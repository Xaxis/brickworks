## The surface pass's colour findings (ColourFaces, SurfacePass "colour"): a
## side or the top one connected colour covers more than half of gets a line
## of the darker tone recoloured through it, and the design settles it. On
## fixtures with known answers:
##
##   a block banded in two colours, a course of each, reads as no side face,
##   and under forty parts nothing is read;
##   a yellow block of 42 bricks reads as five faces, its four sides and its
##   top; the surface pass, after laying its own findings (it curves the top's
##   edges, raises it in tiles, and skins the long flanks), lines the sides in
##   Black, in parts the block was built of and none it just laid, since
##   settling those lays them again; the top, all its own parts, is not
##   lined; each face lined is then broken, or a tenth of its view smaller;
##   it holds as one;
##
## then that settling works: accept with "recolor" makes a line the design's
## colour; "all" with a recolour meant for tiles accepts the other lines as
## laid; the record counts the lines kept; reviewed again, the top, its tiles
## settled, is lined; a reject needs a reason and puts the face's colour back;
## a third review does not line it again; and a small model gets no colour
## finding.
##
##   godot --headless --path . --script src/dev/colour_faces_probe.gd
##
## Against the 44 real sets of proof (d5base) the judge held "mostly one flat
## expanse of a colour, few accents" against 41 of our 59 colour losses, and
## designs with a face like this won 6 of 42 colour verdicts.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


