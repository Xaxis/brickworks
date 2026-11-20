## A LEGO® Technic set's face, laid by the app on the body that stands: a
## course of the face's wall laid again as Technic bricks with their holes
## out, a pin in each hole a part goes on, a panel on two pins over the
## courses round it, and a beam on edge on pins along a course as the frame
## line. A face of a body built studless (beams on edge, their holes out, or
## pins left standing where a panel came off) takes the same parts on the
## holes and pins it has.
##
## Why the app lays it. design26 told every session of a Technic subject what
## a Technic set shows on its surface and how each part is held on a studded
## body (TechnicParts, read from 96 real sets), and five laid panels; then the
## room round them was refused, 39 refusals against the base's 11, and the
## panels came off again to get a build. What was kept went where it is
## easiest, beams flat on studs as trim. Told is not laid. On a real set the
## beams stand on edge as the flank's frame lines, pinned into Technic bricks
## in the wall, and the panels sit on pins over the studded body: so here
## every part is put where its pin puts it (Attach.pose, as an attach in
## edit_model does), each tested as the check tests it (OpenPoints.test), and
## a face is one edit, undone by one Undo.
##
## What a face is given, as a Technic builder lays it on a studded body
## (TechnicParts' holds: a pin in a Technic brick laid in the wall course
## holds most of what shows on one):
##   - the panel first, the largest the face takes: the smooth 11 x 2 x 3
##     panel (62531) hung on two pins at its top edge, a fairing over the
##     courses under the pins; else a flat panel (5 x 11, 3 x 11, 3 x 7)
##     flush on two pins through its face holes; in the wall's own colour,
##     over the body and not over air;
##   - then the frame line: the longest straight beam on edge the courses
##     left have room for, on a pin at each end and one in the middle of a
##     long one, black on a light body and light bluish grey on a dark one;
##   - only the courses a part goes on are laid again, each as the longest
##     Technic bricks made in its colour, a two-wide brick's inner row as a
##     plain brick: the same cells, so what stands on it stands as it did.
##
## Read by SurfacePass for a subject in the style of Technic sets
## (TechnicParts.of_technic): its flank findings are these, laid at once and
## settled as any finding is, in place of the side-stud skin a System body's
## flank gets (src/dev/technic_lay_probe.gd).
class_name TechnicLay
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
const PIN := "2780"
const PIN_COLOUR := 0
## Technic bricks with holes by length in studs, longest first.
const BRICKS: Dictionary = {16: "3703", 14: "32018", 12: "3895", 10: "2730", 8: "3702",
	6: "3894", 4: "3701", 2: "3700", 1: "6541"}
## Straight beams by their holes, longest first: the table's frame lines.
const BEAMS: Dictionary = {15: "32278", 13: "41239", 11: "32525", 9: "40490", 7: "32524",
	5: "32316", 3: "32523"}
## The panels a face is given without the table: the flat ones go flush on
## two pins through their faces, the smooth fairing hangs from two in its back.
const PANELS: Array = ["64782", "15458", "62531"]
## How much of a piece's face must be seen from outside along its face: a
## part a wheel or a step hides is not laid.
const SHOWN := 0.6
## Curved panels show most on a Technic set (12% of what shows on the median
## set against flat panels' 1%, TechnicParts' table): one is worth this much
## more than a flat one of its size.
const CURVED_WORTH := 1.5
## The plain bricks a face's course is read in, by length, and the two-wide
## ones, whose outer row is a one-wide brick's (SurfacePass's, and longer).
const ONE_WIDE: Dictionary = {"3005": 1, "3004": 2, "3622": 3, "3010": 4, "3009": 6, "3008": 8,
	"6111": 10, "6112": 12, "2465": 16}
const TWO_WIDE: Dictionary = {"3003": 2, "3002": 3, "3001": 4, "2456": 6, "3007": 8,
	"3006": 10}
const ONE_WIDE_BRICK: Dictionary = {1: "3005", 2: "3004", 3: "3622", 4: "3010", 6: "3009",
	8: "3008", 10: "6111", 12: "6112", 16: "2465"}
## Shortest run of a course laid again, in studs: a Technic brick 1 x 4's
## three holes, the shortest beam's.
const SHORTEST_RUN := 4
## At most so many of each on a flank, and half as many on an end.
const MOST_PANELS := 2
const MOST_BEAMS := 4
## How much of what a part covers must be the body behind it: a panel over
## air is no panel on a body.
const OVER_BODY := 0.6
## Dark colours a frame line is light bluish grey on.
const DARK: Array = [0, 72, 308, 288, 320, 1, 272, 6, 70]

var assistant: Assistant
var library: PartLibrary
var _read: OpenPoints
var _scratch: Assistant.Model
## Each lay's names begin with its own number, so two never meet.
static var _lays: int = 0


## One face's lay: what goes on, what comes off, and in words.
class Lay extends RefCounted:
	var facing: String = ""
	var add: Array = []
	var remove: Array[int] = []
	var restore: Array = []
	var panels: Array[String] = []
	var beams: Array[String] = []
	var courses: int = 0
	var pins: int = 0
	var box: AABB
	var said: String = ""


## A hole on the face a pin goes in, or the end of a pin standing out of it.
class Mount extends RefCounted:
	var target: String = ""          ## "#41" standing, or a new brick's name
	var part: String = ""
	var frame := Transform3D.IDENTITY
	var point: Attach.Point
	var course: int = -1             ## the course laid again it is in; -1 standing
	var standing_pin: bool = false   ## the end of a pin already there
	var tried: bool = false
	var ok: bool = false
	var pin_flip: bool = false
	var pin_at := Transform3D.IDENTITY
	var pin_placement: Assistant.Placement
	var end: Attach.Point            ## the pin's end a part goes on
	var end_frame := Transform3D.IDENTITY
	var end_part: String = ""
	var name: String = ""            ## the pin's, once it is laid

	func end_at() -> Vector3:
		return (end_frame * end.frame).origin


