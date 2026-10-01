class_name Player
extends CharacterBody3D

## Responsabilidad: Física de movimiento y sincronización de red del personaje.
## Control tipo RPG: W avanza, S retrocede sin girar la cara, A/D rota en su eje.
## Cámara libre con click derecho sin alterar la dirección de marcha y con cursor siempre visible.

const DEFAULT_CONFIG = preload("res://resources/player/default_player_config.tres")
const GroundMarkerScript = preload("res://scripts/player/ground_marker.gd")
const ProgressionControllerScript = preload("res://scripts/gameplay/progression/progression_controller.gd")

@export var config: PlayerConfig = DEFAULT_CONFIG
@export var is_moving: bool = false

@onready var visuals: PlayerVisuals = $Visuals
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var combat_controller: CombatController = get_node_or_null("CombatController")
@onready var combat_target: CombatTarget = get_node_or_null("CombatTarget")
@onready var inventory_controller: InventoryController = get_node_or_null("InventoryController")
@onready var equipment_controller: EquipmentController = get_node_or_null("EquipmentController")
@onready var skill_controller: SkillController = get_node_or_null("SkillController")
@onready var progression_controller: ProgressionController = get_node_or_null("ProgressionController")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_forward_pressed: bool = false
var _prev_global_pos: Vector3 = Vector3.ZERO

# Temporizadores y variables de Dash y Guardia Activa
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _was_space_pressed: bool = false

# Variables y componentes de Click-to-Move (desplazamiento guiado por ratón) y targeting
var _ground_marker: Node3D = null
var _target_indicator: Node3D = null
var _has_click_move: bool = false
var _click_move_target: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	var peer_id := name.to_int()
	if peer_id <= 0:
		peer_id = 1
	set_multiplayer_authority(peer_id, true)
	$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG.duplicate()
	if config.has_method("apply_json_overrides"):
		config.apply_json_overrides()

	var peer_id := name.to_int()
	var is_local := is_multiplayer_authority()
	visuals.configure_visuals(peer_id, is_local)
	camera_pivot.setup(is_local)
	_prev_global_pos = global_position
	visuals.update_animation(is_moving, 0.0)

	if is_local:
		var marker_scene := preload("res://scenes/player/ground_marker.tscn")
		_ground_marker = marker_scene.instantiate() as Node3D
		add_child(_ground_marker)

		var target_ind_scene := preload("res://scenes/combat/target_indicator_3d.tscn")
		_target_indicator = target_ind_scene.instantiate() as Node3D
		add_child(_target_indicator)

		if combat_controller:
			combat_controller.target_acquired.connect(func(target_node: Node3D):
				if _target_indicator and _target_indicator.has_method("set_target"):
					_target_indicator.set_target(target_node)
			)
			combat_controller.target_lost.connect(func():
				if _target_indicator and _target_indicator.has_method("clear_target"):
					_target_indicator.clear_target()
			)

	if combat_target:
		combat_target.died.connect(_on_player_died)

	if inventory_controller == null:
		inventory_controller = InventoryController.new()
		inventory_controller.name = "InventoryController"
		add_child(inventory_controller)
		_setup_starter_inventory()

	if equipment_controller == null:
		equipment_controller = EquipmentController.new()
		equipment_controller.name = "EquipmentController"
		add_child(equipment_controller)
		_setup_starter_equipment()

	if skill_controller == null:
		skill_controller = SkillController.new()
		skill_controller.name = "SkillController"
		add_child(skill_controller)

	if progression_controller == null:
		progression_controller = ProgressionControllerScript.new()
		progression_controller.name = "ProgressionController"
		add_child(progression_controller)

	if combat_target:
		progression_controller.setup(combat_target)

	progression_controller.experience_gained.connect(_on_experience_gained)
	progression_controller.level_up.connect(_on_level_up)

