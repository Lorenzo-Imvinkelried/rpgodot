@tool
extends SceneTree

## Suite de verificación automatizada para el sistema Click-to-Move, Rombo Marcado en el suelo
## e inspección de Tooltip compacto desacoplado.

const GroundMarkerScript = preload("res://scripts/player/ground_marker.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Click-to-Move & Ground Marker & Tooltip Sizing ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Verificación del componente GroundMarker (Rombo Marcado)
	var marker_scene := load("res://scenes/player/ground_marker.tscn") as PackedScene
	assert(marker_scene != null, "scenes/player/ground_marker.tscn debe cargar")

	var marker: Node3D = marker_scene.instantiate()
	root.add_child(marker)
	await process_frame
	assert(marker.top_level, "GroundMarker debe tener top_level = true")
	assert(not marker.visible, "GroundMarker debe iniciar oculto")

	marker.show_at(Vector3(5.0, 0.0, 10.0))
	assert(marker.visible, "GroundMarker.show_at debe hacerlo visible")
	assert(is_equal_approx(marker.global_position.x, 5.0), "Posición X del rombo incorrecta")
	assert(is_equal_approx(marker.global_position.z, 10.0), "Posición Z del rombo incorrecta")

	marker.fade_out()
	marker.queue_free()
	print("[OK] Prueba 1: GroundMarker (Carga de escena, top_level, show_at, fade_out) verificado.")

	# 2. Verificación de Player e inicio de Click-to-Move
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_scene != null, "scenes/player/player.tscn debe cargar")

	var player := player_scene.instantiate() as Player
	player.name = "1"
	root.add_child(player)

	await process_frame
	await process_frame

	assert(not player.has_click_move(), "Player debe iniciar sin click-to-move activo")

	var destination := Vector3(10.0, 0.0, 0.0)
	player.move_to_ground_position(destination)
	assert(player.has_click_move(), "move_to_ground_position debe activar has_click_move")
	assert(player.get_click_move_target() == destination, "Target de click-to-move incorrecto")
	print("[OK] Prueba 2: Activación de Click-to-Move en Player verificado.")

	# 3. Cancelación de combate al hacer clic en el suelo
	var dummy := Node3D.new()
	var ct := CombatTarget.new()
	ct.name = "CombatTarget"
	dummy.add_child(ct)
	root.add_child(dummy)

	player.set_combat_target(dummy)
	assert(not player.has_click_move(), "Asignar combat target debe limpiar click-to-move previo")
	assert(player.combat_controller.is_active(), "CombatController debe estar activo al asignar target")

	# Clic en el suelo: debe cancelar el combate inmediatamente y comenzar a caminar hacia allí
	player.move_to_ground_position(Vector3(-5.0, 0.0, 5.0))
	assert(player.has_click_move(), "Debe activar click-to-move hacia el nuevo destino")
	assert(not player.combat_controller.is_active(), "Clic en el suelo DEBE cancelar el combate activo inmediatamente")
	print("[OK] Prueba 3: Clic en el suelo cancela el ataque/combate activo inmediatamente.")

	# 4. Desplazamiento por física y llegada a destino
	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.move_to_ground_position(Vector3(2.0, 0.0, 0.0))

	# Simular un frame de física: debe avanzar hacia la coordenada
	player._process_movement(0.1)
	assert(player.is_moving, "Player debe marcar is_moving = true al avanzar por click-to-move")
	assert(player.velocity.x > 0.0, "Velocidad X debe ser positiva apuntando al destino")

	# Simular llegada al destino (colocando la posición dentro del rango de frenado arrival_dist = 0.35)
	player.global_position = Vector3(1.95, 0.0, 0.0)
	player._process_movement(0.1)
	assert(not player.has_click_move(), "Al llegar al destino debe limpiarse click-to-move")
	assert(not player.is_moving, "Al llegar al destino debe frenar")
	assert(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z), "Velocidad horizontal debe ser 0 al llegar")
	print("[OK] Prueba 4: Navegación física, detección de llegada y frenado verificado.")

	# 5. Cancelación de Click-to-Move con input manual (clear_click_move)
	player.move_to_ground_position(Vector3(20.0, 0.0, 20.0))
	assert(player.has_click_move(), "Debe iniciar navegación a destino lejano")
	player.clear_click_move()
	assert(not player.has_click_move(), "clear_click_move debe cancelar la navegación")
	print("[OK] Prueba 5: Interrupción y limpieza de click-to-move verificado.")

	# 6. Verificación de Tooltip compacto con top_level = true
	var tt_scene := load("res://scenes/ui/item_tooltip.tscn") as PackedScene
	assert(tt_scene != null, "scenes/ui/item_tooltip.tscn debe cargar")

	var tooltip: Control = tt_scene.instantiate()
	root.add_child(tooltip)
	assert(tooltip.top_level, "ItemTooltip debe tener top_level = true para no expandirse al área del panel")

	var test_sword := ItemData.create_weapon("Espada Probeta", 50, 5, ItemData.ItemRarity.EPIC)
	tooltip.display_item(test_sword, Vector2(100, 100))

	assert(tooltip.visible, "display_item debe hacer visible el tooltip")
	assert(tooltip.size.x < 250.0, "Ancho del tooltip debe ser compacto (< 250px), valor actual: %f" % tooltip.size.x)
	assert(tooltip.size.y < 220.0, "Alto del tooltip debe ser compacto (< 220px), valor actual: %f" % tooltip.size.y)
	assert(tooltip.global_position.x >= 100.0, "Posición X del tooltip debe acompañar al ratón")

	tooltip.hide()
	tooltip.queue_free()
	print("[OK] Prueba 6: ItemTooltip (top_level = true, dimensiones compactas) verificado exitosamente.")

	dummy.queue_free()
	player.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE CLICK-TO-MOVE Y TOOLTIP PASARON EXITOSAMENTE (6/6) ---\n")
	quit(0)
