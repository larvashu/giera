class_name ArenaSetup
extends Control

# ── Player identity ────────────────────────────────────────────────────────
const PLAYER_LABELS := ["PLAYER ONE", "PLAYER TWO", "PLAYER THREE", "PLAYER FOUR"]
const PLAYER_ACCENTS: Array[Color] = [
	Color(0.792, 0.333, 0.318),  # P1 red
	Color(0.706, 0.475, 0.0),    # P2 gold
	Color(0.0,   0.6,   0.639),  # P3 teal
	Color(0.584, 0.396, 0.78),   # P4 violet
]
const PICKED_BGS: Array[Color] = [
	Color(0.2,   0.082, 0.075),
	Color(0.169, 0.11,  0.0),
	Color(0.0,   0.149, 0.153),
	Color(0.145, 0.098, 0.196),
]

# ── Design tokens ──────────────────────────────────────────────────────────
const C_PANEL     := Color(0.094, 0.059, 0.051)
const C_BORDER    := Color(0.231, 0.157, 0.133)
const C_BORDER_U  := Color(0.251, 0.18,  0.153)  # unselected card border
const C_DIVIDER   := Color(0.196, 0.149, 0.129)
const C_GOLD      := Color(0.706, 0.475, 0.0)
const C_GOLD_H    := Color(0.808, 0.573, 0.0)
const C_TEXT      := Color(0.918, 0.89,  0.871)
const C_MUTED     := Color(0.604, 0.549, 0.522)
const C_DIM       := Color(0.427, 0.376, 0.349)
const C_ON_GOLD   := Color(0.047, 0.031, 0.024)
const C_BEGIN_OFF := Color(0.137, 0.094, 0.078)
const C_ICON_BG   := Color(0.145, 0.11,  0.094)

# ── Autoloads ──────────────────────────────────────────────────────────────
@onready var save_manager := get_node("/root/TeamSaveManager") as TeamSaveService
@onready var game_session := get_node("/root/GameSession") as GameSessionState

# ── State ──────────────────────────────────────────────────────────────────
var _step: int = 0  # 0=setup  1=draft  2=confirm
var _player_count: int = 2
var _champ_count: int = 2
var _arena_size_idx: int = 1  # 0=Kwadrat 1=Normalna 2=Duza 3=BardzoD.
var _picks: Array = []   # _picks[pi][si] = StringName or null
var _readies: Array = []
var _chars: Array[CharacterDefinition] = []

# ── Screen roots ───────────────────────────────────────────────────────────
var _screen_setup: Control
var _screen_draft: Control
var _screen_confirm: Control

# ── Setup screen refs ──────────────────────────────────────────────────────
var _player_cards: Array[Control] = []
var _player_num_lbls: Array[Label] = []
var _champ_cards: Array[Control] = []
var _champ_num_lbls: Array[Label] = []
var _size_cards: Array[Control] = []

# ── Draft screen refs ──────────────────────────────────────────────────────
var _summary_lbl: Label
var _panels_box: HBoxContainer
var _slot_ctrls: Array = []   # [pi][si] -> Control
var _class_rows: Array = []   # [pi][ci] -> Control
var _ready_btns: Array[Button] = []
var _begin_btn: Button

# ── Confirm screen refs ────────────────────────────────────────────────────
var _roster_box: HBoxContainer


# ══════════════════════════════════════════════════════════════════════════
# ENTRY
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_chars()
	_reset_picks()
	_build_setup_screen()
	_build_draft_screen()
	_build_confirm_screen()
	_show_step(0)


func _load_chars() -> void:
	_chars.clear()
	for def: CharacterDefinition in save_manager.get_character_definitions():
		if not def.is_mob and def.character_id != &"bandit":
			_chars.append(def)


func _reset_picks() -> void:
	_picks.clear()
	_readies.clear()
	for _pi: int in _player_count:
		var row: Array = []
		row.resize(_champ_count)
		row.fill(null)
		_picks.append(row)
		_readies.append(false)


func _show_step(s: int) -> void:
	_step = s
	_screen_setup.visible  = (s == 0)
	_screen_draft.visible  = (s == 1)
	_screen_confirm.visible = (s == 2)


