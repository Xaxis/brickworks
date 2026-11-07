## Seeing inside a model: the cut-away and x-ray.
##
## A tower's rooms, a car's seats, the stairs inside a castle wall: built by
## hand, the inside of a model is where most of the work is, and the outside
## is in the way. Hiding (H) takes parts away one by one. These see past them
## all at once, as Studio, Mecabricks and StudWorx do.
##
##   The cut-away (K) is a plane across the model along X, Y or Z, dragged
##   through it with the slider in the strip it puts over the model; or a
##   box, a sphere or a cylinder standing up, as StudWorx cuts (APP_UX4 8),
##   chosen in the strip or under View › Cut away by. A shape goes round the
##   selection, or with none takes the middle of the model off from half way
##   up. A knob on each of its faces is dragged to push the face in or pull
##   it out a plate at a time (the wheel over a knob moves it one; Shift
##   drags the whole shape), and the strip's Grow and Shrink move every face
##   a plate. What is on the eye's side of the plane, or inside the shape, is
##   not drawn; the faces it cuts through are drawn as faces, hatched, in the
##   part's colour, so a wall cut through reads as a wall and never as the
##   inside of a brick. Optionally what is cut away stays as a faint ghost.
##
##   X-ray (I) draws everything but the selection — or the sub-assembly being
##   edited inside — see-through, so what is inside can be seen.
##
## Both are the picture only: the model and its history are untouched, and
## the booklet and Render, drawn from worlds of their own, never see them.
## The cut is kept with the model, a line LDraw readers pass over in its
## file (CutShape.META, held as BrickWorld.cut_kept), and comes back when the
## file opens. The pointer goes where the eye does — past the cut and through
## the ghosts to what is drawn solid — because the lattice it is marched
## through is told the same (BrickLattice.cut and cut_shape, see_through).
## The drawing is BrickWorld's (set_cut, set_cut_shape, set_xray).
class_name SeeInside
extends Node

const AXES := ["X", "Y", "Z"]
## The plane sits on odd whole LDU, between the even ones nearly every face
## of a part is on, so it never lies in a face and flickers. A shape's faces
## do too.
const STEP := 2.0
## What the cut is by, as the strip lists them, in CutShape's order.
const SHAPES: Array[String] = ["A plane", "A box", "A sphere", "A cylinder"]
const SHAPE_WORDS: Array[String] = ["a plane", "a box", "a sphere", "a cylinder"]
## A shape's face moves a plate at a time, and a shape is never thinner
## than one.
const PLATE := BrickLattice.PLATE
## A knob's radius on the screen, and how near it the pointer has to be to
## take it, px at the window's own scale.
const KNOB := 6.0
const PICK := 12.0
## A press on a knob that moves no further than this is a click, px.
const DRAG_SLOP := 4.0

var world: BrickWorld
var builder: Builder
var assemblies: Assemblies
var camera: Camera3D
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
## The model's bounds without the baseplate (main's _built_bounds).
var bounds_of_model: Callable = func() -> AABB: return AABB()
## The model's store: how far the model stands above where its file has it
## (ModelStore.lift), and when a model is opened.
var store: ModelStore

## The strip over the model while a cut is on.
var bar: PanelContainer
## What runs along the foot of the model — the key strip, the timeline —
## which the strip sits above: the top of the model is the model tree's, the
## properties' and the view cube's.
var below: Array[Control] = []
## Where the plane is, or the shape's outline, so it can be found when it
## cuts nothing.
var frame: MeshInstance3D

var cutting: bool = false
## What the cut is by: CutShape.PLANE, BOX, SPHERE or CYLINDER.
var shape: int = CutShape.PLANE
## 0, 1, 2 for X, Y, Z.
var axis: int = 1
## Where the plane is along the axis, in LDU in the world.
var at: float = 0.0
## Whether what is cut away is on the axis's positive side.
var cuts_positive: bool = true
## What a box, a sphere or a cylinder fills, in the world, LDU: its faces on
## odd whole LDU and a whole number of plates apart; square where its shape
## is round (_fitted).
var room: AABB = AABB()
var leaves_ghosts: bool = false

var seeing_through: bool = false
## What x-ray keeps solid: the sub-assembly entered when it was turned on,
## or "" for the selection it was turned on with.
var _xray_path: String = ""
var _generation: int = -1

## The knob under the pointer (a face: -X, +X, -Y, +Y, -Z, +Z), or -1.
var lit: int = -1

