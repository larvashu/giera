class_name CharacterAnimationController
extends RefCounted

var _player: AnimationPlayer
var _clips: Dictionary[StringName, StringName] = {}


func setup(model: Node3D, definition: CharacterDefinition) -> void:
	_player = _find_player(model)
	if _player == null or definition == null:
		return
	_register_existing(&"walk")
	_import_clip(&"idle", definition.idle_animation_scene, true)
	_import_clip(&"walk", definition.walk_animation_scene, true)
	_import_clip(&"run", definition.run_animation_scene, true)
	_import_clip(&"attack", definition.attack_animation_scene, false)
	_import_clip(&"hurt", definition.hurt_animation_scene, false)
	play_idle()


func play_idle() -> void:
	_play(&"idle")


func play_walk(speed_scale: float = 1.0) -> void:
	_play(&"walk", speed_scale)


func play_run() -> void:
	_play(&"run")


func play_attack() -> void:
	if _player == null or not _clips.has(&"attack"):
		return
	_player.play(_clips[&"attack"], 0.12)
	_player.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)


func play_hurt() -> void:
	if _player == null or not _clips.has(&"hurt"):
		return
	_player.play(_clips[&"hurt"], 0.08)
	_player.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)


func _on_attack_finished(_animation_name: StringName) -> void:
	play_idle()


func _play(kind: StringName, speed_scale: float = 1.0) -> void:
	if _player != null and _clips.has(kind):
		_player.play(_clips[kind], 0.1, speed_scale)


func _register_existing(kind: StringName) -> void:
	var names := _player.get_animation_list()
	if not names.is_empty():
		_clips[kind] = names[0]


func _import_clip(kind: StringName, source_scene: PackedScene, loop: bool) -> void:
	if source_scene == null:
		return
	var source_root := source_scene.instantiate()
	var source_player := _find_player(source_root)
	if source_player != null:
		var names := source_player.get_animation_list()
		if not names.is_empty():
			var animation := source_player.get_animation(names[0]).duplicate(true) as Animation
			animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			var library := _player.get_animation_library(&"")
			if library == null:
				library = AnimationLibrary.new()
				_player.add_animation_library(&"", library)
			var clip_name := StringName("character_%s" % kind)
			if library.has_animation(clip_name):
				library.remove_animation(clip_name)
			library.add_animation(clip_name, animation)
			_clips[kind] = clip_name
	source_root.free()


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
