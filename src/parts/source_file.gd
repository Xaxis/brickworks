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
##   flexible part's skin): its line, untouched;
## - steps given to a model that had none: each sub-model's lines put in the
##   steps their parts are in, a note with the part after it;
## - a copy of a sub-model now built in the steps of the one that places it
##   (AuthorSteps.IN_PARENT): its parts written into that one's steps after a
##   line naming it (LdrModel.IN_META), as a model written whole says it, and
##   its own section kept as it was.
##
## What cannot be written into the file as it is gets null from
## [method write], and the model is written whole instead (ModelStore): a
## copy of a sub-model changed apart from its other copies, an assembly made
## or renamed, a copy the file built in its parent's steps built whole.
## Written whole, a model kept only its header's licence and history and the
## parts the app could not show: a step edit on a model with no steps of its
## own, or one whose copies the castle's way builds in its steps (stepskeep),
## cost the file every comment, every meta command, every sub-model's own
## header and every retired number (keeptext, 2026-11-05).
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
	## Its part still on its way, in a source [method _shaped] changed: the
	## line it waits on, by where it is now.
	var held: bool = false


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
## Unit path -> the line that places that copy (LdrModel.unit_lines).
var unit_lines: Dictionary = {}
## Sections that are a flexible part LDCad drew (a hose, a band, a string):
## a path and the skin it generated of primitives, which are not parts.
var flexible: Dictionary = {}
## The parts the app could not show, as LdrModel.Placement in the file's
## coordinates ([method make]).
var not_shown: Array = []
## What the model is called by the file itself: a save under another name
## says that name on a line of its own (ModelStore.TITLE_META).
var own_title: String = ""
## Why the last [method write] said the file cannot keep its text, for a
## probe to name: "" when it could.
static var why_whole: String = ""
## Sections [method _shaped] said a copy built in their steps into: written
## again a step at a time ([method _restep]).
var restep_now: Dictionary = {}
## Each line of such a copy said to be its by an IN_META line: line -> the
## copy's path within the section.
var within_now: Dictionary = {}


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
	source.unit_lines = model.unit_lines.duplicate()
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


## The section a copy's parts are in: the model's own for "", that of the
## one round it for a copy the file wrote in its parent's steps (IN_META),
## and for a copy of none a newline, which no section's name can hold. Not a
## NUL character: the engine says "Unicode parsing error" for one in a
## script, three lines every run, which crowded the suite's report of what
## failed.
func _section_of(unit: String) -> String:
	unit = _placed(unit)
	return main_key if unit.is_empty() else str(unit_sections.get(unit, "\n"))


## [param unit], or for a copy the file wrote in the steps of the one round
## it, the nearest round it the file placed by a reference: the copy whose
## section and frame its lines are in.
func _placed(unit: String) -> String:
	while not unit.is_empty() and not unit_sections.has(unit) \
			and int(unit_steps.get(unit, -1)) == AuthorSteps.IN_PARENT:
		unit = Assemblies.parent_of(unit)
	return unit


## The frame the lines of [param unit]'s parts are written in.
func _frame_of(unit: String) -> Transform3D:
	return unit_frames.get(_placed(unit), Transform3D.IDENTITY)


## The path of [param unit] within [param home], the copy whose section its
## lines are in: "" for the home's own, as an IN_META line names it.
static func _within(unit: String, home: String) -> String:
	if unit == home:
		return ""
	return unit if home.is_empty() else unit.substr(home.length() + 1)


## The copy [param unit] is built in the steps of, by [param now]: itself,
## or the nearest round it built in steps of its own.
static func _home(unit: String, now: Dictionary) -> String:
	while not unit.is_empty() and int(now.get(unit, -1)) == AuthorSteps.IN_PARENT:
		unit = Assemblies.parent_of(unit)
	return unit


## The copy [param unit]'s parts are written into the steps of when they
## leave its section ([param moved], the copies [method write] builds in
## their parent's steps now): that one's home, or null for a part written
## in its own section.
static func _moved_into(unit: String, now: Dictionary, moved: Dictionary) -> Variant:
	while not unit.is_empty() and int(now.get(unit, -1)) == AuthorSteps.IN_PARENT:
		if moved.has(unit):
			return moved[unit]
		unit = Assemblies.parent_of(unit)
	return null


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


## [param text], the model written whole (ModelStore._text_into: a change
## this file cannot say as it is), with the file's own lines in it again:
## each comment, note, meta and empty line beside the part or copy it stood
## before in its section (those that end a step or a section, after the one
## before them), and each part's line byte for byte where the app's says
## the same thing. Written whole before keeptext2, a file with a note before
## every part lost 52 of its 64 lines.
func kept_in(text: String, library: PartLibrary) -> String:
	var written: PackedStringArray = text.split("\n")
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return text
	var by_place: Dictionary = {}       ## colour and place -> [[unit, part, line]]
	var part_on: Dictionary = {}        ## a line the app wrote -> the part it places
	for item: Variant in model.flatten(library.parts if library != null else {}):
		var placement: LdrModel.Placement = item
		if placement.line < 0:
			continue
		part_on[placement.line] = placement.part_id
		var key: String = _place_key(placement.color_code, placement.transform)
		if not by_place.has(key):
			by_place[key] = []
		(by_place[key] as Array).append([placement.unit, placement.part_id, placement.line])
	var placing: Dictionary = {}        ## a line of this file -> the copies it places
	for unit: String in unit_lines:
		var at: int = int(unit_lines[unit])
		if not placing.has(at):
			placing[at] = []
		(placing[at] as Array).append(unit)
	# The app's sections, and the lines each has, which are not put in twice.
	var span_of: PackedInt32Array = PackedInt32Array()
	span_of.resize(written.size())
	var heads: Array = [0]
	var has: Array = [{}]
	for n: int in written.size():
		if written[n].strip_edges().to_upper().begins_with("0 FILE ") and n > 0:
			heads.append(n)
			has.append({})
		span_of[n] = heads.size() - 1
		(has[heads.size() - 1] as Dictionary)[written[n].strip_edges()] = true
	var before: Dictionary = {}         ## a line the app wrote -> the file's put before it
	var after: Dictionary = {}          ## ... and after it
	var again: Dictionary = {}          ## ... and its line, the file's
	var used: Dictionary = {}
	for key: String in sections:
		if flexible.has(key):
			continue
		var span: Array = sections[key]
		# Its title: the app wrote its own.
		var title: int = _title_line(key) if not key.is_empty() else -1
		if key.is_empty() and not lines.is_empty():
			var first: PackedStringArray = LdrModel._fields(lines[0].strip_edges())
			if first.size() >= 2 and first[0] == "0" and not first[1].begins_with("!") \
					and not first[1].begins_with("//"):
				title = 0
		var waiting: Array = []
		var last: int = -1
		var tail: int = int(span[1])
		while tail > int(span[0]) and lines[tail - 1].strip_edges().is_empty():
			tail -= 1
		for n: int in range(int(span[0]) + (0 if key.is_empty() else 1), int(span[1])):
			var line: String = lines[n].trim_suffix("\r")
			var words: PackedStringArray = LdrModel._fields(line.strip_edges())
			if _is_step(line):
				if last >= 0 and not waiting.is_empty():
					_kept(after, last, waiting, has[span_of[last]])
					waiting = []
				continue
			if not words.is_empty() and words[0] == "1":
				var at: int = _written_at(n, placing, by_place, model, used)
				if at < 0:
					continue
				used[at] = true
				if not waiting.is_empty():
					# Before the line saying which copy the next is, too.
					var put: int = at
					while put > 0 and written[put - 1].strip_edges().begins_with(LdrModel.COPY_META):
						put -= 1
					_kept(before, put, waiting, has[span_of[at]])
					waiting = []
				last = at
				var same_part: bool = placing.has(n) or by_line.has(n) \
					and (by_line[n][0] as Read).part_id == str(part_on.get(at, ""))
				if same_part and _says_same(line, written[at], placing.has(n)):
					again[at] = line
				continue
			if n == title or n >= tail:
				continue
			if words.size() >= 2 and words[0] == "0":
				var keyword: String = words[1].to_upper()
				if keyword in ["NOFILE", "FILE", "NAME:"] or keyword.begins_with("!BRICKWORKS"):
					continue
			waiting.append(line)
		if not waiting.is_empty() and last >= 0:
			_kept(after, last, waiting, has[span_of[last]])
	_named_as_file(written, again, after)
	var out := PackedStringArray()
	for n: int in written.size():
		for kept: String in before.get(n, []):
			out.append(kept)
		out.append(str(again.get(n, written[n])))
		for kept: String in after.get(n, []):
			out.append(kept)
	return "\n".join(out)


## The model written whole ([param written]) called what this file calls
## it, as a save into the file keeps it: its FILE, title and Name lines the
## file's, and a name it was saved under in a line of its own
## (ModelStore.TITLE_META), in [param again] and [param after].
func _named_as_file(written: PackedStringArray, again: Dictionary, after: Dictionary) -> void:
	if main_key.is_empty() or not sections.has(main_key) or written.is_empty() \
			or not written[0].strip_edges().to_upper().begins_with("0 FILE "):
		return
	var span: Array = sections[main_key]
	again[0] = lines[int(span[0])].trim_suffix("\r")
	var title: int = _title_line(main_key)
	var name_at: int = -1
	for n: int in range(int(span[0]) + 1, int(span[1])):
		var words: PackedStringArray = lines[n].strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "NAME:":
			name_at = n
			break
	for n: int in range(1, written.size()):
		var words: PackedStringArray = written[n].strip_edges().split(" ", false)
		if words.is_empty() or words[0] != "0" or words.size() >= 2 \
				and words[1].to_upper() in ["FILE", "NOFILE", "STEP"]:
			break
		if words.size() >= 2 and words[1].to_upper() == "NAME:":
			if name_at >= 0:
				again[n] = lines[name_at].trim_suffix("\r")
			continue
		if n == 1 and title >= 0 and words.size() >= 2 and not words[1].begins_with("!") \
				and not words[1].begins_with("//"):
			var mine: String = lines[title].trim_suffix("\r")
			if written[n].strip_edges() != mine.strip_edges():
				again[n] = mine
				if not after.has(n):
					after[n] = []
				(after[n] as Array).insert(0, ModelStore.TITLE_META + " ".join(words.slice(1)))


## [param texts] put [param into] by line [param at], but those its section
## has already (the header the app wrote it, its BFC line).
static func _kept(into: Dictionary, at: int, texts: Array, has: Dictionary) -> void:
	if not into.has(at):
		into[at] = []
	for text: String in texts:
		if text.strip_edges().is_empty() or not has.has(text.strip_edges()):
			(into[at] as Array).append(text)


