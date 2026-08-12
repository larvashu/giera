class_name MapRuntime
extends Node3D

const ASSETS: Dictionary[String, String] = {
	"purple_tree_1": "res://assets/models/environment/purple_tree_01.glb",
	"purple_tree_2": "res://assets/models/environment/purple_tree_02.glb",
	"purple_tree_3": "res://assets/models/environment/purple_tree_03.glb",
	"large_tree": "res://assets/models/environment/large_tree.glb",
	"bush": "res://assets/models/environment/bush_grass_02.glb",
	"grass_1": "res://assets/models/environment/grass_clump_01.glb",
	"grass_2": "res://assets/models/environment/grass_clump_02.glb",
}
const OBSTACLE_TYPES: Array[String] = ["purple_tree_1", "purple_tree_2", "purple_tree_3", "large_tree"]
const ROAD_OGRE_SCRIPT := preload("res://scripts/world/road_ogre_walker.gd")

@export var grid_manager: GridManager
@export var decorator: Node3D

var _renderer: MapObjectMultiMeshRenderer

func _ready() -> void:
	call_deferred("_apply_selected_map")

func _apply_selected_map() -> void:
	var session := get_node("/root/GameSession") as GameSessionState
	if session.selected_map_id == "builtin:forest":
		var road_ogre := ROAD_OGRE_SCRIPT.new() as RoadOgreWalker
		road_ogre.name = "PlayMapRoamingOgre"
		add_child(road_ogre)
		road_ogre.setup(grid_manager)
		return
	var data: Dictionary = get_node("/root/MapCatalog").load_map(session.selected_map_id)
	if data.is_empty():
		return
	for child: Node in decorator.get_children():
		child.queue_free()
	grid_manager.clear_blocked_cells()
	grid_manager.apply_spawn_data(data)
	var objects: Array[Dictionary] = []
	for raw: Variant in data.get("objects", []):
		if raw is Dictionary:
			var object_data := raw as Dictionary
			objects.append(object_data)
			var kind := str(object_data.get("type", ""))
			if OBSTACLE_TYPES.has(kind):
				grid_manager.block_cell(Vector2i(roundi(float(object_data.get("x", 0.0))), roundi(float(object_data.get("z", 0.0)))))
	_renderer = MapObjectMultiMeshRenderer.new()
	_renderer.name = "MapObjectBatches"
	decorator.add_child(_renderer)
	_renderer.configure(ASSETS, _resolve_object_position, true, OBSTACLE_TYPES)
	_renderer.rebuild(objects)

func _resolve_object_position(data: Dictionary) -> Vector3:
	var x := float(data.get("x", 0.0))
	var z := float(data.get("z", 0.0))
	var cell := Vector2i(roundi(x), roundi(z))
	var base_position := grid_manager.cell_to_world(cell)
	return base_position + Vector3(x - float(cell.x), 0.0, z - float(cell.y))
