extends Control

const SMALL_MAP_SIZE := Vector2i(160, 190)
const MAP_SIZE_MULTIPLIERS: Array[int] = [1, 2, 4, 8]
const ARENA_TEST_RECT := Rect2i(25, 6, 110, 178)
const ARENA_TEST_LANDSCAPE := preload("res://scripts/maps/arena_test_landscape.gd")
const GRASS_LAYER_SCRIPT := preload("res://scripts/maps/map_grass_layer.gd")
const UNDO_LIMIT := 5
const MAX_BRUSH_RADIUS := 180.0
const WATER_RISE_PER_SECOND := 2.0
const OBJECT_SPATIAL_CELL_SIZE := 16.0
const CLOUD_SKY_SHADER: Shader = preload("res://scripts/maps/editor_clouds.gdshader")
const ASSETS: Dictionary[String, String] = {
	"purple_tree_1": "res://assets/models/environment/purple_tree_01.glb",
	"purple_tree_2": "res://assets/models/environment/purple_tree_02.glb",
	"purple_tree_3": "res://assets/models/environment/purple_tree_03.glb",
	"large_tree": "res://assets/models/environment/large_tree.glb",
	"bush": "res://assets/models/environment/bush_grass_02.glb",
	"grass_1": "res://assets/models/environment/grass_clump_01.glb",
	"grass_2": "res://assets/models/environment/grass_clump_02.glb",
	"tree_real_1": "res://assets/environment/tree_packs/tree/Tree/Tree.fbx",
	"tree_real_2": "res://assets/environment/tree_packs/tree_02/Tree 02/Tree.obj",
	"bush_real_1": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_2": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_3": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_4": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_5": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_6": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_7": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_8": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_real_9": "res://assets/environment/bush_packs/real_bush/source/all Embed.fbx",
	"bush_heather": "res://assets/environment/bush_packs/bush_01/source/Bush.fbx",
	"bush_cliff": "res://assets/environment/bush_packs/cliff_shrub/source/wallBush-01-terrainWallBush.fbx",
	"stylised_rocks": "res://assets/environment/stylised_rocks/source/Stylised_Rock_Collection.fbx",
	"arena_bridge": "res://assets/environment/bridges/long_wood_bridge/source/Long Wood Bridge.fbx",
	"arena_rock": "res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_4_br.glb",
	"arena_soil": "",
	"premium_tree_1": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_5194_Tris.FBX",
	"premium_tree_2": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_11364_Tris.FBX",
	"premium_tree_3": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_107_Tris.FBX",
	"premium_tree_4": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_345_Tris.FBX",
	"premium_tree_5": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_436_Tris.FBX",
	"premium_tree_6": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_491_Tris.FBX",
	"premium_tree_7": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_510_Tris.FBX",
	"premium_tree_8": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_2558_Tris.FBX",
	"premium_tree_9": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_2853_Tris.FBX",
	"premium_tree_10": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_3172_Tris.FBX",
	"premium_tree_11": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_5639_Tris.FBX",
	"premium_tree_12": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_5857_Tris.FBX",
	"premium_tree_13": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_7071_Tris.FBX",
	"premium_tree_14": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_7339_Tris.FBX",
	"premium_tree_15": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_7733_Tris.FBX",
	"premium_tree_16": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_12762_Tris.FBX",
	"premium_tree_17": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_14733_Tris.FBX",
	"premium_tree_18": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_16018_Tris.FBX",
	"premium_tree_19": "res://assets/environment/premium_imports/forest_trees/Forest_Tree_Starter_Kit/Model/DA_Forest_Tree_18195_Tris.FBX",
	"premium_shrub": "res://assets/environment/premium_imports/lycium_shrub/04 Lycium Shawii Shrubs.FBX",
	"moss_rock_08": "res://assets/environment/premium_imports/moss_rock_08/moss rock 08 sketchfab/low.obj",
	"moss_rock_09": "res://assets/environment/premium_imports/moss_rock_09/moss rock 09 sketchfab/moss rock 09.obj",
	"moss_rock_10": "res://assets/environment/premium_imports/moss_rock_10/moss rock 10 sketchfab/moss rock 10.obj",
	"moss_rock_11": "res://assets/environment/premium_imports/moss_rock_11/moss rock 11 sketchfab/moss rock 11.obj",
	"moss_rock_12": "res://assets/environment/premium_imports/moss_rock_12/moss rock 12 sketchfab/moss rock 12.obj",
	"moss_rock_13": "res://assets/environment/premium_imports/moss_rock_13/moss rock 13 sketchfab/moss rock 13.obj",
	"moss_rock_14": "res://assets/environment/premium_imports/moss_rock_14/moss rock 14 sketchfab/moss rock 14.obj",
}
const TOOL_GROUPS: Array[Dictionary] = [
	{"title": "RZEŹBIENIE TERRAIN3D", "open": false, "tools": [
		["terrain_raise", "Podnieś"], ["terrain_lower", "Obniż"],
		["terrain_smooth", "Wygładź"], ["terrain_flatten", "Wyrównaj"],
		["terrain_noise", "Naturalny szum"], ["terrain_erode", "Erozja"],
		["terrain_terrace", "Tarasy skalne"], ["terrain_ridge", "Grzbiet"],
	]},
	{"title": "WODA", "open": false, "tools": [
		["water_add", "Dodaj wodę"], ["water_remove", "Usuń wodę"],
	]},
	{"title": "OBIEKTY ŚRODOWISKOWE", "open": false, "thumbnails": true, "tools": [
		["purple_tree_1", "Drzewo I"], ["purple_tree_2", "Drzewo II"],
		["purple_tree_3", "Drzewo III"], ["large_tree", "Wielkie drzewo"],
		["tree_real_1", "Drzewo realistyczne I"], ["tree_real_2", "Drzewo realistyczne II"],
		["bush", "Krzak"], ["grass_1", "Trawa I"], ["grass_2", "Trawa II"],
		["bush_real_1", "Krzew leśny I"], ["bush_real_2", "Krzew leśny II"],
		["bush_real_3", "Krzew leśny III"], ["bush_real_4", "Krzew leśny IV"],
		["bush_real_5", "Krzew leśny V"], ["bush_real_6", "Krzew leśny VI"],
		["bush_real_7", "Krzew leśny VII"], ["bush_real_8", "Krzew leśny VIII"],
		["bush_real_9", "Krzew leśny IX"], ["bush_heather", "Krzew niski"],
		["bush_cliff", "Krzew skalny"], ["stylised_rocks", "Zestaw skał"],
		["simple_grass", "SimpleGrass — malowanie"],
		["arena_rock", "Skała areny"], ["arena_bridge", "Most areny"],
		["premium_tree_1", "Drzewo premium 01 (5194 tris)"],
		["premium_tree_2", "Drzewo premium 02 (11364 tris)"],
		["premium_tree_3", "Drzewo premium 03 (107 tris)"],
		["premium_tree_4", "Drzewo premium 04 (345 tris)"],
		["premium_tree_5", "Drzewo premium 05 (436 tris)"],
		["premium_tree_6", "Drzewo premium 06 (491 tris)"],
		["premium_tree_7", "Drzewo premium 07 (510 tris)"],
		["premium_tree_8", "Drzewo premium 08 (2558 tris)"],
		["premium_tree_9", "Drzewo premium 09 (2853 tris)"],
		["premium_tree_10", "Drzewo premium 10 (3172 tris)"],
		["premium_tree_11", "Drzewo premium 11 (5639 tris)"],
		["premium_tree_12", "Drzewo premium 12 (5857 tris)"],
		["premium_tree_13", "Drzewo premium 13 (7071 tris)"],
		["premium_tree_14", "Drzewo premium 14 (7339 tris)"],
		["premium_tree_15", "Drzewo premium 15 (7733 tris)"],
		["premium_tree_16", "Drzewo premium 16 (12762 tris)"],
		["premium_tree_17", "Drzewo premium 17 (14733 tris)"],
		["premium_tree_18", "Drzewo premium 18 (16018 tris)"],
		["premium_tree_19", "Drzewo premium 19 (18195 tris)"],
		["premium_shrub", "Krzew Lycium premium"],
		["moss_rock_08", "Omszały kamień 08"], ["moss_rock_09", "Omszały kamień 09"],
		["moss_rock_10", "Omszały kamień 10"], ["moss_rock_11", "Omszały kamień 11"],
		["moss_rock_12", "Omszały kamień 12"], ["moss_rock_13", "Omszały kamień 13"],
		["moss_rock_14", "Omszały kamień 14"],
	]},
	{"title": "POSTACIE", "open": false, "tools": [
		["player_spawn", "Start gracza"], ["enemy_spawn", "Start wroga"],
	]},
	{"title": "EDYCJA", "open": false, "tools": [
		["select", "Zaznacz obiekt"], ["erase", "Usuń obiekt"],
	]},
]

