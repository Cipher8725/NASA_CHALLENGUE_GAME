shader_type canvas_item;

// Muestra la cámara en vivo. Algunas cámaras (macOS/iOS) envían la imagen en
// formato YCbCr separado en dos texturas; aquí se convierte a color normal.
uniform bool use_ycbcr = false;
uniform bool mirror = true;
uniform sampler2D tex_cbcr : filter_linear;

void fragment() {
	vec2 uv = UV;
	if (mirror) {
		uv.x = 1.0 - uv.x;
	}
	if (use_ycbcr) {
		float y = texture(TEXTURE, uv).r;
		vec2 cbcr = texture(tex_cbcr, uv).rg - vec2(0.5);
		vec3 rgb = vec3(y + 1.402 * cbcr.y, y - 0.344136 * cbcr.x - 0.714136 * cbcr.y, y + 1.772 * cbcr.x);
		COLOR = vec4(rgb, 1.0);
	} else {
		COLOR = vec4(texture(TEXTURE, uv).rgb, 1.0);
	}
}
