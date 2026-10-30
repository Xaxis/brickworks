## Split and Merge: a part made into smaller ones of its kind, or parts made
## into the fewest bigger ones (APP_UX2 gap 6, Studio's Alt+S and Alt+M).
##
## Split keeps Studio's rules (studiohelp 6482107372823): a plate, a brick
## or a tile into 1 x 1s of its kind; a 1 x 1 brick into three 1 x 1
## plates; a slope into the 1-wide slope of its angle, length and height; a
## curved slope into the 1-wide curved slope of its length.
##
## Merge goes further than Studio's. Studio merges once a press, into one
## part: five 1 x 2 plates in a 2 x 5 are refused, and a stack of plates
## becomes a brick only three 1 x 1s at a time. Here the selection is merged
## as far as it can be in one press. The plates, bricks and tiles of each
## colour are laid out as cells a stud across and a plate high, and the
## cells covered by the fewest real parts, biggest first, three plates high
## a brick, and only by parts LEGO made in that colour (PartInfo.colors).
## Where that is no fewer parts than were there, nothing changes there.
##
## Each new part stands where the old ones stood, to the LDU: a split's
## pieces on the studs the part had, a merge's parts in the cells the parts
## filled. So what was joined to them is joined to them still, and nothing
## new runs into anything: each is asked of the lattice first, and a part
## that would run into something is left as it was. One undo each.
class_name SplitMerge
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## How far off whole studs and plates a part may measure and still be read
## as them, LDU.
const NEAR := 0.5
## How much of a split's pieces may stand outside the part's own cover, and
## how much of the cover they must fill, as shares: a slope's stepped cover
## and its 1-wide one's differ by a few cells at the foot.
const OUTSIDE_MOST := 0.04
const FILLED_LEAST := 0.9

## The tables below were read for this library.
static var _for: PartLibrary = null
## Plain plates, bricks and tiles by id: [kind, studs along x, along z].
static var _plain: Dictionary = {}
## "Plate/1/2" (the fewer studs first) -> the ids of that size, the most
## used in real sets first.
static var _sized: Dictionary = {}
## Slopes by id: [the key of their 1-wide one, studs wide].
static var _slopes: Dictionary = {}
## "Slope/45/2/28" or "Curved/2/16" (angle, studs long, LDU high) -> the
## 1-wide slope real sets use most.
static var _one_wide: Dictionary = {}
## Part id -> its split, [[piece, its place in the part's own frame]], or
## [] for a part that does not split. Worked out once a part.
static var _splits: Dictionary = {}

static var _plain_name := RegEx.create_from_string(
	"^(Brick|Plate|Tile) +(\\d+) +x +(\\d+)( +with +Groove)?$")
## A slope's angle, studs long and studs wide, and a height or what its
## underside or studs are like after (75° slopes are named by their studs,
## hollow or solid); [method _fills] says whether two are the same shape.
static var _slope_name := RegEx.create_from_string(
	"^Slope Brick (\\d+(?:\\.\\d+)?) +(\\d+) +x +(\\d+)( +x +[\\d./ ]+)?" +
	"( with (Hollow|Solid|Open) Studs?| with Centre Tube| with (Symmetric|Asymmetric) Stud Holder)?$")
static var _curved_name := RegEx.create_from_string(
	"^Slope Brick Curved +(\\d+) +x +(\\d+)( +x +[\\d./ ]+)?$")


# -- the window's commands ------------------------------------------------------


## Split the selection (Alt+S), said on the status bar. Returns how many
## parts were split.
static func split(verbs: EditVerbs) -> int:
	var done: Dictionary = split_selection(verbs.builder)
	return _said(verbs, done)


## Merge the selection (Alt+M), said on the status bar. Returns how many
## parts were merged away.
static func merge(verbs: EditVerbs) -> int:
	var done: Dictionary = merge_selection(verbs.builder)
	return _said(verbs, done)


static func _said(verbs: EditVerbs, done: Dictionary) -> int:
	if int(done["changed"]) > 0:
		verbs.edited.call()
		verbs.aim_again.call()
	verbs.say.call(str(done["words"]))
	return int(done["changed"])


# -- split ----------------------------------------------------------------------


