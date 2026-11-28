## simplefix5: nothing Simple sets aside of Full's view moves where a tap
## lands (simplereview5 F1: after Full's exploded view a tap in Simple picked
## the part drawn where its section would have been, or none), and Full gets
## its view back exactly. Headless (a CPU slot) the layer's own calls stand
## for a finger, as simplereview3-5 do; in a window the same calls.
##
##   godot --path . --resolution 390x844 --script src/dev/simplefix5_probe.gd
##   godot --headless --path . --script src/dev/simplefix5_probe.gd -- --headless-ok --desktop
##   godot --headless --path . --script src/dev/simplefix5_probe.gd -- --headless-ok
##   PROBE_SIZE=1280x800 tools/probe.sh simplefix5_probe -- --desktop
##   tools/probe.sh simplefix5_probe -- --headless-ok [--desktop] [--case=apart]
##
## --case= apart, views, pick (all when not said):
##   apart   Full's exploded view, its picks taken at each part where it is
##           drawn apart. In Simple: nothing drawn moved, SectionsUi.pick_drawn
##           moves no ray, a tap where each part is drawn picks it, a finger's
##           tap chooses it and a finger's drag carries it (Undo exact). Back
##           in Full: every part drawn exactly where it was, the camera as it
##           was, and each of Full's picks the same part as before.
##   views   every other piece of Full's view a pick, a ghost or a drop reads,
##           one at a time and all at once: the timeline on step 2, Show only
##           the selection, a plane cut, a box cut, x-ray, inside a
##           sub-assembly with its x-ray, and hidden + cut + exploded. In
##           Simple: no part passed through (hidden, seen through, ahead of
##           the step, cut), none drawn moved or hidden, a tap where each part
##           is drawn picks it. Back in Full each as it was.
##   pick    simplereview5's own pick case, unchanged.
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview5_probe.gd"


func _run() -> void:
	if not await _start("apart,views,pick"):
		return
	for one: String in ["apart", "views", "pick"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"apart":
				await _case_apart()
			"views":
				await _case_views()
			"pick":
				await _case_pick()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplefix5_probe"


# -- what is drawn and what a ray passes through ---------------------------------------


## The middle of each part's top where the world draws it (drawn apart or
## not), on the screen and inside the model's room: [id, point] each.
func _points_as_drawn() -> Array:
	var out: Array = []
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect()) if _simple.visible \
		else root.get_visible_rect()
	for id: Variant in _plain_ids():
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = _world.drawn_at(brick) * part.bounds
		var at: Vector2 = _camera.unproject_position(Vector3(box.get_center().x, box.end.y - 2.0,
			box.get_center().z))
		if room.has_point(at):
			out.append([int(id), at])
	return out


## What a click picks at each of [param points] ([id, point] each).
func _picked_at(points: Array) -> Array:
	var out: Array = []
	for one: Array in points:
		out.append(_verbs.brick_at(one[1] as Vector2))
	return out


## The part drawn nearest the eye under [param at]: the first box, where the
## world draws it, that the ray meets, hidden parts left out. Read from the
## drawing alone, not the lattice, so it says what a person sees there (every
## part of these models is a box: 3001, 3003). 0 for none.
func _drawn_under(at: Vector2) -> int:
	var origin: Vector3 = _camera.ray_origin(at)
	var normal: Vector3 = _camera.ray_normal(at)
	var best: int = 0
	var nearest: float = INF
	for id: Variant in _plain_ids():
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null or brick.hidden:
			continue
		var met: Variant = (_world.drawn_at(brick) * part.bounds).intersects_ray(origin, normal)
		if met != null and origin.distance_to(met as Vector3) < nearest:
			nearest = origin.distance_to(met as Vector3)
			best = int(id)
	return best


## How many of [param points] a click picks the part drawn there: [right,
## wrong lines].
func _picks_as_drawn(points: Array) -> Array:
	var right: int = 0
	var wrong: Array = []
	for one: Array in points:
		var at: Vector2 = one[1]
		var seen: int = _drawn_under(at)
		var found: int = _verbs.brick_at(at)
		if found == seen:
			right += 1
		else:
			wrong.append("at %s: drawn %d, picked %d" % [str(at.round()), seen, found])
	return [right, wrong]


