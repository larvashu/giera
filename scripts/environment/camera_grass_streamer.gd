class_name CameraGrassStreamer
extends Node3D

# Jedna komorka planszy ma 1 m. Renderujemy tylko glowna plansze 160 x 190 m.
const LOD_RANGES: Array[Vector2] = [
	Vector2(0.0, 12.0),
	Vector2(8.0, 36.0),
	Vector2(28.0, 92.0),
	Vector2(72.0, 200.0),
	Vector2(160.0, 380.0),
	Vector2(330.0, 650.0)
]
const LOD_SPACING: Array[float] = [0.38, 0.82, 1.65, 3.8, 8.0, 15.0]
const LOD_BLADES: Array[int] = [14, 8, 4, 3, 3, 3]
const LOD_SCALE: Array[float] = [1.0, 1.08, 1.18, 1.0, 1.0, 1.0]
const LOD_UPDATE_STEP: Array[float] = [1.0, 2.0, 5.0, 12.0, 28.0, 60.0]
# Daleki LOD zwieksza szerokosc reprezentowanej kepy, ale nie wysokosc trawy.
const LOD_CARD_HALF_WIDTH: Array[float] = [0.0, 0.0, 0.0, 0.75, 1.55, 2.8]
const LOD_CARD_HEIGHT: Array[float] = [0.0, 0.0, 0.0, 0.62, 0.72, 0.82]

@export var grid_manager_path: NodePath = NodePath("../GridManager")

var _grid_manager: GridManager
var _lod_instances: Array[MultiMeshInstance3D] = []
var _last_focus := Vector2(INF, INF)
var _last_lod_focus: Array[Vector2] = []
var _grass_materials: Array[ShaderMaterial] = []
var _far_field: MultiMeshInstance3D


func _ready() -> void:
	_grid_manager = get_node_or_null(grid_manager_path) as GridManager
	if _grid_manager == null:
		push_error("CameraGrassStreamer: nie znaleziono GridManager.")
		set_process(false)
		return
	for lod_index: int in range(LOD_RANGES.size()):
		_grass_materials.append(_create_grass_material(lod_index))
		_last_lod_focus.append(Vector2(INF, INF))
	_create_lod_multimeshes()
	_create_world_far_field()
	_update_grass(true)


func _process(_delta: float) -> void:
	_update_grass(false)


func _create_lod_multimeshes() -> void:
	# Tylko bliskie LOD-y podazaja za graczem. Daleka trawa jest statyczna.
	for lod_index: int in range(3):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _create_lod_mesh(LOD_BLADES[lod_index], LOD_SCALE[lod_index], lod_index >= 3, lod_index)
		var instances := MultiMeshInstance3D.new()
		instances.name = "GrassLOD%d_%dm_%dm" % [lod_index, roundi(LOD_RANGES[lod_index].x), roundi(LOD_RANGES[lod_index].y)]
		instances.multimesh = multimesh
		instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod_index == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instances)
		_lod_instances.append(instances)


func _create_world_far_field() -> void:
	# Jedna niezmienna warstwa obejmuje glowna plansze i nie jest przebudowywana.
	var spacing: float = 1.65
	var transforms: Array[Transform3D] = []
	var minimum_x: float = 0.0
	var maximum_x: float = float(GridManager.GRID_WIDTH)
	var minimum_z: float = 0.0
	var maximum_z: float = float(GridManager.GRID_HEIGHT)
	for grid_z: int in range(floori(minimum_z / spacing), ceili(maximum_z / spacing)):
		for grid_x: int in range(floori(minimum_x / spacing), ceili(maximum_x / spacing)):
			var jitter := _deterministic_jitter(grid_x, grid_z, 701)
			var position_2d := Vector2(
				float(grid_x) * spacing + jitter.x * spacing * 0.68,
				float(grid_z) * spacing + jitter.y * spacing * 0.68
			)
			if not _can_place_grass(position_2d):
				continue
			if _hash_01(grid_x, grid_z, 719) < 0.22:
				continue
			var terrain_local := Vector2(
				fposmod(position_2d.x, float(GridManager.GRID_WIDTH)),
				fposmod(position_2d.y, float(GridManager.GRID_HEIGHT))
			)
			var world_position := Vector3(
				position_2d.x,
				_grid_manager.terrain_height(terrain_local.x, terrain_local.y) + 0.012,
				position_2d.y
			)
			var yaw := _hash_01(grid_x, grid_z, 733) * TAU
			var scale_variation := lerpf(0.82, 1.18, _hash_01(grid_x, grid_z, 751))
			transforms.append(Transform3D(
				Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_variation),
				world_position
			))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Zwykle pojedyncze zdzbla zamiast duzych low-poly kart kep.
	multimesh.mesh = _create_lod_mesh(6, 0.92, false, 2)
	_apply_transform_buffer(multimesh, transforms)
	_far_field = MultiMeshInstance3D.new()
	_far_field.name = "GrassFarField_StaticWorld"
	_far_field.multimesh = multimesh
	_far_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_far_field.custom_aabb = AABB(
		Vector3(minimum_x - 3.0, -4.0, minimum_z - 3.0),
		Vector3(maximum_x - minimum_x + 6.0, 10.0, maximum_z - minimum_z + 6.0)
	)
	add_child(_far_field)


