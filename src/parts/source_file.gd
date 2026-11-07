## The file a model was opened from, kept so a save writes back what nobody
## changed, as it was.
##
## Professional CAD keeps a file it did not write: LDCad, LeoCAD and Studio
## leave an author's name, licence, history, meta commands, comments,
## flexible parts and part numbers alone. Brickworks wrote every save from
## the parts on the baseplate instead, so a real set's file opened and saved
## lost all of that (docs/CADTASK.md, 2026-10-16).
##
## So a model opened from someone else's file keeps the file, and each part
## knows its line: the lines placing the copies round it and its own
## (LdrModel.Placement.origin, BrickWorld.Brick.origin), which no edit
## changes; and each copy of a sub-model knows the lines placing it
## (BrickWorld.unit_chains), wherever a rename, an ungroup or a sub-assembly
## made takes it. A save walks the file, section by section, line by line:
##
## - a part as it was: its line, byte for byte;
## - a part moved, turned or recoloured: its line with those fields written
##   again, in its sub-model's frame, under the number the file used (a
##   retired number stays retired, 4073 stays 4073);
## - a part gone: its line out, with the lines bound to it ([method _run_of]);
## - a copy moved whole: the line placing it written again, its sub-model's
##   lines as they were;
## - a part or copy with no line (put down, pasted): a line at the end of its
##   step, and a section of its own for a sub-model it needs;
## - copies of one sub-model that no longer agree: the changed one a section
##   of its own (its name and " 2"), its placing line pointed at it, as
##   Studio and LDCad do;
## - a step edit: the parts it moved at the end of the step they are in now,
##   every STEP line, empty step and note where it was;
## - every other line where it was: notes, metas, ROTSTEP, the author,
##   !DATA, sub-models nothing places, FILE names.
##
## A file opened from text is never written whole. Until keeptext4 each save
## paired the parts with the lines again by place, path and nearness, and
## wrote the model whole where that failed; two reviews found 16 losses
## (bench/results/keeptext3-2026-11-06/kt3review/report.md).
class_name SourceFile
extends RefCounted

## How near a part must be to where a line puts it to be there: a file's
## numbers are rounded, and a place read and written again is never further
## off than this.
const NEAR := 0.01
const TURN := 0.0001
## LDraw's header lines (its File Format): never bound to a part.
const HEADER := ["FILE", "NOFILE", "!DATA", "NAME:", "AUTHOR:", "!LDRAW_ORG", "!LICENSE",
	"!HISTORY", "!CATEGORY", "!KEYWORDS", "!CMDLINE", "!HELP", "!THEME"]
## The section of a line in none (before the first FILE line, in !DATA): a
## newline, which no section's name can hold.
const NONE := "\n"

## What became of a copy the file places, at a save.
const KEPT := 0         ## still on the baseplate
const DEAD := 1         ## taken off
const DISSOLVED := 2    ## ungrouped: its parts are its parent's now
const BUILT_IN := 3     ## built in the steps of the one round it (AuthorSteps.IN_PARENT)


## A copy of a sub-model the file places, or the model itself: where it
## stands in the file and what is in it.
class Copy extends RefCounted:
	## The lines placing it, outermost first, joined by "/"; "" for the model.
	var chain: String = ""
	## Its path when the file was opened (Placement.unit).
	var path: String = ""
	var section: String = ""
	## Where it stands, in the file's coordinates.
	var frame: Transform3D = Transform3D.IDENTITY
	## The colour it gives its parts of colour 16.
	var colour: int = 0
	## The line placing it, in its parent's section; -1 for the model.
	var line: int = -1
	var parent: Copy = null
	var children: Array[Copy] = []
	var reads: Array[Read] = []
	var depth: int = 0


## A part as the file placed it, in the file's coordinates.
class Read extends RefCounted:
	var origin: String = ""
	var line: int = -1
	var copy: Copy = null
	var part_id: String = ""
	var colour: int = 0
	var at: Transform3D = Transform3D.IDENTITY
	var unit: String = ""
	## A part the app can show (one it cannot is kept as it was).
	var shown: bool = true
	## Read from a line that is no part's: a flexible part's skin, from
	## LDCad's GENERATED line (CustomParts). Never written over.
	var fixed: bool = false


## A line a save writes: a part's, or one placing a copy.
class Item extends RefCounted:
	var read: Read = null
	var brick: BrickWorld.Brick = null
	## Where it is now, in the file's coordinates.
	var at: Transform3D = Transform3D.IDENTITY
	var part_id: String = ""
	var colour: int = 0
	## Its step in the steps of the copy it is written in; -1 for none.
	var step: int = -1
	## The copy built in that one's steps it is part of (IN_META), by its
	## path within it; "" for the copy's own.
	var within: String = ""
	## Its line in the file, in place or where it came from; -1 for none.
	var line: int = -1
	## The copy a placing line places; null for a part.
	var child: Target = null
	## The lines bound to it, carried with it where it goes.
	var run: PackedStringArray = PackedStringArray()
	## The line of its copy's section it goes before, unstepped: where an
	## ungrouped copy's line was. -1 for the end of its step.
	var anchor: int = -1
	var order: int = 0
	## Its line, as it was, where it says the same where it is written.
	var text: String = ""
	## A placing line's colour and numbers, written again ("" where kept).
	var body: String = ""
	## Its line said which copy it is (LdrModel.COPY_META).
	var copy_meta: bool = false


## A copy on the baseplate the save writes a section's lines for: one the
## file places, or one it has not got.
class Target extends RefCounted:
	var path: String = ""
	## The copy of the file it is; null for a new one.
	var copy: Copy = null
	var parent: Target = null
	var frame: Transform3D = Transform3D.IDENTITY
	var colour: int = 0
	var kind: String = ""
	## Its own lines that stay where they are, by line.
	var inplace: Dictionary = {}
	## What is written into it from elsewhere, or new.
	var incoming: Array[Item] = []
	## The line placing it, in its parent.
	var placed: Item = null
	## A new copy that is a copy of this one, placed by a line as it is.
	var like: Target = null
	## Inside a copy so placed: written by nothing.
	var skip: bool = false
	## Its section's lines as written: Strings, and Items for placing lines.
	var entries: Array = []
	var sig: String = ""
	var digest: String = ""
	var group: Group = null
	## Where in [member entries] its FILE, Name: and title lines are.
	var file_at: int = -1
	var name_at: int = -1
	var title_at: int = -1


## The copies of one section that are written alike, under one name.
class Group extends RefCounted:
	var members: Array[Target] = []
	var section: String = ""
	var kind: String = ""
	var name: String = ""
	var title: String = ""
	## Written under another name than the section's own, after it.
	var fork: bool = false
	var retitle: bool = false
	## Entry -> the copy number its placing line says (COPY_META).
	var copy_numbers: Dictionary = {}


## One save's working: what [method write] reads, never the source itself,
## so a save runs on a worker while the model goes on.
class Save extends RefCounted:
	var library: PartLibrary
	var stepped: bool = false
	var steps_now: Dictionary = {}
	var chains_now: Dictionary = {}
	var waiting: Dictionary = {}
	var bricks: Array = []
	var at_of: Dictionary = {}
	var path_of: Dictionary = {}
	var by_origin: Dictionary = {}
	var under: Dictionary = {}
	var alive: Dictionary = {}
	var status: Dictionary = {}
	var path_now: Dictionary = {}
	var pseudo_now: Dictionary = {}
	var motion: Dictionary = {}
	var targets: Dictionary = {}
	var target_of: Dictionary = {}
	var order: Array[Target] = []
	var carried: Dictionary = {}
	var anchors: Dictionary = {}
	var groups: Dictionary = {}
	var by_section: Dictionary = {}
	var news: Array[Group] = []
	var names: Dictionary = {}
	var placing: Dictionary = {}
	var reshaped: bool = false
	## A STEP line goes in after the model's last part: it has steps, and
	## the file would have no STEP line to say so ([method _assemble]).
	var end_step: bool = false
	var within: String = ""
	var main_name: String = ""
	## The sources of the parts made here a save may name ([method write]),
	## and the ids its new lines do name ([method _said]).
	var made: Dictionary = {}
	var new_ids: Dictionary = {}
	## Section -> the title a sub-model placed by nothing is written under
	## ([method _yield_titles]).
	var retitled: Dictionary = {}
	## Sections left out, every part of them gone ([method _gone_sections]).
	var gone: Dictionary = {}


var lines: PackedStringArray
## Whether every line of the file ends in "\r\n", as Studio's and the LDraw
## model repository's do: a save of it ends every line so ([method ended]).
var crlf: bool = false
## Section key -> [its FILE line, the line after its last]: up to the next
## FILE or !DATA line. Of two sections of one name, the later, as a reader
## reads it (kt3review #9).
var sections: Dictionary = {}
var main_key: String = ""
## The model's own section, the first: [its FILE line, the line after].
var main_span: Array = [0, 0]
## Every section in the file's order: [key, first line, line after].
var spans: Array = []
## Sections that are a flexible part LDCad drew (a hose, a band, a string):
## a path and the skin it generated of primitives, which are not parts.
var flexible: Dictionary = {}
## What the model said each copy was when it was opened (LdrModel), by path.
var unit_frames: Dictionary = {}
var unit_sections: Dictionary = {}
var unit_colours: Dictionary = {}
var unit_steps: Dictionary = {}
var unit_lines: Dictionary = {}
var unit_chains: Dictionary = {}
var authored: bool = false
## The parts the app could not show, as LdrModel.Placement.
var not_shown: Array = []
## What the model is called by the file itself: a save under another name
## says that name on a line of its own (ModelStore.TITLE_META).
var own_title: String = ""
## Whether a copy is placed mirrored: a save then asks Mirror for a part's
## other hand (ModelStore indexes it first, on the main thread).
var mirrored: bool = false
## Origin -> Read; chain -> Copy.
var reads: Dictionary = {}
var copies: Dictionary = {}
var root: Copy = null
## Each line's section (NONE for none), the first line of that section, how
## many of its STEP lines are above it, whether a part or STEP line is, and
## where the lines bound to it begin.
var owner: PackedStringArray = PackedStringArray()
var span_at: PackedInt32Array = PackedInt32Array()
var block: PackedInt32Array = PackedInt32Array()
var opened: PackedByteArray = PackedByteArray()
var run_from: PackedInt32Array = PackedInt32Array()
## A section's first line -> its STEP lines; -> its title line.
var steps_in: Dictionary = {}
var titles: Dictionary = {}
## Lines this app writes about the next (COPY_META, IN_META): written again.
var app_lines: Dictionary = {}
## The kinds of line the file has right above a part ([method _family]).
var families: Dictionary = {}
var nofile: bool = false


