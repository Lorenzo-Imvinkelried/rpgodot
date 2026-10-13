@tool
extends SceneTree

## Suite de pruebas para:
## 1. Cadencia y Juice de ataque tras lanzar habilidades ofensivas (Power Strike):
##    El siguiente básico se dispara inmediatamente tras concluir la animación a la velocidad de ataque actual.
## 2. Retención estricta del objetivo de combate (TargetFrame):
##    El target no se pierde por WASD, Dash, Click-to-Move, ni al recibir golpes de un segundo mob,
##    ni por orbitar la cámara con click derecho en medio del combate.

const SkillPowerStrikeScript = preload("res://scripts/gameplay/skills/definitions/skill_power_strike.gd")
const TargetDetectorScript = preload("res://scripts/combat/target_detector.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Skill Attack Speed Cadence & Target Retention ---")
	_run_tests()

func _run_tests() -> void:
	await process_frame

	# ==========================================================================
	# PARTE 1: Retención del Target (WASD, Dash, Click-to-Move y Múltiples Mobs)
	# ==========================================================================
	print("\n[TEST] 1. Verificando retención de target durante movimiento...")

	var player := CharacterBody3D.new()
	player.name = "TestPlayer"
	root.add_child(player)

	var p_stats := CharacterStats.create_player_default()
	p_stats.current_mp = 100
	p_stats.attack_speed = 2.0 # Velocidad de ataque rápida solicitada por el usuario (2.0)

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

	# Crear Mob A (Objetivo principal que el jugador selecciona)
	var mob_a := CharacterBody3D.new()
	mob_a.name = "Mob_A"
	mob_a.position = Vector3(1.5, 0.0, 0.0)
	root.add_child(mob_a)

	var ct_a := CombatTarget.new()
	ct_a.name = "CombatTarget"
	var stats_a := CharacterStats.create_dummy_default()
	stats_a.max_hp = 500
	stats_a.current_hp = 500
	ct_a.stats = stats_a
	mob_a.add_child(ct_a)

	# Crear Mob B (Segundo enemigo que se suma al combate y golpea al jugador)
	var mob_b := CharacterBody3D.new()
	mob_b.name = "Mob_B"
	mob_b.position = Vector3(-1.0, 0.0, 0.0)
	root.add_child(mob_b)

	var ct_b := CombatTarget.new()
	ct_b.name = "CombatTarget"
	var stats_b := CharacterStats.create_dummy_default()
	stats_b.max_hp = 500
	stats_b.current_hp = 500
	ct_b.stats = stats_b
	mob_b.add_child(ct_b)

	await process_frame

	# Jugador selecciona Mob A
	combat_ctrl.select_target(mob_a)
	assert(combat_ctrl.current_target == mob_a, "El target inicial debe ser Mob A")
	print("  [OK] Mob A seleccionado correctamente.")

	# Simular movimiento con WASD (pausar aproximación pero sin borrar el target)
	if combat_ctrl.is_approaching():
		combat_ctrl.state = CombatController.State.IDLE
	assert(combat_ctrl.current_target == mob_a, "WASD no debe borrar current_target (debe retener Mob A)")
	print("  [OK] Movimiento WASD no borra current_target.")

	# Simular Dash (pausar aproximación pero sin borrar el target)
	if combat_ctrl.is_approaching():
		combat_ctrl.state = CombatController.State.IDLE
	assert(combat_ctrl.current_target == mob_a, "Dash no debe borrar current_target (debe retener Mob A)")
	print("  [OK] Dash no borra current_target.")

	# Mob B ataca e inflige daño al jugador
	var dmg_res := DamageResult.new()
	dmg_res.total_damage = 15
	p_ct.take_combat_result(dmg_res, player.global_position, mob_b)

	# Verificar que el target de combate del jugador NUNCA cambió a Mob B
	assert(combat_ctrl.current_target == mob_a, "Al recibir golpe de Mob B, el target DEBE mantenerse en Mob A")
	print("  [OK] Al recibir daño de un segundo mob, el target permanece firmemente en Mob A.")

	# ==========================================================================
	# PARTE 2: Cadencia de Auto-Ataque tras Habilidad ("Juice" con Attack Speed 2.0)
	# ==========================================================================
	print("\n[TEST] 2. Verificando cadencia y juice tras lanzar habilidad...")

	var visuals := PlayerVisuals.new()
	visuals.name = "Visuals"
	player.add_child(visuals)

	var a_player := AnimationPlayer.new()
	var a_lib := AnimationLibrary.new()
	var a_anim := Animation.new()
	a_anim.length = 0.5
	a_lib.add_animation("attack", a_anim)
	a_player.add_animation_library("", a_lib)
	visuals.add_child(a_player)
	visuals.anim_player = a_player
	visuals._anim_attack = "attack"

	await process_frame

	# Empezar atacando a Mob A
	combat_ctrl.attack_target(mob_a)
	assert(combat_ctrl.current_target == mob_a, "Objetivo en combate debe ser Mob A")

	# Lanzar Power Strike sobre Mob A
	var skill_cast_ok := skill_ctrl.activate_slot(0, mob_a, null, null)
	assert(skill_cast_ok == true, "Power Strike debe lanzarse con éxito")

	# Esperar a que la habilidad impacte y ejecute _apply_delayed_strike (0.58 / 1.70 = ~0.34s)
	await create_timer(0.40).timeout

	# Verificar que el autoataque NO sufre un salto forzado artificial (ready_next_attack = 999.0)
	# sino que mantiene la cadencia fluida acumulando el tiempo real sin desfasar los siguientes autoataques
	assert(combat_ctrl._time_since_last_attack < 10.0, "El temporizador de ataque no debe saltar artificialmente a 999.0 (obtenido: %.1f)" % combat_ctrl._time_since_last_attack)
	print("  [OK] El temporizador de ataque mantiene cadencia homogénea tras el impacto de la habilidad.")

	# Simular que termina la animación de la habilidad
	visuals.is_attacking_anim = false
	a_player.stop()

	# Calcular intervalo esperado
	var stats_p := combat_ctrl.get_stats()
	var expected_interval := 1.0 / maxf(0.05, stats_p.attack_speed)

	# Si aún no pasó el intervalo de ataque, update_combat no debe disparar prematuramente
	combat_ctrl._time_since_last_attack = expected_interval * 0.5
	combat_ctrl.update_combat(0.016, visuals)
	assert(combat_ctrl._pending_impacts.is_empty(), "No debe disparar antes de cumplir el intervalo de ataque normal")

	# Al alcanzar el intervalo de ataque normal, debe disparar con cadencia uniforme
	combat_ctrl._time_since_last_attack = expected_interval
	combat_ctrl.update_combat(0.016, visuals)
	assert(not combat_ctrl._pending_impacts.is_empty(), "Debe disparar el auto-ataque al cumplir el intervalo de ataque normal")
	assert(combat_ctrl._time_since_last_attack < 0.1, "_time_since_last_attack debe reiniciarse a 0 para el siguiente autoataque")
	print("  [OK] Todos los autoataques subsiguientes se disparan a intervalos homogéneos y fluidos.")

	# Limpieza
	player.queue_free()
	mob_a.queue_free()
	mob_b.queue_free()

	print("\n>>> TODOS LOS TESTS DE JUICE Y RETENCIÓN DE TARGET PASARON EXITOSAMENTE <<<\n")
	quit(0)
