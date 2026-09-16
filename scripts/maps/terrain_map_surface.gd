class_name TerrainMapSurface
extends Node3D

signal height_edit_finished
signal texture_edit_finished

const MAP_SIZE := Vector2i(160, 190)
const REGION_LOCATION := Vector2i.ZERO
## Wide sculpting range for deep valleys and genuinely mountain-scale terrain.
const MIN_HEIGHT := -128.0
const MAX_HEIGHT := 512.0
const TERRAIN_TEXTURE_SIZE := 1024
const HEIGHT_POINTS_PER_FRAME := 3000
const PBR_ROOT := "res://assets/textures/terrain/ambientcg_2k/"
const GLHF_ROOT := "res://assets/environment/terrain/glhf/"
const PAINT_TEXTURES: Array[Dictionary] = [
	{"name": "Trawa", "path": PBR_ROOT + "Grass001_2K-PNG/Grass001_2K-PNG_Color.png", "normal": PBR_ROOT + "Grass001_2K-PNG/Grass001_2K-PNG_NormalGL.png", "height": PBR_ROOT + "Grass001_2K-PNG/Grass001_2K-PNG_Displacement.png", "roughness_map": PBR_ROOT + "Grass001_2K-PNG/Grass001_2K-PNG_Roughness.png", "uv_scale": 0.18, "roughness": 0.72},
	{"name": "Sucha trawa", "path": PBR_ROOT + "Grass004_2K-PNG/Grass004_2K-PNG_Color.png", "normal": PBR_ROOT + "Grass004_2K-PNG/Grass004_2K-PNG_NormalGL.png", "uv_scale": 0.18, "roughness": 0.78},
	{"name": "Leśna ściółka 03", "path": GLHF_ROOT + "forrest_ground_03/forrest_ground_03_diff_4k.jpg", "normal": GLHF_ROOT + "forrest_ground_03/forrest_ground_03_nor_gl_4k.jpg", "uv_scale": 0.20, "roughness": 0.88},
	{"name": "Leśna ziemia 05", "path": GLHF_ROOT + "forest_ground_05/forest_ground_05_diff_4k.jpg", "normal": GLHF_ROOT + "forest_ground_05/forest_ground_05_nor_gl_4k.jpg", "arm": GLHF_ROOT + "forest_ground_05/forest_ground_05_arm_4k.jpg", "uv_scale": 0.20, "roughness": 0.86},
	{"name": "Leśna ziemia 06", "path": GLHF_ROOT + "forest_ground_06/forest_ground_06_diff_4k.jpg", "normal": GLHF_ROOT + "forest_ground_06/forest_ground_06_nor_gl_4k.jpg", "arm": GLHF_ROOT + "forest_ground_06/forest_ground_06_arm_4k.jpg", "uv_scale": 0.20, "roughness": 0.84},
	{"name": "Kamyki rzeczne", "path": GLHF_ROOT + "dry_river_pebbles/dry_river_pebbles_diff_4k.jpg", "normal": GLHF_ROOT + "dry_river_pebbles/dry_river_pebbles_nor_gl_4k.jpg", "arm": GLHF_ROOT + "dry_river_pebbles/dry_river_pebbles_arm_4k.jpg", "uv_scale": 0.19, "roughness": 0.82},
	{"name": "Skaliste podłoże", "path": GLHF_ROOT + "rocks_ground_01/rocks_ground_01_diff_4k.jpg", "normal": GLHF_ROOT + "rocks_ground_01/rocks_ground_01_nor_gl_4k.jpg", "uv_scale": 0.17, "roughness": 0.90},
	{"name": "Szare skały", "path": GLHF_ROOT + "gray_rocks/gray_rocks_diff_4k.jpg", "normal": GLHF_ROOT + "gray_rocks/gray_rocks_nor_gl_4k.jpg", "uv_scale": 0.16, "roughness": 0.89},
	{"name": "Ciemna skała", "path": GLHF_ROOT + "dark_rock/dark_rock_diff_4k.jpg", "normal": GLHF_ROOT + "dark_rock/dark_rock_nor_gl_4k.jpg", "uv_scale": 0.16, "roughness": 0.91},
	{"name": "Marmurowy klif 04", "path": GLHF_ROOT + "marble_cliff_04/marble_cliff_04_diff_4k.jpg", "normal": GLHF_ROOT + "marble_cliff_04/marble_cliff_04_nor_gl_4k.jpg", "uv_scale": 0.15, "roughness": 0.88},
	{"name": "Marmurowy klif 05", "path": GLHF_ROOT + "marble_cliff_05/marble_cliff_05_diff_4k.jpg", "normal": GLHF_ROOT + "marble_cliff_05/marble_cliff_05_nor_gl_4k.jpg", "uv_scale": 0.15, "roughness": 0.88},
	{"name": "Marmurowa skała 03", "path": GLHF_ROOT + "marble_rock_03/marble_rock_03_diff_4k.jpg", "normal": GLHF_ROOT + "marble_rock_03/marble_rock_03_nor_gl_4k.jpg", "uv_scale": 0.16, "roughness": 0.87},
	{"name": "Droga brukowana", "path": PBR_ROOT + "PavingStones138_2K-PNG/PavingStones138_2K-PNG_Color.png", "normal": PBR_ROOT + "PavingStones138_2K-PNG/PavingStones138_2K-PNG_NormalGL.png", "uv_scale": 0.18, "roughness": 0.82},
	{"name": "Biała plansza", "generated_white": true, "uv_scale": 0.20, "roughness": 0.94},
]
const BLANK_TEXTURE_ID := 13

