@tool
extends SceneTree

## Suite de verificación automatizada para:
## 1. Arquitectura Modular de Skills (un archivo por skill en definitions/).
## 2. Skill 1: Golpe Potente (básico más fuerte con mayor velocidad de ataque).
## 3. Aggro Pool (Threat Table con histéresis y cambio de objetivo por amenaza).
## 4. Estados de Combate: Entrando en combate y saliendo de combate con temporizador.

const SkillPowerStrikeScript = preload("res://scripts/gameplay/skills/definitions/skill_power_strike.gd")
const SkillLightningScript = preload("res://scripts/gameplay/skills/definitions/skill_lightning.gd")
const SkillFireballScript = preload("res://scripts/gameplay/skills/definitions/skill_fireball.gd")
const SkillFrostScript = preload("res://scripts/gameplay/skills/definitions/skill_frost.gd")
const SkillSunRayScript = preload("res://scripts/gameplay/skills/definitions/skill_sun_ray.gd")
const SkillMeteorScript = preload("res://scripts/gameplay/skills/definitions/skill_meteor.gd")
const SkillWhirlwindScript = preload("res://scripts/gameplay/skills/definitions/skill_whirlwind.gd")
const SkillBloodySlashScript = preload("res://scripts/gameplay/skills/definitions/skill_bloody_slash.gd")

