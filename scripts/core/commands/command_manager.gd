class_name CommandManager
extends RefCounted

## Responsabilidad: Registro central, parseo de texto y despacho de comandos de consola/desarrollo.
## Mantiene el historial de comandos ejecutados y gestiona el ciclo de vida de los CommandHandlers registrados.

const CommandResultScript = preload("res://scripts/core/commands/command_result.gd")
const CommandHandlerScript = preload("res://scripts/core/commands/command_handler.gd")

signal command_executed(command_name: String, result: RefCounted)

static var _instance: RefCounted = null

var _handlers: Dictionary = {} # String (nombre/alias en minúsculas) -> CommandHandler
var _command_list: Array = []
var _history: Array[String] = []
var _max_history: int = 50

static func get_instance() -> RefCounted:
	if _instance == null:
		var script := load("res://scripts/core/commands/command_manager.gd") as GDScript
		_instance = script.new()
		_instance._register_default_commands()
	return _instance

## Registra un nuevo controlador de comando y sus alias.
func register_command(handler: CommandHandlerScript) -> void:
	if handler == null or handler.name.is_empty():
		return
	var key := handler.name.to_lower()
	if not _command_list.has(handler):
		_command_list.append(handler)
	_handlers[key] = handler
	for alias in handler.aliases:
		_handlers[alias.to_lower()] = handler

## Remueve un comando por su nombre principal.
func unregister_command(command_name: String) -> void:
	var key := command_name.to_lower()
	if _handlers.has(key):
		var handler: CommandHandlerScript = _handlers[key]
		_command_list.erase(handler)
		_handlers.erase(key)
		for alias in handler.aliases:
			_handlers.erase(alias.to_lower())

## Parsea y ejecuta una línea de comando ingresada por el usuario.
## Retorna un CommandResult con el resultado y mensaje informativo.
func execute_command(context: Node, raw_input: String) -> CommandResultScript:
	var clean := raw_input.strip_edges()
	if clean.is_empty():
		return CommandResultScript.error("Comando vacío.")

	# Añadir al historial si difiere del último comando
	if _history.is_empty() or _history.back() != clean:
		_history.append(clean)
		if _history.size() > _max_history:
			_history.pop_front()

	# Quitar prefijo '/' si está presente
	var without_slash := clean
	if without_slash.begins_with("/"):
		without_slash = without_slash.substr(1).strip_edges()

	# Separar tokens por espacios
	var parts := without_slash.split(" ", false)
	if parts.is_empty():
		return CommandResultScript.error("Comando no reconocido.")

	var cmd_name := parts[0].to_lower()
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	if not _handlers.has(cmd_name):
		var err_msg := "Comando desconocido: '/%s'. Escribe '/ayuda' para ver comandos disponibles." % cmd_name
		var res := CommandResultScript.error(err_msg)
		command_executed.emit(cmd_name, res)
		return res

	var handler = _handlers[cmd_name]
	var result = handler.execute(context, args)
	command_executed.emit(handler.name, result)
	return result

## Retorna la lista única de comandos registrados.
func get_commands() -> Array:
	return _command_list

## Retorna el historial de comandos para navegación con flechas arriba/abajo.
func get_history() -> Array[String]:
	return _history

## Inicializa los comandos por defecto integrados en el sistema.
func _register_default_commands() -> void:
	var GiveStatScript = load("res://scripts/gameplay/commands/give_stat_command.gd")
	if GiveStatScript:
		register_command(GiveStatScript.new())

	var HelpScript = load("res://scripts/gameplay/commands/help_command.gd")
	if HelpScript:
		register_command(HelpScript.new())
