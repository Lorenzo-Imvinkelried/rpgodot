class_name HealthBar3D
extends Node3D

## Responsabilidad: Barra de vida y estado sobre la cabeza de entidades atacables (jugadores, muñecos, enemigos).
## Muestra nombre, barra de vida y texto de puntos de salud de manera aislada por entidad.

const COLOR_HEALTH_HIGH := Color(0.18, 0.82, 0.42, 1.0)
const COLOR_HEALTH_MID := Color(0.96, 0.65, 0.15, 1.0)
const COLOR_HEALTH_LOW := Color(0.92, 0.26, 0.26, 1.0)

@export var height_offset: float = 2.15
@export var auto_bind_combat_target: bool = true
@export var combat_target: CombatTarget = null
@export var auto_hide_when_full: bool = false
@export var use_dynamic_health_color: bool = true
@export var max_visible_distance: float = 60.0

@onready var sub_viewport: SubViewport = $SubViewport
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var name_label: Label = $SubViewport/UIContainer/NameLabel
@onready var health_bar: ProgressBar = $SubViewport/UIContainer/BarContainer/HealthBar
@onready var value_label: Label = $SubViewport/UIContainer/BarContainer/ValueLabel

var _ui_container: Control = null
var _is_floating_2d: bool = false
var _current_health: float = 100.0
var _max_health: float = 100.0
var _hp_tween: Tween = null
var _fill_style: StyleBoxFlat = null
var _base_entity_name: String = ""
var _entity_name_color: Color = Color.WHITE
var _status_controller: StatusEffectController = null

func _exit_tree() -> void:
	if _ui_container != null and is_instance_valid(_ui_container):
		_ui_container.queue_free()
		_ui_container = null

func _ready() -> void:
	height_offset = float(GameConfig.get_ui_value("health_bar", "height_offset", height_offset))
	auto_hide_when_full = bool(GameConfig.get_ui_value("health_bar", "auto_hide_when_full", auto_hide_when_full))
	use_dynamic_health_color = bool(GameConfig.get_ui_value("health_bar", "use_dynamic_health_color", use_dynamic_health_color))

	if position.y == 0.0:
		height_offset = float(GameConfig.get_ui_value("health_bar", "height_offset", height_offset))
		position.y = height_offset

	_setup_floating_ui()

	# Clonar el StyleBox del relleno para que cada barra tenga su propia instancia única
	# y no comparta el color con otros personajes o muñecos
	if health_bar:
		var orig_style := health_bar.get_theme_stylebox("fill")
		if orig_style is StyleBoxFlat:
			_fill_style = orig_style.duplicate() as StyleBoxFlat
		else:
			_fill_style = StyleBoxFlat.new()
			_fill_style.corner_radius_top_left = 2
			_fill_style.corner_radius_top_right = 2
			_fill_style.corner_radius_bottom_right = 2
			_fill_style.corner_radius_bottom_left = 2
		health_bar.add_theme_stylebox_override("fill", _fill_style)

	if auto_bind_combat_target and combat_target == null:
		combat_target = _find_combat_target()

	_status_controller = _find_status_controller()
	if _status_controller:
		_status_controller.stun_applied.connect(_on_status_changed)
		_status_controller.stun_removed.connect(_on_status_changed)
		_status_controller.bleed_applied.connect(_on_status_changed)
		_status_controller.bleed_removed.connect(_on_status_changed)
		_status_controller.slow_applied.connect(_on_status_changed)
		_status_controller.slow_removed.connect(_on_status_changed)

	if combat_target:
		combat_target.health_changed.connect(_on_health_changed)
		combat_target.guard_changed.connect(_on_guard_changed)
		combat_target.combat_state_changed.connect(_on_combat_state_changed)
		combat_target.died.connect(_on_combat_target_died)
		if not combat_target.target_name.is_empty() and _base_entity_name.is_empty():
			set_entity_name(combat_target.target_name)
		set_health(combat_target.current_health, combat_target.max_health, false)
	else:
		set_health(_current_health, _max_health, false)

## Configura el nombre a mostrar sobre la barra y su color distintivo.
func set_entity_name(entity_name: String, text_color: Color = Color.WHITE) -> void:
	_base_entity_name = entity_name
	_entity_name_color = text_color
	_refresh_name_display()

## Actualiza la visualización del nombre incorporando badges de estados alterados activos.
func _refresh_name_display() -> void:
	if name_label == null:
		return
	var badges: Array[String] = []
	if _status_controller:
		if _status_controller.is_stunned():
			badges.append("💫")
		if _status_controller.is_bleeding():
			badges.append("🩸")
		if _status_controller.is_slowed():
			badges.append("❄")
	if combat_target and combat_target.is_guarding:
		badges.append("🛡")

	if badges.is_empty():
		name_label.text = _base_entity_name
	else:
		name_label.text = "%s  [%s]" % [_base_entity_name, " ".join(badges)]
	name_label.add_theme_color_override("font_color", _entity_name_color)

func _on_guard_changed(_guarding: bool) -> void:
	_refresh_name_display()

func _on_status_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	_refresh_name_display()

## Permite fijar un color estático para la barra si se desactiva el color dinámico.
func set_bar_color(color: Color) -> void:
	use_dynamic_health_color = false
	if _fill_style:
		_fill_style.bg_color = color

