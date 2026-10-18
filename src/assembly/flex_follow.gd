## Hoses, tubes and strings laid again as the section they join moves (G10).
##
## A laid flexible part bends rather than holding what it joins
## (Bodies.flexible): a pneumatic tube, a ribbed hose, a flex-system hose, a
## flexible axle, a string, as Flex lays them or as another tool laid the
## same parts (LDCad's tubes of 165 and 166, read as 71533k01 and k03).
## Until G10 a grab that moved the body one end sat in and not the body the
## other end sat in left the hose where it was drawn, its end parting from
## its fitting; a real hose bends and follows.
##
## So each such item is read when the grab begins: its two ends off its own
## end pieces (Flex.ends_of_item), the part that holds each end (the joint
## Bodies read between the hose and that part), its length as it lies, and
## its bend (Flex.fit_bend, as Reshape reads one). As the section moves it is
## laid again between its ends' new places and directions by its kind's own
## layout (Flex.lay_swept), its bend points carried by both ends, each by as
## much as it is near that end. One whose ends move together goes with them
## unchanged. A hose has a length: a pose that would pull its ends further
## apart than it reaches is no pose ([method stretched]), and the grab names
## the hose as what holds it.
##
## Kept, an item laid as many pieces as it has is moved piece by piece; one
## its layout lays in more or fewer pieces is laid afresh in its place, its
## own end parts and colours kept (Grab.commit), in the same undo step.
## Pure but for reading the world.
class_name FlexFollow
extends RefCounted

## A hose is stretched when its ends' straight runs and the line between
## them come to more than its length by this, LDU.
const SLACK := 0.5
## An end is held by a part whose box is within this of its tip, LDU.
const HELD_WITHIN := 16.0


## One flexible item a grab may bend.
class Item extends RefCounted:
	var kind: String = ""
	## Its pieces, in the order its layout lays them: the first end, the
	## middles from it to the other, the last end.
	var slots: PackedInt64Array = PackedInt64Array()
	var middles: int = 0
	## Each end piece of its own put on the other way round from the end
	## its layout lays (LDCad's bulged tube end, 71533k01): turned half
	## round where it is laid again.
	var flipped: Array = [false, false]
	## Each slot's own part, colour, and where it stood.
	var parts: PackedStringArray = PackedStringArray()
	var colours: PackedInt32Array = PackedInt32Array()
	var rest: Array = []
	var path: String = ""
	var step: int = -1
	## Its two ends where they stood (Flex.Port), and the part holding each
	## (0 for a free end) with where that stood.
	var ends: Array = []
	var holders: PackedInt64Array = PackedInt64Array([0, 0])
	var holders_rest: Array = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	## The length of its body along its path, and the straight part's
	## (Flex.lay_swept's real).
	var length: float = 0.0
	var real: float = 0.0
	## How far it may reach between its ends: its length, or as far as it
	## reached as it was drawn where that is further (a file's hose drawn
	## taut is not held by its own length where it stands).
	var reach: float = 0.0
	## An end held by a small piece nothing else holds (a T-piece or a valve
	## no joint joins to the model, which hangs on its tubes): the hose is
	## laid to it, and holds nothing by its length.
	var loose: bool = false
	## Its centreline as it lay, and the bend points read off it (read the
	## first time it is laid again) with how far along each is, 0 to 1.
	var line: Flex.Path = null
	var fitted: bool = false
	var controls: PackedVector3Array = PackedVector3Array()
	var fractions: PackedFloat64Array = PackedFloat64Array()
	## Where it is laid now: null where it stands as it stood, or carried
	## whole; and each slot's transform drawn.
	var laid: Flex.Laid = null
	var drawn: Dictionary = {}
	## The search's start for the next laying (Flex.lay_swept's hint).
	var hint: float = 0.0
	## The two ends' moves it was last laid for.
	var moved_for: Array = []
	## "the pneumatic tube from the Technic Pneumatic Valve (#45)".
	var name: String = ""

	## Whether the pieces it is laid as are its pieces one for one, so it is
	## kept by moving them.
	func exact() -> bool:
		return laid == null or laid.pieces.size() == slots.size()


