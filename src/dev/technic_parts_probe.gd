## A LEGO® Technic subject's first build is told what a Technic set shows on
## its surface, read from real sets, and lays it on the studded body it keeps.
##
##   godot --headless --path . --script src/dev/technic_parts_probe.gd
##
## The nine Technic subjects of the bench's 44 lost every verdict in both of
## design24's arms, on parts; October's studless levers lost likeness; and
## design25's parts, laid at the close look, were kept in 71 spots
## (docs/DESIGN_SCORES.md). design26 reads which parts make a Technic set's
## seen surface and how each is held on a studded body (tools/technic_parts.py
## -> assets/knowledge/technic_parts.json.gz, read by TechnicParts), and tells
## a Technic subject's first build: in how_real_sets_build_this's answer, in
## the connector's first answer with the method, and in a first submission
## showing none of it, sent back once.
##
## Checks: the table has its ten roles, each with its parts, its holds and the
## sets it came from, and none of the bench's held-out sets among them, by
## number or by name; the app reads each listed part's role as the table
## does; "Technic" said of a subject is read as Technic, said of a part is
## not; a Technic subject is told the surface once, another is told what it
## was; a Technic first submission with no panel is sent back once, then built
## as it is; one with panels and frame lines is built at once, and so is any
## other subject's; the hold the answer writes out builds; and the method's
## words are METHOD for any other subject.
extends SceneTree

## The bench's tune half's Technic subjects (tools/bench/realset.py), and
## some of either half's others.
const HELD := ["42061-1", "9393-1", "8464-1", "42107-1", "42049-1", "42079-1", "42006-1",
	"42073-1", "21030-1", "7636-1", "7685-1", "21051-1", "42081-1", "21023-1", "9469-1"]

