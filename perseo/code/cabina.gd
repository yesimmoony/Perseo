extends Node3D

@export_group("Parámetros de Vuelo Realistas")
@export var empuje_motor_principal: float = 25.0
@export var empuje_rcs_freno: float = 14.0
@export var aceleracion_giro_rcs: float = 2.0
@export var amortiguacion_sas: float = 4.0
@export var combustible_delta_v: float = 500.0

@onready var pantalla_telemetria: Label3D = get_node_or_null("PantallaTelemetria")
@onready var pantalla_rcs: Label3D = get_node_or_null("PantallaRCS")
@onready var pantalla_moi: Label3D = get_node_or_null("PantallaMOI")

var marte_ref: Node3D = null
var radio_marte: float = 250.0
var mu_marte: float = 8000.0  # Parámetro gravitacional aumentado para permitir captura orbital realista

var velocidad_nave: Vector3 = Vector3.ZERO
var velocidad_angular_rcs: Vector2 = Vector2.ZERO
var distancia_a_marte: float = 0.0
var altitud_marte: float = 80.0
var aterrizado: bool = false
var en_orbita_capturada: bool = false
var en_vuelo_libre: bool = true

# Modos GNC
enum ModoGNC { LIBRE, CIRCULARIZAR }
var modo_gnc_actual: ModoGNC = ModoGNC.LIBRE

var rcs_up: bool = false
var rcs_down: bool = false
var rcs_left: bool = false
var rcs_right: bool = false
var rcs_freno_frontal: bool = false
var motor_activo: bool = false

var planeta_destino: Node3D = null 

func configurar_aproximacion(nodo_marte: Node3D, visual_rad: float) -> void:
	marte_ref = nodo_marte
	radio_marte = visual_rad
	velocidad_nave = Vector3(-6.0, 0.0, -9.0)
	velocidad_angular_rcs = Vector2.ZERO
	en_orbita_capturada = false
	en_vuelo_libre = true
	
