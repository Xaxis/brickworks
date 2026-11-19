## A model checked against a real set's own model, change by change
## (setcheck, APP_UX10 #4): every part of the set taken away, every part
## added, painted another colour, swapped for another mould, moved (a stud is
## enough) or put in another sub-model, each named by the step the set's
## author put it on in and by where it is in the model: its sub-model and the
## line of its file.
##
## A person who builds a set, or changes one, asks what is not as the set has
## it and where. Compare with a set (PartsCompare) counts pieces by part and
## colour, with no step and no place: a part moved a stud, or put in the
## wrong sub-model, is no change to it at all. ModelDiff compares a model
## with its own saves, by place. This compares it with the set's file from
## the library (LDraw's model of it, stepped by its author as the booklet
## is), by place and by the line each part was read from.
##
## Matched, the fewest changes first:
##
##   0. where the model is the set's own file opened (its lines are the
##      set's), a part on the baseplate is the set's part of the line it was
##      read from (BrickWorld.Brick.origin), whatever was done to it since:
##      exact, so of ten 1 x 2 plates in a row the one moved a stud is that
##      one, by its line;
##   1. the same part in the same colour where one of the set's stands, turned
##      the same way, is that one;
##   2. the same part there in another colour was recoloured;
##   3. a near mould there (another moulding of the number, 3794a for 3794b,
##      or a part of the same kind, size and studs: Collection's rules) was
##      swapped for it;
##   4. the same part in the same colour anywhere else was moved, the nearest
##      first; then the same part in another colour within three studs,
##      moved and recoloured;
##   5. any other part where one of the set's stood was swapped for it;
##   6. what is left of the set's was taken away, and of the model's added.
##
## A pair is then each thing that differs: its number, its colour, its place
## or turn, its sub-model. A model of no sub-models built from a set of some
## is compared without them (every part would be "in another sub-model"), and
## says so. Steps are not compared: an edit tidies a section's step numbers,
## and a part's step is how it is built, not what is built.
##
## A set's step is its author's, as its file numbers them and the booklet the
## file was drawn from does: step 12 of the model, or step 3 of the Wing,
## which goes on in step 12. Read only: nothing here changes the model, its
## file or whether it is saved.
class_name SetCheck
extends RefCounted

const TAKEN := "taken"
const ADDED := "added"
const SWAPPED := "swapped"
const RECOLOURED := "recoloured"
const MOVED := "moved"
const REGROUPED := "regrouped"
## In the order the counts are said.
const KINDS: Array[String] = [TAKEN, ADDED, SWAPPED, RECOLOURED, MOVED, REGROUPED]
## A part this near where the set's stood, LDU, stands where it stood
## (ModelDiff's), and turned the same way within this.
const NEAR := 0.5
const SAME_TURN := 0.01
## A part of the set's number in another colour this near, LDU, is that part
## moved and recoloured; further off it is one taken away and one added.
const RECOLOURED_NEAR := 60.0
## A set's file this long or longer is read on a worker, as an open reads it
## (ModelStore.READ_OFF_FRAME_FROM): 8466-1's 36 MB is over a second.
const READ_OFF_FRAME_FROM := 262144
## Parts on both sides from which the matching is done on a worker, the
## window drawing meanwhile: 10179's 9,000 were more than a frame's work.
const MATCH_OFF_FRAME_FROM := 1500
## A set's number is short ("10294-1", "910003-1"); longer is not one.
const LONGEST_NUMBER := 24
## How far down a file its main model's name is looked for.
const HEAD_LINES := 12


## One part, on one side.
class Part extends RefCounted:
	var part_id: String = ""
	var colour: int = 0
	## Where it stands, in the file's own coordinates (LDU, Godot's axes).
	var at: Transform3D = Transform3D.IDENTITY
	## The copy of the sub-model it is in (Assemblies' path), "" for the model.
	var path: String = ""
	## Its step within the section its steps are counted in, from 0; -1 for
	## none given.
	var step: int = -1
	## The line of the file it was read from, from 0; -1 for a part put down
	## here, which no file has yet.
	var line: int = -1
	## Its place in the file (LdrModel.Placement.origin), "" for none.
	var origin: String = ""
	## The brick on the baseplate it is; 0 for the set's.
	var id: int = 0


## One side as read: its parts, the step each copy of a sub-model goes on in
## (LdrModel.unit_steps, BrickWorld.unit_steps), and what could not be.
class Reading extends RefCounted:
	var parts: Array = []
	var unit_steps: Dictionary = {}
	## Whether its file has steps at all.
	var stepped: bool = true
	## Its file's line count and a sample of its lines ([method is_same_file]),
	## for the set: to know the model is that file opened. Not the whole: a
	## 36 MB file's lines stay off the heap.
	var line_count: int = 0
	var sample: PackedStringArray = PackedStringArray()
	## Parts of it no part of this app's library is: not compared.
	var unknown: int = 0
	## The model's parts its file holds that are not on the baseplate (a part
	## not in the library, a flexible part's skin: ModelStore.unshown), by
	## number, how many: not taken away.
	var held: Dictionary = {}
	## Why it could not be read; "" when it was.
	var trouble: String = ""

	func in_sub_models() -> bool:
		for part: Part in parts:
			if not part.path.is_empty():
				return true
		return false


