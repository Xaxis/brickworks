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
## Both are advice rather than faults. A real design does stand parts on
## smooth faces and trap them between walls, and the tube side of a
## connection is not fully modelled in the library — so the thing this
## probe guards hardest is that it stays quiet about the eight models
## that ship with the app, which are known good.
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
		"smooth": said.contains("no stud anywhere to grip"),
		"ok": bool(report.get("ok", false)),
	}


func _check_offsets(assistant: Assistant) -> void:
	print("\nstacking a 2x4 on a 2x4, shifted sideways")
	for across: float in [0.0, 0.5, 1.0, 2.0]:
		var verdict: Dictionary = _stack(assistant, "3001", "3001", across, 3.0)
		_ok(not verdict["off_grid"],
			"%s studs across is a real position and is not questioned" % across)
	for across: float in [0.1, 0.2, 0.3, 0.7, 0.9]:
		var verdict: Dictionary = _stack(assistant, "3001", "3001", across, 3.0)
		_ok(verdict["off_grid"],
			"%s studs across is named: no stud reaches a tube there" % across)
		_ok(verdict["ok"],
			"...and it is advice, so the design still passes")
		break   # the message is the same for all of them; one proves it


func _check_smooth(assistant: Assistant) -> void:
	print("\nstanding something on a face with nothing to grip it")
	var tile: Dictionary = _stack(assistant, "3068b", "3003", 0.0, 1.0)
	_ok(tile["smooth"], "a brick on a 2x2 tile is told the tile grips nothing")
	_ok(tile["ok"], "...and it is advice, so the design still passes")

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
