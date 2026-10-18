## How the booklet shows each step, as its designer set it: the hand-made
## half of the booklet, kept with the model and in its file.
##
## The steps themselves are the author's (AuthorSteps). What a designer
## adjusts beyond them, in Studio's Instruction Maker or LPub, is how each
## is printed: the model turned round or tilted for a step whose work is
## at the back, zoomed in on a small part, a step started on a new page or
## given a page alone, drawn larger or smaller, its parts box left off, and
## a sub-assembly built in a callout box or on pages of its own. Before
## this the booklet decided all of that itself and none of it could be
## changed.
##
## Each choice is kept in BrickWorld.step_looks, by the step it is on:
## "<sub-model>|<step>" ("" for the model itself, a sub-model by the name
## its copies share, so every window's steps look alike), "<sub-model>|*"
## for the sub-model as a whole, and "|booklet" for the booklet. A step's
## own: {"turn": [x, y, z] degrees, "how": "REL"|"ABS"|"ADD", or "turn":
## "end", "zoom": float, "size": float, "page": "new"|"alone", "parts":
## false, "place": {item: [x, y, w, h]}, "notes": [note]}. A sub-model's:
## {"callout": false}. The booklet's: {"per_page": 1, 2 or 4, "highlight":
## false}. "|data": {name: base64} holds the pictures a page shows.
##
## The page laid out by hand: "place" puts the step's own items where its
## designer dragged them, in millimetres from the page's top left corner
## (Booklet.PAGE, 269 x 199): "picture" [x, y, w, h], "parts" [x, y, w]
## (as tall as its parts need), "callout" [x, y, w, h], "number" [x, y].
## An item not placed is laid out as the booklet lays it. "notes" are what
## a designer adds to the step's page: {"text": words, "at": [x, y, w, h],
## "size": mm} and {"image": name, "at": [x, y, w, h]}, the picture's bytes
## in "|data" under its name.
##
## In the file a turn is LDraw's own rotation step, which MLCad, LPub,
## LDCad and Studio read: the line that ends the step is
## "0 ROTSTEP x y z REL" instead of "0 STEP", and the turn holds for the
## steps after it until another, or "0 ROTSTEP END" puts the usual view
## back. Here x tilts the view up (degrees of pitch from the booklet's
## usual angle) and y turns it round (degrees of yaw), which for a turn
## alone is what LPub draws. The rest are the app's own lines inside the
## step, which other readers pass over: "0 !BRICKWORKS PAGE NEW", "... PAGE
## ALONE", "... ZOOM 1.5", "... SIZE 1.25", "... PARTS OFF", and in a
## sub-model "... CALLOUT OFF"; "... PER_PAGE 2" and "... HIGHLIGHT OFF" in
## the model. A page laid out by hand: "... PLACE PICTURE x y w h", "...
## PLACE PARTS x y w", "... PLACE CALLOUT x y w h", "... PLACE NUMBER x y",
## "... TEXT x y w h size words" (a line break written \n) and "... IMAGE x
## y w h name", the picture itself as LDraw's own embedded file, "0 !DATA
## name" with its base64 in "0 !:" lines, at the end of the file.
##
## Every change is one undo (Builder._apply "steplooks", the whole table
## as it was), and a step edit carries each step's look with the parts it
## had (follow).
class_name BookletLooks
extends RefCounted

const META := "0 !BRICKWORKS "
## The words of the app's own step lines, after META.
const WORDS: Array[String] = ["PAGE", "ZOOM", "SIZE", "PARTS", "CALLOUT", "PER_PAGE",
	"HIGHLIGHT", "PLACE", "TEXT", "IMAGE"]
const BOOKLET := "|booklet"
## The pictures a page shows, by name: {name: base64}.
const DATA := "|data"
## The items of a step a designer can place on its page, and how many
## numbers place each.
const ITEMS: Dictionary = {"picture": 4, "parts": 3, "callout": 4, "number": 2}
## The names a page's picture is kept under in the file, as LDraw's !DATA.
const IMAGE_PREFIX := "brickworks-page-"
const ZOOMS: Array[float] = [0.5, 0.67, 0.8, 1.0, 1.25, 1.5, 2.0, 3.0]
const SIZES: Array[float] = [0.6, 0.8, 1.0, 1.25, 1.5, 2.0]
## How far up or down a tilt may go, from level, in degrees.
const PITCH_MOST := 80.0


static func key(definition: String, step: int) -> String:
	return "%s|%d" % [definition, step]


## The name a section's steps are kept under: "" for the model, else the
## sub-model its copies share ("House#1/Window#3" -> "Window").
static func definition_of(section: String) -> String:
	return "" if section.is_empty() else Assemblies.definition(Assemblies.leaf(section))


