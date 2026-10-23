## A link to a step of a shared model (/app?view=<id>&step=<n>, as
## --view=<id> --step=<n>): the pill a comment on a step wears on the
## model's page (docs/SOCIAL.md U8) opens the viewer's step player at that
## step, not where this device last left the link.
##
##   godot --path . --resolution 1280x800 --script src/dev/step_link_probe.gd
##
## No network: api/share.js is played by a stand-in that answers with
## vendor/omr/files/8808-1.mpd, as share_play_probe's does. Two visits:
##
##   1. Asked for step 3: once the steps are worked out the step player is
##      open at page 3, with nothing pressed.
##   2. Asked for nothing: the viewer, not the step player (as before).
extends SceneTree

## One link a visit: the first visit's place is kept on this device.
const IDS := {3: "St3pL1nk01", 0: "St3pL1nk02"}
const SET := "res://vendor/omr/files/8808-1.mpd"

var _failures: int = 0


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var text: String = FileAccess.get_file_as_string(SET)
	if text.is_empty():
		print("step_link_probe: SKIPPED, no %s (tools/fetch_data.sh)" % SET)
		quit(3)
		return
	for asked: int in [3, 0]:
		print("\nthe link%s" % (", asked for step %d" % asked if asked > 0 else ", asked for no step"))
		var fake := FakeShared.new()
		var id: String = IDS[asked]
		fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Racer", "author": "Probe Builder",
			"parts": 93, "url": "https://brickworks.diy/m/" + id, "model": text}}
		var main: Node = load("res://src/main.tscn").instantiate()
		main.set("_viewing", id)
		main.set("_viewing_step", asked)
		main.set("_shared", fake)
		root.add_child(main)
		var view: ShareView = null
		for _n: int in 1200:
			await process_frame
			view = main.get("_share_view")
			if view != null and view.state in ["ready", "failed", "gone"]:
				break
		_ok(view != null and view.state == "ready", "the shared model opened (%s)" % (
			view.state if view != null else "no viewer"))
		var steps: StepsBar = main.get("_steps")
		var since: int = Time.get_ticks_msec()
		while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
			await process_frame
		var mode: BuildMode = main.get("_build_mode")
		for _n: int in 240:
			if mode != null and mode.is_open() and int(main.get("_build_page")) == asked:
				break
			await process_frame
		var page: int = int(main.get("_build_page"))
		if asked > 0:
			_ok(mode != null and mode.is_open() and page == asked,
				"the step player is open at page %d (%s, page %d)" % [asked,
					"open" if mode != null and mode.is_open() else "not open", page])
		else:
			_ok(mode != null and not mode.is_open(), "the viewer, not the step player (%s)" % (
				"open" if mode != null and mode.is_open() else "not open"))
		main.queue_free()
		await process_frame
		await process_frame
	print("\nstep_link_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
