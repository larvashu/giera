class_name TacticalUnit
extends Area3D

signal stats_changed
signal health_changed(current_health: int, max_health: int)
signal action_points_changed(current_action_points: int, max_action_points: int)
signal died(unit: TacticalUnit)

enum Faction { PLAYER, ENEMY }

const DEFAULT_ABILITIES: Dictionary = {
	&"warrior": ["Ciezkie ciecie", "Tarcza", "Prowokacja"],
	&"archer": ["Precyzyjny strzal", "Pulapka", "Sokole oko"],
	&"mage": ["Kula ognia", "Lodowy pocisk", "Teleportacja"],
	&"priest": ["Leczenie", "Blogoslawienstwo", "Ochrona"],
	&"rogue": ["Cios w plecy", "Unik", "Znikniecie"],
	&"druid": ["Korzenie", "Regeneracja", "Burza lisci"],
	&"ogre": ["Miazdzenie", "Ryk", "Szarza"],
	&"troll": ["Maczuga", "Regeneracja", "Kamienna skora"],
	&"golem": ["Kamienny cios", "Forteca", "Wstrzas"],
	&"dragon": ["Smoczy oddech", "Lot", "Ogon"],
	&"undead_priest": ["Dotyk zarazy", "Nekrotyczne leczenie", "Klatwa grobu"],
	&"falconer": ["Sokoli zwiad", "Pikowanie", "Oznaczenie celu"],
	&"bandit": ["Brudny cios", "Rzut nozem", "Zasadzka"]
}

@export var faction: Faction = Faction.PLAYER
@export var team_id: int = 0
@export var owner_player_id: int = 1
@export var character_id: StringName = &"warrior"
@export var team_slot_cost: int = 1
@export var display_name: String = "Jednostka"
@export var grid_position: Vector2i = Vector2i.ZERO
@export var max_health: int = 10
@export var current_health: int = 10
@export var max_action_points: int = 6
@export var current_action_points: int = 6
@export var initiative: int = 10
var attributes: Dictionary[StringName, int] = {}
var abilities: Array[String] = []
var statuses: Dictionary[StringName, Dictionary] = {}
var race_id: StringName
var class_id: StringName
var profile_uuid: String = ""
var initiative_tiebreaker: int = -1
var is_alive: bool = true
var has_finished_turn: bool = false

var _selection_marker: MeshInstance3D
var _active_marker: MeshInstance3D
var _health_fill: MeshInstance3D
var _name_label: Label3D
var _stats_label: Label3D
var _action_point_dots: Array[MeshInstance3D] = []
var _active_ap_material: StandardMaterial3D
var _spent_ap_material: StandardMaterial3D
var _definition_color: Color = Color.TRANSPARENT
var _definition_scale: float = 1.0
var _definition_visual_scene: PackedScene
var _definition_visual_offset: Vector3 = Vector3.ZERO
var _definition_visual_rotation: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _visual_root: Node3D
var _animation_controller := CharacterAnimationController.new()
const MOVE_STEP_DURATION := 0.125
const TURN_DURATION := 0.075

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	current_health = clampi(current_health, 0, max_health)
	current_action_points = clampi(current_action_points, 0, max_action_points)
	is_alive = current_health > 0
	add_to_group("tactical_units")
	_build_visuals()
	set_selected(false)
	set_active(false)
	_update_overhead_ui()

func configure(
	new_faction: Faction,
	new_team_id: int,
	new_display_name: String,
	new_grid_position: Vector2i,
	health: int,
	action_points: int,
	new_initiative: int
) -> void:
	faction = new_faction
	team_id = new_team_id
	display_name = new_display_name
	grid_position = new_grid_position
	max_health = maxi(1, health)
	current_health = max_health
	max_action_points = maxi(0, action_points)
	current_action_points = max_action_points
	initiative = new_initiative
	is_alive = true
	position = Vector3(float(grid_position.x), 0.05, float(grid_position.y))
	if is_node_ready():
		_apply_faction_color()
		_update_overhead_ui()

