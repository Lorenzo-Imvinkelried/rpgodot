class_name SkillPowerStrike
extends BaseSkill

## Responsabilidad: Skill 1 (Slot 0 / Tecla 1) - Golpe Potente / Golpe Rápido.
## Ejecuta un golpe básico potenciado con mayor velocidad de ataque (animación acelerada 1.45x)
## y daño incrementado respecto al ataque base, diseñado para encadenarse en rotación de combate.

func _init() -> void:
	id = "golpe_potente"
	name = "Golpe Potente"
	icon = "⚔️"
	key_label = "1"
	slot_index = 0

	mana_cost = 5
	cooldown = 1.8
	cast_time = 0.0 # Instantáneo
	range_distance = 3.5 # Rango melee directo

	flat_damage = 30.0
	damage_multiplier = 1.55 # 55% más fuerte que un impacto normal
	anim_speed_multiplier = 1.45 # Mayor velocidad de ataque que el golpe básico estándar
	threat_multiplier = 1.6 # Mayor generación de amenaza para mantener aggro

## Ejecución especializada con golpe contundente y feedback visual acelerado
func execute(caster: Node3D, target: Node3D, caster_stats: CharacterStats, tree: SceneTree = null) -> Dictionary:
	var result := super.execute(caster, target, caster_stats, tree)

	# Si el caster tiene CombatController, orientarlo suavemente hacia el objetivo
	if caster != null and target != null and is_instance_valid(target):
		var diff := target.global_position - caster.global_position
		diff.y = 0.0
		if diff.length_squared() > 0.01:
			caster.look_at(caster.global_position + diff.normalized(), Vector3.UP)

	return result