var _failures: int = 0
var _assistant: Assistant
var _world: BrickWorld
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
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
	_table()
	_roles()
	_words()
	await _told()
	await _sent_back()
	_method()
	print("")
	print("technic parts: the table's ten roles from real sets, none held out, told to a "
		+ "Technic subject's first build and laid there" if _failures == 0
		else "technic parts: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The table: ten roles, each with its parts, its holds and the sets it came
## from, and none of the bench's held-out sets read.
func _table() -> void:
	print("── the table, read from real sets ──")
	var table: Dictionary = TechnicParts.table()
	var read: Array = table.get("read", [])
	_ok(TechnicParts.available() and read.size() >= 60, "the table is there: %d Technic sets read"
		% read.size())
	var roles: Dictionary = table.get("roles", {})
	_ok(roles.size() == 10 and TechnicParts.ROLES.all(func(r: String) -> bool:
		return roles.has(r)), "ten roles: %s" % ", ".join(PackedStringArray(roles.keys())))
	var cited := PackedStringArray()
	for name: String in TechnicParts.ROLES:
		var role: Dictionary = roles.get(name, {})
		var parts: Array = role.get("parts", [])
		var holds: Array = role.get("holds", [])
		var sets: Array = role.get("sets", [])
		var first_hold: Dictionary = holds[0] if not holds.is_empty() else {}
		_ok(parts.size() >= 3 and not holds.is_empty() and sets.size() >= 3
			and not str(first_hold.get("said", "")).is_empty()
			and not (first_hold.get("examples", []) as Array).is_empty(),
			"%s: %s of what shows (median); %d parts, %s; held mostly %s (%d parts in %d sets); from %s"
			% [name, TechnicParts._percent(float(role.get("median", 0.0))), parts.size(),
			", ".join(PackedStringArray(parts.slice(0, 2).map(func(p: Dictionary) -> String:
				return "%s %s" % [p["part"], p["name"]]))), first_hold.get("way", "?"),
			int(first_hold.get("parts", 0)), int(first_hold.get("sets", 0)),
			", ".join(PackedStringArray(sets.slice(0, 2).map(func(s: Dictionary) -> String:
				return "%s %s" % [s["number"], s["name"]])))])
		for one: Variant in sets:
			cited.append(str((one as Dictionary)["number"]))
		for way: Variant in holds:
			for number: Variant in (way as Dictionary).get("examples", []):
				cited.append(str(number))
	var subjects: Array = table.get("subjects", [])
	var numbers: Array = subjects.map(func(s: Dictionary) -> String: return str(s["number"]))
	_ok(subjects.size() >= 88 and HELD.all(func(id: String) -> bool: return numbers.has(id)),
		"it held out the bench's subjects: %d sets, the tune half's eight Technic among them"
		% subjects.size())
	# By number, every set it names; by name, as DesignMemory.holds reads one,
	# every set it read.
	var met := PackedStringArray()
	var bases: Dictionary = {}
	for number: String in numbers:
		bases[number.get_slice("-", 0)] = number
	for one: Variant in read:
		cited.append(str((one as Dictionary)["number"]))
	for number: String in cited:
		if bases.has(number.get_slice("-", 0)):
			met.append(number)
	for one: Variant in read:
		var said: PackedStringArray = RealSnippets.words(str((one as Dictionary)["name"]))
		for subject: Variant in subjects:
			var words: PackedStringArray = RealSnippets.words(str((subject as Dictionary)["name"]))
			if not said.is_empty() and not words.is_empty() and (Array(said).all(
					func(w: String) -> bool: return words.has(w)) or Array(words).all(
					func(w: String) -> bool: return said.has(w))):
				met.append("%s (%s)" % [(one as Dictionary)["number"], (subject as Dictionary)["name"]])
	_ok(met.is_empty(), "...and read none of them, by number or by name, in %d sets named: %s"
		% [cited.size(), ", ".join(met) if not met.is_empty() else "none"])


## The app reads each listed part's role as the table's maker did.
func _roles() -> void:
	print("\n── each listed part's role, read by the app ──")
	var wrong := PackedStringArray()
	var count: int = 0
	for name: String in TechnicParts.ROLES:
		for one: Variant in (TechnicParts.table()["roles"][name] as Dictionary).get("parts", []):
			var info: PartLibrary.PartInfo = _library.parts.get(str((one as Dictionary)["part"]))
			count += 1
			if info == null or TechnicParts.role_of(info.name) != name:
				wrong.append("%s %s" % [(one as Dictionary)["part"], name])
	_ok(count >= 60 and wrong.is_empty(), "%d listed parts, each the table's role: %s"
		% [count, ", ".join(wrong) if not wrong.is_empty() else "all"])


## "Technic" said of a subject is read as Technic; said of a part it is not.
func _words() -> void:
	print("\n── a subject said to be Technic ──")
	for words: String in ["Ducati Panigale V4 R, in the style of LEGO® Technic sets",
			"technic motorcycle", "A Technic-style heavy duty forklift", "Technic Tractor"]:
		_ok(TechnicParts.of_technic(words), "\"%s\" is Technic" % words)
	for words: String in ["a bulldozer with black Technic link tracks round sprocket wheels",
			"a loader with Technic lift arms on a pivot axle", "a crane built of Technic bricks",
			"Tower Bridge", "a technical drawing desk"]:
		_ok(not TechnicParts.of_technic(words), "\"%s\" is not" % words)


func _begin(subject: String) -> void:
	_assistant.heard(subject, true)


## A Technic subject is told the surface once, with how_real_sets_build_this;
## another subject's answer has none of it.
func _told() -> void:
	print("\n── told before the first build ──")
	_begin("lighthouse")
	var plain: Array = await _assistant.use_tool("how_real_sets_build_this", {"subject": "lighthouse"})
	_ok(not _text(plain).contains("TECHNIC SET'S SURFACE"), "a lighthouse is told no Technic surface")
	_begin("technic motorcycle")
	var told: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "technic motorcycle"}))
	_ok(told.contains("A LEGO® TECHNIC SET'S SURFACE") and told.contains("11946")
		and told.contains("3701") and told.contains("flank1.socket[0]"),
		"a Technic motorcycle is told it: %s" % _line_with(told, "curved panels"))
	_ok(told.contains("Technic brick with holes laid in the body's wall course"),
		"...with how each is held: %s" % _line_with(told, "Technic brick with holes laid"))
	var again: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "motorcycle fairing"}))
	_ok(not again.contains("TECHNIC SET'S SURFACE"), "...once a subject: asked again, it is not")


func _design(name: String, description: String, bricks: Array) -> Dictionary:
	return {"name": name, "description": description, "assemblies": [{"name": "body"}],
		"features": [{"name": "body"}], "bricks": bricks}


## A studded body: a 6 x 6 plate, three courses of bricks.
func _body() -> Array:
	var bricks: Array = [{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0}]
	for course: int in 3:
		for z: int in [0, 2, 4]:
			bricks.append({"part": "2456", "color": 4, "x": 0,
				"y": 1 + 3 * course, "z": z})
	return bricks


