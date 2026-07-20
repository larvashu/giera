extends Control

const GRID_SIZE := Vector2i(160, 190)
const ASSETS: Dictionary[String, String] = {
	"purple_tree_1": "res://assets/models/environment/purple_tree_01.glb",
	"purple_tree_2": "res://assets/models/environment/purple_tree_02.glb",
	"purple_tree_3": "res://assets/models/environment/purple_tree_03.glb",
	"large_tree": "res://assets/models/environment/large_tree.glb",
	"bush": "res://assets/models/environment/bush_grass_02.glb",
	"grass_1": "res://assets/models/environment/grass_clump_01.glb",
	"grass_2": "res://assets/models/environment/grass_clump_02.glb",
}
const TOOLS: Array[String] = [
	"purple_tree_1", "purple_tree_2", "purple_tree_3", "large_tree",
	"bush", "grass_1", "grass_2", "erase", "player_spawn", "enemy_spawn",
	"terrain_raise", "terrain_lower", "terrain_smooth"
]
const TOOL_LABELS: Array[String] = [
	"Drzewo I", "Drzewo II", "Drzewo III", "Wielkie drzewo",
	"Krzak", "Trawa I", "Trawa II", "Gumka", "Start P1", "Start P2",
	"Teren: podnies", "Teren: obniz", "Teren: wyrownaj"
]
const TERRAIN_TEXTURE: Texture2D = preload("res://assets/textures/terrain/realistic_grass.png")

var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = [{"x": 78, "z": 9}, {"x": 81, "z": 9}]
var enemy_spawns: Array[Dictionary] = [{"x": 78, "z": 180}, {"x": 81, "z": 180}]
var terrain_strokes: Array[Dictionary] = []
var active_tool: String = "purple_tree_1"
var brush_radius: float = 6.0
var brush_strength: float = 0.65
var _object_nodes: Array[Node3D] = []
var _dragging_camera: bool = false
var _last_mouse_position: Vector2
var _terrain_rebuild_pending: bool = false
var _last_action_msec: int = 0

@onready var canvas: Control = %MapCanvas
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _terrain: MeshInstance3D
var _objects_root: Node3D
var _markers_root: Node3D
var _camera: Camera3D
var _cursor: MeshInstance3D
var _brush_radius_slider: HSlider
var _brush_strength_slider: HSlider
var _brush_label: Label

func _ready() -> void:
	_build_sidebar_controls()
	_build_3d_view()
	_connect_ui()
	_rebuild_terrain()
	_rebuild_objects()
	_update_markers()
	_update_status("Widok 3D gotowy")

func _build_sidebar_controls() -> void:
	for index: int in range(TOOLS.size()):
		%ToolOption.add_item(TOOL_LABELS[index])
	var tool_option := %ToolOption as OptionButton
	var parent := tool_option.get_parent() as VBoxContainer
	var tool_index := tool_option.get_index()
	_brush_label = Label.new()
	_brush_label.text = "Pedzel terenu: promien 6.0 / sila 0.65"
	parent.add_child(_brush_label)
	parent.move_child(_brush_label, tool_index + 1)
	_brush_radius_slider = HSlider.new()
	_brush_radius_slider.min_value = 1.5
	_brush_radius_slider.max_value = 18.0
	_brush_radius_slider.step = 0.5
	_brush_radius_slider.value = brush_radius
	parent.add_child(_brush_radius_slider)
	parent.move_child(_brush_radius_slider, tool_index + 2)
	_brush_strength_slider = HSlider.new()
	_brush_strength_slider.min_value = 0.1
	_brush_strength_slider.max_value = 2.0
	_brush_strength_slider.step = 0.05
	_brush_strength_slider.value = brush_strength
	parent.add_child(_brush_strength_slider)
	parent.move_child(_brush_strength_slider, tool_index + 3)

