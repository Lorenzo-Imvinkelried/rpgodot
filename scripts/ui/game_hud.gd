class_name GameHUD
extends Control

## Responsabilidad: Contenedor principal de la interfaz de usuario en juego (HUD).
## Integra PlayerFrame, TargetFrame, Hotbar, CastBar, ExpBar, QuickButtons y panel de red.
## Sincroniza automáticamente la UI con el jugador local y su objetivo actual.

signal disconnect_requested

@onready var player_frame: PlayerFrame = %PlayerFrame
@onready var target_frame: TargetFrame = %TargetFrame
@onready var hotbar: Hotbar = %Hotbar
@onready var cast_bar: CastBar = %CastBar
@onready var exp_bar: ExpBar = %ExpBar
@onready var quick_buttons: QuickButtons = %QuickButtons
@onready var status_label: Label = %HUDStatus
@onready var disconnect_button: Button = %DisconnectButton

var _bound_player: Node = null
var _last_synced_target: Node = null

func _ready() -> void:
	if disconnect_button:
		disconnect_button.pressed.connect(_on_disconnect_pressed)

func _process(_delta: float) -> void:
	if _bound_player == null:
		_try_auto_bind_player()
	else:
		_sync_target()

## Vincula explícitamente el HUD al nodo del jugador local.
func bind_player(player_node: Node) -> void:
	_bound_player = player_node
	if _bound_player == null:
		return

	if player_frame:
		player_frame.bind_player(_bound_player)
	if hotbar:
		hotbar.bind_player(_bound_player)

	var target_comp := _bound_player.get_node_or_null("CombatTarget") as CombatTarget
	if target_comp:
		var stats := target_comp.get_stats()
		if stats and exp_bar:
			exp_bar.set_experience(0, 1000)

## Intenta localizar y vincular automáticamente al jugador local si aún no está asignado.
func _try_auto_bind_player() -> void:
	var players_container := get_tree().root.find_child("Players", true, false)
	if players_container:
		for child in players_container.get_children():
			if child is CharacterBody3D:
				var is_local := true
				if child.has_method("is_multiplayer_authority"):
					is_local = child.is_multiplayer_authority()
				if is_local:
					bind_player(child)
					break

## Sincroniza el TargetFrame cuando el jugador selecciona, cambia o pierde su objetivo de combate.
func _sync_target() -> void:
	if _bound_player == null:
		return

	var combat_ctrl := _bound_player.get_node_or_null("CombatController") as CombatController
	if combat_ctrl == null:
		return

	var current_tgt: Node3D = combat_ctrl.current_target
	if current_tgt != _last_synced_target:
		_last_synced_target = current_tgt
		if target_frame:
			if is_instance_valid(current_tgt):
				target_frame.set_target(current_tgt)
			else:
				target_frame.clear_target()

## Actualiza el texto informativo del estado de red.
func update_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _on_disconnect_pressed() -> void:
	disconnect_requested.emit()