var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = []
var enemy_spawns: Array[Dictionary] = []
var grass_entries: Array[Dictionary] = []
var selected_object_indices: Array[int] = []
var map_size_multiplier := 1
var map_size := SMALL_MAP_SIZE
var map_name := "nowa_mapa"
var _undo_stack: Array[Dictionary] = []
var _stroke_snapshot_taken := false
var _selection_dragging := false
var _selection_start := Vector2.ZERO
var _selection_end := Vector2.ZERO
var grass_width := 1.0
var grass_height := 1.0
var grass_color := Color(0.42, 0.72, 0.22)
var premium_tree_color := Color.WHITE
var water_level := 0.0
var _water_stroke_started_msec := -1
var _water_stroke_start_level := 0.0
var _grass_stroke_id := 0
var _active_grass_stroke_id := 0
var _grass_preview: TextureRect
var active_tool: String = "paint_0"
var selected_texture_id := 0
var brush_radius: float = 6.0
var brush_strength: float = 0.65
var object_density: float = 0.18
var object_height_scale: float = 1.0
var object_scale_randomness: float = 0.14
var object_rotation_randomness: float = 1.0
var _object_renderer: MapObjectMultiMeshRenderer
var _dragging_camera := false
var _painting_objects := false
var _object_rebuild_pending := false
var _object_spatial_index: Dictionary[String, Array] = {}
var _object_spatial_index_count := -1
var _last_object_stamp := Vector3(INF, INF, INF)
var _fpp_enabled := false
var _fpp_painting := false
var _ghost_placed := false
var _ghost_position := Vector3.ZERO
var _ghost_yaw := 0.0
var _fpp_pitch := 0.0
var _editor_camera_transform := Transform3D.IDENTITY
var _editor_camera_size := 92.0
var _editor_camera_far := 4000.0
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
var _waterways_rivers: WaterwaysRiverSurface
var _objects_root: Node3D
var _markers_root: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _cursor: MeshInstance3D
var _brush_radius_slider: HSlider
var _brush_strength_slider: HSlider
var _density_slider: HSlider
var _grass_width_slider: HSlider
var _grass_height_slider: HSlider
var _object_height_slider: HSlider
var _object_scale_randomness_slider: HSlider
var _object_rotation_randomness_slider: HSlider
var _water_level_slider: HSlider
var _tree_color_control: Control
var _grass_color_control: Control
var _brush_label: Label
var _grass_layer: Node3D
var _selection_box: ColorRect
var _bottom_panel: PanelContainer
var _load_map_dialog: ConfirmationDialog
var _saved_map_list: ItemList
var _saved_map_ids: Array[String] = []
var _asset_preview_cache: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	_build_sidebar_controls()
	_build_3d_view()
	_build_bottom_toolbar()
	_build_load_map_dialog()
	await _terrain_surface.setup(_camera)
	_terrain_surface.height_edit_finished.connect(_on_terrain_height_edit_finished)
	_frame_map_camera()
	_water_surface.setup(_terrain_surface)
	_connect_ui()
	_rebuild_objects()
	_update_markers()
	%StatusLabel.text = ""

func _build_sidebar_controls() -> void:
	for label: String in ["Mała", "Średnia (2×)", "Duża (4×)", "Bardzo duża (8×)"]:
		%NewMapSizeOption.add_item(label)
	%NewMapSizeOption.select(0)
	%SculptTab.pressed.connect(_show_tool_category.bind(0))
	%MaterialsTab.pressed.connect(_show_tool_category.bind(-1))
	%WaterTab.pressed.connect(_show_tool_category.bind(1))
	%ObjectsTab.pressed.connect(_show_tool_category.bind(2))
	%CharactersTab.pressed.connect(_show_tool_category.bind(3))
	%EditTab.pressed.connect(_show_tool_category.bind(4))
	_show_tool_category(0)
	_transform_label = Label.new()
	_transform_label.text = "TRANSFORMACJA — brak zaznaczenia"
	_transform_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var transform_grid := GridContainer.new()
	transform_grid.columns = 3
	for entry: Array in [
		["↶ 15°", -15.0, 0.0, false], ["↷ 15°", 15.0, 0.0, false],
		["Odwróć", 0.0, 0.0, true], ["Obniż", 0.0, -0.25, false],
		["Wyzeruj", 0.0, INF, false], ["Podnieś", 0.0, 0.25, false],
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
	_brush_radius_slider = HSlider.new()
	_brush_radius_slider.min_value = 1.5
	_brush_radius_slider.max_value = MAX_BRUSH_RADIUS
	_brush_radius_slider.step = 1.0
	_brush_radius_slider.tooltip_text = "Promień pędzla do 180 m — 10× większy niż wcześniej"
	_brush_radius_slider.value = brush_radius
	_brush_strength_slider = HSlider.new()
	_brush_strength_slider.min_value = 0.1
	_brush_strength_slider.max_value = 12.0
	_brush_strength_slider.step = 0.1
	_brush_strength_slider.tooltip_text = "Siła zmiany wysokości — większe wartości szybko budują wysokie góry"
	_brush_strength_slider.value = brush_strength
	_density_slider = HSlider.new()
	_density_slider.min_value = 0.0
	_density_slider.max_value = 1.0
	_density_slider.step = 0.01
	_density_slider.value = object_density
	_density_slider.tooltip_text = "Gęstość wypełnienia pędzla: niska = kilka assetów nawet na dużym obszarze"

	_update_brush_label()

func _show_tool_category(group_index: int) -> void:
	for child: Node in %AssetList.get_children():
		child.queue_free()
	if group_index == -1:
		%AssetTitle.text = "MATERIAŁY"
		for texture_id: int in range(TerrainMapSurface.PAINT_TEXTURES.size()):
			var definition: Dictionary = TerrainMapSurface.PAINT_TEXTURES[texture_id]
			var button := _create_tool_button("paint_%d" % texture_id, str(definition["name"]), false)
			button.custom_minimum_size = Vector2(140.0, 62.0)
			if definition.has("path"):
				button.icon = load(str(definition["path"])) as Texture2D
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 48)
			%AssetList.add_child(button)
		var fill_button := _create_tool_button("fill_selected_texture", "▣ Zaznacz obszar i wypełnij", false)
		fill_button.tooltip_text = "Przeciągnij prostokąt na mapie, aby wypełnić go ostatnio wybraną teksturą"
		fill_button.custom_minimum_size = Vector2(140.0, 42.0)
		%AssetList.add_child(fill_button)
		return
	var group: Dictionary = TOOL_GROUPS[group_index]
	%AssetTitle.text = str(group["title"]).replace(" TERRAIN3D", "")
	for entry: Array in group["tools"]:
		%AssetList.add_child(_create_tool_button(str(entry[0]), str(entry[1]), bool(group.get("thumbnails", false))))