func _physics_process(delta: float) -> void:
	if not en_vuelo_libre or not marte_ref:
		return
	
	rcs_up = false
	rcs_down = false
	rcs_left = false
	rcs_right = false
	rcs_freno_frontal = false
	motor_activo = false
	
	var input_yaw: float = 0.0
	var input_pitch: float = 0.0
	
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_yaw = 1.0; rcs_left = true
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_yaw = -1.0; rcs_right = true
		
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input_pitch = 1.0; rcs_up = true
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input_pitch = -1.0; rcs_down = true
		
	if Input.is_key_pressed(KEY_T) and marte_ref:
		planeta_destino = marte_ref
	
	# --- ASISTENCIA GNC RETROGRADE / TARGET ---
	# --- ASISTENCIA GNC CORREGIDA (RETROGRADE / TARGET) ---
	if Input.is_key_pressed(KEY_CTRL):
		var objetivo_rotacion: Vector3
		
		if planeta_destino != null:
			var main_node = get_tree().get_root().find_child("Perseo", true, false)
			var tiempo_actual = main_node.sim_time if main_node and "sim_time" in main_node else 0.0
			var escala_dist = main_node.escala_distancias if main_node and "escala_distancias" in main_node else 5000.0
			var pos_marte_real = FisicasPlanetas.get_planet_pos_real_au("marte", tiempo_actual) * escala_dist
			
			# Modo TARGET: Mira hacia el centro de Marte
			objetivo_rotacion = pos_marte_real
		else:
			# Modo RETROGRADE: Apunta exactamente opuesto a la dirección de movimiento para frenar
			if velocidad_nave.length() > 0.05:
				objetivo_rotacion = global_position - velocidad_nave.normalized() * 10.0
			else:
				objetivo_rotacion = global_position + global_transform.basis.z
		
		var dir_apunteria = (objetivo_rotacion - global_position).normalized()
		var up_hint = Vector3.UP
		if abs(dir_apunteria.dot(Vector3.UP)) > 0.98:
			up_hint = Vector3.FORWARD
		
		var trans_objetivo = transform.looking_at(objetivo_rotacion, up_hint)
		transform = transform.interpolate_with(trans_objetivo, delta * 5.0)
	else:
		velocidad_angular_rcs.x = lerp(velocidad_angular_rcs.x, input_pitch * aceleracion_giro_rcs, amortiguacion_sas * delta)
		velocidad_angular_rcs.y = lerp(velocidad_angular_rcs.y, input_yaw * aceleracion_giro_rcs, amortiguacion_sas * delta)
		rotate_object_local(Vector3.UP, velocidad_angular_rcs.y * delta)
		rotate_object_local(Vector3.RIGHT, velocidad_angular_rcs.x * delta)
	
	var a_total := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_SPACE) and combustible_delta_v > 0.0:
		motor_activo = true
		aterrizado = false
		a_total += -global_transform.basis.z * empuje_motor_principal
		combustible_delta_v -= (empuje_motor_principal * 0.05) * delta
	
	if (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_X)) and combustible_delta_v > 0.0:
		rcs_freno_frontal = true
		if velocidad_nave.length() > 0.2:
			a_total += -velocidad_nave.normalized() * empuje_rcs_freno
		else:
			velocidad_nave = Vector3.ZERO
		combustible_delta_v -= (empuje_rcs_freno * 0.03) * delta
	
	# --- FÍSICA GRAVITACIONAL SUAVIZADA ---
	if not aterrizado and marte_ref:
		var main_node = get_tree().get_root().find_child("Perseo", true, false)
		if main_node and "sim_time" in main_node:
			var pos_marte_real = FisicasPlanetas.get_planet_pos_real_au("marte", main_node.sim_time) * main_node.escala_distancias
			var pos_nave_real = main_node.pos_virtual_nave
			
			var vec_hacia_marte: Vector3 = pos_marte_real - pos_nave_real
			distancia_a_marte = vec_hacia_marte.length()
			altitud_marte = distancia_a_marte - radio_marte

			if distancia_a_marte > 0.001:
				# Reducimos un poco la fuerza gravitacional bruta para que la órbita sea controlable
				var mu_suavizado = 4500.0 
				var magnitud_gravedad: float = mu_suavizado / (distancia_a_marte * distancia_a_marte)
				a_total += vec_hacia_marte.normalized() * magnitud_gravedad
	
	velocidad_nave += a_total * delta
	
	en_orbita_capturada = aterrizado or (velocidad_nave.length() < 7.0 and altitud_marte > 15.0 and altitud_marte < 700.0)
	_actualizar_pantallas()
	
	if Input.is_key_pressed(KEY_SPACE) and combustible_delta_v > 0.0:
		motor_activo = true
		aterrizado = false
		a_total += -global_transform.basis.z * empuje_motor_principal
		combustible_delta_v -= (empuje_motor_principal * 0.05) * delta
	
	if (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_X)) and combustible_delta_v > 0.0:
		rcs_freno_frontal = true
		if velocidad_nave.length() > 0.2:
			a_total += -velocidad_nave.normalized() * empuje_rcs_freno
		else:
			velocidad_nave = Vector3.ZERO
		combustible_delta_v -= (empuje_rcs_freno * 0.03) * delta
	
	# --- FÍSICA GRAVITACIONAL KEPLERIANA EXACTA ---
	if not aterrizado and marte_ref:
		var main_node = get_tree().get_root().find_child("Perseo", true, false)
		if main_node and "sim_time" in main_node:
			var pos_marte_real = FisicasPlanetas.get_planet_pos_real_au("marte", main_node.sim_time) * main_node.escala_distancias
			var pos_nave_real = main_node.pos_virtual_nave
			
			var vec_hacia_marte: Vector3 = pos_marte_real - pos_nave_real
			distancia_a_marte = vec_hacia_marte.length()
			altitud_marte = distancia_a_marte - radio_marte

			if distancia_a_marte > 0.001:
				var magnitud_gravedad: float = mu_marte / (distancia_a_marte * distancia_a_marte)
				a_total += vec_hacia_marte.normalized() * magnitud_gravedad
				
	velocidad_nave += a_total * delta
	# La posición global interna se mantiene estable; el movimiento real se acumula en el script principal.
	
	en_orbita_capturada = aterrizado or (velocidad_nave.length() < 12.0 and altitud_marte > 10.0 and altitud_marte < 800.0)
	_actualizar_pantallas()

