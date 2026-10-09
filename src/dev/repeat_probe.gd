## Can a model say something too large to dictate?
##
##   godot --headless --path . --script src/dev/repeat_probe.gd
##
## The lattice holds fifty thousand bricks. A reply holds about a
## thousand. Everything between those two numbers was unreachable, not
## because it could not be built but because it could not be said.
##
## A real seven thousand part set is a few hundred distinct parts and a
## great deal of repetition, so the way to say one is to describe a
## module and repeat it. This is the proof that a short description
## reaches ten thousand bricks and that the copies land where they
## should.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	print("\none bay, said seven times")
	var row: Assistant.Model = assistant._read_model(_bay(1, 6, {
		"from": "bay", "times": 6, "dx": 20.0}))
	_ok(assistant._repeat_trouble.is_empty(),
		"no complaint: %s" % _said(assistant))
	_ok(row.placements.size() == 7 * 5,
		"35 bricks from 5 described (%d)" % row.placements.size())
	_ok(row.sections.size() == 7,
		"seven sections (%d)" % row.sections.size())
	var furthest: Assistant.Section = row.sections.get("bay 7")
	_ok(furthest != null and is_equal_approx(furthest.x, 120.0),
		"the last copy is 120 studs along (%s)"
		% ("missing" if furthest == null else str(furthest.x)))
	var ids: int = 0
	for put: Assistant.Placement in row.placements:
		if put.id != 0:
			ids += 1
	_ok(ids == 0, "no copy carries a brick number, so none can be removed by one")

	print("\nturned about its own origin, not slid along")
	var ring: Assistant.Model = assistant._read_model(_bay(1, 7, {
		"from": "bay", "times": 7, "degrees": 45.0, "axis": "y"}))
	var round_the_back: Assistant.Section = ring.sections.get("bay 5")
	_ok(round_the_back != null and is_equal_approx(round_the_back.degrees, 180.0),
		"the fifth of eight faces backwards (%s)"
		% ("missing" if round_the_back == null else str(round_the_back.degrees)))

	print("\nwhat it says when it cannot")
	var nothing: Assistant.Model = assistant._read_model(_bay(1, 1, {
		"from": "nacelle", "times": 4}))
	_ok(_said(assistant).contains("no section called"),
		"a section that was never declared is named as such")
	_ok(_said(assistant).contains("bay"),
		"...along with the ones that were")
	_ok(nothing.placements.size() == 5, "and nothing is copied")

	var empty: Dictionary = _bay(1, 1, {"from": "annexe", "times": 4})
	empty["sections"].append({"name": "annexe", "x": 0, "y": 0, "z": 0,
		"axis": "y", "degrees": 0})
	assistant._read_model(empty)
	_ok(_said(assistant).contains("no bricks in it"),
		"a section declared but never filled is told so")

	assistant._read_model(_bay(1, 1, {"from": "bay", "times": 9999}))
	_ok(_said(assistant).contains("is the most"),
		"a mistyped times= is refused: %s" % _said(assistant).substr(0, 60))

	print("\nten thousand bricks from two hundred and fifty")
	var began: int = Time.get_ticks_msec()
	var wall: Assistant.Model = assistant._read_model(_bay(50, 39, {
		"from": "bay", "times": 39, "dx": 20.0}))
	var spent: int = Time.get_ticks_msec() - began
	_ok(assistant._repeat_trouble.is_empty(),
		"no complaint: %s" % _said(assistant))
	_ok(wall.placements.size() == 10000,
		"%d bricks, said in 250" % wall.placements.size())
	print("     expanded in %d ms" % spent)

	# A quarter of the wall first, because what this has to prove is the
	# shape of the curve and not a number on a clock.
	#
	# A wall clock measures the machine. This one said 22 seconds alone
	# and 68 in a suite run beside somebody else's video encode, on a
	# box at load 164 — and the threshold failed while nothing about the
	# check had changed. A ratio divides the machine out.
	#
	# What it pins is that the check stays about linear in the number of
	# bricks. What it does not pin is the staircase scan, and it is
	# worth saying so rather than letting it look guarded: that scan was
	# quadratic in the model's *width*, and with it restored this ratio
	# reads 5.0 against 4.2 — the same quadratic sits in both
	# measurements and nearly divides out. Isolating width at a fixed
	# brick count was tried and confounds width with height, because
	# holding the bricks and narrowing the wall makes it taller. The
	# 108-second-to-22 improvement was measured directly, once, and
	# rules_probe is what guards the answers it gave.
	var quarter: Assistant.Model = assistant._read_model(_bay(50, 9, {
		"from": "bay", "times": 9, "dx": 20.0}))
	_ok(quarter.placements.size() == 2500,
		"%d bricks to compare against" % quarter.placements.size())
	began = Time.get_ticks_msec()
	assistant._check(quarter, true)
	var small: int = maxi(1, Time.get_ticks_msec() - began)
	began = Time.get_ticks_msec()
	var report: Dictionary = assistant._check(wall, true)
	var checked: int = maxi(1, Time.get_ticks_msec() - began)
	print("     2,500 bricks checked in %d ms, 10,000 in %d — %.1f times"
		% [small, checked, float(checked) / float(small)])
	_ok(bool(report.get("ok", false)),
		"and the whole wall holds together")
	# Ten, between the four of linear and the sixteen of quadratic. The
	# ratio read 4.2, 4.9 and 7.3 on three runs of the same code on a
	# loaded machine, so a threshold near four is a flapping check
	# rather than a strict one.
	_ok(float(checked) / float(small) < 10.0,
		"four times the bricks costs %.1f times the work" \
			% (float(checked) / float(small)))


	print("\nand reaches the baseplate")
	began = Time.get_ticks_msec()
	assistant._apply(wall)
	await process_frame
	print("     built in %d ms" % (Time.get_ticks_msec() - began))
	var built: int = 0
	var furthest_x: float = 0.0
	var tallest: float = 0.0
	for brick: BrickWorld.Brick in world.bricks():
		built += 1
		furthest_x = maxf(furthest_x, brick.transform.origin.x)
		tallest = maxf(tallest, brick.transform.origin.y)
	_ok(built == 10000, "%d bricks really on the baseplate" % built)
	# 39 copies at 20 studs is 780, and the far brick of a bay is 16
	# studs further along again. One stud is 20 LDU.
	_ok(absf(furthest_x - (780.0 + 18.0) * 20.0) < 60.0,
		"the last bay stands 780 studs along (%.0f LDU)" % furthest_x)
	_ok(tallest > 48.0 * 8.0,
		"and the wall is fifty courses high (%.0f LDU)" % tallest)

	print("\nand one call's complaint is not the next call's problem")
	# A real run reported "155 problems (floating 125, overlap 17,
	# pattern 13)" about an edit. An edit takes no patterns at all, and
	# _check reads _pattern_trouble whatever produced it — so the
	# thirteen complaints belonged to the check_design before it and
	# were being re-reported as the edit's own, every time, for the rest
	# of the run.
	assistant._read_model({
		"name": "x", "description": "x", "bricks": [],
		"patterns": [{"pattern": "repeat", "times": 2}],
	})
	_ok(not assistant._pattern_trouble.is_empty(),
		"a pattern with nothing to repeat is complained about")
	var after: Assistant.Model = assistant._edit({"add": [
		{"part": "3001", "color": 7, "x": 0, "y": 0, "z": 0}]})
	_ok(assistant._pattern_trouble.is_empty(),
		"and an edit does not inherit it")
	var verdict: Dictionary = assistant._check(after, true)
	_ok(not str(verdict.get("summary", "")).contains("pattern"),
		"so the edit is not told about a pattern it never sent: %s"
			% str(verdict.get("summary", "")))

	print("\nand the model is told it exists")
	# A capability nothing mentions is a capability nothing uses. This
	# is the only thing standing between the mechanism and a design
	# that dictates a stadium by hand because it does not know better.
	var rules: String = assistant.guidance()
	_ok(rules.contains("repeat_section"), "the prompt names it")
	_ok(rules.contains("from: \"bay\", times: 39"),
		"...with a worked example of a wall")
	_ok(rules.contains("decide what the"),
		"...and says to work at the scale the thing is")

	print("")
	if _failures == 0:
		print("a model too large to dictate is one module and a count")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## A wall bay: 2x4 bricks, five to a course, so many courses high.
func _bay(courses: int, _times: int, repeat: Dictionary) -> Dictionary:
	var bricks: Array = []
	for layer: int in courses:
		for across: int in 5:
			bricks.append({"part": "3001", "color": 7,
				"x": across * 4.0 + (2.0 if layer % 2 == 1 else 0.0),
				"y": layer * 3.0, "z": 0.0, "section": "bay"})
	return {
		"name": "wall", "description": "a wall of bays",
		"sections": [{"name": "bay", "x": 0, "y": 0, "z": 0,
			"axis": "y", "degrees": 0}],
		"bricks": bricks,
		"repeat_section": [repeat],
	}


func _said(assistant: Assistant) -> String:
	return " ".join(PackedStringArray(assistant._repeat_trouble))


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
