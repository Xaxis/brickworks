## simple4: Simple sets aside what Full shows, not only where it places
## (simplereview4 F1-F3, H1). Full's cut, x-ray, exploded view, Stress and
## Stud directions are off while Simple is up and back as they were in Full;
## the cut the model's file keeps is kept; a brick put in Simple is seen when
## Full's timeline comes back; the switch says which is chosen from the start.
## Hidden parts, the author's steps and a carry with Full's tool on Place are
## simplereview4_probe's cases (hidden, steps, carry, ctx).
##
##   godot --headless --path . --script src/dev/simple4_probe.gd -- --headless-ok --desktop
##   godot --headless --path . --script src/dev/simple4_probe.gd -- --headless-ok
##
## --case= cut, shape, xray, explode, tints, planned, steps, switch (all when not said):
##   cut      a plane cut in Full: in Simple none (drawn, in the pointer's way),
##            the model's text byte for byte (its cut line kept); a brick put
##            on a part the cut took away; back in Full the same cut.
##   shape    the same with a box cut round a part.
##   xray     x-ray of a selection in Full: off in Simple, the same parts seen
##            through back in Full.
##   explode  the exploded view: every part drawn where it stands in Simple,
##            apart again in Full; together after a brick put in Simple.
##   tints    Stress, then Stud directions: off in Simple and nothing said,
##            on again in Full.
##   planned  a model with no steps, the timeline on its first worked-out step:
##            a brick put in Simple on a part ahead of it is on show in Full.
##   steps    the author's steps on step 1: the brick put in Simple is in step
##            1, before the file's first STEP, and on show in Full on step 1.
##   switch   Simple | Full made with Full chosen; chosen as the controls are,
##            pressed and said ("Chosen").
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview4_probe.gd"

