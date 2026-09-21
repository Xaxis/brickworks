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

## The six ways a part's studs can point.
##
## Naming them by direction rather than by rotation is deliberate: the
## question a builder asks is "which way do the studs face", and the
## answer is a direction. Which rotation produces it is arithmetic, and
## arithmetic is what the model should not have to do.
const FACES: Dictionary = {
	"up": Vector3.UP,
	"down": Vector3.DOWN,
	"+x": Vector3.RIGHT,
	"-x": Vector3.LEFT,
	"+z": Vector3.BACK,
	"-z": Vector3.FORWARD,
}

var library: PartLibrary
var world: BrickWorld
var builder: Builder
## The signed-in account, when there is one. The proxy will not answer
## without it. Left null on a desktop build calling Anthropic directly
## with its own key, where there is nobody to bill.
var account: Account

## Where the proxy lives. Relative on the web (same origin); on desktop
## this needs a full URL, or a key in the environment for a direct call.
var endpoint: String = DEFAULT_ENDPOINT
## Set from the environment on a developer's machine, to talk to
## Anthropic directly instead of via the proxy. A key the person pasted
## into the app is not this — see [method key_in_use], which prefers
## theirs.
var direct_key: String = ""


## The key this request will go out with, and therefore where it goes.
##
## A key belonging to the person using the app wins over one from the
## environment: on a machine that has both, theirs is the one they
## chose. Empty means the proxy, which answers for one account.
func key_in_use() -> String:
	var theirs: String = OwnKey.load_key()
	return theirs if not theirs.is_empty() else direct_key

var _http: HTTPRequest
var _messages: Array = []
var _busy: bool = false
var _repairs: int = 0
var _turns: int = 0
var _pending: Model = null
## Names the conversation for the proxy's monthly budget. One design is
## a dozen round trips and sometimes forty, so the turns have to be
## recognisable as belonging together — otherwise a single lighthouse
## spends six of the month's sixty.
var _design_id: String = ""

## Bricks that belong to the workspace rather than to any model — the
## baseplate. Set by whoever owns the scene; left empty, a snapshot
## would take the baseplate with it and put back a second one.
var scenery: Dictionary = {}

## What the world looked like before this instruction.
##
## Every path through a design replaces what the assistant built:
## a finished submission, a repair, and — since drafts went on screen —
## every check along the way. That is correct when a design succeeds
## and ruinous when one does not, because the model being replaced is
## the one the person already had. A design that exhausts its repairs,
## is cancelled, or loses the network used to leave them with nothing.
var _before: Array[Dictionary] = []
var _placed_ids: PackedInt64Array = PackedInt64Array()

signal said(text: String)
signal progress(note: String)
signal finished(ok: bool, summary: String)
signal built(brick_count: int)
## A model the assistant is still working on, put on screen so the wait
## is not a spinner. Not the same as [signal built] — nothing about a
## sketch is finished, and whoever is watching should not be shown an
## assembly animation for something about to be replaced.
signal sketched(brick_count: int)


## One placement, in the coordinates the model speaks.
class Placement extends RefCounted:
	var part: String
	var color: int
	## Studs and plates, and not always whole ones. A brick turned on its
	## side is 20 LDU tall, which is two and a half plates, so a grid of
	## whole plates cannot say where it goes. The lattice is 2 LDU, which
	## is a tenth of a stud across and a quarter of a plate up, and
	## everything here snaps to it.
	var x: float        ## studs
	var y: float        ## plates from the ground
	var z: float        ## studs
	## Which way the part's studs point. Everything else in this file
	## assumed "up", which is why a brick could never be laid on its side
	## and a tile could never stand up as a window pane.
	var face: String = "up"
	var rot: int        ## quarter turns about [member face]
	## The brick in the world this came from, when it came from one.
	## Zero for a placement the model has just invented. What makes
	## "remove brick 41" mean anything.
	var id: int = 0
	## Whether the assistant placed it. A brick the person put there by
	## hand stays theirs across an edit, so that a later design replaces
	## the assistant's work and leaves theirs alone.
	var mine: bool = true

	static func from_dict(raw: Dictionary) -> Placement:
		var p := Placement.new()
		p.part = str(raw.get("part", ""))
		p.color = int(raw.get("color", 7))
		p.x = float(raw.get("x", 0))
		p.y = float(raw.get("y", 0))
		p.z = float(raw.get("z", 0))
		p.face = str(raw.get("face", "up")).to_lower()
		if not FACES.has(p.face):
			p.face = "up"
		p.rot = posmod(int(raw.get("rot", 0)), 4)
		return p

	func where() -> String:
		return "%s,%s,%s" % [_num(x), _num(y), _num(z)]

	static func _num(value: float) -> String:
		return ("%d" % int(value) if is_equal_approx(value, round(value))
			else "%.2f" % value)


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


## Whether there is a conversation to carry on, as against a fresh
## start. The panel asks before deciding which of the two below to call.
func has_conversation() -> bool:
	return not _messages.is_empty()


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
		_restore()
		finished.emit(false, "cancelled")


