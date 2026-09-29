class_name EquipmentController
extends Node

## Responsabilidad: Gestiona las 12 ranuras oficiales de equipamiento del personaje (Doll),
## valida reglas de empuñadura (Una Mano vs Dos Manos con desequipamiento seguro a la mochila),
## y suma dinámicamente los atributos de los ítems equipados a las estadísticas (CharacterStats).

signal equipment_changed(slot: ItemData.EquipmentSlot, item: ItemData)

# Mapa de ranuras a ítems equipados
var _equipped_slots: Dictionary = {}

func _init() -> void:
	_init_slots()

func _enter_tree() -> void:
	_init_slots()

func _init_slots() -> void:
	for slot_val in ItemData.EquipmentSlot.values():
		if slot_val != ItemData.EquipmentSlot.NONE:
			if not _equipped_slots.has(slot_val):
				_equipped_slots[slot_val] = null

## Retorna el ítem equipado en una ranura específica
func get_equipped_item(slot: ItemData.EquipmentSlot) -> ItemData:
	return _equipped_slots.get(slot, null)

## Equipa un ítem validando compatibilidad de ranura y reglas de Dos Manos
func equip_item(item: ItemData, target_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE, inventory: InventoryController = null) -> bool:
	if item == null:
		return false

	var slot_to_use := target_slot
	if slot_to_use == ItemData.EquipmentSlot.NONE:
		slot_to_use = _determine_default_slot(item)

	if slot_to_use == ItemData.EquipmentSlot.NONE:
		return false

	# 1. Reglas de Armas a Dos Manos (TwoHanded)
	if item.item_type == ItemData.ItemType.WEAPON:
		if item.grip_type == ItemData.GripType.TWO_HANDED:
			# Si se equipa un arma de 2 manos en MainHand, se debe desequipar OffHand
			var off_hand_item := get_equipped_item(ItemData.EquipmentSlot.OFF_HAND)
			if off_hand_item != null:
				if inventory != null:
					var free_slot := inventory.find_empty_slot()
					if free_slot == -1:
						# Mochila llena: abortar equipamiento para evitar pérdida de ítem
						return false
					# Desequipar OffHand a la mochila
					_equipped_slots[ItemData.EquipmentSlot.OFF_HAND] = null
					inventory.add_item(off_hand_item)
					equipment_changed.emit(ItemData.EquipmentSlot.OFF_HAND, null)
				else:
					return false
			slot_to_use = ItemData.EquipmentSlot.MAIN_HAND

		elif slot_to_use == ItemData.EquipmentSlot.OFF_HAND:
			# No se puede equipar en OffHand si MainHand tiene arma de 2 manos
			var main_item := get_equipped_item(ItemData.EquipmentSlot.MAIN_HAND)
			if main_item != null and main_item.grip_type == ItemData.GripType.TWO_HANDED:
				if inventory != null:
					var free_slot := inventory.find_empty_slot()
					if free_slot == -1:
						return false
					_equipped_slots[ItemData.EquipmentSlot.MAIN_HAND] = null
					inventory.add_item(main_item)
					equipment_changed.emit(ItemData.EquipmentSlot.MAIN_HAND, null)
				else:
					return false

	# 2. Intercambio o colocación
	var previous_item := _equipped_slots.get(slot_to_use, null) as ItemData
	_equipped_slots[slot_to_use] = item
	equipment_changed.emit(slot_to_use, item)

	# Si había una pieza previa y se proporcionó mochila, devolver la previa
	if previous_item != null and inventory != null:
		inventory.add_item(previous_item)

	return true

## Desequipa la pieza en la ranura dada transfiriéndola a la mochila
func unequip_item(slot: ItemData.EquipmentSlot, inventory: InventoryController = null) -> ItemData:
	var item := get_equipped_item(slot)
	if item == null:
		return null

	if inventory != null:
		var free_slot := inventory.find_empty_slot()
		if free_slot == -1:
			return null
		_equipped_slots[slot] = null
		inventory.add_item(item)
		equipment_changed.emit(slot, null)
		return item

	_equipped_slots[slot] = null
	equipment_changed.emit(slot, null)
	return item

## Aplica todos los modificadores de los ítems equipados sobre CharacterStats
func apply_equipment_stats_to(stats: CharacterStats) -> void:
	if stats == null:
		return

	# Resetear bonificaciones derivadas de equipo antes de recomputar
	var bonus_dmg := 0
	var bonus_def := 0
	var bonus_str := 0
	var bonus_agi := 0
	var bonus_int := 0
	var bonus_vit := 0
	var bonus_crit := 0.0
	var bonus_lifesteal := 0.0
	var bonus_stun_chance := 0.0

	for slot_val in _equipped_slots.keys():
		var it: ItemData = _equipped_slots[slot_val]
		if it == null:
			continue

		# Bonificaciones base del ítem
		bonus_dmg += int(it.stats.get("damage", 0))
		bonus_def += int(it.stats.get("defense", 0))
		bonus_str += int(it.stats.get("str", 0))
		bonus_agi += int(it.stats.get("agi", 0))
		bonus_int += int(it.stats.get("int", 0))
		bonus_vit += int(it.stats.get("vit", 0))
		bonus_crit += float(it.stats.get("crit_chance", 0.0))
		bonus_lifesteal += float(it.stats.get("lifesteal", 0.0))
		bonus_stun_chance += float(it.stats.get("stun_chance", 0.0))

		# Bonificación adicional por fortificación
		if it.fortification_level > 0:
			if it.item_type == ItemData.ItemType.WEAPON:
				bonus_dmg += it.fortification_level * 5
			elif it.item_type == ItemData.ItemType.ARMOR:
				bonus_def += it.fortification_level * 3

	# Aplicar a stats
	stats.bonus_str = bonus_str
	stats.bonus_agi = bonus_agi
	stats.bonus_int = bonus_int
	stats.bonus_vit = bonus_vit

	stats.equip_attack = float(bonus_dmg)
	stats.equip_defense = float(bonus_def)
	stats.equip_crit_chance = bonus_crit
	stats.lifesteal_percent = bonus_lifesteal
	stats.stun_chance = bonus_stun_chance

	stats.recalculate_stats(false)

func _determine_default_slot(item: ItemData) -> ItemData.EquipmentSlot:
	if item.equip_slot != ItemData.EquipmentSlot.NONE:
		return item.equip_slot

	match item.item_type:
		ItemData.ItemType.WEAPON:
			return ItemData.EquipmentSlot.MAIN_HAND
		ItemData.ItemType.ARMOR:
			return ItemData.EquipmentSlot.CHEST
		_:
			return ItemData.EquipmentSlot.NONE