func _build_bottom_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "BottomEditPanel"
	_bottom_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 472.0
	panel.offset_right = -48.0
	panel.offset_top = -202.0
	panel.offset_bottom = -48.0
	panel.z_index = 100
	panel.top_level = true
	add_child(panel)
	panel.move_to_front()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)
	var edit_row := HBoxContainer.new()
	edit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	edit_row.add_theme_constant_override("separation", 10)
	rows.add_child(edit_row)
	var transform_grid := _transform_buttons[0].get_parent()
	for control: Control in [_transform_label, transform_grid]:
		edit_row.add_child(control)
	_transform_label.custom_minimum_size.x = 220.0
	var select_all := Button.new()
	select_all.text = "Zaznacz wszystko"
	select_all.custom_minimum_size.x = 150.0
	select_all.pressed.connect(_select_all_objects)
	edit_row.add_child(select_all)
	var sliders_row := HBoxContainer.new()
	sliders_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sliders_row.add_theme_constant_override("separation", 12)
	rows.add_child(sliders_row)
	sliders_row.add_child(_brush_label)
	_brush_label.custom_minimum_size.x = 190.0
	_wrap_existing_slider(sliders_row, _brush_radius_slider, "Promień")
	_wrap_existing_slider(sliders_row, _brush_strength_slider, "Siła")
	_wrap_existing_slider(sliders_row, _density_slider, "Gęstość")
	_grass_width_slider = _make_bottom_slider(sliders_row, "Szerokość", 0.25, 3.0, grass_width)
	_grass_height_slider = _make_bottom_slider(sliders_row, "Wysokość trawy", 0.25, 4.0, grass_height)
	_object_height_slider = _make_bottom_slider(sliders_row, "Wysokość assetu", 0.25, 3.0, object_height_scale)
	_object_scale_randomness_slider = _make_bottom_slider(sliders_row, "Losowość skali", 0.0, 1.0, object_scale_randomness)
	_object_scale_randomness_slider.tooltip_text = "Losowość rozmiaru nowych assetów: 0 = identyczne, 1 = od 0.33× do 3×"
	_object_rotation_randomness_slider = _make_bottom_slider(sliders_row, "Losowość obrotu", 0.0, 1.0, object_rotation_randomness)
	_water_level_slider = _make_bottom_slider(sliders_row, "Poziom startowy wody", TerrainMapSurface.MIN_HEIGHT, TerrainMapSurface.MAX_HEIGHT, water_level)
	_water_level_slider.tooltip_text = "Poziom początkowy; przytrzymanie LPM podnosi wodę o 2 m/s"
	_build_premium_tree_color_control(sliders_row)
	_build_grass_color_control(sliders_row)
	_update_brush_controls_for_tool()
	_selection_box = ColorRect.new()
	_selection_box.color = Color(0.15, 0.72, 1.0, 0.20)
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	_selection_box.z_index = 19
	canvas.add_child(_selection_box)


func _build_grass_color_control(parent: Container) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 150.0
	var label := Label.new()
	label.text = "Kolor RGB trawy"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(preview_row)
	_grass_preview = TextureRect.new()
	_grass_preview.texture = load("res://addons/simplegrasstextured/textures/grassbushcc008.png") as Texture2D
	_grass_preview.custom_minimum_size = Vector2(52.0, 42.0)
	_grass_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grass_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grass_preview.modulate = grass_color
	_grass_preview.tooltip_text = "Podgląd wyglądu trawy z wybranym kolorem"
	preview_row.add_child(_grass_preview)
	var picker := ColorPickerButton.new()
	picker.color = grass_color
	picker.custom_minimum_size = Vector2(70.0, 34.0)
	picker.tooltip_text = "Ustaw kolor RGB trawy"
	picker.color_changed.connect(_on_grass_color_changed)
	preview_row.add_child(picker)
	parent.add_child(column)
	_grass_color_control = column


func _build_premium_tree_color_control(parent: Container) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 142.0
	var label := Label.new()
	label.text = "Kolor liści drzewa"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = premium_tree_color
	picker.custom_minimum_size = Vector2(120.0, 34.0)
	picker.tooltip_text = "Kolor zapisze się w nowo malowanych drzewach premium"
	picker.color_changed.connect(func(color: Color) -> void: premium_tree_color = Color(color.r, color.g, color.b, 1.0))
	column.add_child(picker)
	parent.add_child(column)
	_tree_color_control = column


func _on_grass_color_changed(color: Color) -> void:
	grass_color = Color(color.r, color.g, color.b, 1.0)
	if _grass_preview != null:
		_grass_preview.modulate = grass_color
	for entry: Dictionary in grass_entries:
		entry["color"] = grass_color.to_html(false)
	if _grass_layer != null:
		_grass_layer.call("set_grass_color", grass_color)
	_rebuild_grass()


func _wrap_existing_slider(parent: Container, slider: HSlider, title: String) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 112.0
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	column.add_child(slider)
	slider.custom_minimum_size = Vector2(112.0, 24.0)
	var value_label := Label.new()
	value_label.text = "%.2f" % slider.value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void: value_label.text = "%.2f" % new_value)
	parent.add_child(column)


func _make_bottom_slider(parent: Container, title: String, minimum: float, maximum: float, value: float) -> HSlider:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 112.0
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var slider := HSlider.new()
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(112.0, 24.0)
	column.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value_label)
	slider.value_changed.connect(func(new_value: float) -> void: value_label.text = "%.2f" % new_value)
	parent.add_child(column)
	return slider


func _toggle_section(button: Button, content: Control, title: String) -> void:
	content.visible = not content.visible
	button.text = ("▼ " if content.visible else "▶ ") + title

func _create_tool_button(tool_id: String, label: String, thumbnail: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(132.0, 108.0 if thumbnail else 30.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_select_tool.bind(tool_id, label))
	if thumbnail and ASSETS.has(tool_id):
		button.icon = _create_asset_preview(ASSETS[tool_id])
		button.add_theme_constant_override("icon_max_width", 72)
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return button

func _add_material_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	var title := Button.new()
	title.text = "▶ MATERIAŁY TERRAIN3D"
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.tooltip_text = "Natywne warstwy Terrain3D: albedo, normal, roughness i płynny blend"
	section.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	grid.visible = false
	title.pressed.connect(_toggle_section.bind(title, grid, "MATERIAŁY TERRAIN3D"))
	for texture_id: int in range(TerrainMapSurface.PAINT_TEXTURES.size()):
		var definition: Dictionary = TerrainMapSurface.PAINT_TEXTURES[texture_id]
		var button := _create_tool_button("paint_%d" % texture_id, str(definition["name"]), false)
		button.custom_minimum_size = Vector2(140.0, 62.0)
		if definition.has("path"):
			button.icon = load(str(definition["path"])) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 48)
		button.tooltip_text = "%s\nNatywna warstwa Terrain3D" % str(definition["name"])
		grid.add_child(button)