var terrain: Terrain3D
var _region: Terrain3DRegion
var _regions: Array[Terrain3DRegion] = []
var _editable_map_size := MAP_SIZE
var _data_directory: String = ""
## Legacy overlay storage retained only for backward-compatible helper methods.
## The editor no longer creates this surface; Terrain3D renders directly.
var _overlay_multimesh: MultiMesh
var _overlay_instance: MultiMeshInstance3D
var _active_height_job: Dictionary = {}
var _pending_height_request: Dictionary = {}
var _active_texture_job: Dictionary = {}
var _pending_texture_request: Dictionary = {}

func setup(camera: Camera3D = null, data_directory: String = "", legacy_strokes: Array = []) -> void:
	_data_directory = data_directory
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = 1.0
	terrain.mesh_lods = 5
	terrain.mesh_size = 32
	terrain.collision_mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision_shape_size = 16
	add_child(terrain)
	if camera != null:
		terrain.set_camera(camera)
	await get_tree().process_frame
	_configure_material()
	if not data_directory.is_empty():
		terrain.data.load_directory(data_directory)
	_region = terrain.data.get_region(REGION_LOCATION)
	if _region == null:
		_region = terrain.data.add_region_blank(REGION_LOCATION, false)
	_regions = [_region]
	if data_directory.is_empty():
		_initialize_base_height()
	_ensure_paintable_control()
	# Terrain3D keeps editable Images on the CPU and separate textures on the GPU.
	# Uploading all maps is required after creating/loading a runtime region.
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	if not legacy_strokes.is_empty():
		_import_legacy_strokes(legacy_strokes)

func set_map_size_multiplier(multiplier: int) -> void:
	if terrain == null:
		return
	var safe_multiplier := clampi(multiplier, 1, 8)
	_editable_map_size = MAP_SIZE * safe_multiplier
	terrain.vertex_spacing = 1.0
	terrain.mesh_lods = 8 if safe_multiplier >= 4 else 6
	var region_columns := ceili(float(_editable_map_size.x) / float(terrain.region_size))
	var region_rows := ceili(float(_editable_map_size.y) / float(terrain.region_size))
	for existing_location: Vector2i in terrain.data.get_region_locations():
		if existing_location.x < 0 or existing_location.y < 0 or existing_location.x >= region_columns or existing_location.y >= region_rows:
			terrain.data.remove_regionl(existing_location, false)
	_regions.clear()
	for region_z: int in range(region_rows):
		for region_x: int in range(region_columns):
			var location := Vector2i(region_x, region_z)
			var region := terrain.data.get_region(location)
			if region == null:
				region = terrain.data.add_region_blank(location, false)
			elif terrain.data.is_region_deleted(location):
				# remove_regionl() marks regions as deleted but get_region() still
				# returns them. Reactivate them when resizing/reloading, otherwise
				# every second 256 m strip can remain absent on a large map.
				terrain.data.set_region_deleted(location, false)
			_regions.append(region)
	_region = terrain.data.get_region(REGION_LOCATION)

