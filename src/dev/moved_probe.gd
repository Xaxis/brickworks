## Does a model end up holding numbers that still mean something?
##
##   godot --headless --path . --script src/dev/moved_probe.gd
##
## LDraw keeps a stub for every part number it has retired: 4073 is now
## "~Moved to 6141". The stub renders perfectly, because its geometry is
## a reference to the part that replaced it — so a model built on an old
## number looks right and is wrong underneath.
##
## Where that shows is the reading, not the picture. The parts list
## printed "~Moved to 3023b" in the column where a name goes, six times,
## and the instruction booklet says it too. Anyone using either to buy
## the bricks is handed a sentence instead of a part.
##
## Search already declines to suggest them. This is about the numbers
## that arrive another way: out of somebody else's file, or out of a
## design that knows 4073 from memory.
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
	await process_frame

	# Retired numbers taken from the catalogue itself rather than
	# written down here, so the probe cannot go stale against it.
	var moved: Array[String] = []
	for part_id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		if info.is_redirect() and library.parts.has(info.moved_to) \
				and not library.parts[info.moved_to].is_redirect():
			moved.append(part_id)
		if moved.size() >= 6:
			break

	if moved.is_empty():
		print("  no retired numbers in this catalogue")
		quit(0)
		return

	for part_id: String in moved:
		var info: PartLibrary.PartInfo = library.parts[part_id]
		var says: String = library.resolve(part_id)
		if says == part_id:
			_failures += 1
			print("  FAIL  %s is \"%s\" and resolved to itself"
				% [part_id, info.name.strip_edges()])
			continue
		print("  ok    %-9s (%s) resolves to %s"
			% [part_id, info.name.strip_edges(), says])

	# And a brick placed by that number keeps the number that means
	# something, so the parts list and the booklet read properly.
	var at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var landed: int = 0
	for part_id: String in moved:
		var brick_id: int = world.add_brick(part_id, 4,
			Transform3D(Basis.IDENTITY, Vector3(landed * 200.0, 0.0, 0.0)))
		if brick_id == 0:
			continue
		landed += 1
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var name: String = library.parts[brick.part_id].name.strip_edges()
		# A redirect or an alias, specifically. A leading ~ also marks a
		# subpart — a winch drum, a door panel that only exists inside
		# another part — and those are real geometry with a real name,
		# not a sentence standing in for one. Lumping them together made
		# this probe fail on a correct resolution.
		if name.to_lower().begins_with("~moved") or name.begins_with("="):
			_failures += 1
			print("  FAIL  placing %s gave a brick whose name is \"%s\""
				% [part_id, name])
		else:
			print("  ok    placing %s gives %s, \"%s\""
				% [part_id, brick.part_id, name])

	print("")
	if _failures == 0:
		print("a placed brick is a part somebody could buy")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
