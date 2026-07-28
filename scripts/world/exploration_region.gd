class_name ExplorationRegion
extends Node3D

const REGION_SIZE := Vector2(160.0, 190.0)
const CELLS_X := 24
const CELLS_Z := 28

var coordinate := Vector2i.ZERO
var descriptor: Dictionary = {}
var _noise := FastNoiseLite.new()

func configure(region: Dictionary) -> void:
	descriptor = region
	coordinate = Vector2i(int(region.get("x", 0)), int(region.get("z", 0)))
	position = Vector3(coordinate.x * REGION_SIZE.x, 0.0, coordinate.y * REGION_SIZE.y)
	name = "Region_%d_%d" % [coordinate.x, coordinate.y]

func _ready() -> void:
	_noise.seed = int(descriptor.get("seed", 1))
	_noise.frequency = 0.018
	_noise.fractal_octaves = 4
	build()

func build() -> void:
	var mesh := _build_terrain_mesh()
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material(String(descriptor.get("biome", "forest")))
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	_build_multimesh_details()

func height_at(local_x: float, local_z: float) -> float:
	var biome := String(descriptor.get("biome", "forest"))
	var amplitude := 2.2
	if biome == "rocky": amplitude = 8.0
	elif biome == "desert": amplitude = 3.5
	elif biome == "swamp": amplitude = 0.8
	return _noise.get_noise_2d(local_x + coordinate.x * REGION_SIZE.x, local_z + coordinate.y * REGION_SIZE.y) * amplitude

func _build_terrain_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(CELLS_Z):
		for x in range(CELLS_X):
			var x0 := float(x) * REGION_SIZE.x / CELLS_X
			var x1 := float(x + 1) * REGION_SIZE.x / CELLS_X
			var z0 := float(z) * REGION_SIZE.y / CELLS_Z
			var z1 := float(z + 1) * REGION_SIZE.y / CELLS_Z
			_add_triangle(surface, Vector3(x0, height_at(x0,z0), z0), Vector3(x1, height_at(x1,z0), z0), Vector3(x1, height_at(x1,z1), z1))
			_add_triangle(surface, Vector3(x0, height_at(x0,z0), z0), Vector3(x1, height_at(x1,z1), z1), Vector3(x0, height_at(x0,z1), z1))
	surface.generate_normals()
	return surface.commit()

func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_uv(Vector2(vertex.x / 8.0, vertex.z / 8.0))
		surface.add_vertex(vertex)

func _terrain_material(biome: String) -> StandardMaterial3D:
	var colors := {"forest": Color("405d32"), "meadow": Color("608947"), "desert": Color("bd965c"), "rocky": Color("696863"), "swamp": Color("40564b")}
	var material := StandardMaterial3D.new()
	material.albedo_color = colors.get(biome, Color("50683e"))
	material.roughness = 0.95
	material.vertex_color_use_as_albedo = false
	return material

func _build_multimesh_details() -> void:
	var biome := String(descriptor.get("biome", "forest"))
	var count := 150 if biome == "forest" else 70
	if biome == "desert": count = 35
	var rng := RandomNumberGenerator.new()
	rng.seed = int(descriptor.get("seed", 1))
	var mesh: PrimitiveMesh
	if biome == "rocky" or biome == "desert":
		var rock := BoxMesh.new(); rock.size = Vector3(2.4, 3.0, 2.0); mesh = rock
	else:
		var tree := CylinderMesh.new(); tree.top_radius = 0.4; tree.bottom_radius = 1.5; tree.height = 9.0; mesh = tree
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = count
	multimesh.mesh = mesh
	for index in count:
		var x := rng.randf_range(3.0, REGION_SIZE.x - 3.0)
		var z := rng.randf_range(3.0, REGION_SIZE.y - 3.0)
		var scale := rng.randf_range(0.7, 1.6)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, height_at(x,z) + 4.5 * scale, z)))
	var renderer := MultiMeshInstance3D.new()
	renderer.name = "ObstacleMultiMesh"
	renderer.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8d7656") if biome in ["rocky", "desert"] else Color("294f2a")
	renderer.material_override = material
	add_child(renderer)
