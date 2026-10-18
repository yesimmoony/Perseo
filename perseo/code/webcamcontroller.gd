extends Node

# --- SEÑALES ---
signal cursor_actualizado(activo: bool, posicion_normalizada: Vector2, haciendo_pinch: bool)
signal rotacion_izquierda(dx: float, dy: float)

# --- CONFIGURACION ---
@export_group("Configuración del Tracker")
@export var python_command: String = "C:/Users/lolap/AppData/Local/Python/pythoncore-3.14-64/python.exe"
@export var python_script_path: String = "res://python/trackingcontroller.py"
@export var port: int = 4242

# --- VARIABLES ---
var udp := PacketPeerUDP.new()
var tracker_pid: int = -1

# --- CICLO DE VIDA ---
func _ready() -> void:
	udp.bind(port)
	_start_tracker()

func _exit_tree() -> void:
	_kill_tracker()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_kill_tracker()

func _kill_tracker() -> void:
	if tracker_pid != -1:
		OS.kill(tracker_pid)
		tracker_pid = -1

# --- PROCESO TRACKER ---
func _start_tracker() -> void:
	var parent_pid := str(OS.get_process_id())

	if OS.has_feature("editor"):
		var global_py_path := ProjectSettings.globalize_path(python_script_path)
		if not FileAccess.file_exists(python_script_path):
			push_error("WebcamController: No se encontró el script de Python en: " + global_py_path)
			return

		tracker_pid = OS.create_process("cmd.exe", ["/k", python_command, global_py_path, parent_pid], true)
		if tracker_pid == -1:
			push_error("WebcamController: No se pudo iniciar el proceso de Python.")
	else:
		var exe_path := OS.get_executable_path().get_base_dir().path_join("bin").path_join("trackingcontroller.exe")
		if FileAccess.file_exists(exe_path):
			tracker_pid = OS.create_process(exe_path, [parent_pid])

# --- RECEPCION UDP ---
func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var json = JSON.parse_string(packet.get_string_from_utf8())
		if json is Dictionary:
			_process_gestures(json)

func _process_gestures(data: Dictionary) -> void:
	var cursor_activo: bool = bool(data.get("cursor_active", false))
	var cursor_pos := Vector2(float(data.get("cursor_x", 0.0)), float(data.get("cursor_y", 0.0)))
	var haciendo_pinch: bool = bool(data.get("is_pinching", false))
	cursor_actualizado.emit(cursor_activo, cursor_pos, haciendo_pinch)

	if bool(data.get("l_pinch", false)):
		var l_dx: float = float(data.get("l_dx", 0.0))
		var l_dy: float = float(data.get("l_dy", 0.0))
		rotacion_izquierda.emit(l_dx, l_dy)
