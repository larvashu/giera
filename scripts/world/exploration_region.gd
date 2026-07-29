class_name ExplorationRegion
extends Node3D

const REGION_SIZE := Vector2(160.0, 190.0)
const CELLS_X := 32
const CELLS_Z := 38
const TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/purple_tree_01.glb"),
	preload("res://assets/models/environment/purple_tree_02.glb"),
	preload("res://assets/models/environment/purple_tree_03.glb")
]
const LARGE_TREE_SCENE: PackedScene = preload("res://assets/models/environment/large_tree.glb")

var coordinate := Vector2i.ZERO
var descriptor: Dictionary = {}
var detailed := true
var _height_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()

func configure(region: Dictionary, use_detailed_assets: bool = true) -> void:
	descriptor = region
	detailed = use_detailed_assets
	coordinate = Vector2i(int(region.get("x", 0)), int(region.get("z", 0)))
	position = Vector3(coordinate.x * REGION_SIZE.x, 0.0, coordinate.y * REGION_SIZE.y)
	name = "WildClearing_L%d_%d_%d" % [int(region.get("layer", 1)), coordinate.x, coordinate.y]

func _ready() -> void:
	_height_noise.seed = 2_904_117
	_height_noise.frequency = 0.012
	_height_noise.fractal_octaves = 4
	_detail_noise.seed = int(descriptor.get("seed", 1))
	_detail_noise.frequency = 0.035
	_build_terrain()
	_build_roads()
	_build_forest()
	_build_grass_and_bushes()
	_build_landmarks()

func height_at(local_x: float, local_z: float) -> float:
	var gx := local_x + coordinate.x * REGION_SIZE.x
	var gz := local_z + coordinate.y * REGION_SIZE.y
	return _height_noise.get_noise_2d(gx, gz) * 2.4 + _height_noise.get_noise_2d(gx * 0.28, gz * 0.28) * 1.2

func _build_terrain() -> void:
	var mesh := _grid_mesh(false)
	var terrain := MeshInstance3D.new(); terrain.name = "SeamlessWildClearingTerrain"; terrain.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = Color("476f36"); material.roughness = 0.98
	terrain.material_override = material; add_child(terrain)
	var body := StaticBody3D.new(); body.name = "TerrainCollision"
	var collision := CollisionShape3D.new(); collision.shape = mesh.create_trimesh_shape(); body.add_child(collision); add_child(body)

func _grid_mesh(_unused: bool) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(CELLS_Z):
		for x in range(CELLS_X):
			var x0: float = float(x) * REGION_SIZE.x / CELLS_X
			var x1: float = float(x + 1) * REGION_SIZE.x / CELLS_X
			var z0: float = float(z) * REGION_SIZE.y / CELLS_Z
			var z1: float = float(z + 1) * REGION_SIZE.y / CELLS_Z
			_add_ground_triangle(surface, Vector3(x0,height_at(x0,z0),z0), Vector3(x1,height_at(x1,z0),z0), Vector3(x1,height_at(x1,z1),z1))
			_add_ground_triangle(surface, Vector3(x0,height_at(x0,z0),z0), Vector3(x1,height_at(x1,z1),z1), Vector3(x0,height_at(x0,z1),z1))
	surface.generate_normals(); return surface.commit()

func _add_ground_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex: Vector3 in [a,b,c]: surface.set_uv(Vector2(vertex.x / 8.0, vertex.z / 8.0)); surface.add_vertex(vertex)

func _build_roads() -> void:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dwie glowne drogi lacza wszystkie sasiednie plansze na ich krawedziach.
	for index in range(48):
		var z0 := float(index) * REGION_SIZE.y / 48.0
		var z1 := float(index + 1) * REGION_SIZE.y / 48.0
		_add_road_segment(surface, Vector2(_vertical_road_x(z0), z0), Vector2(_vertical_road_x(z1), z1), 3.2)
	for index in range(40):
		var x0 := float(index) * REGION_SIZE.x / 40.0
		var x1 := float(index + 1) * REGION_SIZE.x / 40.0
		_add_road_segment(surface, Vector2(x0, _horizontal_road_z(x0)), Vector2(x1, _horizontal_road_z(x1)), 3.0)
	var road_mesh := surface.commit()
	var road := MeshInstance3D.new(); road.name = "ConnectedDirtRoads"; road.mesh = road_mesh
	var material := StandardMaterial3D.new(); material.albedo_color = Color("705333"); material.roughness = 1.0
	road.material_override = material; add_child(road)

func _add_road_segment(surface: SurfaceTool, a: Vector2, b: Vector2, half_width: float) -> void:
	var direction := (b - a).normalized(); var normal := Vector2(-direction.y, direction.x) * half_width
	var points: Array[Vector2] = [a-normal, a+normal, b+normal, b-normal]
	for order: int in [0,1,2,0,2,3]:
		var p := points[order]; surface.set_uv(p / 4.0); surface.add_vertex(Vector3(p.x, height_at(p.x,p.y) + 0.045, p.y))

func _vertical_road_x(local_z: float) -> float:
	var global_z := local_z + coordinate.y * REGION_SIZE.y
	return REGION_SIZE.x * 0.5 + sin(global_z * 0.035) * 13.0

func _horizontal_road_z(local_x: float) -> float:
	var global_x := local_x + coordinate.x * REGION_SIZE.x
	return REGION_SIZE.y * 0.5 + sin(global_x * 0.038) * 14.0

func _is_on_road(point: Vector2, margin: float = 0.0) -> bool:
	return absf(point.x - _vertical_road_x(point.y)) < 5.0 + margin or absf(point.y - _horizontal_road_z(point.x)) < 4.8 + margin

