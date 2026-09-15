class_name WaterMapSurface
extends Node3D

const MAP_SIZE := Vector2i(160, 190)
const CHUNK_SIZE := 32
const ROWS_PER_FRAME := 12
const CHUNKS_PER_FRAME := 6
const WATER_SURFACE_OFFSET := 0.12
const LEVEL_JOIN_TOLERANCE := 0.35
const ARENA_WATER_SHADER: Shader = preload("res://assets/education_realistic_scene/water/ads.gdshader")
const ARENA_WATER_FOAM: Texture2D = preload("res://assets/education_realistic_scene/water/foam.jpg")
const ARENA_WATER_NORMAL: Texture2D = preload("res://assets/education_realistic_scene/water/water_normal.jpg")

var _cells: Dictionary[Vector2i, float] = {}
var _chunk_instances: Dictionary[Vector2i, MeshInstance3D] = {}
var _water_material: ShaderMaterial
var _active_brush_job: Dictionary = {}
var _pending_brush_request: Dictionary = {}
var _terrain_surface: TerrainMapSurface
var _editable_map_size := MAP_SIZE

func setup(terrain_surface: TerrainMapSurface) -> void:
	_terrain_surface = terrain_surface

func set_map_size(map_size: Vector2i) -> void:
	cancel_queued_edits()
	_editable_map_size = Vector2i(maxi(1, map_size.x), maxi(1, map_size.y))
	var invalid_cells: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		if not _is_valid(cell):
			invalid_cells.append(cell)
	for cell: Vector2i in invalid_cells:
		_cells.erase(cell)
	_rebuild_all_chunks()

func _ready() -> void:
	_water_material = _create_water_material()


func _process(_delta: float) -> void:
	if not _active_brush_job.is_empty():
		_process_brush_job()


func queue_brush(center: Vector3, radius: float, erase: bool = false, level_override: float = NAN) -> void:
	var requested_level: float = _resolve_brush_level(center, radius) if is_nan(level_override) else level_override
	var water_level: float = requested_level if erase else _merge_level_with_touched_water(center, radius, requested_level)
	var request := {
		"center": center,
		"radius": radius,
		"erase": erase,
		"level": water_level,
	}
	if _active_brush_job.is_empty():
		_start_brush_job(request)
	else:
		_pending_brush_request = request


func is_brush_busy() -> bool:
	return not _active_brush_job.is_empty() or not _pending_brush_request.is_empty()


func _start_brush_job(request: Dictionary) -> void:
	var center: Vector3 = request["center"]
	var radius: float = float(request["radius"])
	_active_brush_job = request.duplicate()
	_active_brush_job["min_x"] = maxi(0, floori(center.x - radius))
	_active_brush_job["max_x"] = mini(_editable_map_size.x - 1, ceili(center.x + radius))
	_active_brush_job["max_z"] = mini(_editable_map_size.y - 1, ceili(center.z + radius))
	_active_brush_job["z"] = maxi(0, floori(center.z - radius))
	_active_brush_job["dirty_chunks"] = {}
	_active_brush_job["rebuild_chunks"] = []
	_active_brush_job["rebuild_index"] = 0
	_active_brush_job["phase"] = "paint"


func _process_brush_job() -> void:
	if str(_active_brush_job["phase"]) == "paint":
		_process_brush_rows()
	else:
		_process_brush_chunks()


func _process_brush_rows() -> void:
	var center: Vector3 = _active_brush_job["center"]
	var radius: float = float(_active_brush_job["radius"])
	var erase: bool = bool(_active_brush_job["erase"])
	var water_level: float = float(_active_brush_job["level"])
	var min_x: int = int(_active_brush_job["min_x"])
	var max_x: int = int(_active_brush_job["max_x"])
	var max_z: int = int(_active_brush_job["max_z"])
	var z: int = int(_active_brush_job["z"])
	var dirty_chunks: Dictionary = _active_brush_job["dirty_chunks"]
	var radius_squared := radius * radius
	var rows_processed := 0
	while z <= max_z and rows_processed < ROWS_PER_FRAME:
		var dz := float(z) - center.z
		var horizontal_radius := sqrt(maxf(0.0, radius_squared - dz * dz))
		var row_min_x := maxi(min_x, ceili(center.x - horizontal_radius))
		var row_max_x := mini(max_x, floori(center.x + horizontal_radius))
		for x: int in range(row_min_x, row_max_x + 1):
			var cell := Vector2i(x, z)
			if erase:
				if _cells.erase(cell):
					dirty_chunks[_chunk_for_cell(cell)] = true
			elif _cell_can_hold_water(cell, water_level):
				_cells[cell] = water_level
				dirty_chunks[_chunk_for_cell(cell)] = true
		z += 1
		rows_processed += 1
	_active_brush_job["z"] = z
	if z <= max_z:
		return
	_active_brush_job["rebuild_chunks"] = dirty_chunks.keys()
	_active_brush_job["phase"] = "rebuild"


