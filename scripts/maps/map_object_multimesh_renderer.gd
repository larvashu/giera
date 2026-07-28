class_name MapObjectMultiMeshRenderer
extends Node3D

const DEFAULT_OBSTACLES: Array[String] = [
	"purple_tree_1",
	"purple_tree_2",
	"purple_tree_3",
	"large_tree",
]

var _assets: Dictionary[String, String] = {}
var _obstacle_types: Array[String] = DEFAULT_OBSTACLES.duplicate()
var _position_resolver: Callable
var _create_collisions := false
var _instance_positions: Array[Vector3] = []

func configure(
	assets: Dictionary[String, String],
	position_resolver: Callable,
	create_collisions: bool = false,
	obstacle_types: Array[String] = DEFAULT_OBSTACLES
) -> void:
	_assets = assets.duplicate()
	_position_resolver = position_resolver
	_create_collisions = create_collisions
	_obstacle_types = obstacle_types.duplicate()

func rebuild(objects: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()
	_instance_positions.clear()
	_instance_positions.resize(objects.size())
	var grouped: Dictionary[String, Array] = {}
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var kind := str(data.get("type", ""))
		if not _assets.has(kind):
			continue
		if not grouped.has(kind):
			grouped[kind] = []
		grouped[kind].append({"index": index, "data": data})
	for kind: String in grouped:
		_build_kind(kind, grouped[kind])

func get_instance_position(index: int) -> Vector3:
	if index < 0 or index >= _instance_positions.size():
		return Vector3.ZERO
	return _instance_positions[index]

func _build_kind(kind: String, entries: Array) -> void:
	var packed := load(_assets[kind]) as PackedScene
	if packed == null:
		push_warning("Nie mozna zaladowac modelu mapy: " + _assets[kind])
		return
	var source := packed.instantiate() as Node3D
	if source == null:
		return
	add_child(source)
	source.visible = false
	var visuals: Array[MeshInstance3D] = []
	_collect_meshes(source, visuals)
	for part_index: int in range(visuals.size()):
		var visual := visuals[part_index]
		if visual.mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = visual.mesh
		multimesh.instance_count = entries.size()
		var part_transform := source.transform.affine_inverse() * visual.global_transform
		for entry_index: int in range(entries.size()):
			var entry: Dictionary = entries[entry_index]
			var object_index := int(entry["index"])
			var data: Dictionary = entry["data"]
			var object_transform := _object_transform(data)
			multimesh.set_instance_transform(entry_index, object_transform * part_transform)
			_instance_positions[object_index] = object_transform.origin
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_Part%d" % [kind, part_index]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(instance)
	if _create_collisions and _obstacle_types.has(kind):
		_build_collisions(kind, entries)
	source.queue_free()

func _object_transform(data: Dictionary) -> Transform3D:
	var resolved_position := Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if _position_resolver.is_valid():
		resolved_position = _position_resolver.call(data) as Vector3
	resolved_position.y += float(data.get("height_offset", 0.0))
	var scale_value := clampf(float(data.get("scale", 1.0)), 0.2, 8.0)
	var flip_sign := -1.0 if bool(data.get("flipped", false)) else 1.0
	var object_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(float(data.get("rotation", 0.0))), 0.0))
	object_basis = object_basis.scaled(Vector3(scale_value * flip_sign, scale_value, scale_value))
	return Transform3D(object_basis, resolved_position)

func _build_collisions(kind: String, entries: Array) -> void:
	var body := StaticBody3D.new()
	body.name = kind + "_Obstacles"
	for entry: Dictionary in entries:
		var data: Dictionary = entry["data"]
		var object_transform := _object_transform(data)
		var scale_value := clampf(float(data.get("scale", 1.0)), 0.2, 8.0)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.38 * scale_value
		shape.height = 2.0 * scale_value
		collision.shape = shape
		collision.position = object_transform.origin + Vector3.UP * shape.height * 0.5
		body.add_child(collision)
	add_child(body)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, output)
