## The model's size and weight, always in sight (docs/APP_UX5.md, modelinfo):
## "will it fit the shelf", as Studio's Model Info says it, was nowhere in the
## window or over MCP.
##
##   godot --path . --resolution 1400x900 --script src/dev/modelinfo_probe.gd
##   tools/probe.sh modelinfo_probe
##   ... -- --shots=DIR    the pictures there, not in shots/modelinfo/
##
## At 1280 x 720 and at 1400 x 900, the window made each size as roomfit makes
## it, on the car a first visit opens. Its truth is the box round every
## vertex of every part as it stands, the baseplate left out, read off the
## parts' own meshes here and nowhere in the app. The bar, line by line:
## 1. the car's width, depth and height on the status bar, in studs and
##    plates and in centimetres, each within 0.1 mm of that box (the plates
##    without the studs on its top, as a wall's height is counted; the
##    centimetres with them);
## 2. with parts selected, the selection's size, after "N selected": one
##    2 x 4 plate, the car's eight 1 x 2 plates together, and a tyre on its
##    edge (4½ plates: no studs to leave off); nothing selected, the model's
##    again, after its counts;
## 3. current within a frame of an edit: the right-most part deleted, then
##    Ctrl+Z and Ctrl+Shift+Z pressed, each read every frame until the bar is
##    the new box, at most one frame after the model changed;
## 4. nothing cut at 1280 x 720 with every column open (the bin, the
##    properties and the assistant, as far as the window opens them): every
##    field on the right wholly in the window and as wide as its words,
##    nothing selected, a part selected, and a 2 x 4 brick in hand;
## 5. Properties with nothing selected says the size, the same as the bar's,
##    and the weight, the status bar's grams;
## 6. in_view says the size in centimetres, within 0.1 mm, and the weight,
##    the status bar's grams, and the selection's size with parts selected;
## and the new words read in German, French and Spanish; and Orthanc's 9,429
## parts measured in less than a frame's 16 ms of the app's own time.
## Weight: each part's grams from its shape (Stability.grams), as the status
## bar's; the catalogue lists no part's weight. Parts lacking an entry are
## counted and said.
##
## The data folder is the run's own (probe.sh gives one).
extends SceneTree

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1400, 900)]
## The bar: within a tenth of a millimetre, at LDraw's 0.4 mm an LDU.
const NEAR_MM := 0.1
const LDU_MM := 0.4
## A stud's height over the part it is on, LDU.
const STUD_TOP := 4.0
## One frame's time at 60 a second, for Orthanc measured whole.
const FRAME_MS := 16.0

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _camera: CadCamera
var _verbs: EditVerbs
var _socket: CommandSocket
var _shots: String = ""
var _size: String = ""
var _next: int = 0
## part id -> every vertex of its mesh, LDU.
var _points: Dictionary = {}
## The words the bar and Properties said, for the languages.
var _said: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.substr(8)
	if _shots.is_empty():
		_shots = ProjectSettings.globalize_path("res://shots/modelinfo")
	DirAccess.make_dir_recursive_absolute(_shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  modelinfo probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	_store.keeps = false
	Keymap.reset()
	Keymap.use("brickworks")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _frames(30)
	print("  the car: %d parts, the baseplate left out" % _model().size())

	for size: Vector2i in SIZES:
		await _at(size)
	await _in_view()
	_languages()
	await _orthanc()

	Keymap.use("brickworks")
	Keymap.reset()
	print("")
	if _failures == 0:
		print("modelinfo probe: all checks passed")
	else:
		print("modelinfo probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## One window size: the car's size, a selection's, an edit's, the room, and
## Properties.
func _at(size: Vector2i) -> void:
	root.size = size
	await _frames(40)
	await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	await _frames(10)
	_size = "%dx%d" % [size.x, size.y]
	print("\n── a %s window (%s) ──" % [_size, root.size])
	if root.size != size:
		_check("the window is %s, as asked (got %s)" % [size, root.size], false)
		return
	_builder.clear_selection()
	await _frames(4)
	await _the_car()
	await _selected()
	if size == SIZES[0]:
		await _current()
	await _room()
	await _properties()


# -- 1: the car's size on the status bar -----------------------------------------------

func _the_car() -> void:
	var truth: AABB = _truth(_model())
	var said: String = _bar()
	_said["model"] = said
	print("  the car's box round its vertices: %s x %s x %s LDU (x, z, y)" % [
		_n(truth.size.x), _n(truth.size.z), _n(truth.size.y)])
	_check("1: the status bar says the car's size: \"%s\"" % said, not said.is_empty())
	_check("1: ...beside its counts (\"%s\")" % _shell.status.fields().get("counts", ""),
		str(_shell.status.fields().get("size_after", "")) == "counts")
	_judge("1: the car", said, _model())
	await _shot_bar("the_car")


## Each of [param said]'s numbers against [param bricks]' vertices, within
## 0.1 mm.
func _judge(what: String, said: String, bricks: Array) -> bool:
	var read: Variant = _read(said)
	if read == null:
		_check("%s: \"%s\" reads as studs, plates and centimetres" % [what, said], false)
		return false
	var got: Dictionary = read
	var truth: AABB = _truth(bricks)
	var off: Array = [
		["width in studs", float(got["x"]) * 20.0 * LDU_MM, truth.size.x * LDU_MM],
		["depth in studs", float(got["z"]) * 20.0 * LDU_MM, truth.size.z * LDU_MM],
		["height in plates (its top's studs not counted)", float(got["y"]) * 8.0 * LDU_MM,
			(_body_top(bricks) - truth.position.y) * LDU_MM],
		["width in cm", float(got["cx"]) * 10.0, truth.size.x * LDU_MM],
		["depth in cm", float(got["cz"]) * 10.0, truth.size.z * LDU_MM],
		["height in cm (studs and all)", float(got["cy"]) * 10.0, truth.size.y * LDU_MM]]
	var all: bool = true
	var lines := PackedStringArray()
	for one: Array in off:
		var miss: float = absf(float(one[1]) - float(one[2]))
		all = all and miss <= NEAR_MM + 1e-6
		lines.append("%s %.2f mm (%.3f off)" % [one[0], float(one[1]), miss])
	_check("%s: each within %.1f mm of the box: %s" % [what, NEAR_MM, "; ".join(lines)], all)
	return all


# -- 2: the selection's size -------------------------------------------------------------

func _selected() -> void:
	var plate: int = 0
	var plates: Array = []
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == "3020" and plate == 0:
			plate = brick.id
		if brick.part_id == "3023b":
			plates.append(brick)
	_builder.clear_selection()
	_builder.select_brick(plate, false)
	await _frames(2)
	var said: String = _bar()
	_said["one"] = said
	_check("2: one 2 x 4 plate selected: the bar says its size, \"%s\", after \"%s\"" % [
		said, _shell.status.fields().get("selected", "")],
		not said.is_empty() and str(_shell.status.fields().get("size_after", "")) == "selected")
	if plate != 0:
		_judge("2: the 2 x 4 plate", said, [_world.get_brick(plate)])
	await _shot_bar("one_plate")
	_builder.clear_selection()
	for brick: BrickWorld.Brick in plates:
		_builder.select_brick(brick.id, true)
	await _frames(2)
	said = _bar()
	_said["plates"] = said
	_check("2: the car's %d 1 x 2 plates selected: \"%s\"" % [plates.size(), said],
		plates.size() == 8 and not said.is_empty())
	_judge("2: the eight 1 x 2 plates", said, plates)
	# A wheel's tyre, stood on its edge: no studs, so its whole height, 4½
	# plates. "4 over a whole plate is a stud" read it as 4.
	var tyre: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == "3641":
			tyre = brick
			break
	_builder.clear_selection()
	if tyre != null:
		_builder.select_brick(tyre.id, false)
	await _frames(2)
	said = _bar()
	# 4½ plates, or 4.5 where its width is no whole quarter: one style of
	# number a line (weighsure).
	var read: Variant = _read(said)
	_check("2: a tyre selected: \"%s\", 4½ plates high, no studs taken off" % said,
		tyre != null and read != null and is_equal_approx(float((read as Dictionary)["y"]), 4.5))
	if tyre != null:
		_judge("2: the tyre", said, [tyre])
	_builder.clear_selection()
	await _frames(2)
	_check("2: nothing selected: the car's again, after its counts (\"%s\")" % _bar(),
		_bar() == str(_said["model"])
		and str(_shell.status.fields().get("size_after", "")) == "counts")


# -- 3: current within a frame -----------------------------------------------------------

func _current() -> void:
	# The part reaching furthest right: taking it off makes the car narrower.
	var right: BrickWorld.Brick = null
	var reach: float = -INF
	for brick: BrickWorld.Brick in _model():
		var end: float = _truth([brick]).end.x
		if end > reach + 0.01:
			reach = end
			right = brick
	var narrower: int = 0
	for brick: BrickWorld.Brick in _model():
		if brick != right and _truth([brick]).end.x >= reach - 0.01:
			narrower += 1
	print("  the right-most part: %s (#%d), %d others reach as far" % [right.part_id, right.id,
		narrower])
	_builder.clear_selection()
	_builder.select_brick(right.id, false)
	await _frames(3)
	await _edit("3: Delete on the right-most part", func() -> void: _shell.run("delete"))
	await _edit("3: Ctrl+Z", func() -> void: _send_key(KEY_Z, true, false))
	await _edit("3: Ctrl+Shift+Z", func() -> void: _send_key(KEY_Z, true, true))
	await _edit("3: Ctrl+Z again", func() -> void: _send_key(KEY_Z, true, false))
	_builder.clear_selection()
	await _frames(3)


## [param act] done, then the bar read every frame: the frame the model
## changed in, and the first the bar was its new size in.
func _edit(what: String, act: Callable) -> void:
	await _frames(2)
	var revision: int = _world.revision
	var before: String = _bar()
	act.call()
	var changed: int = -1
	var right: int = -1
	var last: String = ""
	for frame: int in 30:
		if changed < 0 and _world.revision != revision:
			changed = frame
		last = _bar()
		if changed >= 0 and _matches(last, _measured()):
			right = frame
			break
		await process_frame
	_check("%s: the model changed in frame %d, the bar was its size in frame %d (\"%s\" → \"%s\"), "
		% [what, changed, right, before, last] + "at most one frame after",
		changed >= 0 and right >= 0 and right - changed <= 1)


## What the bar measures now: the selection, or the model.
func _measured() -> Array:
	if _builder.selection.is_empty():
		return _model()
	var bricks: Array = []
	for brick_id: int in _builder.selection:
		if _world.get_brick(brick_id) != null:
			bricks.append(_world.get_brick(brick_id))
	return bricks


func _matches(said: String, bricks: Array) -> bool:
	var read: Variant = _read(said)
	if read == null:
		return false
	var got: Dictionary = read
	var truth: AABB = _truth(bricks)
	var high: float = _body_top(bricks) - truth.position.y
	return absf(float(got["x"]) * 20.0 - truth.size.x) * LDU_MM <= NEAR_MM \
		and absf(float(got["z"]) * 20.0 - truth.size.z) * LDU_MM <= NEAR_MM \
		and absf(float(got["y"]) * 8.0 - high) * LDU_MM <= NEAR_MM \
		and absf(float(got["cx"]) * 10.0 - truth.size.x * LDU_MM) <= NEAR_MM \
		and absf(float(got["cz"]) * 10.0 - truth.size.z * LDU_MM) <= NEAR_MM \
		and absf(float(got["cy"]) * 10.0 - truth.size.y * LDU_MM) <= NEAR_MM


# -- 4: nothing cut ----------------------------------------------------------------------

func _room() -> void:
	# Every column open, as far as the window opens them: the assistant on,
	# the bin, and the properties down the right.
	_main.call("set_assistant", true)
	await _settle()
	var bin_dock: SideDock = _main.get("_bin_dock")
	var props_dock: SideDock = _main.get("_props_dock")
	if not bin_dock.is_open():
		await _click(bin_dock.rail().get_global_rect().get_center())
		await _settle()
	if props_dock != null and not props_dock.is_open():
		await _click(props_dock.rail().get_global_rect().get_center())
		await _settle()
	var chat_dock: SideDock = _main.get("_chat_dock")
	print("  columns: the bin %s, the properties %s, the assistant %s" % [
		"open" if bin_dock.is_open() else "folded",
		"open" if props_dock != null and props_dock.is_open() else "folded",
		"open" if chat_dock != null and chat_dock.is_open() else "folded"])
	_builder.clear_selection()
	await _frames(4)
	_uncut("4: nothing selected")
	await _shot("room_nothing_selected")
	var picked: int = _model()[0].id
	_builder.select_brick(picked, false)
	await _frames(4)
	_uncut("4: a part selected")
	await _shot("room_part_selected")
	_builder.clear_selection()
	# A 2 x 4 brick in hand, aimed at the car: where it goes is said too.
	_main.call("_on_part_chosen", "3001")
	for _n: int in 600:
		if _library.mesh_for("3001") != null:
			break
		await process_frame
	await _settle()
	var aim: Vector2 = _camera.unproject_position(_truth(_model()).get_center())
	await _move(aim + Vector2(3, 0))
	await _move(aim)
	await _frames(8)
	var fields: Dictionary = _shell.status.fields()
	_check("4: a 2 x 4 brick in hand over the car: the bar says where it goes (\"%s\")"
		% fields.get("place", ""), not str(fields.get("place", "")).is_empty())
	_uncut("4: a 2 x 4 brick in hand")
	await _shot("room_in_hand")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_verbs.set_mode("select")
	_builder.clear_selection()
	await _frames(6)


## Every field on the right of the status bar wholly in the window and as
## wide as its words; the bar itself in the window.
func _uncut(what: String) -> void:
	var status: StatusBar = _shell.status
	var window: float = root.get_visible_rect().size.x
	var cut := PackedStringArray()
	var shown := PackedStringArray()
	var bar: Rect2 = _rect(status)
	if bar.end.x > window + 0.5:
		cut.append("the bar ends at %.0f px" % bar.end.x)
	for found: Node in status.find_children("*", "Control", true, false):
		var control: Control = found
		if not control.is_visible_in_tree() or not (control is Label or control is Button):
			continue
		var words: String = str(control.get("text"))
		if words.is_empty():
			continue
		var rect: Rect2 = _rect(control)
		var least: float = control.get_combined_minimum_size().x
		if control is Label and (control as Label).clip_text:
			# The line on the left: cut short by design, its whole in its tooltip.
			if rect.size.x < 80.0 - 0.5:
				cut.append("the line on the left squeezed to %.0f px" % rect.size.x)
			continue
		shown.append("\"%s\" %.0f-%.0f" % [words, rect.position.x, rect.end.x])
		if rect.end.x > window + 0.5 or rect.position.x < -0.5:
			cut.append("\"%s\" runs to %.0f px of %.0f" % [words, rect.end.x, window])
		elif rect.size.x + 0.5 < least:
			cut.append("\"%s\" %.0f px wide for words of %.0f" % [words, rect.size.x, least])
	var size_said: String = str(status.fields().get("size", ""))
	_check("%s: the size in sight (\"%s\")" % [what, size_said], not size_said.is_empty())
	_check("%s: nothing on the status bar cut (%s)%s" % [what, ", ".join(shown),
		"" if cut.is_empty() else ": " + "; ".join(cut)], cut.is_empty())


# -- 5: Properties with nothing selected ------------------------------------------------

func _properties() -> void:
	_builder.clear_selection()
	var props_dock: SideDock = _main.get("_props_dock")
	if props_dock != null and not props_dock.is_open():
		await _click(props_dock.rail().get_global_rect().get_center())
		await _settle()
	var inspector: Inspector = _shell.inspector
	if not inspector.is_open():
		inspector.set_open(true)
	await _frames(20)
	# Weighed by the status bar at most once a second, on a worker.
	var grams: String = ""
	for _n: int in 300:
		grams = _bar_grams()
		if not grams.is_empty():
			break
		await process_frame
	var label: Variant = inspector.get("_model_size")
	var words: String = ""
	var shown: bool = false
	if label is Label:
		words = (label as Label).text
		shown = (label as Label).is_visible_in_tree()
	_said["properties"] = words
	var lines: PackedStringArray = words.split("\n")
	var bar: String = _bar()
	_check("5: Properties with nothing selected says the size and the weight: %s" % (
		"\"%s\"" % words.replace("\n", " / ") if shown else "nothing"), shown and lines.size() >= 3)
	if not shown or lines.size() < 3:
		return
	_check("5: ...its size the status bar's (\"%s\" · \"%s\" against \"%s\")" % [lines[0], lines[1],
		bar], bar == lines[0] + " · " + lines[1])
	_check("5: ...its weight the status bar's: \"%s\" against \"%s g\"" % [lines[2], grams],
		lines[2] == "About %s g" % grams)
	var rect: Rect2 = _rect(label as Label)
	_check("5: ...in the window (%s)" % rect, root.get_visible_rect().encloses(rect))
	await _shot("properties_nothing_selected")


func _bar_grams() -> String:
	var found: RegExMatch = RegEx.create_from_string(r" · (\d+) g$").search(
		str(_shell.status.fields().get("counts", "")))
	return found.get_string(1) if found != null else ""


# -- 6: in_view ---------------------------------------------------------------------------

func _in_view() -> void:
	print("\n── in_view, as a session asks ──")
	_builder.clear_selection()
	await _frames(4)
	var said: String = _text(await _rpc("tools/call", {"name": "in_view",
		"arguments": {"picture": false}}))
	print("  " + said.replace("\n", "\n  "))
	var truth: AABB = _truth(_model())
	var found: RegExMatch = RegEx.create_from_string(
		r"(\d+(?:\.\d+)?) cm across \(x\), (\d+(?:\.\d+)?) cm deep \(z\) and (\d+(?:\.\d+)?) cm high"
	).search(said)
	if found == null:
		_check("6: in_view says the model's size in centimetres", false)
	else:
		var cm := Vector3(found.get_string(1).to_float(), found.get_string(3).to_float(),
			found.get_string(2).to_float())
		var miss: Vector3 = (cm * 10.0 - truth.size * LDU_MM).abs()
		_check("6: in_view says the model's size in centimetres, %s x %s x %s, each within %.1f mm (%.3f, %.3f, %.3f off)"
			% [found.get_string(1), found.get_string(2), found.get_string(3), NEAR_MM, miss.x,
				miss.z, miss.y], maxf(miss.x, maxf(miss.y, miss.z)) <= NEAR_MM + 1e-6)
	var grams: String = _bar_grams()
	var weight: RegExMatch = RegEx.create_from_string(r"about (\d+) g").search(said)
	_check("6: in_view says the weight, the status bar's: %s against %s g" % [
		"about %s g" % weight.get_string(1) if weight != null else "none", grams],
		weight != null and weight.get_string(1) == grams)
	# With parts selected, theirs.
	var plates: Array = []
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == "3023b":
			plates.append(brick)
			_builder.select_brick(brick.id, true)
	await _frames(3)
	said = _text(await _rpc("tools/call", {"name": "in_view", "arguments": {"picture": false}}))
	var together: RegExMatch = RegEx.create_from_string(r"together (.+? cm)").search(said)
	_check("6: with the 1 x 2 plates selected, in_view says their size: %s" % (
		"\"%s\"" % together.get_string(1) if together != null else "nothing"),
		together != null and _matches(together.get_string(1).replace("high, ", "high · "),
			plates))
	_builder.clear_selection()
	await _frames(3)


# -- the words in each language ----------------------------------------------------------

func _languages() -> void:
	print("\n── the new words in German, French and Spanish ──")
	var words: Array = []
	for key: String in ["model", "one", "plates"]:
		if not str(_said.get(key, "")).is_empty():
			words.append(_said[key])
	for line: String in str(_said.get("properties", "")).split("\n", false):
		words.append(line)
	words.append_array(["1 part not in the library, not counted",
		"3 parts not in the library, not counted",
		"How big the model is, or the parts selected: studs across and deep, plates high "
			+ "without the studs on top, and centimetres each way with them",
		"How big the model is: studs across and deep, and plates high without the studs on its "
			+ "top; in centimetres with them, as a shelf needs. Its weight is worked out from each "
			+ "part's shape, within about 6% of the bricks weighed"])
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		var drawn: Array = []
		for english: String in words:
			var said: String = TranslationServer.translate(english)
			# A number is kept as it is ("2½", "12.8"), and is no word.
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				var rest: String = str(w)
				for mark: String in "0123456789½¼¾−-.,:× ":
					rest = rest.replace(mark, "")
				return not rest.is_empty())
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english, " (kept " + str(kept) + ")" if not kept.is_empty() else ""])
			drawn.append(said)
		print("  %s: %s" % [code, " | ".join(drawn.slice(0, 4))])
		_check("%s: each of the %d reads in the language%s" % [code, words.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty())
	Language.apply("en")


# -- a big model --------------------------------------------------------------------------

func _orthanc() -> void:
	print("\n── Orthanc ──")
	if not ResourceLoader.exists("res://src/assembly/model_size.gd"):
		_check("Orthanc measured (no ModelSize in this checkout)", false)
		return
	var placed: int = int(_main.call("_open", "res://models/orthanc.ldr"))
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	var measure: GDScript = load("res://src/assembly/model_size.gd")
	var bricks: Array = _world.bricks()
	var spans: Array = []
	var measured: RefCounted = null
	for _n: int in 3:
		var span := ProbeTime.Span.new()
		measured = measure.call("of_bricks", bricks, _library, _store.scenery)
		spans.append(span.end())
		await process_frame
	var best: ProbeTime.Span = spans[0]
	for span: ProbeTime.Span in spans:
		if span.own < best.own:
			best = span
	print("  %d parts: %s" % [placed, measured.call("words")])
	_check("Orthanc's %d parts measured whole in %s, under %.0f ms" % [bricks.size(), best.said(),
		FRAME_MS * best.slack()], best.own <= FRAME_MS * best.slack())
	# Select all, as Ctrl+A does: the bar the selection's, in the frame after.
	_verbs.select_by("all")
	var right: int = -1
	for frame: int in 10:
		await process_frame
		if str(_shell.status.fields().get("size_after", "")) == "selected" \
				and not _bar().is_empty():
			right = frame
			break
	_check("...and all %d selected: the bar says their size in frame %d (\"%s\")" % [
		_builder.selection.size(), right, _bar()], right >= 0 and right <= 1)
	_builder.clear_selection()
	await _frames(3)


# -- reading ------------------------------------------------------------------------------

func _bar() -> String:
	return str(_shell.status.fields().get("size", ""))


## "4½ × 10.8 studs, 15 plates high · 3.6 × 8.64 × 4.96 cm" as its numbers; null
## when it is not that.
func _read(said: String) -> Variant:
	var found: RegExMatch = RegEx.create_from_string(
		r"^(\S+) × (\S+) studs, (\S+) plates? high · (\S+) × (\S+) × (\S+) cm$").search(said)
	if found == null:
		return null
	return {"x": _number(found.get_string(1)), "z": _number(found.get_string(2)),
		"y": _number(found.get_string(3)), "cx": found.get_string(4).to_float(),
		"cz": found.get_string(5).to_float(), "cy": found.get_string(6).to_float()}


func _number(text: String) -> float:
	var sign: float = -1.0 if text.begins_with("−") else 1.0
	var rest: String = text.trim_prefix("−")
	var value: float = 0.0
	for mark: Array in [["¼", 0.25], ["½", 0.5], ["¾", 0.75]]:
		if rest.ends_with(str(mark[0])):
			value = float(mark[1])
			rest = rest.trim_suffix(str(mark[0]))
	return sign * (value + (rest.to_float() if not rest.is_empty() else 0.0))


## The model's parts, the baseplate left out.
func _model() -> Array:
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			bricks.append(brick)
	return bricks


## The box round every vertex of [param bricks]' meshes as they stand.
func _truth(bricks: Array) -> AABB:
	var box := AABB()
	var first: bool = true
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		for point: Vector3 in _vertices(brick.part_id):
			var here: Vector3 = brick.transform * point
			if first:
				box = AABB(here, Vector3.ZERO)
				first = false
			else:
				box = box.expand(here)
	return box


## The highest of [param bricks]' bodies, as a wall's height is counted: a
## part standing upright whose mesh reaches a stud's height over its origin,
## and which has studs, to its top face (no vertex of it above its origin
## but its studs'), any other to its highest vertex.
func _body_top(bricks: Array) -> float:
	var top: float = -INF
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var points: PackedVector3Array = _vertices(brick.part_id)
		var highest: float = -INF
		for point: Vector3 in points:
			highest = maxf(highest, point.y)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		var studded: bool = info != null and info.stud_count > 0 \
			and absf(highest - STUD_TOP) < 0.01 and brick.transform.basis.y.y > 0.999
		for point: Vector3 in points:
			if studded and point.y > 0.01:
				continue
			top = maxf(top, (brick.transform * point).y)
	return top


func _vertices(part_id: String) -> PackedVector3Array:
	if _points.has(part_id):
		return _points[part_id]
	var all := PackedVector3Array()
	var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
	if mesh != null:
		for surface: ArrayMesh in mesh.surfaces:
			for n: int in surface.get_surface_count():
				all.append_array(surface.surface_get_arrays(n)[Mesh.ARRAY_VERTEX])
	_points[part_id] = all
	return all


static func _n(value: float) -> String:
	return String.num(value, 2)


# -- MCP ----------------------------------------------------------------------------------

func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


# -- the window ---------------------------------------------------------------------------

func _settle() -> void:
	await _frames(20)
	await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	await _frames(10)


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	var whole: Vector2 = (root.get_final_transform() * at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


## A key pressed and let go, as a person presses it, in this frame.
func _send_key(code: Key, command: bool, shift: bool) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)


func _key(code: Key) -> void:
	_send_key(code, false, false)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join("%s_%s.png" % [name, _size]))


## The status bar alone, at twice its size, to read its words.
func _shot_bar(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var bar: Rect2 = _rect(_shell.status)
	# The bar's place is in the interface's units, scaled by its size
	# setting; the picture is in the window's pixels.
	var pixels: float = image.get_height() / root.get_visible_rect().size.y
	var top: int = clampi(floori(bar.position.y * pixels), 0, image.get_height() - 1)
	var strip: Image = image.get_region(Rect2i(0, top, image.get_width(), image.get_height() - top))
	if strip.is_empty():
		print("    (no picture of the bar: it is at %s in a picture %s)" % [bar, image.get_size()])
		return
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	strip.save_png(_shots.path_join("%s_bar_%s.png" % [name, _size]))


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
