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
## Aim the ghost where the pointer is, after what is held has changed.
var aim_again: Callable = func() -> void: pass

## What this app last put on the system clipboard, so a paste can tell
## LDraw another program put there from its own copy coming back.
var _put_on_clipboard: String = ""


## The key, if it is one of these verbs. True when it was.
func handle_key(key: InputEventKey) -> bool:
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
			# V alone is the Select tool, and again goes back to Build.
			if not held and not key.alt_pressed:
				set_mode("build" if mode == "select" else "select")
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
			if builder.is_carrying():
				put_away()
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
			if held:
				return false
			if key.alt_pressed:
				show_all()
			elif key.shift_pressed:
				isolate()
			elif builder.selection.is_empty():
				show_all()
			else:
				hide_selection()
			return true
	return false


## A button on the edit bar, by name: the same thing its key does.
func press(name: String) -> void:
	match name:
		"undo":
			if builder.undo():
				edited.call()
			else:
				say.call("nothing to undo")
			aim_again.call()
		"redo":
			if builder.redo():
				edited.call()
			else:
				say.call("nothing to redo")
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
			var gone: int = builder.remove_selection()
			if gone > 0:
				edited.call()
				say.call("removed %s" % _parts(gone))
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
var camera: Camera3D


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


## Asking what a new sub-model is called.
var _naming: ConfirmationDialog
var _name_field: LineEdit


## Make the selection a sub-model, asking for its name first.
func make_submodel() -> void:
	if builder.selection.is_empty():
		say.call("select the parts that make up the sub-model first")
		return
	if _naming == null:
		_naming = ConfirmationDialog.new()
		_naming.title = "Make a sub-model"
		_naming.ok_button_text = "Make it"
		var column := VBoxContainer.new()
		var words := Label.new()
		words.text = "What is it called? It saves as a sub-model of its own,\n" \
			+ "and the instructions build it on its own."
		column.add_child(words)
		_name_field = LineEdit.new()
		_name_field.custom_minimum_size = Vector2(300, 0)
		_name_field.text_submitted.connect(func(_text: String) -> void:
			_naming.hide()
			name_submodel(_name_field.text))
		column.add_child(_name_field)
		_naming.add_child(column)
		_naming.confirmed.connect(func() -> void: name_submodel(_name_field.text))
		add_child(_naming)
	_name_field.text = builder.unused_group("Sub-model")
	_naming.popup_centered()
	_name_field.grab_focus()
	_name_field.select_all()


func name_submodel(name: String) -> int:
	var called: String = name.strip_edges()
	if called.is_empty():
		called = builder.unused_group("Sub-model")
	var count: int = builder.name_group(called)
	if count > 0:
		edited.call()
		say.call("“%s” is a sub-model of %s — Same sub-model, under Select, takes it all" % [
			called, _parts(count)])
	return count


func leave_submodel() -> int:
	var count: int = builder.name_group("")
	if count > 0:
		edited.call()
		say.call("took %s out of its sub-model" % _parts(count))
	return count


## Back through the history to before the step ``count`` steps ago.
func go_back(count: int) -> int:
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
			var wanted: Dictionary = {}
			for seed_id: int in seeds:
				for brick_id: int in SelectBy.matching(kind, world, seed_id, scenery):
					wanted[brick_id] = true
			found = wanted.keys()
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
	builder.selection.clear()
	for brick_id: int in found:
		if not builder.lattice.unseen.has(brick_id) and not builder.is_locked(brick_id):
			builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	return builder.selection.size()


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
	say.call("hid %s — H with nothing selected shows everything" % _parts(ids.size()))
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
	say.call("showing only %s — Alt-H or H shows everything" % _parts(keep.size()))
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


## A copy of the selection in hand at once: copy and paste in one key,
## leaving the clipboard as it was.
func duplicate_selection() -> int:
	var alive: Array = builder.selection.keys()
	if alive.is_empty():
		say.call("select something to duplicate first")
		return 0
	var parts: Array = Carry.gather(world, library, alive)
	if parts.is_empty():
		return 0
	builder.cancel_carry()
	builder.hold_copy(parts)
	aim_again.call()
	say.call("holding a copy of %s — click to put it down, R turns, Esc puts away"
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


## Turn the selection where it stands by any angle: the turn step, from R
## and the Rotate tool.
func turn_by(degrees: float) -> int:
	var count: int = builder.turn_selection_by(degrees)
	if count == 0:
		say.call("no room to turn it there")
		return 0
	edited.call()
	aim_again.call()
	say.call("turned %s %+d°" % [_parts(count), roundi(degrees)])
	return count


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
const MODES: Array[String] = ["build", "select", "move", "rotate", "hinge",
	"clone", "paint", "hide", "delete"]
var mode: String = "build"
signal mode_changed(mode: String)

## How far R and the Rotate tool turn a selection, in degrees. The part in
## hand always turns a quarter: it is put down on the studs.
var turn_step: float = 90.0

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
	if not MODES.has(to) or to == mode:
		return
	mode = to
	if measure != null and measure.active:
		measure.leave()
	if to != "build" and not builder.is_carrying():
		builder.hide_preview()
	mode_changed.emit(mode)
	aim_again.call()


## What the active tool does, for the status bar.
func hint() -> String:
	match mode:
		"select":
			return "Select: click a part, Shift-click to add or take one away, drag a box round several"
		"move":
			return "Move: click a part to pick it up (the whole selection, if it is in it), click again to put it down"
		"rotate":
			return "Rotate: click a part to turn it %d° (Shift-click turns it back)" % roundi(turn_step)
		"hinge":
			return "Hinge: click a part on a hinge, clip or turntable to swing it %d° (Shift-click swings it back)" % roundi(SWING)
		"clone":
			return "Clone: click a part to hold a copy of it, then click where the copy goes"
		"paint":
			return "Paint: click a part to paint it the colour in hand"
		"hide":
			return "Hide: click a part to hide it — Alt-H shows everything again"
		"delete":
			return "Delete: click a part to take it off"
	return "Build: click to put the part down — right-click takes one off, Shift-click selects"


## Whether the ghost of the part in hand belongs under the pointer: in
## Build, and while anything is carried, whatever the tool.
func shows_ghost() -> bool:
	return mode == "build" or builder.is_carrying() or builder.is_holding_figure()


## The part under a point on the screen, or 0 for none, the baseplate or a
## hidden one.
func brick_at(at: Vector2) -> int:
	if camera == null:
		return 0
	var hit: BrickLattice.Hit = builder.lattice.raycast(
		camera.project_ray_origin(at), camera.project_ray_normal(at))
	if not hit.is_valid() or scenery.has(hit.brick_id):
		return 0
	return hit.brick_id


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
