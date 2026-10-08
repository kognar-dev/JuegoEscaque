extends Control
## Escena principal: conecta la UI con MatchController (GDD §13.5, §13.6).
## Estados de interacción: esperando selección → pieza seleccionada (+ movimientos
## legales) → movimiento confirmado → estado actualizado → esperando selección.

@onready var board_view: BoardView = %BoardView
@onready var mode_select: OptionButton = %ModeSelect
@onready var new_game_button: Button = %NewGameButton
@onready var turn_label: Label = %TurnLabel
@onready var player_label: Label = %PlayerLabel
@onready var ap_label: Label = %APLabel
@onready var ap_meter: APMeter = %APMeter
@onready var projection_label: Label = %ProjectionLabel
@onready var reserve_label: Label = %ReserveLabel
@onready var selection_label: Label = %SelectionLabel
@onready var sequence_label: Label = %SequenceLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var history: RichTextLabel = %History
@onready var draw_button: Button = %DrawButton
@onready var logs_button: Button = %LogsButton
@onready var game_over_layer: ColorRect = %GameOverLayer
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_detail: Label = %GameOverDetail
@onready var game_over_log: Label = %GameOverLog
@onready var draw_dialog: ConfirmationDialog = %DrawDialog
@onready var draw_cause: LineEdit = %DrawCause

const LOG_ANALYZER := preload("res://core/log_analyzer.gd")
const AI := preload("res://core/ai_player.gd")
## Pausas para que la jugada de la IA se pueda seguir con la vista.
const AI_THINK_DELAY := 0.35
const AI_STEP_DELAY := 0.5

## Quién controla cada bando: "human" o un nivel de IA ("facil", "normal", "dificil").
const CONTROLLERS := ["human", "facil", "normal", "dificil"]

var mc: MatchController
var selected: Piece = null
var _mode_ids: Array[String] = []
var _ai_busy := false
var _match_token := 0  ## invalida jugadas pendientes de la IA al empezar otra partida
@onready var _ctrl_buttons: Array[OptionButton] = [%WhiteCtrl, %BlackCtrl]


func _ready() -> void:
	mc = MatchController.new()
	mc.state_changed.connect(_refresh)
	mc.action_performed.connect(_on_action)
	mc.turn_ended.connect(_on_turn_ended)
	mc.match_finished.connect(_on_match_finished)
	board_view.mc = mc
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.cancel_requested.connect(_deselect)

	var modes := RulesConfig.available_modes()
	for id in modes.keys():
		_mode_ids.append(id)
		mode_select.add_item(modes[id])

	new_game_button.pressed.connect(func(): _start(_mode_ids[mode_select.selected]))
	%GameOverNewButton.pressed.connect(func(): _start(_mode_ids[mode_select.selected]))
	%GameOverCloseButton.pressed.connect(func(): game_over_layer.hide())
	end_turn_button.pressed.connect(_try_end_turn)
	draw_button.pressed.connect(_ask_draw)
	draw_dialog.confirmed.connect(_confirm_draw)
	draw_dialog.register_text_enter(draw_cause)  # Enter en la causa = confirmar
	logs_button.pressed.connect(_open_logs)
	%ReportButton.pressed.connect(_make_report)

	for i in 2:
		var ob := _ctrl_buttons[i]
		for c in CONTROLLERS:
			ob.add_item("Humano" if c == "human" else AI.level_label(c))
		ob.select(0)
		ob.item_selected.connect(func(_idx): _maybe_ai_turn())

	get_tree().set_auto_accept_quit(false)
	_start("P0")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mc:
			mc.abandon_if_running()  # guarda el log de la partida sin terminar
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_try_end_turn()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_deselect()
				get_viewport().set_input_as_handled()


# --- partida ------------------------------------------------------------------

