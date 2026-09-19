shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.35;
uniform bool use_normal_texture = false;
uniform bool use_roughness_texture = false;
uniform bool alpha_scissor = false;

uniform vec2 wind_direction = vec2(0.86, 0.50);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.42;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.72;
uniform float gust_strength : hint_range(0.0, 2.0) = 0.38;
uniform float branch_flutter : hint_range(0.0, 1.0) = 0.14;
uniform float mesh_base_y = 0.0;
uniform float mesh_height = 1.0;
uniform float stiffness : hint_range(0.0, 1.0) = 0.45;

varying float wind_lighting;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 original_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_mask = smoothstep(mesh_base_y, mesh_base_y + max(mesh_height, 0.01), VERTEX.y);
	height_mask = height_mask * height_mask;
	float phase = dot(original_world.xz, vec2(0.017, 0.013)) + hash12(floor(original_world.xz * 0.08)) * 6.28318;
	float slow_sway = sin(TIME * wind_speed + phase);
	float gust_wave = sin(TIME * wind_speed * 0.31 + dot(original_world.xz, vec2(0.004, 0.006)));
	float gust = smoothstep(0.15, 0.95, gust_wave * 0.5 + 0.5) * gust_strength;
	float amplitude = wind_strength * (0.38 + gust) * (1.0 - stiffness);
	vec2 direction = normalize(wind_direction + vec2(0.0001));
	vec3 world_offset = vec3(direction.x, 0.0, direction.y) * slow_sway * amplitude * height_mask;
	float flutter = sin(TIME * wind_speed * 4.7 + phase * 2.3 + VERTEX.y * 1.9);
	world_offset += vec3(direction.y, 0.12, -direction.x) * flutter * branch_flutter * height_mask;
	vec3 local_offset = inverse(mat3(MODEL_MATRIX)) * world_offset;
	VERTEX += local_offset;
	wind_lighting = clamp(height_mask * (slow_sway * 0.5 + 0.5), 0.0, 1.0);
}

void fragment() {
	vec4 base = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = base.rgb * mix(0.96, 1.035, wind_lighting);
	ROUGHNESS = use_roughness_texture ? texture(roughness_texture, UV).r : roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.28;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	if (alpha_scissor) {
		ALPHA = base.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
}
