shader_type canvas_item;
render_mode unshaded;

// Shader de Post-procesado para Estética Retro / Pixel Art 3D.
// Renderiza el mundo 3D en baja resolución emulada con muestreo Nearest-Neighbor,
// manteniendo la interfaz 2D por encima en resolución nativa de alta definición.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enabled = true;
uniform bool use_target_height = true;
uniform float target_height : hint_range(144.0, 720.0, 1.0) = 270.0;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform bool enable_dither = false;
uniform float dither_strength : hint_range(0.0, 0.5, 0.01) = 0.05;
uniform float color_depth : hint_range(0.0, 64.0, 1.0) = 32.0;

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;
		float scale_factor = pixel_size;
		if (use_target_height && screen_res.y > 0.0) {
			scale_factor = max(1.0, floor(screen_res.y / target_height));
		}

		// Cuantización de coordenadas espaciales de pantalla (pixelado puro)
		vec2 coord = floor(FRAGCOORD.xy / scale_factor) * scale_factor + (scale_factor * 0.5);
		vec2 uv = coord * SCREEN_PIXEL_SIZE;
		vec4 col = texture(screen_texture, uv);

		// Dithering retro de matriz 4x4 de Bayer (opcional para look 16-bit / PS1)
		if (enable_dither) {
			int x = int(mod(coord.x / scale_factor, 4.0));
			int y = int(mod(coord.y / scale_factor, 4.0));
			int idx = x + y * 4;
			float dither_table[16] = float[16](
				0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
				12.0/16.0, 4.0/16.0, 14.0/16.0,  6.0/16.0,
				3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
				15.0/16.0, 7.0/16.0, 13.0/16.0,  5.0/16.0
			);
			float d = (dither_table[idx] - 0.5) * dither_strength;
			col.rgb += d;
		}

		// Cuantización de profundidad de color (Color Banding)
		if (color_depth > 0.0) {
			col.rgb = floor(col.rgb * color_depth) / color_depth;
		}

		COLOR = col;
	}
}
