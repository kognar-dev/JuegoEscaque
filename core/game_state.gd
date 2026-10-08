class_name GameState
extends RefCounted
## Estado completo de una partida (GDD §13.3). Sin lógica de reglas: ver TurnController.

var rules: RulesConfig
var board: Board

var player_turn: int = 0        ## turnos de jugador iniciados (1, 2, 3...)
var round_number: int = 0       ## ronda = un turno de cada jugador
var active_player: int = Piece.WHITE
var ap_available: int = 0
var ap_at_turn_start: int = 0
var reserve: Array[int] = [0, 0]
## Activaciones del turno en curso, en orden. Cada una es un Dictionary de acción.
var turn_actions: Array[Dictionary] = []

## Tablas automáticas: veces que se ha visto cada posición al inicio de turno,
## y turnos de jugador seguidos sin captura ni movimiento de peón.
var position_counts: Dictionary = {}
var current_repetition: int = 1
var turns_without_progress: int = 0
## Fila más avanzada que ha alcanzado cada peón (id -> avance). Sólo superar ese récord
## cuenta como progreso: con retroceso, ir y volver no evita las tablas.
var pawn_best: Dictionary = {}

var over: bool = false
var winner: int = -1            ## -1 = sin ganador (en curso o empate)
var end_reason: String = ""     ## ver constantes REASON_* en VictorySystem
var draw_cause: String = ""


static func create(p_rules: RulesConfig) -> GameState:
	var s := GameState.new()
	s.rules = p_rules
	s.board = Board.new(p_rules.board_size)
	s.active_player = p_rules.first_player
	var next_id := 1
	var n := p_rules.board_size
	for i in p_rules.setup_rows.size():
		var row: String = p_rules.setup_rows[i]
		var y := n - 1 - i  # la primera fila del JSON es la fila superior (8)
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var owner := Piece.WHITE if ch == ch.to_upper() else Piece.BLACK
			var type: String = p_rules.symbol_to_type.get(ch.to_lower(), "")
			assert(type != "", "Símbolo desconocido en setup: %s" % ch)
			s.board.place(Piece.new(next_id, owner, type, Vector2i(x, y), p_rules.pieces[type]["cost"]))
			next_id += 1
	return s


## Copia para simulación: tablero y contadores, sin historial de posiciones.
func clone() -> GameState:
	var s := GameState.new()
	s.rules = rules
	s.board = board.clone()
	s.player_turn = player_turn
	s.round_number = round_number
	s.active_player = active_player
	s.ap_available = ap_available
	s.ap_at_turn_start = ap_at_turn_start
	s.reserve = reserve.duplicate()
	s.turn_actions = turn_actions.duplicate()
	s.current_repetition = current_repetition
	s.turns_without_progress = turns_without_progress
	s.pawn_best = pawn_best.duplicate()
	s.over = over
	s.winner = winner
	s.end_reason = end_reason
	return s


func royal_pieces(owner: int) -> Array[Piece]:
	var out: Array[Piece] = []
	for p in board.pieces_of(owner):
		if bool(rules.pieces[p.piece_type].get("royal", false)):
			out.append(p)
	return out


func opponent(of: int = -1) -> int:
	if of < 0:
		of = active_player
	return 1 - of


## Clave de posición para la repetición, calculada al inicio de turno: piezas,
## jugador activo, PA disponibles y Reserva del rival (la misma posición con 6 u
## 8 PA no es la misma situación).
func position_key() -> String:
	var parts: PackedStringArray = []
	for p in board.all_pieces():
		parts.append("%s%d@%d,%d" % [p.piece_type, p.owner, p.position.x, p.position.y])
	parts.sort()
	return "%s|%d|%d|%d" % [";".join(parts), active_player, ap_available, reserve[opponent()]]


func ap_spent_this_turn() -> int:
	var total := 0
	for a in turn_actions:
		total += int(a["cost"])
	return total
