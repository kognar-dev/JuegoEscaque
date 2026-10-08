class_name MoveGenerator
extends RefCounted
## Genera movimientos legales según el patrón de cada tipo de pieza (GDD §6.6).
## Los patrones vienen de la config: "pawn", "leaper" (offsets) y "slider" (direcciones).
## Sin jaque: el Rey puede entrar en casillas amenazadas (§6.6 Rey).


static func forward_dir(owner: int) -> int:
	return 1 if owner == Piece.WHITE else -1


static func is_pawn_retreat(rules: RulesConfig, piece: Piece, to: Vector2i) -> bool:
	return rules.pieces[piece.piece_type]["movement"] == "pawn" \
		and to - piece.position == Vector2i(0, -forward_dir(piece.owner))


static func legal_moves(board: Board, piece: Piece, rules: RulesConfig) -> Array[Vector2i]:
	var def: Dictionary = rules.pieces[piece.piece_type]
	match String(def["movement"]):
		"pawn":
			return _pawn_moves(board, piece, rules)
		"leaper":
			return _leaper_moves(board, piece, def["offsets"])
		"slider":
			return _slider_moves(board, piece, def["directions"], int(def.get("max_range", 0)))
	push_error("Patrón de movimiento desconocido: %s" % def["movement"])
	return []


## Casillas en las que esta pieza capturaría si hubiera una pieza rival (incluye las
## ocupadas por piezas propias: sirve para saber qué piezas están «defendidas»).
static func attack_squares(board: Board, piece: Piece, rules: RulesConfig) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var def: Dictionary = rules.pieces[piece.piece_type]
	match String(def["movement"]):
		"pawn":
			var dy := forward_dir(piece.owner)
			for dx in [-1, 1]:
				var t := piece.position + Vector2i(dx, dy)
				if board.in_bounds(t):
					out.append(t)
		"leaper":
			for o in def["offsets"]:
				var t: Vector2i = piece.position + o
				if board.in_bounds(t):
					out.append(t)
		"slider":
			var max_range := int(def.get("max_range", 0))
			for d in def["directions"]:
				var t: Vector2i = piece.position + d
				var steps := 1
				while board.in_bounds(t) and (max_range <= 0 or steps <= max_range):
					out.append(t)
					if board.piece_at(t) != null:
						break
					t += d
					steps += 1
	return out


static func is_legal(board: Board, piece: Piece, to: Vector2i, rules: RulesConfig) -> bool:
	return to in legal_moves(board, piece, rules)


## Peón: avanza 1 si está vacío; captura 1 en diagonal hacia delante.
## Sin avance doble ni en passant. Opcional: retroceso de 1 sin capturar (pawn_retreat).
static func _pawn_moves(board: Board, piece: Piece, rules: RulesConfig) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dy := forward_dir(piece.owner)
	var ahead := piece.position + Vector2i(0, dy)
	if board.in_bounds(ahead) and board.is_empty(ahead):
		out.append(ahead)
	for dx in [-1, 1]:
		var diag := piece.position + Vector2i(dx, dy)
		if _is_enemy(board, piece, diag):
			out.append(diag)
	if rules.pawn_retreat:
		var back := piece.position - Vector2i(0, dy)
		if board.in_bounds(back) and board.is_empty(back):
			out.append(back)
	return out


## Saltador (Caballo, Rey): salta piezas; casilla vacía o enemiga.
static func _leaper_moves(board: Board, piece: Piece, offsets: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o in offsets:
		var t: Vector2i = piece.position + o
		if not board.in_bounds(t):
			continue
		var occ := board.piece_at(t)
		if occ == null or occ.owner != piece.owner:
			out.append(t)
	return out


## Deslizador (Torre, Alfil, Dama): hasta `max_range` casillas (0 = sin límite),
## no atraviesa piezas.
static func _slider_moves(board: Board, piece: Piece, directions: Array, max_range: int = 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in directions:
		var t: Vector2i = piece.position + d
		var steps := 1
		while board.in_bounds(t) and (max_range <= 0 or steps <= max_range):
			var occ := board.piece_at(t)
			if occ == null:
				out.append(t)
			else:
				if occ.owner != piece.owner:
					out.append(t)
				break
			t += d
			steps += 1
	return out


static func _is_enemy(board: Board, piece: Piece, p: Vector2i) -> bool:
	if not board.in_bounds(p):
		return false
	var occ := board.piece_at(p)
	return occ != null and occ.owner != piece.owner
