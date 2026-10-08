class_name AIPlayer
extends RefCounted
## IA de ESCAQUE.
##
## Un turno es una SECUENCIA de activaciones (varias piezas, orden libre, PA limitados),
## así que la IA no elige «una jugada»: planifica el turno entero con búsqueda en haz
## (beam search). En cada paso amplía los mejores planes parciales con todas las
## activaciones posibles y evalúa la posición resultante. Puede detenerse en cualquier
## paso, lo que le permite guardar PA como Reserva cuando eso puntúa mejor.
##
## La evaluación mira un turno del rival hacia delante de forma heurística (sin buscar
## sus jugadas): ¿puede capturar mi Rey con sus PA?, ¿qué piezas mías puede ganar?
## Es determinista salvo por un pequeño ruido configurable, que da variedad.

const WIN := 100000.0

## Niveles: anchura del haz, ruido de evaluación y tope de activaciones por turno.
const LEVELS := {
	"facil": {"label": "IA fácil", "beam": 1, "noise": 2.5, "max_actions": 3},
	"normal": {"label": "IA normal", "beam": 3, "noise": 0.3, "max_actions": 0},
	"dificil": {"label": "IA difícil", "beam": 6, "noise": 0.05, "max_actions": 0},
}

## Pesos de la evaluación. Se pueden sobrescribir por instancia (perfiles de IA).
const DEFAULT_WEIGHTS := {
	"material": 1.0,        ## valor de las piezas propias menos las rivales
	"king_danger": 60.0,    ## el rival puede capturar mi Rey en su próximo turno
	"hanging": 0.85,        ## material que el rival puede ganarme con sus PA
	"threats": 0.12,        ## piezas rivales que ataco (puede retirarlas)
	"king_pressure": 0.3,   ## casillas del Rey rival y su entorno que controlo
	"approach": 0.05,       ## cercanía de mis piezas al Rey rival (romper tablas)
	"pawn_advance": 0.08,   ## avance de peones (más si hay promoción)
	"mobility": 0.015,      ## casillas atacadas
	"reserve": 0.3,         ## PA que pasarían a Reserva
	"midline": 0.6,         ## avance del Rey hacia la mitad rival (si la regla está activa)
	"repetition": 1.0,      ## evitar repetir posiciones si voy por delante (buscarlas si voy por detrás)
}

var level: String
var beam_width: int
var noise: float
var max_actions: int
var weights: Dictionary = DEFAULT_WEIGHTS.duplicate()
var rng := RandomNumberGenerator.new()
var nodes_evaluated := 0
var _history: Dictionary = {}


func _init(p_level: String = "normal", seed: int = -1) -> void:
	level = p_level if LEVELS.has(p_level) else "normal"
	var cfg: Dictionary = LEVELS[level]
	beam_width = int(cfg["beam"])
	noise = float(cfg["noise"])
	max_actions = int(cfg["max_actions"])
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()


static func level_label(id: String) -> String:
	return String(LEVELS.get(id, {}).get("label", id))


# --- planificación ------------------------------------------------------------------

## Devuelve el plan del turno: [{piece_id, to: Vector2i}, ...] en orden.
## Plan vacío = terminar el turno sin activar (guardar PA).
func plan_turn(state: GameState) -> Array[Dictionary]:
	nodes_evaluated = 0
	var me := state.active_player
	_history = state.position_counts
	var root := state.clone()
	var best_plan: Array[Dictionary] = []
	var best_score := -INF
	if state.rules.uses_ap():  # en C0 hay que activar; en P0 «no hacer nada» es una opción
		best_score = evaluate(root, me) + rng.randf() * noise + _repetition_term(root, me)
	var beam: Array = [{"sim": root, "plan": [] as Array[Dictionary]}]
	var steps := 0
	while not beam.is_empty():
		var children: Array = []
		for node in beam:
			var sim: GameState = node["sim"]
			for p in sim.board.pieces_of(me):
				if not TurnController.can_activate(sim, p):
					continue
				for m in TurnController.affordable_moves(sim, p):
					var s2 := sim.clone()
					TurnController.activate(s2, s2.board.piece_at(p.position), m)
					var plan: Array[Dictionary] = node["plan"].duplicate()
					plan.append({"piece_id": p.id, "to": m})
					var sc: float
					if s2.over and s2.winner == me:
						sc = WIN - plan.size()  # captura del Rey: cuanto antes, mejor
					else:
						sc = evaluate(s2, me) + rng.randf() * noise + _repetition_term(s2, me)
					children.append({"sim": s2, "plan": plan, "score": sc})
		if children.is_empty():
			break
		children.sort_custom(func(a, b): return a["score"] > b["score"])
		if children[0]["score"] > best_score:
			best_score = children[0]["score"]
			best_plan = children[0]["plan"]
		if best_score >= WIN - 100.0:
			break
		steps += 1
		if max_actions > 0 and steps >= max_actions:
			break
		beam = children.slice(0, beam_width)
	return best_plan


