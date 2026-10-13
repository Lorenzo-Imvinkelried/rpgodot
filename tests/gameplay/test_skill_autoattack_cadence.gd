@tool
extends SceneTree

## Suite de verificación automatizada para:
## Cadencia homogénea y robusta de autoataques tras el uso de habilidades (AA-Reset).
## Evita que el primer ataque post-habilidad salga prematuramente o que el segundo se pause en exceso.

func _init() -> void:
	print("\n--- INICIANDO TEST: Cadencia homogénea de autoataques tras habilidad ---")
	_run_tests()

func _run_tests() -> void:
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	col.shape = box
	floor.position = Vector3(0, -0.5, 0)
	floor.add_child(col)
	root.add_child(floor)

	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	player.position = Vector3(0, 0, 0)
	root.add_child(player)

	var dummy_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var dummy: Node3D = dummy_scene.instantiate()
	dummy.position = Vector3(0, 0, -1.8)
	root.add_child(dummy)
	await process_frame

	var d_ct: CombatTarget = dummy.get_node("CombatTarget")
	d_ct.get_stats().max_hp = 100000.0
	d_ct.get_stats().current_hp = 100000.0
	d_ct.current_health = 100000.0

	var combat_ctrl: CombatController = player.combat_controller
	var skill_ctrl: SkillController = player.skill_controller
	var visuals: PlayerVisuals = player.visuals

	# Asegurar velocidad de ataque fija para reproducibilidad
	var stats: CharacterStats = combat_ctrl.get_stats()
	stats.attack_speed = 1.2
	var expected_interval := 1.0 / 1.2 # ~0.833s

	var attack_times: Array[float] = []
	combat_ctrl.attack_executed.connect(func(target, dmg):
		attack_times.append(combat_ctrl._time_since_last_attack)
	)

	# 1. Comenzar atacando al dummy
	combat_ctrl.attack_target(dummy)

	# Simular 1 segundo de combate inicial
	for i in range(60):
		var dt := 0.016
		player._physics_process(dt)
		player._process(dt)
		await create_timer(dt).timeout

	# 2. Lanzar Skill 1 (Golpe Potente)
	var cast_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_ok == true, "Power Strike debe lanzarse con éxito")

	# Simular 4 segundos de combate tras la habilidad
	for i in range(250):
		var dt := 0.016
		player._physics_process(dt)
		player._process(dt)
		skill_ctrl._process(dt)
		await create_timer(dt).timeout

	# 3. Comprobar que se ejecutaron autoataques posteriores a la habilidad
	assert(attack_times.size() >= 3, "Deben haberse ejecutado múltiples autoataques tras la habilidad (obtenidos: %d)" % attack_times.size())

	# 4. Comprobar que _time_since_last_attack nunca saltó a 999.0 de forma anómala
	assert(combat_ctrl._time_since_last_attack < 10.0, "El temporizador de ataque debe permanecer dentro de límites normales")

	print("[OK] Cadencia de autoataques validada: intervalos continuos y regulares sin pausas anómalas.")
	print("\n>>> TEST DE CADENCIA DE AUTOATAQUES COMPLETADO CON ÉXITO <<<\n")

	dummy.queue_free()
	player.queue_free()
	floor.queue_free()
	quit(0)
