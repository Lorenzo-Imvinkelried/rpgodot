class_name Player
extends CharacterBody3D

## Responsabilidad: Física de movimiento y sincronización de red del personaje.
## Control tipo RPG: W avanza, S retrocede sin girar la cara, A/D rota en su eje.

const FORWARD_SPEED: float = 6.0
const BACKWARD_SPEED: float = 4.2
const TURN_SPEED: float = 5.2

@onready var visuals: PlayerVisuals = $Visuals
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _enter_tree() -> void:
	var peer_id := name.to_int()
	set_multiplayer_authority(peer_id)
	$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

func _ready() -> void:
	var peer_id := name.to_int()
	var is_local := is_multiplayer_authority()
	visuals.configure_visuals(peer_id, is_local)
	camera_pivot.setup(is_local)

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
		# Sincronizar simultáneamente el ángulo de la cámara para eliminar cualquier tirón o retraso opuesto
		if camera_pivot and not camera_pivot.is_rmb_held:
			camera_pivot.rotate_yaw(turn_delta)

	# 2. Desplazamiento adelante/atrás relativo al frente del personaje
	var forward_input := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_forward"):
		forward_input += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_backward"):
		forward_input -= 1.0

	# En Godot, -transform.basis.z es la dirección frontal hacia donde mira el visor
	var forward_dir := -transform.basis.z

	if forward_input > 0.0:
		# Avanzar hacia el frente
		velocity.x = forward_dir.x * FORWARD_SPEED
		velocity.z = forward_dir.z * FORWARD_SPEED
	elif forward_input < 0.0:
		# Retroceder hacia atrás SIN rotar el cuerpo ni la cara
		velocity.x = -forward_dir.x * BACKWARD_SPEED
		velocity.z = -forward_dir.z * BACKWARD_SPEED
	else:
		# Desaceleración
		velocity.x = move_toward(velocity.x, 0.0, FORWARD_SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, FORWARD_SPEED * 8.0 * delta)

	move_and_slide()
