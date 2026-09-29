class_name InventoryController
extends Node

## Responsabilidad: Gestiona el estado de la mochila del jugador (20 slots = 5 columnas x 4 filas),
## adición y remoción atómica de ítems, apilado de consumibles (hasta 99), división de stacks (Shift+Drag),
## uso de pociones y monedero (Oro / Plata / Bronce).

signal item_changed(slot_index: int, item: ItemData)
signal gold_changed(total_bronze: int)
signal inventory_full()

@export var max_slots: int = 20 # 5x4 estándar
@export var bronze_currency: int = 54321 # Ejemplo: 5 Oro, 43 Plata, 21 Bronce

var _slots: Array[ItemData] = []

func _init() -> void:
	_init_slots()

func _enter_tree() -> void:
	_init_slots()

func _init_slots() -> void:
	if _slots.size() != max_slots:
		_slots.resize(max_slots)
		for i in range(max_slots):
			_slots[i] = null

## Retorna el ítem en la posición dada o null
func get_item(slot_index: int) -> ItemData:
	if slot_index >= 0 and slot_index < _slots.size():
		return _slots[slot_index]
	return null

## Busca el primer slot desocupado (-1 si está lleno)
func find_empty_slot() -> int:
	for i in range(_slots.size()):
		if _slots[i] == null:
			return i
	return -1

## Añade un ítem gestionando automáticamente apilado de consumibles
func add_item(item: ItemData) -> bool:
	if item == null:
		return false

	# 1. Si es apilable (stackable), intentar consolidar en stacks existentes
	if item.max_stack > 1:
		for i in range(_slots.size()):
			var existing := _slots[i]
			if existing != null and existing.id == item.id and existing.stack_count < existing.max_stack:
				var space: int = existing.max_stack - existing.stack_count
				var to_add: int = mini(space, item.stack_count)
				existing.stack_count += to_add
				item.stack_count -= to_add
				item_changed.emit(i, existing)
				if item.stack_count <= 0:
					return true

	# 2. Si aún quedan unidades o no es apilable, buscar slot vacío
	while item.stack_count > 0:
		var empty_idx := find_empty_slot()
		if empty_idx == -1:
			inventory_full.emit()
			return false

		if item.stack_count <= item.max_stack:
			_slots[empty_idx] = item
			item_changed.emit(empty_idx, item)
			return true
		else:
			# Partir en stack completo y seguir con el remanente
			var chunk := item.clone()
			chunk.stack_count = item.max_stack
			item.stack_count -= item.max_stack
			_slots[empty_idx] = chunk
			item_changed.emit(empty_idx, chunk)

	return true

## Asigna directamente un ítem en un slot
func set_item(slot_index: int, item: ItemData) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index] = item
		item_changed.emit(slot_index, item)

## Remueve o reduce cantidad de un slot
func remove_item_at(slot_index: int, count: int = 1) -> ItemData:
	var item := get_item(slot_index)
	if item == null:
		return null

	if item.stack_count <= count:
		_slots[slot_index] = null
		item_changed.emit(slot_index, null)
		return item
	else:
		item.stack_count -= count
		item_changed.emit(slot_index, item)
		var removed := item.clone()
		removed.stack_count = count
		return removed

## Intercambia dos casillas o fusiona consumibles si tienen el mismo ID
func swap_slots(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= _slots.size() or to_idx < 0 or to_idx >= _slots.size():
		return
	if from_idx == to_idx:
		return

	var from_item := _slots[from_idx]
	var to_item := _slots[to_idx]

	# Si ambos son consumibles del mismo tipo, fusionar pilas
	if from_item and to_item and from_item.id == to_item.id and to_item.max_stack > 1:
		var space := to_item.max_stack - to_item.stack_count
		if space > 0:
			var to_add := mini(space, from_item.stack_count)
			to_item.stack_count += to_add
			from_item.stack_count -= to_add
			if from_item.stack_count <= 0:
				_slots[from_idx] = null
			item_changed.emit(from_idx, _slots[from_idx])
			item_changed.emit(to_idx, to_item)
			return

	# Intercambio simple (Swap)
	_slots[from_idx] = to_item
	_slots[to_idx] = from_item
	item_changed.emit(from_idx, to_item)
	item_changed.emit(to_idx, from_item)

## Divide una pila a la mitad para arrastre con Shift presionado
func split_stack(slot_index: int) -> ItemData:
	var item := get_item(slot_index)
	if item == null or item.stack_count <= 1:
		return null

	var half: int = item.stack_count / 2
	item.stack_count -= half
	item_changed.emit(slot_index, item)

	var split_item := item.clone()
	split_item.stack_count = half
	return split_item

## Consume una poción restaurando salud y maná al CombatTarget
func use_consumable_at(slot_index: int, target: CombatTarget) -> bool:
	var item := get_item(slot_index)
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE:
		return false

	var hp_heal: float = float(item.consumable_effect.get("hp", 0.0))
	var mp_heal: float = float(item.consumable_effect.get("mp", 0.0))

	if target:
		if hp_heal > 0.0:
			target.current_health = minf(target.max_health, target.current_health + hp_heal)
			target.health_changed.emit(target.current_health, target.max_health)
		if mp_heal > 0.0 and target.stats != null:
			target.stats.current_mp = mini(target.stats.max_mp, target.stats.current_mp + int(mp_heal))
			target.health_changed.emit(target.current_health, target.max_health)

	remove_item_at(slot_index, 1)
	return true

## Gestión de Monedero
func add_currency(bronze: int) -> void:
	bronze_currency = maxi(0, bronze_currency + bronze)
	gold_changed.emit(bronze_currency)

func get_currency_breakdown() -> Dictionary:
	var gold := bronze_currency / 10000
	var silver := (bronze_currency % 10000) / 100
	var bronze := bronze_currency % 100
	return { "gold": gold, "silver": silver, "bronze": bronze }
