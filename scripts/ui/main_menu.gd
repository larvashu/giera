class_name LegacyModeMenu
extends Control

const BATTLE_SCENE: String = "res://scenes/battle/battle.tscn"
const HOTSEAT_SETUP_SCENE: String = "res://scenes/menu/hotseat_setup.tscn"

@onready var mode_panel: VBoxContainer = %ModePanel
@onready var online_panel: VBoxContainer = %OnlinePanel
@onready var nickname_edit: LineEdit = %NicknameEdit
@onready var lobby_code_edit: LineEdit = %LobbyCodeEdit
@onready var online_status: Label = %OnlineStatus

func _ready() -> void:
	%SoloButton.pressed.connect(_start_solo)
	%HotseatButton.pressed.connect(_start_hotseat)
	%OnlineButton.pressed.connect(_show_online)
	%OnlineBackButton.pressed.connect(_hide_online)
	%HostButton.pressed.connect(_online_placeholder.bind("Tworzenie lobby"))
	%JoinButton.pressed.connect(_online_placeholder.bind("Dolaczanie do lobby"))
	online_panel.visible = false

func _start_solo() -> void:
	var game_session: GameSessionState = get_node("/root/GameSession") as GameSessionState
	game_session.clear_match_configuration()
	game_session.game_mode = GameSessionState.GameMode.SOLO_VS_AI
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _start_hotseat() -> void:
	get_tree().change_scene_to_file(HOTSEAT_SETUP_SCENE)

func _show_online() -> void:
	mode_panel.visible = false
	online_panel.visible = true
	online_status.text = "Warstwa lobby jest przygotowana. Transport sieciowy bedzie kolejnym etapem."

func _hide_online() -> void:
	online_panel.visible = false
	mode_panel.visible = true

func _online_placeholder(action_name: String) -> void:
	var nickname: String = nickname_edit.text.strip_edges()
	if nickname.is_empty():
		online_status.text = "Podaj pseudonim."
		return
	var code: String = lobby_code_edit.text.strip_edges()
	online_status.text = "%s: %s. Synchronizacja online nie jest jeszcze aktywna." % [
		action_name,
		code if not code.is_empty() else "nowe lobby"
	]