## [param placements] are what the model opened as: every part put down or
## on its way, after its number was resolved, before the model was stood on
## the ground ([member LdrModel.Placement.origin] set).
## [param hidden_parts] are the parts it holds the app cannot show.
static func make(text: String, model: LdrModel, placements: Array,
		_mirrored_lines: Dictionary, authored_steps: bool, hidden_parts: Array = []) -> SourceFile:
	var source := SourceFile.new()
	source.not_shown = hidden_parts.duplicate()
	source.lines = text.split("\n")
	var ended_so: int = 0
	for n: int in source.lines.size() - 1:
		if source.lines[n].ends_with("\r"):
			ended_so += 1
	source.crlf = source.lines.size() > 1 and ended_so == source.lines.size() - 1
	source.unit_frames = model.unit_frames.duplicate()
	source.unit_sections = model.unit_sections.duplicate()
	source.unit_colours = model.unit_colours.duplicate()
	source.unit_steps = model.unit_steps.duplicate()
	source.unit_lines = model.unit_lines.duplicate()
	source.unit_chains = model.unit_chains.duplicate()
	source.authored = authored_steps
	source._read_sections()
	source._read_copies()
	for item: Variant in placements:
		source._read_part(item as LdrModel.Placement, true)
	for item: Variant in hidden_parts:
		source._read_part(item as LdrModel.Placement, false)
	source._read_runs()
	return source


## Where each section's lines are, as LdrModel.parse reads them, and what
## each line is.
func _read_sections() -> void:
	var size: int = lines.size()
	owner.resize(size)
	span_at.resize(size)
	block.resize(size)
	opened.resize(size)
	run_from.resize(size)
	var has_file: bool = false
	for n: int in size:
		if _keyword(lines[n]) == "FILE":
			has_file = true
			break
	var current: String = NONE if has_file else ""
	var start: int = 0
	var steps := PackedInt32Array()
	var open: bool = false
	var titled: bool = false
	var author_seen: bool = false
	var first: bool = true
	main_span = [0, size]
	titles[0] = -1
	for n: int in size:
		run_from[n] = n
		var words: PackedStringArray = _words(lines[n])
		var keyword: String = words[1].to_upper() if words.size() >= 2 and words[0] == "0" else ""
		if keyword == "FILE" or keyword == "!DATA":
			if current != NONE:
				_close(current, start, n, steps)
			current = NONE
			if keyword == "FILE":
				current = LdrModel._key(" ".join(words.slice(2)))
				start = n
				steps = PackedInt32Array()
				open = false
				titled = false
				titles[start] = -1
				if first:
					main_key = current
					main_span = [n, size]
				first = false
		owner[n] = current
		span_at[n] = start if current != NONE else -1
		block[n] = steps.size()
		opened[n] = 1 if open else 0
		if current == NONE:
			author_seen = author_seen or keyword == "AUTHOR:"
			continue
		if not words.is_empty() and words[0] == "1" and words.size() >= 15:
			open = true
			titled = true
			continue
		if keyword.is_empty() or keyword == "FILE":
			continue
		if keyword == "STEP" or keyword == "ROTSTEP":
			steps.append(n)
			open = true
			continue
		if keyword == "NOFILE":
			nofile = true
		if keyword == "!LDCAD" and words.size() > 2 \
				and (words[2] == "PATH_SKIN" or words[2] == "GENERATED"):
			flexible[current] = true
		if _is_app_meta(lines[n]):
			app_lines[n] = true
			continue
		if keyword == "AUTHOR:" and not author_seen:
			author_seen = true
			continue
		if not titled and not keyword.begins_with("!") and keyword != "BFC" \
				and keyword != "NAME:" and keyword != "NOFILE" and not words[1].begins_with("//"):
			titles[start] = n
			titled = true
	if current != NONE:
		_close(current, start, size, steps)


func _close(key: String, start: int, end: int, steps: PackedInt32Array) -> void:
	sections[key] = [start, end]
	spans.append([key, start, end])
	steps_in[start] = steps
	if start == int(main_span[0]) and key == main_key:
		main_span = [start, end]


## The copies the file places, from what the model said of each.
func _read_copies() -> void:
	root = Copy.new()
	root.section = main_key
	copies[""] = root
	var made: Array[Copy] = []
	for path: String in unit_chains:
		var chain: String = unit_chains[path]
		if chain.is_empty() or chain.contains("|"):
			continue
		var copy := Copy.new()
		copy.chain = chain
		copy.path = path
		copy.section = str(unit_sections.get(path, ""))
		copy.frame = unit_frames.get(path, Transform3D.IDENTITY)
		copy.colour = int(unit_colours.get(path, 16))
		copy.line = int(unit_lines.get(path, -1))
		copy.depth = chain.count("/") + 1
		mirrored = mirrored or copy.frame.basis.determinant() < 0.0
		copies[chain] = copy
		made.append(copy)
	for copy: Copy in made:
		var cut: int = copy.chain.rfind("/")
		var parent: Copy = copies.get("" if cut < 0 else copy.chain.left(cut), root)
		copy.parent = parent
		parent.children.append(copy)


func _read_part(placement: LdrModel.Placement, shown: bool) -> void:
	if placement.origin.is_empty() or reads.has(placement.origin):
		return
	var cut: int = placement.origin.rfind("/")
	var copy: Copy = copies.get("" if cut < 0 else placement.origin.left(cut))
	if copy == null:
		return
	var read := Read.new()
	read.origin = placement.origin
	read.line = placement.origin.substr(cut + 1).to_int()
	read.copy = copy
	read.part_id = placement.part_id
	read.colour = placement.color_code
	read.at = placement.transform
	read.unit = placement.unit
	read.shown = shown
	read.fixed = read.line >= lines.size() or not _is_placing(lines[read.line])
	reads[read.origin] = read
	copy.reads.append(read)


## The lines bound to each part: first the kinds of line the file has right
## above a part where another part or a STEP line is above them, then each
## part's run ([method _run_of]).
func _read_runs() -> void:
	for n: int in lines.size():
		if opened[n] == 1 and owner[n] != NONE and _is_placing(lines[n]):
			for k: int in _collect(n):
				families[_family(lines[k])] = true
	for n: int in lines.size():
		if owner[n] != NONE and _is_placing(lines[n]):
			var run: PackedInt32Array = _run_of(n)
			if not run.is_empty():
				run_from[n] = run[0]


