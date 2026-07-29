class_name ExplorationWorldCatalog
extends RefCounted

const WORLD_PATH := "user://worlds/exploration_world.json"
const REGION_SIZE := Vector2(160.0, 190.0)
const WORLD_VERSION := 2
const RING_COUNT := 4
const REGION_COUNT := 49
const BIOMES: Array[String] = ["wild_clearing"]

static func load_world() -> Dictionary:
	if FileAccess.file_exists(WORLD_PATH):
		var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			var stored := parsed as Dictionary
			if int(stored.get("version", 0)) == WORLD_VERSION and (stored.get("regions", []) as Array).size() == REGION_COUNT:
				return stored
	var world := create_default_world()
	save_world(world)
	return world

static func save_world(world: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://worlds"))
	var file := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(world, "\t"))
	return true

static func create_default_world() -> Dictionary:
	var regions: Array[Dictionary] = []
	for z in range(-3, 4):
		for x in range(-3, 4):
			var ring := maxi(abs(x), abs(z)) + 1
			var index := regions.size()
			regions.append({
				"id": "wild_clearing_%02d" % index,
				"name": "Dzika Polana" if ring == 1 else "Dzika Polana %d.%02d" % [ring, index + 1],
				"x": x, "z": z, "layer": ring,
				"biome": "wild_clearing",
				"seed": 61_720_241 + index * 7_919,
				"source_map_id": "builtin:forest" if ring == 1 else "builtin:forest_variant"
			})
	return {"version": WORLD_VERSION, "name": "Swiat Dzikiej Polany", "layers": RING_COUNT, "region_size": [REGION_SIZE.x, REGION_SIZE.y], "regions": regions}

static func region_at(world: Dictionary, coordinate: Vector2i) -> Dictionary:
	for value: Variant in world.get("regions", []):
		var region := value as Dictionary
		if int(region.get("x", 0)) == coordinate.x and int(region.get("z", 0)) == coordinate.y: return region
	return {}

static func coordinate_from_world_position(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / REGION_SIZE.x), floori(position.z / REGION_SIZE.y))
