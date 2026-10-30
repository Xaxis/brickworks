## Handles on the selection: rings to turn it about an axis and arrows to
## slide it along one (docs/APP_UX.md, B3), drawn while the Rotate or the
## Move tool is in use, as Studio's rotate gizmo, LeoCAD's axis gizmo,
## Mecabricks' arrows and Onshape's triad have them. The Rotate tool was
## "click a part to turn it by the turn step", about the upright only, with
## nothing on screen to say about what; any other angle about any other axis
## was typed into Properties.
##
## - Three rings (Rotate) or three arrows (Move) on the axes of the part,
##   the model or the view: the tag beside them says which, and a click on
##   it goes to the next. A part's are its own, however its parent is turned.
## - Between the arrows, three panes, each sliding it on two axes at once
##   (Mecabricks). Round the rings, a fourth that turns it about the view's
##   axis, and inside them a trackball that turns it freely, as the pointer
##   rolls it (LeoCAD 26.09, 3ds Max's rotate gizmo; docs/APP_UX2.md, 7).
## - They stand where the selection hangs from: the pin, hinge or clip it
##   turns on, else the stud R turns it about (the middle, for a part off the
##   grid), or a point Alt-clicked.
## - A ring's drag snaps to quarter turns near the middle, to the turn step
##   on the ring, 5° past it and 1° further out, as Studio's dial does; an
##   arrow's to the snap, and to 2 LDU away from its line; a pane's to the
##   snap on each of its axes. The trackball is free.
## - A number typed while dragging, or straight after, sets it exactly
##   (TypedEntry): degrees for a ring, studs (or x, y, z, plates…) for an
##   arrow, and for a pane its two axes named ("3x -2z"), the handles'
##   own x, y and z.
## - Collision is kept: the drag stops at the last place with room, and the
##   part in the way lights up (EditVerbs._flash).
## - The model does not change while the button is held: the selection is
##   drawn moved (BrickWorld.set_drawn) and Builder.drag_begin keeps it out of
##   the lattice to weigh each place. Let go, the move is one step to undo.
##
## The states, and what moves between them:
##
##   idle   --press on a ring, an arrow, a pane or the trackball-->  pressed
##   pressed --let go where it was pressed-->  idle: the tool's own click
##   pressed --the pointer moves-->  drag, the selection drawn where it has room
##   drag   --let go-->  idle, one step to undo (none when it never moved)
##   drag   --Esc, a right click, another tool-->  idle, as it was
##   drag   --a digit-->  typed: the number sets it, the pointer does not
##   idle   --a digit straight after a drag-->  typed, the drag taken back
##   typed  --Enter-->  idle, one step;  --Esc-->  the drag as it was
class_name Handles
extends Node

## A ring's radius and an arrow's length on the screen, at the window's own
## scale, px.
const RADIUS := 64.0
## The most a ring's radius grows to round a big selection, px.
const LARGEST := 120.0
## How near a ring or an arrow the pointer has to be to take it, px.
const PICK := 9.0
## A press that moves no further than this is a click, px.
const DRAG_SLOP := 4.0
## A digit typed after a drag is for it until the pointer moves this far, px.
const AIMED_AGAIN := 6.0
const SEGMENTS := 64
## X, Y and Z as the pivot mark draws them (PivotMark).
const AXIS_COLOURS: Array[Color] = [Color(0.91, 0.30, 0.34), Color(0.42, 0.76, 0.32),
	Color(0.33, 0.58, 0.93)]
const LIT := Color(1.0, 0.85, 0.3)
const EDGE := Color(0.05, 0.07, 0.12, 0.85)
const AXES: Array[String] = ["x", "y", "z"]
const FRAMES: Array[String] = ["part", "model", "view"]
const FRAME_WORDS: Dictionary = {"part": "Part axes", "model": "Model axes",
	"view": "View axes"}
## Where a ring's drag gets finer, as the pointer's distance from the middle
## over the ring's radius: inside the first, quarter turns; to the second,
## the turn step; to the third, 5°; past it, 1°.
const ZONES: Array[float] = [0.6, 1.3, 2.0]
## The ring that turns about the view's axis, round the other three, as a
## share of their radius; its stops get finer by the same shares of its own.
const OUTER := 1.25
const OUTER_COLOUR := Color(0.86, 0.88, 0.92)
## Its axis, after x, y and z.
const VIEW_AXIS := 3
## A pane, from and to, as shares of how far an arrow reaches along each of
## its two axes: clear of the arrows, between them.
const PANE: Array[float] = [0.28, 0.68]
## A pane seen more nearly edge on than this share of its face is too thin
## to take, and is not drawn.
const PANE_THINNEST := 0.25
## How far the trackball turns for a drag of the rings' radius: a quarter.
const BALL_TURN := PI * 0.5
## A drag of more parts than this is moved on trust and weighed once, when
## it is let go: weighing each place of a whole model held every frame.
const BIG := 300
## The room tests' share of a frame, ms; the rest of the way is weighed in
## the frames after. A part is never cut short: a tyre on the baseplate at a
## new angle is 5 to 10 ms of cover worked out (Builder.drag_room).
const FRAME_BUDGET_MS := 3.0
## How finely the way between two snapped stops is weighed, so a drag does
## not jump through a thin part: degrees, and LDU.
const SWEEP_DEGREES := 5.0
const SWEEP_LDU := 4.0

var builder: Builder
var world: BrickWorld
var library: PartLibrary
var camera: CadCamera
var verbs: EditVerbs
## Says a line in the bar along the top.
var say: Callable = func(_line: String) -> void: pass
## The model changed by somebody's own hand.
var edited: Callable = func() -> void: pass
## Light up the parts in the way for a second.
var flash: Callable = func(_ids: PackedInt64Array) -> void: pass

## Whose axes the handles are on: "part", "model" or "view".
var frame: String = "part"
## The handle under the pointer, {kind, axis}, or empty.
var lit: Dictionary = {}
## The drag while the button is held (or a number typed for it): {kind
## ("ring", "arrow", "pane" or "ball"), axis (0 to 2, a pane's the one it is
## square to, [constant VIEW_AXIS] the outer ring's), way (the axis in the
## model), pivot, u and v (a ring's plane, a pane's two axes), value (where
## it has room: a ring's degrees, an arrow's LDU, a pane's LDU along u and v
## as a Vector2, the trackball's turn as a Basis), want (the same, where the
## pointer says), stuck (the first stop with no room past value, or null),
## step, big, typing, …}. Empty when nothing is dragged.
var drag: Dictionary = {}
## The drag just let go, for a number typed straight after to take its
## place: {drag, value, depth, at}. Empty when the pointer has moved on.
var _after: Dictionary = {}
## A press on a handle that has not moved yet: {handle, at, shift}.
var _press: Dictionary = {}
## The point Alt-clicked to turn about, or null for where it hangs from.
var _picked: Variant = null
var _eat_release: bool = false
## The pivot and the first part's axes, worked out again when the selection
## or the model changes.
var _seen: int = 0
var _cached: Array = []
var _pivot := Vector3.ZERO
var _part_axes := Basis.IDENTITY
## The box round the selection, in the model.
var _box := AABB()
var _pivot_is: String = ""
var _drawn: Array = []
## Drawn over the main view, and over the second one beside it while View,
## Split shows it: taken and dragged in the view the press was in.
var _overlays: ViewOverlays


