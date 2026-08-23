shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.15, 0.15, 0.15);
uniform vec3 grid_color : source_color = vec3(0.25, 0.25, 0.25);
uniform float grid_size : hint_range(0.1, 10.0) = 1.0;
uniform float line_thickness : hint_range(0.001, 0.5) = 0.05;

void fragment() {
	vec2 pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 grid = fract(pos / grid_size);
	
	// Create lines on the edges of the grid cells
	float x_line = step(grid.x, line_thickness) + step(1.0 - line_thickness, grid.x);
	float y_line = step(grid.y, line_thickness) + step(1.0 - line_thickness, grid.y);
	
	float is_line = clamp(x_line + y_line, 0.0, 1.0);
	
	ALBEDO = mix(base_color, grid_color, is_line);
}