var _bounds: AABB = AABB()
var _shape_choice: OptionButton
var _slider: HSlider
var _reading: Label
var _size: Label
var _axis_buttons: Array[Button] = []
var _grow: Button
var _shrink: Button
var _ghost_box: CheckBox
var _for_plane: Array[Control] = []
var _for_shape: Array[Control] = []
var _setting: bool = false
## The knobs, drawn over each view (ViewOverlays), and what they were last
## drawn for.
var _knobs: ViewOverlays
var _drawn: Array = []
## A press on a knob not yet moved, and a knob's drag: {face, way, pivot,
## room it began from, from (along its line), plates, whole, view}.
var _press: Dictionary = {}
var _drag: Dictionary = {}


func _ready() -> void:
	_build_bar()
	frame = MeshInstance3D.new()
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.visible = false
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.4, 0.66, 1.0, 0.9)
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.no_depth_test = true
	frame.material_override = ink
	add_child(frame)
	# Over the model, under the menus and dialogs, as the move handles are.
	_knobs = ViewOverlays.new()
	_knobs.name = "CutKnobs"
	_knobs.camera = camera as CadCamera
	_knobs.draw_in = _draw_knobs
	add_child(_knobs)
	if assemblies != null:
		assemblies.entered_changed.connect(_on_entered)
	world.rebuilt.connect(func(_b: int, _n: int, _t: int) -> void: _check_model())
	if store != null:
		store.loaded.connect(func(_name: String, _bricks: int) -> void: _opened())


# -- the cut ------------------------------------------------------------------


## Turn the cut on or off. On, it is by the shape last used: the plane
## across the middle of the model, along the axis last used, taking off the
## side the eye is on; or the box, sphere or cylinder, placed afresh.
func set_cut(on: bool) -> void:
	if on == cutting:
		return
	if not on:
		_end_cut()
		world.cut_kept = {}
		say.call("the whole model again")
		return
	if _model_box().size == Vector3.ZERO:
		say.call("there is nothing to cut through yet")
		return
	if shape != CutShape.PLANE:
		cut_by(shape)
		return
	cutting = true
	_generation = world.generation()
	cut_along(axis)
	say.call(Keymap.filled("cut along %s — drag the slider to move it, {cut|puts the model back}") % AXES[axis])


## Cut along an axis, through the middle of the model, from the eye's side.
func cut_along(which: int) -> void:
	axis = clampi(which, 0, 2)
	shape = CutShape.PLANE
	if not cutting:
		set_cut(true)
		return
	var box: AABB = _model_box()
	var middle: float = box.get_center()[axis]
	cuts_positive = camera == null or camera.global_position[axis] > middle
	_plane_on(axis, middle)


## The plane along [param which], at [param position], with the strip's
## slider spanning the model along it.
func _plane_on(which: int, position: float) -> void:
	axis = which
	shape = CutShape.PLANE
	_bounds = _model_box()
	_setting = true
	_slider.min_value = _odd(_bounds.position[axis] - STEP)
	_slider.max_value = _odd(_bounds.end[axis] + STEP)
	_slider.step = STEP
	_setting = false
	for n: int in 3:
		_axis_buttons[n].set_pressed_no_signal(n == axis)
	bar.visible = true
	move_to(_odd(position))


## Move the plane to [param position] along the axis, in LDU.
func move_to(position: float) -> void:
	at = position
	if _slider.value != position:
		_setting = true
		_slider.value = position
		_setting = false
	_apply_cut()


## Cut away the other side instead. A shape takes away what is inside it,
## and has no other side.
func flip() -> void:
	if not cutting:
		set_cut(true)
		return
	if shape != CutShape.PLANE:
		say.call("a %s cuts away what is inside it; Flip turns a plane" % CutShape.KINDS[shape])
		return
	cuts_positive = not cuts_positive
	_apply_cut()
	say.call("cutting away the other side")


## Leave what is cut away as a faint ghost of itself, or take it away.
func set_ghosts(on: bool) -> void:
	leaves_ghosts = on
	_ghost_box.set_pressed_no_signal(on)
	if cutting:
		_apply_cut()


## The plane as BrickWorld and the lattice take it: its normal points to
## the side that is cut away.
func plane() -> Plane:
	var normal := Vector3.ZERO
	normal[axis] = 1.0 if cuts_positive else -1.0
	return Plane(normal, at if cuts_positive else -at)