## A step's own look: {} when it has none.
static func of(world: BrickWorld, section: String, step: int) -> Dictionary:
	if step < 0:
		return {}
	return world.step_looks.get(key(definition_of(section), step), {})


static func booklet(world: BrickWorld) -> Dictionary:
	return world.step_looks.get(BOOKLET, {})


## Whether the booklet marks the parts each step adds: on unless its
## designer turned it off.
static func highlight_on(world: BrickWorld) -> bool:
	return bool(booklet(world).get("highlight", true))


## The pictures a booklet's pages show, name -> base64.
static func images(world: BrickWorld) -> Dictionary:
	return world.step_looks.get(DATA, {})


static func callout_on(world: BrickWorld, section: String) -> bool:
	var whole: Dictionary = world.step_looks.get(definition_of(section) + "|*", {})
	return bool(whole.get("callout", true))


## The turn in force at [param step] of [param section]: the last one set at
## or before it ({"turn": [x, y, z], "how": ...}), or {} for the usual view
## (none, or "end").
static func turn_at(world: BrickWorld, section: String, step: int) -> Dictionary:
	if world.step_looks.is_empty() or step < 0:
		return {}
	var definition: String = definition_of(section)
	# The turned steps at or before it, read off the looks (a few), not
	# asked of every step before it: the step player asks on every page
	# turn, and a castle has a thousand steps.
	var head: String = definition + "|"
	var turned: Array = []
	for name: String in world.step_looks:
		if not name.begins_with(head):
			continue
		var tail: String = name.substr(head.length())
		if tail.is_valid_int() and tail.to_int() <= step \
				and (world.step_looks[name] as Dictionary).has("turn"):
			turned.append(tail.to_int())
	turned.sort()
	var found: Dictionary = {}
	var added := Vector3.ZERO
	for at: int in turned:
		var look: Dictionary = world.step_looks[key(definition, at)]
		if not look.has("turn"):
			continue
		if str(look["turn"]) == "end":
			found = {}
			added = Vector3.ZERO
			continue
		var turn: Vector3 = _vector(look["turn"])
		if str(look.get("how", "REL")) == "ADD":
			added += turn
			found = {"turn": [added.x, added.y, added.z], "how": "REL"}
		else:
			added = turn
			found = {"turn": [turn.x, turn.y, turn.z], "how": str(look.get("how", "REL"))}
	if found.is_empty() or _vector(found["turn"]).is_zero_approx() \
			and str(found["how"]) == "REL":
		return {}
	return found


## The direction a step is drawn from for a turn ([method turn_at]): the
## booklet's usual angle (BookletStudio.FRONT) turned round by y degrees
## and tilted by x; ABS from straight in front, LDraw's 0 0 0.
static func direction(turn: Dictionary) -> Vector3:
	var front: Vector3 = BookletStudio.FRONT.normalized()
	var yaw: float = atan2(front.x, front.z)
	var pitch: float = asin(front.y)
	var by: Vector3 = _vector(turn.get("turn", [0, 0, 0]))
	if str(turn.get("how", "REL")) == "ABS":
		yaw = 0.0
		pitch = 0.0
	yaw += deg_to_rad(by.y)
	pitch = clampf(pitch + deg_to_rad(by.x), deg_to_rad(-PITCH_MOST), deg_to_rad(PITCH_MOST))
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## The turn that draws a step from [param from] (a camera's direction to
## the eye): what Use this view keeps, in whole degrees.
static func turn_for(from: Vector3) -> Array:
	var front: Vector3 = BookletStudio.FRONT.normalized()
	var way: Vector3 = from.normalized()
	var yaw: float = rad_to_deg(atan2(way.x, way.z) - atan2(front.x, front.z))
	yaw = fposmod(yaw + 180.0, 360.0) - 180.0
	var pitch: float = rad_to_deg(asin(clampf(way.y, -1.0, 1.0)) - asin(front.y))
	return [float(roundi(pitch)), float(roundi(yaw)), 0.0]


## The sub-assembly step [param at] puts on, as the path of its first copy
## inside [param section], or "" for a step that puts none on.
static func attached(world: BrickWorld, at: Instructions.Step, section: String) -> String:
	if not at.attaches() or at.copies.is_empty() or at.copies[0].is_empty():
		return ""
	var brick: BrickWorld.Brick = world.get_brick(at.copies[0][0])
	if brick == null:
		return ""
	var depth: int = Assemblies.segments(section).size()
	var segments: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
	if segments.size() <= depth:
		return ""
	return Assemblies.join(section, segments[depth])