func import_height_sampler(sampler: Callable) -> void:
	if terrain == null or _region == null or not sampler.is_valid():
		return
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var sampled_height: float = clampf(float(sampler.call(float(x), float(z))), MIN_HEIGHT, MAX_HEIGHT)
			terrain.data.set_height(Vector3(float(x), 0.0, float(z)), sampled_height)
	_finish_height_edit()


func apply_brush(center: Vector3, radius: float, strength: float, operation: String) -> void:
	if terrain == null or _region == null:
		return
	var bounds := _brush_bounds(center, radius)
	for z: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			_apply_height_point(x, z, center, radius, strength, operation)
	_finish_height_edit()


func queue_height_brush(center: Vector3, radius: float, strength: float, operation: String) -> void:
	if terrain == null or _region == null:
		return
	var request := {
		"center": center,
		"radius": radius,
		"strength": strength,
		"operation": operation,
	}
	if _active_height_job.is_empty():
		_start_height_job(request)
	else:
		# Continuous strokes only need the newest not-yet-started sample.
		# Replacing it prevents a large-brush backlog after releasing the mouse.
		_pending_height_request = request


func is_height_brush_busy() -> bool:
	return not _active_height_job.is_empty() or not _pending_height_request.is_empty()


func _process(_delta: float) -> void:
	if not _active_height_job.is_empty():
		_process_height_job()
	elif not _active_texture_job.is_empty():
		_process_texture_job()


func _start_height_job(request: Dictionary) -> void:
	var center: Vector3 = request["center"]
	var radius: float = float(request["radius"])
	var bounds := _brush_bounds(center, radius)
	_active_height_job = request.duplicate()
	_active_height_job["bounds"] = bounds
	_active_height_job["x"] = bounds.position.x
	_active_height_job["z"] = bounds.position.y


func _process_height_job() -> void:
	var bounds: Rect2i = _active_height_job["bounds"]
	var center: Vector3 = _active_height_job["center"]
	var radius: float = float(_active_height_job["radius"])
	var strength: float = float(_active_height_job["strength"])
	var operation: String = str(_active_height_job["operation"])
	var x: int = int(_active_height_job["x"])
	var z: int = int(_active_height_job["z"])
	var processed := 0
	while z < bounds.end.y and processed < HEIGHT_POINTS_PER_FRAME:
		_apply_height_point(x, z, center, radius, strength, operation)
		processed += 1
		x += 1
		if x >= bounds.end.x:
			x = bounds.position.x
			z += 1
	if z < bounds.end.y:
		_active_height_job["x"] = x
		_active_height_job["z"] = z
		return
	_active_height_job.clear()
	_finish_height_edit()
	height_edit_finished.emit()
	if not _pending_height_request.is_empty():
		var next_request := _pending_height_request
		_pending_height_request = {}
		_start_height_job(next_request)


func _brush_bounds(center: Vector3, radius: float) -> Rect2i:
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(_editable_map_size.x - 1, ceili(center.x + radius))
	var min_z := maxi(0, floori(center.z - radius))
	var max_z := mini(_editable_map_size.y - 1, ceili(center.z + radius))
	return Rect2i(min_x, min_z, max_x - min_x + 1, max_z - min_z + 1)


