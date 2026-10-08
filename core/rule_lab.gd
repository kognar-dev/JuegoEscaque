class_name RuleLab
extends RefCounted
## Laboratorio de reglas: juega partidas IA contra IA con variantes de reglas y compara
## resultados. No mide el equilibrio fino (la IA no es un jugador experto), sino cómo
## cambian la dinámica y los finales al combinar reglas: tablas, duración, ventaja del
## primer jugador, uso de la Reserva, dependencia de orden…
##
## Una variante = un modo base + cambios por ruta, p. ej.:
##   {"id": "P0_promo", "mode": "P0", "set": {"rule_options.promotion": "rook"}}
##   {"id": "P0_ap5",   "mode": "P0", "set": {"modes.P0.base_ap": 5, "pieces.rook.cost": 4}}

const AI := preload("res://core/ai_player.gd")
const ANALYZER := preload("res://core/log_analyzer.gd")

const DEFAULT_EXPERIMENTS := "res://data/lab_experiments.json"


## Asigna `value` en `data` siguiendo una ruta con puntos («modes.P0.base_ap»).
static func set_path(data: Dictionary, path: String, value) -> void:
	var keys := path.split(".")
	var d: Dictionary = data
	for i in keys.size() - 1:
		if not d.has(keys[i]) or not (d[keys[i]] is Dictionary):
			d[keys[i]] = {}
		d = d[keys[i]]
	d[keys[keys.size() - 1]] = value


static func build_rules(base: Dictionary, variant: Dictionary) -> RulesConfig:
	var data := base.duplicate(true)
	var changes: Dictionary = variant.get("set", {})
	for k in changes.keys():
		set_path(data, k, changes[k])
	return RulesConfig.from_dict(data, String(variant.get("mode", "P0")))


## Juega una partida completa IA contra IA. Devuelve el log (Dictionary).
static func play_game(rules: RulesConfig, white, black, log_dir: String, max_turns: int) -> Dictionary:
	var mc := MatchController.new(log_dir, log_dir != "")
	mc.new_match_with_rules(rules)
	var players := [white, black]
	while not mc.state.over:
		if mc.state.player_turn > max_turns:
			mc.declare_draw("límite de %d turnos del laboratorio" % max_turns)
			break
		var plan: Array[Dictionary] = players[mc.state.active_player].plan_turn(mc.state)
		for step in plan:
			var res := mc.activate(mc.state.board.get_piece(step["piece_id"]), step["to"])
			if res.has("error"):
				push_error("La IA propuso una activación ilegal: %s" % res["error"])
				break
			if mc.state.over or not mc.rules.uses_ap():
				break  # en C0 el turno pasa solo tras activar
		if mc.state.over:
			break
		if mc.rules.uses_ap() or plan.is_empty():
			mc.end_turn()
	return mc.logger.data


## Ejecuta todos los experimentos. Devuelve la ruta del informe.
static func run(experiments_path: String = DEFAULT_EXPERIMENTS, out_root: String = "user://lab",
		games_override: int = -1, progress: Callable = Callable()) -> String:
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(experiments_path))
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(exp.get("rules", RulesConfig.DEFAULT_PATH))))
	var games: int = games_override if games_override > 0 else int(exp.get("games_per_variant", 30))
	var level: String = String(exp.get("ai_level", "normal"))
	var max_turns: int = int(exp.get("max_player_turns", 200))
	var seed0: int = int(exp.get("seed", 1))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	var run_dir := out_root.path_join("lab_" + stamp)
	var results: Array = []
	for v in exp.get("variants", []):
		var vid := String(v["id"])
		var vdir := run_dir.path_join(vid)
		DirAccess.make_dir_recursive_absolute(vdir)
		var rules := build_rules(base, v)
		var t0 := Time.get_ticks_msec()
		for g in games:
			var seed := seed0 + g * 2
			play_game(rules, AI.new(level, seed), AI.new(level, seed + 1), vdir, max_turns)
			if progress.is_valid():
				progress.call(vid, g + 1, games)
		var res: Dictionary = ANALYZER.analyze(ANALYZER.load_logs(vdir))
		results.append({"variant": v, "stats": res["modes"].get(rules.mode_id, {}),
			"ms_per_game": float(Time.get_ticks_msec() - t0) / games})
	var report := build_report(results, games, level, experiments_path)
	var path := run_dir.path_join("informe_laboratorio.md")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(report)
	f.close()
	return path


