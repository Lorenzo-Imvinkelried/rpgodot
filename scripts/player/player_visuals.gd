class_name PlayerVisuals
extends Node3D

## Responsabilidad: Gestión exclusiva de la presentación visual y estética del personaje.
## Configura materiales, colores distintivos y cartel identificador sobre la cabeza.

@onready var label: Label3D = $Label3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var visor_mesh: MeshInstance3D = $VisorMesh

func configure_visuals(peer_id: int, is_local: bool) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.roughness = 0.35

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.08, 0.08, 0.08)

	if is_local:
		# Azul para el jugador local
		body_mat.albedo_color = Color(0.18, 0.58, 0.98)
		label.text = "TÚ (ID: %d)" % peer_id
		label.modulate = Color(0.4, 0.85, 1.0)
	else:
		# Naranja para el rival
		body_mat.albedo_color = Color(0.98, 0.42, 0.18)
		label.text = "RIVAL (ID: %d)" % peer_id
		label.modulate = Color(1.0, 0.65, 0.35)

	body_mesh.material_override = body_mat
	visor_mesh.material_override = visor_mat
