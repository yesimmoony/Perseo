class_name DatosPiezas
extends RefCounted

# --- TIPOS DE COMPONENTES ---
enum TipoPieza {
	CHASIS,
	PANEL_SOLAR,
	COFIA,
	PROPULSION,
	INSTRUMENTO
}

# --- CATALOGO DE PIEZAS ---
const CATALOGO: Dictionary = {
	"chasis_octogonal": {
		"nombre": "Chasis Bus Octogonal",
		"tipo": TipoPieza.CHASIS,
		"masa_kg": 60.0,
		"bateria_wh": 1200.0,
		"consumo_base_w": 10.0,
		"descripcion": "Estructura central de aleacion de magnesio con celda de energia."
	},
	"cofia_fibra_vidrio": {
		"nombre": "Cofia de Fibra de Vidrio (Prototipo M-3)",
		"tipo": TipoPieza.COFIA,
		"masa_kg": 45.0,
		"probabilidad_bloqueo": 1.0,
		"descripcion": "Proteccion aerodinamica pesada. Tiende a deformarse bajo presion interna."
	},
	"cofia_metal_aligerada": {
		"nombre": "Cofia Metalica Aligerada (Diseno M-4)",
		"tipo": TipoPieza.COFIA,
		"masa_kg": 22.0,
		"probabilidad_bloqueo": 0.0,
		"descripcion": "Estructura de magnesio con resortes pirotecnicos testeados al vacio."
	},
	"paneles_dobles_fijos": {
		"nombre": "2x Paneles Solares Fijos",
		"tipo": TipoPieza.PANEL_SOLAR,
		"masa_kg": 15.0,
		"potencia_tierra_w": 80.0,
		"descripcion": "Area insuficiente. A 1.5 UA de distancia solar su rendimiento cae al 43%."
	},
	"paneles_cuadruples_aspas": {
		"nombre": "4x Paneles en Cruz con Aspas Solares",
		"tipo": TipoPieza.PANEL_SOLAR,
		"masa_kg": 32.0,
		"potencia_tierra_w": 180.0,
		"descripcion": "Cuatro alas desplegables con aspas de presion de radiacion solar."
	},
	"sistema_rcs_gas_frio": {
		"nombre": "Sistema RCS de Nitrogeno",
		"tipo": TipoPieza.PROPULSION,
		"masa_kg": 18.0,
		"estabilizacion": true,
		"descripcion": "Toberas de gas frio para mantener los paneles apuntando al Sol."
	},
	"sensor_radio_ocultacion": {
		"nombre": "Transmisor de Radio-Ocultacion",
		"tipo": TipoPieza.INSTRUMENTO,
		"masa_kg": 12.0,
		"consumo_w": 30.0,
		"es_clave_atmosfera": true,
		"descripcion": "Mide la refraccion de ondas al pasar tras Marte para deducir presion atmosferica."
	}
}
