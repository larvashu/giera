class_name GridManager
extends Node3D

const GRID_WIDTH: int = 160
const GRID_HEIGHT: int = 190
const CELL_SIZE: float = 1.0
const SOLO_TRAIL_SIZE: Vector2i = Vector2i(256, 256)
const UNIT_SCENE: PackedScene = preload("res://scenes/units/unit.tscn")
const TERRAIN_GROUND_MATERIAL: ShaderMaterial = preload("res://world/terrain/materials/terrain_ground_material.tres")
const GROUND_CLUTTER_SCRIPT := preload("res://world/terrain/ground_clutter_system.gd")
const ARENA_TEST_LANDSCAPE_SCRIPT := preload("res://scripts/maps/arena_test_landscape.gd")
# Deterministic Solo Trail refinement controls. The procedural surface is
# rebuilt from these values, so reverting this file restores the previous map.
const REFINEMENT_HILL_CENTER := Vector2(208.0, 54.0)
const REFINEMENT_HILL_RADIUS: float = 66.0
const REFINEMENT_RIVER_AREA := Rect2(0.0, 78.0, 256.0, 58.0)
const REFINEMENT_DEFORMATION_STRENGTH: float = 1.0
const REFINEMENT_LARGE_NOISE_SCALE: float = 0.018
const REFINEMENT_MEDIUM_NOISE_SCALE: float = 0.057
const REFINEMENT_FINE_NOISE_SCALE: float = 0.19
const REFINEMENT_SEED: float = 814.0426
const REFINEMENT_MAX_SLOPE: float = 0.78
const REFINEMENT_FADE_INTENSITY: float = 1.35
const HIGHLAND_LEDGE_STRENGTH: float = 0.11
const HIGHLAND_EROSION_STRENGTH: float = 0.16
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

var _arena_rect: Rect2i  # When has_area(), restricts the playable grid to this rectangle
var _occupancy: Dictionary[Vector2i, TacticalUnit] = {}
var _blocked_cells: Dictionary[Vector2i, bool] = {}
var _vision_blocked_cells: Dictionary[Vector2i, bool] = {}
var _highlight_markers: Dictionary[Vector2i, MeshInstance3D] = {}
var _highlighted_cells: Dictionary[Vector2i, int] = {}
var _highlight_material: StandardMaterial3D
var _danger_markers: Dictionary[Vector2i, MeshInstance3D] = {}
var _danger_material: StandardMaterial3D
var _ability_range_markers: Dictionary[Vector2i, MeshInstance3D] = {}
var _ability_range_material: StandardMaterial3D
var _ability_target_material: StandardMaterial3D
var _terrain_features: Array[Vector4] = []
var _terrain_surface: TerrainMapSurface
var _water_surface: WaterMapSurface
var _use_procedural_features: bool = true
var _terrain_material: ShaderMaterial
var _grid_visible: bool = false
var _arena_test_landscape_enabled: bool = false

func _ready() -> void:
	add_to_group("grid_manager")
	await _load_selected_terrain()
	_initialize_terrain_features()
	_build_grid()
	if _arena_test_landscape_enabled:
		var landscape := ARENA_TEST_LANDSCAPE_SCRIPT.new() as ArenaTestLandscape
		landscape.name = "ArenaTestLandscape"
		add_child(landscape)
		landscape.setup(self)
	if _arena_rect.has_area() and _terrain_material != null:
		_terrain_material.set_shader_parameter("show_trails", false)
		_terrain_material.set_shader_parameter("is_arena", true)
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session != null and session.selected_map_id == "builtin:solo_trail" and _terrain_material != null:
		_terrain_material.set_shader_parameter("plain_green", false)
		_terrain_material.set_shader_parameter("solo_trail_landscape", true)

