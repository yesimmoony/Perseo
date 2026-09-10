extends Control

# --- CONFIGURACION ---
@export var velocidad_suave: float = 22.0
@export var escala_normal: Vector2 = Vector2.ONE
@export var escala_pinch: Vector2 = Vector2(0.75, 0.75)

# --- VARIABLES ---
var posicion_deseada := Vector2.ZERO
var esta_activo: bool = false
var en_pinch: bool = false

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

# --- PROCESO Y MOVIMIENTO ---
func _process(delta: float) -> void:
	if not esta_activo:
		return

	global_position = global_position.lerp(posicion_deseada, velocidad_suave * delta)

	var escala_objetivo := escala_pinch if en_pinch else escala_normal
	scale = scale.lerp(escala_objetivo, 25.0 * delta)
