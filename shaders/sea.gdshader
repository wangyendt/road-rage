shader_type spatial;
render_mode cull_disabled;
varying vec2 water_uv;
void vertex() {
	water_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}
void fragment() {
	float waves=sin(water_uv.x*0.22+water_uv.y*0.40+TIME*1.3)*sin(water_uv.y*0.11-TIME*0.8);
	float crest=smoothstep(0.65,1.0,waves);
	ALBEDO=mix(vec3(0.025,0.20,0.28),vec3(0.19,0.52,0.57),crest*0.65);
	ROUGHNESS=0.34;
	METALLIC=0.18;
	NORMAL=normalize(NORMAL+vec3(waves*0.09,0.0,cos(water_uv.x*0.3+TIME)*0.05));
}
