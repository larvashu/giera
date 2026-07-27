class_name GridManager
extends Node3D

const GRID_WIDTH: int = 160
const GRID_HEIGHT: int = 190
const CELL_SIZE: float = 1.0
const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/terrain/realistic_grass.png")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]

@export var player_positions: Array[Vector2i] = [Vector2i(78, 9), Vector2i(81, 9)]
@export var enemy_positions: Array[Vector2i] = [Vector2i(78, 180), Vector2i(81, 180)]

var _occupancy: Dictionary[Vector2i, TacticalUnit] = {}
var _blocked_cells: Dictionary[Vector2i, bool] = {}
var _highlight_markers: Dictionary[Vector2i, MeshInstance3D] = {}
var _highlighted_cells: Dictionary[Vector2i, int] = {}
var _highlight_material: StandardMaterial3D
var _danger_markers: Dictionary[Vector2i, MeshInstance3D] = {}
var _danger_material: StandardMaterial3D
var _terrain_features: Array[Vector4] = []
var _terrain_surface: TerrainMapSurface
var _water_surface: WaterMapSurface
var _use_procedural_features: bool = true
var _terrain_material: ShaderMaterial
var _grid_visible: bool = false

func _ready() -> void:
	await _load_selected_terrain()
	_initialize_terrain_features()
	_build_grid()

func _load_selected_terrain() -> void:
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session == null or session.selected_map_id == "builtin:forest":
		return
	var catalog := get_node_or_null("/root/MapCatalog") as MapCatalogService
	if catalog == null:
		return
	var data: Dictionary = catalog.load_map(session.selected_map_id)
	if data.is_empty():
		return
	_use_procedural_features = false
	_terrain_surface = TerrainMapSurface.new()
	_terrain_surface.name = "TerrainMapSurface"
	add_child(_terrain_surface)
	var terrain_directory := str(data.get("terrain_directory", ""))
	var legacy_strokes: Array = data.get("terrain_strokes", []) as Array
	await _terrain_surface.setup(null, terrain_directory, legacy_strokes)
	_water_surface = WaterMapSurface.new()
	_water_surface.name = "WaterMapSurface"
	_water_surface.setup(_terrain_surface)
	add_child(_water_surface)
	_water_surface.load_cells(data.get("water_cells", []) as Array)

func block_cell(cell: Vector2i) -> void:
	if is_inside_grid(cell):
		_blocked_cells[cell] = true

func clear_blocked_cells() -> void:
	_blocked_cells.clear()

func apply_spawn_data(data: Dictionary) -> void:
	player_positions = _parse_spawn_list(data.get("player_spawns", []), player_positions)
	enemy_positions = _parse_spawn_list(data.get("enemy_spawns", []), enemy_positions)

func _parse_spawn_list(raw_values: Variant, fallback: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if raw_values is Array:
		for value: Variant in raw_values:
			if value is Dictionary:
				result.append(Vector2i(int(value.get("x", 0)), int(value.get("z", 0))))
	return result if result.size() >= 2 else fallback

func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked_cells.has(cell)

func set_grid_visible(should_be_visible: bool) -> void:
	_grid_visible = should_be_visible
	if _terrain_material != null:
		_terrain_material.set_shader_parameter("grid_visible", _grid_visible)

func toggle_grid_visibility() -> bool:
	set_grid_visible(not _grid_visible)
	return _grid_visible

func is_grid_visible() -> bool:
	return _grid_visible

func get_units() -> Array[TacticalUnit]:
	var units: Array[TacticalUnit] = []
	for child: Node in get_children():
		if child is TacticalUnit:
			units.append(child as TacticalUnit)
	return units

func _build_grid() -> void:
	_highlight_material = _create_highlight_material()
	_danger_material = _create_danger_material()
	if _terrain_surface != null:
		return
	var terrain_mesh := _create_terrain_mesh()
	var terrain := MeshInstance3D.new()
	terrain.name = "GrassTerrain"
	terrain.mesh = terrain_mesh
	_terrain_material = _create_terrain_material()
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain)

	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = terrain_mesh.create_trimesh_shape()
	floor_body.add_child(floor_shape)
	add_child(floor_body)

