class_name FloatingCombatLayer
extends CanvasLayer

## Responsabilidad: Capa de renderizado 2D en pantalla (Layer 2) para elementos flotantes de combate.
## Sitúa las barras de vida, nombres y números de daño flotantes por encima del post-procesado retro
## (Layer 1) y por debajo del HUD principal (Layer 10), garantizando que se rendericen en alta definición
## nítida (Full HD / 4K) sin verse afectados por la pixelación retro del mundo 3D.

static var instance: FloatingCombatLayer = null

@onready var overlay_container: Control = $OverlayContainer

func _enter_tree() -> void:
	layer = 2
	add_to_group("floating_combat_layer")
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	layer = 2
	_setup_container()

func _setup_container() -> void:
	if overlay_container == null:
		overlay_container = get_node_or_null("OverlayContainer") as Control
	if overlay_container == null:
		overlay_container = Control.new()
		overlay_container.name = "OverlayContainer"
		overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(overlay_container)
	else:
		overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)

## Agrega un control 2D al contenedor de elementos flotantes
func add_floating_element(element: Control) -> void:
	if overlay_container == null:
		_setup_container()
	if element != null and element.get_parent() != overlay_container:
		if element.get_parent() != null:
			element.reparent(overlay_container)
		else:
			overlay_container.add_child(element)

## Remueve un control 2D del contenedor de elementos flotantes
func remove_floating_element(element: Control) -> void:
	if overlay_container != null and element != null and element.get_parent() == overlay_container:
		overlay_container.remove_child(element)

## Obtiene la instancia activa de la capa o crea una contingencia en la raíz del árbol
static func get_or_create(tree: SceneTree) -> FloatingCombatLayer:
	if instance != null and is_instance_valid(instance):
		return instance

	if tree != null and tree.root != null:
		# Buscar si ya existe en el grupo
		var existing := tree.get_first_node_in_group("floating_combat_layer") as FloatingCombatLayer
		if existing != null:
			instance = existing
			return instance

		# Crear dinámicamente en root si no está presente en la escena
		var layer_inst := FloatingCombatLayer.new()
		layer_inst.name = "FloatingCombatLayer"
		layer_inst.layer = 2
		tree.root.add_child(layer_inst)
		instance = layer_inst
		return instance

	return null
