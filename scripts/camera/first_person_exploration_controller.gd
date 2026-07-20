class_name FirstPersonExplorationController
extends CharacterBody3D

@export_range(0.5, 12.0, 0.1) var walk_speed: float = 2.25
@export_range(0.5, 12.0, 0.1) var fast_walk_speed: float = 4.5
@export_range(0.5, 16.0, 0.1) var sprint_speed: float = 8.1
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.45
@export_range(0.5, 3.0, 0.1) var jump_height: float = 1.25
@export_range(0.5, 2.5, 0.05) var standing_height: float = 1.7
@export_range(0.5, 2.0, 0.05) var crouching_height: float = 1.0
@export_range(1.0, 30.0, 0.5) var sprint_acceleration: float = 9.0
@export_range(0.5, 20.0, 0.5) var sprint_coast_deceleration: float = 3.0
@export_range(1.0, 30.0, 0.5) var sprint_brake_deceleration: float = 12.0
@export_range(20.0, 180.0, 5.0) var sprint_turn_speed_degrees: float = 72.0
@export_range(0.0, 45.0, 1.0) var sprint_keyboard_steer_degrees: float = 24.0

var controlled_unit: TacticalUnit
var view_yaw: float = 0.0
var current_camera_height: float = 1.55
var _jump_requested: bool = false
var _gravity: float = 9.8
var _collider: CollisionShape3D
var _capsule: CapsuleShape3D
var _sector_streamer: WorldSectorStreamer
var _sprint_heading: float = 0.0
var _sprint_momentum_active: bool = false

func _ready() -> void:
	add_to_group("exploration_player")
	_sector_streamer = get_tree().get_first_node_in_group("world_sector_streamer") as WorldSectorStreamer
	collision_layer = 4
	collision_mask = 1
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.32
	_capsule.height = standing_height
	_collider = CollisionShape3D.new()
	_collider.name = "ExplorationCollider"
	_collider.shape = _capsule
	add_child(_collider)
	_update_collider(standing_height)

func configure(unit: TacticalUnit, yaw: float) -> void:
	controlled_unit = unit
	view_yaw = yaw
	_sprint_heading = yaw
	global_position = unit.global_position
	current_camera_height = standing_height - 0.15

func request_jump() -> void:
	_jump_requested = true

func _physics_process(delta: float) -> void:
	if controlled_unit == null or not is_instance_valid(controlled_unit):
		velocity = Vector3.ZERO
		return
	var crouching := Input.is_key_pressed(KEY_CTRL)
	var target_height: float = crouching_height if crouching else standing_height
	_update_collider(target_height)
	current_camera_height = move_toward(current_camera_height, target_height - 0.15, delta * 5.5)

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0
	var vehicle_sprinting := _is_vehicle_sprinting(crouching, input_vector)
	if vehicle_sprinting:
		_process_vehicle_sprint(input_vector, delta)
	elif _sprint_momentum_active:
		_process_sprint_coasting(input_vector, crouching, delta)
	else:
		_process_regular_movement(input_vector, crouching)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _jump_requested and not crouching:
		velocity.y = sqrt(2.0 * _gravity * jump_height)
	_jump_requested = false
	move_and_slide()
	if _sector_streamer != null:
		global_position = _sector_streamer.clamp_world_position(global_position)
	else:
		global_position.x = clampf(global_position.x, 0.0, float(GridManager.GRID_WIDTH - 1))
		global_position.z = clampf(global_position.z, 0.0, float(GridManager.GRID_HEIGHT - 1))
	controlled_unit.global_position = global_position
	controlled_unit.rotation.y = _sprint_heading if _sprint_momentum_active else view_yaw

func _is_vehicle_sprinting(crouching: bool, input_vector: Vector2) -> bool:
	return (
		not crouching
		and input_vector.y > 0.0
		and Input.is_key_pressed(KEY_SHIFT)
		and Input.is_key_pressed(KEY_R)
	)


func _process_vehicle_sprint(input_vector: Vector2, delta: float) -> void:
	if not _sprint_momentum_active:
		_sprint_heading = view_yaw
	_sprint_momentum_active = true
	var steer_offset: float = deg_to_rad(sprint_keyboard_steer_degrees) * -input_vector.x
	var target_heading: float = view_yaw + steer_offset
	var current_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(current_speed / maxf(sprint_speed, 0.01), 0.0, 1.0)
	var turn_rate: float = deg_to_rad(sprint_turn_speed_degrees) * lerpf(1.0, 0.58, speed_ratio)
	_sprint_heading = rotate_toward(_sprint_heading, target_heading, turn_rate * delta)
	var sprint_forward := Vector3(-sin(_sprint_heading), 0.0, -cos(_sprint_heading))
	var target_velocity := sprint_forward * sprint_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, sprint_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, sprint_acceleration * delta)


func _process_sprint_coasting(input_vector: Vector2, crouching: bool, delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var has_movement_input: bool = not input_vector.is_zero_approx()
	var deceleration: float = sprint_brake_deceleration if has_movement_input or crouching else sprint_coast_deceleration
	var target_velocity := Vector3.ZERO
	if has_movement_input:
		var forward := Vector3(-sin(view_yaw), 0.0, -cos(view_yaw))
		var right := Vector3(cos(view_yaw), 0.0, -sin(view_yaw))
		target_velocity = (right * input_vector.x + forward * input_vector.y).normalized() * _get_target_move_speed(crouching)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, deceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if horizontal_velocity.distance_to(target_velocity) <= 0.15 or horizontal_velocity.length() <= 0.25:
		_sprint_momentum_active = false


func _process_regular_movement(input_vector: Vector2, crouching: bool) -> void:
	var forward := Vector3(-sin(view_yaw), 0.0, -cos(view_yaw))
	var right := Vector3(cos(view_yaw), 0.0, -sin(view_yaw))
	var move_direction := (right * input_vector.x + forward * input_vector.y).normalized()
	var speed: float = _get_target_move_speed(crouching)
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed


func get_look_sensitivity_multiplier() -> float:
	var movement_pressed: bool = (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_D)
	)
	var sprinting: bool = (
		movement_pressed
		and Input.is_key_pressed(KEY_SHIFT)
		and Input.is_key_pressed(KEY_R)
		and not Input.is_key_pressed(KEY_CTRL)
	)
	return 0.70 if sprinting else 1.0

func _get_target_move_speed(crouching: bool) -> float:
	if crouching:
		return walk_speed * crouch_speed_multiplier
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
	var sprint_modifier_pressed: bool = Input.is_key_pressed(KEY_R)
	if shift_pressed and sprint_modifier_pressed:
		return sprint_speed
	if shift_pressed:
		return fast_walk_speed
	return walk_speed

func _update_collider(height: float) -> void:
	_capsule.height = maxf(height, _capsule.radius * 2.0)
	_collider.position.y = _capsule.height * 0.5
