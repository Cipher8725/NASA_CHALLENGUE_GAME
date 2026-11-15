shader_type spatial;
render_mode unshaded, cull_disabled;

// Paneles de la cabina 3D (fotos del paquete "Nasa Space 2").
// Donde la imagen es transparente (vidrio de las ventanas) se ve el mundo 3D de
// afuera; mientras covered = 1 la cubierta protectora tapa las ventanas.
uniform sampler2D panel_texture : source_color, filter_linear_mipmap;
uniform float covered = 1.0;
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(panel_texture, UV);
	if (c.a < 0.5) {
		if (covered < 0.5) {
			discard;
		}
		c = vec4(0.12, 0.12, 0.13, 1.0);
	}
	ALBEDO = c.rgb * brightness;
}
