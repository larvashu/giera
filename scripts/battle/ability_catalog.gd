class_name AbilityCatalog
extends RefCounted

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
	return "%s  |  %d PA  |  zasieg %d" % [ability_name, int(ability.cost), int(ability.range)]
