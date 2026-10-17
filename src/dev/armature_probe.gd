## Does {"pattern": "figure"} lay a character on joints that work, and is a
## character with no joint sent back once and only once?
##
##   godot --headless --path . --script src/dev/armature_probe.gd [-- --out=DIR]
##
## Told of the joints in every reply, two of eight character sessions posed a
## limb (docs/BRICKBENCH.md, "figures on joints"). So the jointed body is one
## entry of patterns (FigurePattern), and a character submitted with nothing on
## a joint is sent back once with that entry written out for it. Each must:
##   - lay a person (small, large, seated), an animal (small, large) and a head
##     on a neck, every part attached, named, joined to what it went on by
##     BrickNet's labels, clear of every other by verify.py's 1 LDU, and passed
##     by the check standing on a bare floor;
##   - put each limb, the head and the tail on a joint that turns: a different
##     pose turns that part about the joint, still joined, and the pose words
##     land where they say (a raised hand over the shoulder, a forward one in
##     front, an animal's head up or down, its tail raised or down);
##   - hold: submitted, a later edit leaves every posed part where it stood, and
##     an arm and a head posed again by an edit stand where the new pose puts
##     them, still joined;
##   - send a figure or a creature with nothing on a joint back once, with an
##     entry that builds when submitted as it is; build it when it comes again;
##     and never send back a vehicle with its crew, a toy car or a tower.
##
## --out=DIR writes each laid kind as DIR/<kind>.ldr, for BrickBench's verify.py.
extends SceneTree

var _failures: int = 0
var _passed: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _assistant: Assistant
var _out: String = ""

