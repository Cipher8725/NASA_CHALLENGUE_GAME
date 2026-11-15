shader_type spatial;

// Tierra procedural para la simulación 3D: océano, continentes y nubes que se
// mueven, más un brillo azul de atmósfera en el borde. No usa texturas externas.
uniform vec3 ocean_color : source_color = vec3(0.04, 0.16, 0.42);
uniform vec3 land_color : source_color = vec3(0.24, 0.36, 0.18);
uniform vec3 sand_color : source_color = vec3(0.62, 0.56, 0.4);
uniform float time_s = 0.0;
// Brillo azul del borde (atmósfera): el script lo sube con la altura.
uniform float rim_strength = 0.0;
// Cantidad de nubes (0 a 1).
uniform float cloud_amount = 0.55;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i); float n100 = hash(i + vec3(1,0,0)); float n010 = hash(i + vec3(0,1,0)); float n110 = hash(i + vec3(1,1,0));
	float n001 = hash(i + vec3(0,0,1)); float n101 = hash(i + vec3(1,0,1)); float n011 = hash(i + vec3(0,1,1)); float n111 = hash(i + vec3(1,1,1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}
float fbm(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

varying vec3 local_n;
void vertex() { local_n = normalize(VERTEX); }

void fragment() {
	vec3 n = normalize(local_n);
	float land = smoothstep(0.52, 0.56, fbm(n * 6.0));
	// Cerca de la plataforma (polo "norte" de la esfera): costa de Florida.
	// Tierra al oeste (x < 0) y océano Atlántico al este, hacia donde voló el Apolo 8.
	float near_pad = smoothstep(0.985, 0.995, n.y);
	float coast = 1.0 - smoothstep(0.0004, 0.0012, n.x + 0.00025 * sin(n.z * 4000.0));
	land = mix(land, coast, near_pad);
	float shore = smoothstep(0.50, 0.53, fbm(n * 6.0)) - land;
	vec3 col = mix(ocean_color, land_color, land);
	col = mix(col, sand_color, clamp(shore, 0.0, 1.0) * 0.6);
	float clouds = smoothstep(0.62, 0.8, fbm(n * 9.0 + vec3(time_s * 0.002, 0.0, 0.0))) * cloud_amount;
	col = mix(col, vec3(0.95), clouds * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.9, land);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.25, 0.5, 1.0) * rim * rim_strength;
}
