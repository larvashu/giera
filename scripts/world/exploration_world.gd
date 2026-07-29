class_name ExplorationWorld
extends Node3D

const REGION_SCRIPT := preload("res://scripts/world/exploration_region.gd")
const REGION_SIZE := Vector2(160.0, 190.0)

var world: Dictionary
var loaded_regions: Dictionary = {}
var current_coordinate := Vector2i(0, 0)
var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.15
var gravity := 9.8
var status_label: Label

func _ready() -> void:
	world = ExplorationWorldCatalog.load_world()
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_build_environment()
	_build_player()
	_build_hud()
	_update_streaming(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.0022
		pitch = clampf(pitch - motion.relative.y * 0.0022, -1.45, 1.35)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_D): input.x += 1.0
	if Input.is_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_key_pressed(KEY_S): input.y += 1.0
	input = input.limit_length(1.0)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var speed := 18.0 if Input.is_key_pressed(KEY_SHIFT) else 8.0
	var direction := (right * input.x + forward * -input.y).normalized()
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor(): player.velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE): player.velocity.y = 6.5
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation.x = pitch
	_update_streaming(false)

func _update_streaming(force: bool) -> void:
	var next := Vector2i(floori(player.global_position.x / REGION_SIZE.x), floori(player.global_position.z / REGION_SIZE.y))
	if not force and next == current_coordinate: return
	current_coordinate = next
	var wanted: Dictionary = {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var coordinate := current_coordinate + Vector2i(dx, dz)
			var descriptor := ExplorationWorldCatalog.region_at(world, coordinate)
			if descriptor.is_empty(): continue
			wanted[coordinate] = true
			var needs_detail := coordinate == current_coordinate
			if loaded_regions.has(coordinate) and (loaded_regions[coordinate] as ExplorationRegion).detailed != needs_detail:
				(loaded_regions[coordinate] as Node).queue_free()
				loaded_regions.erase(coordinate)
			if not loaded_regions.has(coordinate):
				var region := REGION_SCRIPT.new() as ExplorationRegion
				region.configure(descriptor, needs_detail)
				add_child(region)
				loaded_regions[coordinate] = region
	for coordinate: Vector2i in loaded_regions.keys():
		if not wanted.has(coordinate):
			(loaded_regions[coordinate] as Node).queue_free()
			loaded_regions.erase(coordinate)
	var active := ExplorationWorldCatalog.region_at(world, current_coordinate)
	status_label.text = "%s  |  warstwa: %s/4  |  zaladowane plansze: %d/49" % [active.get("name", "Poza swiatem"), active.get("layer", "-"), loaded_regions.size()]

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Explorer"
	player.position = Vector3(REGION_SIZE.x * 0.5, 5.0, REGION_SIZE.y * 0.5)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.35; capsule.height = 1.8
	collision.shape = capsule; collision.position.y = 0.9
	player.add_child(collision)
	camera = Camera3D.new(); camera.position.y = 1.65; camera.current = true
	player.add_child(camera)
	add_child(player)

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("8fb7cf")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("b9c9bc")
	resource.ambient_light_energy = 0.65
	environment.environment = resource
	add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0); sun.shadow_enabled = true
	add_child(sun)

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	status_label = Label.new(); status_label.position = Vector2(24, 22); status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(status_label)
	var help := Label.new(); help.position = Vector2(24, 52); help.text = "WASD - ruch | Shift - bieg | Spacja - skok | Esc - menu"
	layer.add_child(help)