func _process_brush_chunks() -> void:
	var chunks: Array = _active_brush_job["rebuild_chunks"]
	var index: int = int(_active_brush_job["rebuild_index"])
	var end_index := mini(index + CHUNKS_PER_FRAME, chunks.size())
	while index < end_index:
		_rebuild_chunk(chunks[index] as Vector2i)
		index += 1
	if index < chunks.size():
		_active_brush_job["rebuild_index"] = index
		return
	_active_brush_job.clear()
	if not _pending_brush_request.is_empty():
		var next_request := _pending_brush_request
		_pending_brush_request = {}
		_start_brush_job(next_request)


func load_cells(raw_cells: Array) -> void:
	cancel_queued_edits()
	_cells.clear()
	for raw: Variant in raw_cells:
		if raw is Dictionary:
			var cell := Vector2i(int(raw.get("x", 0)), int(raw.get("z", 0)))
			if _is_valid(cell):
				var fallback_height := (_terrain_surface.get_height(float(cell.x), float(cell.y)) if _terrain_surface != null else 0.0) + 0.12
				_cells[cell] = float(raw.get("y", fallback_height))
	_rebuild_all_chunks()

func apply_brush(center: Vector3, radius: float, erase: bool = false, level_override: float = NAN) -> void:
	var requested_level: float = _resolve_brush_level(center, radius) if is_nan(level_override) else level_override
	var water_level: float = requested_level if erase else _merge_level_with_touched_water(center, radius, requested_level)
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(_editable_map_size.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(_editable_map_size.y - 1, ceili(center.z + radius))
	var radius_squared := radius * radius
	var dirty_chunks: Dictionary[Vector2i, bool] = {}
	for z: int in range(min_z, max_z + 1):
		var dz := float(z) - center.z
		var horizontal_radius := sqrt(maxf(0.0, radius_squared - dz * dz))
		var row_min_x := maxi(min_x, ceili(center.x - horizontal_radius))
		var row_max_x := mini(max_x, floori(center.x + horizontal_radius))
		for x: int in range(row_min_x, row_max_x + 1):
			var cell := Vector2i(x, z)
			if erase:
				if _cells.erase(cell):
					dirty_chunks[_chunk_for_cell(cell)] = true
			elif _cell_can_hold_water(cell, water_level):
				_cells[cell] = water_level
				dirty_chunks[_chunk_for_cell(cell)] = true
	_rebuild_chunks(dirty_chunks.keys())


func cancel_queued_edits() -> void:
	_active_brush_job.clear()
	_pending_brush_request.clear()


func clear() -> void:
	cancel_queued_edits()
	_cells.clear()
	for instance: MeshInstance3D in _chunk_instances.values():
		instance.queue_free()
	_chunk_instances.clear()


func serialize_cells() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sorted_cells: Array[Vector2i] = _cells.keys()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	for cell: Vector2i in sorted_cells:
		result.append({"x": cell.x, "z": cell.y, "y": _cells[cell]})
	return result

func get_cell_count() -> int:
	return _cells.size()

func _is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _editable_map_size.x and cell.y >= 0 and cell.y < _editable_map_size.y

func _chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))


func _rebuild_all_chunks() -> void:
	var all_chunks: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _cells:
		all_chunks[_chunk_for_cell(cell)] = true
	for chunk: Vector2i in _chunk_instances:
		all_chunks[chunk] = true
	_rebuild_chunks(all_chunks.keys())


func _rebuild_chunks(chunks: Array[Vector2i]) -> void:
	for chunk: Vector2i in chunks:
		_rebuild_chunk(chunk)


func _rebuild_chunk(chunk: Vector2i) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var start_x := chunk.x * CHUNK_SIZE
	var start_z := chunk.y * CHUNK_SIZE
	var end_x := mini(start_x + CHUNK_SIZE, _editable_map_size.x)
	var end_z := mini(start_z + CHUNK_SIZE, _editable_map_size.y)
	for z: int in range(start_z, end_z):
		for x: int in range(start_x, end_x):
			var cell := Vector2i(x, z)
			if _cells.has(cell):
				_append_smooth_water_cell(vertices, normals, uvs, indices, cell)
	if vertices.is_empty():
		if _chunk_instances.has(chunk):
			_chunk_instances[chunk].queue_free()
			_chunk_instances.erase(chunk)
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance: MeshInstance3D
	if _chunk_instances.has(chunk):
		instance = _chunk_instances[chunk]
	else:
		instance = MeshInstance3D.new()
		instance.name = "WaterChunk_%d_%d" % [chunk.x, chunk.y]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.material_override = _water_material
		add_child(instance)
		_chunk_instances[chunk] = instance
	instance.mesh = mesh


