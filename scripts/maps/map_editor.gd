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
const TOOL_GROUPS: Array[Dictionary] = [
	{"title": "LAD", "open": true, "tools": [
		["terrain_raise", "Podnies teren"], ["terrain_lower", "Obniz teren"],
		["terrain_smooth", "Wygladz teren"], ["paint_0", "Trawa"],
		["paint_1", "Ziemia"], ["paint_2", "Piasek"], ["paint_3", "Skala"],
		["water_add", "Woda"], ["water_remove", "Usun wode"],
	]},
	{"title": "OBIEKTY", "open": true, "thumbnails": true, "tools": [
		["purple_tree_1", "Drzewo I"], ["purple_tree_2", "Drzewo II"],
		["purple_tree_3", "Drzewo III"], ["large_tree", "Wielkie drzewo"],
		["bush", "Krzak"], ["grass_1", "Trawa I"], ["grass_2", "Trawa II"],
	]},
	{"title": "POSTACIE", "open": false, "tools": [
		["player_spawn", "Start gracza"], ["enemy_spawn", "Start wroga"],
	]},
	{"title": "EDYCJA", "open": true, "tools": [
		["select", "Zaznacz obiekt"], ["erase", "Usun obiekt"],
	]},
]

var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = [{"x": 78, "z": 9}, {"x": 81, "z": 9}]
var enemy_spawns: Array[Dictionary] = [{"x": 78, "z": 180}, {"x": 81, "z": 180}]
var active_tool: String = "terrain_raise"
var brush_radius: float = 6.0
var brush_strength: float = 0.65
var object_density: float = 0.18
var _object_renderer: MapObjectMultiMeshRenderer
var _dragging_camera := false
var _painting_objects := false
var _last_object_stamp := Vector3(INF, INF, INF)
var _fpp_enabled := false
var _ghost_placed := false
var _ghost_position := Vector3.ZERO
var _ghost_yaw := 0.0
var _fpp_pitch := 0.0
var _editor_camera_transform := Transform3D.IDENTITY
var _editor_camera_size := 92.0
var _fpp_speed := 18.0
var _last_mouse_position := Vector2.ZERO
var _last_action_msec := 0
var _selected_object_index := -1
var _selection_ring: MeshInstance3D
var _transform_label: Label
var _transform_buttons: Array[Button] = []

@onready var canvas: Control = %MapCanvas
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _terrain_surface: TerrainMapSurface
var _water_surface: WaterMapSurface
var _objects_root: Node3D
var _markers_root: Node3D
var _camera: Camera3D
var _cursor: MeshInstance3D
var _brush_radius_slider: HSlider
var _brush_strength_slider: HSlider
var _density_slider: HSlider
var _brush_label: Label

func _ready() -> void:
	_build_sidebar_controls()
	_build_3d_view()
	await _terrain_surface.setup(_camera)
	_water_surface.setup(_terrain_surface)
	_connect_ui()
	_rebuild_objects()
	_update_markers()
	_update_status("Edytor gotowy — wybierz widoczne narzedzie")

