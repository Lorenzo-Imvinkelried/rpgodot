class_name TargetIndicator3D
extends Node3D

## Responsabilidad: Marcador visual 3D (rombo/diamante flotante) sobre la cabeza del objetivo seleccionado.
## Proporciona retroalimentación visual clara e instantánea de la entidad enfocada en combate/inspección.
## Desacoplado de la lógica del objetivo, funciona con top_level y sigue suavemente la posición de la cabeza.

@export var indicator_color: Color = Color(1.0, 0.85, 0.2, 0.95)
@export var base_scale: float = 0.45

var _mesh_node: MeshInstance3D = null
var _target: Node3D = null
var _tween: Tween = null
var _bob_time: float = 0.0

func _enter_tree() -> void:
	top_level = true
	visible = false

func _ready() -> void:
	top_level = true
	visible = false
	_build_mesh()

func _build_mesh() -> void:
	if _mesh_node != null:
		return

	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "DiamondCrystal"

	# Crear geometría de diamante 3D (Octaedro)
	_mesh_node.mesh = _create_octahedron_mesh(base_scale * 0.5, base_scale * 0.75)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = indicator_color

	_mesh_node.material_override = mat
	add_child(_mesh_node)

func _process(delta: float) -> void:
	if not visible or _target == null:
		return

	if not is_instance_valid(_target):
		clear_target()
		return

	# Seguir posición sobre la cabeza del objetivo con oscilación suave
	_bob_time += delta * 4.5
	var bob := sin(_bob_time) * 0.08
	var head_y := _calculate_target_head_height(_target)

	global_position = _target.global_position + Vector3(0.0, head_y + bob, 0.0)

	# Rotación 3D continua para efecto de gema mágica flotante
	if _mesh_node:
		_mesh_node.rotation.y += delta * 2.5

## Asigna el objetivo sobre el cual se mostrará el rombo
func set_target(new_target: Node3D) -> void:
	if new_target == null:
		clear_target()
		return

	_build_mesh()
	_target = new_target
	_bob_time = 0.0

	var head_y := _calculate_target_head_height(_target)
	global_position = _target.global_position + Vector3(0.0, head_y, 0.0)
	visible = true

	if is_inside_tree():
		if _tween and _tween.is_valid():
			_tween.kill()

		scale = Vector3(0.1, 0.1, 0.1)
		_tween = create_tween()
		if _tween:
			_tween.set_parallel(false)
			_tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	else:
		scale = Vector3.ONE

	# Escuchar muerte del objetivo para ocultarse automáticamente
	var ct: Node = _target.get_node_or_null("CombatTarget")
	if ct and ct.has_signal("died"):
		if not ct.died.is_connected(_on_target_died):
			ct.died.connect(_on_target_died, CONNECT_ONE_SHOT)

func _on_target_died() -> void:
	clear_target(true)

func has_target() -> bool:
	return _target != null

## Oculta y desvanece el rombo cuando se pierde o deselecciona el objetivo
func clear_target(immediate: bool = false) -> void:
	if _target == null and not visible:
		return

	_target = null
	if is_inside_tree() and not immediate:
		if _tween and _tween.is_valid():
			_tween.kill()

		_tween = create_tween()
		if _tween:
			_tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_callback(func():
				visible = false
				scale = Vector3.ONE
			)
		else:
			visible = false
			scale = Vector3.ONE
	else:
		if _tween and _tween.is_valid():
			_tween.kill()
		visible = false
		scale = Vector3.ONE

func _calculate_target_head_height(target_node: Node3D) -> float:
	# 1. Si tiene barra de vida 3D, colocarse justo por encima de ella
	var hp_bar := target_node.find_child("HealthBar3D", true, false) as Node3D
	if hp_bar and hp_bar.is_inside_tree():
		var diff := hp_bar.global_position.y - target_node.global_position.y
		return diff + 0.35

	# 2. Si tiene colisión cápsula o caja
	var col := target_node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col and col.shape:
		if col.shape is CapsuleShape3D:
			return (col.shape as CapsuleShape3D).height + 0.45
		elif col.shape is BoxShape3D:
			return (col.shape as BoxShape3D).size.y + 0.45

	return 2.45

## Construye proceduralmente una malla de diamante / octaedro 3D
static func _create_octahedron_mesh(radius: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top := Vector3(0.0, height, 0.0)
	var bottom := Vector3(0.0, -height, 0.0)
	var n := Vector3(0.0, 0.0, -radius)
	var e := Vector3(radius, 0.0, 0.0)
	var s := Vector3(0.0, 0.0, radius)
	var w := Vector3(-radius, 0.0, 0.0)

	_add_triangle(st, top, n, e)
	_add_triangle(st, top, e, s)
	_add_triangle(st, top, s, w)
	_add_triangle(st, top, w, n)

	_add_triangle(st, bottom, e, n)
	_add_triangle(st, bottom, s, e)
	_add_triangle(st, bottom, w, s)
	_add_triangle(st, bottom, n, w)

	return st.commit()

static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