func _start(mode: String) -> void:
	_match_token += 1
	_ai_busy = false
	mc.abandon_if_running()
	selected = null
	board_view.selected = null
	board_view.move_targets.clear()
	board_view.last_from = BoardView.NONE
	board_view.last_to = BoardView.NONE
	history.clear()
	game_over_layer.hide()
	mode_select.select(_mode_ids.find(mode))
	mc.new_match(mode)
	history.append_text("[color=#9aa0a8]Nueva partida · %s[/color]\n" % mc.rules.mode_label)
	_turn_header()
	_refresh()


func _try_end_turn() -> void:
	if mc.state.over or not mc.can_end_turn() or _is_ai_turn():
		return
	_deselect()
	mc.end_turn()


func _ask_draw() -> void:
	if mc.state.over:
		return
	draw_cause.text = ""
	draw_dialog.reset_size()
	draw_dialog.popup_centered()
	draw_cause.grab_focus()


func _confirm_draw() -> void:
	var cause := draw_cause.text.strip_edges()
	mc.declare_draw(cause if cause != "" else "sin causa indicada")


func _open_logs() -> void:
	DirAccess.make_dir_recursive_absolute(mc.logger.log_dir)
	OS.shell_open(ProjectSettings.globalize_path(mc.logger.log_dir))


func _make_report() -> void:
	DirAccess.make_dir_recursive_absolute(mc.logger.log_dir)
	# preload: no depender de la caché global de clases (falla si el editor aún no la regeneró)
	var path: String = LOG_ANALYZER.write_report(mc.logger.log_dir)
	if path == "":
		selection_label.text = "No se pudo generar el informe."
		return
	selection_label.text = "Informe generado: " + ProjectSettings.globalize_path(path)
	OS.shell_open(ProjectSettings.globalize_path(path))


# --- selección ----------------------------------------------------------------

func _on_cell_clicked(cell: Vector2i) -> void:
	if mc.state.over or _is_ai_turn():
		return
	if selected and board_view.targets_actionable and cell in board_view.move_targets:
		var piece := selected
		_deselect()
		var result := mc.activate(piece, cell)
		if result.has("error"):
			selection_label.text = result["error"]
		return
	var p := mc.state.board.piece_at(cell)
	if p == null or p == selected:
		_deselect()
		return
	_select(p)


func _select(p: Piece) -> void:
	selected = p
	board_view.selected = p
	board_view.move_targets = mc.legal_moves(p)
	var err := mc.activation_error(p)
	board_view.targets_actionable = err == ""
	var name := mc.rules.piece_name(p.piece_type)
	var cost_txt := " · coste %d PA" % mc.rules.cost_of(p.piece_type) if mc.rules.uses_ap() else ""
	if p.owner != mc.state.active_player:
		selection_label.text = "%s %s%s — alcance rival (sólo consulta)" % [name, _side_adj(p.owner), cost_txt]
	elif err == "":
		var extra := ""
		if mc.rules.pawn_retreat and mc.rules.pieces[p.piece_type]["movement"] == "pawn" and mc.rules.uses_ap():
			extra = " (retroceder: %d PA)" % (mc.rules.cost_of(p.piece_type) * mc.rules.pawn_retreat_cost_factor)
		selection_label.text = "%s%s%s — elige destino" % [name, cost_txt, extra]
	else:
		selection_label.text = "%s%s — no activable: %s" % [name, cost_txt, err]
	board_view.queue_redraw()


func _deselect() -> void:
	selected = null
	board_view.selected = null
	board_view.move_targets.clear()
	board_view.targets_actionable = true
	if mc and mc.state and not mc.state.over:
		selection_label.text = "Selecciona una pieza. Clic derecho / Esc para cancelar."
	board_view.queue_redraw()


# --- eventos del controlador ----------------------------------------------------

func _on_action(a: Dictionary) -> void:
	board_view.last_from = Board.parse_square(a["from"])
	board_view.last_to = Board.parse_square(a["to"])
	var name := mc.rules.piece_name(a["piece"])
	var cost_txt := " [color=#e3b341](%d)[/color]" % int(a["cost"]) if a["cost"] != null else ""
	var cap := ""
	if a["capture"]:
		cap = " [color=#e07a70]× %s[/color]" % mc.rules.piece_name(a["captured"])
	history.append_text("   %d. %s %s→%s%s%s\n" % [a["order"], name, a["from"], a["to"], cap, cost_txt])


