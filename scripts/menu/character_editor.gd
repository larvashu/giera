class_name CharacterEditor
extends Control

@onready var profiles := get_node("/root/CharacterProfileManager") as CharacterProfileService
@onready var name_edit: LineEdit = %NameEdit
@onready var race_option: OptionButton = %RaceOption
@onready var class_option: OptionButton = %ClassOption
@onready var stats_list: VBoxContainer = %StatsList
@onready var skills_label: Label = %SkillsLabel
@onready var points_label: Label = %PointsLabel
@onready var saved_list: VBoxContainer = %SavedList
@onready var status_label: Label = %StatusLabel

var current := CharacterProfile.new()
var stat_spins: Dictionary[StringName, SpinBox] = {}
var stat_labels: Dictionary[StringName, Label] = {}

func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%NewButton.pressed.connect(_new_profile)
	%BackButton.pressed.connect(_back)
	race_option.item_selected.connect(_refresh_summary.unbind(1))
	class_option.item_selected.connect(_refresh_summary.unbind(1))
	_populate_options()
	_build_stats()
	_new_profile()
	_rebuild_saved()
	if not profiles.edit_profile_uuid.is_empty():
		_load_profile(profiles.edit_profile_uuid)
		profiles.edit_profile_uuid = ""

func _populate_options() -> void:
	for race_id: StringName in CharacterProfileService.RACES:
		race_option.add_item(CharacterProfileService.RACES[race_id]["name"])
		race_option.set_item_metadata(race_option.item_count - 1, race_id)
	for class_id: StringName in CharacterProfileService.CLASSES:
		class_option.add_item(CharacterProfileService.CLASSES[class_id]["name"])
		class_option.set_item_metadata(class_option.item_count - 1, class_id)

func _build_stats() -> void:
	for child: Node in stats_list.get_children():
		child.queue_free()
	stat_spins.clear()
	stat_labels.clear()
	for stat_id: StringName in CharacterProfile.STAT_NAMES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(stat_id).capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 5
		spin.value_changed.connect(_on_points_changed.unbind(1))
		row.add_child(label)
		row.add_child(spin)
		stats_list.add_child(row)
		stat_spins[stat_id] = spin
		stat_labels[stat_id] = label

func _on_points_changed() -> void:
	_refresh_summary()

func _refresh_summary() -> void:
	var spent: int = 0
	for spin: SpinBox in stat_spins.values():
		spent += int(spin.value)
	points_label.text = "Punkty dodatkowe: %d / 5" % spent
	points_label.modulate = Color.WHITE if spent == 5 else Color(1.0, 0.45, 0.35)
	var class_id: StringName = _selected_id(class_option)
	var race_id: StringName = _selected_id(race_option)
	var modifiers: Dictionary = CharacterProfileService.RACES.get(race_id, {}).get("mods", {})
	for stat_id: StringName in stat_spins:
		var race_modifier: int = int(modifiers.get(stat_id, 0))
		var final_value: int = 4 + race_modifier + int(stat_spins[stat_id].value)
		var sign_text: String = ("+%d" % race_modifier) if race_modifier > 0 else str(race_modifier)
		stat_labels[stat_id].text = "%s: %d (baza 4, rasa %s)" % [String(stat_id).capitalize(), final_value, sign_text]
	var class_skills: Array = CharacterProfileService.CLASSES.get(class_id, {}).get("skills", [])
	var race_skills: Array = CharacterProfileService.RACES.get(race_id, {}).get("skills", [])
	skills_label.text = "Umiejetnosci klasy: %s\nRasowe: %s" % [", ".join(class_skills), ", ".join(race_skills)]

func _selected_id(option: OptionButton) -> StringName:
	return StringName(option.get_item_metadata(option.selected))

func _save() -> void:
	current.character_name = name_edit.text.strip_edges()
	current.race_id = _selected_id(race_option)
	current.class_id = _selected_id(class_option)
	current.bonus_points.clear()
	for stat_id: StringName in stat_spins:
		current.bonus_points[stat_id] = int(stat_spins[stat_id].value)
	if profiles.save_profile(current):
		status_label.text = "Postac zapisana."
		_rebuild_saved()
	else:
		status_label.text = "Podaj imie i rozdziel dokladnie 5 punktow."

func _new_profile() -> void:
	current = CharacterProfile.new()
	current.character_uuid = profiles.create_uuid()
	name_edit.text = ""
	race_option.select(0)
	class_option.select(0)
	for spin: SpinBox in stat_spins.values():
		spin.value = 0
	status_label.text = ""
	_refresh_summary()

func _load_profile(uuid: String) -> void:
	var found := profiles.find_profile(StringName(uuid))
	if found == null:
		return
	current = found.duplicate_profile(found.character_uuid, "") as CharacterProfile
	current.character_name = found.character_name
	name_edit.text = current.character_name
	_select_metadata(race_option, current.race_id)
	_select_metadata(class_option, current.class_id)
	for stat_id: StringName in stat_spins:
		stat_spins[stat_id].value = int(current.bonus_points.get(stat_id, 0))
	_refresh_summary()

func _select_metadata(option: OptionButton, value: StringName) -> void:
	for index: int in range(option.item_count):
		if StringName(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _rebuild_saved() -> void:
	for child: Node in saved_list.get_children():
		child.queue_free()
	profiles.reload_profiles()
	for profile: CharacterProfile in profiles.profiles:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s — %s, %s" % [profile.character_name, CharacterProfileService.RACES[profile.race_id]["name"], CharacterProfileService.CLASSES[profile.class_id]["name"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var edit := Button.new()
		edit.text = "Edytuj"
		edit.pressed.connect(_load_profile.bind(profile.character_uuid))
		var remove := Button.new()
		remove.text = "Usun"
		remove.pressed.connect(_delete_profile.bind(profile.character_uuid))
		row.add_child(label)
		row.add_child(edit)
		row.add_child(remove)
		saved_list.add_child(row)

func _delete_profile(uuid: String) -> void:
	profiles.delete_profile(uuid)
	_rebuild_saved()

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