func _load_selected_terrain() -> void:
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session == null or session.selected_map_id == "builtin:forest":
		return
	if session.selected_map_id == "builtin:solo_trail":
		_use_procedural_features = false
		player_positions = [Vector2i(128, 128), Vector2i(132, 128)]
		return
	if session.selected_map_id == "builtin:arena":
		const ARENA_RECTS: Array[Rect2i] = [
			Rect2i(71, 86, 18, 18),  # 0 Small
			Rect2i(65, 80, 30, 30),  # 1 Normal
			Rect2i(59, 74, 42, 42),  # 2 Large
			Rect2i(52, 67, 56, 56),  # 3 Very Large
		]
		var si := clampi(session.arena_size_index, 0, ARENA_RECTS.size() - 1)
		_arena_rect = ARENA_RECTS[si]
		if session.arena_test_mode:
			_arena_rect = Rect2i(25, 6, 110, 178)
			_arena_test_landscape_enabled = true
		var ax := _arena_rect.position.x
		var ay := _arena_rect.position.y
		var aw := _arena_rect.size.x
		var ah := _arena_rect.size.y
		var north_spawn_y := ay + ah / 4 if session.arena_test_mode else ay + 5
		var south_spawn_y := ay + ah * 3 / 4 if session.arena_test_mode else ay + ah - 6
		player_positions = [
			Vector2i(ax + aw / 4, north_spawn_y),
			Vector2i(ax + aw * 3 / 4, north_spawn_y),
		]
		enemy_positions = [
			Vector2i(ax + aw / 4, south_spawn_y),
			Vector2i(ax + aw * 3 / 4, south_spawn_y),
		]
		_use_procedural_features = false
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

func get_arena_rect() -> Rect2i:
	return _arena_rect

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

func block_vision_cell(cell: Vector2i) -> void:
	if is_inside_grid(cell):
		_vision_blocked_cells[cell] = true

func blocks_vision(cell: Vector2i) -> bool:
	return _vision_blocked_cells.has(cell)

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
	_ability_range_material = _create_ability_range_material()
	_ability_target_material = _create_ability_target_material()
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

	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session == null or session.selected_map_id != "builtin:solo_trail":
		var ground_clutter := GROUND_CLUTTER_SCRIPT.new() as GroundClutterSystem
		ground_clutter.name = "GroundClutter"
		add_child(ground_clutter)
		ground_clutter.setup_battle(self, _arena_rect.has_area())

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

func spawn_solo_unit(character_id: StringName) -> TacticalUnit:
	var catalog := get_node("/root/TeamSaveManager") as TeamSaveService
	_spawn_character(character_id, catalog, 1, 0, player_positions[0])
	var units := get_units()
	return units[0] if not units.is_empty() else null

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

func spawn_arena_teams(session: GameSessionState, catalog: TeamSaveService) -> void:
	var ax := _arena_rect.position.x
	var ay := _arena_rect.position.y
	var aw := _arena_rect.size.x
	var ah := _arena_rect.size.y
	var q1x := ax + aw / 4
	var q3x := ax + aw * 3 / 4
	var ny := ay + ah / 4 if session.arena_test_mode else ay + 5
	var sy := ay + ah * 3 / 4 if session.arena_test_mode else ay + ah - 6
	var anchors_table: Array = []
	if session.player_count <= 2:
		anchors_table = [
			[Vector2i(q1x, ny), Vector2i(q3x, ny)],
			[Vector2i(q1x, sy), Vector2i(q3x, sy)],
		]
	else:
		anchors_table = [
			[Vector2i(q1x - 2, ny), Vector2i(q1x + 2, ny)],
			[Vector2i(q3x - 2, ny), Vector2i(q3x + 2, ny)],
			[Vector2i(q1x - 2, sy), Vector2i(q1x + 2, sy)],
			[Vector2i(q3x - 2, sy), Vector2i(q3x + 2, sy)],
		]
	for i: int in range(session.player_count):
		if i >= anchors_table.size():
			break
		var pid := i + 1
		var composition := session.get_composition(pid)
		var typed_anchors: Array[Vector2i] = []
		for a: Variant in anchors_table[i]:
			typed_anchors.append(a as Vector2i)
		var positions := _expanded_spawn_positions(typed_anchors)
		for si: int in range(mini(composition.size(), positions.size())):
			_spawn_character(composition[si], catalog, pid, i, positions[si])

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
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session != null and session.arena_test_mode:
		unit.max_action_points = maxi(1, roundi(float(unit.max_action_points) * 1.4))
		unit.current_action_points = unit.max_action_points
	var spawn_cell := _find_nearest_free_cell(cell, unit)
	unit.grid_position = spawn_cell
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
	unit.position = _unit_world_position(unit, spawn_cell)
	add_child(unit)
	_set_unit_occupancy(unit, spawn_cell)
	unit.died.connect(_on_unit_died)

