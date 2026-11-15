## Find and Replace reaches every sub-model, in one undo, by the bar and by a
## session's replace_parts (swapfind, APP_UX8 #9).
##
##   godot --headless --path . --script src/dev/swapfind_probe.gd
##
## The car (models/car.ldr in sub-models: each side one Side, the left placed
## by a mirror, its sill a Sill inside it; each axle an Axle of two Wheels,
## src/dev/fixtures/swapfind_car.mpd) and its every Black 3023, in the model
## and its sub-models, made Dark Bluish Grey from the bar in one action: the
## bar lists where they are and the copies it changes, the save opens again
## as it was shown with each sub-model written once, one undo gives back the
## save before it byte for byte, and a redo the save after it. replace_parts
## in one call gives the bar's file. And the attacks a writer of the model
## file meets: a part used in two colours flagged; a replace inside a
## mirrored copy (a handed door, its other hand in the mirror); a sub-model
## placed 3 times, nested 2 deep; a printed part for a plain one, in place; a
## part of another footprint and one of other connection points, said before;
## CRLF and tabs; a file as live saves it, replaced and read back as live
## reads it (LIVE_SAVED, LIVE_READ: files tools/release/live_ab.sh wrote, or
## the cases skip saying so); undo then redo; a replace while a Build together
## room is open; and the words in German, French and Spanish. The car is the
## app's own save of it, so it opens and saves to the byte (copyorder's S2),
## and every undo is held to the save before the replace, to the byte.
##
##   SWAPFIND_CASES=car,mcp   those cases
extends "res://src/dev/copyfaults_probe.gd"

const FIND_CASES: Array = ["car", "mcp", "two_colours", "mirror", "three_deep", "printed",
	"footprint", "crlf", "live", "together", "words"]
const CAR := "swapfind_car.mpd"
const BLACK := 0
const DARK_BLUISH_GREY := 72

