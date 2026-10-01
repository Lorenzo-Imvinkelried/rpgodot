@tool
extends SceneTree

## Suite de verificación automatizada para correcciones de combate:
## 1. Desenganche inmediato al morir el mob (no seguir pegando al cadáver).
## 2. Ataque directo con un solo click derecho.
## 3. Rango de ataque dinámico proporcional al tamaño físico del enemigo (evita atasco con dragón/boss).

const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")
const CombatControllerScript = preload("res://scripts/combat/combat_controller.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Correcciones de Combate, Desenganche y Rango Dinámico ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Rango de Ataque Dinámico Proporcional al Tamaño Físico (Bug 3)
	# --------------------------------------------------------------------------
	var goblin_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var dragon_scene := load("res://scenes/enemies/mob_dragon_boss.tscn") as PackedScene
	assert(goblin_scene != null and dragon_scene != null, "Las escenas de goblin y dragon deben existir")

	var goblin = goblin_scene.instantiate()
	var dragon = dragon_scene.instantiate()
	root.add_child(goblin)
	root.add_child(dragon)
	await process_frame

	var combat_ctrl := CombatControllerScript.new()
	root.add_child(combat_ctrl)
	await process_frame

	var r_goblin: float = CombatControllerScript.get_target_bounding_radius(goblin)
	var r_dragon: float = CombatControllerScript.get_target_bounding_radius(dragon)

	assert(r_goblin > 0.2 and r_goblin < 0.6, "Radio de goblin debe ser ~0.4m (obtenido: %f)" % r_goblin)
	assert(r_dragon > 1.0, "Radio del Dragón Boss debe ser > 1.0m debido a su colisión y escala (obtenido: %f)" % r_dragon)

	var eff_range_goblin := combat_ctrl.get_effective_attack_range(goblin)
	var eff_range_dragon := combat_ctrl.get_effective_attack_range(dragon)

	assert(eff_range_dragon > eff_range_goblin + 0.6, "El rango efectivo contra el Dragón debe ser notablemente mayor al del Goblin")
	print("[OK] Prueba 1: Rango de ataque dinámico proporcional validado (Goblin: %.2fm vs Dragón: %.2fm)." % [eff_range_goblin, eff_range_dragon])

	# --------------------------------------------------------------------------
	# PRUEBA 2: Aproximación y Detección de Rango sin Bloqueo Físico (Bug 3)
	# --------------------------------------------------------------------------
	# Crear atacante a 2.6m del Dragón (donde antes se atascaba porque 2.6 > 1.8)
	var attacker := CharacterBody3D.new()
	attacker.name = "Attacker"
	attacker.position = Vector3(0.0, 0.0, 0.0)
	dragon.position = Vector3(2.6, 0.0, 0.0) # Distancia 2.6m
	root.add_child(attacker)

	combat_ctrl.reparent(attacker)
	await process_frame
	combat_ctrl.attack_target(dragon)
	assert(combat_ctrl.state == CombatController.State.APPROACHING, "Debe iniciar en APPROACHING")

	# Actualizar combate: a 2.6m, al ser Dragón con radio ~1.4m, attack_range es ~3.2m -> debe entrar en ATTACKING!
	combat_ctrl.update_combat(0.05, null)
	assert(combat_ctrl.state == CombatController.State.ATTACKING, "A 2.6m contra el Dragón debe entrar en ATTACKING sin necesidad de pegarse a su centro")
	print("[OK] Prueba 2: Entrada exitosa en estado ATTACKING frente al Dragón a distancia física segura (2.6m).")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Detención Inmediata al Morir el Mob (No seguir pegando al cadáver) (Bug 1)
	# --------------------------------------------------------------------------
	goblin.position = Vector3(1.5, 0.0, 0.0)
	combat_ctrl.attack_target(goblin)
	combat_ctrl.update_combat(0.05, null)
	assert(combat_ctrl.state == CombatController.State.ATTACKING, "Debe estar en ATTACKING contra el goblin")

	# Simular muerte del goblin (salud a 0 y emisión de died)
	var goblin_ct: CombatTarget = goblin.get_node_or_null("CombatTarget")
	assert(goblin_ct != null, "Goblin debe tener CombatTarget")

	goblin_ct.current_health = 0.0
	goblin_ct.died.emit()
	goblin._on_combat_target_died()

	assert(combat_ctrl.state == CombatController.State.IDLE, "Al morir el mob, el CombatController DEBE pasar a IDLE de inmediato")
	assert(combat_ctrl.current_target == null, "current_target debe ser limpiado a null")
	assert(combat_ctrl.is_active() == false, "El combate activo debe desactivarse")

	# Avanzar múltiples ticks de combate: NUNCA debe volver a pegarle
	for i in range(10):
		combat_ctrl.update_combat(0.5, null)
	assert(combat_ctrl.state == CombatController.State.IDLE, "CombatController debe mantenerse en IDLE y no volver a atacar el cadáver")
	print("[OK] Prueba 3: Desenganche inmediato y cancelación de ataques al morir el mob verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Ataque Directo con un Solo Click Derecho (Bug 2)
	# --------------------------------------------------------------------------
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_scene != null, "player.tscn debe existir")

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var p_combat_ctrl: CombatController = player.get_node_or_null("CombatController")
	assert(p_combat_ctrl != null, "Player debe poseer CombatController")

	# Simular acción de click derecho directo sobre un mob vivo
	var target_wolf = load("res://scenes/enemies/mob_wolf.tscn").instantiate()
	root.add_child(target_wolf)
	target_wolf.position = Vector3(5.0, 0.0, 0.0)
	await process_frame

	player.attack_target(target_wolf)
	assert(p_combat_ctrl.current_target == target_wolf, "attack_target con click derecho debe fijar el objetivo")
	assert(p_combat_ctrl.state == CombatController.State.APPROACHING, "attack_target con click derecho debe iniciar aproximación directa")
	print("[OK] Prueba 4: Un solo click derecho activa el auto-ataque y aproximación inmediata.")

	# Limpieza
	goblin.queue_free()
	dragon.queue_free()
	attacker.queue_free()
	target_wolf.queue_free()
	player.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE COMBATE Y DESENGANCHE PASARON EXITOSAMENTE (4/4) ---\n")
	quit(0)
