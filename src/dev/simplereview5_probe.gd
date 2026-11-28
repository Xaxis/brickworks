## simplereview5: the fifth independent review's attacks on simple4 (Simple
## stands every part on what is under it, Builder.stands_only and
## Carry.rests; Full's view set aside while Simple is up and put back).
## Headless (a CPU slot): the layer's own calls stand for a finger, as
## simplereview3/4 do (no touch reaches the layer headless); in a window the
## same calls, so both runs try the same inputs.
##
##   godot --path . --resolution 390x844 --script src/dev/simplereview5_probe.gd
##   godot --headless --path . --script src/dev/simplereview5_probe.gd -- --headless-ok --desktop
##   godot --headless --path . --script src/dev/simplereview5_probe.gd -- --headless-ok
##   PROBE_SIZE=1280x800 tools/probe.sh simplereview5_probe -- --desktop
##   tools/probe.sh simplereview5_probe -- --headless-ok [--desktop] [--case=faces,pick]
##
## --case= faces, big, ghosts, pick, save, dirty, middrag, modes, full (all when not said):
##   faces    a scene on Simple's plate (a stack, an overhang, a turned brick,
##            a slope, a plate, an inverted slope, an arch) seen from five
##            sides: eight tray parts, upright and turned, aimed over every
##            part's picture. Each ghost offered stands on something (its cover
##            moved down a cell meets a part or the ground) and is not inside
##            one; every third point a drop lands exactly where its ghost was,
##            stands, and Undo gives the text back; every sixth a stack and the
##            turned brick dragged there by a finger, the same.
##   big      the same aims and drops over corner_shop (797 parts), three views;
##            a ghost in the air is told whole and aimed again alone by its ray.
##   ghosts   the two rays big aimed an inverted slope in the air along (after
##            faces), alone over corner_shop, in Simple and in Full: no ghost
##            4 LDU or more over what is under it, let go it stands.
##   pick     Full's exploded view, then Simple: a tap on each part where Simple
##            draws it chooses that part (EditVerbs.brick_at still asks the
##            sections apart).
##   save     a saved file: Simple drops, a drag, Undo, Redo, Delete; each Undo
##            gives the text back exactly, each Redo the text after the act;
##            Save then reopen: every part as the world had it.
##   dirty    hidden, cut, x-ray, exploded, Stress on in Full and saved: a trip
##            to Simple and back with nothing done is no unsaved work, the text
##            byte for byte.
##   middrag  Simple's drag of a part when Full comes up mid-way, and Full's
##            drag when Simple comes up mid-way (then a tap, then Undo): every
##            part kept, Undo exact.
##   modes    Full's view, tool, sub-assembly and timeline step all at once,
##            switched by the header's Simple | Full buttons, with and without a
##            brick put in Simple: back exactly.
##   full     Full's aims over the scene before and after a trip to Simple
##            (with a drop and its Undo): ghost for ghost the same, side faces
##            still at the height they imply, stands_only off.
## Exits non-zero when a check fails.
extends "res://src/dev/simple4_probe.gd"

## Parts tried from the tray: a 1 x 1 and a 2 x 4 brick, a 1 x 2 plate, a
## 2 x 2 slope, an inverted slope, a 1 x 1 round brick, a 1 x 4 arch, a
## 2 x 1 slope.
const TRY_PARTS: Array = ["3005", "3001", "3023b", "3039", "3665a", "3062b", "3659", "3040b"]
const FACE_VIEWS: Array = [
	["front, high", Vector3(0.3, 0.75, 1.0)],
	["right, low", Vector3(1.0, 0.12, 0.25)],
	["back, low", Vector3(-0.35, 0.15, -1.0)],
	["left, level", Vector3(-1.0, 0.04, 0.4)],
	["front, low", Vector3(0.2, 0.08, 1.0)],
]
const GRID5 := 6

var _offered_n: int = 0
var _aimed5: int = 0
var _drops5: int = 0
var _drags5: int = 0
var _air: Array = []
var _near: Array = []
var _inside: Array = []
var _off_ghost: Array = []
var _undo_wrong: Array = []
var _scene: Dictionary = {}


