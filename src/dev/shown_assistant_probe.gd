## With the assistant shown, its panel and Claude's connector are made as the
## window starts, whether or not a frame is ever drawn.
##
##   godot --headless --path . --script src/dev/shown_assistant_probe.gd
##
## The panel waits for the window's first frame drawn (Later: its code held
## the window back for everybody). Headless no frame is drawn, and
## RenderingServer.frame_post_draw never fires, so the relay bench's tab
## (tools/bench/realset.py --via relay: --assistant=on --signed-in) never made
## its connector: every design of d8surf-smoke ended "the tab never switched
## its connector on" (2026-11-01). Nothing here asks for either.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# As --assistant=on leaves it (main._assistant_from_address), in this
	# run's own data folder.
	ShellPrefs.put("assistant", "on")
	var main: Node = (load("res://src/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var frames: int = 0
	for _n: int in 600:
		await process_frame
		frames += 1
		if bool(main.get("_built")) and main.get("_connector_made") != null:
			break
	_check("the window built, %s, %d frames in" % [DisplayServer.get_name(), frames],
		bool(main.get("_built")))
	_check("the assistant's panel made with nothing asking for it",
		main.get("_chat_made") != null)
	var connector: Node = main.get("_connector_made")
	_check("and Claude's connector with it, in the tree",
		connector != null and connector.is_inside_tree())
	print("")
	print("shown assistant: its panel and connector made as the window starts"
		if _failures == 0 else "shown assistant: %d FAILED" % _failures)
	main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
