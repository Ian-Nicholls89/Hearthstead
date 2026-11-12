shader_type spatial;
// Rivers and lakes: colour runs from shallow at the banks to deep in the middle
// (from a per-tile distance-to-land texture), with small waves, a foam line along
// the shore, glints, and ice in winter.
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D shore : filter_linear, repeat_disable;   // 0 at the bank, 1 far from it
uniform vec2 map_size = vec2(96.0, 96.0);
uniform float ice : hint_range(0.0, 1.0) = 0.0;
uniform vec3 deep = vec3(0.12, 0.32, 0.46);
uniform vec3 shallow = vec3(0.24, 0.55, 0.56);
varying vec2 mpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mpos = w.xz;
	float calm = 1.0 - ice;
	VERTEX.y += (sin(w.x * 1.3 + TIME * 1.1) + sin(w.z * 1.7 - TIME * 0.8)) * 0.012 * calm;
}

void fragment() {
	float d = texture(shore, mpos / map_size).r;
	vec3 c = mix(shallow, deep, smoothstep(0.05, 0.6, d));
	float calm = 1.0 - ice;
	float band = smoothstep(0.13, 0.0, d);
	float foam = band * (0.55 + 0.45 * sin(TIME * 1.6 + d * 45.0 + mpos.x * 0.6 + mpos.y * 0.4));
	c = mix(c, vec3(0.86, 0.93, 0.95), foam * 0.65 * calm);
	float glint = pow(max(0.0, sin(mpos.x * 2.3 + TIME * 1.4) * sin(mpos.y * 1.9 - TIME * 1.1)), 16.0);
	c += vec3(glint * 0.25 * calm);
	c = mix(c, vec3(0.78, 0.86, 0.92), ice * 0.9);
	ALBEDO = c;
	ROUGHNESS = mix(0.12, 0.55, ice);
	SPECULAR = 0.55;
	ALPHA = mix(0.84, 0.98, ice);
}
