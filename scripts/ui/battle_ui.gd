class_name BattleUI
extends CanvasLayer

signal end_turn_requested
signal exit_to_main_menu_requested
signal initiative_unit_selected(unit: TacticalUnit)
signal ability_selected(index: int, ability_name: String)

const ACTIVE_AP_COLOR := Color(0.18, 0.9, 0.34, 1.0)
const SPENT_AP_COLOR := Color(0.32, 0.35, 0.38, 1.0)
const PLAYER_COLORS: Array[Color] = [
	Color(0.18, 0.68, 1.0, 1.0),
	Color(0.95, 0.28, 0.22, 1.0),
	Color(0.65, 0.35, 1.0, 1.0),
	Color(1.0, 0.72, 0.15, 1.0)
]

@onready var round_label: Label = %RoundLabel
@onready var active_label: Label = %ActiveLabel
@onready var phase_label: Label = %PhaseLabel
@onready var initiative_cards: HBoxContainer = %InitiativeCards
@onready var details_label: Label = %DetailsLabel
@onready var action_point_dots: HBoxContainer = %ActionPointDots
@onready var end_turn_button: Button = %EndTurnButton
@onready var skill_bar: PanelContainer = %SkillBar
@onready var skill_caption: Label = %SkillCaption
@onready var skill_buttons: HBoxContainer = %SkillButtons

var _displayed_unit: TacticalUnit
var _active_unit: TacticalUnit
var _initiative_units: Array[TacticalUnit] = []
var _selected_ability_index: int = -1
var _exploration_mode: bool = false
var _can_end_active_turn: bool = false

func _ready() -> void:
	end_turn_button.pressed.connect(_request_end_turn)
	end_turn_button.disabled = true
	skill_bar.visible = false
	details_label.text = "Brak zaznaczonej jednostki"
	_update_action_point_dots(null)

func set_round(round_value: int) -> void:
	round_label.text = "Runda: %d" % round_value

func set_phase_message(message: String) -> void:
	phase_label.text = message

func set_active_unit(unit: TacticalUnit, can_end_turn: bool = false, phase_text: String = "") -> void:
	_active_unit = unit
	_can_end_active_turn = can_end_turn
	if unit == null:
		active_label.text = "Aktywna jednostka: -"
		phase_label.text = "Zmiana tury"
		end_turn_button.disabled = true
	else:
		active_label.text = "Aktywna jednostka: %s" % unit.display_name
		phase_label.text = phase_text if not phase_text.is_empty() else "Tura w toku"
		end_turn_button.disabled = _exploration_mode or not can_end_turn or unit.has_finished_turn
	_rebuild_skill_bar()
	refresh_details()
	refresh_initiative()

func set_exploration_mode(enabled: bool) -> void:
	_exploration_mode = enabled
	end_turn_button.disabled = enabled or not _can_end_active_turn or _active_unit == null or _active_unit.has_finished_turn
	skill_bar.visible = not enabled and _active_unit != null and not _active_unit.abilities.is_empty()

func _rebuild_skill_bar() -> void:
	for child: Node in skill_buttons.get_children():
		child.queue_free()
	_selected_ability_index = -1
	if _active_unit == null or _active_unit.abilities.is_empty():
		skill_bar.visible = false
		return
	skill_bar.visible = true
	skill_caption.text = "Umiejetnosci: %s" % _active_unit.display_name
	for index: int in range(mini(9, _active_unit.abilities.size())):
		var button := Button.new()
		button.custom_minimum_size = Vector2(150.0, 44.0)
		button.toggle_mode = true
		button.text = "%d  %s" % [index + 1, _active_unit.abilities[index]]
		button.pressed.connect(_select_ability.bind(index))
		skill_buttons.add_child(button)

func _select_ability(index: int) -> void:
	if _active_unit == null or index < 0 or index >= _active_unit.abilities.size():
		return
	var new_index: int = -1 if _selected_ability_index == index else index
	_selected_ability_index = new_index
	for button_index: int in range(skill_buttons.get_child_count()):
		var button := skill_buttons.get_child(button_index) as Button
		button.button_pressed = button_index == _selected_ability_index
	var ability_name: String = _active_unit.abilities[_selected_ability_index] if _selected_ability_index >= 0 else ""
	ability_selected.emit(_selected_ability_index, ability_name)

