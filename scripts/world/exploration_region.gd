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
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/terrain/realistic_grass.png")

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
	_build_forest()
	_build_grass_and_bushes()
	_build_landmarks()

func height_at(local_x: float, local_z: float) -> float:
	var gx := local_x + coordinate.x * REGION_SIZE.x
	var gz := local_z + coordinate.y * REGION_SIZE.y
	# Ten sam drobny profil co centralny GridManager, z lagodnymi globalnymi pagorkami.
	var result := 0.018 * sin(gx * 0.41 + gz * 0.19)
	result += 0.012 * cos(gx * 0.23 - gz * 0.37)
	result += _height_noise.get_noise_2d(gx, gz) * 0.58
	return result

func _build_terrain() -> void:
	var mesh := _grid_mesh(false)
	var terrain := MeshInstance3D.new(); terrain.name = "SeamlessWildClearingTerrain"; terrain.mesh = mesh
	terrain.material_override = _create_wild_clearing_material(); add_child(terrain)
	var body := StaticBody3D.new(); body.name = "TerrainCollision"
	var collision := CollisionShape3D.new(); collision.shape = mesh.create_trimesh_shape(); body.add_child(collision); add_child(body)

func _create_wild_clearing_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 vec3 grass=texture(grass_texture,p/4.0).rgb*vec3(0.52,0.82,0.44);
 float broad=noise2(p*0.032)+noise2(p*0.071+vec2(13.7,4.2))*0.42;
 float sand_mask=smoothstep(1.02,1.24,broad);
 float sand_detail=noise2(p*0.82+vec2(2.1,8.6));
 vec3 sand=mix(vec3(0.42,0.30,0.16),vec3(0.72,0.55,0.32),0.34+sand_detail*0.46);
 vec3 ground=mix(grass,sand,sand_mask*0.92);
 vec2 sector=floor(p/vec2(160.0,190.0));
 vec2 local=p-sector*vec2(160.0,190.0);
 float ns_x=80.0+sin(p.y*0.055+sector.x*1.7)*12.0;
 float diagonal_z=30.0+p.x*0.72+sin(p.x*0.09)*6.0;
 float ew_z=132.0+sin(p.x*0.07+sector.y*1.4)*10.0;
 float ns=1.0-smoothstep(1.65,2.45,abs(local.x-ns_x));
 float diagonal=1.0-smoothstep(1.5,2.25,abs(p.y-diagonal_z));
 float ew=1.0-smoothstep(1.5,2.25,abs(local.y-ew_z));
 float trail=max(ns,max(diagonal,ew));
 float trail_detail=noise2(p*0.48+vec2(6.2,19.7));
 vec3 trail_color=mix(vec3(0.46,0.30,0.08),vec3(0.88,0.68,0.22),0.48+trail_detail*0.38);
 ALBEDO=mix(ground,trail_color,trail*0.94); ROUGHNESS=mix(0.88,0.76,sand_mask);
}"""
	var material := ShaderMaterial.new(); material.shader = shader; material.set_shader_parameter("grass_texture",GRASS_TEXTURE)
	return material

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
	return 80.0 + sin(global_z * 0.055 + coordinate.x * 1.7) * 12.0

func _horizontal_road_z(local_x: float) -> float:
	var global_x := local_x + coordinate.x * REGION_SIZE.x
	return 132.0 + sin(global_x * 0.07 + coordinate.y * 1.4) * 10.0

func _diagonal_road_z(local_x: float) -> float:
	var global_x := local_x + coordinate.x * REGION_SIZE.x
	return 30.0 - coordinate.y * REGION_SIZE.y + global_x * 0.72 + sin(global_x * 0.09) * 6.0

func _is_on_road(point: Vector2, margin: float = 0.0) -> bool:
	return (
		absf(point.x - _vertical_road_x(point.y)) < 4.8 + margin
		or absf(point.y - _horizontal_road_z(point.x)) < 4.4 + margin
		or absf(point.y - _diagonal_road_z(point.x)) < 4.4 + margin
	)

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
	const TARGET_TREE_COUNT := 321
	const FOREST_SPACING := 9
	var points: Array[Vector2] = []
	var row := 0
	for z in range(2, int(REGION_SIZE.y)-2, FOREST_SPACING):
		var row_offset := 4.5 if row % 2 == 1 else 0.0
		for x in range(2, int(REGION_SIZE.x)-2, FOREST_SPACING):
			var point := Vector2(float(x)+row_offset+rng.randf_range(-2.2,2.2),float(z)+rng.randf_range(-2.2,2.2))
			point.x=clampf(point.x,2.0,REGION_SIZE.x-2.0)
			if not _is_on_road(point,1.0): points.append(point)
		row+=1
	var attempts := 0
	while points.size()<TARGET_TREE_COUNT and attempts<6000:
		attempts+=1
		var candidate:=Vector2(rng.randf_range(3.0,REGION_SIZE.x-3.0),rng.randf_range(3.0,REGION_SIZE.y-3.0))
		if _is_on_road(candidate,1.0): continue
		var separated:=true
		for existing:Vector2 in points:
			if existing.distance_squared_to(candidate)<14.44: separated=false; break
		if separated: points.append(candidate)
	if points.size()>TARGET_TREE_COUNT: points.resize(TARGET_TREE_COUNT)
	var detailed_transforms:Array[Array]=[[],[],[]]
	var canopy_transforms:Array[Transform3D]=[]
	var trunk_transforms:Array[Transform3D]=[]
	for index in range(points.size()):
		var point:=points[index]
		var yaw:=rng.randf_range(0.0,TAU)
		if index%12==0:
			var variant:=rng.randi_range(0,2); var model_scale:=rng.randf_range(4.2,6.8)
			detailed_transforms[variant].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*model_scale),Vector3(point.x,height_at(point.x,point.y)+model_scale,point.y)))
		else:
			var proxy_scale:=rng.randf_range(0.78,1.38); var basis:=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*proxy_scale)
			canopy_transforms.append(Transform3D(basis,Vector3(point.x,height_at(point.x,point.y)+6.1*proxy_scale,point.y)))
			trunk_transforms.append(Transform3D(basis,Vector3(point.x,height_at(point.x,point.y)+2.6*proxy_scale,point.y)))
	for variant in range(3): _add_scene_chunked_multimesh("StreamedForestTrees_%d"%variant,TREE_SCENES[variant],detailed_transforms[variant])
	var canopy_mesh:=SphereMesh.new(); canopy_mesh.radius=2.15; canopy_mesh.height=7.2; canopy_mesh.radial_segments=6; canopy_mesh.rings=3
	var canopy_material:=StandardMaterial3D.new(); canopy_material.albedo_color=Color("244d29"); canopy_material.roughness=0.94; canopy_mesh.material=canopy_material
	var trunk_mesh:=CylinderMesh.new(); trunk_mesh.top_radius=0.34; trunk_mesh.bottom_radius=0.5; trunk_mesh.height=5.2; trunk_mesh.radial_segments=6
	var trunk_material:=StandardMaterial3D.new(); trunk_material.albedo_color=Color("4b2c17"); trunk_material.roughness=0.98; trunk_mesh.material=trunk_material
	_add_chunked_mesh_multimesh("BackgroundForestCanopies",canopy_mesh,canopy_transforms)
	_add_chunked_mesh_multimesh("BackgroundForestTrunks",trunk_mesh,trunk_transforms)

func _add_scene_chunked_multimesh(instance_name:String,scene:PackedScene,transforms:Array) -> void:
	if transforms.is_empty(): return
	var root:=scene.instantiate() as Node3D
	if root==null: return
	var nodes:=root.find_children("*","MeshInstance3D",true,false)
	if not nodes.is_empty(): _add_chunked_mesh_multimesh(instance_name,(nodes[0] as MeshInstance3D).mesh,transforms)
	root.free()

func _add_chunked_mesh_multimesh(instance_name:String,mesh:Mesh,transforms:Array) -> void:
	if transforms.is_empty() or mesh==null: return
	const CHUNK_SIZE:=48.0
	var chunks:Dictionary={}
	for value:Variant in transforms:
		var transform:=value as Transform3D
		var key:=Vector2i(floori(transform.origin.x/CHUNK_SIZE),floori(transform.origin.z/CHUNK_SIZE))
		if not chunks.has(key): chunks[key]=[]
		(chunks[key] as Array).append(transform)
	for key:Vector2i in chunks:
		var center:=Vector3((key.x+0.5)*CHUNK_SIZE,0.0,(key.y+0.5)*CHUNK_SIZE)
		var adjusted:Array[Transform3D]=[]
		for value:Variant in chunks[key]:
			var transform:=value as Transform3D; transform.origin-=center; adjusted.append(transform)
		var chunk_name:="%s_%d_%d"%[instance_name,key.x,key.y]
		_add_mesh_multimesh(chunk_name,mesh,adjusted,false)
		var renderer:=get_node(chunk_name) as MultiMeshInstance3D
		renderer.position=center
		renderer.visibility_range_end=95.0
		renderer.visibility_range_end_margin=0.0
		renderer.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func begin_stream_fade() -> void:
	var geometry_nodes := find_children("*","GeometryInstance3D",true,false)
	for node: GeometryInstance3D in geometry_nodes:
		node.transparency = 1.0
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(node,"transparency",0.0,1.6)

func _build_grass_and_bushes() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(descriptor.get("seed", 1)) + 413
	var grass_mesh := QuadMesh.new(); grass_mesh.size = Vector2(0.28, 0.65); grass_mesh.orientation = PlaneMesh.FACE_Z
	var grass_material := StandardMaterial3D.new(); grass_material.albedo_color = Color("244f1e"); grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mesh.material = grass_material
	var grass_transforms: Array[Transform3D] = []
	for index in range(950 if detailed else 650):
		var p := Vector2(rng.randf_range(1.0,REGION_SIZE.x-1.0),rng.randf_range(1.0,REGION_SIZE.y-1.0))
		if _is_on_road(p): continue
		var scale := rng.randf_range(0.7,1.35); grass_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,height_at(p.x,p.y)+0.3*scale,p.y)))
	_add_mesh_multimesh("GrassCoverage", grass_mesh, grass_transforms, false)
	var bush_mesh := SphereMesh.new(); bush_mesh.radius = 0.55; bush_mesh.height = 0.8; bush_mesh.radial_segments = 8; bush_mesh.rings = 4
	var bush_material := StandardMaterial3D.new(); bush_material.albedo_color = Color("315e2d"); bush_mesh.material = bush_material
	var bushes: Array[Transform3D] = []
	for index in range(170 if detailed else 260):
		var p := Vector2(rng.randf_range(2.0,REGION_SIZE.x-2.0),rng.randf_range(2.0,REGION_SIZE.y-2.0))
		if _is_on_road(p,1.0): continue
		var scale := rng.randf_range(0.8,1.8); bushes.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,height_at(p.x,p.y)+0.35*scale,p.y)))
	_add_mesh_multimesh("Bushes", bush_mesh, bushes, false)

func _build_landmarks() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(descriptor.get("seed", 1)) + 991
	var transforms: Array[Transform3D] = []
	for index in range(3 if detailed else 1):
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
