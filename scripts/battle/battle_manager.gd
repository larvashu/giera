class_name BattleManager
extends Node3D

@export var grid_manager: GridManager
@export var turn_manager: TurnManager
@export var player_controller: PlayerController
@export var battle_ui: BattleUI
@export var tactical_camera: TacticalCamera

@onready var game_session := get_node("/root/GameSession") as GameSessionState
@onready var team_save_manager := get_node("/root/TeamSaveManager") as TeamSaveService

var selected_unit: TacticalUnit
var _pending_unit_target: TacticalUnit
var _pending_move_cell: Vector2i = Vector2i(-999, -999)
var _selected_ability_index: int = -1
var _selected_ability_name: String = ""
var _enemy_turn_token: int = 0
var _input_enabled: bool = true
var _exploration_mode: bool = false
var _grid_was_visible_before_exploration: bool = false
var _danger_zone_mob: WorldMob = null
var _spawning_encounter: bool = false

func _ready() -> void:
	player_controller.unit_selected.connect(_on_unit_selected)
	player_controller.grid_cell_clicked.connect(_on_grid_cell_clicked)
	player_controller.world_mob_clicked.connect(_on_world_mob_clicked)
	battle_ui.end_turn_requested.connect(_on_end_turn_requested)
	battle_ui.exit_to_main_menu_requested.connect(_on_exit_to_main_menu_requested)
	battle_ui.initiative_unit_selected.connect(_on_unit_selected)
	battle_ui.initiative_unit_selected.connect(_on_initiative_card_focus)
	battle_ui.ability_selected.connect(_on_ability_selected)
	tactical_camera.exploration_mode_changed.connect(_on_exploration_mode_changed)
	tactical_camera.tactical_grid_toggle_requested.connect(_on_tactical_grid_toggle_requested)
	tactical_camera.torch_state_changed.connect(_on_torch_state_changed)
	tactical_camera.mob_spotted.connect(_on_mob_spotted)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.active_unit_changed.connect(_on_active_unit_changed)
	turn_manager.initiative_queue_changed.connect(_on_initiative_queue_changed)
	call_deferred("_start_battle")

func _start_battle() -> void:
	if game_session.has_match_configuration():
		grid_manager.spawn_configured_teams(game_session.get_composition(1), game_session.get_composition(2), team_save_manager)
	else:
		grid_manager.spawn_default_units()
	var units := grid_manager.get_units()
	for unit: TacticalUnit in units:
		unit.stats_changed.connect(_on_unit_stats_changed.bind(unit))
	turn_manager.start_battle(units)

func _on_initiative_card_focus(unit: TacticalUnit) -> void:
	if unit == null or not is_instance_valid(unit) or tactical_camera == null:
		return
	if unit.faction == TacticalUnit.Faction.ENEMY or not game_session.is_team_locally_controllable(unit.team_id):
		return
	tactical_camera.switch_focus_unit(unit)

func _on_unit_selected(unit: TacticalUnit) -> void:
	if not _input_enabled or unit == null:
		return
	var repeated_target: bool = _pending_unit_target == unit and unit != turn_manager.active_unit
	_clear_pending_move()
	if selected_unit != null and is_instance_valid(selected_unit) and selected_unit != unit:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	battle_ui.show_unit_details(selected_unit)
	if not game_session.is_team_locally_controllable(unit.team_id):
		grid_manager.show_enemy_range(unit)
	else:
		grid_manager.clear_danger_zone()
	_refresh_movement_highlights()
	if _selected_ability_index >= 0 and unit != turn_manager.active_unit:
		_execute_selected_ability(unit)
	elif repeated_target:
		_request_action_on_target(unit)
	else:
		_pending_unit_target = unit
		if unit != turn_manager.active_unit:
			battle_ui.set_phase_message("Cel: %s — kliknij ponownie, aby wybrac akcje" % unit.display_name)

func _on_ability_selected(index: int, ability_name: String) -> void:
	_selected_ability_index = index
	_selected_ability_name = ability_name
	_clear_pending_targets()
	_refresh_movement_highlights()
	if index >= 0:
		battle_ui.set_phase_message("Wybrano: %s — kliknij cel, aby uzyc" % ability_name)
	else:
		battle_ui.set_phase_message("Nie wybrano umiejetnosci")

func _execute_selected_ability(target: TacticalUnit) -> void:
	if not _can_control_active_unit():
		return
	battle_ui.set_phase_message("%s → %s (efekt umiejetnosci oczekuje na implementacje)" % [_selected_ability_name, target.display_name])
	_pending_unit_target = null

