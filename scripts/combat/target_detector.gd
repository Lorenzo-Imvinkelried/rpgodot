class_name TargetDetector
extends RefCounted

## Responsabilidad: Detección por raycast de entidades atacables bajo el cursor del mouse.

## Realiza un raycast desde la cámara 3D en las coordenadas de pantalla indicadas.
## Retorna el nodo atacable si lo encuentra, o null si no hay objetivo válido.
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
	query.exclude = exclude_rids
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider: Object = hit.collider
	if collider is Node:
		return _resolve_target_entity(collider as Node)

	return null

static func _resolve_target_entity(node: Node) -> Node3D:
	# 1. Si el propio nodo o algún ancestro/hijo tiene CombatTarget
	var curr: Node = node
	while curr != null and not (curr is Viewport):
		if curr.is_in_group("targetable"):
			return curr as Node3D
		for child in curr.get_children():
			if child is CombatTarget:
				return curr as Node3D
		curr = curr.get_parent()

	# 2. Si es otro CharacterBody3D (ej. otro jugador o enemigo)
	if node is CharacterBody3D:
		return node as Node3D

	return null
