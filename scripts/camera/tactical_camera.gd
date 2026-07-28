class_name TacticalCamera
extends Camera3D

signal exploration_mode_changed(enabled: bool, unit: TacticalUnit, world_position: Vector3)
signal tactical_grid_toggle_requested
signal torch_state_changed(enabled: bool)
signal mob_spotted(mob: WorldMob)

@export var board_center: Vector3 = Vector3(79.5, 0.0, 94.5)
@export var camera_offset: Vector3 = Vector3(145.0, 165.0, 145.0)
@export_range(0.001, 0.03, 0.001) var rotation_sensitivity: float = 0.008
@export_range(10.0, 80.0, 1.0) var minimum_elevation_degrees: float = 25.0
@export_range(10.0, 85.0, 1.0) var maximum_elevation_degrees: float = 70.0
@export_range(8.0, 30.0, 1.0) var minimum_zoom: float = 11.0
@export_range(200.0, 320.0, 1.0) var maximum_zoom: float = 245.0
@export_range(0.05, 0.3, 0.01) var zoom_step: float = 0.12
@export var turn_manager_path: NodePath = NodePath("../TurnManager")
@export_range(5.0, 40.0, 1.0) var keyboard_pan_speed: float = 18.0
@export_range(0.5, 3.0, 0.05) var first_person_height: float = 1.55
@export_range(0.001, 0.02, 0.001) var first_person_look_sensitivity: float = 0.004

@export_range(3.0, 40.0, 0.5) var vision_range: float = 15.0
@export_range(20.0, 120.0, 5.0) var vision_fov_degrees: float = 90.0

var _is_rotating: bool = false
var _is_panning: bool = false
var _first_person_mode: bool = false
var _active_unit: TacticalUnit
var _first_person_yaw: float = 0.0
var _first_person_pitch: float = 0.0
var _turn_manager: TurnManager
var _exploration_controller: FirstPersonExplorationController
var _torch_light: SpotLight3D
var _torch_fill_light: OmniLight3D
var _torch_enabled: bool = false
var _spotted_mobs: Dictionary[WorldMob, bool] = {}

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 220.0
	_apply_camera_transform()
	current = true
	_turn_manager = get_node_or_null(turn_manager_path) as TurnManager
	if _turn_manager != null:
		_turn_manager.active_unit_changed.connect(_on_active_unit_changed)
		_active_unit = _turn_manager.active_unit
	_create_torch_lights()
	set_process(true)