func _request_action_on_target(target: TacticalUnit) -> void:
	var active := turn_manager.active_unit
	if not _can_control_active_unit() or target == active:
		return
	battle_ui.set_phase_message("Akcja na %s — system zdolnosci jest przygotowany, brak aktywnych atakow" % target.display_name)
	_pending_unit_target = null

func _on_grid_cell_clicked(cell: Vector2i) -> void:
	if not _can_control_active_unit() or not grid_manager.is_cell_highlighted(cell):
		_clear_pending_targets()
		_refresh_movement_highlights()
		return
	_pending_unit_target = null
	if _pending_move_cell != cell:
		_pending_move_cell = cell
		_refresh_movement_highlights()
		grid_manager.set_preview_cell(cell)
		battle_ui.set_phase_message("Ruch na pole %d, %d — kliknij ponownie, aby potwierdzic" % [cell.x, cell.y])
		return
	await _execute_move(cell)

func _execute_move(cell: Vector2i) -> void:
	var active := turn_manager.active_unit
	if active == null:
		return
	var path := grid_manager.find_path(active.grid_position, cell, active.current_action_points)
	var cost: int = path.size()
	if path.is_empty() or not active.can_spend_action_points(cost):
		_clear_pending_move()
		_refresh_movement_highlights()
		return
	if not grid_manager.move_occupant(active, cell) or not active.spend_action_points(cost):
		return
	_clear_pending_targets()
	grid_manager.clear_highlights()
	await active.move_along_path(path, GridManager.CELL_SIZE, func(path_cell: Vector2i) -> float:
		return grid_manager.terrain_height(float(path_cell.x), float(path_cell.y))
	)
	if not is_instance_valid(active) or active.is_dead():
		return
	selected_unit = active
	active.set_selected(true)
	battle_ui.show_unit_details(active)
	_refresh_movement_highlights()
	battle_ui.refresh_details()
	battle_ui.set_phase_message("Ruch zakonczony — pozostalo PA: %d" % active.current_action_points)
	_check_world_mob_encounter(active)

func _can_control_active_unit() -> bool:
	var active := turn_manager.active_unit
	return (
		_input_enabled
		and active != null
		and is_instance_valid(active)
		and game_session.is_team_locally_controllable(active.team_id)
		and not active.is_moving()
		and active.current_action_points > 0
	)

func _refresh_movement_highlights() -> void:
	grid_manager.clear_highlights()
	if _can_control_active_unit():
		grid_manager.show_reachable_cells(turn_manager.active_unit)
		if _pending_move_cell.x > -900:
			grid_manager.set_preview_cell(_pending_move_cell)

func _clear_pending_move() -> void:
	_pending_move_cell = Vector2i(-999, -999)

func _clear_pending_targets() -> void:
	_clear_pending_move()
	_pending_unit_target = null

func _on_round_started(round_value: int) -> void:
	battle_ui.set_round(round_value)

func _on_turn_started(unit: TacticalUnit) -> void:
	var is_enemy := unit.faction == TacticalUnit.Faction.ENEMY
	_input_enabled = not is_enemy and game_session.is_team_locally_controllable(unit.team_id)
	_clear_pending_targets()
	_selected_ability_index = -1
	_selected_ability_name = ""
	_update_active_ui(unit)
	if _input_enabled:
		grid_manager.clear_danger_zone()
		_on_unit_selected(unit)
		_refresh_movement_highlights()
	elif is_enemy or game_session.should_auto_skip_team(unit.team_id):
		grid_manager.clear_highlights()
		grid_manager.show_enemy_range(unit)
		_execute_enemy_turn(unit)
	else:
		grid_manager.clear_highlights()

func _on_turn_ended(unit: TacticalUnit) -> void:
	_enemy_turn_token += 1
	_input_enabled = false
	_clear_pending_targets()
	grid_manager.clear_highlights()
	battle_ui.refresh_details()
	unit.set_active(false)

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	_update_active_ui(unit)

func _update_active_ui(unit: TacticalUnit) -> void:
	var can_end := unit != null and _input_enabled and game_session.is_team_locally_controllable(unit.team_id)
	var phase := "%s — inicjatywa %d" % [game_session.controller_label(unit.team_id, unit.owner_player_id), unit.initiative] if unit != null else "Zmiana tury"
	battle_ui.set_active_unit(unit, can_end, phase)