## Each selected part that splits, swapped for its pieces, as one step; the
## rest left selected as they were. {"changed": parts split, "made": pieces
## put down, "refused": parts that had no room, "words": what to say}.
static func split_selection(builder: Builder) -> Dictionary:
	_tables(builder.library)
	var world: BrickWorld = builder.world
	var ids: Array = _selected(builder)
	if ids.is_empty():
		return {"changed": 0, "made": 0, "refused": 0, "words": "select parts to split first"}
	var removes := PackedInt64Array()
	var adds: Array = []
	var refused: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var pieces: Array = split_of(builder.library, brick.part_id)
		if pieces.is_empty():
			continue
		var square: bool = BrickLattice.is_square_to_grid(brick.transform.basis)
		var put: Array = []
		for piece: Array in pieces:
			put.append({"part": piece[0], "color": brick.color_code,
				"at": Builder._tidy(brick.transform * (piece[1] as Transform3D), square),
				"path": Assemblies.path_of(brick), "step": brick.step})
		if not _room_for(builder, PackedInt64Array([brick_id]), put):
			refused += 1
			continue
		removes.append(brick_id)
		adds.append_array(put)
	if removes.is_empty():
		return {"changed": 0, "made": 0, "refused": refused, "words": "no room to split it there"
			if refused > 0 else "nothing selected splits: plates, bricks and tiles split into "
			+ "1 x 1s, a 1 x 1 brick into plates, slopes into 1-wide slopes"}
	var words: String = "split %s into %d" % [Builder._many(removes.size()), adds.size()]
	var made: PackedInt64Array = _swap(builder, ids, removes, adds, words)
	if refused > 0:
		words += " — %d had no room" % refused
	return {"changed": removes.size(), "made": made.size(), "refused": refused, "words": words}


## What [param part_id] splits into: [[piece id, its place in the part's
## frame]], or [] when it does not split (a 1 x 1 plate, or a part that is
## none of Studio's kinds). Each split is checked against the part itself
## before it is ever used ([method _fills]).
static func split_of(library: PartLibrary, part_id: String) -> Array:
	_tables(library)
	if _splits.has(part_id):
		return _splits[part_id]
	var pieces: Array = []
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info != null and not info.is_redirect():
		if _plain.has(part_id):
			pieces = _plain_split(library, info, _plain[part_id])
		elif _slopes.has(part_id):
			pieces = _slope_split(library, info, _slopes[part_id])
	_splits[part_id] = pieces
	return pieces


## Into 1 x 1s on its studs, or a 1 x 1 brick into three plates.
static func _plain_split(library: PartLibrary, info: PartLibrary.PartInfo, plain: Array) -> Array:
	var kind: String = plain[0]
	var across: int = plain[1]
	var along: int = plain[2]
	var stacked: bool = kind == "Brick" and across == 1 and along == 1
	if across * along == 1 and not stacked:
		return []
	var piece: String = _first_of("%s/1/1" % ("Plate" if stacked else kind))
	var into: PartLibrary.PartInfo = library.parts.get(piece)
	if into == null:
		return []
	var from: AABB = info.bounds
	var out: Array = []
	if stacked:
		for k: int in 3:
			out.append([piece, Transform3D(Basis.IDENTITY, Vector3(from.position.x - into.bounds.position.x,
				from.position.y + PLATE * k - into.bounds.position.y, from.position.z - into.bounds.position.z))])
	else:
		for i: int in across:
			for j: int in along:
				out.append([piece, Transform3D(Basis.IDENTITY, Vector3(
					from.position.x + STUD * i - into.bounds.position.x,
					from.position.y - into.bounds.position.y,
					from.position.z + STUD * j - into.bounds.position.z))])
	return out if _fills(library, info.id, out) else []


