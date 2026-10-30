## Copies of the selection laid out at once: in a row, round an axis, or
## along a hose's path, each checked for room, put down as one step to undo
## (docs/APP_UX.md, B6). Fences, colonnades, round towers, wheel spokes and
## roof tiles were copied one at a time.
##
## SketchUp: after a copy, "5x" makes five in a row and "/5" divides the
## gap. Fusion and Onshape have linear and circular patterns. No LEGO CAD
## has either. Here "5x" and "/5" are typed straight after a copy is put
## down (EditVerbs, through TypedEntry's [member TypedEntry.reads]), and
## Edit, Pattern… (PatternDialog) takes a count and a spacing along an
## axis, a count round what the selection stands on or hangs from, or a
## spacing along a hose.
##
## A layout is pure: a list of moves in the world, one a copy, each to be
## applied to the parts where they stand ([method row], [method ring],
## [method repeated], [method divided], [method along]). Checking them for
## room, showing them first and putting them down are this node's.
class_name Pattern
extends Node3D

const GHOST_SHADER := preload("res://src/render/ghost.gdshader")
## The most copies one pattern makes, and the most parts it puts down.
const MOST_COPIES := 500
const MOST_PARTS := 5000
## The most parts whose joint a ring is offered round ([method centres]).
const JOINT_MOST := 200

var builder: Builder
var world: BrickWorld
var library: PartLibrary
## Whether the copies are still to be shown: the typed field open, the
## dialog up. The ghosts go when it says no, however that came about.
var keep: Callable = func() -> bool: return true

## Of the last [method check]: each copy (from 0) that had no room, the
## first of them, and the part in its way (0: the ground, or another copy).
var refused := PackedInt32Array()
var first_refused: int = -1
var blocker: int = 0

var _ghosts: Array[MeshInstance3D] = []
## The ghost meshes of the parts copied, [fits, no room], for these ids.
var _meshes: Array = []
var _meshes_of: Array = []


func _process(_delta: float) -> void:
	if not _ghosts.is_empty() and _ghosts[0].visible and not bool(keep.call()):
		hide_copies()


# -- layouts: the moves, one a copy ---------------------------------------------


