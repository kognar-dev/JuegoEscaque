extends SceneTree
## Genera el informe de partidas desde la línea de comandos.
##   godot --headless --path . -s res://tools/analyze_logs.gd -- [carpeta_de_logs] [salida.md]
## Sin argumentos usa user://logs y escribe user://logs/informe_escaque.md.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://logs"
	var out := args[1] if args.size() > 1 else ""
	var path := LogAnalyzer.write_report(dir, out)
	if path == "":
		quit(1)
		return
	print(FileAccess.get_file_as_string(path))
	print("\nInforme escrito en: ", ProjectSettings.globalize_path(path))
	quit(0)