# ══════════════════════════════════════════════════════════════════════════
# SETUP SCREEN
# ══════════════════════════════════════════════════════════════════════════

func _build_setup_screen() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_screen_setup = center

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 48)
	center.add_child(vbox)

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var eyebrow := _lbl("FREE-FOR-ALL ARENA", 18, PLAYER_ACCENTS[0])
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(eyebrow)

	var title := _lbl("SET UP THE MATCH", 40, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	# Player count section
	var player_sec := VBoxContainer.new()
	player_sec.add_theme_constant_override("separation", 12)
	vbox.add_child(player_sec)

	var player_lbl := _lbl("NUMBER OF PLAYERS", 13, C_MUTED)
	player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_sec.add_child(player_lbl)

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 16)
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_sec.add_child(player_row)

	_player_cards.clear()
	_player_num_lbls.clear()
	for n: int in [1, 2, 3, 4]:
		var card := _make_selector_card(
			n, "PLAYER", "PLAYERS",
			func(v: int) -> void: _player_count = v; _update_selector_cards(_player_cards, _player_num_lbls, _player_count),
			_player_cards, _player_num_lbls
		)
		player_row.add_child(card)
	_update_selector_cards(_player_cards, _player_num_lbls, _player_count)

	# Champion count section
	var champ_sec := VBoxContainer.new()
	champ_sec.add_theme_constant_override("separation", 12)
	vbox.add_child(champ_sec)

	var champ_lbl := _lbl("CHAMPIONS PER PLAYER", 13, C_MUTED)
	champ_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ_sec.add_child(champ_lbl)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	champ_sec.add_child(cards_row)

	_champ_cards.clear()
	_champ_num_lbls.clear()
	for n: int in [1, 2, 3, 4]:
		var card := _make_selector_card(
			n, "CHAMPION", "CHAMPIONS",
			func(v: int) -> void: _champ_count = v; _update_selector_cards(_champ_cards, _champ_num_lbls, _champ_count),
			_champ_cards, _champ_num_lbls
		)
		cards_row.add_child(card)
	_update_selector_cards(_champ_cards, _champ_num_lbls, _champ_count)

	# Map size section
	var size_sec := VBoxContainer.new()
	size_sec.add_theme_constant_override("separation", 12)
	vbox.add_child(size_sec)

	var size_lbl := _lbl("MAP SIZE", 13, C_MUTED)
	size_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_sec.add_child(size_lbl)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 12)
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_sec.add_child(size_row)

	const SIZE_LABELS := ["SMALL", "NORMAL", "LARGE", "VERY\nLARGE"]
	_size_cards.clear()
	for si: int in SIZE_LABELS.size():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(100, 0)
		card.set_meta("n", si)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_arena_size_idx = si
				_update_size_cards()
		)
		var mg := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			mg.add_theme_constant_override("margin_" + side, 14)
		card.add_child(mg)
		var lbl := _lbl(SIZE_LABELS[si], 10, C_MUTED)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mg.add_child(lbl)
		_size_cards.append(card)
		size_row.add_child(card)
	_update_size_cards()

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.custom_minimum_size = Vector2(140, 54)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", C_MUTED)
	back_btn.add_theme_color_override("font_hover_color", C_TEXT)
	_flat_btn_style(back_btn)
	var sb_back := StyleBoxFlat.new()
	sb_back.bg_color = Color(0, 0, 0, 0)
	sb_back.border_color = C_BORDER
	sb_back.set_border_width_all(1)
	back_btn.add_theme_stylebox_override("normal", sb_back)
	back_btn.add_theme_stylebox_override("hover", sb_back)
	back_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	btn_row.add_child(back_btn)

	var cont := _gold_btn("CONTINUE")
	cont.custom_minimum_size = Vector2(280, 54)
	cont.pressed.connect(_on_continue)
	btn_row.add_child(cont)


