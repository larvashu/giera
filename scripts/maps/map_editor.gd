extends Control
const GRID_SIZE := Vector2i(160, 190)
const TOOLS := ["purple_tree_1","purple_tree_2","purple_tree_3","large_tree","bush","grass_1","grass_2","erase","player_spawn","enemy_spawn"]
var objects: Array[Dictionary] = []
var player_spawns: Array[Dictionary] = [{"x":78,"z":9},{"x":81,"z":9}]
var enemy_spawns: Array[Dictionary] = [{"x":78,"z":180},{"x":81,"z":180}]
var active_tool := "purple_tree_1"
@onready var canvas: Control = %MapCanvas
func _ready() -> void:
	for label: String in ["Drzewo I","Drzewo II","Drzewo III","Wielkie drzewo","Krzak","Trawa I","Trawa II","Gumka","Start P1","Start P2"]: %ToolOption.add_item(label)
	%ToolOption.item_selected.connect(func(i: int) -> void: active_tool = TOOLS[i])
	canvas.gui_input.connect(_canvas_input)
	canvas.draw.connect(_draw_map)
	%SaveButton.pressed.connect(_save)
	%ClearButton.pressed.connect(func() -> void: objects.clear(); canvas.queue_redraw())
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var scale_value := minf(canvas.size.x / GRID_SIZE.x, canvas.size.y / GRID_SIZE.y)
		var offset := (canvas.size - Vector2(GRID_SIZE) * scale_value) * 0.5
		var cell := Vector2i((event.position - offset) / scale_value)
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y: return
		_apply_tool(cell)
		canvas.queue_redraw()
func _apply_tool(cell: Vector2i) -> void:
	if active_tool == "erase":
		for i: int in range(objects.size()-1,-1,-1):
			if int(objects[i].x)==cell.x and int(objects[i].z)==cell.y: objects.remove_at(i)
	elif active_tool == "player_spawn": _set_spawn(player_spawns,cell)
	elif active_tool == "enemy_spawn": _set_spawn(enemy_spawns,cell)
	else: objects.append({"type":active_tool,"x":cell.x,"z":cell.y,"rotation":randf_range(0.0,360.0),"scale":1.0})
	%StatusLabel.text = "Obiektow: %d" % objects.size()
func _set_spawn(spawns: Array[Dictionary], cell: Vector2i) -> void:
	spawns.pop_front(); spawns.append({"x":cell.x,"z":cell.y})
func _draw_map() -> void:
	var s := minf(canvas.size.x/GRID_SIZE.x,canvas.size.y/GRID_SIZE.y)
	var o := (canvas.size-Vector2(GRID_SIZE)*s)*0.5
	canvas.draw_rect(Rect2(o,Vector2(GRID_SIZE)*s),Color(0.08,0.19,0.09),true)
	for data: Dictionary in objects:
		var c := Color(0.35,0.75,0.25)
		if str(data.type).contains("tree"): c=Color(0.45,0.18,0.58)
		canvas.draw_circle(o+(Vector2(float(data.x),float(data.z))+Vector2(0.5,0.5))*s,maxf(2.0,s*1.4),c)
	for spawn: Dictionary in player_spawns: canvas.draw_circle(o+(Vector2(float(spawn.x),float(spawn.z))+Vector2(0.5,0.5))*s,5.0,Color.CYAN)
	for spawn: Dictionary in enemy_spawns: canvas.draw_circle(o+(Vector2(float(spawn.x),float(spawn.z))+Vector2(0.5,0.5))*s,5.0,Color.ORANGE_RED)
func _save() -> void:
	var map_name: String = str(%NameEdit.text).strip_edges()
	if map_name.is_empty(): %StatusLabel.text="Podaj nazwe mapy."; return
	var path: String = get_node("/root/MapCatalog").save_map({"version":1,"name":map_name,"objects":objects,"player_spawns":player_spawns,"enemy_spawns":enemy_spawns})
	%StatusLabel.text = "Zapisano: "+path
