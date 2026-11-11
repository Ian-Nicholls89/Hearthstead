shader_type spatial;
// Vertex-coloured low-poly look shared by terrain, trees, buildings and people.
// `snow` whitens upward faces in winter; `leaf_tint` turns green leaves autumnal.
render_mode cull_back, specular_disabled;

uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 leaf_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
varying float up;

void vertex() {
	up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float leaf = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	c = mix(c, leaf_tint.rgb * (0.6 + c.g), leaf * leaf_tint.a);
	c = mix(c, vec3(0.92, 0.94, 0.98), snow * smoothstep(0.45, 0.85, up));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