func _make_selector_card(
	n: int,
	singular: String,
	plural: String,
	on_select: Callable,
	cards_arr: Array[Control],
	lbls_arr: Array[Label]
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 0)
	panel.set_meta("n", n)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_select.call(n)
	)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var num_lbl := _lbl(str(n), 34, C_MUTED)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(num_lbl)
	lbls_arr.append(num_lbl)

	var caption := _lbl(plural if n > 1 else singular, 9, C_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(caption)

	cards_arr.append(panel)
	return panel


func _update_size_cards() -> void:
	for card: Control in _size_cards:
		var si: int = card.get_meta("n")
		var sel := (si == _arena_size_idx)
		_panel_style(card, C_PANEL, C_GOLD if sel else C_BORDER_U)
		var lbl := card.get_child(0).get_child(0) as Label
		if lbl:
			lbl.add_theme_color_override("font_color", C_TEXT if sel else C_MUTED)

func _update_selector_cards(cards_arr: Array[Control], lbls_arr: Array[Label], selected: int) -> void:
	for i: int in cards_arr.size():
		var n: int = cards_arr[i].get_meta("n")
		var sel := (n == selected)
		_panel_style(cards_arr[i], C_PANEL, C_GOLD if sel else C_BORDER_U)
		lbls_arr[i].add_theme_color_override("font_color", C_TEXT if sel else C_MUTED)


func _on_continue() -> void:
	_reset_picks()
	_show_step(1)
	_rebuild_draft()


# ══════════════════════════════════════════════════════════════════════════
# DRAFT SCREEN
# ══════════════════════════════════════════════════════════════════════════

func _build_draft_screen() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	_screen_draft = vbox

	# ── Top bar ──────────────────────────────────────────────────────────
	var topbar := HBoxContainer.new()
	topbar.custom_minimum_size = Vector2(0, 80)
	topbar.add_theme_constant_override("separation", 0)
	vbox.add_child(topbar)

	var padding_l := MarginContainer.new()
	padding_l.add_theme_constant_override("margin_left", 32)
	padding_l.add_theme_constant_override("margin_right", 0)
	topbar.add_child(padding_l)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.flat = true
	back_btn.custom_minimum_size = Vector2(120, 0)
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_color_override("font_color", C_MUTED)
	back_btn.add_theme_color_override("font_hover_color", C_TEXT)
	_flat_btn_style(back_btn)
	back_btn.pressed.connect(_on_back_to_setup)
	padding_l.add_child(back_btn)

	var title := _lbl("DRAFT YOUR WARBAND", 26, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(title)

	_summary_lbl = _lbl("", 13, C_MUTED)
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary_lbl.custom_minimum_size = Vector2(160, 0)
	topbar.add_child(_summary_lbl)

	var padding_r := MarginContainer.new()
	padding_r.add_theme_constant_override("margin_right", 32)
	topbar.add_child(padding_r)

	# Rule
	var rule := ColorRect.new()
	rule.color = C_DIVIDER
	rule.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(rule)

	# Player panels area
	_panels_box = HBoxContainer.new()
	_panels_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panels_box.add_theme_constant_override("separation", 0)
	vbox.add_child(_panels_box)

	# Begin battle row
	var begin_center := CenterContainer.new()
	begin_center.custom_minimum_size = Vector2(0, 88)
	vbox.add_child(begin_center)

	_begin_btn = Button.new()
	_begin_btn.text = "BEGIN BATTLE"
	_begin_btn.custom_minimum_size = Vector2(400, 60)
	_begin_btn.add_theme_font_size_override("font_size", 16)
	_begin_btn.pressed.connect(_on_begin_battle)
	begin_center.add_child(_begin_btn)
	_style_begin_btn(false)


func _rebuild_draft() -> void:
	_summary_lbl.text = "%d PLAYERS · %d EACH" % [_player_count, _champ_count]

	for child: Node in _panels_box.get_children():
		child.queue_free()
	_slot_ctrls.clear()
	_class_rows.clear()
	_ready_btns.clear()

	for pi: int in _player_count:
		if pi > 0:
			var div := ColorRect.new()
			div.color = C_DIVIDER
			div.custom_minimum_size = Vector2(1, 0)
			div.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_panels_box.add_child(div)
		_panels_box.add_child(_build_player_panel(pi))

	_refresh_draft()


func _build_player_panel(pi: int) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	inner.add_child(header)

	var p_lbl := _lbl(PLAYER_LABELS[pi], 13, PLAYER_ACCENTS[pi])
	p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(p_lbl)

	var ready_btn := Button.new()
	ready_btn.text = "PICK ALL"
	ready_btn.custom_minimum_size = Vector2(86, 28)
	ready_btn.add_theme_font_size_override("font_size", 9)
	ready_btn.pressed.connect(func() -> void: _on_toggle_ready(pi))
	_style_ready_btn(ready_btn, pi, false, false)
	header.add_child(ready_btn)
	_ready_btns.append(ready_btn)

	# Slot row
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	inner.add_child(slots_row)

	var pi_slots: Array = []
	for si: int in _champ_count:
		var slot := _make_slot(pi, si)
		slots_row.add_child(slot)
		pi_slots.append(slot)
	_slot_ctrls.append(pi_slots)

	# Class list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)

	var cls_vbox := VBoxContainer.new()
	cls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cls_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(cls_vbox)

	var pi_rows: Array = []
	for ci: int in _chars.size():
		var row := _make_class_row(pi, ci)
		cls_vbox.add_child(row)
		pi_rows.append(row)
	_class_rows.append(pi_rows)

	return vbox


func _make_slot(pi: int, si: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(56, 56)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not _readies[pi]:
				_picks[pi][si] = null
				_refresh_draft()
	)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TEXT)
	panel.add_child(lbl)
	return panel


func _make_class_row(pi: int, ci: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_class_pick(pi, ci)
	)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Icon
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(48, 48) if _chars[ci].visual_scene != null else Vector2(34, 34)
	_panel_style(icon, C_ICON_BG, C_BORDER)
	if _chars[ci].visual_scene != null:
		var portrait := CharacterModelPortrait.new()
		portrait.setup(_chars[ci], Vector2(48, 48))
		icon.add_child(portrait)
	else:
		var icon_lbl := Label.new()
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 9)
		icon_lbl.add_theme_color_override("font_color", PLAYER_ACCENTS[pi])
		icon_lbl.text = _code(_chars[ci])
		icon.add_child(icon_lbl)
	hbox.add_child(icon)

	# Text
	var text_vb := VBoxContainer.new()
	text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vb.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vb)

	var name_lbl := _lbl(_chars[ci].display_name.to_upper(), 11, C_TEXT)
	name_lbl.clip_text = true
	text_vb.add_child(name_lbl)

	var role_lbl := _lbl(_chars[ci].role_name, 9, C_MUTED)
	role_lbl.clip_text = true
	text_vb.add_child(role_lbl)

	return panel


