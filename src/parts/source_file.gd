## The file a model was opened from, kept so a save writes back what nobody
## changed, as it was.
##
## Professional CAD keeps a file it did not write: LDCad, LeoCAD and Studio
## leave an author's name, licence, history, meta commands, comments,
## flexible parts and part numbers alone. Brickworks wrote every save from
## the parts on the baseplate instead, so a real set's file opened and saved
## lost all of that: the author's name and the licence that asks for it
## (every file of the LDraw model repository), every retired part number
## (5,623 parts in 45 of 48 sets), the coordinates (the model stood on the
## ground), LDCad's hoses and bands, and the parts the file carries
## (docs/CADTASK.md, 2026-10-16).
##
## So a model opened from someone else's file keeps the file. Each part on
## the baseplate is paired with the line it was read from by what it is
## (number, colour, place, sub-model copy), not by an id, so an undo, a
## move by picking up or an edit over MCP pairs the same. A save then writes
## the file again with only what changed:
##
## - a part as it was: its line, byte for byte;
## - a part moved, turned, recoloured or swapped: its line rewritten in
##   place, in its sub-model's frame, under the number the file used when it
##   is the same part (a retired number stays retired);
## - a part deleted: its line taken out;
## - a part added: a line at the end of its step, in its sub-model;
## - a part the app could not show (not in the library, not fetched yet, a
##   flexible part's skin): its line, untouched.
##
## What cannot be written into the file as it is gets null from
## [method write], and the model is written whole instead (ModelStore): a
## copy of a sub-model changed apart from its other copies, an assembly made
## or renamed, the steps of a model that had none, a sub-model's copy put in
## another step.
class_name SourceFile
extends RefCounted

## How near a part must be to where it was read to be where it was: a
## file's numbers are rounded, and a place read and written again is never
## further off than this.
const NEAR := 0.01
const TURN := 0.0001


## One part as the file placed it, in the file's own coordinates.
class Read extends RefCounted:
	var line: int
	var unit: String
	var group: String
	var part_id: String
	var colour: int
	var at: Transform3D
	var step: int
	## Put in its other hand where a sub-model mirrors it (Assemblies
	## .unmirror): written back only as it was.
	var mirrored: bool = false


var lines: PackedStringArray
## Line -> [Read], one per copy of the sub-model the line is in.
var by_line: Dictionary = {}
var count: int = 0
## Unit path -> where that copy stands in the file, and the section it is
## a copy of; "" is the model itself.
var unit_frames: Dictionary = {}
var unit_sections: Dictionary = {}
var unit_colours: Dictionary = {}
## Section key -> [first line, the line after its last].
var sections: Dictionary = {}
var main_key: String = ""
## Section key -> how many copies of it the model places.
var copies: Dictionary = {}
## The steps of the copies as the file put them on, and whether its steps
## are its author's.
var unit_steps: Dictionary = {}
var authored: bool = false
## Sections that are a flexible part LDCad drew (a hose, a band, a string):
## a path and the skin it generated of primitives, which are not parts.
var flexible: Dictionary = {}
## The parts the app could not show, as LdrModel.Placement in the file's
## coordinates ([method make]).
var not_shown: Array = []
## What the model is called by the file itself: a save under another name
## says that name on a line of its own (ModelStore.TITLE_META).
var own_title: String = ""


