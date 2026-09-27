class_name HitFX
extends Node3D

## Responsabilidad: Efecto visual de impacto en combate (chispas, destello y disipación automática).

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	if particles:
		particles.emitting = true
		particles.one_shot = true

	# Destello luminoso de impacto
	if light:
		var tween := create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.25).from(2.5)

	# Auto-destrucción tras finalizar el efecto
	var lifetime := particles.lifetime if particles else 0.4
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)
