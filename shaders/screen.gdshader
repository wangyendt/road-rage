shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float boost = 0.0;
uniform float damage = 0.0;
uniform float hit = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv - vec2(0.5);
	float edge = smoothstep(0.20,0.72,length(p));
	// Protect the middle 40% of the frame, including the landing road.
	float side = smoothstep(0.20,0.44,abs(p.x));
	vec2 direction = uv - vec2(0.5,0.43);
	vec2 shift = p * boost * side * 0.004;
	vec3 col = texture(screen_texture,uv).rgb;
	if (boost > 0.001 && side > 0.001) {
		// Directional multi-tap screen-space blur, not temporal/velocity motion blur.
		vec3 smear = col;
		for (int i=1; i<=12; i++) {
			vec2 sample_uv = clamp(uv-direction*float(i)*0.010*boost*side,vec2(0.001),vec2(0.999));
			smear += texture(screen_texture,sample_uv).rgb;
		}
		col = mix(col,smear/13.0,0.96*side*boost);
		col.r += (texture(screen_texture,uv+shift).r-texture(screen_texture,uv).r)*0.2;
		col.b += (texture(screen_texture,uv-shift).b-texture(screen_texture,uv).b)*0.2;
	}
	col *= 1.0 - edge*0.25;
	col += vec3(0.0,0.16,0.22)*boost*side;
	col = mix(col,vec3(0.85,0.07,0.04),edge*damage*0.6);
	col += vec3(0.10,0.07,0.035)*hit;
	COLOR = vec4(col,1.0);
}
