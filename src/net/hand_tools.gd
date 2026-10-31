## The window's hand tools for a session: Mirror, Split, Merge and Measure,
## and what the person sees that a session is not told (APP_UX3, mcphand).
##
## A session laid a mirror image, a split or a merge itself, a part at a
## time, and measured nothing: the angle between two connectors was its own
## arithmetic. On the MCP walk's small cases that was exact in 2 to 4 calls;
## on a sub-assembly of forty, with handed wedges and hinges turned every
## way, it is forty places worked out by hand, where the window's Shift+M is
## one key. So each of these is the window's own code (Builder.mirror_bricks,
## SplitMerge, Measure's words) on the parts the session names: one undo
## step, the person's selection left as it was, and a refusal that says what
## to fix.
##
## in_view reads what the person sees and a session did not: the step the
## timeline is at, the part in their hand, and the reference picture they
## laid to build over, with a picture of it and the model's parts drawn on
## it where they stand over it. It changes nothing.
##
## Tools of AppTools, served wherever the app's tools are: the desktop's MCP
## port, My Claude and the connector.
class_name HandTools
extends RefCounted

const NAMES: Array[String] = ["mirror_parts", "split_parts", "merge_parts", "measure", "in_view"]
const STUD := 20.0
const PLATE := 8.0
## How near two connectors' middles are to be two halves of one joint, LDU.
const JOINED := 1.0
## The longest side of in_view's picture of the reference, px.
const PICTURE_MOST := 640
## A connector type as a person says it, where the window's ruler has no
## word of its own for it (Measure.KINDS).
const SAID: Dictionary = {"socket": "pin hole", "cross": "axle hole", "open": "open stud",
	"fixed": "fixed joint"}
## The tools the window's ruler and timeline name, as in_view says them.
const HELD_MODES: Dictionary = {"place": "the Place tool", "connect": "Connect"}

var app: Node


static func definitions() -> Array:
	var bricks: Dictionary = {"type": "array", "items": {"type": "integer"},
		"description": "the parts, by their numbers in look_at_model"}
	return [
		{
			"name": "mirror_parts",
			"description": ("Make parts their mirror image, as the window's Mirror "
				+ "does: each put where its reflection is and turned, a part made in a left and "
				+ "a right hand (a wing, a wedge plate, a door) swapped for its other hand. "
				+ "bricks= the parts; axis \"x\" mirrors left to right (the default), \"z\" "
				+ "front to back. In place, across the plane through their middle; copy=true "
				+ "leaves them and puts a mirrored copy beside them, across their far side "
				+ "(+x or +z). across= puts the plane where you say, in studs, a whole or half "
				+ "number: copy=true across=0 makes a model's left half its right half too. "
				+ "All or nothing, one undo step; refused where the mirror image runs into a "
				+ "part not named."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["bricks"], "properties": {
					"bricks": bricks,
					"axis": {"type": "string", "enum": ["x", "z"]},
					"copy": {"type": "boolean"},
					"across": {"type": "number", "description": "the mirror's plane, x= (or z=) in studs"},
				}},
		},
		{
			"name": "split_parts",
			"description": ("Split parts into smaller ones of their kind on the same studs, as "
				+ "the window's Split does, by Studio's rules: a plate, a brick or a "
				+ "tile into 1 x 1s of its kind, a 1 x 1 brick into three 1 x 1 plates, a slope "
				+ "into the 1-wide slope of its angle, length and height, a curved slope into "
				+ "the 1-wide curved slope of its length. What was joined to them is joined to "
				+ "the pieces. bricks= the parts. One undo step; a part that does not split, or "
				+ "has no room for its pieces, is said and left as it was."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["bricks"], "properties": {"bricks": bricks}},
		},
		{
			"name": "merge_parts",
			"description": ("Merge parts into the fewest bigger ones, as the window's Merge "
				+ "does: the plates, bricks and tiles of each colour and sub-assembly "
				+ "covered by the fewest real parts made in that colour, biggest first, three "
				+ "plates high a brick, each where the old ones stood. Six 1 x 1 plates in a "
				+ "2 x 3 become a 2 x 3 plate; three stacked 1 x 4 plates a 1 x 4 brick. "
				+ "bricks= the parts. One undo step; where no real part would be fewer, they "
				+ "are left as they were."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["bricks"], "properties": {"bricks": bricks}},
		},
		{
			"name": "measure",
			"description": ("Measure between two connectors, or two points, as the window's "
				+ "Measure does: the distance in mm, studs across (x), deep (z) and plates "
				+ "up (y), and the angle between the two connectors' axes to a tenth of a "
				+ "degree (with a hole, a bar or a hinge, which go both ways, the angle between "
				+ "the lines, 0 to 90°; between two pins or axles, 0 to 180°). from= and to= "
				+ "each a connector as attach names it, \"#12.hole[1]\" or \"#7.hinge[0]\" "
				+ "(attachment_points lists a part's), or a point \"x y z\" in studs and "
				+ "plates. The two halves of one joint (a hinge, a pin in its hole, a clip on "
				+ "a bar) are said with the turn between them as attach's yaw gives it, so a "
				+ "hinge left at an angle reads back as that angle. Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["from", "to"], "properties": {
					"from": {"type": "string"},
					"to": {"type": "string"},
				}},
		},
		{
			"name": "in_view",
			"description": ("What the person sees in the window that a session is not told: "
				+ "the step the timeline is at and its parts, the part in their hand (the Place "
				+ "tool's, or the parts they are carrying), how many parts they have selected, "
				+ "and the reference picture they laid to build over: its file, size and place "
				+ "in studs, and with picture=true (the default) the picture itself, the "
				+ "model's parts drawn on it where they stand over it. Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"picture": {"type": "boolean"},
			}},
		},
	]