## One change: [member was] the set's part (null for one added), [member now]
## the model's (null for one taken away).
class Change extends RefCounted:
	var kind: String = ""
	var was: Part = null
	var now: Part = null
	## What else differs, beside [member kind].
	var swapped: bool = false
	var near_mould: bool = false
	var recoloured: bool = false
	var moved: bool = false
	var turned: bool = false
	var by: float = 0.0
	var regrouped: bool = false
	## The set's step it is in, outermost first: [[section path, step], …].
	var chain: Array = []


## What the model was checked against: "7140-1 X-wing Fighter", "7140-1".
var set_name: String = ""
var set_short: String = ""
## Every change, by the set's steps in order.
var changes: Array[Change] = []
var set_parts: int = 0
var model_parts: int = 0
## Whether the model is the set's own file opened, its lines the set's.
var same_file: bool = false
## Whether sub-models were compared (both have some).
var groups_compared: bool = true
## Whether the set's file has steps.
var stepped: bool = true
## The set's parts this app cannot show, not compared; and those the
## model's file holds and does not show, not taken away.
var unknown: int = 0
var held: int = 0
## How far the model was found moved whole from where the set stands, LDU,
## and so compared as though it stood there.
var shifted: Vector3 = Vector3.ZERO
var matched_ms: float = 0.0
## How long the model on the baseplate took to read, ms (on the frame).
var read_ms: float = 0.0
var _set_steps: Dictionary = {}
var _model_steps: Dictionary = {}


# -- reading the two sides -------------------------------------------------------


## The parts a set's file [param text] puts down, as the app opens it
## (ModelDiff.parts_of_text, keeping each part's step, line and place in the
## file); a part this app's library has no part of is counted, not kept.
static func read_set(text: String, library: PartLibrary, name: String = "set") -> Reading:
	var side := Reading.new()
	var model: LdrModel = LdrModel.parse(text, name)
	if model == null:
		side.trouble = "its file is not a model"
		return side
	# A flexible part LDCad generated (a hose, a rope) is one part, its skin,
	# as the open puts it on the baseplate; read as its hundred pieces it
	# was none, and the model's own read as added (6080-1, 10179-1).
	CustomParts.put_skins(library, model)
	var lines: PackedStringArray = text.split("\n")
	side.line_count = lines.size()
	for n: int in range(0, lines.size(), _stride(lines.size())):
		side.sample.append(lines[n])
	side.stepped = model.stepped
	for placement: LdrModel.Placement in model.flatten(library.parts):
		placement.part_id = ModelStore.studio_part(placement.part_id, library)
		if placement.mirrored:
			Assemblies.unmirror(placement, library)
		ModelStore.as_moved(placement, library)
		var colour: int = library.current_colour(placement.part_id)
		if colour >= 0:
			placement.part_id = library.current(placement.part_id)
			placement.color_code = colour
		if not library.parts.has(placement.part_id):
			side.unknown += 1
			continue
		var part := Part.new()
		part.part_id = placement.part_id
		part.colour = placement.color_code
		part.at = placement.transform
		part.path = Assemblies.path_from(placement.group, placement.unit)
		part.step = placement.step
		part.line = placement.line
		part.origin = placement.origin
		side.parts.append(part)
	side.unit_steps = model.unit_steps.duplicate()
	return side


## [method read_set] on a worker for a big file, the frames going on; at once
## for a small one.
static func read_set_paced(text: String, library: PartLibrary, name: String = "set") -> Reading:
	if text.length() < READ_OFF_FRAME_FROM:
		return read_set(text, library, name)
	return await WorkerTasks.awaited(func() -> Reading: return read_set(text, library, name),
		"read a set's file to check a model against", library)


## The model on the baseplate as its file has it (ModelDiff.parts_of_world):
## every part but the baseplate's, where it stands as built less the lift it
## was opened with, and those still on their way; each with its step, and its
## line where it was read from a file.
static func read_model(world: BrickWorld, store: ModelStore) -> Reading:
	var side := Reading.new()
	var back := Transform3D(Basis.IDENTITY, -store.lift())
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if store.scenery.has(brick.id):
			continue
		var part := Part.new()
		part.part_id = brick.part_id
		part.colour = brick.color_code
		part.at = back * world.home_of(brick)
		part.path = Assemblies.path_of(brick)
		part.step = brick.step
		part.origin = brick.origin
		part.line = line_of(brick.origin)
		part.id = brick.id
		side.parts.append(part)
	for item: Variant in store.awaited_now():
		var placement: LdrModel.Placement = item
		var part := Part.new()
		part.part_id = placement.part_id
		part.colour = placement.color_code
		part.at = back * placement.transform
		part.path = Assemblies.path_from(placement.group, placement.unit)
		part.step = placement.step
		part.origin = placement.origin
		part.line = placement.line
		side.parts.append(part)
	side.unit_steps = world.unit_steps.duplicate()
	side.held = store.unshown.duplicate()
	return side


