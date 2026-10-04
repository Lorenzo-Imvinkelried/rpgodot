class_name CommandResult
extends RefCounted

## Responsabilidad: Encapsula el resultado de la ejecución de un comando de desarrollo o consola.
## Proporciona un estado de éxito/error, mensaje descriptivo para la UI y datos opcionales.

var success: bool = true
var message: String = ""
var data: Dictionary = {}

func _init(p_success: bool = true, p_message: String = "", p_data: Dictionary = {}) -> void:
	success = p_success
	message = p_message
	data = p_data

static func ok(p_message: String = "", p_data: Dictionary = {}) -> RefCounted:
	var script = load("res://scripts/core/commands/command_result.gd") as GDScript
	return script.new(true, p_message, p_data)

static func error(p_message: String = "", p_data: Dictionary = {}) -> RefCounted:
	var script = load("res://scripts/core/commands/command_result.gd") as GDScript
	return script.new(false, p_message, p_data)