var _bar: PanelContainer = null


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1500.0).timeout.connect(func() -> void:
		print("swapfind probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var cases: Array = FIND_CASES if OS.get_environment("SWAPFIND_CASES").is_empty() \
		else Array(OS.get_environment("SWAPFIND_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"car": await _case_car()
			"mcp": await _case_mcp()
			"two_colours": await _case_two_colours()
			"mirror": await _case_mirror()
			"three_deep": await _case_three_deep()
			"printed": await _case_printed()
			"footprint": await _case_footprint()
			"crlf": await _case_crlf()
			"live": await _case_live()
			"together": await _case_together()
			"words": await _case_words()
			_: _check("no such case %s" % name, false)
	print("\nswapfind probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the bar ------------------------------------------------------------------------


## Edit › Find and replace…, as the menu runs it, over [param text] opened.
func _bar_on(text: String) -> PanelContainer:
	await _open(text)
	_builder.clear_selection()
	_shell.run("find_replace")
	await _frames(4)
	_bar = _main.get("_find_replace_made")
	return _bar


## The bar's words as a person reads them: every line of its list and notes.
func _bar_said() -> String:
	var said := PackedStringArray()
	for control: Control in _shown_in_bar():
		if control is Label:
			said.append((control as Label).text)
		elif control is Button and not control is OptionButton:
			said.append("[%s]" % (control as Button).text)
	return " | ".join(said)


## The bar's controls on screen now: not those a list filled afresh has let
## go of this frame.
func _shown_in_bar() -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in _bar.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and not _going(control):
			out.append(control)
	return out


func _going(node: Node) -> bool:
	while node != null and node != _bar:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false


## Parts of [param part]'s number, any letter of it (3023 is 3023b once
## the library has read it), in [param colour].
func _count(part: String, colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if (brick.part_id == part or brick.part_id.trim_suffix(brick.part_id.right(1)) == part
				and not brick.part_id.right(1).is_valid_int()) \
				and brick.color_code == colour and not _store.scenery.has(brick.id):
			count += 1
	return count


func _defined(text: String, file: String) -> int:
	return text.count("0 FILE %s" % file)


## The undo, then the save as it stands.
func _undone() -> String:
	_shell.run("undo")
	await _frames(6)
	return _save()


## The car's every Black 3023, everywhere, made Dark Bluish Grey from the bar
## in one action; its save opened again; one undo the save before, to the
## byte; a redo the save after.
func _case_car() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	if not _check("Edit › Find and replace… opens the bar", _bar != null and _bar.visible):
		return
	var before: String = _save()
	_check("car: the app's own file, opened and saved, to the byte (%s)" % _diff(text, before),
		before == text)
	var black: int = _count("3023b", BLACK)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("set_where", "all")
	_bar.call("refresh")
	var found: Dictionary = _bar.get("found")
	var said: String = _bar_said()
	print("  bar: %s" % said)
	_check("car: 4 Black 3023 found, 2 in the model's own parts and 2 in Sill's 2 copies (%d)"
		% (found["ids"] as Array).size(), (found["ids"] as Array).size() == 4 and black == 4
		and said.contains("The model's own parts: 2") and said.contains("Sill: 1 in each of 2 copies"))
	_check("car: ...it says the copies it changes", said.contains("Changes all 2 copies of Sill"))
	_check("car: ...and nothing about a fit, for a colour", not said.contains("sit the same"))
	var depth: int = _builder.history_depth()
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(4)
	_check("car: replaced in one action, one undo step (%s; %d steps)" % [done,
		_builder.history_depth() - depth], int(done.get("changed", 0)) == 4
		and _builder.history_depth() == depth + 1)
	_check("car: no Black 3023 left, 4 Dark Bluish Grey (%d, %d)" % [_count("3023b", BLACK),
		_count("3023b", DARK_BLUISH_GREY)], _count("3023b", BLACK) == 0
		and _count("3023b", DARK_BLUISH_GREY) == 4)
	var after: String = _save()
	print("  saved: %s" % _diff(before, after))
	_check("car: each sub-model written once (Side %d, Wheel %d, Axle %d; Sill's parts in Side %d)"
		% [_defined(after, "side.ldr"), _defined(after, "wheel.ldr"), _defined(after, "axle.ldr"),
			after.count("IN Sill#1")], _defined(after, "side.ldr") == 1
		and _defined(after, "wheel.ldr") == 1 and _defined(after, "axle.ldr") == 1
		and after.count("IN Sill#1") == before.count("IN Sill#1"))
	_check("car: ...the sill's line Dark Bluish Grey, and only those 3 lines changed (%d)"
		% _minus(after, before).size(), after.contains("1 72 30 -64 40 0 0 1 0 1 0 -1 0 0 3023b.dat")
		and _minus(after, before).size() == 3 and _minus(before, after).size() == 3)
	var shown: Array = _looks()
	await _open(after)
	_check("car: opened again, every part as it was shown%s" % _unlike(shown, _looks()),
		shown == _looks())
	await _open(text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	await _frames(4)
	var undone: String = await _undone()
	_check("car: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)
	_shell.run("redo")
	await _frames(4)
	var redone: String = _save()
	_check("car: a redo, the save after to the byte (%s)" % _diff(after, redone), redone == after)


## replace_parts in one call: the bar's file.
func _case_mcp() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	await _frames(4)
	var by_bar: String = _save()
	await _open(text)
	var before: String = _save()
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"find": {"part": "3023", "color": BLACK},
		"replace": {"color": DARK_BLUISH_GREY}, "where": "all"})
	print("  replace_parts: %s" % said.replace("\n", " / "))
	var by_call: String = _save()
	_check("mcp: replace_parts in 1 call gives the bar's file (%s)" % _diff(by_bar, by_call),
		by_call == by_bar)
	_check("mcp: ...as one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_check("mcp: ...its answer lists where and the copies changed",
		said.contains("2 in the model's own parts") and said.contains("2 in Sill (2 copies, 1 each)")
		and said.contains("changes all 2 copies of Sill") and said.contains("Replaced 4"))
	var undone: String = await _say("undo", {})
	_check("mcp: its undo, the save before to the byte (%s)" % undone.get_slice("\n", 0).left(80),
		_save() == before)
	var preview: String = await _say("replace_parts", {"find": {"part": "3023b"},
		"replace": {"part": "3794b"}, "preview": true})
	print("  preview: %s" % preview.replace("\n", " / "))
	_check("mcp: preview changes nothing and says the fit first", _save() == before
		and preview.contains("Nothing changed") and preview.contains("won't sit the same"))


## A part used in two colours is flagged, before a replace.
func _case_two_colours() -> void:
	await _bar_on(_fixture(CAR))
	_bar.call("set_find", "3023", -1)
	_bar.call("set_into", "3794b", -1)
	_bar.call("refresh")
	var said: String = _bar_said()
	print("  bar: %s" % said)
	var found: Dictionary = _bar.get("found")
	_check("two_colours: 3023 in Black and Red, flagged (%s)" % JSON.stringify(found["colours"]),
		(found["colours"] as Dictionary).size() == 2 and said.contains("Used in 2 colours: each keeps its own"))
	_check("two_colours: ...each colour listed with its count", said.contains("Black: 4")
		and said.contains("Red: 4"))
	var answer: String = await _say("replace_parts", {"find": {"part": "3023"}, "preview": true})
	_check("two_colours: replace_parts says it too", answer.contains("used in 2 colours"))


## A replace inside a mirrored copy. The car's right side has a right door
## (3822); its left side is the same Side placed by a mirror, so its door is
## seen as the left one (3821), and is found as that. The right door made a
## left one: the right side's 3821 and, the copies following, the mirrored
## left side's 3822, Side written once with the one line changed. And the
## same asked from the other side: the left door (3821, in the mirrored
## copy, its twin not found) made a right one changes it there, the right
## side following with the other hand: the same file.
func _case_mirror() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	_bar.call("set_find", "3822", -1)
	_bar.call("set_into", "3821", -1)
	_bar.call("refresh")
	var found: Dictionary = _bar.get("found")
	_check("mirror: 3822 found once, the right side's: the mirrored side's door is seen as 3821 (%d, %d mirrored)"
		% [(found["ids"] as Array).size(), (found["mirrored"] as Dictionary).size()],
		(found["ids"] as Array).size() == 1 and (found["mirrored"] as Dictionary).is_empty()
		and not _left_of("3822"))
	var done: Dictionary = await _bar.call("replace_now")
	await _frames(4)
	_check("mirror: the right side's 3821, the mirrored left's 3822 (%s; %d, %d)"
		% [done, _count("3821", 4), _count("3822", 4)], int(done.get("changed", 0)) == 1
		and _count("3821", 4) == 1 and _count("3822", 4) == 1 and _left_of("3822")
		and not _left_of("3821"))
	var after: String = _save()
	print("  saved: %s" % _diff(before, after))
	_check("mirror: Side written once, its one line the 3821", _defined(after, "side.ldr") == 1
		and after.contains("1 4 30 -56 -30 1 0 0 0 1 0 0 0 1 3821.dat")
		and _minus(after, before).size() == 1)
	var shown: Array = _looks()
	await _open(after)
	_check("mirror: opened again as shown%s" % _unlike(shown, _looks()), shown == _looks())
	await _open(text)
	_bar.call("set_find", "3822", -1)
	_bar.call("set_into", "3821", -1)
	_bar.call("refresh")
	await _bar.call("replace_now")
	var undone: String = await _undone()
	_check("mirror: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)
	_shell.run("redo")
	await _frames(6)
	_check("mirror: a redo, the save after to the byte", _save() == after)
	await _open(text)
	_bar.call("set_find", "3821", -1)
	_bar.call("set_into", "3822", -1)
	_bar.call("refresh")
	found = _bar.get("found")
	_check("mirror: 3821 found once, in the mirrored copy (%d, %d mirrored)" % [
		(found["ids"] as Array).size(), (found["mirrored"] as Dictionary).size()],
		(found["ids"] as Array).size() == 1 and (found["mirrored"] as Dictionary).size() == 1)
	_check("mirror: ...and the bar says both copies of Side change", _bar_said().contains(
		"Changes all 2 copies of Side"))
	await _bar.call("replace_now")
	await _frames(4)
	var other_way: String = _save()
	_check("mirror: the left door made a right one, the right side following: the same file (%s)"
		% _diff(after, other_way), other_way == after)
	undone = await _undone()
	_check("mirror: its undo, the save before to the byte", undone == before)


## Whether the [param part] is on the car's left (x < 0).
func _left_of(part: String) -> bool:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.transform.origin.x < 0.0
	return false


## A sub-model placed 3 times, nested 2 deep: the cap of each post.
func _case_three_deep() -> void:
	var text: String = ("0 FILE posts.mpd\n0 Posts\n0 Name: posts.mpd\n0 Author: Brickworks\n"
		+ "1 16 0 0 0 1 0 0 0 1 0 0 0 1 post.ldr\n1 16 60 0 0 1 0 0 0 1 0 0 0 1 post.ldr\n"
		+ "1 16 120 0 0 1 0 0 0 1 0 0 0 1 post.ldr\n0 NOFILE\n"
		+ "0 FILE post.ldr\n0 Post\n0 Name: post.ldr\n0 Author: Brickworks\n"
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\n1 16 0 -24 0 1 0 0 0 1 0 0 0 1 cap.ldr\n0 NOFILE\n"
		+ "0 FILE cap.ldr\n0 Cap\n0 Name: cap.ldr\n0 Author: Brickworks\n"
		+ "1 0 0 -8 0 1 0 0 0 1 0 0 0 1 3023.dat\n0 NOFILE\n")
	await _bar_on(text)
	var before: String = _save()
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	var said: String = _bar_said()
	_check("three_deep: Cap's 3023 in each of 3 copies (%s)" % said,
		said.contains("Cap: 1 in each of 3 copies") and said.contains("Changes all 3 copies of Cap"))
	await _bar.call("replace_now")
	await _frames(4)
	var after: String = _save()
	print("  saved: %s" % _diff(before, after))
	_check("three_deep: 3 Dark Bluish Grey (%d), Post written once, Cap's one line changed (%d)"
		% [_count("3023", DARK_BLUISH_GREY), _minus(after, before).size()],
		_count("3023", DARK_BLUISH_GREY) == 3 and _count("3023", BLACK) == 0
		and _defined(after, "post.ldr") == 1 and _minus(after, before).size() == 1
		and str(_minus(after, before)[0]).begins_with("1 72 "))
	var shown: Array = _looks()
	await _open(after)
	_check("three_deep: opened again as shown", shown == _looks())
	await _open(text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	var undone: String = await _undone()
	_check("three_deep: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)


## A printed part for a plain one: where it stood, and nothing said of a fit.
func _case_printed() -> void:
	var prints: Array = _library.prints_of("3068b")
	if not _check("printed: 3068b has printed versions (%d)" % prints.size(), not prints.is_empty()):
		return
	var printed: String = (prints[0] as PartLibrary.PartInfo).id
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var tile: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3068b":
			tile = brick
	var was: Transform3D = tile.transform
	_bar.call("set_find", "3068b", -1)
	_bar.call("set_into", printed, -1)
	_bar.call("refresh")
	var said: String = _bar_said()
	_check("printed: %s sits as 3068b, nothing said of a fit (%s)" % [printed, said],
		not said.contains("sit the same") and not said.contains("no room"))
	await _bar.call("replace_now")
	await _frames(4)
	var now: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == printed:
			now = brick
	_check("printed: put exactly where the plain one stood", now != null
		and now.transform.is_equal_approx(was) and now.color_code == 4)
	var after: String = _save()
	await _open(after)
	_check("printed: opened again, the printed tile there", _count(printed, 4) == 1)
	await _open(text)
	_bar.call("set_find", "3068b", -1)
	_bar.call("set_into", printed, -1)
	_bar.call("refresh")
	await _bar.call("replace_now")
	var undone: String = await _undone()
	_check("printed: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)


## A part of another footprint (a 1 x 3 for a 1 x 2) and one of other
## connection points (a jumper for a 1 x 2) said before, how many places.
func _case_footprint() -> void:
	var text: String = _fixture(CAR)
	for into: String in ["3623", "3794b"]:
		await _bar_on(text)
		var before: String = _save()
		_bar.call("set_find", "3023", BLACK)
		_bar.call("set_into", into, -1)
		_bar.call("refresh")
		var said: String = _bar_said()
		print("  %s: %s" % [into, said])
		var made: Dictionary = _bar.get("made")
		var otherwise: int = (made.get("otherwise", []) as Array).size()
		var room: int = (made.get("room", []) as Array).size()
		_check("footprint %s: said before, %d places won't sit the same, %d have no room"
			% [into, otherwise, room], otherwise + room > 0 and (said.contains("sit the same")
				or said.contains("no room")))
		var done: Dictionary = await _bar.call("replace_now")
		await _frames(4)
		var put: int = _count(into, BLACK)
		_check("footprint %s: those with room put down (%d), those without left (%d), as said"
			% [into, put, _count("3023b", BLACK)], put == int(done.get("changed", 0))
			and put + _count("3023b", BLACK) == 4 and _count("3023b", BLACK) >= room)
		var floats: int = (made.get("floats", []) as Array).size()
		_check("footprint %s: none put down floating unsaid (%d said)" % [into, floats],
			floats == 0 or said.contains("hold onto nothing"))
		var undone: String = await _undone()
		_check("footprint %s: one undo, the save before to the byte (%s)" % [into,
			_diff(before, undone)], undone == before)


## CRLF and tabs: the replace's save keeps CRLF on every line, and its undo
## gives the file to the byte.
func _case_crlf() -> void:
	var text: String = _fixture(CAR).replace("\n", "\r\n").replace("1 0 30 -40 -80", "1\t0\t30 -40 -80")
	await _bar_on(text)
	var before: String = _save()
	_check("crlf: opened and saved, to the byte", before == text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	await _frames(4)
	var after: String = _save()
	_check("crlf: replaced, every line still CRLF (%d of %d)" % [after.count("\r\n"),
		after.count("\n")], after.count("\r\n") == after.count("\n") and after != before
		and _count("3023b", DARK_BLUISH_GREY) == 4)
	var undone: String = await _undone()
	_check("crlf: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)


## A file as live saves it (LIVE_SAVED: the car opened and saved by live,
## tools/release/live_ab.sh): replaced here, and our save as live reads it
## back (LIVE_READ: live's save of ours), every part where it was.
func _case_live() -> void:
	var saved: String = OS.get_environment("LIVE_SAVED")
	if saved.is_empty() or not FileAccess.file_exists(saved):
		print("  live: LIVE_SAVED not given, skipped")
		return
	var text: String = FileAccess.get_file_as_string(saved)
	await _bar_on(text)
	var before: String = _save()
	_check("live: live's save opened and saved, to the byte (%s)" % _diff(text, before),
		before == text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	await _frames(4)
	_check("live: replaced, 4 Dark Bluish Grey", _count("3023b", DARK_BLUISH_GREY) == 4)
	var ours: String = _save()
	var out: String = OS.get_environment("LIVE_OURS")
	if not out.is_empty():
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(ours)
		file.close()
	var shown: Array = _looks()
	var read: String = OS.get_environment("LIVE_READ")
	if not read.is_empty() and FileAccess.file_exists(read):
		await _open(FileAccess.get_file_as_string(read))
		_check("live: ours as live saves it back, opened here as shown%s" % _unlike(shown,
			_looks()), shown == _looks())
	await _open(text)
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	var undone: String = await _undone()
	_check("live: one undo, the save before to the byte (%s)" % _diff(before, undone),
		undone == before)


## A replace while a Build together room is open (Together.check_alone: this
## window in a session of its own, Ann in it, no server): the 4 parts it
## changed sent to the room, each the new colour where it was, and nothing
## else; the session's undo (each person undoes their own) takes the whole
## replace back in one and sends that, and the save is the one before.
func _case_together() -> void:
	var text: String = _fixture(CAR)
	await _bar_on(text)
	var before: String = _save()
	var together: Together = _main.get("_together")
	together.check_alone([{"who": "a11ce000", "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": [], "view": null}])
	await _frames(10)
	var waiting: int = together.waiting()
	_bar.call("set_find", "3023", BLACK)
	_bar.call("set_into", "", DARK_BLUISH_GREY)
	_bar.call("refresh")
	await _bar.call("replace_now")
	await _frames(10)
	var sent: Dictionary = _sent_since(together, waiting)
	var greys: int = 0
	for uid: String in sent:
		if sent[uid] is Array and int((sent[uid] as Array)[1]) == DARK_BLUISH_GREY:
			greys += 1
	_check("together: the replace sent to the room, its 4 parts Dark Bluish Grey and nothing else (%d sent, %d grey)"
		% [sent.size(), greys], sent.size() == 4 and greys == 4)
	var after_replace: int = together.waiting()
	_shell.run("undo")
	await _frames(10)
	var undone: String = _save()
	var back: Dictionary = _sent_since(together, after_replace)
	var blacks: int = 0
	for uid: String in back:
		if back[uid] is Array and int((back[uid] as Array)[1]) == BLACK:
			blacks += 1
	_check("together: one undo takes the whole replace back (%s), and sends it (%d sent, %d Black)"
		% [_diff(before, undone), back.size(), blacks], undone == before and back.size() == 4
		and blacks == 4)
	together._stop("")
	await _frames(6)


## Each part's state the session was sent after its first [param from]
## waiting changes, by uid, the last one for each.
func _sent_since(together: Together, from: int) -> Dictionary:
	var out: Dictionary = {}
	var pending: Array = together.get("_pending")
	for n: int in range(from, pending.size()):
		var changes: Dictionary = (pending[n] as Dictionary)["changes"]
		for uid: String in changes:
			if not uid.begins_with("~"):
				out[uid] = changes[uid]
	return out


## Every word the bar shows, its menu row and its tooltip, in German, French
## and Spanish: each with its entry, none left in English but a number or a
## sub-model's name. (Its status line is the app's own kind, in English as
## "swapped %s for %s" is.)
func _case_words() -> void:
	await _bar_on(_fixture(CAR))
	var texts: Array = ["Type a part's number or name, or choose a colour, to find it.",
		"Nothing like that here", "Only locked parts are like that: unlock them to change them",
		"In the model's own parts", "In Side and its copies", "In the selection",
		"2 found in the selection", "2 found in the model's own parts", "2 found in Side and its copies",
		"Sill: 2", "Sill: 3 in 2 copies", "Used in 2 colours: all will be Dark Bluish Grey",
		"3 would hold onto nothing", "1 have no room and stay as they are"]
	_bar.call("set_find", "3023", -1)
	_bar.call("set_into", "3623", DARK_BLUISH_GREY)
	_bar.call("refresh")
	for node: Control in _shown_in_bar():
		if node is Label and not (node as Label).text.is_empty():
			texts.append_array((node as Label).text.split("\n"))
		elif node is Button and not node is OptionButton and not (node as Button).text.is_empty():
			texts.append((node as Button).text)
		if not (node as Control).tooltip_text.is_empty():
			texts.append((node as Control).tooltip_text)
		if node is LineEdit:
			texts.append((node as LineEdit).placeholder_text)
		if node is OptionButton:
			texts.append((node as OptionButton).get_item_text(0))
	var command: Shell.Command = _shell.command("find_replace")
	texts.append(command.words)
	texts.append(command.tip)
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		var drawn: Array = []
		for english: String in texts:
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				var rest: String = str(w)
				for mark: String in "0123456789½¼¾−-.,:×bx ":
					rest = rest.replace(mark, "")
				return not rest.is_empty() and str(w) != "Side" and str(w) != "Sill")
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english, " (kept " + str(kept) + ")"
					if not kept.is_empty() else ""])
			drawn.append(TranslationServer.translate(english))
		print("  %s: %s" % [code, " | ".join(drawn.slice(0, 5))])
		_check("words %s: each of the %d reads in the language%s" % [code, texts.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty())
	Language.apply("en")
