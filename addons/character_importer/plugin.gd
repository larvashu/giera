@tool
extends EditorPlugin

var _dock: Control

func _enter_tree() -> void:
	_dock = load("res://addons/character_importer/dock.gd").new()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
