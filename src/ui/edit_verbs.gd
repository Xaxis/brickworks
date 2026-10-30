## The editing verbs a person reaches for while building by hand, in one
## place: copy, cut, paste, duplicate, picking a selection up to move it,
## and turning it.
##
## The keys come here first, and so will the buttons that show them, so a
## shortcut and its button cannot come to do different things. Kept out of
## main.gd, which everything else in the app also lives in.
class_name EditVerbs
extends Node

var builder: Builder
var world: BrickWorld
var library: PartLibrary
## Says a line in the bar along the top.
var say: Callable = func(_line: String) -> void: pass
## The model changed by somebody's own hand.
var edited: Callable = func() -> void: pass
## What is drawn under a ray while the view draws parts other than where
## they stand (SectionsUi.pick_drawn, the sections apart): a brick id, or -1
## when nothing is drawn moved.
var drawn_pick: Callable = Callable()
## Aim the ghost where the pointer is, after what is held has changed.
var aim_again: Callable = func() -> void: pass
## Undo (or Redo, given true) of an open, once there is no other change to
## take back: what it took off the baseplate back (ModelBar.reopen). True
## when it was.
var reopen: Callable = func(_again: bool) -> bool: return false
## What that would take back, or do again, in words; "" for nothing
## (ModelStore.reopen_words).
var reopen_words: Callable = func(_again: bool) -> String: return ""
## Building together (Together): while in a session, Undo and Redo are this
## person's own, and take back none of anybody else's parts.
var together: Together = null

## What this app last put on the system clipboard, so a paste can tell
## LDraw another program put there from its own copy coming back.
var _put_on_clipboard: String = ""


## The key, if it is one of these verbs. True when it was.
func handle_key(key: InputEventKey) -> bool:
	# (A number with something in hand, or straight after R or T, is the
	# typed field's before it comes here: TypedEntry.)
	_arm(key)
	var held: bool = key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_C:
			if held and not key.shift_pressed:
				copy()
				return true
		KEY_V:
			if held and not key.shift_pressed:
				paste()
				return true
			# V alone is the Select tool, as in Studio.
			if not held and not key.alt_pressed:
				if builder.is_carrying():
					put_away()
				set_mode("select")
				return true
		KEY_Q:
			# The last part back in hand. Shift-Q turns the model.
			if not held and not key.shift_pressed and not key.alt_pressed:
				take_last_part()
				return true
		KEY_D:
			if held and not key.shift_pressed:
				duplicate_selection()
				return true
		KEY_X:
			if held:
				cut()
				return true
			if not builder.selection.is_empty() and not builder.is_carrying():
				lift()
				return true
		KEY_R:
			if builder.is_carrying():
				builder.rotate_held(-1 if key.shift_pressed else 1)
				aim_again.call()
				return true
			if not builder.selection.is_empty() and not held:
				turn_by(-turn_step if key.shift_pressed else turn_step)
				return true
		KEY_L:
			if held:
				return false
			if key.shift_pressed:
				unlock_all()
			else:
				lock(true)
			return true
		KEY_ESCAPE:
			if measure != null and measure.active:
				measure.leave()
				aim_again.call()
				say.call("")
				return true
			# Out of Connect: a part from the bin stays in hand to put as
			# ever, a part it took off the model goes back where it was.
			if mode == "connect":
				var placing: bool = connect_tool.holds() and connect_tool.from_hand()
				set_mode("place" if placing else "select")
				return true
			# Out of whatever is carried, and back to Select with nothing
			# in hand, in one press.
			if builder.is_carrying():
				put_away()
				set_mode("select")
				return true
		KEY_U:
			if not held:
				ruler()
				return true
		KEY_G:
			# G alone picks a colour off the model.
			if held and key.shift_pressed:
				leave_submodel()
				return true
			if held:
				make_submodel()
				return true
		KEY_J:
			if not held:
				swing(-SWING if key.shift_pressed else SWING)
				return true
		KEY_M:
			# M alone is the minifigure builder.
			if key.shift_pressed and not held:
				mirror()
				return true
		KEY_H:
			# H alone is the Pan tool (the owner's hand), so hiding is Ctrl-H.
			if key.alt_pressed:
				show_all()
			elif key.shift_pressed:
				isolate()
			elif held:
				if builder.selection.is_empty():
					show_all()
				else:
					hide_selection()
			else:
				view_tool("pan")
			return true
		KEY_N:
			# N alone is Connect (ConnectTool); Shift-N a new step, Ctrl-N New.
			if not held and not key.shift_pressed and not key.alt_pressed:
				start_connect()
				return true
		KEY_O:
			# O the Orbit tool, Z the Zoom tool: the view's own tools, whose
			# left drag only moves the view. Ctrl-O is Open, Ctrl-Z undo.
			if not held and not key.alt_pressed and not key.shift_pressed:
				view_tool("orbit")
				return true
		KEY_Z:
			if not held and not key.alt_pressed and not key.shift_pressed:
				view_tool("zoom")
				return true
	return false


## Changes to this many parts or more take long enough to say so first.
const BIG_CHANGE := 300


## For a change to [param count] parts: when it is a big one, the status
## bar says so (Working) and has been drawn before it is made, since the
## change itself is one long frame. [param words] takes the count.
func _say_first(count: int, words: String) -> Working.Job:
	if count < BIG_CHANGE:
		return null
	var job: Working.Job = Working.begin(words % Working.comma(count))
	await job.shown()
	return job


