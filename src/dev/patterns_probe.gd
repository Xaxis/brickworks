## Can a shape be said rather than counted out?
##
##   godot --headless --path . --script src/dev/patterns_probe.gd
##
## Writing placements one at a time is the arithmetic a language model is
## worst at. An ellipse twenty studs across is a hundred and fifty plates
## by hand; a wing said twice is a wing a stud out on one side, which is
## why there is a check for exactly that; and four thousand parts cannot
## be dictated in one reply at all.
##
## So the design says the shape — repeat, mirror, fill — and the app does
## the counting. What has to be right is the counting, and the two places
## it goes wrong are both here: a placement names its low corner, so a
## mirrored brick moves by its own width as well; and a part with a hand
## has to swap to its twin, or a model gets two left wings, which looks
## exactly like two right wings until somebody looks at it.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("  repeat")
	var row: Array = _made([{
		"pattern": "repeat", "times": 4, "step": {"x": 2},
		"bricks": [{"part": "3023", "color": 71, "x": 0, "y": 0, "z": 0,
			"rot": 0}],
	}])
	_check("four copies, stepped two studs", row.size() == 4)
	_check("...the first where it was written, the last six along",
		row.size() == 4 and float(row[0]["x"]) == 0.0
			and float(row[3]["x"]) == 6.0)
	_check("a repeat with no step is refused",
		_trouble([{"pattern": "repeat", "times": 3,
			"bricks": [{"part": "3023", "x": 0, "y": 0, "z": 0}]}])
			.contains("step"))

	print("")
	print("  mirror")
	# A 2 x 4 brick at x=0 covers studs 0 to 3. Mirrored about x=6 it has
	# to cover 8 to 11, so its corner is 8 — not 12, which is where
	# reflecting the corner alone would put it, and not 11 either.
	var pair: Array = _made([
		{"pattern": "mirror", "about": "x", "at": 6,
			"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0,
				"z": 0, "rot": 0}]},
	])
	_check("one brick reflected, %d back" % pair.size(), pair.size() == 1)
	_check("...and it lands by its far corner, x=%s"
		% (str(pair[0]["x"]) if pair.size() == 1 else "none"),
		pair.size() == 1 and is_equal_approx(float(pair[0]["x"]), 8.0))

	# A wedge plate has a hand. Reflecting one without swapping it gives
	# two left wings.
	var wing: Array = _made([
		{"pattern": "mirror", "about": "z", "at": 4,
			"bricks": [{"part": "41769b", "color": 4, "x": 0, "y": 0,
				"z": 0, "rot": 0}]},
	])
	_check("a wedge plate mirrors to its other hand, %s"
		% (str(wing[0]["part"]) if wing.size() == 1 else "none"),
		wing.size() == 1 and str(wing[0]["part"]) == "41770b")

	# And with nothing named, it reflects everything written so far,
	# which is how a half-built model becomes a whole one.
	var whole: Array = _made([{"pattern": "mirror", "about": "x", "at": 10}],
		[{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0}])
	_check("with nothing named it reflects what is already there, %d"
		% whole.size(), whole.size() == 2)

	print("")
	print("  fill")
	var slab: Array = _made([{"pattern": "fill", "shape": "rectangle",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 8, "deep": 4, "color": 71}])
	_check("a rectangle is covered, %d plates" % slab.size(),
		not slab.is_empty())
	_check("...with the largest that fit, not thirty-two ones",
		slab.size() <= 4)
	_check("...and every stud of it", _covers(slab, 8, 4))

	var disc: Array = _made([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 20, "deep": 16,
		"color": 71}])
	_check("an ellipse comes back, %d plates for 20 x 16" % disc.size(),
		disc.size() > 4 and disc.size() < 80)
	# The shape of it: an ellipse is narrower at its ends than a
	# rectangle, so the corners must be empty.
	var corners: bool = true
	for one: Variant in disc:
		var brick: Dictionary = one
		if float(brick["x"]) < 1.0 and float(brick["z"]) < 1.0:
			corners = false
	_check("...and it is an ellipse, not the box round it", corners)

	print("")
	print("  a solid, said in one object")
	# The shapes a model actually needs and could not say: a dome, a
	# tube, a hull. Each of these was three hundred plates written by
	# hand, and the hundredth plate of a dome is where a design stops
	# being able to check its own work.
	var dome: Array = _made([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 16, "deep": 16,
		"layers": 8, "shrink": 2, "color": 71}])
	_check("a dome comes back, %d plates" % dome.size(), dome.size() > 20)
	var heights: Dictionary = {}
	var widest: Dictionary = {}   ## height -> studs across at that height
	for one: Variant in dome:
		var brick: Dictionary = one
		var y: float = float(brick["y"])
		heights[y] = true
		var x: float = float(brick["x"])
		widest[y] = maxf(widest.get(y, -999.0), x)
	_check("...eight layers of it, one plate apart, %d" % heights.size(),
		heights.size() == 8)
	# Narrower as it rises, which is the whole of what shrink means.
	_check("...and each layer narrower than the one below",
		float(widest.get(0.0, 0.0)) > float(widest.get(7.0, 99.0)))

	var tube: Array = _made([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 12, "deep": 12,
		"wall": 1, "layers": 3, "color": 71}])
	var solid: Array = _made([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 12, "deep": 12,
		"layers": 3, "color": 71}])
	_check("a wall leaves the middle out, %d plates against %d solid"
		% [tube.size(), solid.size()], not tube.is_empty())
	# Counted in studs rather than plates: a ring is more plates than
	# the disc it came from, because a 1-wide ring cannot be tiled in
	# 6x4s. Area is the thing that got smaller.
	_check("...and it is hollow, %d studs against %d"
		% [_area(tube), _area(solid)], _area(tube) < _area(solid) / 2)

	var hull: Array = _made([{"pattern": "fill", "shape": "rectangle",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 6, "deep": 4,
		"layers": 4, "rise": 3, "color": 71}])
	var courses: Dictionary = {}
	for one: Variant in hull:
		courses[float((one as Dictionary)["y"])] = true
	_check("rise puts courses three plates apart, %s"
		% str(courses.keys()), courses.has(0.0) and courses.has(9.0)
		and not courses.has(1.0))

	# A taper that runs out before its layers do is a cone, not an error.
	var cone: Array = _made([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 8, "deep": 8,
		"layers": 40, "shrink": 2, "color": 71}])
	_check("a taper that comes to a point stops there, %d plates"
		% cone.size(), not cone.is_empty() and cone.size() < 200)

	_a_wall_is_long_bricks()
	_a_wall_has_texture()
	_wedges_read_off_the_parts()
	_wedges_go_in_symmetrically()
	_holds_up()

	print("")
	print("  rock")
	var crag: Array = _made([{"pattern": "rock", "at": {"x": 0, "y": 0, "z": 0},
		"across": 16, "deep": 12, "height": 15, "seed": 1}])
	var faces: Dictionary = {}
	var greys: Dictionary = {}
	var high := Vector2.ZERO
	var counted: int = 0
	for one: Dictionary in crag:
		faces[str(one["part"])] = true
		greys[int(one["color"])] = true
		if float(one["y"]) >= 6.0:
			high += Vector2(float(one["x"]) + 0.5, float(one["z"]) + 0.5)
			counted += 1
	var drift: float = (high / maxf(counted, 1.0)).distance_to(Vector2(8, 6))
	_check("a crag comes back, %d parts" % crag.size(), crag.size() > 100)
	_check("...faced with slopes, not left as steps: %s" % ", ".join(faces.keys()),
		faces.has("3040b") and faces.has("54200"))
	_check("...in two greys", greys.has(72) and greys.has(71))
	_check("...leaning one way, not a cone: its upper half %.1f studs off the middle"
		% drift, drift > 1.0)
	var other: Array = _made([{"pattern": "rock", "at": {"x": 0, "y": 0, "z": 0},
		"across": 16, "deep": 12, "height": 15, "seed": 2}])
	_check("...and another seed is another rock", JSON.stringify(other) != JSON.stringify(crag))
	_check("a rock too small to be one is refused",
		_trouble([{"pattern": "rock", "across": 1, "deep": 1}]).contains("rock wants"))

	print("")
	print("  and nonsense is refused rather than built")
	_check("an odd shrink, which would lean the stack",
		_trouble([{"pattern": "fill", "shape": "ellipse", "across": 10,
			"deep": 10, "layers": 4, "shrink": 1}]).contains("even"))
	# Each layer is inside the cap and forty of them are not, which is
	# the one that got through: the first version only measured the
	# footprint, so a reasonable footprint stacked forty high was six
	# thousand plates and no complaint.
	_check("a fill too big to be a shape",
		_trouble([{"pattern": "fill", "shape": "rectangle", "across": 60,
			"deep": 60, "layers": 40}]).contains("mistake in the numbers"))
	_check("a pattern nobody has",
		_trouble([{"pattern": "spiral"}]).contains("no pattern called"))
	_check("a fill with no size",
		_trouble([{"pattern": "fill", "shape": "rectangle"}]).contains("across"))
	_check("a mirror with no line",
		_trouble([{"pattern": "mirror", "about": "x"}]).contains("at"))

	print("")
	if _failures == 0:
		print("a shape can be said instead of counted out")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## Does a shape said this way actually stand up?