## Penaliza (o premia, si voy perdiendo) dejar una posición que ya se ha visto: así las
## tablas por repetición reflejan las reglas y no una IA que da vueltas sin rumbo.
func _repetition_term(s: GameState, me: int) -> float:
	if _history.is_empty():
		return 0.0
	var seen := int(_history.get(next_turn_key(s), 0))
	if seen == 0:
		return 0.0
	var diff := 0.0
	for p in s.board.pieces_of(me):
		diff += piece_value(s, p)
	for p in s.board.pieces_of(1 - me):
		diff -= piece_value(s, p)
	var sign := -1.0 if diff > -0.5 else 0.5
	return sign * weights["repetition"] * seen


## Clave de posición que tendría el rival al empezar su turno si termino el mío ahora
## (mismo formato que GameState.position_key).
static func next_turn_key(s: GameState) -> String:
	var opp := s.opponent()
	var parts: PackedStringArray = []
	for p in s.board.all_pieces():
		parts.append("%s%d@%d,%d" % [p.piece_type, p.owner, p.position.x, p.position.y])
	parts.sort()
	var opp_ap := (s.rules.base_ap + s.reserve[opp]) if s.rules.uses_ap() else 0
	return "%s|%d|%d|%d" % [";".join(parts), opp, opp_ap, TurnController.projected_reserve(s)]


# --- evaluación ---------------------------------------------------------------------

## Puntuación de la posición `s` (a mitad o al final del turno de `me`), vista por `me`,
## suponiendo que el rival juega a continuación.
func evaluate(s: GameState, me: int) -> float:
	nodes_evaluated += 1
	var r := s.rules
	var b := s.board
	var w := weights
	var opp := 1 - me
	var mine := b.pieces_of(me)
	var theirs := b.pieces_of(opp)
	var my_kings := s.royal_pieces(me)
	var op_kings := s.royal_pieces(opp)
	if my_kings.is_empty():
		return -WIN
	if op_kings.is_empty():
		return WIN

	# Mapas de ataque: casilla -> piezas que la atacan.
	var my_att := _attack_map(b, mine, r)
	var op_att := _attack_map(b, theirs, r)

	# Presupuesto del rival en su próximo turno.
	var op_budget := (r.base_ap + s.reserve[opp]) if r.uses_ap() else 0
	var op_max_acts := 99 if r.uses_ap() else 1

	var score := 0.0
	for p in mine:
		score += w["material"] * piece_value(s, p)
	for p in theirs:
		score -= w["material"] * piece_value(s, p)

	# 1. Seguridad del Rey: ¿puede el rival capturarlo en su próximo turno?
	for k in my_kings:
		if king_capturable(s, k, op_att, op_budget, op_max_acts):
			score -= w["king_danger"]
			break

	# 2. Material colgado: lo que el rival puede ganar de forma rentable con sus PA.
	score -= w["hanging"] * expected_loss(s, mine, my_att, op_att, op_budget, op_max_acts)

	# 3. Iniciativa: amenazas, presión sobre el Rey rival, cercanía, movilidad.
	for p in theirs:
		if my_att.has(p.position) and not bool(r.pieces[p.piece_type].get("royal", false)):
			score += w["threats"] * piece_value(s, p)
	for k in op_kings:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var sq := k.position + Vector2i(dx, dy)
				if my_att.has(sq):
					score += w["king_pressure"] * (2.0 if sq == k.position else 1.0)
		for p in mine:
			if p in my_kings:
				continue
			var dist := maxi(absi(p.position.x - k.position.x), absi(p.position.y - k.position.y))
			score += w["approach"] * (r.board_size - dist)
	score += w["mobility"] * my_att.size()

	# 4. Peones: avance (vale más si hay promoción).
	var adv_w: float = w["pawn_advance"]
	if r.promotion != "":
		adv_w += (_type_value(r, r.promotion) - 1.0) / maxf(1.0, r.board_size - 2.0) * 0.6
	for p in mine:
		if r.pieces[p.piece_type]["movement"] == "pawn":
			score += adv_w * _pawn_progress(r, p)

	# 5. Reserva: PA que me llevaría al turno siguiente si termino ahora.
	if r.uses_ap() and s.active_player == me:
		score += w["reserve"] * TurnController.projected_reserve(s)

	# 6. Invasión de la línea media (si la regla está activa).
	if r.midline_victory:
		if VictorySystem.king_invading(s, opp):
			score -= WIN * 0.5  # si no lo capturo este turno, gana al empezar el suyo
		var danger := false
		for k in my_kings:
			if king_capturable(s, k, op_att, op_budget, op_max_acts):
				danger = true
		if VictorySystem.king_invading(s, me) and not danger:
			score += WIN * 0.4  # ganaré al empezar mi próximo turno
		for k in my_kings:
			score += w["midline"] * _king_progress(r, k)
	return score


