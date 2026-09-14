@tool
extends Control

const STAGING_PATH    := "res://imported_models"
const CHARACTERS_PATH := "res://assets/characters"
const DATA_PATH       := "res://data/characters"

# Meshy filename → animation type mapping (lowercase matching)
const PATTERNS: Array = [
	["character_output", "model"],
	["animation_walking", "walk"],
	["animation_running", "run"],
	["animation_attack",  "attack"],
	["animation_idle",    "idle"],
	["animation_death",   "death"],
	["animation_dying",   "death"],
	["animation_hit",     "hurt"],
	["animation_hurt",    "hurt"],
	["animation_unsteady","hurt"],
	["unsteady_walk",     "hurt"],
	["alert",             "idle"],
]

var _name_field:    LineEdit
var _status_label:  Label
var _file_list:     ItemList
var _import_button: Button
var _detected:      Dictionary = {}  # anim_type -> source res:// path

func _init() -> void:
	name = "Character Importer"

func _ready() -> void:
	_build_ui()
	call_deferred("_scan")

func _build_ui() -> void:
	set_custom_minimum_size(Vector2(180, 0))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := Label.new()
	title.text = "Character Importer"
	title.add_theme_font_size_override("font_size", 13)
	root.add_child(title)

	root.add_child(HSeparator.new())

	var refresh_btn := Button.new()
	refresh_btn.text = "Odśwież"
	refresh_btn.pressed.connect(_scan)
	root.add_child(refresh_btn)

	_status_label = Label.new()
	_status_label.text = "Brak plików"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	root.add_child(_status_label)

	var list_lbl := Label.new()
	list_lbl.text = "Wykryte animacje:"
	root.add_child(list_lbl)

	_file_list = ItemList.new()
	_file_list.custom_minimum_size = Vector2(0, 140)
	_file_list.auto_height = false
	root.add_child(_file_list)

	var name_lbl := Label.new()
	name_lbl.text = "Nazwa postaci:"
	root.add_child(name_lbl)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "np. rogue"
	root.add_child(_name_field)

	_import_button = Button.new()
	_import_button.text = "⬇ Import Character"
	_import_button.disabled = true
	_import_button.pressed.connect(_do_import)
	root.add_child(_import_button)

# ── Scan ─────────────────────────────────────────────────────────────────────

func _scan() -> void:
	_detected.clear()
	_file_list.clear()

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(STAGING_PATH)):
		_status_label.text = "imported_models/ jest pusty"
		_import_button.disabled = true
		return

	var glbs := _find_glbs(STAGING_PATH)
	if glbs.is_empty():
		_status_label.text = "Brak GLB w imported_models/"
		_import_button.disabled = true
		return

	for path in glbs:
		var anim_type := _detect_type(path.get_file().to_lower())
		if anim_type == "":
			continue
		if not _detected.has(anim_type):
			_detected[anim_type] = path
			_file_list.add_item("%-8s  %s" % [anim_type, path.get_file()])

	_status_label.text = "Wykryto %d plików" % _detected.size()
	_import_button.disabled = _detected.is_empty()

func _find_glbs(res_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(res_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full := res_path + "/" + entry
			if dir.current_is_dir():
				result.append_array(_find_glbs(full))
			elif entry.ends_with(".glb"):
				result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return result

func _detect_type(filename: String) -> String:
	for pair in PATTERNS:
		if pair[0] in filename:
			return pair[1]
	return ""

# ── Import ────────────────────────────────────────────────────────────────────

func _do_import() -> void:
	var char_name := _name_field.text.strip_edges().to_lower().replace(" ", "_")
	if char_name == "":
		_status_label.text = "⚠ Wpisz nazwę postaci!"
		return

	var target_dir := CHARACTERS_PATH + "/" + char_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_PATH))

	# Copy files
	var copied: Dictionary = {}  # anim_type -> res:// destination path
	for anim_type in _detected:
		var src: String = _detected[anim_type]
		var dst_name: String = char_name + ".glb" if anim_type == "model" else char_name + "_" + anim_type + ".glb"
		var dst: String = target_dir + "/" + dst_name
		if _copy_res_file(src, dst) == OK:
			copied[anim_type] = dst

	# Create .tres
	_write_tres(char_name, copied)

	# Cleanup staging
	_remove_dir_recursive(ProjectSettings.globalize_path(STAGING_PATH))

	# Trigger Godot reimport
	EditorInterface.get_resource_filesystem().scan()

	_status_label.text = "✓ Gotowe! %s (%d plików)" % [char_name, copied.size()]
	_name_field.text = ""
	_detected.clear()
	_file_list.clear()
	_import_button.disabled = true

func _copy_res_file(src_res: String, dst_res: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(src_res)
	if bytes.is_empty() and not FileAccess.file_exists(src_res):
		push_warning("CharacterImporter: cannot read %s" % src_res)
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(dst_res, FileAccess.WRITE)
	if f == null:
		push_warning("CharacterImporter: cannot write %s" % dst_res)
		return FileAccess.get_open_error()
	f.store_buffer(bytes)
	return OK

func _remove_dir_recursive(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full := abs_path + "/" + entry
			if dir.current_is_dir():
				_remove_dir_recursive(full)
				DirAccess.remove_absolute(full)
			else:
				DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)

# ── .tres writer ──────────────────────────────────────────────────────────────

func _write_tres(char_name: String, files: Dictionary) -> void:
	var tres_path := DATA_PATH + "/" + char_name + ".tres"
	var tres_abs  := ProjectSettings.globalize_path(tres_path)

	var load_steps := 2 + files.size() + 1  # script + unit.tscn + GLBs + resource
	var lines := PackedStringArray()
	lines.append('[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=%d format=3]' % load_steps)
	lines.append("")
	lines.append('[ext_resource type="Script" path="res://scripts/data/character_definition.gd" id="1_def"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/units/unit.tscn" id="2_scene"]')

	var id := 3
	var ids: Dictionary = {}
	for anim_type in ["model", "idle", "walk", "run", "attack", "hurt", "death"]:
		if files.has(anim_type):
			ids[anim_type] = "%d_%s" % [id, anim_type]
			lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % [files[anim_type], ids[anim_type]])
			id += 1

	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("1_def")')
	lines.append('character_id = &"%s"' % char_name)
	lines.append('display_name = "%s"' % char_name.replace("_", " ").capitalize())
	lines.append('description = ""')
	lines.append('role_name = ""')
	lines.append("team_slot_cost = 1")
	lines.append("max_health = 12")
	lines.append("max_action_points = 6")
	lines.append("initiative = 10")
	lines.append("movement_range = 6")
	lines.append('scene = ExtResource("2_scene")')

	for pair in [["model", "visual_scene"], ["idle", "idle_animation_scene"],
				 ["walk", "walk_animation_scene"], ["run", "run_animation_scene"],
				 ["attack", "attack_animation_scene"], ["hurt", "hurt_animation_scene"]]:
		if ids.has(pair[0]):
			lines.append('%s = ExtResource("%s")' % [pair[1], ids[pair[0]]])

	lines.append("visual_scale = 1.0")
	lines.append("visual_rotation_degrees = Vector3(0, 180, 0)")
	lines.append("")

	var f := FileAccess.open(tres_abs, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
