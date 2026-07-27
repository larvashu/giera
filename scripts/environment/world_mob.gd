class_name WorldMob
extends Node3D

@export var character_type: StringName = &"bandit"
@export var display_name: String = "Bandyta"
@export var model_scene: PackedScene
@export var model_offset: Vector3 = Vector3.ZERO

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	add_to_group("world_mobs")
	_build_visual()
	_build_overhead_ui()

func _build_overhead_ui() -> void:
	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.position = Vector3(0.0, 2.0, 0.0)
	name_label.font_size = 38
	name_label.outline_size = 8
	name_label.pixel_size = 0.006
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.modulate = Color(1.0, 0.38, 0.3, 1.0)
	add_child(name_label)

	var health_back := MeshInstance3D.new()
	health_back.name = "HealthBarBackground"
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(1.05, 0.12)
	health_back.mesh = back_quad
	health_back.position = Vector3(0.0, 1.78, 0.0)
	health_back.material_override = _create_billboard_material(Color(0.05, 0.05, 0.06, 0.95))
	add_child(health_back)

	var health_fill := MeshInstance3D.new()
	health_fill.name = "HealthBarFill"
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(1.0, 0.075)
	health_fill.mesh = fill_quad
	health_fill.position = Vector3(0.0, 1.78, 0.01)
	health_fill.material_override = _create_billboard_material(Color(0.85, 0.14, 0.1, 1.0))
	add_child(health_fill)

func _create_billboard_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	return material

func _build_visual() -> void:
	var visual: PackedScene = model_scene
	var def_color := Color.WHITE
	var def_scale := 1.0
	var def_offset := Vector3.ZERO
	var def_rotation := Vector3.ZERO

	if visual == null:
		var catalog := get_node_or_null("/root/TeamSaveManager") as TeamSaveService
		if catalog != null:
			var definition := catalog.get_character(character_type)
			if definition != null:
				visual = definition.visual_scene
				def_color = definition.visual_color
				def_scale = definition.visual_scale
				def_offset = definition.visual_offset
				def_rotation = definition.visual_rotation_degrees

	if visual != null:
		var model := visual.instantiate()
		model.name = "WorldMobModel"
		model.scale = Vector3.ONE * def_scale
		model.position = model_offset
		model.rotation_degrees = def_rotation
		_apply_color_to_model(model, def_color)
		add_child(model)
		_mesh_instance = _find_first_mesh(model)
		_try_play_animation(model)
		if not _has_skeletal_animation(model):
			_start_idle_bob(model, model_offset)
	else:
		_build_procedural_visual()

	var area := Area3D.new()
	area.name = "WorldMobArea"
	area.collision_layer = 2
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(shape)
	add_child(area)

func _apply_color_to_model(node: Node, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for i: int in range(mesh_node.get_surface_override_material_count()):
			var mat := mesh_node.get_active_material(i)
			if mat is BaseMaterial3D:
				var override_mat := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				override_mat.albedo_color = (mat as BaseMaterial3D).albedo_color * tint
				mesh_node.set_surface_override_material(i, override_mat)
	for child: Node in node.get_children():
		_apply_color_to_model(child, tint)

func _build_procedural_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.18, 0.12)

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.28
	body_mesh.bottom_radius = 0.32
	body_mesh.height = 1.2
	var body := MeshInstance3D.new()
	body.name = "WorldMobBody"
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.6, 0.0)
	body.material_override = mat
	add_child(body)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var head := MeshInstance3D.new()
	head.name = "WorldMobHead"
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.38, 0.0)
	head.material_override = mat
	add_child(head)

	_mesh_instance = body

func _try_play_animation(node: Node) -> void:
	var player := _find_animation_player(node)
	if player == null:
		return
	var idle_names := ["Idle", "idle", "IDLE", "Stand", "stand"]
	for anim_name: String in idle_names:
		if player.has_animation(anim_name):
			player.play(anim_name)
			return
	if player.get_animation_list().size() > 0:
		player.play(player.get_animation_list()[0])

func _has_skeletal_animation(node: Node) -> bool:
	return _find_animation_player(node) != null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null

func _start_idle_bob(model: Node3D, base_offset: Vector3) -> void:
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "position", base_offset + Vector3(0.0, 0.04, 0.0), 1.4)
	tween.tween_property(model, "position", base_offset - Vector3(0.0, 0.02, 0.0), 1.0)

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find_first_mesh(child)
		if result != null:
			return result
	return null
