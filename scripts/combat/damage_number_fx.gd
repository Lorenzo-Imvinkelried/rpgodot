class_name DamageNumberFX
extends Label3D

## Responsabilidad: Efecto visual de números de daño flotantes en combate 3D con animación de rebote, elevación y desvanecimiento.
## Muestra estados de impacto: daño normal, crítico, bloqueo o fallo (MISS).

const COLOR_NORMAL := Color(0.99, 0.88, 0.28, 1.0)
const COLOR_CRIT := Color(1.0, 0.27, 0.2, 1.0)
const COLOR_BLOCKED := Color(0.4, 0.85, 1.0, 1.0)
const COLOR_MISS := Color(0.75, 0.82, 0.9, 0.85)
const OUTLINE_DARK := Color(0.05, 0.06, 0.08, 0.95)

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 10

	var colors_dict := GameConfig.get_ui_value("damage_numbers", "colors", {}) as Dictionary
	outline_size = int(GameConfig.get_ui_value("damage_numbers", "outline_size", 10))
	outline_modulate = GameConfig.get_color(str(colors_dict.get("outline", "#0d1014")), OUTLINE_DARK)

## Configura el valor de daño o estado a mostrar y dispara la animación de impacto.
func setup(damage: float, is_crit: bool = false, is_blocked: bool = false, is_miss: bool = false) -> void:
	var rounded_dmg := int(round(damage))
	var colors_dict := GameConfig.get_ui_value("damage_numbers", "colors", {}) as Dictionary
	var col_norm := GameConfig.get_color(str(colors_dict.get("normal", "#fde047")), COLOR_NORMAL)
	var col_crit := GameConfig.get_color(str(colors_dict.get("crit", "#ff4533")), COLOR_CRIT)
	var col_blocked := GameConfig.get_color(str(colors_dict.get("blocked", "#67e8f9")), COLOR_BLOCKED)
	var col_miss := GameConfig.get_color(str(colors_dict.get("miss", "#cbd5e1")), COLOR_MISS)

	var fs_norm := int(GameConfig.get_ui_value("damage_numbers", "font_size_normal", 36))
	var fs_crit := int(GameConfig.get_ui_value("damage_numbers", "font_size_crit", 44))

	if is_miss:
		text = "FALLO"
		modulate = col_miss
		font_size = fs_norm
	elif is_blocked:
		text = "%d 🛡" % rounded_dmg
		modulate = col_blocked
		font_size = fs_norm
	elif is_crit:
		text = "%d!" % rounded_dmg
		modulate = col_crit
		font_size = fs_crit
	else:
		text = "%d" % rounded_dmg
		modulate = col_norm
		font_size = fs_norm

	scale = Vector3(0.15, 0.15, 0.15)
	modulate.a = 1.0

	var spread_offset := Vector3(
		randf_range(-0.35, 0.35),
		0.0,
		randf_range(-0.35, 0.35)
	)

	var float_dist := float(GameConfig.get_ui_value("damage_numbers", "float_distance_y", 1.0))
	var float_dur := float(GameConfig.get_ui_value("damage_numbers", "float_duration", 0.75))
	var fade_delay := float(GameConfig.get_ui_value("damage_numbers", "fade_delay", 0.47))
	var fade_dur := float(GameConfig.get_ui_value("damage_numbers", "fade_duration", 0.28))

	var target_pos := position + spread_offset + Vector3(0.0, float_dist, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)

	# 1. Pop de escala inicial
	var scale_tween := create_tween()
	var pop_scale := Vector3(1.4, 1.4, 1.4) if is_crit else Vector3(1.25, 1.25, 1.25)
	scale_tween.tween_property(self, "scale", pop_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Desplazamiento flotante hacia arriba
	tween.tween_property(self, "position", target_pos, float_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Desvanecimiento suave en la fase final
	tween.tween_property(self, "modulate:a", 0.0, fade_dur).set_delay(fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Liberación automática de memoria al terminar
	tween.chain().tween_callback(queue_free)