var items: Array[Item] = []
var world: BrickWorld
var library: PartLibrary
## How long reading the items took, and the last laying, ms.
var read_ms: float = 0.0
var lay_ms: float = 0.0


## The items [param bodies] has whose ends a grab moving [param moving]
## (brick id -> true: what moves, the gears it drives and what they carry)
## would part: one end held by a part that moves and the other by one that
## does not, or the item carried while its ends are not.
## [param fits] are the bends [method fit_all] read ahead, used where they are
## of the same pieces.
static func read(from: BrickWorld, parts: PartLibrary, bodies: Bodies,
		moving: Dictionary, fits: Dictionary = {}) -> FlexFollow:
	var started: int = Time.get_ticks_usec()
	var out := FlexFollow.new()
	out.world = from
	out.library = parts
	for one: int in bodies.flexible:
		var item: Item = out._item_of(bodies, one, moving)
		if item == null:
			continue
		var fit: Dictionary = fits.get(one, {})
		if not fit.is_empty() and fit["keys"] == bodies.members[one]:
			item.controls = fit["controls"]
			item.fractions = fit["fractions"]
			item.hint = float(fit["hint"])
			item.fitted = true
		item.reach = maxf(item.length, out._reach_of(item, {}))
		out.items.append(item)
	out.read_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return out


## Every flexible item's bend, read off it where it lies: body -> {"keys",
## "controls", "fractions", "hint"}. Read ahead with the bodies, on a worker
## (GrabDrag._read_all): read at the first frame of a drag, 42080-1's six
## tubes held it half a second.
static func fit_all(from: BrickWorld, parts: PartLibrary, bodies: Bodies) -> Dictionary:
	var reader := FlexFollow.new()
	reader.world = from
	reader.library = parts
	var out: Dictionary = {}
	for one: int in bodies.flexible:
		var item: Item = reader._item_of(bodies, one, {}, true)
		if item == null:
			continue
		reader._fit(item)
		out[one] = {"keys": bodies.members[one], "controls": item.controls, "fractions": item.fractions,
			"hint": item.hint}
	return out