## A course of the face laid again as Technic bricks.
class Course extends RefCounted:
	var ids: Array[int] = []
	var restore: Array = []
	var bricks: Array = []           ## dicts, a Technic brick's with its name
	var also: Array = []             ## [key, mesh, at, part] for each
	var colour: int = 0
	var y: float = 0.0
	var long: int = 0
	var used: bool = false


## A part a face could be given, on its mounts.
class Piece extends RefCounted:
	var kind: String = ""            ## "panel" or "beam"
	var part: String = ""
	var colour: int = 0
	var mounts: Array = []           ## the mounts its pins are in
	var on: Mount                    ## the one it is attached to
	var by: String = ""              ## its own socket on that mount's pin
	var flip: bool = false
	var align: Array = []            ## [own, world]
	var at := Transform3D.IDENTITY
	var placement: Assistant.Placement
	var worth: float = 0.0


func _init(host: Assistant) -> void:
	assistant = host
	library = host.library


## Whether a subject's lays are Technic ones: said to be in the style of
## LEGO® Technic sets.
static func for_subject(host: Assistant) -> bool:
	return TechnicParts.of_technic(host._subject_of())


## The faces a lay could go on: the four sides.
static func facings() -> Array:
	return ["-z", "+z", "-x", "+x"]


## The lay for one face, worked out and not laid; null when nothing fits.
## [param gone]: bricks another finding takes off, never laid again here.
## [param paced]: the frame given back between parts tried (FramePace), as
## the surface pass lays it; awaited either way.
func lay_for(facing: String, gone: Dictionary = {}, paced: bool = false) -> Lay:
	if library == null or assistant.world == null:
		return null
	_pace = FramePace.new() if paced else null
	tests = 0
	why = {}
	_read = OpenPoints.read(assistant)
	_scratch = Assistant.Model.new()
	var out: Vector3 = Assistant.FACES[facing]
	var courses: Array = _courses(facing, gone)
	var found: Array = _standing_mounts(out, gone)
	for n: int in courses.size():
		found.append_array(_course_mounts(courses[n], n, out))
	# Each hole's pin posed once, its end out of the face: a mount is where
	# a part goes on. Tested only when a part is.
	var mounts: Array = found.filter(func(m: Mount) -> bool: return _pose_pin(m, out))
	if mounts.is_empty():
		return null
	_course_ids = {}
	for course: Course in courses:
		for id: int in course.ids:
			_course_ids[id] = true
	_seen = {}
	var rows: Dictionary = _rows(mounts, out)
	var chosen: Array = []
	var colour: int = _face_colour(courses, mounts)
	var end: bool = _is_end(out)
	var most_panels: int = MOST_PANELS / 2 if end else MOST_PANELS
	var most_beams: int = MOST_BEAMS / 2 if end else MOST_BEAMS
	var frame: int = 71 if DARK.has(colour) else 0
	var beams: Array = _best_first(await _beams(frame, rows, out))
	var panels: Array = []
	for part: String in panel_parts():
		if _made(part, colour):
			panels.append_array(await _panels(part, colour, rows, out))
	panels = _best_first(panels)
	# The frame line first, the longest the face takes: on a Technic set it
	# is the line the eye follows along a flank. Then the largest panel, so
	# the face has both; then the frame's other lines, end to end and course
	# above course, and a second panel where room is left.
	await _take_from(beams, chosen, courses, out, "beam", 1)
	await _take_from(panels, chosen, courses, out, "panel", 1)
	await _take_from(beams, chosen, courses, out, "beam", most_beams)
	await _take_from(panels, chosen, courses, out, "panel", most_panels)
	if chosen.is_empty():
		return null
	return _laid(facing, chosen, courses)


## The bricks of every course a lay could lay again: what a piece's box may
## meet before it is tested, as it meets them again laid as Technic bricks.
var _course_ids: Dictionary = {}
## The places of the pieces worked out so far, so one is worked out once.
var _seen: Dictionary = {}


## Gives the frame back when a slice is spent, where the lay is paced.
var _pace: FramePace


func _breathe() -> void:
	if _pace != null and _pace.due():
		await _pace.next()


## The panels a face may be given, best known first: the flat and curved
## panels real Technic sets show most (TechnicParts' table, read from 96 of
## them), else the three that show most there.
static func panel_parts() -> Array:
	if not TechnicParts.available():
		return PANELS
	var out: Array = []
	var roles: Dictionary = TechnicParts.table().get("roles", {})
	for role: String in ["flat_panel", "curved_panel"]:
		for one: Variant in (roles.get(role, {}) as Dictionary).get("parts", []):
			var part: String = str((one as Dictionary).get("part", ""))
			if not part.is_empty() and not out.has(part):
				out.append(part)
	return out if not out.is_empty() else PANELS


## OpenPoints tests the last lay_for asked.
var tests: int = 0
## Why candidates were passed over, by reason, in the last lay_for.
var why: Dictionary = {}


## The part the last room test met, for [member why].
var _met: String = ""


func _no(reason: String) -> void:
	why[reason] = int(why.get(reason, 0)) + 1


## The pieces of [param kind] in order that fit beside those chosen, until
## [param most] of that kind are.
func _take_from(pieces: Array, chosen: Array, courses: Array, out: Vector3, kind: String,
		most: int) -> void:
	for piece: Piece in pieces:
		if chosen.filter(func(p: Piece) -> bool: return p.kind == kind).size() >= most:
			return
		await _breathe()
		if chosen.has(piece) or _clashes(piece, chosen):
			continue
		if _shown(piece, out) < SHOWN:
			_no("%s hidden" % kind)
			continue
		if _takes(piece, chosen, courses, out):
			chosen.append(piece)


