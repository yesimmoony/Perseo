@tool
extends Node3D
class_name PlanetaVisual

@export_group("Paleta Aerógrafo / Térmica")
@export var col_centro: Color = Color("#FFAD75"):
	set(v):
		col_centro = v
		_actualizar_propiedad()

@export var col_medio1: Color = Color("#E05A2B"):
	set(v):
		col_medio1 = v
		_actualizar_propiedad()

@export var col_medio2: Color = Color("#992D15"):
	set(v):
		col_medio2 = v
		_actualizar_propiedad()

@export var col_borde: Color = Color("#3D1424"):
	set(v):
		col_borde = v
		_actualizar_propiedad()

@export_group("Textura y Grano Risográfico")
@export var textura_personalizada: Texture2D:
	set(v):
		textura_personalizada = v
		_actualizar_propiedad()

@export_range(0.0, 1.0, 0.05) var influencia_textura: float = 0.45:
	set(v):
		influencia_textura = v
		_actualizar_propiedad()

@export_range(0.0, 1.0, 0.05) var distorsion_fluida: float = 0.25:
	set(v):
		distorsion_fluida = v
		_actualizar_propiedad()

@export_range(0.0, 0.5, 0.01) var grano_risografia: float = 0.10:
	set(v):
		grano_risografia = v
		_actualizar_propiedad()

@export_group("Brillo y Halo de Superficie")
@export_range(0.2, 4.0, 0.05) var brillo_superficie: float = 1.35:
	set(v):
		brillo_superficie = v
		_actualizar_propiedad()

@export_range(0.0, 5.0, 0.1) var intensidad_halo: float = 1.4:
	set(v):
		intensidad_halo = v
		_actualizar_propiedad()

@export_range(0.5, 6.0, 0.1) var grosor_halo: float = 2.8:
	set(v):
		grosor_halo = v
		_actualizar_propiedad()

@export_group("Atmósfera 3D y Auroras Polares")
@export var tiene_atmosfera: bool = true:
	set(v):
		tiene_atmosfera = v
		_actualizar_propiedad()

@export var color_atmosfera_dia: Color = Color("#38A3FF"):
	set(v):
		color_atmosfera_dia = v
		_actualizar_propiedad()

@export var color_atmosfera_ocaso: Color = Color("#FF5E38"):
	set(v):
		color_atmosfera_ocaso = v
		_actualizar_propiedad()

@export_range(1.02, 1.35, 0.01) var altura_atmosfera: float = 1.12:
	set(v):
		altura_atmosfera = v
		_actualizar_propiedad()

@export_range(0.0, 4.0, 0.1) var densidad_atmosfera: float = 1.6:
	set(v):
		densidad_atmosfera = v
		_actualizar_propiedad()

@export_subgroup("Auroras Boreales / Australes")
@export_range(0.0, 5.0, 0.1) var intensidad_aurora: float = 1.8:
	set(v):
		intensidad_aurora = v
		_actualizar_propiedad()

@export var color_aurora_base: Color = Color("#1AFF80"):
	set(v):
		color_aurora_base = v
		_actualizar_propiedad()

@export var color_aurora_alta: Color = Color("#D926FF"):
	set(v):
		color_aurora_alta = v
		_actualizar_propiedad()

@export_range(0.4, 0.95, 0.01) var latitud_aurora: float = 0.72:
	set(v):
		latitud_aurora = v
		_actualizar_propiedad()

@export_group("Anillos Planetarios")
@export var tiene_anillos: bool = false:
	set(v):
		tiene_anillos = v
		_actualizar_propiedad()

@export var color_anillo_interno: Color = Color("#E6C37A"):
	set(v):
		color_anillo_interno = v
		_actualizar_propiedad()

@export var color_anillo_externo: Color = Color("#593E2B"):
	set(v):
		color_anillo_externo = v
		_actualizar_propiedad()