func _apply_height_point(x: int, z: int, center: Vector3, radius: float, strength: float, operation: String) -> void:
	var distance_squared := Vector2(float(x) - center.x, float(z) - center.z).length_squared()
	var radius_squared := radius * radius
	if distance_squared >= radius_squared:
		return
	var influence: float = 1.0 - sqrt(distance_squared) / radius
	influence = influence * influence * (3.0 - 2.0 * influence)
	var point := Vector3(float(x), 0.0, float(z))
	var current_height := get_height(float(x), float(z))
	var next_height := current_height
	match operation:
		"raise":
			next_height += strength * influence
		"lower":
			next_height -= strength * influence
		"smooth":
			var average := _neighbor_average(x, z)
			next_height = lerpf(current_height, average, clampf(strength * 0.42 * influence, 0.0, 0.92))
		"flatten":
			next_height = lerpf(current_height, center.y, clampf(strength * 0.45 * influence, 0.0, 0.92))
		"noise":
			var broad := sin(float(x) * 0.071 + float(z) * 0.039) * cos(float(z) * 0.061 - float(x) * 0.027)
			var medium := sin(float(x) * 0.19 + float(z) * 0.23) * 0.32
			next_height += (broad + medium) * strength * 0.48 * influence
		"erode":
			var erosion_average := _neighbor_average(x, z)
			var erosion := clampf(strength * 0.34 * influence, 0.0, 0.78)
			next_height = lerpf(current_height, erosion_average, erosion)
			if current_height > erosion_average:
				next_height -= minf(current_height - erosion_average, strength * 0.08 * influence)
		"terrace":
			var terrace_step := 1.35
			var terraced := roundf(current_height / terrace_step) * terrace_step
			next_height = lerpf(current_height, terraced, clampf(strength * 0.32 * influence, 0.0, 0.68))
		"ridge":
			var ridge_noise := 0.72 + 0.28 * sin(float(x) * 0.13 + sin(float(z) * 0.09) * 2.0)
			next_height += strength * influence * influence * ridge_noise
	terrain.data.set_height(point, clampf(next_height, MIN_HEIGHT, MAX_HEIGHT))


func paint_texture(center: Vector3, radius: float, strength: float, texture_id: int) -> void:
	if terrain == null or _region == null or texture_id < 0 or texture_id >= PAINT_TEXTURES.size():
		return
	var bounds := _brush_bounds(center, radius)
	for z: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			_apply_texture_point(x, z, center, radius, strength, texture_id)
	_finish_texture_edit()


func queue_texture_brush(center: Vector3, radius: float, strength: float, texture_id: int) -> void:
	if terrain == null or _region == null or texture_id < 0 or texture_id >= PAINT_TEXTURES.size():
		return
	var request := {
		"center": center,
		"radius": radius,
		"strength": strength,
		"texture_id": texture_id,
	}
	if _active_texture_job.is_empty():
		_start_texture_job(request)
	else:
		_pending_texture_request = request


func is_texture_brush_busy() -> bool:
	return not _active_texture_job.is_empty() or not _pending_texture_request.is_empty()


func _start_texture_job(request: Dictionary) -> void:
	var center: Vector3 = request["center"]
	var radius: float = float(request["radius"])
	var bounds := _brush_bounds(center, radius)
	_active_texture_job = request.duplicate()
	_active_texture_job["bounds"] = bounds
	_active_texture_job["x"] = bounds.position.x
	_active_texture_job["z"] = bounds.position.y


func _process_texture_job() -> void:
	var bounds: Rect2i = _active_texture_job["bounds"]
	var center: Vector3 = _active_texture_job["center"]
	var radius: float = float(_active_texture_job["radius"])
	var strength: float = float(_active_texture_job["strength"])
	var texture_id: int = int(_active_texture_job["texture_id"])
	var x: int = int(_active_texture_job["x"])
	var z: int = int(_active_texture_job["z"])
	var processed := 0
	while z < bounds.end.y and processed < HEIGHT_POINTS_PER_FRAME:
		_apply_texture_point(x, z, center, radius, strength, texture_id)
		processed += 1
		x += 1
		if x >= bounds.end.x:
			x = bounds.position.x
			z += 1
	if z < bounds.end.y:
		_active_texture_job["x"] = x
		_active_texture_job["z"] = z
		return
	_active_texture_job.clear()
	_finish_texture_edit()
	texture_edit_finished.emit()
	if not _pending_texture_request.is_empty():
		var next_request := _pending_texture_request
		_pending_texture_request = {}
		_start_texture_job(next_request)


