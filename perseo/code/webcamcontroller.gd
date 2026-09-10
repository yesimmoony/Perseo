extends Node

# --- SEÑALES ---
signal toggle_play_requested
signal gesture_changed(status_text: String)
signal gesture_data_received(l_action: String, r_action: String, dx: float, dy: float, palm_size: float)
signal cursor_actualizado(activo: bool, posicion_normalizada: Vector2, haciendo_pinch: bool)

# --- CONFIGURACION ---
@export_group("Configuración del Tracker")
@export var python_command: String = "C:/Users/lolap/AppData/Local/Python/pythoncore-3.14-64/python.exe"
@export var python_script_path: String = "res://python/trackingcontroller.py"
@export var port: int = 4242

# --- VARIABLES ---
var udp := PacketPeerUDP.new()
var last_fist_time: int = 0
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
			push_error("WebcamController: No se pudo iniciar el proceso de Python. Verificá la ruta del ejecutable.")
	else:
		var exe_path := OS.get_executable_path().get_base_dir().path_join("bin").path_join("trackingcontroller.exe")
		if FileAccess.file_exists(exe_path):
			tracker_pid = OS.create_process(exe_path, [parent_pid])
		else:
			push_error("WebcamController: No se encontró el ejecutable en: " + exe_path)

# --- RECEPCION UDP ---
func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var json = JSON.parse_string(packet.get_string_from_utf8())
		if json is Dictionary:
			_process_gestures(json)

func _process_gestures(data: Dictionary) -> void:
	var l_action: String = data.get("l_action", "NONE")
	var r_action: String = data.get("r_action", "NONE")
	var dx: float = float(data.get("dx", 0.0))
	var dy: float = float(data.get("dy", 0.0))
	var palm_size: float = float(data.get("palm_size", 0.0))

	gesture_changed.emit("Izq: " + l_action + " | Der: " + r_action)

	if l_action == "TOGGLE_PLAY":
		var now = Time.get_ticks_msec()
		if now - last_fist_time > 1500:
			last_fist_time = now
			toggle_play_requested.emit()

	gesture_data_received.emit(l_action, r_action, dx, dy, palm_size)

	var cursor_activo: bool = bool(data.get("cursor_active", false))
	var cursor_pos := Vector2(float(data.get("cursor_x", 0.0)), float(data.get("cursor_y", 0.0)))
	var haciendo_pinch: bool = bool(data.get("is_pinching", false))
	cursor_actualizado.emit(cursor_activo, cursor_pos, haciendo_pinch)