## A button on the edit bar, by name: the same thing its key does.
func press(name: String) -> void:
	if together != null and together.live and (name == "undo" or name == "redo"):
		var words: String = together.undo(name == "redo")
		if not words.is_empty():
			edited.call()
		say.call(words if not words.is_empty() else "nothing of yours to %s" % name)
		aim_again.call()
		return
	# Undo with a part Connect took off the model in hand is that taking off.
	if name == "undo" and mode == "connect" and connect_tool.holds() \
			and not connect_tool.from_hand():
		set_mode("select")
		say.call("put back where it was")
		return
	match name:
		"undo":
			var job: Working.Job = await _say_first(builder.next_change_size(),
				"Undoing a change to %s parts…")
			# Said, whatever it was: undoing a sub-assembly made changes
			# nothing a person can see, and the line said nothing either.
			var opened: String = reopen_words.call(false) if builder.history_depth() == 0 else ""
			if builder.undo():
				edited.call()
				say.call("undid: %s" % builder.redo_words())
			elif opened.is_empty() or not await reopen.call(false):
				say.call("nothing to undo")
			if job != null:
				job.end()
			aim_again.call()
		"redo":
			var job: Working.Job = await _say_first(builder.next_change_size(true),
				"Redoing a change to %s parts…")
			var opened: String = reopen_words.call(true) if builder._redo.is_empty() else ""
			if builder.redo():
				edited.call()
				var done: PackedStringArray = builder.history_words(1)
				say.call("redid: %s" % (done[0] if not done.is_empty() else "the change"))
			elif opened.is_empty() or not await reopen.call(true):
				say.call("nothing to redo")
			if job != null:
				job.end()
			aim_again.call()
		"rotate":
			if builder.is_carrying() or builder.selection.is_empty():
				builder.rotate_held(1)
				aim_again.call()
			else:
				turn_by(turn_step)
		"tip":
			builder.tip_held(1)
			aim_again.call()
			say.call("studs %s" % builder.held_face)
		"move":
			lift()
		"copy":
			copy()
		"paste":
			paste()
		"duplicate":
			duplicate_selection()
		"paint":
			var painted: int = builder.paint_selection(builder.held_color)
			if painted > 0:
				edited.call()
				say.call("painted %s" % _parts(painted))
		"delete":
			var job: Working.Job = await _say_first(builder.selection.size(),
				"Taking off %s parts…")
			var gone: int = builder.remove_selection()
			if gone > 0:
				edited.call()
				say.call("removed %s" % _parts(gone))
			if job != null:
				job.end()
		"replace":
			replace()
		"mirror":
			mirror()
		"measure":
			ruler()
		"submodel":
			make_submodel()
		"swing":
			swing(SWING)
		"hide":
			hide_selection()
		"isolate":
			isolate()
		"show_all":
			show_all()
		"lock":
			lock(true)
		"unlock":
			unlock_all()


## Swap the selection for the part in hand.
func replace() -> int:
	var part: String = builder.held_part
	var info: PartLibrary.PartInfo = library.parts.get(part)
	var done: Vector2i = builder.replace_selection(part)
	if done.x == 0 and done.y == 0:
		say.call("select what to replace, and hold the part to put in its place")
		return 0
	if done.x > 0:
		edited.call()
	var named: String = Inventory._tidy(info.name) if info != null else part
	say.call("swapped %s for %s%s" % [_parts(done.x), named,
		"" if done.y == 0 else " — %d had no room for it" % done.y])
	return done.x


## The view, to say which way is left and right on the screen.
var camera: CadCamera


## The selection made into its mirror image, left to right as the view
## sees it.
func mirror() -> int:
	if builder.selection.is_empty():
		say.call("select what to mirror first")
		return 0
	var axis: int = 0
	if camera != null:
		var right: Vector3 = camera.global_transform.basis.x
		axis = 0 if absf(right.x) >= absf(right.z) else 2
	var count: int = builder.mirror_selection(axis)
	if count == 0:
		say.call("no room to mirror it there")
		return 0
	edited.call()
	aim_again.call()
	say.call("mirrored %s" % _parts(count))
	return count


## The ruler (Measure), when the app has one.
var measure: Measure


## Take the ruler out, or put it away.
func ruler() -> void:
	if measure == null:
		return
	if measure.toggle():
		builder.hide_preview()
		say.call("measuring — click two points; U or Esc puts the ruler away")
	else:
		aim_again.call()
		say.call("")


## How far one press of J swings a selection about its joint, in degrees.
const SWING := 15.0


## Swing the selection about the hinge, clip or turntable it hangs from.
func swing(degrees: float) -> int:
	if builder.selection.is_empty():
		say.call("select what hangs from a hinge, clip or turntable first")
		return 0
	var count: int = builder.swing_selection(degrees)
	if count == 0:
		say.call("that is not on a hinge, clip or turntable, or it would hit something")
		return 0
	edited.call()
	aim_again.call()
	say.call("swung %s %+d° — J again, Shift-J back" % [_parts(count), int(degrees)])
	return count


## Asking what a new sub-assembly is called.
var _naming: ConfirmationDialog
var _name_field: LineEdit
## The model's sub-assemblies (Assemblies): what a click takes, which one
## is being edited, and the copies that follow.
var assemblies: Assemblies
## What the naming dialog is for: "make" or "rename".
var _naming_for: String = "make"


## Make the selection a sub-assembly, asking for its name first.
func make_submodel() -> void:
	if builder.selection.is_empty():
		say.call("select the parts that make up the sub-assembly first")
		return
	_ask_name("make", "Make a sub-assembly", "Make it",
		"What is it called? It moves as one, saves as a sub-model of its own,\n"
		+ "and the instructions build it on its own. Copies of it follow it.",
		assemblies.unused_name("Sub-assembly") if assemblies != null
			else builder.unused_group("Sub-model"))


## Call the selected sub-assembly something else, in every copy of it.
func rename_assembly() -> void:
	var path: String = assemblies.selected_assembly() if assemblies != null else ""
	if path.is_empty():
		say.call("select a sub-assembly first")
		return
	_ask_name("rename", "Rename the sub-assembly", "Rename",
		"What is it called? Every copy of it is renamed.",
		Assemblies.definition(Assemblies.leaf(path)))


func _ask_name(purpose: String, title: String, button: String, words_said: String,
		offered: String) -> void:
	if _naming == null:
		_naming = ConfirmationDialog.new()
		var column := VBoxContainer.new()
		var words := Label.new()
		words.name = "Words"
		column.add_child(words)
		_name_field = LineEdit.new()
		_name_field.accessibility_name = "Name"
		_name_field.custom_minimum_size = Vector2(300, 0)
		_name_field.text_submitted.connect(func(_text: String) -> void:
			_naming.hide()
			_named(_name_field.text))
		column.add_child(_name_field)
		_naming.add_child(column)
		_naming.confirmed.connect(func() -> void: _named(_name_field.text))
		add_child(_naming)
	_naming_for = purpose
	_naming.title = title
	_naming.ok_button_text = button
	(_naming.find_child("Words", true, false) as Label).text = words_said
	_name_field.text = offered
	_naming.popup_centered()
	_name_field.grab_focus()
	_name_field.select_all()


func _named(text: String) -> void:
	if _naming_for == "rename":
		var path: String = assemblies.selected_assembly()
		if path.is_empty():
			return
		var name: String = assemblies.rename(path, text)
		edited.call()
		say.call("called it %s, in every copy" % name)
		return
	name_submodel(text)


