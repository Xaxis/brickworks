## The silhouette: a design's outline from one side, laid over the real
## thing's outline read off a photograph, with where they differ in studs and
## plates, leading review_model's answer and each submit_design's (Silhouette).
##
##   godot --headless --path . --script src/dev/silhouette_probe.gd [-- --shots=DIR]
##
## Five sets of the tune half, opened from their own LDraw files, each read
## as a perfect reader would read its photograph (Silhouette.reading_of),
## along its length from the side and up its height from the front: laid over
## the set itself, each differs by 0 studs and 0 plates, and nothing is said
## to fix. Each made a stud wider at two tenths of its height says "a stud
## wider" there and nowhere else; each a brick taller at one tenth of its
## length says "3 plates taller" there, at the model's own x or z. A reading
## given the other way round is laid the way it fits. Then the whole path of a
## session: a design built, the whole review asking for the outline once, the
## outline given and leading the review with its picture, the next build
## leading with it too, a new design on a bare baseplate asked again, and
## readings that are wrong refused with what is wrong. --shots=DIR keeps each
## picture the answers carry. No graphics card: the outline is the lattice's.
extends SceneTree

const SETS := "res://vendor/omr/files"
## Tune-half sets (tools/bench/realset.py sample --which tune): an animal, a
## BrickHeadz figure, a Technic vehicle and two Architecture skylines.
const FIVE: Array[String] = ["40148-1", "41587-1", "42061-1", "21051-1", "21034-1"]
const PLATE := 8.0
const STUD := 20.0

var _failures: int = 0
var _shots: String = ""
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore
## How many sets' readings given the other way round were laid reversed.
var _reversed: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	if not DirAccess.dir_exists_absolute(SETS):
		print("SKIP no %s: tools/omr.py fetch brings the sets" % SETS)
		quit(3)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	root.add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

	for number: String in FIVE:
		await _one_set(number)
	_ok(_reversed >= 3, "%d of the 5 sets' heights, given the other way round, were laid reversed"
		% _reversed)
	await _readings_refused()
	await _session_path()
	await _review_of_a_set()
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _open(number: String) -> bool:
	_world.clear()
	_builder.lattice.clear()
	var path: String = SETS.path_join(number + ".mpd")
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	return _world.brick_count() > 0 and str(opened.get("error", "")).is_empty()


func _laid(side: String, mode: String, said: Dictionary) -> Silhouette.Comparison:
	var outline: Silhouette.Outline = Silhouette.of_bricks(_world.bricks(), _builder,
		_library, side)
	var reading: Silhouette.Reading = Silhouette.read(said)
	if not reading.error.is_empty():
		print("    reading refused: " + reading.error)
		return null
	return Silhouette.compare(outline, reading)


