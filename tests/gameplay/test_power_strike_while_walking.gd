@tool
extends SceneTree

func _init() -> void:
	print("\n--- INICIANDO TEST COMPLETO: Power Strike mientras camina ---")
	_run_tests()

func _run_tests() -> void:
	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	root.add_child(player)

	var goblin_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var goblin: Node3D = goblin_scene.instantiate()
	goblin.position = Vector3(0, 0, -2.0) # En rango directo (2m)
	root.add_child(goblin)
	await process_frame

	var ap: AnimationPlayer = player.visuals.anim_player
	var skill_ctrl: SkillController = player.skill_controller
	var goblin_ct: CombatTarget = goblin.get_node_or_null("CombatTarget")

	# 1. Simular caminar hacia adelante (W / move_forward presionado)
	Input.action_press("move_forward")
	player._physics_process(0.016)
	player._process(0.016)

	assert(player.is_moving == true, "El jugador debe estar moviéndose al pulsar W")
	assert(ap.current_animation == "walk", "La animación debe ser 'walk' al caminar")
	print("[OK] Paso 1: Caminata activa (is_moving=true, anim='walk').")

	# 2. Pulsar Power Strike (Skill 1 / slot 0) contra el goblin mientras sigue caminando
	var initial_hp := goblin_ct.current_health
	var cast_ok := skill_ctrl.activate_slot(0, goblin, null, null)
	assert(cast_ok == true, "Power Strike debe activarse con éxito")

	# 3. Avanzar 1 frame de física y proceso
	player._physics_process(0.016)
	player._process(0.016)

	assert(player.visuals.is_attacking_anim == true, "is_attacking_anim DEBE ser true")
	assert(player.visuals.is_playing_attack() == true, "is_playing_attack() DEBE ser true")
	assert(ap.current_animation == "slash" or ap.current_animation == "attack", "La animación DEBE ser de ataque (obtenido: %s)" % ap.current_animation)
	assert(player.is_moving == false, "El jugador debe frenar para ejecutar el golpe de mandoble")
	print("[OK] Paso 2: Power Strike disparó la animación de golpe correctamente ('%s') sin ser cancelada por caminar." % ap.current_animation)

	# 4. Esperar al impacto de Power Strike (0.58 / 1.70 = ~0.34s)
	await create_timer(0.40).timeout
	var hp_after_strike := goblin_ct.current_health
	assert(hp_after_strike < initial_hp, "El goblin debió recibir daño de Power Strike (HP inicial: %.1f, final: %.1f)" % [initial_hp, hp_after_strike])
	print("[OK] Paso 3: Daño e impacto de Power Strike aplicados correctamente (%.1f de daño infligido)." % (initial_hp - hp_after_strike))

	# 5. Esperar a que la animación de ataque concluya completamente
	await create_timer(0.35).timeout
	# Sigue presionando W:
	player._physics_process(0.016)
	player._process(0.016)

	print("Estado tras terminar la animación de ataque (W sigue presionado):")
	print("  is_moving: ", player.is_moving)
	print("  current_animation: ", ap.current_animation)
	assert(player.is_moving == true, "Al concluir el golpe, debe reanudar la marcha ya que W sigue presionado")
	assert(ap.current_animation == "walk", "La animación debe volver a 'walk'")
	print("[OK] Paso 4: Transición suave de regreso a 'walk' al terminar la animación.")

	Input.action_release("move_forward")
	goblin.queue_free()
	player.queue_free()
	print("\n>>> TEST DE POWER STRIKE MIENTRAS CAMINA PASÓ EXITOSAMENTE <<<\n")
	quit(0)
