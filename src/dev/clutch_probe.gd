## Would the bricks actually hold each other?
##
##   godot --headless --path . --script src/dev/clutch_probe.gd
##
## The lattice is 2 LDU and the connection system is 20, so there are
## positions that are legal on the grid and impossible in plastic. Two
## of them were being called "buildable":
##
##   a 2x4 on a 2x4, shifted three tenths of a stud sideways, where no
##   stud can reach a tube
##   a brick standing on a tile, which grips nothing and falls off the
##   moment the model is lifted
##
## And a third that was passed until 2026-10-11: a plate half a stud
## along a plain plate. Half a stud grips only on a jumper's stud, so it
## is asked of the studs under the part, not of the grid.
##
## Since 2026-10-14 (ExactCheck) a part a few LDU off its studs is seated on
## them as it is checked. One standing square on a smooth face comes away in
## the hand, a fault, unless it is a tile laid on one (rest181, 2026-10-23). The
## thing this probe guards hardest is that it stays quiet about the eight
## models that ship with the app, which are known good.
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

	_check_offsets(assistant)
	_check_halves(assistant)
	_check_smooth(assistant)
	_check_the_known_good(assistant, library)

	print("")
	if _failures == 0:
		print("positions that cannot be built are named, and good models are left alone")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


## What the checker says about a two-brick stack, and whether it passed.
func _stack(assistant: Assistant, lower: String, upper: String,
		across: float, up: float) -> Dictionary:
	var model := Assistant.Model.new()
	var under := Assistant.Placement.new()
	under.part = lower
	under.color = 4
	model.placements.append(under)
	var over := Assistant.Placement.new()
	over.part = upper
	over.color = 1
	over.x = across
	over.y = up
	model.placements.append(over)
	var report: Dictionary = assistant._check(model, true)
	var said: String = str(report.get("feedback", ""))
	return {
		"off_grid": said.contains("studs across and"),
		"said": said,
		"smooth": said.contains("no stud anywhere to grip"),
		"ok": bool(report.get("ok", false)),
		## Where the upper one is after the check, which may have seated it.
		"x": over.x,
	}


func _check_offsets(assistant: Assistant) -> void:
	print("\nstacking a 2x4 on a 2x4, shifted sideways")
	for across: float in [0.0, 1.0, 2.0]:
		var verdict: Dictionary = _stack(assistant, "3001", "3001", across, 3.0)
		_ok(not verdict["off_grid"],
			"%s studs across is a real position and is not questioned" % across)
	# Up to a plate (8 LDU) off its studs, a part is moved onto them as it is
	# checked (ExactCheck.seat), as BrickAgent's attach puts a part by its
	# connector: two round plates on a tower of Orthanc stood a tenth of a
	# stud off with a note beside them, and BrickBench refused crystals 4 LDU
	# off theirs.
	for across: float in [0.1, 0.3, 0.7, 0.9]:
		var seated: Dictionary = _stack(assistant, "3001", "3001", across, 3.0)
		_ok(seated["ok"] and not seated["off_grid"] and str(seated["said"]).contains("Seated")
				and is_equal_approx(float(seated["x"]), roundf(across)),
			"%s studs across is seated on the whole stud nearest, %d: x %s" % [across,
				roundf(across), seated["x"]])
	# On the 2 LDU lattice that leaves one place off the studs and further than
	# a plate from any: half a stud, refused with a jumper offered (below).
	# A part with no stud or tube facing up or down has no grid to be off:
	# the worked fireplace's horns (53451) sit in a brick's studs sideways.
	var horn: Dictionary = _stack(assistant, "3001", "53451", 0.3, 3.0)
	_ok(not horn["off_grid"], "a horn, with no stud grid of its own, is not judged by one")


## Half a stud off is right on a jumper and wrong on a plain plate, and the
## numbers alone cannot tell the two apart: a jumper's one stud stands on
## the half. The checker asks the studs under the part where they landed.
func _check_halves(assistant: Assistant) -> void:
	print("\nhalf a stud off: on a jumper, and on plain studs")
	var plain: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["3022", 0.5, 1, 0, 0]])
	_ok(not plain["ok"] and str(plain["said"]).contains("half a stud off"),
		"a 2x2 plate half a stud along a 2x4 plate is refused")
	_ok(str(plain["said"]).contains("jumper")
			and (str(plain["said"]).contains("at x=0, z=0 it sits on them")
				or str(plain["said"]).contains("at x=1, z=0 it sits on them")),
		"...and told of a jumper, and the whole stud either side")
	var brick: Dictionary = _build(assistant, [
		["3001", 0, 0, 0, 0], ["3001", 0.5, 3, 0, 0]])
	_ok(not brick["ok"] and str(brick["said"]).contains("half a stud off"),
		"so is a 2x4 brick half a stud along a 2x4 brick")
	# Its middle stud is in its tube, and the eight round the edge are
	# against its walls.
	var diagonal: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["3022", 0.5, 1, 0.5, 0]])
	_ok(not diagonal["ok"] and str(diagonal["said"]).contains("half a stud off"),
		"and a 2x2 plate half a stud both ways on a 2x4, one stud in its tube")

	# A 1x2 jumper turned along z puts its stud at 1.5, 1: the 2x2's tube.
	var jumped: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["3794b", 1, 1, 0, 1], ["3022", 0.5, 2, 0, 0]])
	_ok(jumped["ok"] and not str(jumped["said"]).contains("off its studs"),
		"the same 2x2, half a stud along, by its tube on a jumper (3794b) builds")
	var centre: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["87580", 0, 1, 0, 0], ["3023", 0.5, 2, 0.5, 0]])
	_ok(centre["ok"] and not str(centre["said"]).contains("off its studs"),
		"a 1x2 half a stud both ways on a 2x2 jumper (87580), by a socket, builds")
	var carried: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["3794b", 1, 1, 0, 1], ["3022", 0.5, 2, 0, 0],
		["3023", 0.5, 3, 0, 0]])
	_ok(carried["ok"] and not str(carried["said"]).contains("off its studs"),
		"a 1x2 on that jumper-offset 2x2's studs builds")
	# Back on the base plate's grid, it is half a stud off the 2x2 it
	# stands on: that 2x2's stud is on the 1x2's post.
	var back: Dictionary = _build(assistant, [
		["3020", 0, 0, 0, 0], ["3794b", 1, 1, 0, 1], ["3022", 0.5, 2, 0, 0],
		["3023", 1, 3, 0, 0]])
	_ok(not back["ok"] and str(back["said"]).contains("brick 3 (3023"),
		"the 1x2 put back on the base plate's grid, on that 2x2, is refused")


