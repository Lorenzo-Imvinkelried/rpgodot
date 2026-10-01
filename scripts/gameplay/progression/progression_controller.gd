class_name ProgressionController
extends Node

## Responsabilidad: Gestión del estado de experiencia, nivel y escalado de atributos del personaje.
## Administra la acumulación de EXP, calcula transiciones de nivel deterministas, incrementa estadísticas
## primarias en CharacterStats, reabastece salud y maná, y emite señales reactivas hacia la UI y efectos 3D.

signal experience_gained(amount: int, current_xp: int, xp_required: int)
signal level_up(new_level: int, stat_gains: Dictionary)

const ProgressionFormulaScript = preload("res://scripts/gameplay/progression/progression_formula.gd")

@export var current_level: int = 1
@export var current_exp: int = 0
@export var xp_required: int = 300
@export var total_exp: int = 0

var combat_target: CombatTarget = null
var stats: CharacterStats = null

func _ready() -> void:
	if combat_target == null:
		var parent_node := get_parent()
		if parent_node:
			var found_target := parent_node.get_node_or_null("CombatTarget") as CombatTarget
			if found_target:
				setup(found_target)

## Vincula el controlador de progresión al CombatTarget y CharacterStats de la entidad.
func setup(p_combat_target: CombatTarget) -> void:
	combat_target = p_combat_target
	if combat_target:
		stats = combat_target.get_stats()
		if stats:
			current_level = stats.level
	xp_required = ProgressionFormulaScript.get_xp_required_for_level(current_level)

## Añade experiencia a la entidad y evalúa si alcanza o supera el umbral de subida de nivel.
## Soporta múltiples subidas de nivel si la cantidad de EXP otorgada es masiva.
func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	current_exp += amount
	total_exp += amount
	experience_gained.emit(amount, current_exp, xp_required)

	var has_leveled_up := false
	while current_exp >= xp_required:
		current_exp -= xp_required
		current_level += 1
		has_leveled_up = true

		var gains: Dictionary = ProgressionFormulaScript.get_stat_gains(current_level)
		_apply_level_up(current_level, gains)
		xp_required = ProgressionFormulaScript.get_xp_required_for_level(current_level)
		level_up.emit(current_level, gains)

	if has_leveled_up:
		experience_gained.emit(0, current_exp, xp_required)

## Aplica el incremento de atributos y recalcula las estadísticas derivadas del personaje.
func _apply_level_up(lvl: int, gains: Dictionary) -> void:
	if stats == null and combat_target != null:
		stats = combat_target.get_stats()

	if stats:
		stats.level = lvl
		stats.base_str += int(gains.get("base_str", 2))
		stats.base_agi += int(gains.get("base_agi", 2))
		stats.base_int += int(gains.get("base_int", 2))
		stats.base_vit += int(gains.get("base_vit", 3))
		stats.recalculate_stats(false)

		# Como recompensa de subida de nivel, rellenar salud y maná al máximo
		stats.current_hp = stats.max_hp
		stats.current_mp = stats.max_mp

	if combat_target:
		if stats:
			combat_target.max_health = float(stats.max_hp)
			combat_target.current_health = float(stats.max_hp)
		combat_target.health_changed.emit(combat_target.current_health, combat_target.max_health)

## Retorna el porcentaje de avance hacia el siguiente nivel (0.0 a 1.0).
func get_progress_ratio() -> float:
	if xp_required <= 0:
		return 1.0
	return clampf(float(current_exp) / float(xp_required), 0.0, 1.0)
