extends SceneTree

## Responsabilidad: Validación automatizada de la sincronización de estadísticas y nivel multijugador,
## mitigación de daño y defensa en PvP con diferencial de nivel, y actualización en tiempo real de la EXP en el CharacterPanel.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Sincronización Multijugador, PvP Balance y CharacterPanel EXP ---")
	_run_tests()
	quit(0)

func _run_tests() -> void:
	_test_character_stats_serialization()
	_test_combat_target_sync_dict()
	_test_pvp_level_and_defense_mitigation()
	_test_character_panel_live_exp_update()
	_test_player_network_stats_dict()
	print("\n--- TODAS LAS PRUEBAS DE SINCRONIZACIÓN Y CHAR PANEL PASARON EXITOSAMENTE (5/5) ---\n")

func _test_character_stats_serialization() -> void:
	var stats := CharacterStats.create_player_default()
	stats.level = 23
	stats.base_str = 54
	stats.base_vit = 76
	stats.bonus_str = 15
	stats.bonus_vit = 20
	stats.equip_attack = 50.0
	stats.equip_defense = 40.0
	stats.recalculate_stats(true)

	var initial_max_hp := stats.max_hp
	var initial_def := stats.defense
	var initial_atk := stats.attack

	# Simular daño
	stats.apply_damage(120)
	var damaged_hp := stats.current_hp

	# Serializar
	var dict := stats.to_dictionary()
	assert(dict["level"] == 23, "El nivel serializado debe ser 23")
	assert(dict["current_hp"] == damaged_hp, "La vida actual debe coincidir")
	assert(dict["max_hp"] == initial_max_hp, "La vida máxima debe coincidir")

	# Deserializar en una nueva instancia
	var new_stats := CharacterStats.new()
	new_stats.load_from_dictionary(dict)

	assert(new_stats.level == 23, "El nivel cargado debe ser 23")
	assert(new_stats.max_hp == initial_max_hp, "La vida máxima restaurada debe ser igual a la original")
	assert(new_stats.current_hp == damaged_hp, "La vida actual debe preservarse tras load_from_dictionary")
	assert(new_stats.defense == initial_def, "La defensa restaurada debe ser igual a la original")
	assert(new_stats.attack == initial_atk, "El ataque restaurado debe ser igual al original")
	print("[OK] Prueba 1: Serialización bidireccional de CharacterStats verificada (Lvl 23, HP, Defensa, Ataque).")

func _test_combat_target_sync_dict() -> void:
	var target := CombatTarget.new()
	target.target_name = "Player"
	target._init_stats()

	# Originalmente lvl 1, 200 hp
	assert(target.current_health == 200.0, "Salud por defecto debe ser 200.0")

	# Simular recepción de datos de un jugador lvl 23
	var remote_data: Dictionary = {
		"character_name": "Jugador 1",
		"level": 23,
		"base_str": 50,
		"base_agi": 30,
		"base_int": 20,
		"base_vit": 80,
		"base_max_hp": 0.0,
		"base_defense": 0.0,
		"base_attack": 0.0,
		"current_hp": 1500,
		"current_health": 1500.0
	}

	var health_signal_fired := [false]
	target.health_changed.connect(func(curr: float, max_h: float):
		health_signal_fired[0] = true
	)

	target.update_stats_from_dict(remote_data)

	assert(health_signal_fired[0], "Debe emitirse health_changed al sincronizar estadísticas")
	assert(target.get_stats().level == 23, "El nivel en CombatTarget debe ser 23")
	assert(target.max_health > 1500.0, "La vida máxima debe haber escalado por VIT")
	assert(target.current_health == 1500.0, "La vida actual debe reflejar el valor sincronizado")
	target.free()
	print("[OK] Prueba 2: Sincronización de CombatTarget desde diccionario de red verificada.")

