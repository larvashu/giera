class_name TeamBuilder
extends Control

@onready var save_manager := get_node("/root/TeamSaveManager") as TeamSaveService
@onready var character_list: VBoxContainer = %CharacterList
@onready var selected_list: VBoxContainer = %SelectedList
@onready var saved_list: VBoxContainer = %SavedList
@onready var team_name_edit: LineEdit = %TeamNameEdit
@onready var slots_label: Label = %SlotsLabel
@onready var status_label: Label = %StatusLabel
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog

var current_team := TeamDefinition.new()
var pending_delete_uuid: String = ""

func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%ClearButton.pressed.connect(_clear)
	%BackButton.pressed.connect(_back)
	%CharactersButton.pressed.connect(_characters)
	delete_dialog.confirmed.connect(_confirm_delete)
	_clear()
	_refresh_all()

func _refresh_all() -> void:
	_rebuild_character_list()
	_rebuild_selected_list()
	_rebuild_saved_list()

func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _rebuild_character_list() -> void:
	_clear_container(character_list)
	var profile_manager := get_node("/root/CharacterProfileManager") as CharacterProfileService
	profile_manager.reload_profiles()
	for profile: CharacterProfile in profile_manager.profiles:
		var profile_row := HBoxContainer.new()
		var profile_label := Label.new()
		profile_label.text = "%s | %s | %s | koszt 1" % [
			profile.character_name,
			CharacterProfileService.RACES[profile.race_id]["name"],
			CharacterProfileService.CLASSES[profile.class_id]["name"]
		]
		profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var profile_button := Button.new()
		profile_button.text = "Dodaj"
		profile_button.pressed.connect(_add_character.bind(StringName(profile.character_uuid)))
		var edit_button := Button.new()
		edit_button.text = "Edytuj"
		edit_button.pressed.connect(_edit_character.bind(profile.character_uuid))
		profile_row.add_child(profile_label)
		profile_row.add_child(edit_button)
		profile_row.add_child(profile_button)
		character_list.add_child(profile_row)
	for definition: CharacterDefinition in save_manager.get_character_definitions():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s | %s | koszt %d | HP %d | inicjatywa %d" % [
			definition.display_name, definition.role_name, definition.team_slot_cost,
			definition.max_health, definition.initiative
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.text = "Dodaj"
		button.pressed.connect(_add_character.bind(definition.character_id))
		row.add_child(label)
		row.add_child(button)
		character_list.add_child(row)

func _rebuild_selected_list() -> void:
	_clear_container(selected_list)
	for index: int in range(current_team.character_ids.size()):
		var character_id: StringName = current_team.character_ids[index]
		var definition := save_manager.get_character(character_id)
		if definition == null:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (koszt %d)" % [save_manager.get_character_display_name(character_id), save_manager.get_slot_cost(character_id)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var edit_button := Button.new()
		var profile_manager := get_node("/root/CharacterProfileManager") as CharacterProfileService
		var profile := profile_manager.find_profile(character_id)
		edit_button.text = "Edytuj"
		edit_button.visible = profile != null
		if profile != null:
			edit_button.pressed.connect(_edit_character.bind(profile.character_uuid))
		var button := Button.new()
		button.text = "Usun"
		button.pressed.connect(_remove_character.bind(index))
		row.add_child(label)
		row.add_child(edit_button)
		row.add_child(button)
		selected_list.add_child(row)
	slots_label.text = "Zajete miejsca: %d / %d" % [
		save_manager.get_used_slots(current_team.character_ids), TeamSaveService.MAX_TEAM_SLOTS
	]

func _rebuild_saved_list() -> void:
	_clear_container(saved_list)
	save_manager.reload_teams()
	for team: TeamDefinition in save_manager.teams:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s | %d/5 | %d postaci" % [
			team.team_name, save_manager.get_used_slots(team.character_ids), team.character_ids.size()
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var load_button := Button.new()
		load_button.text = "Wczytaj"
		load_button.pressed.connect(_load_team.bind(team.team_uuid))
		var duplicate_button := Button.new()
		duplicate_button.text = "Duplikuj"
		duplicate_button.pressed.connect(_duplicate_team.bind(team.team_uuid))
		var delete_button := Button.new()
		delete_button.text = "Usun"
		delete_button.pressed.connect(_request_delete.bind(team.team_uuid, team.team_name))
		row.add_child(label)
		row.add_child(load_button)
		row.add_child(duplicate_button)
		row.add_child(delete_button)
		saved_list.add_child(row)

func _add_character(character_id: StringName) -> void:
	var definition := save_manager.get_character(character_id)
	if definition == null:
		return
	var used := save_manager.get_used_slots(current_team.character_ids)
	if used + save_manager.get_slot_cost(character_id) > TeamSaveService.MAX_TEAM_SLOTS:
		status_label.text = "Brak miejsca w druzynie."
		return
	current_team.character_ids.append(character_id)
	status_label.text = ""
	_rebuild_selected_list()

func _remove_character(index: int) -> void:
	if index >= 0 and index < current_team.character_ids.size():
		current_team.character_ids.remove_at(index)
	_rebuild_selected_list()

func _save() -> void:
	current_team.team_name = team_name_edit.text.strip_edges()
	if not save_manager.save_team(current_team):
		status_label.text = "Podaj nazwe i dodaj poprawny sklad do 5 miejsc."
		return
	status_label.text = "Druzyna zapisana."
	_load_team(current_team.team_uuid)
	_rebuild_saved_list()

func _clear() -> void:
	current_team = TeamDefinition.new()
	current_team.team_uuid = save_manager.create_uuid()
	team_name_edit.text = ""
	status_label.text = ""
	if is_node_ready():
		_rebuild_selected_list()

func _load_team(team_uuid: String) -> void:
	var team := save_manager.find_team(team_uuid)
	if team == null:
		return
	current_team = team.duplicate_team(team.team_uuid, "")
	current_team.team_name = team.team_name
	team_name_edit.text = current_team.team_name
	status_label.text = "Wczytano druzyne."
	_rebuild_selected_list()

func _duplicate_team(team_uuid: String) -> void:
	var team := save_manager.find_team(team_uuid)
	if team != null:
		save_manager.duplicate_saved_team(team)
		status_label.text = "Utworzono kopie."
		_rebuild_saved_list()

func _request_delete(team_uuid: String, team_name: String) -> void:
	pending_delete_uuid = team_uuid
	delete_dialog.dialog_text = "Usunac druzyne '%s'?" % team_name
	delete_dialog.popup_centered()

func _confirm_delete() -> void:
	if not pending_delete_uuid.is_empty():
		save_manager.delete_team(pending_delete_uuid)
		pending_delete_uuid = ""
		_rebuild_saved_list()

func _edit_character(profile_uuid: String) -> void:
	var profile_manager := get_node("/root/CharacterProfileManager") as CharacterProfileService
	profile_manager.edit_profile_uuid = profile_uuid
	get_tree().change_scene_to_file("res://scenes/menu/character_editor.tscn")

func _characters() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/character_editor.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
