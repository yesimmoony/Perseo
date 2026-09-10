extends CanvasLayer

@export var orbit_renderer: orbitaRender
@onready var toggle_btn: CheckBox = $orbitaboton

func _ready() -> void:
	toggle_btn.text = "Órbitas"
	toggle_btn.button_pressed = true
	toggle_btn.toggled.connect(_on_toggle_orbits_toggled)

func _on_toggle_orbits_toggled(toggled_on: bool) -> void:
	if orbit_renderer:
		orbit_renderer.visible = toggled_on
