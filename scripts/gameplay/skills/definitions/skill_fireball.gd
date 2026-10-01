class_name SkillFireball
extends BaseSkill

## Responsabilidad: Habilidad de orbe ígneo con tiempo de casteo y alto impacto (Slot 4 / Tecla 5).

func _init() -> void:
	id = "fuego"
	name = "Bola de Fuego"
	icon = "🔥"
	key_label = "5"
	slot_index = 4

	mana_cost = 25
	cooldown = 4.5
	cast_time = 1.0 # Canalizado con CastBar
	range_distance = 18.0

	flat_damage = 75.0
	damage_multiplier = 1.5
	anim_speed_multiplier = 1.2
	threat_multiplier = 1.4