static func _place_key(colour: int, at: Transform3D) -> String:
	return "%d|%d,%d,%d" % [colour, roundi(at.origin.x * 8.0), roundi(at.origin.y * 8.0),
		roundi(at.origin.z * 8.0)]


## The line the app wrote for line [param n] of this file: its part, where
## a part of its colour stands where it stood, of its copy if one does; or
## the line placing its copy. -1 for none: taken out, or moved.
func _written_at(n: int, placing: Dictionary, by_place: Dictionary, model: LdrModel,
		used: Dictionary) -> int:
	for origin: Read in by_line.get(n, []):
		var best: int = -1
		var score: int = -1
		for entry: Array in by_place.get(_place_key(origin.colour, origin.at), []):
			if used.has(int(entry[2])):
				continue
			var mine: int = (2 if str(entry[0]) == origin.unit else 0) \
				+ (1 if str(entry[1]) == origin.part_id else 0)
			if mine > score:
				score = mine
				best = int(entry[2])
		if best >= 0:
			return best
	for unit: String in placing.get(n, []):
		if model.unit_lines.has(unit) and not used.has(int(model.unit_lines[unit])):
			return int(model.unit_lines[unit])
	return -1


## Whether [param mine], a line of this file, and [param theirs], the app's
## for it, say the same: colour and place, and for a copy the sub-model.
## A part's name may be the file's for the app's (3023 for 3023b).
static func _says_same(mine: String, theirs: String, copy: bool) -> bool:
	var a: PackedStringArray = LdrModel._fields(mine.strip_edges())
	var b: PackedStringArray = LdrModel._fields(theirs.strip_edges())
	if a.size() < 15 or b.size() < 15 or a[1] != b[1]:
		return false
	for k: int in range(2, 14):
		if not a[k].is_valid_float() or not b[k].is_valid_float() \
				or absf(a[k].to_float() - b[k].to_float()) > 0.001:
			return false
	return not copy or LdrModel._key(" ".join(a.slice(14))) == LdrModel._key(" ".join(b.slice(14)))


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


## The lines of the model's own header that a model written whole does not
## write itself: whose it is and under what terms (its author, licence,
## history, theme, keywords), and every comment and meta command there of
## another program's (BFC, LDCad's, LPub's). Kept when the model has to be
## written whole (ModelStore). Its title, its Name: and this app's own lines
## are written again. Eight kinds of line were kept until keeptext; a
## comment, a BFC line or an LDCad group there went with the rest.
func header() -> PackedStringArray:
	return SourceFile.header_of(lines)