func _on_turn_ended(summary: Dictionary) -> void:
	if summary["ap_start"] != null:
		var lost := int(summary["ap_lost"])
		history.append_text("   [color=#9aa0a8]fin: gasta %d, reserva %d%s[/color]\n" % [
			int(summary["ap_spent"]), int(summary["ap_reserved"]),
			(", pierde %d" % lost) if lost > 0 else ""])
	elif int(summary["activations"]) == 0:
		history.append_text("   [color=#9aa0a8]pasa (sin activaciones posibles)[/color]\n")
	_turn_header()


func _turn_header() -> void:
	var s := mc.state
	var ap := " · %d PA" % s.ap_available if mc.rules.uses_ap() else ""
	history.append_text("[b]T%d %s[/b][color=#9aa0a8]%s[/color]\n" % [s.player_turn, Piece.owner_name(s.active_player), ap])


func _on_match_finished(log_path: String) -> void:
	var s := mc.state
	match s.end_reason:
		VictorySystem.REASON_KING:
			game_over_title.text = "Ganan %s" % Piece.owner_name(s.winner)
			game_over_detail.text = "Rey capturado en el turno %d (ronda %d)." % [s.player_turn, s.round_number]
		VictorySystem.REASON_DRAW:
			game_over_title.text = "Tablas pactadas"
			game_over_detail.text = "Causa: %s · turno %d" % [s.draw_cause, s.player_turn]
		VictorySystem.REASON_REPETITION, VictorySystem.REASON_NO_PROGRESS:
			game_over_title.text = "Tablas"
			game_over_detail.text = "%s (turno %d)." % [s.draw_cause.substr(0, 1).to_upper() + s.draw_cause.substr(1), s.player_turn]
		VictorySystem.REASON_NO_MOVES:
			game_over_title.text = "Ganan %s" % Piece.owner_name(s.winner)
			game_over_detail.text = "%s no tienen movimientos legales (turno %d)." % [
				Piece.owner_name(s.opponent(s.winner)), s.player_turn]
		_:
			return  # abandonada: no mostramos panel
	history.append_text("[b]%s[/b] — %s\n" % [game_over_title.text, game_over_detail.text])
	game_over_log.text = ("Log: " + ProjectSettings.globalize_path(log_path)) if log_path != "" else "Log desactivado"
	game_over_layer.show()


# --- HUD ------------------------------------------------------------------------

