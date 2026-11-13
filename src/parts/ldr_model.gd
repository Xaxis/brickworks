## Reading and writing LDraw model files (.ldr, .mpd, .dat).
##
## This is the interchange format the whole brick CAD world speaks — LDView,
## LeoCAD, Studio, LDCad and every model anyone has ever published. Being
## able to open and save it is what stops this app being a walled garden.
##
## A model is the same line syntax as a part, but its type-1 references name
## parts rather than primitives:
##
##     1 <colour> x y z a b c d e f g h i 3001.dat
##
## with two meta lines that matter: [code]0 STEP[/code] divides the build
## into steps, and [code]0 FILE <name>[/code] starts a new sub-model inside
## a multi-part document (.mpd), where the first one listed is the model and
## the rest are its sub-assemblies.
##
## The axis change from LDraw's -Y-up space to ours is a conjugation, not a
## negation of the translation alone: a placement's orientation has to be
## flipped on both sides or every rotated part ends up mirrored. See
## [method to_transform].
class_name LdrModel
extends RefCounted

## Maps LDraw's space to the application's: +Y up, Z with it, so the pair
## is a 180 degree turn about X and handedness survives.
const FLIP := Vector3(1.0, -1.0, -1.0)


## One part placed in a model.
class Placement extends RefCounted:
	var part_id: String        ## without ".dat"
	var color_code: int
	var transform: Transform3D
	var step: int              ## which build step it belongs to, from 0
	## The sub-model of the document it was placed in at the top level,
	## by that sub-model's title: which assembly of the model it is.
	var group: String = ""
	## Which copy of which sub-model it came in, at every depth: a part of
	## the third window in the house is "House#1/Window#3". A document that
	## builds its window once and places it four times is saying what a
	## booklet says with a "4x" callout, and flattening it into the wall
	## threw that away. Empty for a part the model places itself. The
	## sub-assemblies by hand (Assemblies) are this same path.
	var unit: String = ""
	## Placed by a mirrored reference (a matrix that turns space inside
	## out, as LDraw allows): no part can be that, so whoever places it puts
	## the part's other hand where its reflection is (Assemblies.unmirror) —
	## ``frame`` with x reflected is the reference, ``local`` the part's own
	## place in its sub-model.
	var mirrored: bool = false
	var local: Transform3D = Transform3D.IDENTITY
	var frame: Transform3D = Transform3D.IDENTITY
	## The line of the file it was read from, counted from 0, or -1 for one
	## not read from a file: what a save writes back in place when nothing
	## about the part changed (SourceFile).
	var line: int = -1
	## For a reference to a sub-model, which copy of it this is, as the
	## file says (COPY_META); 0 where it does not.
	var copy: int = 0
	## The copy built in the steps of the sub-model it was read in that it
	## is part of, by its path within that sub-model ("tower#1"), as the
	## file says (IN_META); "" for the sub-model's own.
	var within: String = ""
	## Where in the file it came from, which no edit changes: the line of
	## every reference placing the copies round it, outermost first, and its
	## own line, joined by "/" ("12/40/7"), so each copy of a sub-model's
	## part has its own. "" for one not read from a file (SourceFile).
	var origin: String = ""
	## What its line names, its name from the 15th field on as the file has
	## it, compared as LDraw compares names ([method LdrModel._key]): the
	## sub-model of the file it places, where the file has a FILE section of
	## that name. "" for one not read from a file. Not [member part_id], which
	## is a part's number: "hssub.ldr.ldr" and "hssub.ldr" were one number,
	## and a reference to the first was looked for as the second, never found,
	## and drawn as a part nobody has (hscheck).
	var reference: String = ""
	## The brick it was put down as, once a part on its way came
	## (ModelStore.place_awaited); 0 before. A step edit made while it was on
	## its way gave it its step (AuthorSteps), and is undone on that brick.
	var landed: int = 0
	## For one of the parts not on the baseplate a paste put down
	## (ModelStore._held_put), the name BrickWorld.held_paths keeps where it
	## is by; "" for one read from a file, kept by the path it was read in.
	var held_key: String = ""

	func _init(id: String, color: int, at: Transform3D, in_step: int) -> void:
		part_id = id
		color_code = color
		transform = at
		step = in_step


## A model, or one sub-assembly of a multi-part document.
class SubModel extends RefCounted:
	var name: String
	## Its first line, which LDraw makes the description: "front-left
	## tower" where the file is front_left_tower.ldr.
	var title: String = ""
	var placements: Array[Placement] = []
	var step_count: int = 1
	## References this sub-model makes to other sub-models rather than to
	## parts, which the loader resolves by inlining.
	var unresolved: PackedStringArray = PackedStringArray()
	## Its lines of the file: its FILE line and the line after its last (its
	## NOFILE line in it where it has one); a file with no FILE line, all.
	var span := Vector2i(-1, -1)
	## Its header says it is one of a library's files and not a model: a
	## shortcut, a primitive ([method LdrModel.declares_library_file]). One
	## that says it is a part is no sub-model at all ([member
	## LdrModel.embedded_parts]); this one is read as the library's part of
	## its number where the library has one ([method LdrModel.sub_model_of]).
	var library_file: bool = false


var name: String = ""
var author: String = ""
var submodels: Dictionary = {}      ## String name -> SubModel
var main: SubModel = null
## Parts the file carries inside it, as LDraw's multi-part document spec
## allows: lowercase file name ("bw-b2x7x3.dat") -> the part's own text.
## A section is a part, not a sub-model, when its name ends in .dat or its
## header says it is one. Kept out of [member submodels], so a part is
## placed as a part and never inlined as though it were an assembly.
var embedded_parts: Dictionary = {}
## Every file the document carries that a part may be drawn from: its parts,
## and the subparts and primitives they use, which are not parts themselves
## (an `Unofficial_Primitive`, an `Unofficial_Subpart` under s\). By the name
## a reference gives, folder and all, lowercase, "/" for "\" (PartForge.
## normalise), and by its bare file name. Read as parts only, 1,401 parts
## that real sets' files carry could not be built — 10283's Technic pins,
## drawn from a friction rib the file carries as a primitive, and every
## printed part whose print is a subpart named "s\..." — and what stood on
## them floated.
var embedded_sources: Dictionary = {}
## Files the document carries as `0 !DATA <name>` sections (MPD spec rev.
## 2): base64 in `0 !:` lines, ended by the next FILE, NOFILE or !DATA.
## The pictures of a print drawn in the app, which its part's TEXMAP lines
## name. Lowercase file name -> the bytes.
var embedded_data: Dictionary = {}
## Whether the document divides its build into steps at all: it has a
## "0 STEP" (or "0 ROTSTEP") line somewhere.
var stepped: bool = false
## Whether it says its steps are its author's, written by Brickworks:
## see [method steps_are_authored].
var marked_authored: bool = false
## What [method flatten] found: the step each copy of a sub-model is
## placed in, within the sub-model that places it, by its unit path
## (Placement.unit) — "House#1/Window#3" -> 2.
var unit_steps: Dictionary = {}
## And where each copy stands in the file's own coordinates, and which
## sub-model it is a copy of (its key in [member submodels]): what a save
## needs to write a part of that copy back into its sub-model.
var unit_frames: Dictionary = {}
var unit_sections: Dictionary = {}
## And the colour each copy hands its parts of colour 16.
var unit_colours: Dictionary = {}
## And the line of the file that places each copy (Placement.line): a save
## that changes the steps writes it into the step its copy is in now.
var unit_lines: Dictionary = {}
## And each copy's place in the file, which no edit changes: the lines of
## the references placing it, outermost first, joined by "/" (its parts'
## Placement.origin but their own line). A copy the file builds in the
## steps of the one round it (IN_META) is that one's chain, "|" and its path
## as the file says it there.
var unit_chains: Dictionary = {}

