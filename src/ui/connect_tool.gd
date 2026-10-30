## Connect: a point on the part, then the point it goes on (docs/APP_UX.md,
## B2), as Studio's Connect tool, Mecabricks' S and Blender's B do it. The
## part in hand went onto whichever of its ends the pointer found first,
## and T stepped through the rest one at a time: a 1 x 16 Technic brick on
## two pins has 30 ways on, and 8841-1's column was typed in Properties
## after more than a hundred presses in every run of the CAD task
## (docs/CADTASK.md, gap 3). Here a click says which hole.
##
## The stages, and what moves between them:
##
##   off    --N or the tool, a part in hand with its ghost showing-->  point
##   off    --the tool with nothing in hand-->  part
##   part   --a click on a part of the model-->  point, the part taken off
##             into hand where it stands
##   point  --a click on one of its points-->  aim: the ghost follows the
##             pointer onto the joints that point goes on, and only those
##   aim    --a click where it has room-->  put down, one step to undo (with
##             its taking off, for a part off the model). A part from the
##             bin stays in hand by the same point; Connect then waits for
##             the next part of the model (part)
##   aim    --N-->  point, to pick another point
##   any    --Esc, another tool, another part in hand-->  off; a part taken
##             off the model goes back where it was
##
## The points are the ends JointSnap reads: pins, axles, pin and axle holes,
## bars, clips, a tyre's inside, a rim and a hinge's halves. Studs go on by
## the pointer, the stud grid's, as they always have.
class_name ConnectTool
extends Node

## How near the pointer has to be to a point to pick it, in the window's
## pixels at the window's own scale.
const PICK := 18.0

var builder: Builder
var world: BrickWorld
var library: PartLibrary
var camera: Camera3D
## Says a line in the bar along the top.
var say: Callable = func(_line: String) -> void: pass
## The model changed by somebody's own hand.
var edited: Callable = func() -> void: pass
## Aim the ghost where the pointer is, after what is held has changed.
var aim_again: Callable = func() -> void: pass

## "", "part", "point" or "aim".
var stage: String = ""
## The part's points in its own frame (JointSnap.End), as they are offered.
var points: Array = []
## The one picked, by its place in [member points]; -1 for none.
var chosen: int = -1
## The one under the pointer while points are offered; -1 for none.
var lit: int = -1
## For a part Connect took off the model: how deep the history was before,
## so its putting down and its taking off are one step; -1 for a part from
## the bin.
var _depth: int = -1
var _taken: String = ""
## The part and pose the points are drawn for.
var _part: String = ""
var _at := Transform3D.IDENTITY
var _eat_release: bool = false


func _ready() -> void:
	builder.placed.connect(_on_placed)


func is_on() -> bool:
	return not stage.is_empty()


## Whether a part is in hand for Connect: its points offered, or aimed by one.
func holds() -> bool:
	return stage == "point" or stage == "aim"


## Whether the part held is the hand's own (from the bin, Q, the eyedropper),
## not one Connect took off the model.
func from_hand() -> bool:
	return _depth < 0


## Connect begun, from the toolbar, its menu row or N: on the part in hand
## where its ghost stands, or, with nothing in hand, on the next part
## clicked. Again while aiming, the points offered again to pick another.
## [param placing] says whether a part is in hand (the Place tool's), and
## [param at] where to hold it when its ghost stands nowhere.
func begin(placing: bool, at: Variant = null) -> bool:
	if builder.is_carrying() or builder.is_holding_figure():
		say.call("Connect moves one part: put down what is in hand first")
		return false
	if placing:
		if not builder.hold_still(at if not builder.has_preview() else null):
			say.call(Keymap.filled("Connect: aim the part at the model first, then {mode_connect}"))
			return false
		if not _offer():
			builder.follow_by(null)
			stage = ""
			return false
		return true
	_leave_hand()
	stage = "part"
	say.call("Connect: click the part to move by one of its points — Esc stops")
	return true


## A click on a part of the model while waiting for one: taken off into hand
## where it stands, its points offered. True when it was.
func take(brick_id: int) -> bool:
	if stage != "part":
		return false
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or builder.is_locked(brick_id):
		return false
	var at: Transform3D = brick.transform
	var depth: int = builder.history_depth()
	if not builder.lift_brick(brick_id):
		return false
	_depth = depth
	_taken = _named(brick.part_id)
	edited.call()
	if not builder.hold_still(at) or not _offer():
		_put_back()
		stage = "part"
		return false
	return true


## Let go: a part taken off the model goes back where it was, a part from
## the bin stays in hand to be put as ever.
func end() -> void:
	if stage.is_empty():
		return
	_put_back()
	_leave_hand()
	stage = ""
	_drop_marks()
	aim_again.call()


