class_name CharacterPanel
extends PanelContainer

## Responsabilidad: Ventana de Hoja de Personaje y Equipamiento (Doll).
## Muestra en 2 columnas: desglose de estadísticas en tiempo real (Base, Ofensivas, Defensivas)
## y las 12 ranuras de equipamiento con reglas de 2 Manos, desequipamiento y modo Inspección.

signal visibility_changed_to(is_visible: bool)

@onready var title_bar: Control = %TitleBar
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var tooltip: ItemTooltip = %ItemTooltip

# Contenedor de estadísticas
@onready var stats_labels_container: VBoxContainer = %StatsLabelsContainer

# Contenedor de ranuras de equipamiento
@onready var equip_grid: GridContainer = %EquipGrid

var _bound_stats: CharacterStats = null
var _bound_equipment: EquipmentController = null
var _bound_inventory: InventoryController = null
var _bound_target: CombatTarget = null

var is_inspect_mode: bool = false

# Mapeo de slots
var _slot_ui_map: Dictionary = {}

# Arrastre de ventana
var _is_dragging_window: bool = false
var _drag_window_offset: Vector2 = Vector2.ZERO

const SLOT_DEFINITIONS: Array[Dictionary] = [
	{ "slot": ItemData.EquipmentSlot.HEAD, "label": "🪖 Casco" },
	{ "slot": ItemData.EquipmentSlot.CAPE, "label": "🧣 Capa" },
	{ "slot": ItemData.EquipmentSlot.CHEST, "label": "🥋 Pechera" },
	{ "slot": ItemData.EquipmentSlot.HANDS, "label": "🧤 Guantes" },
	{ "slot": ItemData.EquipmentSlot.MAIN_HAND, "label": "⚔ Arma 1" },
	{ "slot": ItemData.EquipmentSlot.OFF_HAND, "label": "🛡 Arma 2/Escudo" },
	{ "slot": ItemData.EquipmentSlot.LEGS, "label": "👖 Pantalón" },
	{ "slot": ItemData.EquipmentSlot.FEET, "label": "👢 Botas" },
	{ "slot": ItemData.EquipmentSlot.RING_1, "label": "💍 Anillo 1" },
	{ "slot": ItemData.EquipmentSlot.RING_2, "label": "💍 Anillo 2" },
	{ "slot": ItemData.EquipmentSlot.SUB_WEAPON_1, "label": "🏹 Sub-Arma 1" },
	{ "slot": ItemData.EquipmentSlot.SUB_WEAPON_2, "label": "🪄 Sub-Arma 2" }
]

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(hide_panel)
	if title_bar:
		title_bar.gui_input.connect(_on_title_bar_gui_input)

	_build_equipment_slots()
	hide()

func _build_equipment_slots() -> void:
	if equip_grid == null:
		return

	for child in equip_grid.get_children():
		child.queue_free()
	_slot_ui_map.clear()

	var slot_scene := preload("res://scenes/ui/character/equipment_slot_ui.tscn")
	for def in SLOT_DEFINITIONS:
		var slot_ui := slot_scene.instantiate() as EquipmentSlotUI
		var s_type: ItemData.EquipmentSlot = def["slot"]
		slot_ui.equip_slot = s_type
		slot_ui.slot_label_text = def["label"]
		slot_ui.unequip_requested.connect(_on_unequip_requested)
		slot_ui.item_dropped_on_equip_slot.connect(_on_item_dropped_on_equip_slot)
		slot_ui.tooltip_requested.connect(_on_tooltip_requested)
		slot_ui.tooltip_hide_requested.connect(_on_tooltip_hide_requested)
		equip_grid.add_child(slot_ui)
		_slot_ui_map[s_type] = slot_ui

## Vincula la hoja a las estadísticas y componentes del jugador local
func bind_character(stats: CharacterStats, equipment: EquipmentController, inventory: InventoryController, target: CombatTarget = null) -> void:
	_bound_stats = stats
	_bound_equipment = equipment
	_bound_inventory = inventory
	_bound_target = target
	is_inspect_mode = false

	if title_label:
		title_label.text = "👤 Personaje & Equipamiento"

	if _bound_equipment:
		_bound_equipment.equipment_changed.connect(_on_equipment_changed)

	_refresh_all()

## Modo Inspección: Vincula a una entidad ajena para ver su perfil y stats en modo sólo lectura
func inspect_target(target_node: Node) -> void:
	is_inspect_mode = true
	var ct := target_node.get_node_or_null("CombatTarget") as CombatTarget
	if ct == null:
		if target_node is CombatTarget:
			ct = target_node
		else:
			for child in target_node.get_children():
				if child is CombatTarget:
					ct = child
					break

	if ct:
		_bound_target = ct
		_bound_stats = ct.get_stats()
		_bound_equipment = target_node.get_node_or_null("EquipmentController") as EquipmentController
		_bound_inventory = null

		if title_label:
			var lvl := _bound_stats.level if _bound_stats else 1
			title_label.text = "🔍 Inspeccionando: %s (Lvl %d)" % [ct.target_name, lvl]

		_refresh_all()
		show_panel()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func show_panel() -> void:
	show()
	_refresh_all()
	visibility_changed_to.emit(true)

func hide_panel() -> void:
	hide()
	_on_tooltip_hide_requested()
	visibility_changed_to.emit(false)

func _refresh_all() -> void:
	_refresh_stats_display()
	_refresh_equipment_slots()

