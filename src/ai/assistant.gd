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

## How many times to ask again when the connection drops, before
## giving up on a design that may have been running for a long time.
const TRIES_WHEN_DROPPED := 4

const DEFAULT_ENDPOINT := "/api/claude"
## What designs when nothing has been chosen. The choosing lives in
## [Brain], with the table of what each model will actually accept.
const MODEL := Brain.DEFAULT_MODEL
## Turns, not repairs. Most of a design is looking parts up and checking
## work; 24 was not enough and a run ended having built nothing at all
## after spending its budget on three-brick experiments.
const MAX_TURNS := 45
const MAX_REPAIRS := 3
## How many times to ask again when a turn ends having built nothing.
const MAX_NUDGES := 2
## Beyond this a list of studs is not an answer, it is a wall of text.
## A 16x16 baseplate has 256 of them.
const MOST_STUDS := 40

## Studs and plates, as the model speaks them.
const STUD := 20.0
const PLATE := 8.0

## The six ways a part's studs can point. Defined on the lattice, so
## that a part laid on its side by hand and one laid on its side by the
## assistant are laid the same way.
const FACES: Dictionary = BrickLattice.FACE_AXIS

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

## Whether to read the answer as it is written. Off for anything running
## without a scene tree to wait on, and available to turn off if a
## network somewhere refuses to pass a stream through.
var stream_replies: bool = true


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
## Set when the last reply was cut off by the output limit rather than
## finished. Read where an empty design would otherwise be blamed on the
## model's geometry.
var _ran_out_of_room: bool = false
## Sections seen so far in the reply being streamed, so a brick that
## arrives before its section does is still drawn where it belongs.
var _sketching_sections: Dictionary = {}
var _turns: int = 0
var _nudges: int = 0
## Whether an edit has been applied this run. An edit is already built
## by the time it returns, so a turn that ends after one has finished
## its work rather than failed to start it.
var _edited: bool = false
## Whether the finished model has been looked at once and either
## approved or improved. One round, not a loop: a second one mostly
## fiddles.
var _looked_back: bool = false
var _shot: ModelShot
## Tokens this design has spent, as the API reports them. Reset per
## instruction, because "what did that cost" is a question about the
## thing you just asked for.
var _spend := Brain.Spend.new()
## The model that spent them, which is not necessarily the one chosen
## now: somebody who changes the setting mid-design should still be
## told what the design they ran actually cost.
var _spent_on: String = Brain.DEFAULT_MODEL
## True once this turn has put a brick of its own on the baseplate.
var _sketching: bool = false
## The reader of the answer now arriving, so that cancelling can stop
## it. cancel() used to stop _http, which during a streamed turn holds
## nothing at all — so the stream kept arriving and its bricks deleted
## the model that cancel() had just put back.
var _streaming: Streamer
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
## What the finished design cost, in tokens. Emitted whether it
## succeeded or not — a design that failed after three repairs is the
## one you most want the bill for.
signal spent(model_id: String, tokens: Brain.Spend)


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
	## Set when an edit moved this placement. Only a placement that was
	## actually moved has its transform rebuilt; rebuilding the rest
	## from a face and a turn read back off their basis would quietly
	## re-seat every brick that is not on one of the lattice's twenty
	## four orientations, as a side effect of recolouring something
	## else.
	var moved: bool = false
	## Whether the assistant placed it. A brick the person put there by
	## hand stays theirs across an edit, so that a later design replaces
	## the assistant's work and leaves theirs alone.
	var mine: bool = true
	## The section this brick belongs to, or empty for the main body.
	## Its coordinates are then that section's own, not the world's.
	var section: String = ""

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
		p.section = str(raw.get("section", "")).strip_edges()
		return p

	func where() -> String:
		return "%s,%s,%s" % [_num(x), _num(y), _num(z)]

	static func _num(value: float) -> String:
		return ("%d" % int(value) if is_equal_approx(value, round(value))
			else "%.2f" % value)


## Bricks out of an argument list that is still being written.
##
## The model sends a tool call's arguments as fragments of JSON, and
## waiting for the last of them is waiting for the whole design. Each
## complete object inside the list is one brick, and one brick is enough
## to put on the baseplate — so the model appears as it is thought of,
## rather than all at once a minute later.
##
## Nothing here parses JSON properly. It counts braces, minds quotes and
## escapes, and hands whole objects to [method JSON.parse_string], which
## does parse JSON properly. Anything it gets wrong shows up as a brick
## that does not appear early, never as a wrong brick: the real
## arguments are parsed from the whole text at the end regardless.
class Scanner extends RefCounted:
	var _text: String = ""
	var _at: int = 0
	var _depth: int = 0
	var _from: int = 0
	var _in_string: bool = false
	var _escaped: bool = false

	## Add what just arrived; get back whatever objects that completed.
	func feed(piece: String) -> Array[Dictionary]:
		_text += piece
		var out: Array[Dictionary] = []
		while _at < _text.length():
			var c: String = _text[_at]
			_at += 1
			if _in_string:
				if _escaped:
					_escaped = false
				elif c == "\\":
					_escaped = true
				elif c == "\"":
					_in_string = false
				continue
			match c:
				"\"":
					_in_string = true
				"{":
					_depth += 1
					if _depth == 2:
						_from = _at - 1
				"}":
					_depth -= 1
					# Depth two is one level inside the arguments, which
					# is where each brick of a list of them sits.
					if _depth == 1:
						var parsed: Variant = JSON.parse_string(
							_text.substr(_from, _at - _from))
						if typeof(parsed) == TYPE_DICTIONARY:
							out.append(parsed)
		return out


## A part of the model built square and then carried at an angle.
##
## This is how a real set does angled structure, and how LDraw stores
## it: the nacelle of a starship is a rigid square sub-assembly fixed to
## the hull at thirty degrees, not forty individually-angled bricks. The
## difference matters for whoever is building it — asked to place each
## brick at its own angle, the positions have to be worked out by
## trigonometry, and that is exactly the arithmetic that goes wrong.
##
## Inside a section the coordinates are ordinary studs and plates from
## the section's own corner. Where the section sits, and how far it is
## turned, is said once.
class Section extends RefCounted:
	var name: String
	var x: float = 0.0        ## studs, where the section's origin sits
	var y: float = 0.0        ## plates
	var z: float = 0.0        ## studs
	var axis: String = "z"    ## which way the hinge pin runs: x, y or z
	var degrees: float = 0.0

	static func from_dict(raw: Dictionary) -> Section:
		var s := Section.new()
		s.name = str(raw.get("name", "")).strip_edges()
		s.x = float(raw.get("x", 0))
		s.y = float(raw.get("y", 0))
		s.z = float(raw.get("z", 0))
		s.axis = str(raw.get("axis", "z")).to_lower()
		if not ["x", "y", "z"].has(s.axis):
			s.axis = "z"
		s.degrees = float(raw.get("degrees", 0))
		return s

	## Where this section sits in the world, and how it is turned.
	func placed() -> Transform3D:
		var pin := Vector3.BACK
		if axis == "x":
			pin = Vector3.RIGHT
		elif axis == "y":
			pin = Vector3.UP
		return Transform3D(Basis(pin, deg_to_rad(degrees)),
			Vector3(x * STUD, y * PLATE, z * STUD))


class Model extends RefCounted:
	var name: String = "Model"
	var description: String = ""
	var placements: Array[Placement] = []
	## Name -> Section. A placement naming one is built in that
	## section's own square coordinates and carried where it says.
	var sections: Dictionary = {}

	func section_for(placement: Placement) -> Section:
		return sections.get(placement.section)


func _ready() -> void:
	_http = HTTPRequest.new()
	# A design can take minutes of model time; the default would give up.
	_http.timeout = 300.0
	add_child(_http)


func is_busy() -> bool:
	return _busy


## Start a fresh design, discarding any conversation so far.
##
## Refused while one is running, and refused before anything is
## discarded. Clearing the conversation and then finding the loop busy
## left the worst of both: the old run still going, with no history
## behind it, appending its next turn to nothing.
##
## That shipped. The example generator gave up waiting on a boat that
## had run long, started a rocket, and the boat's loop carried on into
## the cleared history — so it went on talking about bowsprits, built
## itself again into the cleared baseplate, and was written to disk as
## the rocket. models/rocket.ldr was a boat.
func design(brief: String) -> bool:
	if _busy:
		return false
	_messages.clear()
	_start(brief)
	return true