func name_submodel(name: String) -> int:
	var called: String = name.strip_edges()
	if assemblies == null:
		if called.is_empty():
			called = builder.unused_group("Sub-model")
		var count: int = builder.name_group(called)
		if count > 0:
			edited.call()
		return count
	var path: String = assemblies.make(called if not called.is_empty() else "Sub-assembly")
	if path.is_empty():
		return 0
	var made: int = assemblies.ids_under(path).size()
	edited.call()
	say.call("“%s” is a sub-assembly of %s — a click takes it whole, a double-click edits inside it"
		% [Assemblies.label(path), _parts(made)])
	return made


## Take the selected sub-assembly apart one level, or take the selected
## parts out of the one they are in.
func leave_submodel() -> int:
	if assemblies != null:
		var path: String = assemblies.selected_assembly()
		if not path.is_empty():
			var count: int = assemblies.ungroup(path)
			if count > 0:
				edited.call()
				say.call("took %s apart" % Assemblies.label(path))
			return count
		var changes: Dictionary = {}
		for brick_id: int in builder.selection:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				changes[brick_id] = Assemblies.parent_of(Assemblies.path_of(brick))
		var moved: int = builder.regroup(changes, "took %s out of its sub-assembly"
			% _parts(changes.size()))
		if moved > 0:
			edited.call()
			say.call("took %s out of its sub-assembly" % _parts(moved))
		return moved
	var gone: int = builder.name_group("")
	if gone > 0:
		edited.call()
	return gone


## Edit inside the selected sub-assembly.
func enter_assembly() -> void:
	var path: String = assemblies.selected_assembly() if assemblies != null else ""
	if path.is_empty():
		say.call("select a sub-assembly first, or double-click one with the Select tool")
		return
	assemblies.enter(path)
	aim_again.call()
	say.call("editing %s — Esc when done" % Assemblies.label(path))


func leave_assembly() -> void:
	if assemblies == null or assemblies.entered.is_empty():
		return
	var was: String = assemblies.entered
	assemblies.leave()
	aim_again.call()
	say.call("done editing %s" % Assemblies.label(was))


## Cut the selected copy loose from the others — or the copy at
## [param path], for a session (AppTools' make_unique). Its new path, or "".
func make_unique(path: String = "") -> String:
	if path.is_empty():
		path = assemblies.selected_assembly() if assemblies != null else ""
	if path.is_empty():
		return ""
	var fresh: String = assemblies.make_unique(path)
	edited.call()
	say.call("%s is a sub-assembly of its own now: editing it changes no other"
		% Assemblies.label(fresh))
	return fresh


## Back through the history to before the step ``count`` steps ago.
func go_back(count: int) -> int:
	# A session's history is each person's own: steps back are Undo's.
	if together != null and together.live:
		var went: int = 0
		while went < count and not together.undo().is_empty():
			went += 1
		if went > 0:
			edited.call()
		say.call("went back %d of your steps" % went)
		aim_again.call()
		return went
	# To before the open they followed: its model back at once, these
	# changes kept with the model it took off, for Redo.
	var opened: String = reopen_words.call(false)
	if count > builder.history_depth() and not opened.is_empty() and await reopen.call(false):
		say.call("went back to before: %s — %s-Shift-Z goes forward again" % [opened, _hold()])
		aim_again.call()
		return count
	var done: int = builder.undo_steps(count)
	if done > 0:
		edited.call()
		say.call("went back %d step%s — %s-Shift-Z goes forward again" % [
			done, "" if done == 1 else "s", _hold()])
	aim_again.call()
	return done


# -- selecting by -------------------------------------------------------------


## The scenery: the baseplate, which no selection takes in.
var scenery: Dictionary = {}


## Widen or replace the selection: "colour", "part", "alike" (both),
## "connected", "inverse", "all" or "none". Seeded by what is selected.
func select_by(kind: String) -> int:
	var seeds: Array = builder.selection.keys()
	var found: Array = []
	match kind:
		"colour", "part", "alike":
			if seeds.is_empty():
				say.call("select a brick first, then choose what to match")
				return 0
			found = SelectBy.matching_any(kind, world, seeds, scenery)
		"submodel":
			if seeds.is_empty():
				say.call("select a brick of the sub-model first")
				return 0
			found = SelectBy.submodel(world, seeds, scenery)
			if found.is_empty():
				say.call("that is not in a sub-model — %s-G makes one" % _hold())
				return 0
		"connected":
			if seeds.is_empty():
				say.call("select a brick first, then take everything joined to it")
				return 0
			found = SelectBy.connected(world, builder.lattice, seeds, scenery)
		"inverse":
			found = SelectBy.inverse(world, builder.selection, scenery)
		"all":
			found = SelectBy.inverse(world, {}, scenery)
		"none":
			builder.clear_selection()
			return 0
	return select_found(found)


## Select these bricks, leaving out the hidden and the locked: how many
## that was.
func select_found(found: Array) -> int:
	builder.selection.clear()
	for brick_id: int in found:
		if not builder.lattice.unseen.has(brick_id) and not builder.is_locked(brick_id):
			builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	return builder.selection.size()


## Everything joined to the selection, however far (Select by, Everything
## connected): on a big model followed a slice at a time, the status bar
## counting, with Cancel. On one frame it held the window for fourteen
## seconds over Orthanc, all of which is joined to all of it (2026-10-13,
## command_probe).
func select_connected() -> int:
	var seeds: Array = builder.selection.keys()
	if seeds.is_empty() or world.brick_count() < BIG_CHANGE:
		return select_by("connected")
	var job: Working.Job = Working.begin("Finding everything joined to %s…"
		% _parts(seeds.size()), 0, true)
	await job.shown()
	var found: Array = await SelectBy.connected_paced(world, builder.lattice, seeds,
		scenery, job)
	job.end()
	if job.cancelled:
		say.call("stopped looking for what is joined to it")
		return 0
	return select_found(found)


# -- hiding -------------------------------------------------------------------


## Hide the selection: still there, still in the way of anything put
## where it is, but not drawn and not in the pointer's way, so what is
## behind or inside it can be reached.
func hide_selection() -> int:
	var ids: Array = builder.selection.keys()
	if ids.is_empty():
		say.call("select what to hide first")
		return 0
	for brick_id: int in ids:
		builder.lattice.unseen[brick_id] = true
	builder.clear_selection()
	apply_hidden()
	# H alone is the Pan tool: the keys that bring it back are these.
	say.call("hid %s — Alt-H, or %s-H with nothing selected, shows everything"
		% [_parts(ids.size()), _hold()])
	return ids.size()


