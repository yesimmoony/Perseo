extends MeshInstance3D

@export var resolucion_pantalla: Vector2i = Vector2i(1024, 768)
@export var color_orbita: Color = Color(0.2, 0.7, 1.0, 1.0) # Cyan limpio (Estilo KSP)
@export var color_escape: Color = Color(1.0, 0.7, 0.2, 1.0) # Naranja/Amarillo para escapes
@export var inclinacion_3d: float = 0.65
@export var giro_vista_3d: float = 0.5

@onready var cabina: Node3D = get_parent()

var viewport: SubViewport
var lienzo_2d: Control

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = resolucion_pantalla
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	
	lienzo_2d = Control.new()
	lienzo_2d.custom_minimum_size = Vector2(resolucion_pantalla)
	lienzo_2d.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo_2d.draw.connect(_dibujar_radar_ksp)
	viewport.add_child(lienzo_2d)
	
	var mat_crt = StandardMaterial3D.new()
	mat_crt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_crt.albedo_texture = viewport.get_texture()
	material_override = mat_crt

func _process(_delta: float) -> void:
	if lienzo_2d:
		lienzo_2d.queue_redraw()

func _dibujar_radar_ksp() -> void:
	var centro = Vector2(resolucion_pantalla) * 0.5
	var radio_pantalla = resolucion_pantalla.y * 0.45
	
	# Fondo oscuro del espacio (como el Map View de KSP)
	lienzo_2d.draw_rect(Rect2(Vector2.ZERO, Vector2(resolucion_pantalla)), Color(0.01, 0.01, 0.02), true)
	
	if not cabina or not cabina.marte_ref:
		return
		
	var main_node = get_tree().get_root().find_child("Perseo", true, false)
	if not main_node:
		return
		
	# 1. Obtener posiciones reales absolutas
	var pos_marte_real = FisicasPlanetas.get_planet_pos_real_au("marte", main_node.sim_time) * main_node.escala_distancias
	var pos_nave_real = main_node.pos_virtual_nave
	var vel_nave = cabina.velocidad_nave
	var mu = 4500.0 # Gravedad calibrada en cabina.gd
	var radio_marte = cabina.radio_marte
	
	var r_vec = pos_nave_real - pos_marte_real
	var r_mag = r_vec.length()
	var v_mag_sq = vel_nave.length_squared()
	
	# 2. Matemática orbital: Semieje mayor (a) y Energía (E)
	var energia = (v_mag_sq / 2.0) - (mu / r_mag)
	var a = -mu / (2.0 * energia) if abs(energia) > 0.0001 else r_mag * 10.0
	
	var excentricidad = 0.0
	var h_vec = r_vec.cross(vel_nave)
	var h_mag = h_vec.length()
	if mu > 0:
		excentricidad = sqrt(max(0.0, 1.0 + (2.0 * energia * (h_mag * h_mag)) / (mu * mu)))
	
	# AUTO-ZOOM Inteligente: Basado en el Apoapsis para que nunca se salga de la pantalla
	var apoapsis = a * (1.0 + excentricidad) if energia < 0.0 else r_mag * 3.0
	var rango_vision = max(apoapsis * 1.15, radio_marte * 2.5)
	var factor_escala = radio_pantalla / rango_vision
	
	# 3. Dibujar MARTE en el Centro 
	var r_marte_px = max(radio_marte * factor_escala, 15.0)
	lienzo_2d.draw_circle(centro, r_marte_px, Color(0.25, 0.25, 0.3)) # Planeta sólido
	lienzo_2d.draw_arc(centro, r_marte_px, 0, TAU, 64, Color(0.6, 0.6, 0.6), 2.0, true) # Borde
	lienzo_2d.draw_string(ThemeDB.fallback_font, centro + Vector2(-20, r_marte_px + 16), "MARTE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.8,0.8,0.8))
	
	# 4. Predicción Dinámica Kepleriana de Trayectoria
	var pasos = 360
	var dt_prediccion = 1.0
	
	if energia < 0.0 and excentricidad < 1.0:
		# ¡MAGIA KSP! Calculamos el período orbital (T) para cerrar el círculo perfectamente
		var periodo = TAU * sqrt((a * a * a) / mu)
		dt_prediccion = periodo / float(pasos)
	else:
		# Trayectoria de escape
		dt_prediccion = 4.0 
		
	var sim_pos = pos_nave_real
	var sim_vel = vel_nave
	
	var puntos_trayectoria := PackedVector2Array()
	var menor_d = INF
	var mayor_d = 0.0
	var pos_pe_2d = Vector2.ZERO
	var pos_ap_2d = Vector2.ZERO
	
	for i in range(pasos):
		# Simulamos relativo a Marte
		var rel_pos = sim_pos - pos_marte_real
		var d = rel_pos.length()
		
		var pt_2d = _proyectar_3d(rel_pos, factor_escala, centro)
		puntos_trayectoria.append(pt_2d)
		
		# Identificar Periapsis (Pe) y Apoapsis (Ap)
		if d < menor_d:
			menor_d = d
			pos_pe_2d = pt_2d
		if d > mayor_d:
			mayor_d = d
			pos_ap_2d = pt_2d
		
		if d <= radio_marte:
			break # Cesa la trayectoria si choca
			
		var acc_g = -rel_pos.normalized() * (mu / (d * d))
		sim_vel += acc_g * dt_prediccion
		sim_pos += sim_vel * dt_prediccion
		
		if energia >= 0.0 and d > rango_vision * 1.5:
			break # Deja de calcular si escapa del radar
			
	# 5. Dibujar la línea de Órbita
	var col_linea = color_orbita if energia < 0.0 else color_escape
	if puntos_trayectoria.size() > 1:
		lienzo_2d.draw_polyline(puntos_trayectoria, col_linea, 2.5, true)
		
	# 6. Dibujar Etiquetas KSP (Pe y Ap)
	if menor_d > radio_marte:
		lienzo_2d.draw_circle(pos_pe_2d, 4.0, Color(0.1, 0.8, 1.0))
		lienzo_2d.draw_string(ThemeDB.fallback_font, pos_pe_2d + Vector2(6, -6), "Pe", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.8, 1.0))
		
	if energia < 0.0 and excentricidad > 0.02:
		lienzo_2d.draw_circle(pos_ap_2d, 4.0, Color(1.0, 0.8, 0.1))
		lienzo_2d.draw_string(ThemeDB.fallback_font, pos_ap_2d + Vector2(6, -6), "Ap", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.1))
		
	# 7. Dibujar el Icono de la Nave Actual
	var pos_nave_2d = _proyectar_3d(r_vec, factor_escala, centro)
	lienzo_2d.draw_circle(pos_nave_2d, 5.0, Color(1, 1, 1))
	
	# UI Superior
	var estado_orbita = "ÓRBITA ESTABLE CAPTURADA" if energia < 0.0 else "TRAYECTORIA DE ESCAPE"
	lienzo_2d.draw_string(ThemeDB.fallback_font, Vector2(20, 35), "MAPA ORBITAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col_linea)
	lienzo_2d.draw_string(ThemeDB.fallback_font, Vector2(20, 60), estado_orbita, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col_linea)

func _proyectar_3d(v: Vector3, factor_escala: float, centro: Vector2) -> Vector2:
	# Proyección isométrica suave para sensación de espacio 3D
	v *= factor_escala
	var rx = v.x * cos(giro_vista_3d) - v.z * sin(giro_vista_3d)
	var rz = v.x * sin(giro_vista_3d) + v.z * cos(giro_vista_3d)
	var py = rz * sin(inclinacion_3d) - v.y * cos(inclinacion_3d)
	return centro + Vector2(rx, py)
