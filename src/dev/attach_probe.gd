## Are the coordinates this thing hands out ones that work?
##
##   godot --headless --path . --script src/dev/attach_probe.gd
##
## attachment_points exists so that nobody has to work out that a stud
## on the side of an 87087 sits one and three quarter plates up, and so
## that a part clutching it starts at half a plate. A tool that does
## that arithmetic wrong is worse than no tool: the answer looks
## authoritative and the design comes back refused with no clue why.
##
## So every answer is taken at its word here — a 1x1 plate is built at
## exactly the coordinates given, on exactly the face given — and the
## design has to come back buildable, which it only does if the plate
## really is held by that stud.
extends SceneTree

var _failures: int = 0
var _checked: int = 0


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
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	# Parts worth asking about: a plain brick, a plate, the two that
	# exist to give you a stud pointing sideways, and a bracket.
	for host: String in ["3005", "3001", "3024", "87087", "4070",
			"99207", "44728", "3062b", "3070b"]:
		if not library.parts.has(host):
			print("  skip  %s is not in the catalogue" % host)
			continue
		for face: String in ["up", "+z", "-x"]:
			_try(assistant, library, host, face)

	# The builder's own lattice keeps the index that says where a brick
	# would come to rest.
	#
	# The scratch lattices a design is checked against turn it off — it
	# is a third of what checking costs and nothing in the check reads
	# it. The live one must not: without it every preview lands on the
	# ground wherever you point, which looks like a placement bug a long
	# way from the lattice.
	print("")
	print("  the live lattice keeps what the preview needs")
	_look("the builder's lattice keeps its column index",
		builder.lattice.keeps_columns)

	# And the shape of a part that is not a box.
	#
	# A wedge plate's studs sit on its square half, so the stud list —
	# the only thing this tool used to print — describes the half that
	# is not the point of the part. Which way the diagonal runs could
	# not be asked at all: not from the studs, and from a render only if
	# you already knew which way the camera pointed. A saucer rim built
	# on a guess is the same wedge put on backwards four times.
	print("")
	print("  the shape of a part that is not a box")
	var right: String = assistant._attachment_points(
		{"part": "41769b", "x": 0, "y": 0, "z": 0, "rot": 0})
	var left: String = assistant._attachment_points(
		{"part": "41770b", "x": 0, "y": 0, "z": 0, "rot": 0})
	_look("a wedge plate is drawn as a footprint",
		right.contains("footprint from above"))
	# Tenths, and they have to run downhill: a column of "some of it"
	# says the stud is cut without saying which way.
	_look("...and the taper is readable, thick end first",
		right.contains("8#") and right.contains("1#"))
	_look("...and the left-handed one is its mirror",
		left.contains("#8") and left.contains("#1"))
	# Silent about a part that fills its box, or it is noise.
	for box: String in ["3001", "3024", "3068b"]:
		_look("%s fills its box, and is not drawn at all" % box,
			not assistant._attachment_points(
				{"part": box, "x": 0, "y": 0, "z": 0, "rot": 0})
				.contains("Its "))

	# A slope is flat in plan and shaped in its side, so the plan says
	# nothing and the side says everything. Which way it falls is the
	# same question as which way a wedge tapers.
	var slope: String = assistant._attachment_points(
		{"part": "3037", "x": 0, "y": 0, "z": 0, "rot": 0})
	_look("a slope is drawn from the side instead",
		slope.contains("Its side"))
	_look("...and the fall is readable, solid at the bottom",
		slope.contains("##") and slope.contains("#2"))
	var arch: String = assistant._attachment_points(
		{"part": "3659", "x": 0, "y": 0, "z": 0, "rot": 0})
	_look("an arch shows the hole under it",
		arch.contains("Its side") and arch.contains("#11#"))

	print("")
	if _failures == 0:
		print("%d attachment points, every one of them real" % _checked)
	else:
		print("%d FAILURE(S) of %d" % [_failures, _checked])
	quit(1 if _failures else 0)


## A plain yes-or-no about what a tool said, counted with the rest.
func _look(what: String, ok: bool) -> void:
	_checked += 1
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _try(assistant: Assistant, library: PartLibrary, host: String,
		face: String) -> void:
	# The host hangs in the air on its own, with nothing under it and
	# nothing around it. It will be reported as floating and that is
	# fine — what is being tested is the part attached to it.
	#
	# Standing it on a base brick seemed more realistic and was worse:
	# a stud pointing down then points straight into the base, and the
	# tool was blamed for an overlap the fixture had arranged.
	var placed := {"part": host, "color": 1, "x": 4, "y": 8, "z": 4,
		"face": face, "rot": 0}

	var answer: String = assistant._attachment_points(placed)
	for line: String in answer.split("\n"):
		if not line.strip_edges().begins_with("stud "):
			continue
		var at: Dictionary = _read(line)
		if at.is_empty():
			_failures += 1
			print("  FAIL  %s %s: could not read '%s'"
				% [host, face, line.strip_edges()])
			continue
		_checked += 1

		var model := Assistant.Model.new()
		for raw: Variant in [placed, {
				"part": "3024", "color": 15,
				"x": at["x"], "y": at["y"], "z": at["z"],
				"face": at["face"], "rot": 0}]:
			model.placements.append(Assistant.Placement.from_dict(raw))
		# The host as a brick already standing, which the check grounds:
		# support is now a walk out from the ground, and a host floating
		# on purpose would leave the plate on it floating too — which is
		# true and is not what this asks.
		model.placements[0].id = 1
		var verdict: Dictionary = assistant._check(model)

		# Brick 1 is the plate, and anything said about it is a fault in
		# the coordinates it was given.
		var wrong := PackedStringArray()
		for complaint: String in str(verdict["feedback"]).split("\n"):
			if complaint.contains("brick 1 "):
				wrong.append(complaint.strip_edges().lstrip("- "))
		if wrong.is_empty():
			continue
		_failures += 1
		print("  FAIL  %s facing %s, %s" % [host, face, line.strip_edges()])
		for complaint: String in wrong:
			print("        " + complaint)


## Pull the numbers back out of the line the tool wrote. Reading its own
## output is deliberate: if it cannot be read, the model cannot read it.
func _read(line: String) -> Dictionary:
	var out: Dictionary = {}
	for token: String in line.split(" ", false):
		var bits: PackedStringArray = token.split("=")
		if bits.size() != 2:
			continue
		if bits[0] == "face":
			out["face"] = bits[1]
		elif bits[0] in ["x", "y", "z"]:
			out[bits[0]] = float(bits[1])
	return out if out.size() == 4 else {}