## How much of [param piece]'s face is seen from outside, along [param out]:
## the share of rays from its front, on a stud's grid over it, that meet
## nothing standing. A panel behind a wheel is held and clear and shows
## nothing a set's would.
func _shown(piece: Piece, out: Vector3) -> float:
	var box: AABB = _box(piece)
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var front: float = -INF
	var lo: float = INF
	var hi: float = -INF
	for k: int in 8:
		var corner: Vector3 = box.get_endpoint(k)
		front = maxf(front, corner.dot(out))
		lo = minf(lo, corner.dot(along))
		hi = maxf(hi, corner.dot(along))
	var lattice: BrickLattice = assistant.builder.lattice
	var across: int = maxi(1, floori((hi - lo) / STUD))
	var up: int = maxi(1, floori(box.size.y / STUD))
	var open: int = 0
	for i: int in across:
		for j: int in up:
			var at: Vector3 = along * (lo + (hi - lo) * (i + 0.5) / across) + out * (front + 2.0)
			at.y = box.position.y + box.size.y * (j + 0.5) / up
			var hit: BrickLattice.Hit = lattice.raycast(at, out)
			if not hit.is_valid() or assistant.scenery.has(hit.brick_id):
				open += 1
	return float(open) / float(across * up)


## Whether two pieces' boxes meet, or share a mount's pin: no test needed.
func _clashes(piece: Piece, chosen: Array) -> bool:
	var box: AABB = _box(piece).grow(-1.0)
	for other: Piece in chosen:
		if box.intersects(_box(other).grow(-1.0)):
			return true
	return false


func _box(piece: Piece) -> AABB:
	return (piece.at * library.mesh_for(piece.part).bounds).abs()


## Whether a face is one of the body's ends: across its shorter side.
func _is_end(out: Vector3) -> bool:
	var bounds: AABB = assistant.world.model_bounds()
	var across_x: bool = absf(out.z) > 0.5
	var along: float = bounds.size.x if across_x else bounds.size.z
	var other: float = bounds.size.z if across_x else bounds.size.x
	return along < other * 0.8


static func _best_first(pieces: Array) -> Array:
	pieces.sort_custom(func(a: Piece, b: Piece) -> bool: return a.worth > b.worth)
	return pieces


func _made(part: String, colour: int) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	return info != null and library.mesh_for(part) != null and not info.never_made_in(colour)


# -- the face's mounts ------------------------------------------------------------


## The face's courses of plain bricks a lay can lay again as Technic bricks:
## runs of one colour, end to end, the long face open toward [param facing].
func _courses(facing: String, gone: Dictionary) -> Array:
	var model: Assistant.Model = assistant._model_from_world()
	var middle := Vector3.ZERO
	var standing: Array[BrickWorld.Brick] = assistant._bricks_inside({})
	for brick: BrickWorld.Brick in standing:
		middle += brick.transform.origin
	if not standing.is_empty():
		middle /= float(standing.size())
	var rows: Dictionary = {}       ## "depth|y" -> entries
	for placement: Assistant.Placement in model.placements:
		if gone.has(placement.id) or placement.face != "up" or not placement.section.is_empty() \
				or placement.nudge != Vector3.ZERO:
			continue
		var long: int = int(ONE_WIDE.get(placement.part, TWO_WIDE.get(placement.part, 0)))
		if long == 0:
			continue
		var tint: PartLibrary.BrickColor = library.color(placement.color)
		if tint != null and tint.is_transparent():
			continue
		var along_x: bool = placement.rot % 2 == 0
		var two: bool = TWO_WIDE.has(placement.part)
		for half: int in (2 if two else 1):
			var row := Assistant.Placement.from_dict({"part": ONE_WIDE_BRICK[long],
				"color": placement.color, "x": placement.x + (half if two and not along_x else 0),
				"y": placement.y, "z": placement.z + (half if two and along_x else 0),
				"rot": placement.rot})
			if assistant._open_side(row, long, along_x, middle) != facing:
				continue
			var depth: float = row.z if along_x else row.x
			var key: String = "%s|%s" % [snappedf(depth, 0.05), snappedf(placement.y, 0.05)]
			if not rows.has(key):
				rows[key] = []
			var inner: Dictionary = {}
			if two:
				inner = {"part": ONE_WIDE_BRICK[long], "color": placement.color,
					"x": placement.x + (1 - half if not along_x else 0), "y": placement.y,
					"z": placement.z + (1 - half if along_x else 0), "rot": placement.rot % 2}
			(rows[key] as Array).append({"placement": placement, "long": long,
				"along": row.x if along_x else row.z, "depth": depth, "along_x": along_x,
				"inner": inner})
	var out: Array = []
	for key: String in rows:
		var row: Array = rows[key]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["along"]) < float(b["along"]))
		var run: Array = []
		for entry: Dictionary in row:
			var joined: bool = not run.is_empty() and absf(float(run[-1]["along"])
				+ int(run[-1]["long"]) - float(entry["along"])) < 0.05 \
				and (run[-1]["placement"] as Assistant.Placement).color \
					== (entry["placement"] as Assistant.Placement).color
			if not joined:
				var course: Course = _course(run)
				if course != null:
					out.append(course)
				run = []
			run.append(entry)
		var last: Course = _course(run)
		if last != null:
			out.append(last)
	return out


