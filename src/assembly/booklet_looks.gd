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
## in "|data" under its name, either turned about its middle ("turn":
## degrees, clockwise) and faded ("opacity": 0.05 to 1), as Studio's page
## objects are; "arrows" the arrows they draw on it: {"at": [x1, y1, x2,
## y2] or with the points it bends through [..., bx, by, ...], "colour":
## "red" or "black", "width": mm}. The booklet's "guides" {"x": [mm],
## "y": [mm]} are the lines dragged from the page editor's rulers, which
## what is dragged on any page snaps to. "panel" [x, y, w, h] is the room the booklet gave
## the step on its page when they were placed: they all belong to the step,
## and when its page changes round it they move and scale with it into its
## new room ([method rebased]). "sign": false leaves the turn sign off it.
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
## the model. A page laid out by hand: "... PANEL x y w h" (the step's room
## then), "... PLACE PICTURE x y w h", "... PLACE PARTS x y w", "... PLACE
## CALLOUT x y w h", "... PLACE NUMBER x y", "... TEXT x y w h size words"
## (a line break written \n), "... IMAGE x y w h name" with the picture
## itself as LDraw's own embedded file, "0 !DATA name" with its base64 in
## "0 !:" lines, at the end of the file, and "... ARROW RED 0.9 x1 y1 x2 y2
## [bx by ...]"; "... NOTE TURN 30 OPACITY 50" after the words or picture it
## turns and fades; "... TURN_SIGN OFF" on a step whose turn sign was taken
## off; "... GUIDE X 120" in the model, a guide each.
##
## Every change is one undo (Builder._apply "steplooks", the whole table
## as it was), and a step edit carries each step's look with the parts it
## had (follow).
class_name BookletLooks
extends RefCounted

const META := "0 !BRICKWORKS "
## The words of the app's own step lines, after META.
const WORDS: Array[String] = ["PAGE", "ZOOM", "SIZE", "PARTS", "CALLOUT", "PER_PAGE",
	"HIGHLIGHT", "PLACE", "TEXT", "IMAGE", "PANEL", "ARROW", "TURN_SIGN", "NOTE", "GUIDE"]
const BOOKLET := "|booklet"
## The pictures a page shows, by name: {name: base64}.
const DATA := "|data"
## The items of a step a designer can place on its page, and how many
## numbers place each.
const ITEMS: Dictionary = {"picture": 4, "parts": 3, "callout": 4, "number": 2}
## The names a page's picture is kept under in the file, as LDraw's !DATA.
const IMAGE_PREFIX := "brickworks-page-"
## The colours an arrow of the designer's comes in: a booklet's red, which
## points where a part goes in, and the black of its callout arrows.
const ARROW_COLOURS: Dictionary = {"red": "#d01012", "black": "#15191e"}
## The widths it comes in, in mm: the callout arrow's, the red pointer's,
## and a broad one; a width given is snapped to the nearest.
const ARROW_WIDTHS: Array[float] = [0.45, 0.9, 1.4]
## The most points an arrow bends through.
const MOST_BENDS := 12
## The faintest a page's words or picture of the designer's is drawn.
const FAINTEST := 0.05
## Two rooms nearer than this, in mm, are the same room.
const SAME_ROOM := 0.5
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


## The guides dragged onto the booklet's pages: {"x": [mm], "y": [mm]}.
static func guides(world: BrickWorld) -> Dictionary:
	var kept: Dictionary = booklet(world).get("guides", {})
	return {"x": (kept.get("x", []) as Array).duplicate(), "y": (kept.get("y", []) as Array).duplicate()}


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
		"place", "notes", "arrows", "panel":
			return (value is Dictionary or value is Array) and value.is_empty()
		"guides":
			return value is Dictionary and (value as Dictionary).values().all(
				func(lines: Variant) -> bool: return not (lines is Array) or (lines as Array).is_empty())
		"sign":
			return bool(value)
		"page":
			return str(value).is_empty() or str(value) == "auto"
		"per_page":
			return int(value) <= 0
	return false


