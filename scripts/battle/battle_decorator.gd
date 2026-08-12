class_name BattleDecorator
extends Node3D

@export var grid_manager: GridManager

const PURPLE_TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/purple_tree_01.glb"),
	preload("res://assets/models/environment/purple_tree_02.glb"),
	preload("res://assets/models/environment/purple_tree_03.glb")
]
const GRASS_CLUMP_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/grass_clump_01.glb"),
	preload("res://assets/models/environment/grass_clump_02.glb")
]
const BUSH_GRASS_SCENE: PackedScene = preload("res://assets/models/environment/bush_grass_02.glb")
const LARGE_TREE_SCENE: PackedScene = preload("res://assets/models/environment/large_tree.glb")

const TREE_CELLS: Array[Vector2i] = [
	Vector2i(6, 10), Vector2i(15, 17), Vector2i(33, 13), Vector2i(43, 20),
	Vector2i(9, 34), Vector2i(19, 42), Vector2i(36, 39), Vector2i(45, 49),
	Vector2i(4, 51), Vector2i(29, 28), Vector2i(39, 7), Vector2i(12, 26)
]
const ROCK_CELLS: Array[Vector2i] = [
	Vector2i(8, 18), Vector2i(17, 9), Vector2i(31, 21), Vector2i(42, 31),
	Vector2i(11, 45), Vector2i(26, 49), Vector2i(38, 52), Vector2i(47, 12)
]

var _trunk_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _leaf_light_material: StandardMaterial3D
var _grass_material: StandardMaterial3D
var _grass_dark_material: StandardMaterial3D
var _rock_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	var session := get_node_or_null("/root/GameSession") as GameSessionState
	if session != null and session.selected_map_id == "builtin:arena":
		_create_arena_decoration()
		return
	_create_forest()
	_create_landmark_trees()
	_create_grass_scatter()
	_create_bush_scatter()

func _create_materials() -> void:
	_trunk_material = _material(Color(0.30, 0.16, 0.07, 1.0), 0.95)
	_leaf_material = _material(Color(0.08, 0.34, 0.12, 1.0), 0.9)
	_leaf_light_material = _material(Color(0.16, 0.48, 0.18, 1.0), 0.85)
	_grass_material = _material(Color(0.11, 0.30, 0.10, 1.0), 1.0)
	_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grass_dark_material = _material(Color(0.06, 0.22, 0.07, 1.0), 1.0)
	_rock_material = _material(Color(0.27, 0.29, 0.27, 1.0), 1.0)

