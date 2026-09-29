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

var over: bool = false
var winner: int = -1            ## -1 = sin ganador (en curso o empate)
var end_reason: String = ""     ## "rey_capturado" | "empate_experimental" | "abandonada"
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


func opponent(of: int = -1) -> int:
	if of < 0:
		of = active_player
	return 1 - of


func ap_spent_this_turn() -> int:
	var total := 0
	for a in turn_actions:
		total += int(a["cost"])
	return total
