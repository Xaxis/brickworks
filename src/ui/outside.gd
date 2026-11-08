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
## started it and however, so no probe can forget to be; any run under
## tools/probe.sh or tools/check.sh, which set BRICKWORKS_OPEN_NOTHING; and
## the app started from a Claude Code session (CLAUDECODE), as appux3's MCP
## walk started it, whose render went into the owner's Downloads. The
## person's app runs src/main.tscn on the project's own main loop, from
## their desktop or a browser tab, and never is. A held run writes its files
## into its own data (Download.downloads).
static func held() -> bool:
	if OS.has_environment("BRICKWORKS_OPEN_NOTHING") or OS.has_environment("CLAUDECODE"):
		return true
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and a_script_run(loop.get_script())


## Whether a main loop of [param script] is a script's run: any script but
## the project's own main loop (BrickworksLoop, a script too), which the
## person's app runs on. Counted as a script's run, it opened no link and
## put no file in Downloads, on the web or the desktop (rel-m271's preview).
static func a_script_run(script: Script) -> bool:
	return script != null and script.get_global_name() \
		!= StringName(str(ProjectSettings.get_setting("application/run/main_loop_type")))


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
