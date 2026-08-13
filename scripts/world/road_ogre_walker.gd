class_name RoadOgreWalker
extends Node3D

const WALK_SPEED := 2.6
const MIN_ROAD_Z := 12.0
const MAX_ROAD_Z := 178.0
const MIN_LEG_DISTANCE := 20.0
const MAX_LEG_DISTANCE := 34.0
const MIN_PAUSE := 3.0
const MAX_PAUSE := 6.0
const TURN_BACK_CHANCE := 0.38

var _grid_manager: GridManager
var _direction := 1.0
var _rng := RandomNumberGenerator.new()
var _animation_controller := CharacterAnimationController.new()
var _model: Node3D


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	_rng.seed = 8_741_903
	var start_z := 92.0
	position = _road_position(start_z)
	_build_visual()
	call_deferred("_roam")


func _build_visual() -> void:
	var catalog := get_node_or_null("/root/TeamSaveManager") as TeamSaveService
	var definition := catalog.get_character(&"ogre") if catalog != null else null
	if definition == null or definition.visual_scene == null:
		return
	_model = definition.visual_scene.instantiate() as Node3D
	if _model == null:
		return
	_model.name = "GloomtuskModel"
	_model.scale = Vector3.ONE * definition.visual_scale
	_model.rotation_degrees = definition.visual_rotation_degrees
	add_child(_model)
	_animation_controller.setup(_model, definition)

	var body := StaticBody3D.new()
	body.name = "OgreBody"
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.25
	capsule.height = 3.8
	collision.shape = capsule
	collision.position.y = 1.85
	body.add_child(collision)
	add_child(body)


func _roam() -> void:
	while is_inside_tree() and _grid_manager != null and is_instance_valid(_grid_manager):
		_animation_controller.play_walk(0.47)
		var leg_distance := _rng.randf_range(MIN_LEG_DISTANCE, MAX_LEG_DISTANCE)
		var destination_z := clampf(position.z + leg_distance * _direction, MIN_ROAD_Z, MAX_ROAD_Z)
		await _walk_to_z(destination_z)
		if not is_inside_tree():
			return
		_animation_controller.play_idle()
		await get_tree().create_timer(_rng.randf_range(MIN_PAUSE, MAX_PAUSE)).timeout
		if not is_inside_tree():
			return
		var at_road_end := is_equal_approx(destination_z, MIN_ROAD_Z) or is_equal_approx(destination_z, MAX_ROAD_Z)
		if at_road_end or _rng.randf() < TURN_BACK_CHANCE:
			_direction *= -1.0


func _walk_to_z(destination_z: float) -> void:
	while is_inside_tree() and absf(position.z - destination_z) > 0.08:
		var delta := get_process_delta_time()
		if delta <= 0.0:
			await get_tree().process_frame
			continue
		var next_z := move_toward(position.z, destination_z, WALK_SPEED * delta)
		var target := _road_position(next_z)
		_face_target(target)
		position = target
		await get_tree().process_frame


func _road_position(local_z: float) -> Vector3:
	var local_x := 80.0 + sin(local_z * 0.055) * 12.0
	return Vector3(local_x, _grid_manager.terrain_height(local_x, local_z) + 0.05, local_z)


func _face_target(target: Vector3) -> void:
	if _model == null:
		return
	var direction := target - position
	direction.y = 0.0
	if direction.length_squared() < 0.00001:
		return
	# Model ma korekte autora 180 stopni, wiec koncowy kierunek odpowiada -Z Godota.
	_model.rotation.y = wrapf(atan2(direction.x, direction.z) + TAU, -PI, PI)