func _on_class_pick(pi: int, ci: int) -> void:
	if _readies[pi]:
		return
	var char_id: StringName = _chars[ci].character_id
	var arr: Array = _picks[pi]
	var existing: int = arr.find(char_id)
	if existing != -1:
		arr[existing] = null
	else:
		var empty: int = arr.find(null)
		if empty == -1:
			return
		arr[empty] = char_id
	_refresh_draft()


func _on_toggle_ready(pi: int) -> void:
	if _picks[pi].has(null):
		return
	_readies[pi] = not _readies[pi]
	_refresh_draft()


func _refresh_draft() -> void:
	for pi: int in _player_count:
		var arr: Array = _picks[pi]
		var full: bool = not arr.has(null)
		var ready: bool = _readies[pi]

		# Slots
		for si: int in _champ_count:
			if si >= _slot_ctrls[pi].size():
				continue
			var slot: Control = _slot_ctrls[pi][si]
			var char_id = arr[si] if si < arr.size() else null
			var lbl: Label = slot.get_child(0)
			if char_id != null:
				var def: CharacterDefinition = save_manager.get_character(char_id)
				lbl.text = _code(def) if def else "?"
				_panel_style(slot, C_ICON_BG, PLAYER_ACCENTS[pi])
			else:
				lbl.text = "+"
				_panel_style(slot, Color(0, 0, 0, 0), C_BORDER)

		# Class rows
		for ci: int in _chars.size():
			if ci >= _class_rows[pi].size():
				continue
			var row: Control = _class_rows[pi][ci]
			var char_id: StringName = _chars[ci].character_id
			var picked: bool = arr.has(char_id)
			var disabled: bool = ready or (not picked and full)

			_panel_style(row,
				PICKED_BGS[pi] if picked else Color(0.102, 0.063, 0.051),
				PLAYER_ACCENTS[pi] if picked else C_BORDER
			)
			row.modulate.a = 0.4 if (disabled and not picked) else 1.0
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE if (disabled and not picked) else Control.MOUSE_FILTER_STOP

		# Ready button
		if pi < _ready_btns.size():
			var btn: Button = _ready_btns[pi]
			btn.text = "WAITING..." if ready else ("READY" if full else "PICK ALL")
			_style_ready_btn(btn, pi, ready, full)

	var all_ready := true
	for r: Variant in _readies:
		if not r:
			all_ready = false
			break
	_style_begin_btn(all_ready)