@export_range(1.1, 2.0, 0.05) var inicio_anillos: float = 1.25:
	set(v):
		inicio_anillos = v
		_actualizar_propiedad()

@export_range(1.5, 4.0, 0.05) var fin_anillos: float = 2.4:
	set(v):
		fin_anillos = v
		_actualizar_propiedad()

@export_range(0.0, 90.0, 1.0) var inclinacion_anillos: float = 25.0:
	set(v):
		inclinacion_anillos = v
		_actualizar_propiedad()

# --- NODOS ---
@onready var nodo_overline: Node3D = get_node_or_null("Overline")
@onready var etiqueta_nombre: Label3D = get_node_or_null("Label3D")

var _mat_planeta: ShaderMaterial = null
var _mat_atmosfera: ShaderMaterial = null
var _mat_anillos: ShaderMaterial = null
var _mesh_atmosfera: MeshInstance3D = null
var _mesh_anillos: MeshInstance3D = null
var _tex_ruido_compartida: NoiseTexture2D = null

const CODIGO_SHADER_SUPERFICIE = """
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D tex_color : source_color, hint_default_white;
uniform sampler2D tex_ruido : repeat_enable, hint_default_white;
uniform bool tiene_tex_color = false;

uniform vec3 col_centro : source_color = vec3(1.0, 0.98, 0.7);
uniform vec3 col_medio1 : source_color = vec3(1.0, 0.35, 0.1);
uniform vec3 col_medio2 : source_color = vec3(0.95, 0.1, 0.65);
uniform vec3 col_borde  : source_color = vec3(0.05, 0.45, 1.0);

uniform float influencia_textura = 0.45;
uniform float distorsion_fluida = 0.25;
uniform float grano_risografia = 0.10;
uniform float brillo_superficie = 1.35;
uniform float intensidad_halo = 1.4;
uniform float grosor_halo = 2.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 luz_dir = normalize(vec3(-0.25, 0.25, 0.93));
	float volumen = clamp(dot(normalize(NORMAL), luz_dir), 0.0, 1.0);
	float base_esfera = mix(ndotv, volumen, 0.5);
	
	float detalle_tex = 0.0;
	if (tiene_tex_color) {
		vec3 tex_base = texture(tex_color, UV).rgb;
		float lum = dot(tex_base, vec3(0.299, 0.587, 0.114));
		detalle_tex = (lum - 0.45) * 1.4 * influencia_textura;
	}
	
	float n_fluido = (texture(tex_ruido, UV * 2.5 + vec2(TIME * 0.015, 0.0)).r - 0.5) * distorsion_fluida;
	float banda = clamp(pow(base_esfera, 0.8) + detalle_tex + n_fluido, 0.0, 1.0);
	float grano = (hash(UV * 900.0) - 0.5) * grano_risografia;
	float b = clamp(banda + grano, 0.0, 1.0);
	
	vec3 color_final = col_borde;
	color_final = mix(color_final, col_medio2, smoothstep(0.08, 0.35, b));
	color_final = mix(color_final, col_medio1, smoothstep(0.35, 0.65, b));
	color_final = mix(color_final, col_centro, smoothstep(0.65, 0.90, b));
	
	float rim = pow(1.0 - ndotv, grosor_halo);
	vec3 color_rim = mix(col_borde, col_medio1, 0.5);
	
	ALBEDO = (color_final * brillo_superficie) + (color_rim * rim * intensidad_halo);
}
"""

const CODIGO_SHADER_ATMOSFERA = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D tex_ruido : repeat_enable, hint_default_white;
uniform vec3 col_atmo_dia : source_color = vec3(0.2, 0.65, 1.0);
uniform vec3 col_atmo_ocaso : source_color = vec3(1.0, 0.35, 0.55);
uniform float densidad_atmo = 1.6;
uniform float intensidad_aurora = 1.8;
uniform vec3 col_aurora_1 : source_color = vec3(0.1, 1.0, 0.55);
uniform vec3 col_aurora_2 : source_color = vec3(0.85, 0.15, 1.0);
uniform float latitud_aurora = 0.72;