func _run() -> void:
	if not await _start("faces,big,ghosts,pick,save,dirty,middrag,modes,full"):
		return
	for one: String in ["faces", "big", "ghosts", "pick", "save", "dirty", "middrag", "modes", "full"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"faces":
				await _case_faces()
			"big":
				await _case_big()
			"ghosts":
				await _case_ghosts()
			"pick":
				await _case_pick()
			"save":
				await _case_save()
			"dirty":
				await _case_dirty()
			"middrag":
				await _case_middrag()
			"modes":
				await _case_modes()
			"full":
				await _case_full()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplereview5_probe"


# -- the scene -------------------------------------------------------------------------


## [param part] put exactly at stud [param cx], [param cz] of the plate's low
## corner, its foot at [param foot] (LDU, up), [param turn] quarter turns: as
## one step Undo takes back (Builder.put_part). Its id.
func _place5(part: String, colour: int, cx: int, cz: int, foot: float, turn: int = 0) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	if mesh == null:
		_note2("no mesh for %s" % part)
		return 0
	var basis := Basis(Vector3.UP, turn * PI * 0.5)
	var box: AABB = Transform3D(basis, Vector3.ZERO) * mesh.bounds
	var floor: AABB = _floor_box()
	var at := Vector3(floor.position.x + cx * 20.0 - box.position.x, foot - box.position.y,
		floor.position.z + cz * 20.0 - box.position.z)
	return _builder.put_part(part, colour, Transform3D(basis, at))


## The top of a part's body (its studs' foot), LDU.
func _top_of(id: int) -> float:
	return _box_of(id).end.y - 4.0


func _face() -> float:
	return _floor_box().end.y - 4.0


func _build_scene5() -> Dictionary:
	await _to_simple()
	await _fresh()
	var s: Dictionary = {}
	var face: float = _face()
	s["red"] = _place5("3001", 4, 2, 2, face)
	s["blue"] = _place5("3001", 1, 2, 2, _top_of(int(s["red"])))
	s["post"] = _place5("3004", 15, 8, 2, face)
	s["over"] = _place5("3020", 14, 8, 2, _top_of(int(s["post"])))
	s["turned"] = _place5("3001", 2, 2, 8, face, 1)
	s["slope"] = _place5("3039", 25, 8, 8, face)
	s["plate"] = _place5("3023b", 14, 12, 2, face)
	s["inverted"] = _place5("3665a", 4, 12, 8, face)
	s["arch"] = _place5("3659", 1, 5, 12, face)
	await _frames(4)
	_builder.forget_history()
	_builder.clear_selection()
	_note2("scene: %s" % str(s))
	for key: String in s:
		var box: AABB = _box_of(int(s[key]))
		_note2("  %s %d: box %s" % [key, int(s[key]), str(box)])
	await _press_fit()
	return s


# -- support and overlap ---------------------------------------------------------------


static func _lowest5(cover: PackedInt32Array) -> int:
	var low: int = 1 << 30
	var n: int = 1
	while n < cover.size():
		low = mini(low, cover[n])
		n += 6
	return low


## Cells the cover [param cover] could drop before it meets a part not in
## [param own] or the ground: 0 rests on something, 8 for 8 or more.
func _gap5(cover: PackedInt32Array, own: Dictionary) -> int:
	if cover.is_empty():
		return -1
	var low: int = _lowest5(cover)
	for k: int in range(1, 9):
		if low - k < Builder.GROUND_CELL:
			return k - 1
		var moved: PackedInt32Array = BrickLattice.moved_by(cover, Vector3i(0, -k, 0))
		for id: int in _builder.lattice.blockers_boxes(moved, 0):
			if not own.has(id):
				return k - 1
	return 8


## The parts of [param ids] other than themselves their covers meet.
func _overlaps5(ids: Array) -> Array:
	var own: Dictionary = {}
	for id: Variant in ids:
		own[int(id)] = true
	var out: Array = []
	for id: Variant in ids:
		for other: int in _builder.lattice.blockers_boxes(_builder.lattice.boxes_of(int(id)), int(id)):
			if not own.has(other):
				out.append("%d in %d" % [int(id), other])
	return out


## The group [param ids] rests: one of its parts rests on a part outside it or
## the ground. The least gap of any.
func _group_gap(ids: Array) -> int:
	var own: Dictionary = {}
	for id: Variant in ids:
		own[int(id)] = true
	var least: int = 99
	for id: Variant in ids:
		least = mini(least, _gap5(_builder.lattice.boxes_of(int(id)), own))
	return least


func _name_of(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return brick.part_id if brick != null else "?"


## The ghost now offered, aimed at [param at]: whether it stands, and whether
## it is inside a part. One in the air is told whole (what it was aimed at,
## its box, the surface under the box, what its cover meets going down) and
## its ray kept, to be aimed again alone ([method _air_again]).
func _judge_ghost(tag: String, part: String, at: Vector2 = Vector2.INF) -> void:
	_offered_n += 1
	var t: Transform3D = _builder.ghost_transform()
	var cover: PackedInt32Array = _builder.boxes_for(_library.mesh_for(part), t)
	var gap: int = _gap5(cover, {})
	var joint: bool = _builder.is_on_joint()
	var line: String = "%s: ghost of %s at %s, gap %d cells%s, valid %s" % [tag, part, str(t.origin.snapped(
		Vector3.ONE * 0.01)), gap, " (on a joint)" if joint else "", str(_builder.can_place())]
	if gap >= 2 and not joint:
		_air.append(line)
		if at.x < INF:
			var ray: Array = [part, _builder.held_rotation, _camera.ray_origin(at), _camera.ray_normal(at)]
			_air_rays.append(ray)
			_note2("  in the air, told whole: %s" % line)
			_note2("    ray %s" % var_to_str(ray))
			for told: String in _under_ghost(part, ray[2], ray[3]):
				_note2("    %s" % told)
	elif gap == 1 and not joint:
		_near.append(line)
	if _builder.can_place():
		var met: PackedInt64Array = _builder.lattice.blockers_boxes(cover, 0)
		if not met.is_empty():
			_inside.append("%s, its cover meets %s" % [line, str(met)])


## Rays of the ghosts offered in the air: [part, quarter turns, origin, direction] each.
var _air_rays: Array = []


## What the ghost of [param part] now shown, aimed along the ray [param origin]
## [param direction], stands over, in lines: the part struck and its face,
## the ghost's box, the highest surface under the box's footprint and the
## parts whose tops make it, the cover's lowest cell, and each part the cover
## meets going down.
func _under_ghost(part: String, origin: Vector3, direction: Vector3) -> Array:
	var out: Array = []
	var hit: BrickLattice.Hit = _builder.lattice.raycast(origin, direction)
	var struck: BrickWorld.Brick = _world.get_brick(hit.brick_id) if hit.is_valid() else null
	out.append("aimed at %d (%s), normal %s, cell %s" % [hit.brick_id, struck.part_id if struck != null else "-",
		str(hit.normal), str(hit.cell)])
	var t: Transform3D = _builder.ghost_transform()
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var box: AABB = t * mesh.bounds
	var from: Vector3i = BrickLattice.to_cell(Vector3(box.position.x + 0.01, 0.0, box.position.z + 0.01))
	var to: Vector3i = BrickLattice.to_cell(Vector3(box.end.x - 0.01, 0.0, box.end.z - 0.01))
	var top: int = _builder.lattice.surface_under(from.x, from.z, to.x + 1, to.z + 1, Builder.GROUND_CELL)
	var holding: Array = []
	for id: int in _builder.lattice.blockers_boxes(PackedInt32Array([from.x, top - 1, from.z, to.x + 1, top,
			to.z + 1]), 0):
		holding.append("%d %s box %s" % [id, _name_of(id), str(_box_of(id))])
	out.append("ghost %s, box %s; under the box's footprint the surface is cell %d (%.1f LDU), the tops of %s" % [
		str(t.origin), str(box), top, top * BrickLattice.CELL, str(holding)])
	var cover: PackedInt32Array = _builder.boxes_for(mesh, t)
	out.append("its cover's lowest cell %d (%.1f LDU), rise onto what is under it %d cells" % [_lowest5(cover),
		_lowest5(cover) * BrickLattice.CELL, _builder.lattice.rise_onto(cover, Builder.GROUND_CELL)])
	var under: Dictionary = {}
	for k: int in range(1, 60):
		for id: int in _builder.lattice.blockers_boxes(BrickLattice.moved_by(cover, Vector3i(0, -k, 0)), 0):
			if not under.has(id):
				under[id] = k
	var lines: Array = []
	for id: Variant in under:
		lines.append("%d %s %d cells down, box %s" % [int(id), _name_of(int(id)), int(under[id]), str(_box_of(int(id)))])
	out.append("its cover going down meets %s" % str(lines.slice(0, 6)))
	return out


## Each ghost the sweep offered in the air aimed again alone, along its own
## ray, the part freshly taken: whether it is offered again, and as high.
func _air_again(tag: String) -> void:
	for ray: Array in _air_rays:
		_simple.call("_put_hand_away")
		await _frames(1)
		_simple.call("_take", str(ray[0]))
		_builder.held_rotation = int(ray[1])
		_builder.update_preview(ray[2] as Vector3, ray[3] as Vector3)
		var offered: bool = _builder.has_preview() and bool(_simple.call("_offered"))
		var t: Transform3D = _builder.ghost_transform()
		var gap: int = _gap5(_builder.boxes_for(_library.mesh_for(str(ray[0])), t), {})
		_note2("[%s] again alone: %s turned %d, ghost %s, offered %s, gap %d cells" % [tag, str(ray[0]), int(ray[1]),
			str(t.origin), str(offered), gap])
		for told: String in _under_ghost(str(ray[0]), ray[2] as Vector3, ray[3] as Vector3):
			_note2("    %s" % told)
		_builder.hide_preview()
	_simple.call("_put_hand_away")


# -- faces -----------------------------------------------------------------------------


func _case_faces() -> void:
	_scene = await _build_scene5()
	if not _check("the scene put down (%d parts)" % _scene.size(), not _scene.values().has(0)):
		return
	var text: String = _text()
	_reset_counts()
	for view: Array in FACE_VIEWS:
		_camera.look_from(view[1] as Vector3)
		await _settle()
		await _sweep5(str(view[0]), _scene.values(), text)
	_simple.call("_put_hand_away")
	await _frames(2)
	_report_counts("faces", 500, 80, 30, 10)
	_check("[faces] every drop and drag undone: the scene as it was, byte for byte", _text() == text)


func _reset_counts() -> void:
	_offered_n = 0
	_aimed5 = 0
	_drops5 = 0
	_drags5 = 0
	_air = []
	_near = []
	_inside = []
	_off_ghost = []
	_undo_wrong = []
	_air_rays = []


func _report_counts(tag: String, aims: int, offered: int, drops: int, drags: int) -> void:
	_check("[%s] points aimed (%d), ghosts offered (%d), drops (%d), drags (%d)" % [tag, _aimed5, _offered_n,
		_drops5, _drags5], _aimed5 >= aims and _offered_n >= offered and _drops5 >= drops and _drags5 >= drags)
	for line: String in _near.slice(0, 8):
		_note2("  a cell over (2 LDU, a stud's stop allows 3): %s" % line)
	_note2("[%s] a cell over what is under: %d" % [tag, _near.size()])
	for line: String in _air.slice(0, 12):
		_note2("  in the air: %s" % line)
	_check("[%s] nothing offered or put down 4 LDU or more over what is under it: %d" % [tag, _air.size()],
		_air.is_empty())
	for line: String in _inside.slice(0, 12):
		_note2("  inside: %s" % line)
	_check("[%s] nothing offered or put down inside another part: %d" % [tag, _inside.size()], _inside.is_empty())
	for line: String in _off_ghost.slice(0, 12):
		_note2("  not where its ghost was: %s" % line)
	_check("[%s] every drop where its ghost stood: %d off" % [tag, _off_ghost.size()], _off_ghost.is_empty())
	for line: String in _undo_wrong.slice(0, 8):
		_note2("  undo: %s" % line)
	_check("[%s] every Undo took back exactly the drop or the drag: %d wrong" % [tag, _undo_wrong.size()],
		_undo_wrong.is_empty())


func _sweep5(view: String, ids: Array, text: String) -> void:
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var n: int = 0
	for id: Variant in ids:
		var rect: Rect2 = _screen_box(_box_of(int(id))).grow(Phone.px(root, 6.0))
		for i: int in GRID5:
			for j: int in GRID5:
				var at: Vector2 = rect.position + rect.size * Vector2((i + 0.5) / GRID5, (j + 0.5) / GRID5)
				if not room.has_point(at):
					continue
				n += 1
				var k: int = 0
				for part: String in TRY_PARTS:
					for turn: int in [0, 1]:
						k += 1
						if (k + n) % 3 != 0:
							continue
						_simple.call("_take", part)
						_builder.held_rotation = turn
						_simple.call("_aim", at)
						_aimed5 += 1
						if _builder.has_preview():
							_judge_ghost("%s, %s turned %d at %s" % [view, part, turn, str(at.round())], part, at)
						_builder.hide_preview()
				if n % 3 == 0:
					await _drop5(view, TRY_PARTS[n % TRY_PARTS.size()], (n / 3) % 2, at, text)
				if n % 6 == 0 and not _scene.is_empty():
					var which: int = int(_scene["red"]) if (n / 6) % 2 == 0 else int(_scene["turned"])
					await _drag5(view, which, at, text)
			await process_frame


## A part of the tray aimed at [param at], its ghost read, then let go there.
func _drop5(view: String, part: String, turn: int, at: Vector2, text: String) -> void:
	_simple.call("_take", part)
	_builder.held_rotation = turn
	_simple.call("_aim", at)
	if not _builder.has_preview() or not _builder.can_place():
		_simple.call("_put_hand_away")
		return
	var ghost: Transform3D = _builder.ghost_transform()
	_simple.call("_drop_from_tray", at, at)
	await _frames(3)
	var put: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	_simple.call("_put_hand_away")
	if put.is_empty():
		return
	var id: int = int(put[0])
	await _seat_done()
	_drops5 += 1
	var tag: String = "%s: %s turned %d let go at %s" % [view, part, turn, str(at.round())]
	var brick: BrickWorld.Brick = _world.get_brick(id)
	if brick != null and not brick.transform.is_equal_approx(ghost):
		_off_ghost.append("%s: ghost %s, down %s" % [tag, str(ghost.origin), str(brick.transform.origin)])
	var gap: int = _gap5(_builder.lattice.boxes_of(id), {id: true})
	if gap >= 2:
		_air.append("%s: down %d cells over what is under it, at %s" % [tag, gap, str(brick.transform.origin)])
	elif gap == 1:
		_near.append("%s: down a cell over, at %s" % [tag, str(brick.transform.origin)])
	var met: Array = _overlaps5([id])
	if not met.is_empty():
		_inside.append("%s: down inside (%s)" % [tag, str(met)])
	await _press_button("undo")
	await _frames(2)
	if _text() != text:
		_undo_wrong.append("%s: the text after Undo is not the scene's" % tag)
		_restore(text)
	_builder.clear_selection()


## The part [param id] (and what rides on it) dragged by a finger to aim at
## [param at], let go, judged, undone.
func _drag5(view: String, id: int, at: Vector2, text: String) -> void:
	var from: Vector2 = _point_on(id)
	if not (from.x < INF):
		return
	var finger: Vector2 = at + Vector2(0.0, Phone.px(root, float(_simple.get("lift_points"))))
	_simple.call("_press", from, 0)
	for k: int in range(1, 9):
		_simple.call("_drag", from.lerp(finger, k / 8.0))
		await process_frame
	var offered: bool = _builder.has_preview() and _builder.is_carrying()
	_simple.call("_release", finger)
	await _frames(3)
	var drop: Dictionary = _simple.get("last_drop")
	var moved: Array = drop.get("put", [])
	if moved.is_empty() or str(drop.get("from", "")) != "model":
		if _text() != text:
			_undo_wrong.append("%s: a drag of %d put back, but the text changed" % [view, id])
			_restore(text)
		return
	await _seat_done()
	_drags5 += 1
	var tag: String = "%s: part %d dragged to aim at %s (offered %s)" % [view, id, str(at.round()), str(offered)]
	var gap: int = _group_gap(moved)
	if gap >= 2:
		_air.append("%s: the group %s down %d cells over what is under it" % [tag, str(moved), gap])
	elif gap == 1:
		_near.append("%s: the group a cell over" % tag)
	var met: Array = _overlaps5(moved)
	if not met.is_empty():
		_inside.append("%s: down inside (%s)" % [tag, str(met)])
	await _press_button("undo")
	await _frames(2)
	if _text() != text:
		_undo_wrong.append("%s: the text after Undo is not the scene's" % tag)
		_restore(text)
	_builder.clear_selection()


## Back to [param text] by Undo, at most a few, when one Undo did not get there.
func _restore(text: String) -> void:
	for _n: int in 4:
		if _text() == text:
			return
		await _press_button("undo")
		await _frames(2)


# -- big -------------------------------------------------------------------------------


func _case_big() -> void:
	await _to_full()
	if not _check("corner_shop opened", await _open("res://models/corner_shop.ldr")):
		return
	_builder.forget_history()
	await _to_simple()
	await _settle()
	var text: String = _text()
	_note2("corner_shop: %d parts" % _plain_ids().size())
	_reset_counts()
	_scene = {}
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var views: Array = [["as framed", Vector3.ZERO], ["right, low", Vector3(1.0, 0.15, 0.3)],
		["back, high", Vector3(-0.4, 0.7, -1.0)]]
	for view: Array in views:
		if (view[1] as Vector3) != Vector3.ZERO:
			_camera.look_from(view[1] as Vector3)
			await _settle()
		var n: int = 0
		for i: int in 14:
			for j: int in 14:
				var at: Vector2 = room.position + room.size * Vector2((i + 0.5) / 14.0, (j + 0.5) / 14.0)
				n += 1
				for part: String in ["3005", "3001", "3023b", "3665a"]:
					for turn: int in [0, 1]:
						if (n + turn + part.length()) % 2 != 0:
							continue
						_simple.call("_take", part)
						_builder.held_rotation = turn
						_simple.call("_aim", at)
						_aimed5 += 1
						if _builder.has_preview():
							_judge_ghost("%s, %s turned %d at %s" % [view[0], part, turn, str(at.round())], part, at)
						_builder.hide_preview()
				if n % 5 == 0:
					await _drop5(str(view[0]), ["3005", "3001", "3023b", "3039"][(n / 5) % 4], (n / 5) % 2, at, text)
			await process_frame
	_simple.call("_put_hand_away")
	await _frames(2)
	await _air_again("big")
	_report_counts("big", 600, 150, 30, 0)
	_check("[big] every drop undone: the model as it was, byte for byte", _text() == text)


# -- pick ------------------------------------------------------------------------------


## Each part's point where Simple draws it: [id, point] each, on the screen.
func _points_drawn() -> Array:
	var out: Array = []
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	for id: Variant in _plain_ids():
		var box: AABB = _box_of(int(id))
		var at: Vector2 = _camera.unproject_position(Vector3(box.get_center().x, box.end.y - 2.0,
			box.get_center().z))
		if room.has_point(at):
			out.append([int(id), at])
	return out


## The parts a tap at each point picks, and how many are the part there.
func _picks(points: Array) -> Array:
	var right: int = 0
	var wrong: Array = []
	for one: Array in points:
		var found: int = _verbs.brick_at(one[1] as Vector2)
		# The ray at the top's middle meets that part or one in front of it:
		# as Simple draws it, nothing apart.
		var plain: BrickLattice.Hit = _builder.lattice.raycast(_camera.ray_origin(one[1] as Vector2),
			_camera.ray_normal(one[1] as Vector2))
		if found == plain.brick_id:
			right += 1
		else:
			wrong.append("at %s: drawn %d, picked %d" % [str((one[1] as Vector2).round()), plain.brick_id, found])
	return [right, wrong]


## Whether a finger's tap just made acted on [param seen], the part under it:
## chose it, or, a part Simple leaves alone (a sub-assembly's, locked,
## bendy, tilted), chose nothing and named that part (SimpleLayer._left_one,
## what it says it leaves alone).
func _tap_acted(seen: int) -> bool:
	var chosen: Array = _builder.selection.keys()
	if not str(_simple.call("left_alone", seen)).is_empty():
		return chosen.is_empty() and int(_simple.get("_left_one")) == seen
	return chosen.has(seen)


func _case_pick() -> void:
	await _open_saved(EXPLODE_MODEL, "sr5_explode.ldr")
	await _to_simple()
	await _settle()
	var base: Array = _picks(_points_drawn())
	_note2("Simple, nothing apart: %d right, wrong %s" % [base[0], str(base[1])])
	await _to_full()
	var sections: Node = _shell().sections
	sections.call("explode_now", true)
	await _frames(3)
	var apart: int = _drawn_apart()
	if not _check("Full drawn apart (%d parts)" % apart, apart > 0):
		return
	await _to_simple()
	await _settle()
	_check("in Simple every part drawn where it stands (%d apart)" % _drawn_apart(), _drawn_apart() == 0)
	var points: Array = _points_drawn()
	var got: Array = _picks(points)
	for line: String in (got[1] as Array).slice(0, 8):
		_note2("  %s" % line)
	_check("in Simple after Full's exploded view: a tap where a part is drawn picks it (%d of %d)" % [got[0],
		points.size()], int(got[0]) == points.size() and points.size() >= 4)
	# A finger's tap acts on what it picks: chooses it, or, a sub-assembly's
	# part, which Simple leaves alone, chooses nothing and names it
	# (simplefix5: the wing's and tail's parts here are all left alone, and
	# a tap on one choosing nothing is right; choosing part 1 was the fault).
	var chose_right: int = 0
	var tried: int = 0
	for one: Array in points:
		var plain: BrickLattice.Hit = _builder.lattice.raycast(_camera.ray_origin(one[1] as Vector2),
			_camera.ray_normal(one[1] as Vector2))
		if not plain.is_valid():
			continue
		tried += 1
		await _layer_tap(one[1] as Vector2)
		if _tap_acted(plain.brick_id):
			chose_right += 1
		else:
			_note2("  a tap on %d chose %s" % [plain.brick_id, str(_builder.selection.keys())])
		_simple.call("_pick", [])
		await _frames(2)
	_check("...and a finger's tap there acts on that part: chooses it, or one Simple leaves alone nothing (%d of %d)"
		% [chose_right, tried], chose_right == tried and tried >= 4)
	await _to_full()
	sections.call("explode_now", false)
	await _frames(2)


# -- save ------------------------------------------------------------------------------


## The model's parts as the world has them: "part colour x y z basis" each,
## sorted, scenery left out.
func _parts_now() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var t: Transform3D = brick.transform
		out.append("%s %d %s %s" % [brick.part_id, brick.color_code, str(t.origin.snapped(Vector3.ONE * 0.01)),
			str([t.basis.x.snapped(Vector3.ONE * 0.001), t.basis.y.snapped(Vector3.ONE * 0.001),
				t.basis.z.snapped(Vector3.ONE * 0.001)])])
	out.sort()
	return out


func _case_save() -> void:
	var path: String = await _open_saved(FROM_FULL, "sr5_save.mpd")
	var own: String = _store.saved_path(_store.title)
	_check("Save the opened file where it was kept", bool(_main.call("save_model", own)))
	await _to_simple()
	await _settle()
	var texts: Array = [_text()]
	var acts: Array = []
	# Three drops on the plate and on parts, a drag, a delete.
	for spot: Array in [["3003", 14, _base_point(0.45, 0.45)], ["3001", 1, _top_point(_plain_ids()[0])],
			["3005", 4, _base_point(-0.45, 0.4)]]:
		var put: int = await _put(str(spot[0]), int(spot[1]), spot[2] as Vector2)
		await _seat_done()
		_simple.call("_put_hand_away")
		if put != 0:
			acts.append("put %d" % put)
			texts.append(_text())
	var first: int = _plain_ids()[1]
	var from: Vector2 = _point_on(first)
	if from.x < INF:
		var to: Vector2 = _base_point(0.0, 0.45) + Vector2(0.0, Phone.px(root, float(_simple.get("lift_points"))))
		_simple.call("_press", from, 0)
		for k: int in range(1, 9):
			_simple.call("_drag", from.lerp(to, k / 8.0))
			await process_frame
		_simple.call("_release", to)
		await _frames(3)
		await _seat_done()
		if not ((_simple.get("last_drop") as Dictionary).get("put", []) as Array).is_empty():
			acts.append("drag %d" % first)
			texts.append(_text())
	_check("in Simple: drops and a drag made (%s)" % str(acts), acts.size() >= 3)
	# Undo each, back to the opened text; Redo each, on to the last.
	var undo_ok: bool = true
	for k: int in range(texts.size() - 1, 0, -1):
		await _press_button("undo")
		await _frames(3)
		if _text() != texts[k - 1]:
			undo_ok = false
			_note2("  Undo of %s: not the text before it" % acts[k - 1])
	_check("each Undo takes back exactly its act, down to the opened text", undo_ok and _text() == texts[0])
	var redo_ok: bool = true
	for k: int in range(1, texts.size()):
		await _press_button("redo")
		await _frames(3)
		if _text() != texts[k]:
			redo_ok = false
			_note2("  Redo of %s: not the text after it" % acts[k - 1])
	_check("each Redo puts back exactly its act", redo_ok and _text() == texts[-1])
	# Then a part chosen and deleted.
	var gone: int = _plain_ids()[0]
	var at: Vector2 = _point_on(gone)
	if at.x < INF:
		await _layer_tap(at)
		await _press_button("delete")
		await _frames(3)
	_check("unsaved work after Simple's acts", _store.has_unsaved_work())
	var world_parts: Array = _parts_now()
	await _to_full()
	_check("Save", bool(_main.call("save_model", own)))
	_check("...then no unsaved work", not _store.has_unsaved_work())
	await _open(own)
	var reopened: Array = _parts_now()
	var missing: Array = []
	for line: String in world_parts:
		if not reopened.has(line):
			missing.append(line)
	var extra: Array = []
	for line: String in reopened:
		if not world_parts.has(line):
			extra.append(line)
	_note2("saved %d parts, reopened %d; missing %s, extra %s" % [world_parts.size(), reopened.size(),
		str(missing.slice(0, 4)), str(extra.slice(0, 4))])
	_check("reopened: every part as the world had it, nothing more (%d parts)" % world_parts.size(),
		missing.is_empty() and extra.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# -- dirty -----------------------------------------------------------------------------


func _case_dirty() -> void:
	await _open_saved(EXPLODE_MODEL, "sr5_dirty.ldr")
	var shell: Shell = _shell()
	var own: String = _store.saved_path(_store.title)
	# The cut, which the file keeps, then saved: Simple must not unsay it.
	var see: SeeInside = shell.see_inside
	see.set_cut(true)
	await _frames(4)
	var plain: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 4)
	_builder.clear_selection()
	_builder.select_brick(plain, false)
	_verbs.hide_selection()
	_builder.clear_selection()
	shell.stress.call("set_on", true)
	shell.sections.call("explode_now", true)
	await _frames(4)
	_check("saved with the cut on", bool(_main.call("save_model", own)))
	var text: String = _text()
	var unseen: Array = _builder.lattice.unseen.keys()
	_note2("Full: cutting %s, hidden %s, stress %s, apart %d, unsaved %s" % [str(see.cutting), str(unseen),
		str(shell.stress.get("on")), _drawn_apart(), str(_store.has_unsaved_work())])
	_check("Full: no unsaved work with its view set", not _store.has_unsaved_work())
	await _to_simple()
	await _settle()
	_check("in Simple, nothing done: no unsaved work, the text byte for byte",
		not _store.has_unsaved_work() and _text() == text)
	await _to_full()
	await _frames(6)
	_check("back in Full: no unsaved work, the text byte for byte",
		not _store.has_unsaved_work() and _text() == text)
	var unseen_back: Array = _builder.lattice.unseen.keys()
	_check("...hidden as it was (%s), cut %s, stress %s, apart %d" % [str(unseen_back), str(see.cutting),
		str(shell.stress.get("on")), _drawn_apart()], str(unseen_back) == str(unseen) and see.cutting
		and bool(shell.stress.get("on")) and _drawn_apart() > 0)
	shell.sections.call("explode_now", false)
	shell.stress.call("set_on", false)
	see.set_cut(false)
	_verbs.show_all()
	await _frames(2)


# -- middrag ---------------------------------------------------------------------------


func _case_middrag() -> void:
	# Simple's drag, Full comes up mid-way.
	await _open_saved(FROM_FULL, "sr5_middrag.mpd")
	await _to_simple()
	await _settle()
	var text: String = _text()
	var parts: Array = _parts_now()
	var id: int = _plain_ids()[0]
	var from: Vector2 = _point_on(id)
	if _check("a part to drag in Simple (%d at %s)" % [id, str(from)], from.x < INF):
		var to: Vector2 = _base_point(0.4, 0.4)
		_simple.call("_press", from, 0)
		for k: int in range(1, 6):
			_simple.call("_drag", from.lerp(to, k / 8.0))
			await process_frame
		var carrying: bool = _builder.is_carrying()
		_note2("mid-drag in Simple: carrying %s, unsaved %s" % [str(carrying), str(_store.has_unsaved_work())])
		_main.call("use_controls", &"full")
		await _frames(6)
		_check("Simple's drag, Full mid-way: nothing in hand (%s), every part where it was, the text byte for byte" % [
			str(_builder.is_carrying())], not _builder.is_carrying() and _parts_now() == parts and _text() == text)
		_check("...and no unsaved work", not _store.has_unsaved_work())
	# Full's drag, Simple comes up mid-way, then a tap on the plate.
	await _to_full()
	var moving: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 1 and b.group.is_empty())
	var at: Vector2 = _camera.unproject_position(_box_of(moving).get_center())
	_builder.clear_selection()
	_builder.select_brick(moving, false)
	var started: bool = _verbs.drag_start(moving, false, true, [_camera.ray_origin(at), _camera.ray_normal(at)])
	await _frames(2)
	_note2("Full's drag of %d: started %s, carrying %s" % [moving, str(started), str(_builder.is_carrying())])
	if not _check("Full carries a part", _builder.is_carrying()):
		return
	await _to_simple()
	await _settle()
	_check("in Simple with Full's part in hand: still in hand, unsaved work (a move begun)",
		_builder.is_carrying() and _store.has_unsaved_work())
	var spot: Vector2 = _base_point(-0.4, 0.45)
	await _layer_tap(spot)
	await _seat_done()
	var after: Array = _parts_now()
	var brick: BrickWorld.Brick = _world.get_brick(moving)
	var lost: Array = []
	for line: String in parts:
		if not after.has(line):
			lost.append(line)
	_note2("after a tap in Simple: carrying %s, part %d at %s, %d lines changed %s" % [str(_builder.is_carrying()),
		moving, str(brick.transform.origin) if brick != null else "gone", lost.size(), str(lost)])
	_check("...a tap put it down: the same parts, only that one moved (%d changed)" % lost.size(),
		not _builder.is_carrying() and after.size() == parts.size() and lost.size() <= 1 and brick != null)
	if brick != null:
		var gap: int = _gap5(_builder.lattice.boxes_of(moving), {moving: true})
		_check("...standing on something (gap %d cells)" % gap, gap == 0)
	await _press_button("undo")
	await _frames(3)
	_check("...Undo: the text before the drag, byte for byte", _text() == text)
	# Full's drag, Simple and back to Full before any tap.
	await _to_full()
	_builder.clear_selection()
	_builder.select_brick(moving, false)
	at = _camera.unproject_position(_box_of(moving).get_center())
	_verbs.drag_start(moving, false, true, [_camera.ray_origin(at), _camera.ray_normal(at)])
	await _frames(2)
	await _to_simple()
	await _settle()
	await _to_full()
	await _frames(4)
	var held: bool = _builder.is_carrying()
	_verbs.put_away()
	await _frames(3)
	_check("Full's drag through Simple and back, then put away (in hand on return %s): the text byte for byte" %
		str(held), _text() == text and _parts_now() == parts)


# -- modes -----------------------------------------------------------------------------


func _header_button(name: String) -> Button:
	var found: Array = _main.find_children(name, "Button", true, false)
	for node: Node in found:
		if (node as Button).is_visible_in_tree():
			return node
	return found[0] if not found.is_empty() else null


## Simple or Full by the header's own button, as a finger's tap on it does.
func _switch_by_header(layer: String) -> bool:
	var button: Button = _header_button("controls_" + layer)
	if button == null:
		_main.call("use_controls", StringName(layer))
		await _frames(6)
		return false
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
	else:
		await _tap_at(button.get_global_rect().get_center())
	await _frames(8)
	await _settle()
	return true


func _view_state() -> Dictionary:
	var shell: Shell = _shell()
	var steps: StepsBar = _main.get("_steps")
	var at: Instructions.Step = steps.current_step() if steps.is_playing_back() else null
	var unseen: Array = _builder.lattice.unseen.keys()
	unseen.sort()
	var through: Array = _builder.lattice.see_through.keys()
	through.sort()
	return {"camera": str(_camera.global_transform.origin.snapped(Vector3.ONE * 0.1)), "unseen": unseen,
		"see_through": through, "xray": shell.see_inside.seeing_through, "cutting": shell.see_inside.cutting,
		"cut_kept": str(_world.cut_kept), "stud_map": bool(shell.stud_map.get("on")),
		"stress": bool(shell.stress.get("on")), "mode": _verbs.mode, "held": [_builder.held_part,
			_builder.held_color, _builder.held_rotation], "entered": shell.assemblies.entered,
		"timeline": at.number if at != null else -1, "playing": steps.is_playing_back(),
		"snap": _verbs.snap, "turn_step": _verbs.turn_step, "stands_only": _builder.stands_only}


func _case_modes() -> void:
	for variant: String in ["nothing", "put"]:
		# A: the timeline on step 2, a part hidden, Stud directions, Paint.
		await _open_saved(STEPS_MODEL, "sr5_modes.ldr")
		var steps: StepsBar = _main.get("_steps")
		var shell: Shell = _shell()
		var top: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 14)
		_builder.clear_selection()
		_builder.select_brick(top, false)
		_verbs.hide_selection()
		_builder.clear_selection()
		shell.stud_map.call("set_on", true)
		_verbs.set_mode("paint")
		_builder.held_color = 2
		_main.call("_toggle_steps")
		for _n: int in 300:
			await process_frame
			if steps.is_playing_back():
				break
		await _frames(10)
		steps.show_step(2)
		await _frames(6)
		var a0: Dictionary = _view_state()
		_note2("[A %s] Full: %s" % [variant, str(a0)])
		var by_header: bool = await _switch_by_header("simple")
		var inside: Dictionary = _view_state()
		_check("[A %s] in Simple (by the header %s): the timeline put away, stands_only on, nothing hidden, no tint" % [
			variant, str(by_header)], not inside["playing"] and inside["stands_only"] and (inside["unseen"] as Array).is_empty()
			and not inside["stud_map"])
		if variant == "put":
			var put: int = await _put("3003", 4, _base_point(0.4, 0.4))
			await _seat_done()
			_check("[A put] a brick put in Simple (%d)" % put, put != 0)
		await _switch_by_header("full")
		for _n: int in 300:
			await process_frame
			if steps.is_playing_back():
				break
		await _frames(10)
		var a1: Dictionary = _view_state()
		var differ: Array = _differ(a0, a1)
		_note2("[A %s] Full's camera %s, back %s" % [variant, a0["camera"], a1["camera"]])
		differ.erase("camera: %s -> %s" % [a0["camera"], a1["camera"]])
		_check("[A %s] back in Full: view, tool and step as they were (%s)" % [variant, str(differ)], differ.is_empty())
		steps.stop()
		shell.stud_map.call("set_on", false)
		_verbs.set_mode("select")
		await _frames(2)
		# B: inside a sub-assembly, x-ray, a plane cut, a part in hand.
		await _open_saved(FROM_FULL, "sr5_modes_b.mpd")
		var wing_part: int = _id_where(func(b: BrickWorld.Brick) -> bool: return not Assemblies.path_of(b).is_empty())
		_builder.clear_selection()
		_builder.select_brick(wing_part, false)
		var wing: String = shell.assemblies.selected_assembly()
		_builder.clear_selection()
		shell.assemblies.enter(wing)
		await _frames(3)
		shell.see_inside.set_cut(true)
		await _frames(3)
		_builder.select_brick(wing_part, false)
		shell.see_inside.set_xray(true)
		_main.call("_on_part_chosen", "3062b")
		_builder.held_color = 25
		_builder.held_rotation = 1
		await _frames(4)
		var b0: Dictionary = _view_state()
		_note2("[B %s] Full: %s" % [variant, str(b0)])
		await _switch_by_header("simple")
		var b_in: Dictionary = _view_state()
		_check("[B %s] in Simple: at the top, no cut, no x-ray" % variant, str(b_in["entered"]).is_empty()
			and not b_in["cutting"] and not b_in["xray"])
		var put2: int = 0
		if variant == "put":
			put2 = await _put("3003", 4, _base_point(0.4, 0.4))
			await _seat_done()
			_check("[B put] a brick put in Simple (%d)" % put2, put2 != 0)
		await _switch_by_header("full")
		await _frames(6)
		var b1: Dictionary = _view_state()
		var differ_b: Array = _differ(b0, b1)
		_note2("[B %s] Full's camera %s, back %s" % [variant, b0["camera"], b1["camera"]])
		differ_b.erase("camera: %s -> %s" % [b0["camera"], b1["camera"]])
		# Simple puts its brick at the model's top, outside the sub-assembly
		# Full's x-ray keeps solid: seen through with the rest (simplefix5).
		if put2 != 0:
			var through: Array = (b0["see_through"] as Array) + [put2]
			through.sort()
			if str(through) == str(b1["see_through"]):
				differ_b.erase("see_through: %s -> %s" % [str(b0["see_through"]), str(b1["see_through"])])
		_check("[B %s] back in Full: sub-assembly, cut, x-ray, part in hand as they were (%s)" % [variant,
			str(differ_b)], differ_b.is_empty())
		shell.see_inside.set_xray(false)
		shell.see_inside.set_cut(false)
		_verbs.set_mode("select")
		# Out of the sub-assembly, as an open by the menu leaves it (Shell's
		# bar.opened): the next model opens by Main._open, which does not, and
		# the next variant's A began "inside" a wing its model has not.
		shell.assemblies.leave_to("")
		await _frames(2)