func _start(text: String) -> void:
	if _busy:
		return
	_busy = true
	_repairs = 0
	_turns = 0
	_pending = null
	_before = _snapshot()
	# A new one per instruction, including a revision: asking for a
	# change starts a fresh round of turns and produces a new model, so
	# it is a design in the sense anyone would count.
	_design_id = _new_design_id()
	_messages.append({"role": "user", "content": text})
	progress.emit("thinking")
	_send()


## Unguessable, and in the alphabet the proxy accepts. Not a secret —
## the account is what limits spending — just something two designs are
## not going to share.
static func _new_design_id() -> String:
	var bytes := PackedByteArray()
	for _n: int in 12:
		bytes.append(randi() % 256)
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


## Everything in the world that is not scenery, with who placed it.
func _snapshot() -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	if world == null:
		return taken
	var mine: Dictionary = {}
	for brick_id: int in _placed_ids:
		mine[brick_id] = true
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		taken.append({
			"part": brick.part_id,
			"colour": brick.color_code,
			"at": brick.transform,
			"mine": mine.has(brick.id),
		})
	return taken


## Put back what was there before this instruction.
##
## Ids are minted afresh — BrickWorld numbers from one and the old ones
## are gone — so _placed_ids is rebuilt from which bricks were the
## assistant's, or a later design would refuse to replace its own work.
func _restore() -> void:
	if _before.is_empty():
		return
	# Everything that is not scenery, not just what the assistant built.
	# Restoring over the survivors put a second copy of every
	# hand-placed brick in the world — the snapshot holds them too,
	# because they are part of what was there.
	var doomed := PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			doomed.append(brick.id)
	for brick_id: int in doomed:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()

	for entry: Dictionary in _before:
		var brick_id: int = world.add_brick(
			str(entry["part"]), int(entry["colour"]), entry["at"])
		if brick_id == 0:
			continue
		builder.register(brick_id, str(entry["part"]), entry["at"])
		if bool(entry["mine"]):
			_placed_ids.append(brick_id)


func _send() -> void:
	_turns += 1
	if _turns > MAX_TURNS:
		_stop(false, "gave up after %d turns" % MAX_TURNS)
		return

	var body: Dictionary = request_body()

	var headers: PackedStringArray = ["content-type: application/json"]
	var url: String = endpoint
	var key: String = key_in_use()
	if not key.is_empty():
		url = "https://api.anthropic.com/v1/messages"
		headers.append("x-api-key: " + key)
		headers.append("anthropic-version: 2023-06-01")
		if OS.has_feature("web"):
			# Anthropic blocks browser calls unless asked not to, which
			# is the right default: it exists to stop a key being put in
			# a web page where every visitor can read it. Here the key
			# belongs to the person at the keyboard and never leaves
			# their machine except to Anthropic, which is the case the
			# header is for.
			headers.append("anthropic-dangerous-direct-browser-access: true")
	elif account != null:
		# Fetched rather than read, because a design can run for minutes
		# and the token may be minutes from expiring when it starts.
		var token: String = await account.access_token()
		if token.is_empty():
			_stop(false, "Sign in to use the assistant.")
			return
		headers.append("authorization: Bearer " + token)

	if _http.request(url, headers, HTTPClient.METHOD_POST,
			JSON.stringify(body)) != OK:
		_stop(false, "could not reach the assistant")
		return

	var result: Array = await _http.request_completed
	_on_response(result)


## The request, built where it can be looked at.
##
## The two routes do not take the same body and the difference is not
## cosmetic. design_id names the conversation for our proxy's monthly
## budget; it is not an Anthropic field, and sending it on the direct
## call gets the whole request refused with "design_id: Extra inputs are
## not permitted". That shipped, because every check went through the
## proxy and nothing exercised the direct route until the examples
## generator did and failed on all six.
##
## Separated from _send so a probe can inspect it without a network
## call, which is the only way this stays fixed.
func request_body() -> Dictionary:
	var body: Dictionary = {
		"model": MODEL,
		"max_tokens": 16000,
		"system": _system_prompt(),
		"messages": _messages,
		"tools": _tools(),
	}
	if not key_in_use().is_empty():
		# The proxy adds this itself, and adds it the same way for
		# everyone; here we are the client and have to ask.
		body["thinking"] = {"type": "adaptive"}
	elif account != null:
		body["design_id"] = _design_id
	return body


## Top-level fields Anthropic's Messages API will accept. Anything else
## on a direct call is refused outright rather than ignored.
## static var, not const: a PackedStringArray is built by a constructor
## call, which is not a constant expression, and declaring it const
## fails in a way that only shows up where it is used.
static var ANTHROPIC_FIELDS := PackedStringArray([
	"model", "max_tokens", "messages", "system", "tools", "tool_choice",
	"thinking", "temperature", "top_p", "top_k", "stop_sequences",
	"stream", "metadata", "service_tier", "output_config",
])


