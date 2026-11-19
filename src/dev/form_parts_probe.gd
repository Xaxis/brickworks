## A form's parts, read from real sets, arrive laid in a feature's close look.
##
##   godot --path . --resolution 1400x900 --script src/dev/form_parts_probe.gd
##
## design24 asked each feature's form before the first build and won head to
## head twice, then lost its surface to the set by 14 points: where it lost,
## the judge named the design's steps in 49 of 63 — forms laid in plates
## stepped in, where real sets turn them with curved slopes, wedges and SNOT
## (docs/DESIGN_SCORES.md). design25 reads what real sets build each form
## with, by each piece's own geometry and parts (tools/form_parts.py ->
## assets/knowledge/form_parts.json.gz, read by FormParts), and the close look
## lays those parts where the feature's plates step (FeaturePass.lay_form,
## SurfacePass.form_finish), settled in the one settle_feature every session
## already answers: accept keeps them, next lays them the next way, reject
## takes them off and puts back what they replaced, built keeps what stands.
##
## Checks: the table has the ten forms with parts and the sets they came
## from, none of the bench's held-out sets among them; a design's words are
## read as forms; and over the port, a nose of plates stepped in has curved
## slopes laid on its steps, the next way straight ones, a reject puts the
## model back as it was, a taper is laid in straight slopes first and an
## accept keeps them. In a window, for the close look's picture.
extends SceneTree

const FORMS := ["curved", "round", "arched", "tapering", "flaring", "leaning", "turned",
	"twisted", "open", "slender"]
## Sets of the bench's two halves (tools/bench/realset.py): the 16 the screen
## runs on, and some of the 44 its proof does.
const HELD := ["21030-1", "21004-1", "21007-1", "21018-1", "21036-1", "21022-1", "21029-1",
	"42107-1", "7636-1", "7634-1", "7685-1", "42079-1", "21051-1", "21034-1", "21039-1",
	"21043-1", "21035-1", "42081-1", "5763-1", "7746-1", "21023-1", "9469-1"]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _assistant: Assistant