## Hide everything but the selection.
func isolate() -> int:
	var keep: Dictionary = builder.selection
	if keep.is_empty():
		say.call("select what to work on first")
		return 0
	var hid: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or keep.has(brick.id):
			continue
		builder.lattice.unseen[brick.id] = true
		hid += 1
	apply_hidden()
	say.call("showing only %s — Alt-H shows everything" % _parts(keep.size()))
	return hid


func show_all() -> int:
	var count: int = builder.lattice.unseen.size()
	builder.lattice.unseen.clear()
	apply_hidden()
	if count > 0:
		say.call("showing everything")
	return count


## Draw what is hidden as hidden. Called again when anything else that
## shows and hides bricks — the timeline — lets go of the world.
func apply_hidden() -> void:
	# A part hidden or shown is one the pointer passes through or stops at.
	_asked = []
	var hidden: Dictionary = builder.lattice.unseen
	if hidden.is_empty():
		world.show_only({})
	else:
		var shown: Dictionary = {}
		for brick: BrickWorld.Brick in world.bricks():
			if not hidden.has(brick.id):
				shown[brick.id] = true
		world.show_only(shown)
	aim_again.call()


func copy() -> int:
	var count: int = builder.copy_selection()
	if count == 0:
		say.call("select something to copy first")
		return 0
	# And as LDraw on the system clipboard, which LDCad, LeoCAD and a
	# text editor all paste. Not in a browser, which allows it only inside
	# the page's own handling of a key or a click — and Godot answers both
	# a frame later, so every copy there printed an error instead.
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) and not OS.has_feature("web"):
		_put_on_clipboard = Carry.as_ldraw(Carry.clipboard)
		DisplayServer.clipboard_set(_put_on_clipboard)
	say.call("copied %s — %s-V to paste" % [_parts(count), _hold()])
	return count


func cut() -> int:
	var count: int = copy()
	if count == 0:
		return 0
	var gone: int = builder.remove_selection()
	if gone > 0:
		edited.call()
	say.call("cut %s — %s-V to paste" % [_parts(gone), _hold()])
	return gone


## Hold a copy of what was copied, to put down where the pointer says.
##
## LDraw put on the system clipboard by another program is taken in place
## of the app's own copy when it is newer: parts copied out of LDCad or a
## text file paste straight in.
func paste() -> int:
	var parts: Array = Carry.clipboard
	var outside: String = ""
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) \
			and DisplayServer.clipboard_has():
		outside = DisplayServer.clipboard_get()
	if not outside.is_empty() and outside != _put_on_clipboard:
		var read: Array = Carry.from_ldraw(outside, library)
		if not read.is_empty():
			parts = read
	if parts.is_empty():
		say.call("nothing copied yet — select something and press %s-C" % _hold())
		return 0
	builder.cancel_carry()
	builder.hold_copy(parts)
	aim_again.call()
	say.call("holding %s — click to put down, R turns, Esc puts away"
		% _parts(parts.size()))
	return parts.size()


## A worked construction from the parts bin in hand, whole (PartsBin's
## Techniques): put down as a paste is, one undo, R turning it first.
func hold(parts: Array, what: String) -> int:
	if parts.is_empty():
		return 0
	builder.cancel_carry()
	builder.hold_copy(parts)
	aim_again.call()
	say.call("holding %s, %s — click to put it down, R turns, Esc puts away"
		% [what, _parts(parts.size())])
	return parts.size()


## A copy of the selection in hand at once: copy and paste in one key,
## leaving the clipboard as it was. Put down, another copy stays in hand
## for the next ([param again]), as the Clone tool's does: not for a copy
## dragged off with Ctrl, which is let go where the drag ends.
func duplicate_selection(again: bool = true) -> int:
	var alive: Array = builder.selection.keys()
	if alive.is_empty():
		say.call("select something to duplicate first")
		return 0
	var parts: Array = Carry.gather(world, library, alive)
	if parts.is_empty():
		return 0
	builder.cancel_carry()
	builder.hold_copy(parts)
	builder.carrying.repeats = again
	aim_again.call()
	say.call(("holding a copy of %s — each click puts one down, R turns, Esc or a right click stops"
		if again else "holding a copy of %s — click to put it down, R turns, Esc puts away")
		% _parts(parts.size()))
	return parts.size()


## Pick the selection up to move it with the pointer.
func lift() -> int:
	var count: int = builder.lift_selection()
	if count == 0:
		return 0
	edited.call()
	aim_again.call()
	say.call("moving %s — click to put down, R turns, Esc puts back"
		% _parts(count))
	return count


## Turn the selection where it stands.
func turn(quarter_turns: int) -> int:
	return turn_by(quarter_turns * 90.0)


## Tip the selection over, forwards as the view looks at it (``way`` -1:
## back), a quarter, where it stands: T and Shift-T.
func tip_selection(way: int) -> int:
	var axis: Vector3 = _level_right()
	var depth: int = builder.history_depth()
	var count: int = builder.tip_selection(axis, -way)
	if count == 0:
		return _turn_in_hand(Basis(axis, -way * PI * 0.5), "tilt", "tip it over")
	_armed = {"verb": "tilt", "depth": depth, "way": way}
	edited.call()
	aim_again.call()
	say.call("tipped %s over — T again, Shift-T back, or type its angle" % _parts(count))
	return count


## The level axis most nearly to the right as the view looks: what T tips
## a selection forwards about.
func _level_right() -> Vector3:
	if camera == null:
		return Vector3.RIGHT
	var right: Vector3 = camera.global_transform.basis.x
	return Vector3(signf(right.x), 0, 0) if absf(right.x) >= absf(right.z) \
		else Vector3(0, 0, signf(right.z))


## Turn the selection where it stands by any angle: the turn step, from R
## and the Rotate tool.
func turn_by(degrees: float) -> int:
	var depth: int = builder.history_depth()
	var count: int = builder.turn_selection_by(degrees)
	if count == 0:
		return _turn_in_hand(Basis(Vector3.UP, deg_to_rad(degrees)), "turn", "turn it")
	_armed = {"verb": "turn", "depth": depth, "degrees": degrees}
	edited.call()
	aim_again.call()
	say.call("turned %s %+d° — or type its angle" % [_parts(count), roundi(degrees)])
	return count