## The line a place in a file names ("12/40/7": its own is the last), from
## 0; -1 for none.
static func line_of(origin: String) -> int:
	if origin.is_empty():
		return -1
	var last: String = origin.get_slice("/", origin.count("/"))
	return int(last) if last.is_valid_int() else -1


## Whether [param opened], the lines of the file the model was opened from
## (ModelStore.opened_lines), are the set's: as many, and nearly all the same
## (an Update all of moved numbers rewrites a few in place).
static func is_same_file(opened: PackedStringArray, on_set: Reading) -> bool:
	if opened.is_empty() or opened.size() != on_set.line_count:
		return false
	var stride: int = _stride(opened.size())
	var same: int = 0
	for k: int in on_set.sample.size():
		if k * stride < opened.size() and opened[k * stride] == on_set.sample[k]:
			same += 1
	return same * 100 >= on_set.sample.size() * 95


static func _stride(lines: int) -> int:
	return maxi(1, lines / 400)


# -- the set it is checked against ------------------------------------------------


## The set the model was opened from, or carries as a saved meta line
## (ModelStore.from_set), or its file's main model is named by: "7140-1";
## "" for none.
static func own_set(store: ModelStore) -> String:
	if store == null:
		return ""
	if not store.from_set.is_empty() and store.from_set != "set":
		return SetInventories.normal(store.from_set)
	# The model repository names a file's main model by its set, "0 FILE
	# 6399 - main.ldr", in files with no !LDRAW_ORG line for the store to
	# read the set from (6399-1, 6542-1).
	var lines: PackedStringArray = store.opened_lines()
	var named := RegEx.create_from_string(
		"^0\\s+(?:FILE|Name:)\\s*([0-9]{3,7}(?:-[0-9]+)?)(?:[ ._]|$)")
	for n: int in mini(lines.size(), HEAD_LINES):
		var found: RegExMatch = named.search(lines[n].strip_edges())
		if found != null:
			return SetInventories.normal(found.get_string(1))
	return ""


## The library's model of the set [param asked] names ("7140", "7140-1" or
## a library id, omr-7140-1): {"entry", "text", "error"}, the error in words
## for a person. Fetched as File, Open, From the library fetches it.
static func fetch(asked: String, models: ModelLibrary, job: Working.Job = null) -> Dictionary:
	var given: String = typed_number(asked)
	if given.is_empty():
		return {"entry": {}, "text": "", "error": "Name the set: its number, as on its box (7140 or 7140-1)."}
	if given.length() > LONGEST_NUMBER or given.contains(" "):
		return {"entry": {}, "text": "", "error": ("That is not a set's number: it is written as on "
			+ "the box, 7140 or 7140-1.")}
	if models == null:
		return {"entry": {}, "text": "", "error": "The library of sets cannot be reached from here."}
	var id: String = given if ModelLibrary.is_id(given) else "omr-" + SetInventories.normal(given)
	var got: Dictionary = await models.fetch_model(id, job)
	if (got["entry"] as Dictionary).is_empty():
		# The index may file the set under another id: look for its number.
		var number: String = SetInventories.normal(given)
		for entry: Dictionary in await models.models():
			if str(entry.get("set", "")) == number:
				got = await models.fetch_model(str(entry["id"]), job)
				break
	if (got["entry"] as Dictionary).is_empty():
		return {"entry": {}, "text": "", "error": "The library has no model of set %s: %s" % [given,
			"it has the sets LDraw's model repository has (File, Open, From the library… lists them)."]}
	return got


## A set's number as typed or pasted, its spaces of every kind and the
## characters nobody sees taken off its ends and out of it: a number copied
## from a web page carries a no-break space or a zero-width one.
static func typed_number(asked: String) -> String:
	var out: String = ""
	for n: int in asked.length():
		var code: int = asked.unicode_at(n)
		if code in [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF]:
			continue
		out += " " if code in [0x00A0, 0x2007, 0x202F, 0x3000] or (code >= 0x2000 and code <= 0x200A) \
			else asked[n]
	return out.strip_edges()


## The last set read ([method reading_of]): its library id and what was read.
static var _read_id: String = ""
static var _read: Reading = null


## The set's file read ([method read_set_paced]), kept for the next check: a
## check again after an edit reads only the model.
static func reading_of(entry: Dictionary, text: String, library: PartLibrary) -> Reading:
	var id: String = str(entry.get("id", ""))
	if not id.is_empty() and id == _read_id and _read != null:
		return _read
	var side: Reading = await read_set_paced(text, library, str(entry.get("set", "set")))
	if side.trouble.is_empty():
		_read_id = id
		_read = side
	return side