func _process(delta: float) -> void:
	if _first_person_mode:
		_apply_first_person_transform()
		_update_torch_flicker()
		_check_line_of_sight()
	else:
		_process_keyboard_pan(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_TAB and key_event.pressed and not key_event.echo:
			_toggle_camera_mode()
			get_viewport().set_input_as_handled()
		elif not _first_person_mode and key_event.keycode == KEY_T and key_event.pressed and not key_event.echo:
			tactical_grid_toggle_requested.emit()
			get_viewport().set_input_as_handled()
		elif _first_person_mode and key_event.keycode == KEY_F and key_event.pressed and not key_event.echo:
			_toggle_torch()
			get_viewport().set_input_as_handled()
		elif _first_person_mode and key_event.keycode == KEY_SPACE and key_event.pressed and not key_event.echo:
			if _exploration_controller != null:
				_exploration_controller.request_jump()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not _first_person_mode and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.0 - zoom_step)
			get_viewport().set_input_as_handled()
		elif not _first_person_mode and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.0 + zoom_step)
			get_viewport().set_input_as_handled()
		elif not _first_person_mode and mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_is_rotating = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if _first_person_mode:
				_is_rotating = mouse_button.pressed
			else:
				_is_panning = mouse_button.pressed and _is_ground_under_cursor(mouse_button.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (_is_rotating or _is_panning):
		var mouse_motion := event as InputEventMouseMotion
		if _first_person_mode:
			_look_around_first_person(mouse_motion.relative)
		elif _is_panning:
			_pan_camera(mouse_motion.relative)
		else:
			_rotate_camera(mouse_motion.relative)
		get_viewport().set_input_as_handled()

func _toggle_camera_mode() -> void:
	if _first_person_mode:
		_leave_first_person()
	elif _active_unit != null and is_instance_valid(_active_unit):
		_enter_first_person()

func _enter_first_person() -> void:
	_first_person_mode = true
	_is_panning = false
	_is_rotating = false
	var horizontal_forward := board_center - position
	horizontal_forward.y = 0.0
	if horizontal_forward.length_squared() > 0.001:
		horizontal_forward = horizontal_forward.normalized()
		_first_person_yaw = atan2(-horizontal_forward.x, -horizontal_forward.z)
	_first_person_pitch = deg_to_rad(-6.0)
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 72.0
	near = 0.05
	_exploration_controller = FirstPersonExplorationController.new()
	_exploration_controller.name = "FirstPersonExplorationController"
	get_tree().current_scene.add_child(_exploration_controller)
	_exploration_controller.configure(_active_unit, _first_person_yaw)
	exploration_mode_changed.emit(true, _active_unit, _active_unit.global_position)
	_apply_first_person_transform()
	_set_torch_visibility()

func _leave_first_person() -> void:
	var exploration_position := _active_unit.global_position if _active_unit != null and is_instance_valid(_active_unit) else Vector3.ZERO
	_first_person_mode = false
	_is_rotating = false
	_spotted_mobs.clear()
	_set_torch_visibility()
	if _exploration_controller != null:
		exploration_position = _exploration_controller.global_position
		_exploration_controller.queue_free()
		_exploration_controller = null
	exploration_mode_changed.emit(false, _active_unit, exploration_position)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 75.0
	var behind := Vector3(sin(_first_person_yaw), 0.0, cos(_first_person_yaw))
	camera_offset = behind * 205.0 + Vector3.UP * 165.0
	if _active_unit != null and is_instance_valid(_active_unit):
		var unit_pos := _active_unit.global_position
		board_center = Vector3(unit_pos.x, board_center.y, unit_pos.z)
		_clamp_board_center()
	_apply_camera_transform()

func _apply_first_person_transform() -> void:
	if _active_unit == null or not is_instance_valid(_active_unit):
		_leave_first_person()
		return
	if _exploration_controller == null:
		return
	global_position = _exploration_controller.global_position + Vector3.UP * _exploration_controller.current_camera_height
	global_rotation = Vector3(_first_person_pitch, _first_person_yaw, 0.0)

func _look_around_first_person(mouse_delta: Vector2) -> void:
	var sensitivity_multiplier: float = 1.0
	if _exploration_controller != null:
		sensitivity_multiplier = _exploration_controller.get_look_sensitivity_multiplier()
	var effective_sensitivity: float = first_person_look_sensitivity * sensitivity_multiplier
	_first_person_yaw -= mouse_delta.x * effective_sensitivity
	_first_person_pitch = clampf(
		_first_person_pitch - mouse_delta.y * effective_sensitivity,
		deg_to_rad(-80.0),
		deg_to_rad(80.0)
	)
	if _exploration_controller != null:
		_exploration_controller.view_yaw = _first_person_yaw
	_apply_first_person_transform()

func _create_torch_lights() -> void:
	_torch_light = SpotLight3D.new()
	_torch_light.name = "ExplorationTorch"
	_torch_light.position = Vector3(0.28, -0.22, -0.55)
	_torch_light.light_color = Color(1.0, 0.58, 0.24)
	_torch_light.light_energy = 7.4
	_torch_light.light_volumetric_fog_energy = 1.15
	_torch_light.spot_range = 19.0
	_torch_light.spot_angle = 52.0
	_torch_light.spot_attenuation = 1.15
	_torch_light.shadow_enabled = true
	_torch_light.shadow_bias = 0.06
	_torch_light.shadow_normal_bias = 1.0
	_torch_light.visible = false
	add_child(_torch_light)

	_torch_fill_light = OmniLight3D.new()
	_torch_fill_light.name = "ExplorationTorchFill"
	_torch_fill_light.position = Vector3(0.32, -0.30, -0.75)
	_torch_fill_light.light_color = Color(1.0, 0.40, 0.12)
	_torch_fill_light.light_energy = 1.7
	_torch_fill_light.omni_range = 4.2
	_torch_fill_light.omni_attenuation = 1.55
	_torch_fill_light.shadow_enabled = false
	_torch_fill_light.visible = false
	add_child(_torch_fill_light)

func _toggle_torch() -> void:
	_torch_enabled = not _torch_enabled
	_set_torch_visibility()
	torch_state_changed.emit(_torch_enabled)

func _set_torch_visibility() -> void:
	var should_show := _torch_enabled and _first_person_mode
	if _torch_light != null:
		_torch_light.visible = should_show
	if _torch_fill_light != null:
		_torch_fill_light.visible = should_show

func _update_torch_flicker() -> void:
	if not _torch_enabled or _torch_light == null:
		return
	var time_seconds := float(Time.get_ticks_msec()) * 0.001
	var flicker := sin(time_seconds * 8.7) * 0.24 + sin(time_seconds * 15.3 + 1.7) * 0.12
	_torch_light.light_energy = 7.4 + flicker
	if _torch_fill_light != null:
		_torch_fill_light.light_energy = 1.7 + flicker * 0.22

func is_torch_enabled() -> bool:
	return _torch_enabled

func exit_exploration_mode() -> void:
	if _first_person_mode:
		_leave_first_person()

func switch_focus_unit(unit: TacticalUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if _first_person_mode:
		_active_unit = unit
		if _exploration_controller != null:
			_exploration_controller.configure(unit, _first_person_yaw)
		_apply_first_person_transform()
	else:
		focus_on_unit(unit)

func focus_on_unit(unit: TacticalUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var target := Vector3(unit.global_position.x, board_center.y, unit.global_position.z)
	target.x = clampf(target.x, 0.0, float(GridManager.GRID_WIDTH - 1))
	target.z = clampf(target.z, 0.0, float(GridManager.GRID_HEIGHT - 1))
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_board_center, board_center, target, 0.35)

func _set_board_center(value: Vector3) -> void:
	board_center = value
	_apply_camera_transform()

func _on_active_unit_changed(unit: TacticalUnit) -> void:
	if unit != null and is_instance_valid(unit):
		_active_unit = unit
		if _first_person_mode:
			_apply_first_person_transform()

func _process_keyboard_pan(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0
	if input_vector.is_zero_approx():
		return
	var right := global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var zoom_speed_scale: float = clampf(size / 35.0, 0.45, 2.0)
	var movement := (right * input_vector.x + forward * input_vector.y).normalized()
	board_center += movement * keyboard_pan_speed * zoom_speed_scale * delta
	_clamp_board_center()
	_apply_camera_transform()

func _pan_camera(mouse_delta: Vector2) -> void:
	var right := global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var world_per_pixel: float = size / maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	board_center += (-right * mouse_delta.x + forward * mouse_delta.y) * world_per_pixel
	_clamp_board_center()
	_apply_camera_transform()

func _is_ground_under_cursor(screen_position: Vector2) -> bool:
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		project_ray_origin(screen_position), project_ray_normal(screen_position)
	)
	if not hit is Vector3:
		return false
	var ground_position: Vector3 = hit
	return ground_position.x >= -0.5 and ground_position.x <= float(GridManager.GRID_WIDTH) - 0.5 and ground_position.z >= -0.5 and ground_position.z <= float(GridManager.GRID_HEIGHT) - 0.5

func _clamp_board_center() -> void:
	board_center.x = clampf(board_center.x, 0.0, float(GridManager.GRID_WIDTH - 1))
	board_center.z = clampf(board_center.z, 0.0, float(GridManager.GRID_HEIGHT - 1))

func _rotate_camera(mouse_delta: Vector2) -> void:
	var offset := camera_offset
	offset = offset.rotated(Vector3.UP, -mouse_delta.x * rotation_sensitivity)

	var right_axis := offset.cross(Vector3.UP).normalized()
	var pitched_offset := offset.rotated(right_axis, mouse_delta.y * rotation_sensitivity)
	var elevation := rad_to_deg(asin(clampf(pitched_offset.y / pitched_offset.length(), -1.0, 1.0)))
	if elevation >= minimum_elevation_degrees and elevation <= maximum_elevation_degrees:
		offset = pitched_offset

	camera_offset = offset
	_apply_camera_transform()

func _check_line_of_sight() -> void:
	var mobs := get_tree().get_nodes_in_group("world_mobs")
	if mobs.is_empty():
		return
	var eye_pos: Vector3 = global_position
	var forward := Vector3(-sin(_first_person_yaw), 0.0, -cos(_first_person_yaw))
	var half_fov: float = deg_to_rad(vision_fov_degrees * 0.5)
	var space_state := get_world_3d().direct_space_state
	for node: Node in mobs:
		var mob := node as WorldMob
		if mob == null or not is_instance_valid(mob):
			continue
		if _spotted_mobs.has(mob):
			continue
		var to_mob: Vector3 = mob.global_position - eye_pos
		if to_mob.length() > vision_range:
			continue
		var to_mob_flat := Vector3(to_mob.x, 0.0, to_mob.z).normalized()
		var angle: float = forward.angle_to(to_mob_flat)
		if angle > half_fov:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye_pos, mob.global_position + Vector3.UP * 0.8)
		query.collision_mask = 1
		query.exclude = [self]
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			continue
		_spotted_mobs[mob] = true
		mob_spotted.emit(mob)

func _apply_camera_transform() -> void:
	position = board_center + camera_offset
	look_at(board_center, Vector3.UP)

func _zoom_at_screen_position(screen_position: Vector2, factor: float) -> void:
	var before: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		project_ray_origin(screen_position), project_ray_normal(screen_position)
	)
	size = clampf(size * factor, minimum_zoom, maximum_zoom)
	var after: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		project_ray_origin(screen_position), project_ray_normal(screen_position)
	)
	if before is Vector3 and after is Vector3:
		var before_position: Vector3 = before
		var after_position: Vector3 = after
		var shift: Vector3 = before_position - after_position
		board_center.x = clampf(board_center.x + shift.x, 0.0, float(GridManager.GRID_WIDTH - 1))
		board_center.z = clampf(board_center.z + shift.z, 0.0, float(GridManager.GRID_HEIGHT - 1))
	_apply_camera_transform()