## A turn or a tip with no room where the selection stands: the parts in
## the way drawn red for a second, and the selection taken into hand
## already turned, its ghost where the pointer says, to be put down where
## it has room. Taking it and putting it down are one step to undo, and Esc
## puts it back as it was. It was a dead end, "no room to turn it there"
## and nothing else (docs/APP_UX.md, A3). Studio's arrows turn a part
## through others; here the collision stays exact and the way on is shown.
func _turn_in_hand(turn: Basis, verb: String, words: String) -> int:
	var blocking: PackedInt64Array = builder.refused_by
	_flash(blocking)
	var why: String = "what it would hit is lit up" if not blocking.is_empty() \
		else "it would go through the floor"
	if builder.selection.size() >= BIG_CHANGE:
		say.call("no room to %s there — %s" % [words, why])
		return 0
	var count: int = builder.lift_selection()
	if count == 0:
		say.call("no room to %s there" % words)
		return 0
	# A number typed straight after takes the place of this turn.
	_armed = {"verb": verb, "hand": builder.hand_state(), "pointer": _pointer()}
	builder.carrying.reshape(turn)
	edited.call()
	aim_again.call()
	say.call("no room to %s there (%s): it is in hand turned — click where it goes, Esc puts it back"
		% [words, why])
	return count


## The parts last lit up as in the way, for a probe to read.
var flashed := PackedInt64Array()
## Red, and amber on a part that is red already: red on a red wall showed
## nothing.
const IN_THE_WAY := Color(1.0, 0.12, 0.08)
const IN_THE_WAY_ON_RED := Color(1.0, 0.86, 0.22)
## The tints as they were under the red now showing, and that red: a
## flash over one still showing keeps what was under the first, so the
## last to end puts back what was there before either.
var _under_red: Dictionary = {}
var _red: Dictionary = {}
var _flashes: int = 0


## Light these parts up for a second, over whatever else is tinted.
func _flash(ids: PackedInt64Array) -> void:
	flashed = ids
	if ids.is_empty() or world == null or not is_inside_tree():
		return
	var now: Dictionary = world.tinted_ids()
	if _red.is_empty() or now != _red:
		var was_under: Dictionary = _under_red
		_under_red = now.duplicate()
		# Red of a flash something else tinted over is not what was under.
		for brick_id: int in _red:
			if _under_red.get(brick_id) in [IN_THE_WAY, IN_THE_WAY_ON_RED]:
				if was_under.has(brick_id):
					_under_red[brick_id] = was_under[brick_id]
				else:
					_under_red.erase(brick_id)
	_red = _under_red.duplicate()
	for brick_id: int in ids:
		_red[brick_id] = _lit(brick_id)
	world.set_tinted(_red)
	_flashes += 1
	var mine: int = _flashes
	await get_tree().create_timer(1.0).timeout
	if mine != _flashes:
		return
	# Back as it was, unless something else has tinted since.
	if world.tinted_ids() == _red:
		world.set_tinted(_under_red)
	_red = {}
	_under_red = {}


func _lit(brick_id: int) -> Color:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or builder.library == null:
		return IN_THE_WAY
	var own: Color = builder.library.color(brick.color_code).shown
	var reddish: bool = (own.h < 0.07 or own.h > 0.93) and own.s > 0.45 and own.v > 0.3
	return IN_THE_WAY_ON_RED if reddish else IN_THE_WAY


# -- locking ------------------------------------------------------------------


## Lock the selection, so nothing picks it out, moves, paints or removes it
## until it is unlocked: a finished base kept safe while the building on it
## is worked on. Or unlock it.
func lock(yes: bool) -> int:
	if builder.selection.is_empty():
		say.call("select what to lock first")
		return 0
	var count: int = builder.lock_selection(yes)
	say.call(("locked %s — Shift-L unlocks everything" if yes else "unlocked %s")
		% _parts(count))
	return count


func unlock_all() -> int:
	var count: int = builder.unlock_all()
	say.call("unlocked %s" % _parts(count) if count > 0 else "nothing is locked")
	return count


# -- tools --------------------------------------------------------------------


## What a left click on the model does. "build" puts the part in hand
## down, as the app always has; each of the others is a tool on the
## toolbar, and a click on a part does that tool's one thing to it — or to
## the whole selection, when the part clicked is in it.
##
## Every verb was a key or a button that acted on a selection made first,
## so turning one brick was three gestures: Shift-click it, press R, press
## Escape. Studio and Mecabricks both have tools a click acts through.
const MODES: Array[String] = ["select", "place", "move", "rotate", "hinge", "connect",
	"clone", "paint", "hide", "delete", "orbit", "pan", "zoom"]
## Select is where the app rests, as Studio does: nothing in hand, a click
## picks a part out and a drag moves it. A part chosen from the bin (or Q,
## or Alt-click on one in the model) is in hand — "place" — until Escape
## or a right click lets go of it; it stays in hand for the next, as
## Studio's "repeat inserting" does by default.
var mode: String = "select"
signal mode_changed(mode: String)

## How far R and the Rotate tool turn a selection, in degrees. The part in
## hand turns a quarter on the studs; on a round joint (a pin in a hole, a
## clip on a bar) it turns by this when it is finer than an eighth, so the
## builder is told too.
var turn_step: float = 90.0:
	set(degrees):
		turn_step = degrees
		if builder != null:
			builder.turn_step = degrees

## The grid a part is put down and nudged on: across, and up for Shift and
## the arrows, in LDU. Named as the toolbar names them.
const SNAPS: Dictionary = {
	"stud": [20, 8], "half": [10, 8], "half_plate": [10, 4], "free": [2, 2]}
var snap: String = "stud"


func set_snap(to: String, aim: bool = true) -> void:
	if not SNAPS.has(to):
		return
	snap = to
	builder.snap_across = float(SNAPS[to][0])
	# Not as the app starts: aiming then put a ghost under a pointer that
	# had not moved, which nothing had ever done before.
	if aim:
		aim_again.call()


## One nudge across, and one up, in lattice cells.
func across_cells() -> int:
	return roundi(float(SNAPS[snap][0]) / BrickLattice.CELL)


func up_cells() -> int:
	return roundi(float(SNAPS[snap][1]) / BrickLattice.CELL)


func set_mode(to: String) -> void:
	if to == "connect":
		start_connect()
		return
	if not MODES.has(to) or to == mode:
		return
	# Another tool ends a clone's run of copies, and Connect's choosing.
	if builder.is_carrying() and builder.carrying.repeats:
		put_away()
	if mode == "connect":
		connect_tool.end()
	mode = to
	if measure != null and measure.active:
		measure.leave()
	if to != "place" and not builder.is_carrying():
		builder.hide_preview()
	mode_changed.emit(mode)
	aim_again.call()