const AT := {"x": 4, "y": 0, "z": 4}
## Each kind as a session would say it: [label, the pattern, the names it must have].
const KINDS: Array = [
	["person, small", {"pattern": "figure", "kind": "person", "at": AT, "height": 30, "color": 1,
		"colors": {"legs": 72, "hair": 0}, "pose": {"right arm": "down", "left arm": "raised",
		"head": 20}}, ["head", "face", "hair", "neck", "chest", "hips", "right shoulder",
		"left shoulder", "right upper arm", "left forearm", "right hand", "left hand",
		"right foot", "left leg"]],
	["person, large", {"pattern": "figure", "kind": "person", "at": AT, "height": 42, "color": 4,
		"colors": {"legs": 1, "hair": 70}, "pose": {"right arm": "forward", "left arm": "out"}},
		["head", "chest", "right hand", "left hand", "right shoulder", "left shoulder"]],
	["person, seated", {"pattern": "figure", "kind": "person", "at": AT, "height": 36, "color": 70,
		"colors": {"skin": 70, "seat": 72}, "pose": {"seated": true, "right arm": "to chin",
		"left arm": "on knee"}}, ["seat", "right thigh", "left knee", "head", "right hand",
		"left hand"]],
	["animal, small", {"pattern": "figure", "kind": "animal", "at": AT, "length": 6, "color": 1,
		"pose": {"head": "up", "tail": "raised"}}, ["body", "neck", "jaw", "head", "rump", "tail",
		"right foreleg", "left hind leg"]],
	["animal, large", {"pattern": "figure", "kind": "animal", "at": AT, "length": 8, "color": 70,
		"pose": {"tail": "raised"}}, ["body", "back", "neck", "jaw", "head", "crown", "rump", "tail"]],
	["head on a neck", {"pattern": "figure", "kind": "head", "at": AT, "height": 12, "color": 15,
		"pose": {"head": 30}}, ["neck", "chin", "head", "face", "hair"]],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	if Exact.shape_for(_library, "14417") == null:
		print("armature probe: SKIPPED, no assets/generated/exact/ to judge joints by")
		quit(0)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	var builder := Builder.new()
	builder.world = _world
	builder.library = _library
	root.add_child(builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = builder
	root.add_child(_assistant)
	await process_frame

	print("\neach kind, laid")
	for kind: Array in KINDS:
		_kind(str(kind[0]), kind[1], kind[2])

	print("\neach joint turns, and the pose words land where they say")
	_arms(30)
	_arms(42)
	_turns("the head turns on its jumper's stud", KINDS[0][1], "head", "neck",
		{"head": 0}, {"head": 40}, 40.0)
	_turns("a head on a neck turns on its jumper's stud", KINDS[5][1], "head", "chin",
		{"head": 0}, {"head": -45}, 45.0)
	_turns("an animal's head nods on its ball neck", KINDS[3][1], "jaw", "neck",
		{"head": "up"}, {"head": "down"}, 0.0)
	_turns("an animal's head looks aside on its ball neck", KINDS[4][1], "jaw", "neck",
		{"head": "left"}, {"head": "right"}, 0.0)
	_turns("an animal's tail swings on its bar", KINDS[3][1], "tail", "rump",
		{"tail": "raised"}, {"tail": "down"}, 60.0)
	_animal_poses()

	print("\nsubmitted, the joints hold")
	await _holds()

	print("\nsent back once")
	await _refusals()

	print("\narmature probe: %d passed, %d failed" % [_passed, _failures])
	quit(1 if _failures > 0 else 0)


## A pattern read as a session's design: the model, each part's transform as
## built, the trouble the reading had, and each named part's index.
func _laid(pattern: Dictionary, bricks: Array = []) -> Dictionary:
	var model: Assistant.Model = _assistant._read_model({"name": "probe",
		"description": "a figure", "floor": "none", "patterns": [pattern], "bricks": bricks})
	var at: Array = []
	var named: Dictionary = {}
	for n: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[n]
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		at.append(_assistant._transform(placement, mesh, model.section_for(placement))
			if mesh != null else Transform3D())
		if not placement.name.is_empty():
			named[placement.name] = n
	return {"model": model, "at": at, "named": named,
		"trouble": _assistant._pattern_trouble.duplicate()}


## Each attached part joined to what it went on, by BrickNet's labels: the
## parts that are not, as "part (connector)".
func _unjoined(laid: Dictionary) -> PackedStringArray:
	var model: Assistant.Model = laid["model"]
	var items: Array = []
	for n: int in model.placements.size():
		var shape: Exact.Shape = Exact.shape_for(_library, model.placements[n].part)
		items.append(Exact.Item.new(shape, laid["at"][n]) if shape != null else null)
	var index_of: Dictionary = {}
	for n: int in model.placements.size():
		index_of[model.placements[n]] = n
	var edges: Array = Exact.connections(items)
	var out := PackedStringArray()
	for n: int in model.placements.size():
		var on: Assistant.Placement = model.placements[n].attached_to
		if on == null:
			continue
		var m: int = int(index_of[on])
		if not edges.any(func(e: Array) -> bool:
				return int(e[0]) == mini(n, m) and int(e[2]) == maxi(n, m)):
			out.append("%s (%s)" % [model.placements[n].part, model.placements[n].attached_by])
	return out


func _kind(label: String, pattern: Dictionary, names: Array) -> void:
	var laid: Dictionary = _laid(pattern)
	var model: Assistant.Model = laid["model"]
	_ok((laid["trouble"] as Array).is_empty() and model.placements.size() >= 8,
		"%s: laid, %d parts %s" % [label, model.placements.size(), laid["trouble"]])
	var odd := PackedStringArray()
	var attached: int = 0
	for placement: Assistant.Placement in model.placements:
		if not placement.odd_attach.is_empty() or not placement.attach.is_empty():
			odd.append("%s %s" % [placement.part, placement.odd_attach])
		if placement.attached_to != null:
			attached += 1
	_ok(odd.is_empty() and attached >= 4, "%s: every part said by its connectors is on them (%d) %s"
		% [label, attached, ", ".join(odd)])
	var missing: Array = names.filter(func(n: String) -> bool:
		return not (laid["named"] as Dictionary).has(n))
	_ok(missing.is_empty(), "%s: its parts are named to build on %s" % [label,
		"" if missing.is_empty() else "(no %s)" % ", ".join(PackedStringArray(missing))])
	_ok(Assistant._posed(model), "%s: it is posed, so it is never sent back" % label)
	var unjoined: PackedStringArray = _unjoined(laid)
	_ok(unjoined.is_empty(), "%s: each joined to what it went on by BrickNet's labels %s"
		% [label, ", ".join(unjoined)])
	var items: Array = []
	for n: int in model.placements.size():
		items.append(Exact.Item.new(Exact.shape_for(_library, model.placements[n].part),
			laid["at"][n]))
	var clashes := PackedStringArray()
	for found: Dictionary in Exact.clashes(items):
		clashes.append("%s and %s, %s LDU" % [model.placements[int(found["a"])].part,
			model.placements[int(found["b"])].part, str(snappedf(float(found["depth"]), 0.01))])
	_ok(clashes.is_empty(), "%s: no two parts overlap by more than 1 LDU %s"
		% [label, ", ".join(clashes)])
	var report: Dictionary = _assistant._check(model, true)
	var exact_said: Array = []
	for what: Variant in (report.get("exact", {}) as Dictionary):
		exact_said.append_array(report["exact"][what])
	_ok(bool(report.get("ok", false)) and exact_said.is_empty(),
		"%s: the check passes it on a bare floor (%s)%s" % [label, report.get("summary", ""),
			"" if bool(report.get("ok", false)) and exact_said.is_empty()
			else ": %s %s" % [str(report.get("feedback", "")).left(600), exact_said]])
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
		var file := FileAccess.open(_out.path_join(label.replace(", ", "-").replace(" ", "-")
			+ ".ldr"), FileAccess.WRITE)
		file.store_string(_ldr_of(model, laid["at"]))
		file.close()


## The angle between two parts' turns, in degrees.
static func _between(a: Transform3D, b: Transform3D) -> float:
	return rad_to_deg((a.basis.orthonormalized().inverse() * b.basis.orthonormalized())
		.get_rotation_quaternion().get_angle())


## One joint posed two ways: [param part] turns about it by [param degrees]
## (any turn of 30 or more when 0), still joined, and nothing but what hangs on
## it moves.
func _turns(what: String, pattern: Dictionary, part: String, on: String, one: Dictionary,
		other: Dictionary, degrees: float) -> void:
	var a: Dictionary = _laid(_posed_as(pattern, one))
	var b: Dictionary = _laid(_posed_as(pattern, other))
	var ia: int = int((a["named"] as Dictionary).get(part, -1))
	var ib: int = int((b["named"] as Dictionary).get(part, -1))
	var ja: int = int((a["named"] as Dictionary).get(on, -1))
	var jb: int = int((b["named"] as Dictionary).get(on, -1))
	if ia < 0 or ib < 0 or ja < 0 or jb < 0:
		_ok(false, "%s: no part named %s on %s" % [what, part, on])
		return
	var turned: float = _between(a["at"][ia], b["at"][ib])
	var base_still: bool = (a["at"][ja] as Transform3D).is_equal_approx(b["at"][jb])
	var joined: bool = _unjoined(a).is_empty() and _unjoined(b).is_empty()
	var right: bool = absf(turned - degrees) < 1.0 if degrees > 0.0 else turned >= 30.0
	_ok(right and base_still and joined, "%s: %s turns %d° on %s, which stays put, joined both ways"
		% [what, part, roundi(turned), on])


static func _posed_as(pattern: Dictionary, pose: Dictionary) -> Dictionary:
	var out: Dictionary = pattern.duplicate(true)
	var now: Dictionary = (out.get("pose", {}) as Dictionary).duplicate()
	now.merge(pose, true)
	out["pose"] = now
	return out


## Each arm pose word at [param height]: the hand where the word says against
## the shoulder, the upper arm turned on its ball, the whole passed by the check.
func _arms(height: int) -> void:
	var person: Dictionary = {"pattern": "figure", "kind": "person", "at": AT, "height": height,
		"color": 4}
	var hands: Dictionary = {}
	var uppers: Dictionary = {}
	var shoulder := Vector3.ZERO
	for word: String in ["down", "bent", "forward", "raised", "out"]:
		var laid: Dictionary = _laid(_posed_as(person, {"right arm": word, "left arm": word}))
		var named: Dictionary = laid["named"]
		var report: Dictionary = _assistant._check(laid["model"], true)
		var unjoined: PackedStringArray = _unjoined(laid)
		_ok(bool(report.get("ok", false)) and unjoined.is_empty(),
			"%d plates, both arms %s: joined and passed (%s) %s" % [height, word,
				report.get("summary", ""), "" if bool(report.get("ok", false))
				else str(report.get("feedback", "")).left(400)])
		shoulder = (laid["at"][named["left shoulder"]] as Transform3D).origin
		hands[word] = (laid["at"][named["left hand"]] as Transform3D).origin - shoulder
		uppers[word] = laid["at"][named["left upper arm"]]
	# The model's y is up, its z the way the figure faces, its left arm at high x.
	var d: Vector3 = hands["down"]
	var f: Vector3 = hands["forward"]
	var r: Vector3 = hands["raised"]
	var o: Vector3 = hands["out"]
	var b: Vector3 = hands["bent"]
	_ok(d.y < -20.0 and r.y > 20.0 and f.y > d.y + 40.0 and f.y < r.y - 40.0
		and f.z > d.z + 30.0 and f.z > r.z + 30.0 and o.x > maxf(d.x, r.x) + 20.0
		and b.z > d.z + 15.0 and b.y > d.y + 40.0,
		"%d plates: the hand lands where the word says (down %s, bent %s, forward %s, raised %s, out %s)"
			% [height, _v(d), _v(b), _v(f), _v(r), _v(o)])
	var least: float = 180.0
	var words: Array = uppers.keys()
	for i: int in words.size():
		for j: int in range(i + 1, words.size()):
			if words[i] == "bent" and words[j] == "forward":
				continue    # The same upper arm; the forearm differs.
			least = minf(least, _between(uppers[words[i]], uppers[words[j]]))
	_ok(least >= 20.0, "%d plates: each pose turns the upper arm on its ball, %d° apart at least"
		% [height, roundi(least)])


static func _v(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x), roundi(v.y), roundi(v.z)]


## An animal's head up is above its head down, and its tail raised above level
## above down.
func _animal_poses() -> void:
	var heads: Dictionary = {}
	var tails: Dictionary = {}
	for word: String in ["up", "forward", "down"]:
		var laid: Dictionary = _laid(_posed_as(KINDS[3][1], {"head": word}))
		heads[word] = (laid["at"][laid["named"]["head"]] as Transform3D).origin
	for word: String in ["raised", "level", "down"]:
		var laid: Dictionary = _laid(_posed_as(KINDS[3][1], {"tail": word}))
		var report: Dictionary = _assistant._check(laid["model"], true)
		_ok(bool(report.get("ok", false)), "the animal, tail %s: passed (%s)"
			% [word, report.get("summary", "")])
		var tail: Transform3D = laid["at"][laid["named"]["tail"]]
		tails[word] = tail.origin + tail.basis * Vector3(0, 0, 0)
	_ok(heads["up"].y > heads["forward"].y and heads["forward"].y > heads["down"].y,
		"the animal's head up stands over forward over down (%s, %s, %s)"
			% [_v(heads["up"]), _v(heads["forward"]), _v(heads["down"])])


## Submitted as a session submits it, every posed part stays where it stood
## through a later edit and reads back where it stands; an arm and a head posed
## again by an edit stand where the new pose puts them, still joined.
func _holds() -> void:
	_world.clear()
	_assistant.forget_built()
	_assistant.heard("A knight stands guard, one arm raised", true)
	var person: Dictionary = KINDS[0][1].duplicate(true)
	var said: String = _text(await _assistant.use_tool("submit_design", {"name": "Knight",
		"description": "a knight standing guard", "floor": "none", "patterns": [person]}))
	_ok(said.begins_with("Built"), "the person is submitted and built: %s" % said.left(160))
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = brick.transform
	var first: int = (before.keys() as Array).min() if not before.is_empty() else 0
	said = _text(await _assistant.use_tool("edit_model", {"recolor": [{"bricks": [first],
		"color": 0}]}))
	var moved := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if before.has(brick.id) and not (before[brick.id] as Transform3D).is_equal_approx(
				brick.transform):
			moved.append(brick.part_id)
	_ok(not said.begins_with("Not applied") and moved.is_empty()
		and _world.brick_count() == before.size(),
		"a later edit leaves every posed part where it stood %s" % ", ".join(moved))
	var model: Assistant.Model = _assistant._model_from_world()
	var off := PackedStringArray()
	for placement: Assistant.Placement in model.placements:
		var brick: BrickWorld.Brick = _world.get_brick(placement.id)
		var again: Transform3D = _assistant._transform(placement,
			_library.mesh_for(placement.part), model.section_for(placement))
		if brick != null and again.origin.distance_to(brick.transform.origin) > 0.01:
			off.append(placement.part)
	_ok(off.is_empty(), "read back, every part is written where it stands %s" % ", ".join(off))

	# The right arm raised by an edit, as a session poses it again: its parts
	# taken off and put on again at the new angle, on the shoulder by its name.
	var ids_of: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		if not placement.name.is_empty():
			ids_of[placement.name] = placement.id
	var forearm: Vector3 = _world.get_brick(int(ids_of["right forearm"])).transform.origin
	var tile: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3070b" and (tile == 0 or brick.transform.origin.distance_to(forearm)
				< _world.get_brick(tile).transform.origin.distance_to(forearm)):
			tile = brick.id
	var off_arm: Array = [tile]
	for name: String in ["right upper arm", "right sleeve", "right forearm", "right hand"]:
		off_arm.append(ids_of[name])
	var on_the_arm := func(brick: Dictionary) -> bool:
		var to: String = str((brick.get("attach", {}) as Dictionary).get("to", ""))
		return to.begins_with("right upper arm") or to.begins_with("right forearm") \
			or to.begins_with("right shoulder")
	await _posed_again("the right arm raised", person, {"right arm": "raised"}, off_arm,
		on_the_arm, "right hand")
	ids_of.clear()
	for placement: Assistant.Placement in _assistant._model_from_world().placements:
		if not placement.name.is_empty():
			ids_of[placement.name] = placement.id
	var the_head := func(brick: Dictionary) -> bool:
		return str(brick.get("name", "")) in ["head", "face", "hair"]
	await _posed_again("the head turned to 60°", _posed_as(person, {"right arm": "raised"}),
		{"head": 60}, [ids_of["head"], ids_of["face"], ids_of["hair"]], the_head, "face")


