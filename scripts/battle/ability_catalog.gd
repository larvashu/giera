class_name AbilityCatalog
extends RefCounted

const ICON_ATLAS_PATH := "res://assets/ui/skills/skill_icons_atlas_source.png"
const ICON_GRID_SIZE := 7
const ICON_ORDER: Array[String] = [
	"Ciezkie ciecie", "Tarcza", "Prowokacja", "Precyzyjny strzal", "Pulapka", "Sokole oko", "Kula ognia",
	"Lodowy pocisk", "Teleportacja", "Leczenie", "Blogoslawienstwo", "Ochrona", "Cios w plecy", "Unik",
	"Znikniecie", "Korzenie", "Regeneracja", "Burza lisci", "Miazdzenie", "Ryk", "Szarza",
	"Maczuga", "Kamienna skora", "Kamienny cios", "Forteca", "Wstrzas", "Smoczy oddech", "Lot",
	"Ogon", "Dotyk zarazy", "Nekrotyczne leczenie", "Klatwa grobu", "Sokoli zwiad", "Pikowanie", "Oznaczenie celu",
	"Brudny cios", "Rzut nozem", "Zasadzka", "Adaptacja", "Widzenie w mroku", "Kamienna odpornosc", "Zew krwi",
	"Szczesciarz", "Majsterkowicz", "Odpornosc na ogien", "Zwinna ucieczka", "Nieczula natura"
]

const ABILITIES: Dictionary = {
	"Ciezkie ciecie": {"cost": 3, "range": 1, "target": "enemy", "effect": "damage", "power": 5},
	"Tarcza": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "guard", "power": 3, "duration": 2},
	"Prowokacja": {"cost": 2, "range": 3, "target": "enemy", "effect": "status", "status": "weakened", "power": 2, "duration": 2},
	"Precyzyjny strzal": {"cost": 3, "range": 8, "target": "enemy", "effect": "damage", "power": 4},
	"Pulapka": {"cost": 3, "range": 6, "target": "enemy", "effect": "damage_status", "power": 2, "status": "rooted", "duration": 1},
	"Sokole oko": {"cost": 2, "range": 8, "target": "enemy", "effect": "status", "status": "marked", "power": 2, "duration": 2},
	"Kula ognia": {"cost": 4, "range": 6, "target": "enemy", "effect": "area_damage", "power": 4, "radius": 2},
	"Lodowy pocisk": {"cost": 3, "range": 6, "target": "enemy", "effect": "damage_status", "power": 3, "status": "slowed", "duration": 2},
	"Teleportacja": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "haste", "power": 3, "duration": 1},
	"Leczenie": {"cost": 3, "range": 5, "target": "ally", "effect": "heal", "power": 6},
	"Blogoslawienstwo": {"cost": 2, "range": 5, "target": "ally", "effect": "status", "status": "might", "power": 2, "duration": 2},
	"Ochrona": {"cost": 3, "range": 5, "target": "ally", "effect": "status", "status": "guard", "power": 3, "duration": 2},
	"Cios w plecy": {"cost": 3, "range": 1, "target": "enemy", "effect": "damage", "power": 7},
	"Unik": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "dodge", "power": 4, "duration": 1},
	"Znikniecie": {"cost": 3, "range": 0, "target": "self", "effect": "status", "status": "hidden", "power": 3, "duration": 2},
	"Korzenie": {"cost": 3, "range": 5, "target": "enemy", "effect": "damage_status", "power": 2, "status": "rooted", "duration": 2},
	"Regeneracja": {"cost": 3, "range": 5, "target": "ally", "effect": "status", "status": "regeneration", "power": 3, "duration": 3},
	"Burza lisci": {"cost": 4, "range": 5, "target": "enemy", "effect": "area_damage", "power": 3, "radius": 2},
	"Miazdzenie": {"cost": 4, "range": 1, "target": "enemy", "effect": "damage", "power": 8},
	"Ryk": {"cost": 3, "range": 4, "target": "enemy", "effect": "area_status", "status": "weakened", "power": 2, "duration": 2, "radius": 3},
	"Szarza": {"cost": 4, "range": 3, "target": "enemy", "effect": "damage_status", "power": 6, "status": "stunned", "duration": 1},
	"Maczuga": {"cost": 3, "range": 1, "target": "enemy", "effect": "damage", "power": 6},
	"Kamienna skora": {"cost": 3, "range": 0, "target": "self", "effect": "status", "status": "guard", "power": 5, "duration": 2},
	"Kamienny cios": {"cost": 3, "range": 1, "target": "enemy", "effect": "damage", "power": 7},
	"Forteca": {"cost": 3, "range": 0, "target": "self", "effect": "status", "status": "guard", "power": 7, "duration": 2},
	"Wstrzas": {"cost": 4, "range": 2, "target": "enemy", "effect": "area_damage_status", "power": 4, "status": "slowed", "duration": 2, "radius": 2},
	"Smoczy oddech": {"cost": 4, "range": 5, "target": "enemy", "effect": "area_damage_status", "power": 8, "status": "burning", "duration": 2, "radius": 2},
	"Lot": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "haste", "power": 4, "duration": 2},
	"Ogon": {"cost": 3, "range": 2, "target": "enemy", "effect": "area_damage", "power": 6, "radius": 1},
	"Dotyk zarazy": {"cost": 3, "range": 2, "target": "enemy", "effect": "damage_status", "power": 3, "status": "poisoned", "duration": 3},
	"Nekrotyczne leczenie": {"cost": 3, "range": 5, "target": "ally", "effect": "heal", "power": 5},
	"Klatwa grobu": {"cost": 3, "range": 5, "target": "enemy", "effect": "status", "status": "marked", "power": 3, "duration": 3},
	"Sokoli zwiad": {"cost": 2, "range": 8, "target": "enemy", "effect": "status", "status": "marked", "power": 2, "duration": 2},
	"Pikowanie": {"cost": 3, "range": 7, "target": "enemy", "effect": "damage", "power": 5},
	"Oznaczenie celu": {"cost": 2, "range": 8, "target": "enemy", "effect": "status", "status": "marked", "power": 3, "duration": 2},
	"Brudny cios": {"cost": 3, "range": 1, "target": "enemy", "effect": "damage_status", "power": 4, "status": "weakened", "duration": 1},
	"Rzut nozem": {"cost": 3, "range": 5, "target": "enemy", "effect": "damage", "power": 3},
	"Zasadzka": {"cost": 3, "range": 0, "target": "self", "effect": "status", "status": "hidden", "power": 3, "duration": 2},
	"Adaptacja": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "might", "power": 1, "duration": 2},
	"Widzenie w mroku": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "dodge", "power": 2, "duration": 2},
	"Kamienna odpornosc": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "guard", "power": 3, "duration": 2},
	"Zew krwi": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "might", "power": 3, "duration": 2},
	"Szczesciarz": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "dodge", "power": 3, "duration": 1},
	"Majsterkowicz": {"cost": 2, "range": 0, "target": "self", "effect": "heal", "power": 4},
	"Odpornosc na ogien": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "guard", "power": 2, "duration": 3},
	"Zwinna ucieczka": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "haste", "power": 2, "duration": 2},
	"Nieczula natura": {"cost": 2, "range": 0, "target": "self", "effect": "status", "status": "regeneration", "power": 2, "duration": 3}
}