## The model on the baseplate checked against [param on_set], the set's file
## read, of the library's [param entry].
## Read on the frame, as the baseplate is; matched on a worker for a big model,
## the window drawing meanwhile. A coroutine.
static func of_model(on_set: Reading, entry: Dictionary, world: BrickWorld, store: ModelStore,
		library: PartLibrary) -> SetCheck:
	var began: int = Time.get_ticks_usec()
	var model: Reading = read_model(world, store)
	var read_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	var same: bool = is_same_file(store.opened_lines(), on_set)
	var check: SetCheck
	if on_set.parts.size() + model.parts.size() < MATCH_OFF_FRAME_FROM:
		check = between(on_set, model, library, same)
	else:
		check = await WorkerTasks.awaited(func() -> SetCheck: return between(on_set, model, library, same),
			"check a model against its set", library)
	check.read_ms = read_ms
	check.set_name = ModelLibrary.title_of(entry)
	check.set_short = str(entry.get("set", ""))
	return check


## The whole check, as File, Compare, Compare with the set… and compare_with_set run
## it: the set fetched and read with the status bar saying so (a big set's
## file is read on a worker), then the model checked: {"check": SetCheck or
## null, "error": words}.
static func run(asked: String, models: ModelLibrary, world: BrickWorld, store: ModelStore,
		library: PartLibrary) -> Dictionary:
	var job: Working.Job = Working.begin("Checking the model against set %s…" % asked.strip_edges())
	var got: Dictionary = await fetch(asked, models, job)
	if not str(got["error"]).is_empty():
		job.end()
		return {"check": null, "error": str(got["error"])}
	job.say("Reading %s's own model…" % ModelLibrary.title_of(got["entry"]))
	var side: Reading = await reading_of(got["entry"], str(got["text"]), library)
	if not side.trouble.is_empty():
		job.end()
		return {"check": null, "error": "Could not read %s: %s." % [ModelLibrary.title_of(got["entry"]),
			side.trouble]}
	job.say("Checking the model against %s…" % ModelLibrary.title_of(got["entry"]))
	var check: SetCheck = await of_model(side, got["entry"], world, store, library)
	job.end()
	return {"check": check, "error": "", "side": side, "entry": got["entry"]}


# -- the check -------------------------------------------------------------------


## [param model] against [param on_set]: every change.
static func between(on_set: Reading, model: Reading, library: PartLibrary, same: bool) -> SetCheck:
	var began: int = Time.get_ticks_usec()
	var check := SetCheck.new()
	check.set_parts = on_set.parts.size()
	check.model_parts = model.parts.size()
	check.same_file = same
	check.stepped = on_set.stepped
	check.unknown = on_set.unknown
	check._set_steps = on_set.unit_steps
	check._model_steps = model.unit_steps
	check.groups_compared = on_set.in_sub_models() and model.in_sub_models()
	var was: Array = on_set.parts.duplicate()
	var now: Array = model.parts.duplicate()
	var pairs: Array = []
	# 0. By the line each was read from, where those are the set's lines.
	if same:
		var by_origin: Dictionary = {}
		for n: int in was.size():
			if not (was[n] as Part).origin.is_empty():
				by_origin[(was[n] as Part).origin] = n
		for m: int in now.size():
			var n: int = int(by_origin.get((now[m] as Part).origin, -1))
			if n >= 0 and was[n] != null:
				pairs.append([was[n], now[m]])
				was[n] = null
				now[m] = null
	else:
		check.shifted = _shift(was, now)
		if check.shifted != Vector3.ZERO:
			now = _moved_by(now, -check.shifted)
	# 1-3. Where one of the set's stood.
	_pair_in_place(was, now, pairs, func(a: Part, b: Part) -> bool:
		return a.part_id == b.part_id and a.colour == b.colour)
	_pair_in_place(was, now, pairs, func(a: Part, b: Part) -> bool:
		return a.part_id == b.part_id)
	_pair_in_place(was, now, pairs, func(a: Part, b: Part) -> bool:
		return near_mould(a.part_id, b.part_id, library))
	# 4. The same part elsewhere.
	_pair_anywhere(was, now, pairs, true, INF)
	_pair_anywhere(was, now, pairs, false, RECOLOURED_NEAR)
	# 5. Another part where one of the set's stood.
	_pair_in_place(was, now, pairs, func(_a: Part, _b: Part) -> bool: return true)
	for pair: Array in pairs:
		var change: Change = check._compared(pair[0], pair[1], library)
		if change != null:
			check.changes.append(change)
	# 6. What is left: of the set's, what the model's file holds and does not
	# show is not taken away.
	var held: Dictionary = model.held.duplicate()
	for part: Part in was:
		if part != null and int(held.get(part.part_id, 0)) > 0:
			held[part.part_id] = int(held[part.part_id]) - 1
			check.held += 1
			continue
		if part != null:
			var change := Change.new()
			change.kind = TAKEN
			change.was = part
			change.chain = chain_of(part.path, part.step, on_set.unit_steps)
			check.changes.append(change)
	for part: Part in now:
		if part != null:
			var change := Change.new()
			change.kind = ADDED
			change.now = part
			change.chain = chain_of(part.path, part.step, model.unit_steps)
			check.changes.append(change)
	check.changes.sort_custom(_in_step_order)
	check.matched_ms = (Time.get_ticks_usec() - began) / 1000.0
	return check


