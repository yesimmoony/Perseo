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

# --- ESCALAS Y SCALED SPACE ---
@export var escala_distancias: float = 5000.0
@export var escala_planetas: float = 500.0
@export var radio_superficie_cercana: float = 30000.0 # Horizonte plano al acercarse sin salirse del rango de cámara
@export var distancia_colision_casco: float = 8.0     # Altura de aterrizaje sobre el suelo

@onready var orbit_renderer: orbitaRender = $Orbitas

@export_group("Jugador")
@export var cabina_scene: PackedScene

var instances: Dictionary = {}
var base_radii: Dictionary = {}
var unit_mesh_radii: Dictionary = {}
var moon_instances: Array = []
var sim_time: float = -1.0
@export var time_speed: float = 1.0 / 31557600.0

# --- ORIGEN FLOTANTE Y CORROTACIÓN ---
@export var altitud_inicial_marte: float = 20000.0
var cabina_ref: Node3D = null
var pos_virtual_nave: Vector3 = Vector3.ZERO
var pos_previa_marte_real: Vector3 = Vector3.ZERO
var aterrizado_en_marte: bool = false

func _ready() -> void:
	_spawn_planets()
	_configurar_camara_largo_alcance()

func _configurar_camara_largo_alcance() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.near = 0.05
		cam.far = 300000.0
	if cabina_ref:
		for child in cabina_ref.find_children("*", "Camera3D", true, false):
			if child is Camera3D:
				child.near = 0.05
				child.far = 300000.0

func _preparar_malla_y_colisiones_planeta(planeta_node: Node3D, _es_marte: bool = false) -> float:
	planeta_node.scale = Vector3.ONE
	
	# Desactivamos los CollisionShape3D físicos internos del planeta para evitar que el StaticBody3D
	# de Marte empuje al CharacterBody3D del jugador fuera de la cabina al escalarse
	for col in planeta_node.find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D and col.get_parent() is StaticBody3D:
			col.disabled = true

	for child in planeta_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.mesh and child.name != "Overline" and child.name != "AtmosferaGenerada" and child.get_parent().name != "Overline":
			if child.mesh is SphereMesh:
				var sph := child.mesh as SphereMesh
				sph.radial_segments = 128
				sph.rings = 64
			
			# Acá sacamos _aplicar_relieve_conservando_textura(child) para que respete el shader de planetas.gd
			
			var aabb: AABB = child.get_aabb()
			var escala_acumulada: float = 1.0
			var nodo_actual: Node = child
			while nodo_actual and nodo_actual != planeta_node:
				if nodo_actual is Node3D:
					escala_acumulada *= abs((nodo_actual as Node3D).scale.x)
				nodo_actual = nodo_actual.get_parent()
			var r_detectado: float = (aabb.size.x * 0.5) * escala_acumulada
			if r_detectado > 0.0001:
				return r_detectado
	return 0.5

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
			
			var r_unitario: float = _preparar_malla_y_colisiones_planeta(p_inst, key == "marte")
			unit_mesh_radii[key] = r_unitario
			
			var planet_data: Dictionary = FisicasPlanetas.PLANETS[key]
			var visual_rad: float = float(planet_data["rad"]) * escala_planetas
			base_radii[key] = visual_rad
			p_inst.scale = Vector3.ONE * (visual_rad / r_unitario)
			
			var pos_real: Vector3 = Vector3.ZERO if key == "sol" else (FisicasPlanetas.get_planet_pos_real_au(key, sim_time) * escala_distancias)
			p_inst.position = pos_real
			
			instances[key] = p_inst

			if key == "marte" and cabina_scene:
				pos_previa_marte_real = pos_real
				var cabina_inst = cabina_scene.instantiate()
				add_child(cabina_inst)
				cabina_inst.scale = Vector3.ONE
				cabina_ref = cabina_inst
				
				pos_virtual_nave = pos_real + Vector3(0, 0, visual_rad + altitud_inicial_marte)

				cabina_inst.global_position = Vector3.ZERO
				
				if cabina_inst.has_method("configurar_aproximacion"):
					cabina_inst.configurar_aproximacion(p_inst, visual_rad)
					cabina_inst.global_position = Vector3.ZERO
			
			_spawn_moons_for_planet(key, p_inst, 1.0)

	_actualizar_universo_relativo()
	if cabina_ref and instances.has("marte"):
		cabina_ref.look_at(instances["marte"].global_position, Vector3.UP)