## Whether there is a conversation to carry on, as against a fresh
## start. The panel asks before deciding which of the two below to call.
func has_conversation() -> bool:
	return not _messages.is_empty()


## Ask for a change to what is already built, keeping the conversation.
func revise(instruction: String) -> bool:
	if _busy:
		return false
	if _messages.is_empty():
		return design(instruction)
	_start(instruction)
	return true


func cancel() -> void:
	if not _busy:
		return
	_busy = false
	_http.cancel_request()
	if _streaming != null:
		_streaming.stop()
		_streaming = null
	_restore()
	finished.emit(false, "cancelled")


func _start(text: String) -> void:
	if _busy:
		return
	_busy = true
	_repairs = 0
	_turns = 0
	_nudges = 0
	_edited = false
	_looked_back = false
	_spend = Brain.Spend.new()
	_spent_on = Brain.chosen()
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
	# Only the assistant's own bricks, and only its own put back.
	#
	# Taking down everything that was not scenery and rebuilding from
	# the snapshot restores the model exactly — and destroys anything
	# placed by hand while the design was running, which is minutes,
	# during which nothing stops anyone building. Somebody adds a
	# chimney while it works on the walls, the design fails, and the
	# chimney is gone with no undo, because it was never in the
	# snapshot to be put back.
	var doomed := PackedInt64Array()
	for brick_id: int in _placed_ids + _sketched_ids:
		doomed.append(brick_id)
	for brick_id: int in doomed:
		if world.get_brick(brick_id) == null:
			continue
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()
	_sketched_ids = PackedInt64Array()

	for entry: Dictionary in _before:
		# Theirs is still standing; only the assistant's own work was
		# taken down, so only the assistant's own work goes back.
		if not bool(entry["mine"]):
			continue
		var brick_id: int = world.add_brick(
			str(entry["part"]), int(entry["colour"]), entry["at"])
		if brick_id == 0:
			continue
		builder.register(brick_id, str(entry["part"]), entry["at"])
		if bool(entry["mine"]):
			_placed_ids.append(brick_id)


func _send() -> void:
	# Cancelled, finished, or superseded while a turn was in the air.
	# _on_response already declines to act on a stale reply; this is the
	# other end of the same guard.
	if not _busy:
		return
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

	# Streamed, so the design appears as it is written rather than a
	# minute later all at once. What comes back at the end is the same
	# message a plain request would have returned, so nothing below this
	# knows the difference.
	if stream_replies:
		body["stream"] = true
		var reader := Streamer.new()
		add_child(reader)
		var scanner := Scanner.new()
		# A field, not a local captured by the lambda below.
		#
		# GDScript lambdas capture by value and copy the capture onto
		# the stack on every call, so an assignment inside one never
		# survives it. Written as a local, this flag read false on every
		# fragment, so _begin_sketch ran for every brick and took away
		# the one before it: the live build showed exactly one brick at
		# a time, all the way through, and the count reported to the
		# status bar was always 1. Nothing errored, and the finished
		# model was correct — only the feature this was written for
		# never happened.
		_sketching = false
		reader.fragment.connect(func(tool: String, piece: String) -> void:
			if tool != "submit_design" and tool != "check_design":
				return
			for raw: Dictionary in scanner.feed(piece):
				if not raw.has("part") or _edited:
					# Same reason a draft does not land after an edit:
					# what is on the baseplate is real by then.
					continue
				if not _sketching:
					_sketching = true
					_begin_sketch()
				_sketch_one(Placement.from_dict(raw),
					_sketching_sections))
		_streaming = reader
		reader.run(url, headers, JSON.stringify(body))
		var streamed: Array = await reader.done
		_streaming = null
		reader.queue_free()

		# Cancelled while it was reading. Everything below would undo
		# what cancel() has already put back.
		if not _busy:
			return

		# A connection held open for three minutes gets dropped
		# sometimes, and losing a whole design to one is not a trade
		# worth making for watching it appear. Ask again without the
		# stream, which is a shorter-lived connection and the path that
		# worked before any of this.
		if int(streamed[0]) != HTTPRequest.RESULT_SUCCESS:
			progress.emit("lost the connection — asking again")
			body.erase("stream")
			for brick_id: int in _sketched_ids:
				builder.lattice.release(brick_id)
				world.remove_brick(brick_id)
			_sketched_ids = PackedInt64Array()
			var again: Array = await _ask_again(url, headers, body)
			if again.is_empty():
				_stop(false, "could not reach the assistant after "
					+ "several tries — the last version that held "
					+ "together is still there")
				return
			_on_response(again)
			return

		_on_response(streamed)
		return

	if _http.request(url, headers, HTTPClient.METHOD_POST,
			JSON.stringify(body)) != OK:
		_stop(false, "could not reach the assistant")
		return

	var result: Array = await _http.request_completed
	_on_response(result)


## The bricks put on the baseplate as the design was written, which the
## finished design then replaces. Tracked apart from [member
## _placed_ids] so that a turn which never submits anything — a search,
## a look — leaves them be rather than half-clearing them.
var _sketched_ids: PackedInt64Array = PackedInt64Array()


func _begin_sketch() -> void:
	# The previous draft goes as the new one starts, not before: a blank
	# baseplate between two drafts reads as the model having given up.
	for brick_id: int in _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_sketched_ids = PackedInt64Array()
	for brick_id: int in _placed_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()


## One brick, the moment it is written.
##
## No collision test and no support test: this is a sketch of what is
## being proposed, and half a design does not stand up yet by
## definition. The real check runs on the whole thing.
func _sketch_one(placement: Placement,
		sections: Dictionary = {}) -> void:
	var part: Lbm.PartMesh = library.mesh_for(placement.part)
	if part == null:
		return
	var at: Transform3D = _transform(placement, part,
		sections.get(placement.section))
	var brick_id: int = world.add_brick(placement.part, placement.color, at)
	if brick_id == 0:
		return
	builder.register(brick_id, placement.part, at)
	_sketched_ids.append(brick_id)
	sketched.emit(_sketched_ids.size())


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
	var choice: Brain.Choice = Brain.find(Brain.chosen())
	# As much as the chosen model will write, when the reply is
	# streamed.
	#
	# A flat 16,000 was about 380 bricks of placements — and a set is
	# five hundred to two thousand. Nothing built here had ever been
	# bigger than that, and it read as a matter of taste rather than an
	# envelope, because a design that ran over came back as a model with
	# no parts in it.
	#
	# Lower when the reply is not streamed, because that is the fallback
	# path for a connection that already dropped once, and a reply that
	# takes minutes to arrive in one piece is how it drops again.
	var body: Dictionary = {
		"model": choice.id,
		"max_tokens": choice.most_out if stream_replies
			else mini(choice.most_out, 16000),
		"system": _system_prompt(),
		"messages": _messages,
		"tools": _tools(),
	}
	# Only where the model takes it. Haiku refuses adaptive thinking and
	# refuses the effort parameter, each with a 400 — so sending either
	# unconditionally turns choosing the quick model into choosing a
	# broken assistant.
	if choice.effort and not Brain.effort().is_empty():
		body["output_config"] = {"effort": Brain.effort()}
	if not key_in_use().is_empty():
		# The proxy asks for thinking itself; here we are the client.
		if choice.adaptive:
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
		var detail: String = _what_went_wrong(code)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			var err: Variant = parsed["error"]
			detail = (str(err.get("message", err))
				if typeof(err) == TYPE_DICTIONARY else str(err))
		_stop(false, detail)
		return

	var response: Dictionary = parsed
	if response.has("usage"):
		_spend.add(response["usage"])
	if response.get("stop_reason", "") == "refusal":
		_stop(false, "the assistant declined this request")
		return

	# A reply that ran out of room mid-sentence.
	#
	# The half-written tool call that comes back parses as a design with
	# no parts in it, so the model was told its geometry was empty and
	# spent a repair on a fault that was not there. Three of those ended
	# the run. Saying what actually happened costs nothing, and is the
	# one thing that lets it answer by building in stages instead.
	if response.get("stop_reason", "") == "max_tokens":
		_ran_out_of_room = true

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
		if _pending != null:
			_stop(true, "done")
			return
		# It looked, and had nothing to change. What is on the baseplate
		# is the design it submitted a moment ago.
		if _looked_back and not _placed_ids.is_empty():
			_stop(true, "%d bricks" % _placed_ids.size())
			return
		# An edit that landed is a finished piece of work. Without this
		# a run that changed the model and then said so was nudged to
		# build something, twice, and then recorded as having built
		# nothing — with the change sitting on the baseplate.
		if _edited:
			_stop(true, "%d bricks" % world.brick_count())
			return
		# Nothing called and nothing submitted. Taken as "it has finished
		# talking", which it is not: a run that looked up five parts,
		# said what it was going to build and stopped was recorded as a
		# finished design of nothing at all. Ask once, then twice, then
		# accept that it is not going to.
		if _nudges >= MAX_NUDGES:
			_stop(false, "stopped without building anything")
			return
		_nudges += 1
		_messages.append({
			"role": "user",
			"content": ("Nothing has been built yet. Place the parts and "
				+ "call submit_design. If the request cannot be built "
				+ "out of bricks, say why instead."),
		})
		_send()
		return

	_forget_old_pictures()
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
		if not _busy:
			return
		# One deliberate look before it is finished.
		#
		# A design stops the moment it holds together, and holding
		# together is not the bar. The house that came out of this was
		# checked, stood up, weighed a hundred grams and had a blank
		# wall where the brief had asked for a door and two windows; the
		# boat was a white box with a staircase for a sail. Both passed
		# every test there is, because every test there is asks whether
		# it is buildable and none asks whether it is the thing.
		#
		# So the last round is a look at what was built, with the
		# failures that keep happening named. It costs one turn, and one
		# turn is cheap against a model nobody would want.
		if not _looked_back:
			_looked_back = true
			_pending = null
			progress.emit("looking at the finished model")
			var shown: Variant = await _from_both_sides(
				_will_it_hold(), CRITIQUE)
			# Cancelled while the picture was being taken. An empty
			# message is one the API refuses, so there would be nothing
			# to show for it but an error.
			if not _busy or (shown is String and (shown as String).is_empty()):
				return
			_messages.append({"role": "user", "content": shown})
			_send()
			return
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


