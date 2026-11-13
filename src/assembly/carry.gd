## Several parts held at once, as one thing.
##
## What Copy keeps, what Paste and Duplicate put in your hand, and what
## lifting a selection picks up. Before this a selection could be painted,
## nudged a stud at a time and deleted, and nothing else: there was no way
## to repeat a window, move a wall with the pointer, or turn anything once
## it was down. Every rival has all three, and a house is mostly the same
## few constructions over again.
##
## The parts are kept in a frame of their own whose origin is a stud
## centre or a stud corner, at the bottom of the group. That one choice is
## what keeps the whole thing on the studs: any whole number of studs along
## the ground and any quarter turn about either kind of point carries every
## stud of every part to another stud, so the group can go anywhere and
## turn any way without a single part ending a fraction off. A point
## halfway along a stud's edge would not: turned, the studs land between.
##
## It is put down the way one part is. The pointer names a stud, the group
## drops onto whatever is highest under any of its parts, and a side face
## pushes it out until its near edge touches the face rather than sinking
## into it.
class_name Carry
extends Node3D

const GHOST_SHADER := preload("res://src/render/ghost.gdshader")

## What Copy took, kept for as long as the app is open: a model opened
## after copying can still be pasted into, which is how a piece is moved
## from one model to another.
static var clipboard: Array = []
## The lights and views of each sub-model the clipboard's parts are in
## (BrickWorld.section_lines, by definition), as Copy found them: a paste
## puts them back where the model it lands in has none (Assemblies.lines_held).
static var clipboard_lines: Dictionary = {}
## And where the frame those are in stands for each copy copied, by its path
## (BrickWorld.section_frames), so a paste puts them where the copy it puts
## down stands (Assemblies.frames_held).
static var clipboard_frames: Dictionary = {}
## And what the copies copied whole hold that is not on the baseplate (parts
## on their way, parts the catalogue lacks: ModelStore._held_carried), each
## where it stands, so the copy a paste puts down holds them too.
static var clipboard_held: Array = []

var library: PartLibrary

## The parts held, each {part, color, at, group, pivot} with ``at`` in the
## carry's own frame (see the class note) and ``pivot`` where that frame
## was in the world when they were gathered.
var items: Array = []
## Quarter turns about the vertical, as R gives them.
var turns: int = 0
## Whether the parts came off the model (a move, which Escape undoes) or
## are a copy (which Escape simply puts away).
var lifted: bool = false
## Whether another copy stays in hand after one is put down: a clone and a
## duplicate (Ctrl-D) go on being put, as Studio's Clone does, until Esc or
## a right click, as a part from the bin always has; a paste and a move go
## once. Five window bays took ten clicks (docs/APP_UX.md, A6).
var repeats: bool = false
## What a paste carries of its sub-models' lights and views (clipboard_lines):
## put down, its step takes them (Builder._put_carried). Nothing else held
## carries any.
var lines: Dictionary = {}
## And the frame each is in (clipboard_frames).
var frames: Dictionary = {}
## And what its copies hold that is not on the baseplate (clipboard_held).
var held: Array = []
## A model brought into this one whole (ModelStore.held_from): its parts go
## down under the names they were read with, each in the step its author
## gave it, and each copy of a sub-model in it, by its path in hand, on in
## the step [member brought_units] says (the whole's after the model's
## last: Builder._bring_steps). [member brought_data] is what else it
## brings: its own copy's path ("root"), its steps' looks and its sections'
## file names (Builder._brought_down), and whether the model it goes into is
## someone else's file with no steps ("host_flat", Builder._bring_steps).
var brought: bool = false
var brought_units: Dictionary = {}
var brought_data: Dictionary = {}

var _ghost: Node3D
## The ghost's one material: its "valid" says whether the group fits.
var _materials: Array[ShaderMaterial] = []
## Collision cover of every item at turn n, framed at _reference: an array
## per turn of [part boxes per item], filled on first use.
var _covers: Dictionary = {}
var _frame: Transform3D = Transform3D.IDENTITY
var _valid: bool = false
var _aimed: bool = false

## Where the cover is worked out from: a point of the same kind as the
## pivot (a stud centre or corner), on cell 0. Any other place the group
## can go is this one moved by whole cells.
var _reference := Vector3(10.0, 0.0, 10.0)


func _ready() -> void:
	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)


# -- what is held -----------------------------------------------------------


