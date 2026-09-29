class_name ItemTooltip
extends PanelContainer

## Responsabilidad: Ventana flotante informativa para inspección de ítems y comparación de stats.
## Se posiciona inteligentemente según las coordenadas del ratón evitando salirse de la pantalla.

@onready var title_label: Label = %TitleLabel
@onready var type_label: Label = %TypeLabel
@onready var level_label: Label = %LevelLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var value_label: Label = %ValueLabel

func _ready() -> void:
	hide()
	mouse_filter = MOUSE_FILTER_IGNORE

## Configura y despliega el contenido de un ítem
func display_item(item: ItemData, global_mouse_pos: Vector2) -> void:
	if item == null:
		hide()
		return

	# 1. Título y Color de Rareza
	if title_label:
		title_label.text = item.get_display_name()
		title_label.add_theme_color_override("font_color", item.get_rarity_color())

	# 2. Subtipo y Empuñadura
	if type_label:
		var type_str := ""
		match item.item_type:
			ItemData.ItemType.WEAPON:
				var grip := "2 Manos" if item.grip_type == ItemData.GripType.TWO_HANDED else "1 Mano"
				type_str = "Arma (%s) - %s" % [grip, item.sub_type]
			ItemData.ItemType.ARMOR:
				type_str = "Armadura - %s" % item.sub_type
			ItemData.ItemType.CONSUMABLE:
				type_str = "Consumible - %s" % item.sub_type
			ItemData.ItemType.GEM:
				type_str = "Gema / Piedra de Engarce"
			_:
				type_str = "Material"
		type_label.text = type_str

	# 3. Nivel Requerido
	if level_label:
		level_label.text = "Nivel Requerido: %d" % item.level_requirement

	# 4. Estadísticas
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()

		# Estadísticas de Equipo
		for stat_name in item.stats.keys():
			var val = item.stats[stat_name]
			var lbl := Label.new()
			lbl.mouse_filter = MOUSE_FILTER_IGNORE
			lbl.add_theme_font_size_override("font_size", 11)

			var stat_display: String = str(stat_name).capitalize()
			if str(stat_name) == "damage":
				stat_display = "Daño Físico"
			elif stat_name == "defense":
				stat_display = "Defensa"

			lbl.text = "• %s: +%s" % [stat_display, str(val)]
			stats_container.add_child(lbl)

		# Efectos consumibles
		for eff_key in item.consumable_effect.keys():
			var eff_val = item.consumable_effect[eff_key]
			if float(eff_val) > 0.0:
				var eff_lbl := Label.new()
				eff_lbl.mouse_filter = MOUSE_FILTER_IGNORE
				eff_lbl.add_theme_font_size_override("font_size", 11)
				eff_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
				eff_lbl.text = "• Restaura: +%s %s" % [str(eff_val), eff_key.to_upper()]
				stats_container.add_child(eff_lbl)

	# 5. Valor Monetario
	if value_label:
		var g := item.gold_value / 10000
		var s := (item.gold_value % 10000) / 100
		var b := item.gold_value % 100
		value_label.text = "Valor: %d Oro  %d Plata  %d Bronce" % [g, s, b]

	show()
	_update_smart_position(global_mouse_pos)

func _update_smart_position(mouse_pos: Vector2) -> void:
	reset_size()
	var vp_size := get_viewport_rect().size
	var tooltip_size := size

	var target_x := mouse_pos.x + 14.0
	var target_y := mouse_pos.y + 14.0

	# Clamping horizontal (desplegar a la izquierda si no cabe a la derecha)
	if target_x + tooltip_size.x > vp_size.x - 10.0:
		target_x = mouse_pos.x - tooltip_size.x - 14.0

	# Clamping vertical (desplegar hacia arriba si no cabe abajo)
	if target_y + tooltip_size.y > vp_size.y - 10.0:
		target_y = mouse_pos.y - tooltip_size.y - 14.0

	global_position = Vector2(maxf(10.0, target_x), maxf(10.0, target_y))
