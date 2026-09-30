extends SceneTree
## Tests headless de reglas: GDD §14 (criterios de aceptación) y §15.1 (pruebas funcionales).
## Ejecutar:  godot --headless --path . -s res://tests/test_rules.gd

var _fails := 0
var _passes := 0
var _log_dir := "user://test_logs"


func _init() -> void:
	_run_all()
	print("\n==== %d OK · %d FALLOS ====" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


func _run_all() -> void:
	for m in get_method_list():
		var name: String = m["name"]
		if name.begins_with("test_"):
			print("\n· ", name)
			call(name)


# --- helpers ---------------------------------------------------------------

func _new(mode: String = "P0") -> MatchController:
	var mc := MatchController.new(_log_dir, false)
	mc.new_match(mode)
	return mc


func _at(mc: MatchController, sq: String) -> Piece:
	return mc.state.board.piece_at(Board.parse_square(sq))


func _mv(mc: MatchController, from: String, to: String) -> Dictionary:
	return mc.activate(_at(mc, from), Board.parse_square(to))


## Estado vacío con piezas a medida: [["K","e1"], ["k","e8"], ...]
func _custom(mode: String, placements: Array) -> MatchController:
	var mc := _new(mode)
	var rows: PackedStringArray = []
	var grid := []
	for y in 8:
		grid.append(".".repeat(8))
	for pl in placements:
		var p := Board.parse_square(pl[1])
		var r := 7 - p.y
		var s: String = grid[r]
		grid[r] = s.substr(0, p.x) + pl[0] + s.substr(p.x + 1)
	for r in grid:
		rows.append(r)
	mc.rules.setup_rows = rows
	mc.state = GameState.create(mc.rules)
	TurnController.start_turn(mc.state)
	mc.logger.begin_match(mc.state)
	return mc


func _squares(moves: Array[Vector2i]) -> Array:
	var out := []
	for v in moves:
		out.append(Board.square_name(v))
	out.sort()
	return out


# --- §14.1 disposición inicial ----------------------------------------------

func test_initial_setup() -> void:
	var mc := _new()
	var expect := {
		"c1": ["rook", 0], "d1": ["knight", 0], "e1": ["king", 0], "f1": ["rook", 0],
		"c2": ["pawn", 0], "d2": ["pawn", 0], "e2": ["pawn", 0], "f2": ["pawn", 0],
		"c8": ["rook", 1], "d8": ["king", 1], "e8": ["knight", 1], "f8": ["rook", 1],
		"c7": ["pawn", 1], "d7": ["pawn", 1], "e7": ["pawn", 1], "f7": ["pawn", 1],
	}
	var ok := mc.state.board.all_pieces().size() == 16
	for sq in expect.keys():
		var p := _at(mc, sq)
		ok = ok and p != null and p.piece_type == expect[sq][0] and p.owner == expect[sq][1]
	check(ok, "disposición inicial exacta (16 piezas, §6.3)")
	check(mc.state.board.pieces_of(0).size() == 8 and mc.state.board.pieces_of(1).size() == 8, "8 piezas por jugador")
	check(mc.state.active_player == Piece.WHITE, "Blancas comienzan")
	check(mc.state.reserve == [0, 0], "Reserva inicial 0 para ambos")


# --- §14.2 / 14.3 / 14.9 turnos, PA y Reserva ----------------------------------

func test_turn_alternation_and_ap() -> void:
	var mc := _new()
	check(mc.state.ap_available == 6, "turno 1: 6 PA")
	mc.end_turn()
	check(mc.state.active_player == Piece.BLACK, "alterna a Negras")
	check(mc.state.ap_available == 6, "Negras empiezan con 6 PA (su Reserva es 0)")


func test_reserve_caps_at_two() -> void:
	var mc := _new()
	mc.end_turn()  # Blancas no gastan nada: guardan min(6,2) = 2
	check(mc.state.reserve[0] == 2, "Reserva limitada a 2 (6 sin gastar → 2)")
	mc.end_turn()  # Negras igual
	check(mc.state.ap_available == 8, "Blancas empiezan con 6 + 2 = 8 PA")
	check(mc.state.reserve[0] == 0, "Reserva vuelve a 0 al iniciar turno")
	_mv(mc, "c2", "c3")  # 1 PA → quedan 7
	mc.end_turn()
	check(mc.state.reserve[0] == 2, "con 7 restantes se reservan 2")


func test_reserve_partial() -> void:
	var mc := _new()
	_mv(mc, "c1", "c1") # ilegal (misma casilla), no gasta
	check(mc.state.ap_available == 6, "movimiento ilegal no consume PA")
	_mv(mc, "d1", "b2")  # caballo 2 → 4
	_mv(mc, "c2", "c3")  # peón 1 → 3
	_mv(mc, "d2", "d3")  # 1 → 2
	_mv(mc, "e2", "e3")  # 1 → 1
	check(mc.state.ap_available == 1, "costes 2+1+1+1 descontados (6→1)")
	check(mc.projected_reserve() == 1, "Reserva proyectada = 1")
	mc.end_turn()
	check(mc.state.reserve[0] == 1, "Reserva guardada = 1")


func test_costs() -> void:
	var mc := _new()
	var r := mc.rules
	check(r.cost_of("pawn") == 1 and r.cost_of("knight") == 2 and r.cost_of("rook") == 3 and r.cost_of("king") == 2,
		"costes 1/2/3/2 (§6.2)")
	_mv(mc, "c2", "c3")
	check(mc.state.ap_available == 5, "Peón cuesta 1")
	_mv(mc, "c1", "c2")
	check(mc.state.ap_available == 2, "Torre cuesta 3")
	_mv(mc, "e1", "d2") # d2 ocupado por propio peón → ilegal
	check(mc.state.ap_available == 2, "Rey no puede ir a casilla propia")
	var a := _mv(mc, "d1", "e3")
	check(not a.has("error") and mc.state.ap_available == 0, "Caballo cuesta 2 (queda 0)")
	var b := _mv(mc, "d2", "d3")
	check(b.get("error", "") == TurnController.ERR_NO_AP, "sin PA: activación rechazada")
	check(mc.state.ap_available >= 0, "PA nunca negativos")


# --- §14.4 una activación por pieza -------------------------------------------

func test_no_double_activation() -> void:
	var mc := _new()
	_mv(mc, "c2", "c3")
	var again := _mv(mc, "c3", "c4")
	check(again.get("error", "") == TurnController.ERR_EXHAUSTED, "pieza agotada no puede reactivarse")
	check(_at(mc, "c3") != null and _at(mc, "c4") == null, "la pieza sigue en c3")
	mc.end_turn()
	mc.end_turn()
	var next := _mv(mc, "c3", "c4")
	check(not next.has("error"), "en el turno siguiente vuelve a estar disponible")


# --- §14.6 movimientos --------------------------------------------------------

func test_pawn_moves() -> void:
	var mc := _custom("P0", [["K", "a1"], ["k", "h8"], ["P", "d4"], ["p", "c5"], ["p", "e5"], ["p", "d5"], ["P", "b2"]])
	var pawn := _at(mc, "d4")
	check(_squares(mc.legal_moves(pawn)) == ["c5", "e5"], "Peón bloqueado de frente; captura sólo en diagonal")
	check(_squares(mc.legal_moves(_at(mc, "b2"))) == ["b3"], "Peón sin avance doble")
	var bp := _at(mc, "d5")
	check(_squares(mc.legal_moves(bp)) == [], "Peón negro bloqueado por d4 y sin capturas")
	var mc2 := _custom("P0", [["K", "a1"], ["k", "h8"], ["P", "d7"], ["p", "c8"]])
	check(_squares(mc2.legal_moves(_at(mc2, "d7"))) == ["c8", "d8"], "Peón blanco en fila 7: avanza a d8 o captura c8")
	var mc3 := _custom("P0", [["K", "a1"], ["k", "h8"], ["P", "d8"]])
	check(_squares(mc3.legal_moves(_at(mc3, "d8"))) == [], "sin promoción: Peón en última fila queda sin movimientos")


func test_knight_jumps() -> void:
	var mc := _new()
	var n := _at(mc, "d1")
	check(_squares(mc.legal_moves(n)) == ["b2", "c3", "e3"], "Caballo d1 salta: b2, c3, e3 (f2 propio)")
	var a := _mv(mc, "d1", "c3")
	check(not a.has("error"), "Caballo salta por encima de la fila de peones")


func test_rook_blocked() -> void:
	var mc := _new()
	check(_squares(mc.legal_moves(_at(mc, "c1"))) == ["a1", "b1"], "Torre c1 no atraviesa c2 ni d1")
	var mc2 := _custom("P0", [["K", "a1"], ["k", "h8"], ["R", "d4"], ["P", "d6"], ["p", "f4"]])
	check(_squares(mc2.legal_moves(_at(mc2, "d4"))) == ["a4", "b4", "c4", "d1", "d2", "d3", "d5", "e4", "f4"],
		"Torre se detiene ante propia (d6) y captura enemiga (f4) sin pasarla")


func test_king_can_enter_threat() -> void:
	var mc := _custom("P0", [["K", "d4"], ["k", "d6"], ["r", "a5"]])
	var moves := _squares(mc.legal_moves(_at(mc, "d4")))
	check("d5" in moves and "c5" in moves, "Rey puede entrar en casilla amenazada y adyacente al Rey rival")
	check(moves.size() == 8, "Rey: 8 destinos en el centro")


# --- §14.7 / 14.8 captura y victoria -----------------------------------------

func test_capture() -> void:
	var mc := _custom("P0", [["K", "a1"], ["k", "h8"], ["N", "d4"], ["p", "e6"]])
	var a := _mv(mc, "d4", "e6")
	check(a["capture"] and a["captured"] == "pawn", "captura registrada")
	check(_at(mc, "e6").piece_type == "knight" and mc.state.board.pieces_of(1).size() == 1,
		"atacante ocupa la casilla, víctima retirada")


func test_king_capture_ends_immediately() -> void:
	var mc := _custom("P0", [["K", "a1"], ["k", "e8"], ["R", "e2"], ["P", "b2"]])
	var a := _mv(mc, "e2", "e8")
	check(a["capture"] and mc.state.over and mc.state.winner == Piece.WHITE, "capturar al Rey gana")
	check(mc.state.end_reason == VictorySystem.REASON_KING, "motivo: rey_capturado")
	var b := _mv(mc, "b2", "b3")
	check(b.get("error", "") == TurnController.ERR_OVER, "no se puede seguir jugando tras la victoria")
	check(not mc.end_turn(), "no se puede terminar turno tras la victoria")


# --- §14.10 terminar turno voluntariamente -------------------------------------

func test_voluntary_end() -> void:
	var mc := _new()
	_mv(mc, "c2", "c3")
	check(mc.can_end_turn() and mc.end_turn(), "P0: se puede terminar con PA sobrantes")
	check(mc.state.active_player == Piece.BLACK, "turno pasa a Negras")


# --- C0 ------------------------------------------------------------------------

func test_c0_single_activation() -> void:
	var mc := _new("C0")
	check(not mc.rules.uses_ap() and mc.state.ap_available == 0, "C0: sin PA")
	check(not mc.can_end_turn(), "C0: no se puede pasar si hay activación posible")
	check(TurnController.can_activate(mc.state, _at(mc, "c1")) == true, "C0: la Torre activable sin coste")
	var a := _mv(mc, "c1", "a1")
	check(not a.has("error") and a["cost"] == null, "C0: acción sin coste")
	check(mc.state.active_player == Piece.BLACK, "C0: el turno termina solo tras una activación")
	check(mc.state.reserve == [0, 0], "C0: nunca hay Reserva")


# --- Log ---------------------------------------------------------------------

func test_log_written() -> void:
	var mc := MatchController.new(_log_dir, true)
	mc.new_match("P0")
	_mv(mc, "d1", "c3")
	_mv(mc, "c2", "c3") # ilegal: ocupado por el caballo
	_mv(mc, "e2", "e3")
	mc.end_turn()
	_mv(mc, "e8", "d6")
	mc.end_turn()
	mc.declare_draw("prueba")
	var path := mc.logger.last_saved_path
	check(path != "" and FileAccess.file_exists(path), "log guardado en %s" % path)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data["mode"] == "P0" and data["first_player"] == "white" and data["end_reason"] == "empate_experimental",
		"log: modo, jugador inicial, motivo")
	var t0: Dictionary = data["turns"][0]
	check(int(t0["ap_start"]) == 6 and int(t0["ap_spent"]) == 3 and int(t0["ap_reserved"]) == 2 and int(t0["ap_lost"]) == 1,
		"log turno 1: 6 iniciales, 3 gastados, 2 reservados, 1 perdido")
	check(t0["sequence"] == ["knight", "pawn"], "log turno 1: secuencia de tipos")
	var a0: Dictionary = t0["actions"][0]
	check(a0["from"] == "d1" and a0["to"] == "c3" and int(a0["cost"]) == 2 and a0["capture"] == false,
		"log acción: pieza, coste, origen, destino, captura")
	check(int(data["turns"][1]["ap_start"]) == 6, "Negras empiezan con 6")
	check(int(data["duration"]["player_turns"]) == 3, "duración en turnos de jugador")
	DirAccess.remove_absolute(path)