var _failures: int = 0
var assistant: Offline
var world: BrickWorld
var builder: Builder
var library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	world = BrickWorld.new()
	world.library = library
	root.add_child(world)
	builder = Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	assistant = Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	print("\nthe reading: a block banded a course of each colour, or small, is no face")
	var banded: Callable = func(course: int) -> int: return 14 if course % 2 == 0 else 0
	await _build("banded block", _block(banded))
	var reading: Dictionary = ColourFaces.read(_bricks(), library)
	var sides: int = 0
	for face: ColourFaces.Face in reading["faces"]:
		sides += 0 if face.view == "top" else 1
	_ok(sides == 0, "banded: no side a face, its yellow top course aside (%s)" % _views(reading))
	_ok((ColourFaces.read(_bricks().slice(0, 30), library)["faces"] as Array).is_empty(),
		"30 of its parts: nothing read")

	print("\na yellow block, one colour all round, is five flat faces")
	await _build("block", _block(func(_course: int) -> int: return 14))
	var built: Dictionary = {}
	for brick: BrickWorld.Brick in _bricks():
		built[brick.id] = true
	reading = ColourFaces.read(_bricks(), library)
	_ok((reading["faces"] as Array).size() == 5, "every side and the top: %s" % _views(reading))
	_ok(is_equal_approx(float((reading["shares"] as Dictionary).get(14, 0.0)), 1.0),
		"...all of it Yellow")

	print("\nthe surface pass lines the sides, after the rest it lays and never in it")
	var said: String = _text_of(await assistant.surface_review())
	print("    " + said.substr(maxi(0, said.find("Colour, as")), 1800).replace("\n", "\n    "))
	var lined: Array[SurfacePass.Finding] = _colour_findings()
	var side: SurfacePass.Finding = null
	for one: SurfacePass.Finding in lined:
		if side == null and not one.said.begins_with("from above"):
			side = one
	_ok(side != null, "a side lined, %d in all" % lined.size())
	_ok(said.contains("Colour, as the four sides and the top show it: Yellow")
		and said.contains("%s colour:" % (lined[0].key if not lined.is_empty() else "C1")),
		"the answer reads the colours and names each line")
	var top_lined: bool = false
	for one: SurfacePass.Finding in lined:
		top_lined = top_lined or _view_of(one) == "top"
	_ok(not top_lined, "the top, all the pass's own tiles and slopes, is not lined")
	var black: bool = not lined.is_empty()
	var ours: bool = not lined.is_empty()
	for one: SurfacePass.Finding in lined:
		black = black and _all_colour(one, 0)
		for id: int in one.ids:
			ours = ours and built.has(id)
	_ok(black, "each line is Black, Yellow's darker tone: %s" % (side.laid if side != null
		else "none"))
	_ok(ours, "nothing added for colour: every line is parts the block was built of")
	var after: Dictionary = ColourFaces.read(_bricks(), library)
	var dented: bool = not lined.is_empty()
	for one: SurfacePass.Finding in lined:
		for face: ColourFaces.Face in after["faces"]:
			if face.view == _view_of(one) and face.share > 1.0 - SurfacePass.LEAST_DENT + 0.001:
				dented = false
	_ok(dented, "each face lined is broken, or a tenth of its view smaller: %s" % _views(after))
	var report: Dictionary = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]), "it holds as one: %s" % report["summary"])

	print("\nsettling: recolour, \"all\", then the top lined, rejected and not lined again")
	var red: String = await assistant.use_tool("settle_surface", {"finding": side.key
		if side != null else "C1", "verdict": "accept", "recolor": {"0": 4}})
	print("    " + red.replace("\n", "\n    "))
	_ok(side != null and side.verdict == "adjusted" and _all_colour(side, 4),
		"accepted with \"recolor\": {\"0\": 4}: the side's line is red")
	var rest: Array[SurfacePass.Finding] = []
	for one: SurfacePass.Finding in lined:
		if not one.settled():
			rest.append(one)
	await assistant.use_tool("settle_surface", {"finding": "all", "verdict": "accept",
		"recolor": {"14": 1}})
	var kept_black: bool = true
	for one: SurfacePass.Finding in rest:
		kept_black = kept_black and one.verdict == "accepted" and _all_colour(one, 0)
	_ok(kept_black, "\"all\" with a recolour for the tiles accepts the other %d line%s as laid"
		% [rest.size(), "" if rest.size() == 1 else "s"])
	_ok(assistant.surface_pass().record().contains("%d one-colour face%s lined" % [
		lined.size(), "" if lined.size() == 1 else "s"]),
		"the record counts the lines kept: %s" % assistant.surface_pass().record())
	said = _text_of(await assistant.surface_review())
	var top: SurfacePass.Finding = null
	for one: SurfacePass.Finding in _colour_findings():
		if not one.settled() and _view_of(one) == "top":
			top = one
	_ok(top != null and _all_colour(top, 272), "reviewed again, the top, its tiles settled "
		+ "Blue, is lined in Dark Blue: %s" % (top.laid if top != null else said.substr(0, 300)))
	var short: String = await assistant.use_tool("settle_surface", {"finding": top.key
		if top != null else "C9", "verdict": "reject", "reason": "no"})
	_ok(short.begins_with("Say why"), "a reject without a reason is asked for one")
	var back: String = await assistant.use_tool("settle_surface", {"finding": top.key
		if top != null else "C9", "verdict": "reject",
		"reason": "this deck gets a hatch and vents of its own"})
	print("    " + back.replace("\n", "\n    "))
	_ok(top != null and top.verdict == "rejected" and _all_colour(top, 1),
		"rejected: the top's line is Blue again")
	await assistant.surface_review()
	var relined: bool = false
	for one: SurfacePass.Finding in _colour_findings():
		if not one.settled() and _view_of(one) == "top":
			relined = true
	_ok(not relined, "a third review does not line the rejected top again")

	print("\na small model gets no colour finding")
	var small: Array = []
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 2, 4]:
			small.append({"part": "3003", "color": 15, "x": x, "y": 0, "z": z, "rot": 0})
	await _build("small", small)
	await assistant.surface_review()
	_ok(_colour_findings().is_empty(), "%d parts: no colour finding" % _bricks().size())

	print("")
	if _failures == 0:
		print("OK colour_faces_probe")
	else:
		print("FAILED colour_faces_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


# -- fixtures ------------------------------------------------------------------


## A block 12 studs by 4, seven courses of 2 x 4 bricks laid in bond: the even
## courses along x, the odd across, each course in [param colour_of] its number.
func _block(colour_of: Callable) -> Array:
	var out: Array = []
	for course: int in 7:
		var colour: int = int(colour_of.call(course))
		if course % 2 == 0:
			for x: int in [0, 4, 8]:
				for z: int in [0, 2]:
					out.append({"part": "3001", "color": colour, "x": x, "y": course * 3, "z": z,
						"rot": 0})
		else:
			for x: int in [0, 2, 4, 6, 8, 10]:
				out.append({"part": "3001", "color": colour, "x": x, "y": course * 3, "z": 0,
					"rot": 1})
	return out


func _build(name: String, bricks: Array) -> void:
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	var built: Variant = await assistant.use_tool("submit_design", {"name": name,
		"description": "a fixture", "bricks": bricks, "features": []})
	if not str(built).begins_with("Built"):
		print("    could not build the %s: %s" % [name, str(built).substr(0, 300)])


func _bricks() -> Array[BrickWorld.Brick]:
	return assistant._bricks_inside({})


func _views(reading: Dictionary) -> String:
	var views := PackedStringArray()
	for face: ColourFaces.Face in reading["faces"]:
		views.append("%s %d%%" % [face.view, roundi(100.0 * face.share)])
	return ", ".join(views) if not views.is_empty() else "none"


## The view a colour finding was read from: "top", "+x" and so on.
func _view_of(one: SurfacePass.Finding) -> String:
	return one.of


func _colour_findings() -> Array[SurfacePass.Finding]:
	var out: Array[SurfacePass.Finding] = []
	for one: SurfacePass.Finding in assistant.surface_pass().findings:
		if one.kind == "colour":
			out.append(one)
	return out


func _all_colour(one: SurfacePass.Finding, colour: int) -> bool:
	if one == null or one.ids.is_empty():
		return false
	for id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick == null or brick.color_code != colour:
			return false
	return true


## All the words in an answer, wherever they sit in it.
func _text_of(message: Variant) -> String:
	if message is String:
		return message
	var said := PackedStringArray()
	if message is Array:
		for block: Variant in message:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				said.append(str((block as Dictionary).get("text", "")))
	return "\n".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
