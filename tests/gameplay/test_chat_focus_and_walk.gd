@tool
extends SceneTree

func _init() -> void:
	print("\n--- INICIANDO TEST COMPLETO: Chat Focus y Movimiento mientras está abierto ---")
	_run_tests()

func _run_tests() -> void:
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	var p_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: Player = p_scene.instantiate()
	root.add_child(player)
	hud.bind_player(player)
	await process_frame

	var chat_bar = hud.chat_command_bar
	var chat_win: Control = chat_bar.chat_window
	var line_edit: LineEdit = chat_bar.line_edit
	var ap: AnimationPlayer = player.visuals.anim_player

	# --------------------------------------------------------------------------
	# PRUEBA 1: Abrir chat sin foco permite caminar y jugar normalmente con chat abierto
	# --------------------------------------------------------------------------
	chat_bar.open_command_bar("", false)
	assert(chat_win.visible == true, "La ventana de chat debe estar abierta")
	assert(line_edit.has_focus() == false, "Al abrir el chat sin initial_text NO debe capturar foco automáticamente")

	# Simular movimiento del jugador con el chat abierto en pantalla
	Input.action_press("move_forward")
	player._physics_process(0.016)
	player._process(0.016)

	assert(player.is_moving == true, "El jugador DEBE poder caminar normalmente aun con el chat abierto")
	assert(ap.current_animation == "walk", "La animación debe ser 'walk'")
	print("[OK] Prueba 1: Chat abierto sin foco permite caminar normalmente (is_moving=true, anim='walk').")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Al hacer click / focus en el chat, captura el input de texto y bloquea movimiento
	# --------------------------------------------------------------------------
	line_edit.grab_focus()
	assert(line_edit.has_focus() == true, "line_edit debe tener el foco")

	player._physics_process(0.016)
	player._process(0.016)
	assert(player.is_moving == false, "El movimiento DEBE bloquearse mientras se escribe activamente en el chat")
	print("[OK] Prueba 2: Focus activo en el chat bloquea movimiento para escribir comandos.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Al hacer click afuera del chat, se deselecciona automáticamente
	# --------------------------------------------------------------------------
	# Simular un click con el ratón en la pantalla del juego fuera del chat window
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	# La ventana de chat está en la esquina inferior izquierda; un click en (800, 300) cae afuera
	mouse_event.position = Vector2(800, 300)
	mouse_event.global_position = Vector2(800, 300)

	chat_bar._input(mouse_event)

	assert(line_edit.has_focus() == false, "Click afuera DEBE deseleccionar y liberar el foco de line_edit")
	assert(chat_win.visible == true, "La ventana de chat DEBE seguir abierta tras el click afuera")

	# Verificar que el jugador puede volver a caminar de inmediato tras deseleccionar con click afuera
	player._physics_process(0.016)
	player._process(0.016)
	assert(player.is_moving == true, "El jugador DEBE poder reanudar la marcha tras click afuera")
	print("[OK] Prueba 3: Click afuera deselecciona line_edit y permite caminar con chat abierto.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Enviar un comando libera el foco automáticamente para jugar de inmediato
	# --------------------------------------------------------------------------
	line_edit.grab_focus()
	assert(line_edit.has_focus() == true, "line_edit enfocado antes de enviar")

	chat_bar._on_text_submitted("/ayuda")
	assert(line_edit.has_focus() == false, "Al enviar un comando, el foco DEBE liberarse para jugar de inmediato")
	assert(line_edit.text == "", "El texto de entrada debe limpiarse tras enviar")
	assert(chat_win.visible == true, "La ventana de chat debe permanecer visible para leer el log")

	player._physics_process(0.016)
	player._process(0.016)
	assert(player.is_moving == true, "El jugador puede caminar inmediatamente tras enviar comando")
	print("[OK] Prueba 4: Enviar comando libera foco y mantiene el log visible mientras se juega.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Enviar texto vacío libera el foco sin ejecutar comando
	# --------------------------------------------------------------------------
	line_edit.grab_focus()
	chat_bar._on_text_submitted("")
	assert(line_edit.has_focus() == false, "Enter con texto vacío debe liberar el foco")
	print("[OK] Prueba 5: Enter con texto vacío libera foco limpiamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 6: Abrir con '/' otorga foco para escribir comandos directamente
	# --------------------------------------------------------------------------
	chat_bar.open_command_bar("/", true)
	assert(chat_win.visible == true, "Chat abierto con '/'")
	assert(line_edit.text == "/", "Debe inicializar con '/'")
	assert(line_edit.has_focus() == true, "Debe tener foco al abrir explícitamente con '/'")
	print("[OK] Prueba 6: Abrir con '/' otorga foco directo para comandos.")

	Input.action_release("move_forward")
	hud.queue_free()
	player.queue_free()
	print("\n>>> TODOS LOS TESTS DE CHAT FOCUS Y MOVIMIENTO PASARON EXITOSAMENTE <<<\n")
	quit(0)