## [method header] of the model [param text] holds, read from its lines:
## the app's own file keeps its header too (ModelStore._own_header).
static func header_of(text_lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var titled: bool = false
	var started: bool = false
	for raw: String in text_lines:
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty():
			continue
		if words[0] != "0" or _is_step(line):
			break
		var keyword: String = words[1].to_upper() if words.size() > 1 else ""
		if keyword == "FILE":
			if started:
				break
			started = true
			continue
		if keyword == "NOFILE" or keyword == "!DATA":
			break
		started = true
		if words.size() == 1 or keyword == "NAME:" or keyword == "!BRICKWORKS":
			continue
		# The title is the first line that is none of those (LdrModel.parse).
		if not titled and not keyword.begins_with("!") and keyword != "BFC" \
				and keyword != "AUTHOR:" and not keyword.begins_with("//"):
			titled = true
			continue
		out.append(line)
	return out


## The file again, with the parts on the baseplate written into it: see the
## class. [param bricks] are the model's parts (BrickWorld.Brick, the floor
## left out), [param lift] how far the model was moved to stand on the
## ground, [param waiting] the lines whose parts are still on their way
## ("line|unit"). Null when the change cannot be written into the file as it
## is.
##
## A change to the tree of sub-models is said in the file first, as LDraw
## says it ([method _shaped]): a sub-model renamed, its title; a copy made
## unique, its section again under a name of its own; a copy put down, a
## line placing it; one taken off, that line out; a sub-assembly made, a
## section of its own, or its parts said to be its where the model's steps
## build it. Until keeptext2 each wrote the file whole.
func write(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		unit_steps_now: Dictionary) -> Variant:
	var present: Dictionary = _present(bricks, waiting)
	# A copy taken off keeps its step for its undo (BrickWorld.unit_steps):
	# only the copies the model has now are asked about.
	var steps_now: Dictionary = {}
	for unit: String in unit_steps_now:
		if present.has(unit):
			steps_now[unit] = unit_steps_now[unit]
	why_whole = ""
	var shaped: Array = _shaped(bricks, lift, waiting, steps_now, present, library)
	if shaped.is_empty():
		return null
	var source: SourceFile = shaped[0]
	var written: Variant = source._write(bricks, lift, shaped[1], library, steps_now)
	if written == null and why_whole.is_empty():
		why_whole = "a part's line"
	# A tree said anew is read back to be sure it is the model's: the copies'
	# numbers are the order a reader meets them in.
	if written != null and source != self and not _reads_as(str(written), present, library):
		why_whole = "read back as another tree"
		return null
	return written


static func _whole(why: String) -> bool:
	if why_whole.is_empty():
		why_whole = why
	return false


## The parts on the baseplate in the copies their paths name: a part put
## in a group with no copy of it is that group's one copy
## (Assemblies.path_of), as an opened file's are.
static func _in_paths(bricks: Array) -> Array:
	var out: Array = []
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var path: String = Assemblies.path_of(brick)
		if path == brick.unit:
			out.append(brick)
			continue
		var moved := BrickWorld.Brick.new(brick.id, brick.part_id, brick.color_code,
			brick.transform)
		moved.group = brick.group
		moved.unit = path
		moved.step = brick.step
		moved.hidden = brick.hidden
		out.append(moved)
	return out


## Every copy the model has now: each part's, each that waits for its part,
## and each holding a part the app cannot show, and every copy round them.
func _present(bricks: Array, waiting: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in bricks:
		_with_round(out, Assemblies.path_of(item as BrickWorld.Brick))
	for key: String in waiting:
		_with_round(out, key.substr(key.find("|") + 1))
	for item: Variant in not_shown:
		_with_round(out, (item as LdrModel.Placement).unit)
	return out


static func _with_round(paths: Dictionary, unit: String) -> void:
	var path: String = ""
	for segment: String in Assemblies.segments(unit):
		path = Assemblies.join(path, segment)
		paths[path] = true


# -- the tree of sub-models, said in the file ----------------------------------


## [the source with the model's tree said in it, the lines waiting as it has
## them]: this one itself while the tree is the file's, a copy of it changed
## where not; [] when the tree changed in a way the file cannot say.
## [param present] are the copies the model has now ([method _present]).
func _shaped(bricks: Array, lift: Vector3, waiting: Dictionary, unit_steps_now: Dictionary,
		present: Dictionary, library: PartLibrary) -> Array:
	var placed: Dictionary = _placed_units()
	var same: bool = true
	for path: String in present:
		if not placed.has(path):
			same = false
			break
	if same:
		# Nothing new, and no copy gone of a sub-model placed more than once:
		# one placed once goes with its parts (_drop_emptied).
		for unit: String in _gone(placed, present):
			if int(copies.get(str(unit_sections.get(unit, "")), 1)) > 1:
				same = false
				break
	if same:
		return [self, waiting]
	var back := Transform3D(Basis.IDENTITY, -lift)
	var now: Dictionary = {}    ## path -> [[brick, its place in the file]] directly in it
	for item: Variant in _in_paths(bricks):
		var brick: BrickWorld.Brick = item
		if not now.has(brick.unit):
			now[brick.unit] = []
		(now[brick.unit] as Array).append([brick, back * brick.transform])
	var source: SourceFile = _copied(waiting)
	if not source._shape(now, present, unit_steps_now, library):
		return []
	return [source, source._held()]


## Every copy the file places: by a reference, and those it wrote in the
## steps of the one round them (IN_META).
func _placed_units() -> Dictionary:
	var out: Dictionary = {}
	for unit: String in unit_steps:
		out[unit] = true
	for unit: String in unit_sections:
		out[unit] = true
	return out


## The copies the file places by a reference that the model has no more,
## the outermost of each: taken off, or now somewhere else.
func _gone(placed: Dictionary, present: Dictionary) -> Array:
	var out: Array = []
	for unit: String in placed:
		if present.has(unit) or not unit_lines.has(unit):
			continue
		var parent: String = Assemblies.parent_of(unit)
		if parent.is_empty() or present.has(parent):
			out.append(unit)
	out.sort()
	return out


## The copies the model has that the file does not place, the outermost of
## each, outermost first.
func _new_units(present: Dictionary) -> Array:
	var placed: Dictionary = _placed_units()
	var out: Array = []
	for path: String in present:
		if placed.has(path):
			continue
		var parent: String = Assemblies.parent_of(path)
		if parent.is_empty() or placed.has(parent):
			out.append(path)
	out.sort_custom(func(a: String, b: String) -> bool:
		return Assemblies.segments(a).size() < Assemblies.segments(b).size() \
			or Assemblies.segments(a).size() == Assemblies.segments(b).size() \
			and a.naturalnocasecmp_to(b) < 0)
	return out


## The names of the sub-models [param paths] are copies of.
static func _kinds_in(paths: Array) -> Dictionary:
	var out: Dictionary = {}
	for path: String in paths:
		for segment: String in Assemblies.segments(path):
			out[Assemblies.definition(segment)] = true
	return out


## The model's tree said in this source, a change at a time, as a person
## makes them: renamed, made unique, copied, made, taken off. False when
## one cannot be said.
func _shape(now: Dictionary, present: Dictionary, unit_steps_now: Dictionary,
		library: PartLibrary) -> bool:
	# A sub-model renamed: its copies' paths, but for its name, the file's.
	var kinds_now: Dictionary = _kinds_in(present.keys())
	var kinds_file: Dictionary = _kinds_in(_placed_units().keys())
	for kind: String in kinds_now:
		if kinds_file.has(kind):
			continue
		for old: String in kinds_file.keys():
			if kinds_now.has(old) or not _renamed_as(old, kind, present, now):
				continue
			if not _rename(old, kind):
				return _whole("renamed: %s as %s" % [old, kind])
			kinds_file.erase(old)
			kinds_file[kind] = true
			break
	# A copy made unique: a sub-model of its own, where a copy of another
	# the model has no more was.
	for path: String in _new_units(present):
		var kind: String = Assemblies.definition(Assemblies.leaf(path))
		if _kinds_in(_placed_units().keys()).has(kind):
			continue
		var was: String = _unique_from(path, now, present)
		if not was.is_empty() and not _fork(was, path, kind, library):
			return _whole("made unique: %s from %s" % [path, was])
	# A copy put down: a line placing it.
	for path: String in _new_units(present):
		var kind: String = Assemblies.definition(Assemblies.leaf(path))
		if _kinds_in(_placed_units().keys()).has(kind) \
				and not _copy_placed(path, now, present, unit_steps_now):
			return _whole("copied: %s" % path)
	# A sub-assembly made of the parts and copies of the one it is in.
	for path: String in _new_units(present):
		if not _made(path, now, present, unit_steps_now, library):
			return _whole("made: %s" % path)
	# A copy taken off a sub-model placed more than once: the line placing it.
	var placed: Dictionary = _placed_units()
	for unit: String in _gone(placed, present):
		if int(copies.get(str(unit_sections.get(unit, "")), 1)) > 1 and not _take_copy(unit):
			return _whole("taken off: %s" % unit)
	for path: String in present:
		if not _placed_units().has(path):
			return _whole("a copy the file cannot place: %s" % path)
	return _numbers_kept(library) or _whole("copies' numbers")


## Every copy the file places by a line of its own read back by the number
## the model gives it: where one before it went (taken off, made unique), a
## reader numbers those after it one less, and 7140-1's third rear engine
## would open as its second. The first read wrong says its number
## (LdrModel.COPY_META), and the file is read again. False when a line
## placing several copies is read wrong.
func _numbers_kept(library: PartLibrary) -> bool:
	var tries: int = 0
	while true:
		var model: LdrModel = LdrModel.parse("\n".join(lines), "model")
		if model == null:
			return false
		model.flatten(library.parts if library != null else {})
		var wrong: int = -1
		var path: String = ""
		for unit: String in unit_lines:
			var line: int = int(unit_lines[unit])
			if int(model.unit_lines.get(unit, -1)) == line:
				continue
			if wrong < 0 or line < wrong:
				wrong = line
				path = unit
		if wrong < 0:
			return true
		tries += 1
		if tries > unit_lines.size():
			return false
		for unit: String in unit_lines:
			if unit != path and int(unit_lines[unit]) == wrong:
				return false
		var said: String = "%s %d" % [LdrModel.COPY_META, Assemblies.copy_of(Assemblies.leaf(path))]
		if wrong > 0 and lines[wrong - 1].strip_edges().begins_with(LdrModel.COPY_META):
			if lines[wrong - 1].strip_edges() == said:
				return false
			lines[wrong - 1] = said + _eol()
		else:
			_put_lines(wrong, [said])
	return false


# -- renamed --


## Whether the copies of [param kind] the model has are copies of
## [param old] the file places, but for the name.
func _renamed_as(old: String, kind: String, present: Dictionary, now: Dictionary) -> bool:
	var placed: Dictionary = _placed_units()
	var reads: Dictionary = _reads_by_unit()
	var any: bool = false
	for path: String in present:
		var was: String = _named(path, kind, old)
		if was == path:
			continue
		any = true
		# Renamed, a copy has the parts it had: one made of other parts
		# and a copy of the old (6650-1's rope) is a new one.
		var had: int = 0
		for origin: Read in reads.get(was, []):
			if not origin.held:
				had += 1
		if not placed.has(was) or (now.get(path, []) as Array).size() != had:
			return false
	# And every copy the file has of it is one still.
	for unit: String in placed:
		if _named(unit, old, kind) != unit and not present.has(_named(unit, old, kind)):
			return false
	return any


## [param path] with each copy of [param from] a copy of [param to], its
## number kept.
static func _named(path: String, from: String, to: String) -> String:
	var parts: PackedStringArray = Assemblies.segments(path)
	for n: int in parts.size():
		if Assemblies.definition(parts[n]) == from:
			parts[n] = "%s#%d" % [to, Assemblies.copy_of(parts[n])]
	return "/".join(parts)


## The sub-model [param old] called [param kind]: its section's title, which
## is what a reader calls it (LdrModel._assembly_names), and each line
## naming a copy of it built in another's steps. The FILE name and every
## reference to it are the file's still, as LDCad's and Studio's
## descriptions are.
func _rename(old: String, kind: String) -> bool:
	var keys: Dictionary = {}
	for unit: String in unit_sections:
		if Assemblies.definition(Assemblies.leaf(unit)) == old:
			keys[unit_sections[unit]] = true
	if keys.size() > 1 or not _can_title(kind):
		return false
	var names: Dictionary = _names()
	for key: String in keys:
		_retitle(key, kind)
	if not _names_kept(names, keys, kind):
		return false
	for n: int in lines.size():
		var said: Variant = _in_named(lines[n])
		if said != null and not str(said).is_empty():
			var again: String = _named(str(said), old, kind)
			if again != str(said):
				lines[n] = _in_line(again) + _eol()
	_repath(func(path: String) -> String: return _named(path, old, kind))
	return true


## Whether [param kind] is read back as a section's title: no line a reader
## takes for something else.
static func _can_title(kind: String) -> bool:
	var words: PackedStringArray = kind.strip_edges().split(" ", false)
	if words.is_empty() or kind.contains("/") or kind.contains("#"):
		return false
	var keyword: String = words[0].to_upper()
	return not keyword.begins_with("!") and not keyword.begins_with("//") \
		and not keyword in ["FILE", "NOFILE", "STEP", "ROTSTEP", "BFC", "NAME:", "AUTHOR:"]


## What a reader calls each section's sub-model (LdrModel._assembly_names):
## its title, or its file name where it has none, and the file name too
## where two share a title.
func _names() -> Dictionary:
	var by_title: Dictionary = {}
	for key: String in sections:
		if key.is_empty():
			continue
		var at: int = _title_line(key)
		var title: String = key
		if at >= 0:
			var words: PackedStringArray = LdrModel._fields(lines[at].strip_edges())
			title = " ".join(words.slice(1)).strip_edges()
		title = title.replace("/", "-").replace("#", "").strip_edges()
		if not by_title.has(title):
			by_title[title] = []
		(by_title[title] as Array).append(key)
	var out: Dictionary = {}
	for title: String in by_title:
		var keys: Array = by_title[title]
		for key: String in keys:
			out[key] = title if keys.size() == 1 else "%s (%s)" % [title, key]
	return out


## Whether every section a reader called [param before] it is called still,
## but [param named], each called [param kind] now.
func _names_kept(before: Dictionary, named: Dictionary, kind: String) -> bool:
	var after: Dictionary = _names()
	for key: String in after:
		if named.has(key):
			if str(after[key]) != kind:
				return false
		elif str(after[key]) != str(before.get(key, "")):
			return false
	return true


## The line a reader takes for [param key]'s title (LdrModel.parse), or -1.
func _title_line(key: String) -> int:
	if not sections.has(key):
		return -1
	var span: Array = sections[key]
	var author: bool = false
	for n: int in int(span[0]):
		var words: PackedStringArray = lines[n].strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "AUTHOR:":
			author = true
			break
	for n: int in range(int(span[0]) + 1, int(span[1])):
		var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
		if words.is_empty():
			continue
		if words[0] == "1" and words.size() >= 15:
			return -1
		if words[0] != "0" or words.size() < 2:
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "AUTHOR:" and not author:
			author = true
			continue
		if keyword in ["STEP", "ROTSTEP", "FILE", "NOFILE", "BFC", "NAME:"] \
				or keyword.begins_with("!") or words[1].begins_with("//"):
			continue
		return n
	return -1


## [param key]'s section titled [param kind]: its title line, or one after
## its FILE line where it has none.
func _retitle(key: String, kind: String) -> void:
	var at: int = _title_line(key)
	if at >= 0:
		lines[at] = "0 " + kind + _eol()
		return
	_put_lines(int((sections[key] as Array)[0]) + 1, ["0 " + kind])


# -- made unique --


## The copy the model has no more that [param path], a sub-model the file
## has not got, was made from (Assemblies.make_unique): beside it, its parts
## where most of that one's were. "" for none.
func _unique_from(path: String, now: Dictionary, present: Dictionary) -> String:
	var parent: String = Assemblies.parent_of(path)
	var mine: Dictionary = {}
	var total: int = 0
	for unit: String in now:
		if unit != path and not unit.begins_with(path + "/"):
			continue
		for entry: Array in now[unit]:
			var brick: BrickWorld.Brick = entry[0]
			var key: String = _bucket("", brick.part_id, brick.color_code, entry[1])
			mine[key] = int(mine.get(key, 0)) + 1
			total += 1
	var best: String = ""
	var best_count: int = 0
	var reads: Dictionary = _reads_by_unit()
	for unit: String in _gone(_placed_units(), present):
		if Assemblies.parent_of(unit) != parent or not unit_sections.has(unit):
			continue
		var left: Dictionary = mine.duplicate()
		var count: int = 0
		var of: int = 0
		for under: String in reads:
			if under != unit and not under.begins_with(unit + "/"):
				continue
			for origin: Read in reads[under]:
				of += 1
				var key: String = _bucket("", origin.part_id, origin.colour, origin.at)
				if int(left.get(key, 0)) > 0:
					left[key] = int(left[key]) - 1
					count += 1
		if count > best_count and count * 2 >= maxi(of, total):
			best = unit
			best_count = count
	return best


## The copy [param was] of a sub-model, now [param path], a sub-model
## [param kind] of its own: its section again, at the end of the file,
## under a name of its own and titled [param kind], every line of it the
## file's, and the line placing the copy naming it. False when that line
## places other copies too (its sub-model placed more than once).
func _fork(was: String, path: String, kind: String, library: PartLibrary) -> bool:
	var at_line: int = int(unit_lines.get(was, -1))
	if at_line < 0 or not _can_title(kind):
		return false
	for unit: String in unit_lines:
		if int(unit_lines[unit]) == at_line and unit != was:
			return false
	var key: String = unit_sections[was]
	var span: Array = sections[key]
	var start: int = int(span[0])
	var stop: int = int(span[1])
	while stop > start + 1 and lines[stop - 1].strip_edges().is_empty():
		stop -= 1
	var name: String = _free_name(_file_name(key), library)
	var fresh: String = LdrModel._key(name)
	var title: int = _title_line(key)
	var texts: Array = []
	var into: Dictionary = {}       ## a line of the section -> its place in the copy
	for n: int in range(start, stop):
		var text: String = lines[n].trim_suffix("\r")
		var words: PackedStringArray = text.strip_edges().split(" ", false)
		if n == start:
			text = "0 FILE " + name
		elif n == title:
			text = "0 " + kind
		elif words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "NAME:":
			text = "0 Name: " + name
		into[n] = texts.size()
		texts.append(text)
		if n == start and title < 0:
			texts.append("0 " + kind)
	var names: Dictionary = _names()
	var first: int = _add_section(fresh, texts, _ends_nofile(key))
	if not _names_kept(names, {fresh: true}, kind):
		return false
	# Its parts', and its own copies', lines the copy's now.
	var moved: Dictionary = {}      ## line -> [Read]
	for line: int in by_line.keys():
		if line < start or line >= stop:
			continue
		var staying: Array = []
		for origin: Read in by_line[line]:
			if origin.unit == was or origin.unit.begins_with(was + "/"):
				origin.line = first + int(into[line])
				if not moved.has(origin.line):
					moved[origin.line] = []
				(moved[origin.line] as Array).append(origin)
			else:
				staying.append(origin)
		by_line[line] = staying
		if staying.is_empty():
			by_line.erase(line)
	for line: int in moved:
		by_line[line] = moved[line]
	for unit: String in unit_lines:
		if unit.begins_with(was + "/") and int(unit_lines[unit]) >= start \
				and int(unit_lines[unit]) < stop:
			unit_lines[unit] = first + int(into[int(unit_lines[unit])])
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		if (placement.unit == was or placement.unit.begins_with(was + "/")) \
				and placement.line >= start and placement.line < stop:
			placement.line = first + int(into[placement.line])
	unit_sections[was] = fresh
	copies[key] = int(copies.get(key, 1)) - 1
	copies[fresh] = 1
	if flexible.has(key):
		flexible[fresh] = true
	lines[at_line] = _with_reference(lines[at_line], name)
	_repath(func(unit: String) -> String:
		return path + unit.substr(was.length()) if unit == was or unit.begins_with(was + "/") \
			else unit)
	return true


## A file name like [param file_name] no section and no part has: "x 2.ldr".
func _free_name(file_name: String, library: PartLibrary) -> String:
	var stem: String = file_name
	var extension: String = ".ldr"
	for suffix: String in [".ldr", ".dat", ".mpd"]:
		if stem.to_lower().ends_with(suffix):
			extension = stem.right(suffix.length())
			stem = stem.left(stem.length() - suffix.length())
			break
	var n: int = 2
	while true:
		var name: String = "%s %d%s" % [stem, n, extension]
		var key: String = LdrModel._key(name)
		if not sections.has(key) and (library == null or not library.parts.has(key)):
			return name
		n += 1
	return ""


## Whether [param key]'s section ends in a NOFILE line, as a new section
## of this file then does.
func _ends_nofile(key: String) -> bool:
	var end: int = int((sections[key] as Array)[1])
	return end < lines.size() and lines[end].strip_edges().to_upper().begins_with("0 NOFILE")


## [param text], a line placing a sub-model or a part, placing
## [param name] instead: every other byte of it as it was.
static func _with_reference(text: String, name: String) -> String:
	var at: int = 0
	var fields: int = 0
	while at < text.length() and fields < 14:
		while at < text.length() and text[at] in [" ", "\t"]:
			at += 1
		while at < text.length() and not text[at] in [" ", "\t", "\r"]:
			at += 1
		fields += 1
	while at < text.length() and text[at] in [" ", "\t"]:
		at += 1
	return text.substr(0, at) + name + ("\r" if text.ends_with("\r") else "")


# -- copied --


## The copy at [param path] of a sub-model the file has, put down (pasted,
## duplicated, moved into another): a line placing it, at the end of its
## step in the one it is in, saying which copy it is (LdrModel.COPY_META),
## and its parts read from that sub-model's lines, as a reader reads them.
## False when its parts are not a copy of that sub-model's.
func _copy_placed(path: String, now: Dictionary, present: Dictionary,
		unit_steps_now: Dictionary) -> bool:
	var kind: String = Assemblies.definition(Assemblies.leaf(path))
	var parent: String = Assemblies.parent_of(path)
	if not parent.is_empty() and not unit_sections.has(parent):
		return false
	var home: String = _section_of(parent)
	if not sections.has(home) or not parent.is_empty() and int(copies.get(home, 1)) > 1:
		return false
	var reads: Dictionary = _reads_by_unit()
	# Of a copy of it the file places, one the model still has first.
	var sources: Array = []
	for unit: String in unit_sections:
		if Assemblies.definition(Assemblies.leaf(unit)) == kind and unit_lines.has(unit):
			sources.append(unit)
	sources.sort_custom(func(a: String, b: String) -> bool:
		return present.has(a) and not present.has(b) \
			or present.has(a) == present.has(b) and a.naturalnocasecmp_to(b) < 0)
	var fit: Dictionary = {}
	var from: String = ""
	for unit: String in sources:
		fit = _fit(unit, path, now, reads)
		if not fit.is_empty():
			from = unit
			break
	if fit.is_empty():
		return false
	var at: Transform3D = fit["at"]
	var words: PackedStringArray = LdrModel._fields(lines[int(unit_lines[from])].strip_edges())
	if words.size() < 15:
		return false
	var colour: String = words[1]
	if colour == "16" and _colour_in(parent) != _colour_in(Assemblies.parent_of(from)):
		colour = _colour_token(int(unit_colours.get(from, 16)))
	var said: String = "1 %s %s %s" % [colour,
		LdrModel._line_numbers(_frame_of(parent).affine_inverse() * at), " ".join(words.slice(14))]
	var step: int = int(unit_steps_now.get(path, -1))
	var put_in: int = step if step >= 0 else -1
	var to: int = _step_end(home, put_in)
	var put: Array = _step_lines(home, put_in)
	if put.is_empty() and not _within_at(home, to).is_empty():
		put.append(_in_line(""))
	put.append("%s %d" % [LdrModel.COPY_META, Assemblies.copy_of(Assemblies.leaf(path))])
	put.append(said)
	_put_lines(to, put)
	var line: int = to + put.size() - 1
	# The copy and every copy in it, as a reader has them.
	var map: Dictionary = fit["map"]
	var inverse: Transform3D = (unit_frames[from] as Transform3D).affine_inverse()
	for unit: String in map:
		var of: String = map[unit]
		if unit != path:
			if unit_lines.has(of):
				unit_lines[unit] = unit_lines[of]
			if unit_steps.has(of):
				unit_steps[unit] = unit_steps[of]
		if unit_sections.has(of):
			unit_sections[unit] = unit_sections[of]
			copies[unit_sections[of]] = int(copies.get(unit_sections[of], 0)) + 1
		if unit_frames.has(of):
			unit_frames[unit] = at * inverse * (unit_frames[of] as Transform3D)
		unit_colours[unit] = unit_colours.get(of, 16)
	unit_lines[path] = line
	unit_steps[path] = _step_at(home, line)
	for of: String in reads:
		if not map.values().has(of):
			continue
		var unit: String = map.find_key(of)
		for origin: Read in reads[of]:
			if origin.held:
				continue
			var read := Read.new()
			read.line = origin.line
			read.unit = unit
			read.group = Assemblies.group_of(unit)
			read.part_id = origin.part_id
			read.colour = origin.colour
			read.at = at * inverse * origin.at
			read.step = origin.step
			read.held = false
			(by_line[origin.line] as Array).append(read)
			count += 1
	return true


## How [param path]'s parts lie on those of [param from], a copy the file
## places: {"at": the frame that lays the one on the other, "map": each copy
## in [param path] -> the one it is in [param from]}, or {} when they are
## not one sub-model's parts.
func _fit(from: String, path: String, now: Dictionary, reads: Dictionary) -> Dictionary:
	var frame: Transform3D = unit_frames.get(from, Transform3D.IDENTITY)
	if frame.basis.determinant() <= 0.0:
		return {}
	var inverse: Transform3D = frame.affine_inverse()
	var theirs: Array = []      ## [Read, its place in the copy, its copy's kinds within]
	for unit: String in reads:
		if unit != from and not unit.begins_with(from + "/"):
			continue
		for origin: Read in reads[unit]:
			if origin.mirrored:
				return {}
			if origin.held:
				continue
			theirs.append([origin, inverse * origin.at, _kinds_below(unit, from)])
	var mine: Array = []        ## [brick, place, kinds within]
	for unit: String in now:
		if unit != path and not unit.begins_with(path + "/"):
			continue
		for entry: Array in now[unit]:
			mine.append([entry[0], entry[1], _kinds_below(unit, path)])
	if theirs.is_empty() or theirs.size() != mine.size():
		return {}
	var first: Array = theirs[0]
	var origin0: Read = first[0]
	for candidate: Array in mine:
		var brick: BrickWorld.Brick = candidate[0]
		if brick.part_id != origin0.part_id or brick.color_code != origin0.colour \
				or str(candidate[2]) != str(first[2]):
			continue
		var at: Transform3D = (candidate[1] as Transform3D) \
			* (first[1] as Transform3D).affine_inverse()
		if at.basis.determinant() <= 0.0:
			continue
		var map: Dictionary = _laid(theirs, mine, at, from, path)
		if not map.is_empty():
			return {"at": at, "map": map}
	return {}


## Each copy in [param path] -> the copy of [param from] it is, when every
## part of [param theirs] laid at [param at] is one of [param mine]; {} when
## not.
func _laid(theirs: Array, mine: Array, at: Transform3D, from: String, path: String) -> Dictionary:
	var open: Dictionary = {}   ## bucket -> [index into mine]
	for k: int in mine.size():
		var brick: BrickWorld.Brick = mine[k][0]
		var key: String = _bucket(str(mine[k][2]), brick.part_id, brick.color_code, mine[k][1])
		if not open.has(key):
			open[key] = []
		(open[key] as Array).append(k)
	var used: Dictionary = {}
	var map: Dictionary = {}    ## copy in path -> copy in from
	var back: Dictionary = {}
	for entry: Array in theirs:
		var origin: Read = entry[0]
		var want: Transform3D = at * (entry[1] as Transform3D)
		var found: int = -1
		for k: int in open.get(_bucket(str(entry[2]), origin.part_id, origin.colour, want), []):
			if not used.has(k) and _same(want, mine[k][1]):
				found = k
				break
		if found < 0:
			for k: int in mine.size():
				var brick: BrickWorld.Brick = mine[k][0]
				if not used.has(k) and brick.part_id == origin.part_id \
						and brick.color_code == origin.colour and str(mine[k][2]) == str(entry[2]) \
						and _same(want, mine[k][1]):
					found = k
					break
		if found < 0:
			return {}
		used[found] = true
		var unit: String = (mine[found][0] as BrickWorld.Brick).unit
		var mine_path: String = ""
		var their_path: String = ""
		var mine_parts: PackedStringArray = Assemblies.segments(unit.substr(path.length()))
		var their_parts: PackedStringArray = Assemblies.segments(origin.unit.substr(from.length()))
		if mine_parts.size() != their_parts.size():
			return {}
		mine_path = path
		their_path = from
		for n: int in range(-1, mine_parts.size()):
			if n >= 0:
				mine_path = Assemblies.join(mine_path, mine_parts[n])
				their_path = Assemblies.join(their_path, their_parts[n])
			if map.has(mine_path) and map[mine_path] != their_path \
					or back.has(their_path) and back[their_path] != mine_path:
				return {}
			map[mine_path] = their_path
			back[their_path] = mine_path
	return map


## The kinds of the copies [param unit] is in below [param top]: what two
## copies of one sub-model have in common where their numbers differ.
static func _kinds_below(unit: String, top: String) -> String:
	var out := PackedStringArray()
	for segment: String in Assemblies.segments(unit.substr(top.length())):
		out.append(Assemblies.definition(segment))
	return "/".join(out)


## How many steps of [param section] end before line [param line]: the step
## a line there is in.
func _step_at(section: String, line: int) -> int:
	var span: Array = sections[section]
	var seen: int = 0
	for n: int in range(int(span[0]), mini(line, int(span[1]))):
		if _is_step(lines[n]):
			seen += 1
	return seen


# -- made --


## The sub-assembly [param path] made of parts and copies of the one it is
## in: built in that one's steps (AuthorSteps.IN_PARENT), its lines said to
## be its where they are (IN_META); built whole, a section of its own at the
## end of the file holding their lines as they were, placed where the first
## of them was. False when its parts are not the file's of the one it is in.
func _made(path: String, now: Dictionary, present: Dictionary, unit_steps_now: Dictionary,
		library: PartLibrary) -> bool:
	var kind: String = Assemblies.definition(Assemblies.leaf(path))
	var parent: String = Assemblies.parent_of(path)
	if not parent.is_empty() and not unit_sections.has(parent):
		return false
	var home: String = _section_of(parent)
	if not sections.has(home) or not parent.is_empty() and int(copies.get(home, 1)) > 1:
		return false
	# The copies put in it: the file's, a level further down.
	var placed: Dictionary = _placed_units()
	var into: Dictionary = {}       ## a copy as the file has it -> as the model has it
	for unit: String in present:
		if not unit.begins_with(path + "/"):
			continue
		var top: String = Assemblies.segments(unit.substr(path.length() + 1))[0]
		var was: String = Assemblies.join(parent, top)
		if not placed.has(was) or present.has(was):
			return false
		into[was] = Assemblies.join(path, top)
	# Its own parts: the file's, of the one it is in, where they were.
	var reads: Dictionary = _reads_by_unit()
	var open: Dictionary = {}       ## bucket -> [Read]
	for origin: Read in reads.get(parent, []):
		var key: String = _bucket("", origin.part_id, origin.colour, origin.at)
		if not open.has(key):
			open[key] = []
		(open[key] as Array).append(origin)
	var mine: Array = []
	for entry: Array in now.get(path, []):
		var brick: BrickWorld.Brick = entry[0]
		for origin: Read in open.get(_bucket("", brick.part_id, brick.color_code, entry[1]), []):
			if not mine.has(origin) and _same(origin.at, entry[1]) \
					and (by_line[origin.line] as Array).size() == 1:
				mine.append(origin)
				break
	var within: String = _within(path, parent)
	if int(unit_steps_now.get(path, -1)) == AuthorSteps.IN_PARENT:
		# Built in the steps of the one it is in: its lines where they are,
		# said to be its.
		unit_steps[path] = AuthorSteps.IN_PARENT
		for origin: Read in mine:
			origin.unit = path
			origin.group = Assemblies.group_of(path)
			within_now[origin.line] = within
		for was: String in into:
			if unit_lines.has(was):
				within_now[int(unit_lines[was])] = within
		_repath(func(unit: String) -> String: return _moved_down(unit, into))
		restep_now[home] = true
		return true
	if int(unit_steps_now.get(path, -1)) >= 0:
		return false
	# Built whole: a section of its own.
	var taken: Array = []
	for origin: Read in mine:
		taken.append(origin.line)
	for was: String in into:
		if not unit_lines.has(was):
			return false
		for unit: String in unit_lines:
			if int(unit_lines[unit]) == int(unit_lines[was]) and unit != was \
					and not unit.begins_with(was + "/"):
				return false
		taken.append(int(unit_lines[was]))
	taken.sort()
	# A line saying what the next is goes with it.
	for n: int in taken.duplicate():
		if n > 0 and _says_next(lines[n - 1]) and not taken.has(n - 1):
			taken.append(n - 1)
	taken.sort()
	if not _can_title(kind):
		return false
	var name: String = _prefix() + kind.to_lower() + ".ldr"
	if sections.has(LdrModel._key(name)) \
			or library != null and library.parts.has(LdrModel._key(name)):
		name = _free_name(name, library)
	var fresh: String = LdrModel._key(name)
	var texts: Array = ["0 FILE " + name, "0 " + kind, "0 Name: " + name]
	for n: int in taken:
		texts.append(lines[n].trim_suffix("\r"))
	var place: int = _step_end(home, -1) if taken.is_empty() else int(taken[0])
	var said: String = "1 16 0 0 0 1 0 0 0 1 0 0 0 1 " + name
	# Their lines and copies, as they were.
	var going: Array = []           ## [index in taken, Read]
	for k: int in taken.size():
		for origin: Read in by_line.get(taken[k], []):
			going.append([k, origin])
		by_line.erase(taken[k])
	var placing: Dictionary = {}    ## copy -> index in taken
	for was: String in into:
		placing[was] = taken.find(int(unit_lines[was]))
	# The first of them the line placing the sub-assembly now, the rest out.
	if taken.is_empty():
		_put_lines(place, [said])
	else:
		lines[place] = said + _eol()
		for k: int in range(taken.size() - 1, 0, -1):
			_take_line(int(taken[k]))
	var names: Dictionary = _names()
	var first: int = _add_section(fresh, texts, _uses_nofile())
	if not _names_kept(names, {fresh: true}, kind):
		return false
	var line: int = place
	for entry: Array in going:
		var origin: Read = entry[1]
		origin.line = first + 3 + int(entry[0])
		if origin.unit == parent:
			origin.unit = path
			origin.group = Assemblies.group_of(path)
		if not by_line.has(origin.line):
			by_line[origin.line] = []
		(by_line[origin.line] as Array).append(origin)
	for was: String in into:
		unit_lines[was] = first + 3 + int(placing[was])
	unit_frames[path] = _frame_of(parent)
	unit_sections[path] = fresh
	unit_colours[path] = _colour_in(parent)
	unit_lines[path] = line
	unit_steps[path] = _step_at(home, line)
	copies[fresh] = 1
	_repath(func(unit: String) -> String: return _moved_down(unit, into))
	return true


## [param unit] in [param into]'s copies, put a level further down.
static func _moved_down(unit: String, into: Dictionary) -> String:
	for was: String in into:
		if unit == was or unit.begins_with(was + "/"):
			return str(into[was]) + unit.substr(was.length())
	return unit


## What the file's sub-models' names begin with, as the LDraw model
## repository's do ("7140 - "): a section made here named alike.
func _prefix() -> String:
	var first: String = ""
	for key: String in sections:
		if key.is_empty():
			continue
		var at: int = key.find(" - ")
		if at < 0:
			return ""
		if first.is_empty():
			first = key.substr(0, at + 3)
		elif not key.begins_with(first):
			return ""
	return first


## Whether the file ends its sections with NOFILE lines.
func _uses_nofile() -> bool:
	for key: String in sections:
		if not key.is_empty() and _ends_nofile(key):
			return true
	return false


# -- taken off --


## The copy [param unit] of a sub-model placed more than once, taken off:
## the line placing it, and the line before it saying which copy it was.
## False when that line places other copies too.
func _take_copy(unit: String) -> bool:
	var line: int = int(unit_lines[unit])
	for other: String in unit_lines:
		if int(unit_lines[other]) == line and other != unit and not other.begins_with(unit + "/"):
			return false
	var reads: Dictionary = _reads_by_unit()
	for under: String in reads:
		if under != unit and not under.begins_with(unit + "/"):
			continue
		for origin: Read in reads[under]:
			if origin.held:
				return false
			(by_line[origin.line] as Array).erase(origin)
			if (by_line[origin.line] as Array).is_empty():
				by_line.erase(origin.line)
			count -= 1
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		if placement.unit == unit or placement.unit.begins_with(unit + "/"):
			return false
	for other: String in unit_steps.keys():
		if other == unit or other.begins_with(unit + "/"):
			if unit_sections.has(other):
				copies[unit_sections[other]] = int(copies.get(unit_sections[other], 1)) - 1
			for table: Dictionary in [unit_frames, unit_sections, unit_colours, unit_steps]:
				table.erase(other)
			if other != unit:
				unit_lines.erase(other)
	unit_lines.erase(unit)
	_take_line(line)
	if line > 0 and lines[line - 1].strip_edges().begins_with(LdrModel.COPY_META):
		_take_line(line - 1)
	return true


# -- the lines and what says where they are --


## This source, to change apart from it ([method _shaped]): its parts'
## Reads new, [member Read.held] where [param waiting] has them.
func _copied(waiting: Dictionary) -> SourceFile:
	var out := SourceFile.new()
	out.lines = lines.duplicate()
	for line: int in by_line:
		var reads: Array = []
		for origin: Read in by_line[line]:
			var read := Read.new()
			read.line = origin.line
			read.unit = origin.unit
			read.group = origin.group
			read.part_id = origin.part_id
			read.colour = origin.colour
			read.at = origin.at
			read.step = origin.step
			read.mirrored = origin.mirrored
			read.held = waiting.has("%d|%s" % [line, origin.unit])
			reads.append(read)
		out.by_line[line] = reads
	out.count = count
	out.unit_frames = unit_frames.duplicate()
	out.unit_sections = unit_sections.duplicate()
	out.unit_colours = unit_colours.duplicate()
	out.sections = sections.duplicate(true)
	out.main_key = main_key
	out.copies = copies.duplicate()
	out.unit_steps = unit_steps.duplicate()
	out.authored = authored
	out.unit_lines = unit_lines.duplicate()
	out.flexible = flexible.duplicate()
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		var copy := LdrModel.Placement.new(placement.part_id, placement.color_code,
			placement.transform, placement.step)
		copy.group = placement.group
		copy.unit = placement.unit
		copy.mirrored = placement.mirrored
		copy.local = placement.local
		copy.frame = placement.frame
		copy.line = placement.line
		copy.copy = placement.copy
		copy.within = placement.within
		out.not_shown.append(copy)
	out.own_title = own_title
	return out


## The lines waiting for their parts, as [method write] is given them.
func _held() -> Dictionary:
	var out: Dictionary = {}
	for line: int in by_line:
		for origin: Read in by_line[line]:
			if origin.held:
				out["%d|%s" % [line, origin.unit]] = true
	return out


## Each copy -> the Reads of the parts in it, not in a copy inside it.
func _reads_by_unit() -> Dictionary:
	var out: Dictionary = {}
	for line: int in by_line:
		for origin: Read in by_line[line]:
			if not out.has(origin.unit):
				out[origin.unit] = []
			(out[origin.unit] as Array).append(origin)
	return out


## Every copy's path as [param change] says it is now: in what says where
## each copy is, each part's, and each the app cannot show.
func _repath(change: Callable) -> void:
	for table: Dictionary in [unit_frames, unit_sections, unit_colours, unit_steps, unit_lines]:
		var again: Dictionary = {}
		for unit: String in table:
			again[change.call(unit)] = table[unit]
		table.clear()
		table.merge(again)
	for line: int in by_line:
		for origin: Read in by_line[line]:
			origin.unit = change.call(origin.unit)
			if not origin.unit.is_empty():
				origin.group = Assemblies.group_of(origin.unit)
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		placement.unit = change.call(placement.unit)
		if not placement.unit.is_empty():
			placement.group = Assemblies.group_of(placement.unit)


func _eol() -> String:
	return "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""


## [param texts] put in before line [param at]: every line from there on,
## and all that says where one is, moved down. A section ending at
## [param at] takes them in.
func _put_lines(at: int, texts: Array) -> void:
	var by: int = texts.size()
	if by == 0:
		return
	var put := PackedStringArray()
	for text: Variant in texts:
		put.append(str(text) + _eol())
	var out := PackedStringArray(lines.slice(0, at))
	out.append_array(put)
	out.append_array(lines.slice(at))
	lines = out
	var moved: Dictionary = {}
	for line: int in by_line:
		var to: int = line + by if line >= at else line
		for origin: Read in by_line[line]:
			origin.line = to
		moved[to] = by_line[line]
	by_line = moved
	for key: String in sections:
		var span: Array = sections[key]
		if int(span[0]) >= at:
			span[0] = int(span[0]) + by
		if int(span[1]) >= at:
			span[1] = int(span[1]) + by
	for unit: String in unit_lines:
		if int(unit_lines[unit]) >= at:
			unit_lines[unit] = int(unit_lines[unit]) + by
	var within: Dictionary = {}
	for line: int in within_now:
		within[line + by if line >= at else line] = within_now[line]
	within_now = within
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		if placement.line >= at:
			placement.line += by


## Line [param at] taken out, every line after it moved up.
func _take_line(at: int) -> void:
	lines.remove_at(at)
	by_line.erase(at)
	var moved: Dictionary = {}
	for line: int in by_line:
		var to: int = line - 1 if line > at else line
		for origin: Read in by_line[line]:
			origin.line = to
		moved[to] = by_line[line]
	by_line = moved
	for key: String in sections:
		var span: Array = sections[key]
		if int(span[0]) > at:
			span[0] = int(span[0]) - 1
		if int(span[1]) > at:
			span[1] = int(span[1]) - 1
	for unit: String in unit_lines:
		if int(unit_lines[unit]) > at:
			unit_lines[unit] = int(unit_lines[unit]) - 1
	var within: Dictionary = {}
	for line: int in within_now:
		if line != at:
			within[line - 1 if line > at else line] = within_now[line]
	within_now = within
	for item: Variant in not_shown:
		var placement: LdrModel.Placement = item
		if placement.line > at:
			placement.line -= 1


## A section [param key] of [param texts] put at the end of the file, after
## the last section's empty lines, which are that section's still, and a
## NOFILE line after it where [param nofile]: the line its FILE line is at.
func _add_section(key: String, texts: Array, nofile: bool) -> int:
	var at: int = lines.size()
	# What follows the file's last line break is no line of it.
	if at > 0 and lines[at - 1].is_empty():
		at -= 1
	var put: Array = texts.duplicate()
	if nofile:
		put.append("0 NOFILE")
	_put_lines(at, put)
	# The section before it ends where it did.
	for other: String in sections:
		var span: Array = sections[other]
		if int(span[0]) < at and int(span[1]) > at:
			span[1] = at
	sections[key] = [at, at + texts.size()]
	return at


## Whether [param text], the file this source wrote with the model's tree
## said in it, is read back as that tree: every copy [param present] has,
## and no other, by the numbers the model gives them.
func _reads_as(text: String, present: Dictionary, library: PartLibrary) -> bool:
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return false
	var paths: Dictionary = {}
	for item: Variant in model.flatten(library.parts if library != null else {}):
		_with_round(paths, (item as LdrModel.Placement).unit)
	for path: String in present:
		if not path.is_empty() and not paths.has(path):
			return false
	for path: String in paths:
		if not present.has(path):
			return false
	return true


## The file again with the parts written into it, its tree the model's
## ([method write]).
func _write(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		unit_steps_now: Dictionary) -> Variant:
	bricks = _in_paths(bricks)
	# A copy put in another step is written with the rest of the steps of
	# the sub-model that places it (_restep); so are the steps given to a
	# model that had none.
	var restepped: Dictionary = restep_now.duplicate()  ## section key -> true
	# A copy the file placed by a reference, built in its parent's steps now:
	# written into the steps of the one it is built in (its home), that
	# one's section a section the model places once. Said whole until
	# keeptext, every step edit on a model given the castle's way lost the
	# file's own text.
	var moved: Dictionary = {}          ## copy -> its home
	for unit: String in unit_steps_now:
		# A copy the file never placed.
		if not unit_steps.has(unit):
			return null
		var now: int = int(unit_steps_now[unit])
		var was: int = int(unit_steps[unit])
		if now == AuthorSteps.IN_PARENT:
			if was == AuthorSteps.IN_PARENT:
				continue
			var home: String = _home(unit, unit_steps_now)
			var into: String = _section_of(home)
			if not unit_lines.has(unit) or not sections.has(into) \
					or not home.is_empty() and int(copies.get(into, 1)) > 1:
				return null
			moved[unit] = home
			restepped[into] = true
		elif was == AuthorSteps.IN_PARENT:
			# Written in its parent's steps by the file, built whole now: a
			# section the file has not got.
			return null
		elif was != now:
			if not unit_lines.has(unit):
				return null
			restepped[_section_of(_home(Assemblies.parent_of(unit), unit_steps_now))] = true
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

	# A section whose parts' steps changed is written again a step at a time.
	for line: int in by_line:
		for origin: Read in by_line[line]:
			if paired.has(origin) and _now_step(paired, origin) != origin.step \
					and _moved_into(origin.unit, unit_steps_now, moved) == null:
				restepped[_section_of(origin.unit)] = true

	# Each line: as it was, rewritten, or taken out.
	var replace: Dictionary = {}    ## line -> its new text, or "" to take it out
	var inserts: Dictionary = {}    ## line -> [lines to go before it]
	var added: Dictionary = {}      ## restepped section -> [[step, line, within, order]]
	for line: int in by_line:
		var origins: Array = by_line[line]
		var live: Array = []
		var leaving: int = 0
		for origin: Read in origins:
			if waiting.has("%d|%s" % [line, origin.unit]):
				continue
			var home: Variant = _moved_into(origin.unit, unit_steps_now, moved)
			if home == null:
				live.append(origin)
				continue
			# Of a copy built in its home's steps now: written there, where its
			# part is now, the line here left to the copies that still use it.
			leaving += 1
			if gone.has(origin):
				continue
			var now: Array = paired[origin]
			var said: Variant = _said_in(line, origin, now[0], now[1], str(home), library)
			if said == null:
				return null
			_add(added, _section_of(str(home)), [_now_step(paired, origin), said,
				_within(origin.unit, str(home)), line])
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
					or not _same(origin.at, now[1]) \
					or _now_step(paired, origin) != origin.step \
					and not restepped.has(_section_of(origin.unit)):
				changed = true
		if removed == live.size() and live.size() + leaving == origins.size():
			# A flexible part's skin stands for its GENERATED line and the
			# lines under it (CustomParts.begin_skins): taking that line out
			# is not taking the skin out.
			if lines[line].strip_edges().begins_with("0 "):
				return null
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
		var step_now: int = _now_step(paired, first)
		if step_now != first.step and not restepped.has(_section_of(first.unit)):
			# Into another step of its section: out of here, in there.
			replace[line] = ""
			var to: Variant = _step_end(_section_of(first.unit), step_now)
			if to == null:
				return null
			_insert(inserts, to, _step_lines(_section_of(first.unit), step_now) + [written])
		else:
			replace[line] = written

	# Each copy moved into its home's steps: the line placing it taken out
	# of the home's section (one inside a copy moved with it is placed in a
	# section left as it was), and each copy inside a moved one that is
	# built in steps of its own placed among the home's steps now.
	var present: Dictionary = _present(bricks, waiting)
	for unit: String in moved:
		if _moved_into(Assemblies.parent_of(unit), unit_steps_now, moved) != null:
			continue
		var at: int = int(unit_lines[unit])
		replace[at] = ""
		if at > 0 and lines[at - 1].strip_edges().begins_with(LdrModel.COPY_META):
			replace[at - 1] = ""
	for unit: String in unit_lines:
		var home: Variant = _moved_into(Assemblies.parent_of(unit), unit_steps_now, moved)
		var step: int = int(unit_steps_now.get(unit, unit_steps.get(unit, -1)))
		if home == null or step == AuthorSteps.IN_PARENT or not present.has(unit):
			continue
		var said: Variant = _placing_in(unit, str(home))
		if said == null:
			return null
		_add(added, _section_of(str(home)), [step, said,
			_within(Assemblies.parent_of(unit), str(home)), int(unit_lines[unit]), unit])

	# Parts added: at the end of their step, in their copy's sub-model, or
	# among the steps of the copy it is built in.
	var inside_at: Dictionary = {}  ## line -> the copy said last before it (IN_META)
	var alike: Variant = _alike(left, unit_steps_now, moved)
	if alike == null:
		return null
	var said_as: Dictionary = alike     ## index in left -> its line's colour, or "" when another's says it
	for k: int in left.size():
		var entry: Array = left[k]
		var brick: BrickWorld.Brick = entry[0]
		var at: Transform3D = entry[1]
		if str(said_as.get(k, "-")).is_empty():
			continue
		# A skin built from this file is no file of its own here: written
		# whole, it is carried.
		if CustomParts.is_skin(brick.part_id) and not sections.has(brick.part_id):
			return null
		if not brick.unit.is_empty() and brick.group != Assemblies.group_of(brick.unit):
			return null
		if brick.unit.is_empty() and not brick.group.is_empty():
			return null
		var home: Variant = _moved_into(brick.unit, unit_steps_now, moved)
		var own: String = _placed(brick.unit) if home == null else str(home)
		var section: String = _section_of(own)
		if not sections.has(section) or int(copies.get(section, 1)) > 1 and not said_as.has(k):
			return null
		var frame: Transform3D = unit_frames.get(own, Transform3D.IDENTITY)
		if frame.basis.determinant() < 0.0:
			return null
		var local: Transform3D = frame.affine_inverse() * at
		var said: String = "1 %s %s %s.dat" % [str(said_as.get(k, _colour_token(brick.color_code))),
			LdrModel._line_numbers(local), brick.part_id]
		var within: String = _within(brick.unit, own)
		if restepped.has(section):
			_add(added, section, [brick.step, said, within, lines.size() + k])
			continue
		var to: Variant = _step_end(section, brick.step)
		if to == null:
			return null
		var put: Array = _step_lines(section, brick.step)
		var force: String = "" if not put.is_empty() \
			else str(inside_at.get(to, _within_at(section, int(to))))
		if within != force:
			put.append(_in_line(within))
		inside_at[to] = within
		_insert(inserts, to, put + [said])

	_drop_emptied(replace, left)

	var eol_now: String = "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""
	for section: String in restepped:
		if not _restep(section, replace, inserts, added.get(section, []), paired,
				unit_steps_now, eol_now):
			return null

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


## A section whose steps changed, written again a step at a time: each
## line in the step its part, or the copy of a sub-model it places, is in
## now, and the notes between them with the step most of theirs went to;
## each step ended by the line that ended the last of the file's steps
## that went into it, so a merge takes one STEP line out, a split puts one
## in, a reorder moves whole steps with their ROTSTEP, and every line
## nobody changed is the file's, byte for byte. False when a line's copies
## are now in different steps: one line cannot be in two.
##
## A line that says what the next one is (an LDCad or MLCad group, a part
## MLCad hides) goes with it; and in a section the file gave no steps, so
## does every note, which is about the part after it (the last ones, the
## part before them): given steps by one edit, 7755-1's "The following 4
## lines don't follow the instructions" went to whichever step most of the
## model's parts were in. [param added] are [step, line, the copy it is of
## within the section (IN_META), its order], at the end of their step:
## parts put down, and those of a copy now built in this one's steps. Each
## run of a copy's lines is written after a line naming it, made again here.
func _restep(section: String, replace: Dictionary, inserts: Dictionary, added: Array,
		paired: Dictionary, unit_steps_now: Dictionary, eol: String) -> bool:
	if not sections.has(section):
		return false
	var span: Array = sections[section]
	var start: int = int(span[0])
	var stop: int = int(span[1])
	var head_end: int = start
	var own_steps: bool = false
	while head_end < stop:
		var words: PackedStringArray = LdrModel._fields(lines[head_end].strip_edges())
		if not words.is_empty() and words[0] == "1" or _is_step(lines[head_end]) \
				or _in_named(lines[head_end]) != null:
			break
		head_end += 1
	for n: int in range(head_end, stop):
		if _is_step(lines[n]):
			own_steps = true
			break
	var tail: int = stop
	while tail > head_end and lines[tail - 1].strip_edges().is_empty():
		tail -= 1
	# The copies each line places, by line.
	var placing: Dictionary = {}
	for unit: String in unit_lines:
		if _section_of(Assemblies.parent_of(unit)) != section:
			continue
		var at: int = int(unit_lines[unit])
		if not placing.has(at):
			placing[at] = []
		(placing[at] as Array).append(unit)
	# The steps as the file had them, and the line ending each; and the copy
	# each line is of, as the file's IN_META lines say.
	var blocks: Array = [[]]
	var ends: Array = [-1]
	var line_within: Dictionary = {}
	var inside: String = ""
	for n: int in range(head_end, tail):
		if _is_step(lines[n]):
			ends[ends.size() - 1] = n
			blocks.append([])
			ends.append(-1)
			inside = ""
			continue
		var said: Variant = _in_named(lines[n])
		if said != null:
			inside = str(said)
			continue
		line_within[n] = str(within_now.get(n, inside))
		(blocks[blocks.size() - 1] as Array).append(n)
	if blocks.size() > 1 and (blocks[blocks.size() - 1] as Array).is_empty():
		blocks.pop_back()
		ends.pop_back()
	# A note, and a line saying what the next is (LDCad's GROUP_NXT), in the
	# copy of the part after it in its step (the last, the part before it):
	# no IN_META line comes between them.
	for block: Array in blocks:
		var next: Variant = null
		var notes: Array = []
		for k: int in range(block.size() - 1, -1, -1):
			var n: int = block[k]
			if by_line.has(n) or placing.has(n):
				next = line_within[n]
			elif next != null:
				line_within[n] = next
			else:
				notes.append(n)
		var last: Variant = null
		for n: int in block:
			if by_line.has(n) or placing.has(n):
				last = line_within[n]
			elif last != null and notes.has(n):
				line_within[n] = last
	# Where each part and copy is now.
	var line_step: Dictionary = {}
	var latest: int = 0
	for block: Array in blocks:
		for n: int in block:
			var now: int = -2
			for origin: Read in by_line.get(n, []):
				if not paired.has(origin):
					continue
				var step: int = _now_step(paired, origin)
				if now != -2 and now != step:
					return false
				now = step
			for unit: String in placing.get(n, []):
				var step: int = int(unit_steps_now.get(unit, unit_steps.get(unit, -1)))
				if now != -2 and now != step:
					return false
				now = step
			if now >= 0:
				line_step[n] = now
				latest = maxi(latest, now)
	for entry: Array in added:
		latest = maxi(latest, int(entry[0]))
	for n: int in line_step:
		if int(line_step[n]) < 0:
			line_step[n] = latest
	# The rest of each step's lines go with most of its parts.
	var voted: Array = []
	for block: Array in blocks:
		var votes: Dictionary = {}
		for n: int in block:
			if line_step.has(n):
				votes[line_step[n]] = int(votes.get(line_step[n], 0)) + 1
		var best: int = -1
		for step: int in votes:
			if best < 0 or int(votes[step]) > int(votes[best]) \
					or int(votes[step]) == int(votes[best]) and step < best:
				best = step
		voted.append(best)
	var block_step: Array = []
	var counted: Dictionary = {}    ## a block with no part the model counts a step still
	var before: int = 0
	for k: int in blocks.size():
		var best: int = int(voted[k])
		if best < 0:
			best = before
			# A step with nothing in it the model numbers the steps after it
			# past (6650-1's doubled STEP) stays: taken out, its last step's
			# parts opened a step early.
			var free: int = 0 if k == 0 else before + 1
			for j: int in range(k + 1, blocks.size()):
				if int(voted[j]) >= 0:
					if int(voted[j]) > free:
						best = free
						counted[k] = true
					break
		block_step.append(best)
		before = best
	# A line saying what the next is, and a note where the file had no
	# steps, with the part after it.
	var note_step: Dictionary = {}
	for block: Array in blocks:
		var follow: int = -1
		for k: int in range(block.size() - 1, -1, -1):
			var n: int = block[k]
			if line_step.has(n):
				follow = int(line_step[n])
			elif follow >= 0 and (not own_steps or _says_next(lines[n])):
				note_step[n] = follow
		if own_steps:
			continue
		var last: int = -1
		for n: int in block:
			if line_step.has(n):
				last = int(line_step[n])
			elif not note_step.has(n) and last >= 0:
				note_step[n] = last
	var into: Dictionary = {}       ## step -> [[order, text, within]]
	var ending: Dictionary = {}     ## step -> the line ending it, or "" for none
	for k: int in blocks.size():
		for n: int in blocks[k]:
			var text: String = lines[n].trim_suffix("\r")
			if replace.has(n):
				text = str(replace[n])
				if text.is_empty():
					continue
			var step: int = int(line_step.get(n, note_step.get(n, block_step[k])))
			if not into.has(step):
				into[step] = []
			var placed: Array = placing.get(n, [])
			(into[step] as Array).append([float(n), text, str(line_within.get(n, "")),
				str(placed[0]) if placed.size() == 1 else ""])
		# A step with nothing in it is taken out with the line that ended
		# it: the steps are numbered as the model has them now, and what an
		# empty step's ROTSTEP turned goes with the step it turned
		# (BookletLooks.follow).
		var any: bool = counted.has(k)
		for n: int in blocks[k]:
			if line_step.has(n):
				any = true
				break
		if not any:
			continue
		ending[block_step[k]] = lines[int(ends[k])].trim_suffix("\r") if int(ends[k]) >= 0 else ""
	# Added lines after the step's own: parts put down, then each copy's run
	# in the order of its name, its lines in the order the file had them.
	var runs: Array = []
	for entry: Array in added:
		if not runs.has(str(entry[2])) and not str(entry[2]).is_empty():
			runs.append(str(entry[2]))
	runs.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for entry: Array in added:
		var step: int = int(entry[0]) if int(entry[0]) >= 0 else latest
		if not into.has(step):
			into[step] = []
		var run: int = runs.find(str(entry[2])) + 1
		(into[step] as Array).append([float(tail) + 1.0 + float(run) * 1.0e7 + float(entry[3]),
			str(entry[1]), str(entry[2]), str(entry[4]) if entry.size() > 4 else ""])
	var order: Dictionary = {}
	for step: int in into:
		order[step] = true
	for step: int in ending:
		if into.has(step) or not str(ending[step]).is_empty():
			order[step] = true
	var steps: Array = order.keys()
	steps.sort()
	for step: int in steps:
		(into.get(step, []) as Array).sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0]))
	var numbered: Dictionary = _renumbered(steps, into, tail)
	var out := PackedStringArray()
	for index: int in steps.size():
		var step: int = steps[index]
		var made: Array = into.get(step, [])
		var said: String = ""
		for item: Array in made:
			if str(item[2]) != said:
				said = str(item[2])
				out.append(_in_line(said))
			var unit: String = str(item[3])
			if numbered.has(unit) and (out.is_empty()
					or not out[out.size() - 1].begins_with(LdrModel.COPY_META)):
				out.append("%s %d" % [LdrModel.COPY_META, Assemblies.copy_of(Assemblies.leaf(unit))])
			out.append(str(item[1]))
		var ended: String = str(ending.get(step, ""))
		if not ended.is_empty():
			out.append(ended)
		elif index < steps.size() - 1:
			out.append("0 STEP")
	for n: int in range(head_end, tail):
		replace[n] = ""
	if out.is_empty():
		return true
	var joined: String = (eol + "\n").join(out)
	if head_end < tail:
		replace[head_end] = joined
	else:
		_insert(inserts, tail, [joined])
	return true


