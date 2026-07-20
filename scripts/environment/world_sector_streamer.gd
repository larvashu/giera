class_name WorldSectorStreamer
extends Node3D

const SECTOR_SIZE := Vector2(float(GridManager.GRID_WIDTH), float(GridManager.GRID_HEIGHT))
# Prototyp korzysta obecnie z jednej fizycznej planszy.
const MIN_SECTOR := Vector2i.ZERO
const MAX_SECTOR := Vector2i.ZERO
const PRELOAD_MARGIN: float = 0.0

@export var grid_manager_path: NodePath = NodePath("../GridManager")
@export var decorator_path: NodePath = NodePath("../BattleDecorator")

var _grid_manager: GridManager
var _decorator: Node3D
var _loaded_sectors: Dictionary[Vector2i, Node3D] = {}

func _ready() -> void:
	add_to_group("world_sector_streamer")
	_grid_manager = get_node_or_null(grid_manager_path) as GridManager
	_decorator = get_node_or_null(decorator_path) as Node3D
	call_deferred("_initialize_streaming")

func _initialize_streaming() -> void:
	if _grid_manager == null or _decorator == null:
		push_warning("WorldSectorStreamer: missing source nodes")
		return
	_unload_copied_sectors()
	set_process(false)

func clamp_world_position(world_position: Vector3) -> Vector3:
	world_position.x = clampf(world_position.x, 0.5, SECTOR_SIZE.x - 0.5)
	world_position.z = clampf(world_position.z, 0.5, SECTOR_SIZE.y - 0.5)
	return world_position

func get_loaded_sector_count() -> int:
	return _loaded_sectors.size() + 1

func _update_loaded_sectors(world_position: Vector3) -> void:
	var current := _world_to_sector(world_position)
	var desired: Dictionary[Vector2i, bool] = {current: true}
	var local := Vector2(world_position.x - float(current.x) * SECTOR_SIZE.x, world_position.z - float(current.y) * SECTOR_SIZE.y)
	var x_offsets: Array[int] = [0]
	var z_offsets: Array[int] = [0]
	if local.x < PRELOAD_MARGIN:
		x_offsets.append(-1)
	if local.x > SECTOR_SIZE.x - PRELOAD_MARGIN:
		x_offsets.append(1)
	if local.y < PRELOAD_MARGIN:
		z_offsets.append(-1)
	if local.y > SECTOR_SIZE.y - PRELOAD_MARGIN:
		z_offsets.append(1)
	for x_offset: int in x_offsets:
		for z_offset: int in z_offsets:
			var coordinate := current + Vector2i(x_offset, z_offset)
			if _is_valid_sector(coordinate):
				desired[coordinate] = true
	for coordinate: Vector2i in desired:
		if coordinate != Vector2i.ZERO and not _loaded_sectors.has(coordinate):
			_load_sector(coordinate)
	var loaded_coordinates: Array[Vector2i] = []
	loaded_coordinates.assign(_loaded_sectors.keys())
	for coordinate: Vector2i in loaded_coordinates:
		if not desired.has(coordinate):
			_unload_sector(coordinate)

func _world_to_sector(world_position: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(world_position.x / SECTOR_SIZE.x), MIN_SECTOR.x, MAX_SECTOR.x), clampi(floori(world_position.z / SECTOR_SIZE.y), MIN_SECTOR.y, MAX_SECTOR.y))

func _is_valid_sector(coordinate: Vector2i) -> bool:
	return coordinate.x >= MIN_SECTOR.x and coordinate.x <= MAX_SECTOR.x and coordinate.y >= MIN_SECTOR.y and coordinate.y <= MAX_SECTOR.y

func _load_sector(coordinate: Vector2i) -> void:
	var sector_root := Node3D.new()
	sector_root.name = "Sector_%d_%d" % [coordinate.x, coordinate.y]
	sector_root.position = Vector3(float(coordinate.x) * SECTOR_SIZE.x, 0.0, float(coordinate.y) * SECTOR_SIZE.y)
	add_child(sector_root)
	for source_name: StringName in [&"GrassTerrain", &"ArenaFloor"]:
		var source := _grid_manager.get_node_or_null(NodePath(String(source_name)))
		if source != null:
			sector_root.add_child(source.duplicate(Node.DUPLICATE_USE_INSTANTIATION))
	for source_child: Node in _decorator.get_children():
		sector_root.add_child(source_child.duplicate(Node.DUPLICATE_USE_INSTANTIATION))
	_loaded_sectors[coordinate] = sector_root

func _unload_sector(coordinate: Vector2i) -> void:
	var sector: Node3D = _loaded_sectors.get(coordinate)
	if sector != null and is_instance_valid(sector):
		sector.queue_free()
	_loaded_sectors.erase(coordinate)

func _unload_copied_sectors() -> void:
	var coordinates: Array[Vector2i] = []
	coordinates.assign(_loaded_sectors.keys())
	for coordinate: Vector2i in coordinates:
		_unload_sector(coordinate)