## Whether the finished model would survive being picked up.
##
## check_design asks whether every part is held by something. That is a
## different question from whether the thing holds together: a tower of
## plates on one stud passes it, and a tree whose canopy hangs out past
## its trunk passes it, and both come apart in the hand.
##
## The app has always worked this out and shown it in the corner — one
## of the models that ships says "1 weak joint (top-heavy)" — and the
## assistant was never told. It is told at the end, where the model is
## real and in the world and the numbers mean something.
func _will_it_hold() -> String:
	if world == null or world.brick_count() == 0:
		return ""
	var judge := Stability.new()
	judge.library = library
	# The same lattice the builder keeps, because that is where what
	# rests on what is recorded. Without it every brick reads as
	# carrying nothing.
	judge.lattice = builder.lattice
	var report: Stability.Report = judge.check(world)
	if report.is_stable():
		return "It holds together: %s." % report.summary()

	var said: PackedStringArray = PackedStringArray()
	for risk: Stability.Risk in report.risks.slice(0, 3):
		said.append("  " + risk.message)
	return ("It does not hold together — %s.\n%s\n\nThat is a real "
		% [report.summary(), "\n".join(said)]
		+ "fault and worth fixing before anything else: spread the "
		+ "load over more studs, or move weight back over what carries "
		+ "it.")


## What to ask once the thing is built.
##
## Named failures, not "does it look right". Every one of these came
## out of looking at models this assistant actually produced, and a
## general question got a general answer — the house was declared good
## in the same breath as its blank front wall.
const CRITIQUE := """This is what you built. It holds together; that \
was never the question. Look at it and answer one: is this the thing \
you were asked for?

Four things go wrong here over and over. Check for each of them by \
name:
  A surface built as a staircase that should be smooth or sloped. \
Steps of plain bricks where a roof, a hull, a nose or a wing should \
run — use slopes, curved slopes and wedges.
  A face left blank. A wall with nothing on it, when the brief asked \
for a door or a window, or when every other face has something.
  A shape that should taper or curve, built as a box.
  Detail that cannot be seen: a colour against the same colour, or \
something hidden inside the model.

If any of those is true, fix it with edit_model and say what you \
changed. If it is genuinely right, say so in one line and stop — do \
not submit it again."""


## Something a person can act on, rather than a number.
##
## Every failure that never reached a server came back as "HTTP 0",
## because that is the code an unsent request has. Which is to say: a
## flat network, a wrong key, a blocked request and a machine that is
## simply offline all read the same, and none of them read as anything.
static func _what_went_wrong(code: int) -> String:
	match code:
		0:
			return ("Could not reach the assistant. Check the "
				+ "connection and try again — nothing was spent.")
		401, 403:
			return ("That key was refused. Check it at "
				+ "console.anthropic.com, or sign in instead.")
		404:
			return "The assistant is not reachable at that address."
		413:
			return ("This conversation has grown too large to send. "
				+ "Start a new one with New.")
		429:
			return ("Too many requests at once, or the key is out of "
				+ "credit. Wait a moment and try again.")
		500, 502, 503, 504:
			return ("Anthropic is having trouble at the moment. "
				+ "Nothing was spent; try again shortly.")
		529:
			return "Anthropic is overloaded. Try again shortly."
	return "The assistant answered with an error (HTTP %d)." % code


## End the run, putting the model back if nothing came of it.
##
## Nothing came of it is the important qualification. An edit that has
## been checked and applied is built and is the person's model now; a
## connection dropped two minutes later does not make it not have
## happened. Restoring over it threw away a hundred and forty bricks
## that were sitting on the baseplate at the time.
func _stop(ok: bool, summary: String) -> void:
	# A design that failed leaves the model it was asked to change
	# exactly as it found it. Without this a revision that ran out of
	# repairs took the original with it — and the drafts shown along the
	# way are what removed it.
	if not ok and not _edited:
		_restore()
	# Anything the sketch left standing is not a model; the finished one
	# either replaced it or never came. Skipping this when an edit had
	# landed left those bricks behind, and the next run's snapshot
	# adopted them as bricks the person had placed by hand.
	for brick_id: int in _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_sketched_ids = PackedInt64Array()
	_busy = false

	# A failed design that started from a bare baseplate has nothing to
	# restore to, so its last checked draft is still standing. Better
	# than an empty baseplate, and worth saying rather than reporting
	# that nothing happened.
	if not ok and not _placed_ids.is_empty():
		summary += " — the last version that held together is still there"
	if not _spend.is_empty():
		spent.emit(_spent_on, _spend)
	finished.emit(ok, summary)


# -- tools ---------------------------------------------------------------