# -- full ------------------------------------------------------------------------------


## Full's ghost for [param part] aimed at each of [param points]: its
## transform or "none", in order.
func _full_aims(part: String, points: Array) -> Array:
	_main.call("_on_part_chosen", part)
	_builder.held_rotation = 0
	await _frames(2)
	var out: Array = []
	for at: Variant in points:
		_main.call("_refresh_preview", at as Vector2)
		out.append(str(_builder.ghost_transform()) if _builder.has_preview() else "none")
	_builder.hide_preview()
	return out


func _case_full() -> void:
	_scene = await _build_scene5()
	await _to_full()
	await _frames(4)
	_camera.look_from(Vector3(1.0, 0.15, 0.3))
	await _settle()
	var points: Array = []
	for id: Variant in _scene.values():
		var rect: Rect2 = _screen_box(_box_of(int(id)))
		for i: int in 4:
			for j: int in 4:
				points.append(rect.position + rect.size * Vector2((i + 0.5) / 4.0, (j + 0.5) / 4.0))
	var before: Array = []
	for part: String in ["3001", "3005", "3023b"]:
		before.append_array(await _full_aims(part, points))
	# Full's own side face: the blue brick's side, at the height it implies.
	var blue: AABB = _box_of(int(_scene["blue"]))
	var side: Vector2 = _camera.unproject_position(Vector3(blue.end.x, blue.position.y + 12.0, blue.get_center().z))
	_main.call("_on_part_chosen", "3005")
	await _frames(2)
	_main.call("_refresh_preview", side)
	var side_full: Vector3 = _builder.ghost_transform().origin if _builder.has_preview() else Vector3.INF
	_note2("Full at the blue brick's side: ghost at %s (blue's foot %.1f)" % [str(side_full), blue.position.y])
	_builder.hide_preview()
	_verbs.set_mode("select")
	var camera_was: Transform3D = _camera.global_transform
	await _to_simple()
	var put: int = await _put("3001", 4, _base_point(0.4, 0.4))
	await _seat_done()
	if put != 0:
		await _press_button("undo")
		await _frames(2)
	await _to_full()
	await _frames(4)
	_camera.global_transform = camera_was
	_camera.look_from(Vector3(1.0, 0.15, 0.3))
	await _settle()
	_check("back in Full: stands_only off", not _builder.stands_only)
	var after: Array = []
	for part: String in ["3001", "3005", "3023b"]:
		after.append_array(await _full_aims(part, points))
	var differ: int = 0
	for k: int in before.size():
		if before[k] != after[k]:
			differ += 1
	_check("Full's aims after a trip to Simple, ghost for ghost the same (%d of %d differ)" % [differ, before.size()],
		differ == 0 and before.size() > 50)
	_main.call("_on_part_chosen", "3005")
	await _frames(2)
	_main.call("_refresh_preview", side)
	var side_again: Vector3 = _builder.ghost_transform().origin if _builder.has_preview() else Vector3.INF
	_check("Full at the blue brick's side still at the height it implies (%s, then %s)" % [str(side_full),
		str(side_again)], side_full == side_again and side_full.x < INF and side_full.y > blue.position.y - 1.0)
	_builder.hide_preview()
	_verbs.set_mode("select")