## A coroutine, as AppTools.run is.
func run(tool: String, input: Dictionary) -> Variant:
	match tool:
		"mirror_parts":
			return _mirror(input)
		"split_parts":
			return _split(input)
		"merge_parts":
			return _merge(input)
		"measure":
			return _measure(input)
		"in_view":
			return _in_view(input)
	return "No tool called %s." % tool


# -- mirror, split and merge --------------------------------------------------------


func _mirror(input: Dictionary) -> String:
	var builder: Builder = app.get("_builder")
	var library: PartLibrary = app.get("_library")
	var ids: Variant = _named(input)
	if ids is String:
		return ids
	var alive := PackedInt64Array(ids)
	var axis_said: String = str(input.get("axis", "x"))
	if not axis_said in ["x", "z"]:
		return "axis is \"x\" (left to right) or \"z\" (front to back)."
	var axis: int = 0 if axis_said == "x" else 2
	var copy: bool = bool(input.get("copy", false))
	var across: float
	if input.has("across"):
		var studs: float = float(input["across"])
		if not is_equal_approx(studs * 2.0, roundf(studs * 2.0)):
			return ("across= is the plane in studs, a whole or half number, so studs land on "
				+ "studs: %s is neither." % _n(studs))
		across = studs * STUD
	else:
		# The window's own plane in place (Builder.mirror_bricks); a copy's,
		# their far side, so it lands beside them and not on them.
		var box: AABB = builder._bounds_of(alive, Transform3D.IDENTITY)
		across = snappedf(box.end[axis] if copy else box.get_center()[axis], STUD * 0.5)
	var swaps: Dictionary = {}      ## "from → to" -> how many
	for brick_id: int in alive:
		var part: String = (app.get("_world") as BrickWorld).get_brick(brick_id).part_id
		var other: String = Mirror.counterpart(library, part)
		if not other.is_empty() and library.mesh_for(other) != null:
			var key: String = "%s %s → %s %s" % [part, _part_name(library, part), other,
				_part_name(library, other)]
			swaps[key] = int(swaps.get(key, 0)) + 1
	var made: PackedInt64Array = builder.mirror_bricks(alive, axis, across, copy)
	var way: String = "left to right" if axis == 0 else "front to back"
	var plane: String = "%s = %s" % [axis_said, _n(across / STUD)]
	if made.is_empty():
		return ("Not mirrored: their mirror image across %s runs into parts not named. Name "
			% plane + "those too, or give copy=true with across= a plane clear of the model "
			+ "(nothing changed).")
	_edited()
	var said := PackedStringArray()
	if copy:
		said.append(("Mirrored a copy of %s %s across %s: %s, beside them; the %d stay as "
			+ "they were. The copy is in no sub-assembly (edit_model's assemblies makes it "
			+ "one).") % [_many(alive.size()), way, plane, _numbers(made), alive.size()])
	else:
		said.append("Mirrored %s %s, in place across %s: they are %s now." % [
			_many(made.size()), way, plane, _numbers(made)])
	if not swaps.is_empty():
		var rows := PackedStringArray()
		for key: String in swaps:
			rows.append("%s%s" % [key, "" if int(swaps[key]) == 1 else " (x%d)" % swaps[key]])
		said.append("Swapped for the other hand: %s." % "; ".join(rows))
	said.append("One undo step.")
	return " ".join(said)