func spawn_enemy_at(character_type: StringName, cell: Vector2i) -> TacticalUnit:
	var catalog := get_node("/root/TeamSaveManager") as TeamSaveService
	if catalog == null:
		return null
	var definition := catalog.get_character(character_type)
	if definition == null:
		return null
	_spawn_from_definition(definition, 2, 1, cell)
	return _occupancy.get(cell)

func spawn_default_units() -> void:
	var catalog := get_node("/root/TeamSaveManager") as TeamSaveService
	_spawn_from_definition(catalog.get_character(&"warrior"), 1, 0, player_positions[0])
	_spawn_from_definition(catalog.get_character(&"archer"), 1, 0, player_positions[1])
	_spawn_from_definition(catalog.get_character(&"warrior"), 2, 1, enemy_positions[0])
	_spawn_from_definition(catalog.get_character(&"ogre"), 2, 1, enemy_positions[1])

func spawn_configured_teams(
	team_one: Array[StringName],
	team_two: Array[StringName],
	catalog: TeamSaveService
) -> void:
	var team_one_positions := _expanded_spawn_positions(player_positions)
	var team_two_positions := _expanded_spawn_positions(enemy_positions)
	for index: int in range(mini(team_one.size(), team_one_positions.size())):
		_spawn_character(team_one[index], catalog, 1, 0, team_one_positions[index])
	for index: int in range(mini(team_two.size(), team_two_positions.size())):
		_spawn_character(team_two[index], catalog, 2, 1, team_two_positions[index])