##
## Expanding to plates is half the job and the easy half. A dome whose
## layers do not reach the one below is a stack of floating rings, and
## the pattern would then be worse than counting it out by hand: wrong
## in a way the design cannot see, arriving as a refusal it cannot
## account for. So each of the five shapes the prompt offers is run
## through the same checker a submission goes through.
func _holds_up() -> void:
	print("")
	print("  and it stands up — the same checker a submission faces")
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = _library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)

	for one: Array in [
		["a dome", {"pattern": "fill", "shape": "ellipse",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 16, "deep": 16,
			"layers": 8, "shrink": 2, "color": 71}],
		["a cone", {"pattern": "fill", "shape": "ellipse",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 20, "deep": 20,
			"layers": 10, "shrink": 4, "color": 71}],
		["a round tower", {"pattern": "fill", "shape": "ellipse",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 12, "deep": 12,
			"wall": 1, "layers": 12, "rise": 3, "color": 71}],
		["a hull", {"pattern": "fill", "shape": "rectangle",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 10, "deep": 6,
			"layers": 6, "rise": 3, "color": 71}],
		["a bowl", {"pattern": "fill", "shape": "ellipse",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 8, "deep": 8,
			"wall": 2, "layers": 6, "shrink": -2, "color": 71}],
		# Laid in short bricks, which only hold as one thing if the bond
		# carries every course across the joints of the one below.
		["a curtain wall", {"pattern": "fill", "shape": "rectangle",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 40, "deep": 24,
			"wall": 1, "layers": 12, "rise": 3, "color": 71}],
		["a wall two studs thick", {"pattern": "fill", "shape": "rectangle",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 30, "deep": 18,
			"wall": 2, "layers": 8, "rise": 3, "color": 71}],
		["a weathered wall", {"pattern": "fill", "shape": "rectangle",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 40, "deep": 24,
			"wall": 1, "layers": 12, "rise": 3, "color": 71,
			"mix_color": 72, "masonry": 0.5}],
		["a stone wall, partly on its side", {"pattern": "fill", "shape": "rectangle",
			"at": {"x": 0, "y": 0, "z": 0}, "across": 24, "deep": 16,
			"wall": 1, "layers": 8, "rise": 3, "color": 71,
			"mix_color": 72, "masonry": 0.4, "sideways": 0.3}],
		["an octagonal shaft", {"pattern": "prism", "at": {"x": 10, "y": 0, "z": 10},
			"sides": 8, "radius": 7, "courses": 10, "color": 0, "mix_color": 72}],
		["a hexagonal tower one stud thick, in masonry", {"pattern": "prism",
			"at": {"x": 10, "y": 0, "z": 10}, "sides": 6, "radius": 6, "courses": 8,
			"thickness": 1, "color": 71, "masonry": 0.5}],
		["a crag", {"pattern": "rock", "at": {"x": 0, "y": 0, "z": 0},
			"across": 16, "deep": 12, "height": 15, "seed": 1}],
		["another crag", {"pattern": "rock", "at": {"x": 0, "y": 0, "z": 0},
			"across": 24, "deep": 20, "height": 21, "seed": 7}],
		["a boulder", {"pattern": "rock", "at": {"x": 0, "y": 0, "z": 0},
			"across": 5, "deep": 4, "height": 6, "seed": 3}],
		["a face built sideways, looking +z", {"pattern": "studs_out",
			"at": {"x": 0, "y": 0, "z": 0}, "length": 8, "courses": 4,
			"facing": "+z", "color": 0, "face_color": 72, "mix_color": 71}],
		["...looking -z", {"pattern": "studs_out", "at": {"x": 0, "y": 0, "z": 0},
			"length": 6, "courses": 3, "facing": "-z", "color": 0}],
		["...looking +x", {"pattern": "studs_out", "at": {"x": 0, "y": 0, "z": 0},
			"length": 6, "courses": 3, "facing": "+x", "color": 0}],
		["...looking -x", {"pattern": "studs_out", "at": {"x": 0, "y": 0, "z": 0},
			"length": 6, "courses": 3, "facing": "-x", "color": 0}],
	]:
		var model: Assistant.Model = assistant._read_model(
			{"patterns": [one[1]]})
		var verdict: Dictionary = assistant._check(model)
		if bool(verdict["ok"]):
			_check("%s holds together, %d parts"
				% [one[0], model.placements.size()], true)
		else:
			_check("%s — %s" % [one[0], str(verdict["summary"])], false)
		if (one[1] as Dictionary).has("sideways"):
			var turned: int = 0
			var dressed: int = 0
			for placement: Assistant.Placement in model.placements:
				if placement.part == "87087":
					turned += 1
				elif placement.face != "up":
					dressed += 1
			_check("...with %d bricks turned out and %d parts dressed on their sides"
				% [turned, dressed], turned > 10 and dressed == turned)
		if str((one[1] as Dictionary)["pattern"]) == "prism":
			var sides: int = int((one[1] as Dictionary)["sides"])
			var turned: Dictionary = {}
			for placement: Assistant.Placement in model.placements:
				var section: Assistant.Section = model.section_for(placement)
				if section != null:
					turned[snappedf(section.degrees, 0.1)] = true
			_check("...its %d faces each turned to their own angle, %d angles"
				% [sides, turned.size()], turned.size() == sides)
		if str((one[1] as Dictionary)["pattern"]) == "studs_out":
			var sideways: int = 0
			var face: String = str((one[1] as Dictionary)["facing"])
			for placement: Assistant.Placement in model.placements:
				if placement.face == face:
					sideways += 1
			var studs: int = int((one[1] as Dictionary)["length"]) \
				* int((one[1] as Dictionary)["courses"])
			_check("...with a part on its side on every one of its %d side studs, %d"
				% [studs, sideways], sideways == studs)


