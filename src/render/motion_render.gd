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
## each backwards with [param reverse], and the model left as it was. Each
## begins where the one before it ended: kept while the next is played,
## then all of it taken back, and the redo the person had is theirs again.
static func frames_of(player: MotionPlayer, order: Array, reverse: bool, fps: int) -> MotionRender:
	var out := MotionRender.new()
	var builder: Builder = player.builder
	var depth: int = builder.history_depth()
	var redo: Array = builder.steps_now()[1]
	var many: bool = order.size() > 1
	for motion: Motions.Motion in order:
		var one: MotionPlayer.Played = player.play(motion, reverse, fps, many)
		out.played.append(one)
		out.poses.append_array(one.frames)
		out.lines.append("%s: %s." % [Motions.quoted(motion.name), player.said(one)])
	if builder.history_depth() > depth:
		builder.take_back_to(depth, redo)
		if player.grabbing != null:
			player.grabbing.edited.call()
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
