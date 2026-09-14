class_name MapObjectMultiMeshRenderer
extends Node3D

const OBJECT_CHUNK_SIZE := 24.0
const PREMIUM_PBR: Dictionary[String, Dictionary] = {
	"moss_rock_08": {"albedo": "res://assets/environment/premium_imports/moss_rock_08/moss rock 08 sketchfab/moss rock 08 color (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_08/moss rock 08 sketchfab/moss rock 08 normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_08/moss rock 08 sketchfab/moss rock 08 roughness (4096).png"},
	"moss_rock_09": {"albedo": "res://assets/environment/premium_imports/moss_rock_09/moss rock 09 sketchfab/moss rock 09 Color (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_09/moss rock 09 sketchfab/moss rock 09_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_09/moss rock 09 sketchfab/moss rock 09_roughness (4096).jpg"},
	"moss_rock_10": {"albedo": "res://assets/environment/premium_imports/moss_rock_10/moss rock 10 sketchfab/moss rock 10 (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_10/moss rock 10 sketchfab/moss rock 10_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_10/moss rock 10 sketchfab/moss rock 10_roughness (4096).png"},
	"moss_rock_11": {"albedo": "res://assets/environment/premium_imports/moss_rock_11/moss rock 11 sketchfab/moss rock 11 (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_11/moss rock 11 sketchfab/moss rock 11_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_11/moss rock 11 sketchfab/moss rock 11_roughness (4096).png"},
	"moss_rock_12": {"albedo": "res://assets/environment/premium_imports/moss_rock_12/moss rock 12 sketchfab/moss rock 12 (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_12/moss rock 12 sketchfab/moss rock 12_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_12/moss rock 12 sketchfab/moss rock 12_roughness (4096).jpg"},
	"moss_rock_13": {"albedo": "res://assets/environment/premium_imports/moss_rock_13/moss rock 13 sketchfab/moss rock 13 (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_13/moss rock 13 sketchfab/moss rock 13_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_13/moss rock 13 sketchfab/moss rock 13_roughness (4096).png"},
	"moss_rock_14": {"albedo": "res://assets/environment/premium_imports/moss_rock_14/moss rock 14 sketchfab/moss rock 14 (4096).jpg", "normal": "res://assets/environment/premium_imports/moss_rock_14/moss rock 14 sketchfab/moss rock 14_normal (4096).png", "roughness": "res://assets/environment/premium_imports/moss_rock_14/moss rock 14 sketchfab/moss rock 14_roughness (4096).png"},
}
const DEFAULT_OBSTACLES: Array[String] = ["purple_tree_1", "purple_tree_2", "purple_tree_3", "large_tree", "tree_real_1", "tree_real_2"]
const TYPE_SCALE_MULTIPLIERS: Dictionary[String, float] = {
	"purple_tree_1": 5.5,
	"purple_tree_2": 5.5,
	"purple_tree_3": 5.5,
	"large_tree": 6.5,
	"bush": 1.3,
	"grass_1": 0.65,
	"grass_2": 0.65,
	"tree_real_1": 140.0,
	"tree_real_2": 140.0,
	"bush_real_1": 1.0,
	"bush_real_2": 1.0,
	"bush_real_3": 1.0,
	"bush_real_4": 1.0,
	"bush_real_5": 1.0,
	"bush_real_6": 1.0,
	"bush_real_7": 1.0,
	"bush_real_8": 1.0,
	"bush_real_9": 1.0,
	"bush_heather": 1.0,
	"bush_cliff": 1.0,
	"stylised_rocks": 1.0,
	"arena_bridge": 0.50,
	"arena_rock": 0.45,
	"arena_soil": 1.0,
}
const MESH_FILTERS: Dictionary[String, String] = {
	"bush_real_1": "Medium_bush_2", "bush_real_2": "Medium_bush_1",
	"bush_real_3": "Small_bush_1", "bush_real_4": "tall_bush_3",
	"bush_real_5": "tall_bush_1", "bush_real_6": "Medium_bush_3",
	"bush_real_7": "Small_bush_2", "bush_real_8": "tall_bush_2",
	"bush_real_9": "tall_bush_4",
	"premium_tree_1": "Forest_Tree_Bark_LOD0",
	"premium_tree_2": "Forest_Tree_Bark_LOD0",
	"premium_tree_3": "Forest_Tree_Bark_LOD0",
	"premium_tree_4": "Forest_Tree_Bark_LOD0",
	"premium_tree_5": "Forest_Tree_Bark_LOD0",
	"premium_tree_6": "Forest_Tree_Bark_LOD0",
	"premium_tree_7": "Forest_Tree_Bark_LOD0",
	"premium_tree_8": "Forest_Tree_Bark_LOD0",
	"premium_tree_9": "Forest_Tree_Bark_LOD0",
	"premium_tree_10": "Forest_Tree_Bark_LOD0",
	"premium_tree_11": "Forest_Tree_Bark_LOD0",
	"premium_tree_12": "Forest_Tree_Bark_LOD0",
	"premium_tree_13": "Forest_Tree_Bark_LOD0",
	"premium_tree_14": "Forest_Tree_Bark_LOD0",
	"premium_tree_15": "Forest_Tree_Bark_LOD0",
	"premium_tree_16": "Forest_Tree_Bark_LOD0",
	"premium_tree_17": "Forest_Tree_Bark_LOD0",
	"premium_tree_18": "Forest_Tree_Bark_LOD0",
	"premium_tree_19": "Forest_Tree_Bark_LOD0",
}

