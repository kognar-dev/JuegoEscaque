extends SceneTree
## Utilidad de desarrollo: renderiza la escena principal en varios estados y guarda PNG.
## godot --path . --rendering-driver opengl3 -s res://tests/screenshot.gd -- <carpeta_salida>

var out_dir := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.mc.logger.enabled = false
	await _shot("01_inicio")

	var mc: MatchController = main.mc
	var b := mc.state.board
	main._on_cell_clicked(Board.parse_square("d1"))
	main._on_cell_clicked(Board.parse_square("c3"))
	main._on_cell_clicked(Board.parse_square("e2"))
	main._on_cell_clicked(Board.parse_square("e3"))
	main._on_cell_clicked(Board.parse_square("c1"))  # Torre: 3 PA, quedan 3 → activable
	await _shot("02_p0_turno_en_curso")

	main._try_end_turn()
	main._on_cell_clicked(Board.parse_square("e8"))
	main._on_cell_clicked(Board.parse_square("d6"))
	main._on_cell_clicked(Board.parse_square("c7"))
	main._on_cell_clicked(Board.parse_square("c6"))
	main._on_cell_clicked(Board.parse_square("f8")) # 3 PA con 3 restantes
	main._on_cell_clicked(Board.parse_square("c3")) # consulta pieza rival
	await _shot("03_consulta_rival")

	main._start("C0")
	main._on_cell_clicked(Board.parse_square("d1"))
	await _shot("04_c0")

	main._start("P0")
	# Partida corta hacia captura de Rey
	var seq := [["d1", "e3"], ["END"], ["e8", "f6"], ["END"], ["e3", "f5"], ["END"], ["f6", "e4"], ["END"], ["f5", "e7"], ["END"], ["d7", "d6"], ["END"], ["e7", "c6"], ["END"], ["c7", "c6"], ["END"], ["e2", "e3"], ["END"], ["e4", "d2"], ["END"], ["e1", "d2"], ["END"], ["d8", "d7"], ["END"]]
	for step in seq:
		if step[0] == "END":
			main._try_end_turn()
		else:
			main._on_cell_clicked(Board.parse_square(step[0]))
			main._on_cell_clicked(Board.parse_square(step[1]))
	mc.declare_draw("captura de prueba")
	await _shot("05_fin")
	quit()
