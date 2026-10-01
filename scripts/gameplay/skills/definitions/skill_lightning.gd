class_name SkillLightning
extends BaseSkill

## Responsabilidad: Habilidad de descarga eléctrica instantánea a distancia (Slot 3 / Tecla 4).

func _init() -> void:
	id = "relampago"
	name = "Relámpago"
	icon = "⚡"
	key_label = "4"
	slot_index = 3

	mana_cost = 15
	cooldown = 3.0
	cast_time = 0.0 # Instantáneo
	range_distance = 18.0

	flat_damage = 45.0
	damage_multiplier = 1.25
	anim_speed_multiplier = 1.3
	threat_multiplier = 1.2
