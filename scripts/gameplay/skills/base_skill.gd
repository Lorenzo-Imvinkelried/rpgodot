class_name BaseSkill
extends RefCounted

## Responsabilidad: Clase base abstracta para todas las habilidades activas del juego.
## Encapsula definición de propiedades, validación de condiciones de lanzamiento (can_cast)
## y ejecución polimórfica de la lógica de impacto, daño y efectos (execute).

const CombatCalculatorScript = preload("res://scripts/combat/combat_calculator.gd")

var id: String = ""
var name: String = ""
var icon: String = ""
var key_label: String = ""
var slot_index: int = -1

var mana_cost: int = 0
var cooldown: float = 0.0
var cast_time: float = 0.0 # 0.0 = instantáneo, > 0.0 = canalizado en CastBar
var range_distance: float = 18.0

var flat_damage: float = 0.0
var damage_multiplier: float = 1.0
var is_aoe: bool = false
var aoe_radius: float = 6.0

var anim_speed_multiplier: float = 1.0
var effect_type: String = "" # "slow", "bleed", "stun", ""
var effect_duration: float = 0.0
var effect_value: float = 0.0
var threat_multiplier: float = 1.0

## Evalúa si la habilidad puede ejecutarse según maná, rango y estado del objetivo.
func can_cast(caster: Node3D, target: Node3D, caster_stats: CharacterStats) -> Dictionary:
	# 1. Validación de Maná
	if caster_stats != null and mana_cost > 0:
		if caster_stats.current_mp < mana_cost:
			return { "ok": false, "reason": "Maná insuficiente" }

	# 2. Validación de Objetivo (habilidades single-target)
	if not is_aoe:
		if target == null or not is_instance_valid(target):
			return { "ok": false, "reason": "Sin objetivo seleccionado" }

		var target_ct := target.get_node_or_null("CombatTarget") as CombatTarget
		if target_ct and target_ct.current_health <= 0.0:
			return { "ok": false, "reason": "Objetivo derrotado" }

		# Validación de distancia
		if caster != null:
			var dist := caster.global_position.distance_to(target.global_position)
			if dist > range_distance:
				return { "ok": false, "reason": "Objetivo fuera de alcance" }

	return { "ok": true, "reason": "" }

## Ejecuta la lógica central de la habilidad (daño, efectos, deducción de recursos y animación).
## Puede ser sobreescrito por habilidades especializadas para comportamientos únicos.
func execute(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree = null) -> Dictionary:
	if caster == null:
		return { "success": false }

	# Deducción de maná
	if caster_stats != null and mana_cost > 0:
		caster_stats.current_mp = maxi(0, caster_stats.current_mp - mana_cost)

	# Animación en el lanzador con velocidad basada en su velocidad actual de ataque
	var visuals: Node = caster.get_node_or_null("Visuals")
	if visuals and visuals.has_method("play_attack"):
		var current_atk_spd: float = 1.4
		if caster_stats != null:
			current_atk_spd = caster_stats.attack_speed
		var status_ctrl: Node = caster.get_node_or_null("StatusEffectController")
		if status_ctrl and status_ctrl.has_method("get_attack_speed_multiplier"):
			current_atk_spd *= status_ctrl.get_attack_speed_multiplier()

		var base_anim_scale: float = 1.0
		if visuals.has_method("get_attack_speed_scale"):
			base_anim_scale = visuals.get_attack_speed_scale(current_atk_spd)
		else:
			base_anim_scale = current_atk_spd

		var final_speed_scale: float = maxf(1.5, base_anim_scale * anim_speed_multiplier)
		visuals.play_attack(final_speed_scale)

	# Registro de estado de combate en el lanzador y sincronización de autoataque
	var caster_ct := caster.get_node_or_null("CombatTarget") as CombatTarget
	if caster_ct:
		caster_ct.enter_combat(target)

	var combat_ctrl: Node = caster.get_node_or_null("CombatController")
	if combat_ctrl and combat_ctrl.has_method("reset_attack_timer"):
		combat_ctrl.reset_attack_timer()

	# Ejecución de daño
	if is_aoe:
		return _execute_aoe(caster, caster_stats, tree)
	else:
		return _execute_single(caster, target, caster_stats)