func _build_sidebar_controls() -> void:
	%ToolOption.visible = false
	var parent := %ToolOption.get_parent() as VBoxContainer
	var insertion_index := %ToolOption.get_index()
	var scroll := ScrollContainer.new()
	scroll.name = "ToolPaletteScroll"
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, insertion_index)
	var tools_panel := VBoxContainer.new()
	tools_panel.name = "VisibleToolPalette"
	tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_panel.add_theme_constant_override("separation", 5)
	scroll.add_child(tools_panel)
	for group: Dictionary in TOOL_GROUPS:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 4)
		tools_panel.add_child(section)
		var title := Button.new()
		title.text = ("▼ " if bool(group.get("open", false)) else "▶ ") + str(group["title"])
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.add_theme_font_size_override("font_size", 13)
		section.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		grid.visible = bool(group.get("open", false))
		section.add_child(grid)
		title.pressed.connect(_toggle_section.bind(title, grid, str(group["title"])))
		for entry: Array in group["tools"]:
			var tool_id := str(entry[0])
			var label := str(entry[1])
			grid.add_child(_create_tool_button(tool_id, label, bool(group.get("thumbnails", false))))
	_transform_label = Label.new()
	_transform_label.text = "TRANSFORMACJA — brak zaznaczenia"
	_transform_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_panel.add_child(_transform_label)
	var transform_grid := GridContainer.new()
	transform_grid.columns = 3
	tools_panel.add_child(transform_grid)
	for entry: Array in [
		["↶ 15°", -15.0, 0.0, false], ["↷ 15°", 15.0, 0.0, false],
		["Odwroc", 0.0, 0.0, true], ["Obniz", 0.0, -0.25, false],
		["Wyzeruj", 0.0, INF, false], ["Podnies", 0.0, 0.25, false],
	]:
		var button := Button.new()
		button.text = str(entry[0])
		button.custom_minimum_size = Vector2(84.0, 28.0)
		button.disabled = true
		button.pressed.connect(_transform_selected.bind(float(entry[1]), float(entry[2]), bool(entry[3])))
		transform_grid.add_child(button)
		_transform_buttons.append(button)
	_brush_label = Label.new()
	_brush_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_panel.add_child(_brush_label)
	_brush_radius_slider = HSlider.new()
	_brush_radius_slider.min_value = 1.5
	_brush_radius_slider.max_value = 18.0
	_brush_radius_slider.step = 0.5
	_brush_radius_slider.value = brush_radius
	tools_panel.add_child(_brush_radius_slider)
	_brush_strength_slider = HSlider.new()
	_brush_strength_slider.min_value = 0.1
	_brush_strength_slider.max_value = 2.0
	_brush_strength_slider.step = 0.05
	_brush_strength_slider.value = brush_strength
	tools_panel.add_child(_brush_strength_slider)
	_density_slider = HSlider.new()
	_density_slider.min_value = 0.02
	_density_slider.max_value = 0.65
	_density_slider.step = 0.01
	_density_slider.value = object_density
	_density_slider.tooltip_text = "Gestosc obiektow na metr kwadratowy"
	tools_panel.add_child(_density_slider)
	_update_brush_label()

func _toggle_section(button: Button, content: Control, title: String) -> void:
	content.visible = not content.visible
	button.text = ("▼ " if content.visible else "▶ ") + title

func _create_tool_button(tool_id: String, label: String, thumbnail: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(140.0, 108.0 if thumbnail else 30.0)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_select_tool.bind(tool_id, label))
	if thumbnail and ASSETS.has(tool_id):
		button.icon = _create_asset_preview(ASSETS[tool_id])
		button.add_theme_constant_override("icon_max_width", 72)
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return button

