class_name AbilitySystem
extends Node

var grid_manager: GridManager

func setup(manager: GridManager) -> void:
	grid_manager = manager

func can_execute(actor: TacticalUnit, target: TacticalUnit, ability_name: String) -> Dictionary:
	var ability := AbilityCatalog.get_ability(ability_name)
	if ability.is_empty():
		return {"ok": false, "message": "Nieznana umiejetnosc: %s" % ability_name}
	if actor == null or target == null or actor.is_dead() or target.is_dead():
		return {"ok": false, "message": "Cel jest niedostepny"}
	var target_kind := String(ability.get("target", "enemy"))
	if target_kind == "self" and target != actor:
		return {"ok": false, "message": "Ta umiejetnosc dziala tylko na uzywajacego"}
	if target_kind == "enemy" and target.team_id == actor.team_id:
		return {"ok": false, "message": "Wybierz przeciwnika"}
	if target_kind == "ally" and target.team_id != actor.team_id:
		return {"ok": false, "message": "Wybierz sojusznika"}
	var ability_range := int(ability.get("range", 1))
	if target != actor and _distance(actor, target) > ability_range:
		return {"ok": false, "message": "Cel poza zasiegiem (%d)" % ability_range}
	var cost := int(ability.get("cost", 0))
	if not actor.can_spend_action_points(cost):
		return {"ok": false, "message": "Za malo punktow akcji (potrzeba %d)" % cost}
	return {"ok": true, "ability": ability}

func execute(actor: TacticalUnit, target: TacticalUnit, ability_name: String) -> Dictionary:
	var validation := can_execute(actor, target, ability_name)
	if not bool(validation.get("ok", false)):
		return validation
	var ability: Dictionary = validation.ability
	var cost := int(ability.get("cost", 0))
	if not actor.spend_action_points(cost):
		return {"ok": false, "message": "Nie udalo sie wydac punktow akcji"}
	actor.play_attack_animation(target)
	var effect := String(ability.get("effect", "damage"))
	var recipients: Array[TacticalUnit] = [target]
	if effect.begins_with("area_"):
		recipients = _area_targets(actor, target, int(ability.get("radius", 1)), String(ability.get("target", "enemy")))
	var total_damage := 0
	var total_healing := 0
	for recipient: TacticalUnit in recipients:
		if not is_instance_valid(recipient) or recipient.is_dead():
			continue
		if effect.contains("damage"):
			var damage := _damage_value(actor, recipient, int(ability.get("power", 1)))
			recipient.take_damage(damage)
			total_damage += damage
		if effect == "heal":
			var before := recipient.current_health
			recipient.heal(int(ability.get("power", 1)) + maxi(0, actor.attributes.get(&"madrosc", 0)))
			total_healing += recipient.current_health - before
		if effect.contains("status"):
			recipient.apply_status(
				StringName(String(ability.get("status", ""))),
				int(ability.get("power", 1)),
				int(ability.get("duration", 1)),
				actor
			)
		_play_effect(recipient, effect)
	var details: Array[String] = []
	if total_damage > 0:
		details.append("%d obrazen" % total_damage)
	if total_healing > 0:
		details.append("%d leczenia" % total_healing)
	if ability.has("status"):
		details.append(TacticalUnit.status_label(StringName(String(ability.status))))
	return {
		"ok": true,
		"message": "%s uzywa %s na %s: %s" % [actor.display_name, ability_name, target.display_name, ", ".join(details)],
		"affected": recipients.size()
	}

func _damage_value(actor: TacticalUnit, target: TacticalUnit, power: int) -> int:
	var attack_bonus := maxi(0, actor.attributes.get(&"sila", 0)) + actor.status_value(&"might")
	attack_bonus -= actor.status_value(&"weakened")
	var defense := target.status_value(&"guard") + target.status_value(&"dodge") + target.status_value(&"hidden")
	var vulnerability := target.status_value(&"marked")
	return maxi(1, power + attack_bonus + vulnerability - defense)

func _area_targets(actor: TacticalUnit, center: TacticalUnit, radius: int, target_kind: String) -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for node: Node in get_tree().get_nodes_in_group("tactical_units"):
		var unit := node as TacticalUnit
		if unit == null or unit.is_dead():
			continue
		if target_kind == "enemy" and unit.team_id == actor.team_id:
			continue
		if target_kind == "ally" and unit.team_id != actor.team_id:
			continue
		if _distance(center, unit) <= radius:
			result.append(unit)
	return result

func _distance(first: TacticalUnit, second: TacticalUnit) -> int:
	var delta := first.grid_position - second.grid_position
	return maxi(absi(delta.x), absi(delta.y))

func _play_effect(target: TacticalUnit, effect: String) -> void:
	if not is_instance_valid(target) or target.get_parent() == null:
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "AbilityPulse"
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	pulse.mesh = sphere
	var color := Color(0.3, 0.75, 1.0, 0.75)
	if effect.contains("damage"):
		color = Color(1.0, 0.22, 0.08, 0.8)
	elif effect == "heal":
		color = Color(0.18, 1.0, 0.4, 0.8)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 2.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse.material_override = material
	target.get_parent().add_child(pulse)
	pulse.global_position = target.global_position + Vector3.UP * 0.8
	pulse.scale = Vector3.ONE * 0.25
	var tween := pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * 1.8, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(pulse.queue_free)
