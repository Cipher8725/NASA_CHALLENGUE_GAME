shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Llama de los motores: más brillante en la tobera y transparente en la punta.
// UV.y = 0 en la tobera (arriba del cono) y 1 en la punta.
uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.75);
uniform vec3 tail_color : source_color = vec3(1.0, 0.45, 0.08);
uniform float intensity = 1.0;
uniform float time_s = 0.0;

void fragment() {
	float t = UV.y;
	float flicker = 0.85 + 0.15 * sin(time_s * 40.0 + UV.x * 25.0);
	vec3 col = mix(core_color, tail_color, smoothstep(0.0, 0.6, t));
	float a = (1.0 - t) * flicker * intensity;
	ALBEDO = col * a;
	ALPHA = a;
}