## The change one pair is, or null when it is none.
func _compared(was: Part, now: Part, library: PartLibrary) -> Change:
	var change := Change.new()
	change.was = was
	change.now = now
	change.swapped = was.part_id != now.part_id
	change.near_mould = change.swapped and near_mould(was.part_id, now.part_id, library)
	change.recoloured = was.colour != now.colour
	change.by = was.at.origin.distance_to(now.at.origin)
	change.turned = not _same_turn(was.at.basis, now.at.basis)
	change.moved = change.by >= NEAR or change.turned
	change.regrouped = groups_compared and was.path != now.path
	if change.swapped:
		change.kind = SWAPPED
	elif change.recoloured:
		change.kind = RECOLOURED
	elif change.moved:
		change.kind = MOVED
	elif change.regrouped:
		change.kind = REGROUPED
	else:
		return null
	change.chain = chain_of(was.path, was.step, _set_steps)
	return change


## Whether [param a] and [param b] are near moulds of one part: another
## moulding of its number (3794a, 3794b: Collection.family_of), or a part of
## the same kind, size and studs (Collection's other mould or print).
static func near_mould(a: String, b: String, library: PartLibrary) -> bool:
	if a == b:
		return false
	if Collection.family_of(a) == Collection.family_of(b):
		return true
	var shape: Variant = Collection._shape(a, library)
	return shape != null and shape == Collection._shape(b, library)


static func _same_turn(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) <= SAME_TURN and a.y.distance_to(b.y) <= SAME_TURN \
		and a.z.distance_to(b.z) <= SAME_TURN


static func _cell(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))


## Each part of [param now] paired with one of [param was] standing where it
## stands, turned the same way, that [param alike] says may be it; both taken
## out of their lists. Looked up by the whole LDU each stands in, and the
## cells round it.
static func _pair_in_place(was: Array, now: Array, pairs: Array, alike: Callable) -> void:
	var at: Dictionary = {}     ## cell -> indexes into was
	for n: int in was.size():
		if was[n] == null:
			continue
		var cell: Vector3i = _cell((was[n] as Part).at.origin)
		if not at.has(cell):
			at[cell] = []
		(at[cell] as Array).append(n)
	if at.is_empty():
		return
	for m: int in now.size():
		var part: Part = now[m]
		if part == null:
			continue
		var cell: Vector3i = _cell(part.at.origin)
		var found: int = _found_at(at, cell, was, part, alike)
		if found < 0:
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						if found < 0 and (dx != 0 or dy != 0 or dz != 0):
							found = _found_at(at, cell + Vector3i(dx, dy, dz), was, part, alike)
		if found >= 0:
			pairs.append([was[found], part])
			was[found] = null
			now[m] = null


static func _found_at(at: Dictionary, cell: Vector3i, was: Array, part: Part, alike: Callable) -> int:
	for n: int in at.get(cell, []):
		var other: Part = was[n]
		if other == null:
			continue
		if other.at.origin.distance_to(part.at.origin) < NEAR \
				and _same_turn(other.at.basis, part.at.basis) and bool(alike.call(other, part)):
			return n
	return -1


## Of what is left, each of [param was] paired with the nearest of [param now]
## of its number, in its colour when [param same_colour] (else in another),
## no further than [param within] LDU: as many as both sides have.
static func _pair_anywhere(was: Array, now: Array, pairs: Array, same_colour: bool,
		within: float) -> void:
	var groups: Dictionary = {}  ## key -> [indexes into was, indexes into now]
	for n: int in was.size():
		if was[n] != null:
			var key: String = _group_key(was[n], same_colour)
			if not groups.has(key):
				groups[key] = [[], []]
			(groups[key][0] as Array).append(n)
	if groups.is_empty():
		return
	for m: int in now.size():
		if now[m] != null:
			var key: String = _group_key(now[m], same_colour)
			if groups.has(key):
				(groups[key][1] as Array).append(m)
	for key: String in groups:
		var olds: Array = groups[key][0]
		var news: Array = groups[key][1]
		if olds.is_empty() or news.is_empty():
			continue
		if olds.size() * news.size() > ModelDiff.PAIRS_WEIGHED:
			# Too many to weigh every pair: in order along the model.
			olds = _along(was, olds)
			news = _along(now, news)
			for k: int in mini(olds.size(), news.size()):
				var a: Part = was[olds[k]]
				var b: Part = now[news[k]]
				if (same_colour or a.colour != b.colour) and a.at.origin.distance_to(b.at.origin) <= within:
					pairs.append([a, b])
					was[olds[k]] = null
					now[news[k]] = null
			continue
		var weighed: Array = []
		for n: int in olds:
			for m: int in news:
				var a: Part = was[n]
				var b: Part = now[m]
				if not same_colour and a.colour == b.colour:
					continue
				var d: float = a.at.origin.distance_to(b.at.origin)
				if d <= within:
					weighed.append([d, n, m])
		weighed.sort()
		for one: Array in weighed:
			var n: int = one[1]
			var m: int = one[2]
			if was[n] != null and now[m] != null:
				pairs.append([was[n], now[m]])
				was[n] = null
				now[m] = null


