class_name GameHUD
extends Control

## Responsabilidad: Visualización del estado de juego en pantalla y botón de desconexión.
## Emite señales sin acoplarse directamente a la lógica de red o nodos de jugadores.

signal disconnect_requested

@onready var status_label: Label = %HUDStatus
@onready var disconnect_button: Button = %DisconnectButton

func _ready() -> void:
	disconnect_button.pressed.connect(_on_disconnect_pressed)

func update_status(text: String) -> void:
	status_label.text = text

func _on_disconnect_pressed() -> void:
	disconnect_requested.emit()