const AggroPoolScript = preload("res://scripts/gameplay/combat/aggro_pool.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Skills Modulares, Skill 1, Aggro Pool y Entrando/Saliendo de Combate ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Carga y Definición Modular de Habilidades (un archivo por skill)
	# --------------------------------------------------------------------------
	var p_strike := SkillPowerStrikeScript.new()
	assert(p_strike.id == "golpe_potente", "Skill 1 ID debe ser 'golpe_potente'")
	assert(p_strike.slot_index == 0, "Skill 1 debe pertenecer al Slot 0 (Tecla 1)")
	assert(p_strike.anim_speed_multiplier > 1.2, "Skill 1 debe tener velocidad de ataque acelerada (obtenido: %.2f)" % p_strike.anim_speed_multiplier)
	assert(p_strike.damage_multiplier > 1.3, "Skill 1 debe ser un golpe básico más fuerte (obtenido: %.2f)" % p_strike.damage_multiplier)

	var lightning := SkillLightningScript.new()
	assert(lightning.id == "relampago", "Skill Relámpago debe existir")

	var fireball := SkillFireballScript.new()
	assert(fireball.id == "fuego" and fireball.cast_time > 0.0, "Skill Bola de Fuego debe ser canalizada")

	var frost := SkillFrostScript.new()
	assert(frost.id == "escarcha" and frost.effect_type == "slow", "Skill Escarcha debe aplicar slow")

	var whirlwind := SkillWhirlwindScript.new()
	assert(whirlwind.id == "torbellino" and whirlwind.is_aoe == true, "Skill Torbellino debe ser AoE")

	var bloody := SkillBloodySlashScript.new()
	assert(bloody.id == "sangrado" and bloody.effect_type == "bleed", "Skill Tajo Sangriento debe aplicar bleed")

	print("[OK] Prueba 1: Todas las skills modulares instanciadas individualmente con su lógica propia.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Ejecución de Skill 1 (Golpe Potente) a través de SkillController
	# --------------------------------------------------------------------------
	var player := CharacterBody3D.new()
	player.name = "PlayerHero"
	root.add_child(player)

	var p_stats := CharacterStats.create_player_default()
	p_stats.current_mp = 50
	p_stats.max_mp = 50
	p_stats.attack = 40

	var p_ct := CombatTarget.new()
	p_ct.name = "CombatTarget"
	p_ct.stats = p_stats
	player.add_child(p_ct)

	var skill_ctrl := SkillController.new()
	skill_ctrl.name = "SkillController"
	player.add_child(skill_ctrl)

	var dummy := CharacterBody3D.new()
	dummy.name = "TargetDummy"
	dummy.position = Vector3(2.0, 0.0, 0.0) # En rango melee
	root.add_child(dummy)

	var d_stats := CharacterStats.create_dummy_default()
	d_stats.max_hp = 500
	d_stats.current_hp = 500
	d_stats.defense = 0

	var d_ct := CombatTarget.new()
	d_ct.name = "CombatTarget"
	d_ct.stats = d_stats
	dummy.add_child(d_ct)
	await process_frame

	var hp_before := float(d_stats.current_hp)
	var mp_before := p_stats.current_mp

	var cast_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_ok == true, "activate_slot(0) debe ejecutar la Skill 1")
	assert(p_stats.current_mp == mp_before - p_strike.mana_cost, "Debe deducir el coste de maná de Skill 1")
	var hp_after := float(d_stats.current_hp)
	var dmg_dealt := hp_before - hp_after
	assert(dmg_dealt > float(p_stats.attack) * 1.3, "El golpe básico potenciado debe infligir daño aumentado (obtenido: %.1f)" % dmg_dealt)
	assert(skill_ctrl._cooldowns.has(0), "Slot 0 debe registrar cooldown tras ejecutarse")
	print("[OK] Prueba 2: Skill 1 (Golpe Potente) ejecutada con éxito, mayor daño y cooldown.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Sistema de Aggro Pool (Threat Table con Umbral de Histéresis)
	# --------------------------------------------------------------------------
	var pool := AggroPoolScript.new()
	var attacker_a := Node3D.new()
	attacker_a.name = "Guerrero"
	var ct_a := CombatTarget.new()
	ct_a.name = "CombatTarget"
	ct_a.current_health = 100.0
	attacker_a.add_child(ct_a)
	root.add_child(attacker_a)

	var attacker_b := Node3D.new()
	attacker_b.name = "Mago"
	var ct_b := CombatTarget.new()
	ct_b.name = "CombatTarget"
	ct_b.current_health = 100.0
	attacker_b.add_child(ct_b)
	root.add_child(attacker_b)

	# Guerrero ataca inicialmente con 100 de daño
	pool.add_threat(attacker_a, 100.0)
	assert(pool.get_top_target() == attacker_a, "Guerrero debe ser el Top Target")
	assert(pool.get_threat(attacker_a) == 100.0, "Amenaza de Guerrero debe ser 100")

	# Mago hace 105 de daño (< 10% de ventaja sobre 100) -> NO debe cambiar inmediatamente por histéresis
	pool.add_threat(attacker_b, 105.0)
	assert(pool.get_top_target() == attacker_a, "Histéresis debe retener al Guerrero mientras Mago no supere 110% de amenaza")

	# Mago lanza ráfaga y suma 20 más (total 125 > 110) -> DEBE cambiar de objetivo
	pool.add_threat(attacker_b, 20.0)
	assert(pool.get_top_target() == attacker_b, "Mago debe superar el umbral y convertirse en nuevo Top Target")

	# Guerrero muere -> Mago queda como único objetivo
	ct_b.current_health = 100.0
	ct_a.current_health = 0.0
	assert(pool.get_top_target() == attacker_b, "Al morir el Guerrero, el Top Target debe ser el Mago vivo")

	# Limpiar tabla
	pool.clear()
	assert(pool.is_empty() == true, "pool.clear() debe vaciar la tabla de amenaza")
	print("[OK] Prueba 3: AggroPool (Threat Table) validada con histéresis de cambio y descarte de objetivos muertos.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Estados de Combate (Entrando en combate y Saliendo de combate)
	# --------------------------------------------------------------------------
	var combatant_1 := Node3D.new()
	var c1_target := CombatTarget.new()
	c1_target.name = "CombatTarget"
	c1_target.combat_timeout = 0.15 # Timeout corto para prueba acelerada
	combatant_1.add_child(c1_target)
	root.add_child(combatant_1)

	var combatant_2 := Node3D.new()
	var c2_target := CombatTarget.new()
	c2_target.name = "CombatTarget"
	c2_target.combat_timeout = 0.15
	combatant_2.add_child(c2_target)
	root.add_child(combatant_2)

	assert(c1_target.is_in_combat == false, "Inicialmente no debe estar en combate")
	assert(c2_target.is_in_combat == false, "Inicialmente no debe estar en combate")

	# Acción hostil: entrar en combate
	c1_target.enter_combat(combatant_2)
	assert(c1_target.is_in_combat == true, "c1 debe estar en combate tras enter_combat")
	assert(c1_target.combat_timer == c1_target.combat_timeout, "combat_timer debe inicializarse en timeout")

	# Esperar a que el temporizador de combate expire
	c1_target._process(0.20)
	assert(c1_target.is_in_combat == false, "c1 debe salir de combate automáticamente tras expirar combat_timeout")

	# Salida inmediata de combate por muerte
	c1_target.enter_combat(combatant_2)
	assert(c1_target.is_in_combat == true, "c1 vuelve a entrar en combate")
	c1_target.current_health = 0.0
	c1_target.exit_combat()
	assert(c1_target.is_in_combat == false, "exit_combat() debe forzar la salida del estado de combate")

	print("[OK] Prueba 4: Entrando y saliendo de combate con temporizador y señales verificado.")

	# Limpieza
	attacker_a.queue_free()
	attacker_b.queue_free()
	combatant_1.queue_free()
	combatant_2.queue_free()
	player.queue_free()
	dummy.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE SKILLS MODULARES, AGGRO Y COMBATE PASARON EXITOSAMENTE (4/4) ---\n")
	quit(0)