func _one_set(number: String) -> void:
	print("\n%s" % number)
	if not _open(number):
		_ok(false, "%s opens" % number)
		return
	var parts: int = _world.brick_count()
	# Read off the set itself, as a reader who read its photograph exactly.
	var side_outline: Silhouette.Outline = Silhouette.of_bricks(_world.bricks(), _builder,
		_library, "left")
	var front_outline: Silhouette.Outline = Silhouette.of_bricks(_world.bricks(), _builder,
		_library, "front")
	_ok(not side_outline.is_empty() and not front_outline.is_empty(),
		"%d parts: outlines %d x %d cells from the side, %d x %d from the front" % [parts,
			side_outline.cols, side_outline.rows, front_outline.cols, front_outline.rows])
	var heights: Dictionary = Silhouette.reading_of(side_outline, "heights")
	var widths: Dictionary = Silhouette.reading_of(front_outline, "widths")

	var along: Silhouette.Comparison = _laid("left", "heights", heights)
	_ok(along != null and along.runs.is_empty() and roundi(along.most_off() / PLATE) == 0
		and not along.reversed and Silhouette.said(along).contains("Within two plates everywhere"),
		"along its length from the side: 0 plates off at every tenth (most %.1f LDU), nothing to fix"
			% (along.most_off() if along != null else -1.0))
	var up: Silhouette.Comparison = _laid("front", "widths", widths)
	_ok(up != null and up.runs.is_empty() and roundi(up.most_off() / STUD) == 0
		and Silhouette.said(up).contains("Within a stud everywhere"),
		"up its height from the front: 0 studs off at every tenth (most %.1f LDU)"
			% (up.most_off() if up != null else -1.0))
	_shot("%s_same_front" % number, up)

	# Given the other way round, it is laid the way it fits.
	var turned: Dictionary = heights.duplicate(true)
	(turned["heights"] as Array).reverse()
	(turned["bottoms"] as Array).reverse()
	var back: Silhouette.Comparison = _laid("left", "heights", turned)
	var back_words: String = Silhouette.said(back) if back != null else ""
	if back != null and back.reversed:
		_reversed += 1
	_ok(back != null and back.runs.is_empty() and (not back.reversed
		or (back_words.contains("Laid the other way round") and back_words.contains("from=\"right\""))),
		"its heights given the other way round: %s" % ("laid reversed, saying from=\"right\""
			if back != null and back.reversed else "within the line either way (it reads near enough the same)"))

	# A stud wider at two tenths of its height, on its right.
	var wider_at: Array[int] = [3, 4]
	var levels := PackedStringArray()
	var added: Array[int] = []
	for index: int in wider_at:
		var row: int = up.samples[index].cell
		var edge: int = front_outline.right[row]
		var cell := Vector3i(front_outline.model_cell(edge),
			row + front_outline.floor_cells - posmod(row + front_outline.floor_cells, 4), 0)
		var id: int = _place_at("3024", 4, cell)
		if id != 0:
			added.append(id)
		levels.append(str(floori(float(row + front_outline.floor_cells) / 4.0)))
	var wider: Silhouette.Comparison = _laid("front", "widths", widths)
	var words: String = Silhouette.said(wider) if wider != null else ""
	var run: Dictionary = wider.runs[0] if wider != null and wider.runs.size() == 1 else {}
	_ok(added.size() == 2 and not run.is_empty() and int(run["from"]) == 3 and int(run["to"]) == 4
		and words.contains("from 3/10 to 4/10 of its height")
		and words.contains("a stud wider than the outline"),
		"a stud wider at 3/10 and 4/10 of its height (plates %s): %s" % [", ".join(levels),
			_line_with(words, "wider")])
	_ok(not run.is_empty() and words.contains("plates %s to" % levels[0]),
		"...said at the plates it was widened at")
	_shot("%s_wider" % number, wider)
	for id: int in added:
		_world.remove_brick(id)

	# A brick taller at one tenth of its length, said at its x or z.
	var along_again: Silhouette.Comparison = _laid("left", "heights", heights)
	var sample: Silhouette.Sample = along_again.samples[6]
	var column: int = sample.cell
	var top_row: int = side_outline.top[column] + side_outline.floor_cells
	var low := Vector3i(0, top_row, side_outline.model_cell(column))
	var brick: int = _place_at("3005", 14, low)
	var taller: Silhouette.Comparison = _laid("left", "heights", heights)
	var tall_words: String = Silhouette.said(taller) if taller != null else ""
	var stud_z: float = float(side_outline.model_cell(column)) * 2.0 / STUD
	var tall_run: Dictionary = taller.runs[0] if taller != null and not taller.runs.is_empty() \
		else {}
	# A brick is a stud across: on a set a few studs long it takes in the next
	# tenth as well.
	_ok(brick != 0 and taller != null and taller.runs.size() == 1 and int(tall_run["from"]) <= 6
		and int(tall_run["to"]) >= 6 and int(tall_run["to"]) - int(tall_run["from"]) <= 1
		and tall_words.contains("6/10")
		and tall_words.contains("its top 3 plates taller than the outline"),
		"a 1 x 1 brick on top at 6/10 of its length: %s" % _line_with(tall_words, "taller"))
	_ok(tall_words.contains("(z %s" % Silhouette._n(snappedf(stud_z, 0.5))),
		"...said at its z, %s studs, where the brick stands" % Silhouette._n(snappedf(stud_z, 0.5)))
	_shot("%s_taller" % number, taller)


## Put [param part] down so its cover's low corner is at [param cell].
func _place_at(part: String, colour: int, cell: Vector3i) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var packed: PackedInt32Array = _builder.boxes_for(mesh, Transform3D.IDENTITY)
	if packed.is_empty():
		return 0
	var lo := Vector3i(packed[0], packed[1], packed[2])
	for n: int in range(6, packed.size(), 6):
		lo = lo.min(Vector3i(packed[n], packed[n + 1], packed[n + 2]))
	return _world.add_brick(part, colour, Transform3D(Basis.IDENTITY,
		BrickLattice.to_ldu(cell - lo)))


