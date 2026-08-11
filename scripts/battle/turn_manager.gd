class_name TurnManager
extends Node

signal battle_started
signal round_started(round_number: int)
signal turn_started(unit: TacticalUnit)
signal turn_ended(unit: TacticalUnit)
signal active_unit_changed(unit: TacticalUnit)
signal initiative_queue_changed(units: Array[TacticalUnit])

var participants: Array[TacticalUnit] = []
var turn_order: Array[TacticalUnit] = []
var current_turn_index: int = -1
var active_unit: TacticalUnit
var round_number: int = 0
var battle_active: bool = false
var _ending_turn: bool = false
var _rng := RandomNumberGenerator.new()

func start_battle(units: Array[TacticalUnit]) -> void:
	participants.clear()
	for unit: TacticalUnit in units:
		if not is_instance_valid(unit):
			continue
		if unit.initiative_tiebreaker < 0:
			unit.initiative_tiebreaker = _rng.randi_range(0, 1_000_000)
		if not unit.died.is_connected(_on_participant_died):
			unit.died.connect(_on_participant_died)
		participants.append(unit)
	battle_active = true
	round_number = 0
	battle_started.emit()
	_start_next_round()

func end_current_turn() -> void:
	if not battle_active or active_unit == null or _ending_turn:
		return
	_ending_turn = true
	var ended_unit := active_unit
	ended_unit.has_finished_turn = true
	ended_unit.end_turn_statuses()
	ended_unit.set_active(false)
	turn_ended.emit(ended_unit)
	active_unit = null
	active_unit_changed.emit(null)
	_ending_turn = false
	_advance_turn()

func is_units_turn(unit: TacticalUnit) -> bool:
	return battle_active and active_unit == unit and unit.is_alive and not unit.has_finished_turn

func get_initiative_preview() -> Array[TacticalUnit]:
	var preview: Array[TacticalUnit] = []
	for unit: TacticalUnit in turn_order:
		if is_instance_valid(unit) and unit.is_alive and not unit.is_dead():
			preview.append(unit)
	return preview

func _start_next_round() -> void:
	round_number += 1
	turn_order.clear()
	for unit: TacticalUnit in participants:
		if is_instance_valid(unit) and unit.is_alive and not unit.is_dead():
			unit.has_finished_turn = false
			turn_order.append(unit)
	_sort_turn_order()
	current_turn_index = -1
	round_started.emit(round_number)
	initiative_queue_changed.emit(get_initiative_preview())
	_advance_turn()

func _sort_turn_order() -> void:
	turn_order.sort_custom(func(a: TacticalUnit, b: TacticalUnit) -> bool:
		if a.initiative == b.initiative:
			return a.initiative_tiebreaker > b.initiative_tiebreaker
		return a.initiative > b.initiative
	)

func _advance_turn() -> void:
	current_turn_index += 1
	while current_turn_index < turn_order.size():
		var candidate: TacticalUnit = turn_order[current_turn_index]
		if is_instance_valid(candidate) and candidate.is_alive and not candidate.is_dead():
			_begin_turn(candidate)
			return
		current_turn_index += 1
	_start_next_round()

func _begin_turn(unit: TacticalUnit) -> void:
	active_unit = unit
	unit.has_finished_turn = false
	unit.reset_action_points()
	if unit.is_dead():
		return
	unit.set_active(true)
	active_unit_changed.emit(unit)
	initiative_queue_changed.emit(get_initiative_preview())
	turn_started.emit(unit)

func add_participant(unit: TacticalUnit) -> void:
	if not is_instance_valid(unit) or participants.has(unit):
		return
	if unit.initiative_tiebreaker < 0:
		unit.initiative_tiebreaker = _rng.randi_range(0, 1_000_000)
	if not unit.died.is_connected(_on_participant_died):
		unit.died.connect(_on_participant_died)
	participants.append(unit)
	unit.has_finished_turn = true
	turn_order.append(unit)
	_sort_turn_order()
	initiative_queue_changed.emit(get_initiative_preview())

func _on_participant_died(unit: TacticalUnit) -> void:
	var removed_index := turn_order.find(unit)
	participants.erase(unit)
	if removed_index >= 0:
		turn_order.remove_at(removed_index)
		if removed_index <= current_turn_index:
			current_turn_index -= 1
	initiative_queue_changed.emit(get_initiative_preview())
	if active_unit == unit:
		active_unit = null
		call_deferred("_advance_turn")