func _split(input: Dictionary) -> String:
	var builder: Builder = app.get("_builder")
	var library: PartLibrary = app.get("_library")
	var world: BrickWorld = app.get("_world")
	var ids: Variant = _named(input)
	if ids is String:
		return ids
	var whole := PackedStringArray()
	for brick_id: int in ids:
		if SplitMerge.split_of(library, world.get_brick(brick_id).part_id).is_empty():
			whole.append(_brick_words(brick_id))
	if whole.size() == (ids as Array).size():
		return ("Nothing split: %s do%s not split. Plates, bricks and tiles split into 1 x 1s, "
			% [", ".join(whole), "es" if whole.size() == 1 else ""]
			+ "a 1 x 1 brick into three plates, slopes into 1-wide slopes; a 1 x 1 plate is "
			+ "as small as they go.")
	var done: Dictionary = SplitMerge.split_bricks(builder, ids, false)
	if int(done["changed"]) == 0:
		return "Nothing split: no room for the pieces there (nothing changed)."
	_edited()
	var made: PackedInt64Array = done["made"]
	var said := PackedStringArray(["Split %s into %d (%s): %s." % [_many(int(done["changed"])),
		made.size(), _kinds(made), _numbers(made)]])
	if not whole.is_empty():
		said.append("%s do%s not split." % [", ".join(whole), "es" if whole.size() == 1 else ""])
	if int(done["refused"]) > 0:
		said.append("%d had no room for their pieces and stay as they were." % done["refused"])
	said.append("One undo step.")
	return " ".join(said)


func _merge(input: Dictionary) -> String:
	var builder: Builder = app.get("_builder")
	var ids: Variant = _named(input)
	if ids is String:
		return ids
	var done: Dictionary = SplitMerge.merge_bricks(builder, ids, false)
	if int(done["changed"]) == 0:
		var why: String = str(done["words"]).replace("select two", "give two")
		return "Nothing merged: %s (nothing changed)." % why
	_edited()
	var made: PackedInt64Array = done["made"]
	var world: BrickWorld = app.get("_world")
	var left := PackedInt64Array()
	for brick_id: int in ids:
		if world.get_brick(brick_id) != null:
			left.append(brick_id)
	var said := PackedStringArray(["Merged %s into %d (%s): %s." % [_many(int(done["changed"])),
		made.size(), _kinds(made), _numbers(made)]])
	if not left.is_empty():
		said.append("%s stay%s as %s: no real part would be fewer, or there was no room." % [
			_numbers(left), "s" if left.size() == 1 else "", "it was" if left.size() == 1
			else "they were"])
	said.append("One undo step.")
	return " ".join(said)


## bricks= as the parts still in the model, or why not.
func _named(input: Dictionary) -> Variant:
	var given: Variant = input.get("bricks", [])
	if not given is Array or (given as Array).is_empty():
		return "Give bricks= the parts' numbers, from look_at_model."
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var ids: Array = []
	var unknown := PackedStringArray()
	for raw: Variant in given:
		var number: int = int(raw)
		if store.scenery.has(number) or world.get_brick(number) == null:
			unknown.append(str(number))
		elif not ids.has(number):
			ids.append(number)
	if not unknown.is_empty():
		return "No part numbered %s (look_at_model numbers them); nothing changed." \
			% ", ".join(unknown)
	return ids


