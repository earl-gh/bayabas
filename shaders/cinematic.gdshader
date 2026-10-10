shader_type canvas_item;
// Film finish over the match view (under the HUD), after the sanga intro frames:
// a shallow depth of field (the far top of the picture and the very bottom go
// soft, the hero's band stays sharp), a warm-highlights / cool-shadows split tone,
// a soft vignette and a fine moving grain.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float focus_center = 0.56;
uniform float focus_half_band = 0.2;
uniform float max_blur = 1.6;
uniform float vignette = 0.32;
uniform float grain = 0.03;
uniform vec3 shadow_tint = vec3(0.95, 0.99, 1.07);
uniform vec3 highlight_tint = vec3(1.05, 1.0, 0.93);

void fragment() {
	vec2 uv = SCREEN_UV;
	float off_focus = max(abs(uv.y - focus_center) - focus_half_band, 0.0);
	// the far top goes softer than the near bottom, like a real lens looking down
	float lod = smoothstep(0.0, 0.32, off_focus) * max_blur * (uv.y < focus_center ? 1.0 : 0.6);
	vec3 color = textureLod(screen_texture, uv, lod).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color *= mix(shadow_tint, highlight_tint, smoothstep(0.25, 0.8, luma));
	vec2 centered = uv - vec2(0.5);
	centered.x *= 0.75;
	color *= 1.0 - smoothstep(0.32, 0.86, length(centered)) * vignette;
	float noise = fract(sin(dot(uv * vec2(1280.0, 720.0) + vec2(TIME * 61.0, TIME * 17.0), vec2(12.9898, 78.233))) * 43758.5453);
	color += (noise - 0.5) * grain;
	COLOR = vec4(color, 1.0);
}