func _readings_refused() -> void:
	print("\nreadings that are wrong are refused, with what is wrong")
	var cases: Array = [
		[{"heights": [0.1, 0.2, 0.2, 0.2, 0.1]}, "from= is the side"],
		[{"from": "top", "heights": [0.1, 0.2, 0.2, 0.2, 0.1]}, "from= is the side"],
		[{"from": "left"}, "Give one of heights="],
		[{"from": "left", "heights": [0.1, 0.2], "widths": [0.1, 0.2]}, "Give one of heights="],
		[{"from": "left", "heights": [0.1, 0.2, 0.3]}, "give 5 to 41"],
		[{"from": "left", "heights": [0.1, "tall", 0.2, 0.2, 0.1]}, "only numbers"],
		[{"from": "left", "heights": [0.1, -0.2, 0.2, 0.2, 0.1]}, "shares from 0"],
		[{"from": "left", "heights": [0.1, 0.2, 0.2, 0.2, 0.1], "bottoms": [0, 0, 0.3, 0, 0]},
			"number 3 is over it"],
		[{"from": "left", "heights": [0.1, 0.2, 0.2, 0.2, 0.1], "bottoms": [0, 0]},
			"bottoms= has 2 numbers"],
		[{"from": "front", "widths": [0.1, 0.2, 0.2, 0.2, 0.1], "bottoms": [0, 0, 0, 0, 0]},
			"bottoms= goes with heights="],
		[{"from": "left", "heights": [0.1, 0.2, 0.2, 0.2, 0.1], "above": -1}, "above= is plates"],
		["left", "outline= is an object"],
	]
	for case: Array in cases:
		var reading: Silhouette.Reading = Silhouette.read(case[0])
		_ok(reading.error.contains(str(case[1])), "%s: %s" % [JSON.stringify(case[0]),
			reading.error])
	var ok: Silhouette.Reading = Silhouette.read({"from": "Left", "heights": [0, 0.1, 0.2, 0.2,
		0.1], "above": 2, "picture": "Car side.jpg"})
	_ok(ok.error.is_empty() and ok.side == "left" and ok.mode == "heights" and ok.above == 2.0
		and ok.values.size() == 5, "a good reading is read: its side, its heights, above= 2")


## The path a session takes: build, whole review, outline, build again.
func _session_path() -> void:
	print("\nthe session's path: asked once, given, leading the review and each build")
	Assistant.design_parts = 1
	_world.clear()
	_builder.lattice.clear()
	var built: Variant = await _assistant.use_tool("submit_design", _truck())
	var first: String = _text(built)
	_ok(first.begins_with("Built.") and first.contains("Give it outline=")
		and not first.contains("The silhouette, from"),
		"the first build asks for the outline in its next steps, with none read yet")
	var whole: Variant = await _assistant.review("")
	var asked: String = _text(whole)
	_ok(asked.begins_with("The whole model:") and asked.contains("The silhouette first.")
		and asked.contains("\"heights\""), "the whole review asks for it, after its first line")
	var again: String = _text(await _assistant.review(""))
	_ok(not again.contains("The silhouette first."), "...once: the next whole review does not")

	# A reading three plates under the truck from 6/10 on: its cab stands taller.
	# Built along x, so its length shows from the front.
	var outline: Silhouette.Outline = Silhouette.of_bricks(_assistant._bricks_inside({}),
		_builder, _library, "front")
	var said: Dictionary = Silhouette.reading_of(outline, "heights")
	var whole_length: float = float(outline.cols) * 2.0
	var heights: Array = said["heights"]
	for n: int in range(6, 11):
		heights[n] = maxf(0.0, float(heights[n]) - 3.0 * PLATE / whole_length)
	said.erase("bottoms")
	said["picture"] = "Truck side view.jpg"
	var reviewed: Variant = await _assistant.review("", "", false, said)
	_ok(reviewed is Array and _text(reviewed).begins_with("The silhouette, from the front")
		and _text(reviewed).contains("\"Truck side view.jpg\""),
		"given outline=, the whole review leads with the silhouette, from the front")
	_ok(_text(reviewed).contains("from 6/10 to 10/10 of its length")
		and _text(reviewed).contains("3 plates taller than the outline"),
		"...the cab 3 plates taller from 6/10 to 10/10: %s" % _line_with(_text(reviewed),
			"taller"))
	_ok(_text(reviewed).contains("The whole model:"), "...then the rest of the whole review")
	var picture: Image = _picture(reviewed)
	_ok(picture != null and picture.get_width() >= 200 and picture.get_height() >= 100,
		"...with its picture, %s" % (str(picture.get_size()) if picture != null else "none"))
	_keep("session_review", picture)

	var rebuilt: Variant = await _assistant.use_tool("submit_design", _truck())
	_ok(rebuilt is Array and _text(rebuilt).begins_with("The silhouette, from the front")
		and _text(rebuilt).contains("Built."),
		"the next build over it leads with the silhouette too, then Built.")
	_keep("session_build", _picture(rebuilt))

	var edited: Variant = await _assistant.review("", "", false, {"from": "front",
		"heights": [0.1, 0.2]})
	_ok(str(edited).begins_with("Not read: heights= has 2 numbers"),
		"a wrong reading in review_model is refused and nothing else is done")
	_ok(_assistant._outline_read != null and _assistant._outline_read.picture == "Truck side view.jpg",
		"...and the reading before it is kept")

	_world.clear()
	_builder.lattice.clear()
	var fresh: Variant = await _assistant.use_tool("submit_design", _truck())
	_ok(fresh is String and not str(fresh).contains("The silhouette, from"),
		"a new design on a bare baseplate is a new subject: no outline laid")
	_ok(_text(await _assistant.review("")).contains("The silhouette first."),
		"...and its whole review asks again")