func _create_asset_preview(scene_path: String) -> Texture2D:
	var preview := SubViewport.new()
	preview.size = Vector2i(96, 72)
	preview.transparent_bg = true
	preview.own_world_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(preview)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return preview.get_texture()
	var model := packed.instantiate() as Node3D
	if model == null:
		return preview.get_texture()
	preview.add_child(model)
	var bounds := _node_bounds(model)
	model.position -= bounds.get_center()
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(1.5, extent * 1.35)
	preview.add_child(camera)
	camera.look_at_from_position(Vector3(extent * 1.15, extent * 0.7, extent * 1.65), Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	light.light_energy = 1.4
	preview.add_child(light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	preview.add_child(world_environment)
	return preview.get_texture()

func _node_bounds(root: Node3D) -> AABB:
	var result := AABB(Vector3.ZERO, Vector3.ONE)
	var initialized := false
	for child: Node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		var child_bounds := visual.get_aabb()
		child_bounds = visual.transform * child_bounds
		if initialized:
			result = result.merge(child_bounds)
		else:
			result = child_bounds
			initialized = true
	return result

func _select_tool(tool_id: String, label: String) -> void:
	active_tool = tool_id
	_update_status("Narzedzie: " + label)

func _select_nearest(world_position: Vector3) -> void:
	var best_index := -1
	var best_distance := 3.0
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var distance := Vector2(float(data.get("x", 0)), float(data.get("z", 0))).distance_to(Vector2(world_position.x, world_position.z))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	_selected_object_index = best_index
	_update_selection_ui()

func _transform_selected(rotation_delta: float, height_delta: float, flip: bool) -> void:
	if _selected_object_index < 0 or _selected_object_index >= objects.size():
		return
	var data: Dictionary = objects[_selected_object_index]
	data["rotation"] = fposmod(float(data.get("rotation", 0.0)) + rotation_delta, 360.0)
	if is_inf(height_delta):
		data["height_offset"] = 0.0
	else:
		data["height_offset"] = clampf(float(data.get("height_offset", 0.0)) + height_delta, -5.0, 12.0)
	if flip:
		data["flipped"] = not bool(data.get("flipped", false))
	objects[_selected_object_index] = data
	_rebuild_objects()
	_update_selection_ui()

func _update_selection_ui() -> void:
	var valid := _selected_object_index >= 0 and _selected_object_index < objects.size()
	for button: Button in _transform_buttons:
		button.disabled = not valid
	if not valid:
		_transform_label.text = "TRANSFORMACJA — brak zaznaczenia"
		if _selection_ring != null:
			_selection_ring.visible = false
		return
	var data: Dictionary = objects[_selected_object_index]
	_transform_label.text = "TRANSFORMACJA — %s | kat %.0f° | wysokosc %+.2f" % [str(data.get("type", "obiekt")), float(data.get("rotation", 0.0)), float(data.get("height_offset", 0.0))]
	if _selection_ring != null and _object_renderer != null:
		_selection_ring.visible = true
		_selection_ring.position = _object_renderer.get_instance_position(_selected_object_index) + Vector3.UP * 0.08

func _build_3d_view() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "RenderedMap"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "MapViewport"
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_objects_root = Node3D.new()
	_world.add_child(_objects_root)
	_object_renderer = MapObjectMultiMeshRenderer.new()
	_object_renderer.name = "ObjectMultiMeshes"
	_objects_root.add_child(_object_renderer)
	_object_renderer.configure(ASSETS, _resolve_editor_object_position, false)
	_markers_root = Node3D.new()
	_world.add_child(_markers_root)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 92.0
	_camera.position = Vector3(80.0, 105.0, 134.0)
	_camera.rotation_degrees = Vector3(-56.0, 0.0, 0.0)
	_camera.current = true
	_world.add_child(_camera)
	_terrain_surface = TerrainMapSurface.new()
	_world.add_child(_terrain_surface)
	_water_surface = WaterMapSurface.new()
	_world.add_child(_water_surface)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.15
	_world.add_child(sun)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.095)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.66, 0.78)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	_world.add_child(world_environment)
	_cursor = MeshInstance3D.new()
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
	_selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.05
	_selection_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.78, 0.18)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.55, 0.08)
	ring_material.emission_energy_multiplier = 1.6
	_selection_ring.material_override = ring_material
	_selection_ring.visible = false
	_markers_root.add_child(_selection_ring)

func _connect_ui() -> void:
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
	_density_slider.value_changed.connect(func(value: float) -> void:
		object_density = value
		_update_brush_label()
	)

func _process(delta: float) -> void:
	if not _fpp_enabled:
		return
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction := _camera.global_basis.x * input_vector.x + _camera.global_basis.z * input_vector.y
	if Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL):
		direction -= Vector3.UP
	var speed := _fpp_speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if direction.length_squared() > 0.0:
		_camera.position += direction.normalized() * speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_TAB:
			if key.shift_pressed:
				_place_ghost_at_cursor()
			else:
				_toggle_fpp()
			get_viewport().set_input_as_handled()
	elif _fpp_enabled and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_ghost_yaw -= motion.relative.x * 0.0025
		_fpp_pitch = clampf(_fpp_pitch - motion.relative.y * 0.0025, deg_to_rad(-88.0), deg_to_rad(88.0))
		_camera.rotation = Vector3(_fpp_pitch, _ghost_yaw, 0.0)
	elif _fpp_enabled and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_fpp_speed = minf(80.0, _fpp_speed * 1.2)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_fpp_speed = maxf(2.0, _fpp_speed / 1.2)

func _place_ghost_at_cursor() -> void:
	if _fpp_enabled:
		return
	var value: Variant = _screen_to_map(_last_mouse_position)
	if value == null:
		_update_status("Najedz kursorem na teren, aby ustawic ducha kamery")
		return
	var hit := value as Vector3
	_ghost_position = hit + Vector3.UP * 1.7
	_ghost_yaw = 0.0
	_fpp_pitch = 0.0
	_ghost_placed = true
	_update_status("Duch kamery ustawiony — Tab: wejdz do FPP")

