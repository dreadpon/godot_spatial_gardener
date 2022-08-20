shader_type spatial;
render_mode blend_mix,cull_disabled,unshaded,depth_draw_opaque,depth_test_disable;


// Base color + opacity
uniform vec4 albedo : hint_color;


void fragment() {
	ALBEDO = albedo.rgb;
	
	if (length(UV - vec2(0.5)) > 0.5) {
		discard;
	}
	
	// Fancy dithered alpha stuff
	float opacity = albedo.a;
	int x = int(FRAGCOORD.x) % 4;
	int y = int(FRAGCOORD.y) % 4;
	int index = x + y * 4;
	float limit = 0.0;
	
	if (x < 8) {
		if (index == 0) limit = 0.0625;
		if (index == 1) limit = 0.5625;
		if (index == 2) limit = 0.1875;
		if (index == 3) limit = 0.6875;
		if (index == 4) limit = 0.8125;
		if (index == 5) limit = 0.3125;
		if (index == 6) limit = 0.9375;
		if (index == 7) limit = 0.4375;
		if (index == 8) limit = 0.25;
		if (index == 9) limit = 0.75;
		if (index == 10) limit = 0.125;
		if (index == 11) limit = 0.625;
		if (index == 12) limit = 1.0;
		if (index == 13) limit = 0.5;
		if (index == 14) limit = 0.875;
		if (index == 15) limit = 0.375;
	}
	// Skip drawing a pixel below the opacity limit
	if (opacity < limit)
		discard;
}
