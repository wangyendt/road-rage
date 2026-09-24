shader_type spatial;
uniform vec4 tint : source_color = vec4(0.09,0.15,0.21,1.0);
uniform vec4 light_color : source_color = vec4(0.54,0.78,0.91,1.0);
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)) + seed)*43758.5453); }
void fragment() {
	vec2 grid = UV * vec2(9.0,23.0);
	vec2 cell = fract(grid);
	float window = step(0.19,cell.x)*step(cell.x,0.72)*step(0.22,cell.y)*step(cell.y,0.67);
	float lit = step(0.61,hash(floor(grid)))*window;
	ALBEDO = mix(tint.rgb,vec3(0.055,0.11,0.16),window);
	EMISSION = light_color.rgb*lit*1.6;
	ROUGHNESS = 0.7;
}