var _assets: Dictionary[String, String] = {}
var _obstacle_types: Array[String] = DEFAULT_OBSTACLES.duplicate()
var _position_resolver: Callable
var _create_collisions := false
var _instance_positions: Array[Vector3] = []
var _part_cache: Dictionary[String, Array] = {}
var _grass_proxy: ArrayMesh
var _bush_proxy: SphereMesh
var _soil_proxy: PlaneMesh

func configure(assets: Dictionary[String, String], position_resolver: Callable, create_collisions: bool = false, obstacle_types: Array[String] = DEFAULT_OBSTACLES) -> void:
	_assets = assets.duplicate()
	_position_resolver = position_resolver
	_create_collisions = create_collisions
	_obstacle_types = obstacle_types.duplicate()

func rebuild(objects: Array[Dictionary]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_instance_positions.clear()
	_instance_positions.resize(objects.size())
	var grouped: Dictionary[String, Array] = {}
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var kind := str(data.get("type", ""))
		# Soil is painted directly into Terrain3D. Legacy marker objects used to
		# create floating brown planes and must never enter the object renderer.
		if kind == "arena_soil" or not _assets.has(kind):
			continue
		var chunk := Vector2i(floori(float(data.get("x", 0.0)) / OBJECT_CHUNK_SIZE), floori(float(data.get("z", 0.0)) / OBJECT_CHUNK_SIZE))
		var key := "%s|%d|%d" % [kind, chunk.x, chunk.y]
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append({"index": index, "data": data, "kind": kind, "chunk": chunk})
	for key: String in grouped:
		_build_group(key, grouped[key])

func get_instance_position(index: int) -> Vector3:
	if index < 0 or index >= _instance_positions.size():
		return Vector3.ZERO
	return _instance_positions[index]

func _build_group(key: String, entries: Array) -> void:
	if entries.is_empty():
		return
	var kind := str((entries[0] as Dictionary)["kind"])
	var parts := _get_parts(kind)
	for part_index: int in range(parts.size()):
		var part: Dictionary = parts[part_index]
		var source_mesh := part["mesh"] as Mesh
		if source_mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = source_mesh
		multimesh.instance_count = entries.size()
		for entry_index: int in range(entries.size()):
			var entry: Dictionary = entries[entry_index]
			var object_index := int(entry["index"])
			var data: Dictionary = entry["data"]
			var object_transform := _object_transform(data)
			multimesh.set_instance_transform(entry_index, object_transform * (part["transform"] as Transform3D))
			var tint := Color.from_string(str(data.get("color", "ffffff")), Color.WHITE)
			multimesh.set_instance_color(entry_index, tint)
			_instance_positions[object_index] = object_transform.origin
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_Part%d" % [key.replace("|", "_"), part_index]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		# Trees must remain visible from the elevated isometric camera. A zero end
		# range disables distance culling while retaining regular frustum culling.
		instance.visibility_range_end = 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.ignore_occlusion_culling = true
		instance.extra_cull_margin = 8.0
		add_child(instance)
	if _create_collisions and _obstacle_types.has(kind):
		_build_collisions(key, entries)

func _get_parts(kind: String) -> Array:
	if _part_cache.has(kind):
		return _part_cache[kind]
	var parts: Array = []
	if kind == "arena_soil":
		if _soil_proxy == null:
			_soil_proxy = _create_soil_proxy()
		parts.append({"mesh": _soil_proxy, "transform": Transform3D.IDENTITY})
	else:
		var resource := load(_assets[kind])
		if resource is Mesh:
			var source_mesh := resource as Mesh
			parts.append({"mesh": _apply_premium_pbr(kind, source_mesh), "transform": Transform3D.IDENTITY})
		elif resource is PackedScene:
			var source := (resource as PackedScene).instantiate() as Node3D
			if source != null:
				_collect_parts(source, Transform3D.IDENTITY, parts, str(MESH_FILTERS.get(kind, "")))
				source.free()
	if kind.begins_with("premium_tree_"):
		for part: Dictionary in parts:
			part["mesh"] = _apply_premium_tree_materials(part["mesh"] as Mesh)
	_part_cache[kind] = parts
	return parts

func _apply_premium_tree_materials(source: Mesh) -> Mesh:
	var mesh := source.duplicate(true) as Mesh
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = load("res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Textures/Bark_GreenVariant.png") as Texture2D
	bark.normal_enabled = true
	bark.normal_texture = load("res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Textures/Bark_Normal.png") as Texture2D
	bark.roughness = 0.88
	bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var leaves := StandardMaterial3D.new()
	leaves.albedo_texture = load("res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Textures/Leave/Tree_Leaves_SummerVariant.png") as Texture2D
	leaves.normal_enabled = true
	leaves.normal_texture = load("res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Textures/Leave/Leave_Normal.png") as Texture2D
	leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaves.alpha_scissor_threshold = 0.42
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.roughness = 0.82
	leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	leaves.vertex_color_use_as_albedo = true
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, bark)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, leaves)
	return mesh


