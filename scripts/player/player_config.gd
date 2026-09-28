class_name PlayerConfig
extends Resource

## Responsabilidad: Parámetros de configuración física y de movimiento del jugador.
## Permite desacoplar los valores numéricos y editarlos visualmente desde el Inspector de Godot.

@export_group("Velocidades de Movimiento")
## Velocidad lineal de avance (en m/s)
@export_range(1.0, 20.0, 0.1) var forward_speed: float = 6.0

## Velocidad lineal de retroceso (en m/s)
@export_range(1.0, 20.0, 0.1) var backward_speed: float = 4.2

## Velocidad angular de rotación en su eje con teclas A/D (en rad/s)
@export_range(1.0, 15.0, 0.1) var turn_speed: float = 5.2

@export_group("Dinámica de Movimiento")
## Multiplicador de desaceleración al soltar las teclas de movimiento
@export_range(1.0, 30.0, 0.5) var deceleration_factor: float = 8.0

## Multiplicador de escala de gravedad sobre el personaje
@export_range(0.0, 5.0, 0.1) var gravity_multiplier: float = 1.0

## Aplica valores definidos en config/player_config.json si existen.
func apply_json_overrides() -> void:
	forward_speed = float(GameConfig.get_player_value("movement", "forward_speed", forward_speed))
	backward_speed = float(GameConfig.get_player_value("movement", "backward_speed", backward_speed))
	turn_speed = float(GameConfig.get_player_value("movement", "turn_speed", turn_speed))
	deceleration_factor = float(GameConfig.get_player_value("movement", "deceleration_factor", deceleration_factor))
	gravity_multiplier = float(GameConfig.get_player_value("movement", "gravity_multiplier", gravity_multiplier))