## [param any]: whatever moves, for reading every item ahead.
func _item_of(bodies: Bodies, one: int, moving: Dictionary, any: bool = false) -> Item:
	var keys: PackedInt64Array = bodies.members.get(one, PackedInt64Array())
	if keys.size() < 3:
		return null
	var kind: String = ""
	var pieces: Array = []
	for key: int in keys:
		var brick: BrickWorld.Brick = world.get_brick(key)
		if brick == null:
			return null
		var its: String = Flex.strung(library, brick.part_id)
		if kind.is_empty():
			kind = its
		if its != kind:
			return null
		pieces.append({"part": brick.part_id, "at": brick.transform, "id": key,
			"color": brick.color_code})
	if not Flex.KINDS.has(kind) or str(Flex.KINDS[kind]["family"]) == "links":
		return null
	var ends: Array = Flex.ends_of_item(kind, pieces)
	if ends.size() != 2:
		return null
	# What holds each end: the part across a joint of the hose's, nearest its
	# tip.
	var across: Array = []
	for link: Bodies.Link in bodies.touching.get(one, []):
		if bodies.flexible.has(link.other(one)):
			continue
		for pair: Array in link.pairs:
			for key: int in pair:
				if int(bodies.body_of.get(key, -1)) != one and not across.has(key):
					across.append(key)
	var item := Item.new()
	item.kind = kind
	item.ends = ends
	for n: int in 2:
		var tip: Vector3 = (ends[n] as Flex.Port).tip
		var best: int = 0
		var nearest: float = HELD_WITHIN
		for key: int in across:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
			if mesh == null:
				continue
			var box: AABB = brick.transform * mesh.bounds
			var off: float = tip.distance_to(tip.clamp(box.position, box.end))
			if off < nearest:
				nearest = off
				best = key
		item.holders[n] = best
		if best != 0:
			item.holders_rest[n] = world.get_brick(best).transform
			item.loose = item.loose or FlexFollow._hangs(bodies, best)
			ends[n] = _in_its_connector(kind, ends[n], best, n)
	if item.holders[0] == 0 and item.holders[1] == 0:
		return null
	var carried: bool = moving.has(keys[0])
	var ends_move: Array = []
	for n: int in 2:
		ends_move.append(moving.has(item.holders[n]) if item.holders[n] != 0 else carried)
	if not any and bool(ends_move[0]) == bool(ends_move[1]) and bool(ends_move[0]) == carried:
		return null
	# Its pieces in the order its layout lays them.
	var spec: Dictionary = Flex.KINDS[kind]
	var middle: String = str(spec.get("middle", spec.get("segment", "")))
	var line := Flex.Path.new()
	line.points = Flex.centreline(kind, pieces, (ends[0] as Flex.Port).tip)
	line.measure()
	if line.points.size() < 2:
		return null
	var end_pieces: Array = []
	var middle_pieces: Array = []
	for piece: Dictionary in pieces:
		if str(piece["part"]) == middle:
			middle_pieces.append(piece)
		else:
			end_pieces.append(piece)
	if end_pieces.size() != 2:
		return null
	var tip0: Vector3 = (ends[0] as Flex.Port).tip
	if (end_pieces[1]["at"] as Transform3D).origin.distance_to(tip0) \
			< (end_pieces[0]["at"] as Transform3D).origin.distance_to(tip0):
		end_pieces.reverse()
	for piece: Dictionary in middle_pieces:
		piece["along"] = Flex.along_of(line, (piece["at"] as Transform3D).origin)
	middle_pieces.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["along"]) < float(y["along"]))
	for piece: Dictionary in [end_pieces[0]] + middle_pieces + [end_pieces[1]]:
		item.slots.append(int(piece["id"]))
		item.parts.append(str(piece["part"]))
		item.colours.append(int(piece["color"]))
		item.rest.append(piece["at"])
	item.middles = middle_pieces.size()
	if kind != "string" and not spec.has("ends"):
		for n: int in 2:
			var own: Transform3D = (end_pieces[0] if n == 0 else end_pieces[1])["at"]
			# The way Flex's own end of this kind points into the hose.
			var into: Vector3 = own.basis.y if kind == "ribbed_hose" else -own.basis.y
			item.flipped[n] = into.dot((ends[n] as Flex.Port).out) < 0.0
	var first: BrickWorld.Brick = world.get_brick(keys[0])
	item.path = Assemblies.path_of(first)
	item.step = first.step
	item.line = line
	# Its length along its pieces as they lie, end to end; a pitched kind's
	# from its rings where that agrees, which the layout lays again one for
	# one. LDCad lays a ribbed hose's rings closer than their pitch (42050-1's
	# are 4.8 LDU apart, not 6.25): counted, it came out a quarter longer.
	var run: float = tip0.distance_to(line.points[0]) + line.total() \
		+ line.points[line.points.size() - 1].distance_to((ends[1] as Flex.Port).tip)
	item.length = run
	item.real = Flex.real_for(kind, run)
	if str(spec["family"]) == "pitched":
		var counted: float = Flex.item_length(kind, pieces)
		if kind == "string" or absf(Flex.body_length(kind, counted) - run) < run * 0.03:
			item.real = counted
			item.length = Flex.body_length(kind, counted)
	# Said by the end that stays: "the pneumatic tube from the valve".
	var from: int = 0 if not bool(ends_move[0]) and item.holders[0] != 0 else 1
	if item.holders[from] == 0:
		from = 1 - from
	item.name = "the %s from %s" % [str(spec["label"]).to_lower(), bodies._part_named(item.holders[from])]
	return item


