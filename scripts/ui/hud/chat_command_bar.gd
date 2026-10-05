class_name ChatCommandBar
extends Control

## Responsabilidad: Interfaz de usuario de consola/chat permanente para ingreso y visualización de comandos.
## Permite abrir la consola con Enter o '/', mantiene el historial visible sin desaparecer automáticamente,
## soporta navegación con flechas (Arriba/Abajo) y se cierra únicamente de forma explícita (Escape o botón '✕').

signal command_submitted(raw_command: String)

const CommandManagerScript = preload("res://scripts/core/commands/command_manager.gd")
const CommandResultScript = preload("res://scripts/core/commands/command_result.gd")

@onready var chat_window: PanelContainer = %ChatWindow
@onready var line_edit: LineEdit = %CommandLineEdit
@onready var log_rich_text: RichTextLabel = %LogRichText
@onready var close_button: Button = %CloseButton

var _bound_player: Node = null
var _history_index: int = -1
var _messages: Array[String] = []
var _max_log_messages: int = 150

func _ready() -> void:
	visible = true
	if chat_window:
		chat_window.visible = false

	if line_edit:
		line_edit.focus_mode = Control.FOCUS_ALL
		line_edit.text_submitted.connect(_on_text_submitted)
		line_edit.gui_input.connect(_on_line_edit_gui_input)

	if close_button:
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(close_command_bar)

	if chat_window:
		var input_panel: Control = chat_window.get_node_or_null("MarginContainer/VBoxContainer/InputPanel")
		if input_panel:
			input_panel.gui_input.connect(_on_input_panel_gui_input)

	_messages.append("[color=#66aaff]Consola de comandos lista. Escribe [b]/ayuda[/b] para ver comandos o [b]/darme <stat> <cantidad>[/b].[/color]")
	_refresh_log_display()

## Vincula la barra de comandos al jugador local para ejecutar comandos en su contexto.
func bind_player(player_node: Node) -> void:
	_bound_player = player_node

func _input(event: InputEvent) -> void:
	if not (chat_window and chat_window.is_visible_in_tree()):
		return

	# Si se hace click con cualquier botón del ratón fuera de la ventana de chat, deseleccionar el campo de texto
	if event is InputEventMouseButton and event.pressed:
		if line_edit and line_edit.has_focus():
			var mb_event := event as InputEventMouseButton
			var click_pos: Vector2 = mb_event.global_position
			var rect: Rect2 = chat_window.get_global_rect()
			if not rect.has_point(click_pos):
				line_edit.release_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if chat_window and chat_window.visible:
			if event.keycode == KEY_ESCAPE:
				if line_edit and line_edit.has_focus():
					line_edit.release_focus()
				else:
					close_command_bar()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if line_edit and not line_edit.has_focus():
					line_edit.grab_focus()
					line_edit.caret_column = line_edit.text.length()
					get_viewport().set_input_as_handled()
			elif event.keycode == KEY_SLASH:
				if line_edit and not line_edit.has_focus():
					line_edit.text = "/"
					line_edit.grab_focus()
					line_edit.caret_column = 1
					get_viewport().set_input_as_handled()
		else:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				open_command_bar("", false)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_SLASH:
				open_command_bar("/", true)
				get_viewport().set_input_as_handled()

## Abre la ventana de consola/chat.
## Solo otorga foco de inmediato si se pasa initial_text o si grab_focus_on_open es true.
## De lo contrario, permite que el chat esté abierto mientras el jugador camina y juega con normalidad.
func open_command_bar(initial_text: String = "", grab_focus_on_open: bool = false) -> void:
	if chat_window:
		chat_window.visible = true
	_history_index = -1
	if line_edit:
		line_edit.text = initial_text
		if grab_focus_on_open or initial_text != "":
			line_edit.grab_focus()
			line_edit.caret_column = line_edit.text.length()
		else:
			line_edit.release_focus()

## Cierra la ventana de comandos y libera el foco de entrada hacia el juego.
func close_command_bar() -> void:
	if chat_window:
		chat_window.visible = false
	_history_index = -1
	if line_edit:
		line_edit.text = ""
		line_edit.release_focus()

func _on_input_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if line_edit:
			line_edit.grab_focus()

func _on_text_submitted(new_text: String) -> void:
	var clean := new_text.strip_edges()
	if clean.is_empty():
		if line_edit:
			line_edit.text = ""
			line_edit.release_focus()
		return

	command_submitted.emit(clean)

	# Registrar el comando escrito por el usuario en el historial visible
	add_log_message("[color=#88ccff]> %s[/color]" % clean)

	var mgr = CommandManagerScript.get_instance()
	var result = mgr.execute_command(_bound_player, clean)

	# Registrar la respuesta en el log con color según éxito o error
	var color_tag := "[color=#88ff88]" if result.success else "[color=#ff6666]"
	add_log_message("%s%s[/color]" % [color_tag, result.message])

	# Limpiar campo de texto y liberar foco para permitir jugar y caminar de inmediato con el chat abierto
	if line_edit:
		line_edit.text = ""
		line_edit.release_focus()

## Agrega un mensaje formateado al historial persistente del chat.
func add_log_message(bbcode_text: String) -> void:
	_messages.append(bbcode_text)
	if _messages.size() > _max_log_messages:
		_messages.pop_front()
	_refresh_log_display()

func _refresh_log_display() -> void:
	if log_rich_text:
		log_rich_text.text = "\n".join(_messages)
		# Forzar desplazamiento hacia el final para leer los mensajes más recientes
		log_rich_text.scroll_to_line(log_rich_text.get_line_count() - 1)

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	var mgr = CommandManagerScript.get_instance()
	var history = mgr.get_history()
	if history.is_empty():
		return

	# Flecha Arriba: Comando anterior en el historial
	if event.keycode == KEY_UP:
		if _history_index == -1:
			_history_index = history.size() - 1
		else:
			_history_index = maxi(0, _history_index - 1)
		line_edit.text = history[_history_index]
		line_edit.caret_column = line_edit.text.length()
		get_viewport().set_input_as_handled()

	# Flecha Abajo: Comando siguiente en el historial
	elif event.keycode == KEY_DOWN:
		if _history_index != -1:
			_history_index += 1
			if _history_index >= history.size():
				_history_index = -1
				line_edit.text = ""
			else:
				line_edit.text = history[_history_index]
			line_edit.caret_column = line_edit.text.length()
			get_viewport().set_input_as_handled()
