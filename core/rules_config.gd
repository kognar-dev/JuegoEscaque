class_name RulesConfig
extends RefCounted
## Parámetros de reglas cargados desde JSON (GDD §13.4).
## Nada de lo que está aquí es lógica: sólo datos.

const DEFAULT_PATH := "res://data/escaque_rules.json"
const ECONOMY_AP := "ap"
const ECONOMY_SINGLE := "single_activation"

var mode_id: String = "P0"
var mode_label: String = ""
var board_size: int = 8
var economy: String = ECONOMY_AP
var base_ap: int = 6
var max_reserve: int = 2
var max_activations_per_piece: int = 1
## Fin de partida automático (Anexo A · A.2.2 y A.2.3). 0 = desactivado.
var repetition_limit: int = 3
var no_progress_turns: int = 30
var no_moves_loses: bool = false
## Reglas opcionales (Anexo A · A.2.1 y A.2.6).
## promotion: "" = sin promoción (P0), o tipo de pieza al que corona automáticamente.
var promotion: String = ""
## Victoria si el Rey empieza su turno en la mitad rival (sobrevivió al turno del rival).
var midline_victory: bool = false
## Retroceso de peón (propuesta de diseño): una casilla hacia atrás, sin capturar,
## pagando coste × factor.
var pawn_retreat: bool = false
var pawn_retreat_cost_factor: int = 2
var first_player: int = 0  # 0 = Blancas, 1 = Negras
var setup_rows: PackedStringArray = PackedStringArray()
## type -> { name, letter, symbol, cost, movement, offsets, directions, royal }
var pieces: Dictionary = {}
## símbolo en minúscula -> type
var symbol_to_type: Dictionary = {}
## Copia del JSON original para el log.
var raw: Dictionary = {}


static func available_modes(path: String = DEFAULT_PATH) -> Dictionary:
	var data := _read_json(path)
	var out := {}
	for k in data.get("modes", {}).keys():
		out[k] = String(data["modes"][k].get("label", k))
	return out


static func load_mode(mode: String, path: String = DEFAULT_PATH) -> RulesConfig:
	return from_dict(_read_json(path), mode)


static func from_dict(data: Dictionary, mode: String) -> RulesConfig:
	var c := RulesConfig.new()
	c.raw = data.duplicate(true)
	c.mode_id = mode
	c.board_size = int(data.get("board_size", 8))
	c.first_player = 0 if String(data.get("first_player", "white")) == "white" else 1
	c.setup_rows = PackedStringArray(data.get("setup", []))

	var modes: Dictionary = data.get("modes", {})
	assert(modes.has(mode), "Modo desconocido: %s" % mode)
	var m: Dictionary = modes[mode]
	c.mode_label = String(m.get("label", mode))
	c.economy = String(m.get("economy", ECONOMY_AP))
	c.base_ap = int(m.get("base_ap", 0))
	c.max_reserve = int(m.get("max_reserve", 0))
	c.max_activations_per_piece = int(m.get("max_activations_per_piece", 1))

	var opts: Dictionary = data.get("end_rules", {}).duplicate()
	opts.merge(data.get("rule_options", {}), true)
	opts.merge(m, true)  # el modo sobrescribe los valores globales
	c.repetition_limit = int(opts.get("repetition_limit", 3))
	c.no_progress_turns = int(opts.get("no_progress_turns", 30))
	c.no_moves_loses = bool(opts.get("no_moves_loses", false))
	c.promotion = String(opts.get("promotion", ""))
	c.midline_victory = bool(opts.get("midline_victory", false))
	c.pawn_retreat = bool(opts.get("pawn_retreat", false))
	c.pawn_retreat_cost_factor = int(opts.get("pawn_retreat_cost_factor", 2))

	for type in data.get("pieces", {}).keys():
		var p: Dictionary = data["pieces"][type]
		var def := {
			"name": String(p.get("name", type)),
			"letter": String(p.get("letter", type.substr(0, 1).to_upper())),
			"symbol": String(p.get("symbol", type.substr(0, 1))).to_lower(),
			"cost": int(p.get("cost", 1)),
			"movement": String(p.get("movement", "leaper")),
			"offsets": _to_vectors(p.get("offsets", [])),
			"directions": _to_vectors(p.get("directions", [])),
			"max_range": int(p.get("max_range", 0)),  ## deslizantes: 0 = sin límite
			"royal": bool(p.get("royal", false)),
			"ai_value": float(p.get("ai_value", -1.0)),  ## valor material para la IA (-1 = por defecto)
		}
		c.pieces[type] = def
		c.symbol_to_type[def["symbol"]] = type
	c._validate()
	return c


## Valida las opciones tras cargar (promoción a un tipo inexistente → error claro).
func _validate() -> void:
	assert(promotion == "" or pieces.has(promotion), "promotion: tipo de pieza desconocido «%s»" % promotion)


## Mitad rival del tablero para `owner` (Blancas: filas superiores).
func in_enemy_half(owner: int, pos: Vector2i) -> bool:
	return pos.y >= board_size / 2 if owner == Piece.WHITE else pos.y < board_size / 2


func uses_ap() -> bool:
	return economy == ECONOMY_AP


## Coste de activación efectivo en el modo actual (0 en C0).
func cost_of(type: String) -> int:
	if not uses_ap():
		return 0
	return int(pieces[type]["cost"])


func piece_name(type: String) -> String:
	return String(pieces[type]["name"])


func to_log_dict() -> Dictionary:
	var costs := {}
	for t in pieces.keys():
		costs[t] = int(pieces[t]["cost"])
	return {
		"mode": mode_id,
		"economy": economy,
		"board_size": board_size,
		"base_ap": base_ap if uses_ap() else null,
		"max_reserve": max_reserve if uses_ap() else null,
		"max_activations_per_piece": max_activations_per_piece,
		"costs": costs if uses_ap() else null,
		"repetition_limit": repetition_limit,
		"no_progress_turns": no_progress_turns,
		"no_moves_loses": no_moves_loses,
		"promotion": promotion,
		"midline_victory": midline_victory,
		"pawn_retreat": pawn_retreat,
		"pawn_retreat_cost_factor": pawn_retreat_cost_factor,
		"setup": Array(setup_rows),
	}


static func _to_vectors(arr) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in arr:
		out.append(Vector2i(int(v[0]), int(v[1])))
	return out


static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "No se puede abrir %s" % path)
	var parsed = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary, "JSON inválido en %s" % path)
	return parsed