## A run of a course laid again: the longest Technic bricks made in its colour
## along its outer row, plain bricks where none is, its two-wide bricks'
## inner rows as plain one-wide bricks. Null for a run too short.
func _course(run: Array) -> Course:
	var long: int = 0
	for entry: Dictionary in run:
		long += int(entry["long"])
	if long < SHORTEST_RUN:
		return null
	var first: Dictionary = run[0]
	var placement: Assistant.Placement = first["placement"]
	var course := Course.new()
	course.colour = placement.color
	course.y = placement.y
	course.long = long
	var seen: Dictionary = {}
	for entry: Dictionary in run:
		var one: Assistant.Placement = entry["placement"]
		if not seen.has(one.id):
			seen[one.id] = true
			course.ids.append(one.id)
			course.restore.append(SurfacePass._as_dict(one))
		if not (entry["inner"] as Dictionary).is_empty():
			course.bricks.append(entry["inner"])
	var along_x: bool = first["along_x"]
	var at: float = float(first["along"])
	var depth: float = float(first["depth"])
	var left: int = long
	while left > 0:
		var size: int = 0
		for length: int in BRICKS:
			if length <= left and _made(str(BRICKS[length]), course.colour):
				size = length
				break
		var part: String = BRICKS[size] if size > 0 else ""
		if size == 0:
			for length: int in ONE_WIDE_BRICK:
				if length <= left and (size == 0 or length > size):
					size = length
			part = ONE_WIDE_BRICK[size]
		course.bricks.append({"part": part, "color": course.colour,
			"x": at if along_x else depth, "y": course.y, "z": depth if along_x else at,
			"rot": 0 if along_x else 1})
		at += size
		left -= size
	for n: int in course.bricks.size():
		var dict: Dictionary = course.bricks[n]
		var mesh: Lbm.PartMesh = library.mesh_for(str(dict["part"]))
		if mesh == null:
			return null
		course.also.append([-1000 - n, mesh, assistant._transform(
			Assistant.Placement.from_dict(dict), mesh, null), str(dict["part"])])
	return course


## The holes of a course's Technic bricks that open toward [param out].
func _course_mounts(course: Course, index: int, out: Vector3) -> Array:
	var mounts: Array = []
	for n: int in course.bricks.size():
		var dict: Dictionary = course.bricks[n]
		if not BRICKS.values().has(str(dict["part"])):
			continue
		var at: Transform3D = course.also[n][2]
		for point: Attach.Point in Attach.points_of(library, str(dict["part"])):
			if point.type != "socket" or absf((at.basis * point.axis()).normalized().dot(out)) \
					< 0.99:
				continue
			var mount := Mount.new()
			mount.part = str(dict["part"])
			mount.frame = at
			mount.point = point
			mount.course = index
			mount.target = "brick %d" % n
			mounts.append(mount)
	return mounts


## The holes standing that open toward [param out] with nothing in front of
## them, and the ends of pins standing out of the face with nothing on them.
func _standing_mounts(out: Vector3, gone: Dictionary) -> Array:
	var mounts: Array = []
	var lattice: BrickLattice = assistant.builder.lattice
	for brick: BrickWorld.Brick in assistant._bricks_inside({}):
		if gone.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var pin: bool = info.name.to_lower().begins_with("technic pin")
		for point: Attach.Point in Attach.points_of(library, brick.part_id):
			if point.type != ("pin" if pin else "socket"):
				continue
			var axis: Vector3 = (brick.transform.basis * point.axis()).normalized()
			if absf(axis.dot(out)) < 0.99:
				continue
			var middle: Vector3 = (brick.transform * point.frame).origin
			if pin:
				# The end of a pin with nothing round it: out of the face.
				if (middle - brick.transform.origin).dot(out) < 1.0:
					continue
				var bare: bool = true
				for side: Vector3 in _across(out):
					var id: int = lattice.brick_at(BrickLattice.to_cell(middle + side * 7.0))
					if id != 0 and id != brick.id and not assistant.scenery.has(id):
						bare = false
				if not bare:
					continue
				var standing := Mount.new()
				standing.target = "#%d" % brick.id
				standing.part = brick.part_id
				standing.standing_pin = true
				standing.tried = true
				standing.ok = true
				standing.end = point
				standing.end_frame = brick.transform
				standing.end_part = brick.part_id
				standing.name = "#%d" % brick.id
				mounts.append(standing)
				continue
			# A hole: nothing in front of it for a pin's outer half.
			var open: bool = true
			for reach: float in [point.length + 3.0, point.length + 11.0, point.length + 19.0]:
				var id: int = lattice.brick_at(BrickLattice.to_cell(middle + out * reach))
				if id != 0 and not assistant.scenery.has(id):
					open = false
			if not open:
				continue
			var mount := Mount.new()
			mount.target = "#%d" % brick.id
			mount.part = brick.part_id
			mount.frame = brick.transform
			mount.point = point
			mounts.append(mount)
	return mounts


static func _across(out: Vector3) -> Array:
	var side: Vector3 = Vector3.UP.cross(out).normalized()
	return [side, -side, Vector3.UP, Vector3.DOWN]


## A mount's pin posed once: in its hole, its other end out of the face with
## nothing ahead of it. Tested only when a part goes on it (_takes).
func _pose_pin(mount: Mount, out: Vector3) -> bool:
	if mount.tried:
		return mount.ok
	mount.tried = true
	var pin_points: Array = Attach.points_of(library, PIN)
	var inner: Attach.Point = Attach.pick(pin_points, "pin", 0)
	var outer: Attach.Point = Attach.pick(pin_points, "pin", 1)
	if inner == null or outer == null:
		return false
	var hole: Vector3 = (mount.frame * mount.point.frame).origin
	for flip: bool in [false, true]:
		var at: Variant = _posed(mount.frame, mount.part, mount.point, PIN, inner,
			{"flip": flip})
		if at == null:
			continue
		var end: Vector3 = ((at as Transform3D) * outer.frame).origin
		if (end - hole).dot(out) < 15.0 or not _open_ahead(end, out):
			continue
		var placement: Assistant.Placement = _placement_at(PIN, PIN_COLOUR, at)
		if placement == null:
			continue
		mount.ok = true
		mount.pin_flip = flip
		mount.pin_at = at
		mount.pin_placement = placement
		mount.end = outer
		mount.end_frame = at
		mount.end_part = PIN
		return true
	return false


