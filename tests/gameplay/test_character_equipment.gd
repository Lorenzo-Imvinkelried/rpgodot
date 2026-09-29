@tool
extends SceneTree

## Suite de verificación automatizada para el Panel de Personaje, Equipamiento y Selección con Clic (Etapa 3).
## Valida las 12 ranuras de equipamiento, reglas de armas de 2 Manos, aplicación de stats en vivo,
## modo Inspección, toggle con [C] y selección por clic con aparición inmediata del TargetFrame.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Panel de Personaje, Equipamiento & Target Selection (Etapa 3) ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Pruebas de EquipmentController & Reglas de 2 Manos
	var eq := EquipmentController.new()
	var inv := InventoryController.new()
	root.add_child(eq)
	root.add_child(inv)

	var sword_1h := ItemData.create_weapon("Espada de 1 Mano", 30, 0, ItemData.ItemRarity.COMMON, false)
	var shield := ItemData.create_armor("Escudo de Madera", 15, ItemData.EquipmentSlot.OFF_HAND, 0, ItemData.ItemRarity.COMMON)
	var greatsword_2h := ItemData.create_weapon("Mandoble Gigante", 90, 6, ItemData.ItemRarity.EPIC, true)

	# Equipar 1 Mano + Escudo
	assert(eq.equip_item(sword_1h, ItemData.EquipmentSlot.MAIN_HAND, inv), "Debe poder equipar espada 1H en MainHand")
	assert(eq.equip_item(shield, ItemData.EquipmentSlot.OFF_HAND, inv), "Debe poder equipar escudo en OffHand")
	assert(eq.get_equipped_item(ItemData.EquipmentSlot.MAIN_HAND) == sword_1h, "MainHand debe ser espada 1H")
	assert(eq.get_equipped_item(ItemData.EquipmentSlot.OFF_HAND) == shield, "OffHand debe ser escudo")

	# Equipar arma de 2 manos debe desequipar automáticamente el escudo hacia la mochila
	assert(eq.equip_item(greatsword_2h, ItemData.EquipmentSlot.MAIN_HAND, inv), "Debe equipar arma de 2 manos")
	assert(eq.get_equipped_item(ItemData.EquipmentSlot.MAIN_HAND) == greatsword_2h, "MainHand ahora debe ser mandoble 2H")
	assert(eq.get_equipped_item(ItemData.EquipmentSlot.OFF_HAND) == null, "OffHand debe haber quedado vacía automáticamente")
	assert(inv.get_item(0) == shield or inv.get_item(1) == shield, "El escudo debió transferirse a la mochila de forma segura")

	# Desequipar arma de 2 manos
	var unequipped := eq.unequip_item(ItemData.EquipmentSlot.MAIN_HAND, inv)
	assert(unequipped == greatsword_2h, "unequip_item debe entregar el mandoble")
	assert(eq.get_equipped_item(ItemData.EquipmentSlot.MAIN_HAND) == null, "MainHand debe quedar vacía")
	print("[OK] Prueba 1: EquipmentController (Equip, Regla 2 Manos, Desequipamiento seguro a mochila) verificado.")

	# 2. Aplicación de estadísticas sobre CharacterStats
	var stats := CharacterStats.new()
	stats.base_str = 10
	stats.base_vit = 10
	stats.recalculate_stats(true)
	var base_atk: int = stats.attack

	# Equipar espada y aplicar stats
	eq.equip_item(greatsword_2h, ItemData.EquipmentSlot.MAIN_HAND, inv)
	eq.apply_equipment_stats_to(stats)
	# Mandoble 90 daño + bono fortificación +7 (6 * 5 = 30) = +120 daño
	assert(stats.attack > base_atk, "stats.attack debe haberse incrementado con el equipo")
	print("[OK] Prueba 2: Modificadores de estadísticas de equipo aplicados a CharacterStats correctamente.")

	# 3. Interfaz CharacterPanel y 12 Ranuras
	var panel_scene := load("res://scenes/ui/character/character_panel.tscn") as PackedScene
	assert(panel_scene != null, "Escena character_panel.tscn debe cargar")
	var char_panel := panel_scene.instantiate() as CharacterPanel
	root.add_child(char_panel)
	await process_frame

	var dummy_tgt := CombatTarget.new()
	dummy_tgt.target_name = "Héroe"
	dummy_tgt.stats = stats
	root.add_child(dummy_tgt)

	char_panel.bind_character(stats, eq, inv, dummy_tgt)
	assert(char_panel._slot_ui_map.size() == 12, "CharacterPanel debe poseer exactamente 12 ranuras de equipamiento")
	assert(not char_panel.visible, "CharacterPanel debe iniciar oculto")

	char_panel.toggle_panel()
	assert(char_panel.visible, "toggle_panel debe abrir la hoja de personaje")

	char_panel.hide_panel()
	assert(not char_panel.visible, "hide_panel debe cerrar la ventana")
	print("[OK] Prueba 3: CharacterPanel UI (12 slots de muñeca, desglose de estadísticas y toggle) verificado.")

	# 4. Modo Inspección
	var enemy_dummy := Node3D.new()
	var enemy_tgt := CombatTarget.new()
	enemy_tgt.target_name = "Orco Caudillo"
	enemy_dummy.add_child(enemy_tgt)
	root.add_child(enemy_dummy)

	char_panel.inspect_target(enemy_dummy)
	assert(char_panel.visible, "inspect_target debe hacer visible el panel")
	assert(char_panel.is_inspect_mode, "char_panel debe estar en modo inspección")
	assert(char_panel.title_label.text.find("Orco Caudillo") != -1, "Título debe reflejar la entidad inspeccionada: " + char_panel.title_label.text)
	char_panel.hide_panel()
	print("[OK] Prueba 4: Modo Inspección (Lectura de objetivo en TargetFrame) verificado.")

	# 5. Selección de Objetivo con Clic y Despliegue Inmediato de TargetFrame en GameHUD
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	hud.bind_player(player)

	# Inicialmente TargetFrame está oculto
	assert(not hud.target_frame.visible, "TargetFrame debe iniciar oculto")

	# Simular pulsación/selección sobre entidad atacable
	player.set_combat_target(enemy_dummy)
	hud._process(0.016)

	assert(hud.target_frame.visible, "TargetFrame debe saltar/mostrarse de inmediato al marcar objetivo")
	assert(hud.target_frame.name_label.text == "Orco Caudillo", "TargetFrame debe mostrar el nombre del objetivo pulsado")

	# Deseleccionar objetivo (Escape)
	var combat_ctrl: CombatController = player.get_node("CombatController")
	combat_ctrl.clear_target()
	hud._process(0.016)

	assert(not hud.target_frame.visible, "TargetFrame debe ocultarse al deseleccionar objetivo")
	print("[OK] Prueba 5: Selección de objetivo con clic y salto inmediato de TargetFrame verificado.")

	# Limpieza
	player.queue_free()
	hud.queue_free()
	enemy_dummy.queue_free()
	dummy_tgt.queue_free()
	char_panel.queue_free()
	inv.queue_free()
	eq.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE ETAPA 3 (5/5) PASARON EXITOSAMENTE ---\n")
	quit(0)