## Connect (ConnectTool): with a part in hand, its points offered where its
## ghost stands, or where the view looks when it stands nowhere (the
## pointer is on the toolbar); with nothing in hand, a click on a part of
## the model takes it. Again while aiming, another point.
func start_connect() -> void:
	var placing: bool = mode == "place" or (mode == "connect" and connect_tool.holds())
	var at: Variant = null
	if placing and not builder.has_preview() and camera != null:
		at = Transform3D(BrickLattice.basis_for(builder.held_face, builder.held_rotation),
			BrickLattice.to_ldu(BrickLattice.to_cell(camera.focus_now())))
	if not connect_tool.begin(placing, at):
		return
	if mode == "connect":
		mode_changed.emit(mode)
		return
	if builder.is_carrying() and builder.carrying.repeats:
		put_away()
	mode = "connect"
	if measure != null and measure.active:
		measure.leave()
	if not connect_tool.holds():
		builder.hide_preview()
	mode_changed.emit(mode)
	aim_again.call()


## The view tools: while one is on, the left button only turns, slides or
## zooms the view, whatever is under it. Esc or the Select tool (V) is the
## way back.
const VIEW_TOOLS: Dictionary = {"orbit": "turn", "pan": "slide", "zoom": "zoom"}


func is_view_tool() -> bool:
	return VIEW_TOOLS.has(mode)


## What a left drag does with the view tool on: "turn", "slide", "zoom".
func view_verb() -> String:
	return str(VIEW_TOOLS.get(mode, ""))


func view_tool(name: String) -> void:
	if builder.is_carrying():
		put_away()
	builder.drop_figure()
	set_mode(name)
	say.call("%s: drag to %s the view — Esc or V for Select" % [name.capitalize(),
		{"orbit": "turn", "pan": "slide", "zoom": "zoom"}[name]])


## The part in hand again, the last one chosen: Q, as the coordinator's
## brief and Studio's "repeat" both have it.
func take_last_part() -> void:
	set_mode("place")
	var info: PartLibrary.PartInfo = library.parts.get(builder.held_part)
	say.call("placing %s — click to put one down, Esc or a right click to stop"
		% (Inventory._tidy(info.name) if info != null else builder.held_part))


## Alt-click: the part under the pointer, in its colour, into hand —
## Studio's eyedropper.
func pick_at(at: Vector2) -> bool:
	var brick_id: int = brick_at(at)
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if brick_id != 0 else null
	if brick == null:
		return false
	builder.held_part = brick.part_id
	builder.held_color = brick.color_code
	builder.picked.emit(brick.part_id, brick.color_code)
	set_mode("place")
	return true


## A left drag that began on a part with the Select tool: the part (with
## the selection, if it is in it) picked up to follow the pointer and be
## let go where the drag ends — or, with Ctrl, a copy of it. False when
## there was nothing it could take.
func drag_start(brick_id: int, copy: bool) -> bool:
	if builder.is_locked(brick_id):
		say.call("that part is locked — Shift-L unlocks everything")
		return false
	if not builder.selection.has(brick_id):
		builder.select_brick(brick_id, false)
	if builder.selection.is_empty():
		return false
	if copy:
		return duplicate_selection(false) > 0
	return lift() > 0


## Whether this is a Mac, where Cmd is the held key and Ctrl-click is a
## right click — the browser's Mac as well as the desktop's.
static func on_mac() -> bool:
	return OS.has_feature("macos") or OS.has_feature("web_macos")


## The held key, as a Mac or anything else names it.
static func held_key() -> String:
	return "Cmd" if on_mac() else "Ctrl"


## What the mouse will do now, in one line, for the status bar: the tool,
## the keys held, and what is under the pointer.
func hint() -> String:
	var held: String = held_key()
	if is_view_tool():
		return {"orbit": "Orbit: drag turns the view", "pan": "Pan: drag slides the view",
			"zoom": "Zoom: drag up or down zooms, a click zooms in (Shift-click out)"}[mode] \
			+ " — Esc or V back to Select"
	if Input.is_key_pressed(KEY_SPACE):
		return "Space held: drag slides the view — let go of Space to carry on"
	if Input.is_key_pressed(KEY_ALT):
		return "Alt held: drag turns the view, with Shift slides it, with %s zooms; a click takes that part into hand" % held
	var over: int = brick_at(camera.get_viewport().get_mouse_position()) \
		if camera != null and camera.is_inside_tree() else 0
	var look: String = "drag turns the view, Shift-drag slides it, scroll zooms"
	match mode:
		"select":
			if builder.is_carrying() and builder.carrying.repeats:
				return "Select: each click puts a copy down · type a number to move it exactly · Esc or a right click stops"
			if builder.is_carrying():
				return "Select: a click puts it down · type a number to move it exactly · %s · Esc puts it back" % look
			if over != 0:
				return "Select: click selects it · drag moves it (on a joint, as the real part moves) · %s-drag copies it · double-click edits inside a sub-assembly" % held
			return "Select: click lets go of the selection · %s · %s-drag draws a box" % [look, held]
		"place":
			var info: PartLibrary.PartInfo = library.parts.get(builder.held_part) \
				if library != null else null
			var named: String = Inventory._tidy(info.name) if info != null else builder.held_part
			# On a joint, what it is on and what R and T do there instead.
			if builder.is_on_joint():
				return "Placing %s on %s: click puts it there · R turns it about the joint · T the other way on · Esc lets go" % [
					named, builder.joint_words()]
			return "Placing %s: click puts one down · type a number to move it exactly · %s, the part stays in hand · Esc lets go" % [
				named, look]
		"move":
			return "Move: click a part to pick it up (the selection with it), click again to put it down · %s" % look
		"rotate":
			return "Rotate: click a part to turn it %d° (Shift-click back) · %s" % [roundi(turn_step), look]
		"hinge":
			return "Hinge: click a part on a hinge, clip or turntable to swing it %d° · %s" % [roundi(SWING), look]
		"connect":
			return connect_tool.hint()
		"clone":
			if builder.is_carrying():
				return "Clone: each click puts a copy down · type a number to move it exactly · Esc or a right click stops"
			return "Clone: click a part to hold a copy of it, then click where each goes · %s" % look
		"paint":
			return "Paint: click a part to paint it the colour in hand · %s" % look
		"hide":
			return "Hide: click a part to hide it — Alt-H shows everything · %s" % look
		"delete":
			return "Delete: click a part to take it off · %s" % look
	return ""


## Whether the ghost of the part in hand belongs under the pointer: while
## placing, and while anything is carried, whatever the tool.
func shows_ghost() -> bool:
	return mode == "place" or builder.is_carrying() or builder.is_holding_figure() \
		or (mode == "connect" and connect_tool.holds())