func _ready() -> void:
	builder.selection_changed.connect(func(_count: int) -> void:
		_seen += 1
		_picked = null
		_after = {})
	# Over the model, under the menus and dialogs, as Connect's points.
	_overlays = ViewOverlays.new()
	_overlays.name = "Handles"
	_overlays.camera = camera
	_overlays.draw_in = _draw_handles
	add_child(_overlays)


## Whether the handles are on the selection now: the Move or Rotate tool,
## something selected and nothing in hand.
func shown() -> bool:
	return verbs != null and camera != null and (verbs.mode == "move" or verbs.mode == "rotate") \
		and not builder.selection.is_empty() and not builder.is_carrying() \
		and not builder.is_holding_figure() and not verbs.out_of_view \
		and not (verbs.measure != null and verbs.measure.active)


func is_dragging() -> bool:
	return not drag.is_empty()


## The next of the part's, the model's and the view's axes.
func cycle_frame() -> void:
	frame = FRAMES[(FRAMES.find(frame) + 1) % FRAMES.size()]
	say.call("%s: the %s turn and slide it along the %s's own" % [FRAME_WORDS[frame],
		"rings" if verbs.mode == "rotate" else "arrows", frame])
	_drawn = []


## The handles' axes now, as a basis whose columns are x, y and z.
func axes() -> Basis:
	if not drag.is_empty():
		return drag["axes"]
	match frame:
		"model":
			return Basis.IDENTITY
		"view":
			return camera.global_transform.basis.orthonormalized()
	_known()
	return _part_axes


## Where the handles stand: the point the selection turns about.
func pivot() -> Vector3:
	if not drag.is_empty():
		return drag["pivot"]
	_known()
	return _pivot


## What the pivot is: "picked", "joint", "stud" or "middle".
func pivot_is() -> String:
	_known()
	return _pivot_is


## Alt-click: the point under the pointer to turn about, a connection of
## the part there if one is near it; on nothing, back to where the
## selection hangs from. True when the click was the handles'.
func pick_pivot(at: Vector2) -> bool:
	if not shown() or not drag.is_empty():
		return false
	var origin: Vector3 = camera.ray_origin(at)
	var normal: Vector3 = camera.ray_normal(at)
	var hit: BrickLattice.Hit = builder.lattice.raycast(origin, normal)
	if not hit.is_valid():
		_picked = null
		_cached = []
		say.call("turning about where it hangs from again")
		return true
	var point: Vector3 = origin + normal * hit.distance
	_picked = Vector3(snappedf(point.x, 1.0), snappedf(point.y, 1.0), snappedf(point.z, 1.0))
	# A pin, a hole, an axle or a bar of the part there, if the click was on it.
	var brick: BrickWorld.Brick = world.get_brick(hit.brick_id)
	if brick != null:
		var best: float = PICK * 1.5 * _scale()
		var view: int = camera.view_at(at)
		for end: JointSnap.End in JointSnap.ends_for(library, brick.part_id):
			var middle: Vector3 = end.placed(brick.transform, 0).middle()
			if camera.behind(middle, view):
				continue
			var off: float = camera.screen_of(middle, view).distance_to(at)
			if off < best:
				best = off
				_picked = middle
	_cached = []
	_drawn = []
	say.call("turning about the point picked — Alt-click empty space to go back")
	return true


# -- what is drawn ---------------------------------------------------------------


func _scale() -> float:
	var window: Window = get_window() if is_inside_tree() else null
	return window.content_scale_factor if window != null and window.content_scale_factor > 0.0 \
		else 1.0


## A ring's radius on the screen now in [param view], px: round the
## selection as it is drawn there, between [constant RADIUS] and [constant
## LARGEST], and kept while dragged.
func _radius(view: int = CadCamera.MAIN) -> float:
	if not drag.is_empty():
		return drag["radius"]
	var frame_now: int = Engine.get_process_frames()
	if frame_now == _radius_frame[view]:
		return _radius_now[view]
	_radius_frame[view] = frame_now
	_known()
	var scale: float = _scale()
	var reach: float = 0.0
	if _box.has_volume() and camera != null:
		var shown := Rect2()
		for n: int in 8:
			var corner: Vector3 = _box.get_endpoint(n)
			if camera.behind(corner, view):
				shown = Rect2()
				break
			var at: Vector2 = camera.screen_of(corner, view)
			shown = Rect2(at, Vector2.ZERO) if n == 0 else shown.expand(at)
		reach = shown.size.length() * 0.3
	_radius_now[view] = clampf(reach, RADIUS * scale, LARGEST * scale)
	return _radius_now[view]


var _radius_now: Array[float] = [RADIUS, RADIUS]
var _radius_frame: Array[int] = [-1, -1]


## The pivot, and the first part's axes, worked out when the selection or the
## model has changed since.
func _known() -> void:
	var key: Array = [_seen, world.revision, _picked]
	if key == _cached:
		return
	_cached = key
	var bricks: Array = []
	var square: bool = true
	for brick_id: int in builder.selection:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		bricks.append(brick)
		if square and not BrickLattice.is_square_to_grid(brick.transform.basis):
			square = false
	if bricks.is_empty():
		return
	_part_axes = (bricks[0] as BrickWorld.Brick).transform.basis.orthonormalized()
	_box = AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		_box = here if first else _box.merge(here)
		first = false
	if _picked != null:
		_pivot = _picked
		_pivot_is = "picked"
		return
	var hung: Dictionary = builder.hung_from()
	if not hung.is_empty():
		_pivot = hung["point"]
		_pivot_is = "joint"
	elif square:
		_pivot = Carry.pivot_of(bricks, library)
		_pivot_is = "stud"
	else:
		_pivot = _box.get_center()
		_pivot_is = "middle"


## How many pixels an LDU at [param at] is across [param view].
func _px_per_ldu(at: Vector3, view: int = CadCamera.MAIN) -> float:
	var right: Vector3 = camera.eye_basis(view).x
	return camera.screen_of(at, view).distance_to(camera.screen_of(at + right, view))


## Two directions square to [param axis] and to each other, the plane a ring
## about it lies in: [u, v], v = axis × u, so a turn from u towards v is a
## turn about the axis by the right hand.
static func _plane_of(axis: Vector3) -> Array:
	var u: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	return [u, axis.cross(u).normalized()]


## Whether the handles are the Rotate tool's: rings and the trackball, not
## arrows and panes.
func _turning() -> bool:
	return drag.get("kind", "") in ["ring", "ball"] if not drag.is_empty() \
		else verbs.mode == "rotate"


