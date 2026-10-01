class_name AggroPool
extends RefCounted

## Responsabilidad: Tabla de amenaza (Aggro Pool / Threat Table) para entidades de combate y mobs.
## Gestiona la lista de agresores hostiles, cuantifica puntos de amenaza por daño o proximidad,
## y determina el objetivo prioritario actual (Top Target) con umbral de histéresis anti-fluctuación.

signal target_switched(new_target: Node3D, old_target: Node3D)
signal aggro_lost()
signal threat_updated(entity: Node3D, new_threat: float, total_threat: float)

var _threat_table: Dictionary = {} # Node3D -> float (threat points)
var _primary_target: Node3D = null
var _switch_threshold: float = 1.10 # Requiere 10% más de amenaza para cambiar de objetivo fijado

## Agrega o incrementa la amenaza generada por una entidad
func add_threat(entity: Node, amount: float) -> void:
	if amount <= 0.0 or entity == null:
		return

	var target_3d := _resolve_target_3d(entity)
	if target_3d == null or not is_target_alive(target_3d):
		return

	var current_val: float = _threat_table.get(target_3d, 0.0)
	var new_val := current_val + amount
	_threat_table[target_3d] = new_val

	threat_updated.emit(target_3d, new_val, get_total_threat())
	_evaluate_primary_target()

## Retorna el objetivo actual con mayor nivel de amenaza
func get_top_target() -> Node3D:
	_cleanup_invalid_targets()
	if _primary_target == null or not is_instance_valid(_primary_target) or not is_target_alive(_primary_target):
		_evaluate_primary_target()
	return _primary_target

## Retorna los puntos de amenaza acumulados por una entidad específica
func get_threat(entity: Node) -> float:
	var target_3d := _resolve_target_3d(entity)
	if target_3d == null:
		return 0.0
	return float(_threat_table.get(target_3d, 0.0))

## Verifica si una entidad se encuentra en la tabla de amenaza
func has_threat(entity: Node) -> bool:
	var target_3d := _resolve_target_3d(entity)
	if target_3d == null:
		return false
	return _threat_table.has(target_3d)

## Remueve una entidad específica de la tabla de amenaza (ej: muerte o escape)
func remove_target(entity: Node) -> void:
	var target_3d := _resolve_target_3d(entity)
	if target_3d != null and _threat_table.has(target_3d):
		_threat_table.erase(target_3d)
		if _primary_target == target_3d:
			_primary_target = null
			_evaluate_primary_target()

## Limpia toda la tabla de amenaza y deselecciona el objetivo
func clear() -> void:
	_threat_table.clear()
	var had_target := (_primary_target != null)
	_primary_target = null
	if had_target:
		aggro_lost.emit()

## Retorna verdadero si no hay agresores en la tabla
func is_empty() -> bool:
	_cleanup_invalid_targets()
	return _threat_table.is_empty()

## Retorna la lista de todos los atacantes registrados
func get_targets() -> Array[Node3D]:
	_cleanup_invalid_targets()
	var result: Array[Node3D] = []
	for k in _threat_table.keys():
		var node := k as Node3D
		if node and is_instance_valid(node):
			result.append(node)
	return result

## Suma total de amenaza en la tabla
func get_total_threat() -> float:
	var total: float = 0.0
	for val in _threat_table.values():
		total += float(val)
	return total

## Aplica decaimiento gradual de amenaza por inactividad
func decay_threat(delta: float, decay_rate: float = 2.0) -> void:
	if _threat_table.is_empty():
		return
	var to_erase: Array[Node3D] = []
	for k in _threat_table.keys():
		var node := k as Node3D
		if node == null or not is_instance_valid(node) or not is_target_alive(node):
			to_erase.append(node)
			continue
		_threat_table[node] = maxf(0.0, _threat_table[node] - (decay_rate * delta))
		if _threat_table[node] <= 0.0:
			to_erase.append(node)

	for node in to_erase:
		_threat_table.erase(node)

	_evaluate_primary_target()

func _evaluate_primary_target() -> void:
	_cleanup_invalid_targets()

	if _threat_table.is_empty():
		if _primary_target != null:
			var prev := _primary_target
			_primary_target = null
			target_switched.emit(null, prev)
			aggro_lost.emit()
		return

	# Buscar la entidad con mayor amenaza
	var best_target: Node3D = null
	var highest_threat: float = -1.0

	for k in _threat_table.keys():
		var node := k as Node3D
		var threat_val: float = float(_threat_table[node])
		if threat_val > highest_threat:
			highest_threat = threat_val
			best_target = node

	if best_target == null:
		return

	# Si no teníamos objetivo previo, asignar directamente
	if _primary_target == null or not is_instance_valid(_primary_target):
		var old := _primary_target
		_primary_target = best_target
		target_switched.emit(_primary_target, old)
		return

	# Si ya teníamos objetivo, aplicar histéresis (necesita 10% más para cambiar)
	if best_target != _primary_target:
		var current_primary_threat: float = float(_threat_table.get(_primary_target, 0.0))
		if highest_threat > (current_primary_threat * _switch_threshold):
			var old := _primary_target
			_primary_target = best_target
			target_switched.emit(_primary_target, old)

func _cleanup_invalid_targets() -> void:
	var to_remove: Array = []
	for k in _threat_table.keys():
		var node: Node = k as Node
		if node == null or not is_instance_valid(node) or not is_target_alive(node):
			to_remove.append(k)

	for bad in to_remove:
		_threat_table.erase(bad)
		if _primary_target == bad:
			_primary_target = null

## Verifica si una entidad sigue viva a través de su CombatTarget
static func is_target_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var ct := node.get_node_or_null("CombatTarget") as CombatTarget
	if ct != null:
		return ct.current_health > 0.0
	if node is CombatTarget:
		return (node as CombatTarget).current_health > 0.0
	return true

static func _resolve_target_3d(entity: Node) -> Node3D:
	if entity is Node3D:
		return entity as Node3D
	if entity != null and entity.get_parent() is Node3D:
		return entity.get_parent() as Node3D
	return null
