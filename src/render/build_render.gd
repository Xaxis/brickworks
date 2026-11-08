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
## stands. The camera turns slowly round, ending on the view chosen, and
## follows the build (video2, APP_UX6 gap 12): each step is framed on what
## is built by its end, so the first step's few parts fill the picture
## rather than sitting small in a corner of the finished model's frame, and
## as each step begins the camera draws back, eased, while its parts come
## down, until the whole model fills it as the picture does. A session
## watching the six frames of a build said "the single plate and the pods
## look small, up in the top left corner"; a person saw the same.
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
## The shortest the camera takes to draw back to a step, in seconds: a
## model of many small steps is followed smoothly, not a jolt a step.
const EASING := 0.15
## How long the camera takes to settle into the view chosen once the model
## is finished, in seconds.
const SETTLING := 1.0
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
## Each part's box where it stands, and what each frame is framed on
## (framed_at), as its least and greatest corners, and how far the view
## chosen has its own framing back (x, 0 to 1).
var _boxes: Array[AABB] = []
var _framed_low := PackedVector3Array()
var _framed_high := PackedVector3Array()
var _settled := PackedVector3Array()


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
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			out._boxes.append(brick.transform * info.bounds if info != null
				else AABB(brick.transform.origin, Vector3.ZERO))
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
	_frame_steps(each, count, fps)


## What each frame is framed on: from the frame a step begins, every part
## of it and of the steps before it, where they stand; the camera eased
## from one to the next over about the time a part takes to come down
## (twice a running mean, so it starts and stops gently), and so never
## framed on less than the parts that are down. Every frame of the last
## step and the finished model is framed on the whole of it. While it goes
## up the camera is fitted close; once it is finished it settles, over
## about a second, into the view chosen as a picture frames it (As I see
## it is the person's own framing, which a first step would sit small in).
func _frame_steps(each: float, count: int, fps: int) -> void:
	var lows := PackedVector3Array()
	var highs := PackedVector3Array()
	var low := Vector3.INF
	var high := -Vector3.INF
	var from: int = 0
	for step: int in count:
		for k: int in range(from, int(_step_ends[step])):
			low = low.min(_boxes[k].position)
			high = high.max(_boxes[k].end)
		from = int(_step_ends[step])
		lows.append(low)
		highs.append(high)
	var low_at := PackedVector3Array()
	var high_at := PackedVector3Array()
	var finished_at := PackedVector3Array()
	low_at.resize(frames)
	high_at.resize(frames)
	finished_at.resize(frames)
	for n: int in frames:
		var at: int = floori(float(n) / maxf(each, 0.001))
		var step: int = clampi(at, 0, maxi(count - 1, 0))
		low_at[n] = lows[step] if count > 0 else Vector3.ZERO
		high_at[n] = highs[step] if count > 0 else Vector3.ZERO
		finished_at[n] = Vector3.ONE if at >= count else Vector3.ZERO
	var width: int = maxi(roundi(_landing * 0.5) + 1, roundi(EASING * float(fps)) + 1)
	_framed_low = _eased(_eased(low_at, width), width)
	_framed_high = _eased(_eased(high_at, width), width)
	var settling: int = maxi(width, roundi(SETTLING * 0.5 * float(fps)))
	_settled = _eased(_eased(finished_at, settling), settling)


## The mean of the last [param width] of [param values] at each, the first
## standing in for those before it. Where they are all the same it is that,
## exactly: the last frames are the whole model's own box.
static func _eased(values: PackedVector3Array, width: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(values.size())
	for n: int in values.size():
		var first: int = maxi(n - width + 1, 0)
		# What is framed only grows, so the first and the last the same
		# are all the same.
		if values[first] == values[n]:
			out[n] = values[n]
			continue
		var sum := Vector3.ZERO
		for k: int in range(n - width + 1, n + 1):
			sum += values[maxi(k, 0)]
		out[n] = sum / float(width)
	return out


## What frame [param n] is framed on, where it stands in the model, and
## how far it has settled into the view chosen, 0 to 1
## (StudioRender.animate's framed_at): [AABB, float].
func framed_at(n: int) -> Array:
	if n < 0 or n >= _framed_low.size():
		return [AABB(), 1.0]
	return [AABB(_framed_low[n], _framed_high[n] - _framed_low[n]), _settled[n].x]


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
			await output.add_frame(n, image), PackedVector3Array(), framed_at)
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
