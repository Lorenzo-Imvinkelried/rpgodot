class_name StrideAnalyzer
extends RefCounted

## Responsabilidad: Análisis cinemático de esqueletos 3D y animaciones.
## Calcula la longitud de zancada y la velocidad natural de locomoción
## para sincronizar el movimiento físico y la animación sin patinaje de pies.

const FALLBACK_SPEED: float = 4.0
const SAMPLES_DEFAULT: int = 30

const FOOT_KEYWORDS_LEFT: Array[String] = [
	"leftfoot", "foot_l", "foot.l", "l_foot", "lfoot", "footl", "left_foot",
	"leftankle", "ankle_l", "ankle.l", "lefttoebase", "left_toe", "toe_l"
]

const FOOT_KEYWORDS_RIGHT: Array[String] = [
	"rightfoot", "foot_r", "foot.r", "r_foot", "rfoot", "footr", "right_foot",
	"rightankle", "ankle_r", "ankle.r", "righttoebase", "right_toe", "toe_r"
]

## Calcula la velocidad natural (en metros por segundo) para una animación específica.
static func calculate_natural_speed(model_root: Node3D, anim_player: AnimationPlayer, anim_name: String, samples: int = SAMPLES_DEFAULT) -> float:
	if model_root == null or anim_player == null or not anim_player.has_animation(anim_name):
		return FALLBACK_SPEED

	var anim: Animation = anim_player.get_animation(anim_name)
	if anim == null or anim.length <= 0.001:
		return FALLBACK_SPEED

	var skeleton: Skeleton3D = _find_skeleton(model_root)
	if skeleton == null or skeleton.get_bone_count() == 0:
		return FALLBACK_SPEED

	var foot_l: int = _find_bone_by_keywords(skeleton, FOOT_KEYWORDS_LEFT, "left", "l")
	var foot_r: int = _find_bone_by_keywords(skeleton, FOOT_KEYWORDS_RIGHT, "right", "r")

	if foot_l == -1 and foot_r == -1:
		return FALLBACK_SPEED

	var chain_l: Array[int] = _build_bone_chain(skeleton, foot_l) if foot_l != -1 else []
	var chain_r: Array[int] = _build_bone_chain(skeleton, foot_r) if foot_r != -1 else []
	var skel_to_root: Transform3D = _get_transform_to_root(skeleton, model_root)

	# Guardar estado original del AnimationPlayer
	var prev_assigned: String = anim_player.current_animation
	var prev_pos: float = anim_player.current_animation_position if anim_player.is_playing() else 0.0
	var prev_speed: float = anim_player.speed_scale

	anim_player.play(anim_name)

	var dt: float = anim.length / float(maxi(samples, 10))
	var min_z_l: float = 999999.0
	var max_z_l: float = -999999.0
	var min_z_r: float = 999999.0
	var max_z_r: float = -999999.0

	for i in range(samples):
		var t: float = i * dt
		anim_player.seek(t, true)

		if not chain_l.is_empty():
			var pos_l: Vector3 = skel_to_root * _eval_fk(skeleton, chain_l).origin
			min_z_l = minf(min_z_l, pos_l.z)
			max_z_l = maxf(max_z_l, pos_l.z)

		if not chain_r.is_empty():
			var pos_r: Vector3 = skel_to_root * _eval_fk(skeleton, chain_r).origin
			min_z_r = minf(min_z_r, pos_r.z)
			max_z_r = maxf(max_z_r, pos_r.z)

	# Restaurar estado previo
	if prev_assigned != "":
		anim_player.play(prev_assigned)
		anim_player.seek(prev_pos, true)
	else:
		anim_player.stop()
	anim_player.speed_scale = prev_speed

	var stride_l: float = (max_z_l - min_z_l) if foot_l != -1 else 0.0
	var stride_r: float = (max_z_r - min_z_r) if foot_r != -1 else 0.0

	var total_distance: float = 0.0
	if foot_l != -1 and foot_r != -1:
		total_distance = stride_l + stride_r
	elif foot_l != -1:
		total_distance = stride_l * 2.0
	elif foot_r != -1:
		total_distance = stride_r * 2.0

	if total_distance <= 0.05:
		return FALLBACK_SPEED

	var speed: float = total_distance / anim.length
	if speed < 0.2 or speed > 30.0:
		return FALLBACK_SPEED

	return speed

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

static func _find_bone_by_keywords(skeleton: Skeleton3D, exact_keywords: Array[String], side_long: String, side_short: String) -> int:
	var count := skeleton.get_bone_count()
	# 1. Coincidencia directa por palabras clave
	for i in range(count):
		var bname := skeleton.get_bone_name(i).to_lower()
		for kw in exact_keywords:
			if kw in bname:
				return i

	# 2. Coincidencia combinada ("foot" o "ankle" + lado)
	for i in range(count):
		var bname := skeleton.get_bone_name(i).to_lower()
		if ("foot" in bname or "ankle" in bname):
			if side_long in bname or bname.ends_with("." + side_short) or bname.ends_with("_" + side_short):
				return i

	return -1

static func _build_bone_chain(skeleton: Skeleton3D, bone_idx: int) -> Array[int]:
	var chain: Array[int] = []
	var curr: int = bone_idx
	while curr != -1:
		chain.append(curr)
		curr = skeleton.get_bone_parent(curr)
	chain.reverse()
	return chain

static func _get_transform_to_root(skeleton: Skeleton3D, model_root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = skeleton
	while curr != null and curr != model_root:
		if curr is Node3D:
			xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

static func _eval_fk(skeleton: Skeleton3D, chain: Array[int]) -> Transform3D:
	var accum := Transform3D.IDENTITY
	for bone_idx in chain:
		accum = accum * skeleton.get_bone_pose(bone_idx)
	return accum
