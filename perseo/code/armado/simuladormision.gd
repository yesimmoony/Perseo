class_name SimuladorMision
extends RefCounted

# --- SIMULACION DE VUELO ---
static func evaluar_ensamble(piezas_instaladas: Array[String]) -> Dictionary:
	var resultado := {
		"exito": false,
		"etapa_fallo": "",
		"informe": "",
		"datos_atmosfericos": {}
	}

	var tiene_chasis := false
	var tiene_rcs := false
	var tiene_sensor_radio := false
	var tipo_cofia := ""
	var tipo_panel := ""
	var masa_total := 0.0

	for id_pieza in piezas_instaladas:
		if not DatosPiezas.CATALOGO.has(id_pieza):
			continue
		var datos: Dictionary = DatosPiezas.CATALOGO[id_pieza]
		masa_total += float(datos.get("masa_kg", 0.0))

		match datos["tipo"]:
			DatosPiezas.TipoPieza.CHASIS:
				tiene_chasis = true
			DatosPiezas.TipoPieza.COFIA:
				tipo_cofia = id_pieza
			DatosPiezas.TipoPieza.PANEL_SOLAR:
				tipo_panel = id_pieza
			DatosPiezas.TipoPieza.PROPULSION:
				tiene_rcs = true
			DatosPiezas.TipoPieza.INSTRUMENTO:
				if bool(datos.get("es_clave_atmosfera", false)):
					tiene_sensor_radio = true

	# 1. Comprobar chasis
	if not tiene_chasis:
		resultado["etapa_fallo"] = "ENSAMBLE INCOMPLETO"
		resultado["informe"] = "Falta el cuerpo estructural base de la sonda."
		return resultado

	# 2. Comprobar eyección de cofia (Fallo histórico de Mariner 3)
	if tipo_cofia == "cofia_fibra_vidrio":
		resultado["etapa_fallo"] = "ASCENSO ORBITAL (T+00:15)"
		resultado["informe"] = "FALLO TIPO MARINER 3: La cofia de fibra de vidrio no se desprendio por deformacion termica. Los paneles solares no pudieron desplegarse. Bateria agotada a las 9 horas de vuelo."
		return resultado
	elif tipo_cofia == "":
		resultado["etapa_fallo"] = "LANZAMIENTO"
		resultado["informe"] = "La sonda se destruyo por presion dinamica al ascender sin cofia protectora."
		return resultado

	# 3. Comprobar estabilización de actitud
	if not tiene_rcs:
		resultado["etapa_fallo"] = "TRAYECTORIA INTERPLANETARIA"
		resultado["informe"] = "Sin toberas RCS de gas frio, la sonda comenzo a rotar sin control. Los paneles solares perdieron la orientacion al Sol."
		return resultado

	# 4. Comprobar balance de energía (Ley del inverso al cuadrado 1/r²)
	# A 1.52 UA (Marte), la radiación solar cae al 43%
	if tipo_panel == "paneles_dobles_fijos":
		resultado["etapa_fallo"] = "ESPACIO PROFUNDO (1.25 UA)"
		resultado["informe"] = "FALLO ENERGETICO: A 1.25 UA del Sol la radiacion bajo demasiado. Dos paneles fijos no alcanzaron a recargar la bateria. Sonda apagada por baja tension."
		return resultado
	elif tipo_panel == "":
		resultado["etapa_fallo"] = "INYECCION TRANS-MARCIANA"
		resultado["informe"] = "La sonda agoto su bateria interna antes de alcanzar la orbita de Marte por no tener paneles solares."
		return resultado

	# 5. Comprobar carga útil científica
	if not tiene_sensor_radio:
		resultado["exito"] = false
		resultado["etapa_fallo"] = "SOBREVUELO MARCIANO"
		resultado["informe"] = "La sonda llego a Marte intacta, pero no contaba con el Transmisor de Radio-Ocultacion para medir la refraccion atmosferica. Mision sin datos utiles."
		return resultado

	# Exito rotundo (Tipo Mariner 4)
	resultado["exito"] = true
	resultado["etapa_fallo"] = "MISIÓN CUMPLIDA"
	resultado["informe"] = "EXITO TIPO MARINER 4: Despliegue correcto, trayectoria estable y sobrevuelo exitoso. Senales de radio atravesaron la atmosfera marciana."
	resultado["datos_atmosfericos"] = {
		"presion_superficie": "6.1 mbar",
		"densidad_relativa": "0.6% respecto a la Tierra",
		"composicion": "95.3% CO2, 2.7% N2, 1.6% Ar"
	}
	return resultado