## What a tool hands back.
##
## A String for most of them. An Array of content blocks when the answer
## includes a picture, which Anthropic accepts in a tool result exactly
## as it does in a message.
func _run_tool(block: Dictionary) -> Variant:
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
			# Only while composing. Once an edit has landed, the model
			# on the baseplate is the person's model, and a check of
			# fifteen bricks would replace the hundred and forty that
			# are standing — and report it as a successful check.
			if not trial.placements.is_empty() and not _edited:
				_apply(trial, false)
			progress.emit("checked %d bricks: %s" % [
				trial.placements.size(), report["summary"]])
			# With the drawing, not merely offered alongside it. Given
			# view_model as a tool of its own, a design would check its
			# work three times and never once look at it — which is how
			# a house gets built with a door in the roof and passes
			# every test, because no test is about whether it looks like
			# a house. The picture has to arrive whether or not anyone
			# thought to ask for it.
			if trial.placements.is_empty():
				return report["feedback"]
			return await _with_a_look(str(report["feedback"]),
				"Look at it. Does it read as the thing it is meant to "
				+ "be? If not, that is worth more than another brick. "
				+ "view_model gives any other side.")
		"attachment_points":
			progress.emit("working out where things attach")
			return _attachment_points(args)
		"look_at_model":
			progress.emit("looking at what is already built")
			return _describe_world(args)
		"view_model":
			var from: String = str(args.get("from", "corner"))
			progress.emit("looking at the %s" % from)
			# Of what is in the world, which during a design is the
			# last draft it checked — so this is its own work, not a
			# hypothetical.
			return await _with_a_look("", "", from)
		"edit_model":
			var edited: Model = _edit(args)
			if _touched == 0:
				# Nothing changed, and saying "done" to that ends the
				# run as a success with the model untouched.
				if _unknown.is_empty():
					return ("Nothing in that changed anything. Check "
						+ "the brick numbers against look_at_model.")
				return ("No brick has %s. Call look_at_model — the "
					% _numbers(_unknown)
					+ "numbers change when a model is opened or rebuilt.")
			if edited.placements.is_empty():
				return ("That would leave the baseplate empty. "
					+ "If clearing it is what you meant, say so instead.")
			await _ensure_parts(edited)
			var verdict: Dictionary = _check(edited, true)
			if not bool(verdict["ok"]):
				progress.emit("tried a change: %s" % verdict["summary"])
				return ("Not applied — the model would not hold together.\n"
					+ str(verdict["feedback"]))
			_apply_edit(edited)
			_pending = null
			_edited = true
			progress.emit("changed it: %d bricks" % edited.placements.size())
			var said: String = "Done. %d bricks now." % edited.placements.size()
			if not _unknown.is_empty():
				said += " No brick has %s, so those were left alone." \
					% _numbers(_unknown)
			return await _with_a_look(said,
				"That is what it looks like now.")
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
	# The sketch counts as the assistant's. Those bricks are on the
	# baseplate with numbers of their own, so an edit can name one; if
	# they were treated as somebody else's work they would survive every
	# later design as orphans nobody could account for.
	var mine: Dictionary = {}
	for brick_id: int in _placed_ids + _sketched_ids:
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
		placement.face = BrickLattice.face_of(brick.transform.basis)
		placement.rot = BrickLattice.turns_about(brick.transform.basis, placement.face)
		placement.id = brick.id
		placement.mine = mine.has(brick.id)
		model.placements.append(placement)
	return model


## Apply a patch to what is built, and say what it came to.
##
## Removals first, so that a brick can be taken away and another put in
## its place in one call without the two fighting over the same cells.
## What an edit asked for that was not there. Filled by [method _edit],
## read by whoever reports the result: an edit that named forty bricks
## and found none of them used to come back as "Done", with nothing
## changed and the run ended as a success.
var _unknown: PackedInt64Array = PackedInt64Array()
## How many changes an edit actually made.
var _touched: int = 0