## Actualiza el estado de la barra de salud directamente de forma individual.
func set_health(current: float, max_val: float, animate: bool = true) -> void:
	_current_health = clampf(current, 0.0, max_val)
	_max_health = maxf(1.0, max_val)

	if health_bar == null:
		return

	health_bar.max_value = _max_health

	if value_label:
		value_label.text = "%d / %d" % [int(ceil(_current_health)), int(_max_health)]

	# Ajuste dinámico de color según porcentaje de vida de ESTA entidad en su StyleBox exclusivo
	if use_dynamic_health_color and _fill_style:
		var ratio := _current_health / _max_health
		var low_ratio := float(GameConfig.get_ui_value("health_bar", "low_health_ratio", 0.25))
		var mid_ratio := float(GameConfig.get_ui_value("health_bar", "mid_health_ratio", 0.50))
		var colors_dict := GameConfig.get_ui_value("health_bar", "colors", {}) as Dictionary

		var col_high := GameConfig.get_color(str(colors_dict.get("high", "#2ed16b")), COLOR_HEALTH_HIGH)
		var col_mid := GameConfig.get_color(str(colors_dict.get("mid", "#f5a626")), COLOR_HEALTH_MID)
		var col_low := GameConfig.get_color(str(colors_dict.get("low", "#eb4242")), COLOR_HEALTH_LOW)

		var target_fill_color := col_high
		if ratio <= low_ratio:
			target_fill_color = col_low
		elif ratio <= mid_ratio:
			target_fill_color = col_mid

		_fill_style.bg_color = target_fill_color

	if not animate:
		health_bar.value = _current_health
		_update_auto_hide()
		return

	# Actualización con interpolación rápida y directa
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	var tween_dur := float(GameConfig.get_ui_value("health_bar", "tween_duration", 0.08))
	_hp_tween.tween_property(health_bar, "value", _current_health, tween_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_update_auto_hide()

func _setup_floating_ui() -> void:
	_ui_container = get_node_or_null("SubViewport/UIContainer") as Control
	if _ui_container == null:
		return

	# Asegurar que ningún control intercepte clics de ratón en el mundo 3D
	_set_mouse_filter_recursive(_ui_container)

	# Obtener o instanciar la capa FloatingCombatLayer en Layer 2
	var layer := FloatingCombatLayer.get_or_create(get_tree())
	if layer != null:
		layer.add_floating_element(_ui_container)
		_is_floating_2d = true
		if sprite_3d:
			sprite_3d.visible = false
		if sub_viewport:
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		# Fallback para pruebas sin SceneTree o entornos mínimos
		if sprite_3d and sub_viewport:
			sprite_3d.texture = sub_viewport.get_texture()

func _process(_delta: float) -> void:
	if not _is_floating_2d or _ui_container == null or not is_instance_valid(_ui_container):
		return

	if not is_visible_in_tree():
		_ui_container.visible = false
		return

	if combat_target != null and combat_target.current_health <= 0.0:
		_ui_container.visible = false
		return

func set_visible_ui(p_visible: bool) -> void:
	if _ui_container != null and is_instance_valid(_ui_container):
		_ui_container.visible = p_visible
	if sprite_3d != null and is_instance_valid(sprite_3d):
		sprite_3d.visible = p_visible

func _on_combat_target_died() -> void:
	set_visible_ui(false)

	var vp := get_viewport()
	if vp == null:
		_ui_container.visible = false
		return

	var cam := vp.get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		_ui_container.visible = false
		return

	var world_pos := global_position
	if cam.is_position_behind(world_pos):
		_ui_container.visible = false
		return

	var dist := cam.global_position.distance_to(world_pos)
	if dist > max_visible_distance:
		_ui_container.visible = false
		return

	var screen_pos := cam.unproject_position(world_pos)
	_ui_container.visible = true
	_ui_container.position = screen_pos - (_ui_container.size * 0.5)

	# Escala sutil con la distancia para mantener máxima legibilidad tipo MMORPG
	var scale_factor := clampf(1.0 - (dist - 8.0) * 0.012, 0.75, 1.05)
	_ui_container.scale = Vector2(scale_factor, scale_factor)
	_ui_container.pivot_offset = _ui_container.size * 0.5

func _update_auto_hide() -> void:
	if not auto_hide_when_full:
		return
	var is_in_comb := (combat_target != null and combat_target.is_in_combat)
	var is_full := (_current_health >= _max_health) and not is_in_comb
	var target_alpha := 0.0 if is_full else 1.0
	var tween := create_tween()
	if _ui_container != null and is_instance_valid(_ui_container):
		tween.tween_property(_ui_container, "modulate:a", target_alpha, 0.2)
	elif sprite_3d != null:
		tween.tween_property(sprite_3d, "modulate:a", target_alpha, 0.2)

func _on_combat_state_changed(_in_combat: bool) -> void:
	_update_auto_hide()

static func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)

func _on_health_changed(current: float, max_val: float) -> void:
	set_health(current, max_val, true)

func _find_combat_target() -> CombatTarget:
	var curr: Node = get_parent()
	while curr != null and not (curr is Viewport):
		var target := curr.get_node_or_null("CombatTarget") as CombatTarget
		if target:
			return target
		for child in curr.get_children():
			if child is CombatTarget:
				return child
		curr = curr.get_parent()
	return null

func _find_status_controller() -> StatusEffectController:
	var curr: Node = get_parent()
	while curr != null and not (curr is Viewport):
		var ctrl := curr.get_node_or_null("StatusEffectController") as StatusEffectController
		if ctrl:
			return ctrl
		for child in curr.get_children():
			if child is StatusEffectController:
				return child
		curr = curr.get_parent()
	return null