func _on_unit_died(unit: TacticalUnit) -> void:
	_clear_unit_occupancy(unit)
	clear_highlights()

func show_reachable_cells(unit: TacticalUnit) -> void:
	clear_highlights()
	if unit.current_action_points <= 0:
		return
	_highlighted_cells = get_reachable_cells(unit.grid_position, unit.current_action_points)
	for cell: Vector2i in _highlighted_cells:
		_create_highlight_marker(cell)
	# Obstacles bordering the reachable area get a restrained red outline.
	var marked_obstacles: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _highlighted_cells:
		for direction: Vector2i in DIRECTIONS:
			var obstacle := cell + direction
			if is_inside_grid(obstacle) and is_cell_blocked(obstacle) and not marked_obstacles.has(obstacle):
				_create_danger_marker(obstacle)
				marked_obstacles[obstacle] = true

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
	var mover: TacticalUnit = _occupancy.get(start) as TacticalUnit
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
			if not _can_step(current, next, mover) or distances.has(next):
				continue
			distances[next] = current_distance + 1
			frontier.append(next)
	distances.erase(start)
	return distances

func find_path(start: Vector2i, goal: Vector2i, max_cost: int) -> Array[Vector2i]:
	var mover: TacticalUnit = _occupancy.get(start) as TacticalUnit
	if not _can_occupy(goal, mover):
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
			if not _can_step(current, next, mover) or distances.has(next):
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

func _can_step(from_cell: Vector2i, to_cell: Vector2i, mover: TacticalUnit = null) -> bool:
	if not _can_occupy(to_cell, mover):
		return false
	var delta := to_cell - from_cell
	var is_diagonal := absi(delta.x) == 1 and absi(delta.y) == 1
	if not is_diagonal:
		return true
	var horizontal_neighbor := Vector2i(to_cell.x, from_cell.y)
	var vertical_neighbor := Vector2i(from_cell.x, to_cell.y)
	return _can_occupy(horizontal_neighbor, mover) and _can_occupy(vertical_neighbor, mover)

func _can_occupy(anchor: Vector2i, mover: TacticalUnit = null) -> bool:
	var size := mover.footprint_size if mover != null else Vector2i.ONE
	for x: int in size.x:
		for y: int in size.y:
			var cell := anchor + Vector2i(x, y)
			if not is_inside_grid(cell) or _blocked_cells.has(cell):
				return false
			if _occupancy.has(cell) and _occupancy[cell] != mover:
				return false
	return true

func move_occupant(unit: TacticalUnit, destination: Vector2i) -> bool:
	if not _can_occupy(destination, unit) or _occupancy.get(unit.grid_position) != unit:
		return false
	_clear_unit_occupancy(unit)
	_set_unit_occupancy(unit, destination)
	return true

func relocate_occupant_from_world(unit: TacticalUnit, world_position: Vector3) -> Vector2i:
	var preferred := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if _arena_rect.has_area():
		preferred.x = clampi(preferred.x, _arena_rect.position.x, _arena_rect.end.x - 1)
		preferred.y = clampi(preferred.y, _arena_rect.position.y, _arena_rect.end.y - 1)
	else:
		preferred.x = clampi(preferred.x, 0, GRID_WIDTH - 1)
		preferred.y = clampi(preferred.y, 0, GRID_HEIGHT - 1)
	var destination := _find_nearest_free_cell(preferred, unit)
	_clear_unit_occupancy(unit)
	_set_unit_occupancy(unit, destination)
	unit.grid_position = destination
	unit.position = _unit_world_position(unit, destination)
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
	return _can_occupy(cell, unit)