func _on_initiative_queue_changed(units: Array[TacticalUnit]) -> void:
	battle_ui.set_initiative_order(units)

func _on_unit_stats_changed(_unit: TacticalUnit) -> void:
	battle_ui.refresh_details()
	battle_ui.refresh_initiative()

func _on_end_turn_requested() -> void:
	var active := turn_manager.active_unit
	if active == null or not _input_enabled or not game_session.is_team_locally_controllable(active.team_id) or active.is_moving():
		return
	turn_manager.end_current_turn()

func _on_exit_to_main_menu_requested() -> void:
	_enemy_turn_token += 1
	_input_enabled = false
	grid_manager.clear_highlights()
	game_session.clear_match_configuration()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _on_exploration_mode_changed(enabled: bool, unit: TacticalUnit, world_position: Vector3) -> void:
	_exploration_mode = enabled
	_input_enabled = not enabled and unit != null and game_session.is_team_locally_controllable(unit.team_id)
	battle_ui.set_exploration_mode(enabled)
	if enabled:
		_grid_was_visible_before_exploration = grid_manager.is_grid_visible()
		grid_manager.set_grid_visible(false)
		_clear_pending_targets()
		grid_manager.clear_highlights()
		grid_manager.clear_danger_zone()
		_danger_zone_mob = null
		battle_ui.set_phase_message("Tryb eksploracji — TAB: powrot do walki")
		return
	if unit != null and is_instance_valid(unit):
		grid_manager.relocate_occupant_from_world(unit, world_position)
		selected_unit = unit
		unit.set_selected(true)
	_refresh_movement_highlights()
	grid_manager.set_grid_visible(_grid_was_visible_before_exploration)
	battle_ui.refresh_details()
	battle_ui.set_phase_message("Tryb walki — TAB: eksploracja")

func _on_torch_state_changed(enabled: bool) -> void:
	battle_ui.set_phase_message("Pochodnia: %s — F: schowaj/wyciagnij" % ("wlaczona" if enabled else "wylaczona"))

func _on_world_mob_clicked(mob: WorldMob) -> void:
	if _exploration_mode:
		return
	if _danger_zone_mob == mob:
		grid_manager.clear_danger_zone()
		_danger_zone_mob = null
		return
	_danger_zone_mob = mob
	grid_manager.show_danger_zone(mob.global_position, tactical_camera.vision_range)

func _check_world_mob_encounter(unit: TacticalUnit) -> void:
	for node: Node in get_tree().get_nodes_in_group("world_mobs"):
		var mob := node as WorldMob
		if mob == null or not is_instance_valid(mob):
			continue
		var mob_cell := Vector2i(roundi(mob.global_position.x), roundi(mob.global_position.z))
		var dist := Vector2(float(unit.grid_position.x - mob_cell.x), float(unit.grid_position.y - mob_cell.y)).length()
		if dist <= tactical_camera.vision_range:
			_spawn_mob_encounter(mob)
			return

func _spawn_mob_encounter(mob: WorldMob) -> void:
	if _spawning_encounter or not is_instance_valid(mob):
		return
	_spawning_encounter = true
	var mob_display_name := mob.display_name
	var mob_type := mob.character_type
	var active := turn_manager.active_unit
	if active == null or not is_instance_valid(active):
		push_warning("BattleManager._spawn_mob_encounter: active_unit is null")
		_spawning_encounter = false
		return
	var mob_origin := Vector2i(roundi(mob.global_position.x), roundi(mob.global_position.z))
	mob_origin.x = clampi(mob_origin.x, 0, GridManager.GRID_WIDTH - 1)
	mob_origin.y = clampi(mob_origin.y, 0, GridManager.GRID_HEIGHT - 1)
	var mob_cell := grid_manager.find_nearest_free_spawn_cell(mob_origin)
	var spawned_unit := grid_manager.spawn_enemy_at(mob_type, mob_cell)
	if spawned_unit == null:
		push_warning("BattleManager._spawn_mob_encounter: spawn_enemy_at returned null for type '%s'" % mob_type)
		_spawning_encounter = false
		return
	if _danger_zone_mob == mob:
		grid_manager.clear_danger_zone()
		_danger_zone_mob = null
	mob.queue_free()
	spawned_unit.stats_changed.connect(_on_unit_stats_changed.bind(spawned_unit))
	turn_manager.add_participant(spawned_unit)
	battle_ui.set_phase_message("Spotkanie z %s! Walka!" % mob_display_name)
	if is_instance_valid(active) and not active.is_dead():
		tactical_camera.focus_on_unit(active)
	grid_manager.show_enemy_range(spawned_unit)
	_spawning_encounter = false