## Into the 1-wide slope of its kind, side by side across its width (its
## x), each turned the way the part slopes: tried as it is, then half a
## turn round, and kept only as the check finds it.
static func _slope_split(library: PartLibrary, info: PartLibrary.PartInfo, slope: Array) -> Array:
	var piece: String = str(_one_wide.get(slope[0], ""))
	var into: PartLibrary.PartInfo = library.parts.get(piece)
	var wide: int = slope[1]
	if into == null or wide < 2:
		return []
	var from: AABB = info.bounds
	if absf(from.size.x - STUD * wide) > NEAR or absf(from.size.z - into.bounds.size.z) > NEAR \
			or absf(from.size.y - into.bounds.size.y) > NEAR:
		return []
	for half: bool in [false, true]:
		var turn := Basis(Vector3.UP, PI) if half else Basis.IDENTITY
		var turned: AABB = Transform3D(turn, Vector3.ZERO) * into.bounds
		var out: Array = []
		for i: int in wide:
			out.append([piece, Transform3D(turn, Vector3(from.position.x + STUD * i - turned.position.x,
				from.position.y - turned.position.y, from.position.z - turned.position.z))])
		if _fills(library, info.id, out):
			return out
	return []


## Whether [param pieces] are [param part_id] in pieces: within its box,
## filling its cover and not each other, its studs each a piece's stud, and
## each place beneath it a stud goes into one of theirs. Turned the wrong
## way, a slope's pieces leave its cover's foot empty, or their studs and
## the places beneath them are at the other end.
##
## Within its box, not its cover: the 3 x 6 slope is a shell over a hollow
## its six 3 x 1s fill, with studs at its ends only, where theirs are on
## each, as Studio's split makes it.
static func _fills(library: PartLibrary, part_id: String, pieces: Array) -> bool:
	var whole: Lbm.PartMesh = library.mesh_for(part_id)
	if whole == null or whole.boxes.is_empty():
		return false
	var cells: Dictionary = _cells_of(whole.boxes, Transform3D.IDENTITY)
	if cells.is_empty():
		return false
	var box := AABB((whole.bounds.position / BrickLattice.CELL).floor(), Vector3.ZERO)
	box.end = (whole.bounds.end / BrickLattice.CELL).ceil()
	var taken: int = 0
	var outside: int = 0
	var twice: int = 0
	var seen: Dictionary = {}
	var studs: Array[Vector3] = []
	var sockets: Array[Vector2] = []
	for piece: Array in pieces:
		var mesh: Lbm.PartMesh = library.mesh_for(str(piece[0]))
		var at: Transform3D = piece[1]
		if mesh == null or not _whole_cells(at.origin):
			return false
		for cell: Vector3i in _cells_of(mesh.boxes, at):
			taken += 1
			if seen.has(cell):
				twice += 1
			seen[cell] = true
			if not box.has_point(Vector3(cell) + Vector3(0.5, 0.5, 0.5)):
				outside += 1
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male":
				studs.append(at * connector.position)
		for socket: Vector2 in mesh.sockets:
			var under: Vector3 = at * Vector3(socket.x, 0.0, socket.y)
			sockets.append(Vector2(under.x, under.z))
	var filled: int = 0
	for cell: Vector3i in cells:
		if seen.has(cell):
			filled += 1
	if outside + twice > taken * OUTSIDE_MOST or filled < cells.size() * FILLED_LEAST:
		return false
	for connector: Lbm.Connector in whole.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and not _near_any(connector.position, studs):
			return false
	for socket: Vector2 in whole.sockets:
		var found: bool = false
		for other: Vector2 in sockets:
			if socket.distance_to(other) < NEAR:
				found = true
				break
		if not found:
			return false
	return true


static func _near_any(point: Vector3, among: Array[Vector3]) -> bool:
	for other: Vector3 in among:
		if point.distance_to(other) < NEAR:
			return true
	return false


## Whether a piece's place is a whole number of lattice cells from the
## part's origin, so its cover is its own moved.
static func _whole_cells(at: Vector3) -> bool:
	var off: Vector3 = (at / BrickLattice.CELL - (at / BrickLattice.CELL).round()).abs()
	return off.x < 0.01 and off.y < 0.01 and off.z < 0.01


## The lattice cells a part's cover takes with the part at [param at] in
## the frame they are read in: a quarter or half turn about the up axis and
## a move by whole cells.
static func _cells_of(boxes: Array[AABB], at: Transform3D) -> Dictionary:
	var out: Dictionary = {}
	var shift := Vector3i((at.origin / BrickLattice.CELL).round())
	for box: AABB in boxes:
		var lo := Vector3i(box.position.round())
		var hi := Vector3i(box.end.round())
		for x: int in range(lo.x, hi.x):
			for y: int in range(lo.y, hi.y):
				for z: int in range(lo.z, hi.z):
					# A cell [c, c + 1) turned is the cell whose low corner
					# the turned cell's is.
					var centre: Vector3 = at.basis * (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5))
					out[Vector3i(centre.floor()) + shift] = true
	return out