varying vec3 pos_local;

void vertex() {
	pos_local = normalize(VERTEX);
}

void fragment() {
	float v_dot_n = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float perfil_limbo = pow(1.0 - v_dot_n, 2.2) * smoothstep(0.0, 0.25, v_dot_n);
	vec3 color_gas = mix(col_atmo_ocaso, col_atmo_dia, v_dot_n);
	
	float latitud = abs(pos_local.y);
	float mascara_polo = exp(-pow(abs(latitud - latitud_aurora) / 0.09, 2.0));
	float angulo_lon = atan(pos_local.x, pos_local.z);
	float onda1 = texture(tex_ruido, vec2(angulo_lon * 2.0 + TIME * 0.06, latitud * 2.5 - TIME * 0.03)).r;
	float onda2 = texture(tex_ruido, vec2(angulo_lon * 3.5 - TIME * 0.09, latitud * 4.0 + TIME * 0.05)).r;
	float cortina = smoothstep(0.25, 0.75, onda1 * onda2 * 2.0);
	
	vec3 col_aurora = mix(col_aurora_1, col_aurora_2, clamp(onda2 * 1.2 + (1.0 - v_dot_n) * 0.4, 0.0, 1.0));
	vec3 emision_aurora = col_aurora * mascara_polo * cortina * intensidad_aurora * 1.5;
	
	ALBEDO = (color_gas * perfil_limbo * densidad_atmo) + emision_aurora;
	ALPHA = clamp((perfil_limbo * densidad_atmo * 0.7) + (mascara_polo * cortina * intensidad_aurora * 0.6), 0.0, 1.0);
}
"""

const CODIGO_SHADER_ANILLOS = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled; // cull_disabled permite ver el anillo por debajo

uniform vec3 col_int : source_color = vec3(0.9, 0.7, 0.4);
uniform vec3 col_ext : source_color = vec3(0.3, 0.2, 0.1);
uniform float radio_interno = 1.25;
uniform float radio_externo = 2.4;
uniform float grano_risografia = 0.1;

varying vec3 pos_local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	pos_local = VERTEX;
}

void fragment() {
	// Calculamos la distancia desde el centro del planeta en el plano XZ
	float dist = length(pos_local.xz);
	
	// Recortamos el agujero del medio para que no atraviese el planeta, y el borde exterior
	float mascara_anillo = smoothstep(radio_interno, radio_interno + 0.05, dist) * (1.0 - smoothstep(radio_externo - 0.05, radio_externo, dist));
	
	// Creamos las divisiones de los anillos (tipo vinilo)
	float bandas = sin(dist * 35.0) * 0.5 + 0.5;
	bandas *= sin(dist * 18.0) * 0.5 + 0.5;
	float huecos_oscuros = smoothstep(0.1, 0.9, bandas);
	
	// Grano para la estética retro
	float grano = (hash(pos_local.xz * 50.0 + FRAGCOORD.xy * 0.1) - 0.5) * grano_risografia;
	
	// Mezcla de colores desde adentro hacia afuera
	float factor_color = clamp((dist - radio_interno) / (radio_externo - radio_interno), 0.0, 1.0);
	vec3 color_final = mix(col_int, col_ext, factor_color);
	
	ALBEDO = color_final + grano;
	ALPHA = mascara_anillo * huecos_oscuros * 0.9;
}
"""

func _ready() -> void:
	if nodo_overline:
		nodo_overline.visible = false
	if not Engine.is_editor_hint() and etiqueta_nombre:
		etiqueta_nombre.visible = false
		etiqueta_nombre.text = name.to_upper()
	
	call_deferred("_inicializar_shader_unico")

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_y((TAU / 88775.0) * delta)

func resaltar(activo: bool) -> void:
	if nodo_overline:
		nodo_overline.visible = activo
	if etiqueta_nombre:
		etiqueta_nombre.visible = activo

