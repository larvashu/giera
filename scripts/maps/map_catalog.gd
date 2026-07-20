class_name MapCatalogService
extends Node
const MAP_DIRECTORY := "user://maps"
const DEFAULT_ID := "builtin:forest"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_DIRECTORY))
func list_maps() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id": DEFAULT_ID, "name": "Dzika Polana (oryginalna)"}]
	var directory := DirAccess.open(MAP_DIRECTORY)
	if directory == null: return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			var data := load_map(MAP_DIRECTORY.path_join(file_name))
			if not data.is_empty(): result.append({"id": MAP_DIRECTORY.path_join(file_name), "name": str(data.get("name", file_name.get_basename()))})
		file_name = directory.get_next()
	directory.list_dir_end()
	return result
func load_map(map_id: String) -> Dictionary:
	if map_id == DEFAULT_ID or map_id.is_empty(): return {}
	var file := FileAccess.open(map_id, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
func save_map(data: Dictionary) -> String:
	var safe_name := str(data.get("name", "nowa_mapa")).strip_edges().to_lower().replace(" ", "_")
	var path := MAP_DIRECTORY.path_join(safe_name + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify(data, "\t"))
	return path
