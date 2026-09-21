## Can a built model be changed without being described again?
##
##   godot --headless --path . --script src/dev/edit_probe.gd
##
## The old answer to "make the roof blue" was to re-emit every
## placement with one colour changed. That is expensive for a large
## model and lossy for any model: a list rewritten from a description
## of itself drifts, and the change asked for arrives with a dozen
## nobody asked for.
##
## What matters here is that a patch touches what it names and nothing
## else, that a patch which would not stand up changes nothing at all,
## and that a brick somebody placed by hand is still theirs afterwards.
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

	# Three bricks in a stack, built the ordinary way.
	var start := Assistant.Model.new()
	for y: int in 3:
		start.placements.append(Assistant.Placement.from_dict({
			"part": "3001", "color": 4, "x": 0, "y": y * 3, "z": 0}))
	assistant._apply(start)
	var ids: Array = _ids(world)
	print("  built %d bricks: %s" % [ids.size(), ids])
	print("")

	# A colour change touches one brick and leaves the rest alone.
	_edit(assistant, "recolour the middle brick", {
		"recolor": [{"bricks": [ids[1]], "color": 1}]})
	_expect_colours(world, "one blue among two red", [4, 1, 4])

	# And the numbers survive it. This is the whole reason the edit is a
	# diff rather than a rebuild: a model that reads the numbers once
	# and then makes two changes has its second change land on whatever
	# holds those numbers afterwards. Renumber, and that is other
	# bricks, silently.
	if _ids(world) == ids:
		print("        the numbers are still the numbers")
	else:
		_failures += 1
		print("  FAIL  editing renumbered the model: %s became %s"
			% [ids, _ids(world)])

	# Taking the top one off leaves two standing.
	_edit(assistant, "remove the top brick", {"remove": [ids[2]]})
	_expect_count(world, "two left", 2)

	# Adding puts it back.
	_edit(assistant, "add one on top", {"add": [
		{"part": "3001", "color": 14, "x": 0, "y": 6, "z": 0}]})
	_expect_count(world, "three again", 3)

	# A move that would leave a brick in mid-air is refused, and refusing
	# it must leave the model exactly as it was rather than half-changed.
	var before: Array = _shape(world)
	_edit(assistant, "shove the top brick into the air", {
		"move": [{"bricks": [_ids(world)[2]], "dy": 6}]}, false)
	if _shape(world) == before:
		print("  ok    a refused change left the model untouched")
	else:
		_failures += 1
		print("  FAIL  a refused change altered the model")

	# A brick placed by hand stays the person's across an edit, or the
	# next design would quietly throw it away as its own work.
	var hand: int = world.add_brick("3005", 2, Transform3D(
		Basis.IDENTITY, Vector3(100, 24, 20)))
	builder.register(hand, "3005", world.get_brick(hand).transform)
	var mine_before: int = assistant.built_count()
	_edit(assistant, "recolour a brick with one placed by hand present", {
		"recolor": [{"bricks": [_ids(world)[0]], "color": 2}]})
	if assistant.built_count() == mine_before:
		print("  ok    the hand-placed brick is still not the assistant's")
	else:
		_failures += 1
		print("  FAIL  the assistant adopted a brick it did not place "
			+ "(%d then, %d now)" % [mine_before, assistant.built_count()])

	# An edit made while a streamed sketch is on the baseplate.
	#
	# The sketch is ordinary bricks with ordinary numbers, and an edit
	# is built from a reading of the world that includes them. Treating
	# them as a separate thing to be cleared first deleted the bricks
	# the edit had just asked to keep.
	# clear_built leaves the hand-placed brick alone, which is the whole
	# point of it, so that one is still standing here.
	assistant.clear_built()
	var by_hand: int = world.brick_count()
	var sketch: Array[Assistant.Placement] = []
	for y: int in 3:
		sketch.append(Assistant.Placement.from_dict({
			"part": "3001", "color": 2, "x": 0, "y": y * 3, "z": 0}))
	assistant._begin_sketch()
	for placement: Assistant.Placement in sketch:
		assistant._sketch_one(placement)
	if world.brick_count() != by_hand + 3:
		_failures += 1
		print("  FAIL  the sketch put %d bricks up, wanted %d"
			% [world.brick_count(), by_hand + 3])

	var sketched_ids: Array = _ids(world)
	_edit(assistant, "recolour a brick that is still only a sketch", {
		"recolor": [{"bricks": [sketched_ids[0]], "color": 14}]})
	if world.brick_count() == by_hand + 3 and _ids(world) == sketched_ids:
		print("        all three survived, with their numbers")
	else:
		_failures += 1
		print("  FAIL  editing a sketch left %d bricks, wanted %d: %s"
			% [world.brick_count(), by_hand + 3, _ids(world)])
	if assistant.built_count() == 3:
		print("        and the assistant owns all three")
	else:
		_failures += 1
		print("  FAIL  the assistant owns %d of 3 after editing its sketch"
			% assistant.built_count())

	print("")
	_someone_elses_bricks(assistant, world, builder, library)
	_unknown_numbers(assistant, world)
	_pieces(assistant)

	print("")
	if _failures == 0:
		print("a model can be changed in place")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _ids(world: BrickWorld) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		out.append(brick.id)
	out.sort()
	return out


