class_name Moon
extends Node3D

var dist_factor: float = 2.5
var period_days: float = 27.32
var inclination_deg: float = 0.0

func setup(moon_data: Dictionary, _planet_rad: float) -> void:
	name = moon_data["name"]
	dist_factor = float(moon_data["dist_factor"])
	period_days = float(moon_data["T_days"])
	inclination_deg = float(moon_data["i"])
	
	var rad_ratio: float = float(moon_data["rad_ratio"])
	scale = Vector3.ONE * rad_ratio

func update_local_position(time_yr: float) -> void:
	var time_days: float = time_yr * 365.25
	var angle: float = (2.0 * PI / period_days) * time_days
	
	var x_local: float = dist_factor * cos(angle)
	var z_local: float = dist_factor * sin(angle)
	var y_local: float = z_local * sin(deg_to_rad(inclination_deg))
	
	position = Vector3(x_local, y_local, z_local)
