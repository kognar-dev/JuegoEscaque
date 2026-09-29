class_name VictorySystem
extends RefCounted
## §6.9: capturar al Rey enemigo termina la partida inmediatamente.
## §6.10: el empate es experimental y se declara manualmente con su causa.

const REASON_KING := "rey_capturado"
const REASON_DRAW := "empate_experimental"
const REASON_ABANDONED := "abandonada"


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