static func get_ability(ability_name: String) -> Dictionary:
	return (ABILITIES.get(ability_name, {}) as Dictionary).duplicate(true)

static func describe(ability_name: String) -> String:
	var ability := get_ability(ability_name)
	if ability.is_empty():
		return ability_name
	var target_labels := {"enemy": "przeciwnik", "ally": "sojusznik", "self": "wlasna postac"}
	var effect := String(ability.get("effect", "damage"))
	var details: Array[String] = []
	if effect.contains("damage"):
		details.append("Zadaje %d bazowych obrazen" % int(ability.get("power", 0)))
	elif effect == "heal":
		details.append("Przywraca %d punktow zdrowia" % int(ability.get("power", 0)))
	if effect.contains("status"):
		var status_id := StringName(String(ability.get("status", "")))
		details.append("Naklada: %s (%d tury)" % [TacticalUnit.status_label(status_id), int(ability.get("duration", 1))])
	if effect.begins_with("area_"):
		details.append("Obszar: %d pola" % int(ability.get("radius", 1)))
	return "%s\n%s\nKoszt: %d PA  |  Zasieg: %d  |  Cel: %s" % [
		ability_name,
		". ".join(details),
		int(ability.cost),
		int(ability.range),
		String(target_labels.get(String(ability.get("target", "enemy")), "cel"))
	]

static func icon_index(ability_name: String) -> int:
	var index := ICON_ORDER.find(ability_name)
	return index if index >= 0 else 47
