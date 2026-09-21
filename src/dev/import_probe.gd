## Can the app read the format it writes?
##
##   godot --headless --path . --script src/dev/import_probe.gd
##
## It could export an .ldr and then had nowhere to put one back. Which
## is a strange shape for a tool to have: the one file it produces is
## the one file it will not open.
##
## The round trip is the test. Build something, write it out, read it
## back, and every brick has to be the same part in the same colour at
## the same transform — not merely the same number of bricks, which is
## what a broken transform still gives you.
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
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library
	await process_frame

	# Something with a bit of everything: stacked, turned, and laid on
	# its side, because a transform that survives upright bricks and
	# loses sideways ones is the failure worth catching.
	var built: Array[Dictionary] = []
	for case: Array in [
		# Resting on the ground, not with its body through it. A part's
		# origin is the top of its body, so origin zero puts a brick
		# entirely below the baseplate — which the app never produces,
		# and which opening a file now corrects by lifting the model.
		["3001", 4, "up", 0, Vector3(0, 24, 0)],
		["3001", 1, "up", 1, Vector3(40, 48, 0)],
		["3024", 15, "+z", 0, Vector3(0, 40, 60)],
		["3070b", 0, "down", 2, Vector3(80, 40, 20)],
		["3005", 14, "-x", 3, Vector3(20, 60, 40)],
	]:
		var at := Transform3D(
			BrickLattice.basis_for(str(case[2]), int(case[3])), case[4])
		var brick_id: int = world.add_brick(str(case[0]), int(case[1]), at)
		if brick_id == 0:
			print("  skip  %s is not in this library" % case[0])
			continue
		builder.register(brick_id, str(case[0]), at)
		built.append({"part": case[0], "colour": case[1], "at": at})

	var text: String = store.to_text("Round Trip")
	print("  wrote %d bricks as %d lines of LDraw"
		% [built.size(), text.split("\n").size()])

	var result: Dictionary = store.open_text(text, "round_trip.ldr")
	if not str(result["error"]).is_empty():
		_failures += 1
		print("  FAIL  reading it back: %s" % result["error"])
	elif int(result["placed"]) != built.size():
		_failures += 1
		print("  FAIL  wrote %d bricks, read back %d"
			% [built.size(), int(result["placed"])])
	else:
		print("  ok    %d bricks written and %d read back"
			% [built.size(), int(result["placed"])])

	# Same parts, same colours, same places.
	var back: Array[Dictionary] = []
	for brick: BrickWorld.Brick in world.bricks():
		back.append({"part": brick.part_id, "colour": brick.color_code,
			"at": brick.transform})
	for wanted: Dictionary in built:
		var found: bool = false
		for got: Dictionary in back:
			if (got["part"] == wanted["part"]
					and got["colour"] == wanted["colour"]
					and (got["at"] as Transform3D).is_equal_approx(wanted["at"])):
				found = true
				break
		if not found:
			_failures += 1
			print("  FAIL  %s c%d did not survive the round trip"
				% [wanted["part"], wanted["colour"]])
			print("        wrote %s" % [wanted["at"]])
			for got: Dictionary in back:
				if got["part"] == wanted["part"]:
					print("        read  %s" % [got["at"]])
	if _failures == 0:
		print("  ok    every part, colour and transform is unchanged")

	# And a file that is not one. What matters is not only that it is
	# refused but that the model on screen is still there afterwards:
	# tearing the world down and then discovering the file was no good
	# leaves an empty baseplate where somebody's work was.
	var standing: int = world.brick_count()
	for bad: Array in [
		["hello, this is not a model", "not a model at all"],
		["0 Nothing\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 9999999.dat\n",
			"parts that do not exist"],
	]:
		var junk: Dictionary = store.open_text(str(bad[0]), "x")
		if str(junk["error"]).is_empty():
			_failures += 1
			print("  FAIL  opened a file of %s" % bad[1])
		elif world.brick_count() != standing:
			_failures += 1
			print("  FAIL  a file of %s was refused but took the model "
				% bad[1] + "with it (%d bricks left of %d)"
				% [world.brick_count(), standing])
		else:
			print("  ok    a file of %s is refused, and the model stands: %s"
				% [bad[1], junk["error"]])

	print("")
	_other_peoples_files(store, world)

	print("")
	if _failures == 0:
		print("the app reads the format it writes")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## And files written by something other than this.
##
## An .ldr from elsewhere is the whole point of being able to open one,
## and each of these was a silent nothing: a file of tabs parsed to no
## parts at all, a sub-model named with a path was never inlined so the
## sub-assembly vanished, and a direct colour was run through to_int()
## which strips the letters and returns a decimal made of the digits
## that were left.
func _other_peoples_files(store: ModelStore, world: BrickWorld) -> void:
	var tabbed: String = "0 Tabbed\n" \
		+ "1\t4\t0\t0\t0\t1\t0\t0\t0\t1\t0\t0\t0\t1\t3001.dat\n"
	var result: Dictionary = store.open_text(tabbed, "tabbed.ldr")
	_says("a file written with tabs", int(result["placed"]) == 1,
		"%d parts, %s" % [int(result["placed"]), result["error"]])

	# A sub-model whose FILE name carries a directory and an extension,
	# referenced by its bare name.
	var nested: String = "0 FILE main.ldr\n" \
		+ "1 16 0 0 0 1 0 0 0 1 0 0 0 1 sub/roof.ldr\n" \
		+ "0 FILE sub/roof.ldr\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	result = store.open_text(nested, "nested.ldr")
	_says("a sub-model named with a path", int(result["placed"]) == 2,
		"%d parts, %s" % [int(result["placed"]), result["error"]])

	# A direct colour, which is not a palette index.
	var direct: String = "0 Direct\n" \
		+ "1 0x2FF0000 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	result = store.open_text(direct, "direct.ldr")
	var code: int = -999
	for brick: BrickWorld.Brick in world.bricks():
		code = brick.color_code
	_says("a direct colour keeps its brick", int(result["placed"]) == 1,
		"%d parts" % int(result["placed"]))
	_says("...as the colour it was written as, not a decimal made of "
		+ "the digits", code == 0x2FF0000,
		"colour came out as %d, wanted %d" % [code, 0x2FF0000])
	# And back out in the form it came in, or reading it again gives an
	# enormous palette index that nothing has.
	var written: String = store.to_text("Direct")
	_says("...and is written back out as a direct colour",
		written.contains("0x2FF0000"), written.strip_edges())


func _says(what: String, held: bool, detail: String) -> void:
	if held:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s — %s" % [what, detail])
