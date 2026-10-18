extends Control

# --- SEÑALES ---
signal planeta_seleccionado(planeta: Node3D)
signal desplazamiento_solicitado(delta_pantalla: Vector2)

# --- CONFIGURACION ---
@export var velocidad_suave: float = 22.0
@export var escala_normal: Vector2 = Vector2.ONE
@export var escala_pinch: Vector2 = Vector2(0.75, 0.75)
@export var distancia_rayo: float = 2000.0

# --- VARIABLES ---
var posicion_deseada := Vector2.ZERO
var posicion_previa_pinch := Vector2.ZERO
var esta_activo: bool = false
var en_pinch: bool = false
var en_pinch_previo: bool = false

var objeto_hover: Node = null
var pieza_agarrada: PiezaTaller = null
var distancia_agarre: float = 5.0

# --- CICLO DE VIDA ---
func _ready() -> void:
	visible = false
	if WebcamController:
		WebcamController.cursor_actualizado.connect(_on_cursor_actualizado)

func _on_cursor_actualizado(activo: bool, pos_norm: Vector2, haciendo_pinch: bool) -> void:
	esta_activo = activo
	en_pinch = haciendo_pinch
	visible = activo

	if activo:
		var tamanio_pantalla := get_viewport_rect().size
		posicion_deseada = Vector2(pos_norm.x * tamanio_pantalla.x, pos_norm.y * tamanio_pantalla.y)

		# 1. Comienzo del Pinch (Click / Agarre)
		if haciendo_pinch and not en_pinch_previo:
			posicion_previa_pinch = posicion_deseada
			if objeto_hover:
				if objeto_hover is PiezaTaller:
					pieza_agarrada = objeto_hover
					pieza_agarrada.agarrar()
				elif objeto_hover is Node3D and objeto_hover.has_method("resaltar"):
					planeta_seleccionado.emit(objeto_hover)

		# 2. Fin del Pinch (Soltar)
		elif not haciendo_pinch and en_pinch_previo:
			if pieza_agarrada:
				pieza_agarrada.soltar()
				pieza_agarrada = null

		# 3. Arrastre en el vacio (Pan)
		elif haciendo_pinch and en_pinch_previo:
			if pieza_agarrada == null and objeto_hover == null:
				var delta_mov := posicion_deseada - posicion_previa_pinch
				desplazamiento_solicitado.emit(delta_mov)
				posicion_previa_pinch = posicion_deseada

	en_pinch_previo = haciendo_pinch

# --- PROCESO Y MOVIMIENTO ---
func _process(delta: float) -> void:
	if not esta_activo:
		if objeto_hover:
			_limpiar_hover()
		return

	global_position = global_position.lerp(posicion_deseada, velocidad_suave * delta)

	var escala_objetivo := escala_pinch if en_pinch else escala_normal
	scale = scale.lerp(escala_objetivo, 25.0 * delta)

	_actualizar_raycast()

# --- DETECCION Y ARRASTRE ---
func _actualizar_raycast() -> void:
	var camara := get_viewport().get_camera_3d()
	if not camara:
		_limpiar_hover()
		return

	var origen := camara.project_ray_origin(global_position)
	var direccion := camara.project_ray_normal(global_position)

	# Si tenemos una pieza agarrada con el pinch, la movemos en el plano 3D
	if pieza_agarrada and is_instance_valid(pieza_agarrada):
		var pos_destino := origen + (direccion * distancia_agarre)
		pieza_agarrada.mover_a(pos_destino)
		return

	var espacio := camara.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * distancia_rayo)
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = true

	var resultado := espacio.intersect_ray(consulta)

	if resultado.is_empty():
		_limpiar_hover()
		return

	var colisionador: Object = resultado["collider"]
	var objetivo: Node = colisionador if colisionador is PiezaTaller else colisionador.get_parent()

	if objetivo != objeto_hover:
		_limpiar_hover()
		objeto_hover = objetivo
		if objeto_hover.has_method("resaltar"):
			objeto_hover.resaltar(true)
		distancia_agarre = origen.distance_to(resultado["position"])

func _limpiar_hover() -> void:
	if objeto_hover:
		if objeto_hover.has_method("resaltar"):
			objeto_hover.resaltar(false)
		objeto_hover = null
