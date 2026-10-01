class_name GroundMarker
extends Node3D

## Responsabilidad: Marcador visual en el suelo con forma de rombo ("rombito marcado").
## Proporciona respuesta visual instantánea al hacer click-to-move en el mundo 3D.
## Desacoplado de la física del jugador, se ubica en coordenadas globales con top_level.

@export var marker_color: Color = Color(0.2, 0.85, 1.0, 0.9)
@export var base_scale: float = 0.9

var _mesh_node: MeshInstance3D = null
var _tween: Tween = null
var _is_active: bool = false
var _spin_angle: float = 0.0

func _enter_tree() -> void:
	top_level = true
	visible = false

func _ready() -> void:
	top_level = true
	visible = false
	_build_visuals()

func _build_visuals() -> void:
	if _mesh_node != null:
		return

	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "DiamondMesh"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(base_scale, base_scale)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _generate_diamond_texture()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	_mesh_node.mesh = mesh
	_mesh_node.material_override = mat

	add_child(_mesh_node)

func _process(delta: float) -> void:
	if not _is_active or not visible:
		return

	# Giro suave y rítmico mientras esté activo
	_spin_angle += delta * 1.5
	if _mesh_node:
		_mesh_node.rotation.y = sin(_spin_angle) * 0.2

## Despliega el rombo en la posición del mundo indicada con animación pop-in
func show_at(world_pos: Vector3) -> void:
	_is_active = true
	global_position = world_pos + Vector3(0, 0.03, 0)
	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	scale = Vector3(0.15, 1.0, 0.15)
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "scale", Vector3(1.15, 1.0, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE)

## Desvanece el rombo cuando el jugador llega al destino o cancela el movimiento
func fade_out() -> void:
	if not _is_active and not visible:
		return

	_is_active = false
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector3(0.05, 1.0, 0.05), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		visible = false
		scale = Vector3.ONE
	)

## Genera proceduralmente una textura de rombo con borde de neón brillante, rombo secundario y centro de cristal
func _generate_diamond_texture() -> ImageTexture:
	var dim := 128
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var center := Vector2(dim * 0.5, dim * 0.5)
	var radius := dim * 0.44

	for y in range(dim):
		for x in range(dim):
			var p := Vector2(x + 0.5, y + 0.5)
			# Distancia Manhattan para forma geométrica de rombo exacto
			var m_dist := absf(p.x - center.x) + absf(p.y - center.y)
			var d := m_dist / radius
			var pixel_col := Color(0, 0, 0, 0)

			# Borde exterior del rombo
			if d >= 0.80 and d <= 1.0:
				var edge_alpha := 1.0 - absf(d - 0.90) / 0.10
				pixel_col = marker_color
				pixel_col.a = clampf(edge_alpha * 0.95, 0.0, 1.0)
			# Anillo / borde interior concéntrico
			elif d >= 0.42 and d <= 0.54:
				var mid_alpha := 1.0 - absf(d - 0.48) / 0.06
				pixel_col = marker_color.lightened(0.15)
				pixel_col.a = clampf(mid_alpha * 0.75, 0.0, 1.0)
			# Relleno interior translúcido
			elif d < 0.42:
				var fill_alpha := (1.0 - d / 0.42) * 0.35
				pixel_col = marker_color.lightened(0.3)
				pixel_col.a = fill_alpha

			# Punto de destello central brillante
			if d < 0.18:
				var core_alpha := (1.0 - d / 0.18)
				pixel_col = pixel_col.lerp(Color(1.0, 1.0, 1.0, 0.95), core_alpha * 0.85)

			img.set_pixel(x, y, pixel_col)

	return ImageTexture.create_from_image(img)
