class_name DragDropManager
extends CanvasLayer

## Responsabilidad: Capa superior para renderizar el ítem en vuelo durante operaciones de Drag & Drop.
## Rastrea el cursor del ratón, dibuja el icono flotante, contador de stack y aura de fortificación.

static var instance: DragDropManager = null

var is_dragging: bool = false
var dragged_item: ItemData = null
var source_slot_index: int = -1
var source_type: String = "" # "inventory", "character", etc.
var is_split: bool = false

var _preview_control: Control = null
var _icon_label: Label = null
var _stack_label: Label = null
var _aura_rect: ColorRect = null
var _border_panel: Panel = null
var _aura_time: float = 0.0

func _enter_tree() -> void:
	instance = self
	layer = 120 # Por encima de todas las ventanas y HUD
	if _preview_control == null:
		_create_preview_node()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if _preview_control == null:
		_create_preview_node()

func _create_preview_node() -> void:
	_preview_control = Control.new()
	_preview_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_control.custom_minimum_size = Vector2(48, 48)
	_preview_control.size = Vector2(48, 48)
	_preview_control.hide()
	add_child(_preview_control)

	# Borde y Fondo
	_border_panel = Panel.new()
	_border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.88)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	_border_panel.add_theme_stylebox_override("panel", style)
	_preview_control.add_child(_border_panel)

	# Aura de Fortificación pulsante (Nivel >= +6)
	_aura_rect = ColorRect.new()
	_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aura_rect.color = Color(1.0, 0.8, 0.2, 0.25)
	_aura_rect.hide()
	_preview_control.add_child(_aura_rect)

	# Icono del ítem
	_icon_label = Label.new()
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 22)
	_preview_control.add_child(_icon_label)

	# Contador de Stack
	_stack_label = Label.new()
	_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_label.anchor_left = 1.0
	_stack_label.anchor_top = 1.0
	_stack_label.anchor_right = 1.0
	_stack_label.anchor_bottom = 1.0
	_stack_label.offset_left = -24.0
	_stack_label.offset_top = -18.0
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_stack_label.add_theme_font_size_override("font_size", 10)
	_preview_control.add_child(_stack_label)

func _process(delta: float) -> void:
	if not is_dragging:
		return

	# Seguir posición del cursor
	var mouse_pos := _preview_control.get_viewport().get_mouse_position()
	_preview_control.global_position = mouse_pos - Vector2(24, 24)

	# Pulsar aura mística si fortificación >= +6
	if _aura_rect and _aura_rect.visible:
		_aura_time += delta * 4.0
		var alpha := 0.25 + 0.15 * sin(_aura_time)
		_aura_rect.color.a = alpha

func _unhandled_input(event: InputEvent) -> void:
	# Cancelar con Escape
	if is_dragging and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()

## Inicia el arrastre de un ítem
func start_drag(item: ItemData, src_type: String, src_idx: int, split: bool = false) -> void:
	if item == null:
		return

	if _border_panel == null:
		_create_preview_node()

	is_dragging = true
	dragged_item = item
	source_type = src_type
	source_slot_index = src_idx
	is_split = split

	# Configurar visual
	if _icon_label:
		_icon_label.text = item.icon_symbol
	if _stack_label:
		_stack_label.visible = (item.stack_count > 1)
		_stack_label.text = str(item.stack_count)

	if _aura_rect:
		_aura_rect.visible = item.has_fortification_aura()

	if _border_panel:
		var style := _border_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = item.get_rarity_color()

	if _preview_control:
		_preview_control.show()
		var vp := _preview_control.get_viewport()
		if vp:
			var mouse_pos := vp.get_mouse_position()
			_preview_control.global_position = mouse_pos - Vector2(24, 24)

## Cancela el arrastre activo retornando los datos para restauración
func cancel_drag() -> Dictionary:
	if not is_dragging:
		return {}

	var res := {
		"item": dragged_item,
		"source_type": source_type,
		"source_slot_index": source_slot_index,
		"is_split": is_split
	}

	_reset_drag()
	return res

## Concluye con éxito el arrastre y entrega el ítem
func finish_drag() -> ItemData:
	if not is_dragging:
		return null
	var item := dragged_item
	_reset_drag()
	return item

func _reset_drag() -> void:
	is_dragging = false
	dragged_item = null
	source_type = ""
	source_slot_index = -1
	is_split = false
	if _preview_control:
		_preview_control.hide()
