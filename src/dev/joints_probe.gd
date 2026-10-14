## Do the joints real sets use pass the checker, where they are joints and
## nowhere else?
##
##   godot --headless --path . --script src/dev/joints_probe.gd
##
## Of 880 real sets' sub-models (tools/omr.py harvest, src/dev/
## harvest_probe.gd) the checker refused 232 for overlaps, and most were
## not overlaps at all: a clip on a bar, a bar in a hollow stud, a hinge's
## two halves, a turntable's top on its base. Each is something round in
## something round that fits it, which the cover fills in like any other
## ring. The parts pipeline now records those rounds (shafts and bores,
## tools/ldraw/connectivity.py) and the checker forgives an overlap that
## lies inside one (Joints.rounds) — so each is tried here where real sets
## put it, and then a little wrong, which must still be refused: a bar
## through a brick with no hole, a turntable's top off its base, a clip on
## something too thick for it, a hinge's halves apart.
##
## Needs a catalogue built with shafts and bores. One without them is
## said, and fails: a checker that cannot see the joints refuses every
## one of the cases that should pass.
extends SceneTree

const PATH := "user://joints_probe.ldr"

var _failures: int = 0
var _assistant: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

	print("\nthe parts carry their rounds")
	_ok(_has(_library, "30374", "shaft", 4.0), "a bar (30374) has a shaft 4 across")
	_ok(_has(_library, "4085c", "bore", 4.0), "a clip (4085c) has a bore 4 across")
	_ok(_has(_library, "3062b", "bore", 4.0), "a hollow-stud brick (3062b) has a bore 4 across")
	_ok(_has(_library, "3831", "bore", 6.0) and _has(_library, "3830", "shaft", 6.0),
		"a hinge brick's base has an eye and its top a pin, 6 across")
	_ok(_has(_library, "3680", "bore", 17.5) and _has(_library, "3679", "shaft", 17.5),
		"a 2x2 turntable's base has a recess and its top a disc, 17.5 across")

	print("\nwhat a joint forgives")
	_check_cores()

	print("\na bar in a hollow stud")
	# 3062b is bored right through: a lightsaber blade in one, as sets
	# hold a pole, runs from the open stud down through the tube.
	await _passes("a bar through a 1x1 round brick with a hollow stud", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")
	await _refused("the same bar through a 1x1 brick, which has no hole", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")
	await _refused("the bar a stud to one side, through the brick beside it", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 4 20 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 36 20 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")

	print("\na clip on a bar")
	# 4085c's clip holds a bar upright at z=-20 of the plate.
	await _passes("a bar upright in a plate's vertical clip", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -60 -20 1 0 0 0 1 0 0 0 1 87994.dat
""")
	await _refused("a Technic axle in the clip, which is too thick for it", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -40 -20 0 -1 0 1 0 0 0 0 1 3705.dat
""")
	await _refused("a 1x1 brick in the clip, which has no bar", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -24 -20 1 0 0 0 1 0 0 0 1 3005.dat
""")
	# And held by it: a flag clipped to a bar has nothing under it.
	await _passes("a flag clipped to a bar in a hollow stud, held only by the clips",
		"""
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
1 4 0 -60 0 1 0 0 0 1 0 0 0 1 4495a.dat
""")

	print("\na hinge's two halves")
	await _passes("hinge brick 1x4, top on base, straight", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")
	await _passes("the same hinge with the top swung a quarter turn", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 0 0 1 0 1 0 -1 0 0 3830.dat
""")
	await _passes("hinge plate 1x4, top on base", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 2429.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 2430.dat
""")
	# Half a stud into the base, not a whole one along: a whole stud the
	# other way only takes the two apart, which is no joint and no fault.
	await _refused("the hinge's top half a stud into its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 -10 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")
	# The joint is real and the pin is in its eye, but the top is swung a
	# quarter turn the other way, into its own base: the overlap is
	# forgiven inside the eye and nowhere else, so the bodies collide.
	# (Half round is not a fault: the pivot is at the brick's edge, so the
	# top folds alongside its base.)
	await _refused("the hinge's top swung a quarter turn into its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 0 0 -1 0 1 0 1 0 0 3830.dat
""")
	await _passes("the hinge's top swung half round, folded alongside its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 -1 0 0 0 1 0 0 0 -1 3830.dat
""")
	await _refused("the hinge's top two LDU off its pivot", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 2 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")

	print("\na turntable's top on its base")
	await _passes("2x2 turntable, top on base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	await _refused("the top a stud off its base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 20 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	await _refused("the top two LDU off its base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 2 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	for degrees: float in [45.0, 30.0, 10.0]:
		var turned: Dictionary = await _turned(degrees, Vector2.ZERO)
		_ok(bool(turned["ok"]), "the top and a brick on it turned %d degrees about the base: %s"
			% [int(degrees), turned["summary"]])
	var off: Dictionary = await _turned(45.0, Vector2(1, 0))
	_ok(not bool(off["ok"]) and str(off["summary"]).contains("overlap"),
		"turned 45 degrees about a point a stud off the base's axis, refused: %s"
		% off["summary"])

	print("\na section that leans has to lean on a joint")
	# The spires of a tower of Orthanc leaned on nothing: a section tipped
	# out sat on the studs below at a slant, gripping none of them.
	# Held by its joint, a lean holds — which it did not, at first, for
	# want of a cell: the halves are shaped to clear each other as the top
	# turns, by less than a cover can show, and 3938 tipped ten degrees
	# shared 99 cells with 3937 outside the pin. Turned on round into its
	# own base, it is a collision and still refused.
	for degrees: float in [10.0, -10.0, 45.0]:
		var hinged: Dictionary = await _leaning(true, degrees)
		_ok(bool(hinged["ok"]),
			"a hinge top turned %d degrees on its hinge brick holds: %s"
			% [int(degrees), hinged["summary"]])
	var over: Dictionary = await _leaning(true, 180.0)
	_ok(not bool(over["ok"]) and str(over["summary"]).contains("overlap"),
		"turned on round into its own base, refused: %s" % over["summary"])
	var bare: Dictionary = await _leaning(false, 12.0)
	_ok(not bool(bare["ok"]) and str(bare["feedback"]).contains("nothing in it turns"),
		"a brick tipped 12 degrees on a plain brick is refused: %s" % bare["summary"])

	print("\na pane in a frame the table did not list (Assistant.NESTS)")
	# Where three of the repository's sets seat it: 34 along, 4 down, 5 in,
	# a quarter turn.
	await _passes("3854 in a 6556 train window, where real sets seat it", """
1 15 0 -72 0 1 0 0 0 1 0 0 0 1 6556.dat
1 47 34 -68 5 0 0 1 0 1 0 -1 0 0 3854.dat
""")
	# Not turned into it, so it stands across the frame instead of in it.
	await _refused("the same pane where it is seated but not turned into the groove", """
1 15 0 -72 0 1 0 0 0 1 0 0 0 1 6556.dat
1 47 34 -68 5 1 0 0 0 1 0 0 0 1 3854.dat
""")

	print("\nturned about the upright and read from a file, in a section of its own")
	# A file keeps where a part is, not the section it was laid in, so a part
	# turned off the square comes back in a section found for it
	# (Assistant._adopted). The joints hold there as anywhere, for a reader
	# that keeps the section.
	await _passes("the frame and its pane turned 30 degrees together",
		_turned_text(30.0, [["6556", 15, Vector3(0, -72, 0), Basis.IDENTITY],
			["3854", 47, Vector3(34, -68, 5), Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
				Vector3(-1, 0, 0)).transposed()]]), true)
	await _refused("...and the pane not turned into its groove",
		_turned_text(30.0, [["6556", 15, Vector3(0, -72, 0), Basis.IDENTITY],
			["3854", 47, Vector3(34, -68, 5), Basis.IDENTITY]]), true)
	await _passes("a turntable's top turned 30 degrees on its base, a brick on it",
		"1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat\n" + _turned_text(30.0, [
			["3679", 4, Vector3(0, -8, 0), Basis.IDENTITY],
			["3003", 1, Vector3(0, -32, 0), Basis.IDENTITY]]), true)

	print("\ntipped on a hinge and read from a file, in a section of its own")
	# And so is a part tipped about a flat axis. Read back at the nearest
	# square turn, a hinge's top and what stands on it were a plate or so off
	# where they are: the bench's starfighter, its wings opened ten degrees,
	# came back in ten pieces and its crane, the boom raised, in sixteen, each
	# one piece as its session built it. Real sets' sub-models, as LDraw's
	# model repository has them (vendor/omr), each refused before.
	await _one_piece("10179's hinge tipped 53 degrees, a jumper and a bar on its top", """
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3022.dat
1 72 0 -24 10 1 0 0 0 1 0 0 0 1 3937.dat
1 71 0 -20.0182 2.0136 1 0 0 0 0.6018 -0.7986 0 0.7986 0.6018 3938.dat
1 72 0 -24.8327 -4.3754 1 0 0 0 0.6018 -0.7986 0 0.7986 0.6018 3794b.dat
1 71 0 -72.9779 -68.2663 1 0 0 0 0.6018 -0.7986 0 0.7986 0.6018 30374.dat
1 71 0 -8 -30 0 0 -1 0 1 0 1 0 0 3021.dat
""")
	await _one_piece("6285's rail on three hinges tipped 21.5 degrees, plates stacked on them", """
1 0 0 0 0 1 0 0 0 1 0 0 0 1 4477.dat
1 0 40 -8 0 1 0 0 0 1 0 0 0 1 3023.dat
1 0 -40 -8 0 1 0 0 0 1 0 0 0 1 3023.dat
1 0 -80 -24 0 1 0 0 0 1 0 0 0 1 3937.dat
1 14 -80 -23.304 -3.665 1 0 0 0 0.93 -0.367 0 0.367 0.93 3938.dat
1 14 0 -23.304 -3.665 1 0 0 0 0.93 -0.367 0 0.367 0.93 3938.dat
1 0 0 -24 0 1 0 0 0 1 0 0 0 1 3937.dat
1 14 80 -23.304 -3.665 1 0 0 0 0.93 -0.367 0 0.367 0.93 3938.dat
1 0 80 -24 0 1 0 0 0 1 0 0 0 1 3937.dat
1 0 -40 -16 0 1 0 0 0 1 0 0 0 1 3069b.dat
1 0 40 -16 0 1 0 0 0 1 0 0 0 1 3069b.dat
1 0 0 -30.748 -6.597 1 0 0 0 0.93 -0.367 0 0.367 0.93 4477.dat
1 0 0 -38.191 -9.529 1 0 0 0 0.93 -0.367 0 0.367 0.93 4477.dat
1 0 -70 -45.634 -12.461 1 0 0 0 0.93 -0.367 0 0.367 0.93 3623.dat
1 0 70 -45.634 -12.461 1 0 0 0 0.93 -0.367 0 0.367 0.93 3623.dat
1 14 0 -45.634 -12.461 1 0 0 0 0.93 -0.367 0 0.367 0.93 3710.dat
""")
	await _one_piece("75144's panel on a hinge tipped 17 degrees, a plate on it", """
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3937.dat
1 15 0 0.437 -2.924 1 0 0 0 0.956 -0.292 0 0.292 0.956 3938.dat
1 47 0 -45.466 -16.958 1 0 0 0 0.956 -0.292 0 0.292 0.956 87552.dat
1 15 0 -53.116 -19.297 1 0 0 0 0.956 -0.292 0 0.292 0.956 32028.dat
""")
	await _one_piece("21307's hinge tipped 60 degrees, a tile and a clip on its top", """
1 0 0 0 0 0 0 -1 0 1 0 1 0 0 3738.dat
1 72 0 -24 -30 0 0 -1 0 1 0 1 0 0 3002.dat
1 0 0 -24 10 -1 0 0 0 1 0 0 0 -1 3937.dat
1 0 0 -8 30 1 0 0 0 1 0 0 0 1 15573.dat
1 0 0 -8 50 1 0 0 0 1 0 0 0 1 15573.dat
1 0 0 -8 70 1 0 0 0 1 0 0 0 1 15573.dat
1 0 0 -16 50 1 0 0 0 1 0 0 0 1 3024.dat
1 0 0 -16 70 0 0 -1 0 1 0 1 0 0 15712.dat
1 72 0 -22.66 15 -1 0 0 0 0.866 -0.5 0 -0.5 -0.866 3938.dat
1 71 -10 -29.588 19 -1 0 0 0 0.866 -0.5 0 -0.5 -0.866 85861.dat
1 0 10 -29.588 19 -1 0 0 0 0.866 -0.5 0 -0.5 -0.866 3070b.dat
1 72 -10 -39.981 25 -1 0 0 0 0.5 0.866 0 0.866 -0.5 22484.dat
1 0 0 -22 70 0 0 1 0.866 0.5 0 -0.5 0.866 0 23443.dat
""")

	print("\nstood on the ground by its shape, not its box")
	# A part turned off the grid hangs its box below itself wherever it does
	# not fill the box. A model opened was stood on the lowest box, so a car
	# whose wheels are drawn spun on their axles, as Technic sets draw them,
	# stood on its tyres' boxes 8 to 12 LDU up and was called floating whole:
	# 8281's sidecar, all 98 of its parts, and most of 8110's 4,026. A wheel
	# with its tyre (3482c04) spun 16 degrees on a square axle through a
	# Technic brick, drawn 5 LDU into the ground so that opening it must
	# stand it up; then the lot tipped a degree two ways as the sidecar is
	# drawn.
	var wheel: Array = [["3700", 4, Vector3(0, -40, 0), Basis.IDENTITY],
		["3705", 0, Vector3(0, -30, -30), Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
			Vector3(-1, 0, 0))],
		["3482c04", 0, Vector3(0, -30, -40), Basis(Vector3(0, 0, 1), deg_to_rad(16.26))]]
	await _passes("a wheel spun 16 degrees on its axle stands on its tyre",
		_carried_text(Basis.IDENTITY, wheel), true)
	var sidecar := Basis(Vector3(1, 0.017, 0), Vector3(-0.017, 1, 0.017),
		Vector3(0, -0.017, 1)).orthonormalized()
	await _passes("and tipped a degree about two axes as 8281's sidecar is drawn",
		_carried_text(sidecar, wheel), true)
	# And with the wheel's geometry arriving after the model opened, as on the
	# web for a part outside the pack: stood on the wheel's box until it is
	# here, then down onto its tyre, to the height a desktop opens it at.
	var text: String = "0 joints probe\n" + _carried_text(sidecar, wheel) + "\n"
	_clear()
	_store.open_text(text, "wheel")
	var desktop: float = _height_of("3700")
	_clear()
	var root: String = _library._root
	var late: String = _library.parts["3482c04"].mesh_hash
	_library._mesh_cache.erase(late)
	_library._root = "user://no-parts-here/"
	_store.open_text(text, "wheel")
	var waiting: int = _store.awaited.size()
	var opened: float = _height_of("3700")
	_library._root = root
	_store.place_awaited("3482c04")
	var settled: float = _height_of("3700")
	_assistant._ground_only = true
	var held: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_assistant._ground_only = false
	_ok(waiting == 1 and opened > settled and is_equal_approx(settled, desktop)
		and int(held.get("floating", []).size()) == 0,
		("its wheel fetched after it opened: stood %.0f LDU up on the box, then %.0f, "
			+ "as a desktop opens it (%.0f), and held (%s)") % [opened, settled, desktop,
			held["summary"]])
	_clear()
	# And a model another tool drew up in the air comes down onto the ground:
	# its origin is that tool's. 30285's dinosaur is drawn 21 LDU up, and
	# stood there every part of it floated. One this app saved keeps its height.
	var aloft: String = "1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 1 0 -124 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	_store.open_text("0 Drawn up in the air\n" + aloft, "aloft")
	var landed: float = _height_of("3001")
	_assistant._ground_only = true
	var stood: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_assistant._ground_only = false
	_clear()
	_store.open_text("0 Drawn up in the air\n0 Author: Brickworks\n" + aloft, "kept")
	var kept: float = _height_of("3001")
	_clear()
	_ok(is_equal_approx(landed, 24.0) and int(stood.get("floating", []).size()) == 0
		and is_equal_approx(kept, 100.0),
		("a model drawn 76 LDU up by another tool comes down onto the ground (%s), "
			+ "held (%s); saved by this app it keeps its height (%s)") % [
			landed - 24.0, stood["summary"], kept - 24.0])

	print("\nchecked where it stands")
	# A part nobody has moved is checked where the file has it, not where the
	# reading can say it is. A figure's parts are read at the nearest square
	# turn (10182's arch of skis, 7893's mechanical arms), and LSynth draws a
	# hose's pieces sheared and stretched: 3,661 parts of real sets were
	# checked off their place. A ski turned 44 degrees on a 6 x 6 plate, read
	# square, and a 1 x 1 brick put down beside it, where the ski read square
	# would be and the ski is not: refused, as overlapping the ski, though
	# nothing is there; and put down on the ski itself, refused.
	var ski_turn := Basis(Vector3.UP, deg_to_rad(44.0))
	var ski: String = "0 A ski on a plate\n1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3958.dat\n" \
		+ _carried_text(ski_turn, [["6120", 15, Vector3(0, -12, 0), Basis.IDENTITY]]) + "\n"
	var beside: Dictionary = await _added_to(ski, "1 4 -30 -32 30 1 0 0 0 1 0 0 0 1 3005.dat")
	var onto: Dictionary = await _added_to(ski, "1 4 -10 -32 -10 1 0 0 0 1 0 0 0 1 3005.dat")
	_ok(bool(beside["ok"]) and not bool(onto["ok"]) and str(onto["summary"]).contains("overlap"),
		"a brick put down beside a ski turned 44 degrees fits (%s), and on the ski is refused (%s)"
			% [beside["summary"], onto["summary"]])

	print("\na retired number, where its stub puts the part it became")
	# LDraw keeps a retired number as a stub that draws the new part; 68 of
	# them turn or shift it. 3139, a tyre, draws 3139b a quarter turn round.
	# Opened, the tyre was renamed 3139b where the stub stood, so it was
	# drawn right and checked, read back and saved turned across its axle:
	# 179 of the model repository's tyres. Needs a catalogue that says where
	# each stub puts its part (tools/build_meshes.py moved_by).
	var stub: PartLibrary.PartInfo = _library.parts.get("3139")
	_clear()
	_store.open_text("0 A retired tyre\n1 0 0 -30 0 1 0 0 0 1 0 0 0 1 3139.dat\n", "retired")
	var opened_as: BrickWorld.Brick = _world.bricks()[0] if _world.brick_count() > 0 else null
	# Where the file draws it, across: the open stands it on the ground, so
	# only its height is the open's.
	var drawn: AABB = stub.bounds if stub != null else AABB()
	var renamed: AABB = AABB()
	if opened_as != null and _library.parts.has(opened_as.part_id):
		renamed = opened_as.transform * (_library.parts[opened_as.part_id] as PartLibrary.PartInfo).bounds
		renamed.position.y = drawn.position.y
	var saved: String = _store.to_text("retired")
	_clear()
	_store.open_text(saved, "retired again")
	var again: BrickWorld.Brick = _world.bricks()[0] if _world.brick_count() > 0 else null
	_ok(opened_as != null and opened_as.part_id == "3139b" and renamed.is_equal_approx(drawn)
		and again != null and again.transform.is_equal_approx(opened_as.transform),
		"3139 opens as 3139b standing as the stub draws it (%s, %s), and saves and reopens there"
			% [renamed, drawn])
	_clear()

	print("\na part drawn from what its file carries")
	# A file carries the parts it uses that LDraw has not got, and the
	# subparts and primitives they are drawn from. Only the parts were read,
	# and by their bare names, so 1,401 parts real sets' files carry could
	# not be built: 10283's Technic pins, drawn from a friction rib the file
	# carries as a primitive, and printed parts whose print is a subpart
	# named s\... — and whatever stood on one floated. A plate drawn from a
	# subpart under s\, drawn from a primitive, and a 2 x 2 brick on it.
	await _passes("a plate drawn from a subpart and a primitive the file carries, a brick on it",
		"""
0 FILE fx-carried.ldr
0 Carried parts
1 4 0 0 0 1 0 0 0 1 0 0 0 1 fx - plate.dat
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
0 FILE fx - plate.dat
0 Plate 2 x 2 Drawn From What Its File Carries
0 Name: fx - plate.dat
0 !LDRAW_ORG Unofficial_Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 s\\fx - plates01.dat
1 16 10 0 10 1 0 0 0 1 0 0 0 1 stud.dat
1 16 -10 0 10 1 0 0 0 1 0 0 0 1 stud.dat
1 16 10 0 -10 1 0 0 0 1 0 0 0 1 stud.dat
1 16 -10 0 -10 1 0 0 0 1 0 0 0 1 stud.dat
0 NOFILE
0 FILE s\\fx - plates01.dat
0 ~Plate 2 x 2 Body
0 Name: s\\fx - plates01.dat
0 !LDRAW_ORG Unofficial_Subpart
1 16 0 0 0 20 0 0 0 8 0 0 0 20 fx - cube.dat
0 NOFILE
0 FILE fx - cube.dat
0 Cube
0 Name: fx - cube.dat
0 !LDRAW_ORG Unofficial_Primitive
4 16 -1 0 -1 1 0 -1 1 0 1 -1 0 1
4 16 -1 1 -1 -1 1 1 1 1 1 1 1 -1
4 16 -1 0 -1 -1 1 -1 1 1 -1 1 0 -1
4 16 -1 0 1 1 0 1 1 1 1 -1 1 1
4 16 -1 0 -1 -1 0 1 -1 1 1 -1 1 -1
4 16 1 0 -1 1 1 -1 1 1 1 1 0 1
0 NOFILE
""")

	# And a hose LSynth drew: the file carries its pieces, named LS and a
	# number. Read as parts of their own, a piece that touched only the next
	# piece floated, and so did 1,100 pieces of real sets' hoses. Two pieces
	# end to end, the first on a 1 x 1 brick, the second out in the air.
	await _passes("an LSynth hose's pieces are one thing, held where one of them is", """
0 FILE fx-hose.ldr
0 A hose LSynth drew
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 0 0 -32 0 1 0 0 0 1 0 0 0 1 fx - ls60.dat
1 0 20 -32 0 1 0 0 0 1 0 0 0 1 fx - ls60.dat
0 NOFILE
0 FILE fx - ls60.dat
0 LS60
0 Name: fx - ls60.dat
0 !LDRAW_ORG Unofficial_Part
1 16 0 2 0 10 0 0 0 2 0 0 0 5 box.dat
0 NOFILE
""")

	print("")
	if _failures == 0:
		print("the joints real sets use pass, and the same parts apart do not")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


## A part shaped like 3941, a 2x2 round brick: a cavity 16 across with a
## tube 8 across standing in it, and a bore 6 across at the tube's foot. A
## pin pushed into the foot is a joint, and the cavity is empty — but the
## tube inside it is not, and a joint on its axis must not make it so.
func _check_cores() -> void:
	var brick := Lbm.PartMesh.new()
	brick.connectors = [_round("bore", Vector3.ZERO, 16.0, 16.0),
		_round("shaft", Vector3.ZERO, 16.0, 8.0),
		_round("bore", Vector3(0, 16, 0), 4.0, 6.0)]
	var pin := Lbm.PartMesh.new()
	pin.connectors = [_round("shaft", Vector3(0, 14, 0), 8.0, 6.0)]
	var held: Dictionary = Joints.rounds([[0, Transform3D.IDENTITY, brick],
		[1, Transform3D.IDENTITY, pin]])
	_ok(held.has(0) and (held[0] as Dictionary).has(1), "a pin in the bore at its foot is a joint")
	if not (held.has(0) and (held[0] as Dictionary).has(1)):
		return
	var zones: Array = held[0][1]
	_ok(_forgiven(zones, Vector3i(0, 9, 0)), "an overlap in the bore the pin is in is forgiven")
	_ok(_forgiven(zones, Vector3i(6, 4, 0)), "and in the empty cavity it reaches into")
	_ok(not _forgiven(zones, Vector3i(0, 4, 0)), "but not in the tube standing inside the cavity")
	_ok(not _forgiven(zones, Vector3i(10, 4, 0)), "nor past the cavity's wall")


func _round(kind: String, from: Vector3, length: float, radius: float) -> Lbm.Connector:
	var c := Lbm.Connector.new()
	c.kind = kind
	c.gender = "male" if kind == "shaft" else "female"
	c.position = from
	c.axis = Vector3.UP
	c.length = length
	c.radius = radius
	return c


## Whether an overlap of one cell there would be forgiven.
func _forgiven(zones: Array, cell: Vector3i) -> bool:
	var box := PackedInt32Array([cell.x, cell.y, cell.z, cell.x + 1, cell.y + 1, cell.z + 1])
	return Joints.overlap_within(box, box, zones, Transform3D.IDENTITY, Joints.ROUND_SLACK)


func _has(library: PartLibrary, part_id: String, kind: String, radius: float) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == kind and absf(connector.radius - radius) < 0.3:
			return true
	return false


## LDraw lines, opened as a model and read back as the placements a design
## would write, then checked as a design on an empty baseplate.
## The parts read back as new placements. [param sections]: with the sections
## a file's turned parts were read into; without, as a square design is.
func _design(ldraw: String, sections: bool = false) -> Assistant.Model:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("0 joints probe\n" + ldraw.strip_edges() + "\n")
	file.close()
	_clear()
	_store.open(PATH)
	for _n: int in 10:
		await process_frame
	var read: Assistant.Model = _assistant._model_from_world()
	_clear()
	var fresh := Assistant.Model.new()
	if sections:
		fresh.sections = read.sections.duplicate()
	for put: Assistant.Placement in read.placements:
		fresh.placements.append(Assistant.Placement.from_dict({"part": put.part,
			"color": put.color, "x": put.x, "y": put.y, "z": put.z,
			"face": put.face, "rot": put.rot,
			"section": put.section if sections else ""}))
	return fresh


## LDraw lines for parts, each [part, colour, position, basis] in LDU, all
## turned [param degrees] about the upright through the origin.
static func _turned_text(degrees: float, parts: Array) -> String:
	# LDraw's y points down, so a turn about it is the same matrix.
	return _carried_text(Basis(Vector3.UP, deg_to_rad(degrees)), parts)


## The same, all carried by [param turn], in LDraw's own axes.
static func _carried_text(turn: Basis, parts: Array) -> String:
	var lines := PackedStringArray()
	for one: Array in parts:
		var at: Vector3 = turn * (one[2] as Vector3)
		var basis: Basis = turn * (one[3] as Basis)
		# LDraw's matrix is by rows: a b c / d e f / g h i.
		var rows: Array = []
		for r: int in 3:
			for c: int in 3:
				rows.append("%.6f" % basis[c][r])
		lines.append("1 %d %.4f %.4f %.4f %s %s.dat" % [int(one[1]), at.x, at.y, at.z,
			" ".join(PackedStringArray(rows)), str(one[0])])
	return "\n".join(lines)


func _passes(said: String, ldraw: String, sections: bool = false) -> void:
	var model: Assistant.Model = await _design(ldraw, sections)
	var verdict: Dictionary = _assistant._check(model, true)
	_ok(bool(verdict["ok"]) and model.placements.size() >= 2,
		"%s (%s)" % [said, verdict["summary"]])
	if not bool(verdict["ok"]):
		print("        " + str(verdict.get("feedback", "")).left(600).replace("\n", "\n        "))


## Read from a file with its sections, and passed in one piece: a part a
## plate off what it stands on passes as a piece of its own.
func _one_piece(said: String, ldraw: String) -> void:
	var model: Assistant.Model = await _design(ldraw, true)
	var verdict: Dictionary = _assistant._check(model, true)
	_ok(bool(verdict["ok"]) and int(verdict["pieces"]) == 1,
		"%s: %d parts, %s, %d piece%s" % [said, model.placements.size(), verdict["summary"],
			int(verdict["pieces"]), "" if int(verdict["pieces"]) == 1 else "s"])


func _refused(said: String, ldraw: String, sections: bool = false) -> void:
	var model: Assistant.Model = await _design(ldraw, sections)
	var verdict: Dictionary = _assistant._check(model, true)
	_ok(not bool(verdict["ok"]) and str(verdict["summary"]).contains("overlap"),
		"%s: refused (%s)" % [said, verdict["summary"]])


## The turntable square, then its top and a 2x2 brick on it moved into a
## section turned about the base's axis — or about a point [param off]
## studs from it.
func _turned(degrees: float, off: Vector2) -> Dictionary:
	var square: Assistant.Model = await _design("""
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
1 1 0 -32 0 1 0 0 0 1 0 0 0 1 3003.dat
""")
	var base: Assistant.Placement = square.placements[0]
	var top: Assistant.Placement = square.placements[1]
	var part: Lbm.PartMesh = _library.mesh_for(top.part)
	# Where the turntable's axis is, in studs: the top's own origin.
	var axis: Vector3 = _assistant._transform(top, part).origin / Assistant.STUD
	var model := Assistant.Model.new()
	model.placements.append(base)
	for put: Assistant.Placement in square.placements.slice(1):
		model.placements.append(Assistant.Placement.from_dict({"part": put.part,
			"color": put.color, "x": put.x - axis.x - off.x, "y": put.y,
			"z": put.z - axis.z - off.y, "face": put.face, "rot": put.rot,
			"section": "turned"}))
	model.sections["turned"] = Assistant.Section.from_dict({"name": "turned",
		"x": axis.x + off.x, "y": 0.0, "z": axis.z + off.y, "axis": "y",
		"degrees": degrees})
	return _assistant._check(model, true)


## A closed tilting hinge (3937 with 3938 on it) on a 1 x 2, with its top
## in a section turned [param degrees] about the hinge pin — or, unhinged,
## a plain 1 x 2 where the base was and another tipped the same way on it.
## (3830/3831 swivel about the upright: a door, not a lean.)
func _leaning(hinged: bool, degrees: float) -> Dictionary:
	var closed: Assistant.Model = await _design("""
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3004.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3937.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3938.dat
""")
	# By part: a design read back from the world comes in the world's order.
	var by_part: Dictionary = {}
	for put: Assistant.Placement in closed.placements:
		by_part[put.part] = put
	var under: Assistant.Placement = by_part["3004"]
	var base: Assistant.Placement = by_part["3937"]
	var top: Assistant.Placement = by_part["3938"]
	var mesh: Lbm.PartMesh = _library.mesh_for(base.part)
	var at: Transform3D = _assistant._transform(base, mesh)
	# The pin: the base's flat round bores and the top's shafts share an
	# axis; any point on it will do for the pivot.
	var pin := Vector3.ZERO
	var way := Vector3.RIGHT
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "bore" and absf(connector.axis.y) < 0.5:
			pin = at * connector.position
			way = (at.basis * connector.axis).normalized()
			break
	var axis: String = "x" if absf(way.x) > absf(way.z) else "z"
	var pivot := Vector3(pin.x / Assistant.STUD, pin.y / Assistant.PLATE, pin.z / Assistant.STUD)
	var model := Assistant.Model.new()
	model.placements.append(under)
	if hinged:
		model.placements.append(base)
		model.placements.append(Assistant.Placement.from_dict({"part": top.part,
			"color": top.color, "x": top.x - pivot.x, "y": top.y - pivot.y,
			"z": top.z - pivot.z, "face": top.face, "rot": top.rot, "section": "lean"}))
	else:
		model.placements.append(Assistant.Placement.from_dict({"part": "3004",
			"color": base.color, "x": under.x, "y": under.y + 3.0, "z": under.z,
			"face": under.face, "rot": under.rot}))
		model.placements.append(Assistant.Placement.from_dict({"part": "3004",
			"color": top.color, "x": under.x - pivot.x, "y": under.y + 6.0 - pivot.y,
			"z": under.z - pivot.z, "face": under.face, "rot": under.rot, "section": "lean"}))
	model.sections["lean"] = Assistant.Section.from_dict({"name": "lean",
		"x": pivot.x, "y": pivot.y, "z": pivot.z, "axis": axis, "degrees": degrees})
	return _assistant._check(model, true)


## A file opened, and the line [param added] checked as a brick an edit puts
## down among what stands there: the check's verdict.
func _added_to(text: String, added: String) -> Dictionary:
	_clear()
	_store.open_text(text + added + "\n", "added")
	await process_frame
	var model: Assistant.Model = _assistant._model_from_world()
	var last: Assistant.Placement = model.placements[model.placements.size() - 1]
	for placement: Assistant.Placement in model.placements:
		if placement.part == added.get_slice(" ", 14).trim_suffix(".dat"):
			last = placement
	last.id = 0
	last.moved = true
	var verdict: Dictionary = _assistant._check(model, true)
	_clear()
	return verdict


## Where the first brick of a part stands, its origin's height in LDU.
func _height_of(part_id: String) -> float:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			return brick.transform.origin.y
	return NAN


func _clear() -> void:
	for brick: BrickWorld.Brick in _world.bricks():
		_builder.lattice.release(brick.id)
	_world.clear()