func _shape(world: BrickWorld) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		out.append("%s %d %s" % [
			brick.part_id, brick.color_code, brick.transform.origin])
	out.sort()
	return out


func _edit(assistant: Assistant, what: String, args: Dictionary,
		want_ok: bool = true) -> void:
	var edited: Assistant.Model = assistant._edit(args)
	# An edit is the whole of what will be on the baseplate, which is
	# what the second argument says. Without it the check puts the
	# hand-placed brick into the lattice as something to avoid, and the
	# edit — which contains that brick — is refused for overlapping it.
	var verdict: Dictionary = assistant._check(edited, true)
	var ok: bool = bool(verdict["ok"])
	if ok:
		assistant._apply_edit(edited)
	if ok == want_ok:
		print("  ok    %s — %s" % [what, verdict["summary"]])
	else:
		_failures += 1
		print("  FAIL  %s: wanted %s, got %s" % [
			what, "applied" if want_ok else "refused", verdict["summary"]])


func _expect_count(world: BrickWorld, what: String, want: int) -> void:
	if world.brick_count() == want:
		print("        %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s: %d bricks, wanted %d"
			% [what, world.brick_count(), want])


func _expect_colours(world: BrickWorld, what: String, want: Array) -> void:
	var got: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		got.append(brick.color_code)
	got.sort()
	var wanted: Array = want.duplicate()
	wanted.sort()
	if got == wanted:
		print("        %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s: colours %s, wanted %s" % [what, got, wanted])


## An edit that names nothing real must say so rather than say "done".
func _unknown_numbers(assistant: Assistant, world: BrickWorld) -> void:
	var edited: Assistant.Model = assistant._edit({
		"recolor": [{"bricks": [90001, 90002], "color": 1}]})
	if assistant._touched == 0 and assistant._unknown.size() == 2:
		print("  ok    an edit that names nothing real changes nothing")
	else:
		_failures += 1
		print("  FAIL  an edit naming two bricks that do not exist "
			+ "touched %d and reported %d unknown"
			% [assistant._touched, assistant._unknown.size()])
	if edited.placements.size() != world.brick_count():
		_failures += 1
		print("  FAIL  it also changed how many bricks there are")


## And a design in two halves is noticed, without being refused.
func _pieces(assistant: Assistant) -> void:
	var model := Assistant.Model.new()
	for raw: Variant in [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0},
		{"part": "3001", "color": 1, "x": 10, "y": 0, "z": 0},
	]:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = assistant._check(model, true)
	if int(verdict.get("pieces", 0)) == 2:
		print("  ok    a model in two halves is counted as two pieces")
	else:
		_failures += 1
		print("  FAIL  two separated stacks counted as %d piece(s)"
			% int(verdict.get("pieces", -1)))
	if not bool(verdict["ok"]):
		_failures += 1
		print("  FAIL  and it was refused for it: %s" % verdict["summary"])
	else:
		print("  ok    and it is not refused for it")


## A submitted design does not get to stand where somebody else's brick
## already is.
##
## A submission replaces the assistant's work and leaves the rest of the
## baseplate alone, so the check has to know about the rest of the
## baseplate. Checking against an empty lattice declared a design
## buildable while it was sitting inside a brick the person had placed,
## and then registered over its cells — leaving that brick holding no
## cells at all once the assistant's next design released them.
func _someone_elses_bricks(assistant: Assistant, world: BrickWorld,
		builder: Builder, library: PartLibrary) -> void:
	assistant.clear_built()
	for brick: BrickWorld.Brick in world.bricks().duplicate():
		builder.lattice.release(brick.id)
		world.remove_brick(brick.id)

	var at := Transform3D(Basis.IDENTITY, Vector3(40.0, 24.0, 20.0))
	var hand: int = world.add_brick("3001", 2, at)
	builder.register(hand, "3001", at)

	var model := Assistant.Model.new()
	model.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0}))
	var verdict: Dictionary = assistant._check(model)
	if bool(verdict["ok"]):
		_failures += 1
		print("  FAIL  a design standing inside a hand-placed brick "
			+ "was called buildable")
	else:
		print("  ok    a design cannot stand where somebody else's brick is")

	# And one beside it is fine.
	var beside := Assistant.Model.new()
	beside.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 8, "y": 0, "z": 0}))
	if bool(assistant._check(beside)["ok"]):
		print("  ok    and one beside it is fine")
	else:
		_failures += 1
		print("  FAIL  a design clear of it was refused anyway: %s"
			% assistant._check(beside)["feedback"])

	builder.lattice.release(hand)
	world.remove_brick(hand)