static func _vector(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO


# -- changing them -------------------------------------------------------------


## [param world]'s looks with [param change] made to the one at [param
## name] (a key): each field of it set, or taken off where it is null or
## the usual value. Returns the undo, empty when nothing changed.
static func change(world: BrickWorld, name: String, change: Dictionary) -> Array:
	var was: Dictionary = world.step_looks.duplicate(true)
	var look: Dictionary = (world.step_looks.get(name, {}) as Dictionary).duplicate(true)
	for field: String in change:
		var value: Variant = change[field]
		if value == null or _usual(field, value):
			look.erase(field)
			if field == "turn":
				look.erase("how")
				look.erase("line")
		else:
			look[field] = value
			if field == "turn":
				look.erase("line")
	if look.is_empty():
		world.step_looks.erase(name)
	else:
		world.step_looks[name] = look
	if world.step_looks == was:
		return []
	return [{"undo": "steplooks", "looks": was}]


## The pictures the pages show set to [param pictures] (name -> base64).
## Returns the undo, empty when nothing changed.
static func set_images(world: BrickWorld, pictures: Dictionary) -> Array:
	if images(world) == pictures:
		return []
	var was: Dictionary = world.step_looks.duplicate(true)
	if pictures.is_empty():
		world.step_looks.erase(DATA)
	else:
		world.step_looks[DATA] = pictures.duplicate()
	return [{"undo": "steplooks", "looks": was}]


static func _usual(field: String, value: Variant) -> bool:
	match field:
		"zoom", "size":
			return is_equal_approx(float(value), 1.0)
		"parts", "callout", "highlight":
			return bool(value)
		"place", "notes":
			return (value is Dictionary or value is Array) and value.is_empty()
		"page":
			return str(value).is_empty() or str(value) == "auto"
		"per_page":
			return int(value) <= 0
	return false


## What each section's items were in, before a step edit, to carry the
## looks with them after it ([method follow]): definition -> {item: step},
## read from the first copy of each sub-model.
static func items_by_step(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var turns: Dictionary = {}
	var sections: Array = AuthorSteps.paths_in(world, skip).keys()
	sections.sort()
	sections.push_front("")
	for section: String in sections:
		var definition: String = definition_of(section)
		if out.has(definition):
			continue
		var items: Dictionary = {}
		for item: Dictionary in AuthorSteps.items_of(world, section, skip):
			var named: String = ("b%d" % int(item["brick"])) if item.has("brick") \
				else "u" + Assemblies.leaf(str(item["unit"]))
			items[named] = int(item["step"])
		out[definition] = items
		var seen: Dictionary = {}
		for step: int in AuthorSteps.steps_in(world, section, skip):
			var turn: Dictionary = turn_at(world, section, step)
			if not turn.is_empty():
				seen[step] = turn
		turns[definition] = seen
	out["@turns"] = turns
	return out


## After a step edit: each step's look moved to the step most of its parts
## went to, the earlier of two where two now share one (merged, the first
## step's choices kept and the second's added where the first had none),
## and one whose parts all went nowhere dropped. Returns the undo.
static func follow(world: BrickWorld, before: Dictionary, skip: Dictionary = {}) -> Array:
	var any_step: bool = false
	for name: String in world.step_looks:
		if not name.ends_with("|*") and name != BOOKLET and name != DATA:
			any_step = true
			break
	if not any_step:
		return []
	var after: Dictionary = items_by_step(world, skip)
	var was: Dictionary = world.step_looks.duplicate(true)
	var moved: Dictionary = {}
	var names: Array = world.step_looks.keys()
	# Earlier steps first, so on a merge the first step's choices win.
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.get_slice("|", 0) < b.get_slice("|", 0) \
			or a.get_slice("|", 0) == b.get_slice("|", 0) \
			and a.get_slice("|", 1).to_int() < b.get_slice("|", 1).to_int())
	for name: String in names:
		var tail: String = name.get_slice("|", 1)
		if name == BOOKLET or tail == "*" or not tail.is_valid_int():
			moved[name] = world.step_looks[name]
			continue
		var definition: String = name.get_slice("|", 0)
		var step: int = tail.to_int()
		var then: Dictionary = before.get(definition, {})
		var now: Dictionary = after.get(definition, {})
		var votes: Dictionary = {}
		for item: String in then:
			if int(then[item]) == step and now.has(item):
				votes[int(now[item])] = int(votes.get(int(now[item]), 0)) + 1
		if votes.is_empty():
			# A step nobody had parts in: kept where it was, if it still is.
			if then.values().has(step) or not now.values().has(step):
				continue
			votes[step] = 1
		var best: int = -1
		for to: int in votes:
			if best < 0 or int(votes[to]) > int(votes[best]) \
					or int(votes[to]) == int(votes[best]) and to < best:
				best = to
		var target: String = key(definition, best)
		var look: Dictionary = (world.step_looks[name] as Dictionary).duplicate(true)
		if moved.has(target):
			var kept: Dictionary = moved[target]
			for field: String in look:
				if not kept.has(field):
					kept[field] = look[field]
		else:
			moved[target] = look
	_turns_follow(moved, before, after)
	if moved == was:
		return []
	world.step_looks = moved
	return [{"undo": "steplooks", "looks": was}]


## Each step's turn after a step edit is the one its parts were seen from
## before it ([method items_by_step]'s "turns"), written again only where it
## changes from the step before: a ROTSTEP ending an empty step, which the
## edit takes out, gives its turn to the step it turned. A turn written as
## it was keeps its line.
static func _turns_follow(looks: Dictionary, before: Dictionary, after: Dictionary) -> void:
	var turns: Dictionary = before.get("@turns", {})
	for definition: String in after:
		if definition.begins_with("@"):
			continue
		var then: Dictionary = before.get(definition, {})
		var now: Dictionary = after[definition]
		if then == now:
			continue
		var seen: Dictionary = turns.get(definition, {})
		var steps: Dictionary = {}
		for item: String in now:
			steps[int(now[item])] = true
		var order: Array = steps.keys()
		order.sort()
		# Each new step's turn: what most of its parts were seen from.
		var want: Dictionary = {}
		for step: int in order:
			var votes: Dictionary = {}
			for item: String in now:
				if int(now[item]) == step and then.has(item):
					var was: String = JSON.stringify(seen.get(int(then[item]), {}))
					votes[was] = int(votes.get(was, 0)) + 1
			var best: String = "{}"
			for one: String in votes:
				if not votes.has(best) or int(votes[one]) > int(votes[best]):
					best = one
			want[step] = JSON.parse_string(best)
		# The lines that said them, kept by what they said.
		var lines: Dictionary = {}
		for name: String in looks.keys():
			if name.get_slice("|", 0) != definition or not name.get_slice("|", 1).is_valid_int():
				continue
			var look: Dictionary = looks[name]
			if look.has("line"):
				lines[JSON.stringify([look.get("turn"), look.get("how", "REL")])] = look["line"]
			look.erase("turn")
			look.erase("how")
			look.erase("line")
			if look.is_empty():
				looks.erase(name)
		var state: Dictionary = {}
		for step: int in order:
			var turn: Dictionary = want[step] if want[step] is Dictionary else {}
			if JSON.stringify(turn) == JSON.stringify(state):
				continue
			var look: Dictionary = looks.get(key(definition, step), {})
			if turn.is_empty():
				look["turn"] = "end"
			else:
				look["turn"] = turn["turn"]
				look["how"] = str(turn.get("how", "REL"))
			var said: String = JSON.stringify([look["turn"], look.get("how", "REL")])
			if lines.has(said):
				look["line"] = lines[said]
			looks[key(definition, step)] = look
			state = turn


# -- reading and writing the file ---------------------------------------------


## The looks a model's file gives its steps, keyed as BrickWorld keeps them
## ([param names]: sub-model key -> the name its assembly goes by,
## LdrModel._assembly_names; the model's own section is "").
static func read(text: String, names: Dictionary, main_key: String) -> Dictionary:
	var out: Dictionary = {}
	var definition: String = ""
	var step: int = 0
	## A page's picture being read (LDraw's !DATA), and its base64 so far.
	var data_name: String = ""
	var data := PackedStringArray()
	var pictures: Dictionary = {}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not data_name.is_empty():
			if line.begins_with("0 !:"):
				data.append(line.substr(4).strip_edges())
				continue
			pictures[data_name] = "".join(data)
			data_name = ""
		if not line.begins_with("0 "):
			continue
		var words: PackedStringArray = LdrModel._fields(line)
		if words.size() < 2:
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "!DATA":
			var named: String = " ".join(words.slice(2)).get_file().to_lower()
			if named.begins_with(IMAGE_PREFIX):
				data_name = named
				data = PackedStringArray()
			continue
		if keyword == "FILE":
			var file_key: String = LdrModel._key(" ".join(words.slice(2)))
			definition = "" if file_key == main_key else str(names.get(file_key, file_key))
			step = 0
			continue
		if keyword == "ROTSTEP":
			# It ends this step and turns the next, as MLCad reads it and as
			# the files of LDraw's model repository write it: a ROTSTEP at
			# the head of a sub-model, before its first part, turns its first.
			var look: Dictionary = out.get(key(definition, step + 1), {})
			if words.size() >= 3 and words[2].to_upper() == "END":
				look["turn"] = "end"
			elif words.size() >= 5:
				look["turn"] = [words[2].to_float(), words[3].to_float(), words[4].to_float()]
				look["how"] = words[5].to_upper() if words.size() >= 6 \
					and words[5].to_upper() in ["REL", "ABS", "ADD"] else "REL"
			look["line"] = line
			out[key(definition, step + 1)] = look
			step += 1
			continue
		if keyword == "STEP":
			step += 1
			continue
		if keyword != "!BRICKWORKS" or words.size() < 3 or not words[2] in WORDS:
			continue
		var value: String = words[3].to_upper() if words.size() > 3 else ""
		match words[2]:
			"PAGE":
				if value in ["NEW", "ALONE"]:
					_put_in(out, key(definition, step), "page", value.to_lower())
			"ZOOM":
				if value.is_valid_float() and value.to_float() > 0.0:
					_put_in(out, key(definition, step), "zoom", clampf(value.to_float(), 0.25, 4.0))
			"SIZE":
				if value.is_valid_float() and value.to_float() > 0.0:
					_put_in(out, key(definition, step), "size", clampf(value.to_float(), 0.4, 3.0))
			"PARTS":
				if value == "OFF":
					_put_in(out, key(definition, step), "parts", false)
			"CALLOUT":
				if value == "OFF" and not definition.is_empty():
					_put_in(out, definition + "|*", "callout", false)
			"PER_PAGE":
				if value.is_valid_int() and value.to_int() in [1, 2, 4]:
					_put_in(out, BOOKLET, "per_page", value.to_int())
			"HIGHLIGHT":
				if value == "OFF":
					_put_in(out, BOOKLET, "highlight", false)
			"PLACE":
				var item: String = value.to_lower()
				var numbers: Array = _numbers(words, 4, int(ITEMS.get(item, 0)))
				if not numbers.is_empty():
					var name: String = key(definition, step)
					var place: Dictionary = (out.get(name, {}) as Dictionary).get("place", {})
					place[item] = numbers
					_put_in(out, name, "place", place)
			"TEXT":
				var at: Array = _numbers(words, 3, 5)
				if not at.is_empty():
					var said: String = _rest_after(line, 8).replace("\\n", "\n")
					_note_in(out, key(definition, step), {"text": said,
						"at": at.slice(0, 4), "size": clampf(float(at[4]), 1.5, 40.0)})
			"IMAGE":
				var at: Array = _numbers(words, 3, 4)
				if not at.is_empty() and words.size() > 7:
					_note_in(out, key(definition, step), {"image": words[7].to_lower(),
						"at": at})
	if not data_name.is_empty():
		pictures[data_name] = "".join(data)
	# Only the pictures a page shows.
	var shown: Dictionary = {}
	for name: String in out:
		for note: Dictionary in (out[name] as Dictionary).get("notes", []):
			if note.has("image") and pictures.has(str(note["image"])):
				shown[str(note["image"])] = pictures[str(note["image"])]
	if not shown.is_empty():
		out[DATA] = shown
	return out


## [param count] numbers from [param words] at [param from], each within
## the page; [] when any is missing or not a number.
static func _numbers(words: PackedStringArray, from: int, count: int) -> Array:
	if count <= 0 or words.size() < from + count:
		return []
	var out: Array = []
	for at: int in range(from, from + count):
		if not words[at].is_valid_float():
			return []
		out.append(clampf(words[at].to_float(), -Booklet.PAGE.x, Booklet.PAGE.x * 2.0))
	return out


## What follows the first [param count] words of [param line], as written.
static func _rest_after(line: String, count: int) -> String:
	var at: int = 0
	for _n: int in count:
		while at < line.length() and line[at] in [" ", "\t"]:
			at += 1
		while at < line.length() and not line[at] in [" ", "\t"]:
			at += 1
	return line.substr(at).strip_edges()


static func _note_in(out: Dictionary, name: String, note: Dictionary) -> void:
	var look: Dictionary = out.get(name, {})
	var notes: Array = look.get("notes", [])
	notes.append(note)
	look["notes"] = notes
	out[name] = look


static func _put_in(out: Dictionary, name: String, field: String, value: Variant) -> void:
	var look: Dictionary = out.get(name, {})
	look[field] = value
	out[name] = look


## Whether [param text] has any of the lines these are written as.
static func _written_in(text: String) -> bool:
	if text.contains("ROTSTEP") or text.contains("rotstep") \
			or text.contains("0 !DATA " + IMAGE_PREFIX):
		return true
	for word: String in WORDS:
		if text.contains(META + word):
			return true
	return false


## [param text], a model written out, with [param looks] in it: each step's
## ending line a STEP or a ROTSTEP as its turn says, and the app's own
## lines for the rest just before it. A line already saying what a look
## says is left as it was, byte for byte, so a file opened and saved with
## nothing changed is the file. [param names] and [param main_key] as
## [method read] takes them.
static func written_into(text: String, looks: Dictionary, names: Dictionary,
		main_key: String) -> String:
	if looks.is_empty() and not _written_in(text):
		return text
	var lines: PackedStringArray = text.split("\n")
	var eol: String = "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""
	var out := PackedStringArray()
	var definition: String = ""
	var step: int = 0
	var any_part: bool = false
	var section_open: bool = false
	var wrote: Dictionary = {}
	# The model's own lines go first in it, where a file without FILE lines
	# has them too.
	var first_file: bool = true
	## Inside a page's picture as it was written (LDraw's !DATA): left out,
	## and written again at the end from the looks.
	var skipping: bool = false
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if skipping:
			if line.begins_with("0 !:"):
				continue
			skipping = false
		var words: PackedStringArray = LdrModel._fields(line) if line.begins_with("0 ") \
			else PackedStringArray()
		var keyword: String = words[1].to_upper() if words.size() >= 2 else ""
		if keyword in ["FILE", "NOFILE", "!DATA"]:
			if section_open or (first_file and any_part):
				_close_section(out, looks, definition, step, any_part, eol, wrote)
				if not section_open:
					# The model's own lines, in a file of no FILE lines, are done.
					first_file = false
			section_open = keyword == "FILE"
			if keyword == "!DATA" and " ".join(words.slice(2)).get_file().to_lower() \
					.begins_with(IMAGE_PREFIX):
				skipping = true
				continue
			if keyword == "FILE":
				var file_key: String = LdrModel._key(" ".join(words.slice(2)))
				definition = "" if first_file or file_key == main_key \
					else str(names.get(file_key, file_key))
				first_file = false
				step = 0
				any_part = false
			out.append(raw)
			continue
		if keyword == "!BRICKWORKS" and words.size() >= 3 and words[2] in WORDS:
			continue
		if keyword == "STEP" or keyword == "ROTSTEP":
			_step_lines(out, looks, definition, step, eol, wrote)
			out.append(_ending(raw, looks, definition, step + 1, eol))
			step += 1
			any_part = false
			continue
		if line.begins_with("1 "):
			if step == 0 and not any_part:
				var first: Dictionary = looks.get(key(definition, 0), {})
				if first.has("turn") and str(first["turn"]) != "end":
					out.append(_ending("0 STEP" + eol, looks, definition, 0, eol))
			any_part = true
		out.append(raw)
	if section_open or first_file:
		_close_section(out, looks, definition, step, any_part, eol, wrote)
	# What has no step in the file to go in (a sub-model's callout, the
	# booklet's own) goes under the model's first line.
	var head := PackedStringArray()
	for name: String in looks:
		if wrote.has(name):
			continue
		var look: Dictionary = looks[name]
		if name == BOOKLET:
			_booklet_lines(head, look, eol)
	if not head.is_empty():
		var at: int = 1
		while at < out.size() and out[at].strip_edges().begins_with("0 ") \
				and not out[at].strip_edges().to_upper().begins_with("0 FILE") \
				and not out[at].strip_edges().to_upper().begins_with("0 STEP") \
				and not out[at].strip_edges().to_upper().begins_with("0 ROTSTEP") \
				and at < 12:
			at += 1
		for n: int in head.size():
			out.insert(at + n, head[n])
	# The pictures the pages show, each as LDraw's embedded file, at the end.
	var pictures: Dictionary = looks.get(DATA, {})
	var shown: Dictionary = {}
	for name: String in looks:
		for note: Variant in (looks[name] as Dictionary).get("notes", []) \
				if looks[name] is Dictionary else []:
			if note is Dictionary and (note as Dictionary).has("image") \
					and pictures.has(str(note["image"])):
				shown[str(note["image"])] = true
	if not shown.is_empty():
		# Before the blank lines the file ends with, as they were.
		var end: int = out.size()
		while end > 0 and out[end - 1].strip_edges().is_empty():
			end -= 1
		var block := PackedStringArray()
		var kept: Array = shown.keys()
		kept.sort()
		for name: String in kept:
			block.append("0 !DATA " + name + eol)
			var encoded: String = str(pictures[name])
			for at: int in range(0, encoded.length(), 76):
				block.append("0 !: " + encoded.substr(at, 76) + eol)
		for n: int in block.size():
			out.insert(end + n, block[n])
		if end + block.size() == out.size():
			out.append("")
	return "\n".join(out)


## The booklet's own lines, said once at the head of the model.
static func _booklet_lines(out: PackedStringArray, whole: Dictionary, eol: String) -> void:
	if whole.has("per_page"):
		out.append(META + "PER_PAGE %d" % int(whole["per_page"]) + eol)
	if whole.has("highlight") and not bool(whole["highlight"]):
		out.append(META + "HIGHLIGHT OFF" + eol)


## The end of a section: the looks of its last step, which has no line
## ending it, said before the trailing blank lines, with a line to end it
## where it is turned.
static func _close_section(out: PackedStringArray, looks: Dictionary, definition: String,
		step: int, any_part: bool, eol: String, wrote: Dictionary) -> void:
	var trailing: int = out.size()
	while trailing > 0 and out[trailing - 1].strip_edges().is_empty():
		trailing -= 1
	var extra := PackedStringArray()
	var look: Dictionary = looks.get(key(definition, step), {})
	if any_part or not look.is_empty():
		_step_lines(extra, looks, definition, step, eol, wrote)
	# A sub-model's callout, said once in it.
	var whole: Dictionary = looks.get(definition + "|*", {})
	if not definition.is_empty() and whole.has("callout") and not bool(whole["callout"]) \
			and not wrote.has(definition + "|*"):
		extra.append(META + "CALLOUT OFF" + eol)
		wrote[definition + "|*"] = true
	for n: int in extra.size():
		out.insert(trailing + n, extra[n])


## The app's own lines for one step, before the line that ends it.
static func _step_lines(out: PackedStringArray, looks: Dictionary, definition: String,
		step: int, eol: String, wrote: Dictionary) -> void:
	if step == 0 and not definition.is_empty():
		var whole: Dictionary = looks.get(definition + "|*", {})
		if whole.has("callout") and not bool(whole["callout"]) and not wrote.has(definition + "|*"):
			out.append(META + "CALLOUT OFF" + eol)
			wrote[definition + "|*"] = true
	if definition.is_empty() and step == 0 and looks.has(BOOKLET) and not wrote.has(BOOKLET):
		var whole: Dictionary = looks[BOOKLET]
		var before: int = out.size()
		_booklet_lines(out, whole, eol)
		if out.size() > before:
			wrote[BOOKLET] = true
	var look: Dictionary = looks.get(key(definition, step), {})
	if look.is_empty():
		return
	wrote[key(definition, step)] = true
	if look.has("page"):
		out.append(META + "PAGE " + str(look["page"]).to_upper() + eol)
	if look.has("zoom"):
		out.append(META + "ZOOM " + _number(float(look["zoom"])) + eol)
	if look.has("size"):
		out.append(META + "SIZE " + _number(float(look["size"])) + eol)
	if look.has("parts") and not bool(look["parts"]):
		out.append(META + "PARTS OFF" + eol)
	var place: Dictionary = look.get("place", {})
	for item: String in ITEMS:
		if place.has(item):
			out.append(META + "PLACE " + item.to_upper() + " " + _numbers_said(place[item]) + eol)
	for note: Variant in look.get("notes", []):
		if not (note is Dictionary):
			continue
		var at: String = _numbers_said(note.get("at", []))
		if note.has("text"):
			out.append(META + "TEXT " + at + " " + _number(float(note.get("size", 4.0))) + " "
				+ str(note["text"]).replace("\r", "").replace("\n", "\\n").strip_edges() + eol)
		elif note.has("image"):
			out.append(META + "IMAGE " + at + " " + str(note["image"]) + eol)


## The line that ends a step, saying the turn of the step after it
## ([param step]): as it was when it says what the look says.
static func _ending(raw: String, looks: Dictionary, definition: String, step: int,
		eol: String) -> String:
	var look: Dictionary = looks.get(key(definition, step), {})
	var line: String = raw.strip_edges()
	if not look.has("turn"):
		return raw if line.to_upper().begins_with("0 STEP") else "0 STEP" + eol
	if look.has("line") and line == str(look["line"]):
		return raw
	if str(look["turn"]) == "end":
		return "0 ROTSTEP END" + eol
	var turn: Vector3 = _vector(look["turn"])
	return "0 ROTSTEP %s %s %s %s" % [_number(turn.x), _number(turn.y), _number(turn.z),
		str(look.get("how", "REL"))] + eol


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 3)


