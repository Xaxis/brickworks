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
## false}. A sub-model's: {"callout": false}. The booklet's: {"per_page":
## 1, 2 or 4}.
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
## sub-model "... CALLOUT OFF"; "... PER_PAGE 2" in the model.
##
## Every change is one undo (Builder._apply "steplooks", the whole table
## as it was), and a step edit carries each step's look with the parts it
## had (follow).
class_name BookletLooks
extends RefCounted

const META := "0 !BRICKWORKS "
## The words of the app's own step lines, after META.
const WORDS: Array[String] = ["PAGE", "ZOOM", "SIZE", "PARTS", "CALLOUT", "PER_PAGE"]
const BOOKLET := "|booklet"
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


static func callout_on(world: BrickWorld, section: String) -> bool:
	var whole: Dictionary = world.step_looks.get(definition_of(section) + "|*", {})
	return bool(whole.get("callout", true))


## The turn in force at [param step] of [param section]: the last one set at
## or before it ({"turn": [x, y, z], "how": ...}), or {} for the usual view
## (none, or "end").
static func turn_at(world: BrickWorld, section: String, step: int) -> Dictionary:
	var definition: String = definition_of(section)
	var found: Dictionary = {}
	var added := Vector3.ZERO
	for at: int in range(0, step + 1):
		var look: Dictionary = world.step_looks.get(key(definition, at), {})
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


static func _usual(field: String, value: Variant) -> bool:
	match field:
		"zoom", "size":
			return is_equal_approx(float(value), 1.0)
		"parts", "callout":
			return bool(value)
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
	return out


## After a step edit: each step's look moved to the step most of its parts
## went to, the earlier of two where two now share one (merged, the first
## step's choices kept and the second's added where the first had none),
## and one whose parts all went nowhere dropped. Returns the undo.
static func follow(world: BrickWorld, before: Dictionary, skip: Dictionary = {}) -> Array:
	var any_step: bool = false
	for name: String in world.step_looks:
		if not name.ends_with("|*") and name != BOOKLET:
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
	if moved == was:
		return []
	world.step_looks = moved
	return [{"undo": "steplooks", "looks": was}]


# -- reading and writing the file ---------------------------------------------


## The looks a model's file gives its steps, keyed as BrickWorld keeps them
## ([param names]: sub-model key -> the name its assembly goes by,
## LdrModel._assembly_names; the model's own section is "").
static func read(text: String, names: Dictionary, main_key: String) -> Dictionary:
	var out: Dictionary = {}
	var definition: String = ""
	var step: int = 0
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with("0 "):
			continue
		var words: PackedStringArray = LdrModel._fields(line)
		if words.size() < 2:
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "FILE":
			var file_key: String = LdrModel._key(" ".join(words.slice(2)))
			definition = "" if file_key == main_key else str(names.get(file_key, file_key))
			step = 0
			continue
		if keyword == "ROTSTEP":
			var look: Dictionary = out.get(key(definition, step), {})
			if words.size() >= 3 and words[2].to_upper() == "END":
				look["turn"] = "end"
			elif words.size() >= 5:
				look["turn"] = [words[2].to_float(), words[3].to_float(), words[4].to_float()]
				look["how"] = words[5].to_upper() if words.size() >= 6 \
					and words[5].to_upper() in ["REL", "ABS", "ADD"] else "REL"
			look["line"] = line
			out[key(definition, step)] = look
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
	return out


static func _put_in(out: Dictionary, name: String, field: String, value: Variant) -> void:
	var look: Dictionary = out.get(name, {})
	look[field] = value
	out[name] = look


## Whether [param text] has any of the lines these are written as.
static func _written_in(text: String) -> bool:
	if text.contains("ROTSTEP") or text.contains("rotstep"):
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
	for raw: String in lines:
		var line: String = raw.strip_edges()
		var words: PackedStringArray = LdrModel._fields(line) if line.begins_with("0 ") \
			else PackedStringArray()
		var keyword: String = words[1].to_upper() if words.size() >= 2 else ""
		if keyword in ["FILE", "NOFILE", "!DATA"]:
			if section_open or (first_file and any_part):
				_close_section(out, looks, definition, step, any_part, eol, wrote)
			section_open = keyword == "FILE"
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
			out.append(_ending(raw, looks, definition, step, eol))
			step += 1
			any_part = false
			continue
		if line.begins_with("1 "):
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
		if name == BOOKLET and look.has("per_page"):
			head.append(META + "PER_PAGE %d" % int(look["per_page"]) + eol)
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
	return "\n".join(out)


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
		if look.has("turn"):
			extra.append(_ending("0 STEP" + eol, looks, definition, step, eol))
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
	if definition.is_empty() and step == 0 and looks.has(BOOKLET):
		var whole: Dictionary = looks[BOOKLET]
		if whole.has("per_page"):
			out.append(META + "PER_PAGE %d" % int(whole["per_page"]) + eol)
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


## The line that ends a step: as it was when it says what the look says.
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


# -- what the booklet is told ---------------------------------------------------


## How a step's look reads, for the timeline and a session: "turned 90°,
## zoom 1.5x, new page", or "".
static func said(world: BrickWorld, section: String, step: int) -> String:
	var parts := PackedStringArray()
	var turn: Dictionary = turn_at(world, section, step)
	var own: Dictionary = of(world, section, step)
	if not turn.is_empty():
		var by: Vector3 = _vector(turn["turn"])
		var bits := PackedStringArray()
		if not is_zero_approx(by.y):
			bits.append("turned %d°" % roundi(by.y))
		if not is_zero_approx(by.x):
			bits.append("tilted %d°" % roundi(by.x))
		if str(turn.get("how", "REL")) == "ABS":
			bits.append("from the front")
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
	return ", ".join(parts)