func _toggle_fpp() -> void:
	if not _fpp_enabled and not _ghost_placed:
		_place_ghost_at_cursor()
		if not _ghost_placed:
			return
	_fpp_enabled = not _fpp_enabled
	if _fpp_enabled:
		_editor_camera_transform = _camera.transform
		_editor_camera_size = _camera.size
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.position = _ghost_position
		_camera.rotation = Vector3(_fpp_pitch, _ghost_yaw, 0.0)
		_cursor.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_status("FPP — WASD/mysz, Space/Ctrl: gora/dol, Shift: szybciej, Tab: powrot")
	else:
		_ghost_position = _camera.position
		_ghost_yaw = _camera.rotation.y
		_fpp_pitch = _camera.rotation.x
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.transform = _editor_camera_transform
		_camera.size = _editor_camera_size
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_status("Widok edycji — Shift+Tab ustawia ducha, Tab: FPP")

func _on_viewport_input(event: InputEvent) -> void:
	if _fpp_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging_camera:
			_pan_camera(motion.position - _last_mouse_position)
		else:
			_update_cursor(motion.position)
			if _painting_objects:
				_try_apply_at_screen(motion.position)
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
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_painting_objects = button.pressed
			if button.pressed:
				_last_object_stamp = Vector3(INF, INF, INF)
				_try_apply_at_screen(button.position)

func _try_apply_at_screen(screen_position: Vector2) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_action_msec < 75:
		return
	var hit: Variant = _screen_to_map(screen_position)
	if hit == null:
		return
	var world_position := hit as Vector3
	var minimum_spacing := maxf(0.65, brush_radius * 0.22)
	if ASSETS.has(active_tool) and not is_inf(_last_object_stamp.x) and _last_object_stamp.distance_to(world_position) < minimum_spacing:
		return
	_last_action_msec = now_msec
	_last_object_stamp = world_position
	_apply_tool(world_position)

func _pan_camera(delta: Vector2) -> void:
	var factor := _camera.size / maxf(320.0, _viewport_container.size.y)
	_camera.position.x = clampf(_camera.position.x - delta.x * factor, -20.0, float(GRID_SIZE.x) + 20.0)
	_camera.position.z = clampf(_camera.position.z - delta.y * factor, 20.0, float(GRID_SIZE.y) + 100.0)

func _screen_to_map(screen_position: Vector2) -> Variant:
	var hit := _terrain_surface.get_intersection(
		_camera.project_ray_origin(screen_position),
		_camera.project_ray_normal(screen_position)
	)
	if is_nan(hit.x) or hit.x < -0.5 or hit.z < -0.5 or hit.x >= GRID_SIZE.x - 0.5 or hit.z >= GRID_SIZE.y - 0.5:
		return null
	return hit

func _update_cursor(screen_position: Vector2) -> void:
	var value: Variant = _screen_to_map(screen_position)
	if value == null:
		_cursor.visible = false
		return
	var hit := value as Vector3
	_cursor.visible = true
	_cursor.position = hit + Vector3.UP * 0.16
	var uses_brush := active_tool.begins_with("terrain_") or active_tool.begins_with("paint_") or active_tool.begins_with("water_") or ASSETS.has(active_tool)
	var radius := brush_radius if uses_brush else 0.75
	_cursor.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

func _apply_tool(world_position: Vector3) -> void:
	var cell := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if active_tool.begins_with("terrain_"):
		_terrain_surface.apply_brush(world_position, brush_radius, brush_strength, active_tool.trim_prefix("terrain_"))
		_reposition_scene_content()
		_water_surface.load_cells(_water_surface.serialize_cells())
	elif active_tool.begins_with("paint_"):
		_terrain_surface.paint_texture(world_position, brush_radius, brush_strength, int(active_tool.trim_prefix("paint_")))
	elif active_tool == "water_add" or active_tool == "water_remove":
		_water_surface.apply_brush(world_position, brush_radius, active_tool == "water_remove")
	elif active_tool == "select":
		_select_nearest(world_position)
	elif active_tool == "erase":
		_erase_nearest(world_position)
	elif active_tool == "player_spawn":
		_set_spawn(player_spawns, cell)
		_update_markers()
	elif active_tool == "enemy_spawn":
		_set_spawn(enemy_spawns, cell)
		_update_markers()
	else:
		_scatter_objects(world_position)
	_update_status("Obiekty: %d | Woda: %d pol" % [objects.size(), _water_surface.get_cell_count()])