## What the window does after its own edit (EditVerbs.edited): the model
## marked changed and saved by its autosave.
func _edited() -> void:
	var verbs: EditVerbs = app.get("_verbs")
	if verbs != null and verbs.edited.is_valid():
		verbs.edited.call()


# -- measure ----------------------------------------------------------------------


func _measure(input: Dictionary) -> String:
	var one: Dictionary = _end(str(input.get("from", "")))
	if one.has("error"):
		return "from= %s" % one["error"]
	var other: Dictionary = _end(str(input.get("to", "")))
	if other.has("error"):
		return "to= %s" % other["error"]
	var from: Vector3 = one["at"]
	var to: Vector3 = other["at"]
	var said: String = Measure.said_between(from, to)
	if said.is_empty():
		said = "0 mm: the two are in one place"
	if one.has("axis") and other.has("axis"):
		said += Measure.angle_words(Measure.angle_between(one["axis"], one["male"],
			other["axis"], other["male"]), one["word"], other["word"])
	var lines := PackedStringArray(["From %s to %s: %s." % [one["said"], other["said"], said]])
	var joint: String = _joint_words(one, other)
	if not joint.is_empty():
		lines.append(joint)
	return "\n".join(lines)


## A connector or a point as measure's from= or to= says it: {at (the
## world, LDU), said, and for a connector axis, male, word, brick, point},
## or {error}.
func _end(given: String) -> Dictionary:
	var text: String = given.strip_edges()
	if text.is_empty():
		return {"error": "is a connector, as \"#12.hole[1]\", or a point, as \"2 3 0\"."}
	var found: RegExMatch = RegEx.create_from_string("^#?\\s*(\\d+)\\s*\\.\\s*(.+)$").search(text)
	if found == null:
		var numbers := PackedFloat64Array()
		for bit: String in text.replace("[", " ").replace("]", " ").replace(",", " ").split(" ", false):
			if not bit.is_valid_float():
				return {"error": "'%s' is neither a connector, as \"#12.hole[1]\", nor a point, as \"2 3 0\"." % given}
			numbers.append(bit.to_float())
		if numbers.size() != 3:
			return {"error": "a point is x y z, in studs, plates and studs."}
		return {"at": Vector3(numbers[0] * STUD, numbers[1] * PLATE, numbers[2] * STUD),
			"said": "the point %s %s %s" % [_n(numbers[0]), _n(numbers[1]), _n(numbers[2])]}
	var number: int = found.get_string(1).to_int()
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var library: PartLibrary = app.get("_library")
	var brick: BrickWorld.Brick = world.get_brick(number)
	if brick == null or store.scenery.has(number):
		return {"error": "#%d: no part has that number (look_at_model numbers them)." % number}
	var address: Dictionary = Attach.parse_address(found.get_string(2))
	if address.has("error"):
		return {"error": str(address["error"])}
	var points: Array = Attach.points_of(library, brick.part_id)
	var type: String = address["type"]
	var count: int = Attach.count_of(points, type)
	if count == 0:
		return {"error": "#%d (%s) has no %s; it has %s." % [number,
			_part_name(library, brick.part_id), type, Attach.listing(points)]}
	if address["index"] == null and count > 1:
		return {"error": "#%d has %d %s; say which, as %s[0] to %s[%d]." % [number, count, type,
			type, type, count - 1]}
	var point: Attach.Point = Attach.pick(points, type,
		0 if address["index"] == null else int(address["index"]))
	if point == null:
		return {"error": "#%d has %d %s (%s[0] to %s[%d])." % [number, count, type, type, type,
			count - 1]}
	var placed: Transform3D = brick.transform * point.frame
	var out: Dictionary = {"at": placed.origin, "axis": placed.basis.y.normalized(), "male": false,
		"word": str(SAID.get(type, type)), "brick": brick, "point": point,
		"said": "#%d.%s" % [number, point.address()]}
	# The window's ruler's own reading of the same connector, where it has
	# one: its words, and a pin's or an axle's way out of its part.
	var nearest: float = 4.0
	for end: JointSnap.End in JointSnap.ends_for(library, brick.part_id):
		var there: JointSnap.End = end.placed(brick.transform, brick.id)
		var off: float = there.middle().distance_to(placed.origin)
		if off < nearest and absf(there.axis.dot(out["axis"])) > 0.999:
			nearest = off
			out["axis"] = there.axis
			out["male"] = there.is_male()
			out["word"] = str(Measure.KINDS.get(there.kind, there.kind))
	out["said"] += " (%s, at %s)" % [out["word"], _at_words(placed.origin)]
	return out


