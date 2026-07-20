class_name HotseatSetup
extends Control

@onready var save_manager := get_node("/root/TeamSaveManager") as TeamSaveService
@onready var game_session := get_node("/root/GameSession") as GameSessionState
@onready var player_one_name: LineEdit = %PlayerOneName
@onready var player_two_name: LineEdit = %PlayerTwoName
@onready var player_one_team: OptionButton = %PlayerOneTeam
@onready var player_two_team: OptionButton = %PlayerTwoTeam
@onready var player_one_preview: Label = %PlayerOnePreview
@onready var player_two_preview: Label = %PlayerTwoPreview
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var map_option: OptionButton = %MapOption

var selected_team_one: TeamDefinition
var selected_team_two: TeamDefinition

func _ready() -> void:
	player_one_team.item_selected.connect(_select_team_one)
	player_two_team.item_selected.connect(_select_team_two)
	start_button.pressed.connect(_start_game)
	%BackButton.pressed.connect(_back)
	_populate_teams()
	_populate_maps()

func _populate_maps() -> void:
	map_option.clear()
	for data: Dictionary in get_node("/root/MapCatalog").list_maps():
		map_option.add_item(str(data.name))
		map_option.set_item_metadata(map_option.item_count - 1, str(data.id))

func _populate_teams() -> void:
	save_manager.reload_teams()
	player_one_team.clear()
	player_two_team.clear()
	for team: TeamDefinition in save_manager.teams:
		var text := "%s (%d/5)" % [team.team_name, save_manager.get_used_slots(team.character_ids)]
		player_one_team.add_item(text)
		player_two_team.add_item(text)
		var index := player_one_team.item_count - 1
		player_one_team.set_item_metadata(index, team.team_uuid)
		player_two_team.set_item_metadata(index, team.team_uuid)
	if not save_manager.teams.is_empty():
		_select_team_one(0)
		_select_team_two(0)
	_update_start_button()

func _select_team_one(index: int) -> void:
	selected_team_one = _team_from_option(player_one_team, index)
	player_one_preview.text = _team_preview(selected_team_one)
	_update_start_button()

func _select_team_two(index: int) -> void:
	selected_team_two = _team_from_option(player_two_team, index)
	player_two_preview.text = _team_preview(selected_team_two)
	_update_start_button()

func _team_from_option(option: OptionButton, index: int) -> TeamDefinition:
	if index < 0 or index >= option.item_count:
		return null
	return save_manager.find_team(str(option.get_item_metadata(index)))

func _team_preview(team: TeamDefinition) -> String:
	if team == null:
		return "Brak druzyny"
	var names: Array[String] = []
	for character_id: StringName in team.character_ids:
		var definition := save_manager.get_character(character_id)
		if definition != null:
			names.append(save_manager.get_character_display_name(character_id))
	return "%s\nZajete miejsca: %d / 5\n%s" % [
		team.team_name, save_manager.get_used_slots(team.character_ids), ", ".join(names)
	]

func _update_start_button() -> void:
	start_button.disabled = (
		selected_team_one == null
		or selected_team_two == null
		or not save_manager.validate_team(selected_team_one)
		or not save_manager.validate_team(selected_team_two)
	)

func _start_game() -> void:
	if start_button.disabled:
		return
	game_session.selected_map_id = str(map_option.get_item_metadata(map_option.selected))
	game_session.configure_hotseat(
		player_one_name.text,
		player_two_name.text,
		selected_team_one,
		selected_team_two
	)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
