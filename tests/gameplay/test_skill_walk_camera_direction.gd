@tool
extends SceneTree

func _init() -> void:
	print("\n--- INICIANDO TEST: Reanudar caminata en direccion de camara tras skill ---")
	_run_tests()

func _run_tests() -> void:
	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	root.add_child(player)

	# Ubicar al enemigo 1 a 90 grados a la derecha (X = 3, Z = 0)
	var goblin_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var goblin: Node3D = goblin_scene.instantiate()
	goblin.position = Vector3(3.0, 0, 0.0)
	root.add_child(goblin)
	await process_frame

	var camera_pivot: PlayerCamera = player.camera_pivot
	var skill_ctrl: SkillController = player.skill_controller

	# Asegurar orientacion inicial de camara hacia el frente (-Z, yaw = 0)
	camera_pivot.set_yaw(0.0)
	player.rotation.y = 0.0

	# --------------------------------------------------------------------------
	# PRUEBA 1: Camara a yaw = 0, mob a la derecha, skill y mantener W
	# --------------------------------------------------------------------------
	Input.action_press("move_forward")
	player._physics_process(0.016)
	player._process(0.016)

	assert(player.is_moving == true, "El jugador debe estar moviendose al caminar con W")
	print("[OK] Prueba 1 - Paso 1: Jugador caminando hacia adelante con yaw de camara = 0.")

	var cast_ok := skill_ctrl.activate_slot(0, goblin, null, null)
	assert(cast_ok == true, "Habilidad activada exitosamente")

	# Avanzar 1 frame: el jugador debio orientarse hacia el goblin (a la derecha)
	player._physics_process(0.016)
	player._process(0.016)

	assert(abs(player.rotation.y) > 0.5, "El jugador debe haberse girado hacia el goblin para golpearlo")
	assert(camera_pivot.current_yaw == 0.0, "La camara debe seguir apuntando hacia su frente (yaw = 0)")
	print("[OK] Prueba 1 - Paso 2: Jugador orientado hacia el mob sin alterar yaw de camara.")

	# Esperar que termine el impacto y la animacion de ataque
	await create_timer(0.40).timeout # Impacto
	await create_timer(0.35).timeout # Fin animacion

	# El jugador SIGUE MANTENIENDO W presionado
	player._physics_process(0.016)
	player._process(0.016)

	# El jugador DEBE volver a caminar hacia donde apunta la camara (yaw = 0)
	assert(player.is_moving == true, "El jugador debe reanudar la marcha tras el golpe si W sigue presionado")
	assert(is_equal_approx(player.rotation.y, camera_pivot.current_yaw), "El jugador DEBE orientarse hacia donde quedo apuntando la camara (esperado: %.2f, obtenido: %.2f)" % [camera_pivot.current_yaw, player.rotation.y])
	assert(player.velocity.z < -1.0, "El jugador debe desplazarse hacia adelante en la direccion de la camara (velocity.z < 0)")
	assert(abs(player.velocity.x) < 0.5, "El jugador NO debe seguir desplazandose hacia el mob en X (velocity.x esperado ~ 0, obtenido: %.2f)" % player.velocity.x)
	print("[OK] Prueba 1 - Paso 3: El jugador reanudo la marcha correctamente hacia donde apunta la camara (yaw = 0).")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Camara en angulo arbitrario (yaw = 0.785 rad, ~45 deg), mob atras, skill y mantener W
	# --------------------------------------------------------------------------
	var custom_yaw: float = 0.785 # 45 grados
	camera_pivot.set_yaw(custom_yaw)

	# Mob 2 atras del jugador (2m detras en Z)
	var goblin2: Node3D = goblin_scene.instantiate()
	goblin2.position = player.global_position + Vector3(0.0, 0, 2.0)
	root.add_child(goblin2)
	await process_frame

	skill_ctrl._cooldowns.clear()
	var cast2_ok := skill_ctrl.activate_slot(0, goblin2, null, null)
	assert(cast2_ok == true, "Segunda habilidad activada exitosamente")

	player._physics_process(0.016)
	player._process(0.016)

	# El jugador se giro hacia atras para golpear a goblin2
	assert(abs(player.rotation.y - custom_yaw) > 0.5, "El jugador debio orientarse hacia atras para golpear a goblin2")
	assert(is_equal_approx(camera_pivot.current_yaw, custom_yaw), "La camara debe permanecer en custom_yaw")
	print("[OK] Prueba 2 - Paso 1: Jugador orientado hacia mob atras sin alterar camara.")

	await create_timer(0.40).timeout
	await create_timer(0.35).timeout

	# Sigue manteniendo W presionado
	player._physics_process(0.016)
	player._process(0.016)

	assert(player.is_moving == true, "Reanuda marcha tras el segundo golpe")
	assert(is_equal_approx(player.rotation.y, custom_yaw), "El jugador DEBE reorientarse a custom_yaw (esperado: %.2f, obtenido: %.2f)" % [custom_yaw, player.rotation.y])

	var expected_dir := -player.transform.basis.z
	print("[OK] Prueba 2 - Paso 2: El jugador reanudo la marcha hacia el angulo exacto de la camara (yaw = %.2f)." % custom_yaw)

	Input.action_release("move_forward")
	goblin.queue_free()
	goblin2.queue_free()
	player.queue_free()
	print("\n>>> TODOS LOS TESTS DE DIRECCION DE CAMARA PASARON EXITOSAMENTE <<<\n")
	quit(0)