func _update_grass(force: bool) -> void:
	var focus := _get_grass_focus()
	# Geometria LOD pozostaje stale widoczna; przebudowa tylko przesuwa zewnetrzne pierscienie.
	for lod_index: int in range(_lod_instances.size()):
		var update_step := LOD_UPDATE_STEP[lod_index]
		var lod_focus := Vector2(snappedf(focus.x, update_step), snappedf(focus.y, update_step))
		if force or lod_focus != _last_lod_focus[lod_index]:
			_last_lod_focus[lod_index] = lod_focus
			_rebuild_lod(lod_index, lod_focus)
	_last_focus = focus


func _get_grass_focus() -> Vector2:
	if not is_inside_tree() or get_tree() == null:
		return Vector2(float(GridManager.GRID_WIDTH - 1) * 0.5, float(GridManager.GRID_HEIGHT - 1) * 0.5)
	var exploration_player := get_tree().get_first_node_in_group("exploration_player") as Node3D
	if exploration_player != null:
		return Vector2(exploration_player.global_position.x, exploration_player.global_position.z)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(float(GridManager.GRID_WIDTH - 1) * 0.5, float(GridManager.GRID_HEIGHT - 1) * 0.5)
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var ground_hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(viewport_center), camera.project_ray_normal(viewport_center))
	if ground_hit is Vector3:
		var hit := ground_hit as Vector3
		return Vector2(hit.x, hit.z)
	return Vector2(camera.global_position.x, camera.global_position.z)


func _rebuild_lod(lod_index: int, focus: Vector2) -> void:
	var lod_range := LOD_RANGES[lod_index]
	var spacing := LOD_SPACING[lod_index]
	var transforms: Array[Transform3D] = []
	for grid_z: int in range(floori((focus.y - lod_range.y) / spacing), ceili((focus.y + lod_range.y) / spacing) + 1):
		for grid_x: int in range(floori((focus.x - lod_range.y) / spacing), ceili((focus.x + lod_range.y) / spacing) + 1):
			var jitter := _deterministic_jitter(grid_x, grid_z, lod_index)
			var position_2d := Vector2(float(grid_x) * spacing + jitter.x * spacing * 0.72, float(grid_z) * spacing + jitter.y * spacing * 0.72)
			var distance := position_2d.distance_to(focus)
			if distance < lod_range.x or distance >= lod_range.y or not _can_place_grass(position_2d):
				continue
			var random_value := _hash_01(grid_x, grid_z, lod_index * 31 + 17)
			var rejection_threshold := 0.0
			if lod_index == 2:
				rejection_threshold = 0.12
			elif lod_index == 3:
				rejection_threshold = 0.30
			elif lod_index == 4:
				rejection_threshold = 0.22
			elif lod_index >= 5:
				rejection_threshold = 0.12
			if random_value < rejection_threshold:
				continue
			var terrain_local := Vector2(
				fposmod(position_2d.x, float(GridManager.GRID_WIDTH)),
				fposmod(position_2d.y, float(GridManager.GRID_HEIGHT))
			)
			var world_position := Vector3(
				position_2d.x,
				_grid_manager.terrain_height(terrain_local.x, terrain_local.y) + 0.01,
				position_2d.y
			)
			var yaw := _hash_01(grid_x, grid_z, lod_index * 47 + 91) * TAU
			var scale_variation := lerpf(0.78, 1.25, _hash_01(grid_x, grid_z, lod_index * 73 + 5))
			transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_variation), world_position))
	_apply_transform_buffer(_lod_instances[lod_index].multimesh, transforms)
	_update_lod_bounds(_lod_instances[lod_index], focus, lod_range.y)


