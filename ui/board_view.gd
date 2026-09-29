class_name BoardView
extends Control
## Dibuja el tablero y las piezas (formas abstractas + letra + coste). Sin assets.
## Emite clics de casilla; toda la lógica vive en main.gd / MatchController.

signal cell_clicked(cell: Vector2i)
signal cancel_requested

const NONE := Vector2i(-1, -1)
const COORD_MARGIN := 26.0

const C_LIGHT := Color("#d8d2c2")
const C_DARK := Color("#8b9584")
const C_COORD := Color("#9aa0a8")
const C_SELECT := Color(1.0, 0.82, 0.25, 0.55)
const C_LAST := Color(0.35, 0.75, 0.85, 0.35)
const C_HOVER := Color(1, 1, 1, 0.9)
const C_MOVE := Color("#2f6f4f")
const C_CAPTURE := Color("#b8433a")
const C_PREVIEW := Color("#4a6fa5")
const C_WHITE_FILL := Color("#f4f1e8")
const C_WHITE_LINE := Color("#23252b")
const C_BLACK_FILL := Color("#2a2c33")
const C_BLACK_LINE := Color("#eae6da")
const C_BADGE_OK := Color("#e3b341")
const C_BADGE_NO := Color("#c0504d")
const C_BADGE_OFF := Color("#7c7f86")

var mc: MatchController
var selected: Piece = null
var move_targets: Array[Vector2i] = []
var targets_actionable: bool = true
var last_from: Vector2i = NONE
var last_to: Vector2i = NONE
var _hover: Vector2i = NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


# --- geometría ----------------------------------------------------------------

func _n() -> int:
	return mc.rules.board_size if mc and mc.rules else 8


func _cell_size() -> float:
	var avail := size - Vector2(COORD_MARGIN * 2, COORD_MARGIN * 2)
	return floorf(minf(avail.x, avail.y) / _n())


func _origin() -> Vector2:
	var side := _cell_size() * _n()
	return ((size - Vector2(side, side)) / 2.0).floor()


func cell_rect(c: Vector2i) -> Rect2:
	var cs := _cell_size()
	var row := _n() - 1 - c.y  # fila 1 abajo (Blancas)
	return Rect2(_origin() + Vector2(c.x * cs, row * cs), Vector2(cs, cs))


func cell_at(pos: Vector2) -> Vector2i:
	var cs := _cell_size()
	var local := (pos - _origin()) / cs
	var x := int(floor(local.x))
	var row := int(floor(local.y))
	var c := Vector2i(x, _n() - 1 - row)
	if x < 0 or row < 0 or x >= _n() or row >= _n():
		return NONE
	return c


# --- entrada ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != _hover:
			_hover = c
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var c := cell_at(event.position)
			if c != NONE:
				cell_clicked.emit(c)
			else:
				cancel_requested.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != NONE:
		_hover = NONE
		queue_redraw()


# --- dibujo -------------------------------------------------------------------

func _draw() -> void:
	if mc == null or mc.state == null:
		return
	var n := _n()
	var cs := _cell_size()
	var font := get_theme_default_font()
	var coord_size := int(clampf(cs * 0.2, 11, 16))

	# casillas
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			draw_rect(cell_rect(c), C_LIGHT if (x + y) % 2 == 1 else C_DARK)

	# coordenadas
	var o := _origin()
	for i in n:
		var file_pos := Vector2(o.x + i * cs, o.y + n * cs + coord_size + 4)
		draw_string(font, file_pos, char(97 + i), HORIZONTAL_ALIGNMENT_CENTER, cs, coord_size, C_COORD)
		var rank_pos := Vector2(o.x - COORD_MARGIN + 2, cell_rect(Vector2i(0, i)).get_center().y + coord_size * 0.35)
		draw_string(font, rank_pos, str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, COORD_MARGIN - 6, coord_size, C_COORD)

	# último movimiento y selección
	for c in [last_from, last_to]:
		if c != NONE:
			draw_rect(cell_rect(c), C_LAST)
	if selected:
		draw_rect(cell_rect(selected.position), C_SELECT)

	# piezas
	for p in mc.state.board.all_pieces():
		_draw_piece(p, font, cs)

	# destinos
	for t in move_targets:
		var r := cell_rect(t)
		var capture := mc.state.board.piece_at(t) != null
		var col := (C_CAPTURE if capture else C_MOVE) if targets_actionable else C_PREVIEW
		if capture:
			draw_arc(r.get_center(), cs * 0.45, 0, TAU, 40, col, maxf(3.0, cs * 0.06), true)
		else:
			draw_circle(r.get_center(), cs * 0.13, Color(col, 0.85))

	# hover
	if _hover != NONE:
		draw_rect(cell_rect(_hover).grow(-1), C_HOVER, false, 2.0)


