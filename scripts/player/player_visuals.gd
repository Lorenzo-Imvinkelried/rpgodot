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
const KEYWORDS_WALK: Array[String] = ["walk"]
const KEYWORDS_RUN: Array[String] = ["run", "sprint", "fast"]
const KEYWORDS_ATTACK: Array[String] = ["slash", "attack", "punch", "strike", "hit"]

const StrideAnalyzerScript = preload("res://scripts/player/stride_analyzer.gd")
const DEFAULT_ATTACK_ANIM = preload("res://resources/combat/anim_attack.res")
const GhostSlashFXScript = preload("res://scripts/combat/ghost_slash_fx.gd")

@onready var health_bar: HealthBar3D = get_node_or_null("HealthBar3D")
@onready var label: Label3D = get_node_or_null("Label3D")
@onready var character_model: Node3D = get_node_or_null("CharacterModel")

var anim_player: AnimationPlayer = null
var _anim_idle: String = ""
var _anim_walk: String = ""
var _anim_run: String = ""
var _anim_attack: String = ""
var _natural_walk_speed: float = 3.5
var _natural_run_speed: float = 6.0
var is_attacking_anim: bool = false

func _ready() -> void:
	_setup_anim_player()
	if character_model:
		GhostSlashFXScript.prewarm(get_tree(), character_model)

func configure_visuals(peer_id: int, is_local: bool) -> void:
	if health_bar:
		if is_local:
			health_bar.set_entity_name("TÚ (ID: %d)" % peer_id, COLOR_LOCAL_LABEL)
		else:
			health_bar.set_entity_name("RIVAL (ID: %d)" % peer_id, COLOR_RIVAL_LABEL)
			_apply_rival_tint()
	elif label:
		if is_local:
			label.text = "TÚ (ID: %d)" % peer_id
			label.modulate = COLOR_LOCAL_LABEL
		else:
			label.text = "RIVAL (ID: %d)" % peer_id
			label.modulate = COLOR_RIVAL_LABEL
			_apply_rival_tint()

	_setup_anim_player()

## Cambia el modelo 3D del personaje y recalcula la velocidad natural de su zancada.
func set_character_model(new_model: Node3D) -> void:
	if character_model and character_model != new_model:
		character_model.queue_free()
	character_model = new_model
	if character_model and not character_model.is_inside_tree():
		add_child(character_model)
	anim_player = null
	_setup_anim_player()

## Calcula el factor de escala de velocidad para que la animación de ataque se complete
## enteramente dentro del intervalo de ataque (1 / attacks_per_second), sin recortarse.
func get_attack_speed_scale(attacks_per_second: float) -> float:
	if anim_player == null:
		_setup_anim_player()
	if anim_player == null or _anim_attack == "":
		return 1.0
	var anim := anim_player.get_animation(_anim_attack)
	if anim == null or anim.length <= 0.001 or attacks_per_second <= 0.001:
		return 1.0
	var anim_length := anim.length
	return maxf(1.0, anim_length * attacks_per_second)

## Reproduce la animación de ataque / golpe ajustada a la velocidad de ataque.
func play_attack(custom_speed_scale: float = 1.0) -> void:
	if anim_player == null or _anim_attack == "":
		return
	is_attacking_anim = true
	anim_player.speed_scale = custom_speed_scale
	anim_player.stop()
	# Adaptar el tiempo de mezcla para ataques rápidos para no recortar el inicio del golpe
	var blend_time: float = clampf(0.08 / custom_speed_scale, 0.01, ANIM_BLEND_TIME)
	anim_player.play(_anim_attack, blend_time)

## Instancia un clon fantasma translúcido que ejecuta un tajo rápido adicional (Multi-Strike)
func spawn_ghost_slash(base_speed_scale: float = 1.0, hit_index: int = 1) -> void:
	if character_model == null:
		return
	GhostSlashFXScript.spawn(character_model, global_transform, hit_index, base_speed_scale, _anim_attack)

## Cancela inmediatamente cualquier animación de ataque y regresa al estado de reposo (Idle).
func stop_attack_and_idle() -> void:
	is_attacking_anim = false
	if anim_player and _anim_idle != "":
		anim_player.speed_scale = 1.0
		anim_player.play(_anim_idle, 0.1)

