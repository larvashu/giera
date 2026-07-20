class_name TeamDefinition
extends Resource

@export var team_uuid: String
@export var team_name: String
@export var character_ids: Array[StringName] = []
@export var modified_at: int = 0
@export var format_version: int = 1

func used_slots(catalog: Dictionary[StringName, CharacterDefinition]) -> int:
	var total: int = 0
	for character_id: StringName in character_ids:
		var definition: CharacterDefinition = catalog.get(character_id)
		if definition != null:
			total += definition.team_slot_cost
	return total

func duplicate_team(new_uuid: String, suffix: String = " — kopia") -> TeamDefinition:
	var copy := TeamDefinition.new()
	copy.team_uuid = new_uuid
	copy.team_name = team_name + suffix
	copy.character_ids = character_ids.duplicate()
	copy.modified_at = int(Time.get_unix_time_from_system())
	return copy