## Cut by a box, a sphere or a cylinder ([param kind], CutShape's), or the
## plane. A shape first goes round the selection, or with none takes the
## middle of the model off from half way up; one already on keeps its place
## and becomes the other shape there.
func cut_by(kind: int) -> void:
	kind = clampi(kind, CutShape.PLANE, CutShape.CYLINDER)
	if kind == CutShape.PLANE:
		cut_along(axis)
		return
	if not cutting and _model_box().size == Vector3.ZERO:
		say.call("there is nothing to cut through yet")
		return
	var placed: bool = cutting and shape != CutShape.PLANE
	shape = kind
	room = _fitted(room, -1) if placed else _first_room()
	if not cutting:
		cutting = true
		_generation = world.generation()
	_apply_cut()
	say.call(Keymap.filled("cut away by %s — drag a knob to push or pull its face a plate at a time, {cut|puts the model back}") % SHAPE_WORDS[shape])


## Whether a box, a sphere or a cylinder is cutting.
func shape_on() -> bool:
	return cutting and shape != CutShape.PLANE


## The shape to fill [param box], snapped to plates and kept round where it
## is round.
func set_room(box: AABB) -> void:
	if not shape_on():
		return
	room = _fitted(box, -1)
	_apply_cut()


## Push the face [param face] (-X, +X, -Y, +Y, -Z, +Z: 0 to 5) out by
## [param plates], or in by a negative number of them.
func push(face: int, plates: int) -> void:
	if not shape_on() or plates == 0:
		return
	room = _fitted(_pushed(room, face, plates), face / 2)
	_apply_cut()


## Every face out by [param plates], or in by a negative number of them.
func grow(plates: int) -> void:
	if not shape_on():
		return
	var box: AABB = room
	for n: int in 3:
		var size: float = maxf(PLATE, box.size[n] + 2.0 * plates * PLATE)
		box.position[n] += (box.size[n] - size) * 0.5
		box.size[n] = size
	room = _fitted(box, -1)
	_apply_cut()
	say.call(("grown to %s" if plates > 0 else "shrunk to %s") % _size_words())


static func _pushed(box: AABB, face: int, plates: int) -> AABB:
	var n: int = face / 2
	var size: float = maxf(PLATE, box.size[n] + plates * PLATE)
	if face % 2 == 0:
		box.position[n] = box.end[n] - size
	box.size[n] = size
	return box


static func _moved(box: AABB, n: int, plates: int) -> AABB:
	box.position[n] += plates * PLATE
	return box


## [param box] as the shape fills it: a sphere's three sizes the same, a
## cylinder's across and deep the same, each the size along [param moved]
## when that axis is one of them, else the largest; the others kept about
## their middles. Sizes stay whole plates and faces odd.
func _fitted(box: AABB, moved: int) -> AABB:
	var round_on: Array = [0, 1, 2] if shape == CutShape.SPHERE \
		else ([0, 2] if shape == CutShape.CYLINDER else [])
	if round_on.is_empty():
		return box
	var size: float = 0.0
	if moved in round_on:
		size = box.size[moved]
	else:
		for n: int in round_on:
			size = maxf(size, box.size[n])
	for n: int in round_on:
		box.position[n] += (box.size[n] - size) * 0.5
		box.size[n] = size
	return box


## Where a shape first goes: round the selection; with none, the middle half
## of the model across and deep, from half way up to a plate over its top,
## or for a sphere a ball sunk into the middle of its top.
func _first_room() -> AABB:
	var around := AABB()
	var any: bool = false
	for brick_id: int in builder.selection:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or scenery.has(brick_id):
			continue
		var mesh: Lbm.PartMesh = world.library.mesh_for(brick.part_id)
		var box: AABB = brick.transform * (mesh.bounds if mesh != null else AABB())
		around = box if not any else around.merge(box)
		any = true
	if not any:
		var model: AABB = _model_box()
		var middle: Vector3 = model.get_center()
		if shape == CutShape.SPHERE:
			var reach: float = maxf(PLATE, minf(model.size.x, model.size.z) * 0.375)
			around = AABB(Vector3(middle.x, model.end.y, middle.z) - Vector3.ONE * reach,
				Vector3.ONE * reach * 2.0)
		else:
			around = AABB(Vector3(middle.x - model.size.x * 0.25, middle.y,
				middle.z - model.size.z * 0.25),
				Vector3(model.size.x * 0.5, model.end.y - middle.y + PLATE, model.size.z * 0.5))
	return _fitted(_snapped(around), -1)


