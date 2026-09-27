@tool
extends SceneTree

func _init() -> void:
	print("--- VERIFYING PLAYER WITH MARIA MODEL ---")
	var player_scn = load("res://scenes/player/player.tscn")
	if player_scn == null:
		push_error("Error loading player.tscn")
		quit(1)
		return

	var root = Node3D.new()
	get_root().add_child(root)

	var player = player_scn.instantiate()
	root.add_child(player)

	print("Player instantiated successfully!")
	var visuals: PlayerVisuals = player.get_node_or_null("Visuals")
	if visuals:
		print("Visuals found: ", visuals.name)
		for c in visuals.get_children():
			print("  Visual child: ", c.name, " (", c.get_class(), ")")
			for cc in c.get_children():
				print("    Subchild: ", cc.name, " (", cc.get_class(), ")")
		visuals._setup_anim_player()
		print("Anim player after _setup_anim_player: ", visuals.anim_player != null)


		if visuals.anim_player:
			print("Anim list: ", visuals.anim_player.get_animation_list())
			print("Active anim: ", visuals.anim_player.current_animation)
			print("Walk anim detected: ", visuals._anim_walk)
			print("Idle anim detected: ", visuals._anim_idle)
			print("Attack anim detected: ", visuals._anim_attack)
			print("Natural walk speed: ", visuals._natural_walk_speed)

		print("\nTesting play_attack()...")
		visuals.play_attack()
		print("Playing anim: ", visuals.anim_player.current_animation)
		print("Is attacking anim flag: ", visuals.is_attacking_anim)

		print("\nTesting update_animation(is_moving=true)...")
		visuals.update_animation(true, 4.0)
		print("Playing anim after movement interrupt: ", visuals.anim_player.current_animation)
		print("Anim speed scale: ", visuals.anim_player.speed_scale)

	player.queue_free()
	root.queue_free()
	print("--- TEST COMPLETED SUCCESSFULLY ---")
	quit()
