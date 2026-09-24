shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float boost = 0.0;
uniform float damage = 0.0;
uniform float hit = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv - vec2(0.5);
	float edge = smoothstep(0.20,0.72,length(p));
	vec2 shift = p * boost * edge * 0.004;
	vec3 col = texture(screen_texture,uv).rgb;
	col.r = texture(screen_texture,uv+shift).r;
	col.b = texture(screen_texture,uv-shift).b;
	col *= 1.0 - edge*0.25;
	col += vec3(0.0,0.11,0.15)*boost*edge;
	col = mix(col,vec3(0.85,0.07,0.04),edge*damage*0.6);
	col += vec3(0.10,0.07,0.035)*hit;
	COLOR = vec4(col,1.0);
}
