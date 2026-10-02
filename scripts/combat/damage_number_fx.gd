class_name DamageNumberFX
extends Node3D

## Responsabilidad: Efecto visual de números de daño flotantes en combate con animación de rebote, elevación y desvanecimiento.
## Muestra estados de impacto: daño normal, crítico, bloqueo o fallo (MISS) en resolución nativa nítida (Layer 2),
## desacoplado del post-procesado retro del mundo 3D.

const COLOR_NORMAL := Color(0.99, 0.88, 0.28, 1.0)
const COLOR_CRIT := Color(1.0, 0.27, 0.2, 1.0)
const COLOR_BLOCKED := Color(0.4, 0.85, 1.0, 1.0)
const COLOR_MISS := Color(0.75, 0.82, 0.9, 0.85)
const OUTLINE_DARK := Color(0.04, 0.05, 0.07, 0.95)

const COLOR_HEAL := Color(0.29, 0.87, 0.5, 1.0) # Verde esmeralda
const COLOR_THORNS := Color(0.98, 0.57, 0.24, 1.0) # Ámbar / Espinas
const COLOR_BLEED := Color(0.96, 0.25, 0.37, 1.0) # Carmesí / Sangrado
const COLOR_STATUS := Color(1.0, 0.84, 0.25, 1.0) # Amarillo / CC

var _label_2d: Label = null
var _is_floating_2d: bool = false
var _pop_multiplier: float = 1.0

func _exit_tree() -> void:
	if _label_2d != null and is_instance_valid(_label_2d):
		_label_2d.queue_free()
		_label_2d = null

func _process(_delta: float) -> void:
	if not _is_floating_2d or _label_2d == null or not is_instance_valid(_label_2d):
		return

	var vp := get_viewport()
	if vp == null:
		_label_2d.visible = false
		return

	var cam := vp.get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		_label_2d.visible = false
		return

	var world_pos := global_position
	if cam.is_position_behind(world_pos):
		_label_2d.visible = false
		return

	var dist := cam.global_position.distance_to(world_pos)
	# Perspectiva 3D real: tamaño decrece con la distancia en lugar de ser estático en pantalla
	var ref_dist := 7.0
	var dist_scale := clampf(ref_dist / maxf(2.0, dist), 0.35, 1.15)
	var final_scale := dist_scale * _pop_multiplier
	_label_2d.scale = Vector2(final_scale, final_scale)
	_label_2d.pivot_offset = _label_2d.size * 0.5

	var screen_pos := cam.unproject_position(world_pos)
	_label_2d.visible = true
	_label_2d.position = screen_pos - (_label_2d.size * 0.5)

## Configura el valor de daño o estado a mostrar y dispara la animación de impacto.
func setup(
	damage: float,
	is_crit: bool = false,
	is_blocked: bool = false,
	is_miss: bool = false,
	is_heal: bool = false,
	is_thorns: bool = false,
	is_bleed: bool = false,
	custom_text: String = ""
) -> void:
	var rounded_dmg := int(round(damage))
	var colors_dict := GameConfig.get_ui_value("damage_numbers", "colors", {}) as Dictionary
	var col_norm := GameConfig.get_color(str(colors_dict.get("normal", "#fde047")), COLOR_NORMAL)
	var col_crit := GameConfig.get_color(str(colors_dict.get("crit", "#ff4533")), COLOR_CRIT)
	var col_blocked := GameConfig.get_color(str(colors_dict.get("blocked", "#67e8f9")), COLOR_BLOCKED)
	var col_miss := GameConfig.get_color(str(colors_dict.get("miss", "#cbd5e1")), COLOR_MISS)
	var col_heal := GameConfig.get_color(str(colors_dict.get("heal", "#4ade80")), COLOR_HEAL)
	var col_thorns := GameConfig.get_color(str(colors_dict.get("thorns", "#fb923c")), COLOR_THORNS)
	var col_bleed := GameConfig.get_color(str(colors_dict.get("bleed", "#f43f5e")), COLOR_BLEED)
	var col_status := GameConfig.get_color(str(colors_dict.get("status", "#facc15")), COLOR_STATUS)

	var fs_norm := int(GameConfig.get_ui_value("damage_numbers", "font_size_normal", 24))
	var fs_crit := int(GameConfig.get_ui_value("damage_numbers", "font_size_crit", 32))

	var display_text := ""
	var target_color := col_norm
	var target_font_size := fs_norm

	if not custom_text.is_empty():
		display_text = custom_text
		target_color = col_status
		target_font_size = fs_crit
	elif is_miss:
		display_text = "FALLO"
		target_color = col_miss
		target_font_size = fs_norm
	elif is_heal:
		display_text = "+%d" % rounded_dmg
		target_color = col_heal
		target_font_size = fs_norm
	elif is_thorns:
		display_text = "%d 🌵" % rounded_dmg
		target_color = col_thorns
		target_font_size = fs_norm
	elif is_bleed:
		display_text = "%d 🩸" % rounded_dmg
		target_color = col_bleed
		target_font_size = fs_norm
	elif is_blocked:
		display_text = "%d 🛡" % rounded_dmg
		target_color = col_blocked
		target_font_size = fs_norm
	elif is_crit:
		display_text = "%d!" % rounded_dmg
		target_color = col_crit
		target_font_size = fs_crit
	else:
		display_text = "%d" % rounded_dmg
		target_color = col_norm
		target_font_size = fs_norm

	_setup_2d_label(display_text, target_color, target_font_size, is_crit)

	var spread_offset := Vector3(
		randf_range(-0.35, 0.35),
		0.0,
		randf_range(-0.35, 0.35)
	)

	var float_dist := float(GameConfig.get_ui_value("damage_numbers", "float_distance_y", 1.0))
	var float_dur := float(GameConfig.get_ui_value("damage_numbers", "float_duration", 0.75))
	var fade_delay := float(GameConfig.get_ui_value("damage_numbers", "fade_delay", 0.47))
	var fade_dur := float(GameConfig.get_ui_value("damage_numbers", "fade_duration", 0.28))

	var target_pos := global_position + spread_offset + Vector3(0.0, float_dist, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)

	# 1. Pop de escala inicial en la etiqueta 2D
	if _label_2d != null:
		var scale_tween := create_tween()
		var start_pop := 1.35 if is_crit else 1.20
		_pop_multiplier = start_pop
		scale_tween.tween_property(self, "_pop_multiplier", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Desplazamiento flotante hacia arriba
	tween.tween_property(self, "global_position", target_pos, float_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Desvanecimiento suave en la fase final
	if _label_2d != null:
		tween.tween_property(_label_2d, "modulate:a", 0.0, fade_dur).set_delay(fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Liberación automática de memoria al terminar
	tween.chain().tween_callback(queue_free)

func _setup_2d_label(display_text: String, text_color: Color, font_size_px: int, is_crit: bool) -> void:
	_label_2d = Label.new()
	_label_2d.text = display_text
	_label_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var settings := LabelSettings.new()
	settings.font_size = font_size_px
	settings.font_color = text_color
	settings.outline_size = 6 if is_crit else 4
	settings.outline_color = OUTLINE_DARK
	settings.shadow_size = 3
	settings.shadow_color = Color(0, 0, 0, 0.6)
	_label_2d.label_settings = settings

	_label_2d.pivot_offset = Vector2(40.0, 15.0)

	var layer := FloatingCombatLayer.get_or_create(get_tree())
	if layer != null:
		layer.add_floating_element(_label_2d)
		_is_floating_2d = true
	else:
		# Contingencia si se instancia sin SceneTree
		add_child(_label_2d)
