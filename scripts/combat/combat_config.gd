class_name CombatConfig
extends Resource

## Responsabilidad: Parámetros numéricos y estadísticas de combate.
## Desacopla las estadísticas de combate permitiendo editarlas visualmente desde el Inspector.

@export_group("Rangos y Tiempos")
## Rango máximo para iniciar el ataque cuerpo a cuerpo (en metros)
@export_range(0.5, 10.0, 0.1) var attack_range: float = 2.0

## Velocidad de ataque (ataques por segundo). La animación se acelerará proporcionalmente para completarse entera en cada ciclo.
@export_range(0.1, 20.0, 0.1) var attack_speed: float = 0.8


## Retardo desde que inicia la animación hasta que conecta el golpe y sale el FX (en segundos).
## Sincronizado con el momento en que baja la espada en la animación de mandoble (~0.58s).
@export_range(0.05, 3.0, 0.01) var impact_delay: float = 0.58

@export_group("Daño")
## Daño base por golpe
@export_range(1.0, 1000.0, 1.0) var base_damage: float = 25.0