static func _group_key(part: Part, same_colour: bool) -> String:
	return "%s|%d" % [part.part_id, part.colour] if same_colour else part.part_id


static func _along(parts: Array, of: Array) -> Array:
	var keyed: Array = []
	for n: int in of:
		var at: Vector3 = (parts[n] as Part).at.origin
		keyed.append([at.x, at.z, at.y, n])
	keyed.sort()
	return keyed.map(func(one: Array) -> int: return int(one[3]))


## How far the model stands whole from where the set does, LDU: a set built
## by hand anywhere on the baseplate, or opened from another file, is
## compared where it stands. Read off the set's rarest parts, each of its
## few copies against the model's: the offset most of them agree on, kept
## only when more parts stand in place by it than without it.
static func _shift(was: Array, now: Array) -> Vector3:
	if was.is_empty() or now.is_empty():
		return Vector3.ZERO
	var of_set: Dictionary = {}
	var of_model: Dictionary = {}
	for part: Part in was:
		var key: String = _group_key(part, true)
		if not of_set.has(key):
			of_set[key] = []
		(of_set[key] as Array).append(part)
	for part: Part in now:
		var key: String = _group_key(part, true)
		if of_set.has(key):
			if not of_model.has(key):
				of_model[key] = []
			(of_model[key] as Array).append(part)
	var keys: Array = of_model.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return (of_set[a] as Array).size() * (of_model[a] as Array).size() \
			< (of_set[b] as Array).size() * (of_model[b] as Array).size())
	var votes: Dictionary = {}
	var weighed: int = 0
	for key: String in keys:
		if (of_set[key] as Array).size() * (of_model[key] as Array).size() > 400:
			break
		for a: Part in of_set[key]:
			for b: Part in of_model[key]:
				if not _same_turn(a.at.basis, b.at.basis):
					continue
				var offset: Vector3i = _cell(b.at.origin - a.at.origin)
				votes[offset] = int(votes.get(offset, 0)) + 1
				weighed += 1
		if weighed > 4000:
			break
	var best: Vector3i = Vector3i.ZERO
	for offset: Vector3i in votes:
		if int(votes[offset]) > int(votes.get(best, 0)):
			best = offset
	if best == Vector3i.ZERO or int(votes[best]) < 3:
		return Vector3.ZERO
	var by := Vector3(best)
	return by if _in_place_count(was, _moved_by(now, -by)) > _in_place_count(was, now) else Vector3.ZERO


static func _moved_by(parts: Array, by: Vector3) -> Array:
	var out: Array = []
	for item: Variant in parts:
		if item == null:
			out.append(null)
			continue
		var part: Part = item
		var moved := Part.new()
		moved.part_id = part.part_id
		moved.colour = part.colour
		moved.at = Transform3D(part.at.basis, part.at.origin + by)
		moved.path = part.path
		moved.step = part.step
		moved.line = part.line
		moved.origin = part.origin
		moved.id = part.id
		out.append(moved)
	return out


static func _in_place_count(was: Array, now: Array) -> int:
	var cells: Dictionary = {}
	for part: Part in was:
		if part != null:
			cells["%s|%d|%s" % [part.part_id, part.colour, _cell(part.at.origin)]] = true
	var count: int = 0
	for part: Part in now:
		if part != null and cells.has("%s|%d|%s" % [part.part_id, part.colour, _cell(part.at.origin)]):
			count += 1
	return count


# -- the set's steps -------------------------------------------------------------


## The step a part in [param path] at [param step] goes on in, outermost
## first: [["", 11]] for the model's step 12, [["", 11], ["Wing#1", 2]] for
## the Wing's step 3, the Wing going on in step 12. A copy built in the steps
## of the one round it (LdrModel.IN_PARENT) is counted in that one's.
static func chain_of(path: String, step: int, unit_steps: Dictionary) -> Array:
	var home: String = _home(path, unit_steps)
	var out: Array = [[home, step]]
	while not home.is_empty():
		var on: int = int(unit_steps.get(home, 0))
		home = _home(Assemblies.parent_of(home), unit_steps)
		out.push_front([home, on])
	return out


static func _home(path: String, unit_steps: Dictionary) -> String:
	var home: String = path
	while not home.is_empty() and int(unit_steps.get(home, 0)) == LdrModel.IN_PARENT:
		home = Assemblies.parent_of(home)
	return home


static func _in_step_order(a: Change, b: Change) -> bool:
	var n: int = mini(a.chain.size(), b.chain.size())
	for k: int in n:
		var p: String = str(a.chain[k][0])
		var q: String = str(b.chain[k][0])
		if p != q:
			return p < q
		if int(a.chain[k][1]) != int(b.chain[k][1]):
			return int(a.chain[k][1]) < int(b.chain[k][1])
	if a.chain.size() != b.chain.size():
		# A sub-model's steps are built before the step that puts it on.
		return a.chain.size() > b.chain.size()
	return KINDS.find(a.kind) < KINDS.find(b.kind)