# --- Fuzz: invariantes en partidas aleatorias -----------------------------------

func test_random_playouts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var ok := true
	var finished := 0
	for mode in ["P0", "C0"]:
		for g in 150:
			var mc := _new(mode)
			var steps := 0
			while not mc.state.over and steps < 2000:
				steps += 1
				var candidates: Array[Piece] = []
				for p in mc.state.board.pieces_of(mc.state.active_player):
					if TurnController.can_activate(mc.state, p):
						candidates.append(p)
				if candidates.is_empty() or (mode == "P0" and rng.randf() < 0.2):
					if not mc.end_turn():
						ok = false
						break
					continue
				var p: Piece = candidates[rng.randi() % candidates.size()]
				var moves := mc.legal_moves(p)
				var before := mc.state.ap_available
				var a := mc.activate(p, moves[rng.randi() % moves.size()])
				if a.has("error"):
					ok = false
				if mode == "P0" and not mc.state.over:
					if mc.state.ap_available < 0 or before - mc.state.ap_available != p.activation_cost:
						ok = false
				if mc.state.reserve[0] > 2 or mc.state.reserve[1] > 2:
					ok = false
				if mode == "P0" and p.activations_this_turn > 1:
					ok = false
			if mc.state.over:
				finished += 1
				var kings := 0
				for q in mc.state.board.all_pieces():
					if q.piece_type == "king":
						kings += 1
				if mc.state.end_reason == VictorySystem.REASON_KING and kings != 1:
					ok = false
				if mc.state.end_reason not in [VictorySystem.REASON_KING, VictorySystem.REASON_REPETITION, VictorySystem.REASON_NO_PROGRESS]:
					ok = false
	check(ok, "300 partidas aleatorias sin violar invariantes (PA≥0, Reserva≤2, 1 activación/pieza)")
	check(finished == 300, "todas terminan (Rey capturado o tablas automáticas) (%d/300)" % finished)