## The copies [param into] (step -> its items, in order) places by a line
## that must say which copy it is (LdrModel.COPY_META): a reader numbers the
## copies of a sub-model in the order it reads them, so where the steps put
## one copy's line before another's of the same sub-model, or a copy's line
## comes here from the section of one now built in this one's steps, each
## of that sub-model's says its number. Given steps, 31037-1's two lights
## changed places in the file and opened as each other (keeptext).
func _renumbered(steps: Array, into: Dictionary, tail: int) -> Dictionary:
	var seen: Dictionary = {}       ## a sub-model -> the lines placing it, in order
	var moved: Dictionary = {}      ## a sub-model one of whose lines moved here
	for step: int in steps:
		for item: Array in into.get(step, []):
			var unit: String = str(item[3])
			if unit.is_empty():
				continue
			var kind: String = Assemblies.definition(Assemblies.leaf(unit))
			if not seen.has(kind):
				seen[kind] = []
			(seen[kind] as Array).append(unit)
			if float(item[0]) > float(tail):
				moved[kind] = true
	var out: Dictionary = {}
	for kind: String in seen:
		var units: Array = seen[kind]
		var in_order: bool = true
		for n: int in range(1, units.size()):
			if int(unit_lines.get(units[n], 0)) < int(unit_lines.get(units[n - 1], 0)):
				in_order = false
		if in_order and not moved.has(kind):
			continue
		if units.size() < 2 and _copies_of_kind(kind) < 2:
			continue
		for unit: String in units:
			out[unit] = true
	return out


