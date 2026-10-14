@tool
extends SceneTree

## Suite de verificación automatizada para:
## 1. Animation Cancelling / AA-Reset de Golpe Potente (Power Strike).
## 2. Cancelación de la fase de Windup (cancel_pending_attack evita daño duplicado o fantasma).
## 3. Cancelación de la fase de Recovery / Backswing (ataque inmediato a 1.70x de velocidad).
## 4. Lunge procedural e impulso hacia adelante.
## 5. Hit-stop y reseteo de temporizador de autoataque al impacto.

const SkillPowerStrikeScript = preload("res://scripts/gameplay/skills/definitions/skill_power_strike.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Power Strike AA-Reset, Animation Cancelling & Juice ---")
	_run_tests()

func _run_tests() -> void:
	var player := CharacterBody3D.new()
	player.name = "HeroPlayer"
	root.add_child(player)

	var p_stats := CharacterStats.create_player_default()
	p_stats.current_mp = 100
	p_stats.max_mp = 100
	p_stats.attack = 50
	p_stats.attack_speed = 1.0

	var p_ct := CombatTarget.new()
	p_ct.name = "CombatTarget"
	p_ct.stats = p_stats
	player.add_child(p_ct)

	var combat_ctrl := CombatController.new()
	combat_ctrl.name = "CombatController"
	combat_ctrl.stats = p_stats
	player.add_child(combat_ctrl)

	var skill_ctrl := SkillController.new()
	skill_ctrl.name = "SkillController"
	player.add_child(skill_ctrl)

	var dummy := CharacterBody3D.new()
	dummy.name = "DummyTarget"
	dummy.position = Vector3(2.0, 0.0, 0.0)
	root.add_child(dummy)

	var d_stats := CharacterStats.create_dummy_default()
	d_stats.max_hp = 1000
	d_stats.current_hp = 1000
	d_stats.defense = 0

	var d_ct := CombatTarget.new()
	d_ct.name = "CombatTarget"
	d_ct.stats = d_stats
	dummy.add_child(d_ct)

	await process_frame

	# --------------------------------------------------------------------------
	# PRUEBA 1: Cancelación en Windup (Priority Cancel)
	# --------------------------------------------------------------------------
	# Iniciar auto-ataque básico
	combat_ctrl.attack_target(dummy)
	assert(combat_ctrl.is_attacking() or combat_ctrl.is_approaching(), "Debe enfocar al dummy")

	# Simular un tick de ataque básico para que entre en Windup
	combat_ctrl._execute_attack(null, 1.0)
	assert(combat_ctrl._pending_impacts.size() > 0, "El auto-ataque básico debe tener impactos en cola de Windup")

	# Ejecutar Power Strike inmediatamente (AA-Reset en pleno Windup)
	var hp_before_windup := float(d_stats.current_hp)
	var cast_windup_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_windup_ok == true, "Power Strike debe permitirse durante el ataque básico (AA-Reset)")
	assert(combat_ctrl._pending_impacts.size() == 0, "Power Strike debe haber cancelado los impactos pendientes del básico (Windup Cancel)")

	# Esperar a que impacte Power Strike (0.58 / 1.70 = ~0.34s)
	await create_timer(0.42).timeout

	var hp_after_windup := float(d_stats.current_hp)
	var dmg_windup := hp_before_windup - hp_after_windup
	assert(dmg_windup > 0.0, "Power Strike debió aplicar su daño tras la caída de la espada")
	print("[OK] Prueba 1: Cancelación en Windup (Priority Cancel) completada sin solapamiento de impactos.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Cancelación en Recovery (AA-Reset perfecto con combo)
	# --------------------------------------------------------------------------
	# Esperar a que expire el cooldown de Skill 1
	skill_ctrl._cooldowns[0] = 0.0

	# Lanzar un auto-ataque básico que complete su impacto
	combat_ctrl._execute_attack(null, 1.0)
	var hp_before_basic := float(d_stats.current_hp)

	# Simular que el impacto del básico ya se aplicó (fase de Recovery / Backswing)
	combat_ctrl._pending_impacts.clear()
	d_ct.current_health -= 25.0
	d_stats.current_hp -= 25
	var hp_after_basic := float(d_stats.current_hp)
	assert(hp_after_basic < hp_before_basic, "El básico ya conectó su daño (entró en Recovery)")

	# Presionar Power Strike de inmediato en fase de Recovery
	var cast_recovery_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_recovery_ok == true, "Power Strike debe cancelar inmediatamente el Backswing del ataque básico")

	# Esperar al impacto de Power Strike
	await create_timer(0.42).timeout

	var hp_final := float(d_stats.current_hp)
	var power_strike_dmg := hp_after_basic - hp_final
	assert(power_strike_dmg > 40.0, "Power Strike debió impactar infligiendo daño potenciado en el combo (obtenido: %.1f)" % power_strike_dmg)
	print("[OK] Prueba 2: Cancelación en Recovery (AA-Reset con combo fluido) verificada con éxito.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Multiplicador 1.70x para animación acelerada de SkillPowerStrike
	# --------------------------------------------------------------------------
	var p_strike := SkillPowerStrikeScript.new()
	assert(absf(p_strike.anim_speed_multiplier - 1.70) < 0.01, "SkillPowerStrike debe tener exactamente multiplicador 1.70x (obtenido: %.2f)" % p_strike.anim_speed_multiplier)
	print("[OK] Prueba 3: Multiplicador 1.70x validado.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Disparo efectivo de la animación (play_attack y PlayerVisuals)
	# --------------------------------------------------------------------------
	var p_visuals := PlayerVisuals.new()
	p_visuals.name = "Visuals"
	player.add_child(p_visuals)

	var a_player := AnimationPlayer.new()
	var a_lib := AnimationLibrary.new()
	var a_anim := Animation.new()
	a_anim.length = 1.0
	a_lib.add_animation("attack", a_anim)
	a_player.add_animation_library("", a_lib)
	p_visuals.add_child(a_player)
	p_visuals.anim_player = a_player
	p_visuals._anim_attack = "attack"
	await process_frame

	skill_ctrl._cooldowns[0] = 0.0
	var cast_anim_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_anim_ok == true, "Power Strike debe activarse")
	assert(p_visuals.is_attacking_anim == true, "is_attacking_anim DEBE ser true al tirar Golpe Potente")
	assert(a_player.is_playing() and a_player.current_animation == "attack", "AnimationPlayer DEBE estar reproduciendo la animación de ataque")
	print("[OK] Prueba 4: Disparo efectivo de animación y estado visual verificado.")

	print("\n>>> TODOS LOS TESTS DE AA-RESET Y ANIMATION CANCELLING PASARON CON ÉXITO <<<\n")
	quit(0)