func _update_lod_bounds(instances: MultiMeshInstance3D, focus: Vector2, radius: float) -> void:
	# MultiMesh.buffer omija koszt tysiecy setterow, ale wymaga jawnego AABB do poprawnego cullingu.
	instances.custom_aabb = AABB(
		Vector3(focus.x - radius - 2.0, -4.0, focus.y - radius - 2.0),
		Vector3(radius * 2.0 + 4.0, 10.0, radius * 2.0 + 4.0)
	)


func _can_place_grass(position_2d: Vector2) -> bool:
	var minimum_x := 0.0
	var maximum_x := float(GridManager.GRID_WIDTH)
	var minimum_z := 0.0
	var maximum_z := float(GridManager.GRID_HEIGHT)
	if position_2d.x < minimum_x or position_2d.x >= maximum_x or position_2d.y < minimum_z or position_2d.y >= maximum_z:
		return false
	var local_position := position_2d
	var north_south_x := float(GridManager.GRID_WIDTH) * 0.5 + sin(local_position.y * 0.055) * 12.0
	var diagonal_z := 30.0 + local_position.x * 0.72 + sin(local_position.x * 0.09) * 6.0
	var east_west_z := 132.0 + sin(local_position.x * 0.07) * 10.0
	return not (absf(local_position.x - north_south_x) < 2.8 or absf(local_position.y - diagonal_z) < 2.6 or absf(local_position.y - east_west_z) < 2.6)


func _apply_transform_buffer(multimesh: MultiMesh, transforms: Array[Transform3D]) -> void:
	multimesh.instance_count = transforms.size()
	if transforms.is_empty():
		multimesh.visible_instance_count = 0
		return
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	var index: int = 0
	for instance_transform: Transform3D in transforms:
		buffer[index] = instance_transform.basis.x.x
		buffer[index + 1] = instance_transform.basis.y.x
		buffer[index + 2] = instance_transform.basis.z.x
		buffer[index + 3] = instance_transform.origin.x
		buffer[index + 4] = instance_transform.basis.x.y
		buffer[index + 5] = instance_transform.basis.y.y
		buffer[index + 6] = instance_transform.basis.z.y
		buffer[index + 7] = instance_transform.origin.y
		buffer[index + 8] = instance_transform.basis.x.z
		buffer[index + 9] = instance_transform.basis.y.z
		buffer[index + 10] = instance_transform.basis.z.z
		buffer[index + 11] = instance_transform.origin.z
		index += 12
	multimesh.buffer = buffer
	multimesh.visible_instance_count = transforms.size()


func _create_lod_mesh(blade_count: int, size_multiplier: float, billboard_like: bool, lod_index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if billboard_like:
		# Daleki LOD przedstawia cala kepe na trzech krzyzujacych sie kartach.
		# Dzieki temu pozostaje czytelny z doliny i pod dowolnym katem kamery FPP.
		for card_index: int in range(3):
			_add_card_quad(
				surface,
				PI * float(card_index) / 3.0,
				LOD_CARD_HALF_WIDTH[lod_index],
				LOD_CARD_HEIGHT[lod_index]
			)
	else:
		for blade_index: int in range(blade_count):
			var angle := TAU * float(blade_index) / float(maxi(blade_count, 1))
			var radial := 0.04 + 0.018 * float(blade_index % 4)
			var center := Vector3(cos(angle) * radial, 0.0, sin(angle) * radial)
			var side := Vector3(cos(angle), 0.0, sin(angle))
			var width := 0.026 * size_multiplier
			var height := (0.38 + 0.035 * float(blade_index % 3)) * size_multiplier
			_add_triangle(surface, center - side * width, center + side * width, center + Vector3(0.03 * sin(angle), height, 0.03 * cos(angle)), float(blade_index) / float(maxi(blade_count, 1)))
	var mesh := surface.commit()
	mesh.surface_set_material(0, _grass_materials[lod_index])
	return mesh


func _add_card_quad(surface: SurfaceTool, angle: float, half_width: float, height: float) -> void:
	var side := Vector3(cos(angle), 0.0, sin(angle))
	var left := -side * half_width
	var right := side * half_width
	var top_left := left + Vector3.UP * height
	var top_right := right + Vector3.UP * height
	var normal := Vector3(-sin(angle), 0.0, cos(angle))
	var vertices: Array[Array] = [
		[left, Vector2(0.0, 0.0)], [right, Vector2(1.0, 0.0)], [top_right, Vector2(1.0, 1.0)],
		[left, Vector2(0.0, 0.0)], [top_right, Vector2(1.0, 1.0)], [top_left, Vector2(0.0, 1.0)]
	]
	for vertex_data: Array in vertices:
		surface.set_normal(normal)
		surface.set_uv(vertex_data[1] as Vector2)
		surface.add_vertex(vertex_data[0] as Vector3)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: float) -> void:
	var normal := Plane(a, b, c).normal
	for vertex_data: Array in [[a, 0.0], [b, 0.0], [c, 1.0]]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(tint, vertex_data[1] as float))
		surface.add_vertex(vertex_data[0] as Vector3)


