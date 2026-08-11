class_name GameSessionState
extends Node

enum GameMode { SOLO_VS_AI, HOTSEAT, ONLINE_PVP }
enum ControllerType { LOCAL_PLAYER, LOCAL_HOTSEAT, AI_PLACEHOLDER, NETWORK_LOCAL, NETWORK_REMOTE }

var game_mode: GameMode = GameMode.SOLO_VS_AI
var player_count: int = 1
var team_controllers: Dictionary[int, ControllerType] = {
	0: ControllerType.LOCAL_PLAYER,
	1: ControllerType.AI_PLACEHOLDER
}
var player_names: Dictionary[int, String] = {1: "Gracz", 2: "Przeciwnik"}
var selected_team_uuids: Dictionary[int, String] = {}
var starting_compositions: Dictionary[int, Array] = {}
var match_configured: bool = false
var local_nickname: String = "Gracz"
var selected_map_id: String = "builtin:forest"
var arena_size_index: int = 1  # 0=Kwadrat 1=Normalna 2=Duza 3=BardozoDuza

func configure_mode(mode: GameMode) -> void:
	game_mode = mode
	match game_mode:
		GameMode.SOLO_VS_AI:
			player_count = 1
			team_controllers = {0: ControllerType.LOCAL_PLAYER, 1: ControllerType.AI_PLACEHOLDER}
		GameMode.HOTSEAT:
			player_count = 2
			team_controllers = {0: ControllerType.LOCAL_HOTSEAT, 1: ControllerType.LOCAL_HOTSEAT}
		GameMode.ONLINE_PVP:
			player_count = 2
			team_controllers = {0: ControllerType.NETWORK_LOCAL, 1: ControllerType.NETWORK_REMOTE}

func configure_hotseat(
	player_one_name: String,
	player_two_name: String,
	team_one: TeamDefinition,
	team_two: TeamDefinition
) -> void:
	configure_mode(GameMode.HOTSEAT)
	player_names = {
		1: player_one_name.strip_edges() if not player_one_name.strip_edges().is_empty() else "Gracz 1",
		2: player_two_name.strip_edges() if not player_two_name.strip_edges().is_empty() else "Gracz 2"
	}
	selected_team_uuids = {1: team_one.team_uuid, 2: team_two.team_uuid}
	starting_compositions = {
		1: team_one.character_ids.duplicate(),
		2: team_two.character_ids.duplicate()
	}
	match_configured = true

func configure_arena(count: int, names: Array, teams: Array) -> void:
	game_mode = GameMode.HOTSEAT
	player_count = count
	team_controllers.clear()
	player_names.clear()
	selected_team_uuids.clear()
	starting_compositions.clear()
	for i: int in range(count):
		var pid := i + 1
		team_controllers[i] = ControllerType.LOCAL_HOTSEAT
		player_names[pid] = names[i] if i < names.size() else "Gracz %d" % pid
		var team: TeamDefinition = teams[i]
		selected_team_uuids[pid] = team.team_uuid
		starting_compositions[pid] = team.character_ids.duplicate()
	match_configured = true

func clear_match_configuration() -> void:
	match_configured = false
	selected_team_uuids.clear()
	starting_compositions.clear()

func has_match_configuration() -> bool:
	return match_configured and starting_compositions.has(1) and starting_compositions.has(2)

func get_composition(owner_player_id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw: Array = starting_compositions.get(owner_player_id, [])
	for value: Variant in raw:
		result.append(StringName(value))
	return result

func is_team_locally_controllable(team_id: int) -> bool:
	var controller: int = int(team_controllers.get(team_id, ControllerType.AI_PLACEHOLDER))
	return controller in [ControllerType.LOCAL_PLAYER, ControllerType.LOCAL_HOTSEAT, ControllerType.NETWORK_LOCAL]

func should_auto_skip_team(team_id: int) -> bool:
	return int(team_controllers.get(team_id, ControllerType.AI_PLACEHOLDER)) == ControllerType.AI_PLACEHOLDER

func is_hotseat() -> bool:
	return game_mode == GameMode.HOTSEAT

func get_player_name(owner_player_id: int) -> String:
	return player_names.get(owner_player_id, "Gracz %d" % owner_player_id)

func controller_label(team_id: int, owner_player_id: int = 0) -> String:
	var controller: int = int(team_controllers.get(team_id, ControllerType.AI_PLACEHOLDER))
	match controller:
		ControllerType.LOCAL_PLAYER:
			return get_player_name(maxi(1, owner_player_id))
		ControllerType.LOCAL_HOTSEAT:
			return get_player_name(maxi(1, owner_player_id))
		ControllerType.AI_PLACEHOLDER:
			return "Przeciwnik (AI placeholder)"
		ControllerType.NETWORK_LOCAL:
			return "Twoja tura online"
		ControllerType.NETWORK_REMOTE:
			return "Tura gracza zdalnego"
	return "Nieznany kontroler"