func apply_character_definition(
	definition: CharacterDefinition,
	new_owner_player_id: int,
	new_team_id: int,
	new_grid_position: Vector2i
) -> void:
	character_id = definition.character_id
	abilities.clear()
	for ability_name: String in DEFAULT_ABILITIES.get(character_id, ["Akcja podstawowa", "Obrona", "Wsparcie"]):
		abilities.append(ability_name)
	team_slot_cost = definition.team_slot_cost
	owner_player_id = new_owner_player_id
	team_id = new_team_id
	faction = Faction.PLAYER if new_team_id == 0 else Faction.ENEMY
	display_name = definition.display_name
	grid_position = new_grid_position
	max_health = definition.max_health
	current_health = max_health
	max_action_points = definition.max_action_points
	current_action_points = max_action_points
	initiative = definition.initiative
	_definition_color = definition.visual_color
	_definition_scale = definition.visual_scale
	_definition_visual_scene = definition.visual_scene
	_definition_visual_offset = definition.visual_offset
	_definition_visual_rotation = definition.visual_rotation_degrees
	is_alive = true
	position = Vector3(float(grid_position.x), 0.05, float(grid_position.y))
	if is_node_ready():
		_apply_faction_color()
		_update_overhead_ui()

func is_player_controlled() -> bool:
	return team_id == 0

func is_moving() -> bool:
	return _is_moving

func is_dead() -> bool:
	return not is_alive or current_health <= 0

func reset_action_points() -> void:
	current_action_points = max_action_points
	_process_turn_statuses()
	action_points_changed.emit(current_action_points, max_action_points)
	stats_changed.emit()
	_update_overhead_ui()

func can_spend_action_points(cost: int) -> bool:
	return is_alive and cost >= 0 and current_action_points >= cost

func spend_action_points(cost: int) -> bool:
	if not can_spend_action_points(cost):
		return false
	current_action_points = maxi(0, current_action_points - cost)
	action_points_changed.emit(current_action_points, max_action_points)
	stats_changed.emit()
	_update_overhead_ui()
	return true

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current_health = maxi(0, current_health - amount)
	_animation_controller.play_hurt()
	health_changed.emit(current_health, max_health)
	stats_changed.emit()
	_update_overhead_ui()
	if current_health == 0:
		is_alive = false
		died.emit(self)
		queue_free()

func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	stats_changed.emit()
	_update_overhead_ui()

func apply_status(status_id: StringName, value: int, duration: int, source: TacticalUnit = null) -> void:
	if status_id.is_empty() or duration <= 0 or is_dead():
		return
	var existing: Dictionary = statuses.get(status_id, {})
	statuses[status_id] = {
		"value": maxi(value, int(existing.get("value", 0))),
		"duration": maxi(duration, int(existing.get("duration", 0))),
		"source": source
	}
	stats_changed.emit()
	_update_overhead_ui()

func status_value(status_id: StringName) -> int:
	return int((statuses.get(status_id, {}) as Dictionary).get("value", 0))

func has_status(status_id: StringName) -> bool:
	return statuses.has(status_id) and int(statuses[status_id].get("duration", 0)) > 0

func can_move_this_turn() -> bool:
	return not has_status(&"rooted") and not has_status(&"stunned")

func _process_turn_statuses() -> void:
	if has_status(&"regeneration"):
		heal(status_value(&"regeneration"))
	if has_status(&"poisoned"):
		take_damage(status_value(&"poisoned"))
	if has_status(&"burning"):
		take_damage(status_value(&"burning"))
	if has_status(&"slowed"):
		current_action_points = maxi(0, current_action_points - status_value(&"slowed"))
	if has_status(&"haste"):
		current_action_points = mini(max_action_points + status_value(&"haste"), current_action_points + status_value(&"haste"))
	if has_status(&"stunned"):
		current_action_points = 0

func end_turn_statuses() -> void:
	var expired: Array[StringName] = []
	for status_id: StringName in statuses:
		var data: Dictionary = statuses[status_id]
		data["duration"] = int(data.get("duration", 1)) - 1
		if int(data.duration) <= 0:
			expired.append(status_id)
	for status_id: StringName in expired:
		statuses.erase(status_id)
	stats_changed.emit()
	_update_overhead_ui()

