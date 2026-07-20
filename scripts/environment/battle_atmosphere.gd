class_name BattleAtmosphere
extends WorldEnvironment

const MOON_DIRECTION := Vector3(-0.42, 0.48, -0.77)

@onready var sun: DirectionalLight3D = get_parent().get_node_or_null("Sun") as DirectionalLight3D

func _ready() -> void:
	_configure_moonlit_environment()
	_configure_moon_light()

func _configure_moonlit_environment() -> void:
	var battle_environment := environment.duplicate(true) as Environment if environment != null else Environment.new()
	battle_environment.background_mode = Environment.BG_SKY
	battle_environment.sky = _create_moonlit_sky()
	battle_environment.background_energy_multiplier = 0.52
	battle_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	battle_environment.ambient_light_color = Color(0.16, 0.22, 0.42)
	battle_environment.ambient_light_energy = 0.64
	battle_environment.ambient_light_sky_contribution = 0.18
	battle_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	battle_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	battle_environment.tonemap_exposure = 1.08
	battle_environment.tonemap_agx_contrast = 1.32
	battle_environment.glow_enabled = true
	battle_environment.glow_intensity = 0.72
	battle_environment.glow_strength = 1.08
	battle_environment.glow_bloom = 0.18
	battle_environment.glow_hdr_threshold = 0.72
	battle_environment.glow_hdr_scale = 1.35
	battle_environment.ssao_enabled = true
	battle_environment.ssao_radius = 2.2
	battle_environment.ssao_intensity = 2.1
	battle_environment.ssao_power = 1.45
	battle_environment.ssao_detail = 0.72
	battle_environment.fog_enabled = true
	battle_environment.fog_light_color = Color(0.12, 0.17, 0.34)
	battle_environment.fog_light_energy = 0.34
	battle_environment.fog_density = 0.00055
	battle_environment.fog_height = 4.0
	battle_environment.fog_height_density = 0.008
	battle_environment.fog_aerial_perspective = 0.58
	battle_environment.fog_sky_affect = 0.18
	battle_environment.fog_sun_scatter = 0.42
	battle_environment.volumetric_fog_enabled = true
	battle_environment.volumetric_fog_density = 0.0028
	battle_environment.volumetric_fog_albedo = Color(0.32, 0.40, 0.70)
	battle_environment.volumetric_fog_emission = Color(0.008, 0.012, 0.035)
	battle_environment.volumetric_fog_emission_energy = 0.18
	battle_environment.volumetric_fog_length = 155.0
	battle_environment.volumetric_fog_detail_spread = 2.4
	battle_environment.volumetric_fog_ambient_inject = 0.07
	battle_environment.volumetric_fog_anisotropy = 0.82
	battle_environment.volumetric_fog_sky_affect = 0.025
	battle_environment.volumetric_fog_temporal_reprojection_enabled = true
	battle_environment.volumetric_fog_temporal_reprojection_amount = 0.91
	environment = battle_environment

func _configure_moon_light() -> void:
	if sun == null:
		return
	var moon_direction := MOON_DIRECTION.normalized()
	sun.look_at(sun.global_position - moon_direction, Vector3.UP)
	sun.light_color = Color(0.64, 0.74, 1.0)
	sun.light_energy = 0.72
	sun.light_indirect_energy = 0.34
	sun.light_volumetric_fog_energy = 0.26
	sun.light_angular_distance = 0.42
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.25
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_fade_start = 0.86

