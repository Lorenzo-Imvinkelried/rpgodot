@tool
extends SceneTree

## Suite de verificación automatizada para Selección de Objetivo sin ataque inmediato,
## Marcador 3D (Rombo sobre la cabeza), Sistema de Habilidades (Skills) y Atajos de Hotbar.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Skills & Targeting & TargetIndicator3D ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Creación de Entidad Jugador y Entidad Objetivo (Mob)
	var player := CharacterBody3D.new()
	player.name = "1" # Local player peer ID
	root.add_child(player)

	var p_stats := CharacterStats.create_player_default()
	p_stats.current_mp = 100
	p_stats.max_mp = 100
	p_stats.attack = 30

	var p_combat_tgt := CombatTarget.new()
	p_combat_tgt.name = "CombatTarget"
	p_combat_tgt.target_name = "Player"
	p_combat_tgt.stats = p_stats
	player.add_child(p_combat_tgt)

	var combat_ctrl := CombatController.new()
	combat_ctrl.name = "CombatController"
	player.add_child(combat_ctrl)

	var skill_ctrl := SkillController.new()
	skill_ctrl.name = "SkillController"
	player.add_child(skill_ctrl)

	var inv_ctrl := InventoryController.new()
	inv_ctrl.name = "InventoryController"
	player.add_child(inv_ctrl)

	var mob := CharacterBody3D.new()
	mob.name = "GoblinMob"
	mob.position = Vector3(5.0, 0.0, 0.0)
	root.add_child(mob)

	var mob_col := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.height = 2.0
	mob_col.shape = cap_shape
	mob.add_child(mob_col)

	var mob_stats := CharacterStats.create_dummy_default()
	mob_stats.max_hp = 300
	mob_stats.current_hp = 300
	mob_stats.defense = 10

	var mob_combat_tgt := CombatTarget.new()
	mob_combat_tgt.name = "CombatTarget"
	mob_combat_tgt.target_name = "Goblin"
	mob_combat_tgt.stats = mob_stats
	mob.add_child(mob_combat_tgt)

	await process_frame
	await process_frame

	# --------------------------------------------------------------------------
	# PRUEBA 1: Selección sin ataque automático inmediato (Click Derecho inicial / Click Izquierdo)
	# --------------------------------------------------------------------------
	combat_ctrl.select_target(mob)
	assert(combat_ctrl.current_target == mob, "El objetivo actual debe ser el mob")
	assert(combat_ctrl.state == CombatController.State.IDLE, "El estado debe ser IDLE, no APPROACHING")
	assert(combat_ctrl.is_approaching() == false, "No debe aproximarse automáticamente")
	assert(combat_ctrl.is_attacking() == false, "No debe atacar automáticamente")
	print("[OK] Prueba 1: select_target() establece el objetivo en modo IDLE sin aproximarse ni atacar.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Segundo click derecho o invocación de ataque inicia aproximación
	# --------------------------------------------------------------------------
	combat_ctrl.attack_target(mob)
	assert(combat_ctrl.state == CombatController.State.APPROACHING, "attack_target() debe cambiar a State.APPROACHING")
	assert(combat_ctrl.is_approaching() == true, "is_approaching() debe ser verdadero")
	combat_ctrl.select_target(mob)
	assert(combat_ctrl.state == CombatController.State.IDLE, "select_target() sobre mob seleccionado debe retornar a IDLE")
	print("[OK] Prueba 2: attack_target() activa aproximación y select_target() puede pausar en IDLE.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Marcador 3D (Rombo / Diamante sobre la cabeza)
	# --------------------------------------------------------------------------
	var indicator := TargetIndicator3D.new()
	root.add_child(indicator)
	await process_frame

	indicator.set_target(mob)
	assert(indicator.visible == true, "El rombo 3D debe hacerse visible al asignar objetivo")
	assert(indicator.global_position.y > mob.global_position.y, "El rombo debe posicionarse por encima del objetivo")

	indicator.clear_target(true)
	assert(indicator.visible == false, "El rombo 3D debe ocultarse al limpiar el objetivo")
	assert(indicator.has_target() == false, "has_target() debe retornar false tras clear_target")

	# Verificación de auto-ocultamiento al morir el objetivo
	indicator.set_target(mob)
	assert(indicator.visible == true, "El rombo 3D debe estar visible")
	mob_combat_tgt.died.emit()
	assert(indicator.visible == false, "El rombo 3D debe ocultarse automáticamente cuando el objetivo muere")
	indicator.queue_free()
	print("[OK] Prueba 3: TargetIndicator3D (rombo 3D flotante y desvanecimiento al morir) verificado.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Lanzamiento de Habilidad Instantánea (Relámpago - Slot 3)
	# --------------------------------------------------------------------------
	var initial_mob_hp := float(mob_stats.current_hp)
	var initial_mp := p_stats.current_mp

	var cast_ok := skill_ctrl.activate_slot(3, mob, null, null)
	assert(cast_ok == true, "El lanzamiento de Relámpago debe ser exitoso")
	assert(p_stats.current_mp == initial_mp - 15, "El maná debe deducirse en 15 (actual: %d vs esperado: %d)" % [p_stats.current_mp, initial_mp - 15])
	assert(float(mob_stats.current_hp) < initial_mob_hp, "La salud del mob debe haberse reducido por el daño de la habilidad")
	print("[OK] Prueba 4: Skill instantánea (Relámpago) ejecutada con deducción de maná y daño recibido.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Enfriamiento (Cooldown) y Validación de Maná Insuficiente
	# --------------------------------------------------------------------------
	var cast_cd_fail := skill_ctrl.activate_slot(3, mob, null, null)
	assert(cast_cd_fail == false, "No debe permitir relanzar una habilidad que aún está en enfriamiento")

	# Reducir maná a 0 y probar habilidad sin cooldown
	p_stats.current_mp = 5
	var cast_mana_fail := skill_ctrl.activate_slot(5, mob, null, null) # Escarcha cuesta 20
	assert(cast_mana_fail == false, "No debe permitir lanzar con maná insuficiente")
	p_stats.current_mp = 100
	print("[OK] Prueba 5: Cooldowns y verificación de maná insuficiente validados correctamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 6: Habilidad Canalizada con CastBar (Bola de Fuego - Slot 4)
	# --------------------------------------------------------------------------
	var cast_bar_scene := load("res://scenes/ui/hud/cast_bar.tscn") as PackedScene
	var cast_bar := cast_bar_scene.instantiate() as CastBar
	root.add_child(cast_bar)
	await process_frame

	var channel_started := skill_ctrl.activate_slot(4, mob, cast_bar, null)
	assert(channel_started == true, "Debe iniciar canalización de Bola de Fuego")
	assert(cast_bar.is_casting() == true, "CastBar debe estar en estado de casteo")

	# Interrupción de casteo
	cast_bar.cancel_cast()
	assert(cast_bar.is_casting() == false, "cancel_cast() debe interrumpir el lanzamiento")
	cast_bar.queue_free()
	print("[OK] Prueba 6: Habilidades canalizadas con CastBar e interrupción validadas correctamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 7: Uso de Poción desde Hotbar (Slot 10: Salud, Slot 11: Maná)
	# --------------------------------------------------------------------------
	inv_ctrl.add_item(ItemData.create_potion("Poción de Salud", 50.0, 0.0, 5))
	inv_ctrl.add_item(ItemData.create_potion("Poción de Maná", 0.0, 40.0, 5))

	p_combat_tgt.current_health = 40.0
	p_stats.current_mp = 20

	var hp_potion_ok := skill_ctrl.activate_slot(10, null, null, null)
	assert(hp_potion_ok == true, "Debe usar la poción de salud del inventario")
	assert(p_combat_tgt.current_health == 90.0, "La salud debe haberse restaurado en 50 puntos")

	var mp_potion_ok := skill_ctrl.activate_slot(11, null, null, null)
	assert(mp_potion_ok == true, "Debe usar la poción de maná del inventario")
	assert(p_stats.current_mp == 60, "El maná debe haberse restaurado en 40 puntos")
	print("[OK] Prueba 7: Activación de pociones desde Hotbar y restauración de HP/MP verificada.")

	# Limpieza
	player.queue_free()
	mob.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE SKILLS Y TARGETING (7/7) PASARON EXITOSAMENTE ---\n")
	quit(0)
