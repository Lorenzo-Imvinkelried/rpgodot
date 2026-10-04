@tool
extends SceneTree

const PlayerScene = preload("res://scenes/player/player.tscn")
const DragonBossScene = preload("res://scenes/enemies/mob_dragon_boss.tscn")
const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")
const GameHudScene = preload("res://scenes/ui/game_hud.tscn")

func _init() -> void:
	print("\n--- TEST: Dragon Boss con AoE y TargetFrame ---")
	_run()

func _run() -> void:
	await process_frame

	var player = PlayerScene.instantiate()
	player.position = Vector3(0.0, 0.0, 75.5)
	root.add_child(player)

	var hud = GameHudScene.instantiate()
	root.add_child(hud)
	hud.bind_player(player)

	# Instanciar Dragon Boss
	var boss = DragonBossScene.instantiate()
	boss.position = Vector3(0.0, 0.0, 78.0)
	root.add_child(boss)

	# Instanciar 2 lobos al lado, uno con vida baja que morirá por el AoE
	var wolf1 = CharacterBody3D.new()
	wolf1.set_script(MobScript)
	wolf1.name = "Wolf1_Dying"
	wolf1.position = Vector3(-2.0, 0.0, 76.0)
	root.add_child(wolf1)

	var wolf2 = CharacterBody3D.new()
	wolf2.set_script(MobScript)
	wolf2.name = "Wolf2_Healthy"
	wolf2.position = Vector3(2.0, 0.0, 76.0)
	root.add_child(wolf2)

	await process_frame
	await process_frame
	await process_frame

	# Wolf 1 con 10 HP para morir en el AoE
	var ct_w1: CombatTarget = wolf1.get_node("CombatTarget")
	ct_w1.stats.max_hp = 10
	ct_w1.stats.current_hp = 10
	ct_w1.max_health = 10.0
	ct_w1.current_health = 10.0

	var combat_ctrl: CombatController = player.get_node("CombatController")
	var skill_ctrl: SkillController = player.get_node("SkillController")
	var tf: TargetFrame = hud.target_frame

	print("1. Iniciar combate atacando al Boss...")
	combat_ctrl.attack_target(boss)
	await process_frame
	hud._process(0.016)

	print("Target en combat_ctrl: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("TargetFrame visible: ", tf.visible)
	print("TargetFrame name: ", tf.name_label.text)
	print("TargetFrame node: ", tf._current_target_node)

	print("\n2. Simular combate continuo: Player ataca al Boss, lobos agroan...")
	wolf1.on_aggroed_by(player)
	wolf2.on_aggroed_by(player)
	boss.on_aggroed_by(player)

	for f in range(10):
		combat_ctrl.update_combat(0.016, player.visuals)
		wolf1._physics_process(0.016)
		wolf2._physics_process(0.016)
		boss._physics_process(0.016)
		await process_frame
		hud._process(0.016)

	print("Durante combate - Target: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("Durante combate - TF visible: ", tf.visible)

	print("\n3. Lanzar Torbellino (AoE slot 8)...")
	var ok = skill_ctrl.activate_slot(8, combat_ctrl.current_target, null, null)
	print("Torbellino ok: ", ok)

	for f in range(20):
		combat_ctrl.update_combat(0.016, player.visuals)
		player._physics_process(0.016)
		wolf1._physics_process(0.016)
		wolf2._physics_process(0.016)
		boss._physics_process(0.016)
		await process_frame
		hud._process(0.016)

	print("Tras Torbellino - Target en combat_ctrl: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("Tras Torbellino - TargetFrame visible: ", tf.visible)
	print("Tras Torbellino - TargetFrame node: ", tf._current_target_node)
	print("Wolf1 is_alive: ", wolf1.is_alive())

	print("\n4. Simular clic en el Boss...")
	player.select_target(boss)
	await process_frame
	hud._process(0.016)
	print("Tras clic - Target en combat_ctrl: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("Tras clic - TargetFrame visible: ", tf.visible)

	print("\n5. Simular Tab...")
	var t1 = combat_ctrl.cycle_target()
	print("cycle_target 1 returned: ", t1.name if t1 else "null")
	await process_frame
	hud._process(0.016)
	print("Tras Tab 1 - Target en combat_ctrl: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("Tras Tab 1 - TargetFrame visible: ", tf.visible)

	var t2 = combat_ctrl.cycle_target()
	print("cycle_target 2 returned: ", t2.name if t2 else "null")
	await process_frame
	hud._process(0.016)
	print("Tras Tab 2 - Target en combat_ctrl: ", combat_ctrl.current_target.name if combat_ctrl.current_target else "null")
	print("Tras Tab 2 - TargetFrame visible: ", tf.visible)

	player.queue_free()
	hud.queue_free()
	boss.queue_free()
	wolf1.queue_free()
	wolf2.queue_free()
	quit(0)
