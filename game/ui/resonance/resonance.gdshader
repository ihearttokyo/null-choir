shader_type canvas_item;
render_mode unshaded;

// No TIME uniform: still frames stay still when playback or motion is paused.
uniform float phase = 0.0;
uniform float aspect = 1.0;
uniform float seed = 0.0;
uniform float energy = 0.0;
uniform int visual_style = 0;

float wire(float d, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(d));
}
float hash(float n) { return fract(sin(n * 127.1 + seed * 91.7) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x *= aspect;
	float aa = max(length(fwidth(p)), 0.001);
	float hue = fract(seed * 0.6180339);
	vec3 brass = mix(vec3(0.74, 0.39, 0.19), vec3(0.53, 0.61, 0.70), hue);
	vec3 bone = vec3(0.91, 0.84, 0.65);
	vec3 spectral = mix(vec3(0.22, 0.39, 0.57), vec3(0.61, 0.14, 0.19), hue);
	vec3 color = vec3(0.012, 0.014, 0.025);
	vec2 eye = p - vec2(0.0, -0.12);
	float radius = length(eye);
	float angle = atan(eye.y, eye.x + 0.000001);
	float breath = sin(phase * 0.23) * 0.015;
	float ribs = 6.0 + floor(mod(seed, 4.0)) * 2.0;

	// A luminous rose window/armillary heart, surrounded by architectural depth.
	float rose_radius = 0.23 + 0.035 * cos(angle * ribs + breath);
	float rose = wire(radius - rose_radius, 0.0025, aa);
	rose += wire(radius - 0.30, 0.003, aa) * 0.7;
	rose += wire(radius - 0.32, 0.001, aa) * 0.7;
	float petal = wire(sin(angle * ribs * 0.5) * radius, 0.0015, aa);
	petal *= smoothstep(0.045, 0.09, radius) * (1.0 - smoothstep(0.22, 0.29, radius));
	color += spectral * (0.025 / (0.03 + radius * radius));
	color += bone * (rose + petal * 0.7) * (0.55 + energy * 0.45);
	color += spectral * exp(-radius * radius * 90.0) * (0.25 + energy * 0.65);

	// Fixed-cost perspective vaults: silhouette, stone ribs, paired columns and
	// carved tracery. Eighteen layers, no raymarch, textures, or screen reads.
	for (int i = 0; i < 18; i++) {
		float depth = float(i) / 17.0;
		float scale = mix(2.7, 0.36, pow(depth, 0.72));
		vec2 q = eye / scale;
		float width = 0.62 + 0.045 * sin(seed + float(i) * 0.7);
		float arch = -0.85 + pow(abs(q.x) / width, 1.45) * 0.67;
		float top = wire((q.y - arch) * scale, 0.004 + (1.0-depth)*0.003, aa);
		top *= 1.0 - smoothstep(width, width + 0.025, abs(q.x));
		float columns = wire((abs(q.x) - width) * scale, 0.006, aa);
		columns *= smoothstep(-0.25, -0.15, q.y) * (1.0 - smoothstep(0.7, 0.8, q.y));
		float capitals = wire((q.y + 0.16) * scale, 0.008, aa);
		capitals *= 1.0 - smoothstep(0.04, 0.08, abs(abs(q.x) - width));
		float inner = wire((q.y - arch - 0.045) * scale, 0.0015, aa);
		inner *= 1.0 - smoothstep(width - 0.035, width, abs(q.x));
		float weight = (0.18 + (1.0 - depth) * 0.45) * (0.82 + 0.18 * sin(phase - depth * 8.0));
		vec3 stone = mix(brass, bone, depth * 0.8);
		color += stone * (top + columns + capitals * 0.7) * weight;
		color += spectral * inner * (0.3 + energy * 0.3);
		// Flanking lancet windows repeated into the depth.
		float lancet_x = abs(abs(q.x) - width * 0.83);
		float lancet = wire((lancet_x + max(0.0, -q.y - 0.03) * 0.45 - 0.025) * scale, 0.0015, aa);
		lancet *= smoothstep(-0.38, -0.29, q.y) * (1.0 - smoothstep(0.3, 0.4, q.y));
		color += spectral * lancet * weight * 0.55;
	}

	// Radial inlaid floor, with restrained light travelling at playback time.
	float floor_mask = smoothstep(0.18, 0.55, p.y);
	float floor_lines = wire(sin(atan(p.x, p.y + 0.15) * 16.0) * radius, 0.001, aa);
	float steps = wire(fract(1.8 / max(0.15, p.y + 0.25)) - 0.5, 0.012, aa * 3.0);
	color += brass * (floor_lines * 0.25 + steps * 0.2) * floor_mask;
	float halo = wire(radius - (0.48 + 0.018 * sin(angle * ribs)), 0.0015, aa);
	if (visual_style == 1) {
		// Orrery: eccentric orbital rings and deterministic celestial filigree.
		for (int orbit = 0; orbit < 7; orbit++) {
			float n = float(orbit);
			vec2 axis = vec2(cos(n * 0.43 + seed), sin(n * 0.43 + seed));
			vec2 rotated = vec2(dot(eye, axis), dot(eye, vec2(-axis.y, axis.x)));
			float ring = length(rotated * vec2(1.0, 1.8 + n * 0.15));
			halo += wire(ring - 0.44 - n * 0.035, 0.001, aa) * 0.32;
		}
	} else if (visual_style == 2) {
		// Reliquary: nested crystalline chevrons around the same sacred void.
		float diamond = abs(eye.x) + abs(eye.y) * 0.82;
		halo += wire(fract(diamond * 7.0) - 0.5, 0.014, aa * 7.0) * smoothstep(0.35, 0.55, radius) * 0.45;
	}
	color += brass * halo * 0.5;
	// Seeded dust is geometry, not fabricated audio-spectrum data.
	for (int star = 0; star < 6; star++) {
		float n = float(star);
		vec2 spot = vec2(hash(n + 5.0) * 2.0 - 1.0, hash(n + 57.0) * 2.0 - 1.0);
		spot.x *= aspect;
		float light = exp(-dot(p - spot, p - spot) * 22000.0);
		color += bone * light * (0.15 + energy * 0.35);
	}
	float vignette = 1.0 - smoothstep(0.55, 2.1, length(p));
	COLOR = vec4(clamp(color * (0.45 + vignette * 0.55), vec3(0.0), vec3(1.0)), 1.0);
}