func _on_back_to_setup() -> void:
	_reset_picks()
	_show_step(0)


func _on_begin_battle() -> void:
	for r: Variant in _readies:
		if not r:
			return
	_show_step(2)
	_rebuild_confirm()


# ══════════════════════════════════════════════════════════════════════════
# CONFIRM SCREEN
# ══════════════════════════════════════════════════════════════════════════

func _build_confirm_screen() -> void:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_screen_confirm = root

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 32)
	vbox.custom_minimum_size = Vector2(700, 0)
	root.add_child(vbox)

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var gates := _lbl("THE GATES OPEN", 13, C_MUTED)
	gates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(gates)

	var assembled := _lbl("CHAMPIONS ASSEMBLED", 34, C_TEXT)
	assembled.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(assembled)

	# Roster panels
	_roster_box = HBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 16)
	_roster_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_roster_box)

	# Footer
	var footer := VBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	var enter := _gold_btn("ENTER ARENA")
	enter.custom_minimum_size = Vector2(320, 60)
	enter.pressed.connect(_on_enter_arena)
	footer.add_child(enter)

	var back_link := Button.new()
	back_link.text = "Back to draft"
	back_link.flat = true
	back_link.add_theme_font_size_override("font_size", 12)
	back_link.add_theme_color_override("font_color", C_MUTED)
	back_link.add_theme_color_override("font_hover_color", C_TEXT)
	_flat_btn_style(back_link)
	back_link.pressed.connect(func() -> void: _show_step(1))
	footer.add_child(back_link)


func _rebuild_confirm() -> void:
	for child: Node in _roster_box.get_children():
		child.queue_free()

	for pi: int in _player_count:
		_roster_box.add_child(_build_roster_panel(pi))


func _build_roster_panel(pi: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_style(panel, C_PANEL, PLAYER_ACCENTS[pi])

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 16)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	var p_lbl := _lbl(PLAYER_LABELS[pi], 11, PLAYER_ACCENTS[pi])
	inner.add_child(p_lbl)

	# Accent divider under player name
	var div := ColorRect.new()
	div.color = PLAYER_ACCENTS[pi]
	div.color.a = 0.3
	div.custom_minimum_size = Vector2(0, 1)
	inner.add_child(div)

	for si: int in _champ_count:
		var char_id = _picks[pi][si] if si < _picks[pi].size() else null
		if char_id == null:
			continue
		var def: CharacterDefinition = save_manager.get_character(char_id)
		if def == null:
			continue

		var entry_margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			entry_margin.add_theme_constant_override("margin_" + side, 10)
		_panel_style(entry_margin, Color(0.12, 0.075, 0.063), C_BORDER)
		inner.add_child(entry_margin)

		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 10)
		entry_margin.add_child(entry)

		var icon := PanelContainer.new()
		icon.custom_minimum_size = Vector2(56, 56) if def.visual_scene != null else Vector2(38, 38)
		_panel_style(icon, C_ICON_BG, PLAYER_ACCENTS[pi])
		if def.visual_scene != null:
			var portrait := CharacterModelPortrait.new()
			portrait.setup(def, Vector2(56, 56))
			icon.add_child(portrait)
		else:
			var icon_lbl := Label.new()
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_lbl.add_theme_font_size_override("font_size", 10)
			icon_lbl.add_theme_color_override("font_color", PLAYER_ACCENTS[pi])
			icon_lbl.text = _code(def)
			icon.add_child(icon_lbl)
		entry.add_child(icon)

		var text_vb := VBoxContainer.new()
		text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vb.add_theme_constant_override("separation", 2)
		entry.add_child(text_vb)

		text_vb.add_child(_lbl(def.display_name.to_upper(), 12, C_TEXT))
		text_vb.add_child(_lbl(def.role_name.to_upper(), 9, PLAYER_ACCENTS[pi]))

	return panel


