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
const MOST_LOOKED := 16


## How much of what [param poses] move each view sees, view -> 0 to 1:
## each moving part's travel as the view sees it (across the picture, not
## towards the camera), at the moments nothing that stands still is
## between it and the camera, over all their travel. A session's
## observatory opened its back wall's panels behind the dome, and the
## front corner saw none of it. Looked along the lines from a few points
## of each part to a camera far off, through [param lattice]'s cells, the
## parts as they stand; what moves is passed through, and so is what a
## moving part stands in where it begins (a door's frame, whose opening
## the lattice fills: through it a door is seen). Draws nothing.
static func seen_from(world: BrickWorld, library: PartLibrary, lattice: BrickLattice, poses: Array) -> Dictionary:
	var out: Dictionary = {}
	for view: String in VIEWS:
		out[view] = 0.0
	if poses.is_empty() or lattice == null:
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
		if most >= 2.0:
			looked.append([most, id, info.bounds, travel, brick.transform])
	looked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	looked = looked.slice(0, MOST_LOOKED)
	for one: Array in looked:
		total += float(one[0])
	if total <= 0.0:
		return out
	var room := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var box: AABB = brick.transform * info.bounds
		room = box if first else room.merge(box)
		first = false
	room = room.grow(BrickLattice.CELL * 2.0)
	for view: String in VIEWS:
		var toward: Vector3 = Vector3(StudioRender.VIEWS[view][1]).normalized()
		var seen: float = 0.0
		for one: Array in looked:
			var bounds: AABB = one[2]
			var flat: float = 0.0
			for moved: Vector3 in one[3]:
				flat += (moved - toward * moved.dot(toward)).length() / 8.0
			if flat <= 0.0:
				continue
			var points: Array = [bounds.get_center()]
			for corner: int in [0, 3, 5, 6]:
				points.append(bounds.get_center().lerp(bounds.get_endpoint(corner), 0.65))
			var nest: Dictionary = {}
			var began: Transform3D = (poses[0] as Dictionary).get(int(one[1]), one[4])
			for point: Vector3 in points:
				nest[lattice.brick_at(BrickLattice.to_cell(began * point))] = true
			var clear: int = 0
			for n: int in moments:
				var at: Transform3D = (poses[n] as Dictionary).get(int(one[1]), one[4])
				for point: Vector3 in points:
					if _clear(lattice, at * point, toward, moving, nest, room):
						clear += 1
			seen += flat * float(clear) / float(points.size() * moments.size())
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


## Whether the line from [param from] along [param toward] leaves [param
## room] without meeting a cell of a part in neither [param passed] nor
## [param nest]: the lattice's march (BrickLattice._march).
static func _clear(lattice: BrickLattice, from: Vector3, toward: Vector3, passed: Dictionary, nest: Dictionary,
		room: AABB) -> bool:
	var span: Vector2 = BrickLattice._through(room, from, toward)
	if span.x > span.y or span.y < 0.0:
		return true
	var cell: Vector3i = lattice.to_cell(from)
	var step := Vector3i(1 if toward.x > 0.0 else -1, 1 if toward.y > 0.0 else -1, 1 if toward.z > 0.0 else -1)
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis: int in 3:
		if absf(toward[axis]) < 1e-9:
			continue
		var boundary: float = (cell[axis] + (0.5 if step[axis] > 0 else -0.5)) * BrickLattice.CELL
		t_max[axis] = (boundary - from[axis]) / toward[axis]
		t_delta[axis] = BrickLattice.CELL / absf(toward[axis])
	var travelled: float = 0.0
	while travelled <= span.y:
		var owner: int = lattice.brick_at(cell)
		if owner != 0 and not passed.has(owner) and not nest.has(owner):
			return false
		if t_max.x < t_max.y and t_max.x < t_max.z:
			cell.x += step.x
			travelled = t_max.x
			t_max.x += t_delta.x
		elif t_max.y < t_max.z:
			cell.y += step.y
			travelled = t_max.y
			t_max.y += t_delta.y
		else:
			cell.z += step.z
			travelled = t_max.z
			t_max.z += t_delta.z
	return true
