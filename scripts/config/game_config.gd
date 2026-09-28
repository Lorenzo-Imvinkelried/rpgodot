class_name GameConfig
extends RefCounted

## Responsabilidad: Carga, parseo, caché y acceso centralizado a los archivos de configuración JSON del proyecto con valores de contingencia (fallback).

const PATH_COMBAT := "res://config/combat_config.json"
const PATH_PLAYER := "res://config/player_config.json"
const PATH_NETWORK := "res://config/network_config.json"
const PATH_UI := "res://config/ui_config.json"

static var _cached_configs: Dictionary = {}

## Carga un archivo JSON desde el sistema de archivos y almacena en caché su contenido parseado.
static func load_json(file_path: String) -> Dictionary:
	if _cached_configs.has(file_path):
		return _cached_configs[file_path]

	if not FileAccess.file_exists(file_path):
		push_warning("GameConfig: Archivo '%s' no encontrado. Se usarán valores predeterminados." % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("GameConfig: Error al abrir archivo '%s'." % file_path)
		return {}

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("GameConfig: Formato JSON inválido en '%s'." % file_path)
		return {}

	_cached_configs[file_path] = parsed
	return parsed

## Fuerza la recarga de todas las configuraciones JSON en memoria.
static func reload() -> void:
	_cached_configs.clear()

## Acceso seguro a configuración de combate (combat_config.json)
static func get_combat_value(category: String, key: String, default_val: Variant) -> Variant:
	var cfg := load_json(PATH_COMBAT)
	if cfg.has(category) and cfg[category] is Dictionary and cfg[category].has(key):
		return cfg[category][key]
	return default_val

## Acceso seguro a configuración de jugador, físicas y cámara (player_config.json)
static func get_player_value(category: String, key: String, default_val: Variant) -> Variant:
	var cfg := load_json(PATH_PLAYER)
	if cfg.has(category) and cfg[category] is Dictionary and cfg[category].has(key):
		return cfg[category][key]
	return default_val

## Acceso seguro a configuración de red (network_config.json)
static func get_network_value(category: String, key: String, default_val: Variant) -> Variant:
	var cfg := load_json(PATH_NETWORK)
	if cfg.has(category) and cfg[category] is Dictionary and cfg[category].has(key):
		return cfg[category][key]
	return default_val

## Acceso seguro a configuración de UI y efectos (ui_config.json)
static func get_ui_value(category: String, key: String, default_val: Variant) -> Variant:
	var cfg := load_json(PATH_UI)
	if cfg.has(category) and cfg[category] is Dictionary and cfg[category].has(key):
		return cfg[category][key]
	return default_val

## Helper para convertir string hexadecimal a Color con valor por defecto
static func get_color(hex_code: String, default_color: Color = Color.WHITE) -> Color:
	if hex_code.is_empty():
		return default_color
	return Color.from_string(hex_code, default_color)

## Helper para convertir array de floats [x, y, z] a Vector3 con valor por defecto
static func get_vector3(arr: Variant, default_vec: Vector3 = Vector3.ZERO) -> Vector3:
	if arr is Array and arr.size() >= 3:
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return default_vec