func _expanded_spawn_positions(anchors: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = anchors.duplicate()
	var center := anchors[0] if not anchors.is_empty() else Vector2i(roundi(float(GRID_WIDTH) * 0.5), roundi(float(GRID_HEIGHT) * 0.5))
	for offset: int in [-4, -2, 2, 4, 6]:
		var candidate := Vector2i(clampi(center.x + offset, 0, GRID_WIDTH - 1), center.y)
		if not result.has(candidate): result.append(candidate)
		if result.size() >= 5: break
	return result

func _spawn_character(character_token: StringName, catalog: TeamSaveService, owner_player_id: int, team: int, cell: Vector2i) -> void:
	var definition := catalog.get_character(character_token)
	if definition == null:
		return
	var profile_manager := get_node("/root/CharacterProfileManager") as CharacterProfileService
	var profile := profile_manager.find_profile(character_token)
	_spawn_from_definition(definition, owner_player_id, team, cell, profile)

func _spawn_from_definition(
	definition: CharacterDefinition,
	owner_player_id: int,
	team: int,
	cell: Vector2i,
	profile: CharacterProfile = null
) -> void:
	if definition == null:
		return
	var packed_scene := definition.scene if definition.scene != null else UNIT_SCENE
	var unit := packed_scene.instantiate() as TacticalUnit
	unit.name = "%s_P%d_%d" % [definition.display_name, owner_player_id, get_units().size()]
	unit.apply_character_definition(definition, owner_player_id, team, cell)
	if profile != null:
		var profile_manager := get_node("/root/CharacterProfileManager") as CharacterProfileService
		var modifiers := profile_manager.get_race_modifiers(profile)
		unit.display_name = profile.character_name
		unit.profile_uuid = profile.character_uuid
		unit.race_id = profile.race_id
		unit.class_id = profile.class_id
		unit.abilities = profile_manager.get_skills(profile)
		for stat_id: StringName in CharacterProfile.STAT_NAMES:
			unit.attributes[stat_id] = profile.get_stat(stat_id, modifiers)
		unit.max_health = 6 + unit.attributes[&"wytrzymalosc"] * 2
		unit.current_health = unit.max_health
		unit.initiative = unit.attributes[&"zrecznosc"] + unit.attributes[&"percepcja"]
	unit.position = cell_to_world(cell) + Vector3(0.0, 0.05, 0.0)
	add_child(unit)
	_occupancy[cell] = unit
	unit.died.connect(_on_unit_died)

func _on_unit_died(unit: TacticalUnit) -> void:
	_occupancy.erase(unit.grid_position)
	clear_highlights()

func show_reachable_cells(unit: TacticalUnit) -> void:
	clear_highlights()
	if unit.current_action_points <= 0:
		return
	_highlighted_cells = get_reachable_cells(unit.grid_position, unit.current_action_points)
	for cell: Vector2i in _highlighted_cells:
		_create_highlight_marker(cell)

func clear_highlights() -> void:
	for marker: MeshInstance3D in _highlight_markers.values():
		marker.queue_free()
	_highlight_markers.clear()
	_highlighted_cells.clear()

func set_preview_cell(cell: Vector2i) -> void:
	if not _highlight_markers.has(cell) or not _highlighted_cells.has(cell):
		return
	var marker: MeshInstance3D = _highlight_markers[cell]
	marker.visible = true
	marker.scale = Vector3(1.18, 1.0, 1.18)

func is_cell_highlighted(cell: Vector2i) -> bool:
	return _highlighted_cells.has(cell)

func get_reachable_cells(start: Vector2i, action_points: int) -> Dictionary[Vector2i, int]:
	var distances: Dictionary[Vector2i, int] = {start: 0}
	var frontier: Array[Vector2i] = [start]
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		var current_distance: int = distances[current]
		if current_distance >= action_points:
			continue
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if not _can_step(current, next) or distances.has(next):
				continue
			distances[next] = current_distance + 1
			frontier.append(next)
	distances.erase(start)
	return distances

func find_path(start: Vector2i, goal: Vector2i, max_cost: int) -> Array[Vector2i]:
	if not is_inside_grid(goal) or _occupancy.has(goal) or _blocked_cells.has(goal):
		return []
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var distances: Dictionary[Vector2i, int] = {start: 0}
	var frontier: Array[Vector2i] = [start]
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		if current == goal:
			break
		var current_distance: int = distances[current]
		if current_distance >= max_cost:
			continue
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if not _can_step(current, next) or distances.has(next):
				continue
			distances[next] = current_distance + 1
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var step := goal
	while step != start:
		path.push_front(step)
		step = came_from[step]
	return path

func _can_step(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not is_inside_grid(to_cell) or _occupancy.has(to_cell) or _blocked_cells.has(to_cell):
		return false
	var delta := to_cell - from_cell
	var is_diagonal := absi(delta.x) == 1 and absi(delta.y) == 1
	if not is_diagonal:
		return true
	var horizontal_neighbor := Vector2i(to_cell.x, from_cell.y)
	var vertical_neighbor := Vector2i(from_cell.x, to_cell.y)
	return (
		not _occupancy.has(horizontal_neighbor)
		and not _occupancy.has(vertical_neighbor)
		and not _blocked_cells.has(horizontal_neighbor)
		and not _blocked_cells.has(vertical_neighbor)
	)

func move_occupant(unit: TacticalUnit, destination: Vector2i) -> bool:
	if _occupancy.has(destination) or _occupancy.get(unit.grid_position) != unit:
		return false
	_occupancy.erase(unit.grid_position)
	_occupancy[destination] = unit
	return true

func relocate_occupant_from_world(unit: TacticalUnit, world_position: Vector3) -> Vector2i:
	var preferred := Vector2i(roundi(world_position.x), roundi(world_position.z))
	preferred.x = clampi(preferred.x, 0, GRID_WIDTH - 1)
	preferred.y = clampi(preferred.y, 0, GRID_HEIGHT - 1)
	var destination := _find_nearest_free_cell(preferred, unit)
	_occupancy.erase(unit.grid_position)
	_occupancy[destination] = unit
	unit.grid_position = destination
	unit.position = cell_to_world(destination) + Vector3(0.0, 0.05, 0.0)
	return destination

func _find_nearest_free_cell(origin: Vector2i, unit: TacticalUnit) -> Vector2i:
	for radius: int in range(maxi(GRID_WIDTH, GRID_HEIGHT)):
		for x: int in range(origin.x - radius, origin.x + radius + 1):
			for z: int in [origin.y - radius, origin.y + radius]:
				var candidate := Vector2i(x, z)
				if _is_free_for_relocation(candidate, unit):
					return candidate
		for z: int in range(origin.y - radius + 1, origin.y + radius):
			for x: int in [origin.x - radius, origin.x + radius]:
				var candidate := Vector2i(x, z)
				if _is_free_for_relocation(candidate, unit):
					return candidate
	return unit.grid_position

func find_nearest_free_spawn_cell(origin: Vector2i) -> Vector2i:
	for radius: int in range(maxi(GRID_WIDTH, GRID_HEIGHT)):
		for x: int in range(origin.x - radius, origin.x + radius + 1):
			for z: int in [origin.y - radius, origin.y + radius]:
				var candidate := Vector2i(x, z)
				if is_inside_grid(candidate) and not _blocked_cells.has(candidate) and not _occupancy.has(candidate):
					return candidate
		for z: int in range(origin.y - radius + 1, origin.y + radius):
			for x: int in [origin.x - radius, origin.x + radius]:
				var candidate := Vector2i(x, z)
				if is_inside_grid(candidate) and not _blocked_cells.has(candidate) and not _occupancy.has(candidate):
					return candidate
	return origin

func _is_free_for_relocation(cell: Vector2i, unit: TacticalUnit) -> bool:
	return is_inside_grid(cell) and not _blocked_cells.has(cell) and (not _occupancy.has(cell) or _occupancy[cell] == unit)

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * CELL_SIZE, terrain_height(float(cell.x), float(cell.y)), float(cell.y) * CELL_SIZE)

func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

func terrain_height(world_x: float, world_z: float) -> float:
	if _terrain_surface != null:
		return _terrain_surface.get_height(world_x, world_z)
	var result: float = 0.018 * sin(world_x * 0.41 + world_z * 0.19)
	result += 0.012 * cos(world_x * 0.23 - world_z * 0.37)
	for feature: Vector4 in _terrain_features:
		var distance := Vector2(world_x - feature.x, world_z - feature.y).length()
		if distance >= feature.z:
			continue
		var influence: float = 1.0 - distance / feature.z
		influence = influence * influence * (3.0 - 2.0 * influence)
		result += feature.w * influence
	return result

func _initialize_terrain_features() -> void:
	_terrain_features.clear()
	if not _use_procedural_features:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5_024_060
	for index: int in range(24):
		var amplitude: float
		var radius: float
		if index < 10:
			amplitude = rng.randf_range(0.75, 1.55)
			radius = rng.randf_range(11.0, 24.0)
		else:
			amplitude = rng.randf_range(0.16, 0.48)
			radius = rng.randf_range(6.0, 14.0)
		if index % 2 == 1:
			amplitude = -amplitude
		_terrain_features.append(Vector4(
			rng.randf_range(3.0, float(GRID_WIDTH) - 4.0),
			rng.randf_range(3.0, float(GRID_HEIGHT) - 4.0),
			radius,
			amplitude
		))

func _create_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for z: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var x0: float = float(x) - 0.5
			var x1: float = float(x) + 0.5
			var z0: float = float(z) - 0.5
			var z1: float = float(z) + 0.5
			_append_terrain_vertex(vertices, normals, uvs, x0, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z1)
			_append_terrain_vertex(vertices, normals, uvs, x0, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z1)
			_append_terrain_vertex(vertices, normals, uvs, x0, z1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _append_terrain_vertex(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	x: float,
	z: float
) -> void:
	vertices.append(Vector3(x, terrain_height(x, z), z))
	var dx: float = terrain_height(x - 0.2, z) - terrain_height(x + 0.2, z)
	var dz: float = terrain_height(x, z - 0.2) - terrain_height(x, z + 0.2)
	normals.append(Vector3(dx, 0.4, dz).normalized())
	uvs.append(Vector2((x + 0.5) / float(GRID_WIDTH), (z + 0.5) / float(GRID_HEIGHT)))

func _create_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_size = vec2(50.0, 60.0);
uniform bool grid_visible = false;

float terrain_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float terrain_noise(vec2 point) {
	vec2 cell_id = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(terrain_hash(cell_id), terrain_hash(cell_id + vec2(1.0, 0.0)), local.x),
		mix(terrain_hash(cell_id + vec2(0.0, 1.0)), terrain_hash(cell_id + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void fragment() {
	vec3 grass = texture(grass_texture, UV * grid_size / 4.0).rgb;
	vec2 scaled_uv = UV * grid_size;
	vec2 cell = fract(scaled_uv);
	vec2 edge = min(cell, vec2(1.0) - cell);
	float grid_line = 1.0 - smoothstep(0.02, 0.055, min(edge.x, edge.y));
	float checker = mod(floor(scaled_uv.x) + floor(scaled_uv.y), 2.0);
	vec3 natural_grass = grass * vec3(0.52, 0.82, 0.44) * mix(0.94, 1.08, checker);

	float broad_noise = terrain_noise(scaled_uv * 0.032);
	broad_noise += terrain_noise(scaled_uv * 0.071 + vec2(13.7, 4.2)) * 0.42;
	float sand_mask = smoothstep(1.02, 1.24, broad_noise);
	float sand_detail = terrain_noise(scaled_uv * 0.82 + vec2(2.1, 8.6));
	vec3 sand_dark = vec3(0.42, 0.30, 0.16);
	vec3 sand_light = vec3(0.72, 0.55, 0.32);
	vec3 sand = mix(sand_dark, sand_light, 0.34 + sand_detail * 0.46);
	vec3 ground_color = mix(natural_grass, sand, sand_mask * 0.92);

	float north_south_x = grid_size.x * 0.5 + sin(scaled_uv.y * 0.055) * 12.0;
	float diagonal_z = 30.0 + scaled_uv.x * 0.72 + sin(scaled_uv.x * 0.09) * 6.0;
	float east_west_z = 132.0 + sin(scaled_uv.x * 0.07) * 10.0;
	float north_south_trail = 1.0 - smoothstep(1.65, 2.45, abs(scaled_uv.x - north_south_x));
	float diagonal_trail = 1.0 - smoothstep(1.5, 2.25, abs(scaled_uv.y - diagonal_z));
	float east_west_trail = 1.0 - smoothstep(1.5, 2.25, abs(scaled_uv.y - east_west_z));
	float trail_mask = max(north_south_trail, max(diagonal_trail, east_west_trail));
	float trail_detail = terrain_noise(scaled_uv * 0.48 + vec2(6.2, 19.7));
	vec3 trail_dark = vec3(0.46, 0.30, 0.08);
	vec3 trail_yellow = vec3(0.88, 0.68, 0.22);
	vec3 trail_color = mix(trail_dark, trail_yellow, 0.48 + trail_detail * 0.38);
	ground_color = mix(ground_color, trail_color, trail_mask * 0.94);

	float visible_grid = grid_visible ? grid_line : 0.0;
	ALBEDO = mix(ground_color, vec3(0.04, 0.07, 0.04), visible_grid * 0.82);
	ROUGHNESS = mix(0.88, 0.76, sand_mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_texture", GRASS_TEXTURE)
	material.set_shader_parameter("grid_size", Vector2(GRID_WIDTH, GRID_HEIGHT))
	material.set_shader_parameter("grid_visible", _grid_visible)
	return material

func show_enemy_range(unit: TacticalUnit) -> void:
	clear_danger_zone()
	var cells := get_reachable_cells(unit.grid_position, unit.current_action_points)
	for cell: Vector2i in cells:
		_create_danger_marker(cell)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var adj := unit.grid_position + Vector2i(dx, dz)
			if is_inside_grid(adj) and not _danger_markers.has(adj):
				_create_danger_marker(adj)

func show_danger_zone(center: Vector3, range_units: float) -> void:
	clear_danger_zone()
	var center_cell := Vector2i(roundi(center.x), roundi(center.z))
	var radius := ceili(range_units)
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell := center_cell + Vector2i(dx, dz)
			if not is_inside_grid(cell):
				continue
			if Vector2(float(dx), float(dz)).length() > range_units:
				continue
			_create_danger_marker(cell)

func clear_danger_zone() -> void:
	for marker: MeshInstance3D in _danger_markers.values():
		marker.queue_free()
	_danger_markers.clear()

func _create_danger_marker(cell: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "DangerHighlight_%02d_%02d" % [cell.x, cell.y]
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.86, 0.035, 0.86)
	marker.mesh = marker_mesh
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.12, 0.0)
	marker.material_override = _danger_material
	add_child(marker)
	_danger_markers[cell] = marker

func _create_danger_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.1, 0.1, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.6, 0.05, 0.05, 1.0)
	material.emission_energy_multiplier = 1.2
	return material

func _create_highlight_marker(cell: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "MoveHighlight_%02d_%02d" % [cell.x, cell.y]
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.86, 0.035, 0.86)
	marker.mesh = marker_mesh
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.075, 0.0)
	marker.material_override = _highlight_material
	add_child(marker)
	_highlight_markers[cell] = marker

func _create_highlight_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.9, 0.45, 0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.04, 0.55, 0.2, 1.0)
	material.emission_energy_multiplier = 1.25
	return material
