class_name InventorySlotUI
extends PanelContainer

## Responsabilidad: Representación visual e interactiva de una casilla de inventario.
## Gestiona borde de calidad, aura mística pulsante (+6 a +15), contador de stack,
## inicio de Drag & Drop con umbral de 5px (y división con Shift) y atajo de clic derecho.

signal slot_right_clicked(slot_index: int, item: ItemData)
signal tooltip_requested(item: ItemData, global_pos: Vector2)
signal tooltip_hide_requested()
signal item_dropped_on_slot(from_type: String, from_index: int, to_index: int, split_item: ItemData)

@export var slot_index: int = 0

@onready var aura_rect: ColorRect = %AuraRect
@onready var icon_label: Label = %IconLabel
@onready var stack_label: Label = %StackLabel

var current_item: ItemData = null

var _is_mouse_down: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _aura_time: float = 0.0

const DRAG_THRESHOLD: float = 5.0 # Mínimo 5 píxeles para iniciar arrastre

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	set_item(current_item)

func _process(delta: float) -> void:
	if aura_rect and aura_rect.visible:
		_aura_time += delta * 4.0
		aura_rect.color.a = 0.22 + 0.14 * sin(_aura_time)

## Asigna o actualiza el ítem de la casilla
func set_item(item: ItemData) -> void:
	current_item = item

	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.12, 0.16, 0.90)
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		add_theme_stylebox_override("panel", style)

	if current_item == null:
		if icon_label: icon_label.text = ""
		if stack_label: stack_label.hide()
		if aura_rect: aura_rect.hide()
		style.border_color = Color(0.22, 0.25, 0.32, 0.8)
		return

	# Icono y Texto
	if icon_label:
		icon_label.text = current_item.icon_symbol

	# Contador de Unidades (Stack)
	if stack_label:
		if current_item.stack_count > 1:
			stack_label.text = str(current_item.stack_count)
			stack_label.show()
		else:
			stack_label.hide()

	# Borde de Calidad (Rareza)
	style.border_color = current_item.get_rarity_color()

	# Aura de Fortificación (+6 o superior)
	if aura_rect:
		aura_rect.visible = current_item.has_fortification_aura()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# 1. Clic Derecho: Acción Rápida (Consumir o Equipar)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if current_item != null:
				slot_right_clicked.emit(slot_index, current_item)
			accept_event()
			return

		# 2. Clic Izquierdo: Drag & Drop
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_down = true
				_drag_start_pos = event.position
			else:
				# Al soltar el clic izquierdo
				_is_mouse_down = false
				if DragDropManager.instance and DragDropManager.instance.is_dragging:
					# Depositar ítem arrastrado en esta casilla
					var ddm := DragDropManager.instance
					var from_type := ddm.source_type
					var from_idx := ddm.source_slot_index
					var dropped_item := ddm.finish_drag()
					item_dropped_on_slot.emit(from_type, from_idx, slot_index, dropped_item)
					accept_event()

	elif event is InputEventMouseMotion and _is_mouse_down:
		# Verificar umbral de arrastre de 5 píxeles
		if event.position.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
			_is_mouse_down = false
			if current_item != null and DragDropManager.instance and not DragDropManager.instance.is_dragging:
				tooltip_hide_requested.emit()
				var is_shift := Input.is_key_pressed(KEY_SHIFT)
				var drag_item := current_item
				if is_shift and current_item.stack_count > 1:
					# Split de pila
					var half := current_item.stack_count / 2
					current_item.stack_count -= half
					set_item(current_item)
					var split_copy := current_item.clone()
					split_copy.stack_count = half
					drag_item = split_copy
					DragDropManager.instance.start_drag(drag_item, "inventory", slot_index, true)
				else:
					DragDropManager.instance.start_drag(drag_item, "inventory", slot_index, false)
				accept_event()

func _on_mouse_entered() -> void:
	if current_item != null:
		tooltip_requested.emit(current_item, get_global_mouse_position())

func _on_mouse_exited() -> void:
	tooltip_hide_requested.emit()