## Parts [param off] taken off by an edit and the ones [param keep] picks from
## [param pattern] posed by [param pose] put on again: [param mark] then stands
## where the pattern posed so lays it, the edit passed.
func _posed_again(what: String, pattern: Dictionary, pose: Dictionary, off: Array,
		keep: Callable, mark: String) -> void:
	var posed: Dictionary = _posed_as(pattern, pose)
	var trouble: Array = []
	var bricks: Array = (FigurePattern.lay(posed, trouble)["bricks"] as Array).filter(keep)
	var count: int = _world.brick_count()
	var said: String = _text(await _assistant.use_tool("edit_model", {"remove": off,
		"add": bricks}))
	var laid: Dictionary = _laid(posed)
	var want: Transform3D = laid["at"][laid["named"][mark]]
	var stands: Transform3D = Transform3D()
	for placement: Assistant.Placement in _assistant._model_from_world().placements:
		if placement.name == mark:
			stands = _world.get_brick(placement.id).transform
	var miss: float = stands.origin.distance_to(want.origin) + _between(stands, want)
	_ok(not said.begins_with("Not applied") and _world.brick_count() == count
		and off.size() == bricks.size() and miss < 0.01,
		"%s by an edit: the %s stands where that pose puts it (%s LDU and degrees off) %s"
			% [what, mark, str(snappedf(miss, 0.001)), "" if not said.begins_with("Not applied")
				else said.left(400)])


