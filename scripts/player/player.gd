class_name Player
extends CharacterBody3D

## Responsabilidad: Física de movimiento y sincronización de red del personaje.
## Control tipo RPG: W avanza, S retrocede sin girar la cara, A/D rota en su eje.
## Cámara libre con click derecho sin alterar la dirección de marcha y con cursor siempre visible.

const FORWARD_SPEED: float = 6.0
const BACKWARD_SPEED: float = 4.2
const TURN_SPEED: float = 5.2

@onready var visuals: PlayerVisuals = $Visuals
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var is_moving: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _was_forward_pressed: bool = false

func _enter_tree() -> void:
	var peer_id := name.to_int()
	set_multiplayer_authority(peer_id)
	$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _ready() -> void:
	var peer_id := name.to_int()
	var is_local := is_multiplayer_authority()
	visuals.configure_visuals(peer_id, is_local)
	camera_pivot.setup(is_local)
	visuals.update_animation(is_moving)

func _process(_delta: float) -> void:
	if visuals:
		visuals.update_animation(is_moving)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	_apply_gravity(delta)
	_process_movement(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _process_movement(delta: float) -> void:
	# 1. Giro en su eje con A y D (o flechas)
	var turn_input := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		turn_input += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		turn_input -= 1.0

	if turn_input != 0.0:
		var turn_delta := turn_input * TURN_SPEED * delta
		rotation.y += turn_delta
		# Si no se está usando la cámara libre (sin click derecho), la cámara apunta hacia donde mira el player y lo sigue
		if camera_pivot and not camera_pivot.is_rmb_held:
			camera_pivot.set_yaw(rotation.y)

	# 2. Desplazamiento adelante/atrás
	var forward_input := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_forward"):
		forward_input += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_backward"):
		forward_input -= 1.0

	var just_started_forward := (forward_input > 0.0 and not _was_forward_pressed)
	_was_forward_pressed = forward_input > 0.0

	if forward_input > 0.0:
		# Al arrancar a caminar (W) sin click derecho, orientar al personaje hacia donde mira la cámara.
		# Mientras ya esté caminando, si se pulsa click derecho para soltar la cámara,
		# la cámara rota libremente y el personaje continúa caminando en su misma dirección.
		if just_started_forward and camera_pivot and not camera_pivot.is_rmb_held:
			rotation.y = camera_pivot.current_yaw

		var forward_dir := -transform.basis.z
		velocity.x = forward_dir.x * FORWARD_SPEED
		velocity.z = forward_dir.z * FORWARD_SPEED
	elif forward_input < 0.0:
		# Retroceder hacia atrás SIN rotar el cuerpo ni la cara
		var forward_dir := -transform.basis.z
		velocity.x = -forward_dir.x * BACKWARD_SPEED
		velocity.z = -forward_dir.z * BACKWARD_SPEED
	else:
		# Desaceleración
		velocity.x = move_toward(velocity.x, 0.0, FORWARD_SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, FORWARD_SPEED * 8.0 * delta)

	is_moving = forward_input != 0.0

	move_and_slide()
