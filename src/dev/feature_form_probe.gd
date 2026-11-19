## A feature given its form is built in the first build and handed back close
## up as built, to check it shows that form.
##
##   godot --path . --resolution 1400x900 --script src/dev/feature_form_probe.gd
##
## design24 (docs/DESIGN_SCORES.md) read the judge's reasons on the base's 46
## likeness verdicts lost to real sets: in 41 the feature was named and built
## and its form was not there — a solid disc for an open wheel, a stubby
## stack for a splayed tower, a flat wall for a curved blade. The session's
## own fresh look named that form in 18 of the 23 sessions, and in 11 its
## final look found it still there. So the form is asked before the first
## build (how_real_sets_build_this's answer leads with it, find_reference's
## pictures end with it, submit_design's features take it), and the feature
## pass hands a feature given one back as built: no real set's piece laid,
## the feature close up from where it faces, with the form said and one
## question, does it show it or read as a block. A feature with no form goes
## the way it went. In a window, for the close look.
extends SceneTree

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
	_read()
	_served()
	await _asked_before()
	await _handed_close_up()
	await _asked_again()
	print("")
	print("feature form: asked before the first build, each feature given one handed back "
		+ "close up as built, the rest as before" if _failures == 0
		else "feature form: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## FeaturePass.read_forms: a form for each feature that says one.
func _read() -> void:
	print("── the forms a submission gives ──")
	var forms: Dictionary = FeaturePass.read_forms({"features": [
		{"name": "London Wheel", "form": " open: a ring of curved parts, bars for spokes "},
		{"name": "headlamps"}, {"name": "blade", "form": ""}, "grille"]})
	_check("one form read, by the name in lower case, trimmed: %s" % JSON.stringify(forms),
		forms.size() == 1 and str(forms.get("london wheel", "")) == "open: a ring of curved "
			+ "parts, bars for spokes")
	_check("none from a submission with no features", FeaturePass.read_forms({}).is_empty()
		and FeaturePass.read_forms({"features": "eyes"}).is_empty())


## The tools say it: submit_design's features take a form, settle_feature says
## what comes back for one, and the connector's method asks for it.
func _served() -> void:
	print("── what the tools and the method say ──")
	var features: Dictionary = _schema("submit_design").get("properties", {}).get("features", {})
	var form: Dictionary = (features.get("items", {}) as Dictionary).get("properties", {}).get(
		"form", {})
	_check("submit_design's features take a form: %s" % str(form.get("description", "")).left(90),
		str(form.get("type", "")) == "string" and str(form.get("description", "")).contains(
			"open (sky through it") and str(features.get("description", "")).contains(
			"never a fill or a stack of bricks") and str(features.get("description", "")
			).contains("a vehicle's wheels or tracks"))
	_check("settle_feature says a feature given its form comes back close up",
		_listed("settle_feature").get("description", "").contains("handed close up as built"))
	_check("the method a connector chat hears asks each feature's form",
		ConnectorGuide.METHOD.contains("its form: open, at an angle, curved")
		and ConnectorGuide.METHOD.contains("never a fill or a stack"))
	_check("...and the instructions' head is as it was, within what Claude Code reads",
		ConnectorGuide.HEAD.length() < 3500 and not ConnectorGuide.HEAD.contains("its form"))


## how_real_sets_build_this leads with the ask while no feature has a form.
func _asked_before() -> void:
	print("── asked before the first build ──")
	await _call("clear_model", {})
	var said: String = _text(await _call("how_real_sets_build_this", {"subject": "tractor"}))
	_check("how_real_sets_build_this leads with the features' forms: %s" % said.left(70),
		said.begins_with("BEFORE THE FIRST BUILD") and said.contains("open (sky shows through it")
		and said.contains("a mast with its forks") and said.contains("never as a fill or a stack"))


## A design whose mast is given its form, its headlamps none, a wheel off the
## model and a frame with no assembly of its name.
func _design(with_forms: bool) -> Dictionary:
	var bricks: Array = []
	for x: int in [0, 4]:
		for z: int in [0, 2]:
			bricks.append({"part": "3001", "color": 4, "x": x, "y": 0, "z": z, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 1})
	bricks.append({"part": "3001", "color": 4, "x": 2, "y": 3, "z": 0, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 2, "y": 3, "z": 2, "rot": 0})
	bricks.append({"part": "3001", "color": 4, "x": 6, "y": 3, "z": 0, "rot": 1})
	for y: int in [6, 9, 12, 15]:
		bricks.append({"part": "3062b", "color": 15, "x": 1, "y": y, "z": 2, "rot": 0})
	var features: Array = [
		{"name": "mast", "x": 1.5, "y": 18, "z": 2.5, "facing": "up"},
		{"name": "headlamps", "x": 8, "y": 3, "z": 2, "facing": "+x"},
		{"name": "spoked wheel", "x": 14, "y": 0, "z": 12, "facing": "+x"},
		{"name": "frame", "x": 4, "y": 3, "z": 4, "facing": "+z"},
	]
	if with_forms:
		features[0]["form"] = "slender: 1x1 round bricks, a stud across and four bricks tall"
		features[2]["form"] = "open: a ring of curved parts round an empty middle"
		features[3]["form"] = "curved: curved slopes along its top"
	return {"name": "Little machine", "description": "a red body with a white mast",
		"brief": "a little machine with a mast", "bricks": bricks, "features": features,
		"assemblies": [
			{"name": "body", "x_from": 0, "x_to": 8, "z_from": 0, "z_to": 4, "y_from": 0,
				"y_to": 6},
			{"name": "mast", "x_from": 0, "x_to": 2, "z_from": 1, "z_to": 4, "y_from": 6,
				"y_to": 18}]}


func _handed_close_up() -> void:
	print("── each feature given its form, handed back close up as built ──")
	var built: String = _text(await _call("submit_design", _design(true)))
	_check("the design stands: %s" % built.get_slice("\n", 0).left(60), built.begins_with("Built."))
	_check("its forms are held, the headlamps' none",
		_assistant.feature_pass().form_of("Mast").begins_with("slender:")
		and _assistant.feature_pass().form_of("headlamps").is_empty())
	var again: String = _text(await _call("how_real_sets_build_this", {"subject": "tractor"}))
	_check("...and how_real_sets_build_this no longer asks", not again.contains("BEFORE THE FIRST"))
	var parts: int = _world.brick_count()
	var review: Array = await _call("review_model", {})
	var said: String = _text(review)
	_check("the whole review lists the mast with its form: %s" % _line_with(said, "  mast:").strip_edges(),
		_line_with(said, "  mast:").contains("its form, slender") and said.contains(
			"one given its form shown close up as built"))
	_check("...and hands it first, close up, with its form: %s" % _line_with(said,
		"Its form, as you gave it").left(120), said.contains("the first feature, the mast — close up "
			+ "as built, to check its form:") and said.contains("The mast — feature 1 of 4. Its form, "
			+ "as you gave it: slender: 1x1 round bricks"))
	_check("...in its own box, from the front, its 4 parts: %s" % _line_with(said, "Here it is").left(110),
		said.contains("Here it is as built, close up from the front (x 0..2, z 1..4, plates 6..18, "
			+ "4 parts)") and said.contains("or does it read as a block, a slab or a stack"))
	var proposal: FeaturePass.Proposal = _assistant.feature_pass().proposal("mast")
	_check("...and no real set's piece is laid for it: %d parts before, %d after" % [parts,
		_world.brick_count()], _world.brick_count() == parts and (proposal == null
			or proposal.piece.is_empty()))
	var pictures: Array = _images(review)
	if ModelShot.possible():
		_check("...with the close look: %d picture(s), %s bytes of PNG" % [pictures.size(),
			str(pictures[-1]) if not pictures.is_empty() else "no"],
			not pictures.is_empty() and int(pictures[-1]) > 1000)
	var next: String = _text(await _call("settle_feature", {"feature": "mast", "verdict": "built",
		"reason": "a stack of white round bricks a stud across, slender as the real one"}))
	_check("settled built, with what the picture shows: %s" % next.get_slice("\n", 0).left(110),
		next.begins_with("The mast: built by the design: a stack of white round bricks")
		and next.contains("Next, the headlamps"))
	_check("...and the headlamps, given no form, go the way they went: %s" % _line_with(next,
		"feature 2 of 4").left(90), next.contains("The headlamps — feature 2 of 4.")
		and not next.contains("Its form, as you gave it") and (next.contains("real set")))
	var wheel: String = _text(await _call("settle_feature", {"feature": "headlamps",
		"verdict": "skip", "reason": "a probe's machine has none"}))
	_check("a feature with nothing where it goes is asked to be built there: %s" % _line_with(wheel,
		"Nothing stands").left(110), wheel.contains("The spoked wheel — feature 3 of 4. Its form, "
			+ "as you gave it: open:") and wheel.contains("Nothing stands where it goes yet (x 10..18")
			and wheel.contains("Build it now, whole, as its own piece"))
	_check("...and nothing is laid for it", _world.brick_count() == parts)
	var frame: String = _text(await _call("settle_feature", {"feature": "spoked wheel",
		"verdict": "skip", "reason": "the probe builds no wheel"}))
	_check("one with no assembly of its name is looked at round where it goes: %s" % _line_with(
		frame, "Here it is").left(110), frame.contains("The frame — feature 4 of 4.")
		and frame.contains("close up from the front (x 0..8, z 0..8, plates 0..18"))
	var done: String = _text(await _call("settle_feature", {"feature": "frame", "verdict": "built",
		"reason": "the body's top course stands for it in this probe"}))
	_check("then every feature is settled, as before: %s" % _line_with(done, "Every feature").left(60),
		done.contains("Every feature is settled") and done.contains("mast: built by the design"))


## A design given again with no forms is asked again before it builds.
func _asked_again() -> void:
	print("── submitted again with no forms ──")
	var built: String = _text(await _call("submit_design", _design(false)))
	_check("the design stands again: %s" % built.get_slice("\n", 0).left(50), built.begins_with("Built."))
	_check("...its features hold no form", _assistant.feature_pass().forms.is_empty())
	var said: String = _text(await _call("how_real_sets_build_this", {"subject": "tractor"}))
	_check("how_real_sets_build_this asks again", said.begins_with("BEFORE THE FIRST BUILD"))
	var review: String = _text(await _call("review_model", {}))
	_check("...and the first feature, given none, has a real set's piece looked for: %s"
		% _line_with(review, "the first feature").left(100), review.contains("the first feature, "
			+ "the mast — the app has laid a real set's piece for it:") or review.contains(
			"No real set's piece"))


func _schema(tool: String) -> Dictionary:
	return _listed(tool).get("inputSchema", {}) as Dictionary


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


## The size in bytes of each picture in an answer.
static func _images(blocks: Array) -> Array:
	var out: Array = []
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			out.append(Marshalls.base64_to_raw(str(block.get("data", ""))).size())
	return out


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
