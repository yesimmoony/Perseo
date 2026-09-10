extends CharacterBody3D

@export var webcam_controller: Node
@export var speed: float = 100.0
@export var sprint: float = 5.0
@export var sensibiidad: float = 0.003
@export var gestosensibiidad: float = 2.0

@onready var camera: Camera3D = $Camera3D

var gesture_pan_dir := Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if WebcamController:
		WebcamController.gesture_data_received.connect(_on_gesture_data_received)
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative.x * sensibiidad, event.relative.y * sensibiidad)

func _rotate_camera(x_delta: float, y_delta: float) -> void:
	rotate_y(-x_delta)
	camera.rotate_x(-y_delta)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _on_gesture_data_received(l_action: String, r_action: String, dx: float, dy: float, palm_size: float) -> void:
	if r_action == "ROTATE":
		_rotate_camera(dx * gestosensibiidad, dy * gestosensibiidad)
		gesture_pan_dir = Vector3.ZERO
	elif r_action == "PAN":
		gesture_pan_dir = (camera.global_transform.basis * Vector3(-dx, dy, 0)).normalized()
	else:
		gesture_pan_dir = Vector3.ZERO

	if l_action == "ZOOM":
		camera.fov = clamp(110.0 - (palm_size * 200.0), 30.0, 100.0)

func _physics_process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var input_2d := Input.get_vector("izquierda", "derecha", "arriba", "abajo")

	var direction := Vector3.ZERO
	if input_2d != Vector2.ZERO:
		direction = (camera.global_transform.basis * Vector3(input_2d.x, 0, input_2d.y)).normalized()
	elif gesture_pan_dir != Vector3.ZERO:
		direction = gesture_pan_dir

	var current_speed := speed
	if Input.is_action_pressed("ui_select"):
		current_speed *= sprint

	velocity = direction * current_speed
	move_and_slide()