## Keep the remaining-designs count honest from the headers the proxy
## sends back, so the panel does not have to ask again after every build.
func _note_usage(headers: Variant) -> void:
	if account == null or typeof(headers) != TYPE_PACKED_STRING_ARRAY:
		return
	var used: int = -1
	var budget: int = -1
	for line: String in headers:
		var lower: String = line.to_lower()
		if lower.begins_with("x-designs-used:"):
			used = int(line.split(":", true, 1)[1].strip_edges())
		elif lower.begins_with("x-designs-budget:"):
			budget = int(line.split(":", true, 1)[1].strip_edges())
	if used >= 0:
		account.note_usage(used, budget)


func _on_response(result: Array) -> void:
	if not _busy:
		return
	var code: int = result[1]
	var payload: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())

	_note_usage(result[2])

	if code != 200 and typeof(parsed) == TYPE_DICTIONARY:
		# Two refusals deserve their own words rather than the generic
		# error line: both are ordinary states of a working account, and
		# neither is something to retry.
		if bool(parsed.get("signin_required", false)):
			if account != null:
				# The session is spent; make the panel offer the form
				# again rather than leaving a composer that cannot send.
				await account.boot()
			_stop(false, str(parsed.get("error", "Sign in to use the assistant.")))
			return
		if bool(parsed.get("quota_exhausted", false)):
			if account != null:
				account.note_usage(
					int(parsed.get("used", 0)), int(parsed.get("budget", 0)))
			_stop(false, str(parsed.get("error", "No designs left this month.")))
			return

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
				"content": await _run_tool(block),
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
		await _ensure_parts(_pending)
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
	# A design that failed leaves the model it was asked to change
	# exactly as it found it. Without this a revision that ran out of
	# repairs took the original with it — and the drafts shown along the
	# way are what removed it.
	if not ok:
		_restore()
	_busy = false
	finished.emit(ok, summary)


# -- tools ---------------------------------------------------------------


func _run_tool(block: Dictionary) -> String:
	# Awaited by the caller, because checking a design may first have to
	# fetch the geometry for parts this build has not loaded.
	var name: String = block.get("name", "")
	var args: Dictionary = block.get("input", {})

	match name:
		"search_parts":
			var query: String = str(args.get("query", ""))
			progress.emit("looking up \"%s\"" % query)
			return _search(query, int(args.get("limit", 15)))
		"check_design":
			var trial: Model = _read_model(args)
			# Fetch what the check will need first. Without this the web
			# build tells the model that real catalogue parts do not
			# exist — they are simply not loaded yet — and it goes off
			# and picks something else.
			await _ensure_parts(trial)
			var report: Dictionary = _check(trial)
			# On screen, not just counted. A design runs for minutes and
			# checks its work two or three times along the way; those
			# are the only glimpses of the shape there are before the
			# end, and they were being thrown away.
			if not trial.placements.is_empty():
				_apply(trial, false)
			progress.emit("checked %d bricks: %s" % [
				trial.placements.size(), report["summary"]])
			return report["feedback"]
		"look_at_model":
			progress.emit("looking at what is already built")
			return _describe_world()
		"view_model":
			var from: String = str(args.get("from", "front"))
			progress.emit("looking at the %s" % from)
			# Drawn from what is in the world, which during a design is
			# the last draft it checked — so this shows its own work,
			# not a hypothetical.
			return ModelView.draw(world, library, from, scenery)
		"edit_model":
			var edited: Model = _edit(args)
			if edited.placements.is_empty():
				return ("That would leave the baseplate empty. "
					+ "If clearing it is what you meant, say so instead.")
			await _ensure_parts(edited)
			var verdict: Dictionary = _check(edited)
			if not bool(verdict["ok"]):
				progress.emit("tried a change: %s" % verdict["summary"])
				return ("Not applied — the model would not hold together.\n"
					+ str(verdict["feedback"]))
			_apply_edit(edited)
			_pending = null
			progress.emit("changed it: %d bricks" % edited.placements.size())
			return ("Done. %d bricks now. "
				% edited.placements.size()
				+ "Call look_at_model or view_model to see it.")
		"submit_design":
			_pending = _read_model(args)
			progress.emit("submitted %d bricks" % _pending.placements.size())
			return "Received. Checking it now."
	return "No tool called %s." % name


## The baseplate as a model, so that changing it is a matter of
## changing a few placements rather than writing it out again.
##
## Re-emitting four hundred bricks to move one is expensive in the
## obvious way and wrong in a less obvious one: a model rewriting a long
## list from a description of it drifts, and the change asked for
## arrives alongside a dozen nobody asked for.
func _model_from_world() -> Model:
	var model := Model.new()
	if world == null:
		return model
	var mine: Dictionary = {}
	for brick_id: int in _placed_ids:
		mine[brick_id] = true
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var at: Vector3 = _to_studs(brick, info)
		var placement := Placement.new()
		placement.part = brick.part_id
		placement.color = brick.color_code
		placement.x = at.x
		placement.y = at.y
		placement.z = at.z
		placement.face = _face_of(brick.transform.basis)
		placement.rot = _turns_about(brick.transform.basis, placement.face)
		placement.id = brick.id
		placement.mine = mine.has(brick.id)
		model.placements.append(placement)
	return model


