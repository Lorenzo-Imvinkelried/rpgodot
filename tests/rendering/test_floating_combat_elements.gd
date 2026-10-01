@tool
extends SceneTree

## Suite de verificación automatizada para Elementos Flotantes de Combate (Layer 2 - Nítidos sin Pixelación Retro).
## Valida que barras de vida, nombres y números de daño operen en FloatingCombatLayer (Layer 2),
## desacoplados del post-procesado retro (Layer 1) y por debajo del HUD principal (Layer 10).

const FloatingCombatLayerScript = preload("res://scripts/combat/floating_combat_layer.gd")
const HealthBar3DScript = preload("res://scripts/combat/health_bar_3d.gd")
const DamageNumberFXScript = preload("res://scripts/combat/damage_number_fx.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Elementos Flotantes de Combate en HD (Layer 2) ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: FloatingCombatLayer en Layer 2 y Contenedor No Oclusivo
	# --------------------------------------------------------------------------
	var layer := FloatingCombatLayerScript.new()
	root.add_child(layer)
	await process_frame

	assert(layer.layer == 2, "FloatingCombatLayer debe operar en Layer 2 (sobre Retro Layer 1)")
	assert(layer.overlay_container != null, "OverlayContainer debe estar inicializado")
	assert(layer.overlay_container.mouse_filter == Control.MOUSE_FILTER_IGNORE, "OverlayContainer no debe interceptar clics del ratón")
	assert(FloatingCombatLayerScript.get_or_create(self) == layer, "get_or_create debe retornar la instancia activa")
	print("[OK] Prueba 1: FloatingCombatLayer activo en Layer 2 con contenedor MOUSE_FILTER_IGNORE.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: HealthBar3D proyecta UI a Layer 2 desacoplada del 3D
	# --------------------------------------------------------------------------
	var hbar_scene := load("res://scenes/combat/health_bar_3d.tscn") as PackedScene
	assert(hbar_scene != null, "health_bar_3d.tscn debe existir")

	var dummy_entity := Node3D.new()
	var hbar: HealthBar3D = hbar_scene.instantiate()
	var combat_tgt := CombatTarget.new()
	combat_tgt.target_name = "Orco Guerrero"
	combat_tgt.max_health = 250.0
	combat_tgt.current_health = 250.0

	dummy_entity.add_child(combat_tgt)
	dummy_entity.add_child(hbar)
	root.add_child(dummy_entity)
	await process_frame

	assert(hbar._is_floating_2d == true, "HealthBar3D debe activar modo flotante 2D en Layer 2")
	assert(hbar.sprite_3d.visible == false, "Sprite3D debe ocultarse en modo 2D para evitar doble renderizado y pixelación 3D")
	assert(hbar._ui_container != null, "UIContainer debe estar referenciado")
	assert(hbar._ui_container.get_parent() == layer.overlay_container, "UIContainer debe residir en FloatingCombatLayer (Layer 2)")
	assert(hbar._ui_container.mouse_filter == Control.MOUSE_FILTER_IGNORE, "UIContainer debe tener mouse_filter IGNORE")
	assert(hbar.name_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "NameLabel no debe interceptar clics")
	assert(hbar.health_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HealthBar no debe interceptar clics")
	print("[OK] Prueba 2: HealthBar3D reparentada a FloatingCombatLayer en Layer 2 con clics transparentes.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Funcionalidades de Barra de Vida y Nombres en Alta Definición
	# --------------------------------------------------------------------------
	hbar.set_entity_name("Jefe Goblin", Color(1.0, 0.4, 0.4))
	assert(hbar.name_label.text == "Jefe Goblin", "El texto del nombre debe actualizarse")
	assert(hbar.name_label.get_theme_color("font_color") == Color(1.0, 0.4, 0.4), "El color del nombre debe actualizarse")

	hbar.set_health(125.0, 250.0, false)
	assert(hbar.health_bar.value == 125.0, "La barra de vida debe reflejar 125 HP")
	assert(hbar.value_label.text == "125 / 250", "El texto numérico de vida debe ser '125 / 250'")
	print("[OK] Prueba 3: Actualizaciones de nombre, color y salud reflejadas en UI nítida.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: DamageNumberFX en Layer 2 con Formato Nítido
	# --------------------------------------------------------------------------
	var dmg_fx_scene := load("res://scenes/combat/damage_number_fx.tscn") as PackedScene
	assert(dmg_fx_scene != null, "damage_number_fx.tscn debe existir")

	var dmg_fx: DamageNumberFX = dmg_fx_scene.instantiate()
	root.add_child(dmg_fx)
	dmg_fx.global_position = Vector3(0.0, 2.0, 0.0)
	dmg_fx.setup(75.0, true, false, false, false, false, false, "")

	assert(dmg_fx._is_floating_2d == true, "DamageNumberFX debe operar en modo 2D Layer 2")
	assert(dmg_fx._label_2d != null, "Etiqueta 2D de daño debe estar instanciada")
	assert(dmg_fx._label_2d.text == "75!", "Texto de daño crítico debe mostrar '75!'")
	assert(dmg_fx._label_2d.get_parent() == layer.overlay_container, "Etiqueta de daño debe residir en FloatingCombatLayer")
	assert(dmg_fx._label_2d.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Etiqueta de daño debe ser traspasable por clics")
	print("[OK] Prueba 4: DamageNumberFX instanciado en Layer 2 con estilo crítico y sin pixelación.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Jerarquía Completa en main.tscn (Layer 0 -> Layer 1 -> Layer 2 -> Layer 10)
	# --------------------------------------------------------------------------
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main_instance: Main = main_scene.instantiate()
	root.add_child(main_instance)
	await process_frame

	var retro_node: CanvasLayer = main_instance.get_node_or_null("RetroPostProcess")
	var floating_node: CanvasLayer = main_instance.get_node_or_null("FloatingCombatLayer")
	var ui_node: CanvasLayer = main_instance.get_node_or_null("UI")

	assert(retro_node != null, "RetroPostProcess debe existir en Main")
	assert(floating_node != null, "FloatingCombatLayer debe existir en Main")
	assert(ui_node != null, "UI debe existir en Main")

	assert(retro_node.layer == 1, "RetroPostProcess debe estar en Layer 1")
	assert(floating_node.layer == 2, "FloatingCombatLayer debe estar en Layer 2")
	assert(ui_node.layer == 10, "UI debe estar en Layer 10")

	assert(retro_node.layer < floating_node.layer, "FloatingCombatLayer DEBE dibujarse después de RetroPostProcess")
	assert(floating_node.layer < ui_node.layer, "UI principal DEBE dibujarse sobre FloatingCombatLayer")
	print("[OK] Prueba 5: Orden estricto de capas validado: 3D (L0) -> Retro (L1) -> Combate Flotante HD (L2) -> HUD (L10).")

	# Limpieza
	dmg_fx.queue_free()
	dummy_entity.queue_free()
	layer.queue_free()
	main_instance.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE ELEMENTOS FLOTANTES PASARON EXITOSAMENTE (5/5) ---\n")
	quit(0)
