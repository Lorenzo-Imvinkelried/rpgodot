@tool
extends SceneTree

## Suite de verificación automatizada para el Sistema de Progresión (EXP, Subida de Nivel y Stats).

const ProgressionFormulaScript = preload("res://scripts/gameplay/progression/progression_formula.gd")
const ProgressionControllerScript = preload("res://scripts/gameplay/progression/progression_controller.gd")
const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Sistema de Experiencia, Niveles y Estadísticas ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Fórmulas Matemáticas de Curva de EXP y Escalado de Atributos
	# --------------------------------------------------------------------------
	var xp_lvl1: int = ProgressionFormulaScript.get_xp_required_for_level(1)
	var xp_lvl2: int = ProgressionFormulaScript.get_xp_required_for_level(2)
	var xp_lvl3: int = ProgressionFormulaScript.get_xp_required_for_level(3)

	assert(xp_lvl1 > 100, "EXP nivel 1 debe ser mayor a 100 (obtenido: %d)" % xp_lvl1)
	assert(xp_lvl2 > xp_lvl1, "La curva debe ser incremental (Lvl 2 > Lvl 1)")
	assert(xp_lvl3 > xp_lvl2, "La curva debe ser incremental (Lvl 3 > Lvl 2)")

	var gains: Dictionary = ProgressionFormulaScript.get_stat_gains(2)
	assert(gains.has("base_str") and gains["base_str"] > 0, "Debe otorgar incremento de Fuerza")
	assert(gains.has("base_vit") and gains["base_vit"] > 0, "Debe otorgar incremento de Vitalidad")
	print("[OK] Prueba 1: Fórmulas de progresión y curva de experiencia validadas (L1: %d, L2: %d, L3: %d XP)." % [xp_lvl1, xp_lvl2, xp_lvl3])

	# --------------------------------------------------------------------------
	# PRUEBA 2: Acumulación de Experiencia y Subida de Nivel en ProgressionController
	# --------------------------------------------------------------------------
	var target_node := Node3D.new()
	var combat_tgt := CombatTarget.new()
	combat_tgt.name = "CombatTarget"
	combat_tgt.target_name = "Player"
	target_node.add_child(combat_tgt)
	root.add_child(target_node)
	await process_frame

	var prog := ProgressionControllerScript.new()
	target_node.add_child(prog)
	prog.setup(combat_tgt)

	var init_level := prog.current_level
	var init_str := combat_tgt.get_stats().base_str
	var init_hp := combat_tgt.get_stats().max_hp
	var init_atk := combat_tgt.get_stats().attack
	var req_xp := prog.xp_required

	# Ganar una porción de EXP que no alcance para subir de nivel
	prog.add_experience(int(req_xp * 0.5))
	assert(prog.current_level == init_level, "No debe subir de nivel aún")
	assert(prog.current_exp == int(req_xp * 0.5), "EXP actual debe ser la acumulada")

	# Ganar el resto para completar el nivel
	var tracker := { "leveled": false }
	prog.level_up.connect(func(_lvl: int, _g: Dictionary): tracker["leveled"] = true)
	prog.add_experience(int(req_xp * 0.6))
	assert(tracker["leveled"], "Señal level_up debe haberse emitido")
	assert(prog.current_level == init_level + 1, "Debe haber subido al nivel 2")
	assert(combat_tgt.get_stats().level == 2, "CharacterStats debe reflejar el nivel 2")
	assert(combat_tgt.get_stats().base_str > init_str, "Fuerza base debe haber aumentado")
	assert(combat_tgt.get_stats().max_hp > init_hp, "Max HP debe haber aumentado con el nivel")
	assert(combat_tgt.get_stats().attack > init_atk, "Poder de ataque debe haber aumentado con el nivel")
	assert(combat_tgt.current_health == combat_tgt.max_health, "Salud debe rellenarse al 100% al subir de nivel")
	print("[OK] Prueba 2: Subida de nivel, incremento de atributos primarios y recalculo de stats vitales/ofensivos verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Otorgamiento de Experiencia al Morir un Mob (Goblin -> Player)
	# --------------------------------------------------------------------------
	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	root.add_child(player)
	await process_frame

	var goblin_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	var goblin = goblin_scene.instantiate()
	root.add_child(goblin)
	await process_frame

	var p_prog := player.progression_controller
	assert(p_prog != null, "Player debe poseer ProgressionController")
	var prev_exp := p_prog.current_exp

	# Simular impacto del player sobre el goblin
	var g_target: CombatTarget = goblin.get_node_or_null("CombatTarget")
	assert(g_target != null, "Goblin debe tener CombatTarget")

	# El jugador le asesta daño letal
	goblin._on_combat_target_hit(100.0, goblin.global_position, player)
	g_target.current_health = 0.0
	g_target.died.emit()
	goblin._on_combat_target_died()

	assert(p_prog.current_exp > prev_exp or p_prog.current_level > 1,
		"Al morir el mob, el Player debe haber recibido la experiencia correspondiente (exp previa: %d, actual: %d)" % [prev_exp, p_prog.current_exp])
	print("[OK] Prueba 3: Otorgamiento automático de XP al matar un mob verificado exitosamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Gran Jefe Dragón y Multi-Level Up
	# --------------------------------------------------------------------------
	var dragon_scene := load("res://scenes/enemies/mob_dragon_boss.tscn") as PackedScene
	var dragon = dragon_scene.instantiate()
	root.add_child(dragon)
	await process_frame

	var lvl_before_boss := player.get_level()
	var d_target: CombatTarget = dragon.get_node_or_null("CombatTarget")
	dragon._on_combat_target_hit(5000.0, dragon.global_position, player)
	d_target.current_health = 0.0
	d_target.died.emit()
	dragon._on_combat_target_died()

	assert(player.get_level() > lvl_before_boss,
		"Derrotar al Gran Dragón Boss (2500+ XP) debe promover al Player al menos a un nivel superior (antes: %d, ahora: %d)" % [lvl_before_boss, player.get_level()])
	print("[OK] Prueba 4: Muerte de Boss con alta recompensa de XP y subida de nivel validada (Lvl %d -> Lvl %d)." % [lvl_before_boss, player.get_level()])

	# --------------------------------------------------------------------------
	# PRUEBA 5: Integración Visual y UI (ExpBar, PlayerFrame, CharacterPanel)
	# --------------------------------------------------------------------------
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud: GameHUD = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame

	hud.bind_player(player)

	assert(hud.exp_bar.current_exp == p_prog.current_exp, "ExpBar debe estar sincronizada con la XP del jugador")
	assert(hud.exp_bar.max_exp == p_prog.xp_required, "ExpBar debe reflejar el umbral del nivel actual")
	assert(hud.player_frame.level_label.text.contains(str(player.get_level())), "PlayerFrame debe mostrar el nivel actual del jugador")

	# Simular ganancia adicional de EXP para verificar reactividad de la barra
	player.add_experience(150)
	assert(hud.exp_bar.current_exp == p_prog.current_exp, "ExpBar debe actualizarse inmediatamente tras ganar XP")
	print("[OK] Prueba 5: Sincronización reactiva del HUD (ExpBar y PlayerFrame) con la progresión del jugador verificada.")

	# Limpieza
	target_node.queue_free()
	goblin.queue_free()
	dragon.queue_free()
	player.queue_free()
	hud.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE PROGRESIÓN, EXP Y NIVELES PASARON EXITOSAMENTE (5/5) ---\n")
	quit(0)
