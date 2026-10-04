class_name SkillBerserker
extends BaseSkill

## Responsabilidad: Habilidad de potenciación personal (Self-Buff) "Furia Berserker".
## Otorga +40% de daño físico y +40% de velocidad de ataque durante 8 segundos.
## No requiere seleccionar un objetivo enemigo para activarse.

var damage_boost_pct: float = 40.0
var attack_speed_boost_pct: float = 40.0
var buff_duration: float = 8.0

func _init() -> void:
	id = "furia_berserker"
	name = "Furia Berserker"
	icon = "🪓"
	key_label = "B"
	slot_index = -1

	mana_cost = 15
	cooldown = 14.0
	cast_time = 0.0 # Instantáneo
	range_distance = 0.0 # Auto-aplicado

	flat_damage = 0.0
	damage_multiplier = 1.0
	is_aoe = false

## Sobrescrito: No requiere objetivo hostil por ser un buff sobre sí mismo.
func can_cast(caster: Node3D, _target: Node3D, caster_stats: CharacterStats) -> Dictionary:
	if caster == null or not is_instance_valid(caster):
		return { "ok": false, "reason": "Lanzador inválido" }

	if caster_stats != null and mana_cost > 0:
		if caster_stats.current_mp < mana_cost:
			return { "ok": false, "reason": "Maná insuficiente" }

	var ct := caster.get_node_or_null("CombatTarget") as CombatTarget
	if ct and ct.current_health <= 0.0:
		return { "ok": false, "reason": "Estás derrotado" }

	return { "ok": true, "reason": "" }

## Aplica el buff de Berserker al lanzador, activa efectos visuales y reinicia la cadencia de ataque.
func execute(caster: Node3D, _target: Node3D, caster_stats: CharacterStats, tree: SceneTree = null) -> Dictionary:
	if caster == null or not is_instance_valid(caster):
		return { "success": false }

	if tree == null:
		tree = caster.get_tree()

	# 1. Deducción de maná
	if caster_stats != null and mana_cost > 0:
		caster_stats.current_mp = maxi(0, caster_stats.current_mp - mana_cost)

	# 2. Aplicar estado alterado Berserker en el StatusEffectController del lanzador
	var status_ctrl := caster.get_node_or_null("StatusEffectController") as StatusEffectController
	if status_ctrl and status_ctrl.has_method("apply_berserker"):
		status_ctrl.apply_berserker(damage_boost_pct, attack_speed_boost_pct, buff_duration)

	# 3. Animación de grito / impacto visual
	var visuals: Node = caster.get_node_or_null("Visuals")
	if visuals and visuals.has_method("play_attack"):
		visuals.play_attack(1.8)

	# 4. Texto flotante indicador de buff
	_spawn_berserk_feedback(caster, tree)

	# 5. Resetear cooldown de ataque básico para aprovechar la velocidad inmediatamente
	var combat_ctrl: Node = caster.get_node_or_null("CombatController")
	if combat_ctrl and combat_ctrl.has_method("reset_attack_timer"):
		combat_ctrl.reset_attack_timer()

	return { "success": true, "duration": buff_duration }

func _spawn_berserk_feedback(caster: Node3D, tree: SceneTree) -> void:
	if tree == null or caster == null:
		return
	var dmg_fx_scene := preload("res://scenes/combat/damage_number_fx.tscn")
	if dmg_fx_scene and tree.root:
		var fx := dmg_fx_scene.instantiate() as DamageNumberFX
		tree.root.add_child(fx)
		fx.global_position = caster.global_position + Vector3(0.0, 2.2, 0.0)
		fx.setup(0.0, true, false, false, false, false, false, "¡BERSERKER! 🪓")