## "step 12", "step 3 of the Wing, which goes on in step 12": the step of
## [param chain] ([method chain_of]) as a booklet's reader finds it.
func step_words(chain: Array) -> String:
	if chain.is_empty():
		return ""
	var last: Array = chain[chain.size() - 1]
	var said: String = "step %d" % (maxi(int(last[1]), 0) + 1)
	if str(last[0]).is_empty():
		return said
	said += " of the %s" % Assemblies.label(str(last[0]))
	if chain.size() > 1:
		var outer: Array = chain.slice(0, chain.size() - 1)
		said += ", which goes on in " + step_words(outer)
	return said


## The step a change is in, said: the set's, for a part the set has.
func step_of(change: Change) -> String:
	if not stepped:
		return "the set's file has no steps"
	if change.was == null and change.now != null and change.now.step < 0:
		return "a step of its own, after the set's"
	return step_words(change.chain)


# -- what it says ----------------------------------------------------------------


## How many changes of [param kind].
func count(kind: String) -> int:
	var n: int = 0
	for change: Change in changes:
		if change.kind == kind:
			n += 1
	return n


## Whether the model is the set, part for part.
func matches() -> bool:
	return changes.is_empty()


## "3 taken away, 2 swapped, 2 recoloured, 1 moved, 1 in another
## sub-model", or "it matches the set".
func summary() -> String:
	if changes.is_empty():
		return "it matches the set, part for part"
	var said := PackedStringArray()
	for kind: String in KINDS:
		var n: int = count(kind)
		if n > 0:
			said.append("%d %s" % [n, kind_words(kind)])
	return ", ".join(said)


static func kind_words(kind: String) -> String:
	match kind:
		TAKEN:
			return "taken away"
		ADDED:
			return "added"
		SWAPPED:
			return "swapped"
		RECOLOURED:
			return "recoloured"
		MOVED:
			return "moved"
	return "in another sub-model"


## What a change is: "Taken away: Plate 1 x 2 in Red", "Swapped Jumper
## Plate 1 x 2 for 3794b, a near mould", "Moved 1 stud: Brick 1 x 2 in
## Blue", "Put in the Wing (copy 2): Tile 1 x 1 in White".
func words(change: Change, library: PartLibrary) -> String:
	var was: Part = change.was
	var now: Part = change.now
	match change.kind:
		TAKEN:
			return "Taken away: %s in %s" % [_name(library, was.part_id), _colour(library, was.colour)]
		ADDED:
			return "Added: %s in %s" % [_name(library, now.part_id), _colour(library, now.colour)]
	var said := PackedStringArray()
	var what: String = "%s in %s" % [_name(library, was.part_id), _colour(library, was.colour)]
	if change.swapped:
		said.append("Swapped %s (%s) for %s (%s)%s" % [_name(library, was.part_id), was.part_id,
			_name(library, now.part_id), now.part_id, ", a near mould" if change.near_mould else ""])
		what = ""
	if change.recoloured:
		said.append(("recoloured %s to %s" if not said.is_empty() else "Recoloured %s to %s")
			% [_colour(library, was.colour), _colour(library, now.colour)])
		if not what.is_empty():
			what = _name(library, was.part_id)
	if change.moved:
		var moved: String = moved_words(change)
		said.append(moved if said.is_empty() else moved.to_lower())
	if change.regrouped:
		said.append(("Put in %s" if said.is_empty() else "put in %s") % where_words(now.path))
	return " and ".join(said) + (": " + what if not what.is_empty() else "")


## "Moved 1 stud", "Turned 90°", "Moved 2 plates and turned 180°".
static func moved_words(change: Change) -> String:
	var said := PackedStringArray()
	if change.by >= NEAR:
		said.append("Moved " + distance_words(change.now.at.origin - change.was.at.origin))
	if change.turned:
		var turn: Basis = change.now.at.basis * change.was.at.basis.inverse()
		var angle: int = roundi(rad_to_deg(turn.get_rotation_quaternion().get_angle()))
		said.append(("turned %d°" if not said.is_empty() else "Turned %d°") % angle)
	return " and ".join(said)


## A step in studs and plates as a builder counts it: "1 stud", "3
## plates", "1 stud and 1 plate"; in LDU when it is neither.
static func distance_words(step: Vector3) -> String:
	var across: float = Vector2(step.x, step.z).length() / 20.0
	var up: float = absf(step.y) / 8.0
	var said := PackedStringArray()
	for pair: Array in [[across, "stud"], [up, "plate"]]:
		var n: float = pair[0]
		if n < 0.05:
			continue
		var whole: bool = is_equal_approx(n, roundf(n))
		said.append("%s %s%s" % [str(roundi(n)) if whole else "%.1f" % n, pair[1],
			"" if whole and roundi(n) == 1 else "s"])
	return " and ".join(said) if not said.is_empty() else "%.1f LDU" % step.length()


