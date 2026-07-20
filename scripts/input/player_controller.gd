class_name PlayerController
extends Node

signal unit_selected(unit: TacticalUnit)
signal grid_cell_clicked(cell: Vector2i)

@export var camera_path: NodePath
var _camera: Camera3D

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_left_click(mouse_event.position)

func _handle_left_click(screen_position: Vector2) -> void:
	if _camera == null:
		return
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + _camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 3)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: CollisionObject3D = hit.get("collider") as CollisionObject3D
	if collider is TacticalUnit:
		unit_selected.emit(collider as TacticalUnit)
		return
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	grid_cell_clicked.emit(Vector2i(roundi(hit_position.x), roundi(hit_position.z)))
