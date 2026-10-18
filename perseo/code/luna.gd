@tool
extends Node3D

# --- VARIABLES EXPORTADAS PARA VER EN EL INSPECTOR ---
@export_group("Paleta de la Luna")
@export var col_centro: Color = Color("#F2F2F0")
@export var col_medio1: Color = Color("#A6A6A2")
@export var col_medio2: Color = Color("#595956")
@export var col_borde: Color = Color("#1C1F26")
@export var brillo_superficie: float = 1.35
@export var intensidad_halo: float = 1.2
@export var grano_risografia: float = 0.14

@export_group("Atmósfera y Auroras")
@export var tiene_atmosfera: bool = false
@export var color_atmosfera_dia: Color = Color("#80E5FF")
@export var color_atmosfera_ocaso: Color = Color("#3380FF")
@export var altura_atmosfera: float = 1.08
@export var densidad_atmosfera: float = 1.2
@export var intensidad_aurora: float = 0.0
@export var color_aurora_base: Color = Color("#00CCFF")
@export var color_aurora_alta: Color = Color("#6633FF")
@export var latitud_aurora: float = 0.72

# --- VARIABLES ORBITALES ---
var dist_orbita: float = 2.5
var periodo_dias: float = 27.32
var inclinacion_rad: float = 0.0
var fase_inicial: float = 0.0

var _mat_luna: ShaderMaterial = null
var _mat_atmo: ShaderMaterial = null
var _mesh_atmo: MeshInstance3D = null

const SHADER_LUNA = """
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex_ruido : repeat_enable, hint_default_white;
uniform vec3 col_centro : source_color = vec3(0.95, 0.95, 0.94);
uniform vec3 col_medio1 : source_color = vec3(0.65, 0.65, 0.63);
uniform vec3 col_medio2 : source_color = vec3(0.35, 0.35, 0.33);
uniform vec3 col_borde  : source_color = vec3(0.11, 0.12, 0.15);

uniform float grano_risografia = 0.14;
uniform float brillo_superficie = 1.35;
uniform float intensidad_halo = 1.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	// En Godot 4, NORMAL.z es 1.0 mirando directo a cámara y 0.0 en el borde
	float ndotv = clamp(NORMAL.z, 0.0, 1.0);
	
	// Luz aerógrafo desplazada arriba a la izquierda para dar volumen 3D
	vec3 dir_luz = normalize(vec3(-0.3, 0.35, 0.88));
	float luz = clamp(dot(normalize(NORMAL), dir_luz), 0.0, 1.0);
	
	// Textura procedural de cráteres y manchas para no depender de si el archivo .jpg es oscuro
	float n1 = texture(tex_ruido, UV * 3.0).r;
	float n2 = texture(tex_ruido, UV * 8.0 + vec2(0.3, 0.7)).r;
	float relieve_crateres = ((n1 * 0.6 + n2 * 0.4) - 0.5) * 0.45;
	
	float banda = clamp(mix(ndotv, luz, 0.55) + relieve_crateres, 0.0, 1.0);
	
	// Grano risográfico
	float grano = (hash(UV * 600.0 + FRAGCOORD.xy * 0.25) - 0.5) * grano_risografia;
	float b = clamp(banda + grano, 0.0, 1.0);
	
	// Mapeo de las 4 bandas de color
	vec3 col = col_borde;
	col = mix(col, col_medio2, smoothstep(0.08, 0.35, b));
	col = mix(col, col_medio1, smoothstep(0.35, 0.65, b));
	col = mix(col, col_centro, smoothstep(0.65, 0.88, b));
	
	// Halo brillante en el borde para que siempre resalte en el espacio negro
	float rim = pow(1.0 - ndotv, 2.5);
	vec3 col_rim = mix(col_medio1, col_centro, 0.5);
	
	ALBEDO = (col * brillo_superficie) + (col_rim * rim * intensidad_halo);
}
"""

const SHADER_ATMO_LUNA = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D tex_ruido : repeat_enable, hint_default_white;
uniform vec3 col_atmo_dia : source_color = vec3(0.5, 0.9, 1.0);
uniform vec3 col_atmo_ocaso : source_color = vec3(0.2, 0.5, 1.0);
uniform float densidad_atmo = 1.2;

uniform float intensidad_aurora = 0.0;
uniform vec3 col_aurora_1 : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 col_aurora_2 : source_color = vec3(0.4, 0.2, 1.0);
uniform float latitud_aurora = 0.72;

varying vec3 pos_local;

void vertex() {
	pos_local = normalize(VERTEX);
}

