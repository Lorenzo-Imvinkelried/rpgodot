class_name SkillPanel
extends PanelContainer

## Responsabilidad: Ventana y Grimorio de Habilidades del jugador (SkillPanel).
## Permite explorar el catálogo completo de habilidades disponibles (daño, enfriamiento,
## coste de maná y efectos) y asignarlas/equiparlas rápidamente en cualquier casilla de la Hotbar.

signal visibility_changed_to(is_visible: bool)

@onready var title_bar: Control = %TitleBar
@onready var close_button: Button = %CloseButton
@onready var skills_container: VBoxContainer = %SkillsContainer

var _bound_skill_controller: SkillController = null
var _bound_player: Node = null

# Arrastre de la ventana
var _is_dragging_window: bool = false
var _drag_window_offset: Vector2 = Vector2.ZERO

# Lista de slots asignables (slot_index -> etiqueta visual)
const ASSIGNABLE_SLOTS: Array[Dictionary] = [
	{ "index": 0, "key": "1" },
	{ "index": 3, "key": "4" },
	{ "index": 4, "key": "5" },
	{ "index": 5, "key": "6" },
	{ "index": 6, "key": "7" },
	{ "index": 7, "key": "8" },
	{ "index": 8, "key": "9" },
	{ "index": 9, "key": "0" }
]

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(hide_panel)
	if title_bar:
		title_bar.gui_input.connect(_on_title_bar_gui_input)

	hide()

func bind_skill_controller(skill_ctrl: SkillController, player: Node = null) -> void:
	_bound_skill_controller = skill_ctrl
	_bound_player = player
	_build_skills_list()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func show_panel() -> void:
	_build_skills_list()
	show()
	visibility_changed_to.emit(true)

func hide_panel() -> void:
	hide()
	visibility_changed_to.emit(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			toggle_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			hide_panel()
			get_viewport().set_input_as_handled()

func _build_skills_list() -> void:
	if skills_container == null:
		return

	for child in skills_container.get_children():
		child.queue_free()

	var catalog := SkillController.get_skill_catalog()
	var current_skills: Dictionary = _bound_skill_controller.get_all_skills() if _bound_skill_controller else {}

	for skill in catalog:
		var entry := _create_skill_entry(skill, current_skills)
		skills_container.add_child(entry)

func _create_skill_entry(skill: BaseSkill, current_skills: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.19, 0.95)
	style.border_color = Color(0.24, 0.28, 0.38, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Fila 1: Icono + Nombre + Coste / CD
	var row_top := HBoxContainer.new()
	vbox.add_child(row_top)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [skill.icon, skill.name]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	row_top.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.text = "%d MP | %.1fs CD" % [skill.mana_cost, skill.cooldown]
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.95))
	row_top.add_child(meta_lbl)

	# Fila 2: Descripción y efectos
	var desc_lbl := Label.new()
	desc_lbl.text = _get_skill_description(skill)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	vbox.add_child(desc_lbl)

	# Fila 3: Botones de Asignación rápida a la Hotbar
	var row_slots := HBoxContainer.new()
	row_slots.add_theme_constant_override("separation", 4)
	vbox.add_child(row_slots)

	var assign_lbl := Label.new()
	assign_lbl.text = "Asignar a tecla:"
	assign_lbl.add_theme_font_size_override("font_size", 10)
	assign_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	row_slots.add_child(assign_lbl)

	for slot_info in ASSIGNABLE_SLOTS:
		var slot_idx: int = slot_info["index"]
		var key_name: String = slot_info["key"]

		var btn := Button.new()
		btn.text = "[ %s ]" % key_name
		btn.custom_minimum_size = Vector2(30, 20)
		btn.add_theme_font_size_override("font_size", 10)
		btn.focus_mode = Control.FOCUS_NONE

		# Indicar si la skill ya está en este slot
		var is_assigned_here: bool = false
		if current_skills.has(slot_idx) and current_skills[slot_idx] != null:
			if current_skills[slot_idx].id == skill.id:
				is_assigned_here = true

		if is_assigned_here:
			btn.modulate = Color(0.3, 1.0, 0.4)
			btn.tooltip_text = "Equipada en Tecla %s" % key_name
		else:
			btn.modulate = Color(0.85, 0.88, 0.95)
			btn.tooltip_text = "Asignar a Tecla %s" % key_name

		btn.pressed.connect(_on_equip_slot_pressed.bind(skill.id, slot_idx))
		row_slots.add_child(btn)

	return panel

func _on_equip_slot_pressed(skill_id: String, slot_idx: int) -> void:
	if _bound_skill_controller:
		_bound_skill_controller.equip_skill_by_id(skill_id, slot_idx)
		_build_skills_list()

func _get_skill_description(skill: BaseSkill) -> String:
	match skill.id:
		"golpe_potente":
			return "Golpe físico cuerpo a cuerpo de ejecución rápida (1.70x) que reinicia el temporizador de autoataque."
		"furia_berserker":
			return "+40% de daño físico y +40% de velocidad de ataque durante 8 segundos. No requiere objetivo."
		"carga":
			return "Embiste velozmente hacia el enemigo e inflige daño contundente, aturdiéndolo por 2.0s al impactar."
		"torbellino":
			return "Gira con tu arma dañando a todos los enemigos cercanos en un radio de 6 metros."
		"tajo_sangriento":
			return "Ataque sangriento que aplica Sangrado continuo sin snapshotting durante 4 segundos."
		"relampago":
			return "Descarga instantánea de alto voltaje de largo alcance que fulmina al objetivo."
		"bola_fuego":
			return "Proyectil ígneo de gran potencia que explota al alcanzar al objetivo tras un casteo de 1.2s."
		"escarcha":
			return "Ráfaga gélida que reduce la velocidad de movimiento un 40% y la velocidad de ataque un 20%."
		"rayo_solar":
			return "Haz concentrado de energía radiante que calcina las defensas enemigas a distancia."
		"meteorito":
			return "Invoca un cometa masivo desde el cielo que impacta con tremendo daño tras 2.2s de casteo."
		_:
			return "Habilidad activa de combate."

# --- Arrastre de la Ventana mediante Barra de Título ---
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging_window = true
				_drag_window_offset = get_global_mouse_position() - global_position
			else:
				_is_dragging_window = false
	elif event is InputEventMouseMotion and _is_dragging_window:
		global_position = get_global_mouse_position() - _drag_window_offset