## Two connectors that are the halves of one joint, said with the turn
## between them as attach's yaw gives it ([method Attach.pose] read back);
## "" when they are not.
static func _joint_words(one: Dictionary, other: Dictionary) -> String:
	if not one.has("point") or not other.has("point"):
		return ""
	var a: Attach.Point = one["point"]
	var b: Attach.Point = other["point"]
	if not Attach.compatible(a, b) or a.kind == Exact.BALL:
		return ""
	var target: Transform3D = (one["brick"] as BrickWorld.Brick).transform * a.frame
	var source: Transform3D = (other["brick"] as BrickWorld.Brick).transform * b.frame
	# at = target * m * b.frame^-1 (Attach.pose): m is the joint's own turn.
	var m: Transform3D = target.affine_inverse() * source
	if Vector2(m.origin.x, m.origin.z).length() > JOINED \
			or absf(m.basis.y.normalized().y) < 0.9999:
		return ""
	var along: float = m.origin.y
	if a.kind != Exact.AXLE and absf(along) > JOINED:
		return ""
	if a.kind == Exact.AXLE and absf(along) > a.length + b.length:
		return ""
	var yaw: float = rad_to_deg(atan2(-m.basis.x.z, m.basis.x.x))
	var flip: bool = m.basis.y.y < 0.0
	var said: String = "They are one joint: %s on %s turned %.1f° about it" % [
		str(other["said"]).get_slice(" (", 0), str(one["said"]).get_slice(" (", 0), yaw]
	if flip:
		said += ", end for end"
	if a.kind == Exact.AXLE and absf(along) > 0.05:
		said += ", slid %s LDU along it" % _n(along)
	return said + (" (attach's yaw, with to=\"%s\" and by=\"%s\")." % [
		str(one["said"]).get_slice(" (", 0), b.address()])


# -- what the person sees ---------------------------------------------------------


func _in_view(input: Dictionary) -> Variant:
	var builder: Builder = app.get("_builder")
	var library: PartLibrary = app.get("_library")
	var lines := PackedStringArray(["What the person sees in the window:"])
	lines.append(" - " + _timeline_words())
	lines.append(" - " + _hand_words())
	var selected: int = 0
	for brick_id: int in builder.selection:
		if builder.world.get_brick(brick_id) != null:
			selected += 1
	lines.append(" - Selected: %s." % ("nothing" if selected == 0
		else "%s (selection reads them)" % _many(selected)))
	var reference: ReferenceImage = app.get("_reference")
	if reference == null or not reference.has_picture():
		lines.append(" - No reference picture is laid in the scene.")
		return "\n".join(lines)
	lines.append(" - " + _reference_words(reference))
	if not bool(input.get("picture", true)):
		return "\n".join(lines)
	var picture: Image = _reference_picture(reference, builder, library)
	if picture == null:
		lines.append("   Its picture could not be read.")
		return "\n".join(lines)
	lines.append("   The picture is the reference as laid, %d x %d px, each part of the model "
		% [picture.get_width(), picture.get_height()]
		+ "drawn on it in its colour where it stands over it, outlined.")
	return [{"type": "text", "text": "\n".join(lines)}, AppTools._picture_block(picture)]


