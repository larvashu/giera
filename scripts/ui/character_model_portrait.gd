class_name CharacterModelPortrait
extends SubViewportContainer


func setup(definition: CharacterDefinition, portrait_size: Vector2 = Vector2(64.0, 64.0)) -> void:
	custom_minimum_size = portrait_size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.name = "PortraitViewport"
	viewport.size = Vector2i(maxi(64, roundi(portrait_size.x * 2.0)), maxi(64, roundi(portrait_size.y * 2.0)))
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.022, 0.018, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.72)
	environment.ambient_light_energy = 1.15
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var camera := Camera3D.new()
	camera.fov = 31.0
	var camera_position := Vector3(0.0, 1.15, 4.7)
	camera.look_at_from_position(camera_position, Vector3(0.0, 0.9, 0.0), Vector3.UP)
	viewport.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
	key_light.light_color = Color(1.0, 0.78, 0.58)
	key_light.light_energy = 2.0
	viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
	fill_light.light_color = Color(0.35, 0.55, 1.0)
	fill_light.light_energy = 0.8
	viewport.add_child(fill_light)

	var scene := definition.idle_animation_scene if definition.idle_animation_scene != null else definition.visual_scene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.scale = Vector3.ONE * definition.visual_scale
	model.position = definition.visual_offset
	model.rotation_degrees = definition.visual_rotation_degrees
	viewport.add_child(model)
	var player := _find_animation_player(model)
	if player != null and not player.get_animation_list().is_empty():
		var animation_name := player.get_animation_list()[0]
		var animation := player.get_animation(animation_name)
		animation.loop_mode = Animation.LOOP_LINEAR
		player.play(animation_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
