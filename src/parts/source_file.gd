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
	## Its place in the file, which no edit changes (LdrModel.Placement
	## .origin): the lines placing the copies round it and its own.
	var origin: String = ""


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
	source.original = source.lines.duplicate()
	source.unit_chains = model.unit_chains.duplicate()
	for item: Variant in hidden_parts:
		source.unshown_origins[(item as LdrModel.Placement).origin] = item
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
		origin.origin = placement.origin
		if not placement.origin.is_empty():
			source.by_origin[placement.origin] = origin
		if not source.by_line.has(origin.line):
			source.by_line[origin.line] = []
		(source.by_line[origin.line] as Array).append(origin)
		source.count += 1
	for unit: String in source.unit_sections:
		var key: String = source.unit_sections[unit]
		source.copies[key] = int(source.copies.get(key, 0)) + 1
	source._read_for_patch()
	return source


## Where each FILE section's lines are; a file without any is one section.
func _read_sections() -> void:
	var current: String = ""
	var first: int = 0
	var any_file: bool = false
	for n: int in lines.size():
		# Split as LdrModel.parse splits a line (a tab is a space), so a
		# section here is the one it read the parts of.
		var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
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


## The section a copy's parts are in: the model's own for "", and for a
## copy of none a newline, which no section's name can hold. Not a NUL
## character: the engine says "Unicode parsing error" for one in a script,
## three lines every run, which crowded the suite's report of what failed.
func _section_of(unit: String) -> String:
	return main_key if unit.is_empty() else str(unit_sections.get(unit, "\n"))


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
## file had it; any other such part the text has not got in its own step and
## sub-model ([method in_own_steps]) placed where it was, in the model's own
## section; and every section of the file those name. [param waiting] are
## parts still on their way, in the file's coordinates. [param place] says
## where a place the file has stands now, in them (ModelStore.held_place:
## where the drives kept since moved the model), as the file has it when
## not given.
func carried_into(text: String, waiting: Array, place: Callable = Callable()) -> String:
	var parts: Array = _to_carry(waiting)
	if parts.is_empty():
		return text
	var carried: Array = _carried(parts, place)
	var refs: PackedStringArray = carried[0]
	var needed: Dictionary = carried[1]
	var out: String = _as_sections(text)
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


## Of [param parts], what the app cannot show and what is on its way (as
## [member not_shown] holds them, in the file's coordinates), those a model
## written whole writes with the parts it shows, each in its own step and its
## own sub-model as the file has it (ModelStore._text_into): all but one of a
## sub-model nothing of which is shown, which goes as the file has it, and
## one whose line names a section of the file or anything but the part
## ([method carried_into]). Up to 2026-11-11 every one was carried, at the
## end of the model's own section, out of its step and its sub-model
## (hscheck Sa), where an open of the file had it in both.
func in_own_steps(parts: Array) -> Array:
	var shown: Dictionary = _shown_sections()
	return parts.filter(func(placement: LdrModel.Placement) -> bool:
		return _in_own_step(placement, shown))


## [method in_own_steps] for one, [param shown] the sections the model
## shows a part of ([method _shown_sections]).
func _in_own_step(placement: LdrModel.Placement, shown: Dictionary) -> bool:
	if not _outermost_unshown(placement.unit, shown).is_empty():
		return false
	var reference: String = _reference_of(placement)
	return not sections.has(LdrModel._key(reference)) \
		and reference.to_lower() == (placement.part_id + ".dat").to_lower()


## What of [member not_shown] and [param waiting] [method carried_into]
## carries: those a model written whole has not got ([method in_own_steps]).
func _to_carry(waiting: Array) -> Array:
	var shown: Dictionary = _shown_sections()
	return (not_shown + waiting).filter(func(placement: LdrModel.Placement) -> bool:
		return not _in_own_step(placement, shown))


## The sections a part of which the model shows: each that a line of a part
## on the baseplate is in.
func _shown_sections() -> Dictionary:
	var out: Dictionary = {}
	for line: int in by_line:
		out[_section_at(line)] = true
	return out


## The name the file's line places [param placement] by, or its part's.
func _reference_of(placement: LdrModel.Placement) -> String:
	if placement.line >= 0 and placement.line < lines.size():
		var words: PackedStringArray = LdrModel._fields(lines[placement.line].strip_edges())
		if words.size() >= 15:
			return " ".join(words.slice(14))
	return placement.part_id + ".dat"


## What [method carried_into] puts in for [param parts]: [the lines placing
## them, in the model's section, and each section of the file those name and
## what those draw on, key -> true].
func _carried(parts: Array, place: Callable = Callable()) -> Array:
	var shown_sections: Dictionary = _shown_sections()
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
			var frame: Transform3D = unit_frames[unit]
			refs.append("1 %s %s %s" % [_colour_token(int(unit_colours.get(unit, 16))),
				LdrModel._line_numbers(place.call(frame) if place.is_valid() else frame),
				_file_name(section)])
			continue
		var reference: String = _reference_of(placement)
		if sections.has(LdrModel._key(reference)):
			needed[LdrModel._key(reference)] = true
		refs.append("1 %s %s %s" % [_colour_token(placement.color_code),
			LdrModel._line_numbers(place.call(placement.transform) if place.is_valid()
				else placement.transform), reference])
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
	return [refs, needed]


## [param text], the model written whole, as a file of sections, the model's
## first: one with no FILE line (LdrModel.write_ldr's, of a model with no
## sub-model) is put in one, named as none of the file's other sections is,
## so a section carried after it is not read as the model (LdrModel.parse
## takes the first FILE as the model). Written bare, with a block nothing
## places after it, the model reopened as that block, its own parts gone
## (sfreview F1).
func _as_sections(text: String) -> String:
	if LdrModel.section_word(text.get_slice("\n", 0)) == "FILE":
		return text
	var name: String = (own_title if not own_title.is_empty() else "model").to_snake_case()
	while sections.has(LdrModel._key(name)) and LdrModel._key(name) != main_key:
		name += "_"
	# Its "0 Name:" the name its FILE line gives it, as LDraw has them: up to
	# metalines one named apart from a section of the file's kept the
	# section's name there (sf2check, named_like.mpd).
	var head: int = text.find("\n\n")
	var named: int = text.find("\n0 Name: ")
	if named >= 0 and (head < 0 or named < head):
		var end: int = text.find("\n", named + 1)
		text = text.substr(0, named + 1) + "0 Name: %s.ldr" % name \
			+ (text.substr(end) if end >= 0 else "")
	return "0 FILE %s.ldr\n%s%s0 NOFILE\n" % [name, text, "" if text.ends_with("\n") else "\n"]


## The keys of the sections a model written whole carries as the file has
## them ([method carried_into], [method unplaced_into]), for [param waiting]
## and [param origins] as those take them: no sub-model the model places is
## written under one of their names (LdrModel.write_tree), or the one the
## file has is taken for it and not written. A placed sub-model titled as
## one placed by nothing took its file name, and that one's parts were lost
## (sfreview F5).
func kept_keys(waiting: Array, origins: Array) -> Dictionary:
	var out: Dictionary = {}
	var parts: Array = _to_carry(waiting)
	if not parts.is_empty():
		out.merge(_carried(parts)[1])
	for key: String in _unplaced(origins):
		out[key] = true
	return out


## [param text], the model written whole, with each section of the file
## nothing in the model is read through carried as the file has it: a
## sub-model it never placed, and one whose every copy was taken off.
## [param origins] are the places in the file of the parts the model holds
## and of those on their way (LdrModel.Placement.origin); the parts the app
## cannot show are this source's. Each goes after the text's own sections,
## in the file's order, with each section of the file it names that the
## text has not got by that name: a sub-model the model still has, too, as
## the file has it (the text's is named and framed anew), and one titled as
## a sub-model the model places renames none of its copies at the next open
## (LdrModel._assembly_names). Written whole, only what the model places was
## written, and a sub-model placed by nothing, the author's work, was lost
## on the save (kt5check F5), as Studio and LDCad keep one.
func unplaced_into(text: String, origins: Array) -> String:
	var keys: Array = _unplaced(origins)
	if keys.is_empty():
		return text
	text = _as_sections(text)
	# The text's own sections: the model's, named anew (LdrModel.write_tree),
	# and the parts it embeds, named as the file has them.
	var written: Dictionary = {}
	for line: String in text.split("\n"):
		if LdrModel.section_word(line) == "FILE":
			written[LdrModel._key(" ".join(_words(line).slice(2)))] = true
	var out: String = text if text.ends_with("\n") else text + "\n"
	var carried: Dictionary = {}
	while not keys.is_empty():
		keys.sort_custom(func(a: String, b: String) -> bool:
			return int((sections[a] as Array)[0]) < int((sections[b] as Array)[0]))
		var more: Array = []
		for key: String in keys:
			# Written already: a part the model's own text embeds.
			if carried.has(key) or written.has(key):
				continue
			carried[key] = true
			var span: Array = sections[key]
			var block := PackedStringArray()
			for n: int in range(int(span[0]), int(span[1])):
				var line: String = original[n].trim_suffix("\r")
				var words: PackedStringArray = _words(line)
				var named: String = LdrModel._key(" ".join(words.slice(14))) \
					if words.size() >= 15 and words[0] == "1" else ""
				# And what it places as the file has it, a sub-model the model
				# still has too: the model's own is written in a frame of its
				# own, under a name of its own (LdrModel.write_tree).
				if sections.has(named) and not written.has(named) and not carried.has(named):
					more.append(named)
				block.append(line)
			var as_had: String = "\n".join(block).strip_edges()
			out += as_had + ("\n" if as_had.to_upper().ends_with("0 NOFILE") else "\n0 NOFILE\n")
		keys = more
	return out


## The keys of the file's sections nothing in the model is read through, for
## [param origins] as [method unplaced_into] takes them.
func _unplaced(origins: Array) -> Array:
	var used: Dictionary = {main_key: true}
	for origin: Variant in origins + unshown_origins.keys():
		for at: String in str(origin).split("/", false):
			var n: int = at.to_int()
			if n < 0 or n >= original.size():
				continue
			used[_sec[n]] = true
			# And what the line names: a part the file carries as a section.
			var words: PackedStringArray = _words(original[n])
			if words.size() >= 15 and words[0] == "1":
				used[LdrModel._key(" ".join(words.slice(14)))] = true
	return sections.keys().filter(func(key: String) -> bool:
		return not used.has(key))


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
		# Its words read as LDraw reads them, any spaces and tabs between
		# (metalines: "0\tAuthor:" was not the author).
		var words: PackedStringArray = LdrModel._fields(line)
		if words.is_empty() or words[0] == "1" or _is_step(line):
			if not words.is_empty():
				break
			continue
		if words.size() < 2 or words[0] != "0":
			continue
		# And LDCad's groups, which the parts written whole are not in but
		# the file named: up to metalines the definitions went (sf2check).
		if words[1] == "!LDCAD" and words.size() > 2 and words[2] == "GROUP_DEF":
			out.append(line)
			continue
		for kept: String in ["Author:", "!LICENSE", "!LDRAW_ORG", "!HISTORY",
				"!THEME", "!CATEGORY", "!KEYWORDS", "!HELP"]:
			if words[1].begins_with(kept):
				out.append(line if words[1] != "Author:" else "0 Author: " + " ".join(words.slice(2)))
				break
	return out