func _execute_single(caster: Node3D, target: Node3D, caster_stats: CharacterStats) -> Dictionary:
	if target == null or not is_instance_valid(target) or target == caster:
		return { "success": false }

	if target.has_method("is_alive") and not target.is_alive():
		return { "success": false }

	var target_ct := target.get_node_or_null("CombatTarget") as CombatTarget
	if target_ct == null or target_ct.current_health <= 0.0:
		return { "success": false }

	var target_stats := target_ct.get_stats()
	var base_dmg := flat_damage
	if caster_stats != null:
		base_dmg += float(caster_stats.attack) * (damage_multiplier - 1.0)

	var dmg_result := CombatCalculatorScript.calculate_skill_damage(caster_stats, target_stats, maxf(1.0, base_dmg))

	# Aplicar impacto
	var hit_pos := target.global_position + Vector3(0.0, 1.0, 0.0)
	target_ct.take_combat_result(dmg_result, hit_pos, caster)

	# Registrar combate en objetivo
	target_ct.enter_combat(caster)

	# Generar amenaza si el objetivo tiene AggroPool o método de aggro
	if target.has_method("on_aggroed_by"):
		target.on_aggroed_by(caster)
	if "aggro_pool" in target and target.aggro_pool != null:
		target.aggro_pool.add_threat(caster, float(dmg_result.total_damage) * threat_multiplier)

	# Efectos de estado
	_apply_status_effect(target, caster, caster_stats)

	return { "success": true, "damage": dmg_result.total_damage, "is_crit": dmg_result.is_crit }

func _execute_aoe(caster: Node3D, caster_stats: CharacterStats, tree: SceneTree) -> Dictionary:
	if tree == null and caster != null:
		tree = caster.get_tree()
	if tree == null:
		return { "success": false }

	var hits: int = 0
	var targets := tree.get_nodes_in_group("targetable")
	var processed_entities: Array[Node3D] = []

	for node in targets:
		if node == caster or (caster.has_node("CombatTarget") and node == caster.get_node_or_null("CombatTarget")):
			continue
		var target_node: Node3D = node as Node3D
		if target_node == null and node.get_parent() is Node3D:
			target_node = node.get_parent() as Node3D
		if target_node == null or not is_instance_valid(target_node):
			continue
		if target_node == caster:
			continue
		if processed_entities.has(target_node):
			continue

		# Comprobar que el objetivo esté vivo y con vida positiva
		if target_node.has_method("is_alive") and not target_node.is_alive():
			continue
		var target_ct := target_node.get_node_or_null("CombatTarget") as CombatTarget
		if target_ct and target_ct.current_health <= 0.0:
			continue

		var dist := caster.global_position.distance_to(target_node.global_position)
		if dist <= aoe_radius:
			processed_entities.append(target_node)
			_execute_single(caster, target_node, caster_stats)
			hits += 1

	return { "success": true, "hits": hits }

func _apply_status_effect(target: Node3D, caster: Node3D = null, caster_stats: CharacterStats = null) -> void:
	if effect_type == "" or target == null:
		return
	var status_ctrl := target.get_node_or_null("StatusEffectController")
	if status_ctrl == null:
		return

	if effect_type == "slow" and status_ctrl.has_method("apply_slow"):
		# apply_slow(move_pct: float, attack_pct: float, duration: float)
		status_ctrl.apply_slow(effect_value, effect_value * 0.5, effect_duration)
	elif effect_type == "bleed" and status_ctrl.has_method("apply_bleed"):
		# apply_bleed(source_stats: CharacterStats, duration: float, flat_damage: int, percent_damage: float, source_node: Node)
		var atk_stats := caster_stats
		if atk_stats == null and caster != null:
			var ct := caster.get_node_or_null("CombatTarget") as CombatTarget
			if ct:
				atk_stats = ct.get_stats()
		status_ctrl.apply_bleed(atk_stats, effect_duration, int(effect_value), 15.0, caster)
	elif effect_type == "stun" and status_ctrl.has_method("apply_stun"):
		status_ctrl.apply_stun(effect_duration)
