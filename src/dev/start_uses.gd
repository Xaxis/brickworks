## Which of the first screen's scripts the start runs a line of, before a
## press: run under the script profiler, it boots the app as a first visit
## does, lets the window settle with nobody touching it, and quits, and the
## profiler's totals (printed at exit) name every function that ran.
##
##   gpu xvfb-run -a godot -d --profiling --ignore-error-breaks --path . \
##     --resolution 390x844 --script src/dev/start_uses.gd -- --phone > log
##   python3 tools/web/start_uses.py log
##
## A script of the first screen with no function in those totals is compiled
## at the start for a press that has not come (webstart12, 2026-11-19):
## tools/web/start_uses.py says which, and what each costs.
##
## It names no class of the app's: naming one would compile it here first.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--phone"):
		# As open_menu_reach_probe lays a phone out: Phone decides on the web only.
		(load("res://src/ui/phone.gd") as GDScript).set(&"_on", 1)
	var scene: PackedScene = load("res://src/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	var built: bool = false
	for _n: int in 1200:
		await process_frame
		if main.get("_shell") != null and bool(main.get("_built")):
			built = true
			break
	# The start's timers (the figures' index at 1 s, the bin's pictures) and
	# a few seconds of a window nobody touches.
	var settle_until: int = Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < settle_until:
		await process_frame
	print("start_uses: %s, %d parts drawn" % ["the window built" if built else "NOT BUILT",
		int((main.get("_world") as Object).call("brick_count")) if main.get("_world") != null else -1])
	# The totals, printed while the scripts are still loaded: at exit they
	# are gone first, and the profiler's own stop printed none.
	if EngineDebugger.is_profiling(&"scripts"):
		EngineDebugger.profiler_enable(&"scripts", false)
	else:
		print("start_uses: the script profiler is off (-d --profiling)")
	quit(0 if built else 1)