## What the checker says about a few placements, each [part, x, y, z, rot].
func _build(assistant: Assistant, bricks: Array) -> Dictionary:
	var model := Assistant.Model.new()
	for brick: Array in bricks:
		model.placements.append(Assistant.Placement.from_dict({
			"part": brick[0], "color": 71, "x": brick[1], "y": brick[2],
			"z": brick[3], "rot": brick[4]}))
	var report: Dictionary = assistant._check(model, true)
	return {"ok": bool(report.get("ok", false)),
		"said": str(report.get("feedback", ""))}


func _check_smooth(assistant: Assistant) -> void:
	print("\nstanding something on a face with nothing to grip it")
	var tile: Dictionary = _stack(assistant, "3068b", "3003", 0.0, 1.0)
	_ok(tile["smooth"], "a brick on a 2x2 tile is told the tile grips nothing")
	# Standing square on the tile it stays while the model stands, as
	# BrickBench's simulation finds, and falls off when it is lifted: a brick
	# is made to be held, so it missed (ExactCheck.set_down).
	_ok(not tile["ok"], "...and it comes away in the hand, so the design does not pass")
	# A tile laid on a tile is set down on purpose, as sets lay a loose printed
	# tile on a table: advice, said.
	var laid: Dictionary = _stack(assistant, "3068b", "3068b", 0.0, 1.0)
	_ok(laid["ok"], "a tile on a tile is advice, so the design still passes")

	var brick: Dictionary = _stack(assistant, "3003", "3003", 0.0, 3.0)
	_ok(not brick["smooth"], "a brick on a brick is not")

	# A hinge base has no studs either, and holds perfectly well — by a
	# hinge, which the library has no connector kind for. Both hinges in
	# models/car.ldr were complained about before this was narrowed to
	# the categories where a smooth top really means nothing grips.
	var hinge: Dictionary = _stack(assistant, "3937", "3938", 0.0, 1.0)
	_ok(not hinge["smooth"], "nor is a hinge top on a hinge base")


func _check_the_known_good(assistant: Assistant, library: PartLibrary) -> void:
	print("\nthe eight models that ship with the app")
	var noisy: int = 0
	# models/kart.ldr is deliberately not in this list. It carries its
	# steering column as an angled section, and the conversion below is
	# square-only — a section's bricks come back with placements that
	# mean nothing, so it would measure the conversion rather than the
	# advice. instructions_probe drives the kart instead, where the
	# ordering question does not need placements at all.
	for name: String in ["bench", "boat", "car", "house", "lighthouse",
			"rocket", "tower", "tree"]:
		var ldr: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		if ldr == null:
			_ok(false, "%s could not be read" % name)
			continue
		var model := Assistant.Model.new()
		for piece: LdrModel.Placement in ldr.flatten():
			var put := Assistant.Placement.new()
			put.part = piece.part_id.to_lower().trim_suffix(".dat")
			put.color = piece.color_code
			var part: Lbm.PartMesh = library.mesh_for(put.part)
			if part == null:
				continue
			# Inverting _square_transform rather than guessing. A
			# placement's x is the part's corner cell; an LDraw origin is
			# wherever the author put it, so dividing one by a stud gives
			# half-stud nonsense for a 1x1 and invented six offsets that
			# were not in the models at all.
			var corner: Vector3i = assistant._corner_cell(
				part, put.part, piece.transform.basis)
			var cell: Vector3i = BrickLattice.to_cell(
				piece.transform.origin) + corner
			put.x = float(cell.x) / float(BrickLattice.CELLS_PER_STUD)
			put.y = float(cell.y) / float(BrickLattice.CELLS_PER_PLATE)
			put.z = float(cell.z) / float(BrickLattice.CELLS_PER_STUD)
			model.placements.append(put)
		var said: String = str(assistant._check(model, true).get("feedback", ""))
		var found: int = said.count("studs across and") \
			+ said.count("no stud anywhere to grip")
		noisy += found
		print("     %-11s %3d bricks, %d complaint%s" % [
			name, model.placements.size(), found, "" if found == 1 else "s"])
	_ok(noisy == 0,
		"nothing to say about any of them (%d complaint%s)" % [
			noisy, "" if noisy == 1 else "s"])
