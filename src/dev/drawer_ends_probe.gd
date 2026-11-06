## Does a drawer end with the app that started it, however the app ends?
##
##   godot --headless --path . --script src/dev/drawer_ends_probe.gd
##
## A bench design's app runs headless and starts a drawer for its pictures
## (src/ai/leased_shots.gd, --draw-by=): `gpu --brief xvfb-run ... godot`,
## which can wait minutes in the GPU lease's queue. The bench ends an app by
## a signal to its group (realset's _stop, booklet_follow's build, timeout),
## and Godot starts the drawer in a session of its own, which that signal
## never reaches, while the app, killed, runs no tree_exiting. So a drawer
## still queued outlived its app, took a slot when its turn came, for nobody,
## and in a relay tab without Claude Code failed on 'xvfb-run', the tab's
## PATH gone with its home (44 relay designs' logs, 2026-10-29 to 11-05).
## Here an app is started as the bench starts one, its drawer a stand-in
## that waits as `gpu` waits in the queue, and ended by SIGTERM to its group
## as realset ends a tab, then by SIGKILL: each time the drawer is the app's
## child, lives while the app does, and is sent SIGTERM as the app ends.
extends SceneTree

## The drawer: says where it is, then waits, and says so when it is ended.
const STAND_IN := """
import os, signal, sys, time
d = [a[len('--dir='):] for a in sys.argv if a.startswith('--dir=')][0]
quiet = os.open(os.devnull, os.O_RDWR)
for fd in (0, 1, 2):
    os.dup2(quiet, fd)
def ended(*_):
    open(os.path.join(d, 'drawer.ended'), 'w').write('TERM')
    sys.exit(0)
signal.signal(signal.SIGTERM, ended)
open(os.path.join(d, 'drawer.pid'), 'w').write(str(os.getpid()))
time.sleep(120)
"""

var _failures: int = 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--as-app"):
		_as_app()
	else:
		_run()


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return ""


## The app: one drawer started as a picture starts one, then waiting to be
## ended, as a tab waits on its session.
func _as_app() -> void:
	await process_frame
	var shots: LeasedShots = LeasedShots.shared()
	shots._dir = _arg("--dir")
	shots._start()
	while true:
		await create_timer(1.0).timeout


func _run() -> void:
	await process_frame
	if OS.get_name() != "Linux":
		print("drawer_ends probe: the bench's drawers run on Linux only")
		quit(3)
		return
	for way: String in ["TERM", "KILL"]:
		print("")
		print("an app ended by SIG%s to its group" % way)
		await _ended_by(way)
	print("")
	print("drawer_ends probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _ended_by(way: String) -> void:
	var dir: String = OS.get_user_data_dir().path_join("drawer_ends_" + way.to_lower())
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["drawer.pid", "drawer.ended"]:
		DirAccess.remove_absolute(dir.path_join(name))
	var words: Array = ["python3", "-I", "-c", STAND_IN]
	var app: int = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/drawer_ends_probe.gd",
		"--", "--as-app", "--dir=" + dir, LeasedShots.ARGUMENT + JSON.stringify(words)])
	var drawer: int = -1
	var until: int = Time.get_ticks_msec() + 120000
	while drawer < 0 and Time.get_ticks_msec() < until:
		await create_timer(0.25).timeout
		var said: String = FileAccess.get_file_as_string(dir.path_join("drawer.pid"))
		if said.is_valid_int():
			drawer = int(said)
	_check(drawer > 0, "the app started its drawer (pid %d)" % drawer)
	if drawer <= 0:
		OS.kill(app)
		return
	await create_timer(1.5).timeout
	_check(_alive(drawer) and _alive(app), "the drawer lives while the app does")
	_check(_parent(drawer) == app, "the app's own child (parent %d, app %d)" % [_parent(drawer), app])
	# As realset's _stop ends a tab: the app's group, which is the app's alone.
	var said: Array = []
	var code: int = OS.execute("/usr/bin/kill", ["-" + way, "--", "-%d" % app], said, true)
	_check(code == 0, "SIG%s sent to the app's group: %s" % [way, "".join(said).strip_edges()])
	until = Time.get_ticks_msec() + 10000
	while _alive(drawer) and Time.get_ticks_msec() < until:
		await create_timer(0.1).timeout
	_check(not _alive(app), "the app has ended")
	_check(not _alive(drawer), "the drawer ended with it")
	_check(FileAccess.file_exists(dir.path_join("drawer.ended")),
		"sent SIGTERM, so `gpu` leaves the lease's queue or stops the drawer it runs")
	for pid: int in [drawer, app]:
		if _alive(pid):
			OS.kill(pid)


## A process's /proc/PID/stat, or "" when there is none. Read a line at a time:
## /proc's files say they are empty, so get_file_as_string reads nothing.
func _stat(pid: int) -> String:
	var file: FileAccess = FileAccess.open("/proc/%d/stat" % pid, FileAccess.READ)
	return file.get_line() if file != null else ""


## Running: there, and not a zombie waiting for its parent.
func _alive(pid: int) -> bool:
	var stat: String = _stat(pid)
	return not stat.is_empty() and not stat.substr(stat.rfind(")") + 2).begins_with("Z")


## The process's parent: the field after its state, after the name's ")".
func _parent(pid: int) -> int:
	var stat: String = _stat(pid)
	var fields: PackedStringArray = stat.substr(stat.rfind(")") + 2).split(" ")
	return int(fields[1]) if not stat.is_empty() and fields.size() > 1 else -1


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
