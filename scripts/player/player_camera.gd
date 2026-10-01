class_name PlayerCamera
extends Node3D

## Responsabilidad: Control exclusivo de la cámara en 3ra persona.
## Gestiona rotación orbital con click derecho, zoom con ruedita y seguimiento de posición.
## No realiza auto-rotaciones graduales que provoquen mareos; cualquier orientación es instantánea.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_degrees: float = -50.0
@export var max_pitch_degrees: float = 30.0
@export var min_zoom: float = 2.0
@export var max_zoom: float = 12.0
@export var zoom_step: float = 1.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var is_rmb_held: bool = false
var target_zoom: float = 5.5
var current_yaw: float = 0.0
var current_pitch: float = -0.35 # Inclinación hacia abajo inicial (~ -20 grados)

func setup(is_local: bool) -> void:
	camera.current = is_local
	set_process(is_local)
	set_process_unhandled_input(is_local)

	if is_local:
		_apply_json_config()
		top_level = true # Desacopla la rotación del padre para control orbital independiente
		target_zoom = spring_arm.spring_length
		var parent_node := get_parent() as Node3D
		if parent_node:
			var pivot_h := float(GameConfig.get_player_value("camera", "pivot_height", 1.5))
			global_position = parent_node.global_position + Vector3(0, pivot_h, 0)
			current_yaw = parent_node.rotation.y
		_apply_rotation()

func _apply_json_config() -> void:
	mouse_sensitivity = float(GameConfig.get_player_value("camera", "mouse_sensitivity", mouse_sensitivity))
	min_pitch_degrees = float(GameConfig.get_player_value("camera", "min_pitch_degrees", min_pitch_degrees))
	max_pitch_degrees = float(GameConfig.get_player_value("camera", "max_pitch_degrees", max_pitch_degrees))
	min_zoom = float(GameConfig.get_player_value("camera", "min_zoom", min_zoom))
	max_zoom = float(GameConfig.get_player_value("camera", "max_zoom", max_zoom))
	zoom_step = float(GameConfig.get_player_value("camera", "zoom_step", zoom_step))
	if spring_arm:
		spring_arm.spring_length = float(GameConfig.get_player_value("camera", "default_zoom", spring_arm.spring_length))

func _exit_tree() -> void:
	if camera.current:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

const TargetDetectorScript = preload("res://scripts/combat/target_detector.gd")

func _unhandled_input(event: InputEvent) -> void:
	if not camera.current:
		return

	# Click Derecho: Seleccionar objetivo atacable o rotar la cámara orbitalmente
	if event is InputEventMouseButton:
		if event.pressed and UIManager.is_mouse_over_ui(get_tree()):
			return

		# Click Izquierdo: Seleccionar objetivo en el mundo 3D (mobs, dummies, jugadores) o Moverse (Click-to-Move)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var parent_node := get_parent() as Node3D
			var exclude: Array[RID] = []
			if parent_node is CollisionObject3D:
				exclude.append((parent_node as CollisionObject3D).get_rid())

			var hit_target := TargetDetectorScript.find_target_at_screen_pos(camera, event.position, exclude)
			if hit_target != null and parent_node and parent_node.has_method("set_combat_target"):
				parent_node.set_combat_target(hit_target)
				return

			# Si no es un objetivo atacable, raycast al suelo del mundo para desplazarse hasta allí
			if parent_node and parent_node.has_method("move_to_ground_position"):
				var ground_pos := _raycast_ground_position(event.position, exclude)
				if ground_pos != Vector3.INF:
					parent_node.move_to_ground_position(ground_pos)
					return

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var parent_node := get_parent() as Node3D
				var exclude: Array[RID] = []
				if parent_node is CollisionObject3D:
					exclude.append((parent_node as CollisionObject3D).get_rid())

				var hit_target := TargetDetectorScript.find_target_at_screen_pos(camera, event.position, exclude)
				if hit_target != null and parent_node and parent_node.has_method("set_combat_target"):
					parent_node.set_combat_target(hit_target)
					is_rmb_held = false
					return
				is_rmb_held = true
			else:
				var was_orbiting := is_rmb_held
				is_rmb_held = false
				# Al soltar el click derecho tras orbitar manualmente la cámara caminando con W
				if was_orbiting:
					var parent_node := get_parent() as Node3D
					if parent_node and (Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W)):
						snap_behind_player()

		# Zoom con la ruedita del mouse
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_step, min_zoom, max_zoom)

	# Movimiento orbital del mouse con click derecho presionado
	elif event is InputEventMouseMotion and is_rmb_held:
		current_yaw -= event.relative.x * mouse_sensitivity
		var min_pitch_rad := deg_to_rad(min_pitch_degrees)
		var max_pitch_rad := deg_to_rad(max_pitch_degrees)
		current_pitch = clamp(current_pitch - event.relative.y * mouse_sensitivity, min_pitch_rad, max_pitch_rad)
		_apply_rotation()

	# Tecla Escape: Deseleccionar objetivo de combate actual
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var parent_node := get_parent() as Node3D
		if parent_node:
			var combat_ctrl = parent_node.get_node_or_null("CombatController")
			if combat_ctrl and combat_ctrl.current_target != null:
				combat_ctrl.clear_target()

func _process(delta: float) -> void:
	if not camera.current:
		return

	var parent_node := get_parent() as Node3D
	if parent_node == null:
		return

	# Seguir la posición del jugador a la altura del pecho/cabeza
	global_position = parent_node.global_position + Vector3(0, 1.5, 0)

	# Zoom suave hacia el target
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, 10.0 * delta)

func rotate_yaw(amount: float) -> void:
	current_yaw += amount
	_apply_rotation()

func set_yaw(yaw: float) -> void:
	current_yaw = yaw
	_apply_rotation()

func snap_behind_player() -> void:
	var parent_node := get_parent() as Node3D
	if parent_node:
		current_yaw = parent_node.rotation.y
		_apply_rotation()

func _apply_rotation() -> void:
	rotation = Vector3(current_pitch, current_yaw, 0.0)

## Proyecta un rayo desde la posición del cursor de la pantalla hacia el suelo del mundo 3D
func _raycast_ground_position(screen_pos: Vector2, exclude: Array[RID]) -> Vector3:
	if camera == null or not camera.is_inside_tree():
		return Vector3.INF
	var space_state := camera.get_world_3d().direct_space_state
	if space_state == null:
		return Vector3.INF

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_dir * 250.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position

	# Fallback: Intersección con el plano horizontal a la altura de los pies del jugador
	var parent_node := get_parent() as Node3D
	var floor_y := parent_node.global_position.y if parent_node else 0.0
	var ground_plane := Plane(Vector3.UP, floor_y)
	var plane_hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	if plane_hit != null:
		return plane_hit

	return Vector3.INF