func _create_moonlit_sky() -> Sky:
	var sky_shader := Shader.new()
	sky_shader.code = """shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.004, 0.009, 0.035);
uniform vec3 horizon_color : source_color = vec3(0.035, 0.055, 0.135);
uniform vec3 cloud_dark : source_color = vec3(0.055, 0.065, 0.12);
uniform vec3 cloud_light : source_color = vec3(0.16, 0.18, 0.30);
uniform vec3 moon_direction = vec3(-0.42, 0.48, -0.77);
uniform float cloud_speed = 0.0045;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

float fractal_noise(vec2 point) {
	float result = 0.0;
	float amplitude = 0.52;
	for (int octave = 0; octave < 5; octave++) {
		result += value_noise(point) * amplitude;
		point = point * 2.07 + vec2(13.1, 7.7);
		amplitude *= 0.5;
	}
	return result;
}

float star_layer(vec2 spherical_uv, float density, float threshold, float radius) {
	vec2 star_grid = spherical_uv * density;
	vec2 cell = floor(star_grid);
	vec2 local = fract(star_grid) - 0.5;
	float seed = hash21(cell);
	float presence = smoothstep(threshold, 1.0, seed);
	float point = 1.0 - smoothstep(radius * 0.28, radius, length(local));
	float twinkle = 0.82 + 0.18 * sin(TIME * (0.7 + seed * 1.8) + seed * 31.0);
	return presence * point * twinkle;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = clamp(direction.y, 0.0, 1.0);
	vec3 color = mix(horizon_color, zenith_color, pow(height, 0.42));

	vec2 spherical_uv = vec2(
		atan(direction.z, direction.x) / 6.2831853 + 0.5,
		asin(clamp(direction.y, -1.0, 1.0)) / 3.14159265 + 0.5
	);
	float stars = star_layer(spherical_uv, 720.0, 0.986, 0.105);
	stars += star_layer(spherical_uv + vec2(0.173, 0.391), 390.0, 0.976, 0.085) * 0.55;
	float horizon_fade = smoothstep(0.055, 0.30, direction.y);
	vec3 star_color = mix(vec3(0.62, 0.72, 1.0), vec3(1.0, 0.91, 0.72), hash21(floor(spherical_uv * 390.0)));

	float cloud_plane_height = max(direction.y, 0.16);
	vec2 cloud_uv = direction.xz / cloud_plane_height * 1.85;
	cloud_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.23);
	float cloud_shape = fractal_noise(cloud_uv);
	float cloud_mask = smoothstep(0.54, 0.78, cloud_shape);
	cloud_mask *= smoothstep(0.10, 0.30, direction.y) * (1.0 - smoothstep(0.91, 1.0, direction.y));
	float cloud_detail = fractal_noise(cloud_uv * 2.6 + 8.3);
	vec3 cloud_color = mix(cloud_dark, cloud_light, cloud_detail);
	color += star_color * stars * horizon_fade * (1.0 - cloud_mask * 0.92) * 3.1;
	color = mix(color, cloud_color, cloud_mask * 0.52);

	vec3 moon_dir = normalize(moon_direction);
	float moon_alignment = dot(direction, moon_dir);
	vec3 moon_right = normalize(cross(vec3(0.0, 1.0, 0.0), moon_dir));
	vec3 moon_up = normalize(cross(moon_dir, moon_right));
	vec2 moon_uv = vec2(dot(direction, moon_right), dot(direction, moon_up)) / 0.036;
	float moon_radius = length(moon_uv);
	float moon_disk = 1.0 - smoothstep(0.91, 1.0, moon_radius);
	float lunar_detail = fractal_noise(moon_uv * 2.35 + vec2(14.2, 3.8));
	float crater_detail = fractal_noise(moon_uv * 6.7 + vec2(2.4, 17.1));
	vec3 moon_surface = mix(vec3(0.72, 0.79, 0.93), vec3(1.0, 0.98, 0.88), lunar_detail);
	moon_surface *= mix(0.72, 1.08, crater_detail);
	float near_halo = smoothstep(0.9932, 0.9995, moon_alignment);
	float far_halo = smoothstep(0.955, 0.998, moon_alignment);
	float cloud_occlusion = 1.0 - cloud_mask * 0.58;
	color += vec3(0.30, 0.42, 0.88) * far_halo * 0.045;
	color += vec3(0.55, 0.68, 1.0) * near_halo * 0.16;
	color = mix(color, moon_surface * 1.35, moon_disk * cloud_occlusion);

	COLOR = color;
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("moon_direction", MOON_DIRECTION.normalized())
	var result := Sky.new()
	result.sky_material = sky_material
	result.process_mode = Sky.PROCESS_MODE_REALTIME
	result.radiance_size = Sky.RADIANCE_SIZE_256
	return result
