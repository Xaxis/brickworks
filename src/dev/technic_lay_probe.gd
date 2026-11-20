## The app lays a LEGO® Technic set's face on the body that stands: on twelve
## bodies, each face its own call, every part it lays held as the build check
## holds it, nothing it lays overlapping, and one Undo taking a face off.
##
##   godot --headless --path . --script src/dev/technic_lay_probe.gd
##
## design26 told sessions a Technic set's parts and they dropped the panels
## the room around refused (docs/DESIGN_SCORES.md, design26), so the app lays
## them (TechnicLay), in the surface pass of a subject said to be Technic.
## Bodies: six first builds of the bench's tune-half Technic subjects, as
## submitted (src/dev/fixtures/technic_lay/), and six of their real sets with
## their panels taken off (vendor/omr/files), opened as File, Open opens one.
##
## Checks: the table TechnicLay takes its panels from has its roles, none of
## the bench's held-out sets read, and each part's role read as the table has
## it; "Technic" said of a subject is read as Technic and said of a part is
## not; how_real_sets_build_this says what the surface pass lays for a
## Technic subject and nothing more for another; each face laid is one edit,
## held and not overlapping, and one Undo puts the body back as it stood; a
## Technic subject's surface pass hands each face as its own finding, which
## a reject takes off alone, and another subject's hands none.
extends SceneTree

const FIRST_BUILDS := "res://src/dev/fixtures/technic_lay"
const SETS := "res://vendor/omr/files"
## The bench's tune half's Technic subjects (tools/bench/realset.py).
const BODIES: Array = ["42061-1", "9393-1", "42049-1", "8464-1", "42073-1", "42079-1"]
const SET_BODIES: Array = ["42061-1", "9393-1", "8464-1", "42049-1", "42079-1", "42006-1"]
## And some of either half's others, held out of the table with them.
const HELD := ["42061-1", "9393-1", "8464-1", "42107-1", "42049-1", "42079-1", "42006-1",
	"42073-1", "21030-1", "7636-1", "7685-1", "21051-1", "42081-1", "21023-1", "9469-1"]

var _failures: int = 0
var _assistant: Assistant
var _world: BrickWorld
var _library: PartLibrary
var _builder: Builder
var _store: ModelStore
## Over the twelve bodies: faces laid, panels and beams among them, bodies
## given a face.
var _faces: int = 0
var _panels: int = 0
var _beams: int = 0
var _bodies_laid: int = 0
var _first_laid: int = 0
## Bodies of the twelve given a face when this probe was written (design27).
const LAID_AT_LEAST := 10


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
	_table()
	_roles()
	_words()
	await _told()
	print("\n── each face laid, on twelve bodies ──")
	for name: String in BODIES:
		await _laid_on("first build %s" % name, _first_build.bind(name))
	for name: String in SET_BODIES:
		await _laid_on("set %s, its panels off" % name, _set_body.bind(name))
	# Every first build takes a face; a set's own body may offer no free place
	# a part is held clear in (8464-1's and 9393-1's did not, design27).
	_ok(_bodies_laid >= LAID_AT_LEAST and _first_laid == BODIES.size() and _panels > 0
		and _beams > 0, "%d of %d bodies given a Technic face (every first build): %d faces, "
		% [_bodies_laid, BODIES.size() + SET_BODIES.size()] + "%d panels, %d beams on edge"
		% [_faces, _panels, _beams])
	await _surface_pass()
	print("")
	print("technic lay: each face of twelve bodies laid in its own call, held, clear, and "
		+ "undone by one Undo; handed by the surface pass to a Technic subject alone"
		if _failures == 0 else "technic lay: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The table: its roles, each with its parts and the sets they came from, and
## none of the bench's held-out sets read, by number or by name.
func _table() -> void:
	print("── the table TechnicLay takes its panels from ──")
	var table: Dictionary = TechnicParts.table()
	var read: Array = table.get("read", [])
	_ok(TechnicParts.available() and read.size() >= 60, "the table is there: %d Technic sets read"
		% read.size())
	var roles: Dictionary = table.get("roles", {})
	_ok(roles.size() == TechnicParts.ROLES.size() and TechnicParts.ROLES.all(
		func(r: String) -> bool: return roles.has(r)), "its roles: %s"
		% ", ".join(PackedStringArray(roles.keys())))
	var panels: Array = TechnicLay.panel_parts()
	_ok(panels.size() >= 6 and panels.has("64782") and panels.has("62531"),
		"the panels a face may be given, the flat and curved panels real sets show: %s"
		% ", ".join(PackedStringArray(panels)))
	var cited := PackedStringArray()
	for name: String in TechnicParts.ROLES:
		for one: Variant in (roles.get(name, {}) as Dictionary).get("sets", []):
			cited.append(str((one as Dictionary)["number"]))
	for one: Variant in read:
		cited.append(str((one as Dictionary)["number"]))
	var subjects: Array = table.get("subjects", [])
	var numbers: Array = subjects.map(func(s: Dictionary) -> String: return str(s["number"]))
	_ok(subjects.size() >= 88 and HELD.all(func(id: String) -> bool: return numbers.has(id)),
		"it held out the bench's subjects: %d sets, the tune half's eight Technic among them"
		% subjects.size())
	var bases: Dictionary = {}
	for number: String in numbers:
		bases[number.get_slice("-", 0)] = number
	var met := PackedStringArray()
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
			"technic motorcycle", "A Technic-style heavy duty forklift", "Technic Tractor",
			"A 1990s-style studded Technic wheel loader", "a LEGO Technic crane truck"]:
		_ok(TechnicParts.of_technic(words), "\"%s\" is Technic" % words)
	for words: String in ["a bulldozer with black Technic link tracks round sprocket wheels",
			"a loader with Technic lift arms on a pivot axle", "a crane built of Technic bricks",
			"Tower Bridge", "a technical drawing desk"]:
		_ok(not TechnicParts.of_technic(words), "\"%s\" is not" % words)