## What each section's items were in, before a step edit, to carry the
## looks with them after it ([method follow]): definition -> {item: step},
## read from the first copy of each sub-model. Taken before anything numbers
## the steps again, AuthorSteps.ensure included: a look is the step's, and
## the step is its parts, not its number. Nothing when no step has a look
## of its own, as then there is nothing to carry: read anyway, it was most
## of a step edit on the Wizard's Tower, which has none (race244).
static func items_by_step(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if not any_step_look(world):
		return out
	var turns: Dictionary = {}
	var own: Dictionary = {}
	var sections: Array = first_copies(world, skip)
	var items_in: Dictionary = AuthorSteps.items_in(world, sections, skip)
	for section: String in sections:
		var definition: String = definition_of(section)
		var items: Dictionary = {}
		for item: Dictionary in items_in[section]:
			items[item_name(item)] = int(item["step"])
		out[definition] = items
		var seen: Dictionary = {}
		var turned: Dictionary = {}
		for step: int in AuthorSteps.steps_of(items_in[section]):
			var turn: Dictionary = turn_at(world, section, step)
			if not turn.is_empty():
				seen[step] = turn
			# A ROTSTEP turning it; not one putting the usual view back,
			# which a step edit writes wherever the view goes back.
			var look: Dictionary = of(world, section, step)
			if look.has("turn") and str(look["turn"]) != "end":
				turned[step] = true
		turns[definition] = seen
		own[definition] = turned
	out["@turns"] = turns
	out["@own"] = own
	return out


## Whether any step has a look of its own: not the booklet's, nor a
## sub-model's for all its copies.
static func any_step_look(world: BrickWorld) -> bool:
	for name: String in world.step_looks:
		if not name.ends_with("|*") and name != BOOKLET and name != DATA:
			return true
	return false


## The section each step look's definition is read from: the model's own ("")
## and the first copy of each sub-model, by path.
static func first_copies(world: BrickWorld, skip: Dictionary = {}) -> Array:
	var sections: Array = AuthorSteps.paths_in(world, skip).keys()
	sections.sort()
	sections.push_front("")
	var out: Array = []
	var seen: Dictionary = {}
	for section: String in sections:
		var definition: String = definition_of(section)
		if not seen.has(definition):
			seen[definition] = true
			out.append(section)
	return out


## An item of AuthorSteps.items_of as [method items_by_step] names it: a part
## by its id, a sub-model's copy by its name.
static func item_name(item: Dictionary) -> String:
	return ("b%d" % int(item["brick"])) if item.has("brick") \
		else "u" + Assemblies.leaf(str(item["unit"]))


## After a step edit: each step's look moved to the step most of its parts
## went to, the earlier of two where two now share one (merged, the first
## step's choices kept and the second's added where the first had none),
## and one whose parts all went nowhere dropped. [param taken] names the
## items the edit took out of their steps (the selection a part move or a
## split moves, a deleted step's): a step keeps its look with the parts it
## kept, and goes with the taken ones only when none are left. A look on a
## step that had no parts when [param before] was read is a step that is
## gone (its parts taken off the model): it is dropped, not left on
## whatever step now has its number. Returns the undo.
static func follow(world: BrickWorld, before: Dictionary, skip: Dictionary = {},
		taken: Dictionary = {}) -> Array:
	if not any_step_look(world):
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
		var kept_any: bool = false
		for item: String in then:
			if int(then[item]) == step and now.has(item) and not taken.has(item):
				kept_any = true
				break
		for item: String in then:
			if int(then[item]) == step and now.has(item) and not (kept_any and taken.has(item)):
				votes[int(now[item])] = int(votes.get(int(now[item]), 0)) + 1
		if votes.is_empty():
			# A step with no parts (taken off the model since its look was
			# set), or whose parts all went: gone, and its look with it.
			continue
		var best: int = -1
		for to: int in votes:
			if best < 0 or int(votes[to]) > int(votes[best]) \
					or int(votes[to]) == int(votes[best]) and to < best:
				best = to
		var target: String = key(definition, best)
		var look: Dictionary = (world.step_looks[name] as Dictionary).duplicate(true)
		if moved.has(target):
			var kept: Dictionary = moved[target]
			# The words, pictures and arrows of both steps' pages kept, the
			# second's moved from its room into the first's.
			if kept.has("panel") and look.has("panel"):
				look = rebased(look, rect_of(kept["panel"]))
			for field: String in look:
				if field in ["notes", "arrows"] and kept.has(field):
					kept[field] = (kept[field] as Array) + (look[field] as Array)
				elif not kept.has(field):
					kept[field] = look[field]
		else:
			moved[target] = look
	_turns_follow(moved, before, after, taken)
	if moved == was:
		return []
	world.step_looks = moved
	return [{"undo": "steplooks", "looks": was}]


## Each step's turn after a step edit is the one its parts were seen from
## before it ([method items_by_step]'s "turns"), written again only where it
## changes from the step before: a ROTSTEP ending an empty step, which the
## edit takes out, gives its turn to the step it turned. Parts [param taken]
## into a step that has its own are seen as it is. Two steps made one (a
## merge) are seen from the first's turn if it had one of its own (a
## ROTSTEP that turns, not one that ends a turn), else the second's, as the
## rest of a merged look is kept; else as most of their parts were. A turn
## written as it was keeps its line.
static func _turns_follow(looks: Dictionary, before: Dictionary, after: Dictionary,
		taken: Dictionary = {}) -> void:
	var turns: Dictionary = before.get("@turns", {})
	var owns: Dictionary = before.get("@own", {})
	for definition: String in after:
		if definition.begins_with("@"):
			continue
		var then: Dictionary = before.get(definition, {})
		var now: Dictionary = after[definition]
		if then == now:
			continue
		var seen: Dictionary = turns.get(definition, {})
		var own: Dictionary = owns.get(definition, {})
		var steps: Dictionary = {}
		for item: String in now:
			steps[int(now[item])] = true
		var order: Array = steps.keys()
		order.sort()
		var want: Dictionary = {}
		for step: int in order:
			# The steps its parts came from: those it kept, without the ones
			# taken into it, when it kept any.
			var from: Dictionary = {}
			for item: String in now:
				if int(now[item]) == step and then.has(item) and not taken.has(item):
					from[int(then[item])] = int(from.get(int(then[item]), 0)) + 1
			if from.is_empty():
				for item: String in now:
					if int(now[item]) == step and then.has(item):
						from[int(then[item])] = int(from.get(int(then[item]), 0)) + 1
			var olds: Array = from.keys()
			olds.sort()
			var best: String = "{}"
			var chosen: bool = false
			if olds.size() > 1:
				for old: int in olds:
					if own.has(old):
						best = JSON.stringify(seen.get(old, {}))
						chosen = true
						break
			if not chosen:
				# What most of its parts were seen from.
				var votes: Dictionary = {}
				for old: int in olds:
					var was: String = JSON.stringify(seen.get(old, {}))
					votes[was] = int(votes.get(was, 0)) + int(from[old])
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


## The looks keyed as a file written whole numbers its steps (ModelStore's
## LdrModel.write_tree and write_ldr): each section's steps one after
## another, none empty. A step whose parts were all taken off the model is a
## number with nothing in it here (BrickWorld.Brick.step) and no step
## there; written as kept, each look after it went on the step after its
## own, and the file opened again had them there. What was set on a step
## that is gone goes with it, and each step is seen from what it is seen
## from now. The looks themselves where no section has an empty step. A
## file written back over (SourceFile) keeps the empty step, and its looks
## as they are.
static func as_written(world: BrickWorld, skip: Dictionary = {}) -> Dictionary:
	var looks: Dictionary = world.step_looks
	if looks.is_empty():
		return looks
	var gapped: Dictionary = {}     ## definition -> [its first copy, its steps in order]
	var sections: Array = first_copies(world, skip)
	var items_in: Dictionary = AuthorSteps.items_in(world, sections, skip)
	for section: String in sections:
		var steps: Array = AuthorSteps.steps_of(items_in[section])
		if not steps.is_empty() and int(steps[steps.size() - 1]) + 1 != steps.size():
			gapped[definition_of(section)] = [section, steps]
	if gapped.is_empty():
		return looks
	var out: Dictionary = {}
	for name: String in looks:
		var definition: String = name.get_slice("|", 0)
		var tail: String = name.get_slice("|", 1)
		if not gapped.has(definition) or not tail.is_valid_int():
			out[name] = looks[name]
			continue
		var at: int = (gapped[definition][1] as Array).find(tail.to_int())
		if at < 0:
			continue
		var look: Dictionary = (looks[name] as Dictionary).duplicate(true)
		for field: String in ["turn", "how", "line"]:
			look.erase(field)
		if not look.is_empty():
			out[key(definition, at)] = look
	for definition: String in gapped:
		var section: String = gapped[definition][0]
		var steps: Array = gapped[definition][1]
		var state: Dictionary = {}
		for at: int in steps.size():
			var turn: Dictionary = turn_at(world, section, int(steps[at]))
			if JSON.stringify(turn) == JSON.stringify(state):
				continue
			var look: Dictionary = out.get(key(definition, at), {})
			if turn.is_empty():
				look["turn"] = "end"
			else:
				look["turn"] = turn["turn"]
				look["how"] = str(turn.get("how", "REL"))
			out[key(definition, at)] = look
			state = turn
	return out


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
			"PANEL":
				var at: Array = _numbers(words, 3, 4)
				if not at.is_empty():
					_put_in(out, key(definition, step), "panel", at)
			"ARROW":
				var colour: String = value.to_lower()
				if ARROW_COLOURS.has(colour) and words.size() > 4 and words[4].is_valid_float():
					# Its ends, and every point it bends through.
					var points: Array = []
					var pairs: int = mini((words.size() - 5) / 2, MOST_BENDS + 2)
					while pairs >= 2 and points.is_empty():
						points = _numbers(words, 5, pairs * 2)
						pairs -= 1
					if not points.is_empty():
						_note_in(out, key(definition, step), {"at": points, "colour": colour,
							"width": arrow_width(words[4].to_float())}, "arrows")
			"TURN_SIGN":
				if value == "OFF":
					_put_in(out, key(definition, step), "sign", false)
			"NOTE":
				# The words or picture just before it, turned and faded.
				var notes: Array = (out.get(key(definition, step), {}) as Dictionary).get("notes", [])
				if notes.is_empty():
					continue
				var note: Dictionary = notes[-1]
				for at: int in range(3, words.size() - 1):
					var number: String = words[at + 1]
					if not number.is_valid_float():
						continue
					match words[at].to_upper():
						"TURN":
							var turn: float = turn_of({"turn": number.to_float()})
							if not is_zero_approx(turn):
								note["turn"] = turn
						"OPACITY":
							var opacity: float = opacity_of({"opacity": number.to_float() / 100.0})
							if opacity < 1.0:
								note["opacity"] = opacity
			"GUIDE":
				if value in ["X", "Y"] and words.size() > 4 and words[4].is_valid_float():
					var kept: Dictionary = (out.get(BOOKLET, {}) as Dictionary).get("guides",
						{"x": [], "y": []})
					(kept[value.to_lower()] as Array).append(snappedf(clampf(words[4].to_float(),
						0.0, Booklet.PAGE.x if value == "X" else Booklet.PAGE.y), 0.1))
					_put_in(out, BOOKLET, "guides", kept)
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


static func _note_in(out: Dictionary, name: String, note: Dictionary,
		field: String = "notes") -> void:
	var look: Dictionary = out.get(name, {})
	var notes: Array = look.get(field, [])
	notes.append(note)
	look[field] = notes
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
			_step_lines(out, looks, definition, step, any_part, eol, wrote)
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
	var kept: Dictionary = whole.get("guides", {})
	for axis: String in ["x", "y"]:
		for at: Variant in kept.get(axis, []):
			out.append(META + "GUIDE %s %s" % [axis.to_upper(), _number(snappedf(float(at), 0.1))] + eol)


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
		_step_lines(extra, looks, definition, step, any_part, eol, wrote)
	# A sub-model's callout, said once in it.
	var whole: Dictionary = looks.get(definition + "|*", {})
	if not definition.is_empty() and whole.has("callout") and not bool(whole["callout"]) \
			and not wrote.has(definition + "|*"):
		extra.append(META + "CALLOUT OFF" + eol)
		wrote[definition + "|*"] = true
	for n: int in extra.size():
		out.insert(trailing + n, extra[n])


## The app's own lines for one step, before the line that ends it. A
## sub-model's callout and the booklet's own lines go in its first step with
## a part in it ([param parts]): not in the step a ROTSTEP before the first
## part ends, which the file opened again has no part in, so the lines went
## up above that ROTSTEP on the next save.
static func _step_lines(out: PackedStringArray, looks: Dictionary, definition: String,
		step: int, parts: bool, eol: String, wrote: Dictionary) -> void:
	if parts and not definition.is_empty():
		var whole: Dictionary = looks.get(definition + "|*", {})
		if whole.has("callout") and not bool(whole["callout"]) and not wrote.has(definition + "|*"):
			out.append(META + "CALLOUT OFF" + eol)
			wrote[definition + "|*"] = true
	if definition.is_empty() and parts and looks.has(BOOKLET) and not wrote.has(BOOKLET):
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
	if look.has("sign") and not bool(look["sign"]):
		out.append(META + "TURN_SIGN OFF" + eol)
	if look.has("panel"):
		out.append(META + "PANEL " + _numbers_said(look["panel"]) + eol)
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
		else:
			continue
		var how := PackedStringArray()
		if not is_zero_approx(turn_of(note)):
			how.append("TURN " + _number(snappedf(turn_of(note), 0.1)))
		if opacity_of(note) < 1.0:
			how.append("OPACITY " + _number(roundf(opacity_of(note) * 100.0)))
		if not how.is_empty():
			out.append(META + "NOTE " + " ".join(how) + eol)
	for arrow: Variant in look.get("arrows", []):
		if arrow is Dictionary and (arrow as Dictionary).has("at"):
			out.append(META + "ARROW %s %s %s" % [str(arrow.get("colour", "red")).to_upper(),
				_number(arrow_width(float(arrow.get("width", 0.9)))), _numbers_said(arrow["at"])] + eol)


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


## [param rect] as a look keeps it: [x, y, w, h] to a tenth of a mm.
static func said_rect(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
		snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]


## Whether two rooms on a page are the same one, to SAME_ROOM mm.
static func same_room(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < SAME_ROOM \
		and a.size.distance_to(b.size) < SAME_ROOM


## [param look]'s placed items, words, pictures and arrows moved from the
## room they were placed in (its "panel") into [param room], the step's
## room on its page now, and scaled with it: each centre to the same place
## in the room, each size by the room's smaller change, so a picture keeps
## its shape. Its "panel" becomes [param room]. A look placed before rooms
## were kept (no "panel") keeps its places, in page mm, and takes [param
## room] as the one they were placed in.
static func rebased(look: Dictionary, room: Rect2) -> Dictionary:
	var out: Dictionary = look.duplicate(true)
	if room.size.x < 1.0 or room.size.y < 1.0:
		return out
	if not (out.has("place") or out.has("notes") or out.has("arrows")):
		out.erase("panel")
		return out
	if not out.has("panel"):
		out["panel"] = said_rect(room)
		return out
	var from: Rect2 = rect_of(out["panel"])
	if same_room(from, room) or from.size.x < 1.0 or from.size.y < 1.0:
		return out
	var by: Vector2 = room.size / from.size
	var k: float = minf(by.x, by.y)
	var place: Dictionary = out.get("place", {})
	for item: String in place.keys():
		var at: Array = place[item]
		match at.size():
			4:
				place[item] = said_rect(_moved(rect_of(at), from, room))
			3:
				var corner: Vector2 = _moved_point(Vector2(float(at[0]), float(at[1])), from, room)
				place[item] = [snappedf(corner.x, 0.1), snappedf(corner.y, 0.1),
					snappedf(float(at[2]) * k, 0.1)]
			2:
				var corner: Vector2 = _moved_point(Vector2(float(at[0]), float(at[1])), from, room)
				place[item] = [snappedf(corner.x, 0.1), snappedf(corner.y, 0.1)]
	for note: Variant in out.get("notes", []):
		if note is Dictionary and (note as Dictionary).has("at"):
			note["at"] = said_rect(_moved(rect_of(note["at"]), from, room))
			if (note as Dictionary).has("size"):
				note["size"] = snappedf(clampf(float(note["size"]) * k, 1.5, 40.0), 0.1)
	for arrow: Variant in out.get("arrows", []):
		if arrow is Dictionary and (arrow as Dictionary).has("at"):
			var points: Array = arrow["at"]
			var moved: Array = []
			for n: int in range(0, points.size() - 1, 2):
				var point: Vector2 = _moved_point(Vector2(float(points[n]), float(points[n + 1])),
					from, room)
				moved.append_array([snappedf(point.x, 0.1), snappedf(point.y, 0.1)])
			arrow["at"] = moved
	out["panel"] = said_rect(room)
	return out


static func _moved(rect: Rect2, from: Rect2, to: Rect2) -> Rect2:
	var by: Vector2 = to.size / from.size
	var k: float = minf(by.x, by.y)
	var centre: Vector2 = to.position + (rect.get_center() - from.position) * by
	return Rect2(centre - rect.size * k * 0.5, rect.size * k)


static func _moved_point(point: Vector2, from: Rect2, to: Rect2) -> Vector2:
	return to.position + (point - from.position) * (to.size / from.size)


## An arrow's points as [from, to, the points it bends through in order
## (Vector2s, none for a straight one)], in page mm.
static func arrow_points(arrow: Dictionary) -> Array:
	var at: Array = arrow.get("at", [])
	if at.size() < 4:
		return []
	var from := Vector2(float(at[0]), float(at[1]))
	var to := Vector2(float(at[2]), float(at[3]))
	var bends: Array = []
	for n: int in range(4, at.size() - 1, 2):
		bends.append(Vector2(float(at[n]), float(at[n + 1])))
	return [from, to, bends]


## [param points] ([method arrow_points]'s) as an arrow's "at": [x1, y1,
## x2, y2, bx, by, ...].
static func arrow_at(points: Array) -> Array:
	var out: Array = []
	for point: Vector2 in [points[0], points[1]] + (points[2] as Array):
		out.append_array([snappedf(point.x, 0.1), snappedf(point.y, 0.1)])
	return out


## The line an arrow is drawn along, from its start to where its head
## begins, and the way the head points: {"line": PackedVector2Array, "way":
## Vector2}; empty for an arrow of no length. Its head is [param head] mm
## long, as Booklet.drawn_arrow draws it. Straight, or through one bend as
## a curve whose middle is the bend; through two or more as one smooth
## curve through each in turn (Catmull-Rom), its head on the way from the
## last bend to the tip.
static func arrow_line(points: Array, head: float) -> Dictionary:
	var from: Vector2 = points[0]
	var to: Vector2 = points[1]
	var bends: Array = points[2]
	var line := PackedVector2Array()
	if bends.size() <= 1:
		var control: Vector2 = (bends[0] as Vector2) * 2.0 - (from + to) * 0.5 \
			if bends.size() == 1 else (from + to) * 0.5
		var way: Vector2 = (to - control).normalized()
		if way == Vector2.ZERO:
			return {}
		var base: Vector2 = to - way * head
		for n: int in 17:
			var t: float = n / 16.0
			line.append((1.0 - t) * (1.0 - t) * from + 2.0 * (1.0 - t) * t * control + t * t * base)
		return {"line": line, "way": way, "control": control, "base": base}
	var way: Vector2 = (to - (bends[-1] as Vector2)).normalized()
	if way == Vector2.ZERO:
		return {}
	var through: Array = [from] + bends + [to - way * head]
	for span: int in through.size() - 1:
		var p1: Vector2 = through[span]
		var p2: Vector2 = through[span + 1]
		var p0: Vector2 = through[span - 1] if span > 0 else p1 * 2.0 - p2
		var p3: Vector2 = through[span + 2] if span + 2 < through.size() else p2 * 2.0 - p1
		for n: int in range(0 if span == 0 else 1, 13):
			var t: float = n / 12.0
			line.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	return {"line": line, "way": way}


## Where along an arrow's line its span from point [param span] of [from,
## bends..., to] to the next is half drawn: where the page editor puts
## the handle that bends it there.
static func span_middle(points: Array, head: float, span: int) -> Vector2:
	var drawn: Dictionary = arrow_line(points, head)
	var through: Array = [points[0]] + (points[2] as Array) + [points[1]]
	if drawn.is_empty() or span < 0 or span >= through.size() - 1:
		return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
	var line: PackedVector2Array = drawn["line"]
	if (points[2] as Array).size() >= 2:
		# Twelve points a span.
		return line[mini(span * 12 + 6, line.size() - 1)]
	if (points[2] as Array).is_empty():
		return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
	# One bend: the curve's quarter and three quarters.
	return line[4 if span == 0 else 12]


## A word or picture of the designer's turned this far, in degrees
## clockwise, -180 to 180.
static func turn_of(note: Dictionary) -> float:
	return fposmod(float(note.get("turn", 0.0)) + 180.0, 360.0) - 180.0


## How solid a word or picture of the designer's is drawn: FAINTEST to 1.
static func opacity_of(note: Dictionary) -> float:
	return clampf(float(note.get("opacity", 1.0)), FAINTEST, 1.0)


## The nearest of the widths an arrow comes in to [param width].
static func arrow_width(width: float) -> float:
	var best: float = ARROW_WIDTHS[1]
	for one: float in ARROW_WIDTHS:
		if absf(one - width) < absf(best - width):
			best = one
	return best


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
		+ "finished model and the parts list. Places are in mm on a 269 x 199 page, and "
		+ "each step's new parts are where its picture shows them: point an arrow there. A step "
		+ "left to the booklet is seen from the front here, and may be drawn turned round: "
		+ "give it turn= to be sure.")
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
				# A callout's step on its own pages: what was placed on its page
				# only; its view is the callout's.
				var own_line: String = said(world, named, entry.look.get_slice("|", 1).to_int(),
					entry.in_callout)
				if not own_line.is_empty():
					how.append(own_line)
			if entry.adds.size.x > 0.0:
				how.append("its new parts at %s" % adds_said(entry.adds))
			if entry.callout != null:
				how.append("puts on the %s%s, %s" % [entry.callout.name,
					" x%d" % entry.callout.times if entry.callout.times > 1 else "",
					"built in a callout box" if entry.callout.inline else "built on its own pages"])
			each.append("%d%s" % [entry.number, (" (" + "; ".join(how) + ")") if not how.is_empty()
				else ""])
		var line: String = "  page %d%s: step%s %s" % [page.number,
			(" (the %s, built on its own)" % page.name) if page.kind == "callout" else "",
			"" if page.entries.size() == 1 else "s", ", ".join(each)]
		if not page.overlaps.is_empty():
			line += "; overlapping: " + Booklet.overlaps_said(page)
		characters += line.length()
		if characters > 6000:
			told.append("  ... booklet_layout {\"from\": %d} for the rest." % page.number)
			break
		told.append(line)
	if not off.is_empty():
		told.append("Built on pages of their own by choice: %s." % ", ".join(off.keys()))
	return "\n".join(told)


## Where a step's new parts are on its page, as a session reads it:
## "150-195 x 50-100 mm (the middle 172, 75)".
static func adds_said(adds: Rect2) -> String:
	return "%s-%s x %s-%s mm (the middle %s, %s)" % [_number(roundf(adds.position.x)),
		_number(roundf(adds.end.x)), _number(roundf(adds.position.y)), _number(roundf(adds.end.y)),
		_number(roundf(adds.get_center().x)), _number(roundf(adds.get_center().y))]


## How a step's look reads, for the timeline and a session: "turned 90°,
## zoom 1.5x, new page", or "".
static func said(world: BrickWorld, section: String, step: int, placed_only: bool = false) -> String:
	var parts := PackedStringArray()
	var turn: Dictionary = turn_at(world, section, step) if not placed_only else {}
	var own: Dictionary = of(world, section, step)
	if placed_only:
		own = {"place": own.get("place", {}), "notes": own.get("notes", []),
			"arrows": own.get("arrows", [])}
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
		var how: String = ""
		if not is_zero_approx(turn_of(note)):
			how += ", turned %s°" % _number(snappedf(turn_of(note), 0.1))
		if opacity_of(note) < 1.0:
			how += ", %d%% opaque" % roundi(opacity_of(note) * 100.0)
		if note.has("text"):
			parts.append("text \"%s\" at %s, %s mm%s" % [str(note["text"]).replace("\n", " / ").left(60),
				_number(snappedf(at.position.x, 0.1)), _number(snappedf(at.position.y, 0.1)), how])
		elif note.has("image"):
			parts.append("a picture at %s, %s mm, %s x %s%s" % [_number(snappedf(at.position.x, 0.1)),
				_number(snappedf(at.position.y, 0.1)), _number(snappedf(at.size.x, 0.1)),
				_number(snappedf(at.size.y, 0.1)), how])
	for arrow: Variant in own.get("arrows", []):
		if arrow is Dictionary:
			parts.append(arrow_said(arrow))
	if own.has("sign") and not bool(own["sign"]):
		parts.append("no turn sign")
	return ", ".join(parts)


## An arrow as a session reads it: "a red arrow from 20, 30 to 60, 80 mm,
## bent through 40, 40, 0.9 mm wide" ("through 40, 40 and 50, 70" for two).
static func arrow_said(arrow: Dictionary) -> String:
	var points: Array = arrow_points(arrow)
	if points.is_empty():
		return "an arrow"
	var from: Vector2 = points[0]
	var to: Vector2 = points[1]
	var bends := PackedStringArray()
	for bend: Vector2 in points[2]:
		bends.append("%s, %s" % [_number(snappedf(bend.x, 0.1)), _number(snappedf(bend.y, 0.1))])
	return "a %s arrow from %s, %s to %s, %s mm%s, %s mm wide" % [str(arrow.get("colour", "red")),
		_number(snappedf(from.x, 0.1)), _number(snappedf(from.y, 0.1)),
		_number(snappedf(to.x, 0.1)), _number(snappedf(to.y, 0.1)),
		(", bent through " + " and ".join(bends)) if not bends.is_empty() else "",
		_number(arrow_width(float(arrow.get("width", 0.9))))]