## The file again, with the parts on the baseplate written into it: see the
## class. [param bricks] are the model's parts (BrickWorld.Brick, the floor
## left out), [param lift] how far the model was moved to stand on the
## ground, [param waiting] the lines whose parts are still on their way
## ("line|unit") -> the step each is in now, [param held_at] the step each
## part the app cannot show is in now, by origin ([method held_steps]). Null when
## the change cannot be written into the file as it is.
func write(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		unit_steps_now: Dictionary, held_at: Dictionary = {}) -> Variant:
	# A copy the file never placed, or steps given to a model that had none.
	# A copy put in another step is written with the rest of the steps of
	# the sub-model that places it (_restep).
	var restepped: Dictionary = {}      ## section key -> true
	for unit: String in unit_steps_now:
		# A copy built in its parent's steps is written in that one's
		# (LdrModel.IN_META), which only the whole file can say.
		if not unit_steps.has(unit) or int(unit_steps_now[unit]) == AuthorSteps.IN_PARENT:
			return null
		if int(unit_steps[unit]) != int(unit_steps_now[unit]):
			if not unit_lines.has(unit):
				return null
			restepped[_section_of(Assemblies.parent_of(unit))] = true
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

	# A section whose parts' steps changed is written again a step at a time:
	# those the model holds and does not show too, whose steps a step edit
	# numbers with the rest.
	for line: int in by_line:
		for origin: Read in by_line[line]:
			if paired.has(origin) and (paired[origin][0] as BrickWorld.Brick).step != origin.step:
				restepped[_section_of(origin.unit)] = true
	var steps_held: Dictionary = held_steps(waiting, held_at)
	for line: int in steps_held:
		if line < _sec.size() and int(steps_held[line]) != _step_at[line]:
			restepped[_sec[line]] = true

	# Each line: as it was, rewritten, or taken out.
	var replace: Dictionary = {}    ## line -> its new text, or "" to take it out
	var moved_into: Dictionary = {}     ## a section a part of it went to another step of
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
					or not _same(origin.at, now[1]) \
					or brick.step != origin.step and not restepped.has(_section_of(origin.unit)):
				changed = true
		if removed == live.size() and live.size() == origins.size():
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
		var brick: BrickWorld.Brick = (paired[first] as Array)[0]
		if brick.step != first.step and not restepped.has(_section_of(first.unit)):
			# Into another step of its section: out of here, in there.
			replace[line] = ""
			var to: Variant = _step_end(_section_of(first.unit), brick.step)
			if to == null:
				return null
			_insert(inserts, to, _step_lines(_section_of(first.unit), brick.step) + [written])
			moved_into[_section_of(first.unit)] = true
		else:
			replace[line] = written

	# Parts added: at the end of their step, in their copy's sub-model.
	var added: Dictionary = {}      ## restepped section -> [[step, line]]
	for entry: Array in left:
		var brick: BrickWorld.Brick = entry[0]
		var at: Transform3D = entry[1]
		var section: String = _section_of(brick.unit)
		if not sections.has(section) or int(copies.get(section, 1)) > 1:
			return null
		# A skin built from this file is no file of its own here: written
		# whole, it is carried.
		if CustomParts.is_skin(brick.part_id) and not sections.has(brick.part_id):
			return null
		if not brick.unit.is_empty() and brick.group != Assemblies.group_of(brick.unit):
			return null
		if brick.unit.is_empty() and not brick.group.is_empty():
			return null
		var frame: Transform3D = unit_frames.get(brick.unit, Transform3D.IDENTITY)
		if frame.basis.determinant() < 0.0:
			return null
		var local: Transform3D = frame.affine_inverse() * at
		var said: String = "1 %s %s %s.dat" % [_colour_token(brick.color_code),
			LdrModel._line_numbers(local), brick.part_id]
		if restepped.has(section):
			if not added.has(section):
				added[section] = []
			(added[section] as Array).append([brick.step, said])
			continue
		var to: Variant = _step_end(section, brick.step)
		if to == null:
			return null
		_insert(inserts, to, _step_lines(section, brick.step) + [said])

	_unplace_emptied(replace, left, moved_into)

	var eol_now: String = "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""
	for section: String in restepped:
		if not _restep(section, replace, inserts, added.get(section, []), paired,
				unit_steps_now, eol_now, steps_held):
			return null

	# A line written here ends as the file's lines do (Studio's in "\r\n").
	var eol: String = "\r" if not lines.is_empty() and lines[0].ends_with("\r") else ""
	var out := PackedStringArray()
	var tail: int = -1      ## where the file's last line went
	for n: int in lines.size():
		for extra: String in inserts.get(n, []):
			out.append(extra + eol)
		if n == lines.size() - 1 and not (replace.has(n) and str(replace[n]).is_empty()):
			tail = out.size()
		if replace.has(n):
			if not str(replace[n]).is_empty():
				out.append(str(replace[n]) + eol)
			continue
		out.append(lines[n])
	for extra: String in inserts.get(lines.size(), []):
		out.append(extra + eol)
	return "\n".join(_ended_as_begun(out, tail, lines, eol))