## Apply a patch to what is built, and say what it came to.
##
## Removals first, so that a brick can be taken away and another put in
## its place in one call without the two fighting over the same cells.
func _edit(args: Dictionary) -> Model:
	var model: Model = _model_from_world()
	var by_id: Dictionary = {}
	for placement: Placement in model.placements:
		by_id[placement.id] = placement

	var gone: Dictionary = {}
	for raw: Variant in args.get("remove", []):
		gone[int(raw)] = true
	if not gone.is_empty():
		var kept: Array[Placement] = []
		for placement: Placement in model.placements:
			if not gone.has(placement.id):
				kept.append(placement)
		model.placements = kept

	for raw: Variant in args.get("recolor", []):
		var order: Dictionary = raw
		var colour: int = int(order.get("color", 7))
		for id_raw: Variant in order.get("bricks", []):
			var placement: Placement = by_id.get(int(id_raw))
			if placement != null:
				placement.color = colour

	for raw: Variant in args.get("move", []):
		var order: Dictionary = raw
		var by := Vector3(float(order.get("dx", 0)),
			float(order.get("dy", 0)), float(order.get("dz", 0)))
		for id_raw: Variant in order.get("bricks", []):
			var placement: Placement = by_id.get(int(id_raw))
			if placement != null:
				placement.x += by.x
				placement.y += by.y
				placement.z += by.z

	for raw: Variant in args.get("add", []):
		model.placements.append(Placement.from_dict(raw))
	return model


## What is on the baseplate, in the coordinates the model speaks.
##
## Without this the assistant is blind to everything it did not place
## this conversation, so "add a chimney to this house" had nothing to
## add a chimney to, and "make the roof blue" could not find a roof. It
## would cheerfully build a second house beside the first.
##
## Positions are inverted back out of the transform rather than kept
## alongside it. Keeping a second copy of where every brick is would be
## two sources of truth for one fact, and the one that drifts is always
## the one nobody is looking at.
func _describe_world() -> String:
	if world == null or world.brick_count() == 0:
		return "The baseplate is empty. Nothing is built yet."

	var mine: Dictionary = {}
	for brick_id: int in _placed_ids:
		mine[brick_id] = true

	var rows := PackedStringArray()
	var tally: Dictionary = {}
	var low := Vector3(999999, 999999, 999999)
	var high := Vector3(-999999, -999999, -999999)
	var counted: int = 0

	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var at: Vector3 = _to_studs(brick, info)
		low = Vector3(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z))
		high = Vector3(maxf(high.x, at.x), maxf(high.y, at.y), maxf(high.z, at.z))

		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		tally[key] = int(tally.get(key, 0)) + 1
		counted += 1

		# Capped. A four-hundred brick model listed in full is most of a
		# context window spent on something the model mostly needs the
		# shape of, and the tally below carries what the rows drop.
		if rows.size() < WORLD_ROWS:
			var face: String = _face_of(brick.transform.basis)
			rows.append("  #%-4d %-9s c%-3d x=%-6s y=%-6s z=%-6s %s rot=%d%s" % [
				brick.id, brick.part_id, brick.color_code,
				Placement._num(at.x), Placement._num(at.y),
				Placement._num(at.z), face,
				_turns_about(brick.transform.basis, face),
				"" if mine.has(brick.id) else "   (placed by hand)"])

	var lines := PackedStringArray()
	lines.append("%d parts are on the baseplate." % counted)
	lines.append("They span x %s..%s, z %s..%s studs, and stand y %s..%s plates."
		% [Placement._num(low.x), Placement._num(high.x),
			Placement._num(low.z), Placement._num(high.z),
			Placement._num(low.y), Placement._num(high.y)])
	lines.append("")
	lines.append("Parts and colours, most first:")
	var keys: Array = tally.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(tally[a]) > int(tally[b]))
	for key: String in keys:
		var bits: PackedStringArray = key.split(":")
		lines.append("  %d x %s in colour %s" % [int(tally[key]), bits[0], bits[1]])

	lines.append("")
	if counted > rows.size():
		lines.append("Where the first %d of them are (of %d):"
			% [rows.size(), counted])
	else:
		lines.append("Where they are:")
	lines.append_array(rows)
	if counted > rows.size():
		lines.append("  … %d more, not listed." % (counted - rows.size()))
	return "\n".join(lines)


## As many rows as are worth spending. Enough to reason about a typical
## model in full, few enough that a large one does not crowd out the
## conversation that asked about it.
const WORLD_ROWS := 220