## A character with nothing on a joint is sent back once, with an entry that
## builds; a vehicle with its crew, a toy car and a tower never are.
func _refusals() -> void:
	_world.clear()
	_assistant.forget_built()
	_assistant.heard("A dark-brown statue of a man sits hunched forward on a rough block.", true)
	var statue: Dictionary = {"name": "Thinker", "description": "a seated statue of a man",
		"floor": "none", "bricks": _stacked()}
	var sent: String = _text(await _assistant.use_tool("submit_design", statue))
	var call: Dictionary = _call_in(sent)
	_ok(sent.begins_with("Not applied, this once") and str(call.get("kind", "")) == "person"
		and _world.brick_count() == 0,
		"a statue stacked square is sent back, nothing built, with a person's entry: %s"
			% JSON.stringify(call))
	var handed: Dictionary = _laid(call)
	var report: Dictionary = _assistant._check(handed["model"], true)
	_ok(bool(report.get("ok", false)) and _unjoined(handed).is_empty(),
		"the entry it is handed builds as it is, joined (%s)" % report.get("summary", ""))
	var again: String = _text(await _assistant.use_tool("submit_design", statue))
	_ok(again.begins_with("Built"), "submitted again as it was, it is built: %s" % again.left(100))
	var third: String = _text(await _assistant.use_tool("submit_design", {"name": "Thinker",
		"description": "a seated statue of a man, taller", "floor": "none",
		"bricks": _stacked(3)}))
	_ok(third.begins_with("Built"), "...and a third, changed, still with no joint: built, not "
		+ "sent back twice: %s" % third.left(100))
	var with_call: String = _text(await _assistant.use_tool("submit_design", {"name": "Thinker",
		"description": "a seated statue of a man", "floor": "none", "patterns": [call]}))
	_ok(with_call.begins_with("Built"), "the entry submitted is built: %s" % with_call.left(100))

	_world.clear()
	_assistant.forget_built()
	_assistant.heard("A bright-blue balloon-dog sculpture stands on a white plinth.", true)
	var dog: String = _text(await _assistant.use_tool("submit_design", {"name": "Balloon dog",
		"description": "a balloon dog on a plinth", "floor": "none", "bricks": _stacked()}))
	var dog_call: Dictionary = _call_in(dog)
	_ok(dog.begins_with("Not applied, this once") and str(dog_call.get("kind", "")) == "animal",
		"a new design, a balloon dog stacked square, is sent back with an animal's entry: %s"
			% JSON.stringify(dog_call))
	var dog_laid: Dictionary = _laid(dog_call)
	report = _assistant._check(dog_laid["model"], true)
	_ok(bool(report.get("ok", false)), "...which builds as it is (%s)" % report.get("summary", ""))
	# On a plinth it keeps, the entry stands on the plinth, not in it.
	_world.clear()
	_assistant.forget_built()
	_assistant.heard("A bright-blue balloon-dog sculpture stands on a white plinth.", true)
	var on_plinth: String = _text(await _assistant.use_tool("submit_design", {"name":
		"Balloon dog", "description": "a balloon dog on a plinth", "floor": "none",
		"bricks": _plinth() + _dog()}))
	var plinth_call: Dictionary = _call_in(on_plinth)
	var kept: Dictionary = _laid(plinth_call, _plinth())
	report = _assistant._check(kept["model"], true)
	_ok(int((plinth_call.get("at", {}) as Dictionary).get("y", -1)) == 2
		and bool(report.get("ok", false)),
		"a dog on a white plinth is handed an entry on the plinth's top, which builds with the "
			+ "plinth kept (%s): %s" % [report.get("summary", ""), JSON.stringify(plinth_call)])

	for pair: Array in [["A red fire engine with a firefighter at the wheel.", "Fire engine"],
			["A Porsche 911 GT3 RS at minifigure scale.", "Porsche"],
			["A lighthouse on a rock.", "Lighthouse"]]:
		_world.clear()
		_assistant.forget_built()
		_assistant.heard(str(pair[0]), true)
		var built: String = _text(await _assistant.use_tool("submit_design", {"name": pair[1],
			"description": str(pair[0]).to_lower(), "floor": "none", "bricks": _stacked()}))
		_ok(built.begins_with("Built"), "%s: never sent back: %s" % [pair[1], built.left(80)])

	# Over the connector no brief is said: the model cleared starts a new
	# subject, and the statue built before is not what the lighthouse is.
	_world.clear()
	_assistant.forget_built()
	_assistant.heard("", true)
	await _assistant.use_tool("submit_design", statue)
	var stood: String = _text(await _assistant.use_tool("submit_design", statue))
	_world.clear()
	_assistant.forget_built()
	var tower: String = _text(await _assistant.use_tool("check_design", {"name": "Lighthouse",
		"description": "a lighthouse on a rock", "floor": "none", "bricks": _stacked()}))
	_ok(stood.begins_with("Built") and not tower.contains("on a joint"),
		"a statue built, the model cleared: a lighthouse is told nothing of joints")