## What of Full's view is left that passes a ray through a part, moves where
## one is drawn or hides one: [] when nothing.
func _view_left() -> Array:
	var lattice: BrickLattice = _builder.lattice
	var left: Array = []
	if not lattice.unseen.is_empty():
		left.append("%d hidden" % lattice.unseen.size())
	if not lattice.see_through.is_empty():
		left.append("%d seen through" % lattice.see_through.size())
	if not lattice.ahead.is_empty():
		left.append("%d ahead of the step" % lattice.ahead.size())
	if lattice.cut != Plane() or lattice.cut_shape != null:
		left.append("a cut")
	if not _world.drawn_ids().is_empty():
		left.append("%d drawn moved" % _world.drawn_ids().size())
	if not _world.xray_ids().is_empty():
		left.append("%d drawn see-through" % _world.xray_ids().size())
	if _world.is_cut():
		left.append("drawn cut")
	var hidden: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.hidden:
			hidden += 1
	if hidden > 0:
		left.append("%d drawn hidden" % hidden)
	if not (_world.get("_reveal_order") as PackedInt64Array).is_empty():
		left.append("a step being revealed")
	var sections: Node = _shell().sections
	for one: Array in _points_as_drawn():
		var at: Vector2 = one[1]
		var moved: int = int(sections.call("pick_drawn", _camera.ray_origin(at), _camera.ray_normal(at)))
		if moved >= 0:
			left.append("pick_drawn moves the ray at %s (%d)" % [str(at.round()), moved])
			break
	return left


## Full's view as a pick, a ghost and a drop read it, to compare.
func _full_view_now() -> Dictionary:
	var lattice: BrickLattice = _builder.lattice
	var drawn: Array = []
	for id: Variant in _world.drawn_ids():
		drawn.append("%d:%s" % [int(id), str((_world.drawn_ids()[id] as Transform3D).origin.snapped(
			Vector3.ONE * 0.01))])
	drawn.sort()
	var keys := func(set: Dictionary) -> Array:
		var out: Array = set.keys()
		out.sort()
		return out
	return {"unseen": keys.call(lattice.unseen), "see_through": keys.call(lattice.see_through),
		"ahead": keys.call(lattice.ahead), "cut": str(lattice.cut), "cut_shape": lattice.cut_shape != null,
		"drawn": drawn, "xray": keys.call(_world.xray_ids()), "drawn_cut": _world.is_cut(),
		"entered": _shell().assemblies.entered, "exploded": bool(_shell().sections.call("is_exploded"))}


## In Simple: nothing of Full's view left, and a tap where each part is drawn
## picks the part the ray meets, as Simple draws it.
func _simple_picks_right(tag: String) -> void:
	var left: Array = _view_left()
	_check("[%s] in Simple nothing of Full's view left (%s)" % [tag, ", ".join(left)], left.is_empty())
	var points: Array = _points_as_drawn()
	var got: Array = _picks_as_drawn(points)
	for line: String in (got[1] as Array).slice(0, 6):
		_note2("  %s" % line)
	_check("[%s] ...a tap where each part is drawn picks the part drawn there (%d of %d)" % [tag, got[0],
		points.size()], int(got[0]) == points.size() and points.size() >= 3)


# -- apart -----------------------------------------------------------------------------


