class_name ExpBar
extends Control

## Responsabilidad: Barra de experiencia horizontal centrada en la base inferior.
## Muestra experiencia acumulada, experiencia requerida y porcentaje con formato "X / Y (Z%)".

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var exp_label: Label = %ExpLabel

var current_exp: int = 0
var max_exp: int = 1000

func _ready() -> void:
	set_experience(current_exp, max_exp)

## Actualiza el progreso de la barra y el texto formateado.
func set_experience(current: int, max_val: int) -> void:
	current_exp = maxi(0, current)
	max_exp = maxi(1, max_val)

	var ratio: float = clampf(float(current_exp) / float(max_exp), 0.0, 1.0)
	var percent: float = ratio * 100.0

	if progress_bar:
		progress_bar.max_value = max_exp
		progress_bar.value = current_exp

	if exp_label:
		exp_label.text = "%d / %d (%.1f%%)" % [current_exp, max_exp, percent]