func _create_arena_decoration() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44_772_019

	var _rect := grid_manager.get_arena_rect()
	var ax := float(_rect.position.x)
	var ay := float(_rect.position.y)
	var aw := float(_rect.size.x)
	var ah := float(_rect.size.y)

	# ── Materials ─────────────────────────────────────────────────────────
	var stone_mat  := _material(Color(0.40, 0.36, 0.30), 0.88)
	var stone_dark := _material(Color(0.26, 0.23, 0.19), 0.95)
	var torch_pole := _material(Color(0.22, 0.15, 0.08), 0.85)
	var flame_mat  := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.05)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.45, 0.0)
	flame_mat.emission_energy_multiplier = 3.0
	flame_mat.roughness = 0.2

	var arena_root := Node3D.new()
	arena_root.name = "ArenaDecoration"
	add_child(arena_root)

	var collision_body := StaticBody3D.new()
	collision_body.name = "ArenaCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	add_child(collision_body)

	# ── Block all border cells ────────────────────────────────────────────
	var _ix := int(ax); var _iy := int(ay); var _iw := int(aw); var _ih := int(ah)
	for x: int in range(_ix, _ix + _iw):
		grid_manager.block_cell(Vector2i(x, _iy))
		grid_manager.block_cell(Vector2i(x, _iy + _ih - 1))
	for y: int in range(_iy + 1, _iy + _ih - 1):
		grid_manager.block_cell(Vector2i(_ix, y))
		grid_manager.block_cell(Vector2i(_ix + _iw - 1, y))

	# ── Constants ─────────────────────────────────────────────────────────
	const WALL_H      := 3.0   # wall height
	const WALL_T      := 1.4   # wall thickness
	const SEG_LEN     := 4.0   # length of one wall segment
	const TOWER_SZ    := 2.2   # tower footprint (square)
	const TOWER_H     := 5.0   # tower height
	const MERLON_SZ   := 0.7   # battlement block size

	# ── Corner towers ─────────────────────────────────────────────────────
	var corners: Array[Vector2] = [
		Vector2(ax,        ay),
		Vector2(ax + aw,   ay),
		Vector2(ax,        ay + ah),
		Vector2(ax + aw,   ay + ah),
	]
	for corner: Vector2 in corners:
		var h := grid_manager.terrain_height(corner.x, corner.y)
		# Main tower shaft
		_add_wall_box(arena_root, collision_body, stone_dark,
			Vector3(corner.x, h + TOWER_H * 0.5, corner.y),
			Vector3(TOWER_SZ, TOWER_H, TOWER_SZ))
		# Battlements — alternating merlons on top
		for mi: int in range(3):
			var ox := (float(mi) - 1.0) * (TOWER_SZ / 2.2)
			_add_wall_box(arena_root, null, stone_mat,
				Vector3(corner.x + ox, h + TOWER_H + MERLON_SZ * 0.5, corner.y),
				Vector3(MERLON_SZ, MERLON_SZ, TOWER_SZ + 0.2))
			_add_wall_box(arena_root, null, stone_mat,
				Vector3(corner.x, h + TOWER_H + MERLON_SZ * 0.5, corner.y + ox),
				Vector3(TOWER_SZ + 0.2, MERLON_SZ, MERLON_SZ))

	# ── Wall segments (skip tower footprint at each end) ──────────────────
	var half_tower := TOWER_SZ * 0.5 + 0.1
	# North & South walls (along X)
	for sign_z: int in [0, 1]:
		var wz := ay if sign_z == 0 else ay + ah
		var wx_start := ax + half_tower
		var wx_end   := ax + aw - half_tower
		var span := wx_end - wx_start
		var segs := maxi(1, roundi(span / SEG_LEN))
		var seg_w := span / float(segs)
		for si: int in range(segs):
			var cx := wx_start + (float(si) + 0.5) * seg_w
			var h := grid_manager.terrain_height(cx, wz)
			_add_wall_box(arena_root, collision_body, stone_mat,
				Vector3(cx, h + WALL_H * 0.5 - 0.3, wz),
				Vector3(seg_w - 0.12, WALL_H, WALL_T))
			# Merlons on top
			for mi: int in range(roundi(seg_w / 1.4)):
				var mx := cx - seg_w * 0.5 + (float(mi) + 0.5) * (seg_w / roundi(seg_w / 1.4))
				if mi % 2 == 0:
					_add_wall_box(arena_root, null, stone_mat,
						Vector3(mx, h + WALL_H + MERLON_SZ * 0.5 - 0.3, wz),
						Vector3(0.55, MERLON_SZ, WALL_T + 0.1))

	# East & West walls (along Z)
	for sign_x: int in [0, 1]:
		var wx := ax if sign_x == 0 else ax + aw
		var wz_start := ay + half_tower
		var wz_end   := ay + ah - half_tower
		var span := wz_end - wz_start
		var segs := maxi(1, roundi(span / SEG_LEN))
		var seg_w := span / float(segs)
		for si: int in range(segs):
			var cz := wz_start + (float(si) + 0.5) * seg_w
			var h := grid_manager.terrain_height(wx, cz)
			_add_wall_box(arena_root, collision_body, stone_mat,
				Vector3(wx, h + WALL_H * 0.5 - 0.3, cz),
				Vector3(WALL_T, WALL_H, seg_w - 0.12))
			for mi: int in range(roundi(seg_w / 1.4)):
				var mz := cz - seg_w * 0.5 + (float(mi) + 0.5) * (seg_w / roundi(seg_w / 1.4))
				if mi % 2 == 0:
					_add_wall_box(arena_root, null, stone_mat,
						Vector3(wx, h + WALL_H + MERLON_SZ * 0.5 - 0.3, mz),
						Vector3(WALL_T + 0.1, MERLON_SZ, 0.55))

	# ── Torches: corners + wall midpoints ────────────────────────────────
	var torch_positions: Array[Vector2] = [
		Vector2(ax,              ay),
		Vector2(ax + aw,         ay),
		Vector2(ax,              ay + ah),
		Vector2(ax + aw,         ay + ah),
		Vector2(ax + aw * 0.5,  ay),
		Vector2(ax + aw * 0.5,  ay + ah),
		Vector2(ax,              ay + ah * 0.5),
		Vector2(ax + aw,         ay + ah * 0.5),
		Vector2(ax + aw * 0.25, ay),
		Vector2(ax + aw * 0.75, ay),
		Vector2(ax + aw * 0.25, ay + ah),
		Vector2(ax + aw * 0.75, ay + ah),
	]
	for tp: Vector2 in torch_positions:
		var h := grid_manager.terrain_height(tp.x, tp.y)
		_add_arena_torch(arena_root, torch_pole, flame_mat, Vector3(tp.x, h, tp.y))

	# ── Interior obstacle trees ───────────────────────────────────────────
	const OBSTACLE_TREE_RATIOS: Array[Vector2] = [
		Vector2(0.20, 0.32), Vector2(0.80, 0.28),
		Vector2(0.50, 0.22), Vector2(0.47, 0.68),
		Vector2(0.32, 0.50), Vector2(0.68, 0.55),
		Vector2(0.12, 0.60), Vector2(0.88, 0.45),
	]
	var tree_transforms: Array[Array] = [[], [], []]
	for ratio: Vector2 in OBSTACLE_TREE_RATIOS:
		var base_pos := Vector2(ax + ratio.x * aw, ay + ratio.y * ah)
		var jitter := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
		var p := base_pos + jitter
		var cell := Vector2i(roundi(p.x), roundi(p.y))
		grid_manager.block_cell(cell)
		var variant_index: int = rng.randi_range(0, PURPLE_TREE_SCENES.size() - 1)
		var scale_value: float = rng.randf_range(1.8, 2.5) * rng.randf_range(1.8, 2.4)
		var world_pos := Vector3(p.x, grid_manager.terrain_height(p.x, p.y), p.y)
		var tilt := Vector3(deg_to_rad(rng.randf_range(-3.0, 3.0)), rng.randf_range(0.0, TAU), deg_to_rad(rng.randf_range(-3.0, 3.0)))
		tree_transforms[variant_index].append(Transform3D(Basis.from_euler(tilt).scaled(Vector3.ONE * scale_value), world_pos + Vector3.UP * scale_value))
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = minf(0.16 * scale_value, 1.2)
		shape.height = 1.5 * scale_value
		col.shape = shape
		col.position = world_pos + Vector3.UP * (0.75 * scale_value)
		collision_body.add_child(col)
	for v: int in range(PURPLE_TREE_SCENES.size()):
		_create_tree_multimesh(v, tree_transforms[v])


