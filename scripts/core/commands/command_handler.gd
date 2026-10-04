class_name CommandHandler
extends RefCounted

## Responsabilidad: Clase base abstracta para la definición y ejecución de comandos de consola/desarrollo.
## Cada comando concreto debe heredar de esta clase e implementar el método execute().

const CommandResultScript = preload("res://scripts/core/commands/command_result.gd")

var name: String = ""
var aliases: Array[String] = []
var description: String = ""
var usage: String = ""

func _init(p_name: String = "", p_aliases: Array[String] = [], p_desc: String = "", p_usage: String = "") -> void:
	name = p_name
	aliases = p_aliases
	description = p_desc
	usage = p_usage

## Ejecuta la lógica del comando sobre el contexto provisto (típicamente el nodo del Player o entidad local).
## Debe retornar una instancia de CommandResult indicando éxito o fracaso y el mensaje de feedback.
func execute(_context: Node, _args: Array[String]) -> RefCounted:
	return CommandResultScript.error("Comando no implementado.")