## [param box] grown to odd whole LDU at each face and whole plates across,
## as evenly at each end as odd faces allow: a box round a roof 80 LDU
## across is 88, 5 to spare at one side and 3 at the other, not 1 and 7.
static func _snapped(box: AABB) -> AABB:
	var out := AABB()
	for n: int in 3:
		var low: float = floorf((box.position[n] - 1.0) / STEP) * STEP + 1.0
		var size: float = maxf(PLATE, ceilf((box.end[n] - low) / PLATE - 0.001) * PLATE)
		# What is spare past the end, moved to the start a STEP at a time.
		var spare_low: float = box.position[n] - low
		var spare_high: float = low + size - box.end[n]
		var back: float = clampf(roundf((spare_high - spare_low) / (2.0 * STEP)), 0.0,
			floorf(spare_high / STEP)) * STEP
		out.position[n] = low - back
		out.size[n] = size
	return out


func _apply_cut() -> void:
	if shape == CutShape.PLANE:
		var cut: Plane = plane()
		world.set_cut(true, cut, leaves_ghosts)
		builder.lattice.cut_shape = null
		builder.lattice.cut = cut
		_reading.text = _words_for(at)
	else:
		var by := CutShape.new(shape, room)
		world.set_cut_shape(by, leaves_ghosts)
		builder.lattice.cut = Plane()
		builder.lattice.cut_shape = by
		_size.text = _size_words()
	_show_controls()
	bar.visible = true
	_draw_frame()
	world.cut_kept = scheme()


## The cut kept with the model, as its file says it (CutShape.read): in the
## file's coordinates, not where the model stands on the baseplate. None
## while nothing is cut.
func scheme() -> Dictionary:
	if not cutting:
		return {}
	var lift: Vector3 = store.lift() if store != null else Vector3.ZERO
	if shape == CutShape.PLANE:
		var point := Vector3.ZERO
		point[axis] = at
		var away: float = (1.0 if cuts_positive else -1.0) * LdrModel.FLIP[axis]
		return {"shape": "plane", "axis": CutShape.AXES[axis],
			"at": ((point - lift) * LdrModel.FLIP)[axis], "away": int(away),
			"ghosts": leaves_ghosts}
	var box := AABB((room.position - lift) * LdrModel.FLIP, Vector3.ZERO) \
		.expand((room.end - lift) * LdrModel.FLIP)
	return {"shape": CutShape.KINDS[shape],
		"from": [box.position.x, box.position.y, box.position.z],
		"to": [box.end.x, box.end.y, box.end.z], "ghosts": leaves_ghosts}


## A model opened: the cut its file keeps, if it keeps one, on again as it
## was saved; otherwise none.
func _opened() -> void:
	var kept: Dictionary = world.cut_kept.duplicate(true)
	if seeing_through:
		set_xray(false)
	if cutting:
		_end_cut()
	_generation = world.generation()
	# A shared model's viewer only looks, with no strip to end a cut by: it
	# shows the model whole.
	var shell: Shell = get_parent() as Shell
	if kept.is_empty() or (shell != null and shell.read_only):
		return
	var lift: Vector3 = store.lift() if store != null else Vector3.ZERO
	leaves_ghosts = bool(kept.get("ghosts", false))
	_ghost_box.set_pressed_no_signal(leaves_ghosts)
	cutting = true
	if str(kept.get("shape")) == "plane":
		var n: int = CutShape.AXES.find(str(kept.get("axis")))
		var point := Vector3.ZERO
		point[n] = float(kept.get("at", 0.0))
		cuts_positive = float(kept.get("away", 1)) * LdrModel.FLIP[n] > 0.0
		_plane_on(n, (point * LdrModel.FLIP + lift)[n])
		return
	var from: Array = kept.get("from", [0, 0, 0])
	var to: Array = kept.get("to", [0, 0, 0])
	shape = maxi(CutShape.BOX, CutShape.KINDS.find(str(kept.get("shape"))))
	room = AABB(Vector3(from[0], from[1], from[2]) * LdrModel.FLIP + lift, Vector3.ZERO) \
		.expand(Vector3(to[0], to[1], to[2]) * LdrModel.FLIP + lift)
	_apply_cut()


## The cut off: the whole model drawn again. What the model keeps is the
## caller's: the person's Cut away forgets it, a model replaced has its own.
func _end_cut() -> void:
	cutting = false
	world.set_cut(false)
	builder.lattice.cut = Plane()
	builder.lattice.cut_shape = null
	bar.visible = false
	frame.visible = false
	_press = {}
	_drag = {}
	lit = -1


## Where the plane is, as a person would say it.
func _words_for(position: float) -> String:
	if axis == 1:
		return "%.1f bricks up" % (position / BrickLattice.BRICK)
	var from: float = position - _bounds.position[axis]
	return "%.1f studs in" % (from / BrickLattice.STUD)