# --- Tablas automáticas y regla sin jugadas (Anexo A · A.2.2, A.2.3) ---------------

func test_repetition_draw() -> void:
	var mc := _custom("P0", [["K", "a1"], ["N", "b1"], ["k", "h8"], ["n", "g8"]])
	var cycle := [["b1", "c3"], ["g8", "f6"], ["c3", "b1"], ["f6", "g8"]]
	var i := 0
	while not mc.state.over and i < 40:
		var step: Array = cycle[i % 4]
		_mv(mc, step[0], step[1])
		mc.end_turn()
		i += 1
	check(mc.state.over and mc.state.end_reason == VictorySystem.REASON_REPETITION, "repetición triple → tablas")
	# Sin PA/Reserva en la clave, T1 = T5 = T9 → tablas en T9. Con ellas, T1 (6 PA) es distinta
	# y la primera triple es T3 = T7 = T11.
	check(mc.state.player_turn == 11, "la clave de posición incluye PA y Reserva (tablas en T11, no en T9)")
	check(mc.state.winner == -1 and VictorySystem.is_draw(mc.state), "sin ganador")


func test_no_progress_draw() -> void:
	var mc := _custom("P0", [["K", "a1"], ["P", "c2"], ["k", "h8"], ["p", "f7"]])
	mc.rules.repetition_limit = 0
	mc.rules.no_progress_turns = 4
	_mv(mc, "a1", "b1")
	mc.end_turn()          # 1 sin progreso
	_mv(mc, "h8", "g8")
	mc.end_turn()          # 2
	_mv(mc, "c2", "c3")    # peón: progreso → contador a 0
	mc.end_turn()
	check(mc.state.turns_without_progress == 0, "mover un peón reinicia el contador")
	for k in 4:
		mc.end_turn()      # pasar sin activar
	check(mc.state.over and mc.state.end_reason == VictorySystem.REASON_NO_PROGRESS, "N turnos sin progreso → tablas")