func _setup_starter_inventory() -> void:
	if inventory_controller:
		inventory_controller.add_item(ItemData.create_potion("Poción de Salud", 60.0, 0.0, 10))
		inventory_controller.add_item(ItemData.create_potion("Poción de Maná", 0.0, 40.0, 5))
		inventory_controller.add_item(ItemData.create_weapon("Espada Rúnica", 45, 7, ItemData.ItemRarity.RARE))
		inventory_controller.add_item(ItemData.create_armor("Escudo de Roble", 25, ItemData.EquipmentSlot.OFF_HAND, 0, ItemData.ItemRarity.UNCOMMON))

func _setup_starter_equipment() -> void:
	if equipment_controller:
		var starter_sword := ItemData.create_weapon("Espada de Acero", 30, 1, ItemData.ItemRarity.COMMON)
		equipment_controller.equip_item(starter_sword, ItemData.EquipmentSlot.MAIN_HAND, inventory_controller)
		if combat_target and combat_target.get_stats():
			equipment_controller.apply_equipment_stats_to(combat_target.get_stats())

func _on_player_died() -> void:
	if not is_multiplayer_authority():
		return
	var delay := float(GameConfig.get_combat_value("targets", "player_respawn_delay", 3.0))
	get_tree().create_timer(delay).timeout.connect(func():
		if combat_target:
			combat_target.sync_reset_health()
	)

func _on_experience_gained(amount: int, _curr: int, _req: int) -> void:
	if amount > 0:
		_spawn_floating_text("+%d XP" % amount)

func _on_level_up(new_lvl: int, _gains: Dictionary) -> void:
	_spawn_floating_text("¡NIVEL %d!" % new_lvl)

func _spawn_floating_text(text_msg: String) -> void:
	if combat_target and combat_target.has_method("_spawn_damage_number"):
		combat_target._spawn_damage_number(0.0, global_position + Vector3(0, 2.2, 0), false, false, false, false, false, false, text_msg)

## Añade experiencia al personaje a través de su controlador de progresión.
func add_experience(amount: int) -> void:
	if progression_controller:
		progression_controller.add_experience(amount)

## Retorna el nivel actual del personaje.
func get_level() -> int:
	if progression_controller:
		return progression_controller.current_level
	if combat_target and combat_target.get_stats():
		return combat_target.get_stats().level
	return 1

## Selecciona un objetivo de combate sin iniciar aproximación ni ataque automático.
func select_target(target: Node3D) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	clear_click_move()
	if combat_controller:
		combat_controller.select_target(target)

## Inicia aproximación automática y ataque hacia el objetivo indicado o actual.
func attack_target(target: Node3D = null) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	clear_click_move()
	if combat_controller:
		combat_controller.attack_target(target)

## Establece un objetivo de combate para auto-aproximación y ataque (retrocompatibilidad).
func set_combat_target(target: Node3D) -> void:
	attack_target(target)

## Obtiene el objetivo actual del CombatController
func get_combat_target() -> Node3D:
	if combat_controller:
		return combat_controller.current_target
	return null

## Limpia y deselecciona el objetivo actual
func clear_combat_target() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if combat_controller:
		combat_controller.clear_target()

## Inicia el desplazamiento guiado hacia un punto del suelo (Click-to-Move)
func move_to_ground_position(target_pos: Vector3) -> void:
	if not is_multiplayer_authority():
		return

	# Si se encontraba en combate activo o aproximándose, cancelarlo inmediatamente
	if combat_controller and combat_controller.is_active():
		combat_controller.clear_target()

	_click_move_target = target_pos
	_has_click_move = true
	_stuck_timer = 0.0
	_last_pos = global_position

	if _ground_marker:
		_ground_marker.show_at(target_pos)

## Cancela el desplazamiento guiado y oculta el marcador visual del suelo
func clear_click_move() -> void:
	if _has_click_move:
		_has_click_move = false
		_stuck_timer = 0.0
		if _ground_marker:
			_ground_marker.fade_out()

func has_click_move() -> bool:
	return _has_click_move

func get_click_move_target() -> Vector3:
	return _click_move_target