## The points of the part in hand, drawn where it is held still. False for
## a part with none, which goes on by its studs.
func _offer() -> bool:
	_part = builder.held_part
	_at = builder.ghost_transform()
	points = JointSnap.ends_for(library, _part)
	chosen = -1
	lit = -1
	if points.is_empty():
		say.call("the %s has no pins, holes, axles, bars or clips: it goes on by its studs"
			% _named(_part))
		_drop_marks()
		return false
	stage = "point"
	_draw_marks()
	say.call("Connect: click the point on the %s it goes on by — %d points, Esc stops" % [
		_named(_part), points.size()])
	return true


## A point of the part picked: the ghost follows the pointer by it alone.
func pick(index: int) -> void:
	if stage != "point" or index < 0 or index >= points.size():
		return
	chosen = index
	stage = "aim"
	builder.follow_by(points[index])
	_drop_marks()
	var end_at: JointSnap.End = points[index]
	say.call(Keymap.filled("Connect: the %s picked — click the %s it goes on, {rotate_held|turns it about the joint}") % [
		JointSnap.SAID.get(end_at.kind, end_at.kind), _goes_on(end_at)])
	aim_again.call()


## The point under [param at] on the screen, nearest the pointer and then
## nearest the eye, in the view [param at] is over (the main one, or the
## second beside it: View, Split); -1 for none within [constant PICK].
func point_at(at: Vector2) -> int:
	if stage != "point" or camera == null:
		return -1
	var cad: CadCamera = camera as CadCamera
	var view: int = cad.view_at(at) if cad != null else CadCamera.MAIN
	var eye: Camera3D = cad.eye_of(view) if cad != null else camera
	var best: int = -1
	var best_off: float = PICK * _scale()
	var best_depth: float = INF
	for n: int in points.size():
		var middle: Vector3 = _middle(n)
		var shown: Variant = _shown_at(middle, view)
		if shown == null:
			continue
		var off: float = (shown as Vector2).distance_to(at)
		var depth: float = eye.global_position.distance_to(middle)
		if off < best_off - 2.0 or (off <= best_off + 2.0 and depth < best_depth):
			best = n
			best_off = minf(off, best_off)
			best_depth = depth
	return best


## Where point [param n] is in the world while it is offered.
func _middle(n: int) -> Vector3:
	return (points[n] as JointSnap.End).placed(_at, 0).middle()


## Where a point of the model is drawn in [param view], or null behind it.
func _shown_at(middle: Vector3, view: int) -> Variant:
	var cad: CadCamera = camera as CadCamera
	if cad != null:
		return null if cad.behind(middle, view) else cad.screen_of(middle, view)
	return null if camera.is_position_behind(middle) else camera.unproject_position(middle)


## The points on the page, and which is picked, for a probe and a browser
## flow to click as a person does: [{kind, x, y}] in the window's pixels,
## as [param view] (the main one, or CadCamera.SECOND) draws them.
func screen_points(view: int = CadCamera.MAIN) -> Array:
	var out: Array = []
	if stage != "point" or camera == null:
		return out
	for n: int in points.size():
		var shown: Variant = _shown_at(_middle(n), view)
		if shown == null:
			continue
		var at: Vector2 = shown
		out.append({"index": n, "kind": (points[n] as JointSnap.End).kind,
			"x": snappedf(at.x, 0.1), "y": snappedf(at.y, 0.1)})
	return out


## What it is about now, for the page: the stage, the points offered, and
## the kind of the one picked.
func page_state(to_page: Transform2D = Transform2D.IDENTITY, per_css: float = 1.0) -> Dictionary:
	var shown: Array = []
	for point: Dictionary in screen_points():
		var at: Vector2 = to_page * Vector2(point["x"], point["y"]) / per_css
		shown.append({"index": point["index"], "kind": point["kind"], "x": roundi(at.x),
			"y": roundi(at.y)})
	return {"stage": stage, "points": shown,
		"chosen": (points[chosen] as JointSnap.End).kind if chosen >= 0 and chosen < points.size()
			else ""}


## The status bar's line while Connect is on.
func hint() -> String:
	match stage:
		"part":
			return "Connect: click the part to move by one of its points · Esc stops"
		"point":
			var over: String = ""
			if lit >= 0 and lit < points.size():
				over = " · this one is a %s" % JointSnap.SAID.get(
					(points[lit] as JointSnap.End).kind, "point")
			return "Connect: click the point on the part it goes on by%s · Esc stops" % over
		"aim":
			var end_at: JointSnap.End = points[chosen] if chosen >= 0 and chosen < points.size() \
				else null
			if end_at == null:
				return "Connect: click where it goes · Esc stops"
			if builder.is_on_joint():
				return Keymap.filled("Connect: by its %s on %s · click puts it there · {rotate_held|turns it about the joint} · {tip_held|the other way on} · {mode_connect|another point} · Esc stops") % [
					JointSnap.SAID.get(end_at.kind, end_at.kind), builder.joint_words()]
			return Keymap.filled("Connect: aim its %s at a %s · {mode_connect|picks another point} · Esc stops") % [
				JointSnap.SAID.get(end_at.kind, end_at.kind), _goes_on(end_at)]
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if stage != "point":
		return
	var moved: InputEventMouseMotion = event as InputEventMouseMotion
	if moved != null:
		var over: int = point_at(moved.position)
		if over != lit:
			lit = over
			_light()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# A press on a point and its release are Connect's: the release would
	# otherwise be a click that puts the part down. A press anywhere else is
	# the view's, to turn it and see a point round the back.
	if button.pressed:
		if point_at(button.position) >= 0:
			_eat_release = true
			get_viewport().set_input_as_handled()
		return
	if _eat_release:
		_eat_release = false
		get_viewport().set_input_as_handled()
		pick(point_at(button.position))


