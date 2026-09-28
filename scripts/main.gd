class_name Main
extends Node3D

## Responsabilidad: Orquestador principal de la escena.
## Conecta la capa de red (NetworkManager) con la capa de presentación (UI) y el ciclo de vida de jugadores.

@onready var network_manager: NetworkManager = $NetworkManager
@onready var connection_menu: ConnectionMenu = $UI/ConnectionMenu
@onready var game_hud: GameHUD = $GameHUD
@onready var players_container: Node3D = $Players

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

func _ready() -> void:
	# Eventos de UI
	connection_menu.host_requested.connect(_on_host_requested)
	connection_menu.join_requested.connect(_on_join_requested)
	game_hud.disconnect_requested.connect(_on_disconnect_requested)

	# Eventos de Red
	network_manager.host_started.connect(_on_host_started)
	network_manager.client_connected.connect(_on_client_connected)
	network_manager.client_disconnected.connect(_on_client_disconnected)
	network_manager.connected_to_host.connect(_on_connected_to_host)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_closed.connect(_on_server_closed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if multiplayer.multiplayer_peer != null:
			_on_disconnect_requested()

func _on_host_requested(port: int) -> void:
	var error := network_manager.start_host(port)
	if error != OK:
		connection_menu.show_status("Error al abrir servidor: %s" % error_string(error), true)

func _on_join_requested(ip: String, port: int) -> void:
	connection_menu.show_status("Conectando a %s:%d..." % [ip, port])
	connection_menu.set_buttons_enabled(false)
	var error := network_manager.start_client(ip, port)
	if error != OK:
		connection_menu.show_status("Error al conectar: %s" % error_string(error), true)
		connection_menu.set_buttons_enabled(true)

func _on_disconnect_requested() -> void:
	network_manager.disconnect_session()
	_clear_all_players()
	_show_connection_menu("Desconectado. Listo para iniciar nueva partida.")

func _on_host_started() -> void:
	connection_menu.hide()
	game_hud.show()
	game_hud.update_status("Rol: Servidor (Host)\nID: 1 (Esperando Jugador 2...)")
	_spawn_player(1)

func _on_client_connected(id: int) -> void:
	if network_manager.is_host():
		game_hud.update_status("Rol: Servidor (Host)\n¡Jugador 2 conectado!")
		_spawn_player(id)

func _on_client_disconnected(id: int) -> void:
	if network_manager.is_host():
		game_hud.update_status("Rol: Servidor (Host)\nJugador %d desconectado." % id)
		var player_node := players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()

func _on_connected_to_host() -> void:
	connection_menu.hide()
	game_hud.show()
	game_hud.update_status("Rol: Cliente\nID local: %d (Conectado)" % network_manager.get_local_id())

func _on_connection_failed(message: String) -> void:
	_clear_all_players()
	_show_connection_menu(message, true)

func _on_server_closed() -> void:
	_clear_all_players()
	_show_connection_menu("El servidor cerró la partida.")

func _spawn_player(peer_id: int) -> void:
	var player_instance: CharacterBody3D = player_scene.instantiate()
	player_instance.name = str(peer_id)

	# Posición de spawn diferenciada cargada desde config/player_config.json
	var p1_pos := GameConfig.get_vector3(GameConfig.get_player_value("spawn", "player_1_position", [-3.0, 1.0, 0.0]), Vector3(-3.0, 1.0, 0.0))
	var p2_pos := GameConfig.get_vector3(GameConfig.get_player_value("spawn", "player_2_position", [3.0, 1.0, 0.0]), Vector3(3.0, 1.0, 0.0))

	if peer_id == 1:
		player_instance.position = p1_pos
	else:
		player_instance.position = p2_pos

	players_container.add_child(player_instance, true)

func _clear_all_players() -> void:
	for child in players_container.get_children():
		child.queue_free()

func _show_connection_menu(status_message: String, is_error: bool = false) -> void:
	game_hud.hide()
	connection_menu.show()
	connection_menu.set_buttons_enabled(true)
	connection_menu.show_status(status_message, is_error)
