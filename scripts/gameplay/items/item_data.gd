class_name ItemData
extends Resource

## Responsabilidad: Definición de datos inmutables y de instancia para cualquier ítem del juego.
## Abarca armas, armaduras, consumibles, gemas y materiales con estadísticas, rarezas,
## niveles de fortificación (+0 a +15), reglas de empuñadura y desglose monetario.

enum ItemType {
	WEAPON,
	ARMOR,
	CONSUMABLE,
	GEM,
	MATERIAL
}

enum ItemRarity {
	COMMON,      # Gris/Blanco
	UNCOMMON,    # Verde
	RARE,        # Azul
	EPIC,        # Naranja
	LEGENDARY,   # Dorado
	MYTHIC,      # Púrpura
	DIVINE       # Rojo intenso
}

enum GripType {
	NONE,
	ONE_HANDED,
	TWO_HANDED
}

enum EquipmentSlot {
	NONE,
	HEAD,
	CAPE,
	CHEST,
	HANDS,
	MAIN_HAND,
	LEGS,
	OFF_HAND,
	RING_1,
	FEET,
	RING_2,
	SUB_WEAPON_1,
	SUB_WEAPON_2
}

const RARITY_COLORS: Dictionary = {
	ItemRarity.COMMON: Color(0.75, 0.75, 0.75, 1.0),
	ItemRarity.UNCOMMON: Color(0.18, 0.80, 0.44, 1.0),
	ItemRarity.RARE: Color(0.20, 0.60, 1.0, 1.0),
	ItemRarity.EPIC: Color(0.95, 0.50, 0.10, 1.0),
	ItemRarity.LEGENDARY: Color(1.0, 0.82, 0.10, 1.0),
	ItemRarity.MYTHIC: Color(0.68, 0.35, 0.90, 1.0),
	ItemRarity.DIVINE: Color(0.95, 0.20, 0.20, 1.0)
}

@export var id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var sub_type: String = ""
@export var rarity: ItemRarity = ItemRarity.COMMON
@export var icon_symbol: String = "📦"
@export var icon_texture: Texture2D = null

@export var level_requirement: int = 1
@export var stack_count: int = 1
@export var max_stack: int = 1
@export var fortification_level: int = 0 # 0 a +15. Si >= +6 emite aura visual

@export var grip_type: GripType = GripType.NONE
@export var equip_slot: EquipmentSlot = EquipmentSlot.NONE

## Diccionario con bonificaciones numéricas (damage, defense, str, agi, int, vit, lifesteal, etc.)
@export var stats: Dictionary = {}

## Efecto consumible (ej. { "hp_restore": 50, "mp_restore": 25 })
@export var consumable_effect: Dictionary = {}

## Valor en monedas de bronce/cobre
@export var gold_value: int = 10

## Retorna si el ítem debe mostrar el aura de fortificación pulsante (Nivel >= +6)
func has_fortification_aura() -> bool:
	return fortification_level >= 6

## Retorna el color correspondiente a la rareza del ítem
func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## Retorna el nombre formateado con el prefijo de fortificación si corresponde (ej. "+7 Espada Larga")
func get_display_name() -> String:
	if fortification_level > 0:
		return "+%d %s" % [fortification_level, item_name]
	return item_name

## Crea una copia profunda de la instancia del ítem para división de pilas y transferencias
func clone() -> ItemData:
	var copy := ItemData.new()
	copy.id = id
	copy.item_name = item_name
	copy.item_type = item_type
	copy.sub_type = sub_type
	copy.rarity = rarity
	copy.icon_symbol = icon_symbol
	copy.icon_texture = icon_texture
	copy.level_requirement = level_requirement
	copy.stack_count = stack_count
	copy.max_stack = max_stack
	copy.fortification_level = fortification_level
	copy.grip_type = grip_type
	copy.equip_slot = equip_slot
	copy.stats = stats.duplicate(true)
	copy.consumable_effect = consumable_effect.duplicate(true)
	copy.gold_value = gold_value
	return copy

## Métodos de fábrica rápidos para prototipado y pruebas
static func create_potion(p_name: String, hp_restore: float, mp_restore: float = 0.0, count: int = 1) -> ItemData:
	var item := ItemData.new()
	item.id = "potion_hp" if hp_restore > 0 else "potion_mp"
	item.item_name = p_name
	item.item_type = ItemType.CONSUMABLE
	item.sub_type = "Poción"
	item.rarity = ItemRarity.COMMON
	item.icon_symbol = "🧪" if hp_restore > 0 else "🍷"
	item.max_stack = 99
	item.stack_count = clamp(count, 1, 99)
	item.consumable_effect = { "hp": hp_restore, "mp": mp_restore }
	item.gold_value = 50
	return item

static func create_weapon(w_name: String, dmg: int, fort: int = 0, rarity: ItemRarity = ItemRarity.UNCOMMON, two_handed: bool = false) -> ItemData:
	var item := ItemData.new()
	item.id = "weapon_" + w_name.to_lower().replace(" ", "_")
	item.item_name = w_name
	item.item_type = ItemType.WEAPON
	item.sub_type = "Espada"
	item.rarity = rarity
	item.icon_symbol = "⚔"
	item.max_stack = 1
	item.stack_count = 1
	item.fortification_level = fort
	item.grip_type = GripType.TWO_HANDED if two_handed else GripType.ONE_HANDED
	item.equip_slot = EquipmentSlot.MAIN_HAND
	item.stats = { "damage": dmg, "str": 5 + fort * 2 }
	item.gold_value = 500 + fort * 200
	return item

static func create_armor(a_name: String, def: int, slot: EquipmentSlot, fort: int = 0, rarity: ItemRarity = ItemRarity.RARE) -> ItemData:
	var item := ItemData.new()
	item.id = "armor_" + a_name.to_lower().replace(" ", "_")
	item.item_name = a_name
	item.item_type = ItemType.ARMOR
	item.sub_type = "Armadura"
	item.rarity = rarity
	item.icon_symbol = "🛡" if slot == EquipmentSlot.OFF_HAND else "🥋"
	item.max_stack = 1
	item.stack_count = 1
	item.fortification_level = fort
	item.grip_type = GripType.ONE_HANDED if slot == EquipmentSlot.OFF_HAND else GripType.NONE
	item.equip_slot = slot
	item.stats = { "defense": def, "vit": 4 + fort * 2 }
	item.gold_value = 400 + fort * 150
	return item