## The line Brickworks writes into a model whose steps are somebody's own,
## so they are kept when it is opened again. Other LDraw readers skip a
## "0 !" meta command they do not know.
const AUTHORED_META := "0 !BRICKWORKS AUTHORED_STEPS"
## And the line it writes into someone else's model it wrote whole, whose
## steps it worked out: their author's name is kept, and these steps are
## still no one's ([member marked_worked]).
const WORKED_META := "0 !BRICKWORKS WORKED_STEPS"
var marked_worked: bool = false
## The line before a reference to a sub-model saying which copy of it that
## is: "Wing#2" is "0 !BRICKWORKS COPY 2". A file has nowhere else to keep
## it, and copies read back were numbered in the order the file places
## them, which is the build order once the steps are written: a mirrored
## wing built first came back as the wing and the original as its copy
## (assembly_flow.mjs, 2026-10-16).
const COPY_META := "0 !BRICKWORKS COPY"
## The line before a run of a step's lines that are of a copy of a
## sub-model built in this one's steps (AuthorSteps.IN_PARENT), naming it by
## its path within this one: "0 !BRICKWORKS IN north-east tower#1". In
## force to the next such line or the end of the step; the line alone goes
## back to this one's own. The castle's towers and walls go up a course of
## each in turn, which no sub-model placed whole can say, so their parts are
## written in the steps they are built in: every LDraw reader builds the
## order shown, and this app reads each copy back as it was (stepskeep).
const IN_META := "0 !BRICKWORKS IN"
## The word after "0 !BRICKWORKS" of each of those four, as [method parse]
## compares a line's: written out, not sliced from them four times over for
## every "0 !BRICKWORKS" line read (lreview's file of 200,000, 2026-11-07).
const _AUTHORED_WORD := "AUTHORED_STEPS"
const _WORKED_WORD := "WORKED_STEPS"
const _COPY_WORD := "COPY"
const _IN_WORD := "IN"
## A light placed in the model, "0 !BRICKWORKS LIGHT {...}" (SceneLights):
## its word, as the others' are compared. And a view kept with it
## (SavedViews), which a sub-model keeps as it keeps a light.
const _LIGHT_WORD := "LIGHT"
const _VIEW_WORD := "VIEW"
## The unit step of such a copy (AuthorSteps reads it from here): kept here,
## where the file is read, so reading one names no class of the app's and
## compiles alone, which is what a file browser's picture of a model waits
## for (ModelThumbnail).
const IN_PARENT := -2
## Every FILE section's text but the model's own, by its FILE name in lower
## case: what a part drawn from the file's sections is built from
## (CustomParts.begin_skins), LDCad's donor sections among them.
var section_texts: Dictionary = {}
## Every FILE section, a part's too, by its name as a reference finds it
## ([method _key]): name -> SubModel, whose span says where it is. The first
## block of a name, as [member submodels] has it and a reference means it
## (LDView's rule); a later block of the name is in no table. subexport cut
## the first of two blocks while the model was built of the last (sereview
## F3); the open reads the first now, and so does every reader.
var files: Dictionary = {}
## The sub-models LDCad generated a flexible part's skin into: sub-model key
## -> [the line of its first `0 !LDCAD GENERATED`, the step it is in].
var generated: Dictionary = {}
## What each of those sub-models' skin is as a part (CustomParts._skin_text),
## by its body: made once an open, where the web looks for what a skin is
## drawn from before it opens (CustomParts.unreached_by) and builds it after.
var skin_texts: Dictionary = {}
## The model's own light lines (SceneLights), as the file has them, without a
## line's CR, in its order: those of its first FILE section and any before
## it. Read here, in the one reading of the file, so which model a light is
## of is decided where every part's is: a sub-model's are [member
## section_lines]'s.
var light_lines := PackedStringArray()
## A sub-model's own light and view lines, by its key (as [member
## unit_sections] names the section each copy is of) -> Array of the lines as
## the file has them, without a line's CR, in its order: what the app's
## whole write would not make again in its section (BrickWorld
## .section_lines). A sub-model's view is its own, as its light is, and a
## whole write lost it (lreview3's F3).
var section_lines: Dictionary = {}
## Whether the file has FILE sections, its model the first of them: whose
## name [method file_names] gives the model's own.
var has_file_lines: bool = false
## The key [member main] goes by in [member submodels] and [member files]:
## [constant MAIN_KEY] in a file of FILE sections (section_key), else the
## name the text was read as.
var main_key: String = ""


## Whether the steps in the file are an author's, to keep: there are steps,
## and they are not ones Brickworks worked out and wrote itself. Every file
## it saved wrote its worked-out order as 0 STEP lines, so other tools see
## a build, and those are no one's steps: kept, a model saved yesterday
## would have a new tower's hundred parts in its last step tomorrow. A
## model of one step has no 0 STEP line, and its mark says it is the
## author's all the same: read as no one's, it lost its booklet looks on
## open and its next save erased them (pkreview, pullkept).
func steps_are_authored() -> bool:
	return (stepped or marked_authored) and not marked_worked \
		and (marked_authored or author.strip_edges() != "Brickworks")


static func load_file(path: String) -> LdrModel:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ldr: cannot open %s" % path)
		return null
	var text: String = file.get_as_text()
	file.close()
	return parse(text, path.get_file())


## Parse a model. Never returns null for merely odd input: unreadable lines
## are skipped, because published models are full of vendor extensions and
## losing one line is better than losing the model.
static func parse(text: String, source_name: String = "model") -> LdrModel:
	var model := LdrModel.new()
	model.name = source_name

	# Past a byte-order mark (text_of): its first line is a line as any other.
	var all: PackedStringArray = text.trim_prefix(bom()).split("\n")
	# A plain .ldr has no FILE lines and is one implicit sub-model.
	var current: SubModel = SubModel.new()
	current.name = source_name
	current.span = Vector2i(0, all.size())
	model.submodels[_key(source_name)] = current
	model.main = current
	model.main_key = _key(source_name)
	# The FILE section whose span has not ended yet.
	var open: SubModel = null
	## The key the sub-model being read goes by ([method _key]): a later
	## block of a name an earlier one has is read under a key of its own, one
	## no reference can give, and nothing reaches it ([method twin_key]).
	var current_key: String = _key(source_name)

	var step: int = 0
	## The copy the next reference is, from a COPY_META line before it.
	var copy_next: int = 0
	## The copy built in this one's steps the lines now read are of, from an
	## IN_META line: to the next, or the end of the step.
	var within: String = ""
	var first_file: bool = true
	## The FILE section being read, by its key, and its lines as written.
	var section: String = ""
	var sections: Dictionary = {}
	## How many blocks of each FILE name have been read.
	var blocks: Dictionary = {}
	## The !DATA section being read, and its base64 so far.
	var data_name: String = ""
	var data := PackedStringArray()
	## The model's own light lines, kept here and given to it at the end: a
	## packed array read out of an object and appended to is a copy.
	var own_lights := PackedStringArray()

	var index: int = -1
	for raw: String in all:
		index += 1
		# Trimmed of what LDraw takes for space (SPACE), not of every
		# character up to one as the engine's strip_edges is: a reference to
		# a sub-model named in control characters lost its name, and the line
		# was no reference at all (se3check).
		var line: String = raw.lstrip(SPACE).rstrip(SPACE)
		if not data_name.is_empty():
			if line.begins_with("0 !:"):
				data.append(line.substr(4).strip_edges())
				continue
			model.embedded_data[data_name] = Marshalls.base64_to_raw("".join(data))
			data_name = ""
		if line.begins_with("0 !DATA ") or line.begins_with("0 !DATA\t"):
			section = ""
			if open != null:
				open.span.y = index
				open = null
			data_name = line.substr(7).strip_edges().get_file().to_lower()
			data = PackedStringArray()
			continue
		if not section.is_empty() and not _is_file_line(line):
			# An Array, not a PackedStringArray: a packed array is a value,
			# and appending to one read out of a Dictionary appends to a
			# copy. Every carried part came back empty that way.
			(sections[section] as Array).append(raw.rstrip("\r"))
		if line.is_empty():
			continue

		# Split on any whitespace, not on the space character alone.
		# LDraw writes its fields separated by whitespace and some tools
		# use tabs; a file that does parsed to nothing at all and was
		# rejected as "there are no parts in that file".
		var tokens: PackedStringArray = _fields(line)
		var line_type: int = tokens[0].to_int()

		if line_type == 0:
			if tokens.size() < 2:
				continue
			var keyword: String = tokens[1].to_upper()
			if keyword == "NOFILE":
				section = ""
				if open != null:
					open.span.y = index + 1
					open = null
			if keyword == "FILE":
				# Its name as the file has it, and keyed as a reference to it
				# is looked up (_key): "Gate .ldr" is not "Gate.ldr", nor
				# "parts\twin.ldr" "twin.ldr", nor "hssub.ldr.ldr" "hssub.ldr".
				current_key = section_key(line, blocks)
				section = current_key
				sections[section] = []
				if open != null:
					open.span.y = index
				current = SubModel.new()
				current.name = file_name_of(line)
				current.span = Vector2i(index, all.size())
				open = current
				step = 0
				within = ""
				if first_file:
					# The first FILE in an .mpd is the model itself; the
					# rest are parts of it.
					model.submodels.erase(_key(source_name))
					model.main = current
					model.main_key = current_key
					model.has_file_lines = true
					first_file = false
				# The first block of a name is the one a reference to it
				# means, as LDView reads a file (LDLModel::readComment loads a
				# name once; a later block is "already loaded"): a later one
				# is read, and nothing reaches it.
				if not is_twin(current_key):
					model.submodels[current_key] = current
					model.files[current_key] = current
			elif keyword == "STEP" or keyword == "ROTSTEP":
				# A ROTSTEP ends a step as a STEP does, turning the view
				# for the next (MLCad, LPub).
				step += 1
				current.step_count = step + 1
				model.stepped = true
				within = ""
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == _AUTHORED_WORD:
				model.marked_authored = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == _WORKED_WORD:
				model.marked_worked = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 3 \
					and tokens[2] == _COPY_WORD:
				copy_next = maxi(tokens[3].to_int(), 0)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == _LIGHT_WORD:
				# The model's own, or the sub-model's being read: a light is
				# of the model its line is in, as a part is.
				if current == model.main:
					own_lights.append(raw.trim_suffix("\r"))
				else:
					model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == _VIEW_WORD and current != model.main:
				# A sub-model's view: its own (the model's are SavedViews.read's).
				model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == _IN_WORD:
				# A path's names may hold spaces: the rest of the line.
				within = line.substr(line.to_upper().find(keyword) + keyword.length()).strip_edges() \
					.substr(tokens[2].length()).strip_edges()
			elif keyword == "!LDCAD" and tokens.size() > 2 and tokens[2] == "GENERATED" \
					and not model.generated.has(current_key):
				model.generated[current_key] = [index, step]
			elif keyword == "AUTHOR:" and model.author.is_empty():
				model.author = " ".join(tokens.slice(2))
			elif (current.title.is_empty() and current.placements.is_empty()
					and not keyword.begins_with("!") and keyword != "BFC"
					and keyword != "NAME:" and keyword != "NOFILE"
					and not tokens[1].begins_with("//")):
				current.title = " ".join(tokens.slice(1)).strip_edges()
			continue

		if line_type != 1 or tokens.size() < 15:
			continue

		var color: int = _colour(tokens[1])
		if color == UNREADABLE_COLOUR:
			continue
		var numbers := PackedFloat64Array()
		var valid: bool = true
		for n: int in range(2, 14):
			if not tokens[n].is_valid_float():
				valid = false
				break
			numbers.append(tokens[n].to_float())
		if not valid:
			continue

		# What it names as the file has it: its fields joined by a space are
		# that, but where the name has a run of spaces or a tab in it.
		var named: String = " ".join(tokens.slice(14))
		if not line.ends_with(named):
			named = reference_of(line)
		var reference: String = named.replace("\\", "/").to_lower()
		var part_id: String = reference.get_file()
		if part_id.ends_with(".dat") or part_id.ends_with(".ldr"):
			part_id = part_id.substr(0, part_id.length() - 4)

		var at: Transform3D = to_transform(numbers)
		if not has_size(at.basis):
			# It places nothing: left out as a line of no colour is, and the
			# file keeps it (SourceFile writes back every line no part is
			# read from). Its COPY_META was its own.
			copy_next = 0
			continue
		var read := Placement.new(part_id, color, at, step)
		read.line = index
		read.copy = copy_next
		read.within = within
		read.reference = _key(named)
		copy_next = 0
		current.placements.append(read)

	if not data_name.is_empty():
		model.embedded_data[data_name] = Marshalls.base64_to_raw("".join(data))
	model.light_lines = own_lights
	for file_name: String in sections:
		var lines := PackedStringArray(sections[file_name])
		# The first section is the model itself, whatever it is called; and a
		# later block of a name an earlier one has is read as nothing.
		if file_name == model.main_key or is_twin(file_name):
			continue
		var body: String = "\n".join(lines).strip_edges() + "\n"
		model.section_texts[file_name] = body
		var key: String = file_name if file_name.ends_with(".dat") else file_name + ".dat"
		if declares_library_file(lines):
			model.embedded_sources[key] = body
			_by_bare_name(model.embedded_sources, key, body)
			if model.submodels.has(file_name):
				(model.submodels[file_name] as SubModel).library_file = true
		if not _is_part(file_name, lines):
			continue
		_by_bare_name(model.embedded_parts, key, body)
		model.submodels.erase(file_name)
	return model


