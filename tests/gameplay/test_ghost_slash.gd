@tool
extends SceneTree

## Suite de verificación automatizada para GhostSlashFX: Pooling, Prewarm y Recorrido de Espada.

func _init() -> void:
	print("\n--- INICIANDO TEST: GhostSlashFX Pooling & Pre-warm ---")
	_run_tests()

func _run_tests() -> void:
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	if player_scene == null:
		printerr("[FAIL] No se pudo cargar player.tscn")
		quit(1)
		return

	var player := player_scene.instantiate() as Node3D
	root.add_child(player)

	# Esperar a que player._ready() y prewarm() procesen los frames de pre-calentamiento
	await process_frame
	await process_frame
	await process_frame

	var visuals := player.get_node_or_null("Visuals") as PlayerVisuals
	if visuals == null:
		printerr("[FAIL] No se encontró el nodo Visuals")
		quit(1)
		return

	var model := visuals.character_model
	if model == null:
		printerr("[FAIL] No se encontró character_model")
		quit(1)
		return

	var pool := GhostSlashFX._pool
	assert(pool.size() >= 3, "El pool debe tener al menos 3 instancias pre-calentadas")
	print("[OK] Pool verificado con %d instancias pre-calentadas." % pool.size())

	# 2. Verificar que las instancias tienen modelo y AnimationPlayer configurados
	var first_ghost := pool[0]
	assert(first_ghost != null, "La primera instancia debe ser válida")
	assert(first_ghost._clone_model != null, "El clon del modelo debe estar instanciado")
	assert(first_ghost._anim_player != null, "AnimationPlayer debe estar detectado")
	assert(first_ghost._anim_player.has_animation("slash"), "El modelo debe tener animación 'slash'")
	assert(first_ghost._ghost_materials.size() > 0, "Los materiales translúcidos deben estar inicializados")
	print("[OK] Estructura interna del clon verificada (Mesh, AnimationPlayer y Materiales).")

	# 3. Invocar spawn y verificar activación
	var spawned := GhostSlashFX.spawn(model, player.global_transform, 1, 1.5, "slash")
	assert(spawned != null, "spawn() debe retornar una instancia válida del pool")
	assert(spawned == first_ghost, "spawn() debe reutilizar la primera instancia disponible del pool")
	assert(spawned._is_busy == true, "La instancia debe estar marcada como ocupada (_is_busy = true)")
	assert(spawned.visible == true, "La instancia debe estar visible")
	assert(spawned._anim_player.is_playing(), "AnimationPlayer debe estar reproduciendo la animación")
	print("[OK] spawn() activó el clon fantasma sin alocaciones nuevas.")

	# 4. Deactivación y retorno al pool
	spawned._deactivate()
	assert(spawned.visible == false, "El clon debe estar oculto tras desactivarse")
	assert(spawned._is_busy == false, "El clon debe volver a estar disponible (_is_busy = false)")
	print("[OK] Desactivación y reciclaje en pool verificados.")

	# 5. Segundo spawn reutiliza el mismo clon
	var reused := GhostSlashFX.spawn(model, player.global_transform, 2, 1.5, "slash")
	assert(reused == first_ghost, "El segundo spawn debe reutilizar la misma instancia reciclada")
	reused._deactivate()
	print("[OK] Reutilización del clon fantasma verificada.")

	player.queue_free()
	print("--- TEST GhostSlashFX COMPLETADO EXITOSAMENTE (5/5 OK) ---\n")
	quit(0)
