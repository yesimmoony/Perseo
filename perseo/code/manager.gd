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

@export var escala_distancias: float = 5000.0
@export var escala_planetas: float = 500.0
@export var radio_superficie_cercana: float = 15000.0
@export var distancia_colision_casco: float = 8.0
@export var altitud_inicial_marte: float = 3500.0

@onready var orbit_renderer: orbitaRender = $Orbitas

@export_group("Jugador")
@export var cabina_scene: PackedScene

var instances: Dictionary = {}
var base_radii: Dictionary = {}
var unit_mesh_radii: Dictionary = {}
var moon_instances: Array = []
var sim_time: float = -1.0
@export var time_speed: float = 1.0 / 31557600.0

var cabina_ref: Node3D = null
var pos_virtual_nave: Vector3 = Vector3.ZERO
var pos_previa_marte_real: Vector3 = Vector3.ZERO
var aterrizado_en_marte: bool = false

const COLORES_ATMOSFERA := {
	"sol": Color(1.0, 0.65, 0.2),
	"mercurio": Color(0.55, 0.7, 1.0),
	"venus": Color(1.0, 0.75, 0.35),
	"tierra": Color(0.2, 0.75, 1.0),
	"marte": Color(0.25, 0.78, 1.0),
	"jupiter": Color(0.85, 0.55, 1.0),
	"saturno": Color(0.9, 0.45, 0.95),
	"urano": Color(0.25, 0.9, 0.95),
	"neptuno": Color(0.3, 0.5, 1.0)
}

func _ready() -> void:
	_asegurar_luz_solar_y_glow()
	_spawn_planets()
	_configurar_camara_largo_alcance()

func _asegurar_luz_solar_y_glow() -> void:
	if find_children("*", "DirectionalLight3D", true, false).is_empty():
		var sol_luz := DirectionalLight3D.new()
		sol_luz.light_energy = 1.6
		sol_luz.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
		add_child(sol_luz)
	
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.glow_enabled = true
		world_env.environment.glow_intensity = 1.35
		world_env.environment.glow_bloom = 0.28
		world_env.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		world_env.environment.glow_hdr_threshold = 0.8

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

func _preparar_malla_y_colisiones_planeta(planeta_node: Node3D, planet_key: String) -> float:
	planeta_node.scale = Vector3.ONE
	
	for col in planeta_node.find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D and col.get_parent() is StaticBody3D:
			col.disabled = true

	for child in planeta_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.mesh and child.name != "Overline" and child.get_parent().name != "Overline":
			if child.mesh is SphereMesh:
				var sph := child.mesh as SphereMesh
				sph.radial_segments = 128
				sph.rings = 64
			_aplicar_relieve_conservando_textura(child, planet_key)
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

func _aplicar_relieve_conservando_textura(mesh_inst: MeshInstance3D, planet_key: String) -> void:
	var mat_orig := mesh_inst.get_active_material(0) as StandardMaterial3D
	var tex_albedo: Texture2D = mat_orig.albedo_texture if mat_orig else null
	var color_base: Color = mat_orig.albedo_color if mat_orig else Color(0.82, 0.38, 0.18)
	var col_atmo: Color = COLORES_ATMOSFERA.get(planet_key, Color(0.25, 0.78, 1.0))

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 5
	noise.frequency = 0.025

	var tex_height := NoiseTexture2D.new()
	tex_height.width = 512
	tex_height.height = 512
	tex_height.seamless = true
	tex_height.noise = noise

	var tex_norm := NoiseTexture2D.new()
	tex_norm.width = 512
	tex_norm.height = 512
	tex_norm.seamless = true
	tex_norm.as_normal_map = true
	tex_norm.bump_strength = 14.0
	tex_norm.noise = noise

	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_color : source_color, filter_linear_mipmap;
uniform bool tiene_textura = true;
uniform vec3 color_fallback : source_color = vec3(0.82, 0.38, 0.18);
uniform sampler2D tex_altura : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float fuerza_montanas = 0.035;
uniform vec3 color_atmosfera : source_color = vec3(0.25, 0.78, 1.0);
uniform vec3 color_incandescente : source_color = vec3(1.0, 0.55, 0.15);

void vertex() {
	float h = texture(tex_altura, UV * 4.0).r - 0.5;
	VERTEX += NORMAL * (h * fuerza_montanas);
}

void fragment() {
	vec3 base = tiene_textura ? texture(tex_color, UV).rgb : color_fallback;
	float grietas = smoothstep(0.68, 0.90, texture(tex_altura, UV * 12.0).r);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);

	ALBEDO = base;
	NORMAL_MAP = texture(tex_normal, UV * 8.0).rgb;
	NORMAL_MAP_DEPTH = 1.6;
	ROUGHNESS = 0.85;
	EMISSION = (color_atmosfera * fresnel * 2.8) + (color_incandescente * grietas * 2.0) + (base * 0.18);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tiene_textura", tex_albedo != null)
	if tex_albedo:
		mat.set_shader_parameter("tex_color", tex_albedo)
	mat.set_shader_parameter("color_fallback", color_base)
	mat.set_shader_parameter("tex_altura", tex_height)
	mat.set_shader_parameter("tex_normal", tex_norm)
	mat.set_shader_parameter("color_atmosfera", col_atmo)
	mat.set_shader_parameter("fuerza_montanas", 0.035 if planet_key == "marte" else 0.012)
	mesh_inst.material_override = mat

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
			
			var r_unitario: float = _preparar_malla_y_colisiones_planeta(p_inst, key)
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

func _physics_process(_delta: float) -> void:
	if cabina_ref:
		cabina_ref.scale = Vector3.ONE
		if cabina_ref.global_position != Vector3.ZERO:
			pos_virtual_nave += cabina_ref.global_position
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
