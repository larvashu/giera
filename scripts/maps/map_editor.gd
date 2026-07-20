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
	{"title": "TEREN — KSZTALT", "tools": [
		["terrain_raise", "Podnies"], ["terrain_lower", "Obniz"], ["terrain_smooth", "Wygladz"],
	]},
	{"title": "TEREN — MATERIAL", "tools": [
		["paint_0", "Trawa"], ["paint_1", "Ziemia"], ["paint_2", "Piasek"], ["paint_3", "Skala"],
	]},
	{"title": "TEREN — WODA", "tools": [
		["water_add", "Dodaj wode"], ["water_remove", "Usun wode"],
	]},
	{"title": "OBIEKTY / DRZEWA", "tools": [
		["purple_tree_1", "Drzewo I"], ["purple_tree_2", "Drzewo II"],
		["purple_tree_3", "Drzewo III"], ["large_tree", "Wielkie"],
		["bush", "Krzak"], ["grass_1", "Trawa I"], ["grass_2", "Trawa II"], ["erase", "Gumka"],
	]},
	{"title": "POSTACIE", "tools": [
		["player_spawn", "Start gracza"], ["enemy_spawn", "Start wroga"],
	]},
]

var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = [{"x": 78, "z": 9}, {"x": 81, "z": 9}]
var enemy_spawns: Array[Dictionary] = [{"x": 78, "z": 180}, {"x": 81, "z": 180}]
var active_tool: String = "terrain_raise"
var brush_radius: float = 6.0
var brush_strength: float = 0.65
var _object_nodes: Array[Node3D] = []
var _dragging_camera := false
var _last_mouse_position := Vector2.ZERO
var _last_action_msec := 0

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
	var tools_panel := VBoxContainer.new()
	tools_panel.name = "VisibleToolPalette"
	tools_panel.add_theme_constant_override("separation", 3)
	parent.add_child(tools_panel)
	parent.move_child(tools_panel, insertion_index)
	for group: Dictionary in TOOL_GROUPS:
		var title := Label.new()
		title.text = str(group["title"])
		title.add_theme_font_size_override("font_size", 12)
		title.modulate = Color(0.72, 0.9, 0.84)
		tools_panel.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 3)
		tools_panel.add_child(grid)
		for entry: Array in group["tools"]:
			var button := Button.new()
			var tool_id := str(entry[0])
			var label := str(entry[1])
			button.text = label
			button.custom_minimum_size = Vector2(76.0, 24.0)
			button.add_theme_font_size_override("font_size", 11)
			button.pressed.connect(_select_tool.bind(tool_id, label))
			grid.add_child(button)
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
	_update_brush_label()

func _select_tool(tool_id: String, label: String) -> void:
	active_tool = tool_id
	_update_status("Narzedzie: " + label)

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
			if now_msec - _last_action_msec < 90:
				return
			_last_action_msec = now_msec
			var hit: Variant = _screen_to_map(button.position)
			if hit != null:
				_apply_tool(hit as Vector3)

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
	var uses_brush := active_tool.begins_with("terrain_") or active_tool.begins_with("paint_") or active_tool.begins_with("water_")
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
	elif active_tool == "erase":
		_erase_nearest(world_position)
	elif active_tool == "player_spawn":
		_set_spawn(player_spawns, cell)
		_update_markers()
	elif active_tool == "enemy_spawn":
		_set_spawn(enemy_spawns, cell)
		_update_markers()
	else:
		objects.append({"type": active_tool, "x": cell.x, "z": cell.y, "rotation": randf_range(0.0, 360.0), "scale": 1.0})
		_rebuild_objects()
	_update_status("Obiekty: %d | Woda: %d pol" % [objects.size(), _water_surface.get_cell_count()])

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
		_rebuild_objects()

func _set_spawn(spawns: Array[Dictionary], cell: Vector2i) -> void:
	if not spawns.is_empty():
		spawns.pop_front()
	spawns.append({"x": cell.x, "z": cell.y})

func terrain_height(world_x: float, world_z: float) -> float:
	return _terrain_surface.get_height(world_x, world_z)

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
		var x := float(data.get("x", 0))
		var z := float(data.get("z", 0))
		holder.position = Vector3(x, terrain_height(x, z), z)
		_objects_root.add_child(holder)
		_object_nodes.append(holder)

func _reposition_scene_content() -> void:
	for index: int in range(mini(objects.size(), _object_nodes.size())):
		var data: Dictionary = objects[index]
		_object_nodes[index].position.y = terrain_height(float(data.get("x", 0)), float(data.get("z", 0)))
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
	_terrain_surface.clear_height()
	_water_surface.clear()
	_rebuild_objects()
	_update_markers()
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
	_brush_label.text = "PEDZEL — promien %.1f / sila %.2f" % [brush_radius, brush_strength]

func _update_status(message: String) -> void:
	%StatusLabel.text = message + "\nLPM: maluj/stawiaj | PPM/MMB: przesun | rolka: zoom"