## The lines right above line [param n], bottom up, unbroken by an empty
## line, a part or drawing line, a STEP line or the section's header (its
## FILE line, title, Name:, author, licence and the rest of LDraw's).
func _collect(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var title: int = int(titles.get(span_at[n], -1))
	var k: int = n - 1
	while k >= 0 and span_at[k] == span_at[n]:
		var words: PackedStringArray = _words(lines[k])
		if words.size() < 2 or words[0] != "0":
			break
		var keyword: String = words[1].to_upper()
		if keyword == "STEP" or keyword == "ROTSTEP" or keyword in HEADER or k == title \
				or (keyword == "BFC" and words.size() > 2
					and words[2].to_upper() in ["CERTIFY", "NOCERTIFY"]):
			break
		out.append(k)
		k -= 1
	return out


## The lines bound to the part at line [param n], top down: those right
## above it about the next part, decided by where they are, not by a list
## of known metas. Where a part or a STEP line is above them, every line
## between; LDCad's group, MLCad's group and hidden part, BFC's INVERTNEXT,
## LeoCAD's hidden step and Studio's decoration alike (kt3review #3). Above
## a section's first part, below its header, only the kinds the file has
## so elsewhere: LDCad's GROUP_DEF there is the section's, its GROUP_NXT the
## part's.
func _run_of(n: int) -> PackedInt32Array:
	var found: PackedInt32Array = _collect(n)
	var out := PackedInt32Array()
	if opened[n] == 1:
		out = found
	else:
		for k: int in found:
			if not families.has(_family(lines[k])) and not app_lines.has(k):
				break
			out.append(k)
	out.reverse()
	return out


## What kind of line [param line] is, as runs are told apart: a comment, a
## meta command of a program by its first two words ("!LDCAD GROUP_NXT"),
## any other by its first ("MLCAD", "PE_TEX_INFO").
static func _family(line: String) -> String:
	var words: PackedStringArray = _words(line)
	if words.size() < 2:
		return ""
	if words[1].begins_with("//"):
		return "//"
	var first: String = words[1].to_upper()
	if first.begins_with("!") and words.size() > 2:
		return first + " " + words[2].to_upper()
	return first


## The bound lines of line [param n] as text, the app's own about the next
## left out: they are written again.
func _run_text(n: int) -> PackedStringArray:
	var out := PackedStringArray()
	for k: int in range(run_from[n], n):
		if not app_lines.has(k):
			out.append(lines[k])
	return out


## What of [param placements], parts the app cannot show, a person reads:
## a flexible part by the sub-model it is (one each, however many pieces
## of skin it is drawn with), anything else by its number. Name -> how many.
func unshown(placements: Array) -> Dictionary:
	var out: Dictionary = {}
	var counted: Dictionary = {}
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var unit: String = placement.unit
		while not unit.is_empty() and not unit_sections.has(unit):
			unit = Assemblies.parent_of(unit)
		var section: String = main_key if unit.is_empty() else str(unit_sections[unit])
		if flexible.has(section) and not unit.is_empty():
			if counted.has(unit):
				continue
			counted[unit] = true
			var named: String = "%s (flexible)" % Assemblies.definition(Assemblies.leaf(unit))
			out[named] = int(out.get(named, 0)) + 1
		else:
			out[placement.part_id] = int(out.get(placement.part_id, 0)) + 1
	return out


## The lines of the model's own header that a model written whole does not
## write itself: whose it is and under what terms ([method header_of]).
func header() -> PackedStringArray:
	return SourceFile.header_of(lines)


## [method header] of the model [param text] holds, read from its lines:
## the app's own file keeps its header too (ModelStore._own_header).
##
## The model's header is its first FILE section's: what comes before that
## line is no model's (an exporter's comments). Nor is a line that says what
## the first part is ([method _binds_next]) the header's.
static func header_of(text_lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var titled: bool = false
	var started: bool = false
	var from: int = 0
	for n: int in text_lines.size():
		var words: PackedStringArray = _words(text_lines[n])
		if words.is_empty():
			continue
		if words[0] != "0":
			break
		if words.size() >= 2 and words[1].to_upper() == "FILE":
			from = n
			break
	var at_part: bool = false
	for raw: String in text_lines.slice(from):
		# As the file has it, byte for byte: stripped, 6780-1's keywords line
		# lost the space it ends in (keeptext3).
		var line: String = raw.trim_suffix("\r")
		var words: PackedStringArray = _words(line)
		if words.is_empty():
			continue
		if words[0] != "0" or _is_step(line):
			at_part = words[0] != "0"
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
	while at_part and not out.is_empty() and _binds_next(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out


# -- a save ---------------------------------------------------------------------


## The file again, with the parts on the baseplate written into it: see the
## class. [param bricks] are the model's parts (BrickWorld.Brick, the floor
## left out), [param lift] how far the model was moved to stand on the
## ground, [param waiting] the parts still on their way (by origin),
## [param unit_steps_now] each copy's step (BrickWorld.unit_steps),
## [param chains_now] which copy of the file each copy is
## (BrickWorld.unit_chains), [param stepped] whether the model has steps,
## [param made] the sources of the parts made here it may name, by part id
## (CustomParts.sources_for: [method _made_lines]).
## Reads only what it is given and this source, which it never changes: on
## any thread.
func write(bricks: Array, lift: Vector3, waiting: Dictionary, library: PartLibrary,
		unit_steps_now: Dictionary, chains_now: Dictionary, stepped: bool,
		made: Dictionary = {}) -> String:
	var save := Save.new()
	save.library = library
	save.made = made
	save.stepped = stepped
	save.steps_now = unit_steps_now
	save.chains_now = chains_now
	save.waiting = waiting
	save.bricks = bricks
	_index_bricks(save, lift)
	_place_copies(save)
	_make_targets(save)
	_assign(save)
	_fit_new(save)
	_place_new(save)
	for target: Target in save.order:
		if not target.skip and target.like == null:
			if target.copy != null:
				_render(save, target)
			else:
				_render_new(save, target)
	_group(save)
	var text: String = _assemble(save)
	if save.reshaped:
		text = _read_back(save, text)
	return text


func _index_bricks(save: Save, lift: Vector3) -> void:
	save.alive[""] = true
	for item: Variant in save.bricks:
		var brick: BrickWorld.Brick = item
		save.at_of[brick.id] = Transform3D(brick.transform.basis, brick.transform.origin - lift)
		var path: String = Assemblies.path_of(brick)
		save.path_of[brick.id] = path
		if not save.under.has(path):
			save.under[path] = []
		(save.under[path] as Array).append(brick)
		var at: String = ""
		for segment: String in Assemblies.segments(path):
			at = Assemblies.join(at, segment)
			save.alive[at] = true
		if not brick.origin.is_empty() and reads.has(brick.origin) \
				and not save.by_origin.has(brick.origin):
			save.by_origin[brick.origin] = brick


## Whether the copy at [param path] is built in the steps of the one round
## it (AuthorSteps.IN_PARENT).
static func _built_in(save: Save, path: String) -> bool:
	if save.steps_now.has(path):
		return int(save.steps_now[path]) == AuthorSteps.IN_PARENT
	return str(save.chains_now.get(path, "")).contains("|")


## The copy [param path]'s parts are written in the steps and section of:
## itself, or the nearest round it built in steps of its own.
static func _home(save: Save, path: String) -> String:
	while not path.is_empty() and _built_in(save, path):
		path = Assemblies.parent_of(path)
	return path


static func _within(path: String, home: String) -> String:
	if path == home:
		return ""
	return path if home.is_empty() else path.substr(home.length() + 1)


## What became of each copy the file places, where it is now, and how it
## moved: by the motion most of its own parts made (all of them, where it
## has none of its own; its parent's, where it has no parts on the
## baseplate). One part's motion alone moves a copy only where its
## sub-model has other copies: the one copy of a one-part sub-model keeps
## its placing line, and its part's line says where the part went.
## A flexible part's copy (LDCad's rope, hose) is its part: the part is
## drawn from its sub-model, so its line places it wherever the part is,
## taken out of its copy too (Ungroup), and moves as the part does, its end
## parts written where they are in it; taken away, its line goes.
func _place_copies(save: Save) -> void:
	var placed: Dictionary = {}
	for chain: String in copies:
		var section: String = (copies[chain] as Copy).section
		placed[section] = int(placed.get(section, 0)) + 1
	var by_chain: Dictionary = {}
	for path: String in save.chains_now:
		var chain: String = str(save.chains_now[path])
		if chain.contains("|"):
			save.pseudo_now[chain] = path
			continue
		if not by_chain.has(chain) or (save.alive.has(path)
				and not save.alive.has(str(by_chain[chain]))):
			by_chain[chain] = path
	var brickable: Dictionary = {}
	for origin: String in reads:
		var read: Read = reads[origin]
		if read.shown and not save.waiting.has(origin):
			var copy: Copy = read.copy
			while copy != null and not brickable.has(copy.chain):
				brickable[copy.chain] = true
				copy = copy.parent
	for copy: Copy in _top_down():
		if copy == root:
			save.status[""] = KEPT
			save.path_now[""] = ""
			save.motion[""] = Transform3D.IDENTITY
			continue
		var above: int = int(save.status[copy.parent.chain])
		var state: int = DEAD
		var path: Variant = by_chain.get(copy.chain)
		var drawn: Array = []
		var skin_gone: bool = false
		for read: Read in copy.reads:
			var brick: BrickWorld.Brick = save.by_origin.get(read.origin)
			if brick != null and read.fixed:
				drawn.append(save.at_of[brick.id] * read.at.affine_inverse())
			elif read.fixed and read.shown and not save.waiting.has(read.origin):
				skin_gone = true
		# Its part taken away, a flexible part's copy is gone: its end parts,
		# where there are any, are parts of their own.
		if skin_gone and drawn.is_empty():
			path = null
		if path == null and above != DEAD and not drawn.is_empty():
			path = _unused_path(save, Assemblies.join(str(save.path_now[copy.parent.chain]),
				Assemblies.leaf(copy.path)))
		if path == null:
			state = DEAD if above == DEAD else DISSOLVED
		elif not drawn.is_empty() or save.alive.has(path) \
				or (not brickable.has(copy.chain) and above != DEAD):
			state = BUILT_IN if _built_in(save, str(path)) else KEPT
		save.status[copy.chain] = state
		if path != null:
			save.path_now[copy.chain] = str(path)
		var moves: Array = []
		for read: Read in copy.reads:
			var brick: BrickWorld.Brick = save.by_origin.get(read.origin)
			if brick != null and not read.fixed:
				moves.append(save.at_of[brick.id] * read.at.affine_inverse())
		var least: int = 1 if int(placed[copy.section]) > 1 else 2
		if not drawn.is_empty():
			moves = drawn
			least = 1
		if moves.is_empty():
			for other: Copy in _below(copy):
				for read: Read in other.reads:
					var brick: BrickWorld.Brick = save.by_origin.get(read.origin)
					if brick != null and not read.fixed:
						moves.append(save.at_of[brick.id] * read.at.affine_inverse())
		save.motion[copy.chain] = _most(moves, save.motion[copy.parent.chain], least)
	if save.status.values().any(func(state: int) -> bool: return state != KEPT):
		save.reshaped = true


## [param path], or one like it no copy on the baseplate has.
static func _unused_path(save: Save, path: String) -> String:
	var out: String = path
	while save.chains_now.has(out) or save.path_now.values().has(out):
		out += "~"
	return out


func _top_down() -> Array[Copy]:
	var out: Array[Copy] = [root]
	var at: int = 0
	while at < out.size():
		out.append_array(out[at].children)
		at += 1
	return out


func _below(copy: Copy) -> Array[Copy]:
	var out: Array[Copy] = []
	var todo: Array[Copy] = copy.children.duplicate()
	while not todo.is_empty():
		var next: Copy = todo.pop_back()
		out.append(next)
		todo.append_array(next.children)
	return out


## The motion most of [param moves] are, at least [param least] of them;
## [param fallback] for none, for fewer and in a tie it is in.
static func _most(moves: Array, fallback: Transform3D, least: int = 1) -> Transform3D:
	if moves.is_empty():
		return fallback
	var counts: Dictionary = {}
	var first: Dictionary = {}
	for item: Variant in moves:
		var move: Transform3D = item
		var key: String = _motion_key(move)
		counts[key] = int(counts.get(key, 0)) + 1
		if not first.has(key):
			first[key] = move
	var best: String = ""
	var fallback_key: String = _motion_key(fallback)
	for key: String in counts:
		if best.is_empty() or int(counts[key]) > int(counts[best]) \
				or (int(counts[key]) == int(counts[best]) and key == fallback_key):
			best = key
	if int(counts[best]) < least:
		return fallback
	return first[best]


static func _motion_key(move: Transform3D) -> String:
	var out := PackedStringArray()
	for v: Vector3 in [move.origin * 20.0, move.basis.x * 1000.0, move.basis.y * 1000.0,
			move.basis.z * 1000.0]:
		out.append("%d,%d,%d" % [roundi(v.x), roundi(v.y), roundi(v.z)])
	return " ".join(out)


## A target for each copy kept, and for each copy on the baseplate the file
## has not got.
func _make_targets(save: Save) -> void:
	var top := Target.new()
	top.copy = root
	top.colour = root.colour
	save.targets[""] = top
	save.target_of[""] = top
	save.order.append(top)
	for copy: Copy in _top_down():
		if copy == root or int(save.status[copy.chain]) != KEPT:
			continue
		var target := Target.new()
		target.path = save.path_now[copy.chain]
		target.copy = copy
		target.frame = (save.motion[copy.chain] as Transform3D) * copy.frame
		target.colour = copy.colour
		target.kind = Assemblies.definition(Assemblies.leaf(target.path))
		save.targets[target.path] = target
		save.target_of[copy.chain] = target
		save.order.append(target)
	for target: Target in save.order.duplicate():
		if target.copy != root:
			target.parent = _target_at(save, _home(save, Assemblies.parent_of(target.path)))
	for item: Variant in save.bricks:
		var brick: BrickWorld.Brick = item
		_target_at(save, _home(save, str(save.path_of[brick.id])))


func _target_at(save: Save, path: String) -> Target:
	if save.targets.has(path):
		return save.targets[path]
	var target := Target.new()
	target.path = path
	target.kind = Assemblies.definition(Assemblies.leaf(path))
	target.parent = _target_at(save, _home(save, Assemblies.parent_of(path)))
	target.frame = target.parent.frame
	target.colour = target.parent.colour
	save.targets[path] = target
	save.order.append(target)
	save.reshaped = true
	return target


## Each line of the file's copies given the target it is written in: in
## place where its part or copy is where the file had it, else moved there
## with the lines bound to it; and each new part its target.
func _assign(save: Save) -> void:
	var count: int = 0
	for copy: Copy in _top_down():
		var here: Target = save.target_of.get(copy.chain)
		var state: int = int(save.status[copy.chain])
		for read: Read in copy.reads:
			count += 1
			var brick: BrickWorld.Brick = save.by_origin.get(read.origin)
			if read.fixed:
				if here != null:
					var kept := Item.new()
					kept.read = read
					kept.line = read.line
					kept.text = lines[read.line]
					here.inplace[read.line] = kept
				continue
			if brick != null:
				var item := _part_item(save, read, brick)
				item.order = count
				var to: Target = save.targets[_home(save, str(save.path_of[brick.id]))]
				item.within = _within(str(save.path_of[brick.id]), to.path)
				if to == here:
					here.inplace[read.line] = item
				else:
					_move_in(save, item, to, copy)
			elif save.waiting.has(read.origin) or not read.shown:
				var held := Item.new()
				held.read = read
				held.line = read.line
				held.part_id = read.part_id
				held.colour = read.colour
				held.order = count
				if here != null:
					held.text = lines[read.line]
					held.within = _held_within(save, read, here)
					here.inplace[read.line] = held
				elif state == DISSOLVED or state == BUILT_IN:
					var to: Target = _settle(save, copy)
					if to != null:
						held.at = (save.motion[copy.chain] as Transform3D) * read.at
						held.within = _held_within(save, read, to)
						_move_in(save, held, to, copy)
		for child: Copy in copy.children:
			var child_state: int = int(save.status[child.chain])
			if child_state == KEPT:
				var target: Target = save.target_of[child.chain]
				var item := Item.new()
				item.child = target
				item.line = child.line
				item.order = count
				item.step = int(save.steps_now.get(target.path, -1)) if save.stepped else -1
				item.within = _within(Assemblies.parent_of(target.path), target.parent.path)
				item.copy_meta = _says_copy(child.line)
				target.placed = item
				if target.parent == here:
					here.inplace[child.line] = item
				else:
					_move_in(save, item, target.parent, copy)
			elif child_state == DISSOLVED or child_state == BUILT_IN:
				if here != null:
					save.carried[child.chain] = _run_text(child.line)
					save.anchors[child.chain] = [here, child.line]
				elif save.anchors.has(copy.chain):
					save.anchors[child.chain] = save.anchors[copy.chain]
	for item: Variant in save.bricks:
		var brick: BrickWorld.Brick = item
		if save.by_origin.get(brick.origin) == brick:
			continue
		count += 1
		var made := Item.new()
		made.brick = brick
		made.at = save.at_of[brick.id]
		made.part_id = brick.part_id
		made.colour = brick.color_code
		made.step = brick.step if save.stepped else -1
		made.order = count
		var to: Target = save.targets[_home(save, str(save.path_of[brick.id]))]
		made.within = _within(str(save.path_of[brick.id]), to.path)
		to.incoming.append(made)


func _part_item(save: Save, read: Read, brick: BrickWorld.Brick) -> Item:
	var item := Item.new()
	item.read = read
	item.brick = brick
	item.line = read.line
	item.at = save.at_of[brick.id]
	item.part_id = brick.part_id
	item.colour = brick.color_code
	item.step = brick.step if save.stepped else -1
	return item


## [param item] of [param from]'s lines written in [param to]: with the
## lines bound to it, and those of the line that placed its copy where that
## copy was ungrouped or built in its parent's steps, at that line's place.
func _move_in(save: Save, item: Item, to: Target, from: Copy) -> void:
	if item.line >= 0 and item.line < lines.size():
		item.run = _run_text(item.line)
	if save.carried.has(from.chain):
		var run: PackedStringArray = save.carried[from.chain]
		run.append_array(item.run)
		item.run = run
		save.carried.erase(from.chain)
	if save.anchors.has(from.chain) and save.anchors[from.chain][0] == to:
		item.anchor = int(save.anchors[from.chain][1])
	if item.child != null:
		save.reshaped = true
	to.incoming.append(item)


## Where the lines of a copy ungrouped or built in its parent's steps go
## that are no part on the baseplate (on their way, or not shown).
func _settle(save: Save, copy: Copy) -> Target:
	var state: int = int(save.status.get(copy.chain, DEAD))
	if state == BUILT_IN:
		return save.targets.get(_home(save, str(save.path_now[copy.chain])))
	if state == KEPT:
		return save.target_of.get(copy.chain)
	if state == DISSOLVED and copy.parent != null:
		return _settle(save, copy.parent)
	return null


## The copy within [param target] a part not on the baseplate is part of:
## where the copy it was read in is now.
func _held_within(save: Save, read: Read, target: Target) -> String:
	var chain: String = str(unit_chains.get(read.unit, ""))
	var path: String = str(save.pseudo_now.get(chain, save.path_now.get(read.copy.chain, "")))
	if path.is_empty() or not (path == target.path or target.path.is_empty()
			or path.begins_with(target.path + "/")):
		return ""
	return _within(path, target.path)


## Whether the lines bound to line [param n] say which copy it places.
func _says_copy(n: int) -> bool:
	for k: int in range(run_from[n], n):
		if _is_copy_meta(lines[k]):
			return true
	return false


## Each copy the file has not got whose parts are all new, placed as what it
## is a copy of: a copy of another, by that one's section.
func _fit_new(save: Save) -> void:
	for target: Target in save.order:
		if target.copy != null or target.skip or not _all_new(save, target):
			continue
		var mine: Array = _parts_under(save, target.path)
		for other: Target in save.order:
			if other == target or other.kind != target.kind or other.skip \
					or (other.copy == null and other.like == null):
				continue
			var fit: Variant = _fit(mine, _parts_under(save, other.path))
			if fit != null:
				target.like = other
				target.frame = (fit as Transform3D) * other.frame
				target.colour = other.colour
				break
		if target.like != null:
			for other: Target in save.order:
				if other.path.begins_with(target.path + "/"):
					other.skip = true


## Whether nothing under [param target] was read from the file.
func _all_new(save: Save, target: Target) -> bool:
	for path: String in save.under:
		if path == target.path or path.begins_with(target.path + "/"):
			for item: Variant in save.under[path]:
				if save.by_origin.get((item as BrickWorld.Brick).origin) == item:
					return false
	for chain: String in save.path_now:
		var path: String = save.path_now[chain]
		if path == target.path or path.begins_with(target.path + "/"):
			return false
	return true


## [part, colour, place] of each part at or under [param path].
func _parts_under(save: Save, path: String) -> Array:
	var out: Array = []
	for at: String in save.under:
		if at == path or path.is_empty() or at.begins_with(path + "/"):
			for item: Variant in save.under[at]:
				var brick: BrickWorld.Brick = item
				out.append([brick.part_id, brick.color_code, save.at_of[brick.id]])
	return out


## The move that puts [param theirs] where [param mine] are, part for part,
## or null.
static func _fit(mine: Array, theirs: Array) -> Variant:
	if mine.is_empty() or mine.size() != theirs.size():
		return null
	var by_kind: Dictionary = {}
	for entry: Variant in mine:
		var one: Array = entry
		var key: String = "%s|%d" % [one[0], one[1]]
		if not by_kind.has(key):
			by_kind[key] = []
		(by_kind[key] as Array).append(one)
	var first: Array = theirs[0]
	var tries: int = 0
	for entry: Variant in by_kind.get("%s|%d" % [first[0], first[1]], []):
		tries += 1
		if tries > 48:
			break
		# Rigid: a file's turns written to its precision (0.707) laid on a
		# part put down, whose are true, are no stretch of the copy's.
		var turn: Basis = ((entry[2] as Transform3D).basis
			* (first[2] as Transform3D).basis.inverse()).orthonormalized()
		var move := Transform3D(turn,
			(entry[2] as Transform3D).origin - turn * (first[2] as Transform3D).origin)
		var used: Dictionary = {}
		var all: bool = true
		for other: Variant in theirs:
			var them: Array = other
			var want: Transform3D = move * (them[2] as Transform3D)
			var found: bool = false
			for candidate: Variant in by_kind.get("%s|%d" % [them[0], them[1]], []):
				if not used.has(candidate) and _same(_true(want), _true((candidate as Array)[2])):
					used[candidate] = true
					found = true
					break
			if not found:
				all = false
				break
		if all:
			return move
	return null


## The line placing each copy the file has not got, in its parent: at its
## step, or, unstepped, where the first of its lines the parent had was.
func _place_new(save: Save) -> void:
	for target: Target in save.order:
		if target.copy != null or target.skip:
			continue
		var item := Item.new()
		item.child = target
		item.step = int(save.steps_now.get(target.path, -1)) if save.stepped else -1
		item.within = _within(Assemblies.parent_of(target.path), target.parent.path)
		item.order = 1 << 30
		if target.parent.copy != null:
			for moved: Item in target.incoming:
				if moved.read != null and moved.read.copy == target.parent.copy \
						and (item.anchor < 0 or moved.line < item.anchor):
					item.anchor = moved.line
		target.placed = item
		target.parent.incoming.append(item)
		save.reshaped = true


# -- written ----------------------------------------------------------------------


## The section of the copy [param target], as its lines now say it.
func _render(save: Save, target: Target) -> void:
	var copy: Copy = target.copy
	var span: Array = main_span if copy == root else sections.get(copy.section, [0, 0])
	var a: int = span[0]
	var b: int = span[1]
	var mine: Dictionary = {}
	for read: Read in copy.reads:
		mine[read.line] = true
	for child: Copy in copy.children:
		mine[child.line] = true
	var drop: Dictionary = {}
	for line: int in app_lines:
		if line >= a and line < b:
			drop[line] = true
	for line: int in mine:
		if not target.inplace.has(line):
			_drop(drop, line)
	var steps_here: PackedInt32Array = steps_in.get(a, PackedInt32Array())
	# Where each item goes: in place, at the end of its step, at an anchor.
	var at_end: Dictionary = {}      ## block -> [Item]
	var anchored: Dictionary = {}    ## line -> [Item]
	var after: Dictionary = {}       ## block -> [steps new after it]; -1 before the first
	var news: Dictionary = {}        ## new step -> [Item]
	var tail: Array[Item] = []
	var ranks: Dictionary = {}
	var by_rank: Dictionary = {}
	var lined: bool = save.stepped and steps_here.is_empty()
	var incoming: Array[Item] = target.incoming.duplicate()
	var numbered: Dictionary = {}    ## block -> true: a step the app numbers is in it
	if save.stepped and not lined:
		var map: Dictionary = _blocks_of(target, incoming, steps_here.size())
		for step: int in map:
			numbered[map[step]] = true
		# Over a copy of its keys: _take erases from it.
		for line: int in target.inplace.keys():
			var item: Item = target.inplace[line]
			if _votes(item) and int(map.get(item.step, -1)) != block[line]:
				_take(save, target, item, drop)
				incoming.append(item)
		for item: Item in incoming:
			if item.step < 0:
				_put(anchored if item.anchor >= 0 else null, item, tail)
			elif map.has(item.step):
				var to: int = map[item.step]
				if item.anchor >= 0 and block[item.anchor] == to:
					_put(anchored, item, tail)
				else:
					_add_to(at_end, to, item)
			else:
				_add_to(news, item.step, item)
		# In step order: news fills in the order its items came.
		var new_steps: Array = news.keys()
		new_steps.sort()
		for step: int in new_steps:
			var last: int = -1
			for known: int in map:
				if known < step:
					last = maxi(last, int(map[known]))
			_add_to(after, last, step)
	elif lined:
		var kept: Dictionary = _longest_run(target)
		for line: int in target.inplace.keys():
			var item: Item = target.inplace[line]
			if _votes(item) and not kept.has(line):
				_take(save, target, item, drop)
				incoming.append(item)
		var steps: Dictionary = {}
		for item: Item in incoming:
			if item.step >= 0:
				steps[item.step] = true
		for line: int in target.inplace:
			var item: Item = target.inplace[line]
			if _votes(item) and not drop.has(line):
				steps[item.step] = true
		var sorted: Array = steps.keys()
		sorted.sort()
		for n: int in sorted.size():
			ranks[sorted[n]] = n
		for item: Item in incoming:
			if item.step < 0:
				tail.append(item)
			else:
				_add_to(by_rank, int(ranks[item.step]), item)
	else:
		for item: Item in incoming:
			_put(anchored if item.anchor >= 0 else null, item, tail)
	for key: Variant in anchored:
		(anchored[key] as Array).sort_custom(_sooner)
	for key: Variant in at_end:
		(at_end[key] as Array).sort_custom(_sooner)
	for key: Variant in by_rank:
		(by_rank[key] as Array).sort_custom(_sooner)
	for key: Variant in news:
		(news[key] as Array).sort_custom(_sooner)
	tail.sort_custom(_sooner)
	# The end of each block: after its last line that stays; and a block
	# a step edit emptied loses the STEP line ending it (or, ended by a
	# ROTSTEP, the one ending the step before), unless the app still
	# numbers a step there (a step whose parts were deleted keeps its
	# number, and its page settings stay keyed by it).
	var last_in: Dictionary = {}
	var last_kept: int = -1
	var first_kept: int = -1
	var had: Dictionary = {}
	for line: int in mine:
		if line >= a and line < b:
			had[block[line]] = true
	for line: int in target.inplace:
		if not drop.has(line) and line >= a and line < b:
			last_in[block[line]] = maxi(int(last_in.get(block[line], -1)), line)
			last_kept = maxi(last_kept, line)
			if _votes(target.inplace[line] as Item) and (first_kept < 0 or line < first_kept):
				first_kept = line
	var end: int = b
	while end > a + 1 and (lines[end - 1].strip_edges().is_empty()
			or _keyword(lines[end - 1]) == "NOFILE"):
		end -= 1
	var ends_at: Dictionary = {}     ## line -> [block] whose items go in before it
	for blk: int in steps_here.size() + 1:
		var at: int = int(last_in[blk]) + 1 if last_in.has(blk) \
			else (steps_here[blk] if blk < steps_here.size() else end)
		_add_to(ends_at, at, blk)
		var used: bool = last_in.has(blk) or at_end.has(blk) or numbered.has(blk)
		for line: Variant in anchored:
			used = used or block[int(line)] == blk
		if save.stepped and had.has(blk) and not used:
			var gone: int = steps_here[blk] if blk < steps_here.size() \
				else (steps_here[blk - 1] if blk > 0 else -1)
			# Ended by a ROTSTEP, which turns the step after it: the STEP
			# ending the step before goes, and the ROTSTEP ends that one.
			if gone >= 0 and _keyword(lines[gone]) == "ROTSTEP" and blk < steps_here.size():
				var k: int = blk - 1
				while k >= 0 and drop.has(steps_here[k]):
					k -= 1
				gone = steps_here[k] if k >= 0 else -1
			if gone >= 0 and _keyword(lines[gone]) == "STEP":
				drop[gone] = true
				save.reshaped = true
	var tail_at: int = last_kept + 1 if last_kept >= 0 else end
	var first_at: int = run_from[first_kept] if first_kept >= 0 else end
	# Each line placed: by_start says which item a line begins the run of.
	var by_start: Dictionary = {}
	for line: int in target.inplace:
		if not drop.has(line):
			by_start[run_from[line]] = line
	save.within = ""
	var out: Array = []
	var rank: int = 0
	for n: int in range(a, b + 1):
		if anchored.has(n):
			for item: Item in anchored[n]:
				_emit(save, out, item, target)
		if ends_at.has(n):
			for blk: int in ends_at[n]:
				for item: Item in at_end.get(blk, []):
					_emit(save, out, item, target)
				if blk == steps_here.size():
					for step: int in after.get(blk, []):
						out.append("0 STEP")
						save.within = ""
						for item: Item in news[step]:
							_emit(save, out, item, target)
		if n == first_at and after.has(-1):
			for step: int in after[-1]:
				for item: Item in news[step]:
					_emit(save, out, item, target)
				out.append("0 STEP")
				save.within = ""
		if lined and n == tail_at:
			while by_rank.has(rank) or rank < ranks.size() - 1:
				for item: Item in by_rank.get(rank, []):
					_emit(save, out, item, target)
				by_rank.erase(rank)
				if ranks.size() - 1 > rank:
					out.append("0 STEP")
					save.within = ""
				rank += 1
		if n == tail_at:
			for item: Item in tail:
				_emit(save, out, item, target)
		if n == b:
			break
		# Before the drop: a run may begin at an app line, written again here.
		if by_start.has(n):
			var item: Item = target.inplace[by_start[n]]
			if lined and _votes(item):
				while rank < int(ranks[item.step]):
					for moved: Item in by_rank.get(rank, []):
						_emit(save, out, moved, target)
					by_rank.erase(rank)
					out.append("0 STEP")
					save.within = ""
					rank += 1
			_said_within(save, out, item.within)
		if drop.has(n):
			# A STEP line gone with the step after it, emptied: the steps
			# new after its own still go in here, each after a STEP line.
			var ended: int = steps_here.find(n) if _is_step(lines[n]) else -1
			for step: int in after.get(ended, []) if ended >= 0 else []:
				out.append("0 STEP")
				save.within = ""
				for item: Item in news[step]:
					_emit(save, out, item, target)
			continue
		if n == a:
			target.file_at = out.size()
		if n == int(titles.get(a, -1)):
			target.title_at = out.size()
		if target.name_at < 0 and _keyword(lines[n]) == "NAME:":
			target.name_at = out.size()
		if target.inplace.has(n):
			_emit_line(save, out, target.inplace[n], target)
			continue
		out.append(lines[n])
		if _is_step(lines[n]):
			save.within = ""
			var blk: int = steps_here.find(n)
			for step: int in after.get(blk, []):
				for item: Item in news[step]:
					_emit(save, out, item, target)
				out.append("0 STEP")
				save.within = ""
	target.entries = out


## Whether [param item]'s step says where it goes: a part or copy with a
## step, not a line the app cannot place.
static func _votes(item: Item) -> bool:
	return item.step >= 0 and (item.brick != null or item.child != null)


static func _sooner(a: Item, b: Item) -> bool:
	if a.anchor != b.anchor:
		return a.anchor < b.anchor
	return a.order < b.order


static func _add_to(table: Dictionary, key: Variant, value: Variant) -> void:
	if not table.has(key):
		table[key] = []
	(table[key] as Array).append(value)


static func _put(anchored: Variant, item: Item, tail: Array[Item]) -> void:
	if anchored == null:
		tail.append(item)
	else:
		_add_to(anchored as Dictionary, item.anchor, item)


## Line [param line] out, with the lines bound to it.
func _drop(drop: Dictionary, line: int) -> void:
	for k: int in range(run_from[line], line + 1):
		drop[k] = true


## [param item] taken from its place to go at the end of its step, its
## bound lines with it.
func _take(save: Save, target: Target, item: Item, drop: Dictionary) -> void:
	item.run = _run_text(item.line)
	item.order = item.line
	_drop(drop, item.line)
	target.inplace.erase(item.line)
	if item.child != null:
		save.reshaped = true


## Each step of the copy's items -> the block of its section it is written
## in: the block most of them are in, each after the one before. A step
## none of them stays in has the block in its place where as many steps lie
## between the steps round it as blocks between theirs (an author's empty
## page a part is moved onto, a step a part is put in whose parts went):
## the app numbers every step, an empty one too (AuthorSteps._tidy). Else
## it is a new one, and has none. As many steps as blocks, each is its own
## block where that keeps as many parts in place. The app's empty steps
## are in the map too, so the block a step is numbered in keeps its STEP
## line. [param ended]: the section's STEP lines.
func _blocks_of(target: Target, incoming: Array[Item], ended: int) -> Dictionary:
	var votes: Dictionary = {}
	for line: int in target.inplace:
		var item: Item = target.inplace[line]
		if _votes(item):
			if not votes.has(item.step):
				votes[item.step] = {}
			var counted: Dictionary = votes[item.step]
			counted[block[line]] = int(counted.get(block[line], 0)) + 1
	var steps: Dictionary = votes.duplicate()
	for item: Item in incoming:
		if item.step >= 0:
			steps[item.step] = true
	var sorted: Array = steps.keys()
	sorted.sort()
	var map: Dictionary = {}
	var last: int = -1
	for step: int in sorted:
		var best: int = -1
		var most: int = 0
		var counted: Dictionary = votes.get(step, {})
		for blk: int in counted:
			if blk > last and (int(counted[blk]) > most
					or (int(counted[blk]) == most and blk < best)):
				best = blk
				most = int(counted[blk])
		if best >= 0:
			map[step] = best
			last = best
	if sorted.is_empty():
		return map
	# The last block a part is in: after the last STEP line only where the
	# section has parts there.
	var top: int = ended - 1
	for line: int in target.inplace:
		top = maxi(top, block[line])
	for read: Read in target.copy.reads:
		top = maxi(top, block[read.line])
	for child: Copy in target.copy.children:
		top = maxi(top, block[child.line])
	# As many steps as blocks: none made or taken out, so each in its own
	# place, unless that keeps fewer parts where they are. A part moved
	# back onto an author's empty page voted its old block for the page.
	if int(sorted[sorted.size() - 1]) == top:
		var kept: int = 0
		var placed: int = 0
		for step: int in sorted:
			var counted: Dictionary = votes.get(step, {})
			placed += int(counted.get(step, 0))
			if map.has(step):
				kept += int(counted.get(map[step], 0))
		if placed >= kept:
			map = {}
			for step: int in top + 1:
				map[step] = step
			return map
	var known: Array = map.keys()
	known.sort()
	for step: int in int(sorted[sorted.size() - 1]) + 1:
		if map.has(step):
			continue
		var below: Array = [-1, -1]
		var above: Array = [int(sorted[sorted.size() - 1]) + 1, top + 1]
		for at: int in known:
			if at < step:
				below = [at, map[at]]
			elif at > step:
				above = [at, map[at]]
				break
		if int(above[0]) - int(below[0]) == int(above[1]) - int(below[1]):
			map[step] = int(below[1]) + step - int(below[0])
	return map


## The lines of [param target]'s items that stay where they are in a
## section with no STEP lines, given steps (line -> true): the longest run
## of them in an order of their steps (the rest go at the end of theirs).
func _longest_run(target: Target) -> Dictionary:
	var lines_in: Array = []
	for line: int in target.inplace:
		if _votes(target.inplace[line] as Item):
			lines_in.append(line)
	lines_in.sort()
	var tails: Array = []       ## length -> index into lines_in of its smallest end
	var before: Array = []
	for n: int in lines_in.size():
		var step: int = (target.inplace[lines_in[n]] as Item).step
		var low: int = 0
		var high: int = tails.size()
		while low < high:
			var middle: int = (low + high) / 2
			if (target.inplace[lines_in[tails[middle]]] as Item).step <= step:
				low = middle + 1
			else:
				high = middle
		before.append(tails[low - 1] if low > 0 else -1)
		if low == tails.size():
			tails.append(n)
		else:
			tails[low] = n
	var out: Dictionary = {}
	var at: int = tails[tails.size() - 1] if not tails.is_empty() else -1
	while at >= 0:
		out[lines_in[at]] = true
		at = before[at]
	return out


## An IN_META line, where the copy the next lines are of is another.
static func _said_within(save: Save, out: Array, within: String) -> void:
	if within != save.within:
		out.append(_in_line(within))
		save.within = within


## [param item] written where it goes, with the lines bound to it.
func _emit(save: Save, out: Array, item: Item, target: Target) -> void:
	_said_within(save, out, item.within)
	out.append_array(item.run)
	_emit_line(save, out, item, target)


func _emit_line(save: Save, out: Array, item: Item, target: Target) -> void:
	if item.child != null:
		_ref_body(item, target)
		out.append(item)
		return
	out.append(_part_text(save, item, target))


## A part's line in [param target]: as it was where that says the same, or
## its colour and numbers written again.
func _part_text(save: Save, item: Item, target: Target) -> String:
	if not item.text.is_empty():
		return item.text
	var read: Read = item.read
	var original: String = lines[read.line] if read != null else ""
	if read != null and read.copy == target.copy and item.part_id == read.part_id \
			and item.colour == read.colour \
			and _same(item.at, (save.motion[read.copy.chain] as Transform3D) * read.at):
		return original
	if not original.is_empty() and _reproduces(save, original, target.frame, target.colour, item):
		return original
	return _said(save, original, item, target.frame, target.colour)


## Whether [param line], read in [param frame] where colour 16 is
## [param inherit], is [param item] where it is, as LdrModel and ModelStore
## read it (studio_part, Assemblies.unmirror, PartLibrary.resolve, current
## colour).
func _reproduces(save: Save, line: String, frame: Transform3D, inherit: int, item: Item) -> bool:
	var words: PackedStringArray = _words(line)
	if words.size() < 15 or words[0] != "1":
		return false
	var colour: int = LdrModel._colour(words[1])
	if colour == 16:
		colour = inherit
	var numbers := PackedFloat64Array()
	for n: int in range(2, 14):
		if not words[n].is_valid_float():
			return false
		numbers.append(words[n].to_float())
	var local: Transform3D = LdrModel.to_transform(numbers)
	var part: String = _part_of(" ".join(words.slice(14)))
	var library: PartLibrary = save.library
	if library != null:
		part = ModelStore.studio_part(part, library)
	var at: Transform3D = frame * local
	if frame.basis.determinant() < 0.0:
		var image: Dictionary = Mirror.image(library, part, local, 0, 0.0) if library != null \
			else Mirror.reflected(null, null, local, 0, 0.0)
		part = str(image.get("part", part))
		at = frame * LdrModel.REFLECT_X * (image["at"] as Transform3D)
		at = Builder._tidy(at, BrickLattice.is_square_to_grid(at.basis))
	if library != null:
		var real: String = library.resolve(part)
		if real != part:
			at = at * library.moved_by(part)
			part = real
		var fixed: int = library.current_colour(part)
		if fixed >= 0:
			part = library.current(part)
			colour = fixed
	return part == item.part_id and colour == item.colour and _same(at, item.at)


## [param item]'s line in [param frame] where colour 16 is [param inherit]:
## [param original]'s part number where it is still this part (a retired
## number placed where its stub puts the part it became), its colour where
## it is still that one, a 16 only where it is still the colour a 16 is.
func _said(save: Save, original: String, item: Item, frame: Transform3D, inherit: int) -> String:
	var library: PartLibrary = save.library
	var words: PackedStringArray = _words(original)
	var reflected: bool = frame.basis.determinant() < 0.0
	var token: String = ""
	var by := Transform3D.IDENTITY
	# A mirrored copy's part is turned back by the two shapes the open
	# turned it by (Assemblies.unmirror): the file's and the one put down.
	var file_part: String = ""
	var put_part: String = item.part_id
	if words.size() >= 15 and words[0] == "1" and library != null:
		var reference: String = " ".join(words.slice(14))
		var part: String = ModelStore.studio_part(_part_of(reference), library)
		var said_part: String = part
		if reflected:
			var other: String = Mirror.counterpart(library, part)
			if not other.is_empty() and library.parts.has(other):
				part = other
		var real: String = library.resolve(part)
		var now: String = real
		var fixed: int = library.current_colour(real)
		if fixed >= 0:
			now = library.current(real)
		if now == item.part_id and (fixed < 0 or fixed == item.colour):
			token = reference
			file_part = said_part
			put_part = part
			if real != part:
				by = library.moved_by(part)
	if token.is_empty():
		var id: String = item.part_id
		if reflected and library != null:
			var other: String = Mirror.counterpart(library, id)
			if not other.is_empty() and library.parts.has(other):
				id = other
		token = id + ".dat"
		file_part = id
		save.new_ids[id] = true
	var want: Transform3D = item.at * by.affine_inverse()
	var local: Transform3D = frame.affine_inverse() * want
	if reflected:
		var put: Lbm.PartMesh = library.mesh_for(put_part) if library != null else null
		var file: Lbm.PartMesh = library.mesh_for(file_part) if library != null else null
		local = Mirror.reflected(put, file, (frame * LdrModel.REFLECT_X).affine_inverse() * want,
			0, 0.0)["at"]
	var colour: String = _colour_token(item.colour)
	if item.read != null and words.size() >= 15 and item.colour == item.read.colour \
			and (words[1] != "16" or inherit == item.colour):
		colour = words[1]
	return "1 %s %s %s" % [colour, LdrModel._line_numbers(local), token]


static func _part_of(reference: String) -> String:
	var id: String = reference.strip_edges().replace("\\", "/").to_lower().get_file()
	if id.ends_with(".dat") or id.ends_with(".ldr"):
		id = id.substr(0, id.length() - 4)
	return id


## A placing line's place and colour, or, where its line still says them,
## that line.
func _ref_body(item: Item, parent: Target) -> void:
	var child: Target = item.child
	item.text = ""
	if item.line >= 0:
		var words: PackedStringArray = _words(lines[item.line])
		if words.size() >= 15 and words[0] == "1":
			var numbers := PackedFloat64Array()
			var valid: bool = true
			for n: int in range(2, 14):
				valid = valid and words[n].is_valid_float()
				numbers.append(words[n].to_float())
			var colour: int = LdrModel._colour(words[1])
			if valid and _same(parent.frame * LdrModel.to_transform(numbers), child.frame) \
					and (colour == child.colour or (colour == 16 and parent.colour == child.colour)):
				item.text = lines[item.line]
				return
	var token: String = "16" if child.colour == parent.colour or child.colour == 16 \
		else _colour_token(child.colour)
	item.body = "1 %s %s" % [token, LdrModel._line_numbers(parent.frame.affine_inverse() * child.frame)]


## A new copy's section: its header, then its lines in their steps.
func _render_new(save: Save, target: Target) -> void:
	var out: Array = ["0 FILE ?", "0 " + target.kind, "0 Name: ?"]
	target.file_at = 0
	target.title_at = 1
	target.name_at = 2
	var items: Array[Item] = target.incoming.duplicate()
	items.sort_custom(func(a: Item, b: Item) -> bool:
		if a.step != b.step:
			return a.step >= 0 and (b.step < 0 or a.step < b.step)
		return a.order < b.order)
	save.within = ""
	var step: int = -2
	for item: Item in items:
		if save.stepped and step != -2 and item.step != step and item.step >= 0:
			out.append("0 STEP")
			save.within = ""
		step = item.step
		_emit(save, out, item, target)
	if nofile:
		out.append("0 NOFILE")
	target.entries = out


# -- named and put together ----------------------------------------------------


## [param target]'s lines as one text, each placing line by what it places.
func _sig(target: Target) -> String:
	if not target.sig.is_empty():
		return target.sig
	var parts := PackedStringArray()
	for entry: Variant in target.entries:
		if entry is Item:
			var item: Item = entry
			parts.append("\u0001%s %s" % [item.text if not item.text.is_empty() else item.body,
				_ref_key(item.child)])
		else:
			parts.append(str(entry))
	target.sig = "\n".join(parts)
	return target.sig


func _ref_key(child: Target) -> String:
	while child.like != null:
		child = child.like
	if child.digest.is_empty():
		child.digest = (child.kind + "\n" + _sig(child)).md5_text()
	return child.digest


## The copies written alike, together under one name: a section's own for
## those written as it was, or as most of its copies are; a name of its own
## (" 2") for each other way it is written now.
func _group(save: Save) -> void:
	for target: Target in save.order:
		if target.skip or target.like != null:
			continue
		var key: String = "%s\n%s\n%s" % [target.copy.section if target.copy != null else NONE,
			target.kind, _ref_key(target) if target.copy != root else "model"]
		var group: Group = save.groups.get(key)
		if group == null:
			group = Group.new()
			group.section = target.copy.section if target.copy != null else NONE
			group.kind = target.kind
			save.groups[key] = group
			if target.copy == null:
				save.news.append(group)
			elif target.copy != root:
				_add_to(save.by_section, group.section, group)
		group.members.append(target)
		target.group = group
	for key: String in sections:
		save.names[key] = true
	for section: String in save.by_section:
		var kept: Array = save.by_section[section]
		var span: Array = sections[section]
		var own: String = _file_name(int(span[0]))
		var kind: String = _kind_of(section)
		var first: Group = null
		for item: Variant in kept:
			var group: Group = item
			if group.kind == kind and _as_it_was(group.members[0], span):
				first = group
				break
		if first == null:
			for item: Variant in kept:
				var group: Group = item
				if first == null or (group.kind == kind and first.kind != kind):
					first = group
		for item: Variant in kept:
			var group: Group = item
			group.retitle = group.kind != kind
			group.title = group.kind
			if group == first:
				group.name = own
				continue
			group.fork = true
			group.name = _free_name(save, own)
			if group.kind == kind:
				group.title = _free_title(save, kind)
			group.retitle = true
			save.reshaped = true
		if first.retitle:
			save.reshaped = true
	var prefix: String = _prefix()
	for group: Group in save.news:
		group.name = _free_name(save, prefix + group.kind + ".ldr", false)
		group.title = group.kind
	if main_key.is_empty():
		save.main_name = _free_name(save, ((own_title if not own_title.is_empty()
			else "model").to_snake_case()) + ".ldr", false)
	_gone_sections(save)
	_yield_titles(save)


## Each sub-model placed by nothing now and written as it was, titled as a
## copy is written now (one renamed as the sub-model taken apart was),
## titled anew: two sections of one title open as neither
## (LdrModel._assembly_names), so the copy would open under another name.
func _yield_titles(save: Save) -> void:
	var now: Dictionary = {}
	for group: Variant in save.groups.values():
		now[(group as Group).title] = true
	for group: Group in save.news:
		now[group.title] = true
	for key: String in sections:
		if key == main_key or save.by_section.has(key) or save.gone.has(key):
			continue
		var title: String = _section_title(key)
		if not title.is_empty() and now.has(title):
			save.retitled[key] = _free_title(save, title)


## The title the reader gives the section [param key] from its own line.
## Each sub-model the model placed whose every copy is gone, no part of it
## or of a copy in it still there (every part taken away, or its only copy
## taken off): it goes with its parts, its block and its end, as another
## program's list of sub-models would show it empty or with parts the
## person took away (fidelity). One Ungrouped keeps its parts, so its text
## stays, placed by nothing; one built in its parent's steps is still a
## copy; a flexible part's stays as its part's own; and one a sub-model
## written as it was still places stays.
func _gone_sections(save: Save) -> void:
	var held: Dictionary = {}
	var copied: Dictionary = {}
	for copy: Copy in _top_down():
		if copy == root:
			continue
		copied[copy.section] = true
		if held.has(copy.section):
			continue
		var state: int = int(save.status.get(copy.chain, DEAD))
		if state == KEPT or state == BUILT_IN or _holds(save, copy):
			held[copy.section] = true
	for key: String in copied:
		if key != main_key and not held.has(key) and not flexible.has(key) \
				and not save.by_section.has(key):
			save.gone[key] = true
	var more: bool = not save.gone.is_empty()
	while more:
		more = false
		for key: String in sections:
			if key == main_key or save.by_section.has(key) or save.gone.has(key):
				continue
			var span: Array = sections[key]
			for n: int in range(int(span[0]), int(span[1])):
				var words: PackedStringArray = _words(lines[n])
				if words.size() >= 15 and words[0] == "1" \
						and save.gone.erase(LdrModel._key(" ".join(words.slice(14)))):
					more = true


## Whether a part of [param copy] or of a copy in it is still there, or
## still loading.
func _holds(save: Save, copy: Copy) -> bool:
	var todo: Array[Copy] = _below(copy)
	todo.append(copy)
	for each: Copy in todo:
		for read: Read in each.reads:
			if save.waiting.has(read.origin) or (read.shown and save.by_origin.has(read.origin)):
				return true
	return false


func _section_title(key: String) -> String:
	var at: int = int(titles.get(int((sections[key] as Array)[0]), -1))
	if at < 0:
		return ""
	return " ".join(_words(lines[at]).slice(1)).strip_edges() \
		.replace("/", "-").replace("#", "").strip_edges()


## The sub-model a reader called the section [param key]: what its copies
## were called when the file was opened.
func _kind_of(key: String) -> String:
	for copy: Variant in copies.values():
		if (copy as Copy).section == key and copy != root:
			return Assemblies.definition(Assemblies.leaf((copy as Copy).path))
	return key


func _as_it_was(target: Target, span: Array) -> bool:
	var entries: Array = target.entries
	if entries.size() != int(span[1]) - int(span[0]):
		return false
	for n: int in entries.size():
		var entry: Variant = entries[n]
		if entry is Item:
			if (entry as Item).text != lines[int(span[0]) + n]:
				return false
		elif str(entry) != lines[int(span[0]) + n]:
			return false
	return true


## A section's name as its FILE line gives it.
func _file_name(start: int) -> String:
	var line: String = lines[start].strip_edges()
	var words: PackedStringArray = _words(line)
	if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "FILE":
		var at: int = line.findn("FILE") + 4
		return line.substr(at).strip_edges()
	return owner[start] + ".ldr"


## [param file_name], or "name 2.ldr", "name 3.ldr", whichever no section,
## part or name given this save has.
func _free_name(save: Save, file_name: String, numbered: bool = true) -> String:
	var stem: String = file_name
	var extension: String = ".ldr"
	for suffix: String in [".ldr", ".dat", ".mpd"]:
		if stem.to_lower().ends_with(suffix):
			extension = stem.right(suffix.length())
			stem = stem.left(stem.length() - suffix.length())
			break
	var n: int = 2 if numbered else 1
	while true:
		var name: String = "%s%s" % [stem, extension] if n == 1 else "%s %d%s" % [stem, n, extension]
		var key: String = LdrModel._key(name)
		if not save.names.has(key) and (save.library == null or not save.library.parts.has(key)):
			save.names[key] = true
			return name
		n += 1
	return ""


func _free_title(save: Save, kind: String) -> String:
	var taken: Dictionary = {}
	for copy: Variant in copies.values():
		taken[Assemblies.definition(Assemblies.leaf((copy as Copy).path))] = true
	for target: Target in save.order:
		taken[target.kind] = true
	for key: String in sections:
		taken[_section_title(key)] = true
	for title: Variant in save.retitled.values():
		taken[title] = true
	var n: int = 2
	while taken.has("%s %d" % [kind, n]):
		n += 1
	return "%s %d" % [kind, n]


## The "7140 - " every section's name begins with, where they all do.
func _prefix() -> String:
	var first: String = ""
	for key: String in sections:
		if key == main_key:
			continue
		var at: int = key.find(" - ")
		if at < 0:
			return ""
		if first.is_empty():
			first = key.substr(0, at + 3)
		elif not key.begins_with(first):
			return ""
	return first


## The whole file: each section as its copies are written, a copy written
## otherwise after it, new sections at the end.
func _assemble(save: Save) -> String:
	var out := PackedStringArray()
	save.placing = {}
	var top: Target = save.target_of[""]
	var made: PackedStringArray = _made_lines(save)
	var extra: bool = not save.news.is_empty() or not made.is_empty()
	for group: Variant in save.groups.values():
		extra = extra or (group as Group).fork
	if main_key.is_empty() and extra:
		out.append("0 FILE " + save.main_name)
	var at: int = 0
	for item: Variant in spans:
		var span: Array = item
		var key: String = span[0]
		var start: int = span[1]
		var end: int = span[2]
		for n: int in range(at, start):
			out.append(lines[n])
		at = end
		if start == int(main_span[0]):
			_put_entries(save, out, top, top.group)
			continue
		var groups: Array = save.by_section.get(key, [])
		if save.gone.has(key) and int((sections[key] as Array)[0]) == start:
			if end == lines.size() and lines[end - 1].is_empty():
				out.append("")
			continue
		if groups.is_empty() or int((sections[key] as Array)[0]) != start:
			var titled: int = int(titles.get(start, -1)) if save.retitled.has(key) \
				and int((sections[key] as Array)[0]) == start else -1
			for n: int in range(start, end):
				out.append("0 " + str(save.retitled.get(key, "")) if n == titled else lines[n])
			continue
		for group: Variant in groups:
			if not (group as Group).fork:
				_put_entries(save, out, (group as Group).members[0], group)
		for group: Variant in groups:
			if (group as Group).fork:
				_put_entries(save, out, (group as Group).members[0], group)
	for n: int in range(at, lines.size()):
		out.append(lines[n])
	var ended_line: bool = not out.is_empty() and out[out.size() - 1].is_empty()
	if ended_line and extra:
		out.remove_at(out.size() - 1)
	for group: Group in save.news:
		_put_entries(save, out, group.members[0], group)
	out.append_array(made)
	if ended_line and extra:
		out.append("")
	# A model given steps in a file of none: read with no STEP line, it
	# would open as a model of no steps, and its booklet as the app's.
	if save.stepped and not save.end_step and not Array(out).any(_is_step):
		save.end_step = true
		return _assemble(save)
	return "\n".join(out)


## The sources of the parts made here that a line written now names and the
## file does not carry (a skin pasted, a part from the element maker), as
## sections for its end: a file means nothing where its parts were not made.
## Until keeptext4 such a save wrote the model whole, to carry them.
func _made_lines(save: Save) -> PackedStringArray:
	var out := PackedStringArray()
	var done: Dictionary = {}
	for id: String in save.new_ids:
		var sources: Dictionary = save.made.get(id, {})
		for name: String in sources:
			var key: String = LdrModel._key(name)
			if sections.has(key) or done.has(key):
				continue
			done[key] = true
			var body: Variant = sources[name]
			if body is PackedByteArray:
				var encoded: String = Marshalls.raw_to_base64(body)
				out.append("0 !DATA " + name)
				for at: int in range(0, encoded.length(), 76):
					out.append("0 !: " + encoded.substr(at, 76))
				continue
			out.append("0 FILE " + name)
			out.append_array(str(body).replace("\r\n", "\n").strip_edges().split("\n"))
			if nofile:
				out.append("0 NOFILE")
	return out


## Whether the file has a section by [param part_id]'s name: a part it
## carries, which a line naming it finds there.
func carries(part_id: String) -> bool:
	return sections.has(LdrModel._key(part_id))


## Whether [param origin] is a line that places no part: a flexible part's
## skin, read from its sub-model's GENERATED line.
func drawn_at(origin: String) -> bool:
	var read: Read = reads.get(origin)
	return read != null and read.fixed


## [param target]'s lines into [param out], under [param group]'s name and
## title where they are another.
func _put_entries(save: Save, out: PackedStringArray, target: Target, group: Group) -> void:
	var renamed: bool = group != null and (group.fork or target.copy == null)
	var titled: bool = group != null and group.retitle
	var author_title: bool = target.title_at >= 0 and target.copy != null \
		and _keyword(str(target.entries[target.title_at])) == "AUTHOR:"
	var last: int = -1
	if save.end_step and target.copy == root:
		for n: int in target.entries.size():
			var entry: Variant = target.entries[n]
			if entry is Item or str(entry).strip_edges().begins_with("1 "):
				last = n
	for n: int in target.entries.size():
		var entry: Variant = target.entries[n]
		if entry is Item:
			var item: Item = entry
			var number: int = int(group.copy_numbers.get(n, 0)) if group != null else 0
			if number == 0 and item.copy_meta:
				number = Assemblies.copy_of(Assemblies.leaf(item.child.path))
			if number > 0:
				out.insert(out.size() - _bound_above(target.entries, n, item),
					LdrModel.COPY_META + " %d" % number)
			out.append(_ref_text(save, item))
			var paths: Array = []
			var members: Array = group.members if group != null else [target]
			for member: Variant in members:
				var entries: Array = (member as Target).entries
				if n < entries.size() and entries[n] is Item:
					paths.append((entries[n] as Item).child.path)
			save.placing[out.size() - 1] = [group if group != null else target, n, paths]
			if n == last:
				out.append("0 STEP")
			continue
		var line: String = str(entry)
		if n == target.file_at and renamed:
			line = "0 FILE " + group.name
		elif n == target.name_at and renamed:
			line = "0 Name: " + group.name
		elif n == target.title_at and titled and not author_title:
			line = "0 " + group.title
		out.append(line)
		if n == last:
			out.append("0 STEP")
		if n == target.file_at and titled and (target.title_at < 0 or author_title):
			out.append("0 " + group.title)


## How many of [param entries] right above entry [param n] are the lines
## bound to [param item]: its copy's number goes in above them, so that a
## line about the next part (LDCad's GROUP_NXT) stays right above it.
func _bound_above(entries: Array, n: int, item: Item) -> int:
	var run: PackedStringArray = item.run
	if run.is_empty() and item.line >= 0 and item.line < lines.size():
		run = _run_text(item.line)
	if run.size() > n:
		return 0
	for k: int in run.size():
		var entry: Variant = entries[n - run.size() + k]
		if entry is Item or str(entry) != run[k]:
			return 0
	return run.size()


## A placing line: as it was where it still says where its copy is, under
## the name its copy is written under now.
func _ref_text(save: Save, item: Item) -> String:
	var child: Target = item.child
	while child.like != null:
		child = child.like
	var name: String = ""
	if child.group != null:
		name = child.group.name
	if not item.text.is_empty():
		var words: PackedStringArray = _words(item.text)
		if LdrModel._key(" ".join(words.slice(14))) == LdrModel._key(name):
			return item.text
		return _with_reference(item.text, name)
	return item.body + " " + name


## [param text] read back as a reader reads it: where a copy comes back
## numbered otherwise than it is, its line says its number
## (LdrModel.COPY_META), and the text is put together again.
func _read_back(save: Save, text: String) -> String:
	if save.library == null:
		return text
	for _round: int in 3:
		var model: LdrModel = LdrModel.parse(text, "model")
		if model == null:
			return text
		model.flatten(save.library.parts)
		var read_at: Dictionary = {}
		for path: String in model.unit_lines:
			_add_to(read_at, int(model.unit_lines[path]), path)
		var changed: bool = false
		for line: int in save.placing:
			var entry: Array = save.placing[line]
			var meant: Array = entry[2]
			var got: Array = read_at.get(line, [])
			meant.sort()
			got.sort()
			if meant == got or meant.size() != 1 or not entry[0] is Group:
				continue
			var group: Group = entry[0]
			var number: int = Assemblies.copy_of(Assemblies.leaf(str(meant[0])))
			if int(group.copy_numbers.get(entry[1], 0)) != number:
				group.copy_numbers[entry[1]] = number
				changed = true
		if not changed:
			return text
		text = _assemble(save)
	return text


# -- the lines -----------------------------------------------------------------


## [param text], written for this file, with its line endings: CRLF for a
## file whose every line ended so. Its own lines keep theirs written into
## it, but the app's went in with a newline alone (ktreview, keeptext3).
func ended(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\n", "\r\n") if crlf else text


## What ends a line of [param text] before its "\n": "\r" in a CRLF file
## (Studio's, the LDraw library's), as its first line ends; else "". Given a
## text or its first line. Each line the app writes into someone else's file
## ends as this says: a meta writer that put its line in with "\n" alone left
## a CRLF file with its endings mixed (ktreview, keeptext3).
static func eol_of(text: String) -> String:
	var cut: int = text.find("\n")
	return "\r" if (text.left(cut) if cut >= 0 else text).ends_with("\r") else ""


## [param text_lines], a text split on "\n", with [param put] in before line
## [param at], each ending as the text's own lines do ([method eol_of]),
## joined again: how the app's own lines go into a model's text (ModelFloor,
## HiddenColours, CutShape, Motions, PinnedComments).
static func lines_put(text_lines: PackedStringArray, at: int, put: PackedStringArray) -> String:
	var eol: String = eol_of(text_lines[0] if not text_lines.is_empty() else "")
	var out: PackedStringArray = text_lines.slice(0, at)
	for line: String in put:
		out.append(line + eol)
	out.append_array(text_lines.slice(at))
	return "\n".join(out)


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


## Whether [param line] says, for another program, what the line after it
## is: LDCad's group of the next part, MLCad's group of the next and the
## part it hides, BFC's INVERTNEXT. For the app's own lines going into a
## file ([method before_run], ModelFloor); a save decides which lines are a
## part's by where they are ([method _run_of]).
static func _binds_next(line: String) -> bool:
	var words: PackedStringArray = _words(line)
	if words.size() < 3 or words[0] != "0":
		return false
	var said: String = (words[1] + " " + words[2]).to_upper()
	return said == "!LDCAD GROUP_NXT" or said == "MLCAD BTG" or said == "MLCAD HIDE" \
		or said == "BFC INVERTNEXT"


## [param at], or where the lines right above line [param at] of
## [param text_lines] that say what it is for another program begin
## ([method _binds_next]): where a line of the app's own goes that is to go
## before line [param at].
static func before_run(text_lines: PackedStringArray, at: int) -> int:
	while at > 0 and _binds_next(text_lines[at - 1]):
		at -= 1
	return at


## The copy an IN_META line names ("" for the section's own), or null for
## any other line: read as LdrModel.parse reads it.
static func _in_named(line: String) -> Variant:
	var words: PackedStringArray = _words(line)
	if words.size() < 3 or words[0] != "0" or words[1].to_upper() != "!BRICKWORKS" \
			or words[2] != LdrModel.IN_META.get_slice(" ", 2):
		return null
	var text: String = line.strip_edges()
	return text.substr(text.to_upper().find("!BRICKWORKS") + 11).strip_edges() \
		.substr(words[2].length()).strip_edges()


## The IN_META line naming [param within], or the bare one for the
## section's own.
static func _in_line(within: String) -> String:
	return LdrModel.IN_META + ("" if within.is_empty() else " " + within)


## Whether [param line] is this app's saying which copy the next reference
## is (LdrModel.COPY_META), as LdrModel.parse reads one.
static func _is_copy_meta(line: String) -> bool:
	var words: PackedStringArray = _words(line)
	return words.size() >= 4 and words[0] == "0" and words[1].to_upper() == "!BRICKWORKS" \
		and words[2] == LdrModel.COPY_META.get_slice(" ", 2)


## The app's own lines about the next, written again at every save.
static func _is_app_meta(line: String) -> bool:
	return _is_copy_meta(line) or _in_named(line) != null


static func _is_placing(line: String) -> bool:
	var words: PackedStringArray = _words(line)
	return words.size() >= 15 and words[0] == "1"


static func _colour_token(code: int) -> String:
	return "0x%07X" % code if LdrModel.is_direct_colour(code) else str(code)


static func _is_step(line: String) -> bool:
	var keyword: String = _keyword(line)
	return keyword == "STEP" or keyword == "ROTSTEP"


## A line's fields as LdrModel reads them (LdrModel._fields): split on any
## run of spaces, tabs and a "\r\n" file's carriage return (kt_tabs).
static func _words(line: String) -> PackedStringArray:
	return LdrModel._fields(line.strip_edges())


## The keyword of a line of type 0, upper case ("STEP", "FILE", "!LDCAD"),
## or "" for any other line.
static func _keyword(line: String) -> String:
	var words: PackedStringArray = _words(line)
	return words[1].to_upper() if words.size() >= 2 and words[0] == "0" else ""


## [param at] turned truly: a file's turns are written to its precision.
static func _true(at: Transform3D) -> Transform3D:
	return Transform3D(at.basis.orthonormalized(), at.origin)


static func _same(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > NEAR:
		return false
	for k: int in 3:
		if not (a.basis[k] - b.basis[k]).is_zero_approx() \
				and (a.basis[k] - b.basis[k]).length() > TURN:
			return false
	return true