func _made(patterns: Array, already: Array = []) -> Array:
	var trouble: Array = []
	return Patterns.expand(patterns, already, trouble, _library)


func _trouble(patterns: Array) -> String:
	var trouble: Array = []
	Patterns.expand(patterns, [], trouble, _library)
	var said := PackedStringArray()
	for one: Variant in trouble:
		said.append(str(one))
	return " ".join(said)


## How many studs a set of parts actually covers.
##
## A wedge's footprint box is bigger than the studs on it — that is
## what makes it a wedge — so counting boxes made a ring full of
## wedges measure wider than the disc it came from while being just as
## hollow. The wedge table knows which cells each one covers, so ask
## it, and fall back to the footprint for anything square.
func _area(bricks: Array) -> int:
	var shapes: Dictionary = Patterns.wedge_shapes(_library)
	var total: int = 0
	for one: Variant in bricks:
		var brick: Dictionary = one
		var named: String = "%s %d" % [str(brick["part"]),
			int(brick.get("rot", 0))]
		if shapes.has(named):
			total += (shapes[named][2] as Dictionary).size()
			continue
		var info: PartLibrary.PartInfo = _library.parts.get(str(brick["part"]))
		if info == null:
			continue
		var footprint: Vector2i = info.footprint_studs()
		total += footprint.x * footprint.y
	return total


