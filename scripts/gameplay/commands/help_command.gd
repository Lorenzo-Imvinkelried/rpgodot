class_name HelpCommand
extends "res://scripts/core/commands/command_handler.gd"


## Responsabilidad: Implementación del comando '/ayuda' (o '/help', '/?').
## Muestra la lista de comandos disponibles, su sintaxis y las estadísticas modificables con /darme.

func _init() -> void:
	super._init(
		"ayuda",
		["help", "?"],
		"Muestra la lista de comandos disponibles y sintaxis de prueba.",
		"/ayuda"
	)

func execute(_context: Node, _args: Array[String]) -> CommandResultScript:
	var text := """[b]=== COMANDOS DE DESARROLLO Y TESTING ===[/b]
• [color=yellow]/darme <stat> <cantidad>[/color]: Suma (+) o resta (-) una estadística.
  [i]Ejemplos:[/i]
    /darme attack 100       (Suma 100 al poder de ataque)
    /darme attack -50       (Resta 50 al ataque)
    /darme as 0.5           (Aumenta velocidad de ataque en +0.5)
    /darme hp 2000          (Aumenta vida máxima y actual)
    /darme str 30           (Aumenta 30 de Fuerza)
    /darme crit 25          (Aumenta 25% de golpe crítico)
    /darme gold 100         (Añade 100 monedas de oro)
    /darme level 5          (Sube 5 niveles)
    /darme speed 3.0        (Aumenta velocidad de movimiento)

• [color=cyan]Estadísticas soportadas:[/color]
  [b]Atributos:[/b] str, agi, int, vit
  [b]Ofensiva:[/b] attack (atk), attack_speed (as), crit, crit_damage (cdmg), armor_pen
  [b]Defensiva:[/b] defense (def), hp, heal, mp, block, lifesteal
  [b]Utilidad:[/b] speed, accuracy, evasion
  [b]Progresión:[/b] level, exp, gold
• [color=yellow]/ayuda[/color]: Muestra esta lista de comandos."""

	return CommandResultScript.ok(text)