func _apply_premium_pbr(kind: String, source: Mesh) -> Mesh:
	if not PREMIUM_PBR.has(kind):
		return source
	var mesh := source.duplicate(true) as Mesh
	var maps: Dictionary = PREMIUM_PBR[kind]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(str(maps["albedo"])) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(str(maps["normal"])) as Texture2D
	material.roughness_texture = load(str(maps["roughness"])) as Texture2D
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for surface_index: int in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface_index, material)
	return mesh


func _collect_parts(node: Node, parent_transform: Transform3D, output: Array, mesh_filter: String = "") -> void:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (mesh_filter.is_empty() or node.name == mesh_filter):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			output.append({"mesh": _make_editor_safe_mesh(mesh_instance), "transform": local_transform})
	for child: Node in node.get_children():
		_collect_parts(child, local_transform, output, mesh_filter)

func _make_editor_safe_mesh(source: MeshInstance3D) -> Mesh:
	var mesh := source.mesh.duplicate(true) as Mesh
	for surface_index: int in range(mesh.get_surface_count()):
		var material := source.get_surface_override_material(surface_index)
		if material == null:
			material = mesh.surface_get_material(surface_index)
		if material is BaseMaterial3D:
			var safe_material := (material as BaseMaterial3D).duplicate(true) as BaseMaterial3D
			safe_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(surface_index, safe_material)
		elif material != null:
			mesh.surface_set_material(surface_index, material)
	return mesh

func _resolved_base_position(data: Dictionary) -> Vector3:
	var result := Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if _position_resolver.is_valid():
		result = _position_resolver.call(data) as Vector3
	result.y += float(data.get("height_offset", 0.0))
	return result

func _effective_scale(data: Dictionary) -> float:
	var kind := str(data.get("type", ""))
	return clampf(float(data.get("scale", 1.0)), 0.2, 8.0) * float(TYPE_SCALE_MULTIPLIERS.get(kind, 1.0))

func _object_transform(data: Dictionary) -> Transform3D:
	var kind := str(data.get("type", ""))
	var resolved_position := _resolved_base_position(data)
	var scale_value := _effective_scale(data)
	var height_scale := clampf(float(data.get("height_scale", 1.0)), 0.25, 3.0)
	var flip_sign := -1.0 if bool(data.get("flipped", false)) else 1.0
	var surface_normal := Vector3(float(data.get("normal_x", 0.0)), float(data.get("normal_y", 1.0)), float(data.get("normal_z", 0.0))).normalized()
	var object_basis := Basis(Quaternion(Vector3.UP, surface_normal))
	object_basis = object_basis.rotated(surface_normal, deg_to_rad(float(data.get("rotation", 0.0))))
	object_basis = object_basis.scaled(Vector3(scale_value * flip_sign, scale_value * height_scale, scale_value))
	return Transform3D(object_basis, resolved_position)

func _build_collisions(key: String, entries: Array) -> void:
	var body := StaticBody3D.new()
	body.name = key.replace("|", "_") + "_Obstacles"
	for entry: Dictionary in entries:
		var data: Dictionary = entry["data"]
		var scale_value := _effective_scale(data)
		var height_scale := clampf(float(data.get("height_scale", 1.0)), 0.25, 3.0)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = minf(0.19 * scale_value, 1.65)
		shape.height = 1.6 * scale_value * height_scale
		collision.shape = shape
		collision.position = _resolved_base_position(data) + Vector3.UP * shape.height * 0.5
		body.add_child(collision)
	add_child(body)

func _create_grass_proxy() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle: float in [0.0, PI * 0.5]:
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.34
		var a := -side
		var b := side
		var c := side + Vector3.UP * 0.72
		var d := -side + Vector3.UP * 0.72
		for point: Vector3 in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	var result := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.30, 0.055)
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.surface_set_material(0, material)
	return result

func _create_soil_proxy() -> PlaneMesh:
	var result := PlaneMesh.new()
	result.size = Vector2(2.0, 2.0)
	result.subdivide_width = 3
	result.subdivide_depth = 3
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/environment/terrain/glhf/forest_ground_06/forest_ground_06_diff_4k.jpg") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load("res://assets/environment/terrain/glhf/forest_ground_06/forest_ground_06_nor_gl_4k.jpg") as Texture2D
	material.albedo_color = Color(0.72, 0.62, 0.46)
	material.roughness = 0.96
	material.uv1_scale = Vector3(2.4, 2.4, 2.4)
	result.material = material
	return result


func _create_bush_proxy() -> SphereMesh:
	var result := SphereMesh.new()
	result.radius = 0.62
	result.height = 0.9
	result.radial_segments = 10
	result.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.31, 0.08)
	material.roughness = 0.92
	result.material = material
	return result