func _review_of_a_set() -> void:
	print("\na set opened and reviewed with its own reading, then a stud wider")
	if not _open("40148-1"):
		_ok(false, "40148-1 opens")
		return
	var outline: Silhouette.Outline = Silhouette.of_bricks(_world.bricks(), _builder, _library,
		"front")
	var said: Dictionary = Silhouette.reading_of(outline, "widths")
	var same: Variant = await _assistant.review("", "", false, said)
	_ok(_text(same).contains("Within a stud everywhere: the silhouette is the one you read"),
		"its own reading: within a stud everywhere")
	var up: Silhouette.Comparison = _laid("front", "widths", said)
	var row: int = up.samples[5].cell
	var cell := Vector3i(outline.model_cell(outline.right[row]),
		row + outline.floor_cells - posmod(row + outline.floor_cells, 4), 0)
	_place_at("3024", 4, cell)
	var wider: String = _text(await _assistant.review(""))
	_ok(wider.contains("at 5/10 of its height") and wider.contains("a stud wider than the outline"),
		"a plate put a stud out at 5/10 of its height: %s" % _line_with(wider, "wider"))
	_keep("sheep_review_wider", _picture(await _assistant.review("")))


## A small truck, a design from outside: a long base, a low body, a cab.
func _truck() -> Dictionary:
	var bricks: Array = []
	for x: int in [0, 4, 8]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 0, "z": 0, "rot": 0})
	for x: int in [0, 4]:
		bricks.append({"part": "3001", "color": 1, "x": x, "y": 3, "z": 0, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 8, "y": 3, "z": 0, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 8, "y": 6, "z": 0, "rot": 0})
	return {"name": "truck", "description": "a small truck", "bricks": bricks,
		"assemblies": [], "features": []}


func _text(answer: Variant) -> String:
	if answer is Array:
		var texts := PackedStringArray()
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
				texts.append(str((block as Dictionary)["text"]))
		return "\n\n".join(texts)
	return str(answer)


func _picture(answer: Variant) -> Image:
	if not answer is Array:
		return null
	for block: Variant in answer:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "image":
			var image := Image.new()
			var bytes: PackedByteArray = Marshalls.base64_to_raw(
				str(((block as Dictionary)["source"] as Dictionary)["data"]))
			if image.load_png_from_buffer(bytes) == OK:
				return image
	return null


func _shot(name: String, laid: Silhouette.Comparison) -> void:
	if laid != null:
		_keep(name, Silhouette.picture(laid))


func _keep(name: String, image: Image) -> void:
	if _shots.is_empty() or image == null:
		return
	image.save_png(_shots.path_join(name + ".png"))


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges()
	return "(no line with \"%s\")" % word


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