func _add_wall_box(
	parent: Node3D,
	collision_parent: StaticBody3D,
	mat: StandardMaterial3D,
	position: Vector3,
	size: Vector3
) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = position
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	if collision_parent != null:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = position
		collision_parent.add_child(col)


func _add_arena_torch(
	parent: Node3D,
	pole_mat: StandardMaterial3D,
	flame_mat: StandardMaterial3D,
	base_pos: Vector3
) -> void:
	var root := Node3D.new()
	root.position = base_pos

	# Pole
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 2.4
	pole_mesh.radial_segments = 8
	pole.mesh = pole_mesh
	pole.material_override = pole_mat
	pole.position = Vector3.UP * 1.2 + Vector3(0.0, 0.0, 0.0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pole)

	# Flame bowl
	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.24
	bowl_mesh.bottom_radius = 0.13
	bowl_mesh.height = 0.30
	bowl_mesh.radial_segments = 10
	bowl.mesh = bowl_mesh
	bowl.material_override = flame_mat
	bowl.position = Vector3.UP * 2.55
	bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bowl)

	# Point light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.60, 0.18)
	light.light_energy = 2.8
	light.omni_range = 7.0
	light.omni_attenuation = 1.8
	light.position = Vector3.UP * 2.7
	root.add_child(light)

	parent.add_child(root)

func _create_tree(cell: Vector2i) -> void:
	var tree := StaticBody3D.new()
	tree.name = "Tree_%02d_%02d" % [cell.x, cell.y]
	tree.collision_layer = 1
	tree.collision_mask = 0
	tree.position = grid_manager.cell_to_world(cell)

	var variant_index: int = absi(cell.x * 31 + cell.y * 17) % PURPLE_TREE_SCENES.size()
	var model := PURPLE_TREE_SCENES[variant_index].instantiate() as Node3D
	if model != null:
		model.name = "PurpleTreeModel_%d" % (variant_index + 1)
		model.scale = Vector3.ONE * 1.55
		model.position.y = 1.55
		model.rotation.y = float(variant_index) * 0.73
		tree.add_child(model)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.29
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	tree.add_child(collision)

	add_child(tree)

func _create_rock_cluster(cell: Vector2i) -> void:
	var cluster := Node3D.new()
	cluster.name = "Rocks_%02d_%02d" % [cell.x, cell.y]
	cluster.position = grid_manager.cell_to_world(cell)
	for index: int in range(3):
		var rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16 + float(index) * 0.035
		sphere.height = 0.28 + float(index) * 0.05
		sphere.radial_segments = 8
		sphere.rings = 4
		rock.mesh = sphere
		rock.position = Vector3(-0.22 + index * 0.22, 0.12, 0.12 * sin(float(index) * 2.0))
		rock.scale = Vector3(1.25, 0.75, 0.95)
		rock.rotation.y = float(index) * 0.7
		rock.material_override = _rock_material
		cluster.add_child(rock)
	add_child(cluster)