func obtener_datos_orbitales() -> Dictionary:
	if not marte_ref:
		return {"pe": 0.0, "ap": 0.0}
	
	var r: Vector3 = global_position - marte_ref.global_position
	var v: Vector3 = velocidad_nave
	var r_mag: float = r.length()
	var v_mag_sq: float = v.length_squared()
	
	var energia: float = (v_mag_sq / 2.0) - (mu_marte / r_mag)
	var semieje_mayor: float = -mu_marte / (2.0 * energia) if abs(energia) > 0.0001 else 100000.0
	
	var h_vec: Vector3 = r.cross(v)
	var h_mag: float = h_vec.length()
	var excentricidad: float = sqrt(max(0.0, 1.0 + (2.0 * energia * (h_mag * h_mag)) / (mu_marte * mu_marte)))
	
	var periapsis_dist: float = semieje_mayor * (1.0 - excentricidad) - radio_marte
	var apoapsis_dist: float = semieje_mayor * (1.0 + excentricidad) - radio_marte
	
	return {
		"pe": max(0.0, periapsis_dist),
		"ap": max(0.0, apoapsis_dist) if excentricidad < 1.0 else 99999.0
	}

func _actualizar_pantallas() -> void:
	var orbita_info = obtener_datos_orbitales()
	
	if pantalla_telemetria:
		var estado_str := "EN ÓRBITA CAPTURADA" if en_orbita_capturada else ("ATERRIZADO" if aterrizado else "EN APROXIMACIÓN")
		var gnc_status = ">>> GNC RETROGRADE ACTIVO [CTRL] <<<" if Input.is_key_pressed(KEY_CTRL) else "[ GNC EN ESPERA (MANTENER CTRL) ]"
		
		pantalla_telemetria.text = """=== PERSEO I // TELEMETRÍA GNC ===
ESTADO: %s
%s
ALTITUD: %.1f m
PERIÁPSIDE (Pe): %.1f m
APOÁPSIDE (Ap): %.1f m
VELOCIDAD: %.1f m/s
COMBUSTIBLE Δv: %.1f m/s
[ESPACIO]: Motor | [CTRL]: Auto-Alinear Retrograde
""" % [
			estado_str,
			gnc_status,
			max(0.0, altitud_marte),
			orbita_info["pe"],
			orbita_info["ap"],
			velocidad_nave.length(),
			combustible_delta_v
		]
	
	if pantalla_rcs:
		var ind_up := "[ ▲ PITCH ]" if rcs_up else "[    ·    ]"
		var ind_down := "[ ▼ PITCH ]" if rcs_down else "[    ·    ]"
		var ind_left := "[◀ YAW]" if rcs_left else "[ · ]"
		var ind_right := "[YAW ▶]" if rcs_right else "[ · ]"
		var ind_freno := "[ FRENO RCS FRONTAL ACTIVO ]" if rcs_freno_frontal else "[ RCS TRASLACIÓN EN ESPERA ]"
		var ind_motor := ">>> ENCENDIDO <<<" if motor_activo else "[ INERTE ]"
		
		pantalla_rcs.text = """--- SISTEMA RCS (SAS SUAVIZADO) ---

             %s
     %s  [ NAVE ]  %s
             %s
%s
MOTOR PRINCIPAL: %s
""" % [ind_up, ind_left, ind_right, ind_down, ind_freno, ind_motor]