static func status_label(status_id: StringName) -> String:
	const LABELS: Dictionary = {
		&"guard": "ochrona", &"weakened": "oslabienie", &"marked": "oznaczenie",
		&"rooted": "unieruchomienie", &"slowed": "spowolnienie", &"haste": "przyspieszenie",
		&"might": "wzmocnienie", &"dodge": "unik", &"hidden": "ukrycie",
		&"regeneration": "regeneracja", &"stunned": "ogluszenie", &"poisoned": "trucizna",
		&"burning": "podpalenie"
	}
	return String(LABELS.get(status_id, String(status_id)))

func set_selected(selected: bool) -> void:
	if _selection_marker != null:
		_selection_marker.visible = selected

func set_active(active: bool) -> void:
	if _active_marker != null:
		_active_marker.visible = active
	stats_changed.emit()

func move_along_path(path: Array[Vector2i], cell_size: float, height_provider: Callable = Callable()) -> void:
	if path.is_empty() or _is_moving:
		return
	_is_moving = true
	_animation_controller.play_walk(1.3)
	for cell: Vector2i in path:
		var target_height: float = float(height_provider.call(cell)) if height_provider.is_valid() else 0.0
		var target := Vector3(float(cell.x) * cell_size, target_height + 0.05, float(cell.y) * cell_size)
		_face_world_position(target, true)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "position", target, MOVE_STEP_DURATION)
		await tween.finished
		grid_position = cell
	_is_moving = false
	_animation_controller.play_idle()

func play_attack_animation(target: TacticalUnit = null) -> void:
	if target != null:
		_face_world_position(target.global_position)
	_animation_controller.play_attack()

func _face_world_position(target: Vector3, immediate: bool = false) -> void:
	if _visual_root == null:
		return
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	# Godot nodes face -Z. The imported visual rotation is an authoring correction,
	# so it must be applied on top of the -Z heading (PI), not directly to +Z.
	var desired_yaw := atan2(direction.x, direction.z) + PI + deg_to_rad(_definition_visual_rotation.y)
	desired_yaw = wrapf(desired_yaw, -PI, PI)
	if immediate:
		_visual_root.rotation.y = desired_yaw
		return
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn.tween_method(_set_visual_yaw.bind(_visual_root.rotation.y, desired_yaw), 0.0, 1.0, TURN_DURATION)

func _set_visual_yaw(weight: float, from_yaw: float, to_yaw: float) -> void:
	_visual_root.rotation.y = lerp_angle(from_yaw, to_yaw, weight)

func _build_visuals() -> void:
	if _definition_visual_scene != null:
		var model := _definition_visual_scene.instantiate() as Node3D
		if model != null:
			model.name = "CharacterModel"
			model.position = _definition_visual_offset
			model.rotation_degrees = _definition_visual_rotation
			model.scale = Vector3.ONE * _definition_scale
			add_child(model)
			_visual_root = model
			_animation_controller.setup(model, _character_definition())
	else:
		var body_mesh := MeshInstance3D.new()
		body_mesh.name = "Body"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.28
		cylinder.bottom_radius = 0.38
		cylinder.height = 0.9
		body_mesh.mesh = cylinder
		body_mesh.position.y = 0.5
		add_child(body_mesh)

		var head_mesh := MeshInstance3D.new()
		head_mesh.name = "Head"
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		head_mesh.mesh = sphere
		head_mesh.position.y = 1.12
		add_child(head_mesh)
		_visual_root = self

	var collision := CollisionShape3D.new()
	collision.name = "SelectionCollider"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.45
	collision.shape = shape
	collision.position.y = 0.7
	add_child(collision)

	_selection_marker = _create_ring("SelectionMarker", 0.43, 0.53, Color(1.0, 0.72, 0.08, 1.0), 0.04)
	add_child(_selection_marker)
	_active_marker = _create_ring("ActiveTurnMarker", 0.57, 0.66, Color(0.1, 1.0, 0.95, 1.0), 0.055)
	add_child(_active_marker)
	_build_overhead_ui()
	_apply_faction_color()

