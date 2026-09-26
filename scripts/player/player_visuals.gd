class_name PlayerVisuals
extends Node3D

## Responsabilidad: Gestión visual del modelo 3D, animación (Idle/Walk) y estética.

# Paleta de colores para identificación en red
const COLOR_LOCAL_LABEL := Color(0.4, 0.85, 1.0)
const COLOR_RIVAL_LABEL := Color(1.0, 0.65, 0.35)
const COLOR_RIVAL_TINT := Color(1.0, 0.65, 0.45)

# Configuración de animaciones y transiciones
const ANIM_BLEND_TIME: float = 0.25
const KEYWORDS_IDLE: Array[String] = ["idle", "stand"]
const KEYWORDS_WALK: Array[String] = ["walk", "run", "move"]

@onready var label: Label3D = $Label3D
@onready var character_model: Node3D = get_node_or_null("CharacterModel")

var anim_player: AnimationPlayer = null
var _anim_idle: String = ""
var _anim_walk: String = ""

func _ready() -> void:
	_setup_anim_player()

func configure_visuals(peer_id: int, is_local: bool) -> void:
	if is_local:
		label.text = "TÚ (ID: %d)" % peer_id
		label.modulate = COLOR_LOCAL_LABEL
	else:
		label.text = "RIVAL (ID: %d)" % peer_id
		label.modulate = COLOR_RIVAL_LABEL
		_apply_rival_tint()

	_setup_anim_player()

func update_animation(is_moving: bool) -> void:
	if anim_player == null:
		_setup_anim_player()
		if anim_player == null:
			return

	var target_anim := _anim_walk if is_moving else _anim_idle
	if target_anim != "" and anim_player.current_animation != target_anim:
		anim_player.play(target_anim)

func _setup_anim_player() -> void:
	if anim_player == null:
		anim_player = _find_animation_player(self)
		if anim_player:
			anim_player.playback_default_blend_time = ANIM_BLEND_TIME
			var available := anim_player.get_animation_list()
			for anim_name in available:
				var anim := anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
			_anim_idle = _find_best_match(available, KEYWORDS_IDLE)
			_anim_walk = _find_best_match(available, KEYWORDS_WALK)
			update_animation(false)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_best_match(anims: PackedStringArray, keywords: Array[String]) -> String:
	for keyword in keywords:
		for anim_name in anims:
			if anim_name.to_lower() == keyword:
				return anim_name
	for keyword in keywords:
		for anim_name in anims:
			if keyword in anim_name.to_lower():
				return anim_name
	return anims[0] if anims.size() > 0 else ""

func _apply_rival_tint() -> void:
	if character_model == null:
		return
	_tint_meshes_recursive(character_model, COLOR_RIVAL_TINT)

func _tint_meshes_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.4
		node.material_override = mat
	for child in node.get_children():
		_tint_meshes_recursive(child, color)
