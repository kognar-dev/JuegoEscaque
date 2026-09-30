class_name TurnController
extends RefCounted
## Economía de turno (GDD §6.4, §6.5, §6.8) y control C0 (§7.1).
## Funciones estáticas y puras sobre GameState: fáciles de testear.

## Códigos de motivo por los que una pieza no puede activarse (texto para la UI).
const ERR_OVER := "La partida ha terminado"
const ERR_NOT_YOURS := "No es tu pieza"
const ERR_EXHAUSTED := "Pieza agotada este turno"
const ERR_NO_AP := "PA insuficientes"
const ERR_NO_MOVES := "Sin movimientos legales"
const ERR_C0_DONE := "Ya has activado una pieza este turno"
const ERR_ILLEGAL := "Movimiento ilegal"


## §6.4: PA = base + Reserva; la Reserva vuelve a 0. Se reinician activaciones.
static func start_turn(s: GameState) -> void:
	s.player_turn += 1
	if s.active_player == s.rules.first_player:
		s.round_number += 1
	s.turn_actions.clear()
	for p in s.board.pieces_of(s.active_player):
		p.activations_this_turn = 0
	if s.rules.uses_ap():
		s.ap_available = s.rules.base_ap + s.reserve[s.active_player]
		s.reserve[s.active_player] = 0
	else:
		s.ap_available = 0
	s.ap_at_turn_start = s.ap_available
	VictorySystem.on_turn_start(s)


## Devuelve "" si la pieza puede activarse ahora, o el motivo si no.
static func activation_error(s: GameState, piece: Piece) -> String:
	if s.over:
		return ERR_OVER
	if piece.owner != s.active_player:
		return ERR_NOT_YOURS
	if not s.rules.uses_ap() and s.turn_actions.size() >= 1:
		return ERR_C0_DONE
	if piece.activations_this_turn >= s.rules.max_activations_per_piece:
		return ERR_EXHAUSTED
	if s.rules.cost_of(piece.piece_type) > s.ap_available:
		return ERR_NO_AP
	if MoveGenerator.legal_moves(s.board, piece, s.rules).is_empty():
		return ERR_NO_MOVES
	return ""


static func can_activate(s: GameState, piece: Piece) -> bool:
	return activation_error(s, piece) == ""


static func has_any_activation(s: GameState) -> bool:
	for p in s.board.pieces_of(s.active_player):
		if can_activate(s, p):
			return true
	return false


## §6.5: pagar coste → ejecutar exactamente un movimiento legal → marcar agotada.
## Devuelve el Dictionary de acción, o { "error": motivo }.
static func activate(s: GameState, piece: Piece, to: Vector2i) -> Dictionary:
	var err := activation_error(s, piece)
	if err != "":
		return {"error": err}
	if not MoveGenerator.is_legal(s.board, piece, to, s.rules):
		return {"error": ERR_ILLEGAL}

	var cost := s.rules.cost_of(piece.piece_type)
	var from := piece.position
	s.ap_available -= cost
	assert(s.ap_available >= 0)
	var victim := s.board.move(piece, to)
	piece.activations_this_turn += 1

	var action := {
		"order": s.turn_actions.size() + 1,
		"player": Piece.owner_key(piece.owner),
		"piece_id": piece.id,
		"piece": piece.piece_type,
		"cost": cost if s.rules.uses_ap() else null,
		"from": Board.square_name(from),
		"to": Board.square_name(to),
		"capture": victim != null,
		"captured": victim.piece_type if victim else null,
		"captured_id": victim.id if victim else null,
		"ap_after": s.ap_available if s.rules.uses_ap() else null,
	}
	s.turn_actions.append(action)
	VictorySystem.on_capture(s, piece, victim)
	return action


## En P0 se puede terminar siempre. En C0 sólo tras activar (o si no hay activación posible).
static func can_end_turn(s: GameState) -> bool:
	if s.over:
		return false
	if s.rules.uses_ap():
		return true
	return s.turn_actions.size() >= 1 or not has_any_activation(s)


## Reserva que quedaría si se terminase el turno ahora (§13.6).
static func projected_reserve(s: GameState) -> int:
	if not s.rules.uses_ap():
		return 0
	return mini(s.ap_available, s.rules.max_reserve)


## Piezas que aún podrían activarse (para medir el ahorro deliberado de PA).
static func activatable_count(s: GameState) -> int:
	var n := 0
	for p in s.board.pieces_of(s.active_player):
		if can_activate(s, p):
			n += 1
	return n


## Hubo progreso si alguna activación capturó o movió un peón (regla de «sin progreso»).
static func turn_made_progress(s: GameState) -> bool:
	for a in s.turn_actions:
		if a["capture"] or a["piece"] == "pawn":
			return true
	return false


## Resumen del turno en curso (se usa al terminarlo y al acabar la partida a mitad).
static func turn_summary(s: GameState, ended_by: String) -> Dictionary:
	var uses_ap := s.rules.uses_ap()
	var reserved := projected_reserve(s) if ended_by != "fin_partida" else 0
	var seq: Array = []
	for a in s.turn_actions:
		seq.append(a["piece"])
	return {
		"index": s.player_turn,
		"round": s.round_number,
		"player": Piece.owner_key(s.active_player),
		"ap_start": s.ap_at_turn_start if uses_ap else null,
		"ap_spent": s.ap_spent_this_turn() if uses_ap else null,
		"ap_left": s.ap_available if uses_ap else null,
		"ap_reserved": reserved if uses_ap else null,
		"ap_lost": (s.ap_available - reserved) if uses_ap and ended_by != "fin_partida" else null,
		"activations": s.turn_actions.size(),
		"sequence": seq,
		"ended_by": ended_by,
		"activatable_left": activatable_count(s) if ended_by != "fin_partida" else null,
		"turns_without_progress": s.turns_without_progress,
		"position_repetition": s.current_repetition,
		"actions": s.turn_actions.duplicate(true),
	}


## §6.8: Reserva = min(PA restantes, máx). Cambia jugador y arranca el siguiente turno.
## Devuelve el resumen del turno terminado (o {} si no se podía terminar).
static func end_turn(s: GameState, ended_by: String = "voluntario") -> Dictionary:
	if not can_end_turn(s):
		return {}
	var summary := turn_summary(s, ended_by)
	s.turns_without_progress = 0 if turn_made_progress(s) else s.turns_without_progress + 1
	if s.rules.uses_ap():
		s.reserve[s.active_player] = projected_reserve(s)
	s.ap_available = 0
	s.active_player = s.opponent()
	start_turn(s)
	return summary
