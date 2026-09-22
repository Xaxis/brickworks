## Can a model too big to list in one go still be worked on?
##
##   godot --headless --path . --script src/dev/scale_probe.gd
##
## look_at_model printed the first 220 bricks and said how many more
## there were, and edit_model can only address bricks by the numbers it
## printed. So past 220 parts the rest of the model was not merely
## unlisted, it was unreachable: it could not be inspected, named or
## corrected. A real set runs to thousands of pieces, and revision is
## where set quality actually comes from.
extends SceneTree

const MANY := 600

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
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

	# A field of bricks, laid out so that a section can be named: thirty
	# across in x, twenty deep in z, two studs apart.
	for n: int in MANY:
		var at := Transform3D(Basis.IDENTITY, Vector3(
			float(n % 30) * 40.0, 24.0, float(n / 30) * 40.0))
		var id: int = world.add_brick("3005", 4, at)
		if id != 0:
			builder.register(id, "3005", at)
			assistant._placed_ids.append(id)
	await process_frame

	print("  a model of %d bricks" % MANY)
	var whole: String = assistant._describe_world({})
	_check("the total is the whole model, not the part that was listed",
		whole.contains("%d parts are on the baseplate" % MANY))
	_check("it says how to see the rest", whole.contains("skip="))
	var listed: int = _rows(whole)
	_check("it lists a windowful, %d rows" % listed,
		listed > 0 and listed <= 220)

	print("")
	print("  one section of it")
	var corner: String = assistant._describe_world({
		"where": {"x_from": 0.0, "x_to": 6.0, "z_from": 0.0, "z_to": 6.0}})
	_check("the total still describes the whole model",
		corner.contains("%d parts are on the baseplate" % MANY))
	_check("but only the section is listed, %d rows" % _rows(corner),
		_rows(corner) > 0 and _rows(corner) < listed)
	_check("and it says how many are in that section",
		corner.contains("in the part you asked about"))

	print("")
	print("  and walking past the end of the first listing")
	var onward: String = assistant._describe_world({"skip": 220})
	_check("skipping gives different bricks",
		_rows(onward) > 0 and _first_row(onward) != _first_row(whole))

	print("")
	if _failures == 0:
		print("a model larger than one listing can still be worked on")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## How many brick rows a listing carries.
static func _rows(text: String) -> int:
	var n: int = 0
	for line: String in text.split("\n"):
		if line.begins_with("  #"):
			n += 1
	return n


static func _first_row(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("  #"):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