func _on_enter_arena() -> void:
	game_session.selected_map_id = "builtin:arena"
	game_session.arena_size_index = _arena_size_idx
	var teams: Array = []
	for pi: int in range(_player_count):
		teams.append(_build_team(pi, "arena_p%d" % (pi + 1)))
	game_session.configure_arena(_player_count, PLAYER_LABELS, teams)
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _build_team(pi: int, uuid: String) -> TeamDefinition:
	var team := TeamDefinition.new()
	team.team_uuid = uuid
	team.team_name = "Arena"
	for char_id: Variant in _picks[pi]:
		if char_id != null:
			team.character_ids.append(StringName(char_id))
	return team


# ══════════════════════════════════════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════════════════════════════════════

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel_style(ctrl: Control, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(0)
	ctrl.add_theme_stylebox_override("panel", sb)


func _gold_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", C_ON_GOLD)
	btn.add_theme_color_override("font_hover_color", C_ON_GOLD)
	btn.add_theme_color_override("font_pressed_color", C_ON_GOLD)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = C_GOLD
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = C_GOLD_H
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_n)
	return btn


func _flat_btn_style(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)


func _style_begin_btn(ready: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_GOLD if ready else C_BEGIN_OFF
	_begin_btn.add_theme_stylebox_override("normal", sb)
	_begin_btn.add_theme_stylebox_override("hover", sb)
	_begin_btn.add_theme_stylebox_override("pressed", sb)
	_begin_btn.add_theme_color_override("font_color", C_ON_GOLD if ready else C_DIM)
	_begin_btn.add_theme_color_override("font_hover_color", C_ON_GOLD if ready else C_DIM)
	_begin_btn.modulate.a = 1.0 if ready else 0.55


func _style_ready_btn(btn: Button, pi: int, ready: bool, full: bool) -> void:
	var accent := PLAYER_ACCENTS[pi]
	var sb := StyleBoxFlat.new()
	var sb_h := StyleBoxFlat.new()
	if ready:
		# Confirmed — filled accent bg, slightly darker on hover
		sb.bg_color = PICKED_BGS[pi]
		sb.border_color = accent
		sb_h.bg_color = PICKED_BGS[pi]
		sb_h.border_color = accent
		btn.add_theme_color_override("font_color", accent)
		btn.add_theme_color_override("font_hover_color", accent)
	elif full:
		# All slots filled — prominent CTA: solid accent fill
		sb.bg_color = accent
		sb.border_color = accent
		sb_h.bg_color = accent.lightened(0.15)
		sb_h.border_color = accent.lightened(0.15)
		btn.add_theme_color_override("font_color", C_ON_GOLD)
		btn.add_theme_color_override("font_hover_color", C_ON_GOLD)
	else:
		# Incomplete — ghost style
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = C_BORDER
		sb_h.bg_color = Color(0, 0, 0, 0)
		sb_h.border_color = C_BORDER
		btn.add_theme_color_override("font_color", C_MUTED)
		btn.add_theme_color_override("font_hover_color", C_MUTED)
	sb.set_border_width_all(1)
	sb_h.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.modulate.a = 1.0 if full else 0.4


func _code(def: CharacterDefinition) -> String:
	if def == null:
		return "??"
	var name := def.display_name.to_upper().strip_edges()
	return name.substr(0, mini(2, name.length()))
