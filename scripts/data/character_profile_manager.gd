class_name CharacterProfileService
extends Node

const CHARACTER_DIRECTORY := "user://characters"
const BONUS_POINT_LIMIT: int = 5

const RACES: Dictionary = {
	&"human": {"name":"Czlowiek","mods":{}, "skills":["Adaptacja"]},
	&"elf": {"name":"Elf","mods":{&"zrecznosc":1,&"percepcja":1,&"wytrzymalosc":-1}, "skills":["Widzenie w mroku"]},
	&"dwarf": {"name":"Krasnolud","mods":{&"wytrzymalosc":2,&"zrecznosc":-1}, "skills":["Kamienna odpornosc"]},
	&"orc": {"name":"Ork","mods":{&"sila":2,&"inteligencja":-1,&"charyzma":-1}, "skills":["Zew krwi"]},
	&"halfling": {"name":"Niziolek","mods":{&"szczesc":2,&"sila":-1}, "skills":["Szczesciarz"]},
	&"gnome": {"name":"Gnom","mods":{&"inteligencja":2,&"sila":-1}, "skills":["Majsterkowicz"]},
	&"tiefling": {"name":"Diabelstwo","mods":{&"charyzma":1,&"inteligencja":1,&"szczesc":-1}, "skills":["Odpornosc na ogien"]},
	&"dragonborn": {"name":"Smoczy potomek","mods":{&"sila":1,&"charyzma":1,&"zrecznosc":-1}, "skills":["Smoczy oddech"]},
	&"goblin": {"name":"Goblin","mods":{&"zrecznosc":2,&"charyzma":-1}, "skills":["Zwinna ucieczka"]},
	&"undead": {"name":"Nieumarly","mods":{&"wytrzymalosc":1,&"madrosc":-1,&"charyzma":-1}, "skills":["Nieczula natura"]}
}
const CLASSES: Dictionary = {
	&"warrior": {"name":"Wojownik","definition":&"warrior","skills":["Ciezkie ciecie","Tarcza","Prowokacja"]},
	&"ranger": {"name":"Lowca","definition":&"archer","skills":["Precyzyjny strzal","Pulapka","Sokole oko"]},
	&"mage": {"name":"Mag","definition":&"mage","skills":["Kula ognia","Lodowy pocisk","Teleportacja"]},
	&"priest": {"name":"Kaplan","definition":&"priest","skills":["Leczenie","Blogoslawienstwo","Ochrona"]},
	&"rogue": {"name":"Lotr","definition":&"rogue","skills":["Cios w plecy","Unik","Znikniecie"]}
}

var profiles: Array[CharacterProfile] = []
var edit_profile_uuid: String = ""

func _ready() -> void:
	reload_profiles()

func reload_profiles() -> void:
	profiles.clear()
	DirAccess.make_dir_recursive_absolute(CHARACTER_DIRECTORY)
	for file_name: String in DirAccess.get_files_at(CHARACTER_DIRECTORY):
		if file_name.ends_with(".json"):
			var profile := _read_profile(CHARACTER_DIRECTORY + "/" + file_name)
			if profile != null:
				profiles.append(profile)
	profiles.sort_custom(func(a: CharacterProfile, b: CharacterProfile) -> bool: return a.modified_at > b.modified_at)

func save_profile(profile: CharacterProfile) -> bool:
	if not validate_profile(profile):
		return false
	if profile.character_uuid.is_empty():
		profile.character_uuid = create_uuid()
	profile.modified_at = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(CHARACTER_DIRECTORY)
	var file := FileAccess.open(CHARACTER_DIRECTORY + "/" + profile.character_uuid + ".json", FileAccess.WRITE)
	if file == null:
		return false
	var bonuses: Dictionary = {}
	for key: StringName in profile.bonus_points:
		bonuses[String(key)] = profile.bonus_points[key]
	file.store_string(JSON.stringify({"format_version":1,"character_uuid":profile.character_uuid,"character_name":profile.character_name,"race_id":String(profile.race_id),"class_id":String(profile.class_id),"bonus_points":bonuses,"modified_at":profile.modified_at}, "  "))
	file.close()
	reload_profiles()
	return true

func validate_profile(profile: CharacterProfile) -> bool:
	return profile != null and not profile.character_name.strip_edges().is_empty() and RACES.has(profile.race_id) and CLASSES.has(profile.class_id) and profile.spent_points() == BONUS_POINT_LIMIT

func find_profile(uuid: StringName) -> CharacterProfile:
	for profile: CharacterProfile in profiles:
		if profile.character_uuid == String(uuid):
			return profile
	return null

func delete_profile(uuid: String) -> bool:
	var path := CHARACTER_DIRECTORY + "/" + uuid + ".json"
	if not FileAccess.file_exists(path):
		return false
	var result := DirAccess.remove_absolute(path) == OK
	reload_profiles()
	return result

func get_race_modifiers(profile: CharacterProfile) -> Dictionary:
	return RACES.get(profile.race_id, {}).get("mods", {})

func get_skills(profile: CharacterProfile) -> Array[String]:
	var result: Array[String] = []
	for skill: String in CLASSES.get(profile.class_id, {}).get("skills", []):
		result.append(skill)
	for skill: String in RACES.get(profile.race_id, {}).get("skills", []):
		result.append(skill)
	return result

func get_definition_id(profile: CharacterProfile) -> StringName:
	return CLASSES.get(profile.class_id, {}).get("definition", &"warrior")

func create_uuid() -> String:
	return "char-%d-%08x-%08x" % [Time.get_unix_time_from_system(), randi(), randi()]

func _read_profile(path: String) -> CharacterProfile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return null
	var d := data as Dictionary
	var profile := CharacterProfile.new()
	profile.character_uuid = str(d.get("character_uuid",""))
	profile.character_name = str(d.get("character_name",""))
	profile.race_id = StringName(str(d.get("race_id","human")))
	profile.class_id = StringName(str(d.get("class_id","warrior")))
	profile.modified_at = int(d.get("modified_at",0))
	var raw: Dictionary = d.get("bonus_points",{})
	for key: Variant in raw:
		profile.bonus_points[StringName(str(key))] = int(raw[key])
	return profile if validate_profile(profile) else null