## Nobody can see the model: the tab is out of view or the window
## minimised (Main._watch_view). Nothing is under a pointer then.
var out_of_view: bool = false
## The last look-up, what it was asked (the ray, and the model as it was)
## and what it found.
##
## The status line and the pointer each ask for the part under the
## pointer every frame. A ray that hits nothing marches the whole lattice:
## 18 ms on the desktop with the 4,242-part Falcon Heavy built, and several
## times that in a browser, twice a frame. A big design built in a hidden
## tab was never seen to settle once shown (arrival_check, 2026-10-12). So
## a frame looks again only when the pointer, the view or the model moved.
var _asked: Array = []
var _found: int = 0
## How many times it really looked, for idle_probe to count.
var looked: int = 0


## The part under a point on the screen, or 0 for none, the baseplate or a
## hidden one.
func brick_at(at: Vector2) -> int:
	if camera == null or out_of_view:
		return 0
	var origin: Vector3 = camera.ray_origin(at)
	var normal: Vector3 = camera.ray_normal(at)
	# The sections drawn apart (SectionsUi): what is drawn under the pointer.
	if drawn_pick.is_valid():
		var drawn: int = int(drawn_pick.call(origin, normal))
		if drawn >= 0:
			return 0 if scenery.has(drawn) else drawn
	var asked: Array = [origin, normal, builder.lattice.revision]
	if asked == _asked:
		return _found
	_asked = asked
	looked += 1
	var hit: BrickLattice.Hit = builder.lattice.raycast(origin, normal)
	_found = 0 if not hit.is_valid() or scenery.has(hit.brick_id) else hit.brick_id
	return _found


## A left click on the model with a tool other than Build. True when it
## did something.
func click(at: Vector2, shift: bool) -> bool:
	var brick_id: int = brick_at(at)
	if mode == "select":
		if brick_id == 0:
			if not shift:
				builder.clear_selection()
			return false
		if builder.is_locked(brick_id):
			say.call("that part is locked — Shift-L unlocks everything")
			return false
		return builder.select_brick(brick_id, shift)
	if brick_id == 0:
		return false
	if builder.is_locked(brick_id):
		say.call("that part is locked — Shift-L unlocks everything")
		return false
	if mode == "connect":
		builder.clear_selection()
		return connect_tool.take(brick_id)
	if not builder.selection.has(brick_id):
		builder.select_brick(brick_id, false)
	match mode:
		"move":
			return lift() > 0
		"rotate":
			return turn_by(-turn_step if shift else turn_step) > 0
		"hinge":
			return swing(-SWING if shift else SWING) > 0
		"clone":
			return duplicate_selection() > 0
		"paint":
			var painted: int = builder.paint_selection(builder.held_color)
			if painted > 0:
				edited.call()
				say.call("painted %s" % _parts(painted))
			return painted > 0
		"hide":
			return hide_selection() > 0
		"delete":
			var gone: int = builder.remove_selection()
			if gone > 0:
				edited.call()
				say.call("removed %s" % _parts(gone))
			return gone > 0
	return false


# -- typed: a number while something is in hand --------------------------------


## The field a number is typed into, at the pointer (TypedEntry).
var typed: TypedEntry
## A point on the part, then the point it goes on (ConnectTool).
var connect_tool: ConnectTool
## R or T just pressed, which a number typed straight after takes the place
## of: {verb, hand} with what was in hand before them (Builder.hand_state),
## or {verb, depth, degrees or way} for a selection turned on the model,
## the history's depth before the turn. Empty when the last key was another.
var _armed: Dictionary = {}
## How to leave things as they were if the typing is let go of with Esc:
## {hand} what was in hand as it opened, or {again} the turn on the model
## to make again; empty for neither.
var _typed_was: Dictionary = {}


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Typed"
	# Over the model and its panels, as a tooltip is.
	layer.layer = 8
	add_child(layer)
	typed = TypedEntry.new()
	typed.may_open = _begin_typing
	typed.opened_as = func() -> String: return str(_armed.get("verb", "move"))
	typed.going = func() -> Vector3: return builder.last_way
	# Straight after a copy, "5x" and "/5" are copies (Pattern), not a move.
	typed.reads = _copies_read
	typed.preview = func(what: Dictionary) -> String:
		if what.has("copies"):
			return _copies_shown(what)
		pattern.hide_copies()
		return _typed_preview(what)
	typed.apply = func(what: Dictionary) -> bool:
		return _copies_put(what) if what.has("copies") else _typed_apply(what)
	typed.cancel = func() -> void:
		pattern.hide_copies()
		_typed_cancel()
	typed.still_held = func() -> bool: return builder.is_pinned()
	typed.clear_of = _hand_on_screen
	layer.add_child(typed)
	connect_tool = ConnectTool.new()
	connect_tool.builder = builder
	connect_tool.world = world
	connect_tool.library = library
	connect_tool.camera = camera
	connect_tool.say = func(line: String) -> void: say.call(line)
	connect_tool.edited = func() -> void: edited.call()
	connect_tool.aim_again = func() -> void: aim_again.call()
	add_child(connect_tool)
	pattern = Pattern.new()
	pattern.builder = builder
	pattern.world = world
	pattern.library = library
	pattern.keep = typed.is_open
	add_child(pattern)
	builder.placed.connect(func(_id: int, _part: String) -> void:
		# A click put down what was being typed: the number is spent.
		if typed.is_open():
			typed.close()
		_typed_was = {}
		_armed = {}
		_note_copy())


## Keep what is in hand before R or T, so a number typed next takes their
## place; any other key forgets it. Modifier keys alone change nothing.
func _arm(key: InputEventKey) -> void:
	if not key.pressed or key.echo or key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT]:
		return
	var held: bool = key.ctrl_pressed or key.meta_pressed or key.alt_pressed
	if key.keycode in [KEY_R, KEY_T] and not held and shows_ghost() and builder.has_preview():
		_armed = {"verb": "turn" if key.keycode == KEY_R else "tilt",
			"hand": builder.hand_state(), "pointer": _pointer()}
		return
	_armed = {}


## R or T in hand is just pressed until the pointer takes the ghost
## elsewhere, even if it comes back: a number typed after aiming again
## moves it from there, turned as R left it.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _armed.has("pointer") \
			and (event as InputEventMouseMotion).position.distance_to(_armed["pointer"]) \
			> AIMED_AGAIN:
		_armed = {}


const AIMED_AGAIN := 6.0


func _pointer() -> Vector2:
	return get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO


## The first digit: what is in hand kept where it stands for the number to
## move it from (Builder.pin_hand). After R or T, they are taken back first,
## the number standing for them: in hand, what was held before them; on the
## model, the turn undone and the selection taken into hand where it was,
## so what is typed shows in hand and is put down with the turn's undo.
## False when there is nothing to type for.
func _begin_typing() -> bool:
	if builder.is_holding_figure() or (measure != null and measure.active) \
			or connect_tool.stage == "point":
		return false
	var armed: Dictionary = _armed
	_armed = {}
	_typed_was = {}
	if armed.has("depth"):
		if builder.is_carrying() or builder.selection.is_empty() \
				or builder.history_depth() != int(armed["depth"]) + 1 or not builder.undo():
			return false
		if builder.lift_selection() == 0:
			builder.redo()
			return false
		builder.carrying.stand_where_lifted(builder.lattice, builder)
		_typed_was = {"again": armed}
		edited.call()
	elif not shows_ghost() or not builder.has_preview():
		return false
	elif armed.has("hand"):
		_typed_was = {"hand": builder.hand_state()}
		builder.set_hand_state(armed["hand"])
		aim_again.call()
	if not builder.pin_hand():
		_typed_cancel()
		return false
	return true


## Where what is in hand stands on the screen, for the field to keep clear
## of; empty if any of it is behind the view.
func _hand_on_screen() -> Rect2:
	var box: AABB = builder.pinned_box()
	if camera == null or not box.has_volume():
		return Rect2()
	var out := Rect2()
	for n: int in 8:
		var corner: Vector3 = box.get_endpoint(n)
		if camera.is_position_behind(corner):
			return Rect2()
		var at: Vector2 = camera.unproject_position(corner)
		out = Rect2(at, Vector2.ZERO) if n == 0 else out.expand(at)
	return out


func _typed_preview(what: Dictionary) -> String:
	var fits: bool = builder.typed_hand(what["move"], float(what["turn"]), float(what["tilt"]),
		-_level_right())
	return "" if fits else "no room there"


## Put it down where the number says: one step to undo, as any placement.
func _typed_apply(what: Dictionary) -> bool:
	if not builder.typed_hand(what["move"], float(what["turn"]), float(what["tilt"]),
			-_level_right()):
		return false
	var carried: bool = builder.is_carrying()
	var lifted: bool = carried and builder.carrying.lifted
	var count: int = builder.carrying.count() if carried else 1
	if builder.place() == 0:
		return false
	_typed_was = {}
	aim_again.call()
	say.call("%s %s: %s" % ["moved" if lifted else "put down", _parts(count), what["words"]])
	return true


func _typed_cancel() -> void:
	var was: Dictionary = _typed_was
	_typed_was = {}
	builder.unpin_hand()
	if was.has("again"):
		# Back where it stood, and turned again as R or T turned it.
		put_away()
		var again: Dictionary = was["again"]
		if str(again["verb"]) == "turn":
			turn_by(float(again["degrees"]))
		else:
			tip_selection(int(again["way"]))
	elif was.has("hand"):
		builder.set_hand_state(was["hand"])
	aim_again.call()


# -- "5x" and "/5" after a copy (Pattern) -----------------------------------------


## Copies laid out at once, shown first (Pattern).
var pattern: Pattern
## The copy a clone or Ctrl-D last put down, for "5x" or "/5" typed next:
## {ids: its parts, at: where they stand, step: the move from where it was
## copied from (the original, or the copy put down before it), depth: the
## history's depth after it}. Empty when the last put was not one.
var _copied: Dictionary = {}


## A copy just put down, with another in hand (A6): what it was copied
## from is the copy before it, put down the step before, or else what the
## copy in hand was gathered from (Carry's pivot and frame).
func _note_copy() -> void:
	var before: Array = []
	if not builder.is_carrying() or not builder.carrying.repeats:
		_copied = {}
		return
	var ids: Array = builder.selection.keys()
	var now: Array = []
	for brick_id: int in ids:
		now.append(world.get_brick(brick_id).transform)
	if not _copied.is_empty() and int(_copied["depth"]) + 1 == builder.history_depth():
		before = _copied["at"]
	else:
		for item: Dictionary in builder.carrying.items:
			before.append(Transform3D(Basis.IDENTITY, item.get("pivot", Vector3.ZERO))
				* (item["at"] as Transform3D))
	var step: Variant = Pattern.step_between(before, now)
	_copied = {} if step == null else {"ids": ids, "at": now, "step": step,
		"depth": builder.history_depth()}


## "5x" or "/5" read as copies, while the copy put down last is still the
## last change; {} otherwise, and for anything else typed.
func _copies_read(text: String) -> Dictionary:
	if _copied.is_empty() or int(_copied["depth"]) != builder.history_depth():
		return {}
	for brick_id: int in _copied["ids"]:
		if world.get_brick(brick_id) == null:
			return {}
	return Pattern.read(text, _copied["step"])


## The copies "5x" or "/5" makes, from the copy put down last.
func _copies_moves(what: Dictionary) -> Array[Transform3D]:
	var step: Transform3D = _copied["step"]
	if bool(what["divide"]):
		# Between where it was copied from and where it went: moves from
		# the copy, which stands a whole step on.
		var back: Transform3D = step.affine_inverse()
		var out: Array[Transform3D] = []
		for move: Transform3D in Pattern.divided(step, int(what["copies"]) + 1):
			out.append(move * back)
		return out
	return Pattern.repeated(step, int(what["copies"]))


func _copies_shown(what: Dictionary) -> String:
	builder.carrying.hide_ghost()
	return pattern.show_copies(_copied["ids"], _copies_moves(what))


## Put them down, one undo with the copy they repeat; the copy in hand
## stays for the next.
func _copies_put(what: Dictionary) -> bool:
	var depth: int = int(_copied["depth"]) - 1
	var made: PackedInt64Array = pattern.put(_copied["ids"], _copies_moves(what),
		"put down %s" % _parts(int(what["copies"]) * (_copied["ids"] as Array).size()))
	if made.is_empty():
		return false
	builder.fold_since(depth, "a row of %d copies" % (int(what["copies"]) + 1))
	_copied = {}
	builder.unpin_hand()
	edited.call()
	aim_again.call()
	say.call("%s — Esc puts the copy in hand away" % what["words"])
	return true


## Put away what is held. A selection that was being moved goes back.
func put_away() -> void:
	var lifted: bool = builder.carrying.lifted
	builder.cancel_carry()
	if lifted:
		edited.call()
	aim_again.call()
	say.call("put back where it was" if lifted else "")


static func _parts(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


static func _hold() -> String:
	return "Cmd" if OS.get_name() == "macOS" else "Ctrl"