func _case_apart() -> void:
	await _open_saved(EXPLODE_MODEL, "sf5_apart.ldr")
	var sections: Node = _shell().sections
	sections.call("explode_now", true)
	await _frames(3)
	var full_view: Dictionary = _full_view_now()
	var full_camera: Transform3D = _camera.global_transform
	var full_points: Array = _points_as_drawn()
	var full_picks: Array = _picked_at(full_points)
	var full_got: Array = _picks_as_drawn(full_points)
	_note2("Full apart: %d parts drawn moved, picks %s at %s %s" % [_drawn_apart(), str(full_picks),
		str(full_points.map(func(one: Array) -> Vector2: return (one[1] as Vector2).round())), str(full_got[1])])
	if not _check("Full drawn apart, and a click where a part is drawn apart picks the part drawn there (%d of %d)"
			% [full_got[0], full_points.size()], _drawn_apart() > 0 and int(full_got[0]) == full_points.size()
			and full_points.size() >= 4):
		sections.call("explode_now", false)
		return
	await _to_simple()
	await _settle()
	_simple_picks_right("apart")
	# A finger's tap, then a finger's drag, on each part where it is drawn.
	var text: String = _text()
	var chose: int = 0
	var carried: int = 0
	var tried: int = 0
	for one: Array in _points_as_drawn():
		var at: Vector2 = one[1]
		var seen: int = _drawn_under(at)
		if seen == 0:
			continue
		tried += 1
		await _layer_tap(at)
		if _builder.selection.has(seen):
			chose += 1
		else:
			_note2("  a tap on %d at %s chose %s" % [seen, str(at.round()), str(_builder.selection.keys())])
		_simple.call("_pick", [])
		await _frames(2)
		var to: Vector2 = _base_point(0.55, 0.55)
		_simple.call("_press", at, 0)
		for k: int in range(1, 9):
			_simple.call("_drag", at.lerp(to, k / 8.0))
			await process_frame
		_simple.call("_release", to)
		await _frames(3)
		await _seat_done()
		var drop: Dictionary = _simple.get("last_drop")
		var moved: Array = drop.get("put", [])
		if str(drop.get("from", "")) == "model" and moved.has(seen):
			carried += 1
		else:
			_note2("  a drag from %d at %s carried %s" % [seen, str(at.round()), str(moved)])
		if _text() != text:
			await _press_button("undo")
			await _frames(2)
		if _text() != text:
			_restore(text)
		_simple.set("last_drop", {})
		_builder.clear_selection()
	_check("[apart] a finger's tap chooses the part it is on (%d of %d)" % [chose, tried],
		chose == tried and tried >= 4)
	_check("[apart] a finger's drag carries the part it is on (%d of %d), Undo exact" % [carried, tried],
		carried == tried and _text() == text)
	await _to_full()
	await _frames(4)
	var back_view: Dictionary = _full_view_now()
	var differ: Array = _differ(full_view, back_view)
	_check("[apart] back in Full every part drawn where it was, apart (%s)" % str(differ),
		differ.is_empty() and _drawn_apart() > 0)
	_check("[apart] ...the camera as it was", _camera.global_transform.is_equal_approx(full_camera))
	var back_picks: Array = _picked_at(full_points)
	_check("[apart] ...and a click at each part drawn apart picks the same part (%s, was %s)" % [
		str(back_picks), str(full_picks)], str(back_picks) == str(full_picks))
	sections.call("explode_now", false)
	await _frames(2)


# -- views -----------------------------------------------------------------------------


func _case_views() -> void:
	for view: String in ["timeline", "isolate", "plane cut", "box cut", "x-ray", "inside", "all"]:
		await _open_saved(EXPLODE_MODEL if view != "timeline" else STEPS_MODEL, "sf5_views.ldr")
		var shell: Shell = _shell()
		var see: SeeInside = shell.see_inside
		var plain: int = _id_where(func(b: BrickWorld.Brick) -> bool: return Assemblies.path_of(b).is_empty())
		var wing_part: int = _id_where(func(b: BrickWorld.Brick) -> bool: return not Assemblies.path_of(b).is_empty())
		_builder.clear_selection()
		match view:
			"timeline":
				await _timeline_on(2)
			"isolate":
				_builder.select_brick(plain, false)
				_verbs.isolate()
			"plane cut":
				see.cut_along(1)
			"box cut":
				_builder.select_brick(plain, false)
				see.cut_by(CutShape.BOX)
			"x-ray":
				_builder.select_brick(plain, false)
				see.set_xray(true)
			"inside":
				_builder.select_brick(wing_part, false)
				var wing: String = shell.assemblies.selected_assembly()
				_builder.clear_selection()
				shell.assemblies.enter(wing)
				await _frames(3)
				see.set_xray(true)
			"all":
				_builder.select_brick(plain, false)
				_verbs.hide_selection()
				_builder.clear_selection()
				see.cut_along(1)
				await _frames(3)
				shell.sections.call("explode_now", true)
		_builder.clear_selection()
		await _frames(4)
		var full_view: Dictionary = _full_view_now()
		var set_in_full: Array = _view_left()
		_note2("[%s] Full: %s" % [view, ", ".join(set_in_full)])
		if not _check("[%s] set in Full" % view, not set_in_full.is_empty()):
			continue
		await _to_simple()
		await _settle()
		_simple_picks_right(view)
		await _to_full()
		if view == "timeline":
			await _timeline_back()
		await _frames(6)
		var differ: Array = _differ(full_view, _full_view_now())
		_check("[%s] back in Full as it was (%s)" % [view, str(differ)], differ.is_empty())
		var steps: StepsBar = _main.get("_steps")
		if steps.is_playing_back():
			steps.stop()
		shell.sections.call("explode_now", false)
		see.set_xray(false)
		see.set_cut(false)
		_verbs.show_all()
		if not shell.assemblies.entered.is_empty():
			shell.assemblies.leave_to("")
		await _frames(2)
