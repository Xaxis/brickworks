## Train tracks joined end to end, as LeoCAD and StudWorx join them.
##
## A track in hand goes onto a free end of a track down when the pointer is
## within [constant REACH_PX] of it: the end of the part in hand that joins
## it laid on it, face to face, so a curve after a straight is one drag and
## not a turn and a nudge by eye. R puts the next of its ends to the joint
## (StudWorx's Rotate Train Track): a curve's other end, which turns it the
## other way. Rails that meet on a sleeper (12V, 4.5V) get the sleeper with
## the track, in the same undo.
##
## Where each end is comes from the parts' own geometry, measured by
## tools/track_ends.py into assets/ldraw/track_ends.json: the face the next
## track's face meets, its place and the way it faces, and the joint's kind
## by what was measured, so a 9V track and a 6 wide one join. Nothing here
## knows a part number.
class_name TrackSnap
extends RefCounted

const TABLE := "res://assets/ldraw/track_ends.json"
## A free end this near the pointer, in the view's pixels, takes the track
## in hand (LeoCAD's 12).
const REACH_PX := 12.0
## Two ends meet when this near, LDU, and facing each other to within
## [constant FACING].
const MEET := 0.5
const FACING := -0.99999
## An end is aimed at by the middle of its face, this far up from its foot:
## the half of a 9V track's 24.
const FACE_MIDDLE := 12.0
## A connector's kind for Attach, outside every Exact kind.
const KIND := -40


## One end of a track: where, which way out of the track, and its joint.
class End extends RefCounted:
	var at: Vector3
	var out: Vector3
	var up: Vector3 = Vector3.UP
	var kind: String = ""
	## A rails joint's: a sleeper of its own under it.
	var sleeper: bool = false
	## Its place among its part's ends: track[index] over MCP.
	var index: int = 0
	## The brick it is an end of, once placed; 0 in a part's own frame.
	var brick: int = 0

	## This end of a part standing at [param where].
	func placed(where: Transform3D, brick_id: int) -> End:
		var end := End.new()
		end.at = where * at
		end.out = (where.basis * out).normalized()
		end.up = (where.basis * up).normalized()
		end.kind = kind
		end.sleeper = sleeper
		end.index = index
		end.brick = brick_id
		return end

	## Its frame: x out of the track, y up, z across (x cross y).
	func frame() -> Transform3D:
		return Transform3D(Basis(out, up, out.cross(up)).orthonormalized(), at)

	## Whether it and [param other] meet: one place, facing each other.
	func meets(other: End) -> bool:
		return other.kind == kind and at.distance_to(other.at) <= MEET \
			and out.dot(other.out) <= FACING and up.dot(other.up) >= 0.999


## The table, read as the class loads and never put again (a worker reads
## a model's parts too: memory gdscript-static-tables-threads).
static var _table: Dictionary = _read_table()
## Part -> its ends in its own frame, made from the table once.
static var _ends: Dictionary = _ends_from(_table)
## Each kind's sleeper: kind -> [part, colour, its place in an end's frame].
static var _sleepers: Dictionary = _sleepers_from(_table)
## The kinds, in the table's order, for a connector's subtype.
static var _kinds: PackedStringArray = _kinds_from(_ends)


static func _read_table() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	return parsed if parsed is Dictionary else {}


static func _vec(row: Variant) -> Vector3:
	return Vector3(float(row[0]), float(row[1]), float(row[2])) if row is Array \
		and (row as Array).size() == 3 else Vector3.ZERO