func _draw_piece(p: Piece, font: Font, cs: float) -> void:
	var s := mc.state
	var center := cell_rect(p.position).get_center()
	var r := cs * 0.34
	var fill := C_WHITE_FILL if p.owner == Piece.WHITE else C_BLACK_FILL
	var line := C_WHITE_LINE if p.owner == Piece.WHITE else C_BLACK_LINE
	var is_active_side := p.owner == s.active_player and not s.over
	var exhausted := is_active_side and p.activations_this_turn >= mc.rules.max_activations_per_piece
	if exhausted:
		fill = Color(fill, 0.35)
		line = Color(line, 0.45)

	var pts := _shape(p.piece_type, center, r)
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, maxf(2.0, cs * 0.035), true)
	if p.piece_type == "king":  # doble contorno: pieza real
		var inner := _shape("king", center, r * 0.8)
		inner.append(inner[0])
		draw_polyline(inner, line, maxf(1.0, cs * 0.02), true)

	# letra
	var fsize := int(cs * 0.3)
	var letter: String = mc.rules.pieces[p.piece_type]["letter"]
	var baseline := center.y + (font.get_ascent(fsize) - font.get_descent(fsize)) * 0.5
	draw_string(font, Vector2(center.x - cs * 0.5, baseline), letter, HORIZONTAL_ALIGNMENT_CENTER, cs, fsize, line)

	# insignia de coste (sólo con economía de PA)
	if mc.rules.uses_ap():
		var cost := mc.rules.cost_of(p.piece_type)
		var bc := C_BADGE_OFF
		if is_active_side and not exhausted:
			bc = C_BADGE_OK if cost <= s.ap_available else C_BADGE_NO
		var bpos := center + Vector2(r * 0.95, -r * 0.95)
		var br := cs * 0.12
		draw_circle(bpos, br, bc)
		draw_arc(bpos, br, 0, TAU, 24, Color(0, 0, 0, 0.5), 1.0, true)
		var bsize := int(cs * 0.17)
		var bbase := bpos.y + (font.get_ascent(bsize) - font.get_descent(bsize)) * 0.5
		draw_string(font, Vector2(bpos.x - br, bbase), str(cost), HORIZONTAL_ALIGNMENT_CENTER, br * 2, bsize, Color("#1b1b1b"))
	# agotada: aspa sobre la pieza (inequívoco, §14.11)
	if exhausted:
		var k := r * 0.55
		var xc := Color("#c0504d", 0.9)
		var w := maxf(2.0, cs * 0.04)
		draw_line(center + Vector2(-k, -k), center + Vector2(k, k), xc, w, true)
		draw_line(center + Vector2(-k, k), center + Vector2(k, -k), xc, w, true)


## Forma abstracta por tipo: Peón círculo, Caballo rombo, Torre cuadrado, Rey octógono.
func _shape(type: String, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match type:
		"pawn":
			for i in 28:
				pts.append(c + Vector2.from_angle(TAU * i / 28.0) * r * 0.78)
		"knight":
			pts = PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 1.05, 0), c + Vector2(0, r * 1.05), c + Vector2(-r * 1.05, 0)])
		"rook":
			var h := r * 0.85
			pts = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
		_:
			for i in 8:
				pts.append(c + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * r)
	return pts
