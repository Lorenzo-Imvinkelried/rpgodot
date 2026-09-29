class_name CastBar
extends Control

## Responsabilidad: Barra de casteo y canalización centrada encima de la Hotbar.
## Muestra el progreso de lanzamiento de habilidades activas y feedback visual de interrupción.

signal cast_completed(skill_name: String)
signal cast_interrupted(skill_name: String)

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var skill_label: Label = %SkillLabel

var _current_skill: String = ""
var _cast_duration: float = 0.0
var _cast_elapsed: float = 0.0
var _is_casting: bool = false

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	if not _is_casting:
		return

	_cast_elapsed += delta
	var ratio := clampf(_cast_elapsed / maxf(0.01, _cast_duration), 0.0, 1.0)
	if progress_bar:
		progress_bar.value = ratio * 100.0

	if _cast_elapsed >= _cast_duration:
		_complete_cast()

## Inicia la barra de casteo para una habilidad con la duración dada.
func start_cast(skill_name: String, duration: float) -> void:
	_current_skill = skill_name
	_cast_duration = maxf(0.05, duration)
	_cast_elapsed = 0.0
	_is_casting = true

	if skill_label:
		skill_label.text = _current_skill
	if progress_bar:
		progress_bar.value = 0.0

	show()

## Cancela o interrumpe el casteo activo (ej. al recibir Stun o moverse).
func cancel_cast() -> void:
	if not _is_casting:
		return
	_is_casting = false
	if skill_label:
		skill_label.text = "¡INTERRUMPIDO!"
	cast_interrupted.emit(_current_skill)

	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_callback(func(): hide())

func is_casting() -> bool:
	return _is_casting

func _complete_cast() -> void:
	_is_casting = false
	hide()
	cast_completed.emit(_current_skill)