func _append_smooth_water_cell(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, cell: Vector2i) -> void:
	var vertex_start := vertices.size()
	var x0 := float(cell.x) - 0.5
	var x1 := float(cell.x) + 0.5
	var z0 := float(cell.y) - 0.5
	var z1 := float(cell.y) + 0.5
	var y00 := _corner_water_level(cell, 0, 0)
	var y10 := _corner_water_level(cell, 1, 0)
	var y11 := _corner_water_level(cell, 1, 1)
	var y01 := _corner_water_level(cell, 0, 1)
	var p00 := Vector3(x0, y00, z0)
	var p10 := Vector3(x1, y10, z0)
	var p11 := Vector3(x1, y11, z1)
	var p01 := Vector3(x0, y01, z1)
	var normal_a := (p11 - p00).cross(p10 - p00).normalized()
	var normal_b := (p01 - p00).cross(p11 - p00).normalized()
	var smooth_normal := (normal_a + normal_b).normalized()
	if smooth_normal.y < 0.0:
		smooth_normal = -smooth_normal
	vertices.append_array(PackedVector3Array([p00, p10, p11, p01]))
	normals.append_array(PackedVector3Array([smooth_normal, smooth_normal, smooth_normal, smooth_normal]))
	uvs.append_array(PackedVector2Array([
		Vector2(x0, z0) * 0.08, Vector2(x1, z0) * 0.08,
		Vector2(x1, z1) * 0.08, Vector2(x0, z1) * 0.08,
	]))
	indices.append_array(PackedInt32Array([
		vertex_start, vertex_start + 1, vertex_start + 2,
		vertex_start, vertex_start + 2, vertex_start + 3,
	]))


func _corner_water_level(cell: Vector2i, positive_x: int, positive_z: int) -> float:
	var total := 0.0
	var count := 0
	for offset_z: int in range(positive_z - 1, positive_z + 1):
		for offset_x: int in range(positive_x - 1, positive_x + 1):
			var neighbor := cell + Vector2i(offset_x, offset_z)
			if _cells.has(neighbor):
				total += float(_cells[neighbor])
				count += 1
	return total / float(maxi(1, count))


func _cell_can_hold_water(cell: Vector2i, water_level: float) -> bool:
	if _cells.has(cell):
		return true
	if _terrain_surface == null:
		return true
	var ground_height: float = _terrain_surface.get_height(float(cell.x), float(cell.y))
	return ground_height + WATER_SURFACE_OFFSET <= water_level


func _merge_level_with_touched_water(center: Vector3, radius: float, requested_level: float) -> float:
	var merged_level := requested_level
	var min_x := maxi(0, floori(center.x - radius - 1.0))
	var max_x := mini(_editable_map_size.x - 1, ceili(center.x + radius + 1.0))
	var min_z := maxi(0, floori(center.z - radius - 1.0))
	var max_z := mini(_editable_map_size.y - 1, ceili(center.z + radius + 1.0))
	var search_radius_squared := (radius + 1.5) * (radius + 1.5)
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var cell := Vector2i(x, z)
			if not _cells.has(cell):
				continue
			if Vector2(float(x) - center.x, float(z) - center.z).length_squared() > search_radius_squared:
				continue
			var existing_level := float(_cells[cell])
			if absf(existing_level - requested_level) <= LEVEL_JOIN_TOLERANCE or existing_level > requested_level:
				merged_level = maxf(merged_level, existing_level)
	return merged_level


func _resolve_brush_level(center: Vector3, radius: float) -> float:
	var accumulated := 0.0
	var connected_cells := 0
	var search_radius := radius + 1.5
	for cell: Vector2i in _cells:
		if Vector2(float(cell.x) - center.x, float(cell.y) - center.z).length() <= search_radius:
			accumulated += float(_cells[cell])
			connected_cells += 1
	if connected_cells > 0:
		return accumulated / float(connected_cells)
	return center.y + 0.12

func _create_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ARENA_WATER_SHADER
	# Te same parametry co w Arena (test): refrakcja, animowane normalne i piana brzegowa.
	material.set_shader_parameter("surface_color", Color(0.619608, 0.839216, 0.858824))
	material.set_shader_parameter("depth_color", Color(0.223529, 0.780392, 0.831373))
	material.set_shader_parameter("opacity", 0.5)
	material.set_shader_parameter("normal_scale", -0.487999)
	material.set_shader_parameter("beer_factor", 7.225)
	material.set_shader_parameter("_roughness", 0.031)
	material.set_shader_parameter("_refraction", 0.014)
	material.set_shader_parameter("_uv_scale", 0.256)
	material.set_shader_parameter("_foam_strength", 0.519)
	material.set_shader_parameter("_foam_size", 0.2)
	material.set_shader_parameter("_foam", ARENA_WATER_FOAM)
	material.set_shader_parameter("normal_map", ARENA_WATER_NORMAL)
	return material
