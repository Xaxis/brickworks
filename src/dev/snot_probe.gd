## Can a part be held by a stud that does not point up?
##
##   godot --headless --path . --script src/dev/snot_probe.gd
##
## Studs-not-on-top is how most of a real model's surface is made: a
## smooth wall, a grille, lettering, a curved bonnet. The rule here used
## to be "something must be in the cell below", which a part clutched by
## a side stud fails by construction — it has air beneath it and always
## will. So every design that tried it was told it was floating, and
## three repairs later the model had learned not to try.
##
## This places the arrangement the rule used to refuse and asserts it is
## now accepted, and — separately — that the part is where the
## coordinates say it is. An orientation that validates but lands
## somewhere else is worse than one that is refused.
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

	print("  a part held by a stud that points sideways")
	print("")

	# 87087 is a 1x1 brick with a stud on one side. Its side stud points
	# along +z and sits 10 LDU below the part's origin, so the plate it
	# holds straddles a plate boundary: y = 0.5, which the old whole-plate
	# grid could not even say.
	_expect(assistant, "a plate on the side stud of an 87087", true, [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "87087", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3024", "color": 15, "x": 0, "y": 3.5, "z": 1,
			"face": "+z", "rot": 0},
	])

	# The same plate one stud further out, touching nothing.
	_expect(assistant, "the same plate moved off the stud", false, [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "87087", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3024", "color": 15, "x": 0, "y": 3.5, "z": 3,
			"face": "+z", "rot": 0},
	])

	# Plain upward building must not have changed.
	_expect(assistant, "two bricks stacked, as before", true, [
		{"part": "3001", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
	])
	_expect(assistant, "a brick floating three plates up", false, [
		{"part": "3001", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 1, "x": 0, "y": 6, "z": 0, "rot": 0},
	])

	print("")
	_corner(assistant, library, "3001", "up", 0)
	_corner(assistant, library, "3001", "up", 1)
	_corner(assistant, library, "3001", "+z", 0)
	_corner(assistant, library, "3001", "-x", 2)
	_corner(assistant, library, "3024", "down", 3)

	print("")
	_roundtrip(assistant, library, world, builder)

	print("")
	_by_hand(builder, world)

	print("")
	if _failures == 0:
		print("sideways building works and upward building is unchanged")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _expect(assistant: Assistant, what: String, want_ok: bool,
		bricks: Array) -> void:
	var model := Assistant.Model.new()
	for raw: Variant in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = assistant._check(model)
	var got: bool = bool(verdict["ok"])
	if got == want_ok:
		print("  ok    %s — %s" % [what, verdict["summary"]])
	else:
		_failures += 1
		print("  FAIL  %s: wanted %s, got %s" % [
			what, "buildable" if want_ok else "refused", verdict["summary"]])
		print("        " + str(verdict["feedback"]).replace("\n", "\n        "))


## The corner rule, checked against the cells the part actually takes up.
##
## A placement that validates but lands elsewhere is the worse failure,
## because nothing reports it: the model is told a brick is at 4,0,2 and
## builds the next one against it, and the two do not meet.
func _corner(assistant: Assistant, library: PartLibrary, part_id: String,
		face: String, rot: int) -> void:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		print("  skip  %s not loaded" % part_id)
		return
	var placement := Assistant.Placement.from_dict({
		"part": part_id, "color": 4, "x": 4, "y": 2, "z": 3,
		"face": face, "rot": rot})
	var at: Transform3D = assistant._transform(placement, part)
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	for cell: Vector3i in assistant.builder._cells_for(part, at):
		lo = Vector3i(mini(lo.x, cell.x), mini(lo.y, cell.y), mini(lo.z, cell.z))
	var ldu: Vector3 = BrickLattice.to_ldu(lo)
	var got := Vector3(ldu.x / 20.0, ldu.y / 8.0, ldu.z / 20.0)
	var want := Vector3(4, 2, 3)
	if got.is_equal_approx(want):
		print("  ok    %s face %s rot %d occupies its stated corner"
			% [part_id, face, rot])
	else:
		_failures += 1
		print("  FAIL  %s face %s rot %d: said %s, occupies from %s"
			% [part_id, face, rot, want, got])


## Placing a brick and reading it back has to give the same answer, or
## look_at_model describes a model that is not the one on screen.
func _roundtrip(assistant: Assistant, library: PartLibrary,
		world: BrickWorld, builder: Builder) -> void:
	for face: String in ["up", "down", "+x", "-x", "+z", "-z"]:
		for rot: int in 4:
			var part: Lbm.PartMesh = library.mesh_for("3005")
			var placement := Assistant.Placement.from_dict({
				"part": "3005", "color": 4, "x": 2, "y": 1.5, "z": 5,
				"face": face, "rot": rot})
			var at: Transform3D = assistant._transform(placement, part)
			var brick_id: int = world.add_brick("3005", 4, at)
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var back: Vector3 = assistant._to_studs(
				brick, library.parts["3005"])
			var face_back: String = BrickLattice.face_of(at.basis)
			var rot_back: int = BrickLattice.turns_about(at.basis, face_back)
			world.remove_brick(brick_id)

			if (not back.is_equal_approx(Vector3(2, 1.5, 5))
					or face_back != face or rot_back != rot):
				_failures += 1
				print("  FAIL  %s rot %d read back as %s %s rot %d"
					% [face, rot, back, face_back, rot_back])
				return
	print("  ok    every face and turn reads back as itself")


## The same thing, by hand.
##
## An assistant that can lay a brick on its side and a person who
## cannot is a tool that builds models you are not allowed to edit. The
## hand path aims a ray and settles the part onto what is below it,
## which is entirely separate code from the assistant's, and it has to
## come to the same orientation.
func _by_hand(builder: Builder, world: BrickWorld) -> void:
	builder.held_part = "3001"
	builder.held_color = 4
	builder.held_rotation = 0
	builder.held_face = "up"

	for want: String in BrickLattice.FACES:
		while builder.held_face != want:
			builder.tip_held()
		# Straight down at the empty ground, well clear of anything.
		builder.update_preview(
			Vector3(600.0, 400.0, 600.0), Vector3.DOWN)
		var brick_id: int = builder.place()
		if brick_id == 0:
			_failures += 1
			print("  FAIL  nothing placed with the part tipped %s" % want)
			return
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var got: String = BrickLattice.face_of(brick.transform.basis)
		# And it must be standing on the ground rather than sunk into it.
		var lowest: int = 0x7FFFFFFF
		for cell: Vector3i in builder._cells_for(
				builder.library.mesh_for("3001"), brick.transform):
			lowest = mini(lowest, cell.y)
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)

		if got != want:
			_failures += 1
			print("  FAIL  tipped to %s, placed as %s" % [want, got])
			return
		if lowest < 0:
			_failures += 1
			print("  FAIL  tipped %s sank %d cells below the ground"
				% [want, -lowest])
			return
	print("  ok    every face can be placed by hand and rests on the ground")