## Whether the plates cover every stud of a footprint exactly once.
func _covers(bricks: Array, across: int, deep: int) -> bool:
	var seen: Dictionary = {}
	for one: Variant in bricks:
		var brick: Dictionary = one
		var info: PartLibrary.PartInfo = _library.parts.get(str(brick["part"]))
		if info == null:
			return false
		var footprint: Vector2i = info.footprint_studs()
		var wide: int = footprint.x
		var tall: int = footprint.y
		if int(brick.get("rot", 0)) % 2 == 1:
			var swap: int = wide
			wide = tall
			tall = swap
		for dx: int in wide:
			for dz: int in tall:
				var cell := Vector2i(int(brick["x"]) + dx, int(brick["z"]) + dz)
				if seen.has(cell):
					return false
				seen[cell] = true
	return seen.size() == across * deep


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


## A wall is the shape fill is best at and the one a design was most
## likely to write out by hand.
##
## Measured on a castle run: it dictated its curtain walls as two hundred
## and twenty-three 1x2 bricks, every joint in a column. fill then laid
## the longest brick that fitted — 1x8s and 2x10s — and every castle
## built that way was 39-56% pieces as big as a 2 x 4 brick, where a real
## set is 10%. So it lays a real set's sizes now, in a bond, and what is
## asserted is both halves: no long bricks, and no columns.
func _a_wall_is_long_bricks() -> void:
	print("")
	print("  a curtain wall, which fill is best at")
	var trouble: Array = []
	var made: Array = Patterns.expand([{
		"pattern": "fill", "shape": "rectangle",
		"at": {"x": 0, "y": 0, "z": 0},
		"across": 40, "deep": 24, "wall": 1,
		"layers": 12, "rise": 3, "color": 71,
	}], [], trouble, _library)
	_check("a 40 by 24 wall twelve courses high is said in one object, "
		+ "%d parts%s" % [made.size(), "" if trouble.is_empty()
			else " — but %s" % str(trouble)],
		trouble.is_empty() and made.size() > 0 and made.size() < 500)
	var counted: Dictionary = {}
	for raw: Variant in made:
		var id: String = str((raw as Dictionary).get("part", "?"))
		counted[id] = int(counted.get(id, 0)) + 1
	_check("laid in the sizes a real set uses: %s" % str(counted),
		int(counted.get("3010", 0)) > made.size() / 2
			and not counted.has("3008") and not counted.has("3006"))
	# The bond: where two bricks of a course meet is a joint, and a joint
	# directly over a joint in the course below is how a wall becomes
	# columns. A half brick at the end of a run is fine — it is the
	# joints that must not stack.
	var at: Dictionary = {}          ## course -> {cell: index}
	for n: int in made.size():
		var one: Dictionary = made[n]
		var course: int = int(round(float(one["y"]) / 3.0))
		if not at.has(course):
			at[course] = {}
		for cell: Vector2i in _cells_of(one):
			(at[course] as Dictionary)[cell] = n
	var joints: Dictionary = {}      ## course -> {"cell|step": true}
	for course: Variant in at:
		var here: Dictionary = at[course]
		var found: Dictionary = {}
		for key: Variant in here:
			var cell: Vector2i = key
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if here.has(cell + step) and here[cell + step] != here[cell]:
					found["%s|%s" % [cell, step]] = true
		joints[course] = found
	var stacked: int = 0
	var all_joints: int = 0
	for course: Variant in joints:
		if int(course) == 0:
			continue
		for joint: Variant in joints[course]:
			all_joints += 1
			if (joints[int(course) - 1] as Dictionary).has(joint):
				stacked += 1
	_check("bonded: %d of %d joints stand on a joint in the course below"
		% [stacked, all_joints], all_joints > 0 and stacked * 20 < all_joints)


