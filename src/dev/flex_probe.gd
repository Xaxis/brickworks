## Are flexible parts laid the way the real ones go on?
##
##   godot --headless --path . --script src/dev/flex_probe.gd
##
## A chain over two sprockets has every link on its neighbour's pins: the
## pins 16 LDU along one link's -z are in the next one's hook, read from
## the links' own connectors (Joints.rounds, the rule the checker uses),
## all the way round and back to the first. A hose between two pin holes
## is the length of the real part, goes straight into each hole along its
## axis, and bends no tighter than the hose does. And what cannot be done
## is said: a hose too short for the path, a chain on sprockets that are
## not on one plane.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	await process_frame

	print("\na chain over two sprockets")
	_chain("chain", [["3648b", Vector3(0, 60, 0)], ["3648b", Vector3(140, 60, 0)]])
	print("\na chain over an 8-tooth and a 40-tooth gear")
	_chain("chain", [["3647", Vector3(0, 40, 0)], ["3649", Vector3(160, 70, 0)]])
	print("\na chain round three")
	_chain("chain", [["4019", Vector3(0, 40, 0)], ["4019", Vector3(120, 40, 0)],
		["3648b", Vector3(60, 130, 0)]])
	print("\na tread over two tread sprockets, its face out")
	_chain("tread", [["32007", Vector3(0, 40, 0)], ["32007", Vector3(180, 40, 0)]], true)
	print("\na chain on sprockets turned about the upright")
	_chain("chain", [["3648b", Vector3(0, 60, 0)], ["3648b", Vector3(140, 60, 0)]], false,
		Basis(Vector3.UP, PI * 0.5))
	print("\nand on two lying flat, their axles upright")
	_chain("chain", [["3648b", Vector3(0, 0, -40)], ["3649", Vector3(0, 160, -40)]], false,
		Basis(Vector3.RIGHT, PI * 0.5))
	_refused_chain()

	print("\na pneumatic tube between two pin holes")
	_hose_between_holes()
	print("\na flexible axle through two pin holes")
	_axle_through_holes()
	print("\na ribbed hose over two pins")
	_ribbed_over_pins()
	print("\na string between two studs")
	_string_between_studs()
	print("\na stretched piece's cover is as long as it is")
	_stretched_cover()

	print("\n%s" % ("flex: every check passed" if _failures == 0
		else "flex: %d checks FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, words: String) -> void:
	print("  %s  %s" % ["ok  " if condition else "FAIL", words])
	if not condition:
		_failures += 1


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()


func _put(part: String, at: Transform3D) -> int:
	var brick_id: int = _world.add_brick(part, 7, at)
	_builder.register(brick_id, part, at)
	return brick_id


func _chain(kind: String, gears: Array, face_out: bool = false,
		turn: Basis = Basis.IDENTITY) -> void:
	_clear()
	var sprockets: Array = []
	for gear: Array in gears:
		var brick_id: int = _put(gear[0], Transform3D(turn, turn * (gear[1] as Vector3)))
		var sprocket: Flex.Sprocket = Flex.sprocket_of(_world.get_brick(brick_id), _library)
		_ok(sprocket != null, "%s is a sprocket, %d links round it" % [gear[0],
			sprocket.links if sprocket != null else 0])
		if sprocket == null:
			return
		sprockets.append(sprocket)
	var laid: Flex.Laid = Flex.lay_chain(kind, sprockets)
	_ok(laid.links >= 3 and laid.pieces.size() == laid.links,
		"%d links laid, the chain %.0f LDU on a loop of %.0f" % [laid.links, laid.length,
			laid.wanted])
	_ok(laid.length >= laid.wanted - 0.01 and laid.length - laid.wanted < Flex.CHAIN_PITCH * 1.5,
		"as many links as go round, and the spare hangs")
	for warning: String in laid.warnings:
		print("        said: %s" % warning)
	for note: String in laid.notes:
		print("        noted: %s" % note)
	_ok(laid.warnings.is_empty(), "nothing to warn about")
	var count: int = laid.pieces.size()
	if count < 3:
		return
	# Geometry: each link's far pins are where the next one's hook is.
	var worst: float = 0.0
	for n: int in count:
		var here: Transform3D = laid.pieces[n]["at"]
		var next: Transform3D = laid.pieces[(n + 1) % count]["at"]
		worst = maxf(worst, (here * Vector3(0, 0, -Flex.CHAIN_PITCH)).distance_to(next.origin))
	_ok(worst < 0.05, "every link's pins are in the next one's hook, the worst %.3f LDU off" % worst)
	# Connectors: the links' own shafts in the next's bores, by the
	# checker's rule, every one of them and the last into the first.
	var entries: Array = []
	var part: Lbm.PartMesh = _library.mesh_for(str(laid.pieces[0]["part"]))
	for n: int in count:
		entries.append([n, laid.pieces[n]["at"], part])
	var held: Dictionary = Joints.rounds(entries)
	var joined: int = 0
	for n: int in count:
		var mine: Dictionary = held.get(n, {})
		if mine.has((n + 1) % count):
			joined += 1
	_ok(joined == count, "%d of %d links on their neighbour's pins, read from their connectors"
		% [joined, count])
	# On the sprockets: the chain wraps each on its pin circle, and never
	# cuts inside one; every link in their plane.
	var off_plane: float = 0.0
	var inside: int = 0
	var wrapped: Array = []
	for sprocket: Flex.Sprocket in sprockets:
		var on: int = 0
		for n: int in count:
			var pin: Vector3 = (laid.pieces[n]["at"] as Transform3D).origin
			var gap: Vector3 = pin - sprocket.centre
			var along: float = gap.dot(sprocket.axis)
			off_plane = maxf(off_plane, absf(along))
			var across: float = (gap - sprocket.axis * along).length()
			if absf(across - sprocket.radius) < 0.02:
				on += 1
			elif across < sprocket.radius:
				inside += 1
		wrapped.append(on)
	var each_wrapped: bool = true
	for on: int in wrapped:
		each_wrapped = each_wrapped and on >= 2
	_ok(each_wrapped, "pins on each sprocket's pin circle, as it wraps them: %s" % str(wrapped))
	_ok(inside == 0, "no pin inside a sprocket's pin circle (%d)" % inside)
	_ok(off_plane < 0.01, "every link in the sprockets' plane")
	if face_out:
		var inward: int = 0
		var middle := Vector3.ZERO
		for sprocket: Flex.Sprocket in sprockets:
			middle += sprocket.centre
		middle /= float(sprockets.size())
		for n: int in count:
			var at: Transform3D = laid.pieces[n]["at"]
			if at.basis.y.dot(at.origin - middle) < 0.0:
				inward += 1
		_ok(inward == 0, "every tread link's face is out (%d turned in)" % inward)


func _refused_chain() -> void:
	print("\nsprockets that cannot take one chain")
	_clear()
	var one: int = _put("3648b", Transform3D(Basis.IDENTITY, Vector3(0, 60, 0)))
	var two: int = _put("3648b", Transform3D(Basis.IDENTITY, Vector3(140, 60, 30)))
	var laid: Flex.Laid = Flex.lay_chain("chain", [
		Flex.sprocket_of(_world.get_brick(one), _library),
		Flex.sprocket_of(_world.get_brick(two), _library)])
	_ok(laid.pieces.is_empty() and not laid.warnings.is_empty(),
		"two gears a stud and a half apart along their axles: refused, and said (%s)"
		% ("; ".join(laid.warnings)))


## Two Technic bricks 1 x 2 with a hole, four studs apart, holes along z.
func _two_holes(gap: float = 80.0) -> Array:
	_clear()
	var one: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	var two: int = _put("3700", Transform3D(Basis.IDENTITY, Vector3(gap, 24, 0)))
	var found: Array = [null, null]
	for anchor: Flex.Anchor in Flex.anchors_in(_world, _library, "pneumatic_tube"):
		if anchor.kind != "pin_hole":
			continue
		if anchor.brick == one:
			found[0] = anchor
		elif anchor.brick == two:
			found[1] = anchor
	return found


func _hose_between_holes() -> void:
	var holes: Array = _two_holes()
	_ok(holes[0] != null and holes[1] != null, "both pin holes are found as anchors")
	if holes[0] == null or holes[1] == null:
		return
	var lengths: Array = Flex.lengths_of(_library, "pneumatic_tube")
	var nine: Dictionary = {}
	for one: Dictionary in lengths:
		if str(one["name"]).contains(" 9L"):
			nine = one
	_ok(not nine.is_empty() and is_equal_approx(float(nine["length"]), 180.0),
		"the 9L tube is 180 LDU (%d tube lengths in the library)" % lengths.size())
	if nine.is_empty():
		return
	var a: Flex.Anchor = holes[0]
	var b: Flex.Anchor = holes[1]
	var ports: Array = [Flex.port_for("pneumatic_tube", a, 1), Flex.port_for("pneumatic_tube", b, 1)]
	var laid: Flex.Laid = Flex.lay_swept("pneumatic_tube", ports[0], ports[1], 180.0)
	for warning: String in laid.warnings:
		print("        said: %s" % warning)
	_ok(laid.warnings.is_empty(), "a 9L tube goes from one hole to the other without a warning")
	# The length, from the pieces themselves: each middle piece is the
	# one-LDU tube stretched, and they run end to end.
	var run: float = 0.0
	var middles: Array = []
	for piece: Dictionary in laid.pieces:
		if str(piece["part"]) == "71533k03":
			middles.append(piece)
			run += (piece["at"] as Transform3D).basis.y.length()
	_ok(absf(run - 180.0) < 0.5, "its pieces add up to %.2f LDU, the tube's 180" % run)
	var gaps: float = 0.0
	for n: int in range(1, middles.size()):
		var last: Transform3D = middles[n - 1]["at"]
		var next: Transform3D = middles[n]["at"]
		gaps = maxf(gaps, (last * Vector3(0, -1, 0)).distance_to(next.origin))
	_ok(gaps < 0.01, "each piece starts where the last ended (%.4f LDU)" % gaps)
	# Into each hole: the first piece starts at the hole's middle, along it.
	var first: Transform3D = middles[0]["at"]
	var last_piece: Transform3D = middles[middles.size() - 1]["at"]
	var first_way: Vector3 = -first.basis.y.normalized()
	var last_end: Vector3 = last_piece * Vector3(0, -1, 0)
	var last_way: Vector3 = -last_piece.basis.y.normalized()
	_ok(first.origin.distance_to(a.at) < 0.01 and first_way.dot(a.axis) > 0.9999,
		"it starts at the first hole's middle, straight out along the hole")
	_ok(last_end.distance_to(b.at) < 0.01 and last_way.dot(-b.axis) > 0.9999,
		"and ends at the second's, straight in along it")
	# The bend: no tighter than the tube goes, no piece turned more than
	# PIECE_TURN from the last, and a U lying in the plane of the holes.
	var spec: Dictionary = Flex.KINDS["pneumatic_tube"]
	_ok(laid.tightest >= float(spec["bend"]),
		"it bends round %.1f LDU at the tightest, the tube's least is %.0f"
			% [laid.tightest, float(spec["bend"])])
	var sharpest: float = 0.0
	for n: int in range(1, middles.size()):
		var was: Vector3 = -(middles[n - 1]["at"] as Transform3D).basis.y.normalized()
		var now: Vector3 = -(middles[n]["at"] as Transform3D).basis.y.normalized()
		sharpest = maxf(sharpest, rad_to_deg(was.angle_to(now)))
	_ok(sharpest <= Flex.PIECE_TURN + 0.5, "no piece turns more than %.1f° from the last"
		% sharpest)
	var lowest_y: float = INF
	var highest_y: float = -INF
	for piece: Dictionary in middles:
		var at: Vector3 = (piece["at"] as Transform3D).origin
		lowest_y = minf(lowest_y, at.y)
		highest_y = maxf(highest_y, at.y)
	_ok(highest_y - lowest_y < 0.01, "it lies level, in the plane of the two holes")
	var farthest: float = 0.0
	var middle_x: float = 0.0
	for point: Vector3 in laid.path.points:
		if point.z > farthest:
			farthest = point.z
			middle_x = point.x
	_ok(farthest > 40.0 and absf(middle_x - 40.0) < 0.5,
		"a U out in front, %.0f LDU at its farthest, halfway between the holes (x %.2f)"
			% [farthest, middle_x])
	# Too short is said, and too tight.
	var three: Flex.Laid = Flex.lay_swept("pneumatic_tube", ports[0], ports[1], 60.0)
	_ok(not three.warnings.is_empty() and "; ".join(three.warnings).contains("longer than"),
		"a 3L tube is too short for the path, and that is said: %s" % "; ".join(three.warnings))
	var close: Array = _two_holes(40.0)
	var tight: Flex.Laid = Flex.lay_swept("pneumatic_tube",
		Flex.port_for("pneumatic_tube", close[0], 1),
		Flex.port_for("pneumatic_tube", close[1], 1), 70.0)
	_ok("; ".join(tight.warnings).contains("tighter"),
		"a 70 LDU tube between holes two studs apart bends too tight, and that is said: %s"
			% "; ".join(tight.warnings))


func _axle_through_holes() -> void:
	var holes: Array = _two_holes(160.0)
	if holes[0] == null or holes[1] == null:
		_ok(false, "no holes")
		return
	var a: Flex.Port = Flex.port_for("flex_axle", holes[0], 1, 0)
	var b: Flex.Port = Flex.port_for("flex_axle", holes[1], 1, 1)
	var lengths: Array = Flex.lengths_of(_library, "flex_axle")
	_ok(lengths.size() >= 1, "the flexible axle 26 is in the library")
	var real: float = float(lengths[0]["length"]) if not lengths.is_empty() else 515.0
	var laid: Flex.Laid = Flex.lay_swept("flex_axle", a, b, real)
	for warning: String in laid.warnings:
		print("        said: %s" % warning)
	_ok(laid.warnings.is_empty(), "it goes from one hole to the other without a warning")
	_ok(absf(laid.length - (real + 1.0)) < 0.5, "%.1f LDU tip to tip, the part's %.0f"
		% [laid.length, real + 1.0])
	var parts: Array = laid.pieces.map(func(p: Dictionary) -> String: return str(p["part"]))
	_ok(parts[0] == "u9011" and parts[parts.size() - 1] == "u9010",
		"its 2L end first and its 4.8L end last, the flexible part between")
	# Each rigid end through its hole: its axle runs along the hole's axis.
	var first: Transform3D = laid.pieces[0]["at"]
	var tip: Vector3 = first * Vector3(60, 0, 0)
	var hole: Flex.Anchor = holes[0]
	var off: Vector3 = tip - hole.at
	_ok(first.basis.x.normalized().dot(-hole.axis) > 0.9999
		and (off - hole.axis * off.dot(hole.axis)).length() < 0.01,
		"the 2L end's axle is through the first hole, on its axis (%s along %s, off %s)"
			% [first.basis.x, hole.axis, off])
	_ok(absf(off.dot(hole.axis) + hole.reach) < 0.01,
		"its tip at the hole's far face, %.2f LDU along the axis" % off.dot(hole.axis))
	_ok(laid.tightest >= float(Flex.KINDS["flex_axle"]["bend"]),
		"and it bends round %.0f LDU at the tightest" % laid.tightest)


func _ribbed_over_pins() -> void:
	var holes: Array = _two_holes(120.0)
	if holes[0] == null or holes[1] == null:
		_ok(false, "no holes")
		return
	# A pin in each hole, half of it out at the front.
	for n: int in 2:
		var hole: Flex.Anchor = holes[n]
		_put("2780", Transform3D(Basis(Vector3.UP, -PI * 0.5), hole.at + hole.axis * 10.0))
	var pins: Array = []
	for anchor: Flex.Anchor in Flex.anchors_in(_world, _library, "ribbed_hose"):
		if anchor.kind == "pin" and anchor.axis.z > 0.9 and anchor.at.z > 5.0:
			pins.append(anchor)
	_ok(pins.size() == 2, "the two pins' free halves are anchors (%d)" % pins.size())
	if pins.size() != 2:
		return
	pins.sort_custom(func(x: Flex.Anchor, y: Flex.Anchor) -> bool: return x.at.x < y.at.x)
	var laid: Flex.Laid = Flex.lay_swept("ribbed_hose", Flex.port_for("ribbed_hose", pins[0], 1),
		Flex.port_for("ribbed_hose", pins[1], 1), 336.25)
	for warning: String in laid.warnings:
		print("        said: %s" % warning)
	_ok(laid.warnings.is_empty(), "a 17L ribbed hose goes over both without a warning")
	var parts: Array = laid.pieces.map(func(p: Dictionary) -> String: return str(p["part"]))
	_ok(parts[0] == "71944k01" and parts[parts.size() - 1] == "71944k01"
		and parts.count("71944k02") == parts.size() - 2,
		"an end, %d rings and an end, as LDraw's straight 17L has 54 pieces" % (parts.size() - 2))
	_ok(parts.size() == 54, "54 pieces in all (%d)" % parts.size())
	var spacing: float = 0.0
	for n: int in range(1, laid.pieces.size()):
		spacing = maxf(spacing, (laid.pieces[n]["at"] as Transform3D).origin.distance_to(
			(laid.pieces[n - 1]["at"] as Transform3D).origin))
	_ok(spacing <= 6.26, "the rings 6.25 LDU apart or a little less round the bend (%.3f)"
		% spacing)
	var first: Transform3D = laid.pieces[0]["at"]
	_ok(first.origin.distance_to(pins[0].at + pins[0].axis * 2.5) < 0.05
		and first.basis.y.normalized().dot(pins[0].axis) > 0.9999,
		"its first end is over the first pin, at its collar, running out along it")


func _string_between_studs() -> void:
	_clear()
	_put("3001", Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_put("3001", Transform3D(Basis.IDENTITY, Vector3(300, 24, 0)))
	var studs: Array = Flex.anchors_in(_world, _library, "string")
	_ok(studs.size() == 16, "every stud of two 2x4 bricks is an anchor (%d)" % studs.size())
	studs.sort_custom(func(x: Flex.Anchor, y: Flex.Anchor) -> bool: return x.at.x < y.at.x)
	var a: Flex.Anchor = studs[0]
	var b: Flex.Anchor = studs[studs.size() - 1]
	var laid: Flex.Laid = Flex.lay_swept("string", Flex.port_for("string", a, 1),
		Flex.port_for("string", b, 1), 616.0)
	for warning: String in laid.warnings:
		print("        said: %s" % warning)
	var ends: int = 0
	var lowest: float = INF
	for piece: Dictionary in laid.pieces:
		var at: Transform3D = piece["at"]
		if str(piece["part"]) == "71149k01":
			ends += 1
		else:
			lowest = minf(lowest, at.origin.y)
	_ok(ends == 2 and (laid.pieces[0]["at"] as Transform3D).origin.distance_to(
		a.at + Vector3(0, 8, 0)) < 0.01, "a stud end sits on each stud")
	_ok(absf(laid.length - 588.0) < 0.5, "the braid between them is 588 LDU, as 14225's is")
	_ok(lowest < a.at.y - 60.0, "and it hangs, %.0f LDU below the bricks' tops at its lowest"
		% (a.at.y - lowest))


func _stretched_cover() -> void:
	_clear()
	var part: Lbm.PartMesh = _library.mesh_for("71533k03")
	var at := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, -40, 0), Vector3(0, 0, -1)),
		Vector3(0, 20, 0))
	var packed: PackedInt32Array = _builder.boxes_for(part, at)
	var low: int = 1 << 30
	var high: int = -(1 << 30)
	var n: int = 0
	while n < packed.size():
		low = mini(low, packed[n + 1])
		high = maxi(high, packed[n + 4])
		n += 6
	var tall: float = float(high - low) * BrickLattice.CELL
	_ok(tall >= 40.0 and tall <= 44.0,
		"a one-LDU tube stretched 40 long covers %.0f LDU of the lattice" % tall)