## The ghost put down. A part off the model: its taking off and its putting
## down are one step, and Connect waits for the next part. A part from the
## bin stays in hand by the same point, as the Place tool keeps one in hand.
func _on_placed(_brick_id: int, _part_id: String) -> void:
	if stage != "aim":
		return
	if _depth >= 0:
		builder.fold_since(_depth, "connected %s" % _taken)
		_depth = -1
		builder.follow_by(null)
		stage = "part"
		say.call("connected the %s — click the next part to move, Esc stops" % _taken)


## A part taken off the model and not put down: back where it was.
func _put_back() -> void:
	if _depth < 0:
		return
	var depth: int = _depth
	_depth = -1
	builder.connect_picking = false
	builder.unpin_hand()
	while builder.history_depth() > depth and builder.undo():
		pass
	edited.call()


## The hand as it was before Connect: by any of its ends, following the pointer.
func _leave_hand() -> void:
	builder.follow_by(null)
	points = []
	chosen = -1
	lit = -1


func _named(part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return Inventory._tidy(info.name) if info != null else part_id


## What a point goes on, in words: "pin or axle" for a hole.
static func _goes_on(end_at: JointSnap.End) -> String:
	var kinds: Array = JointSnap.TAKES.get(end_at.kind, [])
	return " or ".join(kinds.map(func(kind: String) -> String:
		return str(JointSnap.SAID.get(kind, kind))))


func _scale() -> float:
	var window: Window = get_window() if is_inside_tree() else null
	return window.content_scale_factor if window != null and window.content_scale_factor > 0.0 \
		else 1.0


# -- the points drawn ------------------------------------------------------------


## A ring for each hole and a dot for each pin, axle, bar and clip, drawn
## over the model at a size the screen keeps, so the ones inside the part
## and the ones on a part its own colour both show, as Studio draws its
## connectors in blue.
const DOT := 6.0
const EDGE := Color(0.05, 0.07, 0.12, 0.9)
const FILL := Color(0.30, 0.58, 1.0)
const LIT := Color(1.0, 0.85, 0.3)


func _draw_marks() -> void:
	if _overlays == null:
		# Over the model in each view, under the menus and dialogs.
		_overlays = ViewOverlays.new()
		_overlays.name = "ConnectPoints"
		_overlays.draw_in = _draw_points
		add_child(_overlays)
	_overlays.camera = camera as CadCamera
	_overlays.show_drawn(true)


func _light() -> void:
	if _overlays != null and _overlays.is_shown():
		_overlays.show_drawn(true)


func _drop_marks() -> void:
	if _overlays != null:
		_overlays.show_drawn(false)


## How many points are drawn now in [param view], for a probe.
func drawn(view: int = CadCamera.MAIN) -> int:
	return screen_points(view).size() if _overlays != null and _overlays.is_shown() else 0


func _process(_delta: float) -> void:
	# Drawn again as the view turns: a point round the back comes into sight.
	if stage == "point" and _overlays != null and _overlays.is_shown():
		_overlays.show_drawn(true)


## The points as [param view] shows them, drawn on [param canvas] in the
## window's units (ViewOverlays).
func _draw_points(canvas: Control, view: int) -> void:
	var scale: float = _scale()
	for point: Dictionary in screen_points(view):
		var at := Vector2(point["x"], point["y"])
		var lit_up: bool = int(point["index"]) == lit
		var r: float = DOT * scale * (1.4 if lit_up else 1.0)
		var colour: Color = LIT if lit_up else FILL
		var end_at: JointSnap.End = points[int(point["index"])]
		if end_at.is_hole() or end_at.is_wrap() or end_at.is_hinge():
			# A hole is a ring: what goes into it, round its middle.
			canvas.draw_arc(at, r, 0.0, TAU, 24, EDGE, 4.0 * scale, true)
			canvas.draw_arc(at, r, 0.0, TAU, 24, colour, 2.2 * scale, true)
		else:
			canvas.draw_circle(at, r + 1.5 * scale, EDGE)
			canvas.draw_circle(at, r, colour)


var _overlays: ViewOverlays