func _timeline_words() -> String:
	var steps: StepsBar = app.get("_steps")
	if steps == null or not steps.visible:
		return "The timeline is down: the whole model shows."
	var at: Vector2i = steps.timeline_at()
	var head: String = "The timeline is up, in %s, showing %d of %d parts" % [
		StepsBar.MODES[steps.mode()].to_lower(), at.x, at.y]
	var step: Instructions.Step = steps.current_step()
	if step == null:
		return head + "."
	var all: Array[Instructions.Step] = steps.steps()
	var last: int = all[all.size() - 1].number if not all.is_empty() else step.number
	var library: PartLibrary = app.get("_library")
	var kinds := PackedStringArray()
	for part: String in step.parts:
		kinds.append("%d x %s" % [int(step.parts[part]), _part_name(library, part)])
	return head + ", at step %d of %d%s: %s (%s)." % [step.number, last,
		" (%s)" % step.assembly if not step.assembly.is_empty() else "",
		_numbers(step.brick_ids), ", ".join(kinds)]


func _hand_words() -> String:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	var library: PartLibrary = app.get("_library")
	if builder.is_carrying():
		return "In their hand: %s they picked up to move." % _many(builder.carrying.count())
	var mode: String = verbs.mode if verbs != null else "select"
	if not HELD_MODES.has(mode):
		return "Nothing in their hand: the %s tool." % mode.capitalize()
	if not builder.held_figure.is_empty():
		return "In their hand: a minifigure, with %s." % HELD_MODES[mode]
	var colour: PartLibrary.BrickColor = library.color(builder.held_color)
	return "In their hand: %s (%s) in %s (%d), with %s." % [
		_part_name(library, builder.held_part), builder.held_part, colour.name,
		builder.held_color, HELD_MODES[mode]]


func _reference_words(reference: ReferenceImage) -> String:
	var corners: Array[Vector3] = reference.corners()
	var low: Vector3 = corners[0]
	var high: Vector3 = corners[0]
	for corner: Vector3 in corners:
		low = low.min(corner)
		high = high.max(corner)
	var span: String
	match reference.on:
		"front":
			span = "x %s to %s, y %s to %s plates, standing at z %s" % [_n(low.x / STUD),
				_n(high.x / STUD), _n(low.y / PLATE), _n(high.y / PLATE), _n(low.z / STUD)]
		"side":
			span = "z %s to %s, y %s to %s plates, standing at x %s" % [_n(low.z / STUD),
				_n(high.z / STUD), _n(low.y / PLATE), _n(high.y / PLATE), _n(low.x / STUD)]
		_:
			span = "x %s to %s, z %s to %s" % [_n(low.x / STUD), _n(high.x / STUD),
				_n(low.z / STUD), _n(high.z / STUD)]
	return ("The reference picture: %s, %s, %s x %s studs, %s; %d%% opaque%s. A picture for "
		+ "the person's eyes to build over, never part of the model.") % [
		reference.picture_name, str(ReferenceImage.PLANE_WORDS.get(reference.on, reference.on)).to_lower(),
		_n(reference.width / STUD), _n(reference.height() / STUD), span,
		roundi(reference.opacity * 100.0), ", locked" if reference.locked else ""]