## How big the shape is, as a person would say it.
func _size_words() -> String:
	var across: String = _studs(room.size.x)
	var plates: int = roundi(room.size.y / PLATE)
	match shape:
		CutShape.SPHERE:
			return "%s studs across" % across
		CutShape.CYLINDER:
			return "%s studs across, %d plates high" % [across, plates]
	return "%s × %s studs, %d plates high" % [across, _studs(room.size.z), plates]


static func _studs(ldu: float) -> String:
	var studs: float = ldu / BrickLattice.STUD
	return str(roundi(studs)) if is_equal_approx(studs, roundf(studs)) else "%.1f" % studs


## The plane's outline round the model's section, or the shape's.
func _draw_frame() -> void:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for segment: Array in _outline():
		lines.surface_add_vertex(segment[0])
		lines.surface_add_vertex(segment[1])
	lines.surface_end()
	frame.mesh = lines
	frame.visible = true


## The outline's segments: round the plane's section, the box's twelve
## edges, the sphere's three rounds, the cylinder's two and four sides.
func _outline() -> Array:
	var out: Array = []
	if shape == CutShape.PLANE:
		var box: AABB = _bounds.grow(BrickLattice.STUD * 0.5)
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		var corners: Array[Vector3] = []
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var point := Vector3.ZERO
			point[axis] = at
			point[u] = box.position[u] + box.size[u] * corner.x
			point[v] = box.position[v] + box.size[v] * corner.y
			corners.append(point)
		for n: int in 4:
			out.append([corners[n], corners[(n + 1) % 4]])
		return out
	var middle: Vector3 = room.get_center()
	var half: Vector3 = room.size * 0.5
	if shape == CutShape.BOX:
		for n: int in 3:
			var u: int = (n + 1) % 3
			var v: int = (n + 2) % 3
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var a: Vector3 = middle
				a[u] += half[u] * corner.x
				a[v] += half[v] * corner.y
				a[n] -= half[n]
				var b: Vector3 = a
				b[n] += room.size[n]
				out.append([a, b])
		return out
	var rounds: Array = []
	if shape == CutShape.SPHERE:
		rounds = [[middle, 0, 1], [middle, 1, 2], [middle, 0, 2]]
	else:
		for y: float in [room.position.y, room.end.y]:
			rounds.append([Vector3(middle.x, y, middle.z), 0, 2])
		for corner: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var side := Vector3(middle.x + half.x * corner.x, room.position.y,
				middle.z + half.z * corner.y)
			out.append([side, side + Vector3(0.0, room.size.y, 0.0)])
	for one: Array in rounds:
		var centre: Vector3 = one[0]
		var u: int = one[1]
		var v: int = one[2]
		var last: Vector3 = Vector3.ZERO
		for k: int in 49:
			var angle: float = TAU * k / 48.0
			var point: Vector3 = centre
			point[u] += half[u] * cos(angle)
			point[v] += half[v] * sin(angle)
			if k > 0:
				out.append([last, point])
			last = point
	return out


static func _odd(value: float) -> float:
	return floorf(value / STEP) * STEP + 1.0


func _model_box() -> AABB:
	var box: AABB = bounds_of_model.call()
	return box


# -- the knobs ----------------------------------------------------------------


## Each face's knob, where it is in the world: the middle of each face of
## the shape's room, -X, +X, -Y, +Y, -Z, +Z.
func knob_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var middle: Vector3 = room.get_center()
	for face: int in 6:
		var point: Vector3 = middle
		point[face / 2] = room.end[face / 2] if face % 2 == 1 else room.position[face / 2]
		out.append(point)
	return out


## The knob at [param point] on the screen, the nearest within reach, or -1.
func knob_at(point: Vector2) -> int:
	if not shape_on() or not (camera is CadCamera):
		return -1
	var eye: CadCamera = camera
	var view: int = eye.view_at(point)
	var best: int = -1
	var best_off: float = PICK * _scale()
	var points: Array[Vector3] = knob_points()
	for face: int in 6:
		if eye.behind(points[face], view):
			continue
		var off: float = eye.screen_of(points[face], view).distance_to(point)
		if off < best_off:
			best_off = off
			best = face
	return best


## Where knob [param face] is on the screen in the main view, for a probe or
## a browser test to press.
func knob_on_screen(face: int) -> Vector2:
	if not (camera is CadCamera):
		return Vector2.ZERO
	return (camera as CadCamera).screen_of(knob_points()[face])


func _scale() -> float:
	var window: Window = get_window() if is_inside_tree() else null
	return window.content_scale_factor if window != null and window.content_scale_factor > 0.0 \
		else 1.0


