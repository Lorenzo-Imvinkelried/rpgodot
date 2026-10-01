class_name Hotbar
extends Control

## Responsabilidad: Barra de acción de 12 slots en la base inferior.
## Gestiona representación de habilidades, etiquetas de atajos, máscaras de enfriamiento (cooldown)
## con segundos restantes y bloqueo visual ante aturdimiento (Stun) o muerte.

signal slot_activated(slot_index: int)

@onready var slots_container: HBoxContainer = %SlotsContainer
@onready var stun_overlay: Control = %StunOverlay

var _bound_player: Node = null
var _bound_target: CombatTarget = null
var _bound_status: StatusEffectController = null

# Cooldowns manuales por slot (index -> { "total": float, "left": float })
var _slot_cooldowns: Dictionary = {}

const TOTAL_SLOTS: int = 12

func _ready() -> void:
	if stun_overlay:
		stun_overlay.hide()
	_setup_default_slots()

func _process(delta: float) -> void:
	# 1. Actualizar cooldowns registrados
	for idx in _slot_cooldowns.keys():
		var cd_info: Dictionary = _slot_cooldowns[idx]
		cd_info["left"] -= delta
		if cd_info["left"] <= 0.0:
			_slot_cooldowns.erase(idx)
			_set_slot_cooldown_visual(idx, 0.0, 0.0)
		else:
			_set_slot_cooldown_visual(idx, cd_info["left"], cd_info["total"])

	# 2. Sincronizar cooldown del Dash del jugador (Slot 2)
	if is_instance_valid(_bound_player):
		var dash_cd_left: float = _bound_player.get("_dash_cooldown_timer") if "_dash_cooldown_timer" in _bound_player else 0.0
		var dash_cd_total: float = float(GameConfig.get_combat_value("defense_mechanics", "dash_cooldown", 1.0))
		if dash_cd_left > 0.0:
			_set_slot_cooldown_visual(1, dash_cd_left, dash_cd_total)
		elif not _slot_cooldowns.has(1):
			_set_slot_cooldown_visual(1, 0.0, 0.0)

		# 3. Sincronizar indicador de guardia activa (Slot 3)
		if _bound_target:
			var slot_3 := _get_slot_node(2)
			if slot_3:
				var active_indicator: Control = slot_3.get_node_or_null("ActiveIndicator")
				if active_indicator:
					active_indicator.visible = _bound_target.is_guarding

## Vincula la Hotbar al jugador local para reflejar cooldowns y estados en vivo.
func bind_player(player: Node) -> void:
	_bound_player = player
	if _bound_player == null:
		return

	_bound_target = _bound_player.get_node_or_null("CombatTarget") as CombatTarget
	_bound_status = _bound_player.get_node_or_null("StatusEffectController") as StatusEffectController

	if _bound_status:
		_bound_status.stun_applied.connect(_on_stun_applied)
		_bound_status.stun_removed.connect(_on_stun_removed)

## Activa un cooldown en un slot específico (0-11).
func trigger_cooldown(slot_index: int, duration: float) -> void:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS or duration <= 0.0:
		return
	_slot_cooldowns[slot_index] = {
		"total": duration,
		"left": duration
	}
	_set_slot_cooldown_visual(slot_index, duration, duration)

func _set_slot_cooldown_visual(slot_index: int, time_left: float, total_duration: float) -> void:
	var slot := _get_slot_node(slot_index)
	if slot == null:
		return

	var cd_mask: Control = slot.get_node_or_null("CooldownMask")
	var cd_label: Label = slot.get_node_or_null("CooldownLabel")

	if time_left <= 0.0 or total_duration <= 0.0:
		if cd_mask: cd_mask.visible = false
		if cd_label: cd_label.visible = false
		return

	if cd_mask:
		cd_mask.visible = true
		var ratio := clampf(time_left / total_duration, 0.0, 1.0)
		cd_mask.anchor_top = 1.0 - ratio

	if cd_label:
		cd_label.visible = true
		cd_label.text = "%.1fs" % time_left

func _get_slot_node(slot_index: int) -> Control:
	if slots_container == null:
		return null
	if slot_index >= 0 and slot_index < slots_container.get_child_count():
		return slots_container.get_child(slot_index) as Control
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var slot_to_activate: int = -1
		match event.keycode:
			KEY_1, KEY_KP_1:
				slot_to_activate = 0
			KEY_2, KEY_KP_2:
				slot_to_activate = 1
			KEY_3, KEY_KP_3:
				slot_to_activate = 2
			KEY_4, KEY_KP_4:
				slot_to_activate = 3
			KEY_5, KEY_KP_5:
				slot_to_activate = 4
			KEY_6, KEY_KP_6:
				slot_to_activate = 5
			KEY_7, KEY_KP_7:
				slot_to_activate = 6
			KEY_8, KEY_KP_8:
				slot_to_activate = 7
			KEY_9, KEY_KP_9:
				slot_to_activate = 8
			KEY_0, KEY_KP_0:
				slot_to_activate = 9
			KEY_MINUS, KEY_KP_SUBTRACT:
				slot_to_activate = 10
			KEY_EQUAL, KEY_KP_ADD:
				slot_to_activate = 11

		if slot_to_activate >= 0:
			slot_activated.emit(slot_to_activate)

func _setup_default_slots() -> void:
	# Iconos y atajos por defecto de las acciones principales
	var default_icons: Dictionary = {
		0: { "name": "Ataque Básico (1)", "icon": "⚔", "key": "1" },
		1: { "name": "Dash / Esquiva (Space)", "icon": "💨", "key": "Space" },
		2: { "name": "Guardia Activa (Shift)", "icon": "🛡", "key": "Shift" },
		3: { "name": "Relámpago (4)", "icon": "⚡", "key": "4" },
		4: { "name": "Bola de Fuego (5)", "icon": "🔥", "key": "5" },
		5: { "name": "Escarcha (6)", "icon": "❄", "key": "6" },
		6: { "name": "Rayo Solar (7)", "icon": "✨", "key": "7" },
		7: { "name": "Meteorito (8)", "icon": "☄", "key": "8" },
		8: { "name": "Torbellino (9)", "icon": "🌪", "key": "9" },
		9: { "name": "Tajo Sangriento (0)", "icon": "🩸", "key": "0" },
		10: { "name": "Poción de Salud (-)", "icon": "🧪", "key": "-" },
		11: { "name": "Poción de Maná (=)", "icon": "🍷", "key": "=" }
	}

	for i in range(TOTAL_SLOTS):
		var slot := _get_slot_node(i)
		if slot == null:
			continue
		var info: Dictionary = default_icons.get(i, { "name": "", "icon": "", "key": str(i + 1) })
		slot.tooltip_text = info.get("name", "")
		slot.mouse_filter = Control.MOUSE_FILTER_PASS

		if not slot.gui_input.is_connected(_on_slot_gui_input):
			slot.gui_input.connect(_on_slot_gui_input.bind(i))

		var icon_lbl: Label = slot.get_node_or_null("IconLabel")
		if icon_lbl:
			icon_lbl.text = info.get("icon", "")
		var key_lbl: Label = slot.get_node_or_null("KeyLabel")
		if key_lbl:
			key_lbl.text = info.get("key", str(i + 1))

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_activated.emit(slot_idx)

func _on_stun_applied(_dur: float) -> void:
	if stun_overlay:
		stun_overlay.show()

func _on_stun_removed() -> void:
	if stun_overlay:
		stun_overlay.hide()
