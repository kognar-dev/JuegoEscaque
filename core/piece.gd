class_name Piece
extends RefCounted
## Datos mínimos de pieza (GDD §13.3).

const WHITE := 0
const BLACK := 1

var id: int
var owner: int
var piece_type: String
var position: Vector2i
var activation_cost: int
var activations_this_turn: int = 0
var captured: bool = false


func _init(p_id: int, p_owner: int, p_type: String, p_pos: Vector2i, p_cost: int) -> void:
	id = p_id
	owner = p_owner
	piece_type = p_type
	position = p_pos
	activation_cost = p_cost


var activated_this_turn: bool:
	get:
		return activations_this_turn > 0


static func owner_name(o: int) -> String:
	return "Blancas" if o == WHITE else "Negras"


static func owner_key(o: int) -> String:
	return "white" if o == WHITE else "black"
