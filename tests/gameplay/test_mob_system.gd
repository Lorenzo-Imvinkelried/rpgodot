@tool
extends SceneTree

## Suite de verificación automatizada para el Sistema de Mobs, IA, FSM,
## Leash Estricto, Object Pooling, Respawn con Jitter y Escalado Polinomial.

const MobScript = preload("res://scripts/gameplay/enemies/mob.gd")
const MobSpawnerScript = preload("res://scripts/world/spawning/mob_spawner.gd")
const MobBlueprintScript = preload("res://scripts/gameplay/enemies/mob_blueprint.gd")

func _init() -> void:
	print("\n--- INICIANDO TEST SUITE: Arquitectura de Mobs, IA & Spawn System ---")
	_run_tests()

func _run_tests() -> void:
	# --------------------------------------------------------------------------
	# PRUEBA 1: Modelado de Blueprints y parseo desde JSON (Sección 2)
	# --------------------------------------------------------------------------
	var blueprints: Dictionary = MobBlueprintScript.load_all_blueprints("res://config/gameplay/mobs.json")
	assert(blueprints.has("goblin"), "Debe existir el blueprint 'goblin'")
	assert(blueprints.has("wolf"), "Debe existir el blueprint 'wolf'")
	assert(blueprints.has("dragon_boss"), "Debe existir el blueprint 'dragon_boss'")

	var goblin_bp = blueprints["goblin"]
	assert(goblin_bp.name == "Goblin", "Nombre de blueprint incorrecto")
	assert(goblin_bp.stance == MobBlueprintScript.Stance.NEUTRAL, "Stance de Goblin debe ser Neutral")
	assert(goblin_bp.attack_delay_factor == 0.45, "attack_delay_factor debe ser 0.45")
	assert(goblin_bp.leash_radius > 0.0, "leash_radius debe ser positivo")
	print("[OK] Prueba 1: Carga y parseo de MobBlueprints desde JSON verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 2: Escalado Polinomial de Atributos por Nivel (Sección 9.1 & 11.10)
	# --------------------------------------------------------------------------
	# Para delta_L = 0: Stats deben coincidir con base
	var stats_l1: CharacterStats = goblin_bp.create_character_stats(1)
	assert(stats_l1.max_hp == 80, "HP Nivel 1 debe ser 80 (obtenido: %d)" % stats_l1.max_hp)
	assert(stats_l1.attack == 6, "Atk Nivel 1 debe ser 6 (obtenido: %d)" % stats_l1.attack)

	# Para delta_L = 3 (Nivel 4):
	# HP_mult = 1.0 + 3*0.20 + 9*0.12 = 1.0 + 0.60 + 1.08 = 2.68 -> 80 * 2.68 = 214.4 -> 214
	# Atk_mult = 1.0 + 3*0.12 + 9*0.005 = 1.0 + 0.36 + 0.045 = 1.405 -> 6 * 1.405 = 8.43 -> 8
	var stats_l4: CharacterStats = goblin_bp.create_character_stats(4)
	assert(stats_l4.max_hp == 214, "HP escalado Nivel 4 debe ser 214 (obtenido: %d)" % stats_l4.max_hp)
	assert(stats_l4.attack == 8, "Atk escalado Nivel 4 debe ser 8 (obtenido: %d)" % stats_l4.attack)
	assert(stats_l4.base_str == goblin_bp.strength + 3, "STR escalado debe ser base + delta_L")
	print("[OK] Prueba 2: Fórmulas polinomiales de escalado por nivel validadas matemáticamente.")

	# --------------------------------------------------------------------------
	# PRUEBA 3: Instanciación de Mob y Máquina de Estados FSM (Sección 6)
	# --------------------------------------------------------------------------
	var mob_scene := load("res://scenes/enemies/mob_goblin.tscn") as PackedScene
	assert(mob_scene != null, "La escena mob_goblin.tscn debe existir")

	var mob = mob_scene.instantiate()
	mob.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(mob)
	await process_frame
	await process_frame

	assert(mob.is_alive(), "El mob debe iniciar vivo")
	assert(mob.mCurrentState in [MobScript.State.IDLE, MobScript.State.SPAWNING, MobScript.State.WALKING], "Estado inicial válido")
	print("[OK] Prueba 3: Escena 3D de Mob instanciada con jerarquía completa y FSM lista.")

	# --------------------------------------------------------------------------
	# PRUEBA 4: Percepción de Temperamentos (Stances) y Agro Social (Sección 6.1 & 7)
	# --------------------------------------------------------------------------
	var player_dummy := CharacterBody3D.new()
	player_dummy.name = "PlayerDummy"
	player_dummy.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(player_dummy)

	var p_ct := CombatTarget.new()
	p_ct.name = "CombatTarget"
	p_ct.stats = CharacterStats.create_player_default()
	player_dummy.add_child(p_ct)

	var mob2 = mob_scene.instantiate()
	mob2.position = Vector3(1.0, 0.0, 1.0)
	root.add_child(mob2)
	await process_frame

	# Mob neutral no ataca por proximidad
	assert(mob.mAiDecision == MobScript.AiDecision.IDLE, "Mob neutral no debe entrar en combate por simple proximidad")

	# Al atacar a mob1, este entra en agro y alerta socialmente a mob2 (Pack Call)
	mob.on_aggroed_by(player_dummy, true)
	assert(mob.is_aggro() == true, "mob debe entrar en agro tras ser atacado")
	assert(mob.mAiDecision == MobScript.AiDecision.CHASING, "mob debe entrar en estado de persecución CHASING")
	assert(mob2.is_aggro() == true, "mob2 aliado cercano debe recibir agro social (Pack Call)")
	print("[OK] Prueba 4: Temperamento Neutral y Agro Social (Pack Call) verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 5: Leash Estricto por Distancia al Cuadrado (Sección 6.8 & 11.4)
	# --------------------------------------------------------------------------
	# Alejar al mob más allá del leash_radius (18m)
	mob.global_position = mob.mSpawnPoint + Vector3(25.0, 0.0, 0.0)
	mob._update_ai(0.1)

	assert(mob.is_returning_to_spawn() == true, "dist > leashRadius debe forzar ruptura inmediata y RETURNING")
	assert(mob.mAggroTarget == null, "El objetivo de combate debe desengancharse inmediatamente")
	print("[OK] Prueba 5: Ruptura obligatoria de combate por Leash euclidiano verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 6: Inmunidad Total y Curación Completa al Regresar al Spawn (Sección 6.8 & 11.5)
	# --------------------------------------------------------------------------
	# Dañar al mob mientras regresa
	mob.combat_target.current_health = 10.0
	assert(mob.combat_target.is_invulnerable == true, "El mob retornando debe tener inmunidad total a daño")

	# Simular llegada exacta al SpawnPoint
	mob.global_position = mob.mSpawnPoint
	mob._process_ai_returning(0.1)

	assert(mob.mAiDecision == MobScript.AiDecision.IDLE, "Al llegar al spawn debe pasar a IDLE")
	assert(mob.combat_target.current_health == mob.combat_target.max_health, "Debe curarse al 100% al llegar al spawn")
	assert(mob.combat_target.is_invulnerable == false, "La inmunidad debe desactivarse al restablecerse")
	print("[OK] Prueba 6: Inmunidad total en retorno y curación completa al 100% verificadas.")

	# --------------------------------------------------------------------------
	# PRUEBA 7: Separación de Enjambre (Boids Soft Separation) (Sección 8 & 11.8)
	# --------------------------------------------------------------------------
	mob.global_position = Vector3(0.0, 0.0, 0.0)
	mob2.global_position = Vector3(0.5, 0.0, 0.0) # Muy cercanos (< 1.4m)
	var push_force: Vector3 = mob._calculate_separation_force()

	assert(push_force.length_squared() > 0.01, "Debe generarse una fuerza de repulsión elástica entre mobs cercanos")
	assert(push_force.x < 0.0, "La fuerza debe empujar alejándose de mob2")
	print("[OK] Prueba 7: Fuerza de repulsión Boids Anti-Stacking verificada.")

	# --------------------------------------------------------------------------
	# PRUEBA 8: Hit Delay Factor en Ataques (Sección 6.6 & 11.9)
	# --------------------------------------------------------------------------
	mob.global_position = Vector3(0.0, 0.0, 0.0)
	player_dummy.global_position = Vector3(1.5, 0.0, 0.0) # Dentro de rango de ataque
	mob.mAggroTarget = player_dummy

	var hp_before: float = p_ct.current_health
	mob._execute_attack_sequence()

	assert(mob.mCurrentState == MobScript.State.ATTACKING, "Debe entrar en estado ATTACKING")
	assert(mob._is_damage_pending == true, "El daño debe estar pendiente por Hit Delay Factor")
	assert(p_ct.current_health == hp_before, "El daño NO debe aplicarse en el frame 0")

	# Avanzar el tiempo para que se cumpla el delay del impacto
	mob._process(mob._hit_delay_timer + 0.05)
	assert(mob._is_damage_pending == false, "El daño pendiente debe haberse resuelto")
	assert(p_ct.current_health < hp_before, "La salud del objetivo debe haber disminuido tras el hit delay")
	print("[OK] Prueba 8: Ataque con Hit Delay Factor sincronizado verificado.")

	# --------------------------------------------------------------------------
	# PRUEBA 9: Object Pooling y Reciclaje de Instancias (Sección 5.1 & 11.7)
	# --------------------------------------------------------------------------
	var spawner = MobSpawnerScript.new()
	spawner.name = "MobSpawner"
	root.add_child(spawner)
	await process_frame

	var spawned_mob = spawner.spawn_mob("goblin", Vector3(10.0, 0.0, 10.0), 1, false, false)
	assert(spawned_mob != null, "MobSpawner debe generar una instancia de Mob")
	assert(spawner.get_active_mob_count() >= 1, "Debe registrarse en la lista de activos")

	# Simular muerte y reciclaje
	spawned_mob._on_combat_target_died()
	spawned_mob.mCurrentState = MobScript.State.REMOVABLE
	spawner._cleanup_removable_mobs()

	assert(spawner.get_pooled_mob_count("goblin") >= 1, "El mob debe ser reciclado al Object Pool en vez de destruido")

	# Re-spawnear desde el pool
	var recycled_mob = spawner.spawn_mob("goblin", Vector3(5.0, 0.0, 5.0), 2, false, false)
	assert(recycled_mob == spawned_mob, "El spawner debe reutilizar la misma instancia física del pool")
	assert(recycled_mob.global_position == Vector3(5.0, 0.0, 5.0), "La posición debe haberse actualizado al punto nuevo")
	assert(recycled_mob.combat_target.current_health == recycled_mob.combat_target.max_health, "Salud al 100% tras reset")
	print("[OK] Prueba 9: Object Pooling, ciclo de vida y reciclaje de memoria verificados.")

	# --------------------------------------------------------------------------
	# PRUEBA 10: Tickets de Respawn con Jitter y Culling Bypass (Sección 4 & 5.2)
	# --------------------------------------------------------------------------
	var ticket_count_before: int = spawner.get_pending_respawns_count()
	spawner._on_mob_died(recycled_mob, player_dummy)
	assert(spawner.get_pending_respawns_count() == ticket_count_before + 1, "Debe haberse agendado un RespawnTicket")

	# Culling Bypass: Mobs en combate nunca duermen
	recycled_mob.on_aggroed_by(player_dummy)
	assert(recycled_mob.is_aggro() == true, "Mob debe estar en combate")
	spawner._process_logic_culling(1.0)
	assert(recycled_mob.is_processing() == true, "Bypass de Culling: Mob en combate NUNCA debe suspenderse")
	print("[OK] Prueba 10: Respawn con tickets y regla de oro de bypass de culling verificados.")

	# Limpieza
	mob.queue_free()
	mob2.queue_free()
	player_dummy.queue_free()
	spawner.queue_free()

	print("\n--- TODAS LAS PRUEBAS DE MOBS, IA Y SPAWN (10/10) PASARON EXITOSAMENTE ---\n")
	quit(0)
