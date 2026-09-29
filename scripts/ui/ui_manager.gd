class_name UIManager
extends Node

## Responsabilidad: Coordinador central de la interfaz de usuario.
## Gestiona la detección de oclusión del ratón (Mouse Occlusion) para evitar clics accidentales
## en el mundo 3D y despacha señales globales de apertura/cierre de paneles (Mochila, Personaje).

signal inventory_toggle_requested
signal character_sheet_toggle_requested

static var instance: UIManager = null

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Evalúa si el cursor del ratón se encuentra actualmente posado sobre un control interactivo de la UI.
## Si retorna true, la interacción con el mundo 3D (movimiento, ataques) debe bloquearse.
static func is_mouse_over_ui(tree: SceneTree) -> bool:
	if tree == null or tree.root == null:
		return false
	var hovered := tree.root.gui_get_hovered_control()
	if hovered == null:
		return false
	# Ignorar si el control tiene mouse_filter IGNORE o es la raíz del HUD transparente
	if hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	# Si es un contenedor de pantalla completa transparente, verificar si tiene hijos activos
	if hovered.name == "GameHUD" or hovered.name == "MainHUD" or hovered.name == "UI":
		return false
	return true

## Emite solicitud de alternar visibilidad de la mochila/inventario.
func request_toggle_inventory() -> void:
	inventory_toggle_requested.emit()

## Emite solicitud de alternar visibilidad del panel de personaje y equipamiento.
func request_toggle_character_sheet() -> void:
	character_sheet_toggle_requested.emit()