func _build_forest() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(descriptor.get("seed", 1))
	if not detailed:
		_build_forest_proxy(rng)
		return
	var transforms: Array[Array] = [[],[],[]]
	var collision_body := StaticBody3D.new(); collision_body.name = "TreeObstacleCollisions"; add_child(collision_body)
	for index in range(145):
		var point := Vector2(rng.randf_range(3.0, REGION_SIZE.x-3.0), rng.randf_range(3.0, REGION_SIZE.y-3.0))
		if _is_on_road(point, 2.5): continue
		var variant := rng.randi_range(0, 2); var scale := rng.randf_range(4.2, 7.2)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale)
		transforms[variant].append(Transform3D(basis, Vector3(point.x, height_at(point.x,point.y) + scale, point.y)))
		if index % 3 == 0:
			var shape := CollisionShape3D.new(); var cylinder := CylinderShape3D.new(); cylinder.radius = minf(scale*0.18,1.4); cylinder.height = scale*1.5
			shape.shape = cylinder; shape.position = Vector3(point.x,height_at(point.x,point.y)+scale*0.75,point.y); collision_body.add_child(shape)
	for variant in range(3): _add_scene_multimesh("ForestTrees_%d" % variant, TREE_SCENES[variant], transforms[variant], false)

func _build_forest_proxy(rng: RandomNumberGenerator) -> void:
	# Streamowane plansze uzywaja tych samych modeli co Dzika Polana, ale rzadszych i bez cieni.
	# Nie zmieniamy ich po przekroczeniu granicy, wiec drzewa nie przeskakuja miedzy LOD-ami.
	var transforms: Array[Array] = [[],[],[]]
	for index in range(54):
		var point := Vector2(rng.randf_range(4.0,REGION_SIZE.x-4.0),rng.randf_range(4.0,REGION_SIZE.y-4.0))
		if _is_on_road(point,2.0): continue
		var variant := rng.randi_range(0,2)
		var scale := rng.randf_range(4.0,6.6)
		transforms[variant].append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(point.x,height_at(point.x,point.y)+scale,point.y)))
	for variant in range(3): _add_scene_multimesh("StreamedForestTrees_%d" % variant,TREE_SCENES[variant],transforms[variant],false)

func begin_stream_fade() -> void:
	var geometry_nodes := find_children("*","GeometryInstance3D",true,false)
	for node: GeometryInstance3D in geometry_nodes:
		node.transparency = 1.0
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(node,"transparency",0.0,0.65)

func _build_grass_and_bushes() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(descriptor.get("seed", 1)) + 413
	var grass_mesh := QuadMesh.new(); grass_mesh.size = Vector2(0.28, 0.65); grass_mesh.orientation = PlaneMesh.FACE_Z
	var grass_material := StandardMaterial3D.new(); grass_material.albedo_color = Color("244f1e"); grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mesh.material = grass_material
	var grass_transforms: Array[Transform3D] = []
	for index in range(950 if detailed else 220):
		var p := Vector2(rng.randf_range(1.0,REGION_SIZE.x-1.0),rng.randf_range(1.0,REGION_SIZE.y-1.0))
		if _is_on_road(p): continue
		var scale := rng.randf_range(0.7,1.35); grass_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,height_at(p.x,p.y)+0.3*scale,p.y)))
	_add_mesh_multimesh("GrassCoverage", grass_mesh, grass_transforms, false)
	var bush_mesh := SphereMesh.new(); bush_mesh.radius = 0.55; bush_mesh.height = 0.8; bush_mesh.radial_segments = 8; bush_mesh.rings = 4
	var bush_material := StandardMaterial3D.new(); bush_material.albedo_color = Color("315e2d"); bush_mesh.material = bush_material
	var bushes: Array[Transform3D] = []
	for index in range(170 if detailed else 45):
		var p := Vector2(rng.randf_range(2.0,REGION_SIZE.x-2.0),rng.randf_range(2.0,REGION_SIZE.y-2.0))
		if _is_on_road(p,1.0): continue
		var scale := rng.randf_range(0.8,1.8); bushes.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,height_at(p.x,p.y)+0.35*scale,p.y)))
	_add_mesh_multimesh("Bushes", bush_mesh, bushes, false)

func _build_landmarks() -> void:
	if not detailed: return
	var rng := RandomNumberGenerator.new(); rng.seed = int(descriptor.get("seed", 1)) + 991
	var transforms: Array[Transform3D] = []
	for index in range(3):
		var p := Vector2(rng.randf_range(18.0,REGION_SIZE.x-18.0),rng.randf_range(18.0,REGION_SIZE.y-18.0))
		if _is_on_road(p,5.0): continue
		var scale := rng.randf_range(7.0,11.0); transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,height_at(p.x,p.y)+scale,p.y)))
	_add_scene_multimesh("LandmarkTrees", LARGE_TREE_SCENE, transforms, true)

func _add_scene_multimesh(instance_name: String, scene: PackedScene, transforms: Array, shadows: bool) -> void:
	var root := scene.instantiate() as Node3D
	if root == null: return
	var nodes := root.find_children("*","MeshInstance3D",true,false)
	if not nodes.is_empty(): _add_mesh_multimesh(instance_name,(nodes[0] as MeshInstance3D).mesh,transforms,shadows)
	root.free()

func _add_mesh_multimesh(instance_name: String, mesh: Mesh, transforms: Array, shadows: bool) -> void:
	if transforms.is_empty() or mesh == null: return
	var multimesh := MultiMesh.new(); multimesh.transform_format = MultiMesh.TRANSFORM_3D; multimesh.mesh = mesh; multimesh.instance_count = transforms.size()
	for index in range(transforms.size()): multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var renderer := MultiMeshInstance3D.new(); renderer.name = instance_name; renderer.multimesh = multimesh; renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(renderer)
