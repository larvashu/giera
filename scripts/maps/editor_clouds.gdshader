shader_type sky;

uniform vec2 wind_direction = vec2(0.9, 0.28);
uniform float wind_speed : hint_range(0.0, 2.0) = 0.32;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.38;
uniform vec3 horizon_color : source_color = vec3(0.64, 0.76, 0.86);
uniform vec3 zenith_color : source_color = vec3(0.16, 0.36, 0.62);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.92);
uniform vec3 cloud_shadow : source_color = vec3(0.38, 0.48, 0.60);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float result = 0.0;
	float amplitude = 0.52;
	for (int i = 0; i < 5; i++) {
		result += value_noise(p) * amplitude;
		p = mat2(vec2(1.62, 1.17), vec2(-1.17, 1.62)) * p;
		amplitude *= 0.48;
	}
	return result;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = clamp(direction.y, 0.0, 1.0);
	vec3 atmosphere = mix(horizon_color, zenith_color, pow(height, 0.48));
	float haze = pow(1.0 - height, 5.0);
	atmosphere = mix(atmosphere, vec3(0.78, 0.80, 0.79), haze * 0.34);

	if (direction.y > 0.015) {
		vec2 wind = normalize(wind_direction) * TIME * wind_speed * 0.012;
		vec2 cloud_uv = direction.xz / (direction.y + 0.22);
		float broad = fbm(cloud_uv * 1.18 + wind);
		float detail = fbm(cloud_uv * 3.1 - wind * 1.7);
		float cloud = smoothstep(0.58 - cloud_coverage * 0.34, 0.74 - cloud_coverage * 0.18, broad * 0.82 + detail * 0.18);
		cloud *= smoothstep(0.01, 0.16, direction.y);
		float lighting = clamp(dot(normalize(LIGHT0_DIRECTION), vec3(0.15, 0.95, 0.18)) * 0.5 + 0.5, 0.0, 1.0);
		vec3 cloud_color = mix(cloud_shadow, cloud_light, 0.58 + lighting * 0.32);
		atmosphere = mix(atmosphere, cloud_color, cloud * 0.88);
	}
	COLOR = atmosphere;
}