func _apply_texture_point(x: int, z: int, center: Vector3, radius: float, strength: float, texture_id: int) -> void:
	var distance_squared := Vector2(float(x) - center.x, float(z) - center.z).length_squared()
	var radius_squared := radius * radius
	if distance_squared >= radius_squared:
		return
	var influence := 1.0 - sqrt(distance_squared) / radius
	influence = influence * influence * (3.0 - 2.0 * influence)
	var edge_noise := 0.86
	edge_noise += 0.18 * sin(float(x) * 0.73 + float(z) * 1.11)
	edge_noise += 0.10 * sin(float(x) * 2.173 - float(z) * 1.417)
	influence = clampf(influence * edge_noise, 0.0, 1.0)
	var point := Vector3(float(x), 0.0, float(z))
	var base_id := terrain.data.get_control_base_id(point)
	var overlay_id := terrain.data.get_control_overlay_id(point)
	var blend := terrain.data.get_control_blend(point)
	var paint_amount := clampf(strength * 0.52 * influence, 0.0, 0.82)
	if base_id == texture_id:
		blend = maxf(0.0, blend - paint_amount)
		terrain.data.set_control_blend(point, blend)
	elif overlay_id == texture_id:
		blend = minf(0.995, blend + paint_amount)
		terrain.data.set_control_blend(point, blend)
	else:
		if blend > 0.5:
			terrain.data.set_control_base_id(point, overlay_id)
		terrain.data.set_control_overlay_id(point, texture_id)
		terrain.data.set_control_blend(point, paint_amount)
	terrain.data.set_control_auto(point, false)
	terrain.data.set_control_angle(point, _texture_rotation_for_cell(x, z, texture_id))
	var current_color := terrain.data.get_color(point)
	terrain.data.set_color(point, current_color.lerp(Color.WHITE, clampf(strength * 0.24 * influence, 0.0, 1.0)))


func _finish_texture_edit() -> void:
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, true, false)


func fill_texture_rect(rect: Rect2i, texture_id: int) -> void:
	if terrain == null or _region == null or texture_id < 0 or texture_id >= PAINT_TEXTURES.size():
		return
	var clipped := rect.abs().intersection(Rect2i(Vector2i.ZERO, _editable_map_size))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	for z: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			var point := Vector3(float(x), 0.0, float(z))
			terrain.data.set_control_base_id(point, texture_id)
			terrain.data.set_control_overlay_id(point, texture_id)
			terrain.data.set_control_blend(point, 0.0)
			terrain.data.set_control_auto(point, false)
			terrain.data.set_control_angle(point, _texture_rotation_for_cell(x, z, texture_id))
			terrain.data.set_color(point, Color.WHITE)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, true, false)


func _texture_rotation_for_cell(_x: int, _z: int, _texture_id: int) -> float:
	# Per-cell 90-degree jumps created visible 8 m squares. Terrain3D asset
	# detiling handles repetition continuously without discontinuous UV angles.
	return 0.0


func get_height(world_x: float, world_z: float) -> float:
	if terrain == null or terrain.data == null:
		return 0.0
	var value := terrain.data.get_height(Vector3(world_x, 0.0, world_z))
	return 0.0 if is_nan(value) else value