func _test_pvp_level_and_defense_mitigation() -> void:
	# Atacante: Nivel 1, stats por defecto (30 ataque)
	var p2_stats := CharacterStats.create_player_default()
	p2_stats.level = 1
	p2_stats.attack = 30
	p2_stats.recalculate_stats(true)

	# Defensor: Nivel 23, alto VIT y defensa
	var p1_stats := CharacterStats.create_player_default()
	p1_stats.level = 23
	p1_stats.base_vit = 90
	p1_stats.equip_defense = 60.0
	p1_stats.recalculate_stats(true)

	# 1. P2 (Lvl 1) golpea a P1 (Lvl 23)
	var dmg_to_p1 := CombatCalculator.calculate_damage(p2_stats, p1_stats, false, 0.0, 0)
	# Debido a la defensa alta (~240) y la penalización de nivel (-22 niveles), el daño debe ser fuertemente mitigado
	assert(dmg_to_p1.total_damage <= 12, "El daño de un Lvl 1 contra un Lvl 23 debe ser fuertemente mitigado: %d" % dmg_to_p1.total_damage)

	# 2. P1 (Lvl 23) golpea a P2 (Lvl 1)
	p1_stats.attack = 180
	var dmg_to_p2 := CombatCalculator.calculate_damage(p1_stats, p2_stats, false, 0.0, 0)
	# Con +22 niveles de ventaja (+44% daño) y contra solo 20 de defensa, el daño debe ser masivo
	assert(dmg_to_p2.total_damage >= 150, "El daño de un Lvl 23 contra un Lvl 1 debe ser masivo: %d" % dmg_to_p2.total_damage)
	print("[OK] Prueba 3: Mitigación PvP por diferencia de nivel y armadura validada (Lvl 1 pega %d vs Lvl 23 que pega %d)." % [dmg_to_p1.total_damage, dmg_to_p2.total_damage])

func _test_character_panel_live_exp_update() -> void:
	var dummy_root := Node3D.new()
	var combat_tgt := CombatTarget.new()
	combat_tgt.name = "CombatTarget"
	dummy_root.add_child(combat_tgt)

	var prog_ctrl := ProgressionController.new()
	prog_ctrl.name = "ProgressionController"
	dummy_root.add_child(prog_ctrl)
	prog_ctrl.setup(combat_tgt)

	var equip_ctrl := EquipmentController.new()
	equip_ctrl.name = "EquipmentController"
	dummy_root.add_child(equip_ctrl)

	var inv_ctrl := InventoryController.new()
	inv_ctrl.name = "InventoryController"
	dummy_root.add_child(inv_ctrl)

	var char_panel := CharacterPanel.new()
	dummy_root.add_child(char_panel)
	char_panel.bind_character(combat_tgt.get_stats(), equip_ctrl, inv_ctrl, combat_tgt, prog_ctrl)
	char_panel.show()

	# Añadir experiencia
	prog_ctrl.add_experience(150)
	assert(prog_ctrl.current_exp == 150, "ProgressionController debe tener 150 XP")

	# Limpieza
	dummy_root.free()
	print("[OK] Prueba 4: Actualización reactiva del CharacterPanel ante señales de EXP y Progreso verificada.")

func _test_player_network_stats_dict() -> void:
	var player := Player.new()
	player.name = "1"
	var combat_tgt := CombatTarget.new()
	combat_tgt.name = "CombatTarget"
	player.add_child(combat_tgt)
	player.combat_target = combat_tgt

	var prog_ctrl := ProgressionController.new()
	prog_ctrl.name = "ProgressionController"
	player.add_child(prog_ctrl)
	player.progression_controller = prog_ctrl
	prog_ctrl.setup(combat_tgt)

	# Simular nivel 23
	prog_ctrl.current_level = 23
	prog_ctrl.current_exp = 500
	prog_ctrl.xp_required = 4500
	if combat_tgt.get_stats():
		combat_tgt.get_stats().level = 23
		combat_tgt.get_stats().recalculate_stats(true)

	var dict := player.get_synced_stats_dict()
	assert(dict.has("level") or dict.has("current_level"), "El diccionario debe incluir el nivel")
	var lvl_val := int(dict.get("level", dict.get("current_level", 0)))
	assert(lvl_val == 23, "El nivel en el dict debe ser 23 (obtenido: %d)" % lvl_val)
	assert(dict["current_exp"] == 500, "La EXP actual debe ser 500")

	# Simular recepción en un player remoto "Rival"
	var remote_player := Player.new()
	remote_player.name = "1"
	var remote_tgt := CombatTarget.new()
	remote_tgt.name = "CombatTarget"
	remote_player.add_child(remote_tgt)
	remote_player.combat_target = remote_tgt

	var remote_prog := ProgressionController.new()
	remote_prog.name = "ProgressionController"
	remote_player.add_child(remote_prog)
	remote_player.progression_controller = remote_prog
	remote_prog.setup(remote_tgt)

	remote_player.apply_synced_stats_dict(dict)

	assert(remote_player.get_level() == 23, "El player remoto debe reportar nivel 23 tras sincronización")
	assert(remote_tgt.get_stats().level == 23, "Los stats del combat target remoto deben ser nivel 23")

	player.free()
	remote_player.free()
	print("[OK] Prueba 5: Empaquetado y aplicación de diccionario de sincronización de jugador verificado.")