## [param body] put in [param table] by its file name without a folder, as
## a reference that gives none finds it: the file's own of that name before
## one in a folder ("48\x.dat"), and the first of those, as with the
## file's other names. A high-resolution primitive in 48\ took its plain
## twin's place (10265-1's "10265 - t02q1765.dat", 345-1's s\ subparts).
static func _by_bare_name(table: Dictionary, key: String, body: String) -> void:
	var bare: String = key.get_file()
	if bare == key or not table.has(bare):
		table[bare] = body


## Whether a part turned by [param basis] has size: it goes some way along
## each of its own axes. Studio and LDCad write a matrix with a row or a
## column of zeros where a flexible part's path doubles back: a segment of
## 42125-1's flexible axles and hoses, 639 of 42108-1's rope, 653 lines in 7
## of the 1,576 sets in vendor/omr, each with nothing of the part drawn.
## Read as parts, there was no inverse of where they stood: Mechanism asked
## for one of every part to read what rests on studs, and grab_probe logged
## 15 to 20 engine errors from 42125-1 alone. Those sets place every other
## part at a thousandth of its volume or more; a millionth is between.
static func has_size(basis: Basis) -> bool:
	return absf(basis.determinant()) > 0.000001


static func _is_file_line(line: String) -> bool:
	return not section_word(line).is_empty()


## What [param line] opens or closes of a file of many sections, its words
## split as [method parse] splits every line ([method _fields]: a tab is a
## space): "FILE", "NOFILE" or "!DATA"; "" for any other line. Split on
## spaces alone, "0<tab>FILE sub.ldr" ended no section here while parse
## opened one there, and a sub-model's light was read as the model's
## (lreview, 2026-11-07).
static func section_word(line: String) -> String:
	var tokens: PackedStringArray = _fields(line.strip_edges())
	if tokens.size() < 2 or tokens[0].to_int() != 0:
		return ""
	var word: String = tokens[1].to_upper()
	return word if word == "FILE" or word == "NOFILE" or word == "!DATA" else ""


## Where [param text]'s own model is, as [method parse] reads it: x where its
## lines begin after its 0 FILE line (0 when the text has none), y where they
## end, at its second 0 FILE (the text's length when it has none). What a
## writer puts into the model goes after the first of its lines (its title),
## inside its FILE section, never before it. Each line that may be one read
## as parse reads it ([method section_word]); those lines found by the
## engine's searches for the word's last letters, "ILE" and "ile" (any case
## of the word but a mix within them, FiLe say, which no tool writes): its
## search without case took 860 ms over a model of 900,000 lines (these two
## 250), and each save asks this more than once.
static func main_span(text: String) -> Vector2i:
	var start: int = -1
	var upper: int = text.find("ILE")
	var lower: int = text.find("ile")
	while upper >= 0 or lower >= 0:
		var found: int = upper if lower < 0 or (upper >= 0 and upper < lower) else lower
		var line_start: int = text.rfind("\n", found) + 1
		var line_end: int = text.find("\n", found)
		if line_end < 0:
			line_end = text.length()
		if section_word(text.substr(line_start, line_end - line_start)) == "FILE":
			if start >= 0:
				return Vector2i(start, line_start)
			start = mini(line_end + 1, text.length())
		var after: int = line_end + 1
		if after >= text.length():
			break
		if upper >= 0 and upper < after:
			upper = text.find("ILE", after)
		if lower >= 0 and lower < after:
			lower = text.find("ile", after)
	return Vector2i(maxi(start, 0), text.length())


## [param bytes], a model file's, as its text, the file's byte-order mark
## kept as its first character when it has one: the engine's UTF-8 reading
## drops the mark, so a save of a file that had one wrote it without
## (cfcheck's cfc_bom.mpd). The open reads past it ([method parse],
## ModelStore._open_into) and the save writes it back.
static func text_of(bytes: PackedByteArray) -> String:
	var text: String = bytes.get_string_from_utf8()
	if text.is_empty() or bytes.size() < 3 or bytes[0] != 0xEF or bytes[1] != 0xBB \
			or bytes[2] != 0xBF:
		return text
	return bom() + text


## The byte-order mark, made as the script runs. Never a "\ufeff" literal:
## an exported script (the web build, every release) keeps its strings as
## UTF-8, and the engine's reading of UTF-8 drops a leading mark, so there
## the literal was "", which every text begins with. Each file opened in a
## browser lost its first character, and with it its first line's meaning
## (mlfix's preview: "0 FILE" read as " FILE"; the steps, booklet and .io
## flows red). tests/test_bom_literal.py holds the rule.
static func bom() -> String:
	return String.chr(0xFEFF)


## Where [param text]'s own model's lines end ([method main_span]).
static func main_end(text: String) -> int:
	return main_span(text).y


## [param text] with [param lines] put in after the first line of its own
## model ([method main_span]: inside its FILE section, after its title),
## each ending as the text's lines do: where a writer puts what it keeps in
## the model.
static func into_main(text: String, lines: PackedStringArray) -> String:
	if lines.is_empty():
		return text
	var span: Vector2i = main_span(text)
	return lines_at(text, title_end(text, span.x, span.y), lines)


## Where a writer puts a line under the title of the section whose lines run
## from [param at] to [param end]: after its first line, the title or
## whatever line it begins with, which stays its first (a byte-order mark
## stays the file's first); at [param at] when it has none or begins with
## its 0 NOFILE. Every writer's rule (MetaIndex too): ModelFloor put its line
## at a title-less main's top and into_main after its first line, so the
## second save of cfc_noheader.mpd differed from the first (cfcheck).
static func title_end(text: String, at: int, end: int) -> int:
	if at >= end:
		return at
	var stop: int = text.find("\n", at)
	var next: int = text.length() if stop < 0 else stop + 1
	return at if section_word(text.substr(at, next - at)) == "NOFILE" else mini(next, end)


## [param text] with [param lines] put in at [param at], where a line of it
## begins or at its end, each ending as its lines do ([method eol_of]); a text
## that ended without a line end still does.
static func lines_at(text: String, at: int, lines: PackedStringArray) -> String:
	if lines.is_empty():
		return text
	var eol: String = eol_of(text)
	var block: String = eol.join(lines)
	if at < text.length():
		return text.substr(0, at) + block + eol + text.substr(at)
	if text.is_empty() or text.ends_with("\n"):
		return text + block + eol
	return text + eol + block


## How [param text] ends its lines, its first one's way: "\r\n" (Studio's,
## Windows') or "\n". Every line a writer puts into a file ends this way, so
## a file of one kind of line end is never given a line of the other or a CR
## alone (lreview, 2026-11-07).
static func eol_of(text: String) -> String:
	var first: int = text.find("\n")
	return "\r\n" if first > 0 and text[first - 1] == "\r" else "\n"