## How many copies of the sub-model [param kind] the file places.
func _copies_of_kind(kind: String) -> int:
	var count: int = 0
	for unit: String in unit_lines:
		if Assemblies.definition(Assemblies.leaf(unit)) == kind:
			count += 1
	return count


## Whether [param line] says what the line after it is: LDCad's and MLCad's
## group of the next part, MLCad's part hidden, which copy this app's next
## reference is (LdrModel.COPY_META).
static func _says_next(line: String) -> bool:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	if words.size() < 3 or words[0] != "0":
		return false
	var said: String = (words[1] + " " + words[2]).to_upper()
	return said == "!LDCAD GROUP_NXT" or said == "MLCAD BTG" or said == "MLCAD HIDE" \
		or said == LdrModel.COPY_META.substr(2)


## The copy an IN_META line names ("" for the section's own), or null for
## any other line.
static func _in_named(line: String) -> Variant:
	var text: String = line.strip_edges()
	if text != LdrModel.IN_META and not text.begins_with(LdrModel.IN_META + " "):
		return null
	return text.substr(LdrModel.IN_META.length()).strip_edges()


## The IN_META line naming [param within], or the bare one for the
## section's own.
static func _in_line(within: String) -> String:
	return LdrModel.IN_META + ("" if within.is_empty() else " " + within)


