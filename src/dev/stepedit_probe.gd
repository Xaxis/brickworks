## In the steps view an edit reaches only what the step shows (stepedit).
##
##   godot --path . --resolution 1280x720 --script src/dev/stepedit_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh stepedit_probe     the desktop's layout
##   PROBE_SIZE=390x844 tools/probe.sh stepedit_probe      a phone's
##
## appwalk opened a set's own version (346-2) from the set fan, built along
## its steps, and at step 5 clicked the house: 72 of the model's 165 parts
## were on, the click took the whole House sub-model, 149 parts, and a colour
## then painted all 149, the later steps' parts the person had never seen
## too. Studio and LDCad edit at a step only what it shows. Here, 346-2
## opened from its file, the timeline in its author's steps at step 5:
##   A. a click (a phone's tap) on a part of the house takes its parts on
##      show, none of a later step, and the line says how many of how many;
##      a colour paints those alone, in one undo that puts every colour back;
##      saved and opened again, part by part: those painted, every other part
##      as it was, in place and colour;
##   B. Select all takes the parts on show and says how many later ones it
##      left out; Delete takes those alone, Undo puts them back, every part
##      where it was; Select all again takes every step, the timeline at its
##      end; the delete redone, saved and opened again, part by part: the
##      later steps' parts and nothing else;
##   C. a session's edit over the connector (edit_model, mirror_parts,
##      replace_parts) that names a part of a later step is refused before
##      anything changes, says which, and offers all_steps; one of a part on
##      show is made and undone exactly; all_steps: true makes it, saved and
##      opened again part by part.
## Pictures in shots/stepedit/. Exits non-zero when a check fails.
extends "res://src/dev/grabselect_probe.gd"

const SET := "res://vendor/omr/files/346-2.mpd"
const SHOTS2 := "res://shots/stepedit/"
## A colour none of the house's parts is: Bright Green.
const PAINT := 10