## What a wall's short bricks are: a second grey through some of them,
## and some laid as masonry with the stonework facing out.
func _a_wall_has_texture() -> void:
	print("")
	print("  a weathered wall, said in the same one object")
	var wall: Dictionary = {
		"pattern": "fill", "shape": "rectangle",
		"at": {"x": 0, "y": 0, "z": 0},
		"across": 40, "deep": 24, "wall": 1, "layers": 12, "rise": 3,
		"color": 71, "mix_color": 72, "masonry": 0.5,
	}
	var trouble: Array = []
	var made: Array = Patterns.expand([wall], [], trouble, _library)
	var again: Array = Patterns.expand([wall], [], [], _library)
	var dark: int = 0
	var stone: int = 0
	var plain: int = 0
	var facing_in: int = 0
	for raw: Variant in made:
		var one: Dictionary = raw
		if int(one["color"]) == 72:
			dark += 1
		var part: String = str(one["part"])
		if part == "3004" or part == "3010":
			plain += 1
		if part == "98283" or part == "15533":
			stone += 1
			# Out is away from the middle, at x 20 and z 12.
			var rot: int = int(one.get("rot", 0))
			var out: bool
			if rot == 0:
				out = float(one["z"]) >= 12.0
			elif rot == 2:
				out = float(one["z"]) < 12.0
			elif rot == 1:
				out = float(one["x"]) >= 20.0
			else:
				out = float(one["x"]) < 20.0
			if not out:
				facing_in += 1
	_check("about a seventh of it in the second grey when no share is said, %d of %d"
		% [dark, made.size()], trouble.is_empty()
			and dark * 100 > made.size() * 9 and dark * 100 < made.size() * 22)
	_check("about half the 1x2s and 1x4s laid as masonry, %d of %d"
		% [stone, stone + plain], stone * 100 > (stone + plain) * 35
			and stone * 100 < (stone + plain) * 65)
	_check("...every one with its stonework facing out, %d facing in"
		% facing_in, stone > 0 and facing_in == 0)
	_check("and the same wall every time, which a check and a build need",
		str(made) == str(again))
	_check("a share over a half is held to a half",
		_dark_share({"mix_color": 72, "mix": 0.9}) <= 0.55)


