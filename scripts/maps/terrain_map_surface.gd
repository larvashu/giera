class_name TerrainMapSurface
extends Node3D

const MAP_SIZE := Vector2i(160, 190)
const REGION_LOCATION := Vector2i.ZERO
const MIN_HEIGHT := -12.0
const MAX_HEIGHT := 18.0
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/terrain/realistic_grass.png")

var terrain: Terrain3D
var _region: Terrain3DRegion
var _data_directory: String = ""

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
	if not data_directory.is_empty():
		terrain.data.load_directory(data_directory)
	_region = terrain.data.get_region(REGION_LOCATION)
	if _region == null:
		_region = terrain.data.add_region_blank(REGION_LOCATION, false)
		_initialize_base_height()
	if not legacy_strokes.is_empty():
		_import_legacy_strokes(legacy_strokes)
	_configure_material()

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

func _configure_material() -> void:
	if terrain == null or terrain.material == null or terrain.assets == null:
		return
	var grass := Terrain3DTextureAsset.new()
	grass.name = "Grass"
	var grass_image := GRASS_TEXTURE.get_image()
	grass_image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	grass_image.generate_mipmaps()
	grass.albedo_texture = ImageTexture.create_from_image(grass_image)
	var normal_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	normal_image.fill(Color(0.5, 0.5, 1.0, 1.0))
	normal_image.generate_mipmaps()
	grass.normal_texture = ImageTexture.create_from_image(normal_image)
	grass.uv_scale = 0.12
	grass.roughness = 0.65
	terrain.assets.set_texture(0, grass)
	terrain.assets.update_texture_list()
	terrain.show_grey = false
	terrain.material.world_background = Terrain3DMaterial.NONE
