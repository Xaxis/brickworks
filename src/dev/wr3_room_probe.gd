## room_steady_probe at an interface size and in a language (wingreview3):
## the status bar fits the window, nothing cut mid-word or past its edge, and
## the model's room holds still through puts and undos.
##
##   godot --path . --resolution 390x844 --script src/dev/wr3_room_probe.gd -- --lang=de --wr3size=1.5
##
## --lang= is the app's own (Language.start); --wr3size= is Settings,
## Interface size, set before the app's first frame.
extends "res://src/dev/room_steady_probe.gd"


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wr3size="):
			ShellPrefs.put("interface_size", float(argument.trim_prefix("--wr3size=")))
	print("  wr3_room: interface size %s, language %s" % [ShellPrefs.interface_size(), Language.current()])
	await super._run()
