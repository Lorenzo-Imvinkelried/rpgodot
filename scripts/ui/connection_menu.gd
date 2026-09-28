class_name ConnectionMenu
extends Control

## Responsabilidad: Gestión exclusiva de la interfaz gráfica de conexión (Inputs y Botones).
## No inicia sockets ni clientes; notifica intenciones mediante señales.

signal host_requested(port: int)
signal join_requested(ip: String, port: int)

@onready var ip_edit: LineEdit = %IPLineEdit
@onready var port_edit: LineEdit = %PortLineEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	if ip_edit and ip_edit.text.is_empty():
		ip_edit.text = str(GameConfig.get_network_value("network", "default_ip", "127.0.0.1"))
	if port_edit and port_edit.text.is_empty():
		port_edit.text = str(GameConfig.get_network_value("network", "default_port", 8910))

func set_buttons_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled

func show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	if is_error:
		status_label.modulate = Color(1.0, 0.45, 0.45)
	else:
		status_label.modulate = Color(0.65, 0.9, 0.75)

func _on_host_pressed() -> void:
	var port := port_edit.text.to_int()
	host_requested.emit(port)

func _on_join_pressed() -> void:
	var ip := ip_edit.text.strip_edges()
	var port := port_edit.text.to_int()
	join_requested.emit(ip, port)
