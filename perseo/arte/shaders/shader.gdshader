shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// --- CONTROLES EDITABLES EN EL INSPECTOR (Shader Parameters) ---
group_uniforms Grano_Y_Textura;
uniform float intensidad_grano : hint_range(0.0, 0.3, 0.005) = 0.03;
uniform float velocidad_estatica : hint_range(0.0, 5.0, 0.1) = 0.0; // 0.0 = Grano fijo de ilustración | >0 = Estática de TV
uniform float fuerza_lineas : hint_range(0.0, 0.2, 0.005) = 0.015;

group_uniforms Efecto_Holografico;
uniform float fuerza_aberracion : hint_range(0.0, 5.0, 0.1) = 1.0;
uniform float proteger_centro : hint_range(0.0, 1.0, 0.05) = 0.7; // Mantiene nítido el centro de la pantalla

group_uniforms Color_Y_Brillo;
uniform float brillo : hint_range(0.5, 1.5, 0.05) = 0.95;
uniform float contraste : hint_range(0.5, 2.0, 0.05) = 1.05;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 1. Aberración cromática (con opción de mantener el centro limpio)
	float dist_centro = distance(uv, vec2(0.5));
	float factor_borde = mix(1.0, dist_centro * 1.8, proteger_centro);
	vec2 px = SCREEN_PIXEL_SIZE * fuerza_aberracion * factor_borde;
	
	float r = texture(screen_tex, uv + vec2(px.x, -px.y)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(px.x, -px.y)).b;
	vec3 col = vec3(r, g, b);
	
	// 2. Líneas de tramado
	float scanline = sin(FRAGCOORD.y * 1.8 + FRAGCOORD.x * 0.5) * fuerza_lineas;
	col -= scanline;
	
	// 3. Grano (Fijo si velocidad_estatica es 0.0, animado si es mayor a 0.0)
	vec2 semilla = uv;
	if (velocidad_estatica > 0.0) {
		semilla += fract(TIME * velocidad_estatica);
	}
	float ruido = (random(semilla) - 0.5) * 2.0;
	col += ruido * intensidad_grano;
	
	// 4. Ajuste de brillo y contraste sin quemar los blancos
	col = clamp(col * brillo, 0.0, 1.0);
	col = clamp((col - 0.5) * contraste + 0.5, 0.0, 1.0);
	
	COLOR = vec4(col, 1.0);
}