## The body with the hold the answer writes out: a Technic brick in the wall
## course, a pin in its hole, a fairing on the pin's other end; and a beam
## laid flat on studs, two a side.
func _technic_body() -> Array:
	var bricks: Array = [{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 0, "x": 0, "y": 1, "z": 0},
		{"part": "3001", "color": 0, "x": 0, "y": 1, "z": 2},
		{"part": "3010", "color": 0, "x": 0, "y": 1, "z": 4},
		{"part": "3701", "color": 0, "name": "side", "x": 0, "y": 1, "z": 5},
		{"part": "3701", "color": 0, "name": "flank1", "x": 0, "y": 4, "z": 5},
		{"part": "3010", "color": 0, "x": 0, "y": 4, "z": 4},
		{"part": "3001", "color": 0, "x": 0, "y": 4, "z": 0},
		{"part": "3001", "color": 0, "x": 0, "y": 4, "z": 2},
		{"part": "2780", "color": 0, "name": "p1", "attach": {"to": "side.socket[0]",
			"by": "pin[0]", "flip": true}},
		{"part": "32524", "color": 14, "attach": {"to": "p1.pin[1]", "by": "socket[6]",
			"align": ["+z", "+x"]}},
		{"part": "2780", "color": 0, "name": "pin1", "attach": {"to": "flank1.socket[0]",
			"by": "pin[0]", "flip": true}},
		{"part": "11946", "color": 15, "attach": {"to": "pin1.pin[1]", "by": "socket[0]",
			"flip": true, "align": ["-z", "+x"]}}]
	for x: int in [0, 1, 3]:
		bricks.append({"part": "32316", "color": 0, "x": x, "y": 7, "z": 0})
	return bricks


## A Technic first submission with no panel is sent back once, then built as
## it is; one with panels and frame lines is built at once; another subject's
## is built.
func _sent_back() -> void:
	print("\n── the first submission ──")
	_begin("technic tractor")
	var bare: Dictionary = _design("Technic Tractor", "A farm tractor in the style of LEGO® "
		+ "Technic sets, a studded body", _body())
	var standing: int = _world.brick_count()
	var first: String = _text(await _assistant.use_tool("submit_design", bare))
	_ok(first.begins_with("Not applied, this once: it is in the style of LEGO® Technic sets")
		and first.contains("no panel or fairing") and first.contains("Keep the body")
		and first.contains("flank1.socket[0]") and _world.brick_count() == standing,
		"a Technic tractor with no panel is sent back, nothing built: %s" % first.left(150))
	var second: String = _text(await _assistant.use_tool("submit_design", bare))
	_ok(second.begins_with("Built."), "...submitted again as it is, it is built: %s"
		% second.left(60))

	_begin("technic forklift")
	var dressed: Dictionary = _design("Technic Forklift", "A Technic-style forklift, panels "
		+ "pinned to its flanks", _technic_body())
	var laid: String = _text(await _assistant.use_tool("submit_design", dressed))
	_ok(laid.begins_with("Built.") and not laid.contains("overlap"),
		"one with a fairing pinned on a Technic brick and beams on studs, as the answer writes "
		+ "it, is built at once: %s" % laid.left(300))
	var counts: Dictionary = TechnicParts.roles_in(dressed["bricks"].map(func(b: Dictionary) -> String:
		return str(b["part"])), _library)
	_ok(TechnicParts.shows_it(counts), "...and shows a Technic set's surface: %s" % str(counts))

	_begin("lighthouse")
	var other: String = _text(await _assistant.use_tool("submit_design", _design("Lighthouse",
		"A red and white lighthouse", _body())))
	_ok(other.begins_with("Built."), "a lighthouse with no panel is built: %s" % other.left(60))


## The method's words: METHOD for another subject, and for a Technic one with
## what its first build lays.
func _method() -> void:
	print("\n── the method, said on the connector ──")
	_begin("lighthouse")
	_ok(_assistant.method_for_subject() == Assistant.METHOD, "a lighthouse is told METHOD, "
		+ "byte for byte (%d characters)" % Assistant.METHOD.length())
	_begin("Technic-style excavator")
	var said: String = _assistant.method_for_subject()
	_ok(said.begins_with(Assistant.METHOD) and said.ends_with(TechnicParts.METHOD_SAID),
		"a Technic excavator is told METHOD and then: %s" % TechnicParts.METHOD_SAID.left(110))


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(200)
	return "(no line with \"%s\")" % word


func _text(answer: Variant) -> String:
	if answer is Array:
		var said := PackedStringArray()
		for block: Variant in answer:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				said.append(str((block as Dictionary)["text"]))
		return "\n".join(said)
	return str(answer)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