func _process(delta: float) -> void:
	if visuals:
		var speed: float = 0.0
		if is_multiplayer_authority():
			var forward_dir := -transform.basis.z
			var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
			if horiz_vel.length_squared() > 0.01:
				var dot := forward_dir.dot(horiz_vel.normalized())
				var sign_dir := -1.0 if dot < -0.2 else 1.0
				speed = horiz_vel.length() * sign_dir
		else:
			if delta > 0.0:
				var dist := global_position.distance_to(_prev_global_pos)
				speed = dist / delta
				_prev_global_pos = global_position
			if speed < 0.1 and is_moving and config:
				speed = config.forward_speed

		visuals.update_animation(is_moving, speed)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	_apply_gravity(delta)
	_process_movement(delta)

	if combat_controller:
		combat_controller.update_combat(delta, visuals)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var mult := config.gravity_multiplier if config else 1.0
		velocity.y -= gravity * mult * delta

func _process_movement(delta: float) -> void:
	if config == null:
		config = DEFAULT_CONFIG

	# Bloqueo total si el jugador se encuentra aturdido (Stun)
	var status_ctrl := get_node_or_null("StatusEffectController")
	if status_ctrl and status_ctrl.has_method("is_stunned") and status_ctrl.is_stunned():
		if combat_target and combat_target.is_guarding:
			combat_target.is_guarding = false
		clear_click_move()
		_dash_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		is_moving = false
		move_and_slide()
		return

	# Si se encuentra en plena ejecución de Dash
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
		is_moving = true
		move_and_slide()
		return

	var move_speed_mult: float = status_ctrl.get_move_speed_multiplier() if (status_ctrl and status_ctrl.has_method("get_move_speed_multiplier")) else 1.0

	# 1. Giro en su eje con A y D (o flechas)
	var turn_input := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		turn_input += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		turn_input -= 1.0

	# 2. Desplazamiento adelante/atrás
	var forward_input := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_forward"):
		forward_input += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_backward"):
		forward_input -= 1.0

	# 3. Guardia Activa con Escudo (Active Shield Guard - Shift)
	var wants_guard := Input.is_key_pressed(KEY_SHIFT) or (InputMap.has_action("guard") and Input.is_action_pressed("guard"))
	if wants_guard:
		if combat_target and not combat_target.is_guarding:
			combat_target.is_guarding = true
		var guard_mult := float(GameConfig.get_combat_value("defense_mechanics", "guard_speed_multiplier", 0.70))
		move_speed_mult *= guard_mult
	else:
		if combat_target and combat_target.is_guarding:
			combat_target.is_guarding = false

	# 4. Esquiva Rápida con I-Frames (Dash - Barra Espaciadora)
	var is_space_down := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_select")
	var just_pressed_space := is_space_down and not _was_space_pressed
	_was_space_pressed = is_space_down

	if just_pressed_space and _dash_cooldown_timer <= 0.0:
		var dash_dur := float(GameConfig.get_combat_value("defense_mechanics", "dash_duration", 0.20))
		var dash_cd := float(GameConfig.get_combat_value("defense_mechanics", "dash_cooldown", 1.0))
		var dash_mult := float(GameConfig.get_combat_value("defense_mechanics", "dash_speed_multiplier", 2.2))

		_dash_timer = dash_dur
		_dash_cooldown_timer = dash_cd

		var dash_dir := Vector3.ZERO
		if forward_input > 0.0:
			dash_dir += -transform.basis.z
		elif forward_input < 0.0:
			dash_dir += transform.basis.z
		if turn_input > 0.0:
			dash_dir += -transform.basis.x
		elif turn_input < 0.0:
			dash_dir += transform.basis.x

		if dash_dir.length_squared() < 0.01:
			dash_dir = -transform.basis.z
		else:
			dash_dir = dash_dir.normalized()

		_dash_velocity = dash_dir * config.forward_speed * dash_mult

		if combat_target:
			combat_target.trigger_invulnerability(dash_dur)
		if combat_controller and combat_controller.is_active():
			combat_controller.clear_target()
		clear_click_move()

		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
		is_moving = true
		move_and_slide()
		return

	# Cancelar combate automático y click-to-move si el jugador presiona manualmente cualquier tecla de movimiento
	var has_manual_input := (turn_input != 0.0 or forward_input != 0.0)
	if has_manual_input:
		if combat_controller and combat_controller.is_active():
			combat_controller.clear_target()
		clear_click_move()

	# Auto-aproximación hacia el objetivo de combate (directo, en línea recta y sin alterar la cámara)
	if not has_manual_input and combat_controller and combat_controller.is_approaching():
		clear_click_move()
		var approach_dir := combat_controller.get_approach_direction()
		if approach_dir != Vector3.ZERO:
			# Orientación directa hacia el objetivo
			rotation.y = atan2(-approach_dir.x, -approach_dir.z)

			# Desplazamiento en línea recta hacia el objetivo ajustado por ralentización
			velocity.x = approach_dir.x * config.forward_speed * move_speed_mult
			velocity.z = approach_dir.z * config.forward_speed * move_speed_mult
			is_moving = true
			move_and_slide()
			return

	# Si está en rango atacando, frenar en seco inmediatamente para dar los golpes
	if not has_manual_input and combat_controller and combat_controller.is_attacking():
		clear_click_move()
		velocity.x = 0.0
		velocity.z = 0.0
		is_moving = false
		move_and_slide()
		return

	# Desplazamiento guiado por ratón hacia el punto marcado (Click-to-Move)
	if not has_manual_input and _has_click_move:
		var diff := _click_move_target - global_position
		diff.y = 0.0
		var dist := diff.length()
		var arrival_dist := 0.35

		# Detección de atascamiento contra obstáculos
		if is_on_wall() and global_position.distance_squared_to(_last_pos) < 0.0001:
			_stuck_timer += delta
			if _stuck_timer > 0.4:
				clear_click_move()
				velocity.x = 0.0
				velocity.z = 0.0
				is_moving = false
				move_and_slide()
				return
		else:
			_stuck_timer = 0.0
		_last_pos = global_position

		if dist <= arrival_dist:
			clear_click_move()
			velocity.x = 0.0
			velocity.z = 0.0
			is_moving = false
			move_and_slide()
			return
		else:
			var move_dir := diff / dist
			rotation.y = atan2(-move_dir.x, -move_dir.z)
			velocity.x = move_dir.x * config.forward_speed * move_speed_mult
			velocity.z = move_dir.z * config.forward_speed * move_speed_mult
			is_moving = true
			move_and_slide()
			return

	if turn_input != 0.0:
		var turn_delta := turn_input * config.turn_speed * delta
		rotation.y += turn_delta
		# Si no se está usando la cámara libre (sin click derecho), la cámara apunta hacia donde mira el player y lo sigue
		if camera_pivot and not camera_pivot.is_rmb_held:
			camera_pivot.set_yaw(rotation.y)

	var just_started_forward := (forward_input > 0.0 and not _was_forward_pressed)
	_was_forward_pressed = forward_input > 0.0

	if forward_input > 0.0:
		# Al arrancar a caminar (W) sin click derecho, orientar al personaje hacia donde mira la cámara.
		# Mientras ya esté caminando, si se pulsa click derecho para soltar la cámara,
		# la cámara rota libremente y el personaje continúa caminando en su misma dirección.
		if just_started_forward and camera_pivot and not camera_pivot.is_rmb_held:
			rotation.y = camera_pivot.current_yaw

		var forward_dir := -transform.basis.z
		velocity.x = forward_dir.x * config.forward_speed * move_speed_mult
		velocity.z = forward_dir.z * config.forward_speed * move_speed_mult
	elif forward_input < 0.0:
		# Retroceder hacia atrás SIN rotar el cuerpo ni la cara
		var forward_dir := -transform.basis.z
		velocity.x = -forward_dir.x * config.backward_speed * move_speed_mult
		velocity.z = -forward_dir.z * config.backward_speed * move_speed_mult
	else:
		# Desaceleración
		var decel_rate := config.forward_speed * config.deceleration_factor * delta
		velocity.x = move_toward(velocity.x, 0.0, decel_rate)
		velocity.z = move_toward(velocity.z, 0.0, decel_rate)

	is_moving = forward_input != 0.0

	move_and_slide()
