shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Halo del Sol: un cuadrado que siempre mira a la cámara (billboard) con un
// brillo radial que se suma al cielo. Junto con la esfera emisiva del Sol y
// el glow del entorno simula el resplandor que se ve sin atmósfera.
uniform vec3 halo_color : source_color = vec3(1.0, 0.86, 0.6);
uniform float intensity = 2.5;

void vertex() {
	// Billboard: conserva la posición del nodo y orienta el cuadrado a la cámara.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 60.0) * 2.0;
	float glow = exp(-r * 7.0) * 0.7;
	// Rayos suaves (6 puntas) para que no parezca un simple círculo.
	float angle = atan(p.y, p.x);
	float rays = pow(abs(cos(angle * 3.0)), 24.0) * exp(-r * 4.0) * 0.35;
	float a = (core + glow + rays) * (1.0 - smoothstep(0.75, 1.0, r));
	ALBEDO = halo_color * a * intensity;
}
