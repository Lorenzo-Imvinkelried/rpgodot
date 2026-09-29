class_name InventoryPanel
extends PanelContainer

## Responsabilidad: Ventana interactiva y desplazable de la Mochila/Inventario.
## Integra grilla 5x4 de slots, barra de título arrastrable, botón de cerrar [X],
## desglose monetario (Oro, Plata, Bronce) e interoperabilidad con DragDropManager y Tooltips.

signal visibility_changed_to(is_visible: bool)
signal item_equip_requested(item: ItemData, slot_index: int)

@onready var title_bar: Control = %TitleBar
@onready var close_button: Button = %CloseButton
@onready var slots_grid: GridContainer = %SlotsGrid
@onready var gold_label: Label = %GoldLabel
@onready var silver_label: Label = %SilverLabel
@onready var bronze_label: Label = %BronzeLabel
@onready var tooltip: ItemTooltip = %ItemTooltip

const SLOT_UI_SCENE = preload("res://scenes/ui/inventory/inventory_slot_ui.tscn")

var _bound_inventory: InventoryController = null
var _bound_combat_target: CombatTarget = null

# Arrastre de la ventana
var _is_dragging_window: bool = false
var _drag_window_offset: Vector2 = Vector2.ZERO

var _slot_ui_nodes: Array[InventorySlotUI] = []

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(hide_panel)
	if title_bar:
		title_bar.gui_input.connect(_on_title_bar_gui_input)

	_build_slot_grid()
	hide()

func _build_slot_grid() -> void:
	if slots_grid == null:
		return

	# Limpiar slots existentes
	for child in slots_grid.get_children():
		child.queue_free()
	_slot_ui_nodes.clear()

	# Construir 20 slots (5x4)
	for i in range(20):
		var slot_ui := SLOT_UI_SCENE.instantiate() as InventorySlotUI
		slot_ui.slot_index = i
		slot_ui.slot_right_clicked.connect(_on_slot_right_clicked)
		slot_ui.tooltip_requested.connect(_on_tooltip_requested)
		slot_ui.tooltip_hide_requested.connect(_on_tooltip_hide_requested)
		slot_ui.item_dropped_on_slot.connect(_on_item_dropped_on_slot)
		slots_grid.add_child(slot_ui)
		_slot_ui_nodes.append(slot_ui)

## Vincula la ventana al controlador de inventario del jugador
func bind_inventory(inv: InventoryController, combat_target: CombatTarget = null) -> void:
	_bound_inventory = inv
	_bound_combat_target = combat_target

	if _bound_inventory:
		_bound_inventory.item_changed.connect(_on_inventory_item_changed)
		_bound_inventory.gold_changed.connect(_on_gold_changed)
		_refresh_all_slots()
		_update_currency_display()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func show_panel() -> void:
	show()
	_refresh_all_slots()
	_update_currency_display()
	visibility_changed_to.emit(true)

func hide_panel() -> void:
	hide()
	_on_tooltip_hide_requested()
	visibility_changed_to.emit(false)

func _refresh_all_slots() -> void:
	if _bound_inventory == null:
		return
	for i in range(_slot_ui_nodes.size()):
		var item := _bound_inventory.get_item(i)
		_slot_ui_nodes[i].set_item(item)

func _update_currency_display() -> void:
	if _bound_inventory == null:
		return
	var b := _bound_inventory.get_currency_breakdown()
	if gold_label: gold_label.text = "%d" % b.get("gold", 0)
	if silver_label: silver_label.text = "%d" % b.get("silver", 0)
	if bronze_label: bronze_label.text = "%d" % b.get("bronze", 0)

func _on_inventory_item_changed(slot_idx: int, item: ItemData) -> void:
	if slot_idx >= 0 and slot_idx < _slot_ui_nodes.size():
		_slot_ui_nodes[slot_idx].set_item(item)

func _on_gold_changed(_total: int) -> void:
	_update_currency_display()

func _on_slot_right_clicked(slot_idx: int, item: ItemData) -> void:
	if item == null or _bound_inventory == null:
		return

	# Si es consumible, usarlo directamente
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		_bound_inventory.use_consumable_at(slot_idx, _bound_combat_target)
		_on_tooltip_hide_requested()
	# Si es equipo, emitir solicitud de equipar
	elif item.item_type == ItemData.ItemType.WEAPON or item.item_type == ItemData.ItemType.ARMOR:
		item_equip_requested.emit(item, slot_idx)

func _on_item_dropped_on_slot(from_type: String, from_idx: int, to_idx: int, dropped_item: ItemData) -> void:
	if _bound_inventory == null or dropped_item == null:
		return

	if from_type == "inventory":
		if from_idx != to_idx:
			_bound_inventory.swap_slots(from_idx, to_idx)
		else:
			# Soltado en la misma casilla
			_bound_inventory.set_item(to_idx, dropped_item)

func _on_tooltip_requested(item: ItemData, global_mouse_pos: Vector2) -> void:
	if tooltip:
		tooltip.display_item(item, global_mouse_pos)

func _on_tooltip_hide_requested() -> void:
	if tooltip:
		tooltip.hide()

# --- Arrastre de la Ventana mediante Barra de Título ---
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging_window = true
				_drag_window_offset = get_global_mouse_position() - global_position
			else:
				_is_dragging_window = false
	elif event is InputEventMouseMotion and _is_dragging_window:
		global_position = get_global_mouse_position() - _drag_window_offset