## [param raw], a line of sub-model [param key]'s section, kept as its own
## ([member section_lines]).
func _section_line(key: String, raw: String) -> void:
	if not section_lines.has(key):
		section_lines[key] = []
	(section_lines[key] as Array).append(raw.trim_suffix("\r"))


## Whether a FILE section is a part rather than a sub-model: its header
## says so, as every part's does ("0 !LDRAW_ORG Unofficial_Part").
##
## Not by its name. Older model files often call their sub-models
## "door.dat", and taking every .dat for a part dropped those assemblies
## out of the model.
static func _is_part(_file_name: String, lines: PackedStringArray) -> bool:
	return declares_part(lines)


static func declares_part(lines: PackedStringArray) -> bool:
	for raw: String in lines.slice(0, 16):
		var line: String = raw.strip_edges()
		if line.begins_with("0 !LDRAW_ORG") and line.to_lower().contains("part"):
			return true
	return false


## Whether a FILE section is one of a library's files, which a part may be
## drawn from: a part, a subpart, a primitive or a shortcut, as its header
## says. Not a model or a sub-model, whatever it is called.
static func declares_library_file(lines: PackedStringArray) -> bool:
	for raw: String in lines.slice(0, 16):
		var line: String = raw.strip_edges()
		if line.begins_with("0 !LDRAW_ORG"):
			return not line.to_lower().contains("model")
	return false


## Turn the twelve numbers of a type-1 line into a placement transform.
##
## The twelve are x y z then a row-major 3x3. Mapping into our axes is a
## conjugation by the flip: the basis is flipped on both sides and the
## translation once. Flipping the translation alone — the tempting
## shortcut — leaves every rotated part mirrored, which shows up as
## slopes facing the wrong way and is easy to miss on a symmetric model.
## A colour token. LDraw writes a palette index, or a direct colour as
## 0x2RRGGBB — which String.to_int() does not refuse. It strips the
## letters and returns a decimal made of whatever digits were left, so
## 0x2FF0000 became the colour code 2000, which is nothing, and was
## then written back out as 2000.
const UNREADABLE_COLOUR := -1

static func _colour(token: String) -> int:
	var text: String = token.strip_edges()
	if text.is_valid_int():
		return text.to_int()
	if text.to_lower().begins_with("0x2") and text.length() == 9:
		# Kept as the number it is, so it survives being written out
		# again; whatever draws or writes it takes its RGB (direct_rgb).
		return text.hex_to_int()
	return UNREADABLE_COLOUR


## Whether a colour code is an RGB value written into the file rather
## than an index into the palette.
static func is_direct_colour(code: int) -> bool:
	return code >= 0x2000000


## The colour a direct colour is: 0x2RRGGBB's RGB, opaque. Every drawing and
## every writer takes it from here (PartLibrary.color, ModelThumbnail). It is
## only ever opaque: LDraw 0.27's other direct forms (0x3RRGGBB see-through,
## 0x4 to 0x7 dithered) are not read at all (_colour), so none is ever held.
static func direct_rgb(code: int) -> Color:
	return Color.hex((code & 0xFFFFFF) << 8 | 0xFF)


## What LDraw's readers take for space round a name: C's isspace, a space,
## a tab, a line end, a vertical tab and a form feed. A FILE name and a
## reference's are their text with these trimmed off and nothing else. The
## engine's strip_edges takes every character up to a space's, and a
## sub-model named in control characters alone lost its name and its parts
## (se3check).
const SPACE := " \t\n\v\f\r"


## A sub-file's name as LDraw compares it, for a FILE line's name and a
## reference's alike: as written, [constant SPACE] trimmed, in any case, "\"
## and "/" the same (LDView's LDLModel::subModelNamed). Nothing else: "Gate
## .ldr" is not "Gate.ldr", "parts\twin.ldr" not "twin.ldr", "Castle.ldr"
## not the model's own "castle.mpd". Reduced to a bare stem, every pair was
## one sub-model, and one of them was lost (se3check), and "hssub.ldr.ldr"
## was looked for as "hssub.ldr" and never found (hscheck).
static func _key(name: String) -> String:
	return name.lstrip(SPACE).rstrip(SPACE).replace("\\", "/").to_lower()


## A part's number from the name a reference gives it: no folder, no ".dat"
## or ".ldr" or ".mpd", lowercase. What the library knows a part by, never a
## sub-file's name ([method _key]).
static func stem(name: String) -> String:
	var text: String = _key(name).get_file()
	for suffix: String in [".ldr", ".dat", ".mpd"]:
		if text.ends_with(suffix):
			return text.substr(0, text.length() - suffix.length())
	return text


## The key of the [param seen]th block of a FILE name [param key] another
## has before it: one with a line end in it, which no reference can give.
## LDView reads the first block of a name and reports the next as "already
## loaded", so a reference means the first, and a later one is the file's
## all the same: kept as it is, as a block nothing places (SourceFile).
static func twin_key(key: String, seen: int) -> String:
	return "%s\n%d" % [key, seen]


## The key the model's own section goes by in a file of FILE sections, the
## first FILE's: one no reference gives, since a name is never space at its
## ends ([method _key]). LDView puts the model's own block in no table, so a
## later block of its name is the one a reference to the name means; keyed
## by its name, the model took that name, a reference to the block was read
## as the model placing itself, and one part was drawn of LDView's three
## (ofcheck F4).
const MAIN_KEY := " "


## The key of the section FILE line [param line] begins, as [method parse]
## keys it, [param blocks] the count of each name's blocks read before it
## (counted on, from {} for a file's first FILE line): the model's own, the
## first, by [constant MAIN_KEY]; the first block of a name by its name
## ([method _key]); a later one by a key of its own ([method twin_key]).
## What every reader of a file's sections keys them by, so each reads the
## block a reference means. A reader of a file of parts, which has no model
## of its own, starts with {MAIN_KEY: 1} (StudioDecor.sections).
static func section_key(line: String, blocks: Dictionary) -> String:
	if blocks.is_empty():
		blocks[MAIN_KEY] = 1
		return MAIN_KEY
	var key: String = _key(file_name_of(line))
	var seen: int = int(blocks.get(key, 0)) + 1
	blocks[key] = seen
	return key if seen == 1 else twin_key(key, seen)


## Whether a section's key is a later block of a name ([method twin_key]).
static func is_twin(key: String) -> bool:
	return key.contains("\n")


## The name [param line], a FILE line, gives its section: everything after
## the word FILE, as written, [constant SPACE] trimmed.
static func file_name_of(line: String) -> String:
	return _after_fields(line, 2)


## What [param line], a placing line, names: its 15th field to its end, as
## written, [constant SPACE] trimmed. A name with two spaces in a row or a tab
## in it keeps them: its fields joined by one space made "wing  part.ldr"
## "wing part.ldr", which names no section of the file to any other program
## (kt5review tb_move_copy).
static func reference_of(line: String) -> String:
	return _after_fields(line, 14)


static func _after_fields(line: String, count: int) -> String:
	var at: int = 0
	var size: int = line.length()
	for field: int in count + 1:
		while at < size and _is_space(line.unicode_at(at)):
			at += 1
		if field == count:
			break
		while at < size and not _is_space(line.unicode_at(at)):
			at += 1
	return line.substr(at).rstrip(SPACE)


static func _is_space(c: int) -> bool:
	return c == 32 or (c >= 9 and c <= 13)


## Whether [param line] places something, a part or a sub-model: a line of
## type 1, its first field "1" however it is spaced. A file of tabs ("1\t4\t0
## 0 ...") was read as one of no parts where a line was looked for as "1 ",
## and a save of it refused as one of an empty baseplate (ofcheck F3).
static func is_placing(line: String) -> bool:
	var at: int = 0
	var size: int = line.length()
	while at < size and _is_space(line.unicode_at(at)):
		at += 1
	return at + 1 < size and line.unicode_at(at) == 49 and _is_space(line.unicode_at(at + 1))


## Where a line of type 1 begins in [param text] at or after [param from]
## and before [param to] (any spacing, [method is_placing]), or -1. Searched
## for, not split into lines: the autosave asks on every write.
static func placing_at(text: String, from: int = 0, to: int = -1) -> int:
	var found: RegExMatch = _PLACING.search(text, from, to)
	return found.get_start() if found != null else -1


static var _PLACING := RegEx.create_from_string("(?m)^[ \\t\\v\\f]*1[ \\t\\v\\f]")


## The fields of a line, split on any run of whitespace (space, tab, a
## carriage return). By the engine's split: a character at a time here, it
## was most of reading a big file (42082-1, 2.6 MB: 0.6 to 0.9 s).
static func _fields(line: String) -> PackedStringArray:
	if line.contains("\t") or line.contains("\r"):
		line = line.replace("\t", " ").replace("\r", " ")
	return line.split(" ", false)