## The three rings or the three arrows as they stand on the screen now in
## [param view] (the main one, or CadCamera.SECOND beside it): {kind, axis,
## way, points (a ring's SEGMENTS + 1, an arrow's start and tip), front (a
## ring's: each point on the near half)}. Empty when the pivot is behind the
## view. The outer ring and the panes are [method screen_extras].
func screen_handles(view: int = CadCamera.MAIN) -> Array:
	var out: Array = []
	var at: Vector3 = _drawn_at()
	if camera == null or camera.behind(at, view):
		return out
	var middle: Vector2 = camera.screen_of(at, view)
	var per: float = _px_per_ldu(at, view)
	if per < 0.0001:
		return out
	var radius: float = _radius(view)
	var reach: float = radius / per
	var basis: Basis = axes()
	var toward: Vector3 = camera.eye_basis(view).z
	var ring: bool = _turning()
	for n: int in 3:
		var way: Vector3 = [basis.x, basis.y, basis.z][n].normalized()
		if ring:
			var drawn: Dictionary = _ring_on_screen(at, way, reach, toward, view)
			if not drawn.is_empty():
				drawn.merge({"kind": "ring", "axis": n, "way": way, "middle": middle})
				out.append(drawn)
		else:
			var tip3: Vector3 = at + way * reach * 1.25
			if camera.behind(tip3, view):
				continue
			var tip: Vector2 = camera.screen_of(tip3, view)
			var length: float = tip.distance_to(middle)
			# An axis that points at the eye has no length on the screen to
			# drag along.
			if length < radius * 0.3:
				continue
			var from: Vector2 = middle + (tip - middle) / length * 10.0 * _scale()
			out.append({"kind": "arrow", "axis": n, "way": way,
				"points": PackedVector2Array([from, tip]), "middle": middle})
	return out


## A ring about [param way] at [param at], [param reach] LDU round, on the
## screen in [param view]: {points, front}, or empty where it goes behind
## the eye.
func _ring_on_screen(at: Vector3, way: Vector3, reach: float, toward: Vector3,
		view: int) -> Dictionary:
	var plane: Array = _plane_of(way)
	var points := PackedVector2Array()
	var front: Array = []
	for k: int in SEGMENTS + 1:
		var t: float = TAU * k / SEGMENTS
		var p: Vector3 = at + ((plane[0] as Vector3) * cos(t) + (plane[1] as Vector3) * sin(t)) \
			* reach
		if camera.behind(p, view):
			return {}
		points.append(camera.screen_of(p, view))
		front.append((p - at).dot(toward) >= -0.02 * reach)
	return {"points": points, "front": front}


## The Rotate tool's outer ring, about the view's axis, or the Move tool's
## panes, as they stand on the screen in [param view]: {kind, axis, way,
## points (the ring's, or a pane's four corners), middle, and a pane's u, v
## and pair (its two axes, in the model and by number)}. A pane seen nearly
## edge on is left out.
func screen_extras(view: int = CadCamera.MAIN) -> Array:
	var out: Array = []
	var at: Vector3 = _drawn_at()
	if camera == null or camera.behind(at, view):
		return out
	var middle: Vector2 = camera.screen_of(at, view)
	var per: float = _px_per_ldu(at, view)
	if per < 0.0001:
		return out
	var radius: float = _radius(view)
	var reach: float = radius / per
	var toward: Vector3 = camera.eye_basis(view).z
	if _turning():
		# Square to the view it is drawn in; while dragged, the way it was taken.
		var way: Vector3 = drag["way"] if int(drag.get("axis", -1)) == VIEW_AXIS else toward
		var drawn: Dictionary = _ring_on_screen(at, way, reach * OUTER, toward, view)
		if not drawn.is_empty():
			drawn.merge({"kind": "ring", "axis": VIEW_AXIS, "way": way, "middle": middle})
			out.append(drawn)
		return out
	var basis: Basis = axes()
	var face: float = pow((PANE[1] - PANE[0]) * radius, 2.0)
	for n: int in 3:
		# x and y, y and z, x and z: a pane is named by the axis it is square to.
		var pair: Array = [(n + 1) % 3, (n + 2) % 3]
		pair.sort()
		var u: Vector3 = basis[pair[0]].normalized()
		var v: Vector3 = basis[pair[1]].normalized()
		var corners := PackedVector2Array()
		for corner: Vector2 in [Vector2(PANE[0], PANE[0]), Vector2(PANE[1], PANE[0]),
				Vector2(PANE[1], PANE[1]), Vector2(PANE[0], PANE[1])]:
			var p: Vector3 = at + (u * corner.x + v * corner.y) * reach
			if camera.behind(p, view):
				corners = PackedVector2Array()
				break
			corners.append(camera.screen_of(p, view))
		if corners.is_empty() or _area(corners) < face * PANE_THINNEST:
			continue
		out.append({"kind": "pane", "axis": n, "way": basis[n].normalized(), "u": u, "v": v,
			"pair": pair, "points": corners, "middle": middle})
	return out


## How much of the screen a polygon covers, px².
static func _area(points: PackedVector2Array) -> float:
	var twice: float = 0.0
	for k: int in points.size():
		twice += points[k].cross(points[(k + 1) % points.size()])
	return absf(twice) * 0.5


## Where the handles are drawn: at the pivot, carried along by an arrow's
## or a pane's drag with the selection.
func _drawn_at() -> Vector3:
	match drag.get("kind", ""):
		"arrow":
			return (drag["pivot"] as Vector3) + (drag["way"] as Vector3) * float(drag["value"])
		"pane":
			var by: Vector2 = drag["value"]
			return (drag["pivot"] as Vector3) + (drag["u"] as Vector3) * by.x \
				+ (drag["v"] as Vector3) * by.y
	return pivot()


