## The design assistant, running the loop inside the app.
##
## The model proposes; the app disposes. Claude describes placements in
## studs and plates, and every one is resolved against the same catalogue
## and the same collision lattice the renderer uses — not a copy of them
## on a server that could drift. When a design does not hold together the
## specific brick and the specific reason go back, and it tries again.
##
## Keeping the loop here rather than server-side is what makes the tools
## honest. [code]search_parts[/code] searches the catalogue that is
## loaded; [code]check_design[/code] runs the collision test that decides
## whether a brick can actually be placed. A server would have to
## reimplement both, and the moment the two disagree the one the user
## sees is the wrong one.
##
## The server holds the API key and nothing else. See api/claude.js.
class_name Assistant
extends Node

const DEFAULT_ENDPOINT := "/api/claude"
const MODEL := "claude-opus-5"
## Turns, not repairs. Most of a design is looking parts up and checking
## work; 24 was not enough and a run ended having built nothing at all
## after spending its budget on three-brick experiments.
const MAX_TURNS := 45
const MAX_REPAIRS := 3

## Studs and plates, as the model speaks them.
const STUD := 20.0
const PLATE := 8.0

var library: PartLibrary
var world: BrickWorld
var builder: Builder

## Where the proxy lives. Relative on the web (same origin); on desktop
## this needs a full URL, or a key in the environment for a direct call.
var endpoint: String = DEFAULT_ENDPOINT
## Set on desktop to talk to Anthropic directly instead of via the proxy.
var direct_key: String = ""

var _http: HTTPRequest
var _messages: Array = []
var _busy: bool = false
var _repairs: int = 0
var _turns: int = 0
var _pending: Model = null
var _placed_ids: PackedInt64Array = PackedInt64Array()

signal said(text: String)
signal progress(note: String)
signal finished(ok: bool, summary: String)
signal built(brick_count: int)


## One placement, in the coordinates the model speaks.
class Placement extends RefCounted:
	var part: String
	var color: int
	var x: int          ## studs
	var y: int          ## plates from the ground
	var z: int          ## studs
	var rot: int        ## quarter turns

	static func from_dict(raw: Dictionary) -> Placement:
		var p := Placement.new()
		p.part = str(raw.get("part", ""))
		p.color = int(raw.get("color", 7))
		p.x = int(raw.get("x", 0))
		p.y = int(raw.get("y", 0))
		p.z = int(raw.get("z", 0))
		p.rot = int(raw.get("rot", 0)) % 4
		return p


class Model extends RefCounted:
	var name: String = "Model"
	var description: String = ""
	var placements: Array[Placement] = []


func _ready() -> void:
	_http = HTTPRequest.new()
	# A design can take minutes of model time; the default would give up.
	_http.timeout = 300.0
	add_child(_http)


func is_busy() -> bool:
	return _busy


## Start a fresh design, discarding any conversation so far.
func design(brief: String) -> void:
	_messages.clear()
	_start(brief)


## Ask for a change to what is already built, keeping the conversation.
func revise(instruction: String) -> void:
	if _messages.is_empty():
		design(instruction)
		return
	_start(instruction)


func cancel() -> void:
	if _busy:
		_http.cancel_request()
		_busy = false
		finished.emit(false, "cancelled")


func _start(text: String) -> void:
	if _busy:
		return
	_busy = true
	_repairs = 0
	_turns = 0
	_pending = null
	_messages.append({"role": "user", "content": text})
	progress.emit("thinking")
	_send()


func _send() -> void:
	_turns += 1
	if _turns > MAX_TURNS:
		_stop(false, "gave up after %d turns" % MAX_TURNS)
		return

	var body: Dictionary = {
		"model": MODEL,
		"max_tokens": 16000,
		"system": _system_prompt(),
		"messages": _messages,
		"tools": _tools(),
	}

	var headers: PackedStringArray = ["content-type: application/json"]
	var url: String = endpoint
	if not direct_key.is_empty():
		url = "https://api.anthropic.com/v1/messages"
		headers.append("x-api-key: " + direct_key)
		headers.append("anthropic-version: 2023-06-01")
		body["thinking"] = {"type": "adaptive"}

	if _http.request(url, headers, HTTPClient.METHOD_POST,
			JSON.stringify(body)) != OK:
		_stop(false, "could not reach the assistant")
		return

	var result: Array = await _http.request_completed
	_on_response(result)


