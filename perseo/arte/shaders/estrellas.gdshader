shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// --- CONTROLES EDITABLES EN EL INSPECTOR ---
group_uniforms Tamano_Estrellas;
uniform float escala_general : hint_range(0.5, 20.0, 0.5) = 4.0;
uniform float multiplicador_gigantes : hint_range(1.0, 15.0, 0.5) = 5.0; // Hace que algunas estrellas sean enormes
uniform float cantidad_gigantes : hint_range(0.0, 0.5, 0.02) = 0.12;     // Porcentaje de estrellas gigantes (0.12 = 12%)

group_uniforms Forma_4_Picos;
uniform float filo_picos : hint_range(0.2, 0.8, 0.02) = 0.38;     // Más bajo = picos más finos y marcados
uniform float suavidad_borde : hint_range(0.02, 0.5, 0.02) = 0.15; // Más bajo = borde más duro y definido
uniform float inclinacion_max : hint_range(0.0, 1.5, 0.05) = 0.25;

group_uniforms Color_Y_Efectos;
uniform float brillo_estrella : hint_range(0.2, 5.0, 0.1) = 1.4;
uniform float desfase_arcoiris : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float fuerza_glitch_vertical : hint_range(0.0, 1.0, 0.05) = 0.35;

uniform vec3 col_nucleo : source_color = vec3(1.0, 1.0, 0.9);
uniform vec3 col_borde_1 : source_color = vec3(1.0, 0.15, 0.75); // Magenta
uniform vec3 col_borde_2 : source_color = vec3(0.1, 0.85, 1.0);  // Cian
uniform vec3 col_borde_3 : source_color = vec3(1.0, 0.75, 0.1);  // Amarillo/Naranja

// Distancia exacta de astroide para que los 4 picos lleguen siempre al borde
float estrella_4_picos(vec2 p, float k) {
	p = abs(p) + vec2(0.0001);
	return pow(pow(p.x, k) + pow(p.y, k), 1.0 / k);
}

void vertex() {
	// Detectamos con el valor aleatorio de la partícula si le toca ser una "Estrella Gigante"
	float es_gigante = step(1.0 - cantidad_gigantes, COLOR.b);
	float factor_tamano = escala_general * mix(1.0, multiplicador_gigantes, es_gigante);
	
	// Billboard mirando siempre a la cámara
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz) * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz) * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz) * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	
	// Agrandamos el plano directamente desde el shader
	VERTEX *= factor_tamano;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	
	// Rotación leve por estrella
	float angulo = (COLOR.r - 0.5) * inclinacion_max;
	float s = sin(angulo);
	float c = cos(angulo);
	vec2 p = mat2(vec2(c, -s), vec2(s, c)) * uv;
	
	// Parpadeo suave
	float parpadeo = 0.9 + 0.1 * sin(TIME * 2.5 + COLOR.g * 20.0);
	p /= parpadeo;
	
	// 1. Forma de 4 picos con desfase cromático (Magenta / Centro / Cian)
	float d_centro = estrella_4_picos(p, filo_picos);
	float d_mag = estrella_4_picos(p - vec2(desfase_arcoiris, -desfase_arcoiris * 0.6), filo_picos);
	float d_cian = estrella_4_picos(p + vec2(desfase_arcoiris, -desfase_arcoiris * 0.6), filo_picos);
	
	// Máscaras con los 4 picos llegando hasta 0.92 del tamaño del cuadro
	float radio_picos = 0.92;
	float nucleo = 1.0 - smoothstep(radio_picos * 0.25, radio_picos * 0.65, d_centro);
	float cuerpo_amarillo = 1.0 - smoothstep(radio_picos - suavidad_borde, radio_picos, d_centro);
	float borde_mag = 1.0 - smoothstep(radio_picos - suavidad_borde, radio_picos + 0.05, d_mag);
	float borde_ci = 1.0 - smoothstep(radio_picos - suavidad_borde, radio_picos + 0.05, d_cian);
	
	// 2. Rayas verticales estilo ilustración retro
	float lineas_v = fract(sin(uv.x * 120.0) * 43758.5453);
	float mascara_barrido = (1.0 - smoothstep(0.0, 0.28, abs(p.x))) * (1.0 - smoothstep(0.0, 0.9, abs(uv.y)));
	float glitch = step(0.6, lineas_v) * mascara_barrido * fuerza_glitch_vertical;
	
	// 3. Mezcla de color iridiscente
	vec3 col = vec3(0.0);
	col += col_borde_1 * (borde_mag + glitch * 0.8);
	col += col_borde_2 * (borde_ci + glitch);
	col += col_borde_3 * cuerpo_amarillo;
	col = mix(col, col_nucleo * 1.5, nucleo);
	
	float alpha = clamp(max(max(borde_mag, borde_ci), max(cuerpo_amarillo, glitch)), 0.0, 1.0);
	float recorte_borde = 1.0 - smoothstep(0.92, 1.0, max(abs(uv.x), abs(uv.y)));
	
	ALBEDO = col * brillo_estrella;
	ALPHA = alpha * recorte_borde;
}