## The figure entry a refusal hands over, read back as the session would copy it.
static func _call_in(said: String) -> Dictionary:
	for line: String in said.split("\n"):
		var one: String = line.strip_edges()
		if one.begins_with("{\"pattern\": \"figure\""):
			var parsed: Variant = JSON.parse_string(one)
			if parsed is Dictionary:
				return parsed
	return {}


## A man stacked square, as a session stacks one: legs, a body, two arms
## hanging under the shoulders, a head; [param courses] of body.
static func _stacked(courses: int = 2) -> Array:
	var out: Array = [
		{"part": "3004", "color": 308, "x": 1, "y": 0, "z": 0, "rot": 1, "name": "left leg"},
		{"part": "3004", "color": 308, "x": 2, "y": 0, "z": 0, "rot": 1, "name": "right leg"},
		{"part": "3003", "color": 308, "x": 1, "y": 3, "z": 0, "rot": 0},
		{"part": "3003", "color": 308, "x": 1, "y": 6, "z": 0, "rot": 0},
		{"part": "3001", "color": 308, "x": 0, "y": 9, "z": 0, "rot": 0, "name": "shoulders"},
		{"part": "3005", "color": 308, "x": 0, "y": 6, "z": 0, "rot": 0, "name": "left arm"},
		{"part": "3005", "color": 308, "x": 3, "y": 6, "z": 0, "rot": 0, "name": "right arm"},
		{"part": "3003", "color": 308, "x": 1, "y": 12, "z": 0, "rot": 0, "name": "head"},
	]
	for n: int in courses - 2:
		for brick: Dictionary in out:
			if int(brick["y"]) >= 6:
				brick["y"] = int(brick["y"]) + 3
		out.append({"part": "3003", "color": 308, "x": 1, "y": 6, "z": 0, "rot": 0})
	return out