## The knobs as [param view] shows them: a dot in its axis's colour (the
## move handles'), lit while the pointer is over it or drags it, with a tick
## out along the way its face is pulled.
func _draw_knobs(canvas: Control, view: int) -> void:
	if not shape_on() or not (camera is CadCamera):
		return
	var eye: CadCamera = camera
	var scale: float = _scale()
	var points: Array[Vector3] = knob_points()
	for face: int in 6:
		if eye.behind(points[face], view):
			continue
		var on: bool = face == lit or int(_drag.get("face", -1)) == face
		var colour: Color = PivotMark.LIT if on else PivotMark.AXIS_COLOURS[face / 2]
		var middle: Vector2 = eye.screen_of(points[face], view)
		var out := Vector3.ZERO
		out[face / 2] = BrickLattice.STUD if face % 2 == 1 else -BrickLattice.STUD
		var way: Vector2 = eye.screen_of(points[face] + out, view) - middle
		if way.length() > 1.0:
			var tip: Vector2 = middle + way.normalized() * (KNOB + 9.0) * scale
			canvas.draw_line(middle, tip, PivotMark.EDGE, 4.0 * scale, true)
			canvas.draw_line(middle, tip, colour, 2.0 * scale, true)
		var radius: float = (KNOB + (1.5 if on else 0.0)) * scale
		canvas.draw_circle(middle, radius + 1.5 * scale, PivotMark.EDGE)
		canvas.draw_circle(middle, radius, colour)


func _follow_knobs() -> void:
	if _knobs == null:
		return
	if not shape_on():
		if _knobs.is_shown():
			_knobs.show_drawn(false)
			_drawn = []
		return
	var eye: CadCamera = camera as CadCamera
	var second: Array = eye.second.pose() if eye != null and eye.second != null \
		and eye.second.is_showing() else []
	var now: Array = [camera.global_transform, camera.size, camera.fov, camera.projection,
		_knobs.rect(CadCamera.MAIN), _knobs.rect(CadCamera.SECOND), second, room, shape, lit,
		_drag.get("face")]
	if now != _drawn or not _knobs.is_shown():
		_drawn = now
		_knobs.show_drawn(true)


