class_name PlayerFrame
extends Control

## Responsabilidad: Marco del jugador en la esquina superior izquierda.
## Muestra retrato, nombre, nivel, barras de vida y maná en tiempo real,
## contador visual de combo TAP (1-2-3-Burst) y badges de estados alterados activos.

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var max_mana: float = 100.0
@export var current_mana: float = 100.0

@onready var portrait_rect: TextureRect = %PortraitRect
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var mana_bar: ProgressBar = %ManaBar
@onready var mana_label: Label = %ManaLabel
@onready var tap_block_1: ColorRect = %TapBlock1
@onready var tap_block_2: ColorRect = %TapBlock2
@onready var tap_block_3: ColorRect = %TapBlock3
@onready var status_icons_label: Label = %StatusIconsLabel

var _current_combo_hits: int = 0
var _combo_timeout: float = 0.0
const COMBO_RESET_DELAY: float = 3.0

var _bound_player: Node = null
var _bound_stats: CharacterStats = null
var _bound_target: CombatTarget = null
var _bound_status: StatusEffectController = null

# Colores de TAP Combo
const COLOR_TAP_EMPTY := Color(0.20, 0.22, 0.28, 0.85)
const COLOR_TAP_ACTIVE := Color(0.95, 0.75, 0.15, 1.0)
const COLOR_TAP_FULL := Color(1.0, 0.30, 0.20, 1.0)

func _ready() -> void:
	_update_tap_visuals()
	_refresh_bars()

func _process(delta: float) -> void:
	if _combo_timeout > 0.0:
		_combo_timeout -= delta
		if _combo_timeout <= 0.0:
			_combo_timeout = 0.0
			_current_combo_hits = 0
			_update_tap_visuals()

## Vincula el PlayerFrame al nodo del jugador local para escuchar sus señales en vivo.
func bind_player(player: Node) -> void:
	_bound_player = player
	if _bound_player == null:
		return

	_bound_target = _bound_player.get_node_or_null("CombatTarget") as CombatTarget
	if _bound_target:
		_bound_target.health_changed.connect(_on_health_changed)
		_bound_target.guard_changed.connect(_on_guard_changed)
		_bound_stats = _bound_target.get_stats()
		if _bound_stats:
			set_player_info(_bound_stats.character_name, _bound_stats.level)
			set_health(float(_bound_stats.current_hp), float(_bound_stats.max_hp))
			set_mana(float(_bound_stats.current_mp), float(_bound_stats.max_mp))

	var combat_ctrl := _bound_player.get_node_or_null("CombatController") as CombatController
	if combat_ctrl:
		combat_ctrl.attack_executed.connect(_on_attack_executed)

	_bound_status = _bound_player.get_node_or_null("StatusEffectController") as StatusEffectController
	if _bound_status:
		_bound_status.stun_applied.connect(_on_status_changed)
		_bound_status.stun_removed.connect(_on_status_changed)
		_bound_status.bleed_applied.connect(_on_status_changed)
		_bound_status.bleed_removed.connect(_on_status_changed)
		_bound_status.slow_applied.connect(_on_status_changed)
		_bound_status.slow_removed.connect(_on_status_changed)

	_refresh_status_badges()

func set_player_info(player_name: String, level: int) -> void:
	if name_label:
		name_label.text = player_name
	if level_label:
		level_label.text = "Lvl: %d" % level

func set_health(current: float, max_val: float) -> void:
	current_health = clampf(current, 0.0, max_val)
	max_health = maxf(1.0, max_val)
	_refresh_bars()

func set_mana(current: float, max_val: float) -> void:
	current_mana = clampf(current, 0.0, max_val)
	max_mana = maxf(1.0, max_val)
	_refresh_bars()

func _refresh_bars() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label:
		health_label.text = "%d / %d" % [int(ceil(current_health)), int(max_health)]

	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana
	if mana_label:
		mana_label.text = "%d / %d" % [int(ceil(current_mana)), int(max_mana)]

func _on_attack_executed(_target: Node, _dmg: float) -> void:
	_current_combo_hits += 1
	_combo_timeout = COMBO_RESET_DELAY
	if _current_combo_hits > 4:
		_current_combo_hits = 1
	_update_tap_visuals()

func _update_tap_visuals() -> void:
	if tap_block_1 == null or tap_block_2 == null or tap_block_3 == null:
		return

	# Reset
	tap_block_1.color = COLOR_TAP_EMPTY
	tap_block_2.color = COLOR_TAP_EMPTY
	tap_block_3.color = COLOR_TAP_EMPTY

	match _current_combo_hits:
		1:
			tap_block_1.color = COLOR_TAP_ACTIVE
		2:
			tap_block_1.color = COLOR_TAP_ACTIVE
			tap_block_2.color = COLOR_TAP_ACTIVE
		3:
			tap_block_1.color = COLOR_TAP_FULL
			tap_block_2.color = COLOR_TAP_FULL
			tap_block_3.color = COLOR_TAP_FULL
		4:
			# Descarga potenciada completada
			tap_block_1.color = COLOR_TAP_EMPTY
			tap_block_2.color = COLOR_TAP_EMPTY
			tap_block_3.color = COLOR_TAP_EMPTY
			_current_combo_hits = 0

func _refresh_status_badges() -> void:
	if status_icons_label == null:
		return
	var badges: Array[String] = []
	if _bound_status:
		if _bound_status.is_stunned():
			badges.append("💫")
		if _bound_status.is_bleeding():
			badges.append("🩸")
		if _bound_status.is_slowed():
			badges.append("❄")
	if _bound_target and _bound_target.is_guarding:
		badges.append("🛡")

	status_icons_label.text = " ".join(badges)

func _on_health_changed(current: float, max_val: float) -> void:
	set_health(current, max_val)
	if _bound_stats:
		set_mana(float(_bound_stats.current_mp), float(_bound_stats.max_mp))

func _on_guard_changed(_guarding: bool) -> void:
	_refresh_status_badges()

func _on_status_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	_refresh_status_badges()
