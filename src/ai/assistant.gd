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

## How big a reference picture is sent at. Enough to read the shape and
## the proportions off, which is all it is for.
const REFERENCE_SIZE := 900
const MAX_REPAIRS := 3
## Turns one assembly gets to be detailed in, once the model holds
## together, and how many assemblies get a look of their own. Twelve is
## a castle's gatehouse, four towers, four walls, a keep and a yard with
## one to spare; the turns are what an edit, a look and a search cost.
const TURNS_PER_ASSEMBLY := 8
const MOST_ASSEMBLIES := 12
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
## Pictures the person supplied of what they want built. Content blocks,
## ready to send. They go at the head of the conversation and stay
## there — see [method _forget_old_pictures].
var references: Array = []
## Brick id -> the section it belongs to, and the square placement it
## was written as. The world keeps only the composed transform, so
## without these a section cannot be re-angled and an angled brick
## cannot be moved. See [method _remember_section].
var _section_of: Dictionary = {}
var _local_of: Dictionary = {}
var _sections: Dictionary = {}


## Keep a picture of what is wanted. Returns false if it cannot be used.
func remember_reference(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	# Scaled down first. A photograph off a phone is several thousand
	# pixels wide, costs far more of the conversation than it is worth,
	# and tells you nothing about proportion that a smaller one does
	# not.
	var copy: Image = image.duplicate()
	var widest: int = maxi(copy.get_width(), copy.get_height())
	if widest > REFERENCE_SIZE:
		var scale: float = float(REFERENCE_SIZE) / float(widest)
		copy.resize(maxi(int(copy.get_width() * scale), 1),
			maxi(int(copy.get_height() * scale), 1),
			Image.INTERPOLATE_LANCZOS)
	var bytes: PackedByteArray = copy.save_png_to_buffer()
	if bytes.is_empty():
		return false
	references.append({
		"type": "image",
		"source": {
			"type": "base64",
			"media_type": "image/png",
			"data": Marshalls.raw_to_base64(bytes),
		},
	})
	return true


func forget_references() -> void:
	references.clear()
	_kept_pictures.clear()
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
## The assemblies still to be looked at one by one, the one being
## detailed now, and how many turns it has had. See [method _detail_next].
var _to_detail: Array[Dictionary] = []
## Every assembly the design named, which the bricks are tagged with when
## the run ends. See [method _tag_assemblies].
var _declared: Array[Dictionary] = []
var _detailing: Dictionary = {}
var _detail_turns: int = 0
var _detail_count: int = 0
## What each pass brought to the model that it did not have before, as
## [name, part ids], and the part ids the model had when the current one
## began. See [method _assembly_measured].
var _detail_added: Array = []
var _parts_before_pass: Dictionary = {}
## Whether the assembly being detailed has been sent back once already
## for being thin. See [method _detail_next].
var _sent_back: bool = false
## The whole model as it stood when detailing began, to say what the
## passes came to.
var _before_detail: String = ""
## What a run may spend in turns. MAX_TURNS, until detailing begins and
## each assembly brings its own.
var _turn_cap: int = MAX_TURNS
## What was asked for, so a pass can say what real sets of that kind are
## built from.
var _brief: String = ""
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
	## A face that was asked for and is not one of the six. Kept so the
	## check can say so rather than silently standing the part up.
	var odd_face: String = ""
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
			# Remembered, not just corrected. Quietly turning an
			# unrecognised face into "up" hands back a square brick and
			# no complaint, so a model that invented one — and the
			# obvious thing to invent is an angle — sees its part land
			# flat and has nothing to go on but the picture.
			p.odd_face = p.face
			p.face = "up"
		p.rot = posmod(int(raw.get("rot", 0)), 4)
		p.section = str(raw.get("section", "")).strip_edges()
		return p

	## This brick again, in another section. A copy is a new brick, so
	## it carries no id: "remove 41" must never reach forty other
	## bricks because one was repeated.
	func copied_into(into: String) -> Placement:
		var p := Placement.new()
		p.part = part
		p.color = color
		p.x = x
		p.y = y
		p.z = z
		p.face = face
		p.rot = rot
		p.odd_face = odd_face
		p.section = into
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
	## The parts of it a person would name — the gatehouse, a tower —
	## each {name, where}, where being a box in studs and plates as
	## look_at_model takes one. Detailed one at a time once it holds.
	var assemblies: Array[Dictionary] = []

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
	_to_detail = []
	_declared = []
	_left_out = ""
	_detailing = {}
	_detail_turns = 0
	_detail_count = 0
	_detail_added = []
	_parts_before_pass = {}
	_sent_back = false
	_before_detail = ""
	_turn_cap = MAX_TURNS
	_brief = text
	_spend = Brain.Spend.new()
	_spent_on = Brain.chosen()
	_pending = null
	_before = _snapshot()
	# A new one per instruction, including a revision: asking for a
	# change starts a fresh round of turns and produces a new model, so
	# it is a design in the sense anyone would count.
	_design_id = _new_design_id()
	# References first, in the same message as the brief.
	#
	# A named real subject was designed entirely from memory of it. The
	# loop can say a model is buildable and can look at what it built,
	# but nothing in it could ever say "that is not what a Voyager looks
	# like" — there was no way for a picture to come IN. Renders went
	# out; nothing came back.
	_messages.append({"role": "user", "content": opening_for(text)})
	progress.emit("thinking")
	_send()


## The first message of a run: the references, the brief, and what real
## sets of this kind are built from.
##
## Its own function so that what a run opens with can be read without
## opening one — a check that drives _start to see this reaches the API,
## which is both slow and a thing to need a key for.
func opening_for(text: String) -> Array:
	var opening: Array = []
	for block: Dictionary in references:
		opening.append(block)
	if not references.is_empty():
		opening.append({"type": "text", "text":
			"The picture above is what this is meant to look like. "
			+ "Measure the proportions off it — the relative sizes of "
			+ "the main masses, and where they sit against each other "
			+ "— before you choose any part."})
	opening.append({"type": "text", "text": text})
	# And what real sets of this kind are built from, unasked.
	#
	# This project has measured twice what happens to a capability the
	# design can get by without. It reached for sideways building
	# because a smooth sign face is impossible studs-up, and it never
	# once reached for a wedge plate across three runs, because a
	# staircase of plates still satisfies "build a saucer". The lesson
	# written down then: a technique the brief demands gets used, and a
	# technique that merely makes the result better has to be somewhere
	# the design cannot avoid it.
	#
	# Knowing that a castle set is arch doors in tan is exactly the
	# second kind. Offered as a tool it would be skipped by a design
	# that already has a picture in mind — and the picture is what it
	# remembers of LEGO. So it arrives with the brief.
	var kind: Dictionary = _how_real_sets_build_this(text)
	var measured: String = str(kind.get("content", ""))
	if not measured.is_empty() and not measured.begins_with("No kind") \
			and not measured.begins_with("This build"):
		opening.append({"type": "text", "text":
			"Before you choose parts, this is how real LEGO sets of this "
			+ "kind are actually built. It is measured over every "
			+ "catalogued set, not advice.\n" + measured})
	return opening


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
			"group": brick.group,
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
		world.get_brick(brick_id).group = str(entry.get("group", ""))
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
	if _turns > _turn_cap:
		_stop(false, "gave up after %d turns" % _turn_cap)
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
		# Cached, which is most of what a long design costs.
		#
		# The whole conversation is re-sent every turn, and a design
		# takes up to forty-five of them. The rules above the messages
		# never change — they are one literal string with no date, no
		# identifier and nothing counted in them — and they were being
		# read and charged for in full, every turn, at ten times what a
		# cache read costs.
		#
		# The breakpoint goes at the end of the system block because the
		# request renders tools, then system, then messages: one mark
		# here covers the tool definitions as well, and those are built
		# from a fixed list in a fixed order.
		"system": [{
			"type": "text",
			"text": _system_prompt(),
			"cache_control": {"type": "ephemeral"},
		}],
		"messages": _messages,
		"tools": _tools(),
		# And the conversation, up to whatever was added last.
		#
		# The mark above covers the rules and nothing after them, so every
		# turn paid full price for the whole design so far: a castle run
		# sent 2.04M tokens fresh against 575k from the cache, which was
		# $8 of its $9.67. Top-level, the mark goes on the last block of
		# the request and moves forward with it, and next turn reads back
		# everything up to there — as long as nothing before it has
		# changed, which is why old pictures are no longer rewritten every
		# turn.
		"cache_control": {"type": "ephemeral"},
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
	"stream", "metadata", "service_tier", "output_config", "cache_control",
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
		# Finished with the whole model, or with one assembly of it.
		if _looked_back and await _detail_next():
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
	# One assembly has had its turns. The next rides in with the answers
	# to this one's tools, so nothing it asked goes unanswered.
	if _pending == null and not _detailing.is_empty():
		_detail_turns += 1
		if _detail_turns >= TURNS_PER_ASSEMBLY:
			progress.emit("out of turns for the %s" % _detailing["name"])
			var moved_on: Array = tool_results.duplicate()
			moved_on.append({"type": "text", "text": "That is as many "
				+ "turns as one assembly gets, so on to the next."})
			if await _detail_next(moved_on):
				return
			_stop(true, "%d bricks" % world.brick_count())
			return
	_messages.append({"role": "user", "content": tool_results})

	if _pending == null:
		_send()
		return

	# A design arrived. Check it against the real lattice.
	var report: Dictionary = _check(_pending)
	progress.emit(report["summary"])
	if not report["ok"] and _repairs >= MAX_REPAIRS and not _looked_back:
		report = _salvage(report)

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
			_to_detail = _queue_assemblies(_pending.assemblies)
			_declared = _pending.assemblies
			_pending = null
			progress.emit("looking at the finished model: %s"
				% _texture(_bricks_inside({})))
			# With what the check had to say that was not a fault.
			#
			# It was computing the advice and throwing it away on
			# exactly the designs that needed it. A design that fails
			# gets report["feedback"], which carries both; a design that
			# holds together went straight to this look, which says
			# whether it would survive being picked up and lists five
			# visual faults to check by name — and never once mentioned
			# that it was made of too few different things.
			#
			# Measured on a castle: 713 bricks, buildable, 23 different
			# shapes where a real set of that size has 117, and 208 of
			# one piece where 81 is as many as all but one set in
			# twenty. The check knew all three. At the one moment the
			# design was deciding whether it was finished, it was shown
			# none of them, and it finished.
			var measured: Array = report.get("advice", [])
			var noticed: String = _left_out + _will_it_hold()
			if not measured.is_empty():
				noticed += "\n\nAnd what the check measured about it:\n" \
					+ "\n".join(PackedStringArray(measured))
			var ask: String = CRITIQUE
			if not _to_detail.is_empty():
				var names := PackedStringArray()
				for one: Dictionary in _to_detail:
					names.append(str(one["name"]))
				ask += ("\n\nAfter this, each of the %d assemblies you "
					% names.size() + "named — %s — comes to you on its "
					% ", ".join(names) + "own, close up, with what it is "
					+ "made of, to detail one at a time. So judge the "
					+ "whole here: its proportions, its outline, and "
					+ "anything that runs across more than one of them.")
			var shown: Variant = await _from_all_round(noticed, ask)
			# Cancelled while the picture was being taken. An empty
			# message is one the API refuses, so there would be nothing
			# to show for it but an error.
			if not _busy or (shown is String and (shown as String).is_empty()):
				return
			_messages.append({"role": "user", "content": shown})
			_send()
			return
		# Submitted again during the whole look, so the assemblies it
		# names now are the ones to detail.
		if _detailing.is_empty() and _detail_count == 0 \
				and not _pending.assemblies.is_empty():
			_to_detail = _queue_assemblies(_pending.assemblies)
			_declared = _pending.assemblies
		_pending = null
		if await _detail_next():
			return
		_stop(true, report["summary"])
		return

	if _repairs >= MAX_REPAIRS:
		_keep_the_failure(report)
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

Five things go wrong here over and over. Check for each of them by \
name:
  A surface built as a staircase that should be smooth or sloped. \
Steps of plain bricks where a roof, a hull, a nose or a wing should \
run — use slopes, curved slopes and wedges.
  Something raked, swept or hinged, built square. A pylon, a wing, a \
windscreen, an opened hatch. Filling a staircase with slopes leaves a \
staircase; what these want is to be a section, turned to the angle \
they actually sit at. If you find yourself stepping a shape outward a \
stud at a time, that shape wanted an angle.
  A face left blank. A wall with nothing on it, when the brief asked \
for a door or a window, or when every other face has something.
  A shape that should taper or curve, built as a box.
  Detail that cannot be seen: a colour against the same colour, or \
something hidden inside the model.
  One shape doing the work of twenty. A wall extruded out of one \
brick, a tower stacked out of one corner piece, a roof of one slope. \
If the measurements above say the model is made of far fewer different \
things than a real set of its size, this is why, and the way out is \
not more bricks — it is a different piece where something changes: a \
tile course where the wall meets the walkway, a window a third of the \
way up, a band in a second colour, a bracket carrying a lamp. Measured \
on a castle that stood up perfectly: 23 shapes against the 117 a real \
set of its size has, and 208 of one corner brick against 81.
  The same part in two colours, where one of them is used once. Three \
red beams and one grey one reads as a part taken from the wrong bin, \
not as a detail. Look at whether the odd one is doing something — a \
light, a marking, a stripe that carries across — and if it is not, \
make it match. A single contrasting piece that is clearly deliberate \
is fine; it is the structural part in the wrong colour that is not.

Use view_model with where= to look closely at whatever you are \
judging. A whole model in one frame makes every assembly on it a few \
dozen pixels across, which is not enough to tell a taper from a step.

If any of those is true, fix it with edit_model and say what you \
changed. Replacing a shape with a better one is a fix; taking it out \
and leaving the space empty is not — a model that got smaller has \
usually got worse.

If it is genuinely right, say so in one line and stop — do not submit \
it again. Be honest about this: say it reads as the thing only if you \
can name the features that make it recognisable and see each of them \
in the picture."""


## What a design that ran out of repairs had to leave behind, said at the
## start of its look. See [method _salvage].
var _left_out: String = ""


## Keep what holds of a design that has run out of repairs.
##
## A space cruiser's last submission was 641 bricks, of which two would
## not hold, and the run ended with nothing at all: three repairs spent,
## and a design that stood but for two bricks thrown away whole. Bricks
## that float hold nothing up — anything resting only on one floats too —
## so leaving them out cannot loosen the rest. Only when floating is the
## whole complaint, and at most a quarter of the design: past that it is
## not the same model any more. The design is told what went, at its
## look, and carries on to it.
func _salvage(report: Dictionary) -> Dictionary:
	var floating: Array = report.get("floating", [])
	if report.get("kinds", []) != ["floating"] or floating.is_empty() \
			or floating.size() * 4 > _pending.placements.size():
		return report
	var gone: Dictionary = {}
	for index: Variant in floating:
		gone[int(index)] = true
	var kept := Model.new()
	kept.name = _pending.name
	kept.description = _pending.description
	kept.sections = _pending.sections
	kept.assemblies = _pending.assemblies
	var said := PackedStringArray()
	for index: int in _pending.placements.size():
		if gone.has(index):
			if said.size() < 6:
				said.append("%s at %s" % [_pending.placements[index].part,
					_pending.placements[index].where()])
			continue
		kept.placements.append(_pending.placements[index])
	var again: Dictionary = _check(kept)
	if not again["ok"]:
		return report
	# Kept as it was sent as well: what would not hold is the thing to
	# debug, and the run going on does not make it any less of a failure.
	_keep_the_failure(report)
	_pending = kept
	_left_out = ("After three repairs %d brick%s still had nothing holding "
		% [gone.size(), "" if gone.size() == 1 else "s"]
		+ "them, so they were left out and the rest stands: %s%s. Put back "
		% [", ".join(said), "" if gone.size() <= 6 else " and more"]
		+ "whatever the model needs of them, held this time.\n\n")
	progress.emit("left out %d brick%s that would not hold; the rest stands"
		% [gone.size(), "" if gone.size() == 1 else "s"])
	return again


## The last design submitted, exactly as it was sent.
var _last_submitted: Dictionary = {}
## Where a design that could not be made to hold together is written. A
## variable so a probe can write somewhere else: sharing the path, a probe
## run overwrote a real run's 641-brick failure before it was read.
var failed_design: String = "user://failed_design.json"


## Write down the design that ran out of repairs, and say where.
##
## A space cruiser's run spent its three repairs on a pod that would not
## attach and ended with nothing kept and nothing recorded: the summary
## said 46 floating, and the design that floated was gone with the
## conversation. A failure that cannot be reproduced cannot be fixed, so
## the arguments go to a file a probe can read back through _read_model
## and _check, with what the check said about them.
func _keep_the_failure(report: Dictionary) -> void:
	if _last_submitted.is_empty():
		return
	var file: FileAccess = FileAccess.open(failed_design, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"brief": _brief,
		"summary": report.get("summary", ""),
		"feedback": report.get("feedback", ""),
		"design": _last_submitted}, "\t"))
	file.close()
	progress.emit("kept the design that would not hold at %s"
		% ProjectSettings.globalize_path(failed_design))


## Mark every brick with the assembly it is part of, as the run ends.
##
## The design knows its model is a gatehouse, four towers and the walls
## between, and that was thrown away with the conversation. Kept on the
## bricks it goes into the file as sub-models and into the booklet as
## its parts — "the gatehouse" rather than "part 3". A brick belongs to
## the first assembly whose box holds its corner, the way look_at_model
## reads where=. A model that is one thing is left as one thing.
func _tag_assemblies() -> void:
	if _declared.size() < 2 or world == null:
		return
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var at: Vector3 = _to_studs(brick, info)
		for one: Dictionary in _declared:
			if _inside(at, one["where"]):
				brick.group = str(one["name"])
				break


## Hand the design the next assembly to detail, or say it is finished.
##
## Detailing happened once, in the whole look, and that one pass took a
## castle from 20 shapes to 30 and from 2 castle parts to 12 — the most
## any single change has moved texture. But a castle is a gatehouse,
## four towers and four runs of wall, and a look at all of it at once
## frames each of them a few dozen pixels across and asks one question
## about the lot. A set designer finishes a gatehouse and then starts on
## a tower. So after the whole look each assembly the design named comes
## back to it on its own, close up, with what it is made of.
##
## [param also] is what has to go first in the message: the answers to
## the tools of a pass that ran out of turns.
func _detail_next(also: Array = []) -> bool:
	# Once, when a pass says it is done and its assembly is still thinner
	# than all but one real set in twenty of its size. Every pass in
	# three runs made one change and stopped, with eight turns in hand
	# and the gap in front of it in numbers — a tower of 70 parts and 10
	# shapes, told a set of that size has 38. Said at the moment it is
	# deciding it has finished, and only on the tail, like all the
	# advice here: an assembly within the range of real sets is left
	# alone, and under 60 parts there is no range to be outside.
	if not _detailing.is_empty() and not _sent_back and also.is_empty():
		var here: Array[BrickWorld.Brick] = _bricks_inside(
			_detailing["where"])
		var normal: Dictionary = library.normal_for(here.size())
		var shapes: int = _parts_in(here).size()
		if not normal.is_empty() and shapes < int(normal.get("shapes_thin", 0)):
			_sent_back = true
			progress.emit("sent the %s back: %d shapes in %d parts"
				% [_detailing["name"], shapes, here.size()])
			_messages.append({"role": "user", "content": ("The %s is %d "
				% [_detailing["name"], shapes] + "different shapes in %d "
				% here.size() + "parts. A real set of that size has about "
				+ "%d, and fewer than %d is thinner than all but one set "
				% [int(normal.get("shapes", 0)),
					int(normal.get("shapes_thin", 0))]
				+ "in twenty. One more round on it: where does something "
				+ "change that is still the same piece? Then stop.")})
			_send()
			return true
	if not _detailing.is_empty():
		progress.emit("the %s, detailed: %s" % [_detailing["name"],
			_texture(_bricks_inside(_detailing["where"]))])
		var added := PackedStringArray()
		for part_id: String in _parts_in(_bricks_inside({})):
			if not _parts_before_pass.has(part_id):
				added.append(part_id)
		_detail_added.append([_detailing["name"], added])
		_detailing = {}
		_detail_count += 1
	while not _to_detail.is_empty():
		var one: Dictionary = _to_detail.pop_front()
		var inside: Array[BrickWorld.Brick] = _bricks_inside(one["where"])
		if inside.is_empty():
			progress.emit("nothing inside the box of the %s" % one["name"])
			continue
		if _before_detail.is_empty():
			_before_detail = _texture(_bricks_inside({}))
			_turn_cap = maxi(_turn_cap, _turns + 2
				+ TURNS_PER_ASSEMBLY * (_to_detail.size() + 1))
		_detailing = one
		_detail_turns = 0
		_sent_back = false
		_repairs = 0
		_parts_before_pass = _parts_in(_bricks_inside({}))
		progress.emit("detailing the %s (%d of %d): %s" % [one["name"],
			_detail_count + 1, _detail_count + 1 + _to_detail.size(),
			_texture(inside)])
		var shown: Array = await _assembly_look(one, inside)
		if not _busy:
			return true
		_forget_old_pictures()
		_messages.append({"role": "user", "content": also + shown})
		_send()
		return true
	if not _before_detail.is_empty():
		progress.emit("detailed %d assemblies: from %s to %s" % [
			_detail_count, _before_detail, _texture(_bricks_inside({}))])
		_before_detail = ""
	return false


## One assembly, close up from two opposite corners, measured.
func _assembly_look(one: Dictionary,
		inside: Array[BrickWorld.Brick]) -> Array:
	var name: String = one["name"]
	var box: AABB = _bounds_of(inside)
	var said: String = _assembly_measured(name, inside, box)
	var ask: String = ASSEMBLY_CRITIQUE.replace("{name}", name)
	var near: Dictionary = await _ensure_shot().block(
		world, "corner", scenery, box)
	if not _busy:
		return []
	var far: Dictionary = await _shot.block(
		world, "far corner", scenery, box)
	if not _busy:
		return []
	if near.is_empty() or far.is_empty():
		var drawn: Variant = await _with_a_look(said, ask, "corner", box)
		if drawn is String:
			return [{"type": "text", "text": drawn}]
		return drawn
	return [
		{"type": "text", "text": said},
		{"type": "text", "text": "The %s from one corner:" % name},
		near,
		{"type": "text", "text": "And from the opposite one:"},
		far,
		{"type": "text", "text": ask},
	]


## What one assembly is made of, against a real set its size, and which
## of the parts real sets of this kind reach for it has not used yet.
##
## Against a set the size of the assembly, not of the model: a 200-part
## gatehouse is detailed like a 200-part gatehouse set or it is not, and
## the model's own norm says nothing about where its variety is missing.
func _assembly_measured(name: String, inside: Array[BrickWorld.Brick],
		box: AABB) -> String:
	var said := PackedStringArray()
	said.append("The %s: %s, from x %s to %s, z %s to %s, plates %d to %d."
		% [name, _texture(inside), _studs(box.position.x / STUD),
			_studs(box.end.x / STUD), _studs(box.position.z / STUD),
			_studs(box.end.z / STUD), int(floor(box.position.y / PLATE)),
			int(floor(box.end.y / PLATE + 0.001))])
	var normal: Dictionary = library.normal_for(inside.size())
	if not normal.is_empty():
		said.append("A real set of %d parts — this one assembly on its "
			% inside.size() + "own — has about %d different shapes in %d "
			% [int(normal.get("shapes", 0)), int(normal.get("colours", 0))]
			+ "colours, and at most about %d of any one piece."
			% int(normal.get("most_of_one", 0)))

	# What the passes before this one brought, because the design gives
	# siblings the same treatment: four towers got "the same crown, so
	# they match", and each tower went from 6 shapes to 11 while the
	# model went from 27 to 33. A part another assembly already has adds
	# nothing to the model's count of different shapes, and that count
	# is where it is furthest from a real set.
	var everything: Array[BrickWorld.Brick] = _bricks_inside({})
	var whole: Dictionary = _parts_in(everything)
	var before := PackedStringArray()
	for entry: Array in _detail_added:
		var brought: PackedStringArray = entry[1]
		if brought.is_empty():
			continue
		var named := PackedStringArray()
		for part_id: String in brought.slice(0, 8):
			named.append("%s %s" % [part_id, _part_called(part_id)])
		before.append("  the %s: %s" % [entry[0], "; ".join(named)])
	if not before.is_empty():
		var count: String = "The whole model is %d different shapes" \
			% whole.size()
		var normal_whole: Dictionary = library.normal_for(everything.size())
		if not normal_whole.is_empty():
			count += ", where a real set of %d parts has about %d" % [
				everything.size(), int(normal_whole.get("shapes", 0))]
		said.append("What the assemblies before this one brought to the "
			+ "model:\n" + "\n".join(before) + "\n" + count + ". Another "
			+ "assembly's parts again add nothing to that count. A pair "
			+ "that frames something can match; past that, real sets give "
			+ "siblings different jobs, and a different job is a different "
			+ "piece.")

	var used: Dictionary = {}
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in inside:
		used[brick.part_id] = true
		colours[brick.color_code] = true
	# The kinds the brief named, as the opening message gave them: a
	# castle brief that mentions towers is tower and castle both.
	var kinds := PackedStringArray()
	var missing := PackedStringArray()
	var present := PackedStringArray()
	var palette := PackedStringArray()
	var listed: Dictionary = {}
	for raw: Variant in library.kinds_for(_brief):
		var kind: Dictionary = raw
		kinds.append(str(kind.get("kind", "")))
		for entry: Variant in kind.get("parts", []):
			var part_id: String = str((entry as Array)[0])
			if listed.has(part_id):
				continue
			listed[part_id] = true
			if used.has(part_id):
				present.append(part_id)
			else:
				missing.append("  %s %s%s" % [part_id, _part_called(part_id),
					"" if whole.has(part_id) else "  — nowhere in the model yet"])
		for entry: Variant in kind.get("colors", []):
			var code: int = int((entry as Array)[0])
			var called: String = _colour_name(code)
			if not colours.has(code) and not palette.has(called):
				palette.append(called)
	if not missing.is_empty():
		said.append("Real %s sets reach for these far more than other "
			% " and ".join(kinds) + "sets do, and the %s has none of "
			% name + "them yet:\n" + "\n".join(missing))
	if not present.is_empty():
		said.append("It already has %s." % ", ".join(present))
	if not palette.is_empty():
		said.append("And they build in %s, which it does not use."
			% ", ".join(palette))

	# What most real sets of the kind use at all, which lift cannot say.
	# The parts above are what makes a castle a castle; a castle of 1,895
	# parts also has some 260 shapes, and most are ordinary. The best one
	# built here had 24 of the 40 parts castle sets use most — no 1 x 1
	# plate, no 2 x 3, neither jumper, neither cheese slope, each in more
	# than half of them. Against the whole model, because a 1 x 1 plate
	# the gatehouse has is one the tower need not be told about.
	var have: Dictionary = {}
	for part_id: String in whole:
		have[library.resolve(part_id)] = true
	var lacking := PackedStringArray()
	var offered: Dictionary = {}
	for raw: Variant in library.kinds_for(_brief):
		for entry: Variant in (raw as Dictionary).get("common", []):
			var part_id: String = str((entry as Array)[0])
			if offered.has(part_id) or have.has(library.resolve(part_id)):
				continue
			offered[part_id] = true
			lacking.append("  %s %s — in %d%% of them" % [part_id,
				_part_called(part_id), int((entry as Array)[1])])
	# And how many shapes it uses once or twice, where nearly all of the
	# gap to a real set was: a set of 1,100 parts has some 177 shapes, 85
	# of them one or two of a part; the best castle built here had 71
	# shapes and 21 such. The shapes it used many times were close.
	var per_part: Dictionary = {}
	for brick: BrickWorld.Brick in everything:
		var id: String = library.resolve(brick.part_id)
		per_part[id] = int(per_part.get(id, 0)) + 1
	var once: int = per_part.values().filter(func(n: int) -> bool:
		return n <= 2).size()
	var normal_whole: Dictionary = library.normal_for(everything.size())
	if int(normal_whole.get("accents", 0)) > once:
		said.append("Across the whole model, %d shapes are used only once "
			% once + "or twice; a real set of %d parts has about %d. "
			% [everything.size(), int(normal_whole.get("accents", 0))]
			+ "That is where most of a set's variety is — one of a part, "
			+ "where something happens — and where this model is "
			+ "furthest from one.")
	if not lacking.is_empty():
		said.append("And the parts most real %s sets use at all, which " 
			% " and ".join(kinds) + "the whole model has none of yet. "
			+ "Ordinary pieces, and where most of a set's different shapes "
			+ "come from — the smaller part where the edge or the surface "
			+ "changes:\n" + "\n".join(lacking.slice(0, 15)))
	return "\n".join(said)


## Every brick of the model whose corner is inside a box in studs and
## plates, the way look_at_model reads where=. An empty box is all of it.
func _bricks_inside(where: Dictionary) -> Array[BrickWorld.Brick]:
	var out: Array[BrickWorld.Brick] = []
	if world == null:
		return out
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		if _inside(_to_studs(brick, info), where):
			out.append(brick)
	return out


## The space a set of bricks really takes up, in LDU.
func _bounds_of(bricks: Array[BrickWorld.Brick]) -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in bricks:
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var one: AABB = (brick.transform * part.bounds).abs()
		box = one if first else box.merge(one)
		first = false
	return box


## The different parts among some bricks, as a set of ids.
static func _parts_in(bricks: Array[BrickWorld.Brick]) -> Dictionary:
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		found[brick.part_id] = true
	return found


## Parts, shapes, colours and the commonest piece, in one line.
func _texture(bricks: Array[BrickWorld.Brick]) -> String:
	var of_one: Dictionary = {}
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		of_one[brick.part_id] = int(of_one.get(brick.part_id, 0)) + 1
		colours[brick.color_code] = true
	var most: int = 0
	var commonest: String = ""
	for part_id: String in of_one:
		if int(of_one[part_id]) > most:
			most = int(of_one[part_id])
			commonest = part_id
	return "%d parts, %d shapes, %d colours, %d of %s" % [bricks.size(),
		of_one.size(), colours.size(), most, commonest]


## What to ask of one assembly, close up.
const ASSEMBLY_CRITIQUE := """This is one assembly of the model, the \
{name}, close up. Judge it the way you would judge a set that was only \
this: does it read as a {name}, and is it detailed like one?

Give it the detail it is missing, with edit_model. Where something \
changes is where a different piece goes: the course where a wall meets \
its walkway, the sill and head of a window, the top of a tower, a \
corner, a doorway, a base. Use the parts real sets of this kind reach \
for, above, where the shape calls for them. A different piece is the \
point; more of the same one is not.

Keep to the {name}; every other assembly gets its own turn. look_at_model \
with where= lists its bricks and their numbers, if you need to take any \
out or recolour them. Do not call submit_design: it replaces the whole \
model.

When it reads as detailed as a set of its size would be — not after \
the first change — say in a line what you changed, and stop."""


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
	_tag_assemblies()
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
			progress.emit("checked %d bricks%s: %s" % [
				trial.placements.size(), _shorthand_used(args),
				report["summary"]])
			# Here rather than only on a submission: this is where a
			# pattern is expanded, so this is where one that came to
			# nothing has something to say.
			_say_shorthand_trouble()
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
		"show_technique":
			var wanted: String = str(args.get("name", ""))
			progress.emit("looking up how to do %s" % wanted)
			return _show_technique(wanted)
		"plan_scale":
			progress.emit("working out how big it should be")
			return _plan_scale(args)
		"find_reference":
			var subject: String = str(args.get("subject", ""))
			progress.emit("looking up what a %s looks like" % subject)
			return await _find_reference(subject)
		"how_real_sets_build_this":
			var subject: String = str(args.get("subject", ""))
			progress.emit("looking up how real sets build a %s" % subject)
			return _how_real_sets_build_this(subject)
		"look_at_model":
			progress.emit("looking at what is already built")
			return _describe_world(args)
		"view_model":
			var from: String = str(args.get("from", "corner"))
			var close: AABB = _box_from(args.get("where"))
			progress.emit("looking at the %s" % from
				if close.size.length() <= 0.0
				else "looking closely at the %s" % from)
			# Of what is in the world, which during a design is the
			# last draft it checked — so this is its own work, not a
			# hypothetical.
			return await _with_a_look("", "", from, close)
		"edit_model":
			var edited: Model = _edit(args)
			_say_shorthand_trouble()
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
			progress.emit("changed it: %d bricks%s"
				% [edited.placements.size(), _shorthand_used(args)])
			var said: String = "Done. %d bricks now." % edited.placements.size()
			if not _unknown.is_empty():
				said += " No brick has %s, so those were left alone." \
					% _numbers(_unknown)
			# Set before the picture, dropped after it: a magenta
			# brick in a check_design render a minute later would read
			# as a colour somebody chose.
			var ask_about_it: String = _after_an_edit(edited)
			# Framed on the assembly being detailed, if one is: the
			# whole castle in one picture is what the pass is for not
			# having to judge by.
			var framed := AABB()
			if not _detailing.is_empty():
				framed = _bounds_of(_bricks_inside(_detailing["where"]))
			var answer: Variant = await _with_a_look(said, ask_about_it,
				"corner", framed)
			_shot.highlight = {}
			return answer
		"submit_design":
			_last_submitted = args
			_pending = _read_model(args)
			progress.emit("submitted %d bricks%s"
				% [_pending.placements.size(), _shorthand_used(args)])
			_say_shorthand_trouble()
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
	model.sections = _sections.duplicate()
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
		# A brick in a section is described in that section's own
		# coordinates, which are the ones it was written in. Derived
		# from the world instead they come back composed with the
		# section's angle — and the face and turn read off a basis that
		# is not square to the grid are the nearest of twenty-four,
		# which is not where the brick is.
		if _section_of.has(brick.id) and _local_of.has(brick.id):
			var kept: Array = _local_of[brick.id]
			placement.section = _section_of[brick.id]
			placement.x = float(kept[0])
			placement.y = float(kept[1])
			placement.z = float(kept[2])
			placement.face = str(kept[3])
			placement.rot = int(kept[4])
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
## Which bricks the last edit added or moved, for the picture to pick
## out. Numbers only — the recolouring happens on a copy of the world
## inside [ModelShot], so nothing in the model changes colour.
var _changed_ids: PackedInt64Array = PackedInt64Array()


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

	# After the adds, so one call can declare a section, fill it and
	# repeat it — which is the whole point of being able to repeat.
	#
	# Both troubles are cleared here, and the pattern one matters most:
	# an edit takes no patterns at all, and _check reads _pattern_trouble
	# whatever produced it. So a check_design or a submission that left
	# thirteen pattern complaints behind had every later edit report them
	# as its own — thirteen problems with an edit that could not have
	# caused one. Found because the progress line started saying how much
	# shorthand a call carried, and an edit was claiming patterns.
	var before: int = model.placements.size()
	_repeat_trouble = []
	_pattern_trouble = []
	_expand_repeats(model, args, _repeat_trouble)
	_touched += model.placements.size() - before
	_touched += gone.size()
	return model


## What shorthand a design used, for the run's own log.
##
## A real castle run reported in its own words that "the repeats didn't
## fire" and there was no way to find out what it had sent: nothing
## logged a tool's arguments, so the first use of a new feature in anger
## could say it had failed and leave no evidence at all. Counts in the
## progress line, and the complaint itself said out loud.
static func _shorthand_used(args: Dictionary) -> String:
	var said: PackedStringArray = PackedStringArray()
	var patterns: int = (args.get("patterns", []) as Array).size()
	if patterns > 0:
		said.append("%d pattern%s" % [patterns, "" if patterns == 1 else "s"])
	var copies: int = 0
	for raw: Variant in args.get("repeat_section", []):
		if typeof(raw) == TYPE_DICTIONARY:
			copies += maxi(1, int((raw as Dictionary).get("times", 1)))
	if copies > 0:
		said.append("%d section copies" % copies)
	var sections: int = (args.get("sections", []) as Array).size()
	if sections > 0:
		said.append("%d section%s" % [sections, "" if sections == 1 else "s"])
	return "" if said.is_empty() else ", " + ", ".join(said)


## And why a piece of shorthand came to nothing, in the log rather than
## only in the reply the model gets.
func _say_shorthand_trouble() -> void:
	for said: Variant in _repeat_trouble:
		progress.emit("repeat_section came to nothing: %s" % str(said))
	for said: Variant in _pattern_trouble:
		progress.emit("a pattern came to nothing: %s" % str(said))


## Whether this picture is of the subject rather than of a draft.
##
## Drafts are dropped as they age — a dozen views of a model that no
## longer exists is most of a context window spent on nothing. The thing
## being built is the opposite: it has to stay in front of the designer
## while it details, which is exactly when it stops looking at it.
func _is_reference_picture(block: Dictionary) -> bool:
	var source: Dictionary = block.get("source", {}) as Dictionary
	return _kept_pictures.has(str(source.get("data", "")))


## The base64 of every picture of the subject, so the sweep above can
## tell them from drafts. Data rather than position: a tool result moves
## about in the conversation and its index means nothing later.
var _kept_pictures: Dictionary = {}


## How much picture the conversation may carry before the old ones go,
## in base64 bytes. A request is refused above 32 MB, and a render is a
## few hundred kilobytes once it is base64, so this is a couple of dozen
## views with room left for a thousand-brick submission beside them.
const MOST_PICTURE_BYTES := 8_000_000


## Drop the pictures of earlier drafts, once there are enough of them to
## matter. Each becomes a line saying there was one, which keeps the
## transcript honest about what was seen without carrying the pixels. A
## reference the person supplied is not a draft and is never dropped.
##
## This used to run every turn, and it was the most expensive line in the
## loop. Rewriting an earlier message changes the conversation from that
## point on, so nothing after it could ever be read from the cache: a
## castle run spent $9.67, and $8 of it was the conversation sent fresh
## — 2.04M tokens, against 575k read from the cache. On Opus 5.5 an
## edited history also drops the design's thinking from that point. So
## the pictures stay until they add up, and then go in one sweep: one
## turn pays for the rewrite instead of every turn.
func _forget_old_pictures() -> void:
	## [content array, index] of every draft picture, and their weight.
	var drafts: Array = []
	var carried: int = 0
	for at: int in range(1, _messages.size()):
		var message: Dictionary = _messages[at]
		var content: Variant = message.get("content")
		if typeof(content) != TYPE_ARRAY:
			continue
		for n: int in (content as Array).size():
			var block: Variant = content[n]
			if typeof(block) != TYPE_DICTIONARY:
				continue
			if block.get("type", "") == "image":
				if not _is_reference_picture(block):
					drafts.append([content, n])
					carried += _picture_bytes(block)
				continue
			var inner: Variant = block.get("content")
			if typeof(inner) != TYPE_ARRAY:
				continue
			for m: int in (inner as Array).size():
				var piece: Variant = inner[m]
				if (typeof(piece) == TYPE_DICTIONARY
						and piece.get("type", "") == "image"
						and not _is_reference_picture(piece)):
					drafts.append([inner, m])
					carried += _picture_bytes(piece)
	if carried <= MOST_PICTURE_BYTES:
		return
	for found: Array in drafts:
		(found[0] as Array)[int(found[1])] = {"type": "text",
			"text": "(a view of an earlier draft)"}


static func _picture_bytes(block: Dictionary) -> int:
	var source: Dictionary = block.get("source", {}) as Dictionary
	return str(source.get("data", "")).length()


## Pick out what the edit just changed, and say so.
##
## A design that has just moved eight bricks is shown the whole model
## and asked whether the change worked, which on four hundred bricks
## means finding its own eight by reading coordinates. Picking them out
## in one unmistakable colour turns that back into looking.
##
## Only when the change is a part of the model rather than most of it:
## an edit that moved everything would come back as a model in one
## colour, which says nothing about anything.
func _after_an_edit(model: Model) -> String:
	_ensure_shot().highlight = {}
	var picked: Dictionary = {}
	for brick_id: int in _changed_ids:
		picked[brick_id] = true
	if picked.is_empty() or picked.size() * 2 > model.placements.size():
		return "That is what it looks like now."
	_shot.highlight = picked
	return ("That is what it looks like now. The %d you added or moved "
		% picked.size()
		+ "are bright magenta in the picture so that you can find them — "
		+ "only in the picture. They are still the colours you gave "
		+ "them.")


## How big the model actually came out, in studs.
##
## The one question a critique most needs answered — is this the size I
## planned? — is the one a picture answers worst. A vision model counts
## studs in a render badly, and the research says so: on spatial tasks
## about stacked bricks the best of them sit near half right where a
## person is at ninety percent. So the numbers are measured here and
## handed over, in the same units plan_scale talks in.
##
## Banded by height, because that is a model's massing: a saucer that
## came out three plates thick and forty across is a different object
## from one eight thick and twenty across, and both read as "a disc" in
## a photograph.
##
## Measured off each part's own bounds rather than off the lattice. The
## lattice is exact and costs nine thousand cells a brick, which is
## three million for a model this is worth saying about.
func _measured() -> String:
	if world == null or library == null:
		return ""
	## Band of plates -> [low x, high x, low z, high z], in studs.
	var bands: Dictionary = {}
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var counted: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = (brick.transform * part.bounds).abs()
		var near := Vector3(box.position.x / STUD, box.position.y / PLATE,
			box.position.z / STUD)
		var far := Vector3(box.end.x / STUD, box.end.y / PLATE,
			box.end.z / STUD)
		low = Vector3(minf(low.x, near.x), minf(low.y, near.y),
			minf(low.z, near.z))
		high = Vector3(maxf(high.x, far.x), maxf(high.y, far.y),
			maxf(high.z, far.z))
		counted += 1
		# Floor, not ceiling, so the stud on top does not put the brick
		# in a band of its own: a brick runs from 0 to 3.5 by its own
		# bounds and occupies plates 0, 1 and 2. A builder says three.
		for plate: int in range(int(floor(near.y)), maxi(
				int(floor(far.y + 0.001)), int(floor(near.y)) + 1)):
			var was: Array = bands.get(plate, [INF, -INF, INF, -INF])
			bands[plate] = [minf(was[0], near.x), maxf(was[1], far.x),
				minf(was[2], near.z), maxf(was[3], far.z)]
	if counted == 0:
		return ""

	var said := PackedStringArray()
	said.append("Measured, in studs: the whole model is %s across, %s deep "
		% [_studs(high.x - low.x), _studs(high.z - low.z)]
		+ "and %d plates tall, its near corner at x %s, z %s."
		% [int(floor(high.y - low.y + 0.001)), _studs(low.x),
			_studs(low.z)])

	# At most a dozen rows: thirty-three bands of a hundred-plate model
	# is a wall of numbers nobody reads.
	var plates: Array = bands.keys()
	plates.sort()
	if plates.is_empty():
		return " ".join(said)
	var tall: int = int(plates[plates.size() - 1]) - int(plates[0]) + 1
	var step: int = maxi(3, int(ceil(float(tall) / 12.0 / 3.0)) * 3)
	var rows := PackedStringArray()
	var band: int = int(plates[0])
	while band <= int(plates[plates.size() - 1]):
		var lo_x: float = INF
		var hi_x: float = -INF
		var lo_z: float = INF
		var hi_z: float = -INF
		for plate: int in range(band, band + step):
			if not bands.has(plate):
				continue
			var one: Array = bands[plate]
			lo_x = minf(lo_x, float(one[0]))
			hi_x = maxf(hi_x, float(one[1]))
			lo_z = minf(lo_z, float(one[2]))
			hi_z = maxf(hi_z, float(one[3]))
		if lo_x < INF:
			rows.append("  plates %-7s %s across x %s deep, at x %s, z %s"
				% ["%d-%d" % [band, band + step - 1],
					_studs(hi_x - lo_x), _studs(hi_z - lo_z),
					_studs(lo_x), _studs(lo_z)])
		band += step
	if rows.size() > 1:
		said.append("Its massing, layer by layer — compare this against "
			+ "the sizes you planned:\n" + "\n".join(rows))
	var named: String = _sections_measured()
	if not named.is_empty():
		said.append(named)
	return " ".join(said)


## Each named part of the model, measured on its own.
##
## A section is already the thing a designer thinks in — the saucer, the
## port nacelle, the neck — and the model declares them to carry a
## sub-assembly at an angle. Measuring them separately answers the
## questions a whole-model box cannot: do the two nacelles match each
## other, is the saucer wider than the hull is long, is the neck the
## three studs it was meant to be. In world coordinates, turned as they
## are carried, because that is the shape somebody sees.
func _sections_measured() -> String:
	if _section_of.is_empty():
		return ""
	## Section name -> [low, high] in studs and plates.
	var boxes: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or not _section_of.has(brick.id):
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = (brick.transform * part.bounds).abs()
		var near := Vector3(box.position.x / STUD, box.position.y / PLATE,
			box.position.z / STUD)
		var far := Vector3(box.end.x / STUD, box.end.y / PLATE,
			box.end.z / STUD)
		var name: String = str(_section_of[brick.id])
		if not boxes.has(name):
			boxes[name] = [near, far]
			continue
		var was: Array = boxes[name]
		var low: Vector3 = was[0]
		var high: Vector3 = was[1]
		boxes[name] = [
			Vector3(minf(low.x, near.x), minf(low.y, near.y),
				minf(low.z, near.z)),
			Vector3(maxf(high.x, far.x), maxf(high.y, far.y),
				maxf(high.z, far.z))]
	if boxes.is_empty():
		return ""
	var names: Array = boxes.keys()
	names.sort()
	var rows := PackedStringArray()
	for name: String in names:
		var pair: Array = boxes[name]
		var low: Vector3 = pair[0]
		var high: Vector3 = pair[1]
		rows.append("  %-18s %s across x %s deep x %d plates, from "
			% [name.substr(0, 18), _studs(high.x - low.x),
				_studs(high.z - low.z),
				int(floor(high.y - low.y + 0.001))]
			+ "x %s, y %s, z %s" % [_studs(low.x),
				_studs(floor(low.y + 0.001)), _studs(low.z)])
	return ("And each named part of it, as it is carried:\n"
		+ "\n".join(rows))


## A measurement, without a decimal point it does not need.
static func _studs(value: float) -> String:
	return Placement._num(snappedf(value, 0.1))


## The thing that takes pictures, made on first use.
func _ensure_shot() -> ModelShot:
	if _shot == null:
		_shot = ModelShot.new()
		add_child(_shot)
	return _shot


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
func _from_all_round(said: String, ask: String) -> Variant:
	var near: Dictionary = await _ensure_shot().block(
		world, "corner", scenery)
	if not _busy:
		return ""
	var far: Dictionary = await _shot.block(world, "far corner", scenery)
	if not _busy:
		return ""
	# And from directly above.
	#
	# Both of the other two are oblique, and a flat surface seen from a
	# corner is a sliver. So the one thing the rules ask for by name —
	# "surfaces that are meant to be smooth are tiled, not studded" —
	# was being judged on a view that could not show it. A five hundred
	# brick fire station came back with its roof and its whole forecourt
	# in bare studs, nearly six hundred of them in one plane, and the
	# critique had no way to see them.
	var over: Dictionary = await _shot.block(world, "top", scenery)
	if not _busy:
		return ""
	if near.is_empty() or far.is_empty():
		# No pictures to be had, so fall back to the letters — which
		# draw the plan and an elevation and hide nothing.
		return await _with_a_look(said, ask)

	var blocks: Array = []
	if not said.is_empty():
		blocks.append({"type": "text", "text": said})

	# The subject first, when there is one.
	#
	# This is the moment a designer holds the model up next to the thing
	# and sees what is wrong with it, and it was the one moment the
	# picture of the thing was not in front of it. Asking "is this the
	# thing you were asked for" with nothing to compare against is
	# asking it to remember, which is what it did badly in the first
	# place.
	var subject: Array = _subject_pictures()
	if not subject.is_empty():
		blocks.append({"type": "text", "text":
			"What you were asked for, to hold the model up against:"})
		blocks.append_array(subject)
		blocks.append({"type": "text", "text":
			"And what you built. Compare them: the proportions first, "
			+ "then the outline, then what is missing."})
	var sizes: String = _measured()
	if not sizes.is_empty():
		blocks.append({"type": "text", "text": sizes})
	blocks.append({"type": "text", "text": "From one corner:"})
	blocks.append(near)
	blocks.append({"type": "text", "text": "And from the opposite one, "
		+ "so that every side has been seen:"})
	blocks.append(far)
	if not over.is_empty():
		blocks.append({"type": "text", "text": "And from straight above. "
			+ "This is where a roof, a road, a floor or a forecourt "
			+ "shows what it is made of: bare studs read as unfinished, "
			+ "and tiles read as a surface."})
		blocks.append(over)
	if not ask.is_empty():
		blocks.append({"type": "text", "text": ask})
	return blocks


## Pictures of the subject, if any were ever found or given.
##
## Capped at one: the critique already carries three renders, and a turn
## with five pictures in it is a turn spent on pictures.
func _subject_pictures() -> Array:
	for block: Dictionary in references:
		return [block]
	for data: String in _kept_pictures:
		return [{
			"type": "image",
			"source": {"type": "base64", "media_type": "image/png",
				"data": data},
		}]
	return []


func _with_a_look(said: String, ask: String,
		from: String = "corner", only: AABB = AABB()) -> Variant:
	_ensure_shot()

	# Whether this is part of a design run, settled before the picture is
	# drawn rather than after.
	#
	# The test below used to be "if not _busy", which is right during a
	# run and wrong outside one: a session driving the app over the
	# command socket is never busy, so every tool that answers with a
	# picture answered with an empty string instead — check_design,
	# view_model, edit_model, three of the nine, silent.
	var during_a_run: bool = _busy

	var picture: Dictionary = await _shot.block(world, from, scenery, only)
	# Cancelled while the picture was being taken. Saying anything now
	# would be answering a turn that no longer exists.
	if during_a_run and not _busy:
		return ""
	# How big it came out, which is the thing a picture is worst at and
	# is wanted every time one is taken — not only at the critique.
	# A trial checked at twelve studs across when the plan said twenty
	# is cheaper to find out now than after the detail goes on.
	var sizes: String = _measured()

	if picture.is_empty():
		# Said, because the run is otherwise silent about it: a design
		# that went blind reads in its log exactly like one that looked.
		progress.emit("no picture in time, so it is shown the letters")
		var elevation: String = "front" if from in ["corner", "top"] else from
		var drawn: String = "%s\n%s" % [
			ModelView.draw(world, library, "top", scenery),
			ModelView.draw(world, library, elevation, scenery)]
		var parts := PackedStringArray()
		for piece: String in [said, sizes, drawn, ask]:
			if not piece.strip_edges().is_empty():
				parts.append(piece)
		return "\n\n".join(parts)

	var blocks: Array = []
	if not said.is_empty():
		blocks.append({"type": "text", "text": said})
	if not sizes.is_empty():
		blocks.append({"type": "text", "text": sizes})
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

	var shape: String = _footprint_sketch(part, at)

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

	# Holes, which are the other way parts join and were not reported at
	# all. A Technic beam has no studs, so this said "no studs — nothing
	# clutches to it. Tiles and most sloped surfaces are like this" about
	# the part the whole of Technic is built from.
	var holes: String = _holes_in(part, at)

	if found > MOST_STUDS:
		return ("%s has %d studs, which is too many to list. " % [label, found]
			+ "It is a flat field of them: anything sitting on top goes "
			+ "at whole studs across and at the height of its top face."
			+ holes)
	if found == 0:
		if not holes.is_empty():
			return ("%s has no studs. It joins to things through its "
				% label + "holes instead." + shape + holes)
		return ("%s has no studs — nothing clutches to it. " % label
			+ "Tiles and most sloped surfaces are like this." + shape)
	return ("%s has %d stud%s.%s%s\n" % [label, found,
		"" if found == 1 else "s", shape, holes]
		+ "\n".join(lines)
		+ "\n\nThose corners are for a 1x1 plate. A part that covers "
		+ "more studs extends from the same corner, the way it would on "
		+ "the ground. A part that is thicker than a plate is the same "
		+ "on a stud pointing up, +x or +z — but on one pointing down, "
		+ "-x or -z it hangs the other way, so its corner is further "
		+ "back along that direction by its own thickness: a brick is "
		+ "three plates, so three plates or one and a half studs.")


## Where a part's holes are, in the coordinates a pin would be written
## in, and which way each one runs.
##
## A hole's position is the one coordinate nobody gets right by
## reasoning: it sits at the middle of the part's thickness, so on a
## beam lying flat it is half a stud up and on a 1x2 brick with a hole
## it is one and a half plates up. The whole point of this tool is not
## having to work that out, and until now it only did it for studs.
##
## Said as a position rather than as a placement for a particular pin,
## because which pin goes in is the caller's choice and each has its own
## length: 2780 and 3673 reach through two beams, 4274 through one.
func _holes_in(part: Lbm.PartMesh, at: Transform3D) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "pin_hole" and connector.kind != "axle_hole":
			continue
		if lines.size() >= MOST_HOLES:
			lines.append("  ...and more, a hole every stud along it.")
			break
		var point: Vector3 = at * connector.position
		var axis: Vector3 = (at.basis * connector.axis).normalized()
		lines.append("  %s at x=%s y=%s z=%s, running %s" % [
			"pin hole" if connector.kind == "pin_hole" else "axle hole",
			Placement._num(point.x / STUD),
			Placement._num(point.y / PLATE),
			Placement._num(point.z / STUD),
			_which_axis(axis)])
	if lines.is_empty():
		return ""
	return ("\n\nHoles — a pin goes in at the position given, turned to "
		+ "run the same way:\n" + "\n".join(lines))


## How many holes are worth listing before it is a wall of text. A
## Technic baseplate has 195.
const MOST_HOLES := 12


## The axis a direction lies along, named without claiming a sign: a
## hole takes a pin from either end, so "along z" is the whole truth and
## "+z" would be half of it presented as all.
static func _which_axis(axis: Vector3) -> String:
	# Thirty holes in the library run diagonally, and calling one of
	# those "along z" would be a direction nobody could pin to.
	if absf(axis.x) > 0.99:
		return "along x"
	if absf(axis.y) > 0.99:
		return "up and down"
	if absf(axis.z) > 0.99:
		return "along z"
	return "at an angle, so put the pin in a section turned to match"


## How much of each stud this part covers, looking down, in the
## orientation it is being asked about.
##
## Nothing answered "which way does this wedge taper". The studs say
## where things attach, which for a wedge plate is the square half of
## it, and a render answers it only if you already know which way the
## camera is pointing. So the one question a shape is bought for could
## not be asked, and a saucer rim built from guesses comes out inside
## out — the same wedge put on backwards four times.
##
## Only drawn when it tells you something: a brick, a plate and a tile
## all fill their box, and saying so is noise.
const SKETCH_LIMIT := 16    ## studs a side, past which this is a wall of text


func _footprint_sketch(part: Lbm.PartMesh, at: Transform3D) -> String:
	var cells: Array[Vector3i] = builder._cells_for(part, at)
	if cells.is_empty():
		return ""

	var plan: String = _sketch_on(cells, 0, 2,
		BrickLattice.CELLS_PER_STUD, BrickLattice.CELLS_PER_STUD)
	if not plan.is_empty():
		return ("\n\nIts footprint from above — x left to right, z top to "
			+ "bottom. # is a whole stud, a digit is tenths of one, . is "
			+ "nothing:\n" + plan)

	# Flat in plan, which every slope is: the shape is in its side. Two
	# of them, because a slope falls along one axis and is square across
	# the other, and only one of the two says which.
	for side: Array in [[0, "x left to right"], [2, "z left to right"]]:
		var upright: String = _sketch_on(cells, int(side[0]), 1,
			BrickLattice.CELLS_PER_STUD, BrickLattice.CELLS_PER_PLATE, true)
		if not upright.is_empty():
			return ("\n\nIts side, %s, y up the page — # is a whole plate, "
				% side[1]
				+ "a digit is tenths of one, . is nothing:\n" + upright)
	return ""


## The part drawn on one plane, or "" when that plane says nothing.
##
## [param across] and [param up] are axis numbers into a cell: 0 is x,
## 1 is y, 2 is z. [param flip] draws the second axis bottom-up, which is
## what makes a side view read the way a side looks.
func _sketch_on(cells: Array[Vector3i], across: int, up: int,
		per_across: int, per_up: int, flip: bool = false) -> String:
	var filled: Dictionary = {}
	var lo := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	var hi := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
	for cell: Vector3i in cells:
		var flat := Vector2i(cell[across], cell[up])
		filled[flat] = true
		lo = Vector2i(mini(lo.x, flat.x), mini(lo.y, flat.y))
		hi = Vector2i(maxi(hi.x, flat.x), maxi(hi.y, flat.y))
	if lo.x == 0x7FFFFFFF:
		return ""

	var first := Vector2i(floori(float(lo.x) / per_across),
		floori(float(lo.y) / per_up))
	var last := Vector2i(floori(float(hi.x) / per_across),
		floori(float(hi.y) / per_up))
	if last.x - first.x + 1 > SKETCH_LIMIT or last.y - first.y + 1 > SKETCH_LIMIT:
		return ""

	var rows := PackedStringArray()
	var anything_missing: bool = false
	for b in range(first.y, last.y + 1):
		var row: String = ""
		for a in range(first.x, last.x + 1):
			var covered: int = 0
			for ca in range(a * per_across, a * per_across + per_across):
				for cb in range(b * per_up, b * per_up + per_up):
					if filled.has(Vector2i(ca, cb)):
						covered += 1
			var share: float = float(covered) / float(per_across * per_up)
			if share > 0.97:
				row += "#"
			elif share < 0.03:
				row += "."
				anything_missing = true
			else:
				# How full, in tenths, rather than merely "partly".
				#
				# A wedge plate drawn with one symbol for "some of it"
				# came back as a column of them, which says the stud is
				# cut without saying which way — and which way is the
				# whole question. In tenths the taper reads straight
				# off: 9 7 4 1 down a column is a diagonal, and the
				# thick end is where the 9 is.
				row += str(clampi(int(share * 10.0), 1, 9))
				anything_missing = true
		if flip:
			rows.insert(0, "  " + row)
		else:
			rows.append("  " + row)

	# A full rectangle is every part anyone has ever used without
	# wondering about its shape.
	return "" if not anything_missing else "\n".join(rows)


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
## A box written in studs and plates, as a box in LDU. Empty when
## nothing usable was given, which means the whole model.
static func _box_from(raw: Variant) -> AABB:
	if typeof(raw) != TYPE_DICTIONARY:
		return AABB()
	var where: Dictionary = raw
	for side: String in ["x_from", "x_to", "y_from", "y_to",
			"z_from", "z_to"]:
		if not where.has(side):
			return AABB()
	var low := Vector3(
		float(where["x_from"]) * STUD,
		float(where["y_from"]) * PLATE,
		float(where["z_from"]) * STUD)
	var high := Vector3(
		float(where["x_to"]) * STUD,
		float(where["y_to"]) * PLATE,
		float(where["z_to"]) * STUD)
	return AABB(low.min(high), (high - low).abs().max(
		Vector3(STUD, PLATE, STUD)))


## What the world cannot hold on to.
##
## A brick goes into the world as one composed transform: the section's
## angle and the brick's own square placement multiplied together, with
## no record that the two were ever separate. Read back, its basis is
## snapped to the nearest of the twenty-four and the angle is gone.
##
## So an edit could not give a section a new angle — which the rules
## promise it can, because that is how a hatch opens without describing
## a brick again — and moving an angled brick re-seated it square.
## Remembered here instead, for as long as the model is on the
## baseplate.
func _remember_section(brick_id: int, placement: Placement,
		model: Model) -> void:
	if placement.section.is_empty():
		_section_of.erase(brick_id)
		_local_of.erase(brick_id)
		return
	_section_of[brick_id] = placement.section
	_local_of[brick_id] = [placement.x, placement.y, placement.z,
		placement.face, placement.rot]
	var section: Section = model.sections.get(placement.section)
	if section != null:
		_sections[placement.section] = section


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
		var corners: Array = _corners_in_studs(brick)
		if corners.is_empty():
			continue
		var at: Vector3 = corners[0]
		var reaches: Vector3 = corners[1]
		low = Vector3(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z))
		high = Vector3(maxf(high.x, reaches.x), maxf(high.y, reaches.y),
			maxf(high.z, reaches.z))

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
	var corners: Array = _corners_in_studs(brick)
	return Vector3.ZERO if corners.is_empty() else corners[0] as Vector3


## Both corners a brick really occupies, in studs and plates.
##
## The low one is what a placement is named by, and for a long time it
## was the only one anyone asked for — so the span of a model was the
## span of its corners. Four wing plates all placed at z=0 reach four
## studs deep between them, and look_at_model said "z 0..0" about them.
## Anything deciding whether a thing fits was told the model was the
## size of a point.
func _corners_in_studs(brick: BrickWorld.Brick) -> Array:
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if part == null:
		return []
	# From the boxes, which already know where the part begins and ends.
	# This walked every cell to find two corners — nine thousand six
	# hundred of them for a 2x4 — and it is called once per brick every
	# time the model is described. On a two thousand brick model that
	# was nine seconds to answer "what is on the baseplate", which is
	# the question a design asks most.
	var packed: PackedInt32Array = builder.boxes_for(part, brick.transform)
	if packed.is_empty():
		return []
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3] - 1, packed[4] - 1, packed[5] - 1)
	for n: int in range(6, packed.size(), 6):
		lo = Vector3i(mini(lo.x, packed[n]), mini(lo.y, packed[n + 1]),
			mini(lo.z, packed[n + 2]))
		hi = Vector3i(maxi(hi.x, packed[n + 3] - 1),
			maxi(hi.y, packed[n + 4] - 1), maxi(hi.z, packed[n + 5] - 1))
	var near: Vector3 = BrickLattice.to_ldu(lo)
	# One cell past the last one filled, because a cell is a step and
	# not a point: a 1 x 1 plate fills one cell and reaches to the next.
	var far: Vector3 = BrickLattice.to_ldu(hi + Vector3i.ONE)
	return [
		Vector3(near.x / STUD, near.y / PLATE, near.z / STUD),
		Vector3(far.x / STUD, far.y / PLATE, far.z / STUD),
	]


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
	return "%s: %s, covers %dx%d studs, %d plate%s, %s%s" % [
		info.id, info.name.strip_edges(), footprint.x, footprint.y,
		plates, "" if plates == 1 else "s", _studs_of(info),
		_made_in(info)]


## What can be had, on the one line the model reads about a part.
##
## Silent when nothing is known, which is most of the library: a part
## with no inventory behind it must not read as a part that was never
## sold. A retired part says so with its last year, because "there are
## no current colours" and "nobody knows" are not the same answer and
## the model cannot tell them apart from a count of zero.
func _made_in(info: PartLibrary.PartInfo) -> String:
	if not info.availability_known():
		# Geometry somebody drew that may not be a real element. The
		# flag was being loaded and never read, so in-review parts read
		# exactly like mass-produced ones. Only worth saying when there
		# is also no record of the part in any set: 346 unofficial parts
		# are demonstrably in recent sets and are simply new.
		if info.unofficial:
			return ", drawn but unreviewed — no record of it in any set"
		return ""
	if info.still_made():
		var how_many: int = info.colors_recent.size()
		# A count is only useful when it is large. "37 colours" says the
		# part is versatile and the choice is free; "3 colours" decides
		# the colour of whatever is built from it, and which three is
		# then the only thing worth knowing.
		if how_many <= NAME_THEM:
			var names: PackedStringArray = PackedStringArray()
			for code: int in info.colors_recent:
				names.append(_colour_name(code))
			return ", made in %d colour%s, %s" % [
				how_many, "" if how_many == 1 else "s", ", ".join(names)]
		return ", made in %d colours" % how_many
	if info.last_year > 0:
		return ", retired — last in a set in %d" % info.last_year
	return ""




## Whether the model is made of as many different things as a real set.
##
## The checker can say a model stands up. Whether it reads as a set is a
## different question and it was resting on taste, so it is measured
## instead: every catalogued LEGO set, banded by size, gives the number
## of part-and-colour lots, the number of different shapes and how many
## of one part is normal. A five hundred part set has about a hundred
## and fifty lots and a hundred and twenty shapes, and uses at most two
## dozen of any one piece.
##
## A fire station this built came to five hundred and thirty five parts
## in forty five lots, thirty shapes, and eighty six of one brick. It
## stands up and it is the right size; it is the wrong texture, and
## nothing said so.
func _variety(model: Model) -> String:
	var parts: int = model.placements.size()
	var normal: Dictionary = library.normal_for(parts)
	if normal.is_empty():
		return ""
	var lots: Dictionary = {}
	var shapes: Dictionary = {}
	var of_one: Dictionary = {}
	for placement: Placement in model.placements:
		lots["%s/%d" % [placement.part, placement.color]] = true
		shapes[placement.part] = true
		of_one[placement.part] = int(of_one.get(placement.part, 0)) + 1
	var most: int = 0
	var commonest: String = ""
	for part_id: String in of_one:
		if int(of_one[part_id]) > most:
			most = int(of_one[part_id])
			commonest = part_id

	# What it fires on is the tails, and what it reports is the median.
	#
	# A multiple of the median read like a tolerance and was not one.
	# Six tenths of the median shapes and twice the median repeat fired
	# on **29 to 34 per cent of real LEGO sets**, band by band — and the
	# standard this project already holds advice to is that it must not
	# fire on good models. The fifth and ninety-fifth percentiles of the
	# same measurements bring that to 7-11%, which is what advice should
	# cost, and still catch the fire station this was written for.
	var said: PackedStringArray = PackedStringArray()
	var want_lots: int = int(normal.get("lots", 0))
	var want_shapes: int = int(normal.get("shapes", 0))
	var want_most: int = int(normal.get("most_of_one", 0))
	var thin_lots: int = int(normal.get("lots_thin", 0))
	var thin_shapes: int = int(normal.get("shapes_thin", 0))
	var high_most: int = int(normal.get("most_of_one_high", 0))
	if thin_lots > 0 and lots.size() < thin_lots:
		said.append("%d different part-and-colour combinations, where a real "
			% lots.size() + "set of %d parts has about %d" % [parts, want_lots])
	if thin_shapes > 0 and shapes.size() < thin_shapes:
		said.append("%d different shapes, against about %d"
			% [shapes.size(), want_shapes])
	if high_most > 0 and most > high_most:
		said.append("%d of one part (%s), where about %d is usual and %d "
			% [most, commonest, want_most, high_most]
			+ "is as many as all but one set in twenty uses")
	if said.is_empty():
		return ""
	return ("Thinner than a set of this size:\n  " + "\n  ".join(said)
		+ "\nThis is what separates a model that is built from one that is "
		+ "designed — the detail that needs a different piece. Measured "
		+ "over %d real sets of this size." % int(normal.get("sets", 0)))


## Up to how many available colours are worth naming rather than counting.
const NAME_THEM := 6
## How many of one colour mistake to mention before it is repetition.
const WORTH_SAYING := 4
## How many substitute colours to name. Enough to choose from, not a
## recitation of eighty.
const ENOUGH_COLOURS := 8


## Parts specified in a colour LEGO never moulded them in.
##
## Advice, not a fault, and for a reason: the join behind this knows
## 6,419 of the 8,591 plain parts in the library, and 846 of those have
## a colour list that is short because sixty-nine Rebrickable colours
## have no LDraw counterpart. PartInfo.never_made_in refuses to answer
## for either case, so what is left is parts whose list is both present
## and complete — but a design is still buildable in another colour, and
## failing one over a data join would be the join overreaching.
func _never_made(model: Model) -> String:
	## "part|colour" -> how many bricks say it.
	var wrong: Dictionary = {}
	for placement: Placement in model.placements:
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		if info == null or not info.never_made_in(placement.color):
			continue
		var key: String = "%s|%d" % [placement.part, placement.color]
		wrong[key] = int(wrong.get(key, 0)) + 1
	if wrong.is_empty():
		return ""

	# Worst first: the mistake repeated across forty bricks matters more
	# than the one brick that got an odd colour.
	var keys: Array = wrong.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(wrong[a]) > int(wrong[b]))

	var lines: PackedStringArray = PackedStringArray()
	for key: String in keys.slice(0, WORTH_SAYING):
		var bits: PackedStringArray = key.split("|")
		var info: PartLibrary.PartInfo = library.parts.get(bits[0])
		var count: int = int(wrong[key])
		lines.append("%s in %s (%d brick%s) — %s was never moulded in it. %s" % [
			bits[0], _colour_name(int(bits[1])), count,
			"" if count == 1 else "s", info.name.strip_edges(),
			_instead(info)])
	if keys.size() > WORTH_SAYING:
		lines.append("and %d more part-and-colour pairs like that."
			% (keys.size() - WORTH_SAYING))
	return "Colours that were never made:\n" + "\n".join(lines)


func _colour_name(code: int) -> String:
	var colour: PartLibrary.BrickColor = library.colors.get(code)
	return colour.name if colour != null else "colour %d" % code


## The colours to offer instead, preferring ones still in production.
func _instead(info: PartLibrary.PartInfo) -> String:
	var pick: PackedInt32Array = info.colors_recent
	var when: String = "comes in"
	if pick.is_empty():
		pick = info.colors
		when = "only ever came in"
	var names: PackedStringArray = PackedStringArray()
	for code: int in pick:
		if names.size() >= ENOUGH_COLOURS:
			break
		names.append(_colour_name(code))
	var tail: String = "" if pick.size() <= names.size() \
		else ", and %d more" % (pick.size() - names.size())
	return "It %s %s%s." % [when, ", ".join(names), tail]


## Categories where no stud on top really does mean nothing grips.
##
## A positive list on purpose. "No studs" is true of a hinge base, a
## turntable and most of Technic as well, and those hold perfectly well
## by a hinge or a pin — the library simply has no connector kind for a
## hinge. Firing on "no studs" alone complained about both hinges in
## models/car.ldr, which is how the roof and the doors are attached.
const SMOOTH_ON_TOP: Dictionary = {
	"Tile": true, "Slope": true, "Panel": true, "Baseplate": true,
}


## Legal sideways offsets between two stacked parts, in studs. Zero is
## square on, and a half is what a jumper plate exists to give. Anything
## between is a position no stud can reach a tube from.
const STUD_GRID := 0.5
## How far off that grid still counts as on it, in studs. The lattice
## snaps to tenths, so this is tighter than one cell.
const GRID_SLACK := 0.02


## Note that a brick rests on another without being attached to it.
##
## Two different faults wear the same shape. If no stud reaches the brick
## at all, it is standing on a smooth face — a tile, a slope — and
## nothing clutches. If one does reach it but the two parts are offset by
## a fraction of a stud, a stud is inside the brick's footprint without
## being inside a tube, which is a position that exists on the lattice
## and not in plastic.
func _note_loose(loose: Dictionary, model: Model, index: int, under: int,
		reached: bool) -> void:
	var placement: Placement = model.placements[index]
	var below: Placement = model.placements[under]

	# Whether the thing underneath has any stud at all, which is a fact
	# about the part rather than about the lattice.
	#
	# The first version of this asked whether a stud reached the brick,
	# which _studs_reaching_in answers by sampling five LDU past the
	# stud's tip. For a part whose underside the occupancy left open —
	# a flower, a round tile — that sample lands in the cavity and finds
	# nothing, so a flower correctly pressed onto a 2x2 round brick was
	# reported as resting on something with no studs. It has four. Two
	# to four such complaints per model, on the eight that ship with the
	# app and are known good.
	var holder: PartLibrary.PartInfo = library.parts.get(below.part)
	if holder != null and holder.stud_count == 0 \
			and SMOOTH_ON_TOP.has(holder.category):
		_note(loose, "Resting on a smooth face, held by nothing:",
			"  brick %d (%s at %s) stands on brick %d (%s), which has no "
			% [index, placement.part, placement.where(), under, below.part]
			+ "stud anywhere to grip it. Put it on something studded, or "
			+ "hold it another way.")
		return
	if not reached:
		return
	# Only the ordinary stacking case. A part carried on the side of
	# something, or in a section turned to an angle, is off the stud grid
	# for a good reason and is not what this is about.
	if placement.face != "up" and placement.face != "down":
		return
	if below.face != "up" and below.face != "down":
		return
	if placement.section != below.section:
		return
	var across: float = absf(placement.x - below.x)
	var along: float = absf(placement.z - below.z)
	if _on_the_grid(across) and _on_the_grid(along):
		return
	_note(loose, "Offsets no stud can reach:",
		"  brick %d (%s at %s) sits %s studs across and %s along from "
		% [index, placement.part, placement.where(),
			Placement._num(across), Placement._num(along)]
		+ "brick %d, so its tubes land between that part's studs. Whole "
		% under + "studs grip; so does a half, on a jumper. Nothing in "
		+ "between does.")


static func _on_the_grid(offset: float) -> bool:
	var over: float = fposmod(offset, STUD_GRID)
	return over <= GRID_SLACK or over >= STUD_GRID - GRID_SLACK


## Where a part's studs are, not merely how many there are.
##
## This said "N studs on top" and counted every stud a part has,
## whichever way it points. So 87087 — "Brick 1 x 1 with Stud on 1
## Side", whose side stud is the entire reason the part exists — was
## described as having two studs on top, and a bracket, which is a
## right angle with studs on both planes, as having six. The one line
## the model reads about a part misstated the exact feature that makes
## it the part it went looking for.
##
## The catalogue does not record which way a stud faces, but it does
## not need to: a top face can hold one stud per stud of footprint, so
## anything beyond that is somewhere else. It cannot over-claim, and it
## under-claims only for parts with fewer top studs than they have room
## for — a jumper, say — which is not a sideways part and reads
## correctly anyway.
## How many studs the part's top face has room for.
##
## Rounded, where the footprint the placement rules use is rounded up.
## The two are different questions: a 1x1 brick with a stud on its side
## is 24 LDU deep, because the stud sticks out, and it needs two studs
## of clearance — but its top holds one. Ceiling that to two says it
## has room for the side stud on top, which is exactly the part's whole
## point going missing.
static func _room_on_top(info: PartLibrary.PartInfo) -> int:
	return maxi(int(round(info.size.x / STUD)), 1) \
		* maxi(int(round(info.size.z / STUD)), 1)


func _studs_of(info: PartLibrary.PartInfo) -> String:
	if info.stud_count <= 0:
		return "no studs — a smooth face"
	var room: int = _room_on_top(info)
	var on_top: int = mini(info.stud_count, room)
	var elsewhere: int = info.stud_count - on_top
	if elsewhere <= 0:
		return "%d stud%s on top" % [on_top, "" if on_top == 1 else "s"]
	# Which way, not merely "another way".
	#
	# "Another way" is the whole reason somebody searched for a bracket
	# or a headlight brick, and leaving it at that costs an
	# attachment_points call to find out whether the part does the job.
	# Sideways and underneath are different parts for different
	# problems: one carries a wall, the other hangs something below a
	# floor.
	var way: String = _which_way(info, elsewhere)
	return ("%d stud%s on top and %s — "
		% [on_top, "" if on_top == 1 else "s", way]
		+ "attachment_points gives the exact coordinates")


## How the studs that are not on top are pointed, in the part's own
## frame: sideways or underneath. Named in the part's frame and not in
## the world's, because an unplaced part has no world: "+x" would be a
## claim about where it ends up, and rot decides that.
func _which_way(info: PartLibrary.PartInfo, elsewhere: int) -> String:
	var mesh: Lbm.PartMesh = library.mesh_for(info.id) if library != null \
		else null
	if mesh == null:
		return "%d facing another way" % elsewhere
	var sideways: int = 0
	var under: int = 0
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var axis: Vector3 = connector.axis.normalized()
		# LDraw is -Y up, and a part's own studs point along its own
		# axis; up is whatever the rest of them agree on, so this asks
		# only whether a stud disagrees with the top face and how.
		if axis.dot(Vector3.UP) > 0.9:
			continue
		if axis.dot(Vector3.UP) < -0.9:
			under += 1
		else:
			sideways += 1
	if sideways > 0 and under > 0:
		return "%d facing sideways and %d underneath" % [sideways, under]
	if under > 0:
		return "%d underneath" % under
	if sideways > 0:
		return "%d facing sideways" % sideways
	return "%d facing another way" % elsewhere


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
	var written: Array = args.get("bricks", [])
	for raw: Variant in written:
		model.placements.append(Placement.from_dict(raw))

	# And the shapes it described rather than counted out. Patterns are
	# expanded after the bricks because mirror reflects what is there.
	var patterns: Array = args.get("patterns", [])
	if not patterns.is_empty():
		var trouble: Array = []
		for raw: Variant in Patterns.expand(patterns, written, trouble,
				library):
			model.placements.append(Placement.from_dict(raw))
		_pattern_trouble = trouble
	else:
		_pattern_trouble = []

	_repeat_trouble = []
	_expand_repeats(model, args, _repeat_trouble)
	model.assemblies = _read_assemblies(args)
	return model


## The assemblies a design named, each a name and a box in studs and
## plates. A side left out is open, as it is for look_at_model.
static func _read_assemblies(args: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in args.get("assemblies", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges()
		if name.is_empty():
			continue
		var where: Dictionary = {}
		for side: String in ["x_from", "x_to", "y_from", "y_to",
				"z_from", "z_to"]:
			if one.has(side):
				where[side] = float(one[side])
		out.append({"name": name, "where": where})
	return out


## What a run will detail, one assembly at a time. Nothing for a model
## that is one thing: its whole look is already the look at it.
static func _queue_assemblies(named: Array[Dictionary]) -> Array[Dictionary]:
	if named.size() < 2:
		return []
	return named.slice(0, MOST_ASSEMBLIES)


## What was wrong with the last set of patterns, said by the check.
var _pattern_trouble: Array = []

## And with the last set of repeats. Kept apart from the patterns so the
## summary can name which of the two went wrong: a model told only that
## something was wrong with its shorthand has two shorthands to check.
var _repeat_trouble: Array = []


## How many copies one repeat may make, and how many bricks they may
## come to. The lattice holds fifty thousand bricks in 180 MB, so the
## ceiling is the lattice's and not a guess; these stop a mistyped
## times= from asking for a model nothing can hold.
const MOST_COPIES := 400
const MOST_BRICKS := 50000


## Copy a section that is already built to new places and angles.
##
## This is what makes a large model sayable. A castle wall of forty bays
## is ten thousand bricks, which is more than a reply holds — and it is
## also one bay described once and repeated thirty-nine times. Real sets
## are built the second way: a 7,000 part model is a few hundred distinct
## parts and a great deal of repetition. Nothing here could say that, so
## every large model had to be dictated brick by brick, and the limit on
## how big a model could be was the limit on how much fits in one reply.
##
## Copies are expanded after the bricks, so one call can declare a
## section, fill it, and repeat it.
##
## The step is applied per copy, so times=7 with dx=24 lays seven bays in
## a row. degrees= steps too, and a section turns about its own origin:
## put the origin at the centre of a tower and degrees=45 with times=7
## walks a module round it.
static func _expand_repeats(model: Model, args: Dictionary,
		trouble: Array) -> void:
	for raw: Variant in args.get("repeat_section", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var order: Dictionary = raw
		var from: String = str(order.get("from", "")).strip_edges()
		if not model.sections.has(from):
			# Naming what there is, because the likeliest mistake is a
			# section that was never declared and the second likeliest
			# is a near miss on its name.
			var known: String = ", ".join(
				PackedStringArray(model.sections.keys()))
			trouble.append(("There is no section called \"%s\". " % from)
				+ ("The sections here are: %s." % known if not known.is_empty()
					else "This model has no sections yet.")
				+ " Only a section can be repeated: build the piece you"
				+ " want copied with section= on each of its bricks,"
				+ " declare that section, then repeat it.")
			continue
		var source: Section = model.sections[from]
		var body: Array[Placement] = []
		for placement: Placement in model.placements:
			if placement.section == from:
				body.append(placement)
		if body.is_empty():
			trouble.append(("Section \"%s\" has no bricks in it, so " % from)
				+ "repeating it would copy nothing. Place its bricks "
				+ ("first, with section=\"%s\" on each." % from))
			continue

		var times: int = maxi(1, int(order.get("times", 1)))
		if times > MOST_COPIES:
			trouble.append("times=%d is more copies than %s can "
				% [times, from] + "take; %d is the most." % MOST_COPIES)
			continue
		var room: int = MOST_BRICKS - model.placements.size()
		if body.size() * times > room:
			trouble.append(("%d copies of \"%s\" is %d bricks, and there "
				% [times, from, body.size() * times])
				+ ("is room for %d. " % maxi(0, room))
				+ "Build it in pieces, or make the section smaller.")
			continue

		var step := Vector3(float(order.get("dx", 0)),
			float(order.get("dy", 0)), float(order.get("dz", 0)))
		var turn: float = float(order.get("degrees", 0))
		var axis: String = str(order.get("axis", source.axis)).to_lower()
		if not ["x", "y", "z"].has(axis):
			axis = source.axis
		var base: String = str(order.get("name", from)).strip_edges()
		if base.is_empty():
			base = from

		for n: int in range(1, times + 1):
			var name: String = "%s %d" % [base, n + 1]
			var at: int = 2
			while model.sections.has(name):
				at += 1
				name = "%s %d" % [base, at]
			var copy := Section.new()
			copy.name = name
			copy.x = source.x + step.x * n
			copy.y = source.y + step.y * n
			copy.z = source.z + step.z * n
			copy.axis = axis
			copy.degrees = source.degrees + turn * n
			model.sections[name] = copy
			for placement: Placement in body:
				model.placements.append(placement.copied_into(name))


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
	# Nothing here asks where a brick would come to rest, which is the
	# only thing the column index is for, and keeping it is a third of
	# what checking a design costs.
	lattice.keeps_columns = false
	## Section name -> a lattice of that section's own square cells.
	var inside: Dictionary = {}
	## Sections that ran into something. A brick that overlaps is never
	## occupied, so the rest of its section then looks unsupported and
	## unattached — three complaints from one fault, two of them
	## artefacts of the first.
	var crowded: Dictionary = {}
	## Section name -> the indices of the placements in it.
	var part_of: Dictionary = {}
	## Sections reported adrift, so the hint below can address them too.
	var stuck: Dictionary = {}
	## Things worth saying that are not faults, and must not be counted
	## as any.
	var advice: Array = []
	var issues: Dictionary = {}     ## kind -> Array[String]
	var cells_of: Dictionary = {}   ## index -> Array[Vector3i]
	var boxes_of: Dictionary = {}   ## index -> its boxes, six ints each
	var box_of: Dictionary = {}     ## index -> [low cell, high cell]

	for said: Variant in _pattern_trouble:
		_note(issues, "pattern", str(said))
	for said: Variant in _repeat_trouble:
		_note(issues, "repeat", str(said))

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
					+ "edit_model, a few hundred bricks at a time.",
			}
		return {
			"ok": false,
			"summary": "no bricks",
			"feedback": "That design has no parts in it.",
		}

	## Which placements a pin, axle or ball joins to which. Needed before
	## the first brick goes into the lattice, because a joint is allowed
	## to overlap and the lattice finds out in placement order.
	var joined: Dictionary = _connectors_mating(model)

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
			lattice.occupy_boxes(key,
				builder.boxes_for(part, brick.transform))
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
		# A section that was never declared.
		#
		# section_for hands back null, _transform quietly returns the
		# square placement, and the brick is built at those coordinates
		# as though they were the world's — which for a part meant to
		# be carried somewhere at an angle is a long way from where it
		# belongs. Silent, and the same shape of fault as a face that
		# is not one of the six.
		if not placement.section.is_empty() \
				and not model.sections.has(placement.section):
			_note(issues, "no such section",
				"brick %d (%s) says it is in section '%s', which is "
					% [index, placement.part, placement.section]
					+ "not one of the sections given. Declare it in "
					+ "sections, or leave the field out and give the "
					+ "brick the model's own coordinates.")
			continue
		if not placement.odd_face.is_empty():
			_note(issues, "no such face",
				"brick %d (%s) asks for face '%s'. The six are up, "
					% [index, placement.part, placement.odd_face]
					+ "down, +x, -x, +z and -z — face cannot carry an "
					+ "angle. For anything not square to the grid, put "
					+ "the part in a section and turn the section.")
			continue
		# Below the baseplate, but only for a brick this design is
		# actually placing.
		#
		# The rule exists to stop a design being written underground.
		# Applied to bricks that were already standing it stops the
		# assistant doing anything at all: models/car.ldr, which this
		# app ships and opens, has thirteen tyres at y=-3 — which is
		# where a car's wheels go — and asking to change the colour of
		# one brick on it came back "Not applied: the model would not
		# hold together", listing thirteen wheels the edit never
		# touched and could not have moved. A fault nobody can act on
		# is not a fault.
		if placement.y < 0 and (placement.id == 0 or placement.moved):
			_note(issues, "below ground",
				"brick %d (%s) is at y=%d, below the ground" % [
					index, placement.part, placement.y])
			continue

		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
		var packed: PackedInt32Array = builder.boxes_for(part, at)
		# Cells out of the boxes, not worked out a second time. For a
		# turned part the cover costs a separating-axis test on every
		# candidate cell, and asking for it twice — once as boxes, once
		# as cells — is what made a model with four sections take
		# thirty-five seconds to check against six and a half.
		var cells: Array[Vector3i] = BrickLattice.cells_in(packed)

		# Inside a section, check the bricks against each other in the
		# section's own square frame.
		#
		# A part that is not square to the grid cannot be rasterised
		# onto it exactly, so it reserves every cell it touches at all —
		# which is the safe direction against other assemblies and
		# quite wrong within one. Two bricks that abut exactly each
		# reach a little way into the other once the section is tipped,
		# and the section collides with itself: a six-brick pylon came
		# back with three overlaps at every angle but zero. A design
		# asked for Voyager met this, wrote "the rotated sections
		# collide with everything once tipped", and went back to
		# building stepped slabs.
		#
		# Rotating an assembly rigidly cannot make its own bricks
		# intersect. In their own frame they are square, so the exact
		# integer path answers, and it answers correctly.
		if not placement.section.is_empty():
			if not part_of.has(placement.section):
				part_of[placement.section] = []
			part_of[placement.section].append(index)
			var own: BrickLattice = inside.get(placement.section)
			if own == null:
				own = BrickLattice.new()
				own.keeps_columns = false
				inside[placement.section] = own
			var square: Transform3D = _square_transform(placement, part)
			# In boxes, and worked out once. In cells this was nine
			# thousand six hundred of them per brick, merged back into
			# boxes twice over — once to ask what it ran into and once
			# to put it in — and on a model with four sections that was
			# the whole cost of checking it.
			var here: PackedInt32Array = builder.boxes_for(part, square)
			var near: PackedInt64Array = own.blockers_boxes(here)
			if not near.is_empty():
				crowded[placement.section] = true
				_note(issues, "overlap",
					"brick %d (%s at %s) overlaps brick %d inside "
						% [index, placement.part, placement.where(),
							near[0] - 1]
						+ "section '%s'%s" % [placement.section,
							_ends_at(cells_of.get(near[0] - 1))])
				continue
			own.occupy_boxes(index + 1, here)

		var blockers: PackedInt64Array = _blockers_outside(
			lattice, packed, model, placement)

		# Two bricks that were already standing, neither of them touched
		# by this design, are not this design's problem.
		#
		# models/car.ldr ships with the app and has wheels: a tyre fits
		# around a hub, which a cover made of boxes cannot express, so
		# the car reads as nine overlaps that are not faults and that
		# nobody can act on. Asking to change the colour of one brick on
		# it came back "Not applied — the model would not hold
		# together", listing them. The rule is the same one the ground
		# check needed: report what this design is doing, not what it
		# found already there. They are still put in the lattice,
		# because they are still really there and nothing new may be
		# built inside them.
		# A pin in a hole is meant to overlap, and by a measurable
		# amount. A Technic pin's shaft is 12 LDU across but its collar
		# is 16, and the collar is what sits in the chamfer at the hole's
		# mouth — which a lattice of 2 LDU cells cannot represent. Put
		# 3673 into 3700's hole and 42 of the pin's 500 cells land inside
		# the brick, all of them the collar ring.
		#
		# Widening the bore to swallow it was measured and is worse: at
		# radius 8 a Technic beam 3 loses a third of its cells, 1,472 to
		# 992, and other parts would pass straight through a liftarm. So
		# the bore stays at the shaft's radius and the joint is forgiven
		# instead — only between the two parts the joint actually names,
		# so every other overlap still reports.
		if not blockers.is_empty() and joined.has(index):
			var mates: Dictionary = joined[index]
			var rest: PackedInt64Array = PackedInt64Array()
			for key: int in blockers:
				if key > 0 and not mates.has(key - 1):
					rest.append(key)
				elif key <= 0:
					rest.append(key)
			blockers = rest

		if not blockers.is_empty() and placement.id != 0 \
				and not placement.moved:
			var first: int = blockers[0]
			if first > 0 and first - 1 < model.placements.size():
				var other: Placement = model.placements[first - 1]
				if other.id != 0 and not other.moved:
					blockers = PackedInt64Array()

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
			# In section terms when it is a section, because the answer
			# is different.
			#
			# Told "brick 7 overlaps brick 3", the way out is to move
			# brick 7 — and if it is one of forty in a pylon, the way
			# out that actually works is to give up on the pylon and
			# build it square. A design did exactly that: "my pylon
			# sections dipped into the hull", and it came back with
			# stepped pylons and no angle anywhere in it. A section
			# collides as a whole and moves as a whole.
			var mine: String = placement.section
			if not mine.is_empty():
				crowded[mine] = true
				_note(issues, "overlap",
					"section '%s' runs into %s at brick %d (%s at %s "
						% [mine, who, index, placement.part,
							placement.where()]
						+ "in that section's own coordinates). Move the "
						+ "section or change its angle — the bricks "
						+ "inside it are square to each other and do "
						+ "not need rebuilding.")
				continue
			_note(issues, "overlap",
				"brick %d (%s at %s) overlaps %s%s" % [
					index, placement.part, placement.where(), who,
					_ends_at(cells_of.get(blocker - 1))])
			continue

		lattice.occupy_boxes(index + 1, packed)
		cells_of[index] = cells
		boxes_of[index] = packed
		# The corners, read off the boxes. Three checks below want them,
		# and finding them by walking every cell is nine thousand six
		# hundred reads for a number six of them give: on a ten thousand
		# brick wall that one loop was twenty seconds of the check.
		box_of[index] = BrickLattice.corners_in(packed)

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

	## Bricks that rest on something without being attached to it.
	## kind -> Array of sentences, said as advice once the faults are in.
	var loose: Dictionary = {}
	var floating: Dictionary = {}
	_check_support(model, cells_of, lattice, issues, crowded, joined,
		loose, boxes_of, floating)
	for kind: String in loose:
		var said: Array = loose[kind]
		advice.append("%s\n%s" % [kind, "\n".join(
			PackedStringArray(said.slice(0, WORTH_SAYING)))])
		if said.size() > WORTH_SAYING:
			advice[advice.size() - 1] += \
				"\n  ...and %d more like that." % (said.size() - WORTH_SAYING)

	# Every section has to be fixed to something outside itself.
	# Held together inside and touching nothing is a part that falls off
	# when the model is picked up, which is the one thing a section
	# makes easy to do by accident.
	_check_sections_attached(model, cells_of, lattice, issues, crowded,
		stuck, boxes_of)

	# And where each section that did not fit would have fitted, for as
	# long as that is worth spending.
	#
	# Measured: one failing section costs 46 seconds of sweeping, two
	# 82, four 182 — and the relay a session talks through gives up at
	# 180. A starship has four candidates, two pylons and two nacelles,
	# so a design fighting its pylons made a check that never came
	# back. A real run said so on every call after it: "the brickworks
	# server has stopped responding". This is advice. A check must not
	# spend minutes on advice.
	var hints_until: float = Time.get_unix_time_from_system() + HINTS_WITHIN
	for group: String in _sections_present(model, cells_of):
		if group.is_empty():
			continue
		if not crowded.has(group) and not stuck.has(group):
			continue
		var fits: String = _where_it_would_meet(model, group, lattice,
			part_of, hints_until)
		if not fits.is_empty():
			advice.append("Section '%s':%s" % [group, fits])

	# And whether it is made of enough different things to read as a set.
	var thin: String = _variety(model)
	if not thin.is_empty():
		advice.append(thin)

	# And whether anything is specified in a colour it was never made in.
	var unmade: String = _never_made(model)
	if not unmade.is_empty():
		advice.append(unmade)

	# And whether the outline is a staircase where it could be an edge.
	var stepped: String = _stepped_outline(cells_of, box_of)
	if not stepped.is_empty():
		advice.append(stepped)

	# And whether there is a line it would come apart along.
	var seam: String = _unbonded_seam(box_of)
	if not seam.is_empty():
		advice.append(seam)

	# And whether the whole thing is one colour.
	var plain: String = _all_one_colour(model)
	if not plain.is_empty():
		advice.append(plain)

	# And whether it is all structure and no detail.
	var coarse: String = _mostly_big_plates(model)
	if not coarse.is_empty():
		advice.append(coarse)

	# And whether a nearly-symmetric model has a brick on one side only.
	var lopsided: String = _lopsided(model, box_of, lattice)
	if not lopsided.is_empty():
		advice.append(lopsided)

	var pieces: int = _count_pieces(model, cells_of, lattice, boxes_of)

	var errors: int = 0
	for kind: String in issues:
		errors += issues[kind].size()

	var ok: bool = errors == 0 and not model.placements.is_empty()
	# What kind of problem, not merely how many.
	#
	# "156 problems" is what a run's log recorded about the worst
	# submission of a five hundred brick building, and it says nothing
	# anyone can act on — whether the design is colliding with itself,
	# hanging things in the air, or naming parts that do not exist are
	# three different faults with three different answers. The kinds are
	# already counted; this says them.
	var summary: String = "%d bricks, buildable" % model.placements.size()
	if not ok:
		var kinds: PackedStringArray = PackedStringArray()
		var named: Array = issues.keys()
		named.sort_custom(func(a: String, b: String) -> bool:
			return (issues[a] as Array).size() > (issues[b] as Array).size())
		for kind: String in named:
			kinds.append("%s %d" % [kind, (issues[kind] as Array).size()])
		summary = "%d problem%s (%s)" % [errors, "" if errors == 1 else "s",
			", ".join(kinds)]

	var feedback: String = _feedback(issues, summary, advice)
	# Said, never counted.
	#
	# Both the tool description and the prompt promised that a design is
	# checked for being in one piece, and nothing in this file computed
	# it. Now it does — but as a remark rather than an error, because a
	# model in two pieces is often exactly what was asked for (a boat
	# and a jetty, a tree beside a house) and failing it would throw
	# away a design that is otherwise correct.
	if pieces > 1:
		# "Do not touch" was the wrong word, and it was the usual case:
		# a layer of plates laid side by side is flush against itself
		# everywhere and joined nowhere, because plastic only holds
		# where a stud goes into a tube. A designer told those pieces do
		# not touch goes looking for a gap there is not.
		feedback += ("\n\nIt is in %d pieces that nothing joins. "
			% pieces
			+ "Intended, if it is meant to be a scene; worth a look "
			+ "otherwise, because a part held by nothing falls off when "
			+ "the model is picked up.")
		# And the commonest way to arrive here, which has its own fix.
		if _one_layer(box_of):
			feedback += (" This is one layer thick, and one layer is "
				+ "always like this: bricks side by side are not "
				+ "joined, however tightly they are packed. A second "
				+ "layer over it, with its joints landing across the "
				+ "joints below, is what makes the whole thing one "
				+ "piece.")

	return {
		"ok": ok,
		"summary": summary,
		"feedback": feedback,
		"advice": advice,
		"pieces": pieces,
		"kinds": issues.keys(),
		"floating": floating.keys(),
	}


## How many separate pieces the design is in.
##
## Two bricks are in the same piece when one occupies a cell directly
## above a cell of the other, or when a stud of one reaches into the
## other — the same two rules that decide whether a brick is held up,
## so a design cannot be "every brick supported" and "in five pieces"
## for contradictory reasons.
## A straight run of single-stud steps in the plan view, which is a
## diagonal built the long way round.
##
## Said as advice, never as a fault: a staircase is exactly right for
## stairs, for a stepped tower, for a ziggurat. But it is also what an
## ellipse, a swept wing, a bow and a bonnet come out as when they are
## made of rectangles, and that is the single most visible difference
## between a model that looks designed and one that looks like graph
## paper. The parts that fix it exist and are one search away; what was
## missing was anything that noticed.
##
## Four steps, because three is a chamfered corner and nobody wants to
## hear about a chamfered corner.
const SHORTEST_STAIRCASE := 4

## How long the outline scan may take. Advice, so seconds and not
## minutes.
const OUTLINE_WITHIN := 2.0

## Above this share in one colour, a model reads as unfinished rather
## than as a thing somebody chose the colours of.
##
## Measured, and the two populations do not overlap. The eight models
## that ship with the app were made by a person: their commonest colour
## is 31 to 59 per cent of the parts, across three to eight colours.
## Three starships the assistant built: 90, 93 and 95 per cent, across
## four or five. Nothing a person built goes above 59 and nothing it
## built goes below 90, so three quarters sits in the gap with room
## either side.
const MOSTLY_ONE_COLOUR := 0.75

## And below this many parts there was no real chance to vary: a
## fourteen-brick sign is one colour because it is a sign.
const WORTH_COLOURING := 40

## A part covering this many studs or more is structure rather than
## detail: a 2 x 4 is eight, a 4 x 6 is twenty-four.
const BIG_PART_STUDS := 8.0

## Above this share of big parts, a model is a massing study rather
## than a thing somebody detailed.
##
## Measured, and the populations do not overlap again. The eight models
## a person built are 9 to 44 per cent big parts; three starships the
## assistant built are 70, 73 and 75. A set is mostly small parts with
## the big plates buried inside it, which is what greebling is.
const MOSTLY_BIG := 0.60

## How long one check may spend working out where sections would fit.
##
## The sweep is thirty-two trial placements per section, and each trial
## voxelises the section against the lattice: 46 seconds for one
## failing section, measured. Four of them is three minutes, which is
## exactly where the relay a session talks through gives up.
##
## Eight and not four. A rotated part is voxelised the slow way — the
## fast path wants a square basis — so one section's sweep is about
## five and a half seconds of real work, and a four-second budget cut
## off the useful case as well as the futile one: an eight-brick model
## with a single tipped pylon was told the time had run out when the
## answer was two trials away. Eight lets one section finish. Several
## share the same eight, so the later ones are told the time ran out,
## which is bounded and true, and the check still comes back in about
## ten seconds with four of them failing.
const HINTS_WITHIN := 8.0


func _stepped_outline(cells_of: Dictionary, box_of: Dictionary) -> String:
	# One course at a time, and only the parts that are square in plan.
	#
	# Flattening the whole model into a single plan view was the first
	# way of doing this, and it is blind to the thing it was written
	# for. A starship is a saucer, a hull, two pylons, two nacelles and
	# a stand, all on top of one another in plan; the envelope of all
	# of them together is a blob with no staircase in it. Measured: a
	# 144-part Voyager whose saucer is a staircase of rectangular
	# plates, not one wedge in it, came back with no advice at all.
	#
	# And only square parts, because this reads lattice cells and the
	# lattice approximates a round brick as a staircase. A tower of
	# round bricks is round; saying it is stepped would be a complaint
	# about the measuring, not about the model.
	var longest: int = 0      ## studs across
	var deep: int = 0         ## and how far it moves in that distance
	# And a budget, for the same reason the hint sweep has one: this is
	# advice, and a check must not spend minutes on advice. A genuine
	# staircase is as deep as it is long, so a run long enough to cost
	# real time describes a diagonal hundreds of studs across — and the
	# longest one found by then is still true, merely not provably the
	# longest.
	var until: float = Time.get_unix_time_from_system() + OUTLINE_WITHIN
	for course: Variant in _courses(cells_of, box_of).values():
		if Time.get_unix_time_from_system() > until:
			break
		var layer: Array = course
		var far: Dictionary = layer[0]
		var near: Dictionary = layer[1]
		if far.size() < SHORTEST_STAIRCASE + 1:
			continue
		var found: Array = _longest_staircase(far, near)
		if int(found[0]) > longest:
			longest = int(found[0])
			deep = int(found[1])

	if longest < SHORTEST_STAIRCASE:
		return ""
	return ("The outline steps its way across %d studs while moving %d "
		% [longest + 1, deep]
		+ "deep. If that edge is meant to be a straight diagonal rather "
		+ "than stairs, wedge plates do in one part what those steps are "
		+ "doing badly — search \"wedge plate 2 x 4\". They are one "
		+ "plate thick, left and right handed, and sit in the layer "
		+ "beside ordinary plates.")


## The plan outline of each course, as [far, near] by stud x.
##
## Read off each part's box rather than off its cells. The box is
## already worked out — every other check here uses it — and a part
## that fills its box is square in plan, which is the only kind this
## should look at: the lattice approximates a round brick as a
## staircase, and calling that stepped would be a complaint about the
## measuring rather than about the model. A wedge fills its box no more
## than a round brick does, and is excluded for the same reason, which
## is right: a wedge edge is the thing being recommended.
##
## Cells are counted and never walked. The first version walked all of
## them to find out which stud columns a part covered, which is nine
## thousand six hundred per brick for a number the box gives for free.
func _courses(cells_of: Dictionary, box_of: Dictionary) -> Dictionary:
	## plate -> [far, near] by stud x
	var courses: Dictionary = {}
	for index: int in box_of:
		var corners: Array = box_of[index]
		var low: Vector3i = corners[0]
		var high: Vector3i = corners[1]
		var volume: int = (high.x - low.x + 1) * (high.y - low.y + 1) \
			* (high.z - low.z + 1)
		var filled: int = 0
		if cells_of.has(index):
			filled = (cells_of[index] as Array).size()
		if filled != volume:
			continue
		# Whole plates only, so that the stud on a part's top does not
		# give it a presence in the course above and merge two outlines
		# that have nothing to do with each other.
		var first: int = ceili(float(low.y) / BrickLattice.CELLS_PER_PLATE)
		var last: int = floori(float(high.y + 1)
			/ BrickLattice.CELLS_PER_PLATE) - 1
		if last < first:
			continue
		var from_x: int = floori(float(low.x) / BrickLattice.CELLS_PER_STUD)
		var to_x: int = floori(float(high.x) / BrickLattice.CELLS_PER_STUD)
		var from_z: int = floori(float(low.z) / BrickLattice.CELLS_PER_STUD)
		var to_z: int = floori(float(high.z) / BrickLattice.CELLS_PER_STUD)
		for plate: int in range(first, last + 1):
			if not courses.has(plate):
				courses[plate] = [{}, {}]
			var layer: Array = courses[plate]
			var far: Dictionary = layer[0]
			var near: Dictionary = layer[1]
			for at_x: int in range(from_x, to_x + 1):
				far[at_x] = maxi(far.get(at_x, to_z), to_z)
				near[at_x] = mini(near.get(at_x, from_z), from_z)
	return courses


## The longest run of even steps along either edge, as [studs, depth].
func _longest_staircase(far: Dictionary, near: Dictionary) -> Array:
	var columns: Array = far.keys()
	columns.sort()
	var longest: int = 0
	var deep: int = 0
	for edge: Dictionary in [far, near]:
		var start: int = 0
		while start < columns.size() - 1:
			# Extend while the edge stays within a stud of the straight
			# line from where the run began to where it has reached.
			#
			# The first version compared step *sizes* and allowed any
			# two adjacent ones, which reads as "a straight diagonal of
			# any slope" and is not: a two-stud step alternating with a
			# flat one is the commonest wedge slope there is, and its
			# sizes are 0 and 2, which that rule rejects. Measured on a
			# 144-part Voyager whose saucer is a staircase of plain
			# plates — every run broke at its second step and nothing
			# was ever said. Asking whether the edge is near a line
			# does not care how the steps are distributed, which is the
			# whole point: a staircase is a line drawn in steps.
			var at: int = start
			var ran: int = start
			# Whether every step so far has been the same size, which
			# makes the run exactly a line and the scan below pointless.
			#
			# An edge that does not move is the commonest case there is
			# — any flat wall — and it is also the worst for the scan,
			# because the run never breaks and every extension rechecks
			# everything before it. Quadratic in the width of the model:
			# invisible on forty studs, thirty-six seconds on a wall
			# eight hundred studs long. A run of equal steps has every
			# point exactly on its chord, deviation zero, so there is
			# nothing to measure.
			var level: bool = true
			var step_size: int = 0
			while at < columns.size() - 1 \
					and columns[at + 1] == columns[at] + 1:
				at += 1
				var span: int = columns[at] - columns[start]
				var rise: float = float(edge[columns[at]]
					- edge[columns[start]])
				var moved_by: int = edge[columns[at]] - edge[columns[at - 1]]
				if at == start + 1:
					step_size = moved_by
				elif level and moved_by != step_size:
					level = false
				if level:
					ran = at
					continue
				var straight: bool = true
				for n: int in range(start + 1, at):
					var want: float = float(edge[columns[start]]) \
						+ rise * float(columns[n] - columns[start]) \
						/ float(span)
					if absf(float(edge[columns[n]]) - want) > 1.0:
						straight = false
						break
				if not straight:
					at -= 1
					break
				ran = at
			var steps: int = ran - start
			var moved: int = absi(edge[columns[ran]] - edge[columns[start]])
			# Flat is not a staircase, and one lone step in a flat edge
			# is a jog rather than a diagonal. Nor is a very shallow
			# drift: steeper than one stud deep for every two across,
			# or the shipped tower and tree — which taper two studs
			# over five, on purpose — get told to use wedge plates, and
			# advice that fires on good models is noise. Measured at
			# one in two exactly: both of them fire. Strictly steeper:
			# neither does, and a saucer still does.
			if steps >= SHORTEST_STAIRCASE and moved * 2 > steps \
					and moved >= 2 and steps > longest:
				longest = steps
				deep = moved
			start = maxi(ran, start + 1)
	return [longest, deep]


## Is the model nearly all one colour?
##
## The checker asks whether a model stands up and never whether it
## reads as the thing it is meant to be, and colour is most of the
## difference. A real set uses several greys on purpose — plating, panel
## lines, a darker shade where a shadow would fall — and an accent or
## two. Measured on three starships the assistant built: 387 of 407
## parts in one grey, 93 per cent of another, 90 of a third. The eight
## models a person built sit between 31 and 59 per cent.
##
## Advice and never a fault. A monochrome model is right for plenty of
## things — a chess piece, a sculpture, a prototype — and the design is
## the one who knows which this is.
func _all_one_colour(model: Model) -> String:
	if model.placements.size() < WORTH_COLOURING:
		return ""
	var counted: Dictionary = {}
	var most: int = 0
	var commonest: int = 0
	for placement: Placement in model.placements:
		var now: int = int(counted.get(placement.color, 0)) + 1
		counted[placement.color] = now
		if now > most:
			most = now
			commonest = placement.color
	var share: float = float(most) / float(model.placements.size())
	if share < MOSTLY_ONE_COLOUR:
		return ""
	var named: String = "colour %d" % commonest
	if library != null:
		var colour: PartLibrary.BrickColor = library.color(commonest)
		if colour != null and not colour.name.is_empty():
			named = colour.name
	return ("%d of the %d parts are %s — %.0f%% of the model in one "
		% [most, model.placements.size(), named, share * 100.0]
		+ "colour, across %d altogether. A set uses several greys on "
		% counted.size()
		+ "purpose: a darker one where a shadow would fall, a lighter "
		+ "one for plating, a line of tiles to break up a long face, "
		+ "and an accent for the parts that are meant to catch the "
		+ "eye. The eight models this app ships are 31 to 59 per cent "
		+ "their commonest colour. If one colour is the intention — a "
		+ "sculpture, a prototype, a chess piece — then this is not a "
		+ "fault and nothing needs doing.")


## Is it all structure and no detail?
##
## The other half of "holds together perfectly and does not read as the
## thing". A hull laid in 4 x 6 plates is the right way to build a hull
## and the wrong way to finish one: what makes a set look like a set is
## the layer of small parts over the top — tiles, studs, a round plate
## for a sensor, a grille for a vent — and the big plates hidden under
## it. Measured: 284 of 407 parts on a starship were eight studs or
## bigger, against 9 to 44 per cent on the models a person built.
##
## Advice, never a fault, and only once there are enough parts to have
## had the chance.
func _mostly_big_plates(model: Model) -> String:
	if model.placements.size() < WORTH_COLOURING or library == null:
		return ""
	var big: int = 0
	var small: int = 0
	var counted: int = 0
	for placement: Placement in model.placements:
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		if info == null:
			continue
		counted += 1
		var footprint: Vector2i = info.footprint_studs()
		var studs: float = float(footprint.x) * float(footprint.y)
		if studs >= BIG_PART_STUDS:
			big += 1
		elif studs <= 2.0:
			small += 1
	if counted < WORTH_COLOURING:
		return ""
	var share: float = float(big) / float(counted)
	if share < MOSTLY_BIG:
		return ""
	return ("%d of the %d parts cover eight studs or more — %.0f%% of it "
		% [big, counted, share * 100.0]
		+ "is structure, and %d parts are small enough to be detail. "
		% small
		+ "That is the shape of a model that is built and not yet "
		+ "finished. What makes a set look like one is a layer of small "
		+ "parts over the big ones: tiles across a long face, a round "
		+ "plate for a sensor, a grille for a vent, a one-by-one in a "
		+ "second colour where a panel line would run. The eight models "
		+ "this app ships are 9 to 44 per cent big parts. If this is "
		+ "meant to be a blocked-out shape, nothing needs doing.")


## Whether the whole design sits in a single course.
##
## One layer of anything is always in as many pieces as it has parts,
## and the count on its own reads as a fault in the arrangement rather
## than as the one thing it is: nothing on top of it.
func _one_layer(box_of: Dictionary) -> bool:
	# Nothing above anything, which is not the same as "short".
	#
	# The test was whether the model stood less than a brick tall, and
	# two courses of plates is two thirds of a brick — so a disc tiled in
	# two layers, which is the first thing anybody does to make a disc
	# hold together, was told it was one layer and to add another.
	#
	# One layer means the model is exactly as tall as its tallest single
	# part: nothing is stacked on anything.
	var lowest: int = 0x7FFFFFFF
	var highest: int = -0x7FFFFFFF
	var tallest: int = 0
	for index: int in box_of:
		var corners: Array = box_of[index]
		var near: Vector3i = corners[0]
		var far: Vector3i = corners[1]
		lowest = mini(lowest, near.y)
		highest = maxi(highest, far.y)
		tallest = maxi(tallest, far.y - near.y)
	if lowest > highest:
		return false
	return highest - lowest <= tallest


## A model that is symmetric except for one or two bricks.
##
## Half-built-then-mirrored is how anything with two sides gets made, and
## getting one brick wrong in the mirroring is the commonest way it goes
## wrong — a wing a stud further out than its opposite, a nacelle a plate
## low. It is invisible in a list of placements, it survives every check
## here, and it is the first thing a person sees.
##
## The line between a mistake and a choice is how many. A house with a
## door on one side has nine bricks with no opposite number; a wing with
## one brick in the wrong place has two — itself, and the one it should
## have matched. Measured on the models that ship: car 0 of 61, tree 2 of
## 69, house 9 of 71, lighthouse 14 of 84, bench 29 of 43. So three is
## the most this will call a mistake, and it would rather miss one than
## argue with a door.
const MOST_LONELY := 3
## Below this there is no symmetry to speak of either way.
const FEWEST_FOR_SYMMETRY := 12


func _lopsided(model: Model, box_of: Dictionary,
		lattice: BrickLattice) -> String:
	if box_of.size() < FEWEST_FOR_SYMMETRY:
		return ""
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := Vector3i(-0x7FFFFFFF, -0x7FFFFFFF, -0x7FFFFFFF)
	for index: int in box_of:
		var corners: Array = box_of[index]
		var near: Vector3i = corners[0]
		var far: Vector3i = corners[1]
		lo = Vector3i(mini(lo.x, near.x), mini(lo.y, near.y), mini(lo.z, near.z))
		hi = Vector3i(maxi(hi.x, far.x), maxi(hi.y, far.y), maxi(hi.z, far.z))
	if lo.x == 0x7FFFFFFF:
		return ""

	for axis: int in [0, 2]:
		var alone: Array[int] = []
		for index: int in box_of:
			# Sampled, not weighed cell by cell. Asking the lattice
			# whether five points of the mirrored box are filled gives
			# the same answer as walking every cell of it, and walking
			# every cell of every brick was five seconds of a fourteen
			# second check on a four hundred brick model — more than a
			# third of it, for a question that is about where a part is
			# rather than what shape it is.
			var corners: Array = box_of[index]
			var near: Vector3i = corners[0]
			var far: Vector3i = corners[1]
			var filled: int = 0
			var asked: int = 0
			for point: Vector3i in _probe_points(near, far):
				var mirror: Vector3i = point
				mirror[axis] = lo[axis] + hi[axis] - point[axis]
				asked += 1
				if lattice.brick_at(mirror) != 0:
					filled += 1
			if asked > 0 and float(filled) / float(asked) <= 0.5:
				alone.append(index)
			if alone.size() > MOST_LONELY:
				break
		if alone.is_empty() or alone.size() > MOST_LONELY:
			continue
		var named := PackedStringArray()
		for index: int in alone:
			named.append(_name_of(model, index))
		return ("The model is a mirror of itself about %s, except for %s. "
			% ["its length" if axis == 0 else "its width",
				" and ".join(named)]
			+ "If it is meant to be symmetric, that is where it is not — "
			+ "and one brick out of place on one side is the thing a "
			+ "person sees first.")
	return ""


## Five points of a box: its middle and the middle of each face pair,
## pulled in a cell so a part that only touches its own edge is not
## sampled outside itself.
static func _probe_points(near: Vector3i, far: Vector3i) -> Array[Vector3i]:
	var mid := Vector3i((near.x + far.x) / 2, (near.y + far.y) / 2,
		(near.z + far.z) / 2)
	return [
		mid,
		Vector3i(near.x, mid.y, mid.z), Vector3i(far.x, mid.y, mid.z),
		Vector3i(mid.x, mid.y, near.z), Vector3i(mid.x, mid.y, far.z),
	]


## A brick as the other messages name it.
func _name_of(model: Model, index: int) -> String:
	if index < 0 or index >= model.placements.size():
		return "brick %d" % index
	var placement: Placement = model.placements[index]
	return "brick %d (%s at %s)" % [index, placement.part, placement.where()]


## A vertical line nothing bridges, with model on both sides of it.
##
## The checker knows whether a model is in one piece. It does not know
## whether that one piece would survive being picked up, and the oldest
## way to get that wrong is to stack bricks with their joints in a
## column: every course ends where the one below it ended, nothing
## bridges, and the wall splits along that line in the hand while
## passing every test here. Staggering is the first thing anyone is
## taught and the first thing a model built out of neat rectangles
## forgets.
##
## Six plates — two bricks — because one course failing to bridge is a
## corner, and two is a habit.
const WORST_SEAM := 6


func _unbonded_seam(box_of: Dictionary) -> String:
	# Per plate-layer: which stud columns hold anything, and which lines
	# between columns something crosses.
	var holds: Dictionary = {}     ## axis -> layer -> stud -> true
	var bridges: Dictionary = {}   ## axis -> layer -> line -> true
	for axis: int in [0, 2]:
		holds[axis] = {}
		bridges[axis] = {}

	for index: int in box_of:
		var corners: Array = box_of[index]
		var lo: Vector3i = corners[0]
		var hi: Vector3i = corners[1]
		var first_layer: int = floori(float(lo.y) / BrickLattice.CELLS_PER_PLATE)
		var last_layer: int = floori(float(hi.y) / BrickLattice.CELLS_PER_PLATE)
		# A part forty plates tall is a flagpole, not a wall, and walking
		# every layer of every part is the one thing here that could get
		# expensive on a four thousand piece model.
		if last_layer - first_layer > 64:
			continue
		for axis: int in [0, 2]:
			var from: int = floori(float(lo[axis]) / BrickLattice.CELLS_PER_STUD)
			var to: int = floori(float(hi[axis]) / BrickLattice.CELLS_PER_STUD)
			for layer in range(first_layer, last_layer + 1):
				if not holds[axis].has(layer):
					holds[axis][layer] = {}
					bridges[axis][layer] = {}
				for at in range(from, to + 1):
					holds[axis][layer][at] = true
				# The lines this part crosses are the ones inside it.
				for line in range(from + 1, to + 1):
					bridges[axis][layer][line] = true

	var worst: int = 0
	var where: String = ""
	for axis: int in [0, 2]:
		var layers: Array = holds[axis].keys()
		layers.sort()
		if layers.size() < 2:
			continue
		# Every line with model on both sides of it, which is the whole
		# point: a seam is a line nothing crosses, so taking the
		# candidates from what *does* cross one leaves out every line
		# this is looking for. That was the first version, and it found
		# nothing, ever.
		var lines: Dictionary = {}
		for layer: int in layers:
			for at: int in holds[axis][layer]:
				if holds[axis][layer].has(at + 1):
					lines[at + 1] = true
		for line: int in lines:
			var run: int = 0
			for layer: int in layers:
				var here: Dictionary = holds[axis][layer]
				# Only where the model is actually continuous across the
				# line. Two towers with a gap between them are two
				# towers, and nothing is wrong with that.
				if not (here.has(line - 1) and here.has(line)):
					run = 0
					continue
				if bridges[axis][layer].has(line):
					run = 0
					continue
				run += 1
				if run > worst:
					worst = run
					where = ("%s=%d" % ["x" if axis == 0 else "z", line])
			# Layers are consecutive integers only where the model is;
			# a gap in them ends a run on its own, which the loop above
			# gets wrong by one layer and nobody will ever notice.

	if worst < WORST_SEAM:
		return ""
	return ("Nothing bridges the line at %s for %d plates together. " % [
		where, worst]
		+ "Courses whose joints all land in the same place come apart "
		+ "along that line when the model is picked up — stagger them, "
		+ "so each brick sits across the joint below it.")


func _count_pieces(model: Model, cells_of: Dictionary,
		lattice: BrickLattice, boxes_of: Dictionary = {}) -> int:
	if cells_of.size() <= 1:
		return cells_of.size()

	var joined: Dictionary = {}   ## index -> Array of index
	for index: int in cells_of:
		joined[index] = []
	# What sits directly on each brick, asked as a slab across its top
	# rather than cell by cell. A brick is nine thousand six hundred
	# cells and each was a question for the lattice: free while a cell
	# was a dictionary key, and the cost of the whole check once a cell
	# became a search of the boxes near it.
	for index: int in boxes_of:
		var packed: PackedInt32Array = boxes_of[index]
		var over := PackedInt32Array()
		over.resize(packed.size())
		for n: int in range(0, packed.size(), 6):
			over[n] = packed[n]
			over[n + 1] = packed[n + 4]
			over[n + 2] = packed[n + 2]
			over[n + 3] = packed[n + 3]
			over[n + 4] = packed[n + 4] + 1
			over[n + 5] = packed[n + 5]
		for above: int in lattice.blockers_boxes(over, index + 1):
			if above > 0 and joined.has(above - 1):
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


## Which placements are held by something pushed into them, or by
## something they are pushed into.
##
## The matching itself lives in [Joints], because the booklet needs the
## same answer from a world of bricks rather than a model of placements,
## and two copies of it would drift.
func _connectors_mating(model: Model) -> Dictionary:
	var entries: Array = []
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		entries.append([index, _transform(placement, part,
			model.section_for(placement)), part])
	return Joints.both_ways(entries)


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


## Where this section would actually meet the model.
##
## A section that is turned meets a flat surface at a line or a corner,
## never squarely, so the offset at which it touches without digging in
## is narrow — measured on a four-brick pylon against a flat hull, one
## quarter of a plate wide, with overlap below it and open air above.
##
## Nothing finds that by reasoning. Three separate designs tried an
## angled pylon, were told it ran into the hull, lifted it by a whole
## plate, were told it was adrift, and concluded an angled pylon could
## not be attached in this system at all. One of them wrote exactly
## that. So when a section does not fit, say where it would.
func _where_it_would_meet(model: Model, group: String,
		lattice: BrickLattice, part_of: Dictionary, until: float) -> String:
	var section: Section = model.sections.get(group)
	if section == null:
		return ""
	var was: float = section.y

	# Is there anything in reach at all, before sweeping for it?
	#
	# The sweep is thirty-two trial placements and every one of them is
	# expensive precisely when it fails, because a section that touches
	# nothing makes the touching test look at all twenty-six
	# neighbours of every cell it has. A section parked in mid-air
	# fails all thirty-two that way. One pass over the box it could
	# reach settles whether any of them could have worked, and costs
	# about as much as a single trial.
	if not _anything_in_reach(model, group, lattice, part_of):
		var across: String = _sideways(model, group, lattice, part_of,
			until)
		if not across.is_empty():
			return across
		return (" No height within two plates of where you put it "
			+ "reaches the model at all, so this is a distance and not "
			+ "a fine adjustment: the section is in the wrong place, or "
			+ "the thing it should meet has not been built yet. "
			+ "Changing the angle will not help — measured, nothing "
			+ "within four degrees either way reaches either.")
	# Eighths, not quarters. Measured, the window where a twenty-degree
	# pylon rests against a flat hull is two eighths of a plate wide —
	# so a sweep in quarters can step over it and report that there is
	# nowhere it fits, which is worse than saying nothing.
	# Two plates either way, in eighths.
	#
	# One plate was not enough: a section declared a plate and a half
	# below where it fits was told nothing at all, which reads as "there
	# is nowhere" and is the answer that ends runs. The window itself is
	# a fraction of a plate wide, so the step has to be small and the
	# reach has to be long.
	var tried: Array = []
	for step: int in 16:
		var away: float = float(step + 1) * 0.125
		tried.append(away)
		tried.append(-away)
	for step: float in tried:
		if Time.get_unix_time_from_system() > until:
			section.y = was
			# Out of time rather than out of places. Saying nothing here
			# reads as "there is nowhere", which is the answer that ends
			# runs, so say which it was.
			return (" Where it would fit was not worked out in the time "
				+ "this check allows. Move it a quarter of a plate at a "
				+ "time, not a whole one: the offset that reaches a "
				+ "flat face is a fraction of a plate wide.")
		section.y = was + step
		if _section_sits(model, group, lattice, part_of):
			section.y = was
			# "Rest against" was the wording, and it cost a design its
			# nacelles. A model asked for Voyager read it, concluded
			# that "a hinged section has to rest on something, not just
			# touch the side", and rebuilt its angled pylons as stacks
			# of square bricks. Nothing here is about gravity: a section
			# is held by meeting anything outside itself, in any
			# direction, and sideways is the usual one.
			return (" At y=%s it meets the model instead of running "
				% Placement._num(was + step)
				+ "into it — a turned section touches a flat face at a "
				+ "corner, so the offset that reaches is narrow.")
	section.y = was
	# Something was in reach and no height put the section against it:
	# it fits between the offsets tried, or only on its other side.
	var across: String = _sideways(model, group, lattice, part_of, until)
	if not across.is_empty():
		return across
	return (" Nothing in two plates of travel either way sets it "
		+ "against the model without running into it. Move the section "
		+ "in x or z rather than in y — it is meeting the wrong face.")


## The same, across rather than up: where in x or z the section meets.
##
## The height sweep said "move it in x or z" and left the arithmetic to
## the design. Two space cruisers spent their repairs on exactly that —
## one measured its starboard pylon 0.8 studs inboard, moved it, and was
## a hairline out the other way — and both ended with nothing kept. A
## pod on a pylon meets the hull's side, so the offset that matters is
## sideways, and the lattice step is a tenth of a stud.
func _sideways(model: Model, group: String, lattice: BrickLattice,
		part_of: Dictionary, until: float) -> String:
	var section: Section = model.sections.get(group)
	if section == null:
		return ""
	for axis: String in ["x", "z"]:
		var was: float = section.x if axis == "x" else section.z
		for step: int in 20:
			for sign: float in [1.0, -1.0]:
				if Time.get_unix_time_from_system() > until:
					_put(section, axis, was)
					return ""
				var at: float = snappedf(was + sign * (step + 1) * 0.1, 0.1)
				_put(section, axis, at)
				if _section_sits(model, group, lattice, part_of):
					_put(section, axis, was)
					return (" At %s=%s it meets the model — a pylon "
						% [axis, Placement._num(at)]
						+ "meets the hull's side, so the offset that "
						+ "matters is sideways, a tenth of a stud at a "
						+ "time.")
		_put(section, axis, was)
	return ""


static func _put(section: Section, axis: String, value: float) -> void:
	if axis == "x":
		section.x = value
	else:
		section.z = value


## Could any height in the sweep's reach touch anything at all?
##
## Grown by two plates up and down, which is how far the sweep looks,
## and by one cell all round, because touching is adjacency. If nothing
## of anybody else's is inside that, no trial can succeed and sweeping
## is thirty-two expensive ways of finding that out.
func _anything_in_reach(model: Model, group: String,
		lattice: BrickLattice, part_of: Dictionary) -> bool:
	var low := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var high := Vector3i(-0x7FFFFFFF, -0x7FFFFFFF, -0x7FFFFFFF)
	var found: bool = false
	for index: int in part_of.get(group, []):
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var packed: PackedInt32Array = builder.boxes_for(part,
			_transform(placement, part, model.sections.get(group)))
		for n: int in range(0, packed.size(), 6):
			low = Vector3i(mini(low.x, packed[n]), mini(low.y, packed[n + 1]),
				mini(low.z, packed[n + 2]))
			high = Vector3i(maxi(high.x, packed[n + 3]),
				maxi(high.y, packed[n + 4]), maxi(high.z, packed[n + 5]))
			found = true
	if not found:
		return false
	var reach: int = BrickLattice.CELLS_PER_PLATE * 2
	# One box, asked once.
	#
	# This walked the whole grown volume cell by cell asking who was
	# there, which for a nacelle is hundreds of thousands of questions.
	# Each was a dictionary lookup once and is a search of the boxes
	# nearby now, and the section probe stopped finishing.
	var around := PackedInt32Array([
		low.x - 1, low.y - reach - 1, low.z - 1,
		high.x + 1, high.y + reach + 1, high.z + 1])
	for who: int in lattice.blockers_boxes(around):
		if not _is_ours(who, model, group):
			return true
	return false


## Whether the section would sit there: nothing of it inside anything
## else, and some of it against something else.
func _section_sits(model: Model, group: String, lattice: BrickLattice,
		part_of: Dictionary) -> bool:
	var touching: bool = false
	# The section's own bricks, so the lattice can drop them before
	# comparing boxes rather than after. Lattice keys count from one.
	var ours: Dictionary = {}
	for index: int in part_of.get(group, []):
		ours[index + 1] = true
	for index: int in part_of.get(group, []):
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var packed: PackedInt32Array = builder.boxes_for(part,
			_transform(placement, part, model.sections.get(group)))

		# Asked of the boxes, not cell by cell.
		#
		# This walked every cell of every brick asking the lattice who
		# was there, and then walked the outer ones again asking about
		# all twenty-six neighbours. That was affordable while a cell
		# was a dictionary key and is not now that a cell is answered by
		# searching the boxes near it — a brick is nine thousand six
		# hundred cells, and the hint search does this thirty-two times
		# per section. The section probe stopped finishing.
		#
		# One query says what it runs into. A second, on the same boxes
		# grown by a cell on every side, says what it touches: anything
		# that meets the grown box but not the original is alongside it.
		for who: int in lattice.blockers_boxes(packed, 0, ours):
			if not _is_ours(who, model, group):
				return false
		if touching:
			continue
		var grown := PackedInt32Array()
		grown.resize(packed.size())
		for n: int in range(0, packed.size(), 6):
			grown[n] = packed[n] - 1
			grown[n + 1] = packed[n + 1] - 1
			grown[n + 2] = packed[n + 2] - 1
			grown[n + 3] = packed[n + 3] + 1
			grown[n + 4] = packed[n + 4] + 1
			grown[n + 5] = packed[n + 5] + 1
		for who: int in lattice.blockers_boxes(grown, 0, ours):
			if not _is_ours(who, model, group):
				touching = true
				break
	return touching


## Whether a lattice key belongs to this section. Negative keys are
## bricks that were already on the baseplate, which are nobody's.
static func _is_ours(key: int, model: Model, group: String) -> bool:
	return key > 0 and key - 1 < model.placements.size() \
		and model.placements[key - 1].section == group


## What a placement runs into, not counting its own section.
##
## Its neighbours inside the section are checked exactly, in the frame
## they were written in; here they would collide with it simply for
## being adjacent to something that is no longer square to the grid.
static func _blockers_outside(lattice: BrickLattice,
		packed: PackedInt32Array, model: Model,
		placement: Placement) -> PackedInt64Array:
	var hit: PackedInt64Array = lattice.blockers_boxes(packed)
	if placement.section.is_empty() or hit.is_empty():
		return hit
	var others := PackedInt64Array()
	for who: int in hit:
		# Negative keys are bricks that were already on the baseplate,
		# which are nobody's section.
		if who > 0 and who - 1 < model.placements.size() \
				and model.placements[who - 1].section == placement.section:
			continue
		others.append(who)
	return others


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
		lattice: BrickLattice, issues: Dictionary,
		crowded: Dictionary = {}, stuck: Dictionary = {},
		boxes_of: Dictionary = {}) -> void:
	for group: String in _sections_present(model, cells_of):
		if group.is_empty():
			continue
		# A section that ran into something is not also adrift. Its
		# overlapping bricks were never occupied, so what is left has
		# nothing beside it — and saying both makes the two complaints
		# contradict each other. A design read that and concluded an
		# angled pylon could not be attached in this system at all,
		# which was a fair reading of what it was told.
		if crowded.has(group):
			continue
		var touches: bool = false
		var lowest: int = 0x7FFFFFFF
		# Grown by a cell on every side and asked once per brick.
		#
		# This asked about all twenty-six neighbours of every cell —
		# nine thousand six hundred cells for a 2x4, a quarter of a
		# million questions for one brick — which was affordable only
		# while a cell was a dictionary key.
		for index: int in boxes_of:
			if model.placements[index].section != group:
				continue
			var packed: PackedInt32Array = boxes_of[index]
			var grown := PackedInt32Array()
			grown.resize(packed.size())
			for n: int in range(0, packed.size(), 6):
				lowest = mini(lowest, packed[n + 1])
				grown[n] = packed[n] - 1
				grown[n + 1] = packed[n + 1] - 1
				grown[n + 2] = packed[n + 2] - 1
				grown[n + 3] = packed[n + 3] + 1
				grown[n + 4] = packed[n + 4] + 1
				grown[n + 5] = packed[n + 5] + 1
			for who: int in lattice.blockers_boxes(grown):
				if who < 0 or (who > 0
						and model.placements[who - 1].section != group):
					touches = true
					break
			if touches:
				break
		# Standing on the ground counts as being fixed to something.
		if not touches and lowest > 0:
			stuck[group] = true
			_note(issues, "section adrift",
				"section '%s' is not touching anything outside itself "
					% group + "— it is built, but it would fall off. "
					+ "Move it so it meets the part it is fixed to. "
					+ "Touching anywhere counts and in any direction: a "
					+ "pylon fixed to the side of a hull is held, and "
					+ "needs nothing underneath it.")


func _check_support(
	model: Model, cells_of: Dictionary, lattice: BrickLattice,
	issues: Dictionary, crowded: Dictionary = {},
	joined: Dictionary = {}, loose: Dictionary = {},
	boxes_of: Dictionary = {}, floating: Dictionary = {}
) -> void:
	var studs: Dictionary = _studs_reaching_in(model, cells_of, lattice)
	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		# Its section ran into something, so some of its neighbours were
		# never placed. Whether this brick is held cannot be known until
		# that is sorted out, and saying it floats is noise on top of
		# the fault that matters.
		if crowded.has(placement.section):
			continue
		var cells: Array[Vector3i] = cells_of[index]
		var floor_y: int = 0x7FFFFFFF
		for cell: Vector3i in cells:
			floor_y = mini(floor_y, cell.y)
		# Standing on the ground, read off where the brick actually
		# ended up rather than off the number that was written.
		#
		# This asked whether the written y was zero, which for a brick
		# in a section is that section's own y and not the world's — so
		# the base course of a pylon carried thirty plates into the air
		# was excused from needing anything to hold it up, and a whole
		# assembly could hang there with the check calling it sound.
		if floor_y <= 0:
			continue

		var supported: bool = false
		var sitting_on: int = 0        ## the placement underneath, if one
		# One query for the whole underside rather than one per cell.
		#
		# This asked the lattice what was under each cell of the bottom
		# face, which is eight hundred questions for a 2x4 and was free
		# while a cell was a dictionary key. It is not free now that a
		# cell is answered by searching the boxes near it, and the shape
		# of the question was always wrong: what is wanted is "is
		# anything in the slab one cell under me", which is one box.
		var under := PackedInt32Array()
		var at: int = 0
		while at < boxes_of[index].size():
			var box: PackedInt32Array = boxes_of[index]
			if box[at + 1] == floor_y:
				under.append_array(PackedInt32Array([
					box[at], floor_y - 1, box[at + 2],
					box[at + 3], floor_y, box[at + 5]]))
			at += 6
		for below: int in lattice.blockers_boxes(under, index + 1):
			supported = true
			if below > 0 and sitting_on == 0:
				sitting_on = below
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

		# Or a pin, axle or ball joins it to something.
		if not supported and joined.has(index) \
				and not (joined[index] as Dictionary).is_empty():
			supported = true

		if not supported:
			floating[index] = true
			_note(issues, "floating",
				"brick %d (%s at %s) has nothing holding it" % [
					index, placement.part, placement.where()])
			continue

		# It is held. Whether it is actually *attached* is a different
		# question, and the lattice cannot answer it: cells are 2 LDU and
		# the connection system is 20, so a part can rest on another
		# without a single stud lining up with a single tube. Both of the
		# things below were reported "buildable" before this:
		#
		#   a 2x4 on a 2x4 shifted sideways by three tenths of a stud
		#   a brick standing on a tile, clutching nothing
		#
		# Advice rather than a fault, because a real design does stand
		# parts on tiles and trap them between walls, and because the
		# tube side of a connection is not completely modelled in the
		# library — bottom_sockets exists in occupancy.py precisely
		# because the primitives do not say where every socket is.
		if sitting_on > 0 and sitting_on - 1 < model.placements.size():
			_note_loose(loose, model, index, sitting_on - 1,
				studs.has(index))


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


## Advice is not a fault.
##
## The hint that says where a section would fit was being added with
## _note, and every note is counted: errors += issues[kind].size(). So
## the one thing in here trying to help was reported as a second
## problem, and a design told "1 problem" saw "2". Said separately now,
## after the faults, and counted as none of them.
static func _feedback(issues: Dictionary, summary: String,
		advice: Array = []) -> String:
	if issues.is_empty():
		if advice.is_empty():
			return summary
		return summary + "\n" + "\n".join(advice)
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
	for word: String in advice:
		lines.append("")
		lines.append(str(word))
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
	_changed_ids = PackedInt64Array()
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
			_changed_ids.append(brick_id)
			# Where it now sits inside its section, which is what the
			# next edit will be written against.
			_remember_section(brick_id, placement, model)
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
			_changed_ids.append(brick_id)
			_remember_section(brick_id, placement, model)
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
			_remember_section(brick_id, placement, model)
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
	# And which brick belonged to which section.
	#
	# These are keyed by brick id, and BrickWorld numbers from one
	# again after a clear — so a stale entry names an ordinary brick
	# somebody places later, which would then be read back as part of a
	# section that no longer exists and moved when that section moved.
	# The same trap the scenery set carries a warning about; I walked
	# into it the same afternoon I read the warning.
	_section_of.clear()
	_local_of.clear()
	_sections.clear()


func clear_built() -> void:
	for brick_id: int in _placed_ids + _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
		_section_of.erase(brick_id)
		_local_of.erase(brick_id)
	_placed_ids = PackedInt64Array()
	_sketched_ids = PackedInt64Array()


# -- prompt --------------------------------------------------------------


func _system_prompt() -> String:
	return _rules() + _what_a_set_is_made_of() + _what_sets_are_built_from()


## The shape of a real set, read out of the catalogue rather than
## asserted here, because it is measured from every catalogued LEGO set
## and changes when the tables are refreshed.
## What real sets of this kind are built from.
##
## The one thing in here that is neither geometry nor my taste. Every
## other piece of advice about what to reach for was written by me —
## tile a roof, curve a bonnet — and a castle is not arches because I
## say so. It is arches because a hundred and seventy-five real castle
## sets use the arch door twenty-six times as often as sets at large do,
## and build in tan and pearl gold.
##
## Lift and not count, or every answer would be the same list of plates.
func _how_real_sets_build_this(subject: String) -> Dictionary:
	if library == null or library.kinds.is_empty():
		return {"content": "This build has no set data, so there is "
			+ "nothing to compare against. Design it from the "
			+ "reference and the rules."}
	var found: Array = library.kinds_for(subject)
	if found.is_empty():
		return {"content": ("No kind of real set matches \"%s\". That is "
			% subject) + "not a verdict on the idea — it means no "
			+ "catalogued set has that word in its name, which is "
			+ "true of most specific subjects. Try the plainer word "
			+ "for the thing: a word like castle, fire, space, train, "
			+ "house, tractor, pirate, dragon or police."}
	var said: PackedStringArray = PackedStringArray()
	for raw: Variant in found:
		var kind: Dictionary = raw
		said.append("\n%s — measured over %d real sets of %d"
			% [str(kind.get("kind", "")).to_upper(),
				int(kind.get("sets", 0)), library.kinds_measured_over])
		said.append("  What they are built from, and how much more often "
			+ "than sets in general:")
		for entry: Variant in kind.get("parts", []):
			var pair: Array = entry
			said.append("    %-9s x%-5s %s" % [str(pair[0]), str(pair[1]),
				_part_called(str(pair[0]))])
		var palette: PackedStringArray = PackedStringArray()
		for entry: Variant in kind.get("colors", []):
			var pair: Array = entry
			palette.append("%s (%d) x%s" % [
				_colour_name(int(pair[0])), int(pair[0]), str(pair[1])])
		if not palette.is_empty():
			said.append("  Colours they use more than other sets do: "
				+ ", ".join(palette))
		var props: Array = kind.get("props", [])
		if not props.is_empty():
			var carried: PackedStringArray = PackedStringArray()
			for entry: Variant in props:
				var pair: Array = entry
				carried.append("%s (%s)" % [_part_called(str(pair[0])),
					str(pair[0])])
			said.append("  And what they carry: " + ", ".join(carried))
	return {"content": "\n".join(said)
		+ "\n\nA multiplier is how much more often sets of this kind use "
		+ "the part than sets in general do, so a high one is what makes "
		+ "the kind look like itself. Use these where the shape calls for "
		+ "them — they are what a real designer reached for, not a list "
		+ "to fill. Check a part with search_parts before placing it."}


## A part's name as a person would read it, or its number if unknown.
func _part_called(part_id: String) -> String:
	if library == null:
		return part_id
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return part_id
	return " ".join(PackedStringArray(info.name.split(" ", false)))


func _what_a_set_is_made_of() -> String:
	if library == null or library.set_norms.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for band: Variant in library.set_norms:
		var entry: Dictionary = band
		lines.append("  %d to %d parts: about %d part-and-colour lots, "
			% [int(entry.get("from", 0)), int(entry.get("to", 0)),
				int(entry.get("lots", 0))]
			+ "%d different shapes, %d colours, and at most about %d of "
			% [int(entry.get("shapes", 0)), int(entry.get("colours", 0)),
				int(entry.get("most_of_one", 0))]
			+ "any one piece")
	return ("\n\nWHAT A SET IS MADE OF\nMeasured over every LEGO set there "
		+ "is, by size:\n" + "\n".join(lines)
		+ "\nThese are medians of real sets, not a target to hit exactly. "
		+ "What they are for is the shape of the mistake: a model that is "
		+ "the right size with a third of the variety is repetitive, and it "
		+ "reads as built rather than designed. Eighty of one brick where "
		+ "two dozen is usual means a wall was extruded instead of "
		+ "detailed. The way out is not more parts, it is more different "
		+ "parts — a tile where the wall turns, a bracket for a sign, a "
		+ "slope where the roof meets the gutter.")


## The parts real sets are built from, and nothing about taste.
##
## Everything else in this prompt about what to reach for was written by
## me: tile a roof, curve a bonnet, use a bracket for a sign. Good
## advice, and still only advice. This is the catalogue counting every
## set inventory there is, and the first thing it says is that a LEGO set
## is mostly plates — the 2x4 brick that everybody pictures when they
## think of LEGO is twenty-second on the list.
##
## Worth the room it takes because a design reaches for what it can
## remember, and what a model remembers about LEGO is bricks.
func _what_sets_are_built_from() -> String:
	if library == null:
		return ""
	var staples: Array[PartLibrary.PartInfo] = library.staples(30)
	if staples.size() < 10:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for info: PartLibrary.PartInfo in staples:
		var name: String = " ".join(
			PackedStringArray(info.name.split(" ", false)))
		lines.append("  %-8s %-42s %d sets" % [info.id, name, info.in_sets])
	return ("\n\nTHE PARTS REAL SETS ARE MADE OF\nThe thirty most used "
		+ "parts in LEGO history, counted over every catalogued set "
		+ "inventory:\n" + "\n".join(lines)
		+ "\n\nRead the shape of that list, not the individual numbers. A "
		+ "LEGO set is mostly plates: the 2x4 brick everyone pictures is "
		+ "twenty-second, under the 1x1 round plate and four sizes of "
		+ "tile. Plates let a shape be refined a plate at a time where "
		+ "bricks force it in threes, and tiles are what makes a surface "
		+ "read as a surface. If your design is mostly bricks, it is "
		+ "built the way a child builds and not the way a set is "
		+ "designed.\nThese are the parts to reach for when nothing "
		+ "special is wanted. Reach past them deliberately, not by "
		+ "accident: search_parts ranks by what sets really use, so the "
		+ "first result for a shape is usually the right one.")


func _rules() -> String:
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
  Those tenths exist for sideways work and nothing else. A part \
stacked on top of another has to be a whole stud across from it, or \
exactly half a one — a half is what a jumper plate is for. Three \
tenths of a stud is a position on the grid and not a position in \
plastic: the studs underneath land between the tubes above, gripping \
nothing, and the model falls apart when it is picked up.
  A tile, a slope and a panel have nothing on top to grip. Something \
standing on one is resting, not attached, and needs holding another \
way — a wall beside it, a bracket, a stud from the side.
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

BUILDING WITH PINS AND AXLES
Studs are not the only way parts join, and for anything with a \
mechanism — a chassis, a steering linkage, a hinge, an arm that moves — \
they are the wrong way. Technic beams join to each other with pins, \
and check_design accepts a part held by a pin, an axle or a ball joint \
exactly as it accepts one held by a stud. A beam pinned to another \
beam with nothing underneath either of them is held.
  The parts: 32523, 32316 and 32524 are Technic beams 3, 5 and 7, with \
a hole every stud along their length. 3700, 3701 and 3894 are ordinary \
bricks 1x2, 1x4 and 1x6 with holes through them, which is how a \
mechanism meets a studded wall. 2780 is the friction pin that holds \
two beams together and is the single most used Technic part there is; \
3673 is the frictionless version for something that must turn; 4274 \
is a pin with a stud on one end, which joins a hole to a stud. 3705 \
and 4519 are axles 4 and 3, which turn inside an axle hole rather \
than gripping it.
  Call search_parts for "technic beam" or "technic pin", and \
attachment_points for where the holes are. It lists every hole with \
its x, y and z and which way the hole runs, and a pin goes in at that \
position turned to run the same way. Do not work it out instead: a \
hole sits at the middle of the part's thickness, which is not a whole \
number of plates and is not the same on a beam as on a brick.

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
  Transparent is glass, a lens or a light, and nothing else. Trans \
Clear is not white — white is 15, and Trans Clear is 47. A body panel, \
a chassis or a floor in a transparent colour reads as a model somebody \
has not finished, because you can see the inside of it. If a quarter \
of what you have built is see-through, that is what has happened.
  Things that stick out — a handle, a lamp, an aerial, a wing mirror — \
are what make a shape recognisable at a glance, and they are small. A \
bar, a round plate, a 1x1 tile on a bracket.
  Scale is consistent. If a door is four bricks tall, a window is not \
six. Decide what a doorway is and let everything else follow from it.

So a 2x4 brick at y=0 occupies plates 0,1,2. The next brick on top of it \
goes at y=3. Two bricks side by side at y=0 go at x=0 and x=4.

COLOUR
A colour is an LDraw number. Do not recall one — these are the colours
sets are actually made of, and a number not in this list is very likely
either wrong or a shade that was discontinued before you were trained.

  greys and neutrals   71 light bluish grey   72 dark bluish grey
                       0 black   15 white   19 tan   28 dark tan
                       70 reddish brown   308 dark brown
  strong              4 red   320 dark red   14 yellow   25 orange
                       484 dark orange   2 green   288 dark green
                       1 blue   272 dark blue   5 dark pink
  lighter             191 bright light orange   226 bright light yellow
                       212 bright light blue   322 medium azure
                       321 dark azure   323 light aqua   27 lime
                       326 yellowish green   379 sand blue
                       378 sand green   85 medium lilac
  see-through         47 clear   36 red   34 green   40 brown

71 and 72 are the greys modern sets use. 7 and 8 are the greys sets
used until 2004 and they read as slightly green beside anything else;
do not reach for them because "grey" sounds like a low number.

Colour is not decoration, it is how a shape is read. A hull that is one
colour throughout reads as a block whatever its silhouette; the same
hull with its recesses a shade darker reads as having depth. Pick two
or three and let a fourth be the accent.

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

The axis is the hinge pin, and the sign is worth getting right first \
time — a design that guessed it built both its pylons leaning inward \
and spent a turn finding out. A positive angle:

  about z  leans the top towards -x (leftward), keeping +z forward
  about x  leans the top towards +z (backward)
  about y  swings the nose from +z towards +x, without tilting

Negate it to go the other way. For a pair of raked pylons, one is the \
negative of the other.

Something rigid and turned meets a flat face along a line, so the \
height at which a section rests against the hull without digging into \
it is a narrow band — a fraction of a plate, not a whole one. Do not \
hunt for it. When a section does not fit, the checker sweeps and tells \
you the y where it would; use that number.

Keep sections for the few places the angle is what makes the shape \
read — a raked pylon, a swept wing, an opened hatch. Everything else \
is quicker and steadier square. And if a section still will not attach \
after two tries, build that one assembly square and say so in your \
reply: a model that is ninety percent right and standing is worth more \
than a perfect pylon and nothing under it. One design spent every turn \
it had on a fifty-degree pylon and submitted nothing at all.

Inside a section, support works exactly as it does anywhere else, in \
that section's own square coordinates: a brick needs a brick beneath it \
*in the section*, not beneath it in the world. The tipping happens after. \
So a whole nacelle, a whole saucer, a whole wing can be one section, \
built flat and carried — you do not have to keep sections small to keep \
them legal.

And the section as a whole has only to touch the rest of the model. \
Anywhere, in any direction, by any part of it. Nothing has to be \
underneath it and nothing has to rest on anything. One design spent \
eight checks finding that out by experiment; it is written here so you \
do not have to.

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
Four things before the first brick, in this order:

  1. plan_scale with how long the real thing is. Everything after it \
     depends on the proportions, and changing the scale later means \
     moving the whole model.
  2. find_reference, for anything that exists. A lighthouse you recall \
     is a tapering tower with a light on top, which is every lighthouse \
     and no lighthouse. A picture gives you this one.
  3. Decide the main masses and their sizes in studs, off that picture.
  4. show_technique for any construction you have not built before. \
     Being told to stagger a wall or turn a face sideways is not the \
     same as knowing where the stud sits, and the arithmetic is the \
     part that goes wrong.

Then lay it out layer by layer from the ground up.

SAY THE SHAPE, DO NOT COUNT IT OUT
Writing placements one at a time is the part of this you are worst at, \
and most of a model is repetition. Three patterns do the counting, \
alongside the bricks you write by hand:

  repeat   the same bricks again, stepped each time. A colonnade, a row \
           of windows, a stack of courses.
  mirror   everything so far, reflected about a line. Build one side and \
           mirror it. A wing written twice is a wing a stud out on one \
           side, and a part with a hand is swapped for its twin for you.
  fill     a footprint — rectangle or ellipse — tiled with the largest \
           plates that fit, and wedge plates along an ellipse's edge \
           where a wedge's shape is the shape of that edge, so the \
           outline is a cut and not a staircase. Sixteen studs by \
           twelve is thirteen parts this way and twenty-nine by hand. A saucer twenty studs across is one line \
           here and a hundred and fifty plates by hand. Four more keys \
           turn that footprint into a solid: wall leaves the middle out, \
           layers stacks it, rise says how far apart, and shrink takes \
           studs off each layer so it tapers.

             a dome          ellipse, layers 8, shrink 2
             a cone          ellipse, layers 10, shrink 4
             a round tube    ellipse, wall 1, layers 12, rise 3
             a hull          rectangle, layers 6, rise 3, shrink 0
             a bowl          ellipse, wall 2, layers 6, shrink -2
             a wall          rectangle, wall 1, layers 12, rise 3
             a room          rectangle, wall 1, layers 4, rise 3

           Say it that way. A dome written out by hand is three hundred \
           plates, and the ones that go wrong are the ones nobody can \
           check.
           A round *tower* is the exception, and it used to say tower \
           here. An ellipse with a wall has no room for a long brick in \
           any run once it curves, so a small one comes out as a \
           staircase of 1x1 bricks: measured on a castle, 354 of them, \
           four towers' worth. Anything round and more than a couple of \
           studs across wants show_technique("wide round tower") — four \
           4x4 corner-round bricks a course, which is what real castle \
           sets use.
           Walls especially. Measured: a curtain wall 40 by 24 studs and \
           twelve courses high is 192 parts out of fill — a hundred and \
           sixty-eight 1x8 bricks and twenty-four 1x6, staggered and \
           bonded, because fill lays the longest brick that fits each \
           run. A castle run that wrote its walls out by hand instead \
           used two hundred and twenty-three 1x2 bricks: more parts, \
           every joint in a column, and a model made of two shapes \
           where a real set of that size has a hundred and seventy. If \
           a surface is a rectangle or a ring, fill it.

A four thousand part model is not too large to build. It is too large to \
dictate, which is a different problem, and this is the answer to it.

AND BEYOND THAT, A MODULE SAID AGAIN
Above a few thousand parts even patterns are not enough, because the \
reply itself runs out of room. Real large sets are not large \
descriptions: a seven thousand part model is a few hundred distinct \
parts and a great deal of repetition — a wall is one bay forty times, a \
hull is one rib twenty times, a roof is one truss again and again.
  Build the module once as a section, then repeat_section it:

    sections        [{name: "bay", x: 0, y: 0, z: 0, axis: "y", degrees: 0}]
    bricks          the bay, each brick with section: "bay"
    repeat_section  [{from: "bay", times: 39, dx: 20}]

Two hundred and fifty bricks described, ten thousand built, and they \
are checked together like anything else. Each copy is a section of its \
own named "bay 2", "bay 3", and so on, so a later edit can move or turn \
one of them without touching the rest.
  dx, dy and dz step each copy further than the last. degrees turns \
each copy further, about the section's own origin — so put that origin \
at the centre of a tower and degrees: 45, times: 7 walks the module \
round it. Both at once makes a spiral.
  Work at the scale the thing is. Do not dictate a stadium stand by \
hand because you can dictate four hundred bricks of it: decide what the \
repeating unit is, build that one well, and say how many.

HOW REAL SETS OF THIS KIND ARE BUILT
If the brief names a kind of thing real sets exist of, what those sets \
are built from arrives with it: the parts they reach for far more often \
than sets in general, and the colours they build in. A castle is arch \
doors and lattice windows in tan and pearl gold. A fire station is \
trans-blue lights, a tap, a steering stand, and red. A spaceship is \
brackets, antennas, cones and inverted dishes in white and grey. None \
of that follows from the shape, and all of it is the difference between \
a model of the thing and a model of bricks.
  It is measurement, not instruction. Use what the shape calls for and \
ignore the rest; a part that is characteristic of a kind is not a part \
every set of that kind has. But do not pass over it because you already \
have a picture in mind — the picture is what you remember of LEGO, and \
this is what LEGO did.
  how_real_sets_build_this asks the same question about anything else: \
a part of the model that is its own kind of thing, or a subject the \
brief did not name in plain words.

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

A search result says what colours the part was really moulded in, and \
that is a fact about the factory, not a preference. "made in 3 colours, \
white, black and dark bluish grey" means those three and nothing else: \
choose the colour of a wall from what its parts come in, rather than \
choosing a colour and hoping. "retired" means it has not been in a set \
for years, so prefer a current part where there is one. Results that \
say nothing about colour are parts nobody has records for, which is \
most of the library — not parts that were never sold.

SOMETHING BIG
A set-sized model — a ship, a building, a vehicle with a real interior \
— is hundreds to thousands of parts. A real LEGO set of any ambition is \
a thousand to four thousand, and nothing here stops you: the checker \
handles ten thousand parts and a model of fifty thousand fits in \
memory. If what you have built is two hundred parts and the subject \
would be two thousand, you have built a model of the model. \
There is no limit on how large the finished thing may be; there is a \
limit on how much of it you can say at once. Build it the way a set is \
designed, in stages:

  1. submit_design the structure: the masses and their proportions, a \
     few dozen parts. Get that right first, because everything after it \
     depends on the proportions being right, and fixing them later \
     means moving everything.
  2. view_model and judge those proportions against the real subject \
     before adding a single detail.
  3. edit_model to add one section at a time — a hundred to four \
     hundred parts a call is comfortable. Each one is checked against \
     everything already there, so a section that collides or floats is \
     caught while you still know what you meant by it. That is the \
     reason for building in stages, not the reply length: a reply has \
     room for well over a thousand placements, and a stage of four \
     hundred that comes back with one fault is far easier to put right \
     than a stage of two thousand.
  4. look_at_model with where= to re-read a section before changing it, \
     and view_model between sections to see what you have.
  5. Name its assemblies when you submit. Once the whole model holds \
     together and you have looked at it, each assembly also comes back \
     to you on its own, close up, with what it is made of, for a second \
     look at its detail — the way a set designer turns a gatehouse over \
     in their hands before moving on to a tower.

A reply holds roughly a thousand placements. Going near that is not \
forbidden, it is just a poor bet: everything in the call stands or \
falls together, so a single bad coordinate costs the lot. Stages of a \
few hundred are the sweet spot. If a reply ever is cut off you will be \
told so plainly, and the answer is a smaller stage, not a smaller model.

LOOK AT IT
On a big model, look closely as well as from a distance. view_model \
takes a where= box in studs and plates: a whole ship framed at once \
makes every assembly on it a few dozen pixels across, which is not \
enough to judge a shape by. Frame the saucer, then a nacelle, then the \
hull, the way you would turn a real model over in your hands.

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

And read the numbers beside the picture. Every look comes with the model
measured in studs: the whole thing, its massing course by course, and
each named section as it is carried. Those answer what a picture answers
worst. "Is the saucer the twenty-six studs I planned" is a number, not
an impression; so is whether the two nacelles match each other, and
whether the hull is deeper than it is wide. Compare them against the
sizes you decided on before the first brick, and if they disagree, the
sizes are right and the model is wrong.

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
Look at the thing first. find_reference brings back pictures of anything \
real, and the proportions of a model are decided before its first brick \
— how long against how tall, where the mass sits, what the outline does. \
Recalling a lighthouse gives you a tapering tower with a light on top, \
which is every lighthouse and no lighthouse. A picture gives you this \
one: how many times its own width it stands, where the gallery sits, how \
far the lamp room oversails it. That difference is most of what \
separates a model somebody recognises from one they have to be told \
about.

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

A straight diagonal is not stepped, though. Four plates in a staircase \
read as four plates in a staircase; one wedge plate reads as an edge. \
Search "wedge plate 2 x 4" — they run from 2 x 2 up to 6 x 12, left and \
right handed, and they are one plate thick, so they drop into any layer \
beside ordinary plates. Step where the outline curves; wedge where it \
runs straight. A saucer, a swept wing, a bow, a bonnet and a car's \
shoulder are all the second thing, and built the first way they come \
out looking like graph paper.

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


## Everything the app knows about designing well in it.
##
## The same words the design loop is given, served to whoever else is
## driving. A session outside the app has the same tools and the same
## lattice and the same catalogue; what it did not have was any of this,
## so it was left to work out from refusals that a wedge plate exists,
## that courses are staggered, that a big model goes in stages. Serving
## it from here rather than writing it again in the relay is the same
## reason the tool list is served from here: two copies of advice drift,
## and the one that drifts is the one nobody is testing.
func guidance() -> String:
	return _system_prompt()


## How a construction is actually made, in parts and coordinates.
##
## Being told to stagger a wall or turn a face sideways is not the same
## as knowing where a bracket's side stud sits, and that stud is not at a
## whole number of plates. A design that has to work it out gets it wrong
## twice and goes back to stacking bricks studs-up, which is the shape
## everything it builds then has.
func _show_technique(wanted: String) -> String:
	if wanted.strip_edges().is_empty():
		return ("Name one of: %s." % ", ".join(Techniques.names()))
	var technique: Dictionary = Techniques.named(wanted)
	if technique.is_empty():
		return ("No technique called \"%s\". There is: %s."
			% [wanted, ", ".join(Techniques.names())])

	var rows := PackedStringArray()
	for raw: Variant in technique["bricks"]:
		var brick: Dictionary = raw
		var face: String = str(brick.get("face", "up"))
		rows.append("  %-8s colour %-3s x=%-5s y=%-5s z=%-5s rot=%s%s" % [
			brick["part"], brick["color"],
			Placement._num(float(brick["x"])),
			Placement._num(float(brick["y"])),
			Placement._num(float(brick["z"])),
			brick.get("rot", 0),
			"" if face == "up" else " face=" + face])
	return ("%s — %s.\n\n%s\n\nBuilt like this, at the origin:\n%s\n\n"
		% [str(technique["name"]).capitalize(), technique["when"],
			technique["why"], "\n".join(rows)]
		+ "Move it where you need it by adding to x, y and z. Every one "
		+ "of these is checked against the same lattice your design is, "
		+ "so it holds together as it stands.")


## How big the model should be, before a brick is chosen.
##
## A designer settles the scale first, because everything after it
## depends on the proportions and fixing them later means moving the
## whole model. This one never did: it built at whatever size the first
## few bricks implied, which is how a starship and a post box come out
## the same length.
##
## The scales are the ones builders actually use. One stud to the foot
## is minifigure scale — a minifigure is four bricks and reads as a six
## foot person — and three studs to the metre is the same number said in
## metric. Below that it is microscale, where a minifigure would be a
## plate tall and the shape has to carry the whole model.
const SCALES: Array = [
	{"name": "minifigure", "studs_per_metre": 3.0,
		"note": "1 stud to the foot; a minifigure fits inside it"},
	{"name": "half minifigure", "studs_per_metre": 1.5,
		"note": "half the above; a vehicle keeps its doors and wheels"},
	{"name": "small", "studs_per_metre": 0.6,
		"note": "a house is a handful of studs; detail is shape, not parts"},
	{"name": "micro", "studs_per_metre": 0.2,
		"note": "a building is a few studs; the outline carries it"},
	{"name": "tiny", "studs_per_metre": 0.06,
		"note": "a ship on a desk; masses and nothing else"},
]
## Below this across, a model cannot show anything but its outline.
const TOO_SMALL := 8.0
## Above this, it is a display piece in two thousand parts.
const TOO_BIG := 120.0


func _plan_scale(args: Dictionary) -> String:
	var metres: float = float(args.get("longest_metres", 0.0))
	var subject: String = str(args.get("subject", "it"))
	if metres <= 0.0:
		return ("Say how long the real thing is, in metres, as "
			+ "longest_metres. A guess within half is enough — this is "
			+ "about which scale, not about the decimal.")

	var rows := PackedStringArray()
	var best: Dictionary = {}
	for one: Variant in SCALES:
		var scale: Dictionary = one
		var across: float = metres * float(scale["studs_per_metre"])
		var fits: String = ""
		if across < TOO_SMALL:
			fits = "too small to read"
		elif across > TOO_BIG:
			fits = "very large"
		elif best.is_empty():
			best = scale
			fits = "<- this one"
		rows.append("  %-16s %7s studs long   %s   %s" % [
			scale["name"], Placement._num(snappedf(across, 0.1)),
			scale["note"], fits])

	var chosen: String = ""
	if not best.is_empty():
		var across: float = metres * float(best["studs_per_metre"])
		# A plate is a third of a brick, so height in plates is what
		# actually gets placed and is worth saying out loud.
		chosen = ("\n\nAt %s scale, %s is %s studs along its longest side. "
			% [best["name"], subject, Placement._num(snappedf(across, 0.1))]
			+ "Build it at that size. Lay out the main masses first and "
			+ "check the proportions against a picture before adding "
			+ "anything. One stud across is %s metres; one plate up is %s."
			% [Placement._num(snappedf(1.0 / float(best["studs_per_metre"]), 0.01)),
				Placement._num(snappedf(
					1.0 / float(best["studs_per_metre"]) / 3.0, 0.01))]
			# Measured, and the reason this paragraph exists: given the
			# list, a run picked a scale *below* the smallest on it and
			# built a 43-stud Voyager where the list said 69, which
			# came to 144 parts against 297 for the same brief without
			# the list. Nothing was wrong with the arithmetic. The
			# model was sparing itself the typing.
			+ " Do not go smaller than this to save yourself writing "
			+ "placements. The patterns do the writing — one fill is a "
			+ "saucer — and a model built too small to read is the one "
			+ "fault no amount of revising gets out of it, because "
			+ "every detail you then want has nowhere to go.")
	else:
		chosen = ("\n\nNothing on that list reads well at %s metres. "
			% Placement._num(metres)
			+ "Build a part of it instead — a locomotive rather than the "
			+ "train, a tower rather than the whole castle — or accept "
			+ "that it will be an outline.")

	# Not capitalize(), which title-cases every word and turns a double
	# decker bus into A Double Decker Bus.
	var named: String = subject.substr(0, 1).to_upper() + subject.substr(1)
	return ("%s is %s metres along its longest side. At each scale "
		% [named, Placement._num(metres)]
		+ "builders use, the model would be:\n" + "\n".join(rows) + chosen)


## Pictures of the thing it has been asked to build.
##
## A designer given "a lighthouse" has one in front of them. This one had
## the word and whatever it could recall, and no way to check either
## against anything — which is most of the distance between what it
## builds and a set somebody would buy.
##
## Wikimedia Commons only, which is free to use and asks for nothing. The
## cost of that is the thing it does not have: a famous spaceship from a
## film is somebody's property and is not on Commons, so a search for one
## comes back with whatever shares its name. Every picture is named and
## credited in the answer for exactly that reason — the model can see it
## has been handed a 1917 destroyer and say so.
func _find_reference(subject: String) -> Variant:
	if subject.strip_edges().is_empty():
		return "Say what to look for."
	if _finder == null:
		_finder = ReferenceFinder.new()
		add_child(_finder)

	# Fields, not locals captured by the lambdas below.
	#
	# A GDScript lambda captures by value, so assigning to a local from
	# inside one changes the copy and nothing else. Both of these set
	# "we are done" on a copy, the wait ran its full forty-five seconds
	# every time, and the answer was always "no pictures came back" — of
	# a lookup that had in fact come back.
	_lookup_pictures = []
	_lookup_trouble = ""
	_lookup_waiting = true
	var done := func(got: Array) -> void:
		_lookup_pictures = got
		_lookup_waiting = false
	var failed := func(why: String) -> void:
		_lookup_trouble = why
		_lookup_waiting = false
	_finder.found.connect(done, CONNECT_ONE_SHOT)
	_finder.missed.connect(failed, CONNECT_ONE_SHOT)
	_finder.look_for(subject)
	# Bounded in seconds, not in frames.
	#
	# Frames are not time. A headless run draws thousands a second, so
	# eighteen hundred of them is under a second — long enough for
	# nothing at all, and the lookup answered "no pictures came back"
	# before the request had left the machine.
	var give_up_at: int = Time.get_ticks_msec() + LOOKUP_MS
	while _lookup_waiting and Time.get_ticks_msec() < give_up_at:
		await get_tree().process_frame
	if _finder.found.is_connected(done):
		_finder.found.disconnect(done)
	if _finder.missed.is_connected(failed):
		_finder.missed.disconnect(failed)

	var pictures: Array = _lookup_pictures
	if pictures.is_empty():
		return ("No pictures of \"%s\" came back%s. Build it from what " % [
			subject, "" if _lookup_trouble.is_empty() else " — " + _lookup_trouble]
			+ "you know of it, and look at what you build.")

	var blocks: Array = [{"type": "text", "text":
		("%d picture%s of \"%s\", from Wikimedia Commons. Check each one "
			% [pictures.size(), "" if pictures.size() == 1 else "s", subject]
			+ "is the thing you were asked for before you build to it: "
			+ "Commons carries what is free to use, so a name can bring "
			+ "back something else that shares it.")}]
	for one: Variant in pictures:
		var picture: Dictionary = one
		var encoded: String = Marshalls.raw_to_base64(picture["bytes"])
		# Kept, where a draft is not. The subject has to still be there
		# when the detailing starts, which is the point at which the
		# sweep that drops old pictures would otherwise have taken it.
		_kept_pictures[encoded] = true
		blocks.append({"type": "text", "text": "%s — %s"
			% [picture["title"], picture["credit"]]})
		blocks.append({
			"type": "image",
			"source": {
				"type": "base64",
				"media_type": "image/png",
				"data": encoded,
			},
		})
	return blocks


## How long to wait for pictures. Four searches and three downloads over
## somebody's connection, and then the design carries on without them.
const LOOKUP_MS := 45000

var _finder: ReferenceFinder = null
var _lookup_pictures: Array = []
var _lookup_trouble: String = ""
var _lookup_waiting: bool = false


## The tools, as the model is offered them.
##
## Public because something other than the loop serves them now: a
## session outside the app can be handed this same list and call into
## the same implementations, which is the only way the two cannot drift.
func tool_catalogue() -> Array:
	return _tools()


## Run one tool the way a design run would.
##
## submit_design gets the step the loop takes next as well. Inside the
## loop, submitting sets a design aside and the loop then checks it and
## stands it up; called from outside, nothing would, and a caller would
## get "Received. Checking it now." for a design that was never checked
## and never built.
func use_tool(name: String, input: Dictionary) -> Variant:
	var answer: Variant = await _run_tool({"name": name, "input": input})
	if name != "submit_design" or _pending == null:
		return answer
	var design: Model = _pending
	_pending = null
	var report: Dictionary = _check(design)
	if not bool(report["ok"]):
		return "Not applied — it does not hold together yet.\n%s" \
			% report["feedback"]
	await _ensure_parts(design)
	_apply(design)
	return "Built. %d bricks on the baseplate. %s" % [
		design.placements.size(), report["summary"]]


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

	# A shape described rather than counted out.
	var pattern: Dictionary = {
		"type": "object",
		"properties": {
			"pattern": {"type": "string",
				"enum": ["repeat", "mirror", "fill"],
				"description":
					"repeat: the bricks again, stepped each time. "
					+ "mirror: everything so far, reflected about a line "
					+ "— build one side and mirror it rather than "
					+ "writing both. fill: a footprint tiled with the "
					+ "largest plates that fit — and with layers, a "
					+ "shrink and a wall it is a dome, a cone, a hull, "
					+ "a tube or a bowl in one object."},
			"times": {"type": "integer", "description": "repeat: how many"},
			"step": {"type": "object", "description":
				"repeat: how far each copy moves, in studs and plates",
				"properties": {"x": {"type": "number"},
					"y": {"type": "number"}, "z": {"type": "number"}},
				"additionalProperties": false},
			"about": {"type": "string", "enum": ["x", "z"],
				"description": "mirror: which way the line runs"},
			"at": {"description":
				"mirror: the line to reflect about, in studs. fill: where "
				+ "the footprint's low corner sits, as {x, y, z}."},
			"shape": {"type": "string", "enum": ["rectangle", "ellipse"],
				"description": "fill: which footprint"},
			"across": {"type": "number", "description": "fill: studs in x"},
			"deep": {"type": "number", "description": "fill: studs in z"},
			"color": {"type": "integer", "description": "fill: the colour"},
			"wall": {"type": "number", "description":
				"fill: leave the middle out, this many studs in from "
				+ "every side. An ellipse with wall 1 is a round tube; "
				+ "a rectangle with wall 1 is a room's walls."},
			"layers": {"type": "number", "description":
				"fill: how many of the footprint, stacked up"},
			"rise": {"type": "number", "description":
				"fill: plates between layers. 1 for plates, which is "
				+ "the default; 3 for courses of bricks."},
			"shrink": {"type": "number", "description":
				"fill: studs off each layer, taken half from each side, "
				+ "so the stack tapers as it rises. Must be even. 2 is "
				+ "a dome, 4 a steep cone, 0 a straight-sided hull, and "
				+ "-2 flares outward."},
			"bricks": {"type": "array", "items": brick, "description":
				"repeat: what to repeat. mirror: what to reflect, if not "
				+ "everything so far."},
		},
		"required": ["pattern"],
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

	# One built section, said again somewhere else. A large model is
	# repetition, and this is how it is said.
	var repeat_section: Dictionary = {
		"type": "object",
		"properties": {
			"from": {"type": "string", "description":
				"the name of a section that already has bricks in it"},
			"times": {"type": "integer", "description":
				"how many copies to make, each one step further than "
				+ "the last"},
			"dx": {"type": "number", "description":
				"studs across, per copy"},
			"dy": {"type": "number", "description": "plates up, per copy"},
			"dz": {"type": "number", "description":
				"studs deep, per copy"},
			"degrees": {"type": "number", "description":
				"turned this much further per copy, about the section's "
				+ "own origin. Put that origin at the centre of a tower "
				+ "and this walks the copies round it."},
			"axis": {"type": "string", "enum": ["x", "y", "z"],
				"description":
					"which way that pin runs. Defaults to the source "
					+ "section's."},
			"name": {"type": "string", "description":
				"what to call the copies. They are numbered from 2."},
		},
		"required": ["from", "times"],
		"additionalProperties": false,
	}

	# A named part of the model and the box it sits in, for detailing
	# one at a time. Not a section: nothing is moved or turned by it.
	var assembly: Dictionary = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "description":
				"what a person would call it, e.g. north-east tower"},
			"x_from": {"type": "number"},
			"x_to": {"type": "number"},
			"y_from": {"type": "number", "description":
				"may be left out, for all of its height"},
			"y_to": {"type": "number"},
			"z_from": {"type": "number"},
			"z_to": {"type": "number"},
		},
		"required": ["name", "x_from", "x_to", "z_from", "z_to"],
		"additionalProperties": false,
	}

	return [
		{
			"name": "search_parts",
			"description": ("Find real parts by description. Returns part "
				+ "numbers with their footprint, height and the colours "
				+ "they were really made in. Use this instead of "
				+ "guessing a part number."),
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
					"patterns": {"type": "array", "items": pattern},
					"sections": {"type": "array", "items": section},
				},
				"required": ["bricks"],
				"additionalProperties": false,
			},
		},
		{
			"name": "show_technique",
			"description": ("How a construction is actually made, in "
				+ "part numbers and coordinates: %s. "
				% ", ".join(Techniques.names())
				+ "Ask before building one of these for the first time "
				+ "— a bracket's sideways stud is not at a whole number "
				+ "of plates, and the arithmetic is the part that goes "
				+ "wrong. Every one of them is checked against the same "
				+ "lattice your design is."),
			"input_schema": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "description":
						"which one; a partial name will do"},
				},
				"required": ["name"],
				"additionalProperties": false,
			},
		},
		{
			"name": "plan_scale",
			"description": ("How big the model should be, worked out "
				+ "before anything is placed. Give the real thing's "
				+ "longest dimension in metres and this answers with "
				+ "what it comes to in studs at each scale builders "
				+ "use, and which one is worth building at. Settle this "
				+ "first: everything after it depends on the "
				+ "proportions, and changing it later means moving the "
				+ "whole model."),
			"input_schema": {
				"type": "object",
				"properties": {
					"subject": {"type": "string"},
					"longest_metres": {"type": "number", "description":
						"how long the real thing is along its longest "
						+ "side. A guess within half is enough."},
				},
				"required": ["longest_metres"],
				"additionalProperties": false,
			},
		},
		{
			"name": "find_reference",
			"description": ("Pictures of a real thing, so you can build "
				+ "to what it looks like rather than to what you recall "
				+ "of it. Ask for this first for any subject that exists "
				+ "— a lighthouse, a tractor, a kingfisher, a particular "
				+ "building — and judge the proportions off the picture "
				+ "before you place a brick. The pictures come from "
				+ "Wikimedia Commons, which carries what is free to use: "
				+ "each is named and credited, and a famous ship from a "
				+ "film will not be there, so check what came back is "
				+ "the thing before building to it."),
			"input_schema": {
				"type": "object",
				"properties": {
					"subject": {"type": "string", "description":
						"what to look for, in the words you would use "
						+ "looking it up — \"Fresnel lighthouse lantern "
						+ "room\" rather than \"lighthouse\" when it is "
						+ "a detail you are after"},
				},
				"required": ["subject"],
				"additionalProperties": false,
			},
		},
		{
			"name": "how_real_sets_build_this",
			"description": ("What real LEGO sets of this kind are "
				+ "actually built from — the parts they reach for far "
				+ "more often than sets in general, and the colours "
				+ "they use. Measured over fifteen thousand real sets, "
				+ "so it is what LEGO's own designers did and not "
				+ "advice.\n\nCall it for any subject that is a kind of "
				+ "set: a castle, a fire station, a spaceship, a train, "
				+ "a house, a tractor, a police car. A castle set is "
				+ "arch doors and lattice windows in tan and pearl "
				+ "gold; a fire station is trans-blue lights, taps and "
				+ "red; a spaceship is brackets, antennas, cones and "
				+ "inverted dishes in white and grey. That is the "
				+ "difference between a model of the thing and a model "
				+ "of bricks, and you cannot get it from the shape "
				+ "alone.\n\nGive the plain word for the thing. Nothing "
				+ "matches a specific name."),
			"input_schema": {
				"type": "object",
				"properties": {
					"subject": {"type": "string", "description":
						"the kind of thing being built, in plain words "
						+ "— \"fire station\", \"medieval castle\", "
						+ "\"spaceship\""},
				},
				"required": ["subject"],
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
				+ "plates and the arithmetic is easy to get wrong. It "
				+ "also draws the shape of any part that is not a plain "
				+ "box: which way a wedge plate tapers, which way a "
				+ "slope falls, where an arch is open. Ask before using "
				+ "one of those for the first time — a wedge put on "
				+ "backwards looks exactly like a wedge until you look "
				+ "at it."),
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
					"repeat_section": {"type": "array",
						"items": repeat_section, "description":
							"say a section again somewhere else. One bay "
							+ "of a wall, repeated — rather than forty "
							+ "bays dictated."},
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
					"where": {
						"type": "object",
						"description": ("Look closely at one part of "
							+ "the model rather than all of it, in "
							+ "studs and plates. The rest is still in "
							+ "the picture, just not filling it. On a "
							+ "big model a single assembly is a few "
							+ "dozen pixels across otherwise, which is "
							+ "not enough to judge its shape by."),
						"properties": {
							"x_from": {"type": "number"},
							"x_to": {"type": "number"},
							"y_from": {"type": "number"},
							"y_to": {"type": "number"},
							"z_from": {"type": "number"},
							"z_to": {"type": "number"},
						},
						"required": ["x_from", "x_to", "y_from", "y_to",
							"z_from", "z_to"],
						"additionalProperties": false,
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
					"patterns": {"type": "array", "items": pattern},
					"sections": {"type": "array", "items": section},
					"repeat_section": {"type": "array", "items": repeat_section},
					"assemblies": {"type": "array", "items": assembly,
						"description":
							"the parts of this model a person would "
							+ "name — the gatehouse, each tower, each run "
							+ "of wall, the keep — each a box in studs "
							+ "and plates. Once the model holds together "
							+ "and you have looked at it whole, each one "
							+ "is shown to you close up, on its own, to "
							+ "detail. A model that is one thing is one "
							+ "assembly."},
				},
				"required": ["name", "description", "bricks", "assemblies"],
				"additionalProperties": false,
			},
		},
	]
