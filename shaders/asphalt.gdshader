shader_type spatial;
uniform vec4 base_tint : source_color = vec4(0.046,0.061,0.078,1.0);
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
void fragment() {
	float grain = texture(grain_texture,UV*vec2(5.0,10.0)).r;
	float wear = pow(abs(sin(UV.x*12.56637)),10.0);
	ALBEDO = base_tint.rgb + grain*0.009 + wear*0.007;
	ROUGHNESS = 0.73+grain*0.16;
	METALLIC = 0.12;
}