var _store: ModelStore
var _steps: StepsBar
var _shell: Shell
var _bar: ModelBar
var _socket: CommandSocket
var _rpc: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("stepedit_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if _layout == "phone":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	print("stepedit_probe: a %s window, laid out for a %s" % [_size, _layout])
	await _paint_the_house()
	await _select_all_and_delete()
	await _a_sessions_edit()
	print("\nstepedit_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- A. the house, clicked and painted ---------------------------------------


func _paint_the_house() -> void:
	print("\nA. a %s on the house at step 5, and a colour" % ("tap" if _layout == "phone" else "click"))
	if not await _at_step_5():
		return
	var before: Dictionary = _by_id()
	var house: Array = _house_part()
	if not _check("a part of a sub-assembly with later steps' parts is under a point (%s)" % [house],
			not house.is_empty()):
		return
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var all_of: PackedInt64Array = _verbs.assemblies.ids_under(unit)
	var on_show: Array = Array(all_of).filter(func(id: int) -> bool: return not _ahead(id))
	print("  %s: %d parts, %d on at step 5" % [unit, all_of.size(), on_show.size()])
	await _press_at(house[1])
	var chosen: Array = _builder.selection.keys()
	var later: int = chosen.filter(func(id: int) -> bool: return _ahead(id)).size()
	_check("...it takes the parts of %s on show (%d selected, %d of them on show), none of a later step (%d)"
		% [Assemblies.label(unit), chosen.size(), on_show.size(), later],
		chosen.size() == on_show.size() and later == 0 and on_show.size() < all_of.size())
	var line: String = _line()
	var of: String = "%d of its %d parts on at this step" % [on_show.size(), all_of.size()]
	_check("...and the line says how many of how many: \"%s\"" % line, line.contains(of))
	await _pic("A1_house_selected")
	var depth: int = _builder.history_depth()
	_builder.held_color = PAINT
	await _verbs.press("paint")
	await _frames(6)
	var after: Dictionary = _by_id()
	var painted: Array = _changed(before, after)
	var wrong: Array = painted.filter(func(id: int) -> bool: return not on_show.has(id))
	_check("a colour paints the %d on show and nothing else (painted %d, %d of them not on show)"
		% [on_show.size(), painted.size(), wrong.size()],
		painted.size() == on_show.size() and wrong.is_empty())
	_check("...every later step's part keeps its colour (%d of %d)" % [
		_kept(before, after, all_of), all_of.size() - on_show.size()],
		_kept(before, after, all_of) == all_of.size() - on_show.size())
	await _pic("A2_painted")
	await _verbs.press("undo")
	await _frames(6)
	_check("...one undo (%d steps, was %d) puts every colour back, part by part (%d differ)"
		% [_builder.history_depth(), depth, _changed(before, _by_id()).size()],
		_builder.history_depth() == depth and _changed(before, _by_id()).is_empty())
	await _verbs.press("redo")
	await _frames(6)
	var wanted: Array = _parts_of(_by_id())
	await _saved_and_opened("stepedit paint %s" % _size, wanted, "A")


# -- B. select all, delete -----------------------------------------------------


func _select_all_and_delete() -> void:
	print("\nB. Select all at step 5, and Delete")
	if not await _at_step_5():
		return
	var before: Dictionary = _by_id()
	var on_show: Array = before.keys().filter(func(id: int) -> bool:
		return not _ahead(id) and not _store.scenery.has(id))
	var later_parts: int = before.size() - on_show.size() - _store.scenery.size()
	_shell.run("select_all")
	await _frames(8)
	var chosen: Array = _builder.selection.keys()
	_check("Select all takes the %d parts on show (%d selected, %d of a later step)"
		% [on_show.size(), chosen.size(), chosen.filter(func(id: int) -> bool: return _ahead(id)).size()],
		chosen.size() == on_show.size() and not chosen.any(func(id: int) -> bool: return _ahead(id)))
	var said: String = _said()
	_check("...and says it left out the %d of later steps, and how to take every step: \"%s\""
		% [later_parts, said], said.contains("%d more in later steps are left out" % later_parts)
			and said.contains("Select all again takes every step"))
	await _pic("B1_select_all")
	var depth: int = _builder.history_depth()
	_shell.run("delete")
	await _until(func() -> bool: return _builder.history_depth() > depth)
	var after: Dictionary = _by_id()
	var gone: Array = before.keys().filter(func(id: int) -> bool: return not after.has(id))
	_check("Delete takes the %d on show and nothing else (%d gone, %d of them not on show)"
		% [on_show.size(), gone.size(), gone.filter(func(id: int) -> bool: return not on_show.has(id)).size()],
		gone.size() == on_show.size() and gone.all(func(id: int) -> bool: return on_show.has(id)))
	_check("...every later step's part where it was, in its colour (%d of %d)" % [
		_kept(before, after, PackedInt64Array(before.keys())) , later_parts + _store.scenery.size()],
		_kept(before, after, PackedInt64Array(before.keys())) == later_parts + _store.scenery.size())
	await _pic("B2_deleted")
	await _verbs.press("undo")
	await _until(func() -> bool: return _builder.history_depth() == depth)
	_check("...one undo puts every part back where it was (%d steps, was %d; the model %s)"
		% [_builder.history_depth(), depth,
			"as it was" if _parts_of(_by_id()) == _parts_of(before) else "different"],
		_builder.history_depth() == depth and _parts_of(_by_id()) == _parts_of(before))
	# Select all again: every step, the timeline at its end.
	if not await _at_step_5(false):
		return
	_shell.run("select_all")
	await _frames(6)
	_shell.run("select_all")
	await _frames(10)
	var at: Vector2i = _steps.timeline_at()
	_check("Select all again takes every step: %d of %d selected, the timeline at its end (%d of %d)"
		% [_builder.selection.size(), before.size() - _store.scenery.size(), at.x, at.y],
		_builder.selection.size() == before.size() - _store.scenery.size() and at.x == at.y)
	await _pic("B3_every_step")
	_builder.clear_selection()
	# The delete at step 5 again, kept: saved and opened again.
	if not await _at_step_5(false):
		return
	_shell.run("select_all")
	await _frames(6)
	depth = _builder.history_depth()
	_shell.run("delete")
	await _until(func() -> bool: return _builder.history_depth() > depth)
	var kept: Array = _parts_of(_by_id())
	_check("B: the delete kept, %d parts are left, the later steps' (%d) and the scenery (%d)"
		% [kept.size(), later_parts, _store.scenery.size()],
		kept.size() == later_parts + _store.scenery.size())
	await _saved_and_opened("stepedit delete %s" % _size, kept, "B")


# -- C. a session's edit -------------------------------------------------------


func _a_sessions_edit() -> void:
	print("\nC. a session's edit over the connector at step 5")
	if not await _at_step_5():
		return
	var before: Dictionary = _by_id()
	var shown: int = 0
	var later: int = 0
	for id: int in before:
		if _store.scenery.has(id) or (before[id] as Array)[1] == PAINT:
			continue
		if _ahead(id) and later == 0:
			later = id
		elif not _ahead(id) and shown == 0:
			shown = id
	if not _check("a part on show (#%d) and one of a later step (#%d)" % [shown, later],
			shown != 0 and later != 0):
		return
	var depth: int = _builder.history_depth()
	var said: String = await _call("edit_model", {"recolor": [{"bricks": [shown, later], "color": PAINT}],
		"picture": false})
	_check("edit_model naming a later step's part is refused, naming it and offering all_steps: %s"
		% said.left(300), said.begins_with("Not applied") and said.contains("#%d" % later)
			and not said.contains("#%d," % shown) and said.contains("all_steps"))
	_check("...and nothing changed (%d differ, %d undo steps more)" % [_changed(before, _by_id()).size(),
		_builder.history_depth() - depth],
		_changed(before, _by_id()).is_empty() and _builder.history_depth() == depth)
	said = await _call("edit_model", {"recolor": [{"bricks": [shown, later], "color": PAINT}],
		"picture": false, "all_steps": false})
	_check("...all_steps: false is as if not sent: refused (%s)" % said.left(60),
		said.begins_with("Not applied") and _changed(before, _by_id()).is_empty())
	said = await _call("mirror_parts", {"bricks": [later], "picture": false})
	_check("mirror_parts of a later step's part is refused, nothing changed: %s" % said.left(160),
		said.begins_with("Not applied") and _changed(before, _by_id()).is_empty())
	var part: String = (before[later] as Array)[0]
	said = await _call("replace_parts", {"find": {"part": part}, "preview": true})
	_check("replace_parts finds the parts on show and counts the later ones left out: %s" % said.left(240),
		said.contains("in later steps left out") and said.contains("all_steps"))
	said = await _call("edit_model", {"recolor": [{"bricks": [shown], "color": PAINT}], "picture": false})
	var changed: Array = _changed(before, _by_id())
	_check("edit_model of a part on show is made (%s): %s" % [changed, said.left(80)], changed == [shown])
	await _verbs.press("undo")
	await _frames(6)
	_check("...and one undo puts it back (%d differ)" % _changed(before, _by_id()).size(),
		_changed(before, _by_id()).is_empty() and _builder.history_depth() == depth)
	said = await _call("edit_model", {"recolor": [{"bricks": [shown, later], "color": PAINT}],
		"picture": false, "all_steps": true})
	changed = _changed(before, _by_id())
	changed.sort()
	var both: Array = [shown, later]
	both.sort()
	_check("all_steps: true makes it, both parts (%s): %s" % [changed, said.left(80)], changed == both)
	await _saved_and_opened("stepedit tool %s" % _size, _parts_of(_by_id()), "C")


# -- the set at its fifth step ---------------------------------------------------


## 346-2 opened from its file, the timeline in its author's steps, at step 5.
func _at_step_5(fresh: bool = true) -> bool:
	if fresh:
		if _steps.is_playing_back():
			_steps.stop()
		_main.call("clear_model")
		await _frames(4)
		var placed: int = await _bar.open_with_progress(SET)
		_bar.opened.emit(placed)
		await _frames(30)
	if not _steps.is_playing_back():
		_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(6)
	_steps.to_start()
	for _n: int in 5:
		_steps.step_forward()
		await _frames(2)
	_builder.clear_selection()
	_verbs.set_mode("select")
	await _settle()
	await _frames(10)
	_was_ahead = _builder.lattice.ahead.duplicate()
	var at: Instructions.Step = _steps.current_step()
	var shown: Vector2i = _steps.timeline_at()
	return _check("346-2 at step %d of the author's steps (mode %d): %d of %d parts on, %d not yet"
		% [at.number if at != null else -1, _steps.mode(), shown.x, shown.y,
			_builder.lattice.ahead.size()],
		at != null and at.number == 5 and _builder.lattice.ahead.size() > 0)


## A part of a sub-assembly that has parts of later steps, and a point on the
## screen it is the part under: [id, point], or [] for none.
func _house_part() -> Array:
	var best: Array = []
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _ahead(brick.id) or _store.scenery.has(brick.id):
			continue
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		var under: PackedInt64Array = _verbs.assemblies.ids_under(str(unit))
		var later: int = Array(under).filter(func(id: int) -> bool: return _ahead(id)).size()
		if later == 0 or under.size() <= most:
			continue
		var at: Vector2 = _point_on(brick.id)
		if at == Vector2.INF:
			continue
		best = [brick.id, at]
		most = under.size()
	return best


func _ahead(brick_id: int) -> bool:
	return _builder.lattice.ahead.has(brick_id)


## A click, or on a phone a tap, at [param at], and the selection it makes.
func _press_at(at: Vector2) -> void:
	_builder.clear_selection()
	if _layout == "phone":
		_touch(0, at, true)
		await process_frame
		_touch(0, at, false)
	else:
		_button(at, true)
		await process_frame
		_button(at, false)
	# A tap waits out a double tap's time before it selects.
	for _n: int in 90:
		await process_frame
		if not _builder.selection.is_empty():
			break
	await _frames(8)


## What the selection's line says: the status bar's, or a phone's own.
func _line() -> String:
	if _layout == "phone":
		return str((_main.get("_phone") as Node).call("hint"))
	return _said()


func _said() -> String:
	return str(_shell.status.message.text)


## Every part by id: [part, colour, where].
func _by_id() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.part_id, brick.color_code, _place(brick.transform)]
	return out


## Each part as its part, colour and place, in order: a model opened again
## numbers its parts afresh.
static func _parts_of(by_id: Dictionary) -> Array:
	var out: Array = []
	for one: Array in by_id.values():
		out.append("%s %d %s" % one)
	out.sort()
	return out


static func _place(at: Transform3D) -> String:
	var b: Basis = at.basis
	return "%.2f %.2f %.2f | %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f" % [at.origin.x, at.origin.y,
		at.origin.z, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]


## The ids whose part, colour or place differ between the two, or are in one
## alone.
static func _changed(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for id: int in a:
		if not b.has(id) or a[id] != b[id]:
			out.append(id)
	for id: int in b:
		if not a.has(id):
			out.append(id)
	return out


## How many of [param ids] the timeline had not put on in [param a] (or the
## scenery) that are in [param b] as they were. [member _was_ahead] is what it
## had not put on before the edit: the edit can work the steps out again.
func _kept(a: Dictionary, b: Dictionary, ids: PackedInt64Array) -> int:
	var kept: int = 0
	for id: int in ids:
		if (_was_ahead.has(id) or _store.scenery.has(id)) and b.has(id) and a.has(id) and a[id] == b[id]:
			kept += 1
	return kept


var _was_ahead: Dictionary = {}


## Frames until [param done] says so, at most [param most].
func _until(done: Callable, most: int = 240) -> void:
	for _n: int in most:
		if bool(done.call()):
			break
		await process_frame
	await _frames(4)


## Saved, opened again from the file as File › Open does, and compared part
## by part with [param wanted].
func _saved_and_opened(name: String, wanted: Array, label: String) -> void:
	_forget(name)
	_store.title = name
	if not _check("%s: saved" % label, _store.save_as(name)):
		return
	var path: String = ModelStore.saved_path(name)
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(20)
	var now: Array = _parts_of(_by_id())
	var missing: Array = wanted.filter(func(one: String) -> bool: return not now.has(one))
	var extra: Array = now.filter(func(one: String) -> bool: return not wanted.has(one))
	if not _check("%s: opened again, part by part the model saved (%d parts, %d wanted; %d missing, %d not wanted)"
			% [label, now.size(), wanted.size(), missing.size(), extra.size()], now == wanted):
		for one: String in missing.slice(0, 4):
			print("      missing  %s" % one)
		for one: String in extra.slice(0, 4):
			print("      extra    %s" % one)
	_forget(name)


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


## A tool called as the connector calls it: its answer's words.
func _call(tool: String, arguments: Dictionary) -> String:
	_rpc += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text


func _pic(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS2))
	root.get_texture().get_image().save_png("%s%s_%s_%s.png" % [SHOTS2, _size, _layout, name])