func _on_response(result: Array) -> void:
	if not _busy:
		return
	var code: int = result[1]
	var payload: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())

	if code != 200 or typeof(parsed) != TYPE_DICTIONARY:
		var detail: String = "HTTP %d" % code
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			var err: Variant = parsed["error"]
			detail = str(err.get("message", err)) if typeof(err) == TYPE_DICTIONARY else str(err)
		_stop(false, detail)
		return

	var response: Dictionary = parsed
	if response.get("stop_reason", "") == "refusal":
		_stop(false, "the assistant declined this request")
		return

	var content: Array = response.get("content", [])
	_messages.append({"role": "assistant", "content": content})

	var tool_results: Array = []
	for item: Variant in content:
		var block: Dictionary = item
		var kind: String = block.get("type", "")
		if kind == "text":
			var spoken: String = str(block.get("text", "")).strip_edges()
			if not spoken.is_empty():
				said.emit(spoken)
		elif kind == "tool_use":
			tool_results.append({
				"type": "tool_result",
				"tool_use_id": block.get("id", ""),
				"content": _run_tool(block),
			})

	if tool_results.is_empty():
		# Nothing called and nothing submitted: it has finished talking.
		_stop(_pending != null, "done")
		return

	_messages.append({"role": "user", "content": tool_results})

	if _pending == null:
		_send()
		return

	# A design arrived. Check it against the real lattice.
	var report: Dictionary = _check(_pending)
	progress.emit(report["summary"])

	if report["ok"]:
		_apply(_pending)
		_stop(true, report["summary"])
		return

	if _repairs >= MAX_REPAIRS:
		_stop(false, "could not make it hold together: " + report["summary"])
		return

	_repairs += 1
	_pending = null
	progress.emit("repairing (attempt %d)" % _repairs)
	_messages.append({
		"role": "user",
		"content": ("That design does not hold together yet:\n\n"
			+ report["feedback"]
			+ "\n\nFix those specific parts and submit the whole design "
			+ "again. Remember that parts side by side are not connected "
			+ "— only stacking connects them, so stagger the joints."),
	})
	_send()


func _stop(ok: bool, summary: String) -> void:
	_busy = false
	finished.emit(ok, summary)


# -- tools ---------------------------------------------------------------


func _run_tool(block: Dictionary) -> String:
	var name: String = block.get("name", "")
	var args: Dictionary = block.get("input", {})

	match name:
		"search_parts":
			var query: String = str(args.get("query", ""))
			progress.emit("looking up \"%s\"" % query)
			return _search(query, int(args.get("limit", 15)))
		"check_design":
			var trial: Model = _read_model(args)
			var report: Dictionary = _check(trial)
			progress.emit("checked %d bricks: %s" % [
				trial.placements.size(), report["summary"]])
			return report["feedback"]
		"submit_design":
			_pending = _read_model(args)
			progress.emit("submitted %d bricks" % _pending.placements.size())
			return "Received. Checking it now."
	return "No tool called %s." % name


func _search(query: String, limit: int) -> String:
	var found: Array[PartLibrary.PartInfo] = library.search(query, maxi(1, limit))
	var usable: Array[PartLibrary.PartInfo] = []
	for info: PartLibrary.PartInfo in found:
		if info.is_redirect() or not info.packed:
			continue
		usable.append(info)

	if usable.is_empty():
		return "No parts match '%s'. Try fewer or plainer words." % query

	var lines: PackedStringArray = PackedStringArray()
	for info: PartLibrary.PartInfo in usable:
		lines.append(_describe(info))
	return "\n".join(lines)


func _describe(info: PartLibrary.PartInfo) -> String:
	var footprint: Vector2i = info.footprint_studs()
	var plates: int = _height_plates(info)
	var studs: String = ("%d studs on top" % info.stud_count
		if info.stud_count > 0 else "no studs on top")
	return "%s: %s, covers %dx%d studs, %d plate%s, %s" % [
		info.id, info.name.strip_edges(), footprint.x, footprint.y,
		plates, "" if plates == 1 else "s", studs]


static func _height_plates(info: PartLibrary.PartInfo) -> int:
	var body: float = info.size.y
	if info.stud_count > 0:
		body -= 4.0
	return maxi(1, int(round(body / PLATE)))


func _read_model(args: Dictionary) -> Model:
	var model := Model.new()
	model.name = str(args.get("name", "Model"))
	model.description = str(args.get("description", ""))
	for raw: Variant in args.get("bricks", []):
		model.placements.append(Placement.from_dict(raw))
	return model


# -- validation ----------------------------------------------------------