## A white plinth two plates high, six studs square.
static func _plinth() -> Array:
	return [{"part": "3958", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3958", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 0}]


## A blue dog stacked square on it: four legs, a body, a head.
static func _dog() -> Array:
	return [
		{"part": "3005", "color": 1, "x": 1, "y": 2, "z": 2, "rot": 0},
		{"part": "3005", "color": 1, "x": 4, "y": 2, "z": 2, "rot": 0},
		{"part": "3005", "color": 1, "x": 1, "y": 2, "z": 3, "rot": 0},
		{"part": "3005", "color": 1, "x": 4, "y": 2, "z": 3, "rot": 0},
		{"part": "3001", "color": 1, "x": 1, "y": 5, "z": 2, "rot": 0, "name": "body"},
		{"part": "3003", "color": 1, "x": 0, "y": 8, "z": 2, "rot": 0, "name": "head"},
	]


## The model as LDraw lines, in LDraw's frame.
func _ldr_of(model: Assistant.Model, at: Array) -> String:
	var c := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var lines := PackedStringArray(["0 armature probe", "0 Name: probe.ldr"])
	for n: int in model.placements.size():
		var t: Transform3D = at[n]
		var r: Basis = c * t.basis * c
		var o: Vector3 = c * t.origin
		lines.append("1 %d %s %s %s %s %s %s %s %s %s %s %s %s %s.dat" % [
			model.placements[n].color, _f(o.x), _f(o.y), _f(o.z),
			_f(r.x.x), _f(r.y.x), _f(r.z.x), _f(r.x.y), _f(r.y.y), _f(r.z.y),
			_f(r.x.z), _f(r.y.z), _f(r.z.z), model.placements[n].part])
	return "\n".join(lines) + "\n"


static func _f(v: float) -> String:
	return "%.6f" % v


func _text(answer: Variant) -> String:
	if answer is String:
		return answer
	var out := PackedStringArray()
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
				out.append(str((block as Dictionary).get("text", "")))
	return "\n".join(out)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s" % what)