## [param placements] are what the model opened as: every part put down or
## on its way, after its number was resolved, before the model was stood on
## the ground ([member LdrModel.Placement.line] set).
## [param hidden_parts] are the parts it holds the app cannot show (not in the
## library): kept in it, and carried by a model written whole.
static func make(text: String, model: LdrModel, placements: Array,
		mirrored_lines: Dictionary, authored_steps: bool, hidden_parts: Array = []) -> SourceFile:
	var source := SourceFile.new()
	source.not_shown = hidden_parts.duplicate()
	source.lines = text.split("\n")
	source.unit_frames = model.unit_frames.duplicate()
	source.unit_sections = model.unit_sections.duplicate()
	source.unit_colours = model.unit_colours.duplicate()
	source.unit_steps = model.unit_steps.duplicate()
	source.authored = authored_steps
	source._read_sections()
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		if placement.line < 0:
			continue
		var origin := Read.new()
		origin.line = placement.line
		origin.unit = placement.unit
		origin.group = placement.group
		origin.part_id = placement.part_id
		origin.colour = placement.color_code
		origin.at = placement.transform
		origin.step = placement.step
		origin.mirrored = mirrored_lines.has("%d|%s" % [placement.line, placement.unit])
		if not source.by_line.has(origin.line):
			source.by_line[origin.line] = []
		(source.by_line[origin.line] as Array).append(origin)
		source.count += 1
	for unit: String in source.unit_sections:
		var key: String = source.unit_sections[unit]
		source.copies[key] = int(source.copies.get(key, 0)) + 1
	return source


## Where each FILE section's lines are; a file without any is one section.
func _read_sections() -> void:
	var current: String = ""
	var first: int = 0
	var any_file: bool = false
	for n: int in lines.size():
		var words: PackedStringArray = lines[n].strip_edges().split(" ", false)
		if words.size() < 2 or words[0] != "0":
			continue
		if words[1] == "!LDCAD" and words.size() > 2 \
				and (words[2] == "PATH_SKIN" or words[2] == "GENERATED"):
			flexible[current] = true
		var keyword: String = words[1].to_upper()
		if keyword != "FILE" and keyword != "NOFILE" and keyword != "!DATA":
			continue
		if any_file and not current.is_empty() and not sections.has(current):
			sections[current] = [first, n]
		current = ""
		if keyword == "FILE":
			current = LdrModel._key(" ".join(words.slice(2)))
			first = n
			if not any_file:
				main_key = current
			any_file = true
	if any_file and not current.is_empty() and not sections.has(current):
		sections[current] = [first, lines.size()]
	if not any_file:
		main_key = ""
		sections[""] = [0, lines.size()]


## The section a copy's parts are in: the model's own for "".
func _section_of(unit: String) -> String:
	return main_key if unit.is_empty() else str(unit_sections.get(unit, "\u0000"))


## What of [param placements], parts the app cannot show, a person reads:
## a flexible part by the sub-model it is (one each, however many pieces
## of skin it is drawn with), anything else by its number. Name -> how many.
func unshown(placements: Array) -> Dictionary:
	var out: Dictionary = {}
	var counted: Dictionary = {}
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var section: String = _section_of(placement.unit)
		if flexible.has(section) and not placement.unit.is_empty():
			if counted.has(placement.unit):
				continue
			counted[placement.unit] = true
			var named: String = "%s (flexible)" % Assemblies.definition(
				Assemblies.leaf(placement.unit))
			out[named] = int(out.get(named, 0)) + 1
		else:
			out[placement.part_id] = int(out.get(placement.part_id, 0)) + 1
	return out