## The copy said last before line [param at] of [param section]: what a
## line put there is read as part of.
func _within_at(section: String, at: int) -> String:
	var span: Array = sections[section]
	var inside: String = ""
	for n: int in range(int(span[0]), mini(at, int(span[1]))):
		if _is_step(lines[n]):
			inside = ""
			continue
		var said: Variant = _in_named(lines[n])
		if said != null:
			inside = str(said)
	return inside


static func _add(added: Dictionary, section: String, entry: Array) -> void:
	if not added.has(section):
		added[section] = []
	(added[section] as Array).append(entry)


## The line placing the copy at [param unit], as its section has it, in the
## frame of [param home]: the copy it is placed in built in that one's steps.
func _placing_in(unit: String, home: String) -> Variant:
	var words: PackedStringArray = LdrModel._fields(lines[int(unit_lines[unit])].strip_edges())
	if words.size() < 15 or not unit_frames.has(unit):
		return null
	var at: Transform3D = (unit_frames.get(home, Transform3D.IDENTITY) as Transform3D) \
		.affine_inverse() * (unit_frames[unit] as Transform3D)
	var colour: String = words[1]
	if colour == "16" and int(unit_colours.get(unit, 0)) != _colour_in(home):
		colour = _colour_token(int(unit_colours.get(unit, 0)))
	return "1 %s %s %s" % [colour, LdrModel._line_numbers(at), " ".join(words.slice(14))]