func _set_unit_occupancy(unit: TacticalUnit, anchor: Vector2i) -> void:
	for cell: Vector2i in unit.occupied_cells(anchor):
		_occupancy[cell] = unit

func _clear_unit_occupancy(unit: TacticalUnit) -> void:
	for cell: Vector2i in _occupancy.keys():
		if _occupancy[cell] == unit:
			_occupancy.erase(cell)

func _unit_world_position(unit: TacticalUnit, anchor: Vector2i) -> Vector3:
	var center_x := float(anchor.x) + float(unit.footprint_size.x - 1) * 0.5
	var center_z := float(anchor.y) + float(unit.footprint_size.y - 1) * 0.5
	return Vector3(center_x * CELL_SIZE, terrain_height(center_x, center_z) + 0.05, center_z * CELL_SIZE)

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * CELL_SIZE, terrain_height(float(cell.x), float(cell.y)), float(cell.y) * CELL_SIZE)

func is_inside_grid(cell: Vector2i) -> bool:
	if _arena_rect.has_area():
		return _arena_rect.has_point(cell)
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

func terrain_height(world_x: float, world_z: float) -> float:
	if _arena_test_landscape_enabled:
		return ArenaTestLandscape.sample_height(_arena_rect, world_x, world_z)
	if _terrain_surface != null:
		return _terrain_surface.get_height(world_x, world_z)
	if _is_solo_trail():
		return _solo_trail_height(world_x, world_z)
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

func is_arena_test_water(world_x: float, world_z: float) -> bool:
	return _arena_test_landscape_enabled and ArenaTestLandscape.is_water(_arena_rect, world_x, world_z)

func get_exploration_world_size() -> Vector2:
	return Vector2(SOLO_TRAIL_SIZE) if _is_solo_trail() else Vector2(GRID_WIDTH, GRID_HEIGHT)

func _is_solo_trail() -> bool:
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	return session != null and session.selected_map_id == "builtin:solo_trail"