## [param text], the model written whole (ModelStore), with what the app
## could not show carried into it, so a model written whole loses nothing it
## could not show either: a sub-model that is nothing but such parts (a
## flexible part) placed where each copy of it was, and its section as the
## file had it; any other such part placed where it was, in the model's own
## section; and every section of the file those name. [param waiting] are
## parts still on their way, in the file's coordinates.
func carried_into(text: String, waiting: Array) -> String:
	var parts: Array = not_shown + waiting
	if parts.is_empty():
		return text
	var shown_sections: Dictionary = {}
	for line: int in by_line:
		shown_sections[_section_at(line)] = true
	var refs := PackedStringArray()
	var placed_units: Dictionary = {}
	var needed: Dictionary = {}    ## section key -> true
	for item: Variant in parts:
		var placement: LdrModel.Placement = item
		var unit: String = _outermost_unshown(placement.unit, shown_sections)
		if not unit.is_empty():
			if placed_units.has(unit):
				continue
			placed_units[unit] = true
			var section: String = str(unit_sections[unit])
			needed[section] = true
			refs.append("1 %s %s %s" % [_colour_token(int(unit_colours.get(unit, 16))),
				LdrModel._line_numbers(unit_frames[unit]), _file_name(section)])
			continue
		var reference: String = placement.part_id + ".dat"
		if placement.line >= 0:
			var words: PackedStringArray = LdrModel._fields(lines[placement.line].strip_edges())
			if words.size() >= 15:
				reference = " ".join(words.slice(14))
		if sections.has(LdrModel._key(reference)):
			needed[LdrModel._key(reference)] = true
		refs.append("1 %s %s %s" % [_colour_token(placement.color_code),
			LdrModel._line_numbers(placement.transform), reference])
	# And what those sections draw on that the file carries.
	var todo: Array = needed.keys()
	while not todo.is_empty():
		var key: String = todo.pop_back()
		var span: Array = sections[key]
		for n: int in range(int(span[0]) + 1, int(span[1])):
			var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
			if words.size() < 15 or words[0] != "1":
				continue
			var named: String = LdrModel._key(" ".join(words.slice(14)))
			if sections.has(named) and not needed.has(named):
				needed[named] = true
				todo.append(named)
	var out: String = text
	if not out.begins_with("0 FILE "):
		out = "0 FILE %s.ldr\n%s0 NOFILE\n" % [
			(own_title if not own_title.is_empty() else "model").to_snake_case(), out]
	var cut: int = out.find("\n0 NOFILE")
	var body: String = "\n".join(refs)
	out = out.substr(0, cut + 1) + body + out.substr(cut) if cut >= 0 \
		else out + body + "\n"
	if not out.ends_with("\n"):
		out += "\n"
	for key: String in needed:
		if out.contains("\n0 FILE " + _file_name(key) + "\n"):
			continue
		var span: Array = sections[key]
		var section := PackedStringArray(lines.slice(int(span[0]), int(span[1])))
		var written: String = "\n".join(section).strip_edges()
		out += written + ("\n" if written.ends_with("0 NOFILE") else "\n0 NOFILE\n")
	return out


## The outermost copy above (or at) [param unit] whose section and every
## section inside it shows nothing: "" when there is none.
func _outermost_unshown(unit: String, shown_sections: Dictionary) -> String:
	var found: String = ""
	var path: String = ""
	for segment: String in Assemblies.segments(unit):
		path = Assemblies.join(path, segment)
		if not unit_sections.has(path) or not unit_frames.has(path):
			return found
		if found.is_empty() and not _shows_any(path, shown_sections) \
				and (unit_frames[path] as Transform3D).basis.determinant() > 0.0:
			found = path
	return found


## Whether any part under the copy at [param unit] is shown.
func _shows_any(unit: String, shown_sections: Dictionary) -> bool:
	for other: String in unit_sections:
		if (other == unit or other.begins_with(unit + "/")) \
				and shown_sections.has(str(unit_sections[other])):
			return true
	return false


## The section a line is in.
func _section_at(line: int) -> String:
	for key: String in sections:
		var span: Array = sections[key]
		if line >= int(span[0]) and line < int(span[1]):
			return key
	return main_key


## A section's name as its FILE line gives it.
func _file_name(key: String) -> String:
	var span: Array = sections[key]
	var first: String = lines[int(span[0])].strip_edges()
	return first.substr(7).strip_edges() if first.begins_with("0 FILE ") else key + ".ldr"


## The meta lines of the model's own header that say whose it is and under
## what terms: kept when the model has to be written whole (ModelStore).
func header() -> PackedStringArray:
	var out := PackedStringArray()
	if not sections.has(main_key):
		return out
	var span: Array = sections[main_key]
	for n: int in range(int(span[0]), mini(int(span[1]), int(span[0]) + 40)):
		var line: String = lines[n].strip_edges()
		if line.begins_with("1 ") or _is_step(line):
			break
		for kept: String in ["0 Author:", "0 !LICENSE", "0 !LDRAW_ORG", "0 !HISTORY",
				"0 !THEME", "0 !CATEGORY", "0 !KEYWORDS", "0 !HELP"]:
			if line.begins_with(kept):
				out.append(line)
				break
	return out


