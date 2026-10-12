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

var _ghost: MeshInstance3D
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
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


# -- what is held -----------------------------------------------------------


## The parts of these bricks, in a frame of their own, ready to hold.
static func gather(world: BrickWorld, from: PartLibrary,
		ids: Array) -> Array:
	var bricks: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and from.mesh_for(brick.part_id) != null:
			bricks.append(brick)
	if bricks.is_empty():
		return []
	var pivot: Vector3 = pivot_of(bricks, from)
	var out: Array = []
	for brick: BrickWorld.Brick in bricks:
		out.append({
			"part": brick.part_id,
			"color": brick.color_code,
			"at": Transform3D(brick.transform.basis, brick.transform.origin - pivot),
			"group": brick.group,
			"pivot": pivot,
		})
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
	_covers.clear()
	_aimed = false
	_valid = false
	if _ghost != null:
		_ghost.visible = false
		_ghost.mesh = null


func is_holding() -> bool:
	return not items.is_empty()


func turn(by: int) -> void:
	turns = posmod(turns + by, 4)
	if _ghost != null:
		_ghost.transform = _frame_at(_frame.origin)


func count() -> int:
	return items.size()


# -- aiming -----------------------------------------------------------------


## Where the group would go for a ray from the camera, and whether it can.
## Returns the brick under the pointer, as the builder's own aim does.
func aim(lattice: BrickLattice, builder: Builder, origin: Vector3,
		direction: Vector3) -> int:
	if items.is_empty():
		return 0
	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
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
	var whole: PackedInt32Array = covers[covers.size() - 1]
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
	# Down onto whatever is highest under any of its parts.
	var rise: int = Builder.GROUND_CELL - _lowest(whole)
	var item_covers: Array = covers[0]
	for packed: PackedInt32Array in item_covers:
		var n: int = 0
		while n < packed.size():
			var under: int = lattice.surface_under(
				packed[n] + shift.x, packed[n + 2] + shift.z,
				packed[n + 3] + shift.x, packed[n + 5] + shift.z,
				Builder.GROUND_CELL)
			rise = maxi(rise, under - packed[n + 1])
			n += 6
	# A side face keeps the height it implies, as a single part does, to
	# the plate: a whole group two LDU off every course reads as a fault.
	if hit.is_valid() and hit.normal.y == 0:
		var level: int = BrickLattice._floor_div(hit.adjacent().y,
			BrickLattice.CELLS_PER_PLATE) * BrickLattice.CELLS_PER_PLATE
		rise = maxi(rise, level - _lowest(whole))
	shift.y = rise

	_frame = _frame_at(Vector3(at.x, rise * BrickLattice.CELL, at.z))
	_valid = not lattice.collides_boxes(BrickLattice.moved_by(whole, shift))
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


## Each item's cover at _reference for the current turn, and all of them
## together as the last entry, worked out once per turn.
func _covers_for(builder: Builder) -> Array:
	if _covers.has(turns):
		return _covers[turns]
	var frame: Transform3D = _frame_at(_reference)
	var each: Array = []
	var whole := PackedInt32Array()
	for item: Dictionary in items:
		var packed: PackedInt32Array = builder.boxes_for(
			library.mesh_for(str(item["part"])), frame * (item["at"] as Transform3D))
		each.append(packed)
		whole.append_array(packed)
	var both: Array = [each, whole]
	_covers[turns] = both
	return both


func is_aimed() -> bool:
	return _aimed and _ghost != null and _ghost.visible


func can_place() -> bool:
	return is_aimed() and _valid


func hide_ghost() -> void:
	_aimed = false
	_valid = false
	if _ghost != null:
		_ghost.visible = false


## Where each part goes if put down now: [{part, color, at, group}] in the
## world, and the cover each occupies.
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
			"at": _frame * (item["at"] as Transform3D),
			"boxes": BrickLattice.moved_by(covers[0][n], shift),
		})
	return out


# -- the ghost --------------------------------------------------------------


## One mesh for the whole group, a surface per colour, in the carry's own
## frame: turning it is a change of transform, not a rebuild.
##
## A node per part was the obvious way, and a whole floor of a building
## duplicated is several hundred draw calls following the pointer.
func _build_ghost() -> void:
	var by_colour: Dictionary = {}
	for item: Dictionary in items:
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null:
			continue
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
	_materials.clear()
	for code: int in by_colour:
		var tool: SurfaceTool = by_colour[code]
		tool.commit(mesh)
		var material := ShaderMaterial.new()
		material.shader = GHOST_SHADER
		material.set_shader_parameter("tint", library.color(code).shown)
		material.set_shader_parameter("valid", true)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		_materials.append(material)
	_ghost.mesh = mesh
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
	if placed.is_empty():
		return []
	var box := AABB()
	var first: bool = true
	for placement: LdrModel.Placement in placed:
		var part: Lbm.PartMesh = from.mesh_for(placement.part_id)
		if part == null:
			continue
		var here: AABB = (placement.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	var pivot: Vector3 = _pivot_in(box)
	var out: Array = []
	for placement: LdrModel.Placement in placed:
		out.append({"part": placement.part_id, "color": placement.color_code,
			"at": Transform3D(placement.transform.basis,
				placement.transform.origin - pivot),
			"group": placement.group, "pivot": pivot})
	return out
