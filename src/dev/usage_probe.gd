## Does search lead with the part real sets reach for?
##
##   godot --headless --path . --script src/dev/usage_probe.gd
##
## The ranking was built out of what a part's name looks like, carefully
## and over many measured queries, and a name can only say so much. It
## cannot say that 3062b — "Brick 1 x 1 Round with Hollow Stud" — is in
## four and a half thousand sets while 71075a, named just as plainly, is
## in seventeen. Thirty thousand set inventories can say that.
##
## Measured over thirty-five ordinary queries: twelve led with the part
## real sets use most and the leader carried 71% of the usage the best
## match had; sixteen and 81% once usage counted.
##
## The guard at the end is the one that matters. Usage must order parts
## *within* what was asked for and never over it: "plate 4 x 4" has to
## go on leading with the 4 x 4, which is in 3,603 sets, and not with
## the 2 x 4 that is in 7,969.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("\nwhat the catalogue knows about what gets used")
	var known: int = 0
	for id: String in library.ids():
		if (library.parts[id] as PartLibrary.PartInfo).in_sets > 0:
			known += 1
	_ok(known > 4000, "%d parts carry a set count" % known)
	_ok(known < library.parts.size() / 2,
		"and most of the library does not, so a zero is silence (%d of %d)"
			% [known, library.parts.size()])

	var staples: Array[PartLibrary.PartInfo] = library.staples(30)
	_ok(staples.size() == 30, "the thirty staples are there")
	_ok(staples[0].id == "3023b" or staples[0].id == "3023",
		"led by the 1x2 plate (%s, %d sets)"
			% [staples[0].id, staples[0].in_sets])
	# The whole lesson of the list, asserted rather than asserted of me.
	var plates: int = 0
	for info: PartLibrary.PartInfo in staples.slice(0, 10):
		if info.name.to_lower().contains("plate"):
			plates += 1
	_ok(plates >= 6, "%d of the ten most used parts are plates" % plates)
	var brick_2x4: int = -1
	for n: int in staples.size():
		if staples[n].id == "3001":
			brick_2x4 = n + 1
	_ok(brick_2x4 > 15,
		"and the 2x4 brick everyone pictures is number %d" % brick_2x4)

	print("\nthe queries a name could not answer")
	_leads(library, "round brick 1 x 1", "3062b", 71075)
	_leads(library, "hinge", "3937", 0)
	_leads(library, "antenna", "3957a", 0)
	_leads(library, "jumper", "", 0)

	print("\nand what it must not do")
	# A size in the query is never decoration. The 2x4 plate is in twice
	# as many sets as the 4x4 and must still not answer this.
	var square: Array[PartLibrary.PartInfo] = library.search("plate 4 x 4", 3)
	_ok(not square.is_empty() and square[0].id == "3031",
		"\"plate 4 x 4\" still leads with the 4x4, not the commoner 2x4 (%s)"
			% ("nothing" if square.is_empty() else square[0].id))
	# Asked for by number, a part nobody has data about is still first.
	var by_number: Array[PartLibrary.PartInfo] = library.search("71075a", 3)
	_ok(not by_number.is_empty() and by_number[0].id == "71075a",
		"a part in seventeen sets is still found by its number")

	print("\nand the model is told what sets are made of")
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	get_root().add_child(assistant)
	await process_frame
	var rules: String = assistant.guidance()
	_ok(rules.contains("THE PARTS REAL SETS ARE MADE OF"),
		"the prompt carries the list")
	_ok(rules.contains("3023b") and rules.contains("54200"),
		"...with the parts in it")
	_ok(rules.contains("mostly plates"), "...and what it means")

	print("")
	if _failures == 0:
		print("search leads with the part a real set would use")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## The leader for a query, and that it is a part sets really use.
func _leads(library: PartLibrary, query: String, want: String,
		_was: int) -> void:
	var found: Array[PartLibrary.PartInfo] = library.search(query, 1)
	if found.is_empty():
		_ok(false, "\"%s\" found nothing" % query)
		return
	var first: PartLibrary.PartInfo = found[0]
	if not want.is_empty():
		_ok(first.id == want, "\"%s\" leads with %s, in %d sets"
			% [query, first.id, first.in_sets])
	else:
		# No single right answer, but it may not be an oddity.
		_ok(first.in_sets > 1000, "\"%s\" leads with %s, in %d sets"
			% [query, first.id, first.in_sets])


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