## [param count] copies, each [param by] further on (LDU).
static func row(by: Vector3, count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for k: int in range(1, count + 1):
		out.append(Transform3D(Basis.IDENTITY, by * k))
	return out


## [param count] copies, each [param degrees] further round [param axis]
## through [param point].
static func ring(point: Vector3, axis: Vector3, degrees: float, count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for k: int in range(1, count + 1):
		var turn := Basis(axis.normalized(), deg_to_rad(degrees * k))
		out.append(Transform3D(turn, point - turn * point))
	return out


## [param count] copies, each [param step] again from the last: SketchUp's
## "5x" after a copy, which is [param step] (a move, a turn, or both).
static func repeated(step: Transform3D, count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var at := Transform3D.IDENTITY
	for _k: int in count:
		at = step * at
		out.append(at)
	return out


## The gap [param step] made, in [param parts] even steps: the
## [param parts] − 1 copies between where a copy came from and where it went
## (SketchUp's "/5"), as moves from where it came from.
static func divided(step: Transform3D, parts: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for k: int in range(1, parts):
		out.append(power(step, float(k) / parts))
	return out


## [param step] a fraction [param f] of the way: a move, [param f] of it; a
## turn about any line (with a slide along it), [param f] of the turn about
## the same line. A turn's line is where it turns about, which a move and a
## turn written as one transform do not say: it is worked out (the screw).
static func power(step: Transform3D, f: float) -> Transform3D:
	var q: Quaternion = step.basis.orthonormalized().get_rotation_quaternion()
	var angle: float = q.get_angle()
	var axis: Vector3 = q.get_axis() if angle > 1e-6 else Vector3.UP
	if angle > PI:
		angle = TAU - angle
		axis = -axis
	var t: Vector3 = step.origin
	if angle < 1e-6:
		return Transform3D(Basis.IDENTITY, t * f)
	axis = axis.normalized()
	var along_axis: Vector3 = axis * axis.dot(t)
	var across: Vector3 = t - along_axis
	# The point the turn is about, in the plane across the axis:
	# t = (I − R)·c, solved.
	var centre: Vector3 = 0.5 * (across + axis.cross(across) / tan(angle * 0.5))
	var turn := Basis(axis, angle * f)
	return Transform3D(turn, centre - turn * centre + along_axis * f)


## [param count] copies along a path (a hose's centreline), each
## [param spacing] LDU further along it than the last from where the path
## passes nearest [param from], turned as the path turns. Fewer when the
## path ends first.
static func along(points: PackedVector3Array, from: Vector3, spacing: float,
		count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if points.size() < 2 or is_zero_approx(spacing):
		return out
	# How far along each point is, and a frame carried along each run
	# turning only as the path turns.
	var runs: PackedFloat64Array = [0.0]
	var frames: Array[Basis] = [Basis.IDENTITY]
	var way: Vector3 = (points[1] - points[0]).normalized()
	for n: int in range(1, points.size()):
		runs.append(runs[n - 1] + points[n].distance_to(points[n - 1]))
		if n < points.size() - 1:
			var next: Vector3 = (points[n + 1] - points[n]).normalized()
			var bend: Basis = Basis.IDENTITY
			if way.cross(next).length() > 1e-6:
				bend = Basis(Quaternion(way, next))
			frames.append(bend * frames[n - 1])
			way = next
	var start: float = _nearest_along(points, runs, from)
	var here: Transform3D = _frame_at(points, runs, frames, start)
	for k: int in range(1, count + 1):
		var s: float = start + spacing * k
		if s < 0.0 or s > runs[runs.size() - 1]:
			break
		out.append(_frame_at(points, runs, frames, s) * here.affine_inverse())
	return out


static func _nearest_along(points: PackedVector3Array, runs: PackedFloat64Array,
		point: Vector3) -> float:
	var best: float = 0.0
	var nearest: float = INF
	for n: int in points.size() - 1:
		var a: Vector3 = points[n]
		var span: Vector3 = points[n + 1] - a
		var t: float = clampf((point - a).dot(span) / maxf(span.length_squared(), 1e-9), 0.0, 1.0)
		var gap: float = (a + span * t).distance_squared_to(point)
		if gap < nearest:
			nearest = gap
			best = runs[n] + span.length() * t
	return best


static func _frame_at(points: PackedVector3Array, runs: PackedFloat64Array,
		frames: Array[Basis], s: float) -> Transform3D:
	var n: int = 0
	while n < points.size() - 2 and runs[n + 1] < s:
		n += 1
	var span: float = maxf(runs[n + 1] - runs[n], 1e-9)
	var at: Vector3 = points[n].lerp(points[n + 1], clampf((s - runs[n]) / span, 0.0, 1.0))
	return Transform3D(frames[mini(n, frames.size() - 1)], at)


## The one move that took parts standing at [param before] to
## [param after] (each a list of transforms, the same parts in order), or
## null when they did not all move as one.
static func step_between(before: Array, after: Array) -> Variant:
	if before.is_empty() or before.size() != after.size():
		return null
	var step: Transform3D = (after[0] as Transform3D) * (before[0] as Transform3D).affine_inverse()
	for n: int in range(1, before.size()):
		var moved: Transform3D = step * (before[n] as Transform3D)
		var there: Transform3D = after[n]
		if moved.origin.distance_to(there.origin) > 0.05:
			return null
		for axis: int in 3:
			if (moved.basis[axis] - there.basis[axis]).length() > 0.002:
				return null
	return Transform3D(step.basis.orthonormalized(), step.origin)


## A move in the words a builder uses: "2 studs along x", "turned 22.5°".
static func words_for(step: Transform3D) -> String:
	var said := PackedStringArray()
	var angle: float = rad_to_deg(step.basis.orthonormalized().get_rotation_quaternion().get_angle())
	if angle > 180.0:
		angle = 360.0 - angle
	if angle > 0.01:
		said.append("turned %s°" % String.num(snappedf(angle, 0.01), 2))
	else:
		for n: int in 3:
			if absf(step.origin[n]) > 0.001:
				said.append("%s along %s" % [TypedEntry._length_words(step.origin[n], n == 1)
					.trim_prefix("+"), TypedEntry.AXES[n]])
	return ", ".join(said) if not said.is_empty() else "in the same place"


# -- what "5x" and "/5" mean, typed after a copy ----------------------------------


## [param text] read as copies after a copy whose move was [param step]
## (TypedEntry.reads): {copies, divide, words, error, empty}, or {} when it
## says something else ("5", "x 5": a move, TypedEntry.parse's).
##   "5x", "5*", "*5"   five in the row, counting the copy just put down:
##                      four more, each the same move again;
##   "/5"               the gap from where it came from cut in five: four
##                      more between.
static func read(text: String, step: Transform3D) -> Dictionary:
	var s: String = text.strip_edges().to_lower().replace(" ", "")
	var out: Dictionary = {"copies": 0, "divide": false, "words": "", "error": "",
		"empty": false, "move": Vector3.ZERO, "turn": 0.0, "tilt": 0.0}
	var count: String = ""
	if s.begins_with("/"):
		out["divide"] = true
		count = s.substr(1)
	elif s.begins_with("*"):
		count = s.substr(1)
	elif s.length() >= 2 and s.right(1) in ["x", "*"] and s.left(-1).is_valid_int() \
			and not s.left(1) in ["-", "+"]:
		count = s.left(-1)
	else:
		return {}
	if count.is_empty():
		out["empty"] = true
		out["hint"] = ("how many parts to cut the gap in: /5 puts four between"
			if out["divide"] else "how many in the row: *5 makes four more")
		return out
	if not count.is_valid_int():
		out["error"] = "“%s” is not a whole number" % count
		return out
	var n: int = count.to_int()
	if n < 2:
		out["error"] = "at least 2"
		return out
	if n - 1 > MOST_COPIES:
		out["error"] = "at most %d" % (MOST_COPIES + 1)
		return out
	out["copies"] = n - 1
	out["words"] = ("%d more between, the gap cut in %d" % [n - 1, n]) if out["divide"] \
		else ("%d in the row: %d more, each %s" % [n, n - 1, words_for(step)])
	return out


# -- room, ghosts and putting them down --------------------------------------------


## Whether every copy has room: each against the model and the copies
## before it, by the rule a part put down meets (Builder.room_for), and
## none below the ground. Says which did not in [member refused].
func check(ids: Array, moves: Array) -> bool:
	refused = PackedInt32Array()
	first_refused = -1
	blocker = 0
	var parts: Array = parts_of(ids)
	if parts.is_empty() or moves.is_empty():
		return false
	# The copies with room so far stand in the lattice under numbers no
	# part has, so the next is checked against them too; taken out after.
	var standing: Array[int] = []
	var number: int = -1
	for k: int in moves.size():
		var covers: Array = []
		var fits: bool = true
		for item: Dictionary in parts:
			var at: Transform3D = placed(moves[k], item["at"])
			if not builder.room_for(str(item["part"]), at, true):
				fits = false
				if first_refused < 0:
					first_refused = k
					blocker = builder.room_blocker
				break
			covers.append(builder.boxes_for(library.mesh_for(str(item["part"])), at))
		if not fits:
			refused.append(k)
			continue
		for packed: PackedInt32Array in covers:
			builder.lattice.occupy_boxes(number, packed)
			standing.append(number)
			number -= 1
	for id: int in standing:
		builder.lattice.release(id)
	return refused.is_empty()


## Show the copies where they would go, a copy with no room red, and say
## why not: "" when every copy has room.
func show_copies(ids: Array, moves: Array) -> String:
	var why: String = refusal(ids, moves)
	if moves.size() * ids.size() <= MOST_PARTS:
		_draw(ids, moves)
	else:
		hide_copies()
	return why


## In words, why these copies cannot go down: "" when they can.
func refusal(ids: Array, moves: Array) -> String:
	if moves.is_empty():
		return "no copies"
	if moves.size() > MOST_COPIES or moves.size() * ids.size() > MOST_PARTS:
		return "too many: at most %d copies and %d parts" % [MOST_COPIES, MOST_PARTS]
	if check(ids, moves):
		return ""
	var what: String = "the ground or another copy"
	var brick: BrickWorld.Brick = world.get_brick(blocker) if blocker != 0 else null
	if brick != null:
		what = _name_of(brick.part_id)
	if refused.size() == 1:
		return "copy %d has no room: %s is in the way" % [first_refused + 1, what]
	return "%d copies have no room, the first copy %d: %s is in the way" \
		% [refused.size(), first_refused + 1, what]


func hide_copies() -> void:
	for ghost: MeshInstance3D in _ghosts:
		ghost.visible = false


## Put the copies down, if every one has room: as one step to undo, called
## [param words], the copies selected. Their ids; none when any had no room.
func put(ids: Array, moves: Array, words: String) -> PackedInt64Array:
	hide_copies()
	var made := PackedInt64Array()
	if not refusal(ids, moves).is_empty():
		return made
	var parts: Array = parts_of(ids)
	var steps: Array = []
	for move: Transform3D in moves:
		# Each copy of a named assembly or a minifigure another one of it,
		# as a paste makes: "Guard" copied beside "Guard" is "Guard 2".
		var renamed: Dictionary = {}
		var adds: Array = []
		for item: Dictionary in parts:
			var path: String = Assemblies.path_from(str(item["group"]), str(item["unit"]))
			path = builder.copy_group.call(path, renamed) if builder.copy_group.is_valid() \
				else builder.place_group
			adds.append({"part": item["part"], "color": item["color"],
				"at": placed(move, item["at"]), "path": path,
				"step": int(builder.place_step.call(path)) if builder.place_step.is_valid() else -1})
		var put_down: Array = builder.swap_bricks(PackedInt64Array(), adds)
		for step: Dictionary in put_down:
			made.append(int(step["brick"]))
		steps.append_array(put_down)
	builder.record(steps, words)
	builder.selection.clear()
	for brick_id: int in made:
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	return made


## The parts of these bricks as they stand: {part, color, at, group, unit}.
func parts_of(ids: Array) -> Array:
	var out: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and library.mesh_for(brick.part_id) != null:
			out.append({"part": brick.part_id, "color": brick.color_code, "at": brick.transform,
				"group": brick.group, "unit": brick.unit})
	return out


## Where a part standing at [param at] goes, moved by [param move]: on the
## grid exactly when it is square to it.
static func placed(move: Transform3D, at: Transform3D) -> Transform3D:
	var to: Transform3D = move * at
	var basis: Basis = to.basis.orthonormalized()
	return Builder._tidy(Transform3D(basis, to.origin), BrickLattice.is_square_to_grid(basis))


func _draw(ids: Array, moves: Array) -> void:
	if _meshes.is_empty() or _meshes_of != ids:
		_meshes = [_mesh_of(ids, true), _mesh_of(ids, false)]
		_meshes_of = ids.duplicate()
	while _ghosts.size() < moves.size():
		var ghost := MeshInstance3D.new()
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		_ghosts.append(ghost)
	for k: int in _ghosts.size():
		var ghost: MeshInstance3D = _ghosts[k]
		ghost.visible = k < moves.size()
		if ghost.visible:
			ghost.mesh = _meshes[1] if refused.has(k) else _meshes[0]
			ghost.transform = moves[k]


## The parts as they stand, as one ghost mesh, a surface per colour; red
## and striped for [param fits] false (src/render/ghost.gdshader).
func _mesh_of(ids: Array, fits: bool) -> ArrayMesh:
	var by_colour: Dictionary = {}
	for item: Dictionary in parts_of(ids):
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		for s: int in part.surface_count():
			var code: int = part.surface_colors[s] if s < part.surface_colors.size() \
				else Lbm.COLOR_INHERIT
			if code == Lbm.COLOR_INHERIT:
				code = int(item["color"])
			var tool: SurfaceTool = by_colour.get(code)
			if tool == null:
				tool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_colour[code] = tool
			tool.append_from(part.surfaces[s], 0, item["at"])
	var mesh := ArrayMesh.new()
	for code: int in by_colour:
		(by_colour[code] as SurfaceTool).commit(mesh)
		var material := ShaderMaterial.new()
		material.shader = GHOST_SHADER
		material.set_shader_parameter("tint", library.color(code).shown)
		material.set_shader_parameter("valid", fits)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


# -- round what: the line a ring goes round ------------------------------------------


## The lines the selection can go round, the likeliest first: each
## {words, point, axis}. The part it stands on (its middle, upright), the
## joint it hangs on (a turntable's, a hinge's, an axle's), and the middle
## of the floor.
func centres(ids: Array) -> Array:
	var out: Array = []
	var under: int = stands_on(ids)
	if under != 0:
		var brick: BrickWorld.Brick = world.get_brick(under)
		var box: AABB = (brick.transform * library.mesh_for(brick.part_id).bounds).abs()
		# "the plate 16 x 16 it stands on", without its "with underside ribs".
		out.append({"words": "the %s it stands on" % _name_of(brick.part_id).to_lower()
			.get_slice(" with ", 0),
			"point": box.get_center(), "axis": (brick.transform.basis.y).normalized()})
	var picked := PackedInt64Array()
	for brick_id: int in ids:
		if world.get_brick(brick_id) != null:
			picked.append(brick_id)
	# A joint is what a small piece hangs on: a spoke, a door, an arm. Read
	# for a whole floor, the joints near it are thousands of parts' worth.
	var joint: Dictionary = builder._joint_of(picked) \
		if not picked.is_empty() and picked.size() <= JOINT_MOST else {}
	if not joint.is_empty():
		out.append({"words": "the joint it hangs on", "point": joint["point"],
			"axis": (joint["axis"] as Vector3).normalized()})
	out.append({"words": "the middle of the floor", "point": Vector3.ZERO, "axis": Vector3.UP})
	return out


## The part, not the floor's, that the bottom of these parts rests on: the
## widest under them whose top meets their bottom. 0 for none.
func stands_on(ids: Array) -> int:
	var picked: Dictionary = {}
	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null:
			continue
		picked[brick_id] = true
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	if first:
		return 0
	var reach := AABB(box.position - Vector3(0, 4, 0), Vector3(box.size.x, 8, box.size.z))
	var cell: float = BrickLattice.CELL
	var cells := PackedInt32Array([floori(reach.position.x / cell), floori(reach.position.y / cell),
		floori(reach.position.z / cell), ceili(reach.end.x / cell), ceili(reach.end.y / cell),
		ceili(reach.end.z / cell)])
	var best: int = 0
	var widest: float = 0.0
	for other: int in builder.lattice.near_bounds(cells):
		if picked.has(other) or builder.scenery.has(other):
			continue
		var brick: BrickWorld.Brick = world.get_brick(other)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null:
			continue
		var theirs: AABB = (brick.transform * part.bounds).abs()
		if absf(theirs.end.y - box.position.y) > 4.0 or theirs.get_center().y > box.position.y:
			continue
		var wide: float = theirs.size.x * theirs.size.z
		if wide > widest:
			widest = wide
			best = other
	return best


func _name_of(part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	var name: String = info.name if info != null and not info.name.is_empty() else "part " + part_id
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name