func _on_mob_spotted(mob: WorldMob) -> void:
	if not _exploration_mode:
		return
	tactical_camera.exit_exploration_mode()
	_spawn_mob_encounter(mob)

func _on_tactical_grid_toggle_requested() -> void:
	if _exploration_mode:
		return
	var grid_is_visible := grid_manager.toggle_grid_visibility()
	battle_ui.set_phase_message("Siatka taktyczna: %s" % ("wlaczona" if grid_is_visible else "wylaczona"))

func _schedule_enemy_turn_end(enemy: TacticalUnit) -> void:
	_enemy_turn_token += 1
	var token := _enemy_turn_token
	await get_tree().create_timer(0.4).timeout
	if token == _enemy_turn_token and turn_manager.active_unit == enemy:
		turn_manager.end_current_turn()

func _execute_enemy_turn(unit: TacticalUnit) -> void:
	_enemy_turn_token += 1
	var token := _enemy_turn_token
	await get_tree().create_timer(0.6).timeout
	if token != _enemy_turn_token or not is_instance_valid(unit) or unit.is_dead():
		return

	var target := _find_nearest_player_unit(unit)
	if target == null:
		turn_manager.end_current_turn()
		return

	if unit.current_action_points > 0 and not _is_adjacent(unit.grid_position, target.grid_position):
		await _ai_move_towards(unit, target)
		if is_instance_valid(unit):
			grid_manager.show_enemy_range(unit)

	if is_instance_valid(unit) and not unit.is_dead() and is_instance_valid(target) and not target.is_dead():
		if _is_adjacent(unit.grid_position, target.grid_position):
			_ai_attack(unit, target)
			await get_tree().create_timer(0.5).timeout

	if is_instance_valid(unit) and not unit.is_dead() and token == _enemy_turn_token:
		turn_manager.end_current_turn()

func _find_nearest_player_unit(from: TacticalUnit) -> TacticalUnit:
	var best: TacticalUnit = null
	var best_dist := INF
	for node: Node in get_tree().get_nodes_in_group("tactical_units"):
		var u := node as TacticalUnit
		if u == null or u.is_dead() or u.team_id == from.team_id:
			continue
		var dist := Vector2(float(from.grid_position.x - u.grid_position.x), float(from.grid_position.y - u.grid_position.y)).length()
		if dist < best_dist:
			best_dist = dist
			best = u
	return best

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1 and a != b

func _ai_move_towards(unit: TacticalUnit, target: TacticalUnit) -> void:
	if not is_instance_valid(target) or target.is_dead():
		return
	var best_path: Array[Vector2i] = []
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var adj := target.grid_position + Vector2i(dx, dz)
			var path := grid_manager.find_path(unit.grid_position, adj, unit.current_action_points)
			if not path.is_empty() and (best_path.is_empty() or path.size() < best_path.size()):
				best_path = path

	if best_path.is_empty():
		var target_pos := Vector2(float(target.grid_position.x), float(target.grid_position.y))
		var reachable := grid_manager.get_reachable_cells(unit.grid_position, unit.current_action_points)
		var closest_cell := Vector2i(-1, -1)
		var closest_dist := INF
		for cell: Vector2i in reachable:
			var d := Vector2(float(cell.x), float(cell.y)).distance_to(target_pos)
			if d < closest_dist:
				closest_dist = d
				closest_cell = cell
		if closest_cell.x >= 0:
			best_path = grid_manager.find_path(unit.grid_position, closest_cell, unit.current_action_points)

	if best_path.is_empty():
		return
	var destination := best_path[best_path.size() - 1]
	if not grid_manager.move_occupant(unit, destination):
		return
	unit.spend_action_points(best_path.size())
	await unit.move_along_path(best_path, GridManager.CELL_SIZE, func(cell: Vector2i) -> float:
		return grid_manager.terrain_height(float(cell.x), float(cell.y))
	)

func _ai_attack(attacker: TacticalUnit, target: TacticalUnit) -> void:
	var damage := maxi(1, 1 + attacker.attributes.get(&"sila", 0))
	battle_ui.set_phase_message("%s atakuje %s! Obrazenia: %d" % [attacker.display_name, target.display_name, damage])
	target.take_damage(damage)
	battle_ui.refresh_details()
