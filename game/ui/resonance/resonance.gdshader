shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float aspect = 1.0;

const vec3 STONE = vec3(0.026, 0.020, 0.033);
const vec3 BONE = vec3(0.933, 0.875, 0.753);
const vec3 BRASS = vec3(0.659, 0.522, 0.318);
const vec3 EMBER = vec3(0.569, 0.204, 0.161);
const vec3 VIOLET = vec3(0.196, 0.137, 0.267);
const vec3 CYAN = vec3(0.388, 0.722, 0.784);

float wire(float distance_to_wire, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(distance_to_wire));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.25;
	p.x *= aspect;
	float r = length(p);
	float angle = atan(p.y, p.x + 0.000001);
	float aa = max(length(fwidth(p)), 0.001);
	float drift = sin(phase) * 0.025;
	vec3 color = STONE + VIOLET * (0.17 / (1.0 + r * r));
	float window = 1.0 - smoothstep(1.18, 1.35, r);
	float cavities = pow(0.5 + 0.5 * cos(angle * 6.0), 3.0);
	color += EMBER * cavities * smoothstep(0.25, 0.55, r) * window * 0.46;
	float brass = wire(r - 1.08, 0.008, aa) + wire(r - 1.13, 0.003, aa);
	float bone = 0.0;
	vec2 q = p;
	float scale = 1.0;
	// Four recursive polar folds, independent of viewport size; no textures or raymarch.
	for (int i = 0; i < 4; i++) {
		float radius = length(q);
		float a = atan(q.y, q.x + 0.000001);
		float rose = 0.62 + 0.13 * cos(a * 6.0 + drift);
		bone += wire((radius - rose) / scale, 0.0025, aa) * 0.46;
		brass += wire((radius - rose - 0.04) / scale, 0.002, aa) * 0.25;
		float ribs = sin(a * 18.0 + radius * 7.0 + drift) * radius / scale;
		bone += wire(ribs, 0.0015, aa) * smoothstep(0.18, 0.4, radius) * (1.0 - smoothstep(0.68, 0.84, radius)) * 0.22;
		q = abs(q);
		q = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866)) * q;
		q = q * 1.65 - vec2(0.58, 0.21);
		scale *= 1.65;
	}
	float aperture = smoothstep(0.20, 0.32, r);
	color += BRASS * min(brass, 1.1) * window * aperture;
	color += BONE * min(bone, 1.0) * window * aperture;
	float orbit = wire(r - (0.19 + 0.022 * cos(angle * 8.0)), 0.0015, aa);
	float spokes = wire(sin(angle * 4.0) * r, 0.001, aa) * (1.0 - smoothstep(0.18, 0.28, r));
	color += CYAN * (orbit * 0.40 + spokes * 0.22);
	color += CYAN * 0.42 * exp(-r * r * 900.0);
	float edge = 1.0 - smoothstep(0.72, 1.8, r);
	COLOR = vec4(clamp(color * (0.6 + 0.4 * edge), vec3(0.0), vec3(1.0)), 1.0);
}