func _actualizar_propiedad() -> void:
	if not is_node_ready():
		return
	if not _mat_planeta:
		_inicializar_shader_unico()
	else:
		_sincronizar_todos_los_parametros()

func _inicializar_shader_unico() -> void:
	var mesh_inst := _buscar_malla()
	if not mesh_inst:
		return
		
	if not textura_personalizada:
		var mat_orig := mesh_inst.get_active_material(0)
		if mat_orig is StandardMaterial3D and mat_orig.albedo_texture:
			textura_personalizada = mat_orig.albedo_texture
	
	if not _tex_ruido_compartida:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.025
		_tex_ruido_compartida = NoiseTexture2D.new()
		_tex_ruido_compartida.seamless = true
		_tex_ruido_compartida.noise = noise

	var sh_sup := Shader.new()
	sh_sup.code = CODIGO_SHADER_SUPERFICIE
	_mat_planeta = ShaderMaterial.new()
	_mat_planeta.shader = sh_sup
	_mat_planeta.set_shader_parameter("tex_ruido", _tex_ruido_compartida)
	mesh_inst.material_override = _mat_planeta
	
	_crear_o_actualizar_malla_atmosfera(mesh_inst)
	_crear_o_actualizar_malla_anillos(mesh_inst)
	_sincronizar_todos_los_parametros()

func _crear_o_actualizar_malla_atmosfera(malla_planeta: MeshInstance3D) -> void:
	_mesh_atmosfera = malla_planeta.get_node_or_null("AtmosferaGenerada") as MeshInstance3D
	if not _mesh_atmosfera:
		_mesh_atmosfera = MeshInstance3D.new()
		_mesh_atmosfera.name = "AtmosferaGenerada"
		malla_planeta.add_child(_mesh_atmosfera)
	
	var aabb: AABB = malla_planeta.get_aabb()
	var radio_base: float = max(aabb.size.x * 0.5, 0.001)
	
	var sph := SphereMesh.new()
	sph.radius = radio_base
	sph.height = radio_base * 2.0
	sph.radial_segments = 64
	sph.rings = 32
	_mesh_atmosfera.mesh = sph
	_mesh_atmosfera.scale = Vector3.ONE * altura_atmosfera
	_mesh_atmosfera.visible = tiene_atmosfera
	_mesh_atmosfera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	if not _mat_atmosfera:
		var sh_atmo := Shader.new()
		sh_atmo.code = CODIGO_SHADER_ATMOSFERA
		_mat_atmosfera = ShaderMaterial.new()
		_mat_atmosfera.shader = sh_atmo
		_mesh_atmosfera.material_override = _mat_atmosfera

func _crear_o_actualizar_malla_anillos(malla_planeta: MeshInstance3D) -> void:
	_mesh_anillos = malla_planeta.get_node_or_null("AnillosGenerados") as MeshInstance3D
	if not _mesh_anillos:
		_mesh_anillos = MeshInstance3D.new()
		_mesh_anillos.name = "AnillosGenerados"
		malla_planeta.add_child(_mesh_anillos)
		
	var aabb: AABB = malla_planeta.get_aabb()
	var radio_base: float = max(aabb.size.x * 0.5, 0.001)
	
	# Usamos un cilindro súper aplastado para simular un disco perfecto de vinilo
	var cyl := CylinderMesh.new()
	cyl.top_radius = radio_base * fin_anillos
	cyl.bottom_radius = radio_base * fin_anillos
	cyl.height = 0.001
	cyl.radial_segments = 64
	_mesh_anillos.mesh = cyl
	_mesh_anillos.visible = tiene_anillos
	_mesh_anillos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Inclinación del anillo
	_mesh_anillos.rotation_degrees = Vector3(inclinacion_anillos, 0, 0)
	
	if not _mat_anillos:
		var sh_anillos := Shader.new()
		sh_anillos.code = CODIGO_SHADER_ANILLOS
		_mat_anillos = ShaderMaterial.new()
		_mat_anillos.shader = sh_anillos
		_mesh_anillos.material_override = _mat_anillos

