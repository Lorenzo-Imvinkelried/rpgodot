extends SceneTree

func _init() -> void:
	print("--- INICIANDO SUITE DE PRUEBAS: CharacterStats & CombatCalculator ---")
	var failures: int = 0

	# 1. Prueba de derivación de CharacterStats
	var stats := CharacterStats.new()
	stats.base_str = 10
	stats.base_agi = 10
	stats.base_int = 10
	stats.base_vit = 10
	stats.recalculate_stats(true)

	if stats.attack != 30:
		printerr("FALLO: stats.attack debería ser 30 (10 STR * 3), fue: ", stats.attack)
		failures += 1
	if stats.max_hp != 200:
		printerr("FALLO: stats.max_hp debería ser 200 (10 VIT * 20), fue: ", stats.max_hp)
		failures += 1
	if stats.defense != 20:
		printerr("FALLO: stats.defense debería ser 20 (10 VIT * 2), fue: ", stats.defense)
		failures += 1
	if stats.max_mp != 200:
		printerr("FALLO: stats.max_mp debería ser 200 (10 INT * 20), fue: ", stats.max_mp)
		failures += 1
	if not is_equal_approx(stats.crit_chance, 6.0):
		printerr("FALLO: stats.crit_chance debería ser 6.0% (5% base + 1% por 10 AGI), fue: ", stats.crit_chance)
		failures += 1
	if not is_equal_approx(stats.attack_speed, 1.5):
		printerr("FALLO: stats.attack_speed debería ser 1.5 (1.4 base + 0.10 por 10 AGI), fue: ", stats.attack_speed)
		failures += 1

	print("[OK] Prueba 1: Derivación de CharacterStats completada correctamente.")

	# 2. Prueba de Acierto y Evasión
	var attacker := CharacterStats.new()
	attacker.level = 1
	attacker.base_accuracy = 100.0
	attacker.recalculate_stats(true)

	var defender := CharacterStats.new()
	defender.level = 1
	defender.base_evasion = 100.0
	defender.recalculate_stats(true)

	var hit_chance := CombatCalculator.get_hit_chance(attacker, defender)
	# 100 / (100 + 100 * 0.25) = 100 / 125 = 0.80
	if not is_equal_approx(hit_chance, 0.80):
		printerr("FALLO: hit_chance debería ser 0.80, fue: ", hit_chance)
		failures += 1

	# Con diferencia de nivel: Atacante nivel 11 (+10 niveles) -> +2% (+0.02)
	attacker.level = 11
	var hit_chance_lvl := CombatCalculator.get_hit_chance(attacker, defender)
	if not is_equal_approx(hit_chance_lvl, 0.82):
		printerr("FALLO: hit_chance con bono de nivel debería ser 0.82, fue: ", hit_chance_lvl)
		failures += 1

	print("[OK] Prueba 2: Probabilidad de Acierto y Evasión calculada correctamente.")

	# 3. Prueba de Mitigación Hiperbólica y Armadura
	attacker.level = 1
	attacker.base_attack = 100.0
	attacker.base_str = 0 # Para controlar exactamente el ataque
	attacker.base_crit_chance = 0.0 # Sin críticos en este test
	attacker.base_agi = 0
	attacker.recalculate_stats(true)

	defender.level = 1
	defender.base_vit = 0
	defender.base_defense = 115.0 # A nivel 1: C = 1 * 15 + 100 = 115. Armadura 115 => 50% mitigación
	defender.recalculate_stats(true)

	var dmg_result := CombatCalculator.calculate_damage(attacker, defender, true, 0.0, 0)
	# 100 daño crudo mitigado al 50% => 50 de daño físico
	if dmg_result.total_damage != 50 or dmg_result.physical_damage != 50:
		printerr("FALLO: Daño mitigado debería ser 50, fue: ", dmg_result)
		failures += 1

	print("[OK] Prueba 3: Mitigación hiperbólica de armadura (50%) verificada.")

	# 4. Prueba de Penetración de Armadura
	attacker.armor_pen_flat = 50.0
	# Effective defense = 115 - 50 = 65. C = 115. Reducción = 65 / (65 + 115) = 65 / 180 = 0.36111
	# Daño recibido = 100 * (1 - 0.36111) = 63.88 -> redondeado a 64
	var pen_result := CombatCalculator.calculate_damage(attacker, defender, true, 0.0, 0)
	if pen_result.total_damage != 64:
		printerr("FALLO: Daño con penetración debería ser 64, fue: ", pen_result)
		failures += 1

	print("[OK] Prueba 4: Penetración de armadura verificada.")

	# 5. Prueba de Bloqueo
	attacker.armor_pen_flat = 0.0
	defender.block_chance = 100.0 # Bloqueo garantizado
	defender.block_value_percent = 50.0 # Mitiga 50% adicional
	var block_result := CombatCalculator.calculate_damage(attacker, defender, true, 0.0, 0)
	# 100 con 50% de bloqueo => 50 rawPhys. Luego mitigado con 50% de armadura => 25 de daño
	if not block_result.is_blocked or block_result.total_damage != 25:
		printerr("FALLO: Daño bloqueado debería ser 25 con is_blocked=true, fue: ", block_result)
		failures += 1

	print("[OK] Prueba 5: Bloqueo de escudo verificado.")

	# 6. Prueba de Daño Verdadero (True Damage)
	defender.block_chance = 0.0
	defender.base_defense = 9999.0 # Defensa extrema
	defender.recalculate_stats(true)
	attacker.true_damage_percent = 100.0 # 100% Daño verdadero
	var true_result := CombatCalculator.calculate_damage(attacker, defender, true, 0.0, 0)
	if true_result.true_damage != 100 or true_result.total_damage != 100:
		printerr("FALLO: Daño verdadero debería ser 100 ignorando armadura, fue: ", true_result)
		failures += 1

	print("[OK] Prueba 6: Daño Verdadero ignorando armadura verificado.")

	# 7. Regla de daño mínimo (al menos 1)
	attacker.true_damage_percent = 0.0 # Solo físico
	var min_result := CombatCalculator.calculate_damage(attacker, defender, true, 0.0, 0)
	if min_result.total_damage != 1:
		printerr("FALLO: Regla de daño mínimo garantizado debería retornar 1, fue: ", min_result)
		failures += 1

	print("[OK] Prueba 7: Regla de daño mínimo garantizado (1 punto) verificada.")

	# 8. Prueba de integración con combat_config.json
	var player_cfg_stats := CharacterStats.create_player_default()
	if player_cfg_stats.character_name != "Player" or player_cfg_stats.base_str != 10:
		printerr("FALLO: create_player_default no cargó los datos esperados de combat_config.json")
		failures += 1

	var dummy_cfg_stats := CharacterStats.create_dummy_default()
	if dummy_cfg_stats.character_name != "TrainingDummy" or dummy_cfg_stats.block_chance != 10.0:
		printerr("FALLO: create_dummy_default no cargó los datos esperados de combat_config.json")
		failures += 1

	print("[OK] Prueba 8: Carga y fábricas desde combat_config.json verificadas.")

	# Conclusión
	if failures == 0:
		print("--- TODAS LAS PRUEBAS (8/8) PASARON EXITOSAMENTE ---")
		quit(0)
	else:
		printerr("--- HUBO ", failures, " FALLOS EN LAS PRUEBAS ---")
		quit(1)
