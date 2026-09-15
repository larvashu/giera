class_name WaterwaysRiverSurface
extends Node3D

const RIVER_SCRIPT: Script = preload("res://addons/waterways/river_manager.gd")

var _river_data: Array[Dictionary] = []


func clear() -> void:
	_river_data.clear()
	for child: Node in get_children():
		child.queue_free()


func load_rivers(raw_rivers: Array) -> void:
	clear()
	for raw: Variant in raw_rivers:
		if raw is Dictionary:
			var river_data: Dictionary = (raw as Dictionary).duplicate(true)
			_river_data.append(river_data)
			_create_river(river_data)


func serialize_rivers() -> Array[Dictionary]:
	return _river_data.duplicate(true)


func _create_river(data: Dictionary) -> void:
	var raw_points: Array = data.get("points", [])
	if raw_points.size() < 2:
		return
	var river := Node3D.new()
	river.name = str(data.get("name", "WaterwaysRiver"))
	river.set_script(RIVER_SCRIPT)
	add_child(river)
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var widths: Array[float] = []
	for index: int in range(raw_points.size()):
		var point_data: Dictionary = raw_points[index]
		var point := Vector3(
			float(point_data.get("x", 0.0)),
			float(point_data.get("y", 0.0)),
			float(point_data.get("z", 0.0))
		)
		var previous: Vector3 = point
		var following: Vector3 = point
		if index > 0:
			var previous_data: Dictionary = raw_points[index - 1]
			previous = Vector3(float(previous_data.get("x", 0.0)), float(previous_data.get("y", 0.0)), float(previous_data.get("z", 0.0)))
		if index + 1 < raw_points.size():
			var next_data: Dictionary = raw_points[index + 1]
			following = Vector3(float(next_data.get("x", 0.0)), float(next_data.get("y", 0.0)), float(next_data.get("z", 0.0)))
		var tangent := (following - previous) * 0.22
		curve.add_point(point, -tangent, tangent)
		widths.append(maxf(1.0, float(point_data.get("width", 8.0))))
	river.set("curve", curve)
	river.set("widths", widths)
	river.set("shape_step_length_divs", 2)
	river.set("shape_step_width_divs", 3)
	river.set("shape_smoothness", 0.8)
	river.call("_generate_river")