## Check a proposed design against the real lattice.
##
## Runs on a scratch lattice rather than the live one, so a failing
## design never half-lands in the scene. Everything the app knows about
## collision is used here; nothing is approximated for the model's sake.
func _check(model: Model) -> Dictionary:
	var lattice := BrickLattice.new()
	var issues: Dictionary = {}     ## kind -> Array[String]
	var cells_of: Dictionary = {}   ## index -> Array[Vector3i]

	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			_note(issues, "unknown part",
				"no part '%s' exists" % placement.part)
			continue
		if placement.y < 0:
			_note(issues, "below ground",
				"brick %d (%s) is at y=%d, below the ground" % [
					index, placement.part, placement.y])
			continue

		var at: Transform3D = _transform(placement, part)
		var cells: Array[Vector3i] = builder._cells_for(part, at)
		var blockers: PackedInt64Array = lattice.blockers(cells)
		if not blockers.is_empty():
			_note(issues, "overlap",
				"brick %d (%s at %d,%d,%d) overlaps brick %d" % [
					index, placement.part, placement.x, placement.y,
					placement.z, blockers[0]])
			continue

		lattice.occupy(index + 1, cells)
		cells_of[index] = cells

	_check_support(model, cells_of, lattice, issues)

	var errors: int = 0
	for kind: String in issues:
		errors += issues[kind].size()

	var ok: bool = errors == 0 and not model.placements.is_empty()
	var summary: String = ("%d bricks, buildable" % model.placements.size()
		if ok else "%d problem%s" % [errors, "" if errors == 1 else "s"])

	return {
		"ok": ok,
		"summary": summary,
		"feedback": _feedback(issues, summary),
	}


func _check_support(
	model: Model, cells_of: Dictionary, lattice: BrickLattice,
	issues: Dictionary
) -> void:
	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		if placement.y == 0:
			continue
		var cells: Array[Vector3i] = cells_of[index]
		var floor_y: int = 0x7FFFFFFF
		for cell: Vector3i in cells:
			floor_y = mini(floor_y, cell.y)

		var supported: bool = false
		for cell: Vector3i in cells:
			if cell.y != floor_y:
				continue
			var below: int = lattice.brick_at(Vector3i(cell.x, cell.y - 1, cell.z))
			if below != 0 and below != index + 1:
				supported = true
				break
		if not supported:
			_note(issues, "floating",
				"brick %d (%s at %d,%d,%d) has nothing beneath it" % [
					index, placement.part, placement.x, placement.y,
					placement.z])


static func _note(issues: Dictionary, kind: String, message: String) -> void:
	if not issues.has(kind):
		issues[kind] = []
	issues[kind].append(message)


static func _feedback(issues: Dictionary, summary: String) -> String:
	if issues.is_empty():
		return summary
	# Grouped and capped: a hundred instances of one mistake teach no more
	# than three do, and crowd out the others.
	var lines: PackedStringArray = PackedStringArray()
	for kind: String in issues:
		var found: Array = issues[kind]
		lines.append("%s (%d):" % [kind, found.size()])
		for n: int in mini(3, found.size()):
			lines.append("  - " + str(found[n]))
		if found.size() > 3:
			lines.append("  - ... and %d more like it" % (found.size() - 3))
	return "\n".join(lines)


## Where a placement puts the part, in world units.
##
## Three conversions at once, and all three are easy to get wrong by
## hand: the anchor moves from the footprint's low corner to the part's
## centre, the height is measured in plates, and a part's own origin sits
## at the top of its body rather than the bottom.
func _transform(placement: Placement, _part: Lbm.PartMesh) -> Transform3D:
	var info: PartLibrary.PartInfo = library.parts[placement.part]
	var footprint: Vector2i = info.footprint_studs()
	var across: int = footprint.y if placement.rot % 2 == 1 else footprint.x
	var deep: int = footprint.x if placement.rot % 2 == 1 else footprint.y

	var basis := Basis(Vector3.UP, placement.rot * PI * 0.5)
	# A part's own origin sits at the TOP of its body — the mesh spans
	# -height..0 in Y, with the studs above zero — so a part resting on
	# layer y has its origin at the top of the plates it occupies, and
	# nothing further is subtracted.
	#
	# Subtracting the mesh's maximum Y here was wrong in a way that hid
	# itself: it took off the 4 LDU of stud, so studded parts sank half a
	# plate while tiles and slopes without studs sat correctly. The check
	# used the same transform, so a design still validated — it was just
	# validating the wrong arrangement.
	var origin := Vector3(
		(placement.x + across * 0.5) * STUD,
		(placement.y + _height_plates(info)) * PLATE,
		(placement.z + deep * 0.5) * STUD)
	return Transform3D(basis, origin)


# -- applying ------------------------------------------------------------


func _apply(model: Model) -> void:
	# Replace what the assistant built last time, leaving anything the
	# person placed by hand alone.
	for brick_id: int in _placed_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()

	for placement: Placement in model.placements:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _transform(placement, part)
		var brick_id: int = world.add_brick(placement.part, placement.color, at)
		if brick_id != 0:
			builder.register(brick_id, placement.part, at)
			_placed_ids.append(brick_id)

	built.emit(_placed_ids.size())