func _create_grass_scatter() -> void:
	# Gestosc trawy jest teraz streamowana wokolo aktywnej kamery przez CameraGrassStreamer.
	var transforms_by_variant: Array[Array] = [[], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9_401_337
	var cluster_centers: Array[Vector2] = []
	for index: int in range(8):
		cluster_centers.append(Vector2(
			rng.randf_range(3.0, float(GridManager.GRID_WIDTH) - 4.0),
			rng.randf_range(5.0, float(GridManager.GRID_HEIGHT) - 6.0)
		))
	for center: Vector2 in cluster_centers:
		var clump_count: int = rng.randi_range(3, 5)
		for clump_index: int in range(clump_count):
			var angle: float = rng.randf_range(0.0, TAU)
			var radius: float = rng.randf_range(0.15, 5.5)
			var position_2d := center + Vector2(cos(angle), sin(angle)) * radius
			_add_grass_transform(transforms_by_variant, position_2d, rng)
	for sparse_index: int in range(12):
		_add_grass_transform(
			transforms_by_variant,
			Vector2(
				rng.randf_range(2.0, float(GridManager.GRID_WIDTH) - 3.0),
				rng.randf_range(3.0, float(GridManager.GRID_HEIGHT) - 4.0)
			),
			rng
		)
	# Importowane modele maja setki tysiecy trojkatow i przepalony material.
	# Zostawiamy ich dane gotowe do przyszlego LOD, lecz nie renderujemy ich w masowym scatterze.

func _create_dense_low_poly_grass() -> void:
	var grass_mesh := _create_crossed_grass_mesh()
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 27_418_903
	var total_cells: int = GridManager.GRID_WIDTH * GridManager.GRID_HEIGHT
	var target_count: int = floori(float(total_cells) / 2.0)
	var candidates: Array[Vector2i] = []
	for z: int in range(GridManager.GRID_HEIGHT):
		for x: int in range(GridManager.GRID_WIDTH):
			var cell := Vector2i(x, z)
			if not _is_in_spawn_clearing(Vector2(x, z), 10.0):
				candidates.append(cell)
	# Losowanie bez powtorzen daje rzeczywiste 50% powierzchni mapy.
	for index: int in range(mini(target_count, candidates.size())):
		var swap_index: int = rng.randi_range(index, candidates.size() - 1)
		var chosen: Vector2i = candidates[swap_index]
		candidates[swap_index] = candidates[index]
		candidates[index] = chosen
		var offset := Vector2(rng.randf_range(-0.36, 0.36), rng.randf_range(-0.36, 0.36))
		var position_2d := Vector2(chosen) + offset
		var world_position := Vector3(
			position_2d.x,
			grid_manager.terrain_height(position_2d.x, position_2d.y) + 0.015,
			position_2d.y
		)
		var grass_scale := Vector3(
			rng.randf_range(0.70, 1.10),
			rng.randf_range(0.70, 1.10),
			rng.randf_range(0.70, 1.10)
		)
		var grass_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(grass_scale)
		transforms.append(Transform3D(grass_basis, world_position))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = grass_mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instances := MultiMeshInstance3D.new()
	instances.name = "DenseGrassCoverage50Percent"
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)

func _create_crossed_grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_rng := RandomNumberGenerator.new()
	blade_rng.seed = 8_813
	# Kilka osobnych, zwezajacych sie zdzbel tworzy przestrzenna kepke bez alfa-overdraw.
	for blade_index: int in range(18):
		var angle: float = (TAU * float(blade_index) / 18.0) + blade_rng.randf_range(-0.3, 0.3)
		var radial_offset := Vector3(cos(angle), 0.0, sin(angle)) * blade_rng.randf_range(0.02, 0.32)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var height: float = blade_rng.randf_range(0.22, 0.48)
		var width: float = blade_rng.randf_range(0.018, 0.035)
		var bend := direction * blade_rng.randf_range(0.06, 0.16)
		var bottom_left := radial_offset - side * width
		var bottom_right := radial_offset + side * width
		var middle_center := radial_offset + Vector3.UP * (height * 0.58) + bend * 0.28
		var middle_left := middle_center - side * width * 0.62
		var middle_right := middle_center + side * width * 0.62
		var tip := radial_offset + Vector3.UP * height + bend
		var tint: float = blade_rng.randf_range(0.0, 1.0)
		_add_grass_triangle(surface, bottom_left, bottom_right, middle_right, 0.0, 0.0, 0.58, tint)
		_add_grass_triangle(surface, bottom_left, middle_right, middle_left, 0.0, 0.58, 0.58, tint)
		_add_grass_triangle(surface, middle_left, middle_right, tip, 0.58, 0.58, 1.0, tint)
	var mesh := surface.commit()
	mesh.surface_set_material(0, _create_grass_shader_material())
	return mesh