func _unhandled_input(event: InputEvent) -> void:
	if not shape_on():
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		if _press.is_empty() and _drag.is_empty():
			lit = knob_at(moved.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or not _press.is_empty() or not _drag.is_empty():
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var turned: int = knob_at(button.position)
		if turned < 0:
			return
		get_viewport().set_input_as_handled()
		push(turned, 1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		say.call(_size_words())
		return
	if button.button_index != MOUSE_BUTTON_LEFT or button.ctrl_pressed or button.alt_pressed \
			or button.meta_pressed or button.double_click:
		return
	var face: int = knob_at(button.position)
	if face < 0:
		return
	get_viewport().set_input_as_handled()
	_press = {"face": face, "at": button.position, "whole": button.shift_pressed,
		"view": (camera as CadCamera).view_at(button.position)}


## A knob held: everything the pointer does is its, over the model or a
## panel, until it is let go. None held, a move unlights the knob here, and
## _unhandled_input lights it again only if the move reaches the view: a
## pointer that leaves a knob for a panel leaves no knob lit.
func _input(event: InputEvent) -> void:
	if _press.is_empty() and _drag.is_empty():
		if event is InputEventMouseMotion:
			lit = -1
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if key.pressed and key.keycode == KEY_ESCAPE and not _drag.is_empty():
			room = _drag["room"]
			_apply_cut()
			_drag = {}
			_press = {}
			say.call("put back as it was")
			get_viewport().set_input_as_handled()
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		get_viewport().set_input_as_handled()
		if _drag.is_empty():
			if moved.position.distance_to(_press["at"]) <= DRAG_SLOP * _scale():
				return
			_start(_press)
			_press = {}
		_follow(moved.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	get_viewport().set_input_as_handled()
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		if not _drag.is_empty():
			room = _drag["room"]
			_apply_cut()
			say.call("put back as it was")
		_drag = {}
		_press = {}
		return
	if button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	var was: Dictionary = _drag
	_drag = {}
	_press = {}
	if was.is_empty():
		say.call("drag a knob to push or pull its face a plate at a time; Shift drags the whole %s"
			% CutShape.KINDS[shape])
	else:
		say.call(_size_words())


func _start(press: Dictionary) -> void:
	var face: int = press["face"]
	var way := Vector3.ZERO
	way[face / 2] = 1.0 if face % 2 == 1 else -1.0
	_drag = {"face": face, "way": way, "pivot": knob_points()[face], "room": room,
		"whole": press["whole"], "view": press["view"], "plates": 0, "from": 0.0}
	var along: Variant = _along(press["at"])
	_drag["from"] = float(along) if along != null else 0.0


## The pointer at [param point]: its face, or with Shift the whole shape,
## where the pointer says, a plate at a time.
func _follow(point: Vector2) -> void:
	var along: Variant = _along(point)
	if along == null:
		return
	var plates: int = roundi((float(along) - float(_drag["from"])) / PLATE)
	if plates == int(_drag["plates"]):
		return
	_drag["plates"] = plates
	var face: int = _drag["face"]
	var start: AABB = _drag["room"]
	if bool(_drag["whole"]):
		room = _moved(start, face / 2, plates if face % 2 == 1 else -plates)
	else:
		room = _fitted(_pushed(start, face, plates), face / 2)
	_apply_cut()


## How far along the dragged knob's line the pointer is, in LDU from where
## the knob was: the nearest points of the pointer's ray and the line. Null
## where the line points at the eye.
func _along(point: Vector2) -> Variant:
	var eye: CadCamera = camera as CadCamera
	var view: int = int(_drag.get("view", CadCamera.MAIN))
	var origin: Vector3 = eye.ray_origin(point, view)
	var normal: Vector3 = eye.ray_normal(point, view)
	var way: Vector3 = _drag["way"]
	var b: float = way.dot(normal)
	var square: float = 1.0 - b * b
	if square < 0.0004:
		return null
	var w: Vector3 = (_drag["pivot"] as Vector3) - origin
	return (b * normal.dot(w) - way.dot(w)) / square


# -- x-ray --------------------------------------------------------------------


## Turn x-ray on or off. On, what stays solid is the sub-assembly being
## edited, or else the selection; with neither there is nothing to see
## through to, and it says so.
func set_xray(on: bool) -> bool:
	if not on:
		if seeing_through:
			seeing_through = false
			world.set_xray({})
			builder.lattice.see_through = {}
			say.call("x-ray off")
		return true
	var keep: Dictionary = {}
	if assemblies != null and not assemblies.entered.is_empty():
		_xray_path = assemblies.entered
		for brick_id: int in assemblies.ids_under(_xray_path):
			keep[brick_id] = true
	elif not builder.selection.is_empty():
		_xray_path = ""
		keep = builder.selection.duplicate()
	else:
		say.call(Keymap.filled("select what to see, or edit inside a sub-assembly, then x-ray ({xray})"))
		return false
	seeing_through = true
	_generation = world.generation()
	_see_through_all_but(keep)
	say.call(Keymap.filled("x-ray: everything but %s is see-through — {xray|again to end it}") % (
		"the sub-assembly" if not _xray_path.is_empty() else "the selection"))
	return true


func _see_through_all_but(keep: Dictionary) -> void:
	var ghosts: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		# The baseplate stays solid: it is where a part is put down.
		if not keep.has(brick.id) and not scenery.has(brick.id):
			ghosts[brick.id] = true
	world.set_xray(ghosts)
	builder.lattice.see_through = ghosts


## Editing inside another sub-assembly while x-ray is on sees through to
## that one instead; leaving the one x-ray was showing ends it.
func _on_entered(path: String) -> void:
	if not seeing_through or _xray_path.is_empty():
		return
	if path.is_empty():
		set_xray(false)
		return
	_xray_path = path
	var keep: Dictionary = {}
	for brick_id: int in assemblies.ids_under(path):
		keep[brick_id] = true
	_see_through_all_but(keep)


## A model replaced — opened, cleared, designed afresh — ends both: they
## were about the model that was there. One opened brings its own cut back
## once it is all down (_opened).
func _check_model() -> void:
	if (cutting or seeing_through) and world.generation() != _generation:
		set_xray(false)
		if cutting:
			_end_cut()


# -- the strip ----------------------------------------------------------------


func _process(_delta: float) -> void:
	_follow_knobs()
	if bar == null or not bar.visible:
		return
	# Above the key strip and the timeline when they are up, however many
	# rows they wrap to.
	var lift: float = 12.0
	var area: Rect2 = (bar.get_parent() as Control).get_global_rect()
	for under: Control in below:
		if under != null and under.is_visible_in_tree():
			lift = maxf(lift, area.end.y - under.get_global_rect().position.y + 8.0)
	if not is_equal_approx(bar.offset_bottom, -lift):
		bar.offset_bottom = -lift
		bar.offset_top = -lift - bar.get_combined_minimum_size().y


## The plane's controls for the plane, the shape's for a shape.
func _show_controls() -> void:
	var by_plane: bool = shape == CutShape.PLANE
	for control: Control in _for_plane:
		control.visible = by_plane
	for control: Control in _for_shape:
		control.visible = not by_plane
	if _shape_choice.selected != shape:
		_shape_choice.select(shape)


func _build_bar() -> void:
	bar = PanelContainer.new()
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.94)
	backing.border_color = Color(0.4, 0.66, 1.0, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 8
	backing.content_margin_right = 8
	backing.content_margin_top = 5
	backing.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", backing)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -12.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	# What the cut takes away, where the strip used to say "Cut along".
	_shape_choice = OptionButton.new()
	_shape_choice.accessibility_name = "Cut away by"
	_shape_choice.focus_mode = Control.FOCUS_NONE
	_shape_choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shape_choice.add_theme_font_size_override("font_size", 13)
	_dressed(_shape_choice)
	for words: String in SHAPES:
		_shape_choice.add_item(words)
	_shape_choice.select(shape)
	_shape_choice.tooltip_text = "What the cut takes away: what is past a plane, or what is inside a box, a sphere or a cylinder"
	_shape_choice.item_selected.connect(func(index: int) -> void: cut_by(index))
	row.add_child(_shape_choice)

	var group := ButtonGroup.new()
	for n: int in 3:
		var button: Button = _button(AXES[n])
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = "Cut across the model along %s" % (
			["X, left to right", "Y, bottom to top", "Z, front to back"][n])
		var which: int = n
		button.pressed.connect(func() -> void: cut_along(which))
		row.add_child(button)
		_axis_buttons.append(button)
		_for_plane.append(button)

	_slider = HSlider.new()
	_slider.accessibility_name = "Where the cut is"
	_slider.custom_minimum_size = Vector2(240, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_slider.tooltip_text = "Drag to move the cut through the model (the wheel moves it too)"
	_slider.value_changed.connect(func(value: float) -> void:
		if not _setting:
			move_to(value))
	row.add_child(_slider)
	_for_plane.append(_slider)

	_reading = Label.new()
	_reading.custom_minimum_size = Vector2(92, 0)
	_reading.add_theme_font_size_override("font_size", 12)
	_reading.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	row.add_child(_reading)
	_for_plane.append(_reading)

	var other: Button = _button("Flip")
	Keymap.tell(other, "Cut away the other side   {cut_flip}")
	other.pressed.connect(flip)
	row.add_child(other)
	_for_plane.append(other)

	_shrink = _button("Shrink")
	_shrink.tooltip_text = "Bring every face of the shape in a plate"
	_shrink.pressed.connect(func() -> void: grow(-1))
	row.add_child(_shrink)
	_for_shape.append(_shrink)
	_grow = _button("Grow")
	_grow.tooltip_text = "Take every face of the shape out a plate (drag a knob to move one face)"
	_grow.pressed.connect(func() -> void: grow(1))
	row.add_child(_grow)
	_for_shape.append(_grow)

	_size = Label.new()
	_size.custom_minimum_size = Vector2(150, 0)
	_size.add_theme_font_size_override("font_size", 12)
	_size.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	row.add_child(_size)
	_for_shape.append(_size)

	_ghost_box = CheckBox.new()
	_ghost_box.text = "Ghost"
	_ghost_box.focus_mode = Control.FOCUS_NONE
	_ghost_box.add_theme_font_size_override("font_size", 12)
	_ghost_box.tooltip_text = "Leave what is cut away as a faint ghost of itself"
	_ghost_box.toggled.connect(set_ghosts)
	row.add_child(_ghost_box)

	var close: Button = _button("×")
	Keymap.tell(close, "The whole model again   {cut}")
	close.pressed.connect(func() -> void: set_cut(false))
	row.add_child(close)
	_show_controls()


func _button(words: String) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = Vector2(28, 26)
	_dressed(button)
	return button


## The strip's faces on a button: faint, lighter under the pointer, blue
## when pressed.
static func _dressed(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = {"normal": Color(1, 1, 1, 0.07), "hover": Color(1, 1, 1, 0.14),
			"pressed": Color(0.36, 0.6, 1.0, 0.45),
			"hover_pressed": Color(0.36, 0.6, 1.0, 0.55)}[state]
		face.set_corner_radius_all(5)
		face.content_margin_left = 8
		face.content_margin_right = 8
		button.add_theme_stylebox_override(state, face)


## The strip's controls, for a probe or a browser test to press.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {"cut_slider": _slider, "cut_ghosts": _ghost_box,
		"cut_shape": _shape_choice, "cut_grow": _grow, "cut_shrink": _shrink}
	for n: int in 3:
		out["cut_" + AXES[n].to_lower()] = _axis_buttons[n]
	return out