func _edit(args: Dictionary) -> Model:
	var model: Model = _model_from_world()
	var by_id: Dictionary = {}
	for placement: Placement in model.placements:
		by_id[placement.id] = placement
	_unknown = PackedInt64Array()
	_touched = 0

	var gone: Dictionary = {}
	for raw: Variant in args.get("remove", []):
		if not by_id.has(int(raw)):
			_unknown.append(int(raw))
			continue
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
			if placement == null:
				_unknown.append(int(id_raw))
			elif placement.color != colour:
				placement.color = colour
				_touched += 1

	for raw: Variant in args.get("move", []):
		var order: Dictionary = raw
		var by := Vector3(float(order.get("dx", 0)),
			float(order.get("dy", 0)), float(order.get("dz", 0)))
		for id_raw: Variant in order.get("bricks", []):
			var placement: Placement = by_id.get(int(id_raw))
			if placement == null:
				_unknown.append(int(id_raw))
			elif by != Vector3.ZERO:
				placement.x += by.x
				placement.y += by.y
				placement.z += by.z
				placement.moved = true
				_touched += 1

	# An edit may add sections, or move one that is already there —
	# which is how a hinged part gets opened further without every
	# brick in it being described again.
	for raw: Variant in args.get("sections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var section: Section = Section.from_dict(raw)
		if section.name.is_empty():
			continue
		model.sections[section.name] = section
		for placement: Placement in model.placements:
			if placement.section == section.name:
				placement.moved = true
		_touched += 1

	for raw: Variant in args.get("add", []):
		model.placements.append(Placement.from_dict(raw))
		_touched += 1
	_touched += gone.size()
	return model


## Drop every picture but the one about to be sent.
##
## A rendering is a hundred kilobytes, and base64 makes it a hundred and
## forty. The conversation is sent in full on every turn, so ten views
## over a long design is a megabyte and a half going down the wire forty
## times — for nine pictures of drafts that no longer exist.
##
## What the model is looking at is the latest one. The others are
## replaced by a line saying there was one, which keeps the transcript
## honest about what it saw without carrying the pixels.
func _forget_old_pictures() -> void:
	for message: Dictionary in _messages:
		var content: Variant = message.get("content")
		if typeof(content) != TYPE_ARRAY:
			continue
		for n: int in (content as Array).size():
			var block: Variant = content[n]
			if typeof(block) != TYPE_DICTIONARY:
				continue
			if block.get("type", "") == "image":
				content[n] = {"type": "text",
					"text": "(a view of an earlier draft)"}
				continue
			# A tool result carries its own list of blocks.
			var inner: Variant = block.get("content")
			if typeof(inner) != TYPE_ARRAY:
				continue
			for m: int in (inner as Array).size():
				var piece: Variant = inner[m]
				if (typeof(piece) == TYPE_DICTIONARY
						and piece.get("type", "") == "image"):
					inner[m] = {"type": "text",
						"text": "(a view of an earlier draft)"}


## An answer with a picture of the model attached, or with the model
## drawn as letters when there is no way to take one.
##
## Letters were a great deal better than nothing and are what a headless
## run still gets. But a design is judged on whether it reads as the
## thing it is meant to be, and that is a question about a picture. A
## rendering is also cheaper than the two elevations it replaces.
## The same, from both three-quarters.
##
## One corner shows two faces of a model and hides the other two, which
## is how a house was judged good with a blank front wall. Two opposite
## corners between them show all four.
func _from_both_sides(said: String, ask: String) -> Variant:
	if _shot == null:
		_shot = ModelShot.new()
		add_child(_shot)
	var near: Dictionary = await _shot.block(world, "corner", scenery)
	if not _busy:
		return ""
	var far: Dictionary = await _shot.block(world, "far corner", scenery)
	if not _busy:
		return ""
	if near.is_empty() or far.is_empty():
		# No pictures to be had, so fall back to the letters — which
		# draw the plan and an elevation and hide nothing.
		return await _with_a_look(said, ask)

	var blocks: Array = []
	if not said.is_empty():
		blocks.append({"type": "text", "text": said})
	blocks.append({"type": "text", "text": "From one corner:"})
	blocks.append(near)
	blocks.append({"type": "text", "text": "And from the opposite one, "
		+ "so that every side has been seen:"})
	blocks.append(far)
	if not ask.is_empty():
		blocks.append({"type": "text", "text": ask})
	return blocks


func _with_a_look(said: String, ask: String,
		from: String = "corner") -> Variant:
	if _shot == null:
		_shot = ModelShot.new()
		add_child(_shot)

	var picture: Dictionary = await _shot.block(world, from, scenery)
	# Cancelled while the picture was being taken. Saying anything now
	# would be answering a turn that no longer exists.
	if not _busy:
		return ""
	if picture.is_empty():
		var elevation: String = "front" if from in ["corner", "top"] else from
		var drawn: String = "%s\n%s" % [
			ModelView.draw(world, library, "top", scenery),
			ModelView.draw(world, library, elevation, scenery)]
		var parts := PackedStringArray()
		for piece: String in [said, drawn, ask]:
			if not piece.strip_edges().is_empty():
				parts.append(piece)
		return "\n\n".join(parts)

	var blocks: Array = []
	if not said.is_empty():
		blocks.append({"type": "text", "text": said})
	blocks.append({"type": "text", "text": "The model, from the %s:" % from})
	blocks.append(picture)
	if not ask.is_empty():
		blocks.append({"type": "text", "text": ask})
	return blocks


## Where a part's studs are, and what coordinates something on one of
## them would take.
##
## Built because the arithmetic is the hard part and there is no reason
## anyone should have to do it. A stud on the side of an 87087 sits at
## 14 LDU above the brick's base, which is one and three quarter plates,
## and the plate that clutches it therefore starts half a plate up.
## Nobody works that out reliably from a description, and getting it
## wrong is not a wonky model — it is a part that touches nothing and a
## design that comes back refused.
##
## Answers for a brick that is already placed, or for one that is not
## yet: planning a wall means knowing where its studs will be before
## committing to it.
func _attachment_points(args: Dictionary) -> String:
	var at: Transform3D
	var part_id: String
	var label: String

	if args.has("brick"):
		var brick_id: int = int(args["brick"])
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return "There is no brick numbered %d." % brick_id
		if scenery.has(brick_id):
			return ("Brick %d is the baseplate, not part of the model. "
				% brick_id + "It has a stud everywhere; build on it by "
				+ "putting parts at y=0.")
		at = brick.transform
		part_id = brick.part_id
		label = "brick %d (%s)" % [brick_id, part_id]
	else:
		part_id = str(args.get("part", ""))
		if not library.parts.has(part_id):
			return "No part '%s' exists." % part_id
		var hypothetical := Placement.from_dict(args)
		var mesh: Lbm.PartMesh = library.mesh_for(part_id)
		if mesh == null:
			return "The geometry for %s has not arrived yet." % part_id
		at = _transform(hypothetical, mesh)
		label = "%s at %s facing %s" % [
			part_id, hypothetical.where(), hypothetical.face]

	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return "The geometry for %s has not arrived yet." % part_id

	var lines := PackedStringArray()
	var found: int = 0
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var point: Vector3 = at * connector.position
		var axis: Vector3 = (at.basis * connector.axis).normalized()
		# A part sitting on this stud has its own up along the stud, so
		# the face it takes is simply the direction the stud points.
		var face: String = "up"
		var best: float = -2.0
		for name: String in FACES:
			var d: float = axis.dot(FACES[name])
			if d > best:
				best = d
				face = name
		var corner: Vector3 = _corner_on(point, axis, face)
		lines.append("  stud %d points %-4s — a 1x1 plate goes at "
			% [found, face]
			+ "x=%s y=%s z=%s face=%s" % [
				Placement._num(corner.x / STUD),
				Placement._num(corner.y / PLATE),
				Placement._num(corner.z / STUD), face])
		found += 1

	if found > MOST_STUDS:
		return ("%s has %d studs, which is too many to list. " % [label, found]
			+ "It is a flat field of them: anything sitting on top goes "
			+ "at whole studs across and at the height of its top face.")
	if found == 0:
		return ("%s has no studs — nothing clutches to it. " % label
			+ "Tiles and most sloped surfaces are like this.")
	return ("%s has %d stud%s.\n" % [label, found, "" if found == 1 else "s"]
		+ "\n".join(lines)
		+ "\n\nThose corners are for a 1x1 plate. A part that covers "
		+ "more studs extends from the same corner, the way it would on "
		+ "the ground. A part that is thicker than a plate is the same "
		+ "on a stud pointing up, +x or +z — but on one pointing down, "
		+ "-x or -z it hangs the other way, so its corner is further "
		+ "back along that direction by its own thickness: a brick is "
		+ "three plates, so three plates or one and a half studs.")


## Where a 1x1 plate's low corner falls if it clutches this stud.
##
## Across the two directions the stud does not point along, it is
## centred: half a stud either side. Along the stud it starts at the
## stud and grows away from it — which for a stud pointing down or left
## means the corner is a plate's thickness back, because the corner is
## the low end and the part is on the high side of it.
##
## That last case was wrong and every sideways attachment on a negative
## face came back as an overlap with the very brick it was clutching.
func _corner_on(point: Vector3, axis: Vector3, face: String) -> Vector3:
	# Measured, not assumed: this file has been wrong before about how
	# thick a plate is and in which units.
	var thickness: float = PLATE
	var plate: Lbm.PartMesh = library.mesh_for("3024")
	if plate != null:
		var basis: Basis = BrickLattice.basis_for(face, 0)
		var lo: int = 0x7FFFFFFF
		var hi: int = -0x7FFFFFFF
		for cell: Vector3i in builder._cells_for(
				plate, Transform3D(basis, Vector3.ZERO)):
			var along: int = int(round(Vector3(cell).dot(axis)))
			lo = mini(lo, along)
			hi = maxi(hi, along + 1)
		thickness = float(hi - lo) * BrickLattice.CELL

	# Positive: the part starts at the stud. Negative: the part is on
	# the far side of the stud from its own low corner, so the corner is
	# its thickness back.
	var back: float = 0.0 if axis.x + axis.y + axis.z > 0.0 else thickness
	var half: float = STUD * 0.5
	return Vector3(
		point.x - (back if absf(axis.x) > 0.5 else half),
		point.y - (back if absf(axis.y) > 0.5 else half),
		point.z - (back if absf(axis.z) > 0.5 else half))


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
## Whether a placement is inside the section that was asked about.
## An empty box means the whole model.
static func _inside(at: Vector3, where: Dictionary) -> bool:
	if where.is_empty():
		return true
	for pair: Array in [["x_from", "x_to", at.x], ["y_from", "y_to", at.y],
			["z_from", "z_to", at.z]]:
		var value: float = float(pair[2])
		if where.has(pair[0]) and value < float(where[pair[0]]):
			return false
		if where.has(pair[1]) and value > float(where[pair[1]]):
			return false
	return true


func _describe_world(args: Dictionary = {}) -> String:
	if world == null or world.brick_count() <= scenery.size():
		return "The baseplate is empty. Nothing is built yet."

	var mine: Dictionary = {}
	for brick_id: int in _placed_ids:
		mine[brick_id] = true

	var rows := PackedStringArray()
	var tally: Dictionary = {}
	var low := Vector3(999999, 999999, 999999)
	var high := Vector3(-999999, -999999, -999999)
	var counted: int = 0
	var matched: int = 0
	var where: Dictionary = args.get("where", {}) if typeof(
		args.get("where")) == TYPE_DICTIONARY else {}
	var skip: int = maxi(int(args.get("skip", 0)), 0)

	for brick: BrickWorld.Brick in world.bricks():
		# The baseplate is a brick like any other and is 32 studs
		# across. Listing it gave the model a part with a brick number,
		# a negative y and a bounding box wider than anything on it —
		# and then invited it to move or remove the workspace. Both
		# _snapshot and _model_from_world already skip scenery; this
		# was the one that did not.
		if scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var at: Vector3 = _to_studs(brick, info)
		low = Vector3(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z))
		high = Vector3(maxf(high.x, at.x), maxf(high.y, at.y), maxf(high.z, at.z))

		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		tally[key] = int(tally.get(key, 0)) + 1
		counted += 1

		# Outside the section being worked on.
		#
		# Counted and tallied first, so the totals and the span always
		# describe the whole model however narrow the question — a
		# section listed as though it were everything is how a model
		# rebuilds something it already has.
		if not _inside(at, where):
			continue
		matched += 1
		if matched <= skip:
			continue

		# Capped. A four-hundred brick model listed in full is most of a
		# context window spent on something the model mostly needs the
		# shape of, and the tally below carries what the rows drop.
		if rows.size() < WORLD_ROWS:
			var face: String = BrickLattice.face_of(brick.transform.basis)
			rows.append("  #%-4d %-9s c%-3d x=%-6s y=%-6s z=%-6s %s rot=%d%s" % [
				brick.id, brick.part_id, brick.color_code,
				Placement._num(at.x), Placement._num(at.y),
				Placement._num(at.z), face,
				BrickLattice.turns_about(brick.transform.basis, face),
				"" if mine.has(brick.id) else "   (placed by hand)"])

	var lines := PackedStringArray()
	lines.append("%d parts are on the baseplate." % counted)
	if not where.is_empty() or skip > 0:
		lines.append("%d of them are in the part you asked about%s."
			% [matched, "" if skip == 0 else ", of which %d skipped" % skip])
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
		# And how to see them, which is the whole difference between a
		# model that can be finished and one that cannot. A set-sized
		# build never fits in one listing, so the way through is to ask
		# for one section at a time rather than to give up on the rest.
		var left: int = matched - skip - rows.size()
		lines.append("  … %d more here, not listed. Ask again with "
			% left + "skip=%d to go on, or with where={x_from,x_to,"
			% (skip + rows.size())
			+ "z_from,z_to,y_from,y_to} in studs and plates to work on "
			+ "one section at a time.")
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
	_read_sections(model, args)
	for raw: Variant in args.get("bricks", []):
		model.placements.append(Placement.from_dict(raw))
	return model


