class_name TerrainMapSurface
extends Node3D

const MAP_SIZE := Vector2i(160, 190)
const REGION_LOCATION := Vector2i.ZERO
const MIN_HEIGHT := -12.0
const MAX_HEIGHT := 18.0
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/terrain/paint/meadow_grass_rgba.png")
const MATERIAL_COLORS: Array[Color] = [
	Color(0.20, 0.43, 0.16),
	Color(0.30, 0.20, 0.12),
	Color(0.62, 0.51, 0.29),
	Color(0.31, 0.32, 0.30),
]
const PAINT_TEXTURES: Array[Dictionary] = [
	{"name": "Trawa", "path": "res://assets/textures/terrain/paint/meadow_grass_rgba.png", "uv_scale": 0.12, "roughness": 0.65},
	{"name": "Ziemia", "path": "res://assets/textures/terrain/paint/forest_soil_rgba.png", "uv_scale": 0.16, "roughness": 0.78},
	{"name": "Piasek", "path": "res://assets/textures/terrain/paint/river_sand_rgba.png", "uv_scale": 0.18, "roughness": 0.72},
	{"name": "Skała", "path": "res://assets/textures/terrain/paint/weathered_rock_rgba.png", "uv_scale": 0.13, "roughness": 0.82},
]

var terrain: Terrain3D
var _region: Terrain3DRegion
var _data_directory: String = ""
var _overlay_multimesh: MultiMesh
var _overlay_instance: MultiMeshInstance3D

func setup(camera: Camera3D = null, data_directory: String = "", legacy_strokes: Array = []) -> void:
	_data_directory = data_directory
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = 1.0
	terrain.mesh_lods = 5
	terrain.mesh_size = 32
	terrain.collision_mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision_shape_size = 16
	add_child(terrain)
	if camera != null:
		terrain.set_camera(camera)
	await get_tree().process_frame
	_configure_material()
	if not data_directory.is_empty():
		terrain.data.load_directory(data_directory)
	_region = terrain.data.get_region(REGION_LOCATION)
	if _region == null:
		_region = terrain.data.add_region_blank(REGION_LOCATION, false)
		_initialize_base_height()
	_ensure_paintable_control()
	_build_visual_overlay()
	if not legacy_strokes.is_empty():
		_import_legacy_strokes(legacy_strokes)

