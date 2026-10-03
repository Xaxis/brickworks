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
	print("  and nonsense is refused rather than built")
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