# -- merge ----------------------------------------------------------------------


## The selection's plates, bricks and tiles merged as far as they go, as one
## step; the rest of it left selected as it was. {"changed": parts merged
## away, "made": parts they became, "words": what to say}.
static func merge_selection(builder: Builder) -> Dictionary:
	var library: PartLibrary = builder.library
	_tables(library)
	var world: BrickWorld = builder.world
	var ids: Array = _selected(builder)
	# Kind, colour and sub-assembly: a merge never paints a part, nor moves
	# one into another assembly.
	var groups: Dictionary = {}
	var plain: int = 0
	var colours: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if not _plain.has(brick.part_id):
			continue
		plain += 1
		colours[brick.color_code] = true
		var kind: String = "Tile" if _plain[brick.part_id][0] == "Tile" else "Plate"
		var key: String = "%s|%d|%s" % [kind, brick.color_code, Assemblies.path_of(brick)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(brick)
	if plain < 2:
		return {"changed": 0, "made": 0, "words":
			"select two or more plates, bricks or tiles of one colour to merge"}
	var removes := PackedInt64Array()
	var adds: Array = []
	var refused: int = 0
	for key: String in groups:
		var kind: String = key.get_slice("|", 0)
		var colour: int = key.get_slice("|", 1).to_int()
		for frame: Dictionary in _frames(library, groups[key]):
			for cells: Dictionary in _pieces_of(frame["cells"]):
				var olds: Dictionary = {}
				for cell: Vector3i in cells:
					olds[frame["cells"][cell]] = true
				if olds.size() < 2:
					continue
				var laid: Array = _tile(cells, _shapes(library, kind, colour, olds.keys(), world))
				if laid.is_empty() or laid.size() >= olds.size():
					continue
				var put: Array = []
				for item: Array in laid:
					put.append(_part_for(library, world, frame, item))
				var gone := PackedInt64Array(olds.keys())
				if not _room_for(builder, gone, put):
					refused += gone.size()
					continue
				removes.append_array(gone)
				adds.append_array(put)
	if removes.is_empty():
		var named: String = ""
		if colours.size() == 1:
			named = " in %s" % library.color(int(colours.keys()[0])).name
		return {"changed": 0, "made": 0, "words": "no room to merge them there" if refused > 0
			else "no real part%s is made of these: nothing merged" % named}
	var words: String = "merged %s into %s" % [Builder._many(removes.size()),
		"a " + Inventory._tidy(library.parts[str(adds[0]["part"])].name) if adds.size() == 1
		else str(adds.size())]
	var made: PackedInt64Array = _swap(builder, ids, removes, adds, words)
	if refused > 0:
		words += " — %d had no room" % refused
	return {"changed": removes.size(), "made": made.size(), "words": words}


## The bricks of one group laid out in frames: the first part's studs-up
## and stud grid, and every other part on it, square to it and a whole
## number of studs and plates off, its cells as cell -> brick id. A part
## off another's grid starts a frame of its own.
static func _frames(library: PartLibrary, bricks: Array) -> Array:
	var frames: Array = []
	for brick: BrickWorld.Brick in bricks:
		var into: Dictionary = {}
		for frame: Dictionary in frames:
			var cells: Variant = _cells_in(library, frame, brick)
			if cells != null:
				into = frame
				for cell: Vector3i in cells:
					(frame["cells"] as Dictionary)[cell] = brick.id
				break
		if into.is_empty():
			var info: PartLibrary.PartInfo = library.parts[brick.part_id]
			var frame: Dictionary = {"at": Transform3D(brick.transform.basis.orthonormalized(),
				brick.transform.origin), "ref": _centre(info, _plain[brick.part_id], 0, 0, 0),
				"cells": {}}
			for cell: Vector3i in _cells_in(library, frame, brick):
				(frame["cells"] as Dictionary)[cell] = brick.id
			frames.append(frame)
	return frames


## Where cell (i, j, k) of a plain part is in its own frame: i studs along
## x, j along z from its low corner, k plates down from its top.
static func _centre(info: PartLibrary.PartInfo, plain: Array, i: int, j: int, k: int) -> Vector3:
	var top: float = info.bounds.position.y + PLATE * _layers(plain[0])
	return Vector3(info.bounds.position.x + STUD * (i + 0.5), top - PLATE * (k + 0.5),
		info.bounds.position.z + STUD * (j + 0.5))


static func _layers(kind: String) -> int:
	return 3 if kind == "Brick" else 1


## [param brick]'s cells in [param frame], or null when it is not on the
## frame's grid: its studs another way up, turned off square, between
## studs or plates, or on cells already taken.
static func _cells_in(library: PartLibrary, frame: Dictionary, brick: BrickWorld.Brick) -> Variant:
	var at: Transform3D = frame["at"]
	var basis: Basis = brick.transform.basis.orthonormalized()
	if basis.y.dot(at.basis.y) < 0.999:
		return null
	if absf(basis.x.dot(at.basis.x)) < 0.999 and absf(basis.x.dot(at.basis.z)) < 0.999:
		return null
	var plain: Array = _plain[brick.part_id]
	var info: PartLibrary.PartInfo = library.parts[brick.part_id]
	var ref: Vector3 = frame["ref"]
	var into: Transform3D = at.affine_inverse() * brick.transform
	var out: Array[Vector3i] = []
	for i: int in plain[1]:
		for j: int in plain[2]:
			for k: int in _layers(plain[0]):
				var cell: Vector3 = (into * _centre(info, plain, i, j, k) - ref) / Vector3(STUD, PLATE, STUD)
				var whole := Vector3i(cell.round())
				var off: Vector3 = (cell - Vector3(whole)).abs() * Vector3(STUD, PLATE, STUD)
				if off.x > NEAR or off.y > NEAR or off.z > NEAR:
					return null
				if (frame["cells"] as Dictionary).has(whole):
					return null
				out.append(whole)
	return out


## The cells in pieces that touch face to face: each is merged, or left,
## on its own.
static func _pieces_of(cells: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for start: Vector3i in cells:
		if seen.has(start):
			continue
		var piece: Dictionary = {}
		var queue: Array[Vector3i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var here: Vector3i = queue.pop_back()
			piece[here] = true
			for step: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN,
					Vector3i.BACK, Vector3i.FORWARD]:
				var next: Vector3i = here + step
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		out.append(piece)
	return out


## The parts a merge may lay, biggest first: [studs along x, plates high,
## studs along z, part id, turned a quarter]. Plates and bricks for plates
## and bricks, tiles for tiles, each a part made in [param colour], or one
## of the parts already there, which the model has in that colour.
static func _shapes(library: PartLibrary, kind: String, colour: int, olds: Array,
		world: BrickWorld) -> Array:
	var had: Dictionary = {}
	for brick_id: int in olds:
		had[world.get_brick(brick_id).part_id] = true
	var out: Array = []
	for size: String in _sized:
		var its: String = size.get_slice("/", 0)
		if not (its == kind or (kind == "Plate" and its == "Brick")):
			continue
		var chosen: String = ""
		for id: String in _sized[size]:
			if had.has(id) or _made_in(library.parts[id], colour):
				chosen = id
				break
		if chosen.is_empty():
			continue
		var plain: Array = _plain[chosen]
		var high: int = _layers(its)
		out.append([plain[1], high, plain[2], chosen, false])
		if plain[1] != plain[2]:
			out.append([plain[2], high, plain[1], chosen, true])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var va: int = int(a[0]) * int(a[1]) * int(a[2])
		var vb: int = int(b[0]) * int(b[1]) * int(b[2])
		if va != vb:
			return va > vb
		if a[1] != b[1]:
			return int(a[1]) > int(b[1])
		return not bool(a[4]) and bool(b[4]))
	return out


## Whether LEGO made [param info] in [param colour], as far as anyone knows:
## a part nothing is known of is not offered.
static func _made_in(info: PartLibrary.PartInfo, colour: int) -> bool:
	return info.availability_known() and not info.never_made_in(colour)


## [param cells] covered by [param shapes], the biggest that fits first,
## from the lowest, nearest corner: [[low cell, shape]], or [] when some
## cell is left that no shape covers.
static func _tile(cells: Dictionary, shapes: Array) -> Array:
	var order: Array = cells.keys()
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var free: Dictionary = cells.duplicate()
	var lo: Vector3i = order[0]
	var hi: Vector3i = order[0]
	for cell: Vector3i in order:
		lo = lo.min(cell)
		hi = hi.max(cell)
	var room: Vector3i = hi - lo + Vector3i.ONE
	var out: Array = []
	for shape: Array in shapes:
		var size := Vector3i(int(shape[0]), int(shape[1]), int(shape[2]))
		if size.x > room.x or size.y > room.y or size.z > room.z:
			continue
		for low: Vector3i in order:
			if not free.has(low) or not _fits(free, low, size):
				continue
			for x: int in size.x:
				for y: int in size.y:
					for z: int in size.z:
						free.erase(low + Vector3i(x, y, z))
			out.append([low, shape])
		if free.is_empty():
			break
	return out if free.is_empty() else []


static func _fits(free: Dictionary, low: Vector3i, size: Vector3i) -> bool:
	for x: int in size.x:
		for y: int in size.y:
			for z: int in size.z:
				if not free.has(low + Vector3i(x, y, z)):
					return false
	return true


## The part a laid shape is, as swap_bricks takes it: placed so its body
## fills the shape's cells in the frame, turned a quarter where the shape
## is, in the colour, sub-assembly and earliest step of the parts it takes
## the place of.
static func _part_for(library: PartLibrary, world: BrickWorld, frame: Dictionary, item: Array) -> Dictionary:
	var low: Vector3i = item[0]
	var shape: Array = item[1]
	var part: String = shape[3]
	var info: PartLibrary.PartInfo = library.parts[part]
	var plain: Array = _plain[part]
	var turn := Basis(Vector3.UP, PI / 2.0) if bool(shape[4]) else Basis.IDENTITY
	var top: float = info.bounds.position.y + PLATE * _layers(plain[0])
	var body := AABB(Vector3(info.bounds.position.x, top - PLATE * _layers(plain[0]),
		info.bounds.position.z), Vector3(info.bounds.size.x, PLATE * _layers(plain[0]), info.bounds.size.z))
	var turned: AABB = Transform3D(turn, Vector3.ZERO) * body
	var ref: Vector3 = frame["ref"]
	# The shape's low corner in the frame: the low cell's centre less half a
	# cell, its top cell being shape[1] - 1 plates above the low one.
	var corner: Vector3 = ref + Vector3(STUD * low.x - STUD * 0.5, PLATE * low.y - PLATE * 0.5,
		STUD * low.z - STUD * 0.5)
	var at: Transform3D = (frame["at"] as Transform3D) * Transform3D(turn, corner - turned.position)
	var first: BrickWorld.Brick = null
	var step: int = -1
	for x: int in int(shape[0]):
		for y: int in int(shape[1]):
			for z: int in int(shape[2]):
				var brick: BrickWorld.Brick = world.get_brick(int((frame["cells"] as Dictionary)[
					low + Vector3i(x, y, z)]))
				if first == null:
					first = brick
				if brick.step >= 0 and (step < 0 or brick.step < step):
					step = brick.step
	return {"part": part, "color": first.color_code,
		"at": Builder._tidy(at, BrickLattice.is_square_to_grid(at.basis)),
		"path": Assemblies.path_of(first), "step": step}


# -- both -----------------------------------------------------------------------


## The selected parts still in the model.
static func _selected(builder: Builder) -> Array:
	var out: Array = []
	for brick_id: int in builder.selection:
		if builder.world.get_brick(brick_id) != null:
			out.append(brick_id)
	return out


## Whether [param adds] can go down with [param gone] taken off: none runs
## into another part. The parts are put back as they were either way.
static func _room_for(builder: Builder, gone: PackedInt64Array, adds: Array) -> bool:
	var lattice: BrickLattice = builder.lattice
	var covers: Dictionary = {}
	for brick_id: int in gone:
		covers[brick_id] = lattice.cover_of(brick_id)[0]
		lattice.release(brick_id)
	var room: bool = true
	for item: Dictionary in adds:
		var packed: PackedInt32Array = builder.boxes_for(
			builder.library.mesh_for(str(item["part"])), item["at"])
		if packed.is_empty() or lattice.collides_boxes(packed):
			room = false
			break
	for brick_id: int in gone:
		lattice.occupy_boxes(brick_id, covers[brick_id])
	return room


## Take [param removes] off and put [param adds] down as one undo, called
## [param words]; select what was put down, with what was selected and not
## changed. Returns the new parts.
static func _swap(builder: Builder, selected: Array, removes: PackedInt64Array, adds: Array,
		words: String) -> PackedInt64Array:
	var steps: Array = builder.swap_bricks(removes, adds)
	builder.record(steps, words)
	var made := PackedInt64Array()
	for step: Dictionary in steps:
		if step.get("undo", "") == "remove":
			made.append(int(step["brick"]))
	var keep: Dictionary = {}
	for brick_id: int in removes:
		keep[brick_id] = true
	builder.selection.clear()
	for brick_id: int in selected:
		if not keep.has(brick_id) and builder.world.get_brick(brick_id) != null:
			builder.selection[brick_id] = true
	for brick_id: int in made:
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	return made


## Read the catalogue's names once a library: the plain plates, bricks and
## tiles and their sizes, and the slopes and their 1-wide ones.
static func _tables(library: PartLibrary) -> void:
	if _for == library:
		return
	_for = library
	_plain = {}
	_sized = {}
	_slopes = {}
	_one_wide = {}
	_splits = {}
	var used: Dictionary = {}
	var slopes: Dictionary = {}
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or info.custom or not info.category in ["Brick", "Plate", "Tile", "Slope"]:
			continue
		var name: String = Inventory._tidy(info.name)
		var found: RegExMatch = _plain_name.search(name)
		if found != null:
			var kind: String = found.get_string(1)
			var plain: Variant = _plain_of(info, kind)
			if plain == null:
				continue
			_plain[id] = plain
			var size: String = "%s/%d/%d" % [kind, mini(plain[1], plain[2]), maxi(plain[1], plain[2])]
			if not _sized.has(size):
				_sized[size] = []
			(_sized[size] as Array).append(id)
			used[id] = info.in_sets
			continue
		var key: String = ""
		var long: int = 0
		var wide: int = 0
		found = _curved_name.search(name)
		if found != null:
			long = found.get_string(1).to_int()
			wide = found.get_string(2).to_int()
			key = "Curved/%d/%d" % [long, roundi(info.bounds.size.y)]
		else:
			found = _slope_name.search(name)
			if found == null:
				continue
			long = found.get_string(2).to_int()
			wide = found.get_string(3).to_int()
			key = "Slope/%s/%d/%d" % [found.get_string(1), long, roundi(info.bounds.size.y)]
		if wide == 1:
			if not _one_wide.has(key) or info.in_sets > int(slopes.get(_one_wide[key], -1)):
				_one_wide[key] = id
				slopes[id] = info.in_sets
		else:
			_slopes[id] = [key, wide]
	for size: String in _sized:
		(_sized[size] as Array).sort_custom(func(a: String, b: String) -> bool:
			return int(used[a]) > int(used[b]) if int(used[a]) != int(used[b]) else a < b)


## [kind, studs along x, along z] for a part whose box is whole studs across
## and a plate (or for a brick three) deep below its top, with its top at
## its origin, as LDraw draws them; null for one that is not.
static func _plain_of(info: PartLibrary.PartInfo, kind: String) -> Variant:
	var box: AABB = info.bounds
	var across: int = roundi(box.size.x / STUD)
	var along: int = roundi(box.size.z / STUD)
	if across < 1 or along < 1 or absf(box.size.x - STUD * across) > NEAR \
			or absf(box.size.z - STUD * along) > NEAR:
		return null
	if absf(box.position.y + PLATE * _layers(kind)) > NEAR:
		return null
	return [kind, across, along]


## The most used part of a size, or "".
static func _first_of(size: String) -> String:
	var ids: Array = _sized.get(size, [])
	return str(ids[0]) if not ids.is_empty() else ""
