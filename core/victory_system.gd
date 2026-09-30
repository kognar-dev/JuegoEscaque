class_name VictorySystem
extends RefCounted
## §6.9: capturar al Rey enemigo termina la partida inmediatamente.
## §6.10: el empate es experimental y se declara manualmente con su causa.

const REASON_KING := "rey_capturado"
const REASON_DRAW := "empate_experimental"
const REASON_ABANDONED := "abandonada"
const REASON_REPETITION := "tablas_repeticion"
const REASON_NO_PROGRESS := "tablas_sin_progreso"
const REASON_NO_MOVES := "sin_jugadas"

const DRAW_REASONS := [REASON_DRAW, REASON_REPETITION, REASON_NO_PROGRESS]


## Comprobaciones automáticas al inicio de cada turno (Anexo A · A.2.2, A.2.3).
## Orden: sin jugadas → repetición → sin progreso.
static func on_turn_start(s: GameState) -> void:
	if s.over:
		return
	var r := s.rules
	if r.no_moves_loses and not has_any_legal_move(s):
		s.over = true
		s.winner = s.opponent()
		s.end_reason = REASON_NO_MOVES
		return
	var key := s.position_key()
	s.current_repetition = int(s.position_counts.get(key, 0)) + 1
	s.position_counts[key] = s.current_repetition
	if r.repetition_limit > 0 and s.current_repetition >= r.repetition_limit:
		_auto_draw(s, REASON_REPETITION, "posición repetida %d veces" % s.current_repetition)
		return
	if r.no_progress_turns > 0 and s.turns_without_progress >= r.no_progress_turns:
		_auto_draw(s, REASON_NO_PROGRESS,
			"%d turnos sin captura ni movimiento de peón" % s.turns_without_progress)


## Movimiento legal para alguna pieza del jugador activo, sin mirar PA.
static func has_any_legal_move(s: GameState) -> bool:
	for p in s.board.pieces_of(s.active_player):
		if not MoveGenerator.legal_moves(s.board, p, s.rules).is_empty():
			return true
	return false


static func is_draw(s: GameState) -> bool:
	return s.over and s.end_reason in DRAW_REASONS


static func _auto_draw(s: GameState, reason: String, cause: String) -> void:
	s.over = true
	s.winner = -1
	s.end_reason = reason
	s.draw_cause = cause


static func on_capture(s: GameState, attacker: Piece, victim: Piece) -> void:
	if victim == null:
		return
	if bool(s.rules.pieces[victim.piece_type].get("royal", false)):
		s.over = true
		s.winner = attacker.owner
		s.end_reason = REASON_KING


static func declare_draw(s: GameState, cause: String) -> void:
	if s.over:
		return
	s.over = true
	s.winner = -1
	s.end_reason = REASON_DRAW
	s.draw_cause = cause


static func abandon(s: GameState) -> void:
	if s.over:
		return
	s.over = true
	s.winner = -1
	s.end_reason = REASON_ABANDONED