## The sections a model declares, before any brick refers to one.
static func _read_sections(model: Model, args: Dictionary) -> void:
	for raw: Variant in args.get("sections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var section: Section = Section.from_dict(raw)
		if not section.name.is_empty():
			model.sections[section.name] = section


# -- validation ----------------------------------------------------------


## Check a proposed design against the real lattice.
##
## Runs on a scratch lattice rather than the live one, so a failing
## design never half-lands in the scene. Everything the app knows about
## collision is used here; nothing is approximated for the model's sake.
## Check a design against the real rules.
##
## ``alone`` says the model is the whole of what will be on the
## baseplate — which is true of an edit, since an edit is built from a
## reading of everything there. A submission is not: it replaces the
## assistant's work and leaves what the person placed by hand standing,
## so those bricks have to be in the lattice or a design can be declared
## buildable while sitting inside one of them.
func _check(model: Model, alone: bool = false) -> Dictionary:
	var lattice := BrickLattice.new()
	var issues: Dictionary = {}     ## kind -> Array[String]
	var cells_of: Dictionary = {}   ## index -> Array[Vector3i]

	if model.placements.is_empty():
		# Which of the two this is matters enormously.
		#
		# A reply cut off by the output limit arrives as a tool call
		# that stops mid-placement, and what survives parsing is a
		# design with nothing in it. Told "no parts", the model looks
		# for the fault in its geometry, finds none, and spends a repair
		# on it; three of those end the run. It is not a geometry fault
		# at all — the design was too long to say in one reply.
		if _ran_out_of_room:
			_ran_out_of_room = false
			return {
				"ok": false,
				"summary": "cut off",
				"feedback": "That reply hit the length limit part way "
					+ "through, so nothing of the design arrived. It is "
					+ "not wrong, it is too long to send in one piece. "
					+ "Submit the structure first and add the rest with "
					+ "edit_model, a few dozen bricks at a time.",
			}
		return {
			"ok": false,
			"summary": "no bricks",
			"feedback": "That design has no parts in it.",
		}

	# What will still be there afterwards, standing in the way.
	var theirs: Dictionary = {}     ## lattice key -> part id
	if not alone and world != null:
		var mine: Dictionary = {}
		for brick_id: int in _placed_ids + _sketched_ids:
			mine[brick_id] = true
		var key: int = -1
		for brick: BrickWorld.Brick in world.bricks():
			if mine.has(brick.id) or scenery.has(brick.id):
				continue
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null:
				continue
			lattice.occupy(key, builder._cells_for(part, brick.transform))
			theirs[key] = brick.part_id
			key -= 1

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

		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
		var cells: Array[Vector3i] = builder._cells_for(part, at)
		var blockers: PackedInt64Array = lattice.blockers(cells)
		if not blockers.is_empty():
			# The lattice numbers from one, because zero means empty,
			# and negative keys are bricks that were already there. Both
			# were printed raw beside a zero-based list index, so a
			# brick was told it overlapped itself.
			var blocker: int = blockers[0]
			var who: String = (
				"a %s already on the baseplate" % theirs[blocker]
				if theirs.has(blocker) else "brick %d" % (blocker - 1))
			# And where the thing it hit actually ends.
			#
			# "overlaps brick 3" leaves the arithmetic to be redone by
			# whoever reads it, and the arithmetic is the part that goes
			# wrong: y counts plates, a brick is three of them, so the
			# course above a brick at y=6 starts at y=9 and not at y=7.
			# A design that got that wrong concluded the checker mangled
			# rotated parts — because the part it had turned was the one
			# that came back refused — and rebuilt a windmill with no
			# rotation at all, so it had no sails. Saying where the next
			# course starts costs nothing and removes the guess.
			_note(issues, "overlap",
				"brick %d (%s at %s) overlaps %s%s" % [
					index, placement.part, placement.where(), who,
					_ends_at(cells_of.get(blocker - 1))])
			continue

		lattice.occupy(index + 1, cells)
		cells_of[index] = cells

	# Support is checked in world coordinates even for a section that
	# has been carried somewhere at an angle, and that is not an
	# oversight.
	#
	# "Something in the cell below" would indeed be the wrong question
	# for a turned section — the brick above another one can end up
	# beside it, or under it. But that is only the cheap half of the
	# rule. The other half asks the part library where this brick's
	# studs actually are and which way they point, reading both off the
	# real transform, and that half does not care which way round the
	# section is. A stack hinged right over is still a stack.
	#
	# Checking each section again in its own square frame was written
	# and then taken out: across shallow angles, steep ones and a
	# section turned fully over, it never once changed an answer.

	_check_support(model, cells_of, lattice, issues)

	# Every section has to be fixed to something outside itself.
	# Held together inside and touching nothing is a part that falls off
	# when the model is picked up, which is the one thing a section
	# makes easy to do by accident.
	_check_sections_attached(model, cells_of, lattice, issues)

	var pieces: int = _count_pieces(model, cells_of, lattice)

	var errors: int = 0
	for kind: String in issues:
		errors += issues[kind].size()

	var ok: bool = errors == 0 and not model.placements.is_empty()
	var summary: String = ("%d bricks, buildable" % model.placements.size()
		if ok else "%d problem%s" % [errors, "" if errors == 1 else "s"])

	var feedback: String = _feedback(issues, summary)
	# Said, never counted.
	#
	# Both the tool description and the prompt promised that a design is
	# checked for being in one piece, and nothing in this file computed
	# it. Now it does — but as a remark rather than an error, because a
	# model in two pieces is often exactly what was asked for (a boat
	# and a jetty, a tree beside a house) and failing it would throw
	# away a design that is otherwise correct.
	if pieces > 1:
		feedback += ("\n\nIt is in %d separate pieces that do not touch "
			% pieces
			+ "each other. Intended, if it is meant to be a scene; worth "
			+ "a look otherwise, because a part of a model that touches "
			+ "nothing falls off when it is picked up.")

	return {
		"ok": ok,
		"summary": summary,
		"feedback": feedback,
		"pieces": pieces,
	}


## How many separate pieces the design is in.
##
## Two bricks are in the same piece when one occupies a cell directly
## above a cell of the other, or when a stud of one reaches into the
## other — the same two rules that decide whether a brick is held up,
## so a design cannot be "every brick supported" and "in five pieces"
## for contradictory reasons.
func _count_pieces(model: Model, cells_of: Dictionary,
		lattice: BrickLattice) -> int:
	if cells_of.size() <= 1:
		return cells_of.size()

	var joined: Dictionary = {}   ## index -> Array of index
	for index: int in cells_of:
		joined[index] = []
	for index: int in cells_of:
		for cell: Vector3i in cells_of[index]:
			var above: int = lattice.brick_at(
				Vector3i(cell.x, cell.y + 1, cell.z))
			if above != 0 and above - 1 != index and joined.has(above - 1):
				joined[index].append(above - 1)
				joined[above - 1].append(index)

	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var tip: Vector3 = at * (connector.position
				+ connector.axis.normalized() * 5.0)
			var reached: int = lattice.brick_at(BrickLattice.to_cell(tip))
			if reached != 0 and reached - 1 != index and joined.has(reached - 1):
				joined[index].append(reached - 1)
				joined[reached - 1].append(index)

	var seen: Dictionary = {}
	var pieces: int = 0
	for start: int in cells_of:
		if seen.has(start):
			continue
		pieces += 1
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var here: int = stack.pop_back()
			for next: int in joined[here]:
				if not seen.has(next):
					seen[next] = true
					stack.append(next)
	return pieces


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
		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
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


## Where a brick stops, in the units the placement was written in.
##
## Returns a clause to hang off an overlap message, or nothing at all
## when the brick that was hit is one already on the baseplate rather
## than one of these placements.
static func _ends_at(cells: Variant) -> String:
	if typeof(cells) != TYPE_ARRAY or (cells as Array).is_empty():
		return ""
	var low: int = (cells[0] as Vector3i).y
	var high: int = low
	for cell: Vector3i in cells:
		low = mini(low, cell.y)
		high = maxi(high, cell.y)
	var from_y: float = float(low) / BrickLattice.CELLS_PER_PLATE
	var to_y: float = float(high + 1) / BrickLattice.CELLS_PER_PLATE
	return ", which fills y=%s up to y=%s — so the course above it starts at y=%s" % [
		_tidy(from_y), _tidy(to_y), _tidy(to_y)]


## A number without a pointless decimal point.
static func _tidy(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, floor(value)) \
		else str(snappedf(value, 0.01))


## Ask again, more than once, before losing the whole design.
##
## A design runs for twenty minutes and holds each connection open for
## up to three, so a blip somewhere in the middle is ordinary rather
## than exceptional. Giving up on the first one threw away everything
## built so far — twenty-four minutes and a finished windmill, one
## revision short of done, because a socket closed.
##
## The pause grows between tries, because a network that has just
## failed is not ready again a millisecond later.
func _ask_again(url: String, headers: PackedStringArray,
		body: Dictionary) -> Array:
	for attempt: int in TRIES_WHEN_DROPPED:
		if not _busy:
			return []
		if attempt > 0:
			progress.emit("still trying — attempt %d of %d"
				% [attempt + 1, TRIES_WHEN_DROPPED])
			await get_tree().create_timer(2.0 * float(attempt)).timeout
			if not _busy:
				return []
		if _http.request(url, headers, HTTPClient.METHOD_POST,
				JSON.stringify(body)) != OK:
			continue
		var result: Array = await _http.request_completed
		if int(result[0]) == HTTPRequest.RESULT_SUCCESS:
			return result
	return []


## Which sections actually have bricks in this model, main body first.
static func _sections_present(model: Model, cells_of: Dictionary) -> Array:
	var seen: Dictionary = {"": true}
	for index: int in cells_of:
		seen[model.placements[index].section] = true
	var names: Array = seen.keys()
	names.sort()
	return names


## Every section must touch something that is not itself.
##
## Inside a section the bricks hold each other, and that check passes
## whether or not the section is fixed to anything — so a nacelle can be
## perfectly built and floating a stud clear of the hull, and every
## other check will say the model is fine.
func _check_sections_attached(model: Model, cells_of: Dictionary,
		lattice: BrickLattice, issues: Dictionary) -> void:
	for group: String in _sections_present(model, cells_of):
		if group.is_empty():
			continue
		var touches: bool = false
		var lowest: int = 0x7FFFFFFF
		for index: int in cells_of:
			if model.placements[index].section != group:
				continue
			for cell: Vector3i in cells_of[index]:
				lowest = mini(lowest, cell.y)
				for step: Vector3i in BrickLattice.NEIGHBOURS:
					var who: int = lattice.brick_at(cell + step)
					if who == 0:
						continue
					if who < 0:
						touches = true
						break
					if model.placements[who - 1].section != group:
						touches = true
						break
				if touches:
					break
			if touches:
				break
		# Standing on the ground counts as being fixed to something.
		if not touches and lowest > 0:
			_note(issues, "section adrift",
				"section '%s' is not touching anything outside itself "
					% group + "— it is built, but it would fall off. "
					+ "Move it so it meets the part it is fixed to.")


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


## "number 12" or "numbers 12, 14 and 15", capped so a confused edit
## does not answer with three hundred of them.
static func _numbers(ids: PackedInt64Array) -> String:
	var shown: PackedStringArray = PackedStringArray()
	for n: int in mini(ids.size(), 8):
		shown.append(str(ids[n]))
	var more: String = (", and %d others" % (ids.size() - 8)
		if ids.size() > 8 else "")
	if shown.size() == 1:
		return "number %s" % shown[0]
	return "numbers %s%s" % [", ".join(shown), more]


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
func _transform(placement: Placement, part: Lbm.PartMesh,
		section: Section = null) -> Transform3D:
	var square: Transform3D = _square_transform(placement, part)
	# Built square, then carried. The brick's own coordinates are the
	# section's, so the arithmetic the model has to do is the same
	# whether the section ends up level or at thirty degrees.
	return square if section == null else section.placed() * square


## Where a placement sits in whatever coordinates it was written in,
## before any section it belongs to is taken into account.
func _square_transform(placement: Placement,
		part: Lbm.PartMesh) -> Transform3D:
	var basis: Basis = BrickLattice.basis_for(placement.face, placement.rot)
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
	for brick_id: int in _placed_ids + _sketched_ids:
		mine[brick_id] = true

	# Gone, and anything whose part changed — which is a different brick
	# wearing the same number, not a brick that moved.
	# The sketch is not cleared first. It is made of ordinary bricks
	# with ordinary numbers, and the edit was built from a reading of
	# the world that included them — clearing them here deleted the very
	# bricks the edit had just asked to keep, and then skipped them as
	# missing.
	var doomed := PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var placement: Placement = wanted.get(brick.id)
		if placement == null:
			doomed.append(brick.id)
		elif placement.part != brick.part_id:
			# A different part wearing the same number is a different
			# brick, so it goes out and comes back rather than being
			# moved. It has to be re-seated, since nothing else will.
			placement.moved = true
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
		# Only what the edit actually moved. Comparing transforms
		# instead looks equivalent and is not: a brick placed by hand at
		# an orientation the lattice does not have a name for reads back
		# as the nearest one it does, and "the transform differs" is
		# then true of every such brick, every time, for an edit that
		# never mentioned it.
		if placement.moved:
			var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
			world.move_brick(brick_id, at)
			builder.lattice.release(brick_id)
			builder.register(brick_id, placement.part, at)
		if brick.color_code != placement.color:
			world.recolor_brick(brick_id, placement.color)

	for placement: Placement in fresh:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
		var brick_id: int = world.add_brick(
			placement.part, placement.color, at)
		if brick_id != 0:
			builder.register(brick_id, placement.part, at)
			if placement.mine:
				mine[brick_id] = true

	_placed_ids = PackedInt64Array()
	for brick_id: int in mine:
		_placed_ids.append(brick_id)
	# Whatever was a sketch is now built.
	_sketched_ids = PackedInt64Array()
	built.emit(_placed_ids.size())


## Put a model on the baseplate, replacing whatever the assistant built
## last time and leaving anything the person placed by hand alone.
func _apply(model: Model, finished: bool = true) -> void:
	for brick_id: int in _placed_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	# And the sketch it was drawn from, or the design lands on top of
	# itself: every brick twice, one of them unaccounted for.
	for brick_id: int in _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_sketched_ids = PackedInt64Array()
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
		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
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


## Forget the conversation, keeping the model.
##
## What "New" means. Without it the button cleared the transcript on
## screen and left the messages behind, so the next brief was sent as a
## revision of the conversation the person had just thrown away — and
## the model quietly built on top of what they meant to abandon.
func forget_conversation() -> void:
	_messages.clear()
	_pending = null
	_edited = false


## Stop claiming any of it, without touching the world.
##
## For when the world has already been replaced. BrickWorld numbers from
## one again after a clear, so ids the assistant is holding now name
## bricks of the new model — and clear_built, called at that moment,
## does not remove what the assistant built. It removes the first N
## bricks of whatever was just opened.
##
## Same family as the undo bug and the one the comment beside the Clear
## handler describes; the Open handler had the call in the wrong place
## and so was an instance of it rather than a fix for it.
func forget_built() -> void:
	_placed_ids = PackedInt64Array()
	_sketched_ids = PackedInt64Array()
	_before.clear()


func clear_built() -> void:
	for brick_id: int in _placed_ids + _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
	_placed_ids = PackedInt64Array()
	_sketched_ids = PackedInt64Array()


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
one side), 4070 (1x1 headlight brick), 3062b (1x1 round brick), 99207 \
and 44728 (brackets). Put one of those in the wall and the parts that \
hang off it get face +x, -x, +z or -z.
  Do not work the coordinates out by hand. Call attachment_points, \
