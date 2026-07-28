class_name ExplorationWorldCatalog
extends RefCounted

const WORLD_PATH := "user://worlds/exploration_world.json"
const REGION_SIZE := Vector2(160.0, 190.0)
const BIOMES: Array[String] = ["forest", "meadow", "desert", "rocky", "swamp"]

static func load_world() -> Dictionary:
	if FileAccess.file_exists(WORLD_PATH):
		var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and (parsed as Dictionary).get("regions", []).size() == 50:
			return parsed as Dictionary
	var world := create_default_world()
	save_world(world)
	return world

static func save_world(world: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://worlds"))
	var file := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(world, "\t"))
	return true

static func create_default_world() -> Dictionary:
	var regions: Array[Dictionary] = []
	var biome_index := 0
	for z in range(-2, 3):
		for x in range(-5, 5):
			var biome := BIOMES[biome_index % BIOMES.size()]
			if x == 0 and z == 0:
				biome = "forest"
			elif abs(x) >= 4:
				biome = "desert" if z <= 0 else "rocky"
			elif z == -2:
				biome = "swamp" if x < 0 else "meadow"
			regions.append({
				"id": "region_%02d" % regions.size(),
				"name": _region_name(biome, regions.size()),
				"x": x,
				"z": z,
				"biome": biome,
				"seed": 41041 + regions.size() * 7919,
				"source_map_id": "builtin:forest" if x == 0 and z == 0 else ""
			})
			biome_index += 1
	return {"version": 1, "name": "Wielki swiat", "region_size": [REGION_SIZE.x, REGION_SIZE.y], "regions": regions}

static func region_at(world: Dictionary, coordinate: Vector2i) -> Dictionary:
	for value: Variant in world.get("regions", []):
		var region := value as Dictionary
		if int(region.get("x", 0)) == coordinate.x and int(region.get("z", 0)) == coordinate.y:
			return region
	return {}

static func coordinate_from_world_position(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / REGION_SIZE.x), floori(position.z / REGION_SIZE.y))

static func _region_name(biome: String, index: int) -> String:
	var labels := {"forest": "Las", "meadow": "Laka", "desert": "Pustynia", "rocky": "Skaliste ziemie", "swamp": "Mokradla"}
	return "%s %02d" % [labels.get(biome, "Kraina"), index + 1]