## [param port], an end read off the hose's own pieces, with the straight run
## it has in the connector of [param holder] it is in, as Flex lays one there
## (Flex.port_for: through a pin hole to 2 LDU past its mouth), matched as
## Reshape matches an end to its connector. Read off the pieces, every end
## ran straight 2 LDU: a tube between two holes side by side could reach 12
## LDU further than it does, and the made arm met the tower before the tube
## held it. Unmatched (another tool's end not on a connector's place), as read.
func _in_its_connector(kind: String, port: Flex.Port, holder: int, n: int) -> Flex.Port:
	var brick: BrickWorld.Brick = world.get_brick(holder)
	if brick == null:
		return port
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	var takes: Array = Flex.KINDS[kind].get("takes", [])
	for anchor: Flex.Anchor in Flex.anchors_of(library.mesh_for(brick.part_id), brick.transform, holder,
			info != null and info.name.contains("Pneumatic")):
		if not takes.has(anchor.kind):
			continue
		for side: int in [1, -1]:
			var trial: Flex.Port = Flex.port_for(kind, anchor, side, n)
			if trial.tip.distance_to(port.tip) < 1.0 and trial.out.dot(port.out) > 0.99:
				return Flex.free_port(port.tip, port.out, trial.lead)
	return port


## A piece of the model this small, held by nothing (no part on the
## baseplate's studs, none locked), hangs on its hoses.
const HANGS_MOST := 12


## Whether [param part] is in such a piece: 42080-1's T-pieces, joined to
## nothing but tubes (Bodies reaches them from no anchor), each stood where
## it was drawn while the cylinder a tube from it went to moved, and its tube
## held the crane's arm 3° down.
static func _hangs(bodies: Bodies, part: int) -> bool:
	var at: int = int(bodies.body_of.get(part, -1))
	var guard: int = 0
	while bodies.parent_of.has(at) and guard < 10000:
		at = int(bodies.parent_of[at])
		guard += 1
	# Reached from no anchor (joined to the model by hoses alone, which carry
	# nothing on), or its own piece's heaviest body.
	var why: Array = bodies.anchor_why.get(at, [])
	if not why.is_empty() and str(why[0]) != "heaviest":
		return false
	# Its own parts, not the hoses that hang from it.
	var rigid: Array = bodies.beyond(at).filter(func(one: int) -> bool: return not bodies.flexible.has(one))
	return bodies.parts_of(rigid).size() <= HANGS_MOST


## Every piece of the items, brick id -> true: what [method lay_into] draws.
func keys() -> Dictionary:
	var out: Dictionary = {}
	for item: Item in items:
		for key: int in item.slots:
			out[key] = true
	return out


## Where each piece stood: brick id -> Transform3D.
func rests() -> Dictionary:
	var out: Dictionary = {}
	for item: Item in items:
		for n: int in item.slots.size():
			out[item.slots[n]] = item.rest[n]
	return out


## How the part holding an item's end [param n] has moved, as [param at]
## places it.
func _moved(item: Item, n: int, at: Dictionary) -> Transform3D:
	var holder: int = item.holders[n]
	if holder == 0:
		holder = item.holders[1 - n]
	if holder == 0 or not at.has(holder):
		return Transform3D.IDENTITY
	return (at[holder] as Transform3D) * (item.holders_rest[n if item.holders[n] != 0 else 1 - n]
		as Transform3D).affine_inverse()


## The first item [param at] would pull further than it reaches, or null:
## its ends' straight runs in their connectors and the line between where
## those runs end, against its length.
func stretched(at: Dictionary) -> Item:
	for item: Item in items:
		if not item.loose and _reach_of(item, at) > item.reach + SLACK:
			return item
	return null


