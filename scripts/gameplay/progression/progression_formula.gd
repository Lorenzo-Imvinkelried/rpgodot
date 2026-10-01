class_name ProgressionFormula
extends RefCounted

## Responsabilidad: Fórmulas matemáticas puras de progresión de nivel y experiencia.
## Determina la curva de experiencia requerida por nivel y los incrementos de atributos por subida de nivel.

const DEFAULT_BASE_XP: float = 250.0
const DEFAULT_EXPONENT: float = 1.35
const DEFAULT_LINEAR_OFFSET: float = 50.0

## Calcula la experiencia requerida para avanzar desde `level` hacia `level + 1`.
## Utiliza una curva polinomial suave: Base * (Nivel ^ Exponente) + (Offset * Nivel).
static func get_xp_required_for_level(level: int) -> int:
	var base_xp: float = float(GameConfig.get_combat_value("progression", "base_xp", DEFAULT_BASE_XP))
	var exponent: float = float(GameConfig.get_combat_value("progression", "xp_exponent", DEFAULT_EXPONENT))
	var offset: float = float(GameConfig.get_combat_value("progression", "xp_linear_offset", DEFAULT_LINEAR_OFFSET))

	var lvl := maxi(1, level)
	var req := base_xp * pow(float(lvl), exponent) + (offset * float(lvl))
	return maxi(50, int(round(req)))

## Retorna el incremento de atributos primarios base al subir a `new_level`.
## Atributos por defecto: +2 STR, +2 AGI, +2 INT, +3 VIT.
static func get_stat_gains(new_level: int) -> Dictionary:
	var gains_cfg: Dictionary = GameConfig.get_combat_value("progression", "stat_gains_per_level", {}) as Dictionary
	return {
		"base_str": int(gains_cfg.get("base_str", 2)),
		"base_agi": int(gains_cfg.get("base_agi", 2)),
		"base_int": int(gains_cfg.get("base_int", 2)),
		"base_vit": int(gains_cfg.get("base_vit", 3))
	}