## Nothing of the model ahead of [param at] along [param way], from a stud
## out to past the model: a pin there is on the face, not in a hollow of it.
func _open_ahead(at: Vector3, way: Vector3) -> bool:
	var lattice: BrickLattice = assistant.builder.lattice
	var id: int = lattice.brick_at(BrickLattice.to_cell(at + way * 12.0))
	if id != 0 and not assistant.scenery.has(id):
		return false
	var hit: BrickLattice.Hit = lattice.raycast(at + way * 12.0, way)
	return not hit.is_valid() or assistant.scenery.has(hit.brick_id)


## Whether a piece's own cover is clear of what stands, but for [param skip]
## and the standing pins it goes on: the lattice's own test, so most of what
## the check would refuse is refused before it is asked. Its cover, not its
## box: a fairing's box takes in the room it curves round.
func _clear_inside(piece: Piece, skip: Dictionary, mounts: Array) -> bool:
	var mesh: Lbm.PartMesh = library.mesh_for(piece.part)
	var packed: PackedInt32Array = assistant.builder.boxes_for(mesh, piece.at)
	# What its pins go into it lies against.
	var held: Dictionary = {}
	for mount: Mount in mounts:
		if mount.target.begins_with("#"):
			held[int(mount.target.trim_prefix("#"))] = true
	var holes: Array = []
	for point: Attach.Point in Attach.points_of(library, piece.part):
		if point.type == "socket":
			holes.append([(piece.at * point.frame).origin,
				(piece.at.basis * point.axis()).normalized()])
	for id: int in assistant.builder.lattice.blockers_boxes(packed, 0, skip):
		if held.has(id) or assistant.scenery.has(id):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(id)
		if brick != null and _pin_in(brick, holes):
			continue
		_met = brick.part_id if brick != null else "?"
		return false
	return true


## Whether [param brick] is a pin standing in one of [param holes] ([origin,
## axis] each): a panel goes on every pin its holes meet, as a set's does,
## not only the two it was posed on.
func _pin_in(brick: BrickWorld.Brick, holes: Array) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	if info == null or not info.name.to_lower().begins_with("technic pin"):
		return false
	var ends: Array = Attach.points_of(library, brick.part_id).filter(
		func(p: Attach.Point) -> bool: return p.type == "pin")
	if ends.is_empty():
		return false
	var along: Vector3 = (brick.transform.basis * (ends[0] as Attach.Point).axis()).normalized()
	var middle := Vector3.ZERO
	for end: Attach.Point in ends:
		middle += (brick.transform * end.frame).origin / ends.size()
	for hole: Array in holes:
		var axis: Vector3 = hole[1]
		if absf(axis.dot(along)) < 0.99:
			continue
		var off: Vector3 = middle - (hole[0] as Vector3)
		if (off - axis * off.dot(axis)).length() < 1.5 and absf(off.dot(axis)) < 30.0:
			return true
	return false


## A piece's place, to tell two the same.
func _key(piece: Piece) -> String:
	return "%s|%s|%s" % [piece.part, piece.at.origin.snapped(Vector3.ONE * 0.5),
		piece.at.basis.get_euler().snapped(Vector3.ONE * 0.01)]


## The face's main colour: the courses', else the parts the mounts are in.
func _face_colour(courses: Array, mounts: Array) -> int:
	var counts: Dictionary = {}
	for course: Course in courses:
		counts[course.colour] = int(counts.get(course.colour, 0)) + course.long
	if counts.is_empty():
		for mount: Mount in mounts:
			var id: int = int(mount.target.trim_prefix("#")) if mount.target.begins_with("#") else 0
			var brick: BrickWorld.Brick = assistant.world.get_brick(id) if id != 0 else null
			if brick != null and not mount.standing_pin:
				counts[brick.color_code] = int(counts.get(brick.color_code, 0)) + 1
	var best: int = 71
	for code: int in counts:
		if not counts.has(best) or int(counts[code]) > int(counts[best]):
			best = code
	return best


# -- the parts ----------------------------------------------------------------------


## The mounts by row: level and at one depth, each row in order along the
## face, keyed "y|depth".
func _rows(mounts: Array, out: Vector3) -> Dictionary:
	var rows: Dictionary = {}
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	for mount: Mount in mounts:
		var end: Vector3 = mount.end_at()
		var key: String = "%s|%s" % [snappedf(end.y, 2.0), snappedf(end.dot(out), 2.0)]
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(mount)
	for key: String in rows:
		(rows[key] as Array).sort_custom(func(m: Mount, n: Mount) -> bool:
			return m.end_at().dot(along) < n.end_at().dot(along))
	return rows


