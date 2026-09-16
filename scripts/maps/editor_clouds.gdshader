shader_type sky;

uniform vec2 wind_direction = vec2(0.88, 0.32);
uniform float wind_speed : hint_range(0.0, 2.0) = 0.22;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_density : hint_range(0.0, 2.0) = 1.05;
uniform float cloud_scale : hint_range(0.2, 4.0) = 1.0;
uniform vec3 horizon_color : source_color = vec3(0.58, 0.72, 0.86);
uniform vec3 zenith_color : source_color = vec3(0.075, 0.22, 0.48);
uniform vec3 sun_color : source_color = vec3(1.0, 0.88, 0.66);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.97, 0.90);
uniform vec3 cloud_mid : source_color = vec3(0.64, 0.72, 0.79);
uniform vec3 cloud_shadow : source_color = vec3(0.25, 0.34, 0.43);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.52;
	mat2 rotation = mat2(vec2(1.58, 1.18), vec2(-1.18, 1.58));
	for (int i = 0; i < 6; i++) {
		value += noise2d(p) * amplitude;
		p = rotation * p;
		amplitude *= 0.47;
	}
	return value;
}

float cloud_field(vec2 uv, vec2 wind, float scale) {
	float shape = fbm(uv * scale + wind);
	float erosion = fbm(uv * scale * 3.7 - wind * 1.43);
	float wisps = fbm(uv * scale * 8.3 + wind * 0.71);
	return shape * 0.76 + erosion * 0.18 + wisps * 0.06;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	vec3 sun_direction = normalize(LIGHT0_DIRECTION);
	float height = clamp(direction.y, 0.0, 1.0);
	float horizon = pow(1.0 - height, 4.2);
	vec3 atmosphere = mix(horizon_color, zenith_color, pow(height, 0.42));
	float sun_dot = max(dot(direction, sun_direction), 0.0);
	float mie = pow(sun_dot, 18.0) * (0.42 + horizon * 0.58);
	atmosphere += sun_color * mie * 0.34;
	atmosphere = mix(atmosphere, vec3(0.73, 0.79, 0.83), horizon * 0.26);
	float sun_disc = smoothstep(0.99991, 0.99997, sun_dot);
	float sun_halo = pow(sun_dot, 420.0);
	atmosphere += sun_color * (sun_disc * 7.5 + sun_halo * 0.9);

	if (direction.y > 0.008) {
		vec2 wind = normalize(wind_direction) * TIME * wind_speed * 0.009;
		vec2 projected = direction.xz / (direction.y + 0.115);
		float low = cloud_field(projected, wind, 0.72 * cloud_scale);
		float high = cloud_field(projected + vec2(7.3, -3.1), -wind * 1.7, 1.75 * cloud_scale);
		float threshold = 0.69 - cloud_coverage * 0.29;
		float body = smoothstep(threshold, threshold + 0.16, low) * cloud_density;
		float breakup = smoothstep(0.42, 0.78, high);
		body *= mix(0.70, 1.08, breakup);
		body *= smoothstep(0.008, 0.105, direction.y);
		float thickness = smoothstep(0.0, 0.92, body);
		float light_noise = cloud_field(projected + sun_direction.xz * 0.075, wind, 0.72 * cloud_scale);
		float self_shadow = clamp((low - light_noise) * 3.7 + 0.54, 0.0, 1.0);
		float forward_scatter = pow(sun_dot, 8.0) * 0.72 + pow(sun_dot, 64.0) * 1.4;
		float edge = clamp(body - smoothstep(threshold + 0.045, threshold + 0.19, low), 0.0, 1.0);
		vec3 lit_cloud = mix(cloud_shadow, cloud_mid, self_shadow);
		lit_cloud = mix(lit_cloud, cloud_light, 0.40 + forward_scatter * 0.32);
		lit_cloud += sun_color * edge * (0.45 + forward_scatter);
		atmosphere = mix(atmosphere, lit_cloud, clamp(thickness * 0.94, 0.0, 0.96));
		float cirrus = smoothstep(0.66, 0.82, fbm(projected * 4.6 - wind * 2.4));
		cirrus *= smoothstep(0.08, 0.32, direction.y) * (1.0 - thickness) * 0.34;
		atmosphere = mix(atmosphere, cloud_light, cirrus);
	}
	COLOR = atmosphere;
}