func _build_3d_view() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "RenderedMap"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "MapViewport"
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "MapWorld"
	_viewport.add_child(_world)
	_objects_root = Node3D.new()
	_objects_root.name = "PlacedObjects"
	_world.add_child(_objects_root)
	_markers_root = Node3D.new()
	_markers_root.name = "Markers"
	_world.add_child(_markers_root)
	_terrain = MeshInstance3D.new()
	_terrain.name = "EditableTerrain"
	_world.add_child(_terrain)
	_camera = Camera3D.new()
	_camera.name = "EditorCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 92.0
	_camera.position = Vector3(80.0, 105.0, 134.0)
	_camera.rotation_degrees = Vector3(-56.0, 0.0, 0.0)
	_camera.current = true
	_world.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.15
	_world.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.095)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.66, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_world.add_child(environment)
	_cursor = MeshInstance3D.new()
	_cursor.name = "BrushCursor"
	var cursor_mesh := CylinderMesh.new()
	cursor_mesh.top_radius = 0.5
	cursor_mesh.bottom_radius = 0.5
	cursor_mesh.height = 0.08
	cursor_mesh.radial_segments = 48
	_cursor.mesh = cursor_mesh
	var cursor_material := StandardMaterial3D.new()
	cursor_material.albedo_color = Color(0.16, 0.92, 0.66, 0.42)
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor.material_override = cursor_material
	_cursor.visible = false
	_markers_root.add_child(_cursor)

func _connect_ui() -> void:
	%ToolOption.item_selected.connect(_on_tool_selected)
	_viewport_container.gui_input.connect(_on_viewport_input)
	%SaveButton.pressed.connect(_save)
	%ClearButton.pressed.connect(_clear_map)
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	_brush_radius_slider.value_changed.connect(func(value: float) -> void:
		brush_radius = value
		_update_brush_label()
	)
	_brush_strength_slider.value_changed.connect(func(value: float) -> void:
		brush_strength = value
		_update_brush_label()
	)

func _on_tool_selected(index: int) -> void:
	active_tool = TOOLS[index]
	_cursor.visible = false
	_update_status("Narzedzie: %s" % TOOL_LABELS[index])

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging_camera:
			_pan_camera(motion.position - _last_mouse_position)
		else:
			_update_cursor(motion.position)
		_last_mouse_position = motion.position
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_camera = button.pressed
			_last_mouse_position = button.position
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = maxf(24.0, _camera.size * 0.88)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = minf(210.0, _camera.size * 1.12)
		elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var now_msec := Time.get_ticks_msec()
			if now_msec - _last_action_msec < 140:
				return
			_last_action_msec = now_msec
			var world_position: Variant = _screen_to_map(button.position)
			if world_position != null:
				_apply_tool(world_position as Vector3)

func _pan_camera(delta: Vector2) -> void:
	var factor: float = _camera.size / maxf(320.0, _viewport_container.size.y)
	_camera.position.x -= delta.x * factor
	_camera.position.z -= delta.y * factor
	_camera.position.x = clampf(_camera.position.x, -20.0, float(GRID_SIZE.x) + 20.0)
	_camera.position.z = clampf(_camera.position.z, 20.0, float(GRID_SIZE.y) + 100.0)

