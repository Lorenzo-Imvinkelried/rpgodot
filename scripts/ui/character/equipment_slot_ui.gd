class_name EquipmentSlotUI
extends PanelContainer

## Responsabilidad: Casilla de equipamiento de la "muñeca" (Doll).
## Muestra el ícono del ítem equipado, aura mística si >= +6, borde de calidad,
## tooltip en hover, desequipamiento con clic derecho y recepción de Drag & Drop.

signal unequip_requested(slot: ItemData.EquipmentSlot)
signal item_dropped_on_equip_slot(from_type: String, from_index: int, target_slot: ItemData.EquipmentSlot, item: ItemData)
signal tooltip_requested(item: ItemData, mouse_pos: Vector2)
signal tooltip_hide_requested()

@export var equip_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.HEAD
@export var slot_label_text: String = "Casco"

@onready var icon_label: Label = %IconLabel
@onready var slot_title_label: Label = %SlotTitleLabel
@onready var aura_rect: ColorRect = %AuraRect

var equipped_item: ItemData = null

var _is_mouse_down: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _aura_time: float = 0.0

const DRAG_THRESHOLD: float = 5.0

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	set_item(equipped_item)

func _process(delta: float) -> void:
	if aura_rect and aura_rect.visible:
		_aura_time += delta * 4.0
		aura_rect.color.a = 0.22 + 0.14 * sin(_aura_time)

## Asigna o actualiza la pieza equipada en esta ranura
func set_item(item: ItemData) -> void:
	equipped_item = item

	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.12, 0.16, 0.90)
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		add_theme_stylebox_override("panel", style)

	if equipped_item == null:
		if icon_label: icon_label.text = ""
		if slot_title_label:
			slot_title_label.text = slot_label_text
			slot_title_label.show()
		if aura_rect: aura_rect.hide()
		style.border_color = Color(0.22, 0.25, 0.32, 0.75)
		return

	if icon_label:
		icon_label.text = equipped_item.icon_symbol
	if slot_title_label:
		slot_title_label.hide()

	style.border_color = equipped_item.get_rarity_color()

	if aura_rect:
		aura_rect.visible = equipped_item.has_fortification_aura()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# 1. Clic Derecho: Desequipar pieza a la mochila
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if equipped_item != null:
				unequip_requested.emit(equip_slot)
				tooltip_hide_requested.emit()
			accept_event()
			return

		# 2. Clic Izquierdo: Drag & Drop
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_down = true
				_drag_start_pos = event.position
			else:
				_is_mouse_down = false
				if DragDropManager.instance and DragDropManager.instance.is_dragging:
					var ddm := DragDropManager.instance
					var from_type := ddm.source_type
					var from_idx := ddm.source_slot_index
					var dropped_item := ddm.finish_drag()
					item_dropped_on_equip_slot.emit(from_type, from_idx, equip_slot, dropped_item)
					accept_event()

	elif event is InputEventMouseMotion and _is_mouse_down:
		if event.position.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
			_is_mouse_down = false
			if equipped_item != null and DragDropManager.instance and not DragDropManager.instance.is_dragging:
				tooltip_hide_requested.emit()
				DragDropManager.instance.start_drag(equipped_item, "character", equip_slot, false)
				accept_event()

func _on_mouse_entered() -> void:
	if equipped_item != null:
		tooltip_requested.emit(equipped_item, get_global_mouse_position())

func _on_mouse_exited() -> void:
	tooltip_hide_requested.emit()
