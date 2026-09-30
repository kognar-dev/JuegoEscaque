class_name MatchLogger
extends RefCounted
## Telemetría mínima (GDD §13.7) en JSON: partida, turnos y acciones.
## Añade un resumen por jugador para las pruebas de diseño (§15.2).

const SCHEMA := "escaque-log/1"

var log_dir: String
var enabled: bool = true
var data: Dictionary = {}
var last_saved_path: String = ""


func _init(p_log_dir: String = "user://logs", p_enabled: bool = true) -> void:
	log_dir = p_log_dir
	enabled = p_enabled


func begin_match(s: GameState) -> void:
	last_saved_path = ""
	data = {
		"schema": SCHEMA,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		"mode": s.rules.mode_id,
		"config": s.rules.to_log_dict(),
		"rules": s.rules.raw,
		"started_at": Time.get_datetime_string_from_system(),
		"ended_at": null,
		"first_player": Piece.owner_key(s.rules.first_player),
		"winner": null,
		"end_reason": null,
		"draw_cause": null,
		"duration": {"player_turns": 0, "rounds": 0},
		"turns": [],
		"summary": {},
	}


func record_turn(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	data["turns"].append(summary)


## Cierra el log y lo guarda. Devuelve la ruta (o "" si está desactivado / vacío).
func end_match(s: GameState) -> String:
	data["ended_at"] = Time.get_datetime_string_from_system()
	data["winner"] = Piece.owner_key(s.winner) if s.winner >= 0 else null
	data["first_player_won"] = (s.winner == s.rules.first_player) if s.winner >= 0 else null
	data["end_reason"] = s.end_reason
	data["draw_cause"] = s.draw_cause if s.draw_cause != "" else null
	data["duration"] = {"player_turns": data["turns"].size(), "rounds": s.round_number}
	data["summary"] = build_summary(data["turns"])
	return save()


func save() -> String:
	if not enabled:
		return ""
	DirAccess.make_dir_recursive_absolute(log_dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
	var path := "%s/escaque_%s_%s.json" % [log_dir, data.get("mode", "X"), stamp]
	var n := 1
	while FileAccess.file_exists(path):
		n += 1
		path = "%s/escaque_%s_%s_%d.json" % [log_dir, data.get("mode", "X"), stamp, n]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir el log en %s" % path)
		return ""
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	last_saved_path = path
	return path


## Métricas por jugador orientadas a las hipótesis H-P0-1..3 y riesgos §9.
static func build_summary(turns: Array) -> Dictionary:
	var out := {}
	for key in ["white", "black"]:
		var n := 0
		var acts := 0
		var spent := 0
		var captures := 0
		var reserve_hist := {"0": 0, "1": 0, "2": 0}
		var lost := 0
		var type_freq := {}
		var sequences := {}
		for t in turns:
			if t["player"] != key:
				continue
			n += 1
			acts += int(t["activations"])
			if t["ap_spent"] != null:
				spent += int(t["ap_spent"])
			if t["ap_reserved"] != null and t["ended_by"] != "fin_partida":
				var r := str(int(t["ap_reserved"]))
				reserve_hist[r] = int(reserve_hist.get(r, 0)) + 1
			if t["ap_lost"] != null:
				lost += int(t["ap_lost"])
			for typ in t["sequence"]:
				type_freq[typ] = int(type_freq.get(typ, 0)) + 1
			var seq_key := "+".join(PackedStringArray(t["sequence"]))
			if seq_key == "":
				seq_key = "(pasa)"
			sequences[seq_key] = int(sequences.get(seq_key, 0)) + 1
			for a in t["actions"]:
				if a["capture"]:
					captures += 1
		out[key] = {
			"turns": n,
			"avg_activations": snappedf(float(acts) / n, 0.01) if n > 0 else 0.0,
			"avg_ap_spent": snappedf(float(spent) / n, 0.01) if n > 0 else 0.0,
			"reserve_histogram": reserve_hist,
			"ap_lost_total": lost,
			"activations_by_type": type_freq,
			"sequences": sequences,
			"captures": captures,
		}
	return out
