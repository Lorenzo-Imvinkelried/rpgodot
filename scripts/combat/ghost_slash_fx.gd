class_name GhostSlashFX
extends Node3D

## Responsabilidad: Efecto visual de clon fantasma / afterimage para Multi-Strike (Ghost Slashes).
## Utiliza un pool pre-calentado en memoria para eliminar el tirón (lag spike) del primer golpe.
## Ejecuta el recorrido completo de la espada antes de desvanecerse en el remate del golpe.

const GHOST_COLOR_1 := Color(0.35, 0.75, 1.0, 0.65) # Celeste espectral (Ghost 1)
const GHOST_EMISSION_1 := Color(0.2, 0.65, 1.0)
const GHOST_COLOR_2 := Color(0.85, 0.45, 1.0, 0.65) # Violeta espectral (Ghost 2)
const GHOST_EMISSION_2 := Color(0.7, 0.3, 1.0)

const PREWARM_COUNT := 3
static var _pool: Array[GhostSlashFX] = []
static var _cached_scene: PackedScene = null
static var _is_prewarmed: bool = false

var _clone_model: Node3D = null
var _anim_player: AnimationPlayer = null
var _ghost_materials: Array[StandardMaterial3D] = []
var _active_tween: Tween = null
var _is_busy: bool = false

## Pre-calienta el pool de clones fantasma para compilar shaders y cargar mallas en la GPU antes del combate.
static func prewarm(tree: SceneTree, source_model: Node3D) -> void:
	if _is_prewarmed or tree == null or tree.root == null:
		return
	_is_prewarmed = true

	# Esperar al siguiente frame para asegurar que la escena principal terminó de montarse
	await tree.process_frame

	if _cached_scene == null and source_model != null and not source_model.scene_file_path.is_empty():
		_cached_scene = load(source_model.scene_file_path) as PackedScene

	for i in range(PREWARM_COUNT):
		var ghost := _create_instance(source_model)
		if ghost:
			tree.root.add_child(ghost)
			# Posicionar a escala minúscula dentro de la escena para que la GPU compile los shaders de inmediato
			if source_model != null and source_model.is_inside_tree():
				ghost.global_transform = source_model.global_transform
			ghost.scale = Vector3(0.001, 0.001, 0.001)
			ghost.visible = true
			_pool.append(ghost)

	# Esperar 2 frames de renderizado para forzar al driver de la GPU a compilar
	# los shaders y pipelines de los materiales translúcidos y de emisión sin congelar el juego durante el combate
	if tree != null:
		await tree.process_frame
		await tree.process_frame

	for ghost in _pool:
		if is_instance_valid(ghost) and not ghost._is_busy:
			ghost.visible = false
			ghost.scale = Vector3.ONE
			ghost.position = Vector3(0, -999, 0)

static func _create_instance(source_model: Node3D) -> GhostSlashFX:
	var ghost := GhostSlashFX.new()

	var clone: Node3D = null
	if _cached_scene != null:
		clone = _cached_scene.instantiate() as Node3D
	elif source_model != null and not source_model.scene_file_path.is_empty():
		_cached_scene = load(source_model.scene_file_path) as PackedScene
		if _cached_scene:
			clone = _cached_scene.instantiate() as Node3D

	if clone == null and source_model != null:
		clone = source_model.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D

	if clone == null:
		ghost.queue_free()
		return null

	ghost.add_child(clone)
	if source_model != null:
		clone.transform = source_model.transform

	ghost._clone_model = clone
	ghost._anim_player = ghost._find_animation_player(clone)
	ghost._init_ghost_materials(clone)
	return ghost

## Obtiene una instancia del pool o crea una nueva si es necesario, activando el recorrido de espada.
static func spawn(
	source_model: Node3D,
	source_transform: Transform3D,
	hit_index: int = 1,
	base_speed_scale: float = 1.0,
	anim_name: String = ""
) -> GhostSlashFX:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null

	var ghost: GhostSlashFX = null
	for item in _pool:
		if is_instance_valid(item) and not item._is_busy:
			ghost = item
			break

	if ghost == null:
		ghost = _create_instance(source_model)
		if ghost:
			tree.root.add_child(ghost)
			_pool.append(ghost)

	if ghost == null:
		return null

	ghost.activate_ghost(source_transform, hit_index, base_speed_scale, anim_name)
	return ghost