func set_initiative_order(units: Array[TacticalUnit]) -> void:
	_initiative_units = units.duplicate()
	refresh_initiative()

func refresh_initiative() -> void:
	for child: Node in initiative_cards.get_children():
		child.queue_free()
	for unit: TacticalUnit in _initiative_units:
		if unit == null or not is_instance_valid(unit) or unit.is_dead():
			continue
		initiative_cards.add_child(_create_initiative_card(unit))

func _create_initiative_card(unit: TacticalUnit) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(148.0, 72.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.94)
	style.border_color = Color(1.0, 0.84, 0.25, 1.0) if unit == _active_unit else Color(0.22, 0.28, 0.34, 1.0)
	var border_width: int = 3 if unit == _active_unit else 1
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7.0
	style.content_margin_right = 9.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_initiative_card_input.bind(unit))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(52.0, 58.0)
	var color_index: int = clampi(unit.owner_player_id - 1, 0, PLAYER_COLORS.size() - 1)
	portrait.color = PLAYER_COLORS[color_index]
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = unit.display_name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 15)
	text_box.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "HP %d / %d" % [unit.current_health, unit.max_health]
	hp_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
	hp_label.add_theme_font_size_override("font_size", 13)
	text_box.add_child(hp_label)

	var initiative_label := Label.new()
	initiative_label.text = "INI %d" % unit.initiative
	initiative_label.add_theme_color_override("font_color", Color(0.68, 0.75, 0.82, 1.0))
	initiative_label.add_theme_font_size_override("font_size", 12)
	text_box.add_child(initiative_label)
	return panel

func _on_initiative_card_input(event: InputEvent, unit: TacticalUnit) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			initiative_unit_selected.emit(unit)

func show_unit_details(unit: TacticalUnit) -> void:
	if _displayed_unit != null and is_instance_valid(_displayed_unit):
		var callable := Callable(self, "_on_displayed_unit_stats_changed")
		if _displayed_unit.stats_changed.is_connected(callable):
			_displayed_unit.stats_changed.disconnect(callable)
	_displayed_unit = unit
	if _displayed_unit != null:
		_displayed_unit.stats_changed.connect(_on_displayed_unit_stats_changed)
	refresh_details()

func refresh_details() -> void:
	var unit := _displayed_unit if is_instance_valid(_displayed_unit) else _active_unit
	if unit == null or not is_instance_valid(unit):
		details_label.text = "Brak zaznaczonej jednostki"
		_update_action_point_dots(null)
		return
	var team_name := "Gracz 1" if unit.team_id == 0 else "Gracz 2 / Przeciwnik"
	var status := "Aktywna tura" if unit == _active_unit and not unit.has_finished_turn else "Tura zakonczona" if unit.has_finished_turn else "Oczekuje"
	details_label.text = "%s\nDruzyna: %s\nHP: %d / %d\nInicjatywa: %d\nStatus: %s" % [
		unit.display_name, team_name,
		unit.current_health, unit.max_health,
		unit.initiative, status
	]
	_update_action_point_dots(unit)

func _update_action_point_dots(unit: TacticalUnit) -> void:
	for child: Node in action_point_dots.get_children():
		child.queue_free()
	if unit == null:
		action_point_dots.visible = false
		return
	action_point_dots.visible = true
	for index: int in range(unit.max_action_points):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16.0, 16.0)
		var style := StyleBoxFlat.new()
		style.bg_color = ACTIVE_AP_COLOR if index < unit.current_action_points else SPENT_AP_COLOR
		style.set_corner_radius_all(8)
		style.set_border_width_all(1)
		style.border_color = Color(0.08, 0.1, 0.11, 0.9)
		dot.add_theme_stylebox_override("panel", style)
		action_point_dots.add_child(dot)

func _on_displayed_unit_stats_changed() -> void:
	refresh_details()
	refresh_initiative()

func _request_end_turn() -> void:
	if not end_turn_button.disabled:
		end_turn_button.disabled = true
		end_turn_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		exit_to_main_menu_requested.emit()
		return
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		var ability_index: int = int(key_event.keycode - KEY_1)
		if ability_index < skill_buttons.get_child_count():
			_select_ability(ability_index)
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_SPACE:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		_request_end_turn()
