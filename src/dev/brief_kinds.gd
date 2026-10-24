## The kinds of set each brief names, read as the app reads a brief
## (PartLibrary.kinds_for), for tools/texture.py.
##
##   godot --headless --path . --script src/dev/brief_kinds.gd -- --out=FILE BRIEF...
##
## FILE is written as JSON, each brief -> its kinds, what it is first first.
## texture.py kept a Python copy of the rule, and it missed both of a day's
## fixes to it: "speedboat" and "speed boat" were still the speed kind there,
## high-speed trains, after the app read each as a boat (race244). So the rule
## is the app's alone, and the tool asks it. Not a check: it passes or fails
## nothing, and exits 1 only when it could not read the catalogue.
extends SceneTree


func _initialize() -> void:
	var out_path: String = ""
	var briefs := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr(6)
		else:
			briefs.append(arg)
	var library := PartLibrary.new()
	if out_path.is_empty() or not library.load_catalogue():
		printerr("brief_kinds: %s" % ("no --out=FILE" if out_path.is_empty() else "no catalogue"))
		quit(1)
		return
	var read: Dictionary = {}
	for brief: String in briefs:
		var kinds: Array = []
		for entry: Dictionary in library.kinds_for(brief):
			kinds.append(entry["kind"])
		read[brief] = kinds
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("brief_kinds: cannot write %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(read))
	file.close()
	quit(0)