func _screen_to_map(screen_position: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return null
	var distance: float = -origin.y / direction.y
	if distance < 0.0:
		return null
	var hit := origin + direction * distance
	if hit.x < -0.5 or hit.z < -0.5 or hit.x >= GRID_SIZE.x - 0.5 or hit.z >= GRID_SIZE.y - 0.5:
		return null
	hit.y = terrain_height(hit.x, hit.z)
	return hit

func _update_cursor(screen_position: Vector2) -> void:
	var world_position: Variant = _screen_to_map(screen_position)
	if world_position == null:
		_cursor.visible = false
		return
	var hit := world_position as Vector3
	_cursor.visible = true
	_cursor.position = hit + Vector3.UP * 0.08
	var radius: float = brush_radius if active_tool.begins_with("terrain_") else 0.75
	_cursor.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

func _apply_tool(world_position: Vector3) -> void:
	var cell := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if active_tool.begins_with("terrain_"):
		var operation := active_tool.trim_prefix("terrain_")
		terrain_strokes.append({
			"x": world_position.x,
			"z": world_position.z,
			"radius": brush_radius,
			"strength": brush_strength,
			"operation": operation,
		})
		_schedule_terrain_rebuild()
	elif active_tool == "erase":
		_erase_nearest(world_position)
	elif active_tool == "player_spawn":
		_set_spawn(player_spawns, cell)
		_update_markers()
	elif active_tool == "enemy_spawn":
		_set_spawn(enemy_spawns, cell)
		_update_markers()
	else:
		objects.append({
			"type": active_tool,
			"x": cell.x,
			"z": cell.y,
			"rotation": randf_range(0.0, 360.0),
			"scale": 1.0,
		})
		_rebuild_objects()
	_update_status("Obiektow: %d / ruchow terenu: %d" % [objects.size(), terrain_strokes.size()])

func _schedule_terrain_rebuild() -> void:
	if _terrain_rebuild_pending:
		return
	_terrain_rebuild_pending = true
	call_deferred("_finish_terrain_rebuild")

func _finish_terrain_rebuild() -> void:
	_terrain_rebuild_pending = false
	_rebuild_terrain()
	_reposition_scene_content()

func _erase_nearest(world_position: Vector3) -> void:
	var best_index: int = -1
	var best_distance: float = 2.5
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var distance := Vector2(float(data.get("x", 0)), float(data.get("z", 0))).distance_to(Vector2(world_position.x, world_position.z))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index >= 0:
		objects.remove_at(best_index)
		_rebuild_objects()

func _set_spawn(spawns: Array[Dictionary], cell: Vector2i) -> void:
	if not spawns.is_empty():
		spawns.pop_front()
	spawns.append({"x": cell.x, "z": cell.y})

func terrain_height(world_x: float, world_z: float) -> float:
	var height: float = _base_terrain_height(world_x, world_z)
	for stroke: Dictionary in terrain_strokes:
		var center := Vector2(float(stroke.get("x", 0.0)), float(stroke.get("z", 0.0)))
		var radius := maxf(0.1, float(stroke.get("radius", 1.0)))
		var distance := Vector2(world_x, world_z).distance_to(center)
		if distance >= radius:
			continue
		var influence: float = 1.0 - distance / radius
		influence = influence * influence * (3.0 - 2.0 * influence)
		var strength := float(stroke.get("strength", 0.5))
		match str(stroke.get("operation", "raise")):
			"raise": height += strength * influence
			"lower": height -= strength * influence
			"smooth": height = lerpf(height, _base_terrain_height(world_x, world_z), clampf(strength * 0.35 * influence, 0.0, 1.0))
	return height

func _base_terrain_height(world_x: float, world_z: float) -> float:
	return 0.018 * sin(world_x * 0.41 + world_z * 0.19) + 0.012 * cos(world_x * 0.23 - world_z * 0.37)

func _rebuild_terrain() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const STEP := 2
	for z: int in range(0, GRID_SIZE.y, STEP):
		for x: int in range(0, GRID_SIZE.x, STEP):
			var x0: float = float(x) - 0.5
			var x1: float = minf(float(x + STEP) - 0.5, float(GRID_SIZE.x) - 0.5)
			var z0: float = float(z) - 0.5
			var z1: float = minf(float(z + STEP) - 0.5, float(GRID_SIZE.y) - 0.5)
			_append_terrain_vertex(vertices, normals, uvs, x0, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z1)
			_append_terrain_vertex(vertices, normals, uvs, x0, z0)
			_append_terrain_vertex(vertices, normals, uvs, x1, z1)
			_append_terrain_vertex(vertices, normals, uvs, x0, z1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_terrain.mesh = mesh
	var terrain_material := StandardMaterial3D.new()
	terrain_material.albedo_texture = TERRAIN_TEXTURE
	terrain_material.uv1_scale = Vector3(40.0, 48.0, 1.0)
	terrain_material.albedo_color = Color(0.48, 0.72, 0.42)
	terrain_material.roughness = 0.96
	_terrain.material_override = terrain_material

func _append_terrain_vertex(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, x: float, z: float) -> void:
	vertices.append(Vector3(x, terrain_height(x, z), z))
	var dx: float = terrain_height(x - 0.25, z) - terrain_height(x + 0.25, z)
	var dz: float = terrain_height(x, z - 0.25) - terrain_height(x, z + 0.25)
	normals.append(Vector3(dx, 0.5, dz).normalized())
	uvs.append(Vector2((x + 0.5) / float(GRID_SIZE.x), (z + 0.5) / float(GRID_SIZE.y)))

func _rebuild_objects() -> void:
	for child: Node in _objects_root.get_children():
		child.queue_free()
	_object_nodes.clear()
	for data: Dictionary in objects:
		var kind := str(data.get("type", ""))
		if not ASSETS.has(kind):
			continue
		var packed := load(ASSETS[kind]) as PackedScene
		if packed == null:
			continue
		var holder := Node3D.new()
		var model := packed.instantiate() as Node3D
		if model == null:
			continue
		var scale_value := clampf(float(data.get("scale", 1.0)), 0.2, 8.0)
		model.scale = Vector3.ONE * scale_value
		model.rotation.y = deg_to_rad(float(data.get("rotation", 0.0)))
		holder.add_child(model)
		holder.position = Vector3(float(data.get("x", 0)), terrain_height(float(data.get("x", 0)), float(data.get("z", 0))), float(data.get("z", 0)))
		_objects_root.add_child(holder)
		_object_nodes.append(holder)

func _reposition_scene_content() -> void:
	for index: int in range(mini(objects.size(), _object_nodes.size())):
		var data: Dictionary = objects[index]
		var node := _object_nodes[index]
		node.position.y = terrain_height(float(data.get("x", 0)), float(data.get("z", 0)))
	_update_markers()

func _update_markers() -> void:
	for child: Node in _markers_root.get_children():
		if child != _cursor:
			child.queue_free()
	for spawn: Dictionary in player_spawns:
		_create_spawn_marker(spawn, Color.CYAN)
	for spawn: Dictionary in enemy_spawns:
		_create_spawn_marker(spawn, Color.ORANGE_RED)

func _create_spawn_marker(data: Dictionary, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.12
	marker.mesh = mesh
	var spawn_material := StandardMaterial3D.new()
	spawn_material.albedo_color = color
	spawn_material.emission_enabled = true
	spawn_material.emission = color
	spawn_material.emission_energy_multiplier = 1.4
	marker.material_override = spawn_material
	var x := float(data.get("x", 0))
	var z := float(data.get("z", 0))
	marker.position = Vector3(x, terrain_height(x, z) + 0.1, z)
	_markers_root.add_child(marker)

func _clear_map() -> void:
	objects.clear()
	terrain_strokes.clear()
	_rebuild_terrain()
	_rebuild_objects()
	_update_markers()
	_update_status("Mapa wyczyszczona")

func _save() -> void:
	var map_name: String = str(%NameEdit.text).strip_edges()
	if map_name.is_empty():
		_update_status("Podaj nazwe mapy.")
		return
	var path: String = get_node("/root/MapCatalog").save_map({
		"version": 2,
		"name": map_name,
		"objects": objects,
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
		"terrain_strokes": terrain_strokes,
	})
	_update_status("Zapisano: " + path)

func _update_brush_label() -> void:
	_brush_label.text = "Pedzel terenu: promien %.1f / sila %.2f" % [brush_radius, brush_strength]

func _update_status(message: String) -> void:
	%StatusLabel.text = message + "\nLPM: uzyj | PPM/MMB: przesun | rolka: zoom"