func apply_brush(center: Vector3, radius: float, strength: float, operation: String) -> void:
	if terrain == null or _region == null:
		return
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(MAP_SIZE.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(MAP_SIZE.y - 1, ceili(center.z + radius))
	var changes: Array[Vector3] = []
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var distance := Vector2(float(x) - center.x, float(z) - center.z).length()
			if distance >= radius:
				continue
			var influence: float = 1.0 - distance / radius
			influence = influence * influence * (3.0 - 2.0 * influence)
			var point := Vector3(float(x), 0.0, float(z))
			var current_height := get_height(float(x), float(z))
			var next_height := current_height
			match operation:
				"raise":
					next_height += strength * influence
				"lower":
					next_height -= strength * influence
				"smooth":
					var average := _neighbor_average(x, z)
					next_height = lerpf(current_height, average, clampf(strength * 0.42 * influence, 0.0, 0.92))
				"flatten":
					next_height = lerpf(current_height, center.y, clampf(strength * 0.45 * influence, 0.0, 0.92))
			changes.append(Vector3(point.x, clampf(next_height, MIN_HEIGHT, MAX_HEIGHT), point.z))
	for change: Vector3 in changes:
		terrain.data.set_height(Vector3(change.x, 0.0, change.z), change.y)
	_finish_height_edit()
	_refresh_overlay_heights(changes)

func paint_texture(center: Vector3, radius: float, strength: float, texture_id: int) -> void:
	if terrain == null or _region == null or texture_id < 0 or texture_id >= PAINT_TEXTURES.size():
		return
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(MAP_SIZE.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(MAP_SIZE.y - 1, ceili(center.z + radius))
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var distance := Vector2(float(x) - center.x, float(z) - center.z).length()
			if distance >= radius:
				continue
			var influence := 1.0 - distance / radius
			influence = influence * influence * (3.0 - 2.0 * influence)
			var point := Vector3(float(x), 0.0, float(z))
			var base_id := terrain.data.get_control_base_id(point)
			var overlay_id := terrain.data.get_control_overlay_id(point)
			var blend := terrain.data.get_control_blend(point)
			if base_id == texture_id:
				terrain.data.set_control_overlay_id(point, texture_id)
				terrain.data.set_control_blend(point, 0.0)
			elif overlay_id == texture_id:
				blend = minf(1.0, blend + strength * 0.18 * influence)
				terrain.data.set_control_blend(point, blend)
			else:
				terrain.data.set_control_overlay_id(point, texture_id)
				terrain.data.set_control_blend(point, clampf(strength * 0.18 * influence, 0.0, 1.0))
			terrain.data.set_control_auto(point, false)
			var current_color := terrain.data.get_color(point)
			var target_color := MATERIAL_COLORS[texture_id]
			terrain.data.set_color(point, current_color.lerp(target_color, clampf(strength * 0.24 * influence, 0.0, 1.0)))
			_set_overlay_material(x, z, texture_id)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, false, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, false, false)

func get_height(world_x: float, world_z: float) -> float:
	if terrain == null or terrain.data == null:
		return 0.0
	var value := terrain.data.get_height(Vector3(world_x, 0.0, world_z))
	return 0.0 if is_nan(value) else value

func get_intersection(ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	if terrain == null:
		return Vector3(NAN, NAN, NAN)
	return terrain.get_intersection(ray_origin, ray_direction, false)

func clear_height() -> void:
	if terrain == null:
		return
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			terrain.data.set_height(Vector3(float(x), 0.0, float(z)), 0.0)
	_finish_height_edit()

func save_to_directory(directory: String) -> void:
	if terrain == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	terrain.data.save_directory(directory)
	_data_directory = directory

func get_data_directory() -> String:
	return _data_directory

func _initialize_base_height() -> void:
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var height := _base_height(float(x), float(z))
			terrain.data.set_height(Vector3(float(x), 0.0, float(z)), height)
	_finish_height_edit()

func _ensure_paintable_control() -> void:
	var color_map := _region.get_color_map()
	if color_map == null or color_map.is_empty():
		color_map = Image.create(terrain.region_size, terrain.region_size, false, Image.FORMAT_RGBA8)
		for z: int in range(terrain.region_size):
			for x: int in range(terrain.region_size):
				var variation := 0.88 + 0.12 * sin(float(x) * 0.37 + float(z) * 0.19) * cos(float(z) * 0.23)
				color_map.set_pixel(x, z, Color(MATERIAL_COLORS[0].r * variation, MATERIAL_COLORS[0].g * variation, MATERIAL_COLORS[0].b * variation, 1.0))
		_region.set_color_map(color_map)
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var point := Vector3(float(x), 0.0, float(z))
			terrain.data.set_control_auto(point, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, false, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, false, false)

func _base_height(world_x: float, world_z: float) -> float:
	return (
		0.018 * sin(world_x * 0.41 + world_z * 0.19)
		+ 0.012 * cos(world_x * 0.23 - world_z * 0.37)
	)

func _neighbor_average(x: int, z: int) -> float:
	var total: float = get_height(float(x), float(z))
	var count: int = 1
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, z) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= MAP_SIZE.x or neighbor.y >= MAP_SIZE.y:
			continue
		total += get_height(float(neighbor.x), float(neighbor.y))
		count += 1
	return total / float(count)

func _finish_height_edit() -> void:
	_region.calc_height_range()
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, false)

func _import_legacy_strokes(strokes: Array) -> void:
	for raw_stroke: Variant in strokes:
		if raw_stroke is not Dictionary:
			continue
		var stroke := raw_stroke as Dictionary
		var center := Vector3(
			float(stroke.get("x", 0.0)),
			0.0,
			float(stroke.get("z", 0.0))
		)
		apply_brush(
			center,
			maxf(0.1, float(stroke.get("radius", 1.0))),
			float(stroke.get("strength", 0.5)),
			str(stroke.get("operation", "raise"))
		)

func _build_visual_overlay() -> void:
	_overlay_instance = MultiMeshInstance3D.new()
	_overlay_instance.name = "TerrainPaintVisual"
	var tile_mesh := PlaneMesh.new()
	tile_mesh.size = Vector2(1.08, 1.08)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying flat float material_id;
