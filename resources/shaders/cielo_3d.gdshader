shader_type sky;

// Cielo de la simulación 3D: azul en el suelo, negro con estrellas en el espacio.
// altitude_km lo actualiza el script con los datos reales del Apolo 8.
uniform float altitude_km = 0.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void sky() {
	float h = clamp(altitude_km / 70.0, 0.0, 1.0);
	float up = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 horizon = mix(vec3(0.72, 0.84, 1.0), vec3(0.02, 0.03, 0.08), h);
	vec3 zenith = mix(vec3(0.22, 0.45, 0.9), vec3(0.0, 0.0, 0.01), h);
	vec3 col = mix(horizon, zenith, clamp(up, 0.0, 1.0));
	col = mix(col, horizon * 0.8, clamp(-up, 0.0, 1.0));
	// Estrellas: solo cuando ya casi no hay aire.
	float stars = step(0.9985, hash(floor(EYEDIR * 400.0))) * smoothstep(50.0, 110.0, altitude_km);
	col += vec3(stars);
	// Sol
	float sun = smoothstep(0.9993, 0.9998, dot(EYEDIR, LIGHT0_DIRECTION));
	col += LIGHT0_COLOR * sun * 4.0;
	COLOR = col;
}
