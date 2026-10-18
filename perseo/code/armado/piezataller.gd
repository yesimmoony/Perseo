class_name PiezaTaller
extends Area3D

# --- CONFIGURACION ---
@export var id_pieza: String = "sensor_radio_ocultacion"
@export var tipo_pieza: DatosPiezas.TipoPieza = DatosPiezas.TipoPieza.INSTRUMENTO
@export var distancia_iman_pixeles: float = 85.0
@export var velocidad_retorno: float = 14.0

# --- VARIABLES ---
var posicion_original := Vector3.ZERO
var agarrada: bool = false

# --- CICLO DE VIDA ---
func _ready() -> void:
	add_to_group("piezas_taller")
	posicion_original = global_position

# --- PROCESO ---
func _process(delta: float) -> void:
	if not agarrada:
		global_position = global_position.lerp(posicion_original, velocidad_retorno * delta)

# --- INTERACCION ---
func agarrar() -> void:
	agarrada = true

func mover_a(posicion_destino: Vector3) -> void:
	global_position = posicion_destino

func soltar() -> void:
	agarrada = false
	var ranura_destino := _buscar_ranura_cercana()
	if ranura_destino:
		ranura_destino.acoplar(id_pieza)
		visible = false
		monitoring = false
		monitorable = false

# --- DETECCION MAGNETICA ---
func _buscar_ranura_cercana() -> RanuraAcople:
	var camara := get_viewport().get_camera_3d()
	if not camara:
		return null

	var pos_pantalla_pieza := camara.unproject_position(global_position)
	var mejor_ranura: RanuraAcople = null
	var menor_distancia := distancia_iman_pixeles

	for nodo in get_tree().get_nodes_in_group("ranuras_acople"):
		if nodo is RanuraAcople and nodo.puede_recibir(tipo_pieza):
			var pos_pantalla_ranura := camara.unproject_position(nodo.global_position)
			var distancia_actual := pos_pantalla_pieza.distance_to(pos_pantalla_ranura)

			if distancia_actual < menor_distancia:
				menor_distancia = distancia_actual
				mejor_ranura = nodo

	return mejor_ranura