func _refresh_stats_display() -> void:
	if stats_labels_container == null:
		return

	for child in stats_labels_container.get_children():
		child.queue_free()

	if _bound_stats == null and _bound_target:
		_bound_stats = _bound_target.get_stats()

	if _bound_stats == null:
		return

	# Re-aplicar bonificaciones de equipo a las estadísticas
	if _bound_equipment and not is_inspect_mode:
		_bound_equipment.apply_equipment_stats_to(_bound_stats)

	_add_stat_header("ATRIBUTOS BASE")
	_add_stat_line("Fuerza (STR)", "%d (+%d)" % [_bound_stats.base_str, _bound_stats.bonus_str])
	_add_stat_line("Agilidad (AGI)", "%d (+%d)" % [_bound_stats.base_agi, _bound_stats.bonus_agi])
	_add_stat_line("Inteligencia (INT)", "%d (+%d)" % [_bound_stats.base_int, _bound_stats.bonus_int])
	_add_stat_line("Vitalidad (VIT)", "%d (+%d)" % [_bound_stats.base_vit, _bound_stats.bonus_vit])

	_add_stat_header("ESTADÍSTICAS VITALES")
	var hp_curr := _bound_target.current_health if _bound_target else float(_bound_stats.current_hp)
	var hp_max := _bound_target.max_health if _bound_target else float(_bound_stats.max_hp)
	_add_stat_line("Salud (HP)", "%d / %d" % [int(ceil(hp_curr)), int(hp_max)])
	_add_stat_line("Maná (MP)", "%d / %d" % [_bound_stats.current_mp, _bound_stats.max_mp])

	_add_stat_header("OFENSIVAS")
	_add_stat_line("Daño Físico", "%d" % _bound_stats.attack)
	_add_stat_line("Velocidad Ataque", "%.2f/s" % _bound_stats.attack_speed)
	_add_stat_line("Prob. Crítico", "%.1f%%" % _bound_stats.crit_chance)
	_add_stat_line("Daño Crítico", "%.1f%%" % _bound_stats.crit_damage)
	_add_stat_line("Penetración Arm.", "%d" % int(_bound_stats.armor_pen_flat))
	_add_stat_line("Robo de Vida", "%.1f%%" % _bound_stats.lifesteal_percent)
	_add_stat_line("Prob. Stun", "%.1f%%" % _bound_stats.stun_chance)
	_add_stat_line("Multi-Strike", "%.1f%%" % (_bound_stats.double_strike_chance + _bound_stats.triple_strike_chance))

	_add_stat_header("DEFENSIVAS")
	_add_stat_line("Defensa / Armadura", "%d" % _bound_stats.defense)
	_add_stat_line("Prob. Bloqueo", "%.1f%%" % _bound_stats.block_chance)
	_add_stat_line("Evasión", "%.1f" % _bound_stats.base_evasion)
	_add_stat_line("Tenacidad", "%.1f%%" % _bound_stats.tenacity_percent)
	_add_stat_line("Espinas (Thorns)", "%.1f%%" % _bound_stats.thorns_percent)

func _add_stat_header(title: String) -> void:
	var lbl := Label.new()
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25, 1.0))
	lbl.text = "—— " + title + " ——"
	stats_labels_container.add_child(lbl)

func _add_stat_line(stat_name: String, stat_val: String) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = MOUSE_FILTER_IGNORE

	var l_name := Label.new()
	l_name.mouse_filter = MOUSE_FILTER_IGNORE
	l_name.size_flags_horizontal = SIZE_EXPAND_FILL
	l_name.add_theme_font_size_override("font_size", 10)
	l_name.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	l_name.text = stat_name

	var l_val := Label.new()
	l_val.mouse_filter = MOUSE_FILTER_IGNORE
	l_val.add_theme_font_size_override("font_size", 10)
	l_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	l_val.text = stat_val

	h.add_child(l_name)
	h.add_child(l_val)
	stats_labels_container.add_child(h)

func _refresh_equipment_slots() -> void:
	for slot_type in _slot_ui_map.keys():
		var slot_ui: EquipmentSlotUI = _slot_ui_map[slot_type]
		var item: ItemData = null
		if _bound_equipment:
			item = _bound_equipment.get_equipped_item(slot_type)
		slot_ui.set_item(item)

func _on_equipment_changed(_slot: ItemData.EquipmentSlot, _item: ItemData) -> void:
	_refresh_all()

func _on_unequip_requested(slot: ItemData.EquipmentSlot) -> void:
	if is_inspect_mode or _bound_equipment == null:
		return
	_bound_equipment.unequip_item(slot, _bound_inventory)
	_refresh_all()

func _on_item_dropped_on_equip_slot(from_type: String, from_idx: int, target_slot: ItemData.EquipmentSlot, item: ItemData) -> void:
	if is_inspect_mode or _bound_equipment == null or item == null:
		return

	if from_type == "inventory":
		# Remover temporalmente de la mochila para equipar
		var equipped_ok := _bound_equipment.equip_item(item, target_slot, _bound_inventory)
		if equipped_ok and _bound_inventory:
			_bound_inventory.remove_item_at(from_idx, item.stack_count)
	elif from_type == "character":
		# Mover entre ranuras compatibles de la muñeca
		_bound_equipment.equip_item(item, target_slot, _bound_inventory)

	_refresh_all()

func _on_tooltip_requested(item: ItemData, mouse_pos: Vector2) -> void:
	if tooltip:
		tooltip.display_item(item, mouse_pos)

func _on_tooltip_hide_requested() -> void:
	if tooltip:
		tooltip.hide()

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
