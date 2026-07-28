class_name TerrainVisualSurface
extends Node3D

const MATERIAL_COUNT := 4
const CHUNK_SIZE := 16

var _terrain_surface: TerrainMapSurface
var _materials: Array[ShaderMaterial] = []
var _chunks: Dictionary[Vector2i, MeshInstance3D] = {}

func setup(terrain_surface: TerrainMapSurface, texture_definitions: Array[Dictionary]) -> void:
	_terrain_surface = terrain_surface
	_materials.clear()
	for definition: Dictionary in texture_definitions:
		_materials.append(_create_material(load(str(definition["path"])) as Texture2D, float(definition.get("uv_scale", 0.14)), float(definition.get("roughness", 0.8))))
	rebuild()

func rebuild() -> void:
	var chunk_count_x := ceili(float(TerrainMapSurface.MAP_SIZE.x - 1) / float(CHUNK_SIZE))
	var chunk_count_z := ceili(float(TerrainMapSurface.MAP_SIZE.y - 1) / float(CHUNK_SIZE))
	for chunk_z: int in range(chunk_count_z):
		for chunk_x: int in range(chunk_count_x):
			_build_chunk(Vector2i(chunk_x, chunk_z))

func rebuild_region(center: Vector3, radius: float) -> void:
	var min_chunk_x := maxi(0, floori((center.x - radius - 1.0) / float(CHUNK_SIZE)))
	var max_chunk_x := mini(ceili(float(TerrainMapSurface.MAP_SIZE.x - 1) / float(CHUNK_SIZE)) - 1, floori((center.x + radius + 1.0) / float(CHUNK_SIZE)))
	var min_chunk_z := maxi(0, floori((center.z - radius - 1.0) / float(CHUNK_SIZE)))
	var max_chunk_z := mini(ceili(float(TerrainMapSurface.MAP_SIZE.y - 1) / float(CHUNK_SIZE)) - 1, floori((center.z + radius + 1.0) / float(CHUNK_SIZE)))
	for chunk_z: int in range(min_chunk_z, max_chunk_z + 1):
		for chunk_x: int in range(min_chunk_x, max_chunk_x + 1):
			_build_chunk(Vector2i(chunk_x, chunk_z))

func _build_chunk(chunk: Vector2i) -> void:
	if _terrain_surface == null or _terrain_surface.terrain == null:
		return
	var instance: MeshInstance3D
	if _chunks.has(chunk):
		instance = _chunks[chunk]
	else:
		instance = MeshInstance3D.new()
		instance.name = "TerrainChunk_%d_%d" % [chunk.x, chunk.y]
		_chunks[chunk] = instance
		add_child(instance)
	var vertices_by_material: Array[PackedVector3Array] = []
	var normals_by_material: Array[PackedVector3Array] = []
	for material_id: int in range(MATERIAL_COUNT):
		vertices_by_material.append(PackedVector3Array())
		normals_by_material.append(PackedVector3Array())
	var start_x := chunk.x * CHUNK_SIZE
	var end_x := mini(start_x + CHUNK_SIZE, TerrainMapSurface.MAP_SIZE.x - 1)
	var start_z := chunk.y * CHUNK_SIZE
	var end_z := mini(start_z + CHUNK_SIZE, TerrainMapSurface.MAP_SIZE.y - 1)
	for z: int in range(start_z, end_z):
		for x: int in range(start_x, end_x):
			var center := Vector3(float(x) + 0.5, 0.0, float(z) + 0.5)
			var base_id := _terrain_surface.terrain.data.get_control_base_id(center)
			var overlay_id := _terrain_surface.terrain.data.get_control_overlay_id(center)
			var blend := _terrain_surface.terrain.data.get_control_blend(center)
			var material_id := clampi(overlay_id if blend >= 0.5 else base_id, 0, MATERIAL_COUNT - 1)
			_append_cell(vertices_by_material[material_id], normals_by_material[material_id], x, z)
	var result := ArrayMesh.new()
	for material_id: int in range(MATERIAL_COUNT):
		if vertices_by_material[material_id].is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices_by_material[material_id]
		arrays[Mesh.ARRAY_NORMAL] = normals_by_material[material_id]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, _materials[material_id])
	instance.mesh = result

func _append_cell(vertices: PackedVector3Array, normals: PackedVector3Array, x: int, z: int) -> void:
	var p00 := _point(x, z)
	var p10 := _point(x + 1, z)
	var p01 := _point(x, z + 1)
	var p11 := _point(x + 1, z + 1)
	for point: Vector3 in [p00, p01, p10, p10, p01, p11]:
		vertices.append(point + Vector3.UP * 0.12)
		normals.append(_smooth_normal(roundi(point.x), roundi(point.z)))

func _point(x: int, z: int) -> Vector3:
	return Vector3(float(x), _terrain_surface.get_height(float(x), float(z)), float(z))

func _smooth_normal(x: int, z: int) -> Vector3:
	var left := _terrain_surface.get_height(float(maxi(0, x - 1)), float(z))
	var right := _terrain_surface.get_height(float(mini(TerrainMapSurface.MAP_SIZE.x - 1, x + 1)), float(z))
	var back := _terrain_surface.get_height(float(x), float(maxi(0, z - 1)))
	var forward := _terrain_surface.get_height(float(x), float(mini(TerrainMapSurface.MAP_SIZE.y - 1, z + 1)))
	return Vector3(left - right, 2.0, back - forward).normalized()

func _create_material(texture: Texture2D, uv_scale: float, roughness: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;
uniform sampler2D seamless_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float world_scale = 0.14;
uniform float material_roughness = 0.8;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 sample_x = texture(seamless_texture, world_position.zy * world_scale).rgb;
	vec3 sample_y = texture(seamless_texture, world_position.xz * world_scale).rgb;
	vec3 sample_z = texture(seamless_texture, world_position.xy * world_scale).rgb;
	ALBEDO = sample_x * weights.x + sample_y * weights.y + sample_z * weights.z;
	ROUGHNESS = material_roughness;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("seamless_texture", texture)
	material.set_shader_parameter("world_scale", uv_scale)
	material.set_shader_parameter("material_roughness", roughness)
	return material