static func _numbers_said(values: Variant) -> String:
	var said := PackedStringArray()
	for value: Variant in values if values is Array else []:
		said.append(_number(snappedf(float(value), 0.1)))
	return " ".join(said)


## A place on the page as a rect, in mm: [x, y, w, h], or [x, y, w] and [x,
## y] with what is not said zero.
static func rect_of(values: Variant) -> Rect2:
	var numbers: Array = values if values is Array else []
	var got: Array = []
	for n: int in 4:
		got.append(float(numbers[n]) if n < numbers.size() else 0.0)
	return Rect2(got[0], got[1], got[2], got[3])


# -- what the booklet is told ---------------------------------------------------


## The pages a booklet lays out (BookletMaker.lay_out_only), as a session
## reads them: a line a page from [param from], each step with how its
## designer set it.
static func layout_said(world: BrickWorld, pages: Array[Booklet.Page], from: int = 2) -> String:
	var told := PackedStringArray()
	var steps: int = 0
	var kinds: Dictionary = {}
	for page: Booklet.Page in pages:
		kinds[page.kind] = int(kinds.get(page.kind, 0)) + 1
		if page.kind == "steps":
			steps += page.entries.size()
	var most: int = int(booklet(world).get("per_page", 0))
	told.append("%d pages of steps and %d of callouts, %d steps; %s a page; %s. Then the "
		% [int(kinds.get("steps", 0)), int(kinds.get("callout", 0)), steps,
			"as many as fit" if most == 0 else "at most %d" % most,
			"the parts each step adds outlined" if highlight_on(world) else "new parts not outlined"]
		+ "finished model and the parts list. Places are in mm on a 269 x 199 page.")
	var characters: int = 0
	var off: Dictionary = {}
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if entry.callout != null and entry.callout.own_pages:
				off[entry.callout.name] = true
		if page.number < from:
			continue
		var each := PackedStringArray()
		for entry: Booklet.Entry in page.entries:
			var how := PackedStringArray()
			if not entry.look.is_empty():
				var named: String = entry.look.get_slice("|", 0)
				var own_line: String = said(world, named, entry.look.get_slice("|", 1).to_int())
				if not own_line.is_empty():
					how.append(own_line)
			if entry.callout != null:
				how.append("puts on the %s%s, %s" % [entry.callout.name,
					" x%d" % entry.callout.times if entry.callout.times > 1 else "",
					"built in a callout box" if entry.callout.inline else "built on its own pages"])
			each.append("%d%s" % [entry.number, (" (" + "; ".join(how) + ")") if not how.is_empty()
				else ""])
		var line: String = "  page %d%s: step%s %s" % [page.number,
			(" (the %s, built on its own)" % page.name) if page.kind == "callout" else "",
			"" if page.entries.size() == 1 else "s", ", ".join(each)]
		characters += line.length()
		if characters > 6000:
			told.append("  ... booklet_layout {\"from\": %d} for the rest." % page.number)
			break
		told.append(line)
	if not off.is_empty():
		told.append("Built on pages of their own by choice: %s." % ", ".join(off.keys()))
	return "\n".join(told)


