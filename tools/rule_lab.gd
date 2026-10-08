extends SceneTree
## Laboratorio de reglas desde la línea de comandos.
##   godot --headless --path . -s res://tools/rule_lab.gd -- [experimentos.json] [partidas_por_variante]
## Sin argumentos usa res://data/lab_experiments.json. El informe y los logs quedan en user://lab/.

const LAB := preload("res://core/rule_lab.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var exp_path := args[0] if args.size() > 0 else LAB.DEFAULT_EXPERIMENTS
	var games := int(args[1]) if args.size() > 1 else -1
	var last := [""]
	var path: String = LAB.run(exp_path, "user://lab", games, func(vid, g, n):
		if vid != last[0]:
			last[0] = vid
			print("· ", vid)
		if g == n or g % 10 == 0:
			print("    %d/%d partidas" % [g, n]))
	print("")
	print(FileAccess.get_file_as_string(path))
	print("Informe: ", ProjectSettings.globalize_path(path))
	quit(0)
