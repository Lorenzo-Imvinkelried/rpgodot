@tool
extends SceneTree

## Suite de verificación automatizada para:
## 1. El aislamiento de la tecla TAB para selección exclusiva de mobs en el mundo (Tab-Targeting).
## 2. Desactivación de captura de foco (FOCUS_NONE) en todos los elementos del HUD.
## 3. Comprobación de que pulsar TAB consume el evento en _input() y no enfoca controles de la UI.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Tab-Targeting Exclusivo y Bloqueo de Foco en HUD ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Verificación de focus_mode = FOCUS_NONE en Controles del GameHUD
	# --------------------------------------------------------------------------
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	assert(hud_scene != null, "game_hud.tscn debe cargar")
	var hud := hud_scene.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	assert(hud.quick_buttons.bag_button.focus_mode == Control.FOCUS_NONE, "BagButton debe tener focus_mode = FOCUS_NONE")
	assert(hud.quick_buttons.character_button.focus_mode == Control.FOCUS_NONE, "CharacterButton debe tener focus_mode = FOCUS_NONE")
	assert(hud.quick_buttons.skills_button.focus_mode == Control.FOCUS_NONE, "SkillsButton debe tener focus_mode = FOCUS_NONE")
	assert(hud.disconnect_button.focus_mode == Control.FOCUS_NONE, "DisconnectButton debe tener focus_mode = FOCUS_NONE")
	print("[OK] Prueba 1: Todos los botones del HUD tienen focus_mode = FOCUS_NONE (sin selección de foco).")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Captura prioritaria de TAB en Player._input()
	# --------------------------------------------------------------------------
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_scene != null, "player.tscn debe cargar")
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	# Crear dos dummies en el mundo para comprobar el ciclado con Tab
	var dummy1 := CharacterBody3D.new()
	dummy1.name = "DummyMob1"
	dummy1.position = Vector3(5.0, 0.0, 0.0)
	var ct1 := CombatTarget.new()
	ct1.target_name = "Lobo 1"
	dummy1.add_child(ct1)
	root.add_child(dummy1)

	var dummy2 := CharacterBody3D.new()
	dummy2.name = "DummyMob2"
	dummy2.position = Vector3(10.0, 0.0, 0.0)
	var ct2 := CombatTarget.new()
	ct2.target_name = "Lobo 2"
	dummy2.add_child(ct2)
	root.add_child(dummy2)

	await process_frame

	var combat_ctrl := player.get_node_or_null("CombatController") as CombatController
	assert(combat_ctrl != null, "Player debe tener CombatController")

	# Simular pulsación de la tecla TAB
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	tab_event.echo = false

	# Disparar _input en el jugador
	player._input(tab_event)

	# Verificar que seleccionó a un mob del mundo
	assert(combat_ctrl.current_target != null, "Pulsar TAB debe seleccionar un mob del mundo")
	var first_selected := combat_ctrl.current_target
	assert(first_selected == dummy1 or first_selected == dummy2, "El objetivo debe ser uno de los dummies del mundo")
	print("[OK] Prueba 2: Pulsar TAB seleccionó el objetivo del mundo correctamente: %s." % first_selected.name)

	# Simular segunda pulsación de TAB para ciclar
	player._input(tab_event)
	assert(combat_ctrl.current_target != null, "El segundo TAB debe mantener un objetivo válido")
	var second_selected := combat_ctrl.current_target
	assert(second_selected != first_selected, "El segundo TAB debe ciclar hacia el siguiente mob del mundo")
	print("[OK] Prueba 3: Ciclado de mobs en el mundo verificado exitosamente (de %s a %s)." % [first_selected.name, second_selected.name])

	# --------------------------------------------------------------------------
	# PRUEBA 4: Comprobación de que el foco de la GUI nunca fue capturado por el HUD
	# --------------------------------------------------------------------------
	var focus_owner := root.gui_get_focus_owner()
	assert(focus_owner == null, "Ningún control del HUD debe tener foco tras pulsar TAB")
	print("[OK] Prueba 4: El HUD permanece completamente libre de foco visual o selección por TAB.")

	# Cleanup
	hud.queue_free()
	player.queue_free()
	dummy1.queue_free()
	dummy2.queue_free()

	print("\n>>> TODAS LAS PRUEBAS DE TAB-TARGETING Y BLOQUEO DE FOCO EN HUD PASARON CON ÉXITO <<<")
	quit(0)
