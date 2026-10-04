class_name GiveStatCommand
extends "res://scripts/core/commands/command_handler.gd"

const ProgressionFormulaScript = preload("res://scripts/gameplay/progression/progression_formula.gd")

## Responsabilidad: Implementación del comando '/darme <stat> <cantidad>' (y sus alias).
## Modifica atributos base, estadísticas de combate, vitales o progresión sumando o restando (+/-)
## el valor indicado, recalculando deterministamente las estadísticas del personaje y actualizando la UI.

func _init() -> void:
	super._init(
		"darme",
		["give", "stat", "stats_add", "modificar_stat"],
		"Modifica una estadística sumando o restando una cantidad (+/-).",
		"/darme <stat> <cantidad>"
	)

func execute(context: Node, args: Array[String]) -> CommandResultScript:
	if args.size() < 2:
		var err := "Uso: /darme <stat> <cantidad>\nEjemplos:\n  /darme attack 100\n  /darme attack -50\n  /darme as 0.5\n  /darme hp 1000\n  /darme str 25\n  /darme gold 50"
		return CommandResultScript.error(err)

	var stat_name := args[0].to_lower()
	var raw_val := args[1]

	if not raw_val.is_valid_float() and not raw_val.is_valid_int():
		return CommandResultScript.error("La cantidad debe ser un valor numérico válido (ej: 100, -50, 0.5).")

	var delta := raw_val.to_float()

	# Obtener componentes del personaje desde el contexto
	var target_entity: Node = context
	if target_entity == null:
		return CommandResultScript.error("No hay un jugador o entidad de contexto seleccionada.")

	var combat_target := target_entity.get_node_or_null("CombatTarget") as CombatTarget
	var stats: CharacterStats = combat_target.get_stats() if combat_target else null
	var prog_ctrl := target_entity.get_node_or_null("ProgressionController") as ProgressionController
	var inv_ctrl := target_entity.get_node_or_null("InventoryController") as InventoryController

	if stats == null and combat_target == null:
		return CommandResultScript.error("La entidad de contexto no posee CombatTarget ni CharacterStats.")

	var old_str: String = ""
	var new_str: String = ""
	var friendly_name: String = stat_name

	match stat_name:
		# --- Atributos Primarios ---
		"str", "fuerza", "strength":
			friendly_name = "Fuerza (STR)"
			old_str = str(stats.base_str + stats.bonus_str)
			stats.bonus_str += int(delta)
			stats.recalculate_stats(false)
			new_str = str(stats.base_str + stats.bonus_str)

		"agi", "agilidad", "agility":
			friendly_name = "Agilidad (AGI)"
			old_str = str(stats.base_agi + stats.bonus_agi)
			stats.bonus_agi += int(delta)
			stats.recalculate_stats(false)
			new_str = str(stats.base_agi + stats.bonus_agi)

		"int", "inteligencia", "intelligence":
			friendly_name = "Inteligencia (INT)"
			old_str = str(stats.base_int + stats.bonus_int)
			stats.bonus_int += int(delta)
			stats.recalculate_stats(false)
			new_str = str(stats.base_int + stats.bonus_int)

		"vit", "vitalidad", "vitality":
			friendly_name = "Vitalidad (VIT)"
			old_str = str(stats.base_vit + stats.bonus_vit)
			stats.bonus_vit += int(delta)
			stats.recalculate_stats(false)
			new_str = str(stats.base_vit + stats.bonus_vit)

		# --- Ofensiva y Daño ---
		"attack", "atk", "ataque", "damage", "dmg", "poder_ataque":
			friendly_name = "Poder de Ataque"
			old_str = str(stats.attack)
			stats.base_attack += delta
			stats.recalculate_stats(false)
			new_str = str(stats.attack)

		"attack_speed", "atk_speed", "as", "vel_ataque", "velocidad_ataque":
			friendly_name = "Velocidad de Ataque"
			old_str = "%.2f" % stats.attack_speed
			stats.base_atk_speed += delta
			stats.recalculate_stats(false)
			new_str = "%.2f" % stats.attack_speed

		"crit", "crit_chance", "critico", "prob_critico":
			friendly_name = "Probabilidad Crítica"
			old_str = "%.1f%%" % stats.crit_chance
			stats.base_crit_chance += delta
			stats.recalculate_stats(false)
			new_str = "%.1f%%" % stats.crit_chance

		"crit_damage", "crit_dmg", "cdmg", "dano_critico":
			friendly_name = "Daño Crítico"
			old_str = "%.1f%%" % stats.crit_damage
			stats.base_crit_damage += delta
			stats.recalculate_stats(false)
			new_str = "%.1f%%" % stats.crit_damage

		"armor_pen", "penetracion", "pen":
			friendly_name = "Penetración de Armadura"
			old_str = str(stats.armor_pen_flat)
			stats.armor_pen_flat += delta
			new_str = str(stats.armor_pen_flat)

		# --- Defensiva y Vitales ---
		"defense", "def", "defensa", "armor", "armadura":
			friendly_name = "Defensa Física"
			old_str = str(stats.defense)
			stats.base_defense += delta
			stats.recalculate_stats(false)
			new_str = str(stats.defense)

		"max_hp", "maxhp", "hp", "vida", "health":
			friendly_name = "Vida Máxima (HP)"
			old_str = "%d/%d" % [stats.current_hp, stats.max_hp]
			stats.base_max_hp += delta
			stats.recalculate_stats(false)
			if delta > 0.0:
				stats.current_hp = mini(stats.max_hp, stats.current_hp + int(delta))
			else:
				stats.current_hp = clampi(stats.current_hp + int(delta), 1, stats.max_hp)
			combat_target.max_health = float(stats.max_hp)
			combat_target.current_health = float(stats.current_hp)
			new_str = "%d/%d" % [stats.current_hp, stats.max_hp]

		"heal", "curar", "curacion":
			friendly_name = "Salud Actual (Heal)"
			old_str = "%d/%d" % [stats.current_hp, stats.max_hp]
			stats.current_hp = clampi(stats.current_hp + int(delta), 0, stats.max_hp)
			combat_target.current_health = float(stats.current_hp)
			new_str = "%d/%d" % [stats.current_hp, stats.max_hp]

		"max_mp", "maxmp", "mp", "mana":
			friendly_name = "Maná Máximo (MP)"
			old_str = "%d/%d" % [stats.current_mp, stats.max_mp]
			stats.base_max_mp += delta
			stats.recalculate_stats(false)
			if delta > 0.0:
				stats.current_mp = mini(stats.max_mp, stats.current_mp + int(delta))
			else:
				stats.current_mp = clampi(stats.current_mp + int(delta), 0, stats.max_mp)
			new_str = "%d/%d" % [stats.current_mp, stats.max_mp]

		"block", "block_chance", "bloqueo":
			friendly_name = "Probabilidad de Bloqueo"
			old_str = "%.1f%%" % stats.block_chance
			stats.block_chance = clampf(stats.block_chance + delta, 0.0, 100.0)
			new_str = "%.1f%%" % stats.block_chance

		# --- Utilidad y Precisión ---
		"speed", "move_speed", "velocidad", "movimiento":
			friendly_name = "Velocidad de Movimiento"
			old_str = "%.1f" % stats.move_speed
			stats.move_speed = maxf(1.0, stats.move_speed + delta)
			new_str = "%.1f" % stats.move_speed
			if "config" in target_entity and target_entity.config:
				target_entity.config.forward_speed = stats.move_speed

		"accuracy", "precision", "acc":
			friendly_name = "Precisión"
			old_str = "%.1f" % stats.accuracy
			stats.base_accuracy += delta
			stats.recalculate_stats(false)
			new_str = "%.1f" % stats.accuracy

		"evasion", "esquiva", "eva":
			friendly_name = "Evasión"
			old_str = "%.1f" % stats.evasion
			stats.base_evasion += delta
			stats.recalculate_stats(false)
			new_str = "%.1f" % stats.evasion

		"lifesteal", "robo_vida":
			friendly_name = "Robo de Vida"
			old_str = "%.1f%%" % stats.lifesteal_percent
			stats.lifesteal_percent = maxf(0.0, stats.lifesteal_percent + delta)
			new_str = "%.1f%%" % stats.lifesteal_percent

		# --- Progresión y Economía ---
		"level", "lvl", "nivel":
			friendly_name = "Nivel de Personaje"
			var current_lvl := prog_ctrl.current_level if prog_ctrl else stats.level
			old_str = str(current_lvl)
			var target_lvl := maxi(1, current_lvl + int(delta))
			if prog_ctrl:
				prog_ctrl.current_level = target_lvl
				prog_ctrl.xp_required = ProgressionFormulaScript.get_xp_required_for_level(target_lvl)
			stats.level = target_lvl
			stats.recalculate_stats(true)
			new_str = str(target_lvl)
			if prog_ctrl:
				prog_ctrl.level_up.emit(target_lvl, {})

		"exp", "xp", "experiencia":
			friendly_name = "Experiencia (EXP)"
			if prog_ctrl:
				old_str = "%d/%d" % [prog_ctrl.current_exp, prog_ctrl.xp_required]
				if delta > 0:
					prog_ctrl.add_experience(int(delta))
				else:
					prog_ctrl.current_exp = maxi(0, prog_ctrl.current_exp + int(delta))
					prog_ctrl.experience_gained.emit(int(delta), prog_ctrl.current_exp, prog_ctrl.xp_required)
				new_str = "%d/%d" % [prog_ctrl.current_exp, prog_ctrl.xp_required]
			else:
				return CommandResultScript.error("El jugador no dispone de ProgressionController para gestionar EXP.")

		"gold", "oro", "dinero", "money":
			friendly_name = "Oro (Gold)"
			if inv_ctrl:
				var current_gold := float(inv_ctrl.bronze_currency) / 10000.0
				old_str = "%.2f Oro" % current_gold
				var bronze_delta := int(delta * 10000.0)
				inv_ctrl.bronze_currency = maxi(0, inv_ctrl.bronze_currency + bronze_delta)
				inv_ctrl.gold_changed.emit(inv_ctrl.bronze_currency)
				var new_gold := float(inv_ctrl.bronze_currency) / 10000.0
				new_str = "%.2f Oro" % new_gold
			else:
				return CommandResultScript.error("El jugador no dispone de InventoryController para gestionar monedas.")

		_:
			return CommandResultScript.error("Estadística '%s' no reconocida. Escribe '/ayuda' para ver las estadísticas soportadas." % stat_name)

	# Notificar a CombatTarget y UI del cambio de estadísticas
	if combat_target and stats:
		combat_target.max_health = float(stats.max_hp)
		combat_target.current_health = float(stats.current_hp)
		combat_target.health_changed.emit(combat_target.current_health, combat_target.max_health)

	# Sincronización en red multijugador si aplica
	if target_entity.has_method("sync_stats_to_network"):
		target_entity.sync_stats_to_network()

	var sign_str := "+" if delta > 0.0 else ""
	var delta_fmt := "%s%.2f" % [sign_str, delta] if fmod(delta, 1.0) != 0.0 else "%s%d" % [sign_str, int(delta)]
	var msg := "✓ %s modificado: %s -> %s (%s)" % [friendly_name, old_str, new_str, delta_fmt]

	return CommandResultScript.ok(msg, {
		"stat": stat_name,
		"friendly_name": friendly_name,
		"old_value": old_str,
		"new_value": new_str,
		"delta": delta
	})