func test_no_moves_rule() -> void:
	# Blancas sin ninguna jugada legal: Rey en a8 rodeado de peones propios y peón en última fila.
	var placements := [["K", "a8"], ["P", "b8"], ["P", "a7"], ["P", "b7"], ["k", "h1"]]
	for flag in [false, true]:
		var mc := _new("P0")
		var grid := []
		for y in 8:
			grid.append(".".repeat(8))
		for pl in placements:
			var p := Board.parse_square(pl[1])
			var r := 7 - p.y
			var row: String = grid[r]
			grid[r] = row.substr(0, p.x) + pl[0] + row.substr(p.x + 1)
		mc.rules.setup_rows = PackedStringArray(grid)
		mc.rules.no_moves_loses = flag
		mc.state = GameState.create(mc.rules)
		TurnController.start_turn(mc.state)
		if flag:
			check(mc.state.over and mc.state.winner == Piece.BLACK and mc.state.end_reason == VictorySystem.REASON_NO_MOVES,
				"no_moves_loses=true: sin jugadas legales pierde")
		else:
			check(not mc.state.over and mc.can_end_turn(), "no_moves_loses=false: sólo pasa turno")


func test_end_rules_from_config() -> void:
	var mc := _new("P0")
	check(mc.rules.repetition_limit == 3 and mc.rules.no_progress_turns == 30 and mc.rules.no_moves_loses == false,
		"valores de end_rules leídos del JSON")