static func to_transform(v: PackedFloat64Array) -> Transform3D:
	var a: float = v[3]
	var b: float = v[4]
	var c: float = v[5]
	var d: float = v[6]
	var e: float = v[7]
	var f: float = v[8]
	var g: float = v[9]
	var h: float = v[10]
	var i: float = v[11]

	# F * M * F with F = diag(1, -1, -1): element (r, c) picks up the sign
	# of both its row and its column, so the two off-diagonal blocks flip
	# and the diagonal blocks do not.
	#
	# LDraw writes the matrix by rows and Basis takes it by columns, so
	# the elements have to be transposed as well as signed. f and h were
	# left where they were written, which transposes eight of the nine
	# and not those two.
	#
	# Nothing caught it for as long as every model turned only about the
	# vertical: a rotation about Y has zeros in exactly f and h, so the
	# two wrong entries were both zero and the matrix came out right.
	# The first brick ever laid on its side came back as a matrix that
	# was not a rotation at all — one column doubled, one column empty.
	var basis := Basis(
		Vector3(a, -d, -g),   # column 0
		Vector3(-b, e, h),    # column 1
		Vector3(-c, f, i))    # column 2
	var origin := Vector3(v[0], -v[1], -v[2])
	return Transform3D(basis, origin)


## Inverse of [method to_transform], for writing models back out.
static func from_transform(at: Transform3D) -> PackedFloat64Array:
	var b: Basis = at.basis
	var out := PackedFloat64Array()
	out.append(at.origin.x)
	out.append(-at.origin.y)
	out.append(-at.origin.z)
	# Undo the conjugation; it is its own inverse.
	out.append(b.x.x)
	out.append(-b.y.x)
	out.append(-b.z.x)
	out.append(-b.x.y)
	out.append(b.y.y)
	out.append(b.z.y)
	out.append(-b.x.z)
	out.append(b.y.z)
	out.append(b.z.z)
	return out


## The name each sub-model's section was read with, by the definition its
## copies are of once laid ([method _assembly_names]), and the model's own
## by "" where the file has FILE sections: what a whole write writes each
## under again (write_tree's files, BrickWorld.section_files). A sub-model
## renamed, or a copy made one of its own, is written under a name of its
## new one.
func file_names() -> Dictionary:
	var out: Dictionary = {}
	var names: Dictionary = _assembly_names()
	for key: String in names:
		var sub: SubModel = submodels[key]
		if sub != main:
			out[str(names[key])] = sub.name
	if has_file_lines:
		out[""] = main.name
	return out


## Every placement of the main model, with sub-models inlined.
##
## A sub-model reference carries its own transform, so inlining composes
## the two. Recursion is bounded because a model that contains itself is
## malformed and would otherwise hang the loader.
##
## [param known_parts], the parts the reader's library has: a reference is a
## sub-model where the file has a FILE of its name, a part where it has none,
## and the library's part where the FILE says it is a library's file of a
## number the library has ([method sub_model_of]).
func flatten(known_parts: Dictionary = {}) -> Array[Placement]:
	var out: Array[Placement] = []
	_known = known_parts
	_names = _assembly_names()
	unit_steps.clear()
	unit_frames.clear()
	unit_sections.clear()
	unit_colours.clear()
	unit_lines.clear()
	unit_chains.clear()
	if main != null:
		_inline(main, Transform3D.IDENTITY, 0, out, {}, 0, "", "", {}, "")
	return out


## Reflection across x, which with a turn and a shift is every mirrored
## reference.
const REFLECT_X := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
	Vector3.ZERO)

## Sub-model key -> the name its assembly goes by.
var _names: Dictionary = {}
## The parts the reader's library has, as the last [method flatten] was given.
var _known: Dictionary = {}


## The sub-model of the file [param placement] places, or null where it
## places a part: the FILE of the name it gives ([member Placement
## .reference]), the file's before the library's, as LDView reads a file;
## but not one whose header says it is one of a library's files ([member
## SubModel.library_file]: a shortcut) under a number the library has (the
## known parts [method flatten] was given): that is the library's part, as
## the file says. Read as a sub-model, 10251-1's door (a shortcut block,
## 60797c02.dat) was two parts of no number, gone from the parts list and
## its price, and a save wrote it as a sub-model of the two (ofcheck F1).
## Where the library has no part of the number the block is drawn as it is:
## 10265-1's "10265 - 42716c01.dat" is a sub-model, as LDView reads it. The
## rule every reader of a file's references takes, the server's too
## (api/_parts.js subModelOf).
func sub_model_of(placement: Placement) -> SubModel:
	var nested: SubModel = submodels.get(placement.reference)
	if nested != null and nested.library_file and _known.has(placement.part_id):
		return null
	return nested


## What each sub-model's assembly is called: its title, or its file name
## where it has none — and the file name too where two the model places
## share a title, so two different sub-models are never taken for copies of
## one. One placed by nothing has a title of its own only where no other
## has it: a block the file keeps that nothing places (kt5check F5: the last
## copy taken off, its block kept on the save) renames no copy of the
## model's, as one of the same title did. Never with a "/" or a "#", which
## the path uses. The model's own section is no assembly and clashes with
## none: a model saved as "Flap" round its sub-model Flap had it back as
## "Flap (flap)", and a motion of Flap#1 found nothing to move (motions).
## Up to the exact names, the two had one key wherever the model's file
## and its first section had one stem, and the model was dropped from the
## table by chance.
func _assembly_names() -> Dictionary:
	# The sub-models the model places, at any depth.
	var placed: Dictionary = {}
	var todo: Array = [main] if main != null else []
	while not todo.is_empty():
		var sub: SubModel = todo.pop_back()
		if placed.has(sub):
			continue
		placed[sub] = true
		for placement: Placement in sub.placements:
			var nested: SubModel = sub_model_of(placement)
			if nested != null and not placed.has(nested):
				todo.append(nested)
	# A sub-model with no title goes by its file name's stem ("roof" for
	# "sub/roof.ldr"), and two of one stem by their file names whole.
	var stems: Dictionary = {}
	for key: String in submodels:
		if submodels[key] != main:
			stems[stem(key)] = int(stems.get(stem(key), 0)) + 1
	var titles: Dictionary = {}
	var by_title: Dictionary = {}    ## title -> how many the model places
	var all_titled: Dictionary = {}  ## title -> how many the file has
	for key: String in submodels:
		var sub: SubModel = submodels[key]
		var plain: String = stem(key) if int(stems.get(stem(key), 0)) <= 1 else key
		var title: String = (sub.title if not sub.title.is_empty() else plain) \
			.replace("/", "-").replace("#", "").strip_edges()
		titles[key] = title
		if sub == main:
			continue
		all_titled[title] = int(all_titled.get(title, 0)) + 1
		if placed.has(sub):
			by_title[title] = int(by_title.get(title, 0)) + 1
	var out: Dictionary = {}
	for key: String in submodels:
		var title: String = titles[key]
		var alone: bool = submodels[key] == main \
			or (int(by_title.get(title, 0)) == 1 if placed.has(submodels[key])
				else int(all_titled[title]) == 1)
		var plain: String = stem(key) if int(stems.get(stem(key), 0)) <= 1 else key
		out[key] = title if alone \
			else "%s (%s)" % [title, plain.replace("/", "-").replace("#", "")]
	return out


func _inline(
	sub: SubModel,
	at: Transform3D,
	color: int,
	out: Array[Placement],
	visiting: Dictionary,
	depth: int,
	group: String,
	unit: String,
	copies: Dictionary,
	chain: String
) -> void:
	# By the sub-model, not its name: a block of the model's own name is
	# another (MAIN_KEY).
	if depth > 32 or visiting.has(sub):
		push_warning("ldr: %s contains itself; not expanding further" % sub.name)
		return
	visiting[sub] = true
	## Each copy built in this one's steps (Placement.within) -> its path.
	var made: Dictionary = {}

	for placement: Placement in sub.placements:
		var nested: SubModel = sub_model_of(placement)
		# In a copy built in this one's steps: that copy's, as a reference
		# makes one, numbered as the file says where that number is free.
		var own_group: String = group
		var own_unit: String = unit
		if not placement.within.is_empty():
			own_unit = _built_within(placement.within, unit, copies, made, chain)
			if depth == 0:
				own_group = own_unit.get_slice("/", 0).get_slice("#", 0)

		# A reference to a FILE of its name is that sub-model, whatever part
		# its stem is the number of, as LDView reads it (a file's sub-file
		# before the library's), unless the FILE says it is the library's
		# part (sub_model_of). Matched by a bare stem, a part's reference
		# could be read as a sub-model of that stem, and was kept a part by
		# whether the library had it; matched by the name, "3001.dat" is not
		# "3001.ldr", and the file decides.
		if nested != null:
			# A sub-model referenced by the model itself is one of its
			# assemblies; what that sub-model nests stays part of it.
			var named: String = own_group
			var inside: String = own_unit
			var kind: String = _names.get(_key(nested.name), _key(nested.name))
			if depth == 0 and placement.within.is_empty():
				named = kind
			# Each copy its own unit, at every depth: the four windows are
			# four assemblies of one kind, not one assembly of sixteen parts.
			# Numbered as the file says (COPY_META) where that number is
			# still free, and otherwise the next after the highest, as the
			# app numbers a new copy (Assemblies.next_copy). Free matters: a
			# definition's references are written once, for its first copy,
			# and a second copy of the house says its windows are 1 and 2
			# again.
			var number: int = int(copies.get(kind, 0)) + 1
			if placement.copy > 0 and not copies.has("%s#%d" % [kind, placement.copy]):
				number = placement.copy
			copies[kind] = maxi(int(copies.get(kind, 0)), number)
			var copy: String = "%s#%d" % [kind, number]
			copies[copy] = true
			inside = copy if inside.is_empty() else "%s/%s" % [inside, copy]
			unit_steps[inside] = placement.step
			unit_frames[inside] = at * placement.transform
			unit_sections[inside] = _key(nested.name)
			unit_colours[inside] = placement.color_code if placement.color_code != 16 else color
			unit_lines[inside] = placement.line
			var placed_by: String = _origin(chain, placement.line)
			unit_chains[inside] = placed_by
			_inline(
				nested,
				at * placement.transform,
				placement.color_code if placement.color_code != 16 else color,
				out, visiting.duplicate(), depth + 1, named,
				inside, copies, placed_by)
			continue

		var resolved: int = placement.color_code
		if resolved == 16:
			resolved = color
		var placed := Placement.new(
			placement.part_id, resolved, at * placement.transform, placement.step)
		placed.group = own_group
		placed.unit = own_unit
		placed.line = placement.line
		placed.origin = _origin(chain, placement.line)
		if at.basis.determinant() < 0.0:
			placed.mirrored = true
			placed.local = placement.transform
			placed.frame = at * REFLECT_X
		out.append(placed)

	visiting.erase(sub)