func _character_definition() -> CharacterDefinition:
	var catalog := get_node_or_null("/root/TeamSaveManager") as TeamSaveService
	return catalog.get_character(character_id) if catalog != null else null

func _create_ring(marker_name: String, inner: float, outer: float, color: Color, height: float) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 32
	ring.ring_segments = 8
	marker.mesh = ring
	marker.position.y = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	marker.material_override = material
	return marker

func _build_overhead_ui() -> void:
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.position = Vector3(0.0, 1.78, 0.0)
	_name_label.font_size = 38
	_name_label.outline_size = 8
	_name_label.pixel_size = 0.006
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	add_child(_name_label)

	var health_back := MeshInstance3D.new()
	health_back.name = "HealthBarBackground"
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(1.05, 0.12)
	health_back.mesh = back_quad
	health_back.position = Vector3(0.0, 1.57, 0.0)
	health_back.material_override = _create_billboard_material(Color(0.05, 0.05, 0.06, 0.95))
	add_child(health_back)

	_health_fill = MeshInstance3D.new()
	_health_fill.name = "HealthBarFill"
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(1.0, 0.075)
	_health_fill.mesh = fill_quad
	_health_fill.position = Vector3(0.0, 1.57, 0.01)
	_health_fill.material_override = _create_billboard_material(
		Color(0.12, 0.75, 1.0, 1.0) if is_player_controlled() else Color(1.0, 0.24, 0.18, 1.0)
	)
	add_child(_health_fill)

	_stats_label = Label3D.new()
	_stats_label.name = "StatsLabel"
	_stats_label.position = Vector3(0.0, 1.39, 0.0)
	_stats_label.font_size = 30
	_stats_label.outline_size = 7
	_stats_label.pixel_size = 0.0055
	_stats_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stats_label.no_depth_test = true
	add_child(_stats_label)
	_build_action_point_dots()

func _build_action_point_dots() -> void:
	_active_ap_material = _create_dot_material(Color(0.18, 0.95, 0.35, 1.0))
	_spent_ap_material = _create_dot_material(Color(0.28, 0.31, 0.34, 1.0))
	var spacing: float = 0.16
	var start_x: float = -float(max_action_points - 1) * spacing * 0.5
	for index: int in range(max_action_points):
		var dot := MeshInstance3D.new()
		dot.name = "ActionPointDot_%d" % (index + 1)
		var sphere := SphereMesh.new()
		sphere.radius = 0.055
		sphere.height = 0.11
		dot.mesh = sphere
		dot.position = Vector3(start_x + float(index) * spacing, 1.98, 0.0)
		dot.material_override = _active_ap_material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot)
		_action_point_dots.append(dot)

func _create_dot_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	material.no_depth_test = true
	return material

func _create_billboard_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material

func _update_overhead_ui() -> void:
	if _name_label == null or _stats_label == null or _health_fill == null:
		return
	_name_label.text = display_name
	_name_label.modulate = Color(0.45, 0.85, 1.0, 1.0) if is_player_controlled() else Color(1.0, 0.55, 0.45, 1.0)
	_stats_label.text = "%d / %d" % [current_health, max_health]
	for index: int in range(_action_point_dots.size()):
		_action_point_dots[index].material_override = (
			_active_ap_material if index < current_action_points else _spent_ap_material
		)
	var ratio: float = float(current_health) / float(maxi(1, max_health))
	_health_fill.scale.x = ratio
	_health_fill.position.x = -0.5 * (1.0 - ratio)

func _apply_faction_color() -> void:
	var fallback_color := Color(0.12, 0.48, 0.95, 1.0) if is_player_controlled() else Color(0.9, 0.16, 0.18, 1.0)
	var color := _definition_color if _definition_color.a > 0.0 else fallback_color
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	for child: Node in get_children():
		if child is MeshInstance3D and child.name in ["Body", "Head"]:
			var visual := child as MeshInstance3D
			visual.material_override = material
			visual.scale = Vector3.ONE * _definition_scale