## how_real_sets_build_this says what the surface pass lays for a Technic
## subject, and nothing of it for another.
func _told() -> void:
	print("\n── told before the first build ──")
	_assistant.heard("lighthouse", true)
	var plain: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "lighthouse"}))
	_ok(not plain.contains("LEGO® Technic set"), "a lighthouse is told nothing of it")
	_assistant.heard("technic forklift", true)
	var told: String = _text(await _assistant.use_tool("how_real_sets_build_this",
		{"subject": "technic forklift"}))
	_ok(told.contains("As a LEGO® Technic set: build the body of studded bricks")
		and told.contains("review_model {\"surface\": true}") and told.contains("one finding a side"),
		"a Technic forklift is told the surface pass lays its faces: %s"
		% _line_with(told, "As a LEGO® Technic set"))


func _first_build(name: String) -> void:
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		FIRST_BUILDS.path_join(name + ".json")))
	await _assistant.use_tool("submit_design", design)


## A real set, its panels, mudguards, figures and stickers taken off, its
## lowest part on the ground, opened as File, Open opens one.
func _set_body(name: String) -> void:
	var model: LdrModel = LdrModel.load_file(SETS.path_join(name + ".mpd"))
	if model == null:
		return
	var lowest: float = INF
	var kept: Array = []
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		var info: PartLibrary.PartInfo = _library.parts.get(placement.part_id)
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part_id)
		if info == null or mesh == null:
			continue
		var lower: String = info.name.to_lower()
		if TechnicParts.role_of(info.name) in ["curved_panel", "flat_panel", "mudguard"] \
				or lower.begins_with("minifig") or lower.contains("sticker"):
			continue
		kept.append(placement)
		lowest = minf(lowest, (placement.transform * mesh.bounds).abs().position.y)
	var lift := Transform3D(Basis.IDENTITY, Vector3(0, -lowest, 0))
	var lines := PackedStringArray(["0 %s, its panels off" % name])
	for placement: LdrModel.Placement in kept:
		var nums := PackedStringArray()
		for n: float in LdrModel.from_transform(lift * placement.transform):
			nums.append("%.4f" % (snappedf(n, 0.0001) + 0.0))
		lines.append("1 %d %s %s.dat" % [placement.color_code, " ".join(nums), placement.part_id])
	_store.open_text("\n".join(lines) + "\n", name + ".ldr")
	# What the app's check faults in the set as it stands (joins it reads
	# otherwise than LEGO® did, a section a panel held) comes off too: an
	# edit is judged on the whole model, so a body the check refuses would
	# refuse every face for what the set already was.
	for round: int in 6:
		var now: Assistant.Model = _assistant._model_from_world()
		var report: Dictionary = _assistant._check(now, true)
		if bool(report.get("ok", false)):
			return
		var drop: Dictionary = {}
		for index: Variant in (report.get("floating", []) as Array) + (report.get("unheld", [])
				as Array) + (report.get("overlapping", {}) as Dictionary).keys():
			drop[now.placements[int(index)].id] = true
		var said: String = str(report.get("feedback", ""))
		for m: RegExMatch in RegEx.create_from_string("brick (\\d+) \\(").search_all(said):
			if int(m.get_string(1)) < now.placements.size():
				drop[now.placements[int(m.get_string(1))].id] = true
		for m: RegExMatch in RegEx.create_from_string("section '([^']+)'").search_all(said):
			for placement: Assistant.Placement in now.placements:
				if placement.section == m.get_string(1):
					drop[placement.id] = true
		if drop.is_empty():
			return
		for id: int in drop:
			_builder.remove_brick_id(id)


