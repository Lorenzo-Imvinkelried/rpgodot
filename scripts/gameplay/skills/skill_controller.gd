class_name SkillController
extends Node

## Responsabilidad: Orquestador y despachador de habilidades activas del jugador o entidad.
## Carga definiciones modulares de habilidades (definitions/), administra cooldowns,
## valida rangos y maná, coordina casteo con CastBar y ejecuta la lógica polimórfica de cada skill.

signal skill_cast_started(skill: RefCounted, target: Node3D)
signal skill_cast_finished(skill: RefCounted, target: Node3D)
signal skill_cast_failed(reason: String)

const SkillPowerStrikeScript = preload("res://scripts/gameplay/skills/definitions/skill_power_strike.gd")
const SkillLightningScript = preload("res://scripts/gameplay/skills/definitions/skill_lightning.gd")
const SkillFireballScript = preload("res://scripts/gameplay/skills/definitions/skill_fireball.gd")
const SkillFrostScript = preload("res://scripts/gameplay/skills/definitions/skill_frost.gd")
const SkillSunRayScript = preload("res://scripts/gameplay/skills/definitions/skill_sun_ray.gd")
const SkillMeteorScript = preload("res://scripts/gameplay/skills/definitions/skill_meteor.gd")
const SkillWhirlwindScript = preload("res://scripts/gameplay/skills/definitions/skill_whirlwind.gd")
const SkillBloodySlashScript = preload("res://scripts/gameplay/skills/definitions/skill_bloody_slash.gd")

var _skills: Dictionary = {} # slot_index (int) -> BaseSkill
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
	# Slot 0 (Key 1): Skill 1 - Golpe Potente (básico más fuerte y rápido)
	_skills[0] = SkillPowerStrikeScript.new()
	# Slot 3 (Key 4): Relámpago
	_skills[3] = SkillLightningScript.new()
	# Slot 4 (Key 5): Bola de Fuego
	_skills[4] = SkillFireballScript.new()
	# Slot 5 (Key 6): Escarcha
	_skills[5] = SkillFrostScript.new()
	# Slot 6 (Key 7): Rayo Solar
	_skills[6] = SkillSunRayScript.new()
	# Slot 7 (Key 8): Meteorito
	_skills[7] = SkillMeteorScript.new()
	# Slot 8 (Key 9): Torbellino
	_skills[8] = SkillWhirlwindScript.new()
	# Slot 9 (Key 0): Tajo Sangriento
	_skills[9] = SkillBloodySlashScript.new()

## Registra o reemplaza una habilidad en un slot específico
func register_skill(slot_idx: int, skill: BaseSkill) -> void:
	if skill != null:
		skill.slot_index = slot_idx
		_skills[slot_idx] = skill

## Retorna la habilidad asignada a un slot específico
func get_skill(slot_idx: int) -> BaseSkill:
	return _skills.get(slot_idx, null)

## Retorna el diccionario completo de habilidades registradas
func get_all_skills() -> Dictionary:
	return _skills

## Activa la acción o habilidad asociada al slot dado (0-11)
func activate_slot(slot_idx: int, target: Node3D = null, cast_bar: Control = null, hotbar: Control = null) -> bool:
	if _parent_body == null:
		_parent_body = get_parent() as CharacterBody3D

	# 1. Comprobación de Stun (Aturdimiento)
	var status_ctrl: Node = _parent_body.get_node_or_null("StatusEffectController") if _parent_body else null
	if status_ctrl and status_ctrl.has_method("is_stunned") and status_ctrl.is_stunned():
		skill_cast_failed.emit("Aturdido")
		return false

	# 2. Slot 0: Skill 1 (Golpe Potente - básico más fuerte y veloz)
	if slot_idx == 0:
		return _activate_skill_1(target, hotbar)

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

	var skill: BaseSkill = _skills[slot_idx]

	# Enfriamiento
	if _cooldowns.has(slot_idx) and _cooldowns[slot_idx] > 0.0:
		skill_cast_failed.emit("En enfriamiento")
		return false

	# Validación de condiciones (maná, rango, objetivo)
	var caster_ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
	var caster_stats: CharacterStats = caster_ct.get_stats() if caster_ct else null

	var check_result: Dictionary = skill.can_cast(_parent_body, target, caster_stats)
	if not check_result.get("ok", false):
		skill_cast_failed.emit(check_result.get("reason", "Lanzamiento inválido"))
		return false

	# Canalización con CastBar si la habilidad tiene tiempo de casteo
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

## Maneja la ejecución de la Skill 1 (Golpe Potente)
func _activate_skill_1(target: Node3D, hotbar: Control) -> bool:
	var skill: BaseSkill = _skills.get(0, null)
	if skill == null:
		return false

	# 1. Comprobación de Enfriamiento: NUNCA atacar ni activar autoataque si está en cooldown
	if _cooldowns.has(0) and _cooldowns[0] > 0.0:
		skill_cast_failed.emit("En enfriamiento")
		return false

	# 2. Si no se pasó objetivo explícito, tomar el objetivo actual de combate
	var combat_ctrl: Node = _parent_body.get_node_or_null("CombatController") if _parent_body else null
	if target == null and combat_ctrl and "current_target" in combat_ctrl:
		target = combat_ctrl.current_target

	# 3. Comprobación de existencia del objetivo
	if target == null or not is_instance_valid(target):
		skill_cast_failed.emit("Sin objetivo seleccionado")
		return false

	# 4. Comprobación de Rango considerando tamaño del objetivo
	var dist := _parent_body.global_position.distance_to(target.global_position)
	var max_range := skill.range_distance
	if combat_ctrl and combat_ctrl.has_method("get_effective_attack_range"):
		max_range = maxf(max_range, combat_ctrl.get_effective_attack_range(target))
	if dist > max_range:
		skill_cast_failed.emit("Objetivo fuera de alcance")
		return false

	# 5. Validar maná
	var caster_ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget if _parent_body else null
	var caster_stats: CharacterStats = caster_ct.get_stats() if caster_ct else null
	if caster_stats and caster_stats.current_mp < skill.mana_cost:
		skill_cast_failed.emit("Maná insuficiente")
		return false

	_execute_skill(skill, 0, target, hotbar)
	return true

func _on_cast_bar_completed(_skill_name: String) -> void:
	if _pending_cast_slot < 0 or not _skills.has(_pending_cast_slot):
		return
	var skill: BaseSkill = _skills[_pending_cast_slot]
	_execute_skill(skill, _pending_cast_slot, _pending_cast_target, _pending_hotbar)
	_pending_cast_slot = -1
	_pending_cast_target = null
	_pending_hotbar = null

func _on_cast_bar_interrupted(_skill_name: String) -> void:
	_pending_cast_slot = -1
	_pending_cast_target = null
	_pending_hotbar = null

func _execute_skill(skill: BaseSkill, slot_idx: int, target: Node3D, hotbar: Control = null) -> void:
	if _parent_body == null:
		return

	var caster_ct := _parent_body.get_node_or_null("CombatTarget") as CombatTarget
	var caster_stats: CharacterStats = caster_ct.get_stats() if caster_ct else null

	# Registrar cooldown
	if skill.cooldown > 0.0:
		_cooldowns[slot_idx] = skill.cooldown
		if hotbar and hotbar.has_method("trigger_cooldown"):
			hotbar.trigger_cooldown(slot_idx, skill.cooldown)

	# Delegar ejecución lógica y efectos a la instancia polimórfica de la skill
	skill.execute(_parent_body, target, caster_stats, get_tree())

	skill_cast_finished.emit(skill, target)

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
