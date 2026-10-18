class_name RanuraAcople
extends Area3D

# --- CONFIGURACION ---
@export var tipo_permitido: DatosPiezas.TipoPieza = DatosPiezas.TipoPieza.INSTRUMENTO
@export var id_pieza_instalada: String = ""
@export var malla_asociada: Node3D

# --- ESTADO ---
var ocupada: bool = false

# --- CICLO DE VIDA ---
func _ready() -> void:
	add_to_group("ranuras_acople")
	if malla_asociada:
		malla_asociada.visible = false

# --- GESTION DE ACOPLE ---
func puede_recibir(tipo: DatosPiezas.TipoPieza) -> bool:
	return not ocupada and tipo == tipo_permitido

func acoplar(id_pieza: String) -> void:
	ocupada = true
	id_pieza_instalada = id_pieza
	if malla_asociada:
		malla_asociada.visible = true

func desacoplar() -> void:
	ocupada = false
	id_pieza_instalada = ""
	if malla_asociada:
		malla_asociada.visible = false
