class_name TeamSaveService
extends Node

const TEAM_DIRECTORY := "user://teams"
const CHARACTER_DIRECTORY := "res://data/characters"
const MAX_TEAM_SLOTS: int = 5

var character_catalog: Dictionary[StringName, CharacterDefinition] = {}
var teams: Array[TeamDefinition] = []

func _ready() -> void:
	_load_character_catalog()
	reload_teams()
	if teams.is_empty():
		var starter := TeamDefinition.new()
		starter.team_uuid = create_uuid()
		starter.team_name = "Pierwsza Kompania"
		starter.character_ids = [&"warrior", &"archer", &"mage", &"priest", &"rogue"]
		save_team(starter)

func _load_character_catalog() -> void:
	character_catalog.clear()
	var files := DirAccess.get_files_at(CHARACTER_DIRECTORY)
	for file_name: String in files:
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(CHARACTER_DIRECTORY + "/" + file_name) as CharacterDefinition
		if resource != null and not resource.character_id.is_empty():
			character_catalog[resource.character_id] = resource

func get_character_definitions() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = []
	for definition: CharacterDefinition in character_catalog.values():
		result.append(definition)
	result.sort_custom(func(a: CharacterDefinition, b: CharacterDefinition) -> bool:
		if a.team_slot_cost == b.team_slot_cost:
			return a.display_name < b.display_name
		return a.team_slot_cost < b.team_slot_cost
	)
	return result

func get_character(character_id: StringName) -> CharacterDefinition:
	var definition: CharacterDefinition = character_catalog.get(character_id)
	if definition != null:
		return definition
	var profile_manager := get_node_or_null("/root/CharacterProfileManager") as CharacterProfileService
	var profile: CharacterProfile = profile_manager.find_profile(character_id) if profile_manager != null else null
	return character_catalog.get(profile_manager.get_definition_id(profile)) if profile != null else null

func get_character_display_name(character_id: StringName) -> String:
	var profile_manager := get_node_or_null("/root/CharacterProfileManager") as CharacterProfileService
	var profile: CharacterProfile = profile_manager.find_profile(character_id) if profile_manager != null else null
	if profile != null:
		return profile.character_name
	var definition := get_character(character_id)
	return definition.display_name if definition != null else "Nieznana postac"

func reload_teams() -> void:
	teams.clear()
	DirAccess.make_dir_recursive_absolute(TEAM_DIRECTORY)
	for file_name: String in DirAccess.get_files_at(TEAM_DIRECTORY):
		if file_name.ends_with(".json"):
			var parsed := _read_team_file(TEAM_DIRECTORY + "/" + file_name)
			if parsed != null:
				teams.append(parsed)
	teams.sort_custom(func(a: TeamDefinition, b: TeamDefinition) -> bool:
		return a.modified_at > b.modified_at
	)

func save_team(team: TeamDefinition) -> bool:
	if not validate_team(team):
		return false
	if team.team_uuid.is_empty():
		team.team_uuid = create_uuid()
	team.modified_at = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(TEAM_DIRECTORY)
	var file := FileAccess.open(TEAM_DIRECTORY + "/" + team.team_uuid + ".json", FileAccess.WRITE)
	if file == null:
		return false
	var ids: Array[String] = []
	for character_id: StringName in team.character_ids:
		ids.append(String(character_id))
	file.store_string(JSON.stringify({
		"format_version": team.format_version,
		"team_uuid": team.team_uuid,
		"team_name": team.team_name,
		"character_ids": ids,
		"modified_at": team.modified_at
	}, "  "))
	file.close()
	reload_teams()
	return true

func delete_team(team_uuid: String) -> bool:
	var path := TEAM_DIRECTORY + "/" + team_uuid + ".json"
	if not FileAccess.file_exists(path):
		return false
	var error := DirAccess.remove_absolute(path)
	reload_teams()
	return error == OK

func duplicate_saved_team(team: TeamDefinition) -> TeamDefinition:
	var copy := team.duplicate_team(create_uuid())
	save_team(copy)
	return copy

func find_team(team_uuid: String) -> TeamDefinition:
	for team: TeamDefinition in teams:
		if team.team_uuid == team_uuid:
			return team
	return null

func validate_team(team: TeamDefinition) -> bool:
	if team == null or team.team_name.strip_edges().is_empty() or team.character_ids.is_empty():
		return false
	var used: int = 0
	for character_id: StringName in team.character_ids:
		var definition := get_character(character_id)
		if definition == null:
			return false
		used += 1 if _is_profile(character_id) else definition.team_slot_cost
	return used <= MAX_TEAM_SLOTS

func get_used_slots(character_ids: Array[StringName]) -> int:
	var total: int = 0
	for character_id: StringName in character_ids:
		var definition := get_character(character_id)
		if definition != null:
			total += 1 if _is_profile(character_id) else definition.team_slot_cost
	return total

func get_slot_cost(character_id: StringName) -> int:
	var definition := get_character(character_id)
	if definition == null:
		return 0
	return 1 if _is_profile(character_id) else definition.team_slot_cost

func _is_profile(character_id: StringName) -> bool:
	var profile_manager := get_node_or_null("/root/CharacterProfileManager") as CharacterProfileService
	return profile_manager != null and profile_manager.find_profile(character_id) != null

func create_uuid() -> String:
	return "%d-%08x-%08x" % [Time.get_unix_time_from_system(), randi(), randi()]

func _read_team_file(path: String) -> TeamDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		return null
	var dictionary := data as Dictionary
	var result := TeamDefinition.new()
	result.team_uuid = str(dictionary.get("team_uuid", ""))
	result.team_name = str(dictionary.get("team_name", ""))
	result.modified_at = int(dictionary.get("modified_at", 0))
	result.format_version = int(dictionary.get("format_version", 1))
	var raw_ids: Array = dictionary.get("character_ids", [])
	for raw_id: Variant in raw_ids:
		var character_id := StringName(str(raw_id))
		if get_character(character_id) != null:
			result.character_ids.append(character_id)
	if result.team_uuid.is_empty() or not validate_team(result):
		return null
	return result