func get_intersection(ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	if terrain == null:
		return Vector3(NAN, NAN, NAN)
	return terrain.get_intersection(ray_origin, ray_direction, false)


func get_surface_normal(world_x: float, world_z: float) -> Vector3:
	var step := 0.5
	var dx := get_height(world_x + step, world_z) - get_height(world_x - step, world_z)
	var dz := get_height(world_x, world_z + step) - get_height(world_x, world_z - step)
	return Vector3(-dx, step * 2.0, -dz).normalized()

func clear_height() -> void:
	if terrain == null:
		return
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			terrain.data.set_height(Vector3(float(x), 0.0, float(z)), 0.0)
	_finish_height_edit()

func reset_blank() -> void:
	cancel_queued_edits()
	if terrain == null or _region == null:
		return
	for z: int in range(_editable_map_size.y):
		for x: int in range(_editable_map_size.x):
			var point := Vector3(float(x), 0.0, float(z))
			terrain.data.set_height(point, 0.0)
			terrain.data.set_control_base_id(point, BLANK_TEXTURE_ID)
			terrain.data.set_control_overlay_id(point, BLANK_TEXTURE_ID)
			terrain.data.set_control_blend(point, 0.0)
			terrain.data.set_control_auto(point, false)
			terrain.data.set_color(point, Color.WHITE)
	for region: Terrain3DRegion in _regions:
		region.calc_height_range()
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)

func capture_state() -> Dictionary:
	if _region == null:
		return {}
	return {
		"height": _region.get_height_map().duplicate(),
		"control": _region.get_control_map().duplicate(),
		"color": _region.get_color_map().duplicate(),
	}


func restore_state(state: Dictionary) -> void:
	cancel_queued_edits()
	if _region == null or state.is_empty():
		return
	var height_map := state.get("height") as Image
	var control_map := state.get("control") as Image
	var color_map := state.get("color") as Image
	if height_map != null:
		_region.set_height_map(height_map.duplicate())
	if control_map != null:
		_region.set_control_map(control_map.duplicate())
	if color_map != null:
		_region.set_color_map(color_map.duplicate())
	_region.calc_height_range()
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)


func load_from_directory(directory: String, multiplier: int) -> bool:
	if terrain == null or directory.is_empty():
		return false
	var absolute_directory := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return false
	for location: Vector2i in terrain.data.get_region_locations():
		terrain.data.remove_regionl(location, false)
	terrain.data.load_directory(directory)
	set_map_size_multiplier(multiplier)
	for region: Terrain3DRegion in _regions:
		region.calc_height_range()
	terrain.data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
	_data_directory = directory
	return true


func save_to_directory(directory: String) -> void:
	if terrain == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	terrain.data.save_directory(directory)
	_data_directory = directory

func get_data_directory() -> String:
	return _data_directory


func cancel_queued_edits() -> void:
	_active_height_job.clear()
	_pending_height_request.clear()
	_active_texture_job.clear()
	_pending_texture_request.clear()


func _initialize_base_height() -> void:
	for z: int in range(terrain.region_size):
		for x: int in range(terrain.region_size):
			var point := Vector3(float(x), 0.0, float(z))
			terrain.data.set_height(point, 0.0)
			terrain.data.set_control_base_id(point, BLANK_TEXTURE_ID)
			terrain.data.set_control_overlay_id(point, BLANK_TEXTURE_ID)
			terrain.data.set_control_blend(point, 0.0)
			terrain.data.set_control_auto(point, false)
			terrain.data.set_color(point, Color.WHITE)
	_finish_height_edit()

func _ensure_paintable_control() -> void:
	var color_map := _region.get_color_map()
	if color_map == null or color_map.is_empty():
		color_map = Image.create(terrain.region_size, terrain.region_size, false, Image.FORMAT_RGBA8)
		for z: int in range(terrain.region_size):
			for x: int in range(terrain.region_size):
				color_map.set_pixel(x, z, Color.WHITE)
		_region.set_color_map(color_map)
	for z: int in range(_editable_map_size.y):
		for x: int in range(_editable_map_size.x):
			var point := Vector3(float(x), 0.0, float(z))
			var base_id := terrain.data.get_control_base_id(point)
			var overlay_id := terrain.data.get_control_overlay_id(point)
			if base_id < 0 or base_id >= PAINT_TEXTURES.size():
				terrain.data.set_control_base_id(point, 0)
			if overlay_id < 0 or overlay_id >= PAINT_TEXTURES.size():
				terrain.data.set_control_overlay_id(point, 0)
				terrain.data.set_control_blend(point, 0.0)
			terrain.data.set_control_auto(point, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, true, false)

