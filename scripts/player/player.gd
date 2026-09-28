class_name Player
extends CharacterBody3D

## Responsabilidad: Física de movimiento y sincronización de red del personaje.
## Control tipo RPG: W avanza, S retrocede sin girar la cara, A/D rota en su eje.
## Cámara libre con click derecho sin alterar la dirección de marcha y con cursor siempre visible.

const DEFAULT_CONFIG = preload("res://resources/player/default_player_config.tres")

@export var config: PlayerConfig = DEFAULT_CONFIG
@export var is_moving: bool = false

@onready var visuals: PlayerVisuals = $Visuals
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var combat_controller: CombatController = get_node_or_null("CombatController")
@onready var combat_target: CombatTarget = get_node_or_null("CombatTarget")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_forward_pressed: bool = false
var _prev_global_pos: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	var peer_id := name.to_int()
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

	if combat_target:
		combat_target.died.connect(_on_player_died)

func _on_player_died() -> void:
	if not is_multiplayer_authority():
		return
	var delay := float(GameConfig.get_combat_value("targets", "player_respawn_delay", 3.0))
	get_tree().create_timer(delay).timeout.connect(func():
		if combat_target:
			combat_target.sync_reset_health()
	)

## Establece un objetivo de combate para auto-aproximación y ataque.
func set_combat_target(target: Node3D) -> void:
	if is_inside_tree() and not is_multiplayer_authority():
		return
	if combat_controller:
		combat_controller.set_target(target)

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

	# Cancelar combate automático si el jugador presiona manualmente cualquier tecla de movimiento
	var has_manual_input := (turn_input != 0.0 or forward_input != 0.0)
	if has_manual_input and combat_controller and combat_controller.is_active():
		combat_controller.clear_target()

	# Auto-aproximación hacia el objetivo de combate (directo, en línea recta y sin alterar la cámara)
	if not has_manual_input and combat_controller and combat_controller.is_approaching():
		var approach_dir := combat_controller.get_approach_direction()
		if approach_dir != Vector3.ZERO:
			# Orientación directa hacia el objetivo
			rotation.y = atan2(-approach_dir.x, -approach_dir.z)

			# Desplazamiento en línea recta hacia el objetivo
			velocity.x = approach_dir.x * config.forward_speed
			velocity.z = approach_dir.z * config.forward_speed
			is_moving = true
			move_and_slide()
			return

	# Si está en rango atacando, frenar en seco inmediatamente para dar los golpes
	if not has_manual_input and combat_controller and combat_controller.is_attacking():
		velocity.x = 0.0
		velocity.z = 0.0
		is_moving = false
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
		velocity.x = forward_dir.x * config.forward_speed
		velocity.z = forward_dir.z * config.forward_speed
	elif forward_input < 0.0:
		# Retroceder hacia atrás SIN rotar el cuerpo ni la cara
		var forward_dir := -transform.basis.z
		velocity.x = -forward_dir.x * config.backward_speed
		velocity.z = -forward_dir.z * config.backward_speed
	else:
		# Desaceleración
		var decel_rate := config.forward_speed * config.deceleration_factor * delta
		velocity.x = move_toward(velocity.x, 0.0, decel_rate)
		velocity.z = move_toward(velocity.z, 0.0, decel_rate)

	is_moving = forward_input != 0.0

	move_and_slide()