func _refresh() -> void:
	var s := mc.state
	if s == null:
		return
	var uses_ap := mc.rules.uses_ap()
	turn_label.text = "%s · turno %d · ronda %d%s" % [mc.rules.mode_id, s.player_turn, s.round_number, _end_rules_hint(s)]
	player_label.text = ("Fin de partida" if s.over else "Juegan %s" % Piece.owner_name(s.active_player))
	player_label.add_theme_color_override("font_color",
		Color("#f4f1e8") if s.active_player == Piece.WHITE else Color("#b9bcc4"))

	ap_label.visible = uses_ap
	ap_meter.visible = uses_ap
	reserve_label.visible = uses_ap
	projection_label.visible = not s.over
	if not uses_ap:
		projection_label.text = "Control C0: sin PA ni Reserva. Una activación por turno; el turno pasa solo."
	if uses_ap:
		var proj := mc.projected_reserve()
		ap_label.text = "PA disponibles: %d / %d" % [s.ap_available, s.ap_at_turn_start]
		ap_meter.set_values(s.ap_available, s.ap_at_turn_start, proj if not s.over else 0)
		var lost := s.ap_available - proj
		projection_label.text = "Si terminas ahora: guardas %d PA%s" % [proj, (" · se pierden %d" % lost) if lost > 0 else ""]
		reserve_label.text = "Reserva acumulada · Blancas %d · Negras %d  (máx. %d)" % [
			s.reserve[0], s.reserve[1], mc.rules.max_reserve]

	var parts: PackedStringArray = []
	for a in s.turn_actions:
		var c := " (%d)" % int(a["cost"]) if a["cost"] != null else ""
		parts.append("%s %s→%s%s" % [mc.rules.pieces[a["piece"]]["letter"], a["from"], a["to"], c])
	sequence_label.text = "Activadas este turno: " + (" → ".join(parts) if parts.size() > 0 else "—")

	var can_end := mc.can_end_turn() and not _is_ai_turn()
	end_turn_button.disabled = not can_end
	if uses_ap:
		end_turn_button.text = "Fin de turno  [Espacio]"
	else:
		end_turn_button.text = "Pasar turno (sin jugadas)" if can_end else "C0: activa una pieza"
	draw_button.disabled = s.over

	if s.over:
		selection_label.text = "Partida terminada. Pulsa «Nueva partida» para jugar otra."
	elif selected == null:
		if _is_ai_turn():
			selection_label.text = "Juega la %s." % AI.level_label(_controller(s.active_player))
		elif uses_ap and not TurnController.has_any_activation(s):
			selection_label.text = "No quedan activaciones posibles: termina el turno."
		else:
			selection_label.text = "Selecciona una pieza. Clic derecho / Esc para cancelar."
	board_view.queue_redraw()
	if not _ai_busy:
		_maybe_ai_turn.call_deferred()


## Contadores visibles de tablas automáticas: sólo cuando empiezan a importar.
func _end_rules_hint(s: GameState) -> String:
	var parts: PackedStringArray = []
	var r := mc.rules
	if r.no_progress_turns > 0 and s.turns_without_progress >= r.no_progress_turns / 2:
		parts.append("sin progreso %d/%d" % [s.turns_without_progress, r.no_progress_turns])
	if r.repetition_limit > 0 and s.current_repetition >= 2 and not s.over:
		parts.append("posición repetida %d/%d" % [s.current_repetition, r.repetition_limit])
	return "  ·  " + " · ".join(parts) if parts.size() > 0 else ""


# --- IA ---------------------------------------------------------------------------

func _controller(player: int) -> String:
	return CONTROLLERS[_ctrl_buttons[player].selected]


func _is_ai_turn() -> bool:
	return mc.state != null and not mc.state.over and _controller(mc.state.active_player) != "human"


## Si le toca a la IA, planifica el turno y lo ejecuta paso a paso, con pausas visibles.
func _maybe_ai_turn() -> void:
	if _ai_busy or not _is_ai_turn():
		return
	_ai_busy = true
	var token := _match_token
	selection_label.text = "La IA está pensando…"
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	if token != _match_token or not _is_ai_turn():
		_ai_busy = false
		return
	var ai = AI.new(_controller(mc.state.active_player))
	var plan: Array[Dictionary] = ai.plan_turn(mc.state)
	for step in plan:
		if token != _match_token or mc.state.over:
			break
		var piece := mc.state.board.get_piece(step["piece_id"])
		_select(piece)  # se ve qué pieza activa y adónde puede ir
		await get_tree().create_timer(AI_STEP_DELAY).timeout
		if token != _match_token or mc.state.over:
			break
		_deselect()
		mc.activate(piece, step["to"])
		if not mc.rules.uses_ap():
			break  # en C0 el turno pasa solo
	if token == _match_token and not mc.state.over and (mc.rules.uses_ap() or plan.is_empty()) \
			and _controller(mc.state.active_player) != "human":
		await get_tree().create_timer(AI_STEP_DELAY * 0.6).timeout
		if token == _match_token and not mc.state.over:
			mc.end_turn()
	_ai_busy = false
	if token == _match_token:
		_maybe_ai_turn.call_deferred()  # IA contra IA, o turno siguiente


func _side_adj(owner: int) -> String:
	return "blanco" if owner == Piece.WHITE else "negro"