## How a step's look reads, for the timeline and a session: "turned 90°,
## zoom 1.5x, new page", or "".
static func said(world: BrickWorld, section: String, step: int) -> String:
	var parts := PackedStringArray()
	var turn: Dictionary = turn_at(world, section, step)
	var own: Dictionary = of(world, section, step)
	if not turn.is_empty():
		var by: Vector3 = _vector(turn["turn"])
		var bits := PackedStringArray()
		if str(turn.get("how", "REL")) == "ABS":
			# Measured from straight in front, as LDraw's ABS is.
			bits.append("seen from %d° round and %d° up" % [roundi(by.y), roundi(by.x)])
		else:
			if not is_zero_approx(by.y):
				bits.append("turned %d°" % roundi(by.y))
			if not is_zero_approx(by.x):
				bits.append("tilted %d°" % roundi(by.x))
		parts.append(", ".join(bits) + ("" if own.has("turn") else " (from before)"))
	if own.has("zoom"):
		parts.append("zoom %sx" % _number(float(own["zoom"])))
	if own.has("size"):
		parts.append("size %sx" % _number(float(own["size"])))
	match str(own.get("page", "")):
		"new":
			parts.append("new page")
		"alone":
			parts.append("a page alone")
	if own.has("parts") and not bool(own["parts"]):
		parts.append("no parts list")
	var place: Dictionary = own.get("place", {})
	for item: String in ITEMS:
		if place.has(item):
			var at: Array = place[item]
			parts.append("%s at %s, %s mm%s" % [item, _number(snappedf(float(at[0]), 0.1)),
				_number(snappedf(float(at[1]), 0.1)), (" (%s wide%s)" % [
					_number(snappedf(float(at[2]), 0.1)),
					(", %s high" % _number(snappedf(float(at[3]), 0.1))) if at.size() > 3 else ""])
					if at.size() > 2 else ""])
	for note: Variant in own.get("notes", []):
		if not (note is Dictionary):
			continue
		var at: Rect2 = rect_of(note.get("at", []))
		if note.has("text"):
			parts.append("text \"%s\" at %s, %s mm" % [str(note["text"]).replace("\n", " / ").left(60),
				_number(snappedf(at.position.x, 0.1)), _number(snappedf(at.position.y, 0.1))])
		elif note.has("image"):
			parts.append("a picture at %s, %s mm, %s x %s" % [_number(snappedf(at.position.x, 0.1)),
				_number(snappedf(at.position.y, 0.1)), _number(snappedf(at.size.x, 0.1)),
				_number(snappedf(at.size.y, 0.1))])
	return ", ".join(parts)