static func build_report(results: Array, games: int, level: String, source: String) -> String:
	var L: PackedStringArray = []
	L.append("# ESCAQUE · Laboratorio de reglas")
	L.append("")
	L.append("Generado: %s · %d partidas por variante · IA «%s» contra sí misma · experimentos: `%s`" % [
		Time.get_datetime_string_from_system().replace("T", " "), games, level, source])
	L.append("")
	L.append("> IA contra IA: mide cómo cambian la dinámica y los finales entre variantes, no el equilibrio entre jugadores expertos.")
	L.append("")
	L.append("## Resultados")
	L.append("")
	L.append("| Variante | Decisivas | Gana 1.º | Gana 2.º | Tablas (rep / sin progreso / otras) | Turnos (media) | Activ./turno | Reserva máx. | Gasta todo | Orden importa |")
	L.append("|---|---:|---:|---:|---|---:|---:|---:|---:|---:|")
	for r in results:
		var s: Dictionary = r["stats"]
		if s.is_empty():
			L.append("| %s | — |" % r["variant"]["id"])
			continue
		var n: int = s["games"]
		var reasons: Dictionary = s["reasons"]
		var rep := int(reasons.get(VictorySystem.REASON_REPETITION, 0))
		var np := int(reasons.get(VictorySystem.REASON_NO_PROGRESS, 0))
		var other := int(s["draws"]) - rep - np
		var closed: int = s["closed_turns"]
		var max_r := str(s["max_reserve"])
		L.append("| %s | %s | %s | %s | %s / %s / %s | %s | %s | %s | %s | %s |" % [
			r["variant"]["id"],
			_pct(n - int(s["draws"]), n), _pct(s["wins_first"], n), _pct(s["wins_second"], n),
			_pct(rep, n), _pct(np, n), _pct(other, n),
			_avg(s["durations"]),
			"%.2f" % (float(s["activations_total"]) / maxi(1, s["turns"])),
			_pct(int(s["reserve_hist"].get(max_r, 0)), closed) if s["uses_ap"] else "—",
			_pct(s["all_spent"], closed) if s["uses_ap"] else "—",
			_pct(s["order_dependent_turns"], s["multi_turns"]) if s["multi_turns"] > 0 else "—",
		])
	L.append("")
	L.append("## Motivos de final por variante")
	L.append("")
	for r in results:
		var s: Dictionary = r["stats"]
		var parts: PackedStringArray = []
		for k in s.get("reasons", {}).keys():
			parts.append("%s ×%d" % [k, s["reasons"][k]])
		L.append("- **%s** — %s. %s(%.0f ms/partida)" % [r["variant"]["id"], ", ".join(parts),
			(String(r["variant"].get("note", "")) + " ") if r["variant"].has("note") else "", r["ms_per_game"]])
	L.append("")
	L.append("## Definición de las variantes")
	L.append("")
	for r in results:
		L.append("- **%s**: modo %s; cambios `%s`" % [r["variant"]["id"], r["variant"].get("mode", "P0"),
			JSON.stringify(r["variant"].get("set", {}))])
	L.append("")
	return "\n".join(L)


static func _pct(a: int, b: int) -> String:
	return "—" if b <= 0 else "%d %%" % roundi(100.0 * a / b)


static func _avg(d: Array) -> String:
	if d.is_empty():
		return "—"
	var t := 0
	for x in d:
		t += int(x)
	return "%.1f" % (float(t) / d.size())
