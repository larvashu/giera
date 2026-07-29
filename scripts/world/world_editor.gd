class_name WorldEditor
extends Control

var world: Dictionary
var selected_index := 0
var grid: GridContainer
var info: Label
var cards: Array[Button] = []

func _ready() -> void:
	world = ExplorationWorldCatalog.load_world()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new(); background.color = Color("101820"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18); root.add_theme_constant_override("separation", 10); add_child(root)
	var title := Label.new(); title.text = "EDYTOR SWIATA DZIKIEJ POLANY — 4 WARSTWY / 49 PLANSZ"; title.add_theme_font_size_override("font_size", 26); root.add_child(title)
	info = Label.new(); root.add_child(info)
	var toolbar := HBoxContainer.new(); root.add_child(toolbar)
	for data in [["←",Vector2i(-1,0)],["→",Vector2i(1,0)],["↑",Vector2i(0,-1)],["↓",Vector2i(0,1)]]:
		var button := Button.new(); button.text = data[0]; button.custom_minimum_size = Vector2(54,40); button.pressed.connect(_move_selected.bind(data[1])); toolbar.add_child(button)
	var save := Button.new(); save.text = "Zapisz uklad"; save.pressed.connect(_save); toolbar.add_child(save)
	var explore := Button.new(); explore.text = "Eksploruj"; explore.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world/exploration_world.tscn")); toolbar.add_child(explore)
	var reset := Button.new(); reset.text = "Przywroc 4 warstwy"; reset.pressed.connect(_reset); toolbar.add_child(reset)
	var back := Button.new(); back.text = "Menu"; back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")); toolbar.add_child(back)
	grid = GridContainer.new(); grid.columns = 7; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(grid)
	for index in ExplorationWorldCatalog.REGION_COUNT:
		var card := Button.new(); card.custom_minimum_size = Vector2(190,105); card.toggle_mode = true; card.pressed.connect(_select.bind(index)); grid.add_child(card); cards.append(card)

func _sorted_regions() -> Array:
	var regions: Array = world.get("regions", [])
	regions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.z)<int(b.z) or (int(a.z)==int(b.z) and int(a.x)<int(b.x)))
	return regions

func _refresh() -> void:
	var regions := _sorted_regions()
	for index in mini(cards.size(),regions.size()):
		var region := regions[index] as Dictionary; var layer := int(region.get("layer",1)); var card := cards[index]
		card.text = "%s\nwarstwa %d  [%d,%d]" % [region.get("name","Dzika Polana"),layer,region.get("x",0),region.get("z",0)]
		card.modulate = [Color.WHITE,Color("8ecf76"),Color("72ad68"),Color("588b5c"),Color("426c51")][layer]
		card.button_pressed = index == selected_index
	info.text = "Warstwa 1: 1 plansza | warstwa 2: 8 | warstwa 3: 16 | warstwa 4: 24 | aktywna: %d" % [selected_index+1]

func _select(index: int) -> void: selected_index=index; _refresh()

func _move_selected(delta: Vector2i) -> void:
	var regions := _sorted_regions(); var selected := regions[selected_index] as Dictionary
	var target := Vector2i(int(selected.x),int(selected.z))+delta
	for value: Variant in regions:
		var other := value as Dictionary
		if Vector2i(int(other.x),int(other.z)) == target:
			var old := Vector2i(int(selected.x),int(selected.z)); selected.x=target.x; selected.z=target.y; other.x=old.x; other.z=old.y
			selected.layer=maxi(abs(int(selected.x)),abs(int(selected.z)))+1; other.layer=maxi(abs(int(other.x)),abs(int(other.z)))+1; _refresh(); return

func _save() -> void: info.text = "Uklad 49 plansz zapisany." if ExplorationWorldCatalog.save_world(world) else "Blad zapisu."
func _reset() -> void: world=ExplorationWorldCatalog.create_default_world(); ExplorationWorldCatalog.save_world(world); selected_index=24; _refresh()