func _create_grass_material(lod_index: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec3 grass_dark : source_color = vec3(0.018, 0.065, 0.012);
uniform vec3 grass_light : source_color = vec3(0.10, 0.25, 0.055);
uniform vec3 violet : source_color = vec3(0.25, 0.08, 0.31);
uniform float wind_strength = 0.065;
uniform float wind_speed = 1.25;
uniform bool card_mode = false;
uniform float brightness_boost = 1.0;
uniform float ambient_lift = 0.0;

float blade_mask(vec2 uv, float center, float lean, float width) {
	float shaped_x = uv.x - center + lean * (uv.y - 0.45);
	float tapered_width = mix(width, 0.012, smoothstep(0.05, 1.0, uv.y));
	return 1.0 - smoothstep(tapered_width, tapered_width + 0.025, abs(shaped_x));
}

void vertex() {
	float height_mask = UV.y * UV.y;
	float phase = TIME * wind_speed + MODEL_MATRIX[3].x * 0.19 + MODEL_MATRIX[3].z * 0.27;
	VERTEX.x += sin(phase) * wind_strength * height_mask;
	VERTEX.z += cos(phase * 0.71) * wind_strength * 0.48 * height_mask;
}

void fragment() {
	float random_tint = fract(sin(MODEL_MATRIX[3].x * 12.9898 + MODEL_MATRIX[3].z * 78.233) * 43758.5453);
	vec3 green = mix(grass_dark, grass_light, 0.30 + UV.y * 0.55);
	ALBEDO = mix(green, violet, 0.20 + random_tint * 0.34) * brightness_boost;
	EMISSION = ALBEDO * ambient_lift;
	ROUGHNESS = 0.94;
	if (card_mode) {
		float mask = blade_mask(UV, 0.10, -0.15, 0.075);
		mask = max(mask, blade_mask(UV, 0.27, 0.10, 0.065));
		mask = max(mask, blade_mask(UV, 0.44, -0.04, 0.085));
		mask = max(mask, blade_mask(UV, 0.61, 0.14, 0.070));
		mask = max(mask, blade_mask(UV, 0.79, -0.11, 0.080));
		mask = max(mask, blade_mask(UV, 0.92, 0.06, 0.060));
		ALPHA = mask;
		ALPHA_SCISSOR_THRESHOLD = 0.36;
	} else {
		ALPHA = 1.0;
		ALPHA_SCISSOR_THRESHOLD = 0.0;
	}
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("card_mode", lod_index >= 3)
	var brightness_boost := 1.0
	if lod_index == 3:
		brightness_boost = 1.12
	elif lod_index == 4:
		brightness_boost = 1.24
	elif lod_index >= 5:
		brightness_boost = 1.32
	material.set_shader_parameter("brightness_boost", brightness_boost)
	# Dalekie karty musza pozostac czytelne poza zasiegiem lokalnych swiatel.
	material.set_shader_parameter("ambient_lift", 0.28 if lod_index >= 3 else 0.0)
	return material


func _deterministic_jitter(x: int, z: int, seed_value: int) -> Vector2:
	return Vector2(_hash_01(x, z, seed_value) - 0.5, _hash_01(x, z, seed_value + 1013) - 0.5) * 2.0


func _hash_01(x: int, z: int, seed_value: int) -> float:
	var value: int = x * 73856093 ^ z * 19349663 ^ seed_value * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return float(value & 0x7fffffff) / 2147483647.0
