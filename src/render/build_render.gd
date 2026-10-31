## The model built up, as a video: File, Render's Building, and a session's
## render_model kind "build". Studio renders a building video; a model page
## that builds itself is what people share (APP_UX3, gap 5).
##
## The order is the timeline's: the steps Timeline works out (the author's
## steps where the model has them, else the build order, Instructions.plan),
## each step's parts in turn. Each step has the same share of the time, and
## its parts come down into place from above, one after another, all of them
## down before the next step begins; then the finished model, the last part
## of the length. Every frame shows the first so many parts of that order
## and none after them, and the last frame is the whole model, where it
## stands. The camera turns slowly round the whole of it, ending on the view
## chosen, and is framed on the finished model throughout, so it stands
## still while the model goes up in it.
##
## Drawn by StudioRender.animate, as a motion is (MotionRender): a part not
## yet arrived is drawn at no size, a part coming down a little above its
## place. So the set, the light, the lens and the grades are a picture's,
## and the frames are kept as a turntable's are (RenderOutput): an animated
## WebP, and on the desktop the frames and an MP4 where ffmpeg is installed.
class_name BuildRender
extends RefCounted

## The lengths offered, in seconds.
const LENGTHS: Array[int] = [10, 20, 30, 60]
const SHORTEST := 10
const LONGEST := 60
## The share of the length the finished model is shown at the end.
const FINISHED := 0.2
## How fast the camera turns, in degrees a second: slowly.
const TURNING := 4.5
## The longest a part takes to come down into place, in seconds.
const LANDING := 0.5
## How far above its place a part begins coming down: a share of the
## model's height, and at least two bricks (LDU).
const DROP_SHARE := 0.25
const DROP_LEAST := 48.0
## A part not yet arrived: drawn at no size, so it draws nothing and
## casts no shadow.
const AWAY := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

## The parts in the order they arrive, by their id in the world.
var order := PackedInt64Array()
## How many steps they came in, as the timeline numbers them, and where
## each step ends in [member order], as a count of parts.
var steps: int = 0
var _step_ends := PackedInt64Array()
## Each frame: how many of [member order] are on show, arriving or down.
var shown := PackedInt32Array()
## The frames, and how far round the camera has turned at each.
var frames: int = 0
var _turns: float = 0.0
## Each part: the frame it begins coming down at, and how many frames that takes.
var _starts := PackedFloat32Array()
var _landing: float = 0.0
var _drop: float = 0.0
var _homes: Array[Transform3D] = []


## The parts of [param world] (less [param scenery] and what is hidden) in
## the timeline's order, worked out a slice at a time with [param job]
## saying so and able to cancel it. Null when cancelled or nothing is there.
static func planned(world: BrickWorld, library: PartLibrary, scenery: Dictionary,
		job: Working.Job) -> BuildRender:
	var plan: Array[Instructions.Step] = await Instructions.plan_paced(world, library, scenery, {},
		job, AuthorSteps.any(world, scenery))
	if job.cancelled or plan.is_empty():
		return null
	var out := BuildRender.new()
	var seen: Dictionary = {}
	var ends := PackedInt64Array()
	for step: Instructions.Step in plan:
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if seen.has(brick_id) or brick == null or brick.hidden or scenery.has(brick_id):
				continue
			seen[brick_id] = true
			out.order.append(brick_id)
			out._homes.append(brick.transform)
		if not out.order.is_empty() and (ends.is_empty() or ends[ends.size() - 1] < out.order.size()):
			ends.append(out.order.size())
	out.steps = int(Instructions.count(plan)["steps"])
	out._step_ends = ends
	return out if not out.order.is_empty() else null


## The frames of [param seconds] at [param fps]: when each part arrives,
## and how far [param height] (the model's, in LDU) a part comes down.
func lay_out(seconds: float, fps: int, height: float) -> void:
	frames = maxi(roundi(clampf(seconds, SHORTEST, LONGEST) * float(fps)), 2)
	_turns = seconds * TURNING / 360.0
	_drop = maxf(height * DROP_SHARE, DROP_LEAST)
	var building: float = float(frames) - maxf(roundf(float(frames) * FINISHED), 1.0)
	var count: int = _step_ends.size()
	var each: float = building / float(maxi(count, 1))
	# Half a step's time for its parts to begin coming down, one after
	# another, and the other half at most for the last to be down.
	_landing = minf(LANDING * float(fps), each * 0.5)
	_starts.resize(order.size())
	var from: int = 0
	for step: int in count:
		var to: int = int(_step_ends[step])
		var parts: int = to - from
		for k: int in parts:
			_starts[from + k] = each * float(step) + each * 0.5 * float(k) / float(parts)
		from = to
	shown.resize(frames)
	var at: int = 0
	for n: int in frames:
		while at < order.size() and _starts[at] <= float(n):
			at += 1
		shown[n] = at


## Frame [param n]'s parts that stand otherwise than in the frame before it
## (in frame 0, every part): brick id -> where it is drawn. StudioRender
## moves only those, so a frame costs the parts coming down, not the model.
func poses_at(n: int) -> Dictionary:
	var out: Dictionary = {}
	# The parts arrive in order, so those down before the frame before
	# this one are the first so many, and stand as they stood.
	var from: int = 0 if n == 0 else _starts.bsearch(float(n - 1) - _landing)
	for k: int in range(from, order.size()):
		if _starts[k] > float(n):
			# Not yet: only frame 0 needs to send it away.
			if n > 0:
				break
			out[order[k]] = Transform3D(AWAY, _homes[k].origin)
			continue
		out[order[k]] = _at(k, n)
	return out


## Where part [param k] is drawn in frame [param n], once it has begun to
## come down: above its place, easing in, then at it.
func _at(k: int, n: int) -> Transform3D:
	var home: Transform3D = _homes[k]
	if _landing <= 0.0:
		return home
	var t: float = clampf((float(n) - _starts[k]) / _landing, 0.0, 1.0)
	var left: float = pow(1.0 - t, 3.0)
	return Transform3D(home.basis, home.origin + Vector3(0.0, _drop * left, 0.0))


## How far round the camera is at frame [param n], in turns: it ends on the
## view chosen.
func turn_at(n: int) -> float:
	return -_turns * (1.0 - float(n) / float(maxi(frames - 1, 1)))


## Its frames drawn by [param renderer] as [param chosen] says (its fps the
## frames'), handed to [param output], begun by the caller: [param each] gets
## each frame's number and picture as it is drawn. Returns how many were
## drawn, all of them unless cancelled; the caller finishes [param output].
func draw(renderer: StudioRender, world: BrickWorld, chosen: RenderSettings,
		output: RenderOutput, each: Callable) -> int:
	var done: int = await renderer.animate(world, chosen, frames, poses_at, turn_at, AABB(),
		func(n: int, image: Image) -> void:
			await each.call(n, image)
			await output.add_frame(n, image))
	await output.settle()
	return done


## How tall the finished model is, in LDU: how far a part comes down is a
## share of it.
static func height_of(world: BrickWorld, library: PartLibrary, ids: PackedInt64Array) -> float:
	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var each: AABB = brick.transform * info.bounds
		box = each if first else box.merge(each)
		first = false
	return box.size.y


## What it comes to, in words: "61 parts in 12 steps, 20 s".
func said(fps: int) -> String:
	return "%s part%s in %s step%s, %d s" % [Working.comma(order.size()), "" if order.size() == 1 else "s",
		Working.comma(steps), "" if steps == 1 else "s", roundi(float(frames) / float(maxi(fps, 1)))]