## The path of the copy [param within] names (IN_META), built in the steps
## of the copy at [param unit]: each of its copies numbered as the file says
## where that number is still free in [param copies], else the next after
## the highest, as a reference's is ([method _inline]); the same path for
## every line of one copy in one reading of [param unit] ([param made]).
## Each is a copy built in its parent's steps (AuthorSteps.IN_PARENT).
func _built_within(within: String, unit: String, copies: Dictionary, made: Dictionary,
		chain: String) -> String:
	var path: String = unit
	var said: String = ""
	for segment: String in within.split("/", false):
		said = segment if said.is_empty() else "%s/%s" % [said, segment]
		if made.has(said):
			path = made[said]
			continue
		var kind: String = segment.get_slice("#", 0).strip_edges()
		var asked: int = segment.get_slice("#", 1).to_int() if segment.contains("#") else 0
		var number: int = int(copies.get(kind, 0)) + 1
		if asked > 0 and not copies.has("%s#%d" % [kind, asked]):
			number = asked
		copies[kind] = maxi(int(copies.get(kind, 0)), number)
		var copy: String = "%s#%d" % [kind, number]
		copies[copy] = true
		path = copy if path.is_empty() else "%s/%s" % [path, copy]
		made[said] = path
		unit_steps[path] = IN_PARENT
		unit_chains[path] = chain + "|" + said
	return path


## A line [param line] read within the copy [param chain] places, as
## Placement.origin says it.
static func _origin(chain: String, line: int) -> String:
	return str(line) if chain.is_empty() else "%s/%d" % [chain, line]


## Serialise placements back to .ldr text.
##
## A model whose bricks belong to groups goes out as a multi-part
## document, a sub-model per group, which is how LDraw says "this is the
## gatehouse": Studio, LeoCAD and LPub all show it as an assembly, and it
## comes back in here with every brick in its group.
##
## [param frames] gives a group a frame of its own, group -> Transform3D:
## its sub-model is then written in that frame and placed by it, the way
## a real set's file keeps a minifigure — standing at the origin of
## "Saruman.ldr", and that file put where he stands. Any other group is
## written where its bricks are and placed where it already is.
## [param embedded] carries parts the file has to bring with it — a made
## element, which no other tool has — as file name -> LDraw text. They go
## at the end as sections of their own, which makes even a model with no
## groups a multi-part document.
## [param parts] are the part numbers a reader knows (PartLibrary.parts): no
## sub-model is given a file name that is one, since a reference to it would
## be read as that part. 3315-1's container, a sub-model titled "33009", went
## out as 33009.ldr and came back as the library's 33009, its five parts gone and
## the model 20 LDU higher. [param steps] and [param files] as [method
## write_tree] takes them.
static func write_ldr(
	placements: Array, title: String = "Model", author_name: String = "",
	frames: Dictionary = {}, embedded: Dictionary = {}, parts: Dictionary = {},
	steps: Dictionary = {}, files: Dictionary = {}
) -> String:
	var groups: Array[String] = []
	for item: Variant in placements:
		var group: String = (item as Placement).group
		if not group.is_empty() and not groups.has(group):
			groups.append(group)
	if groups.is_empty() and embedded.is_empty():
		return _write_one(placements, title, author_name, [], "", [], [], [], steps.get("", []))

	var main_file: String = _main_file(title, parts, files)
	var file_of: Dictionary = _file_names(groups, main_file, parts, files)
	var loose: Array = placements.filter(func(p: Placement) -> bool:
		return p.group.is_empty())
	var refs: Array[String] = []
	for group: String in groups:
		var frame: Transform3D = frames.get(group, Transform3D.IDENTITY)
		refs.append("1 16 %s %s" % [_line_numbers(frame), str(file_of[group])])
	var text: String = "0 FILE " + main_file + "\n" \
		+ _write_one(loose, title, author_name, refs, main_file, [], [], [],
			steps.get("", []) if groups.is_empty() else []) + "0 NOFILE\n"
	for group: String in groups:
		var own: Array = placements.filter(func(p: Placement) -> bool:
			return p.group == group)
		if frames.has(group):
			var back: Transform3D = (frames[group] as Transform3D).affine_inverse()
			own = own.map(func(p: Placement) -> Placement:
				var local := Placement.new(p.part_id, p.color_code,
					back * p.transform, p.step)
				local.group = p.group
				return local)
		text += "0 FILE " + str(file_of[group]) + "\n" \
			+ _write_one(own, group, author_name, [],
				str(file_of[group])) + "0 NOFILE\n"
	var names: Array = embedded.keys()
	names.sort()
	for part_name: Variant in names:
		if embedded[part_name] is PackedByteArray:
			continue
		text += "0 FILE " + str(part_name) + "\n" \
			+ str(embedded[part_name]).strip_edges() + "\n0 NOFILE\n"
	# And the files the parts need that are not LDraw: a print's pictures,
	# as the MPD spec carries them, base64 in lines of 76 characters.
	for data_name: Variant in names:
		if not (embedded[data_name] is PackedByteArray):
			continue
		var encoded: String = Marshalls.raw_to_base64(embedded[data_name])
		text += "0 !DATA " + str(data_name) + "\n"
		for at: int in range(0, encoded.length(), 76):
			text += "0 !: " + encoded.substr(at, 76) + "\n"
	return text