# -- ghosts: big's two inverted slopes once offered in the air, alone ---------------------


## The rays [big] aimed the two inverted slopes along when the sweep came
## after [faces] (the camera there is not the one big alone has): [part,
## quarter turns, origin, direction, what it was aimed at, what its box stood
## on]. The first at a 2 x 4 tile on the ground, its box's far edge over a
## minifig's arm 52 LDU up; the second at a 1 x 2 plate, its box's far half
## over a 2 x 2 double slope's ridge (bigghost, 2026-11-28).
const AIR_RAYS: Array = [
	["3665a", 1, Vector3(1781.5161, 424.53134, 678.1275), Vector3(-0.9628271, -0.25840482, -0.07868184),
		"a 2 x 4 tile, the box on a minifig's arm"],
	["3665a", 0, Vector3(-448.39258, 1137.5686, -1203.7672), Vector3(0.2330554, -0.52178884, 0.8206227),
		"a 1 x 2 plate, the box on a double slope's ridge"],
]


## Each of [constant AIR_RAYS] aimed alone over corner_shop, in Simple and
## in Full: Simple offers no ghost 4 LDU or more over what is under it, and
## let go the part stands on what is under it; Full's ghost is not in the
## air either (the builder rests a part that is not a box by its cover).
func _case_ghosts() -> void:
	await _to_full()
	if not _check("corner_shop opened", await _open("res://models/corner_shop.ldr")):
		return
	_builder.forget_history()
	await _to_simple()
	await _settle()
	var text: String = _text()
	for ray: Array in AIR_RAYS:
		var tag: String = "%s turned %d at %s" % [str(ray[0]), int(ray[1]), str(ray[4])]
		for simple: bool in [true, false]:
			if not simple:
				await _to_full()
				_verbs.set_mode("place")
			if simple:
				_simple.call("_put_hand_away")
				_simple.call("_take", str(ray[0]))
			else:
				_main.call("_on_part_chosen", str(ray[0]))
			_builder.held_rotation = int(ray[1])
			_builder.update_preview(ray[2] as Vector3, ray[3] as Vector3)
			var shown: bool = _builder.has_preview()
			var offered: bool = shown and (bool(_simple.call("_offered")) if simple else _builder.can_place())
			var t: Transform3D = _builder.ghost_transform()
			var gap: int = _gap5(_builder.boxes_for(_library.mesh_for(str(ray[0])), t), {})
			_note2("[ghosts] %s, %s: ghost %s, offered %s, gap %d cells" % [tag, "Simple" if simple else "Full",
				str(t.origin), str(offered), gap])
			for told: String in _under_ghost(str(ray[0]), ray[2] as Vector3, ray[3] as Vector3):
				_note2("    %s" % told)
			_check("[ghosts] %s, %s: not offered 4 LDU or more over what is under it (gap %d cells)" % [tag,
				"Simple" if simple else "Full", gap], not offered or gap < 2 or _builder.is_on_joint())
			if simple and offered:
				# Let go there, as a drop does: it stands, and Undo takes it back.
				var put: int = _builder.place()
				await _frames(3)
				var down: int = _gap5(_builder.lattice.boxes_of(put), {put: true}) if put != 0 else -1
				_check("[ghosts] %s: let go, it stands on what is under it (gap %d cells)" % [tag, down],
					put != 0 and down >= 0 and down < 2)
				if put != 0:
					await _press_button("undo")
					await _frames(2)
			_builder.hide_preview()
			if not simple:
				_verbs.set_mode("select")
				await _to_simple()
	_simple.call("_put_hand_away")
	_check("[ghosts] the model as it was, byte for byte", _text() == text)