func _dark_share(extra: Dictionary) -> float:
	var wall: Dictionary = {"pattern": "fill", "shape": "rectangle",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 20, "deep": 12, "wall": 1,
		"layers": 6, "rise": 3, "color": 71}
	wall.merge(extra)
	var made: Array = Patterns.expand([wall], [], [], _library)
	var dark: int = 0
	for raw: Variant in made:
		if int((raw as Dictionary)["color"]) == 72:
			dark += 1
	return float(dark) / maxf(1.0, float(made.size()))


func _cells_of(one: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var info: PartLibrary.PartInfo = _library.parts.get(str(one["part"]))
	if info == null:
		return cells
	var footprint: Vector2i = info.footprint_studs()
	var wide: int = footprint.x
	var deep: int = footprint.y
	if int(one.get("rot", 0)) % 2 == 1:
		var swap: int = wide
		wide = deep
		deep = swap
	for i: int in wide:
		for j: int in deep:
			cells.append(Vector2i(int(one["x"]) + i, int(one["z"]) + j))
	return cells


## A fill that lays wedges has to know which cells of a wedge's
## footprint it covers and which it leaves to the outside of the shape.
## Writing that down by hand is how a model gets two left wings, so it
## is read off each part's own top studs — and the handedness falls out
## of the arithmetic rather than being asserted.
func _wedges_read_off_the_parts() -> void:
	print("")
	print("  wedge shapes, read off the parts themselves")
	var shapes_read: Dictionary = Patterns.wedge_shapes(_library)
	_check("every wedge in the list has a shape, %d of them"
		% shapes_read.size(), shapes_read.size() == Patterns.WEDGES.size() * 4)

	# The one shape worth writing out, because every other check here
	# would pass on a table of empty sets.
	var drawn_as: String = _draw(shapes_read.get("3936 0", []))
	_check("Wing 4 x 4 Left is %s" % drawn_as,
		drawn_as == "###. / ###. / ##.. / #...")
	# And its twin is the mirror of it, which is the whole reason the
	# shapes are derived rather than typed.
	_check("...and Wing 4 x 4 Right is the mirror of it, %s"
		% _draw(shapes_read.get("3935 0", [])),
		_draw(shapes_read.get("3935 0", [])) == ".### / .### / ..## / ...#")

	# Every shape has a mirror twin somewhere in the family. Without
	# that, laying wedges in pairs could not be guaranteed — and the
	# first attempt at this laid them greedily and threw out the ones
	# that came up unpaired, which was all of them.
	var twinless: int = 0
	for named: String in shapes_read:
		if Patterns.wedge_mirror_of(_library, named).is_empty():
			twinless += 1
			if twinless <= 3:
				print("        %s has no twin" % named)
	_check("every shape has a mirror twin, %d without" % twinless,
		twinless == 0)

	# The trap that cost the first attempt: a right hand's own corner
	# cell is never one of its studs, so a candidate position taken
	# from the shape's cells can only ever place left hands.
	var right_hand: Array = shapes_read.get("3935 0", [])
	_check("a right hand does not cover its own low corner, which is "
		+ "why positions are tried over the whole box",
		not right_hand.is_empty()
			and not (right_hand[2] as Dictionary).has(Vector2i(0, 0)))


## A shape as "###. / ##.. / ...", for a message somebody can read.
func _draw(shape: Array) -> String:
	if shape.is_empty():
		return "(nothing)"
	var across: int = shape[0]
	var deep: int = shape[1]
	var cells: Dictionary = shape[2]
	var rows := PackedStringArray()
	for j: int in deep:
		var row: String = ""
		for i: int in across:
			row += "#" if cells.has(Vector2i(i, j)) else "."
		rows.append(row)
	return " / ".join(rows)


## Are the wedges laid symmetrically, as a property of the output?
##
## Not "does the checker complain": its symmetry advice forgives up to
## three lonely bricks, so one unpaired wedge can slip under it — tested,
## an ellipse laid with only the across-mirror came back eighteen parts
## and no complaint. The invariant is stronger and deterministic: reflect
## every cell the wedges cover about the shape's middle across, and about
## its middle deep, and the set has to map onto itself.
func _wedges_go_in_symmetrically() -> void:
	print("")
	print("  and they go in symmetrically, which is a property not an opinion")
	for size: Array in [[16, 12], [20, 16], [26, 32]]:
		var wanted: Dictionary = {}
		for x: int in int(size[0]):
			for z: int in int(size[1]):
				var u: float = (float(x) + 0.5) / (float(size[0]) / 2.0) - 1.0
				var v: float = (float(z) + 0.5) / (float(size[1]) / 2.0) - 1.0
				if u * u + v * v <= 1.0:
					wanted[Vector2i(x, z)] = true
		var low := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
		var high := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
		for key: Variant in wanted:
			var at: Vector2i = key
			low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
			high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
		var laid_cells: Dictionary = {}
		var made: Array = Patterns._lay_wedges(wanted, 0.0, 71, {},
			laid_cells, _library)
		# Vacuous otherwise: an empty set is symmetric about anything.
		_check("%d x %d lays wedges at all, %d of them"
			% [size[0], size[1], made.size()], made.size() > 0)
		if made.is_empty():
			continue
		var mapped: int = 0
		for key: Variant in laid_cells:
			var at: Vector2i = key
			if laid_cells.has(Vector2i(low.x + high.x - at.x, at.y)) \
					and laid_cells.has(Vector2i(at.x,
						low.y + high.y - at.y)):
				mapped += 1
		_check("...and every one of its %d studs has its reflection in "
			% laid_cells.size() + "both directions, %d of %d"
			% [mapped, laid_cells.size()], mapped == laid_cells.size())
