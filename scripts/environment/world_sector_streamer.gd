class_name WorldSectorStreamer
extends Node3D

const REGION_SCRIPT := preload("res://scripts/world/exploration_region.gd")
const SECTOR_SIZE := Vector2(float(GridManager.GRID_WIDTH), float(GridManager.GRID_HEIGHT))
const MIN_SECTOR := Vector2i(-3, -3)
const MAX_SECTOR := Vector2i(3, 3)
const PRELOAD_MARGIN := Vector2(115.0, 135.0)
const UPDATE_INTERVAL := 0.18

var _world: Dictionary = {}
var _loaded_sectors: Dictionary[Vector2i, ExplorationRegion] = {}
var _enabled := false
var _elapsed := 0.0

func _ready() -> void:
	add_to_group("world_sector_streamer")
	_enabled = GameSession.selected_map_id.is_empty() or GameSession.selected_map_id == MapCatalogService.DEFAULT_ID
	if not _enabled:
		set_process(false)
		return
	_world = ExplorationWorldCatalog.load_world()
	call_deferred("_initialize_streaming")

func _initialize_streaming() -> void:
	# Sektory wokol prawdziwej planszy bitwy sa gotowe zanim gracz wejdzie do FPP.
	_update_loaded_sectors(Vector3(SECTOR_SIZE.x * 0.5, 0.0, SECTOR_SIZE.y * 0.5))

func _process(delta: float) -> void:
	if not _enabled: return
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL: return
	_elapsed = 0.0
	var explorer := get_tree().get_first_node_in_group("exploration_player") as Node3D
	if explorer != null: _update_loaded_sectors(explorer.global_position)

func clamp_world_position(world_position: Vector3) -> Vector3:
	if not _enabled:
		world_position.x = clampf(world_position.x, 0.5, SECTOR_SIZE.x - 0.5)
		world_position.z = clampf(world_position.z, 0.5, SECTOR_SIZE.y - 0.5)
		return world_position
	world_position.x = clampf(world_position.x, MIN_SECTOR.x * SECTOR_SIZE.x + 0.5, (MAX_SECTOR.x + 1) * SECTOR_SIZE.x - 0.5)
	world_position.z = clampf(world_position.z, MIN_SECTOR.y * SECTOR_SIZE.y + 0.5, (MAX_SECTOR.y + 1) * SECTOR_SIZE.y - 0.5)
	_update_loaded_sectors(world_position)
	return world_position

func get_loaded_sector_count() -> int:
	return _loaded_sectors.size() + 1

func _update_loaded_sectors(world_position: Vector3) -> void:
	var current := _world_to_sector(world_position)
	var local := Vector2(world_position.x - current.x * SECTOR_SIZE.x, world_position.z - current.y * SECTOR_SIZE.y)
	var x_offsets: Array[int] = [0]
	var z_offsets: Array[int] = [0]
	if local.x < PRELOAD_MARGIN.x: x_offsets.append(-1)
	if local.x > SECTOR_SIZE.x - PRELOAD_MARGIN.x: x_offsets.append(1)
	if local.y < PRELOAD_MARGIN.y: z_offsets.append(-1)
	if local.y > SECTOR_SIZE.y - PRELOAD_MARGIN.y: z_offsets.append(1)
	var desired: Dictionary[Vector2i, bool] = {}
	for dx: int in x_offsets:
		for dz: int in z_offsets:
			var coordinate := current + Vector2i(dx, dz)
			if _is_valid_sector(coordinate): desired[coordinate] = true
	# Centralna plansza jest prawdziwym GridManagerem i BattleDecoratorem — nie duplikujemy jej.
	desired[Vector2i.ZERO] = true
	for coordinate: Vector2i in desired:
		if coordinate != Vector2i.ZERO and not _loaded_sectors.has(coordinate): _load_sector(coordinate)
	var loaded_coordinates: Array[Vector2i] = []
	loaded_coordinates.assign(_loaded_sectors.keys())
	for coordinate: Vector2i in loaded_coordinates:
		if not desired.has(coordinate): _unload_sector(coordinate)

func _world_to_sector(world_position: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(world_position.x / SECTOR_SIZE.x),MIN_SECTOR.x,MAX_SECTOR.x),clampi(floori(world_position.z / SECTOR_SIZE.y),MIN_SECTOR.y,MAX_SECTOR.y))

func _is_valid_sector(coordinate: Vector2i) -> bool:
	return coordinate.x >= MIN_SECTOR.x and coordinate.x <= MAX_SECTOR.x and coordinate.y >= MIN_SECTOR.y and coordinate.y <= MAX_SECTOR.y

func _load_sector(coordinate: Vector2i) -> void:
	var descriptor := ExplorationWorldCatalog.region_at(_world, coordinate)
	if descriptor.is_empty(): return
	var sector := REGION_SCRIPT.new() as ExplorationRegion
	sector.configure(descriptor, false)
	add_child(sector)
	_loaded_sectors[coordinate] = sector
	sector.call_deferred("begin_stream_fade")

func _unload_sector(coordinate: Vector2i) -> void:
	var sector: ExplorationRegion = _loaded_sectors.get(coordinate) as ExplorationRegion
	if sector != null and is_instance_valid(sector): sector.queue_free()
	_loaded_sectors.erase(coordinate)
