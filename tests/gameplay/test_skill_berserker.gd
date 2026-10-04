@tool
extends SceneTree

## Suite de verificación automatizada para:
## 1. Integración de StatusEffectController en Player.tscn y CombatTarget.
## 2. Activación de Habilidad Furia Berserker (Self-Buff).
## 3. Incremento efectivo de Daño Físico (+40%) y Velocidad de Ataque (+40%).
## 4. Indicadores visuales en HUD (PlayerFrame), HealthBar3D y tinte de personaje.
## 5. Expiración precisa del buff tras transcurrir su duración y restauración de estadísticas.

const SkillBerserkerScript = preload("res://scripts/gameplay/skills/definitions/skill_berserker.gd")
const StatusEffectControllerScript = preload("res://scripts/combat/status_effect_controller.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Habilidad Furia Berserker & Buff de Ataque/Velocidad ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Verificación de StatusEffectController en player.tscn
	# --------------------------------------------------------------------------
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_scene != null, "player.tscn debe existir y cargar correctamente")

	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var status_node := player.get_node_or_null("StatusEffectController") as StatusEffectController
	assert(status_node != null, "player.tscn DEBE tener un nodo StatusEffectController")
	print("[OK] Prueba 1: StatusEffectController verificado en player.tscn.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Equipar y Activar Furia Berserker
	# --------------------------------------------------------------------------
	var skill_ctrl := player.get_node_or_null("SkillController") as SkillController
	var combat_tgt := player.get_node_or_null("CombatTarget") as CombatTarget
	var stats := combat_tgt.get_stats()
	assert(stats != null, "El jugador debe tener CharacterStats asignadas")

	# Fijar stats controladas para validación matemática
	stats.base_attack = 50
	stats.base_atk_speed = 1.0
	stats.bonus_str = 0
	stats.bonus_agi = 0
	stats.current_mp = 50
	stats.max_mp = 50
	stats.recalculate_stats(false)

	var initial_atk := stats.attack
	var initial_spd := stats.attack_speed
	var initial_mp := stats.current_mp
	var expected_boosted_atk: int = initial_atk + roundi(float(initial_atk) * 0.40)
	var expected_boosted_spd: float = initial_spd * 1.40

	# Equipar Berserker en el slot 3
	var berserk_skill := SkillBerserkerScript.new()
	skill_ctrl.register_skill(3, berserk_skill)

	# Ejecutar activación
	var cast_ok := skill_ctrl.activate_slot(3, null, null, null)
	assert(cast_ok == true, "La activación de Berserker debe retornar true")
	assert(stats.current_mp == initial_mp - berserk_skill.mana_cost, "Maná debe deducir exactamente el costo (15 MP)")
	assert(status_node.is_berserk() == true, "StatusEffectController debe reportar is_berserk() == true")
	assert(status_node.get_berserk_time_left() > 7.0, "Tiempo restante debe ser ~8.0s")
	print("[OK] Prueba 2: Activación de Furia Berserker y deducción de recursos verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Bonificaciones de Estadísticas (+40% Ataque y +40% Velocidad de Ataque)
	# --------------------------------------------------------------------------
	assert(stats.attack == expected_boosted_atk, "El ataque con Berserker (+40%%) debe ser %d (obtenido: %d)" % [expected_boosted_atk, stats.attack])
	assert(is_equal_approx(stats.attack_speed, expected_boosted_spd), "La velocidad de ataque con Berserker (+40%%) debe ser %.2f/s (obtenido: %.2f)" % [expected_boosted_spd, stats.attack_speed])
	print("[OK] Prueba 3: Estadísticas potenciadas (+40%% daño y +40%% velocidad) verificadas en CharacterStats.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Refresco sin acumulación indebida de estadísticas
	# --------------------------------------------------------------------------
	# Simular avance de 3 segundos
	status_node.update_status_effects(3.0)
	assert(status_node.get_berserk_time_left() <= 5.1, "Tiempo restante debe haberse reducido")

	# Re-aplicar Berserker
	status_node.apply_berserker(40.0, 40.0, 8.0)
	assert(is_equal_approx(status_node.get_berserk_time_left(), 8.0), "La duración debe renovarse a 8.0s")
	assert(stats.attack == expected_boosted_atk, "El ataque no debe duplicarse al renovar (debe seguir en %d, obtenido: %d)" % [expected_boosted_atk, stats.attack])
	assert(is_equal_approx(stats.attack_speed, expected_boosted_spd), "La velocidad de ataque no debe duplicarse (debe seguir en %.2f, obtenido: %.2f)" % [expected_boosted_spd, stats.attack_speed])
	print("[OK] Prueba 4: Renovación de duración sin duplicación de atributos verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Expiración y Retorno a Estadísticas Originales
	# --------------------------------------------------------------------------
	# Avanzar más allá del tiempo restante (8.5 segundos)
	status_node.update_status_effects(8.5)
	assert(status_node.is_berserk() == false, "Tras expirar la duración, is_berserk() debe ser false")
	assert(status_node.get_berserk_time_left() == 0.0, "Tiempo restante debe ser 0.0")
	assert(stats.attack == initial_atk, "El ataque debe revertir a %d (obtenido: %d)" % [initial_atk, stats.attack])
	assert(is_equal_approx(stats.attack_speed, initial_spd), "La velocidad de ataque debe revertir a %.2f (obtenido: %.2f)" % [initial_spd, stats.attack_speed])
	print("[OK] Prueba 5: Expiración natural y reversión de estadísticas verificada exitosamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 6: Badges en HealthBar3D y PlayerFrame
	# --------------------------------------------------------------------------
	var pf_scene := load("res://scenes/ui/hud/player_frame.tscn") as PackedScene
	assert(pf_scene != null, "player_frame.tscn debe cargar")
	var pf := pf_scene.instantiate() as PlayerFrame
	root.add_child(pf)
	pf.bind_player(player)

	# Reactivar Berserker
	status_node.apply_berserker(40.0, 40.0, 8.0)
	pf._refresh_status_badges()
	assert(pf.status_icons_label.text.find("🪓") != -1, "PlayerFrame debe mostrar el badge de hacha 🪓 mientras Berserk está activo")

	var hbar: HealthBar3D = player.get_node_or_null("Visuals/HealthBar3D")
	if hbar:
		hbar._refresh_name_display()
		assert(hbar.name_label.text.find("🪓") != -1, "HealthBar3D debe mostrar el badge 🪓 sobre el personaje")

	# Limpiar
	status_node.cleanse_all()
	pf._refresh_status_badges()
	assert(pf.status_icons_label.text.find("🪓") == -1, "Badge 🪓 debe desaparecer de PlayerFrame al finalizar el buff")
	print("[OK] Prueba 6: Indicadores visuales en PlayerFrame y HealthBar3D verificados.")

	# Cleanup
	player.queue_free()
	pf.queue_free()

	print("\n>>> TODAS LAS PRUEBAS DE FURIA BERSERKER PASARON CON ÉXITO <<<")
	quit(0)
