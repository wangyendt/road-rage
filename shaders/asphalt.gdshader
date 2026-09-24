shader_type spatial;
uniform float wetness = 0.0;
uniform vec4 base_tint : source_color = vec4(0.046,0.061,0.078,1.0);
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
void fragment() {
	float grain = texture(grain_texture,UV*vec2(5.0,10.0)).r;
	float wear = pow(abs(sin(UV.x*12.56637)),10.0);
	ALBEDO = base_tint.rgb + grain*0.009 + wear*0.007;
	ROUGHNESS = mix(0.73+grain*0.16,0.24+grain*0.08,wetness);
	METALLIC = 0.12;
}