## The file again, with the parts on the baseplate written into it: see the
## class. [param bricks] are the model's parts (BrickWorld.Brick, the floor
## left out), [param lift] how far the model was moved to stand on the
## ground, [param waiting] the lines whose parts are still on their way
## ("line|unit"). Null when the change cannot be written into the file as it
## is.
func write(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		unit_steps_now: Dictionary) -> Variant:
	# A copy put in another step, or steps given to a model that had none.
	for unit: String in unit_steps_now:
		if not unit_steps.has(unit) or int(unit_steps[unit]) != int(unit_steps_now[unit]):
			return null
	if not authored:
		for item: Variant in bricks:
			if (item as BrickWorld.Brick).step >= 0:
				return null
	var back := Transform3D(Basis.IDENTITY, -lift)
	# The parts as the file had them, in buckets by what they are and where.
	var open: Dictionary = {}       ## bucket -> [Read]
	for line: int in by_line:
		for origin: Read in by_line[line]:
			if waiting.has("%d|%s" % [line, origin.unit]):
				continue
			var bucket: String = _bucket(origin.unit, origin.part_id, origin.colour, origin.at)
			if not open.has(bucket):
				open[bucket] = []
			(open[bucket] as Array).append(origin)
	var paired: Dictionary = {}     ## Read -> [brick, its place in the file]
	var left: Array = []            ## [brick, place]
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var at: Transform3D = back * brick.transform
		var bucket: String = _bucket(brick.unit, brick.part_id, brick.color_code, at)
		var found: Read = null
		for origin: Read in open.get(bucket, []):
			if origin.group == brick.group and _same(origin.at, at):
				found = origin
				break
		if found == null:
			left.append([brick, at])
			continue
		(open[bucket] as Array).erase(found)
		paired[found] = [brick, at]
	# What did not pair as it was: moved, turned, recoloured or swapped, by
	# the nearest of the same copy that is left, the same part first.
	var gone: Dictionary = {}
	for bucket: String in open:
		for origin: Read in open[bucket]:
			gone[origin] = true
	if not left.is_empty() and not gone.is_empty():
		# Looked for among the same copy's (and the same part's) only: a
		# model moved whole, or an assembly renamed, is thousands of each.
		for same_part: bool in [true, false]:
			var candidates: Dictionary = {}     ## unit (|part) -> [Read]
			for origin: Read in gone:
				var key: String = origin.unit + ("|" + origin.part_id if same_part else "")
				if not candidates.has(key):
					candidates[key] = []
				(candidates[key] as Array).append(origin)
			var still: Array = []
			for entry: Array in left:
				var brick: BrickWorld.Brick = entry[0]
				var at: Transform3D = entry[1]
				var mates: Array = candidates.get(
					brick.unit + ("|" + brick.part_id if same_part else ""), [])
				var best: Read = null
				var best_d: float = INF
				for origin: Read in mates:
					if origin.group != brick.group or not gone.has(origin):
						continue
					var d: float = origin.at.origin.distance_to(at.origin)
					# Another part in its place is a swap; further off it is
					# a part taken away and another put down.
					if not same_part and d > 0.5:
						continue
					if d < best_d:
						best_d = d
						best = origin
				if best == null:
					still.append(entry)
					continue
				gone.erase(best)
				paired[best] = entry
			left = still
			if left.is_empty() or gone.is_empty():
				break

	# Each line: as it was, rewritten, or taken out.
	var replace: Dictionary = {}    ## line -> its new text, or "" to take it out
	var inserts: Dictionary = {}    ## line -> [lines to go before it]
	for line: int in by_line:
		var origins: Array = by_line[line]
		var live: Array = origins.filter(func(o: Read) -> bool:
			return not waiting.has("%d|%s" % [line, o.unit]))
		if live.is_empty():
			continue
		var removed: int = 0
		var changed: bool = false
		for origin: Read in live:
			if gone.has(origin):
				removed += 1
				continue
			var now: Array = paired[origin]
			var brick: BrickWorld.Brick = now[0]
			if brick.part_id != origin.part_id or brick.color_code != origin.colour \
					or brick.step != origin.step or not _same(origin.at, now[1]):
				changed = true
		if removed == live.size() and live.size() == origins.size():
			replace[line] = ""
			continue
		if removed > 0:
			# Some copies of a sub-model without this part and some with it.
			return null
		if not changed:
			continue
		var written: Variant = _rewritten(line, live, paired, library)
		if written == null:
			return null
		var first: Read = live[0]
		var brick: BrickWorld.Brick = (paired[first] as Array)[0]
		if brick.step != first.step:
			# Into another step of its section: out of here, in there.
			replace[line] = ""
			var to: Variant = _step_end(_section_of(first.unit), brick.step)
			if to == null:
				return null
			_insert(inserts, to, _step_lines(_section_of(first.unit), brick.step) + [written])
		else:
			replace[line] = written

	# Parts added: at the end of their step, in their copy's sub-model.
	for entry: Array in left:
		var brick: BrickWorld.Brick = entry[0]
		var at: Transform3D = entry[1]
		var section: String = _section_of(brick.unit)
		if not sections.has(section) or int(copies.get(section, 1)) > 1:
			return null
		if not brick.unit.is_empty() and brick.group != Assemblies.group_of(brick.unit):
			return null
		if brick.unit.is_empty() and not brick.group.is_empty():
			return null
		var frame: Transform3D = unit_frames.get(brick.unit, Transform3D.IDENTITY)
		if frame.basis.determinant() < 0.0:
			return null
		var local: Transform3D = frame.affine_inverse() * at
		var to: Variant = _step_end(section, brick.step)
		if to == null:
			return null
		_insert(inserts, to, _step_lines(section, brick.step)
			+ ["1 %s %s %s.dat" % [_colour_token(brick.color_code),
				LdrModel._line_numbers(local), brick.part_id]])

	_drop_emptied(replace, left)

	# A line written here ends as the file's lines do (Studio's in "\r\n").
	var eol: String = "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""
	var out := PackedStringArray()
	for n: int in lines.size():
		for extra: String in inserts.get(n, []):
			out.append(extra + eol)
		if replace.has(n):
			if not str(replace[n]).is_empty():
				out.append(str(replace[n]) + eol)
			continue
		out.append(lines[n])
	for extra: String in inserts.get(lines.size(), []):
		out.append(extra + eol)
	return "\n".join(out)


