class_name SkillPowerStrike
extends BaseSkill

## Responsabilidad: Skill 1 (Slot 0 / Tecla 1) - Golpe Potente / Ataque Básico Potenciado.
## Ejecuta un golpe básico potenciado con mayor velocidad de ataque que el básico estándar.
## El impacto y el daño se sincronizan exactamente con la caída de la espada (impact_delay / speed_scale),
## comportándose idéntico a un ataque básico pero con cadencia acelerada, mayor daño y chispas HitFX.

const HIT_FX_SCENE = preload("res://scenes/combat/hit_fx.tscn")
const BASE_IMPACT_DELAY: float = 0.58

func _init() -> void:
	id = "golpe_potente"
	name = "Golpe Potente"
	icon = "⚔️"
	key_label = "1"
	slot_index = 0

	mana_cost = 5
	cooldown = 1.8
	cast_time = 0.0 # Instantáneo
	range_distance = 3.5 # Rango melee directo

	flat_damage = 30.0
	damage_multiplier = 1.55 # 55% más de daño que el básico estándar
	anim_speed_multiplier = 1.45 # Velocidad de ataque acelerada respecto a la cadencia actual
	threat_multiplier = 1.6 # Mayor generación de amenaza

## Ejecución con animación acelerada e impacto sincronizado con la caída de la espada
func execute(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree = null) -> Dictionary:
	if caster == null or target == null or not is_instance_valid(target):
		return { "success": false }

	if tree == null:
		tree = caster.get_tree()

	# 1. Deducción de maná
	if caster_stats != null and mana_cost > 0:
		caster_stats.current_mp = maxi(0, caster_stats.current_mp - mana_cost)

	# 2. Orientar al personaje hacia el objetivo
	var diff := target.global_position - caster.global_position
	diff.y = 0.0
	if diff.length_squared() > 0.001:
		caster.look_at(caster.global_position + diff.normalized(), Vector3.UP)

	# 3. Calcular la velocidad de ataque acelerada tomando como base la velocidad actual del jugador
	var current_atk_spd: float = 1.4
	if caster_stats != null:
		current_atk_spd = caster_stats.attack_speed

	var status_ctrl: Node = caster.get_node_or_null("StatusEffectController")
	if status_ctrl and status_ctrl.has_method("get_attack_speed_multiplier"):
		current_atk_spd *= status_ctrl.get_attack_speed_multiplier()

	var visuals: Node = caster.get_node_or_null("Visuals")
	var base_anim_scale: float = 1.0
	if visuals and visuals.has_method("get_attack_speed_scale"):
		base_anim_scale = visuals.get_attack_speed_scale(current_atk_spd)
	else:
		base_anim_scale = current_atk_spd

	# Escala de velocidad final acelerada (más rápida que el golpe básico normal)
	var skill_speed_scale: float = maxf(1.5, base_anim_scale * anim_speed_multiplier)

	# 4. Reproducir la animación de golpe acelerada
	if visuals and visuals.has_method("play_attack"):
		visuals.play_attack(skill_speed_scale)

	# 5. Entrada en estado de combate del lanzador
	var caster_ct := caster.get_node_or_null("CombatTarget") as CombatTarget
	if caster_ct:
		caster_ct.enter_combat(target)

	# 6. Sincronización del impacto con la caída de la espada
	var base_delay: float = float(GameConfig.get_combat_value("combat", "impact_delay", BASE_IMPACT_DELAY))
	var real_delay: float = base_delay / skill_speed_scale

	# Programar la entrega del daño para el momento exacto en que desciende la espada
	if tree != null and real_delay > 0.01:
		tree.create_timer(real_delay).timeout.connect(func():
			_apply_delayed_strike(caster, target, caster_stats, tree)
		)
	else:
		_apply_delayed_strike(caster, target, caster_stats, tree)

	return { "success": true, "speed_scale": skill_speed_scale, "impact_delay": real_delay }

func _apply_delayed_strike(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	if target == null or not is_instance_valid(target):
		return

	var target_ct := target.get_node_or_null("CombatTarget") as CombatTarget
	if target_ct == null or target_ct.current_health <= 0.0:
		return

	var target_stats := target_ct.get_stats()
	var base_dmg := flat_damage
	if caster_stats != null:
		base_dmg += float(caster_stats.attack) * (damage_multiplier - 1.0)

	var dmg_result := CombatCalculatorScript.calculate_skill_damage(caster_stats, target_stats, maxf(1.0, base_dmg))

	var hit_pos := target.global_position + Vector3(0.0, 1.0, 0.0)

	# Chispas de impacto (HitFX) exactamente igual que un ataque básico
	if tree != null and tree.root != null and not dmg_result.is_miss:
		var hit_fx := HIT_FX_SCENE.instantiate() as Node3D
		tree.root.add_child(hit_fx)
		hit_fx.global_position = hit_pos

	# Aplicar el resultado de combate al objetivo cuando la espada impacta
	target_ct.take_combat_result(dmg_result, hit_pos, caster)

	# Entrar en combate objetivo
	target_ct.enter_combat(caster)

	# Registrar amenaza en la tabla de aggro
	if target.has_method("on_aggroed_by"):
		target.on_aggroed_by(caster)
	if "aggro_pool" in target and target.aggro_pool != null:
		target.aggro_pool.add_threat(caster, float(dmg_result.total_damage) * threat_multiplier)

	_apply_status_effect(target)
