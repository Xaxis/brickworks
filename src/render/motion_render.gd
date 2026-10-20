## A model's motions drawn as an animation and kept (docs/MOTIONS.md,
## "Render"): the one way File, Render's Animation, the Motions panel's
## Render animation and a session's render_motion draw them, so the same
## settings give the same frames whichever asks.
##
## The frames are the motions played through Grab (MotionPlayer), each
## from where the one before it ended; the camera is as the view is ("as I
## see it") or fitted to the points the moving parts pass through
## ("framed on what moves", RenderSettings.on_what_moves); the files are
## named after the model and the motion (RenderOutput.begin_animation).
class_name MotionRender
extends RefCounted

## Every motion of the model, each after the one it follows (Play all):
## what the dialog offers, and the files' name for it.
const ALL := "All, in order"
## The most corners a frame is fitted to.
const MOST_POINTS := 4096

## One a frame: brick id -> Transform3D of every part that moves.
var poses: Array = []
## What each motion did, in its own words.
var lines := PackedStringArray()
## Each motion as it played (MotionPlayer.Played), in order.
var played: Array = []


## [param order] (Motions.Motion) played one after another at [param fps],
## each backwards with [param reverse] (a sequence's motions in reverse
## order), and the model left as it was. Each begins where the one before
## it ended: kept while the next is played, then all of it taken back, and
## the redo the person had is theirs again.
static func frames_of(player: MotionPlayer, order: Array, reverse: bool, fps: int) -> MotionRender:
	var out := MotionRender.new()
	var builder: Builder = player.builder
	var depth: int = builder.history_depth()
	var redo: Array = builder.steps_now()[1]
	var missing: Array = []
	order = player.motions().flat(order, reverse, missing)
	for words: String in missing:
		out.lines.append("%s." % words)
	var many: bool = order.size() > 1
	var each: Array = []
	for motion: Motions.Motion in order:
		var one: MotionPlayer.Played = player.play(motion, reverse, fps, many)
		out.played.append(one)
		each.append(one.frames)
		out.lines.append("%s: %s." % [Motions.quoted(motion.name), player.said(one)])
	for frames: Array in whole_frames(each):
		out.poses.append_array(frames)
	if builder.history_depth() > depth:
		builder.take_back_to(depth, redo)
		if player.grabbing != null:
			player.grabbing.edited.call()
	return out


## A sequence's frames, each motion's in [param each], with every part any
## of them moves in every frame, where it stands at that moment. A frame
## holds what its own motion moves, and is drawn on the model as it stands
## when drawn: played and kept, the observatory's telescope stood slid out
## through its shut dome in the frames that opened the dome; rendered, with
## the model put back, the dome stood shut again while the telescope slid
## out. So a frame takes what earlier motions moved from where they ended,
## and what later ones move from where they began.
static func whole_frames(each: Array) -> Array:
	var out: Array = []
	var before: Dictionary = {}
	for frames: Array in each:
		var whole: Array = []
		for frame: Dictionary in frames:
			var one: Dictionary = before.duplicate()
			one.merge(frame, true)
			whole.append(one)
		if not frames.is_empty():
			before.merge(frames.back(), true)
		out.append(whole)
	var after: Dictionary = {}
	for k: int in range(out.size() - 1, -1, -1):
		for frame: Dictionary in out[k]:
			frame.merge(after)
		if not (each[k] as Array).is_empty():
			after.merge(each[k][0], true)
	return out


## [param poses] drawn by [param renderer] as [param chosen] says (its fps
## the frames'), the model turned [param turn_at] (frame -> turns) round,
## and handed to [param output], begun by the caller: [param shown] gets
## each frame's number and picture as it is drawn. Returns how many were
## drawn, all of them unless cancelled; the caller finishes [param output].
static func draw(renderer: StudioRender, world: BrickWorld, chosen: RenderSettings, poses: Array,
		turn_at: Callable, output: RenderOutput, shown: Callable) -> int:
	var library: PartLibrary = renderer.library if renderer.library != null else world.library
	var poser := Poser.new()
	poser.world = world
	poser.library = library
	var done: int = await renderer.animate(world, chosen, poses.size(),
		func(n: int) -> Dictionary: return poses[n],
		turn_at, poser.reach(poses),
		func(n: int, image: Image) -> void:
			await shown.call(n, image)
			await output.add_frame(n, image),
		swept(world, library, poses))
	await output.settle()
	return done