func update_animation(is_moving: bool, current_speed: float = 0.0) -> void:
	if anim_player == null:
		_setup_anim_player()
		if anim_player == null:
			return

	# Si el jugador se mueve, cancelar el bloqueo de ataque para caminar inmediatamente
	if is_moving:
		is_attacking_anim = false

	# Si se está reproduciendo el golpe, esperar a que termine antes de forzar Idle
	if is_attacking_anim:
		if anim_player.is_playing() and anim_player.current_animation == _anim_attack:
			return
		is_attacking_anim = false

	if not is_moving or absf(current_speed) < 0.05:
		if _anim_idle != "" and anim_player.current_animation != _anim_idle:
			anim_player.play(_anim_idle, ANIM_BLEND_TIME)
		anim_player.speed_scale = 1.0
		return

	# Determinar si corresponde animación de correr o caminar
	var is_backward := current_speed < -0.05
	var abs_speed := absf(current_speed)
	var target_anim: String = ""
	var final_speed_scale: float = 1.0

	if is_backward:
		# Movimiento hacia atrás: caminar en reversa de forma suave y controlada
		target_anim = _anim_walk if _anim_walk != "" else _anim_run
		var ref_speed := 4.2
		var scale_factor := abs_speed / ref_speed
		final_speed_scale = -clampf(scale_factor, 0.85, 1.25)
	elif abs_speed >= 4.5 and _anim_run != "":
		# Desplazamiento rápido hacia adelante (WASD W, Click-to-Move, aproximación de ataque)
		target_anim = _anim_run
		var ref_speed := 6.0
		var scale_factor := abs_speed / ref_speed
		final_speed_scale = clampf(scale_factor, 0.85, 1.25)
	else:
		# Desplazamiento moderado o ralentizado (guardia con escudo, estados alterados)
		target_anim = _anim_walk if _anim_walk != "" else _anim_run
		var ref_speed := 3.5
		var scale_factor := abs_speed / ref_speed
		final_speed_scale = clampf(scale_factor, 0.85, 1.25)

	if target_anim != "" and anim_player.current_animation != target_anim:
		anim_player.play(target_anim, ANIM_BLEND_TIME)

	anim_player.speed_scale = final_speed_scale

func _setup_anim_player() -> void:
	if character_model == null:
		character_model = get_node_or_null("CharacterModel")
	if anim_player == null:
		anim_player = _find_animation_player(self)
		if anim_player:
			anim_player.playback_default_blend_time = ANIM_BLEND_TIME
			var available := anim_player.get_animation_list()
			for anim_name in available:
				var anim := anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
			_anim_idle = _find_best_match(available, KEYWORDS_IDLE, true)
			_anim_walk = _find_best_match(available, KEYWORDS_WALK, false)
			_anim_run = _find_best_match(available, KEYWORDS_RUN, false)
			_anim_attack = _find_best_match(available, KEYWORDS_ATTACK, false)

			# Robustez de fallback entre walk y run
			if _anim_walk == "" and _anim_run != "":
				_anim_walk = _anim_run
			elif _anim_run == "" and _anim_walk != "":
				_anim_run = _anim_walk
			elif _anim_walk == "" and _anim_run == "":
				_anim_walk = _find_best_match(available, ["move", "locomotion"], true)
				_anim_run = _anim_walk

			# Si el modelo no tiene animación de ataque nativa, inyectar el recurso de golpe
			if _anim_attack == "" or _anim_attack == _anim_idle or _anim_attack == _anim_walk:
				if not anim_player.has_animation("attack"):
					var lib: AnimationLibrary = anim_player.get_animation_library("")
					if lib == null:
						lib = AnimationLibrary.new()
						anim_player.add_animation_library("", lib)
					lib.add_animation("attack", DEFAULT_ATTACK_ANIM)
				_anim_attack = "attack"

			# Asegurarse de que el golpe sea un disparo único (sin bucle infinito)
			var attack_res := anim_player.get_animation(_anim_attack)
			if attack_res:
				attack_res.loop_mode = Animation.LOOP_NONE

			# Analizar la zancada del modelo automáticamente
			if character_model:
				if _anim_walk != "":
					_natural_walk_speed = StrideAnalyzerScript.calculate_natural_speed(character_model, anim_player, _anim_walk)
				if _anim_run != "":
					_natural_run_speed = StrideAnalyzerScript.calculate_natural_speed(character_model, anim_player, _anim_run)

			update_animation(false, 0.0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_best_match(anims: PackedStringArray, keywords: Array[String], fallback_to_first: bool = false) -> String:
	for keyword in keywords:
		for anim_name in anims:
			if anim_name.to_lower() == keyword:
				return anim_name
	for keyword in keywords:
		for anim_name in anims:
			if keyword in anim_name.to_lower():
				return anim_name
	return anims[0] if (fallback_to_first and anims.size() > 0) else ""

func _apply_rival_tint() -> void:
	if character_model == null:
		return
	_tint_meshes_recursive(character_model, COLOR_RIVAL_TINT)

func _tint_meshes_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var orig_mat: Material = node.get_active_material(0)
		var mat := StandardMaterial3D.new()
		if orig_mat is BaseMaterial3D and orig_mat.albedo_texture:
			mat.albedo_texture = orig_mat.albedo_texture
			mat.albedo_color = color
		else:
			mat.albedo_color = color
		mat.roughness = 0.5
		node.material_override = mat
	for child in node.get_children():
		_tint_meshes_recursive(child, color)


