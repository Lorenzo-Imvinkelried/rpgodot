class_name SkillCharge
extends BaseSkill

## Responsabilidad: Habilidad de embestida cinética "Carga".
## Desplaza velozmente al lanzador hacia el objetivo enemigo y al impactar inflige
## daño físico contundente y aplica Aturdimiento (Stun) durante 2.0 segundos.

const HIT_FX_SCENE = preload("res://scenes/combat/hit_fx.tscn")
const CHARGE_SPEED: float = 26.0

var stun_duration: float = 2.0

func _init() -> void:
	id = "carga"
	name = "Carga"
	icon = "🏃‍♂️"
	key_label = "C"
	slot_index = -1

	mana_cost = 10
	cooldown = 8.0
	cast_time = 0.0 # Instantáneo
	range_distance = 18.0

	flat_damage = 45.0
	damage_multiplier = 1.35
	is_aoe = false
	threat_multiplier = 2.0

## Valida que haya un objetivo hostil vivo dentro del rango de embestida.
func can_cast(caster: Node3D, target: Node3D, caster_stats: CharacterStats) -> Dictionary:
	var base_check := super.can_cast(caster, target, caster_stats)
	if not base_check.get("ok", false):
		return base_check

	if target == caster:
		return { "ok": false, "reason": "No puedes cargarte a ti mismo" }

	return { "ok": true, "reason": "" }

## Inicia el desplazamiento cinético ultrarrápido hacia el enemigo y programa el impacto al llegar.
func execute(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree = null) -> Dictionary:
	if caster == null or not is_instance_valid(caster):
		return { "success": false }
	if target == null or not is_instance_valid(target) or target == caster:
		return { "success": false }

	if tree == null:
		tree = caster.get_tree()

	# 1. Deducción de maná
	if caster_stats != null and mana_cost > 0:
		caster_stats.current_mp = maxi(0, caster_stats.current_mp - mana_cost)

	# 2. Calcular vector de dirección hacia el objetivo
	var diff := target.global_position - caster.global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir := diff.normalized() if dist > 0.001 else -caster.transform.basis.z

	# Orientar al lanzador hacia el objetivo
	caster.look_at(caster.global_position + dir, Vector3.UP)

	# 3. Duración de la carrera según la distancia
	var charge_dist := maxf(0.0, dist - 1.2)
	var charge_dur := clampf(charge_dist / CHARGE_SPEED, 0.10, 0.75)

	# 4. Impulso físico procedural (Lunge a alta velocidad)
	if caster.has_method("apply_lunge"):
		caster.apply_lunge(dir, CHARGE_SPEED, charge_dur)

	# Animación de ataque / embestida
	var visuals: Node = caster.get_node_or_null("Visuals")
	if visuals and visuals.has_method("play_attack"):
		visuals.play_attack(2.0)

	# Entrar en combate
	var caster_ct := caster.get_node_or_null("CombatTarget") as CombatTarget
	if caster_ct:
		caster_ct.enter_combat(target)

	var combat_ctrl: Node = caster.get_node_or_null("CombatController")
	if combat_ctrl:
		if "current_target" in combat_ctrl and combat_ctrl.current_target == null:
			combat_ctrl.current_target = target
		if combat_ctrl.has_method("reset_attack_timer"):
			combat_ctrl.reset_attack_timer()

	# 5. Programar el impacto justo en el momento de llegada
	if tree != null and charge_dur > 0.02:
		tree.create_timer(charge_dur).timeout.connect(func():
			_on_charge_impact(caster, target, caster_stats, tree)
		)
	else:
		_on_charge_impact(caster, target, caster_stats, tree)

	return { "success": true, "duration": charge_dur }

func _on_charge_impact(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	if target == null or not is_instance_valid(target) or target == caster:
		return

	if target.has_method("is_alive") and not target.is_alive():
		return

	var target_ct := target.get_node_or_null("CombatTarget") as CombatTarget
	if target_ct == null or target_ct.current_health <= 0.0:
		return


	# Reset de autoataque al colisionar
	var combat_ctrl: Node = caster.get_node_or_null("CombatController")
	if combat_ctrl and combat_ctrl.has_method("reset_attack_timer"):
		combat_ctrl.reset_attack_timer()

	# Chispas de impacto (HitFX)
	var hit_pos := target.global_position + Vector3(0.0, 1.2, 0.0)
	if tree != null and tree.root != null:
		var hit_fx := HIT_FX_SCENE.instantiate() as Node3D
		tree.root.add_child(hit_fx)
		hit_fx.global_position = hit_pos

	# Cálculo de daño
	var target_stats := target_ct.get_stats()
	var base_dmg := flat_damage
	if caster_stats != null:
		base_dmg += float(caster_stats.attack) * (damage_multiplier - 1.0)

	var dmg_result := CombatCalculatorScript.calculate_skill_damage(caster_stats, target_stats, maxf(1.0, base_dmg))
	target_ct.take_combat_result(dmg_result, hit_pos, caster)
	target_ct.enter_combat(caster)

	# Aplicar Aturdimiento (Stun)
	var status_ctrl := target.get_node_or_null("StatusEffectController") as StatusEffectController
	if status_ctrl and status_ctrl.has_method("apply_stun"):
		status_ctrl.apply_stun(stun_duration)

	# Amenaza de combate
	if target.has_method("on_aggroed_by"):
		target.on_aggroed_by(caster)
	if "aggro_pool" in target and target.aggro_pool != null:
		target.aggro_pool.add_threat(caster, float(dmg_result.total_damage) * threat_multiplier)