func clear_built() -> void:
	for brick_id: int in _placed_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()


# -- prompt --------------------------------------------------------------


func _system_prompt() -> String:
	return """You design models out of real bricks, inside an application \
that builds whatever you submit. Your designs get built, so they have to \
hold together.

COORDINATES
Positions are in brick units, not millimetres.
  x and z count studs across the baseplate.
  y counts plates upward from the ground, which is y=0.
  A brick is 3 plates tall. A plate is 1. A tile is 1.
  x, y, z is the LOW CORNER of the part's footprint, not its centre.
  A 2x4 brick at x=0,z=0 covers studs 0..3 across and 0..1 deep.
  rot is quarter turns about the vertical axis: 0, 1, 2 or 3. Rotating \
swaps the footprint but does not move the corner.

So a 2x4 brick at y=0 occupies plates 0,1,2. The next brick on top of it \
goes at y=3. Two bricks side by side at y=0 go at x=0 and x=4.

THE RULES YOUR DESIGN MUST SATISFY
1. Nothing may overlap. Two parts cannot share space.
2. Nothing may float. Every part needs the ground (y=0) or another part \
directly beneath it.
3. The model must be ONE connected thing. Parts that merely sit side by \
side are NOT connected — only stacking connects them.

Rule 3 is the one that catches people. A wall built as separate stacked \
columns is not a wall, it is several towers. Stagger the joints: offset \
alternate courses so each part bridges the seam below it, exactly as you \
would with real bricks.

HOW TO WORK
Think about the shape first, then lay it out layer by layer from the \
ground up.

Always use search_parts before using a part number you are not certain \
of. A guessed number is not a part and the design will be rejected.

Use check_design on the whole model, or on a substantial part of it. \
Checking three bricks tells you almost nothing and costs a turn; you \
have a limited number of them and running out means nothing gets built. \
Two or three checks over a design is right — once the structure is laid \
out, once after detailing, and once more if something needs fixing.

Do not probe the coordinate system with tiny experiments. The rules \
above are exact and complete. If a slope faces the wrong way, change its \
rot and carry on; do not submit a three-brick model to find out which \
way it points.

Search once per thing you need, with plain words — "slope curved", \
"cone", "plate 1 x 2". Searching the same word repeatedly returns the \
same answer.

WHAT MAKES A MODEL GOOD
Shape reads before detail does. Get the silhouette right first.
Vary the colour with purpose, not at random.
Use slopes and tiles to break up the staircase that stacked bricks make.
A smaller model that reads clearly beats a larger one that does not.

You are talking to someone who is watching the model appear as you build \
it. Say what you are going for in a sentence or two — not a list of \
steps, not a description of every brick. Then build it.

Finish by calling submit_design with the complete list of parts. If you \
are asked to change something, submit the whole model again with the \
change made."""


func _tools() -> Array:
	var brick: Dictionary = {
		"type": "object",
		"properties": {
			"part": {"type": "string", "description": "part number, e.g. 3001"},
			"color": {"type": "integer", "description": "LDraw colour code"},
			"x": {"type": "integer", "description": "studs across"},
			"y": {"type": "integer", "description": "plates up from ground"},
			"z": {"type": "integer", "description": "studs deep"},
			"rot": {"type": "integer", "description": "quarter turns, 0-3"},
		},
		"required": ["part", "color", "x", "y", "z", "rot"],
		"additionalProperties": false,
	}

	return [
		{
			"name": "search_parts",
			"description": ("Find real parts by description. Returns part "
				+ "numbers with their footprint and height. Use this "
				+ "instead of guessing a part number."),
			"input_schema": {
				"type": "object",
				"properties": {
					"query": {"type": "string"},
					"limit": {"type": "integer"},
				},
				"required": ["query"],
				"additionalProperties": false,
			},
		},
		{
			"name": "check_design",
			"description": ("Check a list of parts for overlaps, floating "
				+ "parts and whether it is one connected model. Safe to "
				+ "call on a partial design while you work."),
			"input_schema": {
				"type": "object",
				"properties": {"bricks": {"type": "array", "items": brick}},
				"required": ["bricks"],
				"additionalProperties": false,
			},
		},
		{
			"name": "submit_design",
			"description": "Submit the finished model, with every part.",
			"input_schema": {
				"type": "object",
				"properties": {
					"name": {"type": "string"},
					"description": {"type": "string"},
					"bricks": {"type": "array", "items": brick},
				},
				"required": ["name", "description", "bricks"],
				"additionalProperties": false,
			},
		},
	]