func _add_grass_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	wind_a: float,
	wind_b: float,
	wind_c: float,
	tint: float
) -> void:
	var face_normal := Plane(a, b, c).normal
	for vertex_data: Array in [[a, wind_a], [b, wind_b], [c, wind_c]]:
		surface.set_normal(face_normal)
		surface.set_uv(Vector2(tint, vertex_data[1] as float))
		surface.add_vertex(vertex_data[0] as Vector3)

func _create_grass_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;

uniform vec3 grass_dark : source_color = vec3(0.018, 0.075, 0.008);
uniform vec3 grass_light : source_color = vec3(0.085, 0.25, 0.025);
uniform vec3 violet_dark : source_color = vec3(0.09, 0.03, 0.13);
uniform vec3 violet_light : source_color = vec3(0.29, 0.11, 0.36);
uniform float wind_strength = 0.055;
uniform float wind_speed = 1.35;

void vertex() {
	float height_mask = UV.y * UV.y;
	float phase = TIME * wind_speed + VERTEX.x * 3.7 + VERTEX.z * 4.9
		+ MODEL_MATRIX[3].x * 0.17 + MODEL_MATRIX[3].z * 0.23;
	VERTEX.x += sin(phase) * wind_strength * height_mask;
	VERTEX.z += cos(phase * 0.73) * wind_strength * 0.55 * height_mask;
}

void fragment() {
	float vertical_light = smoothstep(0.0, 1.0, UV.y);
	float variation = fract(UV.x * 7.13 + MODEL_MATRIX[3].x * 0.071 + MODEL_MATRIX[3].z * 0.053);
	float spatial_tint = fract(sin(MODEL_MATRIX[3].x * 12.9898 + MODEL_MATRIX[3].z * 78.233) * 43758.5453);
	vec3 green = mix(grass_dark, grass_light, 0.28 + vertical_light * 0.48 + variation * 0.16);
	vec3 violet = mix(violet_dark, violet_light, 0.20 + vertical_light * 0.58);
	float violet_amount = 0.26 + smoothstep(0.30, 0.88, spatial_tint) * 0.46;
	ALBEDO = mix(green, violet, violet_amount);
	ROUGHNESS = 0.92;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _add_grass_transform(transforms_by_variant: Array[Array], position_2d: Vector2, rng: RandomNumberGenerator) -> void:
	position_2d.x = clampf(position_2d.x, 1.0, float(GridManager.GRID_WIDTH) - 2.0)
	position_2d.y = clampf(position_2d.y, 1.0, float(GridManager.GRID_HEIGHT) - 2.0)
	if _is_in_spawn_clearing(position_2d, 12.0):
		return
	var variant_index: int = 0 if rng.randf() < 0.72 else 1
	var scale_value: float = rng.randf_range(0.34, 0.52) if variant_index == 0 else rng.randf_range(0.28, 0.42)
	var world_position := Vector3(
		position_2d.x,
		grid_manager.terrain_height(position_2d.x, position_2d.y),
		position_2d.y
	)
	var vertical_offset: float = 0.403 * scale_value if variant_index == 0 else 0.683 * scale_value
	world_position.y += vertical_offset
	var instance_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
	transforms_by_variant[variant_index].append(Transform3D(instance_basis, world_position))

func _create_grass_multimesh(variant_index: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var source_root := GRASS_CLUMP_SCENES[variant_index].instantiate() as Node3D
	if source_root == null:
		return
	var mesh_nodes: Array[Node] = source_root.find_children("*", "MeshInstance3D", true, false)
	var source_mesh_instance: MeshInstance3D = null
	if not mesh_nodes.is_empty():
		source_mesh_instance = mesh_nodes[0] as MeshInstance3D
	if source_mesh_instance == null or source_mesh_instance.mesh == null:
		source_root.free()
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source_mesh_instance.mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var instances := MultiMeshInstance3D.new()
	instances.name = "GrassClumps_%02d" % (variant_index + 1)
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)
	source_root.free()

func _create_bush_scatter() -> void:
	var source_root := BUSH_GRASS_SCENE.instantiate() as Node3D
	if source_root == null:
		return
	var mesh_nodes: Array[Node] = source_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		source_root.free()
		return
	var source_mesh_instance := mesh_nodes[0] as MeshInstance3D
	var source_material: Material = source_mesh_instance.mesh.surface_get_material(0)
	var proxy_mesh := SphereMesh.new()
	proxy_mesh.radius = 0.62
	proxy_mesh.height = 0.82
	proxy_mesh.radial_segments = 10
	proxy_mesh.rings = 5
	proxy_mesh.material = _create_bush_shader_material(source_material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71_306_419
	var transforms: Array[Transform3D] = []
	for index: int in range(760):
		var position_2d := Vector2(
			rng.randf_range(2.0, float(GridManager.GRID_WIDTH) - 3.0),
			rng.randf_range(3.0, float(GridManager.GRID_HEIGHT) - 4.0)
		)
		if _is_in_spawn_clearing(position_2d, 11.0) or _is_on_trail_surface(position_2d):
			continue
		var scale_value: float = rng.randf_range(1.05, 1.85)
		var scale_vector := Vector3(
			scale_value * rng.randf_range(0.85, 1.25),
			scale_value * rng.randf_range(0.62, 1.05),
			scale_value * rng.randf_range(0.85, 1.25)
		)
		var world_position := Vector3(
			position_2d.x,
			grid_manager.terrain_height(position_2d.x, position_2d.y) + 0.34 * scale_vector.y,
			position_2d.y
		)
		var bush_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale_vector)
		transforms.append(Transform3D(bush_basis, world_position))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = proxy_mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instances := MultiMeshInstance3D.new()
	instances.name = "BushesFromTrawa2"
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)
	# Kilka pelnych modeli zachowuje charakter oryginalnego zasobu z Meshy.
	var hero_transforms: Array[Transform3D] = []
	for index: int in range(4):
		var position_2d := Vector2(
			rng.randf_range(8.0, float(GridManager.GRID_WIDTH) - 9.0),
			rng.randf_range(12.0, float(GridManager.GRID_HEIGHT) - 13.0)
		)
		if _is_on_trail_surface(position_2d):
			continue
		var scale_value: float = rng.randf_range(0.62, 0.92)
		var world_position := Vector3(
			position_2d.x,
			grid_manager.terrain_height(position_2d.x, position_2d.y) + 0.68 * scale_value,
			position_2d.y
		)
		var hero_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
		hero_transforms.append(Transform3D(hero_basis, world_position))
	_create_source_mesh_multimesh("DetailedTrawa2Bushes", source_mesh_instance.mesh, hero_transforms, false)
	source_root.free()

