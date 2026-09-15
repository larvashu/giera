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
	# Keep Waterways' purpose-built river shader: it follows the spline UVs and
	# provides depth colour, shoreline fading, refraction, foam and moving normals.
	# A generic plane/cubemap material cannot preserve the direction of the current.
	_tune_river_material(river)


func _tune_river_material(river: Node3D) -> void:
	river.call("set_materials", "normal_scale", 0.72)
	river.call("set_materials", "uv_scale", Vector3(0.34, 0.34, 0.34))
	river.call("set_materials", "roughness", 0.055)
	river.call("set_materials", "edge_fade", 0.42)
	var water_gradient := Transform3D(
		Vector3(0.055, 0.34, 0.36),
		Vector3(0.012, 0.095, 0.16),
		Vector3.ZERO,
		Vector3.ZERO
	)
	river.call("set_materials", "albedo_color", water_gradient)
	river.call("set_materials", "albedo_depth", 4.8)
	river.call("set_materials", "albedo_depth_curve", 0.48)
	river.call("set_materials", "transparency_clarity", 8.0)
	river.call("set_materials", "transparency_depth_curve", 0.52)
	river.call("set_materials", "transparency_refraction", 0.032)
	river.call("set_materials", "flow_speed", 0.42)
	river.call("set_materials", "flow_base", 0.72)
	river.call("set_materials", "flow_steepness", 1.35)
	river.call("set_materials", "flow_distance", 0.55)
	river.call("set_materials", "flow_pressure", 0.65)
	river.call("set_materials", "flow_max", 2.4)
	river.call("set_materials", "foam_amount", 1.25)
	river.call("set_materials", "foam_steepness", 1.75)
	river.call("set_materials", "foam_smoothness", 0.62)
	river.call("set_materials", "foam_color", Color(0.86, 0.94, 0.94, 1.0))
	river.call("set_materials", "i_lod0_distance", 140.0)