which gives the exact x, y, z and face for every stud of a part —  \
placed or merely considered. A stud on the side of an 87087 is one and \
three quarter plates up and the part on it starts at half a plate; \
that is the kind of number nobody gets right by reasoning about it.
  check_design accepts a part held by a stud from any direction, not \
just one sitting on something. If it says a part has nothing holding \
it, nothing is touching it — move it, do not give up on the idea.

WHAT MAKES A MODEL LOOK REAL
The difference between a model that reads as the thing and one that \
reads as bricks is nearly always one of these.
  Surfaces that are meant to be smooth are tiled, not studded. A roof, \
a road, a table top, a bonnet.
  Shapes that are meant to be curved use parts that are curved. Slopes \
for a roof, curved slopes for a bonnet, round bricks and cones for a \
chimney or a tree trunk, dishes for a dome.
  Colour is used sparingly and deliberately. Two or three colours that \
belong together, plus one for detail. Every colour you add to the \
palette makes the model read as less of one thing.
  Things that stick out — a handle, a lamp, an aerial, a wing mirror — \
are what make a shape recognisable at a glance, and they are small. A \
bar, a round plate, a 1x1 tile on a bracket.
  Scale is consistent. If a door is four bricks tall, a window is not \
six. Decide what a doorway is and let everything else follow from it.

