class_name WaterMapSurface
extends Node3D

const MAP_SIZE := Vector2i(160, 190)

var _cells: Dictionary[Vector2i, bool] = {}
var _mesh_instance: MeshInstance3D
var _terrain_surface: TerrainMapSurface

func setup(terrain_surface: TerrainMapSurface) -> void:
	_terrain_surface = terrain_surface

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
				_cells[cell] = true
	_rebuild_mesh()

func apply_brush(center: Vector3, radius: float, erase: bool = false) -> void:
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(MAP_SIZE.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(MAP_SIZE.y - 1, ceili(center.z + radius))
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var cell := Vector2i(x, z)
			if Vector2(float(x) - center.x, float(z) - center.z).length() > radius:
				continue
			if erase:
				_cells.erase(cell)
			else:
				_cells[cell] = true
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
		result.append({"x": cell.x, "z": cell.y})
	return result

func get_cell_count() -> int:
	return _cells.size()

func _is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_SIZE.x and cell.y >= 0 and cell.y < MAP_SIZE.y

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
		var x0 := float(cell.x) - 0.5
		var x1 := float(cell.x) + 0.5
		var z0 := float(cell.y) - 0.5
		var z1 := float(cell.y) + 0.5
		vertices.append_array(PackedVector3Array([
			Vector3(x0, _water_height(x0, z0), z0), Vector3(x1, _water_height(x1, z0), z0),
			Vector3(x1, _water_height(x1, z1), z1), Vector3(x0, _water_height(x0, z1), z1),
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

func _water_height(world_x: float, world_z: float) -> float:
	return (_terrain_surface.get_height(world_x, world_z) if _terrain_surface != null else 0.0) + 0.12

func _create_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.035, 0.34, 0.39, 0.72);
uniform vec4 deep_color : source_color = vec4(0.015, 0.075, 0.16, 0.88);
uniform float wave_height = 0.055;
uniform float wave_speed = 0.65;

varying float wave_value;

void vertex() {
	float wave_a = sin((VERTEX.x + TIME * wave_speed) * 1.35);
	float wave_b = cos((VERTEX.z - TIME * wave_speed * 0.73) * 1.71);
	wave_value = (wave_a + wave_b) * 0.5;
	VERTEX.y += wave_value * wave_height;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float ripple = 0.5 + 0.5 * sin((UV.x + UV.y + TIME * 0.08) * 34.0);
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, 0.38 + fresnel * 0.48);
	water += vec3(0.025, 0.06, 0.07) * ripple;
	ALBEDO = water;
	METALLIC = 0.05;
	ROUGHNESS = mix(0.16, 0.05, fresnel);
	SPECULAR = 0.95;
	ALPHA = mix(shallow_color.a, deep_color.a, fresnel);
	NORMAL_MAP_DEPTH = 0.35;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