## A brick's placement, back in studs and plates. The inverse of
## [method _transform], and it has to stay that way — a description in
## coordinates the model cannot act on is worse than none.
func _to_studs(brick: BrickWorld.Brick, _info: PartLibrary.PartInfo) -> Vector3:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if part == null:
		return Vector3.ZERO
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	for cell: Vector3i in builder._cells_for(part, brick.transform):
		lo = Vector3i(mini(lo.x, cell.x), mini(lo.y, cell.y), mini(lo.z, cell.z))
	if lo.x == 0x7FFFFFFF:
		return Vector3.ZERO
	var ldu: Vector3 = BrickLattice.to_ldu(lo)
	return Vector3(ldu.x / STUD, ldu.y / PLATE, ldu.z / STUD)


## The rot that, with this face, reproduces this orientation.
##
## Found by trying all four rather than by trigonometry, because the
## four are the only answers there are and trying them cannot disagree
## with the rule that generated them.
static func _turns_about(basis: Basis, face: String) -> int:
	var snapped: Basis = BrickLattice.snap_basis(basis)
	for rot: int in 4:
		if _basis_for(face, rot).is_equal_approx(snapped):
			return rot
	return 0


## Quarter turns about Y, recovered from the basis.
##
## Measured off the X axis, not the forward one. Vector3.FORWARD is
## (0, 0, -1), so an unrotated basis gives atan2(0, -1) = pi and reads
## back as a half turn — which is a brick described to the assistant as
## facing the opposite way from the one it is facing.
static func _quarter_turns(basis: Basis) -> int:
	var right: Vector3 = basis * Vector3.RIGHT
	return posmod(int(round(atan2(-right.z, right.x) / (PI * 0.5))), 4)


func _search(query: String, limit: int) -> String:
	var found: Array[PartLibrary.PartInfo] = library.search(query, maxi(1, limit))
	var usable: Array[PartLibrary.PartInfo] = []
	for info: PartLibrary.PartInfo in found:
		if info.is_redirect() or not info.reachable:
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
			# Two different failures wearing one message. A part that is
			# not in the catalogue is a mistake to correct by choosing
			# another; a part that is in the catalogue but whose
			# geometry has not arrived is not the model's problem at
			# all, and telling it the part does not exist sends it
			# looking for a substitute that was never needed.
			if library.parts.has(placement.part):
				_note(issues, "not loaded",
					"part '%s' exists but its geometry has not arrived — "
					% placement.part + "keep it and try again")
			else:
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
				"brick %d (%s at %s) overlaps brick %d" % [
					index, placement.part, placement.where(),
					blockers[0]])
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


## Which placements have a stud from some other part reaching into
## them.
##
## A stud stands 4 LDU proud of the surface it rises from, so the cell
## it reaches into is the one just beyond its tip. Whoever owns that
## cell is being held by it — which is as true of a stud on the side of
## a brick as of one on top, and is the whole of what makes sideways
## building possible.
func _studs_reaching_in(model: Model, cells_of: Dictionary,
		lattice: BrickLattice) -> Dictionary:
	var held: Dictionary = {}
	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _transform(placement, part)
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			# A little past the tip, so the sample lands in the part
			# being held rather than on the boundary between them.
			var tip: Vector3 = at * (connector.position
				+ connector.axis.normalized() * 5.0)
			var reached: int = lattice.brick_at(BrickLattice.to_cell(tip))
			# brick_at returns index + 1, since zero means empty.
			if reached != 0 and reached - 1 != index:
				held[reached - 1] = true
	return held


func _check_support(
	model: Model, cells_of: Dictionary, lattice: BrickLattice,
	issues: Dictionary
) -> void:
	var studs: Dictionary = _studs_reaching_in(model, cells_of, lattice)
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

		# Or a stud from somewhere else points into it.
		#
		# "Something in the cell below" is the only rule there was, and
		# it is the rule that makes studs-not-on-top impossible: a part
		# held by a stud on the side of a brick has air beneath it by
		# construction. So a wall of smooth colour, a row of round
		# plates reading as rivets, a tile standing up as a window pane
		# — every one of them was rejected as floating, and three
		# repairs later the model has learned not to try.
		#
		# The library knows where every stud is and which way it points,
		# including the sideways ones: 87087 records its side stud at
		# axis +Z. It was never consulted.
		if not supported and studs.has(index):
			supported = true

		if not supported:
			_note(issues, "floating",
				"brick %d (%s at %s) has nothing holding it" % [
					index, placement.part, placement.where()])


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
## How many studs a part covers, from the cover rather than the bounds.
##
## footprint_studs() is ceil(size / 20), and a size a hair over a stud
## multiple rounds up a whole stud. A 2 x 2 round brick measures 40.001
## LDU and so reports three studs across; anchored on that it lands half
## a stud out in both axes, the validator calls it an overlap the model
## cannot explain from its own coordinates, and three repairs later the
## model has concluded round bricks do not work.
##
## The collision cover is the exact set of whole cells the part
## occupies — the same set the lattice uses — so anchoring on it is
## right by construction rather than by maintenance.
static func _cover_studs(part: Lbm.PartMesh, info: PartLibrary.PartInfo) -> Vector2i:
	if part == null or part.boxes.is_empty():
		# Nothing was built for this part; the bounds are all there is.
		return info.footprint_studs()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for box: AABB in part.boxes:
		lo = Vector2(minf(lo.x, box.position.x), minf(lo.y, box.position.z))
		hi = Vector2(
			maxf(hi.x, box.position.x + box.size.x),
			maxf(hi.y, box.position.z + box.size.z))
	var per_stud: float = STUD / part.cell_ldu
	return Vector2i(
		maxi(int(round((hi.x - lo.x) / per_stud)), 1),
		maxi(int(round((hi.y - lo.y) / per_stud)), 1))


