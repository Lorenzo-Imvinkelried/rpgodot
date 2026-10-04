@tool
extends SceneTree

## Responsabilidad: Validación automatizada de la retención estricta del TargetFrame y CombatController
## durante ataques en área (AoE / Torbellino / Cleave) contra múltiples enemigos simultáneos.
## Verifica que:
## 1. El objetivo seleccionado se mantenga intacto al golpear una manada de enemigos con AoE.
## 2. La muerte de enemigos secundarios no deseleccione al objetivo principal.
## 3. El movimiento del jugador (WASD, Dash, Click-to-Move) no borre el objetivo actual.
## 4. Al morir el objetivo principal en medio de un pack, transicione de forma limpia al siguiente hostil.
## 5. Al morir el último objetivo restante, se limpie limpiamente sin errores ni saltos erráticos.

const PlayerScene = preload("res://scenes/player/player.tscn")
const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Retención de TargetFrame en Ataques en Área (AoE) ---")
	_run_tests()

func _run_tests() -> void:
	await process_frame

	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.position = Vector3.ZERO

	# Crear un pack de 4 enemigos reales
	var mobs: Array[CharacterBody3D] = []
	for i in range(4):
		var mob := CharacterBody3D.new()
		mob.set_script(MobScript)
		mob.name = "PackMob_%d" % i
		mob.position = Vector3(1.5 + float(i), 0.0, 0.0)
		root.add_child(mob)
		mobs.append(mob)

	await process_frame
	await process_frame

	# Configurar vida: Mob 0 (Target principal, 5000 HP), Mob 1 (10 HP para morir en el AoE), Mob 2 y 3 (5000 HP)
	var ct0: CombatTarget = mobs[0].get_node("CombatTarget")
	ct0.stats.max_hp = 5000
	ct0.stats.current_hp = 5000
	ct0.max_health = 5000.0
	ct0.current_health = 5000.0

	var ct1: CombatTarget = mobs[1].get_node("CombatTarget")
	ct1.stats.max_hp = 10
	ct1.stats.current_hp = 10
	ct1.max_health = 10.0
	ct1.current_health = 10.0

	for i in [2, 3]:
		var cti: CombatTarget = mobs[i].get_node("CombatTarget")
		cti.stats.max_hp = 5000
		cti.stats.current_hp = 5000
		cti.max_health = 5000.0
		cti.current_health = 5000.0

	var combat_ctrl: CombatController = player.get_node("CombatController")
	var skill_ctrl: SkillController = player.get_node("SkillController")

	# PRUEBA 1: Selección inicial y lanzamiento de habilidad de daño en área (Torbellino / Slot 8)
	combat_ctrl.select_target(mobs[0])
	assert(combat_ctrl.current_target == mobs[0], "Mob 0 debe estar seleccionado inicialmente")

	combat_ctrl.attack_target(mobs[0])
	assert(combat_ctrl.state == CombatController.State.ATTACKING, "Debe estar en estado ATTACKING")

	var cast_ok: bool = skill_ctrl.activate_slot(8, combat_ctrl.current_target, null, null)
	assert(cast_ok == true, "Torbellino debe lanzarse correctamente")
	assert(combat_ctrl.current_target == mobs[0], "El objetivo DEBE seguir siendo Mob 0 tras el AoE")
	assert(ct1.current_health <= 0.0, "Mob 1 debe haber muerto con el daño del AoE")
	print("[OK] Prueba 1: Lanzamiento de AoE en pack de mobs y muerte de mob secundario no alteran el target principal.")

	# PRUEBA 2: Retención durante movimiento y desplazamientos (WASD, Dash, Click-to-Move)
	Input.action_press("move_forward")
	player._process_movement(0.016)
	Input.action_release("move_forward")
	assert(combat_ctrl.current_target == mobs[0], "WASD no debe deseleccionar al objetivo")

	player._dash_timer = 0.2
	player._process_movement(0.016)
	assert(combat_ctrl.current_target == mobs[0], "Dash no debe deseleccionar al objetivo")

	player.move_to_ground_position(Vector3(5.0, 0.0, 5.0))
	assert(combat_ctrl.current_target == mobs[0], "Click-to-Move no debe deseleccionar al objetivo")
	print("[OK] Prueba 2: Movimiento con WASD, Dash y Click-to-Move preservan el objetivo seleccionado.")

	# PRUEBA 3: Muerte del objetivo principal en combate contra un pack (transición suave al siguiente mob vivo)
	mobs[2].on_aggroed_by(player)
	mobs[3].on_aggroed_by(player)
	ct0.stats.current_hp = 1
	ct0.current_health = 1.0
	skill_ctrl._cooldowns.clear()

	var lethal_cast = skill_ctrl.activate_slot(8, combat_ctrl.current_target, null, null)
	assert(lethal_cast == true, "Torbellino letal debe ejecutarse")
	assert(combat_ctrl.current_target != null, "No debe quedar con target null si hay otros mobs hostiles en combate")
	assert(combat_ctrl.current_target != mobs[0], "Debe haber transicionado fuera del mob derrotado")
	assert(combat_ctrl.current_target == mobs[2] or combat_ctrl.current_target == mobs[3], "Debe seleccionar a uno de los mobs vivos del pack")
	print("[OK] Prueba 3: Muerte del objetivo principal en combate de pack transiciona suavemente al siguiente mob vivo.")

	# PRUEBA 4: Muerte del último mob restante en combate (limpieza limpia de target)
	var final_target: CharacterBody3D = combat_ctrl.current_target
	var final_ct: CombatTarget = final_target.get_node("CombatTarget")
	final_ct.stats.current_hp = 1
	final_ct.current_health = 1.0

	# Alejar al otro mob fuera del rango para simular combate solitario final
	var other_mob: CharacterBody3D = mobs[3] if final_target == mobs[2] else mobs[2]
	other_mob.position = Vector3(999.0, 0.0, 0.0)

	skill_ctrl._cooldowns.clear()
	skill_ctrl.activate_slot(8, final_target, null, null)
	assert(combat_ctrl.current_target == null, "Al morir el último enemigo en combate, el target debe limpiarse limpiamente")
	print("[OK] Prueba 4: Muerte del último mob restante limpia el target de forma adecuada.")

	# Limpieza de nodos
	player.queue_free()
	for m in mobs:
		m.queue_free()

	print("\n>>> TODAS LAS PRUEBAS DE RETENCIÓN DE TARGET EN AOE PASARON EXITOSAMENTE <<<\n")
	quit(0)
