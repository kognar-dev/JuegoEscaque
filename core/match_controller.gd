class_name MatchController
extends RefCounted
## Fachada entre la UI (o los tests) y las reglas. La UI sólo habla con esta clase.

signal state_changed
signal action_performed(action: Dictionary)
signal turn_ended(summary: Dictionary)
signal match_finished(log_path: String)

var rules: RulesConfig
var state: GameState
var logger: MatchLogger
var _rules_path: String


func _init(log_dir: String = "user://logs", log_enabled: bool = true,
		rules_path: String = RulesConfig.DEFAULT_PATH) -> void:
	logger = MatchLogger.new(log_dir, log_enabled)
	_rules_path = rules_path


func new_match(mode: String) -> void:
	new_match_with_rules(RulesConfig.load_mode(mode, _rules_path))


## Partida con un RulesConfig ya construido (variantes del laboratorio de reglas).
func new_match_with_rules(p_rules: RulesConfig) -> void:
	rules = p_rules
	state = GameState.create(rules)
	TurnController.start_turn(state)
	logger.begin_match(state)
	state_changed.emit()
	if state.over:  # p. ej. sin jugadas desde la posición inicial
		_finish(false)


## Destinos a mostrar: para las piezas del jugador activo, sólo los que puede pagar;
## para las rivales, todo su alcance (consulta).
func legal_moves(piece: Piece) -> Array[Vector2i]:
	if piece.owner == state.active_player and not state.over:
		return TurnController.affordable_moves(state, piece)
	return MoveGenerator.legal_moves(state.board, piece, rules)


func move_cost(piece: Piece, to: Vector2i) -> int:
	return TurnController.move_cost(state, piece, to)


func activation_error(piece: Piece) -> String:
	return TurnController.activation_error(state, piece)


func can_end_turn() -> bool:
	return TurnController.can_end_turn(state)


func projected_reserve() -> int:
	return TurnController.projected_reserve(state)


## Activa una pieza hacia `to`. En C0 el turno termina solo tras la activación.
func activate(piece: Piece, to: Vector2i) -> Dictionary:
	var action := TurnController.activate(state, piece, to)
	if action.has("error"):
		return action
	action_performed.emit(action)
	if state.over:
		_finish()
	elif not rules.uses_ap():
		_end_turn("auto_c0")
	else:
		state_changed.emit()
	return action


func end_turn() -> bool:
	if not can_end_turn():
		return false
	_end_turn("voluntario")
	return true


func declare_draw(cause: String) -> void:
	if state.over:
		return
	VictorySystem.declare_draw(state, cause)
	_finish()


## Guarda el log de una partida sin terminar (nueva partida / cerrar ventana).
func abandon_if_running() -> void:
	if state == null or state.over:
		return
	if state.player_turn <= 1 and state.turn_actions.is_empty():
		return  # no se ha jugado nada: no merece log
	VictorySystem.abandon(state)
	_finish()


func _end_turn(ended_by: String) -> void:
	var summary := TurnController.end_turn(state, ended_by)
	logger.record_turn(summary)
	turn_ended.emit(summary)
	if state.over:
		# Tablas o derrota detectadas al empezar el turno siguiente: ese turno no se jugó.
		_finish(false)
	else:
		state_changed.emit()


## Cierra la partida. `record_current`: registrar el turno en curso (acabado a mitad).
func _finish(record_current: bool = true) -> void:
	if record_current:
		logger.record_turn(TurnController.turn_summary(state, "fin_partida"))
	var path := logger.end_match(state)
	state_changed.emit()
	match_finished.emit(path)