## The orientation a face and a quarter turn come to.
##
## Rotation is applied about the part's new up rather than about the
## world's, so rot means the same thing whichever way the part is
## facing: turn it on the spot.
static func _basis_for(face: String, rot: int) -> Basis:
	var up: Vector3 = FACES.get(face, Vector3.UP)
	var tip: Basis
	if up.is_equal_approx(Vector3.UP):
		tip = Basis.IDENTITY
	elif up.is_equal_approx(Vector3.DOWN):
		tip = Basis(Vector3.RIGHT, PI)
	else:
		tip = Basis(Vector3.UP.cross(up).normalized(), PI * 0.5)
	return BrickLattice.snap_basis(Basis(up, rot * PI * 0.5) * tip)


## Which way the studs point, read back off an orientation.
static func _face_of(basis: Basis) -> String:
	var up: Vector3 = (basis * Vector3.UP).normalized()
	var best: String = "up"
	var best_dot: float = -2.0
	for name: String in FACES:
		var d: float = up.dot(FACES[name])
		if d > best_dot:
			best_dot = d
			best = name
	return best


## Where a part's lowest, leftmost, backmost cell falls if its origin is
## at the middle of cell zero. Cached: a design of four hundred bricks
## asks this for each of them, twice, and the answer depends only on the
## part and which way it is turned.
var _corner_cache: Dictionary = {}

func _corner_cell(part: Lbm.PartMesh, part_id: String, basis: Basis) -> Vector3i:
	var key: String = "%s|%s" % [part_id, basis]
	if _corner_cache.has(key):
		return _corner_cache[key]
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	for cell: Vector3i in builder._cells_for(part, Transform3D(basis, Vector3.ZERO)):
		lo = Vector3i(mini(lo.x, cell.x), mini(lo.y, cell.y), mini(lo.z, cell.z))
	if lo.x == 0x7FFFFFFF:
		lo = Vector3i.ZERO
	_corner_cache[key] = lo
	return lo


## Where the part goes, given the corner it is meant to occupy.
##
## One rule: x, y, z name the lowest, leftmost, backmost cell of the
## space the part takes up. Not its centre, and not its own origin,
## which for an LDraw part sits at the top of its body and is no use at
## all once the part is lying on its side.
##
## The rule this replaces read the height off the catalogue and the
## width off the cover, and so had a second opinion about where a part
## was for every part where those two disagreed. Reading both off the
## cover — the same cover the collision test uses — means the forward
## transform and [method _to_studs] cannot drift apart, because they are
## now the same measurement taken in opposite directions.
func _transform(placement: Placement, part: Lbm.PartMesh) -> Transform3D:
	var basis: Basis = _basis_for(placement.face, placement.rot)
	var corner: Vector3i = _corner_cell(part, placement.part, basis)
	var want := BrickLattice.to_cell(Vector3(
		placement.x * STUD, placement.y * PLATE, placement.z * STUD))
	return Transform3D(basis, BrickLattice.to_ldu(want - corner))


# -- applying ------------------------------------------------------------


## Make sure every part a design uses is to hand before placing any of
## it. On the web most are fetched rather than shipped, and a model that
## lands half-built because the rest was still downloading is worse than
## one that takes a moment longer.
func _ensure_parts(model: Model) -> void:
	var wanted: Dictionary = {}
	for placement: Placement in model.placements:
		if not library.is_resident(placement.part):
			wanted[placement.part] = true
	if wanted.is_empty():
		return

	progress.emit("fetching %d part%s" % [
		wanted.size(), "" if wanted.size() == 1 else "s"])
	for part_id: String in wanted:
		library.request_mesh(part_id)

	# Wait for them, but not forever: a part that never arrives should
	# cost a few seconds, not the whole design.
	var deadline: int = Time.get_ticks_msec() + 20000
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		for part_id: String in wanted.keys():
			if library.is_resident(part_id):
				wanted.erase(part_id)