## The tag that says whose axes these are, which a click goes to the next,
## and while dragging how far it has gone: its box on the screen.
func _tag_box(said: String = "", view: int = CadCamera.MAIN) -> Rect2:
	var at: Vector3 = _drawn_at()
	if camera == null or camera.behind(at, view) or _overlays == null:
		return Rect2()
	var middle: Vector2 = camera.screen_of(at, view)
	var font: Font = _overlays.font()
	var size: int = roundi(12 * _scale())
	var words: Vector2 = font.get_string_size(FRAME_WORDS[frame] if said.is_empty() else said,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var radius: float = _radius(view)
	var box := Rect2(middle + Vector2(radius * 1.05, -radius * 1.25),
		words + Vector2(14, 8) * _scale())
	# Inside its own view.
	var room: Rect2 = _overlays.rect(view)
	box.position.x = clampf(box.position.x, room.position.x + 4.0,
		maxf(room.end.x - box.size.x - 4.0, room.position.x + 4.0))
	box.position.y = clampf(box.position.y, room.position.y + 4.0,
		maxf(room.end.y - box.size.y - 4.0, room.position.y + 4.0))
	return box


## The handle under [param at] on the screen: {kind, axis, way} or {kind:
## "frame"} for the tag, nearest the pointer; empty for none. A ring or an
## arrow before a pane, and any of them before the trackball inside the
## rings.
func handle_at(at: Vector2) -> Dictionary:
	if not shown():
		return {}
	# The view the pointer is over: its handles, as it draws them.
	var view: int = camera.view_at(at)
	if _tag_box("", view).has_point(at):
		return {"kind": "frame"}
	var best: Dictionary = {}
	var best_off: float = PICK * _scale()
	var three: Array = screen_handles(view)
	var extras: Array = screen_extras(view)
	var lines: Array = three + extras.filter(func(handle: Dictionary) -> bool:
		return handle["kind"] == "ring")
	for handle: Dictionary in lines:
		var points: PackedVector2Array = handle["points"]
		for k: int in points.size() - 1:
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(at, points[k], points[k + 1])
			var off: float = near.distance_to(at)
			# The near half of a ring before the far half behind it.
			if handle["kind"] == "ring" and not bool((handle["front"] as Array)[k]):
				off += 3.0 * _scale()
			if off < best_off:
				best_off = off
				best = {"kind": handle["kind"], "axis": handle["axis"], "way": handle["way"],
					"at": near, "segment": k, "view": view}
	if not best.is_empty():
		return best
	for handle: Dictionary in extras:
		if handle["kind"] == "pane" and Geometry2D.is_point_in_polygon(at, handle["points"]):
			return {"kind": "pane", "axis": handle["axis"], "way": handle["way"], "u": handle["u"],
				"v": handle["v"], "pair": handle["pair"], "at": at, "view": view}
	if _turning() and not three.is_empty():
		if at.distance_to(three[0]["middle"]) < _radius(view):
			return {"kind": "ball", "axis": -1, "way": Vector3.ZERO, "at": at, "view": view}
	return best


func _process(_delta: float) -> void:
	if not shown():
		if not drag.is_empty():
			cancel()
		_press = {}
		lit = {}
		if _overlays != null and _overlays.is_shown():
			_overlays.show_drawn(false)
			_drawn = []
		return
	if not drag.is_empty():
		_sweep()
	# Drawn again only when something it shows changed: a frame drawn for
	# nothing is a frame the app need not have drawn (IdleDraw).
	_overlays.camera = camera
	var second: Array = camera.second.pose() if camera.second != null \
		and camera.second.is_showing() else []
	var now: Array = [camera.global_transform, _overlays.rect(CadCamera.MAIN),
		_overlays.rect(CadCamera.SECOND), second, pivot(), axes(), lit, drag.get("value"),
		drag.get("want"), drag.get("kind"), frame, verbs.mode, _picked, drag.get("typing"),
		drag.get("pointer")]
	if now != _drawn or not _overlays.is_shown():
		_drawn = now
		_overlays.show_drawn(true)


## The handles as [param view] shows them, drawn on [param canvas] in the
## window's units (ViewOverlays).
func _draw_handles(canvas: Control, view: int) -> void:
	if not shown():
		return
	var scale: float = _scale()
	var handles: Array = screen_handles(view)
	if handles.is_empty():
		return
	var radius: float = _radius(view)
	var middle: Vector2 = handles[0]["middle"]
	# The trackball: lit while the pointer is over it, and while it turns.
	if lit.get("kind") == "ball" or drag.get("kind") == "ball":
		canvas.draw_circle(middle, radius, Color(1, 1, 1, 0.08))
		canvas.draw_arc(middle, radius, 0.0, TAU, 72, Color(LIT, 0.7), 1.5 * scale, true)
	for handle: Dictionary in handles + screen_extras(view):
		var n: int = handle["axis"]
		var kind: String = handle["kind"]
		var held: bool = not drag.is_empty() and drag["kind"] == kind and int(drag["axis"]) == n
		# A pane's drag shows its two arrows too, the axes it goes along.
		var beside: bool = drag.get("kind") == "pane" and kind == "arrow" \
			and n in (drag["pair"] as Array)
		if not drag.is_empty() and not held and not beside:
			continue
		var on: bool = held or (lit.get("axis", -1) == n and lit.get("kind") == kind)
		var colour: Color = LIT if on else (OUTER_COLOUR if n == VIEW_AXIS else AXIS_COLOURS[n])
		var points: PackedVector2Array = handle["points"]
		if kind == "ring":
			var runs: Array = _runs(points, handle["front"])
			for run: Array in runs:
				if run[1]:
					canvas.draw_polyline(run[0], EDGE, (5.0 if on else 4.0) * scale, true)
			for run: Array in runs:
				var near: bool = run[1]
				canvas.draw_polyline(run[0], colour if near else Color(colour, 0.35),
					((3.0 if on else 2.2) if near else 1.2) * scale, true)
		elif kind == "pane":
			# Coloured as the axis it is square to, as the arrow left out of it.
			canvas.draw_colored_polygon(points, Color(colour, 0.65 if on else 0.45))
			var edge := PackedVector2Array(points)
			edge.append(points[0])
			canvas.draw_polyline(edge, EDGE, 3.0 * scale, true)
			canvas.draw_polyline(edge, colour, (2.0 if on else 1.4) * scale, true)
		else:
			var from: Vector2 = points[0]
			var tip: Vector2 = points[1]
			var along: Vector2 = (tip - from).normalized()
			var side: Vector2 = along.orthogonal() * 5.5 * scale
			var back: Vector2 = tip - along * 13.0 * scale
			canvas.draw_line(from, back, EDGE, (5.0 if on else 4.5) * scale, true)
			canvas.draw_line(from, back, colour, (3.0 if on else 2.4) * scale, true)
			var head := PackedVector2Array([tip + along * scale, back + side * 1.25,
				back - side * 1.25])
			canvas.draw_colored_polygon(head, EDGE)
			canvas.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
				colour)
	# The pivot: white, or amber where it was picked.
	canvas.draw_circle(middle, 4.5 * scale, EDGE)
	canvas.draw_circle(middle, 3.0 * scale, LIT if _picked != null else Color.WHITE)
	var font: Font = canvas.get_theme_default_font()
	var size: int = roundi(12 * scale)
	if drag.is_empty():
		var box: Rect2 = _tag_box("", view)
		var face := StyleBoxFlat.new()
		face.bg_color = Look.FACE
		face.border_color = LIT if lit.get("kind") == "frame" else Look.EDGE
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		canvas.draw_style_box(face, box)
		canvas.draw_string(font, box.position + Vector2(7.0 * scale, box.size.y - 6.0 * scale),
			FRAME_WORDS[frame], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Look.ROW_WORDS)
		return
	# Dragging: where a ring gets finer, and how far it has gone.
	if drag["kind"] == "ring":
		var round: float = radius * _zone_share()
		for zone: int in [1, 2]:
			canvas.draw_arc(middle, round * ZONES[zone], 0.0, TAU, 72,
				Color(1, 1, 1, 0.22), 1.0 * scale, true)
			canvas.draw_string(font, middle + Vector2(4.0 * scale, -round * ZONES[zone] - 3.0 * scale),
				"5°" if zone == 1 else "1°", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * scale),
				Color(1, 1, 1, 0.6))
	var said: String = _amount(drag, drag["value"])
	if drag.get("stuck") != null:
		said += " · no room further"
	var box: Rect2 = _tag_box(said, view)
	var face := StyleBoxFlat.new()
	face.bg_color = Look.FACE
	face.border_color = Look.EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(4)
	canvas.draw_style_box(face, box)
	canvas.draw_string(font, box.position + Vector2(7.0 * scale, box.size.y - 6.0 * scale),
		said, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Look.ROW_WORDS)


