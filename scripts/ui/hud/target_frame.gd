class_name TargetFrame
extends Control

## Responsabilidad: Marco del objetivo actual (enemigo o dummy) centrado en la parte superior.
## Muestra nombre, barras de vida y maná, indicador de jefe (Boss) y badges de estados alterados.
## Se oculta automáticamente si el objetivo muere o se aleja.

signal inspect_requested(target_node: Node)

@onready var panel_container: PanelContainer = %Panel
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var mana_bar: ProgressBar = %ManaBar
@onready var mana_label: Label = %ManaLabel
@onready var status_icons_label: Label = %StatusIconsLabel
@onready var boss_badge: Label = %BossBadge

var _current_target_node: Node = null
var _current_combat_target: CombatTarget = null
var _current_stats: CharacterStats = null
var _current_status_ctrl: StatusEffectController = null

var max_health: float = 100.0
var current_health: float = 100.0
var max_mana: float = 100.0
var current_mana: float = 100.0

const COLOR_BORDER_NORMAL := Color(0.24, 0.28, 0.38, 0.95)
const COLOR_BORDER_BOSS := Color(1.0, 0.78, 0.15, 1.0) # Dorado para jefes

func _ready() -> void:
	hide()

## Asigna y vincula un nuevo objetivo al marco. Si target es null, oculta el marco.
func set_target(target_node: Node) -> void:
	_disconnect_current()

	if not is_instance_valid(target_node):
		hide()
		return

	var ct := _find_combat_target(target_node)
	if ct == null:
		hide()
		return

	if ct.current_health <= 0.0 or (target_node is Node3D and not CombatController.is_target_alive(target_node as Node3D)):
		hide()
		return

	_current_target_node = target_node
	_current_combat_target = ct

	if not _current_combat_target.health_changed.is_connected(_on_target_health_changed):
		_current_combat_target.health_changed.connect(_on_target_health_changed)
	if not _current_combat_target.died.is_connected(_on_target_died):
		_current_combat_target.died.connect(_on_target_died)

	_current_stats = _current_combat_target.get_stats()
	_current_status_ctrl = _find_status_controller(_current_target_node)

	var t_name: String = _current_combat_target.target_name
	var t_lvl: int = _current_stats.level if _current_stats else 1
	var is_boss: bool = t_name.findn("boss") != -1 or t_name.findn("jefe") != -1

	name_label.text = t_name
	level_label.text = "Lvl: %d" % t_lvl

	if boss_badge:
		boss_badge.visible = is_boss

	# Estilo del marco dorado si es jefe
	var style = panel_container.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var dup_style = style.duplicate() as StyleBoxFlat
		dup_style.border_color = COLOR_BORDER_BOSS if is_boss else COLOR_BORDER_NORMAL
		panel_container.add_theme_stylebox_override("panel", dup_style)

	set_health(_current_combat_target.current_health, _current_combat_target.max_health)
	if _current_stats:
		set_mana(float(_current_stats.current_mp), float(_current_stats.max_mp))
	else:
		set_mana(0.0, 0.0)

	if _current_status_ctrl:
		if _current_status_ctrl.has_signal("berserker_applied") and not _current_status_ctrl.berserker_applied.is_connected(_refresh_status_badges):
			_current_status_ctrl.berserker_applied.connect(func(_d, _dmg, _spd): _refresh_status_badges())
		if _current_status_ctrl.has_signal("berserker_removed") and not _current_status_ctrl.berserker_removed.is_connected(_refresh_status_badges):
			_current_status_ctrl.berserker_removed.connect(_refresh_status_badges)

	_refresh_status_badges()
	show()

func clear_target() -> void:
	_clear()

func _disconnect_current() -> void:
	if is_instance_valid(_current_combat_target):
		if _current_combat_target.health_changed.is_connected(_on_target_health_changed):
			_current_combat_target.health_changed.disconnect(_on_target_health_changed)
		if _current_combat_target.died.is_connected(_on_target_died):
			_current_combat_target.died.disconnect(_on_target_died)
	_current_combat_target = null
	_current_target_node = null
	_current_stats = null
	_current_status_ctrl = null

func _clear() -> void:
	_disconnect_current()
	hide()

func set_health(current: float, max_val: float) -> void:
	current_health = clampf(current, 0.0, max_val)
	max_health = maxf(1.0, max_val)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label:
		health_label.text = "%d / %d" % [int(ceil(current_health)), int(max_health)]

func set_mana(current: float, max_val: float) -> void:
	current_mana = clampf(current, 0.0, max_val)
	max_mana = maxf(1.0, max_val)
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana
	if mana_label:
		mana_label.text = "%d / %d" % [int(ceil(current_mana)), int(max_mana)]

func _on_target_health_changed(current: float, max_val: float) -> void:
	if current <= 0.0:
		_clear()
		return
	set_health(current, max_val)
	if _current_combat_target:
		if _current_stats == null:
			_current_stats = _current_combat_target.get_stats()
		if _current_stats and level_label:
			level_label.text = "Lvl: %d" % _current_stats.level
		if name_label and not _current_combat_target.target_name.is_empty():
			name_label.text = _current_combat_target.target_name
	_refresh_status_badges()

func _on_target_died() -> void:
	# Ocultar automáticamente al morir
	_clear()

func _refresh_status_badges() -> void:
	if status_icons_label == null:
		return
	var badges: Array[String] = []
	if _current_status_ctrl:
		if _current_status_ctrl.is_stunned():
			badges.append("💫")
		if _current_status_ctrl.is_bleeding():
			badges.append("🩸")
		if _current_status_ctrl.is_slowed():
			badges.append("❄")
		if _current_status_ctrl.has_method("is_berserk") and _current_status_ctrl.is_berserk():
			badges.append("🪓")
	if _current_combat_target and _current_combat_target.is_guarding:
		badges.append("🛡")

	status_icons_label.text = " ".join(badges)

func _find_combat_target(node: Node) -> CombatTarget:
	if node is CombatTarget:
		return node
	if node.has_node("CombatTarget"):
		return node.get_node_or_null("CombatTarget") as CombatTarget
	for child in node.get_children():
		if child is CombatTarget:
			return child
	return null

func _find_status_controller(node: Node) -> StatusEffectController:
	if node is StatusEffectController:
		return node
	if node.has_node("StatusEffectController"):
		return node.get_node_or_null("StatusEffectController") as StatusEffectController
	for child in node.get_children():
		if child is StatusEffectController:
			return child
	return null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _current_target_node != null:
			inspect_requested.emit(_current_target_node)
			accept_event()

