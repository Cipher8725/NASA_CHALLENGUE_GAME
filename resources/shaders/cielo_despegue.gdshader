shader_type canvas_item;

// Cielo que se ve por las ventanas de la cabina durante el despegue.
//  * covered = 1: la cubierta protectora tapa las ventanas (hasta soltar la torre de escape).
//  * altitude_km: el azul se oscurece con la altura; arriba de ~70 km aparecen estrellas.
//  * Arriba de ~90 km se ve el borde curvo de la Tierra con su atmósfera azul.
uniform float altitude_km = 0.0;
uniform float covered = 1.0;
uniform float time_s = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float h = clamp(altitude_km / 60.0, 0.0, 1.0);
	vec3 low = mix(vec3(0.55, 0.75, 1.0), vec3(0.02, 0.03, 0.08), h);
	vec3 high = mix(vec3(0.25, 0.5, 0.95), vec3(0.0, 0.0, 0.02), h);
	vec3 col = mix(low, high, uv.y < 0.5 ? 1.0 - uv.y * 2.0 : 0.0);
	// Estrellas
	float star_amount = smoothstep(55.0, 110.0, altitude_km);
	vec2 cell = floor(uv * vec2(260.0, 150.0));
	float s = step(0.996, hash(cell)) * star_amount;
	col += vec3(s);
	// Borde de la Tierra (curva) cuando ya se está muy alto
	float earth_amount = smoothstep(80.0, 160.0, altitude_km);
	float curve = 0.82 - 0.18 * pow(uv.x - 0.5, 2.0) * 4.0;
	float earth = smoothstep(curve, curve + 0.004, uv.y) * earth_amount;
	vec3 earth_col = mix(vec3(0.1, 0.3, 0.7), vec3(0.85, 0.9, 0.95), step(0.55, hash(floor((uv + vec2(time_s * 0.01, 0.0)) * vec2(40.0, 18.0)))) * 0.6);
	float glow = exp(-abs(uv.y - curve) * 60.0) * earth_amount;
	col = mix(col, earth_col, earth);
	col += vec3(0.2, 0.45, 1.0) * glow * 0.8;
	// Cubierta protectora: panel gris oscuro
	col = mix(col, vec3(0.13, 0.13, 0.14) + 0.03 * hash(floor(uv * 30.0)), covered);
	COLOR = vec4(col, 1.0);
}
