class_name CharacterProfile
extends Resource

const STAT_NAMES: Array[StringName] = [&"sila", &"zrecznosc", &"wytrzymalosc", &"inteligencja", &"madrosc", &"percepcja", &"charyzma", &"szczesc"]

@export var character_uuid: String
@export var character_name: String
@export var race_id: StringName = &"human"
@export var class_id: StringName = &"warrior"
@export var bonus_points: Dictionary[StringName, int] = {}
@export var modified_at: int = 0
@export var format_version: int = 1

func get_stat(stat_id: StringName, race_modifiers: Dictionary) -> int:
	return 4 + int(race_modifiers.get(stat_id, 0)) + int(bonus_points.get(stat_id, 0))

func spent_points() -> int:
	var total: int = 0
	for value: int in bonus_points.values():
		total += value
	return total

func duplicate_profile(new_uuid: String, suffix: String = " — kopia") -> Resource:
	var copy := CharacterProfile.new()
	copy.character_uuid = new_uuid
	copy.character_name = character_name + suffix
	copy.race_id = race_id
	copy.class_id = class_id
	copy.bonus_points = bonus_points.duplicate()
	copy.modified_at = int(Time.get_unix_time_from_system())
	return copy