## Each face of one body: laid by its own edit, held, clear of what stands,
## one Undo putting the body back as it stood; then laid again for the next.
func _laid_on(label: String, build: Callable) -> void:
	# A set opened as a file is the person's, which clear_model leaves:
	# the world and its lattice emptied, so the next body stands alone.
	await _assistant.use_tool("clear_model", {})
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	await build.call()
	_builder.forget_history()
	var standing: int = _world.brick_count()
	if standing < 20:
		_ok(false, "%s: built (%d parts)" % [label, standing])
		return
	var floating_before: int = _floating().size()
	var faces := PackedStringArray()
	for facing: String in TechnicLay.facings():
		var lay: TechnicLay.Lay = await TechnicLay.new(_assistant).lay_for(facing)
		if lay == null:
			continue
		var before: Array = _signature()
		var had: Dictionary = {}
		for brick: BrickWorld.Brick in _world.bricks():
			had[brick.id] = true
		var input := {"add": lay.add, "remove": lay.remove}
		var answer: String = _text(await _assistant._run_tool({"name": "edit_model",
			"input": input}))
		if not answer.begins_with("Done."):
			_ok(false, "%s %s: laid by its own edit: %s" % [label, facing, answer.left(240)])
			continue
		var laid: Array[int] = []
		for brick: BrickWorld.Brick in _world.bricks():
			if not had.has(brick.id):
				laid.append(brick.id)
		var floating: Dictionary = _floating()
		var adrift: Array = laid.filter(func(id: int) -> bool: return floating.has(id))
		var clashes: Array = _overlaps(laid)
		var undone: bool = _builder.undo()
		var back: bool = undone and _signature() == before
		_ok(adrift.is_empty() and clashes.is_empty() and floating.size() <= floating_before
			and back, "%s %s: %d parts in one edit (%s, %s, %d pins, %d course%s laid again); "
			% [label, facing, laid.size(), "panels " + ", ".join(lay.panels) if not lay.panels.is_empty()
			else "no panel", "beams " + ", ".join(lay.beams) if not lay.beams.is_empty() else "no beam",
			lay.pins, lay.courses, "" if lay.courses == 1 else "s"]
			+ "held: %s; overlapping: %s; one Undo puts it back: %s"
			% ["all" if adrift.is_empty() else "%d adrift" % adrift.size(),
			"none" if clashes.is_empty() else str(clashes.slice(0, 3)), "yes" if back else "NO"])
		# Laid again, so the next face is laid beside it as the pass lays them.
		await _assistant._run_tool({"name": "edit_model", "input": input})
		faces.append(facing)
		_faces += 1
		_panels += lay.panels.size()
		_beams += lay.beams.size()
	if not faces.is_empty():
		_bodies_laid += 1
		if label.begins_with("first build"):
			_first_laid += 1
	print("    %s: %d parts standing, faces laid %s" % [label, standing,
		", ".join(faces) if not faces.is_empty() else "none"])