## The model as a tree of sub-models, one file section per definition:
## [param instances] is every assembly's path -> {"frame": Transform3D,
## "def": its definition's name, "first" where it is known: the id of its
## first part, which orders the references of a section, and "colour" where
## its definition's copies are placed in two: the colour its reference hands
## the definition's parts of 16}, from Assemblies.file_frames and ModelStore.
## The definition's parts in the colour its first copy is placed in are
## written in 16, and each reference says its copy's colour, 16 where it is
## the colour of the copy its section is written from. A
## definition is written once, from its first copy, in that copy's frame;
## every copy, that one included, is a reference placed by its own frame —
## a mirrored copy by a matrix that reflects, as LDraw allows. Parts
## directly in an assembly are in its section; assemblies inside it are
## references there. A part's place is its unit (Placement.unit).
## [param unit_steps] is each path's step in the section that places it,
## path -> step (see BrickWorld.unit_steps); without it, every reference
## goes in its section's first step. A copy built in its parent's steps
## (AuthorSteps.IN_PARENT) has no section: its parts, and the copies it
## places, are written in the steps of the one round it after a line
## naming it (IN_META). [param steps]: each section's steps, by definition
## ([method steps_written]'s and any a step list adds), each written, one
## with nothing in it too. [param kept] is the lines a definition keeps that
## are not parts, by its name -> the lines, written after its section's
## first line as they are: a sub-model's own lights and views (BrickWorld
## .section_lines, Assemblies.lines_written). [param files]: the name each
## definition's section was read with, by its name, "" the model's own
## (BrickWorld.section_files): written under it again ([method _file_names]).
static func write_tree(
	placements: Array, title: String, author_name: String,
	instances: Dictionary, embedded: Dictionary = {}, unit_steps: Dictionary = {},
	parts: Dictionary = {}, steps: Dictionary = {}, kept: Dictionary = {},
	files: Dictionary = {}
) -> String:
	var tree: Dictionary = _tree_of(instances, unit_steps)
	var masters: Dictionary = tree["masters"]
	var defs: Array = tree["defs"]
	var children: Dictionary = tree["children"]
	var placed_within: Dictionary = tree["within"]
	var main_file: String = _main_file(title, parts, files)
	var file_of: Dictionary = _file_names(defs, main_file, parts, files)
	var refs := func(parent: String, inverse: Transform3D) -> Array[String]:
		var out: Array[String] = []
		# A copy placed in the colour its section's own copy is placed in
		# takes it, by 16; one placed in another, by that colour.
		var hands: int = int((instances.get(parent, {}) as Dictionary).get("colour", -1))
		for child: String in children.get(parent, []):
			var entry: Dictionary = instances[child]
			var colour: int = int(entry.get("colour", -1))
			var line: String = "1 %s %s %s" % [colour_said(colour) if colour >= 0
				and colour != hands else "16", _line_numbers(inverse
				* (entry["frame"] as Transform3D)), str(file_of[str(entry["def"])])]
			# Which copy it is, where it is a copy of the definition it
			# places: one that went its own way (Assemblies.file_frames) is
			# the first of a definition of its own.
			var leaf: String = child.get_slice("/", child.count("/"))
			if leaf.get_slice("#", 0) == str(entry["def"]) and leaf.contains("#"):
				line = "%s %d\n%s" % [COPY_META, maxi(leaf.get_slice("#", 1).to_int(), 1), line]
			elif masters.get(str(entry["def"])) == child:
				# The one copy of a definition of its own ("wing 2", from
				# Wing#2): its first, as the file read again numbers it. Said
				# nowhere, the next save said it, and wrote the file anew
				# (copyfaults2: cfc_wing2).
				line = "%s 1\n%s" % [COPY_META, line]
			out.append(line)
		return out
	var ref_steps := func(parent: String) -> Array:
		if unit_steps.is_empty():
			return []
		return children.get(parent, []).map(func(child: String) -> int:
			return int(unit_steps.get(child, 0)))
	var ref_within := func(parent: String) -> Array:
		return children.get(parent, []).map(func(child: String) -> String:
			return str(placed_within[child]))
	var loose: Array = placements.filter(func(p: Placement) -> bool:
		return _home_in(p.unit, unit_steps) == "")
	var text: String = "0 FILE " + main_file + "\n" \
		+ _write_one(loose, title, author_name, refs.call("", Transform3D.IDENTITY), main_file,
			ref_steps.call(""), loose.map(func(p: Placement) -> String:
				return _within_of(p.unit, "")), ref_within.call(""), steps.get("", [])) \
		+ "0 NOFILE\n"
	for def: String in defs:
		var master: String = masters[def]
		var inverse: Transform3D = ((instances[master] as Dictionary)["frame"] as Transform3D) \
			.affine_inverse()
		# Its parts in the colour its first copy is placed in, where its copies
		# are placed in two, in 16: each copy shows them in its own.
		var hands: int = int((instances[master] as Dictionary).get("colour", -1))
		var own: Array = placements.filter(func(p: Placement) -> bool:
			return _home_in(p.unit, unit_steps) == master).map(func(p: Placement) -> Placement:
				var local := Placement.new(p.part_id, 16 if hands >= 0 and p.unit == master
					and p.color_code == hands else p.color_code, inverse * p.transform, p.step)
				local.group = p.group
				local.unit = p.unit
				local.within = _within_of(p.unit, master)
				return local)
		text += "0 FILE " + str(file_of[def]) + "\n" \
			+ _write_one(own, def, author_name, refs.call(master, inverse), str(file_of[def]),
				ref_steps.call(master), own.map(func(p: Placement) -> String: return p.within),
				ref_within.call(master), steps.get(def, []), kept.get(def, PackedStringArray())) \
			+ "0 NOFILE\n"
	var names: Array = embedded.keys()
	names.sort()
	for part_name: Variant in names:
		if embedded[part_name] is PackedByteArray:
			continue
		text += "0 FILE " + str(part_name) + "\n" \
			+ str(embedded[part_name]).strip_edges() + "\n0 NOFILE\n"
	for data_name: Variant in names:
		if not (embedded[data_name] is PackedByteArray):
			continue
		var encoded: String = Marshalls.raw_to_base64(embedded[data_name])
		text += "0 !DATA " + str(data_name) + "\n"
		for at: int in range(0, encoded.length(), 76):
			text += "0 !: " + encoded.substr(at, 76) + "\n"
	return text


## [param code] as a line says it: a direct colour in the form it came in,
## or it reads as an enormous palette index that nothing has.
static func colour_said(code: int) -> String:
	return "0x%07X" % code if is_direct_colour(code) else str(code)


## The file name the model's own section is written under: the one it was
## read with ([param files]' ""), else one after [param title] ([method
## new_file_name]); none of [param parts] (a part a reader knows, or a
## section of the file a model written whole carries as the file has it,
## SourceFile.kept_keys), as no sub-model's is, or the model is read as
## that, and that as the model: a model titled as a sub-model its file
## keeps, placed by nothing, took that one's name and lost it.
static func _main_file(title: String, parts: Dictionary, files: Dictionary = {}) -> String:
	var file: String = str(files.get("", ""))
	if file.is_empty() or _reserved(file, parts):
		file = new_file_name(title)
	while _reserved(file, parts):
		file = _another(file)
	return file


## The file name each of [param defs] is written under: the name it was read
## with ([param files], by definition), else one after it ([method
## new_file_name]), never the model's own ([param main_file]), another's, a
## part a reader knows or a section kept as the file has it ([param parts]),
## each compared as LDraw compares names ([method _key]). A sub-model kept
## its name only where it was its title's snake case and ".ldr": "0 FILE
## hssub.ldr" titled "hssub.ldr", as MLCad writes one, was written "FILE
## hssub.ldr.ldr", and the next open lost it (hscheck). The names read with
## are given out first, so a new one never takes one of them.
static func _file_names(defs: Array, main_file: String, parts: Dictionary,
		files: Dictionary) -> Dictionary:
	var taken: Dictionary = {_key(main_file): true}
	var out: Dictionary = {}
	for def: String in defs:
		var read: String = str(files.get(def, ""))
		if read.is_empty() or taken.has(_key(read)) or _reserved(read, parts):
			continue
		out[def] = read
		taken[_key(read)] = true
	for def: String in defs:
		if out.has(def):
			continue
		var file: String = new_file_name(def)
		while taken.has(_key(file)) or _reserved(file, parts):
			file = _another(file)
		out[def] = file
		taken[_key(file)] = true
	return out


## A file name for a section read under none, after [param title]: its snake
## case, and ".ldr" after it where it does not end in an LDraw file's
## extension already ("hssub.ldr", never "hssub.ldr.ldr").
static func new_file_name(title: String) -> String:
	var file: String = title.to_snake_case()
	var lower: String = file.to_lower()
	if lower.ends_with(".ldr") or lower.ends_with(".dat") or lower.ends_with(".mpd"):
		return file
	return file + ".ldr"


## [param file] another way, for one taken: "_" before its extension.
static func _another(file: String) -> String:
	var extension: String = file.get_extension()
	return file.get_basename() + "_" + ("." + extension if not extension.is_empty() else "")


## Whether [param file] is one of [param parts]: a part a reader knows by
## its number, or a section kept by its name (SourceFile.kept_keys).
static func _reserved(file: String, parts: Dictionary) -> bool:
	return parts.has(_key(file)) or parts.has(stem(file))


## How [method write_tree] lays out [param instances]: "masters" (each
## definition -> the copy it is written from), "defs" (the definitions in
## the order written), "children" (each section -> the copies it puts on,
## in the order it references them) and "within" (each copy -> the copy
## built in its section's steps it is placed in, IN_META's, "" for none).
static func _tree_of(instances: Dictionary, unit_steps: Dictionary) -> Dictionary:
	var ordered: Array = instances.keys().filter(func(path: String) -> bool:
		return int(unit_steps.get(path, -1)) != IN_PARENT)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var depth_a: int = a.count("/")
		var depth_b: int = b.count("/")
		if depth_a != depth_b:
			return depth_a < depth_b
		return a.naturalnocasecmp_to(b) < 0)
	var masters: Dictionary = {}     ## def -> path
	var defs: Array[String] = []
	for path: String in ordered:
		var def: String = str((instances[path] as Dictionary)["def"])
		if not masters.has(def):
			masters[def] = path
			defs.append(def)
	var children: Dictionary = {}    ## the section placing it -> Array of paths
	var placed_within: Dictionary = {}     ## path -> the copy it is placed in there, IN_META
	for path: String in ordered:
		var at: int = path.rfind("/")
		var parent: String = "" if at < 0 else path.substr(0, at)
		var section: String = _home_in(parent, unit_steps)
		placed_within[path] = _within_of(parent, section)
		if not children.has(section):
			children[section] = []
		(children[section] as Array).append(path)
	# Each section's references in the order the model holds their parts
	# (an instance's "first"): two put on in one step are built in the order
	# they are read in (AuthorSteps.key_of). By name, 7140-1's ship went
	# before its support vehicle once a sub-model was renamed, and every
	# step of the vehicle came 30 later (unitsteps).
	var last: int = 1 << 62
	for section: String in children:
		(children[section] as Array).sort_custom(func(a: String, b: String) -> bool:
			var at_a: int = int((instances[a] as Dictionary).get("first", last))
			var at_b: int = int((instances[b] as Dictionary).get("first", last))
			return at_a < at_b if at_a != at_b else a.naturalnocasecmp_to(b) < 0)
	return {"masters": masters, "defs": _in_written_order(defs, masters, instances, children,
		placed_within, unit_steps), "children": children, "within": placed_within}