## The reference picture as laid, at most [constant PICTURE_MOST] px, with
## each part of the model drawn on it in its colour where it stands over it,
## the lowest first, and outlined; null when it does not read.
func _reference_picture(reference: ReferenceImage, builder: Builder,
		library: PartLibrary) -> Image:
	var kept: Dictionary = reference.said()
	var bytes: PackedByteArray = Marshalls.base64_to_raw(str(kept.get("picture", "")))
	var picture: Image = PictureFile.decode(bytes, "webp") if not bytes.is_empty() else null
	if picture == null or picture.is_empty():
		return null
	picture.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(picture.get_width(), picture.get_height())
	if longest > PICTURE_MOST:
		var scale: float = float(PICTURE_MOST) / longest
		picture.resize(maxi(1, roundi(picture.get_width() * scale)),
			maxi(1, roundi(picture.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	# The picture's plane: from its top left corner, along it and down it.
	var corners: Array[Vector3] = reference.corners()
	var along: Vector3 = corners[1] - corners[0]
	var down: Vector3 = corners[3] - corners[0]
	var size := Vector2(picture.get_width(), picture.get_height())
	var store: ModelStore = app.get("_store")
	var drawn: Array = []       ## [how near the eye, rect, colour]
	var toward: Vector3 = along.cross(down).normalized()
	for brick: BrickWorld.Brick in builder.world.bricks():
		if store.scenery.has(brick.id):
			continue
		var box: AABB = builder._bounds_of(PackedInt64Array([brick.id]), Transform3D.IDENTITY)
		if box.size == Vector3.ZERO:
			continue
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for n: int in 8:
			var off: Vector3 = box.get_endpoint(n) - corners[0]
			var uv := Vector2(off.dot(along) / along.length_squared(),
				off.dot(down) / down.length_squared()) * size
			low = low.min(uv)
			high = high.max(uv)
		var rect := Rect2i(Vector2i(low.floor()), Vector2i((high - low).ceil())).intersection(
			Rect2i(Vector2i.ZERO, Vector2i(size)))
		if rect.size.x < 1 or rect.size.y < 1:
			continue
		drawn.append([-box.get_center().dot(toward), rect, library.color(brick.color_code).rgb])
	# Nearest the picture first, so what stands highest over it shows.
	drawn.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for row: Array in drawn:
		var rect: Rect2i = row[1]
		var colour: Color = row[2]
		var fill := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		fill.fill(Color(colour, 0.55))
		picture.blend_rect(fill, Rect2i(Vector2i.ZERO, rect.size), rect.position)
		var edge: Color = colour.darkened(0.6) if colour.get_luminance() > 0.3 \
			else colour.lightened(0.6)
		for line: Rect2i in [Rect2i(rect.position, Vector2i(rect.size.x, 1)),
				Rect2i(rect.position + Vector2i(0, rect.size.y - 1), Vector2i(rect.size.x, 1)),
				Rect2i(rect.position, Vector2i(1, rect.size.y)),
				Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y))]:
			picture.fill_rect(line, edge)
	return picture


# -- words ------------------------------------------------------------------------


func _brick_words(brick_id: int) -> String:
	var library: PartLibrary = app.get("_library")
	var brick: BrickWorld.Brick = (app.get("_world") as BrickWorld).get_brick(brick_id)
	return "#%d (%s)" % [brick_id, _part_name(library, brick.part_id)]


## The new parts by kind: "8 x Plate 1 x 1".
func _kinds(ids: PackedInt64Array) -> String:
	var library: PartLibrary = app.get("_library")
	var world: BrickWorld = app.get("_world")
	var counts: Dictionary = {}
	for brick_id: int in ids:
		var name: String = _part_name(library, world.get_brick(brick_id).part_id)
		counts[name] = int(counts.get(name, 0)) + 1
	var said := PackedStringArray()
	for name: String in counts:
		said.append("%d x %s" % [counts[name], name])
	return ", ".join(said)


static func _part_name(library: PartLibrary, part: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	return Inventory._tidy(info.name) if info != null else part


## Part numbers, runs together: "#40 to #47, #52".
static func _numbers(ids: PackedInt64Array) -> String:
	var sorted: Array = Array(ids)
	sorted.sort()
	var runs := PackedStringArray()
	var n: int = 0
	while n < sorted.size():
		var last: int = n
		while last + 1 < sorted.size() and int(sorted[last + 1]) == int(sorted[last]) + 1:
			last += 1
		runs.append("#%d" % sorted[n] if last == n else ("#%d, #%d" if last == n + 1
			else "#%d to #%d") % [sorted[n], sorted[last]])
		n = last + 1
	return ", ".join(runs)


static func _many(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


static func _at_words(at: Vector3) -> String:
	return "x %s, y %s, z %s" % [_n(at.x / STUD), _n(at.y / PLATE), _n(at.z / STUD)]


static func _n(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
