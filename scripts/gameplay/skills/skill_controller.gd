class_name SkillController
extends Node

## Responsabilidad: Coordinación de lanzamiento de habilidades activas, validación de maná,
## rangos, enfriamientos, canalización en CastBar y aplicación de daño al objetivo.

signal skill_cast_started(skill: RefCounted, target: Node3D)
signal skill_cast_finished(skill: RefCounted, target: Node3D)
signal skill_cast_failed(reason: String)

const SkillDataScript = preload("res://scripts/gameplay/skills/skill_data.gd")
const CombatCalculatorScript = preload("res://scripts/combat/combat_calculator.gd")

var _skills: Dictionary = {} # slot_index (int) -> SkillData
var _cooldowns: Dictionary = {} # slot_index -> float remaining
var _pending_cast_slot: int = -1
var _pending_cast_target: Node3D = null
var _pending_hotbar: Control = null

var _parent_body: CharacterBody3D = null

func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	_setup_default_skills()

func _process(delta: float) -> void:
	for slot in _cooldowns.keys():
		_cooldowns[slot] -= delta
		if _cooldowns[slot] <= 0.0:
			_cooldowns.erase(slot)

func _setup_default_skills() -> void:
	# Slot 3 (Key 4)
	_skills[3] = SkillDataScript.create("relampago", "Relámpago", "⚡", "4", 15, 3.0, 0.0, 45.0, 18.0)
	# Slot 4 (Key 5)
	_skills[4] = SkillDataScript.create("fuego", "Bola de Fuego", "🔥", "5", 25, 4.5, 1.0, 75.0, 18.0)
	# Slot 5 (Key 6)
	_skills[5] = SkillDataScript.create("escarcha", "Escarcha", "❄", "6", 20, 5.0, 0.0, 40.0, 16.0, false, "slow", 3.0, 35.0)
	# Slot 6 (Key 7)
	_skills[6] = SkillDataScript.create("rayo_solar", "Rayo Solar", "✨", "7", 30, 6.0, 1.2, 90.0, 20.0)
	# Slot 7 (Key 8)
	_skills[7] = SkillDataScript.create("meteorito", "Meteorito", "☄", "8", 45, 8.0, 1.5, 130.0, 20.0)
	# Slot 8 (Key 9)
	_skills[8] = SkillDataScript.create("torbellino", "Torbellino", "🌪", "9", 25, 5.0, 0.0, 55.0, 6.0, true)
	# Slot 9 (Key 0)
	_skills[9] = SkillDataScript.create("sangrado", "Tajo Sangriento", "🩸", "0", 20, 4.0, 0.0, 50.0, 15.0, false, "bleed", 4.0, 10.0)

## Activa la acción o habilidad asociada al slot dado (0-11)
func activate_slot(slot_idx: int, target: Node3D = null, cast_bar: Control = null, hotbar: Control = null) -> bool:
	if _parent_body == null:
		_parent_body = get_parent() as CharacterBody3D

	# 1. Comprobación de Stun (Aturdimiento)
	var status_ctrl: Node = _parent_body.get_node_or_null("StatusEffectController") if _parent_body else null
	if status_ctrl and status_ctrl.has_method("is_stunned") and status_ctrl.is_stunned():
		skill_cast_failed.emit("Aturdido")
		return false

	# 2. Slot 0: Ataque básico
	if slot_idx == 0:
		if _parent_body and _parent_body.has_method("attack_target"):
			_parent_body.attack_target(target)
		return true

	# 3. Slot 1: Dash (espacio)
	if slot_idx == 1:
		return true

	# 4. Slot 2: Guardia (shift)
	if slot_idx == 2:
		var ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
		if ct:
			ct.is_guarding = not ct.is_guarding
		return true

	# 5. Slots 10 y 11: Pociones
	if slot_idx == 10:
		var ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
		return _use_potion("Salud", ct)
	if slot_idx == 11:
		var ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
		return _use_potion("Maná", ct)

	# 6. Habilidades de combate (Slots 3 a 9)
	if not _skills.has(slot_idx):
		return false

	var skill: RefCounted = _skills[slot_idx]

	# Enfriamiento
	if _cooldowns.has(slot_idx) and _cooldowns[slot_idx] > 0.0:
		skill_cast_failed.emit("En enfriamiento")
		return false

	# Maná suficiente
	var caster_ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
	var caster_stats: CharacterStats = caster_ct.get_stats() if caster_ct else null
	if caster_stats:
		if caster_stats.current_mp < skill.mana_cost:
			skill_cast_failed.emit("Maná insuficiente")
			return false

	# Validación de objetivo
	if not skill.is_aoe:
		if target == null or not is_instance_valid(target):
			skill_cast_failed.emit("Sin objetivo seleccionado")
			return false

		# Rango
		var dist := _parent_body.global_position.distance_to(target.global_position)
		if dist > skill.range_distance:
			skill_cast_failed.emit("Objetivo fuera de alcance")
			return false

	# Canalización con CastBar
	if skill.cast_time > 0.0 and cast_bar != null:
		_pending_cast_slot = slot_idx
		_pending_cast_target = target
		_pending_hotbar = hotbar

		cast_bar.start_cast(skill.name, skill.cast_time)

		if not cast_bar.cast_completed.is_connected(_on_cast_bar_completed):
			cast_bar.cast_completed.connect(_on_cast_bar_completed, CONNECT_ONE_SHOT)
		if not cast_bar.cast_interrupted.is_connected(_on_cast_bar_interrupted):
			cast_bar.cast_interrupted.connect(_on_cast_bar_interrupted, CONNECT_ONE_SHOT)

		skill_cast_started.emit(skill, target)
		return true

	# Lanzamiento instantáneo
	_execute_skill(skill, slot_idx, target, hotbar)
	return true

