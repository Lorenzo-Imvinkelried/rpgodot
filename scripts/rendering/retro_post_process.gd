class_name RetroPostProcess
extends CanvasLayer

## Responsabilidad: Orquestador del pipeline de renderizado retro pixelado para el entorno 3D.
## Aplica un pase de pantalla completa en Layer 1, situándose de forma estricta entre el mundo 3D
## (Layer 0) y la interfaz de usuario en alta definición (Layer 10).
## Permite alternar la estética retro en caliente (F10) y configurar parámetros desde retro_config.json.

const RETRO_SHADER = preload("res://shaders/retro_pixel.gdshader")
const CONFIG_PATH = "res://config/rendering/retro_config.json"

@export var retro_enabled: bool = true:
	set = set_retro_enabled
@export var target_vertical_res: float = 270.0:
	set = set_target_vertical_res
@export var pixel_scale: float = 4.0:
	set = set_pixel_scale
@export var enable_dither: bool = false:
	set = set_enable_dither
@export var color_depth: float = 32.0:
	set = set_color_depth

var _color_rect: ColorRect = null
var _material: ShaderMaterial = null

func _init() -> void:
	layer = 1 # Se dibuja inmediatamente después del mundo 3D y antes del HUD (layer 10)

func _ready() -> void:
	_load_config()
	_setup_fullscreen_quad()
	_apply_shader_parameters()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			toggle_retro()
			get_viewport().set_input_as_handled()

func _setup_fullscreen_quad() -> void:
	if _color_rect == null:
		_color_rect = ColorRect.new()
		_color_rect.name = "RetroScreenQuad"
		_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_color_rect)

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = RETRO_SHADER
		_color_rect.material = _material

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json_str := file.get_as_text()
	var json := JSON.new()
	if json.parse(json_str) == OK and json.data is Dictionary:
		var retro_dict: Dictionary = json.data.get("retro", {})
		retro_enabled = bool(retro_dict.get("enabled", retro_enabled))
		target_vertical_res = float(retro_dict.get("target_vertical_resolution", target_vertical_res))
		pixel_scale = float(retro_dict.get("pixel_scale", pixel_scale))
		enable_dither = bool(retro_dict.get("enable_dither", enable_dither))
		color_depth = float(retro_dict.get("color_depth", color_depth))

func _apply_shader_parameters() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("enabled", retro_enabled)
	_material.set_shader_parameter("target_height", target_vertical_res)
	_material.set_shader_parameter("pixel_size", pixel_scale)
	_material.set_shader_parameter("enable_dither", enable_dither)
	_material.set_shader_parameter("color_depth", color_depth)

func set_retro_enabled(value: bool) -> void:
	retro_enabled = value
	_apply_shader_parameters()

func toggle_retro() -> void:
	set_retro_enabled(not retro_enabled)

func set_target_vertical_res(value: float) -> void:
	target_vertical_res = maxf(100.0, value)
	_apply_shader_parameters()

func set_pixel_scale(value: float) -> void:
	pixel_scale = maxf(1.0, value)
	_apply_shader_parameters()

func set_enable_dither(value: bool) -> void:
	enable_dither = value
	_apply_shader_parameters()

func set_color_depth(value: float) -> void:
	color_depth = value
	_apply_shader_parameters()