var _world: BrickWorld
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_table()
	_words()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	(_main.get("_store") as ModelStore).keeps = false
	_assistant = _main.get("_assistant")
	_world = _main.get("_world")
	_served()
	await _laid_in_the_close_look()
	await _accepted()
	print("")
	print("form parts: the table's ten forms from real sets, none held out, laid where a "
		+ "feature's plates step and settled with it" if _failures == 0
		else "form parts: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The table: ten forms, each with a size whose parts and sets are listed, and
## none of the bench's held-out sets read.
func _table() -> void:
	print("── the table, read from real sets ──")
	var table: Dictionary = FormParts.table()
	_check("the table is there: %d pieces read, %d sets" % [int(table.get("pieces", 0)),
		(table.get("sets", {}) as Dictionary).size()], FormParts.available()
		and int(table.get("pieces", 0)) > 5000 and (table.get("sets", {}) as Dictionary).size() > 500)
	var forms: Dictionary = table.get("forms", {})
	for form: String in FORMS:
		var best: Dictionary = {}
		for size: Variant in (forms.get(form, {}) as Dictionary).get("sizes", {}).values():
			var any: Dictionary = (size as Dictionary).get("any", {})
			if int(any.get("entries", 0)) > int(best.get("entries", 0)):
				best = any
		var parts: Array = best.get("parts", [])
		var sets: Array = best.get("sets", [])
		_check("%s: %d pieces of %d sets; %s; from %s" % [form, int(best.get("entries", 0)),
			int(best.get("set_count", 0)), ", ".join(parts.slice(0, 3).map(
				func(row: Array) -> String: return "%s %s" % [row[0], FormParts.name_of(str(row[0]))])),
			", ".join(sets.slice(0, 2).map(func(row: Array) -> String: return str(row[0])))],
			int(best.get("entries", 0)) >= 5 and parts.size() >= 3 and sets.size() >= 3)
	var held: Array = table.get("held_out", [])
	_check("it held out the bench's subjects: %d sets, the screen's 16 and the proof's among them"
		% held.size(), held.size() >= 88 and HELD.all(func(id: String) -> bool:
			return held.has(id)))
	var read_from: Dictionary = table.get("sets", {})
	var met := PackedStringArray()
	for id: Variant in read_from:
		var base: String = str(id).get_slice("-", 0)
		for one: Variant in held:
			if str(one).get_slice("-", 0) == base:
				met.append(str(id))
	# And by name, as DesignMemory.holds reads one: 21004-1 is the Guggenheim
	# as much as 21035-1 is.
	for name: Variant in table.get("held_out_names", []):
		var words: PackedStringArray = RealSnippets.words(str(name))
		for id: Variant in read_from:
			var said: PackedStringArray = RealSnippets.words(str((read_from[id] as Array)[0]))
			if not said.is_empty() and not words.is_empty() and (Array(said).all(
					func(w: String) -> bool: return words.has(w)) or Array(words).all(
					func(w: String) -> bool: return said.has(w))):
				met.append("%s (%s)" % [str(id), str(name)])
	_check("...and read none of them, by number or by name: %s" % (", ".join(met) if not
		met.is_empty() else "none"), met.is_empty())
	var cited := PackedStringArray()
	for form: Variant in forms.values():
		for size: Variant in (form as Dictionary).get("sizes", {}).values():
			for cell: Variant in (size as Dictionary).values():
				for row: Variant in (cell as Dictionary).get("sets", []):
					if HELD.has(str((row as Array)[0])) or not read_from.has(str((row as Array)[0])):
						cited.append(str((row as Array)[0]))
	_check("every set a cell cites is one it read, none held out: %s" % (", ".join(cited)
		if not cited.is_empty() else "so"), cited.is_empty())
	var cell: Dictionary = FormParts.cell("curved", 6.0, "Architecture")
	var said: String = FormParts.said(cell)
	_check("a cell in words: %s" % said.left(150), said.begins_with("Real ")
		and said.contains("curved in profile") and said.contains("their technique")
		and said.contains("pieces of"))
	# A set the run holds out is never named, though the table were to cite it.
	var first: String = str(((cell.get("sets", []) as Array)[0] as Array)[0])
	DesignMemory.hold_out(PackedStringArray([first]))
	_check("...and a set held out by the run is not named: %s" % first,
		not FormParts.said(cell).contains(first + " "))
	DesignMemory.hold_out(PackedStringArray())
	_check("sizes: 3 studs small, 7 medium, 14 large", FormParts.size_of(3.0) == "small"
		and FormParts.size_of(7.0) == "medium" and FormParts.size_of(14.0) == "large")
	_check("a theme said in a brief is the table's: %s" % FormParts.theme_in(
		"The Capitol, in the style of LEGO® Architecture sets"),
		FormParts.theme_in("The Capitol, in the style of LEGO® Architecture sets") == "Architecture")


## A design's own words, read as forms, the first named first.
func _words() -> void:
	print("── a design's words, read as forms ──")
	# The form said before a colon is the form; the parts after it are not.
	var cases: Array = [
		["curved: a dome of curved slopes over a round drum", ["curved"]],
		["open: a ring of bars round an empty middle, spokes to the hub", ["open"]],
		["slender and tapering: a shaft into a spire", ["slender", "tapering"]],
		["at an angle: legs splayed out on hinges", ["leaning"]],
		["twisted: each floor turned a little", ["twisted"]],
		["set back above the overhanging cornice: a narrower box", ["flaring"]],
		# With no colon, or none named before it, the words are read whole.
		["tapering to a point, setbacks every few bricks", ["tapering"]],
		["arched gateway with a flared cornice", ["arched", "flaring"]],
		["the main one: a round drum under a dome", ["round", "curved"]],
		["a plain box", []],
	]
	for row: Array in cases:
		var got: PackedStringArray = FormParts.forms_in(str(row[0]))
		var want: Array = row[1]
		var ok: bool = got.size() >= want.size()
		for n: int in want.size():
			ok = ok and n < got.size() and got[n] == str(want[n])
		_check("\"%s\" -> %s" % [row[0], ", ".join(got)], ok and (not want.is_empty()
			or got.is_empty()))
	# What is laid for each: slopes and skins for a curve in profile or a
	# taper, nothing for a form no slope or skin makes.
	var curve: Array = FeaturePass.form_ways(PackedStringArray(["curved"]))
	var taper: Array = FeaturePass.form_ways(PackedStringArray(["slender", "tapering"]))
	var both: Array = FeaturePass.form_ways(PackedStringArray(["slender", "curved", "tapering"]))
	_check("a curve is laid in curved slopes first, its edges rounded, then straight ones",
		curve.size() == 3 and not bool(curve[0]["straight"]) and bool(curve[0]["edges"])
		and bool(curve[0]["skins"]) and bool(curve[1]["straight"]))
	_check("...a taper in straight slopes first, and a curve named first goes curved",
		not taper.is_empty() and bool(taper[0]["straight"]) and not bool(taper[0]["edges"])
		and not both.is_empty() and not bool(both[0]["straight"]))
	var none := PackedStringArray()
	for form: String in ["round", "arched", "flaring", "open", "slender", "leaning", "turned",
			"twisted"]:
		if not FeaturePass.form_ways(PackedStringArray([form])).is_empty():
			none.append(form)
	_check("...and nothing for round, arched, flaring, open, slender, at an angle, turned or "
		+ "twisted: %s" % (", ".join(none) if not none.is_empty() else "none laid"), none.is_empty())


func _served() -> void:
	print("── what the tools say ──")
	_check("settle_feature says a formed feature comes back with real sets' parts laid",
		str(_listed("settle_feature").get("description", "")).contains(
			"real sets' parts for that form laid where its plates step"))
	_check("the connector's method says so in step 4",
		ConnectorGuide.METHOD.contains("real sets' parts \nfor that form")
		or ConnectorGuide.METHOD.contains("real sets' parts for that form"))


## A nose of plates stepped in a stud every plate, on a block of bricks
## (surface_probe's stair): the stepped look design24's surface lost on, and
## the treads a real set lays curved slopes on, two plates and two studs at a
## time.
func _design(form: String) -> Dictionary:
	return {"name": "Little speeder", "description": "a white speeder with a stepped nose",
		"brief": "a little speeder", "bricks": [
			{"part": "3001", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3003", "color": 15, "x": 4, "y": 0, "z": 0, "rot": 0},
			{"part": "3795", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
			{"part": "3020", "color": 15, "x": 1, "y": 4, "z": 0, "rot": 0},
			{"part": "3023b", "color": 15, "x": 5, "y": 4, "z": 0, "rot": 1},
			{"part": "3020", "color": 15, "x": 2, "y": 5, "z": 0, "rot": 0},
			{"part": "3021", "color": 15, "x": 3, "y": 6, "z": 0, "rot": 0},
			{"part": "3022", "color": 15, "x": 4, "y": 7, "z": 0, "rot": 0}],
		"features": [{"name": "nose", "x": 3, "y": 8, "z": 1, "facing": "-x", "form": form}],
		"assemblies": [
			{"name": "body", "x_from": 0, "x_to": 6, "z_from": 0, "z_to": 2, "y_from": 0,
				"y_to": 3},
			{"name": "nose", "x_from": 0, "x_to": 6, "z_from": 0, "z_to": 2, "y_from": 3,
				"y_to": 8}]}


func _laid_in_the_close_look() -> void:
	print("── a nose stepped in plates, close up ──")
	await _call("clear_model", {})
	var built: String = _text(await _call("submit_design", _design(
		"curved: a nose rounded over, of curved slopes")))
	_check("the design stands: %s" % built.get_slice("\n", 0).left(60), built.begins_with("Built."))
	var before: Dictionary = _parts()
	var steps: Array = _assistant.surface_pass().steps_in(_assistant._bounds_of(
		_assistant._bricks_inside({})).grow(2.0))
	_check("its steps are read, a stud each plate from the left: %s"
		% SurfacePass.steps_said(steps, 4), steps.size() == 1 and _four_in(steps[0]))
	var review: Array = await _call("review_model", {})
	var said: String = _text(review)
	var one: FeaturePass.Proposal = _assistant.feature_pass().proposal("nose")
	_show(said, "The nose — feature 1 of 1")
	_check("the close look reads what real sets build its form with: %s" % _line_with(said,
		"sets build ").left(140), said.contains("The nose — feature 1 of 1. Its form, as you "
		+ "gave it") and _line_with(said, "sets build ").contains("curved in profile"))
	_check("...and lays them where its plates step: %s" % _line_with(said, "  S").strip_edges().left(140),
		one != null and one.formed() and said.contains("The app has laid real sets' parts for "
			+ "that form where its plates step"))
	var laid: Dictionary = _added(before, _parts())
	var curved: int = 0
	for part: String in laid:
		var info: PartLibrary.PartInfo = _assistant.library.parts.get(part)
		if info != null and info.name.to_lower().contains("curved"):
			curved += int(laid[part])
	_check("...curved slopes on its treads, %d of the %d parts laid: %s" % [curved,
		_count(laid), JSON.stringify(laid)], curved > 0)
	_check("...each finding the nose's, settled with it, not by settle_surface",
		one != null and one.finish.all(_the_noses))
	_check("...and asked the one question: accept, next, reject or built",
		said.contains("settle_feature {\"feature\": \"nose\", \"verdict\": \"accept\"} keeps"))
	if ModelShot.possible():
		var pictures: Array = _images(review)
		_check("...with the close look: %d picture(s)" % pictures.size(), not pictures.is_empty()
			and int(pictures[-1]) > 1000)
	# next: the other slope family.
	var first_laid: Dictionary = laid
	var next: String = _text(await _call("settle_feature", {"feature": "nose", "verdict": "next"}))
	_show(next, "The nose — feature 1 of 1")
	var then: Dictionary = _added(before, _parts())
	_check("next lays them the next way: %s" % JSON.stringify(then), one.formed()
		and next.contains("The nose — feature 1 of 1") and then != first_laid
		and not then.is_empty())
	# reject: everything back as the design built it.
	var short: String = _text(await _call("settle_feature", {"feature": "nose",
		"verdict": "reject"}))
	_check("a reject asks why: %s" % short.left(80), short.begins_with("Say why"))
	var rejected: String = _text(await _call("settle_feature", {"feature": "nose",
		"verdict": "reject", "reason": "the probe wants its stepped nose as built"}))
	_check("rejected with a reason, the parts come off: %s" % rejected.get_slice("\n", 0).left(90),
		rejected.contains("The nose: the app's piece rejected: the probe wants")
		and _parts() == before and not one.formed())
	_check("...and the surface pass leaves the place alone after",
		_assistant.surface_pass().zones.size() >= 1)


func _accepted() -> void:
	print("── accepted ──")
	await _call("clear_model", {})
	var built: String = _text(await _call("submit_design", _design(
		"tapering: a nose narrowing to a point")))
	_check("built again, a taper: %s" % built.get_slice("\n", 0).left(50), built.begins_with("Built."))
	var before: Dictionary = _parts()
	await _call("review_model", {})
	var one: FeaturePass.Proposal = _assistant.feature_pass().proposal("nose")
	var laid: Dictionary = _added(before, _parts())
	var straight: int = 0
	for part: String in laid:
		var info: PartLibrary.PartInfo = _assistant.library.parts.get(part)
		if info != null and info.family_category() == "Slope" \
				and not info.name.to_lower().contains("curved"):
			straight += int(laid[part])
	_check("a taper is laid in straight slopes first: %s" % JSON.stringify(laid),
		one != null and one.formed() and straight > 0)
	var done: String = _text(await _call("settle_feature", {"feature": "nose", "verdict": "accept"}))
	_check("accepted, they stay: %s" % done.get_slice("\n", 0).left(100),
		done.contains("The nose: %d of real sets' parts for its form laid by the app, accepted"
			% one.ids.size()) and _added(before, _parts()) == laid)
	_check("...their findings settled with it", one.finish.all(_accepted_one)
		and _assistant.surface_pass().open().is_empty())


static func _four_in(run: Dictionary) -> bool:
	return str(run["face"]) == "-x" and str(run["way"]) == "in" and int(run["steps"]) == 4 \
		and int(run["covered"]) == 0


static func _the_noses(one: SurfacePass.Finding) -> bool:
	return one.feature == "nose" and not one.settled()


static func _accepted_one(one: SurfacePass.Finding) -> bool:
	return one.verdict == "accepted"


## Part id -> how many stand, building parts of the main model.
func _parts() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _assistant._bricks_inside({}):
		out[brick.part_id] = int(out.get(brick.part_id, 0)) + 1
	return out


## What stands now that did not before, by part.
static func _added(before: Dictionary, now: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part: String in now:
		var more: int = int(now[part]) - int(before.get(part, 0))
		if more > 0:
			out[part] = more
	return out


static func _count(parts: Dictionary) -> int:
	var n: int = 0
	for part: String in parts:
		n += int(parts[part])
	return n


func _listed(tool: String) -> Dictionary:
	for one: Variant in _socket.served_tools():
		if str((one as Dictionary).get("name", "")) == tool:
			return one
	return {}


func _call(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


static func _text(blocks: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return "\n".join(out)


static func _images(blocks: Array) -> Array:
	var out: Array = []
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			out.append(Marshalls.base64_to_raw(str(block.get("data", ""))).size())
	return out


## What a session hears from [param from] on, for the log.
static func _show(text: String, from: String) -> void:
	var at: int = text.find(from)
	for line: String in text.substr(maxi(at, 0)).split("\n").slice(0, 24):
		print("    | " + line.left(400))


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