## A Technic subject's surface pass hands each face as its own finding, laid
## at once; rejecting one takes off only its parts and puts its course back;
## another subject's pass hands none.
func _surface_pass() -> void:
	print("\n── the surface pass ──")
	await _assistant.use_tool("clear_model", {})
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_assistant.heard("technic forklift", true)
	await _first_build("42079-1")
	var before: Array = _signature()
	var answer: String = _text(await _assistant.surface_review())
	var technic: Array = _assistant.surface_pass().findings.filter(
		func(one: SurfacePass.Finding) -> bool: return one.of == "technic")
	var facings: Dictionary = {}
	for one: SurfacePass.Finding in technic:
		facings[one.said.get_slice(" face", 0)] = true
	_ok(technic.size() >= 2 and facings.size() == technic.size()
		and technic.all(func(one: SurfacePass.Finding) -> bool: return not one.ids.is_empty()),
		"a Technic forklift's pass hands %d faces, each its own finding, laid: %s"
		% [technic.size(), _line_with(answer, "as a Technic set's")])
	if technic.is_empty():
		return
	var first: SurfacePass.Finding = technic[0]
	var others: Array[int] = []
	for one: SurfacePass.Finding in technic.slice(1):
		others.append_array(one.ids)
	var said: String = _text(await _assistant.use_tool("settle_surface", {"finding": first.key,
		"verdict": "reject", "reason": "probe: the face taken off alone"}))
	var gone: bool = first.ids.all(func(id: int) -> bool: return _world.get_brick(id) == null)
	var kept: bool = others.all(func(id: int) -> bool: return _world.get_brick(id) != null)
	var restored: bool = first.remove.all(func(id: int) -> bool:
		return _world.get_brick(id) != null) or first.remove.is_empty() or said.contains("put back")
	_ok(gone and kept and restored, "rejecting %s takes off its %d parts alone and puts its "
		% [first.key, first.ids.size()] + "course back: %s" % said.left(160))
	await _assistant.use_tool("clear_model", {})
	_assistant.heard("forklift truck", true)
	_assistant._named_as = ""
	_assistant._brief = ""
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		FIRST_BUILDS.path_join("42079-1.json")))
	design["name"] = "Forklift"
	design["description"] = "A heavy duty forklift truck"
	design.erase("brief")
	await _assistant.use_tool("submit_design", design)
	_assistant.heard("forklift truck", true)
	await _assistant.surface_review()
	var none: Array = _assistant.surface_pass().findings.filter(
		func(one: SurfacePass.Finding) -> bool: return one.of == "technic")
	_ok(none.is_empty() and not TechnicLay.for_subject(_assistant),
		"a forklift not said to be Technic is handed no Technic face (%d)" % none.size())
	if before.is_empty():
		_ok(false, "the forklift was built")


## Parts the build check calls floating, by brick id, as the realset audit
## reads a model (only the ground holds).
func _floating() -> Dictionary:
	var model: Assistant.Model = _assistant._model_from_world()
	_assistant._ground_only = true
	var report: Dictionary = _assistant._check(model, true)
	_assistant._ground_only = false
	var out: Dictionary = {}
	for index: Variant in report.get("floating", []):
		out[model.placements[int(index)].id] = true
	return out


## Pairs the check would refuse as overlapping with one of [param laid] in them.
func _overlaps(laid: Array[int]) -> Array:
	var model: Assistant.Model = _assistant._model_from_world()
	var report: Dictionary = _assistant._check(model, true)
	var pairs: Array = (report.get("standing_overlaps", []) as Array).duplicate()
	var overlapping: Dictionary = report.get("overlapping", {})
	for index: Variant in overlapping:
		pairs.append([int(index), int(overlapping[index])])
	var out: Array = []
	for pair: Array in pairs:
		var a: int = model.placements[int(pair[0])].id
		var b: int = model.placements[int(pair[1])].id
		if laid.has(a) or laid.has(b):
			out.append([a, b])
	return out


func _signature() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.id, brick.part_id, brick.color_code, brick.transform])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return out


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(220)
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