static func _ends_from(table: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var tracks: Dictionary = table.get("tracks", {})
	for part: String in tracks:
		var list: Array = []
		for row: Dictionary in (tracks[part] as Dictionary).get("ends", []):
			var end := End.new()
			end.at = _vec(row.get("at"))
			end.out = _vec(row.get("out")).normalized()
			end.kind = str(row.get("kind", ""))
			end.sleeper = bool(row.get("sleeper", false))
			end.index = list.size()
			list.append(end)
		out[part] = list
	return out


static func _sleepers_from(table: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var given: Dictionary = table.get("sleepers", {})
	for kind: String in given:
		var spec: Dictionary = given[kind]
		var columns: Array = spec.get("basis", [])
		if columns.size() != 3:
			continue
		var where := Transform3D(Basis(_vec(columns[0]), _vec(columns[1]), _vec(columns[2])),
			_vec(spec.get("origin")))
		out[kind] = [str(spec.get("part", "")), int(spec.get("color", 16)), where]
	return out


static func _kinds_from(ends: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in ends:
		for end: End in ends[part]:
			if not out.has(end.kind):
				out.append(end.kind)
	return out


## Whether [param part_id] is a track the table has ends for.
static func is_track(part_id: String) -> bool:
	return _ends.has(part_id)


## A track's ends in its own frame, in the table's order; empty for any
## other part.
static func ends_of(part_id: String) -> Array:
	return _ends.get(part_id, [])


## The family a track is of ("9V", "6 wide", "12V"...), "" for none.
static func family_of(part_id: String) -> String:
	return str(((_table.get("tracks", {}) as Dictionary).get(part_id, {}) as Dictionary).get(
		"family", ""))


## Where a part goes so that its end [param mine] (its own frame) meets
## [param theirs] (placed): on its place, facing it, the same way up.
static func pose(mine: End, theirs: End) -> Transform3D:
	var into := Transform3D(Basis(-theirs.out, theirs.up, (-theirs.out).cross(theirs.up))
		.orthonormalized(), theirs.at)
	return into * mine.frame().affine_inverse()


## Whether two tracks standing at [param at] and [param there] are joined:
## an end of one on an end of the other. Their covers meet there, a tab in
## the other's slot, as real tracks do.
static func joined(mine: String, at: Transform3D, theirs: String, there: Transform3D) -> bool:
	if not _ends.has(mine) or not _ends.has(theirs):
		return false
	for one: End in _ends[mine]:
		var a: End = one.placed(at, 0)
		for other: End in _ends[theirs]:
			if a.meets(other.placed(there, 0)):
				return true
	return false


## The sleepers a joint of [param mine] onto [param theirs] needs: one under
## it when neither end has its own, for a joint that takes one. [part,
## colour, where] each.
static func sleepers_for(mine: End, theirs: End) -> Array:
	if mine.sleeper or theirs.sleeper or not _sleepers.has(theirs.kind):
		return []
	var spec: Array = _sleepers[theirs.kind]
	return [[spec[0], spec[1], theirs.frame() * (spec[2] as Transform3D)]]


## A track's ends as Attach's connectors: "track[0]", "track[1]"... in the
## table's order, each framed so that two joined ends' frames are laid one
## on the other turned half about up (Attach.pose asks [method attach_pose]).
static func points(part_id: String) -> Array:
	var out: Array = []
	for end: End in ends_of(part_id):
		var point := Attach.Point.new()
		point.type = "track"
		point.index = end.index
		point.kind = KIND
		point.sub = maxi(_kinds.find(end.kind), 0)
		point.frame = end.frame()
		point.exact = false
		out.append(point)
	return out


## Whether two of Attach's connectors are track ends that join.
static func points_join(a: Attach.Point, b: Attach.Point) -> bool:
	return a.kind == KIND and b.kind == KIND and a.sub == b.sub


## Attach's pose for a track end [param b] (the source's) on [param a] (the
## target's, its part at [param target]): face to face, the same way up.
## A track joins one way; yaw, flip, slide and the rest are refused.
static func attach_pose(target: Transform3D, a: Attach.Point, b: Attach.Point,
		options: Dictionary) -> Dictionary:
	for key: String in ["yaw", "flip", "slide", "seat", "align", "orient"]:
		if options.has(key) and not (key == "yaw" and is_zero_approx(float(options[key]))):
			return {"error": "a track's end joins another face to face, one way: leave out %s" % key}
	if not points_join(a, b):
		return {"error": "track ends of two kinds do not join: %s and %s" % [
			_kinds[a.sub] if a.sub < _kinds.size() else "?",
			_kinds[b.sub] if b.sub < _kinds.size() else "?"]}
	var half := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var at: Transform3D = target * a.frame * half * b.frame.affine_inverse()
	return {"at": Transform3D(at.basis.orthonormalized(), at.origin)}


# -- the hand ---------------------------------------------------------------

## Whether the ghost is on a track's end now ([method aim]).
var on_end: bool = false
## The free end it is on, and the part's end that goes on it.
var target: End = null
var held_index: int = 0
## Where the part in hand goes on it, and the sleepers it needs.
var at := Transform3D.IDENTITY
var sleepers: Array = []
## R's turns since the hand came onto this end: the next of the part's
## ends each.
var _turns: int = 0
var _aimed_key: String = ""
## Every free end of the tracks down, as the world's revision left them.
var _free: Array = []
var _free_at: int = -1
var _free_world: BrickWorld = null


## Put the part in hand on the free end the pointer's line ([param origin]
## going [param way]) is within [constant REACH_PX] of, nearest first, if it
## is a track with an end of that kind. False, and nothing changed but
## [member on_end], when it is not.
func aim(builder: Builder, part_id: String, origin: Vector3, way: Vector3) -> bool:
	on_end = false
	var mine: Array = ends_of(builder.library.resolve(part_id)) \
		if builder.library != null else []
	if mine.is_empty() or builder.world == null:
		return false
	var kinds: Dictionary = {}
	for end: End in mine:
		kinds[end.kind] = true
	var camera: Camera3D = builder.get_viewport().get_camera_3d() \
		if builder.is_inside_tree() else null
	var best: End = null
	var best_px: float = REACH_PX
	for end: End in free_ends(builder.world, builder.library):
		if not kinds.has(end.kind) or builder.lattice.unseen.has(end.brick):
			continue
		var px: float = _pixels(camera, origin, way, end.at + end.up * FACE_MIDDLE)
		if px <= best_px:
			best = end
			best_px = px
	if best == null:
		return false
	var key: String = "%s|%d|%d" % [part_id, best.brick, best.index]
	if key != _aimed_key:
		_aimed_key = key
		_turns = 0
	target = best
	var fitting: Array = []
	for end: End in mine:
		if end.kind == best.kind:
			fitting.append(end.index)
	var first: int = _continuing(mine, fitting, best, builder)
	held_index = fitting[posmod(fitting.find(first) + _turns, fitting.size())]
	at = pose(mine[held_index], best)
	sleepers = sleepers_for(mine[held_index], best)
	on_end = true
	return true


## R on a track end: the part's next end to the joint.
func turn(by: int) -> void:
	_turns += by


## The track the ghost is on the end of, by its name, for the status line.
func target_name(builder: Builder) -> String:
	var brick: BrickWorld.Brick = builder.world.get_brick(target.brick) \
		if on_end and target != null else null
	var info: PartLibrary.PartInfo = builder.library.parts.get(brick.part_id) \
		if brick != null else null
	return Inventory._tidy(info.name) if info != null else "a track"


## Every end of every track down that no other track's end meets.
func free_ends(world: BrickWorld, library: PartLibrary) -> Array:
	if world == _free_world and world.revision == _free_at:
		return _free
	var all: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if brick.hidden:
			continue
		var part: String = library.resolve(brick.part_id)
		if not _ends.has(part):
			continue
		for end: End in _ends[part]:
			all.append(end.placed(brick.transform, brick.id))
	# Met ends by where they are: two LDU cells, and the cells round each.
	var cells: Dictionary = {}
	for end: End in all:
		var cell := Vector3i((end.at / 2.0).round())
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(end)
	_free = []
	for end: End in all:
		var met: bool = false
		var cell := Vector3i((end.at / 2.0).round())
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for other: End in cells.get(cell + Vector3i(dx, dy, dz), []):
						if other.brick != end.brick and end.meets(other):
							met = true
		if not met:
			_free.append(end)
	_free_at = world.revision
	_free_world = world
	return _free


## Of [param fitting] (indices of [param mine] that join [param theirs]),
## the one that turns the part in hand the way the track it goes on turns:
## sixteen curves laid one after another go round, not in an S. The first
## when the track it goes on runs straight or has more than two ends.
func _continuing(mine: Array, fitting: Array, theirs: End, builder: Builder) -> int:
	var brick: BrickWorld.Brick = builder.world.get_brick(theirs.brick)
	var their_ends: Array = ends_of(builder.library.resolve(brick.part_id)) \
		if brick != null else []
	if their_ends.size() != 2 or mine.size() != 2:
		return fitting[0]
	var other: End = their_ends[1 - theirs.index]
	var bends: float = _bend(other, their_ends[theirs.index])
	if absf(bends) < 1e-3:
		return fitting[0]
	for index: int in fitting:
		if signf(_bend(mine[index], mine[1 - index])) == signf(bends):
			return index
	return fitting[0]


## Which way a two-ended track turns going in at [param from] and out at
## [param to]: positive left (about up), 0 straight.
static func _bend(from: End, to: End) -> float:
	return (-from.out).cross(to.out).y


## How far apart, in pixels, the pointer and [param point] are drawn: the
## pointer is where its line, [param origin] going [param way], is drawn.
## With no camera (a probe's builder alone), as a 1280 x 720 view at 75
## degrees would draw them.
static func _pixels(camera: Camera3D, origin: Vector3, way: Vector3, point: Vector3) -> float:
	var along: float = (point - origin).dot(way)
	if along <= 0.0:
		return INF
	var foot: Vector3 = origin + way * along
	if camera != null and camera.is_inside_tree():
		if camera.is_position_behind(point):
			return INF
		return camera.unproject_position(point).distance_to(camera.unproject_position(foot))
	return point.distance_to(foot) / along * (360.0 / tan(deg_to_rad(37.5)))
