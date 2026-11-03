## Does a model file given to the app, as a system hands over a double-click,
## open in it?
##
##   godot --headless --path . --script src/dev/given_file_probe.gd
##
## A double-click on a .ldr, .mpd, .io or .lxf runs the app with the file's
## path and nothing else (Exec=brickworks %f on Linux, "%1" on Windows, the
## openFiles event on a Mac, which Godot puts in its arguments). Until the
## packages registered those types (docs/DISTRIBUTION.md) the app read no such
## argument and came up on its last model. Each kind here is copied into a
## folder with a space in its name, and the app run on it headless with
## --out=, which writes what it opened and quits: it says "opened <path>: N
## parts" (Main._open_given), and the file it wrote holds those N. A file
## that is not a model says why it did not open. tools/release.py smoke runs
## the same on each package, and each system's own double-click.
extends SceneTree

const FIXTURES := ["res://models/car.ldr", "res://src/dev/fixtures/telescope.mpd",
	"res://tests/fixtures/studio/bay_2025.io", "res://src/dev/fixtures/49311_test.lxf"]

var _failures: int = 0


func _initialize() -> void:
	var folder: String = ProjectSettings.globalize_path("user://given file probe")
	DirAccess.make_dir_recursive_absolute(folder)
	for fixture: String in FIXTURES:
		var model: String = folder.path_join(fixture.get_file())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(fixture), model)
		var run: Dictionary = _run(model)
		var parts: int = _opened(run.output, model)
		var written: int = ModelStore.count_in(FileAccess.get_file_as_string(run.out))
		_check("%s given as a double-click gives it opens: %d parts, %d written back, exit %d"
			% [model.get_file(), parts, written, run.code],
			run.code == 0 and parts > 0 and written == parts)
	var garbled: String = folder.path_join("not a model.ldr")
	var file: FileAccess = FileAccess.open(garbled, FileAccess.WRITE)
	file.store_string("<html>Not Found</html>\n")
	file.close()
	var refused: Dictionary = _run(garbled)
	_check("a .ldr that is not a model says it could not open, and opens nothing",
		refused.output.contains("could not open %s" % garbled) and _opened(refused.output, garbled) < 0)
	DirAccess.remove_absolute(garbled)
	print("given_file: %s" % ("each kind opens as a double-click gives it" if _failures == 0
		else "%d failures" % _failures))
	quit(1 if _failures > 0 else 0)


## The app on [model], headless, writing what it opened and quitting.
func _run(model: String) -> Dictionary:
	var out: String = ProjectSettings.globalize_path("user://given_file_probe_out.ldr")
	DirAccess.remove_absolute(out)
	var said: Array = []
	var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), model, "--", "--out=" + out]), said, true)
	return {"code": code, "output": "".join(said), "out": out}


## The parts the app said it opened [model] with, or -1.
func _opened(output: String, model: String) -> int:
	var found: RegExMatch = RegEx.create_from_string(
		"opened [^\\n]*" + _escaped(model.get_file()) + ": (\\d+) parts").search(output)
	return int(found.get_string(1)) if found != null else -1


func _escaped(text: String) -> String:
	var out: String = ""
	for character: String in text:
		out += ("\\" + character) if ".()[]{}+*?^$|\\".contains(character) else character
	return out


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
