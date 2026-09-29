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

	# --------------------------------------------------------------------------
	# PRUEBA 9: Ondas Expansivas / Cleave en Área (AoE Cleave Waves)
	# --------------------------------------------------------------------------
	var attacker_node := CharacterBody3D.new()
	var attacker_comp := CombatTarget.new()
	var atk_stats_aoe := CharacterStats.new()
	atk_stats_aoe.base_str = 0
	atk_stats_aoe.base_attack = 50.0
	atk_stats_aoe.aoe_radius = 4.0 # 4 metros de radio
	atk_stats_aoe.aoe_damage_percent = 50.0 # 50% de daño a objetivos secundarios
	atk_stats_aoe.recalculate_stats(true)
	attacker_comp.stats = atk_stats_aoe
	attacker_node.add_child(attacker_comp)

	var combat_ctrl := CombatController.new()
	attacker_node.add_child(combat_ctrl)
	root.add_child(attacker_node)
	combat_ctrl._parent_body = attacker_node

	# Objetivo Primario (a 1 metro)
	var prim_node := StaticBody3D.new()
	prim_node.position = Vector3(1.0, 0, 0)
	prim_node.add_to_group("targetable")
	var prim_target := CombatTarget.new()
	var prim_stats := CharacterStats.new()
	prim_stats.base_vit = 0
	prim_stats.base_defense = 0.0
	prim_stats.base_max_hp = 100.0
	prim_stats.recalculate_stats(true)
	prim_target.stats = prim_stats
	prim_node.add_child(prim_target)
	root.add_child(prim_node)

	# Objetivo Secundario en rango (a 2 metros del primario)
	var sec_node := StaticBody3D.new()
	sec_node.position = Vector3(3.0, 0, 0) # Distancia al primario: 2 metros (dentro de radio 4.0)
	sec_node.add_to_group("targetable")
	var sec_target := CombatTarget.new()
	var sec_stats := CharacterStats.new()
	sec_stats.base_vit = 0
	sec_stats.base_defense = 0.0
	sec_stats.base_max_hp = 100.0
	sec_stats.recalculate_stats(true)
	sec_target.stats = sec_stats
	sec_node.add_child(sec_target)
	root.add_child(sec_node)

	# Objetivo Lejano fuera de rango (a 8 metros del primario)
	var far_node := StaticBody3D.new()
	far_node.position = Vector3(9.0, 0, 0) # Distancia al primario: 8 metros (> 4.0m)
	far_node.add_to_group("targetable")
	var far_target := CombatTarget.new()
	var far_stats := CharacterStats.new()
	far_stats.base_vit = 0
	far_stats.base_defense = 0.0
	far_stats.base_max_hp = 100.0
	far_stats.recalculate_stats(true)
	far_target.stats = far_stats
	far_node.add_child(far_target)
	root.add_child(far_node)

	# Esperar un ciclo de frames para que los nodos ingresen al árbol y registren el grupo 'targetable'
	await process_frame

	var primary_hit := DamageResult.new()
	primary_hit.total_damage = 40
	primary_hit.physical_damage = 40
	prim_target.take_combat_result(primary_hit, prim_node.global_position, attacker_node)

	# Invocamos la onda de cleave de CombatController
	combat_ctrl._apply_aoe_cleave(prim_node, primary_hit, atk_stats_aoe)

	assert(prim_target.current_health == 60.0, "Objetivo primario debe recibir 40 de daño (obtenido: %f)" % prim_target.current_health)
	assert(sec_target.current_health == 80.0, "Objetivo en radio de cleave debe recibir 50%% de daño = 20 (obtenido: %f)" % sec_target.current_health)
	assert(far_target.current_health == 100.0, "Objetivo fuera de radio de cleave debe conservar 100 HP (obtenido: %f)" % far_target.current_health)
	print("[OK] Prueba 9: Ondas Expansivas / Cleave en Área (AoE Cleave Waves) verificadas exitosamente.")

	attacker_node.queue_free()
	prim_node.queue_free()
	sec_node.queue_free()
	far_node.queue_free()

	# --------------------------------------------------------------------------
	# PRUEBA 10: Esquiva con I-Frames (Dash Invulnerability)
	# --------------------------------------------------------------------------
	var dodge_target := CombatTarget.new()
	var dodge_stats := CharacterStats.new()
	dodge_stats.base_vit = 0
	dodge_stats.base_max_hp = 100.0
	dodge_stats.recalculate_stats(true)
	dodge_target.stats = dodge_stats
	root.add_child(dodge_target)

	var initial_hp := dodge_target.current_health
	var test_dmg := DamageResult.new()
	test_dmg.total_damage = 25
	dodge_target.take_combat_result(test_dmg, Vector3.ZERO, null)
	assert(dodge_target.current_health == initial_hp - 25.0, "Sin invulnerabilidad debe recibir 25 de daño (obtenido: %f)" % dodge_target.current_health)

	dodge_target.trigger_invulnerability(0.20)
	assert(dodge_target.is_invulnerable == true, "Debe estar invulnerable tras trigger_invulnerability")

	var dodge_dmg := DamageResult.new()
	dodge_dmg.total_damage = 50
	dodge_target.take_combat_result(dodge_dmg, Vector3.ZERO, null)
	assert(dodge_target.current_health == initial_hp - 25.0, "Durante I-Frames no debe recibir ningún daño (conserva %f HP)" % dodge_target.current_health)

	dodge_target._process(0.25)
	assert(dodge_target.is_invulnerable == false, "Tras expirar el temporizador ya no debe estar invulnerable")

	dodge_target.take_combat_result(test_dmg, Vector3.ZERO, null)
	assert(dodge_target.current_health == initial_hp - 50.0, "Tras terminar el dash vuelve a recibir daño (obtenido: %f)" % dodge_target.current_health)
	print("[OK] Prueba 10: Esquiva con I-Frames (Dash Invulnerability) verificada exitosamente.")

	dodge_target.queue_free()

	# --------------------------------------------------------------------------
	# PRUEBA 11: Guardia Activa con Escudo (Active Shield Guard)
	# --------------------------------------------------------------------------
	var guard_target := CombatTarget.new()
	var guard_stats := CharacterStats.new()
	guard_stats.block_chance = 10.0
	guard_stats.block_value_percent = 50.0
	guard_stats.recalculate_stats(true)
	guard_target.stats = guard_stats
	root.add_child(guard_target)

	assert(guard_target.is_guarding == false, "No debe empezar cubriéndose")
	assert(guard_stats.block_chance == 10.0, "Probabilidad de bloqueo inicial debe ser 10%")

	guard_target.is_guarding = true
	assert(guard_target.is_guarding == true, "Debe reportar postura de guardia activa")
	assert(guard_stats.block_chance == 50.0, "Guardia debe sumar +40%% a la probabilidad de bloqueo (obtenido: %f)" % guard_stats.block_chance)
	assert(guard_stats.block_value_percent == 75.0, "Guardia debe sumar +25%% al valor de bloqueo (obtenido: %f)" % guard_stats.block_value_percent)

	guard_target.is_guarding = false
	assert(guard_stats.block_chance == 10.0, "Al soltar guardia debe regresar a 10% de probabilidad")
	assert(guard_stats.block_value_percent == 50.0, "Al soltar guardia debe regresar a 50% de valor")
	print("[OK] Prueba 11: Guardia Activa con Escudo (Active Shield Guard) verificada exitosamente.")

	guard_target.queue_free()

	# --------------------------------------------------------------------------
	# PRUEBA 12: Badges de Estados Alterados y Guardia en HealthBar3D
	# --------------------------------------------------------------------------
	var hbar_scene := load("res://scenes/combat/health_bar_3d.tscn")
	var hbar_instance: HealthBar3D = hbar_scene.instantiate()
	var dummy_entity := Node3D.new()
	var hbar_combat_target := CombatTarget.new()
	hbar_combat_target.target_name = "Muñeco"
	var hbar_status_ctrl := StatusEffectControllerScript.new()

	dummy_entity.add_child(hbar_combat_target)
	dummy_entity.add_child(hbar_status_ctrl)
	dummy_entity.add_child(hbar_instance)
	root.add_child(dummy_entity)

	# Esperar a que HealthBar3D._ready() ejecute el auto-binding
	await process_frame

	hbar_instance.set_entity_name("Muñeco")
	assert(hbar_instance.name_label.text == "Muñeco", "Nombre base debe ser 'Muñeco'")

	# Aplicar Stun -> debe aparecer [💫]
	hbar_status_ctrl.apply_stun(2.0)
	assert(hbar_instance.name_label.text.find("💫") != -1, "Debe mostrar icono de Aturdimiento 💫 (obtenido: '%s')" % hbar_instance.name_label.text)

	# Activar Guardia -> debe agregarse [🛡]
	hbar_combat_target.is_guarding = true
	assert(hbar_instance.name_label.text.find("🛡") != -1, "Debe mostrar icono de Guardia 🛡 (obtenido: '%s')" % hbar_instance.name_label.text)

	# Quitar estados -> debe volver a "Muñeco"
	hbar_combat_target.is_guarding = false
	hbar_status_ctrl.clear_all_effects()
	assert(hbar_instance.name_label.text == "Muñeco", "Al limpiar efectos debe volver a 'Muñeco' sin badges (obtenido: '%s')" % hbar_instance.name_label.text)
	print("[OK] Prueba 12: Badges Visuales en HealthBar3D verificados exitosamente.")

	dummy_entity.queue_free()

	print("--- TODAS LAS PRUEBAS DE FASE 4 (12/12) PASARON EXITOSAMENTE ---\n")
	quit(0)