## How far apart [param at] puts an item's ends, along the straight runs in
## their connectors and the line between where those runs end: the least
## length that reaches.
## Near its length (within [constant NEAR] of it), the shortest its layout
## lays it between its ends with no bend points, as Flex.swept_path's search
## starts: its ends leaving their connectors their own way, it cannot go
## straight across (a tube between two holes side by side reached its length
## 10 LDU before the line between them did). Not through its bend points:
## read off the hose where it lies, they lie on it, and a curve through them
## is as long as the hose already; 42080-1's arm lowered by 4 LDU of its
## cylinder's rod read a tube as pulled to its length.
func _reach_of(item: Item, at: Dictionary) -> float:
	var one: Transform3D = _moved(item, 0, at)
	var other: Transform3D = _moved(item, 1, at)
	var a: Flex.Port = _port(item, 0, one)
	var b: Flex.Port = _port(item, 1, other)
	if item.kind == "string":
		# Between the braid's ends, off the tops of its stud ends.
		var a_tip: Vector3 = a.tip
		a = Flex._string_port(a, b.tip)
		b = Flex._string_port(b, a_tip)
	var from: Vector3 = a.start()
	var to: Vector3 = b.start()
	var straight: float = from.distance_to(to) + a.lead + b.lead
	if item.kind == "string" or straight < maxf(item.length, item.reach) * NEAR:
		return straight
	var least: float = Flex._curve_length(from, a.out, to, -b.out, PackedVector3Array(),
		maxf(from.distance_to(to) * 0.2, 1.0), FlexFollow.step_for(item)) + a.lead + b.lead
	return maxf(straight, least)


## A hose this close to its length, the line between its ends against it,
## is measured along the shortest its layout lays it.
const NEAR := 0.85


## The item's bend points where its ends' moves [param one] and [param
## other] carry them: each by both, by as much as it is near each.
func _controls_at(item: Item, one: Transform3D, other: Transform3D) -> PackedVector3Array:
	if not item.fitted:
		_fit(item)
	var controls := PackedVector3Array()
	for n: int in item.controls.size():
		var t: float = item.fractions[n]
		var point: Vector3 = item.controls[n]
		controls.append((one * point) * (1.0 - t) + (other * point) * t)
	return controls


func _port(item: Item, n: int, move: Transform3D) -> Flex.Port:
	var rest: Flex.Port = item.ends[n]
	return Flex.free_port(move * rest.tip, move.basis * rest.out, rest.lead)


## Lay each item where [param at] (brick id -> Transform3D, a grab's
## placed) puts the parts holding its ends, and put its pieces in [param
## at] too.
func lay_into(at: Dictionary) -> void:
	var started: int = Time.get_ticks_usec()
	for item: Item in items:
		var moves: Array = [_moved(item, 0, at), _moved(item, 1, at)]
		if not item.moved_for.is_empty() and _same(moves[0], item.moved_for[0]) \
				and _same(moves[1], item.moved_for[1]):
			for key: Variant in item.drawn:
				at[key] = item.drawn[key]
			continue
		item.moved_for = moves
		item.drawn.clear()
		if _same(moves[0], moves[1]):
			# Its ends move together: it goes with them as it is.
			item.laid = null
			for n: int in item.slots.size():
				item.drawn[item.slots[n]] = (moves[0] as Transform3D) * (item.rest[n] as Transform3D)
		else:
			_lay(item, moves[0], moves[1])
		for key: Variant in item.drawn:
			at[key] = item.drawn[key]
	lay_ms = float(Time.get_ticks_usec() - started) / 1000.0


## How finely an item's path is drawn as it is laid again, LDU: its kind's
## own step (Flex.SAMPLE) on a short hose, and no more than [constant
## POINTS] points along a long one. 42080-1's arm bends six tubes of up to
## 700 LDU, and at three quarters of an LDU a laying was 20 ms each; the
## curve is the same, drawn by fewer points (7 LDU apart on the longest).
const POINTS := 100.0


static func step_for(item: Item) -> float:
	return maxf(Flex.SAMPLE, item.length / POINTS)


