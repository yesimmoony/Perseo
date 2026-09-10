extends Node3D

@export_group("Escenas del Sistema Solar")
@export var sol: PackedScene
@export var mercurio: PackedScene
@export var venus: PackedScene
@export var tierra: PackedScene
@export var marte: PackedScene
@export var jupiter: PackedScene
@export var saturno: PackedScene
@export var urano: PackedScene
@export var neptuno: PackedScene

@export_group("Satélites")
@export var luna: PackedScene

@export var global_planet_scale: float = 1.0

@onready var orbit_renderer: orbitaRender = $Orbitas

var instances: Dictionary = {}
var moon_instances: Array = []
var sim_time: float = -1.0
@export var time_speed: float = 0.05

func _ready() -> void:
	_spawn_planets()

func _spawn_planets() -> void:
	var planet_scenes := {
		"sol": sol, "mercurio": mercurio, "venus": venus,
		"tierra": tierra, "marte": marte, "jupiter": jupiter,
		"saturno": saturno, "urano": urano, "neptuno": neptuno
	}

	for key in planet_scenes.keys():
		var p_scene: PackedScene = planet_scenes[key]
		if p_scene and FisicasPlanetas.PLANETS.has(key):
			var p_inst = p_scene.instantiate()
			p_inst.name = key.capitalize()
			add_child(p_inst)
			
			var planet_data: Dictionary = FisicasPlanetas.PLANETS[key]
			var visual_rad: float = float(planet_data["rad"]) * global_planet_scale
			p_inst.scale = Vector3.ONE * visual_rad
			p_inst.position = FisicasPlanetas.get_planet_pos_real_au(key, sim_time)
			
			instances[key] = p_inst
			
			_spawn_moons_for_planet(key, p_inst, visual_rad)

func _spawn_moons_for_planet(planet_key: String, planet_node: Node3D, visual_rad: float) -> void:
	if not FisicasPlanetas.MOONS.has(planet_key) or not luna:
		return

	for moon_data in FisicasPlanetas.MOONS[planet_key]:
		var m_inst = luna.instantiate()
		planet_node.add_child(m_inst)
		if m_inst.has_method("setup"):
			m_inst.setup(moon_data, visual_rad)
		moon_instances.append(m_inst)

func _process(delta: float) -> void:
	sim_time += time_speed * delta
	if sim_time > 11.5:
		sim_time = -1.0
	
	for key in instances.keys():
		instances[key].position = FisicasPlanetas.get_planet_pos_real_au(key, sim_time)
		
	for moon in moon_instances:
		if is_instance_valid(moon) and moon.has_method("update_local_position"):
			moon.update_local_position(sim_time)
