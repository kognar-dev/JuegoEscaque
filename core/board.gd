class_name Board
extends RefCounted
## Límites, ocupación, trayectorias y movimiento/captura (GDD §13.3).
## Coordenadas: x = columna (0 = a), y = fila (0 = fila 1). Blancas avanzan hacia +y.

var size: int
var _grid: Dictionary = {}  # Vector2i -> Piece
var _pieces: Array[Piece] = []


func _init(p_size: int = 8) -> void:
	size = p_size


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size and p.y < size


func piece_at(p: Vector2i) -> Piece:
	return _grid.get(p, null)


func is_empty(p: Vector2i) -> bool:
	return not _grid.has(p)


func place(piece: Piece) -> void:
	assert(in_bounds(piece.position) and is_empty(piece.position))
	_grid[piece.position] = piece
	_pieces.append(piece)


## Mueve la pieza; si el destino está ocupado por un rival, lo captura.
## Devuelve la pieza capturada o null.
func move(piece: Piece, to: Vector2i) -> Piece:
	var victim: Piece = piece_at(to)
	assert(victim == null or victim.owner != piece.owner)
	if victim:
		victim.captured = true
		_grid.erase(to)
	_grid.erase(piece.position)
	piece.position = to
	_grid[to] = piece
	return victim


func all_pieces(include_captured: bool = false) -> Array[Piece]:
	var out: Array[Piece] = []
	for p in _pieces:
		if include_captured or not p.captured:
			out.append(p)
	return out


func pieces_of(owner: int) -> Array[Piece]:
	var out: Array[Piece] = []
	for p in _pieces:
		if p.owner == owner and not p.captured:
			out.append(p)
	return out


func get_piece(id: int) -> Piece:
	for p in _pieces:
		if p.id == id:
			return p
	return null


## Copia independiente (sólo piezas en juego), para que la IA simule sin tocar la partida.
func clone() -> Board:
	var b := Board.new(size)
	for p in _pieces:
		if p.captured:
			continue
		var q := Piece.new(p.id, p.owner, p.piece_type, p.position, p.activation_cost)
		q.activations_this_turn = p.activations_this_turn
		b._grid[q.position] = q
		b._pieces.append(q)
	return b


static func square_name(p: Vector2i) -> String:
	return "%s%d" % [char(97 + p.x), p.y + 1]


static func parse_square(s: String) -> Vector2i:
	return Vector2i(s.unicode_at(0) - 97, int(s.substr(1)) - 1)