## Every way [param part] goes on two mounts at one depth of the face, posed
## and not tested, worth what it covers of the body.
func _panels(part: String, colour: int, rows: Dictionary, out: Vector3) -> Array:
	var pieces: Array = []
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	if mesh == null:
		return pieces
	# Only the holes through its face: on the edge holes a panel would
	# stand out of the body like a fin.
	var thin: Vector3 = _thin_axis(mesh.bounds.size)
	var pairs: Array = _own_pairs(Attach.points_of(library, part).filter(
		func(p: Attach.Point) -> bool: return absf(p.axis().dot(thin)) > 0.99))
	var curved: bool = TechnicParts.role_of(str((library.parts[part] as PartLibrary.PartInfo)
		.name)) == "curved_panel"
	var size: Vector3 = mesh.bounds.size
	var area: float = maxf(size.x * size.y, maxf(size.y * size.z, size.x * size.z))
	# Any two pin ends at one depth of the face: a flat panel goes on two one
	# above the other as often as on two side by side.
	var planes: Dictionary = {}
	for key: String in rows:
		var depth: String = key.get_slice("|", 1)
		if not planes.has(depth):
			planes[depth] = []
		(planes[depth] as Array).append_array(rows[key])
	for depth: String in planes:
		var row: Array = planes[depth]
		for i: int in row.size():
			await _breathe()
			var a: Mount = row[i]
			for k: int in row.size():
				if i == k:
					continue
				var b: Mount = row[k]
				var gap: float = (b.end_at() - a.end_at()).length()
				for pair: Array in pairs:
					var own_gap: float = ((pair[1] as Attach.Point).frame.origin
						- (pair[0] as Attach.Point).frame.origin).length()
					if absf(gap - own_gap) > 1.5:
						continue
					var piece: Piece = _posed_on(part, colour, a, b, pair, out, curved, true)
					if piece == null:
						continue
					var place: String = _key(piece)
					if _seen.has(place):
						continue
					_seen[place] = true
					if not _clear_inside(piece, _course_ids, [a, b]):
						_no("panel meets %s" % _met)
						continue
					var over: float = _over_body(piece, out)
					if over < OVER_BODY:
						_no("panel over air")
						continue
					piece.kind = "panel"
					piece.worth = area * (CURVED_WORTH if curved else 1.0) * over
					pieces.append(piece)
	return pieces


## The axis a part's box is thinnest along, in its own frame.
static func _thin_axis(size: Vector3) -> Vector3:
	if size.x <= size.y and size.x <= size.z:
		return Vector3.RIGHT
	return Vector3.UP if size.y <= size.z else Vector3.BACK


## A part's own pairs of holes that two pins from behind could go in: two
## parallel sockets side by side across their axis, a whole number of holes
## apart, from two to eleven.
static func _own_pairs(own: Array) -> Array:
	var pairs: Array = []
	for i: int in own.size():
		var p: Attach.Point = own[i]
		if p.type != "socket":
			continue
		for k: int in range(i + 1, own.size()):
			var q: Attach.Point = own[k]
			if q.type != "socket" or absf(p.axis().dot(q.axis())) < 0.999:
				continue
			var d: Vector3 = q.frame.origin - p.frame.origin
			if absf(d.dot(p.axis())) > 1.0:
				continue
			# Straight across, along one of the part's own axes.
			var steps: int = 0
			for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
				if absf(d.normalized().dot(axis)) > 0.999:
					steps = roundi(d.length() / STUD)
			if steps < 2 or steps > 11 or absf(d.length() - steps * STUD) > 1.0:
				continue
			pairs.append([p, q])
			pairs.append([q, p])
	# The widest first: a panel held at its ends hangs square.
	pairs.sort_custom(func(x: Array, y: Array) -> bool:
		return ((x[1] as Attach.Point).frame.origin - (x[0] as Attach.Point).frame.origin) \
			.length() > ((y[1] as Attach.Point).frame.origin
			- (y[0] as Attach.Point).frame.origin).length())
	return pairs


## [param part] on mount [param a]'s pin by its socket pair[0], its pair[1]
## on [param b]'s, its body out of the face; null where it does not go.
func _posed_on(part: String, colour: int, a: Mount, b: Mount, pair: Array, out: Vector3,
		hangs: bool, panel: bool = false) -> Piece:
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	var mine: Attach.Point = pair[0]
	var other: Attach.Point = pair[1]
	var own_way: Vector3 = (other.frame.origin - mine.frame.origin).normalized()
	var world_way: Vector3 = (b.end_at() - a.end_at()).normalized()
	for flip: bool in [false, true]:
		var options: Dictionary = {"flip": flip, "align": [own_way, world_way]}
		var at: Variant = _posed(a.end_frame, a.end_part, a.end, part, mine, options)
		if at == null:
			_no("pose")
			continue
		var t: Transform3D = at
		if ((t * other.frame).origin - b.end_at()).length() > 1.5:
			_no("second pin")
			continue
		var box: AABB = (t * mesh.bounds).abs()
		# Its body out of the face, not into the wall the pin comes out of
		# (a pin's end is half a hole out of it), and a fairing hung by its
		# top, the right way up.
		var back: float = INF
		for k: int in 8:
			back = minf(back, box.get_endpoint(k).dot(out))
		if back < a.end_at().dot(out) - 13.0:
			_no("into the wall")
			continue
		if hangs and (t.basis * Vector3.UP).dot(Vector3.UP) < 0.99:
			_no("upside down")
			continue
		# A panel flat against the face: its thinnest side out of it.
		if panel and absf((t.basis * _thin_axis(mesh.bounds.size)).normalized().dot(out)) < 0.99:
			_no("not flat on the face")
			continue
		var placement: Assistant.Placement = _placement_at(part, colour, t)
		if placement == null:
			_no("not square")
			continue
		var piece := Piece.new()
		piece.part = part
		piece.colour = colour
		piece.mounts = [a, b]
		piece.on = a
		piece.by = mine.address()
		piece.flip = flip
		piece.align = [own_way, world_way]
		piece.at = t
		piece.placement = placement
		return piece
	return null