void fragment() {
	float v_dot_n = clamp(abs(NORMAL.z), 0.0, 1.0);
	float perfil_limbo = pow(1.0 - v_dot_n, 2.0) * smoothstep(0.0, 0.25, v_dot_n);
	vec3 color_gas = mix(col_atmo_ocaso, col_atmo_dia, v_dot_n);
	
	float latitud = abs(pos_local.y);
	float mascara_polo = exp(-pow((latitud - latitud_aurora) / 0.09, 2.0));
	float angulo_lon = atan(pos_local.x, pos_local.z);
	float onda = texture(tex_ruido, vec2(angulo_lon * 2.0 + TIME * 0.08, latitud * 3.0)).r;
	float cortina = smoothstep(0.3, 0.75, onda * 1.5);
	
	vec3 col_aur = mix(col_aurora_1, col_aurora_2, 1.0 - v_dot_n);
	vec3 emision_aurora = col_aur * mascara_polo * cortina * intensidad_aurora * 1.5;
	
	ALBEDO = (color_gas * perfil_limbo * densidad_atmo) + emision_aurora;
	ALPHA = clamp((perfil_limbo * densidad_atmo * 0.7) + (mascara_polo * cortina * intensidad_aurora * 0.6), 0.0, 1.0);
}
"""

func _ready() -> void:
	# Si abrís luna.tscn sola en el editor, se inicializa con el perfil por defecto
	if Engine.is_editor_hint():
		_aplicar_shader_a_mallas()

func setup(moon_data: Dictionary, local_rad: float) -> void:
	var nombre_luna: String = moon_data.get("name", "Luna")
	name = nombre_luna
	
	dist_orbita = float(moon_data.get("dist_factor", 2.5)) * local_rad
	periodo_dias = float(moon_data.get("T_days", 27.32))
	inclinacion_rad = deg_to_rad(float(moon_data.get("i", 0.0)))
	fase_inicial = float(nombre_luna.hash() % 360) * (PI / 180.0)
	
	var rad_ratio: float = float(moon_data.get("rad_ratio", 0.2))
	scale = Vector3.ONE * (local_rad * rad_ratio)
	
	var etiq := get_node_or_null("Label3D") as Label3D
	if etiq:
		etiq.visible = false
		etiq.text = nombre_luna.to_upper()
		
	var over := get_node_or_null("Overline") as Node3D
	if over:
		over.visible = false
	
	# 1. Cargar colores según el nombre de la luna
	_cargar_perfil_color(nombre_luna)
	
	# 2. Aplicar el shader inmediatamente a TODAS las mallas de la luna
	_aplicar_shader_a_mallas()

func update_local_position(sim_time: float) -> void:
	if abs(periodo_dias) < 0.0001:
		return
	var dias_transcurridos: float = sim_time * 365.25
	var angulo: float = fase_inicial + (TAU / periodo_dias) * dias_transcurridos
	
	var x: float = cos(angulo) * dist_orbita
	var z: float = sin(angulo) * dist_orbita
	var y: float = sin(angulo) * sin(inclinacion_rad) * dist_orbita
	position = Vector3(x, y, z)

func _cargar_perfil_color(nombre_luna: String) -> void:
	match nombre_luna:
		"Fobos", "Deimos":
			# Le subimos el contraste cálido/ocre para que NO se pierdan en el fondo negro de Marte
			col_centro = Color("#FFE0B2")
			col_medio1 = Color("#C2875A")
			col_medio2 = Color("#784421")
			col_borde  = Color("#2D162C")
			brillo_superficie = 1.45
			intensidad_halo = 1.3
			tiene_atmosfera = false

		"Ío":
			col_centro = Color("#FFFF80")
			col_medio1 = Color("#FF8000")
			col_medio2 = Color("#CC2900")
			col_borde  = Color("#33140A")
			brillo_superficie = 1.5
			intensidad_halo = 1.4
			tiene_atmosfera = true
			color_atmosfera_dia = Color("#FFD940")
			color_atmosfera_ocaso = Color("#FF3300")
			altura_atmosfera = 1.08
			densidad_atmosfera = 1.0
			intensidad_aurora = 1.5
			color_aurora_base = Color("#FF9900")
			color_aurora_alta = Color("#3366FF")

		"Europa", "Encélado":
			col_centro = Color("#FFFFFF")
			col_medio1 = Color("#99E6FF")
			col_medio2 = Color("#3399CC")
			col_borde  = Color("#193366")
			brillo_superficie = 1.5
			intensidad_halo = 1.4
			tiene_atmosfera = true
			color_atmosfera_dia = Color("#80E5FF")
			color_atmosfera_ocaso = Color("#3380FF")
			altura_atmosfera = 1.07
			densidad_atmosfera = 0.8
			intensidad_aurora = 1.0

		"Titán":
			col_centro = Color("#FFE699")
			col_medio1 = Color("#E69526")
			col_medio2 = Color("#994D14")
			col_borde  = Color("#3D1F0A")
			brillo_superficie = 1.35
			intensidad_halo = 1.5
			tiene_atmosfera = true
			color_atmosfera_dia = Color("#FFAA33")
			color_atmosfera_ocaso = Color("#2680FF")
			altura_atmosfera = 1.18
			densidad_atmosfera = 2.0
			intensidad_aurora = 0.0

		"Tritón", "Ganímedes", "Cálisto":
			col_centro = Color("#E6FFFF")
			col_medio1 = Color("#7AB8CC")
			col_medio2 = Color("#3D6B80")
			col_borde  = Color("#1A2640")
			brillo_superficie = 1.4
			intensidad_halo = 1.2
			tiene_atmosfera = true
			color_atmosfera_dia = Color("#66CCFF")
			color_atmosfera_ocaso = Color("#334DFF")
			altura_atmosfera = 1.07
			densidad_atmosfera = 0.7
			intensidad_aurora = 1.2 if nombre_luna == "Ganímedes" else 0.4

		_:
			# Luna Terrestre y demás satélites
			col_centro = Color("#FFFFFF")
			col_medio1 = Color("#B8C2CC")
			col_medio2 = Color("#667380")
			col_borde  = Color("#262B40")
			brillo_superficie = 1.4
			intensidad_halo = 1.2
			tiene_atmosfera = false

func _aplicar_shader_a_mallas() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	var tex_ruido := NoiseTexture2D.new()
	tex_ruido.seamless = true
	tex_ruido.noise = noise

	var sh := Shader.new()
	sh.code = SHADER_LUNA
	_mat_luna = ShaderMaterial.new()
	_mat_luna.shader = sh
	_mat_luna.set_shader_parameter("tex_ruido", tex_ruido)
	_mat_luna.set_shader_parameter("col_centro", col_centro)
	_mat_luna.set_shader_parameter("col_medio1", col_medio1)
	_mat_luna.set_shader_parameter("col_medio2", col_medio2)
	_mat_luna.set_shader_parameter("col_borde", col_borde)
	_mat_luna.set_shader_parameter("grano_risografia", grano_risografia)
	_mat_luna.set_shader_parameter("brillo_superficie", brillo_superficie)
	_mat_luna.set_shader_parameter("intensidad_halo", intensidad_halo)

	var malla_principal: MeshInstance3D = null
	for child in find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.mesh and child.name != "Overline" and child.name != "AtmosferaLuna" and child.get_parent().name != "Overline":
			# Limpiamos cualquier material viejo que esté bloqueando el shader
			child.material_override = _mat_luna
			for i in range(child.get_surface_override_material_count()):
				child.set_surface_override_material(i, null)
			if not malla_principal:
				malla_principal = child

	if malla_principal and tiene_atmosfera:
		_mesh_atmo = malla_principal.get_node_or_null("AtmosferaLuna") as MeshInstance3D
		if not _mesh_atmo:
			_mesh_atmo = MeshInstance3D.new()
			_mesh_atmo.name = "AtmosferaLuna"
			malla_principal.add_child(_mesh_atmo)
		
		var aabb: AABB = malla_principal.get_aabb()
		var r_base: float = max(aabb.size.x * 0.5, 0.001)
		var sph := SphereMesh.new()
		sph.radius = r_base
		sph.height = r_base * 2.0
		_mesh_atmo.mesh = sph
		_mesh_atmo.scale = Vector3.ONE * altura_atmosfera
		
		var sh_atmo := Shader.new()
		sh_atmo.code = SHADER_ATMO_LUNA
		_mat_atmo = ShaderMaterial.new()
		_mat_atmo.shader = sh_atmo
		_mat_atmo.set_shader_parameter("tex_ruido", tex_ruido)
		_mat_atmo.set_shader_parameter("col_atmo_dia", color_atmosfera_dia)
		_mat_atmo.set_shader_parameter("col_atmo_ocaso", color_atmosfera_ocaso)
		_mat_atmo.set_shader_parameter("densidad_atmo", densidad_atmosfera)
		_mat_atmo.set_shader_parameter("intensidad_aurora", intensidad_aurora)
		_mat_atmo.set_shader_parameter("col_aurora_1", color_aurora_base)
		_mat_atmo.set_shader_parameter("col_aurora_2", color_aurora_alta)
		_mat_atmo.set_shader_parameter("latitud_aurora", latitud_aurora)
		_mesh_atmo.material_override = _mat_atmo
