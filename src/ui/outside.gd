## Everything the app opens outside itself: a link in the browser, a file in
## the program that opens its kind, a file in its folder. Every one goes
## through here; tests/test_outside.py fails on any other call to the
## system's opener.
##
## A run that is not the person's own app opens nothing, and keeps what it
## was asked to open in [member opened] instead. An agent's shell carries
## the owner's desktop (its Wayland display and its D-Bus), and a probe that
## chose Documentation opened brickworks.diy/docs in a browser on the
## owner's screen for seven minutes (2026-10-29); twenty other buttons
## called the system straight, each a probe away from doing the same.
class_name Outside
extends RefCounted

## What a held run was asked to open, in order: each link's address, and
## each path a folder was to be shown at. A probe reads this.
static var opened: Array[String] = []


## Whether this run opens nothing. Any script's run (a probe or a tool:
## `--script` or `-s`, whose main loop is that script) is held, whoever
## started it and however, so no probe can forget to be; and any run under
## tools/probe.sh or tools/check.sh, which set BRICKWORKS_OPEN_NOTHING. The
## person's app runs src/main.tscn on Godot's own SceneTree, and never is.
static func held() -> bool:
	if OS.has_environment("BRICKWORKS_OPEN_NOTHING"):
		return true
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null


## [param address] open in the browser (a new tab, on the web), or a
## file:// path in the program the system opens its kind with.
static func open_link(address: String) -> Error:
	if held():
		opened.append(address)
		return OK
	return OS.shell_open(address)


## The file manager open on [param path], selected where it can be.
static func show_in_folder(path: String) -> Error:
	if held():
		opened.append(path)
		return OK
	return OS.shell_show_in_file_manager(path)