func _create_bush_shader_material(source_material: Material) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;

uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_source_texture = false;
uniform vec3 green_tint : source_color = vec3(0.10, 0.28, 0.075);
uniform vec3 violet_tint : source_color = vec3(0.34, 0.12, 0.40);

void fragment() {
	vec3 source = has_source_texture ? texture(source_texture, UV).rgb : vec3(0.72);
	float detail = dot(source, vec3(0.299, 0.587, 0.114));
	float random_tint = fract(sin(MODEL_MATRIX[3].x * 19.19 + MODEL_MATRIX[3].z * 47.77) * 43758.5453);
	float violet_amount = smoothstep(0.08, 0.94, random_tint);
	vec3 tint = mix(green_tint, violet_tint, violet_amount);
	ALBEDO = tint * mix(0.65, 1.32, detail);
	ROUGHNESS = 0.94;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	if source_material is StandardMaterial3D:
		var standard := source_material as StandardMaterial3D
		if standard.albedo_texture != null:
			result.set_shader_parameter("source_texture", standard.albedo_texture)
			result.set_shader_parameter("has_source_texture", true)
	return result

func _create_landmark_trees() -> void:
	var source_root := LARGE_TREE_SCENE.instantiate() as Node3D
	if source_root == null:
		return
	var mesh_nodes: Array[Node] = source_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		source_root.free()
		return
	var source_mesh_instance := mesh_nodes[0] as MeshInstance3D
	var transforms: Array[Transform3D] = []
	var collision_body := StaticBody3D.new()
	collision_body.name = "LandmarkTreeCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	add_child(collision_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92_144_703
	for index: int in range(7):
		var position_2d := Vector2(
			rng.randf_range(12.0, float(GridManager.GRID_WIDTH) - 13.0),
			rng.randf_range(18.0, float(GridManager.GRID_HEIGHT) - 19.0)
		)
		if _is_in_spawn_clearing(position_2d, 20.0):
			continue
		var scale_roll: float = rng.randf()
		var base_scale: float = 3.85 if index == 0 else 2.3 + pow(scale_roll, 3.2) * 1.7
		var scale_value: float = base_scale * rng.randf_range(2.0, 3.0) * rng.randf_range(1.1, 2.5)
		var world_position := Vector3(
			position_2d.x,
			grid_manager.terrain_height(position_2d.x, position_2d.y),
			position_2d.y
		)
		var tilt := Vector3(deg_to_rad(rng.randf_range(-2.0, 2.0)), rng.randf_range(0.0, TAU), deg_to_rad(rng.randf_range(-2.0, 2.0)))
		var tree_basis := Basis.from_euler(tilt).scaled(Vector3.ONE * scale_value)
		transforms.append(Transform3D(tree_basis, world_position + Vector3.UP * scale_value))
		var cell := Vector2i(roundi(position_2d.x), roundi(position_2d.y))
		grid_manager.block_cell(cell)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.34 * scale_value
		shape.height = 1.75 * scale_value
		collision.shape = shape
		collision.position = world_position + Vector3.UP * (0.88 * scale_value)
		collision_body.add_child(collision)
	_create_source_mesh_multimesh("LandmarkLargeTrees", source_mesh_instance.mesh, transforms, true)
	source_root.free()

func _create_source_mesh_multimesh(
	instance_name: String,
	source_mesh: Mesh,
	transforms: Array[Transform3D],
	cast_shadows: bool
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source_mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instances := MultiMeshInstance3D.new()
	instances.name = instance_name
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)

func _create_forest() -> void:
	var transforms_by_variant: Array[Array] = [[], [], []]
	var occupied_cells: Dictionary[Vector2i, bool] = {}
	var collision_body := StaticBody3D.new()
	collision_body.name = "ForestCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	add_child(collision_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61_720_241
	const FOREST_SPACING: int = 9
	var forest_row: int = 0
	for z: int in range(2, GridManager.GRID_HEIGHT - 2, FOREST_SPACING):
		var row_offset: float = 4.5 if forest_row % 2 == 1 else 0.0
		for x: int in range(2, GridManager.GRID_WIDTH - 2, FOREST_SPACING):
			var position_2d := Vector2(
				float(x) + row_offset + rng.randf_range(-2.2, 2.2),
				float(z) + rng.randf_range(-2.2, 2.2)
			)
			position_2d.x = wrapf(position_2d.x, 1.5, float(GridManager.GRID_WIDTH) - 1.5)
			if _is_on_forest_trail(position_2d):
				continue
			_add_forest_tree(transforms_by_variant, occupied_cells, collision_body, position_2d, rng)
		forest_row += 1
	for variant_index: int in range(PURPLE_TREE_SCENES.size()):
		_create_tree_multimesh(variant_index, transforms_by_variant[variant_index])

func _is_on_forest_trail(position_2d: Vector2) -> bool:
	var north_south_x: float = float(GridManager.GRID_WIDTH) * 0.5 + sin(position_2d.y * 0.055) * 12.0
	var diagonal_z: float = 30.0 + position_2d.x * 0.72 + sin(position_2d.x * 0.09) * 6.0
	var east_west_z: float = 132.0 + sin(position_2d.x * 0.07) * 10.0
	return (
		absf(position_2d.x - north_south_x) < 4.8
		or absf(position_2d.y - diagonal_z) < 4.4
		or absf(position_2d.y - east_west_z) < 4.4
	)

func _is_on_trail_surface(position_2d: Vector2) -> bool:
	var north_south_x: float = float(GridManager.GRID_WIDTH) * 0.5 + sin(position_2d.y * 0.055) * 12.0
	var diagonal_z: float = 30.0 + position_2d.x * 0.72 + sin(position_2d.x * 0.09) * 6.0
	var east_west_z: float = 132.0 + sin(position_2d.x * 0.07) * 10.0
	return (
		absf(position_2d.x - north_south_x) < 2.8
		or absf(position_2d.y - diagonal_z) < 2.6
		or absf(position_2d.y - east_west_z) < 2.6
	)

func _add_forest_tree(
	transforms_by_variant: Array[Array],
	occupied_cells: Dictionary[Vector2i, bool],
	collision_body: StaticBody3D,
	position_2d: Vector2,
	rng: RandomNumberGenerator
) -> void:
	position_2d.x = clampf(position_2d.x, 1.0, float(GridManager.GRID_WIDTH) - 2.0)
	position_2d.y = clampf(position_2d.y, 1.0, float(GridManager.GRID_HEIGHT) - 2.0)
	if _is_in_spawn_clearing(position_2d, 5.5):
		return
	var cell := Vector2i(roundi(position_2d.x), roundi(position_2d.y))
	if occupied_cells.has(cell):
		return
	occupied_cells[cell] = true
	grid_manager.block_cell(cell)
	var variant_index: int = rng.randi_range(0, PURPLE_TREE_SCENES.size() - 1)
	var base_scale: float = rng.randf_range(1.5, 2.4)
	var size_multiplier: float = rng.randf_range(2.5, 4.0)
	var scale_value: float = base_scale * size_multiplier
	var world_position := Vector3(
		position_2d.x,
		grid_manager.terrain_height(position_2d.x, position_2d.y),
		position_2d.y
	)
	var tilt_x: float = deg_to_rad(rng.randf_range(-3.5, 3.5))
	var tilt_z: float = deg_to_rad(rng.randf_range(-3.5, 3.5))
	var instance_basis := Basis.from_euler(Vector3(tilt_x, rng.randf_range(0.0, TAU), tilt_z)).scaled(Vector3.ONE * scale_value)
	transforms_by_variant[variant_index].append(Transform3D(instance_basis, world_position + Vector3.UP * scale_value))
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = minf(0.19 * scale_value, 1.65)
	shape.height = 1.6 * scale_value
	collision.shape = shape
	collision.position = world_position + Vector3.UP * (0.8 * scale_value)
	collision_body.add_child(collision)

func _create_tree_multimesh(variant_index: int, transforms: Array) -> void:
	if transforms.is_empty(): return
	var source_root := PURPLE_TREE_SCENES[variant_index].instantiate() as Node3D
	if source_root == null: return
	var mesh_nodes: Array[Node] = source_root.find_children("*","MeshInstance3D",true,false)
	if mesh_nodes.is_empty(): source_root.free(); return
	var source_mesh := (mesh_nodes[0] as MeshInstance3D).mesh
	const CHUNK_SIZE := 48.0
	var chunks: Dictionary = {}
	for value: Variant in transforms:
		var transform := value as Transform3D
		var key := Vector2i(floori(transform.origin.x/CHUNK_SIZE),floori(transform.origin.z/CHUNK_SIZE))
		if not chunks.has(key): chunks[key]=[]
		(chunks[key] as Array).append(transform)
	for key: Vector2i in chunks:
		var center := Vector3((key.x+0.5)*CHUNK_SIZE,0.0,(key.y+0.5)*CHUNK_SIZE)
		var values := chunks[key] as Array
		var multimesh := MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_3D; multimesh.mesh=source_mesh; multimesh.instance_count=values.size()
		for index in range(values.size()):
			var transform := values[index] as Transform3D; transform.origin-=center; multimesh.set_instance_transform(index,transform)
		var instances := MultiMeshInstance3D.new(); instances.name="ForestTrees_%02d_%d_%d"%[variant_index+1,key.x,key.y]; instances.position=center; instances.multimesh=multimesh
		instances.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# Tactical camera is high above the board; distance culling from the camera
		# hid most chunks even while they were inside the orthographic viewport.
		instances.visibility_range_end = 0.0
		add_child(instances)
	source_root.free()

func _is_in_spawn_clearing(position_2d: Vector2, radius: float) -> bool:
	var player_spawn := Vector2((float(GridManager.GRID_WIDTH) - 1.0) * 0.5, 9.0)
	var enemy_spawn := Vector2((float(GridManager.GRID_WIDTH) - 1.0) * 0.5, float(GridManager.GRID_HEIGHT) - 10.0)
	return position_2d.distance_to(player_spawn) < radius or position_2d.distance_to(enemy_spawn) < radius

func _create_border_vegetation() -> void:
	for index: int in range(72):
		var tuft := MeshInstance3D.new()
		tuft.name = "GrassTuft_%02d" % index
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.13
		cone.height = 0.38 + 0.08 * sin(float(index))
		cone.radial_segments = 5
		tuft.mesh = cone
		var side: int = index % 4
		var progress: float = (float(index) / 4.0) / 17.0
		var cell_x: float = lerpf(0.0, 49.0, progress) if side < 2 else (0.0 if side == 2 else 49.0)
		var cell_z: float = (0.0 if side == 0 else 59.0) if side < 2 else lerpf(0.0, 59.0, progress)
		tuft.position = Vector3(cell_x, grid_manager.terrain_height(cell_x, cell_z) + 0.17, cell_z)
		tuft.rotation.y = float(index) * 0.73
		tuft.material_override = _grass_dark_material if index % 2 == 0 else _leaf_light_material
		add_child(tuft)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result