func _lay(item: Item, one: Transform3D, other: Transform3D) -> void:
	var a: Flex.Port = _port(item, 0, one)
	var b: Flex.Port = _port(item, 1, other)
	var step: float = FlexFollow.step_for(item)
	if not item.fitted:
		_fit(item)
	var controls: PackedVector3Array = _controls_at(item, one, other)
	var laid: Flex.Laid = Flex.lay_swept(item.kind, a, b, item.real, controls, item.hint, step,
		false)
	if not controls.is_empty() and laid.path.total() > laid.wanted + 0.5:
		# Through its bend points it would be longer than it is (42080-1's arm
		# lowered spread a tube's seven, and it came out 10 LDU long): it
		# straightens, laid between its ends alone.
		laid = Flex.lay_swept(item.kind, a, b, item.real, PackedVector3Array(), item.hint, step, false)
	item.hint = laid.sag if item.kind == "string" else laid.k
	item.laid = laid
	_map(item, laid)


## Read the item's bend off it where it lies (Flex.fit_bend, as Reshape reads
## one), laid as a drag lays it: by [method step_for]'s points, scored on a
## hundred of the line's.
func _fit(item: Item) -> void:
	item.fitted = true
	var step: float = FlexFollow.step_for(item)
	var at_rest: Array = [_port(item, 0, Transform3D.IDENTITY), _port(item, 1, Transform3D.IDENTITY)]
	var own: float = minf(item.line.tightest(2.0), float(Flex.KINDS[item.kind].get("bend", 0.0)))
	# Each try's length search starts where the last one ended (an array: a
	# lambda keeps its own copy of a number).
	var guess: Array = [maxf((at_rest[0] as Flex.Port).start().distance_to((at_rest[1] as Flex.Port).start()),
		8.0)]
	item.controls = Flex.fit_bend(func(controls: PackedVector3Array) -> Flex.Laid:
		var trial: Flex.Laid = Flex.lay_swept(item.kind, at_rest[0], at_rest[1], item.real, controls,
			float(guess[0]) if item.kind != "string" else 0.0, step)
		guess[0] = maxf(trial.k, float(guess[0]) * 0.5)
		return trial, item.line, own, 100)
	item.hint = float(guess[0]) if item.kind != "string" else 0.0
	item.fractions = PackedFloat64Array()
	for point: Vector3 in item.controls:
		item.fractions.append(Flex.along_of(item.line, point) / maxf(item.line.total(), 0.001))


## The pieces laid onto the item's own, slot for slot: the ends to its ends,
## the middles in order. Where the layout laid fewer middles than it has,
## the rest are drawn as nothing at its last end; where more, neighbouring
## ones are drawn as one (a tube's pieces stretched over both), until it is
## kept and laid afresh (Grab.commit).
func _map(item: Item, laid: Flex.Laid) -> void:
	var count: int = laid.pieces.size()
	if count < 2:
		return
	var last: int = item.slots.size() - 1
	item.drawn[item.slots[0]] = FlexFollow._own_end(item, 0, laid.pieces[0]["at"])
	item.drawn[item.slots[last]] = FlexFollow._own_end(item, 1, laid.pieces[count - 1]["at"])
	var given: Array = laid.pieces.slice(1, count - 1)
	var wanted: int = item.middles
	if given.size() > wanted and wanted > 0:
		given = _merged(item.kind, given, wanted)
	var gone := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001),
		(laid.pieces[count - 1]["at"] as Transform3D).origin)
	for n: int in wanted:
		item.drawn[item.slots[n + 1]] = given[n]["at"] if n < given.size() else gone


