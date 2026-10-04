class_name QuickButtons
extends Control

## Responsabilidad: Botones de acceso rápido en la esquina inferior derecha.
## Permite alternar la apertura de la Mochila (tecla B) y el Panel de Personaje (tecla C).

signal inventory_toggle_requested
signal character_sheet_toggle_requested
signal skills_toggle_requested

@onready var bag_button: Button = %BagButton
@onready var character_button: Button = %CharacterButton
@onready var skills_button: Button = get_node_or_null("%SkillsButton")

func _ready() -> void:
	if bag_button:
		bag_button.pressed.connect(_on_bag_pressed)
	if character_button:
		character_button.pressed.connect(_on_character_pressed)
	if skills_button:
		skills_button.pressed.connect(_on_skills_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_on_bag_pressed()
		elif event.keycode == KEY_C:
			_on_character_pressed()
		elif event.keycode == KEY_K:
			_on_skills_pressed()

func _on_bag_pressed() -> void:
	inventory_toggle_requested.emit()
	if UIManager.instance:
		UIManager.instance.request_toggle_inventory()

func _on_character_pressed() -> void:
	character_sheet_toggle_requested.emit()
	if UIManager.instance:
		UIManager.instance.request_toggle_character_sheet()

func _on_skills_pressed() -> void:
	skills_toggle_requested.emit()
	if UIManager.instance:
		UIManager.instance.request_toggle_skills()
