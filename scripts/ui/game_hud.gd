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
@onready var inventory_panel: InventoryPanel = %InventoryPanel
@onready var character_panel: CharacterPanel = %CharacterPanel
@onready var status_label: Label = %HUDStatus
@onready var disconnect_button: Button = %DisconnectButton

var _bound_player: Node = null
var _last_synced_target: Node = null

func _ready() -> void:
	if disconnect_button:
		disconnect_button.pressed.connect(_on_disconnect_pressed)

	if quick_buttons:
		quick_buttons.inventory_toggle_requested.connect(_on_inventory_toggle_requested)
		quick_buttons.character_sheet_toggle_requested.connect(_on_character_sheet_toggle_requested)

	if UIManager.instance:
		UIManager.instance.inventory_toggle_requested.connect(_on_inventory_toggle_requested)
		UIManager.instance.character_sheet_toggle_requested.connect(_on_character_sheet_toggle_requested)

	if target_frame:
		target_frame.inspect_requested.connect(_on_target_inspect_requested)

	if inventory_panel:
		inventory_panel.item_equip_requested.connect(_on_item_equip_requested)

	if DragDropManager.instance == null:
		var ddm := DragDropManager.new()
		add_child(ddm)

func _process(_delta: float) -> void:
	if _bound_player == null:
		_try_auto_bind_player()
	else:
		_sync_target()
		_check_cast_movement_interrupt()

## Vincula explícitamente el HUD al nodo del jugador local.
func bind_player(player_node: Node) -> void:
	_bound_player = player_node
	if _bound_player == null:
		return

	if player_frame:
		player_frame.bind_player(_bound_player)

	if hotbar:
		hotbar.bind_player(_bound_player)
		if not hotbar.slot_activated.is_connected(_on_hotbar_slot_activated):
			hotbar.slot_activated.connect(_on_hotbar_slot_activated)

	var skill_ctrl := _bound_player.get_node_or_null("SkillController") as Node
	if skill_ctrl and skill_ctrl.has_signal("skill_cast_failed"):
		if not skill_ctrl.skill_cast_failed.is_connected(_on_skill_cast_failed):
			skill_ctrl.skill_cast_failed.connect(_on_skill_cast_failed)

	var status_ctrl := _bound_player.get_node_or_null("StatusEffectController") as Node
	if status_ctrl and cast_bar and status_ctrl.has_signal("stun_applied"):
		if not status_ctrl.stun_applied.is_connected(_on_stun_interrupt_cast):
			status_ctrl.stun_applied.connect(_on_stun_interrupt_cast)

	if inventory_panel:
		var inv_ctrl := _bound_player.get_node_or_null("InventoryController") as InventoryController
		var tgt_ctrl := _bound_player.get_node_or_null("CombatTarget") as CombatTarget
		if inv_ctrl:
			inventory_panel.bind_inventory(inv_ctrl, tgt_ctrl)

	if character_panel:
		var inv_ctrl := _bound_player.get_node_or_null("InventoryController") as InventoryController
		var eq_ctrl := _bound_player.get_node_or_null("EquipmentController") as EquipmentController
		var tgt_ctrl := _bound_player.get_node_or_null("CombatTarget") as CombatTarget
		var stats := tgt_ctrl.get_stats() if tgt_ctrl else null
		if stats and eq_ctrl:
			character_panel.bind_character(stats, eq_ctrl, inv_ctrl, tgt_ctrl)

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

func _on_inventory_toggle_requested() -> void:
	if inventory_panel:
		inventory_panel.toggle_panel()

func _on_character_sheet_toggle_requested() -> void:
	if character_panel:
		character_panel.toggle_panel()

func _on_target_inspect_requested(target_node: Node) -> void:
	if character_panel and is_instance_valid(target_node):
		character_panel.inspect_target(target_node)

func _on_item_equip_requested(item: ItemData, slot_idx: int) -> void:
	if _bound_player == null or item == null:
		return
	var eq_ctrl := _bound_player.get_node_or_null("EquipmentController") as EquipmentController
	var inv_ctrl := _bound_player.get_node_or_null("InventoryController") as InventoryController
	if eq_ctrl and inv_ctrl:
		var ok := eq_ctrl.equip_item(item, ItemData.EquipmentSlot.NONE, inv_ctrl)
		if ok:
			inv_ctrl.remove_item_at(slot_idx, item.stack_count)

func _check_cast_movement_interrupt() -> void:
	if cast_bar and cast_bar.is_casting() and is_instance_valid(_bound_player):
		var moving: bool = _bound_player.get("is_moving") if ("is_moving" in _bound_player) else false
		if moving:
			cast_bar.cancel_cast()

func _on_hotbar_slot_activated(slot_idx: int) -> void:
	if _bound_player == null or not is_instance_valid(_bound_player):
		return

	var skill_ctrl := _bound_player.get_node_or_null("SkillController")
	if skill_ctrl == null:
		return

	var combat_ctrl := _bound_player.get_node_or_null("CombatController") as CombatController
	var current_tgt: Node3D = combat_ctrl.current_target if combat_ctrl else null

	if skill_ctrl.has_method("activate_slot"):
		skill_ctrl.activate_slot(slot_idx, current_tgt, cast_bar, hotbar)

func _on_skill_cast_failed(reason: String) -> void:
	update_status(reason)
	var timer := get_tree().create_timer(2.0)
	if timer:
		timer.timeout.connect(func():
			if status_label and status_label.text == reason:
				update_status("")
		)

func _on_stun_interrupt_cast(_dur: float) -> void:
	if cast_bar and cast_bar.is_casting():
		cast_bar.cancel_cast()


