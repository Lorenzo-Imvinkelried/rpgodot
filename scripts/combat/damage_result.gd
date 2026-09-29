class_name DamageResult
extends RefCounted

## Responsabilidad: Contenedor inmutable de datos que describe el resultado de un cálculo de combate.

var total_damage: int = 0
var physical_damage: int = 0
var true_damage: int = 0
var is_crit: bool = false
var is_blocked: bool = false
var is_miss: bool = false

func _to_string() -> String:
	return "[DamageResult: total=%d (phys=%d, true=%d) crit=%s blocked=%s miss=%s]" % [
		total_damage, physical_damage, true_damage,
		str(is_crit), str(is_blocked), str(is_miss)
	]
