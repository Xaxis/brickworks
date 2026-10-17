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
## Every request goes from this machine straight to Anthropic, on a key
## of the person's own. There is no server of ours in the path.
class_name Assistant
extends Node

## How many times to ask again when the connection drops, before
## giving up on a design that may have been running for a long time.
const TRIES_WHEN_DROPPED := 4

## Anthropic's Messages API, where every turn of a design goes.
const MESSAGES_URL := "https://api.anthropic.com/v1/messages"
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
## Turns one feature gets (see [method _feature_brief]): a look, a placing
## and a fix, and the answer saying which it used.
const TURNS_PER_FEATURE := 4
const MOST_FEATURES := 8
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
## The ways a part's joint can be said to run, for a placement's axis.
const AXES: Dictionary = {"x": Vector3.RIGHT, "-x": Vector3.LEFT, "y": Vector3.UP,
	"-y": Vector3.DOWN, "z": Vector3.BACK, "-z": Vector3.FORWARD}

## The colour of a brick that names none: Light Bluish Grey, the grey
## modern sets are built in, and what a fill already defaults to. It was
## 7, Light Grey, which LEGO replaced in 2004 — the last set with it is
## from 2007 — and which reads green beside anything current.
const DEFAULT_COLOUR := 71

var library: PartLibrary
var world: BrickWorld
var builder: Builder
## Where requests go. Anthropic, always, except in a probe that points
## it at a port nothing listens on to watch a connection drop.
var endpoint: String = MESSAGES_URL
## Set from the environment on a developer's machine. A key the person
## pasted into the app is not this — see [method key_in_use], which
## prefers theirs.
var direct_key: String = ""

## Whether to read the answer as it is written. Off for anything running
## without a scene tree to wait on, and available to turn off if a
## network somewhere refuses to pass a stream through.
var stream_replies: bool = true


## The key this request will go out with, and therefore where it goes.
##
## A key belonging to the person using the app wins over one from the
## environment: on a machine that has both, theirs is the one they
## chose. Empty means there is no key, and nothing is sent.
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
## Brick id -> the name a design gave it, which a later edit attaches to it
## by (Placement.name).
var _given_names: Dictionary = {}
## Brick id -> [x, y, z, face, rot, nudge] of a brick in no section seated
## past its lattice cell, as it was written: read back as it was while it
## still stands where that puts it.
var _nudged: Dictionary = {}
## Sections found for bricks that came without one (see [method _adopted]),
## by what they share, and the world generation they were found in.
var _adoptions: Dictionary = {}
var _adoptions_of: int = -1


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


## The picture the person chose to make into a mosaic, for make_art.
var art_source: Image = null
## How many times make_art has laid the picture named [member _art_name]:
## the first look, then a revision or two (ArtPlan.next_step).
var _art_laid: int = 0
var _art_name: String = ""
## Said when make_art has laid a picture, for the window to look at it.
signal art_laid(art: MosaicArt.Art)


## The picture to make LEGO Art of: the one chosen for a mosaic, or failing
## that the first one the person gave of what they want. Null if neither.
func art_picture() -> Image:
	if art_source != null and not art_source.is_empty():
		return art_source
	for block: Dictionary in references:
		var image := Image.new()
		var bytes: PackedByteArray = Marshalls.base64_to_raw(
			str((block.get("source", {}) as Dictionary).get("data", "")))
		if not bytes.is_empty() and image.load_png_from_buffer(bytes) == OK:
			return image
	return null


## make_art: a plan read at the edge, laid, and put down in place of what
## was there, as the mosaic dialog's Build does. The answer is the picture
## face on, for whoever made the plan to judge it by.
func _make_art(args: Dictionary) -> Variant:
	var plan: ArtPlan = ArtPlan.parse(args, library)
	if not plan.ok():
		progress.emit("a Brick Art plan that could not be laid")
		return plan.trouble()
	var art: MosaicArt.Art = plan.lay(art_picture(), library)
	if art == null:
		return plan.trouble()
	if art.placements.is_empty():
		return "Nothing was laid: the picture came to no studs."
	if world == null or builder == null:
		return "There is no baseplate here to lay it on."
	await _ensure_parts(art.model())
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	scenery.clear()
	forget_built()
	_placed_ids = MosaicArt.put_down(art, world, builder, self)
	_pending = null
	# A finished piece of work, as an edit is: a run that lays it and says
	# so has finished, rather than being asked to build something.
	_edited = true
	if not _busy:
		_outside_standing = true
		_outside_assemblies = []
	if not plan.name.is_empty():
		titled.emit(plan.name)
	art_laid.emit(art)
	built.emit(_placed_ids.size())
	var said: String = ArtPlan.said_of(art)
	progress.emit("laid a Brick Art picture: %d parts" % _placed_ids.size())
	# Laid again under the same name is a revision of the same picture.
	if plan.name.to_lower() != _art_name:
		_art_name = plan.name.to_lower()
		_art_laid = 0
	_art_laid += 1
	# Face on, as a person sees it on the wall: rendered where there is a
	# renderer, drawn element by element where there is not.
	var seen: Dictionary = {}
	if ModelShot.possible():
		seen = await _ensure_shot().block(world, "face", scenery)
	var shown: String = "This is it face on, as it hangs on a wall:"
	if seen.is_empty():
		var face: Image = MosaicArt.picture_of(art, library,
			clampi(768 / maxi(art.plan.across, art.plan.down), 4, 12))
		seen = {"type": "image", "source": {"type": "base64", "media_type": "image/png",
			"data": Marshalls.raw_to_base64(face.save_png_to_buffer())}}
		shown = ("This is it face on, each element drawn as its shape and lighter the "
			+ "higher it stands:")
	return [
		{"type": "text", "text": "Laid (%s). %s\n\n%s" % [
			"first look" if _art_laid == 1 else "revision %d" % (_art_laid - 1), said,
			ArtPlan.measured(art, library)]},
		{"type": "text", "text": shown},
		seen,
		{"type": "text", "text": "%s\n\n%s\n\n%s" % [ArtPlan.CRITIQUE, ArtPlan.REFERENCE,
			ArtPlan.next_step(_art_laid)]},
	]


## look_at_picture: what make_art would lay, for a session that cannot
## otherwise see it — Claude Code over MCP is given a sentence, not the
## picture.
func _look_at_picture() -> Variant:
	var picture: Image = art_picture()
	if picture == null:
		return ("No picture has been chosen. Draw one as make_art's svg: big simple "
			+ "shapes in flat colours, one stud a pixel.")
	var shown: Image = picture.duplicate()
	var widest: int = maxi(shown.get_width(), shown.get_height())
	if widest > REFERENCE_SIZE:
		var scale: float = float(REFERENCE_SIZE) / widest
		shown.resize(maxi(1, int(shown.get_width() * scale)),
			maxi(1, int(shown.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return [
		{"type": "text", "text": ("The picture to make into Brick Art, %d x %d pixels. "
			% [picture.get_width(), picture.get_height()]
			+ "Plan it with make_art; coordinates are fractions of it, 0 to 1 from the "
			+ "top left, after any crop.")},
		{"type": "image", "source": {"type": "base64", "media_type": "image/png",
			"data": Marshalls.raw_to_base64(shown.save_png_to_buffer())}},
	]
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
## The features the design listed, worked before the assemblies, and
## whether what each came to has been said.
var _features: Array[String] = []
var _features_told: bool = false
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
## What a session from outside has said its subject is, before any design
## names it: the brief Claude Code was started with ([method heard]), and the
## subject plan_scale, find_reference and how_real_sets_build_this were asked
## about. check_design carries no name, so without this a figure checked
## before its first submit was a subject of no kind, and told of towers.
var _heard: String = ""
## The brief a session was started on, which outlives a clear_model inside it.
var _heard_fresh: String = ""
## What the person owns ("part/colour" -> how many, CollectionStore.on_hand),
## for a brief that asks to be built from their collection
## (Collection.wanted_in). Empty when nothing is known.
var owned: Dictionary = {}
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

## Bricks that belong to the workspace rather than to any model — the
## baseplate. Set by whoever owns the scene; left empty, a snapshot
## would take the baseplate with it and put back a second one.
var scenery: Dictionary = {}
## What the app's floor is (ModelFloor.KINDS), set by whoever owns the scene:
## on a bare floor what only the floor holds must balance (ExactCheck.tips).
var floor_kind: Callable = Callable()

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
## The design standing calls itself this: the name submit_design gave it.
signal titled(name: String)
## What the design said it stands on (submit_design's floor): {"kind":
## ModelFloor's, "colour": an LDraw code or -1, "part": whether a baseplate
## goes in the box as part of the build}. Main lays it; the person can
## change it after, in View, Floor.
signal floor_chosen(choice: Dictionary)
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
	## For a part that joins by a line (a pin, an axle, a gear, a bush, a
	## beam's hole): the way that line runs, one of [constant AXES]. Then
	## x, y and z are where the line's middle goes, which is the point
	## attachment_points gives for a hole, and not the part's low corner;
	## rot turns it about the line. Read into the low corner before
	## anything else sees it (Assistant._onto_lines). Empty for the corner.
	##
	## A hole is said by where it is, and a placement was only ever said by
	## its corner. A session told "a pin goes in at the position given" put
	## the pin's corner there, half a pin off the hole, and every pin and
	## axle it tried was refused as an overlap with the brick it was meant
	## to be in.
	var axis: String = ""
	## Which of its joints goes there, as attachment_points numbers them; -1
	## for the one nearest its middle.
	var joint: int = -1
	## Why an axis could not be read, for the check to say.
	var odd_axis: String = ""
	## The section this brick belongs to, or empty for the main body.
	## Its coordinates are then that section's own, not the world's.
	var section: String = ""
	## A tile or round plate laid on a side stud to finish a face
	## (Assistant._dress). Finish, not structure: where it would overlap
	## a brick, it is the thing left out (Assistant._give_way).
	var dressing: bool = false
	## The assembly the brick is in on the baseplate — a file's sub-model,
	## a run's named part, a figure — or empty. What lets a piece that
	## stands apart on purpose (a stand, a sign) be told from one that came
	## loose (Assistant._standing_apart).
	var group: String = ""
	## And which copy of which sub-model, as the brick has it
	## (BrickWorld.Brick.unit): what makes a hose laid as one item one thing
	## to the check, as it is to the parts list (Joints.held_otherwise).
	var unit: String = ""
	## A turn of this one part, yaw then pitch then roll in degrees, about
	## its own corner: zero for none. Read into a section of its own before
	## anything else sees it ([method Assistant._turned_parts]), since a part
	## turned off the grid is checked as a section is.
	var turn := Vector3.ZERO
	## Where the brick it was read from really stands (a Transform3D), or
	## null for a placement that is not in the world. The reading of a part
	## turned two ways, or drawn off its box, is not quite where it is; the
	## exact check (ExactCheck) judges what stands by where it stands.
	var standing_at: Variant = null
	## The part that stands there, which an edit may change.
	var standing_part: String = ""
	## LDU past the 2 LDU lattice cell x, y and z put it in, for a part seated
	## on a connector the cells cannot say (ExactCheck.seat): a round part's
	## stud an LDU off the cell its corner falls in.
	var nudge := Vector3.ZERO
	## What a later part of the same design or edit attaches to it by: "torso"
	## in "torso.hinge[0]". Empty for none.
	var name: String = ""
	## Put on another part by their connectors, as BrickAgent's attach puts
	## one ({to, by, yaw, align, orient, flip, slide, seat}), until the app has
	## worked out where that is ([method Assistant._attach_parts]); then empty,
	## and x, y, z, face, rot, nudge and section say it.
	var attach: Dictionary = {}
	## The part it was attached to, and by which two connectors, said: what
	## the check holds it by where the lattice cannot see the joint.
	var attached_to: Placement = null
	var attached_by: String = ""
	## Why an attach could not be done as asked, for the check to say.
	var odd_attach: String = ""

	## Where the exact check takes this to be: where it stands while it is
	## standing and unmoved, else [param built] (where it will be built).
	func exact_at(built: Transform3D) -> Transform3D:
		if id != 0 and not moved and standing_at is Transform3D and standing_part == part:
			return standing_at
		return built

	static func from_dict(raw: Dictionary) -> Placement:
		var p := Placement.new()
		p.part = str(raw.get("part", ""))
		p.color = int(raw.get("color", DEFAULT_COLOUR))
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
		var line: String = str(raw.get("axis", "")).strip_edges().to_lower().trim_prefix("+")
		if AXES.has(line):
			p.axis = line
		elif not line.is_empty():
			p.odd_axis = "asks for axis '%s'; the six are x, -x, y, -y, z and -z" % line
		p.joint = int(raw.get("joint", -1))
		p.section = str(raw.get("section", "")).strip_edges()
		p.dressing = bool(raw.get("dressing", false))
		p.turn = Vector3(float(raw.get("yaw", 0)), float(raw.get("pitch", 0)),
			float(raw.get("roll", 0)))
		p.name = str(raw.get("name", "")).strip_edges()
		var joint: Variant = raw.get("attach")
		if joint is Dictionary and not (joint as Dictionary).is_empty():
			p.attach = (joint as Dictionary).duplicate(true)
			# The joint's angle, said on the part instead of its attach: the
			# only angle a part on a joint has is the joint's.
			if not p.attach.has("yaw") and not p.attach.has("orient") \
					and not is_zero_approx(p.turn.x):
				p.attach["yaw"] = p.turn.x
			if p.turn.y != 0.0 or p.turn.z != 0.0:
				p.odd_attach = ("is attached and also given a pitch or roll of its own; a part "
					+ "on a joint turns as the joint does: give the attach a yaw (about its "
					+ "axis), an align or, on a ball, an orient")
			p.turn = Vector3.ZERO
		elif joint != null and not (joint is Dictionary):
			p.odd_attach = ("has attach %s, which is not an object like {\"to\": "
				% JSON.stringify(joint) + "\"torso.hinge[0]\", \"by\": \"hinge[0]\", \"yaw\": 30}")
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
		p.axis = axis
		p.joint = joint
		p.odd_axis = odd_axis
		p.section = into
		p.dressing = dressing
		# Where it sits past its cell, as a part seated by its connector does.
		p.nudge = nudge
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
##
## Turned any way at all: yaw, then pitch, then roll, or an axis and an
## angle. One axis was all a section had, and a dome's panel needs two —
## one to face it round the dome, one to tip it back to the curve — so a
## session given one axis built a pyramid, its panels facing four ways. And
## built inside another section ([member within]), which is how a real set
## chains its hinged panels: 10143's shell is sixteen segments each turned
## 22.5 degrees from the last, every one carrying panels hinged to it.
class Section extends RefCounted:
	var name: String
	var x: float = 0.0        ## studs, where the section's origin sits
	var y: float = 0.0        ## plates
	var z: float = 0.0        ## studs
	var axis: String = "z"    ## which way the hinge pin runs: x, y or z
	## An axis given as a direction instead of a letter, or zero.
	var axis_way := Vector3.ZERO
	var degrees: float = 0.0
	## Degrees, applied yaw first, then pitch, then roll, about the
	## section's origin in its parent's coordinates. The section's own +z is
	## its nose: yaw swings it towards +x about the upright, pitch lifts it,
	## roll lifts its +x side.
	var yaw: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	## The section this one is built in: its x, y, z and its hinge's base are
	## then in that section's own coordinates, and it goes where that one
	## goes. Empty for the model's own.
	var within: String = ""
	var parent: Section = null
	## Built on a joint whose two halves the app lays: x, y and z are then
	## where the joint's base stands, like any brick's, the section's own
	## coordinates start on the top half's studs, and it turns about the
	## joint's real line. The app puts the halves in and finds the line
	## ([method Assistant._fit_hinge]): working it out by hand is the
	## arithmetic designs get wrong, and since a lean has to turn on a
	## joint, it is the arithmetic every lean needs. [member hinge_kind]
	## says which joint, one of [constant Hinges.KINDS].
	var hinge: bool = false
	var hinge_kind: String = Hinges.TILTING
	var hinge_color: int = 72
	## For a hinged section, in LDU: the line from the base's corner, and
	## the section's own origin from it.
	var pin_from_corner := Vector3.ZERO
	var origin_from_pin := Vector3.ZERO
	## The quarter turns the joint's two halves are laid at.
	var base_rot: int = 0
	var top_rot: int = 0
	## Where the top half's corner sits in the section's own studs and
	## plates: so that its first stud stands at the origin's, and the
	## section's bricks start on its studs. Below the origin by its height,
	## and back or down further where its joint stands out of its body — a
	## clip's round reaches past the plate it is on.
	var top_at := Vector3(0, -2, 0)
	## Set on the section the app makes to hold a hinge's base when the
	## hinge is turned off the square: the name of the section it is the
	## base of. Its frame is that section's hinge frame, so the two cannot
	## disagree.
	var base_for: String = ""
	var base_of: Section = null
	## What could not be read as asked, for the check to say.
	var odd: String = ""

	## Read from what a design or an edit said. [param was] is the section
	## of that name already there, for an edit that only says what changes.
	static func from_dict(raw: Dictionary, was: Section = null) -> Section:
		var s := Section.new() if was == null else was.copied(was.name)
		if was != null:
			s.within = was.within
			s.base_for = was.base_for
			s.odd = ""
		s.name = str(raw.get("name", s.name)).strip_edges()
		s.x = float(raw.get("x", s.x))
		s.y = float(raw.get("y", s.y))
		s.z = float(raw.get("z", s.z))
		var line: Variant = raw.get("line", raw.get("axis", s.axis))
		if line is Array and (line as Array).size() == 3:
			var way := Vector3(float(line[0]), float(line[1]), float(line[2]))
			if way.length() < 0.001:
				s.odd = "its axis [0, 0, 0] runs no way at all"
			else:
				s.axis_way = way.normalized()
				s.axis = ""
		else:
			s.axis = str(line).to_lower().trim_prefix("+")
			if not ["x", "y", "z"].has(s.axis):
				if not s.axis.is_empty():
					s.odd = ("its axis '%s' is not x, y, z or a direction [x, y, z]"
						% s.axis)
				s.axis = "z"
			s.axis_way = Vector3.ZERO
		s.degrees = float(raw.get("degrees", s.degrees))
		for pair: Array in [["yaw", "turn"], ["pitch", "tilt"], ["roll", "bank"]]:
			var said: Variant = raw.get(pair[0], raw.get(pair[1]))
			if said != null:
				s.set(pair[0], float(said))
		s.within = str(raw.get("within", raw.get("in", s.within))).strip_edges()
		if s.within == s.name and not s.name.is_empty():
			s.odd = "it is said to be within itself"
			s.within = ""
		var joint: Variant = raw.get("hinge", s.hinge_kind if s.hinge else false)
		if joint is bool:
			s.hinge = joint
			if joint and was == null:
				s.hinge_kind = Hinges.TILTING
		elif joint is String:
			var kind: String = Hinges.kind_named(joint)
			if kind.is_empty() and not str(joint).strip_edges().is_empty() \
					and str(joint).to_lower() != "false":
				s.odd = ("there is no hinge called '%s'; there are %s"
					% [joint, Hinges.listing()])
			s.hinge = not kind.is_empty()
			if s.hinge:
				s.hinge_kind = kind
		if s.hinge:
			# The joint's line lies flat, across the section's nose: pitch
			# lifts the nose about a line along x, roll lifts the +x side
			# about one along z. Said either way, it is the same hinge.
			if not raw.has("axis") and (was == null or not was.hinge):
				s.axis = "z" if not is_zero_approx(s.roll) and is_zero_approx(s.pitch) \
					else "x"
			if s.hinge_kind != Hinges.BALL:
				if s.axis == "y" or s.axis.is_empty():
					s.odd = ("a %s hinge's line lies flat, so its axis is x or z; "
						% s.hinge_kind + "about the upright it is a turntable — "
						+ "give the section a yaw instead")
					s.hinge = false
				elif not is_zero_approx(s.pitch) and not is_zero_approx(s.roll):
					s.odd = ("a %s hinge turns about one line, so it takes a "
						% s.hinge_kind + "pitch or a roll, not both. To tip two "
						+ "ways, hinge a section within this one")
				elif s.axis == "x" and not is_zero_approx(s.roll) \
						or s.axis == "z" and not is_zero_approx(s.pitch):
					s.odd = ("its hinge's line runs along %s, so it turns by %s; "
						% [s.axis, "pitch" if s.axis == "x" else "roll"]
						+ "leave the axis out to have it follow the angle given")
		s.hinge_color = int(raw.get("hinge_color", s.hinge_color))
		return s

	## The same section somewhere else, its hinge with it.
	func copied(as_name: String) -> Section:
		var s := Section.new()
		s.name = as_name
		s.x = x
		s.y = y
		s.z = z
		s.axis = axis
		s.axis_way = axis_way
		s.degrees = degrees
		s.yaw = yaw
		s.pitch = pitch
		s.roll = roll
		s.within = within
		s.parent = parent
		s.hinge = hinge
		s.hinge_kind = hinge_kind
		s.hinge_color = hinge_color
		s.pin_from_corner = pin_from_corner
		s.origin_from_pin = origin_from_pin
		s.base_rot = base_rot
		s.top_rot = top_rot
		s.top_at = top_at
		s.odd = odd
		return s

	## The way a section's pin runs, for its axis.
	static func pin_of(along: String) -> Vector3:
		if along == "x":
			return Vector3.RIGHT
		return Vector3.UP if along == "y" else Vector3.BACK

	## Yaw, then pitch, then roll, as a basis: the nose is +z.
	static func turned(yaw_deg: float, pitch_deg: float, roll_deg: float) -> Basis:
		return Basis(Vector3.UP, deg_to_rad(yaw_deg)) \
			* Basis(Vector3.RIGHT, -deg_to_rad(pitch_deg)) \
			* Basis(Vector3.BACK, deg_to_rad(roll_deg))

	## The yaw, pitch and roll that make [param basis], in degrees.
	static func angles_of(basis: Basis) -> Vector3:
		var e: Vector3 = basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
		return Vector3(rad_to_deg(e.y), -rad_to_deg(e.x), rad_to_deg(e.z))

	## How it is turned in its parent's coordinates, about its origin.
	func turn() -> Basis:
		var line: Vector3 = axis_way if axis_way != Vector3.ZERO else pin_of(axis)
		return exact(turned(yaw, pitch, roll) * Basis(line, deg_to_rad(degrees)))

	## A quarter turn made exactly one. Yaw -90 then pitch -90 came out a
	## hair off the square in floating point, and a skin stood on side
	## studs that way was rasterised a cell short of the core it stood on,
	## and called adrift where the same skin a ten-millionth of a stud over
	## was held.
	static func exact(basis: Basis) -> Basis:
		return BrickLattice.snap_basis(basis) if BrickLattice.is_square_to_grid(basis) \
			else basis

	## How a hinged section turns about its joint's line.
	func hinge_turn() -> Basis:
		if hinge_kind == Hinges.BALL:
			var line: Vector3 = axis_way if axis_way != Vector3.ZERO else pin_of(axis)
			return turned(0.0, pitch, roll) * Basis(line, deg_to_rad(degrees))
		var pin: Vector3 = pin_of(axis)
		var lift: float = -pitch if axis == "x" else roll
		return exact(Basis(pin, deg_to_rad(degrees + lift)))

	## Where the base of a hinged section's joint stands, in its parent's
	## coordinates: its corner, on the lattice since a part stands there,
	## turned by the yaw about its first stud — which is where a part on one
	## stud swivels.
	func hinge_own() -> Transform3D:
		var corner: Vector3 = BrickLattice.to_ldu(BrickLattice.to_cell(
			Vector3(x * STUD, y * PLATE, z * STUD)))
		if is_zero_approx(fposmod(yaw, 360.0)):
			return Transform3D(Basis.IDENTITY, corner)
		var stud := Vector3(STUD * 0.5, 0.0, STUD * 0.5)
		var turn: Basis = exact(Basis(Vector3.UP, deg_to_rad(yaw)))
		return Transform3D(turn, corner + stud - turn * stud)

	## The hinge's frame in the world.
	func hinge_frame() -> Transform3D:
		var mine: Transform3D = hinge_own()
		return dusted(mine if parent == null else parent.placed() * mine)

	## Where it sits in its parent's coordinates, and how it is turned.
	func own() -> Transform3D:
		if hinge:
			return hinge_own() * Transform3D(hinge_turn(), pin_from_corner) \
				* Transform3D(Basis.IDENTITY, origin_from_pin)
		return Transform3D(turn(), Vector3(x * STUD, y * PLATE, z * STUD))

	## Where this section sits in the world, and how it is turned.
	func placed() -> Transform3D:
		if base_of != null:
			return base_of.hinge_frame()
		var mine: Transform3D = own()
		return dusted(mine if parent == null else parent.placed() * mine)

	## A frame with the arithmetic's dust taken off its place, to the
	## thousandth of an LDU an LDraw file writes: a skin a ten-millionth of a
	## stud out of the side it stands on was rasterised a whole cell away
	## from it once its quarter turn was exact, and called adrift.
	static func dusted(at: Transform3D) -> Transform3D:
		return Transform3D(at.basis, Vector3(snappedf(at.origin.x, 0.001),
			snappedf(at.origin.y, 0.001), snappedf(at.origin.z, 0.001)))

	## Whether it is turned in a way that needs a joint to hold it: not
	## square to what it is built on, and not only turned about the upright,
	## which a part on one stud does.
	func leans() -> bool:
		if square():
			return false
		return (_turned_from_parent() * Vector3.UP).dot(Vector3.UP) < 0.9999

	## Whether it is turned only by quarter turns from what it is built on.
	func square() -> bool:
		return BrickLattice.is_square_to_grid(_turned_from_parent())

	## How it is turned from what it is built on: a hinge's frame by its
	## hinge's yaw.
	func _turned_from_parent() -> Basis:
		return own().basis if base_of == null else base_of.hinge_own().basis

	## Whether its up is still the world's up, however it is turned about it.
	func upright() -> bool:
		return (placed().basis * Vector3.UP).dot(Vector3.UP) > 0.9999

	## How it is turned, in the words a design uses.
	func said() -> String:
		var parts := PackedStringArray()
		for pair: Array in [["yaw", yaw], ["pitch", pitch], ["roll", roll]]:
			if not is_zero_approx(float(pair[1])):
				parts.append("%s %s" % [pair[0], Placement._num(float(pair[1]))])
		if not is_zero_approx(degrees):
			parts.append("%s degrees about %s" % [Placement._num(degrees),
				axis if axis_way == Vector3.ZERO else "[%s, %s, %s]" % [
					Placement._num(axis_way.x), Placement._num(axis_way.y),
					Placement._num(axis_way.z)]])
		var out: String = "not turned" if parts.is_empty() else ", ".join(parts)
		if hinge:
			out += " on a %s hinge" % hinge_kind
		if not within.is_empty():
			out += ", within '%s'" % within
		return out

	## The quarter turn that lays a hinge brick's pin along [member axis].
	func hinge_rot() -> int:
		return 0 if axis == "x" else 1


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
	## What the subject is known by — eyes, a beak, wheel arches, a grille —
	## each worked once the shape stands: looked up in real sets, laid as
	## one of theirs, or built from a worked technique.
	var features: Array[String] = []
	## Where each feature goes, where the design said: name in lower case ->
	## {x, y, z, facing} (FeaturePass.read_spots).
	var feature_spots: Dictionary = {}
	## What it stands on, as floor_chosen says it; empty when not said.
	var stands_on: Dictionary = {}

	func section_for(placement: Placement) -> Section:
		return sections.get(placement.section)

	## Each section's parent and each hinge base's section, found by name.
	## Asked again after anything that adds or replaces a section, since an
	## edit that re-declares one makes a new one its children must follow. A
	## section within one that is not there, or within itself by way of
	## others, is said so and built in the model's own coordinates.
	func link_sections() -> void:
		for section: Section in sections.values():
			section.parent = null
			if not section.within.is_empty():
				section.parent = sections.get(section.within)
				if section.parent == null and section.odd.is_empty():
					section.odd = ("it is within '%s', which is not one of the sections"
						% section.within)
			section.base_of = sections.get(section.base_for) \
				if not section.base_for.is_empty() else null
		for section: Section in sections.values():
			var seen: Dictionary = {}
			var at: Section = section
			while at != null:
				if seen.has(at):
					section.odd = "it is within '%s', which is within it" % section.within
					section.parent = null
					break
				seen[at] = true
				at = at.base_of.parent if at.base_of != null else at.parent

	## The sections built within [param name], at any depth, nearest first.
	func sections_within(name: String) -> Array[Section]:
		var out: Array[Section] = []
		var wanted: Array[String] = [name]
		while not wanted.is_empty():
			var next: String = wanted.pop_front()
			for section: Section in sections.values():
				if section.within == next or section.base_for == next:
					if not out.has(section):
						out.append(section)
						wanted.append(section.name)
		return out


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
	_drop_sketches()
	_start(brief)
	return true


# -- sketch first ----------------------------------------------------------


## Three massings to choose between, in one turn on the cheaper model
## (Brain.sketch_model), before anything is paid for in full. Each is
## checked and pictured off the baseplate, and [signal sketches_ready]
## hands them to whoever shows them; [method choose_sketch] puts the chosen
## one down and designs the whole model from it at the person's own model
## and effort. Refused while a design runs, as [method design] is.
func sketch(brief: String) -> bool:
	if _busy:
		return false
	_messages.clear()
	_drop_sketches()
	_sketch_brief = brief
	_sketch_round = true
	_start(brief)
	return true


## The sketches are in: who shows them, what they are, and what making them
## cost. [param ours] is false for a session's from outside, which chooses
## for itself with choose_sketch.
signal sketches_ready(sketches: Array, model_id: String, tokens: Brain.Spend, ours: bool)
## One was chosen, by its number; the others are gone.
signal sketch_chosen(number: int)

## Turns the sketches may take: a look-up or two, then the three. Past it,
## whatever was sketched is shown.
const SKETCH_TURNS := 4
## Times three that are one idea are sent back for another.
const SKETCH_REDOS := 1

const SKETCH_ASK := """Sketch first. Before the full design, the person \
wants three quick sketches to choose between, so call submit_design three \
times in this one reply, each with "sketch": true. A sketch is massing only: \
the main masses at their sizes and in their colours, under 150 parts once \
any patterns are laid, each mass in the biggest pieces that fit it — no \
detail, no rooms, no features worked; assemblies and features may be empty. Make \
them three ideas a person can choose between: a different silhouette, \
different proportions, or a different approach to the subject — not one \
model three times at slightly different sizes. Name each for its idea and \
say in its description what makes it different. Each is checked and \
pictured, not built; the person chooses one, and the full design is built \
from it."""

## The same, said to a session outside the app with its brief.
const SKETCH_FIRST := """Sketch first: before the full design, make three \
quick sketches to choose between — submit_design with "sketch": true, three \
times, each massing only, under 150 parts once its patterns are laid (each \
mass in the biggest pieces that fit it), and different from the others in \
silhouette, proportion or approach. Then choose_sketch the one that best \
answers this brief, and design the whole model from it."""

const FROM_SKETCH := """Design the whole model from it now. Keep what the \
person chose — its silhouette, its proportions and its approach — and build \
it as a set is built: the right parts, real detail, the assemblies a person \
would name and the features the subject is known by. submit_design the \
whole model, without sketch: it replaces the sketch."""

var _sketch_round: bool = false
var _sketch_brief: String = ""
var _held_sketches: Array = []
## Whether the held ones came from a session outside the app.
var _sketches_outside: bool = false
## The number the next sketch replaces, when two were one idea; 0 for none.
var _sketch_redo: int = 0
var _sketch_redos: int = 0
## Sketches held during the reply being answered.
var _sketch_arrivals: int = 0
## The one chosen, while the full design's opening is made from it.
var _chosen_sketch: Sketches.Sketch = null


## A brief with the sketch-first ask on it, for a session outside the app
## (My Claude with Sketch first ticked, --ask-claude-code --sketch-first).
static func sketch_brief(text: String) -> String:
	return "%s\n\n%s" % [text, SKETCH_FIRST]


## The sketches held, for a probe or a panel.
func held_sketches() -> Array:
	return _held_sketches.duplicate()


func _drop_sketches() -> void:
	_held_sketches = []
	_sketch_round = false
	_sketch_redo = 0
	_sketch_redos = 0
	_sketch_arrivals = 0
	_chosen_sketch = null


## What the first message of a run carries besides the brief: the ask for
## sketches, or the chosen one to design from.
func _sketch_opening() -> Array:
	if _sketch_round:
		return [{"type": "text", "text": SKETCH_ASK}]
	if _chosen_sketch == null:
		return []
	var one: Sketches.Sketch = _chosen_sketch
	var said: Array = [{"type": "text", "text": ("You sketched three massings for "
		+ "this, and the person chose sketch %d, \"%s\"" % [one.number, one.name]
		+ (": %s" % one.description if not one.description.is_empty() else "")
		+ ". It stands on the baseplate now: %d parts, %s." % [one.parts, one.measures()])}]
	if not one.block.is_empty():
		said.append(one.block)
	var written: Dictionary = one.args.duplicate()
	written.erase("sketch")
	said.append({"type": "text", "text": "Its parts, as you submitted them:\n"
		+ JSON.stringify(written)})
	said.append({"type": "text", "text": FROM_SKETCH})
	return said


## A sketch, from submit_design with sketch: true (or any submission while
## the app's own loop is sketching): read, checked, measured and pictured on
## a world of its own, and held. Nothing is put on the baseplate.
func _hold_sketch(args: Dictionary) -> Variant:
	var model: Model = _read_model(args)
	_say_shorthand_trouble()
	var parts: int = model.placements.size()
	if parts == 0:
		return "Not held — that sketch has no parts in it."
	if parts > Sketches.MOST_PARTS:
		progress.emit("a sketch of %d parts, over the %d a sketch may have"
			% [parts, Sketches.MOST_PARTS])
		return ("Not held — a sketch is massing only, under %d parts, and this is %d "
			% [Sketches.MOST_PARTS, parts] + "once its patterns are laid. Say each mass "
			+ "in the biggest pieces that fit it — 2 x 4 bricks, 6 x 6 and larger "
			+ "plates — or fewer masses, and leave the detail for the full design.")
	# A fourth in the same reply is not the first of a new three.
	if _sketch_round and _sketch_redo == 0 and _held_sketches.size() >= Sketches.COUNT:
		return "Not held — three sketches are in already, and the person chooses among them."
	var running: bool = _busy
	if not _sketch_round:
		# From outside: a set begun by the app's own loop is not this one's.
		if not _sketches_outside:
			_held_sketches = []
		_sketches_outside = true
	else:
		_sketches_outside = false
	await _ensure_parts(model)
	progress.emit("checking a sketch of %d parts" % parts)
	var report: Dictionary = await _checked(model)
	if running and not _busy:
		return ""
	var one := Sketches.Sketch.new()
	one.name = model.name if model.name != "Model" else "Sketch"
	one.description = model.description
	one.model = model
	one.args = args
	one.report = report
	one.parts = parts
	var stage: BrickWorld = _stage_of(model)
	var measured: Dictionary = Sketches.measure(stage)
	one.size = measured["size"]
	one.outline = measured["outline"]
	if ModelShot.possible():
		one.picture = await _sketch_picture(stage)
		if running and not _busy:
			stage.free()
			return ""
		if one.picture != null:
			one.block = await _shot.encode(one.picture)
	if one.block.is_empty():
		one.letters = "%s\n%s" % [ModelView.draw(stage, library, "top"),
			ModelView.draw(stage, library, "front")]
	stage.free()

	# Where it goes: in place of one that was the same idea as another, or
	# after the last, or as the first of a new three.
	if _sketch_redo > 0 and _sketch_redo <= _held_sketches.size():
		one.number = _sketch_redo
		_held_sketches[_sketch_redo - 1] = one
		_sketch_redo = 0
	else:
		if _held_sketches.size() >= Sketches.COUNT:
			_held_sketches = []
			_sketch_redos = 0
		_held_sketches.append(one)
		one.number = _held_sketches.size()
	_sketch_arrivals += 1
	progress.emit("sketch %d of %d: %s, %s" % [one.number, Sketches.COUNT, one.name,
		one.measures()])
	return _sketch_answer(one)


## A world holding only [param model], in no tree and drawing nothing, to be
## measured and photographed. The caller frees it.
func _stage_of(model: Model) -> BrickWorld:
	var stage := BrickWorld.new()
	stage.library = library
	stage.keeps_history = false
	for placement: Placement in model.placements:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		stage.add_unseen(placement.part, placement.color,
			_transform(placement, part, model.section_for(placement)))
	return stage


## A sketch from a corner, as a person sees it: its own colours, no studs
## written on, nothing picked out.
func _sketch_picture(stage: BrickWorld) -> Image:
	var shot: ModelShot = _ensure_shot()
	var was: Array = [shot.highlight, shot.marks, shot.rulers]
	shot.highlight = {}
	shot.marks = []
	shot.rulers = false
	var image: Image = await shot.take(stage, "corner")
	shot.highlight = was[0]
	shot.marks = was[1]
	shot.rulers = was[2]
	return image


## What a sketch's submit_design answers: what it is and its picture; and,
## once there are three, whether they are three ideas, and then all three
## pictures and how to choose (from outside) — or that the person chooses.
func _sketch_answer(one: Sketches.Sketch) -> Variant:
	var verdict: String = ("it holds together" if one.holds()
		else "the check says %s" % str(one.report.get("summary", "")))
	var blocks: Array = [{"type": "text", "text": "Sketch %d of %d held, not built: "
		% [one.number, Sketches.COUNT] + "%d parts, %s; %s." % [one.parts,
			one.measures(), verdict]}]
	blocks.append_array(_sketch_shown(one))
	if _held_sketches.size() < Sketches.COUNT:
		var others := PackedStringArray()
		for held: Sketches.Sketch in _held_sketches:
			others.append("%d" % held.number)
		blocks.append({"type": "text", "text": ("Now sketch %d: another idea, "
			% (_held_sketches.size() + 1)) + "different from sketch %s in silhouette, "
			% " and ".join(others) + "proportion or approach."})
		return blocks
	var pairs: Array = Sketches.alike_pairs(_held_sketches)
	if not pairs.is_empty() and _sketch_redos < SKETCH_REDOS:
		_sketch_redos += 1
		var pair: Array = pairs[0]
		var first: Sketches.Sketch = _held_sketches[int(pair[0]) - 1]
		_sketch_redo = int(pair[1])
		progress.emit("sketches %d and %d are one idea; asking for another" % pair)
		blocks.append({"type": "text", "text": ("Sketches %d and %d are nearly the "
			% pair) + "same idea: both about %s, with outlines that overlap %d%%. " % [
				first.measures(), roundi(Sketches.overlap(first,
					_held_sketches[int(pair[1]) - 1]) * 100.0)]
			+ "A person cannot choose between those. Submit submit_design with "
			+ "\"sketch\": true once more: it replaces sketch %d, and should differ " % pair[1]
			+ "from the other two in silhouette, proportion or approach."})
		return blocks
	if not _sketches_outside:
		blocks.append({"type": "text", "text":
			"That is three. The person chooses one, and the full design is built from it."})
		return blocks
	# From outside: all three, and how to choose.
	sketches_ready.emit(_held_sketches.duplicate(), "", Brain.Spend.new(), false)
	blocks.append({"type": "text", "text": "The three sketches, side by side:"})
	for held: Sketches.Sketch in _held_sketches:
		blocks.append({"type": "text", "text": "Sketch %d, \"%s\": %d parts, %s%s." % [
			held.number, held.name, held.parts, held.measures(),
			"" if held.holds() else ", and it does not hold together yet"]})
		blocks.append_array(_sketch_shown(held))
	blocks.append({"type": "text", "text": ("Choose the one that best answers the "
		+ "brief — its silhouette, its proportions, its approach — with choose_sketch "
		+ "{\"sketch\": N}. It goes on the baseplate and the other two are dropped; "
		+ "then design the whole model from it and submit_design it without sketch. "
		+ "Or submit_design with \"sketch\": true again for a new three.")})
	return blocks


## A sketch as Claude is shown it: its picture, or the letters without one.
static func _sketch_shown(one: Sketches.Sketch) -> Array:
	if not one.block.is_empty():
		return [one.block]
	return [{"type": "text", "text": one.letters}]


## After a reply in the app's own sketch round: true when it has been dealt
## with here — the sketches shown, sent back for the rest, or the round
## given up — and false when the reply was only look-ups, to be answered as
## any turn is.
func _sketch_turn_over(tool_results: Array) -> bool:
	var arrived: int = _sketch_arrivals
	_sketch_arrivals = 0
	var full: bool = _held_sketches.size() >= Sketches.COUNT
	if full and _sketch_redo == 0:
		_sketches_shown()
		return true
	var out_of_turns: bool = _turns >= SKETCH_TURNS
	if out_of_turns:
		if _held_sketches.is_empty():
			_stop(false, "it made no sketches")
		else:
			_sketches_shown()
		return true
	if arrived == 0 and not tool_results.is_empty():
		return false
	if not full:
		var ask: String = ("%d of the three sketches so far. " % _held_sketches.size()
			+ "Submit the other %d now, each submit_design with \"sketch\": true, "
			% (Sketches.COUNT - _held_sketches.size())
			+ "each a different idea from the ones before.")
		if tool_results.is_empty():
			ask = ("No sketches yet. Call submit_design three times now, each with "
				+ "\"sketch\": true: three massings under 150 parts, three different ideas.")
		tool_results.append({"type": "text", "text": ask})
	_messages.append({"role": "user", "content": tool_results})
	_send()
	return true


## The round is over: the sketches go to the panel, with what they cost, and
## the conversation that made them is done with. Choosing begins the design.
func _sketches_shown() -> void:
	_sketch_round = false
	_busy = false
	# Held off the baseplate: nothing to undo. Choosing one begins the step.
	_run_mark = {}
	_messages.clear()
	var spend: Brain.Spend = _spend
	_spend = Brain.Spend.new()
	progress.emit("%d sketches to choose from" % _held_sketches.size())
	sketches_ready.emit(_held_sketches.duplicate(), _spent_on, spend, true)


## Put sketch [param number] down and go on from it; the others are dropped.
## The app's own: the whole model designed from it, a fresh conversation at
## the person's model and effort ("" when that has begun). From outside:
## what to do next, said to the session.
func choose_sketch(number: int) -> String:
	if _busy:
		return "Not now — a design is running. Choose when it has finished."
	if _held_sketches.is_empty():
		return ("There are no sketches to choose from. submit_design with \"sketch\": "
			+ "true, three times, makes them.")
	if number < 1 or number > _held_sketches.size():
		return "There is no sketch %d; choose 1 to %d." % [number, _held_sketches.size()]
	var one: Sketches.Sketch = _held_sketches[number - 1]
	var outside: bool = _sketches_outside
	_held_sketches = []
	_sketch_redo = 0
	sketch_chosen.emit(number)
	progress.emit("putting down sketch %d, %s" % [number, one.name])
	var model: Model = one.model
	# In the app, the sketch going down begins the design's one step.
	if not outside:
		_run_mark = ClaudeStep.mark(builder, world, scenery, "Claude's design")
	await _ensure_parts(model)
	await _apply(model, true, true)
	if outside:
		# Standing, so a check is a check and not a replacement for it.
		_outside_standing = true
		return ("Sketch %d, \"%s\", stands on the baseplate: %d parts, %s. " % [number,
			one.name, one.parts, one.measures()] + "It is the massing the design is built "
			+ "from.\n\n" + FROM_SKETCH + " Then review_model, as its answer says.")
	_chosen_sketch = one
	_start(_sketch_brief)
	_chosen_sketch = null
	return ""


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
	_drop_sketches()
	_http.cancel_request()
	if _streaming != null:
		_streaming.stop()
		_streaming = null
	if _scoped:
		# Stopped while changing a selection: its one step taken back, which
		# is what was there before. _restore puts back only bricks the
		# assistant built, and a selection is usually the person's.
		_scoped = false
		if focus != null and not focus.step.is_empty() \
				and is_same(builder.last_step(), focus.step):
			builder.undo()
			focus.step = {}
	else:
		_restore()
	# What a cancelled run had changed and did not put back (an edit that
	# landed) is Claude's step too.
	_record_run()
	finished.emit(false, "cancelled")


## Where the model and its history stood as this request began, for its
## change to be one step of the history as it ends (ClaudeStep); {} when no
## request is running, or it is about a selection.
var _run_mark: Dictionary = {}


## This request's change, one undo step named as Claude's.
func _record_run() -> void:
	var mark: Dictionary = _run_mark
	_run_mark = {}
	ClaudeStep.record(builder, world, scenery, mark)


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
	_features = []
	_features_told = false
	_feature_used = {}
	_feature_now = ""
	_feature_closed = false
	feature_pass().reset({})
	# A fresh design gets the creative pass; a revision carries on the
	# conversation, and a selection is the person's model.
	_creative_wanted = not _scoped and _messages.is_empty()
	_creative_record = ""
	# And the surface pass before it: see SurfacePass.
	_surface_wanted = _creative_wanted
	if _surface_wanted:
		surface_pass().reset()
	_detail_count = 0
	_detail_added = []
	_parts_before_pass = {}
	_sent_back = false
	_before_detail = ""
	_turn_cap = MAX_TURNS
	_art_laid = 0
	_art_name = ""
	_brief = text
	_joints_told = 0
	_joint_parts_told = false
	_spend = Brain.Spend.new()
	_spent_on = Brain.sketch_model() if _sketch_round else Brain.chosen()
	_pending = null
	_before = _snapshot()
	# What this request changes is one undo step, Claude's, kept as it ends
	# (ClaudeStep). About a selection, its edits gather into one already.
	if not _scoped and _run_mark.is_empty():
		_run_mark = ClaudeStep.mark(builder, world, scenery,
			"Claude's design" if _messages.is_empty() else "Claude's change")
	# References first, in the same message as the brief.
	#
	# A named real subject was designed entirely from memory of it. The
	# loop can say a model is buildable and can look at what it built,
	# but nothing in it could ever say "that is not what a Voyager looks
	# like" — there was no way for a picture to come IN. Renders went
	# out; nothing came back.
	if _scoped:
		# The selection, its room and pictures of it, then the request.
		var opening: Array = await _focus_opening(text)
		if not _busy:
			return
		_messages.append({"role": "user", "content": opening})
	else:
		# On the web our scored designs are fetched the first time.
		await DesignMemory.ensure(self)
		if not _busy:
			return
		_messages.append({"role": "user", "content": opening_for(text) + _sketch_opening()})
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
	if not owned.is_empty() and Collection.wanted_in(text):
		opening.append({"type": "text", "text": Collection.brief_note(owned, library)})
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
			"Before you choose parts, this is how real LEGO® sets of this "
			+ "kind are actually built. It is measured over every "
			+ "catalogued set, not advice.\n" + measured})
	# And, for the same reason, what our own scored designs of the nearest
	# subject did and what the bench's judge faulted (src/ai/design_memory.gd).
	# In words: the pictures here are the reference.
	opening.append_array(DesignMemory.recall(text, false))
	return opening


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

	var key: String = key_in_use()
	if key.is_empty():
		# A frame later, not now. This runs inside design(), and a
		# finished emitted before design() returns reaches nobody who
		# awaits it: --ask with no key sat waiting for ever.
		await get_tree().process_frame
		if _busy:
			_stop(false, NO_KEY)
		return
	var body: Dictionary = request_body()
	var url: String = endpoint
	var headers: PackedStringArray = ["content-type: application/json",
		"x-api-key: " + key, "anthropic-version: 2023-06-01"]
	if OS.has_feature("web"):
		# Anthropic blocks browser calls unless asked not to, which is
		# the right default: it exists to stop a key being put in a web
		# page where every visitor can read it. Here the key belongs to
		# the person at the keyboard and never leaves their machine
		# except to Anthropic, which is the case the header is for.
		headers.append("anthropic-dangerous-direct-browser-access: true")

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
			# Sketches are held off the baseplate, not drawn on it.
			if _sketch_round or (tool != "submit_design" and tool != "check_design"):
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
	# One said by its connectors has no place until the whole is read.
	if part == null or not placement.attach.is_empty():
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
## Only fields Anthropic takes. Anything else gets the whole request
## refused: a design_id meant for a proxy, since removed, came back as
## "design_id: Extra inputs are not permitted" on every direct call, and
## shipped, because nothing exercised the direct route until the
## examples generator did and failed on all six.
##
## Separated from _send so a probe can inspect it without a network
## call, which is the only way this stays fixed.
func request_body() -> Dictionary:
	# Sketches on the cheaper model and effort; everything else on the chosen.
	var choice: Brain.Choice = Brain.find(Brain.sketch_model() if _sketch_round
		else Brain.chosen())
	var effort: String = Brain.sketch_effort() if _sketch_round else Brain.effort()
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
		"tools": _tools() + (focus_tools() if _scoped else []),
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
	if choice.effort and not effort.is_empty():
		body["output_config"] = {"effort": effort}
	if choice.adaptive:
		body["thinking"] = {"type": "adaptive"}
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


func _on_response(result: Array) -> void:
	if not _busy:
		return
	var code: int = result[1]
	var payload: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())

	if code != 200 or typeof(parsed) != TYPE_DICTIONARY:
		# Said plainly first. Anthropic's own words used to replace this
		# whenever its reply carried them, so a mistyped key came back as
		# "invalid x-api-key" in small grey type — accurate, and no use to
		# anybody deciding what to do next. Its words are kept after ours
		# where they say something ours do not.
		var detail: String = _what_went_wrong(code)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			var err: Variant = parsed["error"]
			var theirs: String = (str(err.get("message", err))
				if typeof(err) == TYPE_DICTIONARY else str(err)).strip_edges()
			if not theirs.is_empty() and code not in [401, 403, 529] \
					and code < 500:
				detail += " Anthropic said: %s" % theirs
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

	# Sketching first: shown once there are three, asked for the rest until.
	if _sketch_round and _busy and _sketch_turn_over(tool_results):
		return

	if tool_results.is_empty():
		# About a selection, a reply with nothing to call is the answer:
		# what it changed, or what it said about the parts.
		if _scoped:
			_stop(true, "changed the selection: %s" % SelectionScope.words_for(
				focus.step.get("steps", [])) if _edited and focus != null
				and not focus.step.is_empty() else "answered")
			return
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
		var feature: bool = bool(_detailing.get("feature", false))
		var creative: bool = bool(_detailing.get("creative", false))
		var surface: bool = bool(_detailing.get("surface", false))
		# Settled with settle_feature: that is the feature's answer, so on
		# to the next with the answers to this turn's tools.
		if feature and _feature_closed:
			_feature_closed = false
			var settled: Array = tool_results.duplicate()
			if await _detail_next(settled):
				return
			_stop(true, "%d bricks" % world.brick_count())
			return
		# Every finding of the surface pass settled: that is its answer.
		if surface and surface_pass().open().is_empty():
			if await _detail_next(tool_results.duplicate()):
				return
			_stop(true, "%d bricks" % world.brick_count())
			return
		if _detail_turns >= (TURNS_FOR_TOUCHES if creative else SurfacePass.TURNS if surface
				else TURNS_PER_FEATURE if feature else TURNS_PER_ASSEMBLY):
			progress.emit("out of turns for the %s" % _detailing["name"])
			var moved_on: Array = tool_results.duplicate()
			moved_on.append({"type": "text", "text": "That is as many "
				+ "turns as the %s gets, so on to the next." % (
					"creative pass" if creative else "surface pass" if surface
						else "feature" if feature else "assembly")})
			if await _detail_next(moved_on):
				return
			_stop(true, "%d bricks" % world.brick_count())
			return
	_messages.append({"role": "user", "content": tool_results})

	if _pending == null:
		_send()
		return

	# A design arrived. Check it against the real lattice.
	progress.emit("checking %d bricks" % _pending.placements.size())
	await _ready_to_check(_pending)
	var report: Dictionary = await _checked(_pending)
	# Stopped while it was being checked: nothing more to do with it.
	if not _busy:
		return
	progress.emit(report["summary"])
	if not report["ok"] and _repairs >= MAX_REPAIRS and not _looked_back:
		report = _salvage(report)

	if report["ok"]:
		await _ensure_parts(_pending)
		await _apply(_pending, true, true)
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
			_to_detail = _queue_features(_pending.features)
			_to_detail.append_array(_queue_assemblies(_pending.assemblies))
			_features = _pending.features
			feature_pass().reset(_pending.feature_spots)
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
			if not _features.is_empty():
				ask += ("\n\nThis look is for the silhouette and the proportions: "
					+ "the masses, their sizes against the reference, the outline. "
					+ "After it, each feature you listed — %s — comes back to you "
					% ", ".join(_features) + "on its own: the app lays the best real "
					+ "set's piece for it where it goes, and you accept it, adjust "
					+ "it, or reject it with a reason, one at a time.")
			else:
				ask += ("\n\nYou listed no features. Name what the subject is "
					+ "known by — its eyes, beak, ears, wheel arches, grille, "
					+ "windows, roof — with submit_design's features, or work "
					+ "each now with find_techniques before detailing.")
			var names := PackedStringArray()
			for one: Dictionary in _to_detail:
				if not bool(one.get("feature", false)):
					names.append(str(one["name"]))
			if not names.is_empty():
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
				and (not _pending.assemblies.is_empty() or not _pending.features.is_empty()):
			_to_detail = _queue_features(_pending.features if not _pending.features.is_empty()
				else _features)
			_to_detail.append_array(_queue_assemblies(_pending.assemblies))
			if not _pending.features.is_empty():
				_features = _pending.features
				feature_pass().reset(_pending.feature_spots)
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
	judge.floor_ids = scenery
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
  Inside. If it is a building, can you see in? Real sets are open at the \
back with furnished rooms on floors; a closed shell is the one place a \
model of this kind is plainer than every set of its kind. add_rooms lays \
the floors and furnishes them in one call.
  Craft. Is anything in it not studs-up, not square, not mirrored where \
the subject is not? Is there one part used for what it looks like rather \
than what it is for? Does the texture change where the material does, \
and does any face have depth — something set in, something standing \
out? A model that holds together and has none of these is a correct \
model nobody would buy.
  The same part in two colours, where one of them is used once. Three \
red beams and one grey one reads as a part taken from the wrong bin, \
not as a detail. Look at whether the odd one is doing something — a \
light, a marking, a stripe that carries across — and if it is not, \
make it match. A single contrasting piece that is clearly deliberate \
is fine; it is the structural part in the wrong colour that is not.
  Windows as a grid. Rows of identical lit windows make any building an \
office block. Few windows, each with a reason — arched, framed, varied, \
gathered where something happens — their colour and light from the \
subject: a dark fortress has dark slits, a lighthouse one lit lantern.
  A dark face with nothing on it. A big face of plain bricks in black or \
another dark colour reads as a hole in the picture. Texture in the same \
colour (grille bricks, masonry, bricks with a handle, cheese slopes) for \
most of it, a second tone in bands where the ledges are (sprinkled \
through the bricks it is noise), and depth — an inset or outset course, \
a pilaster, a rib — so light and shadow draw the form.
  No silhouette. A tall thing the same width all the way up, with its top \
stuck on. Its profile is the design: taper, flare at the foot, a waist, \
facets catching light, a crown that grows out of the body.
  The base as an afterthought. Rubble ringed round the foot. A composed \
plinth — steps, a terrace, ground that rises to the door — leads the eye \
up.
  The wrong technique for the shape. Something round built of square \
bricks, a slanted edge stepped, a hull or a body boxy where it curves, \
a hinge or a leg built rigid. WHAT THE SUBJECT NEEDS names the call for \
each; replace the shape with it.
  Touches. Is there anything a person would find and smile at — a \
figure or a small scene, a printed tile, a nod to the subject's story, \
something that opens or turns, a stand with a nameplate for a display \
model? An expert adds them unasked; a model with none is finished only \
as a shape.

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
## the smallest assembly whose box holds its corner (the box read the way
## look_at_model reads where=), so a sign named on a roof is the sign's. A
## model that is one thing is left as one thing.
##
## One assembly is tagged only where something stands outside it: a stand
## named in front of an otherwise unnamed model is an item of its own, in
## the file as in the check (_standing_apart). A session from outside names
## its assemblies too, and they are tagged as it saves.
func _tag_assemblies() -> void:
	var named: Array[Dictionary] = _assemblies_named()
	if named.is_empty() or world == null:
		return
	if named.size() == 1:
		var outside: bool = false
		for brick: BrickWorld.Brick in world.bricks():
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			if scenery.has(brick.id) or info == null:
				continue
			if not _inside(_to_studs(brick, info), named[0]["where"]):
				outside = true
				break
		if not outside:
			return
	# A figure is its own sub-model wherever it stands; renamed after the
	# tower it is in, it would be three arms and a hat in "tower".
	var members: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not brick.group.is_empty():
			if not members.has(brick.group):
				members[brick.group] = []
			(members[brick.group] as Array).append(brick)
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		if members.has(brick.group) and Minifig.is_figure(members[brick.group], library):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var group: String = _assembly_at(_to_studs(brick, info), named)
		if not group.is_empty():
			brick.group = group


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
	if not _detailing.is_empty() and not _sent_back and also.is_empty() \
			and not bool(_detailing.get("feature", false)) \
			and not bool(_detailing.get("creative", false)) \
			and not bool(_detailing.get("surface", false)):
		var here: Array[BrickWorld.Brick] = _bricks_inside(
			_detailing["where"])
		var normal: Dictionary = library.normal_for(here.size())
		var shapes: int = _parts_in(here).size()
		var thin: bool = not normal.is_empty() \
			and shapes < int(normal.get("shapes_thin", 0))
		# Or the whole model is short of one-off pieces, on the same tail.
		# Keyed on the assembly alone, the message that moved them never
		# reached a run whose assemblies were rich enough on their own:
		# run 16 was sent back and came to 54 one-off shapes, run 17's
		# towers were not and it came to 17.
		var whole: Array[BrickWorld.Brick] = _bricks_inside({})
		var real: Dictionary = library.normal_for(whole.size())
		var once: int = _once_or_twice(whole)
		var few: bool = once < int(real.get("accents_thin", 0))
		# Or it is mostly one colour, on the tail of real sets. A real
		# castle set is a median 31% its main colour; every castle built
		# here was 49-55%, with 72-86% in its top two colours where a
		# real one has 49% — and the one that read best was the least
		# grey of them.
		var colour: Array = _main_colour(whole)
		var high: int = int(real.get("main_colour_high", 0))
		var grey: bool = high > 0 and int(colour[1]) > high
		# Or it is built of big pieces, on the tail of real sets: see
		# _coarse. Said with the assembly's own share, because that is
		# what this pass can change.
		var coarse: Array = _coarse(_ids_of(whole))
		var big_high: int = int(real.get("big_high", 0))
		var rough: bool = big_high > 0 and int(coarse[0]) > big_high
		if thin or few or grey or rough:
			_sent_back = true
			var name: String = _detailing["name"]
			progress.emit("sent the %s back: %d shapes in %d parts, %d "
				% [name, shapes, here.size(), once]
				+ "used once or twice in the whole model, %d%% its main "
				% int(colour[1]) + "colour, %d%% big pieces"
				% int(coarse[0]))
			var said := PackedStringArray()
			if thin:
				said.append("The %s is %d different shapes in %d parts. A "
					% [name, shapes, here.size()] + "real set of that "
					+ "size has about %d, and fewer than %d is thinner "
					% [int(normal.get("shapes", 0)),
						int(normal.get("shapes_thin", 0))]
					+ "than all but one set in twenty.")
			if int(real.get("accents", 0)) > once:
				said.append("Most of a real set's different shapes are "
					+ "pieces it uses once or twice: the whole model has "
					+ "%d, a real set its size about %d" % [once,
						int(real.get("accents", 0))]
					+ (", and fewer than %d is thinner than all but one "
						% int(real.get("accents_thin", 0))
						+ "set in twenty" if few else "")
					+ ". A detail copied onto every tower counts as one "
					+ "shape however many towers there are.")
			if grey:
				said.append("And the whole model is %d%% %s, where a real "
					% [int(colour[1]), _colour_name(int(colour[0]))]
					+ "set its size is about %d%% its main colour and more "
					% int(real.get("main_colour", 0))
					+ "than %d%% is more one colour than all but one set in " % high
					+ "twenty. A second colour where something changes — "
					+ "a band, a roof, a door, a trim — is what a real set "
					+ "does with it.")
			if rough:
				var own: Array = _coarse(_ids_of(here))
				said.append("And %d%% of the whole model's pieces are as "
					% int(coarse[0]) + "big as a 2 x 4 brick or bigger "
					+ "(%d%% of the %s's, most of them %s %s), where a "
					% [int(own[0]), name, own[1] if not str(own[1]).is_empty()
						else coarse[1], _part_called(str(own[1])
							if not str(own[1]).is_empty() else str(coarse[1]))]
					+ "real set its size has about %d%% and more than %d%% "
					% [int(real.get("big", 0)), big_high]
					+ "is coarser than all but one set in twenty. A long "
					+ "brick is a stretch of wall where nothing can happen; "
					+ "in short ones, one can be a window, a masonry brick "
					+ "or a second grey.")
			said.append("One more round on the %s: where does something " % name
				+ "change that is still the same piece? Then stop.")
			_messages.append({"role": "user", "content": " ".join(said)})
			_send()
			return true
	if not _detailing.is_empty() and bool(_detailing.get("surface", false)):
		surface_pass().close()
		progress.emit("the surface pass: %s" % surface_pass().record())
		_detailing = {}
	if not _detailing.is_empty() and bool(_detailing.get("creative", false)):
		_creative_record = _creative_said(_parts_before_pass, int(_detailing["count"]))
		progress.emit("the creative pass: %s" % _creative_record)
		_detailing = {}
	elif not _detailing.is_empty() and bool(_detailing.get("feature", false)):
		# Its turns over with the app's piece standing and nothing said of
		# it: the piece stays, as a piece in the model does.
		var left: FeaturePass.Proposal = feature_pass().proposal(_detailing["name"])
		if left != null and not left.settled() and not left.ids.is_empty() \
				and feature_pass()._standing(left.ids):
			left.verdict = "kept"
		progress.emit("the %s: %s" % [_detailing["name"], _feature_said(_detailing["name"])])
		var brought := PackedStringArray()
		for part_id: String in _parts_in(_bricks_inside({})):
			if not _parts_before_pass.has(part_id):
				brought.append(part_id)
		_detail_added.append([_detailing["name"], brought])
		_feature_now = ""
		_detailing = {}
	elif not _detailing.is_empty():
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
		# A settle said during an assembly's turn is not this feature's.
		_feature_closed = false
		_sent_back = false
		_repairs = 0
		_parts_before_pass = _parts_in(_bricks_inside({}))
		if bool(one.get("feature", false)):
			var of: int = _features.find(str(one["name"])) + 1
			progress.emit("working the %s (feature %d of %d)" % [one["name"], of,
				_features.size()])
			_feature_now = str(one["name"])
			var brief: Variant = await _feature_brief(_feature_now, of, _features.size(), true)
			if not _busy:
				return true
			_note_feature("looked up %s" % _feature_now)
			_forget_old_pictures()
			var content: Array = also.duplicate()
			if brief is Array:
				content.append_array(brief)
			else:
				content.append({"type": "text", "text": str(brief)})
			_messages.append({"role": "user", "content": content})
			_send()
			return true
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
	if not _features.is_empty() and not _features_told:
		_features_told = true
		progress.emit("features:\n%s" % _features_record(_features))
	# Then the surface pass, before the creative pass: see SurfacePass.
	if _surface_wanted:
		_surface_wanted = false
		if await _surface_turn(also):
			return true
	# Last, once everything else has had its turn: see CREATIVE_PASS.
	if _creative_wanted:
		_creative_wanted = false
		var standing: Array[BrickWorld.Brick] = _bricks_inside({})
		if not standing.is_empty():
			_detailing = {"name": "creative touches", "where": {}, "creative": true,
				"count": standing.size()}
			_detail_turns = 0
			_repairs = 0
			_parts_before_pass = _parts_in(standing)
			_turn_cap = maxi(_turn_cap, _turns + 2 + TURNS_FOR_TOUCHES)
			progress.emit("the creative pass: proposing touches for it")
			_forget_old_pictures()
			var content: Array = also.duplicate()
			content.append({"type": "text", "text": _creative_brief()})
			_messages.append({"role": "user", "content": content})
			_send()
			return true
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
			% name + "them yet — one where its shape is wanted, never "
			+ "something the brief did not ask for:\n" + "\n".join(missing))
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
	var once: int = _once_or_twice(everything)
	var normal_whole: Dictionary = library.normal_for(everything.size())
	if int(normal_whole.get("accents", 0)) > once:
		said.append("Across the whole model, %d shapes are used only once "
			% once + "or twice; a real set of %d parts has about %d. "
			% [everything.size(), int(normal_whole.get("accents", 0))]
			+ "That is where most of a set's variety is — one of a part, "
			+ "where something happens — and where this model is "
			+ "furthest from one.")
	# And what those pieces are, for this kind: the parts real sets of it
	# use one or two of, where something happens — a goblet, a torch, a
	# hinge, a bracket — measured, not chosen. The count alone, told in
	# the message above, did not move: 21 one-off shapes, then 13.
	var accents := PackedStringArray()
	var named_accent: Dictionary = {}
	for raw: Variant in library.kinds_for(_brief):
		for entry: Variant in (raw as Dictionary).get("accents", []):
			var part_id: String = str((entry as Array)[0])
			if named_accent.has(part_id) or have.has(library.resolve(part_id)):
				continue
			named_accent[part_id] = true
			accents.append("  %s %s — one or two, in %d%% of them" % [part_id,
				_part_called(part_id), int((entry as Array)[1])])
	if not accents.is_empty():
		said.append("The pieces real %s sets use one or two of, which the "
			% " and ".join(kinds) + "whole model has none of — the "
			+ "accents, where something happens:\n"
			+ "\n".join(accents.slice(0, 12)))
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
		# Everything is inside no box at all: working out where each brick
		# is first was most of what reviewing a whole model cost.
		if where.is_empty() or _inside(_to_studs(brick, info), where):
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


## The commonest colour among some bricks, and its share in percent.
func _main_colour(bricks: Array[BrickWorld.Brick]) -> Array:
	var per: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		per[brick.color_code] = int(per.get(brick.color_code, 0)) + 1
	var best: int = 0
	var most: int = 0
	for code: int in per:
		if int(per[code]) > most:
			most = int(per[code])
			best = code
	return [best, 0 if bricks.is_empty() else 100 * most / bricks.size()]


## How many shapes some bricks use only once or twice.
func _once_or_twice(bricks: Array[BrickWorld.Brick]) -> int:
	var per_part: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var id: String = library.resolve(brick.part_id)
		per_part[id] = int(per_part.get(id, 0)) + 1
	return per_part.values().filter(func(n: int) -> bool:
		return n <= 2).size()


## How big a piece has to be to count as a big one, in plates: studs
## across by studs deep by plates tall with its studs. A 2 x 4 brick, a
## 1 x 8 and a 4 x 4 plate are as big; a 1 x 6 and a 2 x 3 are not. The
## same rule as piece_size in tools/rebrickable.py, which the norm in
## set_norms is measured with, and the comparison is only fair because
## of that.
const BIG_PIECE := 24.0


## How big a building piece is, in plates, or -1 for what is not one: a
## figure, a sticker, a base plate.
func _piece_size(part_id: String) -> float:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null or info.category in ["Baseplate", "Figure", "Animal"] \
			or info.category.begins_with("Minifig") \
			or info.category.begins_with("Sticker"):
		return -1.0
	return (info.size.x / 20.0) * (info.size.z / 20.0) \
		* maxf(info.size.y, 8.0) / 8.0


## What share of some parts, by id, are as big as a 2 x 4 brick, as
## [per cent, the commonest big one].
##
## A real set is a median 10% at every size from 350 parts up, and more
## than about 20% is coarser than all but one set in twenty. Every
## castle built here was 39-56%: curtain walls in 2 x 10 bricks, which
## is a wall nothing can happen in — no window, no masonry brick, no
## second grey — because there is no small piece in it to be one.
func _coarse(part_ids: PackedStringArray) -> Array:
	var sized: int = 0
	var big: Dictionary = {}
	var count: int = 0
	for part_id: String in part_ids:
		var size: float = _piece_size(part_id)
		if size < 0.0:
			continue
		sized += 1
		if size >= BIG_PIECE:
			count += 1
			big[part_id] = int(big.get(part_id, 0)) + 1
	var commonest: String = ""
	for part_id: String in big:
		if commonest.is_empty() or int(big[part_id]) > int(big[commonest]):
			commonest = part_id
	return [0 if sized == 0 else 100 * count / sized, commonest]


static func _ids_of(bricks: Array[BrickWorld.Brick]) -> PackedStringArray:
	var ids := PackedStringArray()
	for brick: BrickWorld.Brick in bricks:
		ids.append(brick.part_id)
	return ids


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

Four things to catch by name: windows as a repeating grid (few, each \
with a reason, coloured by the subject); a face of one dark colour with \
nothing on it (texture in that colour, a second tone in bands, depth); a shape \
with no profile (taper, flare, a top that grows out of it); and a base \
that is an afterthought (a composed plinth that leads the eye up).

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
## How a refused key is reported, so the panel can tell it from the rest
## and ask for another.
const KEY_REFUSED := "Anthropic refused that key."
## How a run with no key at all ends. The panel never sends one, because
## it shows the key form instead; this is for everything else that can
## start a design, the command line among them.
const NO_KEY := ("No Anthropic key. Paste one into the assistant panel, "
	+ "or set ANTHROPIC_API_KEY.")


static func _what_went_wrong(code: int) -> String:
	match code:
		0:
			return ("Could not reach the assistant. Check the "
				+ "connection and try again — nothing was spent.")
		401, 403:
			return (KEY_REFUSED + " Check it at console.anthropic.com "
				+ "and paste it again.")
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
	# About a selection, nothing outside it was this run's to regroup or to
	# put back: an edit that landed is one step of the history.
	var scoped: bool = _scoped
	_scoped = false
	if not scoped:
		_tag_assemblies()
	# A design that failed leaves the model it was asked to change
	# exactly as it found it. Without this a revision that ran out of
	# repairs took the original with it — and the drafts shown along the
	# way are what removed it.
	if not ok and not _edited and not scoped:
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
	_record_run()

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


## What a tool hands back, and what it did for the feature being worked, if
## one is (see [method _feature_brief]).
func _run_tool(block: Dictionary) -> Variant:
	var before: int = world.brick_count() if world != null else 0
	var answer: Variant = await _tool_answer(block)
	if str(block.get("name", "")) == "find_techniques":
		var named: String = _feature_named(str((block.get("input", {}) as Dictionary).get(
			"query", "")))
		if not named.is_empty():
			_feature_now = named
	if _feature_now.is_empty():
		return answer
	var name: String = str(block.get("name", ""))
	var args: Dictionary = block.get("input", {}) as Dictionary
	var grew: bool = world != null and world.brick_count() != before
	var head: String = str(answer if answer is String else (
		(answer as Array)[0].get("text", "") if answer is Array and not (answer as Array).is_empty()
			and (answer as Array)[0] is Dictionary else ""))
	var refused: bool = head.begins_with("Not applied") or head.begins_with("Nothing in that") \
		or head.begins_with("No brick") or head.begins_with("That would")
	match name:
		"find_techniques":
			_note_feature("looked up " + str(args.get("query", "")))
		"show_technique":
			var worked: Dictionary = Techniques.named(str(args.get("name", "")))
			if not worked.is_empty():
				_note_feature("technique " + str(worked["name"]))
		"place_technique":
			if grew:
				_note_feature("placed " + str(args.get("id", "")))
		"edit_model", "edit_selection":
			if not _laying_whole and (grew or not refused):
				_note_feature("edited")
	return _with_features_left(name, answer)


## A session from outside, changing the model, is told the features it
## listed that have had no turn yet, on every change: told once, in the
## build's answer, the held-out owl worked none of them, looked at the whole
## once and saved.
func _with_features_left(name: String, answer: Variant) -> Variant:
	if _busy or not _outside_standing or not name in ["edit_model", "place_technique"] \
			or _laying_whole:
		return answer
	var left: Array[String] = _features_left()
	if left.is_empty():
		return answer
	var line: String = ("Features not settled yet: %s — review_model {\"feature\": \"%s\"} "
		% [", ".join(left), left[0]] + "lays the app's piece for it, to settle with "
		+ "settle_feature. Saving waits until each is settled.")
	if answer is String:
		return "%s\n\n%s" % [answer, line]
	if answer is Array:
		return (answer as Array) + [{"type": "text", "text": line}]
	return answer


## What a tool hands back.
##
## A String for most of them. An Array of content blocks when the answer
## includes a picture, which Anthropic accepts in a tool result exactly
## as it does in a message.
func _tool_answer(block: Dictionary) -> Variant:
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
			await _ready_to_check(trial)
			var running: bool = _busy
			var report: Dictionary = await _checked(trial, false, true)
			# This app's own run, stopped while it was checked.
			if running and not _busy:
				return ""
			# On screen, not just counted. A design runs for minutes and
			# checks its work two or three times along the way; those
			# are the only glimpses of the shape there are before the
			# end, and they were being thrown away.
			# Only while this app's own run is composing. Once an edit has
			# landed, the model on the baseplate is the person's model, and a
			# check of fifteen bricks would replace the hundred and forty that
			# are standing — and report it as a successful check. Nor about a
			# selection: the model round it is the person's. And never from
			# outside, where the session has no draft to show and a check is
			# only a check: a session testing how one part seats wiped a
			# 2,900 part Orthanc this way, and once a design had been built
			# that was stopped — but a model opened, or built in another
			# session, was still checked onto: the owner's test gear and axle
			# came out on the baseplate as bricks #223 and #224.
			var applied: bool = _busy and not trial.placements.is_empty() \
				and not _edited and not _keeps_to_focus()
			if applied:
				await _apply(trial, false, true)
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
			var weighed: String = _balance_said(report, trial, applied)
			return await _with_a_look(str(report["feedback"])
				+ ("" if weighed.is_empty() else "\n\n" + weighed),
				"Look at it. Does it read as the thing it is meant to "
				+ "be? If not, that is worth more than another brick. "
				+ "view_model gives any other side.")
		"attachment_points":
			progress.emit("working out where things attach")
			return await _attachment_points(args)
		"search_gear_ratio":
			progress.emit("searching gear trains for a ratio")
			return gear_ratio_said(args)
		"show_technique":
			var wanted: String = str(args.get("name", ""))
			progress.emit("looking up how to do %s" % wanted)
			return _show_technique(wanted)
		"read_guide":
			var section: String = str(args.get("section", ""))
			progress.emit("reading the guide on %s" % section)
			return _for_the_subject(section, read_guide(section))
		"find_techniques":
			var query: String = str(args.get("query", ""))
			progress.emit("looking up how real sets built %s" % query)
			return await _find_techniques(query, float(args.get("max_studs", 0.0)),
				args.get("kinds", []) as Array)
		"place_technique":
			progress.emit("laying %s as a real set built it" % str(args.get("id", "")))
			return await _place_technique(args)
		"find_parts_like":
			var query: String = str(args.get("query", ""))
			progress.emit("looking for a part that reads as %s" % query)
			return await _find_parts_like(query)
		"plan_scale":
			progress.emit("working out how big it should be")
			heard(str(args.get("subject", "")))
			return _plan_scale(args)
		"find_reference":
			var subject: String = str(args.get("subject", ""))
			progress.emit("looking up what a %s looks like" % subject)
			heard(subject)
			return await _find_reference(subject)
		"how_real_sets_build_this":
			var subject: String = str(args.get("subject", ""))
			progress.emit("looking up how real sets build a %s" % subject)
			heard(subject)
			# And what our own scored designs of the nearest subject did and
			# were faulted for: asked once, with the subject, before building.
			await DesignMemory.ensure(self)
			return [{"type": "text", "text": str(_how_real_sets_build_this(subject)["content"])}] \
				+ DesignMemory.recall(subject)
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
		"restyle_model":
			progress.emit("dressing the plain faces")
			var change: Dictionary = _restyle(args)
			if change.is_empty():
				return ("Nothing to restyle: no plain brick one or two studs "
					+ "wide with an open face in that box.")
			if not change.has("edit"):
				return str(change["summary"])
			_laying_whole = true
			var said: Variant = await _run_tool({"name": "edit_model",
				"input": change["edit"]})
			_laying_whole = false
			if said is Array:
				return [{"type": "text", "text": change["summary"]}] + (said as Array)
			return "%s\n%s" % [change["summary"], str(said)]
		"add_rooms":
			progress.emit("laying floors and furnishing the rooms")
			var rooms: Dictionary = await _rooms(args)
			if rooms.has("trouble"):
				return str(rooms["trouble"])
			# Seen from the side the rooms open to, in their own colours: an
			# edit's picture is from a corner with what it added in magenta,
			# which is a picture of where the rooms are and not of them.
			_look_after_edit = {"from": rooms["view"], "only": rooms["box"],
				"ask": "That is what it looks like now, from the side the rooms "
					+ "open to. Does each read as the room it is?"}
			_laying_whole = true
			var laid: Variant = await _run_tool({"name": "edit_model",
				"input": {"add": rooms["bricks"]}})
			_laying_whole = false
			_look_after_edit = {}
			if laid is Array:
				return [{"type": "text", "text": rooms["summary"]}] + (laid as Array)
			return "%s\n%s" % [rooms["summary"], str(laid)]
		"make_art":
			# A picture laid as a LEGO Art set, to a plan: see
			# src/assembly/art_plan.gd.
			if _keeps_to_focus():
				return _not_while_scoped()
			progress.emit("laying out a Brick Art picture")
			return await _make_art(args)
		"look_at_picture":
			progress.emit("looking at the picture")
			return _look_at_picture()
		"make_part":
			# A part LEGO has not made, made as a person makes one: see
			# src/parts/part_tool.gd. Not in a run kept to a list of parts.
			if not PartsOnly.tool_refusal(name).is_empty():
				return PartsOnly.tool_refusal(name)
			progress.emit("making a part")
			return await PartTool.run(args, library)
		"add_minifig":
			# The figure is made and stood up in src/minifig/figure_tool.gd.
			# Its parts are this design's, so a new submission replaces
			# them along with everything else it built.
			if _keeps_to_focus():
				return _not_while_scoped()
			progress.emit("standing %s in the model" % str(args.get("name", "a figure")))
			var stood: Dictionary = await FigureTool.add(args, library, world, builder)
			_placed_ids.append_array(stood["ids"])
			if not bool(stood["ok"]) or not ModelShot.possible():
				return str(stood["text"])
			return await _with_a_look(str(stood["text"]), "Is it where it "
				+ "should be, the right size for the place, facing the right way?",
				"corner", (stood["box"] as AABB).grow(60.0))
		"edit_model":
			var edited: Model = _edit(args)
			_say_shorthand_trouble()
			if not _bad_colours.is_empty():
				progress.emit("tried a change in a colour that does not exist")
				return ("Not applied — %s. " % "; ".join(_bad_colours)
					+ _colour_advice())
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
			var sprinkled: String = "" if _laying_whole else _sprinkled(edited)
			if not sprinkled.is_empty():
				progress.emit("tried to sprinkle dressing over a dark wall")
				return "Not applied — " + sprinkled
			await _ready_to_check(edited)
			# About a selection: only inside its room, said before anything
			# is checked, because nothing outside it is this request's.
			var scoped: bool = _keeps_to_focus()
			if scoped:
				var beyond: PackedStringArray = _beyond_focus(edited)
				if not beyond.is_empty():
					progress.emit("tried a change outside the selection")
					return _refused_beyond(beyond)
			var running: bool = _busy
			var verdict: Dictionary = await _checked(edited, true)
			if running and not _busy:
				return ""
			if not bool(verdict["ok"]):
				progress.emit("tried a change: %s" % verdict["summary"])
				# About a selection, why each part was refused and the
				# nearest place it does fit, so a refusal teaches.
				return ("Not applied — the model would not hold together.\n"
					+ str(verdict["feedback"]) + (_what_would_fit(edited, verdict)
						if scoped else ""))
			# A pass laying its own proposal (SurfacePass) must not leave the
			# model in more pieces: what it took off may have held some together.
			if _keep_pieces >= 0 and int(verdict.get("pieces", 0)) > _keep_pieces:
				progress.emit("tried a change that would split the model")
				return ("Not applied — it would leave the model in %d pieces, where it is "
					% int(verdict.get("pieces", 0)) + "in %d." % _keep_pieces)
			if scoped:
				var hanging: String = await _left_hanging(edited)
				if running and not _busy:
					return ""
				if not hanging.is_empty():
					progress.emit("tried a change that leaves the rest hanging")
					return "Not applied — the model would not hold together: " + hanging
			if _trial_only:
				progress.emit("tried a change without making it: it would hold")
				return ("It would be applied: it keeps to the room, holds together and "
					+ "leaves nothing hanging (%d bricks). Nothing has changed yet: give "
					% edited.placements.size()
					+ "edit_selection the same change without check_only to make it.")
			# The "before" the panel shows, if nothing has drawn it yet: a
			# session may change a selection without reading it first.
			if scoped and focus.before == null and ModelShot.possible():
				_ensure_shot().highlight = {}
				focus.before = await _shot.take(world, "corner", scenery, focus.region)
			var standing_was: Dictionary = SelectionScope.snapshot(world, scenery) \
				if scoped else {}
			_apply_edit(edited)
			_name_assemblies(edited.assemblies)
			_pending = null
			_edited = true
			progress.emit("changed it: %d bricks%s"
				% [edited.placements.size(), _shorthand_used(args)])
			var said: String = "Done. %d bricks now." % edited.placements.size()
			if not _unknown.is_empty():
				said += " No brick has %s, so those were left alone." \
					% _numbers(_unknown)
			if scoped:
				var words: String = _gather_focus_step(standing_was)
				# What held is known for the edit as it landed; copies that
				# followed it are new parts, and asked about afresh.
				_hanging_before = [world.revision] + _hanging_after \
					if focus.followed == 0 else []
				return await _focus_answer(said, words)
			# A pass laying its own proposal shows one picture of all of it
			# afterwards (SurfacePass): a picture per edit is time thrown away.
			if _quiet_edit:
				return said
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
			var from: String = "corner"
			if not _look_after_edit.is_empty():
				_shot.highlight = {}
				ask_about_it = str(_look_after_edit["ask"])
				from = str(_look_after_edit["from"])
				framed = _look_after_edit["only"]
			var answer: Variant = await _with_a_look(said, ask_about_it,
				from, framed)
			_shot.highlight = {}
			return answer
		"selection":
			progress.emit("looking at what is selected")
			return await selection_said()
		"edit_selection":
			progress.emit("trying a change to the selection" if bool(args.get("check_only", false))
				else "changing the selection")
			return await _edit_selection(args)
		"settle_feature":
			return await _settle_feature(args)
		"where_to_attach":
			progress.emit("finding where parts fit on the selection")
			return await _where_to_attach(args)
		"settle_surface":
			progress.emit("settling the surface pass: %s %s" % [str(args.get("finding", "")),
				str(args.get("verdict", ""))])
			return await surface_pass().settle(args)
		"submit_design":
			# Asked about part of the model, a whole new one is not an answer.
			if _keeps_to_focus():
				return ("Not applied — the person asked about the parts they "
					+ "selected, and submit_design would replace the model. Change "
					+ "them with edit_selection.")
			if bool(args.get("sketch", false)) or _sketch_round:
				return await _hold_sketch(args)
			# A whole design instead of choosing: the sketches are done with.
			if not _held_sketches.is_empty():
				_held_sketches = []
				sketch_chosen.emit(0)
			_last_submitted = args
			_pending = _read_model(args)
			progress.emit("submitted %d bricks%s"
				% [_pending.placements.size(), _shorthand_used(args)])
			_say_shorthand_trouble()
			return "Received. Checking it now."
		"choose_sketch":
			return await choose_sketch(int(args.get("sketch", 0)))
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
	model.assemblies = _assemblies_named()
	if world == null:
		return model
	# The sketch counts as the assistant's. Those bricks are on the
	# baseplate with numbers of their own, so an edit can name one; if
	# they were treated as somebody else's work they would survive every
	# later design as orphans nobody could account for.
	var mine: Dictionary = {}
	for brick_id: int in _placed_ids + _sketched_ids:
		mine[brick_id] = true
	_forget_moved_sections()
	var adopted: Dictionary = _adopted()
	for section: Section in _adoptions.values():
		model.sections[section.name] = section
	model.link_sections()
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		if adopted.has(brick.id):
			var read: Array = adopted[brick.id]
			var kept_in := Placement.new()
			kept_in.part = brick.part_id
			kept_in.color = brick.color_code
			kept_in.section = str(read[0])
			kept_in.x = float(read[1])
			kept_in.y = float(read[2])
			kept_in.z = float(read[3])
			kept_in.face = str(read[4])
			kept_in.rot = int(read[5])
			kept_in.id = brick.id
			kept_in.mine = mine.has(brick.id)
			kept_in.group = brick.group
			kept_in.unit = brick.unit
			kept_in.standing_at = brick.transform
			kept_in.standing_part = brick.part_id
			model.placements.append(kept_in)
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
			if kept.size() > 5 and kept[5] is Vector3:
				placement.nudge = kept[5]
		elif _nudged.has(brick.id):
			# Seated past its cell (a leg on its hips, by their connectors): read
			# as it was written while it still stands there, so a later edit that
			# moves it moves it from its joint and not from the cell under it.
			var kept: Array = _nudged[brick.id]
			var was := Placement.from_dict({"part": brick.part_id, "x": kept[0], "y": kept[1],
				"z": kept[2], "face": kept[3], "rot": kept[4]})
			was.nudge = kept[5]
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh != null and _square_transform(was, mesh).origin.distance_to(
					brick.transform.origin) < 0.01 and _square_transform(was, mesh).basis \
					.is_equal_approx(brick.transform.basis):
				placement.x = was.x
				placement.y = was.y
				placement.z = was.z
				placement.face = was.face
				placement.rot = was.rot
				placement.nudge = was.nudge
			else:
				_nudged.erase(brick.id)
		placement.name = str(_given_names.get(brick.id, ""))
		placement.id = brick.id
		placement.mine = mine.has(brick.id)
		placement.group = brick.group
		placement.unit = brick.unit
		placement.standing_at = brick.transform
		placement.standing_part = brick.part_id
		model.placements.append(placement)
	return model


## A brick the window has turned or moved since it was laid in a section is
## no longer where its section says, so the section is forgotten for it and
## it is read where it stands. Read back by its section, a panel tipped in
## the inspector went back to where it had been at the next edit.
func _forget_moved_sections() -> void:
	if _section_of.is_empty() or world == null or library == null:
		return
	var linked := Model.new()
	linked.sections = _sections.duplicate()
	linked.link_sections()
	for brick_id: int in _section_of.keys():
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var section: Section = linked.sections.get(_section_of[brick_id])
		var kept: Array = _local_of.get(brick_id, [])
		if brick == null or section == null or kept.size() < 5:
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var was := Placement.from_dict({"part": brick.part_id, "x": kept[0], "y": kept[1],
			"z": kept[2], "face": kept[3], "rot": kept[4]})
		if kept.size() > 5 and kept[5] is Vector3:
			was.nudge = kept[5]
		var said: Transform3D = section.placed() * _square_transform(was, mesh)
		var basis: Basis = brick.transform.basis.orthonormalized()
		var same: bool = said.origin.distance_to(brick.transform.origin) < 1.0
		for k: int in 3:
			same = same and said.basis[k].normalized().dot(basis[k]) > 0.9995
		if not same:
			_section_of.erase(brick_id)
			_local_of.erase(brick_id)


## The assemblies the design standing has named: by the run of this app's
## own loop, or by a session from outside.
func _assemblies_named() -> Array[Dictionary]:
	return (_declared if not _declared.is_empty()
		else _outside_assemblies).duplicate()


## Name the design's assemblies, as an edit left them: where the run is
## this app's own loop, it tags its bricks with them as it ends; from
## outside, review_model and saving read them.
func _name_assemblies(named: Array[Dictionary]) -> void:
	if _outside_standing or not _outside_assemblies.is_empty():
		_outside_assemblies = named.duplicate()
	else:
		_declared = named.duplicate()


## The sections of the bricks that came without one, as [section name, x, y,
## z, face, rot] by brick id: a model opened from a file keeps where each
## brick is and not the section it was laid in. Read back at the nearest
## square turn and the nearest cell, a prism's faces were checked and dressed
## where they are not — the shipped Orthanc was told of sky through slits no
## picture of it shows, and of 559 pieces of speckle on ribs that run straight
## up its faces. Bricks turned the same way about the upright whose origins
## fall on one 2 LDU lattice were laid in one frame, so they are one section:
## turned by that much, its origin the point of that lattice nearest the
## middle of what stands, where a side looking away from it is out, as a
## prism's faces are read. And so are bricks tipped the same way about a flat
## axis: a starfighter's wings opened ten degrees on their hinges and a
## crane's boom raised on its pin, read back square, were sixteen pieces where
## the session that built them had one, the tiles on each wing a plate's gap
## above it. A square brick stays in the main body, and a
## minifigure's parts are left as they were. Inside a section the joint rules
## hold as they do anywhere — a pane in its frame, a turntable's top on its
## base — for a reader that keeps the section; one that copies a placement
## without it has the turn wrong, as it had before at the nearest square one.
## The sections are kept until the world is cleared, so a brick an edit adds
## to one is where the next reading says it is.
func _adopted() -> Dictionary:
	var out: Dictionary = {}
	if world == null or library == null:
		return out
	if world.generation() != _adoptions_of:
		_adoptions.clear()
		_adoptions_of = world.generation()
	var middle := Vector3.INF
	for brick: BrickWorld.Brick in world.bricks():
		# A figure stands on no stud grid, and its parts nest in each other.
		if scenery.has(brick.id) or _section_of.has(brick.id) or _figure_part(brick.part_id):
			continue
		var axis: String = ""
		var turn: float = NAN
		for one: String in ["y", "x", "z"]:
			turn = _turn_about(brick.transform.basis, one)
			if not is_nan(turn):
				axis = one
				break
		# Turned two ways or more — a dome's panel faced round it and tipped to
		# its curve — it was laid in a frame turned so, which is the least turn
		# that squares it. Left square, the next edit re-seated every panel of
		# a dome flat.
		var whole := Basis()
		if is_nan(turn):
			var basis: Basis = brick.transform.basis.orthonormalized()
			whole = (basis * BrickLattice.snap_basis(basis).inverse()).orthonormalized()
			if BrickLattice.is_square_to_grid(whole):
				continue
			axis = "any"
			turn = 0.0
		var pin: Vector3 = Section.pin_of(axis)
		var unturn := Basis(pin, -deg_to_rad(turn)) if axis != "any" else whole.inverse()
		var local: Vector3 = unturn * brick.transform.origin
		# A square brick is read where it is, as it always was: the cell it
		# rounds to is at most an LDU off, which every joint rule allows. Put
		# in a section of its own when its origin was off the lattice, a pane
		# seated half a stud into its frame came back in that section's
		# coordinates, and a reader that copied it without its section stood
		# it across the frame (joints_probe).
		if turn == 0.0 and axis != "any":
			continue
		var angles: Vector3 = Section.angles_of(whole)
		var rest := Vector3(_on_lattice(local.x), _on_lattice(local.y), _on_lattice(local.z))
		var key: String = "%s %.2f %.1f %.1f %.1f" % [axis, turn, rest.x, rest.y, rest.z]
		if axis == "any":
			key = "any %.2f %.2f %.2f %.1f %.1f %.1f" % [angles.x, angles.y, angles.z,
				rest.x, rest.y, rest.z]
		var section: Section = _adoptions.get(key)
		if section == null:
			if middle == Vector3.INF:
				middle = Vector3.ZERO
				for one: BrickWorld.Brick in world.bricks():
					middle += one.transform.origin
				middle /= maxf(1.0, float(world.brick_count()))
			var near: Vector3 = unturn * middle
			# Along the pin the lattice is where it is; across it, the point
			# of it nearest the middle.
			var square := rest
			for k: int in 3:
				if pin[k] == 0.0 or axis == "any":
					square[k] = rest[k] + BrickLattice.CELL * round((near[k] - rest[k])
						/ BrickLattice.CELL)
			var origin: Vector3 = unturn.inverse() * square
			var name: String = "turned %s" % Placement._num(turn) if axis == "y" \
				else "tipped %s about %s" % [Placement._num(turn), axis]
			if axis == "any":
				name = "turned %s, %s, %s" % [Placement._num(snappedf(angles.x, 0.1)),
					Placement._num(snappedf(angles.y, 0.1)), Placement._num(snappedf(angles.z, 0.1))]
			var named: String = name
			var n: int = 1
			while _sections.has(named) or _adoptions.values().any(
					func(other: Section) -> bool: return other.name == named):
				n += 1
				named = "%s %d" % [name, n]
			if axis == "any":
				section = Section.from_dict({"name": named, "x": origin.x / STUD,
					"y": origin.y / PLATE, "z": origin.z / STUD, "yaw": angles.x,
					"pitch": angles.y, "roll": angles.z})
			else:
				section = Section.from_dict({"name": named, "x": origin.x / STUD,
					"y": origin.y / PLATE, "z": origin.z / STUD, "axis": axis, "degrees": turn})
			_adoptions[key] = section
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var square: Transform3D = section.placed().affine_inverse() * brick.transform
		var face: String = BrickLattice.face_of(square.basis)
		var rot: int = BrickLattice.turns_about(square.basis, face)
		var cell := Vector3i(roundi(square.origin.x / BrickLattice.CELL),
			roundi(square.origin.y / BrickLattice.CELL), roundi(square.origin.z / BrickLattice.CELL))
		var at: Vector3 = BrickLattice.to_ldu(cell
			+ _corner_cell(mesh, brick.part_id, BrickLattice.basis_for(face, rot)))
		out[brick.id] = [section.name, at.x / STUD, at.y / PLATE, at.z / STUD, face, rot]
	return out


## How far a brick is turned about [param axis] (x, y or z, as a section's)
## off the square, in degrees from 0 up to 90, or NAN when it is turned some
## other way as well.
static func _turn_about(basis: Basis, axis: String) -> float:
	var pin: Vector3 = Section.pin_of(axis)
	# Measured from a flat line across the pin, the way Basis turns it.
	var across: Vector3 = Vector3.UP if axis == "x" else Vector3.RIGHT
	var onward: Vector3 = pin.cross(across)
	var turned: Basis = basis.orthonormalized()
	for n: int in 3:
		var column: Vector3 = turned[n]
		if absf(column.dot(pin)) > 0.001:
			continue
		var turn: float = snappedf(fposmod(rad_to_deg(atan2(column.dot(onward),
			column.dot(across))), 90.0), 0.01)
		if turn >= 90.0 - 0.01:
			turn = 0.0
		var square: Basis = Basis(pin, -deg_to_rad(turn)) * turned
		var snapped: Basis = BrickLattice.snap_basis(square)
		for k: int in 3:
			if square[k].dot(snapped[k]) < 0.9999:
				return NAN
		return turn
	return NAN


## Where a coordinate falls on the 2 LDU lattice, to a tenth of an LDU:
## 0 when on it.
static func _on_lattice(value: float) -> float:
	var rest: float = snappedf(fposmod(value, BrickLattice.CELL), 0.1)
	return 0.0 if rest >= BrickLattice.CELL - 0.05 else rest


## Apply a patch to what is built, and say what it came to.
##
## Removals first, so that a brick can be taken away and another put in
## its place in one call without the two fighting over the same cells.
## What an edit asked for that was not there. Filled by [method _edit],
## read by whoever reports the result: an edit that named forty bricks
## and found none of them used to come back as "Done", with nothing
## changed and the run ended as a success.
var _unknown: PackedInt64Array = PackedInt64Array()
## Recolours an edit asked for in a colour no part can be, said in
## words. An edit with any is refused whole, the way a design with a
## brick in one is: carried out, it painted bricks magenta.
var _bad_colours: PackedStringArray = PackedStringArray()
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

	_bad_colours = PackedStringArray()
	for raw: Variant in args.get("recolor", []):
		var order: Dictionary = raw
		if not order.has("color"):
			_bad_colours.append("a recolor names no colour")
			continue
		var colour: int = int(order.get("color"))
		var trouble: String = _colour_trouble(colour)
		if not trouble.is_empty():
			_bad_colours.append(trouble)
			continue
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
	# Parts turned where they stand, as the window's Turn, Tilt and Roll
	# turn a selection: about the middle of what is named, which becomes a
	# section turned so, within whatever they were built in.
	var turn_trouble: Array = []
	for raw: Variant in args.get("turn", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var said: String = _turn_bricks(model, raw, by_id)
		if not said.is_empty():
			turn_trouble.append(said)

	# Said in part, an edit changes only what it says: a new pitch on a
	# panel keeps its place, its hinge and what it is built in.
	for raw: Variant in args.get("sections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var name: String = str((raw as Dictionary).get("name", "")).strip_edges()
		if name.is_empty():
			continue
		var was: Section = model.sections.get(name)
		var section: Section = Section.from_dict(raw, was)
		model.sections[section.name] = section
		model.link_sections()
		# What is built in it moves with it, at any depth.
		var moving: Dictionary = {section.name: true}
		for inner: Section in model.sections_within(section.name):
			moving[inner.name] = true
		for placement: Placement in model.placements:
			if moving.has(placement.section):
				placement.moved = true
		if section.hinge or (was != null and was.hinge):
			_rehinge(model, section, was)
		_touched += 1

	# And name a part of it: a stand or a sign added in front of a model
	# stands apart on purpose, and the check takes it as an item of its own
	# only when it is named (_standing_apart). One of the same name is
	# moved to the new box.
	for one: Dictionary in _read_assemblies(args):
		var replaced: bool = false
		for n: int in model.assemblies.size():
			if str(model.assemblies[n]["name"]).to_lower() == str(one["name"]).to_lower():
				model.assemblies[n] = one
				replaced = true
		if not replaced:
			model.assemblies.append(one)
		_touched += 1

	for raw: Variant in args.get("add", []):
		model.placements.append(_said_placement(raw))
		_touched += 1
	_attach_parts(model)
	_turned_parts(model)

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
	_repeat_trouble = turn_trouble
	_pattern_trouble = []
	_pattern_advice = []
	_expand_repeats(model, args, _repeat_trouble)
	_onto_lines(model)
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
	# And how many were put by their connectors, so a run's log says whether
	# a session reached for joints at all.
	var attached: int = 0
	for key: String in ["bricks", "add"]:
		if not (args.get(key) is Array):
			continue
		for raw: Variant in args[key]:
			if raw is Dictionary and (raw as Dictionary).has("attach"):
				attached += 1
	if attached > 0:
		said.append("%d attached" % attached)
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
## committing to it. A coroutine: on the web a part's geometry arrives when
## it is first asked for, and this waits for it rather than answer that it
## has not — the owner's session was told so of a Technic beam, 32523.
func _attachment_points(args: Dictionary) -> String:
	var at: Transform3D
	var part_id: String
	var label: String
	## What attach names its connectors by: "#41." for a brick standing.
	var prefix: String = ""

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
		prefix = "#%d." % brick_id
	else:
		part_id = str(args.get("part", ""))
		if not library.parts.has(part_id):
			return "No part '%s' exists." % part_id
		var hypothetical := Placement.from_dict(args)
		var mesh: Lbm.PartMesh = await _geometry_of(part_id)
		if mesh == null:
			return "The geometry for %s could not be fetched; ask again." % part_id
		_on_its_line(hypothetical)
		if not hypothetical.odd_axis.is_empty():
			return "%s %s." % [part_id, hypothetical.odd_axis]
		at = _transform(hypothetical, mesh)
		label = "%s at %s facing %s" % [
			part_id, hypothetical.where(), hypothetical.face]

	var part: Lbm.PartMesh = await _geometry_of(part_id)
	if part == null:
		return "The geometry for %s could not be fetched; ask again." % part_id

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
	var holes: String = _holes_in(part, at, part_id) + _connectors_said(part_id, at, prefix,
		args.get("near"))

	if found > MOST_STUDS:
		return ("%s has %d studs, which is too many to list. " % [label, found]
			+ "It is a flat field of them: anything sitting on top goes "
			+ "at whole studs across and at the height of its top face."
			+ holes)
	if found == 0:
		if not holes.is_empty():
			return ("%s has no studs. It joins to things through its "
				% label + "joints instead." + shape + holes)
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


## Where a part's holes, pins and axles are, numbered, and which way each
## runs: the point a pin, an axle or a gear goes at, said as a placement
## takes it.
##
## A hole's position is the one coordinate nobody gets right by
## reasoning: it sits at the middle of the part's thickness, so on a
## beam lying flat it is half a stud up and on a 1x2 brick with a hole
## it is one and a half plates up. The whole point of this tool is not
## having to work that out, and until now it only did it for studs.
##
## And it said "a pin goes in at the position given", which was not so: a
## placement's x, y and z were its low corner, so a pin put there stood half
## a pin off the hole and was refused as an overlap with the brick it was
## meant to be in. The owner's session did exactly that with a pin, an axle
## and an axle through a 40 tooth gear. The point is now said the way a
## placement takes a middle (axis), and each hole says whether it grips an
## axle or lets it turn, which is the whole difference between a gear that
## drives and one that spins on its axle.
func _holes_in(part: Lbm.PartMesh, at: Transform3D, part_id: String = "") -> String:
	var lines: PackedStringArray = PackedStringArray()
	var joints: Array = _joint_lines(part, part_id)
	for n: int in joints.size():
		if lines.size() >= MOST_HOLES:
			lines.append("  ...and more, one every stud along it.")
			break
		var joint: Array = joints[n]
		var point: Vector3 = at * (joint[1] as Vector3)
		var way: Vector3 = (at.basis * (joint[2] as Vector3)).normalized()
		var where: String = "x=%s y=%s z=%s" % [Placement._num(point.x / STUD),
			Placement._num(point.y / PLATE), Placement._num(point.z / STUD)]
		var said: String = AXLE_WORDS.get(joint[0], "")
		if joint[0] == "axle" or joint[0] == "pin" or joint[0] == "bar":
			# Its length, so a gear or a clip can be put anywhere along it.
			said = said % _studs(float(joint[3]) * 2.0 / STUD)
		lines.append("  joint %d: %s at %s, running %s — %s" % [n, joint[0], where,
			_which_axis(way), said])
	if lines.is_empty():
		return ""
	return ("\n\nIts joints, each at its middle:\n" + "\n".join(lines)
		+ "\nTo put a pin, an axle, a gear, a bush or a clip on one, give it axis: the way the "
		+ "joint runs (\"z\" for along z) and that joint's x, y and z: they are then "
		+ "where its own middle goes, not its low corner. Slide it along by changing "
		+ "the coordinate it runs along. Its own joint by joint: n, numbered as here.")


## Every connector of a part by the address attach takes ([param prefix] and
## "hinge[0]"), with where it is in studs and plates for [param at] and the
## way it points: BrickNet's labels from its exact shape, which is where
## BrickBench's check and this one look for a connection, else the
## catalogue's. A type with many is said by its first few unless [param near]
## ([x, y, z] in studs and plates) asks for those nearest a point. "" for a
## part with none.
func _connectors_said(part_id: String, at: Transform3D, prefix: String = "",
		near: Variant = null) -> String:
	var points: Array = Attach.points_of(library, part_id)
	if points.is_empty():
		return ""
	var where: Variant = null
	if near is Array and (near as Array).size() == 3:
		where = Vector3(float(near[0]) * STUD, float(near[1]) * PLATE, float(near[2]) * STUD)
	var rows: Array = []      ## [distance, type, line]
	for point: Attach.Point in points:
		var frame: Transform3D = at * point.frame
		var way: Vector3 = (-frame.basis.y).normalized()
		var line: bool = point.kind == Exact.AXLE or point.kind == Exact.HINGE
		var spot: Vector3 = frame.origin
		rows.append([spot.distance_to(where) if where != null else 0.0, point.type,
			"  %s%s %s at x=%s y=%s z=%s, %s" % [prefix, point.address(), point.said(),
				Placement._num(snappedf(spot.x / STUD, 0.01)),
				Placement._num(snappedf(spot.y / PLATE, 0.01)),
				Placement._num(snappedf(spot.z / STUD, 0.01)),
				_pointing(way, line).replace("pointing ", "points ")]])
	var lines := PackedStringArray()
	if where != null:
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for row: Array in rows.slice(0, MOST_CONNECTORS):
			lines.append(str(row[2]))
	else:
		var shown: Dictionary = {}
		var hidden: Dictionary = {}
		for row: Array in rows:
			var type: String = row[1]
			if int(shown.get(type, 0)) < EACH_TYPE:
				shown[type] = int(shown.get(type, 0)) + 1
				lines.append(str(row[2]))
			else:
				hidden[type] = int(hidden.get(type, 0)) + 1
		for type: String in hidden:
			lines.append("  ...and %d more %s, %s%s[%d] on: near=[x, y, z] lists those by a point"
				% [hidden[type], type, prefix, type, int(shown[type])])
	var source: String = ("as BrickBench's check reads them" if (points[0] as Attach.Point).exact
		else "from the catalogue (BrickNet has no shape for it)")
	return ("\n\nConnectors, %s, by the address attach takes:\n" % source
		+ "\n".join(lines) + "\nTo put a part on one: {\"part\": ..., \"attach\": {\"to\": \"%s%s\", "
			% [prefix if not prefix.is_empty() else "<its name>.", (points[0] as Attach.Point).address()]
		+ "\"by\": \"<that part's own connector>\", \"yaw\": <degrees about the joint>}}. A stud "
		+ "takes a hole, tube or open stud; a clip or a hollow stud a bar; a pin a socket; an "
		+ "axle a cross hole; a hinge, a ball or a fixed joint its other half (same sub, in to on).")


## How many connectors attachment_points lists of a type, and near a point.
const EACH_TYPE := 6
const MOST_CONNECTORS := 16


## A direction said for a connector: up, down, +x... or "along x" for a line.
static func _pointing(way: Vector3, line: bool) -> String:
	for axis: Array in [[Vector3.UP, "up", "down", "up and down"],
			[Vector3.RIGHT, "+x", "-x", "along x"], [Vector3.BACK, "+z", "-z", "along z"]]:
		var d: float = way.dot(axis[0])
		if absf(d) > 0.99:
			return str(axis[3]) if line else "pointing " + str(axis[1] if d > 0.0 else axis[2])
	return "at an angle"


## What each kind of joint does with an axle, as a session needs to hear it.
const AXLE_WORDS: Dictionary = {
	"pin hole": "round: an axle or a pin turns in it",
	"axle hole": "grips an axle: this part turns with it",
	"axle": "an axle %s studs long: an axle hole on it turns with it, a round hole turns on it",
	"pin": "a pin %s studs long, for round holes",
	"turntable": ("where it turns: its top and its base both go here, each by axis "
		+ "\"y\" and this point"),
	"bar": ("a bar %s studs long: a clip, a hand or a hollow stud grips it anywhere "
		+ "along it, at any angle round it"),
	"clip": "grips a bar laid along this line (a clip, a hollow stud, a bar holder)",
}


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


# -- joints on a line: pins, axles, gears, bushes, beams' holes ---------------


## The lines a part joins by, in its own frame, in the order attachment_points
## numbers them: [kind, middle, way, half its length along the line]. kind is
## "axle", "pin", "axle hole" or "pin hole", then "bar" or "clip" ([method
## _bar_kind]). An axle's or a pin's middle is
## halfway along it (Mechanism reads the same lines, Joints.through matches
## them); a hole's is halfway through the part (JointSnap.ends_of).
##
## And a turntable's turning point, given its part: where its top and its
## base share an origin and an axis (Mechanism's table, as real sets stand
## them in all 71 the OMR has), so the two are put together by one point.
static func _joint_lines(part: Lbm.PartMesh, part_id: String = "") -> Array:
	if part == null:
		return []
	var turntables: Dictionary = Mechanism.table().get("turntables", {})
	if not part_id.is_empty() and (turntables.has(part_id)
			or turntables.values().has(part_id)):
		var with: Array = _joint_lines(part).duplicate()
		var spec: Dictionary = Mechanism.spec_of(part_id)
		with.append(["turntable", Vector3.ZERO, Mechanism._axis_of(spec.get("axis", "y")),
			0.0])
		return with
	var key: int = part.get_instance_id()
	if _joints_of.has(key):
		return _joints_of[key]
	var out: Array = []
	_joints_of[key] = out
	for line: Array in Joints._lines_of(part)[0]:
		var from: float = line[3]
		var to: float = line[4]
		out.append([line[0], (line[1] as Vector3) + (line[2] as Vector3) * ((from + to) * 0.5),
			line[2], (to - from) * 0.5])
	for end: JointSnap.End in JointSnap.ends_of(part):
		if not end.is_hole():
			continue
		var kind: String = "axle hole" if end.kind == "axle_hole" else "pin hole"
		var again: bool = false
		for one: Array in out:
			if one[0] == kind and (one[1] as Vector3).distance_to(end.at) < 1.0:
				again = true
		if not again:
			out.append([kind, end.at, end.axis, end.reach])
	# And after those, so a Technic part's numbering is what it was: the bars
	# and what grips one (a clip, a hollow stud, a bar holder, a hand). The
	# owner's session building a dome was told 87375, a quarter dome whose
	# two handles are bars, had no connection points at all, and gave up on
	# it.
	for connector: Lbm.Connector in part.connectors:
		var kind: String = _bar_kind(connector)
		if kind.is_empty():
			continue
		var middle: Vector3 = connector.position + connector.axis * (connector.length * 0.5)
		var again: bool = false
		for one: Array in out:
			if one[0] == kind and (one[1] as Vector3).distance_to(middle) < 1.0:
				again = true
		if not again:
			out.append([kind, middle, connector.axis, connector.length * 0.5])
	return out


## The radius of a bar, LDU: 3.18 mm across. A clip, a hand, a hollow stud
## and a bar holder grip one; LDraw draws each a round 4 LDU in radius.
const BAR_RADIUS := 4.0


## What a round connector is to a bar: "bar" (a shaft a bar's size, long
## enough to grip) or "clip" (a bore that size: a clip's eye, a hollow
## stud, a bar holder, a hand — the part file keeps no arc to tell an open
## one from a closed one, and a bar goes into either along its line), or "".
static func _bar_kind(connector: Lbm.Connector) -> String:
	if absf(connector.radius - BAR_RADIUS) > 0.5:
		return ""
	if connector.kind == "shaft" and connector.length >= 4.0:
		return "bar"
	if connector.kind == "bore" and connector.length >= 2.0:
		return "clip"
	return ""


## [method _joint_lines] by part, worked out once each.
static var _joints_of: Dictionary = {}


## Which of a part's joints is nearest its middle: the one a placement on a
## line takes when it names none. A Technic joint before a bar or a clip,
## so a part that has both is put by its pin, axle or hole as it was.
static func _middle_joint(part: Lbm.PartMesh, lines: Array) -> int:
	var centre: Vector3 = part.bounds.get_center()
	var best: int = -1
	for technic: bool in [true, false]:
		for n: int in lines.size():
			if technic and str(lines[n][0]) in BAR_KINDS:
				continue
			if best < 0 or (lines[n][1] as Vector3).distance_to(centre) \
					< (lines[best][1] as Vector3).distance_to(centre) - 0.5:
				best = n
		if best >= 0:
			return best
	return 0


## The joints a bar makes, as [method _joint_lines] names them.
const BAR_KINDS: Array[String] = ["bar", "clip"]


## The four square turns that carry [param local] onto [param want], a
## quarter apart about it: the first the nearest to the part's own way up,
## the rest that one turned on about the line.
static func _bases_onto(local: Vector3, want: Vector3) -> Array[Basis]:
	var first := Basis()
	var best: float = -INF
	for face: String in BrickLattice.FACES:
		for rot: int in 4:
			var basis: Basis = BrickLattice.basis_for(face, rot)
			if (basis * local).dot(want) < 0.99:
				continue
			var trace: float = basis.x.x + basis.y.y + basis.z.z
			if trace > best + 0.001:
				best = trace
				first = basis
	var out: Array[Basis] = []
	if best == -INF:
		return out
	for k: int in 4:
		out.append(BrickLattice.snap_basis(Basis(want, k * PI * 0.5) * first))
	return out


## Write a placement as the low corner, face and turn that put its joint
## [param line] (from [method _joint_lines]) through [param point] (LDU, in
## its own frame), running along [param basis].
func _put_on_line(placement: Placement, part: Lbm.PartMesh, line: Array,
		point: Vector3, basis: Basis) -> void:
	var origin: Vector3 = point - basis * (line[1] as Vector3)
	var cell := Vector3i(roundi(origin.x / BrickLattice.CELL),
		roundi(origin.y / BrickLattice.CELL), roundi(origin.z / BrickLattice.CELL))
	var corner: Vector3 = BrickLattice.to_ldu(cell + _corner_cell(part, placement.part, basis))
	placement.x = snappedf(corner.x / STUD, 0.01)
	placement.y = snappedf(corner.y / PLATE, 0.01)
	placement.z = snappedf(corner.z / STUD, 0.01)
	placement.face = BrickLattice.face_of(basis)
	placement.rot = BrickLattice.turns_about(basis, placement.face)


## Every placement said by its line, written as its corner, and every one
## whose corner was written at a hole put in the hole: see [method _seat].
## Run on what a design or an edit says, before anything reads where its
## parts are.
func _onto_lines(model: Model) -> void:
	for placement: Placement in model.placements:
		_on_its_line(placement)
	_seat(model)


## One placement said by its line, written as its corner; why not, in its
## odd_axis.
func _on_its_line(placement: Placement) -> void:
	if placement.axis.is_empty():
		return
	var line_way: String = placement.axis
	placement.axis = ""
	var part: Lbm.PartMesh = library.mesh_for(placement.part)
	if part == null:
		return
	var lines: Array = _joint_lines(part, placement.part)
	if lines.is_empty():
		placement.odd_axis = ("is said by its axis, but has no pin, axle, hole, bar "
			+ "or clip to put on a line; give its low corner instead")
		return
	var n: int = placement.joint if placement.joint >= 0 else _middle_joint(part, lines)
	if n >= lines.size():
		placement.odd_axis = "asks for joint %d and has %d (0 to %d)" % [n,
			lines.size(), lines.size() - 1]
		return
	var turns: Array[Basis] = _bases_onto(lines[n][2], AXES[line_way])
	if turns.is_empty():
		placement.odd_axis = ("asks for joint %d, which runs at an angle and cannot "
			+ "be put on a square line; use a section") % n
		return
	_put_on_line(placement, part, lines[n], Vector3(placement.x * STUD,
		placement.y * PLATE, placement.z * STUD), turns[placement.rot % 4])


## A pin, an axle, a gear or a bush whose low corner was written at a hole,
## or a gear's or a bush's at a point on an axle, put in it: its x, y and z
## taken for its middle, as though axis had been given.
##
## The owner's own session, building an orrery: attachment_points said 3700
## at 80, 0, 80 has a pin hole at 81, 1.75, 80.5 running along z, and "a pin
## goes in at the position given". It put 2780 there, then axle 3706, then
## an axle through a 40 tooth gear's hole, by a quarter turn and by face
## +z, and every one was refused as an overlap with the part it was meant
## to be in, because x, y and z are a part's low corner. There is no other
## reading of a joint's part whose corner is on another part's joint line:
## its own line is then off that one by its whole radius, in the other
## part's plastic. Only when the corner reading overlaps the part the hole
## is in, and only a part with no studs, so a brick is never moved.
func _seat(model: Model) -> void:
	var wanted: Array[int] = []
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		if placement.id != 0 or not placement.section.is_empty() \
				or not placement.odd_axis.is_empty() or _has_studs(placement.part):
			continue
		if _joint_lines(library.mesh_for(placement.part)).is_empty():
			continue
		wanted.append(index)
	if wanted.is_empty():
		return
	# Where they were written, and room round that for anything whose hole or
	# axle could be there: a long axle's middle is far from its ends.
	var region := AABB()
	for n: int in wanted.size():
		var one: Placement = model.placements[wanted[n]]
		var point := Vector3(one.x * STUD, one.y * PLATE, one.z * STUD)
		region = AABB(point, Vector3.ZERO) if n == 0 else region.expand(point)
	region = region.grow(STUD)
	# The holes and the axles and pins of every part that reaches there.
	var holes: Array = []    ## [index, kind, middle, way, half depth]
	var shafts: Array = []   ## [index, kind, middle, way, half length]
	var placed: Dictionary = {}
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = _joined_at(placement, part, model)
		placed[index] = at
		if not (at * part.bounds).abs().intersects(region):
			continue
		for line: Array in _joint_lines(part):
			var row: Array = [index, line[0], at * (line[1] as Vector3),
				(at.basis * (line[2] as Vector3)).normalized(), line[3]]
			if _takes_one(str(line[0])):
				holes.append(row)
			else:
				shafts.append(row)
	for index: int in wanted:
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		var point := Vector3(placement.x * STUD, placement.y * PLATE, placement.z * STUD)
		var lines: Array = _joint_lines(part)
		var found: Array = _hole_at(point, lines, holes, shafts, index)
		if found.is_empty():
			continue
		var line: Array = lines[found[0]]
		var target: Array = found[1]
		var way: Vector3 = target[3]
		# Only where the corner reading runs into the part it was meant to
		# be in: that is the mistake, and nothing else is moved.
		var other: Placement = model.placements[target[0]]
		var theirs: Lbm.PartMesh = library.mesh_for(other.part)
		if BrickLattice.shared_cells(builder.boxes_for(part, placed[index]),
				builder.boxes_for(theirs, placed[target[0]])) == 0:
			continue
		# Its own turn if that already runs along the line, else the first
		# square one that does.
		var basis: Basis = (placed[index] as Transform3D).basis
		if absf((basis * (line[2] as Vector3)).normalized().dot(way)) < 0.99:
			basis = _bases_onto(line[2], way)[0]
		var was: String = placement.where()
		_put_on_line(placement, part, line, point, basis)
		_pattern_advice.append(("brick %d (%s): put %s brick %d's %s. Its x, y, z (%s) "
			% [index, placement.part, "in" if _takes_one(str(target[1])) else "on",
				target[0], target[1], was]
			+ "were a point on that %s, so they were read as where its middle goes; " % (
				"hole" if str(target[1]).ends_with("hole") else str(target[1]))
			+ "it stands at %s face %s rot %d. Say a part by its middle with axis: \"%s\" "
				% [placement.where(), placement.face, placement.rot, _axis_name(way)]
			+ "and those x, y, z; without axis, x, y, z are its low corner."))


## The joint of a part and the hole or the axle of another that [param
## point] is on: [joint number, the other's row], or [] for none, by what
## goes into what ([constant GOES_IN]): a pin or an axle into a hole (a pin
## not into an axle hole), a bar into a clip, and each the other way round.
## A turntable's point is for a placement by its axis and nothing else.
func _hole_at(point: Vector3, lines: Array, holes: Array, shafts: Array,
		own: int) -> Array:
	for n: int in lines.size():
		var kind: String = lines[n][0]
		if not GOES_IN.has(kind):
			continue
		var male: bool = not _takes_one(kind)
		for row: Array in (holes if male else shafts):
			if row[0] == own or not (GOES_IN[kind] as Array).has(row[1]):
				continue
			var gap: Vector3 = point - (row[2] as Vector3)
			var along: float = gap.dot(row[3])
			if absf(along) > float(row[4]) + Mechanism.REACH_SLACK:
				continue
			if (gap - (row[3] as Vector3) * along).length() > Mechanism.LINE_SLACK:
				continue
			return [n, row]
	return []


## What each kind of joint line goes into, or takes: see [method _hole_at].
const GOES_IN: Dictionary = {
	"pin": ["pin hole"], "axle": ["pin hole", "axle hole"],
	"pin hole": ["pin", "axle"], "axle hole": ["axle"],
	"bar": ["clip"], "clip": ["bar"],
}


## Whether a joint line is the kind something goes into: a hole or a clip.
static func _takes_one(kind: String) -> bool:
	return kind.ends_with("hole") or kind == "clip"


## Whether a part has studs of its own (a brick, a plate), which a joint's
## part does not.
func _has_studs(part_id: String) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return true
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "stud" and connector.gender == "male":
			return true
	return false


## The name a placement's axis has for a way: "z", "-x".
static func _axis_name(way: Vector3) -> String:
	for name: String in AXES:
		if (AXES[name] as Vector3).dot(way) > 0.99:
			return name
	return "z"


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
	# And its name, for a later edit to attach to it by ("torso.hinge[0]").
	if placement.name.is_empty():
		_given_names.erase(brick_id)
	else:
		_given_names[brick_id] = placement.name
	if placement.section.is_empty():
		_section_of.erase(brick_id)
		_local_of.erase(brick_id)
		if placement.nudge == Vector3.ZERO:
			_nudged.erase(brick_id)
		else:
			_nudged[brick_id] = [placement.x, placement.y, placement.z, placement.face,
				placement.rot, placement.nudge]
		return
	_nudged.erase(brick_id)
	_section_of[brick_id] = placement.section
	# With what it sits past its cell: a part attached by its connector sits
	# exactly on it, which the cell alone does not say.
	_local_of[brick_id] = [placement.x, placement.y, placement.z,
		placement.face, placement.rot, placement.nudge]
	var section: Section = model.sections.get(placement.section)
	# And every section it is built in, and the one a hinge's frame is the
	# base of, which may have no bricks of their own: a chain of hinged
	# panels read back without its middle link falls apart.
	var seen: Dictionary = {}
	while section != null and not seen.has(section):
		seen[section] = true
		_sections[section.name] = section
		if section.base_of != null:
			_sections[section.base_of.name] = section.base_of
		section = section.base_of.parent if section.base_of != null else section.parent


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
			rows.append("  #%-4d %-9s c%-3d x=%-6s y=%-6s z=%-6s %s rot=%d%s%s%s" % [
				brick.id, brick.part_id, brick.color_code,
				Placement._num(at.x), Placement._num(at.y),
				Placement._num(at.z), face,
				BrickLattice.turns_about(brick.transform.basis, face),
				_on_line_said(brick),
				# The name a later part attaches to it by ("torso.hinge[0]").
				"   '%s'" % _given_names[brick.id] if _given_names.has(brick.id) else "",
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


## For a pin, an axle, a gear or a bush, where its line runs, said as a
## placement on a line takes it: "  axis z at 3, 5.75, 2.5". A gear to go on
## an axle listed here goes at that x and y, and any z along it. Empty for
## anything with studs, or no joint.
func _on_line_said(brick: BrickWorld.Brick) -> String:
	if _has_studs(brick.part_id):
		return ""
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	var lines: Array = _joint_lines(part)
	if lines.is_empty():
		return ""
	var line: Array = lines[_middle_joint(part, lines)]
	var point: Vector3 = brick.transform * (line[1] as Vector3)
	var way: Vector3 = (brick.transform.basis * (line[2] as Vector3)).normalized()
	if absf(way.x) < 0.99 and absf(way.y) < 0.99 and absf(way.z) < 0.99:
		return ""
	return "  axis %s at %s, %s, %s" % [_axis_name(way), Placement._num(point.x / STUD),
		Placement._num(point.y / PLATE), Placement._num(point.z / STUD)]


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
	# The lattice's own record where it has one: the same boxes, worked out
	# when the brick was registered, and this is asked for every brick each
	# time a model is read back.
	var packed: PackedInt32Array = builder.lattice.boxes_of(brick.id)
	if packed.is_empty():
		packed = builder.boxes_for(part, brick.transform)
	if packed.is_empty():
		return []
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3] - 1, packed[4] - 1, packed[5] - 1)
	for n: int in range(6, packed.size(), 6):
		lo = Vector3i(mini(lo.x, packed[n]), mini(lo.y, packed[n + 1]),
			mini(lo.z, packed[n + 2]))
		hi = Vector3i(maxi(hi.x, packed[n + 3] - 1),
			maxi(hi.y, packed[n + 4] - 1), maxi(hi.z, packed[n + 5] - 1))
	# Named by the same corner a placement is written with, or a model read
	# back and written again moves every part drawn inside its footprint.
	if BrickLattice.is_square_to_grid(brick.transform.basis):
		lo = BrickLattice.to_cell(brick.transform.origin) + _corner_cell(part,
			brick.part_id, BrickLattice.snap_basis(brick.transform.basis))
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


const PREFETCH_FOUND := 5


func _search(query: String, limit: int) -> String:
	# Kept to a list (PartsOnly), more are read so that as many are listed.
	var limited: bool = PartsOnly.active()
	var found: Array[PartLibrary.PartInfo] = library.search(query,
		maxi(1, limit) * (4 if limited else 1))
	var usable: Array[PartLibrary.PartInfo] = []
	var barred: int = 0
	for info: PartLibrary.PartInfo in found:
		if info.is_redirect() or not info.reachable:
			continue
		if not PartsOnly.allows(info.id):
			barred += 1
			continue
		if usable.size() < maxi(1, limit):
			usable.append(info)

	if usable.is_empty():
		return "No parts match '%s'%s. Try fewer or plainer words." % [query,
			" among %s (%d that do are not on it)" % [PartsOnly.named(), barred]
				if limited else ""]
	# Built from their own collection: what they own first, and how much.
	var from_collection: bool = not owned.is_empty() and Collection.wanted_in(_brief)
	if from_collection:
		usable = Collection.owned_first(usable, owned)

	# The parts a design is about to name, fetched while it is still being
	# thought about, so check_design is not the first to ask for them. Only
	# the web build fetches; the best few, since a search lists alternatives.
	if OS.has_feature("web"):
		for info: PartLibrary.PartInfo in usable.slice(0, PREFETCH_FOUND):
			if not library.is_resident(info.id):
				library.request_mesh(info.id)

	var lines: PackedStringArray = PackedStringArray()
	var told: String = ""
	for info: PartLibrary.PartInfo in usable:
		lines.append(_describe(info) + _prints_note(info)
			+ (Collection.owned_note(info.id, owned, library) if from_collection else ""))
		if told.is_empty() and not library.prints_of(info.id).is_empty():
			told = _prints_named(info)
	if not told.is_empty():
		lines.append(told)
	if barred > 0:
		lines.append("Not listed: %d more that match, which this run may not use (it uses "
			% barred + "only %s; a print or another part is refused too unless it is "
			% PartsOnly.named() + "among them).")
	var worked: String = _technique_for(query)
	if not worked.is_empty():
		lines.append(worked)
	var jointed: String = _joint_parts_for(query)
	if not jointed.is_empty():
		lines.append(jointed)
	return "\n".join(lines)


## Words of a search that ask for a limb, a neck or a joint.
const LIMB_WORDS: Array = ["arm", "arms", "leg", "legs", "limb", "limbs", "hand", "hands",
	"foot", "feet", "paw", "paws", "tail", "wing", "wings", "neck", "shoulder", "hip",
	"hips", "elbow", "knee", "knees", "joint", "joints", "pose", "posed", "flipper", "fin",
	"fins", "torso"]
## Whether this design's searches have been told of the joint parts yet.
var _joint_parts_told: bool = false


## The parts a limb goes on a joint by, said under a search for a limb, and
## under a character's first search: no session of the attach round searched
## for a limb or a joint, and every one built its limbs of bricks, stacked.
func _joint_parts_for(query: String) -> String:
	var asked: bool = not SubjectWords.first_named(query, LIMB_WORDS).is_empty()
	if not asked and (_joint_parts_told or Style.character_of(_subject_of()).is_empty()):
		return ""
	_joint_parts_told = true
	return ("For a limb, a head or a tail on a joint, at its pose's angle: a bar plate "
		+ "60478 in a clip plate 63868 (\"limb on a clip\", \"tail on a bar\"); a ball plate "
		+ "14417 or 22890 in a socket plate 14418 (\"ball shoulder\", \"head on a neck\"); "
		+ "click hinge plates 44302a and 44301a (\"hinged wing\"); a hinge brick 3937 under "
		+ "3938. Each goes on by its connectors (a part's attach), and place_technique with "
		+ "the name lays it in one call; \"posed minifigure\", \"jointed figure\" and "
		+ "\"jointed animal\" lay a whole one.")


## A worked construction for what a search asked about, said under its
## answer: a technique names the words it answers ("asked_by"). A session
## asked for "a smooth hemispherical dome on a square base" read the shapes
## guide, laid two stepped domes, searched "dome hemisphere", found a 4 x 4
## dome and built that, four studs across, never knowing four 87375 quarter
## domes make one sixteen across: the guide said so where it did not look.
static func _technique_for(query: String) -> String:
	var words: PackedStringArray = query.to_lower().split(" ", false)
	for one: Variant in Techniques.all():
		var technique: Dictionary = one
		for word: String in technique.get("asked_by", []):
			if words.has(word):
				return ("Built from real parts as sets build it: show_technique \"%s\" — %s."
					% [technique["name"], technique["when"]])
	return ""


## What a part in a search's answer has printed on it, or what prints of
## it there are, at the end of its line.
##
## A design that cannot see the prints does not know they exist: it
## builds a badge out of plates, or does without. 3623 has eleven, and
## "porsche print" did not find the one a Porsche wants (2026-10-13).
func _prints_note(info: PartLibrary.PartInfo) -> String:
	# A film goes on a face, not on studs: placed as a brick it floats.
	if info.decor() & PartLibrary.PartInfo.STICKER:
		return ", a sticker: print_part {\"brick\": N, \"sticker_part\": \"%s\", \"side\": …} " \
			% info.id + "lays it on that part's face"
	if not info.print_of.is_empty():
		return (", a print of %s" if info.decor() & PartLibrary.PartInfo.PRINTED
			else ", %s with a sticker on") % info.print_of
	var how_many: String = _prints_counted(info)
	return "" if how_many.is_empty() else ", " + how_many


## "11 prints", "25 prints and 17 stickered", or "" for a part with none.
func _prints_counted(info: PartLibrary.PartInfo) -> String:
	var printed: int = 0
	var stuck: int = 0
	for each: PartLibrary.PartInfo in library.prints_of(info.id):
		if each.decor() & PartLibrary.PartInfo.PRINTED:
			printed += 1
		else:
			stuck += 1
	var said := PackedStringArray()
	if printed > 0:
		said.append("%d print%s" % [printed, "" if printed == 1 else "s"])
	if stuck > 0:
		said.append("%d stickered" % stuck)
	return " and ".join(said)


## The first part in an answer that has prints, a few of them by what is
## on them, and how to ask for the rest.
func _prints_named(info: PartLibrary.PartInfo) -> String:
	var prints: Array[PartLibrary.PartInfo] = library.prints_of(info.id)
	var some := PackedStringArray()
	for each: PartLibrary.PartInfo in prints.slice(0, 3):
		var on_it: String = each.printed()
		if on_it.length() > 40:
			var cut: int = on_it.rfind(" ", 40)
			on_it = on_it.left(cut if cut > 0 else 40) + "…"
		some.append("%s %s" % [each.id, on_it])
	var asks: String = "\"%s print\"" % info.id
	if _prints_counted(info).contains("stickered"):
		asks += " or \"%s sticker\"" % info.id
	return ("%s has %s: %s%s. search_parts %s lists them; \"porsche print\" "
		% [info.id, _prints_counted(info), "; ".join(some),
			"; and %d more" % (prints.size() - 3) if prints.size() > 3 else "", asks]
		+ "finds any print by what is on it.")


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




## Whether the model is built like real sets of its kind: see Style.
func _style(model: Model) -> String:
	if model.placements.size() < Style.LEAST or library == null:
		return ""
	var parts: Array = []
	for placement: Placement in model.placements:
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			continue
		parts.append([placement.part, placement.color,
			_transform(placement, mesh, model.section_for(placement)), mesh.bounds])
	var about: String = _subject_of(model)
	# Its body laid by a shape: this design's, or the one on the baseplate a
	# design checked by hand would replace.
	var shaped: bool = _shaped_body
	var submitted: Variant = _last_submitted.get("patterns", [])
	if submitted is Array:
		for raw: Variant in submitted:
			shaped = shaped or (raw is Dictionary
				and str((raw as Dictionary).get("pattern", "")).to_lower() == "shape")
	return Style.advice(Style.measure(parts), Style.group_for(about), about, shaped)


## What the subject is said to be: the brief, what a session from outside said
## of it before naming a design ([member _heard]), and the design's own name
## and description.
func _subject_of(model: Model = null) -> String:
	if model == null:
		return "%s %s" % [_brief, _heard]
	return "%s %s %s %s" % [_brief, _heard, model.name, model.description]


## The subject a session was started on, or asked a tool about: kept for the
## check to read the subject by (Style.character_of). [param fresh] starts a
## new design's, as Claude Code started on a brief does.
func heard(subject: String, fresh: bool = false) -> void:
	var said: String = subject.strip_edges()
	if fresh:
		_heard = said
		_heard_fresh = said
		# What the last design from outside was called is not this one's
		# subject: a lighthouse after a statue was read as a figure.
		if not _busy:
			_brief = ""
		_joints_told = 0
		_joint_parts_told = false
		_joints_refused = false
		return
	if said.is_empty() or _heard.to_lower().contains(said.to_lower()):
		return
	_heard = ("%s %s" % [_heard, said]).strip_edges().right(HEARD_MOST)


## How much of what was heard is kept, in characters: a brief and a few subjects.
const HEARD_MOST := 1200
## From this many parts a design is a build, and a character's build is told of
## its joints.
const JOINTS_FROM := 6
## Times the joints have been said in full this design; after that, in a line.
var _joints_told: int = 0
const JOINTS_IN_FULL := 2


## Whether any part of [param model] is posed: put on another by its
## connectors, a joint's part (a clip, a bar, a ball, a hinge: Style's "a"),
## or in a section turned off the square or on a hinge.
static func _posed(model: Model) -> bool:
	for placement: Placement in model.placements:
		if not placement.attach.is_empty() or placement.attached_to != null \
				or Style.kinds_of(placement.part).contains("a"):
			return true
	for name: String in model.sections:
		var section: Section = model.sections[name]
		if section.hinge or not is_zero_approx(section.degrees) \
				or not is_zero_approx(section.yaw) or not is_zero_approx(section.pitch) \
				or not is_zero_approx(section.roll):
			return true
	return false


## A figure, a creature or a character with nothing in it on a joint, said
## with each joint's one call while how to build it is still being decided.
## Every character session of the attach round (2026-10-15) decided at its
## first submit or check, just after reading the shapes guide, and built a
## statue of stacked bricks: the joints were a line of a guide one in eight
## of them read, and the only figure line in those replies was the tail of a
## hint about small ellipsoids. "" when it is not one, or is posed.
func _on_joints_said(model: Model) -> String:
	if model.placements.size() < JOINTS_FROM:
		return ""
	var kind: String = Style.character_of(_subject_of(model))
	if kind.is_empty() or _posed(model):
		return ""
	_joints_told += 1
	if _joints_told > JOINTS_IN_FULL:
		return ("Still nothing in it is on a joint, so it stands as a statue of stacked "
			+ "bricks: put its head, limbs and tail on joints — %splace_technique \"%s\", or "
			% ["the figure pattern (\"kind\": \"%s\"), " % ("person" if kind == "figure"
				else "animal") if kind != "face" else "",
				"posed minifigure\", \"jointed figure" if kind == "figure"
				else "head on a neck\", \"limb on a clip"]
			+ "a part's attach by its connectors (read_guide \"figures\").")
	var lead: String = {
		"figure": ("  posed minifigure  a person at minifigure scale, posed in one call: arms "
			+ "swung by yaw (180 hangs at the side, 270 raised), legs bent on the hips, head "
			+ "turned, a tool in a hand\n"
			+ "  jointed figure  a person or a humanoid built of bricks, 13 plates tall: head "
			+ "on a ball neck, arms on ball shoulders bent at clip elbows, legs on click-hinge "
			+ "hips and knees, each joint's yaw the pose\n"),
		"creature": ("  jointed animal  a four-legged creature built of bricks: legs on "
			+ "click hinges, its head on a ball neck, its tail on a bar\n"),
	}.get(kind, "")
	var call: String = _figure_call(model, kind)
	return ("It is a figure, a creature or a character, and nothing in it is on a joint "
		+ "yet: stacked square, it is a statue of bricks, which is how every one built here "
		+ "was judged. %s" % ("Lay its body on joints in one entry of patterns, sized to "
			+ "this design, and build on it: %s. " % call if not call.is_empty() else "")
		+ "A set builds one of sub-assemblies of shaped parts, each put on the "
		+ "one before by its connectors at the angle its pose has. Each joint is one call, "
		+ "place_technique with its name and an x, y and z, built on after by its studs or "
		+ "posed again with an edit's yaw:\n" + lead
		+ "  limb on a clip  an arm, a leg, a flipper at an angle: a bar plate (60478) in a "
		+ "clip plate (63868), its yaw the angle\n"
		+ "  ball shoulder  a shoulder or a hip that turns every way: 14417's ball in 14418's "
		+ "socket, aimed by align\n"
		+ "  head on a neck  a head looking up, down or aside: a ball plate (22890) under a "
		+ "socket plate (14418), the head on its studs\n"
		+ "  tail on a bar  a tail raised or drooping: a clip plate (63868) on a bar plate "
		+ "(60478), its yaw raising it\n"
		+ "  hinged wing  a wing, a fin or an ear standing out: click hinge plates 44302a and "
		+ "44301a, yaw 200 lifts it\n"
		+ "Said by hand, a part goes on one named before it: {\"part\": \"60478\", \"name\": "
		+ "\"forearm\", \"attach\": {\"to\": \"elbow.clip[0]\", \"by\": \"bar[0]\", \"flip\": "
		+ "true, \"yaw\": 210}}; attachment_points lists a part's connectors by name. Its "
		+ "eyes and brows go on the same way, turned to their angle.")


## The figure pattern that lays [param design]'s character on joints, written
## out for the box and the colour the design has: what a session is handed to
## copy. "" for a design that is not a figure or a creature.
func _figure_call(design: Model, kind: String) -> String:
	var plain: Array = design.placements.filter(func(p: Placement) -> bool:
		return p.section.is_empty() and p.attach.is_empty())
	var colours: Dictionary = {}
	for placement: Placement in plain:
		colours[placement.color] = int(colours.get(placement.color, 0)) + 1
	var colour: int = 1
	var most: int = -1
	for code: Variant in colours:
		if int(colours[code]) > most:
			most = int(colours[code])
			colour = int(code)
	# The body is the box of its colour, so the entry stands on the plinth or
	# the block the design keeps rather than in it.
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for placement: Placement in plain:
		if placement.color != colour:
			continue
		var at := Vector3(placement.x, placement.y, placement.z)
		low = Vector3(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z))
		high = Vector3(maxf(high.x, at.x), maxf(high.y, at.y), maxf(high.z, at.z))
	if low.x == INF:
		low = Vector3.ZERO
		high = Vector3(6, 30, 4)
	var middle := Vector3((low.x + high.x) * 0.5, low.y, (low.z + high.z) * 0.5)
	if kind == "creature":
		var length: int = clampi(roundi(high.x - low.x), 4, 12)
		return ("{\"pattern\": \"figure\", \"kind\": \"animal\", \"at\": {\"x\": %d, \"y\": %d, "
			% [roundi(low.x), roundi(low.y)] + "\"z\": %d}, \"length\": %d, \"color\": %d, "
			% [roundi(middle.z) - (1 if length < FigurePattern.LARGE_ANIMAL else 2), length, colour]
			+ "\"pose\": {\"head\": \"up\", \"tail\": \"raised\"}}")
	if kind != "figure":
		return ""
	var tall: int = clampi(roundi(high.y - low.y + 3.0), 20, 60)
	return ("{\"pattern\": \"figure\", \"kind\": \"person\", \"at\": {\"x\": %d, \"y\": %d, "
		% [roundi(middle.x) - (3 if tall >= 34 else 2), roundi(low.y)]
		+ "\"z\": %d}, \"height\": %d, \"color\": %d, \"colors\": {\"skin\": 78, \"legs\": %d}, "
		% [roundi(middle.z) - 1, tall, colour, colour]
		+ "\"pose\": {\"right arm\": \"down\", \"left arm\": \"raised\", \"head\": 20}}")


## Whether a character's unjointed first submission has been sent back.
var _joints_refused: bool = false


## A figure or a creature submitted with nothing on a joint is sent back once,
## with the one entry that lays it on joints. Told of the joints in every
## reply, two of eight character sessions posed a limb (docs/BRICKBENCH.md,
## "figures on joints"): a submission that is built is a choice made, and the
## advice under it came after. Sent back, the choice is still open. Once:
## submitted again as it was, it is built. "" to go on and check it.
func _unjointed_refusal(design: Model) -> String:
	if _joints_refused or design.placements.size() < JOINTS_FROM or _posed(design):
		return ""
	var kind: String = Style.character_of(_subject_of(design))
	var call: String = _figure_call(design, kind)
	if call.is_empty():
		return ""
	_joints_refused = true
	var what: String = "figure" if kind == "figure" else "creature"
	return ("Not applied, this once: it is a %s and nothing in it is on a joint, so it " % what
		+ "would stand as a statue of stacked bricks, as every one built here was judged. "
		+ "A set builds its limbs, head and tail on joints. Lay the %s in one entry of " % what
		+ "patterns, sized and coloured to this design, and build on it:\n  %s\n" % call
		+ ("It lays feet, legs, hips, a torso, arms on ball shoulders posed by words (down, "
			+ "bent, forward, raised, out), hands, and a head turning on a "
			+ "jumper's stud, with hair; \"seated\": true sits it on a block of its own; "
			+ "\"kind\": \"head\" is a head on a neck alone. " if kind == "figure"
			else "It lays four legs, a body, the head on a ball neck (up, down, forward, left, "
			+ "right) with eyes, and the tail on a bar (raised, level, down). ")
		+ "Each part is named (\"head\", \"chest\", \"left hand\", \"tail\"): your own bricks "
		+ "attach to them, a hat {\"part\": ..., \"attach\": {\"to\": \"hair.stud[0]\"}}, or stand "
		+ "on their studs. Keep the rest of the design (a plinth, props), leave out the body "
		+ "it replaces. Submitted again with nothing on a joint, it is built as it is.")


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
	# Without its figures, as real sets are counted: their inventories
	# keep a figure's body in the figure's own (Minifig.is_body_part), so
	# a castle with a dozen guards must not read as richer for them.
	var building: Array = model.placements.filter(
		func(placement: Placement) -> bool:
			return not Minifig.is_body_part(library.parts.get(placement.part)))
	var parts: int = building.size()
	var normal: Dictionary = library.normal_for(parts)
	if normal.is_empty():
		return ""
	var lots: Dictionary = {}
	var shapes: Dictionary = {}
	var of_one: Dictionary = {}
	for placement: Placement in building:
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
	var ids := PackedStringArray()
	for placement: Placement in building:
		ids.append(placement.part)
	var coarse: Array = _coarse(ids)
	var big_high: int = int(normal.get("big_high", 0))
	if big_high > 0 and int(coarse[0]) > big_high:
		said.append("%d%% of its pieces as big as a 2 x 4 brick or bigger, "
			% int(coarse[0]) + "most of them %s %s, where a real set has "
			% [coarse[1], _part_called(str(coarse[1]))]
			+ "about %d%% and more than %d%% is coarser than all but one "
			% [int(normal.get("big", 0)), big_high] + "set in twenty. A "
			+ "real set lays a wall in 1 x 2, 1 x 3 and 1 x 4 bricks, and "
			+ "that is what lets one of them be a window, a masonry brick "
			+ "or a second grey")
	if said.is_empty():
		return ""
	# The call that does it, by name, for a building: a real set's different
	# pieces and colours are its interior, and twelve Orthancs that were told
	# so in words built solid shells. The style advice naming restyle_model
	# is what got the finishing pass used.
	var rooms: String = ""
	var about: String = "%s %s %s" % [_brief, model.name, model.description]
	if Style.group_for(about) in ["fantasy", "buildings_since_2010"] \
			and (thin_shapes > 0 and shapes.size() < thin_shapes
				or thin_lots > 0 and lots.size() < thin_lots):
		rooms = ("\nOne call for a tower, a keep or a house: add_rooms, a "
			+ "floor at each storey inside it, each a furnished room — a "
			+ "library, a forge, a dungeon — which is where a real set's "
			+ "different pieces and colours are.")
	return ("Thinner than a set of this size:\n  " + "\n  ".join(said)
		+ "\nThis is what separates a model that is built from one that is "
		+ "designed — the detail that needs a different piece. Measured "
		+ "over %d real sets of this size." % int(normal.get("sets", 0))
		+ rooms)


## Up to how many available colours are worth naming rather than counting.
const NAME_THEM := 6
## How many of one colour mistake to mention before it is repetition.
const WORTH_SAYING := 4
## How many substitute colours to name. Enough to choose from, not a
## recitation of eighty.
const ENOUGH_COLOURS := 8


## Parts specified in a colour LEGO never moulded them in.
##
## Advice, not a fault, and measured to stay one. The join behind this
## knows 6,427 of the 8,591 plain parts in the library, 700 of them with
## a list known to be short, and PartInfo.never_made_in refuses to
## answer for those. Until the colour join read LEGO's names and
## Rebrickable's ids, 49 of the 50 most used parts were short and this
## was silent for nearly every brick; now it is one. Asked of the 276
## real sets in LDraw's model repository, which contain every part they
## are drawn in, it fires on 1.3% of the part-and-colour lots it can
## judge, against 4.0% before. What is left is mostly not colour at all
## — old models drawing flat silver as 179 and trans light blue as 41,
## and mould variants (3665a) the part join cannot tell apart — but a
## real set told one lot in seventy-five does not exist is still too
## often for a fault that fails a sound design.
##
## A rubber or canvas colour is asked as the colour it is: Rebrickable
## files a black tyre under Black.
func _never_made(model: Model) -> String:
	## "part|colour" -> how many bricks say it.
	var wrong: Dictionary = {}
	for placement: Placement in model.placements:
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		if info == null \
				or not info.never_made_in(library.plain_code(placement.color)):
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


## Why no part can be this colour, or "" when one can.
func _colour_trouble(code: int) -> String:
	if library == null or library.colors.is_empty():
		return ""                   # no palette loaded, nothing to judge by
	var colour: PartLibrary.BrickColor = library.colors.get(code)
	if colour == null:
		return "%d is not an LDraw colour" % code
	if not colour.is_plastic():
		return ("%d is %s, a code LDraw uses inside part files, not a "
			% [code, colour.name] + "colour anything is moulded in")
	return ""


## What to reach for instead, out of the data: the commonest current
## colours, so the answer to a wrong number is a right one.
func _colour_advice() -> String:
	var named: PackedStringArray = PackedStringArray()
	for code: int in _current_colours(["solid"]).slice(0, 8):
		named.append("%d %s" % [code, _colour_name(code)])
	if named.is_empty():
		return "Use a colour from the list in the rules."
	return ("A colour is an LDraw number from the list in the rules — "
		+ "%s, and the rest of it." % ", ".join(named))


## Current colours, commonest first, in these finishes. Current means in
## a set of the last couple of years by Rebrickable's inventories, and
## the count of sets is what orders them. A colour in fewer than
## COMMON_COLOUR sets is a handful of special parts and is left out, so
## the list stays a palette rather than a catalogue.
const COMMON_COLOUR := 100


func _current_colours(finishes: Array) -> Array:
	var found: Array = []
	if library == null:
		return found
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		if colour.current and colour.is_plastic() \
				and colour.sets >= COMMON_COLOUR \
				and finishes.has(colour.finish):
			found.append(code)
	found.sort_custom(func(a: int, b: int) -> bool:
		var x: int = (library.colors[a] as PartLibrary.BrickColor).sets
		var y: int = (library.colors[b] as PartLibrary.BrickColor).sets
		return x > y if x != y else a < b)
	return found


## The palette the rules give, built from the data rather than written
## out: a hand-kept list named 85 as "medium lilac" correctly and was
## silent about every colour LEGO has added since it was typed.
func _palette_lines() -> String:
	var rows: Array = [
		["plain", ["solid"]],
		["see-through", ["transparent"]],
		["metallic", ["pearlescent", "metal", "chrome"]],
	]
	var lines: PackedStringArray = PackedStringArray()
	for row: Array in rows:
		var named: PackedStringArray = PackedStringArray()
		for code: int in _current_colours(row[1]):
			named.append("%d %s" % [code, _colour_name(code)])
		if not named.is_empty():
			lines.append("  %-12s %s" % [row[0], ", ".join(named)])
	if lines.is_empty():
		# A build without the Rebrickable tables knows nothing current,
		# and an empty list would read as "there are no colours".
		return ("  71 Light Bluish Grey, 72 Dark Bluish Grey, 0 Black, "
			+ "15 White, 19 Tan, 4 Red, 1 Blue, 14 Yellow, 47 Trans Clear")
	return "\n".join(lines)


## The last year either of the old greys was in a set, for the warning
## about them. Read rather than written, like the palette.
func _old_greys_until() -> String:
	var until: int = 0
	if library != null:
		for code: int in [7, 8]:
			var colour: PartLibrary.BrickColor = library.colors.get(code)
			if colour != null:
				until = maxi(until, colour.last_year)
	return "the mid 2000s" if until == 0 else str(until)


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
##
## The first is advice: real sets do stand parts on tiles and trap them
## between walls. The second is a fault, since 2026-10-10. As advice it
## was read and passed over — two round plates on the owner's tower of
## Orthanc stood a tenth of a stud off their studs with the note beside
## them — and now that a placement is named by its footprint, an offset
## between two parts that have studs is an offset between their studs.
## Over the 61 worked examples, which are real sets' own, it fired only
## on two horns, which have no stud facing up or down to be off by.
##
## Half a stud off is a third case, and the grid cannot answer it: a
## jumper's stud stands on the half-shifted grid, so a part half off its
## neighbour is right on a jumper and wrong on a plain plate, and the two
## look the same by their numbers. So the studs that reach into the part
## ([param studs], [where, way] each) are asked where they went
## ([method _underside]). On a jumper, a centre stud or something carried
## by one, each is in a socket or a tube; on plain studs half a stud off,
## they stand against its walls and tubes, and it grips nothing. Until
## 2026-10-11 every half was passed.
func _note_loose(loose: Dictionary, model: Model, index: int, under: int,
		reached: bool, issues: Dictionary = {}, studs: Array = []) -> void:
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
	#
	# And only a part that grips nothing at all: a part clutched by its own
	# studs elsewhere is held, whatever it happens to rest on. A shell laid
	# on its side is rows of tiles and slopes held on side studs, each row
	# resting on the edge of the row under it, and every one of them was
	# called "held by nothing".
	var holder: PartLibrary.PartInfo = library.parts.get(below.part)
	if holder != null and holder.stud_count == 0 \
			and SMOOTH_ON_TOP.has(holder.family_category()) and not reached:
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
	if _on_the_grid(across, 1.0) and _on_the_grid(along, 1.0):
		return
	var under_it: Array = _underside(model, index, studs)
	var reaching: PackedVector2Array = under_it[0]
	var sockets: PackedVector2Array = under_it[1]
	var half: bool = _on_the_grid(across) and _on_the_grid(along)
	if half and (not _underside_known(placement.part)
			or _none_off(reaching, sockets, under_it[2])):
		return
	# A horn on its side or a pane has no stud facing up or down, so no
	# grid of its own to be off; its corner is its cover's.
	if not _has_a_grid(placement) or not _has_a_grid(below):
		return
	# Where it grips: moved the least that puts one of the studs reaching
	# into it in one of its sockets. Snapped to the grid of the part below,
	# this said x=0.5 for a part 0.3 off a plain plate, which is half a
	# stud off it and grips no better.
	var x: float = below.x + snappedf(placement.x - below.x, STUD_GRID)
	var z: float = below.z + snappedf(placement.z - below.z, STUD_GRID)
	var move: Variant = _nearest_move(reaching, sockets)
	if move != null:
		x = snappedf(placement.x + (move as Vector2).x, 0.01)
		z = snappedf(placement.z + (move as Vector2).y, 0.01)
	if half:
		_note(issues, "off its studs",
			"brick %d (%s at %s) sits %s studs across and %s along from "
			% [index, placement.part, placement.where(),
				Placement._num(across), Placement._num(along)]
			+ "brick %d, half a stud off, and the studs under it stand " % under
			+ "against its walls and tubes, not in its sockets. Half a "
			+ "stud grips only on a stud that stands on "
			+ "the half — a jumper plate's (3794b, 15573; 87580 for a "
			+ "2 x 2) or one on a part a jumper carries. Put a jumper under "
			+ "it, or at x=%s, z=%s it sits on them."
			% [Placement._num(x), Placement._num(z)])
		return
	_note(issues, "off its studs",
		"brick %d (%s at %s) sits %s studs across and %s along from "
		% [index, placement.part, placement.where(),
			Placement._num(across), Placement._num(along)]
		+ "brick %d, so its tubes land between that part's studs. Whole "
		% under + "studs grip; so does a half, on a jumper. Nothing in "
		+ "between does: at x=%s, z=%s it sits on them."
		% [Placement._num(x), Placement._num(z)])


## What is under a part, as [studs, sockets, takes], each a list of points
## across and along in studs in the frame its placement is written in: the
## studs reaching up into it from below, its sockets, and everywhere it
## takes a stud ([method _underside_of]). [param studs] are [where, way] in
## the world, from [method _studs_reaching_in].
func _underside(model: Model, index: int, studs: Array) -> Array:
	var reaching := PackedVector2Array()
	var sockets := PackedVector2Array()
	var takes := PackedVector2Array()
	var placement: Placement = model.placements[index]
	var part: Lbm.PartMesh = library.mesh_for(placement.part)
	if part == null:
		return [reaching, sockets, takes]
	var at: Transform3D = _square_transform(placement, part)
	var section: Section = model.section_for(placement)
	var frame: Transform3D = Transform3D.IDENTITY if section == null \
		else section.placed().affine_inverse()
	var down: Vector3 = (at.basis * Vector3.DOWN).normalized()
	# Only a stud that stands where the part's underside does goes into it.
	# One standing lower touches it with its tip at most, which is a stud
	# under it and not in it (an inverted slope's, 4 LDU down, in 10197).
	var bottom: float = (at * part.bounds.position).dot(-down) \
		if absf(down.y) > 0.99 else -INF
	for stud: Array in studs:
		var way: Vector3 = (frame.basis * (stud[1] as Vector3)).normalized()
		var where: Vector3 = frame * (stud[0] as Vector3)
		if way.dot(down) < -0.99 and where.dot(-down) > bottom - 1.0:
			reaching.append(Vector2(where.x, where.z) / STUD)
	var local: Array = _underside_of(part)
	for one: Vector2 in local[0]:
		var where: Vector3 = at * Vector3(one.x, 0.0, one.y)
		sockets.append(Vector2(where.x, where.z) / STUD)
	for one: Vector2 in local[1]:
		var where: Vector3 = at * Vector3(one.x, 0.0, one.y)
		takes.append(Vector2(where.x, where.z) / STUD)
	return [reaching, sockets, sockets + takes]


## Where a part takes a stud from underneath, in its own LDU across and
## along: [sockets, everything else that takes one].
##
## The sockets are measured from the part's own edge, and an edge that is
## not on its stud grid puts them off it: 3957a's at 2, 2 rather than its
## middle, a tree's 4 LDU from where the trunk's tube says (3470), a hinge
## plate's 2 along (2430). So they are moved onto the grid its studs, or
## its tubes, stand on — the only grids a socket can be on are those, or
## those shifted half a stud, which is a jumper's. And where they leave
## gaps (4488 records two of four), the studs on top say where the rest
## are: a stud is over a socket, a jumper's over its post or its tube.
##
## Besides those, every tube, and the point between two sockets of a part
## one stud wide. A 1 x N's post fits inside a hollow stud, and a jumper's
## is hollow: 10218 sets a 1 x 2 by its post on a 2 x 2 jumper, 10276 a
## 1 x 3 by both posts on a 35480's open studs. Where it has no post a
## stud there is gripped by its walls, which is what 15573 is for. The
## catalogue cannot tell a hollow stud from a solid one (87580's is stud2
## and records no bore), so a post on a solid stud passes as well. Between
## two sockets of a 2 x N there is a tube half a stud away, and a stud
## there is against it.
static func _underside_of(part: Lbm.PartMesh) -> Array:
	var tops: Array[Vector2] = []
	var tubes: Array[Vector2] = []
	var holes: Array[Vector2] = []
	for connector: Lbm.Connector in part.connectors:
		var p := Vector2(connector.position.x, connector.position.z)
		if connector.kind == "stud" and connector.axis.y > 0.99:
			tops.append(p)
		elif connector.kind == "tube" and connector.axis.y < -0.99:
			tubes.append(p)
		elif absf(connector.axis.y) > 0.99 and (connector.kind == "pin_hole"
				or connector.kind == "axle_hole"
				or (connector.kind == "bore" and connector.radius >= 5.5)):
			holes.append(p)
	var half: float = STUD / 2.0
	var shift := Vector2.ZERO
	var grid: Array[Vector2] = tops if not tops.is_empty() else tubes
	if not grid.is_empty() and not part.sockets.is_empty():
		for axis: int in 2:
			var off: float = fposmod(part.sockets[0][axis] - grid[0][axis], half)
			shift[axis] = -off if off < half / 2.0 else half - off
	var sockets: Array[Vector2] = []
	var seen: Dictionary = {}
	for socket: Vector2 in part.sockets:
		sockets.append(socket + shift)
		seen[Vector2i((socket + shift).round())] = true
	for top: Vector2 in tops:
		if not seen.has(Vector2i(top.round())):
			sockets.append(top)
			seen[Vector2i(top.round())] = true
	var blocked: Dictionary = {}
	for tube: Vector2 in tubes:
		blocked[Vector2i(tube.round())] = true
	var takes: Array[Vector2] = tubes + holes
	# A tube grips the four studs round it, which is what a 2 x N's is for,
	# and a part whose foot is narrower than a stud sits there too: a pot
	# (98374) between four studs, six times in 75969. The foot is narrow
	# where the sockets came out off the tube's grid, or there are none.
	# Not a 1 x 1 round plate's, whose socket is its tube and which is a
	# stud across.
	var narrow: bool = part.sockets.is_empty() \
		or (grid == tubes and absf(shift.x) > 1.0 and absf(shift.y) > 1.0)
	for tube: Vector2 in tubes if narrow else []:
		var at := Vector2i(tube.round())
		var gap: int = roundi(half)
		if seen.has(at + Vector2i(gap, 0)) or seen.has(at - Vector2i(gap, 0)) \
				or seen.has(at + Vector2i(0, gap)) or seen.has(at - Vector2i(0, gap)):
			continue
		for corner: Vector2 in [Vector2(half, half), Vector2(half, -half),
				Vector2(-half, half), Vector2(-half, -half)]:
			takes.append(tube + corner)
	var step: int = roundi(STUD)
	for key: Variant in seen:
		var from: Vector2i = key
		for along: Vector2i in [Vector2i(step, 0), Vector2i(0, step)]:
			if not seen.has(from + along):
				continue
			var middle: Vector2i = from + along / 2
			var side := Vector2i(along.y, along.x) / 2
			if not blocked.has(middle + side) and not blocked.has(middle - side):
				takes.append(Vector2(middle))
	return [sockets, takes]


## How close a stud has to be to where a part takes one to be in it, and
## how far it can be and still be said to be half a stud off it, in studs.
## In: seven LDU; a train buffer beam's studs (4022c01) are six off the
## plates sets put on them. Off: half a stud is 0.5, or 0.71 half a stud
## both ways. A stud further than that from everywhere the part takes one
## is under a stretch the catalogue does not describe — a train base's
## sockets are a few of its hundreds — and is not judged.
const IN_A_SOCKET := 0.35
const HALF_OFF := 0.8


## Whether none of [param studs] stands against the part's plastic: each
## is in a socket or anywhere else it [param takes] one, or under a stretch
## nothing says of. One half a stud along from where it is taken is
## against a wall, a tube's side or a post. One half a stud both ways is
## where a 2 x N's tube is, or would be: a part that a stud grips by a
## socket is seated, and that stud is in its cavity — under the cut end
## of an angled tile (22385, five times in 10251 and 10277). Seated on
## nothing, it is a plain part half a stud both ways off plain studs, its
## edges on them.
static func _none_off(studs: PackedVector2Array, sockets: PackedVector2Array,
		takes: PackedVector2Array) -> bool:
	var seated: bool = false
	var across: bool = false
	for stud: Vector2 in studs:
		var nearest: float = INF
		for take: Vector2 in takes:
			nearest = minf(nearest, stud.distance_to(take))
		if nearest <= IN_A_SOCKET:
			for socket: Vector2 in sockets:
				seated = seated or stud.distance_to(socket) <= IN_A_SOCKET
		elif nearest < 0.6:
			return false
		elif nearest < HALF_OFF:
			across = true
	return seated or not across


## Whether the half-stud rule can judge a part: one whose underside is the
## grid of sockets, tubes and posts the catalogue describes. Plates,
## bricks, tiles, slopes and their like are; an animal, a windscreen, a
## train base or a plant is hollow underneath in ways it does not record,
## and over the fetched real sets those were the parts it refused that
## stood on nothing but air (a pig in 75980, a roll cage in 10197, a 6 x 28
## base in 10233, flower stems between four studs in 2150, 4554, 6597).
func _underside_known(part_id: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(part_id))
	return info != null and PLAIN_UNDERSIDES.has(info.family_category())


const PLAIN_UNDERSIDES: Dictionary = {
	"Brick": true, "Plate": true, "Tile": true, "Slope": true, "Wedge": true,
	"Bracket": true, "Hinge": true, "Arch": true, "Cone": true, "Cylinder": true,
	"Dish": true, "Panel": true, "Window": true, "Door": true, "Fence": true,
	"Container": true, "Bar": true, "Support": true, "Turntable": true,
	"Staircase": true, "Baseplate": true,
}


## The least move, across and along in studs, that puts one of
## [param studs] in one of [param sockets]; null if either is empty.
static func _nearest_move(studs: PackedVector2Array,
		sockets: PackedVector2Array) -> Variant:
	var best: Variant = null
	for stud: Vector2 in studs:
		for socket: Vector2 in sockets:
			var move: Vector2 = stud - socket
			if best == null or move.length() < (best as Vector2).length() - 0.001:
				best = move
	return best


## Whether a placement has a stud or a tube facing up or down, which is
## what puts it on a stud grid of its own — and is not a minifigure's.
func _has_a_grid(placement: Placement) -> bool:
	var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
	if mesh == null or _figure_part(placement.part):
		return false
	var basis: Basis = BrickLattice.basis_for(placement.face, placement.rot)
	for connector: Lbm.Connector in mesh.connectors:
		if (connector.kind == "stud" or connector.kind == "tube") \
				and absf((basis * connector.axis).normalized().y) > 0.99:
			return true
	return false


static func _on_the_grid(offset: float, per: float = STUD_GRID) -> bool:
	var over: float = fposmod(offset, per)
	return over <= GRID_SLACK or over >= per - GRID_SLACK


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


## What submit_design said the model stands on, read at the edge: a kind
## ModelFloor has, and for a baseplate its colour by name and that it goes
## in the box. {} for nothing said or nothing sensible.
func _floor_of(args: Dictionary) -> Dictionary:
	var said: String = str(args.get("floor", "")).strip_edges().to_lower()
	if not said in ModelFloor.KINDS:
		return {}
	var colour: int = -1
	var named: String = str(args.get("floor_colour", "")).strip_edges().to_lower()
	for pair: Array in ModelFloor.COLOURS:
		if str(pair[1]).to_lower() == named or str(pair[1]).to_lower().replace("grey", "gray") == named:
			colour = int(pair[0])
	return {"kind": said, "colour": colour, "part": said == ModelFloor.BASEPLATE}


func _read_model(args: Dictionary) -> Model:
	var shell_trouble: Array = []
	var shell_said: Array = []
	args = _with_shells(args, shell_trouble, shell_said)
	args = _with_figures(args, shell_trouble, shell_said)
	var model := Model.new()
	model.name = str(args.get("name", "Model"))
	model.description = str(args.get("description", ""))
	model.stands_on = _floor_of(args)
	_read_sections(model, args)
	for section: Section in model.sections.values().duplicate():
		if section.hinge:
			_lay_hinge(model, section)
	var written: Array = args.get("bricks", [])
	for raw: Variant in written:
		model.placements.append(_said_placement(raw))
	_attach_parts(model)
	_turned_parts(model)

	# And the shapes it described rather than counted out. Patterns are
	# expanded after the bricks because mirror reflects what is there.
	var patterns: Array = args.get("patterns", [])
	_pattern_advice = []
	_shaped_body = false
	for raw: Variant in patterns:
		_shaped_body = _shaped_body or (raw is Dictionary
			and str((raw as Dictionary).get("pattern", "")).to_lower() == "shape")
	if not patterns.is_empty():
		var trouble: Array = []
		# A face of studs turned out needs the parts' own geometry to know
		# where a side stud is, which only this side has.
		var plain: Array = []
		var sideways: Array = []
		var prisms: Array = []
		for raw: Variant in patterns:
			var kind: String = str((raw as Dictionary).get("pattern", "")).to_lower() \
				if raw is Dictionary else ""
			if kind == "studs_out":
				sideways.append(raw)
			elif kind == "prism":
				prisms.append(raw)
			else:
				plain.append(raw)
		for raw: Variant in Patterns.expand(plain, written, trouble,
				library):
			var one: Dictionary = raw
			if one.has("dress"):
				# A fill's 1x1 with a side stud, marked with the way out:
				# turned so the stud faces it, and dressed.
				# On a dark wall the same part all the way up its column.
				var dressing: Dictionary = _dress(one, str(one["dress"]), -1,
					[RIB_PART] if _is_dark(int(one.get("color", DEFAULT_COLOUR))) else [])
				one.erase("dress")
				if not dressing.is_empty():
					model.placements.append(Placement.from_dict(dressing))
			if one.has("panel"):
				# A shape's brick with studs on its side: turned so they face
				# out, and a tile laid on them flat against the side.
				var tile: Dictionary = _panel(one, str(one["panel"]))
				one.erase("panel")
				if not tile.is_empty():
					model.placements.append(Placement.from_dict(tile))
			model.placements.append(Placement.from_dict(one))
		for raw: Variant in sideways:
			for brick: Dictionary in _studs_out(raw, trouble):
				model.placements.append(Placement.from_dict(brick))
		for n: int in prisms.size():
			var laid: Array = _prism(prisms[n], model, n, trouble)
			_smooth_under_turned(laid, model)
			for brick: Dictionary in laid:
				model.placements.append(Placement.from_dict(brick))
		_pattern_trouble = trouble
		_pattern_advice.append_array(_round_by_panels(plain))
		# What a shape could not join, or that one stands on nothing, with the fix.
		_pattern_advice.append_array(Shapes.said)
	else:
		_pattern_trouble = []
	_pattern_trouble.append_array(shell_trouble)
	_pattern_advice.append_array(shell_said)

	_repeat_trouble = []
	_expand_repeats(model, args, _repeat_trouble)
	_onto_lines(model)
	model.assemblies = _read_assemblies(args)
	model.features = _read_features(args)
	model.feature_spots = FeaturePass.read_spots(args)
	return model


## A finishing pass over what stands: the plain one-wide bricks with an open
## long face, and the outer rows of two-wide ones, laid again in place. Returns
## {} when nothing qualifies, {"summary"} alone when it was asked for something
## it has not got, or {"edit": edit_model's input, "summary": what it will do}.
##
## The designs built here write their walls brick by brick and then edit
## them; the sixth Orthanc was 978 plain 1x2 bricks and nothing on its side,
## though every check said real fantasy sets are a fifth sideways and a pattern
## for it was there to be used. What it does reliably is edit what stands, so
## this is an edit, worked out from what is actually open to the air.
##
## Each wall — one face's outer row, in its section's frame or the main body's
## — is laid again as one structure in its own colour ([constant
## DRESS_STYLES]), never a part at a time: a dark one in panels unless told,
## since a dark face with nothing on it reads as a hole and one sprinkled with
## dressing as speckle. Run 4 of the Orthanc, on the landing page, was 58%
## plain black after this pass had turned out only the bricks that started on
## a column, each carrying its own tile: broken columns, which are regrouped
## now. A light wall told no style keeps the old scatter: a
## [code]sideways[/code] share turned out and dressed, a [code]masonry[/code]
## share as masonry. A [code]face_color[/code] is the second tone: on every
## fifth rib, on bands, or through a fifth of the scatter. The sixteenth
## Orthanc asked for dark grey on its black faces and all 149 round tiles came
## out grey, which read as polka dots.
func _restyle(args: Dictionary) -> Dictionary:
	if world == null or builder == null or builder.lattice == null:
		return {}
	var where: Dictionary = args.get("where", {}) if args.get("where") is Dictionary else {}
	# "turned_out": false (the surface pass, on a building) lays masonry
	# only: no stud turned out and dressed, and a dark wall scattered like a
	# light one, not panelled between ribs of studs. The judge called the
	# edges round shop's turned-out studs "odd studs" "in clumps".
	var turned_out: bool = bool(args.get("turned_out", true))
	var sideways: float = clampf(float(args.get("sideways", 0.15)), 0.0, 0.5) \
		if turned_out else 0.0
	var masonry: float = clampf(float(args.get("masonry", 0.25)), 0.0, 1.0)
	var face_colour: int = int(args.get("face_color", args.get("face_colour", -1)))
	var style: String = str(args.get("style", "")).to_lower()
	if not style.is_empty() and not DRESS_STYLES.has(style):
		return {"summary": "No style called %s: %s." % [style,
			", ".join(PackedStringArray(DRESS_STYLES.keys()))]}
	var texture: String = str(args.get("texture", "")).to_lower()
	if not texture.is_empty() and not DRESS_TEXTURES.has(texture):
		return {"summary": "No texture called %s: %s." % [texture,
			", ".join(PackedStringArray(DRESS_TEXTURES.keys()))]}
	var middle := Vector3.ZERO
	var standing: Array[BrickWorld.Brick] = _bricks_inside({})
	for brick: BrickWorld.Brick in standing:
		middle += brick.transform.origin
	if not standing.is_empty():
		middle /= float(standing.size())
	var model: Model = _model_from_world()
	# Every brick with an open face, by the wall it is in.
	var walls: Dictionary = {}
	for placement: Placement in model.placements:
		var long: int = int(Patterns.ONE_WIDE.get(placement.part, TWO_WIDE.get(placement.part, 0)))
		if long == 0 or placement.face != "up":
			continue
		# A window is not a wall to finish.
		var tint: PartLibrary.BrickColor = library.color(placement.color)
		if tint != null and tint.is_transparent():
			continue
		# A brick in a section is in the section's own square coordinates,
		# so it is restyled in them and carried with it: the faces of a prism
		# or a cluster, which are most of a tower built with one. The
		# fifteenth Orthanc asked for this pass over its shaft and was told
		# "Restyled 4 bricks"; every face of it was in a section. Only
		# sections turned about y, whose up is still up.
		var frame := Transform3D.IDENTITY
		if not placement.section.is_empty():
			var section: Section = model.section_for(placement)
			if section == null or not section.upright():
				continue
			frame = section.placed()
		var seen: Vector3 = frame * Vector3(placement.x * STUD, placement.y * PLATE,
			placement.z * STUD)
		if not _inside(Vector3(seen.x / STUD, seen.y / PLATE, seen.z / STUD), where):
			continue
		var along_x: bool = placement.rot % 2 == 0
		if not TWO_WIDE.has(placement.part):
			var facing: String = _open_side(placement, long, along_x, middle, frame)
			if not facing.is_empty():
				_wall_of(walls, facing, frame, {"placement": placement, "outer": placement,
					"inner": {}, "long": long, "seen": seen})
			continue
		# A two-wide brick with a long face open is laid again as two rows:
		# the inner one plain, the outer one finished as a one-wide brick
		# would be; with both open, a wall standing on its own, each row is
		# its own face's. A two-thick prism face is a course of them every
		# other course, and a solid fill's rim is nothing else; restyling
		# one-wide bricks only, the fifteenth Orthanc's shaft and plinth
		# stayed 64% plain with the pass reaching every section.
		var rows: Array = []
		for half: int in 2:
			var row := {"part": ONE_WIDE_OF[long], "color": placement.color,
				"x": placement.x + (0 if along_x else half), "y": placement.y,
				"z": placement.z + (half if along_x else 0), "rot": placement.rot}
			if not placement.section.is_empty():
				row["section"] = placement.section
			var facing: String = _open_side(Placement.from_dict(row), long, along_x, middle,
				frame)
			rows.append([row, facing])
		var open: Array = rows.filter(func(one: Array) -> bool: return not str(one[1]).is_empty())
		if open.is_empty():
			continue
		var made: Array = []
		for one: Array in open:
			var other: Dictionary = rows[1 - rows.find(one)][0]
			made.append(_wall_of(walls, one[1], frame, {"placement": placement,
				"outer": Placement.from_dict(one[0]), "long": long, "seen": seen,
				"inner": other if open.size() == 1 else {}}))
		if made.size() == 2:
			(made[0] as Dictionary)["pair"] = made[1]
			(made[1] as Dictionary)["pair"] = made[0]
	# The bricks with a stud on the side a wall has already, each with what is
	# on its stud: kept where they stand in ribs, regrouped where they do not.
	var facing_of: Dictionary = {}
	for facing: String in ["+x", "-x", "+z", "-z"]:
		var side: Array = _side_stud(facing)
		if not side.is_empty():
			facing_of[int(side[0])] = facing
	var on_studs: Dictionary = {}    ## section|face -> [dressing placements]
	for placement: Placement in model.placements:
		if placement.face != "up" and (placement.dressing or placement.part in SPECKS):
			var key: String = "%s|%s" % [placement.section, placement.face]
			if not on_studs.has(key):
				on_studs[key] = []
			(on_studs[key] as Array).append(placement)
	for placement: Placement in model.placements:
		if placement.part != "87087" or placement.face != "up" \
				or not facing_of.has(placement.rot):
			continue
		var facing: String = facing_of[placement.rot]
		var along_x: bool = facing in ["+z", "-z"]
		var key: String = "%s|%s|%s" % [placement.section, facing,
			snappedf((placement.z if along_x else placement.x)
				+ (0.2 if facing.begins_with("-") else 0.0), 0.5)]
		if not walls.has(key):
			# A row that is all side studs and texture already, nothing plain
			# left in it: its studs are a wall to regroup all the same. The
			# run 4 Orthanc had rows like that the old pass had turned out.
			var frame := Transform3D.IDENTITY
			if not placement.section.is_empty():
				var section: Section = model.section_for(placement)
				if section == null or not section.upright():
					continue
				frame = section.placed()
			var seen: Vector3 = frame * Vector3(placement.x * STUD, placement.y * PLATE,
				placement.z * STUD)
			if not _inside(Vector3(seen.x / STUD, seen.y / PLATE, seen.z / STUD), where):
				continue
			walls[key] = {"section": placement.section, "facing": facing, "along_x": along_x,
				"depth": (placement.z if along_x else placement.x)
					+ (0.2 if facing.begins_with("-") else 0.0),
				"frame": frame, "bricks": [], "studs": [], "colours": {placement.color: 1}}
		var along: float = placement.x if along_x else placement.z
		var depth: float = placement.z if along_x else placement.x
		# Its stud stands a fifth of a stud out of its row.
		if facing.begins_with("-"):
			depth += 0.2
		var carried: Array = []
		for on: Placement in on_studs.get("%s|%s" % [placement.section, facing], []):
			var on_along: float = on.x if along_x else on.z
			var on_depth: float = on.z if along_x else on.x
			if absf(on_along - along) < 0.5 and absf(on.y - placement.y - 1.0) < 1.6 \
					and absf(on_depth - depth) < 1.5:
				carried.append(on.id)
		(walls[key]["studs"] as Array).append({"placement": placement, "carried": carried})
	var out := {"removed": {}, "added": [], "said": {}, "styled": {}, "accents": {}}
	var affected: Array = []
	for key: String in walls:
		var wall: Dictionary = walls[key]
		var colours: Dictionary = wall["colours"]
		var colour: int = -1
		for code: int in colours:
			if colour < 0 or int(colours[code]) > int(colours[colour]):
				colour = code
		wall["colour"] = colour
		var chosen: String = style
		if chosen.is_empty() and _is_dark(colour) and turned_out:
			chosen = "panels"
		if chosen.is_empty():
			for one: Dictionary in wall["bricks"]:
				_scatter_one(one, wall, sideways, masonry, face_colour, out)
			continue
		if _dress_wall(wall, chosen, texture, face_colour, out, affected):
			out["styled"][chosen] = int(out["styled"].get(chosen, 0)) + 1
	# The rest of each brick taken out: its inner row, or the other face's
	# row when only one of them was laid again.
	for one: Dictionary in affected:
		if not (one["inner"] as Dictionary).is_empty():
			(out["added"] as Array).append(one["inner"])
		if one.has("pair") and not bool((one["pair"] as Dictionary).get("affected", false)):
			var other: Placement = (one["pair"] as Dictionary)["outer"]
			(out["added"] as Array).append({"part": other.part, "color": other.color,
				"x": other.x, "y": other.y, "z": other.z, "rot": other.rot,
				"section": other.section})
	var removed: Dictionary = out["removed"]
	if removed.is_empty():
		return {}
	var parts := PackedStringArray()
	for what: String in out["said"]:
		parts.append("%d %s" % [int(out["said"][what]), what])
	var how := PackedStringArray()
	for chosen: String in out["styled"]:
		var many: int = int(out["styled"][chosen])
		how.append("%d wall%s in %s" % [many, "" if many == 1 else "s", chosen])
	return {"edit": {"remove": removed.keys(), "add": out["added"]},
		"summary": "Restyled %d brick%s%s: %s." % [removed.size(),
			"" if removed.size() == 1 else "s",
			"" if how.is_empty() else " (" + ", ".join(how) + ")", ", ".join(parts)]}


## Put a brick with an open face into the wall it is part of, keyed by its
## section, the way it looks and its depth; returns the brick's entry.
static func _wall_of(walls: Dictionary, facing: String, frame: Transform3D,
		one: Dictionary) -> Dictionary:
	var outer: Placement = one["outer"]
	var along_x: bool = outer.rot % 2 == 0
	var depth: float = outer.z if along_x else outer.x
	var key: String = "%s|%s|%s" % [outer.section, facing, snappedf(depth, 0.5)]
	if not walls.has(key):
		walls[key] = {"section": outer.section, "facing": facing, "along_x": along_x,
			"depth": depth, "frame": frame, "bricks": [], "studs": [], "colours": {}}
	var wall: Dictionary = walls[key]
	one["at"] = outer.x if along_x else outer.z
	(wall["bricks"] as Array).append(one)
	var colours: Dictionary = wall["colours"]
	colours[outer.color] = int(colours.get(outer.color, 0)) + int(one["long"])
	return one


## How a wall is dressed as one structure: ribs (a column of round plates on
## bricks with a stud on the side, up the wall every RIB_EVERY studs from its
## middle, or where its ribs are already), bands (a course of texture every
## BAND_STEP courses, in the second tone if one is given), panels (texture over
## the wall between its ribs, framed by a plain stud at each end and a plain
## course against each ledge and string course — 10237's black faces are
## panels of grille between ribs), grid (ribs and bands) and courses (a course
## of round bricks every RECESS_EVERY, a shadow line).
const DRESS_STYLES: Dictionary = {
	"ribs": "a column of round plates up each face every few studs",
	"bands": "a course of texture every few courses, in the second tone if given",
	"panels": "texture between the ribs, framed by a plain stud at each end and "
		+ "a plain course against each ledge",
	"grid": "ribs and bands",
	"courses": "a course of round bricks every few courses, a recessed line",
}
## What a run of texture is laid in, two studs and one: grille (10237 breaks
## its black with 86 of 2877, and with 63 headlight bricks, 4070), masonry,
## logs (planking, a round brick for a single stud), round bricks (a fluted
## panel) or headlight bricks.
const DRESS_TEXTURES: Dictionary = {
	"grille": ["2877", "4070"],
	"masonry": ["98283", "4070"],
	"log": ["30136", "3062b"],
	"round": ["", "3062b"],
	"headlight": ["", "4070"],
}
## Which way each texture part's face looks at rot 0, in this app's axes.
## Masonry and grille face LDraw's -Z, which is +Z here; a headlight brick's
## opening LDraw's +Z.
const TEXTURE_FACES: Dictionary = {"2877": "+z", "98283": "+z", "15533": "+z",
	"4070": "-z", "3062b": "+z", "30136": "+z"}
const BAND_STEP := 4
const RECESS_EVERY := 4
## A column of side studs that holds this share of its wall's courses is a
## rib already, and is kept; less, and it is regrouped.
const RIB_KEEP := 0.5
## How wide a wall is before its panels stand a plain stud in from each end.
const PANEL_MARGIN_FROM := 8.0
## A dark wall's dressing told how, wherever a check or an edit sends it.
const DRESS_HOW := ("Lay them as one structure, never part by part: restyle_model "
	+ "with \"style\": \"ribs\" (a column of round plates up each face), \"bands\" "
	+ "(a course of grille round it, in the second tone if given), \"panels\" "
	+ "(grille between the ribs, framed plain), \"grid\" (ribs and bands) or "
	+ "\"courses\" (round bricks, a recessed line), over the box it is for "
	+ "(where); on a dark wall it lays panels unasked.")


## One wall laid again in [param style]: each brick a stud of it touches is
## taken out and laid as plain pieces, texture, ribs or round bricks, stud by
## stud as the style says; runs of texture are laid across the joints they
## came from, a course at a time, each the same. A side stud already there that is
## not in a rib is regrouped the same way, with what it carried. A brick is
## split only where every stud of it is held from above or below, as the
## scatter splits one. Returns whether anything changed; what was taken out
## goes on [param affected].
func _dress_wall(wall: Dictionary, style: String, texture: String, face_colour: int,
		out: Dictionary, affected: Array) -> bool:
	var colour: int = wall["colour"]
	var bricks: Array = wall["bricks"]
	var studs: Array = wall["studs"]
	var along_x: bool = wall["along_x"]
	var facing: String = wall["facing"]
	var frame: Transform3D = wall["frame"]
	var section: String = wall["section"]
	var low: float = INF
	var high: float = -INF
	var bottom: float = INF
	for one: Dictionary in bricks:
		low = minf(low, float(one["at"]))
		high = maxf(high, float(one["at"]) + int(one["long"]))
		bottom = minf(bottom, (one["outer"] as Placement).y)
	for one: Dictionary in studs:
		var placement: Placement = one["placement"]
		var at: float = placement.x if along_x else placement.z
		low = minf(low, at)
		high = maxf(high, at + 1.0)
		bottom = minf(bottom, placement.y)
	if high - low < 3.0 and studs.is_empty():
		return false
	# Its courses from the lowest: those in another colour (its ledges), and
	# those of two-wide bricks, which tie a face two studs thick to its back
	# row. A rib of bricks with a stud on the side cuts the face's outer row
	# into strips, and panels split its two-wide bricks in two; held to the
	# back by nothing, a strip is a piece of its own, and the first wall laid
	# in panels came apart in thirteen. So a rib stands only in the courses of
	# one-wide bricks, and one course of two-wide bricks next to each ledge —
	# or with no ledges, every fourth such course, and the first and last —
	# stays whole: a plain course across the wall that every strip hangs from.
	var bands: Dictionary = {}
	var courses: Dictionary = {}
	var ties: Dictionary = {}
	var top: int = 0
	for one: Dictionary in bricks:
		var placement: Placement = one["outer"]
		var course: int = roundi((placement.y - bottom) / 3.0)
		top = maxi(top, course)
		courses[course] = true
		if placement.color != colour:
			bands[course] = true
		if TWO_WIDE.has((one["placement"] as Placement).part):
			ties[course] = true
	for one: Dictionary in studs:
		var course: int = roundi(((one["placement"] as Placement).y - bottom) / 3.0)
		top = maxi(top, course)
		courses[course] = true
	var frames: Dictionary = {0: true, top: true}
	if bands.is_empty():
		var tied: Array = ties.keys()
		tied.sort()
		for n: int in tied.size():
			if n % 4 == 2:
				frames[tied[n]] = true
	else:
		for band: int in bands:
			for next: int in [band - 1, band + 1]:
				if ties.has(next):
					frames[next] = true
	# Its ribs: the columns of side studs it has that stand in half its
	# courses of one-wide bricks or more, or every RIB_EVERY from its middle.
	var one_wide: int = 0
	for course: int in courses:
		if not ties.has(course):
			one_wide += 1
	var held: Dictionary = {}    ## column -> {course: true}
	for one: Dictionary in studs:
		var placement: Placement = one["placement"]
		var at: float = snappedf(placement.x if along_x else placement.z, 0.5)
		if not held.has(at):
			held[at] = {}
		(held[at] as Dictionary)[roundi((placement.y - bottom) / 3.0)] = true
	var ribs: Dictionary = {}
	for at: float in held:
		if (held[at] as Dictionary).size() >= RIB_KEEP * maxi(1, one_wide):
			ribs[at] = true
	if ribs.is_empty() and style in ["ribs", "panels", "grid"] and high - low >= 5.0:
		# Moved off the middle a stud or two where that puts each rib inside
		# the two-wide bricks of every course it skips: a rib on their joint
		# cut the wall through from top to bottom, and the first wall laid in
		# ribs came apart in four.
		var spans: Dictionary = {}    ## course -> [Vector2(from, to)] of its two-wide bricks
		for one: Dictionary in bricks:
			if TWO_WIDE.has((one["placement"] as Placement).part):
				var course: int = roundi(((one["outer"] as Placement).y - bottom) / 3.0)
				if not spans.has(course):
					spans[course] = []
				(spans[course] as Array).append(Vector2(float(one["at"]),
					float(one["at"]) + int(one["long"])))
		var best: Dictionary = {}
		var fewest: int = 1 << 30
		for shift: int in [0, 1, -1, 2, -2]:
			var at: float = low + floorf((high - low) / 2.0) + shift
			while at - RIB_EVERY >= low + 1.0:
				at -= RIB_EVERY
			var trial: Dictionary = {}
			var cut: int = 0
			while at <= high - 2.0:
				trial[snappedf(at, 0.5)] = true
				for course: int in spans:
					# Some two-wide brick of this course runs on past the rib
					# on both sides.
					var crossed: bool = false
					for span: Vector2 in spans[course]:
						if span.x < at - 0.05 and span.y > at + 1.05:
							crossed = true
							break
					if not crossed:
						cut += 1
				at += RIB_EVERY
			if cut < fewest and not trial.is_empty():
				fewest = cut
				best = trial
		ribs = best
	# A wide wall's panels stand a plain stud in from each end; a narrow
	# face's corners frame it already.
	var margin: float = 1.0 if high - low >= PANEL_MARGIN_FROM else 0.0
	var role_of := func(at: float, course: int, two: bool) -> String:
		var on_rib: bool = ribs.has(snappedf(at, 0.5)) and not two
		match style:
			"ribs":
				return "rib" if on_rib else ""
			"panels":
				if frames.has(course) or bands.has(course):
					return ""
				if on_rib:
					return "rib"
				if at >= low + margin and at < high - margin:
					return "texture"
			"bands":
				return "band" if posmod(course, BAND_STEP) == BAND_STEP - 1 else ""
			"grid":
				if on_rib:
					return "rib"
				if posmod(course, BAND_STEP) == BAND_STEP - 1:
					return "band"
			"courses":
				return "round" if posmod(course, RECESS_EVERY) == RECESS_EVERY / 2 else ""
		return ""
	# What each stud of each brick becomes: "" (left plain), "texture",
	# "band", "rib" or "round". A brick to be split must have every stud held.
	var roles: Array = []
	for one: Dictionary in bricks:
		var outer: Placement = one["outer"]
		var course: int = roundi((outer.y - bottom) / 3.0)
		var two: bool = TWO_WIDE.has((one["placement"] as Placement).part)
		var row := PackedStringArray()
		for step: int in int(one["long"]):
			row.append(role_of.call(float(one["at"]) + step, course, two)
				if outer.color == colour else "")
		if not Array(row).all(func(role: String) -> bool: return role.is_empty()) \
				and not _each_stud_held(outer, int(one["long"]), along_x, frame):
			row = PackedStringArray()
			row.resize(int(one["long"]))
		roles.append(row)
	var removed: Dictionary = out["removed"]
	var added: Array = out["added"]
	var said: Dictionary = out["said"]
	var accents: Dictionary = out["accents"]
	var by_course: Dictionary = {}    ## course -> [[at, role, colour, y]]
	var changed: bool = false
	var pieces := func(role: String, at: float, run: int, tint: int, y: float,
			course: int, from: String) -> void:
		match role:
			"":
				added.append(_dress_piece(ONE_WIDE_OF[run], tint, at, y, wall, from))
				said["plain"] = int(said.get("plain", 0)) + 1
			"rib":
				for k: int in run:
					var stud: Dictionary = _dress_piece("87087", tint, at + k, y, wall, "")
					stud["rot"] = 0
					var key: String = "%s|%s|%s" % [section, facing, at + k]
					if not accents.has(key):
						accents[key] = accents.size()
					var tone: int = face_colour if face_colour >= 0 and posmod(
						int(accents[key]), roundi(1.0 / FACE_ACCENT)) == 0 else tint
					var plate: Dictionary = _dress(stud, facing, tone, [RIB_PART])
					added.append(stud)
					if not plate.is_empty():
						if not section.is_empty():
							plate["section"] = section
						added.append(plate)
					said["rib studs"] = int(said.get("rib studs", 0)) + 1
			"round":
				for k: int in run:
					added.append(_dress_piece("3062b", tint, at + k, y, wall, "-"))
				said["round bricks"] = int(said.get("round bricks", 0)) + run
			_:
				if not by_course.has(course):
					by_course[course] = []
				for k: int in run:
					(by_course[course] as Array).append([at + k, role, tint, y])
	for n: int in bricks.size():
		var row: PackedStringArray = roles[n]
		if Array(row).all(func(role: String) -> bool: return role.is_empty()):
			continue
		changed = true
		var one: Dictionary = bricks[n]
		var placement: Placement = one["placement"]
		var outer: Placement = one["outer"]
		if not removed.has(placement.id):
			removed[placement.id] = true
		one["affected"] = true
		affected.append(one)
		var course: int = roundi((outer.y - bottom) / 3.0)
		var step: int = 0
		while step < row.size():
			var run: int = 1
			while step + run < row.size() and row[step + run] == row[step]:
				run += 1
			pieces.call(row[step], float(one["at"]) + step, run, outer.color, outer.y, course,
				str(outer.rot))
			step += run
	# Side studs out of a rib, and what they carry, regrouped into the wall.
	for one: Dictionary in studs:
		var placement: Placement = one["placement"]
		var at: float = placement.x if along_x else placement.z
		if ribs.has(snappedf(at, 0.5)) or placement.color != colour:
			continue
		changed = true
		removed[placement.id] = true
		for id: int in one["carried"]:
			removed[id] = true
		var course: int = roundi((placement.y - bottom) / 3.0)
		var role: String = role_of.call(at, course, false)
		pieces.call("" if role == "rib" else role, at, 1, placement.color, placement.y,
			course, "0")
		said["side studs regrouped"] = int(said.get("side studs regrouped", 0)) + 1
	var parts: Array = DRESS_TEXTURES.get(texture if not texture.is_empty() else "grille")
	for course: int in by_course:
		var row: Array = by_course[course]
		row.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var n: int = 0
		while n < row.size():
			var run: int = 1
			while n + run < row.size() \
					and absf(float(row[n + run][0]) - float(row[n][0]) - run) < 0.05 \
					and row[n + run][1] == row[n][1] and row[n + run][2] == row[n][2]:
				run += 1
			var first: Array = row[n]
			var role: String = first[1]
			var tone: int = face_colour if role == "band" and face_colour >= 0 else int(first[2])
			var pair: String = str(parts[0])
			var single: String = str(parts[1])
			var at: float = float(first[0])
			var left: int = run
			# Pairs from the left and a single at the right end, the same
			# every course: a panel of vertical stripes. Bonded, the single
			# moved from end to end course by course, and the grille, which
			# catches the light where black does not, zigzagged up the face.
			# The panel hangs from the whole courses that frame it.
			while left > 0:
				var two: bool = left >= 2 and not pair.is_empty()
				added.append(_dress_piece(pair if two else single, tone, at, float(first[3]),
					wall, "-"))
				at += 2.0 if two else 1.0
				left -= 2 if two else 1
			var what: String = "studs of %s %s" % [texture if not texture.is_empty() else "grille",
				"in bands" if role == "band" else "in panels"]
			said[what] = int(said.get(what, 0)) + run
			n += run
	return changed


## One piece of a wall laid again: [param part] [param at] studs along it, in
## its row and at height [param y]. [param turn] is the turn as a number, or
## "-" to turn a texture part's face out of the wall.
func _dress_piece(part: String, colour: int, at: float, y: float, wall: Dictionary,
		turn: String) -> Dictionary:
	var along_x: bool = wall["along_x"]
	var rot: int = int(turn) if turn.is_valid_int() else (0 if along_x else 1)
	if turn == "-":
		var order: Array = ["+z", "+x", "-z", "-x"]
		rot = posmod(order.find(str(wall["facing"]))
			- order.find(str(TEXTURE_FACES.get(part, "+z"))), 4)
	var depth: float = wall["depth"]
	var one := {"part": part, "color": colour, "x": at if along_x else depth, "y": y,
		"z": depth if along_x else at, "rot": rot}
	if not str(wall["section"]).is_empty():
		one["section"] = wall["section"]
	return one


## The old pass, for a light wall told no style: a share turned out and
## dressed, a share as masonry, chosen by where each brick is.
func _scatter_one(one: Dictionary, wall: Dictionary, sideways: float, masonry: float,
		face_colour: int, out: Dictionary) -> void:
	var placement: Placement = one["placement"]
	var outer: Placement = one["outer"]
	var inner: Dictionary = one["inner"]
	var long: int = one["long"]
	var seen: Vector3 = one["seen"]
	var along_x: bool = wall["along_x"]
	var facing: String = wall["facing"]
	var frame: Transform3D = wall["frame"]
	var removed: Dictionary = out["removed"]
	var added: Array = out["added"]
	var said: Dictionary = out["said"]
	if removed.has(placement.id):
		return
	if one.has("pair"):
		# Both faces open: this one finished, the other row laid plain.
		var other: Placement = (one["pair"] as Dictionary)["outer"]
		inner = {"part": other.part, "color": other.color, "x": other.x, "y": other.y,
			"z": other.z, "rot": other.rot, "section": other.section}
	var pick: float = Patterns._scatter(seen.x / STUD, seen.y / PLATE, seen.z / STUD, 41)
	if pick < sideways and _each_stud_held(outer, long, along_x, frame):
		removed[placement.id] = true
		if not inner.is_empty():
			added.append(inner)
		for step: int in long:
			var stud := {"part": "87087", "color": placement.color,
				"x": outer.x + (step if along_x else 0), "y": outer.y,
				"z": outer.z + (0 if along_x else step), "rot": 0}
			var tone: int = -1
			if face_colour >= 0 and Patterns._scatter(seen.x / STUD + step,
					seen.y / PLATE, seen.z / STUD, 31) < FACE_ACCENT:
				tone = face_colour
			var dressing: Dictionary = _dress(stud, facing, tone)
			if not placement.section.is_empty():
				stud["section"] = placement.section
				if not dressing.is_empty():
					dressing["section"] = placement.section
			added.append(stud)
			if not dressing.is_empty():
				added.append(dressing)
		said["turned out and dressed"] = int(said.get("turned out and dressed", 0)) + 1
	elif pick < sideways + masonry and Patterns.MASONRY.has(outer.part):
		removed[placement.id] = true
		if not inner.is_empty():
			added.append(inner)
		var stone := {"part": Patterns.MASONRY[outer.part],
			"color": placement.color, "x": outer.x, "y": outer.y, "z": outer.z,
			"rot": ["+z", "+x", "-z", "-x"].find(facing)}
		if not placement.section.is_empty():
			stone["section"] = placement.section
		added.append(stone)
		said["laid as masonry"] = int(said.get("laid as masonry", 0)) + 1


## The share of a finishing pass's dressing in the colour asked for; the
## rest is the wall's own.
const FACE_ACCENT := 0.2


## How the picture after an edit is taken when the edit was not the
## design's own bricks: {"from", "only", "ask"}, or {} for the usual corner
## with what changed in magenta. Set by add_rooms around its edit.
var _look_after_edit: Dictionary = {}
## What the last add_rooms came to (Rooms.answer, and "dropped": how many
## items the check took back out), for rooms_probe to hold it to.
var _last_rooms: Dictionary = {}


## Floors and furnished rooms in what stands (see [Rooms]), checked the way
## the edit that lays them will be. What the check finds floating is taken
## back out, a piece of furniture or a floor at a time, and the rest checked
## again: a room short of a chest is still a room, and an edit refused whole
## for one is no rooms at all. Returns Rooms.plan's answer.
func _rooms(args: Dictionary) -> Dictionary:
	if world == null or builder == null or builder.lattice == null:
		return {"trouble": "There is no model standing to put rooms in."}
	var wanted := Model.new()
	for part: String in Rooms.parts_wanted():
		wanted.placements.append(Placement.from_dict({"part": part}))
	await _ensure_parts(wanted)
	var rooms := Rooms.new(self)
	var plan: Dictionary = rooms.plan(args)
	if plan.has("trouble"):
		return plan
	var dropped: int = 0
	for _try: int in 3:
		var trial: Model = _model_from_world()
		var standing: int = trial.placements.size()
		for brick: Dictionary in rooms.bricks():
			trial.placements.append(Placement.from_dict(brick))
		_pattern_trouble = []
		_pattern_advice = []
		_repeat_trouble = []
		var report: Dictionary = await _checked(trial, true)
		if bool(report["ok"]):
			break
		var ours: Array = []
		for index: Variant in report.get("floating", []):
			if int(index) >= standing:
				ours.append(int(index) - standing)
		var gone: int = rooms.drop(ours) if not ours.is_empty() else 0
		if gone == 0:
			break
		dropped += gone
		plan = rooms.answer()
	_last_rooms = plan.duplicate()
	_last_rooms["dropped"] = dropped
	if (plan["bricks"] as Array).is_empty():
		return {"trouble": "Nothing would fit: %s" % str(plan["summary"])}
	return plan


## Whether every stud of a one-wide brick has a part directly under it
## or on top of it, so the brick can be split into 1x1s and each still be
## held. A course's end brick in a bonded wall overhangs the course below
## and is held only through its own length: split, its end floated, and
## the first restyle of a wall was refused for it.
func _each_stud_held(placement: Placement, long: int, along_x: bool,
		frame: Transform3D = Transform3D.IDENTITY) -> bool:
	for step: int in long:
		var x: float = placement.x + (step + 0.5 if along_x else 0.5)
		var z: float = placement.z + (0.5 if along_x else step + 0.5)
		var under: Vector3 = frame * Vector3(x * STUD, (placement.y - 0.5) * PLATE, z * STUD)
		var over: Vector3 = frame * Vector3(x * STUD, (placement.y + 3.5) * PLATE, z * STUD)
		var held: bool = placement.y <= 0.01 \
			or builder.lattice.brick_at(BrickLattice.to_cell(under)) != 0 \
			or builder.lattice.brick_at(BrickLattice.to_cell(over)) != 0
		if not held:
			return false
	return true


## The plain two-wide bricks the finishing pass lays again as two rows, by
## how long they are, and the one-wide brick of each length a row is.
const TWO_WIDE: Dictionary = {"3003": 2, "3002": 3, "3001": 4}
const ONE_WIDE_OF: Dictionary = {1: "3005", 2: "3004", 3: "3622", 4: "3010"}


## Which way a one-wide brick's long face is open to the air, with room
## in front of it for a part laid on its side: "+z", "-z", "+x", "-x" or
## "" when neither is. When both are — a wall one stud thick standing on
## its own — the side away from the middle of the model.
##
## A brick in a section is given the section's [param frame], and says the
## side in the section's own coordinates. There only a side looking away
## from the section's origin counts: a prism face's inner row is open onto
## the hollow inside its shaft, and dressing laid there is never seen.
func _open_side(placement: Placement, long: int, along_x: bool,
		middle: Vector3, frame: Transform3D = Transform3D.IDENTITY) -> String:
	var sides: Array = ["+z", "-z"] if along_x else ["+x", "-x"]
	var in_section: bool = frame != Transform3D.IDENTITY
	# A section found for a model opened from a file has its origin at the
	# middle of what stands, not at its own prism's: a pier's faces that look
	# across a cleft are sixty degrees and more off straight out from there,
	# and were never dressed. There a side counts that does not look back
	# towards the middle, and is open far enough out that it is not a groove.
	var adopted: bool = in_section and _adoptions.values().any(
		func(one: Section) -> bool: return one.name == placement.section)
	var centre := Vector3((placement.x + 0.5) * STUD, 0, (placement.z + 0.5) * STUD)
	var open: Array = []
	for side: String in sides:
		var out: Vector3 = FACES[side]
		# Within sixty degrees of straight out from the origin: the end of a
		# face's course is open sideways onto the groove at its corner, and a
		# tile laid there looks into the groove, not out of the tower.
		if adopted:
			var seen: Vector3 = frame * centre
			var away := Vector3(seen.x - middle.x, 0.0, seen.z - middle.z)
			if (frame.basis * out).dot(away.normalized()) < -0.1:
				continue
		elif in_section and out.dot(Vector3(centre.x, 0.0, centre.z).normalized()) < 0.5:
			continue
		var clear: bool = true
		for step: int in long:
			for up: float in [0.75, 2.25]:
				# The middle of this stud of the face, a little and then a
				# plate's thickness out.
				var x: float = placement.x + (step + 0.5 if along_x else 0.5)
				var z: float = placement.z + (0.5 if along_x else step + 0.5)
				var at := Vector3(x * STUD, (placement.y + up) * PLATE, z * STUD)
				at += out * (STUD * 0.5)
				for reach: float in ([2.0, 7.0, 24.0] if adopted else [2.0, 7.0]):
					var cell: Vector3i = BrickLattice.to_cell(frame * (at + out * reach))
					if builder.lattice.brick_at(cell) != 0:
						clear = false
		if clear:
			open.append(side)
	if open.size() == 1:
		return str(open[0])
	if open.size() == 2:
		var away: Vector3 = centre - middle
		if adopted:
			away = frame.basis.inverse() * (frame * centre - middle)
		if along_x:
			return "+z" if away.z >= 0.0 else "-z"
		return "+x" if away.x >= 0.0 else "-x"
	return ""


## A many-sided shaft in one object: each face a bonded wall in a section
## of its own, turned to the face's angle about the middle.
##
## The fifth Orthanc built its piers octagonal from 560 bricks in ~150
## sections it worked out by hand — the first run at the real-set norm for
## parts at an angle, 26% — and it cost the run everything else: it never
## saw its finished model. The seventh took the finishing pass because it
## was one call. So is this.
##
## Faces are as wide as lets their inside corners just meet, which leaves
## a narrow groove up each outside corner: the faceted edge a polygonal
## tower has.
##
##   {"pattern": "prism", "at": {"x": 16, "y": 0, "z": 16}, "sides": 8,
##    "radius": 7, "courses": 10, "thickness": 2, "color": 0}
func _prism(pattern: Dictionary, model: Model, index: int, trouble: Array) -> Array:
	# A tower of piers at display proportions: its courses worked out when not
	# said, and said when the ones given are far from them. Once, at the top:
	# not again for its plinth's tower or each of its storeys.
	if pattern.has("piers") and not pattern.has("_storey") and not pattern.has("_raised"):
		pattern = _at_display_proportions(pattern)
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var cx: float = float(at.get("x", 0.0))
	var y0: float = float(at.get("y", 0.0))
	var cz: float = float(at.get("z", 0.0))
	var sides: int = int(pattern.get("sides", 8))
	var radius: float = float(pattern.get("radius", 6))
	var courses: int = int(round(float(pattern.get("courses", 8))))
	var thick: int = clampi(int(pattern.get("thickness", 2)), 1, 2)
	var colour: int = int(pattern.get("color", pattern.get("colour", DEFAULT_COLOUR)))
	var mix_colour: int = int(pattern.get("mix_color", pattern.get("mix_colour", -1)))
	var mix: float = clampf(float(pattern.get("mix", 0.15 if mix_colour >= 0 else 0.0)), 0.0, 0.5)
	# A black face gets its second tone unless told otherwise — in bands, a
	# course of it every BAND_EVERY, where a real tower's string courses and
	# setbacks are. The homepage's Orthanc was black on black and read as a
	# void; the next, sprinkled with dark bluish grey bricks and dressing,
	# read as noise. LEGO's 10237 is 13% dark bluish grey, on its ledges.
	var band_colour: int = int(pattern.get("band_color", pattern.get("band_colour",
		SECOND_TONE.get(colour, -1) if mix_colour < 0 else -1)))
	# Dressed unless asked not to be. Both were zero unless given, the
	# guidance said to give them, and no run did: the thirteenth Orthanc
	# stood a prism of plain faces (61% plain, 1% on its side) which the
	# finishing pass cannot reach once they are turned. "masonry": 0 and
	# "sideways": 0 still give a plain face.
	var masonry: float = clampf(float(pattern.get("masonry", 0.25)), 0.0, 1.0)
	if sides < 5 or sides > 16 or courses < 1 or courses > 200:
		trouble.append("prism wants 5 to 16 sides and 1 to 200 courses")
		return []
	if pattern.has("plinth") and not pattern.has("_storey"):
		return _on_plinth(pattern, model, index, trouble)
	if pattern.has("storeys") and not pattern.has("_storey"):
		return _storeys(pattern, model, index, trouble)
	var clear: float = _clear_radius(sides, radius, thick)
	if clear != radius:
		_pattern_advice.append(("A prism of %d sides at radius %s has two faces turned off "
			+ "the grid meeting with less than a fifth of a stud between their bricks, "
			+ "so it is laid at radius %s.") % [sides, Placement._num(radius),
			Placement._num(clear)])
		radius = clear
	var width: int = int(floor(2.0 * (radius - thick) * tan(PI / sides) + 0.001))
	if width < 2:
		trouble.append("a prism of radius %s has faces narrower than two studs; "
			% Placement._num(radius) + "%d sides want a radius of %s or more"
			% [sides, Placement._num(_least_radius(sides, thick))])
		return []
	var sideways: float = clampf(float(pattern.get("sideways", 0.15)), 0.0, 0.5)
	# Faces left out, centred on the back (the face looking -z, which is the
	# one turned half way round), so the inside shows the way a real set's
	# tower opens: rooms on floors, behind. Every Orthanc built here was a
	# solid shell, and that is where a real set's variety is.
	var open: int = clampi(int(pattern.get("open", 0)), 0, sides - 2)
	# With piers, an opening is the core's whole back, every face that looks
	# backwards, whatever number was asked: the fifteenth Orthanc asked for
	# two faces of an octagon and got one face and one pier opened, the
	# rooms behind a slot between two piers again. One more where the
	# count would leave it off centre. The back is what looks within
	# OPEN_REACH of straight back, an octagon's three faces: counted as
	# every face looking backwards at all, a ten-sided core opened five of
	# its ten, the seventeenth Orthanc's sides opened onto the hollows of its
	# piers, and the sky showed through it from its front corner.
	if pattern.has("piers") and open > 0:
		var back: int = 0
		for face: int in sides:
			if absf(angle_difference(TAU * face / sides, PI)) <= deg_to_rad(OPEN_REACH) + 0.001:
				back += 1
		open = maxi(open, back)
		if (open - back) % 2 != 0:
			open += 1
		open = mini(open, sides - 2)
	# The faces nearest the back first, the lower number of two as near.
	var order: Array = range(sides)
	order.sort_custom(func(a: int, b: int) -> bool:
		var from_a: float = absf(angle_difference(TAU * a / sides, PI))
		var from_b: float = absf(angle_difference(TAU * b / sides, PI))
		return from_a < from_b - 0.0001 or absf(from_a - from_b) <= 0.0001 and a < b)
	var left_out: Dictionary = {}
	for n: int in open:
		left_out[order[n]] = true
	var spec := {"x": cx, "y": y0, "z": cz, "sides": sides, "radius": radius,
		"courses": courses, "thick": thick, "colour": colour,
		"mix_colour": mix_colour, "mix": mix, "masonry": masonry,
		"band_colour": band_colour,
		"sideways": sideways, "open": open, "left_out": left_out,
		# Only when asked. They were on by default, Trans-Yellow every eight
		# courses up every face, and the homepage's Orthanc read as an
		# office block: 228 lit 1 x 1s in rows. "windows": true lays them
		# narrow and few, in "window_color" (dark unless said).
		"windows": bool(pattern.get("windows", false)),
		"window_colour": int(pattern.get("window_color", pattern.get("window_colour",
			WINDOW_COLOUR))),
		# A storey of a prism in storeys (_storeys) is named for its storey
		# too: each face is a section turned about the middle from its own
		# foot, and two storeys' faces in one section would stand one on the
		# other's foot.
		"tag": str(index) if not pattern.has("_storey")
			else "%d storey %d" % [index, int(pattern["_storey"])],
		"summit_colour": int(pattern.get("_summit_colour", colour))}
	if pattern.has("piers"):
		return _cluster(pattern, spec, model, index, trouble)
	# Each face as a cluster's core lays one, its outside row run on into the
	# groove at its corner where there is room: a plain prism of radius 9
	# had a channel at each corner too wide for the post behind it to cover.
	var made: Array = []
	var laid: Dictionary = {}
	var tag: String = spec["tag"]
	# A door in its front only when asked: a plain prism is as often a column,
	# a chimney or a turret as a tower with a way in.
	var door: float = NAN
	if bool(pattern.get("door", false)) and not left_out.has(0):
		door = _door_for(Vector2(cx, cz), radius, sides, thick, [])
		if is_nan(door):
			_pattern_advice.append("No door was laid in the prism's front: its faces "
				+ "are narrower than four studs, or one stud thick.")
	for face: int in sides:
		if left_out.has(face):
			continue
		laid[face] = _cluster_face(made, model, "prism %s face %d" % [tag, face],
			Vector2(cx, cz), 360.0 * face / sides, radius, sides, spec, [], [], 0.0,
			courses, true, door if face == 0 else NAN)
	_corner_posts(made, model, func(face: int) -> String: return "prism %s face %d" % [tag, face],
		Vector2(cx, cz), sides, radius, spec, laid, [], courses)
	if pattern.has("_ledge"):
		made.append_array(_ledge(pattern, [_outline(Vector2(cx, cz), sides, radius, 0.0)],
			y0 + 3.0 * courses))
	return made


## A prism in storeys, each set back from the one below on a ledge: the
## answer to a tower with no silhouette. Every Orthanc built here rose the
## same width from its foot to its horns, a shaft with a top stuck on, where
## LEGO's 10237 steps in at each storey on a ledge of grey. Each storey is
## the prism again — piers, horns, windows and all — its core [code]in[/code]
## studs smaller than the one below and its piers the same size, drawn in
## with it, standing on a ledge two plates thick laid round the top of the
## one below in the second tone; only the top storey's piers rise into
## horns. The piers keep their size because a cluster of small piers on a
## small core does not hold: an octagonal core of radius 7 with piers of
## 4.5 overlaps itself and comes apart in six pieces. The ledge is a ring,
## so the rooms inside are not floored over at every storey.
##
##   "storeys": {"count": 3, "in": 1}
func _storeys(pattern: Dictionary, model: Model, index: int, trouble: Array) -> Array:
	var raw: Variant = pattern["storeys"]
	var asked: Dictionary = raw if raw is Dictionary else {"count": int(raw)}
	var count: int = int(asked.get("count", 3))
	var inset: float = float(asked.get("in", 1))
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var sides: int = int(pattern.get("sides", 8))
	var radius: float = float(pattern.get("radius", 6))
	var courses: int = int(round(float(pattern.get("courses", 8))))
	var thick: int = clampi(int(pattern.get("thickness", 2)), 1, 2)
	var colour: int = int(pattern.get("color", pattern.get("colour", DEFAULT_COLOUR)))
	if count < 2 or count > 8 or inset < 1.0 or inset != floor(inset) \
			or courses < 3 * count:
		trouble.append("storeys wants a count of 2 to 8, set in by a whole number of "
			+ "studs (\"in\", 1 or more), with at least 3 courses to a storey")
		return []
	var top: float = radius - inset * (count - 1)
	if floor(2.0 * (top - thick) * tan(PI / sides) + 0.001) < 2:
		trouble.append(("%d storeys set in %s each leave the top one radius %s, with "
			+ "faces narrower than two studs: fewer storeys, a smaller in, or a "
			+ "radius of %s or more") % [count, Placement._num(inset), Placement._num(top),
			Placement._num(_least_radius(sides, thick) + inset * (count - 1))])
		return []
	# The ledges are the second tone's bands on a prism in storeys, in
	# band_color if it is said; a colour with no second tone, its own.
	var ledge: int = int(pattern.get("band_color", pattern.get("band_colour",
		SECOND_TONE.get(colour, colour))))
	if ledge < 0:
		ledge = colour
	var piers: Dictionary = {}
	if pattern.has("piers"):
		var given: Variant = pattern["piers"]
		piers = (given as Dictionary).duplicate(true) if given is Dictionary \
			else {"count": int(given)}
	var p_sides: int = int(piers.get("sides", sides))
	var p_radius: float = float(piers.get("radius", round(radius * 2.0 / 3.0)))
	var least: float = _least_radius(p_sides, thick)
	var further: float = float(piers["out"]) - (radius + maxf(least, p_radius) - thick) \
		if piers.has("out") else 0.0
	var horns: int = int(round(float(piers.get("courses",
		courses + maxi(2, courses / 5))))) - courses
	var each: int = courses / count
	var y: float = float(at.get("y", 0.0))
	var made: Array = []
	for s: int in count:
		var storey: Dictionary = pattern.duplicate(true)
		storey.erase("storeys")
		storey["_storey"] = s
		# The door at the foot of the lowest: each storey laid its own, and the
		# ones above opened onto nothing half way up the tower.
		if s > 0:
			storey["door"] = false
		storey["_summit_colour"] = ledge
		storey["band_color"] = -1
		var high: int = each + (1 if s < courses % count else 0)
		var r: float = radius - inset * s
		storey["courses"] = high
		storey["radius"] = r
		storey["at"] = {"x": float(at.get("x", 0.0)), "y": y, "z": float(at.get("z", 0.0))}
		if s < count - 1:
			storey["_ledge"] = ledge
			# Under the whole of the next storey's wall and the posts in the
			# grooves behind its corners, which stand up to a stud and a half
			# inside it, so they stand on the ledge and not on the air inside
			# this one.
			storey["_hole"] = r - inset - thick - 1.5
		if not piers.is_empty():
			var these: Dictionary = piers.duplicate(true)
			var pr: float = maxf(least, p_radius)
			these["radius"] = pr
			these["out"] = r + pr - thick + further
			these["courses"] = high + (maxi(horns, 0) if s == count - 1 else 0)
			storey["piers"] = these
		made.append_array(_prism(storey, model, index, trouble))
		y += 3.0 * high + SUMMIT
	_pattern_advice.append(("The prism stands in %d storeys, each %s in from the one "
		+ "below on a ledge; the top one is radius %s, so add_rooms with that radius "
		+ "fits every storey, and its summit is at y %s.") % [count,
		Placement._num(inset), Placement._num(top), Placement._num(y - SUMMIT)])
	return made


## The most plates a piece of a ledge can be and still be left off: the
## crumbs where a ring crosses a diagonal were two and four, over air; the
## least piece that carried a pier of the storey above was thirty.
const LEDGE_CRUMBS := 6


## A tower on a plinth: square terraces stepping down from its foot, two
## courses each, and a stair from the ground up the front (+z) to the level
## of its door; the tower stands on the top terrace. Every Orthanc built here
## stood on a ring of rubble, and the owner named it: a base as an
## afterthought. LEGO's 10237 stands on a stepped black base with stairs up
## to its door.
##
## The terraces are a shape (`Shapes`): boxes, so every edge is straight —
## laid round, they were a circle stepped a stud at a time in plan, and read
## as a staircase from above. Their tops are tiled in the second tone right
## up to the tower's faces, studs only where the tower stands; inside they
## are hollow under a cap four plates thick, which nothing shows — the
## first hollow went up through the top, and the tower stood in a pit. The
## stair is part of the same shape, a step two plates high and a stud deep.
##
##   "plinth": {"steps": 2, "out": 2}
func _on_plinth(pattern: Dictionary, model: Model, index: int, trouble: Array) -> Array:
	var raw: Variant = pattern["plinth"]
	var asked: Dictionary = raw if raw is Dictionary else {}
	var steps: int = clampi(int(asked.get("steps", 2)), 1, 4)
	var out: int = clampi(int(asked.get("out", 2)), 1, 4)
	var colour: int = int(pattern.get("color", pattern.get("colour", DEFAULT_COLOUR)))
	colour = int(asked.get("color", asked.get("colour", colour)))
	var ledge: int = int(asked.get("ledge_color", SECOND_TONE.get(colour, colour)))
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var cx: float = float(at.get("x", 0.0))
	var cz: float = float(at.get("z", 0.0))
	var y0: float = float(at.get("y", 0.0))
	# The top terrace two studs clear of the tower's farthest corner either
	# way, and studs left showing under the tower and nowhere else.
	var foot: Array = _foot(pattern)
	var far: float = 0.0
	for outline: PackedVector2Array in foot:
		for point: Vector2 in outline:
			far = maxf(far, maxf(absf(point.x), absf(point.y)))
	var half: int = int(ceil(far - 0.001)) + 2
	# Any stud the tower's foot reaches over at all: by its middle alone, a
	# face turned off the grid stood its end bricks on tiles.
	var under: Array = []
	for x: int in range(-half, half):
		for z: int in range(-half, half):
			var reached: bool = false
			for point: Vector2 in [Vector2(x + 0.5, z + 0.5), Vector2(x + 0.1, z + 0.1),
					Vector2(x + 0.9, z + 0.1), Vector2(x + 0.1, z + 0.9), Vector2(x + 0.9, z + 0.9)]:
				for outline: PackedVector2Array in foot:
					reached = reached or Geometry2D.is_point_in_polygon(point, outline)
			if reached:
				under.append([x, z])
	# Rock rising against the tower from the top terrace's corners, in the
	# plinth's dark tones, unless told not to: the run after the blades stood
	# its tower on a flat pale yard 66 studs wide with five rock piles round
	# it, a base as an afterthought. Each crag as big as the corner holds clear
	# of the foot, so the base is no wider for it, on studs left for it.
	var crags: Array = []
	if bool(asked.get("rock", true)):
		crags = _plinth_crags(foot, half)
		for crag: Array in crags:
			for x: int in range(int(crag[0]), int(crag[0]) + int(crag[2])):
				for z: int in range(int(crag[1]), int(crag[1]) + int(crag[2])):
					under.append([x, z])
	# Two courses a terrace: one course stood as a ring round the foot, and
	# read from across the room as a kerb.
	var rise: int = 6
	var tall_: int = rise * steps
	var solids: Array = []
	for k: int in steps:
		var w: int = half + out * (steps - 1 - k)
		solids.append({"box": {"from": [-w, 0, -w], "size": [2 * w, rise * (k + 1), 2 * w]}})
	var hollow: int = half - 3
	# The stair: a flight cut into the terraces' front, four studs wide, a
	# step two plates high and a stud deep, from a kerb at the front edge
	# up to the top terrace, which runs on from its head to the door; its
	# treads tiled in the second tone. Cut in, it is bonded to the terraces
	# either side of it: stood out in front, in a colour of its own or laid
	# on its own, it was one or two pieces that nothing joined.
	var cuts: Array = [{"box": {"from": [-hollow, -1, -hollow],
		"size": [2 * hollow, tall_ - 3, 2 * hollow]}}]
	if bool(asked.get("stair", true)):
		# The lowest step four plates high, a brick under its tread: two, it
		# was plates beside the terraces' bricks, and a piece of its own.
		var edge: int = half + out * (steps - 1)
		var head: int = edge - tall_ / 2 + 1
		var treads: Array = []
		for c: int in range(head + 1, edge):
			treads.append([float(c), float(2 * (edge - c) + 2)])
			treads.append([float(c) + 0.999, float(2 * (edge - c) + 2)])
		treads.append([float(edge), 0.0])
		treads.append([float(edge) + 1.0, 0.0])
		cuts.append({"extrude": {"along": "z", "from": -2, "width": 4, "under": treads,
			"profile": [[head + 1, tall_ + 1], [edge + 1, tall_ + 1]]}})
	var raised: Dictionary = pattern.duplicate(true)
	raised.erase("plinth")
	raised["at"] = {"x": cx, "y": y0 + tall_, "z": cz}
	raised["_raised"] = true
	var tower: Array = _prism(raised, model, index, trouble)
	# Tiled, not studded, under a face turned off the grid: its sockets do
	# not meet the studs, which stand against its walls and tubes (the
	# read-back tower's 45 degree faces on 46 of them, dress_probe). It rests
	# there, held by the courses over it, and the square faces grip.
	var turned_on: Dictionary = _studs_turned_parts_miss(tower, model, y0 + tall_)
	under = under.filter(func(cell: Array) -> bool:
		return not turned_on.has(Vector2i(floori(cx + float(cell[0]) + 0.5),
			floori(cz + float(cell[1]) + 0.5))))
	# Square terraces in bricks, as they were measured: their steps are not
	# a curve to turn on its side, and the courses over the hollow are tied
	# by the tower's foot.
	var made: Array = Shapes.lay({"pattern": "shape", "at": {"x": cx, "y": y0, "z": cz},
		"color": colour, "top_color": ledge, "surface": "none", "panels": false,
		"sideways": false, "bridges": false,
		"studs_at": under, "solids": solids, "cuts": cuts}, trouble, library)
	if not trouble.is_empty():
		return []
	for n: int in crags.size():
		var crag: Array = crags[n]
		made.append_array(Patterns._rock({"at": {"x": cx + float(crag[0]), "y": y0 + tall_,
			"z": cz + float(crag[1])}, "across": crag[2], "deep": crag[2],
			"height": 3 * clampi(int(round(float(crag[2]) * 2.0)), 4, 10), "color": colour,
			"mix_color": ledge, "seed": index * 4 + n + 1}, trouble))
	_pattern_advice.append(("The tower stands on a plinth of %d terraces, %d plates tall%s: "
		+ "its foot, and add_rooms' y, is at y %s.") % [steps, tall_,
		(", %d crags of rock rising against it" % crags.size()) if not crags.is_empty() else "",
		Placement._num(y0 + tall_)])
	return made + tower


## The studs, as whole studs in the world's plan, at plate [param top] that a
## part of [param made] turned off the grid about the upright stands its foot
## on and does not take in a socket: every stud under it, but for one that
## lands in a socket of its (a turned part grips by one stud, a jumper's or a
## round plate's). A stud there stands against its walls and tubes, which the
## lattice, taking every stud for one in a socket, lets through and plastic
## does not (_note_turned_studs).
func _studs_turned_parts_miss(made: Array, model: Model, top: float,
		feet: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if feet.is_empty():
		feet = _turned_feet(made, model)
	for one: Array in feet.get(roundi(top * 4.0), []):
		var foot: PackedVector2Array = one[0]
		var takes: Array = one[1]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for p: Vector2 in foot:
			low = low.min(p)
			high = high.max(p)
		for x: int in range(floori(low.x) - 1, ceili(high.x) + 1):
			for z: int in range(floori(low.y) - 1, ceili(high.y) + 1):
				# The stud's own round, as a square a little inside it.
				var stud := PackedVector2Array([Vector2(x + 0.25, z + 0.25),
					Vector2(x + 0.75, z + 0.25), Vector2(x + 0.75, z + 0.75),
					Vector2(x + 0.25, z + 0.75)])
				if not _convex_meet(stud, foot):
					continue
				var middle := Vector2(x + 0.5, z + 0.5)
				var held: bool = false
				for take: Vector2 in takes:
					held = held or middle.distance_to(take) <= TURNED_GRIP
				if not held:
					out[Vector2i(x, z)] = true
	return out


## The feet of the parts of [param made] turned off the grid about the
## upright, by the quarter plate they stand at: [the foot's outline in plan,
## where it takes a stud], each in studs.
func _turned_feet(made: Array, model: Model) -> Dictionary:
	var out: Dictionary = {}
	for one: Dictionary in made:
		var name: String = str(one.get("section", ""))
		var section: Section = model.sections.get(name) if not name.is_empty() else null
		if section == null or section.square():
			continue
		var placement: Placement = Placement.from_dict(one)
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			continue
		var at: Transform3D = _transform(placement, mesh, section)
		if (at.basis * Vector3.UP).dot(Vector3.UP) < 0.9999:
			continue
		var box: AABB = mesh.bounds
		var foot := PackedVector2Array()
		for corner: Vector2 in [Vector2(box.position.x, box.position.z),
				Vector2(box.end.x, box.position.z), Vector2(box.end.x, box.end.z),
				Vector2(box.position.x, box.end.z)]:
			var p: Vector3 = at * Vector3(corner.x, box.position.y, corner.y)
			foot.append(Vector2(p.x, p.z) / STUD)
		var takes: Array = []
		var under: Array = _underside_of(mesh)
		for local: Vector2 in (under[0] as Array) + (under[1] as Array):
			var p: Vector3 = at * Vector3(local.x, 0.0, local.y)
			takes.append(Vector2(p.x, p.z) / STUD)
		var level: int = roundi((at * box.position).y / PLATE * 4.0)
		if not out.has(level):
			out[level] = []
		(out[level] as Array).append([foot, takes])
	return out


## The plate a tile of the same size is, for a ledge or a floor that a part
## turned off the grid stands on.
const PLATE_TILE: Dictionary = {"3024": "3070b", "3023": "3069b", "3023b": "3069b",
	"3623": "63864", "3710": "2431", "3666": "6636", "3460": "4162", "3022": "3068b",
	"3021": "26603", "3020": "87079", "3795": "69729"}


## Every plate of [param made] laid square (in no section) that a part turned
## off the grid stands on off its sockets, laid as the tile of its size: a
## storey stood its 45 degree faces on its ledge's studs, and a horn on the
## summit's. The plate under a square face keeps its studs, and holds it.
func _smooth_under_turned(made: Array, model: Model) -> void:
	var tops: Dictionary = {}    ## plate -> the plates there, by index into made
	for n: int in made.size():
		var one: Dictionary = made[n]
		if not str(one.get("section", "")).is_empty() or not PLATE_TILE.has(str(one["part"])) \
				or str(one.get("face", "up")) != "up":
			continue
		var top: float = float(one["y"]) + 1.0
		if not tops.has(top):
			tops[top] = []
		(tops[top] as Array).append(n)
	var feet: Dictionary = _turned_feet(made, model)
	if feet.is_empty():
		return
	for top: Variant in tops:
		if not feet.has(roundi(float(top) * 4.0)):
			continue
		var missed: Dictionary = _studs_turned_parts_miss(made, model, float(top), feet)
		if missed.is_empty():
			continue
		for n: int in tops[top]:
			var one: Dictionary = made[n]
			var placement: Placement = Placement.from_dict(one)
			var info: PartLibrary.PartInfo = library.parts.get(placement.part)
			if info == null:
				continue
			var size: Vector2i = info.footprint_studs()
			if posmod(placement.rot, 2) == 1:
				size = Vector2i(size.y, size.x)
			var on: bool = false
			for dx: int in size.x:
				for dz: int in size.y:
					on = on or missed.has(Vector2i(floori(placement.x + dx + 0.5),
						floori(placement.z + dz + 0.5)))
			if on:
				one["part"] = PLATE_TILE[placement.part]


## The crags a plinth's top terrace holds, each [x, z, studs across] from its
## middle: at each corner, and against the middle of each side but the front
## (where the stair is), the largest square of three studs or more at the
## terrace's edge that keeps a fifth of a stud clear of every outline of the foot.
static func _plinth_crags(foot: Array, half: int) -> Array:
	var out: Array = []
	for at: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		for size: int in range(mini(8, half), 2, -1):
			var x0: int = (half - size if at.x > 0 else -half) if at.x != 0 else -size / 2
			var z0: int = (half - size if at.y > 0 else -half) if at.y != 0 else -size / 2
			var square := PackedVector2Array([Vector2(x0 - 0.2, z0 - 0.2),
				Vector2(x0 + size + 0.2, z0 - 0.2), Vector2(x0 + size + 0.2, z0 + size + 0.2),
				Vector2(x0 - 0.2, z0 + size + 0.2)])
			var clear: bool = true
			for outline: PackedVector2Array in foot:
				clear = clear and not _convex_meet(square, outline)
			if clear:
				out.append([x0, z0, size])
				break
	return out


## How many times as tall as it is wide a tower stands as a display model, its
## base and horns included. LEGO's 10237 is 21 cm across and 73 cm tall, as its
## box says: 1 : 3.4. The homepage's Orthanc (run 18) stood 2.1 times its
## 49-stud base, and the next, on a 41-stud plate of rubble, 2.6: thin towers
## on wide bases, where a display tower stands on a base that hugs it.
const DISPLAY_TALL := 3.3
## How far from it the courses given may be before the reply says so.
const DISPLAY_SLACK := 0.2


## A prism with piers at display proportions. Not given its courses, it is
## laid in as many as make it [constant DISPLAY_TALL] times as tall as it is
## wide; given courses far from that, it is laid as asked and the reply says
## how many would do. The returned pattern is a copy when anything was added.
func _at_display_proportions(pattern: Dictionary) -> Dictionary:
	var wide: float = _display_width(pattern)
	var best: int = 3
	var off: float = INF
	var least: int = 3 * _storey_count(pattern)
	for courses: int in range(maxi(least, 3), 201):
		var miss: float = absf(_display_height(pattern, courses) * PLATE
			- DISPLAY_TALL * wide * STUD)
		if miss < off:
			off = miss
			best = courses
	if not pattern.has("courses"):
		var laid: Dictionary = pattern.duplicate(true)
		laid["courses"] = best
		_pattern_advice.append(("No courses were said, so the tower is laid in %d: %s times "
			+ "as tall as its base is wide (%s studs), as a display model stands — set "
			+ "10237 is 21 cm across and 73 cm tall.") % [best, "%.1f" % DISPLAY_TALL,
			roundi(wide)])
		return laid
	var courses: int = int(round(float(pattern["courses"])))
	var ratio: float = _display_height(pattern, courses) * PLATE / maxf(wide * STUD, 1.0)
	if absf(ratio - DISPLAY_TALL) > DISPLAY_TALL * DISPLAY_SLACK:
		_pattern_advice.append(("This tower stands %.1f times as tall as its base is wide "
			+ "(%s studs); a display model stands about %s — set 10237 is 21 cm across "
			+ "and 73 cm tall. %s, about %d courses, or leave courses out and they are "
			+ "worked out.") % [ratio, roundi(wide), "%.1f" % DISPLAY_TALL,
			"Taller" if ratio < DISPLAY_TALL else "Lower, or a wider radius", best])
	return pattern


## How wide a prism stands, its plinth included, in studs across the widest way.
func _display_width(pattern: Dictionary) -> float:
	var far: float = 0.0
	for outline: PackedVector2Array in _foot(pattern):
		for point: Vector2 in outline:
			far = maxf(far, maxf(absf(point.x), absf(point.y)))
	if not pattern.has("plinth"):
		return 2.0 * far
	var asked: Dictionary = pattern["plinth"] if pattern["plinth"] is Dictionary else {}
	var steps: int = clampi(int(asked.get("steps", 2)), 1, 4)
	var out: int = clampi(int(asked.get("out", 2)), 1, 4)
	return 2.0 * (ceil(far - 0.001) + 2.0 + out * (steps - 1))


## How many storeys a prism is laid in.
static func _storey_count(pattern: Dictionary) -> int:
	if not pattern.has("storeys"):
		return 1
	var raw: Variant = pattern["storeys"]
	return int((raw as Dictionary).get("count", 3)) if raw is Dictionary else int(raw)


## How tall a prism stands in [param courses], in plates: its plinth, its
## storeys and their summits, and its horns.
func _display_height(pattern: Dictionary, courses: int) -> float:
	var tall: float = 3.0 * courses + SUMMIT * _storey_count(pattern)
	if pattern.has("plinth"):
		var asked: Dictionary = pattern["plinth"] if pattern["plinth"] is Dictionary else {}
		tall += 6.0 * clampi(int(asked.get("steps", 2)), 1, 4)
	var given: Variant = pattern.get("piers")
	var piers: Dictionary = given if given is Dictionary else {}
	var above: int = int(round(float(piers.get("courses", courses + maxi(2, courses / 5))))) \
		- courses
	if above <= 0:
		return tall
	match str(piers.get("horns", "blade")).to_lower():
		"blade":
			var sides: int = int(pattern.get("sides", 8))
			var thick: int = clampi(int(pattern.get("thickness", 2)), 1, 2)
			var radius: float = _clear_radius(sides, float(pattern.get("radius", 6)), thick)
			var p_sides: int = int(piers.get("sides", sides))
			var asked_radius: float = maxf(_least_radius(p_sides, thick),
				float(piers.get("radius", round(radius * 2.0 / 3.0))))
			var p_radius: float = _clear_radius(p_sides, asked_radius, thick,
				float(piers.get("turn", 180.0 / maxi(int(piers.get("count", 4)), 1))))
			tall += _blade_lift() + Shapes.PLATES_PER_STUD * _blade_size(p_radius, above).y
		"spire":
			# The crown and its point, about two courses a ring and a stud's bar.
			tall += 3.0 * above + SUMMIT + 20.0
		_:
			tall += 3.0 * above + SUMMIT
	return tall


## What a prism stands on at its foot, in plan about its middle: its core's
## outline, and with piers each pier's, as its lowest storey lays them.
func _foot(pattern: Dictionary) -> Array:
	var sides: int = int(pattern.get("sides", 8))
	var thick: int = clampi(int(pattern.get("thickness", 2)), 1, 2)
	var radius: float = _clear_radius(sides, float(pattern.get("radius", 6)), thick)
	var outlines: Array = [_outline(Vector2.ZERO, sides, radius, 0.0)]
	if not pattern.has("piers"):
		return outlines
	var given: Variant = pattern["piers"]
	var piers: Dictionary = given if given is Dictionary else {"count": int(given)}
	var count: int = maxi(int(piers.get("count", 4)), 1)
	var p_sides: int = int(piers.get("sides", sides))
	var turn: float = float(piers.get("turn", 180.0 / count))
	var asked: float = maxf(_least_radius(p_sides, thick),
		float(piers.get("radius", round(radius * 2.0 / 3.0))))
	var pr: float = _clear_radius(p_sides, asked, thick, turn)
	# In storeys the piers are set out by the radius asked, not the one
	# spaced (_storeys).
	var out: float = float(piers.get("out", radius + (asked if pattern.has("storeys")
		else pr) - thick))
	for k: int in count:
		var angle: float = turn + 360.0 * k / count
		outlines.append(_outline(_towards(angle) * out, p_sides, pr, angle))
	return outlines


## A ledge two plates thick round the top of a storey: over the studs inside
## [param outlines] (this storey's, in plan) but not wholly inside the
## pattern's [code]_hole[/code], the inside of the next storey's wall.
func _ledge(pattern: Dictionary, outlines: Array, y: float) -> Array:
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var middle := Vector2(float(at.get("x", 0.0)), float(at.get("z", 0.0)))
	var sides: int = int(pattern.get("sides", 8))
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-(1 << 20), -(1 << 20))
	for outline: PackedVector2Array in outlines:
		for point: Vector2 in outline:
			low = Vector2i(mini(low.x, int(floor(point.x))), mini(low.y, int(floor(point.y))))
			high = Vector2i(maxi(high.x, int(ceil(point.x))), maxi(high.y, int(ceil(point.y))))
	var cells: Dictionary = _studs_within(outlines, low, high)
	var hole: float = float(pattern.get("_hole", 0.0))
	if hole > 0.0:
		for cell: Variant in _studs_within([_outline(middle, sides, hole, 0.0)], low, high):
			cells.erase(cell)
	return _summit(cells, y, int(pattern["_ledge"]), LEDGE_CRUMBS)


## The courses of one face of a prism, over each of its runs ([left, studs]
## in the face's own frame, which looks +z, and how many studs further the
## outside row runs on past the right-hand end), from [param base] plates up.
## [param clear] says whether a brick's dressing would be clear of what
## stands beside the face, for a face that meets another shaft. [param door]
## is the left end of a door's arch at its foot, in the face's own frame (see
## [method _door_for]), or NAN.
func _lay_face(made: Array, name: String, spec: Dictionary, runs: Array,
		radius: float, base: float, courses: int,
		clear: Callable = Callable(), windows: Dictionary = {},
		door: float = NAN) -> void:
	var wide: Array = [[4, "3001"], [3, "3002"], [2, "3003"]]
	var narrow: Array = [[4, "3010"], [3, "3622"], [2, "3004"], [1, "3005"]]
	var thick: int = spec["thick"]
	var colour: int = spec["colour"]
	var mix_colour: int = spec["mix_colour"]
	var mix: float = spec["mix"]
	# A window is in the face's widest run, at its middle stud.
	var widest: int = 0
	for n: int in runs.size():
		if int(runs[n][1]) > int(runs[widest][1]):
			widest = n
	var band_colour: int = int(spec.get("band_colour", -1))
	for course: int in courses:
		var y: float = base + 3.0 * course
		# A string course in the second tone, the whole way round.
		var tone: int = colour
		if band_colour >= 0 and course % BAND_EVERY == BAND_EVERY - 1 and course < courses - 1:
			tone = band_colour
		for n: int in runs.size():
			var run: Array = runs[n]
			var left: float = run[0]
			var width: int = run[1]
			var extra: int = int(run[2]) if run.size() > 2 else 0
			if n == widest and course < DOOR_BELOW + DOOR_ARCH_COURSES and not is_nan(door):
				_lay_door_course(made, name, spec, left, width, extra, radius, course, y,
					door, clear)
				continue
			var gap: float = NAN
			if windows.has(course) and n == widest and width >= 2:
				gap = left + floor(width / 2.0)
				made.append(_prism_brick(name, "3005", int(spec.get("window_colour", WINDOW_COLOUR)), gap, y,
					radius - 1.0, 0, -1, 0.0, 0.0))
			# Two thick: a course of two-wide bricks, then a course of two
			# rows of one-wide ones, which the courses either side tie
			# together. The outside row is where a face can be turned out
			# and dressed or laid as masonry: the first prism, all two-wide
			# bricks, was a face the finishing pass could not touch, and an
			# Orthanc built with it came out 94% plain.
			if thick == 2 and course % 2 == 0:
				_lay_row_around(made, name, wide, left, width, gap, y, radius - 2.0,
					course, tone, mix_colour, mix, 0.0, 0.0)
				if not is_nan(gap):
					made.append(_prism_brick(name, "3005", tone, gap, y,
						radius - 2.0, 0, mix_colour, mix, 0.0))
				if extra > 0:
					_lay_row(made, name, narrow, left + width, extra, y, radius - 1.0,
						course, tone, mix_colour, mix, 0.0, 0.0)
				continue
			# The bond of the one-wide rows counts their own courses: on a
			# two-thick face they are only ever the odd ones, and counted by
			# the course every outside row started short — 1x3s and 1x1s
			# only, so not one of them could be a masonry brick.
			var bond: int = course / 2 if thick == 2 else course
			_grille_until = left + width
			_lay_row_around(made, name, narrow, left, width + extra, gap, y,
				radius - 1.0, bond, tone, mix_colour, mix, spec["masonry"],
				spec["sideways"], clear)
			_grille_until = -INF
			if thick == 2:
				_lay_row(made, name, narrow, left, width, y, radius - 2.0,
					bond + 1, tone, mix_colour, mix, 0.0, 0.0)


## A row as [method _lay_row] lays it, but for the [param across] studs from
## [param gap] (a window or a door, laid by the caller), or whole where
## [param gap] is NAN.
func _lay_row_around(made: Array, section: String, lengths: Array, left: float,
		width: int, gap: float, y: float, z: float, course: int, colour: int,
		mix_colour: int, mix: float, masonry: float, sideways: float,
		clear: Callable = Callable(), across: int = 1) -> void:
	if is_nan(gap) or gap + across <= left or gap >= left + width:
		_lay_row(made, section, lengths, left, width, y, z, course, colour,
			mix_colour, mix, masonry, sideways, clear)
		return
	var before: int = maxi(0, int(round(gap - left)))
	var after: int = width - int(round(gap + across - left))
	if before > 0:
		_lay_row(made, section, lengths, left, before, y, z, course, colour,
			mix_colour, mix, masonry, sideways, clear)
	if after > 0:
		_lay_row(made, section, lengths, gap + across, after, y, z, course, colour,
			mix_colour, mix, masonry, sideways, clear)


## A great door at the foot of a tower's front: a 1 x 4 x 2 arch in the
## outside row DOOR_BELOW courses up, the two studs under it open, and the
## inside row behind the opening laid as the door, reddish brown log bricks
## set back a stud — in the inside row, so the opening is never a window onto
## an open back. Both rows are one-wide through the door's courses, and the
## course over the arch ties them again; and a jamb one stud wide is tied
## under the arch's foot (see [method _lay_door_course]). The seventeenth
## Orthanc built a stair up to its tower and nothing at the top of it;
## Orthanc's great door is up its steps.
const DOOR_ARCH := "6182"
const DOOR_ARCH_COURSES := 2
const DOOR_BELOW := 4
const DOOR_PANEL := "30136"
const DOOR_COLOUR := 70


## One course of a face's run through its door, whose arch's left end is at
## [param door]: the outside row around the opening (around the arch, where
## the arch is), the inside row around the door, and the door and the arch.
##
## The arch stands on one stud each side and hands down everything over it, so
## each of its feet carries two studs' worth of wall. Where the face leaves the
## jamb one stud wide, the course under each foot is a 1 x 2 laid across both
## rows, which hands that on to both: two 1 x 1s there were a column on one
## stud, untied to the inside row, and in the Wizard's Tower each of its
## bricks carried 83 to 85 g where a stud holds 80.
func _lay_door_course(made: Array, name: String, spec: Dictionary, left: float,
		width: int, extra: int, radius: float, course: int, y: float, door: float,
		clear: Callable) -> void:
	var narrow: Array = [[4, "3010"], [3, "3622"], [2, "3004"], [1, "3005"]]
	var colour: int = spec["colour"]
	var arch: bool = course >= DOOR_BELOW
	var tie_left: bool = course == DOOR_BELOW - 1 and absf(door - left) < 0.01
	var tie_right: bool = course == DOOR_BELOW - 1 \
		and absf(left + width + extra - (door + 4.0)) < 0.01
	var from: float = door if arch else door + (0.0 if tie_left else 1.0)
	var across: int = 4 if arch else 2 + int(tie_left) + int(tie_right)
	_lay_row_around(made, name, narrow, left, width + extra, from,
		y, radius - 1.0, course, colour, spec["mix_colour"], spec["mix"],
		spec["masonry"], spec["sideways"], clear, across)
	_lay_row_around(made, name, narrow, left, width, from if not arch else door + 1.0,
		y, radius - 2.0, course + 1, colour, spec["mix_colour"], spec["mix"], 0.0, 0.0,
		Callable(), across if not arch else 2)
	for at: float in ([door] if tie_left else []) + ([door + 3.0] if tie_right else []):
		made.append(_prism_brick(name, "3004", colour, at, y, radius - 2.0, 1,
			spec["mix_colour"], spec["mix"], 0.0))
	made.append(_prism_brick(name, DOOR_PANEL, DOOR_COLOUR, door + 1.0, y,
		radius - 2.0, 0, -1, 0.0, 0.0))
	if course == DOOR_BELOW:
		made.append({"part": DOOR_ARCH, "color": colour, "x": door, "y": y,
			"z": radius - 1.0, "rot": 0, "section": name})


## Where a door goes in the face of a prism of [param sides] about
## [param origin] that looks straight ahead (+z): the left end of its arch in
## the face's own frame, on the face's brick grid, its two-stud opening inside
## the stretch of the face's outside that [param covers] (outlines in plan, a
## cluster's piers) leaves in view and as near that stretch's middle as the
## grid allows; NAN where none fits. The seventeenth Orthanc's piers left two
## studs of its core's front in view.
static func _door_for(origin: Vector2, radius: float, sides: int, thick: int,
		covers: Array) -> float:
	var width: int = int(floor(2.0 * (radius - thick) * tan(PI / sides) + 0.001))
	if thick < 2 or width < 4:
		return NAN
	var left: float = -width / 2.0
	# In view: from the face's middle out to the nearest cover either way.
	var lo: float = left
	var hi: float = left + width
	for shape: PackedVector2Array in covers:
		var span: Array = _span_in_face(shape, origin, 0.0, radius - 0.05, radius + 0.05)
		if span.is_empty():
			continue
		if float(span[1]) <= 0.0:
			lo = maxf(lo, float(span[1]))
		elif float(span[0]) >= 0.0:
			hi = minf(hi, float(span[0]))
		else:
			return NAN
	var best: float = NAN
	for k: int in width - 3:
		var at: float = left + k
		if at + 1.0 < lo - 0.01 or at + 3.0 > hi + 0.01:
			continue
		var off: float = absf(at + 2.0 - (lo + hi) / 2.0)
		if is_nan(best) or off < absf(best + 2.0 - (lo + hi) / 2.0) - 0.001:
			best = at
	return best


## One row of a prism's face, in its own frame: bonded by the course,
## the outside row ([param masonry], [param sideways] above nought) turned
## to stone or turned out and dressed, facing +z, which is out.
func _lay_row(made: Array, section: String, lengths: Array, left: float,
		width: int, y: float, z: float, course: int, colour: int,
		mix_colour: int, mix: float, masonry: float, sideways: float,
		clear: Callable = Callable()) -> void:
	var x: float = left
	var end: float = left + width
	var first: bool = true
	# On a dark face, what is turned out goes up it in ribs, never scattered.
	var dark: bool = _is_dark(colour)
	var ribs: Array[float] = []
	if dark and sideways > 0.0:
		ribs = _ribs(left, width)
	while x < end - 0.01:
		var rib: float = NAN
		for at: float in ribs:
			if at > x - 0.05:
				rib = at
				break
		if not is_nan(rib) and absf(rib - x) < 0.05 \
				and (not clear.is_valid() or bool(clear.call(x, 1))):
			var stud := {"part": "87087", "color": colour, "x": x, "y": y, "z": z,
				"rot": 0, "section": section}
			var on_it: Dictionary = _dress(stud, "+z", mix_colour if mix_colour >= 0 else colour,
				[RIB_PART])
			made.append(stud)
			if not on_it.is_empty():
				on_it["section"] = section
				made.append(on_it)
			x += 1.0
			first = false
			continue
		var room: int = int(round(end - x))
		if not is_nan(rib):
			room = mini(room, maxi(1, int(round(rib - x))))
		var chosen: Array = []
		for pair: Array in lengths:
			var long: int = int(pair[0])
			# Every other course starts short, so its joints fall across
			# the ones below.
			if first and course % 2 == 1 and long == int(lengths[0][0]) and room > 2:
				continue
			if long <= room:
				chosen = pair
				break
		first = false
		if chosen.is_empty():
			# A stud of width left on a two-wide course: a 1x2 across it.
			made.append(_prism_brick(section, "3004", colour, x, y, z, 1,
				mix_colour, mix, 0.0))
			x += 1.0
			continue
		var long: int = int(chosen[0])
		if sideways > 0.0 and not dark \
				and Patterns._scatter(x, y, z + float(section.hash() % 97), 53) < sideways \
				and (not clear.is_valid() or bool(clear.call(x, long))):
			for step: int in long:
				var one := {"part": "87087", "color": colour, "x": x + step, "y": y,
					"z": z, "rot": 0, "section": section}
				var dressing: Dictionary = _dress(one, "+z")
				made.append(one)
				if not dressing.is_empty():
					dressing["section"] = section
					made.append(dressing)
		elif masonry > 0.0 and long >= 2 and dark \
				and x + long - (2 if long % 2 == 0 else 1) < _grille_until - 0.01 \
				and posmod(course, GRILLE_EVERY) == GRILLE_EVERY / 2 \
				and ((not is_nan(rib) and absf(x + long - rib) < 0.05)
					or ribs.any(func(at: float) -> bool: return absf(at + 1.0 - x) < 0.05)):
			# A dark face's bricks either side of each rib as grille bricks,
			# every GRILLE_EVERY of its rows, a textured strip up the face
			# flanking the rib: 10237 is 3.6% grille brick, and the Orthanc
			# after it was 0.2%, its black faces long bricks the grille could
			# never reach. Scattered, they read as speckle; in a band round
			# every other row, they were 0.7%, two studs a face. Each grille
			# brick starts over the face: one wholly in the groove past it
			# would hang there on nothing.
			var along: int = 0
			while along < long:
				var pair: bool = long - along >= 2
				made.append(_with_section({"part": "2877" if pair else "3005",
					"color": colour, "x": x + along, "y": y, "z": z, "rot": 0}, section))
				along += 2 if pair else 1
		else:
			made.append(_prism_brick(section, str(chosen[1]), colour, x, y, z, 0,
				mix_colour, mix, masonry))
		x += float(long)


## Where the face being laid ends, in its own frame: a long brick run on
## past it into the groove is held by its part over the face, and laid as two
## grille bricks its far one hung in the groove on nothing.
var _grille_until: float = -INF


func _with_section(one: Dictionary, section: String) -> Dictionary:
	one["section"] = section
	return one


func _prism_brick(section: String, part: String, colour: int, x: float, y: float,
		z: float, rot: int, mix_colour: int, mix: float, masonry: float) -> Dictionary:
	var tone: int = colour
	# A second tone scattered through a dark face reads as speckle: there it
	# goes on the face's ribs (_lay_row), and here only on a light one.
	if mix_colour >= 0 and not _is_dark(colour) \
			and Patterns._scatter(x, y, z + float(section.hash() % 97), 43) < mix:
		tone = mix_colour
	var one := {"part": part, "color": tone, "x": x, "y": y, "z": z, "rot": rot,
		"section": section}
	# Stonework on the outside, which in a face's own frame is +z: relief in
	# the wall's own colour, which does not speckle.
	if Patterns.MASONRY.has(part) and rot == 0 \
			and Patterns._scatter(x, y, z + float(section.hash() % 97), 47) < masonry:
		one["part"] = Patterns.MASONRY[part]
	return one


## Whether a colour is dark enough that a plain face of it reads as a hole.
func _is_dark(code: int) -> bool:
	var colour: PartLibrary.BrickColor = library.colors.get(code) if library != null else null
	return colour != null and colour.rgb.get_luminance() <= DARK_LUMINANCE


## A prism's windows, when asked: one stud wide and two courses tall, in the
## outside row, every so many courses (the inside row stays whole, so a
## window is never seen through). Trans-Brown by default, LEGO's smoked
## glass: a dark slit. They were Trans-Yellow every eight courses on every
## face, and lit an Orthanc up as an office block.
const WINDOW_COLOUR := 40
const WINDOW_EVERY := 16
## A dark face's outside rows from one course of grille bricks beside its
## ribs to the next. 10237 is 86 grille bricks in 2,359 parts, in panels.
const GRILLE_EVERY := 2
## What a dark face's ribs carry on their side studs, and how far apart they
## are on a face wide enough for more than one: a column of round plates up
## the middle of every face reads as a rib, as 10237's columns of round
## plates and grille do; scattered over it, tiles, round tiles and cheese
## slopes read as speckle, and the run that had them was called noise.
const RIB_PART := "4073"
const RIB_EVERY := 4


## The cells of a run of a face, from [param left] [param width] studs along,
## that its ribs stand in: the one at the face's middle (nought in its own
## frame, or left of it where that leaves too little after) and every RIB_EVERY either side of it, as
## many as fall in the run with a stud of it before and two after. Split at a
## rib with one stud after, a face's outside row left the stud it runs on into
## its corner groove a column of 1 x 1s on its own, held by nothing.
static func _ribs(left: float, width: int) -> Array[float]:
	var out: Array[float] = []
	# The middle stud, or the one left of it where the middle leaves too little
	# after it: a rib left of the middle had a 1 x 3 after it every row, run on
	# into the groove, which is neither masonry nor grille.
	var middle: int = -1
	for at: int in [int(round(-left - 0.5)), int(floor(-left - 0.5 + 0.001))]:
		if at >= 1 and at <= width - 3:
			middle = at
			break
	if middle < 0:
		return out
	for i: int in range(1, width - 2):
		if posmod(i - middle, RIB_EVERY) == 0:
			out.append(left + i)
	return out

## Courses from one band of a black face's second tone to the next.
const BAND_EVERY: int = Patterns.BAND_EVERY

## The second tone a wall of a dark colour gets unless told: dark bluish
## grey through black, as 10237 Tower of Orthanc has it (66% and 13%).
const SECOND_TONE: Dictionary = Patterns.SECOND_TONE
## How far round from straight back a cluster's core is opened, in degrees:
## an octagon's three back faces, a decagon's three, a twelve-sided core's
## five.
const OPEN_REACH := 67.5


## A post up the inside of each corner where two laid faces of a shaft meet:
## a column of round bricks in one of the two faces' sections, from its foot
## to its top course. A face is as wide as whole studs allow, so its inner
## corner stops short of its neighbour's and a channel 2.4 LDU wide runs up
## beside it — narrower than a lattice cell, so nothing in the check sees it,
## and in a tower open at the back the sky shows through: a white slit up the
## front of the sixteenth Orthanc's core, seen from the front at six heights
## in nine. Faces cannot be brought closer (two walls at angles nearer than a
## cell collide), so the channel is closed from behind, as a builder puts a
## column in the corner of a polygonal tower. Only where it could be seen
## through: a tower open at the back, or with an odd number of sides, whose
## corners face each other across it, or a corner whose outside row could not
## run on into its groove — a decagon's or a twelve-sided prism's, closed or
## not, is open straight through along the corner. [param laid] is each laid
## face's runs, by number, the first looking [param turn] degrees round;
## [param against] outlines a post must keep clear of.
##
## A post square to one of the two faces has to stand clear of the other, and
## where the faces meet at a wider angle than an octagon's that puts it too
## far behind the channel's mouth to meet the sightlines that slant through:
## no post fitted any corner of the seventeenth Orthanc's ten-sided core. So
## where none fits square to either face, the post is turned half way between
## them, in a section of its own ("prism N corner K"), where it sits as near
## both as it can.
func _corner_posts(made: Array, model: Model, name_of: Callable, origin: Vector2,
		sides: int, radius: float, spec: Dictionary, laid: Dictionary, against: Array,
		courses: int, turn: float = 0.0, between_first: bool = false) -> Array:
	var posts: Array = []
	var step: float = 360.0 / sides
	for face: int in sides:
		var next: int = (face + 1) % sides
		if not laid.has(face) or not laid.has(next):
			continue
		# A face's outside row runs on past its right-hand end into the groove.
		var runs: Array = laid[face]
		var last: Array = runs[runs.size() - 1]
		var run_on: bool = last.size() > 2 and int(last[2]) > 0
		if int(spec["open"]) == 0 and sides % 2 == 0 and run_on:
			continue
		# In whichever face is turned off the grid first: a face square to it
		# is judged on its studs, and the half-stud grid seldom has a place
		# that covers the channel. Every corner of a prism has one.
		var hosts: Array = [[face, next], [next, face]]
		if _square_to_grid(turn + step * face):
			hosts.reverse()
		var at: Array = []
		var host: int = -1
		var frame: float = NAN
		# A pier's face is narrow, so a post square to it stands right behind
		# its inside row, and a turned part's cover reaches a cell past its
		# box: the check read such a post as resting on that row, off its
		# studs. Turned half way between, in a section of its own, it is
		# judged on nobody's grid.
		for size: int in ([] if between_first else [1, 2]):
			for pair: Array in hosts:
				var mine: float = turn + step * int(pair[0])
				var theirs: float = turn + step * int(pair[1])
				at = _corner_post([origin, mine, laid[pair[0]], radius],
					angle_difference(deg_to_rad(mine), deg_to_rad(theirs)) > 0.0,
					[origin, theirs, laid[pair[1]], radius], int(spec["thick"]),
					against + posts, size)
				if not at.is_empty():
					host = int(pair[0])
					break
			if not at.is_empty():
				break
		# Half way between the faces, or a little either side where half way is
		# square to the grid and the half-stud grid has no place that covers it
		# (a ten-sided core's corners at 90 and 270 degrees).
		for off: float in [0.0, 5.0, -5.0, 10.0, -10.0]:
			if not at.is_empty():
				break
			frame = turn + step * (face + 0.5) + off
			for size: int in [1, 2]:
				at = _corner_post([origin, turn + step * face, laid[face], radius], true,
					[origin, turn + step * next, laid[next], radius], int(spec["thick"]),
					against + posts, size, frame)
				if not at.is_empty():
					break
		if at.is_empty():
			continue
		var section: String = name_of.call(host) if is_nan(frame) \
			else str(name_of.call(face)).replace(" face ", " corner ")
		if not is_nan(frame) and not model.sections.has(section):
			model.sections[section] = Section.from_dict({"name": section, "x": origin.x,
				"y": spec["y"], "z": origin.y, "axis": "y", "degrees": frame})
		var size: float = 1.0 if at[2] == "3062b" else 2.0
		var turned: float = turn + step * host if is_nan(frame) else frame
		posts.append(_face_slab(origin, turned, float(at[0]) - CLUSTER_CLEAR,
			float(at[0]) + size + CLUSTER_CLEAR, float(at[1]) - CLUSTER_CLEAR,
			float(at[1]) + size + CLUSTER_CLEAR))
		for course: int in courses:
			made.append({"part": at[2], "color": spec["colour"], "x": at[0],
				"y": 3.0 * course, "z": at[1], "rot": 0, "section": section})
	return posts


## How far out from the core's middle to set piers that were not told: set
## into it by the thickness of its wall, or the nearest half stud to that at
## which no pier's face is left a hole by the core — part of it standing
## clear, but too little for a brick — deeper before further out, so the
## shaft stays one mass. A core of radius 8 with piers of 5 took two of each
## pier's faces down to 0.9 of a stud and laid nothing there, and the sky
## showed a stud wide straight through every pier, full height, from every
## corner (the run after the rules for clefts); a stud deeper, none.
static func _pier_out(middle: Vector2, sides: int, radius: float, p_sides: int,
		p_radius: float, thick: int, angles: Array[float], set_in: float) -> float:
	var core: PackedVector2Array = _outline(middle, sides, radius + CLUSTER_CLEAR, 0.0)
	for out: float in [set_in, set_in - 0.5, set_in - 1.0, set_in + 0.5, set_in + 1.0]:
		var holed: bool = false
		for angle: float in angles:
			var centre: Vector2 = middle + _towards(angle) * out
			for face: int in p_sides:
				var degrees: float = angle + 360.0 * face / p_sides
				var free: float = 0.0
				for one: Array in _free(centre, degrees, p_radius, thick, p_sides, [core]):
					free += float(one[1]) - float(one[0])
				if free > PIER_HOLE and _runs(centre, degrees, p_radius, thick, p_sides,
						[core]).is_empty():
					holed = true
		if not holed:
			return out
	return set_in


## A stretch of a pier's face left standing by the core, in studs, past which
## laying nothing there leaves a hole into the pier.
const PIER_HOLE := 0.3


## The least radius, in half studs, at which a prism of [param sides] faces
## [param thick] studs thick has faces two studs wide.
static func _least_radius(sides: int, thick: int) -> float:
	var radius: float = ceil((thick + 1.0 / tan(PI / sides)) * 2.0) / 2.0
	while int(floor(2.0 * (radius - thick) * tan(PI / sides) + 0.001)) < 2:
		radius += 0.5
	return radius


## The radius to lay a prism of [param sides] faces at, from the one asked:
## where two faces both turned off the grid meet, the bricks at their inside
## corners have to be a fifth of a stud apart, because each turned part's
## cover reaches about a seventh of a stud past it. A twelve-sided prism of
## radius 8 had a tenth and ran into itself at faces 1 and 2; at 8.5 it
## holds. A face square to the grid is laid exactly, so an octagon, whose
## turned faces each meet a square one, is laid as asked.
##
## A pair with one face turned needs less, a twentieth: the piers of radius
## 4.5 an octagonal core of 7 was given had a twenty-eighth, and their horns'
## faces ran into each other all the way up. [param turn] is the first face's
## angle, as a pier's is its own.
static func _clear_radius(sides: int, radius: float, thick: int, turn: float = 0.0) -> float:
	var need: float = 0.0
	for k: int in sides:
		var turned: int = (0 if _square_to_grid(turn + 360.0 * k / sides) else 1) \
			+ (0 if _square_to_grid(turn + 360.0 * (k + 1) / sides) else 1)
		need = maxf(need, [0.0, 0.05, 0.2][turned])
	if need <= 0.0:
		return radius
	var r: float = radius
	for _step: int in 4:
		var half: float = (r - thick) * tan(PI / sides)
		var face: float = floor(2.0 * half + 0.001) / 2.0
		if half - face >= need:
			return r
		r += 0.5
	return radius


## Whether a section turned [param degrees] about y is square to the grid.
static func _square_to_grid(degrees: float) -> bool:
	return absf(angle_difference(deg_to_rad(degrees),
		roundf(degrees / 90.0) * PI / 2.0)) < 0.001


## Where the post behind one end of a face of a shaft stands, in the face's
## own frame: [x, z, part], the corner of the studs a round brick
## [param size] studs across stands on (3062b, or 3941 where the gap is wider
## than one can cover: a face of a prism of radius 9 loses most of a stud to
## whole studs), or [] where none fits that covers it. [param host] is the
## face, [origin, degrees, runs, radius] — a run is [left, studs, how far its
## outside row runs on past its right-hand end] — and [param right] which of
## its ends; [param beside] the face round the corner from that end, the
## same way. As near the channel's mouth as it is clear of both faces by
## [constant CLUSTER_CLEAR] — nearer its own, the clutch check reads it as
## standing across that face's studs — and kept only if it meets every
## sightline that passes between them there, from either face's look and
## fifteen degrees past it: those are found by looking across the corner
## every five degrees and keeping the gaps between the faces' bricks at its
## mouth. With [param frame], the post is square to that turn instead of to
## the host face, and [x, z] are in that frame: a post turned half way
## between the two faces stands symmetric to both, centred on the mouth and
## just behind it.
static func _corner_post(host: Array, right: bool, beside: Array, thick: int,
		against: Array, size: int = 1, frame: float = NAN) -> Array:
	var origin: Vector2 = host[0]
	var degrees: float = host[1]
	var mine: Array = host[2]
	var radius: float = host[3]
	var inner: float = radius - thick
	var start := func(runs: Array) -> float:
		return float(runs[0][0])
	# One thick, the face is its outside row, run on into the groove.
	var finish := func(runs: Array) -> float:
		var last: Array = runs[runs.size() - 1]
		return float(last[0]) + int(last[1]) \
			+ (int(last[2]) if thick == 1 and last.size() > 2 else 0)
	var to_plan := func(face: Array, at: Vector2) -> Vector2:
		var turned: float = deg_to_rad(float(face[1]))
		return (face[0] as Vector2) + Vector2(cos(turned), -sin(turned)) * at.x \
			+ _towards(float(face[1])) * at.y
	var mine_end: float = finish.call(mine) if right else start.call(mine)
	var corner: Vector2 = to_plan.call(host, Vector2(mine_end, inner))
	# The faces' bricks in plan, as laid and grown by the clearance.
	var walls: Array = []
	var kept_off: Array = []
	var theirs: Array = []
	var c: float = CLUSTER_CLEAR
	for face: Array in [host, beside]:
		var inside: float = float(face[3]) - thick
		for run: Array in face[2]:
			var a: float = float(run[0])
			var b: float = a + int(run[1])
			var slabs: Array = [_face_slab(face[0], face[1], a, b, inside, face[3])]
			kept_off.append(_face_slab(face[0], face[1], a - c, b + c, inside - c,
				float(face[3]) + c))
			if run.size() > 2 and int(run[2]) > 0:
				var e: float = b + int(run[2])
				slabs.append(_face_slab(face[0], face[1], b, e, float(face[3]) - 1.0, face[3]))
				kept_off.append(_face_slab(face[0], face[1], b - c, e + c,
					float(face[3]) - 1.0 - c, float(face[3]) + c))
			walls.append_array(slabs)
			if face == beside:
				theirs.append_array(slabs)
	# The mouth: midway from this face's inner corner to the nearest point of
	# the face beside it.
	var meets: Vector2 = corner
	var closest: float = INF
	for slab: PackedVector2Array in theirs:
		for k: int in slab.size():
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(corner, slab[k],
				slab[(k + 1) % slab.size()])
			if point.distance_to(corner) < closest:
				closest = point.distance_to(corner)
				meets = point
	var at_mouth: Vector2 = (corner + meets) / 2.0
	var other: float = float(beside[1])
	var inward: Vector2 = (origin - at_mouth).normalized()
	# What passes between the two faces, every five degrees from one face's
	# look to the other's and fifteen past each: [the way across, the gaps at
	# the mouth across it, the way along].
	var sightlines: Array = []
	var apart: float = rad_to_deg(absf(angle_difference(deg_to_rad(degrees), deg_to_rad(other))))
	var fan: int = int(ceil((apart / 2.0 + 15.0) / 5.0))
	for n: int in range(-fan, fan + 1):
		var way: Vector2 = inward.rotated(deg_to_rad(5.0 * n))
		var across := Vector2(way.y, -way.x)
		var spans: Array = []
		for wall: PackedVector2Array in walls:
			var lo: float = INF
			var hi: float = -INF
			for point: Vector2 in wall:
				lo = minf(lo, point.dot(across))
				hi = maxf(hi, point.dot(across))
			spans.append([lo, hi])
		spans.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var here: float = at_mouth.dot(across)
		var gaps: Array = []
		var reach: float = spans[0][1]
		for span: Array in spans:
			if float(span[0]) > reach + 0.01 and reach < here + 1.5 and float(span[0]) > here - 1.5:
				gaps.append([reach, float(span[0])])
			reach = maxf(reach, float(span[1]))
		if not gaps.is_empty():
			sightlines.append([across, gaps, way])
	var half: float = size / 2.0
	var square_to: float = degrees if is_nan(frame) else frame
	var placed_in: Array = host if is_nan(frame) else [origin, frame]
	var on_grid: bool = _square_to_grid(square_to)
	var best: Array = []
	var nearest: float = INF
	var z_top: float = floor((inner - CLUSTER_CLEAR - size) * 10.0 + 0.001) / 10.0
	var x_mid: float = floor((mine_end - (size if right else 0.0)) * 10.0) / 10.0
	var deep: int = 16
	if not is_nan(frame):
		# Centred on the mouth across, and from just behind it inwards.
		var turned: float = deg_to_rad(frame)
		var mouth := Vector2((at_mouth - origin).dot(Vector2(cos(turned), -sin(turned))),
			(at_mouth - origin).dot(_towards(frame)))
		z_top = floor((mouth.y - size) * 10.0 + 0.001) / 10.0
		x_mid = floor((mouth.x - half) * 10.0 + 0.5) / 10.0
		deep = 21
	for dz: int in deep:
		var z: float = snappedf(z_top - 0.1 * dz, 0.1)
		for dx: int in 41:
			var x: float = snappedf(x_mid + 0.1 * (dx - 20), 0.1)
			var middle: Vector2 = to_plan.call(placed_in, Vector2(x + half, z + half))
			var off: float = middle.distance_to(at_mouth)
			if off >= nearest:
				continue
			var square: PackedVector2Array = _face_slab(origin, square_to, x, x + size, z, z + size)
			var clear: bool = true
			for shape: PackedVector2Array in kept_off + against:
				clear = clear and not _convex_meet(square, shape)
			if not clear:
				continue
			# A face square to the grid is judged on its studs like any square
			# part: its post on whole or half studs, as the face's bricks are.
			if on_grid:
				var low := Vector2(INF, INF)
				for point: Vector2 in square:
					low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
				if absf(low.x * 2.0 - roundf(low.x * 2.0)) > 0.01 \
						or absf(low.y * 2.0 - roundf(low.y * 2.0)) > 0.01:
					continue
			# Its round body across every gap.
			var covers: bool = true
			for seen: Array in sightlines:
				var centre: float = middle.dot(seen[0])
				covers = covers and (middle - at_mouth).dot(seen[2]) > 0.0
				for gap: Array in seen[1]:
					covers = covers and centre - half <= float(gap[0]) \
						and centre + half >= float(gap[1])
			if covers:
				best = [x, z, "3062b" if size == 1 else "3941"]
				nearest = off
	return best


## How far the shafts of a cluster keep apart, in studs. A part turned to an
## angle claims every lattice cell it touches, and a cell is 2 LDU, so two
## walls at different angles nearer than a cell's diagonal (2.8 LDU) share
## one and collide; this is 3, and every brick of a cluster sits on the
## lattice's tenth-of-a-stud grid in its own frame, so it is never less.
const CLUSTER_CLEAR := 0.15
## How thick the summit a cluster's core is capped with is, in plates.
const SUMMIT := 2


## Faceted piers clustered round a prism's core, in the same object: each pier
## a prism of its own whose faces are bonded walls turned to their angles,
## standing where it meets the core, with a cleft between each two.
##
## The fourteenth Orthanc had its best form yet — four piers clustered round
## a core, rising into horns — and built the piers square, by hand, so nothing
## in it was at an angle (0%, against a real-set median of 27%). Run 5 built
## its piers octagonal by hand from 150 sections and reached the median at
## the cost of the run. A design takes up a technique when it is one call
## shaped like the work it is already doing; this is that work as one call.
##
## The core is whole and each pier is built against it, as a buttress is
## against a wall: a pier's faces stop a clearance short of the core's
## outside and of the next pier round, so nothing is in two places and a
## groove at a joint looks onto a face, not through it. Walls at different
## angles hold only by resting on one another, so the core is capped at its
## top with a summit two plates thick laid across every wall of core and pier
## alike — one piece, as a real tower's roof ties its walls, and the floor of
## polished stone between Orthanc's horns. The piers rise past it into horns,
## whole prisms standing on the summit.
##
## With "open", the core's back faces are left out as on a prism, and so is
## every face of a pier at the back that looks backwards or across the
## opening: run 14's rooms were behind a slot, where 10237 opens its whole
## back onto them.
##
##   "piers": {"count": 4, "sides": 8, "radius": 6, "out": 13, "courses": 38}
func _cluster(pattern: Dictionary, spec: Dictionary, model: Model, index: int,
		trouble: Array) -> Array:
	var raw: Variant = pattern.get("piers")
	var piers: Dictionary = raw if raw is Dictionary else {}
	if raw is int or raw is float:
		piers = {"count": int(raw)}
	var sides: int = spec["sides"]
	var radius: float = spec["radius"]
	var thick: int = spec["thick"]
	var courses: int = spec["courses"]
	var count: int = int(piers.get("count", 4))
	# The core's own sides unless said, so four piers on an octagon have faces
	# parallel to the core's and meet it flat. Six-sided piers on an octagon
	# meet it corner first, with a wedge of groove beside every cleft.
	var p_sides: int = int(piers.get("sides", sides))
	# Two thirds of the core's, and never less than keeps two-stud faces at
	# its sides. Asked smaller, the piers are laid at that and the check
	# says so: refused, the fifteenth and sixteenth Orthancs both asked for
	# piers of radius 4 at eight sides, were told "make their radius larger
	# or their sides fewer", and took six sides, which meet an octagon
	# corner first and leave the sky showing beside every cleft.
	var least: float = _least_radius(p_sides, thick)
	var p_radius: float = maxf(least, float(piers.get("radius", round(radius * 2.0 / 3.0))))
	if p_radius > float(piers.get("radius", p_radius)):
		_pattern_advice.append("Piers of radius %s would have faces narrower than two "
			% Placement._num(float(piers["radius"])) + "studs at %d sides, so they are " % p_sides
			+ "laid at radius %s, the least that keeps %d sides." % [Placement._num(least), p_sides])
	# And far enough out that their own faces clear each other where they
	# meet, as a prism's are.
	var spaced: float = _clear_radius(p_sides, p_radius, thick,
		float(piers.get("turn", 180.0 / maxi(int(piers.get("count", 4)), 1))))
	if spaced != p_radius:
		_pattern_advice.append(("Piers of radius %s have faces whose bricks meet with "
			+ "too little between them, so they are laid at radius %s.")
			% [Placement._num(p_radius), Placement._num(spaced)])
		p_radius = spaced
	# Past the core's summit into horns unless said: Orthanc's four rise above
	# its top, and so do a castle's corner turrets.
	var p_courses: int = int(round(float(piers.get("courses",
		courses + maxi(2, courses / 5)))))
	# Between the faces the back opens through, so a cleft is at the front
	# and one at the back.
	var turn: float = float(piers.get("turn", 180.0 / maxi(count, 1)))
	if count < 2 or count > 8 or p_sides < 5 or p_sides > 16:
		trouble.append("piers wants a count of 2 to 8 and 5 to 16 sides each")
		return []
	# What the piers rise into past the summit: blades unless said.
	var horns: String = str(piers.get("horns", "blade")).to_lower()
	if not horns in HORNS:
		trouble.append("piers' horns are %s" % ", ".join(PackedStringArray(HORNS)))
		return []
	if p_courses > 200:
		trouble.append("piers wants 200 courses at most")
		return []
	var middle := Vector2(spec["x"], spec["z"])
	var clear: float = CLUSTER_CLEAR
	var angles: Array[float] = []
	for k: int in count:
		angles.append(turn + 360.0 * k / count)
	# Set into the core by the thickness of its wall, so each pier stands out
	# of it by most of its width and the clefts between them are deep.
	var out: float = float(piers.get("out", radius + p_radius - thick))
	if not piers.has("out"):
		out = _pier_out(middle, sides, radius, p_sides, p_radius, thick, angles, out)
	var shafts: Array[PackedVector2Array] = []
	for angle: float in angles:
		shafts.append(_outline(middle + _towards(angle) * out, p_sides, p_radius, angle))
	var core: PackedVector2Array = _outline(middle, sides, radius, 0.0)
	for k: int in count:
		if not _convex_meet(shafts[k], _outline(middle, sides, radius - 0.5, 0.0)):
			trouble.append("piers %s out stand clear of the core and would not meet it; "
				% Placement._num(out) + "bring them in (out less than %s)"
				% Placement._num(radius + p_radius - 0.5))
			return []
		if _inside_of(shafts[k], _outline(middle, sides, radius + 1.0, 0.0)):
			trouble.append("piers %s out stand inside the core; take them out "
				% Placement._num(out) + "(out more than %s)" % Placement._num(radius - p_radius + 1.0))
			return []

	# The back, which the core's open faces look through, and the piers that
	# stand on it.
	var left_out: Dictionary = spec["left_out"]
	var back := Vector2.ZERO
	for face: Variant in left_out:
		back += _towards(360.0 * int(face) / sides)
	var reach: float = 180.0 * float(left_out.size()) / sides
	var behind: Array[bool] = []
	for angle: float in angles:
		behind.append(not left_out.is_empty() and back.length() > 0.001
			and rad_to_deg(absf(_towards(angle).angle_to(back))) <= reach + 0.01)

	var made: Array = []
	var tag: String = spec["tag"]
	var name_of := func(pier: int, face: int) -> String:
		return ("prism %s face %d" % [tag, face]) if pier < 0 \
			else "prism %s pier %d face %d" % [tag, pier, face]
	# The core whole, but for its open back: each pier is built against it, as
	# a buttress is against a wall. The first clusters had the core stop short
	# of each pier instead, and its faces could only stop a groove short, so
	# every cleft had a slit down it that the rooms showed through; built
	# against the core, a groove looks onto its face.
	var grown: Array = []
	for k: int in count:
		grown.append(_outline(middle + _towards(angles[k]) * out, p_sides,
			p_radius + clear, angles[k]))
	# A great door in the core's front, at the top of whatever stair a design
	# builds to it, unless told not to: in the stretch the piers leave in view.
	var door: float = NAN
	if bool(pattern.get("door", true)) and not left_out.has(0):
		var piers_in_plan: Array = []
		for k: int in count:
			piers_in_plan.append(_outline(middle + _towards(angles[k]) * out, p_sides,
				p_radius, angles[k]))
		door = _door_for(middle, radius, sides, thick, piers_in_plan)
		if is_nan(door):
			_pattern_advice.append("No door was laid in the core's front: the piers "
				+ "leave less than two studs of it in view, or its faces are narrower "
				+ "than four. Set the piers further out, or build a door yourself.")
	var laid: Dictionary = {}
	for face: int in sides:
		if left_out.has(face):
			continue
		var runs: Array = _cluster_face(made, model, name_of.call(-1, face), middle,
			360.0 * face / sides, radius, sides, spec, [], grown, 0.0, courses, true,
			door if face == 0 else NAN)
		if not runs.is_empty():
			laid[face] = runs
	_corner_posts(made, model, func(face: int) -> String: return name_of.call(-1, face),
		middle, sides, radius, spec, laid, [], courses)
	# The piers, short of the core's outside.
	var whole: PackedVector2Array = _outline(middle, sides, radius + clear, 0.0)
	# The core's faces that stand, each as the slab of its wall: what a pier at
	# the back gives way to where the core's back is open.
	var standing: Array = []
	var reach_out: float = (radius + clear) * tan(PI / sides) + clear
	for face: int in sides:
		if not left_out.has(face):
			standing.append(_face_slab(middle, 360.0 * face / sides, -reach_out, reach_out,
				radius - thick - clear, radius + clear))
	# And the core's inside, which the rooms are seen through from behind.
	# Piers set as deep into the core as the fifteenth Orthanc's meet across its
	# back and close it; kept clear of a way straight in instead, they let the
	# sky up the clefts again (13 sightlines from the corner).
	standing.append(_outline(middle, sides, radius - thick - clear, 0.0))
	for k: int in count:
		var centre: Vector2 = middle + _towards(angles[k]) * out
		# Welded where two piers meet, each giving way to the next one round,
		# as they all give way to the core: "four mighty piers of many-sided
		# stone were welded into one". A pier at the back of a core opened
		# behind gives way only to the core's faces that stand, and keeps
		# every face of its own: closed, it stands where the core's corner
		# was taken out. Left a frame, open behind and to the opening, the sky
		# showed through the seam where it met the core's last face and up its
		# own front grooves, from the corner a picture is taken from.
		var core_of: Array = standing if behind[k] else [whole]
		var against: Array = core_of + [grown[(k + 1) % count]]
		var dressed: Array = core_of.duplicate()
		for other: int in count:
			if other != k:
				dressed.append(grown[other])
		var pier_laid: Dictionary = {}
		for face: int in p_sides:
			var degrees: float = angles[k] + 360.0 * face / p_sides
			var runs: Array = _cluster_face(made, model, name_of.call(k, face), centre,
				degrees, p_radius, p_sides, spec, against, dressed, 0.0, courses,
				_towards(degrees).dot(_towards(angles[k])) > 0.3)
			if not runs.is_empty():
				pier_laid[face] = runs
		# Every pier is closed, the back ones too, but where its outside rows
		# cannot run on into its corner grooves, two of them line up: the
		# eighteenth Orthanc's ten-sided piers of radius 6, faces two studs
		# wide, showed the sky up both front clefts from the corner. Posted
		# as a closed prism is.
		var pier: int = k
		var as_closed: Dictionary = spec.duplicate()
		as_closed["open"] = 0
		_corner_posts(made, model, func(face: int) -> String: return name_of.call(pier, face),
			centre, p_sides, p_radius, as_closed, pier_laid, dressed, courses, angles[k], true)

	# The summit, across everything that stands inside the outline.
	var top: float = 3.0 * courses
	var outline: Array = [core]
	for k: int in count:
		outline.append(_outline(middle + _towards(angles[k]) * out, p_sides,
			p_radius, angles[k]))
	var span: float = radius + out + p_radius * 2.0
	var low := Vector2i(int(floor(middle.x - span)), int(floor(middle.y - span)))
	var high := Vector2i(int(ceil(middle.x + span)), int(ceil(middle.y + span)))
	if pattern.has("_ledge"):
		# A storey with another on it: a ledge round its top, not a floor.
		made.append_array(_ledge(pattern, outline, float(spec["y"]) + top))
	else:
		for plate: Dictionary in _summit(_studs_within(outline, low, high),
				float(spec["y"]) + top, spec["summit_colour"]):
			made.append(plate)

	# The horns as blades: each a fin of plates on their side rising from the
	# summit over its pier, sweeping out and back in to a point (_horn_blade).
	if p_courses > courses and horns == "blade":
		var base: float = float(spec["y"]) + top + SUMMIT
		var size: Vector2i = _blade_size(p_radius, p_courses - courses)
		var wide: int = size.x
		var tall: int = size.y
		var flare: float = float(piers.get("flare", round(wide * BLADE_FLARE)))
		for k: int in count:
			# In the plane through the tower's middle and its pier, sweeping
			# out from the crown, and turned BLADE_TURN off it towards the side,
			# so from the front every face shows and from the corner none
			# stands edge on. Turned to face the front, the four were two
			# straight sticks from the side and cut-off plates from the corner;
			# on their piers' lines exactly, the two on the corner view's line
			# were edge on, a mast behind the summit.
			var facing: float = angles[k]
			var aside: float = sin(deg_to_rad(angles[k]))
			if absf(aside) > 0.01:
				facing += clampf(rad_to_deg(angle_difference(deg_to_rad(angles[k]),
					deg_to_rad(90.0 if aside > 0.0 else 270.0))), -BLADE_TURN, BLADE_TURN)
			made.append_array(_horn_blade(model, "prism %s horn %d" % [tag, k],
				middle + _towards(angles[k]) * out, facing, base,
				floor(p_radius - 1.0), wide, tall, clampf(flare, 0.0, float(wide)),
				spec["colour"]))
		_pattern_advice.append(("Each pier rises past the summit as a blade %d studs wide "
			+ "and %d tall, its tip near y %s.") % [wide, tall,
			Placement._num(base + _blade_lift() + Shapes.PLATES_PER_STUD * tall)])
	# The horns: each pier again, whole, standing on the summit, capped
	# square at its top and carrying a point. Without the cap a horn ends in
	# faces turned to its angles, which nothing square can sit on: the
	# fifteenth Orthanc took its four generated horns down to build square
	# ones by hand ("Pier tops are built at 45°, so grid parts can't clip
	# on"), eight minutes of a run spent on what the call should have made.
	elif p_courses > courses:
		var crown: float = float(spec["y"]) + 3.0 * p_courses + SUMMIT
		var capped: Dictionary = {}
		for k: int in count:
			var centre: Vector2 = middle + _towards(angles[k]) * out
			var others: Array = []
			for other: int in count:
				if other != k:
					others.append(grown[other])
			for face: int in p_sides:
				_cluster_face(made, model, name_of.call(k, face), centre,
					angles[k] + 360.0 * face / p_sides, p_radius, p_sides, spec,
					[grown[(k + 1) % count]], others, top + SUMMIT, p_courses - courses)
			var cells: Dictionary = _studs_within(
				[_outline(centre, p_sides, p_radius, angles[k])], low, high)
			for cell: Variant in capped:
				cells.erase(cell)
			var cap: Array = _summit(cells, crown, spec["colour"])
			var on_top: Dictionary = {}
			for plate: Dictionary in cap:
				for cell: Vector2i in _plate_studs(plate):
					capped[cell] = true
					if is_equal_approx(float(plate["y"]), crown + 1.0):
						on_top[cell] = true
			made.append_array(cap)
			if horns == "spire":
				made.append_array(_horn_crown(on_top, centre, _towards(angles[k]),
					crown + SUMMIT, spec["colour"]))
	return made


## The whole studs inside [param outlines] (in plan, in studs), between
## [param low] and [param high]: each a Vector2i -> true, where its corners
## and its middle are each inside one of them.
static func _studs_within(outlines: Array, low: Vector2i, high: Vector2i) -> Dictionary:
	var cells: Dictionary = {}
	for x: int in range(low.x, high.x):
		for z: int in range(low.y, high.y):
			var all_in: bool = true
			for corner: Vector2 in [Vector2(x, z), Vector2(x + 1, z),
					Vector2(x, z + 1), Vector2(x + 1, z + 1), Vector2(x + 0.5, z + 0.5)]:
				var any: bool = false
				for shape: PackedVector2Array in outlines:
					if Geometry2D.is_point_in_polygon(corner, shape):
						any = true
						break
				if not any:
					all_in = false
					break
			if all_in:
				cells[Vector2i(x, z)] = true
	return cells


## What a pier's horns are: a blade (the default), the stepped spire with a
## point that came before it, or flat, a turret's square cap and nothing on it.
const HORNS: Array[String] = ["blade", "spire", "flat"]
## A blade's width at its foot, as a share of its pier's radius, and the
## least and most; how many times its width it rises at least; how far its
## outer edge sweeps out past its foot, as a share of its width.
const BLADE_WIDE := 1.2
const BLADE_LEAST := 4
const BLADE_MOST := 10
const BLADE_TALL := 2.6
const BLADE_FLARE := 0.5
## Degrees a blade is turned off its pier's line towards the side.
const BLADE_TURN := 20.0
## Layers of plates on their side a blade is laid in, each tied across the
## joints of the one under it; with its tiles, two studs deep. Two layers and
## tiles were 24 LDU, and the two blades seen edge on from the corner read as
## one sheet standing up out of the middle of the summit.
const BLADE_LAYERS := 4
## Bricks with studs on one side, longest first, that a blade's foot is
## pressed onto: the anchor every blade in a real set hangs from.
const BLADE_ANCHORS: Array = [[4, "30414"], [2, "11211"], [1, "87087"]]

## A blade's width at its foot and its height, in studs, over a pier of
## [param p_radius] whose courses rise [param above] past the core's.
static func _blade_size(p_radius: float, above: int) -> Vector2i:
	var wide: int = clampi(int(round(p_radius * BLADE_WIDE)), BLADE_LEAST, BLADE_MOST)
	return Vector2i(wide, maxi(int(ceil(3.0 * above / Shapes.PLATES_PER_STUD)),
		int(round(wide * BLADE_TALL))))


## A horn as a blade, in a section [param name] turned about the upright to
## [param degrees] over [param centre], its foot at [param y]: a fin of
## plates laid on their side, [param wide] studs across at the foot, whose
## outer edge stands at [param reach] studs out from the pier's middle;
## rising [param high] studs and sweeping out by up to [param flare] and back
## in to a point, its edges cut on the diagonal by wedge plates; its lowest
## row of plates pressed onto bricks with studs on their side standing on the
## summit. The sweep is the section's own: out along its z, up its y, the
## plates' studs looking along its x.
##
## LEGO's 10237 builds its four horns so, as blades of plates and wedge
## plates on their side, Technic edges and a point; the generated horns
## before this were square spires stepping in to a cone and a bar, and from
## the corner they read as four turrets with roofs. "Gaping horns, their
## pinnacles sharp as the points of spears."
func _horn_blade(model: Model, name: String, centre: Vector2, degrees: float,
		y: float, reach: float, wide: int, high: int, flare: float, colour: int) -> Array:
	var side: Dictionary = _blade_side()
	if side.is_empty():
		return []
	var edges: Array = _blade_edges(int(floor(reach)), wide, high, flare)
	var inner: PackedInt32Array = edges[0]
	var outer: PackedInt32Array = edges[1]
	# Its tiled face to the front: a blade's other face is the undersides of
	# its plates. One whose studs would look backwards is built the other way
	# round, turned half a turn with its edges taken from the other side, so
	# the same blade stands in the same place with its tiles the other way.
	var backwards: bool = sin(deg_to_rad(degrees)) > 0.001 \
		or (absf(sin(deg_to_rad(degrees))) <= 0.001 and cos(deg_to_rad(degrees)) < 0.0)
	if backwards:
		degrees += 180.0
		var flipped_in := PackedInt32Array()
		var flipped_out := PackedInt32Array()
		for v: int in inner.size():
			flipped_in.append(-outer[v])
			flipped_out.append(-inner[v])
		inner = flipped_in
		outer = flipped_out
	if not model.sections.has(name):
		model.sections[name] = Section.from_dict({"name": name, "x": centre.x, "y": y,
			"z": centre.y, "axis": "y", "degrees": degrees})
	var cells: Dictionary = {}
	for v: int in inner.size():
		for u: int in range(inner[v], outer[v]):
			cells[Vector2i(u, v)] = true
	var wedges: Array = _blade_wedges(inner, outer, cells, colour)
	# Centred on its pier's line: the anchors stand back by half the blade's
	# depth, which starts at their side studs.
	var anchor_x: float = snappedf(-0.2 * (BLADE_LAYERS + 1) - (float(side["face"]) + 1.0), 0.1)
	var face: float = anchor_x + float(side["face"]) + 1.0
	var made: Array = []
	var below: Dictionary = {}
	for layer: int in BLADE_LAYERS:
		var wanted: Dictionary = cells.duplicate()
		var laid: Dictionary = {}
		for wedge: Dictionary in wedges:
			made.append(_by_its_body(_on_its_side(wedge, side, face + 0.4 * layer, name),
				int(wedge["_side"])))
			for cell: Vector2i in wedge["_studs"]:
				wanted.erase(cell)
				laid[cell] = true
		for one: Dictionary in Patterns._tile(wanted, float(layer), colour, Patterns.TILES,
				below, laid, layer):
			made.append(_on_its_side(one, side, face + 0.4 * layer, name))
		below = laid
	# Its face smooth, as a set's blades are: tiles on every plate of the last
	# layer, the wedges' studs left showing along its edges.
	var faced: Dictionary = cells.duplicate()
	for wedge: Dictionary in wedges:
		for cell: Vector2i in wedge["_studs"]:
			faced.erase(cell)
	for one: Dictionary in Patterns._tile(faced, 0.0, colour, Shapes.TOPS, {}, {}):
		made.append(_on_its_side(one, side, face + 0.4 * BLADE_LAYERS, name))
	# The anchors, under the foot's row of plates.
	var at: int = inner[0]
	while at < outer[0]:
		for anchor: Array in BLADE_ANCHORS:
			var long: int = anchor[0]
			var turned: int = int((side["rot"] as Dictionary).get(anchor[1], -1))
			if at + long > outer[0] or turned < 0:
				continue
			made.append({"part": anchor[1], "color": colour, "x": anchor_x, "y": 0.0,
				"z": float(at), "rot": turned, "section": name})
			at += long
			break
	return made


## A blade's two edges, row by row up it (a row is a stud): where its inside
## begins and where its outside ends, in studs out from its pier's middle,
## until they meet at the tip: the whole sweeping out by [param flare] and
## part of the way back in to the point as it narrows; each edge moving a stud
## at a time, at most every other row, the steepest step a wedge plate's cut
## carries (_blade_wedges).
## Followed more closely, the first blades had edges that moved two and three
## studs a row, and their wedges stood out of them like the teeth of a saw.
static func _blade_edges(reach: int, wide: int, high: int, flare: float) -> Array:
	var inner := PackedInt32Array()
	var outer := PackedInt32Array()
	var middle: float = reach - wide / 2.0
	var o: int = reach
	var i: int = reach - wide
	var since_o: int = 0
	var since_i: int = 0
	var v: int = 0
	# Up to its height following the curves, then on until the edges meet: a
	# blade that stopped at its height three studs wide had a flat top, and
	# read as a slab.
	while v < high or o - i > 1 or mini(since_o, since_i) < 2:
		var t: float = minf((v + 0.5) / high, 1.0)
		if v > 0:
			# Either side of a centre line that sweeps out by the flare a little
			# over half way up and comes part of the way back, by a width that
			# narrows to nothing: a horn. Its outer edge bowed out on its own and
			# its inner held still, both curves, and the blades read as a hare's
			# ears. Past the height, both close on the tip.
			var line: float = middle + flare * sin(0.85 * PI * t)
			var across: float = wide * pow(1.0 - t, 0.8)
			var want: float = line + across / 2.0
			if v >= high:
				want = i + 1
			if since_o >= 2 and absf(want - o) >= 0.75:
				o += 1 if want > o else -1
				since_o = 0
			want = line - across / 2.0
			if v >= high:
				want = o - 1
			if since_i >= 2 and absf(want - i) >= 0.75 and o - i > 1:
				i += 1 if want > i else -1
				since_i = 0
		if o - i < 1 or v > 3 * high:
			break
		inner.append(i)
		outer.append(o)
		since_o += 1
		since_i += 1
		v += 1
	return [inner, outer]


## The wedge plates a blade's edges are cut by, laid flat (as _on_its_side
## takes them): at each step an edge makes, one two studs across whose studs
## stand in the last column inside and whose cut fills the column outside,
## full where the step is and running out over the rows beside it, so the
## edge goes on the diagonal from step to step. Which way each one's cut runs
## is read off its body (_blade_side's "wedges"), not off its studs, which are
## the same either way up: matched by its studs alone, every other wedge on
## the first blades stood the wrong way out of the edge.
func _blade_wedges(inner: PackedInt32Array, outer: PackedInt32Array, cells: Dictionary,
		colour: int) -> Array:
	var kinds: Dictionary = _blade_side().get("wedges", {})
	var rows: int = inner.size()
	var claimed: Dictionary = {}
	var made: Array = []
	for v: int in range(1, rows):
		# Each step: the column the wedge's studs stand in, the column its cut
		# fills, the row at the step, which way from it the wedge runs, which
		# end of the cut is full, and which of its two columns has the studs.
		var steps: Array = []
		var d: int = outer[v] - outer[v - 1]
		if d == -1:
			steps.append([outer[v] - 1, outer[v], v, 1, "low", 0])
		elif d == 1:
			steps.append([outer[v - 1] - 1, outer[v - 1], v - 1, -1, "high", 0])
		d = inner[v] - inner[v - 1]
		if d == 1:
			steps.append([inner[v], inner[v] - 1, v, 1, "low", 1])
		elif d == -1:
			steps.append([inner[v - 1], inner[v - 1] - 1, v - 1, -1, "high", 1])
		for step: Array in steps:
			var studs: int = step[0]
			var cut: int = step[1]
			var from: int = step[2]
			var way: int = step[3]
			# As many rows as the edge holds still beside the step, up to four.
			var long: int = 0
			while long < 4:
				var row: int = from + way * long
				if row < 0 or row >= rows or not cells.has(Vector2i(studs, row)) \
						or cells.has(Vector2i(cut, row)) or claimed.has(Vector2i(studs, row)) \
						or claimed.has(Vector2i(cut, row)):
					break
				long += 1
			var named: String = ""
			while long >= 2 and named.is_empty():
				named = str(kinds.get("%d %s %d" % [step[5], step[4], long], ""))
				if named.is_empty():
					long -= 1
			if named.is_empty():
				continue
			var low: int = from if way > 0 else from - long + 1
			var taken: Array[Vector2i] = []
			for n: int in long:
				claimed[Vector2i(studs, low + n)] = true
				claimed[Vector2i(cut, low + n)] = true
				taken.append(Vector2i(studs, low + n))
			var said: PackedStringArray = named.split(" ")
			made.append({"part": said[0], "color": colour, "x": mini(studs, cut), "y": 0.0,
				"z": low, "rot": said[1].to_int(), "_studs": taken, "_side": step[5]})
	return made


## A part laid flat (x along, z deep, a plate's layer up) turned onto its
## side in a blade: its studs looking along the section's x, the flat x
## going out along z and the flat z going up, each stud of it 2.5 plates.
func _on_its_side(flat: Dictionary, side: Dictionary, across: float, name: String) -> Dictionary:
	return {"part": flat["part"], "color": flat["color"], "face": "+x",
		"rot": posmod(int(flat["rot"]) + int(side["turn"]), 4), "x": across,
		"y": side["lift"] + Shapes.PLATES_PER_STUD * float(flat["z"]),
		"z": float(flat["x"]), "section": name}


## A blade's wedge plate moved so the part itself, not its collision cover,
## stands where it is meant to: its face and foot at the corner it names, and
## the side its studs are on ([param studs], 0 the low side along the blade, 1
## the high) flush with that side of its two studs. On its side a wedge's cover
## is pulled in at its cut end by a lattice cell, and the 2 x 2's body is two
## LDU short of two studs at its cut; placed by its cover or its low side, the
## part stood two LDU off the plate beside it, a slit of sky up the inner edge
## of every blade, one a wedge.
func _by_its_body(one: Dictionary, studs: int) -> Dictionary:
	var mesh: Lbm.PartMesh = library.mesh_for(str(one["part"]))
	if mesh == null:
		return one
	var box: AABB = _square_transform(Placement.from_dict(one), mesh) * mesh.bounds
	var z: float = float(one["z"]) * STUD
	var off: float = (z - box.position.z) if studs == 0 else (z + 2.0 * STUD - box.end.z)
	one["x"] = snappedf(float(one["x"]) + (float(one["x"]) * STUD - box.position.x) / STUD, 0.1)
	one["y"] = snappedf(float(one["y"]) + (float(one["y"]) * PLATE - box.position.y) / PLATE,
		0.25)
	one["z"] = snappedf(float(one["z"]) + off / STUD, 0.1)
	return one


## How far up the summit a blade's foot row starts: where the anchors' side
## studs are, less half a stud.
func _blade_lift() -> float:
	var side: Dictionary = _blade_side()
	return float(side.get("lift", 0.0))


## Measured once off the parts, as the side studs a studs_out band hangs its
## dressing on are: for each anchor, the quarter turn that points its side
## studs along +x; where a plate pressed onto them starts across ("face") and
## up ("lift"), for an anchor at x -1 on the summit; and the quarter turn a
## part laid flat is given on its side ("turn"), the one under which a
## plate's own across runs out along z and its deep up the blade.
var _blade_sides: Dictionary = {}


func _blade_side() -> Dictionary:
	if not _blade_sides.is_empty() or library == null:
		return _blade_sides
	var turns: Dictionary = {}
	var face: float = NAN
	var lift: float = NAN
	for anchor: Array in BLADE_ANCHORS:
		var mesh: Lbm.PartMesh = library.mesh_for(str(anchor[1]))
		if mesh == null:
			continue
		for rot: int in 4:
			var trial := Placement.from_dict({"part": anchor[1], "x": -1, "y": 0, "z": 0,
				"rot": rot})
			var placed: Transform3D = _transform(trial, mesh)
			var lowest: Vector3 = Vector3(INF, INF, INF)
			for connector: Lbm.Connector in mesh.connectors:
				if connector.kind == "stud" and connector.gender == "male" \
						and (placed.basis * connector.axis).normalized().dot(Vector3.RIGHT) > 0.9:
					var point: Vector3 = placed * connector.position
					if point.z < lowest.z:
						lowest = point
			if lowest.z == INF:
				continue
			turns[anchor[1]] = rot
			if is_nan(face):
				face = snappedf(lowest.x / STUD, 0.1)
				lift = snappedf((lowest.y - STUD * 0.5) / PLATE, 0.25)
			break
	if is_nan(face):
		return {}
	# The wedge plates two studs across with their studs in one column, by
	# which column, which end of the other their cut fills ("low" nearest
	# the row they start at) and how many rows deep: "0 low 4" -> "41770a 0".
	var wedges: Dictionary = {}
	var shapes: Dictionary = Patterns.wedge_shapes(library)
	for named: String in shapes:
		var shape: Array = shapes[named]
		var columns: Dictionary = {}
		for cell: Vector2i in (shape[2] as Dictionary):
			columns[cell.x] = true
		if int(shape[0]) != 2 or columns.size() != 1 or builder == null:
			continue
		var studs: int = int(columns.keys()[0])
		var said: PackedStringArray = named.split(" ")
		var mesh: Lbm.PartMesh = library.mesh_for(said[0])
		if mesh == null:
			continue
		var at: Transform3D = _square_transform(Placement.from_dict({"part": said[0],
			"x": 0, "y": 0, "z": 0, "rot": said[1].to_int()}), mesh)
		var deep: int = int(shape[1]) * BrickLattice.CELLS_PER_STUD
		var ends := Vector2i.ZERO
		for cell: Vector3i in builder._cells_for(mesh, at):
			if floori(cell.x / float(BrickLattice.CELLS_PER_STUD)) != 1 - studs:
				continue
			if cell.z < BrickLattice.CELLS_PER_STUD / 2:
				ends.x += 1
			elif cell.z >= deep - BrickLattice.CELLS_PER_STUD / 2:
				ends.y += 1
		if ends.x != ends.y:
			wedges["%d %s %d" % [studs, "low" if ends.x > ends.y else "high",
				int(shape[1])]] = named
	# The turn under which a part's own x goes along z, its y along x and
	# its z up: its studs out of the blade's side.
	var onto := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	for turn: int in 4:
		var all: bool = true
		for rot: int in 4:
			if not BrickLattice.basis_for("+x", (rot + turn) % 4).is_equal_approx(
					onto * BrickLattice.basis_for("up", rot)):
				all = false
		if all:
			_blade_sides = {"rot": turns, "face": face, "lift": lift, "turn": turn,
				"wedges": wedges}
			break
	return _blade_sides


## How many courses each ring of a horn's crown is, and the slope its ledges
## are faced with: two studs in for two courses up, 65 degrees.
const HORN_RING := 2
const HORN_SLOPE := "60481a"


## A horn's crown, on its cap [param cells] (the studs on top of it) at
## [param y], over a horn whose middle is [param centre] and which looks
## [param outward] from the tower's middle: rings of bricks stepping in two
## studs at a time towards the cap's outermost 2 x 2, their ledges sloped
## inwards as the rock pattern slopes its own, and on that 2 x 2 a pyramid, a
## cone and a bar. "Gaping horns, their pinnacles sharp as the points of
## spears": four claws opening outwards round the platform. The seventeenth
## Orthanc's horns were flat caps with a point stood in the middle of each,
## and from the front they read as four turrets with roofs; its close pass on
## "horns and summit", the one that would have shaped them, was never made.
## Square parts on square studs, so a design can take it off and build its
## own on the cap.
func _horn_crown(cells: Dictionary, centre: Vector2, outward: Vector2, y: float,
		colour: int) -> Array:
	# The way out, to the nearest eighth of a turn.
	var d := Vector2i(int(signf(outward.x)) if absf(outward.x) > 0.4 else 0,
		int(signf(outward.y)) if absf(outward.y) > 0.4 else 0)
	if d == Vector2i.ZERO:
		return []
	# The 2 x 2 furthest out, nearest the horn's line where two tie.
	var tip := Vector2i.ZERO
	var best: float = -INF
	for key: Variant in cells:
		var corner: Vector2i = key
		if not (cells.has(corner + Vector2i(1, 0)) and cells.has(corner + Vector2i(0, 1))
				and cells.has(corner + Vector2i(1, 1))):
			continue
		var middle := Vector2(corner.x + 1.0, corner.y + 1.0)
		var score: float = (middle - centre).dot(Vector2(d).normalized()) \
			- 0.01 * absf((middle - centre).cross(Vector2(d).normalized()))
		if score > best + 0.0001:
			best = score
			tip = corner
	if best == -INF:
		return []
	# How many courses in from the tip each stud is: two studs a course, in
	# from the tip along the way out and across it.
	var tip_middle := Vector2(tip.x + 1.0, tip.y + 1.0)
	var level := func(cell: Vector2i) -> int:
		if cell.x >= tip.x and cell.x <= tip.x + 1 and cell.y >= tip.y and cell.y <= tip.y + 1:
			return 0
		var off: Vector2 = Vector2(cell.x + 0.5, cell.y + 0.5) - tip_middle
		var inward: float = 0.0
		if d.x != 0 and d.y != 0:
			inward = maxf(-off.x * d.x, -off.y * d.y)
		elif d.x != 0:
			inward = maxf(-off.x * d.x, absf(off.y))
		else:
			inward = maxf(-off.y * d.y, absf(off.x))
		return maxi(1, int(ceil((inward - 0.5) / 2.0 - 0.001)))
	var deepest: int = 0
	for key: Variant in cells:
		deepest = maxi(deepest, level.call(key))
	# The cap, then rings two courses tall, each two studs smaller, the last
	# the tip's 2 x 2: two studs in for two courses up is the 65 degree slope
	# a ledge is faced with. One course a ring was 31 degrees, a roof.
	var steps: Array = [cells]
	for k: int in range(deepest - 1, -1, -1):
		var course: Dictionary = {}
		for key: Variant in cells:
			if level.call(key) <= k:
				course[key] = true
		for _twice: int in HORN_RING:
			steps.append(course)
	var made: Array = []
	var below: Dictionary = {}
	for k: int in range(1, steps.size()):
		var laid: Dictionary = {}
		made.append_array(Patterns._tile((steps[k] as Dictionary).duplicate(),
			y + 3.0 * (k - 1), colour, Patterns.COURSES, below, laid, k))
		below = laid
	made.append_array(Patterns._face_steps(steps, y - 3.0, colour, -1, 0.0, false,
		HORN_SLOPE))
	var at: float = y + 3.0 * (steps.size() - 1)
	made.append({"part": "3688", "color": colour, "x": tip.x, "y": at, "z": tip.y, "rot": 0})
	at += 6.0
	# The pyramid's one stud is at its middle, half a stud off the grid.
	made.append({"part": "59900", "color": colour, "x": tip.x + 0.5, "y": at,
		"z": tip.y + 0.5, "rot": 0})
	at += 3.0
	# A bar has no studs, so it is placed by its cover: 8 LDU across.
	made.append({"part": "30374", "color": colour, "x": tip.x + 0.8, "y": at,
		"z": tip.y + 0.8, "rot": 0})
	return made


## One face of a shaft of a cluster, in a section of its own: laid where it
## is clear of [param against], dressed where its dressing is clear of
## [param dressed] and of the faces either side, and its outside row run on
## past its right-hand end into the groove at the corner. Without that a
## two-thick face of a pier five studs out is three studs wide with a groove
## nearly as wide at each corner, and the first cluster built read as a
## bundle of separate sticks rather than four faceted piers. Returns the runs
## it laid, each [left, studs, how far the outside row ran on], or [].
func _cluster_face(made: Array, model: Model, name: String, origin: Vector2,
		degrees: float, radius: float, sides: int, spec: Dictionary,
		against: Array, dressed: Array, base: float, courses: int,
		windowed: bool = false, door: float = NAN) -> Array:
	var thick: int = spec["thick"]
	var runs: Array = _runs(origin, degrees, radius, thick, sides, against)
	if runs.is_empty():
		return []
	var half: float = floor(2.0 * (radius - thick) * tan(PI / sides) + 0.001) / 2.0
	var step: float = 360.0 / sides
	var beside: Array = [
		_face_slab(origin, degrees - step, -half, half, radius - thick, radius),
		_face_slab(origin, degrees + step, -half, half, radius - thick, radius)]
	# As far as the corner of the outline and no further, so the face's line
	# is carried round to the next one's without a fin standing proud of it.
	var corner: float = radius * tan(PI / sides) + 0.05
	for run: Array in runs:
		var end: float = float(run[0]) + int(run[1])
		var extra: int = 0
		if bool(run[2]):
			for more: int in [2, 1]:
				if end + more > corner:
					continue
				var reach: PackedVector2Array = _face_slab(origin, degrees, end,
					end + more + CLUSTER_CLEAR, radius - 1.0 - CLUSTER_CLEAR,
					radius + CLUSTER_CLEAR)
				var fits: bool = not _convex_meet(reach, beside[1])
				for shape: PackedVector2Array in against:
					fits = fits and not _convex_meet(reach, shape)
				if fits:
					extra = more
					break
		run[2] = extra
	if not model.sections.has(name):
		model.sections[name] = Section.from_dict({"name": name, "x": origin.x,
			"y": spec["y"], "z": origin.y, "axis": "y", "degrees": degrees})
	# Narrow lit windows, two courses tall, every WINDOW_EVERY courses up the
	# face, alternate faces half a storey apart: Orthanc's faces have them,
	# and the sixteenth, whose dressing is now black on black, had none.
	# Asked for, they are few: every other face, a storey apart.
	var windows: Dictionary = {}
	if windowed and bool(spec.get("windows", false)) and absi(name.hash()) % 2 == 0:
		var first: int = 4 + (WINDOW_EVERY / 2 if absi(name.hash() / 2) % 2 == 1 else 0)
		# Over a door, the first a storey above its arch.
		if not is_nan(door):
			first = DOOR_BELOW + DOOR_ARCH_COURSES + WINDOW_EVERY / 2
		for course: int in range(first, courses - 2, WINDOW_EVERY):
			windows[course] = true
			windows[course + 1] = true
	_lay_face(made, name, spec, runs, radius, base, courses,
		_dressing_clear.bind(origin, degrees, radius, dressed + beside), windows,
		door if runs.size() == 1 and courses > DOOR_BELOW + DOOR_ARCH_COURSES else NAN)
	return runs


## A rectangle in a face's own frame, x0..x1 along it and z0..z1 out from
## [param origin], as an outline in plan.
static func _face_slab(origin: Vector2, degrees: float, x0: float, x1: float,
		z0: float, z1: float) -> PackedVector2Array:
	var along := Vector2(cos(deg_to_rad(degrees)), -sin(deg_to_rad(degrees)))
	var out: Vector2 = _towards(degrees)
	return PackedVector2Array([origin + along * x0 + out * z0,
		origin + along * x1 + out * z0, origin + along * x1 + out * z1,
		origin + along * x0 + out * z1])


## Which way an angle about +y looks, in plan (x, z): 0 is +z, 90 is +x.
static func _towards(degrees: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees)))


## A prism's outline in plan, in studs: its corners going round, for faces
## [param apothem] out from [param middle], the first looking [param turn]
## degrees round from +z.
static func _outline(middle: Vector2, sides: int, apothem: float,
		turn: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var out: float = apothem / cos(PI / sides)
	for k: int in sides:
		corners.append(middle + _towards(turn + 360.0 * (k + 0.5) / sides) * out)
	return corners


## Whether two convex outlines overlap, by their separating edges.
static func _convex_meet(one: PackedVector2Array, two: PackedVector2Array) -> bool:
	for shape: PackedVector2Array in [one, two]:
		for k: int in shape.size():
			var edge: Vector2 = shape[(k + 1) % shape.size()] - shape[k]
			var axis := Vector2(-edge.y, edge.x)
			var a := Vector2(INF, -INF)
			var b := Vector2(INF, -INF)
			for point: Vector2 in one:
				a = Vector2(minf(a.x, point.dot(axis)), maxf(a.y, point.dot(axis)))
			for point: Vector2 in two:
				b = Vector2(minf(b.x, point.dot(axis)), maxf(b.y, point.dot(axis)))
			if a.y <= b.x or b.y <= a.x:
				return false
	return true


## Whether every corner of one outline is inside another.
static func _inside_of(shape: PackedVector2Array, within: PackedVector2Array) -> bool:
	for point: Vector2 in shape:
		if not Geometry2D.is_point_in_polygon(point, within):
			return false
	return true


## The runs a face is laid in, each [left, studs, whether it ends at the
## face's right-hand corner rather than at something] along its own frame: the
## whole face as a prism lays it, less wherever one of [param against]
## (outlines in plan) crosses its wall. A run that ends at something is laid
## up against it on the lattice's tenth-of-a-stud grid, so the groove left
## there is as narrow as the bricks allow; one that meets things at both ends
## is centred between them.
static func _runs(origin: Vector2, degrees: float, radius: float, thick: int,
		sides: int, against: Array) -> Array:
	var free: Array = _free(origin, degrees, radius, thick, sides, against)
	if free.size() == 1 and not bool(free[0][2]) and not bool(free[0][3]):
		var width: int = int(floor(2.0 * (radius - thick) * tan(PI / sides) + 0.001))
		return [[-width / 2.0, width, true]]
	var runs: Array = []
	for one: Array in free:
		var a: float = one[0]
		var b: float = one[1]
		var width: int = int(floor(b - a + 0.001))
		var lo: float = ceil(a * 10.0 - 0.001) / 10.0
		var hi: float = floor((b - width) * 10.0 + 0.001) / 10.0
		while width > 0 and lo > hi + 0.001:
			width -= 1
			hi = floor((b - width) * 10.0 + 0.001) / 10.0
		if width < 1:
			continue
		var left: float = snappedf((lo + hi) / 2.0, 0.1)
		if bool(one[2]) and not bool(one[3]):
			left = lo
		elif bool(one[3]) and not bool(one[2]):
			left = hi
		runs.append([clampf(left, lo, hi), width, not bool(one[3])])
	return runs


## The stretches of a face's wall clear of [param against], each [from, to,
## whether something is at the start, whether something is at the end] in the
## face's own frame; a face nothing crosses is one stretch, corner to corner.
static func _free(origin: Vector2, degrees: float, radius: float, thick: int,
		sides: int, against: Array) -> Array:
	var half: float = (radius - thick) * tan(PI / sides)
	var spans: Array = []
	for shape: PackedVector2Array in against:
		var span: Array = _span_in_face(shape, origin, degrees, radius - thick, radius)
		if not span.is_empty() and span[1] > -half and span[0] < half:
			spans.append(span)
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var free: Array = []
	var at: float = -half
	var met: bool = false
	for span: Array in spans:
		if float(span[0]) > at:
			free.append([at, float(span[0]), met, true])
		if float(span[1]) > at:
			at = span[1]
			met = true
	if at < half:
		free.append([at, half, met, false])
	return free


## The span of x in a face's own frame that an outline covers within the
## face's wall, z0 to z1 out from its middle, or [] where it does not reach.
static func _span_in_face(shape: PackedVector2Array, origin: Vector2,
		degrees: float, z0: float, z1: float) -> Array:
	var along := Vector2(cos(deg_to_rad(degrees)), -sin(deg_to_rad(degrees)))
	var out: Vector2 = _towards(degrees)
	var local := PackedVector2Array()
	for point: Vector2 in shape:
		local.append(Vector2((point - origin).dot(along), (point - origin).dot(out)))
	local = _clipped(_clipped(local, z0, true), z1, false)
	if local.is_empty():
		return []
	var span: Array = [INF, -INF]
	for point: Vector2 in local:
		span[0] = minf(span[0], point.x)
		span[1] = maxf(span[1], point.x)
	return span


## An outline cut at y = [param edge], keeping what is above it or below.
static func _clipped(shape: PackedVector2Array, edge: float,
		above: bool) -> PackedVector2Array:
	var kept := PackedVector2Array()
	for k: int in shape.size():
		var a: Vector2 = shape[k]
		var b: Vector2 = shape[(k + 1) % shape.size()]
		var a_in: bool = a.y >= edge if above else a.y <= edge
		var b_in: bool = b.y >= edge if above else b.y <= edge
		if a_in:
			kept.append(a)
		if a_in != b_in:
			kept.append(a.lerp(b, (edge - a.y) / (b.y - a.y)))
	return kept


## Whether the dressing a brick of a face's outside row would carry, a plate's
## thickness and a little out from the face, is clear of [param against].
## Dressing gives way in the check anyway; a cluster is laid so it need not.
static func _dressing_clear(x: float, long: int, origin: Vector2,
		degrees: float, radius: float, against: Array) -> bool:
	var patch: PackedVector2Array = _face_slab(origin, degrees, x - 0.1,
		x + long + 0.1, radius, radius + 0.6)
	for shape: PackedVector2Array in against:
		if _convex_meet(patch, shape):
			return false
	return true


## The plates a summit is laid in, each [across, deep, part, turn]: strips
## along z for its first layer, along x for its second.
const SUMMIT_ALONG_Z: Array = [[2, 6, "3795", 1], [2, 4, "3020", 1], [2, 3, "3021", 1],
	[2, 2, "3022", 0], [1, 4, "3710", 1], [1, 3, "3623", 1], [1, 2, "3023", 1],
	[1, 1, "3024", 0]]
const SUMMIT_ALONG_X: Array = [[6, 2, "3795", 0], [4, 2, "3020", 0], [3, 2, "3021", 0],
	[2, 2, "3022", 0], [4, 1, "3710", 0], [3, 1, "3623", 0], [2, 1, "3023", 0],
	[1, 1, "3024", 0]]


## The studs a summit's plate covers, from its part, turn and corner.
static func _plate_studs(plate: Dictionary) -> Array[Vector2i]:
	var size := Vector2i.ZERO
	for one: Array in SUMMIT_ALONG_Z + SUMMIT_ALONG_X:
		if str(one[2]) == str(plate["part"]) and int(one[3]) == int(plate["rot"]):
			size = Vector2i(one[0], one[1])
			break
	var studs: Array[Vector2i] = []
	for dx: int in size.x:
		for dz: int in size.y:
			studs.append(Vector2i(int(plate["x"]) + dx, int(plate["z"]) + dz))
	return studs


## Two layers of plates over [param cells]: strips along z, then strips
## along x across them, so each plate crosses several of the other layer
## and the whole floor holds wherever its edge rests.
##
## The second layer's joints are kept off the first's wherever a strip's
## length allows (`_summit_across`). Without that both layers could break
## round the same block, tying it to nothing, and only the largest piece is
## kept: the eighteenth Orthanc's summit lost a 6 x 6 block from its middle,
## six-long strips both ways over a block six by six, where its figures were to
## stand ("nothing to stand on"), and the run laid a plate over the hole by
## hand.
static func _summit(cells: Dictionary, y: float, colour: int, crumbs: int = 0) -> Array:
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or a.x == b.x and a.y < b.y)
	var first: Dictionary = {}
	for cell: Vector2i in ordered:
		first[cell] = true
	var laid: Dictionary = {}
	var made: Array = Patterns._tile(first, y, colour, SUMMIT_ALONG_Z, {}, laid)
	var below: Dictionary = {}
	for n: int in made.size():
		for cell: Vector2i in _plate_studs(made[n]):
			below[cell] = n
	made.append_array(_summit_across(cells, below, y + 1.0, colour))
	# The two layers are one floor only where they cross. A corner of the
	# outline a stud across is a 1x1 plate on a 1x1 plate, held by nothing,
	# and the first open cluster had one hanging over its open back. The
	# largest piece is the summit; anything apart from it is left off —
	# unless [param crumbs] is said, when only pieces of that many plates
	# or fewer are: a ledge round a storey is a ring, and where it crosses
	# a cleft on a diagonal its studs meet only at their corners, so it
	# comes in several pieces, each standing on the walls under it. Keeping
	# only the largest dropped the ledge under a whole pier of the storey
	# above; keeping every piece kept crumbs of four plates on a diagonal,
	# over the air inside the wall.
	var under: Dictionary = {}
	var over: Dictionary = {}
	for n: int in made.size():
		var plate: Dictionary = made[n]
		for cell: Vector2i in _plate_studs(plate):
			if is_equal_approx(float(plate["y"]), y):
				under[cell] = n
			else:
				over[cell] = n
	var links: Dictionary = {}
	for cell: Vector2i in over:
		if under.has(cell):
			for pair: Array in [[under[cell], over[cell]], [over[cell], under[cell]]]:
				if not links.has(pair[0]):
					links[pair[0]] = {}
				(links[pair[0]] as Dictionary)[pair[1]] = true
	var seen: Dictionary = {}
	var largest: Dictionary = {}
	var pieces: Dictionary = {}     ## plate -> the first plate of its piece
	var sizes: Dictionary = {}      ## that first plate -> how many in the piece
	for start: int in made.size():
		if seen.has(start):
			continue
		var piece: Dictionary = {start: true}
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			for next: Variant in (links.get(queue.pop_back(), {}) as Dictionary):
				if not seen.has(next):
					seen[next] = true
					piece[next] = true
					queue.append(next)
		if piece.size() > largest.size():
			largest = piece
		sizes[start] = piece.size()
		for n: Variant in piece:
			pieces[n] = start
	var kept: Array = []
	for n: int in made.size():
		if largest.has(n) or crumbs > 0 and int(sizes[pieces[n]]) > crumbs:
			kept.append(made[n])
	return kept


## A summit's second layer over [param cells] at [param y]: strips along x,
## two studs deep where both rows have studs and one where only one does,
## each laid from its left end in plates of six, four, three, two or one, the
## longest whose right end is not over a joint of the first layer
## ([param below]: stud -> the first layer's plate) unless the strip ends
## there. Every block the first layer bounds is then crossed by a plate of the
## second.
const SUMMIT_ACROSS := {2: {6: ["3795", 0], 4: ["3020", 0], 3: ["3021", 0],
	2: ["3022", 0], 1: ["3023", 1]}, 1: {4: ["3710", 0], 3: ["3623", 0],
	2: ["3023", 0], 1: ["3024", 0]}}


static func _summit_across(cells: Dictionary, below: Dictionary, y: float,
		colour: int) -> Array:
	var made: Array = []
	var left: Dictionary = cells.duplicate()
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for key: Variant in cells:
		var cell: Vector2i = key
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	for z: int in range(low.y, high.y + 1, 2):
		for deep: int in [2, 1]:
			for row: int in ([z] if deep == 2 else [z, z + 1]):
				var free := func(at: int) -> bool:
					for dz: int in deep:
						if not left.has(Vector2i(at, row + dz)):
							return false
					return true
				var x: int = low.x
				while x <= high.x:
					if not free.call(x):
						x += 1
						continue
					var end: int = x
					while end <= high.x and free.call(end):
						end += 1
					var at: int = x
					while at < end:
						var chosen: int = 0
						for long: int in (SUMMIT_ACROSS[deep] as Dictionary).keys():
							var stop: int = at + long
							if stop > end:
								continue
							var joint: bool = false
							for dz: int in deep:
								joint = joint or below.get(Vector2i(stop - 1, row + dz), -1) \
									!= below.get(Vector2i(stop, row + dz), -2)
							if stop == end or not joint:
								chosen = long
								break
						if chosen == 0:
							for long: int in (SUMMIT_ACROSS[deep] as Dictionary).keys():
								if at + long <= end:
									chosen = long
									break
						var part: Array = SUMMIT_ACROSS[deep][chosen]
						made.append({"part": part[0], "color": colour, "x": at, "y": y,
							"z": row, "rot": part[1]})
						for dx: int in chosen:
							for dz: int in deep:
								left.erase(Vector2i(at + dx, row + dz))
						at += chosen
					x = end
	return made


## A face of studs turned outward, dressed with tiles, round tiles,
## round plates and cheese slopes on their sides: the commonest way real
## sets put something other than a stud on a wall, said in one object.
##
## Real fantasy sets build a median 19% of their parts on their side.
## Every design built here built none, though the check said so: a part
## on a sideways stud sits at one and three quarter plates up and a
## fraction of a stud out, and nobody gets that right by reasoning. So
## the arithmetic is done here, from the parts' own connectors — the same
## measurement attachment_points makes — and never from a guess.
##
## Courses of 87087 (a 1x1 brick with a stud on one side), each tied to
## the next by a course of plates staggered across the joints, every side
## stud facing the way asked and carrying a 1x1 part laid on it.
##
##   {"pattern": "studs_out", "at": {"x": 0, "y": 0, "z": 0}, "length": 8,
##    "courses": 4, "facing": "+z", "color": 0}
func _studs_out(pattern: Dictionary, trouble: Array) -> Array:
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var x0: float = float(at.get("x", 0.0))
	var y0: float = float(at.get("y", 0.0))
	var z0: float = float(at.get("z", 0.0))
	var length: int = int(round(float(pattern.get("length", 0))))
	var courses: int = int(round(float(pattern.get("courses", 3))))
	var facing: String = str(pattern.get("facing", "+z")).to_lower()
	var colour: int = int(pattern.get("color", pattern.get("colour", DEFAULT_COLOUR)))
	var face_colour: int = int(pattern.get("face_color",
		pattern.get("face_colour", colour)))
	var mix_colour: int = int(pattern.get("mix_color",
		pattern.get("mix_colour", -1)))
	if length < 1 or courses < 1 or length * courses > 1000:
		trouble.append("studs_out wants length and courses of at least 1, "
			+ "and not more than 1000 studs of face between them")
		return []
	if not facing in ["+x", "-x", "+z", "-z"]:
		trouble.append("studs_out faces +x, -x, +z or -z")
		return []
	if _side_stud(facing).is_empty():
		trouble.append("the 1x1 brick with a side stud has not arrived yet")
		return []
	# What each stud carries: a mix by default, or one kind for a band of
	# detail — rivets down a hull plate, round tiles for portholes or lights
	# (in a transparent face_color), flat tiles for a smooth panel.
	var dress: String = str(pattern.get("dress", "mixed")).to_lower()
	var only: Array = DRESSES.get(dress, [])
	if dress != "mixed" and not DRESSES.has(dress):
		trouble.append("studs_out dresses its studs mixed, tiles, rivets, round "
			+ "or lights")
		return []
	var along_x: bool = facing in ["+z", "-z"]
	var made: Array = []
	for course: int in courses:
		var y: float = y0 + 4.0 * course
		for n: int in length:
			var x: float = x0 + (n if along_x else 0)
			var z: float = z0 + (0 if along_x else n)
			var one := {"part": "87087", "color": colour, "x": x, "y": y,
				"z": z, "rot": 0}
			var tone: int = face_colour
			if mix_colour >= 0 and Patterns._scatter(x, y, z, 29) < 0.3:
				tone = mix_colour
			var dressing: Dictionary = _dress(one, facing, tone, only)
			made.append(one)
			if not dressing.is_empty():
				made.append(dressing)
		# The course above is tied across the joints of this one.
		var tie_y: float = y + 3.0
		var start: int = 0 if course % 2 == 0 else 1
		var plates: Array = [[4, "3710"], [3, "3623"], [2, "3023"], [1, "3024"]]
		var n2: int = 0
		if start == 1:
			made.append(_tie(x0, tie_y, z0, 0, 1, "3024", colour, along_x))
			n2 = 1
		while n2 < length:
			for pair: Array in plates:
				if n2 + int(pair[0]) <= length:
					made.append(_tie(x0, tie_y, z0, n2, int(pair[0]),
						str(pair[1]), colour, along_x))
					n2 += int(pair[0])
					break
	return made


## The tile a row of side studs carries, by how many: two studs tall, so
## that laid on a course of them it covers the course over it too.
const PANELS: Dictionary = {4: "87079", 2: "3068b", 1: "3069b"}

## A brick with studs on one side, turned so they point [param facing],
## and a tile two studs tall laid on them flat against the side — its lower
## row on the studs, its upper over the course above. The brick's rot is
## set; the tile comes back as a placement, {} where none fits.
##
## A side of a shape laid in plain bricks is a face of studs-down plastic
## nobody sees; real vehicles turn a fifth of their parts on their side, and
## a car's flank is tiles on bricks like these.
func _panel(brick: Dictionary, facing: String) -> Dictionary:
	if not facing in ["+x", "-x", "+z", "-z"]:
		return {}
	var part: String = str(brick["part"])
	var mesh: Lbm.PartMesh = library.mesh_for(part)
	if mesh == null:
		return {}
	var outward: Vector3 = FACES[facing]
	var studs: Array[Vector3] = []
	for rot: int in 4:
		var trial: Dictionary = brick.duplicate()
		trial["rot"] = rot
		var placed: Transform3D = _transform(Placement.from_dict(trial), mesh)
		var found: Array[Vector3] = []
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and (placed.basis * connector.axis).normalized().dot(outward) > 0.9:
				found.append(placed * connector.position)
		if not found.is_empty():
			brick["rot"] = rot
			studs = found
			break
	if studs.is_empty() or not PANELS.has(studs.size()):
		return {}
	var id: String = PANELS[studs.size()]
	var tile: Lbm.PartMesh = library.mesh_for(id)
	var info: PartLibrary.PartInfo = library.parts.get(id)
	if tile == null or info == null:
		return {}
	# Where each stud of the tile's footprint is on its underside, in its own
	# coordinates: the side studs go into these.
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = tile.bounds
	var under: Array[Vector3] = []
	for i: int in foot.x:
		for k: int in foot.y:
			under.append(Vector3(b.position.x + 10.0 + 20.0 * i, b.position.y,
				b.position.z + 10.0 + 20.0 * k))
	var lowest: float = INF
	for point: Vector3 in studs:
		lowest = minf(lowest, point.y)
	for rot: int in 4:
		var basis: Basis = BrickLattice.basis_for(facing, rot)
		var turned: Array[Vector3] = []
		for point: Vector3 in under:
			turned.append(basis * point)
		for first: Vector3 in turned:
			var origin: Vector3 = studs[0] - first
			var all_on: bool = true
			for point: Vector3 in studs:
				var on: bool = false
				for other: Vector3 in turned:
					if (origin + other - point).length() < 1.0:
						on = true
						break
				if not on:
					all_on = false
					break
			if not all_on:
				continue
			# Upwards from the studs, over the course above, never below them.
			var up: bool = false
			var down: bool = false
			for other: Vector3 in turned:
				var y: float = (origin + other).y
				up = up or y > lowest + 10.0
				down = down or y < lowest - 10.0
			if not up or down:
				continue
			var corner: Vector3 = origin + BrickLattice.to_ldu(_corner_cell(tile, id, basis))
			return {"part": id, "color": int(brick.get("panel_color", brick.get("color", DEFAULT_COLOUR))),
				"x": snappedf(corner.x / STUD, 0.1), "y": snappedf(corner.y / PLATE, 0.25),
				"z": snappedf(corner.z / STUD, 0.1), "face": facing, "rot": rot,
				"dressing": true}
	return {}


## The parts a studs_out band's studs carry, by the kind of band asked.
const DRESSES: Dictionary = {"tiles": ["3070b"], "rivets": ["4073"],
	"round": ["98138"], "lights": ["98138"]}


func _tie(x0: float, y: float, z0: float, from: int, _long: int,
		part: String, colour: int, along_x: bool) -> Dictionary:
	return {"part": part, "color": colour,
		"x": x0 + (from if along_x else 0), "y": y,
		"z": z0 + (0 if along_x else from), "rot": 0 if along_x else 1}


## Which turn of 87087 points its side stud the way asked, and that
## stud, measured on a trial brick once per way: [turn, connector], or
## [] when the part has not arrived.
var _side_studs: Dictionary = {}


func _side_stud(facing: String) -> Array:
	if _side_studs.has(facing):
		return _side_studs[facing]
	var brick: Lbm.PartMesh = library.mesh_for("87087")
	if brick == null:
		return []
	var outward: Vector3 = FACES[facing]
	for rot: int in 4:
		var trial := Placement.from_dict({"part": "87087", "color": 0,
			"x": 0, "y": 0, "z": 0, "rot": rot})
		var placed: Transform3D = _transform(trial, brick)
		for connector: Lbm.Connector in brick.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			if (placed.basis * connector.axis).normalized().dot(outward) > 0.9:
				_side_studs[facing] = [rot, connector]
				return _side_studs[facing]
	return []


## Turn a 1x1 brick with a side stud (87087) to face the way asked, and
## return the part laid on its stud: a tile, round tile, round plate or
## cheese slope, chosen by where it is. {} when it cannot be worked out.
func _dress(brick: Dictionary, facing: String, tone: int = -1,
		only: Array = []) -> Dictionary:
	if not facing in ["+x", "-x", "+z", "-z"]:
		return {}
	var side: Array = _side_stud(facing)
	var mesh: Lbm.PartMesh = library.mesh_for("87087")
	if side.is_empty() or mesh == null:
		return {}
	brick["rot"] = int(side[0])
	var connector: Lbm.Connector = side[1]
	var placed: Transform3D = _transform(Placement.from_dict(brick), mesh)
	var point: Vector3 = placed * connector.position
	var axis: Vector3 = (placed.basis * connector.axis).normalized()
	var corner: Vector3 = _corner_on(point, axis, facing)
	var faces: Array = ["3070b", "98138", "4073", "54200", "3024"]
	if facing in ["-x", "-z"]:
		# Thicker than a plate hangs the other way on these sides.
		faces = ["3070b", "98138", "4073", "3024"]
	if not only.is_empty():
		faces = only
	var x: float = float(brick["x"])
	var y: float = float(brick["y"])
	var z: float = float(brick["z"])
	var part: String = faces[int(Patterns._scatter(x, y, z, 23) * faces.size()) % faces.size()]
	return {"part": part, "color": tone if tone >= 0 else int(brick.get("color", DEFAULT_COLOUR)),
		"x": snappedf(corner.x / STUD, 0.1), "y": snappedf(corner.y / PLATE, 0.25),
		"z": snappedf(corner.z / STUD, 0.1), "face": facing, "rot": 0,
		"dressing": true}


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
		# The sides on the assembly itself, as the schema has them, or in
		# a where= of their own, the way look_at_model and view_model take
		# a box: easy to send by habit, and read as no box at all — the
		# whole model — when it was ignored.
		var given: Dictionary = one
		if one.get("where") is Dictionary:
			given = one["where"]
		var where: Dictionary = {}
		for side: String in ["x_from", "x_to", "y_from", "y_to",
				"z_from", "z_to"]:
			if given.has(side):
				where[side] = float(given[side])
		out.append({"name": name, "where": where})
	return out


## The features a design listed, each a few words: "eyes", "ear tufts",
## "wheel arches". Duplicates and blanks dropped, at most MOST_FEATURES.
static func _read_features(args: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var given: Variant = args.get("features", [])
	if not given is Array:
		return out
	for raw: Variant in given:
		var name: String = str((raw as Dictionary).get("name", "")) if raw is Dictionary \
			else str(raw)
		name = name.strip_edges()
		if name.is_empty() or seen.has(name.to_lower()):
			continue
		seen[name.to_lower()] = true
		out.append(name)
		if out.size() >= MOST_FEATURES:
			break
	return out


## The features as the detail passes take them, before the assemblies: each
## {name, where, feature}, where the whole model.
static func _queue_features(named: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name: String in named:
		out.append({"name": name, "where": {}, "feature": true})
	return out


## What was used for each feature, by its name in lower case: the pieces
## laid, the techniques looked at, the edits. Said as the run ends and in a
## session's reviews, so "which did it use" is a record and not a guess.
var _feature_used: Dictionary = {}
## The feature being worked now, in the loop or by a session from outside
## (the last review_model feature=), or "".
var _feature_now: String = ""
## The features a session from outside listed when it submitted.
var _outside_features: Array[String] = []
## The app's own feature pass: a real piece laid per feature, settled by
## the design (FeaturePass). Set when settle_feature ends a feature's turn
## in the loop.
var _feature_pass: FeaturePass = null
var _feature_closed: bool = false


func feature_pass() -> FeaturePass:
	if _feature_pass == null:
		_feature_pass = FeaturePass.new(self)
	return _feature_pass


## [param text] ahead of [param more], a String or the blocks of an answer
## with a picture: blocks when there is a picture to keep.
static func _joined(text: String, more: Variant) -> Variant:
	if text.is_empty():
		return more
	if more is Array:
		var out: Array = (more as Array).duplicate()
		if not out.is_empty() and out[0] is Dictionary \
				and str((out[0] as Dictionary).get("type", "")) == "text":
			out[0] = {"type": "text", "text": "%s\n\n%s" % [text, (out[0] as Dictionary)["text"]]}
		else:
			out.push_front({"type": "text", "text": text})
		return out
	var after: String = str(more)
	return text if after.is_empty() else "%s\n\n%s" % [text, after]


## The listed feature the words of [param query] name, or "": "owl eye"
## is the eyes, "car nose" none of eyes and beak.
func _feature_named(query: String) -> String:
	var asked: PackedStringArray = RealSnippets.words(query)
	for name: String in (_features if not _features.is_empty() else _outside_features):
		for word: String in RealSnippets.words(name):
			if asked.has(word):
				return name
	return ""


## Note what a tool did for the feature being worked on.
func _note_feature(what: String) -> void:
	if _feature_now.is_empty():
		return
	var key: String = _feature_now.to_lower()
	var used: Array = _feature_used.get(key, [])
	if not used.has(what):
		used.append(what)
		if not what.begins_with("looked up"):
			progress.emit("the %s: %s" % [_feature_now, what])
	_feature_used[key] = used


## A feature's record in a line: "real piece 4349-3 laid", "built by hand
## after show_technique eye with a highlight", or "not worked yet".
func _feature_said(name: String) -> String:
	var settled: String = feature_pass().said(name)
	if not settled.is_empty():
		return settled
	var proposed: FeaturePass.Proposal = feature_pass().proposal(name)
	if proposed != null and not proposed.piece.is_empty():
		return "real piece %s laid by the app, not settled yet" % proposed.piece["id"]
	var used: Array = _feature_used.get(name.to_lower(), [])
	if used.is_empty():
		return "not worked yet"
	var placed := PackedStringArray()
	var looked := PackedStringArray()
	var built: bool = false
	for raw: Variant in used:
		var one: String = str(raw)
		if one.begins_with("placed "):
			placed.append(one.trim_prefix("placed "))
		elif one.begins_with("technique "):
			looked.append(one.trim_prefix("technique "))
		elif one == "edited":
			built = true
	if not placed.is_empty():
		return "real piece %s laid%s" % [", ".join(placed), ", then adapted" if built else ""]
	if built and not looked.is_empty():
		return "built from the worked technique %s" % ", ".join(looked)
	if built:
		return "built by hand"
	return "looked up, nothing laid yet"


## The features listed and what each came to, in a line each.
func _features_record(names: Array[String]) -> String:
	var said := PackedStringArray()
	for name: String in names:
		said.append("  %s: %s" % [name, _feature_said(name)])
	return "\n".join(said)


## The subject's own words in [param text] that the real-set index knows
## as subjects (owl, car, castle), so a feature is looked up among sets
## about it first. "A barn owl as a detailed LEGO display model" is "owl".
static func _subject_words(text: String) -> String:
	var kept := PackedStringArray()
	for word: String in RealSnippets.words(text):
		if RealSnippets.is_subject(word) and not kept.has(word):
			kept.append(word)
	return " ".join(kept)


## One feature, handed to the design to work: the app looks up how real
## sets built it, lays the best piece that lays whole and fits where the
## feature goes (FeaturePass), and hands it over with a picture of it
## standing there, to accept, adjust or reject with settle_feature. When
## nothing fits, the pieces it tried and the worked technique, to build it.
## [param picture] adds the picture where one can be taken.
func _feature_brief(name: String, of: int, count: int, picture: bool) -> Variant:
	var said := PackedStringArray()
	said.append("The %s — feature %d of %d." % [name, of, count])
	var one: FeaturePass.Proposal = null
	if await RealSnippets.ensure(self):
		one = await feature_pass().propose(name)
	var worked: Dictionary = Techniques.for_feature(name)
	var technique: String = ("show_technique(\"%s\") — %s" % [worked["name"], worked["when"]]) \
		if not worked.is_empty() else ""
	if one != null and not one.piece.is_empty():
		said.append(_proposal_said(one))
	else:
		var tried: String = ""
		if one != null and not one.candidates.is_empty():
			var ids := PackedStringArray()
			for entry: Variant in one.candidates:
				ids.append(str((entry as Dictionary)["id"]))
			tried = " (tried %s)" % ", ".join(ids)
		said.append(("No real set's piece that lays whole fits where it goes%s, so build it "
			% tried) + ("from the worked technique, %s" % technique if not technique.is_empty()
				else "your own way") + ", then settle_feature \"built\" with how; or "
			+ "\"reject\" with a reason if the model has it already.")
		return "\n".join(said)
	if not technique.is_empty():
		said.append("To build it your own way instead: %s." % technique)
	said.append(SETTLE_HOW.replace("{name}", name))
	var text: String = "\n".join(said)
	if not picture:
		return text
	var shown: Dictionary = await _proposal_picture(one)
	if shown.is_empty():
		return text
	return [{"type": "text", "text": text}, shown]


const SETTLE_HOW := """Settle it with settle_feature {"feature": "{name}", \
"verdict": ...}: "accept" keeps it (with move {dx, dy, dz} in studs and \
plates, turn or recolor {"15": 1} to adjust it first); "next" takes it off \
and lays the next-best piece; "reject" with a reason takes it off, to build \
it your own way or leave it out; "built" if you built it yourself (the \
app's piece comes off). A \
feature is parts with depth, never a tile painted on a panel. Saving waits \
until every feature is settled."""


## The piece the app laid for a feature, in a few lines: what it is and
## whose, where it went and how, the bricks it is, and the next-best.
func _proposal_said(one: FeaturePass.Proposal) -> String:
	var entry: Dictionary = one.piece
	var copy: Dictionary = one.copies[0]
	var at: Vector3 = copy.get("at", Vector3.ZERO)
	var how: String = "as built, its front to %s" % one.spot["facing"] \
		if str(copy["up"]) == "up" else "tipped whole, studs out to %s" % copy["up"]
	var text: String = str(entry.get("text", ""))
	if text.length() > 140:
		text = text.substr(0, text.rfind(" ", 140)) + "…"
	var bricks := PackedStringArray()
	for id: int in one.ids:
		bricks.append("#%d" % id)
	var lines := PackedStringArray()
	lines.append(("The app looked up how real sets built it and laid the best piece "
		+ "that lays whole and fits where it goes, as a proposal:\n  %s \"%s\", %s, "
		% [entry["id"], entry["name"], RealSnippets.credit(entry)])
		+ "%d parts. %s\n  Seated on the stud at x=%s y=%s z=%s, %s%s; bricks %s."
		% [int(entry["parts"]), text, _studs(at.x), _studs(at.y), _studs(at.z), how,
			", and its pair across the model" if one.copies.size() > 1 else "",
			", ".join(bricks.slice(0, 24))])
	if one.guessed:
		lines.append(("Where it goes was read off its name (facing %s, x=%s y=%s z=%s): "
			% [one.spot["facing"], _studs(float(one.spot["x"])), _studs(float(one.spot["y"])),
				_studs(float(one.spot["z"]))]) + "if that is not where it belongs, accept it "
			+ "with move, or give each feature x, y, z and facing in submit_design.")
	var rest := PackedStringArray()
	for n: int in range(one.next, one.candidates.size()):
		var other: Dictionary = one.candidates[n]
		rest.append("%s \"%s\" (%d parts)" % [other["id"], other["name"], int(other["parts"])])
	if not rest.is_empty():
		lines.append("Next-best, for \"next\": %s." % "; ".join(rest.slice(0, 3)))
	return "\n".join(lines)


## The proposal standing in the model, framed on it from the way it faces.
## {} where no picture can be taken.
func _proposal_picture(one: FeaturePass.Proposal) -> Dictionary:
	if not ModelShot.possible() or one == null or one.ids.is_empty():
		return {}
	var bricks: Array[BrickWorld.Brick] = []
	for id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick != null:
			bricks.append(brick)
	if bricks.is_empty():
		return {}
	var box: AABB = _bounds_of(bricks).grow(4.0 * STUD)
	var from: String = str({"+z": "front", "-z": "back", "+x": "right", "-x": "left"}.get(
		str(one.spot.get("facing", "")), "corner"))
	var image: Image = await _ensure_shot().take(world, from, scenery, box)
	if image == null:
		return {}
	return await _shot.encode(image)


## settle_feature: what the design says of the app's piece for a feature.
## In the loop the loop then hands the next feature; from outside this
## answer does, with its piece laid, and after the last says what is next.
func _settle_feature(args: Dictionary) -> Variant:
	var asked: String = str(args.get("feature", "")).strip_edges()
	var names: Array[String] = _features if _busy else _outside_features
	var name: String = ""
	for listed: String in names:
		if listed.to_lower() == asked.to_lower():
			name = listed
	if name.is_empty():
		name = _feature_named(asked)
	if name.is_empty():
		return ("No feature called \"%s\". The features listed: %s." % [asked,
			", ".join(names) if not names.is_empty() else "none (submit_design's features)"])
	var features: FeaturePass = feature_pass()
	var one: FeaturePass.Proposal = features.proposal(name)
	var verdict: String = str(args.get("verdict", "")).strip_edges().to_lower()
	var reason: String = str(args.get("reason", "")).strip_edges()
	_feature_now = name
	match verdict:
		"accept":
			if one == null or one.piece.is_empty() or not features._standing(one.ids):
				return ("Nothing of the app's stands for the %s to accept. \"next\" lays " % name
					+ "a real piece for it, \"built\" says you built it, \"reject\" with a "
					+ "reason leaves it out.")
			var move: Dictionary = args.get("move", {}) if args.get("move") is Dictionary else {}
			var turns: int = int(args.get("turn", 0))
			var recolor: Dictionary = {}
			if args.get("recolor") is Dictionary:
				for key: Variant in args["recolor"]:
					recolor[int(str(key))] = int((args["recolor"] as Dictionary)[key])
			var moving: bool = not move.is_empty() and (absf(float(move.get("dx", 0.0)))
				+ absf(float(move.get("dy", 0.0))) + absf(float(move.get("dz", 0.0)))) > 0.0
			if moving or turns % 4 != 0 or not recolor.is_empty():
				var why: String = await features.adjust(one, move if moving else {}, turns % 4, recolor)
				if not why.is_empty():
					return why
				one.verdict = "adjusted"
			else:
				one.verdict = "accepted"
		"next":
			if one == null:
				one = await features.propose(name)
			else:
				if not await features.take_off(one):
					return "Could not take the %s's piece off; settle it another way." % name
				if one.candidates.is_empty():
					one.candidates = features.candidates_for(name)
				if one.spot.is_empty():
					one.spot = features.spot_for(name)
				await features._lay_next(one)
			var of: int = names.find(name) + 1
			return await _feature_brief(name, of, names.size(), true) if not one.piece.is_empty() \
				else ("No other real piece fits where the %s goes. Build it your own way and " % name
					+ "settle_feature \"built\" with how, or \"reject\" with a reason.")
		"reject":
			if reason.split(" ", false).size() < 3:
				return ("Say why in a sentence (reason): what is wrong with the piece here — "
					+ "its size, its shape, its colours, or that the model has it already.")
			if one == null:
				one = FeaturePass.Proposal.new()
				one.feature = name
				features.proposals[name.to_lower()] = one
			elif not await features.take_off(one):
				return "Could not take the %s's piece off; settle it another way." % name
			one.verdict = "rejected"
			one.reason = reason
		"built":
			var used: Array = _feature_used.get(name.to_lower(), [])
			if reason.is_empty() and not used.has("edited"):
				return ("Nothing has been built for the %s since it was handed: build it " % name
					+ "with edit_model, or say how you built it (reason).")
			if one == null:
				one = FeaturePass.Proposal.new()
				one.feature = name
				features.proposals[name.to_lower()] = one
			# Built its own way: the app's piece is not it. A session that said
			# the proposed piece "sat at the neck" and settled built left it there.
			elif not await features.take_off(one):
				return "Could not take the %s's piece off; settle it another way." % name
			one.verdict = "built"
			one.reason = reason
		_:
			return "verdict is one of \"accept\", \"next\", \"reject\" or \"built\"."
	progress.emit("the %s: %s" % [name, _feature_said(name)])
	var head: String = "The %s: %s." % [name, _feature_said(name)]
	if _busy:
		_feature_closed = true
		return head
	var left: Array[String] = features.open(_outside_features)
	if not left.is_empty():
		var brief: Variant = await _review_feature(left[0])
		return _joined(head + " Next, the %s:" % left[0], brief)
	_feature_now = ""
	return "%s\n\nEvery feature is settled:\n%s\n\n%s" % [head,
		_features_record(_outside_features), _after_features()]


## What comes after the features, for a session from outside: the first
## assembly not yet looked at closely, or the creative features.
func _after_features() -> String:
	var left: Array[String] = _not_yet_reviewed()
	if not left.is_empty():
		return ("Next, each assembly close up: review_model {\"assembly\": \"%s\"}%s."
			% [left[0], " — %d more after it" % (left.size() - 1) if left.size() > 1 else ""])
	if not surface_pass().ran:
		return ("Next, the surface pass: review_model {\"surface\": true}; then the creative "
			+ "pass, review_model {\"creative\": true}.")
	return "Next, the creative features: review_model {\"creative\": true}."


## One real piece in a line or two: its id, name and where it is from, its
## size and whether it lays as it stands, what it is, and its first parts.
func _piece_line(n: int, entry: Dictionary) -> String:
	var size: Array = entry["size"]
	var lays: String = "lays as it stands" if bool(entry.get("lays", false)) \
		else ("built at an angle, copy it" if not bool(entry.get("square", true))
			else "held from outside it, so hold it in your model or copy it")
	var text: String = str(entry.get("text", ""))
	if text.length() > 110:
		text = text.substr(0, text.rfind(" ", 110)) + "…"
	var made_of := PackedStringArray()
	for raw: Variant in (entry["bom"] as Array).slice(0, 4):
		var line: Array = raw
		made_of.append("%dx %s (%d)" % [int(line[2]), str(line[0]), int(line[1])])
	var more: int = (entry["bom"] as Array).size() - 4
	return ("%d. %s \"%s\", %s: %s x %s studs, %s plates, %d parts; %s.%s\n   %s%s"
		% [n, entry["id"], entry["name"], RealSnippets.credit(entry),
			_studs(float(size[0])), _studs(float(size[2])), _studs(float(size[1])),
			int(entry["parts"]), lays, "" if text.is_empty() else " " + text,
			", ".join(made_of), " and %d more" % more if more > 0 else ""])


# -- the creative pass ---------------------------------------------------------


## The creative pass: what a person finds and smiles at.
##
## The bench's first batch scored creativity 4.0 of 10 over thirteen
## designs, and the judge's reasons repeated: a figure standing about
## with nothing to do, a nameplate that was a blank black slope, the lamp
## post and chimney every model has, "nothing goes beyond the expected",
## no play feature, no story. The rules had asked for each of those by
## name since before the bench, and the check's advice too (_touches).
## Rules alone never moved a run; a turn of its own did, for the features.
## So this is a turn: once the build stands and its features and
## assemblies have had theirs, the design proposes three touches of
## different kinds for its subject and adds the best one or two. Nothing
## here knows a subject: the kinds are a set designer's, the subject is
## the design's.
const TURNS_FOR_TOUCHES := 6

const CREATIVE_PASS := """The creative pass: the last a LEGO® designer \
makes, and the one people remember. The model holds together and reads as \
its subject — {subject}. Now give it what a competent model lacks and a \
real set has: something a person finds and smiles at.

1. Propose three touches for this subject, not for any model, each of a \
different kind, in a line each:
  A story: who flies, drives, works, keeps or hunts from it, doing what \
this subject is for, with the thing they hold or use; or a small scene of \
what happens here. A figure standing about is a figure, not a story: give \
it its tool, its catch, its load, its customer.
  A play or display feature: something that opens, turns, lifts or comes \
apart, shown working — a door or a lid on a hinge left ajar, a hatch \
raised, a jib or a turret on a turntable, a hook hanging on its line, a \
drawbridge half down; or, for a display model, a stand whose nameplate is \
printed. A plain slope where a nameplate goes reads as blank: print it or \
leave it out.
  A nod: what only someone who knows the subject would catch — its maker, \
its number or its year on a printed part, the detail it is famous for, \
what the LEGO® set of it is loved for — or a part used for what it looks \
like rather than what it is: a claw for a thorn, a flower stem for an \
aerial, a pearl-gold ring for a crest. A lamp post, a chimney and a flag \
are what every model has; they are not this.
2. Add the best one or two now, with edit_model, place_technique or \
add_minifig: small (a handful to thirty parts), joined to the model, where \
the eye lands from the front or the corner. Never over what the subject is \
known by, never changing its silhouette, never at the cost of its build: a \
touch that hurts the likeness is not one. One hidden inside shows only \
through a door left open, an open back or a window. Where the brief says \
what is in the scene — who is there, what they hold, what they stand on — \
it is the scope: the touches go on those things (a printed part, a pose, \
something that moves, a detail it names done better), and a figure, a \
creature, a plant or a prop it did not name is clutter, not a story.
3. Say in a line which you added and why it belongs to this subject.

What it has now: {has}.

How real sets built one: find_techniques with the touch's own words — \
"cockpit hatch", "crane hook", "drawbridge", "treasure chest", "mailbox", \
"flower pot" and "display plaque" are all there — and show_technique for \
{techniques}. A printed part: search_parts "print" with the subject's own \
names (its maker, its model, its number) or a word of its story (a flag, a \
map, a gauge, a sign); there are printed parts for a great many real \
things. A figure: add_minifig. A creature: search_parts "animal"."""


## Whether this run's creative pass is still to come: set for a fresh
## design (see [method _start]), never for a revision or a selection.
var _creative_wanted: bool = false
## What the last creative pass came to, in a line, or "".
var _creative_record: String = ""
## From outside: whether a design was submitted in this session, whether
## its creative pass has been handed, and while it runs the parts and the
## count the model had when it was handed.
var _outside_designed: bool = false
var _outside_creative_handed: bool = false
var _outside_creative: Dictionary = {}


## The pass's brief for the model as it stands.
func _creative_brief() -> String:
	var subject: String = _brief.strip_edges()
	if subject.length() > 160:
		subject = subject.substr(0, subject.rfind(" ", 160)) + "…"
	var worked := PackedStringArray()
	for one: Variant in Techniques.all():
		if str((one as Dictionary).get("group", "")) == "creative touches":
			worked.append("\"%s\"" % str((one as Dictionary)["name"]))
	var brief: String = CREATIVE_PASS.replace("{subject}",
		"\"%s\"" % subject if not subject.is_empty() else "what was asked").replace(
		"{has}", _touches_had()).replace("{techniques}", ", ".join(worked))
	var tiled: String = surface_pass().for_touches()
	return brief if tiled.is_empty() else "%s\n\n%s" % [brief, tiled]


## What the model has already of the touches a set designer adds, in
## words: "1 figure, no creature, no printed part, 2 parts that hinge,
## turn or pin". So the pass proposes what is missing, not a second driver.
func _touches_had() -> String:
	if library == null:
		return "not known"
	var model: Model = _model_from_world()
	var figures: int = 0
	var creatures: int = 0
	var printed := PackedStringArray()
	var moving: int = 0
	for placement: Placement in model.placements:
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		if info == null:
			continue
		var category: String = info.family_category()
		if info.name.begins_with("Minifig Head"):
			figures += 1
		elif category == "Animal":
			creatures += 1
		elif _decorated(info) and not category.begins_with("Minifig") \
				and not printed.has(placement.part):
			printed.append(placement.part)
		if category in ["Hinge", "Turntable"] or info.has_connector("ball"):
			moving += 1
	for section: Section in model.sections.values():
		if section.hinge:
			moving += 1
	var said := PackedStringArray()
	said.append("no figure" if figures == 0
		else "%d figure%s" % [figures, "" if figures == 1 else "s"])
	said.append("no creature" if creatures == 0
		else "%d creature%s" % [creatures, "" if creatures == 1 else "s"])
	said.append("no printed part" if printed.is_empty()
		else "%d printed part%s (%s)" % [printed.size(), "" if printed.size() == 1 else "s",
			", ".join(printed.slice(0, 4))])
	said.append("nothing that hinges or turns" if moving == 0
		else "%d part%s that hinge or turn" % [moving, "" if moving == 1 else "s"])
	return ", ".join(said)


## What a creative pass came to, in a line: how many parts it added and
## the kinds new to the model, by name; "nothing added" when it added none.
func _creative_said(before: Dictionary, count: int) -> String:
	var now: Array[BrickWorld.Brick] = _bricks_inside({})
	var added: int = now.size() - count
	var new_kinds := PackedStringArray()
	for part_id: String in _parts_in(now):
		if not before.has(part_id):
			new_kinds.append("%s %s" % [part_id, _part_called(part_id)])
	if added <= 0 and new_kinds.is_empty():
		return "nothing added"
	return "%d part%s added%s" % [added, "" if added == 1 else "s",
		"" if new_kinds.is_empty() else ", new to the model: %s" % ", ".join(
			new_kinds.slice(0, 6))]


## The creative pass for a session from outside (review_model creative=),
## from now until it saves: what it adds is the pass's.
func _creative_review() -> String:
	var everything: Array[BrickWorld.Brick] = _bricks_inside({})
	if everything.is_empty():
		return "The baseplate is bare: build the model before its touches."
	_outside_creative_handed = true
	_outside_creative = {"parts": _parts_in(everything), "count": everything.size()}
	_feature_now = ""
	progress.emit("the creative pass: proposing touches for it")
	return _creative_brief() + "\n\nThen save_model: saving says what the pass added."


## What saving hands a session from outside once its features and
## assemblies have had their turns: the creative pass if it has not been
## handed; after it, what it added, said once; then "".
func _creative_next() -> String:
	var passed: String = _creative_passed()
	if not passed.is_empty():
		return passed
	if _outside_designed and not _outside_creative_handed:
		return ("Before it is finished: the creative pass, which this app's own "
			+ "designer makes last.\n\n%s" % _creative_review())
	return ""


## What a creative pass from outside added, said once at the save after it,
## or "" when none is running. Said before anything else saving hands back:
## three of four bench sessions worked the pass before their features, and
## the save that handed the next feature never said what the pass brought.
func _creative_passed() -> String:
	if _outside_creative.is_empty():
		return ""
	var said: String = _creative_said(_outside_creative["parts"],
		int(_outside_creative["count"]))
	_outside_creative = {}
	_creative_record = said
	progress.emit("the creative pass: %s" % said)
	if said == "nothing added":
		return ("The creative pass added nothing. Add the best touch you proposed "
			+ "— small, joined, where it is seen — with edit_model, place_technique "
			+ "or add_minifig, then save again.")
	return "The creative pass: %s." % said


# -- the surface pass ----------------------------------------------------------


## The surface pass (SurfacePass): the open stud fields, staircases, hard top
## edges and plain walls a set would have finished, found and laid by the app, settled
## by the design with settle_surface. In the loop it has a turn of its own
## after the assemblies and before the creative pass; from outside,
## review_model {"surface": true}, and saving says when it was never run.
var _surface: SurfacePass = null
## Whether this run's surface pass is still to come (see [method _start]).
var _surface_wanted: bool = false


func surface_pass() -> SurfacePass:
	if _surface == null:
		_surface = SurfacePass.new(self)
	return _surface


## The loop's turn for the surface pass, with [param also] first: false when
## it found nothing, so the creative pass comes straight after.
func _surface_turn(also: Array) -> bool:
	var handed: Variant = await surface_pass().hand()
	if not _busy:
		return true
	if surface_pass().findings.is_empty():
		return false
	_detailing = {"name": "surface pass", "where": {}, "surface": true}
	_detail_turns = 0
	_repairs = 0
	_turn_cap = maxi(_turn_cap, _turns + 2 + SurfacePass.TURNS)
	_forget_old_pictures()
	var content: Array = also.duplicate()
	if handed is Array:
		content.append_array(handed)
	else:
		content.append({"type": "text", "text": str(handed)})
	_messages.append({"role": "user", "content": content})
	_send()
	return true


## review_model {"surface": true}, for a session from outside: the pass laid
## on the model as it stands, with what comes after it.
func surface_review() -> Variant:
	if _bricks_inside({}).is_empty():
		return "The baseplate is bare: there is nothing to review."
	var handed: Variant = await surface_pass().hand()
	var then: String = ("Then the creative pass: review_model {\"creative\": true}."
		if not _outside_creative_handed else "Then save_model.")
	if handed is Array:
		return (handed as Array) + [{"type": "text", "text": then}]
	return "%s\n\n%s" % [str(handed), then]


## Saving, from outside, when the features and assemblies have had their
## turns and the surface pass was never run: said once on its own, before the
## creative pass is handed. "" otherwise.
func _surface_first_reminder() -> String:
	if not _outside_designed or surface_pass().ran or surface_pass().reminded:
		return ""
	surface_pass().reminded = true
	progress.emit("saved before the surface pass: reminded")
	return "Before it is finished: %s" % surface_pass().reminder()


## What a run will detail, one assembly at a time. Nothing for a model
## that is one thing: its whole look is already the look at it.
static func _queue_assemblies(named: Array[Dictionary]) -> Array[Dictionary]:
	if named.size() < 2:
		return []
	return named.slice(0, MOST_ASSEMBLIES)


## What was wrong with the last set of patterns, said by the check.
var _pattern_trouble: Array = []
## And what the patterns did that was not asked, said as advice.
var _pattern_advice: Array = []
## Whether the last design read laid its body with the shape pattern: it is
## then told to keep that body (Style.SHAPED_KEEP), not to say one.
var _shaped_body: bool = false

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
## walks a module round it. Or round a centre said as around={x, z}, yaw=
## stepping each copy round it, as a dome's panels go round its axis, each
## keeping its own pitch and roll — or stepping those too. What is built
## within the section, at any depth, is copied with it: a panel and the
## panels hinged on it go round as one.
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
		# What is within it goes with it, but not the frame its own hinge's
		# base stands in: each copy lays its own base, turned as it is.
		var inner: Array[Section] = []
		for one: Section in model.sections_within(from):
			if one.base_for != from:
				inner.append(one)
		var bodies: Dictionary = {from: []}
		for one: Section in inner:
			bodies[one.name] = []
		var count: int = 0
		for placement: Placement in model.placements:
			if bodies.has(placement.section):
				(bodies[placement.section] as Array).append(placement)
				count += 1
		if (bodies[from] as Array).is_empty() and count == 0:
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
		if count * times > room:
			trouble.append(("%d copies of \"%s\" is %d bricks, and there "
				% [times, from, count * times])
				+ ("is room for %d. " % maxi(0, room))
				+ "Build it in pieces, or make the section smaller.")
			continue

		var step := Vector3(float(order.get("dx", 0)),
			float(order.get("dy", 0)), float(order.get("dz", 0)))
		var turn: float = float(order.get("degrees", 0))
		var axis: String = str(order.get("axis", source.axis)).to_lower()
		if not ["x", "y", "z"].has(axis):
			axis = source.axis
		var turns := Vector3(float(order.get("yaw", 0)), float(order.get("pitch", 0)),
			float(order.get("roll", 0)))
		var centre: Variant = null
		var around: Variant = order.get("around")
		if around is Dictionary:
			centre = Vector2(float((around as Dictionary).get("x", source.x)),
				float((around as Dictionary).get("z", source.z)))
		elif around != null:
			trouble.append("around is a centre, {\"x\": studs, \"z\": studs}, "
				+ "in the coordinates %s is built in." % from)
			continue
		var base: String = str(order.get("name", from)).strip_edges()
		if base.is_empty():
			base = from

		for n: int in range(1, times + 1):
			var name: String = _free_name(model, base, n + 1)
			var copy: Section = source.copied(name)
			copy.x = source.x + step.x * n
			copy.y = source.y + step.y * n
			copy.z = source.z + step.z * n
			copy.axis = axis
			copy.degrees = source.degrees + turn * n
			copy.yaw = source.yaw + turns.x * n
			copy.pitch = source.pitch + turns.y * n
			copy.roll = source.roll + turns.z * n
			if centre != null:
				# Carried round the centre by as much as it is turned, so the
				# copy is the source turned rigidly about the upright there. A
				# hinge swivels about its base's first stud, so that is what
				# goes round.
				var pivot := Vector2(source.x, source.z)
				if source.hinge:
					pivot += Vector2(0.5, 0.5)
				var gone: Vector3 = Basis(Vector3.UP, deg_to_rad(turns.x * n)) \
					* Vector3(pivot.x - centre.x, 0.0, pivot.y - centre.y)
				copy.x = centre.x + gone.x + step.x * n - (pivot.x - source.x)
				copy.z = centre.y + gone.z + step.z * n - (pivot.y - source.z)
				# A hinge's base stands on studs, so each copy's on the studs
				# nearest where the turn carries it, as the first one's are:
				# carried exactly, all but the quarter turns stood between
				# studs, and the one turned full circle was refused for it.
				if source.hinge:
					copy.x = _on_studs_as(copy.x, source.x)
					copy.z = _on_studs_as(copy.z, source.z)
			model.sections[name] = copy
			var mapped: Dictionary = {from: name}
			for one: Section in inner:
				mapped[one.name] = _free_name(model, one.name, n + 1, mapped.values())
			for one: Section in inner:
				var again: Section = one.copied(mapped[one.name])
				again.within = str(mapped.get(one.within, one.within))
				again.base_for = str(mapped.get(one.base_for, one.base_for))
				model.sections[again.name] = again
			for key: String in bodies:
				for placement: Placement in bodies[key]:
					model.placements.append(placement.copied_into(mapped[key]))
			# The hinge's top is in the section and came with it; its base
			# stands outside, so each copy gets its own.
			if copy.hinge:
				if _needs_frame(copy):
					var frame := Section.new()
					frame.name = _base_name(copy)
					frame.base_for = copy.name
					model.sections[frame.name] = frame
				model.placements.append(_hinge_base(copy))
		model.link_sections()


## [param value] on the nearest stud that is on the same footing as [param
## like]: whole studs for a whole one, halves for a half.
static func _on_studs_as(value: float, like: float) -> float:
	var footing: float = fposmod(snappedf(like, 0.5), 1.0)
	return roundf(value - footing) + footing


## A section name not yet taken: [param base] with a number from [param n].
static func _free_name(model: Model, base: String, n: int, taken: Array = []) -> String:
	var at: int = n
	var name: String = "%s %d" % [base, at]
	while model.sections.has(name) or taken.has(name):
		at += 1
		name = "%s %d" % [base, at]
	return name


## The sections a model declares, before any brick refers to one.
static func _read_sections(model: Model, args: Dictionary) -> void:
	for raw: Variant in args.get("sections", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var section: Section = Section.from_dict(raw)
		if not section.name.is_empty():
			model.sections[section.name] = section
	model.link_sections()


const HINGE_BASE := "3937"
const HINGE_TOP := "3938"


## Where a hinged section's joint is, and where its own coordinates start,
## read off the joint's parts ([method Hinges.fit]): for the tilting hinge
## the base's flat bore is the pin, and closed, the top stands a plate up on
## the base's corner with its studs two plates above that — measured on
## 6085's gatehouse flag (`leaning on a hinge`): the pin 1.75 plates up and
## half a stud in, the top's studs 1.25 plates above it. For the rest, the
## line the two halves' joint records share.
func _fit_hinge(section: Section) -> void:
	# A part's corner is read off its cover, which takes the builder: an
	# assistant made only to talk has neither and lays no hinge.
	if library == null or builder == null:
		return
	var trouble: String = Hinges.fit(section, library,
		func(part: String, rot: int, at: Vector3) -> Transform3D:
			return _square_transform(Placement.from_dict({"part": part, "rot": rot,
				"x": at.x, "y": at.y, "z": at.z}), library.mesh_for(part)))
	if not trouble.is_empty():
		if section.odd.is_empty():
			section.odd = trouble
		section.hinge = false
		return


## The shells a design says ({"pattern": "shell"}), laid into it as the
## hinged sections and bricks they are, before anything is read: so a shell
## is checked, edited and read back as any hinged section is. What each
## came to goes in [param said], why one could not in [param trouble].
func _with_shells(args: Dictionary, trouble: Array, said: Array) -> Dictionary:
	var patterns: Array = args.get("patterns", []) if args.get("patterns") is Array else []
	var shells: Array = patterns.filter(func(raw: Variant) -> bool:
		return raw is Dictionary and str((raw as Dictionary).get("pattern", "")).to_lower() \
			== "shell")
	if shells.is_empty():
		return args
	var out: Dictionary = args.duplicate()
	out["patterns"] = patterns.filter(func(raw: Variant) -> bool: return not shells.has(raw))
	var sections: Array = (args.get("sections", []) as Array).duplicate() \
		if args.get("sections") is Array else []
	var bricks: Array = (args.get("bricks", []) as Array).duplicate() \
		if args.get("bricks") is Array else []
	var hinge: Dictionary = _shell_hinge()
	if hinge.is_empty():
		trouble.append("shell: this build cannot lay a clip hinge, which its panels hang on")
		return out
	for n: int in shells.size():
		var raw: Dictionary = (shells[n] as Dictionary).duplicate()
		if not raw.has("name") and shells.size() > 1:
			raw["name"] = "shell %d" % (n + 1)
		var laid: Dictionary = Shells.lay(raw, hinge, trouble)
		if laid.is_empty():
			continue
		sections.append_array(laid["sections"])
		bricks.append_array(laid["bricks"])
		said.append(str(laid["said"]))
	out["sections"] = sections
	out["bricks"] = bricks
	return out


## The characters a design says ({"pattern": "figure"}), laid into it as the
## named, jointed bricks they are (FigurePattern), ahead of the design's own
## bricks so those can attach to them by name, a hat to "hair.stud[0]". A
## second figure's parts are named after it ("dog head"), or "figure 2 head".
func _with_figures(args: Dictionary, trouble: Array, said: Array) -> Dictionary:
	var patterns: Array = args.get("patterns", []) if args.get("patterns") is Array else []
	var figures: Array = patterns.filter(func(raw: Variant) -> bool:
		return raw is Dictionary and str((raw as Dictionary).get("pattern", "")).to_lower() \
			== "figure")
	if figures.is_empty():
		return args
	var out: Dictionary = args.duplicate()
	out["patterns"] = patterns.filter(func(raw: Variant) -> bool: return not figures.has(raw))
	var bricks: Array = []
	for n: int in figures.size():
		var raw: Dictionary = figures[n]
		var named: String = str(raw.get("name", "")).strip_edges()
		var prefix: String = ""
		if not named.is_empty():
			prefix = named + " "
		elif n > 0:
			prefix = "figure %d " % (n + 1)
		var laid: Dictionary = FigurePattern.lay(raw, trouble, prefix)
		if laid.is_empty():
			continue
		bricks.append_array(laid["bricks"])
		said.append(str(laid["said"]))
	if args.get("bricks") is Array:
		bricks.append_array(args["bricks"])
	out["bricks"] = bricks
	return out


## The joint a shell's panels hang on, as [Shells] wants it: a clip on a
## bar, its line read off the parts.
func _shell_hinge() -> Dictionary:
	if library == null or not Hinges.available(Hinges.CLIP, library):
		return {}
	var fit := Section.from_dict({"name": "fit", "hinge": Hinges.CLIP, "pitch": 1})
	_fit_hinge(fit)
	if not fit.hinge:
		return {}
	return {"kind": Hinges.CLIP, "pin": fit.pin_from_corner, "line": -fit.origin_from_pin}


## Round bodies too big for moulded parts, said as shapes of plates: a nudge
## to the way real sets build them. A ball asked for came back a lumpy
## ellipsoid of plates, the session having read of hinged panels and taken
## them for a dome's alone; the guide is read once, and the shape's answer
## is read when the choice is made. And a body that curves two ways at once,
## said as a loft, a revolve or a profile with rounded shoulders: a sports
## car asked for "a smoothly curved body" was a loft of plates and curved
## slopes stepping along its length, and the next an extruded profile, the
## guide's skins and panels never reached for either time.
const ROUND_PANELS_FROM := 12.0
## A loft, revolve or extruded profile this long, rounded, curves both ways.
const TWO_WAYS_FROM := 10.0
## A round body under ROUND_PANELS_FROM said as a shape: a core of bricks a
## few studs across under a skin a part thick, which is a statue. The first
## BrickBench designs said a penguin, a duck and a blob this way, and the
## judge's word for every one was "blocky" against bodies of round bricks,
## domes and dishes; four of our own owl's nine judgements call its body
## stacked bricks.
const SMALL_ROUND := ("The %s %s studs across is laid as bricks and plates, "
	+ "and a round body that small is a few moulded parts in a set: a 4 x 4 or "
	+ "2 x 2 round brick (87081, 3941), a dome (30367c) or a dish (3960, 4740), "
	+ "round corner bricks (85080, 48092) round a core, curved slopes on side "
	+ "studs. A figure's or a creature's head or body is built so, as a "
	+ "sub-assembly, its limbs on joints (read_guide \"figures\").")


static func _round_by_panels(patterns: Array) -> Array:
	var said: Array = []
	for raw: Variant in patterns:
		if not raw is Dictionary or str((raw as Dictionary).get("pattern", "")) != "shape":
			continue
		for solid: Dictionary in Shapes._read(raw, "solids", [], true):
			var box: AABB = solid.get("box", AABB())
			var across: float = maxf(box.size.x, box.size.z)
			if solid["kind"] in ["dome", "ellipsoid"] and across >= ROUND_PANELS_FROM:
				var panels: String = ("A round body that size reads smooth as hinged "
					+ "panels, which one pattern lays closed: {\"pattern\": \"shell\", "
					+ "\"kind\": \"dome\" or \"ball\", \"across\": %d, \"at\": {x, y, z}, "
					% roundi(across) + "\"color\"} (read_guide \"round\"). ")
				if across > Shells.LARGEST + 1.0:
					panels = ("One shell of hinged panels is built up to %d studs across "
						% roundi(Shells.LARGEST) + "so far; this one, skin. ")
				elif across < Shells.SMALLEST_DOME:
					panels = ("A dome that size reads smooth as four quarter domes "
						+ "(show_technique \"smooth dome\", 16 across) or a dish. ")
				said.append(("The %s %s studs across is laid in plates, and a curve of "
					% [solid["kind"], Placement._num(snappedf(across, 0.5))])
					+ "plates is a staircase however fine. " + panels
					+ "An egg or a body lying on its side reads smooth as skins on side "
					+ "studs, with the shape kept inside as its core.")
				return said
			if solid["kind"] in ["dome", "ellipsoid", "revolve"] and across < ROUND_PANELS_FROM:
				said.append(SMALL_ROUND % [solid["kind"],
					Placement._num(snappedf(across, 0.5))])
				return said
			# Not where the shape skinned its flanks itself (Shapes.turned): told
			# its body "steps in plates however fine" over the side shells the
			# shape had laid, a car's session called it blocky and built the car
			# again by hand.
			if solid["kind"] in ["loft", "revolve", "extrude"] \
					and bool(solid.get("round", false)) and across >= TWO_WAYS_FROM \
					and minf(box.size.x, box.size.z) >= 4.0 and Shapes.turned == 0:
				said.append(("The %s %s studs long is rounded across as well as along it, "
					% [solid["kind"], Placement._num(snappedf(across, 0.5))])
					+ "and a body that curves two ways at once steps in plates however "
					+ "fine. Real sets skin it: curved slopes built flat in a section and "
					+ "stood out on bricks with side studs along its flanks (sideways "
					+ "skins), wedge plates on its plan's diagonals, panels on hinges "
					+ "where it is domed — over this shape kept as its core (read_guide "
					+ "\"round\", show_technique \"sideways skins\").")
				return said
	return said


## The section a hinge's base stands in when the hinge is turned about the
## upright: its frame is the hinge's, so the base swivels with it.
static func _base_name(section: Section) -> String:
	return "%s hinge" % section.name


static func _needs_frame(section: Section) -> bool:
	return not is_zero_approx(fposmod(section.yaw, 360.0))


static func _hinge_base(section: Section) -> Placement:
	var part: String = str(Hinges.KINDS.get(section.hinge_kind,
		Hinges.KINDS[Hinges.TILTING])[0])
	if _needs_frame(section):
		return Placement.from_dict({"part": part, "color": section.hinge_color,
			"x": 0, "y": 0, "z": 0, "rot": section.base_rot,
			"section": _base_name(section)})
	return Placement.from_dict({"part": part, "color": section.hinge_color,
		"x": section.x, "y": section.y, "z": section.z,
		"rot": section.base_rot, "section": section.within})


static func _hinge_top(section: Section) -> Placement:
	var part: String = str(Hinges.KINDS.get(section.hinge_kind,
		Hinges.KINDS[Hinges.TILTING])[1])
	return Placement.from_dict({"part": part, "color": section.hinge_color,
		"x": section.top_at.x, "y": section.top_at.y, "z": section.top_at.z,
		"rot": section.top_rot,
		"section": section.name})


## Both halves of a hinged section's joint, and the frame its base stands
## in when the hinge is turned about the upright.
func _lay_hinge(model: Model, section: Section) -> void:
	_fit_hinge(section)
	if not section.hinge:
		return
	if _needs_frame(section):
		var frame := Section.new()
		frame.name = _base_name(section)
		frame.base_for = section.name
		model.sections[frame.name] = frame
	model.placements.append(_hinge_base(section))
	model.placements.append(_hinge_top(section))
	model.link_sections()


## An edit declaring a hinged section, or unhinging one: the old halves and
## the frame the base stood in go, and the new ones are laid where the
## section now says. Found by what they are and where the section said they
## were, since the base stands outside the section.
func _rehinge(model: Model, section: Section, was: Section) -> void:
	if was != null and was.hinge:
		var kind: Array = Hinges.KINDS.get(was.hinge_kind, Hinges.KINDS[Hinges.TILTING])
		var frame: String = _base_name(was)
		var kept: Array[Placement] = []
		for placement: Placement in model.placements:
			var base: bool = placement.part == kind[0] and (placement.section == frame
				or (placement.section == was.within and not _needs_frame(was)
					and is_equal_approx(placement.x, was.x)
					and is_equal_approx(placement.y, was.y)
					and is_equal_approx(placement.z, was.z)))
			var top: bool = placement.part == kind[1] and placement.section == was.name \
				and Vector3(placement.x, placement.y, placement.z).is_equal_approx(was.top_at)
			if not base and not top:
				kept.append(placement)
		model.placements = kept
		model.sections.erase(frame)
	if section.hinge:
		_lay_hinge(model, section)
	model.link_sections()


## Turn the bricks an edit names, about the middle of them, as one: they
## become a section turned so, within whatever section they were in. What
## the window's Turn, Tilt and Roll do to a selection, said in an edit.
## Bricks from two sections are not one thing to turn, and are said so.
func _turn_bricks(model: Model, order: Dictionary, by_id: Dictionary) -> String:
	var chosen: Array[Placement] = []
	for id_raw: Variant in order.get("bricks", []):
		var placement: Placement = by_id.get(int(id_raw))
		if placement == null:
			_unknown.append(int(id_raw))
		elif not chosen.has(placement):
			chosen.append(placement)
	var turn := Vector3(float(order.get("yaw", 0)), float(order.get("pitch", 0)),
		float(order.get("roll", 0)))
	if chosen.is_empty() or turn == Vector3.ZERO:
		return ""
	var inside: String = chosen[0].section
	if chosen.any(func(p: Placement) -> bool: return p.section != inside):
		return ("turn: bricks %s are in different sections, so they are "
			% str(order.get("bricks", [])) + "not one thing to turn; turn each section's "
			+ "own, or give the section a new yaw, pitch or roll")
	# The middle of their boxes, in the coordinates they are written in,
	# on the lattice.
	var low := Vector3.INF
	var high := -Vector3.INF
	for placement: Placement in chosen:
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			continue
		var box: AABB = (_square_transform(placement, mesh) * mesh.bounds).abs()
		low = low.min(box.position)
		high = high.max(box.end)
	if low == Vector3.INF:
		return ""
	var middle: Vector3 = BrickLattice.to_ldu(BrickLattice.to_cell((low + high) * 0.5))
	var name: String = _free_name(model, "turned", 1)
	var section := Section.new()
	section.name = name
	section.x = middle.x / STUD
	section.y = middle.y / PLATE
	section.z = middle.z / STUD
	section.yaw = turn.x
	section.pitch = turn.y
	section.roll = turn.z
	section.within = inside
	model.sections[name] = section
	for placement: Placement in chosen:
		placement.x -= section.x
		placement.y -= section.y
		placement.z -= section.z
		placement.section = name
		placement.moved = true
		_touched += 1
	model.link_sections()
	return ""


## The parts turned on their own, each read into a section of one turned
## about its corner: the same arithmetic as any section, so a part turned
## off the grid is checked as one is. Named for the part, so a later edit
## can turn it again by name.
static func _turned_parts(model: Model) -> void:
	for placement: Placement in model.placements:
		if placement.turn == Vector3.ZERO:
			continue
		var name: String = "%s turned" % placement.part
		var n: int = 1
		while model.sections.has(name):
			n += 1
			name = "%s turned %d" % [placement.part, n]
		var section := Section.new()
		section.name = name
		section.x = placement.x
		section.y = placement.y
		section.z = placement.z
		section.yaw = placement.turn.x
		section.pitch = placement.turn.y
		section.roll = placement.turn.z
		section.within = placement.section
		model.sections[name] = section
		placement.x = 0.0
		placement.y = 0.0
		placement.z = 0.0
		placement.section = name
		placement.turn = Vector3.ZERO
	model.link_sections()


## A part as a design or an edit says it. Said by neither its corner nor its
## connectors, it is said so: with x, y and z no longer required (a part on a
## joint has none of its own), one left out would otherwise stand at 0, 0, 0.
func _said_placement(raw: Variant) -> Placement:
	var placement := Placement.from_dict(raw if raw is Dictionary else {})
	if raw is Dictionary and not (raw as Dictionary).has("attach") \
			and not ((raw as Dictionary).has("x") or (raw as Dictionary).has("y")
				or (raw as Dictionary).has("z")):
		placement.odd_attach = ("says neither where it goes (x, y, z, its low corner) nor what "
			+ "it attaches to (attach: {\"to\": \"torso.hinge[0]\", \"by\": \"hinge[0]\"})")
	return placement


## Every placement said by its connectors (attach), put where BrickAgent's
## attach puts it (Attach.pose) and written as a placement: in the frame of
## the part it goes on, square to it where it is (a tile on a side stud, a leg
## on its hips) with what lies past the lattice cell as a nudge, and otherwise
## as a section of one, turned as the joint turns it (an arm swung on its
## shoulder) within the section the part it goes on is in, so that it goes
## where that goes. In order: a part attaches to one put before it, by the
## name that one was given ("torso.hinge[0]"), or to a brick standing by its
## number ("#41.stud[3]"). One whose parts have not arrived yet (the web
## build fetches them) waits for [method _ready_to_check].
##
## Placed by their corners, a session's arms, tails and wings were the joint
## arithmetic it gets wrong, so it built none: 0% clips, bars, balls and
## hinges in our BrickBench characters against BrickAgent's 4%.
func _attach_parts(model: Model) -> void:
	var waiting: bool = false
	for placement: Placement in model.placements:
		if not placement.attach.is_empty() and placement.odd_attach.is_empty():
			waiting = true
	if not waiting or library == null:
		return
	var named: Dictionary = {}       ## name in lower case -> its placement
	var twice: Dictionary = {}       ## names given to two parts
	var by_id: Dictionary = {}
	for placement: Placement in model.placements:
		if placement.id != 0:
			by_id[placement.id] = placement
		if placement.name.is_empty():
			continue
		var key: String = placement.name.to_lower()
		if named.has(key) and named[key] != placement:
			twice[key] = true
		elif not named.has(key):
			named[key] = placement
	model.link_sections()
	for placement: Placement in model.placements:
		if placement.attach.is_empty() or not placement.odd_attach.is_empty():
			continue
		var said: String = _attach_one(model, placement, named, twice, by_id)
		if said == ATTACH_WAITS:
			continue
		placement.attach = {}
		if not said.is_empty():
			placement.odd_attach = said
	model.link_sections()


## What [method _attach_one] says of a part whose geometry has not arrived.
const ATTACH_WAITS := "waits"


## One placement's attach worked out: "" when done, [constant ATTACH_WAITS]
## to wait for its parts, else why it cannot be done as said.
func _attach_one(model: Model, placement: Placement, named: Dictionary,
		twice: Dictionary, by_id: Dictionary) -> String:
	var raw: Dictionary = placement.attach
	var to_said: String = str(raw.get("to", "")).strip_edges()
	if to_said.is_empty():
		return ("has an attach with no to: say the part and its connector, as "
			+ "\"torso.hinge[0]\" (a part of this design by its name) or \"#41.stud[3]\" "
			+ "(a brick standing, by its number)")
	var split := RegEx.create_from_string(
		"^(.+?)\\s*\\.\\s*([A-Za-z]+\\s*(?:\\[\\s*-?\\d+\\s*\\]|-?\\d+)?)$")
	var found: RegExMatch = split.search(to_said)
	if found == null:
		return ("attaches to \"%s\", which is not a part and a connector, as \"torso.hinge[0]\""
			% to_said)
	var ref: String = found.get_string(1).strip_edges()
	var where: Dictionary = Attach.parse_address(found.get_string(2))
	if where.has("error"):
		return "attaches to %s: %s" % [to_said, where["error"]]
	var target: Placement = null
	var number: String = ref.trim_prefix("#").strip_edges()
	if ref.begins_with("#") or number.is_valid_int():
		target = by_id.get(int(number))
		if target == null:
			return ("attaches to %s, but no brick numbered %s stands (look_at_model numbers them)"
				% [to_said, number])
	else:
		var key: String = ref.to_lower()
		if twice.has(key):
			return "attaches to '%s', and two parts are named that; give each its own name" % ref
		target = named.get(key)
		if target == null:
			# A part attached earlier, by the section of one it was written as.
			var inside: Array = model.placements.filter(func(p: Placement) -> bool:
				return p.section.to_lower() == key)
			if inside.size() == 1:
				target = inside[0]
		if target == null:
			return ("attaches to '%s', and no part is named that. Name the part it goes on "
				% ref + "(\"name\": \"%s\") where it is placed, before this one, or say a " % ref
				+ "brick standing by its number, as \"#41.%s\"" % found.get_string(2))
	if target == placement:
		return "attaches to itself"
	if not target.attach.is_empty():
		if target.odd_attach.is_empty() and model.placements.find(target) \
				< model.placements.find(placement):
			return ATTACH_WAITS
		return ("attaches to '%s', which is attached after it: put '%s' first" % [ref, ref]
			if target.odd_attach.is_empty() else "attaches to '%s', which could not be put "
			% ref + "where it was said itself")
	if not target.odd_attach.is_empty() or not target.odd_face.is_empty() \
			or not target.odd_axis.is_empty():
		return "attaches to '%s', which could not be put where it was said itself" % ref
	if not target.section.is_empty() and not model.sections.has(target.section):
		return ("attaches to '%s', which is in section '%s', and there is no such section"
			% [ref, target.section])
	for part_id: String in [target.part, placement.part]:
		if not library.parts.has(part_id):
			return "no part '%s' exists" % part_id
	_on_its_line(target)
	var target_mesh: Lbm.PartMesh = library.mesh_for(target.part)
	var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
	if target_mesh == null or mesh == null:
		return ATTACH_WAITS
	for part_id: String in [target.part, placement.part]:
		if not Exact.known(library, part_id):
			Exact.shape_for(library, part_id)
			if not Exact.known(library, part_id):
				return ATTACH_WAITS
	var parent: Section = model.section_for(target)
	var target_at: Transform3D = target.exact_at(_transform(target, target_mesh, parent))

	var theirs: Array = Attach.points_of(library, target.part)
	var mine: Array = Attach.points_of(library, placement.part)
	var type: String = where["type"]
	var many: int = Attach.count_of(theirs, type)
	if many == 0:
		return "attaches to %s, and %s has no %s: it has %s%s" % [to_said, target.part, type,
			Attach.listing(theirs), Attach.mates_said(theirs, mine, ref)]
	if where["index"] == null and many > 1:
		return ("attaches to %s, and %s has %d of those: say which, %s[0] to %s[%d] "
			% [to_said, target.part, many, type, type, many - 1]
			+ "(attachment_points lists each with where it is)")
	var a: Attach.Point = Attach.pick(theirs, type, int(where["index"]) if where["index"] != null else 0)
	if a == null:
		return "attaches to %s, and %s has %d %s, %s[0] to %s[%d]" % [to_said, target.part, many,
			type, type, type, many - 1]

	var by_type: String = ""
	var by_index: Variant = null
	var by_said: Variant = raw.get("by")
	if by_said is Array and not (by_said as Array).is_empty():
		by_type = str(by_said[0]).strip_edges().to_lower()
		by_index = int(by_said[1]) if (by_said as Array).size() > 1 else null
	elif by_said != null and not str(by_said).strip_edges().is_empty():
		var by_where: Dictionary = Attach.parse_address(str(by_said))
		if by_where.has("error"):
			return "attaches by %s: %s" % [str(by_said), by_where["error"]]
		by_type = by_where["type"]
		by_index = by_where["index"]
	var source: Dictionary = Attach.source_for(mine, a, by_type, by_index)
	if source.has("error"):
		# What does mate, unless it is only which of several fitting ones.
		return "goes on %s, but %s %s%s" % [to_said, placement.part, source["error"],
			"" if str(source["error"]).contains("say which")
				else Attach.mates_said(theirs, mine, ref, a)]
	var b: Attach.Point = source["point"]

	var options: Dictionary = {}
	for key: String in ["yaw", "slide"]:
		if raw.has(key):
			options[key] = float(raw[key])
	if raw.has("flip"):
		options["flip"] = bool(raw["flip"])
	if raw.has("seat"):
		options["seat"] = str(raw["seat"])
	if raw.has("align"):
		var pair: Variant = raw["align"]
		var u: Variant = Attach.direction(pair[0]) if pair is Array and (pair as Array).size() == 2 \
			else null
		var v: Variant = Attach.direction(pair[1]) if u != null else null
		if u == null or v == null:
			return ("has align %s: it takes two directions, the part's own and the model's, as "
				% JSON.stringify(pair) + "[\"+z\", \"up\"] or [[0, 0, 1], [0, 1, 0]]")
		options["align"] = [u, v]
	if raw.has("orient"):
		var orient: Variant = _orient_of(raw["orient"])
		if orient == null:
			return ("has orient %s: give the part's own turn in the model as {\"yaw\": 150, "
				% JSON.stringify(raw["orient"]) + "\"pitch\": 0, \"roll\": 0}, or \"same\" for "
				+ "the model's own axes")
		options["orient"] = orient
	if Attach.pinned(a, b) and not raw.has("slide") and not raw.has("seat"):
		options["slide"] = Attach.seat_slide(Exact.shape_for(library, target.part), target_at,
			Exact.shape_for(library, placement.part), a, b, options)
	var posed: Dictionary = Attach.pose(target_at, a, b, options)
	if posed.has("error"):
		return "on %s, by its %s: %s" % [to_said, b.address(), posed["error"]]
	var said: String = _written_at(model, placement, mesh, posed["at"], parent, ref)
	if not said.is_empty():
		return said
	placement.attached_to = target
	placement.attached_by = "%s on %s's %s" % [b.address(), ref, a.address()]
	return ""


## An orientation said for orient: {yaw, pitch, roll} as a section's, [yaw,
## pitch, roll], or "same" for the model's own axes; null when not one.
static func _orient_of(said: Variant) -> Variant:
	if said is Dictionary:
		var turn: Dictionary = said
		return Section.turned(float(turn.get("yaw", 0.0)), float(turn.get("pitch", 0.0)),
			float(turn.get("roll", 0.0)))
	if said is Array and (said as Array).size() == 3:
		return Section.turned(float(said[0]), float(said[1]), float(said[2]))
	if said is String and ["same", "id", "identity", "as is", "none"].has(
			str(said).strip_edges().to_lower()):
		return Basis.IDENTITY
	return null


## [param placement] written where [param at] (the world) puts it: square to
## the frame of [param parent] (the section the part it goes on is in, null
## for the model's own), in that frame with a nudge for what lies past its
## cell; else a section of one within [param parent], named for the part or
## for what it is on. "" when written, else why not.
func _written_at(model: Model, placement: Placement, mesh: Lbm.PartMesh, at: Transform3D,
		parent: Section, on: String) -> String:
	var local: Transform3D = at if parent == null else parent.placed().affine_inverse() * at
	if BrickLattice.is_square_to_grid(local.basis):
		var basis: Basis = BrickLattice.snap_basis(local.basis)
		placement.section = parent.name if parent != null else ""
		placement.face = BrickLattice.face_of(basis)
		placement.rot = BrickLattice.turns_about(basis, placement.face)
		var corner: Vector3i = _corner_cell(mesh, placement.part,
			BrickLattice.basis_for(placement.face, placement.rot))
		var cell: Vector3i = BrickLattice.to_cell(local.origin + Vector3.ONE * 0.001)
		placement.x = _into_cell(cell.x + corner.x, STUD)
		placement.y = _into_cell(cell.y + corner.y, PLATE)
		placement.z = _into_cell(cell.z + corner.z, STUD)
		placement.nudge = Vector3.ZERO
		placement.nudge = local.origin - _square_transform(placement, mesh).origin
		if placement.nudge.length() < 0.0005:
			placement.nudge = Vector3.ZERO
		if _square_transform(placement, mesh).origin.distance_to(local.origin) > 0.01:
			return "could not be written where its connector puts it (%s)" % str(local.origin)
		return ""
	var corner_ldu: Vector3 = BrickLattice.to_ldu(_corner_cell(mesh, placement.part,
		Basis.IDENTITY))
	var own: Transform3D = local * Transform3D(Basis.IDENTITY, corner_ldu)
	var angles: Vector3 = Section.angles_of(own.basis)
	var section := Section.new()
	var base: String = placement.name if not placement.name.is_empty() \
		else "%s on %s" % [placement.part, on]
	section.name = base
	var n: int = 1
	while model.sections.has(section.name):
		n += 1
		section.name = "%s %d" % [base, n]
	section.x = own.origin.x / STUD
	section.y = own.origin.y / PLATE
	section.z = own.origin.z / STUD
	section.yaw = angles.x
	section.pitch = angles.y
	section.roll = angles.z
	section.within = parent.name if parent != null else ""
	model.sections[section.name] = section
	model.link_sections()
	placement.section = section.name
	placement.x = 0.0
	placement.y = 0.0
	placement.z = 0.0
	placement.face = "up"
	placement.rot = 0
	placement.nudge = Vector3.ZERO
	var built: Transform3D = _transform(placement, mesh, section)
	var off: float = built.origin.distance_to(at.origin)
	for k: int in 3:
		off = maxf(off, (built.basis[k] - at.basis[k]).length() * 30.0)
	if off > 0.05:
		return "could not be written where its connector puts it, %s LDU off" % str(snappedf(off, 0.01))
	return ""


# -- validation ----------------------------------------------------------


## The check, off the main thread once a design is big enough to be felt.
##
## On the web the page has one thread, and the check held it: on the
## owner's 4,242-part Falcon Heavy a check_design was one 31 s task in a
## browser, and a submit, an edit and a review each another — no frame, no
## click, no answer to Claude until it was done. On the desktop it was
## 3.4 s of a frozen window. So a big check runs on a worker and this waits
## for it a frame at a time, the page drawing and answering meanwhile.
##
## What the worker reads is made still first. Every part it needs is loaded
## here, because a worker never loads one (PartLibrary.mesh_for); the
## library holds new arrivals aside until it is done, and a part made
## meanwhile waits for it; the bricks already
## standing are listed here rather than read from a world that a person may
## be adding to; and the tables filled on first use — the style norms, the
## minifigure name patterns — are filled here. The probes call [method
## _check] itself, on their own thread, as before.
func _checked(model: Model, alone: bool = false, weigh: bool = false) -> Dictionary:
	# One worker at a time: a second check while one is out (the design
	# loop and a connector both checking) is done here, as before.
	if model.placements.size() < CHECK_OFF_THREAD_FROM or _standing_held \
			or OS.has_feature("nothreads") or library == null:
		return _check(model, alone, weigh)
	_standing_held = true
	await _ensure_parts(model)
	Style.norms()
	# Its table of which parts are a hose's pieces filled here, not raced on
	# the worker (Joints.held_otherwise).
	Flex.kind_of_piece("")
	var named: Dictionary = {}
	for placement: Placement in model.placements:
		named[placement.part] = true
	for part_id: String in named:
		Minifig.slot_for(library.parts.get(part_id))
	_standing_now = _others_standing(alone)
	# The exact shapes read a part at a time, the frame given back between:
	# read in one go they were 52 of the 81 ms of the desktop's frame after
	# Brick Art, and a browser's was 355 ms (progress_check, 2026-10-15).
	var exact_ids: Array = _exact_ids(model, alone)
	var pace := FramePace.new()
	for part_id: String in exact_ids:
		if pace.due():
			await pace.next()
		Exact.shape_for(library, part_id)
	_exact_now = Exact.shapes_for(library, exact_ids)
	library.begin_reading()
	var report: Dictionary = {}
	var task: int = WorkerThreadPool.add_task(func() -> void:
		report.merge(_check(model, alone, weigh)), false, "check a design")
	library.reading_in(task)
	while not WorkerThreadPool.is_task_completed(task):
		await Engine.get_main_loop().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	library.end_reading(task)
	_standing_held = false
	_standing_now = []
	_exact_now = {}
	if report.is_empty():
		# A worker that failed leaves nothing. Checked here instead: slow,
		# but an answer.
		return _check(model, alone, weigh)
	return report


## Placements from which a check goes to a worker. Below it a check is a
## few tens of milliseconds and a worker would only add a frame.
const CHECK_OFF_THREAD_FROM := 300

## The bricks a check has to fit around, as [method _others_standing] found
## them before the worker began.
var _standing_now: Array = []
var _standing_held: bool = false


## What will still be standing afterwards and is not this design's: none
## of the bricks it placed, nor the baseplate. Copies, so a worker reading
## them shares nothing with the world.
func _others_standing(alone: bool) -> Array:
	if _standing_held and OS.get_thread_caller_id() != OS.get_main_thread_id():
		return _standing_now
	var standing: Array = []
	if alone or world == null:
		return standing
	var mine: Dictionary = {}
	for brick_id: int in _placed_ids + _sketched_ids:
		mine[brick_id] = true
	for brick: BrickWorld.Brick in world.bricks():
		if mine.has(brick.id) or scenery.has(brick.id):
			continue
		standing.append(BrickWorld.Brick.new(brick.id, brick.part_id,
			brick.color_code, brick.transform))
	return standing


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
##
## ``weigh`` asks as well whether it would stand, and puts the answer in
## "balance" (Balance.Report): check_design's, which a session reads.
## ``weigh_whole`` asks it only of a model that passes in one piece: what a
## mend checks again and again until it does, a second of weighing each on
## a forty-stud scan, wants only the last. Without ``advise`` it says only
## the faults, none of the advice (Brickify reads no more).
func _check(model: Model, alone: bool = false, weigh: bool = false,
		weigh_whole: bool = false, advise: bool = true) -> Dictionary:
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
	## Dressing that would have overlapped a brick: index -> true.
	var gave_way: Dictionary = {}
	## Section name -> the indices of the placements in it.
	var part_of: Dictionary = {}
	## Sections reported adrift, so the hint below can address them too.
	var stuck: Dictionary = {}
	## index -> the lattice key of what it ran into first, for a refusal
	## to say where it would fit instead (OpenPoints).
	var overlapping: Dictionary = {}
	## Things worth saying that are not faults, and must not be counted
	## as any.
	var advice: Array = []
	var issues: Dictionary = {}     ## kind -> Array[String]
	## index -> its cover, as boxes. Every cell it was, once: 2,000 cells a
	## brick on the owner's 4,242-part Falcon Heavy, 8.5 million Vector3i
	## made and kept for a check — a third of a gigabyte of the browser's
	## heap, and most of the time the loop below took. Everything that read
	## them wanted a lowest cell, a highest or a count, and boxes answer
	## each in six numbers.
	var cells_of: Dictionary = {}
	var boxes_of: Dictionary = {}   ## index -> its boxes, six ints each
	var box_of: Dictionary = {}     ## index -> [low cell, high cell]
	## Overlaps between bricks standing, excused: see [method _standing_overlaps].
	var collided: Array = []

	for said: Variant in _pattern_trouble:
		_note(issues, "pattern", str(said))
	for said: Variant in _repeat_trouble:
		_note(issues, "repeat", str(said))
	# First, as how to build it is decided here: a character on joints.
	var on_joints: String = _on_joints_said(model)
	if not on_joints.is_empty():
		advice.append(on_joints)
	advice.append_array(_pattern_advice)
	# A turn or a hinge that could not be read as asked is said, not
	# quietly built some other way: a panel told to tip two ways on a
	# one-pin hinge and laid on one of them looks right and is not.
	model.link_sections()
	for name: String in model.sections:
		var odd: String = (model.sections[name] as Section).odd
		if not odd.is_empty():
			_note(issues, "section", "section '%s': %s." % [name, odd])

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
	var entries: Array = _mating_entries(model)
	var joined: Dictionary = Joints.both_ways(entries)
	## And a ball in its socket, a towball's too, whichever way each turns:
	## held and forgiven as a pin is. See [method Joints.balls].
	Joints.merge(joined, Joints.balls(entries))
	## And which turn in something round that fits them, with where: a clip
	## on a bar, a bar in a hollow stud, a hinge, a turntable. See
	## [method Joints.rounds].
	var rounds: Dictionary = Joints.rounds(entries)
	## And which gears are in mesh, whose discs share the ring their teeth
	## turn in. Forgiven, and holding nothing: a gear is held by its axle.
	var meshing: Dictionary = Joints.meshing(entries)
	## index -> where that placement went, for the inserts below.
	var placed_at: Dictionary = {}
	## The parts by their exact shapes, as BrickBench judges them (ExactCheck):
	## each placement and each brick standing, numbered placements first.
	var exact: ExactCheck = _exact_check_for(model, alone)

	# What will still be there afterwards, standing in the way.
	var theirs: Dictionary = {}     ## lattice key -> part id
	if not alone and world != null:
		var key: int = -1
		for brick: BrickWorld.Brick in _others_standing(alone):
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null:
				continue
			lattice.occupy_boxes(key,
				builder.boxes_for(part, brick.transform))
			theirs[key] = brick.part_id
			exact.stand(key, brick.part_id, brick.transform)
			key -= 1

	# A part of this design that misses a stud, a hole, a hinge or a bar by a
	# few LDU goes onto it exactly, before anything is checked.
	var seated: String = _seat_exactly(model, exact)
	if not seated.is_empty():
		advice.append(seated)

	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		# A colour no part can be: a number LDraw does not have, or one
		# of its internal codes — 16 means "the colour of whatever this
		# is inside", which a brick on a baseplate is not. Drawn, either
		# came out magenta and nothing said why. Only a brick this design
		# places: one already standing came from somewhere else, and an
		# edit's own recolours are checked where they are asked for.
		# Not a reason to skip the brick's geometry, which is still sound.
		if placement.id == 0:
			var trouble: String = _colour_trouble(placement.color)
			if not trouble.is_empty():
				_note(issues, "no such colour", "brick %d (%s): %s"
					% [index, placement.part, trouble])
		# A run kept to a list of parts (--parts-only, the BrickBench
		# bench): one off it is refused wherever it stands, so the edit
		# that would keep it is the one that swaps it.
		if not PartsOnly.allows(placement.part, library):
			_note(issues, "not among this run's parts", "%s: %s" % [
				"#%d" % placement.id if placement.id != 0 else "brick %d" % index,
				PartsOnly.swap_words(placement.part)])
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
		if not placement.odd_axis.is_empty():
			_note(issues, "no such joint", "brick %d (%s) %s." % [index,
				placement.part, placement.odd_axis])
			continue
		# Said by its connectors and not put there: said, and not built
		# somewhere else instead.
		if not placement.odd_attach.is_empty():
			_note(issues, "attach", "brick %d (%s%s) %s." % [index, placement.part,
				" '%s'" % placement.name if not placement.name.is_empty() else "",
				placement.odd_attach])
			continue
		if not placement.attach.is_empty():
			_note(issues, "not loaded", "brick %d (%s) is attached by parts whose geometry "
				% [index, placement.part] + "has not arrived yet; keep it and try again")
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
		# is not a fault. Where it stands, for one nobody moved ([method
		# _joined_at]).
		var at: Transform3D = _joined_at(placement, part, model)
		# In a section, y is measured from the section's pivot, not the
		# ground, so it is where the brick ends up that says. A hinge top
		# leaning on a tilting hinge was refused as below the ground at
		# twenty-eight LDU above it. By its shape, not its box: a tyre spun
		# on its axle hangs its box 8 LDU below its tread, and a wheel
		# standing on its tread was refused as below the ground.
		var under_ground: bool = placement.y < 0
		if not placement.section.is_empty():
			under_ground = part.lowest_at(at) < -1.0
		if under_ground and (placement.id == 0 or placement.moved):
			_note(issues, "below ground",
				"brick %d (%s) is at y=%d, below the ground" % [
					index, placement.part, placement.y])
			continue

		placed_at[index] = at
		exact.place(index, placement.part, placement.exact_at(at))
		# Boxes, worked out once. For a turned part the cover costs a
		# separating-axis test on every candidate cell, and asking for it
		# twice — once as boxes, once as cells — is what made a model with
		# four sections take thirty-five seconds to check against six and
		# a half.
		var packed: PackedInt32Array = builder.boxes_for(part, at)

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
			# The joints below are forgiven here as well. They were only ever
			# asked about between sections, so a hinge, a clip on a bar or a
			# pin inside one turned assembly was refused for what the same
			# parts did square.
			var near: PackedInt64Array = _joints_out(own.blockers_boxes(here),
				index, model, placed_at, joined, rounds, here, own,
				model.section_for(placement).placed(), true, meshing)
			# Their exact shapes decide where both have one.
			near = exact.drop_cleared(near, index)
			# Between two bricks standing, as outside a section: a file's
			# tipped parts read into one ([method _adopted]) were refused for
			# what the same parts read square were forgiven — 31 overlaps in
			# 10240's X-wing, where there had been none.
			_standing_overlaps(near, placement, index, model, collided)
			near = _between_standing(near, placement, model)
			near = _give_way(near, placement, index, model, gave_way)
			if gave_way.has(index):
				continue
			if not near.is_empty():
				crowded[placement.section] = true
				overlapping[index] = near[0]
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
		#
		# A pane in its window frame, or a door in its door frame, where
		# real sets put it. See [constant NESTS].
		#
		# And something round in something round that fits it, which is a
		# clip on a bar, a bar in a hollow stud, a hinge and a turntable:
		# of 880 real sets' sub-models the checker refused 232 for
		# overlaps, and these were most of them. Forgiven only where the
		# overlap lies inside the bore, so the same two parts meeting
		# anywhere else still collide. See [method Joints.rounds].
		blockers = _joints_out(blockers, index, model, placed_at, joined,
			rounds, packed, lattice, Transform3D.IDENTITY, false, meshing)
		# A cover is whole cells, and two parts it rounds into each other can
		# be clear by their real shapes: where both have one, the shapes decide.
		blockers = exact.drop_cleared(blockers, index)

		_standing_overlaps(blockers, placement, index, model, collided)
		blockers = _between_standing(blockers, placement, model)

		blockers = _give_way(blockers, placement, index, model, gave_way)
		if gave_way.has(index):
			continue

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
			overlapping[index] = blocker
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
				"brick %d (%s at %s) overlaps %s%s%s" % [
					index, placement.part, placement.where(), who,
					_ends_at(cells_of.get(blocker - 1)),
					_gears_apart(model, placed_at, index, blocker - 1)])
			continue

		lattice.occupy_boxes(index + 1, packed)
		cells_of[index] = packed
		boxes_of[index] = packed
		# The corners, read off the boxes. Three checks below want them,
		# and finding them by walking every cell is nine thousand six
		# hundred reads for a number six of them give: on a ten thousand
		# brick wall that one loop was twenty seconds of the check.
		box_of[index] = BrickLattice.corners_in(packed)

	# And what the lattice forgave or could not see: a side stud pushed into
	# a brick, a hinge through its other half, an axle through a part with no
	# hole on its line, a part sunk into the one under it. Said for each pair
	# this design is in, with how to fix it; between bricks standing, kept for
	# the audit of real sets as the lattice's overlaps are.
	var colliding: Dictionary = {}
	_exact_collisions(model, exact, issues, overlapping, gave_way, collided, meshing, colliding)

	# Without the dressing that gave way, and checked again, so that every
	# brick number said from here on is a number in the model as built.
	if not gave_way.is_empty():
		return _without_dressing(model, gave_way, alone, weigh, weigh_whole, advise)

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
	# A part put on another by their connectors holds by that joint, as a
	# pin does, where BrickNet's labels still join the two: an arm on its
	# shoulder at any angle, a ball in its socket, a clip on a bar, which the
	# lattice's cells cannot see.
	_attach_joins(model, exact, placed_at, joined)
	# A round joint holds both ways, as a pin does: a flag clipped to a
	# lance hangs from the lance, and a turntable's top is held by its base.
	var holds: Dictionary = joined.duplicate(true)
	# And what holds by glue or by being one thing: a sticker on the face it
	# lies on, a string's braids with each other (Joints.held_otherwise).
	var with_paths: Array = entries.map(func(entry: Array) -> Array:
		var placement: Placement = model.placements[int(entry[0])]
		return entry + [Assemblies.path_from(placement.group, placement.unit)])
	# And what is pushed into what without a connector to pair: a carrot in
	# a hand's grip, a spring in its hips, an arm's peg in its torso. It made
	# a figure one piece and held none of it: an arm a file swings about the
	# torso's line, not its own, has its peg 8 degrees off the socket's, and
	# 6022's archer hung his bow arm in the air once the arm was checked where
	# it stands (Joints.pushed_in).
	var pushed: Dictionary = Joints.pushed_in(entries.filter(
		func(entry: Array) -> bool: return cells_of.has(entry[0])),
		_filled_by(cells_of, lattice))
	for held: Dictionary in [rounds, Joints.held_otherwise(with_paths, library), pushed]:
		for index: Variant in held:
			if not holds.has(index):
				holds[index] = {}
			for other: Variant in held[index]:
				(holds[index] as Dictionary)[other] = true
	var clutched_pairs: Array = []
	_check_support(model, cells_of, lattice, issues, crowded, holds,
		loose, boxes_of, floating, clutched_pairs)
	for kind: String in loose:
		var said: Array = loose[kind]
		advice.append("%s\n%s" % [kind, "\n".join(
			PackedStringArray(said.slice(0, WORTH_SAYING)))])
		if said.size() > WORTH_SAYING:
			advice[advice.size() - 1] += \
				"\n  ...and %d more like that." % (said.size() - WORTH_SAYING)

	# What turns with what: which gears mesh, which nearly do, and what each
	# axle grips and turns in.
	var turning: String = _drive_said(model, entries, meshing, placed_at)
	if not turning.is_empty():
		advice.append(turning)
	var hinged: String = _hinges_said(model)
	if not hinged.is_empty():
		advice.append(hinged)

	# Every section has to be fixed to something outside itself.
	# Held together inside and touching nothing is a part that falls off
	# when the model is picked up, which is the one thing a section
	# makes easy to do by accident.
	_check_sections_attached(model, cells_of, lattice, issues, crowded,
		stuck, boxes_of, joined, rounds, exact)

	# Held by a connection, as BrickBench's stability check wants: a part of
	# this design resting on another with nothing joining them falls when
	# the model is picked up, and its simulation lets it fall. Not said again
	# of a section already said to lean on nothing or to be adrift.
	var unheld: Dictionary = {}
	_exact_unheld(model, exact, issues, crowded, cells_of, floating, holds,
		clutched_pairs, stuck, unheld)

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
	# Advice, which a caller that reads only the faults goes without: Brickify's
	# mend checks a forty-stud scan again and again, and advice was a quarter of
	# each check.
	if advise:
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

		# And whether it is built the way real sets of its kind are: on its
		# side, at an angle, curved, and mirrored only where they are.
		var square: String = _style(model)
		if not square.is_empty():
			advice.append(square)

		# What to use instead of a colour that does not exist, said once.
		if issues.has("no such colour"):
			advice.append(_colour_advice())

		# And whether anything is specified in a colour it was never made in.
		var unmade: String = _never_made(model)
		if not unmade.is_empty():
			advice.append(unmade)

		# And whether the outline is a staircase where it could be an edge.
		var stepped: String = _stepped_outline(cells_of, box_of)
		if not stepped.is_empty():
			advice.append(stepped)

		# And whether there is a line it would come apart along. Not between
		# round parts: two cylinder halves back to back, four corner rounds of a
		# ring and a booster beside its core are how a set builds a round, each
		# column tied by a round plate, and a rocket was told to stagger them.
		var walls: Dictionary = {}
		for index: int in box_of:
			if not Style.kinds_of(model.placements[index].part).contains("c"):
				walls[index] = box_of[index]
		var seam: String = _unbonded_seam(walls)
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

		# And whether it has a touch nobody asked for.
		var touches: String = _touches(model)
		if not touches.is_empty():
			advice.append(touches)

		# And the three things that made the homepage's Orthanc "the ugliest
		# piece of shit I've ever seen", each a fault of any subject: windows
		# in a grid, a dark face of plain bricks, a tall thing with no profile.
		for said: String in [_window_grid(model), _dark_and_plain(model),
				_straight_shaft(model, box_of), _speckle(model), _daylight(model),
				_wide_yard(model, box_of)]:
			if not said.is_empty():
				advice.append(said)

		# And whether a nearly-symmetric model has a brick on one side only.
		var lopsided: String = _lopsided(model, box_of, lattice)
		if not lopsided.is_empty():
			advice.append(lopsided)

	var each_piece: Array = _pieces_of(model, cells_of, lattice, boxes_of, holds)
	var pieces: int = each_piece.size()
	# What touches what, asked only of a model with a part of the design's
	# in it: of one that is all the person's own nothing is asked, and for a
	# real set in a thousand pieces each piece's every part was asked what it
	# stands beside.
	var apart: Dictionary = _standing_apart(model, each_piece, floating,
		func() -> Dictionary: return _touching(each_piece, lattice, boxes_of),
		func() -> Dictionary: return _outside(each_piece, box_of), box_of)
	for piece: Array in apart["loose"]:
		_note(issues, "loose", _loose_said(model, piece))

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
	# Pieces nothing joins, said; a piece apart from the model fails unless
	# it is named.
	#
	# All of it was a remark, because a model in two pieces is often what
	# was asked for (a boat and a jetty, a tree beside a house, a nameplate
	# in front of a car) — and a remark let the held-out car finish with a
	# plaque lying loose in front of it and say every check passed. What is
	# meant to stand apart is named, and the person sees it as an item of
	# its own. What stands against the model unjoined (bricks side by side,
	# a seam) is a remark still, each piece said where it is.
	# A vehicle's part that nothing couples, each said, with how sets couple
	# one: told only that a piece stood against the model, the shapes round's
	# locomotive left its tender as it was.
	var uncoupled: Array = apart["uncoupled"]
	if not uncoupled.is_empty():
		feedback += "\n\n"
		for found: Dictionary in uncoupled.slice(0, WORTH_SAYING):
			feedback += _uncoupled_said(model, found) + " "
		feedback += COUPLE_HOW
	var apart_loose: int = (apart["loose"] as Array).size()
	if apart_loose > 0:
		feedback += ("\n\nA piece apart from the model is either a part "
			+ "that has come off — it falls off when the model is picked up "
			+ "— or an item of its own: a stand, a sign, a nameplate, a "
			+ "figure's base. Join %s to the model, " % ("it" if apart_loose == 1
				else "each")
			+ "or, if it is meant to stand apart, name it: an assembly of "
			+ "its own (assemblies, on edit_model or submit_design) whose "
			+ "box holds it and none of the model.")
	elif int(apart["against"]) > 0:
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
		var unjoined: Array = apart["unjoined"]
		if not unjoined.is_empty():
			feedback += (" Each falls off when the model is picked up; join it "
				+ "with a plate or brick over or under the joint that reaches "
				+ "across into both, or a layer whose joints land across the "
				+ "joints below:")
		for piece: Array in unjoined.slice(0, WORTH_SAYING):
			feedback += "\n  - " + _unjoined_said(model, piece)
		if unjoined.size() > WORTH_SAYING:
			feedback += "\n  ...and %d more like that." % (unjoined.size() - WORTH_SAYING)
	var items := PackedStringArray(apart["items"])
	if apart_loose == 0 and not items.is_empty():
		feedback += ("\n\n%s stand%s apart from the model, named."
			% [", ".join(items), "s" if items.size() == 1 else ""])
	# And the commonest way to arrive in pieces, which has its own fix.
	if (apart_loose > 0 or int(apart["against"]) > 0) and _one_layer(box_of):
		feedback += (" This is one layer thick, and one layer is "
			+ "always like this: bricks side by side are not "
			+ "joined, however tightly they are packed. A second "
			+ "layer over it, with its joints landing across the "
			+ "joints below, is what makes the whole thing one "
			+ "piece.")

	var checked: Dictionary = {
		"ok": ok,
		"summary": summary,
		"feedback": feedback,
		"advice": advice,
		"pieces": pieces,
		## Pieces apart from the model that nothing names, the names of the
		## ones that stand apart as items of their own, and how many pieces
		## those and the figures standing apart are.
		"loose": apart_loose,
		## A vehicle's parts on wheels in line with it that nothing couples.
		"uncoupled": uncoupled.size(),
		"items": apart["items"],
		"named": int(apart["named"]),
		## Of those, the figures: no name of their own to say.
		"figures": int(apart["figures"]),
		"kinds": issues.keys(),
		"floating": floating.keys(),
		"overlapping": overlapping,
		## Each piece, as indices into the placements, for a probe to say
		## where each one is.
		"each_piece": each_piece,
		## Pairs of standing bricks that overlap and were excused, [index,
		## other], for an audit of real sets to count.
		"standing_overlaps": collided,
		## What the exact check found (ExactCheck), kind -> sentences: what
		## review_model says before a design is handed over.
		"exact": {"collision": issues.get("collision", []),
			"not held": issues.get("not held", []),
			"tips over": issues.get("tips over", [])},
		## The parts of what is not held, as indices into the placements.
		"unheld": unheld.keys(),
		## The later part of each pair whose real shapes collide.
		"colliding": colliding.keys(),
		## And what asking the exact shapes cost this check, ms.
		"exact_ms": exact.spent_usec / 1000.0,
		"exact_on": exact.spent_on,
	}
	if weigh or (weigh_whole and ok and pieces <= 1):
		checked["balance"] = _weighed(model, lattice, placed_at, boxes_of, holds, alone)
	return checked


## Whether a design checked by check_design would stand, for the session:
## Balance over it as checked, or, once it stands in the world with parts
## that turn on a hinge or a turntable, over every pose they reach
## (Poser.sweep), as Tools, Check stability weighs it. Its bricks are
## named as the design numbers them, with where they are.
func _balance_said(report: Dictionary, trial: Model, applied: bool) -> String:
	var balance: Balance.Report = report.get("balance")
	var namer: Callable = func(id: int) -> String:
		if id <= 0 or id > trial.placements.size():
			return "a part already standing"
		var placement: Placement = trial.placements[id - 1]
		return "brick %d (%s at %s)" % [id - 1, placement.part, placement.where()]
	if applied and assemblies != null and builder != null and world != null:
		var poser := Poser.new()
		poser.world = world
		poser.builder = builder
		poser.library = library
		poser.assemblies = assemblies
		if poser.find() > 0:
			var judge := Balance.new()
			judge.library = library
			judge.lattice = builder.lattice
			judge.floor_ids = scenery
			balance = judge.measure(world.bricks(), poser.sweep())
			namer = func(id: int) -> String:
				var brick: BrickWorld.Brick = world.get_brick(id)
				return "#%d (%s)" % [id, brick.part_id] if brick != null else "#%d" % id
	return balance.said(namer) if balance != null else ""


## Whether a checked design would stand (Balance), on the lattice it was
## checked on: each placement that went in by its key there (its index and
## one), with whatever was standing already (the negative keys), and the
## pins, axles, clips, hinges, stickers and strings the check already found
## joining them.
func _weighed(model: Model, lattice: BrickLattice, placed_at: Dictionary,
		boxes_of: Dictionary, holds: Dictionary, alone: bool) -> Balance.Report:
	var bricks: Array = []
	for index: int in boxes_of:
		var placement: Placement = model.placements[index]
		bricks.append(BrickWorld.Brick.new(index + 1, placement.part, placement.color,
			placed_at[index]))
	if not alone and world != null:
		var key: int = -1
		for brick: BrickWorld.Brick in _others_standing(alone):
			if library.mesh_for(brick.part_id) == null:
				continue
			bricks.append(BrickWorld.Brick.new(key, brick.part_id, brick.color_code,
				brick.transform))
			key -= 1
	var links: Array = []
	for one: Variant in holds:
		for other: Variant in holds[one]:
			links.append([int(one) + 1, int(other) + 1])
	var judge := Balance.new()
	judge.library = library
	judge.lattice = lattice
	return judge.measure(bricks, [], links)


## The overlaps between bricks already standing that [method
## _between_standing] is about to excuse, kept as [index, other index]:
## not this design's to answer for, but a real set's parts do not overlap,
## so each one in a set read from a file is the cover of a part wrong
## (src/dev/connection_audit.gd counts them). Nothing reads them to decide.
static func _standing_overlaps(blockers: PackedInt64Array, placement: Placement,
		index: int, model: Model, into: Array) -> void:
	if blockers.is_empty() or placement.id == 0 or placement.moved:
		return
	for key: int in blockers:
		if key > 0 and key - 1 < model.placements.size():
			var other: Placement = model.placements[key - 1]
			if other.id != 0 and not other.moved:
				into.append([index, key - 1])


## What is left of [param blockers] for [param placement]: nothing, when it and
## the first thing it runs into were both standing already and neither has
## moved — not this design's to answer for (see [method _check]).
static func _between_standing(blockers: PackedInt64Array, placement: Placement,
		model: Model) -> PackedInt64Array:
	if blockers.is_empty() or placement.id == 0 or placement.moved:
		return blockers
	var first: int = blockers[0]
	if first > 0 and first - 1 < model.placements.size():
		var other: Placement = model.placements[first - 1]
		if other.id != 0 and not other.moved:
			return PackedInt64Array()
	return blockers


# -- the exact check (ExactCheck) ------------------------------------------


## Exact shapes, part id -> Exact.Shape, as [method _checked] found them
## before its worker began: a worker reads, never loads.
var _exact_now: Dictionary = {}
## The whole model's parts this assistant or a session placed count as this
## design's for the exact check, as well as what an edit adds or moves:
## review_model judges a design built from outside that way.
var _strict_mine: bool = false


## The exact shapes a check of [param model] reads, with what stands beside
## it: loaded here on the main thread, or as [method _checked] loaded them.
func _exact_shapes(model: Model, alone: bool) -> Dictionary:
	var ids: Array = _exact_ids(model, alone)
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		return Exact.shapes_for(library, ids)
	var out: Dictionary = {}
	for part_id: Variant in ids:
		if _exact_now.has(part_id):
			out[part_id] = _exact_now[part_id]
	return out


## The parts whose exact shapes a check of [param model] reads: its own, and
## (not [param alone]) those of the bricks standing beside it.
func _exact_ids(model: Model, alone: bool) -> Array:
	var ids: Dictionary = {}
	for placement: Placement in model.placements:
		ids[placement.part] = true
	if not alone and world != null:
		for brick: BrickWorld.Brick in _others_standing(alone):
			ids[brick.part_id] = true
	return ids.keys()


func _exact_check_for(model: Model, alone: bool) -> ExactCheck:
	return ExactCheck.new(_exact_shapes(model, alone), model.placements.size())


## Whether placement [param index] is this design's to answer for: placed or
## moved by it, or (reviewing a whole design) placed by it at all.
func _exact_subject(model: Model, index: int) -> bool:
	if index < 0 or index >= model.placements.size():
		return false
	var placement: Placement = model.placements[index]
	return placement.id == 0 or placement.moved or (_strict_mine and placement.mine)


## A part the exact check speaks of, by its item: a placement as the check
## numbers bricks, or a brick standing beside the design.
func _exact_name(model: Model, exact: ExactCheck, item: int) -> String:
	if item >= 0 and item < model.placements.size():
		var placement: Placement = model.placements[item]
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		var label: String = "#%d" % placement.id if placement.id != 0 and not placement.moved \
			else "brick %d" % item
		return "%s (%s %s at %s)" % [label, placement.part,
			info.name.strip_edges().replace("  ", " ").to_lower() if info != null else "",
			placement.where()]
	if item >= 0 and item < exact.parts.size():
		return "a %s already on the baseplate" % exact.parts[item]
	return "a part"


## Each part of this design that misses a connector by a few LDU and joins
## nothing exactly, moved onto it (ExactCheck.seat): its placement changed
## here, so what is checked and built is the seated one. Only a part square
## on the grid and in no section, whose move is whole cells: anything else
## cannot be said as a placement. Returns what was moved, said, or "".
func _seat_exactly(model: Model, exact: ExactCheck) -> String:
	if not exact.any() or library == null:
		return ""
	if not model.placements.any(func(p: Placement) -> bool:
			return (p.id == 0 or p.moved) and p.section.is_empty()):
		return ""
	var movable: Array = []
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null or not placement.odd_face.is_empty() or not placement.odd_axis.is_empty():
			continue
		if not placement.section.is_empty() and not model.sections.has(placement.section):
			continue
		exact.place(index, placement.part, placement.exact_at(_transform(placement, part,
			model.section_for(placement))))
		# What this change puts down or moves: a review judges what stands, and
		# says what to move rather than moving it.
		if (placement.id == 0 or placement.moved) and placement.section.is_empty():
			movable.append(index)
	if movable.is_empty():
		return ""
	var moved: Dictionary = exact.seat(movable)
	var said := PackedStringArray()
	for index: int in moved:
		var move: Vector3 = moved[index]
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		var at: Transform3D = _transform(placement, part).translated(move)
		var corner: Vector3i = _corner_cell(part, placement.part, at.basis)
		# The cell the seated origin is in, written as its own number of studs
		# and plates, and the rest of the way as a nudge: whole cells for a
		# move of whole cells, an LDU over for a round part's odd stud.
		var cell: Vector3i = BrickLattice.to_cell(at.origin + Vector3.ONE * 0.001)
		var was := [placement.x, placement.y, placement.z, placement.nudge]
		placement.x = _into_cell(cell.x + corner.x, STUD)
		placement.y = _into_cell(cell.y + corner.y, PLATE)
		placement.z = _into_cell(cell.z + corner.z, STUD)
		placement.nudge = Vector3.ZERO
		placement.nudge = at.origin - _transform(placement, part).origin
		if placement.nudge.length() < 0.001:
			placement.nudge = Vector3.ZERO
		if not _transform(placement, part).origin.is_equal_approx(at.origin):
			placement.x = was[0]
			placement.y = was[1]
			placement.z = was[2]
			placement.nudge = was[3]
			exact.place(index, placement.part, _transform(placement, part))
			continue
		if said.size() < WORTH_SAYING:
			said.append("brick %d (%s) %s" % [index, placement.part,
				ExactCheck._direction(move)])
		elif said.size() == WORTH_SAYING:
			said.append("...")
	if said.is_empty():
		return ""
	return ("Seated %d part%s exactly on the stud, hole, hinge or bar %s missed by a few LDU "
		% [moved.size(), "" if moved.size() == 1 else "s", "it" if moved.size() == 1 else "each"]
		+ "(the app does this on every check; nothing to change): %s." % ", ".join(said))


## Whether item [param i] is a placement in one of the prism pattern's own
## sections.
static func _in_a_prism(model: Model, i: int) -> bool:
	return i >= 0 and i < model.placements.size() \
		and model.placements[i].section.begins_with("prism ")


## Lattice cell [param cell] as a placement's studs or plates ([param per] LDU
## each): the number that reads back as that cell.
static func _into_cell(cell: int, per: float) -> float:
	var said: float = snappedf(float(cell) * BrickLattice.CELL / per, 0.0001)
	if int(floor(said * per / BrickLattice.CELL)) != cell:
		said += 0.00001
	return said


## The exact shapes' collisions that the lattice did not already refuse (see
## [method _check]), noted as faults where this design is in the pair. Dressing
## gives way, as it does to a lattice overlap; a pair of bricks standing goes
## into [param collided] for the audit of real sets; gears in [param meshing]
## are in mesh, not in each other.
func _exact_collisions(model: Model, exact: ExactCheck, issues: Dictionary,
		overlapping: Dictionary, gave_way: Dictionary, collided: Array,
		meshing: Dictionary = {}, colliding: Dictionary = {}) -> void:
	if not exact.any():
		return
	var count: int = model.placements.size()
	# The pairs this design is in; every pair when only the ground holds (the
	# audit of real sets, which counts what stands as well).
	var subjects: Dictionary = {}
	if not _ground_only:
		for index: int in count:
			if _exact_subject(model, index):
				subjects[index] = true
		if subjects.is_empty():
			return
	var already: Dictionary = {}
	for pair: Variant in collided:
		already[Vector2i(mini(int(pair[0]), int(pair[1])), maxi(int(pair[0]), int(pair[1])))] = true
	var namer: Callable = func(item: int) -> String: return _exact_name(model, exact, item)
	for found: Dictionary in exact.collisions(subjects):
		var a: int = found["a"]
		var b: int = found["b"]
		if _ground_only and (a >= count or b >= count):
			continue
		if overlapping.has(a) or overlapping.has(b):
			continue
		# Gears in mesh: their teeth interleave, which a convex piece a tooth
		# cannot say unless each is turned to the other's gap, and real sets
		# are drawn either way. Held by their axles, as the lattice has them.
		if (meshing.get(a, {}) as Dictionary).has(b) or (meshing.get(b, {}) as Dictionary).has(a):
			continue
		# The prism pattern's own turned walls, which meet each other and their
		# square summit inside each other by their real shapes: judged by the
		# lattice, as the turned studs under them are (_note_turned_studs),
		# until the pattern lays its corners another way.
		if _in_a_prism(model, a) or _in_a_prism(model, b):
			continue
		# A wheel drawn spun on its axle: in plastic the axle turns with it.
		if exact.turned_on_axle(a, b):
			continue
		var mine: bool = _exact_subject(model, a) or _exact_subject(model, b)
		if not mine:
			if a < count and b < count and not already.has(Vector2i(a, b)):
				collided.append([a, b])
			continue
		var dressed: int = -1
		for i: int in [a, b]:
			if i < count and model.placements[i].dressing:
				dressed = i
		if dressed >= 0:
			gave_way[dressed] = true
			continue
		_note(issues, "collision", exact.said(found, namer))
		# By index too, the later of the two, for what mends a design
		# (Brickify.mend) to take out as it does a part that overlaps.
		if maxi(a, b) < count:
			colliding[maxi(a, b)] = mini(a, b)


## The parts of this design no connection holds, by BrickNet's rules where
## both parts have an exact shape and by this check's own where one has not:
## a piece of them is held when it reaches the ground, a brick standing before
## this design (unless only the ground holds: _ground_only), or a part with no
## exact shape that this check holds. One fault a piece.
func _exact_unheld(model: Model, exact: ExactCheck, issues: Dictionary,
		crowded: Dictionary, cells_of: Dictionary, floating: Dictionary,
		holds: Dictionary, clutched_pairs: Array, stuck: Dictionary = {},
		unheld: Dictionary = {}) -> void:
	if not exact.any():
		return
	var count: int = model.placements.size()
	var subjects: Array[int] = []
	for index: int in cells_of:
		var section: String = model.placements[index].section
		if _exact_subject(model, index) and exact.items[index] != null \
				and not floating.has(index) and not crowded.has(section) \
				and not stuck.has(section) and not section.begins_with("prism "):
			subjects.append(index)
	if subjects.is_empty():
		return
	# The lattice's joins stand where the exact shapes cannot say: a part with
	# none, and the prism pattern's turned walls, whose studs the lattice
	# judges (_note_turned_studs) as it judges their meeting (_exact_collisions).
	var extra: Array = []
	for pair: Array in clutched_pairs:
		if exact.items[int(pair[0])] == null or exact.items[int(pair[1])] == null \
				or _in_a_prism(model, int(pair[0])) or _in_a_prism(model, int(pair[1])):
			extra.append([int(pair[0]), int(pair[1])])
	for index: Variant in holds:
		for other: Variant in holds[index]:
			if int(index) < count and int(other) < count \
					and (exact.items[int(index)] == null or exact.items[int(other)] == null
						or _in_a_prism(model, int(index)) or _in_a_prism(model, int(other))):
				extra.append([int(index), int(other)])
	# Only what is near this design's parts: anything else that stands is held
	# already, so a piece of them is held exactly when it reaches the ground or
	# something beside them that stands. An edit to a 9,000 part model asks
	# about its own few parts and their neighbours, not every stud in it.
	var near: Dictionary = {}
	for index: int in subjects:
		near[index] = true
	if not _ground_only and subjects.size() < exact.items.size():
		for pair: Vector2i in exact.pairs_near(near.duplicate(), -(Exact.POS_THR + 1.0)):
			near[pair.x] = true
			near[pair.y] = true
	else:
		for i: int in exact.items.size():
			near[i] = true
	# And what the lattice joins them to that has no shape to be near by: a
	# brick on a plate a file draws from parts it carries (joints_probe).
	var grew: bool = true
	while grew:
		grew = false
		for pair: Array in extra:
			if near.has(pair[0]) != near.has(pair[1]):
				near[pair[0]] = true
				near[pair[1]] = true
				grew = true
	var root: PackedInt32Array = exact.pieces(extra, near)
	var held: Dictionary = {}
	## Pieces held by something other than the floor: what stood before, or
	## what the lattice holds. The rest the floor alone holds, and on a bare
	## floor only while they balance (ExactCheck.tips).
	var held_otherwise: Dictionary = {}
	for i: int in exact.items.size():
		if not near.has(i):
			continue
		var other: bool = false
		if i >= count:
			other = not _ground_only
		elif not _exact_subject(model, i):
			other = not _ground_only
		elif exact.items[i] == null or _in_a_prism(model, i):
			# Held as the lattice has it, which judges these.
			other = cells_of.has(i) and not floating.has(i)
		if other:
			held_otherwise[root[i]] = true
		if other or exact.on_ground(i):
			held[root[i]] = true
	var pieces: Dictionary = {}    ## root -> its subjects
	for index: int in subjects:
		if held.has(root[index]):
			continue
		var members: Array = pieces.get(root[index], [])
		members.append(index)
		pieces[root[index]] = members
	var namer: Callable = func(item: int) -> String: return _exact_name(model, exact, item)
	for key: Variant in pieces:
		# Standing square on what is under it, clear of everything, it stays
		# where it is when the model stands, as BrickBench's simulation finds
		# it; that it comes away in the hand the loose advice says.
		if exact.rests(pieces[key]):
			continue
		_note(issues, "not held", exact.unheld_said(pieces[key], namer))
		# By index too, for what mends a design (Brickify.mend) to join or
		# take out, as it does a part floating.
		for index: Variant in pieces[key]:
			unheld[int(index)] = true
	# And what the floor alone holds, on a bare floor: it stands while it
	# balances. On a baseplate its studs hold it, as they do in the hand.
	if _ground_only or not _on_bare_floor(model):
		return
	var on_floor: Dictionary = {}    ## root -> its items
	var mine: Dictionary = {}
	for index: int in subjects:
		mine[root[index]] = true
	for i: int in exact.items.size():
		if near.has(i) and held.has(root[i]) and not held_otherwise.has(root[i]) \
				and mine.has(root[i]):
			var members: Array = on_floor.get(root[i], [])
			members.append(i)
			on_floor[root[i]] = members
	for key: Variant in on_floor:
		var found: Dictionary = exact.tips(on_floor[key])
		if not found.is_empty():
			_note(issues, "tips over", exact.tips_said(found, on_floor[key], namer))


## Whether [param model] stands on a bare floor, as a figure, a vehicle or a
## statue on a shelf does and as BrickBench stands every build: the design says
## so ("none" or "grid"), or the app's floor is one of those ([member
## floor_kind]). On a baseplate its studs hold what stands on them; with no
## floor known (a probe, a check of a piece) it is not asked.
func _on_bare_floor(model: Model) -> bool:
	var said: String = str(model.stands_on.get("kind", ""))
	if said.is_empty() and floor_kind.is_valid():
		said = str(floor_kind.call())
	return said == ModelFloor.NONE or said == ModelFloor.GRID


## How many separate pieces the design is in.
##
## Two bricks are in the same piece when one occupies a cell directly
## above a cell of the other, or when a stud of one reaches into the
## other — the same two rules that decide whether a brick is held up,
## so a design cannot be "every brick supported" and "in five pieces"
## for contradictory reasons.
## Dressing gives way: what is left of [param blockers] once the dressing
## among them, or the placement itself if it is dressing, has stepped
## aside into [param gave_way].
##
## A tile on a side stud is the finish on a face. Where the face meets
## something — a prism's core against the piers that hold it — a real
## build simply has no tile there, and refusing the whole design for it
## is refusing it for decoration. A run did exactly what that taught:
## "its sideways tiles were what hit them. I'll drop those tiles from the
## core", and the tower lost its texture to get past one corner.
static func _give_way(blockers: PackedInt64Array, placement: Placement,
		index: int, model: Model, gave_way: Dictionary) -> PackedInt64Array:
	if blockers.is_empty():
		return blockers
	if placement.dressing:
		gave_way[index] = true
		return PackedInt64Array()
	var solid := PackedInt64Array()
	for key: int in blockers:
		if key > 0 and key - 1 < model.placements.size() \
				and model.placements[key - 1].dressing:
			gave_way[key - 1] = true
		else:
			solid.append(key)
	return solid


## The design without the dressing that gave way, checked again as it was
## asked to be, and saying how much was left out. Checked again with only
## the first two asks, a Brickify scan's first check came back unweighed
## and full of advice, and its mend checked it a third time to weigh it.
func _without_dressing(model: Model, gave_way: Dictionary,
		alone: bool, weigh: bool = false, weigh_whole: bool = false,
		advise: bool = true) -> Dictionary:
	var kept: Array[Placement] = []
	for index: int in model.placements.size():
		if not gave_way.has(index):
			kept.append(model.placements[index])
	model.placements = kept
	var report: Dictionary = _check(model, alone, weigh, weigh_whole, advise)
	var left: int = gave_way.size()
	var said: String = ("%d finishing part%s (a tile on a side stud, a rim's wedge) would "
		% [left, "" if left == 1 else "s"]
		+ "have run into another part and %s left out; the rest keeps its finish."
		% ("was" if left == 1 else "were"))
	report["feedback"] = "%s\n%s" % [report["feedback"], said]
	(report["advice"] as Array).append(said)
	return report


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
			filled = BrickLattice.volume_of(cells_of[index])
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
		# A round brick or a cylinder half is the skin of a rocket, not a
		# plate under it: a body laid in them read as "structure, not yet
		# finished" at every size.
		if studs >= BIG_PART_STUDS and not Style.kinds_of(placement.part).contains("c"):
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


## Whether a model has the touches nearly every real set has and nobody
## asks for: a printed or stickered part, and something that moves.
##
## Measured over Rebrickable's inventories of the 2,517 sets of 300 parts
## or more since 2015: 95% carry a printed or stickered part and 94% a
## hinge, a turntable, a Technic pin or a ball joint, so each one missing
## is a tail of one set in twenty, the rule every advice here keeps. Every
## design the owner judged had neither: a Falcon Heavy of 4,252 parts with
## one printed minifigure head in it, an Orthanc with figures but nothing
## that opened. Said with the other touches an expert adds, because the
## advice is where a design that thinks it is finished still listens.
func _touches(model: Model) -> String:
	if model.placements.size() < TOUCHES_FROM or library == null:
		return ""
	var printed: bool = false
	var moving: bool = false
	for placement: Placement in model.placements:
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		if info == null:
			continue
		if _decorated(info):
			printed = true
		if Style.kinds_of(placement.part).contains("a") or info.has_connector("pin") \
				or info.has_connector("ball"):
			moving = true
	for section: Section in model.sections.values():
		if section.hinge:
			moving = true
	if printed and moving:
		return ""
	var missing := PackedStringArray()
	if not printed:
		missing.append("no printed or stickered part, where 95% of real sets of 300 "
			+ "parts or more have one — a gauge, a screen, a map, a logo, a nameplate: "
			+ "search_parts with \"print\" or \"sticker\" and the subject's own word")
	if not moving:
		missing.append("nothing that moves, where 94% have a hinge, a turntable, a "
			+ "Technic pin or a ball joint — a hatch, a door, a ramp, a turret: a "
			+ "section with hinge: true")
	return ("The touches an expert adds unasked: this has " + "; and ".join(missing)
		+ ". While you are there: a figure who belongs to it or a small scene "
		+ "hidden in it (add_minifig), a nod to the subject's story, and for a "
		+ "display model a stand with a nameplate.")


## Windows laid as a grid: one transparent part in one colour, many of
## them, most in rows. The homepage's Orthanc had 71 lit yellow 1 x 1s up
## every face at the same heights and read as an office block; the
## owner's verdict was the worst yet. A real set places few windows, each
## with a reason, and takes their colour from the subject.
func _window_grid(model: Model) -> String:
	if library == null:
		return ""
	var groups: Dictionary = {}   ## "part colour" -> [y, ...]
	for placement: Placement in model.placements:
		var colour: PartLibrary.BrickColor = library.colors.get(placement.color)
		# Lit: a warm transparent colour, yellow to red. Glass in rows is
		# how real buildings are glazed — Big Ben's facade is 380 trans-brown
		# 1 x 1s, Tower Bridge's 48 clear panes — and asked of eight real
		# sets, counting every transparent colour fired on three of them.
		if colour == null or colour.finish != "transparent" or colour.rgb.s < 0.4 \
				or colour.rgb.v < 0.5 or (colour.rgb.h > 0.18 and colour.rgb.h < 0.95):
			continue
		var key: String = "%s %d" % [placement.part, placement.color]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(snappedf(placement.y, 0.25))
	# The biggest group first: that is the grid the eye sees.
	var order: Array = groups.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return (groups[a] as Array).size() > (groups[b] as Array).size())
	for key: String in order:
		var heights: Array = groups[key]
		if heights.size() < WINDOW_GRID:
			continue
		var at: Dictionary = {}
		for y: float in heights:
			at[y] = int(at.get(y, 0)) + 1
		var in_rows: int = 0
		for y: float in heights:
			if int(at[y]) >= 4:
				in_rows += 1
		if float(in_rows) < 0.7 * heights.size():
			continue
		var named: PackedStringArray = key.split(" ")
		return ("%d of one lit window (%s in %s), most of them in rows at the same "
			% [heights.size(), named[0], _colour_name(int(named[1]))]
			+ "heights: a grid of windows reads as an office block, whatever the "
			+ "building is. Few windows, each with a reason — arched, framed, "
			+ "varied, gathered where something happens inside — and their colour "
			+ "from the subject: a dark fortress has dark slits, a lighthouse one "
			+ "lit lantern. Take most of these out and make the rest count.")
	return ""


## Dressing (parts on side studs) and a second tone scattered over a dark
## wall, where a real set textures one in ribs and grids. The Orthanc after the
## blades scattered round tiles, cheese slopes and grey across its black faces
## and read as noise. A wall is one plane of one face: dressing that looks the
## same way from the same depth, in a section's frame or the main body's, and a
## second tone in one row of bricks. Each storey that steps in is a wall of its
## own. It was the section, or the whole main body: a tower read back from a
## file, every face in one, had the rib up each storey's face counted against
## every course of the model, and was told 559 of its 593 pieces of dressing
## were scattered when 67 were. A wall's colour is the commonest of its
## section's plain parts. A mark is organised when its column holds most of
## the courses its wall is marked in (a rib) or its course most of the columns
## (a band), and at least SPECKLE_LINE of them: one round plate on its own is
## not a rib. A second tone counts in a section only, so mottled rock is not
## speckle.
const SPECKLE_FROM := 24
const SPECKLE_COVER := 0.6
const SPECKLE_LINE := 3
## What lies on a side stud as dressing.
const SPECKS: Array[String] = ["3070b", "98138", "4073", "6141", "54200", "3024"]


## The marks over dark walls, each [placement, wall, its columns, course], their
## wall's colour, and which of them are scattered: {"marks", "colour",
## "scattered"} (a bool for each mark).
func _speckle_marks(model: Model) -> Dictionary:
	var found := {"marks": [], "colour": -1, "scattered": []}
	if library == null:
		return found
	var counts: Dictionary = {}    ## section -> {colour: plain parts}
	for placement: Placement in model.placements:
		if placement.face != "up" or not Style.kinds_of(placement.part).contains("p"):
			continue
		if not counts.has(placement.section):
			counts[placement.section] = {}
		var of: Dictionary = counts[placement.section]
		of[placement.color] = int(of.get(placement.color, 0)) + 1
	var wall_of: Dictionary = {}
	for key: Variant in counts:
		var best: int = -1
		var most: int = 0
		for code: Variant in counts[key]:
			if int(counts[key][code]) > most:
				most = int(counts[key][code])
				best = int(code)
		wall_of[key] = best
	var marks: Array = []
	var wall_rows: Dictionary = {}    ## wall -> {course: true}
	var wall_columns: Dictionary = {}    ## wall -> {column: true}
	var column_rows: Dictionary = {}    ## column -> {course: true}
	var row_columns: Dictionary = {}    ## course -> {column: true}
	for placement: Placement in model.placements:
		var wall_colour: int = int(wall_of.get(placement.section, -1))
		if wall_colour < 0 or not _is_dark(wall_colour):
			continue
		var tint: PartLibrary.BrickColor = library.color(placement.color)
		if tint == null or tint.is_transparent():
			continue
		var dressing: bool = placement.dressing \
			or (placement.face != "up" and placement.part in SPECKS)
		var accent: bool = not placement.section.is_empty() and placement.color != wall_colour \
			and not _is_dark(placement.color) and Style.kinds_of(placement.part).contains("p")
		if not dressing and not accent:
			continue
		var wall: String
		var along: float
		var long: int = 1
		if dressing:
			# The plane it lies on: the face it looks out of, at the depth of
			# the side it is pressed against.
			var deep: float = placement.z
			along = placement.x
			if placement.face in ["+x", "-x"]:
				deep = placement.x
				along = placement.z
			elif not placement.face in ["+z", "-z"]:
				deep = placement.y
			if placement.face.begins_with("-"):
				var info: PartLibrary.PartInfo = library.parts.get(placement.part)
				deep += info.size.y / STUD if info != null else 0.0
			wall = "%s|%s|%d" % [placement.section, placement.face, roundi(deep)]
		else:
			# One row of bricks, along x or along z by its turn, each of its
			# studs a column: a course of grey laid in bricks of any length is
			# a band whatever its joints.
			var across: float = placement.z if placement.rot % 2 == 0 else placement.x
			along = placement.x if placement.rot % 2 == 0 else placement.z
			wall = "%s|row %d|%d" % [placement.section, placement.rot % 2, floori(across + 0.01)]
			var info: PartLibrary.PartInfo = library.parts.get(placement.part)
			if info != null:
				long = maxi(1, roundi(info.size.x / STUD))
		var columns := PackedStringArray()
		for step: int in long:
			columns.append("%s|%s" % [wall, snappedf(along + step, 0.5)])
		var course: String = "%s|%s" % [wall, snappedf(placement.y, 0.5)]
		if not wall_rows.has(wall):
			wall_rows[wall] = {}
			wall_columns[wall] = {}
		if not row_columns.has(course):
			row_columns[course] = {}
		(wall_rows[wall] as Dictionary)[course] = true
		for column: String in columns:
			(wall_columns[wall] as Dictionary)[column] = true
			(row_columns[course] as Dictionary)[column] = true
			if not column_rows.has(column):
				column_rows[column] = {}
			(column_rows[column] as Dictionary)[course] = true
		marks.append([placement, wall, columns, course])
		found["colour"] = wall_colour
	var scattered: Array = []
	for mark: Array in marks:
		var courses: int = (wall_rows[mark[1]] as Dictionary).size()
		var rib: bool = false
		for column: String in mark[2]:
			var up: int = (column_rows[column] as Dictionary).size()
			if up >= SPECKLE_LINE and float(up) / courses >= SPECKLE_COVER:
				rib = true
		var across: int = (row_columns[mark[3]] as Dictionary).size()
		var band: bool = across >= SPECKLE_LINE \
			and float(across) / (wall_columns[mark[1]] as Dictionary).size() >= SPECKLE_COVER
		scattered.append(not rib and not band)
	found["marks"] = marks
	found["scattered"] = scattered
	return found


## Dressing an edit lays a part at a time over a dark wall, refused before it
## is built: SPRINKLED_FROM pieces or more of it scattered, or any of it when
## the whole would then be speckle. The detail pass of run 4 of the Orthanc
## placed its dressing tile by tile, and words against speckle never stopped
## a run doing it; a refusal that names the call that does it whole does.
const SPRINKLED_FROM := 6
## Set while a call that lays a whole structure (restyle_model, add_rooms)
## makes its edit: what it lays is a wall's ribs or a room's furniture, not
## dressing placed a part at a time.
var _laying_whole: bool = false
## Set while a pass lays its own proposal: edit_model answers without a picture.
var _quiet_edit: bool = false
## And the pieces the model is in while it lays one that takes parts off: an
## edit that would leave more is refused. -1 when nothing is kept to.
var _keep_pieces: int = -1


func _sprinkled(model: Model) -> String:
	var found: Dictionary = _speckle_marks(model)
	var marks: Array = found["marks"]
	var scattered: Array = found["scattered"]
	var laid: int = 0
	var alone: int = 0
	for n: int in marks.size():
		var placement: Placement = marks[n][0]
		if placement.id != 0 and not placement.moved:
			continue
		laid += 1
		if bool(scattered[n]):
			alone += 1
	var whole: int = scattered.count(true)
	var speckled: bool = whole >= SPECKLE_FROM and whole >= 0.4 * marks.size()
	if alone == 0 or (not speckled and (alone < SPRINKLED_FROM or alone < 0.4 * laid)):
		return ""
	return ("%d of the %d parts this edit lays dressing the %s walls, or in a "
		% [alone, laid, _colour_name(int(found["colour"]))]
		+ "second tone on them, stand one by one, in no column and no course: "
		+ "over a dark wall that reads as speckle. " + DRESS_HOW)


func _speckle(model: Model) -> String:
	var found: Dictionary = _speckle_marks(model)
	var marks: Array = found["marks"]
	var scattered: int = (found["scattered"] as Array).count(true)
	if scattered < SPECKLE_FROM or scattered < 0.4 * marks.size():
		return ""
	return ("%d of the %d parts dressing the %s walls, or in a second tone on them, "
		% [scattered, marks.size(), _colour_name(int(found["colour"]))]
		+ "are scattered one by one: over a dark wall that reads as speckle, as "
		+ "noise, the way a grid of windows reads as an office block. A real set "
		+ "textures a dark wall in ribs and grids — a column of round plates or "
		+ "grille up the middle of each face, grille bricks in a band, panels "
		+ "between pilasters — and puts its second tone on ledges and string "
		+ "courses. " + DRESS_HOW)


## Slits of sky through the model up to a stud and a half wide, seen from any
## of the eight ways round it a picture is taken from: a seam or a groove with
## nothing behind it. The run after the blades opened its tower's back for its
## rooms, and from the corner a slit of sky ran up a cleft, a crack through
## the tower; the run after that had one a stud wide straight through its
## piers, and was told only of the narrower ones. Measured as patterns_probe's
## daylight check measures it, off each part's own box laid flat in plan; a
## slit under DAYLIGHT_SLIT.x is under a pixel at a display model's size, and
## past DAYLIGHT_SLIT.y is a space between two things. A crack runs up the
## model, so a slit counts from a way round where it is seen at DAYLIGHT_RUNS
## of the nine heights or more: at one height only it is the sky between a
## rock and the tower it stands against, at the foot of the guidance's tower.
const DAYLIGHT_SLIT := Vector2(0.1, 1.5)
const DAYLIGHT_RUNS := 2
const DAYLIGHT_FROM := 200


func _daylight(model: Model) -> String:
	if library == null or model.placements.size() < DAYLIGHT_FROM:
		return ""
	var prints: Array = []
	var low: float = INF
	var high: float = -INF
	for placement: Placement in model.placements:
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			continue
		var at: Transform3D = _transform(placement, mesh, model.section_for(placement))
		var corners := PackedVector2Array()
		var lo: float = INF
		var hi: float = -INF
		for k: int in 8:
			var point: Vector3 = at * mesh.bounds.get_endpoint(k)
			corners.append(Vector2(point.x / STUD, point.z / STUD))
			lo = minf(lo, point.y / PLATE)
			hi = maxf(hi, point.y / PLATE)
		prints.append([corners, lo, hi])
		low = minf(low, lo)
		high = maxf(high, hi)
	var seen: Dictionary = {}    ## heading -> heights a slit is at
	for heading: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var across := Vector2(cos(deg_to_rad(heading)), -sin(deg_to_rad(heading)))
		# Each part's span across the view once, sorted, then filtered by height.
		var all: Array = []
		for one: Array in prints:
			var lo: float = INF
			var hi: float = -INF
			for corner: Vector2 in one[0]:
				lo = minf(lo, corner.dot(across))
				hi = maxf(hi, corner.dot(across))
			all.append([lo, hi, float(one[1]), float(one[2])])
		all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for n: int in 9:
			var y: float = low + (high - low) * (n + 1) / 10.0
			var spans: Array = []
			for one: Array in all:
				if y > float(one[2]) + 0.01 and y < float(one[3]) - 0.01:
					spans.append(Vector2(float(one[0]), float(one[1])))
			var reach: float = INF if spans.is_empty() else (spans[0] as Vector2).y
			for span: Vector2 in spans:
				var gap: float = span.x - reach
				if gap > DAYLIGHT_SLIT.x and gap < DAYLIGHT_SLIT.y:
					if not seen.has(heading):
						seen[heading] = []
					(seen[heading] as Array).append(roundi(y))
					break
				reach = maxf(reach, span.y)
	for heading: Variant in seen.keys():
		if (seen[heading] as Array).size() < DAYLIGHT_RUNS:
			seen.erase(heading)
	if seen.is_empty():
		return ""
	var said := PackedStringArray()
	for heading: Variant in seen:
		said.append("from %d degrees at y %s" % [int(heading),
			", ".join(PackedStringArray((seen[heading] as Array).map(
				func(h: int) -> String: return str(h))))])
	return ("Sky shows through it in slits up to a stud and a half wide, %s (0 is the front, 90 "
		% "; ".join(said) + "the right): a seam or a groove with nothing behind it, "
		+ "which a picture shows as a crack through the model. A tower opened at the "
		+ "back for its rooms shows the sky up its clefts. Close each behind — a "
		+ "post or a wall behind the seam, the face carried on round its corner — "
		+ "or leave the back closed.")


## A base much wider than the body standing on it, under a tall display model:
## the Orthanc after the blades stood its tower on a flat 66-stud yard with rock
## piles, 1.9 times as tall as wide where its tower alone was 3.3. 10237's base
## is 21 cm across under a tower 16 cm wide.
##
## A yard is open ground: YARD_OPEN of its area or more with nothing rising
## off it (the tower on a 60-stud yard, 75%). The bench's crane, its deck over
## all of its chassis (18% open), and its bonsai, the pot under the tree's
## pads (none), were called yards for being wider than a boom and a trunk
## half way up. And a stand is not a yard: one the brief asks for, or one the
## design names as one (most of the base an assembly called a stand, a plinth,
## a mount or a pot), is the display feature it is. The bench's owl, astronaut
## and Falcon Heavy were each told the stand they were asked for was a yard.
const YARD_WIDER := 1.6
const YARD_OPEN := 0.5
## Whole words, a stand's own plural left out: "it stands on a rock" asks for none.
const STAND_WORDS := ("stand|plinth|plinths|pedestal|pedestals|podium|plaque|nameplate|"
	+ "display base|mount|pot|pots|planter|launch pad")


func _wide_yard(model: Model, box_of: Dictionary) -> String:
	if box_of.size() < DAYLIGHT_FROM:
		return ""
	var stand := RegEx.create_from_string("\\b(%s)\\b" % STAND_WORDS)
	if stand.search(("%s %s %s" % [_brief, model.name, model.description]).to_lower()) != null:
		return ""
	var low: int = 1 << 30
	var high: int = -(1 << 30)
	for index: int in box_of:
		low = mini(low, (box_of[index][0] as Vector3i).y)
		high = maxi(high, (box_of[index][1] as Vector3i).y)
	var middle: int = (low + high) / 2
	var foot: int = low + 6 * BrickLattice.CELLS_PER_PLATE
	var body := Rect2i()
	var base := Rect2i()
	var have_body: bool = false
	var have_base: bool = false
	var ground: Dictionary = {}     ## a stud of the base's plan -> true
	var covered: Dictionary = {}    ## a stud something rises off -> true
	var in_base: int = 0
	var standing: int = 0
	var names: Dictionary = {}      ## assembly -> whether it is a stand
	var stud: int = BrickLattice.CELLS_PER_STUD
	for index: int in box_of:
		var lo: Vector3i = box_of[index][0]
		var hi: Vector3i = box_of[index][1]
		var plan := Rect2i(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z)
		if lo.y <= middle and hi.y >= middle:
			body = plan if not have_body else body.merge(plan)
			have_body = true
		var studs: Array = []
		for x: int in range(floori(float(lo.x) / stud), ceili(float(hi.x) / stud)):
			for z: int in range(floori(float(lo.z) / stud), ceili(float(hi.z) / stud)):
				studs.append(Vector2i(x, z))
		if hi.y > foot:
			for at: Vector2i in studs:
				covered[at] = true
		if lo.y < foot:
			base = plan if not have_base else base.merge(plan)
			have_base = true
			for at: Vector2i in studs:
				ground[at] = true
			in_base += 1
			var named: String = _assembly_of(model, model.placements[index])
			if not names.has(named):
				names[named] = stand.search(named.to_lower()) != null
			if bool(names[named]):
				standing += 1
	if not have_body or not have_base or standing * 2 >= in_base:
		return ""
	var body_wide: float = float(maxi(body.size.x, body.size.y)) / BrickLattice.CELLS_PER_STUD
	var base_wide: float = float(maxi(base.size.x, base.size.y)) / BrickLattice.CELLS_PER_STUD
	var tall: float = float(high - low) / BrickLattice.CELLS_PER_STUD
	if body_wide <= 0.0 or tall < 2.0 * body_wide or base_wide < YARD_WIDER * body_wide:
		return ""
	var open: int = 0
	for at: Vector2i in ground:
		if not covered.has(at):
			open += 1
	if open < YARD_OPEN * ground.size():
		return ""
	return ("Its base is %d studs across under a body %d wide, half way up: a tall "
		% [roundi(base_wide), roundi(body_wide)] + "display model stands on a base "
		+ "that hugs it — 10237's is 21 cm under a tower 16 cm wide. A wide flat yard "
		+ "round it, pale above all, is not a display base and makes the whole squat. "
		+ "Make the base close to its foot: a plinth of terraces, and rock rising "
		+ "against it in dark tones (a prism's \"plinth\": {\"rock\": true}). If it is "
		+ "a display stand, name it one (an assembly called a stand) and it is not a yard.")


## A model mostly plain bricks in one dark colour. In a picture a dark face
## with nothing on it is a hole: the homepage's Orthanc was black on black
## and read as a void. 10237, LEGO's own Orthanc, is 66% black and breaks
## it with 86 grille bricks, 63 headlight bricks, 58 bricks with handles,
## 47 cheese slopes, 36 curved 10 x 1 ribs and 13% dark bluish grey.
func _dark_and_plain(model: Model) -> String:
	if model.placements.size() < DARK_FROM or library == null:
		return ""
	var dark: Dictionary = {}
	for placement: Placement in model.placements:
		var colour: PartLibrary.BrickColor = library.colors.get(placement.color)
		if colour == null or colour.rgb.get_luminance() > DARK_LUMINANCE \
				or not Style.kinds_of(placement.part).contains("p"):
			continue
		dark[placement.color] = int(dark.get(placement.color, 0)) + 1
	for code: int in dark:
		var share: float = float(dark[code]) / model.placements.size()
		if share < DARK_AND_PLAIN:
			continue
		return ("%d%% of the model is plain bricks and plates in %s. A big dark "
			% [roundi(share * 100.0), _colour_name(code)]
			+ "face with nothing on it reads as a hole in a picture. Break it up "
			+ "the way 10237 Tower of Orthanc breaks up its black: texture in the "
			+ "same colour (grille bricks 2877, masonry 98283, bricks with a "
			+ "handle 2921, headlight bricks, cheese slopes, ingots) for most "
			+ "of it; a second tone in bands, where the ledges and string "
			+ "courses are (dark bluish grey on black: band_color), never "
			+ "sprinkled through the bricks, which reads as noise; and depth — "
			+ "an inset or outset course, a pilaster, a rib — so light and "
			+ "shadow draw the form. One call lays it on what stands: "
			+ "restyle_model, which on a dark wall lays panels of grille between "
			+ "ribs of round plates, framed plain, unasked (\"style\" for ribs, "
			+ "bands, a grid or recessed courses).")
	return ""


## A tall model the same width all the way up: no taper, no flare, no
## crown growing out of it. The homepage's Orthanc was square shafts
## glued together, the horns reading as spikes stuck on. Not said of a
## subject that is a straight round (a rocket, a column): its straightness
## is its shape.
func _straight_shaft(model: Model, box_of: Dictionary) -> String:
	if box_of.size() < DARK_FROM:
		return ""
	var about: String = "%s %s %s" % [_brief, model.name, model.description]
	var traits: Dictionary = Style.traits_of(about)
	if traits.has("round") or traits.has("vehicle"):
		return ""
	var low: Dictionary = {}    ## plate layer -> Vector2i low x, z in cells
	var high: Dictionary = {}
	for index: int in box_of:
		var corners: Array = box_of[index]
		var lo: Vector3i = corners[0]
		var hi: Vector3i = corners[1]
		for layer: int in range(floori(float(lo.y) / BrickLattice.CELLS_PER_PLATE),
				floori(float(hi.y) / BrickLattice.CELLS_PER_PLATE) + 1):
			var was_lo: Vector2i = low.get(layer, Vector2i(lo.x, lo.z))
			var was_hi: Vector2i = high.get(layer, Vector2i(hi.x, hi.z))
			low[layer] = Vector2i(mini(was_lo.x, lo.x), mini(was_lo.y, lo.z))
			high[layer] = Vector2i(maxi(was_hi.x, hi.x), maxi(was_hi.y, hi.z))
	var layers: Array = low.keys()
	if layers.size() < 30:
		return ""
	layers.sort()
	var tall: float = layers.size() / 2.5            ## studs
	var widths: Array = []
	for n: int in range(layers.size() / 10, layers.size() * 9 / 10):
		var span: Vector2i = (high[layers[n]] as Vector2i) - (low[layers[n]] as Vector2i)
		widths.append(float(maxi(span.x, span.y)) / BrickLattice.CELLS_PER_STUD)
	var widest: float = widths.max()
	var narrowest: float = widths.min()
	if tall < 2.0 * widest or widest - narrowest > STRAIGHT_WITHIN * widest:
		return ""
	return ("It rises %d studs as one straight shaft about %d across, the same "
		% [roundi(tall), roundi(widest)]
		+ "width from a tenth of its height to nine tenths. A tall subject's profile "
		+ "is its design: let it taper, flare at the foot, gather at a waist, and "
		+ "let its top grow out of the body — an oversail on inverted slopes, a "
		+ "corbelled crown, a spire stepping in (show_technique \"oversail on "
		+ "inverted slopes\", \"turret spire\") — rather than a cap with spikes "
		+ "stuck on. A prism with \"storeys\" steps in on a ledge at each storey in "
		+ "one call; the base should lead the eye up, a composed plinth and not rubble "
		+ "ringed round its foot.")


## Twelve of one window before a grid of them is a pattern and not a choice.
const WINDOW_GRID := 12
## From this many parts, a model has faces big enough to read as holes.
const DARK_FROM := 200
## Darker than this (CIELAB-ish luminance of the plastic's colour) is dark:
## black, dark brown, dark blue, dark green — not dark bluish grey.
const DARK_LUMINANCE := 0.2
## And this share of the model plain in one dark colour is a void. The
## shipped models and real sets are measured in patterns_probe/style_probe.
const DARK_AND_PLAIN := 0.4
## How much a shaft's width may vary, as a share of it, and still be
## straight: run 18's Orthanc varied 2.5 studs in 28 with its dressing and
## windows, a tapering tower a third or more.
const STRAIGHT_WITHIN := 0.12


## A part with a print or a sticker on it: LDraw files them as their
## plain part's number with a pattern after it (3069bp01, 4515d03).
func _decorated(info: PartLibrary.PartInfo) -> bool:
	return info.name.contains("Sticker") or info.name.contains("Pattern") \
		or _decorated_id.search(info.id) != null


static var _decorated_id := RegEx.create_from_string("[0-9][a-z]?(p[0-9a-z]{2,}|d[0-9a-z]{2,}|pr[0-9]+)$")
## Below this many parts a model is a vignette, and the touches are a
## matter of taste.
const TOUCHES_FROM := 300


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
				# Only where the part is: a wedge plate fills half its box, and
				# a mirror pair of 2 x 3 wings, each the other's reflection,
				# was called lopsided for the empty half of each box.
				if lattice.brick_at(point) != index + 1:
					continue
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
			+ "person sees first. If it is not meant to be — rock, a "
			+ "ruin, a tree, a tower grown out of a crag — a few bricks "
			+ "do not make it asymmetric, they make it look like a "
			+ "mistake: make the difference large and deliberate.")
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


## The pieces that touch another, face to face or a hair apart, as pairs of
## piece numbers: piece -> {piece: true}. Bricks laid side by side touch and
## are not joined, which is a seam or one layer (said by their own advice);
## a piece that touches nothing of the model stands apart from it. Near is
## within [constant NEAR] lattice cells, across, up and along.
func _touching(pieces: Array, lattice: BrickLattice, boxes_of: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if pieces.size() <= 1:
		return out
	var piece_of: Dictionary = {}
	for n: int in pieces.size():
		for index: int in pieces[n]:
			piece_of[index] = n
	# The largest piece is found from the others' side: touching is both ways.
	var largest: int = 0
	for n: int in pieces.size():
		if (pieces[n] as Array).size() > (pieces[largest] as Array).size():
			largest = n
	for n: int in pieces.size():
		if n == largest:
			continue
		for index: int in pieces[n]:
			var packed: PackedInt32Array = boxes_of.get(index, PackedInt32Array())
			var grown := PackedInt32Array()
			grown.resize(packed.size())
			for b: int in range(0, packed.size(), 6):
				for k: int in 3:
					grown[b + k] = packed[b + k] - NEAR[k]
					grown[b + 3 + k] = packed[b + 3 + k] + NEAR[k]
			for key: int in lattice.blockers_boxes(grown, index + 1):
				var other: int = int(piece_of.get(key - 1, -1))
				if key <= 0 or other < 0 or other == n:
					continue
				if not out.has(n):
					out[n] = {}
				if not out.has(other):
					out[other] = {}
				(out[n] as Dictionary)[other] = true
				(out[other] as Dictionary)[n] = true
	return out


## The pieces whose plan lies outside the plan of all the others, by more
## than [constant NEAR]: n -> true. A nameplate on the ground in front of a
## car; not one face of a prism among the others.
static func _outside(pieces: Array, box_of: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if pieces.size() <= 1:
		return out
	var plans: Array = []
	for piece: Array in pieces:
		var lo := Vector2i(1 << 30, 1 << 30)
		var hi := -lo
		for index: int in piece:
			var corners: Array = box_of.get(index, [])
			if corners.is_empty():
				continue
			var a: Vector3i = corners[0]
			var b: Vector3i = corners[1]
			lo = Vector2i(mini(lo.x, a.x), mini(lo.y, a.z))
			hi = Vector2i(maxi(hi.x, b.x), maxi(hi.y, b.z))
		plans.append([lo, hi])
	# The plan of all the others, for each: the least and the next least of
	# every low edge, the most and the next most of every high one, so the
	# others' are the first unless it is this piece's own. Piece by piece
	# against every other piece, a real set's thousand pieces were a million
	# reads.
	var least: Array = [_two_most(plans, 0, 0, -1), _two_most(plans, 0, 1, -1)]
	var most: Array = [_two_most(plans, 1, 0, 1), _two_most(plans, 1, 1, 1)]
	for n: int in pieces.size():
		var lo := Vector2i(int(least[0][1] if int(least[0][0]) == n else least[0][2]) * -1,
			int(least[1][1] if int(least[1][0]) == n else least[1][2]) * -1)
		var hi := Vector2i(int(most[0][1] if int(most[0][0]) == n else most[0][2]),
			int(most[1][1] if int(most[1][0]) == n else most[1][2]))
		var mine_lo: Vector2i = plans[n][0]
		var mine_hi: Vector2i = plans[n][1]
		var apart: bool = mine_lo.x > hi.x + NEAR[0] or mine_hi.x < lo.x - NEAR[0] \
			or mine_lo.y > hi.y + NEAR[2] or mine_hi.y < lo.y - NEAR[2]
		if apart:
			out[n] = true
	return out


## Of every plan's corner [param corner] (0 low, 1 high), axis [param axis]
## of it, times [param facing]: [which plan has the most, the most of the
## others (the next most), the most]. -(1 << 30) for an axis no other has.
static func _two_most(plans: Array, corner: int, axis: int, facing: int) -> Array:
	var best: int = -(1 << 30)
	var at: int = -1
	var next: int = -(1 << 30)
	for n: int in plans.size():
		var value: int = (plans[n][corner] as Vector2i)[axis] * facing
		if at < 0 or value > best:
			next = best if at >= 0 else next
			best = value
			at = n
		elif value > next:
			next = value
	return [at, next, best]


## Which pieces standing apart from the model (touching nothing of it) are
## there on purpose, and which came loose: {"loose": the pieces nothing
## names, "unjoined": the design's pieces against the model that nothing
## joins, to be said where they are, "items": the names of the rest}.
##
## The held-out sports car finished in two pieces and said every check
## passed: a nameplate on a plate lay on the ground in front of it, joined
## to nothing. It was meant — "a nameplate plaque in front of the car" —
## and nothing about it said so: the check called it a remark, and a part
## that has come off a model reads exactly the same. So a piece apart from
## the model is an item of its own only when it is named: every part of it
## in one assembly (the design's named box, or a file's sub-model) that
## holds none of the model's own, or a whole figure. Anything else is
## loose, and fails. The model is the largest piece with a part of the
## design's in it; a piece of the person's own is theirs to leave.
##
## [param touching_of] and [param outside_of] hand over [method _touching]'s
## and [method _outside]'s answers, worked out only when they are wanted.
func _standing_apart(model: Model, pieces: Array, floating: Dictionary = {},
		touching_of: Callable = Callable(), outside_of: Callable = Callable(),
		box_of: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"loose": [], "unjoined": [], "items": PackedStringArray(),
		"against": 0, "named": 0, "figures": 0, "uncoupled": []}
	if pieces.size() <= 1:
		return out
	var main: int = -1
	for n: int in pieces.size():
		var designed: bool = false
		for index: int in pieces[n]:
			if model.placements[index].mine:
				designed = true
				break
		if designed and (main < 0
				or (pieces[n] as Array).size() > (pieces[main] as Array).size()):
			main = n
	if main < 0:
		# All the person's own: said, as it always was, and theirs to leave.
		out["against"] = pieces.size() - 1
		return out
	var touching: Dictionary = touching_of.call() if touching_of.is_valid() else {}
	var outside: Dictionary = outside_of.call() if outside_of.is_valid() else {}
	var main_names: Dictionary = {}
	for index: int in pieces[main]:
		main_names[_assembly_of(model, model.placements[index])] = true
	# What touches the model, or touches what does: walls side by side that
	# nothing bonds, a door beside its frame, a base whose second layer of
	# plates lies joint on joint over the first. Not standing apart, and not
	# joined either: said, each where it is. The held-out owl finished in
	# seven pieces that touched, told only how many.
	var against: Dictionary = {main: true}
	var reach: Array = [main]
	while not reach.is_empty():
		var here: int = reach.pop_back()
		for other: Variant in touching.get(here, {}):
			if not against.has(other):
				against[other] = true
				reach.append(other)
	for n: int in pieces.size():
		if n == main:
			continue
		var piece: Array = pieces[n]
		# A whole figure of the design's is an item of its own wherever it
		# stands, as it is standing apart: beside the model with a hand on its
		# hull, or on a courtyard's floor. The bench's starfighter pilot, on the
		# ground by its nose, and its crane's rigger and supervisor were each a
		# piece against the model, joined to nothing, and failed the probe.
		if (against.has(n) or not outside.has(n)) and _our_figure(model, piece, floating):
			out["named"] = int(out["named"]) + 1
			out["figures"] = int(out["figures"]) + 1
			continue
		# A vehicle's own part beside it, in line with it on wheels of its own
		# — a tender, a trailer, a carriage — is coupled to it, or it stays
		# behind when the model is pulled, named or not. The shapes round's
		# locomotive came out in two pieces, its tender butted against the
		# drawbar plate with no hitch or magnet, and the check said only that
		# it was a piece against the model, to join with a plate across.
		var coupled: Dictionary = _uncoupled(model, piece, pieces[main], floating, box_of)
		if not coupled.is_empty():
			(out["uncoupled"] as Array).append(coupled)
			continue
		# Inside the model's plan — a face of a prism against its posts, a
		# part on the floor of a courtyard — is not standing apart from it.
		if not against.has(n) and not outside.has(n):
			out["against"] = int(out["against"]) + 1
			continue
		var designed: bool = false
		var adrift: bool = true
		var names: Dictionary = {}
		var parts: Array = []
		for index: int in piece:
			var placement: Placement = model.placements[index]
			designed = designed or placement.mine
			adrift = adrift and floating.has(index)
			names[_assembly_of(model, placement)] = true
			parts.append({"part": placement.part})
		# Against the model: said, with where each one of the design's is, so
		# a design can lay a part across the joint. Not refused: the prisms,
		# rooms, round towers and one-layer walls the patterns lay are in
		# pieces that touch (a prism's faces against its core), and 26 of
		# their probes' models failed when it was a fault.
		if against.has(n):
			out["against"] = int(out["against"]) + 1
			if designed and not adrift:
				(out["unjoined"] as Array).append(piece)
			continue
		# Held by nothing is said already, part by part; the person's own
		# is theirs to leave.
		if not designed or adrift:
			continue
		# Named when every part of it is in an assembly the model has no
		# part in: a nameplate, or a nameplate with a figure standing on it
		# (the held-out car's, two assemblies in one piece).
		var own: bool = not names.has("")
		for name: Variant in names:
			own = own and not main_names.has(name)
		if own:
			# A packed array is a value: appended to through the
			# dictionary, the name went into a copy.
			var items: PackedStringArray = out["items"]
			for name: Variant in names:
				if not items.has(str(name)):
					items.append(str(name))
			out["items"] = items
			out["named"] = int(out["named"]) + 1
			continue
		if _a_figure(parts):
			out["named"] = int(out["named"]) + 1
			out["figures"] = int(out["figures"]) + 1
			continue
		# A piece apart of a size with the model is a scene's other thing —
		# a jetty by a boat, a tree by a house, a second tower — said as it
		# always was. One much smaller than the model is a part come off or
		# an item, and only a name says which.
		if piece.size() * SCENE >= (pieces[main] as Array).size():
			out["against"] = int(out["against"]) + 1
			continue
		(out["loose"] as Array).append(piece)
	return out


## A piece apart from the model with fewer than one part in this many of
## the model's is an item or a part come off: a nameplate of 7 parts by a
## car of 537.
const SCENE := 10


## Whether a piece is a whole figure the design placed, standing on something
## rather than held by nothing. Its parts known by the library's names: the
## starfighter's pilot wore 24581p01, a baby's head, which the figure table
## by number does not list.
func _our_figure(model: Model, piece: Array, floating: Dictionary) -> bool:
	var designed: bool = false
	var adrift: bool = true
	var parts: Array = []
	for index: int in piece:
		var placement: Placement = model.placements[index]
		designed = designed or placement.mine
		adrift = adrift and floating.has(index)
		parts.append({"part": placement.part})
	return designed and not adrift and _a_figure(parts)


## Whether a piece's parts ([{part}]) are a figure, and not a model with a
## figure in it: a torso and a head among them (Minifig.is_figure), and half
## of them or more a figure's own or what it holds. The sides round's
## locomotive, its driver standing in its cab, was 136 parts, and called "a
## figure apart" from the tender that nothing coupled to it.
func _a_figure(parts: Array) -> bool:
	if not Minifig.is_figure(parts, library):
		return false
	var worn: int = 0
	for one: Dictionary in parts:
		var id: String = str(one["part"])
		if not Minifig.role_of(id, library.parts.get(id)).is_empty():
			worn += 1
	return worn * 2 >= parts.size()


## Whether a piece apart from the model is a vehicle's own part left
## uncoupled: of the design's, held up, rolling on wheels of its own as the
## model does, end to end with it along x or z — its feet level with the
## model's, its side in line with it, no more than [constant COUPLE_GAP]
## studs off its end. {"piece", "along", "gap" in studs, "behind"} or {}.
## The rule reads how the two stand, not what they are: a tender, a
## trailer, a carriage and a wagon stand that way, and a jetty by a boat, a
## tree by a house or a figure by a car do not.
func _uncoupled(model: Model, piece: Array, main: Array, floating: Dictionary,
		box_of: Dictionary) -> Dictionary:
	if piece.size() < 4 or box_of.is_empty():
		return {}
	var designed: bool = false
	var adrift: bool = true
	var rolls: bool = false
	for index: int in piece:
		var placement: Placement = model.placements[index]
		designed = designed or placement.mine
		adrift = adrift and floating.has(index)
		rolls = rolls or _rolls(placement.part)
	if not designed or adrift or not rolls:
		return {}
	var main_rolls: bool = false
	for index: int in main:
		if _rolls(model.placements[index].part):
			main_rolls = true
			break
	if not main_rolls:
		return {}
	var bounds := func(indices: Array) -> Array:
		var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
		var hi := -lo
		for index: int in indices:
			var corners: Array = box_of.get(index, [])
			if corners.is_empty():
				continue
			lo = lo.min(corners[0])
			hi = hi.max(corners[1])
		return [lo, hi]
	var mine: Array = bounds.call(piece)
	var theirs: Array = bounds.call(main)
	var p_lo: Vector3i = mine[0]
	var p_hi: Vector3i = mine[1]
	var m_lo: Vector3i = theirs[0]
	var m_hi: Vector3i = theirs[1]
	if absi(p_lo.y - m_lo.y) > 6 * BrickLattice.CELLS_PER_PLATE:
		return {}
	var stud: int = BrickLattice.CELLS_PER_STUD
	for axis: int in [0, 2]:
		var other: int = 2 - axis
		var gap: int = maxi(p_lo[axis] - m_hi[axis], m_lo[axis] - p_hi[axis])
		var shared: int = mini(p_hi[other], m_hi[other]) - maxi(p_lo[other], m_lo[other])
		var narrow: int = mini(p_hi[other] - p_lo[other], m_hi[other] - m_lo[other])
		if gap >= -NEAR[axis] and gap <= COUPLE_GAP * stud and shared * 2 >= narrow:
			return {"piece": piece, "along": "x" if axis == 0 else "z",
				"gap": maxf(0.0, float(gap) / stud), "behind": p_lo[axis] > m_hi[axis] - NEAR[axis]}
	return {}


## How far off a model's end, in studs, a part of it on wheels may stand and
## still be its car to couple: a tender a stud or two back, a trailer on its
## drawbar's length.
const COUPLE_GAP := 8


## Whether a part is a wheel, a tyre or a bogie: what a vehicle's part rolls on.
func _rolls(part_id: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	if info == null:
		return false
	if info.category in ["Wheel", "Tyre"]:
		return true
	return (info.name.contains("Wheel") or info.name.contains("Tyre")) \
		and not info.name.contains("Steering") and not info.name.contains("Ship")


## What the check says of a part of a vehicle that nothing couples, and how
## sets couple one.
static func _uncoupled_said(model: Model, found: Dictionary) -> String:
	var piece: Array = found["piece"]
	var name: String = ""
	for index: int in piece:
		name = _assembly_of(model, model.placements[index])
		if not name.is_empty():
			break
	var where: String = _loose_said(model, piece).replace(", joined to nothing of the model", "")
	var gap: float = float(found["gap"])
	var off: String = "against it" if gap < 0.5 else "%s stud%s off it" % [
		Placement._num(gap), "" if is_equal_approx(gap, 1.0) else "s"]
	var who: String = "" if name.is_empty() else "The %s, " % name
	var end: String = ("+" if bool(found["behind"]) else "-") + str(found["along"])
	return ("%s%s rolls on wheels of its own at the model's %s end, %s, and nothing "
		% [who, where, end, off]
		+ "couples it to the model: it stays behind when the model is pulled and comes "
		+ "away when it is picked up.")


## How sets couple a vehicle's parts, said once after the parts it is for.
const COUPLE_HOW := ("Couple each at the ends that meet, as sets do: a towball on one "
	+ "and a towball socket over it on the other (14417, plate 1 x 2 with a towball on its "
	+ "side; 14704, plate 1 x 2 with its socket; show_technique \"towball hitch\"); for a "
	+ "train's cars "
	+ "a buffer beam with a sealed magnet at each end, the magnets touching (64422; "
	+ "show_technique \"magnet coupling\"); or a Technic liftarm pinned (2780) into a "
	+ "Technic brick's hole (3700) on each. Coupled, the two are one piece to the check.")


## The assembly a placement is in: its own, as a file or the baseplate
## has it, or the first named box that holds its corner, as the run ends
## by tagging it (_tag_assemblies).
static func _assembly_of(model: Model, placement: Placement) -> String:
	if not placement.group.is_empty():
		return placement.group
	var at := Vector3(placement.x, placement.y, placement.z)
	var section: Section = model.section_for(placement)
	if section != null:
		at = Vector3(section.x, section.y, section.z)
	return _assembly_at(at, model.assemblies)


## The assembly a corner [param at] is in: of the boxes that hold it, the
## smallest. A nameplate named in front of a car whose bonnet's box runs on
## past the bumper was in the bonnet, first named, and the held-out run was
## told twice that the nameplate it had named was loose.
static func _assembly_at(at: Vector3, assemblies: Array[Dictionary]) -> String:
	var best: String = ""
	var least: float = INF
	for one: Dictionary in assemblies:
		var where: Dictionary = one.get("where", {})
		if not _inside(at, where):
			continue
		var size: float = 1.0
		for side: Array in [["x_from", "x_to"], ["y_from", "y_to"], ["z_from", "z_to"]]:
			if where.has(side[0]) and where.has(side[1]):
				size *= maxf(0.1, float(where[side[1]]) - float(where[side[0]]))
			else:
				size *= 10000.0
		if size < least:
			least = size
			best = str(one["name"])
	return best


## Where a loose piece is and what it is made of, for the check to say.
static func _loose_said(model: Model, piece: Array) -> String:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var parts: Dictionary = {}
	for index: int in piece:
		var placement: Placement = model.placements[index]
		var at := Vector3(placement.x, placement.y, placement.z)
		low = low.min(at)
		high = high.max(at)
		parts[placement.part] = int(parts.get(placement.part, 0)) + 1
	var named := PackedStringArray()
	for part_id: String in parts:
		named.append(part_id if int(parts[part_id]) == 1
			else "%d x %s" % [parts[part_id], part_id])
		if named.size() == 4:
			break
	return ("%d part%s (%s%s) with corners from x %s, y %s, z %s to x %s, y %s, "
		% [piece.size(), "" if piece.size() == 1 else "s", ", ".join(named),
			", ..." if parts.size() > 4 else "", Placement._num(low.x),
			Placement._num(low.y), Placement._num(low.z), Placement._num(high.x),
			Placement._num(high.y)]
		+ "z %s, joined to nothing of the model" % Placement._num(high.z))


## Where a piece against the model is, what it is made of and what it
## touches, for the check to say: the bricks it is beside, so a design can
## lay a part across the joint.
static func _unjoined_said(model: Model, piece: Array) -> String:
	var said: String = _loose_said(model, piece).replace("joined to nothing of the model",
		"against the model and joined to nothing of it")
	return said


## Half a stud across and a plate up: faces turned to an angle meet at their
## corners by boxes that leave a sliver between them.
const NEAR: Array[int] = [5, 4, 5]


## The separate pieces the design is in, each the indices of its
## placements, joined by the rules [method _check] says them by.
func _pieces_of(model: Model, cells_of: Dictionary,
		lattice: BrickLattice, boxes_of: Dictionary = {},
		holds: Dictionary = {}) -> Array:
	if cells_of.size() <= 1:
		return [cells_of.keys()] if cells_of.size() == 1 else []

	var joined: Dictionary = {}   ## index -> Array of index
	for index: int in cells_of:
		joined[index] = []
	# And the joints, which support counts and this did not: a flag clipped
	# to a lance was held up and yet a piece of its own. With what is pushed
	# into what (a carrot in a hand's grip, a cape round a neck), so a whole
	# minifigure is one piece, as it is in the hand ([method _check]).
	for index: Variant in holds:
		for other: Variant in holds[index]:
			if joined.has(index) and joined.has(other):
				joined[index].append(other)
				joined[other].append(index)
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
		var at: Transform3D = _joined_at(placement, part, model)
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
	var pieces: Array = []
	for start: int in cells_of:
		if seen.has(start):
			continue
		var piece: Array = [start]
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var here: int = stack.pop_back()
			for next: int in joined[here]:
				if not seen.has(next):
					seen[next] = true
					stack.append(next)
					piece.append(next)
		pieces.append(piece)
	return pieces


## What fills a cell, for [method Joints.pushed_in]: the placements whose
## covers are in it, each where it is checked ([method _joined_at]), which
## is where the checker's lattice has it. A figure's parts were in it at the
## nearest square turn, where a hand's grip and the sword in it are not
## where each other are, and were covered again here where they stand.
func _filled_by(cells_of: Dictionary, lattice: BrickLattice) -> Callable:
	return func(box: PackedInt32Array, key: Variant) -> Array:
		var out: Array = []
		for found: int in lattice.blockers_boxes(box, int(key) + 1):
			if found > 0 and cells_of.has(found - 1):
				out.append(found - 1)
		return out


## Every stud that reaches into another part, as [whose stud, which part
## it reaches into, where the stud stands, which way it points]. Both
## parts are held by it: see [method _check_support]. Where it stands is
## what says whether it went into a socket ([method _underside]).
##
## A stud stands 4 LDU proud of the surface it rises from, so the cell
## it reaches into is the one just beyond its tip. Whoever owns that
## cell is being held by it — which is as true of a stud on the side of
## a brick as of one on top, and is the whole of what makes sideways
## building possible.
##
## And clutch holds both ways. A plate pressed up under an overhang has
## nothing beneath it and is held by its own studs, and this counted
## only the part above, so the plate was "floating". Real sets hang parts
## like that constantly: of 162 small sub-models of real sets in LDraw's
## model repository, 32 were refused as floating, and the commonest were
## plates — a 1x3 under a sign, a 2x2 under a lantern.
func _studs_reaching_in(model: Model, cells_of: Dictionary,
		lattice: BrickLattice) -> Array:
	var entries: Array = []
	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		entries.append([index, _joined_at(placement, part, model), part])
	# The rule is Joints', which the booklet reads support by too.
	return Joints.studs_in(entries, func(tip: Vector3, index: Variant) -> Variant:
		# brick_at returns index + 1, since zero means empty.
		var reached: int = lattice.brick_at(BrickLattice.to_cell(tip))
		return reached - 1 if reached != 0 and reached - 1 != int(index) else null)


## Each placement as [Joints] wants it, to ask which are held by something
## pushed into them, or by something they are pushed into, and which turn
## in something round.
##
## The matching itself lives in [Joints], because the booklet needs the
## same answer from a world of bricks rather than a model of placements,
## and two copies of it would drift.
func _mating_entries(model: Model) -> Array:
	var entries: Array = []
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		# By the number it moved to, if it moved: the gear table knows 3648b
		# and not 3648, which a session may well write.
		entries.append([index, _joined_at(placement, part, model), part,
			library.resolve(placement.part)])
	return entries


## Where a placement is checked, its cover, its studs and its joints: where
## the part stands, for one read off the world and not moved since; where
## its placement says, for one a design or an edit puts down or moves.
##
## The reading cannot always say where a part is. A minifigure's parts stand
## on no stud grid and are read back at the nearest square turn ([method
## _adopted] leaves them as they were): a hand turned 45 degrees in its arm,
## read back square, had its peg off the arm's socket, and on top of Orthanc
## Saruman's raised right hand was a piece of its own. And a part drawn
## sheared or mirrored, as LDCad draws a flexible hose's segments, is no
## turn at all. Checked where the reading put them, 3,661 parts of real sets
## floated (docs/CONNECTIONS.md, "read off its place"): 7893's mechanical
## arms on their clips, 9390's and 8841's hoses. A brick in a section is
## where it stands too: an edit that moves a section marks what is in it
## moved ([method _edit]), and a turn in the window forgets the section
## ([method _forget_moved_sections]).
func _joined_at(placement: Placement, part: Lbm.PartMesh, model: Model) -> Transform3D:
	if placement.id != 0 and not placement.moved and world != null:
		var brick: BrickWorld.Brick = world.get_brick(placement.id)
		if brick != null and brick.part_id == placement.part:
			return brick.transform
	return _transform(placement, part, model.section_for(placement))


## Where a brick stops, in the units the placement was written in.
##
## Returns a clause to hang off an overlap message, or nothing at all
## when the brick that was hit is one already on the baseplate rather
## than one of these placements.
static func _ends_at(cover: Variant) -> String:
	if typeof(cover) != TYPE_PACKED_INT32_ARRAY or (cover as PackedInt32Array).is_empty():
		return ""
	var boxes: PackedInt32Array = cover
	var low: int = boxes[1]
	var high: int = boxes[4] - 1
	for at: int in range(0, boxes.size(), 6):
		low = mini(low, boxes[at + 1])
		high = maxi(high, boxes[at + 4] - 1)
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
		boxes_of: Dictionary = {}, joined: Dictionary = {},
		rounds: Dictionary = {}, exact: ExactCheck = null) -> void:
	# A section that leans has to lean on something that turns.
	#
	# Touching was enough, so a horn tip tipped eight degrees out sat on
	# the studs of the brick below it at a slant, gripping none of them:
	# the owner saw the spires of a tower of Orthanc not sitting on their
	# studs, and that is exactly what they were. Real sets lean a part on
	# a hinge, a clip on a bar or a ball, and the checker knows those now
	# (Joints). Turning about the upright is not leaning, and a quarter
	# turn is studs on their side. Judged from the design, not from what
	# was placed: a leaning brick that also overlapped was never placed.
	# Each section's placements, and whether a design or an edit put any of
	# them down or moved it, read once. Asked section by section of every
	# placement, a real set read into a thousand sections was millions of
	# reads before anything was checked.
	var members: Dictionary = {}   ## section -> its placements' indices, in order
	var laid: Dictionary = {}      ## section -> true, when one is new or moved
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		if not members.has(placement.section):
			members[placement.section] = []
		(members[placement.section] as Array).append(index)
		if placement.id == 0 or placement.moved:
			laid[placement.section] = true
	var adopted: Dictionary = {}
	for one: Section in _adoptions.values():
		adopted[one.name] = true
	for group: String in model.sections:
		var section: Section = model.sections[group]
		# Square to what it is built on, or turned only about the upright,
		# it stands on studs as anything does; a section within a leaning
		# one leans with it and is held to it by studs, square.
		if not section.leans():
			continue
		if not members.has(group):
			continue
		# A section found for a file's tipped parts ([method _adopted]) that
		# nothing has added to or moved is what was standing, as an overlap
		# among standing bricks is: not this design's to answer for. Poe's
		# X-wing (75102) read so has two whose joint the checker does not see.
		if adopted.has(group) and not laid.has(group):
			continue
		if _turns_on_a_joint(model, group, joined, rounds, members[group]):
			continue
		# Or on one BrickNet's labels join, where both parts have an exact
		# shape: an arm put on its shoulder by its connectors, standing since.
		if exact != null and _leans_on_exact_joint(model, group, exact):
			continue
		stuck[group] = true
		_note(issues, "leaning on nothing",
			"section '%s' is turned %s but nothing in it turns on "
				% [group, section.said()]
				+ "anything outside it: its bottom sits on the studs below at a "
				+ "slant and grips none of them. Stand it upright on "
				+ "its studs, or turn it only about the upright (yaw) "
				+ "instead. A part leans in a real set only on a joint "
				+ "whose line lies along the turn at its pivot "
				+ "— a tilting hinge (3937 with 3938 on it), click "
				+ "hinge plates, a clip on a bar, a "
				+ "ball in a socket — one half outside the section and "
				+ "the other in it. hinge: \"%s\" on the section " % Hinges.TILTING
				+ "lays both halves and turns it about their line for "
				+ "you (%s); show_technique(\"leaning on a hinge\") is one " % (
					Hinges.offered(library) if library != null else Hinges.listing())
				+ "written out. Or put the leaning part on the joint by its "
				+ "connectors (attach: {\"to\": \"base.hinge[0]\", \"by\": \"hinge[0]\", "
				+ "\"yaw\": 30}), which seats it at that angle exactly. (3830/3831 and "
				+ "2429/2430 swivel flat, like a door; they do not lean.)")
	## Section -> its placements standing, in the order they were placed.
	var standing: Dictionary = {}
	for index: int in boxes_of:
		var group: String = model.placements[index].section
		if not standing.has(group):
			standing[group] = []
		(standing[group] as Array).append(index)
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
		# Its own bricks are not asked about: touching them is not touching
		# anything outside it, and a turned brick against forty of its own
		# was the cost of the question.
		var own: Dictionary = {}
		for index: int in standing.get(group, []):
			own[index + 1] = true
		for index: int in standing.get(group, []):
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
			for who: int in lattice.blockers_boxes(grown, 0, own):
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


## Each part of [param model] attached by its connectors (Placement.attached_to)
## joined to the part it is on, into [param joined] both ways, as a pin is:
## where both have exact shapes, only while BrickNet's labels still join them
## (the part it is on moved since, it is not); where either has none, as
## worked out, since the lattice cannot say otherwise.
func _attach_joins(model: Model, exact: ExactCheck, placed_at: Dictionary,
		joined: Dictionary) -> void:
	if not model.placements.any(func(p: Placement) -> bool: return p.attached_to != null):
		return
	var index_of: Dictionary = {}
	for i: int in model.placements.size():
		index_of[model.placements[i]] = i
	for i: int in model.placements.size():
		var placement: Placement = model.placements[i]
		if placement.attached_to == null or not placed_at.has(i):
			continue
		var j: int = int(index_of.get(placement.attached_to, -1))
		if j < 0 or not placed_at.has(j):
			continue
		var shaped: bool = i < exact.items.size() and j < exact.items.size() \
			and exact.items[i] != null and exact.items[j] != null
		if shaped and Exact.connections(exact.items,
				PackedInt32Array([mini(i, j), maxi(i, j)])).is_empty():
			continue
		for pair: Array in [[i, j], [j, i]]:
			if not joined.has(pair[0]):
				joined[pair[0]] = {}
			(joined[pair[0]] as Dictionary)[pair[1]] = true


## Whether a part of [param group] is joined to one outside it by a joint that
## turns, by BrickNet's labels on their exact shapes: a hinge, a ball, a fixed
## joint, a pin, an axle or a bar in a clip. Not a stud: a part at a slant on
## studs grips none of them, whatever 3 LDU of slack BrickNet allows.
static func _leans_on_exact_joint(model: Model, group: String, exact: ExactCheck) -> bool:
	var count: int = mini(model.placements.size(), exact.items.size())
	var mine: Dictionary = {}
	for i: int in count:
		if model.placements[i].section == group and exact.items[i] != null:
			mine[i] = true
	if mine.is_empty():
		return false
	var these: Dictionary = mine.duplicate()
	for i: Variant in mine:
		for j: int in Exact._near(exact.items, int(i), PackedInt32Array(), Exact.POS_THR, true):
			these[j] = true
	var only := PackedInt32Array()
	for i: Variant in these:
		only.append(int(i))
	only.sort()
	for edge: Array in Exact.connections(exact.items, only):
		if mine.has(int(edge[0])) == mine.has(int(edge[2])):
			continue
		var kind: int = (exact.items[int(edge[0])] as Exact.Item).shape.kind[int(edge[1])]
		if kind != Exact.STUD and kind != Exact.HOLE:
			return true
	return false


## Whether any brick in [param group] is pinned, clipped, hinged or
## balled to a brick outside it.
## [param members] are the group's placements' indices, when the caller has
## them.
static func _turns_on_a_joint(model: Model, group: String, joined: Dictionary,
		rounds: Dictionary, members: Array = []) -> bool:
	var indices: Array = members
	if indices.is_empty():
		indices = range(model.placements.size())
	for index: int in indices:
		if model.placements[index].section != group:
			continue
		for mates: Dictionary in [joined.get(index, {}), rounds.get(index, {})]:
			for other: Variant in mates:
				if int(other) < model.placements.size() \
						and model.placements[int(other)].section != group:
					return true
	return false


func _check_support(
	model: Model, cells_of: Dictionary, lattice: BrickLattice,
	issues: Dictionary, crowded: Dictionary = {},
	joined: Dictionary = {}, loose: Dictionary = {},
	boxes_of: Dictionary = {}, floating: Dictionary = {},
	clutched_pairs: Array = []
) -> void:
	# Who holds whom. A part is held if a chain of these reaches the
	# ground: resting on a part, a stud reaching into it or its own stud
	# reaching into another — clutch holds both ways — or a pin, axle or
	# ball. The rule this replaced looked one part down. A plate pressed
	# up under an overhang has nothing beneath it and was called
	# floating, which was the commonest reason the check refused a real
	# set's sub-model; and counting clutch both ways without asking
	# about the ground let a stack hanging in mid-air hold itself up.
	var gives: Dictionary = {}       ## index -> indices it holds up
	var clutched: Dictionary = {}    ## index -> true, held by some stud
	var studs_in: Dictionary = {}    ## index -> [where, way] of studs in it
	var reaching: Array = _studs_reaching_in(model, cells_of, lattice)
	_note_turned_studs(model, reaching, issues)
	for pair: Array in reaching:
		var owner: int = pair[0]
		var into: int = pair[1]
		if into >= model.placements.size():
			continue
		_gives(gives, owner, into)
		_gives(gives, into, owner)
		clutched[owner] = true
		clutched[into] = true
		clutched_pairs.append([owner, into])
		if not studs_in.has(into):
			studs_in[into] = []
		(studs_in[into] as Array).append(pair.slice(2))
	for index: int in joined:
		for mate: Variant in (joined[index] as Dictionary):
			_gives(gives, int(mate), index)
	var grounded: Array[int] = []
	var resting: Dictionary = {}     ## index -> the part it rests on
	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		# Its section ran into something, so some of its neighbours were
		# never placed. Whether this brick is held cannot be known until
		# that is sorted out, and saying it floats is noise on top of
		# the fault that matters.
		if crowded.has(placement.section):
			continue
		var cover: PackedInt32Array = cells_of[index]
		var floor_y: int = 0x7FFFFFFF
		for at: int in range(1, cover.size(), 6):
			floor_y = mini(floor_y, cover[at])
		# Standing on the ground, read off where the brick actually
		# ended up rather than off the number that was written.
		#
		# This asked whether the written y was zero, which for a brick
		# in a section is that section's own y and not the world's — so
		# the base course of a pylon carried thirty plates into the air
		# was excused from needing anything to hold it up, and a whole
		# assembly could hang there with the check calling it sound.
		# On the ground, or already standing before this design and not
		# touched by it — which, like an overlap between two such bricks,
		# is not this design's to answer for.
		# Unless what is asked is what an edit leaves hanging: then only the
		# ground holds (_left_hanging).
		if floor_y <= 0 or (floor_y <= 2 and _on_the_ground(placement, model)) \
				or (placement.id != 0 and not placement.moved and not _ground_only):
			grounded.append(index)
			continue

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
			# A brick that was already standing holds it as the ground
			# does.
			if below < 0:
				grounded.append(index)
			elif below - 1 != index:
				_gives(gives, below - 1, index)
				if sitting_on == 0:
					sitting_on = below
		resting[index] = sitting_on

	# Out from the ground. Studs, not only what is underneath: "something
	# in the cell below" was once the only rule, and it made studs-not-on-
	# top impossible — a wall of smooth colour, round plates as rivets, a
	# tile standing up as a pane, all rejected as floating, until three
	# repairs taught the model not to try. 87087 records its side stud at
	# axis +Z and a pin knows its hole; this asks them.
	var held: Dictionary = {}
	var queue: Array[int] = grounded.duplicate()
	for index: int in grounded:
		held[index] = true
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for next: int in gives.get(here, []):
			if not held.has(next):
				held[next] = true
				queue.append(next)

	for index: int in cells_of:
		var placement: Placement = model.placements[index]
		if crowded.has(placement.section) or held.has(index):
			continue
		floating[index] = true
		# Said by what it touches. A brick on a floating one stands on
		# something that is not held up; a part clutched or pinned to one
		# is held, by something that is not; only a part touching nothing
		# has nothing holding it.
		var how: String = "has nothing holding it"
		if int(resting.get(index, 0)) > 0:
			how = "stands on parts that are not held up themselves"
		elif gives.values().any(func(them: Variant) -> bool:
				return (them as Array).has(index)):
			how = "is held only by parts that are not held up themselves"
		_note(issues, "floating", "brick %d (%s at %s) %s" % [index,
			placement.part, placement.where(), how])

	for index: int in resting:
		if not held.has(index):
			continue
		var sitting_on: int = resting[index]
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
				clutched.has(index), issues, studs_in.get(index, []))


## How near a socket a stud from a part turned off the square has to land
## to be in it, in studs: a cell. Turned about one stud, every other stud
## between two parts lands a fraction of a stud from where it would grip,
## and the slack the square case allows (a third of a stud) passed a 1 x 2
## turned ten degrees on two studs.
const TURNED_GRIP := 0.1


## Studs into a part turned off the square about the upright, from one that
## is not turned with it, landing anywhere but in a socket. Turning about
## the upright was let through as a part on one stud swivels, and so it
## does; but a 2 x 4 turned thirty degrees on a plate stands on studs that
## meet its tubes and walls, and it was called buildable. What grips is one
## stud in one socket with nothing else under it — a 1 x 1 round plate, a
## jumper's centre stud, a turntable.
##
## Asked of the turned part's underside only. A square part on a turned
## one's studs is the same plastic, but the prism pattern's cluster ties its
## piers' walls, each at its own angle, with a summit of square plates laid
## across their tops, and every Orthanc built with it would be refused. The
## same pattern stood its turned walls on square studs too — a storey on the
## ledge below, a tower on its plinth — and 23 of patterns_probe's towers were
## refused for it, so its own sections were let through, and a tower saved and
## opened again, its sections read anew, was refused for 128. It lays tiles
## under them now (_smooth_under_turned, and the plinth's studs), and its
## sections are judged as any other.
func _note_turned_studs(model: Model, studs: Array, issues: Dictionary) -> void:
	var frames: Dictionary = {}     ## section -> its basis in the world
	var off: Dictionary = {}        ## Vector2i(owner, into) -> [count, degrees]
	for one: Array in studs:
		var owner: int = one[0]
		var into: int = one[1]
		if into >= model.placements.size() or owner >= model.placements.size():
			continue
		var below: Placement = model.placements[owner]
		var above: Placement = model.placements[into]
		if below.section == above.section or not _underside_known(above.part) \
				or _swivels(above.part):
			continue
		var turned: Basis = _frame_of(model, above.section, frames)
		var between: Basis = turned.inverse() * _frame_of(model, below.section, frames)
		if BrickLattice.is_square_to_grid(between) or BrickLattice.is_square_to_grid(turned) \
				or (between * Vector3.UP).dot(Vector3.UP) < 0.9999:
			continue
		var under_it: Array = _underside(model, into, [one.slice(2)])
		var reaching: PackedVector2Array = under_it[0]
		var takes: PackedVector2Array = under_it[2]
		for stud: Vector2 in reaching:
			var nearest: float = INF
			for take: Vector2 in takes:
				nearest = minf(nearest, stud.distance_to(take))
			if nearest <= TURNED_GRIP or nearest >= HALF_OFF:
				continue
			var key := Vector2i(owner, into)
			if not off.has(key):
				off[key] = [0, Section.angles_of(between).x]
			off[key][0] = int(off[key][0]) + 1
	for key: Vector2i in off:
		var below: Placement = model.placements[key.x]
		var above: Placement = model.placements[key.y]
		_note(issues, "off its studs",
			"brick %d (%s at %s) sits on the studs of brick %d (%s at %s), turned %s degrees "
			% [key.y, above.part, above.where(), key.x, below.part, below.where(),
				Placement._num(snappedf(absf(float(off[key][1])), 0.1))]
			+ "from it about the upright, so %d of the studs between them " % off[key][0]
			+ "land between its sockets, against its tubes and walls, and grip "
			+ "nothing. Turned off the square, a part grips by one stud with nothing "
			+ "else under it: stand it on a 1 x 1 round plate, a jumper's centre "
			+ "stud or a turntable, or turn it square.")


## Whether [param part] turns on a shaft or in a bore of its own, as a
## turntable's top does on its base: held by that, the studs its skirt
## stands among beside the base are not what holds it. The corner on a
## turntable, stood on a floor, was refused for them.
func _swivels(part: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	return info != null and (info.has_connector("shaft") or info.has_connector("bore"))


## A section's turn in the world, the model's own for "", kept in [param
## frames] once worked out.
static func _frame_of(model: Model, name: String, frames: Dictionary) -> Basis:
	if not frames.has(name):
		var section: Section = model.sections.get(name) if not name.is_empty() else null
		frames[name] = section.placed().basis if section != null else Basis.IDENTITY
	return frames[name]


## Whether a part stands on the ground by its drawn shape, within a cell of
## it, where its cover stops short of it. A cover keeps the cells whose
## middles are in the part, and a wheel's tread or a train's wheelset whose
## lowest point is an LDU above a cell's line keeps none in the cell under
## it; and opened from a file, a model stands on its lowest point rounded up
## to a whole cell, which a bucket's handle drawn 1.6 LDU under the
## baseplate made 2. So the trains of 10014 and 10020 stood an LDU up on
## their wheels, 10243's restaurant two on its baseplate, and the whole of
## each was called floating. By its shape, turned or not (Lbm.PartMesh.
## lowest_at): a turned part's box reaches below it, and a tyre a file draws a
## hair off the square was a turned part.
##
## Within two cells for a part read off the world that nothing has moved. The
## open stands a model on its lowest point rounded up to a whole cell, so that
## point is up to a cell above the ground, and a part a file stands within a
## cell of the ground stands within two of it here: 4549's train and 6482's
## car had their wheels 2.5 and 3 LDU up, beside a bogie and a figure's feet
## the open stood a cell up. Read back at the nearest cell they were at 2;
## checked where they stand, as they are now, they floated. A part a design
## or an edit puts down stands on the ground within one cell, so nothing it
## places hovers.
func _on_the_ground(placement: Placement, model: Model) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(placement.part) if library != null else null
	if part == null:
		return false
	var cells: float = 1.0 if placement.id == 0 or placement.moved else 2.0
	return part.lowest_at(_joined_at(placement, part, model)) \
		<= cells * BrickLattice.CELL + 0.01


static func _gives(gives: Dictionary, holder: int, held: int) -> void:
	if not gives.has(holder):
		gives[holder] = []
	(gives[holder] as Array).append(held)


## Parts made to sit inside another, and where real sets put them.
##
## A pane clips into a window frame and a door hangs in a door frame,
## and the frame's collision boxes are coarser than the groove: cells
## are 2 LDU and a pane is 4 thick, so the two meet as a one-cell
## overlap and the checker refused every glazed window. Measured over
## the LDraw model repository's sets, 2026-10-09: 185 panes in 60592
## and 110 in 60593 at the frame's own origin and turn; doors 32 LDU
## either side of a 60596's middle and 5 in (46, the far one turned
## half round); 57895 glass 4 down and 5 in (19).
##
## Insert -> [frame, x, y, z, quarter turns about the frame's up] in
## the frame's own LDraw coordinates. Only there is the overlap
## forgiven, to within an LDU: a pane anywhere else is a fault as
## before.
##
## Measured again over the same sets, 2026-10-10, for the panes 880 real
## sub-models were still refused for: 3854 in 6556 (28 a side, in three
## files, 4 to 6 in) and in 60594, 60607 in 60594 (15 a side) where 60608
## sits, 86210 in 60594 (18, 4 in, give or take an LDU in seven files),
## 38320 at 60592's origin (64), and 57895 in 57894 (6, 3 out). And the
## seats the table had one way round that sets use both: 57895 turned
## half round in 60596 (9 of 29), 60603 4 in and square (2 files). Then
## the two seats still refused after that: 10190 Market Street sets its
## left 3854 3 in where the right is 4 (five sub-models of one window),
## and 10297 Boutique Hotel turns 86210 half round 2 in (7).
const NESTS: Dictionary = {
	"60601": [["60592", 0, 0, 0, 0]],
	"60602": [["60593", 0, 0, 0, 0]],
	"38320": [["60592", 0, 0, 0, 0]],
	"57895": [["60596", 0, 4, 5, 0], ["60596", 0, 4, 5, 2],
		["57894", 0, 4, -3, 0], ["57894", 0, 4, -3, 2]],
	"60623": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60616a": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60616b": [["60596", -32, 0, 5, 0], ["60596", 32, 0, 5, 2]],
	"60603": [["60594", 0, 8, 5, 2], ["60594", 0, 8, 4, 0]],
	"60608": [["60594", -32, 4, 4, 3], ["60594", 32, 4, 4, 1]],
	"60607": [["60594", -32, 4, 4, 3], ["60594", 32, 4, 4, 1]],
	"86210": [["60594", 0, 8, 4, 0], ["60594", 0, 8, 2, 2]],
	"3854": [["6556", -34, 4, 5, 3], ["6556", 34, 4, 5, 1], ["6556", -34, 4, 3, 3],
		["60594", -34, 4, 4, 3], ["60594", 34, 4, 4, 1]],
}


## What is left of [param blockers] once the parts that are meant to meet
## inside one another are taken out: a pin in its hole, a pane in its
## frame, and something round in something round that fits it where they
## overlap nowhere but in the round.
##
## [param mine] is this placement's cover, [param against] the lattice
## the others' covers are in, and [param to_world] carries that lattice's
## cells into the world's coordinates, which the joints are in — the two
## differ only inside a section. [param square] says the cells are square
## to both parts, as a section's own are.
func _joints_out(blockers: PackedInt64Array, index: int, model: Model,
		placed_at: Dictionary, joined: Dictionary, rounds: Dictionary,
		mine: PackedInt32Array, against: BrickLattice, to_world: Transform3D,
		square: bool, meshing: Dictionary = {}) -> PackedInt64Array:
	if blockers.is_empty():
		return blockers
	var pinned: Dictionary = joined.get(index, {})
	var in_mesh: Dictionary = meshing.get(index, {})
	var turning: Dictionary = rounds.get(index, {})
	var at: Transform3D = placed_at[index]
	var kept := PackedInt64Array()
	for key: int in blockers:
		var other: int = key - 1
		if key > 0 and other < model.placements.size():
			if pinned.has(other) or in_mesh.has(other):
				continue
			if placed_at.has(other) and _seated(model.placements[index].part, at,
					model.placements[other].part, placed_at[other]):
				continue
			if turning.has(other) and placed_at.has(other):
				var slack: float = Joints.ROUND_SLACK
				var own: Array = []
				if not square and not (BrickLattice.is_square_to_grid(at.basis)
						and BrickLattice.is_square_to_grid(
							(placed_at[other] as Transform3D).basis)):
					slack = Joints.ROUND_SLACK_TURNED
					own = [_own_cover(model, index), _own_cover(model, other)]
				if Joints.overlap_within(mine, against.boxes_of(key),
						turning[other], to_world, slack, own):
					continue
			# And the rest of a section that turns on a joint, against the
			# joint's other half. A jumper on a hinge top turned thirty
			# degrees clears the hinge's base by an LDU in 6085 Black
			# Monarch's Castle, and a cover keeping every cell it touches
			# put it a cell into the base.
			if not square and placed_at.has(other) \
					and _turns_against(model, index, other, rounds) \
					and Joints.overlap_within(mine, against.boxes_of(key), [],
						to_world, 0.0, [_own_cover(model, index),
							_own_cover(model, other)]):
				continue
			# A gear's square cover reaches past its teeth: meeting it only
			# there is meeting air.
			if placed_at.has(other):
				var teeth: Array = Joints.gear_rounds([
					[library.resolve(model.placements[index].part), at],
					[library.resolve(model.placements[other].part), placed_at[other]]], library)
				if Joints.past_the_teeth(mine, against.boxes_of(key), teeth, to_world):
					continue
		kept.append(key)
	return kept


## Two gears that overlap, said by how far apart they are and how far apart
## they mesh: " — an 8 and a 24 mesh with their centres 40 LDU (2 studs)
## apart; these are 36". Empty unless both are gears turning in one plane.
##
## A session told only "brick 14 (3648b) overlaps brick 13" turned the 8
## half a tooth, then gave up and ran a chain between the two gears, saying
## the check treats a gear as a solid disc. The number it needed was the
## spacing.
func _gears_apart(model: Model, placed_at: Dictionary, one: int, other: int) -> String:
	if other < 0 or other >= model.placements.size() or not placed_at.has(one) \
			or not placed_at.has(other):
		return ""
	var ids: Array = [library.resolve(model.placements[one].part),
		library.resolve(model.placements[other].part)]
	if Mechanism.spec_of(ids[0]).is_empty() or Mechanism.spec_of(ids[1]).is_empty():
		return ""
	var pair: Mechanism = Mechanism.build([
		{"key": 1, "part": ids[0], "at": placed_at[one], "mesh": library.mesh_for(ids[0])},
		{"key": 2, "part": ids[1], "at": placed_at[other], "mesh": library.mesh_for(ids[1])}])
	var a: Mechanism.Gear = pair.gear_at(1)
	var b: Mechanism.Gear = pair.gear_at(2)
	if a == null or b == null or a.kind == "worm" or b.kind == "worm" \
			or absf(a.axis.dot(b.axis)) < 0.999:
		return ""
	var gap: Vector3 = b.centre - a.centre
	var along: float = gap.dot(a.axis)
	if absf(along) > Mechanism.PLANE_SLACK:
		return ""
	var apart: float = (gap - a.axis * along).length()
	var mesh: float = a.radius + b.radius
	return (" — %s and %s mesh with their centres %s LDU (%s studs) apart across "
		% [Joints._teeth(a), Joints._teeth(b), _tidy(mesh),
			_studs(mesh / STUD)]
		+ "their axles, and these are %s: put their axles that far apart" % _tidy(apart))


## What turns with what, for a model with gears in it: the gears in mesh,
## those that nearly are (with the spacing they mesh at), and for each
## axle the parts it grips, which turn with it, and the round holes it
## turns in. Empty for a model without a gear.
func _drive_said(model: Model, entries: Array, meshing: Dictionary,
		placed_at: Dictionary) -> String:
	var gears: Array = []
	for entry: Array in entries:
		if not Mechanism.spec_of(str(entry[3])).is_empty():
			gears.append({"key": int(entry[0]) + 1, "part": entry[3], "at": entry[1],
				"mesh": entry[2]})
	if gears.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var said: Dictionary = {}
	for index: Variant in meshing:
		for other: Variant in meshing[index]:
			# A gear forgiven against its partner's axle is not a mesh.
			if str(meshing[index][other]).begins_with("past the axle"):
				continue
			if int(index) < int(other) and lines.size() < WORTH_SAYING:
				lines.append("  brick %d meshes brick %d: %s" % [index, other,
					meshing[index][other]])
	# Nearly in mesh: in one plane, a little too far apart. Too near is an
	# overlap, which says the same.
	var all: Mechanism = Mechanism.build(gears)
	for i: int in all.gears.size():
		for j: int in range(i + 1, all.gears.size()):
			var a: Mechanism.Gear = all.gears[i]
			var b: Mechanism.Gear = all.gears[j]
			if a.kind == "worm" or b.kind == "worm" or a.key == b.key \
					or absf(a.axis.dot(b.axis)) < 0.999:
				continue
			if (meshing.get(a.key - 1, {}) as Dictionary).has(b.key - 1):
				continue
			var gap: Vector3 = b.centre - a.centre
			var along: float = gap.dot(a.axis)
			var apart: float = (gap - a.axis * along).length()
			var over: float = apart - a.radius - b.radius
			if absf(along) > Mechanism.PLANE_SLACK or over <= Mechanism.MESH_SLACK \
					or over > NEARLY_MESH:
				continue
			lines.append("  brick %d and brick %d do not mesh: %s and %s mesh with "
				% [a.key - 1, b.key - 1, Joints._teeth(a), Joints._teeth(b)]
				+ "their centres %s LDU (%s studs) apart, and these are %s"
				% [_tidy(a.radius + b.radius), _studs((a.radius + b.radius) / STUD),
					_tidy(apart)])
	var by_axle: Dictionary = {}   ## index -> [grips, turns in], each an Array of numbers
	for one: Array in Joints.through(entries):
		var shaft: int = one[0]
		if not by_axle.has(shaft):
			by_axle[shaft] = [[], []]
		(by_axle[shaft][0 if one[2] == "grips" else 1] as Array).append(str(one[1]))
	# Those that grip something first: a train's axles, before the frame's ties.
	var order: Array = by_axle.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		return (by_axle[a][0] as Array).size() > (by_axle[b][0] as Array).size())
	var axles: int = 0
	for shaft: int in order:
		if axles >= WORTH_SAYING:
			break
		var grips := PackedStringArray(by_axle[shaft][0])
		var turns := PackedStringArray(by_axle[shaft][1])
		var part: Lbm.PartMesh = library.mesh_for(model.placements[shaft].part)
		var kinds: Array = Joints._lines_of(part)[0] if part != null else []
		if not kinds.any(func(line: Array) -> bool: return line[0] == "axle"):
			continue
		axles += 1
		lines.append("  brick %d (%s, an axle): grips %s; turns in %s" % [shaft,
			model.placements[shaft].part,
			"bricks " + ", ".join(grips) if not grips.is_empty() else "nothing",
			"bricks " + ", ".join(turns) if not turns.is_empty() else "nothing"])
	if lines.is_empty():
		return ""
	return ("What turns with what. A part on an axle by an axle hole turns with it; "
		+ "an axle in a round hole turns in it; gears in mesh turn each other. A gear "
		+ "on a round hole spins free and drives nothing:\n" + "\n".join(lines))


## How far past meshing two gears in one plane may be and still be said to
## nearly mesh, LDU: two teeth of module 1.
const NEARLY_MESH := 6.0


## Whether [param index] is in a section, turned, that turns on a joint
## whose other half is [param other].
func _turns_against(model: Model, index: int, other: int,
		rounds: Dictionary) -> bool:
	var group: String = model.placements[index].section
	if group.is_empty() or model.placements[other].section == group:
		return false
	var section: Section = model.sections.get(group)
	if section == null or section.square():
		return false
	for k: Variant in rounds.get(other, {}):
		if int(k) < model.placements.size() \
				and model.placements[int(k)].section == group:
			return true
	return false


## A placement's frame, its section's or the world's, and its cover
## square in that frame, where the cover is exact.
func _own_cover(model: Model, index: int) -> Array:
	var placement: Placement = model.placements[index]
	var part: Lbm.PartMesh = library.mesh_for(placement.part)
	var section: Section = model.section_for(placement)
	return [section.placed() if section != null else Transform3D.IDENTITY,
		builder.boxes_for(part, _square_transform(placement, part))]


## Whether two parts are an insert and its frame, seated as real sets
## seat them, whichever of the two was placed first.
func _seated(one: String, at_one: Transform3D, two: String,
		at_two: Transform3D) -> bool:
	return _seated_in(library.resolve(one), at_one, library.resolve(two),
		at_two) or _seated_in(library.resolve(two), at_two,
			library.resolve(one), at_one)


static func _seated_in(insert: String, at_insert: Transform3D,
		frame: String, at_frame: Transform3D) -> bool:
	if not NESTS.has(insert):
		return false
	var f: PackedFloat64Array = LdrModel.from_transform(at_frame)
	var g: PackedFloat64Array = LdrModel.from_transform(at_insert)
	# The insert in the frame's own coordinates: its offset carried back
	# through the frame's turn, and the turn between the two.
	var offset := Vector3(g[0] - f[0], g[1] - f[1], g[2] - f[2])
	var rows: Array = [Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8]),
		Vector3(f[9], f[10], f[11])]
	var local := Vector3.ZERO
	var turn: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for k: int in 3:
		local += (rows[k] as Vector3) * offset[k]
	var theirs: Array = [Vector3(g[3], g[4], g[5]), Vector3(g[6], g[7], g[8]),
		Vector3(g[9], g[10], g[11])]
	for i: int in 3:
		for k: int in 3:
			turn[i] = (turn[i] as Vector3) + Vector3(
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).x,
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).y,
				(rows[k] as Vector3)[i] * (theirs[k] as Vector3).z)
	for raw: Variant in NESTS[insert]:
		var seat: Array = raw
		if str(seat[0]) != frame:
			continue
		if local.distance_to(Vector3(seat[1], seat[2], seat[3])) > 1.01:
			continue
		# A quarter turn q about LDraw's up: cos in the corners, sin
		# off them.
		var angle: float = int(seat[4]) * PI * 0.5
		var want: Array = [Vector3(cos(angle), 0, sin(angle)),
			Vector3(0, 1, 0), Vector3(-sin(angle), 0, cos(angle))]
		var same: bool = true
		for i: int in 3:
			if not (turn[i] as Vector3).is_equal_approx(want[i] as Vector3):
				same = false
		if same:
			return true
	return false


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
## at the middle of cell zero — across and deep, the corner of the whole
## studs it stands on rather than of its cover. Cached: a design of four
## hundred bricks asks this for each of them, twice, and the answer
## depends only on the part and which way it is turned.
##
## The cover's own corner was the answer, and for most parts it is the
## same one. Not for a part drawn inside its footprint: a 4 x 4 wing
## (3935) has its cut edge at -38 of a -40 box, a turntable's top (3679)
## is 36 across on a 2 x 2, a flag's (4495b) clip is 16 wide on its stud.
## Placed at whole studs by that corner, each landed a tenth of a stud
## off the studs it stood on, and the owner saw it: the wing tips of a
## tower of Orthanc not sitting on their studs, 24 of them in one model.
## The patterns that lay wings meant the footprint all along.
##
## Kept by part and then by the basis itself. The key was the two written
## out as one string, and writing a Basis out is nine numbers formatted:
## most of the 142 ms that placing the owner's 4,242-part Falcon Heavy
## spent working out where its parts go, and asked again by every check,
## every look and every reading of the model. A check on a worker
## (_checked) keeps its own, behind a lock, so neither thread writes a
## Dictionary the other is reading.
var _corner_cache: Dictionary = {}     ## part id -> {Basis: Vector3i}
var _corner_off_main: Dictionary = {}
var _corner_lock := Mutex.new()


func _corner_cell(part: Lbm.PartMesh, part_id: String, basis: Basis) -> Vector3i:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		_corner_lock.lock()
		var known: Variant = (_corner_off_main.get(part_id, {}) as Dictionary).get(basis)
		if known == null:
			known = _work_out_corner(part, part_id, basis)
			if not _corner_off_main.has(part_id):
				_corner_off_main[part_id] = {}
			(_corner_off_main[part_id] as Dictionary)[basis] = known
		_corner_lock.unlock()
		return known
	var by_basis: Variant = _corner_cache.get(part_id)
	if by_basis == null:
		by_basis = {}
		_corner_cache[part_id] = by_basis
	var found: Variant = (by_basis as Dictionary).get(basis)
	if found != null:
		return found
	var lo: Vector3i = _work_out_corner(part, part_id, basis)
	(by_basis as Dictionary)[basis] = lo
	return lo


func _work_out_corner(part: Lbm.PartMesh, part_id: String, basis: Basis) -> Vector3i:
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := -lo
	for cell: Vector3i in builder._cells_for(part, Transform3D(basis, Vector3.ZERO)):
		lo = Vector3i(mini(lo.x, cell.x), mini(lo.y, cell.y), mini(lo.z, cell.z))
		hi = Vector3i(maxi(hi.x, cell.x), maxi(hi.y, cell.y), maxi(hi.z, cell.z))
	if lo.x == 0x7FFFFFFF:
		lo = Vector3i.ZERO
	# Upright or upside down only. On its side a part's height runs across,
	# and that is measured in plates, not studs. And not a minifigure's: a
	# skeleton's neck stud sits on a line and its arms reach past its legs,
	# and a figure is put together by its own transforms, not on studs.
	elif absf((basis * Vector3.UP).y) > 0.99 and not _figure_part(part_id):
		lo.x = _footprint_start(part, basis, 0, lo.x, hi.x + 1)
		lo.z = _footprint_start(part, basis, 2, lo.z, hi.z + 1)
	return lo


## A minifigure's part or accessory, which stands on no stud grid.
func _figure_part(part_id: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return info != null and info.family_category().begins_with("Minifig")


## The cell a part's footprint starts at along x (0) or z (2): its cover's
## first cell [param lo], moved to the nearest line of the part's own stud
## grid.
##
## The grid is read off the studs facing up or down, or the tubes when it
## has no studs. A stud stands in the middle of a square of that grid, so
## its lines are half a stud either side — except on a jumper, whose one
## stud sits on a line, so the other grid is tried too and taken when the
## cover fits it exactly. A part with neither stands on no stud — a pane, a pin, a
## door — and keeps the cover's corner.
##
## The nearest line, and outward only on a tie: a seat's backrest hangs 4
## LDU behind its 2 x 2, and moved out to the next line its corner was a
## whole stud from the studs it stands on.
func _footprint_start(part: Lbm.PartMesh, basis: Basis, axis: int,
		lo: int, hi: int) -> int:
	var per: int = int(round(STUD / BrickLattice.CELL))
	var phases: Array[int] = []
	for kind: String in ["stud", "tube"]:
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != kind \
					or absf((basis * connector.axis).normalized().y) < 0.99:
				continue
			var at: int = int(round((basis * connector.position)[axis]
				/ BrickLattice.CELL))
			var middle: int = posmod(at - per / 2, per)
			phases = [middle, posmod(middle + per / 2, per)]
			break
		if not phases.is_empty():
			break
	if phases.is_empty():
		return lo
	# The stud's middle, unless the cover lies exactly on the other grid
	# and not on this one, which is what a jumper's does. Weighed any more
	# loosely the other grid won for a tap, whose spout leaves its cover
	# fitting neither.
	var fits: Array[int] = []
	for phase: int in phases:
		fits.append(absi(lo - _nearest_line(lo, phase, per, -1))
			+ absi(hi - _nearest_line(hi, phase, per, 1)))
	var phase: int = phases[1] if fits[1] == 0 and fits[0] > 0 else phases[0]
	return _nearest_line(lo, phase, per, -1)


## The line of a grid [param per] cells apart, offset [param phase], that
## is nearest [param at]; on a tie, the one on the [param out] side.
static func _nearest_line(at: int, phase: int, per: int, out: int) -> int:
	var below: int = at - posmod(at - phase, per)
	if below == at:
		return at
	var above: int = below + per
	if at - below < above - at or (at - below == above - at and out < 0):
		return below
	return above


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
	return Transform3D(basis, BrickLattice.to_ldu(want - corner) + placement.nudge)


# -- applying ------------------------------------------------------------


## Make sure every part a design uses is to hand before placing any of
## it. On the web most are fetched rather than shipped, and a model that
## lands half-built because the rest was still downloading is worse than
## one that takes a moment longer.
func _ensure_parts(model: Model) -> void:
	var wanted: Dictionary = {}
	# A retired number is placed as the part it became (BrickWorld._place),
	# so that is the geometry wanted too.
	# Each part once: asked per placement, Brick Art's 1,327 tiles of a few
	# kinds were a frame of 178 ms in a browser (progress_check, 2026-10-15).
	var named: Dictionary = {}
	for placement: Placement in model.placements:
		if named.has(placement.part):
			continue
		named[placement.part] = true
		var real: String = library.resolve(placement.part)
		if real != placement.part:
			named[real] = true
	for part_id: String in named:
		# From disk first, where the build has it: only what is not there is
		# fetched. Not resident meant fetched over HTTP even on the desktop,
		# whose every part is on disk; the request failed, and the wait for it
		# was the twenty seconds below. add_rooms, which asks for seventy
		# parts at once, spent most of its time here, and the first Orthanc
		# run to use it logged a column of "could not fetch".
		if not library.is_resident(part_id):
			library.mesh_for(part_id)
		if not library.is_resident(part_id):
			wanted[part_id] = true
	if wanted.is_empty():
		return

	progress.emit("fetching %d part%s" % [
		wanted.size(), "" if wanted.size() == 1 else "s"])
	for part_id: String in wanted:
		library.request_mesh(part_id)

	# Wait for them, but not forever: a part that never arrives should
	# cost a few seconds, not the whole design. On the Working bar while
	# it waits, as any slow thing is: a tool asked from outside answers
	# once its parts are here, and the person sees why it is taking a moment.
	var fetching: int = wanted.size()
	var job: Working.Job = Working.begin("Fetching %d part%s…" % [fetching,
		"" if fetching == 1 else "s"], fetching)
	# Until each has come or is not coming (it failed, or there is nowhere
	# to fetch it from), not for a fixed few seconds: a fetch is polled once
	# a frame, and a browser drawing in software at a few frames a second
	# took longer than the twenty seconds this once allowed, so a check said
	# a gear "has not arrived" that was on its way.
	var deadline: int = Time.get_ticks_msec() + FETCH_WAIT_MS
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		for part_id: String in wanted.keys():
			if library.is_resident(part_id) or not library.is_on_its_way(part_id):
				wanted.erase(part_id)
		job.count(fetching - wanted.size())
	job.end()


## The longest a part's geometry is waited for, ms: a request that never
## answers. One that fails stops the wait at once.
const FETCH_WAIT_MS := 120000


## The plate of each tile's size: what a tile is laid again as where
## something stands on it.
const TILE_PLATES: Dictionary = {
	"3070b": "3024", "3070a": "3024", "3069b": "3023", "3069a": "3023",
	"63864": "3623", "2431": "3710", "6636": "3666", "4162": "3460",
	"3068b": "3022", "3068a": "3022", "26603": "3021", "87079": "3020",
	"98138": "6141", "14769": "4032a",
}


## Every part a model needs, then the studs under whatever stands on a tile
## (see [method _studs_where_stood_on]) and the plates that brings. Awaited,
## as [method _ensure_parts] is. Every design and every edit comes through
## here before it is checked, so what is checked is what is built.
func _ready_to_check(model: Model) -> void:
	await _ensure_parts(model)
	if _studs_where_stood_on(model) > 0:
		await _ensure_parts(model)
	await _ensure_exact(model)
	# A part said by its connectors whose geometry had not arrived when it was
	# read (the web build fetches it): put where they say, now that it has.
	_attach_parts(model)


## Every exact shape a check of [param model] reads, to hand: on the desktop
## read from disk as it is asked for; in the browser fetched from beside the
## geometry, and waited for as the geometry is (a part BrickNet does not have
## is answered at once, with none).
func _ensure_exact(model: Model) -> void:
	if library == null:
		return
	# Asked once a part, not once a placement: in the browser a shape not yet
	# fetched is looked for in the pack each time it is asked for, and the
	# Falcon's 4,242 placements of 20 parts held the page for 8 seconds.
	var parts: Dictionary = {}
	for placement: Placement in model.placements:
		parts[placement.part] = true
	var wanted: Dictionary = {}
	for part_id: String in parts:
		if not Exact.known(library, part_id):
			Exact.shape_for(library, part_id)
			if not Exact.known(library, part_id):
				wanted[part_id] = true
	if wanted.is_empty():
		return
	var deadline: int = Time.get_ticks_msec() + FETCH_WAIT_MS
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		for part_id: String in wanted.keys():
			if Exact.known(library, part_id) or not library.is_exact_on_its_way(part_id):
				wanted.erase(part_id)


## A part standing on a tile grips nothing: a tile has no stud for it. The
## owner's orrery stood a collar on a shape's tiled top, and it floated —
## held, the check said, because resting on a part counts as held up. A
## builder tiles a top only where nothing will stand on it, and where
## something goes on a tile the tile becomes the plate of its size. The
## same size, not plates under the part and tiles round it: a top's tiles
## often tie the plates under them together, and split, a rooms floor's
## 1 x 2 tile left a 1 x 1 plate and the tile on it held by nothing. So
## wherever a part that takes studs is put down studs-up on a tile, the tile
## is that plate, in the same change, so one undo takes back both. Only a
## tile square to the grid and on it, in no section; Shapes keeps the studs
## of its own tops under what the design stands there (Patterns.expand).
## Returns how many tiles changed.
func _studs_where_stood_on(model: Model) -> int:
	if library == null or builder == null:
		return 0
	var tiles: Array[int] = []
	var tops: Dictionary = {}       ## a tile's top, in plates -> true
	for n: int in model.placements.size():
		var placement: Placement = model.placements[n]
		if TILE_PLATES.has(placement.part) and _square_on_grid(placement):
			tiles.append(n)
			tops[roundi(placement.y) + 1] = true
	if tiles.is_empty():
		return 0
	# What could stand on one: a part that takes studs, studs up, its foot at
	# a tile's top — and one this change puts down or moves. An edit is read
	# from the whole model, and the person's own parts resting on their own
	# tiles are theirs, not the edit's to re-lay.
	var standing := BrickLattice.new()
	standing.keeps_columns = false
	for n: int in model.placements.size():
		var placement: Placement = model.placements[n]
		if (placement.id != 0 and not placement.moved) or not placement.attach.is_empty() \
				or placement.face != "up" or not placement.section.is_empty() \
				or not is_equal_approx(placement.y, roundf(placement.y)) \
				or not tops.has(roundi(placement.y)):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(placement.part)
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if info == null or info.socket_count == 0 or mesh == null:
			continue
		standing.occupy_boxes(n + 1, builder.boxes_for(mesh, _transform(placement, mesh)))
	# About a selection, a tile of the model round it is not this change's.
	var scoped: bool = _keeps_to_focus()
	var changed: int = 0
	var over: BrickLattice = null    ## every part whose foot is at a tile's top
	for n: int in tiles:
		var tile: Placement = model.placements[n]
		var mesh: Lbm.PartMesh = library.mesh_for(tile.part)
		if mesh == null:
			continue
		var at: Transform3D = _transform(tile, mesh)
		if scoped and tile.id != 0 and not focus.holds(
				SelectionScope.box_of(tile.part, at, library)):
			continue
		var box: PackedInt32Array = BrickLattice._bound_of(builder.boxes_for(mesh, at))
		var per: float = float(BrickLattice.CELLS_PER_STUD)
		var studs: Array[Vector2i] = []
		for sx: int in range(floori(box[0] / per), ceili(box[3] / per)):
			for sz: int in range(floori(box[2] / per), ceili(box[5] / per)):
				studs.append(Vector2i(sx, sz))
		if standing.standing_on(studs, box[4], n + 1).is_empty():
			continue
		# Nor where the plate's studs would run into another part over it that
		# takes none there: one off the grid, on its side, or solid under. A
		# rooms floor tiled under an armchair's arms and a dresser's door rail
		# plates came back as plates whose studs stood 4 LDU into them, by the
		# parts' real shapes, because a turntable beside them took studs.
		if over == null:
			over = _feet_at(model, tops)
		if _studs_would_meet(model, over, n, str(TILE_PLATES[tile.part]), box):
			continue
		# A part changed is another brick to the edit (Assistant._apply_edit):
		# the tile comes off and the plate goes on, in this one change.
		tile.part = str(TILE_PLATES[tile.part])
		changed += 1
	if changed > 0:
		progress.emit("laid %d tile%s again as plates, under what stands on %s"
			% [changed, "" if changed == 1 else "s", "it" if changed == 1 else "them"])
	return changed


## Every part of [param model] whose foot is at one of [param tops] (in
## plates), whatever its face or section, in a lattice of its own.
func _feet_at(model: Model, tops: Dictionary) -> BrickLattice:
	var out := BrickLattice.new()
	out.keeps_columns = false
	var per: int = roundi(PLATE / BrickLattice.CELL)
	for n: int in model.placements.size():
		var placement: Placement = model.placements[n]
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			continue
		var boxes: PackedInt32Array = builder.boxes_for(mesh,
			_transform(placement, mesh, model.section_for(placement)))
		if boxes.is_empty():
			continue
		var low: int = BrickLattice._bound_of(boxes)[1]
		if posmod(low, per) == 0 and tops.has(low / per):
			out.occupy_boxes(n + 1, boxes)
	return out


## Whether [param plate], laid where tile [param n] of [param model] is (its
## lattice bound [param box]), would stand a stud in a part over it by the
## parts' real shapes (Exact): a part there that takes no stud.
func _studs_would_meet(model: Model, over: BrickLattice, n: int, plate: String,
		box: PackedInt32Array) -> bool:
	var tile: Placement = model.placements[n]
	var laid: Placement = Placement.from_dict({"part": plate, "x": tile.x, "y": tile.y,
		"z": tile.z, "rot": tile.rot})
	var mesh: Lbm.PartMesh = library.mesh_for(plate)
	var shape: Exact.Shape = Exact.shape_for(library, plate)
	if mesh == null or shape == null or not shape.has_pieces():
		return false
	var mine := Exact.Item.new(shape, _transform(laid, mesh))
	var reach: int = ceili(6.0 / BrickLattice.CELL)    ## a stud and a hair
	for key: int in over.blockers_boxes(PackedInt32Array([box[0], box[4], box[2], box[3],
			box[4] + reach, box[5]]), n + 1):
		if key <= 0 or key - 1 == n:
			continue
		var other: Placement = model.placements[key - 1]
		var theirs: Exact.Shape = Exact.shape_for(library, other.part)
		var other_mesh: Lbm.PartMesh = library.mesh_for(other.part)
		if theirs == null or other_mesh == null or not theirs.has_pieces():
			continue
		var item := Exact.Item.new(theirs, other.exact_at(_transform(other, other_mesh,
			model.section_for(other))))
		if not Exact.clash(mine, item).is_empty():
			return true
	return false


## Studs up, square to the grid on whole studs and plates, in no section.
static func _square_on_grid(placement: Placement) -> bool:
	return placement.face == "up" and placement.section.is_empty() \
		and is_equal_approx(placement.x, roundf(placement.x)) \
		and is_equal_approx(placement.y, roundf(placement.y)) \
		and is_equal_approx(placement.z, roundf(placement.z))


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
	fresh_ids = _changed_ids.duplicate()
	built.emit(_placed_ids.size())


## Put a model on the baseplate, replacing whatever the assistant built
## last time and leaving anything the person placed by hand alone.
##
## [param gradually] spreads it over frames, a slice at a time (FramePace),
## for the tools: putting down the owner's 4,242-part Falcon Heavy was 0.4 s
## in one frame on the desktop and more in a browser. What is drawn stays as it
## was until the whole design is down (BrickWorld.hold_drawing), so the
## build animation that follows is the first anyone sees of it. Without it,
## as the probes call it, all at once and never waiting.
##
## A design of this app's own loop can be stopped while it is going down:
## Stop puts the model back as it was (_restore) from what has been placed
## so far, and the rest is then not placed.
func _apply(model: Model, finished: bool = true, gradually: bool = false) -> void:
	if gradually:
		world.hold_drawing()
	var running: bool = _busy
	var pace := FramePace.new()
	# What stands already and is the same as before stays, under its
	# number; only what changed comes down or goes up.
	#
	# Every submit, and every check from outside, took the whole design
	# down and put it back renumbered. A session that read the numbers,
	# resubmitted to fix one corner and then edited by them was editing
	# other bricks: the eleventh Orthanc said so, "the rock's brick
	# numbers changed when I resubmitted". And the history the timeline
	# replays was every brick removed and added again per resubmit, with
	# the real changes lost among them. The sketch counts too, or a
	# design lands on top of its own draft: every brick twice.
	var standing: Dictionary = {}  ## _same_key -> brick ids
	for brick_id: int in _placed_ids + _sketched_ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var key: String = _same_key(brick.part_id, brick.color_code,
			brick.transform)
		if not standing.has(key):
			standing[key] = []
		standing[key].append(brick_id)
		if gradually and pace.due():
			await pace.next()
			if running and not _busy:
				world.release_drawing()
				return

	# A part whose geometry never arrived used to be skipped here in
	# silence, and what the person got was the design minus its wheels
	# with nothing to say so. Say so.
	var missing: Dictionary = {}
	var at_of: Dictionary = {}  ## placement index -> where it goes
	var kept: Dictionary = {}   ## placement index -> the brick it already is
	for index: int in model.placements.size():
		var placement: Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			missing[placement.part] = true
			continue
		var at: Transform3D = _transform(placement, part,
			model.section_for(placement))
		at_of[index] = at
		var same: Array = standing.get(_same_key(
			library.resolve(placement.part), placement.color, at), [])
		if not same.is_empty():
			kept[index] = same.pop_back()
		if gradually and pace.due():
			await pace.next()
			if running and not _busy:
				world.release_drawing()
				return
	# Down first, so nothing new is registered inside what is leaving.
	for key: String in standing:
		for brick_id: int in standing[key]:
			builder.lattice.release(brick_id)
			world.remove_brick(brick_id)
	_sketched_ids = PackedInt64Array()
	_placed_ids = PackedInt64Array()
	fresh_ids = PackedInt64Array()

	var order: Array = at_of.keys()
	for step: int in order.size():
		var index: int = order[step]
		var placement: Placement = model.placements[index]
		var brick_id: int = kept.get(index, 0)
		if brick_id == 0:
			brick_id = world.add_brick(placement.part, placement.color,
				at_of[index])
			if brick_id == 0:
				continue
			builder.register(brick_id, placement.part, at_of[index])
			fresh_ids.append(brick_id)
		_remember_section(brick_id, placement, model)
		if placement.mine:
			_placed_ids.append(brick_id)
		if gradually and pace.due():
			await pace.next()
			if running and not _busy:
				# Stop put back the model from what had been placed; what
				# was standing and not reached yet is part of neither.
				for later: int in order.slice(step + 1):
					var standing_id: int = kept.get(later, 0)
					if standing_id != 0:
						builder.lattice.release(standing_id)
						world.remove_brick(standing_id)
				world.release_drawing()
				return
	if gradually:
		world.release_drawing()

	if not missing.is_empty():
		var names: Array = missing.keys()
		names.sort()
		progress.emit("%d part%s could not be loaded and %s left out: %s" % [
			names.size(), "" if names.size() == 1 else "s",
			"was" if names.size() == 1 else "were",
			", ".join(PackedStringArray(names.slice(0, 6)))])

	if finished:
		var named: String = model.name.strip_edges()
		if not named.is_empty() and named != "Model":
			titled.emit(named)
		if not model.stands_on.is_empty():
			floor_chosen.emit(model.stands_on)
		built.emit(_placed_ids.size())
	else:
		sketched.emit(_placed_ids.size())


## The same brick, as far as putting a design down again goes: the part,
## the colour and where it is, to a hundredth of an LDU.
static func _same_key(part_id: String, colour: int, at: Transform3D) -> String:
	var b: Basis = at.basis
	return "%s|%d|%.2f %.2f %.2f|%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f" % [
		part_id, colour, at.origin.x, at.origin.y, at.origin.z,
		b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]


## The bricks the last build or edit put down or moved, which were not
## standing as they are before it. What the build animation shows going up:
## the rest was already there.
var fresh_ids := PackedInt64Array()


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
	_given_names.clear()
	_nudged.clear()
	# A selection names bricks by number too.
	unfocus()
	# And what it was of: a model cleared or opened from outside starts a new
	# subject, or the statue built before it makes the lighthouse after it a
	# figure. The brief a session was started on stays.
	if not _busy:
		_brief = ""
		_heard = _heard_fresh


func clear_built() -> void:
	for brick_id: int in _placed_ids + _sketched_ids:
		builder.lattice.release(brick_id)
		world.remove_brick(brick_id)
		_section_of.erase(brick_id)
		_local_of.erase(brick_id)
		_given_names.erase(brick_id)
		_nudged.erase(brick_id)
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
			+ "%d different shapes, %d colours, at most about %d of "
			% [int(entry.get("shapes", 0)), int(entry.get("colours", 0)),
				int(entry.get("most_of_one", 0))]
			+ "any one piece, and %d%% of its pieces as big as a 2 x 4 "
			% int(entry.get("big", 10)) + "brick")
	return ("\n\nWHAT A SET IS MADE OF\nMeasured over every LEGO® set there "
		+ "is, by size:\n" + "\n".join(lines)
		+ "\nThese are medians of real sets, not a target to hit exactly. "
		+ "What they are for is the shape of the mistake: a model that is "
		+ "the right size with a third of the variety is repetitive, and it "
		+ "reads as built rather than designed. Eighty of one brick where "
		+ "two dozen is usual means a wall was extruded instead of "
		+ "detailed. The way out is not more parts, it is more different "
		+ "parts — a tile where the wall turns, a bracket for a sign, a "
		+ "slope where the roof meets the gutter. And small ones: one "
		+ "piece in ten as big as a 2 x 4 brick is what a real set is, at "
		+ "every size. Its walls are 1 x 2, 1 x 3 and 1 x 4 bricks, and "
		+ "its texture is what those small pieces are free to be.")


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
		+ "parts in the history of LEGO® sets, counted over every catalogued set "
		+ "inventory:\n" + "\n".join(lines)
		+ "\n\nRead the shape of that list, not the individual numbers. A "
		+ "LEGO® set is mostly plates: the 2x4 brick everyone pictures is "
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

When you write to the person, LEGO® is a brand name: in capitals, with \
its ®, and an adjective (LEGO® bricks, a LEGO® set), never plural or \
possessive. The company is the LEGO Group.

BRICK ART
A picture to hang up — a mosaic in the style of LEGO® Art sets, \
wall art, a portrait or a scene in bricks — is not modelled with \
submit_design. Call make_art, which lays it the way a LEGO® Art set is \
laid while you decide what its designer would. With a picture the person \
chose, look_at_picture first; with \
none, draw it in make_art's svg. {31212}

COORDINATES
Positions are in brick units, not millimetres.
  x and z count studs across the baseplate.
  y counts plates upward from the ground, which is y=0.
  A brick is 3 plates tall. A plate is 1. A tile is 1.
  x, y, z is the LOW CORNER of the part's footprint, not its centre.
  A 2x4 brick at x=0,z=0 covers studs 0..3 across and 0..1 deep.
  The footprint is the whole studs a part stands on, even where it is \
drawn inside them — a wing plate's cut edge, a turntable's round top, \
an antenna's base — so whole numbers seat those on their studs too.
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
mechanism — a chassis, a steering linkage, a hinge, an arm that moves, \
a gear train — they are the wrong way. check_design accepts a part held \
by a pin, an axle or a ball joint exactly as it accepts one held by a \
stud. A beam pinned to another beam with nothing underneath either of \
them is held.
  The parts: 32523, 32316 and 32524 are Technic beams 3, 5 and 7, with \
a hole every stud along their length. 3700, 3701, 3894 and 3702 are \
bricks 1x2, 1x4, 1x6 and 1x8 with holes through them, which is how a \
mechanism meets a studded wall. 2780 is the friction pin that holds two \
beams together; 3673 is the frictionless one, for something that must \
turn; 4274 is a pin with a stud on one end. 4519, 3705, 3706 and 3707 \
are axles 3, 4, 6 and 8. Gears: 3647 has 8 teeth, 69779 20, 3648b 24, \
3649 40, and 4716 is a worm. A bush (3713) or a half bush (4265c) on an \
axle against a wall stops it sliding. 6632, a thin liftarm with an axle \
hole at each end, is a crank or an arm.
  What turns: a round hole (every beam's and every brick's) lets an \
axle turn in it; an axle hole (the cross in a gear, a bush, a liftarm's \
end) grips the axle, and the part turns with it. A gear on a round hole \
spins free and drives nothing. An axle carries every part on its line, \
all along its length, so one axle goes through both walls of a frame \
and the gear between them. attachment_points says of each hole which it \
is, and check_design says what each axle grips and turns in.
  Say a pin, an axle, a gear, a bush or a liftarm by its line: axis \
"z" (the way it runs) and, for x, y and z, the point attachment_points \
gives the hole it goes in. They are then where the part's own middle \
goes, not its low corner. A part with more than one hole or axle takes \
joint: n, numbered as attachment_points lists them, and rot turns it \
about the line, a quarter at a time. To slide it along the line, change \
the one coordinate the line runs along: a gear a stud further along an \
axle running along z is z + 1. Do not work a corner out instead: a \
hole sits at the middle of the part's thickness, and a gear's corner is \
half its width off its hole.
  Gears mesh with their centres 1.25 LDU a tooth apart across their \
axles, in one plane: an 8 and a 24 at 40 LDU, which is 2 studs; 24 and \
24 at 3 studs; 40 and 40 at 5; 8 and 40 at 3; 16 and 16 at 2; a worm \
and a 24 at 2. So put the two axles through holes that far apart and \
the gears at the same place along them. check_design forgives gears in \
mesh and names each mesh; two too near, or nearly in mesh, are told the \
spacing they mesh at. For a ratio no two gears give (a planet's year, a \
clock's hours), search_gear_ratio gives the nearest trains of real gears \
on the stud grid, with to= every axle between two holes, and \
simulate_mechanism then reads what the parts give. A gear between two others, an idler, makes the \
last turn the same way as the first. Gears reduce by the ratio of their \
teeth: an 8 driving a 24 turns it a third as fast. find_techniques with \
"gear train" or "worm" shows how real sets built one, and \
place_technique lays one of them where you say.

WHAT MAKES A MODEL LOOK REAL
The difference between a model that reads as the thing and one that \
reads as bricks is nearly always one of these.
  Surfaces that are meant to be smooth are tiled, not studded. A roof, \
a road, a table top, a bonnet.
  Shapes that are meant to be curved use parts that are curved. Slopes \
for a roof, curved slopes for a bonnet, round bricks and cones for a \
chimney or a tree trunk, dishes for a dome.
  Colour is chosen, not scattered. A main colour, two or three close \
tones of it for texture and wear, and accents where something changes — \
a door, a band, a roof, a lamp. Real sets are not two-colour: one of \
2,000 parts uses about twenty-five, most of them on a handful of small \
parts each. What reads as random is colour with no reason to be there.
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
A colour is an LDraw number. Do not recall one — these are the colours \
in real sets of the last couple of years, commonest first, by the set \
inventories. A number not in this list is very likely either wrong or a \
shade that was discontinued, and one that is not a colour at all is \
refused: 16 and 24 are codes inside LDraw's part files, not plastic.

""".replace("{31212}", ArtPlan.REFERENCE) + _palette_lines() + """

71 and 72 are the greys modern sets use. 7 and 8 are the greys sets \
used until """ + _old_greys_until() + """ and they read as slightly green \
beside anything else; do not reach for them because "grey" sounds like a \
low number.

Colour is not decoration, it is how a shape is read. A hull that is one
colour throughout reads as a block whatever its silhouette; the same
hull with its recesses a shade darker reads as having depth. Pick two
or three and let a fourth be the accent.

AT AN ANGLE
face and rot only ever give you square quarter turns. Much of what makes \
a model look like the real thing is not square: a nacelle pylon raked \
back, a wing swept, a hatch standing open, a roof at a pitch no slope \
brick makes, the panels of a dome.

Say those as a SECTION. A section is a part of the model you build \
square, in its own ordinary studs and plates from its own corner, and \
then carry somewhere turned:

  sections: [{name: "port pylon", x: 14, y: 8, z: 6, yaw: 20, pitch: 35}]

Every brick with section: "port pylon" is then written as though that \
pylon were sitting flat at the origin — x from 0, y from 0 — and the \
whole thing is turned and carried to 14,8,6. This is how a real set \
does it and how a set's instructions read: build the assembly, then \
attach it.

Do not try to angle bricks one at a time. Working out where each brick \
lands once it is rotated is trigonometry, you would have to do it \
forty times for one pylon, and every one of those is a chance to be a \
tenth of a stud out.

A turn is said yaw, then pitch, then roll, in degrees, and a section's \
own +z is its nose:

  yaw    swings the nose from +z towards +x, about the upright
  pitch  then lifts the nose
  roll   then lifts its +x side

Yaw and pitch together face a panel any way at all — yaw says which way \
round it faces, pitch tips it back — which one axis cannot: a dome whose \
panels could only turn about one axis came out a pyramid. Or one turn \
about one pin, axis "x", "y" or "z" (or line: [x, y, z]) and degrees, \
whose sign is worth getting right first time:

  about z  leans the top towards -x (leftward), keeping +z forward
  about x  leans the top towards +z (backward)
  about y  swings the nose from +z towards +x, without tilting

Negate an angle to go the other way: for a pair of raked pylons, one is \
the negative of the other. One part on its own takes yaw, pitch and roll \
too, turned about its own corner; it becomes a section of one.

A section within another (within: "wing") has its x, y and z in that \
one's own coordinates and goes wherever it goes: a flap on a wing, a \
panel hinged on a panel.

A section that leans turns on a joint, as it does in plastic, and \
hinge: lays both halves of a real one for you and turns the section \
about the line they share:

  sections: [{name: "spire", x: 6, y: 18, z: 3, pitch: 15,
              hinge: "tilting"}]

  "tilting" (or true): a hinge brick's base, 3937, with its top, 3938, \
resting closed on it. The section's bricks start at 0,0,0 on the top's \
two studs, which run along the pin, so a spire, a horn or a raked pylon \
is written as if it stood square on a 1 x 2 plate.
  "clip": a plate with a bar on its end (60478) and a plate with a clip \
on its end (63868), resting in line. The base runs along the nose to its \
bar, the section starts on the clip plate's studs beyond it, and pitch \
lifts the section about the bar.
  "click": click hinge plates, 44302 then 44301, the same way round, \
where this build's parts say where their fingers are.

x, y, z are then where the base stands, like any brick's, in the \
coordinates of whatever the section is within; yaw turns the base and \
all on it about the base's first stud, as a part on one stud swivels; \
pitch (or roll, with axis "z") turns the section about the joint's line. \
{HINGE LINES} A hinge turns about one line, so it takes a pitch or a \
roll and not both: to tip two ways, hinge a section within a hinged one. \
A section that only rests against the model at a slant grips none of the \
studs it sits on and is refused. Turned only about the upright, or by \
quarter turns, it stands on studs as anything else does.

Something rigid and turned meets a flat face along a line, so the \
height at which a section touches the hull without digging into it is \
a narrow band — a fraction of a plate, not a whole one. Do not hunt for \
it. When a section does not fit, the checker sweeps and tells you the y \
where it would; use that number.

Keep sections for the places the angle is what makes the shape read — \
a raked pylon, a swept wing, an opened hatch, a curve that must not be \
a staircase. Everything else is quicker and steadier square. And if a \
section still will not attach after two tries, build that one assembly \
square and say so in your reply: a model that is ninety percent right \
and standing is worth more than a perfect pylon and nothing under it. \
One design spent every turn it had on a fifty-degree pylon and \
submitted nothing at all.

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
that falls off when the model is picked up. Give a section a new yaw, \
pitch or position with edit_model — its name and only what changes — and \
everything in it, and within it, moves together, which is how a hatch is \
opened further without describing a single brick again.

ROUND BODIES AND DOMES
A curve built in square plates is a staircase however fine the steps. \
Real sets make a round body one of three ways, by its size. Choose by \
how it is built, not by what the subject is.

  Moulded parts, when one fits: a dish for a dome's cap (4740 2x2, 3960 \
4x4, 44375b 6x6, 3961 8x8, 50990b 10x10), round bricks and plates for a \
column, cones for a taper, round corner bricks for a quarter ring \
(85080 2x2, 2577 and 48092 4x4). Up to about ten studs across, a dish \
or a stack of round plates under curved slopes is the whole answer. \
A smooth dome 16 studs across is four 87375 quarter domes clipped on \
58846 tapered corners: show_technique "smooth dome".
  Sideways skins, for a band, a body lying on its side, an egg, a car's \
curved flank: a core with studs out on its sides (11211, 87087, 4733, \
brackets 99780 and 99207), and on each side a section turned to face out \
— pitch -90 and yaw 0, 90, 180, 270 — built flat as a lens: a plate the \
side's width, curved slopes (15068, 93606, 11477, 61678) falling away to \
its ends, tiles between. Four skins round a square core read round. The \
BB-8 sets and the Saturn V are built so.
  Hinged panels, for a dome or a ball bigger than a dish: the surface \
cut into flat panels, each plates with tiles on them on a hinge, tipped \
to the curve, no two at the same angle. 10143, the Death Star II, is \
sixteen shell segments carrying panels on click hinges. Say it as one \
pattern and the app lays it closed:
    {"pattern": "shell", "kind": "dome" or "ball", "across": studs over \
its panels, 20 to 32 (a ball 24 to 32), "at": {x, y, z} the middle of where \
it stands, "color": the panels, "frame_color": its ring and hinges}
Twelve strips of panels on clip hinges stand round a ring, each panel \
hinged at the far end of the one below ({HINGE NEXT}) and folded in by a \
band's angle. Each band's panels are sized to the round they are on: the \
strips take turns, the low ones a little narrower than their share, the \
high ones two plates up and wide enough to lap both their neighbours' \
edges; wedge plates in left and right pairs taper each panel toward the \
pole; each band's last row stands a plate higher, its tiles reaching two \
studs over the band above, which folds in under them. Where the strips \
would crowd near the top, discs of plates stepping in as the sphere does, \
under a dish, are the crown; a course of bricks round the ring closes the \
foot. A ball hangs the same strips under the ring, a course round its \
middle, and stands on a column. Every band is a section named for its strip and band \
("shell 3.2"), so an edit can recolour or turn one. Built by hand instead \
— a partial dome, a shell that is not round — keep what closes it: no \
panel wider than its share of the round at either end, the next strip's \
over its edges, a lip over each seam. show_technique("hinged panels") is \
one strip, built and checked.

FIGURES, CREATURES AND SMALL MODELS
A figure, a creature, a character, or anything a hand closes round, is not \
a small hull. The shape, fill, round and shell patterns fill a volume with \
bricks and skin it, which is how a set builds a hull, a car body, a \
fuselage, a boiler or a building. A figure built that way is a statue of \
stacked bricks, and the judge called every one built here that. A set \
builds a character from tens of parts to a couple of hundred, each chosen \
for the shape it makes, in sub-assemblies joined at angles.
  Start it as the figure pattern, one entry of submit_design's patterns: \
{"pattern": "figure", "kind": "person", "at": {"x": 4, "y": 0, "z": 4}, \
"height": 36, "color": 1, "colors": {"skin": 78, "legs": 72, "hair": 70}, \
"pose": {"right arm": "down", "left arm": "raised", "head": 20}} lays a \
person feet to crown with its arms on ball shoulders, posed by words (down, \
bent, forward, raised, out; "seated": true on a seat of \
its own), and its head turning on a jumper's stud; "kind": "animal" with a \
"length" in studs four legs, a body, the head on a ball neck and the tail \
on a bar; "kind": "head" a head on a neck. Every part is named ("head", \
"chest", "left hand", "tail"): attach your own to them (a hat on \
"hair.stud[0]", a sword in "right hand"), or pose one again with an edit's \
align or yaw. Then dress it: a face, clothes, a hat, what it holds.
  The brief is the scope and the size. Build what it names (each figure, \
what they hold, what they stand on) in its proportions (tiny, squat, \
round, a head as big as its body), and nothing it does not name: an \
unasked figure, creature, plant or fence is clutter, not a story. What it \
stands on is what the brief says (a log, a stool, a small base), a stud \
or two past its footprint; a figure alone stands on its feet.
  Its size. A person among things at minifigure scale is a minifigure: \
add_minifig, with real heads, helmets, armour and tools (a pilot, a \
chef at the stove). A brick-built figure or creature is about 6 to 16 \
studs tall, a cartoon's head a third of it or more.
  Each part of it a sub-assembly of shaped parts:
    a head   a 2 x 2 or 4 x 4 round brick (3941, 87081), a dome (30367c), a \
dish (4740, 3960) for a face or a cap, a cone (3942c) for a hat; eyes \
printed round tiles (98138p07, 14769p01) or 1 x 1 round plates; a beak, a \
snout or a muzzle a curved or cheese slope on a jumper
    a body   round bricks and round corner bricks (85080, 48092), curved \
slopes (15068, 11477, 93606) on bricks with side studs (87087, 11211), a \
dish for a belly, slopes falling for a robe
    a limb   turned to its pose on a joint, never butted on: a section on \
hinge "clip" (a bar in a clip: an arm, a wing, a tail, a lance), "click" \
or "tilting" (read_guide "angle"); a ball in a socket (22890 in 14418) for \
a shoulder or a hip
    held     a bar is a handle: a sword, a staff, a mop or an axe's \
shaft held in a clip (61252, 60897)
  Put each joint by its connectors, not its corner: a part's attach \
({"to": "torso.hinge[0]", "by": "hinge[0]", "yaw": 30}) seats it exactly at \
any angle; show_technique "posed minifigure", "limb on a clip", "ball \
shoulder", "head on a neck", "tail on a bar" and "hinged wing" are each one \
written out, and "jointed figure" and "jointed animal" a whole armature to \
pose and build on; place_technique lays any of them in one call.
  find_techniques with the part's own words ("head", "arm", "wing", "leg", \
"bird", "animal") finds the pieces real sets built; show_technique has "eye \
with a highlight", "beak or snout", "ears or tufts", "talons" and "leaning \
on a hinge"; search_parts "minifig" with a word finds a figure's parts.
  A pattern still fits the one big mass of a figure that is a hull (a \
boiler, a tank's body, a whale 20 studs long) under its shaped head, limbs \
and features.

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
The way a set is designed: the silhouette and its proportions first, then \
each feature the subject is known by, then the detail. In this order:

  1. plan_scale with how long the real thing is. Everything after it \
     depends on the proportions, and changing the scale later means \
     moving the whole model.
  2. find_reference, for anything that exists. A lighthouse you recall \
     is a tapering tower with a light on top, which is every lighthouse \
     and no lighthouse. A picture gives you this one.
  3. The silhouette. Decide the main masses and their sizes in studs, \
     off that picture and the brief, and what each is: round in section, \
     tapered, at a slant, smooth, moving, mechanical, organic. Say a \
     hull, a car body, a fuselage or a building as a shape and submit \
     that first: its proportions are judged before anything is put on \
     it. A figure, a creature or a character is not a shape: it is \
     sub-assemblies of shaped parts on joints (FIGURES, CREATURES AND \
     SMALL MODELS, above), submitted the same way first. WHAT THE \
     SUBJECT NEEDS, below, says which call builds each; \
     how_real_sets_build_this, asked with the plainest word for the \
     kind (a rocket: space; a locomotive: train; a galleon: pirate; an \
     owl: animal), says what real sets of it are made of and in, and \
     what our own scored designs of the nearest subject did and the \
     faults the judge found in them, to design out. The picture's \
     colours come with it as numbers.
  4. The feature list: what the subject is known by, given to \
     submit_design as features, each with where it goes (x, y, z and \
     the way it faces out) — an owl's facial disc, eyes, beak, ear \
     tufts, wings, talons; a car's wheel arches, headlamps, grille, \
     windscreen, spoiler; a castle's gate, arrow slits, crenellations, \
     turret roofs.
  5. Each feature, one at a time, once the shape stands: the app looks \
     up how real sets built it, lays the best piece that lays whole and \
     fits where the feature goes, and hands it to you with a picture. \
     settle_feature says what it is to be: accept it — moved, turned or \
     recoloured first if it needs it — "next" for the next-best piece, \
     reject it with a reason and build your own from the worked \
     technique (show_technique; faces and features has the eye, the \
     round face, the beak, ears, talons, headlamps and grille), or \
     "built". A design is not finished until each feature is settled. \
     A feature is parts with depth, never a tile painted on a panel. A \
     face on a shaped head is the shape's "face", said when the shape is \
     submitted: it lays the disc, 2 x 2 eyes and a beak on side studs, \
     flush with the curve. \
     find_parts_like finds a part by what it should read as — a \
     feather, a claw, an eyelid, an exhaust.
  6. show_technique for any construction you have not built before. \
     Being told to stagger a wall or turn a face sideways is not the \
     same as knowing where the stud sits, and the arithmetic is the \
     part that goes wrong.
  7. Last, the creative pass: what a person finds and smiles at (THE \
     CREATIVE PASS, below).

Then lay it out layer by layer from the ground up.

SAY THE SHAPE, DO NOT COUNT IT OUT
Writing placements one at a time is the part of this you are worst at, \
and most of a model is repetition. The patterns below are for masses — a \
hull, a body, a building, a wall, a rock. A figure, a creature or a \
character is not one: its head, body and limbs are a few shaped parts \
each, on joints (read_guide "figures"), and said as a pattern it is a \
statue of stacked bricks. Three patterns do the counting, alongside the \
bricks you write by hand:

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

             a dome          ellipse, layers 8, shrink 2 (stepped;
                             smooth and 16 across is four 87375s:
                             show_technique "smooth dome")
             a cone          ellipse, layers 10, shrink 4
             a round tube    the round pattern (below), not a fill
             a hull          rectangle, layers 6, rise 3, shrink 0
             a bowl          ellipse, wall 2, layers 6, shrink -2
             a wall          rectangle, wall 1, layers 12, rise 3
             a stone wall    the same, mix_color 72, masonry 0.5,
                             sideways 0.15
             a room          rectangle, wall 1, layers 4, rise 3
             what is in it   add_rooms once it stands, where= its box,
                             floors= [{"room": "hall"}, {"room":
                             "bedchamber"}]

           Rock is its own pattern, because stepped plates centred on \
           each other are a wedding cake, never a crag: \
           {"pattern": "rock", "at": {...}, "across": 16, "deep": 12, \
           "height": 15, "seed": 3}. The courses step in unevenly and \
           lean to one side, every edge gets a slope, a cheese slope, a \
           pebble or a bare ledge, in two greys (72 and 71 unless \
           said). Several rocks with different seeds, overlapping, make \
           a base nobody would take for a pattern; then build on it.

           A face built on its side is the other: \
           {"pattern": "studs_out", "at": {...}, "length": 8, "courses": \
           4, "facing": "+z", "color": 0}. Courses of \
           1x1 bricks with a stud on one side, tied by plates, and on \
           every side stud a tile, a round tile, a round plate or a \
           cheese slope, so the face is texture rather than studs. Real \
           fantasy sets build about a fifth of their parts on their side \
           and every design here built none, because where a side stud \
           sits is arithmetic nobody gets right by hand; this does it. \
           Put it where a face should read as dressed stone, panelling or \
           machinery, at the bottom of a wall course so it stands on it.

           And a tower that is not square is one object too: \
           {"pattern": "prism", "at": {"x": 24, "y": 0, "z": 24}, \
           "sides": 8, "radius": 7, "color": 0, "piers": \
           {"count": 4}, "storeys": {"count": 3, "in": 1}, "plinth": \
           {"steps": 2, "out": 2}} is \
           an eight-sided core with four faceted piers clustered round \
           it and deep clefts between them, in three storeys, each a \
           stud in from the one below on a ledge of dark bluish grey, \
           the top one's piers rising past its summit into horns, closed \
           all round, one mass of black stone from any side, standing on \
           a plinth of two terraces \
           with a stair up the front to its door — Orthanc, a keep with \
           corner towers, anything clustered. With no "courses" it is \
           laid at a display model's proportions, 3.3 times as tall as \
           its base is wide, horns and all (set 10237 is 21 cm \
           across and 73 cm tall), and the reply says how many; a run \
           that chose its own stood a thin tower on a base twice its \
           width, and its check says when the courses given are far \
           from that. "plinth" is the base: \
           every Orthanc built without it stood on a ring of rubble, a \
           base as an afterthought; the reply says where the tower's \
           foot then is. Its terraces carry crags rising against the \
           tower at their corners and sides, in its dark tones \
           ("rock": false for none): that is the rocky base, close to \
           the foot. A wide flat yard round a tall model, pale above \
           all, is no display base and makes the whole squat. A dark \
           face is textured in ribs and bands, never sprinkled: the \
           prism lays a column of round plates up the middle of each \
           face and grille bricks in bands. Each \
           face is a bonded wall in a section of its own, turned to its \
           angle. One run built octagonal piers by hand from 150 turned \
           sections, reached the real-set share of parts at an angle and \
           spent itself doing it; another built them square and had \
           none; this is that, in one line. "piers" also takes sides, \
           radius and out (how far from the middle each stands). \
           "storeys" is the silhouette: every Orthanc built without it \
           rose the same width from foot to horns, a shaft with a top \
           stuck on. The top is capped with a summit two plates thick, \
           which ties it all together; the reply says at what y (without \
           storeys, y + 3 x courses), so build on it two plates higher. \
           Each horn is a blade, as set 10237 builds Orthanc's: \
           plates on their side pressed onto bricks with side studs on \
           the summit, edges cut by wedge plates, sweeping out from its \
           pier and back in to a point, so they open round the platform \
           like claws; the reply says how tall and where the tips are. \
           "horns": "spire" steps a square crown in to a point instead, \
           "flat" caps a turret; "flare" is how far a blade sweeps out. \
           A blade is any spiked crown's: a throne's back, a gate's \
           fangs, a dark tower's points. With \
           piers, any "open" opens the core's whole back, its rooms on \
           show from behind between the back piers, which stay closed so \
           no sky shows up the clefts beside them. An arched \
           door stands at the foot of the core's front (+z), at y, for a \
           stair to lead up to ("door": false for none). Without "piers" \
           a prism is one shaft with a groove up each corner, and \
           "storeys" steps it in the same way. Its faces come dressed as a \
           finished wall's are — a quarter worked stone, some bricks \
           turned out with things on their side (the finishing pass cannot \
           reach them once the faces are turned); "masonry" and \
           "sideways" set how much, 0 for a plain face; a black face \
           takes a course of dark bluish grey every eight, a string \
           course ("band_color" for another), and grille bricks among \
           its masonry. "windows": true puts a few narrow dark slits up \
           every other face ("window_color" for another; lit yellow in \
           rows makes any tower an office block). Once it stands, \
           add_rooms with "prism": the same at and sides, the top \
           storey's radius (the reply says it; without storeys, the \
           radius), and \
           "floors": [{"room": "dungeon"}, {"room": "forge", "stair": \
           true}, {"room": "library"}, {"room": "study"}] lays a floor at \
           each storey and furnishes each room, in one call.

           A body that is not a box is one object too, said as the \
           solids it is: {"pattern": "shape", "at": {"x": 0, "y": 0, \
           "z": 0}, "color": 4, "solids": [{"extrude": {"along": "x", \
           "width": 8, "round": 1.5, "profile": [[0, 7], [3, 9], [8, 10], [20, 10], [21, 9]], \
           "under": [[0, 2], [21, 2]]}}, {"extrude": {"along": "x", "from": \
           1, "width": 6, "round": 1, "profile": [[8, 10], [11, 18], [13, \
           18], [20, 11]], "screen": true}}], "wheels": [4, 16]} is a Speed \
           Champions car on its wheels: its side profile pulled across \
           eight studs with its shoulders rounded and two plates of ground \
           under it; its cabin its own side profile on it, six studs wide, \
           the front climbing from the bonnet to the roof as glass — \
           "screen" lays a windscreen at that rake, standing on the \
           bonnet's plates, the roof on its top studs — and the roof \
           falling from there to the tail in curved slopes, a fastback, the \
           cabin behind the windscreen glazed in its glass for the side \
           windows; and at x 4 and 16 \
           an axle each — wheels and tyres, a Technic axle through Technic \
           bricks, the body cut clear of each wheel's box and standing on \
           the bricks, and a chassis of plates under them from nose to \
           tail holding the nose and tail — so it is one piece on its \
           wheels. If a shape cannot hold a part of itself, or stands on \
           nothing, its reply says where and what to change. \
           Never raise a shape over nothing to make room for wheels you \
           add later: it floats, and a round arch cut leaves a tyre's \
           corners in the body. It is \
           laid as a builder lays one: bricks and plates inside; on the \
           surface, wherever it falls from one stud to the next, the \
           slope or curved slope whose fall is nearest; inverted slopes \
           under an overhang; wedge plates where an edge runs on the \
           diagonal; tiles on top; its straight sides tiles laid flat on \
           bricks with side studs; one half and its mirror, tied across \
           the middle. A hull is a loft with "keel" narrowing its lower \
           half and a box cut off its top for the deck; a fuselage a \
           revolve along x; a display animal's big body (an owl twenty \
           studs tall) ellipsoids and a loft for its tail, its head and \
           limbs shaped parts (read_guide "figures"); "bands" colour it \
           by height (a waterline, a \
           belly), and a solid's own "color" a part of it (a canopy). The \
           car that was told every check to use wedge plates and curved \
           slopes and used none of them would have had both from this. \
           A cabin, a cab or a cockpit is its own side profile on the \
           body, never a loft with a flat top (a box with glass stood up \
           on it): "screen": true on that solid, or {"from": 8, "to": 11, \
           "color": 47} naming the stretch along it and the glass, lays a \
           windscreen (92583 or 4176 six studs across, 3823 or 57783 four) \
           where its front climbs 6 to 8 plates over 2 or 3 studs to the \
           roof, the roof two plates over its top row; behind it let the \
           roof fall to the tail, and the reply says what it laid or why \
           none fits. A truck's cab climbs steeply over 2 studs, an \
           aircraft's cockpit where the nose climbs to the fuselage. \
           A big head's face (ten studs across or more) is said on it: \
           "face": {"facing": "+z", "x": 10, \
           "y": 53, "z": 11, "across": 6, "color": 15, "rim": 84, "eyes": \
           0, "beak": 19} leaves a square of 6 out of the curved side \
           there, on the side-stud bricks behind it lays a plate to bring \
           it out to the curve and a 6 x 6 round plate as the disc, and on \
           the disc two 2 x 2 round eyes with printed eye tiles and a beak \
           on a jumper — the face a set builds onto a head, which a panel \
           of tiles on a shell cannot take (across 4, 6 or 8; x, y, z its \
           middle, on the side that curves out; "beak": -1 for none).

           Anything round in section is one object too, upright or \
           lying down: {"pattern": "round", "at": {"x": 10, "y": 0, \
           "z": 10}, "diameter": 4, "color": 15, "stack": [{"cones": 9, \
           "color": 0}, {"technic": true, "struts": 2, "color": 0}, \
           {"plates": 60}, {"plates": 9, "color": 0, "spokes": 4}, \
           {"diameter": 6, "plates": 18}, {"nose": "ogive"}]}. It lays \
           the round parts real sets lay at each diameter — 1 and 2 \
           studs round bricks; 4, a round brick or two cylinder halves \
           back to back; 6 and 8, four corner rounds tied by a round \
           plate — so the surface is a true circle, not a staircase of \
           bricks. Up the stack go bands of colour, a wider or narrower \
           length, cones under a round plate, a Technic course with \
           beams pinned on, a plate whose spokes carry tiles out past \
           the round, and a nose (cone, ogive, dome, point, flat). \
           "axis": "x" lays the same stack along x; "beside" stands two \
           or four more round it, pinned to it. A rocket stage and its \
           boosters, a lighthouse with its gallery, a silo, a column, a \
           chimney, a locomotive's boiler, a fuselage, a submarine, a \
           tree trunk: every one of these built square here read as a \
           pile of bricks, and real sets never build round square.

           Say it that way. A dome written out by hand is three hundred \
           plates, and the ones that go wrong are the ones nobody can \
           check.
           A round *tower* in a fill is the trap: an ellipse with a wall \
           has no room for a long brick in any run once it curves, so a \
           small one comes out as a staircase of 1x1 bricks — measured \
           on a castle, 354 of them, four towers' worth. A round tower \
           is the round pattern, diameter 8 or less; wider than that, \
           a prism of many sides. But round is a choice: 15 of 54 castle \
           sets since 2010 use the 4x4 corner round at all, none more \
           than eight, and every castle built here had two hundred.
           Walls especially. Measured: a curtain wall 40 by 24 studs and \
           twelve courses high is 408 parts out of fill — 1x4 bricks \
           in a running bond, 1x3, 1x2 and 1x1 at the ends, and not one \
           joint over a joint in the course below. Those are the sizes \
           a real set lays a wall in; every castle that fill built in \
           1x8s and 2x10s was coarser than all but one real set in \
           twenty, and its walls were slabs nothing could happen in. A \
           castle run that wrote its walls out by hand instead used two \
           hundred and twenty-three 1x2 bricks with every joint in a \
           column, which is a wall of separate towers. If a surface is \
           a rectangle or a ring, fill it, and make some of its short \
           bricks something else: mix_color puts a second colour \
           through them and masonry lays some as stonework, in the same \
           object. A real castle's walls are 9-19% their second grey; \
           Lion Knights' Castle has 281 of the 1x2 masonry brick.

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
have a picture in mind — the picture is what you remember of LEGO® sets, and \
this is what the sets did.
  how_real_sets_build_this asks the same question about anything else: \
a part of the model that is its own kind of thing, or a subject the \
brief did not name in plain words.
  find_techniques goes one step further: it finds the actual pieces \
real sets built a thing with (a wheel arch, a beak, a turret roof), \
each with its set, author and size, and place_technique lays one into \
the model as built, turned and moved where it goes.

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
— is hundreds to thousands of parts. A real LEGO® set of any ambition is \
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

Choose what it stands on (submit_design's floor). A vehicle, a ship, a \
figure or a creature has no plate in its box: floor "none". A scene, a \
diorama or a building on its lot comes on a baseplate: floor "baseplate" \
in the colour of its ground, and that plate is part of the build. A figure \
or two with what the brief stands them on is not a scene: floor "none", \
and the base the brief names (a log, a stool, a stretch of floor, a small \
base) built a stud or two past their footprint.

WHAT MAKES A MODEL BEAUTIFUL
Holding together and reading as the thing are the floor, not the goal. \
What makes a person stop and look is craft, and it can be learned:
  Not everything is studs-up. Real sets turn a good share of their parts \
on their sides and upside down — brackets, bricks with studs on the \
side, headlight bricks — to lay tiles, grilles and slopes across a \
face, and that is where most of a wall's detail comes from \
(show_technique "face turned sideways").
  Not everything is square. A wall that bends, a roof pitched where no \
slope is, a rock face, a horn, a buttress leaning in: hinges, clips on \
bars, and sections turned to the angle the thing really has \
(show_technique "rock outcrop" for a rock face).
  Symmetry is a choice, not a default. A vehicle or a formal front is \
mirrored; rock, ruins, trees, a tower grown out of a crag, a wall that \
has been fought over are not, and built mirrored they look \
manufactured. Where the subject is irregular, make the irregularity \
large and deliberate — a shoulder higher on one side, a spur, a \
fissure, a change of texture — rather than a brick out of place.
  Use a part for what it looks like, not what it is for. Builders call it \
nice part usage and it is the mark of a good model: claws and horns for \
spikes and thorns, tooth plates for battlements, ingots and cheese \
slopes for dressed stone, 1x1 round plates for rivets, a bar for a \
spire, a leaf for a flame. One unexpected part, well placed, does more \
than a hundred plain bricks.
  Texture changes where the material changes. Tiles for dressed stone or \
metal, studs left showing for rough ground, masonry bricks and grilles \
for worked stone, two or three close colours — black, dark bluish grey, \
dark grey — mixed for weathering. One grey over everything reads as \
plastic (show_technique "rough stone wall", "weathered stone wall").
  Depth makes the detail. A face on one plane is flat, however much is on \
it. Set windows in, let a cornice oversail, recess a doorway a plate, \
stand a buttress out: the shadows are what the eye reads \
(show_technique "oversail on inverted slopes", "corbelled wall walk").
  The profile is the design. A tall subject the same width all the way \
up is a shaft, whatever is on it: taper it, flare its foot, gather it at \
a waist, facet its edges, and let its top grow out of the body rather \
than sit on it with spikes stuck on. A prism's "storeys" steps a tower in \
on ledges in one call; a round's stack takes a smaller diameter; a stack \
of either, each a little smaller, says a taper in plain calls.
  Dark is not one colour. A big face of black or dark brown with nothing \
on it photographs as a hole. The Tower of Orthanc set (10237) is 66% \
black and breaks it with 86 grille bricks, 63 headlight bricks, 58 \
bricks with a handle, 47 cheese slopes, 36 curved ribs and 13% dark \
bluish grey on its ledges: texture in the same colour, a second tone in \
bands rather than sprinkled (scattered, it reads as noise), depth. \
restyle_model lays it on what stands, wall by wall, in one call: on a dark \
wall panels of grille between ribs of round plates unasked, or the \
"style" said (ribs, bands, grid, recessed courses). Dressing placed a \
part at a time over a dark wall is refused.
  Windows have reasons. A few, varied, framed, where something happens \
inside — never a grid of identical lit squares, which makes a fortress an \
office block. Their colour comes from the subject: dark slits for a dark \
tower, a lit lantern for a lighthouse.
  The base leads the eye up: a plinth, steps, a terrace, ground that \
rises to the door — composed, not rubble ringed round the foot.
  A focal point. Somewhere the eye goes first — the top of a tower, a \
gate, a figure on a balcony — gets the most interesting parts in the \
model.
  Inside. A building in a real set is open at the back, with floors and \
rooms: a library, a stair, a throne, a forge, a figure at a table. That \
is where most of a set's different pieces and colours are — furniture, \
books, lamps, tools — and a solid shell has none of them. Leave the back \
open (a prism takes "open"; a house leaves its back wall out), and then \
add_rooms lays the floors and furnishes every room, one call for the lot, \
from the furniture real sets built (show_technique: bookcase, fireplace, \
anvil, four-poster bed, wall lantern, and the rest of furniture and \
interiors).

WHAT THE SUBJECT NEEDS
An expert reads a subject as shapes, and each shape has its technique. \
Reach for these by yourself; nobody will ask for them by name:
  Round in section — a rocket stage, a lighthouse, a silo, a boiler, a \
fuselage, a funnel, a tree trunk, a column: the round pattern, upright \
or lying along x or z. Never square bricks stacked into a round: that \
is the one way a real set never builds it.
  Tapered or domed — a nose, a spire, a dome, a cone: the round \
pattern's nose; a fill with layers and a shrink; cones and dishes. A \
smooth dome 16 studs across, glass or solid (an observatory, a greenhouse, \
a habitat, a planetarium): four 87375 quarter domes on a ring of four \
58846 tapered corners, each quarter held by the bar of its bottom handle in \
two 61252 clips and its top handle in a 61252 clip on a 2 x 2 round \
plate inside the crown, a 2 x 2 round tile on those clips closing it — \
show_technique "smooth dome". A handle is a bar: \
attachment_points lists it, and a quarter goes on its clips by axis and \
joint at the clips' line. A dome or a ball of any other size up to 32 \
across: one shell of hinged panels (read_guide "round").
  A figure, a creature, a character — anything with a head, limbs and a \
pose: sub-assemblies of shaped parts on joints, never one pattern \
(read_guide "figures"); a minifigure where it is minifigure-sized.
  A body that is not a box — a car's body, a hull, a fuselage, a big \
display animal's body: the shape pattern, said as its solids (a loft \
through sections, a profile extruded, a revolve, ellipsoids), which \
lays its slopes, curved slopes, wedges and tiles for you, a round \
section in round parts, and a side that curves up and down turned out \
on side studs, so its outside is smooth parts and not a staircase. \
Where a body curves two ways at once — a sports car's wings and roof, a \
creature's back and flanks — its plates step however fine: skin it as \
real sets do, curved slopes built flat in sections stood out on side \
studs over the shape's core (sideways skins), panels on hinges where it \
is a dome (read_guide "round"). \
Shapes stack: a cabin said as a shape on a body keeps the body's studs \
under it. When a shape comes back in pieces or floating, the check \
names the parts: fix what it stands on or the cut that splits it, and \
keep the body — rebuilt by hand, its curves are lost.
  A cabin or a canopy — a car's, a truck's or a train's cab, a \
cockpit: its own side profile on the body, "screen": true where its \
front climbs to the roof, so a windscreen is laid at that rake with the \
roof on its top studs, and the roof falling behind it to the tail in \
curved slopes; inverted slopes under anything that overhangs (read_guide \
"shapes", show_technique "raked screen and falling roof"). A loft with a \
flat top is a box with glass stood upright on it.
  Parts that roll apart — a tender, a trailer, a carriage, a wagon: \
coupled to what pulls them, never butted against it — a towball in a \
socket, magnet couplers touching, or a Technic liftarm pinned into \
both (show_technique "towball hitch", "magnet coupling"). \
A rocket's stages stand on each other's studs, or on a Technic axle \
through both.
  Edges at a slant — a swept wing, a car's shoulder, a bow: wedge \
plates (show_technique "smooth diagonal"). A curved surface — a \
bonnet, a hull's bilge, a cab roof: curved slopes, studs-up or on \
their side on brackets.
  Smooth — a car's flank, a hull's side, a sign: studs_out, tiles \
over every stud that shows.
  At an angle, or moving — a raked mast, a windscreen, a wing, a door, \
a hatch, a ramp, a jaw, a leg: a section, on a hinge (hinge: true) \
when it leans. A part that opens or turns is also a play feature, and \
real sets have them.
  Mechanical — legs, arms, a crane jib, a frame, struts: Technic beams \
pinned to Technic bricks (a round's "technic" course pins beams on in \
one line); grille tiles, round plates, levers and pipes for machinery.
  Organic — rock, a tree: the rock pattern; curved slopes and wedges for \
a body; hinged sections for wings and limbs.
  A face — an animal's, a figure's, a robot's, a vehicle's front: \
features, each a part a designer chose, not a panel. Eyes are round \
plates with a printed pupil and its highlight (show_technique "eye with \
a highlight"); a face that is round is a round plate with the eyes and \
the beak on it ("round face"); a beak or a snout, a cheese slope on a \
jumper ("beak or snout"); ears and tufts, slopes at the head's corners \
("ears or tufts"); feet, claws ("talons"); a vehicle's face, its lamps \
and grille ("headlamps and grille"). A grid of 1 x 1 tiles with a dot \
for each eye is a pixel picture, not a face. The face is where a person \
looks first, so it gets the model's best parts.
  Rough or worn — stone, a hull's planking, weathering: two or three \
close colours mixed (mix_color), masonry, texture parts.
  A band of detail — rivets down a hull plate, a row of portholes or \
lights, a smooth panel, vents: studs_out with "dress": "rivets", \
"round", "lights" (in a transparent face_color) or "tiles"; grille \
tiles in a row (show_technique "grille band"). Stripes and colour \
blocks are a band of another colour in the round pattern, an \
edge_color or mix_color on a fill, or a course in a second colour.
  Several of anything — boosters on a core, funnels, columns, wheels: \
one built well and the pattern saying the rest (beside, repeat, \
mirror, repeat_section).

THE SURFACE PASS
A real set leaves studs only where something is built on them: a roof, \
a bonnet, a wing top and the top of a wall are tiled, and a slope or a \
curve follows a line that would otherwise step. Once the model stands and \
its assemblies have had their turns, the app reads its open studs, its \
tops, the way they step and where they end, and its plain walls exactly, \
and lays the real pieces for each as a proposal on the model (from outside, \
review_model {"surface": true}): tiles in the part's own colour, largest \
first, with a textured one or two; slopes on a staircase's treads, studded \
or tiled, or a step brick laid again as a slope; over steps a plate high, a \
curved slope two plates tall on each pair of them; curved slopes along a \
body's hard top edge, flush with its top; on a body's flank of plain \
bricks, a skin on its side (studs turned out of a course, plates and tiles \
on them, curved slopes at its ends); masonry in a building's long plain \
wall. Every finding is laid at once. Settle each with \
settle_surface: accept it (adjusted: "plain", "recolor"); reject it with a \
reason, to finish it your own way; or keep the studs with a reason where \
they are the point — a yard figures stand on, a mosaic, a studded texture, \
where a touch will stand. The ground is offered, never laid unless you say \
"tile".

THE CREATIVE PASS
A designer adds things nobody asked for, and they are what a person \
finds and smiles at. Of 2,517 real sets of 300 parts or more since \
2015, 95% carry a printed or stickered part and 94% a hinge, a \
turntable, a Technic pin or a ball joint; 1.6% have none of these. \
Once the model stands and its features have had their turns, the \
creative pass comes back to you on its own (from outside, review_model \
{"creative": true}): propose three touches for this subject, each of a \
different kind, and add the best one or two — small, joined to the \
model, where they are seen from the front or the corner. The kinds:
  A story: who flies it, keeps it, works it, hunts from it, doing what \
the subject is for — a figure with its tool, its catch, its load — or a \
small scene, or one hidden somewhere a person will find it \
(add_minifig). A figure standing about is not yet a story.
  Something that moves, shown working: a hatch raised, a door ajar, a \
ramp down, a turret or a jib on a turntable, a hook on its line — a \
section on a hinge or a turntable.
  A display stand with a nameplate, for a display model: a black base, \
a plaque on it, the model held up the way it is shown. The plaque is \
printed (a printed tile or slope that names the subject or its story); \
a blank one reads as unfinished. Joined to the model — or, where it \
stands apart (a plaque in front of a car), named as an assembly of its \
own: a piece apart that nothing names is a part that has come off, and \
fails.
  A nod to the subject's story: a detail only someone who knows it \
would catch — a mission patch, a launch date, a famous passenger, the \
ship's cat, what the LEGO® set of it is loved for — on a printed part \
(search_parts with "print" and the subject's own word: there are \
printed parts for a great many real things), or a part used for what it \
looks like.
  Never at the cost of what it is: a touch that covers what the subject \
is known by, changes its silhouette or loosens its build is not one.
  And never beside what was asked, where the brief says what is in the \
scene — who is there, what they hold, what they stand on. Then the brief \
is the scope: the touches go on those things (a printed part, a pose, \
something that moves, the detail it names done better), and a figure, a \
creature, a plant or a prop it did not name is clutter. A brief that names \
only its subject (a castle, a ship) leaves room for a story.

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
edit away.""".replace("{HINGE LINES}", _hinge_lines()).replace("{HINGE NEXT}",
		_hinge_next())


## What is turned on which hinge, in a line or two: how many sections on
## each kind, one of them as it was said, and where the base of a section
## hinged within one goes. Said in the check's answer, because a session
## acts on what a tool tells it and reads the guide once.
func _hinges_said(model: Model) -> String:
	var kinds: Dictionary = {}    ## kind -> [count, one section]
	for section: Section in model.sections.values():
		if not section.hinge:
			continue
		if not kinds.has(section.hinge_kind):
			kinds[section.hinge_kind] = [0, section]
		kinds[section.hinge_kind][0] = int(kinds[section.hinge_kind][0]) + 1
	if kinds.is_empty():
		return ""
	var said := PackedStringArray()
	for kind: String in kinds:
		var one: Section = kinds[kind][1]
		var step: Vector3 = _hinge_step(kind)
		said.append("%d section%s on %s hinges, '%s' %s%s" % [int(kinds[kind][0]),
			"" if int(kinds[kind][0]) == 1 else "s", kind, one.name, one.said(),
			"" if step == Vector3.INF else "; one hinged within one L studs long "
				+ "stands its base at %s" % _step_said(step)])
	return "Hinged: " + "; ".join(said) + "."


## Where a hinged section's joint line is in its own coordinates, and where
## the base of one hinged within it L studs on goes, for each kind of hinge
## this build lays in line: worked out from the parts, so the numbers a
## chain of panels needs are never a guess written down here.
func _hinge_lines() -> String:
	if library == null or builder == null:
		return ""
	var said := PackedStringArray()
	for kind: String in [Hinges.CLIP, Hinges.CLICK]:
		var next: Vector3 = _hinge_step(kind)
		if next == Vector3.INF:
			continue
		var fit := Section.from_dict({"name": "fit", "hinge": kind, "pitch": 1})
		_fit_hinge(fit)
		var line: Vector3 = -fit.origin_from_pin
		said.append(("On a %s hinge the line is at the section's own y=%s, z=%s, and a "
			% [kind, Placement._num(snappedf(line.y / PLATE, 0.05)),
				Placement._num(snappedf(line.z / STUD, 0.05))])
			+ "section hinged within it L studs on stands its base at %s." % _step_said(next))
	return " ".join(said)


## Where the next panel's base goes, for the kind a dome is best hung on.
func _hinge_next() -> String:
	for kind: String in [Hinges.CLICK, Hinges.CLIP]:
		var next: Vector3 = _hinge_step(kind)
		if next != Vector3.INF:
			return "on a %s hinge, %s" % [kind, _step_said(next)]
	return "where its hinge's base stands on it"


## The base of a section hinged within one of [param kind], from the parent's
## origin, less L studs along z, in studs and plates; INF where the kind
## cannot be laid here.
func _hinge_step(kind: String) -> Vector3:
	if library == null or builder == null or not Hinges.available(kind, library):
		return Vector3.INF
	var fit := Section.from_dict({"name": "fit", "hinge": kind, "pitch": 1})
	_fit_hinge(fit)
	if not fit.hinge:
		return Vector3.INF
	var next: Vector3 = -fit.origin_from_pin - fit.pin_from_corner
	return Vector3(next.x / STUD, next.y / PLATE, next.z / STUD)


static func _step_said(next: Vector3) -> String:
	var along: float = snappedf(next.z, 0.05)
	return "x=%s, y=%s, z=L%s" % [Placement._num(snappedf(next.x, 0.05)),
		Placement._num(snappedf(next.y, 0.05)),
		"" if is_zero_approx(along) else ("%+.2f" % along).trim_suffix("0").trim_suffix(".0")]


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
##
## Headed by GUIDE_HEAD, because Claude Code cuts a server's instructions
## off at about 3,800 characters: asked what it was given, a session quoted
## LEGO ART, COORDINATES, SIDEWAYS and half of BUILDING WITH PINS AND AXLES,
## and "… [truncated]". HOW TO WORK starts at character 12,868 of 54,090, so
## no session from outside — the bench's, a person's My Claude — had ever
## read how to work, the rules, the shapes or what a subject needs. The head
## says the process and where the rest is; read_guide serves any section.
##
## And ends with the rest of the app (AppTools.GUIDE): the floor, the build
## steps, hoses, posing, undo, rendering and exporting, which a session has
## and the design loop does not.
func guidance() -> String:
	return GUIDE_HEAD + "\n\n" + _guide_text()


## What read_guide serves sections of: the design loop's own guidance, and
## the rest of the app's tools.
func _guide_text() -> String:
	return _system_prompt() + "\n\n" + AppTools.GUIDE


## What a session reads first, inside the 3,800 characters that reach it.
const GUIDE_HEAD := """You design LEGO® models with this app's tools: it builds \
what you submit, checks that it holds together, and refuses what does not. \
Only the start of these instructions may reach you: read_guide gives any \
section of the rest in full.

HOW TO WORK — the way a set is designed:
 1. plan_scale with the real thing's length; find_reference for anything \
that exists; how_real_sets_build_this with the subject: real sets' parts, \
and the faults the judge found in our own designs of it, to design out.
 2. The silhouette: the main masses, sized in studs off the picture and \
the brief. A hull, a car body, a fuselage or a building is a shape pattern \
(read_guide "shapes"); a figure, a creature, a character or anything \
small is shaped parts on joints (the figure pattern, attach; read_guide "figures"). \
submit_design that first, with its assemblies and features — what the \
subject is known by (an owl's eyes; a car's wheel arches, grille), each \
with where it goes (x, y, z, facing).
 3. review_model: the silhouette and proportions against real sets. Fix \
the masses before any detail.
 4. Each feature in turn: the app lays the best real set's piece where it \
goes; settle_feature accepts it, asks for the next, rejects it with a \
reason, or says you built it. A feature is parts with depth, never a \
painted tile.
 5. Each assembly in turn: review_model {"assembly": name}, detailed with \
edit_model.
 6. The surface pass: review_model {"surface": true} — the app tiles open \
studs, slopes staircases, rounds hard edges, skins flanks and textures \
walls; settle each with settle_surface (accept, reject or keep).
 7. Last, the creative pass: review_model {"creative": true} — three \
touches, the best one or two added; where the brief lists the scene, on \
what it names. Then save_model.

THE RULES: nothing overlaps; nothing floats (every part on the ground or \
on a part under it); the model is one connected thing — parts side by side \
are not joined, only stacking joins, so stagger the joints.

A MECHANISM (gears, axles, a crank, a turntable): read_guide "pins" \
first. Put a pin, an axle, a gear or a bush by its line, axis "z" and \
the x, y, z attachment_points gives the hole, never by its corner. Gears \
mesh 1.25 LDU a tooth apart: an 8 and a 24, 2 studs. A ratio no two gears \
give: search_gear_ratio.

A CURVED SURFACE (a dome, a sphere, a round body): read_guide "round" \
first: hinged panels turned by yaw and pitch, or skins built sideways — \
never plates stepped in.

ASKED ABOUT A SELECTION (parts the person selected): selection, then \
where_to_attach (with part=, placements that fit as they are), then \
edit_selection; never submit_design.

SKETCH FIRST, when asked: submit_design with "sketch": true three times \
(each a different idea, under 150 parts), then choose_sketch one and design \
from it.

read_guide sections: "work", "rules", "shapes" (repeat, mirror, fill, rock, \
studs_out, prism, round, and shape with its face), "figures", "subject" \
(what each kind of subject needs), "real", "colour", "angle", "round", \
"coordinates", "sideways", "pins", "big", "look", "good", "beautiful", \
"creative", "changing", "kind", "art", and "app" (everything else the \
person can do from the menus, as tools).

A call answered with a job number is still working in the app: call job \
about every 10 s until it gives the answer."""


## The section on figures and creatures, which the head sends a session to.
const FIGURES := "FIGURES, CREATURES AND SMALL MODELS"

## Names a session may ask read_guide for, beside the headings' own words.
const GUIDE_NAMES: Dictionary = {"work": "HOW TO WORK", "process": "HOW TO WORK",
	"rules": "THE RULES YOUR DESIGN MUST SATISFY", "shapes": "SAY THE SHAPE, DO NOT COUNT IT OUT",
	"patterns": "SAY THE SHAPE, DO NOT COUNT IT OUT", "shape": "SAY THE SHAPE, DO NOT COUNT IT OUT",
	"face": "SAY THE SHAPE, DO NOT COUNT IT OUT", "subject": "WHAT THE SUBJECT NEEDS",
	"figures": FIGURES, "figure": FIGURES, "character": FIGURES, "characters": FIGURES,
	"creature": FIGURES, "creatures": FIGURES, "animal": FIGURES, "small": FIGURES,
	"vignette": FIGURES, "scope": FIGURES,
	"cabin": "SAY THE SHAPE, DO NOT COUNT IT OUT", "canopy": "SAY THE SHAPE, DO NOT COUNT IT OUT",
	"screen": "SAY THE SHAPE, DO NOT COUNT IT OUT", "windscreen": "SAY THE SHAPE, DO NOT COUNT IT OUT",
	"coupling": "WHAT THE SUBJECT NEEDS", "couplings": "WHAT THE SUBJECT NEEDS",
	"angle": "AT AN ANGLE", "sections": "AT AN ANGLE", "hinge": "AT AN ANGLE",
	"round": "ROUND BODIES AND DOMES", "dome": "ROUND BODIES AND DOMES",
	"domes": "ROUND BODIES AND DOMES", "sphere": "ROUND BODIES AND DOMES",
	"curve": "ROUND BODIES AND DOMES", "curved": "ROUND BODIES AND DOMES",
	"hinged panels": "ROUND BODIES AND DOMES", "skins": "ROUND BODIES AND DOMES",
	"pins": "BUILDING WITH PINS AND AXLES", "technic": "BUILDING WITH PINS AND AXLES",
	"real": "WHAT MAKES A MODEL LOOK REAL", "touches": "THE CREATIVE PASS",
	"creative": "THE CREATIVE PASS", "surface": "THE SURFACE PASS", "studs": "THE SURFACE PASS",
	"changing": "CHANGING SOMETHING THAT IS ALREADY BUILT", "edit": "CHANGING SOMETHING THAT IS ALREADY BUILT",
	"kind": "HOW REAL SETS OF THIS KIND ARE BUILT", "module": "AND BEYOND THAT, A MODULE SAID AGAIN",
	"art": "BRICK ART", "mosaic": "BRICK ART",
	"app": "THE REST OF THE APP", "menus": "THE REST OF THE APP", "floor": "THE REST OF THE APP",
	"steps": "THE REST OF THE APP", "hose": "THE REST OF THE APP", "pose": "THE REST OF THE APP",
	"render": "THE REST OF THE APP", "export": "THE REST OF THE APP", "undo": "THE REST OF THE APP",
	"job": "THE REST OF THE APP", "jobs": "THE REST OF THE APP"}


## One section of the guidance by its name or a word of its heading: the
## heading's text to the next heading. The headings, if none matches.
func read_guide(section: String) -> String:
	var text: String = _guide_text()
	var headings: Array[String] = []
	var at: Array[int] = []
	var heading := RegEx.create_from_string("(?m)^[A-Z][A-Z ,'-]{4,}$")
	for found: RegExMatch in heading.search_all(text):
		headings.append(found.get_string())
		at.append(found.get_start())
	var asked: String = section.strip_edges().to_lower()
	var wanted: String = str(GUIDE_NAMES.get(asked, ""))
	if wanted.is_empty():
		for name: String in headings:
			if name.to_lower().contains(asked) and not asked.is_empty():
				wanted = name
				break
	var n: int = headings.find(wanted)
	if n < 0:
		return ("No section called \"%s\". There is: %s." % [section,
			", ".join(PackedStringArray(GUIDE_NAMES.keys()))]
			+ " Or a heading: %s." % ", ".join(PackedStringArray(headings)))
	var end: int = at[n + 1] if n + 1 < at.size() else text.length()
	return text.substr(at[n], end - at[n]).strip_edges()


## The guide's shapes section, led for a figure, a creature or a character by
## what it is built of instead. Eight of the attach round's ten guide reads
## were "shapes", every character session that read it submitted a shape on
## its next call, and the figure line at its top was one sentence of 16,000
## characters.
func _for_the_subject(section: String, text: String) -> String:
	if str(GUIDE_NAMES.get(section.strip_edges().to_lower(), "")) != "SAY THE SHAPE, DO NOT COUNT IT OUT":
		return text
	if Style.character_of(_subject_of()).is_empty():
		return text
	return ("This subject is a figure, a creature or a character, which is not a shape: "
		+ "a shape or a fill of one is a statue of stacked bricks, and every one built here "
		+ "was judged so. Its pattern is the figure pattern, which lays it on joints in one "
		+ "entry: {\"pattern\": \"figure\", \"kind\": \"person\" (or \"animal\", \"head\"), "
		+ "\"at\": {\"x\", \"y\", \"z\"}, \"height\": plates (an animal's \"length\": studs), "
		+ "\"color\", \"colors\": {\"skin\", \"legs\", \"hair\"}, \"pose\": {\"right arm\": "
		+ "\"down\", \"left arm\": \"raised\", \"head\": 20, \"seated\": true}}, every part "
		+ "named for your own to attach to (read_guide \"figures\"). Single joints are "
		+ "place_technique calls: \"head on a neck\", \"limb on a clip\", \"ball shoulder\", "
		+ "\"tail on a bar\", \"hinged wing\". The patterns below are for what it stands on, "
		+ "and for a body that is a hull, a whale's.\n\n" + text)


## How a construction is actually made, in parts and coordinates.
##
## Being told to stagger a wall or turn a face sideways is not the same
## as knowing where a bracket's side stud sits, and that stud is not at a
## whole number of plates. A design that has to work it out gets it wrong
## twice and goes back to stacking bricks studs-up, which is the shape
## everything it builds then has.
func _show_technique(wanted: String) -> String:
	if wanted.strip_edges().is_empty():
		return ("Name one of these, by what it is for — %s." % Techniques.listing())
	var technique: Dictionary = Techniques.named(wanted)
	if technique.is_empty():
		return ("No technique called \"%s\". There is, by what it is for — %s."
			% [wanted, Techniques.listing()])

	var rows := PackedStringArray()
	# An angled one is a section, said first so the bricks that name it
	# read as being in it.
	for raw: Variant in technique.get("sections", []):
		var section: Dictionary = raw
		rows.append("  section \"%s\" at x=%s y=%s z=%s, %s" % [section["name"],
			Placement._num(float(section["x"])), Placement._num(float(section["y"])),
			Placement._num(float(section["z"])), Section.from_dict(section).said()])
	for raw: Variant in technique.get("repeat_section", []):
		var order: Dictionary = raw
		rows.append("  repeat_section %s" % JSON.stringify(order))
	var attached: bool = false
	for raw: Variant in technique["bricks"]:
		var brick: Dictionary = raw
		# One put on another by its connectors is said as it is written, to
		# copy: it has no corner of its own.
		if brick.has("attach"):
			attached = true
			rows.append("  " + JSON.stringify(brick))
			continue
		if brick.has("name"):
			rows.append("  " + JSON.stringify(brick))
			continue
		var face: String = str(brick.get("face", "up"))
		var inside: String = str(brick.get("section", ""))
		# A part put by its line: x, y and z are where that joint's middle
		# goes, and said as such.
		var line: String = "" if not brick.has("axis") \
			else " axis=%s joint=%d" % [brick["axis"], int(brick.get("joint", 0))]
		rows.append("  %-8s colour %-3s x=%-5s y=%-5s z=%-5s rot=%s%s%s%s" % [
			brick["part"], brick["color"],
			Placement._num(float(brick["x"])),
			Placement._num(float(brick["y"])),
			Placement._num(float(brick["z"])),
			brick.get("rot", 0),
			"" if face == "up" else " face=" + face,
			"" if inside.is_empty() else " section=" + inside, line])
	# A section's bricks are in its own coordinates and go where it goes.
	# Told only to add to x, y and z, a design would move them twice and
	# take a turntable's top off its base.
	var move: String = "Move it where you need it by adding to x, y and z"
	if not (technique.get("sections", []) as Array).is_empty():
		move += (" of the section and of the bricks outside it; the bricks "
			+ "in the section are in its own coordinates and move with it")
	if attached:
		move += (" of the parts that have them; each part with attach goes on the one it "
			+ "names, by those connectors, wherever that is, so it follows. Copy them as "
			+ "written, in order, each name once in a design; change a yaw or an align "
			+ "to pose it, or attach to your own part (a brick standing is \"#41.stud[3]\"; "
			+ "attachment_points lists every connector)")
	return ("%s — %s.\n\n%s\n\nBuilt like this, at the origin:\n%s\n\n"
		% [str(technique["name"]).capitalize(), technique["when"],
			technique["why"], "\n".join(rows)]
		+ move + ". Every one "
		+ "of these is checked against the same lattice your design is, "
		+ "so it holds together as it stands.")


## How real sets built a feature: the best few of the real-set index
## (src/ai/real_snippets.gd) for the words asked, each with its parts,
## size, credit and id, and one picture of them side by side.
##
## The worked examples behind show_technique are seventy-odd, chosen by
## hand. A designer asked for an owl's eye needs the eye a set built, not
## the nearest of seventy, and the repository has thousands of named
## sub-assemblies. Words find them; the picture says whether one is it.
## How many real pieces find_techniques answers with: three, each in two
## lines, and a picture of them 200 pixels a piece. Five with their whole
## parts lists and a picture 1,600 wide was a long read a run made once.
const FOUND := 3


func _find_techniques(query: String, max_studs: float, kinds: Array) -> Variant:
	# Fetched on the web the first time, from beside the build.
	if not await RealSnippets.ensure(self):
		return ("This build has no index of real sets' sub-assemblies "
			+ "(tools/snippets.py build). show_technique has the worked "
			+ "examples.")
	if query.strip_edges().is_empty():
		return "Say what you are building: \"owl eye\", \"car nose\", \"dragon wing\"."
	var found: Array = RealSnippets.search(query, max_studs, kinds, FOUND)
	if found.is_empty():
		return ("No real set has a piece called anything like \"%s\"%s. Try the "
			% [query, " that small" if max_studs > 0.0 else ""]
			+ "plain word for the feature (eye, beak, nose, wing, roof, "
			+ "grille, wheel arch), or the subject alone.")
	var rows := PackedStringArray()
	var shown: Array = []
	for n: int in found.size():
		var entry: Dictionary = found[n][1]
		shown.append(entry)
		rows.append(_piece_line(n + 1, entry))
	var said: String = ("How real sets built %s, best first:\n\n%s\n\n"
		% [query, "\n".join(rows)]
		+ "place_technique with an id lays one as built — turned, moved, and in "
		+ "your colours if you say which become which — and checks it like any "
		+ "edit. Parts do not scale: pick one the size your model needs, or "
		+ "build your own the way the picture shows.")
	var picture: Image = await _snippet_picture(shown)
	if picture == null:
		return said
	var encoded: PackedByteArray = picture.save_png_to_buffer()
	return [{"type": "text", "text": said + "\n\nThe picture shows them in that "
			+ "order, left to right."},
		{"type": "image", "source": {"type": "base64", "media_type": "image/png",
			"data": Marshalls.raw_to_base64(encoded)}}]


## Parts by what they read as: the families of tools/part_looks.py whose
## line, written by Claude, matches the words asked.
func _find_parts_like(query: String) -> String:
	if not await RealSnippets.ensure_looks(self):
		return "This build has no list of what parts look like (tools/part_looks.py)."
	var found: Array = RealSnippets.search_looks(query, 6)
	var printed: String = _printed_with(query)
	if found.is_empty():
		return ("No family of parts reads as \"%s\" in what is written about them. " % query
			+ "Try a plainer word for the look (claw, feather, scale, exhaust, eye), "
			+ "or search_parts for one you can name." + printed)
	var rows := PackedStringArray()
	for raw: Variant in found:
		var family: Dictionary = raw
		var parts := PackedStringArray()
		# Kept to a list (PartsOnly): only the family's parts on it.
		var listed: Array = (family["parts"] as Array).filter(func(pair: Variant) -> bool:
			return PartsOnly.allows(str((pair as Array)[0]), library))
		if listed.is_empty():
			continue
		for pair: Variant in listed.slice(0, 6):
			parts.append("%s %s" % [(pair as Array)[0], _part_called(str((pair as Array)[0]))])
		rows.append("%s — reads as: %s\n   %s" % [family["family"].replace("N x N", "n x n"),
			family["looks"], "; ".join(parts)])
	if rows.is_empty():
		return ("No family of parts among %s reads as \"%s\". " % [PartsOnly.named(), query]
			+ "Try a plainer word for the look, or search_parts for one you can name."
			+ printed)
	return ("Parts that read as %s, best first:\n\n%s\n\nsearch_parts with a number "
		% [query, "\n".join(rows)] + "says its sizes and the colours it was made in."
		+ printed)


## Prints that show what find_parts_like was asked for, as a paragraph to
## end its answer with, or "".
##
## The families it searches are plain moulds, described by what they read
## as; a print is the same mould with a picture on, so none is among them.
## But a control panel, a gauge or a grille is as often a print as a
## shape, and a design told only of shapes builds a control panel out of
## round tiles when the LEGO Group printed one on a 2 x 2 slope.
func _printed_with(query: String) -> String:
	var found: Array[PartLibrary.PartInfo] = library.search(query + " print", 4)
	var named := PackedStringArray()
	for info: PartLibrary.PartInfo in found:
		if PartsOnly.allows(info.id):
			named.append("%s %s" % [info.id, _part_called(info.id)])
	if named.is_empty():
		return ""
	return ("\n\nPrinted with it: %s. search_parts \"%s print\" for more."
		% ["; ".join(named), query])


## Each piece drawn on its own and set side by side, in the order found.
## Null where nothing can be drawn (a headless run).
func _snippet_picture(entries: Array) -> Image:
	if not ModelShot.possible() or entries.is_empty() or library == null:
		return null
	const TILE := 200
	var stage := BrickWorld.new()
	stage.library = library
	stage.visible = false
	add_child(stage)
	var sheet := Image.create(TILE * entries.size(), TILE, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.93, 0.94, 0.96))
	var shot: ModelShot = _ensure_shot()
	var was_rulers: bool = shot.rulers
	var was_highlight: Dictionary = shot.highlight
	shot.rulers = false
	shot.highlight = {}
	for n: int in entries.size():
		stage.clear()
		var model: LdrModel = LdrModel.parse(RealSnippets.ldr_text(entries[n]), "piece")
		var placed: Array = []
		for item: Variant in model.flatten(library.parts):
			var put: LdrModel.Placement = item
			if put.mirrored:
				Assemblies.unmirror(put, library)
			if library.parts.has(put.part_id):
				placed.append(put)
		var wanted := Model.new()
		for put: LdrModel.Placement in placed:
			var as_placed := Placement.new()
			as_placed.part = put.part_id
			wanted.placements.append(as_placed)
		await _ensure_parts(wanted)
		for put: LdrModel.Placement in placed:
			stage.add_brick(put.part_id, put.color_code, put.transform)
		var image: Image = await shot.take(stage, "corner")
		if image == null:
			continue
		image.convert(Image.FORMAT_RGB8)
		image.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(0, 0, TILE, TILE), Vector2i(n * TILE, 0))
	shot.rulers = was_rulers
	shot.highlight = was_highlight
	stage.queue_free()
	return sheet


## Lay a real set's piece into the model as it was built: find_techniques'
## id, turned, moved, recoloured, and put through edit_model so it is
## checked like anything else a design adds. The bricks as laid come back
## with the answer, so a design writing whole lists can carry them.
func _place_technique(args: Dictionary) -> Variant:
	var id: String = str(args.get("id", ""))
	await RealSnippets.ensure(self)
	var entry: Dictionary = RealSnippets.entry(id)
	if entry.is_empty():
		# Or one of show_technique's worked constructions, by its name: a posed
		# minifigure laid in one call, its joints put by their connectors.
		var worked: Dictionary = Techniques.named(id) if not id.strip_edges().is_empty() else {}
		if not worked.is_empty():
			return await _place_worked(worked, args)
		return ("No piece has the id \"%s\", and no worked technique is called that. Use "
			% id + "an id find_techniques gave or a name show_technique lists."
			if RealSnippets.available()
			else "This build has no index of real sets' sub-assemblies.")
	if not bool(entry.get("square", true)):
		return ("%s is built at an angle, which a placement here cannot say "
			% id + "part by part. Build it from the picture, with a section "
			+ "for the angled part.")
	var recolor: Dictionary = {}
	var asked: Variant = args.get("recolor", {})
	if asked is Dictionary:
		for key: Variant in asked:
			recolor[int(str(key))] = int((asked as Dictionary)[key])
	var at := Vector3(float(args.get("x", 0.0)), float(args.get("y", 0.0)),
		float(args.get("z", 0.0)))
	var laid: Variant = await _snippet_bricks(entry, at, int(args.get("turn", 0)), recolor)
	if laid is String:
		return laid
	var bricks: Array = laid
	_laying_whole = true
	var said: Variant = await _run_tool({"name": "edit_model", "input": {"add": bricks}})
	_laying_whole = false
	var rows := PackedStringArray()
	for raw: Variant in bricks:
		rows.append(JSON.stringify(raw))
	var head: String = ("%s \"%s\", %s: %d parts, as laid:\n%s\n"
		% [id, entry["name"], RealSnippets.credit(entry), bricks.size(),
			"\n".join(rows)])
	if said is Array:
		return [{"type": "text", "text": head}] + (said as Array)
	return "%s\n%s" % [head, str(said)]


## One of show_technique's worked constructions laid into the model by edit_model:
## turned a number of quarter turns about the upright, its parts with a corner
## moved so their lowest is at x, y, z, and each part said by its connectors
## put on the one it names wherever that went, its align and orient turned
## with it. Its names are made the model's own ("torso 2" where a torso
## stands), so a second figure attaches to its own parts. One built in
## sections is copied from show_technique instead.
func _place_worked(technique: Dictionary, args: Dictionary) -> Variant:
	if not (technique.get("sections", []) as Array).is_empty() \
			or not (technique.get("repeat_section", []) as Array).is_empty():
		return ("\"%s\" is built in sections, which place_technique does not lay: copy it "
			% technique["name"] + "from show_technique, adding to its sections' and bricks' "
			+ "x, y and z.")
	var turns: int = posmod(int(args.get("turn", 0)), 4)
	var turn := Basis(Vector3.UP, turns * PI * 0.5)
	var at := Vector3(float(args.get("x", 0.0)), float(args.get("y", 0.0)),
		float(args.get("z", 0.0)))
	var recolor: Dictionary = {}
	var asked: Variant = args.get("recolor", {})
	if asked is Dictionary:
		for key: Variant in asked:
			recolor[int(str(key))] = int((asked as Dictionary)[key])
	var taken: Dictionary = {}
	for value: Variant in _given_names.values():
		taken[str(value).to_lower()] = true
	var renamed: Dictionary = {}
	for raw: Variant in technique["bricks"]:
		var name: String = str((raw as Dictionary).get("name", ""))
		if name.is_empty():
			continue
		var free: String = name
		var n: int = 1
		while taken.has(free.to_lower()):
			n += 1
			free = "%s %d" % [name, n]
		taken[free.to_lower()] = true
		renamed[name.to_lower()] = free
	var wanted := Model.new()
	for raw: Variant in technique["bricks"]:
		var as_placed := Placement.new()
		as_placed.part = str((raw as Dictionary)["part"])
		wanted.placements.append(as_placed)
	await _ensure_parts(wanted)
	# The parts with corners, turned about the origin, then moved together.
	var low := Vector3(INF, INF, INF)
	var turned: Dictionary = {}       ## index -> [transform, corner]
	for n: int in (technique["bricks"] as Array).size():
		var brick: Dictionary = technique["bricks"][n]
		if brick.has("attach"):
			continue
		var placement := Placement.from_dict(brick)
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		if mesh == null:
			return "Part %s of \"%s\" could not be loaded to place." % [placement.part,
				technique["name"]]
		var placed_at: Transform3D = Transform3D(turn, Vector3.ZERO) * _transform(placement, mesh)
		var corners: Array = _corners_in_studs(BrickWorld.Brick.new(0, placement.part,
			placement.color, placed_at))
		if corners.is_empty():
			return "Part %s of \"%s\" could not be placed." % [placement.part, technique["name"]]
		low = low.min(corners[0])
		turned[n] = [placed_at, corners[0]]
	if low == Vector3(INF, INF, INF):
		low = Vector3.ZERO
	var shift := Vector3(at.x - roundf(low.x), at.y - floorf(low.y + 0.01), at.z - roundf(low.z))
	var split := RegEx.create_from_string(
		"^(.+?)(\\s*\\.\\s*[A-Za-z]+\\s*(?:\\[\\s*-?\\d+\\s*\\]|-?\\d+)?)$")
	var bricks: Array = []
	for n: int in (technique["bricks"] as Array).size():
		var brick: Dictionary = (technique["bricks"][n] as Dictionary).duplicate(true)
		brick["color"] = int(recolor.get(int(brick.get("color", DEFAULT_COLOUR)),
			brick.get("color", DEFAULT_COLOUR)))
		if brick.has("name"):
			brick["name"] = renamed.get(str(brick["name"]).to_lower(), brick["name"])
		if brick.has("attach"):
			var joint: Dictionary = brick["attach"]
			var found: RegExMatch = split.search(str(joint.get("to", "")))
			if found != null and renamed.has(found.get_string(1).strip_edges().to_lower()):
				joint["to"] = str(renamed[found.get_string(1).strip_edges().to_lower()]) \
					+ found.get_string(2)
			if joint.get("align") is Array and (joint["align"] as Array).size() == 2:
				var v: Variant = Attach.direction(joint["align"][1])
				if v != null:
					var way: Vector3 = turn * (v as Vector3)
					joint["align"] = [joint["align"][0], [snappedf(way.x, 0.0001),
						snappedf(way.y, 0.0001), snappedf(way.z, 0.0001)]]
			if joint.get("orient") is Dictionary:
				(joint["orient"] as Dictionary)["yaw"] = float((joint["orient"] as Dictionary).get(
					"yaw", 0.0)) + 90.0 * turns
			bricks.append(brick)
			continue
		var row: Array = turned[n]
		var basis: Basis = (row[0] as Transform3D).basis
		var face: String = BrickLattice.face_of(basis)
		var corner: Vector3 = (row[1] as Vector3) + shift
		brick["x"] = snappedf(corner.x, 0.01)
		brick["y"] = snappedf(corner.y, 0.01)
		brick["z"] = snappedf(corner.z, 0.01)
		brick["rot"] = BrickLattice.turns_about(basis, face)
		brick.erase("face")
		if face != "up":
			brick["face"] = face
		bricks.append(brick)
	_laying_whole = true
	var said: Variant = await _run_tool({"name": "edit_model", "input": {"add": bricks}})
	_laying_whole = false
	var rows := PackedStringArray()
	for raw: Variant in bricks:
		rows.append(JSON.stringify(raw))
	var head: String = ("\"%s\": %d parts, as laid; each with attach goes where it names "
		% [technique["name"], bricks.size()] + "and follows it, and its names are the model's "
		+ "now, for a later edit to attach to:\n%s\n" % "\n".join(rows))
	if said is Array:
		return [{"type": "text", "text": head}] + (said as Array)
	return "%s\n%s" % [head, str(said)]


## A piece's parts as placements: turned a number of quarter turns about
## the upright, then, with [param up] other than "up", tipped whole so its
## own up points that way (an eye built studs up, laid studs out on a
## face), moved by whole studs so its low corner is at `at` and what was
## on the grid stays on it, colours swapped where `recolor` says. A String
## says why it cannot be.
func _snippet_bricks(entry: Dictionary, at: Vector3, turns: int,
		recolor: Dictionary, up: String = "up") -> Variant:
	var model: LdrModel = LdrModel.parse(RealSnippets.ldr_text(entry), "piece")
	var placed: Array = []
	for item: Variant in model.flatten(library.parts):
		var put: LdrModel.Placement = item
		if put.mirrored:
			Assemblies.unmirror(put, library)
		if not library.parts.has(put.part_id):
			return "%s uses part %s, which this library does not have." % [
				entry["id"], put.part_id]
		placed.append(put)
	var wanted := Model.new()
	for put: LdrModel.Placement in placed:
		var as_placed := Placement.new()
		as_placed.part = library.resolve(put.part_id)
		wanted.placements.append(as_placed)
	await _ensure_parts(wanted)
	var turn := Transform3D(Basis(Vector3.UP, posmod(turns, 4) * PI / 2.0), Vector3.ZERO)
	if up != "up" and FACES.has(up):
		turn = Transform3D(BrickLattice.basis_for(up, 0), Vector3.ZERO) * turn
	var read: Array = []
	var low := Vector3(INF, INF, INF)
	for put: LdrModel.Placement in placed:
		var part_id: String = library.resolve(put.part_id)
		var placed_at: Transform3D = turn * put.transform
		var corners: Array = _corners_in_studs(
			BrickWorld.Brick.new(0, part_id, put.color_code, placed_at))
		if corners.is_empty():
			return "Part %s of %s could not be loaded to place." % [part_id, entry["id"]]
		var corner: Vector3 = corners[0]
		low = low.min(corner)
		read.append([part_id, put.color_code, placed_at, corner])
	var shift := Vector3(at.x - roundf(low.x), at.y - floorf(low.y + 0.01),
		at.z - roundf(low.z))
	var bricks: Array = []
	for row: Array in read:
		var basis: Basis = (row[2] as Transform3D).basis
		var face: String = BrickLattice.face_of(basis)
		var corner: Vector3 = row[3] + shift
		var brick := {"part": row[0], "color": int(recolor.get(int(row[1]), row[1])),
			"x": snappedf(corner.x, 0.01), "y": snappedf(corner.y, 0.01),
			"z": snappedf(corner.z, 0.01), "rot": BrickLattice.turns_about(basis, face)}
		if face != "up":
			brick["face"] = face
		bricks.append(brick)
	return bricks


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
	elif metres * float((SCALES[0] as Dictionary)["studs_per_metre"]) < TOO_SMALL:
		# Smaller than a scale can show: a person, an animal, a chair. "Build
		# a part of it, a locomotive rather than the train" is no answer for
		# those, and nothing else said how big a figure is: the first
		# BrickBench knights were stacked 37 to 62 plates tall.
		chosen = ("\n\nAt %s metres it is smaller than any scale reads, so "
			% Placement._num(metres)
			+ "it is built as a figure, not to a scale. A person among "
			+ "minifigure-scale things is a minifigure, posed as the brief has them: "
			+ "place_technique \"posed minifigure\" lays one in one call, its arms, "
			+ "legs and head each on its joint, posed again by their yaw "
			+ "(add_minifig stands one at rest); an animal there is one moulded part "
			+ "(search_parts \"animal\"). On its own, a figure or a creature is "
			+ "brick-built, about 6 to 16 studs tall in its own proportions, on a "
			+ "jointed armature: place_technique \"jointed figure\" (a person) or "
			+ "\"jointed animal\" (four legs) lays one, every limb on a joint, to pose "
			+ "and to build its shaped parts on — a round brick or a dome for a head, "
			+ "round bricks and curved slopes for a body (read_guide \"figures\").")
	else:
		chosen = ("\n\nNothing on that list reads well at %s metres. "
			% Placement._num(metres)
			+ "Build a part of it instead — a locomotive rather than the "
			+ "train, a tower rather than the whole castle — or accept "
			+ "that it will be an outline.")

	# A figure or a creature at a scale too — a giant, a dragon, a mascot on a
	# roof — is built on joints all the same. plan_scale's figure answer was for
	# the small alone, by size, and never said a joint (2026-10-15).
	if not chosen.contains("jointed armature") \
			and not Style.character_of("%s %s" % [subject, _subject_of()]).is_empty():
		chosen += ("\n\nA figure or a creature at any size is built on joints, not "
			+ "stacked: its head on a neck, its limbs on clips, balls and hinges at the "
			+ "pose's angle (place_technique \"jointed figure\", \"jointed animal\", "
			+ "\"posed minifigure\" for a person at minifigure scale, or one joint each: "
			+ "\"limb on a clip\", \"ball shoulder\", \"head on a neck\", \"tail on a bar\", "
			+ "\"hinged wing\").")
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
	if _finder.swatches.is_empty() and library != null:
		for code: int in _current_colours(["solid"]):
			_finder.swatches.append([code, (library.colors[code] as PartLibrary.BrickColor).rgb])

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
			+ "back something else that shares it." + _colours_seen(pictures))}]
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


## The pictures' colours as LEGO colours, said as numbers to build in.
##
## The owner's Falcon Heavy came out in three greys with the photographs
## in front of the design: a white rocket with black interstages, built
## from memory of "rocket grey". ReferenceFinder reads each picture into
## the plastic colours sets are made in, backdrop left out; this says them
## once, averaged over the pictures, commonest first.
func _colours_seen(pictures: Array) -> String:
	var summed: Dictionary = {}
	var counted: int = 0
	for one: Variant in pictures:
		var shares: Dictionary = (one as Dictionary).get("colours", {}) as Dictionary
		if shares.is_empty():
			continue
		counted += 1
		for code: int in shares:
			summed[code] = float(summed.get(code, 0.0)) + float(shares[code])
	if counted == 0:
		return ""
	var codes: Array = summed.keys()
	codes.sort_custom(func(a: int, b: int) -> bool:
		return float(summed[a]) > float(summed[b]))
	var said := PackedStringArray()
	for code: int in codes:
		var share: float = float(summed[code]) / counted
		if share < SEEN_AT_LEAST or said.size() >= SEEN_MOST:
			break
		said.append("%s (%d) %d%%" % [_colour_name(code), code, roundi(share * 100.0)])
	if said.is_empty():
		return ""
	return ("\n\nIts colours in these pictures, read as the plastic colours sets "
		+ "are made in, the backdrop left out: " + ", ".join(said) + ". Build in "
		+ "these numbers, not the colour you remember the thing being: the "
		+ "commonest is its main colour, a dark one in a band is a stripe or a "
		+ "section, and a grey just lighter or darker than the main colour is "
		+ "often the main colour in shadow or in light. Look at the picture to "
		+ "tell which.")


## Colours under this share of the pictures' subject go unsaid, and no
## more than this many are said.
const SEEN_AT_LEAST := 0.04
const SEEN_MOST := 6


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
	return _tools() + focus_tools() + sketch_tools()


## Choosing a sketch, for a session outside the app: in the app's own loop
## the person chooses, on the cards in the panel, so the loop is not offered it.
func sketch_tools() -> Array:
	return [{
		"name": "choose_sketch",
		"description": ("Choose one of the three sketches made with submit_design "
			+ "\"sketch\": true. It goes on the baseplate as the massing the full "
			+ "design is built from, and the other two are dropped. Then design the "
			+ "whole model from it, and submit_design that without sketch."),
		"input_schema": {
			"type": "object",
			"properties": {
				"sketch": {"type": "integer", "description": "its number, 1 to 3"},
			},
			"required": ["sketch"],
			"additionalProperties": false,
		},
	}]


## search_gear_ratio: GearRatios over the asked ratio, said compactly, or
## what to give instead.
static func gear_ratio_said(args: Dictionary) -> String:
	var wanted: float = 0.0
	if args.has("ratio"):
		wanted = float(args["ratio"])
	elif args.has("period") and float(args["period"]) != 0.0:
		wanted = 1.0 / float(args["period"])
	if wanted == 0.0 or is_nan(wanted) or is_inf(wanted):
		return ("Give ratio= (output turns per input turn: 1/3 for an 8 driving a 24 is 0.3333, "
			+ "negative for the other way) or period= (input turns per output turn).")
	if absf(wanted) < 1e-6 or absf(wanted) > 1e6:
		return "%s is out of reach of a gear train: between a millionth and a million." % str(wanted)
	var most: int = clampi(int(args.get("stages", 4)), 1, GearRatios.MOST_STAGES)
	var to: Variant = null
	if args.get("to") is Array:
		var at: Array = args["to"]
		if at.size() != 2:
			return "to= is [x, z], in studs."
		to = Vector2i(roundi(float(at[0])), roundi(float(at[1])))
	var teeth: Array = []
	for one: Variant in (args.get("gears", []) as Array if args.get("gears") is Array else []):
		if not GearRatios.PARTS.has(int(one)):
			return "gears= takes tooth counts of %s." % ", ".join(PackedStringArray(
				GearRatios.PARTS.keys().map(func(t: int) -> String: return str(t))))
		teeth.append(int(one))
	if teeth.is_empty():
		teeth = GearRatios.PARTS.keys()
	var first: int = int(args.get("first", 0))
	if first != 0 and not first in teeth:
		return "first= is the input's gear, one of the tooth counts searched."
	var trains: Array[GearRatios.Train] = GearRatios.search(wanted, most, to,
		clampi(int(args.get("within", 2)), 0, 4), teeth, GearRatios.KEEP, first)
	return GearRatios.said(trains, wanted, most, to)


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
	var unjointed: String = _unjointed_refusal(design)
	if not unjointed.is_empty():
		return unjointed
	await _ready_to_check(design)
	var report: Dictionary = await _checked(design)
	if not bool(report["ok"]):
		return "Not applied — it does not hold together yet.\n%s" \
			% report["feedback"]
	await _ensure_parts(design)
	await _apply(design, true, true)
	if not _busy:
		_outside_standing = true
		_outside_assemblies = design.assemblies.duplicate()
		_outside_reviewed = {}
		_outside_reviewing = {}
		_detail_added = []
		_exact_save_refusals = 0
		_brief = "%s. %s" % [design.name, design.description]
		# Submitted again with the same features keeps what was done for them.
		if design.features != _outside_features:
			_feature_used = {}
		_outside_features = design.features.duplicate()
		_feature_now = ""
		# The model is new, so whatever the pass laid is gone with the old one.
		feature_pass().reset(design.feature_spots)
		# A new design, so its surface and creative passes are still to come.
		_outside_designed = true
		_outside_creative_handed = false
		_outside_creative = {}
		surface_pass().reset()
	return _built_from_outside(design, report)


## A design built from outside — Claude over the connector, or a session
## on the MCP port — has no loop of this app's to look it over after it
## stands. This app's own designer measures it against real sets, looks
## at the whole, then details each assembly close up; told only "Built",
## the session did none of that. The first tower of Orthanc to come in
## from claude.ai was built that way: the check measured it and the
## answer threw the measurements away. So the answer carries them, and
## review_model is the rest of the loop, one call at a time.
var _outside_assemblies: Array[Dictionary] = []
## A design built from outside stands on the baseplate, so a check is a
## check and not a replacement for it.
var _outside_standing: bool = false
## The assembly being reviewed, and the parts the model had before, so the
## next review can say what this one brought.
var _outside_reviewing: Dictionary = {}
## The assemblies a session has had a close review of, by name in lower case.
var _outside_reviewed: Dictionary = {}

const FROM_OUTSIDE_NEXT := """A first design is never as detailed as a \
set; this app's own designer always goes on from here, and so should you:
  1. review_model with no assembly: the silhouette and proportions first — \
the whole model measured against real sets of its size and kind, with what \
to look for. view_model from two corners to see it. Fix the masses before \
any detail.
  2. Then each feature, one at a time{features}: the app lays the best \
real set's piece for it where it goes and hands it to you with a picture \
(the whole review hands the first). settle_feature says what it is to be: \
accept it (moved, turned or recoloured first if it needs it), "next" for \
the next-best, reject it with a reason and build your own, or "built". \
Each settle hands the next. Saving waits until every feature is settled.
  3. Then review_model for each assembly in turn{names}: close up, \
measured, with the parts real sets of the kind use that it has none of. \
Detail it with edit_model — a different piece where something changes — \
before moving to the next. Never submit_design again for this: it \
replaces the whole model.
  4. Then the surface pass: review_model {"surface": true}. The app tiles \
the open stud fields, slopes the staircases (plate steps too), rounds a \
body's hard top edges, skins its flanks and textures a building's walls, \
and you settle each with settle_surface — accept, reject or keep, with a \
reason.
  5. Then the creative pass, last: review_model {"creative": true}. Three \
touches proposed for this subject — a story, a play or display feature, a \
nod only someone who knows it would catch — and the best one or two added, \
small and joined, where they are seen."""


func _built_from_outside(design: Model, report: Dictionary) -> String:
	var said := PackedStringArray()
	said.append("Built. %d bricks on the baseplate. %s" % [
		design.placements.size(), report["summary"]])
	var measured: Array = report.get("advice", [])
	if not measured.is_empty():
		said.append("What the check measured about it:\n"
			+ "\n".join(PackedStringArray(measured)))
	var names := PackedStringArray()
	for one: Dictionary in design.assemblies:
		names.append(str(one.get("name", "")))
	said.append(FROM_OUTSIDE_NEXT.replace("{names}",
		" (%s)" % ", ".join(names) if not names.is_empty() else "").replace("{features}",
		" (%s)" % ", ".join(design.features) if not design.features.is_empty()
			else " (you listed none: name what the subject is known by — eyes, beak, ears, "
				+ "wheel arches, grille, windows, roof — and give each its turn)"))
	# Big and in sections, as a set with bags is: what big sets do inside,
	# offered at the very end, never done unasked (HiddenColours).
	if design.placements.size() >= HiddenColours.OFFER_PARTS \
			and design.assemblies.size() >= HiddenColours.OFFER_SECTIONS:
		said.append(OFFER_HIDDEN_COLOURS)
	return "\n\n".join(said)


const OFFER_HIDDEN_COLOURS := """  6. At the very end, for a model this big in \
sections: offer the person colour_hidden_parts — the parts nobody sees once \
it is finished, a colour for each section, as big sets are coloured inside, \
so they can find their place while building it. Only an offer: show them \
the preview, and apply it only once they say yes."""


## The review this app's own designer gives a model, for a session doing
## its own designing: the whole, or one named assembly close up.
func review(assembly: String, feature: String = "", creative: bool = false) -> Variant:
	# A coroutine for the whole model's check below: callers await it.
	var everything: Array[BrickWorld.Brick] = _bricks_inside({})
	if everything.is_empty():
		return "The baseplate is bare: there is nothing to review."
	if creative:
		return _creative_review()
	if not feature.strip_edges().is_empty():
		return await _review_feature(feature.strip_edges())
	# What the last assembly reviewed brought, for the next one to know.
	if not _outside_reviewing.is_empty():
		var before: Dictionary = _outside_reviewing["parts"]
		var added := PackedStringArray()
		for part_id: String in _parts_in(everything):
			if not before.has(part_id):
				added.append(part_id)
		_detail_added.append([_outside_reviewing["name"], added])
		_outside_reviewing = {}
	if assembly.strip_edges().is_empty():
		# Every part this design placed is judged, not only what an edit adds:
		# a design is handed over from here, and BrickBench refuses a build for
		# one collision or one loose part (ExactCheck).
		_strict_mine = true
		var report: Dictionary = await _checked(_model_from_world())
		_strict_mine = false
		var said := PackedStringArray()
		said.append("The whole model: %s. %s." % [_texture(everything),
			report["summary"]])
		var faults: String = _exact_faults_said(report)
		if not faults.is_empty():
			said.append(faults)
		var measured: Array = report.get("advice", [])
		if not measured.is_empty():
			said.append("Measured against real sets:\n"
				+ "\n".join(PackedStringArray(measured)))
		var stiff: String = _stiff_limbs_said(everything)
		if not stiff.is_empty():
			said.append(stiff)
		said.append(CRITIQUE)
		said.append(_features_to_review())
		said.append(_assemblies_to_review())
		said.append("Then the surface pass, review_model {\"surface\": true}; last, the "
			+ "creative pass: review_model {\"creative\": true}.")
		# The first feature with no turn yet, here: a list to work through
		# was read and put down, and the run went on to save.
		var left: Array[String] = _features_left()
		if not left.is_empty():
			said.append("Once the silhouette is right, the first feature, the %s — the app "
				% left[0] + "has laid a real set's piece for it:")
			return _joined("\n\n".join(said), await _review_feature(left[0]))
		return "\n\n".join(said)
	var one: Dictionary = {}
	for named: Dictionary in _outside_assemblies:
		if str(named.get("name", "")).to_lower() == assembly.strip_edges().to_lower():
			one = named
	if one.is_empty():
		return "No assembly called %s. %s" % [assembly, _assemblies_to_review()]
	var name: String = str(one["name"])
	var inside: Array[BrickWorld.Brick] = _bricks_inside(one.get("where", {}))
	if inside.is_empty():
		return "Nothing stands inside the box of the %s. %s" % [name,
			_assemblies_to_review()]
	_outside_reviewing = {"name": name, "parts": _parts_in(everything)}
	_outside_reviewed[name.to_lower()] = true
	# Not "and stop": said to a session with nothing to hand it the next
	# assembly, that ended the run. The sixteenth Orthanc made one edit to
	# the first of its three assemblies, then saved and finished; no run
	# from outside had reviewed more than two.
	var left: Array[String] = _not_yet_reviewed()
	var ending: String = ("say in a line what you changed, then review_model "
		+ "{\"assembly\": \"%s\"}%s." % [left[0], " — %d more after it" % (left.size() - 1)
			if left.size() > 1 else ""]) if not left.is_empty() \
		else ("say in a line what you changed: it is the last of its assemblies. "
			+ "Then the surface pass, review_model {\"surface\": true}, and the creative "
			+ "pass, review_model {\"creative\": true}.")
	return "%s\n\n%s\n\nSee it with view_model from=\"corner\" and from=\"far corner\", where=%s." % [
		_assembly_measured(name, inside, _bounds_of(inside)),
		ASSEMBLY_CRITIQUE.replace("{name}", name).replace(
			"say in a line what you changed, and stop.", ending),
		JSON.stringify(one.get("where", {}))]


## What a design names a limb by, in its parts', sections' and assemblies' names.
const LIMB_NAMES: Array = ["arm", "leg", "limb", "hand", "foot", "paw", "tail", "wing",
	"neck", "flipper", "fin"]


## A figure's or a creature's limbs stacked square on its body: each one named
## as a limb (a part, a section or an assembly) with nothing in it on a joint,
## or, with none named, a character with nothing on a joint at all. The attach
## round's first review said "a hinge or a leg built rigid" among five faults
## of any model, and pointed at a section of the guide no session read; the
## balloon dog's tail was settled "built", of round bricks, under a review
## that offered "tail on a bar". "" when it is not a character, or is posed.
func _stiff_limbs_said(everything: Array[BrickWorld.Brick]) -> String:
	var kind: String = Style.character_of(_subject_of())
	if kind.is_empty() or everything.size() < JOINTS_FROM:
		return ""
	var units: Dictionary = {}     ## name -> Array of bricks
	for one: Dictionary in _outside_assemblies:
		var name: String = str(one.get("name", ""))
		if not SubjectWords.first_named(name, LIMB_NAMES).is_empty():
			units[name] = _bricks_inside(one.get("where", {}))
	for brick: BrickWorld.Brick in everything:
		for name: String in [str(_section_of.get(brick.id, "")), str(_given_names.get(brick.id, ""))]:
			if not name.is_empty() and not SubjectWords.first_named(name, LIMB_NAMES).is_empty():
				if not units.has(name):
					units[name] = []
				(units[name] as Array).append(brick)
	var stiff := PackedStringArray()
	for name: String in units:
		var bricks: Array = units[name]
		# A leg it stands on is standing, not stiff.
		if bricks.any(func(b: Variant) -> bool: return _on_the_floor(b)):
			continue
		if not bricks.is_empty() and not _bricks_posed(bricks):
			stiff.append("the %s (%d part%s)" % [name, bricks.size(),
				"" if bricks.size() == 1 else "s"])
	var how: String = ("Put each on a joint at the angle the pose has, and build it on "
		+ "that: an arm or a leg on a ball (place_technique \"ball shoulder\") or a bar in a "
		+ "clip (\"limb on a clip\"), a head on a ball neck (\"head on a neck\"), a tail on "
		+ "a bar (\"tail on a bar\"), a wing on a click hinge (\"hinged wing\"); a part's "
		+ "attach in edit_model puts what is built onto it by its connectors.")
	if not stiff.is_empty():
		return ("Stiff, stacked limbs: %s stand%s square on the body with nothing on a "
			% [", ".join(stiff), "s" if stiff.size() == 1 else ""]
			+ "joint, so they read as a statue's, never as reaching, sitting or "
			+ "turning. " + how)
	if _bricks_posed(everything):
		return ""
	return ("Nothing in it is on a joint: a figure's or a creature's head, limbs and tail "
		+ "stacked square on its body stand stiff, as a statue of bricks does, and the "
		+ "pose the brief has cannot be read. " + how)


## Whether [param brick] stands on the floor: its lowest within a plate of it.
func _on_the_floor(brick: BrickWorld.Brick) -> bool:
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	return mesh != null and mesh.lowest_at(brick.transform) <= PLATE


## Whether any of [param bricks] is posed: a joint's part (Style's "a"), turned
## off the square, or in a section on a hinge or turned.
func _bricks_posed(bricks: Array) -> bool:
	for raw: Variant in bricks:
		var brick: BrickWorld.Brick = raw
		if Style.kinds_of(brick.part_id).contains("a") or Style._angled(brick.transform.basis):
			return true
		var section: Variant = _sections.get(str(_section_of.get(brick.id, "")))
		if section is Section and ((section as Section).hinge
				or not is_zero_approx((section as Section).degrees)):
			return true
	return false


## What the exact check found in a whole design, said as faults to fix before
## it is handed over, or "" when it found nothing.
static func _exact_faults_said(report: Dictionary) -> String:
	var found: Dictionary = report.get("exact", {})
	var lines := PackedStringArray()
	for kind: String in ["collision", "not held", "tips over"]:
		var said: Array = found.get(kind, [])
		if said.is_empty():
			continue
		lines.append("%s (%d):" % [kind, said.size()])
		for n: int in mini(WORTH_SAYING, said.size()):
			lines.append("  - " + str(said[n]))
		if said.size() > WORTH_SAYING:
			lines.append("  - ... and %d more like it" % (said.size() - WORTH_SAYING))
	if lines.is_empty():
		return ""
	return ("Fix these first, with edit_model: a build with one of them is refused "
		+ "by BrickBench's check, and in the hand it jams or falls apart.\n" + "\n".join(lines))


## The next assembly's close review, for a session that is saving with some
## not yet looked at closely; "" when every one has been. The sixteenth
## Orthanc's last act was to save, with two of its three assemblies never
## reviewed: so saving hands it the next, as this app's own loop hands each
## assembly back in turn.
func next_review() -> Variant:
	# A coroutine because review is: callers await it.
	var undone: Array[String] = _features_left()
	if not undone.is_empty():
		var passed: String = _creative_passed()
		return _joined(_first(passed, "Before it is finished: %d of its %d features %s not "
			% [undone.size(), _outside_features.size(), "is" if undone.size() == 1 else "are"]
			+ "settled yet (%s). The next is the %s." % [", ".join(undone), undone[0]]),
			await _review_feature(undone[0]))
	var left: Array[String] = _not_yet_reviewed()
	if left.is_empty():
		# The surface pass before the creative pass; reminded, never refused.
		var first_time: String = _surface_first_reminder()
		if not first_time.is_empty():
			return _first(_creative_passed(), first_time)
		return _first(surface_pass().reminder() if _outside_designed else "", _creative_next())
	var name: String = left[0]
	var passed_too: String = _creative_passed()
	return _joined(_first(passed_too, "Before it is finished: %d of its %d assemblies %s not had "
		% [left.size(), _outside_assemblies.size(), "has" if left.size() == 1 else "have"]
		+ "a close look (%s). This app's own designer details each in turn; the " % ", ".join(left)
		+ "next is the %s." % name), await review(name))


## Whether a session from outside may save yet: "" when it may; otherwise
## why not, with the first feature not settled handed over, its piece laid.
## Every bench session saved with features never worked, and saving handed
## the next one back only after the file was written: the session read
## "Written" and ended. A save that waits is a turn the design cannot skip.
func save_gate() -> Variant:
	if _busy or not _outside_standing:
		return ""
	var left: Array[String] = _features_left()
	if left.is_empty():
		return await _exact_save_gate()
	progress.emit("not saved: %d features not settled" % left.size())
	return _joined(("Not saved yet: %d of its %d features %s not settled (%s). For each, "
		% [left.size(), _outside_features.size(), "is" if left.size() == 1 else "are",
			", ".join(left)]) + "the app lays the best real set's piece where it goes; "
		+ "settle_feature accepts it (adjusted if need be), asks for the next, rejects "
		+ "it with a reason, or says you built it. Then save again. The %s:" % left[0],
		await _review_feature(left[0]))


## Times saving has been held back for what the exact check finds; after
## MOST_EXACT_REFUSALS it saves and says so, rather than hold a session that
## cannot fix a part for ever.
var _exact_save_refusals: int = 0
const MOST_EXACT_REFUSALS := 2


## Saving a design built from outside waits, twice at most, until no part of
## it collides by its real shape or rests with nothing holding it (ExactCheck):
## the design is handed over when it is saved, and BrickBench refuses a build
## for one of either. "" lets it save.
func _exact_save_gate() -> String:
	if _exact_save_refusals >= MOST_EXACT_REFUSALS or world == null or world.brick_count() == 0:
		return ""
	_strict_mine = true
	var report: Dictionary = await _checked(_model_from_world())
	_strict_mine = false
	var faults: String = _exact_faults_said(report)
	if faults.is_empty():
		return ""
	_exact_save_refusals += 1
	progress.emit("not saved: parts collide or hang loose")
	return "Not saved yet. %s\nThen save again." % faults


## [param said] and then [param then], or [param then] alone.
static func _first(said: String, then: String) -> String:
	return then if said.is_empty() else "%s\n\n%s" % [said, then]


## The assemblies a session named that have had no close review yet, in
## the order it named them.
func _not_yet_reviewed() -> Array[String]:
	var left: Array[String] = []
	for one: Dictionary in _outside_assemblies:
		var name: String = str(one.get("name", ""))
		if not _outside_reviewed.has(name.to_lower()):
			left.append(name)
	return left


## A feature for a session from outside: how real sets built it and the
## worked technique, and from now until the next review what it uses is
## put down to this feature.
func _review_feature(name: String) -> Variant:
	var known: String = name
	for listed: String in _outside_features:
		if listed.to_lower() == name.to_lower():
			known = listed
	if not _outside_features.has(known):
		_outside_features.append(known)
	_feature_now = known
	_note_feature("looked up %s" % known)
	var of: int = _outside_features.find(known) + 1
	progress.emit("working the %s (feature %d of %d)" % [known, of, _outside_features.size()])
	return await _feature_brief(known, of, _outside_features.size(), true)


## The features listed that have not been settled (settle_feature).
func _features_left() -> Array[String]:
	return feature_pass().open(_outside_features)


func _features_to_review() -> String:
	if _outside_features.is_empty():
		return ("No features were listed. Name what the subject is known by in "
			+ "submit_design's features, or review_model {\"feature\": \"eyes\"} "
			+ "for each: a feature a real set solved is better than a first guess.")
	return ("Its features, each laid by the app and settled in turn (settle_feature):\n%s"
		% _features_record(_outside_features))


func _assemblies_to_review() -> String:
	if _outside_assemblies.is_empty():
		return ("No assemblies were named when it was submitted; name them "
			+ "in submit_design's assemblies to have each reviewed close up.")
	var names := PackedStringArray()
	for one: Dictionary in _outside_assemblies:
		names.append(str(one.get("name", "")))
	return "Its assemblies, to review one at a time: %s." % ", ".join(names)


# -- asked about a selection -------------------------------------------------


## The selection a person asked about, or null: its parts, the room a
## change to them may use, and the undo step the change gathers into. See
## [SelectionScope].
var focus: SelectionScope = null
## The model's sub-assemblies, so the other copies of one follow a change
## to the selection made in it (the app's; null where there are none).
var assemblies: Assemblies = null
## Set when the panel asked about [member focus], so a session reading the
## selection is told about the parts the person asked about rather than
## whatever is selected by the time it looks.
var _focus_pinned: bool = false
## True while the edits being made are about [member focus]: this app's
## own run asked about a selection, or an edit_selection from outside.
var _scoped: bool = false
## And whether the conversation is about a selection, so a second request
## about it carries on from the first.
var _scoped_talk: bool = false

## A change to the selection landed: what it did in words, and the room
## the selection is in before and after, in its own colours (null when
## there is nothing to draw with).
signal focus_edited(summary: String, before: Image, after: Image)
## Claude asks for more room than the selection gives; the person answers
## with [method answer_room].
signal room_asked(why: String, where: String)
## The answer, or -1 while it is awaited.
var _room_answer: int = -1
## How long a request for room waits for the person. The relay gives up on
## a call at three minutes; a no is better than its silence.
var room_wait_s: float = 120.0

const NOTHING_SELECTED := ("Nothing is selected in Brickworks. Ask the person "
	+ "to select the parts they mean (click one; shift-click or drag a box for "
	+ "more), then call selection again.")

const FOCUS_RULES := """A change about them may take off, paint, move or put \
down parts only inside that room. One that reaches outside it is refused \
whole, naming the parts that did: everything outside stays exactly where it \
is. The model must still hold together and be one piece afterwards; the \
change is checked as any design is, and refused if it would not. Make it with \
edit_selection, which takes what edit_model takes, by the numbers above. If \
it cannot be done inside the room, give edit_selection room={x_from, x_to, \
y_from, y_to, z_from, z_to} in studs and plates and why=, a sentence the \
person reads: they are asked in the app, and the change goes ahead only if \
they say yes. A question (why is this not stable, what is this part) is \
answered in words, changing nothing unless they ask."""

const FOCUS_TASK := """This is not a new design. The person has selected part \
of their model and asked about that part. Change only it, with \
edit_selection: never submit_design, which would replace the model, and \
nothing the room does not hold. where_to_attach says where a part can go on \
it and, with part=, gives placements that fit and hold. Make the change big \
enough to see at once: a person asking for spikes wants spikes, not barbs. \
Read what changed in the picture that comes back. When it is done, or if it \
is a question, say so in a sentence or two and stop."""


## Ask about these parts: the selection's room is worked out now, from
## where they stand. "" when it can be, or why not. [param pinned] for the
## panel's own request: a session then reads these parts, not whatever is
## selected by the time it looks.
func focus_on(selected: Array, pinned: bool = false) -> String:
	if focus != null and focus.same(selected) and _focus_alive():
		_focus_pinned = _focus_pinned or pinned
		return ""
	var scope: SelectionScope = SelectionScope.of(selected, world, library, scenery)
	if scope == null:
		return NOTHING_SELECTED
	focus = scope
	_focus_pinned = pinned
	_scoped_talk = false
	return ""


## Whether what is changed now must keep to the selection's room: this
## app's own run about it, an edit_selection, or anything at all while the
## person's request about it (the panel's chip, or --ask-about) stands.
func _keeps_to_focus() -> bool:
	return (_scoped or _focus_pinned) and _focus_alive()


## Whether the person asked about a selection that still stands: their
## request is about it, whatever a session calls.
func asked_about_selection() -> bool:
	return _focus_pinned and _focus_alive()


## No longer about a selection.
func unfocus() -> void:
	focus = null
	_focus_pinned = false
	_scoped_talk = false


## Whether the parts asked about still stand. Those an undo or another
## change took off are let go of; none left, and it is gone.
func _focus_alive() -> bool:
	if focus == null:
		return false
	for brick_id: Variant in focus.ids.keys():
		if world.get_brick(int(brick_id)) == null:
			focus.ids.erase(brick_id)
	return not focus.ids.is_empty()


## The selection, for a session to read: its parts by number, where they
## are, the room a change may use, and two pictures with it picked out —
## close up, and the whole model round it.
func selection_said() -> Variant:
	var selected: Array = builder.selection.keys() if builder != null else []
	if not _busy and not _focus_pinned and not selected.is_empty():
		focus_on(selected)
	if not _focus_alive():
		var why: String = focus_on(selected)
		if not why.is_empty():
			return why
	var words: String = _focus_words()
	if not ModelShot.possible():
		return words
	_ensure_shot().highlight = focus.ids.duplicate()
	var close: Image = await _shot.take(world, "corner", scenery, focus.region)
	var whole: Image = await _shot.take(world, "corner", scenery)
	_shot.highlight = {}
	if focus.before == null:
		focus.before = await _shot.take(world, "corner", scenery, focus.region)
	var blocks: Array = [{"type": "text", "text": words}]
	for pair: Array in [[close, "Close up, from the corner, the selection in magenta (only in "
			+ "the picture: they are the colours listed):"],
			[whole, "The whole model, the selection in magenta:"]]:
		if pair[0] == null:
			continue
		var picture: Dictionary = await _shot.encode(pair[0])
		if not picture.is_empty():
			blocks.append({"type": "text", "text": pair[1]})
			blocks.append(picture)
	return blocks


## The selection in words.
func _focus_words() -> String:
	var rows := PackedStringArray()
	var tally: Dictionary = {}
	var colours: Dictionary = {}
	var ids: Array = focus.ids.keys()
	ids.sort()
	# Each where edit_model reads it, in the section it is laid in when it
	# is laid turned: the numbers to write are the numbers given. Said in
	# the world's square coordinates instead, a part of Orthanc's horn,
	# turned 25 degrees, read as standing where it does not, and the first
	# real request about one was refused 22 times finding out.
	var read: OpenPoints = OpenPoints.read(self)
	var laid_in: Dictionary = {}
	for raw: Variant in ids:
		var brick: BrickWorld.Brick = world.get_brick(int(raw))
		if brick == null:
			continue
		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		tally[key] = int(tally.get(key, 0)) + 1
		colours[brick.color_code] = true
		var placement: Placement = read.by_id.get(brick.id)
		if placement != null and not placement.section.is_empty():
			laid_in[placement.section] = int(laid_in.get(placement.section, 0)) + 1
		if rows.size() >= WORLD_ROWS or placement == null:
			continue
		rows.append("  #%-4d %-9s c%-3d x=%-6s y=%-6s z=%-6s %s rot=%d%s" % [
			brick.id, brick.part_id, brick.color_code, Placement._num(placement.x),
			Placement._num(placement.y), Placement._num(placement.z), placement.face,
			placement.rot, "" if placement.section.is_empty()
				else " section='%s'" % placement.section])
	var others: int = 0
	var standing: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		standing += 1
		if not focus.ids.has(brick.id) and focus.holds(
				SelectionScope.box_of(brick.part_id, brick.transform, library)):
			others += 1
	var lines := PackedStringArray()
	lines.append("The person has selected %d part%s in Brickworks, of the %d in the model%s. "
		% [focus.ids.size(), "" if focus.ids.size() == 1 else "s", standing,
			"" if focus.path.is_empty() else ", all in its sub-assembly \"%s\""
				% Assemblies.label(focus.path)]
		+ "This is about them.")
	lines.append("They stand %s, in %d colour%s." % [_box_words(focus.box),
		colours.size(), "" if colours.size() == 1 else "s"])
	lines.append("")
	lines.append("Parts and colours, most first:")
	var keys: Array = tally.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(tally[a]) > int(tally[b]))
	for key: String in keys:
		var bits: PackedStringArray = key.split(":")
		var info: PartLibrary.PartInfo = library.parts.get(bits[0])
		lines.append("  %d x %s (%s) in %s (%s)" % [int(tally[key]), bits[0],
			info.name if info != null else "?", _colour_name(int(bits[1])), bits[1]])
	lines.append("")
	lines.append("Each, by number:")
	lines.append_array(rows)
	if ids.size() > rows.size():
		lines.append("  ... and %d more: look_at_model with where= the room lists them."
			% (ids.size() - rows.size()))
	lines.append("")
	var allowed: bool = focus.region.size.x > focus.box.size.x \
		+ SelectionScope.MARGIN.x * 2.0 + 0.5
	lines.append("The room a change may use: %s — %s. %s" % [
		_box_words(focus.region),
		"their box and the room the person allowed" if allowed
			else "their box, two studs round it and three plates above and below",
		"%d other part%s stand%s in it, not selected: change them only if the request needs it."
			% [others, "" if others == 1 else "s", "s" if others == 1 else ""]
			if others > 0 else "Nothing else stands in it."])
	lines.append(FOCUS_RULES)
	var frames: String = _sections_said(read, laid_in)
	if not frames.is_empty():
		lines.append("")
		lines.append(frames)
	lines.append("")
	lines.append(_open_said(read.points_of(ids)))
	var weak: String = _focus_stability()
	if not weak.is_empty():
		lines.append("")
		lines.append(weak)
	return "\n".join(lines)


## The sections the selection is laid in, said so a part can be put down
## in one: its name, where it stands and how it is turned.
func _sections_said(read: OpenPoints, laid_in: Dictionary) -> String:
	if laid_in.is_empty():
		return ""
	var said := PackedStringArray()
	for name: String in laid_in:
		var section: Section = read.model.sections.get(name)
		if section == null:
			continue
		said.append("  '%s' (%d of them): its origin at x=%s y=%s z=%s, %s"
			% [name, int(laid_in[name]), Placement._num(section.x), Placement._num(section.y),
				Placement._num(section.z), section.said()])
	return ("Some are laid turned, in a section, and are given above in that section's own "
		+ "studs and plates. A part put down among them takes the same section= and its "
		+ "x, y, z in those coordinates; nothing else about the section needs saying, and a "
		+ "new section at a near angle would not meet them:\n" + "\n".join(said))


## The selection's open connection points, counted by the way they face,
## with one of each kind to start from; where_to_attach lists them all.
func _open_said(points: Array) -> String:
	var groups: Dictionary = {}    ## heading and kind -> [count, first point]
	var taken: int = 0
	for point: OpenPoints.Point in points:
		if point.by != 0:
			taken += 1
			continue
		var key: String = "%s|%s" % [OpenPoints.NAMES[point.kind], OpenPoints.heading(point)]
		if not groups.has(key):
			groups[key] = [0, point]
		groups[key][0] = int(groups[key][0]) + 1
	if groups.is_empty():
		return ("Open connection points: none — every stud and hollow of the selection "
			+ "has something on it (%d taken). A part added has to replace one, or join "
			% taken + "what stands round it.")
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(groups[a][0]) > int(groups[b][0]))
	var said := PackedStringArray()
	for key: String in keys.slice(0, 8):
		var first: OpenPoints.Point = groups[key][1]
		said.append("  %d free %s%s %s, e.g. on #%d (%s) at %s" % [int(groups[key][0]),
			key.get_slice("|", 0), "" if int(groups[key][0]) == 1 else "s",
			key.get_slice("|", 1), first.brick, first.part, OpenPoints.where_of(first)])
	if keys.size() > 8:
		said.append("  ...and %d more kinds." % (keys.size() - 8))
	return ("Open connection points of the selection (%d taken by the parts on them):\n"
		% taken + "\n".join(said) + "\nwhere_to_attach lists every one with a picture of "
		+ "them numbered; given part=, it seats that part on them, tries each against the "
		+ "model as it stands, and gives the placements that fit and hold, to put in "
		+ "edit_selection's add as they are.")


## How the joints in and round the selection stand, from the same judge as
## Tools, Check stability: what "why is this not stable" is asking.
func _focus_stability() -> String:
	if builder == null or world.brick_count() > 1500:
		return ""
	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	judge.floor_ids = scenery
	var report: Stability.Report = judge.check(world)
	var near := PackedStringArray()
	for risk: Stability.Risk in report.risks:
		var brick: BrickWorld.Brick = world.get_brick(risk.brick_id)
		if brick == null:
			continue
		if focus.ids.has(risk.brick_id) or focus.holds(
				SelectionScope.box_of(brick.part_id, brick.transform, library)):
			near.append("  #%d: %s" % [risk.brick_id, risk.message])
	if near.is_empty():
		return ("Its joints: %s, and nothing in or round the selection is weak."
			% report.summary())
	return "Weak joints in or round the selection (%s):\n%s" % [report.summary(),
		"\n".join(near.slice(0, 6))]


## Set while a check asks what holds a part from the ground alone, not
## excusing the parts that were standing before (see [method _left_hanging]).
var _ground_only: bool = false
## What held before an edit about a selection, by the world's revision:
## [revision, brick ids hanging already, pieces].
var _hanging_before: Array = []
var _hanging_after: Array = []


## What an edit leaves hanging that was held: a check excuses what already
## stood, because a fault it found standing is not the design's to answer
## for, and so it never asked whether taking a part out from under the rest
## leaves the rest in the air. A selection's change is checked for exactly
## that, against how the model stood before it: a part that hung already
## (the example car's tyres sit below the ground) is still not its fault.
## And for the model coming apart: more pieces than it was in.
func _left_hanging(edited: Model) -> String:
	_ground_only = true
	if _hanging_before.size() != 3 or int(_hanging_before[0]) != world.revision:
		var now: Model = _model_from_world()
		var was: Dictionary = await _checked(now, true)
		var ids: Dictionary = {}
		for index: Variant in was.get("floating", []):
			ids[now.placements[int(index)].id] = true
		_hanging_before = [world.revision, ids, int(was.get("pieces", 1))]
	var after: Dictionary = await _checked(edited, true)
	_ground_only = false
	# What holds after it, kept for the next edit once this one lands: on
	# the shipped Orthanc's 9,400 parts a check is ten seconds.
	var hanging: Dictionary = {}
	for index: Variant in after.get("floating", []):
		var one: Placement = edited.placements[int(index)]
		if one.id != 0:
			hanging[one.id] = true
	_hanging_after = [hanging, int(after.get("pieces", 1))]
	var newly := PackedStringArray()
	for index: Variant in after.get("floating", []):
		var placement: Placement = edited.placements[int(index)]
		if placement.id != 0 and not (_hanging_before[1] as Dictionary).has(placement.id):
			newly.append("#%d (%s)" % [placement.id, placement.part])
	if not newly.is_empty():
		return ("it leaves %s with nothing holding %s up. Everything it stands on "
			% [", ".join(newly.slice(0, 8)), "it" if newly.size() == 1 else "them"]
			+ "or under has to stay, or be replaced by something that holds it.")
	var pieces: int = int(after.get("pieces", 1))
	if pieces > int(_hanging_before[2]):
		return ("it leaves the model in %d pieces where it was in %d: what it took "
			% [pieces, int(_hanging_before[2])] + "out was joining them.")
	return ""


## A box in LDU as studs and plates, the way a session writes one.
static func _box_words(box: AABB) -> String:
	var low: Vector3 = box.position
	var high: Vector3 = box.end
	return "x %s..%s, z %s..%s studs, y %s..%s plates" % [
		Placement._num(snappedf(low.x / STUD, 0.1)), Placement._num(snappedf(high.x / STUD, 0.1)),
		Placement._num(snappedf(low.z / STUD, 0.1)), Placement._num(snappedf(high.z / STUD, 0.1)),
		Placement._num(snappedf(low.y / PLATE, 0.1)), Placement._num(snappedf(high.y / PLATE, 0.1))]


## edit_selection: edit_model, kept to the selection's room, asking the
## person first for any more room it says it needs.
func _edit_selection(args: Dictionary) -> Variant:
	var selected: Array = builder.selection.keys() if builder != null else []
	if not _focus_alive():
		var why: String = focus_on(selected)
		if not why.is_empty():
			return why
	var input: Dictionary = args.duplicate(true)
	var room: AABB = _box_from(input.get("room"))
	var reason: String = str(input.get("why", "")).strip_edges()
	var trial: bool = bool(input.get("check_only", false))
	input.erase("room")
	input.erase("why")
	input.erase("check_only")
	if room.has_volume() and not focus.region.encloses(room):
		progress.emit("asking for more room than the selection")
		if not await _ask_for_room(room, reason):
			return ("Not applied — the person did not give that room (%s). Keep the "
				% _box_words(room) + "change inside %s, or say in words what it "
				% _box_words(focus.region) + "would need and why.")
		focus.allow(room)
	var was: bool = _scoped
	_scoped = true
	_trial_only = trial
	var answer: Variant = await _run_tool({"name": "edit_model", "input": input})
	_trial_only = false
	_scoped = was
	return answer


## Set while edit_selection only tries a change (check_only): it is
## checked as it would be, and then not made.
var _trial_only: bool = false

## Free points listed and numbered on the picture, at most.
const MOST_POINTS := 40
## Placements where_to_attach gives when not told how many.
const MOST_FITS := 8


## where_to_attach: the selection's connection points, the free ones
## numbered by the way they face and on a picture, and, given a part, the
## placements of it on them that fit and hold where the model stands.
func _where_to_attach(args: Dictionary) -> Variant:
	var selected: Array = builder.selection.keys() if builder != null else []
	if not _focus_alive():
		var why: String = focus_on(selected)
		if not why.is_empty():
			return why
	var read: OpenPoints = OpenPoints.read(self)
	var all: Array[OpenPoints.Point] = read.points_of(focus.ids.keys())
	var wanted_kind: String = str(args.get("kind", "")).strip_edges()
	var free: Array = []
	var taken: int = 0
	for point: OpenPoints.Point in all:
		if not wanted_kind.is_empty() and OpenPoints.NAMES[point.kind] != wanted_kind:
			continue
		if point.by != 0:
			taken += 1
		else:
			free.append(point)
	# Best first: facing the way asked, then nearest the place asked.
	var toward: String = str(args.get("toward", "any"))
	var near := Vector3.INF
	if args.get("near") is Dictionary:
		var at: Dictionary = args["near"]
		near = Vector3(float(at.get("x", 0)) * STUD, float(at.get("y", 0)) * PLATE,
			float(at.get("z", 0)) * STUD)
	var middle: Vector3 = _middle_of_model()
	var score := func(point: OpenPoints.Point) -> float:
		var facing: float = 0.0
		if toward == "out":
			var out := Vector3(point.at.x - middle.x, 0.0, point.at.z - middle.z)
			facing = point.way.dot(out.normalized()) if out.length() > 0.1 else 0.0
		elif FACES.has(toward):
			facing = point.way.dot(FACES[toward])
		var far: float = 0.0 if near == Vector3.INF else point.at.distance_to(near) / STUD
		return facing * 100.0 - far
	free.sort_custom(func(a: OpenPoints.Point, b: OpenPoints.Point) -> bool:
		return score.call(a) > score.call(b))
	var shown: Array = free.slice(0, MOST_POINTS)
	for n: int in shown.size():
		(shown[n] as OpenPoints.Point).number = n + 1
	var lines := PackedStringArray()
	lines.append("The selection's open connection points%s: %d free, %d taken by the parts on them."
		% ["" if wanted_kind.is_empty() else " (%ss)" % wanted_kind, free.size(), taken])
	if free.is_empty():
		lines.append("Nothing is free. A part added has to replace one that is there, or "
			+ "join what stands round the selection.")
	# Grouped by kind and the way they face, in the order they were ranked.
	var groups: Dictionary = {}
	var order: Array = []
	for point: OpenPoints.Point in shown:
		var heading: String = "%ss %s" % [OpenPoints.NAMES[point.kind], OpenPoints.heading(point)]
		if not groups.has(heading):
			groups[heading] = []
			order.append(heading)
		(groups[heading] as Array).append(point)
	for heading: String in order:
		var group: Array = groups[heading]
		var first: OpenPoints.Point = group[0]
		var section: String = "" if first.section.is_empty() \
			else ", section='%s'" % first.section
		var takes: String = ""
		if first.kind == "stud":
			takes = " — a part put on one takes face=%s%s" % [first.face, section]
		elif first.kind == "anti-stud":
			takes = " — a part put under one, its stud in it, takes face=%s%s" % [
				OpenPoints.nearest_face(-(FACES[first.face] as Vector3)), section]
		lines.append("")
		lines.append("%d %s%s:" % [group.size(), heading, takes])
		for point: OpenPoints.Point in group:
			lines.append("  [%d] %s on #%d (%s) at %s" % [point.number,
				OpenPoints.NAMES[point.kind], point.brick, point.part, OpenPoints.where_of(point)])
	if free.size() > shown.size():
		lines.append("  ...and %d more; toward= or near= puts others first." % (
			free.size() - shown.size()))
	var part_id: String = str(args.get("part", "")).strip_edges()
	if not part_id.is_empty():
		lines.append("")
		lines.append(await _fits_said(read, shown, part_id, args))
	if not ModelShot.possible() or shown.is_empty():
		return "\n".join(lines)
	var marks: Array = []
	for point: OpenPoints.Point in shown:
		marks.append([point.at, point.number])
	_ensure_shot().highlight = focus.ids.duplicate()
	_shot.marks = marks
	var from: String = _facing_view(shown)
	var image: Image = await _shot.take(world, from, scenery, focus.region)
	_shot.marks = []
	_shot.highlight = {}
	if image == null:
		return "\n".join(lines)
	var picture: Dictionary = await _shot.encode(image)
	if picture.is_empty():
		return "\n".join(lines)
	return [{"type": "text", "text": "\n".join(lines)},
		{"type": "text", "text": ("The selection's room from the %s, the selection in magenta and "
			+ "its free points numbered in cyan as listed (a number may be on the far side of "
			+ "what it is drawn over):") % from}, picture]


## A part's geometry, fetched and waited for where the build does not carry
## it (the web), as the Working bar says; null if it never comes. Awaited.
func _geometry_of(part_id: String) -> Lbm.PartMesh:
	if library.mesh_for(part_id) == null:
		var model := Model.new()
		var one := Placement.new()
		one.part = part_id
		model.placements.append(one)
		await _ensure_parts(model)
	return library.mesh_for(part_id)


## [param part_id] seated on the points given, best first: each tried as
## the check would try it, so what is listed fits and holds as it stands.
func _fits_said(read: OpenPoints, points: Array, part_id: String, args: Dictionary) -> String:
	if not library.parts.has(part_id):
		return "No part '%s' exists; search_parts finds one." % part_id
	if await _geometry_of(part_id) == null:
		return "The geometry for %s could not be fetched; ask again." % part_id
	var most: int = clampi(int(args.get("limit", MOST_FITS)), 1, 30)
	var fits := PackedStringArray()
	var tried: int = 0
	# Each tried with those before it standing, so the list goes down
	# together: offered one by one, the second spike on a horn was refused
	# for running into the first.
	var together: Array = []
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	for point: OpenPoints.Point in points:
		if point.kind != "stud" and point.kind != "anti-stud":
			continue
		tried += 1
		var colour: int = int(args.get("color", world.get_brick(point.brick).color_code))
		var found: Array[Placement] = read.fits_on(point, part_id, colour, {}, focus.region, 4,
			together)
		if found.is_empty():
			continue
		together.append([-(together.size() + 1), mesh, read.world_of(found[0], mesh)])
		var turns := PackedStringArray()
		for other: Placement in found:
			if other.rot != found[0].rot and not turns.has(str(other.rot)):
				turns.append(str(other.rot))
		fits.append("  %s — on [%d], the %s of #%d (%s)%s" % [OpenPoints.as_json(found[0]),
			point.number, OpenPoints.NAMES[point.kind], point.brick, point.part,
			"" if turns.is_empty() else "; turned on it, rot=%s fits too" % ", ".join(turns)])
		if fits.size() >= most:
			break
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if fits.is_empty():
		return ("%s (%s) fits on none of the %d studs and hollows tried: each would run "
			% [part_id, info.name if info != null else "?", tried]
			+ "into something or hold by nothing. Try a smaller part, other points (toward=, "
			+ "near=), or take off what is in the way in the same edit.")
	return ("%s (%s), seated on the points above and tried against the model as it stands "
		% [part_id, info.name if info != null else "?"]
		+ "(nothing in the way, inside the room, holding by the stud it is on), each with "
		+ "the ones before it, so all of them go down together. Put them in "
		+ "edit_selection's add as they are:\n" + "\n".join(fits))


## The middle of the model, for which way is out.
func _middle_of_model() -> Vector3:
	var middle := Vector3.ZERO
	var count: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		middle += brick.transform.origin
		count += 1
	return middle / maxf(1.0, float(count))


## The named view that faces most of these points.
static func _facing_view(points: Array) -> String:
	var best: String = "corner"
	var most: float = -INF
	for name: String in ["corner", "far corner", "front", "back", "left", "right", "top"]:
		var from: Vector3 = (ModelShot.ANGLES[name] as Vector3).normalized()
		var seen: float = 0.0
		for point: OpenPoints.Point in points:
			seen += maxf(0.0, point.way.dot(from))
		if seen > most + 0.01:
			most = seen
			best = name
	return best


## Why a change about the selection was refused, part by part, and the
## nearest place each refused part does fit and hold, tried on the model as
## it stands (OpenPoints): a refusal that says where instead costs no
## second guess. Empty when nothing it put down or moved is to blame.
func _what_would_fit(edited: Model, verdict: Dictionary) -> String:
	var overlapping: Dictionary = verdict.get("overlapping", {})
	var troubled: Dictionary = {}    ## index -> what is wrong with it
	for raw: Variant in overlapping:
		var index: int = int(raw)
		# Numbered in the model checked, which is this one unless dressing
		# gave way and it was checked again without it.
		if index >= edited.placements.size():
			continue
		var placement: Placement = edited.placements[index]
		var key: int = int(overlapping[raw])
		# Laid in model order, a part already standing can be the one told
		# it overlaps what the edit puts down: the edit's part is to blame.
		if placement.id != 0 and not placement.moved and key > 0 \
				and key - 1 < edited.placements.size():
			var other: Placement = edited.placements[key - 1]
			if other.id == 0 or other.moved:
				troubled[key - 1] = ["overlap", index + 1]
				continue
		troubled[index] = ["overlap", key]
	for raw: Variant in verdict.get("floating", []):
		if not troubled.has(int(raw)) and int(raw) < edited.placements.size():
			troubled[int(raw)] = ["floating", 0]
	var read: OpenPoints = null
	var skip: Dictionary = {}
	var also: Array = []
	var free: Array = []
	var lines := PackedStringArray()
	var order: Array = troubled.keys()
	order.sort()
	for index: int in order:
		var placement: Placement = edited.placements[index]
		if placement.id != 0 and not placement.moved:
			continue
		if lines.size() >= 6:
			lines.append("  ...and %d more like that." % (order.size() - lines.size()))
			break
		if read == null:
			read = OpenPoints.read(self)
			# What the edit takes off or moves is not in the way, and what
			# it puts down or moves is in the way of the rest of it.
			var kept: Dictionary = {}
			for one: Placement in edited.placements:
				if one.id != 0:
					kept[one.id] = one
			for brick: BrickWorld.Brick in world.bricks():
				var one: Placement = kept.get(brick.id)
				if not scenery.has(brick.id) and (one == null or one.moved):
					skip[brick.id] = true
			for n: int in edited.placements.size():
				var one: Placement = edited.placements[n]
				var mesh: Lbm.PartMesh = library.mesh_for(one.part)
				if mesh != null and (one.id == 0 or one.moved):
					also.append([-(n + 1), mesh, _transform(one, mesh, edited.section_for(one)), n])
		var others: Array = also.filter(func(one: Array) -> bool: return int(one[3]) != index)
		var what: String = "the %s at x=%s y=%s z=%s face=%s%s" % [placement.part,
			Placement._num(placement.x), Placement._num(placement.y), Placement._num(placement.z),
			placement.face, "" if placement.section.is_empty()
				else " in section '%s'" % placement.section]
		var trouble: Array = troubled[index]
		var said: String
		if str(trouble[0]) == "overlap":
			said = "%s runs into %s" % [what, _key_words(int(trouble[1]), edited)]
		else:
			said = ("nothing holds %s: no stud of it reaches into a part, none reaches into it, "
				% what + "and no pin or clip joins it")
		var fix: Placement = read.nearest_fit(placement, skip, others, focus.region)
		if fix != null:
			lines.append("  - %s. It fits and holds %s: %s" % [said,
				_moved_by_words(placement, fix), OpenPoints.as_json(fix)])
			continue
		if free.is_empty():
			var near: Array = []
			for brick: BrickWorld.Brick in world.bricks():
				if not scenery.has(brick.id) and not skip.has(brick.id) and focus.holds(
						SelectionScope.box_of(brick.part_id, brick.transform, library)):
					near.append(brick.id)
			for point: OpenPoints.Point in read.points_of(near):
				if point.by == 0 and (point.kind == "stud" or point.kind == "anti-stud"):
					free.append(point)
		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		var here: Vector3 = (_transform(placement, mesh, edited.section_for(placement))
			* mesh.bounds).abs().get_center() if mesh != null else Vector3.ZERO
		free.sort_custom(func(a: OpenPoints.Point, b: OpenPoints.Point) -> bool:
			return a.at.distance_squared_to(here) < b.at.distance_squared_to(here))
		var seated: String = ""
		for point: OpenPoints.Point in free.slice(0, 40):
			var found: Array[Placement] = read.fits_on(point, placement.part, placement.color,
				skip, focus.region, 1)
			if not found.is_empty():
				seated = "the nearest free %s it fits on is on #%d (%s), %s studs away: %s" % [
					OpenPoints.NAMES[point.kind], point.brick, point.part,
					Placement._num(snappedf(point.at.distance_to(here) / STUD, 0.1)),
					OpenPoints.as_json(found[0])]
				break
		lines.append("  - %s. Nothing within a stud of there fits; %s" % [said,
			seated if not seated.is_empty() else "nor does it fit on any free stud of the room "
				+ "near it, so take off what is in the way in the same edit, or use a "
				+ "smaller part"])
	if lines.is_empty():
		return ""
	return ("\n\nPart by part, and the nearest place each fits and holds (tried on the model "
		+ "as it stands, with the rest of this change; nothing else needs to move):\n"
		+ "\n".join(lines))


## What a key from a check names, in words: a part of the edit, or one
## standing, by its number.
func _key_words(key: int, edited: Model) -> String:
	if key > 0 and key - 1 < edited.placements.size():
		var other: Placement = edited.placements[key - 1]
		if other.id != 0 and not other.moved:
			return "#%d (%s)" % [other.id, other.part]
		return "the %s this change puts at x=%s y=%s z=%s" % [other.part,
			Placement._num(other.x), Placement._num(other.y), Placement._num(other.z)]
	return "a part already standing"


## How a placement moved to where it fits, in its own frame's words.
static func _moved_by_words(was: Placement, now: Placement) -> String:
	var said := PackedStringArray()
	for axis: Array in [["y", now.y - was.y, "plate", "up", "down"],
			["x", now.x - was.x, "stud", "+x", "-x"], ["z", now.z - was.z, "stud", "+z", "-z"]]:
		var by: float = float(axis[1])
		if is_zero_approx(by):
			continue
		var amount: String = Placement._num(absf(snappedf(by, 0.01)))
		said.append("%s %s%s %s" % [amount, axis[2], "" if absf(by) <= 1.0 else "s",
			axis[3] if by > 0.0 else axis[4]])
	return " and ".join(said) if not said.is_empty() else "where it is"


## Ask the person for more room, and wait for their answer. False when
## nobody is there to ask, or they say no, or they do not answer in time.
func _ask_for_room(room: AABB, why: String) -> bool:
	if room_asked.get_connections().is_empty():
		return false
	_room_answer = -1
	room_asked.emit(why if not why.is_empty() else "it needs more room than the selection",
		_box_words(room.merge(focus.region)))
	var until: int = Time.get_ticks_msec() + int(room_wait_s * 1000.0)
	while _room_answer < 0 and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	var yes: bool = _room_answer == 1
	_room_answer = -1
	return yes


## The person's answer to [signal room_asked].
func answer_room(yes: bool) -> void:
	_room_answer = 1 if yes else 0


## What an edit about the selection changes outside its room, said: empty
## when it all keeps inside.
func _beyond_focus(edited: Model) -> PackedStringArray:
	var out := PackedStringArray()
	var kept: Dictionary = {}
	for placement: Placement in edited.placements:
		if placement.id != 0:
			kept[placement.id] = placement
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var placement: Placement = kept.get(brick.id)
		var did: String = ("takes off" if placement == null
			else "swaps" if placement.part != brick.part_id
			else "moves" if placement.moved
			else "paints" if placement.color != brick.color_code else "")
		if did.is_empty():
			continue
		var was_at: AABB = SelectionScope.box_of(brick.part_id, brick.transform, library)
		if not focus.holds(was_at):
			out.append("it %s #%d (%s), which stands at %s" % [did, brick.id,
				brick.part_id, _box_words(was_at)])
			continue
		if placement != null and placement.moved:
			var to: AABB = _placement_box(placement, edited)
			if to.has_volume() and not focus.holds(to):
				out.append("it moves #%d (%s) out to %s" % [brick.id, brick.part_id,
					_box_words(to)])
	for placement: Placement in edited.placements:
		if placement.id != 0:
			continue
		var at: AABB = _placement_box(placement, edited)
		if at.has_volume() and not focus.holds(at):
			out.append("it puts a %s down at %s" % [placement.part, _box_words(at)])
	return out


func _placement_box(placement: Placement, model: Model) -> AABB:
	var part: Lbm.PartMesh = library.mesh_for(placement.part)
	if part == null:
		return AABB()
	return SelectionScope.box_of(placement.part,
		_transform(placement, part, model.section_for(placement)), library)


func _refused_beyond(beyond: PackedStringArray) -> String:
	var listed := PackedStringArray()
	for said: String in beyond.slice(0, 8):
		listed.append("  - " + said)
	if beyond.size() > 8:
		listed.append("  ...and %d more like that." % (beyond.size() - 8))
	return ("Not applied — that reaches outside the room the selection gives "
		+ "(%s):\n%s\nEverything outside it stays as it is. Keep the change "
		% [_box_words(focus.region), "\n".join(listed)]
		+ "inside it; or, if the request cannot be met without more, give "
		+ "edit_selection room= the box it needs and why=, and the person is asked.")


## An edit about the selection has landed: its changes made one step of
## the history (with whatever else this request changed before it), new
## parts put in the selection's sub-assembly, the selection now what it
## became.
func _gather_focus_step(was: Dictionary) -> String:
	var steps: Array = SelectionScope.steps_back(was, world, scenery)
	if steps.is_empty():
		return ""
	for step: Dictionary in steps:
		var kind: String = str(step.get("undo", ""))
		if kind == "remove":
			var brick: BrickWorld.Brick = world.get_brick(int(step["brick"]))
			if brick != null:
				focus.ids[brick.id] = true
				# As Builder.set_path puts it, which cannot be called by the
				# class's name: that is the Script, whose own set_path
				# (Resource's, one argument) answers, and the call failed,
				# so a part put down in a sub-assembly was left out of it.
				if not focus.path.is_empty() and brick.group.is_empty() \
						and brick.unit.is_empty():
					brick.unit = focus.path
					brick.group = Assemblies.group_of(focus.path)
		elif kind == "add" and step.has("was"):
			focus.ids.erase(int(step["was"]))
	focus.changed += steps.size()
	var words: String = SelectionScope.words_for(steps)
	# Every other copy of the sub-assembly it was made in follows it, as
	# it does a change made by hand, in the same undo step. Asked about one
	# of a model's two wings, the other stayed as it was.
	var followed: Array = [[], 0]
	if assemblies != null:
		followed = assemblies.copies_follow(builder.touched_groups(
			{"undo": "group", "steps": steps}))
	focus.followed = int(followed[1])
	var own: Array = steps
	steps = steps + (followed[0] as Array)
	if not focus.step.is_empty() and is_same(builder.last_step(), focus.step):
		focus.own_steps = own + focus.own_steps
		focus.step["steps"] = steps + (focus.step["steps"] as Array)
		focus.step["words"] = "Claude's change to the selection (%s)" \
			% SelectionScope.words_for(focus.own_steps)
	else:
		focus.own_steps = own
		builder.record(steps, "Claude's change to the selection (%s)" % words)
		focus.step = builder.last_step()
	if focus.followed > 0:
		var named: String = Assemblies.definition(Assemblies.leaf(focus.path))
		words += "; %d other cop%s of %s followed it" % [focus.followed,
			"y" if focus.followed == 1 else "ies",
			"its sub-assembly" if named.is_empty() else "\"%s\"" % named]
		assemblies.changed.emit()
	builder.selection = focus.ids.duplicate()
	builder.selection_changed.emit(builder.selection.size())
	return words


## The answer to an edit about the selection: what it changed, and the
## room as it now is in its own colours, the picture the panel shows
## beside the one from before.
func _focus_answer(said: String, words: String) -> Variant:
	var after: Image = null
	if ModelShot.possible():
		_ensure_shot().highlight = {}
		after = await _shot.take(world, "corner", scenery, focus.region)
	focus_edited.emit(words, focus.before, after)
	var numbers := PackedStringArray()
	for brick_id: Variant in focus.ids:
		numbers.append(str(brick_id))
	var text: String = ("%s Changed: %s. One undo takes the whole request back. "
		% [said, words] + "The selection is now #%s." % ", #".join(numbers))
	if after == null:
		return text + "\n\n" + _measured()
	var picture: Dictionary = await _shot.encode(after)
	if picture.is_empty():
		return text
	return [{"type": "text", "text": text},
		{"type": "text", "text": "The selection's room now, from the corner, in its own colours:"},
		picture,
		{"type": "text", "text": "Is that what the person asked for? If not, change it "
			+ "again; if so, say so in a sentence."}]


## The app's own loop, asked about the selection in [member focus] (set by
## [method focus_on]). A second request about the same selection carries
## the conversation on.
func about_selection(text: String) -> bool:
	if _busy or not _focus_alive():
		return false
	if not (_scoped_talk and has_conversation()):
		_messages.clear()
	_scoped = true
	_scoped_talk = true
	focus.step = {}
	_start(text)
	return true


## What a run about the selection opens with: the selection, and the
## request.
func _focus_opening(text: String) -> Array:
	var said: Variant = await selection_said()
	var opening: Array = []
	if said is Array:
		opening.append_array(said as Array)
	else:
		opening.append({"type": "text", "text": str(said)})
	opening.append({"type": "text", "text": FOCUS_TASK})
	opening.append({"type": "text", "text": "The person asks: " + text})
	return opening


## The brief a session started for the person is given, when they asked
## about a selection: it reads the selection itself.
static func selection_brief(text: String, count: int) -> String:
	return ("In Brickworks the person has selected %d part%s of their model and asks "
		% [count, "" if count == 1 else "s"]
		+ "about them: \"%s\"\n\nCall selection first: it lists those parts by " % text
		+ "number, where they stand and the room a change may use, with pictures. "
		+ "where_to_attach then gives their open studs, and with part= placements on "
		+ "them that fit and hold. Make the change with edit_selection, which keeps to "
		+ "that room: everything else in the model stays where it is and must stay "
		+ "joined; a refusal says where each refused part would fit instead. Make it "
		+ "plainly visible: a change the person has to look for is not the one asked for. "
		+ "Never submit_design or clear_model: they would replace the model. If it "
		+ "is a question, answer it in words. When it is done, say what changed in "
		+ "a sentence and stop.")


## What a tool that puts parts down unchecked says while a run is about a
## selection: nothing but edit_selection keeps to its room.
static func _not_while_scoped() -> String:
	return ("Not while changing the selection: this puts parts down without "
		+ "keeping to its room. Use edit_selection.")


## The two tools a session outside the app asks about a selection with.
func focus_tools() -> Array:
	var edit: Dictionary = {}
	for tool: Dictionary in _tools():
		if str(tool.get("name", "")) == "edit_model":
			edit = tool.duplicate(true)
	var schema: Dictionary = edit.get("input_schema", {"type": "object", "properties": {}})
	var box: Dictionary = {"type": "object", "properties": {}, "additionalProperties": false,
		"required": ["x_from", "x_to", "y_from", "y_to", "z_from", "z_to"],
		"description": ("more room than the selection gives, in studs and plates, "
			+ "when the change cannot be made inside it. The person is asked in the "
			+ "app, and the change goes ahead only if they say yes.")}
	for side: String in ["x_from", "x_to", "y_from", "y_to", "z_from", "z_to"]:
		(box["properties"] as Dictionary)[side] = {"type": "number"}
	(schema["properties"] as Dictionary)["room"] = box
	(schema["properties"] as Dictionary)["why"] = {"type": "string", "description":
		"why the change needs that room, in a sentence the person reads"}
	(schema["properties"] as Dictionary)["check_only"] = {"type": "boolean", "description":
		("try the change without making it: says whether it would be applied, or why "
			+ "not and the nearest place each refused part fits and holds")}
	return [
		{
			"name": "selection",
			"description": ("What the person has selected in Brickworks — the parts "
				+ "they mean by \"this\", \"these\" or \"the selected\": each by number "
				+ "with where it stands, their box, the sub-assembly they are in, the "
				+ "room a change about them may use, how the joints round them stand, "
				+ "and pictures with them picked out, close up and in the whole model. "
				+ "Call it whenever a request is about part of the model, then change "
				+ "that part with edit_selection."),
			"input_schema": {"type": "object", "properties": {},
				"additionalProperties": false},
		},
		{
			"name": "edit_selection",
			"description": ("Change the selected parts as edit_model does — take off, "
				+ "paint, move, put down — keeping to the selection's room: a change "
				+ "that reaches outside it is refused whole, and everything else in "
				+ "the model stays where it is. It is checked as any design is, so a "
				+ "change that would not hold together or leaves a part loose changes "
				+ "nothing, and the refusal says, part by part, what each ran into or "
				+ "why nothing holds it, and the nearest place it fits and holds. "
				+ "check_only=true tries a change without making it. Other copies of "
				+ "the sub-assembly follow the change. One undo takes the request back. "
				+ "For more room, give room= and why=: the person is asked first."),
			"input_schema": schema,
		},
		{
			"name": "where_to_attach",
			"description": ("Where the selected parts can take another part: every open "
				+ "stud, anti-stud (the hollow underneath that takes a stud), side stud, "
				+ "pin hole, bar and clip, grouped by the way it faces, each with the part "
				+ "that carries it and where it is in the coordinates edit_selection takes "
				+ "(a section's own, for parts laid turned), and a picture with the free "
				+ "ones numbered. Give part= (and color=) and it seats that part on them "
				+ "and tries each against the model as it stands: what comes back fits "
				+ "and holds, to put in edit_selection's add as it is. toward= puts first "
				+ "the points facing that way (out: away from the model's middle, for "
				+ "spikes or detail on an outer face); near= {x, y, z} those nearest a place."),
			"input_schema": {
				"type": "object",
				"properties": {
					"part": {"type": "string", "description":
						"a part to seat on the open points, e.g. 49668"},
					"color": {"type": "integer", "description":
						"its LDraw colour; the colour of the part it goes on when omitted"},
					"toward": {"type": "string",
						"enum": ["any", "out", "up", "down", "+x", "-x", "+z", "-z"]},
					"near": {"type": "object", "description": "studs and plates",
						"properties": {"x": {"type": "number"}, "y": {"type": "number"},
							"z": {"type": "number"}}},
					"kind": {"type": "string", "enum": ["stud", "anti-stud", "pin hole",
						"axle hole", "pin", "axle", "bar", "clip", "ball", "socket"]},
					"limit": {"type": "integer", "description":
						"how many placements of part to give; 8 when omitted"},
				},
				"additionalProperties": false,
			},
		},
	]


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
				"quarter turns about the face direction, 0-3; with axis, about that line"},
			"axis": {"type": "string", "enum": ["x", "-x", "y", "-y", "z", "-z"],
				"description": "for a pin, an axle, a gear, a bush or a beam put on "
					+ "a line: the way its axle, pin or hole runs. x, y and z are then "
					+ "where that joint's middle goes (the point attachment_points "
					+ "gives a hole or an axle), not the low corner, and face is "
					+ "not used."},
			"joint": {"type": "integer", "description": "with axis: which of the "
				+ "part's own holes, pins or axles goes there, numbered as "
				+ "attachment_points lists them; omit for the one at its middle"},
			"section": {"type": "string", "description":
				"the section this brick belongs to, if any. Its x, y "
				+ "and z are then that section's own coordinates, not "
				+ "the model's."},
			"yaw": {"type": "number", "description": "turn this one part off the "
				+ "grid, degrees about the upright (its +z swings towards +x), about "
				+ "its own corner; it becomes a section of one. Any angle."},
			"pitch": {"type": "number", "description": "and then lift its +z end, "
				+ "degrees. A part that leans must turn on a joint."},
			"roll": {"type": "number", "description": "and then lift its +x side, degrees"},
			"name": {"type": "string", "description": "a name for this part, which "
				+ "a later part attaches to it by: \"torso\" in \"torso.hinge[0]\""},
			"attach": {
				"type": "object",
				"description": "put it on another part connector to connector, "
					+ "instead of x, y, z, face and rot: the app works out the pose and "
					+ "seats it exactly, at any angle the joint turns to. How figures "
					+ "and small models are built: legs on hips, an arm on a shoulder, a "
					+ "hand on the arm, a wing on a hinge, a tail on a bar, a head on a "
					+ "neck. show_technique \"posed minifigure\" or \"limb on a clip\" is "
					+ "one written out; attachment_points lists a part's connectors.",
				"properties": {
					"to": {"type": "string", "description": "the part it goes on and "
						+ "that part's connector: \"torso.hinge[0]\" (a part named so "
						+ "before this one) or \"#41.stud[3]\" (a brick standing, by its "
						+ "number). Types: stud, open, hole, tube, post, axle, cross, pin, "
						+ "socket, bar, clip, hinge, ball, fixed; numbered from 0 in each "
						+ "type, as attachment_points lists them"},
					"by": {"type": "string", "description": "this part's own connector "
						+ "that goes there, as \"hinge[0]\"; leave out when only one fits"},
					"yaw": {"type": "number", "description": "degrees about the joint's "
						+ "axis: a hinge's or a clip's angle, an arm's swing, a turn on a "
						+ "stud or an axle"},
					"align": {"type": "array", "description": "[a direction of this part, "
						+ "one of the model's]: turn it about the joint until the first "
						+ "lies along the second, as [\"+z\", \"up\"] or [[0, 0, 1], [0, 1, "
						+ "0]], then yaw from there. On a ball it points that way whatever "
						+ "the ball's axis: [\"-x\", [0.94, -0.34, 0]] is out along x and "
						+ "20 degrees down"},
					"orient": {"type": "object", "description": "this part's whole turn "
						+ "in the model, as a section's yaw, pitch and roll: a ball takes "
						+ "any; a hinge, clip or axle only one that keeps its line; a fixed "
						+ "joint none.",
						"properties": {"yaw": {"type": "number"}, "pitch": {"type": "number"},
							"roll": {"type": "number"}},
						"additionalProperties": false},
					"flip": {"type": "boolean", "description": "an axle, bar or hinge "
						+ "joint the other way round, end for end"},
					"slide": {"type": "number", "description": "LDU along an axle's, a "
						+ "bar's or a pin's line"},
				},
				"required": ["to"],
				"additionalProperties": false,
			},
		},
		"required": ["part", "color"],
		"additionalProperties": false,
	}

	# A shape described rather than counted out.
	var pattern: Dictionary = {
		"type": "object",
		"properties": {
			"pattern": {"type": "string",
				"enum": ["repeat", "mirror", "fill", "rock", "studs_out", "prism",
					"round", "shape", "shell", "figure"],
				"description":
					"repeat: the bricks again, stepped each time. "
					+ "mirror: everything so far, reflected about a line "
					+ "— build one side and mirror it rather than "
					+ "writing both. fill: a footprint tiled with the "
					+ "largest plates that fit, or with rise 3 a wall "
					+ "of short bricks in a running bond — and with "
					+ "layers, a "
					+ "shrink and a wall it is a dome, a cone, a hull, "
					+ "a tube or a bowl in one object. rock: a crag in "
					+ "one object — courses stepping in unevenly towards "
					+ "a peak off the middle, faced with slopes, cheese "
					+ "slopes, pebbles and bare ledges in two greys; a "
					+ "different seed is a different rock. studs_out: a "
					+ "face built sideways in one object — courses of 1x1 "
					+ "bricks with a side stud, tied by plates, each stud "
					+ "carrying a tile, round tile, round plate or cheese "
					+ "slope laid on its side; the arithmetic of where a "
					+ "side stud is, done for you. prism: a many-sided "
					+ "shaft in one object — a tower, a pier, a turret of 5 "
					+ "to 16 sides, each face a bonded wall turned to its "
					+ "angle about the middle (at is the middle), grooved "
					+ "where the faces meet. round: anything round in "
					+ "section, in one object — a column, a rocket stage, a "
					+ "lighthouse, a silo, a boiler, a fuselage, a tree "
					+ "trunk — of the round parts sets use at each diameter "
					+ "(round bricks, cylinder halves, corner rounds tied by "
					+ "round plates), colour bands, cones, Technic struts "
					+ "and spokes up its stack, ending in a nose; upright "
					+ "or lying along x or z. shape: a body that is not a "
					+ "box, said as solids — a loft through cross-sections, "
					+ "an extruded side profile, a revolve, a box with "
					+ "rounded or cut corners and edges, an ellipsoid or "
					+ "dome — less any cuts, laid in the parts a builder "
					+ "would choose: bricks and plates inside, slopes and "
					+ "curved slopes fitted to the surface's fall, inverted "
					+ "slopes under it, wedge plates on a diagonal edge, "
					+ "round parts where a section is round, a side that "
					+ "curves up and down laid on its side on side studs, "
					+ "tiles on top, one half and its mirror; a car's body, "
					+ "a hull, a fuselage, an animal's body. Another shape "
					+ "standing on it keeps its studs there. shell: a dome or "
					+ "a ball bigger than a dish, in one object — twelve "
					+ "strips of flat panels on clip hinges round a ring, "
					+ "each band's panels sized to its round, the strips "
					+ "taking turns low and high so the high ones lap the "
					+ "low ones' edges, tapered with wedge plates, each band "
					+ "lapping the one above, under a dish; a ball hangs the "
					+ "same strips under the ring on a stand. Its bands are "
					+ "sections (\"shell 3.2\": strip 3, band 2) an edit "
					+ "can turn or repaint. figure: a character in one object, "
					+ "built as a set builds one — a person, a four-legged animal "
					+ "or a head on a neck, every limb, the head and the tail on "
					+ "a working joint (ball shoulders, a turning or ball neck, a "
					+ "tail on a bar), posed by words, sized and coloured as said, "
					+ "its parts named to build on and pose again."},
			"times": {"type": "integer", "description": "repeat: how many"},
			"step": {"type": "object", "description":
				"repeat: how far each copy moves, in studs and plates",
				"properties": {"x": {"type": "number"},
					"y": {"type": "number"}, "z": {"type": "number"}},
				"additionalProperties": false},
			"about": {"type": "string", "enum": ["x", "z"],
				"description": "mirror: which way the line runs"},
			"at": {"description":
				"mirror: the line to reflect about, in studs. fill, round: "
				+ "where the footprint's low corner sits, as {x, y, z} (a "
				+ "round lying along x or z: the low end of it, on the ground). "
				+ "shell: the middle of where it stands, {x, y, z}."},
			"kind": {"type": "string", "enum": ["dome", "ball", "person", "animal", "head"],
				"description": "shell: a dome on its ring, or a ball on a stand. figure: "
				+ "a person (a statue, a mascot, a robot), an animal on four legs, or a "
				+ "head on a neck"},
			"frame_color": {"type": "integer", "description":
				"shell: its ring, hinges and column (72 unless said)"},
			"shape": {"type": "string", "enum": ["rectangle", "ellipse"],
				"description": "fill: which footprint"},
			"solids": {"type": "array", "items": {"type": "object"}, "description":
				"shape: what it is made of, each an object naming one kind — "
				+ "{\"loft\": {...}}, {\"extrude\": {...}}, {\"revolve\": {...}}, "
				+ "{\"box\": {...}}, {\"ellipsoid\": {...}} or {\"dome\": {...}} — "
				+ "with its own \"color\" if it wants one (the last that holds a stud "
				+ "gives it its colour). Studs across and along, plates up, from at."},
			"cuts": {"type": "array", "items": {"type": "object"}, "description":
				"shape: solids taken away, said the same way: a cockpit, a doorway; "
				+ "\"keep\": true keeps the cut clear of every part."},
			"wheels": {"type": "array", "items": {"type": "number"}, "description":
				"shape: a car on its own wheels — studs along x of each axle's middle, "
				+ "under a body laid along x 6, 8, 10 or 12 studs across. Each axle is "
				+ "a wheel and tyre each side on a Technic axle through Technic bricks, "
				+ "on a chassis of plates under them from nose to tail; the body cut "
				+ "clear of each wheel's box stands on the bricks (its underside 5 "
				+ "plates up or lower over them) and the chassis, so the car is one "
				+ "piece on its wheels. wheel_color is the rims' colour."},
			"wheel_color": {"type": "integer", "description": "shape: the rims' colour"},
			"loft": {"type": "object", "description":
				"shape: {\"along\": \"x\" or \"z\", \"centre\": studs across "
				+ "(half the widest unless said), \"sections\": [{\"at\": studs along, "
				+ "\"width\": studs, \"height\": plates, \"bottom\": plates, "
				+ "\"round\": 0 a box to 1 an ellipse, \"keel\": 0 to 1, how far "
				+ "its lower half narrows to a V, \"offset\": studs across}, ...]} — "
				+ "the section between each two is in between; width 0 at an end is "
				+ "a point; \"screen\" as on an extrude."},
			"extrude": {"type": "object", "description":
				"shape: {\"along\": \"x\" or \"z\", \"from\": studs across, "
				+ "\"width\": studs, \"profile\": [[studs along, plates up], ...] "
				+ "its top seen from the side, \"under\": the same for its underside "
				+ "(0 unless said), \"round\": studs its top edges are rounded by, "
				+ "\"screen\": true where its front climbs to a roof as glass (a cabin, "
				+ "a cab, a cockpit) — a windscreen laid at that rake, the roof on its "
				+ "top studs; or {\"from\", \"to\": studs along, \"color\"}}. A cabin is "
				+ "its own profile on the body, its roof falling to the tail."},
			"revolve": {"type": "object", "description":
				"shape: {\"axis\": \"y\", \"x\" or \"z\", \"centre\": [x, y, z], "
				+ "\"profile\": [[along it (plates up y, studs along x or z), radius "
				+ "in studs], ...]}; along x or z, \"screen\" as on an extrude."},
			"box": {"type": "object", "description":
				"shape: {\"from\": [x, y, z], \"size\": [across, plates up, deep], "
				+ "\"round\": studs its plan corners are rounded by, \"chamfer\": "
				+ "studs they are cut by, \"edge\": studs its top edges are rounded "
				+ "by}."},
			"ellipsoid": {"type": "object", "description":
				"shape: {\"centre\": [x, y, z], \"radii\": [studs across, plates up, "
				+ "studs deep]}."},
			"dome": {"type": "object", "description":
				"shape: an ellipsoid's top half, said the same way."},
			"top": {"type": "string", "enum": ["smooth", "studs"], "description":
				"shape: tiles over its top (the default) or studs left showing."},
			"surface": {"type": "string", "enum": ["auto", "curved", "straight"],
				"description": "shape: curved slopes on its surface or straight ones; "
					+ "auto (the default) is curved if any solid is rounded."},
			"bands": {"type": "array", "items": {"type": "object"}, "description":
				"shape: [{\"from\": plates, \"to\": plates, \"color\"}] — a waterline, "
				+ "a stripe, a belly, by height."},
			"top_color": {"type": "integer", "description":
				"shape: the colour of its top tiles and slopes, if not its own."},
			"face": {"type": "object", "description":
				"shape: a face laid on a curved side, studs out — {\"facing\": "
				+ "\"+z\", \"x\", \"y\", \"z\": its middle, \"across\": 4, 6 or 8, "
				+ "\"color\": the disc, \"rim\": the plate behind it, \"eyes\": the "
				+ "iris, \"beak\": its colour or -1}: a round plate disc on side "
				+ "studs, two 2 x 2 round eyes with printed eye tiles, a beak."},
			"panels": {"type": "boolean", "description":
				"shape: its straight sides as tiles on bricks with side studs every "
				+ "other course (true, the default), or plain bricks (false)."},
			"across": {"type": "number", "description":
				"fill, rock: studs in x; shell: studs across over its panels, 20 to 32 (a "
				+ "ball 24 to 32)"},
			"deep": {"type": "number", "description": "fill, rock: studs in z"},
			"color": {"type": "integer", "description":
				"fill, rock, shell: the colour (rock: 72 if not said; shell: its panels, 71); "
				+ "figure: its clothes or its body"},
			"height": {"type": "number", "description":
				"rock: how tall, in plates. figure: a person's, feet to crown, 20 to 60 "
				+ "plates (34 and over at the larger size); a head's neck"},
			"length": {"type": "number", "description":
				"studs_out: studs along the face. figure: an animal's, nose to tail, 4 "
				+ "to 12 studs (7 and over at the larger size)"},
			"colors": {"type": "object", "description":
				"figure: colours by what they are, LDraw codes: skin, torso, legs, "
				+ "feet, hair, arms, head, seat (a person); body, legs, head, tail, eyes "
				+ "(an animal)"},
			"pose": {"type": "object", "description":
				"figure: {\"right arm\" and \"left arm\": down, bent, forward, raised, "
				+ "out, or [[out, up, forward] of the upper arm, the "
				+ "same of the forearm]; \"seated\": true sits a person on a seat of its "
				+ "own; \"head\": degrees it turns (an animal's: up, down, forward, left, "
				+ "right); \"tail\": raised, level, down}"},
			"name": {"type": "string", "description":
				"figure, shell: what its parts' names begin with, for a second one"},
			"courses": {"type": "number", "description":
				"studs_out: how many rows, each four plates tall; prism: "
				+ "how many courses of bricks, three plates each (with piers, left "
				+ "out for a display model's proportions, 3.3 times as tall as wide)"},
			"sides": {"type": "integer", "description": "prism: how many faces, 5-16"},
			"radius": {"type": "number", "description":
				"prism: studs from the middle to the outside of a face"},
			"thickness": {"type": "integer", "description":
				"prism: 2 (the default) closes the inside; 1 leaves slits at the corners"},
			"open": {"type": "integer", "description":
				"prism: faces left out at the back, so the rooms inside show; "
				+ "with piers, any number opens the core's whole back, the "
				+ "piers there left closed"},
			"windows": {"type": "boolean", "description":
				"prism: a few narrow windows up every other face, a storey "
				+ "apart, dark slits unless window_color says; none unless said"},
			"window_color": {"type": "integer", "description":
				"prism: the windows' colour (40, Trans-Brown, a dark slit, "
				+ "unless said)"},
			"plinth": {"type": "object", "description":
				"prism: {\"steps\": 1 to 4, \"out\": studs, \"stair\": true, \"rock\": true} — "
				+ "the tower raised on square terraces stepping down from its foot, two "
				+ "courses each, their tops tiled in the second tone up to its faces, "
				+ "with a stair cut into the front (+z) up to its door's level, and crags "
				+ "in its dark tones rising against it at their corners and sides (rock: "
				+ "false for none). The reply says the tower's foot (and add_rooms' y).",
				"properties": {
					"steps": {"type": "integer"},
					"out": {"type": "integer"},
					"stair": {"type": "boolean"},
					"rock": {"type": "boolean"}}},
			"storeys": {"type": "object", "description":
				"prism: {\"count\": 2 to 8, \"in\": studs} — the courses "
				+ "split into storeys, each in studs smaller than the one "
				+ "below (its piers drawn in with it) and standing on a ledge two "
				+ "plates thick in the second tone, only the top storey's "
				+ "piers rising into horns: a tower that steps in as it "
				+ "rises, not a shaft. The reply says the top's radius "
				+ "(for add_rooms) and its summit's y.",
				"properties": {
					"count": {"type": "integer"},
					"in": {"type": "integer"}}},
			"door": {"type": "boolean", "description":
				"prism: an arched door at the foot of the face looking +z, two "
				+ "studs wide and six courses tall, for a stair to lead up to; "
				+ "true unless said with piers, false unless said without"},
			"piers": {"type": "object", "description":
				"prism: faceted piers clustered round it, each a prism of its "
				+ "own built against the core, with a cleft between each two "
				+ "— a tower like Orthanc in one object. The core is capped "
				+ "with a summit two plates thick at y + 3 x courses, and "
				+ "piers taller than the core rise past it as horns: blades of "
				+ "plates on their side, cut by wedge plates, sweeping out and "
				+ "back in to a point (the reply says where the tips are).",
				"properties": {
					"count": {"type": "integer", "description": "how many, 2-8 (4)"},
					"sides": {"type": "integer", "description":
						"each pier's faces, 5-16 (the core's)"},
					"radius": {"type": "number", "description":
						"studs from a pier's middle to the outside of its faces "
						+ "(two thirds of the core's; smaller than keeps faces two "
						+ "studs wide at its sides, it is laid at that and said)"},
					"out": {"type": "number", "description":
						"studs from the core's middle to each pier's (set into "
						+ "the core by its wall's thickness)"},
					"courses": {"type": "number", "description":
						"how tall, in courses of three plates; more than the "
						+ "core's for horns (a fifth more; a blade rises at least "
						+ "two and a half times its width)"},
					"turn": {"type": "number", "description":
						"degrees round from +z to the first pier (between two "
						+ "faces, so there is a cleft front and back)"},
					"horns": {"type": "string", "enum": ["blade", "spire", "flat"],
						"description": "what piers taller than the core rise "
						+ "into: a blade (the default, as set 10237 builds "
						+ "Orthanc's), a square spire stepping in to a point, or "
						+ "flat, a turret's cap"},
					"flare": {"type": "number", "description":
						"blade: studs its sweep reaches out (half its width)"},
				},
				"additionalProperties": false},
			"facing": {"type": "string", "enum": ["+x", "-x", "+z", "-z"],
				"description": "studs_out: which way the face looks"},
			"face_color": {"type": "integer", "description":
				"studs_out: the colour of what is laid on the side studs"},
			"dress": {"type": "string", "enum": ["mixed", "tiles", "rivets", "round",
				"lights"], "description":
				"studs_out: what every side stud carries — a mix (the default), "
				+ "flat tiles for a smooth panel, round plates as rivets, round "
				+ "tiles as portholes, or lights (round tiles in a transparent "
				+ "face_color): a band of detail along a hull, a boiler, a wall"},
			"seed": {"type": "integer", "description":
				"rock: which rock — each number leans and wanders its own way"},
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
			"edge_color": {"type": "integer", "description":
				"fill: a second colour for the outside stud of every "
				+ "layer — hull plating, a trim, a kerb."},
			"mix_color": {"type": "integer", "description":
				"fill, rock: a second colour through some of its bricks, "
				+ "chosen by where they are, the same every time — a "
				+ "weathered wall. Real castle walls are 9-19% their "
				+ "second grey."},
			"band_color": {"type": "integer", "description":
				"fill with rise 3, prism: a course in this colour every "
				+ "eight, a string course where a storey's ledge is. A "
				+ "black wall gets dark bluish grey bands unless "
				+ "mix_color or this says otherwise."},
			"mix": {"type": "number", "description":
				"fill: the share in mix_color, up to 0.5; 0.15 if not "
				+ "said."},
			"sideways": {"type": "number", "description":
				"fill, prism: the share of its 1x2 bricks laid as two 1x1 bricks "
				+ "with a stud on the side, turned out and dressed with a "
				+ "tile, round tile, round plate or cheese slope on that "
				+ "stud, 0 to 0.5. For a wall one stud thick: a face built "
				+ "partly on its side, as real sets build them."},
			"masonry": {"type": "number", "description":
				"fill: the share of its 1x2 and 1x4 bricks laid as "
				+ "masonry bricks (98283, 15533), stonework facing away "
				+ "from the middle, 0 to 1. For a wall one stud thick."},
			"bricks": {"type": "array", "items": brick, "description":
				"repeat: what to repeat. mirror: what to reflect, if not "
				+ "everything so far."},
			"diameter": {"type": "integer", "enum": [1, 2, 4, 6, 8],
				"description": "round: studs across — the sizes round parts "
					+ "come in (at is the low corner of its square)"},
			"axis": {"type": "string", "enum": ["y", "x", "z"], "description":
				"round: y stands it up (the default); x or z lays it along "
				+ "that axis on the ground — a boiler, a fuselage, a hull, a log"},
			"stack": {"type": "array", "description":
				"round: what goes up the axis, bottom first, each square on "
				+ "the last. {\"plates\": N} a length of body (\"color\" a "
				+ "band of another colour, \"diameter\" wider or narrower, "
				+ "\"spokes\": 4 or 2 its top plate reaching a stud out with a "
				+ "\"tile\" on each reach — grid fins, gallery brackets, yard "
				+ "stubs); {\"cones\": 9 or 1} cones under a round plate "
				+ "(\"cone_color\") — nozzles, engine bells, lamps; "
				+ "{\"technic\": true, \"struts\": 0-4} a course with a pin "
				+ "hole out of each side and a Technic beam pinned on that "
				+ "many sides (\"strut_color\", \"strut_length\" in holes) — "
				+ "legs, stays; {\"nose\": cone, ogive, dome, point or flat} "
				+ "its top, and the end of the stack.",
				"items": {"type": "object"}},
			"beside": {"type": "object", "description":
				"round: more rounds standing round this one, touching it, "
				+ "pinned where their Technic courses meet (start both stacks "
				+ "the same, each with a technic course at one height): "
				+ "{\"count\": 2 or 4, \"diameter\", \"color\", \"stack\"}. "
				+ "Boosters on a core, twin funnels, a cluster of silos."},
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
			"yaw": {"type": "number", "description":
				"degrees about the upright: its +z (its nose) swings towards +x. "
				+ "Applied first."},
			"pitch": {"type": "number", "description":
				"then degrees its nose lifts. Yaw and pitch together face a "
				+ "panel any way round a dome and tip it to the curve."},
			"roll": {"type": "number", "description":
				"then degrees its +x side lifts"},
			"axis": {"type": "string", "enum": ["x", "y", "z"], "description":
				"or one turn about one pin: z tips it left and right, x forward "
				+ "and back, y swings it round. Applied after yaw, pitch and roll."},
			"line": {"type": "array", "items": {"type": "number"}, "description":
				"or the turn's axis as a direction [x, y, z], instead of axis"},
			"degrees": {"type": "number", "description":
				"how far it is turned about that axis or line. Any angle."},
			"within": {"type": "string", "description":
				"the section this one is built in: x, y, z (and its hinge's base) "
				+ "are then that section's own coordinates, and it goes where it "
				+ "goes. Panels hinged on panels, a chain round a dome."},
			"hinge": {"description":
				"turn it on a real joint, both halves laid for you: \"tilting\" "
				+ "(or true; 3937 under 3938, rests closed), \"clip\" (60478's bar "
				+ "in 63868's clip, rests in line), \"click\" (44302/44301, in "
				+ "line, where this build's parts have it). x, y, z are then where "
				+ "the base stands, like any brick, turned by yaw about its first "
				+ "stud; the section's bricks start at 0,0,0 on the top half's "
				+ "studs, its nose (+z) running away from the joint's line, and "
				+ "pitch lifts it about that line (or roll, with the line along "
				+ "z). A section that leans must turn on a joint; this is the "
				+ "one-line way.",
				"type": "string", "enum": ["tilting", "clip", "click"]},
			"hinge_color": {"type": "integer", "description":
				"the hinge's colour, if not 72"},
		},
		"required": ["name", "x", "y", "z"],
		"additionalProperties": false,
	}

	# The same, as an edit says it: a section already there needs only its
	# name and what changes.
	var section_change: Dictionary = section.duplicate(true)
	section_change["required"] = ["name"]

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
			"around": {"type": "object", "description":
				"{\"x\", \"z\"}: a centre, in the coordinates the section is "
				+ "built in. Each copy is carried round it by its yaw step, "
				+ "keeping its pitch and roll — a ring of panels round a dome.",
				"properties": {"x": {"type": "number"}, "z": {"type": "number"}}},
			"yaw": {"type": "number", "description":
				"degrees further round per copy (360 / how many in the ring)"},
			"pitch": {"type": "number", "description": "degrees more pitch per copy"},
			"roll": {"type": "number", "description": "degrees more roll per copy"},
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
				+ "guessing a part number. Printed parts are found by "
				+ "what is on them with the word print: \"porsche print\", "
				+ "\"control panel print\", \"3623 print\" (3623's prints); "
				+ "a part with a sticker on, with sticker."),
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
				+ "parts and whether it is one connected model, and weigh it: "
				+ "whether it stands (its centre of mass against the edge of "
				+ "what it stands on, in every pose its hinges and turntables "
				+ "reach), the counterweight that would hold it, and its most "
				+ "loaded stud joints. Safe to call on a partial design while "
				+ "you work."),
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
			"name": "read_guide",
			"description": ("A section of how to design in this app, in full: "
				+ "\"work\" (the process: silhouette, features, detail), \"rules\", "
				+ "\"shapes\" (the patterns that lay a wall, a dome, a tower, a "
				+ "hull or a car body), \"figures\" (a figure, a creature or a "
				+ "character: its head and limbs on joints), \"subject\" (what each "
				+ "kind of subject needs), \"angle\", \"pins\", \"colour\", \"creative\" "
				+ "and more. Read \"shapes\" before saying a shape, \"figures\" before "
				+ "building a figure or a creature."),
			"input_schema": {
				"type": "object",
				"properties": {
					"section": {"type": "string", "description":
						"work, rules, shapes, figures, subject, real, colour, angle, "
						+ "coordinates, sideways, pins, big, look, good, beautiful, creative, "
						+ "changing, kind or art"},
				},
				"required": ["section"],
				"additionalProperties": false,
			},
		},
		{
			"name": "show_technique",
			"description": ("How a construction is actually made, in "
				+ "part numbers and coordinates, most of them as the LEGO "
				+ "Group built them in real sets. By what they are for — %s. "
				% Techniques.listing()
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
			"name": "find_techniques",
			"description": ("How real LEGO® sets built a feature, found by "
				+ "what it is: the sub-assemblies of thousands of real sets "
				+ "(an owl's eye, a car's nose, a dragon's wing, a turret "
				+ "roof, a grille, a beak, a tree), each with a picture, its "
				+ "parts and colours, its size in studs, the set and modeller "
				+ "it is from, and an id for place_technique. Ask before "
				+ "inventing any feature of a face, a creature or a machine: "
				+ "a real designer's answer is better than a first guess. "
				+ "Name the subject too — \"owl eye\", \"car nose\" — and "
				+ "pieces from sets about it come first."),
			"input_schema": {
				"type": "object",
				"properties": {
					"query": {"type": "string", "description":
						"the feature, and the subject it is on: \"owl eye\", "
						+ "\"sports car front\", \"castle turret roof\""},
					"max_studs": {"type": "number", "description":
						"the most studs wide or deep it may be; leave out "
						+ "for any size"},
					"kinds": {"type": "array", "items": {"type": "string",
						"enum": ["sideways", "angled", "curved", "sloped",
							"brackets", "hinged", "textured", "smooth",
							"organic"]},
						"description": "only pieces built this way"},
				},
				"required": ["query"],
				"additionalProperties": false,
			},
		},
		{
			"name": "find_parts_like",
			"description": ("Parts by what they look like in a model, not by "
				+ "their catalogue name: \"feather\", \"claw\", \"exhaust\", "
				+ "\"eyelid\", \"scales\", \"leaf\". Each family of parts "
				+ "comes with what builders use it for and its commonest part "
				+ "numbers. search_parts finds a part you can name; this finds "
				+ "the one you can only describe."),
			"input_schema": {
				"type": "object",
				"properties": {
					"query": {"type": "string", "description":
						"what the part should read as"},
				},
				"required": ["query"],
				"additionalProperties": false,
			},
		},
		{
			"name": "place_technique",
			"description": ("Lay one of find_techniques' pieces into the "
				+ "model as the LEGO Group built it, or one of show_technique's by its "
				+ "name (a posed minifigure, a hinged wing: its joints put by their "
				+ "connectors): every part where the set has it, "
				+ "turned a number of quarter turns about the upright and "
				+ "moved so its low corner is at x, y, z, in your colours "
				+ "if you say which of its colours become which. Parts "
				+ "cannot be scaled; pick a piece of the right size. "
				+ "Checked like any edit: it is refused, with the reason, "
				+ "if it overlaps the model or does not hold on. The "
				+ "answer lists the bricks as placed."),
			"input_schema": {
				"type": "object",
				"properties": {
					"id": {"type": "string", "description":
						"the id find_techniques gave, or the name of one of "
						+ "show_technique's: \"posed minifigure\", \"hinged wing\""},
					"x": {"type": "number", "description":
						"studs across, to its low corner"},
					"y": {"type": "number", "description":
						"plates up, to its low corner"},
					"z": {"type": "number", "description":
						"studs deep, to its low corner"},
					"turn": {"type": "integer", "description":
						"quarter turns about the upright, 0-3"},
					"recolor": {"type": "object", "description":
						"its colours to yours, by LDraw code: {\"15\": 4} "
						+ "makes its white parts red",
						"additionalProperties": {"type": "integer"}},
				},
				"required": ["id", "x", "y", "z"],
				"additionalProperties": false,
			},
		},
		{
			"name": "settle_feature",
			"description": ("Say what a feature is to be, once the app has "
				+ "laid a real set's piece for it where it goes (the whole "
				+ "review, each settle and saving hand the next feature with "
				+ "its piece laid and a picture): accept it — moved, turned "
				+ "or recoloured first if it needs it — ask for the next-best "
				+ "piece instead, reject it with a reason, or say you built "
				+ "it yourself. Saving waits until every feature listed in "
				+ "submit_design is settled."),
			"input_schema": {
				"type": "object",
				"properties": {
					"feature": {"type": "string", "description":
						"the feature, as listed in submit_design's features"},
					"verdict": {"type": "string",
						"enum": ["accept", "next", "reject", "built"],
						"description": "accept: keep the app's piece (adjusted "
							+ "by move, turn or recolor first, if given); next: "
							+ "take it off and lay the next-best piece; reject: "
							+ "take it off, with a reason, and build it your own "
							+ "way or leave it out; built: you built it yourself, "
								+ "and the app's piece comes off (accept keeps it)"},
					"reason": {"type": "string", "description":
						"a sentence: what is wrong with the piece here (to "
						+ "reject), or how you built it (built)"},
					"move": {"type": "object", "description":
						"accept, moved first: studs across and deep, plates up. "
						+ "The other of a pair moves the mirror way.",
						"properties": {"dx": {"type": "number"},
							"dy": {"type": "number"}, "dz": {"type": "number"}},
						"additionalProperties": false},
					"turn": {"type": "integer", "description":
						"accept, turned first: quarter turns on the spot"},
					"recolor": {"type": "object", "description":
						"accept, recoloured first: its colours to yours by "
						+ "LDraw code, {\"15\": 1} makes its white blue",
						"additionalProperties": {"type": "integer"}},
				},
				"required": ["feature", "verdict"],
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
			"description": ("What real LEGO® sets of this kind are "
				+ "actually built from — the parts they reach for far "
				+ "more often than sets in general, and the colours "
				+ "they use. Measured over fifteen thousand real sets, "
				+ "so it is what the LEGO Group's own designers did and not "
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
				+ "matches a specific name.\n\nWith it comes our own best "
				+ "design of the nearest subject, as the design bench's judge "
				+ "scored it: how it was built, what it did best, and the "
				+ "faults to design out before you build."),
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
				+ "take, and its joints: holes, pins, axles, and the bars "
				+ "(a handle is one) and clips a clip-on-bar joint is made "
				+ "of, each by its middle and the way it runs, numbered "
				+ "for a placement by axis and joint. Ask about a brick that is already placed by "
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
				+ "at it. And every connector by the address attach takes "
				+ "(\"#41.hinge[0]\", \"hinge[0]\"): its type and number, "
				+ "where it is and the way it points."),
			"input_schema": {
				"type": "object",
				"properties": {
					"brick": {"type": "integer", "description":
						"the number look_at_model printed"},
					"near": {"type": "array", "items": {"type": "number"},
						"description": "[x, y, z] in studs and plates: list the "
							+ "connectors nearest it first, every type"},
					"part": {"type": "string"},
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"},
					"face": {"type": "string",
						"enum": ["up", "down", "+x", "-x", "+z", "-z"]},
					"rot": {"type": "integer"},
					"axis": {"type": "string", "enum": ["x", "-x", "y", "-y", "z", "-z"],
						"description": "as a brick's: x, y, z are then where its joint's "
							+ "middle goes"},
					"joint": {"type": "integer"},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "search_gear_ratio",
			"description": ("The gear trains of real spur gears (8 to 40 teeth) nearest a "
				+ "ratio, every mesh at a spacing the stud grid gives: an orrery's year, a "
				+ "clock's hour, a reduction for a slow arm. ratio= is output turns per input "
				+ "turn, negative for the other way round; or period= input turns per output "
				+ "turn. With to= [x, z] the output's axle stands that many studs from the "
				+ "input's, and the answer gives every axle between, on a grid point within "
				+ "within= studs of the line; without it, each mesh's spacing. Each train with "
				+ "its fraction, its error, its gears by part. Lay them as it says, and "
				+ "simulate_mechanism shows the ratio the parts give."),
			"input_schema": {
				"type": "object",
				"properties": {
					"ratio": {"type": "number", "description": "output turns per input turn"},
					"period": {"type": "number", "description": "input turns per output turn, "
						+ "instead of ratio"},
					"stages": {"type": "integer", "description": "most meshes, 1 to 6; 4 when omitted"},
					"to": {"type": "array", "items": {"type": "integer"}, "description":
						"[x, z]: studs from the input's axle to the output's, axles parallel"},
					"within": {"type": "integer", "description": "with to: how far off the line "
						+ "between them an axle may stand, studs; 2 when omitted"},
					"gears": {"type": "array", "items": {"type": "integer"}, "description":
						"the tooth counts to use; 8, 12, 16, 20, 24, 28, 36, 40 when omitted"},
					"first": {"type": "integer", "description": "the teeth of the gear on the "
						+ "input axle: two trains taken off one shaft at one height share it"},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "restyle_model",
			"description": ("A finishing pass over what is already built, "
				+ "wall by wall: plain bricks one stud wide (1x1 to 1x4) whose "
				+ "long face is open to the air, and the outer row of two-wide "
				+ "ones, are laid again in place as one structure per wall — "
				+ "ribs (a column of round plates on bricks with a stud on the "
				+ "side, every few studs), bands (a course of grille), panels "
				+ "(grille between the ribs, framed by a plain stud at each end "
				+ "and a plain course at each ledge, as 10237 Orthanc textures "
				+ "its black), grid (ribs and bands) or courses (round bricks, "
				+ "a recessed line) — in the wall's own colour, never a part at "
				+ "a time. A dark wall gets panels unasked; a light wall not "
				+ "given a style gets a scatter of dressed bricks (sideways) and "
				+ "masonry. The faces of a prism or a cluster too, in their own "
				+ "sections, and a model opened from a file. Done for you, in "
				+ "one call, checked like any edit."),
			"input_schema": {
				"type": "object",
				"properties": {
					"where": {"type": "object", "description":
						"only bricks inside this box, in studs and plates, "
						+ "as look_at_model takes one; the whole model if left out",
						"properties": {
							"x_from": {"type": "number"}, "x_to": {"type": "number"},
							"y_from": {"type": "number"}, "y_to": {"type": "number"},
							"z_from": {"type": "number"}, "z_to": {"type": "number"},
						},
						"additionalProperties": false},
					"style": {"type": "string", "enum": DRESS_STYLES.keys(),
						"description": "how each wall is dressed, as one structure: "
						+ "panels on a dark wall if not said"},
					"texture": {"type": "string", "enum": DRESS_TEXTURES.keys(),
						"description": "what panels and bands are laid in: grille "
						+ "(the default), masonry, logs (planking), round bricks "
						+ "(fluted) or headlight bricks"},
					"sideways": {"type": "number", "description":
						"a light wall given no style: share of its bricks turned "
						+ "out and dressed, 0 to 0.5; 0.15 if not said"},
					"masonry": {"type": "number", "description":
						"a light wall given no style: share laid as masonry, 0 to "
						+ "1; 0.25 if not said"},
					"face_color": {"type": "integer", "description":
						"the second tone: on every fifth rib and on bands; the "
						+ "rest is the wall's own colour, as a set dresses a "
						+ "black wall in black"},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "add_rooms",
			"description": ("Floors and furnished rooms inside a building that "
				+ "already stands — a tower, a keep, a house — in one call, as "
				+ "a real set opens at the back onto them (10237 Orthanc: a "
				+ "library, Saruman's chamber, a dungeon, the palantír). Give "
				+ "the building's box (where) or, for a prism, the prism's own "
				+ "at, sides and radius (prism), and the floors bottom up, each "
				+ "a kind of room: %s. Each floor is laid as plates and tiles "
				% ", ".join(PackedStringArray(Rooms.KINDS.keys()))
				+ "held up on columns; each room is furnished from the worked "
				+ "examples real sets built — bookcases, a fireplace, an anvil, "
				+ "a four-poster bed, lamps, chests, barrels — against its walls "
				+ "and facing in, varied by the seed; stair: true climbs to the "
				+ "next floor. The shell is left as it is and the edit is "
				+ "checked like any other, so build it open at the back (a "
				+ "prism's open, or no back wall) for the rooms to be seen. "
				+ "This is where a real set's different pieces and colours "
				+ "are, and a solid shell has none of them."),
			"input_schema": {
				"type": "object",
				"properties": {
					"where": {"type": "object", "description":
						"the building, in studs and plates, as look_at_model "
						+ "takes a box: its walls and the inside between them. "
						+ "y_from is where the lowest floor goes if no floor says",
						"properties": {
							"x_from": {"type": "number"}, "x_to": {"type": "number"},
							"y_from": {"type": "number"}, "y_to": {"type": "number"},
							"z_from": {"type": "number"}, "z_to": {"type": "number"},
						},
						"additionalProperties": false},
					"prism": {"type": "object", "description":
						"for a prism's inside: the same at, sides and radius "
						+ "(and thickness, if not 2) as the prism pattern, so "
						+ "the floors follow its faces",
						"properties": {
							"at": {"type": "object", "properties": {
								"x": {"type": "number"}, "y": {"type": "number"},
								"z": {"type": "number"}},
								"additionalProperties": false},
							"sides": {"type": "integer"},
							"radius": {"type": "number"},
							"thickness": {"type": "integer"},
						},
						"additionalProperties": false},
					"floors": {"type": "array", "description":
						"bottom up, one a floor",
						"items": {"type": "object", "properties": {
							"room": {"type": "string", "description":
								"what the room is, e.g. library or Saruman's chamber"},
							"y": {"type": "number", "description":
								"plates up, where its floor is laid; left out, "
								+ "floors stack up from the bottom"},
							"stair": {"type": "boolean", "description":
								"a stair from this floor up to the next"},
						},
						"required": ["room"],
						"additionalProperties": false}},
					"height": {"type": "number", "description":
						"plates from one floor to the next when no y is said; "
						+ "24 where the building is tall enough"},
					"seed": {"type": "integer", "description":
						"another seed is another arrangement and other colours"},
				},
				"required": ["floors"],
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
					"turn": {
						"type": "array",
						"description": "turn bricks where they stand, about "
							+ "their middle, as one: they become a section "
							+ "turned so, as the window's Turn, Tilt and Roll "
							+ "do. A part that leans this way must turn on a "
							+ "joint; give a section its own new angle instead.",
						"items": {
							"type": "object",
							"properties": {
								"bricks": {"type": "array",
									"items": {"type": "integer"}},
								"yaw": {"type": "number", "description":
									"degrees about the upright"},
								"pitch": {"type": "number", "description":
									"degrees its +z end lifts"},
								"roll": {"type": "number", "description":
									"degrees its +x side lifts"},
							},
							"required": ["bricks"],
							"additionalProperties": false,
						},
					},
					"add": {"type": "array", "items": brick},
					"sections": {"type": "array", "items": section_change,
						"description":
							"add a section, or give one that already "
							+ "exists a new angle or position — its name "
							+ "and only what changes — which moves "
							+ "everything in it and within it without "
							+ "naming a single brick."},
					"repeat_section": {"type": "array",
						"items": repeat_section, "description":
							"say a section again somewhere else. One bay "
							+ "of a wall, repeated — rather than forty "
							+ "bays dictated."},
					"assemblies": {"type": "array", "items": assembly,
						"description":
							"name a part of the model, as submit_design's "
							+ "assemblies do; one of the same name moves "
							+ "to the new box. Something meant to stand "
							+ "apart from the model — a display stand, a "
							+ "sign, a nameplate in front of it — must be "
							+ "named, its box holding it and none of the "
							+ "model: a piece apart that nothing names is "
							+ "a part that has come off, and fails."},
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
			"name": "settle_surface",
			"description": ("Settle what the surface pass laid (review_model "
				+ "{\"surface\": true}, or the app's own turn for it): accept a "
				+ "finding, adjusted if need be; reject it with a reason, which "
				+ "takes the app's pieces off and puts back what they replaced; or "
				+ "keep the studs there for good with a reason — a yard, a mosaic, "
				+ "a studded texture, where a touch will stand. \"tile\" lays "
				+ "ground the pass only offered."),
			"input_schema": {
				"type": "object",
				"properties": {
					"finding": {"type": "string", "description":
						"its key, S1 or G1, several as \"S1, S3\", or \"all\""},
					"verdict": {"type": "string",
						"enum": ["accept", "reject", "keep", "tile"]},
					"reason": {"type": "string", "description":
						"why, in a sentence: required to reject or keep"},
					"plain": {"type": "boolean", "description":
						"with accept: plain tiles where the textured ones are"},
					"recolor": {"type": "object", "description":
						"with accept: its colours to others by LDraw code, "
						+ "{\"4\": 320}", "additionalProperties": {"type": "integer"}},
				},
				"required": ["finding", "verdict"],
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
					"floor": {"type": "string", "enum": ModelFloor.KINDS,
						"description":
							"what it stands on. \"none\" for anything that is "
							+ "picked up and played with or stood on a shelf — a "
							+ "vehicle, a ship, a figure, a creature, a spacecraft: "
							+ "a set like that has no plate in the box; and a "
							+ "figure or two with what the brief stands them on, "
							+ "whose base is the one it names, built to their "
							+ "footprint. "
							+ "\"baseplate\" for a scene, a diorama, a building on "
							+ "its lot, a landscape: a real baseplate, sized to it, "
							+ "goes in the box as the first part of the build — "
							+ "build on it, never lay ground plates of your own "
							+ "under the model as well. \"grid\" for neither. Say "
							+ "in the description which you chose and why; the "
							+ "person can change it."},
					"floor_colour": {"type": "string",
						"description": "a baseplate's colour, from the colours baseplates "
							+ "come in: Green, Bright Green, Dark Green, Tan, Dark Tan, "
							+ "Light Bluish Grey, Dark Bluish Grey, Sand Green, Blue, "
							+ "White, Black. Grass is green, a road or a yard grey, "
							+ "sand or a desert tan, water blue, snow white."},
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
							+ "detail. A pass adds about as much to a "
							+ "big assembly as to a small one, so name "
							+ "them at about a hundred parts each: on a "
							+ "building, a floor's front is one and its "
							+ "sides another, the roof one and the sign "
							+ "on it another. A model that is one thing "
							+ "is one assembly."},
					"features": {"type": "array", "items": {
						"type": "object",
						"properties": {
							"name": {"type": "string"},
							"x": {"type": "number", "description": "studs across"},
							"y": {"type": "number", "description": "plates up"},
							"z": {"type": "number", "description": "studs deep"},
							"facing": {"type": "string",
								"enum": ["+z", "-z", "+x", "-x", "up"],
								"description": "the way it faces out; the front is +z"},
						},
						"required": ["name"],
						"additionalProperties": false},
						"description":
							"what the subject is known by, a few words "
							+ "each: an owl's facial disc, eyes, beak, ear "
							+ "tufts, wings, talons; a car's wheel arches, "
							+ "headlamps, grille, windscreen, spoiler — and "
							+ "where each goes: x, y, z on the model's surface "
							+ "and the way it faces out (one of a pair; the "
							+ "other is mirrored). Once the shape stands and "
							+ "you have looked at it whole, each comes back to "
							+ "you in turn with the best real set's piece for "
							+ "it laid there by the app, to accept, adjust or "
							+ "reject with settle_feature."},
					"sketch": {"type": "boolean", "description":
						"true for a sketch: massing only, under 150 parts, checked "
						+ "and pictured but not built. Three are made to choose "
						+ "between before the full design, each a different idea: "
						+ "in silhouette, proportion or approach."},
				},
				"required": ["name", "description", "bricks", "assemblies", "features"],
				"additionalProperties": false,
			},
		},
	] + [FigureTool.schema(), PartTool.schema()] + ArtPlan.schemas()
