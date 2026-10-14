@tool
extends SceneTree

## Suite de verificación automatizada para:
## 1. Disparo inmediato del siguiente ataque básico apenas concluye la animación acelerada (1.70x) de Golpe Potente.
## 2. Continuidad regular a la cadencia dictada por attack_speed (1.0 / attack_speed) para los ataques subsiguientes.
## 3. Ausencia total de pausas muertas de ~1.5s post-habilidad.

var sim_time: float = 0.0
var basic_attack_times: Array[float] = []

func _init() -> void:
	print("\n--- INICIANDO TEST: Salida inmediata del ataque básico al concluir animación de skill ---")
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

	var stats: CharacterStats = combat_ctrl.get_stats()
	stats.attack_speed = 1.2
	var expected_interval := 1.0 / 1.2 # ~0.833s

	combat_ctrl.attack_executed.connect(func(target, dmg):
		basic_attack_times.append(sim_time)
		print("[t=%.3fs] Ataque básico ejecutado (dmg: %.1f)" % [sim_time, dmg])
	)

	# 1. Comenzar auto-ataque normal
	combat_ctrl.attack_target(dummy)

	# Simular 1 segundo de combate
	for i in range(60):
		var dt := 0.0166667
		sim_time += dt
		player._physics_process(dt)
		player._process(dt)
		await create_timer(dt).timeout

	assert(basic_attack_times.size() >= 1, "Debe haberse ejecutado al menos un ataque básico inicial")

	# 2. Lanzar Golpe Potente (AA-Reset con animación rápida 1.70x)
	var skill_cast_time := sim_time
	var initial_basic_count := basic_attack_times.size()
	var cast_ok := skill_ctrl.activate_slot(0, dummy, null, null)
	assert(cast_ok == true, "Golpe Potente debe ejecutarse correctamente")
	print("[t=%.3fs] Golpe Potente lanzado (skill_cast_time)" % skill_cast_time)

	# Simular 3 segundos adicionales frame a frame
	for i in range(180):
		var dt := 0.0166667
		sim_time += dt
		player._physics_process(dt)
		player._process(dt)
		skill_ctrl._process(dt)
		await create_timer(dt).timeout

	# 3. Verificaciones de sincronización
	assert(basic_attack_times.size() > initial_basic_count, "El ataque básico posterior debió impactar")
	var first_basic_after_skill_time: float = basic_attack_times[initial_basic_count]
	var delay_to_first_basic := first_basic_after_skill_time - skill_cast_time
	print("Tiempo total desde lanzamiento de skill hasta impacto del siguiente básico: %.3fs" % delay_to_first_basic)

	# Con animación rápida (1.70x) e inicio inmediato, el impacto debe ocurrir en < 0.70s (nunca demorarse ~1.5s)
	assert(delay_to_first_basic <= 0.70, "El siguiente básico debe impactar ágilmente tras la habilidad sin demoras excesivas (obtenido: %.3fs)" % delay_to_first_basic)

	# 4. Verificar que el subsiguiente ataque básico respeta la cadencia de attack_speed (~0.68s - ~0.83s)
	assert(basic_attack_times.size() >= initial_basic_count + 2, "Deben haberse ejecutado múltiples ataques para medir la cadencia regular")
	var subsequent_delta := basic_attack_times[basic_attack_times.size() - 1] - basic_attack_times[basic_attack_times.size() - 2]
	print("Intervalo de ataque subsiguiente: %.3fs (esperado nominal: %.3fs)" % [subsequent_delta, expected_interval])
	assert(subsequent_delta <= expected_interval + 0.1, "Los ataques subsiguientes deben respetar la velocidad de ataque regular sin pausas")

	print("\n[OK] Salida inmediata al concluir la animación y cadencia regular posterior validadas con éxito.")
	print(">>> TEST COMPLETADO CON ÉXITO <<<\n")

	dummy.queue_free()
	player.queue_free()
	floor.queue_free()
	quit(0)