## A sub-model whose every part was taken out goes with them: its FILE
## block, and each line that places it. Left in, the saved file kept an
## empty sub-model, still placed where the assembly had been, which another
## program's list of sub-models shows (2026-10-16). A sub-model is kept while
## anything stays in it: a part not taken out, one the app cannot show, a
## part added here ([param left]), a sub-model of its own still in use, or
## an LDCad flexible part's skin.
func _drop_emptied(replace: Dictionary, left: Array) -> void:
	var kept: Dictionary = {}
	for entry: Array in left:
		kept[_section_of((entry[0] as BrickWorld.Brick).unit)] = true
	var emptied: Dictionary = {}
	var more: bool = true
	while more:
		more = false
		for key: String in sections:
			if key == main_key or emptied.has(key) or kept.has(key) or flexible.has(key):
				continue
			var span: Array = sections[key]
			var placed_any: bool = false
			var all_gone: bool = true
			for n: int in range(int(span[0]), int(span[1])):
				var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
				if words.size() < 15 or words[0] != "1":
					continue
				placed_any = true
				var named: String = LdrModel._key(" ".join(words.slice(14)))
				if sections.has(named):
					if not emptied.has(named):
						all_gone = false
						break
				elif not (replace.has(n) and str(replace[n]).is_empty()):
					all_gone = false
					break
			if placed_any and all_gone:
				emptied[key] = true
				more = true
	if emptied.is_empty():
		return
	for key: String in sections:
		var span: Array = sections[key]
		if emptied.has(key) and int(span[1]) < lines.size() \
				and lines[int(span[1])].strip_edges().to_upper().begins_with("0 NOFILE"):
			replace[int(span[1])] = ""
		for n: int in range(int(span[0]), int(span[1])):
			if emptied.has(key):
				replace[n] = ""
				continue
			var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
			if words.size() >= 15 and words[0] == "1" \
					and emptied.has(LdrModel._key(" ".join(words.slice(14)))):
				replace[n] = ""


