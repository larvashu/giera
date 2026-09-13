class_name WaterMapSurface
extends Node3D

const MAP_SIZE := Vector2i(160, 190)
const ARENA_WATER_SHADER: Shader = preload("res://assets/education_realistic_scene/water/ads.gdshader")
const ARENA_WATER_FOAM: Texture2D = preload("res://assets/education_realistic_scene/water/foam.jpg")
const ARENA_WATER_NORMAL: Texture2D = preload("res://assets/education_realistic_scene/water/water_normal.jpg")

var _cells: Dictionary[Vector2i, float] = {}
var _mesh_instance: MeshInstance3D
var _terrain_surface: TerrainMapSurface
var _editable_map_size := MAP_SIZE

func setup(terrain_surface: TerrainMapSurface) -> void:
	_terrain_surface = terrain_surface

func set_map_size(map_size: Vector2i) -> void:
	_editable_map_size = Vector2i(maxi(1, map_size.x), maxi(1, map_size.y))
	var invalid_cells: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		if not _is_valid(cell):
			invalid_cells.append(cell)
	for cell: Vector2i in invalid_cells:
		_cells.erase(cell)
	_rebuild_mesh()

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "PaintedWater"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.material_override = _create_water_material()
	add_child(_mesh_instance)

func load_cells(raw_cells: Array) -> void:
	_cells.clear()
	for raw: Variant in raw_cells:
		if raw is Dictionary:
			var cell := Vector2i(int(raw.get("x", 0)), int(raw.get("z", 0)))
			if _is_valid(cell):
				var fallback_height := (_terrain_surface.get_height(float(cell.x), float(cell.y)) if _terrain_surface != null else 0.0) + 0.12
				_cells[cell] = float(raw.get("y", fallback_height))
	_rebuild_mesh()

func apply_brush(center: Vector3, radius: float, erase: bool = false, level_override: float = NAN) -> void:
	var water_level := _resolve_brush_level(center, radius) if is_nan(level_override) else level_override
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(_editable_map_size.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(_editable_map_size.y - 1, ceili(center.z + radius))
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var cell := Vector2i(x, z)
			if Vector2(float(x) - center.x, float(z) - center.z).length() > radius:
				continue
			if erase:
				_cells.erase(cell)
			else:
				_cells[cell] = water_level
	_rebuild_mesh()

func clear() -> void:
	_cells.clear()
	_rebuild_mesh()

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

func _rebuild_mesh() -> void:
	if _mesh_instance == null:
		return
	if _cells.is_empty():
		_mesh_instance.mesh = null
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for cell: Vector2i in _cells:
		var start := vertices.size()
		var water_level := float(_cells[cell])
		var x0 := float(cell.x) - 0.5
		var x1 := float(cell.x) + 0.5
		var z0 := float(cell.y) - 0.5
		var z1 := float(cell.y) + 0.5
		vertices.append_array(PackedVector3Array([
			Vector3(x0, water_level, z0), Vector3(x1, water_level, z0),
			Vector3(x1, water_level, z1), Vector3(x0, water_level, z1),
		]))
		normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
		uvs.append_array(PackedVector2Array([
			Vector2(x0, z0) * 0.08, Vector2(x1, z0) * 0.08,
			Vector2(x1, z1) * 0.08, Vector2(x0, z1) * 0.08,
		]))
		indices.append_array(PackedInt32Array([
			start, start + 1, start + 2, start, start + 2, start + 3,
		]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh

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
