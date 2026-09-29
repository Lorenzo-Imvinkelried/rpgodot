@tool
extends SceneTree

## Suite de verificación automatizada para el Sistema de Inventario / Mochila (Etapa 2).
## Comprueba ItemData, apilado y split de stacks, auras >= +6, uso de consumibles,
## monedero (Oro/Plata/Bronce), DragDropManager, InventoryPanel e integración con GameHUD.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Sistema de Inventario & Mochila (Etapa 2) ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Pruebas de ItemData
	var pot := ItemData.create_potion("Poción Menor", 50.0, 20.0, 10)
	assert(pot.item_type == ItemData.ItemType.CONSUMABLE, "Tipo de ítem incorrecto")
	assert(pot.stack_count == 10, "Cantidad de stack incorrecta")
	assert(pot.max_stack == 99, "Límite de stack de consumible debe ser 99")
	assert(not pot.has_fortification_aura(), "Poción sin fortificación no debe tener aura")

	var sword := ItemData.create_weapon("Espada Épica", 85, 7, ItemData.ItemRarity.EPIC)
	assert(sword.fortification_level == 7, "Nivel de fortificación incorrecto")
	assert(sword.has_fortification_aura(), "Ítem +7 debe emitir aura de fortificación")
	assert(sword.get_display_name() == "+7 Espada Épica", "Nombre mostrado debe incluir prefijo +7")
	assert(sword.get_rarity_color() == ItemData.RARITY_COLORS[ItemData.ItemRarity.EPIC], "Color de rareza épica incorrecto")

	var sword_copy := sword.clone()
	assert(sword_copy.id == sword.id and sword_copy.stats["damage"] == 85, "Copia del ítem debe conservar estadísticas")
	sword_copy.stats["damage"] = 100
	assert(sword.stats["damage"] == 85, "El clon debe ser independiente (copia profunda)")
	print("[OK] Prueba 1: ItemData (Creación, Clonación, Rareza y Aura +7) verificado.")

	# 2. Pruebas de InventoryController
	var inv := InventoryController.new()
	root.add_child(inv)

	# Añadir pociones y verificar apilado
	var p1 := ItemData.create_potion("Poción HP", 50.0, 0.0, 15)
	var p2 := ItemData.create_potion("Poción HP", 50.0, 0.0, 20)
	assert(inv.add_item(p1), "Debe poder agregar p1")
	assert(inv.add_item(p2), "Debe poder agregar p2")
	assert(inv.get_item(0).stack_count == 35, "Las pociones del mismo ID deben apilarse en el mismo slot (35)")

	# Añadir equipo
	assert(inv.add_item(sword), "Debe poder agregar espada")
	assert(inv.get_item(1) == sword, "La espada debe ubicarse en el slot 1")

	# División de Pila (Split Stack)
	var split_pot := inv.split_stack(0)
	assert(split_pot != null, "split_stack debe generar una nueva instancia")
	assert(split_pot.stack_count == 17, "Mitad de 35 es 17 (división entera)")
	assert(inv.get_item(0).stack_count == 18, "Resto en slot original debe ser 18")

	# Intercambio (Swap)
	inv.swap_slots(0, 2)
	assert(inv.get_item(0) == null, "Slot 0 debe quedar vacío tras swap")
	assert(inv.get_item(2) != null and inv.get_item(2).stack_count == 18, "Slot 2 debe contener la poción")

	# Monedero (Currency Breakdown)
	inv.bronze_currency = 54321
	var breakdown := inv.get_currency_breakdown()
	assert(breakdown["gold"] == 5, "Oro debe ser 5 (54321 / 10000)")
	assert(breakdown["silver"] == 43, "Plata debe ser 43 ((54321 % 10000) / 100)")
	assert(breakdown["bronze"] == 21, "Bronce debe ser 21 (54321 % 100)")
	print("[OK] Prueba 2: InventoryController (Apilado, Split, Swap y Monedero) verificado.")

	# 3. Uso de Consumibles
	var dummy_tgt := CombatTarget.new()
	dummy_tgt.target_name = "Player"
	dummy_tgt.max_health = 100.0
	dummy_tgt.current_health = 40.0
	root.add_child(dummy_tgt)

	# Consumir poción en slot 2
	var used := inv.use_consumable_at(2, dummy_tgt)
	assert(used, "Poción debe poder consumirse")
	assert(dummy_tgt.current_health == 90.0, "Salud debe subir de 40 a 90 (+50 HP)")
	assert(inv.get_item(2).stack_count == 17, "El stack debe decrementar a 17 tras uso")
	print("[OK] Prueba 3: Uso de consumibles y restauración de salud verificado.")

	# 4. DragDropManager
	var ddm := DragDropManager.new()
	root.add_child(ddm)

	assert(not ddm.is_dragging, "DragDropManager no debe iniciar arrastrando")
	ddm.start_drag(sword, "inventory", 1, false)
	assert(ddm.is_dragging, "DragDropManager debe estar en estado activo")
	assert(ddm.dragged_item == sword, "Ítem arrastrado debe ser la espada")

	var finished := ddm.finish_drag()
	assert(finished == sword, "finish_drag debe entregar el ítem arrastrado")
	assert(not ddm.is_dragging, "DragDropManager debe retornar a inactivo tras finalizar")
	print("[OK] Prueba 4: DragDropManager (Inicio, Estado de arrastre y Entrega) verificado.")

	# 5. InventoryPanel UI
	var panel_scene := load("res://scenes/ui/inventory/inventory_panel.tscn") as PackedScene
	assert(panel_scene != null, "Escena inventory_panel.tscn debe cargar")
	var inv_panel := panel_scene.instantiate() as InventoryPanel
	root.add_child(inv_panel)
	await process_frame

	inv_panel.bind_inventory(inv, dummy_tgt)
	assert(inv_panel._slot_ui_nodes.size() == 20, "InventoryPanel debe tener exactamente 20 casillas (5x4)")

	assert(not inv_panel.visible, "InventoryPanel debe iniciar oculto")
	inv_panel.toggle_panel()
	assert(inv_panel.visible, "toggle_panel debe abrir el inventario")
	assert(inv_panel.gold_label.text == "5", "Etiqueta de oro debe mostrar 5")
	assert(inv_panel.silver_label.text == "43", "Etiqueta de plata debe mostrar 43")
	assert(inv_panel.bronze_label.text == "21", "Etiqueta de bronce debe mostrar 21")

	inv_panel.hide_panel()
	assert(not inv_panel.visible, "hide_panel debe cerrar la ventana")
	print("[OK] Prueba 5: InventoryPanel UI (20 Slots, Monedero y Toggle) verificado.")

	# 6. Integración en GameHUD
	var hud_scene := load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame

	assert(hud.inventory_panel != null, "GameHUD debe contener InventoryPanel instanciado")
	assert(not hud.inventory_panel.visible, "InventoryPanel en GameHUD debe iniciar cerrado")

	hud._on_inventory_toggle_requested()
	assert(hud.inventory_panel.visible, "Atajo de apertura debe mostrar la mochila")
	hud._on_inventory_toggle_requested()
	assert(not hud.inventory_panel.visible, "Segundo atajo debe cerrar la mochila")
	print("[OK] Prueba 6: Integración de InventoryPanel con GameHUD y toggles verificada.")

	# Limpieza
	hud.queue_free()
	inv_panel.queue_free()
	ddm.queue_free()
	dummy_tgt.queue_free()
	inv.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE INVENTARIO (6/6) PASARON EXITOSAMENTE ---\n")
	quit(0)