## The share of the rings' radius a ring's stops are measured in: the outer
## ring's own.
func _zone_share(of: Dictionary = drag) -> float:
	return OUTER if int(of.get("axis", -1)) == VIEW_AXIS else 1.0


## A ring's points cut where it passes from the near half to the far one:
## [points, near] a run, each drawn as one line.
static func _runs(points: PackedVector2Array, front: Array) -> Array:
	var out: Array = []
	var k: int = 0
	while k < points.size() - 1:
		var near: bool = front[k]
		var run := PackedVector2Array([points[k]])
		while k < points.size() - 1 and bool(front[k]) == near:
			run.append(points[k + 1])
			k += 1
		out.append([run, near])
	return out


## What the drag [param of] at [param value] says: "+23.5°", "+3 studs",
## "x +3 studs, z -2 studs" or "23.5°" (the trackball's, about whatever axis
## it rolled to).
static func _amount(of: Dictionary, value: Variant) -> String:
	match of["kind"]:
		"ring":
			return "%s°" % TypedEntry._num(float(value), true)
		"ball":
			return "%s°" % TypedEntry._num(rad_to_deg(Quaternion(value as Basis).get_angle()), false)
		"pane":
			var by: Vector2 = value
			var said := PackedStringArray()
			for k: int in 2:
				if not is_zero_approx(by[k]) or (by.is_zero_approx() and k == 0):
					said.append("%s %s" % [AXES[int((of["pair"] as Array)[k])],
						TypedEntry._length_words(by[k], absf((of["u" if k == 0 else "v"] as Vector3).y) > 0.7)])
			return ", ".join(said)
	return TypedEntry._length_words(float(value), absf((of["way"] as Vector3).y) > 0.7)


## The handles' box on the screen, for the typed field to open clear of.
func on_screen() -> Rect2:
	var at: Vector3 = _drawn_at()
	var view: int = int(drag.get("view", CadCamera.MAIN))
	if camera == null or camera.behind(at, view):
		return Rect2()
	var reach: float = _radius(view) * (OUTER + 0.05)
	return Rect2(camera.screen_of(at, view) - Vector2(reach, reach), Vector2(reach, reach) * 2.0)


# -- the drag ---------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	# The pointer gone on from where a drag was let go, over the model or a
	# panel: a digit now is not for that drag.
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null and not _after.is_empty() \
			and moved.position.distance_to(_after["at"]) > AIMED_AGAIN:
		_after = {}
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		# A release kept from the model never came (it was let go over a
		# panel): this press is a new one.
		_eat_release = false
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and not drag.is_empty() and not bool(drag.get("typing", false)):
		cancel()
		say.call("put back as it was")
		get_viewport().set_input_as_handled()
		return
	# A key other than what opens the field (a digit, "." or "-") means the
	# drag just let go is done with: R after it is R's.
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT]:
		return
	var c: String = TypedEntry._character(key)
	if c.is_empty() or not (c.is_valid_int() or c == "." or c == "-"):
		_after = {}


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if _eat_release and button != null and button.button_index == MOUSE_BUTTON_LEFT \
			and not button.pressed:
		_eat_release = false
		get_viewport().set_input_as_handled()
		return
	if not drag.is_empty() or not _press.is_empty():
		_while_held(event)
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		var over: Dictionary = handle_at(moved.position) if shown() else {}
		if over.get("kind") != lit.get("kind") or over.get("axis") != lit.get("axis"):
			lit = over
		return
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	_after = {}
	if button.alt_pressed or button.ctrl_pressed or button.meta_pressed or button.double_click \
			or Input.is_key_pressed(KEY_SPACE):
		return
	var handle: Dictionary = handle_at(button.position)
	if handle.is_empty():
		return
	get_viewport().set_input_as_handled()
	if handle["kind"] == "frame":
		cycle_frame()
		_eat_release = true
		return
	_press = {"handle": handle, "at": button.position, "shift": button.shift_pressed}


