@tool
extends SceneTree

## Suite de verificación para el Mapa Ampliado (200x200m) y Generación de Grupos de Mobs.

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Mapa Ampliado & Grupos de Mobs en Main ---")
	_run_tests()

func _run_tests() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null, "La escena main.tscn debe compilar y cargar correctamente")

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 1. Verificación del mapa ampliado (200x200m)
	var floor_node := main.find_child("Floor", true, false) as StaticBody3D
	assert(floor_node != null, "El nodo Floor debe existir en el entorno")
	var col_shape := floor_node.get_node("CollisionShape3D") as CollisionShape3D
	assert(col_shape != null and col_shape.shape is BoxShape3D, "CollisionShape3D de Floor debe ser BoxShape3D")
	var box := col_shape.shape as BoxShape3D
	assert(box.size.x >= 200.0 and box.size.z >= 200.0, "Las dimensiones del mapa deben ser de al menos 200x200m (obtenido: %s)" % str(box.size))
	print("[OK] Prueba 1: Mapa ampliado a 200x200m con colisiones y límites verificado.")

	# 2. Verificación de MobSpawner en Main
	var spawner := main.find_child("MobSpawner", true, false)
	assert(spawner != null, "MobSpawner debe estar presente como nodo en Main")
	var active_count: int = spawner.get_active_mob_count()
	assert(active_count >= 25, "Deben haberse generado múltiples grupos de mobs en el mundo (obtenido: %d)" % active_count)
	print("[OK] Prueba 2: MobSpawner activo en Main con %d entidades generadas." % active_count)

	# 3. Verificación de arquetipos: Goblins, Lobos y Dragón Boss
	var has_goblin: bool = false
	var has_wolf: bool = false
	var has_dragon_boss: bool = false

	for child in spawner.get_children():
		if child is CharacterBody3D and "blueprint_type" in child:
			if child.blueprint_type == "goblin":
				has_goblin = true
			elif child.blueprint_type == "wolf":
				has_wolf = true
			elif child.blueprint_type == "dragon_boss":
				has_dragon_boss = true
				assert(child.is_boss == true, "El Dragón debe tener el flag is_boss activo")
				assert(child.combat_target.max_health >= 1500.0, "La vida del Dragón Boss debe ser de jefe (>=1500)")

	assert(has_goblin, "Debe existir al menos un grupo de Goblins en el mundo")
	assert(has_wolf, "Debe existir al menos una manada de Lobos en el mundo")
	assert(has_dragon_boss, "Debe existir el Gran Dragón Boss en la arena del norte")
	print("[OK] Prueba 3: Grupos de Goblins, Manadas de Lobos y Gran Dragón Boss verificados.")

	# 4. Verificación de distribución espacial de campamentos
	var mobs_in_west: int = 0
	var mobs_in_east: int = 0
	var mobs_in_south: int = 0
	var mobs_in_north: int = 0

	for child in spawner.get_children():
		if child is CharacterBody3D and "mSpawnPoint" in child:
			var p: Vector3 = child.mSpawnPoint
			if p.x < -20.0:
				mobs_in_west += 1
			elif p.x > 20.0:
				mobs_in_east += 1
			elif p.z < -20.0:
				mobs_in_south += 1
			elif p.z > 40.0:
				mobs_in_north += 1

	assert(mobs_in_west >= 5, "El campamento del Oeste debe tener mobs (obtenido: %d)" % mobs_in_west)
	assert(mobs_in_east >= 5, "La guarida del Este debe tener lobos (obtenido: %d)" % mobs_in_east)
	assert(mobs_in_south >= 5, "Las ruinas del Sur deben tener mobs (obtenido: %d)" % mobs_in_south)
	assert(mobs_in_north >= 5, "La arena del Norte debe tener guardianes y boss (obtenido: %d)" % mobs_in_north)
	print("[OK] Prueba 4: Distribución espacial por cuadrantes (Oeste: %d, Este: %d, Sur: %d, Norte: %d) verificada." % [mobs_in_west, mobs_in_east, mobs_in_south, mobs_in_north])

	main.queue_free()
	print("\n--- TODAS LAS PRUEBAS DE MAPA Y GRUPOS DE MOBS PASARON EXITOSAMENTE (4/4) ---\n")
	quit(0)