## [param defs] in the order their sections are written: each by where its
## first reference is, the model's own section's references in the order
## [method _write_one] writes them (by step, then by the copy built in steps
## each is placed in, then as [param children] has them), then each section
## so found's in turn. A file read again builds its parts in that order, so
## a second save writes the sections in the order the first did. By the copy's
## first part ("first"), they went in the order of the last open's parts: a
## step edit putting Alpha before Zeta wrote zeta, alpha, and the next save
## alpha, zeta (ofcheck F2: order_own3, 60067-1's Speedboat and Bush).
static func _in_written_order(defs: Array[String], masters: Dictionary, instances: Dictionary,
		children: Dictionary, placed_within: Dictionary, unit_steps: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var sections: Array[String] = [""]
	var next: int = 0
	while next < sections.size():
		var placing: Array = (children.get(sections[next], []) as Array).duplicate()
		next += 1
		var at: Dictionary = {}
		for n: int in placing.size():
			at[placing[n]] = n
		placing.sort_custom(func(a: String, b: String) -> bool:
			var step_a: int = int(unit_steps.get(a, 0))
			var step_b: int = int(unit_steps.get(b, 0))
			if step_a != step_b:
				return step_a < step_b
			var within_a: String = str(placed_within.get(a, ""))
			var within_b: String = str(placed_within.get(b, ""))
			if within_a != within_b:
				return within_a < within_b
			return int(at[a]) < int(at[b]))
		for path: String in placing:
			var def: String = str((instances[path] as Dictionary)["def"])
			if seen.has(def):
				continue
			seen[def] = true
			out.append(def)
			sections.append(str(masters[def]))
	# One whose copies are all in sections not written (none, as a tree is
	# laid): after, as they were.
	for def: String in defs:
		if not seen.has(def):
			out.append(def)
	return out


## The section the parts directly in [param path] are written in: its own,
## or for a copy built in its parent's steps (IN_PARENT), the nearest one
## round it that is not.
static func _home_in(path: String, unit_steps: Dictionary) -> String:
	while not path.is_empty() and int(unit_steps.get(path, -1)) == IN_PARENT:
		path = "" if path.rfind("/") < 0 else path.substr(0, path.rfind("/"))
	return path


## [param path] named within the section [param home] it is written in.
static func _within_of(path: String, home: String) -> String:
	if path == home:
		return ""
	return path if home.is_empty() else path.substr(home.length() + 1)


## The steps of each file section [method write_tree] writes, by
## definition ("" the model's own, and the only one of [method write_ldr],
## which has no [param instances]), in order: those of the parts written in
## it and of the copies it puts on, as [method _write_one] places each. The
## writer writes them, with any a step list given adds, and the booklet's
## looks are numbered by the same list (ModelStore, BookletLooks.as_written):
## worked out from the model's parts and not the file's, a part the
## catalogue lacks, written in a step of its own, made every save write one
## step more and move every look after it (pkreview, 2026-11-07).
static func steps_written(placements: Array, instances: Dictionary = {},
		unit_steps: Dictionary = {}) -> Dictionary:
	var tree: Dictionary = _tree_of(instances, unit_steps)
	var def_at: Dictionary = {"": ""}     ## the section a definition is written from -> it
	for def: String in tree["masters"]:
		def_at[tree["masters"][def]] = def
	var own: Dictionary = {}     ## section -> its placements, in order
	for item: Variant in placements:
		var placement: Placement = item
		var home: String = _home_in(placement.unit, unit_steps)
		if def_at.has(home):
			(own.get_or_add(home, []) as Array).append(placement)
	var out: Dictionary = {}
	for section: String in def_at:
		var listed: Array = own.get(section, [])
		var used: Dictionary = {}
		for placement: Placement in listed:
			used[placement.step] = true
		# A copy goes on in its step; with no steps given, in the step of the
		# section's first part.
		var first: int = (listed[0] as Placement).step if not listed.is_empty() else 0
		for child: String in (tree["children"] as Dictionary).get(section, []):
			used[int(unit_steps.get(child, 0)) if not unit_steps.is_empty() else first] = true
		var order: Array = used.keys()
		order.sort()
		out[def_at[section]] = order
	return out


## One file section: its header, then its references to sub-models and its
## parts, step by step, a "0 STEP" between steps. [param ref_steps] gives
## each reference the step it goes on in, as [param placements] carry
## theirs; without them every reference goes first, in the first step. A
## reference was always written first, so a window an author put on in
## step 9 came back put on in step 1. [param within] and [param ref_within]
## name the copy built in this one's steps each part and each reference is
## of, "" for its own: each run of a step's lines of one such copy is
## written after a line naming it (IN_META). [param steps] are steps to
## write, in among the others, that nothing is in (ModelStore: one the
## model's file had empty, that a booklet look is set on). [param kept] go
## after its first line, as they are (write_tree).
static func _write_one(placements: Array, title: String, author_name: String,
		refs: Array[String], file_name: String = "", ref_steps: Array = [],
		within: Array = [], ref_within: Array = [], steps: Array = [],
		kept: PackedStringArray = PackedStringArray()) -> String:
	var lines := PackedStringArray()
	lines.append("0 " + title)
	lines.append_array(kept)
	lines.append("0 Name: " + (file_name if not file_name.is_empty()
		else new_file_name(title)))
	if not author_name.is_empty():
		lines.append("0 Author: " + author_name)
	lines.append("")

	# [step, 0 for a reference or 1 for a part, its place, its line, the copy
	# built in this one's steps it is of]: in a step, this one's own before
	# each such copy's, and the sub-models each puts on before its parts.
	var first: int = (placements[0] as Placement).step if not placements.is_empty() else 0
	var items: Array = []
	for n: int in refs.size():
		var at: int = int(ref_steps[n]) if n < ref_steps.size() else first
		items.append([at, 0, n, refs[n], str(ref_within[n]) if n < ref_within.size() else ""])
	for n: int in placements.size():
		var placement: Placement = placements[n]
		var colour: String = colour_said(placement.color_code)
		items.append([placement.step, 1, n, "1 %s %s %s.dat" % [
			colour, _line_numbers(placement.transform), placement.part_id],
			str(within[n]) if n < within.size() else ""])
	# A step with nothing in it: a place in the order, written as its 0 STEP.
	var filled: Dictionary = {}
	for item: Array in items:
		filled[int(item[0])] = true
	for step: Variant in steps:
		if not filled.has(int(step)):
			items.append([int(step), 2, 0, "", ""])
	items.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		if str(a[4]) != str(b[4]):
			return str(a[4]) < str(b[4])
		for k: int in [1, 2]:
			if int(a[k]) != int(b[k]):
				return int(a[k]) < int(b[k])
		return false)

	var started: bool = false
	var step: int = 0
	var inside: String = ""
	for item: Array in items:
		if started and int(item[0]) != step:
			lines.append("0 STEP")
			inside = ""
		step = int(item[0])
		started = true
		if int(item[1]) == 2:
			continue
		if str(item[4]) != inside:
			inside = str(item[4])
			lines.append(IN_META + ("" if inside.is_empty() else " " + inside))
		lines.append(str(item[3]))

	lines.append("0")
	return "\n".join(lines) + "\n"


## The twelve numbers of a type-1 line for a placement.
static func _line_numbers(at: Transform3D) -> String:
	return numbers_text(from_transform(at))


## The twelve numbers of a type-1 line (x y z a b c d e f g h i), written.
static func numbers_text(v: PackedFloat64Array) -> String:
	var numbers := PackedStringArray()
	for n: int in v.size():
		var value: float = v[n]
		# The first three are a position in LDU; the nine after
		# them are a rotation, and they do not want the same
		# precision.
		#
		# Everything was trimmed to a position's worth — 1/1000 LDU
		# is 0.4 microns, which is plenty for where a brick is. On
		# a direction cosine the same trim is about a sixteenth of
		# a degree, and it is not spent once: a model written and
		# reopened comes back very slightly turned, and again the
		# next time. Nothing in the app could author an angle when
		# this was written, so every matrix element was a 0 or a 1
		# and the loss was exactly zero.
		#
		# And negative zero is zero. A rotation about the vertical
		# axis leaves several matrix elements at -0.0, which prints
		# as "-0" and is valid LDraw and unreadable in a diff: every
		# brick in a re-saved model shows as changed when nothing
		# has. It made a migration that touched three files look
		# like one that had rewritten eight.
		#
		# A whole number, which most of them are (a rotation's 0s and 1s, a
		# position on the grid), written straight off: the same text, and
		# a model of nine thousand parts written in half the time.
		if value == floorf(value) and absf(value) < 1e9:
			numbers.append(str(int(value)))
			continue
		numbers.append(_number_text(value, 4 if n < 3 else 8))
	return " ".join(numbers)


## Whether a placement's numbers are held in single precision, as in every
## build the app ships; a double-precision engine keeps them as written.
static var _held_single: bool = Vector3(0.1, 0.0, 0.0).x != 0.1


static func _as_held(value: float) -> float:
	return PackedFloat32Array([value])[0] if _held_single else value


## [param value] in the fewest places, up to [param most], that read back as
## the same number. A placement is held in single precision, so an author's
## 0.806 is 0.80599999427... here: written to its eight places it came back
## "0.80599999", and every recoloured or moved part of a hand-made file
## changed its text with nothing changed in its place (keeptext5, 11-09).
## The fewest places that are the same single-precision number say exactly
## what was held, so a file written and read again is the same to the bit.
static func _number_text(value: float, most: int) -> String:
	var held: float = _as_held(value)
	var shown: String = ""
	for places: int in range(1, most + 1):
		shown = String.num(value, places)
		if _as_held(shown.to_float()) == held:
			break
	shown = shown.rstrip("0").rstrip(".") if shown.contains(".") else shown
	return "0" if shown == "-0" or shown.is_empty() else shown