## Put a model in the world.
##
## [param finished] separates the design it submitted from the drafts it
## checked along the way. Both are shown — a design takes minutes and
## watching a shape appear beats watching a spinner — but only the
## finished one is worth an assembly animation, and only the finished
## one means anything to the rest of the app.
## Carry out an edit, touching only the bricks it changes.
##
## Tearing the model down and building it again from the patched list
## would be far less code, and it renumbers every brick — so a model
## that reads the numbers once and then makes two changes has its second
## change land on whatever now happens to hold those numbers. Which is
## to say: on the wrong bricks, silently.
func _apply_edit(model: Model) -> void:
	var wanted: Dictionary = {}
	var fresh: Array[Placement] = []
	for placement: Placement in model.placements:
		if placement.id != 0:
			wanted[placement.id] = placement
		else:
			fresh.append(placement)

	var mine: Dictionary = {}
	for brick_id: int in _placed_ids:
		mine[brick_id] = true

	# Gone, and anything whose part changed — which is a different brick
	# wearing the same number, not a brick that moved.
	var doomed := PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var placement: Placement = wanted.get(brick.id)
		if placement == null:
			doomed.append(brick.id)
		elif placement.part != brick.part_id:
			doomed.append(brick.id)
			fresh.append(placement)
			wanted.erase(brick.id)
	for brick_id: int in doomed:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
		mine.erase(brick_id)

	# Moved or recoloured, keeping the number they were given.
	for brick_id: int in wanted:
		var placement: Placement = wanted[brick_id]
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if brick == null or part == null:
			continue
		var at: Transform3D = _transform(placement, part)
		if not brick.transform.is_equal_approx(at):
			world.move_brick(brick_id, at)
			builder.lattice.release(brick_id)
			builder.register(brick_id, placement.part, at)
		if brick.color_code != placement.color:
			world.recolor_brick(brick_id, placement.color)

	for placement: Placement in fresh:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _transform(placement, part)
		var brick_id: int = world.add_brick(
			placement.part, placement.color, at)
		if brick_id != 0:
			builder.register(brick_id, placement.part, at)
			if placement.mine:
				mine[brick_id] = true

	_placed_ids = PackedInt64Array()
	for brick_id: int in mine:
		_placed_ids.append(brick_id)
	built.emit(_placed_ids.size())


## Put a model on the baseplate, replacing whatever the assistant built
## last time and leaving anything the person placed by hand alone.
func _apply(model: Model, finished: bool = true) -> void:
	for brick_id: int in _placed_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()

	# A part whose geometry never arrived used to be skipped here in
	# silence, and what the person got was the design minus its wheels
	# with nothing to say so. Say so.
	var missing: Dictionary = {}
	for placement: Placement in model.placements:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			missing[placement.part] = true
			continue
		var at: Transform3D = _transform(placement, part)
		var brick_id: int = world.add_brick(placement.part, placement.color, at)
		if brick_id != 0:
			builder.register(brick_id, placement.part, at)
			if placement.mine:
				_placed_ids.append(brick_id)

	if not missing.is_empty():
		var names: Array = missing.keys()
		names.sort()
		progress.emit("%d part%s could not be loaded and %s left out: %s" % [
			names.size(), "" if names.size() == 1 else "s",
			"was" if names.size() == 1 else "were",
			", ".join(PackedStringArray(names.slice(0, 6)))])

	if finished:
		built.emit(_placed_ids.size())
	else:
		sketched.emit(_placed_ids.size())


## How many bricks in the world the assistant considers its own.
func built_count() -> int:
	return _placed_ids.size()


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
  face says which way the studs point: up (the default), down, +x, -x, \
+z or -z.
  rot is quarter turns about the face direction: 0, 1, 2 or 3. Rotating \
swaps the footprint but does not move the corner.

SIDEWAYS
Real models are not built only upward. A smooth wall, a grille, a row of \
rivets, a curved bonnet, lettering on a sign — all of it is parts turned \
on their side, and you can turn them.

  A brick laid on its side is 20 LDU tall, which is two and a half \
plates, so y takes quarters: 0, 0.25, 0.5, 0.75, 1 and so on. x and z \
take tenths of a stud the same way. Whole numbers everywhere is still \
right for ordinary upward building.
  Parts that exist to let you do this: 87087 (1x1 brick with a stud on \
one side), 4070 (1x1 headlight brick), 99207 (1x2 bracket), 44728 (1x2 \
bracket 2x2). Put one of those in the wall and the parts that hang off \
it get face +x, -x, +z or -z.
  check_design accepts a part held by a stud from any direction, not \
just one sitting on something. If it says a part has nothing holding \
it, nothing is touching it — move it, do not give up on the idea.

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

You cannot see the baseplate. If the request is about what is already \
there — adding to it, changing part of it, making it taller, matching \
its colours — call look_at_model first. Guessing what is there and \
building beside it is the failure this prevents, and it is not \
recoverable: submitting replaces everything you placed, so a design \
that ignored the existing model will have thrown it away.

When you revise, submit the WHOLE model, including the parts you are \
keeping. Anything the person placed by hand is left alone; anything you \
placed and leave out of the new submission is removed.

Always use search_parts before using a part number you are not certain \
of. A guessed number is not a part and the design will be rejected.

