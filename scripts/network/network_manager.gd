class_name NetworkManager
extends Node

## Responsabilidad: Gestión exclusiva del ciclo de vida de la conexión de red (ENet).
## No contiene lógica visual ni de interfaz gráfica.

signal host_started
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connected_to_host
signal connection_failed(error_message: String)
signal server_closed

const DEFAULT_PORT: int = 8910
const DEFAULT_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 2

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_host(port: int = DEFAULT_PORT) -> Error:
	var target_port := port if port > 0 else DEFAULT_PORT
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(target_port, MAX_PLAYERS)
	
	if error != OK:
		return error

	multiplayer.multiplayer_peer = peer
	host_started.emit()
	return OK

func start_client(ip: String = DEFAULT_IP, port: int = DEFAULT_PORT) -> Error:
	var target_ip := ip.strip_edges()
	if target_ip == "":
		target_ip = DEFAULT_IP
	var target_port := port if port > 0 else DEFAULT_PORT

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target_ip, target_port)
	if error != OK:
		return error

	multiplayer.multiplayer_peer = peer
	return OK

func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func is_host() -> bool:
	return multiplayer.is_server()

func get_local_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	client_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	client_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connected_to_host.emit()

func _on_connection_failed() -> void:
	disconnect_session()
	connection_failed.emit("No fue posible establecer conexión con el servidor.")

func _on_server_disconnected() -> void:
	disconnect_session()
	server_closed.emit()
