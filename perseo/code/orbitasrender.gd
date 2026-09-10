class_name orbitaRender
extends Node3D

@export var orbit_color: Color
@export var custom_material: Material

var orbit_materials: Dictionary = {}
var orbit_meshes: Dictionary = {}

func _ready() -> void:
	# Si no le pasás un material custom desde el inspector, crea uno con emisión brillante
	if not custom_material:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = orbit_color
		mat.use_point_size = true
		custom_material = mat

	generate_orbits()

func generate_orbits() -> void:
	# Limpia órbitas previas si se vuelve a generar
	for child in get_children():
		child.queue_free()
	orbit_meshes.clear()

	for key in FisicasPlanetas.PLANETS.keys():
		var p_data: Dictionary = FisicasPlanetas.PLANETS[key]
		if float(p_data["a"]) == 0.0:
			continue

		var orbit_mesh = ImmediateMesh.new()
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = orbit_mesh
		mesh_instance.name = key.capitalize() + "_Orbit"
		
		# Duplicamos el material para poder manipular colores por planeta si quisiéramos
		var mat_instance = custom_material.duplicate()
		mesh_instance.material_override = mat_instance
		orbit_materials[key] = mat_instance

		var period: float = float(p_data["T"])
		var points_count: int = 120

		orbit_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(points_count + 1):
			var sample_time: float = (float(i) / float(points_count)) * period
			var pos: Vector3 = FisicasPlanetas.get_planet_pos_real_au(key, sample_time)
			orbit_mesh.surface_add_vertex(pos)
		orbit_mesh.surface_end()

		add_child(mesh_instance)
		orbit_meshes[key] = mesh_instance

# --- Controles en tiempo real para la UI ---

func set_global_color(new_color: Color) -> void:
	orbit_color = new_color
	for key in orbit_materials.keys():
		var mat = orbit_materials[key]
		if mat is StandardMaterial3D:
			mat.albedo_color = new_color
		elif mat is ShaderMaterial:
			mat.set_shader_parameter("orbit_color", new_color)

func set_planet_orbit_color(planet_key: String, new_color: Color) -> void:
	if orbit_materials.has(planet_key):
		var mat = orbit_materials[planet_key]
		if mat is StandardMaterial3D:
			mat.albedo_color = new_color
		elif mat is ShaderMaterial:
			mat.set_shader_parameter("orbit_color", new_color)

func toggle_orbits() -> void:
	visible = !visible
