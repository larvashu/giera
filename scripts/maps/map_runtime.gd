class_name MapRuntime
extends Node3D
const ASSETS := {"purple_tree_1":"res://assets/models/environment/purple_tree_01.glb","purple_tree_2":"res://assets/models/environment/purple_tree_02.glb","purple_tree_3":"res://assets/models/environment/purple_tree_03.glb","large_tree":"res://assets/models/environment/large_tree.glb","bush":"res://assets/models/environment/bush_grass_02.glb","grass_1":"res://assets/models/environment/grass_clump_01.glb","grass_2":"res://assets/models/environment/grass_clump_02.glb"}
@export var grid_manager: GridManager
@export var decorator: Node3D
func _ready() -> void: call_deferred("_apply_selected_map")
func _apply_selected_map() -> void:
	var session := get_node("/root/GameSession") as GameSessionState
	if session.selected_map_id == "builtin:forest": return
	var data: Dictionary = get_node("/root/MapCatalog").load_map(session.selected_map_id)
	if data.is_empty(): return
	for child: Node in decorator.get_children(): child.queue_free()
	grid_manager.clear_blocked_cells()
	grid_manager.apply_spawn_data(data)
	for raw: Variant in data.get("objects", []):
		if raw is Dictionary: _create_object(raw)
func _create_object(data: Dictionary) -> void:
	var kind := str(data.get("type", "grass_1"))
	if not ASSETS.has(kind): return
	var packed := load(str(ASSETS[kind])) as PackedScene
	var root := Node3D.new()
	var model := packed.instantiate() as Node3D
	var size := clampf(float(data.get("scale", 1.0)), 0.2, 8.0)
	model.scale = Vector3.ONE * size
	model.rotation.y = deg_to_rad(float(data.get("rotation", 0.0)))
	root.add_child(model)
	var cell := Vector2i(int(data.get("x", 0)), int(data.get("z", 0)))
	root.position = grid_manager.cell_to_world(cell)
	decorator.add_child(root)
	if kind.contains("tree"):
		grid_manager.block_cell(cell)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.35 * size
		shape.height = 1.8 * size
		collision.shape = shape
		collision.position.y = 0.9 * size
		body.add_child(collision)
		root.add_child(body)