## The step each part the model holds and does not show is in now, by its
## line ([method patch], [method write]): [param held] is each part the app
## cannot show, by origin -> its step (ModelStore reads them as the model
## stands, BrickWorld.held), else its placement's own; [param waiting] each
## on its way, by origin or by "line|unit" -> its step (true for one not
## said). -2 for a line whose copies are in different steps. None for a file
## whose steps are not its author's, which has no steps to keep.
func held_steps(waiting: Dictionary, held: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if not authored:
		return out
	for origin: String in unshown_origins:
		_held_line(out, origin.get_slice("/", origin.get_slice_count("/") - 1).to_int(),
			int(held.get(origin, (unshown_origins[origin] as LdrModel.Placement).step)))
	for key: Variant in waiting:
		if waiting[key] is int and not str(key).is_empty():
			var said: String = str(key)
			_held_line(out, said.get_slice("|", 0).to_int() if said.contains("|")
				else said.get_slice("/", said.get_slice_count("/") - 1).to_int(), int(waiting[key]))
	return out


static func _held_line(out: Dictionary, line: int, step: int) -> void:
	if line < 0 or step < 0:
		return
	out[line] = step if int(out.get(line, step)) == step else -2


## A section whose steps changed, written again a step at a time: each
## line in the step its part, or the copy of a sub-model it places, is in
## now, and the notes between them with the step most of theirs went to;
## each step ended by the line that ended the last of the file's steps
## that went into it, so a merge takes one STEP line out, a split puts one
## in, a reorder moves whole steps with their ROTSTEP, and every line
## nobody changed is the file's, byte for byte. A part the model holds and
## does not show is in the step [param steps_held] says, by its line
## ([method held_steps]): put with the step before it, a step of only such a
## part went into that one, and its zoom and name with it (heldsteps). False
## when a line's copies are now in different steps: one line cannot be in two.
func _restep(section: String, replace: Dictionary, inserts: Dictionary, added: Array,
		paired: Dictionary, unit_steps_now: Dictionary, eol: String,
		steps_held: Dictionary = {}) -> bool:
	if not sections.has(section):
		return false
	var span: Array = sections[section]
	var start: int = int(span[0])
	var stop: int = int(span[1])
	var head_end: int = start
	while head_end < stop:
		var words: PackedStringArray = LdrModel._fields(lines[head_end].strip_edges())
		if not words.is_empty() and words[0] == "1" or _is_step(lines[head_end]):
			break
		head_end += 1
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
	# The steps as the file had them, and the line ending each.
	var blocks: Array = [[]]
	var ends: Array = [-1]
	for n: int in range(head_end, tail):
		if _is_step(lines[n]):
			ends[ends.size() - 1] = n
			blocks.append([])
			ends.append(-1)
		else:
			(blocks[blocks.size() - 1] as Array).append(n)
	if blocks.size() > 1 and (blocks[blocks.size() - 1] as Array).is_empty():
		blocks.pop_back()
		ends.pop_back()
	# Where each part and copy is now.
	var line_step: Dictionary = {}
	var latest: int = 0
	for block: Array in blocks:
		for n: int in block:
			var now: int = -2
			for origin: Read in by_line.get(n, []):
				if not paired.has(origin):
					continue
				var step: int = (paired[origin][0] as BrickWorld.Brick).step
				if now != -2 and now != step:
					return false
				now = step
			for unit: String in placing.get(n, []):
				var step: int = int(unit_steps_now.get(unit, unit_steps.get(unit, -1)))
				if now != -2 and now != step:
					return false
				now = step
			if steps_held.has(n):
				var kept_in: int = int(steps_held[n])
				if kept_in == -2 or now != -2 and now != kept_in:
					return false
				now = kept_in
			if now >= 0:
				line_step[n] = now
				latest = maxi(latest, now)
	for entry: Array in added:
		latest = maxi(latest, int(entry[0]))
	for n: int in line_step:
		if int(line_step[n]) < 0:
			line_step[n] = latest
	# The rest of each step's lines go with most of its parts.
	var block_step: Array = []
	var before: int = 0
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
		if best < 0:
			best = before
		block_step.append(best)
		before = best
	var into: Dictionary = {}       ## step -> [[order, text]]
	var ending: Dictionary = {}     ## step -> the line ending it, or "" for none
	for k: int in blocks.size():
		for n: int in blocks[k]:
			var text: String = lines[n].trim_suffix("\r")
			if replace.has(n):
				text = str(replace[n])
				if text.is_empty():
					continue
			var step: int = int(line_step.get(n, block_step[k]))
			if not into.has(step):
				into[step] = []
			(into[step] as Array).append([float(n), text])
		# A step with nothing in it is taken out with the line that ended
		# it: the steps are numbered as the model has them now, and what an
		# empty step's ROTSTEP turned goes with the step it turned
		# (BookletLooks.follow).
		var any: bool = false
		for n: int in blocks[k]:
			if line_step.has(n):
				any = true
				break
		if not any:
			continue
		ending[block_step[k]] = lines[int(ends[k])].trim_suffix("\r") if int(ends[k]) >= 0 else ""
	for entry: Array in added:
		var step: int = int(entry[0]) if int(entry[0]) >= 0 else latest
		if not into.has(step):
			into[step] = []
		(into[step] as Array).append([float(tail) + 0.5, str(entry[1])])
	var order: Dictionary = {}
	for step: int in into:
		order[step] = true
	for step: int in ending:
		if into.has(step) or not str(ending[step]).is_empty():
			order[step] = true
	var steps: Array = order.keys()
	steps.sort()
	var out := PackedStringArray()
	for index: int in steps.size():
		var step: int = steps[index]
		var made: Array = into.get(step, [])
		made.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for item: Array in made:
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


## A sub-model whose every part was taken out, its every copy taken off, is
## placed by nothing: each line placing it goes, from every section still
## in use, and its block stays as the file has it, its parts' lines with
## it, as the patch keeps it ([method _left_unplaced]) and as Studio and
## LDCad keep one. Its block went with them, and the last copy taken off
## lost the author's sub-model on the save (kt5check F5). Placed still, with
## its parts' lines gone, the saved file kept an empty sub-model where the
## assembly had been, which another program's list shows (2026-10-16). A
## sub-model is in use while anything stays in it: a part not taken out, one
## the app cannot show, a part added here ([param left]) or moved to another
## of its steps ([param moved_into]), a sub-model of its own still in use, or
## an LDCad flexible part's skin.
func _unplace_emptied(replace: Dictionary, left: Array, moved_into: Dictionary) -> void:
	var kept: Dictionary = moved_into.duplicate()
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
		for n: int in range(int(span[0]), int(span[1])):
			if emptied.has(key):
				replace.erase(n)
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


## The lines [param plan]'s parts with no line take, each where it is in
## its copy ([param frames]): key -> [section, text, step, [bricks]], or
## {"": why} when one cannot be written. With [param placing], a part in
## the colour its copy hands its parts of 16 ([member unit_colours]) is
## written in 16.
func _fresh_lines(plan: Plan, frames: Dictionary, dead_copies: Dictionary,
		library: PartLibrary, placing: bool) -> Dictionary:
	var groups: Dictionary = {}
	for entry: Array in plan.fresh:
		var brick: BrickWorld.Brick = entry[0]
		if not brick.unit.is_empty() and not unit_sections.has(brick.unit):
			return {"": "a new part is in a copy the file never placed"}
		if dead_copies.has(brick.unit):
			return {"": "a new part is in a copy taken off"}
		if not brick.unit.is_empty() and brick.group != Assemblies.group_of(brick.unit):
			return {"": "a new part's group is not its copy's"}
		if brick.unit.is_empty() and not brick.group.is_empty():
			return {"": "a new part is in a group of no copy"}
		if not authored and brick.step >= 0:
			return {"": "steps were given to a file that has none"}
		var frame: Transform3D = frames.get(brick.unit, Transform3D.IDENTITY)
		if frame.basis.determinant() < 0.0:
			return {"": "a new part in a mirrored copy"}
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if library != null else null
		if CustomParts.is_skin(brick.part_id) or info != null and info.custom \
				and not sections.has(brick.part_id):
			return {"": "a new part made here the file does not carry"}
		var section: String = _section_of(brick.unit)
		var local: Transform3D = frame.affine_inverse() * (entry[1] as Transform3D)
		var colour: String = "16" if placing and not brick.unit.is_empty() \
			and unit_colours.has(brick.unit) and int(unit_colours[brick.unit]) == brick.color_code \
			else _colour_token(brick.color_code)
		var text: String = "1 %s %s %s.dat" % [colour, _numbers_for(PackedStringArray(), local),
			brick.part_id]
		var key: String = "%s|%d|%s" % [section, brick.step, text]
		if not groups.has(key):
			groups[key] = [section, text, brick.step, []]
		(groups[key][3] as Array).append(brick)
	return groups


## Whether each of [param groups] ([method _fresh_lines]) is one part in
## every copy of its sub-model still placed, [param dead_copies] aside.
func _one_each(groups: Dictionary, dead_copies: Dictionary) -> bool:
	for key: String in groups:
		var section: String = groups[key][0]
		var copies_now: int = 1 if section == main_key else 0
		for path: String in unit_sections:
			if str(unit_sections[path]) == section and not dead_copies.has(path):
				copies_now += 1
		if (groups[key][3] as Array).size() != copies_now:
			return false
	return true


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
	# Any run of spaces and tabs between the words, as LDraw reads them.
	var words: PackedStringArray = LdrModel._fields(line.strip_edges())
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


# -- the patch: (A) -----------------------------------------------------------
#
# A save of a model opened from someone else's file is exactly one of two
# things (keeptext5):
#
# (A) A patch ([method patch]): the file as it was, and line operations each
#     bound to a part that was edited, nothing else:
#     1. a part's own line rewritten: its colour, its place and turn, or its
#        part, the file's own number kept while it is still the part; a copy
#        of a sub-model moved whole, the one line placing it;
#     2. a part's line taken out, with the lines bound to it above it
#        ([method _binds_next]), a pair of another program's it leaves empty,
#        and a sub-model no line places any more;
#     3. a new part's line at the end of its step, inside no pair;
#     4. a part's line moved to the end of another step, only where the pairs
#        round it are the same at both places.
#     Every other line stays byte for byte, in its order.
# (B) What live writes: [method write], or, where that gives null, the model
#     written whole (ModelStore).
#
# What the four cannot say is (B), and so is a patch the gate ([method gate])
# does not pass. Nothing is ever refused: a save always writes. keeptext4
# wrote every edit into the file and refused what did not read back, which
# trapped the work and then lost it (kt4review).

## The file as it was opened, which no writer touches: what [method gate]
## holds a written text to. [member lines] is the writers' copy.
var original: PackedStringArray = PackedStringArray()
## Each part read from the file, by its place there (Read.origin) -> its [Read].
var by_origin: Dictionary = {}
## The parts the app cannot show, by origin -> their Placement: on their
## lines, as the file had them.
var unshown_origins: Dictionary = {}
## Each copy's place in the file as it opened (LdrModel.unit_chains).
var unit_chains: Dictionary = {}

const KEEP := 0
const REWRITE := 1
const MOVE := 2
const NEW := 3
## A line of a text the gate is given that is none of the patch's.
const FOREIGN := 4
## A section key no section has: the lines before an MPD's first FILE line.
const NOWHERE := "\n"

## What a patch is: the lines written, and for each where it came from.
class Plan extends RefCounted:
	## Why the edit is not a patch: "" when it is.
	var why: String = ""
	var out := PackedStringArray()
	## Each line of [member out]: the file's line it is (-1 for a new one) and how.
	var from := PackedInt32Array()
	var how := PackedByteArray()
	## A new line of [member out] -> the bricks it places, one per copy.
	var new_bricks: Dictionary = {}
	## The parts by origin -> [brick, its place in the file's coordinates].
	var now: Dictionary = {}
	## The parts with no line: [[brick, its place]].
	var fresh: Array = []
	## The file's lines taken out, and those rewritten or moved.
	var gone: Dictionary = {}
	var changed: Dictionary = {}


# The file read for patching once, as it is made ([method make]), before
# any save can read it: each line's section, step and the pairs round it,
# as LdrModel.parse reads them. Read on first use, the autosave's worker
# and a save on the main thread could both find it unread, one patching
# from tables the other was still filling (kt5review #6, kt5r_race).
var _why_never: String = ""
var _sec := PackedStringArray()
var _step_at := PackedInt32Array()
var _bound_from := PackedInt32Array()
## Section -> the lines ending its steps, in order.
var _ends: Dictionary = {}
## Section -> where a line put at its end goes.
var _tail: Dictionary = {}
## [begin, end, kind] of every pair; end the section's end when never closed.
var _pairs: Array = []
## A placing line -> the begin lines of the pairs round it.
var _stack_at: Dictionary = {}
## The file's lines are CRLF.
var _crlf: bool = false


func _read_for_patch() -> void:
	var count: int = original.size()
	_crlf = count > 0 and original[0].ends_with("\r")
	_sec.resize(count)
	_step_at.resize(count)
	_bound_from.resize(count)
	var any_file: bool = false
	for n: int in count:
		if _keyword(original[n]) == "FILE":
			any_file = true
			break
	var current: String = NOWHERE if any_file else main_key
	var step: int = 0
	var open: Dictionary = {}       ## kind -> [begin lines]
	var open_all: Array = []
	var seen_files: Dictionary = {}
	for n: int in count:
		var raw: String = original[n]
		var keyword: String = _keyword(raw)
		if keyword == "FILE":
			_close_open(open, n)
			open_all.clear()
			current = LdrModel._key(" ".join(_words(raw).slice(2)))
			if seen_files.has(current):
				_why_never = "two FILE sections of one name"
			seen_files[current] = true
			step = 0
		if not _ends.has(current):
			_ends[current] = []
		_sec[n] = current
		_step_at[n] = step
		_bound_from[n] = n
		if keyword == "STEP" or keyword == "ROTSTEP":
			(_ends[current] as Array).append(n)
			step += 1
			continue
		var pair: Array = _pair_of(raw)
		if not pair.is_empty():
			var kind: String = pair[0]
			if int(pair[1]) > 0:
				if not open.has(kind):
					open[kind] = []
				(open[kind] as Array).append(n)
				open_all.append(n)
			elif open.has(kind) and not (open[kind] as Array).is_empty():
				var begin: int = (open[kind] as Array).pop_back()
				_pairs.append([begin, n, kind])
				open_all.erase(begin)
			continue
		if not _is_placing(raw):
			continue
		var k: int = n
		while k > 0 and _sec[k - 1] == current and _binds_next(original[k - 1]):
			k -= 1
		_bound_from[n] = k
		var stack: Array = open_all.duplicate()
		stack.sort()
		_stack_at[n] = stack
	_close_open(open, count)
	for key: String in sections:
		var span: Array = sections[key]
		var end: int = int(span[1])
		while end > int(span[0]) + 1 and original[end - 1].strip_edges().is_empty():
			end -= 1
		_tail[key] = end


func _close_open(open: Dictionary, at: int) -> void:
	for kind: String in open:
		for begin: int in open[kind]:
			_pairs.append([begin, at, kind])
	open.clear()


## The begin lines of the pairs a line put in [param section] before line
## [param at] is in.
func _stack_before(section: String, at: int) -> Array:
	var out: Array = []
	for pair: Array in _pairs:
		if int(pair[0]) < at and at <= int(pair[1]) and _sec[int(pair[0])] == section:
			out.append(int(pair[0]))
	out.sort()
	return out


## Where a part of step [param step] goes at its end in [param section]:
## before the line ending that step, or at the section's end for its last
## step and for none (-1); -1 when the section has no such step.
func _end_of_step(section: String, step: int) -> int:
	var ends: Array = _ends.get(section, [])
	if step < 0 or step == ends.size():
		return int(_tail.get(section, -1))
	if step > ends.size():
		return -1
	return int(ends[step])


## The sub-model a copy of which was taken off ([param dead]) while a copy
## of it numbered after that one stays, or "". An open numbers a sub-model's
## copies in the file's order, so the one left opens again numbered one
## less: Wing#2 as Wing#1, with the app's lines that name it by its path
## (a motion's JOINT ASSEMBLY, a copy's step) naming another. Live's write
## (B) writes them for the copies as they are (kt5review #5: 8156-1,
## 8028-1, 5540-1's delcopy, nest_del_copy_comment).
func _renumbered(dead: Dictionary) -> String:
	var first_dead: Dictionary = {}     ## a sub-model -> the lowest number of a copy of it taken off
	for path: String in dead:
		var segment: String = Assemblies.leaf(path)
		var kind: String = Assemblies.definition(segment)
		var number: int = Assemblies.copy_of(segment)
		first_dead[kind] = mini(int(first_dead.get(kind, number)), number)
	if first_dead.is_empty():
		return ""
	for path: String in unit_sections:
		if dead.has(path):
			continue
		var segment: String = Assemblies.leaf(path)
		var kind: String = Assemblies.definition(segment)
		if first_dead.has(kind) and Assemblies.copy_of(segment) > int(first_dead[kind]):
			return kind
	return ""


## Why a patch taking out the lines [param gone] is not to be one; "": no
## part left at all with no new one ([param fresh] of them) in, which live's
## write writes (kt5review #4: single_delete_all). A sub-model no line
## places any more is no reason: its block stays, placed by nothing, as the
## file's author made it and as Studio and LDCad keep one, and only the
## lines placing it go. Sent to live's write, which dropped the block, the
## last copy taken off lost the sub-model on the save (kt5check F5:
## fidelity_probe's sub-model emptied, 30572-1, 8644-1, 8121-1, 4309-1,
## 4348-1's delcopy).
func _left_unplaced(gone: Dictionary, fresh: int) -> String:
	var before: Dictionary = _placed_from_main({})
	var after: Dictionary = _placed_from_main(gone)
	if fresh == 0 and int(after.get(main_key, 0)) == 0 and int(before.get(main_key, 0)) > 0:
		return "no part is left in the model"
	return ""


## Each section the main model's lines place, but for those of [param
## gone], through its sub-models -> how many parts' lines, from the main
## model down, are under it (the main model's key for them all).
func _placed_from_main(gone: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not sections.has(main_key):
		return out
	var parts: int = 0
	var todo: Array = [main_key]
	var seen: Dictionary = {main_key: true}
	while not todo.is_empty():
		var key: String = todo.pop_back()
		var span: Array = sections[key]
		var start: int = int(span[0])
		if start < original.size() and _keyword(original[start]) == "FILE":
			start += 1
		for n: int in range(start, int(span[1])):
			if gone.has(n):
				continue
			var words: PackedStringArray = _words(original[n])
			if words.size() < 15 or words[0] != "1":
				continue
			var named: String = LdrModel._key(" ".join(words.slice(14)))
			if not sections.has(named):
				parts += 1
			elif not seen.has(named):
				seen[named] = true
				todo.append(named)
	for key: String in seen:
		out[key] = 0
	out[main_key] = parts
	return out


## The patch of the file for the model as [param bricks] stand (see the
## class, (A)), or a [Plan] that says why there is none ([member Plan.why]).
## [param waiting] are the origins of parts still on their way, as they
## were, each -> the step it is in now; [param steps_now] each copy's step
## (BrickWorld.unit_steps); [param held_at] the step each part the app
## cannot show is in now, by origin ([method held_steps]). Reads only what it is
## given and this source: on any thread.
func patch(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		steps_now: Dictionary, held_at: Dictionary = {}) -> Plan:
	var plan := Plan.new()
	if not _why_never.is_empty():
		return _no(plan, _why_never)
	var back := Transform3D(Basis.IDENTITY, -lift)
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var at: Transform3D = back * brick.transform
		if brick.origin.is_empty():
			plan.fresh.append([brick, at])
			continue
		var read: Read = by_origin.get(brick.origin)
		if read == null:
			return _no(plan, "a part is on a line the file has not got (%s)" % brick.origin)
		if plan.now.has(brick.origin):
			return _no(plan, "two parts are on one line (%s)" % brick.origin)
		if brick.unit != read.unit or brick.group != read.group:
			return _no(plan, "a part is in another copy than the file's (%s)" % brick.origin)
		if not authored and brick.step >= 0:
			return _no(plan, "steps were given to a file that has none")
		plan.now[brick.origin] = [brick, at]
	for unit: String in steps_now:
		if int(steps_now[unit]) == AuthorSteps.IN_PARENT:
			return _no(plan, "a copy is built in its parent's steps")
		if not unit_steps.has(unit) or not unit_lines.has(unit):
			return _no(plan, "a copy the file never placed")

	# The copies, outermost first: each where it stands now, a copy whose
	# every part moved alike moved whole on its own line, and one whose
	# every part was taken off taken off on it.
	var frames: Dictionary = {"": Transform3D.IDENTITY}
	var dead_copies: Dictionary = {}
	var under: Dictionary = {}      ## path -> origins of the parts under it
	var waits_under: Dictionary = {}
	var hidden_under: Dictionary = {}
	for origin: String in by_origin:
		var read: Read = by_origin[origin]
		var path: String = read.unit
		while not path.is_empty():
			_add_to(under, path, origin)
			if waiting.has(origin):
				waits_under[path] = true
			path = Assemblies.parent_of(path)
	for origin: String in unshown_origins:
		var path: String = (unshown_origins[origin] as LdrModel.Placement).unit
		while not path.is_empty():
			hidden_under[path] = true
			path = Assemblies.parent_of(path)
	var paths: Array = unit_sections.keys()
	paths.sort_custom(func(a: String, b: String) -> bool:
		return Assemblies.segments(a).size() < Assemblies.segments(b).size())
	var placing: Dictionary = {}    ## a copy's line -> [what each copy it places says: "dead" or its place now]
	for path: String in paths:
		var parent: String = Assemblies.parent_of(path)
		if not frames.has(parent):
			frames[parent] = unit_frames.get(parent, Transform3D.IDENTITY)
		if dead_copies.has(parent):
			dead_copies[path] = true
			frames[path] = unit_frames.get(path, Transform3D.IDENTITY)
			continue
		if not unit_lines.has(path) or not unit_frames.has(path):
			return _no(plan, "a copy with no line of its own")
		var was: Transform3D = unit_frames[path]
		var parent_was: Transform3D = unit_frames.get(parent, Transform3D.IDENTITY) \
			if not parent.is_empty() else Transform3D.IDENTITY
		var parent_now: Transform3D = frames[parent]
		var frame: Transform3D = parent_now * parent_was.affine_inverse() * was
		var origins: Array = under.get(path, [])
		var present: Array = origins.filter(func(o: String) -> bool: return plan.now.has(o))
		var line: int = int(unit_lines[path])
		if present.is_empty() and not origins.is_empty() and not waits_under.has(path):
			dead_copies[path] = true
			_add_to(placing, line, "dead")
			frames[path] = frame
			continue
		if not waits_under.has(path) and (present.size() >= 2 or not hidden_under.has(path)):
			var moved: Variant = _common_move(plan, present)
			if moved != null and not _same((moved as Transform3D) * was, frame):
				frame = (moved as Transform3D) * was
		frames[path] = frame
		_add_to(placing, line, parent_now.affine_inverse() * frame)
	var renumbered: String = _renumbered(dead_copies)
	if not renumbered.is_empty():
		return _no(plan, "a copy of %s taken off and a later one left, which opens again numbered one less" % renumbered)
	var rewrites: Dictionary = {}   ## line -> its text now
	var moves: Dictionary = {}      ## line -> the step it goes to
	var recolour: Dictionary = {}   ## a copy's line -> the colour a flexible part in it is now
	for line: int in placing:
		var says: Array = placing[line]
		var dead: int = says.count("dead")
		if dead == says.size():
			plan.gone[line] = true
			continue
		if dead > 0:
			return _no(plan, "a copy of a sub-model was taken off and another like it not")
		var local: Transform3D = says[0]
		for other: Variant in says:
			if not _same(other as Transform3D, local):
				return _no(plan, "copies placed by one line moved apart (line %d)" % (line + 1))
		var words: PackedStringArray = _words(lines[line])
		var numbers: Variant = _numbers_of(words)
		if numbers == null:
			return _no(plan, "a copy's line could not be read (line %d)" % (line + 1))
		if not _same(LdrModel.to_transform(numbers), local):
			if local.basis.determinant() < 0.0 or LdrModel.to_transform(numbers).basis.determinant() < 0.0:
				return _no(plan, "a mirrored copy moved")
			rewrites[line] = "1 %s %s %s" % [words[1], _numbers_for(words, local),
				_named_as_written(lines[line])]
	# A copy put in another step: its line moved to the end of that step.
	for path: String in steps_now:
		if int(steps_now[path]) == int(unit_steps.get(path, -1)) or dead_copies.has(path):
			continue
		var line: int = int(unit_lines[path])
		if moves.has(line) and int(moves[line]) != int(steps_now[path]):
			return _no(plan, "copies placed by one line went to two steps")
		moves[line] = int(steps_now[path])

	# Each part's line.
	for line: int in by_line:
		var reads: Array = (by_line[line] as Array).filter(func(r: Read) -> bool:
			return not dead_copies.has(r.unit) or r.unit.is_empty())
		if reads.is_empty():
			continue
		var taken: int = 0
		var waits: int = 0
		var said: Array = []        ## [part, colour, local, step]
		for read: Read in reads:
			if waiting.has(read.origin):
				waits += 1
				continue
			if not plan.now.has(read.origin):
				taken += 1
				continue
			var held: Array = plan.now[read.origin]
			var brick: BrickWorld.Brick = held[0]
			var local: Transform3D = (frames.get(read.unit, Transform3D.IDENTITY) as Transform3D) \
				.affine_inverse() * (held[1] as Transform3D)
			said.append([brick.part_id, brick.color_code, local, brick.step, read])
		if taken == reads.size():
			plan.gone[line] = true
			continue
		if taken > 0:
			return _no(plan, "a part was taken off one copy of a sub-model and not another (line %d)" % (line + 1))
		if said.is_empty():
			continue
		# A part of a mirrored copy is in its other hand (Assemblies.unmirror):
		# it agrees with the line only as it was opened.
		var mirrored: bool = false
		for item: Array in said:
			var was: Read = item[4]
			if not was.mirrored:
				continue
			mirrored = true
			var opened: Transform3D = (unit_frames.get(was.unit, Transform3D.IDENTITY) as Transform3D) \
				.affine_inverse() * was.at
			if str(item[0]) != was.part_id or int(item[1]) != was.colour \
					or authored and int(item[3]) != was.step or not _same(item[2] as Transform3D, opened):
				return _no(plan, "a part of a mirrored copy changed")
		said = said.filter(func(item: Array) -> bool: return not (item[4] as Read).mirrored)
		if said.is_empty():
			continue
		# Its copies alike: one part, place and step, and one colour where
		# any was painted (a colour of 16 is each copy's own until then).
		var first: Array = said[0]
		var painted: bool = false
		for other: Array in said:
			painted = painted or int(other[1]) != (other[4] as Read).colour
		for other: Array in said:
			if other[0] != first[0] or int(other[3]) != int(first[3]) \
					or not _same(other[2] as Transform3D, first[2] as Transform3D) \
					or painted and int(other[1]) != int(first[1]):
				return _no(plan, "copies of a sub-model no longer agree (line %d)" % (line + 1))
		var read: Read = first[4]
		var was_local: Transform3D = (unit_frames.get(read.unit, Transform3D.IDENTITY) as Transform3D) \
			.affine_inverse() * read.at if not read.unit.is_empty() else read.at
		var changed: bool = str(first[0]) != read.part_id or painted \
			or not _same(first[2] as Transform3D, was_local)
		var stepped: bool = authored and int(first[3]) != read.step
		if (changed or stepped) and waits > 0:
			return _no(plan, "a part still on its way is on a line that changed")
		if changed and not _is_placing(lines[line]):
			# A flexible part, on the line LDCad marks its path with: its
			# colour the line placing its path's sub-model says, the way
			# LDCad paints a path (its caps of colour 16 with it). Only
			# its colour changes so; the gate reads back that nothing
			# else did.
			if str(first[0]) != read.part_id or not _same(first[2] as Transform3D, was_local):
				return _no(plan, "a flexible part's place changed")
			var giving: int = _colour_line(read.origin)
			if giving < 0:
				return _no(plan, "a flexible part's colour no line of its says")
			if recolour.has(giving) and int(recolour[giving]) != int(first[1]):
				return _no(plan, "two flexible parts of one path painted apart")
			recolour[giving] = int(first[1])
			changed = false
		if (changed or stepped) and mirrored:
			return _no(plan, "a part of a mirrored copy changed")
		if changed:
			var text: Variant = _line_for(line, str(first[0]), int(first[1]), painted, first[2], library)
			if text == null:
				return _no(plan, "a part's line could not be written (line %d)" % (line + 1))
			rewrites[line] = text
		if stepped:
			if not _is_placing(lines[line]):
				return _no(plan, "a flexible part's step changed")
			moves[line] = int(first[3])

	for line: int in recolour:
		var text: String = str(rewrites[line]) if rewrites.has(line) else lines[line].trim_suffix("\r")
		rewrites[line] = _with_colour(text, _colour_token(int(recolour[line])))
	# What goes: the lines bound to each line taken out, a sub-model no line
	# places any more, and a pair left with nothing in it.
	_taken_with(plan.gone)
	for line: int in plan.gone:
		if rewrites.has(line) or moves.has(line):
			return _no(plan, "a line both taken out and kept")
	var unplaced: String = _left_unplaced(plan.gone, plan.fresh.size())
	if not unplaced.is_empty():
		return _no(plan, unplaced)
	# A part the app cannot show, or one still on its way, stays on its line:
	# one a step edit put in another step (AuthorSteps numbers its step with
	# the rest) is live's write, which moves its line (_restep). Up to
	# 2026-11-11 it had no step to follow, and where every other part of its
	# step went to one other step it was left behind alone (keeptext5).
	var steps_held: Dictionary = held_steps(waiting, held_at)
	for line: int in steps_held:
		if line < _sec.size() and int(steps_held[line]) != _step_at[line]:
			return _no(plan, "a part the app cannot show is in another step now (line %d)" % (line + 1))
	# A step of the file every part went out of, and none came into: the
	# steps numbered again (a merge, a step emptied), which moving lines
	# cannot say. Each later part moved up a step left the file's STEP lines
	# where no step ends: 106-1's merge took the car's first STEP out and put
	# one after its last part. Live's write takes the emptied step's line out.
	if not moves.is_empty():
		var kept: Dictionary = {}       ## "section|step" -> a part line is in it
		var left: Dictionary = {}       ## "section|step" -> a part line went out of it
		for line: int in _stack_at:
			if plan.gone.has(line):
				continue
			var key: String = "%s|%d" % [_sec[line], _step_at[line]]
			if moves.has(line):
				left[key] = true
				kept["%s|%d" % [_sec[line], int(moves[line])]] = true
			else:
				kept[key] = true
		for key: String in left:
			if not kept.has(key):
				return _no(plan, "a step's every part went to another step: the steps numbered again")

	# Where each moved line goes: the end of its step, the pairs round it the
	# same there.
	var inserts: Dictionary = {}    ## line -> [[text, how, from, bricks]]
	var away: Dictionary = {}
	var moved_lines: Array = moves.keys()
	moved_lines.sort()
	for line: int in moved_lines:
		var section: String = _sec[line]
		var to: int = _end_of_step(section, int(moves[line]))
		if to < 0:
			return _no(plan, "a part went to a step the file has not got")
		if _stack_before(section, to) != (_stack_at.get(line, []) as Array):
			return _no(plan, "a step edit would cross a pair (line %d)" % (line + 1))
		for k: int in range(_bound_from[line], line + 1):
			if k == to or (k < to and to <= line):
				return _no(plan, "a part moved within its own lines")
			away[k] = true
			var text: String = str(rewrites.get(k, "")) + _eol() if rewrites.has(k) else lines[k]
			_add_to(inserts, to, [text, MOVE, k, []])
	# The parts with no line: one line for one in every copy of its sub-model.
	# Each in its colour; or, where that takes a line for each copy, in 16
	# where it is in the colour its copy hands its parts of 16: a plate put
	# down red in the red post went down in the other post in that one's own,
	# the two said two lines, and the file was written afresh, every 16 of
	# the post written as the first post's colour (cf2check post16).
	var groups: Dictionary = _fresh_lines(plan, frames, dead_copies, library, false)
	if not groups.has("") and not _one_each(groups, dead_copies):
		var in_16: Dictionary = _fresh_lines(plan, frames, dead_copies, library, true)
		if _one_each(in_16, dead_copies):
			groups = in_16
	if groups.has(""):
		return _no(plan, str(groups[""]))
	if not _one_each(groups, dead_copies):
		return _no(plan, "a new part in one copy of a sub-model and not another")
	var keys: Array = groups.keys()
	keys.sort()
	for key: String in keys:
		var group: Array = groups[key]
		var section: String = group[0]
		var to: int = _end_of_step(section, int(group[2]))
		if to < 0:
			return _no(plan, "a new part is in a step the file has not got")
		if not _stack_before(section, to).is_empty():
			return _no(plan, "a new part's step ends inside a pair")
		_add_to(inserts, to, [str(group[1]) + _eol(), NEW, -1, group[3]])

	# The lines, in order.
	var count: int = lines.size()
	for n: int in count + 1:
		for put: Array in inserts.get(n, []):
			_emit(plan, str(put[0]), int(put[1]), int(put[2]), put[3])
		if n == count:
			break
		if plan.gone.has(n) or away.has(n):
			continue
		if rewrites.has(n):
			_emit(plan, str(rewrites[n]) + _eol(), REWRITE, n, [])
		else:
			_emit(plan, lines[n], KEEP, n, [])
	plan.out = _ended_as_begun(plan.out, plan.from.find(count - 1), lines, _eol())
	plan.changed = rewrites.duplicate()
	for line: int in moves:
		plan.changed[line] = true
	return plan


func _eol() -> String:
	return "\r" if _crlf else ""


## [param out], a writer's lines of the file [param file_lines], ending as
## the file did where it ended with no line break: the line [param tail]
## (where the file's last line went, kept, rewritten or moved; -1 for gone)
## ended as the rest ([param eol]) where a line follows it, and the last
## line written with no end. A rewrite of the last line was given the
## file's line end, and a CRLF file came back ending in a bare CR (kt5check
## F4); its last line taken out left the one before it so.
static func _ended_as_begun(out: PackedStringArray, tail: int, file_lines: PackedStringArray,
		eol: String) -> PackedStringArray:
	var count: int = file_lines.size()
	if count == 0 or out.is_empty() or file_lines[count - 1].is_empty() \
			or file_lines[count - 1].ends_with("\r"):
		return out
	var end: int = out.size() - 1
	if tail >= 0 and tail < end and not out[tail].ends_with("\r"):
		out[tail] = out[tail] + eol
	out[end] = out[end].trim_suffix("\r")
	return out


func _emit(plan: Plan, text: String, how: int, from: int, placed: Array) -> void:
	if how == NEW:
		plan.new_bricks[plan.out.size()] = placed
	plan.out.append(text)
	plan.from.append(from)
	plan.how.append(how)


static func _no(plan: Plan, why: String) -> Plan:
	plan.why = why
	return plan


## One move every part of [param origins] made alike, from where the file
## put it to where it is now, or null.
func _common_move(plan: Plan, origins: Array) -> Variant:
	var moved: Variant = null
	for origin: String in origins:
		var was: Transform3D = (by_origin[origin] as Read).at
		var at: Transform3D = (plan.now[origin] as Array)[1]
		if moved == null:
			moved = at * was.affine_inverse()
		elif not _same((moved as Transform3D) * was, at):
			return null
	return moved


## [param gone], lines of the file taken out, with what goes with them: the
## lines bound to each above it, and a pair left with nothing in it. A
## sub-model no line places any more stays, placed by nothing, as Ungroup,
## LDCad and Studio keep one (kt4review): no part of the model.
func _taken_with(gone: Dictionary) -> void:
	for line: int in gone.keys():
		for k: int in range(_bound_from[line], line):
			gone[k] = true
	var more: bool = true
	while more:
		more = false
		for pair: Array in _pairs:
			var begin: int = pair[0]
			var end: int = pair[1]
			if gone.has(begin) or end >= original.size() or gone.has(end) \
					or _pair_of(original[end]).is_empty():
				continue
			var any: bool = false
			var empty: bool = true
			for n: int in range(begin + 1, end):
				if gone.has(n):
					any = true
				elif not original[n].strip_edges().is_empty():
					empty = false
					break
			if any and empty:
				gone[begin] = true
				gone[end] = true
				more = true


## The twelve numbers of a placing line's fields, or null.
static func _numbers_of(words: PackedStringArray) -> Variant:
	if words.size() < 15 or words[0] != "1":
		return null
	var numbers := PackedFloat64Array()
	for n: int in range(2, 14):
		if not words[n].is_valid_float():
			return null
		numbers.append(words[n].to_float())
	return numbers


## Line [param line] rewritten for its part as it is now: [param part] in
## [param colour] at [param local] in its copy. The file's own number while
## it is still this part (a retired one placed where its stub puts the part
## it became), its colour as it said it unless [param painted], and its
## numbers as they were where they still say the place or the turn.
func _line_for(line: int, part: String, colour: int, painted: bool, local: Transform3D,
		library: PartLibrary) -> Variant:
	var words: PackedStringArray = _words(lines[line])
	if _numbers_of(words) == null:
		return null
	var reference: String = _named_as_written(lines[line])
	var said_id: String = LdrModel._key(" ".join(words.slice(14)))
	var token: String = part + ".dat"
	var by := Transform3D.IDENTITY
	if library != null:
		var named: String = ModelStore.studio_part(said_id, library)
		var real: String = library.resolve(named)
		var shown: String = real
		var fixed: int = library.current_colour(real)
		if fixed >= 0:
			shown = library.current(real)
		if shown == part and (fixed < 0 or fixed == colour):
			token = reference
			if real != named:
				by = library.moved_by(named)
	elif said_id == part:
		token = reference
	var said_colour: String = _colour_token(colour) if painted else words[1]
	return "1 %s %s %s" % [said_colour, _numbers_for(words, local * by.affine_inverse()), token]


## The line that gives the part read from [param origin] its colour: the
## nearest line round it, its own aside, that says one, not 16; -1 for none.
func _colour_line(origin: String) -> int:
	var chain: PackedStringArray = origin.split("/", false)
	for k: int in range(chain.size() - 2, -1, -1):
		var at: int = chain[k].to_int()
		var words: PackedStringArray = _words(lines[at])
		if words.size() < 2 or words[0] != "1":
			return -1
		if words[1] != "16":
			return at
	return -1


## Placing line [param line] with its colour [param token], every other
## character of it as it was.
static func _with_colour(line: String, token: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("^(\\s*1\\s+)(\\S+)").search(line)
	if found == null:
		return line
	return found.get_string(1) + token + line.substr(found.get_end(2))


static func _add_to(table: Dictionary, key: Variant, value: Variant) -> void:
	if not table.has(key):
		table[key] = []
	(table[key] as Array).append(value)


## [param text], a patch with the app's own lines written into it
## (ModelStore), with those lines as the file's own: one the file has as it
## has it; a new one ending as the file's lines end, and above the lines
## that say what the next part is for another program ([method
## _binds_next]), never between them and that part, where it was said of
## nothing: put after an LDCad GROUP_NXT, the floor's line left the part in
## no group (ktreview). One that says what a line of the file says, its
## fields in another order (a VIEW written by hand or another build), is
## the file's line: kt4review's metas came back reordered with nothing
## changed. And one the file has stays where the file has it in its step
## ([method _in_file_places]).
func app_lines_placed(text: String) -> String:
	if not text.contains("0 !BRICKWORKS"):
		return text
	var had: Dictionary = {}        ## the file's own app lines, as it ended them
	var meant: Dictionary = {}      ## the same, by what each says
	var after: Dictionary = {}      ## each of them, the line it follows in the file
	var before: Dictionary = {}     ## and the line after it
	var twice: Dictionary = {}      ## those the file has more than once
	for n: int in original.size():
		var line: String = original[n]
		if _is_app_line(line):
			if had.has(line.trim_suffix("\r")):
				twice[line] = true
			had[line.trim_suffix("\r")] = line
			meant[_app_said(line.trim_suffix("\r"))] = line
			# "\n" for none: no line is that.
			after[line] = original[n - 1].trim_suffix("\r") if n > 0 else "\n"
			before[line] = original[n + 1].trim_suffix("\r") if n + 1 < original.size() else "\n"
	var put: PackedStringArray = text.split("\n")
	var out := PackedStringArray()
	var own_at := PackedByteArray()  ## 1 for each line of out the file has
	for n: int in put.size():
		var line: String = put[n]
		var bare: String = line.trim_suffix("\r")
		var own: String = str(had[bare]) if had.has(bare) \
			else str(meant.get(_app_said(bare), "")) if _is_app_line(line) else ""
		if not _is_app_line(line):
			out.append(line)
			own_at.append(0)
		elif not own.is_empty():
			# One the file has (a save of it before): as it has it. Right
			# after the line it follows in the file, or else above the
			# lines that say what the next part is: the floor's writer puts
			# its line above the first part, and with the file's own line
			# there a second save left a GROUP_NXT saying it of the floor
			# (keep_text). Then where the file has it in its step
			# (_in_file_places).
			var at: int = out.size()
			if at == 0 or out[at - 1].trim_suffix("\r") != str(after[own]):
				at = before_run(out, at)
			out.insert(at, own)
			own_at.insert(at, 0 if twice.has(own) else 1)
		else:
			var said: String = line.trim_suffix("\r") + (_eol() if n < put.size() - 1 else "")
			var at: int = before_run(out, out.size())
			out.insert(at, said)
			own_at.insert(at, 0)
	return "\n".join(_in_file_places(out, own_at, after, before))


## [param out] with each line the file has ([param own_at], an app line the
## file has once) moved, within the stretch of lines the app's writer put it
## in, to where the file has it there: after the line it follows in the
## file ([param after]), or else before the line after it ([param before]),
## when that line is in the stretch once. A stretch is the lines between two
## that begin a step or a model (STEP, ROTSTEP, FILE, NOFILE), so no line
## changes step or model. A writer that puts its lines elsewhere than an
## older build did moved them on a save with nothing changed: since pre261 a
## VIEW goes under the main model's title, before it under its 0 FILE
## (kt4review's studio_meta), and a step's look one put by hand at its top
## went to its end (kt5 lights1). One whose neighbours went keeps the place
## its writer gave it.
static func _in_file_places(out: PackedStringArray, own_at: PackedByteArray,
		after: Dictionary, before: Dictionary) -> PackedStringArray:
	if not own_at.has(1):
		return out
	var result := PackedStringArray()
	var size: int = out.size()
	# A last empty line is the text's end, in no stretch.
	var end: int = size - 1 if size > 0 and out[size - 1].is_empty() else size
	var start: int = 0
	var opener: String = "\n"       ## the line before the stretch; none at the top
	while start < end:
		var stop: int = start
		while stop < end and not _begins_stretch(out[stop]):
			stop += 1
		result.append_array(_placed_in(out.slice(start, stop), own_at.slice(start, stop),
			opener, after, before))
		if stop < end:
			result.append(out[stop])
			opener = out[stop].trim_suffix("\r")
		start = stop + 1
	for n: int in range(end, size):
		result.append(out[n])
	return result


## [method _in_file_places] for one stretch, [param lines], after the line
## [param opener].
static func _placed_in(lines: PackedStringArray, own_at: PackedByteArray, opener: String,
		after: Dictionary, before: Dictionary) -> PackedStringArray:
	if not own_at.has(1):
		return lines
	var where: Dictionary = {}      ## a line's text (its end aside) -> its line, -2 for more than one
	for k: int in lines.size():
		var bare: String = lines[k].trim_suffix("\r")
		where[bare] = -2 if where.has(bare) else k
	# Each line to place goes after or before another, or at the top: one
	# not to be placed, or one placed before it, so every one is reached.
	var after_of: Dictionary = {}   ## a line -> those going right after it
	var before_of: Dictionary = {}  ## a line -> those going right before it
	var top: Array[int] = []
	var base: Array[int] = []       ## the lines not to be placed, in order
	var last_kept: int = -1
	for k: int in lines.size():
		if own_at[k] == 0:
			base.append(k)
			last_kept = k
			continue
		var prev: String = str(after.get(lines[k], "\n"))
		var at: int = int(where.get(prev, -1))
		if at >= 0 and (own_at[at] == 0 or at < k):
			_add_to(after_of, at, k)
			continue
		if prev == opener:
			top.append(k)
			continue
		at = int(where.get(str(before.get(lines[k], "\n")), -1))
		if at >= 0 and (own_at[at] == 0 or at < k):
			_add_to(before_of, at, k)
		elif last_kept >= 0:
			# Where its writer put it: after the line before it there.
			_add_to(after_of, last_kept, k)
		else:
			top.append(k)
	# Written out without recursion (a file can have thousands in a row):
	# 2k + 1 writes line k, 2k writes what goes before it, it, and after it.
	var out := PackedStringArray()
	var stack := PackedInt32Array()
	var roots: Array[int] = top + base
	for n: int in range(roots.size() - 1, -1, -1):
		stack.append(roots[n] * 2)
	while not stack.is_empty():
		var v: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var k: int = v >> 1
		if v & 1:
			out.append(lines[k])
			continue
		var afters: Array = after_of.get(k, [])
		for n: int in range(afters.size() - 1, -1, -1):
			stack.append(int(afters[n]) * 2)
		stack.append(k * 2 + 1)
		var befores: Array = before_of.get(k, [])
		for n: int in range(befores.size() - 1, -1, -1):
			stack.append(int(befores[n]) * 2)
	return out


## Whether [param line] begins a step or a model, where a stretch of
## [method _in_file_places] ends.
static func _begins_stretch(line: String) -> bool:
	var word: String = _keyword(line)
	return word == "STEP" or word == "ROTSTEP" or word == "FILE" or word == "NOFILE"


# -- the gate -----------------------------------------------------------------


## Why [param text], the patch [param plan] with the app's own lines written
## into it, may not go over the file; "" when it may. Held to the file as it
## was opened ([member original]), line by line, and read back as an open
## reads it, part by part by its line:
## - the text's lines, the app's own aside, are the patch's;
## - each line the patch keeps is the file's, byte for byte, in the file's
##   order; each it rewrites is a placing line of a part or copy that was
##   edited; each it moves, one of a part whose step changed, with the
##   lines bound to it; each new one, a line for parts with none;
## - each of the file's lines it leaves out is a part's taken off, a line
##   bound to one, a pair left empty, a sub-model no line places, or the
##   app's own;
## - read back, every part is there once, in its part, colour, place,
##   copy and step, and nothing else is; the parts the app cannot show and
##   those on their way on their lines;
## - every placing line is in the pairs it was in, a new one in none.
## Reads only what it is given and this source: on any thread.
func gate(plan: Plan, text: String, library: PartLibrary, waiting: Dictionary,
		steps_now: Dictionary) -> String:
	if not plan.why.is_empty():
		return plan.why
	# The text's lines, the app's own aside, matched to the patch's: the
	# patch as the text has it, each line of it judged against the file.
	var final: PackedStringArray = text.split("\n")
	var map := PackedInt32Array()   ## each line of the text -> its line of [var plan], -1 for the app's
	plan = _as_written(plan, final, map)
	# Each line of the patch, held to the file as it was.
	var alive: Dictionary = {}      ## every line a part in the model or on its way is read through
	for origin: Variant in plan.now.keys() + waiting.keys():
		for at: String in str(origin).split("/", false):
			alive[at.to_int()] = true
	var used: Dictionary = {}
	var last_kept: int = -1
	var last: int = original.size() - 1
	var may_say: Dictionary = _colours_said(plan)
	# A file that ended with no line break ends so again: the text's last
	# line with no end, the file's line before it that had one too
	# (_ended_as_begun).
	var ends_bare: bool = last >= 0 and not original[last].is_empty() \
		and not original[last].ends_with("\r")
	for n: int in plan.out.size():
		var said: String = plan.out[n]
		if _is_app_line(said):
			continue
		var from: int = plan.from[n]
		var how: int = plan.how[n]
		var at_end: bool = ends_bare and n == plan.out.size() - 1 and text.ends_with(said)
		if how != NEW and how != FOREIGN and (from < 0 or from >= original.size() or used.has(from)):
			return "a line of the file written twice, or one it has not got"
		match how:
			KEEP, REWRITE:
				if from <= last_kept:
					return "line %d of the file out of its order" % (from + 1)
				last_kept = from
				if how == KEEP and said != original[from] \
						and not (from == last and said == original[from] + _eol()) \
						and not (at_end and said == original[from].trim_suffix("\r")):
					return "line %d of the file changed with no edit to it" % (from + 1)
				if how == REWRITE and (not _is_placing(said) or not _may_change(plan, from, false, steps_now)):
					return "line %d of the file changed, and nothing on it was edited" % (from + 1)
				if how == REWRITE:
					var why: String = _rewritten_as_written(plan, from, said, may_say, at_end)
					if not why.is_empty():
						return why
			MOVE:
				if not _may_change(plan, from, true, steps_now):
					return "line %d of the file moved, and nothing on it changed step" % (from + 1)
				if said != original[from] and not (from == last and said == original[from] + _eol()) \
						and not (_is_placing(said) and _is_placing(original[from])
						and _may_change(plan, from, false, steps_now)):
					return "line %d of the file moved and changed, and nothing on it was edited" % (from + 1)
				if said != original[from]:
					var why: String = _rewritten_as_written(plan, from, said, may_say, at_end)
					if not why.is_empty():
						return why
			NEW:
				if not _is_placing(said) or (plan.new_bricks.get(n, []) as Array).is_empty():
					return "a new line places no new part (%s)" % said.strip_edges().left(60)
				var why: String = _new_as_written(said, plan.new_bricks[n] as Array,
					n == plan.out.size() - 1)
				if not why.is_empty():
					return why
			_:
				return "a line is written the file has not got, and no part is on it (%s)" \
					% said.strip_edges().left(60)
		if from >= 0:
			used[from] = true
	for n: int in original.size():
		if used.has(n) or _is_app_line(original[n]):
			continue
		if not _may_go(plan, n, alive):
			return "line %d of the file was left out, and nothing taken off was on it (%s)" % [
				n + 1, original[n].strip_edges().left(60)]
	# The pairs round each placing line.
	var why: String = _pairs_kept(plan, final, map)
	if not why.is_empty():
		return why
	# Read back.
	return _read_back_kept(plan, text, final, map, library, waiting, steps_now)


## Each line of the file -> the colours it may now say, as their codes are
## written ([method _colour_token]): those of the parts painted on it, and
## of a flexible part painted whose colour it gives ([method _colour_line]).
func _colours_said(plan: Plan) -> Dictionary:
	var out: Dictionary = {}
	for origin: String in plan.now:
		var was: Read = by_origin.get(origin)
		var colour: int = ((plan.now[origin] as Array)[0] as BrickWorld.Brick).color_code
		if was == null or colour == was.colour:
			continue
		var token: String = _colour_token(colour)
		_add_to(out, origin.get_slice("/", origin.get_slice_count("/") - 1).to_int(), token)
		var giving: int = _colour_line(origin)
		if giving >= 0:
			_add_to(out, giving, token)
	return out


## Why [param said], the file's placing line [param from] rewritten, does
## not say what changed as the file's own words say it; "". Its fields are
## held to the file's as written, not as an open reads them, since an open
## makes some of them one: a top-level 16 reads as 0 (black), and "wing
## part.ldr" as "wing  part.ldr" (kt5review #1, gate2 g_bound_black).
## - its colour as the file wrote it, or the code of a colour painted on it
##   ([param may_say], [method _colours_said]);
## - what it names as the file wrote it, or, where its part was swapped or
##   painted, that part's number as a new line names it;
## - its place's three numbers as the file wrote them unless the place they
##   say is another, and its turn's nine unless the turn is;
## - its line end the file's, or none where it ends the text of a file that
##   ended with no line break ([param at_end]).
func _rewritten_as_written(plan: Plan, from: int, said: String, may_say: Dictionary,
		at_end: bool = false) -> String:
	var was: PackedStringArray = _words(original[from])
	var now: PackedStringArray = _words(said)
	var was_at: Variant = _numbers_of(was)
	var now_at: Variant = _numbers_of(now)
	if was_at == null or now_at == null:
		return "line %d of the file rewritten past reading" % (from + 1)
	if now[1] != was[1] and not (may_say.get(from, []) as Array).has(now[1]):
		return "line %d of the file says colour %s, which no part painted on it is" % [from + 1, now[1]]
	var named: String = _named_as_written(said)
	if named != _named_as_written(original[from]):
		var swapped: bool = false
		for read: Read in by_line.get(from, []):
			if plan.now.has(read.origin):
				var brick: BrickWorld.Brick = (plan.now[read.origin] as Array)[0]
				if (brick.part_id != read.part_id or brick.color_code != read.colour) \
						and named == brick.part_id + ".dat":
					swapped = true
		if not swapped:
			return "line %d of the file names %s, not what it named (%s)" % [
				from + 1, named.left(60), _named_as_written(original[from]).left(60)]
	var a: Transform3D = LdrModel.to_transform(was_at)
	var b: Transform3D = LdrModel.to_transform(now_at)
	for k: int in range(2, 14):
		if now[k] == was[k]:
			continue
		if k < 5 and a.origin.distance_to(b.origin) <= NEAR:
			return "line %d of the file has its place written anew, and it is where it was" % (from + 1)
		if k >= 5 and _same(Transform3D(a.basis, Vector3.ZERO), Transform3D(b.basis, Vector3.ZERO)):
			return "line %d of the file has its turn written anew, and it is turned as it was" % (from + 1)
	if said.ends_with("\r") != original[from].ends_with("\r") and from != original.size() - 1 \
			and not at_end:
		return "line %d of the file ends another way" % (from + 1)
	return ""


## Why [param said], a new line for the parts [param bricks], does not say
## them as written: each one's colour by its own code (a 16 at the top of a
## file would read as 0), or 16 in a copy that hands its parts of 16 that
## colour ([method _fresh_lines]), its number as "part.dat", the file's line
## end unless it is the text's [param at_end]; "".
func _new_as_written(said: String, bricks: Array, at_end: bool) -> String:
	var words: PackedStringArray = _words(said)
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var handed: bool = words[1] == "16" and not brick.unit.is_empty() \
			and int(unit_colours.get(brick.unit, -999)) == brick.color_code
		if words[1] != _colour_token(brick.color_code) and not handed:
			return "a new line says colour %s, and its part is %s" % [words[1], _colour_token(brick.color_code)]
		if _named_as_written(said) != brick.part_id + ".dat":
			return "a new line names %s, and its part is %s" % [_named_as_written(said).left(60), brick.part_id]
	if not at_end and said.ends_with("\r") != _crlf:
		return "a new line ends another way than the file's"
	return ""


static func _is_app_line(line: String) -> bool:
	return line.begins_with("0 !BRICKWORKS")


## What an app line says: its words, and the JSON after them with its
## fields in one order; the line itself when it has none.
static func _app_said(line: String) -> String:
	var at: int = line.find("{")
	if at < 0:
		return line
	var value: Variant = JSON.parse_string(line.substr(at))
	return line if value == null else line.substr(0, at) + JSON.stringify(value, "", true)


## [param plan] as [param final], a text written over it, has it: each of
## the text's lines, the app's own aside, the patch's line it is, matched
## in order as a line diff matches them ([method _aligned]); a placing line
## that is none of them, a rewrite of a placing line of the patch's it
## stands in place of; any other line, one from nowhere ([const FOREIGN]).
## A writer after the patch, or a fault in it, is judged so against the
## file line by line, as the patch is. Fills [param map]: each line of
## [param final] -> its line of the plan returned, -1 for the app's.
func _as_written(plan: Plan, final: PackedStringArray, map: PackedInt32Array) -> Plan:
	var wrote := PackedStringArray()
	var wrote_at := PackedInt32Array()
	for k: int in plan.out.size():
		if not _is_app_line(plan.out[k]):
			wrote.append(plan.out[k])
			wrote_at.append(k)
	var said := PackedStringArray()
	for line: String in final:
		if not _is_app_line(line):
			said.append(line)
	var matched: PackedInt32Array = _aligned(said, wrote)
	var taken: Dictionary = {}
	var next_matched := PackedInt32Array()  ## each line of said -> the patch's line the next matched one is
	next_matched.resize(said.size() + 1)
	next_matched[said.size()] = wrote.size()
	for j: int in range(said.size() - 1, -1, -1):
		next_matched[j] = matched[j] if matched[j] >= 0 else next_matched[j + 1]
		if matched[j] >= 0:
			taken[matched[j]] = true
	var seen := Plan.new()
	seen.now = plan.now
	seen.fresh = plan.fresh
	seen.gone = plan.gone
	seen.changed = plan.changed
	map.resize(final.size())
	var j: int = 0
	var gap: int = 0
	for n: int in final.size():
		if _is_app_line(final[n]):
			map[n] = -1
			continue
		map[n] = seen.out.size()
		var k: int = matched[j]
		var how: int = FOREIGN
		var from: int = -1
		if k >= 0:
			how = plan.how[wrote_at[k]]
			from = plan.from[wrote_at[k]]
			if plan.new_bricks.has(wrote_at[k]):
				seen.new_bricks[seen.out.size()] = plan.new_bricks[wrote_at[k]]
			gap = k + 1
		elif _is_placing(final[n]):
			for g: int in range(gap, next_matched[j]):
				var at: int = wrote_at[g]
				if not taken.has(g) and plan.from[at] >= 0 and _is_placing(wrote[g]):
					taken[g] = true
					how = MOVE if plan.how[at] == MOVE else REWRITE
					from = plan.from[at]
					break
		seen.out.append(final[n])
		seen.from.append(from)
		seen.how.append(how)
		j += 1
	return seen


## How far past a line two texts differ on [method _aligned] looks for them
## to meet again.
const LOOK := 400


## Each line of [param a] -> the line of [param b] it is, or -1: the two
## matched in order, as a line diff matches them, looking up to
## [const LOOK] lines past a line they differ on for the two to meet again.
## However it matches them, a line matched is the same text in the same
## order, so a match only ever finds more to judge, never less.
static func _aligned(a: PackedStringArray, b: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(a.size())
	out.fill(-1)
	var i: int = 0
	var j: int = 0
	while j < a.size() and i < b.size():
		if a[j] == b[i]:
			out[j] = i
			i += 1
			j += 1
			continue
		var di: int = -1
		for d: int in range(1, mini(LOOK, b.size() - i)):
			if b[i + d] == a[j]:
				di = d
				break
		var dj: int = -1
		for d: int in range(1, mini(LOOK, a.size() - j)):
			if a[j + d] == b[i]:
				dj = d
				break
		if di > 0 and (dj < 0 or di <= dj):
			i += di
		elif dj > 0:
			j += dj
		else:
			i += 1
			j += 1
	return out


## Whether the file's line [param line] may be rewritten, or moved
## ([param moved]): a part on it, or a copy it places, was edited; a line
## bound to a moved one goes with it.
func _may_change(plan: Plan, line: int, moved: bool, steps_now: Dictionary) -> bool:
	if not _is_placing(original[line]):
		if not moved or not _binds_next(original[line]):
			return false
		var n: int = line + 1
		while n < original.size() and not _is_placing(original[n]):
			n += 1
		return n < original.size() and _bound_from[n] <= line and _may_change(plan, n, true, steps_now)
	for read: Read in by_line.get(line, []):
		if not plan.now.has(read.origin):
			continue
		var held: Array = plan.now[read.origin]
		var brick: BrickWorld.Brick = held[0]
		if moved:
			if authored and brick.step != read.step:
				return true
		elif brick.part_id != read.part_id or brick.color_code != read.colour \
				or not _same(read.at, held[1] as Transform3D):
			return true
	# A copy's line: a part read through it painted (a flexible one, which
	# has no line to say its colour on), a part under it moved, or the
	# copy's step changed.
	if not moved:
		var through: String = "%d/" % line
		for origin: String in plan.now:
			if (origin.begins_with(through) or origin.contains("/" + through)) \
					and (plan.now[origin][0] as BrickWorld.Brick).color_code != (by_origin[origin] as Read).colour:
				return true
	for path: String in unit_lines:
		if int(unit_lines[path]) != line:
			continue
		if moved:
			if steps_now.has(path) and int(steps_now[path]) != int(unit_steps.get(path, -1)):
				return true
			continue
		for origin: String in plan.now:
			var read: Read = by_origin[origin]
			if (read.unit == path or read.unit.begins_with(path + "/")) \
					and not _same(read.at, (plan.now[origin] as Array)[1] as Transform3D):
				return true
	return false


## Whether the file's line [param line] may be left out: a line no part in
## the model or on its way is read through ([param alive]) that is a part's
## or a copy's, one bound to such a line, or a pair left with nothing in it.
func _may_go(plan: Plan, line: int, alive: Dictionary) -> bool:
	if not plan.gone.has(line) or alive.has(line):
		return false
	if _is_placing(original[line]) or by_line.has(line):
		return true
	if _binds_next(original[line]):
		var n: int = line + 1
		while n < original.size() and not _is_placing(original[n]):
			n += 1
		if n < original.size() and _bound_from[n] <= line:
			return not alive.has(n) and plan.gone.has(n)
	for pair: Array in _pairs:
		if int(pair[0]) != line and int(pair[1]) != line:
			continue
		var any: bool = false
		for k: int in range(int(pair[0]) + 1, mini(int(pair[1]), original.size())):
			if plan.gone.has(k):
				any = true
			elif not original[k].strip_edges().is_empty():
				return false
		if any:
			return true
	return false


## Why the pairs round a placing line of [param final] are not what they
## were in the file; "".
func _pairs_kept(plan: Plan, final: PackedStringArray, map: PackedInt32Array) -> String:
	var open: Dictionary = {}       ## kind -> [file lines of their begins]
	for n: int in final.size():
		if map[n] < 0:
			continue
		var raw: String = final[n]
		var from: int = plan.from[map[n]]
		var keyword: String = _keyword(raw)
		if keyword == "FILE":
			open.clear()
		if keyword == "STEP" or keyword == "ROTSTEP":
			continue
		var pair: Array = _pair_of(raw)
		if not pair.is_empty():
			var kind: String = pair[0]
			if int(pair[1]) > 0:
				if not open.has(kind):
					open[kind] = []
				(open[kind] as Array).append(from)
			elif open.has(kind) and not (open[kind] as Array).is_empty():
				(open[kind] as Array).pop_back()
			continue
		if not _is_placing(raw):
			continue
		var stack: Array = []
		for kind: String in open:
			stack.append_array(open[kind])
		stack.sort()
		var wanted: Array = [] if from < 0 else _stack_at.get(from, [])
		if stack != wanted:
			return "line %d is no longer in the pairs it was in" % ((from if from >= 0 else n) + 1)
	return ""


## Why [param text], read back as an open reads it, is not the model; "".
func _read_back_kept(plan: Plan, text: String, final: PackedStringArray,
		map: PackedInt32Array, library: PartLibrary, waiting: Dictionary,
		steps_now: Dictionary) -> String:
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return "it could not be read back"
	if library != null:
		CustomParts.put_skins(library, model)
	if model.steps_are_authored() != authored:
		return "read back, its steps would be another's"
	var seen: Dictionary = {}
	var fresh_left: Dictionary = {}
	for n: int in plan.new_bricks:
		for brick: Variant in plan.new_bricks[n]:
			fresh_left[(brick as BrickWorld.Brick).id] = true
	var fresh_at: Dictionary = {}
	for entry: Array in plan.fresh:
		fresh_at[(entry[0] as BrickWorld.Brick).id] = entry
	for item: Variant in model.flatten(library.parts if library != null else {}):
		var placement: LdrModel.Placement = item
		var origin := PackedStringArray()
		var leaf_new: int = -1
		for written: String in placement.origin.split("/", false):
			var at: int = written.to_int()
			var in_patch: int = map[at] if at < map.size() else -1
			if in_patch < 0:
				return "a part read back from a line of the app's own"
			var from: int = plan.from[in_patch]
			if from < 0:
				leaf_new = in_patch
				break
			origin.append(str(from))
		if not authored:
			placement.step = -1
		if placement.mirrored and leaf_new < 0:
			# A part of a mirrored copy is never edited in a patch: its
			# lines as the file had them, read as the open read them.
			for written: String in placement.origin.split("/", false):
				if plan.how[map[written.to_int()]] != KEEP:
					return "read back, a mirrored part's line changed"
			var was: Read = by_origin.get("/".join(origin))
			if was == null:
				return "read back, a mirrored part the file had not got"
			placement.part_id = was.part_id
			placement.color_code = was.colour
			placement.transform = was.at
		else:
			_as_opened(placement, library)
		if leaf_new >= 0:
			var matched: bool = false
			for brick: Variant in plan.new_bricks.get(leaf_new, []):
				var mine: BrickWorld.Brick = brick
				if not fresh_left.has(mine.id) or mine.unit != placement.unit:
					continue
				var entry: Array = fresh_at[mine.id]
				if mine.part_id == placement.part_id and mine.color_code == placement.color_code \
						and _close_to(entry[1] as Transform3D, placement.transform) \
						and (mine.step < 0 or mine.step == placement.step):
					fresh_left.erase(mine.id)
					matched = true
					break
			if not matched:
				return "read back, a new part is not where it was put (line %d)" % (leaf_new + 1)
			continue
		var key: String = "/".join(origin)
		if seen.has(key):
			return "read back, one line is two parts (%s)" % key
		seen[key] = true
		if waiting.has(key) or unshown_origins.has(key):
			continue
		if not plan.now.has(key):
			return "read back, a part taken off is there (line %d)" % (int(origin[origin.size() - 1]) + 1)
		var held: Array = plan.now[key]
		var brick: BrickWorld.Brick = held[0]
		if brick.part_id != placement.part_id or brick.color_code != placement.color_code:
			return "read back, line %d is %s in %d, not %s in %d" % [int(origin[origin.size() - 1]) + 1,
				placement.part_id, placement.color_code, brick.part_id, brick.color_code]
		if not _close_to(held[1] as Transform3D, placement.transform):
			return "read back, line %d is not where its part is" % (int(origin[origin.size() - 1]) + 1)
		# Its copy by the lines placing it (the origin, matched above) and
		# by its path as the file opens again: the app's lines name a copy
		# by it (a motion's JOINT ASSEMBLY, a copy's step), so a copy
		# numbered again is another copy (kt5review #5, [method _renumbered]).
		if placement.unit != brick.unit:
			return "read back, line %d is in another copy" % (int(origin[origin.size() - 1]) + 1)
		if authored and placement.step != brick.step:
			return "read back, line %d is in step %d, not %d" % [int(origin[origin.size() - 1]) + 1,
				placement.step, brick.step]
	for origin: String in plan.now:
		if not seen.has(origin):
			return "read back without the part on line %d" % (int(origin.get_slice("/", origin.get_slice_count("/") - 1)) + 1)
	if not fresh_left.is_empty():
		return "read back without %d new part%s" % [fresh_left.size(), "" if fresh_left.size() == 1 else "s"]
	if authored:
		for path: String in steps_now:
			if model.unit_steps.has(path) and int(model.unit_steps[path]) != int(steps_now[path]):
				return "read back, the copy %s is in step %d, not %d" % [path, int(model.unit_steps[path]),
					int(steps_now[path])]
	return ""


## [param placement] as ModelStore's open makes it the part it puts down: a
## Studio number as LDraw's, a retired number the part it became, a part
## of one colour as it is now. A mirrored copy's part is read as the open
## read it ([method _read_back_kept]).
static func _as_opened(placement: LdrModel.Placement, library: PartLibrary) -> void:
	if library == null:
		return
	placement.part_id = ModelStore.studio_part(placement.part_id, library)
	var real: String = library.resolve(placement.part_id)
	if real != placement.part_id:
		placement.transform = placement.transform * library.moved_by(placement.part_id)
		placement.part_id = real
	var colour: int = library.current_colour(placement.part_id)
	if colour >= 0:
		placement.part_id = library.current(placement.part_id)
		placement.color_code = colour


## Why [param text] may not go over the file for the model [param bricks]
## stand as ([method patch] then [method gate]); "" when it may. A probe's
## way to hold a hand-made text to the gate.
func checked(text: String, bricks: Array, lift: Vector3, waiting: Dictionary,
		library: PartLibrary, steps_now: Dictionary = {}) -> String:
	var origins: Dictionary = {}
	for key: Variant in waiting:
		origins[str(key)] = true
	var plan: Plan = patch(bricks, lift, origins, library, steps_now)
	return gate(plan, text, library, origins, steps_now)


## Whether [param a] and [param b] put a part in one place, turned alike,
## as a file's numbers and a part's place read and written again do.
static func _close_to(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > NEAR:
		return false
	for k: int in 3:
		if (a.basis[k] - b.basis[k]).length() > 0.001:
			return false
	return true


# -- what (B) leaves out ---------------------------------------------------------


## The file's own lines [param text], written for the model, leaves out, by
## kind -> how many: its comments and other programs' lines, not its parts
## (written again in the model's own words) nor its steps.
func left_out_of(text: String) -> Dictionary:
	var have: Dictionary = {}
	for line: String in text.split("\n"):
		var said: String = " ".join(_words(line))
		have[said] = int(have.get(said, 0)) + 1
	var out: Dictionary = {}
	for line: String in original:
		var words: PackedStringArray = _words(line)
		if words.size() < 2 or words[0] != "0":
			continue
		var keyword: String = words[1].to_upper()
		if keyword in ["STEP", "ROTSTEP", "NOFILE", "FILE", "!BRICKWORKS"] or keyword.begins_with("!:"):
			continue
		var said: String = " ".join(words)
		if int(have.get(said, 0)) > 0:
			have[said] = int(have[said]) - 1
			continue
		var kind: String = _kind_said(words)
		out[kind] = int(out.get(kind, 0)) + 1
	return out


## What a person calls a line of [param words]: "comment", "header",
## "other", or the program it is for ("LPub", "LDCad", ...).
static func _kind_said(words: PackedStringArray) -> String:
	var keyword: String = words[1].to_upper()
	if keyword.begins_with("//"):
		return "comment"
	for named: Array in [["!LPUB", "LPub"], ["LPUB", "LPub"], ["!LDCAD", "LDCad"],
			["!LEOCAD", "LeoCAD"], ["MLCAD", "MLCad"], ["BUFEXCHG", "MLCad"], ["GHOST", "MLCad"],
			["GROUP", "MLCad"], ["SYNTH", "LSynth"], ["!TEXMAP", "TEXMAP"],
			["PE_TEX_PATH", "Studio"], ["PE_TEX_INFO", "Studio"], ["BFC", "BFC"]]:
		if keyword == str(named[0]):
			return str(named[1])
	if keyword in ["NAME:", "AUTHOR:", "!LICENSE", "!LDRAW_ORG", "!HISTORY", "!CATEGORY",
			"!KEYWORDS", "!THEME", "!HELP", "!CMDLINE"]:
		return "header"
	if keyword.begins_with("!"):
		return "other"
	return "comment"



# -- lines --------------------------------------------------------------------


## [the pair's kind, 1] for a line opening a pair, [the kind, -1] for one
## closing it, [] for any other: the words before the one that opens or
## closes are its kind. Only the pairs other programs write ([const
## PAIRS]): "0 SYNTH BEGIN ..." and "0 SYNTH END", "0 !LPUB PLI BEGIN IGN"
## and "0 !LPUB PLI END", "0 !TEXMAP START ..." and "0 !TEXMAP END", "0
## MLCAD SKIP_BEGIN" and "0 MLCAD SKIP_END", "0 BUFEXCHG A STORE" and "0
## BUFEXCHG A RETRIEVE", "0 !LEOCAD GROUP BEGIN Roof" and "0 !LEOCAD GROUP
## END". A person's comment that says START or END, "0 Engine START", is a
## comment, kept as any other and never taken out as a pair left empty: 17
## of the OMR's files have one (kt5review c_del_engine).
static func _pair_of(line: String) -> Array:
	var words: PackedStringArray = _words(line)
	if words.size() < 3 or words[0] != "0":
		return []
	var said: Array = PAIRS.get(words[1].to_upper().trim_prefix("!"), [])
	if said.is_empty():
		return []
	var kind := PackedStringArray()
	for n: int in range(1, mini(words.size(), 5)):
		var word: String = words[n].to_upper().trim_prefix("!") if n == 1 else words[n].to_upper()
		var opens: bool = word in (said[0] as Array)
		var closes: bool = word in (said[1] as Array)
		if (opens or closes) and not kind.is_empty():
			return [" ".join(kind) + (" SKIP" if word.begins_with("SKIP") else ""), 1 if opens else -1]
		kind.append(word)
	return []


## The pairs of lines other programs write round parts, by a pair's first
## word ("!" aside) -> [the words that open one, those that close it]:
## LSynth's, LPub's (PLI, BOM, MULTI_STEP, CALLOUT), LDraw's texture map,
## MLCad's SKIP and buffer exchange, LeoCAD's groups.
const PAIRS := {
	"SYNTH": [["BEGIN"], ["END"]],
	"LPUB": [["BEGIN"], ["END"]],
	"TEXMAP": [["START"], ["END"]],
	"MLCAD": [["SKIP_BEGIN"], ["SKIP_END"]],
	"BUFEXCHG": [["STORE"], ["RETRIEVE"]],
	"LEOCAD": [["BEGIN"], ["END"]],
}


## The twelve numbers placing [param local] in a line, from [param words]
## (the line's fields as it was) wherever they still say it: its x y z where
## the place is the same, its nine where the turn is. A colour alone
## changed wrote all twelve again with a float's noise, 0.984 as
## 0.98400015, and a copy moved straight turned by -0.00000001 (kt4review
## #4). Written anew, a place to 1/10000 LDU, a turn to six significant
## digits.
static func _numbers_for(words: PackedStringArray, local: Transform3D) -> String:
	var values: PackedFloat64Array = LdrModel.from_transform(local)
	var out := PackedStringArray()
	for n: int in 12:
		out.append(_number_said(values[n], n < 3))
	if words.size() < 15 or words[0] != "1":
		return " ".join(out)
	var numbers := PackedFloat64Array()
	for n: int in range(2, 14):
		if not words[n].is_valid_float():
			return " ".join(out)
		numbers.append(words[n].to_float())
	var was: Transform3D = LdrModel.to_transform(numbers)
	if was.origin.distance_to(local.origin) <= NEAR:
		for n: int in 3:
			out[n] = words[2 + n]
	if _same(Transform3D(was.basis, Vector3.ZERO), Transform3D(local.basis, Vector3.ZERO)):
		for n: int in range(3, 12):
			out[n] = words[2 + n]
	return " ".join(out)


## [param value] as a line says it: a place to four places, a turn's
## number to six significant digits, a whole number as one, never "-0".
static func _number_said(value: float, place: bool) -> String:
	if value == floorf(value) and absf(value) < 1e9:
		return str(int(value))
	var places: int = 4
	if not place:
		if absf(value) < 5e-7:
			return "0"
		places = clampi(5 - floori(log(absf(value)) / log(10.0)), 0, 12)
	var shown: String = String.num(value, places).rstrip("0").rstrip(".")
	return "0" if shown == "-0" or shown.is_empty() else shown


## Whether [param line] says, for another program, what the line after it
## is, a closed list: BFC's INVERTNEXT, LDCad's group of the next part
## (GROUP_NXT), MLCad's (BTG), LDraw's texture of the next (!TEXMAP NEXT),
## Studio's print on it (PE_TEX_PATH, PE_TEX_INFO) and LeoCAD's piece lines
## (!LEOCAD PIECE, which LeoCAD writes above the piece). These go where the
## part goes, and the app's own lines go in above them ([method
## before_run], [method app_lines_placed]). MLCad's HIDE is not one: it is
## a part's line of its own, hidden.
static func _binds_next(line: String) -> bool:
	var words: PackedStringArray = _words(line)
	if words.size() < 2 or words[0] != "0":
		return false
	var first: String = words[1].to_upper()
	if first == "PE_TEX_PATH" or first == "PE_TEX_INFO":
		return true
	if words.size() < 3:
		return false
	var said: String = first + " " + words[2].to_upper()
	# And the app's own: which copy the reference after it is (LdrModel
	# .COPY_META). Not bound, it stayed when its copy was taken off, saying
	# it of nothing (kt5check F3).
	return said == "BFC INVERTNEXT" or said == "!LDCAD GROUP_NXT" or said == "MLCAD BTG" \
		or said == "!TEXMAP NEXT" or said == "!LEOCAD PIECE" \
		or said == LdrModel.COPY_META.substr(2)


## [param at], or where the lines right above line [param at] of
## [param text_lines] that say what it is for another program begin
## ([method _binds_next]): where a line of the app's own goes that is to go
## before line [param at].
static func before_run(text_lines: PackedStringArray, at: int) -> int:
	while at > 0 and _binds_next(text_lines[at - 1]):
		at -= 1
	return at


static func _is_placing(line: String) -> bool:
	var words: PackedStringArray = _words(line)
	return words.size() >= 15 and words[0] == "1"


## A line's fields as LdrModel reads them (LdrModel._fields): split on any
## run of spaces, tabs and a "\r\n" file's carriage return (kt_tabs).
static func _words(line: String) -> PackedStringArray:
	return LdrModel._fields(line.strip_edges())


## What placing line [param line] names, its 15th field to its end, as the
## file has it: a name with two spaces in a row or a tab in it keeps them.
## Its fields joined by one space made "wing  part.ldr" "wing part.ldr",
## which names no section of the file to any other program (kt5review
## tb_move_copy). Lookups still go by the fields joined, as LdrModel keys
## its sections.
static func _named_as_written(line: String) -> String:
	var at: int = 0
	var n: int = line.length()
	for field: int in 15:
		while at < n and _is_blank(line.unicode_at(at)):
			at += 1
		if field == 14:
			break
		while at < n and not _is_blank(line.unicode_at(at)):
			at += 1
	return line.substr(at).strip_edges(false, true)


## A character LdrModel._fields splits on: a space, a tab, a carriage return.
static func _is_blank(c: int) -> bool:
	return c == 32 or c == 9 or c == 13


## The keyword of a line of type 0, upper case ("STEP", "FILE", "!LDCAD"),
## or "" for any other line.
static func _keyword(line: String) -> String:
	var words: PackedStringArray = _words(line)
	return words[1].to_upper() if words.size() >= 2 and words[0] == "0" else ""