So a 2x4 brick at y=0 occupies plates 0,1,2. The next brick on top of it \
goes at y=3. Two bricks side by side at y=0 go at x=0 and x=4.

AT AN ANGLE
face and rot only ever give you square quarter turns. Much of what makes \
a model look like the real thing is not square: a nacelle pylon raked \
back, a wing swept, a hatch standing open, a roof at a pitch no slope \
brick makes.

Say those as a SECTION. A section is a part of the model you build \
square, in its own ordinary studs and plates from its own corner, and \
then carry somewhere at an angle:

  sections: [{name: "port pylon", x: 14, y: 8, z: 6,
              axis: "z", degrees: 35}]

Every brick with section: "port pylon" is then written as though that \
pylon were sitting flat at the origin — x from 0, y from 0 — and the \
whole thing is tipped 35 degrees and carried to 14,8,6. This is how a \
real set does it and how a set's instructions read: build the assembly, \
then attach it.

Do not try to angle bricks one at a time. Working out where each brick \
lands once it is rotated is trigonometry, you would have to do it \
forty times for one pylon, and every one of those is a chance to be a \
tenth of a stud out.

The axis is the hinge pin: z tips a thing left and right, x tips it \
forward and back, y swings it round without tilting it.

A section must touch the rest of the model somewhere, or it is a piece \
that falls off when the model is picked up. Give a section a new \
degrees or a new position with edit_model and everything in it moves \
together, which is how a hatch is opened further without describing a \
single brick again.

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

SOMETHING BIG
A set-sized model — a ship, a building, a vehicle with a real interior \
— is hundreds to thousands of parts, and it does not go in one reply. \
There is no limit on how large the finished thing may be; there is a \
limit on how much of it you can say at once. Build it the way a set is \
designed, in stages:

  1. submit_design the structure: the masses and their proportions, a \
     few dozen parts. Get that right first, because everything after it \
     depends on the proportions being right, and fixing them later \
     means moving everything.
  2. view_model and judge those proportions against the real subject \
     before adding a single detail.
  3. edit_model to add one section at a time — thirty to eighty parts a \
     call. Each one is checked against everything already there, so a \
     section that collides or floats is caught while you still know \
     what you meant by it.
  4. look_at_model with where= to re-read a section before changing it, \
     and view_model between sections to see what you have.

Do not try to submit a thousand parts in one call. It will be cut off \
part way through and nothing of it will arrive.

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
submit_design is for starting something new.

An edit is applied as soon as it is accepted. Once you have made one, \
the model is built — finish by saying what you did. Calling \
submit_design afterwards with a list that predates the edit throws the \
edit away."""


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
			"section": {"type": "string", "description":
				"the section this brick belongs to, if any. Its x, y "
				+ "and z are then that section's own coordinates, not "
				+ "the model's."},
		},
		"required": ["part", "color", "x", "y", "z", "rot"],
		"additionalProperties": false,
	}

	# A part of the model built square and then carried at an angle.
	var section: Dictionary = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "description":
				"what to call it, e.g. port nacelle"},
			"x": {"type": "number", "description":
				"studs across, where this section's own origin sits"},
			"y": {"type": "number", "description": "plates up"},
			"z": {"type": "number", "description": "studs deep"},
			"axis": {"type": "string", "enum": ["x", "y", "z"],
				"description":
					"which way the hinge pin runs. z tips it left and "
					+ "right, x tips it forward and back, y swings it "
					+ "round."},
			"degrees": {"type": "number", "description":
				"how far it is turned about that pin. Any angle."},
		},
		"required": ["name", "x", "y", "z", "axis", "degrees"],
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
				"properties": {
					"bricks": {"type": "array", "items": brick},
					"sections": {"type": "array", "items": section},
				},
				"required": ["bricks"],
				"additionalProperties": false,
			},
		},
		{
			"name": "attachment_points",
			"description": ("Where a part's studs are and the exact "
				+ "coordinates something sitting on each one would "
				+ "take. Ask about a brick that is already placed by "
				+ "its number, or about one you are considering by "
				+ "giving part and position. Use this rather than "
				+ "working out sideways positions yourself — a stud on "
				+ "the side of a brick is not at a whole number of "
				+ "plates and the arithmetic is easy to get wrong."),
			"input_schema": {
				"type": "object",
				"properties": {
					"brick": {"type": "integer", "description":
						"the number look_at_model printed"},
					"part": {"type": "string"},
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"},
					"face": {"type": "string",
						"enum": ["up", "down", "+x", "-x", "+z", "-z"]},
					"rot": {"type": "integer"},
				},
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
					"sections": {"type": "array", "items": section,
						"description":
							"add a section, or give one that already "
							+ "exists a new angle or position — which "
							+ "moves everything in it without naming a "
							+ "single brick."},
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
				+ "otherwise.\n\nA large model will not fit in one "
				+ "reply. Give where= to list one section, or skip= to "
				+ "carry on from where the last listing stopped. The "
				+ "totals and the overall span are always for the whole "
				+ "model, whatever you ask for."),
			"input_schema": {
				"type": "object",
				"properties": {
					"where": {
						"type": "object",
						"description": ("Only the part of the model "
							+ "inside this box, in studs and plates. "
							+ "Any side may be left out."),
						"properties": {
							"x_from": {"type": "number"},
							"x_to": {"type": "number"},
							"y_from": {"type": "number"},
							"y_to": {"type": "number"},
							"z_from": {"type": "number"},
							"z_to": {"type": "number"},
						},
						"additionalProperties": false,
					},
					"skip": {
						"type": "integer",
						"description": ("How many matching bricks to "
							+ "pass over before listing, for walking "
							+ "through a model a section at a time."),
					},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "view_model",
			"description": ("Look at what is on the baseplate. This is "
				+ "the only way to see whether the thing you are "
				+ "building looks like the thing you were asked for. "
				+ "check_design tells you a model is legal; this tells "
				+ "you what it is."),
			"input_schema": {
				"type": "object",
				"properties": {
					"from": {
						"type": "string",
						"enum": ["corner", "top", "front", "back",
							"left", "right"],
						"description": "which side to look from. "
							+ "corner is a three-quarter view and shows "
							+ "the shape best",
					},
				},
				"required": ["from"],
				"additionalProperties": false,
			},
		},
		{
			"name": "submit_design",
			"description": ("Submit the finished model, with every "
				+ "part. It replaces everything on the baseplate that "
				+ "you put there — including anything you added with "
				+ "edit_model. If you have been building with "
				+ "edit_model, the model is already built: say so and "
				+ "stop, rather than submitting a list that is missing "
				+ "the additions."),
			"input_schema": {
				"type": "object",
				"properties": {
					"name": {"type": "string"},
					"description": {"type": "string"},
					"bricks": {"type": "array", "items": brick},
					"sections": {"type": "array", "items": section},
				},
				"required": ["name", "description", "bricks"],
				"additionalProperties": false,
			},
		},
	]