## Valor material de una pieza en la posición actual.
func piece_value(s: GameState, p: Piece) -> float:
	var r := s.rules
	if bool(r.pieces[p.piece_type].get("royal", false)):
		return 0.0  # la pérdida del Rey se trata como derrota, no como material
	if r.pieces[p.piece_type]["movement"] == "pawn" and r.promotion == "":
		var last := r.board_size - 1 if p.owner == Piece.WHITE else 0
		if p.position.y == last:
			return 0.25  # peón sin promoción en la última fila: ya no se mueve
	return _type_value(r, p.piece_type)


static func _type_value(r: RulesConfig, type: String) -> float:
	var def: Dictionary = r.pieces[type]
	if float(def.get("ai_value", -1.0)) >= 0.0:
		return float(def["ai_value"])
	var v := 1.5 * float(def["cost"])
	match type:
		"pawn":
			v = 1.0
		"knight":
			v = 3.0
		"bishop":
			v = 3.0
		"rook":
			v = 5.0
		"queen":
			v = 9.0
	# Deslizantes con alcance limitado valen menos.
	var rng_max := int(def.get("max_range", 0))
	if def["movement"] == "slider" and rng_max > 0:
		v *= 0.6 + 0.4 * minf(1.0, float(rng_max) / (r.board_size - 1))
	return v


## ¿Puede el rival capturar al Rey `k` en su próximo turno?
## Cubre: captura directa por cualquier pieza que pueda pagar, y «descubierta»: el rival
## aparta primero una pieza propia que tapa la línea de una pieza deslizante.
## (Capturar una pieza mía que tapa la línea no la abre: el captor ocupa la casilla.)
func king_capturable(s: GameState, k: Piece, op_att: Dictionary, budget: int, max_acts: int) -> bool:
	var r := s.rules
	for a in op_att.get(k.position, []):
		if r.cost_of(a.piece_type) <= budget:
			return true
	if max_acts < 2:
		return false
	var b := s.board
	for q in b.pieces_of(k.owner ^ 1):
		var def: Dictionary = r.pieces[q.piece_type]
		if def["movement"] != "slider":
			continue
		var max_range := int(def.get("max_range", 0))
		for d in def["directions"]:
			# Recorrer desde la pieza deslizante hacia el Rey por la dirección d.
			var t: Vector2i = q.position + d
			var blocker: Piece = null
			var steps := 1
			while b.in_bounds(t) and (max_range <= 0 or steps <= max_range):
				var occ := b.piece_at(t)
				if occ != null:
					if occ == k:
						if blocker != null and r.cost_of(q.piece_type) + r.cost_of(blocker.piece_type) <= budget:
							return true
						break
					if blocker != null or occ.owner == k.owner:
						break  # dos bloqueos, o bloqueo mío: no se abre en un turno
					if MoveGenerator.legal_moves(b, occ, r).is_empty():
						break
					blocker = occ  # pieza propia del rival que puede apartarse
				t += d
				steps += 1
	return false


## Material que el rival puede ganarme de forma rentable en su próximo turno.
## Voraz: cada pieza rival captura una vez, dentro de su presupuesto de PA; si la víctima
## está defendida, se descuenta el valor del captor (yo recapturaría).
func expected_loss(s: GameState, mine: Array[Piece], my_att: Dictionary,
		op_att: Dictionary, budget: int, max_acts: int) -> float:
	var r := s.rules
	var options: Array = []
	for v in mine:
		if bool(r.pieces[v.piece_type].get("royal", false)):
			continue
		var attackers: Array = op_att.get(v.position, [])
		if attackers.is_empty():
			continue
		var defended := my_att.has(v.position)
		var best_gain := 0.0
		var best_att: Piece = null
		for a in attackers:
			if r.cost_of(a.piece_type) > budget:
				continue
			var gain := piece_value(s, v) - (piece_value(s, a) if defended else 0.0)
			if gain > best_gain:
				best_gain = gain
				best_att = a
		if best_att != null:
			options.append([best_gain, best_att])
	options.sort_custom(func(x, y): return x[0] > y[0])
	var used := {}
	var total := 0.0
	var acts := 0
	for o in options:
		var a: Piece = o[1]
		var c := r.cost_of(a.piece_type)
		if used.has(a.id) or c > budget or acts >= max_acts:
			continue
		used[a.id] = true
		budget -= c
		acts += 1
		total += o[0]
	return total


static func _attack_map(b: Board, pieces: Array[Piece], r: RulesConfig) -> Dictionary:
	var m := {}
	for p in pieces:
		for sq in MoveGenerator.attack_squares(b, p, r):
			if not m.has(sq):
				m[sq] = []
			m[sq].append(p)
	return m


static func _pawn_progress(r: RulesConfig, p: Piece) -> float:
	return float(p.position.y) if p.owner == Piece.WHITE else float(r.board_size - 1 - p.position.y)


## Avance del Rey hacia la mitad rival: 0 en su fila inicial, máximo al cruzar.
static func _king_progress(r: RulesConfig, k: Piece) -> float:
	var half := r.board_size / 2
	var y := k.position.y if k.owner == Piece.WHITE else r.board_size - 1 - k.position.y
	return float(mini(y, half))
