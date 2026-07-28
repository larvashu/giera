class_name WorldEditor
extends Control

const BIOME_COLORS := {"forest": Color("315b35"), "meadow": Color("669451"), "desert": Color("c59a57"), "rocky": Color("6d6b68"), "swamp": Color("385750")}
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
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18); root.add_theme_constant_override("separation", 12); add_child(root)
	var title := Label.new(); title.text = "EDYTOR SWIATA — 50 STREAMOWANYCH REGIONOW"; title.add_theme_font_size_override("font_size", 28); root.add_child(title)
	info = Label.new(); root.add_child(info)
	var toolbar := HBoxContainer.new(); root.add_child(toolbar)
	for data in [["←", Vector2i(-1,0)], ["→", Vector2i(1,0)], ["↑", Vector2i(0,-1)], ["↓", Vector2i(0,1)]]:
		var button := Button.new(); button.text = data[0]; button.custom_minimum_size = Vector2(54,42); button.pressed.connect(_move_selected.bind(data[1])); toolbar.add_child(button)
	var biome_button := Button.new(); biome_button.text = "Zmien biom"; biome_button.pressed.connect(_cycle_biome); toolbar.add_child(biome_button)
	var save := Button.new(); save.text = "Zapisz swiat"; save.pressed.connect(_save); toolbar.add_child(save)
	var explore := Button.new(); explore.text = "Testuj eksploracje"; explore.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world/exploration_world.tscn")); toolbar.add_child(explore)
	var back := Button.new(); back.text = "Menu"; back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")); toolbar.add_child(back)
	grid = GridContainer.new(); grid.columns = 10; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(grid)
	for index in 50:
		var card := Button.new(); card.custom_minimum_size = Vector2(150, 105); card.pressed.connect(_select.bind(index)); grid.add_child(card); cards.append(card)

func _refresh() -> void:
	var regions: Array = world.get("regions", [])
	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z) or (int(a.z) == int(b.z) and int(a.x) < int(b.x)))
	for index in mini(cards.size(), regions.size()):
		var region := regions[index] as Dictionary
		var card := cards[index]
		card.text = "%s\n[%d, %d]\n%s" % [region.get("name", "Region"), region.get("x",0), region.get("z",0), region.get("biome","")]
		card.modulate = BIOME_COLORS.get(String(region.get("biome", "forest")), Color.WHITE)
		card.button_pressed = index == selected_index
	info.text = "Kliknij region, przesuwaj strzalkami (zamiana miejsc) lub zmieniaj biom. Aktywny: %d" % [selected_index + 1]

func _select(index: int) -> void:
	selected_index = index
	_refresh()

func _move_selected(delta: Vector2i) -> void:
	var regions: Array = world.get("regions", [])
	var selected := regions[selected_index] as Dictionary
	var target_x := int(selected.x) + delta.x
	var target_z := int(selected.z) + delta.y
	for other_value: Variant in regions:
		var other := other_value as Dictionary
		if int(other.x) == target_x and int(other.z) == target_z:
			other.x = selected.x; other.z = selected.z
			selected.x = target_x; selected.z = target_z
			_refresh(); return

func _cycle_biome() -> void:
	var region := (world.get("regions", []) as Array)[selected_index] as Dictionary
	var current := ExplorationWorldCatalog.BIOMES.find(String(region.get("biome", "forest")))
	region.biome = ExplorationWorldCatalog.BIOMES[(current + 1) % ExplorationWorldCatalog.BIOMES.size()]
	_refresh()

func _save() -> void:
	info.text = "Swiat zapisany." if ExplorationWorldCatalog.save_world(world) else "Blad zapisu swiata."