LOOK AT IT
check_design tells you a model is legal. view_model tells you what it
is, which is the thing you are actually being judged on — a car that
holds together and does not look like a car is a failure, and it is a
failure you cannot see from a brick count.

Look at least twice: once when the main shape is laid out, while
changing it is cheap, and once before you submit. Choose the side that
would show the mistake — a car from the left, a tower from the front, a
mosaic or a floor plan from the top.

Read the drawing as a drawing. If the roof line is flat where it should
slope, if one end is taller than the other when they should match, if a
window is a stud off centre, if the silhouette has a notch in it you
did not intend — that is what looking is for. Then fix it and carry on.
Do not look after every brick; each look costs a turn and you have a
limited number.

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

Round and organic things are made by stepping. Each layer is a stud or \
two narrower or wider than the one below, and the silhouette comes from \
that taper. A single flat slab of plates is the shape of a table: if \
what you are building does not have a flat top, do not give it one. A \
tree canopy, a rock, a hill, a dome — all of them are three or four \
layers of different footprints, never one.

Ground is part of the model or it is not there at all. Plates scattered \
around the base at different heights read as debris, not as a lawn. \
Either lay a deliberate shape — an even layer, a definite edge — or \
leave the baseplate bare and let the model stand on it.

You are talking to someone who is watching the model appear as you build \
it. Say what you are going for in a sentence or two — not a list of \
steps, not a description of every brick. Then build it.

Finish by calling submit_design with the complete list of parts.

CHANGING SOMETHING THAT IS ALREADY BUILT
Do not describe it again. Call look_at_model, which prints a number \
beside every brick, then edit_model with those numbers: remove, \
recolor, move, add. Rewriting four hundred placements to move one wall \
costs a fortune and loses details nobody asked you to change. \
submit_design is for starting something new."""


func _tools() -> Array:
	var brick: Dictionary = {
		"type": "object",
		"properties": {
			"part": {"type": "string", "description": "part number, e.g. 3001"},
			"color": {"type": "integer", "description": "LDraw colour code"},
			"x": {"type": "number", "description":
				"studs across, to the low corner. Tenths allowed."},
			"y": {"type": "number", "description":
				"plates up from the ground, to the low corner. "
				+ "Quarters allowed, for parts lying on their side."},
			"z": {"type": "number", "description":
				"studs deep, to the low corner. Tenths allowed."},
			"face": {"type": "string",
				"enum": ["up", "down", "+x", "-x", "+z", "-z"],
				"description":
					"which way the studs point. Omit for up."},
			"rot": {"type": "integer", "description":
				"quarter turns about the face direction, 0-3"},
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
			"name": "edit_model",
			"description": ("Change what is already built without "
				+ "describing it again. Takes the numbers look_at_model "
				+ "prints beside each brick. Use this for any change to "
				+ "an existing model — moving a wall, recolouring a "
				+ "roof, taking a chimney off, adding a door — and only "
				+ "use submit_design when starting something new. "
				+ "Everything is checked together before any of it is "
				+ "applied, so a change that would not hold together "
				+ "changes nothing."),
			"input_schema": {
				"type": "object",
				"properties": {
					"remove": {
						"type": "array",
						"items": {"type": "integer"},
						"description": "brick numbers to take away",
					},
					"recolor": {
						"type": "array",
						"items": {
							"type": "object",
							"properties": {
								"bricks": {"type": "array",
									"items": {"type": "integer"}},
								"color": {"type": "integer"},
							},
							"required": ["bricks", "color"],
							"additionalProperties": false,
						},
					},
					"move": {
						"type": "array",
						"items": {
							"type": "object",
							"properties": {
								"bricks": {"type": "array",
									"items": {"type": "integer"}},
								"dx": {"type": "number",
									"description": "studs"},
								"dy": {"type": "number",
									"description": "plates"},
								"dz": {"type": "number",
									"description": "studs"},
							},
							"required": ["bricks"],
							"additionalProperties": false,
						},
					},
					"add": {"type": "array", "items": brick},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "look_at_model",
			"description": ("See what is already on the baseplate, in the "
				+ "same stud and plate coordinates you use. Call this "
				+ "first whenever the request is about what is there — "
				+ "adding to it, changing part of it, matching its "
				+ "colours or its height. You cannot see the model "
				+ "otherwise."),
			"input_schema": {
				"type": "object",
				"properties": {},
				"additionalProperties": false,
			},
		},
		{
			"name": "view_model",
			"description": ("Look at what is on the baseplate, drawn as "
				+ "text: a plan from above or an elevation from any "
				+ "side, each square a stud across and a plate tall, "
				+ "lettered by colour. This is the only way to see "
				+ "whether the thing you are building looks like the "
				+ "thing you were asked for. check_design tells you a "
				+ "model is legal; this tells you what it is."),
			"input_schema": {
				"type": "object",
				"properties": {
					"from": {
						"type": "string",
						"enum": ["top", "front", "back", "left", "right"],
						"description": "which side to look from",
					},
				},
				"required": ["from"],
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
