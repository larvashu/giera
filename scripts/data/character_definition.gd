class_name CharacterDefinition
extends Resource

@export var character_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var role_name: String
@export_range(1, 5, 1) var team_slot_cost: int = 1
@export var max_health: int = 10
@export var max_action_points: int = 6
@export var initiative: int = 10
@export var movement_range: int = 6
@export var scene: PackedScene
@export var visual_scene: PackedScene
@export var visual_color: Color = Color.WHITE
@export_range(0.5, 2.5, 0.1) var visual_scale: float = 1.0
@export var visual_offset: Vector3 = Vector3.ZERO
@export var visual_rotation_degrees: Vector3 = Vector3.ZERO