func _neighbor_average(x: int, z: int) -> float:
	var total: float = get_height(float(x), float(z))
	var count: int = 1
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, z) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= _editable_map_size.x or neighbor.y >= _editable_map_size.y:
			continue
		total += get_height(float(neighbor.x), float(neighbor.y))
		count += 1
	return total / float(count)

func _finish_height_edit() -> void:
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, false)

func _import_legacy_strokes(strokes: Array) -> void:
	for raw_stroke: Variant in strokes:
		if raw_stroke is not Dictionary:
			continue
		var stroke := raw_stroke as Dictionary
		var center := Vector3(
			float(stroke.get("x", 0.0)),
			0.0,
			float(stroke.get("z", 0.0))
		)
		apply_brush(
			center,
			maxf(0.1, float(stroke.get("radius", 1.0))),
			float(stroke.get("strength", 0.5)),
			str(stroke.get("operation", "raise"))
		)

func _build_visual_overlay() -> void:
	_overlay_instance = MultiMeshInstance3D.new()
	_overlay_instance.name = "TerrainPaintVisual"
	var tile_mesh := PlaneMesh.new()
	tile_mesh.size = Vector2(1.08, 1.08)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying flat float material_id;
varying flat float instance_detail;
void vertex() {
	material_id = INSTANCE_CUSTOM.r * 3.0;
	instance_detail = 0.94 + 0.06 * sin(MODEL_MATRIX[3].x * 1.73 + MODEL_MATRIX[3].z * 2.11);
}
void fragment() {
	float id = material_id;
	vec2 tiled_uv = UV * 0.82;
	vec3 albedo;
	if (id < 0.5) {
		albedo = texture(grass_texture, tiled_uv).rgb;
	} else if (id < 1.5) {
		albedo = texture(soil_texture, tiled_uv).rgb;
	} else if (id < 2.5) {
		albedo = texture(sand_texture, tiled_uv).rgb;
	} else {
		albedo = texture(rock_texture, tiled_uv).rgb;
	}
	ALBEDO = albedo * instance_detail;
	ROUGHNESS = 0.82;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("grass_texture", load(str(PAINT_TEXTURES[0]["path"])))
	shader_material.set_shader_parameter("soil_texture", load(str(PAINT_TEXTURES[1]["path"])))
	shader_material.set_shader_parameter("sand_texture", load(str(PAINT_TEXTURES[2]["path"])))
	shader_material.set_shader_parameter("rock_texture", load(str(PAINT_TEXTURES[3]["path"])))
	tile_mesh.material = shader_material
	_overlay_multimesh = MultiMesh.new()
	_overlay_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_overlay_multimesh.use_custom_data = true
	_overlay_multimesh.mesh = tile_mesh
	_overlay_multimesh.instance_count = MAP_SIZE.x * MAP_SIZE.y
	for z: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var point := Vector3(float(x), 0.0, float(z))
			var base_id := terrain.data.get_control_base_id(point)
			var overlay_id := terrain.data.get_control_overlay_id(point)
			var texture_id := overlay_id if terrain.data.get_control_blend(point) >= 0.5 else base_id
			var index := z * MAP_SIZE.x + x
			_overlay_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, get_height(float(x), float(z)) + 0.035, float(z) + 0.5)))
			_overlay_multimesh.set_instance_custom_data(index, Color(float(texture_id) / 3.0, 0.0, 0.0, 1.0))
	_overlay_instance.multimesh = _overlay_multimesh
	add_child(_overlay_instance)

func _set_overlay_material(x: int, z: int, texture_id: int) -> void:
	if _overlay_multimesh == null:
		return
	var index := z * MAP_SIZE.x + x
	_overlay_multimesh.set_instance_custom_data(index, Color(float(texture_id) / 3.0, 0.0, 0.0, 1.0))

