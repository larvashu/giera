class_name GameMainMenu
extends Control

func _ready() -> void:
	%PlayButton.pressed.connect(_play)
	%ArenaButton.pressed.connect(_arena)
	%TeamsButton.pressed.connect(_teams)
	%CharactersButton.pressed.connect(_characters)
	%MapEditorButton.pressed.connect(_map_editor)
	%ExploreWorldButton.pressed.connect(_explore_world)
	%WorldEditorButton.pressed.connect(_world_editor)
	%QuitButton.pressed.connect(_quit)

func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/hotseat_setup.tscn")

func _arena() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/arena_setup.tscn")

func _teams() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/team_builder.tscn")

func _characters() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/character_editor.tscn")

func _map_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/map_editor.tscn")

func _explore_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world/exploration_world.tscn")

func _world_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/world/world_editor.tscn")

func _quit() -> void:
	get_tree().quit()