## The colour a part's 16 is in the copy at [param home]: the model's own,
## black (LdrModel.flatten), or the colour the copy was placed in.
func _colour_in(home: String) -> int:
	return 0 if home.is_empty() else int(unit_colours.get(home, 0))


## The line of a part of a copy now built in the steps of [param home],
## written there in its frame: as the file had it, its own numbers carried
## over, where nothing changed; else as [method _said] says it now.
func _said_in(line: int, origin: Read, brick: BrickWorld.Brick, at: Transform3D, home: String,
		library: PartLibrary) -> Variant:
	var words: PackedStringArray = LdrModel._fields(lines[line].strip_edges())
	if words.size() < 15:
		return null
	var into: Transform3D = (unit_frames.get(home, Transform3D.IDENTITY) as Transform3D) \
		.affine_inverse()
	if brick.part_id == origin.part_id and brick.color_code == origin.colour \
			and _same(origin.at, at):
		var numbers := PackedFloat64Array()
		for n: int in range(2, 14):
			if not words[n].is_valid_float():
				return null
			numbers.append(words[n].to_float())
		var colour: String = words[1]
		if colour == "16" and origin.colour != _colour_in(home):
			colour = _colour_token(origin.colour)
		return "1 %s %s %s" % [colour, LdrModel._line_numbers(into * _frame_of(origin.unit)
			* LdrModel.to_transform(numbers)), " ".join(words.slice(14))]
	if origin.mirrored:
		return null
	return _said(line, origin, brick, into * at, _colour_in(home), library)


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
	var text: String = ""
	for origin: Read in live:
		if origin.mirrored:
			return null
		var now: Array = paired[origin]
		var said: Variant = _said(line, origin, now[0],
			_frame_of(origin.unit).affine_inverse() * (now[1] as Transform3D), origin.colour, library)
		if said == null or not text.is_empty() and str(said) != text:
			return null
		text = said
	return text


