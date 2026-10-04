class_name TargetDetector
extends RefCounted

## Responsabilidad: Detección por raycast de entidades atacables bajo el cursor del mouse.

## Realiza un raycast desde la cámara 3D en las coordenadas de pantalla indicadas.
## Retorna el nodo atacable si lo encuentra, o null si no hay objetivo válido.
## Penetra automáticamente a través de cadáveres o entidades no vivas para encontrar objetivos válidos.
static func find_target_at_screen_pos(camera: Camera3D, screen_pos: Vector2, exclude_rids: Array[RID] = []) -> Node3D:
	if camera == null or not camera.is_inside_tree():
		return null

	var space_state := camera.get_world_3d().direct_space_state
	if space_state == null:
		return null

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_dir * 100.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var current_excludes := exclude_rids.duplicate()
	query.collide_with_bodies = true
	query.collide_with_areas = true

	# Bucle de penetración (hasta 5 iteraciones) para atravesar cadáveres o colisionadores no atacables
	for _iter in range(5):
		query.exclude = current_excludes
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return null

		var collider: Object = hit.collider
		if collider is Node:
			var entity := _resolve_target_entity(collider as Node)
			if entity != null:
				return entity

			# Si el objeto alcanzado es el suelo o terreno, detener la búsqueda de objetivo
			var col_node := collider as Node
			if col_node.name == "Floor" or col_node.is_in_group("ground"):
				return null

		if hit.has("rid"):
			current_excludes.append(hit.rid)
		else:
			break

	return null

static func _resolve_target_entity(node: Node) -> Node3D:
	var curr: Node = node
	while curr != null and not (curr is Viewport):
		var candidate: Node3D = null
		if curr.is_in_group("targetable"):
			if curr is CombatTarget:
				candidate = curr.get_parent() as Node3D
			else:
				candidate = curr as Node3D
		elif curr.has_node("CombatTarget"):
			candidate = curr as Node3D
		elif curr is CharacterBody3D and curr.name != "Floor":
			candidate = curr as Node3D

		if candidate != null:
			# Validar estrictamente que el objetivo esté vivo y activo para combate
			if CombatController.is_target_alive(candidate):
				return candidate
			return null # Si es una entidad muerta/fading, descartarla para permitir penetración

		curr = curr.get_parent()

	return null