func _create_asset_preview(scene_path: String) -> Texture2D:
	if _asset_preview_cache.has(scene_path):
		return _asset_preview_cache[scene_path]
	var preview := SubViewport.new()
	preview.size = Vector2i(128, 96)
	preview.transparent_bg = false
	preview.own_world_3d = true
	# UPDATE_ONCE often rendered before imported model textures were ready,
	# leaving a blank or untextured icon. Render a few complete frames first.
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview)
	var resource := load(scene_path)
	var model: Node3D
	if resource is PackedScene:
		model = (resource as PackedScene).instantiate() as Node3D
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		model = mesh_instance
	if model == null:
		var empty_texture := preview.get_texture()
		_asset_preview_cache[scene_path] = empty_texture
		return empty_texture
	preview.add_child(model)
	var bounds := _node_bounds(model)
	model.position -= bounds.get_center()
	var extent := maxf(0.1, maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(1.5, extent * 1.35)
	preview.add_child(camera)
	camera.look_at_from_position(Vector3(extent * 1.15, extent * 0.7, extent * 1.65), Vector3.ZERO)
	camera.current = true
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	key_light.light_energy = 1.55
	key_light.shadow_enabled = true
	preview.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(35.0, 145.0, 0.0)
	fill_light.light_energy = 0.65
	preview.add_child(fill_light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	preview.add_child(world_environment)
	var texture := preview.get_texture()
	_asset_preview_cache[scene_path] = texture
	_finish_asset_preview.call_deferred(preview)
	return texture


func _finish_asset_preview(preview: SubViewport) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(preview):
		preview.render_target_update_mode = SubViewport.UPDATE_DISABLED

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
	if tool_id.begins_with("paint_"):
		selected_texture_id = int(tool_id.trim_prefix("paint_"))
	if tool_id == "fill_selected_texture":
		tool_id = "fill_texture_%d" % selected_texture_id
	active_tool = tool_id
	_update_brush_controls_for_tool()
	_update_brush_label()
	_update_status("Narzędzie: " + label)


func _update_brush_controls_for_tool() -> void:
	var is_asset := ASSETS.has(active_tool)
	var is_grass := active_tool == "simple_grass"
	if _object_height_slider != null:
		_object_height_slider.get_parent().visible = is_asset
	if _object_scale_randomness_slider != null:
		_object_scale_randomness_slider.get_parent().visible = is_asset
	if _object_rotation_randomness_slider != null:
		_object_rotation_randomness_slider.get_parent().visible = is_asset
	if _grass_width_slider != null:
		_grass_width_slider.get_parent().visible = is_grass
	if _grass_height_slider != null:
		_grass_height_slider.get_parent().visible = is_grass
	if _grass_color_control != null:
		_grass_color_control.visible = is_grass
	if _tree_color_control != null:
		_tree_color_control.visible = active_tool.begins_with("premium_tree_")
	if _water_level_slider != null:
		_water_level_slider.get_parent().visible = active_tool.begins_with("water_")

func _push_undo_state() -> void:
	_undo_stack.append({
		"objects": objects.duplicate(true),
		"grass": grass_entries.duplicate(true),
		"player_spawns": player_spawns.duplicate(true),
		"enemy_spawns": enemy_spawns.duplicate(true),
		"water": _water_surface.serialize_cells(),
		"terrain": _terrain_surface.capture_state(),
	})
	while _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()


func _undo_last_action() -> void:
	if _undo_stack.is_empty():
		_update_status("Brak wcześniejszych akcji do cofnięcia")
		return
	var state: Dictionary = _undo_stack.pop_back()
	objects.assign(state["objects"])
	grass_entries.assign(state["grass"])
	player_spawns.assign(state["player_spawns"])
	enemy_spawns.assign(state["enemy_spawns"])
	_terrain_surface.restore_state(state["terrain"])
	_water_surface.load_cells(state["water"])
	selected_object_indices.clear()
	_selected_object_index = -1
	_rebuild_objects()
	_rebuild_grass()
	_update_markers()
	_update_selection_ui()
	_update_status("Cofnięto akcję — pozostało %d kroków" % _undo_stack.size())


func _select_all_objects() -> void:
	selected_object_indices.clear()
	for index: int in range(objects.size()):
		selected_object_indices.append(index)
	_selected_object_index = selected_object_indices[0] if not selected_object_indices.is_empty() else -1
	_update_selection_ui()


func _select_objects_in_screen_rect(rect: Rect2) -> void:
	selected_object_indices.clear()
	for index: int in range(objects.size()):
		var screen_point := _camera.unproject_position(_object_renderer.get_instance_position(index))
		if rect.has_point(screen_point):
			selected_object_indices.append(index)
	_selected_object_index = selected_object_indices[0] if not selected_object_indices.is_empty() else -1
	_update_selection_ui()


func _delete_selected_objects() -> void:
	if selected_object_indices.is_empty() and _selected_object_index >= 0:
		selected_object_indices.append(_selected_object_index)
	if selected_object_indices.is_empty():
		return
	_push_undo_state()
	selected_object_indices.sort()
	selected_object_indices.reverse()
	for index: int in selected_object_indices:
		if index >= 0 and index < objects.size():
			objects.remove_at(index)
	selected_object_indices.clear()
	_selected_object_index = -1
	_rebuild_objects()
	_update_selection_ui()


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
	selected_object_indices.clear()
	if best_index >= 0:
		selected_object_indices.append(best_index)
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
	if selected_object_indices.size() > 1:
		_transform_label.text = "ZAZNACZONO: %d obiektów | DEL usuwa" % selected_object_indices.size()
	else:
		_transform_label.text = "TRANSFORMACJA — %s | kąt %.0f° | wysokość %+.2f" % [str(data.get("type", "obiekt")), float(data.get("rotation", 0.0)), float(data.get("height_offset", 0.0))]
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
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.scaling_3d_scale = 0.78
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_objects_root = Node3D.new()
	_world.add_child(_objects_root)
	_object_renderer = MapObjectMultiMeshRenderer.new()
	_object_renderer.name = "ObjectMultiMeshes"
	_objects_root.add_child(_object_renderer)
	_object_renderer.configure(ASSETS, _resolve_editor_object_position, false)
	_grass_layer = GRASS_LAYER_SCRIPT.new() as Node3D
	_grass_layer.name = "SimpleGrassLayer"
	_objects_root.add_child(_grass_layer)
	_grass_layer.call_deferred("set_grass_color", grass_color)
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
	_waterways_rivers = WaterwaysRiverSurface.new()
	_world.add_child(_waterways_rivers)
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.26
	sun.light_indirect_energy = 0.68
	sun.light_volumetric_fog_energy = 0.62
	sun.light_angular_distance = 0.53
	sun.shadow_opacity = 0.88
	sun.shadow_blur = 1.15
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.72
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_fade_start = 0.88
	sun.directional_shadow_blend_splits = true
	_world.add_child(sun)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_SKY
	environment.sky = _create_day_sky()
	environment.background_energy_multiplier = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.92
	environment.ambient_light_energy = 0.54
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.04
	environment.tonemap_agx_contrast = 1.18
	environment.ssao_enabled = true
	environment.ssao_radius = 1.45
	environment.ssao_intensity = 1.12
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.72
	environment.ssil_enabled = true
	environment.ssil_radius = 2.0
	environment.ssil_intensity = 0.46
	environment.sdfgi_enabled = true
	environment.sdfgi_energy = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.24
	environment.glow_bloom = 0.025
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.76, 0.86)
	environment.fog_light_energy = 0.34
	environment.fog_density = 0.00014
	environment.fog_aerial_perspective = 0.62
	environment.fog_sun_scatter = 0.26
	# A short, subtle volumetric layer grounds valleys without fogging the
	# full 12 km camera range or paying for long-distance ray marching.
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0022
	environment.volumetric_fog_length = 320.0
	environment.volumetric_fog_detail_spread = 1.7
	environment.volumetric_fog_ambient_inject = 0.58
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

func _frame_map_camera() -> void:
	var viewport_aspect := maxf(1.0, _viewport_container.size.x / maxf(1.0, _viewport_container.size.y))
	var vertical_coverage := float(map_size.y) * 0.90
	var horizontal_coverage := float(map_size.x) / viewport_aspect * 1.12
	_camera.size = maxf(vertical_coverage, horizontal_coverage)
	# Keep the editor camera above the highest sculptable peaks so ray picking
	# continues to work even after building mountain-scale terrain.
	var camera_height := maxf(_camera.size * 1.10, TerrainMapSurface.MAX_HEIGHT + _camera.size * 0.60)
	var ground_center := Vector3(float(map_size.x) * 0.5, 0.0, float(map_size.y) * 0.5)
	var forward := -_camera.global_basis.z
	var forward_horizontal := Vector3(forward.x, 0.0, forward.z)
	var horizontal_offset := Vector3.ZERO
	if absf(forward.y) > 0.001:
		horizontal_offset = forward_horizontal * (camera_height / -forward.y)
	_camera.position = ground_center - horizontal_offset + Vector3.UP * camera_height
	_camera.far = maxf(4000.0, camera_height * 4.0)
	_editor_camera_transform = _camera.transform
	_editor_camera_size = _camera.size
	_editor_camera_far = _camera.far
	_terrain_surface.terrain.set_camera(_camera)


func _create_day_sky() -> Sky:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = CLOUD_SKY_SHADER
	sky_material.set_shader_parameter("wind_direction", Vector2(0.9, 0.28))
	sky_material.set_shader_parameter("wind_speed", 0.22)
	sky_material.set_shader_parameter("cloud_coverage", 0.46)
	sky_material.set_shader_parameter("cloud_density", 1.05)
	var sky := Sky.new()
	sky.sky_material = sky_material
	# Incremental updates keep animated clouds while avoiding a full IBL
	# cubemap rebuild every frame.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_512
	return sky
func _build_load_map_dialog() -> void:
	_load_map_dialog = ConfirmationDialog.new()
	_load_map_dialog.title = "Wczytaj zapisaną mapę"
	_load_map_dialog.ok_button_text = "Wczytaj"
	_load_map_dialog.cancel_button_text = "Anuluj"
	_load_map_dialog.size = Vector2i(560, 440)
	add_child(_load_map_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(520.0, 350.0)
	_load_map_dialog.add_child(content)
	var hint := Label.new()
	hint.text = "Wybierz mapę zapisaną w edytorze:"
	content.add_child(hint)
	_saved_map_list = ItemList.new()
	_saved_map_list.custom_minimum_size = Vector2(520.0, 310.0)
	_saved_map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_saved_map_list)
	_load_map_dialog.confirmed.connect(_load_selected_saved_map)
	_saved_map_list.item_activated.connect(func(_index: int) -> void:
		_load_selected_saved_map()
		_load_map_dialog.hide()
	)


func _show_load_map_dialog() -> void:
	_saved_map_list.clear()
	_saved_map_ids.clear()
	var catalog: Node = get_node("/root/MapCatalog")
	for entry: Dictionary in catalog.call("list_maps"):
		var map_id := str(entry.get("id", ""))
		if not map_id.begins_with("user://"):
			continue
		var data: Dictionary = catalog.call("load_map", map_id)
		var saved_size: Dictionary = data.get("map_size", {})
		var label := "%s  —  %d × %d m" % [
			str(entry.get("name", "Mapa")),
			int(saved_size.get("x", SMALL_MAP_SIZE.x)),
			int(saved_size.get("y", SMALL_MAP_SIZE.y)),
		]
		_saved_map_list.add_item(label)
		_saved_map_ids.append(map_id)
	if _saved_map_ids.is_empty():
		_saved_map_list.add_item("Brak zapisanych map")
		_saved_map_list.set_item_disabled(0, true)
		_load_map_dialog.get_ok_button().disabled = true
	else:
		_saved_map_list.select(0)
		_load_map_dialog.get_ok_button().disabled = false
	_load_map_dialog.popup_centered(Vector2i(560, 440))


func _load_selected_saved_map() -> void:
	var selected := _saved_map_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if index < 0 or index >= _saved_map_ids.size():
		return
	var catalog: Node = get_node("/root/MapCatalog")
	var data: Dictionary = catalog.call("load_map", _saved_map_ids[index])
	if data.is_empty():
		_update_status("Nie udało się wczytać mapy")
		return
	var saved_multiplier := int(data.get("map_size_multiplier", 1))
	map_size_multiplier = clampi(saved_multiplier, 1, 8)
	var saved_size: Dictionary = data.get("map_size", {})
	map_size = Vector2i(
		int(saved_size.get("x", SMALL_MAP_SIZE.x * map_size_multiplier)),
		int(saved_size.get("y", SMALL_MAP_SIZE.y * map_size_multiplier))
	)
	map_name = str(data.get("name", "wczytana_mapa"))
	var terrain_directory := str(data.get("terrain_directory", ""))
	if not _terrain_surface.load_from_directory(terrain_directory, map_size_multiplier):
		_update_status("Nie udało się wczytać danych terenu mapy")
		return
	objects.assign(data.get("objects", []))
	grass_entries.assign(data.get("grass", []))
	player_spawns.assign(data.get("player_spawns", []))
	enemy_spawns.assign(data.get("enemy_spawns", []))
	grass_width = float(data.get("grass_width", 1.0))
	grass_height = float(data.get("grass_height", 1.0))
	grass_color = Color.from_string(str(data.get("grass_color", "6bb838")), Color(0.42, 0.72, 0.22))
	_grass_width_slider.value = grass_width
	_grass_height_slider.value = grass_height
	_on_grass_color_changed(grass_color)
	_water_surface.set_map_size(map_size)
	_water_surface.load_cells(data.get("water_cells", []))
	_waterways_rivers.load_rivers(data.get("rivers", []))
	_undo_stack.clear()
	_selected_object_index = -1
	_frame_map_camera()
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()
	_update_status("Wczytano: %s — %d × %d m" % [map_name, map_size.x, map_size.y])


func _connect_ui() -> void:
	_viewport_container.gui_input.connect(_on_viewport_input)
	%SaveButton.pressed.connect(_save)
	%ClearButton.pressed.connect(func() -> void:
		%NewMapSizeOption.select(0)
		%NewMapDialog.popup_centered()
	)
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	%LoadButton.pressed.connect(_show_load_map_dialog)
	%NewMapDialog.confirmed.connect(_create_new_map)
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
	_grass_width_slider.value_changed.connect(func(value: float) -> void:
		grass_width = value
		_rebuild_grass()
		_update_brush_label()
	)
	_grass_height_slider.value_changed.connect(func(value: float) -> void:
		grass_height = value
		_rebuild_grass()
		_update_brush_label()
	)
	_object_height_slider.value_changed.connect(func(value: float) -> void:
		object_height_scale = value
		_update_brush_label()
	)
	_object_scale_randomness_slider.value_changed.connect(func(value: float) -> void:
		object_scale_randomness = value
		_update_brush_label()
	)
	_object_rotation_randomness_slider.value_changed.connect(func(value: float) -> void:
		object_rotation_randomness = value
		_update_brush_label()
	)
	_water_level_slider.value_changed.connect(func(value: float) -> void:
		water_level = value
		_update_brush_label()
	)


func _process(delta: float) -> void:
	if not _fpp_enabled:
		if _viewport_container != null and _viewport_container.get_rect().has_point(_viewport_container.get_local_mouse_position()):
			_last_mouse_position = _viewport_container.get_local_mouse_position()
			_update_cursor(_last_mouse_position)
		return
	var fpp_center := _viewport_container.size * 0.5
	_update_cursor(fpp_center)
	var wants_fpp_paint := Input.is_key_pressed(KEY_R)
	if wants_fpp_paint and not _fpp_painting:
		_fpp_painting = true
		_stroke_snapshot_taken = false
		_last_object_stamp = Vector3(INF, INF, INF)
		if active_tool == "simple_grass":
			_grass_stroke_id += 1
			_active_grass_stroke_id = _grass_stroke_id
		elif active_tool == "water_add":
			_begin_water_stroke()
	elif not wants_fpp_paint and _fpp_painting:
		if active_tool == "water_add":
			_try_apply_at_screen(fpp_center, true)
			_end_water_stroke()
		_fpp_painting = false
		if _object_rebuild_pending:
			_flush_object_rebuild()
	if wants_fpp_paint:
		_try_apply_at_screen(fpp_center)
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
		if key.pressed and not key.echo and key.ctrl_pressed and key.keycode == KEY_Z:
			_undo_last_action()
			get_viewport().set_input_as_handled()
		elif key.pressed and not key.echo and key.keycode == KEY_DELETE:
			_delete_selected_objects()
			get_viewport().set_input_as_handled()
		elif key.pressed and not key.echo and key.keycode == KEY_TAB:
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
	if not _fpp_enabled:
		var center_position := _viewport_container.size * 0.5
		var center_hit: Variant = _screen_to_map(center_position)
		if center_hit == null:
			_update_status("Środek widoku musi znajdować się nad mapą, aby wejść do FPP")
			return
		var ground_center := center_hit as Vector3
		_ghost_position = ground_center + Vector3.UP * 1.7
		var iso_forward := -_camera.global_basis.z
		_ghost_yaw = atan2(-iso_forward.x, -iso_forward.z)
		_fpp_pitch = 0.0
		_ghost_placed = true
	_fpp_enabled = not _fpp_enabled
	if _fpp_enabled:
		_editor_camera_transform = _camera.transform
		_editor_camera_size = _camera.size
		_editor_camera_far = _camera.far
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.position = _ghost_position
		_camera.rotation = Vector3(_fpp_pitch, _ghost_yaw, 0.0)
		# The largest 8x map is over 1.5 km deep. Keep distant terrain and
		# decoration visible in first person instead of clipping it at 260 m.
		_camera.far = 12000.0
		# FPP needs native resolution for distant terrain detail; the editor
		# overview keeps its cheaper scale when leaving first person.
		_viewport.scaling_3d_scale = 1.0
		if _sun != null:
			_sun.directional_shadow_max_distance = 600.0
		_cursor.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_status("FPP — WASD/mysz | przytrzymaj R: maluj | Space/Ctrl: góra/dół | Tab: powrót")
	else:
		_ghost_position = _camera.position
		_ghost_yaw = _camera.rotation.y
		_fpp_pitch = _camera.rotation.x
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.transform = _editor_camera_transform
		_camera.size = _editor_camera_size
		_camera.far = _editor_camera_far
		_terrain_surface.terrain.set_camera(_camera)
		_viewport.scaling_3d_scale = 0.78
		if _sun != null:
			_sun.directional_shadow_max_distance = 260.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_status("Widok edycji — Shift+Tab ustawia ducha, Tab: FPP")

func _on_viewport_input(event: InputEvent) -> void:
	if _bottom_panel != null and _bottom_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	if _fpp_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging_camera:
			_pan_camera(motion.position - _last_mouse_position)
		else:
			_update_cursor(motion.position)
			if _selection_dragging:
				_selection_end = motion.position
				var rect := Rect2(_selection_start, _selection_end - _selection_start).abs()
				_selection_box.position = rect.position
				_selection_box.size = rect.size
			elif _painting_objects:
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
			var maximum_zoom_out := maxf(210.0, float(map_size.y) * 1.05)
			_camera.size = minf(maximum_zoom_out, _camera.size * 1.12)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if active_tool == "select" or active_tool.begins_with("fill_texture_"):
				_selection_dragging = button.pressed
				if button.pressed:
					_selection_start = button.position
					_selection_end = button.position
					_selection_box.position = button.position
					_selection_box.size = Vector2.ZERO
					_selection_box.visible = true
				else:
					_selection_box.visible = false
					var selection_rect := Rect2(_selection_start, _selection_end - _selection_start).abs()
					if active_tool.begins_with("fill_texture_"):
						_fill_selected_texture_area(_selection_start, _selection_end)
					elif selection_rect.size.length() < 8.0:
						var hit: Variant = _screen_to_map(button.position)
						if hit != null:
							_select_nearest(hit as Vector3)
					else:
						_select_objects_in_screen_rect(selection_rect)
			else:
				_painting_objects = button.pressed
				if button.pressed:
					_stroke_snapshot_taken = false
					if active_tool == "simple_grass":
						_grass_stroke_id += 1
						_active_grass_stroke_id = _grass_stroke_id
					elif active_tool == "water_add":
						_begin_water_stroke()
					_last_object_stamp = Vector3(INF, INF, INF)
					_try_apply_at_screen(button.position)
				else:
					if active_tool == "water_add":
						_try_apply_at_screen(button.position, true)
						_end_water_stroke()
					if _object_rebuild_pending:
						_flush_object_rebuild()

func _fill_selected_texture_area(screen_start: Vector2, screen_end: Vector2) -> void:
	var start_hit: Variant = _screen_to_map(screen_start)
	var end_hit: Variant = _screen_to_map(screen_end)
	if start_hit == null or end_hit == null:
		_update_status("Zaznaczenie musi zaczynać i kończyć się na mapie")
		return
	var start_point := start_hit as Vector3
	var end_point := end_hit as Vector3
	var min_cell := Vector2i(floori(minf(start_point.x, end_point.x)), floori(minf(start_point.z, end_point.z)))
	var max_cell := Vector2i(ceili(maxf(start_point.x, end_point.x)), ceili(maxf(start_point.z, end_point.z)))
	var fill_rect := Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
	_push_undo_state()
	_terrain_surface.fill_texture_rect(fill_rect, selected_texture_id)
	_update_status("Wypełniono obszar %d × %d m teksturą: %s" % [
		fill_rect.size.x,
		fill_rect.size.y,
		str(TerrainMapSurface.PAINT_TEXTURES[selected_texture_id]["name"]),
	])


func _begin_water_stroke() -> void:
	_water_stroke_started_msec = Time.get_ticks_msec()
	# The first terrain hit anchors water to the local ground. This prevents a
	# stale global slider value from creating a floating sheet.
	_water_stroke_start_level = NAN


func _current_water_brush_level(surface_height: float = NAN) -> float:
	if _water_stroke_started_msec < 0:
		return water_level
	if is_nan(_water_stroke_start_level):
		if is_nan(surface_height):
			return water_level
		_water_stroke_start_level = surface_height + 0.12
		water_level = _water_stroke_start_level
		if _water_level_slider != null:
			_water_level_slider.set_value_no_signal(water_level)
	var elapsed_seconds := float(Time.get_ticks_msec() - _water_stroke_started_msec) / 1000.0
	return clampf(_water_stroke_start_level + elapsed_seconds * WATER_RISE_PER_SECOND, TerrainMapSurface.MIN_HEIGHT, TerrainMapSurface.MAX_HEIGHT)


func _end_water_stroke() -> void:
	if _water_stroke_started_msec < 0:
		return
	if not is_nan(_water_stroke_start_level):
		water_level = _current_water_brush_level()
	_water_stroke_started_msec = -1
	_water_stroke_start_level = NAN
	if _water_level_slider != null:
		_water_level_slider.set_value_no_signal(water_level)
	_update_brush_label()


func _try_apply_at_screen(screen_position: Vector2, force: bool = false) -> void:
	var now_msec := Time.get_ticks_msec()
	if not force and now_msec - _last_action_msec < 75:
		return
	var hit: Variant = _screen_to_map(screen_position)
	if hit == null:
		return
	var world_position := hit as Vector3
	var minimum_spacing := maxf(0.65, brush_radius * 0.22)
	if ASSETS.has(active_tool) and not is_inf(_last_object_stamp.x) and _last_object_stamp.distance_to(world_position) < minimum_spacing:
		return
	if not _stroke_snapshot_taken:
		_push_undo_state()
		_stroke_snapshot_taken = true
	_last_action_msec = now_msec
	_last_object_stamp = world_position
	_apply_tool(world_position)

func _pan_camera(delta: Vector2) -> void:
	var factor := _camera.size / maxf(320.0, _viewport_container.size.y)
	var pan_margin := maxf(80.0, _camera.size * 0.85)
	_camera.position.x = clampf(_camera.position.x - delta.x * factor, -pan_margin, float(map_size.x) + pan_margin)
	_camera.position.z = clampf(_camera.position.z - delta.y * factor, -pan_margin, float(map_size.y) + pan_margin * 2.0)

func _screen_to_map(screen_position: Vector2) -> Variant:
	var hit := _terrain_surface.get_intersection(
		_camera.project_ray_origin(screen_position),
		_camera.project_ray_normal(screen_position)
	)
	if is_nan(hit.x) or hit.x < -0.5 or hit.z < -0.5 or hit.x >= map_size.x - 0.5 or hit.z >= map_size.y - 0.5:
		return null
	return hit

func _update_cursor(screen_position: Vector2) -> void:
	var value: Variant = _screen_to_map(screen_position)
	if value == null:
		_cursor.visible = false
		return
	var hit := value as Vector3
	_cursor.visible = true
	var surface_normal := _terrain_surface.get_surface_normal(hit.x, hit.z)
	_cursor.position = hit + surface_normal * 0.16
	_cursor.basis = Basis(Quaternion(Vector3.UP, surface_normal))
	var uses_brush := active_tool.begins_with("terrain_") or active_tool.begins_with("paint_") or active_tool.begins_with("water_") or active_tool == "simple_grass" or ASSETS.has(active_tool)
	var radius := brush_radius if uses_brush else 0.75
	_cursor.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

func _apply_tool(world_position: Vector3) -> void:
	var cell := Vector2i(roundi(world_position.x), roundi(world_position.z))
	if active_tool.begins_with("terrain_"):
		_terrain_surface.queue_height_brush(world_position, brush_radius, brush_strength, active_tool.trim_prefix("terrain_"))
	elif active_tool.begins_with("paint_"):
		_terrain_surface.queue_texture_brush(world_position, brush_radius, brush_strength, int(active_tool.trim_prefix("paint_")))
	elif active_tool == "water_add" or active_tool == "water_remove":
		var active_water_level := _current_water_brush_level(world_position.y) if active_tool == "water_add" else water_level
		_water_surface.queue_brush(world_position, brush_radius, active_tool == "water_remove", active_water_level)
	elif active_tool == "simple_grass":
		_paint_simple_grass(world_position)
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

func _on_terrain_height_edit_finished() -> void:
	# Rebuilding every placed scene after each sculpt stroke is prohibitively
	# expensive on large maps. Newly painted content still snaps to terrain.
	_update_selection_ui()


func _paint_simple_grass(center: Vector3) -> void:
	var requested := clampi(roundi(PI * brush_radius * brush_radius * object_density * 5.0), 1, 600)
	for index: int in range(requested):
		var angle := randf() * TAU
		var distance := sqrt(randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if x < 0.0 or z < 0.0 or x >= float(map_size.x) or z >= float(map_size.y):
			continue
		var normal := _terrain_surface.get_surface_normal(x, z)
		grass_entries.append({"x": x, "z": z, "rotation": randf_range(0.0, 360.0), "scale": randf_range(0.78, 1.22), "stroke_id": _active_grass_stroke_id, "color": grass_color.to_html(false), "normal_x": normal.x, "normal_y": normal.y, "normal_z": normal.z})
	_rebuild_grass()


func _scatter_objects(center: Vector3) -> void:
	if not ASSETS.has(active_tool):
		return
	_ensure_object_spatial_index()
	var obstacle := active_tool.begins_with("purple_tree_") or active_tool.begins_with("tree_real_") or active_tool.begins_with("premium_tree_") or active_tool == "large_tree"
	var effective_density := clampf(object_density, 0.0, 1.0)
	var maximum := 120 if obstacle else 240
	# Density is a normalized fill control, not objects-per-square-metre.
	# A huge brush at low density must still scatter only a handful of assets.
	var brush_capacity := clampi(roundi(PI * brush_radius * brush_radius / 64.0), 1, maximum)
	var density_curve := pow(effective_density, 1.6)
	var requested := clampi(roundi(lerpf(1.0, float(brush_capacity), density_curve)), 1, maximum)
	var added := 0
	for index: int in range(maxi(requested * 8, 24)):
		if added >= requested:
			break
		var angle := randf() * TAU
		var distance := sqrt(randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if x < 0.0 or z < 0.0 or x >= float(map_size.x) or z >= float(map_size.y):
			continue
		var density_spacing := sqrt(1.0 / maxf(effective_density, 0.001)) * (0.32 if obstacle else 0.18)
		var minimum_distance := clampf(density_spacing, 0.55 if obstacle else 0.22, 12.0 if obstacle else 4.0)
		if _has_nearby_object(active_tool, Vector2(x, z), minimum_distance):
			continue
		# Reciprocal bounds avoid biasing random sizes toward tiny objects:
		# randomness 1.0 produces a visible, balanced range from 0.33× to 3×.
		var scale_spread := 1.0 + object_scale_randomness * 2.0
		var randomized_scale := exp(randf_range(-log(scale_spread), log(scale_spread)))
		var randomized_rotation := randf_range(-180.0, 180.0) * object_rotation_randomness
		var surface_normal := _terrain_surface.get_surface_normal(x, z)
		objects.append({
			"type": active_tool,
			"x": x,
			"z": z,
			"rotation": randomized_rotation,
			"scale": maxf(0.2, randomized_scale),
			"height_scale": object_height_scale,
			"color": premium_tree_color.to_html(false) if active_tool.begins_with("premium_tree_") else "ffffff",
			"height_offset": 0.0,
			"normal_x": surface_normal.x,
			"normal_y": surface_normal.y,
			"normal_z": surface_normal.z,
			"flipped": randf() < 0.5,
		})
		_index_object_position(active_tool, Vector2(x, z))
		_object_spatial_index_count = objects.size()
		added += 1
	_selected_object_index = objects.size() - 1 if added > 0 else -1
	_object_rebuild_pending = _object_rebuild_pending or added > 0
	if not _painting_objects:
		_flush_object_rebuild()

func _ensure_object_spatial_index() -> void:
	if _object_spatial_index_count == objects.size():
		return
	_object_spatial_index.clear()
	for data: Dictionary in objects:
		var kind := str(data.get("type", ""))
		var position := Vector2(float(data.get("x", 0.0)), float(data.get("z", 0.0)))
		_index_object_position(kind, position)
	_object_spatial_index_count = objects.size()


func _index_object_position(kind: String, position: Vector2) -> void:
	var cell := Vector2i(floori(position.x / OBJECT_SPATIAL_CELL_SIZE), floori(position.y / OBJECT_SPATIAL_CELL_SIZE))
	var key := "%s|%d|%d" % [kind, cell.x, cell.y]
	if not _object_spatial_index.has(key):
		_object_spatial_index[key] = []
	_object_spatial_index[key].append(position)


func _has_nearby_object(kind: String, target_position: Vector2, minimum_distance: float) -> bool:
	var center_cell := Vector2i(floori(target_position.x / OBJECT_SPATIAL_CELL_SIZE), floori(target_position.y / OBJECT_SPATIAL_CELL_SIZE))
	var cell_radius := ceili(minimum_distance / OBJECT_SPATIAL_CELL_SIZE)
	var minimum_distance_squared := minimum_distance * minimum_distance
	for offset_y: int in range(-cell_radius, cell_radius + 1):
		for offset_x: int in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(offset_x, offset_y)
			var key := "%s|%d|%d" % [kind, cell.x, cell.y]
			if not _object_spatial_index.has(key):
				continue
			for existing: Vector2 in _object_spatial_index[key]:
				if existing.distance_squared_to(target_position) < minimum_distance_squared:
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

func _flush_object_rebuild() -> void:
	if not _object_rebuild_pending:
		return
	_object_rebuild_pending = false
	_rebuild_objects()
	_update_selection_ui()

func _rebuild_objects() -> void:
	if _object_renderer == null:
		return
	_object_renderer.rebuild(objects)
	_rebuild_grass()


func _rebuild_grass() -> void:
	if _grass_layer == null:
		return
	_grass_layer.call("rebuild", grass_entries, Callable(self, "terrain_height"), grass_width, grass_height)

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

func _load_arena_test_preset() -> void:
	map_size_multiplier = 1
	map_size = SMALL_MAP_SIZE
	_terrain_surface.set_map_size_multiplier(1)
	_water_surface.set_map_size(map_size)
	_update_status("Wczytywanie Areny (test)...")
	objects.clear()
	player_spawns = [{"x": 78, "z": 10}, {"x": 81, "z": 10}]
	enemy_spawns = [{"x": 78, "z": 180}, {"x": 81, "z": 180}]
	_terrain_surface.reset_blank()
	_terrain_surface.import_height_sampler(_arena_test_height)
	var water_cells: Array[Dictionary] = []
	for x: int in range(ARENA_TEST_RECT.position.x + 1, ARENA_TEST_RECT.end.x - 1):
		var river_center: float = ARENA_TEST_LANDSCAPE.river_z(ARENA_TEST_RECT, float(x))
		for z: int in range(floori(river_center - ARENA_TEST_LANDSCAPE.RIVER_HALF_WIDTH), ceili(river_center + ARENA_TEST_LANDSCAPE.RIVER_HALF_WIDTH) + 1):
			if ARENA_TEST_LANDSCAPE.is_water(ARENA_TEST_RECT, float(x), float(z)):
				water_cells.append({"x": x, "z": z})
	_water_surface.load_cells(water_cells)

	var rng := RandomNumberGenerator.new()
	rng.seed = 71_409_233
	for index: int in range(42):
		var point := _arena_random_natural_point(rng, 7.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("large_tree" if index % 2 == 0 else "tree_real_1", point, rng, rng.randf_range(0.82, 1.22)))
	for index: int in range(96):
		var point := _arena_random_natural_point(rng, 4.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("bush_heather" if index % 3 == 0 else "bush", point, rng, rng.randf_range(0.72, 1.18)))
	for index: int in range(180):
		var point := _arena_random_natural_point(rng, 3.0)
		if point != Vector2.INF:
			objects.append(_arena_editor_object("grass_1" if index % 2 == 0 else "grass_2", point, rng, rng.randf_range(0.72, 1.34)))
	var arena_center := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * 0.5
	objects.append({"type": "arena_bridge", "x": arena_center.x, "z": arena_center.y, "rotation": 0.0, "scale": 1.0, "height_offset": 0.20, "flipped": false})
	for ridge_index: int in range(32):
		var ridge_side := -1.0 if ridge_index < 16 else 1.0
		var ridge_point := arena_center + Vector2(ridge_side * rng.randf_range(24.0, 36.0), ridge_side * rng.randf_range(34.0, 54.0))
		objects.append(_arena_editor_object("arena_rock", ridge_point, rng, rng.randf_range(1.2, 3.4)))

	# Recreate editable soil islands and the route leading exactly into the bridge.
	var soil_ratios: Array[Vector2] = [
		Vector2(0.20, 0.32), Vector2(0.80, 0.28), Vector2(0.50, 0.22),
		Vector2(0.47, 0.68), Vector2(0.32, 0.50), Vector2(0.68, 0.55),
		Vector2(0.12, 0.60), Vector2(0.88, 0.45), Vector2(0.18, 0.76),
		Vector2(0.74, 0.78), Vector2(0.84, 0.63), Vector2(0.39, 0.27),
		Vector2(0.61, 0.31), Vector2(0.24, 0.44), Vector2(0.56, 0.47),
		Vector2(0.42, 0.57), Vector2(0.79, 0.58), Vector2(0.58, 0.72)
	]
	for ratio: Vector2 in soil_ratios:
		var soil_point := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * ratio
		_terrain_surface.paint_texture(Vector3(soil_point.x, _arena_test_height(soil_point.x, soil_point.y), soil_point.y), 9.0, 1.35, 4)
		objects.append({"type": "arena_soil", "x": soil_point.x, "z": soil_point.y, "rotation": rng.randf_range(0.0, 360.0), "scale": rng.randf_range(4.0, 6.5), "height_offset": 0.08, "flipped": false})
	for z: int in range(ARENA_TEST_RECT.position.y + 4, ARENA_TEST_RECT.end.y - 4, 6):
		var path_x := _arena_editor_path_x(float(z))
		_terrain_surface.paint_texture(Vector3(path_x, _arena_test_height(path_x, float(z)), float(z)), 4.2, 1.0, 3)
		objects.append({"type": "arena_soil", "x": path_x, "z": float(z), "rotation": 0.0, "scale": 2.7, "height_offset": 0.09, "flipped": false})
	_selected_object_index = -1
	_rebuild_objects()
	_update_markers()
	_reposition_scene_content()
	map_name = "arena_test_edycja"
	_update_status("Arena (test) wczytana — teren, woda i %d obiektow sa edytowalne" % objects.size())


func _arena_test_height(x: float, z: float) -> float:
	if not Rect2(ARENA_TEST_RECT).has_point(Vector2(x, z)):
		return 0.0
	return ARENA_TEST_LANDSCAPE.sample_height(ARENA_TEST_RECT, x, z)


func _arena_editor_path_x(z: float) -> float:
	var delta := z - 95.0
	var bridge_clearance := smoothstep(8.0, 18.0, absf(delta))
	return 80.0 + bridge_clearance * (sin(delta * 0.041) * 7.2 + sin(delta * 0.093) * 2.4)


func _arena_random_natural_point(rng: RandomNumberGenerator, margin: float) -> Vector2:
	for attempt: int in range(32):
		var point := Vector2(
			rng.randf_range(float(ARENA_TEST_RECT.position.x) + margin, float(ARENA_TEST_RECT.end.x) - margin),
			rng.randf_range(float(ARENA_TEST_RECT.position.y) + margin, float(ARENA_TEST_RECT.end.y) - margin)
		)
		var center := Vector2(ARENA_TEST_RECT.position) + Vector2(ARENA_TEST_RECT.size) * 0.5
		if ARENA_TEST_LANDSCAPE.is_water(ARENA_TEST_RECT, point.x, point.y):
			continue
		if absf(point.x - center.x) < 8.0 or absf(point.x - (center.x + ARENA_TEST_LANDSCAPE.FORD_X_OFFSET)) < 9.0:
			continue
		return point
	return Vector2.INF


func _arena_editor_object(kind: String, point: Vector2, rng: RandomNumberGenerator, scale_value: float) -> Dictionary:
	return {
		"type": kind,
		"x": point.x,
		"z": point.y,
		"rotation": rng.randf_range(0.0, 360.0),
		"scale": scale_value,
		"height_offset": 0.0,
		"flipped": rng.randf() < 0.5,
	}


func _clear_map() -> void:
	objects.clear()
	grass_entries.clear()
	_undo_stack.clear()
	player_spawns.clear()
	enemy_spawns.clear()
	_selected_object_index = -1
	_terrain_surface.set_map_size_multiplier(map_size_multiplier)
	_terrain_surface.reset_blank()
	_frame_map_camera()
	_water_surface.set_map_size(map_size)
	_water_surface.clear()
	_waterways_rivers.clear()
	_rebuild_objects()
	_update_markers()
	_update_selection_ui()
	_update_status("Utworzono pustą mapę Terrain3D")

func _save() -> void:
	if _terrain_surface.is_height_brush_busy() or _terrain_surface.is_texture_brush_busy() or _water_surface.is_brush_busy():
		_update_status("Kończenie edycji przed zapisem...")
		while _terrain_surface.is_height_brush_busy() or _terrain_surface.is_texture_brush_busy() or _water_surface.is_brush_busy():
			await get_tree().process_frame
	var safe_name := map_name.to_lower().replace(" ", "_")
	var terrain_directory := "user://maps/terrain/" + safe_name
	_terrain_surface.save_to_directory(terrain_directory)
	var path: String = get_node("/root/MapCatalog").save_map({
		"version": 5,
		"name": map_name,
		"map_size_multiplier": map_size_multiplier,
		"map_size": {"x": map_size.x, "y": map_size.y},
		"objects": objects,
		"grass": grass_entries,
		"grass_width": grass_width,
		"grass_height": grass_height,
		"grass_color": grass_color.to_html(false),
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns,
		"terrain_directory": terrain_directory,
		"water_cells": _water_surface.serialize_cells(),
		"rivers": _waterways_rivers.serialize_rivers(),
	})
	_update_status("Zapisano: " + path)

func _create_new_map() -> void:
	var index: int = %NewMapSizeOption.selected
	map_size_multiplier = MAP_SIZE_MULTIPLIERS[index]
	map_size = SMALL_MAP_SIZE * map_size_multiplier
	map_name = "nowa_mapa_%d" % Time.get_unix_time_from_system()
	_clear_map()
	var size_name: String = %NewMapSizeOption.get_item_text(index)
	_update_status("Utworzono: %s mapa — %d × %d m" % [size_name, map_size.x, map_size.y])

func _update_brush_label() -> void:
	if ASSETS.has(active_tool):
		_brush_label.text = "ASSET: %s\nPromień %.1f m | gęstość %.3f | wysokość %.2f× | los. skali %.0f%% | los. obrotu %.0f%%" % [active_tool, brush_radius, object_density, object_height_scale, object_scale_randomness * 100.0, object_rotation_randomness * 100.0]
	elif active_tool == "simple_grass":
		_brush_label.text = "TRAWA | promień %.1f m | gęstość %.3f\nszer. %.2f | wys. %.2f | kolor dla nowego pociągnięcia" % [brush_radius, object_density, grass_width, grass_height]
	elif active_tool.begins_with("water_"):
		_brush_label.text = "WODA | promień %.1f m | poziom Y %.2f" % [brush_radius, water_level]
	else:
		_brush_label.text = "PĘDZEL %.1f m | siła %.2f | gęstość %.3f" % [brush_radius, brush_strength, object_density]

func _update_status(message: String) -> void:
	%StatusLabel.text = message + "\nLPM: maluj | PPM/MMB: przesuń | Shift+Tab: ustaw ducha | Tab: FPP"