func _buscar_malla() -> MeshInstance3D:
	for child in find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.mesh and child.name != "Overline" and child.name != "AtmosferaGenerada" and child.name != "AnillosGenerados" and child.get_parent().name != "Overline":
			return child
	return null

func _sincronizar_todos_los_parametros() -> void:
	if _mat_planeta:
		_mat_planeta.set_shader_parameter("tiene_tex_color", textura_personalizada != null)
		if textura_personalizada:
			_mat_planeta.set_shader_parameter("tex_color", textura_personalizada)
		_mat_planeta.set_shader_parameter("col_centro", col_centro)
		_mat_planeta.set_shader_parameter("col_medio1", col_medio1)
		_mat_planeta.set_shader_parameter("col_medio2", col_medio2)
		_mat_planeta.set_shader_parameter("col_borde", col_borde)
		_mat_planeta.set_shader_parameter("influencia_textura", influencia_textura)
		_mat_planeta.set_shader_parameter("distorsion_fluida", distorsion_fluida)
		_mat_planeta.set_shader_parameter("grano_risografia", grano_risografia)
		_mat_planeta.set_shader_parameter("brillo_superficie", brillo_superficie)
		_mat_planeta.set_shader_parameter("intensidad_halo", intensidad_halo)
		_mat_planeta.set_shader_parameter("grosor_halo", grosor_halo)
	
	if _mesh_atmosfera:
		_mesh_atmosfera.visible = tiene_atmosfera
		_mesh_atmosfera.scale = Vector3.ONE * altura_atmosfera
		
	if _mat_atmosfera:
		_mat_atmosfera.set_shader_parameter("tex_ruido", _tex_ruido_compartida)
		_mat_atmosfera.set_shader_parameter("col_atmo_dia", color_atmosfera_dia)
		_mat_atmosfera.set_shader_parameter("col_atmo_ocaso", color_atmosfera_ocaso)
		_mat_atmosfera.set_shader_parameter("densidad_atmo", densidad_atmosfera)
		_mat_atmosfera.set_shader_parameter("intensidad_aurora", intensidad_aurora)
		_mat_atmosfera.set_shader_parameter("col_aurora_1", color_aurora_base)
		_mat_atmosfera.set_shader_parameter("col_aurora_2", color_aurora_alta)
		_mat_atmosfera.set_shader_parameter("latitud_aurora", latitud_aurora)
		
	if _mesh_anillos:
		_mesh_anillos.visible = tiene_anillos
		_mesh_anillos.rotation_degrees = Vector3(inclinacion_anillos, 0, 0)
		if _mesh_anillos.mesh is CylinderMesh:
			var malla_planeta = _buscar_malla()
			if malla_planeta:
				var aabb: AABB = malla_planeta.get_aabb()
				var radio_base: float = max(aabb.size.x * 0.5, 0.001)
				(_mesh_anillos.mesh as CylinderMesh).top_radius = radio_base * fin_anillos
				(_mesh_anillos.mesh as CylinderMesh).bottom_radius = radio_base * fin_anillos
				
	if _mat_anillos:
		var malla_planeta = _buscar_malla()
		if malla_planeta:
			var aabb: AABB = malla_planeta.get_aabb()
			var radio_base: float = max(aabb.size.x * 0.5, 0.001)
			_mat_anillos.set_shader_parameter("radio_interno", radio_base * inicio_anillos)
			_mat_anillos.set_shader_parameter("radio_externo", radio_base * fin_anillos)
		_mat_anillos.set_shader_parameter("col_int", color_anillo_interno)
		_mat_anillos.set_shader_parameter("col_ext", color_anillo_externo)
		_mat_anillos.set_shader_parameter("grano_risografia", grano_risografia)
