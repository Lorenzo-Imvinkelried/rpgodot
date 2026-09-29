class_name GhostSlashFX
extends Node3D

## Responsabilidad: Efecto visual de clon fantasma / afterimage para Multi-Strike (Ghost Slashes).
## Instancia una réplica translúcida y brillante del modelo del atacante, ejecuta un ataque rápido y se desvanece suavemente.

const GHOST_COLOR_1 := Color(0.35, 0.75, 1.0, 0.55) # Celeste espectral (Ghost 1)
const GHOST_EMISSION_1 := Color(0.2, 0.65, 1.0)
const GHOST_COLOR_2 := Color(0.85, 0.45, 1.0, 0.55) # Violeta espectral (Ghost 2)
const GHOST_EMISSION_2 := Color(0.7, 0.3, 1.0)

var _ghost_materials: Array[StandardMaterial3D] = []

## Crea y añade al mundo un clon fantasma del modelo fuente realizando el tajo a alta velocidad.
static func create(
	source_model: Node3D,
	source_transform: Transform3D,
	hit_index: int = 1,
	base_speed_scale: float = 1.0
) -> GhostSlashFX:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or source_model == null:
		return null

	var ghost_root := GhostSlashFX.new()
	tree.root.add_child(ghost_root)

	# Instanciar clon del modelo a partir de su PackedScene original o duplicado
	var clone_model: Node3D = null
	if not source_model.scene_file_path.is_empty():
		var scene := load(source_model.scene_file_path) as PackedScene
		if scene:
			clone_model = scene.instantiate() as Node3D

	if clone_model == null:
		clone_model = source_model.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D

	if clone_model == null:
		ghost_root.queue_free()
		return null

	ghost_root.add_child(clone_model)
	# Copiar la transformación local del modelo dentro del visuals (por ej. rotación 180° si la tiene)
	clone_model.transform = source_model.transform

	ghost_root.setup_ghost(clone_model, source_transform, hit_index, base_speed_scale)
	return ghost_root

func setup_ghost(
	clone_model: Node3D,
	source_transform: Transform3D,
	hit_index: int,
	base_speed_scale: float
) -> void:
	# 1. Configuración de colores según hit_index
	var is_second_ghost := hit_index >= 2
	var base_col: Color = GHOST_COLOR_2 if is_second_ghost else GHOST_COLOR_1
	var emission_col: Color = GHOST_EMISSION_2 if is_second_ghost else GHOST_EMISSION_1

	# 2. Desplazamiento lateral y frontal relativo para que no coincida exactamente con el cuerpo del jugador
	var offset_dist := float(GameConfig.get_combat_value("multi_strike", "ghost_offset_distance", 0.35))
	var lateral_sign: float = -1.0 if is_second_ghost else 1.0
	var offset_vector := (source_transform.basis.x * (offset_dist * lateral_sign)) + (source_transform.basis.z * 0.1)

	global_transform = source_transform
	global_position += offset_vector

	# 3. Aplicar material translúcido fantasmal a todas las mallas del clon
	_apply_ghost_material_recursive(clone_model, base_col, emission_col)

	# 4. Encontrar AnimationPlayer y ejecutar animación de ataque acelerada
	var speed_mult := float(GameConfig.get_combat_value("multi_strike", "ghost_anim_speed_multiplier", 1.6))
	var ghost_speed := base_speed_scale * speed_mult
	var anim_player := _find_animation_player(clone_model)

	if anim_player:
		anim_player.speed_scale = ghost_speed
		var anim_name := _pick_attack_animation(anim_player)
		if not anim_name.is_empty():
			anim_player.play(anim_name)

	# 5. Animación de desvanecimiento suave (fade-out)
	var fade_duration := float(GameConfig.get_combat_value("multi_strike", "ghost_fade_duration", 0.38))
	var tween := create_tween()
	tween.set_parallel(true)

	for mat in _ghost_materials:
		tween.tween_property(mat, "albedo_color:a", 0.0, fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 6. Autodestrucción al finalizar el desvanecimiento
	tween.chain().tween_callback(queue_free)

func _apply_ghost_material_recursive(node: Node, albedo_color: Color, emission_color: Color) -> void:
	if node is MeshInstance3D:
		var orig_mat: Material = node.get_active_material(0)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

		if orig_mat is BaseMaterial3D and orig_mat.albedo_texture:
			mat.albedo_texture = orig_mat.albedo_texture

		mat.albedo_color = albedo_color
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = 1.6
		mat.roughness = 0.3
		mat.rim_enabled = true
		mat.rim = 0.6

		node.material_override = mat
		_ghost_materials.append(mat)

	for child in node.get_children():
		_apply_ghost_material_recursive(child, albedo_color, emission_color)

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
	for candidate in ["attack", "slash", "punch", "strike", "hit"]:
		for anim in list:
			if candidate in anim.to_lower():
				return anim
	return list[0] if list.size() > 0 else ""
