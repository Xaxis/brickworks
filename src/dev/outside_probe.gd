## Does a probe that presses the app's links and Show in folder open nothing
## on the desktop, and keep what it would have opened (Outside)?
##
##   godot --headless --path . --script src/dev/outside_probe.gd
##
## An agent's shell carries the owner's desktop: a probe that pressed
## Documentation opened brickworks.diy/docs in a browser on the owner's
## screen for seven minutes (2026-10-29). Every link and every Show in
## folder now goes through Outside, which opens nothing in a script's run.
## This presses three that called the system straight before: the share
## panel's Open, Help's Website and Documentation, and the status bar's Show
## in folder after File, Export, LDraw. Under tools/probe.sh the desktop's
## openers are stubs that fail the run when anything reaches one.
extends SceneTree

const MODEL := "res://models/car.ldr"
const SHARED := "outside-probe-model"

var _failures: int = 0
var _main: Node
var _shell: Shell


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	_check("a script's run is held, started by tools/probe.sh or not (BRICKWORKS_OPEN_NOTHING %s)"
		% ("set" if OS.has_environment("BRICKWORKS_OPEN_NOTHING") else "not set"), Outside.held())
	var downloads: String = OS.get_user_data_dir().path_join("outside_probe_downloads")
	DirAccess.make_dir_recursive_absolute(downloads)
	Download.folder = downloads
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	_shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress(MODEL)
	if not _check("%s opened, %d parts" % [MODEL, placed], placed > 0):
		_finish()
		return

	# The share panel's Open, on a model with a link.
	var share: SharePanel = _main.get("_share_panel")
	share.call("_show_link", SHARED)
	var open: Button = share.get("_open_link")
	_press(open)
	_check_opened("the share panel's Open", [SharedModels.link_for(SHARED)])

	# Help, Website and Documentation.
	_shell.run("website")
	await _frames(4)
	_check_opened("Help, Brickworks website", ["https://brickworks.diy"])
	_shell.run("docs")
	await _frames(4)
	_check_opened("Help, Documentation", [DocsPages.SITE + _shell.docs_page()])

	# File, Export, LDraw, then the status bar's Show in folder.
	_shell.run("export_ldraw")
	var written: String = ""
	for _n: int in 600:
		await process_frame
		if not SaveTo.shown.is_empty():
			written = SaveTo.shown
			break
	_check("the export wrote %s, in the probe's own folder" % written,
		not written.is_empty() and written.begins_with(downloads) and FileAccess.file_exists(written))
	var show: Button = _shell.status.show_folder
	for _n: int in 60:
		await process_frame
		if show.visible:
			break
	_check("the status bar offers Show in folder", show.visible)
	_press(show)
	_check_opened("Show in folder", [written])
	_finish()


func _press(button: Button) -> void:
	Outside.opened.clear()
	if _check("%s can be pressed" % button.text, not button.disabled):
		button.pressed.emit()


## What [param what] asked to open: exactly [param wanted], kept and not opened.
func _check_opened(what: String, wanted: Array) -> void:
	_check("%s opens nothing, and keeps %s" % [what, ", ".join(Outside.opened)],
		", ".join(Outside.opened) == ", ".join(wanted) and Outside.opened.size() == wanted.size())
	Outside.opened.clear()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("outside probe: all checks passed")
	else:
		print("outside probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
