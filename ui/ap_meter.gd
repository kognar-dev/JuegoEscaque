class_name APMeter
extends Control
## Contador visual de PA: ● disponibles, ○ gastados; anillo dorado = lo que se
## guardaría como Reserva si se terminase el turno ahora.

const C_FILL := Color("#e3b341")
const C_EMPTY := Color("#5a5d66")
const C_RESERVE := Color("#fff2c2")

var available: int = 0
var total: int = 0
var reserve_if_end: int = 0


func set_values(p_available: int, p_total: int, p_reserve: int) -> void:
	available = p_available
	total = p_total
	reserve_if_end = p_reserve
	queue_redraw()


func _draw() -> void:
	if total <= 0:
		return
	var r := minf(size.y * 0.36, 13.0)
	var gap := r * 2.0 + 8.0
	var y := size.y * 0.5
	for i in total:
		var c := Vector2(r + 2 + i * gap, y)
		if i < available:
			draw_circle(c, r, C_FILL)
			if i >= available - reserve_if_end:
				draw_arc(c, r + 3, 0, TAU, 32, C_RESERVE, 2.0, true)
		else:
			draw_arc(c, r - 1, 0, TAU, 32, C_EMPTY, 2.0, true)