## Every frame line the face's mounts take: a straight beam on edge on the
## pins of a row of holes a hole apart, posed and not tested, the longest
## worth most and the lower of two as long a little more.
func _beams(colour: int, rows: Dictionary, out: Vector3) -> Array:
	var pieces: Array = []
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var bounds: AABB = assistant.world.model_bounds()
	for key: String in rows:
		var row: Array = rows[key]
		# Runs of mounts a hole apart.
		var runs: Array = []
		var run: Array = []
		for mount: Mount in row:
			if not run.is_empty() and absf((mount.end_at() - (run[-1] as Mount).end_at())
					.dot(along) - STUD) > 1.0:
				runs.append(run)
				run = []
			run.append(mount)
		runs.append(run)
		for one: Array in runs:
			await _breathe()
			for holes: int in BEAMS:
				if holes > one.size() or not _made(str(BEAMS[holes]), colour):
					continue
				# Centred on the run first, then each other place along it.
				var starts: Array = range(0, one.size() - holes + 1)
				var mid: int = (one.size() - holes) / 2
				starts.sort_custom(func(p: int, q: int) -> bool:
					return absi(p - mid) < absi(q - mid))
				for start: int in starts.slice(0, 3):
					var first: Mount = one[start]
					var last: Mount = one[start + holes - 1]
					var piece: Piece = _beam_on(str(BEAMS[holes]), colour, first, last, out)
					if piece == null:
						continue
					var place: String = _key(piece)
					if _seen.has(place):
						continue
					_seen[place] = true
					if not _clear_inside(piece, _course_ids, [first, last]):
						_no("beam meets %s" % _met)
						continue
					var over: float = _over_body(piece, out)
					if over < OVER_BODY:
						_no("beam over air")
						continue
					piece.kind = "beam"
					piece.mounts = [first, last]
					if holes >= 9:
						piece.mounts.append(one[start + holes / 2])
					var low: float = 1.0 - clampf((first.end_at().y - bounds.position.y)
						/ maxf(bounds.size.y, 1.0), 0.0, 1.0)
					piece.worth = holes * STUD * STUD * over * (1.0 + 0.2 * low)
					pieces.append(piece)
	return pieces


func _beam_on(part: String, colour: int, first: Mount, last: Mount, out: Vector3) -> Piece:
	var own: Array = Attach.points_of(library, part).filter(func(p: Attach.Point) -> bool:
		return p.type == "socket")
	if own.size() < 2:
		return null
	# Its end holes: the two furthest apart.
	var ends: Array = [own[0], own[0]]
	var most: float = -1.0
	for p: Attach.Point in own:
		for q: Attach.Point in own:
			var d: float = (q.frame.origin - p.frame.origin).length()
			if d > most:
				most = d
				ends = [p, q]
	var piece: Piece = _posed_on(part, colour, first, last, ends, out, false)
	return piece


## How much of what a piece covers, seen from out of the face, has the body
## just behind it.
func _over_body(piece: Piece, out: Vector3) -> float:
	var mesh: Lbm.PartMesh = library.mesh_for(piece.part)
	var box: AABB = (piece.at * mesh.bounds).abs()
	var along: Vector3 = Vector3.UP.cross(out).normalized()
	var back: float = INF
	for k: int in 8:
		var corner: Vector3 = box.get_endpoint(k)
		back = minf(back, corner.dot(out))
	var lo_a: float = INF
	var hi_a: float = -INF
	for k: int in 8:
		var corner: Vector3 = box.get_endpoint(k)
		lo_a = minf(lo_a, corner.dot(along))
		hi_a = maxf(hi_a, corner.dot(along))
	var hits: int = 0
	var all: int = 0
	var lattice: BrickLattice = assistant.builder.lattice
	var a: float = lo_a + 5.0
	while a < hi_a:
		var y: float = box.position.y + 4.0
		while y < box.end.y:
			all += 1
			var at: Vector3 = along * a + out * (back - 6.0)
			at.y = y
			var id: int = lattice.brick_at(BrickLattice.to_cell(at))
			if id != 0 and not assistant.scenery.has(id):
				hits += 1
			y += 8.0
		a += 10.0
	return float(hits) / maxf(all, 1)


## Whether [param piece] fits beside what is chosen: its pins and itself,
## each tested as the check tests it, the courses it and the chosen go on
## laid again.
func _takes(piece: Piece, chosen: Array, courses: Array, out: Vector3) -> bool:
	var skip: Dictionary = {}
	var also: Array = []
	var used: Dictionary = {}
	for mount: Mount in piece.mounts:
		if mount.course >= 0:
			used[mount.course] = true
	for other: Piece in chosen:
		for mount: Mount in other.mounts:
			if mount.course >= 0:
				used[mount.course] = true
	for n: int in used:
		var course: Course = courses[n]
		for id: int in course.ids:
			skip[id] = true
		also.append_array(course.also)
	var key: int = -1
	var pinned: Dictionary = {}
	for other: Piece in chosen:
		for mount: Mount in other.mounts:
			if not mount.standing_pin and not pinned.has(mount):
				pinned[mount] = true
				also.append([key, library.mesh_for(PIN), mount.pin_at, PIN])
				key -= 1
		also.append([key, library.mesh_for(other.part), other.at, other.part])
		key -= 1
	# A mount another piece's pin is in already serves this one too.
	for mount: Mount in piece.mounts:
		if mount.standing_pin or pinned.has(mount):
			continue
		if not _fits(mount.pin_placement, skip, also, "pin"):
			return false
		also.append([key, library.mesh_for(PIN), mount.pin_at, PIN])
		key -= 1
		pinned[mount] = true
	return _fits(piece.placement, skip, also, piece.kind)