func _solo_trail_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var rolling := sin(x * 0.052) * 1.7 + cos(z * 0.041) * 1.4
	rolling += sin((x + z) * 0.021) * 2.1 + sin(x * 0.17 - z * 0.13) * 0.38
	var height: float = 3.2 + rolling
	# Global ridges are independent of tile edges, so streamed neighbours share
	# exactly the same height samples along every seam.
	var global_ridge := smoothstep(0.57, 0.82, _terrain_noise(p, 0.0085, 137.0))
	height += global_ridge * global_ridge * 18.0
	height += _irregular_peak(p, Vector2(30.0, 38.0), 39.0, 40.0, 0.4)
	height += _irregular_peak(p, REFINEMENT_HILL_CENTER, 34.0, REFINEMENT_HILL_RADIUS, 2.1)
	height += _irregular_peak(p, Vector2(230.0, 205.0), 43.0, 46.0, 4.2)
	height += _irregular_peak(p, Vector2(35.0, 220.0), 31.0, 47.0, 5.4)
	# Flatten both connected roads after hills, but before rivers. The path over
	# the northern hill is therefore walkable, while submerged crossings remain low.
	var path_flatten := 1.0 - smoothstep(3.2, 9.5, solo_trail_path_distance(x, z))
	var path_height := 3.1 + (_terrain_noise(p, 0.010, 211.0) - 0.5) * 1.0
	height = lerpf(height, path_height, path_flatten * 0.94)
	# A broad meadow keeps the player spawn readable and walkable.
	var clearing_weight := 1.0 - smoothstep(22.0, 46.0, p.distance_to(Vector2(130.0, 150.0)))
	height = lerpf(height, 3.0 + sin(x * 0.11) * 0.22 + cos(z * 0.09) * 0.18, clearing_weight)
	# The river cuts through the valley from west to east.
	var river_center := _solo_river_center(x)
	var river_side := z - river_center
	var river_distance := absf(river_side)
	var river_curvature := _solo_river_center(x + 2.0) - 2.0 * river_center + _solo_river_center(x - 2.0)
	var river_outer_side := -signf(river_curvature) if absf(river_curvature) > 0.001 else 0.0
	var is_outer_bank := signf(river_side) == river_outer_side
	var bank_noise := _terrain_noise(Vector2(x, z), REFINEMENT_MEDIUM_NOISE_SCALE, 19.0)
	var river_core_width := 7.0 + (bank_noise - 0.5) * 0.65
	# Outer bends cut narrower, steeper scarps. Inner bends spread a wider and
	# gentler depositional shelf, avoiding mirrored banks.
	var river_bank_width := (13.0 if is_outer_bank else 18.5) + (bank_noise - 0.5) * 2.4
	var river_weight := 1.0 - smoothstep(river_core_width, river_bank_width, river_distance)
	var bed_variation := (_terrain_noise(Vector2(x, z), REFINEMENT_LARGE_NOISE_SCALE, 43.0) - 0.5) * 0.24
	var river_floor := minf(-3.95, -4.55 + bed_variation + pow(river_distance / maxf(river_core_width, 0.1), 1.48) * 0.42)
	height = lerpf(height, river_floor, river_weight)
	# A flooded canyon branches northward from the main river.
	var ravine_x := _solo_ravine_center(z)
	var ravine_extent := 1.0
	var ravine_side := x - ravine_x
	var ravine_distance := absf(ravine_side)
	var ravine_curvature := _solo_ravine_center(z + 2.0) - 2.0 * ravine_x + _solo_ravine_center(z - 2.0)
	var ravine_outer_side := -signf(ravine_curvature) if absf(ravine_curvature) > 0.001 else 0.0
	var ravine_outer := signf(ravine_side) == ravine_outer_side
	var ravine_noise := _terrain_noise(Vector2(x, z), REFINEMENT_MEDIUM_NOISE_SCALE, 71.0)
	var ravine_core_width := 5.0 + (ravine_noise - 0.5) * 0.5
	var ravine_bank_width := (10.8 if ravine_outer else 15.4) + (ravine_noise - 0.5) * 1.8
	var ravine_weight := (1.0 - smoothstep(ravine_core_width, ravine_bank_width, ravine_distance)) * ravine_extent
	var canyon_floor := minf(-4.0, -4.62 + (_terrain_noise(Vector2(x, z), REFINEMENT_LARGE_NOISE_SCALE, 89.0) - 0.5) * 0.20 + pow(ravine_distance / maxf(ravine_core_width, 0.1), 1.42) * 0.46)
	height = lerpf(height, canyon_floor, ravine_weight)
	return height


func _solo_river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0


func _solo_ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0