## A sub-model's copy as a person reads it: "the Wing (copy 2)", or "the
## main model".
static func where_words(path: String) -> String:
	return "the main model" if path.is_empty() else "the " + Assemblies.label(path)


## Where a change is in the model: its sub-model and the line of its file,
## "the Wing (copy 2), line 412". A part taken away is where the set has
## it: on that line of the model's file where the model is the set's file
## opened, else of the set's. A part put down here has no line yet.
func place_words(change: Change) -> String:
	if change.now == null:
		return "%s, line %d of the %s" % [where_words(change.was.path), change.was.line + 1,
			"model's file, the set's own" if same_file else "set's file"]
	if change.now.line < 0:
		if change.was != null and same_file:
			# A part swapped in where the set's stood: on that part's line.
			return "%s, line %d, where the set's part was" % [where_words(change.now.path),
				change.was.line + 1]
		return "%s, a new part, on no line of the file yet" % where_words(change.now.path)
	return "%s, line %d" % [where_words(change.now.path), change.now.line + 1]


## What a change is and where, on one line: what the panel's row and a
## session read.
func line_words(change: Change, library: PartLibrary) -> String:
	var said: String = "%s · %s" % [words(change, library), place_words(change)]
	if change.now != null and change.now.id != 0:
		said += " (#%d)" % change.now.id
	return said


## The changes by the set's steps, in order: [[the step said, [Change…]], …].
func by_step() -> Array:
	var out: Array = []
	var last: String = ""
	for change: Change in changes:
		var step: String = step_of(change)
		if out.is_empty() or step != last:
			out.append([step, []])
			last = step
		(out[out.size() - 1][1] as Array).append(change)
	return out


## The heading: "Checked against 7140-1 X-wing Fighter: 352 parts in the set,
## 349 in the model. 9 changes: …".
func heading() -> String:
	var said: String = "Checked against %s: %s in the set, %d in the model." % [set_name,
		Counted.of(set_parts, "part"), model_parts]
	if changes.is_empty():
		return said + " It matches the set, part for part."
	return said + " %s: %s." % [Counted.of(changes.size(), "change"), summary()]


## What a session reads (compare_with_set): the heading, what was not
## compared, then every change by the set's step, each with the part's
## number on the baseplate, and how to put it as the set has it.
func said(library: PartLibrary, most: int = 60) -> String:
	var lines := PackedStringArray([heading()])
	lines.append_array(notes())
	if changes.is_empty():
		return "\n".join(lines)
	lines.append("By the set's own steps:")
	var listed: int = 0
	for group: Array in by_step():
		if listed >= most:
			break
		lines.append("%s:" % (str(group[0]).left(1).to_upper() + str(group[0]).substr(1)))
		for change: Change in group[1]:
			if listed >= most:
				break
			lines.append("  %s%s" % [line_words(change, library), fix_words(change)])
			listed += 1
	if changes.size() > listed:
		lines.append("  …and %d more: most= lists more." % (changes.size() - listed))
	lines.append("Nothing was changed: a part on the baseplate is #N, as look_at_model numbers "
		+ "it; select or change it with edit_model. undo takes back the person's or your own "
		+ "last changes, a part taken away among them.")
	return "\n".join(lines)


## What was not compared, and how the two were laid side by side.
func notes() -> PackedStringArray:
	var out := PackedStringArray()
	if not stepped:
		out.append("The set's file has no steps, so each change is named by its sub-model and line.")
	if not groups_compared:
		out.append("The model has no sub-models (or the set none), so which sub-model a part is "
			+ "in is not compared.")
	if unknown > 0:
		out.append("%s of the set this app has no part for %s not compared." % [
			Counted.of(unknown, "part"), "is" if unknown == 1 else "are"])
	if held > 0:
		out.append("%s the model's file holds and does not show %s counted as there." % [
			Counted.of(held, "part"), "is" if held == 1 else "are"])
	if shifted != Vector3.ZERO:
		out.append("The model stands %s from where the set does, and is compared as though "
			% distance_words(shifted) + "it stood there.")
	return out


## How a session puts one back as the set has it: " → edit_model recolor
## bricks [12] color 4".
func fix_words(change: Change) -> String:
	if change.now == null or change.now.id == 0:
		return ""
	match change.kind:
		ADDED:
			return " → edit_model remove [%d]" % change.now.id
		SWAPPED:
			return " → replace_parts or edit_model: part %s, colour %d" % [change.was.part_id,
				change.was.colour]
		RECOLOURED:
			return " → edit_model recolor bricks [%d] color %d" % [change.now.id, change.was.colour]
		MOVED:
			if change.turned:
				return ""
			var back: Vector3 = change.was.at.origin - change.now.at.origin
			return " → edit_model move bricks [%d] dx %s dy %s dz %s" % [change.now.id,
				_num(back.x / 20.0), _num(back.y / 8.0), _num(back.z / 20.0)]
	return ""


static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value


static func _name(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return Inventory._tidy(info.name) if info != null else part_id


static func _colour(library: PartLibrary, code: int) -> String:
	return library.color(code).name.replace("_", " ") if library != null else str(code)
