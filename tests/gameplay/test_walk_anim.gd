@tool
extends SceneTree

func _init() -> void:
	print("\n--- INICIANDO TEST: Animación de Walk exactamente como en 85569bf ---")
	_run_tests()

func _run_tests() -> void:
	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	root.add_child(player)
	await process_frame

	var ap: AnimationPlayer = player.visuals.anim_player
	assert(ap != null, "AnimationPlayer debe existir")

	# 1. En reposo -> Idle
	player.is_moving = false
	player._process(0.016)
	player._physics_process(0.016)
	assert(ap.current_animation == "idle", "En reposo debe ser idle")
	print("[OK] Prueba 1: Reposo (idle) verificado.")

	# 2. Caminata libre (WASD) sin objetivo -> debe mantenerse en 'walk' en _process y _physics_process
	player.is_moving = true
	player.velocity = Vector3(0, 0, -6.0)
	player._process(0.016)
	assert(ap.current_animation == "walk", "Al caminar debe ser 'walk' tras _process")
	player._physics_process(0.016)
	assert(ap.current_animation == "walk", "NO debe ser reseteado a idle por _physics_process mientras camina")
	print("[OK] Prueba 2: Caminata continua (walk) verificada sin interrupción de idle.")

	# 3. Caminata guiada por click (Click-to-Move) -> debe mantenerse en 'walk'
	player.move_to_ground_position(Vector3(10, 0, 10))
	player._physics_process(0.016)
	player._process(0.016)
	assert(ap.current_animation == "walk", "Click-to-move debe reproducir 'walk'")
	print("[OK] Prueba 3: Click-to-move reproduce 'walk' de forma continua.")

	# 4. Desenganche al morir mob -> Al morir el mob, combate se detiene y no interfiere con walk
	var goblin_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var goblin = goblin_scene.instantiate()
	root.add_child(goblin)
	await process_frame

	player.attack_target(goblin)
	assert(player.combat_controller.current_target == goblin, "Debe tener objetivo")
	
	# Matar mob
	var ct: CombatTarget = goblin.get_node_or_null("CombatTarget")
	ct.current_health = 0.0
	ct.died.emit()
	
	player._physics_process(0.016)
	assert(player.combat_controller.current_target == null, "Objetivo debe ser limpiado")
	assert(player.combat_controller.state == CombatController.State.IDLE, "Estado debe ser IDLE")
	print("[OK] Prueba 4: Desenganche al morir mob verificado.")

	goblin.queue_free()
	player.queue_free()
	print("\n--- TEST DE ANIMACIÓN DE WALK FINALIZADO CON ÉXITO ---\n")
	quit(0)