## The parts of these bricks, in a frame of their own, ready to hold, and
## the line each was read from, which a lift puts back down with it
## (Builder._put_carried).
static func gather(world: BrickWorld, from: PartLibrary,
		ids: Array) -> Array:
	var placed: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and from.mesh_for(brick.part_id) != null:
			placed.append({"part": brick.part_id, "color": brick.color_code,
				"at": brick.transform, "group": brick.group, "unit": brick.unit,
				"step": brick.step, "origin": brick.origin})
	return framed(placed, from)


## Parts given where they stand in the model ({part, color, at, ...}, ``at``
## in the world), each put in a frame of their own about their pivot
## ([method pivot_of]), with the pivot kept as ``pivot``, and where it stood
## when it was first gathered as ``was`` (what [method moved] measures
## from, however it is turned, typed or framed again since).
static func framed(placed: Array, from: PartLibrary) -> Array:
	if placed.is_empty():
		return []
	var box := AABB()
	var first: bool = true
	for item: Dictionary in placed:
		var part: Lbm.PartMesh = from.mesh_for(str(item["part"]))
		if part == null:
			continue
		var here: AABB = ((item["at"] as Transform3D) * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	var pivot: Vector3 = _pivot_in(box)
	var out: Array = []
	for item: Dictionary in placed:
		var at: Transform3D = item["at"]
		var mine: Dictionary = item.duplicate()
		mine["at"] = Transform3D(at.basis, at.origin - pivot)
		mine["pivot"] = pivot
		if not mine.get("was") is Transform3D:
			mine["was"] = at
		out.append(mine)
	return out


## The point nearest the middle of these bricks that they can turn about
## and stay on the studs, at their bottom.
##
## Stud centres are at odd multiples of 10 LDU across the ground (see
## BrickLattice.snap_to_studs) and stud corners at multiples of 20; either
## serves, and the nearer is taken, so a 2 x 4 turns about its own middle.
## The bottom is kept to a whole cell so that moving the frame by whole
## cells moves every cover exactly.
static func pivot_of(bricks: Array, from: PartLibrary) -> Vector3:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in bricks:
		var part: Lbm.PartMesh = from.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return _pivot_in(box)


static func _pivot_in(box: AABB) -> Vector3:
	var middle: Vector3 = box.get_center()
	var flat := Vector2(middle.x, middle.z)
	var centre := Vector2(_on_phase(middle.x, 10.0), _on_phase(middle.z, 10.0))
	var corner := Vector2(_on_phase(middle.x, 0.0), _on_phase(middle.z, 0.0))
	var best: Vector2 = centre if flat.distance_to(centre) < flat.distance_to(corner) - 0.01 \
		else corner
	return Vector3(best.x, round(box.position.y / BrickLattice.CELL) * BrickLattice.CELL, best.y)


## The nearest of the points a whole number of studs from ``phase``.
static func _on_phase(value: float, phase: float) -> float:
	return round((value - phase) / BrickLattice.STUD) * BrickLattice.STUD + phase


## Whether a pivot is a stud centre (10) or a stud corner (0).
static func phase_of(pivot: Vector3) -> float:
	return 0.0 if is_zero_approx(fposmod(pivot.x, BrickLattice.STUD)) else 10.0


## Take these parts in hand.
func hold(parts: Array, came_off_the_model: bool) -> void:
	items = parts.duplicate(true)
	turns = 0
	lifted = came_off_the_model
	lines = {}
	frames = {}
	held = []
	brought = false
	brought_units = {}
	brought_data = {}
	_pinned = false
	_base = []
	var phase: float = phase_of(items[0].get("pivot", Vector3(10, 0, 10))) \
		if not items.is_empty() else 10.0
	_reference = Vector3(phase, 0.0, phase)
	_covers.clear()
	_aimed = false
	_valid = false
	_build_ghost()


## Let go of whatever is held, without putting it anywhere.
func drop() -> void:
	items = []
	lifted = false
	repeats = false
	lines = {}
	frames = {}
	held = []
	brought = false
	brought_units = {}
	brought_data = {}
	_pinned = false
	_base = []
	_covers.clear()
	_aimed = false
	_valid = false
	if _ghost != null:
		_ghost.visible = false
		for child: Node in _ghost.get_children():
			_ghost.remove_child(child)
			child.free()


func is_holding() -> bool:
	return not items.is_empty()


func turn(by: int) -> void:
	turns = posmod(turns + by, 4)
	if _ghost != null:
		_ghost.transform = _frame_at(_frame.origin)


func count() -> int:
	return items.size()


## The parts in hand turned by [param turn] about where they turn round
## (R's quarters with it), and framed again from where that leaves them,
## so the group still stands on a stud point at its bottom: what had no
## room to turn on the model comes into hand turned (EditVerbs.turn_by).
func reshape(turn: Basis) -> void:
	var pivot: Vector3 = items[0].get("pivot", Vector3.ZERO) if not items.is_empty() \
		else Vector3.ZERO
	var about := Transform3D(turn * Basis(Vector3.UP, turns * PI * 0.5), pivot)
	var placed: Array = []
	for item: Dictionary in items:
		var mine: Dictionary = item.duplicate()
		var at: Transform3D = about * (item["at"] as Transform3D)
		mine["at"] = Transform3D(at.basis.orthonormalized(), at.origin)
		placed.append(mine)
	var keep: bool = repeats
	hold(framed(placed, library), lifted)
	repeats = keep


# -- typed: held where it is, moved by a number --------------------------------


## While a number is typed (TypedEntry) the group stays where its ghost was
## when the typing began, whatever the pointer does: its frame is kept, and
## the parts are moved inside it by what is typed. These are the parts as
## they were then.
var _pinned: bool = false
var _base: Array = []


## Keep the group where its ghost stands now. False when it stands nowhere.
func pin() -> bool:
	if not is_aimed():
		return false
	_pinned = true
	_base = items.duplicate(true)
	return true


func is_pinned() -> bool:
	return _pinned


## The parts as held before anything was typed: what goes back in hand for
## the next copy.
func base_items() -> Array:
	return _base if _pinned else items


## What is in hand is a model brought in whole ([param held], ModelStore
## .held_from's): put down, it goes in as read ([member brought]), with its
## sub-models' own lines and their frames, and what it holds that is not
## shown.
func bring(held: Dictionary) -> void:
	brought = true
	brought_units = held["units"]
	brought_data = {"root": held["root"], "looks": held["looks"], "files": held["files"],
		"host_flat": bool(held.get("host_flat", false))}
	lines = held["lines"]
	frames = held["frames"]
	self.held = held["held"]


## Stop keeping it: the ghost follows the pointer again, the parts as they
## were before the typing.
func unpin() -> void:
	if not _pinned:
		return
	_pinned = false
	items = _base
	_base = []
	_covers.clear()
	_build_ghost()
	_aimed = false
	_valid = false


## The group, kept where it was pinned, moved in the world by [param by]
## (turned about any point, moved any amount, to the thousandth of an LDU):
## shown there, and whether it may go down there. Its covers are worked out
## for the parts where they now are, and moved by whole cells to the frame
## as an aimed group's are, so a part off the lattice is as exact here.
func show_moved(by: Transform3D, lattice: BrickLattice, builder: Builder) -> bool:
	if not _pinned:
		return false
	var inside: Transform3D = _frame.affine_inverse() * by * _frame
	items = []
	for item: Dictionary in _base:
		var mine: Dictionary = item.duplicate()
		var at: Transform3D = inside * (item["at"] as Transform3D)
		mine["at"] = Builder._tidy(Transform3D(at.basis.orthonormalized(), at.origin),
			BrickLattice.is_square_to_grid(at.basis))
		items.append(mine)
	_covers.clear()
	_build_ghost()
	_stand(lattice, builder)
	return _valid


## Put the group back where it was lifted from, its ghost there: where a
## selection turned on the model is taken into hand to type its turn.
func stand_where_lifted(lattice: BrickLattice, builder: Builder) -> void:
	if items.is_empty():
		return
	turns = 0
	_frame = _frame_at(items[0].get("pivot", _reference))
	_stand(lattice, builder)


## Whether the group fits where its frame is now, and its ghost shown there.
func _stand(lattice: BrickLattice, builder: Builder) -> void:
	var covers: Array = _covers_for(builder)
	var whole: PackedInt32Array = covers[1]
	var shift := Vector3i(
		roundi((_frame.origin.x - _reference.x) / BrickLattice.CELL),
		roundi(_frame.origin.y / BrickLattice.CELL),
		roundi((_frame.origin.z - _reference.z) / BrickLattice.CELL))
	_valid = not whole.is_empty() and _lowest(whole) + shift.y >= Builder.GROUND_CELL \
		and not lattice.collides_moved(whole, covers[3], covers[4], shift)
	_aimed = true
	_ghost.transform = _frame
	_ghost.visible = true
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("valid", _valid)


## The box round the parts as they stood when pinned, moved in the world
## by [param by].
func bounds_moved(by: Transform3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for item: Dictionary in base_items():
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null:
			continue
		var here: AABB = ((by * _frame * (item["at"] as Transform3D)) * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box


## Where the group turns round in the world: its frame's origin.
func pivot() -> Vector3:
	return _frame.origin


# -- aiming -----------------------------------------------------------------


## Where the group would go for a ray from the camera, and whether it can.
## Returns the brick under the pointer, as the builder's own aim does.
func aim(lattice: BrickLattice, builder: Builder, origin: Vector3,
		direction: Vector3) -> int:
	if items.is_empty():
		return 0
	# Asked again with nothing changed (the pointer still, a frame after a
	# paste aimed it): as it was. Each look at a group as big as Orthanc
	# is a quarter of a second.
	var asked: Array = [origin, direction, turns, lattice.revision, builder.snap_across,
		_pinned]
	if asked == _last_asked and _aimed:
		return _last_hit
	_last_asked = asked
	_last_hit = _aim(lattice, builder, origin, direction)
	return _last_hit


## What [method aim] was last asked, and what it said.
var _last_asked: Array = []
var _last_hit: int = 0


func _aim(lattice: BrickLattice, builder: Builder, origin: Vector3,
		direction: Vector3) -> int:
	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	# Kept where it is while a number is typed.
	if _pinned:
		return hit.brick_id
	var target: Vector3
	if hit.is_valid():
		target = BrickLattice.to_ldu(hit.adjacent())
	else:
		var ground := Plane(Vector3.UP, Builder.GROUND_CELL * BrickLattice.CELL)
		var landing: Variant = ground.intersects_ray(origin, direction)
		if landing == null:
			_ghost.visible = false
			_aimed = false
			_valid = false
			return 0
		target = landing
	var covers: Array = _covers_for(builder)
	var whole: PackedInt32Array = covers[1]
	if whole.is_empty():
		# Nothing with a shape yet: parts still on their way over the
		# network have no cover to stand on anything with.
		_ghost.visible = false
		_aimed = false
		_valid = false
		return hit.brick_id
	var at := Vector3(_on_phase(target.x, _reference.x), 0.0,
		_on_phase(target.z, _reference.z))
	# A finer snap than a stud, from the toolbar: whole steps from where
	# it was, rather than whole studs.
	if builder.snap_across < BrickLattice.STUD - 0.01:
		var step: float = builder.snap_across
		at = Vector3(_reference.x + snappedf(target.x - _reference.x, step), 0.0,
			_reference.z + snappedf(target.z - _reference.z, step))

	# Against a wall, out from it until the near edge meets the face.
	# Centred on the cell beside the face, a group wider than a stud
	# would be half inside the wall and refused for it.
	if hit.is_valid() and hit.normal.y == 0:
		at = _out_from(at, whole, hit)

	var shift := Vector3i(
		roundi((at.x - _reference.x) / BrickLattice.CELL), 0,
		roundi((at.z - _reference.z) / BrickLattice.CELL))
	# Down onto whatever is highest under any of its parts: asked of its
	# footing, which rests as the whole does.
	var rise: int = lattice.rise_onto(covers[2], Builder.GROUND_CELL, shift.x, shift.z)
	# A side face keeps the height it implies, as a single part does, to
	# the plate: a whole group two LDU off every course reads as a fault.
	if hit.is_valid() and hit.normal.y == 0:
		var level: int = BrickLattice._floor_div(hit.adjacent().y,
			BrickLattice.CELLS_PER_PLATE) * BrickLattice.CELLS_PER_PLATE
		rise = maxi(rise, level - _lowest(whole))
	# Never down a stud past its foot, where a cover under it stops short of
	# its top (a cone's): asked of the parts it rests on, whole cells up.
	var resting: Array = []
	var trial: Transform3D = _frame_at(Vector3(at.x, rise * BrickLattice.CELL, at.z))
	for k: int in (covers[5] as PackedInt32Array):
		resting.append([str(items[k]["part"]), trial * (items[k]["at"] as Transform3D)])
	var lift: float = builder.stud_feet_lift(resting)
	if lift > 0.0:
		rise += ceili((lift - 0.01) / BrickLattice.CELL)
	shift.y = rise

	_frame = _frame_at(Vector3(at.x, rise * BrickLattice.CELL, at.z))
	_valid = not lattice.collides_moved(whole, covers[3], covers[4], shift)
	_aimed = true
	_ghost.transform = _frame
	_ghost.visible = true
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("valid", _valid)
	return hit.brick_id


## Pushed out of the face it was aimed at by whole studs, far enough that
## nothing of it is on the wall's side of the face.
func _out_from(at: Vector3, whole: PackedInt32Array,
		hit: BrickLattice.Hit) -> Vector3:
	var axis: int = 0 if hit.normal.x != 0 else 2
	var way: int = hit.normal.x if axis == 0 else hit.normal.z
	# The face, in cells: the near side of the cell beside it.
	var face: int = hit.adjacent()[axis] if way > 0 else hit.adjacent()[axis] + 1
	var offset: int = roundi((at[axis] - _reference[axis]) / BrickLattice.CELL)
	var lo: int = 1 << 30
	var hi: int = -(1 << 30)
	var n: int = 0
	while n < whole.size():
		lo = mini(lo, whole[n + axis] + offset)
		hi = maxi(hi, whole[n + 3 + axis] + offset)
		n += 6
	var past: int = (face - lo) if way > 0 else (hi - face)
	if past <= 0:
		return at
	var studs: int = ceili(float(past) / BrickLattice.CELLS_PER_STUD)
	var out: Vector3 = at
	out[axis] += way * studs * BrickLattice.STUD
	return out


static func _lowest(packed: PackedInt32Array) -> int:
	var lo: int = 1 << 30
	var n: int = 0
	while n < packed.size():
		lo = mini(lo, packed[n + 1])
		n += 6
	return lo


func _frame_at(origin: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turns * PI * 0.5), origin)


## For the current turn, at _reference, worked out once per turn: [each
## item's cover, all of them together, their footing (the lowest box over
## each run of columns, which rests where all of them do: what
## BrickLattice.rise_onto reads of them), their bound, whether none of them
## is empty along an axis, the items the footing is of]. The bound and the
## two after it are what every aim asked of all the boxes again, a quarter
## of a second a move for all of Orthanc in hand (bigmodels, 2026-10-30).
func _covers_for(builder: Builder) -> Array:
	if _covers.has(turns):
		return _covers[turns]
	var frame: Transform3D = _frame_at(_reference)
	var each: Array = []
	var whole := PackedInt32Array()
	var owner := PackedInt32Array()     ## each box's item
	for k: int in items.size():
		var item: Dictionary = items[k]
		var packed: PackedInt32Array = builder.boxes_for(
			library.mesh_for(str(item["part"])), frame * (item["at"] as Transform3D))
		each.append(packed)
		whole.append_array(packed)
		for _box: int in packed.size() / 6:
			owner.append(k)
	var lowest: Dictionary = {}
	var lowest_of: Dictionary = {}      ## key -> the item whose box it is
	var n: int = 0
	while n < whole.size():
		var key := Vector4i(whole[n], whole[n + 2], whole[n + 3], whole[n + 5])
		if whole[n + 1] < int(lowest.get(key, 1 << 30)):
			lowest[key] = whole[n + 1]
			lowest_of[key] = owner[n / 6]
		n += 6
	var footing := PackedInt32Array()
	footing.resize(lowest.size() * 6)
	n = 0
	for key: Vector4i in lowest:
		var bottom: int = lowest[key]
		footing[n] = key.x
		footing[n + 1] = bottom
		footing[n + 2] = key.y
		footing[n + 3] = key.z
		footing[n + 4] = bottom + 1
		footing[n + 5] = key.w
		n += 6
	var under: Dictionary = {}
	for key: Vector4i in lowest_of:
		under[lowest_of[key]] = true
	var all: Array = [each, whole, footing, BrickLattice._bound_of(whole),
		BrickLattice._plain(whole), PackedInt32Array(under.keys())]
	_covers[turns] = all
	return all


func is_aimed() -> bool:
	return _aimed and _ghost != null and _ghost.visible


func can_place() -> bool:
	return is_aimed() and _valid


func hide_ghost() -> void:
	_aimed = false
	_valid = false
	if _ghost != null:
		_ghost.visible = false


## Where each part goes if put down now: [{part, color, at, group, unit,
## step, origin}] in the world, and the cover each occupies. The copy a part was in
## goes with it: without it a part moved in a sub-model's second copy went
## into its first, and one duplicated inside a copy within another into a
## new copy of the outermost (keeptext2).
## How the parts held are moved from where they were gathered to where
## [method placements] puts them now: where the first is put against where
## it stood when gathered (``was``), the group moved as one. What a paste's
## and a move's sub-model lines are carried by (Assemblies.lines_pasted,
## frames_carried). Up to 2026-11-11 it was the carry's frame after the pivot
## alone, and missed what a typed move or a turn did to the parts inside it:
## a moved copy's light stayed where it had been (lights_probe, pcfix).
func moved() -> Transform3D:
	if items.is_empty():
		return Transform3D.IDENTITY
	var first: Dictionary = items[0]
	if first.get("was") is Transform3D:
		return _frame * (first["at"] as Transform3D) * (first["was"] as Transform3D).affine_inverse()
	var pivot: Vector3 = first["pivot"] if first.get("pivot") is Vector3 else Vector3.ZERO
	return _frame * Transform3D(Basis.IDENTITY, -pivot)


## Whether the group, where it was last aimed, stands on the ground: its
## lowest cell on the floor's, on no part (AppTools._into_spot). Its parts'
## drawn bottoms say less: a tyre's is a little over the floor it stands on.
func stands_on_ground(builder: Builder) -> bool:
	var whole: PackedInt32Array = _covers_for(builder)[1]
	return _aimed and not whole.is_empty() \
		and _lowest(whole) + roundi(_frame.origin.y / BrickLattice.CELL) == Builder.GROUND_CELL


func placements(builder: Builder) -> Array:
	var covers: Array = _covers_for(builder)
	var shift := Vector3i(
		roundi((_frame.origin.x - _reference.x) / BrickLattice.CELL),
		roundi(_frame.origin.y / BrickLattice.CELL),
		roundi((_frame.origin.z - _reference.z) / BrickLattice.CELL))
	var out: Array = []
	for n: int in items.size():
		var item: Dictionary = items[n]
		out.append({
			"part": item["part"], "color": item["color"],
			"group": item.get("group", ""),
			"unit": item.get("unit", ""),
			"step": item.get("step", -1),
			"origin": item.get("origin", ""),
			"at": _frame * (item["at"] as Transform3D),
			"boxes": BrickLattice.moved_by(covers[0][n], shift),
		})
	return out


# -- the ghost --------------------------------------------------------------


## The group drawn as instances, a MultiMesh for each surface of each part
## and every part's colour its instance's, in the carry's own frame:
## turning it is a change of transform, not a rebuild.
##
## A node per part was the obvious way, and a whole floor of a building
## duplicated is several hundred draw calls following the pointer. One
## mesh made of every part's triangles was the next, and copying them
## (SurfaceTool.append_from, which reads each part's arrays back off the
## graphics card) held the window 4.3 s for a paste of all of Orthanc
## (bigmodels, 2026-10-30). The model itself is drawn as instances
## (BrickWorld), with a draw call for each part's surface, not each part.
func _build_ghost() -> void:
	for child: Node in _ghost.get_children():
		_ghost.remove_child(child)
		child.free()
	if _materials.is_empty():
		var material := ShaderMaterial.new()
		material.shader = GHOST_SHADER
		material.set_shader_parameter("instanced", true)
		material.set_shader_parameter("linearise", BrickWorld._linearise_colors())
		_materials.append(material)
	_materials[0].set_shader_parameter("valid", true)
	# Surface mesh -> [mesh, where each instance is, its colour].
	var batches: Dictionary = {}
	var box := AABB()
	var first: bool = true
	for item: Dictionary in items:
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null:
			continue
		var at: Transform3D = item["at"]
		var here: AABB = (at * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
		for s: int in part.surface_count():
			var code: int = part.surface_colors[s] if s < part.surface_colors.size() \
				else Lbm.COLOR_INHERIT
			if code == Lbm.COLOR_INHERIT:
				code = int(item["color"])
			var colour: PartLibrary.BrickColor = library.color(code)
			var mesh: ArrayMesh = part.surfaces[s]
			var batch: Array = batches.get(mesh, [])
			if batch.is_empty():
				batch = [mesh, [], []]
				batches[mesh] = batch
			(batch[1] as Array).append(at)
			(batch[2] as Array).append(colour.shown if colour != null else Color.WHITE)
	for batch: Array in batches.values():
		var places: Array = batch[1]
		var colours: Array = batch[2]
		# Laid out as MultiMesh.buffer is: a transform's three rows, a colour.
		var floats := PackedFloat32Array()
		floats.resize(places.size() * 16)
		for n: int in places.size():
			var at: Transform3D = places[n]
			var b: Basis = at.basis
			var shown: Color = colours[n]
			var o: int = n * 16
			floats[o] = b.x.x
			floats[o + 1] = b.y.x
			floats[o + 2] = b.z.x
			floats[o + 3] = at.origin.x
			floats[o + 4] = b.x.y
			floats[o + 5] = b.y.y
			floats[o + 6] = b.z.y
			floats[o + 7] = at.origin.y
			floats[o + 8] = b.x.z
			floats[o + 9] = b.y.z
			floats[o + 10] = b.z.z
			floats[o + 11] = at.origin.z
			floats[o + 12] = shown.r
			floats[o + 13] = shown.g
			floats[o + 14] = shown.b
			floats[o + 15] = 1.0
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = batch[0]
		multimesh.instance_count = places.size()
		multimesh.buffer = floats
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = multimesh
		drawn.material_override = _materials[0]
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A part's surface carries its own box (Lbm), which the MultiMesh
		# would measure from: the group's, so it is not culled away.
		drawn.custom_aabb = box
		_ghost.add_child(drawn)
	_ghost.visible = false


# -- the clipboard as LDraw -------------------------------------------------


## The held parts as LDraw lines, which any LDraw tool pastes: LDCad,
## LeoCAD, a text file. Written where they were in the model, so a paste
## into another tool puts them where they came from.
static func as_ldraw(parts: Array) -> String:
	var lines := PackedStringArray()
	for item: Dictionary in parts:
		var pivot: Vector3 = item.get("pivot", Vector3.ZERO)
		var at: Transform3D = item["at"]
		var colour: int = int(item["color"])
		lines.append("1 %s %s %s.dat" % [
			("0x%07X" % colour) if LdrModel.is_direct_colour(colour) else str(colour),
			LdrModel._line_numbers(Transform3D(at.basis, at.origin + pivot)),
			str(item["part"])])
	return "\n".join(lines) + "\n"


## Parts read back from LDraw text, if it is any: what another tool put on
## the clipboard. Empty when the text holds no part lines this library has.
static func from_ldraw(text: String, from: PartLibrary) -> Array:
	if not text.contains("1 ") or text.length() > 4_000_000:
		return []
	var model: LdrModel = LdrModel.parse(text, "clipboard")
	if model == null:
		return []
	var placed: Array = []
	for placement: LdrModel.Placement in model.flatten(from.parts):
		if from.parts.has(placement.part_id):
			placed.append(placement)
	var out: Array = []
	for placement: LdrModel.Placement in placed:
		out.append({"part": placement.part_id, "color": placement.color_code,
			"at": placement.transform, "group": placement.group})
	return framed(out, from)


# -- what rests on it ---------------------------------------------------------


## How many parts a look for what rests on a dragged part asks about before it
## stops: what it has not finished with stays where it is.
const RIDERS_MOST := 1500


## The parts resting on [param moving] and held by nothing else: what a part
## dragged in the view carries with it (Brickyard's drag; docs/APP_UX7.md,
## carryrest). A drag moved the part alone and left the bricks on it hanging
## in the air, a wall's whole upper courses floating where the brick under
## them had been.
##
## A part rests on it when its underside sits on the top of one of [param
## moving]. It comes with them, and so does all it is joined to (studs above
## and below, and a side's studs, as Select by, Everything connected reads
## them: SelectBy._joined_to) leaving [param moving] out, however far, unless
## any of that reaches a part that stays: one reaching lower than the top of
## [param moving] (held from below, not from above), the scenery, a locked or
## a hidden part. So the bricks stacked on a 2 x 4 come with it, a
## plate across it and a brick beside it keeps the plate and all on it where
## they are, and what the 2 x 4 itself sits on never comes. A sub-assembly
## comes whole or not at all ([param takes]: Builder.takes, empty for a locked
## part).
##
## Returns {"riders": the ids, "cut": true when the look stopped at
## [constant RIDERS_MOST] parts with some of it unread}.
static func riders(world: BrickWorld, lattice: BrickLattice, moving: Array,
		scenery: Dictionary, takes: Callable, locked: Dictionary) -> Dictionary:
	var held: Dictionary = {}
	# How low a part resting on them may reach: the lowest of their tops, less
	# a stud's height, which a part on its studs reaches down round them. A
	# pin or an axle through one of them reaches lower and is no part on it.
	var level: int = 1 << 30
	for brick_id: Variant in moving:
		if world.get_brick(int(brick_id)) != null:
			held[int(brick_id)] = true
			var bound: PackedInt32Array = lattice._bounds.get(int(brick_id), PackedInt32Array())
			if not bound.is_empty():
				level = mini(level, bound[4] - STUD_CELLS)
	# Each part looked at -> whether it stays (true) or comes (false).
	var stays: Dictionary = {}
	var out: Array = []
	var asked: Array = [0]
	for brick_id: int in held:
		for other: int in lattice.blockers_boxes(_slab(lattice.boxes_of(brick_id), true),
				brick_id, held):
			if stays.has(other):
				continue
			out.append_array(_resting(world, lattice, other, held, level, scenery, takes,
				locked, stays, asked))
	out.sort()
	return {"riders": out, "cut": asked[0] > RIDERS_MOST}


## A stud's height in cells (4 LDU).
const STUD_CELLS := 2


## Everything joined to [param from] but [param held], if none of it stays
## ([method riders]); empty if any does. Each part read is noted in [param
## stays], so the next look from another part on top reads no part twice.
##
## Read by what is above and below each part first, the lowest first, and
## only once that finds nothing that stays, by what is beside each: a side's
## look is two of every three a part costs (SelectBy._joined_to), and most
## looks end at the first part reaching too low. From one part of the
## Millennium Falcon (10179) the first look took 3.1 s, every joint asked of
## every part, down to the ground through its hull and legs.
static func _resting(world: BrickWorld, lattice: BrickLattice, from: int, held: Dictionary,
		level: int, scenery: Dictionary, takes: Callable, locked: Dictionary,
		stays: Dictionary, asked: Array) -> Array:
	var found: Dictionary = {}
	var queue: Array = [from]
	var staying: bool = false
	# Parts whose sub-assembly is asked for already, and whose sides are.
	var units: Dictionary = {}
	var sides: Dictionary = {}
	var select_by: GDScript = null
	var lowest_last: Callable = func(a: int, b: int) -> bool:
		return _bottom(lattice, a) > _bottom(lattice, b)
	while not staying:
		while not queue.is_empty() and not staying:
			var here: int = queue.pop_back()
			if found.has(here) or held.has(here):
				continue
			if stays.has(here):
				# Read already by another look: one that stays, as this would.
				staying = bool(stays[here])
				continue
			found[here] = true
			asked[0] += 1
			if asked[0] > RIDERS_MOST or _stays_put(world, lattice, here, level, scenery,
					locked):
				staying = true
				break
			# A sub-assembly is one thing: the rest of it with it, all of it
			# looked at before any is gone into.
			if not units.has(here):
				var whole: PackedInt64Array = takes.call(here) if takes.is_valid() \
					else PackedInt64Array([here])
				staying = whole.is_empty()
				for other: int in whole:
					units[other] = true
					if held.has(other) or found.has(other):
						continue
					if _stays_put(world, lattice, other, level, scenery, locked):
						staying = true
						break
					queue.append(other)
				if staying:
					break
			# What it is joined to above and below, the lowest asked first.
			var boxes: PackedInt32Array = lattice.boxes_of(here)
			var next: Array = Array(lattice.blockers_boxes(
				_slab(boxes, false) + _slab(boxes, true), here, held))
			next.sort_custom(lowest_last)
			for other: int in next:
				if not found.has(other):
					queue.append(other)
		if staying:
			break
		# Nothing that stays above or below: then what is joined at the sides,
		# as Select by reads them. Reached through Later: Carry is compiled
		# with the first screen, and SelectBy is not (tests/test_later.py).
		if select_by == null:
			select_by = Later.script(&"SelectBy")
		for brick_id: int in found:
			if sides.has(brick_id):
				continue
			sides[brick_id] = true
			for other: int in select_by._joined_to(world, lattice, brick_id, [], held):
				if not found.has(other):
					queue.append(other)
		if queue.is_empty():
			break
	for brick_id: int in found:
		stays[brick_id] = staying
	if staying:
		return []
	return found.keys()


## The lowest cell a part reaches.
static func _bottom(lattice: BrickLattice, brick_id: int) -> int:
	var bound: PackedInt32Array = lattice._bounds.get(brick_id, PackedInt32Array())
	return bound[1] if not bound.is_empty() else -(1 << 30)


## Whether a part stays where it is whatever is dragged: it reaches lower than
## [param level] (what the dragged part stands on does, and what is beside it),
## it stands on the ground, it is the scenery, or it is locked or hidden.
static func _stays_put(world: BrickWorld, lattice: BrickLattice, brick_id: int,
		level: int, scenery: Dictionary, locked: Dictionary) -> bool:
	if scenery.has(brick_id) or locked.has(brick_id) or lattice.unseen.has(brick_id):
		return true
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or brick.hidden:
		return true
	var bottom: int = _bottom(lattice, brick_id)
	return bottom < level or bottom <= Builder.GROUND_CELL


## The one-cell slab on top of each box ([param up]), or under it, inset a
## cell round its edges where there is room, as SelectBy._shell's are: two
## parts meeting only at an edge are not one on the other.
static func _slab(boxes: PackedInt32Array, up: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(boxes.size())
	var n: int = 0
	while n < boxes.size():
		for k: int in [0, 2]:
			var low: int = boxes[n + k]
			var high: int = boxes[n + k + 3]
			if high - low > 2:
				low += 1
				high -= 1
			out[n + k] = low
			out[n + k + 3] = high
		out[n + 1] = boxes[n + 4] if up else boxes[n + 1] - 1
		out[n + 4] = out[n + 1] + 1
		n += 6
	return out
