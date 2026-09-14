class_name MapGrassLayer
extends Node3D

const SIMPLE_GRASS_SCRIPT := preload("res://addons/simplegrasstextured/grass.gd")
const GRASS_TEXTURE := preload("res://addons/simplegrasstextured/textures/grassbushcc008.png")
const DEFAULT_MESH := preload("res://addons/simplegrasstextured/default_mesh.tres")

var _default_color := Color(0.42, 0.72, 0.22)
var _grass_nodes: Array[MultiMeshInstance3D] = []


func set_grass_color(color: Color) -> void:
	_default_color = color


func rebuild(entries: Array[Dictionary], height_resolver: Callable, width: float, height: float) -> void:
	for node: MultiMeshInstance3D in _grass_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_grass_nodes.clear()
	var grouped: Dictionary[String, Array] = {}
	for data: Dictionary in entries:
		var color_key := str(data.get("color", _default_color.to_html(false)))
		if not grouped.has(color_key):
			grouped[color_key] = []
		grouped[color_key].append(data)
	for color_key: String in grouped:
		_build_color_layer(color_key, grouped[color_key], height_resolver, width, height)


func _build_color_layer(color_key: String, entries: Array, height_resolver: Callable, width: float, height: float) -> void:
	var grass := SIMPLE_GRASS_SCRIPT.new() as MultiMeshInstance3D
	grass.name = "SimpleGrass_%s" % color_key
	add_child(grass)
	_grass_nodes.append(grass)
	grass.set("texture_albedo", GRASS_TEXTURE)
	grass.set("grass_tint", Color.from_string(color_key, _default_color))
	grass.set("color_variation_strength", 0.0)
	grass.set("dry_tint", Color.WHITE)
	grass.set("fresh_tint", Color.WHITE)
	grass.set("albedo", Color.WHITE)
	grass.set("interactive", false)
	grass.set("light_mode", 0)
	grass.set("optimization_by_distance", false)
	grass.set("scale_w", width)
	grass.set("scale_h", height)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = DEFAULT_MESH
	multi.instance_count = entries.size()
	for index: int in range(entries.size()):
		var data: Dictionary = entries[index]
		var x := float(data.get("x", 0.0))
		var z := float(data.get("z", 0.0))
		var y := float(height_resolver.call(x, z)) if height_resolver.is_valid() else 0.0
		var yaw := deg_to_rad(float(data.get("rotation", 0.0)))
		var variation := float(data.get("scale", 1.0))
		var normal := Vector3(float(data.get("normal_x", 0.0)), float(data.get("normal_y", 1.0)), float(data.get("normal_z", 0.0))).normalized()
		var basis := Basis(Quaternion(Vector3.UP, normal))
		basis = basis.rotated(normal, yaw)
		basis = basis.scaled(Vector3.ONE * variation)
		multi.set_instance_transform(index, Transform3D(basis, Vector3(x, y, z)))
	grass.multimesh = multi
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for data: Dictionary in entries:
		var entry_x := float(data.get("x", 0.0))
		var entry_z := float(data.get("z", 0.0))
		var entry_y := float(height_resolver.call(entry_x, entry_z)) if height_resolver.is_valid() else 0.0
		minimum = minimum.min(Vector3(entry_x, entry_y, entry_z))
		maximum = maximum.max(Vector3(entry_x, entry_y, entry_z))
	var padding := Vector3(maxf(3.0, width * 2.0), maxf(8.0, height * 3.0), maxf(3.0, width * 2.0))
	grass.custom_aabb = AABB(minimum - padding, maximum - minimum + padding * 2.0)