func _refresh_overlay_heights(changes: Array[Vector3]) -> void:
	if _overlay_multimesh == null:
		return
	for change: Vector3 in changes:
		var x := clampi(roundi(change.x), 0, MAP_SIZE.x - 1)
		var z := clampi(roundi(change.z), 0, MAP_SIZE.y - 1)
		var index := z * MAP_SIZE.x + x
		var instance_transform := _overlay_multimesh.get_instance_transform(index)
		instance_transform.origin.y = change.y + 0.035
		_overlay_multimesh.set_instance_transform(index, instance_transform)

func _configure_material() -> void:
	if terrain == null or terrain.material == null or terrain.assets == null:
		return
	var texture_assets: Array[Terrain3DTextureAsset] = []
	for texture_id: int in range(PAINT_TEXTURES.size()):
		var definition: Dictionary = PAINT_TEXTURES[texture_id]
		var asset := Terrain3DTextureAsset.new()
		asset.id = texture_id
		asset.name = str(definition["name"])
		if bool(definition.get("generated_white", false)):
			asset.albedo_texture = _create_solid_texture(Color.WHITE)
			asset.normal_texture = _create_solid_texture(Color(0.5, 0.5, 1.0, 1.0))
		else:
			asset.albedo_texture = _prepare_terrain_albedo(definition)
			asset.normal_texture = _prepare_terrain_normal(definition)
		asset.uv_scale = float(definition["uv_scale"])
		asset.roughness = float(definition["roughness"])
		asset.normal_depth = 1.08 if texture_id in [5, 6, 7, 8, 9, 10, 11] else 0.92
		# Continuous per-asset detiling prevents repeating grids without writing
		# hard 90-degree angle changes into the terrain control map.
		asset.detiling_rotation = 0.18 + float(texture_id % 4) * 0.07
		asset.detiling_shift = 0.12 + float(texture_id % 3) * 0.055
		texture_assets.append(asset)
	terrain.assets.set_texture_list(texture_assets)
	terrain.assets.update_texture_list()
	# `show_colormap` is a white diagnostic view, not the regular color multiplier.
	terrain.material.show_colormap = false
	terrain.material.dual_scaling = true
	terrain.material.update()
	terrain.show_grey = false
	terrain.material.world_background = Terrain3DMaterial.NONE

func _create_solid_texture(color: Color) -> Texture2D:
	var image := Image.create(TERRAIN_TEXTURE_SIZE, TERRAIN_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.generate_mipmaps(true)
	return ImageTexture.create_from_image(image)


func _prepare_terrain_albedo(definition: Dictionary) -> Texture2D:
	var image := _load_terrain_image(str(definition["path"]))
	if image == null:
		return null
	var height_image: Image = _load_terrain_image(str(definition.get("height", "")))
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			color.a = height_image.get_pixel(x, y).r if height_image != null else 0.5
			image.set_pixel(x, y, color)
	image.generate_mipmaps(true)
	return ImageTexture.create_from_image(image)


func _prepare_terrain_normal(definition: Dictionary) -> Texture2D:
	var image := _load_terrain_image(str(definition["normal"]))
	if image == null:
		return null
	var arm_image: Image = _load_terrain_image(str(definition.get("arm", "")))
	var roughness_image: Image = _load_terrain_image(str(definition.get("roughness_map", "")))
	var fallback_roughness := float(definition.get("roughness", 0.9))
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if roughness_image != null:
				color.a = roughness_image.get_pixel(x, y).r
			elif arm_image != null:
				color.a = arm_image.get_pixel(x, y).g
			else:
				color.a = fallback_roughness
			image.set_pixel(x, y, color)
	image.generate_mipmaps(false)
	return ImageTexture.create_from_image(image)


func _load_terrain_image(path: String) -> Image:
	if path.is_empty():
		return null
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_width() != TERRAIN_TEXTURE_SIZE or image.get_height() != TERRAIN_TEXTURE_SIZE:
		image.resize(TERRAIN_TEXTURE_SIZE, TERRAIN_TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	return image
