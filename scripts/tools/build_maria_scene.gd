@tool
extends SceneTree

## Herramienta de utilidad para ensamblar y empaquetar la escena de personaje de Maria
## con sus animaciones extraídas de los FBX del Great Sword Pack.

const StrideAnalyzerScript = preload("res://scripts/player/stride_analyzer.gd")

func _init() -> void:
	print("=== INICIANDO CONSTRUCCIÓN DE SCENE MARIA ===")
	
	var maria_fbx = load("res://assets/models/characters/maria/Maria WProp J J Ong.fbx")
	if maria_fbx == null:
		push_error("No se pudo cargar Maria WProp J J Ong.fbx")
		quit(1)
		return

	var maria_root: Node3D = maria_fbx.instantiate()
	maria_root.name = "CharacterModel"

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	maria_root.add_child(anim_player)

	var anim_lib := AnimationLibrary.new()

	var anim_map: Dictionary = {
		"idle": "res://assets/models/characters/maria/great sword idle.fbx",
		"walk": "res://assets/models/characters/maria/great sword walk.fbx",
		"run": "res://assets/models/characters/maria/great sword run.fbx",
		"slash": "res://assets/models/characters/maria/great sword slash.fbx",
		"attack": "res://assets/models/characters/maria/great sword attack.fbx",
		"impact": "res://assets/models/characters/maria/great sword impact.fbx",
		"death": "res://assets/models/characters/maria/two handed sword death.fbx"
	}

	for anim_name in anim_map:
		var path: String = anim_map[anim_name]
		var fbx_scn = load(path)
		if fbx_scn:
			var fbx_inst = fbx_scn.instantiate()
			var src_anim_player: AnimationPlayer = _find_anim_player(fbx_inst)
			if src_anim_player and src_anim_player.has_animation("mixamo_com"):
				var anim: Animation = src_anim_player.get_animation("mixamo_com").duplicate(true)
				
				# Convertir caminata y carrera con root motion a in-place
				if anim_name in ["walk", "run"]:
					_convert_to_in_place(anim)
				
				# Configurar modo de bucle
				if anim_name in ["idle", "walk", "run"]:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE
				
				anim_lib.add_animation(anim_name, anim)
				print("✔ Animación '%s' agregada (duración: %.2fs, pistas: %d)" % [anim_name, anim.length, anim.get_track_count()])
			else:
				push_warning("No se encontró mixamo_com en: " + path)
			fbx_inst.free()
		else:
			push_error("No se pudo cargar: " + path)

	anim_player.add_animation_library("", anim_lib)

	# Asignar dueño recursivo para que PackedScene guarde todos los nodos
	_set_owner_recursive(maria_root, maria_root)

	DirAccess.make_dir_recursive_absolute("res://scenes/characters")

	var output_path := "res://scenes/characters/maria.tscn"
	var packed := PackedScene.new()
	var pack_err := packed.pack(maria_root)
	if pack_err != OK:
		push_error("Error al empaquetar la escena: %d" % pack_err)
		quit(1)
		return

	var save_err := ResourceSaver.save(packed, output_path)
	if save_err != OK:
		push_error("Error al guardar la escena: %d" % save_err)
		quit(1)
		return

	print("✔ Escena empaquetada y guardada con éxito en: ", output_path)

	# Verificación de carga y cálculo de zancada
	var test_load = load(output_path)
	if test_load:
		var test_inst = test_load.instantiate()
		var ap: AnimationPlayer = test_inst.get_node_or_null("AnimationPlayer")
		if ap:
			print("✔ Verificación: AnimationPlayer cargado con animaciones: ", ap.get_animation_list())
		var speed: float = StrideAnalyzerScript.calculate_natural_speed(test_inst, ap, "walk")
		print("✔ Verificación: Velocidad natural calculada por StrideAnalyzer = %.2f m/s" % speed)
		test_inst.free()

	maria_root.free()
	print("=== CONSTRUCCIÓN COMPLETADA EXITOSAMENTE ===")
	quit()

func _convert_to_in_place(anim: Animation) -> void:
	for t in range(anim.get_track_count()):
		var path_str := String(anim.track_get_path(t))
		if "Hips" in path_str and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var key_count := anim.track_get_key_count(t)
			if key_count > 1:
				var k0: Vector3 = anim.track_get_key_value(t, 0)
				var kend: Vector3 = anim.track_get_key_value(t, key_count - 1)
				var delta_z: float = kend.z - k0.z
				var delta_x: float = kend.x - k0.x
				var length: float = anim.length
				for k in range(key_count):
					var time := anim.track_get_key_time(t, k)
					var val: Vector3 = anim.track_get_key_value(t, k)
					val.z -= (time / length) * delta_z
					val.x -= (time / length) * delta_x
					anim.track_set_key_value(t, k, val)

func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null