const AppHeader := preload("res://src/ui/app_header.gd")
## Two sub-assemblies and a plain brick: the exploded view takes a model
## apart only where it has two sections or more (Sections.explode_groups).
const EXPLODE_MODEL := """0 FILE s4_explode.ldr
0 Name: s4_explode.ldr
1 4 -40 -8 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 -60 -8 -60 1 0 0 0 1 0 0 0 1 s4_wing.ldr
1 1 60 -8 40 1 0 0 0 1 0 0 0 1 s4_tail.ldr
0 NOFILE
0 FILE s4_wing.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
0 FILE s4_tail.ldr
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""


func _run() -> void:
	if not await _start("cut,shape,xray,explode,tints,planned,steps,switch"):
		return
	for one: String in ["cut", "shape", "xray", "explode", "tints", "planned", "steps", "switch"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"cut":
				await _case_cut(false)
			"shape":
				await _case_cut(true)
			"xray":
				await _case_xray()
			"explode":
				await _case_explode()
			"tints":
				await _case_tints()
			"planned":
				await _case_planned()
			"steps":
				await _case_steps4()
			"switch":
				await _case_switch()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simple4_probe"


func _wing_top() -> int:
	var top: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not Assemblies.path_of(brick).is_empty() and (top == 0 or _box_of(brick.id).end.y > _box_of(top).end.y):
			top = brick.id
	return top


## Whether the lattice passes a ray through anything as the eye does (a cut).
func _lattice_cut() -> bool:
	return _builder.lattice.cut != Plane() or _builder.lattice.cut_shape != null


# -- cut ------------------------------------------------------------------------------


func _case_cut(by_shape: bool) -> void:
	await _from_full_open()
	_builder.forget_history()
	var see: SeeInside = _shell().see_inside
	var top: int = _wing_top()
	var tag: String = "box" if by_shape else "plane"
	if by_shape:
		_builder.clear_selection()
		_builder.select_brick(top, false)
		see.cut_by(CutShape.BOX)
		_builder.clear_selection()
	else:
		see.cut_along(1)
	await _frames(4)
	var kept: Dictionary = _world.cut_kept.duplicate(true)
	var scheme: String = str(see.scheme())
	var text: String = _text()
	_note2("[%s] Full cuts: %s; the text has the cut line %s" % [tag, scheme, str(text.contains(CutShape.META))])
	if not _check("[%s] Full's cut on" % tag, see.cutting and _world.is_cut() and _lattice_cut()):
		see.set_cut(false)
		return
	await _to_simple()
	_check("[%s] in Simple no cut: drawn whole, nothing passed through (cutting %s, drawn cut %s, lattice %s)" % [
		tag, see.cutting, _world.is_cut(), _lattice_cut()], not see.cutting and not _world.is_cut() and not _lattice_cut())
	_check("[%s] ...the model keeps its cut: the text byte for byte, cut_kept the same" % tag,
		_text() == text and str(_world.cut_kept) == str(kept))
	var on_top: Vector2 = _top_point(top)
	var put: int = await _put("3005", 14, on_top)
	await _seat_done()
	var joined: Array = SelectBy.connected(_world, _builder.lattice, [put], _store.scenery, 2) if put != 0 else []
	_note2("[%s] a 1 x 1 let go on the wing's top (the part the cut took away): put %d, joined to %s, the wing's top %d" % [
		tag, put, str(joined), top])
	_check("[%s] ...a brick put on the part Full's cut took away stands on it" % tag, put != 0 and joined.has(top))
	await _to_full()
	_check("[%s] back in Full the same cut (%s)" % [tag, str(see.scheme())],
		see.cutting and _world.is_cut() and _lattice_cut() and str(see.scheme()) == scheme)
	await _undo_full()
	_check("[%s] ...Undo gives the text as it was, the cut line with it" % tag, _text() == text)
	see.set_cut(false)
	await _frames(2)


# -- x-ray ----------------------------------------------------------------------------


func _case_xray() -> void:
	await _from_full_open()
	var see: SeeInside = _shell().see_inside
	var red: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 4 and b.group.is_empty())
	_builder.clear_selection()
	_builder.select_brick(red, false)
	see.set_xray(true)
	await _frames(3)
	var ghosts: Array = _builder.lattice.see_through.keys()
	ghosts.sort()
	if not _check("Full's x-ray on the red 2 x 4 (%d parts seen through)" % ghosts.size(),
			see.seeing_through and not ghosts.is_empty()):
		return
	await _to_simple()
	_check("in Simple no x-ray (seeing through %s, %d parts passed through, %d drawn so)" % [see.seeing_through,
		_builder.lattice.see_through.size(), _world.xray_ids().size()],
		not see.seeing_through and _builder.lattice.see_through.is_empty() and _world.xray_ids().is_empty())
	await _to_full()
	var now: Array = _builder.lattice.see_through.keys()
	now.sort()
	_check("back in Full the same parts seen through (%s)" % str(now), see.seeing_through and now == ghosts
		and _world.xray_ids().size() == ghosts.size())
	see.set_xray(false)
	_builder.clear_selection()
	await _frames(2)


# -- explode --------------------------------------------------------------------------


## The parts drawn elsewhere than they stand.
func _drawn_apart() -> int:
	var apart: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _world.drawn_at(brick).origin.is_equal_approx(brick.transform.origin):
			apart += 1
	return apart


func _case_explode() -> void:
	for variant: String in ["nothing", "put"]:
		await _open_saved(EXPLODE_MODEL, "s4_explode.ldr")
		var sections: Node = _shell().sections
		sections.call("explode_now", true)
		await _frames(3)
		var apart: int = _drawn_apart()
		_note2("[%s] Full's exploded view: %s, %d parts drawn apart" % [variant,
			str(sections.call("is_exploded")), apart])
		if not _check("[%s] Full drawn apart" % variant, bool(sections.call("is_exploded")) and apart > 0):
			return
		await _to_simple()
		_check("[%s] in Simple every part drawn where it stands (%d apart)" % [variant, _drawn_apart()],
			_drawn_apart() == 0)
		if variant == "put":
			var put: int = await _put("3003", 14, _base_point(0.4, 0.4))
			await _seat_done()
			_check("[%s] a brick put in Simple (%d)" % [variant, put], put != 0)
		await _to_full()
		await _frames(4)
		if variant == "nothing":
			_check("[%s] back in Full drawn apart as it was (%d apart)" % [variant, _drawn_apart()],
				bool(sections.call("is_exploded")) and _drawn_apart() == apart)
		else:
			_check("[%s] back in Full, the model changed: together, as any change brings it (%s, %d apart)" % [
				variant, str(sections.call("is_exploded")), _drawn_apart()],
				not bool(sections.call("is_exploded")) and _drawn_apart() == 0)
		sections.call("explode_now", false)
		await _frames(2)


# -- Stress, Stud directions ----------------------------------------------------------


func _case_tints() -> void:
	await _from_full_open()
	var shell: Shell = _shell()
	for which: String in ["stress", "stud_map"]:
		var view: Node = shell.stress if which == "stress" else shell.stud_map
		view.call("set_on", true)
		await _frames(6)
		_check("[%s] on in Full" % which, bool(view.get("on")))
		_say_nothing()
		await _to_simple()
		var said: String = _said().to_lower()
		_check("[%s] off in Simple (on %s, stressed %s), nothing said of it (\"%s\")" % [which,
			str(view.get("on")), str(_world.is_stressed()), said], not bool(view.get("on"))
			and not _world.is_stressed() and not said.contains("stress") and not said.contains("stud"))
		await _to_full()
		await _frames(4)
		_check("[%s] on again in Full" % which, bool(view.get("on")))
		view.call("set_on", false)
		await _frames(2)


# -- the timeline ---------------------------------------------------------------------


func _timeline_on(step: int) -> bool:
	var steps: StepsBar = _main.get("_steps")
	_main.call("_toggle_steps")
	for _n: int in 300:
		await process_frame
		if steps.is_playing_back():
			break
	await _frames(10)
	steps.show_step(step)
	await _frames(6)
	return steps.is_playing_back()


func _timeline_back() -> void:
	var steps: StepsBar = _main.get("_steps")
	for _n: int in 300:
		await process_frame
		if steps.is_playing_back():
			break
	await _frames(10)


## A model with no steps, worked out: a brick put in Simple on the wing's top,
## a part the first step leaves for later.
func _case_planned() -> void:
	await _from_full_open()
	_builder.forget_history()
	var steps: StepsBar = _main.get("_steps")
	var top: int = _wing_top()
	if not await _timeline_on(1):
		_check("the timeline on", false)
		return
	_note2("Full: the timeline on step %d of %d (mode %d), %d parts ahead, the wing's top ahead %s" % [
		steps.current_step().number if steps.current_step() != null else -1, steps.steps().size(), steps.mode(),
		_builder.lattice.ahead.size(), str(_builder.lattice.ahead.has(top))])
	await _to_simple()
	var put: int = await _put("3005", 14, _top_point(top))
	await _seat_done()
	_check("a 1 x 1 put in Simple on the wing's top (%d)" % put, put != 0)
	await _to_full()
	await _timeline_back()
	var now: Instructions.Step = steps.current_step()
	_check("back in Full the brick put in Simple is on show (step %d of %d, ahead %s)" % [
		now.number if now != null else -1, steps.steps().size(), str(_builder.lattice.ahead.has(put))],
		put != 0 and steps.is_playing_back() and not _builder.lattice.ahead.has(put))
	steps.stop()
	await _frames(4)


## The author's steps on step 1: the brick is in step 1, as Full's own put.
func _case_steps4() -> void:
	await _open_saved(STEPS_MODEL, "sr4_steps.ldr")
	var steps: StepsBar = _main.get("_steps")
	if not await _timeline_on(1):
		_check("the timeline on", false)
		return
	var first: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 4)
	await _to_simple()
	var put: int = await _put("3003", 14, _base_point(0.4, 0.4))
	await _seat_done()
	var brick: BrickWorld.Brick = _world.get_brick(put)
	var text: String = _text()
	var line_at: int = -1
	var step_at: int = -1
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if line_at < 0 and lines[n].ends_with("3003.dat"):
			line_at = n
		if step_at < 0 and lines[n].strip_edges() == "0 STEP":
			step_at = n
	_check("the brick put in Simple is in step 1 as Full's own put would be (its step %d, the first part's %d; its line %d, the first STEP's %d)" % [
		brick.step if brick != null else -9, _world.get_brick(first).step, line_at, step_at],
		brick != null and brick.step == _world.get_brick(first).step and line_at >= 0 and line_at < step_at)
	await _to_full()
	await _timeline_back()
	var now: Instructions.Step = steps.current_step()
	_check("back in Full on step 1, the brick on show (step %d, ahead %s)" % [now.number if now != null else -1,
		str(_builder.lattice.ahead.has(put))], now != null and now.number == 1 and not _builder.lattice.ahead.has(put))
	steps.stop()
	await _frames(4)


# -- the switch -----------------------------------------------------------------------


func _chosen_of(frame: PanelContainer) -> Array:
	var out: Array = []
	if frame == null:
		return out
	for child: Node in frame.get_child(0).get_children():
		var button: Button = child as Button
		if button.button_pressed:
			out.append("%s (%s)" % [str(button.get_meta("controls")), button.accessibility_description])
	return out


func _case_switch() -> void:
	var made: PanelContainer = AppHeader.controls_switch(1.0, false, func(_layer: StringName) -> void: pass)
	_check("Simple | Full made shows Full chosen, said so: %s" % str(_chosen_of(made)),
		_chosen_of(made) == ["full (Chosen)"])
	made.free()
	var frame: PanelContainer = _phone.get("_switch") if _phone != null else (_main.get("_bar") as ModelBar).controls
	await _to_full()
	_check("in Full the header's switch: %s" % str(_chosen_of(frame)), _chosen_of(frame) == ["full (Chosen)"])
	await _to_simple()
	_check("in Simple the header's switch: %s" % str(_chosen_of(frame)), _chosen_of(frame) == ["simple (Chosen)"])