## Método de compatibilidad hacia atrás
static func create(
	source_model: Node3D,
	source_transform: Transform3D,
	hit_index: int = 1,
	base_speed_scale: float = 1.0
) -> GhostSlashFX:
	return spawn(source_model, source_transform, hit_index, base_speed_scale, "")

## Activa el clon fantasma, reproduce la animación completa y desvanece al final del recorrido.
func activate_ghost(
	source_transform: Transform3D,
	hit_index: int,
	base_speed_scale: float,
	anim_name: String
) -> void:
	_is_busy = true
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	# 1. Colores según el índice del golpe fantasma
	var is_second := hit_index >= 2
	var base_col: Color = GHOST_COLOR_2 if is_second else GHOST_COLOR_1
	var emission_col: Color = GHOST_EMISSION_2 if is_second else GHOST_EMISSION_1

	# 2. Desplazamiento lateral y frontal relativo (para flanquear al jugador de forma natural)
	var offset_dist := float(GameConfig.get_combat_value("multi_strike", "ghost_offset_distance", 0.35))
	var lateral_sign: float = -1.0 if is_second else 1.0
	var offset_vec := (source_transform.basis.x * (offset_dist * lateral_sign)) + (source_transform.basis.z * 0.08)

	global_transform = source_transform
	global_position += offset_vec
	visible = true

	# 3. Restaurar opacidad y brillo inicial en los materiales
	for mat in _ghost_materials:
		mat.albedo_color = base_col
		mat.emission = emission_col
		mat.emission_energy_multiplier = 1.8

	# 4. Velocidad de animación ajustada para percibir nítidamente el golpe
	var speed_mult := float(GameConfig.get_combat_value("multi_strike", "ghost_anim_speed_multiplier", 1.25))
	var ghost_speed: float = maxf(0.1, base_speed_scale * speed_mult)

	var target_anim := anim_name
	if _anim_player:
		_anim_player.speed_scale = ghost_speed
		if target_anim.is_empty() or not _anim_player.has_animation(target_anim):
			target_anim = _pick_attack_animation(_anim_player)
		if not target_anim.is_empty():
			_anim_player.stop()
			_anim_player.play(target_anim)

	# 5. Cálculo exacto del tiempo de la espada para garantizar recorrido completo de corte y remate
	var anim_length := 1.266
	if _anim_player and not target_anim.is_empty():
		var a := _anim_player.get_animation(target_anim)
		if a and a.length > 0.01:
			anim_length = a.length

	var total_duration := anim_length / ghost_speed
	# La espada se mantiene completamente visible y sólida durante el recorrido entero del tajo (85% del tiempo)
	var swing_ratio := float(GameConfig.get_combat_value("multi_strike", "ghost_swing_completion_ratio", 0.85))
	var swing_time: float = total_duration * clampf(swing_ratio, 0.5, 0.95)
	# El desvanecimiento suave solo ocurre en la recuperación final (15% restante)
	var fade_time: float = maxf(0.12, total_duration - swing_time)

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	for mat in _ghost_materials:
		_active_tween.tween_property(mat, "albedo_color:a", 0.0, fade_time).set_delay(swing_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(mat, "emission_energy_multiplier", 0.0, fade_time).set_delay(swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 6. Al terminar el recorrido y desvanecimiento, devolver al pool
	_active_tween.chain().tween_callback(_deactivate)

func _deactivate() -> void:
	visible = false
	_is_busy = false
	if _anim_player:
		_anim_player.stop()
	position = Vector3(0, -999, 0)

func _init_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var orig_mat: Material = node.get_active_material(0)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

		if orig_mat is BaseMaterial3D and orig_mat.albedo_texture:
			mat.albedo_texture = orig_mat.albedo_texture

		mat.albedo_color = GHOST_COLOR_1
		mat.emission_enabled = true
		mat.emission = GHOST_EMISSION_1
		mat.emission_energy_multiplier = 1.8
		mat.roughness = 0.3
		mat.rim_enabled = true
		mat.rim = 0.6

		node.material_override = mat
		_ghost_materials.append(mat)

	for child in node.get_children():
		_init_ghost_materials(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _pick_attack_animation(player: AnimationPlayer) -> String:
	var list := player.get_animation_list()
	for candidate in ["slash", "attack", "punch", "strike", "hit"]:
		for anim in list:
			if candidate in anim.to_lower():
				return anim
	return list[0] if list.size() > 0 else ""