## The step [param origin]'s part is in now: the file's where it has none
## (a part of a copy pasted in a model with steps, put in none).
static func _now_step(paired: Dictionary, origin: Read) -> int:
	var step: int = (paired[origin][0] as BrickWorld.Brick).step
	return step if step >= 0 else origin.step


## Parts added to a copy of a sub-model the model places more than once,
## each put in every copy alike (Assemblies.copies_follow): one line in its
## section says them all. Index in [param left] -> the colour that line
## says, the first of each; "" for the rest. Null when some copies were
## given a part the others were not, or a mirrored one was.
func _alike(left: Array, unit_steps_now: Dictionary, moved: Dictionary) -> Variant:
	var by_place: Dictionary = {}   ## section|within|part|place|step -> [index, own, local]
	for k: int in left.size():
		var brick: BrickWorld.Brick = left[k][0]
		var home: Variant = _moved_into(brick.unit, unit_steps_now, moved)
		var own: String = _placed(brick.unit) if home == null else str(home)
		var section: String = _section_of(own)
		if int(copies.get(section, 1)) <= 1 or not sections.has(section):
			continue
		var frame: Transform3D = unit_frames.get(own, Transform3D.IDENTITY)
		if frame.basis.determinant() < 0.0:
			return null
		var local: Transform3D = frame.affine_inverse() * (left[k][1] as Transform3D)
		var key: String = "%s|%s|%s|%d" % [section, _within(brick.unit, own),
			_bucket("", brick.part_id, 0, local), brick.step]
		if not by_place.has(key):
			by_place[key] = []
		(by_place[key] as Array).append([k, own, local])
	var out: Dictionary = {}
	for key: String in by_place:
		var found: Array = by_place[key]
		var section: String = _section_of(str(found[0][1]))
		var copies_of: Dictionary = {}
		for unit: String in unit_sections:
			if str(unit_sections[unit]) == section:
				copies_of[unit] = true
		var seen: Dictionary = {}
		var colours: Dictionary = {}
		var inherited: bool = true
		for entry: Array in found:
			var brick: BrickWorld.Brick = left[int(entry[0])][0]
			if seen.has(entry[1]) or not _same(entry[2], found[0][2]):
				return null
			seen[entry[1]] = true
			colours[brick.color_code] = true
			if brick.color_code != int(unit_colours.get(entry[1], -1)):
				inherited = false
		if seen.size() != copies_of.size() or seen.size() != int(copies.get(section, 1)):
			return null
		var first: BrickWorld.Brick = left[int(found[0][0])][0]
		out[int(found[0][0])] = _colour_token(first.color_code) if colours.size() == 1 \
			else ("16" if inherited else "")
		if str(out[int(found[0][0])]).is_empty():
			return null
		for n: int in range(1, found.size()):
			out[int(found[n][0])] = ""
	return out


## The line read as [param origin] from line [param line], for [param brick]
## placed at [param local] in the frame the line is written in: under the
## number the file used when it is this part, and in the colour the file
## said while it is still that one, a 16 only where it is still the colour
## a 16 is there ([param inherit]).
func _said(line: int, origin: Read, brick: BrickWorld.Brick, local: Transform3D, inherit: int,
		library: PartLibrary) -> Variant:
	var words: PackedStringArray = LdrModel._fields(lines[line].strip_edges())
	if words.size() < 15:
		return null
	var reference: String = " ".join(words.slice(14))
	var written_id: String = LdrModel._key(reference)
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
		and (words[1] != "16" or inherit == origin.colour) else _colour_token(brick.color_code)
	return "1 %s %s %s" % [colour, LdrModel._line_numbers(local), ref]


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
