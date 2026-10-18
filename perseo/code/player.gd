extends CharacterBody3D

# --- CONFIGURACION ---
@export var cursor_holografico: Control
@export var velocidad: float = 20.0
@export var sprint: float = 3.0
@export var sensibilidad_mouse: float = 0.003
@export var sensibilidad_rotacion_gesto: float = 2.0
@export var sensibilidad_pan_gesto: float = 0.04
@export var velocidad_enfoque: float = 4.0
@export var factor_distancia_planeta: float = 3.5

# --- NODOS ---
@onready var camara: Camera3D = $Camera3D

# Guardamos la posición original del asiento dentro de la cabina para que nunca sea expulsado
var pos_asiento_local: Vector3 = Vector3.ZERO

func _ready() -> void:
	pos_asiento_local = position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Desactivamos la colisión física del CharacterBody3D para que ningún planeta o pared lo empuje fuera de la cabina
	collision_layer = 0
	collision_mask = 0
	
	if camara:
		camara.current = true
		camara.near = 0.05
		camara.far = 300000.0

	if WebcamController:
		WebcamController.rotacion_izquierda.connect(_on_rotacion_izquierda)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad_mouse)
		if camara:
			camara.rotate_x(-event.relative.y * sensibilidad_mouse)
			camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Mantiene al jugador clavado en el asiento de la cabina en todo momento
	position = pos_asiento_local
	velocity = Vector3.ZERO

func _on_rotacion_izquierda(dx: float, dy: float) -> void:
	rotate_y(-dx * sensibilidad_rotacion_gesto)
	if camara:
		camara.rotate_x(-dy * sensibilidad_rotacion_gesto)
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-89), deg_to_rad(89))