func _spawn_moons_for_planet(planet_key: String, planet_node: Node3D, local_rad: float) -> void:
	if not FisicasPlanetas.MOONS.has(planet_key) or not luna:
		return

	for moon_data in FisicasPlanetas.MOONS[planet_key]:
		var m_inst = luna.instantiate()
		planet_node.add_child(m_inst)
		if m_inst.has_method("setup"):
			m_inst.setup(moon_data, local_rad)
		moon_instances.append(m_inst)

func _physics_process(delta: float) -> void:
	if cabina_ref and "velocidad_nave" in cabina_ref:
		pos_virtual_nave += cabina_ref.velocidad_nave * delta

	if cabina_ref:
		cabina_ref.scale = Vector3.ONE
		cabina_ref.global_position = Vector3.ZERO

	_actualizar_universo_relativo()
	
func _process(delta: float) -> void:
	var delta_tiempo_real: float = delta / 31557600.0
	sim_time += delta_tiempo_real
	if sim_time > 11.5:
		sim_time = -1.0
	
	if instances.has("marte"):
		instances["marte"].set_process(not aterrizado_en_marte)
	
	_actualizar_universo_relativo()
		
	for moon in moon_instances:
		if is_instance_valid(moon) and moon.has_method("update_local_position"):
			moon.update_local_position(sim_time)

func _actualizar_universo_relativo() -> void:
	var pos_marte_actual: Vector3 = FisicasPlanetas.get_planet_pos_real_au("marte", sim_time) * escala_distancias
	var delta_orbita_marte: Vector3 = pos_marte_actual - pos_previa_marte_real
	pos_previa_marte_real = pos_marte_actual
	if pos_virtual_nave.distance_to(pos_marte_actual) < base_radii.get("marte", 250.0) * 30.0:
		pos_virtual_nave += delta_orbita_marte

	if orbit_renderer:
		orbit_renderer.scale = Vector3.ONE
		orbit_renderer.global_position = -pos_virtual_nave

	for key in instances.keys():
		var pos_real_planeta: Vector3 = Vector3.ZERO
		if key != "sol":
			pos_real_planeta = FisicasPlanetas.get_planet_pos_real_au(key, sim_time) * escala_distancias
		
		var vec_relativo: Vector3 = pos_real_planeta - pos_virtual_nave
		var distancia_centro: float = vec_relativo.length()
		var dir_hacia_planeta: Vector3 = vec_relativo.normalized() if distancia_centro > 0.0001 else Vector3.FORWARD
		
		if base_radii.has(key):
			var rad_base: float = base_radii[key]
			var r_unitario: float = unit_mesh_radii.get(key, 0.5)
			var altitud_real: float = distancia_centro - rad_base
			
			# COLISIÓN Y ATERRIZAJE EN SUPERFICIE
			if altitud_real <= distancia_colision_casco + 0.5:
				altitud_real = distancia_colision_casco
				pos_virtual_nave = pos_real_planeta - dir_hacia_planeta * (rad_base + distancia_colision_casco)
				if key == "marte":
					aterrizado_en_marte = true
				if cabina_ref and "velocidad_nave" in cabina_ref:
					var vel: Vector3 = cabina_ref.velocidad_nave
					if vel.dot(dir_hacia_planeta) > -0.1:
						cabina_ref.velocidad_nave = Vector3.ZERO
			else:
				if key == "marte":
					aterrizado_en_marte = false
			
			var rango_expansion: float = 2000.0
			var t_cercania: float = clamp(1.0 - (altitud_real / rango_expansion), 0.0, 1.0)
			var rad_superficie_actual: float = lerp(rad_base, radio_superficie_cercana, pow(t_cercania, 1.5))
			
			instances[key].scale = Vector3.ONE * (rad_superficie_actual / r_unitario)
			instances[key].global_position = dir_hacia_planeta * (rad_superficie_actual + altitud_real)
			
			if key == "marte" and cabina_ref:
				if "altitud_marte" in cabina_ref:
					cabina_ref.altitud_marte = altitud_real - distancia_colision_casco
				if "aterrizado" in cabina_ref:
					cabina_ref.aterrizado = aterrizado_en_marte
		else:
			instances[key].global_position = vec_relativo