## The line for a part changed in every copy alike, or null when the copies
## now differ: one line cannot say two things.
func _rewritten(line: int, live: Array, paired: Dictionary, library: PartLibrary) -> Variant:
	var words: PackedStringArray = LdrModel._fields(lines[line].strip_edges())
	if words.size() < 15:
		return null
	var reference: String = " ".join(words.slice(14))
	var written_id: String = LdrModel._key(reference)
	var text: String = ""
	for origin: Read in live:
		if origin.mirrored:
			return null
		var now: Array = paired[origin]
		var brick: BrickWorld.Brick = now[0]
		var frame: Transform3D = unit_frames.get(origin.unit, Transform3D.IDENTITY)
		var local: Transform3D = frame.affine_inverse() * (now[1] as Transform3D)
		var ref: String = brick.part_id + ".dat"
		# The number the file used when it is this part: a retired number
		# stays the file's, placed where its stub puts the part it became.
		var plain: String = written_id.substr(3) if written_id.begins_with("bl_") else written_id
		if library != null and (library.resolve(written_id) == brick.part_id
				or library.resolve(plain) == brick.part_id):
			var by: Transform3D = library.moved_by(written_id) \
				if library.resolve(written_id) == brick.part_id else library.moved_by(plain)
			local = local * by.affine_inverse()
			ref = reference
		elif written_id == brick.part_id:
			ref = reference
		var colour: String = words[1] if brick.color_code == origin.colour \
			else _colour_token(brick.color_code)
		var said: String = "1 %s %s %s" % [colour, LdrModel._line_numbers(local), ref]
		if not text.is_empty() and said != text:
			return null
		text = said
	return text


static func _colour_token(code: int) -> String:
	return "0x%07X" % code if LdrModel.is_direct_colour(code) else str(code)


## Where a part of step [param step] goes in [param section]: before the
## line that ends that step, or at the section's end; null when there is no
## such section.
func _step_end(section: String, step: int) -> Variant:
	if not sections.has(section):
		return null
	var span: Array = sections[section]
	var seen: int = 0
	if step >= 0:
		for n: int in range(int(span[0]), int(span[1])):
			if _is_step(lines[n]):
				if seen == step:
					return n
				seen += 1
	var end: int = int(span[1])
	while end > int(span[0]) + 1 and lines[end - 1].strip_edges().is_empty():
		end -= 1
	return end


## The STEP lines a part of step [param step] needs before it at the end of
## [param section]: none unless the section has fewer steps.
func _step_lines(section: String, step: int) -> Array:
	if step < 0 or not sections.has(section):
		return []
	var span: Array = sections[section]
	var have: int = 0
	for n: int in range(int(span[0]), int(span[1])):
		if _is_step(lines[n]):
			have += 1
	var out: Array = []
	for _n: int in maxi(step - have, 0):
		out.append("0 STEP")
	return out


static func _is_step(line: String) -> bool:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	return words.size() >= 2 and words[0] == "0" \
		and (words[1].to_upper() == "STEP" or words[1].to_upper() == "ROTSTEP")


static func _insert(inserts: Dictionary, at: int, added: Array) -> void:
	if not inserts.has(at):
		inserts[at] = []
	(inserts[at] as Array).append_array(added)


static func _bucket(unit: String, part_id: String, colour: int, at: Transform3D) -> String:
	return "%s|%s|%d|%d|%d|%d" % [unit, part_id, colour, roundi(at.origin.x * 8.0),
		roundi(at.origin.y * 8.0), roundi(at.origin.z * 8.0)]


static func _same(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > NEAR:
		return false
	for k: int in 3:
		if not (a.basis[k] - b.basis[k]).is_zero_approx() \
				and (a.basis[k] - b.basis[k]).length() > TURN:
			return false
	return true
