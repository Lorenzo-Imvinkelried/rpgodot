@tool
extends SceneTree

## Responsabilidad: Validación automatizada de:
## 1. Salud de los Training Dummies configurada a 2 millones de HP (2,000,000).
## 2. Sistema modular de comandos (/darme, /ayuda, CommandManager, GiveStatCommand).
## 3. Suma y resta de estadísticas (+/-) y recálculo determinista en tiempo real.
## 4. Historial e integración con el HUD y ChatCommandBar.

const PlayerScene = preload("res://scenes/player/player.tscn")
const DummyScene = preload("res://scenes/combat/training_dummy.tscn")
const GameHudScene = preload("res://scenes/ui/game_hud.tscn")
const CommandManagerScript = preload("res://scripts/core/commands/command_manager.gd")
const ChatCommandBarScript = preload("res://scripts/ui/hud/chat_command_bar.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Dummies 2M HP y Sistema Modular de Comandos (/darme) ---")
	_run_tests()

func _run_tests() -> void:
	await process_frame

	# -------------------------------------------------------------
	# PARTE 1: VERIFICACIÓN DE DUMMY CON 2 MILLONES DE HP
	# -------------------------------------------------------------
	print("\n[TEST 1] Verificando salud del Training Dummy (2,000,000 HP)...")
	var dummy = DummyScene.instantiate()
	root.add_child(dummy)
	await process_frame
	await process_frame

	var dummy_ct: CombatTarget = dummy.get_node("CombatTarget")
	assert(dummy_ct != null, "Dummy debe tener CombatTarget")
	print("  Dummy Max Health: ", dummy_ct.max_health)
	print("  Dummy Current Health: ", dummy_ct.current_health)

	assert(is_equal_approx(dummy_ct.max_health, 2000000.0), "La vida máxima del Dummy DEBE ser 2,000,000 HP")
	assert(is_equal_approx(dummy_ct.current_health, 2000000.0), "La vida actual del Dummy DEBE ser 2,000,000 HP")

	var dummy_stats := dummy_ct.get_stats()
	if dummy_stats:
		assert(dummy_stats.max_hp == 2000000, "CharacterStats.max_hp del Dummy DEBE ser 2,000,000")

	# Simular daño de 50,000 y verificar salud restante
	dummy_ct.take_hit(50000.0, Vector3.ZERO, null)
	print("  Dummy tras 50,000 daño: ", dummy_ct.current_health, "/", dummy_ct.max_health)
	assert(is_equal_approx(dummy_ct.current_health, 1950000.0), "Dummy debe tener 1,950,000 HP tras recibir 50,000 de daño")

	dummy.queue_free()
	print("  [OK] Training Dummy con 2 Millones de HP verificado con éxito.")

	# -------------------------------------------------------------
	# PARTE 2: INICIALIZACIÓN DEL JUGADOR Y HUD
	# -------------------------------------------------------------
	print("\n[TEST 2] Verificando CommandManager y comandos por defecto...")
	var player = PlayerScene.instantiate()
	player.position = Vector3.ZERO
	root.add_child(player)

	var hud = GameHudScene.instantiate()
	root.add_child(hud)
	hud.bind_player(player)

	await process_frame
	await process_frame

	var cmd_mgr = CommandManagerScript.get_instance()
	assert(cmd_mgr != null, "CommandManager singleton debe existir")

	var commands = cmd_mgr.get_commands()
	assert(commands.size() >= 2, "Debe tener registrados al menos /darme y /ayuda")

	var player_ct: CombatTarget = player.get_node("CombatTarget")
	var stats: CharacterStats = player_ct.get_stats()
	assert(stats != null, "El jugador debe tener CharacterStats")

	# -------------------------------------------------------------
	# PARTE 3: COMANDO /darme (SUMAR Y RESTAR ATRIBUTOS Y ESTADÍSTICAS)
	# -------------------------------------------------------------
	print("\n[TEST 3] Verificando comando /darme con suma y resta (+/-)...")

	# 3.1 Poder de Ataque
	var initial_atk := stats.attack
	var res_atk_add = cmd_mgr.execute_command(player, "/darme attack 100")
	assert(res_atk_add.success, "Comando /darme attack 100 debe ser exitoso")
	print("  Resultado /darme attack 100: ", res_atk_add.message)
	assert(stats.attack == initial_atk + 100, "Ataque debe incrementarse en 100")

	var res_atk_sub = cmd_mgr.execute_command(player, "/darme attack -40")
	assert(res_atk_sub.success, "Comando /darme attack -40 debe ser exitoso")
	print("  Resultado /darme attack -40: ", res_atk_sub.message)
	assert(stats.attack == initial_atk + 60, "Ataque debe decrementar en 40 (neto +60)")

	# 3.2 Velocidad de Ataque
	var initial_as := stats.attack_speed
	var res_as = cmd_mgr.execute_command(player, "/darme as 0.5")
	assert(res_as.success, "Comando /darme as 0.5 debe ser exitoso")
	print("  Resultado /darme as 0.5: ", res_as.message)
	assert(is_equal_approx(stats.attack_speed, initial_as + 0.5), "Velocidad de ataque debe incrementarse en 0.5")

	# 3.3 Vida Máxima (HP)
	var initial_max_hp := stats.max_hp
	var res_hp = cmd_mgr.execute_command(player, "/darme hp 1500")
	assert(res_hp.success, "Comando /darme hp 1500 debe ser exitoso")
	print("  Resultado /darme hp 1500: ", res_hp.message)
	assert(stats.max_hp == initial_max_hp + 1500, "Vida máxima debe incrementarse en 1500")
	assert(player_ct.max_health == float(stats.max_hp), "CombatTarget.max_health debe sincronizarse")

	var res_hp_sub = cmd_mgr.execute_command(player, "/darme hp -500")
	assert(res_hp_sub.success, "Comando /darme hp -500 debe ser exitoso")
	print("  Resultado /darme hp -500: ", res_hp_sub.message)
	assert(stats.max_hp == initial_max_hp + 1000, "Vida máxima debe quedar en +1000")

	# 3.4 Atributo Fuerza (STR) y recálculo determinista de Ataque
	var current_atk_before_str := stats.attack
	var res_str = cmd_mgr.execute_command(player, "/darme str 20")
	assert(res_str.success, "Comando /darme str 20 debe ser exitoso")
	print("  Resultado /darme str 20: ", res_str.message)
	assert(stats.attack > current_atk_before_str, "Incrementar STR debe recalcular y aumentar el ataque derivado")

	# 3.5 Defensa
	var initial_def := stats.defense
	var res_def = cmd_mgr.execute_command(player, "/darme def 80")
	assert(res_def.success, "Comando /darme def 80 debe ser exitoso")
	assert(stats.defense == initial_def + 80, "Defensa debe incrementarse en 80")

	# 3.6 Golpe Crítico
	var initial_crit := stats.crit_chance
	var res_crit = cmd_mgr.execute_command(player, "/darme crit 25.0")
	assert(res_crit.success, "Comando /darme crit 25.0 debe ser exitoso")
	assert(is_equal_approx(stats.crit_chance, initial_crit + 25.0), "Crit chance debe incrementarse en 25%")

	# 3.7 Oro (Gold)
	var inv_ctrl: InventoryController = player.get_node("InventoryController")
	var initial_bronze := inv_ctrl.bronze_currency
	var res_gold = cmd_mgr.execute_command(player, "/darme gold 50")
	assert(res_gold.success, "Comando /darme gold 50 debe ser exitoso")
	print("  Resultado /darme gold 50: ", res_gold.message)
	assert(inv_ctrl.bronze_currency == initial_bronze + (50 * 10000), "Oro debe aumentar en 50 monedas de oro (500,000 bronce)")

	# 3.8 Nivel (Level)
	var prog_ctrl: ProgressionController = player.get_node("ProgressionController")
	var initial_lvl := prog_ctrl.current_level
	var res_lvl = cmd_mgr.execute_command(player, "/darme level 3")
	assert(res_lvl.success, "Comando /darme level 3 debe ser exitoso")
	print("  Resultado /darme level 3: ", res_lvl.message)
	assert(prog_ctrl.current_level == initial_lvl + 3, "Nivel debe incrementarse en 3")

	# 3.9 Alias alternativos (/give, /stat)
	var res_alias = cmd_mgr.execute_command(player, "/give attack 20")
	assert(res_alias.success, "Alias /give debe funcionar igual que /darme")

	# -------------------------------------------------------------
	# PARTE 4: COMANDO /ayuda Y MANEJO DE ERRORES
	# -------------------------------------------------------------
	print("\n[TEST 4] Verificando /ayuda y manejo de errores sintácticos...")
	var res_help = cmd_mgr.execute_command(player, "/ayuda")
	assert(res_help.success, "/ayuda debe ser exitoso")
	assert(res_help.message.find("/darme") != -1, "La ayuda debe mencionar /darme")

	var res_err_stat = cmd_mgr.execute_command(player, "/darme stat_inexistente 999")
	assert(not res_err_stat.success, "Stat desconocido debe fallar limpiamente con mensaje explicativo")
	print("  Error controlado stat desconocido: ", res_err_stat.message)

	var res_err_nan = cmd_mgr.execute_command(player, "/darme attack no_es_numero")
	assert(not res_err_nan.success, "Cantidad no numérica debe fallar limpiamente")
	print("  Error controlado valor no numérico: ", res_err_nan.message)

	var res_err_args = cmd_mgr.execute_command(player, "/darme")
	assert(not res_err_args.success, "Falta de argumentos debe retornar instrucciones de uso")
	print("  Error controlado falta de argumentos: ", res_err_args.message)

	# -------------------------------------------------------------
	# PARTE 5: COMPONENTE UI ChatCommandBar
	# -------------------------------------------------------------
	print("\n[TEST 5] Verificando ChatCommandBar en el HUD...")
	var chat_bar = hud.chat_command_bar
	assert(chat_bar != null, "ChatCommandBar debe estar integrado en GameHUD")

	# Abrir y simular envío de comando
	chat_bar.open_command_bar("/darme move_speed 2.5")
	assert(chat_bar.chat_window.visible == true, "Ventana de chat debe abrirse")
	assert(chat_bar.line_edit.text == "/darme move_speed 2.5", "Texto debe cargarse")

	var speed_before := stats.move_speed
	chat_bar._on_text_submitted("/darme move_speed 2.5")
	assert(is_equal_approx(stats.move_speed, speed_before + 2.5), "Velocidad de movimiento debe haberse incrementado")
	assert(chat_bar.chat_window.visible == true, "La ventana de chat DEBE permanecer abierta para permitir lectura continua")
	assert(chat_bar.log_rich_text.text.find("Velocidad de Movimiento") != -1, "El log persistente debe contener la confirmación del comando")

	# Cerrar explícitamente con Escape o close_command_bar
	chat_bar.close_command_bar()
	assert(chat_bar.chat_window.visible == false, "Cerrar la consola debe ocultar la ventana")

	print("\n>>> TODAS LAS PRUEBAS DE DUMMIES 2M HP Y COMANDOS PASARON CON ÉXITO <<<")
	quit(0)