func solo_trail_path_center_x(z: float) -> float:
	if z < 20.0:
		return 218.0 + sin((z - 20.0) * 0.016) * 28.0
	if z > 246.0:
		return 35.0 + sin((z - 246.0) * 0.016) * 28.0
	var t := clampf((246.0 - z) / 226.0, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * inverse * 35.0 + 3.0 * inverse * inverse * t * 45.0 + 3.0 * inverse * t * t * 225.0 + t * t * t * 218.0


func solo_trail_horizontal_path_z(x: float) -> float:
	return 132.0 + sin(x * 0.014 + 0.8) * 34.0 + sin(x * 0.037) * 8.0


func solo_trail_path_distance(x: float, z: float) -> float:
	return minf(absf(x - solo_trail_path_center_x(z)), absf(z - solo_trail_horizontal_path_z(x)))


func solo_trail_is_water(x: float, z: float) -> bool:
	return absf(z - _solo_river_center(x)) <= 7.2 or absf(x - _solo_ravine_center(z)) <= 5.2


func _terrain_noise(point: Vector2, scale_value: float, seed_offset: float) -> float:
	var q := point * scale_value
	var seed_phase := REFINEMENT_SEED + seed_offset
	var value := sin(q.x * 1.17 + q.y * 0.43 + seed_phase) * 0.50
	value += cos(q.y * 1.31 - q.x * 0.37 + seed_phase * 0.73) * 0.31
	value += sin((q.x + q.y) * 0.71 - seed_phase * 0.41) * 0.19
	return value * 0.5 + 0.5

func _height_peak(point: Vector2, center: Vector2, amplitude: float, radius: float) -> float:
	var normalized_distance := point.distance_to(center) / radius
	if normalized_distance >= 1.0:
		return 0.0
	var profile := 1.0 - normalized_distance * normalized_distance
	return amplitude * profile * profile


func _irregular_peak(point: Vector2, center: Vector2, amplitude: float, radius: float, phase: float) -> float:
	var offset := point - center
	# Low-frequency domain warping makes each massif lean and branch instead of
	# remaining a radial mound. It fades completely at the foot of the hill.
	var warp := Vector2(
		_terrain_noise(point, 0.0105, phase * 53.0) - 0.5,
		_terrain_noise(point, 0.0125, phase * 67.0) - 0.5
	) * radius * 0.24
	offset += warp
	var angle := atan2(offset.y, offset.x)
	var radial_warp := 1.0 + sin(angle * 3.0 + phase) * 0.16 + sin(angle * 5.0 - phase * 0.7) * 0.09
	var skewed := Vector2(offset.x * (0.88 + 0.08 * sin(phase)), offset.y * (1.12 - 0.06 * cos(phase)))
	var normalized_distance := skewed.length() / (radius * radial_warp)
	if normalized_distance >= 1.0:
		return 0.0
	var profile := 1.0 - normalized_distance * normalized_distance
	var mask := pow(1.0 - smoothstep(0.0, 1.0, normalized_distance), REFINEMENT_FADE_INTENSITY)
	var large := (_terrain_noise(point, REFINEMENT_LARGE_NOISE_SCALE, phase * 17.0) - 0.5) * 0.34
	var medium_source := _terrain_noise(point, REFINEMENT_MEDIUM_NOISE_SCALE, phase * 29.0)
	var ridges := (1.0 - absf(medium_source * 2.0 - 1.0) - 0.5) * 0.22
	var fine := (_terrain_noise(point, REFINEMENT_FINE_NOISE_SCALE, phase * 41.0) - 0.5) * 0.045
	var deformation := (large + ridges + fine) * mask * REFINEMENT_DEFORMATION_STRENGTH
	var shoulder := sin(point.x * 0.071 + phase) * cos(point.y * 0.063 - phase) * 0.055 * mask
	# Short, broken rock shelves: the angular gate prevents horizontal rings,
	# while the radial gate lets shelves disappear back into the slope.
	var shelf_phase := normalized_distance * 9.0 + medium_source * 1.7 + phase
	var shelf_band := smoothstep(0.72, 0.91, sin(shelf_phase) * 0.5 + 0.5)
	var shelf_arc := smoothstep(0.45, 0.78, _terrain_noise(point, 0.024, phase * 83.0))
	var shelf_mask := shelf_band * shelf_arc * smoothstep(0.22, 0.48, normalized_distance) * (1.0 - smoothstep(0.78, 0.96, normalized_distance))
	var erosion_gully := pow(maxf(0.0, sin(angle * 2.0 + phase + medium_source * 1.8)), 4.0)
	erosion_gully *= smoothstep(0.25, 0.62, normalized_distance) * (1.0 - smoothstep(0.76, 0.98, normalized_distance))
	var structural := shelf_mask * HIGHLAND_LEDGE_STRENGTH - erosion_gully * HIGHLAND_EROSION_STRENGTH
	# Broad offset shoulders break the last remaining single-summit silhouette.
	# They use low frequency fields, so the form reads from afar without noisy ground.
	var summit_breakup := lerpf(0.76, 1.18, _terrain_noise(point, 0.014, phase * 97.0))
	var ridge_bias := 1.0 + 0.13 * sin(angle * 2.0 - phase) * smoothstep(0.18, 0.70, normalized_distance)
	var local := skewed / radius
	var ridge_direction := Vector2(cos(phase * 0.83), sin(phase * 0.83))
	var ridge_along := local.dot(ridge_direction)
	var ridge_across := local.dot(Vector2(-ridge_direction.y, ridge_direction.x))
	# A shallow saddle divides the summit into unequal shoulders. The cut is
	# strongest near the crown and vanishes before reaching the foothills.
	var saddle := exp(-ridge_across * ridge_across / 0.018) * exp(-ridge_along * ridge_along / 0.34)
	var asymmetric_crown := 1.0 - saddle * 0.24
	asymmetric_crown += exp(-local.distance_squared_to(ridge_direction * 0.31) / 0.055) * 0.18
	asymmetric_crown += exp(-local.distance_squared_to(-ridge_direction * 0.22) / 0.085) * 0.09
	return amplitude * profile * profile * summit_breakup * ridge_bias * asymmetric_crown * maxf(0.50, 1.0 + deformation + shoulder + structural)

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
	var terrain_size := SOLO_TRAIL_SIZE if _is_solo_trail() else Vector2i(GRID_WIDTH, GRID_HEIGHT)
	for z: int in range(terrain_size.y):
		for x: int in range(terrain_size.x):
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
	var material := TERRAIN_GROUND_MATERIAL.duplicate() as ShaderMaterial
	material.set_shader_parameter("grid_size", get_exploration_world_size())
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

func show_ability_range(actor: TacticalUnit, ability_name: String) -> void:
	clear_ability_range()
	var ability := AbilityCatalog.get_ability(ability_name)
	if ability.is_empty():
		return
	var ability_range := int(ability.get("range", 1))
	var target_kind := String(ability.get("target", "enemy"))
	if target_kind == "self":
		return
	var valid_target_cells: Dictionary[Vector2i, bool] = {}
	for unit: TacticalUnit in get_units():
		if unit == actor or unit.is_dead():
			continue
		if target_kind == "enemy" and unit.team_id == actor.team_id:
			continue
		if target_kind == "ally" and unit.team_id != actor.team_id:
			continue
		var dist := maxi(absi(unit.grid_position.x - actor.grid_position.x), absi(unit.grid_position.y - actor.grid_position.y))
		if dist <= ability_range:
			valid_target_cells[unit.grid_position] = true
	for dz: int in range(-ability_range, ability_range + 1):
		for dx: int in range(-ability_range, ability_range + 1):
			if dx == 0 and dz == 0:
				continue
			var cell := actor.grid_position + Vector2i(dx, dz)
			if not is_inside_grid(cell):
				continue
			if maxi(absi(dx), absi(dz)) > ability_range:
				continue
			_create_ability_marker(cell, valid_target_cells.has(cell))

func clear_ability_range() -> void:
	for marker: MeshInstance3D in _ability_range_markers.values():
		marker.queue_free()
	_ability_range_markers.clear()

func _create_ability_marker(cell: Vector2i, is_valid_target: bool) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "AbilityHighlight_%02d_%02d" % [cell.x, cell.y]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.86, 0.035, 0.86)
	marker.mesh = mesh
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.10, 0.0)
	marker.material_override = _ability_target_material if is_valid_target else _ability_range_material
	add_child(marker)
	_ability_range_markers[cell] = marker

func _create_ability_range_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.1, 0.9, 0.30)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.4, 0.05, 0.75, 1.0)
	material.emission_energy_multiplier = 0.7
	return material

func _create_ability_target_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.65, 0.0, 0.80)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.0, 1.0)
	material.emission_energy_multiplier = 2.0
	return material

func _create_danger_marker(cell: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "DangerHighlight_%02d_%02d" % [cell.x, cell.y]
	marker.mesh = _create_cell_outline_mesh(0.86)
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.12, 0.0)
	marker.material_override = _danger_material
	add_child(marker)
	_danger_markers[cell] = marker

func _create_cell_outline_mesh(size_value: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half_size := size_value * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half_size, 0.0, -half_size),
		Vector3(half_size, 0.0, -half_size),
		Vector3(half_size, 0.0, half_size),
		Vector3(-half_size, 0.0, half_size)
	]
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index: int in range(4):
		mesh.surface_add_vertex(corners[index])
		mesh.surface_add_vertex(corners[(index + 1) % 4])
	mesh.surface_end()
	return mesh


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
	marker.mesh = _create_cell_outline_mesh(0.86)
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
