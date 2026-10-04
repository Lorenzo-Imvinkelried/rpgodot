@tool
extends SceneTree

## Suite de verificación automatizada para la Interfaz de Usuario (HUD, PlayerFrame, TargetFrame, Hotbar, CastBar, ExpBar, UIManager).

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Interfaz de Usuario (HUD & Frames) ---")
	_run_tests()

func _run_tests() -> void:
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	if hud_scene == null:
		printerr("[FAIL] No se pudo cargar scenes/ui/game_hud.tscn")
		quit(1)
		return

	var hud := hud_scene.instantiate() as GameHUD
	root.add_child(hud)

	await process_frame
	await process_frame

	# 1. Verificación de Instanciación de Subcomponentes
	assert(hud.player_frame != null, "PlayerFrame debe estar instanciado")
	assert(hud.target_frame != null, "TargetFrame debe estar instanciado")
	assert(hud.hotbar != null, "Hotbar debe estar instanciado")
	assert(hud.cast_bar != null, "CastBar debe estar instanciado")
	assert(hud.exp_bar != null, "ExpBar debe estar instanciado")
	assert(hud.quick_buttons != null, "QuickButtons debe estar instanciado")
	assert(hud.skill_panel != null, "SkillPanel debe estar instanciado")
	print("[OK] Prueba 1: Componentes principales del GameHUD instanciados correctamente.")

	# 2. Verificación de PlayerFrame
	var pf := hud.player_frame
	pf.set_player_info("Guerrero", 25)
	assert(pf.name_label.text == "Guerrero", "Nombre del jugador incorrecto")
	assert(pf.level_label.text == "Lvl: 25", "Nivel del jugador incorrecto")

	pf.set_health(150.0, 200.0)
	assert(pf.health_bar.value == 150.0, "Valor de health_bar incorrecto")
	assert(pf.health_bar.max_value == 200.0, "Max de health_bar incorrecto")
	assert(pf.health_label.text == "150 / 200", "Texto de health_label incorrecto")

	pf.set_mana(80.0, 100.0)
	assert(pf.mana_bar.value == 80.0, "Valor de mana_bar incorrecto")
	assert(pf.mana_label.text == "80 / 100", "Texto de mana_label incorrecto")

	# TAP Combo
	pf._on_attack_executed(null, 10.0)
	assert(pf.tap_block_1.color == PlayerFrame.COLOR_TAP_ACTIVE, "Hit 1 de combo debe iluminar bloque 1")
	pf._on_attack_executed(null, 10.0)
	assert(pf.tap_block_2.color == PlayerFrame.COLOR_TAP_ACTIVE, "Hit 2 de combo debe iluminar bloque 2")
	pf._on_attack_executed(null, 10.0)
	assert(pf.tap_block_3.color == PlayerFrame.COLOR_TAP_FULL, "Hit 3 de combo debe iluminar bloque 3 en color FULL")
	print("[OK] Prueba 2: PlayerFrame (Salud, Maná, Nivel y Combo TAP) verificado exitosamente.")

	# 3. Verificación de TargetFrame
	var tf := hud.target_frame
	assert(not tf.visible, "TargetFrame debe iniciar oculto cuando no hay objetivo")

	var dummy_boss := Node3D.new()
	var combat_tgt := CombatTarget.new()
	combat_tgt.name = "CombatTarget"
	combat_tgt.target_name = "Gran Dragon Boss"
	dummy_boss.add_child(combat_tgt)
	root.add_child(dummy_boss)

	var bstats := CharacterStats.new()
	bstats.max_hp = 1000
	bstats.current_hp = 750
	combat_tgt.stats = bstats

	tf.set_target(dummy_boss)
	assert(tf.visible, "TargetFrame debe hacerse visible al asignar objetivo")
	assert(tf.name_label.text == "Gran Dragon Boss", "Nombre de objetivo incorrecto")
	assert(tf.boss_badge.visible, "Boss badge debe estar visible para objetivos jefe")
	assert(tf.health_bar.value == 750.0, "Salud de TargetFrame incorrecta: %f vs 750" % tf.health_bar.value)

	# Muerte del objetivo oculta el marco automáticamente
	combat_tgt.died.emit()
	assert(not tf.visible, "TargetFrame debe ocultarse al morir el objetivo")
	dummy_boss.queue_free()
	print("[OK] Prueba 3: TargetFrame (Boss Badge, Salud, Auto-hide al morir) verificado.")

	# 4. Verificación de Hotbar
	var hb := hud.hotbar
	assert(hb.slots_container.get_child_count() == 12, "Hotbar debe poseer exactamente 12 slots")
	hb.trigger_cooldown(0, 4.0)
	assert(hb._slot_cooldowns.has(0), "Slot 0 debe registrar cooldown activo")
	hb._process(1.0)
	assert(is_equal_approx(hb._slot_cooldowns[0]["left"], 3.0), "Cooldown debe reducirse con el delta")

	# Stun Overlay
	assert(not hb.stun_overlay.visible, "StunOverlay debe iniciar oculto")
	hb._on_stun_applied(2.0)
	assert(hb.stun_overlay.visible, "StunOverlay debe bloquear la barra durante aturdimiento")
	hb._on_stun_removed()
	assert(not hb.stun_overlay.visible, "StunOverlay debe ocultarse tras remover aturdimiento")
	print("[OK] Prueba 4: Hotbar (12 slots, Cooldown visual, Bloqueo de Stun) verificado.")

	# 5. Verificación de CastBar
	var cb := hud.cast_bar
	assert(not cb.visible, "CastBar debe iniciar oculta")
	cb.start_cast("Rayo Solar", 2.0)
	assert(cb.visible, "CastBar debe mostrarse al iniciar casteo")
	assert(cb.is_casting(), "CastBar debe indicar estado de casteo activo")
	assert(cb.skill_label.text == "Rayo Solar", "Nombre de habilidad incorrecto")

	cb._process(1.0)
	assert(is_equal_approx(cb.progress_bar.value, 50.0), "Progreso de casteo debe ser 50% tras 1s de 2s")

	var signal_tracker := {
		"interrupted": false,
		"inv_toggled": false,
		"char_toggled": false
	}
	cb.cast_interrupted.connect(func(_skill): signal_tracker["interrupted"] = true)
	cb.cancel_cast()
	assert(signal_tracker["interrupted"], "Señal cast_interrupted debe ser emitida")
	assert(cb.skill_label.text == "¡INTERRUMPIDO!", "Texto de interrupción incorrecto")
	print("[OK] Prueba 5: CastBar (Inicio, Progreso numérico, Interrupción) verificado.")

	# 6. Verificación de ExpBar
	var eb := hud.exp_bar
	eb.set_experience(350, 1000)
	assert(eb.progress_bar.value == 350, "Valor de ExpBar incorrecto")
	assert(eb.progress_bar.max_value == 1000, "Max de ExpBar incorrecto")
	assert(eb.exp_label.text == "350 / 1000 (35.0%)", "Formato de texto de ExpBar incorrecto: " + eb.exp_label.text)
	print("[OK] Prueba 6: ExpBar (Valores numéricos y formato porcentaje) verificado.")

	# 7. Verificación de UIManager
	var ui_mgr := UIManager.new()
	root.add_child(ui_mgr)

	ui_mgr.inventory_toggle_requested.connect(func(): signal_tracker["inv_toggled"] = true)
	ui_mgr.character_sheet_toggle_requested.connect(func(): signal_tracker["char_toggled"] = true)

	ui_mgr.request_toggle_inventory()
	assert(signal_tracker["inv_toggled"], "inventory_toggle_requested no fue recibida")
	ui_mgr.request_toggle_character_sheet()
	assert(signal_tracker["char_toggled"], "character_sheet_toggle_requested no fue recibida")

	# Mouse Occlusion check
	var is_over := UIManager.is_mouse_over_ui(self)
	# Sin control enfocado, debe ser false
	assert(not is_over, "Sin control interactivo bajo el ratón, is_mouse_over_ui debe retornar false")

	ui_mgr.queue_free()
	print("[OK] Prueba 7: UIManager (Despacho de eventos y Mouse Occlusion) verificado.")

	print("\n--- TODAS LAS PRUEBAS DE UI (7/7) PASARON EXITOSAMENTE ---\n")
	quit(0)
