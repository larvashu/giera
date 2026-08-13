class_name MapObjectMultiMeshRenderer
extends Node3D

const OBJECT_CHUNK_SIZE := 24.0
const DEFAULT_OBSTACLES: Array[String] = ["purple_tree_1", "purple_tree_2", "purple_tree_3", "large_tree"]
const TYPE_SCALE_MULTIPLIERS: Dictionary[String, float] = {
	"purple_tree_1": 5.5,
	"purple_tree_2": 5.5,
	"purple_tree_3": 5.5,
	"large_tree": 6.5,
	"bush": 1.3,
	"grass_1": 0.65,
	"grass_2": 0.65,
}

var _assets: Dictionary[String, String] = {}
var _obstacle_types: Array[String] = DEFAULT_OBSTACLES.duplicate()
var _position_resolver: Callable
var _create_collisions := false
var _instance_positions: Array[Vector3] = []
var _part_cache: Dictionary[String, Array] = {}
var _grass_proxy: ArrayMesh
var _bush_proxy: SphereMesh

func configure(assets: Dictionary[String, String], position_resolver: Callable, create_collisions: bool = false, obstacle_types: Array[String] = DEFAULT_OBSTACLES) -> void:
	_assets = assets.duplicate()
	_position_resolver = position_resolver
	_create_collisions = create_collisions
	_obstacle_types = obstacle_types.duplicate()

func rebuild(objects: Array[Dictionary]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_instance_positions.clear()
	_instance_positions.resize(objects.size())
	var grouped: Dictionary[String, Array] = {}
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var kind := str(data.get("type", ""))
		if not _assets.has(kind):
			continue
		var chunk := Vector2i(floori(float(data.get("x", 0.0)) / OBJECT_CHUNK_SIZE), floori(float(data.get("z", 0.0)) / OBJECT_CHUNK_SIZE))
		var key := "%s|%d|%d" % [kind, chunk.x, chunk.y]
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append({"index": index, "data": data, "kind": kind, "chunk": chunk})
	for key: String in grouped:
		_build_group(key, grouped[key])

func get_instance_position(index: int) -> Vector3:
	if index < 0 or index >= _instance_positions.size():
		return Vector3.ZERO
	return _instance_positions[index]

func _build_group(key: String, entries: Array) -> void:
	if entries.is_empty():
		return
	var kind := str((entries[0] as Dictionary)["kind"])
	var parts := _get_parts(kind)
	for part_index: int in range(parts.size()):
		var part: Dictionary = parts[part_index]
		var source_mesh := part["mesh"] as Mesh
		if source_mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source_mesh
		multimesh.instance_count = entries.size()
		for entry_index: int in range(entries.size()):
			var entry: Dictionary = entries[entry_index]
			var object_index := int(entry["index"])
			var data: Dictionary = entry["data"]
			var object_transform := _object_transform(data)
			multimesh.set_instance_transform(entry_index, object_transform * (part["transform"] as Transform3D))
			_instance_positions[object_index] = object_transform.origin
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_Part%d" % [key.replace("|", "_"), part_index]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _obstacle_types.has(kind) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Trees must remain visible from the elevated isometric camera. A zero end
		# range disables distance culling while retaining regular frustum culling.
		instance.visibility_range_end = 0.0 if _obstacle_types.has(kind) else 75.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(instance)
	if _create_collisions and _obstacle_types.has(kind):
		_build_collisions(key, entries)

func _get_parts(kind: String) -> Array:
	if _part_cache.has(kind):
		return _part_cache[kind]
	var parts: Array = []
	if kind.begins_with("grass_"):
		if _grass_proxy == null:
			_grass_proxy = _create_grass_proxy()
		parts.append({"mesh": _grass_proxy, "transform": Transform3D.IDENTITY})
	elif kind == "bush":
		if _bush_proxy == null:
			_bush_proxy = _create_bush_proxy()
		parts.append({"mesh": _bush_proxy, "transform": Transform3D.IDENTITY})
	else:
		var packed := load(_assets[kind]) as PackedScene
		if packed != null:
			var source := packed.instantiate() as Node3D
			if source != null:
				_collect_parts(source, Transform3D.IDENTITY, parts)
				source.free()
	_part_cache[kind] = parts
	return parts

func _collect_parts(node: Node, parent_transform: Transform3D, output: Array) -> void:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			output.append({"mesh": mesh_instance.mesh, "transform": local_transform})
	for child: Node in node.get_children():
		_collect_parts(child, local_transform, output)

func _resolved_base_position(data: Dictionary) -> Vector3:
	var result := Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if _position_resolver.is_valid():
		result = _position_resolver.call(data) as Vector3
	result.y += float(data.get("height_offset", 0.0))
	return result

func _effective_scale(data: Dictionary) -> float:
	var kind := str(data.get("type", ""))
	return clampf(float(data.get("scale", 1.0)), 0.2, 8.0) * float(TYPE_SCALE_MULTIPLIERS.get(kind, 1.0))

func _object_transform(data: Dictionary) -> Transform3D:
	var kind := str(data.get("type", ""))
	var resolved_position := _resolved_base_position(data)
	var scale_value := _effective_scale(data)
	if _obstacle_types.has(kind):
		resolved_position.y += scale_value
	var flip_sign := -1.0 if bool(data.get("flipped", false)) else 1.0
	var object_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(float(data.get("rotation", 0.0))), 0.0))
	object_basis = object_basis.scaled(Vector3(scale_value * flip_sign, scale_value, scale_value))
	return Transform3D(object_basis, resolved_position)

func _build_collisions(key: String, entries: Array) -> void:
	var body := StaticBody3D.new()
	body.name = key.replace("|", "_") + "_Obstacles"
	for entry: Dictionary in entries:
		var data: Dictionary = entry["data"]
		var scale_value := _effective_scale(data)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = minf(0.19 * scale_value, 1.65)
		shape.height = 1.6 * scale_value
		collision.shape = shape
		collision.position = _resolved_base_position(data) + Vector3.UP * shape.height * 0.5
		body.add_child(collision)
	add_child(body)

func _create_grass_proxy() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle: float in [0.0, PI * 0.5]:
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.34
		var a := -side
		var b := side
		var c := side + Vector3.UP * 0.72
		var d := -side + Vector3.UP * 0.72
		for point: Vector3 in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	var result := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.30, 0.055)
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.surface_set_material(0, material)
	return result

func _create_bush_proxy() -> SphereMesh:
	var result := SphereMesh.new()
	result.radius = 0.62
	result.height = 0.9
	result.radial_segments = 10
	result.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.31, 0.08)
	material.roughness = 0.92
	result.material = material
	return result