# --- Analizador de logs ------------------------------------------------------------

func test_replay_order_dependency() -> void:
	var mc := MatchController.new(_log_dir, false)
	mc.new_match("P0")
	_mv(mc, "c2", "c3")   # libera c2…
	_mv(mc, "c1", "c2")   # …y la Torre sólo puede ir a c2 gracias a lo anterior
	mc.end_turn()
	_mv(mc, "e7", "e6")
	_mv(mc, "d7", "d6")   # independientes
	mc.end_turn()
	mc.logger.record_turn(TurnController.turn_summary(mc.state, "fin_partida"))
	var r := LogAnalyzer.replay_order_dependency(mc.logger.data)
	check(r["ok"], "la partida se reproduce desde el log")
	check(r["deps"][0] == 1 and r["deps"][1] == 0, "detecta la activación habilitada por otra anterior (1) y la independiente (0)")
	var t0: Dictionary = mc.logger.data["turns"][0]
	check(t0.has("activatable_left") and int(t0["activatable_left"]) > 0, "log: piezas aún activables al terminar (ahorro deliberado)")
	check(mc.logger.data.has("rules"), "log: incluye las reglas completas")


func test_analyzer_report() -> void:
	var dir := "user://test_analyzer"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var played := {"P0": 0, "C0": 0}
	for mode in ["P0", "P0", "P0", "P0", "C0", "C0", "C0"]:
		var mc := MatchController.new(dir, true)
		mc.new_match(mode)
		var guard := 0
		while not mc.state.over and guard < 3000:
			guard += 1
			var cands: Array[Piece] = []
			for p in mc.state.board.pieces_of(mc.state.active_player):
				if TurnController.can_activate(mc.state, p):
					cands.append(p)
			if cands.is_empty() or (mode == "P0" and rng.randf() < 0.3):
				mc.end_turn()
				continue
			var p: Piece = cands[rng.randi() % cands.size()]
			var moves := mc.legal_moves(p)
			mc.activate(p, moves[rng.randi() % moves.size()])
		played[mode] += 1
		OS.delay_msec(5)
	var logs := LogAnalyzer.load_logs(dir)
	var res := LogAnalyzer.analyze(logs)
	check(logs.size() == 7, "7 logs escritos y leídos")
	check(res["modes"]["P0"]["games"] == 4 and res["modes"]["C0"]["games"] == 3, "partidas agrupadas por modo")
	check(res["modes"]["P0"]["replay_failed"] == 0 and res["modes"]["C0"]["replay_failed"] == 0, "todas las partidas se reproducen")
	var p0: Dictionary = res["modes"]["P0"]
	var hist_total := 0
	for k in p0["reserve_hist"].keys():
		hist_total += int(p0["reserve_hist"][k])
	check(hist_total == p0["closed_turns"] and p0["closed_turns"] > 0, "histograma de Reserva cuadra con los turnos cerrados")
	check(not p0["reserve_hist"].has("3"), "ninguna Reserva por encima de 2")
	var path := LogAnalyzer.write_report(dir)
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("## 1. Comparativa entre modos") and text.contains("P0 · indicios para el criterio de avance"),
		"informe Markdown generado con comparativa e indicios")
	print(text)
