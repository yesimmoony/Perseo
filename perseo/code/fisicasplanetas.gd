extends Node

const VISUAL_SCALE: float = 10.0

const PLANETS = {
	"sol":      {"name": "Sol",      "a": 0.0,    "e": 0.0,   "i": 0.0, "rad": 3.0},
	"mercurio": {"name": "Mercurio", "a": 0.387,  "e": 0.205, "i": 7.0, "rad": 0.4,  "T": 0.24,  "M0": 174.79, "W": 48.33,  "w": 29.12},
	"venus":    {"name": "Venus",    "a": 0.723,  "e": 0.007, "i": 3.4, "rad": 0.95, "T": 0.615, "M0": 50.11,  "W": 76.68,  "w": 54.88},
	"tierra":   {"name": "Tierra",   "a": 1.000,  "e": 0.016, "i": 0.0, "rad": 1.0,  "T": 1.0,   "M0": 357.53, "W": -11.26, "w": 102.94},
	"marte":    {"name": "Marte",    "a": 1.524,  "e": 0.093, "i": 1.8, "rad": 0.53, "T": 1.88,  "M0": 19.37,  "W": 49.56,  "w": 286.50},
	"jupiter":  {"name": "Júpiter",  "a": 5.204,  "e": 0.048, "i": 1.3, "rad": 2.2,  "T": 11.86, "M0": 20.02,  "W": 100.46, "w": 273.87},
	"saturno":  {"name": "Saturno",  "a": 9.582,  "e": 0.056, "i": 2.5, "rad": 1.8,  "T": 29.46, "M0": 317.02, "W": 113.67, "w": 339.39},
	"urano":    {"name": "Urano",    "a": 19.201, "e": 0.046, "i": 0.8, "rad": 1.4,  "T": 84.01, "M0": 142.24, "W": 74.01,  "w": 96.99},
	"neptuno":  {"name": "Neptuno",  "a": 30.047, "e": 0.009, "i": 1.8, "rad": 1.4,  "T": 164.79,"M0": 256.23, "W": 131.78, "w": 273.19}
}

const MOONS = {
	"tierra": [
		{"name": "Luna", "dist_factor": 2.5, "rad_ratio": 0.27, "T_days": 27.32, "i": 5.14}
	],
	"marte": [
		{"name": "Fobos",  "dist_factor": 1.6, "rad_ratio": 0.08, "T_days": 0.318, "i": 1.09},
		{"name": "Deimos", "dist_factor": 2.4, "rad_ratio": 0.05, "T_days": 1.262, "i": 1.79}
	],
	"jupiter": [
		{"name": "Ío",        "dist_factor": 1.8, "rad_ratio": 0.12, "T_days": 1.769,  "i": 0.05},
		{"name": "Europa",    "dist_factor": 2.4, "rad_ratio": 0.10, "T_days": 3.551,  "i": 0.47},
		{"name": "Ganímedes", "dist_factor": 3.2, "rad_ratio": 0.15, "T_days": 7.155,  "i": 0.20},
		{"name": "Cálisto",   "dist_factor": 4.2, "rad_ratio": 0.14, "T_days": 16.689, "i": 0.28}
	],
	"saturno": [
		{"name": "Mimas",     "dist_factor": 1.6, "rad_ratio": 0.06, "T_days": 0.942,  "i": 1.57},
		{"name": "Encélado",  "dist_factor": 2.0, "rad_ratio": 0.07, "T_days": 1.370,  "i": 0.02},
		{"name": "Tetis",     "dist_factor": 2.4, "rad_ratio": 0.09, "T_days": 1.888,  "i": 1.12},
		{"name": "Dione",     "dist_factor": 2.8, "rad_ratio": 0.09, "T_days": 2.737,  "i": 0.02},
		{"name": "Rea",       "dist_factor": 3.4, "rad_ratio": 0.11, "T_days": 4.518,  "i": 0.34},
		{"name": "Titán",     "dist_factor": 4.4, "rad_ratio": 0.22, "T_days": 15.945, "i": 0.35},
		{"name": "Japeto",    "dist_factor": 5.8, "rad_ratio": 0.10, "T_days": 79.321, "i": 15.47}
	],
	"urano": [
		{"name": "Miranda",   "dist_factor": 1.7, "rad_ratio": 0.07, "T_days": 1.413,  "i": 4.23},
		{"name": "Ariel",     "dist_factor": 2.2, "rad_ratio": 0.10, "T_days": 2.520,  "i": 0.26},
		{"name": "Umbriel",   "dist_factor": 2.7, "rad_ratio": 0.10, "T_days": 4.144,  "i": 0.20},
		{"name": "Titania",   "dist_factor": 3.4, "rad_ratio": 0.13, "T_days": 8.706,  "i": 0.34},
		{"name": "Oberón",    "dist_factor": 4.2, "rad_ratio": 0.12, "T_days": 13.463, "i": 0.06}
	],
	"neptuno": [
		{"name": "Proteo",    "dist_factor": 1.8, "rad_ratio": 0.08, "T_days": 1.122,  "i": 0.55},
		{"name": "Tritón",    "dist_factor": 2.8, "rad_ratio": 0.18, "T_days": -5.877, "i": 156.8},
		{"name": "Nereida",   "dist_factor": 4.8, "rad_ratio": 0.06, "T_days": 360.13, "i": 7.23}
	]
}

func get_planet_pos_real_au(key: String, time_yr: float) -> Vector3:
	if not PLANETS.has(key):
		return Vector3.ZERO
		
	var p: Dictionary = PLANETS[key]
	
	# Retorna (0,0,0) inmediatamente si es el Sol antes de pedir variables de órbita
	if float(p["a"]) == 0.0:
		return Vector3.ZERO
		
	var M: float = deg_to_rad(float(p["M0"])) + (2.0 * PI / float(p["T"])) * time_yr
	var E: float = M
	for j in 5:
		E = M + float(p["e"]) * sin(E)
		
	var v: float = 2.0 * atan(sqrt((1.0 + float(p["e"])) / (1.0 - float(p["e"]))) * tan(E / 2.0))
	var r: float = float(p["a"]) * (1.0 - float(p["e"]) * cos(E))
	
	var W_rad: float = deg_to_rad(float(p["W"]))
	var w_rad: float = deg_to_rad(float(p["w"]))
	var i_rad: float = deg_to_rad(float(p["i"]))
	
	var x_orb: float = r * cos(v)
	var y_orb: float = r * sin(v)
	
	var x: float = x_orb * (cos(w_rad) * cos(W_rad) - sin(w_rad) * cos(i_rad) * sin(W_rad)) - y_orb * (sin(w_rad) * cos(W_rad) + cos(w_rad) * cos(i_rad) * sin(W_rad))
	var z: float = x_orb * (cos(w_rad) * sin(W_rad) + sin(w_rad) * cos(i_rad) * cos(W_rad)) + y_orb * (cos(w_rad) * cos(i_rad) * cos(W_rad) - sin(w_rad) * sin(W_rad))
	var y: float = x_orb * (sin(w_rad) * sin(i_rad)) + y_orb * (cos(w_rad) * sin(i_rad))
	
	return Vector3(x, y, z) * VISUAL_SCALE
