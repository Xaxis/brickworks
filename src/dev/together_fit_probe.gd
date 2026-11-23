## Build together, in a session, inside the window it is in, laid out for a
## finger as a tablet held sideways is, and every control of it in sight.
##
##   godot --path . --resolution 1024x768 --script src/dev/together_fit_probe.gd
##   tools/probe.sh together_fit_probe
##   PROBE_SIZE=390x844 tools/probe.sh together_fit_probe    a phone (and 430x932, 768x1024)
##   ... -- --desktop    the desktop's layout, no finger
##   ... -- --shots=DIR  the window at each step
##
## dialogs_1024 on rel-m299: pointat put how to point a part out in its
## words, and the panel in a session ran 44 points past a 1024 x 768
## screen, its title and close button off the top. Here the panel is opened
## as More opens it, then grown by a session of this window's own
## (Together.check_alone, with Ann in it), and then:
##   its frame, title to foot, is inside the window;
##   its link's Copy, End the session, the chat's field and Send, and Close
##   are inside it and in sight, none scrolled out of its body;
##   on a finger, it says to hold a part to point it out, not a key or a
##   right-click; on a desktop, the key;
##   opened to watchers (buildlive), it is whole, with Copy watch link,
##   Close to watchers, End and Close in sight; End's row is under what
##   scrolls, so they stay in sight in any window from 1024 x 600 up
##   (buildfit: PROBE_SIZE=1152x648, 1280x720, 1024x600, and --desktop);
##   with the keyboard up for the chat (a finger's), the panel is above it,
##   and the field being typed in is in sight; the keyboard down, it is
##   whole again.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _step: int = 0
var _finger: bool = true


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
		elif arg == "--desktop":
			_finger = false
	var screen := DisplayServer.window_get_size()
	if _finger:
		Phone._on = 1
		Phone._wide = minf(screen.x, screen.y) >= Phone.NARROW
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var shell: Shell = null
	for _n: int in 900:
		await process_frame
		shell = _main.get("_shell")
		if shell != null and not (_main.get("_store") as ModelStore).laying:
			break
	if shell == null:
		print("  together_fit probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)
	var layout: String = ("a tablet's" if Phone.wide() else "a phone's") if _finger else "a desktop's"
	print("  a %d x %d window, laid out as %s" % [screen.x, screen.y, layout])

	_check("File, Build together… runs", shell.run("together"))
	await _frames(30)
	var dialog: TogetherDialog = _main.get("_together_dialog")
	_whole(dialog, "before a session")
	await _shot("before")
	var together: Together = _main.get("_together")
	together.check_alone([{"who": "a1b2c3d4", "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": [], "view": null}])
	await _frames(40)
	_whole(dialog, "in a session")
	_in_sight(dialog, ["together_copy", "together_end", "together_chat_field", "together_chat_send",
		"together_close"], "in a session")
	var note: String = str(dialog.page_state().get("note", ""))
	if _finger:
		_check("on a finger it says to hold a part to point it out, no key or right-click",
			note.contains("Hold a part to point it out to the others") and not note.contains("Alt")
			and not note.contains("right-click"))
	else:
		var key: String = Keymap.written("together_point")
		_check("on a desktop it says the key to point a part out (%s)" % key,
			not key.is_empty() and note.contains(key) and note.contains("right-click"))
	await _shot("session")

	# Open to watchers (buildlive): how many watch and Copy watch link on one
	# row, Close to watchers at the far end of End's row, and End in sight.
	_check("in a session of its own, as its designer", together.owns)
	together.watch = {"watch": "AbcdEfghIjkL", "link": "https://brickworks.diy/live/AbcdEfghIjkL", "watchers": 3}
	together.changed.emit()
	await _frames(40)
	_whole(dialog, "open to watchers")
	_in_sight(dialog, ["together_watch_copy", "together_watch_close", "together_end", "together_close"], "open to watchers")
	await _shot("watching")
	together.watch = {}
	together.changed.emit()
	await _frames(40)

	var touch := _main.get("_touch") as TouchSizing
	if _finger and touch != null:
		var field: LineEdit = dialog.controls_by_name()["together_chat_field"]
		field.grab_focus()
		touch.keyboard = roundf(screen.y * (0.38 if Phone.wide() else 0.4))
		touch._place_all()
		await _frames(40)
		var room: Rect2 = touch.room(dialog)
		_whole(dialog, "the keyboard up, %d points" % touch.keyboard, room)
		_in_sight(dialog, ["together_chat_field"], "the keyboard up", room)
		await _shot("keyboard")
		touch.keyboard = 0.0
		field.release_focus()
		touch._place_all()
		await _frames(40)
		_whole(dialog, "the keyboard down again")
		_in_sight(dialog, ["together_end", "together_close"], "the keyboard down again")

	print("")
	if _failures == 0:
		print("together_fit probe: all checks passed")
	else:
		print("together_fit probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The panel's frame, its title bar to its foot, inside [param room] (the
## window's, unless given).
func _whole(dialog: TogetherDialog, when: String, room: Rect2 = Rect2()) -> void:
	if room.size == Vector2.ZERO:
		room = root.get_visible_rect()
	var frame: Array[float] = TouchSizing.frame_of(dialog)
	var whole := Rect2(Vector2(dialog.position) - Vector2(frame[0], frame[1]),
		Vector2(dialog.size) + Vector2(frame[0] + frame[2], frame[1] + frame[3]))
	_check("%s: the panel open, its frame %s inside %s" % [when, _rect(whole), _rect(room)],
		dialog.visible and room.grow(0.5).encloses(whole))


## Each of [param names] inside [param room] and in sight in the panel's
## body: drawn where a finger can reach it, not scrolled away.
func _in_sight(dialog: TogetherDialog, names: Array, when: String, room: Rect2 = Rect2()) -> void:
	if room.size == Vector2.ZERO:
		room = root.get_visible_rect()
	var controls: Dictionary = dialog.controls_by_name()
	var body: ScrollContainer = dialog.get("_body")
	var shown: Rect2 = body.get_global_rect() if body != null else Rect2()
	# End's row is under the body, never scrolled (buildfit).
	var foot: Control = dialog.get("_end_row")
	var kept: Rect2 = foot.get_global_rect() if foot != null and foot.is_visible_in_tree() else Rect2()
	var at := Vector2(dialog.position)
	var out := PackedStringArray()
	for name: String in names:
		var control: Control = controls.get(name)
		if control == null or not control.is_visible_in_tree():
			out.append("%s not shown" % name)
			continue
		var box: Rect2 = control.get_global_rect()
		var inside_body: bool = name == "together_close" or shown.grow(0.5).encloses(box) \
			or (kept.has_area() and kept.grow(0.5).encloses(box))
		if not inside_body or not room.grow(0.5).encloses(Rect2(at + box.position, box.size)):
			out.append("%s at %s" % [name, _rect(Rect2(at + box.position, box.size))])
	_check("%s: %s in sight%s" % [when, ", ".join(PackedStringArray(names)),
		"" if out.is_empty() else " — not: " + "; ".join(out)], out.is_empty())


func _rect(box: Rect2) -> String:
	return "%d,%d %dx%d" % [roundi(box.position.x), roundi(box.position.y), roundi(box.size.x), roundi(box.size.y)]


func _shot(what: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	_step += 1
	root.get_texture().get_image().save_png(_shots.path_join("%d_%s.png" % [_step, what]))
