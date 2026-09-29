@tool
extends SceneTree

## Suite de verificación automatizada para Fase 4: Mecánicas On-Hit y Control de Masas (CC).
## Valida Lifesteal, Mana Steal, Thorns, Stun con Tenacidad, Bleed sin snapshotting y Slow.

const StatusEffectControllerScript = preload("res://scripts/combat/status_effect_controller.gd")

func _init() -> void:
	print("\n--- INICIANDO SUITE DE PRUEBAS: Fase 4 (On-Hit & Control de Masas) ---")
	_run_all_tests()

func _run_all_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Robo de Vida (Lifesteal)
	# --------------------------------------------------------------------------
	var attacker := CharacterStats.new()
	attacker.base_str = 10
	attacker.base_max_hp = 100.0
	attacker.lifesteal_percent = 20.0 # 20% de robo de vida
	attacker.recalculate_stats(true)
	attacker.current_hp = 60 # Dañado a 60/100

	var heal_amt := CombatCalculator.calculate_lifesteal(attacker, 100)
	assert(heal_amt == 20, "El 20% de 100 debe curar exactamente 20 HP")
	var actual_healed := attacker.heal(heal_amt)
	assert(actual_healed == 20, "Debe curar 20 puntos efectivos")
	assert(attacker.current_hp == 80, "La salud debe ser 80 tras curarse")
	print("[OK] Prueba 1: Robo de Vida (Lifesteal) verificado (20 HP curados).")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Robo de Maná (Mana Steal)
	# --------------------------------------------------------------------------
	attacker.mana_steal_percent = 15.0 # 15% robo de maná
	attacker.current_mp = 10
	var mana_amt := CombatCalculator.calculate_mana_steal(attacker, 100)
	assert(mana_amt == 15, "El 15% de 100 debe restaurar 15 MP")
	attacker.restore_mana(mana_amt)
	assert(attacker.current_mp == 25, "El maná debe ser 25 tras la restauración")
	print("[OK] Prueba 2: Robo de Maná (Mana Steal) verificado (15 MP restaurados).")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Espinas (Thorns) con mitigación de armadura del atacante
	# --------------------------------------------------------------------------
	var defender := CharacterStats.new()
	defender.thorns_percent = 40.0 # 40% de espinas
	defender.recalculate_stats(true)

	attacker.base_defense = 100.0 # Con constante 100, 100 def mitiga exactamente 50%
	attacker.recalculate_stats(false)

	# Defensor recibe 100 de daño físico
	var thorns_res := CombatCalculator.calculate_thorns_damage(defender, attacker, 100, false)
	assert(thorns_res != null, "Las espinas deben generar un DamageResult")
	assert(thorns_res.is_thorns == true, "El resultado debe estar marcado con is_thorns = true")
	# 40% de 100 = 40 raw thorns. Con 50% mitigación de armadura de atacante -> 20 de daño reflejado
	assert(thorns_res.total_damage == 20, "40 raw mitigado al 50%% debe reflejar 20 de daño (obtenido: %d)" % thorns_res.total_damage)
	print("[OK] Prueba 3: Espinas (Thorns) mitigadas por armadura del atacante verificadas (20 reflejados).")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Inmunidad de Espinas ante Daño Verdadero puro
	# --------------------------------------------------------------------------
	var thorns_true := CombatCalculator.calculate_thorns_damage(defender, attacker, 100, true)
	assert(thorns_true == null, "El daño verdadero puro no debe activar espinas")
	print("[OK] Prueba 4: Inmunidad de Espinas a Daño Verdadero puro verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Aturdimiento (Stun) y mitigación por Tenacidad
	# --------------------------------------------------------------------------
	attacker.stun_chance = 100.0 # 100% acierto forzado
	attacker.stun_duration = 2.0 # 2.0s base
	defender.tenacity_percent = 30.0 # 30% tenacidad

	var stun_eff := CombatCalculator.calculate_stun_duration(attacker, defender, 50.0)
	var expected_eff := 2.0 * (1.0 - 0.30) # 1.4s
	assert(is_equal_approx(stun_eff, expected_eff), "Duración con 30% tenacidad debe ser 1.4s")

	# Tenacidad total (100% o superior)
	defender.tenacity_percent = 100.0
	var stun_immune := CombatCalculator.calculate_stun_duration(attacker, defender, 50.0)
	assert(stun_immune == 0.0, "Con 100% de tenacidad debe ser 0.0s (inmune)")

	# Umbral mínimo de inmunidad (<= 0.05s)
	defender.tenacity_percent = 98.0 # 2.0s * 0.02 = 0.04s
	var stun_subthreshold := CombatCalculator.calculate_stun_duration(attacker, defender, 50.0)
	assert(stun_subthreshold == 0.0, "Duraciones <= 0.05s deben descartarse como 0.0s")
	print("[OK] Prueba 5: Aturdimiento (Stun) con Tenacidad y umbral mínimo verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 6: Sangrado Continuo (Bleed System sin Snapshotting)
	# --------------------------------------------------------------------------
	attacker.base_str = 0 # 0 fuerza para que el ataque sea exactamente igual a base_attack
	attacker.base_attack = 100.0
	attacker.recalculate_stats(false)
	defender.base_vit = 0
	defender.base_defense = 0.0
	defender.recalculate_stats(false)

	# Tick con 10 plano + 20% del ataque actual (20) = 30 de daño
	var bleed_tick_1 := CombatCalculator.calculate_bleed_tick(attacker, defender, 10, 20.0)
	assert(bleed_tick_1 != null and bleed_tick_1.is_bleed == true, "Debe ser resultado de sangrado")
	assert(bleed_tick_1.total_damage == 30, "10 plano + 20%% de 100 atk = 30 daño (obtenido: %d)" % bleed_tick_1.total_damage)

	# Regla contra Snapshotting: El atacante aumenta su ataque a 200 (buff temporal o equipamiento)
	attacker.base_attack = 200.0
	attacker.recalculate_stats(false)
	var bleed_tick_2 := CombatCalculator.calculate_bleed_tick(attacker, defender, 10, 20.0)
	# 10 plano + 20% de 200 atk = 10 + 40 = 50 de daño
	assert(bleed_tick_2.total_damage == 50, "Sin snapshotting, con 200 atk debe ser 50 daño (obtenido: %d)" % bleed_tick_2.total_damage)
	print("[OK] Prueba 6: Sangrado Continuo (Bleed) recalculado sin snapshotting verificado.")

	# --------------------------------------------------------------------------
	# PRUEBA 7: StatusEffectController (Stun lock, Slow & Tick Logic)
	# --------------------------------------------------------------------------
	var status_node := StatusEffectControllerScript.new()
	root.add_child(status_node)

	# Stun
	assert(status_node.is_stunned() == false, "No debe empezar aturdido")
	status_node.apply_stun(1.5)
	assert(status_node.is_stunned() == true, "Debe estar aturdido tras apply_stun")
	assert(status_node.get_move_speed_multiplier() == 0.0, "La velocidad debe ser 0.0 bajo Stun")
	assert(status_node.get_attack_speed_multiplier() == 0.0, "La velocidad de ataque debe ser 0.0 bajo Stun")

	# Limpiar Stun y aplicar Slow
	status_node.clear_all_effects()
	assert(status_node.is_stunned() == false, "Stun debe haberse limpiado")
	status_node.apply_slow(35.0, 25.0, 3.0) # 35% slow move, 25% slow atk
	assert(status_node.is_slowed() == true, "Debe estar ralentizado")
	assert(is_equal_approx(status_node.get_move_speed_multiplier(), 0.65), "Velocidad de movimiento debe ser 0.65x")
	assert(is_equal_approx(status_node.get_attack_speed_multiplier(), 0.75), "Velocidad de ataque debe ser 0.75x")

	status_node.queue_free()
	print("[OK] Prueba 7: StatusEffectController (Multiplicadores de Stun y Slow) verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 8: Integración en combate de nodos (CombatTarget Thorns + Lifesteal)
	# --------------------------------------------------------------------------
	var p_node := Node3D.new()
	var p_target := CombatTarget.new()
	p_target.stats = attacker
	attacker.base_max_hp = 100.0
	attacker.lifesteal_percent = 25.0 # 25% robo de vida
	attacker.base_defense = 0.0
	attacker.base_vit = 0
	attacker.recalculate_stats(true)
	attacker.current_hp = 50 # 50/100
	p_node.add_child(p_target)
	root.add_child(p_node)

	var d_node := Node3D.new()
	var d_target := CombatTarget.new()
	d_target.stats = defender
	defender.base_max_hp = 200.0
	defender.thorns_percent = 20.0 # 20% espinas
	defender.base_defense = 0.0
	defender.base_vit = 0
	defender.recalculate_stats(true)
	d_node.add_child(d_target)
	root.add_child(d_node)

	# El atacante impacta al defensor por 40 de daño
	var hit_res := DamageResult.new()
	hit_res.total_damage = 40
	hit_res.physical_damage = 40

	d_target.take_combat_result(hit_res, Vector3.ZERO, p_node)

	assert(d_target.current_health == 160.0, "Defensor debe quedar en 160 HP (obtenido: %f)" % d_target.current_health)
	assert(p_target.current_health == 52.0, "Atacante debe quedar en 52 HP tras curar 10 y recibir 8 de espinas (obtenido: %f)" % p_target.current_health)
	print("[OK] Prueba 8: Integración de Combate en vivo (Lifesteal + Thorns cruzados) verificada exitosamente.")

	p_node.queue_free()
	d_node.queue_free()

	print("--- TODAS LAS PRUEBAS DE FASE 4 (8/8) PASARON EXITOSAMENTE ---\n")
	quit(0)