varying flat float instance_detail;
void vertex() {
	material_id = INSTANCE_CUSTOM.r * 3.0;
	instance_detail = 0.94 + 0.06 * sin(MODEL_MATRIX[3].x * 1.73 + MODEL_MATRIX[3].z * 2.11);
}
void fragment() {
	float id = material_id;
	vec2 tiled_uv = UV * 0.82;
	vec3 albedo;
	if (id < 0.5) {
		albedo = texture(grass_texture, tiled_uv).rgb;
	} else if (id < 1.5) {
		albedo = texture(soil_texture, tiled_uv).rgb;
	} else if (id < 2.5) {
		albedo = texture(sand_texture, tiled_uv).rgb;
	} else {
		albedo = texture(rock_texture, tiled_uv).rgb;
	}
	ALBEDO = albedo * instance_detail;
	ROUGHNESS = 0.82;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("grass_texture", load(str(PAINT_TEXTURES[0]["path"])))
	shader_material.set_shader_parameter("soil_texture", load(str(PAINT_TEXTURES[1]["path"])))
	shader_material.set_shader_parameter("sand_texture", load(str(PAINT_TEXTURES[2]["path"])))
	shader_material.set_shader_parameter("rock_texture", load(str(PAINT_TEXTURES[3]["path"])))
	tile_mesh.material = shader_material
	_overlay_multimesh = MultiMesh.new()
	_overlay_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_overlay_multimesh.use_custom_data = true
	_overlay_multimesh.mesh = tile_mesh
	_overlay_multimesh.instance_count = MAP_SIZE.x * MAP_SIZE.y
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var point := Vector3(float(x), 0.0, float(z))
			var base_id := terrain.data.get_control_base_id(point)
			var overlay_id := terrain.data.get_control_overlay_id(point)
			var texture_id := overlay_id if terrain.data.get_control_blend(point) >= 0.5 else base_id
			var index := z * MAP_SIZE.x + x
			_overlay_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, get_height(float(x), float(z)) + 0.035, float(z) + 0.5)))
			_overlay_multimesh.set_instance_custom_data(index, Color(float(texture_id) / 3.0, 0.0, 0.0, 1.0))
	_overlay_instance.multimesh = _overlay_multimesh
	add_child(_overlay_instance)

func _set_overlay_material(x: int, z: int, texture_id: int) -> void:
	if _overlay_multimesh == null:
		return
	var index := z * MAP_SIZE.x + x
	_overlay_multimesh.set_instance_custom_data(index, Color(float(texture_id) / 3.0, 0.0, 0.0, 1.0))

func _refresh_overlay_heights(changes: Array[Vector3]) -> void:
	if _overlay_multimesh == null:
		return
	for change: Vector3 in changes:
		var x := clampi(roundi(change.x), 0, MAP_SIZE.x - 1)
		var z := clampi(roundi(change.z), 0, MAP_SIZE.y - 1)
		var index := z * MAP_SIZE.x + x
		var instance_transform := _overlay_multimesh.get_instance_transform(index)
		instance_transform.origin.y = change.y + 0.035
		_overlay_multimesh.set_instance_transform(index, instance_transform)

func _configure_material() -> void:
	if terrain == null or terrain.material == null or terrain.assets == null:
		return
	var texture_assets: Array[Terrain3DTextureAsset] = []
	for texture_id: int in range(PAINT_TEXTURES.size()):
		var definition: Dictionary = PAINT_TEXTURES[texture_id]
		var asset := Terrain3DTextureAsset.new()
		asset.id = texture_id
		asset.name = str(definition["name"])
		asset.albedo_texture = load(str(definition["path"])) as Texture2D
		asset.normal_texture = load("res://assets/textures/terrain/paint/flat_normal_roughness_1024.png") as Texture2D
		asset.uv_scale = float(definition["uv_scale"])
		asset.roughness = float(definition["roughness"])
		texture_assets.append(asset)
	terrain.assets.set_texture_list(texture_assets)
	terrain.assets.update_texture_list()
	terrain.material.show_colormap = false
	terrain.material.update()
	terrain.show_grey = true
	terrain.material.world_background = Terrain3DMaterial.NONE
