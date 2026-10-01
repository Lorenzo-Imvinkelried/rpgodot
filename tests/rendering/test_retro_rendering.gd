@tool
extends SceneTree

## Suite de verificación automatizada para el Sistema de Renderizado Retro 3D (Layer 1 + UI Layer 10).

const RetroPostProcessScript = preload("res://scripts/rendering/retro_post_process.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Renderizado Retro Pixelado (3D Pixel Art & UI Nítida) ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Instanciación de RetroPostProcess y Parámetros por Defecto
	# --------------------------------------------------------------------------
	var retro := RetroPostProcessScript.new()
	root.add_child(retro)
	await process_frame

	assert(retro.layer == 1, "RetroPostProcess debe operar estrictamente en Layer 1 (inmediatamente sobre el 3D)")
	assert(retro._color_rect != null, "ColorRect de pantalla completa debe estar instanciado")
	assert(retro._material != null, "ShaderMaterial de post-procesado debe estar instanciado")
	assert(retro._color_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ColorRect no debe interceptar clics del ratón ni raycasts")
	print("[OK] Prueba 1: Componente RetroPostProcess instanciado en Layer 1 con Quad no oclusivo.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Carga de Configuración desde retro_config.json
	# --------------------------------------------------------------------------
	assert(retro.retro_enabled == true, "Por defecto la estética retro debe estar activa")
	assert(retro.target_vertical_res >= 144.0, "Resolución vertical objetivo debe ser válida (obtenido: %.1f)" % retro.target_vertical_res)
	assert(retro.pixel_scale >= 1.0, "Escala de píxeles debe ser >= 1.0 (obtenido: %.1f)" % retro.pixel_scale)
	print("[OK] Prueba 2: Configuración externa leída correctamente (Target Res: %.0fp, Pixel Scale: %.0fx)." % [retro.target_vertical_res, retro.pixel_scale])

	# --------------------------------------------------------------------------
	# PRUEBA 3: Alternancia Dinámica (Toggle Retro) y Actualización de Shader
	# --------------------------------------------------------------------------
	var initial_state := retro.retro_enabled
	retro.toggle_retro()
	assert(retro.retro_enabled != initial_state, "toggle_retro debe invertir el estado")
	assert(retro._material.get_shader_parameter("enabled") == retro.retro_enabled, "El shader debe sincronizarse con retro_enabled")

	retro.toggle_retro()
	assert(retro.retro_enabled == initial_state, "Segundo toggle debe restaurar el estado original")
	print("[OK] Prueba 3: Alternancia dinámica en caliente (Toggle Retro / F10) verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Configuración de Parámetros en Tiempo Real
	# --------------------------------------------------------------------------
	retro.set_target_vertical_res(180.0)
	assert(retro.target_vertical_res == 180.0, "set_target_vertical_res debe actualizar el valor")
	assert(retro._material.get_shader_parameter("target_height") == 180.0, "Shader debe recibir 180.0")

	retro.set_pixel_scale(6.0)
	assert(retro.pixel_scale == 6.0, "set_pixel_scale debe actualizar el valor")
	assert(retro._material.get_shader_parameter("pixel_size") == 6.0, "Shader debe recibir 6.0")

	retro.set_enable_dither(true)
	assert(retro.enable_dither == true, "enable_dither debe ser true")
	assert(retro._material.get_shader_parameter("enable_dither") == true, "Shader debe tener dithering activo")
	print("[OK] Prueba 4: Actualización en vivo de resolución retro, escala y dithering verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Integración en Main Scene y Preservación de UI en Layer 10
	# --------------------------------------------------------------------------
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null, "main.tscn debe existir")

	var main_instance: Main = main_scene.instantiate()
	root.add_child(main_instance)
	await process_frame

	var main_retro: RetroPostProcess = main_instance.get_node_or_null("RetroPostProcess")
	assert(main_retro != null, "Main debe contener el nodo RetroPostProcess")
	assert(main_retro.layer == 1, "RetroPostProcess en Main debe tener layer = 1")

	var ui_layer: CanvasLayer = main_instance.get_node_or_null("UI")
	assert(ui_layer != null, "Main debe contener el CanvasLayer 'UI'")
	assert(ui_layer.layer == 10, "El CanvasLayer 'UI' debe estar en layer = 10 (estrictamente superior a Layer 1)")

	var hud: GameHUD = main_instance.game_hud
	assert(hud != null, "GameHUD debe estar resuelto en Main")
	assert(hud.get_parent() == ui_layer, "GameHUD DEBE estar dentro del CanvasLayer UI (Layer 10) para no ser pixelado")
	print("[OK] Prueba 5: Jerarquía de Main validada (3D en Layer 0 -> Retro en Layer 1 -> UI nítida en Layer 10).")

	# Limpieza
	retro.queue_free()
	main_instance.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE RENDERIZADO RETRO PASARON EXITOSAMENTE (5/5) ---\n")
	quit(0)