## The corners of every part that moves, in every frame (every few, past
## [constant MOST_POINTS], and the last): what a camera framed on what
## moves is fitted to.
static func swept(world: BrickWorld, library: PartLibrary, poses: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if poses.is_empty():
		return out
	var each: int = ceili(float(poses.size() * (poses[0] as Dictionary).size() * 8) / float(MOST_POINTS))
	for n: int in poses.size():
		if n % maxi(each, 1) != 0 and n != poses.size() - 1:
			continue
		var placed: Dictionary = poses[n]
		for brick_id: Variant in placed:
			var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
			if info == null:
				continue
			var at: Transform3D = placed[brick_id]
			for corner: int in 8:
				out.append(at * info.bounds.get_endpoint(corner))
	return out


## The views a motion's picture may be taken from (StudioRender.VIEWS), the
## front corner first: another is chosen when it sees [constant BETTER_BY]
## more of what moves.
const VIEWS: Array = ["hero", "front", "side", "back", "low", "top"]
const BETTER_BY := 0.1
## The most moving parts looked for, the furthest moving first.
const MOST_LOOKED := 24
## The side of a square a view files what stands in the way in, LDU.
const CELL := 40.0


## How much of what [param poses] move each view sees, view -> 0 to 1:
## each moving part's travel as the view sees it (across the picture, not
## towards the camera), at the moments nothing stands between it and the
## camera, over all their travel. A session's observatory opened its back
## wall's panels behind the dome, and the front corner saw none of it.
## Pure geometry on the parts' boxes: it draws nothing.
static func seen_from(world: BrickWorld, library: PartLibrary, poses: Array) -> Dictionary:
	var out: Dictionary = {}
	for view: String in VIEWS:
		out[view] = 0.0
	if poses.is_empty():
		return out
	var last: int = poses.size() - 1
	var moments: Array = [0]
	for n: int in [floori(last / 2.0), last]:
		if not moments.has(n):
			moments.append(n)
	var moving: Dictionary = {}
	for n: int in moments:
		for key: Variant in poses[n]:
			moving[int(key)] = true
	# Each part that moves: its corners' travel from the first moment to
	# the one it is furthest from it.
	var looked: Array = []   ## [how far, id, bounds, [travel of each corner], where it stands]
	var total: float = 0.0
	for id: int in moving:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var from: Transform3D = (poses[0] as Dictionary).get(id, brick.transform)
		var most: float = 0.0
		var travel: Array = []
		for n: int in moments:
			var at: Transform3D = (poses[n] as Dictionary).get(id, brick.transform)
			var each: Array = []
			var far: float = 0.0
			for corner: int in 8:
				var point: Vector3 = info.bounds.get_endpoint(corner)
				each.append(at * point - from * point)
				far += (each.back() as Vector3).length() / 8.0
			if far > most:
				most = far
				travel = each
		if most < 2.0:
			continue
		looked.append([most, id, info.bounds, travel, brick.transform])
	looked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	looked = looked.slice(0, MOST_LOOKED)
	for one: Array in looked:
		total += float(one[0])
	if total <= 0.0:
		return out
	var standing: Array = []   ## what does not move: [transform, bounds]
	for brick: BrickWorld.Brick in world.bricks():
		if moving.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null:
			standing.append([brick.transform, info.bounds])
	for view: String in VIEWS:
		var toward: Vector3 = Vector3(StudioRender.VIEWS[view][1]).normalized()
		var across: Vector3 = (Vector3.UP if absf(toward.y) < 0.9 else Vector3.RIGHT).cross(toward).normalized()
		var up: Vector3 = toward.cross(across)
		var still: Dictionary = _filed(standing, toward, across, up)
		var seen: float = 0.0
		for n: int in moments:
			var now: Array = []
			for id: int in moving:
				var brick: BrickWorld.Brick = world.get_brick(id)
				var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
				if info != null:
					now.append([(poses[n] as Dictionary).get(id, brick.transform), info.bounds, id])
			var stirring: Dictionary = _filed(now, toward, across, up)
			for one: Array in looked:
				var at: Transform3D = (poses[n] as Dictionary).get(int(one[1]), one[4])
				var bounds: AABB = one[2]
				var clear: int = 0
				var points: Array = [bounds.get_center()]
				for corner: int in 8:
					points.append(bounds.get_center().lerp(bounds.get_endpoint(corner), 0.65))
				for point: Vector3 in points:
					var from: Vector3 = at * point
					if not _blocked(still, from, toward, across, up, -1) \
							and not _blocked(stirring, from, toward, across, up, int(one[1])):
						clear += 1
				var flat: float = 0.0
				for moved: Vector3 in one[3]:
					flat += (moved - toward * moved.dot(toward)).length() / 8.0
				seen += flat * float(clear) / float(points.size()) / float(moments.size())
		out[view] = clampf(seen / total, 0.0, 1.0)
	return out


## The view [param seen] (seen_from) says sees most: the front corner
## unless another sees [constant BETTER_BY] more.
static func best_view(seen: Dictionary) -> String:
	var best: String = "hero"
	for view: String in VIEWS:
		if float(seen.get(view, 0.0)) > float(seen.get(best, 0.0)) + (BETTER_BY if best == "hero" else 0.0):
			best = view
	return best


## [param parts] ([transform, bounds, id]) filed by the squares of the
## picture plane their boxes cover, seen along [param toward]: square ->
## [[inverse transform, bounds, nearest and furthest along toward, the
## square's rect, id]].
static func _filed(parts: Array, toward: Vector3, across: Vector3, up: Vector3) -> Dictionary:
	var out: Dictionary = {}
	for part: Array in parts:
		var at: Transform3D = part[0]
		var bounds: AABB = part[1]
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for corner: int in 8:
			var point: Vector3 = at * bounds.get_endpoint(corner)
			var p := Vector3(point.dot(across), point.dot(up), point.dot(toward))
			low = low.min(p)
			high = high.max(p)
		var entry: Array = [at.affine_inverse(), bounds, high.z, Rect2(low.x, low.y, high.x - low.x,
			high.y - low.y), int(part[2]) if part.size() > 2 else -1]
		for i: int in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
			for j: int in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
				var key := Vector2i(i, j)
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append(entry)
	return out


## Whether something filed in [param filed] stands between [param from]
## and a camera far off along [param toward]; [param own] is not.
static func _blocked(filed: Dictionary, from: Vector3, toward: Vector3, across: Vector3, up: Vector3,
		own: int) -> bool:
	var flat := Vector2(from.dot(across), from.dot(up))
	var depth: float = from.dot(toward)
	for entry: Array in filed.get(Vector2i(floori(flat.x / CELL), floori(flat.y / CELL)), []):
		if int(entry[4]) == own and own >= 0:
			continue
		if float(entry[2]) <= depth + 0.5 or not (entry[3] as Rect2).has_point(flat):
			continue
		var inverse: Transform3D = entry[0]
		if (entry[1] as AABB).intersects_ray(inverse * from, inverse.basis * toward) != null:
			return true
	return false