func _while_held(event: InputEvent) -> void:
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		get_viewport().set_input_as_handled()
		if drag.is_empty():
			if moved.position.distance_to(_press["at"]) <= DRAG_SLOP:
				return
			var press: Dictionary = _press
			_press = {}
			if not _start(press["handle"], press["at"]):
				return
		if not bool(drag.get("typing", false)):
			_follow(moved.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	get_viewport().set_input_as_handled()
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		_press = {}
		if not drag.is_empty():
			cancel()
			say.call("put back as it was")
		return
	if button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	if drag.is_empty():
		# Let go where it was pressed: a click, the tool's own (EditVerbs.click).
		var press: Dictionary = _press
		_press = {}
		verbs.click(button.position, bool(press.get("shift", false)))
		return
	if bool(drag.get("typing", false)):
		# The number is being typed: the field puts it down.
		drag["mouse_up"] = true
		drag["again"] = drag["value"]
		return
	_let_go()


## A drag begun on [param handle], pressed at [param at]. False when the
## selection could not be taken to drag.
func _start(handle: Dictionary, at: Vector2) -> bool:
	var center: Vector3 = pivot()
	var basis: Basis = axes()
	var held: int = builder.drag_begin()
	if held == 0:
		return false
	var way: Vector3 = handle["way"]
	var plane: Array = _plane_of(way)
	# Dragged in the view it was taken in, wherever the pointer goes.
	var view: int = int(handle.get("view", CadCamera.MAIN))
	var radius: float = _radius(view)
	var reach: float = radius / maxf(_px_per_ldu(center, view), 0.0001)
	drag = {"view": view, "radius": radius, "kind": handle["kind"], "axis": handle["axis"],
		"way": way, "pivot": center,
		"axes": basis, "frame": frame, "u": plane[0], "v": plane[1], "reach": reach,
		"value": 0.0, "want": 0.0, "stuck": null, "step": 1.0, "turned": 0.0,
		"held": held, "clear": 0.0, "piece": 0.0, "parts": 0,
		"big": held > BIG, "typing": false, "pointer": at, "last_at": at}
	if handle["kind"] == "pane":
		# Its two axes, and the point on its plane it was taken by.
		drag.merge({"u": handle["u"], "v": handle["v"], "pair": handle["pair"],
			"value": Vector2.ZERO, "want": Vector2.ZERO, "step": Vector2.ONE, "clear": [],
			"piece": null}, true)
		var on: Variant = _on_pane(at)
		drag["from"] = on if on != null else Vector2.ZERO
	elif handle["kind"] == "ball":
		# Rolled as the view it was taken in sees it.
		drag.merge({"eye": camera.eye_basis(view), "value": Basis.IDENTITY,
			"want": Basis.IDENTITY, "clear": [], "piece": null}, true)
	elif handle["kind"] == "ring":
		var looking: Vector3 = camera.ray_normal(camera.screen_of(center, view), view)
		drag["edge_on"] = absf(way.dot(looking)) < 0.25
		var angle: Variant = _ring_angle(at)
		drag["last"] = angle if angle != null else 0.0
		if bool(drag["edge_on"]) or angle == null:
			drag["edge_on"] = true
			# Along the ring's line on the screen where it was taken, a
			# radian a ring's radius.
			var t: float = TAU * int(handle.get("segment", 0)) / SEGMENTS
			var u: Vector3 = plane[0]
			var v: Vector3 = plane[1]
			var a: Vector2 = camera.screen_of(center + (u * cos(t - 0.05)
				+ v * sin(t - 0.05)) * reach, view)
			var b: Vector2 = camera.screen_of(center + (u * cos(t + 0.05)
				+ v * sin(t + 0.05)) * reach, view)
			drag["tangent"] = (b - a) / 0.1
	else:
		var along: Variant = _along(at)
		drag["from"] = along if along != null else 0.0
	return true


## The angle about the ring's axis of the point the pointer is over on its
## plane, from u towards v; null where the plane is edge on to the eye.
func _ring_angle(at: Vector2) -> Variant:
	var view: int = int(drag.get("view", CadCamera.MAIN))
	var origin: Vector3 = camera.ray_origin(at, view)
	var normal: Vector3 = camera.ray_normal(at, view)
	var way: Vector3 = drag["way"]
	var across: float = normal.dot(way)
	if absf(across) < 0.0001:
		return null
	var t: float = ((drag["pivot"] as Vector3) - origin).dot(way) / across
	if t < 0.0:
		return null
	var local: Vector3 = origin + normal * t - (drag["pivot"] as Vector3)
	return atan2(local.dot(drag["v"]), local.dot(drag["u"]))


## How far along the arrow's line the pointer is, in LDU from the pivot:
## the nearest points of the pointer's ray and the line. Null where the line
## points at the eye.
func _along(at: Vector2) -> Variant:
	var view: int = int(drag.get("view", CadCamera.MAIN))
	var origin: Vector3 = camera.ray_origin(at, view)
	var normal: Vector3 = camera.ray_normal(at, view)
	var way: Vector3 = drag["way"]
	var b: float = way.dot(normal)
	var square: float = 1.0 - b * b
	if square < 0.0004:
		return null
	var w: Vector3 = (drag["pivot"] as Vector3) - origin
	return (b * normal.dot(w) - way.dot(w)) / square


## Where the pointer is on the pane's plane, in LDU from the pivot along its
## two axes; null where the plane is edge on to the eye or behind it.
func _on_pane(at: Vector2) -> Variant:
	var view: int = int(drag.get("view", CadCamera.MAIN))
	var origin: Vector3 = camera.ray_origin(at, view)
	var normal: Vector3 = camera.ray_normal(at, view)
	var way: Vector3 = drag["way"]
	var across: float = normal.dot(way)
	if absf(across) < 0.02:
		return null
	var t: float = ((drag["pivot"] as Vector3) - origin).dot(way) / across
	if t < 0.0:
		return null
	var local: Vector3 = origin + normal * t - (drag["pivot"] as Vector3)
	return Vector2(local.dot(drag["u"]), local.dot(drag["v"]))


## The snap along [param way]: the toolbar's across, or up for an upright.
func _snap_along(way: Vector3) -> float:
	var snaps: Array = EditVerbs.SNAPS[verbs.snap]
	return float(snaps[1] if absf(way.y) > 0.7 else snaps[0])


## The pointer at [param at]: where it says the drag goes, snapped, and the
## way there weighed.
func _follow(at: Vector2) -> void:
	var view: int = int(drag.get("view", CadCamera.MAIN))
	var middle: Vector2 = camera.screen_of(drag["pivot"], view)
	var reach: float = _radius()
	if drag["kind"] == "pane":
		var on: Variant = _on_pane(at)
		if on == null:
			return
		var step := Vector2(_snap_along(drag["u"]), _snap_along(drag["v"]))
		drag["step"] = step
		drag["want"] = ((on as Vector2) - (drag["from"] as Vector2)).snapped(step)
	elif drag["kind"] == "ball":
		# Rolled the way the pointer goes: about the line square to it in the
		# view's plane, a quarter turn for the rings' radius.
		var by: Vector2 = at - (drag["last_at"] as Vector2)
		if by.length() > 0.01:
			var eye: Basis = drag["eye"]
			var axis: Vector3 = eye.z.cross(eye.x * by.x - eye.y * by.y).normalized()
			drag["want"] = (Basis(axis, by.length() / reach * BALL_TURN)
				* (drag["want"] as Basis)).orthonormalized()
	elif drag["kind"] == "ring":
		if bool(drag["edge_on"]):
			var tangent: Vector2 = drag["tangent"]
			if tangent.length_squared() > 0.0001:
				drag["turned"] = float(drag["turned"]) + (at - (drag["last_at"] as Vector2)).dot(
					tangent) / tangent.length_squared()
		else:
			var angle: Variant = _ring_angle(at)
			if angle != null:
				drag["turned"] = float(drag["turned"]) + wrapf(float(angle) - float(drag["last"]),
					-PI, PI)
				drag["last"] = angle
		var out: float = at.distance_to(middle) / (reach * _zone_share())
		var step: float = 1.0
		if out < ZONES[0]:
			step = 90.0
		elif out < ZONES[1]:
			step = verbs.turn_step
		elif out < ZONES[2]:
			step = minf(5.0, verbs.turn_step)
		drag["step"] = step
		drag["want"] = snappedf(rad_to_deg(float(drag["turned"])), step)
	else:
		var along: Variant = _along(at)
		if along == null:
			return
		var tip: Vector2 = camera.screen_of((drag["pivot"] as Vector3)
			+ (drag["way"] as Vector3) * float(drag["reach"]), view)
		var off: float = at.distance_to(Geometry2D.get_closest_point_to_segment_uncapped(at,
			middle, tip))
		var step: float = _snap_along(drag["way"])
		if off > reach:
			step = BrickLattice.CELL
		drag["step"] = step
		drag["want"] = snappedf(float(along) - float(drag["from"]), step)
	drag["last_at"] = at
	drag["pointer"] = at
	_sweep()


## The model moved by the drag at [param value]: a ring's degrees, an
## arrow's LDU, a pane's LDU on its two axes, the trackball's turn.
func _moved_by(value: Variant, of: Dictionary = drag) -> Transform3D:
	var way: Vector3 = of["way"]
	var at: Vector3 = of["pivot"]
	match of["kind"]:
		"ring":
			return Transform3D(Basis.IDENTITY, at) * Transform3D(Basis(way,
				deg_to_rad(float(value))), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -at)
		"ball":
			return Transform3D(Basis.IDENTITY, at) * Transform3D(value as Basis, Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -at)
		"pane":
			var by: Vector2 = value
			return Transform3D(Basis.IDENTITY, (of["u"] as Vector3) * by.x + (of["v"] as Vector3) * by.y)
	return Transform3D(Basis.IDENTITY, way * float(value))


## Whether a drag of [param value] goes nowhere.
static func _nowhere(value: Variant) -> bool:
	if value is Basis:
		return (value as Basis).is_equal_approx(Basis.IDENTITY)
	if value is Vector2:
		return (value as Vector2).is_zero_approx()
	return is_zero_approx(float(value))


## Towards where the pointer says, a snapped stop at a time, each stop and
## the way to it weighed, until there is no room further or the frame's
## share is spent (one share a frame, however often the pointer moved in
## it); [param whole], to the end however long it takes, as when let go.
## The selection drawn at the last stop with room.
func _sweep(whole: bool = false) -> void:
	if drag.is_empty() or bool(drag.get("typing", false)):
		return
	if drag["kind"] == "pane" or drag["kind"] == "ball":
		_sweep_on(whole)
		return
	var want: float = drag["want"]
	var at: float = drag["value"]
	if is_equal_approx(want, at):
		return
	if bool(drag["big"]):
		drag["value"] = want
		_show(want)
		return
	if Engine.get_process_frames() != _swept_in:
		_swept_in = Engine.get_process_frames()
		_sweep_until = Time.get_ticks_usec() + int(FRAME_BUDGET_MS * 1000.0)
	var until: int = 0 if whole else _sweep_until
	var moved: bool = false
	var step: float = maxf(float(drag["step"]), 0.001)
	var fine: float = SWEEP_DEGREES if drag["kind"] == "ring" else SWEEP_LDU
	while not is_equal_approx(at, want) and (whole or Time.get_ticks_usec() < until):
		var way: float = signf(want - at)
		var stuck: Variant = drag["stuck"]
		if stuck != null and signf(float(stuck) - at) == way \
				and absf(want - at) >= absf(float(stuck) - at) - 0.0001:
			break
		# The next stop on the step's grid, not past where the pointer says.
		var next: float = (floorf(at / step + 0.0001) + 1.0) * step if way > 0.0 \
			else (ceilf(at / step - 0.0001) - 1.0) * step
		next = minf(next, want) if way > 0.0 else maxf(next, want)
		# Weighed a fine piece at a time from the farthest place found clear,
		# a piece's parts carried over from the frame that ran out of time.
		var clear: float = drag["clear"] if signf(float(drag["clear"]) - at) == way else at
		var blocked: bool = false
		while not is_equal_approx(clear, next) and (whole or Time.get_ticks_usec() < until):
			var piece: float = clear + way * minf(fine, absf(next - clear))
			var from: int = drag["parts"] if is_equal_approx(drag["piece"], piece) else 0
			var got: int = builder.drag_room(_moved_by(piece), from, until)
			if got < 0:
				blocked = true
				break
			drag["piece"] = piece
			drag["parts"] = got
			if got < int(drag["held"]):
				break
			clear = piece
			drag["parts"] = 0
		drag["clear"] = clear
		if blocked:
			drag["stuck"] = next
			drag["parts"] = 0
			flash.call(builder.refused_by)
			break
		if not is_equal_approx(clear, next):
			break
		at = next
		moved = true
		drag["stuck"] = null
	if moved:
		drag["value"] = at
		_show(at)


var _swept_in: int = -1
var _sweep_until: int = 0


## [method _sweep] for a pane's drag, on two axes at once, and the
## trackball's, whose values are not one number: from stop to stop on the
## straight way to where the pointer says, a pane's stops on the snap of
## each axis, the trackball's 5° apart. It stops at the last with room.
func _sweep_on(whole: bool) -> void:
	var want: Variant = drag["want"]
	var at: Variant = drag["value"]
	if _same(at, want):
		return
	if bool(drag["big"]):
		drag["value"] = want
		_show(want)
		return
	if Engine.get_process_frames() != _swept_in:
		_swept_in = Engine.get_process_frames()
		_sweep_until = Time.get_ticks_usec() + int(FRAME_BUDGET_MS * 1000.0)
	var until: int = 0 if whole else _sweep_until
	var moved: bool = false
	while not _same(at, want) and (whole or Time.get_ticks_usec() < until):
		var next: Variant = _stop_after(at, want)
		# No room there last time, and the pointer still says that way.
		if drag["stuck"] != null and _same(drag["stuck"], next):
			break
		var was: Array = drag["clear"]
		var clear: Variant = was[2] if was.size() == 3 and _same(was[0], at) \
			and _same(was[1], next) else at
		var blocked: bool = false
		while not _same(clear, next) and (whole or Time.get_ticks_usec() < until):
			var piece: Variant = _piece_after(clear, next)
			var from: int = drag["parts"] if drag["piece"] != null \
				and _same(drag["piece"], piece) else 0
			var got: int = builder.drag_room(_moved_by(piece), from, until)
			if got < 0:
				blocked = true
				break
			drag["piece"] = piece
			drag["parts"] = got
			if got < int(drag["held"]):
				break
			clear = piece
			drag["parts"] = 0
		drag["clear"] = [at, next, clear]
		if blocked:
			drag["stuck"] = next
			drag["parts"] = 0
			flash.call(builder.refused_by)
			break
		if not _same(clear, next):
			break
		at = next
		moved = true
		drag["stuck"] = null
	if moved:
		drag["value"] = at
		_show(at)


## The next stop from [param at] towards [param want]: a pane's on the snap
## of each axis, along the straight way between; the trackball's 5° on.
func _stop_after(at: Variant, want: Variant) -> Variant:
	if at is Basis:
		var from := Quaternion(at as Basis)
		var to := Quaternion(want as Basis)
		var left: float = from.angle_to(to)
		var most: float = deg_to_rad(SWEEP_DEGREES)
		return want if left <= most else Basis(from.slerp(to, most / left))
	var here: Vector2 = at
	var there: Vector2 = want
	var step: Vector2 = drag["step"]
	var left: Vector2 = there - here
	var count: float = maxf(ceilf(absf(left.x) / step.x - 0.001), ceilf(absf(left.y) / step.y - 0.001))
	if count <= 1.0:
		return there
	var next: Vector2 = (here + left / count).snapped(step)
	return there if next.is_equal_approx(here) else next


## A piece of the way from [param clear] to the stop [param next] to weigh
## at once: a pane's 4 LDU; the trackball's stops are pieces already.
func _piece_after(clear: Variant, next: Variant) -> Variant:
	if clear is Basis:
		return next
	return (clear as Vector2).move_toward(next, SWEEP_LDU)


## Whether two places of a drag are one. Bases compared as they are: a
## quaternion's angle_to a copy of itself is not 0 in floats.
static func _same(a: Variant, b: Variant) -> bool:
	if a is Basis:
		return (a as Basis).is_equal_approx(b as Basis)
	if a is Vector2:
		return (a as Vector2).is_equal_approx(b)
	return is_equal_approx(float(a), float(b))


func _show(value: Variant) -> void:
	world.set_drawn(builder.drag_places(_moved_by(value)))


## Let go: where the drag had room, one step to undo.
func _let_go() -> void:
	_sweep(true)
	var was: Dictionary = drag
	drag = {}
	world.set_drawn({})
	var value: Variant = was["value"]
	var by: Transform3D = _moved_by(value, was)
	var depth: int = builder.history_depth()
	var words: String = _words(was, _amount(was, value))
	var moved: int = builder.drag_end(by if not _nowhere(value) else Transform3D.IDENTITY,
		words)
	_drawn = []
	if moved > 0:
		if _picked != null:
			_picked = by * (_picked as Vector3)
		edited.call()
		# The trackball's turn is free: no number makes it exact.
		if was["kind"] == "ball":
			say.call(Keymap.filled("%s — {undo|undoes it}") % words)
			return
		say.call(Keymap.filled("%s — type a number to make it exact, {undo|undoes it}") % words)
		_after = {"drag": was, "value": value, "depth": depth,
			"at": was.get("pointer", Vector2.ZERO)}
		return
	if not _nowhere(value):
		flash.call(builder.refused_by)
		say.call("no room there — what it would hit is lit up")
	elif was.get("stuck") != null:
		say.call("no room to %s it that way — what is in the way is lit up"
			% ("turn" if was["kind"] in ["ring", "ball"] else "slide"))


## Put the selection back as it was before the drag. The button's release
## that follows is the handles' still: let through, it is a click on the
## model, which with the Move tool picks the part up.
func cancel() -> void:
	if not _press.is_empty():
		_eat_release = true
	_press = {}
	if drag.is_empty():
		return
	if not bool(drag.get("mouse_up", false)):
		_eat_release = true
	drag = {}
	world.set_drawn({})
	builder.drag_end(Transform3D.IDENTITY)
	_drawn = []


## What a drag did, in the history's words: "turned 1 part +23.5° about the
## part's x", "slid 1 part x +3 studs, z -2 studs on its own axes".
func _words(of: Dictionary, amount: String) -> String:
	var count: int = (of.get("count", builder.selection.size()))
	var parts: String = "1 part" if count == 1 else "%d parts" % count
	var whose: String = "its own" if of["frame"] == "part" else "the %s's" % of["frame"]
	match of["kind"]:
		"ball":
			return "turned %s %s freely" % [parts, amount]
		"pane":
			return "slid %s %s on %s axes" % [parts, amount, whose]
		"ring":
			if int(of["axis"]) == VIEW_AXIS:
				return "turned %s %s about the view's axis" % [parts, amount]
			return "turned %s %s about %s %s" % [parts, amount, whose, AXES[int(of["axis"])]]
	return "slid %s %s along %s %s" % [parts, amount, whose, AXES[int(of["axis"])]]


# -- a number typed for it (TypedEntry) ---------------------------------------------


## Whether a number typed now is the handles': while one is dragged, or
## straight after.
func wants_typing() -> bool:
	return not drag.is_empty() or not _after.is_empty()


func is_typing() -> bool:
	return bool(drag.get("typing", false))


## What a number alone is: degrees for a ring, a length along an arrow. A
## pane's takes its axes named, so a number alone asks which way.
func typed_verb() -> String:
	var kind: String = str(drag.get("kind", (_after.get("drag", {}) as Dictionary).get("kind", "")))
	return "turn" if kind == "ring" else "move"


func typed_way() -> Vector3:
	return drag["way"] if drag.get("kind", "") == "arrow" else Vector3.ZERO


## The first digit: the drag held where it is for the number to set it,
## or, straight after a drag, the drag taken back and its handle held again
## at nothing. False when there is nothing to type for, and while the
## trackball turns, which is free.
func begin_typing() -> bool:
	if drag.get("kind", "") == "ball":
		return false
	if drag.is_empty():
		if _after.is_empty():
			return false
		var after: Dictionary = _after
		_after = {}
		if builder.history_depth() != int(after["depth"]) + 1 or not builder.undo():
			return false
		edited.call()
		if builder.drag_begin() == 0:
			builder.redo()
			edited.call()
			return false
		drag = (after["drag"] as Dictionary).duplicate()
		var pane: bool = drag["kind"] == "pane"
		drag.merge({"value": Vector2.ZERO if pane else 0.0, "want": Vector2.ZERO if pane else 0.0,
			"stuck": null, "clear": [] if pane else 0.0, "parts": 0}, true)
		drag["mouse_up"] = true
		drag["again"] = after["value"]
		if _picked != null:
			_picked = _moved_by(after["value"], drag).affine_inverse() * (_picked as Vector3)
	drag["typing"] = true
	return true


## What the typed text moves it by, or in words why it cannot.
func _typed_move(what: Dictionary) -> Variant:
	var move: Vector3 = what["move"]
	var turn: float = float(what["turn"]) + float(what["tilt"])
	if drag["kind"] == "ring":
		if not move.is_zero_approx():
			return "a ring turns it: type degrees"
		return _moved_by(turn)
	if not is_zero_approx(turn):
		return "%s slides it: type a length" % ("a pane" if drag["kind"] == "pane" else "an arrow")
	if drag["kind"] == "pane":
		# The handles' own x, y and z, two of which the pane is on.
		var pair: Array = drag["pair"]
		if not is_zero_approx(move[int(drag["axis"])]):
			return "this pane slides it along %s and %s" % [AXES[int(pair[0])], AXES[int(pair[1])]]
		return Transform3D(Basis.IDENTITY, (drag["axes"] as Basis) * move)
	return Transform3D(Basis.IDENTITY, move)


func typed_preview(what: Dictionary) -> String:
	if drag.is_empty():
		return "nothing to move"
	var by: Variant = _typed_move(what)
	if by is String:
		return by
	world.set_drawn(builder.drag_places(by))
	_drawn = []
	if not builder.drag_fits(by):
		flash.call(builder.refused_by)
		return "no room there"
	return ""


func typed_apply(what: Dictionary) -> bool:
	if drag.is_empty():
		return false
	var by: Variant = _typed_move(what)
	if by is String or not builder.drag_fits(by):
		return false
	var was: Dictionary = drag
	drag = {}
	world.set_drawn({})
	var words: String = _words(was, str(what["words"]))
	if builder.drag_end(by, words) == 0:
		return false
	if _picked != null:
		_picked = (by as Transform3D) * (_picked as Vector3)
	if not bool(was.get("mouse_up", false)):
		_eat_release = true
	_drawn = []
	edited.call()
	say.call(words)
	return true


## Esc in the field: the drag as it was before the number, or, straight
## after one, the drag let go as it was.
func typed_cancel() -> void:
	if drag.is_empty():
		return
	drag["typing"] = false
	if bool(drag.get("mouse_up", false)):
		drag["value"] = drag.get("again", Vector2.ZERO if drag["kind"] == "pane" else 0.0)
		drag["want"] = drag["value"]
		_let_go()
		return
	_show(drag["value"])
	_drawn = []