## [param pieces] of a scaled kind drawn as [param count]: each run of
## neighbours one piece from the first's start to the last's end.
static func _merged(kind: String, pieces: Array, count: int) -> Array:
	var spec: Dictionary = Flex.KINDS[kind]
	if str(spec["family"]) != "scaled":
		return pieces.slice(0, count)
	var native: float = float(spec.get("native", 1.0))
	var x_way: bool = str(spec.get("along", "y")) == "x"
	var out: Array = []
	for n: int in count:
		var from: int = n * pieces.size() / count
		var to: int = (n + 1) * pieces.size() / count - 1
		var first: Transform3D = pieces[from]["at"]
		var final: Transform3D = pieces[to]["at"]
		var start: Vector3
		var end: Vector3
		if x_way:
			start = first.origin - first.basis.x * native * 0.5
			end = final.origin + final.basis.x * native * 0.5
		else:
			start = first.origin
			end = final.origin - final.basis.y * native
		var span: float = start.distance_to(end)
		if span < 0.001:
			out.append(pieces[from])
			continue
		var heading: Vector3 = (end - start) / span
		var normal: Vector3 = first.basis.x.normalized() if not x_way else first.basis.y.normalized()
		var at: Transform3D
		if x_way:
			var basis: Basis = Flex.basis_along(heading, normal, "x")
			basis.x *= span / native
			at = Transform3D(basis, (start + end) * 0.5)
		else:
			var basis: Basis = Flex.basis_along(heading, normal, "-y")
			basis.y *= span / native
			at = Transform3D(basis, start)
		out.append({"part": spec["middle"], "at": at})
	return out


## Where the item's own end piece [param n] goes for an end laid at [param
## at]: there, turned half round where its own is the other way round.
static func _own_end(item: Item, n: int, at: Transform3D) -> Transform3D:
	if not bool(item.flipped[n]):
		return at
	return Transform3D(at.basis * Basis(Vector3.RIGHT, PI), at.origin)


## The items to be laid afresh when kept: laid as more or fewer pieces than
## they have. Brick id -> true for each of their pieces.
func swapped() -> Dictionary:
	var out: Dictionary = {}
	for item: Item in items:
		if not item.exact():
			for key: int in item.slots:
				out[key] = true
	return out


## Lay afresh each item [method swapped] names, in its place, its own end
## parts and colours kept: the history steps, for the grab's one step.
## [param placed] and [param rest] (the grab's) lose the old pieces and gain
## the new, standing where they are put.
func swap(builder: Builder, placed: Dictionary, rest: Dictionary) -> Array:
	var steps: Array = []
	for item: Item in items:
		if item.exact():
			continue
		var adds: Array = []
		var count: int = item.laid.pieces.size()
		# Where its pieces are now: a copy made its own since it was read
		# (GrabDrag._own_copies) is under another name.
		var first: BrickWorld.Brick = world.get_brick(item.slots[0])
		var path: String = Assemblies.path_of(first) if first != null else item.path
		for n: int in count:
			var piece: Dictionary = item.laid.pieces[n]
			var slot: int = 0 if n == 0 else (item.slots.size() - 1 if n == count - 1 else 1)
			var part: String = item.parts[slot] if n == 0 or n == count - 1 else str(piece["part"])
			if n > 0 and n < count - 1 and item.middles > 0:
				part = item.parts[1]
			var at: Transform3D = piece["at"]
			if n == 0 or n == count - 1:
				at = FlexFollow._own_end(item, 0 if n == 0 else 1, at)
			adds.append({"part": part, "color": item.colours[slot], "at": at, "path": path,
				"step": item.step})
		var put: Array = builder.swap_bricks(item.slots, adds)
		for key: int in item.slots:
			placed.erase(key)
			rest.erase(key)
		for one: Dictionary in put:
			if str(one.get("undo", "")) == "remove":
				var brick: BrickWorld.Brick = world.get_brick(int(one["brick"]))
				if brick != null:
					placed[brick.id] = brick.transform
					rest[brick.id] = brick.transform
		steps.append_array(put)
	return steps


static func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.is_equal_approx(b.origin) and a.basis.x.is_equal_approx(b.basis.x) \
		and a.basis.y.is_equal_approx(b.basis.y) and a.basis.z.is_equal_approx(b.basis.z)
