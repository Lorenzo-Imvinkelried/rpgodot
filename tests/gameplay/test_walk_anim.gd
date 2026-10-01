@tool
extends SceneTree

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Sincronización y Suavidad de Animación de Locomoción ---")
	_run_tests()

func _run_tests() -> void:
	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(p_scene != null, "player.tscn debe existir")

	var player: Player = p_scene.instantiate()
	root.add_child(player)
	await process_frame

	var visuals: PlayerVisuals = player.visuals
	assert(visuals != null, "PlayerVisuals debe existir en Player")
	assert(visuals.anim_player != null, "AnimationPlayer debe estar inicializado")

	print("Animaciones detectadas en Visuals:")
	print(" - Idle:  '%s'" % visuals._anim_idle)
	print(" - Walk:  '%s'" % visuals._anim_walk)
	print(" - Run:   '%s'" % visuals._anim_run)
	print(" - Attack:'%s'" % visuals._anim_attack)

	assert(visuals._anim_idle == "idle", "Animación Idle debe ser 'idle'")
	assert(visuals._anim_walk == "walk", "Animación Walk debe ser 'walk'")
	assert(visuals._anim_run == "run", "Animación Run debe ser 'run'")

	# --------------------------------------------------------------------------
	# PRUEBA 1: Estado de Reposo (Idle)
	# --------------------------------------------------------------------------
	player.is_moving = false
	player._process(0.016)
	assert(visuals.anim_player.current_animation == "idle", "En reposo debe reproducir 'idle'")
	assert(is_equal_approx(visuals.anim_player.speed_scale, 1.0), "En reposo speed_scale debe ser 1.0")
	print("[OK] Prueba 1: Estado de reposo (Idle) verificado con speed_scale = 1.0.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Caminata/Carrera hacia adelante (WASD W - 6.0 m/s)
	# --------------------------------------------------------------------------
	player.is_moving = true
	player.velocity = Vector3(0.0, 0.0, -6.0)
	player._is_moving_backward = false
	player._process(0.016)

	assert(visuals.anim_player.current_animation == "run", "Al avanzar a 6.0 m/s debe reproducir 'run'")
	assert(visuals.anim_player.speed_scale >= 0.85 and visuals.anim_player.speed_scale <= 1.25,
		"speed_scale debe mantenerse dentro de límites naturales [0.85, 1.25] (obtenido: %f)" % visuals.anim_player.speed_scale)
	assert(visuals.anim_player.speed_scale > 0.0, "Al avanzar speed_scale debe ser positivo")
	print("[OK] Prueba 2: Marcha hacia adelante (WASD W) reproduce 'run' con speed_scale = %.2f (sin hiper-velocidad 6x)." % visuals.anim_player.speed_scale)

	# --------------------------------------------------------------------------
	# PRUEBA 3: Giro continuo en su eje mientras avanza (A/D + W)
	# --------------------------------------------------------------------------
	for i in range(12):
		player.rotation.y += 0.3
		player._process(0.016)
		assert(visuals.anim_player.speed_scale > 0.0, "Al girar avanzando NUNCA debe invertirse el signo de speed_scale (obtenido: %f)" % visuals.anim_player.speed_scale)
		assert(visuals.anim_player.speed_scale <= 1.25, "Al girar avanzando speed_scale no debe dispararse")
	print("[OK] Prueba 3: Giros con A/D manteniendo avance no provocan giros de signo ni glitching.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Marcha hacia atrás (WASD S - 4.2 m/s)
	# --------------------------------------------------------------------------
	player.velocity = Vector3(0.0, 0.0, 4.2)
	player._is_moving_backward = true
	player._process(0.016)

	assert(visuals.anim_player.current_animation == "walk", "Al retroceder debe reproducir 'walk' en reversa")
	assert(visuals.anim_player.speed_scale < 0.0, "Al retroceder speed_scale DEBE ser negativo")
	assert(visuals.anim_player.speed_scale >= -1.25 and visuals.anim_player.speed_scale <= -0.85,
		"Al retroceder speed_scale debe ser suave [-1.25, -0.85] (obtenido: %f)" % visuals.anim_player.speed_scale)
	print("[OK] Prueba 4: Retroceso con S reproduce 'walk' en reversa con speed_scale = %.2f estable." % visuals.anim_player.speed_scale)

	# --------------------------------------------------------------------------
	# PRUEBA 5: Desplazamiento por Click (Click-to-Move - 6.0 m/s)
	# --------------------------------------------------------------------------
	player._is_moving_backward = false
	player.move_to_ground_position(Vector3(20.0, 0.0, 20.0))
	player._physics_process(0.016)
	player._process(0.016)

	assert(visuals.anim_player.current_animation == "run", "Click-to-move a velocidad normal debe reproducir 'run'")
	assert(visuals.anim_player.speed_scale >= 0.85 and visuals.anim_player.speed_scale <= 1.25,
		"Click-to-move speed_scale debe ser natural (obtenido: %f)" % visuals.anim_player.speed_scale)
	print("[OK] Prueba 5: Click-to-Move reproduce locomoción suave a escala natural (%.2f)." % visuals.anim_player.speed_scale)

	# --------------------------------------------------------------------------
	# PRUEBA 6: Desplazamiento en Guardia Activa (Shield Guard - 4.2 m/s)
	# --------------------------------------------------------------------------
	player.clear_click_move()
	player.velocity = Vector3(0.0, 0.0, -4.2)
	player._is_moving_backward = false
	player._process(0.016)

	assert(visuals.anim_player.current_animation == "walk", "Al desplazarse a 4.2 m/s (en guardia/ralentizado) debe reproducir 'walk'")
	assert(visuals.anim_player.speed_scale >= 0.85 and visuals.anim_player.speed_scale <= 1.25,
		"Caminata con escudo debe mantenerse dentro de límites [0.85, 1.25] (obtenido: %f)" % visuals.anim_player.speed_scale)
	print("[OK] Prueba 6: Movimiento táctico con escudo reproduce 'walk' a escala fluida (%.2f)." % visuals.anim_player.speed_scale)

	# Limpieza
	player.queue_free()
	print("\n--- TODAS LAS PRUEBAS DE ANIMACIÓN DE LOCOMOCIÓN PASARON EXITOSAMENTE (6/6) ---\n")
	quit(0)
