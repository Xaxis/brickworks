## Prove a model survives being saved and reopened.
##
## The claim is that .ldr is lossless for what this app puts in it — the
## same parts, the same colours, the same places. That is worth checking
## rather than assuming, because the round trip crosses the axis
## conversion twice and a sign error there is invisible on a symmetric
## model.
##
##   godot --headless --path . --script src/dev/store_probe.gd
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
	store.library = library
	store.builder = builder

	# A model with rotation and a range of colours, so an axis or sign
	# error in the conversion has something to show up on.
	var wanted: Array = [
		{"part": "3001", "colour": 4, "at": Vector3(0, 24, 0), "turn": 0},
		{"part": "3001", "colour": 14, "at": Vector3(40, 48, 0), "turn": 1},
		{"part": "3024", "colour": 2, "at": Vector3(-60, 24, 40), "turn": 2},
		{"part": "3068b", "colour": 47, "at": Vector3(80, 24, -40), "turn": 3},
		# And a model whose order has to survive the save: a 1 x 1 plate with
		# a 3 x 3 on its stud. Put in together, the 3 x 3 hides the 1 x 1 from
		# the front and the back, and a builder cannot see where it goes, so
		# the booklet puts the 3 x 3 in the step after (docs/INSTRUCTIONS.md,
		# 17). The four parts above plan as one step since 2026-10-17
		# (cfbe8b1b: a step takes what is near any of its parts), and one step
		# has no STEP line to write; so would a brick on a brick on a brick,
		# three parts and none of them hidden.
		{"part": "3024", "colour": 15, "at": Vector3(200, 8, 0), "turn": 0},
		{"part": "11212", "colour": 1, "at": Vector3(200, 16, 0), "turn": 0},
	]
	for entry: Dictionary in wanted:
		var at := Transform3D(
			Basis(Vector3.UP, entry["turn"] * PI * 0.5), entry["at"])
		var id: int = world.add_brick(entry["part"], entry["colour"], at)
		if id != 0:
			builder.register(id, entry["part"], at)

	var before: Array = _snapshot(world)
	print("wrote %d bricks" % before.size())

	# The build order has to leave the app with the model. It is worked
	# out here and nowhere else, so a file without it opens in Stud.io
	# or LDCad as one flat pile — and the order is not obvious for a
	# mechanism, where a pin has to follow the part it goes into.
	#
	# Not in the autosave, though: working it out compares every brick
	# with every other, which is 2.2 seconds at two thousand bricks, and
	# the autosave fires a second after every change.
	var saved: String = store.to_text("round trip", true)
	var auto: String = store.to_text("round trip", false)
	var small_step: int = _step_in(saved, 15, "3024")
	var over_step: int = _step_in(saved, 1, "11212")
	_expect(small_step >= 0 and over_step > small_step,
		"a saved model carries its build order: the 1 x 1 plate in step %d, the 3 x 3 on it in step %d (%d STEP lines)"
		% [small_step + 1, over_step + 1, saved.count("0 STEP")])
	_expect(auto.count("0 STEP") == 0,
		"the autosave does not pay for it (%d STEP lines)"
		% auto.count("0 STEP"))
	# And a pin is written after the part it goes into, which is the
	# order's whole purpose.
	var pinned := BrickWorld.new()
	pinned.library = library
	get_root().add_child(pinned)
	var technic: LdrModel = LdrModel.load_file("res://models/kart.ldr")
	for piece: LdrModel.Placement in technic.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) != null:
			pinned.add_brick(part_id, piece.color_code, piece.transform)
	var kart_store := ModelStore.new()
	kart_store.world = pinned
	kart_store.library = library
	var kart_text: String = kart_store.to_text("kart", true)
	_expect(kart_text.count("0 STEP") >= 10,
		"a Technic model is written in steps (%d)" % kart_text.count("0 STEP"))
	pinned.queue_free()

	if not store.save_as("round trip"):
		print("  XX could not save")
		quit(1)
		return

	var reopened: int = store.open(ModelStore.SAVE_DIR + "round trip.ldr")
	var after: Array = _snapshot(world)
	print("read back %d bricks" % reopened)

	_expect(before.size() == after.size(),
		"brick count: %d then %d" % [before.size(), after.size()])

	for n: int in mini(before.size(), after.size()):
		var a: Dictionary = before[n]
		var b: Dictionary = after[n]
		_expect(a["part"] == b["part"],
			"brick %d part: %s then %s" % [n, a["part"], b["part"]])
		_expect(a["colour"] == b["colour"],
			"brick %d colour: %d then %d" % [n, a["colour"], b["colour"]])
		_expect(a["at"].distance_to(b["at"]) < 0.01,
			"brick %d position: %v then %v" % [n, a["at"], b["at"]])
		_expect(_same_basis(a["basis"], b["basis"]),
			"brick %d orientation changed" % n)

	DirAccess.remove_absolute(ModelStore.SAVE_DIR + "round trip.ldr")

	# The assemblies a design named, kept in the file. Two groups of
	# bricks become two sub-models, titled as a person wrote them, and
	# come back with every brick in its own.
	world.clear()
	builder.lattice.clear()
	for tower: int in 2:
		for level: int in 3:
			var at := Transform3D(Basis.IDENTITY,
				Vector3(tower * 600.0, level * 24.0, 0))
			var id: int = world.add_brick("3001", 4, at)
			builder.register(id, "3001", at)
			world.get_brick(id).group = ["north-east tower", "gatehouse"][tower]
	var grouped: String = store.to_text("castle", true)
	_expect(grouped.contains("0 FILE north_east_tower.ldr")
			and grouped.contains("0 FILE gatehouse.ldr"),
		"a grouped model is written as one sub-model per group")
	var parsed: LdrModel = LdrModel.parse(grouped, "castle.mpd")
	var by_group: Dictionary = {}
	for piece: LdrModel.Placement in parsed.flatten(library.parts):
		by_group[piece.group] = int(by_group.get(piece.group, 0)) + 1
	_expect(int(by_group.get("north-east tower", 0)) == 3
			and int(by_group.get("gatehouse", 0)) == 3,
		"read back with every brick in its group, by name: %s" % str(by_group))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	_expect(steps[0].section in ["north-east tower", "gatehouse"]
			and steps[-1].section != steps[0].section,
		"the booklet builds them as its parts: %s, then %s"
			% [steps[0].section, steps[-1].section])
	# And undoing a deletion puts the brick back in its group: undo
	# re-adds it from what the history recorded, which was its part, its
	# colour and its place, and not which assembly it was.
	var some: int = world.bricks()[0].id
	var its: String = world.get_brick(some).group
	builder.selection = {some: true}
	builder.remove_selection()
	builder.undo()
	var back: Array = world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.group == its)
	_expect(back.size() == 3, "undoing a deletion puts it back in %s (%d of 3)"
		% [its, back.size()])
	print("grouped: %s; booklet parts %s then %s" % [str(by_group),
		steps[0].section, steps[-1].section])

	# The Open list counts a model as the app does once it is open: a
	# sub-model's reference is not a brick, and each copy of one is its
	# parts. It said "My House — 14 bricks" of a house the app called 13.
	var listed: String = "user://store_probe_count.ldr"
	var file: FileAccess = FileAccess.open(listed, FileAccess.WRITE)
	file.store_string(store.to_text("Grouped"))
	file.close()
	_expect(ModelStore._count_bricks(listed) == world.brick_count(),
		"the Open list counts the grouped model as %d bricks, as the app does (%d)"
		% [world.brick_count(), ModelStore._count_bricks(listed)])
	var copies: String = "\n".join(PackedStringArray([
		"0 FILE house.ldr", "0 House",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 16 0 -48 0 1 0 0 0 1 0 0 0 1 wing.ldr",
		"1 16 0 -96 0 1 0 0 0 1 0 0 0 1 wing.ldr",
		"1 16 0 -120 0 1 0 0 0 1 0 0 0 1 bw-made.dat",
		"0 FILE wing.ldr", "0 Wing",
		"1 1 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat",
		"1 1 0 -8 0 1 0 0 0 1 0 0 0 1 3020.dat",
		"1 1 0 -16 0 1 0 0 0 1 0 0 0 1 3020.dat",
		"0 FILE bw-made.dat", "0 A made brick", "0 Name: bw-made.dat",
		"0 !LDRAW_ORG Unofficial_Part",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 stud.dat",
		"1 16 20 0 0 1 0 0 0 1 0 0 0 1 stud.dat", ""]))
	file = FileAccess.open(listed, FileAccess.WRITE)
	file.store_string(copies)
	file.close()
	var opens_as: int = LdrModel.parse(copies, "house.ldr").flatten().size()
	_expect(ModelStore._count_bricks(listed) == 9 and opens_as == 9,
		"two copies of a three-part wing, two bricks and a made part count as the 9 "
		+ "they open as (%d listed, %d opened)" % [ModelStore._count_bricks(listed), opens_as])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(listed))

	# A download is named after the model, and a design names the model:
	# a title climbing out of the folder must land inside it.
	# In the probe's own session folder, two deep, so a title that did
	# climb out would still land in the probe's data and never in the
	# person's Downloads (or two folders above it, their home).
	var folder: String = OS.get_user_data_dir().path_join("sessions/probe/downloads/a/b")
	DirAccess.make_dir_recursive_absolute(folder)
	Download.folder = folder
	var inside: String = folder.path_join("brickworks_store_probe_escape.txt")
	var outside: String = folder.path_join("../../brickworks_store_probe_escape.txt").simplify_path()
	Download.give("x", "../../brickworks_store_probe_escape.txt")
	_expect(FileAccess.file_exists(inside) and not FileAccess.file_exists(outside),
		"a download named to climb out of the folder lands in it")
	DirAccess.remove_absolute(inside)
	Download.folder = ""
	DirAccess.remove_absolute(outside)

	# Two tabs (or windows) with one saved model open (2026-10-13): when one
	# saves it, the other is told and asked, not saved over in silence. The
	# times are a file's, to the second, so each save waits for the next.
	var here: ModelStore = _side(library)
	var there: ModelStore = _side(library)
	_brick(here, Vector3(0, 24, 0))
	here.title = "Probe Shared"
	var shared: String = ModelStore.saved_path("Probe Shared")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(shared))
	_expect(here.save_as("Probe Shared"), "one tab saves Probe Shared")
	_expect(there.open(shared) == 1 and not there.saved_elsewhere(),
		"another opens it, and nothing has been saved elsewhere since")
	OS.delay_msec(1100)
	_brick(here, Vector3(40, 24, 0))
	_expect(here.save_as("Probe Shared"), "the first adds a brick and saves again")
	_expect(there.saved_elsewhere(), "...and the other, which has it open, is told")
	_expect(not there.save_as("Probe Shared") and there.refused.contains("since this one opened it"),
		"...and its own Save will not go over it unasked: %s" % there.refused)
	there.know(shared)
	_expect(not there.saved_elsewhere(), "kept its own, it is not asked again")
	OS.delay_msec(1100)
	_expect(there.save_as("Probe Shared") and ModelStore._count_bricks(shared) == 1,
		"...and saving then replaces the other's, as chosen")
	_expect(here.saved_elsewhere(), "...which the first is told of in turn")
	here.open(shared)
	OS.delay_msec(1100)
	_expect(there.save_as("Probe Shared") and not here.saved_elsewhere(),
		"the same bricks saved again elsewhere ask nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(shared))

	if _failures == 0:
		print("round trip is lossless")
	else:
		print("%d difference(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## A store with a world of its own, as each tab has.
func _side(library: PartLibrary) -> ModelStore:
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	return store


static func _brick(store: ModelStore, at: Vector3) -> void:
	var id: int = store.world.add_brick("3001", 4, Transform3D(Basis(), at))
	if id != 0:
		store.builder.register(id, "3001", Transform3D(Basis(), at))


static func _snapshot(world: BrickWorld) -> Array:
	var out: Array = []
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		out.append({
			"part": brick.part_id,
			"colour": brick.color_code,
			"at": brick.transform.origin,
			"basis": brick.transform.basis,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["at"].y != b["at"].y:
			return a["at"].y < b["at"].y
		if a["at"].x != b["at"].x:
			return a["at"].x < b["at"].x
		return a["at"].z < b["at"].z)
	return out


static func _same_basis(a: Basis, b: Basis) -> bool:
	for n: int in 3:
		if a[n].distance_to(b[n]) > 0.001:
			return false
	return true


## Which step of [param text] (from 0, counted by its STEP lines) puts in
## the first [param part] in [param colour], or -1.
func _step_in(text: String, colour: int, part: String) -> int:
	var step: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() == 2 and words[0] == "0" and words[1] == "STEP":
			step += 1
		elif words.size() >= 15 and words[0] == "1" and words[1] == str(colour) \
				and words[14].to_lower() == part + ".dat":
			return step
	return -1


func _expect(condition: bool, detail: String) -> void:
	if not condition:
		_failures += 1
		print("  XX %s" % detail)