func _scatter_objects(center: Vector3) -> void:
	if not ASSETS.has(active_tool):
		return
	var obstacle := active_tool.begins_with("purple_tree_") or active_tool == "large_tree"
	var effective_density := minf(object_density, 0.10) if obstacle else object_density
	var maximum := 80 if obstacle else 240
	var requested := clampi(roundi(PI * brush_radius * brush_radius * effective_density), 1, maximum)
	var added := 0
	for index: int in range(requested * 3):
		if added >= requested:
			break
		var angle := randf() * TAU
		var distance := sqrt(randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if x < 0.0 or z < 0.0 or x >= float(GRID_SIZE.x) or z >= float(GRID_SIZE.y):
			continue
		if _has_nearby_object(active_tool, Vector2(x, z), 0.7 if obstacle else 0.35):
			continue
		objects.append({
			"type": active_tool,
			"x": x,
			"z": z,
			"rotation": randf_range(0.0, 360.0),
			"scale": randf_range(0.86, 1.14),
			"height_offset": 0.0,
			"flipped": randf() < 0.5,
		})
		added += 1
	_selected_object_index = objects.size() - 1 if added > 0 else -1
	_rebuild_objects()
	_update_selection_ui()

func _has_nearby_object(kind: String, target_position: Vector2, minimum_distance: float) -> bool:
	for data: Dictionary in objects:
		if str(data.get("type", "")) != kind:
			continue
		var existing := Vector2(float(data.get("x", 0.0)), float(data.get("z", 0.0)))
		if existing.distance_to(target_position) < minimum_distance:
			return true
	return false

func _erase_nearest(world_position: Vector3) -> void:
	var best_index := -1
	var best_distance := 2.5
	for index: int in range(objects.size()):
		var data: Dictionary = objects[index]
		var distance := Vector2(float(data.get("x", 0)), float(data.get("z", 0))).distance_to(Vector2(world_position.x, world_position.z))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index >= 0:
		objects.remove_at(best_index)
		_selected_object_index = -1
		_rebuild_objects()
		_update_selection_ui()

func _set_spawn(spawns: Array[Dictionary], cell: Vector2i) -> void:
	if not spawns.is_empty():
		spawns.pop_front()
	spawns.append({"x": cell.x, "z": cell.y})

func terrain_height(world_x: float, world_z: float) -> float:
	return _terrain_surface.get_height(world_x, world_z)

func _rebuild_objects() -> void:
	if _object_renderer == null:
		return
	_object_renderer.rebuild(objects)

func _resolve_editor_object_position(data: Dictionary) -> Vector3:
	var x := float(data.get("x", 0.0))
	var z := float(data.get("z", 0.0))
	return Vector3(x, terrain_height(x, z), z)

func _reposition_scene_content() -> void:
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()

func _update_markers() -> void:
	for child: Node in _markers_root.get_children():
		if child != _cursor and child != _selection_ring:
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
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = color
	marker_material.emission_enabled = true
	marker_material.emission = color
	marker_material.emission_energy_multiplier = 1.4
	marker.material_override = marker_material
	var x := float(data.get("x", 0))
	var z := float(data.get("z", 0))
	marker.position = Vector3(x, terrain_height(x, z) + 0.1, z)
	_markers_root.add_child(marker)

func _clear_map() -> void:
	objects.clear()
	_selected_object_index = -1
	_terrain_surface.clear_height()
	_water_surface.clear()
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()
	_update_status("Mapa wyczyszczona")

func _save() -> void:
	var map_name := str(%NameEdit.text).strip_edges()
	if map_name.is_empty():
		_update_status("Podaj nazwe mapy.")
		return
	var safe_name := map_name.to_lower().replace(" ", "_")
	var terrain_directory := "user://maps/terrain/" + safe_name
	_terrain_surface.save_to_directory(terrain_directory)
	var path: String = get_node("/root/MapCatalog").save_map({
		"version": 4,
		"name": map_name,
		"objects": objects,
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
		"terrain_directory": terrain_directory,
		"water_cells": _water_surface.serialize_cells(),
	})
	_update_status("Zapisano: " + path)

func _update_brush_label() -> void:
	_brush_label.text = "PEDZEL — promien %.1f / sila %.2f / gestosc %.2f" % [brush_radius, brush_strength, object_density]

func _update_status(message: String) -> void:
	%StatusLabel.text = message + "\nLPM: maluj | PPM/MMB: przesun | Shift+Tab: ustaw ducha | Tab: FPP"