## Whether [param placement] fits as the check tests it, held by something
## that stays: [param what] names it in [member why] when it does not.
func _fits(placement: Assistant.Placement, skip: Dictionary, also: Array,
		what: String = "") -> bool:
	tests += 1
	var trial: Dictionary = _read.test(placement, skip, also)
	if not bool(trial["fits"]):
		_no("%s meets %s" % [what, str(trial.get("hits", [])).substr(0, 40)])
		return false
	for by: Variant in trial["held_by"]:
		if int(by) != 0 and not skip.has(int(by)):
			return true
	_no("%s not held" % what)
	return false


# -- posing ---------------------------------------------------------------------------


## [param part] by its [param b] on [param a] of a part standing at
## [param target_at], as an attach in edit_model puts it (Assistant
## ._attach_one): a pin seated by its collar. Null where it does not go.
func _posed(target_at: Transform3D, target_part: String, a: Attach.Point, part: String,
		b: Attach.Point, options: Dictionary) -> Variant:
	var opts: Dictionary = options.duplicate()
	if Attach.pinned(a, b) and not opts.has("slide"):
		# The same two parts by the same connectors seat the same way
		# wherever they are: worked out once.
		var key: String = "%s|%s|%s|%s|%s" % [target_part, a.address(), part, b.address(),
			str(opts)]
		if not _slides.has(key):
			_slides[key] = Attach.seat_slide(Exact.shape_for(library, target_part), target_at,
				Exact.shape_for(library, part), a, b, opts)
		opts["slide"] = _slides[key]
	var posed: Dictionary = Attach.pose(target_at, a, b, opts)
	return null if posed.has("error") else posed["at"]


## Seat slides worked out, by the parts and connectors and options.
static var _slides: Dictionary = {}


## [param part] where [param at] puts it, written as a placement square to
## the grid; null when it is not square.
func _placement_at(part: String, colour: int, at: Transform3D) -> Assistant.Placement:
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	if mesh == null or not BrickLattice.is_square_to_grid(at.basis):
		return null
	var placement := Assistant.Placement.new()
	placement.part = part
	placement.color = colour
	if not assistant._written_at(_scratch, placement, mesh, at, null, "").is_empty() \
			or not placement.section.is_empty():
		return null
	return placement


# -- laid -------------------------------------------------------------------------------


## The chosen pieces as one edit: the courses they go on laid again, a pin in
## each hole they use, each piece attached on its pin.
func _laid(facing: String, chosen: Array, courses: Array) -> Lay:
	_lays += 1
	var stem: String = "technic lay %d" % _lays
	var lay := Lay.new()
	lay.facing = facing
	var used: Dictionary = {}
	for piece: Piece in chosen:
		for mount: Mount in piece.mounts:
			if mount.course >= 0:
				used[mount.course] = true
	var brick_names: Dictionary = {}     ## [course, n] -> name
	var keys: Array = used.keys()
	keys.sort()
	for n: int in keys:
		var course: Course = courses[n]
		lay.courses += 1
		lay.remove.append_array(course.ids)
		lay.restore.append_array(course.restore)
		for k: int in course.bricks.size():
			var dict: Dictionary = (course.bricks[k] as Dictionary).duplicate()
			if BRICKS.values().has(str(dict["part"])):
				dict["name"] = "%s brick %d-%d" % [stem, n, k]
				brick_names["%d|%d" % [n, k]] = dict["name"]
			lay.add.append(dict)
	var pins: int = 0
	for piece: Piece in chosen:
		for mount: Mount in piece.mounts:
			if mount.standing_pin or not mount.name.is_empty():
				continue
			pins += 1
			mount.name = "%s pin %d" % [stem, pins]
			var target: String = mount.target
			if mount.course >= 0:
				target = brick_names["%d|%d" % [mount.course, int(mount.target.get_slice(" ", 1))]]
			lay.add.append({"part": PIN, "color": PIN_COLOUR, "name": mount.name,
				"attach": {"to": "%s.%s" % [target, mount.point.address()], "by": "pin[0]",
					"flip": mount.pin_flip}})
	lay.pins = pins
	var box := AABB()
	var first: bool = true
	for piece: Piece in chosen:
		var own: Vector3 = piece.align[0]
		var world: Vector3 = piece.align[1]
		lay.add.append({"part": piece.part, "color": piece.colour, "attach": {
			"to": "%s.%s" % [piece.on.name, piece.on.end.address()], "by": piece.by,
			"flip": piece.flip, "align": [[_n(own.x), _n(own.y), _n(own.z)],
				[_n(world.x), _n(world.y), _n(world.z)]]}})
		(lay.panels if piece.kind == "panel" else lay.beams).append(piece.part)
		var one: AABB = (piece.at * library.mesh_for(piece.part).bounds).abs()
		box = one if first else box.merge(one)
		first = false
	lay.box = box
	lay.said = _said(lay, chosen, courses, keys)
	return lay


static func _n(value: float) -> float:
	return snappedf(value, 0.0001) + 0.0


func _said(lay: Lay, chosen: Array, courses: Array, used: Array) -> String:
	var bits := PackedStringArray()
	for n: int in used:
		var course: Course = courses[n]
		bits.append("a course of %d stud%s in %s laid again as Technic bricks with their holes out"
			% [course.long, "" if course.long == 1 else "s",
			assistant._colour_name(course.colour).to_lower()])
	for piece: Piece in chosen:
		var called: String = assistant._part_called(piece.part)
		if piece.kind == "panel":
			bits.append("%s %s on two pins over the body" % [piece.part, called])
		else:
			bits.append("%s %s on edge on %d pins as the frame line" % [piece.part, called,
				piece.mounts.size()])
	return "the %s face, as a Technic set's: %s" % [lay.facing, "; ".join(bits)]