func _on_cast_bar_completed(_skill_name: String) -> void:
	if _pending_cast_slot < 0 or not _skills.has(_pending_cast_slot):
		return
	var skill: RefCounted = _skills[_pending_cast_slot]
	_execute_skill(skill, _pending_cast_slot, _pending_cast_target, _pending_hotbar)
	_pending_cast_slot = -1
	_pending_cast_target = null
	_pending_hotbar = null

func _on_cast_bar_interrupted(_skill_name: String) -> void:
	_pending_cast_slot = -1
	_pending_cast_target = null
	_pending_hotbar = null

func _execute_skill(skill: RefCounted, slot_idx: int, target: Node3D, hotbar: Control = null) -> void:
	if _parent_body == null:
		return

	var caster_ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget
	var caster_stats: CharacterStats = caster_ct.get_stats() if caster_ct else null

	# Deducción de maná
	if caster_stats and skill.mana_cost > 0:
		caster_stats.current_mp = maxi(0, caster_stats.current_mp - skill.mana_cost)

	# Registrar cooldown
	_cooldowns[slot_idx] = skill.cooldown
	if hotbar and hotbar.has_method("trigger_cooldown"):
		hotbar.trigger_cooldown(slot_idx, skill.cooldown)

	# Animación visual del lanzador
	var visuals: Node = _parent_body.get_node_or_null("Visuals") if _parent_body else null
	if visuals and visuals.has_method("play_attack"):
		visuals.play_attack(1.2)

	# Aplicar daño al objetivo o área
	if skill.is_aoe:
		_execute_aoe_damage(skill, caster_stats)
	else:
		_execute_single_target_damage(skill, caster_stats, target)

	skill_cast_finished.emit(skill, target)

func _execute_single_target_damage(skill: RefCounted, caster_stats: CharacterStats, target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	var target_ct := target.get_node_or_null("CombatTarget") as CombatTarget
	if target_ct == null:
		return

	var target_stats := target_ct.get_stats()
	var dmg_result := CombatCalculatorScript.calculate_skill_damage(caster_stats, target_stats, skill.flat_damage)

	var hit_pos := target.global_position + Vector3(0.0, 1.0, 0.0)
	target_ct.take_combat_result(dmg_result, hit_pos, _parent_body)

	# Efectos de estado
	if skill.effect_type != "":
		var target_status := target.get_node_or_null("StatusEffectController")
		if target_status:
			if skill.effect_type == "slow" and target_status.has_method("apply_slow"):
				target_status.apply_slow(skill.effect_value, skill.effect_duration)
			elif skill.effect_type == "bleed" and target_status.has_method("apply_bleed"):
				target_status.apply_bleed(int(skill.effect_value), skill.effect_duration)
			elif skill.effect_type == "stun" and target_status.has_method("apply_stun"):
				target_status.apply_stun(skill.effect_duration)

func _execute_aoe_damage(skill: RefCounted, caster_stats: CharacterStats) -> void:
	var tree := _parent_body.get_tree()
	if tree == null:
		return

	var targets := tree.get_nodes_in_group("targetable")
	for node in targets:
		if node == _parent_body or node == _parent_body.get_node_or_null("CombatTarget"):
			continue
		var target_node: Node3D = node as Node3D
		if target_node == null and node.get_parent() is Node3D:
			target_node = node.get_parent() as Node3D
		if target_node and is_instance_valid(target_node):
			var dist := _parent_body.global_position.distance_to(target_node.global_position)
			if dist <= skill.aoe_radius:
				_execute_single_target_damage(skill, caster_stats, target_node)

func _use_potion(type_str: String, combat_target: CombatTarget) -> bool:
	var inv_ctrl := _parent_body.get_node_or_null("InventoryController") as InventoryController if _parent_body else null
	if inv_ctrl == null:
		return false
	for i in range(20):
		var item := inv_ctrl.get_item(i)
		if item != null and item.item_type == ItemData.ItemType.CONSUMABLE:
			if item.item_name.findn(type_str) != -1 or item.sub_type.findn(type_str) != -1:
				inv_ctrl.use_consumable_at(i, combat_target)
				return true
	return false
