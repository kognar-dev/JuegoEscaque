class_name LogAnalyzer
extends RefCounted
## Lee los logs JSON de partidas y genera un informe comparativo C0 / P0 en Markdown,
## orientado a las pruebas de diseño (GDD §15.2) y al criterio de avance (§18).
## Los umbrales producen INDICIOS, no veredictos: la muestra suele ser pequeña.

const REPORT_NAME := "informe_escaque.md"
const MIN_GAMES := 3                 ## por debajo: «muestra insuficiente»
const T_ALL_SPENT := 0.85            ## gastar todo en ≥85 % de turnos → posible pauta dominante
const T_RESERVE_MAX := 0.75          ## reservar el máximo en ≥75 % de turnos → riesgo §9.1
const T_TOP_COMPOSITION := 0.40      ## una composición en ≥40 % de turnos → riesgo §9.2
const T_ORDER_DEP := 0.15            ## ≥15 % de turnos múltiples con dependencia de orden → H-P0-3
const T_FIRST_PLAYER := 0.70         ## el primer jugador gana ≥70 % → riesgo §9.4


# --- carga ---------------------------------------------------------------------

static func load_logs(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if parsed is Dictionary and String(parsed.get("schema", "")).begins_with("escaque-log"):
			parsed["_file"] = f
			out.append(parsed)
	return out


# --- análisis ------------------------------------------------------------------

static func analyze(logs: Array[Dictionary]) -> Dictionary:
	var modes := {}
	var abandoned := 0
	for log in logs:
		if log.get("end_reason") == VictorySystem.REASON_ABANDONED or log.get("end_reason") == null:
			abandoned += 1
			continue
		var mode := String(log.get("mode", "?"))
		if not modes.has(mode):
			modes[mode] = _empty_stats(mode, String(log.get("config", {}).get("economy", "ap")))
		_add_game(modes[mode], log)
	return {"modes": modes, "files": logs.size(), "abandoned": abandoned}


static func _empty_stats(mode: String, economy: String) -> Dictionary:
	return {
		"mode": mode, "uses_ap": economy == RulesConfig.ECONOMY_AP,
		"games": 0, "wins_first": 0, "wins_second": 0, "draws": 0, "reasons": {},
		"durations": [],
		"turns": 0, "captures": 0, "activations_total": 0,
		"activations_hist": {"0": 0, "1": 0, "2": 0, "3": 0, "4+": 0},
		"closed_turns": 0, "ap_spent_total": 0, "ap_lost_total": 0,
		"reserve_hist": {}, "max_reserve": 0,
		"all_spent": 0, "saved_turns": 0, "deliberate_save": 0,
		"compositions": {}, "type_freq": {},
		"multi_turns": 0, "order_dependent_turns": 0, "order_dependent_actions": 0,
		"replay_failed": 0,
	}


static func _add_game(st: Dictionary, log: Dictionary) -> void:
	st["games"] += 1
	var reason := String(log.get("end_reason", ""))
	st["reasons"][reason] = int(st["reasons"].get(reason, 0)) + 1
	if log.get("winner") == null:
		st["draws"] += 1
	elif log.get("winner") == log.get("first_player"):
		st["wins_first"] += 1
	else:
		st["wins_second"] += 1
	st["durations"].append(int(log.get("duration", {}).get("player_turns", 0)))
	var cfg: Dictionary = log.get("config", {})
	if cfg.get("max_reserve") != null:
		st["max_reserve"] = int(cfg["max_reserve"])

	var replay := replay_order_dependency(log)
	if not replay["ok"]:
		st["replay_failed"] += 1

	var turns: Array = log.get("turns", [])
	for i in turns.size():
		var t: Dictionary = turns[i]
		var n := int(t.get("activations", 0))
		st["turns"] += 1
		st["activations_total"] += n
		var bucket := "4+" if n >= 4 else str(n)
		st["activations_hist"][bucket] += 1
		for a in t.get("actions", []):
			if a.get("capture", false):
				st["captures"] += 1
		var seq: Array = t.get("sequence", []).duplicate()
		for typ in seq:
			st["type_freq"][typ] = int(st["type_freq"].get(typ, 0)) + 1
		seq.sort()
		var comp := "+".join(PackedStringArray(seq)) if seq.size() > 0 else "(pasa)"
		st["compositions"][comp] = int(st["compositions"].get(comp, 0)) + 1

		if n >= 2:
			st["multi_turns"] += 1
			if replay["ok"]:
				var dep: int = replay["deps"][i]
				if dep > 0:
					st["order_dependent_turns"] += 1
					st["order_dependent_actions"] += dep

		if st["uses_ap"] and t.get("ended_by") != "fin_partida" and t.get("ap_left") != null:
			st["closed_turns"] += 1
			st["ap_spent_total"] += int(t.get("ap_spent", 0))
			st["ap_lost_total"] += int(t.get("ap_lost", 0))
			var r := str(int(t.get("ap_reserved", 0)))
			st["reserve_hist"][r] = int(st["reserve_hist"].get(r, 0)) + 1
			if int(t["ap_left"]) == 0:
				st["all_spent"] += 1
			else:
				st["saved_turns"] += 1
				var left = t.get("activatable_left")
				if left != null and int(left) > 0:
					st["deliberate_save"] += 1


## Reproduce la partida y, para cada turno, cuenta las activaciones cuyo destino NO era
## legal al empezar el turno: sólo fueron posibles por una activación anterior del mismo
## turno (el rival no mueve entre medias). Mide directamente H-P0-3 · Secuenciación.
static func replay_order_dependency(log: Dictionary) -> Dictionary:
	var raw = log.get("rules")
	if not (raw is Dictionary) or not raw.get("modes", {}).has(log.get("mode", "")):
		return {"ok": false, "deps": []}
	var rules := RulesConfig.from_dict(raw, String(log["mode"]))
	var setup = log.get("config", {}).get("setup")
	if setup is Array:
		rules.setup_rows = PackedStringArray(setup)
	var s := GameState.create(rules)
	var deps: Array[int] = []
	for t in log.get("turns", []):
		var start_legal := {}
		for p in s.board.all_pieces():
			var names := {}
			for m in MoveGenerator.legal_moves(s.board, p, rules):
				names[Board.square_name(m)] = true
			start_legal[p.id] = names
		var dep := 0
		var actions: Array = t.get("actions", [])
		for i in actions.size():
			var a: Dictionary = actions[i]
			var piece := s.board.piece_at(Board.parse_square(a["from"]))
			if piece == null or piece.id != int(a["piece_id"]):
				return {"ok": false, "deps": deps}
			var target := s.board.piece_at(Board.parse_square(a["to"]))
			if target and target.owner == piece.owner:
				return {"ok": false, "deps": deps}
			if i > 0 and not start_legal.get(piece.id, {}).has(a["to"]):
				dep += 1
			s.board.move(piece, Board.parse_square(a["to"]))
		deps.append(dep)
	return {"ok": true, "deps": deps}


# --- informe -------------------------------------------------------------------

static func build_report(result: Dictionary, source: String = "") -> String:
	var L: PackedStringArray = []
	var modes: Dictionary = result["modes"]
	var ids: Array = modes.keys()
	ids.sort_custom(func(a, b): return _mode_rank(a) < _mode_rank(b))

	L.append("# ESCAQUE · Informe de partidas")
	L.append("")
	L.append("Generado: %s  " % Time.get_datetime_string_from_system().replace("T", " "))
	if source != "":
		L.append("Carpeta: `%s`  " % source)
	var counts: PackedStringArray = []
	for m in ids:
		counts.append("%s: %d" % [m, modes[m]["games"]])
	L.append("Logs leídos: %d (%s). Partidas abandonadas excluidas: %d." % [
		result["files"], ", ".join(counts) if counts.size() > 0 else "ninguna terminada", result["abandoned"]])
	L.append("")
	L.append("> Los indicios son heurísticos y dependen del tamaño de la muestra. Con menos de %d partidas por modo se marcan como «muestra insuficiente»." % MIN_GAMES)
	L.append("")
	if ids.is_empty():
		L.append("No hay partidas terminadas que analizar.")
		return "\n".join(L)

	# Comparativa
	L.append("## 1. Comparativa entre modos")
	L.append("")
	L.append("| Métrica | " + " | ".join(PackedStringArray(ids)) + " |")
	L.append("|---|" + "---:|".repeat(ids.size()))
	L.append(_row("Partidas", ids, modes, func(s): return str(s["games"])))
	L.append(_row("Gana el primer jugador", ids, modes, func(s): return _pct_of(s["wins_first"], s["games"])))
	L.append(_row("Gana el segundo jugador", ids, modes, func(s): return _pct_of(s["wins_second"], s["games"])))
	L.append(_row("Tablas / empates", ids, modes, func(s): return _pct_of(s["draws"], s["games"])))
	L.append(_row("Duración media (turnos de jugador)", ids, modes, func(s): return _duration(s["durations"])))
	L.append(_row("Activaciones por turno (media)", ids, modes, func(s): return _ratio(s["activations_total"], s["turns"])))
	L.append(_row("Capturas por turno (media)", ids, modes, func(s): return _ratio(s["captures"], s["turns"])))
	L.append(_row("Motivos de final", ids, modes, func(s): return _reasons(s["reasons"])))
	L.append("")

	var section := 2
	for m in ids:
		var st: Dictionary = modes[m]
		if not st["uses_ap"]:
			continue
		L.append_array(_ap_section(section, st))
		section += 1
		L.append_array(_criteria_section(section, st))
		section += 1

	L.append("## %d. Lo que el log no mide" % section)
	L.append("")
	L.append("El §18 también pide que el jugador pueda **explicar por qué tomó una secuencia concreta**. Eso sólo sale de las notas tomadas tras cada partida.")
	L.append("")
	return "\n".join(L)


static func _ap_section(n: int, st: Dictionary) -> PackedStringArray:
	var L: PackedStringArray = []
	var closed: int = st["closed_turns"]
	L.append("## %d. %s · economía de PA" % [n, st["mode"]])
	L.append("")
	L.append("Turnos analizados: %d (%d cerrados con Fin de turno)." % [st["turns"], closed])
	L.append("")
	L.append("**Reserva al terminar el turno**")
	L.append("")
	L.append("| PA reservados | Turnos | % |")
	L.append("|---:|---:|---:|")
	var keys: Array = st["reserve_hist"].keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		L.append("| %s | %d | %s |" % [k, st["reserve_hist"][k], _pct(_frac(st["reserve_hist"][k], closed))])
	L.append("")
	L.append("- Turnos que gastan todos los PA: %s" % _pct_of(st["all_spent"], closed))
	L.append("- Turnos que guardan PA pudiendo activar alguna pieza (**ahorro deliberado**): %s" % _pct_of(st["deliberate_save"], closed))
	L.append("- PA gastados por turno (media): %s · PA perdidos por turno (media): %s" % [
		_ratio(st["ap_spent_total"], closed), _ratio(st["ap_lost_total"], closed)])
	L.append("")
	L.append("**Activaciones por turno (concentración vs. dispersión)**")
	L.append("")
	L.append("| 0 | 1 | 2 | 3 | 4+ |")
	L.append("|---:|---:|---:|---:|---:|")
	var h: Dictionary = st["activations_hist"]
	L.append("| %s | %s | %s | %s | %s |" % [_pct_of(h["0"], st["turns"]), _pct_of(h["1"], st["turns"]),
		_pct_of(h["2"], st["turns"]), _pct_of(h["3"], st["turns"]), _pct_of(h["4+"], st["turns"])])
	L.append("")
	L.append("**Composiciones de turno más frecuentes** (tipos activados, sin orden)")
	L.append("")
	L.append("| Composición | Turnos | % |")
	L.append("|---|---:|---:|")
	for pair in _top(st["compositions"], 6):
		L.append("| %s | %d | %s |" % [_pretty_comp(pair[0]), pair[1], _pct(_frac(pair[1], st["turns"]))])
	L.append("")
	L.append("**Dependencia de orden (H-P0-3)**")
	L.append("")
	L.append("- Turnos con 2 o más activaciones: %d" % st["multi_turns"])
	L.append("- De ellos, con al menos una activación que sólo era legal gracias a otra anterior del mismo turno: %s; %d activaciones en total" % [
		_pct_of(st["order_dependent_turns"], st["multi_turns"]), st["order_dependent_actions"]])
	if st["replay_failed"] > 0:
		L.append("- Aviso: %d partidas no se pudieron reproducir (logs antiguos o reglas cambiadas) y no cuentan aquí." % st["replay_failed"])
	L.append("")
	return L


static func _criteria_section(n: int, st: Dictionary) -> PackedStringArray:
	var L: PackedStringArray = []
	var enough: bool = st["games"] >= MIN_GAMES
	var closed: int = st["closed_turns"]
	var max_r := str(st["max_reserve"])
	var all_spent := _frac(st["all_spent"], closed)
	var res_max := _frac(int(st["reserve_hist"].get(max_r, 0)), closed)
	var top := _top(st["compositions"], 1)
	var top_share := _frac(top[0][1], st["turns"]) if top.size() > 0 else 0.0
	var dep := _frac(st["order_dependent_turns"], st["multi_turns"])
	var first := _frac(st["wins_first"], st["games"])

	L.append("## %d. %s · indicios para el criterio de avance (§18)" % [n, st["mode"]])
	L.append("")
	L.append("| Criterio | Valor | Indicio |")
	L.append("|---|---:|---|")
	L.append("| Gastar todos los PA no es siempre dominante | %s de turnos | %s |" % [
		_pct(all_spent), _verdict(enough, all_spent < T_ALL_SPENT, "posible pauta dominante")])
	L.append("| Reservar el máximo (%s) no es siempre dominante (§9.1) | %s de turnos | %s |" % [
		max_r, _pct(res_max), _verdict(enough, res_max < T_RESERVE_MAX, "posible «burst» dominante")])
	L.append("| Hay ahorro deliberado de PA (§15.2) | %d turnos | %s |" % [
		st["deliberate_save"], _verdict(enough, st["deliberate_save"] > 0, "no aparece")])
	L.append("| Ninguna composición domina (§9.2) | la más usada: %s | %s |" % [
		_pct(top_share), _verdict(enough, top_share < T_TOP_COMPOSITION, "composición dominante")])
	L.append("| El orden de activación importa (H-P0-3) | %s de turnos múltiples | %s |" % [
		_pct(dep), _verdict(enough and st["multi_turns"] > 0, dep >= T_ORDER_DEP, "el orden apenas influye")])
	L.append("| Sin ventaja excesiva del primer jugador (§9.4) | gana %s | %s |" % [
		_pct(first), _verdict(enough, first < T_FIRST_PLAYER, "ventaja del primer jugador")])
	L.append("")
	return L


# --- utilidades ------------------------------------------------------------------

static func write_report(log_dir: String, out_path: String = "") -> String:
	var result := analyze(load_logs(log_dir))
	var text := build_report(result, ProjectSettings.globalize_path(log_dir))
	if out_path == "":
		out_path = log_dir.path_join(REPORT_NAME)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir %s" % out_path)
		return ""
	f.store_string(text)
	f.close()
	return out_path


## Orden de columnas: C0 (control), P0, y después el resto alfabéticamente.
static func _mode_rank(m: String) -> String:
	return {"C0": "0", "P0": "1"}.get(m, "2" + m)


static func _row(label: String, ids: Array, modes: Dictionary, fn: Callable) -> String:
	var cells: PackedStringArray = []
	for m in ids:
		cells.append(str(fn.call(modes[m])))
	return "| %s | %s |" % [label, " | ".join(cells)]


static func _frac(a: int, b: int) -> float:
	return float(a) / b if b > 0 else 0.0


static func _pct(x: float) -> String:
	return "%d %%" % roundi(x * 100.0)


static func _pct_of(a: int, b: int) -> String:
	return "—" if b <= 0 else "%d (%s)" % [a, _pct(_frac(a, b))]


static func _ratio(a: int, b: int) -> String:
	return "—" if b <= 0 else "%.2f" % (float(a) / b)


static func _duration(d: Array) -> String:
	if d.is_empty():
		return "—"
	var total := 0
	for x in d:
		total += int(x)
	return "%.1f (%d–%d)" % [float(total) / d.size(), d.min(), d.max()]


static func _reasons(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in r.keys():
		parts.append("%s ×%d" % [k, r[k]])
	return ", ".join(parts)


static func _top(counts: Dictionary, n: int) -> Array:
	var pairs := []
	for k in counts.keys():
		pairs.append([k, int(counts[k])])
	pairs.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return pairs.slice(0, n)


static func _pretty_comp(comp: String) -> String:
	const NAMES := {"pawn": "Peón", "knight": "Caballo", "rook": "Torre", "king": "Rey"}
	if comp == "(pasa)":
		return "(sin activaciones)"
	var parts: PackedStringArray = []
	for t in comp.split("+"):
		parts.append(NAMES.get(t, t))
	return " + ".join(parts)


static func _verdict(enough: bool, good: bool, bad_label: String) -> String:
	if not enough:
		return "muestra insuficiente"
	return "favorable" if good else "**alerta: %s**" % bad_label
