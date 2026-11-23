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
	## And the copies inside it, where its line says them: each by its path
	## within it as the sub-model's own lines number them -> its number in
	## this copy ([method LdrModel.copies_said]). {} where it says none.
	var copies_in: Dictionary = {}
	## The copy built in the steps of the sub-model it was read in that it
	## is part of, by its path within that sub-model ("tower#1"), as the
	## file says (IN_META); "" for the sub-model's own.
	var within: String = ""
	## For a reference to a sub-model whose copy is built in the steps of the
	## one it is read in (IN_PARENT) and keeps its section: each step of that
	## section -> the step of this one it is built in, as the file says
	## (BUILT_META). {} for a copy built in its own steps.
	var built: Dictionary = {}
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
	## The lines of its file it reads as the definition's own of a copy built
	## in its steps (IN_META): the copy as the IN line names it -> the line
	## numbers ([member LdrModel.within_lines]).
	var kept_within: Dictionary = {}


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
## And the numbers of the copies inside that copy, after its own, where it is
## not the copy its sub-model's section is written from: each "Wing#2=3",
## the copy by its path in the section as the section's own lines number it,
## "=" and its number in this copy ([method copies_said]). A section is
## written once, so its COPY lines say the numbers of one copy's; a second
## car's wing came back numbered as the first's, or as the next after the
## highest where that was taken: "Car#2/Wing#3" opened as "Car#2/Wing#2", the
## first car's as "Wing#5", and each save numbered them anew (cf3check O1,
## copyorder). Other readers skip the line; one of this app's before them
## reads the copy's own number alone.


## The number [param word] says on a COPY_META line, its own or one of
## [method copies_said]'s: 1 to 9 digits and nothing else, else 0, none. The
## site reads it by the same rule (api/_parts.js copyNumber): read each its
## own way, "+3" was 3 here and nothing there, twenty nines were Godot's
## highest int here and 1e20 there, and "Wing#2=3" in the own number's place
## was copy 23 here (coreview F2).
static func copy_number(word: String) -> int:
	if word.is_empty() or word.length() > 9 or not word.lstrip("0123456789").is_empty():
		return 0
	return word.to_int()


## The numbers [param words] say, a COPY_META line's after its own number:
## path -> number. A word that says none is skipped.
static func copies_said(words: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for word: String in words:
		var at: int = word.rfind("=")
		if at <= 0:
			continue
		var number: int = copy_number(word.substr(at + 1))
		if number > 0:
			out[word.left(at).uri_decode()] = number
	return out


## The steps a BUILT_META line's [param words] say: each "from=to", a step
## of the sub-model's section and the step it is built in, digits only (as
## [method copy_number] reads a number). A word that says none is skipped.
static func built_said(words: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for word: String in words:
		var at: int = word.find("=")
		var from: String = word.left(at) if at > 0 else ""
		var to: String = word.substr(at + 1) if at > 0 else ""
		if _step_word(from) and _step_word(to):
			out[from.to_int()] = to.to_int()
	return out


## Whether [param word] is a step a BUILT_META line can say: 1 to 9 digits.
static func _step_word(word: String) -> bool:
	return not word.is_empty() and word.length() <= 9 \
		and word.lstrip("0123456789").is_empty()


## [param built] ([member Placement.built]) as a BUILT_META line's words, in
## the order of its steps.
static func built_saying(built: Dictionary) -> String:
	var order: Array = built.keys()
	order.sort()
	return " ".join(order.map(func(step: Variant) -> String:
		return "%d=%d" % [int(step), int(built[step])]))


## [param numbers] (path -> number) as words of a COPY_META line, in an order
## of their own, each path's spaces, tabs, "=", "+" and "%" escaped: a
## sub-model's name may have any of them ("Wing 2+"), and the reader's
## String.uri_decode reads a "+" as a space.
static func copies_saying(numbers: Dictionary) -> String:
	var paths: Array = numbers.keys()
	paths.sort_custom(func(a: String, b: String) -> bool:
		var by: int = a.naturalnocasecmp_to(b)
		return by < 0 if by != 0 else a < b)
	var words := PackedStringArray()
	for path: String in paths:
		words.append("%s=%d" % [path.replace("%", "%25").replace(" ", "%20").replace("\t", "%09")
			.replace("=", "%3D").replace("+", "%2B"), int(numbers[path])])
	return " ".join(words)
## The line before a run of a step's lines that are of a copy of a
## sub-model built in this one's steps (AuthorSteps.IN_PARENT), naming it by
## its path within this one: "0 !BRICKWORKS IN north-east tower#1". In
## force to the next such line or the end of the step; the line alone goes
## back to this one's own. The castle's towers and walls go up a course of
## each in turn, which no sub-model placed whole can say, so their parts are
## written in the steps they are built in: every LDraw reader builds the
## order shown, and this app reads each copy back as it was (stepskeep).
const IN_META := "0 !BRICKWORKS IN"
## The line before a reference to a sub-model whose copy is built in this
## one's steps, as an IN_META block's is, but that the file had as a section
## of its own: "0 !BRICKWORKS BUILT 0=4 1=7 2=9", each step of the
## sub-model's section, "=", and the step of this one it is built in. The
## castle's towers go up a course of each in turn and stay the ten sub-models
## its file has: LDCad, LDView and Studio open them as sub-models, each built
## whole where its line is, and this app reads each part back in the step it
## is built in (wholekeep). Flattened into IN blocks, every whole write of a
## re-planned castle wrote its 11 sections as 1 and 420 IN lines.
const BUILT_META := "0 !BRICKWORKS BUILT"
## The word after "0 !BRICKWORKS" of each of those four, as [method parse]
## compares a line's: written out, not sliced from them four times over for
## every "0 !BRICKWORKS" line read (lreview's file of 200,000, 2026-11-07).
const _AUTHORED_WORD := "AUTHORED_STEPS"
const _WORKED_WORD := "WORKED_STEPS"
const _COPY_WORD := "COPY"
const _IN_WORD := "IN"
const _BUILT_WORD := "BUILT"
## A light placed in the model, "0 !BRICKWORKS LIGHT {...}" (SceneLights):
## its word, as the others' are compared. And a view kept with it
## (SavedViews), which a sub-model keeps as it keeps a light.
const _LIGHT_WORD := "LIGHT"
const _VIEW_WORD := "VIEW"
## And its motions' lines ("MOTION", "MOTION_TRACK"...): a sub-model's are
## its own, kept as its file has them (Motions reads the model's).
const _MOTION_WORD := "MOTION"
## And its program for its motors (HubProgram): a sub-model's is its own, as a
## model put into another brings it, kept and not run.
const _PROGRAM_WORD := "PROGRAM"
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
## A sub-model's own light, view and motion lines, by its key (as [member
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
## The lights, views, motions, credits and comments of a sub-model that has
## no section of its own, every copy of it built in the steps of the one round
## it (IN_PARENT): written after the first IN_META line naming one of its
## copies, in the coordinates of the section that builds it, and read here as
## that definition's, by its name as the path names it ("Model" for "IN
## Model#1") -> Array of the lines, without a line's CR. Read as the model's
## own, a model put into one nobody gave steps lost its 20 motion lines on the
## first save (intomodel3), or played them as the host's.
var within_lines: Dictionary = {}
## And for each copy whose IN block carries them, by its path, as [method
## flatten] laid it: {"frame": the frame of the section building it, in the
## file's coordinates (Transform3D), "lines": PackedInt32Array of their
## lines in the file}. What BrickWorld.section_frames keeps for it, and what
## a cut keeps of it (SubmodelFile).
var unit_kept: Dictionary = {}
## Which copy's IN block gave [member within_lines] each definition's.
var _within_first: Dictionary = {}
## Each sub-model's key whose "0 Name:" line has been read in its head: 0,
## then 1 once [constant NAMED_HERE] is in its [member section_lines].
var _named_at: Dictionary = {}

## In a sub-model's own lines ([member section_lines]): where its Name and
## whose it is go, the lines before it above them and those after below, as
## the file had them ([method _write_one]). An empty line, so a writer that
## knows nothing of it writes a blank line at most. Up to mergekeep
## (2026-11-18) every one went above the Name, and an unedited save of a
## file of the app's own moved a sub-model's PROGRAM, VIEW or LIGHT line
## after its Author up there (hpreview F3).
const NAMED_HERE := ""


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
	## The copy the next reference is, from a COPY_META line before it, and
	## the numbers it says of the copies inside it.
	var copy_next: int = 0
	var copies_next: Dictionary = {}
	## And the steps it is built in, from a BUILT_META line before it.
	var built_next: Dictionary = {}
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
	## The lines the model does not read, kept beside their lines
	## ([member kept_lines]).
	var keep := _Keeper.new()
	keep.key = model.main_key

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
			keep.begin("\n")
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
			keep.blank()
			continue

		# Split on any whitespace, not on the space character alone.
		# LDraw writes its fields separated by whitespace and some tools
		# use tabs; a file that does parsed to nothing at all and was
		# rejected as "there are no parts in that file".
		var tokens: PackedStringArray = _fields(line)
		var line_type: int = tokens[0].to_int()

		if line_type == 0:
			if tokens.size() < 2:
				keep.blank()
				continue
			var keyword: String = tokens[1].to_upper()
			# The app's word after it, read in any case, as MetaIndex reads it:
			# a sub-model's lower-case "0 !BrickWorks program" or "view" was
			# read as nothing and dropped from every save (hpreview F4).
			var word: String = tokens[2].to_upper() if tokens.size() > 2 else ""
			if keyword == "NOFILE":
				section = ""
				keep.finish()
				if open != null:
					open.span.y = index + 1
					open = null
				# The writer's own, after each section: never kept, or each
				# whole write wrote one more (wirekeep's files, swapfind's car).
				continue
			if keyword == "FILE":
				# Its name as the file has it, and keyed as a reference to it
				# is looked up (_key): "Gate .ldr" is not "Gate.ldr", nor
				# "parts\twin.ldr" "twin.ldr", nor "hssub.ldr.ldr" "hssub.ldr".
				current_key = section_key(line, blocks)
				section = current_key
				keep.begin(current_key)
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
				keep.step()
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _AUTHORED_WORD:
				model.marked_authored = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _WORKED_WORD:
				model.marked_worked = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 3 \
					and word == _COPY_WORD:
				copy_next = copy_number(tokens[3])
				copies_next = copies_said(tokens.slice(4))
			elif keyword == "!BRICKWORKS" and tokens.size() > 3 \
					and word == _BUILT_WORD:
				built_next = built_said(tokens.slice(3))
			elif not within.is_empty() and _kept_within(keyword, tokens):
				# In an IN block: the lines of the copy it names, its
				# definition's own (within_lines), never this section's.
				model._within_line(current, current_key, within, raw, index)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _LIGHT_WORD:
				# The model's own, or the sub-model's being read: a light is
				# of the model its line is in, as a part is.
				if current == model.main:
					own_lights.append(raw.trim_suffix("\r"))
				else:
					model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _VIEW_WORD and current != model.main:
				# A sub-model's view: its own (the model's are SavedViews.read's).
				model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word.begins_with(_MOTION_WORD) and current != model.main:
				# A sub-model's motions: its own, as a model put into another
				# brings them (ModelStore.held_from), written back with it. Read
				# as nothing, a save and an open of the app's own lost them.
				model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _PROGRAM_WORD and current != model.main:
				# A sub-model's program: its own, as its motions are.
				model._section_line(current_key, raw)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and word == _IN_WORD:
				# A path's names may hold spaces: the rest of the line.
				within = line.substr(line.to_upper().find(keyword) + keyword.length()).strip_edges() \
					.substr(tokens[2].length()).strip_edges()
			elif keyword == "!LDCAD" and tokens.size() > 2 and tokens[2] == "GENERATED" \
					and not model.generated.has(current_key):
				model.generated[current_key] = [index, step]
			elif keyword == "AUTHOR:" and current != model.main and not model.author.is_empty() \
					and current.placements.is_empty() and step == 0 \
					and not " ".join(tokens.slice(2)) in [model.author, "Brickworks"]:
				# A sub-model's own author, where it is not the model's nor
				# the app's, and its licence below: whose that section is,
				# kept with it (a model put into another, a section of
				# another's file by someone else).
				model._section_line(current_key, raw)
			elif keyword == "!LICENSE" and current != model.main and step == 0 \
					and current.placements.is_empty() and model.section_lines.has(current_key):
				model._section_line(current_key, raw)
			elif keyword.begins_with("//") and current != model.main and step == 0 \
					and current.placements.is_empty() and model.author == "Brickworks":
				# A note in a sub-model's head, in a file of the app's own,
				# which writes none itself: a model's put into this one
				# (ModelStore.held_from), kept with it. And kept beside its
				# line too: its sub-model taken apart writes it there, and
				# where its section is written, once (write_tree's elsewhere).
				model._section_line(current_key, raw)
				keep.carry(raw, false, false, false)
			elif keyword == "AUTHOR:" and model.author.is_empty():
				model.author = " ".join(tokens.slice(2))
			elif keyword == "NAME:" and current != model.main and step == 0 \
					and current.placements.is_empty():
				# Where its own lines after it are written back (NAMED_HERE).
				model._named_at[current_key] = 0
			elif (current.title.is_empty() and current.placements.is_empty()
					and not keyword.begins_with("!") and keyword != "BFC"
					and keyword != "NAME:" and keyword != "NOFILE"
					and not tokens[1].begins_with("//")):
				current.title = " ".join(tokens.slice(1)).strip_edges()
			elif _carried_word(keyword):
				# Read into nothing: kept beside its line for a whole write.
				var said: Array = _block_of(tokens)
				keep.carry(raw, bool(said[0]), bool(said[1]), _binds_next(tokens))
			continue

		if line_type != 1 or tokens.size() < 15:
			if line_type == 1:
				keep.carry(raw, false, false, false)
			continue

		var color: int = _colour(tokens[1])
		if color == UNREADABLE_COLOUR:
			keep.carry(raw, false, false, false)
			continue
		var numbers := PackedFloat64Array()
		var valid: bool = true
		for n: int in range(2, 14):
			if not tokens[n].is_valid_float():
				valid = false
				break
			numbers.append(tokens[n].to_float())
		if not valid:
			keep.carry(raw, false, false, false)
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
			copies_next = {}
			built_next = {}
			keep.carry(raw, false, false, false)
			continue
		var read := Placement.new(part_id, color, at, step)
		read.line = index
		read.copy = copy_next
		read.copies_in = copies_next
		read.within = within
		read.built = built_next
		read.reference = _key(named)
		copy_next = 0
		copies_next = {}
		built_next = {}
		current.placements.append(read)
		keep.anchor(index)

	keep.finish()
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
		keep.drop(file_name)
	# A flexible part's skin LDCad generated is written as the file has it
	# (SourceFile.carried_into, LdcadPath): none of its lines carried twice.
	for skinned: String in model.generated:
		keep.drop(skinned)
	# Someone else's file written whole is headed by its own header's lines
	# already (SourceFile.header): those of them are not carried again.
	if model.author.strip_edges() != "Brickworks":
		var heads: Dictionary = keep.out["head"]
		if heads.has(model.main_key):
			heads[model.main_key] = (heads[model.main_key] as Array).filter(
				func(item: Array) -> bool: return not _header_kept(str(item[0])))
		var order: Array = (keep.out["order"] as Dictionary).get(model.main_key, [])
		var before: Dictionary = keep.out["before"]
		if not order.is_empty() and before.has(int(order[0])):
			before[int(order[0])] = (before[int(order[0])] as Array).filter(
				func(item: Array) -> bool: return not _header_kept(str(item[0])))
	keep.out["main"] = model.main_key
	# And where each line a kept TEXMAP or its geometry is beside stands in
	# its section: a write that moves the part, or frames its section anew,
	# moves its picture with it (_kept_moved).
	keep.out["at"] = _kept_at(keep.out, model)
	# And where the parts and copies of each sub-model's section stand in it,
	# by their lines: a whole write writes a sub-model the file had in the
	# frame the file gave it (Assemblies.file_frames).
	keep.out["locals"] = model._read_locals()
	# And the file's pictures its TEXMAP lines kept name: a whole write
	# carries each one nothing else of it writes (ModelStore._text_into).
	keep.out["data"] = _pictures_named(keep.out, model.embedded_data)
	model.kept_lines = keep.out
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


## Whether [param line] says whose a file is or on what terms ("0 Author:",
## "0 !LICENSE"), as LDraw's header does.
static func is_credit_line(line: String) -> bool:
	var words: PackedStringArray = _fields(line.strip_edges())
	return words.size() >= 2 and words[0] == "0" \
		and (words[1].to_upper() == "AUTHOR:" or words[1].to_upper() == "!LICENSE")


## [param raw], a line of sub-model [param key]'s section, kept as its own
## ([member section_lines]).
func _section_line(key: String, raw: String) -> void:
	if not section_lines.has(key):
		section_lines[key] = []
	if int(_named_at.get(key, -1)) == 0:
		(section_lines[key] as Array).append(NAMED_HERE)
		_named_at[key] = 1
	(section_lines[key] as Array).append(raw.trim_suffix("\r"))


## Whether a line of [param keyword] ([param tokens] its words) is one a
## definition keeps of its own ([member section_lines]' kinds): a light, a
## view, a motion, whose it is and on what terms, or a comment ("0 //").
static func _kept_within(keyword: String, tokens: PackedStringArray) -> bool:
	if keyword == "!BRICKWORKS":
		var word: String = tokens[2].to_upper() if tokens.size() > 2 else ""
		return word == _LIGHT_WORD or word == _VIEW_WORD or word.begins_with(_MOTION_WORD) \
			or word == _PROGRAM_WORD
	return keyword == "AUTHOR:" or keyword == "!LICENSE" or keyword.begins_with("//")


## [param raw], line [param index] of [param sub]'s section (its key
## [param key]), read in the IN block naming the copy [param within]: its
## definition's own ([member within_lines]), from the first block that names
## one of its copies.
func _within_line(sub: SubModel, key: String, within: String, raw: String, index: int) -> void:
	var said: String = "/".join(within.split("/", false))
	var segments: PackedStringArray = said.split("/", false)
	if segments.is_empty():
		return
	var def: String = segments[segments.size() - 1].get_slice("#", 0).strip_edges()
	var block: String = key + "\n" + said
	if str(_within_first.get(def, block)) != block:
		return
	_within_first[def] = block
	if not within_lines.has(def):
		within_lines[def] = []
	(within_lines[def] as Array).append(raw.trim_suffix("\r"))
	if not sub.kept_within.has(said):
		sub.kept_within[said] = PackedInt32Array()
	var at: PackedInt32Array = sub.kept_within[said]
	at.append(index)
	sub.kept_within[said] = at


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
	unit_kept.clear()
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
	chain: String,
	said: Array = [],
	maps: Array = []
) -> void:
	# By the sub-model, not its name: a block of the model's own name is
	# another (MAIN_KEY).
	if depth > 32 or visiting.has(sub):
		push_warning("ldr: %s contains itself; not expanding further" % sub.name)
		return
	visiting[sub] = true
	## Each copy built in this one's steps (Placement.within) -> [its path,
	## the copies' numbers in force there ([param said])].
	var made: Dictionary = {}

	for placement: Placement in sub.placements:
		var nested: SubModel = sub_model_of(placement)
		# In a copy built in this one's steps: that copy's, as a reference
		# makes one, numbered as the file says where that number is free.
		var own_group: String = group
		var own_unit: String = unit
		var own_said: Array = said
		if not placement.within.is_empty():
			var built: Array = _built_within(placement.within, unit, copies, made, chain, said)
			own_unit = built[0]
			own_said = built[1]
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
			# again: each of its others says its own on the line placing it
			# (Placement.copies_in, [param said]).
			var asked: Array = _asked(kind, placement.copy, own_said)
			var number: int = int(copies.get(kind, 0)) + 1
			if int(asked[0]) > 0 and not copies.has("%s#%d" % [kind, int(asked[0])]):
				number = int(asked[0])
			copies[kind] = maxi(int(copies.get(kind, 0)), number)
			var copy: String = "%s#%d" % [kind, number]
			copies[copy] = true
			var below: Array = asked[1]
			if not placement.copies_in.is_empty():
				below = below + [[placement.copies_in, ""]]
			inside = copy if inside.is_empty() else "%s/%s" % [inside, copy]
			# One built in this one's steps that keeps its section: its parts
			# in the steps its line says (BUILT_META), its own steps none.
			unit_steps[inside] = IN_PARENT if not placement.built.is_empty() \
				else _step_in(placement.step, maps)
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
				inside, copies, placed_by, below,
				maps + [placement.built] if not placement.built.is_empty() else [])
			continue

		var resolved: int = placement.color_code
		if resolved == 16:
			resolved = color
		var placed := Placement.new(
			placement.part_id, resolved, at * placement.transform, _step_in(placement.step, maps))
		placed.group = own_group
		placed.unit = own_unit
		placed.line = placement.line
		placed.origin = _origin(chain, placement.line)
		if at.basis.determinant() < 0.0:
			placed.mirrored = true
			placed.local = placement.transform
			placed.frame = at * REFLECT_X
		out.append(placed)

	# The lines its IN blocks carry of a copy built in its steps: that copy's
	# own, in this section's coordinates, which stand at [param at] here.
	for kept_as: String in sub.kept_within:
		if not made.has(kept_as):
			continue
		var path: String = (made[kept_as] as Array)[0]
		if not unit_kept.has(path):
			unit_kept[path] = {"frame": at, "lines": sub.kept_within[kept_as]}
	visiting.erase(sub)


## [param step], of a section read through the BUILT_META lines [param
## maps] say (outermost first), as the step of the section it is built in.
static func _step_in(step: int, maps: Array) -> int:
	for n: int in range(maps.size() - 1, -1, -1):
		step = int((maps[n] as Dictionary).get(step, step))
	return step


## The path of the copy [param within] names (IN_META), built in the steps
## of the copy at [param unit]: each of its copies numbered as the file says
## where that number is still free in [param copies], else the next after
## the highest, as a reference's is ([method _inline]); the same path for
## every line of one copy in one reading of [param unit] ([param made]).
## Each is a copy built in its parent's steps (AuthorSteps.IN_PARENT).
## Returns [the path, the copies' numbers in force in it ([method _asked])].
func _built_within(within: String, unit: String, copies: Dictionary, made: Dictionary,
		chain: String, numbers: Array = []) -> Array:
	var path: String = unit
	var said: String = ""
	var inner: Array = numbers
	for segment: String in within.split("/", false):
		said = segment if said.is_empty() else "%s/%s" % [said, segment]
		if made.has(said):
			path = (made[said] as Array)[0]
			inner = (made[said] as Array)[1]
			continue
		var kind: String = segment.get_slice("#", 0).strip_edges()
		var asked: Array = _asked(kind,
			segment.get_slice("#", 1).to_int() if segment.contains("#") else 0, inner)
		var number: int = int(copies.get(kind, 0)) + 1
		if int(asked[0]) > 0 and not copies.has("%s#%d" % [kind, int(asked[0])]):
			number = int(asked[0])
		copies[kind] = maxi(int(copies.get(kind, 0)), number)
		var copy: String = "%s#%d" % [kind, number]
		copies[copy] = true
		path = copy if path.is_empty() else "%s/%s" % [path, copy]
		inner = asked[1]
		made[said] = [path, inner]
		unit_steps[path] = IN_PARENT
		unit_chains[path] = chain + "|" + said
	return [path, inner]


## The number a copy of [param kind] the file numbers [param number] (0:
## none) is asked to have, by the copies' numbers in force where it is read
## ([param said]: each copy round it whose line says the numbers of the
## copies inside it ([member Placement.copies_in]), outermost first, as
## [that table, the path the copy being read is in within that one, as its
## own table names it, or null where it cannot be named]). The innermost
## renumbers first, and the next out reads it by the number it then has,
## as a copy of that one is numbered by its section's lines and its own;
## past one it cannot be named in, the number as far as it was read.
## Returns [the number, [param said] for the copies inside this one].
static func _asked(kind: String, number: int, said: Array) -> Array:
	if said.is_empty():
		return [number, said]
	var below: Array = []
	below.resize(said.size())
	var known: bool = true
	for k: int in range(said.size() - 1, -1, -1):
		var frame: Array = said[k]
		if not known or number <= 0 or frame[1] == null:
			known = false
			below[k] = [frame[0], null]
			continue
		var key: String = "%s#%d" % [kind, number] if str(frame[1]).is_empty() \
			else "%s/%s#%d" % [frame[1], kind, number]
		below[k] = [frame[0], key]
		number = int((frame[0] as Dictionary).get(key, number))
	return [number, below]


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
	steps: Dictionary = {}, files: Dictionary = {}, carried: Dictionary = {}
) -> String:
	var groups: Array[String] = []
	for item: Variant in placements:
		var group: String = (item as Placement).group
		if not group.is_empty() and not groups.has(group):
			groups.append(group)
	# The lines the file carried that the model does not read, each beside its
	# line again ([method kept_for]): in the model's own section, and in a
	# group's where it is one the file had.
	var main_key: String = str(carried.get("main", "\n"))
	var written: Dictionary = {main_key: true}
	for group: String in groups:
		if files.has(group):
			written[_key(str(files[group]))] = true
	var kept_out: Dictionary = kept_for(carried, _kept_present(placements, {}, {}), written)
	if not (kept_out["block_of"] as Dictionary).is_empty():
		var written_at: Dictionary = {}
		for item: Variant in placements:
			var placement: Placement = item
			written_at[kept_line(placement.origin)] = "%s|%d" % [placement.group, placement.step]
		_split_blocks(kept_out, written_at)
	if groups.is_empty() and embedded.is_empty():
		return _write_one(placements, title, author_name, [], "", [], [], [], steps.get("", []),
			PackedStringArray(), {}, _kept_anchors(placements), [], kept_out, main_key)

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
			steps.get("", []) if groups.is_empty() else [], PackedStringArray(), {},
			_kept_anchors(loose), [], kept_out, main_key) + "0 NOFILE\n"
	for group: String in groups:
		var own: Array = placements.filter(func(p: Placement) -> bool:
			return p.group == group)
		if frames.has(group):
			var back: Transform3D = (frames[group] as Transform3D).affine_inverse()
			own = own.map(func(p: Placement) -> Placement:
				var local := Placement.new(p.part_id, p.color_code,
					back * p.transform, p.step)
				local.group = p.group
				local.origin = p.origin
				return local)
		text += "0 FILE " + str(file_of[group]) + "\n" \
			+ _write_one(own, group, author_name, [],
				str(file_of[group]), [], [], [], [], PackedStringArray(), {}, _kept_anchors(own), [],
				kept_out, _key(str(files[group])) if files.has(group) else "\n") + "0 NOFILE\n"
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
## the definition's parts of 16, and "master" on the copy the definition is
## written from}, from Assemblies.file_frames and ModelStore.
## The definition's parts in the colour its first copy is placed in are
## written in 16, and each reference says its copy's colour, 16 where it is
## the colour of the copy its section is written from. A
## definition is written once, from its first copy (the one marked "master",
## else the outermost), in that copy's frame;
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
## [param kept_within]: the lines a definition keeps whose every copy is built
## in its parent's steps, so has no section to write them in, by the copy
## they are written with (its path) -> the lines, in the coordinates of the
## section that builds it (Assemblies.lines_written): after the first IN_META
## line naming that copy, as [method parse] reads them back (within_lines).
static func write_tree(
	placements: Array, title: String, author_name: String,
	instances: Dictionary, embedded: Dictionary = {}, unit_steps: Dictionary = {},
	parts: Dictionary = {}, steps: Dictionary = {}, kept: Dictionary = {},
	files: Dictionary = {}, kept_within: Dictionary = {}, carried: Dictionary = {},
	sectioned: Dictionary = {}
) -> String:
	# Each copy built in the model's own steps whose section the file had
	# ([method built_sections], [param sectioned]): that section still, its
	# line saying the step each of its steps is built in.
	var built: Dictionary = {}
	if not sectioned.is_empty():
		placements = sectioned["placements"]
		unit_steps = sectioned["units"]
		steps = sectioned["steps"]
		built = sectioned["built"]
	var tree: Dictionary = _tree_of(instances, unit_steps)
	var masters: Dictionary = tree["masters"]
	var defs: Array = tree["defs"]
	var children: Dictionary = tree["children"]
	var placed_within: Dictionary = tree["within"]
	var main_file: String = _main_file(title, parts, files)
	var file_of: Dictionary = _file_names(defs, main_file, parts, files)
	# The lines the file carried that the model does not read, each beside its
	# line again ([method kept_for]): a part's by its origin, a copy's by the
	# line placing it, a section's head and end in the section the file had.
	var copy_lines: Dictionary = _copy_lines(placements)
	var placed: Dictionary = {}
	for section: String in children:
		for child: String in children[section]:
			placed[child] = true
	var main_key: String = str(carried.get("main", "\n"))
	var written: Dictionary = {main_key: true}
	for def: String in defs:
		if files.has(def):
			written[_key(str(files[def]))] = true
	# A sub-model's own lines are written with it ([param kept], [param
	# kept_within]): none of them carried a second time where its section is
	# not written.
	var elsewhere: Dictionary = {}
	for table: Dictionary in [kept, kept_within]:
		for at: Variant in table:
			for line: Variant in table[at]:
				elsewhere[str(line)] = true
	# A copy written after IN lines in a section that is written (one a
	# sectioned sub-model's copies could not all be written as, [method
	# built_sections]): the line that placed it is written with it, its lines
	# before its first IN line (_write_one's in_lines), not given to whatever
	# line comes next.
	var master_of: Dictionary = {}
	for def: String in masters:
		master_of[masters[def]] = true
	var flat_lines: Dictionary = {}  ## home -> {the copy as its IN lines name it -> its line}
	var lines_placed: Dictionary = placed.duplicate()
	for path: String in copy_lines:
		if int(unit_steps.get(path, -1)) != IN_PARENT or int(copy_lines[path]) < 0:
			continue
		var home: String = _home_in(path, unit_steps)
		if home.is_empty() or master_of.has(home):
			(flat_lines.get_or_add(home, {}) as Dictionary)[_within_of(path, home)] = \
				int(copy_lines[path])
			lines_placed[path] = true
	var kept_out: Dictionary = kept_for(carried, _kept_present(placements, copy_lines,
		lines_placed), written, elsewhere)
	if not (kept_out["block_of"] as Dictionary).is_empty():
		var def_at: Dictionary = {}      ## the copy a section is written from -> its definition
		for def: String in masters:
			def_at[masters[def]] = def
		var written_at: Dictionary = {}
		for item: Variant in placements:
			var placement: Placement = item
			var home: String = _home_in(placement.unit, unit_steps)
			if home.is_empty() or def_at.has(home):
				written_at[kept_line(placement.origin)] = "%s|%s|%d" % [str(def_at.get(home, "")),
					_within_of(placement.unit, home), placement.step]
		_split_blocks(kept_out, written_at)
	var ref_anchors := func(parent: String) -> Array:
		return children.get(parent, []).map(func(child: String) -> int:
			return int(copy_lines.get(child, -1)))
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
				# And the copies inside it, where its section is another's.
				var inside: String = _copies_inside(child, instances, masters)
				line = "%s %d%s\n%s" % [COPY_META, maxi(leaf.get_slice("#", 1).to_int(), 1),
					"" if inside.is_empty() else " " + inside, line]
			elif masters.get(str(entry["def"])) == child:
				# The one copy of a definition of its own ("wing 2", from
				# Wing#2): its first, as the file read again numbers it. Said
				# nowhere, the next save said it, and wrote the file anew
				# (copyfaults2: cfc_wing2).
				line = "%s 1\n%s" % [COPY_META, line]
			if built.has(child):
				line = "%s %s\n%s" % [BUILT_META, built_saying(built[child]), line]
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
	# The lines kept with each copy built in a section's steps, by the copy as
	# that section's IN lines name it.
	var kept_in := func(home: String) -> Dictionary:
		var out: Dictionary = {}
		for path: String in kept_within:
			if _home_in(path, unit_steps) == home and path != home:
				out[_within_of(path, home)] = kept_within[path]
		return out
	var loose: Array = placements.filter(func(p: Placement) -> bool:
		return _home_in(p.unit, unit_steps) == "")
	var text: String = "0 FILE " + main_file + "\n" \
		+ _write_one(loose, title, author_name, refs.call("", Transform3D.IDENTITY), main_file,
			ref_steps.call(""), loose.map(func(p: Placement) -> String:
				return _within_of(p.unit, "")), ref_within.call(""), steps.get("", []),
			PackedStringArray(), kept_in.call(""), _kept_anchors(loose), ref_anchors.call(""),
			kept_out, main_key, flat_lines.get("", {})) \
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
				local.origin = p.origin
				return local)
		text += "0 FILE " + str(file_of[def]) + "\n" \
			+ _write_one(own, def, author_name, refs.call(master, inverse), str(file_of[def]),
				ref_steps.call(master), own.map(func(p: Placement) -> String: return p.within),
				ref_within.call(master), steps.get(def, []), kept.get(def, PackedStringArray()),
				kept_in.call(master), _kept_anchors(own), ref_anchors.call(master), kept_out,
				_key(str(files[def])) if files.has(def) else "\n", flat_lines.get(master, {})) \
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


## Which copies built in the model's own steps (IN_PARENT) [method
## write_tree] writes as the sections their file had, each placed by its
## line after a BUILT_META line that says the step each of its section's
## steps is built in: those whose definition the file had as a section
## ([param files]), or that is new in a file of sections (a sub-assembly
## made after Plan steps: a new FILE section, as LDCad's own would be); every
## copy of it built in the model's own steps all the way out; and each copy
## part for part its definition's written copy, each
## part where and in the colour that section's lines put it, its steps one
## map of that section's ([method _built_in]). One that is not has its parts
## written in the model's steps after its IN lines, as before. {} where none
## is. Its "units" are the steps the save writes (Assemblies.lines_written
## and lines_within write each sub-model's own lines by them: in its section,
## in its coordinates), and the whole goes to write_tree's [param sectioned].
static func built_sections(placements: Array, instances: Dictionary, unit_steps: Dictionary,
		files: Dictionary, steps: Dictionary = {}) -> Dictionary:
	var by_def: Dictionary = {}      ## def -> its copies
	var refused: Dictionary = {}     ## def -> true
	var of_sections: bool = false    ## the file had a sub-model as a section
	for def: Variant in files:
		of_sections = of_sections or not str(def).is_empty() and not str(files[def]).is_empty()
	for path: String in instances:
		var def: String = str((instances[path] as Dictionary)["def"])
		(by_def.get_or_add(def, []) as Array).append(path)
		if int(unit_steps.get(path, -1)) != IN_PARENT \
				or str(files.get(def, "")).is_empty() and not of_sections \
				or not _home_in(path, unit_steps).is_empty():
			refused[def] = true
	# Each that is not part for part its definition's written copy takes its
	# definition's others with it, so the copy each is written from stays.
	for _round: int in by_def.size() + 1:
		var chosen: Dictionary = {}
		for def: String in by_def:
			if not refused.has(def):
				for path: String in by_def[def]:
					chosen[path] = true
		if chosen.is_empty():
			return {}
		var made: Dictionary = _built_in(placements, instances, unit_steps, chosen, steps)
		if (made["refused"] as Dictionary).is_empty():
			return made
		refused.merge(made["refused"])
	return {}


## [method built_sections]'s work for the copies [param chosen] (path ->
## true): {"units": [param unit_steps] with each of them put on in its
## section's first step its parts are built in, and each copy put on in one
## of them in that one's step; "placements": [param placements] with each
## part written in one of their sections in that section's step; "steps":
## [param steps] with each such section's steps, and the model's every step
## one of them is built in, so its STEP lines number them as the model does;
## "built": each such copy whose line is written -> its section's steps ->
## the step of the section placing it each is built in, BUILT_META's;
## "refused": the definitions of the copies that are not part for part their
## written copy, {} where none is}. Steps of a section are numbered as it is
## read again: 0, 1, 2... in order, the model's own by its STEP lines.
static func _built_in(placements: Array, instances: Dictionary, unit_steps: Dictionary,
		chosen: Dictionary, steps: Dictionary) -> Dictionary:
	var units: Dictionary = unit_steps.duplicate()
	for path: String in chosen:
		units[path] = 0
	var masters: Dictionary = _tree_of(instances, units)["masters"]
	var parent_of := func(path: String) -> String:
		return "" if path.rfind("/") < 0 else path.substr(0, path.rfind("/"))
	# What each one's section has: its parts (by their place in [param
	# placements]) and the copies it puts on, with the model's steps of every
	# part and copy put on anywhere in it ("spans").
	var parts_in: Dictionary = {}    ## section -> indices of its parts
	var refs_in: Dictionary = {}     ## section -> the copies it puts on
	for n: int in placements.size():
		var home: String = _home_in((placements[n] as Placement).unit, units)
		(parts_in.get_or_add(home, []) as Array).append(n)
	for path: String in instances:
		if int(units.get(path, -1)) != IN_PARENT:
			(refs_in.get_or_add(_home_in(parent_of.call(path), units), []) as Array).append(path)
	var deepest: Array = chosen.keys()
	deepest.sort_custom(func(a: String, b: String) -> bool: return a.count("/") > b.count("/"))
	var spans: Dictionary = {}       ## chosen path -> {model step: true}
	var refused: Dictionary = {}
	for path: String in deepest:
		var span: Dictionary = {}
		for n: int in parts_in.get(path, []):
			span[(placements[n] as Placement).step] = true
		for ref: String in refs_in.get(path, []):
			if chosen.has(ref):
				span.merge(spans[ref])
			else:
				span[int(unit_steps.get(ref, 0))] = true
		spans[path] = span
		if span.is_empty():
			refused[str((instances[path] as Dictionary)["def"])] = true
	if not refused.is_empty():
		return {"refused": refused}
	# The model's own steps as its section is written and read again: those of
	# its parts, the copies it puts on and every part built in its steps.
	var model_steps: Dictionary = {}
	for step: Variant in steps.get("", []):
		model_steps[int(step)] = true
	for n: int in parts_in.get("", []):
		model_steps[(placements[n] as Placement).step] = true
	for ref: String in refs_in.get("", []):
		if chosen.has(ref):
			model_steps.merge(spans[ref])
		else:
			model_steps[int(unit_steps.get(ref, 0))] = true
	var ranked := func(span: Dictionary) -> Dictionary:
		var order: Array = span.keys()
		order.sort()
		var out: Dictionary = {}
		for n: int in order.size():
			out[order[n]] = n
		return out
	var model_rank: Dictionary = ranked.call(model_steps)
	var local: Dictionary = {}       ## chosen path -> model step -> its section's step
	for path: String in chosen:
		local[path] = ranked.call(spans[path])
	# A model step as the section placing [param path] numbers it.
	var placing := func(path: String, step: int) -> int:
		var parent: String = _home_in(parent_of.call(path), units)
		return int(model_rank[step]) if parent.is_empty() else int(local[parent][step])
	var built: Dictionary = {}
	for path: String in chosen:
		var parent: String = _home_in(parent_of.call(path), units)
		var def: String = str((instances[path] as Dictionary)["def"])
		if not parent.is_empty() and masters.get(str((instances[parent] as Dictionary)["def"])) \
				!= parent:
			continue    # in a copy whose section is another's: that one's line says it
		var master: String = masters[def]
		var map: Dictionary = {}
		if master == path:
			for step: int in spans[path]:
				map[int(local[path][step])] = placing.call(path, step)
		else:
			var theirs: Dictionary = _built_leaves(master, placements, instances, unit_steps,
				chosen, parts_in, refs_in)
			var mine: Dictionary = _built_leaves(path, placements, instances, unit_steps,
				chosen, parts_in, refs_in)
			if theirs.size() != mine.size():
				refused[def] = true
				continue
			for key: String in theirs:
				var a: Array = theirs[key]
				var b: Array = mine.get(key, [])
				if a.size() != b.size():
					refused[def] = true
					break
				a.sort()
				b.sort()
				for n: int in a.size():
					if int(a[n]) < 0:
						continue
					var from: int = int(local[master][int(a[n])])
					var to: int = placing.call(path, int(b[n]))
					if int(map.get(from, to)) != to:
						refused[def] = true
						break
					map[from] = to
				if refused.has(def):
					break
		built[path] = map
	if not refused.is_empty():
		return {"refused": refused}
	# Each written in its section's steps, and each placed in the step of the
	# section placing it its first part is built in.
	for path: String in chosen:
		var parent: String = _home_in(parent_of.call(path), units)
		var first: int = (spans[path] as Dictionary).keys().min()
		units[path] = first if parent.is_empty() else int(local[parent][first])
		for ref: String in refs_in.get(path, []):
			if not chosen.has(ref):
				units[ref] = int(local[path][int(unit_steps.get(ref, 0))])
	var written: Array = placements.duplicate()
	for path: String in chosen:
		for n: int in parts_in.get(path, []):
			var was: Placement = placements[n]
			var now := Placement.new(was.part_id, was.color_code, was.transform,
				int(local[path][was.step]))
			now.group = was.group
			now.unit = was.unit
			now.origin = was.origin
			now.line = was.line
			written[n] = now
	var stepped: Dictionary = steps.duplicate()
	var order: Array = model_steps.keys()
	order.sort()
	stepped[""] = order
	for def: String in masters:
		if chosen.has(masters[def]):
			stepped[def] = range((local[masters[def]] as Dictionary).size())
	return {"units": units, "placements": written, "steps": stepped, "built": built,
		"refused": {}}


## What the copy at [param path] holds, as its section and those of the
## copies built in it are written ([method _built_in]): each part and each
## copy put on, by what its line says, the definitions on its way and its
## place from the copy's -> the model steps each such is built in (-1 for a
## copy built in it, which says only where it is).
static func _built_leaves(path: String, placements: Array, instances: Dictionary,
		unit_steps: Dictionary, chosen: Dictionary, parts_in: Dictionary,
		refs_in: Dictionary) -> Dictionary:
	var inverse: Transform3D = ((instances[path] as Dictionary)["frame"] as Transform3D) \
		.affine_inverse()
	var on_way := func(unit: String) -> String:
		var defs := PackedStringArray()
		var at: String = path
		for segment: String in _within_of(unit, path).split("/", false):
			at += "/" + segment
			defs.append(str((instances.get(at, {}) as Dictionary).get("def", segment)))
		return "/".join(defs)
	var out: Dictionary = {}
	var todo: Array = [path]
	while not todo.is_empty():
		var section: String = todo.pop_back()
		for n: int in parts_in.get(section, []):
			var part: Placement = placements[n]
			var key: String = "%s|%s %s %s" % [on_way.call(part.unit), colour_said(part.color_code),
				_line_numbers(inverse * part.transform), part.part_id]
			(out.get_or_add(key, []) as Array).append(part.step)
		for ref: String in refs_in.get(section, []):
			var entry: Dictionary = instances[ref]
			var key: String = "%s|%s %d %s" % [on_way.call(ref), str(entry["def"]),
				int(entry.get("colour", -1)), _line_numbers(inverse * (entry["frame"] as Transform3D))]
			if chosen.has(ref):
				(out.get_or_add(key, []) as Array).append(-1)
				todo.append(ref)
			else:
				(out.get_or_add(key, []) as Array).append(int(unit_steps.get(ref, 0)))
	return out


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
	# Each definition from the copy marked "master" (Assemblies.file_frames:
	# the one its others were laid on, its colours the ones read for 16),
	# else from its outermost.
	var marked: Dictionary = {}      ## def -> path
	for path: String in ordered:
		if bool((instances[path] as Dictionary).get("master", false)):
			marked[str((instances[path] as Dictionary)["def"])] = path
	var masters: Dictionary = {}     ## def -> path
	var defs: Array[String] = []
	for path: String in ordered:
		var def: String = str((instances[path] as Dictionary)["def"])
		if not masters.has(def) and str(marked.get(def, path)) == path:
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


## The numbers of the copies inside the copy at [param path] as words of
## its COPY_META line ([method copies_saying]), where its definition's
## section is written from another copy ([param masters]): each copy inside
## that one by its path there (Assemblies.file_frames' "copies"), which is
## how the section's own lines number it, read as each copy of a definition
## is written, its kind its definition's. "" where there are none to say.
static func _copies_inside(path: String, instances: Dictionary, masters: Dictionary) -> String:
	var entry: Dictionary = instances[path]
	var laid: Dictionary = entry.get("copies", {})
	var master: String = str(masters.get(str(entry["def"]), path))
	if laid.is_empty() or master == path:
		return ""
	var numbers: Dictionary = {}
	for inner: String in laid:
		var mine: String = laid[inner]
		var theirs: String = inner.get_slice("/", inner.count("/"))
		var own: String = mine.get_slice("/", mine.count("/"))
		if theirs.get_slice("#", 0) != own.get_slice("#", 0) or theirs == own:
			continue
		# Each copy on the way named as the section's lines name it: of the
		# kind of the definition it is written as.
		var said: bool = true
		var at: String = master
		for segment: String in inner.split("/"):
			at += "/" + segment
			if str((instances.get(at, {}) as Dictionary).get("def", "")) != segment.get_slice("#", 0):
				said = false
				break
		if said:
			numbers[inner] = own.get_slice("#", 1).to_int()
	return copies_saying(numbers)


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
## after its first line, as they are (write_tree). [param kept_in]: the lines
## kept with a copy built in its steps, by the copy as its IN line names it,
## each written once, after the first IN line naming it; one with no part of
## its own goes in before the first line of a copy inside it.
static func _write_one(placements: Array, title: String, author_name: String,
		refs: Array[String], file_name: String = "", ref_steps: Array = [],
		within: Array = [], ref_within: Array = [], steps: Array = [],
		kept: PackedStringArray = PackedStringArray(), kept_in: Dictionary = {},
		anchors: Array = [], ref_anchors: Array = [], carried: Dictionary = {},
		key: String = "\n", in_lines: Dictionary = {}) -> String:
	var lines := PackedStringArray()
	lines.append("0 " + title)
	# Whose a section is and on what terms, where it is someone else's
	# (section_lines: a model put into this one, a section of another's
	# file): under its name, in place of the writer's, as LDraw heads a file.
	# Its own lines the file had after its Name (NAMED_HERE) go after these,
	# as they were, whose it is among them where the file said it.
	var here: int = kept.find(NAMED_HERE)
	var after: PackedStringArray = kept.slice(here + 1) if here >= 0 else PackedStringArray()
	var credit_after: bool = false
	for line: String in after:
		credit_after = credit_after or is_credit_line(line)
	var credit := PackedStringArray()
	for line: String in (kept.slice(0, here) if here >= 0 else kept):
		if is_credit_line(line):
			credit.append(line)
		else:
			lines.append(line)
	lines.append("0 Name: " + (file_name if not file_name.is_empty()
		else new_file_name(title)))
	if not credit.is_empty():
		lines.append_array(credit)
	elif not author_name.is_empty() and not credit_after:
		lines.append("0 Author: " + author_name)
	lines.append_array(after)
	# The lines of the head of the section the file had ([method kept_for]),
	# each once: a line the head says already (whose it is) is not said again.
	for line: String in (carried.get("head", {}) as Dictionary).get(key, []):
		if not lines.has(line):
			lines.append(line)
	lines.append("")

	# [step, 0 for a reference or 1 for a part, its place, its line, the copy
	# built in this one's steps it is of]: in a step, this one's own before
	# each such copy's, and the sub-models each puts on before its parts.
	var first: int = (placements[0] as Placement).step if not placements.is_empty() else 0
	var items: Array = []
	for n: int in refs.size():
		var at: int = int(ref_steps[n]) if n < ref_steps.size() else first
		items.append([at, 0, n, refs[n], str(ref_within[n]) if n < ref_within.size() else "",
			int(ref_anchors[n]) if n < ref_anchors.size() else -1, null])
	for n: int in placements.size():
		var placement: Placement = placements[n]
		var colour: String = colour_said(placement.color_code)
		items.append([placement.step, 1, n, "1 %s %s %s.dat" % [
			colour, _line_numbers(placement.transform), placement.part_id],
			str(within[n]) if n < within.size() else "",
			int(anchors[n]) if n < anchors.size() else -1, placement.transform])
	# A step with nothing in it: a place in the order, written as its 0 STEP.
	var filled: Dictionary = {}
	for item: Array in items:
		filled[int(item[0])] = true
	for step: Variant in steps:
		if not filled.has(int(step)):
			items.append([int(step), 2, 0, "", "", -1, null])
	items.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		if str(a[4]) != str(b[4]):
			return str(a[4]) < str(b[4])
		for k: int in [1, 2]:
			if int(a[k]) != int(b[k]):
				return int(a[k]) < int(b[k])
		return false)
	items = _blocks_together(items, carried.get("block_of", {}))

	var started: bool = false
	var step: int = 0
	var inside: String = ""
	var said: Dictionary = {}       ## each of kept_in written
	var placing_said: Dictionary = {}    ## each copy of in_lines whose line's lines are written
	for item: Array in items:
		if started and int(item[0]) != step:
			lines.append("0 STEP")
			inside = ""
		step = int(item[0])
		started = true
		if int(item[1]) == 2:
			continue
		var anchor: int = int(item[5])
		var was: Variant = (carried.get("at", {}) as Dictionary).get(anchor)
		var above: Array = (carried.get("before", {}) as Dictionary).get(anchor, []) \
			if anchor >= 0 else []
		if str(item[4]) != inside:
			inside = str(item[4])
			# Where it is written after IN lines, the lines the file had before
			# it (and before the line placing its copy, and each copy round it,
			# the first time) go before them, as a reader reads them again: a
			# line before an IN line is the next part's. Not one that says what
			# the next line is or opens a block round it, which stays beside it.
			if not inside.is_empty():
				var copy: String = ""
				for segment: String in inside.split("/", false):
					copy = segment if copy.is_empty() else copy + "/" + segment
					if in_lines.has(copy) and not placing_said.has(copy):
						placing_said[copy] = true
						var line: int = int(in_lines[copy])
						for table: String in ["before", "after"]:
							lines.append_array(PackedStringArray(
								(carried.get(table, {}) as Dictionary).get(line, [])))
				var cut: int = 0
				while cut < above.size() and not _stays_beside(str(above[cut])):
					cut += 1
				lines.append_array(PackedStringArray(above.slice(0, cut)))
				above = above.slice(cut)
			var named: bool = false
			for copy: String in _kept_opened(inside, kept_in, said):
				lines.append(IN_META + " " + copy)
				for line: String in kept_in[copy]:
					if line != NAMED_HERE:
						lines.append(line)
				said[copy] = true
				named = copy == inside
			if not named:
				lines.append(IN_META + ("" if inside.is_empty() else " " + inside))
		# Beside the lines the file had it beside ([method kept_for]), a
		# picture's moved as its part is.
		lines.append_array(_kept_moved(above, was, item[6]))
		if (carried.get("open_before", {}) as Dictionary).has(anchor):
			lines.append_array(_kept_moved([carried["open_before"][anchor]], was, item[6]))
		lines.append(str(item[3]))
		if anchor >= 0 and carried.has("after"):
			var below: Array = (carried["after"] as Dictionary).get(anchor, [])
			if (carried.get("mute_end", {}) as Dictionary).has(anchor):
				below = below.filter(func(line: String) -> bool: return not _ends_block(line))
			lines.append_array(_kept_moved(below, was, item[6]))
			if (carried.get("close_after", {}) as Dictionary).has(anchor):
				lines.append(str(carried["close_after"][anchor]))

	lines.append_array(PackedStringArray((carried.get("end", {}) as Dictionary).get(key, [])))
	lines.append("0")
	return "\n".join(lines) + "\n"


## How many of a sub-model's parts [method _read_locals] keeps the place of:
## enough that most of them still say where its copy's frame is after the
## edits that move a few, and few enough that a file of 200,000 lines keeps
## no place for each.
const READ_LOCALS_EACH := 16


## Line -> where it stands in its section, as the file says it (its own
## numbers, the app's space): every line of a sub-model's section placing
## another sub-model, and its first [constant READ_LOCALS_EACH] parts. From
## these a copy's parts, read from the file, say the frame the file gave the
## copy (Assemblies._read_frames). None of the model's own section, whose
## frame is the file's.
func _read_locals() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in submodels:
		var sub: SubModel = submodels[key]
		if sub == main or sub.library_file:
			continue
		var parts: int = 0
		for placement: Placement in sub.placements:
			if placement.line < 0:
				continue
			if sub_model_of(placement) != null:
				out[placement.line] = placement.transform
			elif parts < READ_LOCALS_EACH:
				out[placement.line] = placement.transform
				parts += 1
	return out


## Where each line of [param kept] ([member kept_lines]) that a TEXMAP line,
## or a TEXMAP block's own geometry ("0 !: 1 ..."), is beside stands in its
## section, as [param model]'s lines place it: line -> Transform3D. Only
## those: a file of 200,000 lines keeps no place for each.
static func _kept_at(kept: Dictionary, model: LdrModel) -> Dictionary:
	var wanted: Dictionary = {}
	for table: String in ["before", "after"]:
		for line: Variant in kept[table]:
			for item: Array in kept[table][line]:
				var said: String = str(item[0]).strip_edges().to_upper()
				if said.begins_with("0 !TEXMAP") or said.begins_with("0 !:"):
					wanted[int(line)] = true
					break
	var out: Dictionary = {}
	if wanted.is_empty():
		return out
	for key: Variant in model.submodels:
		for placement: Placement in (model.submodels[key] as SubModel).placements:
			if wanted.has(placement.line):
				out[placement.line] = placement.transform
	return out


## [param lines] (kept beside a line that stood at [param was] in its
## section, [method _kept_at]) as they are written beside it now it stands
## at [param now]: a TEXMAP's points and its block's own geometry moved as
## the part moved, so the picture is still on it. As they are where it did
## not move, or where either is not known (null): byte for byte.
static func _kept_moved(lines: Array, was: Variant, now: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var by := Transform3D.IDENTITY
	if was is Transform3D and now is Transform3D:
		by = (now as Transform3D) * (was as Transform3D).affine_inverse()
	var still: bool = by.is_equal_approx(Transform3D.IDENTITY)
	for line: Variant in lines:
		out.append(str(line) if still else _moved_line(str(line), by))
	return out


## [param line], a TEXMAP START or NEXT, or a "0 !:" line of a block's own
## geometry, with its points carried by [param by] (in the app's space,
## [constant FLIP] of the file's). Any other line as it is.
static func _moved_line(line: String, by: Transform3D) -> String:
	var words: PackedStringArray = _fields(line.strip_edges())
	if words.size() < 3 or words[0] != "0":
		return line
	var key: String = words[1].to_upper()
	if key == "!TEXMAP" and words.size() >= 13 and words[2].to_upper() in ["START", "NEXT"]:
		var moved: Variant = _moved_points(words, 4, 3, by)
		return line if moved == null else " ".join(moved)
	if key == "!:":
		var inner: PackedStringArray = words.slice(2)
		var kind: String = inner[0]
		var moved: Variant = null
		if kind == "1" and inner.size() >= 15:
			var numbers := PackedFloat64Array()
			for n: int in range(2, 14):
				if not inner[n].is_valid_float():
					return line
				numbers.append(inner[n].to_float())
			var placed: PackedStringArray = numbers_text(from_transform(
				by * to_transform(numbers))).split(" ")
			for n: int in 12:
				inner[n + 2] = placed[n]
			moved = inner
		elif kind in ["2", "3", "4", "5"]:
			moved = _moved_points(inner, 2, {"2": 2, "3": 3, "4": 4, "5": 4}[kind], by)
		return line if moved == null else "0 !: " + " ".join(moved)
	return line


## [param words] with the [param count] points from word [param from] on
## carried by [param by]; null where one of them is not a number.
static func _moved_points(words: PackedStringArray, from: int, count: int,
		by: Transform3D) -> Variant:
	if words.size() < from + count * 3:
		return null
	var out: PackedStringArray = words.duplicate()
	for k: int in count:
		var at: int = from + k * 3
		for n: int in 3:
			if not words[at + n].is_valid_float():
				return null
		var point: Vector3 = by * (Vector3(words[at].to_float(), words[at + 1].to_float(),
			words[at + 2].to_float()) * FLIP) * FLIP
		out[at] = _number_text(point.x + 0.0, 4)
		out[at + 1] = _number_text(point.y + 0.0, 4)
		out[at + 2] = _number_text(point.z + 0.0, 4)
	return out


## A block [param kept] ([method kept_for]) has round lines now written in
## two or more places ([param written_at]: line -> its section, copy and
## step, as one word): an edit put one of its parts in another sub-model or
## step. It stays round the parts written with its first, its END after the
## last of them, never a START with no END in a section nor one round a STEP
## or another sub-model's parts. A picture round its parts alone (a TEXMAP
## with no geometry of its own, "0 !:", nor FALLBACK) opens again round each
## other place's parts, so it is on every part it was on; any other block's
## parts elsewhere are written as they are, without it.
static func _split_blocks(kept: Dictionary, written_at: Dictionary) -> void:
	var lines_of: Dictionary = {}    ## block -> its lines written
	for line: int in kept["block_of"]:
		(lines_of.get_or_add(int(kept["block_of"][line]), []) as Array).append(line)
	var close_after: Dictionary = {}
	var open_before: Dictionary = {}
	var mute_end: Dictionary = {}
	for block: int in lines_of:
		var lines: Array = lines_of[block]
		lines.sort()
		var runs: Dictionary = {}    ## where -> its lines, in the file's order
		for line: int in lines:
			(runs.get_or_add(str(written_at.get(line, "")), []) as Array).append(line)
		if runs.size() < 2:
			continue
		var end: String = ""
		var opening: String = ""
		var plain: bool = true
		for line: int in lines:
			for table: String in ["before", "after"]:
				for said: String in (kept[table] as Dictionary).get(line, []):
					var words: PackedStringArray = _fields(said.strip_edges())
					var ends: Array = _block_of(words)
					if bool(ends[1]):
						end = said
					elif bool(ends[0]) and line == int(lines[0]) and table == "before":
						opening = said
					var upper: String = said.strip_edges().to_upper()
					if upper.begins_with("0 !:") or upper.begins_with("0 !TEXMAP FALLBACK"):
						plain = false
		if end.is_empty():
			continue
		plain = plain and opening.strip_edges().to_upper().begins_with("0 !TEXMAP START")
		var first: String = str(written_at.get(int(lines[0]), ""))
		var last: int = int((runs[first] as Array).max())
		for line: int in lines:
			if line != last:
				mute_end[line] = true
		if not (kept["after"] as Dictionary).get(last, []).has(end):
			close_after[last] = end
		else:
			mute_end.erase(last)
		var again: int = 0
		for where: String in runs:
			if where == first:
				continue
			var run: Array = runs[where]
			again += 1
			for line: int in run:
				if plain:
					(kept["block_of"] as Dictionary)[line] = block + again * 1000000000
				else:
					(kept["block_of"] as Dictionary).erase(line)
			if plain:
				open_before[int(run.min())] = opening
				close_after[int(run.max())] = end
	kept["close_after"] = close_after
	kept["open_before"] = open_before
	kept["mute_end"] = mute_end


## Whether [param line], kept before a line ([method kept_for]), is about that
## line and so is written directly before it: one that says what the next
## line is ([method _binds_next]), opens a block round it ([method _block_of]),
## or is in such a block (a TEXMAP's own geometry, its FALLBACK).
static func _stays_beside(line: String) -> bool:
	var words: PackedStringArray = _fields(line.strip_edges())
	if words.size() >= 2 and words[0] == "0" \
			and (words[1] == "!:" or words[1].to_upper() == "!TEXMAP"):
		return true
	return _binds_next(words) or bool(_block_of(words)[0])


## Whether [param line] ends a block another program wrote ([method _block_of]).
static func _ends_block(line: String) -> bool:
	return bool(_block_of(_fields(line.strip_edges()))[1])


## [param items] ([method _write_one]'s, in their order) with the lines a
## block another program wrote round two or more of them covers
## ([param block_of]: line -> block, [method kept_for]) written together where
## the first of them is, in the file's order, so its START is before the
## first and its END after the last with nothing else between: a TEXMAP round
## two parts, sorted apart by height, put a third part in its picture. Only
## within a step and a copy built in it: one across two steps is written as
## its parts are, its START and END where their lines are.
static func _blocks_together(items: Array, block_of: Dictionary) -> Array:
	if block_of.is_empty():
		return items
	var out: Array = []
	var taken: Dictionary = {}
	for n: int in items.size():
		if taken.has(n):
			continue
		var item: Array = items[n]
		var block: int = int(block_of.get(int(item[5]), -1)) if int(item[1]) != 2 else -1
		if block < 0:
			out.append(item)
			continue
		var together: Array = [item]
		for m: int in range(n + 1, items.size()):
			var other: Array = items[m]
			if not taken.has(m) and int(other[1]) != 2 and int(other[0]) == int(item[0]) \
					and str(other[4]) == str(item[4]) \
					and int(block_of.get(int(other[5]), -1)) == block:
				together.append(other)
				taken[m] = true
		together.sort_custom(func(a: Array, b: Array) -> bool: return int(a[5]) < int(b[5]))
		out.append_array(together)
	return out


## The copies of [param kept_in] not yet [param said] that [param inside]
## (a copy as an IN line names it) is, or is inside, the outermost first:
## each one's lines go in before its first part, or the first of a copy inside
## it, is written.
static func _kept_opened(inside: String, kept_in: Dictionary, said: Dictionary) -> Array:
	if inside.is_empty() or kept_in.is_empty():
		return []
	var out: Array = []
	for copy: String in kept_in:
		if not said.has(copy) and (inside == copy or inside.begins_with(copy + "/")):
			out.append(copy)
	out.sort_custom(func(a: String, b: String) -> bool: return a.count("/") < b.count("/"))
	return out


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


# -- the lines a model written whole carries (wholekeep) ----------------------

## The lines of the file's sub-model sections the model does not read into
## itself, each kept beside the line it was beside, so a model written whole
## writes them there again ([method kept_for], [method _write_one]): comments,
## other programs' lines (LDCad's, LPub's, MLCad's, LeoCAD's, BFC), a part's
## TEXMAP block with its picture's texture-only lines, a line that places
## nothing. Up to wholekeep a whole write kept only a sub-model's head notes
## in a file of the app's own: the castle's "0 // Designed by ..." went at its
## first edit, and a printed panel's TEXMAP block at any edit of a file the
## app wrote (dkfix N2). Plain Dictionaries, read on any thread:
## "before": a placing line's place in the file -> the lines above it since
##   the line before, each [text, the TEXMAP or other block it is in, -1];
## "after": a placing line -> the lines after it that end its step or close
##   the block round it (the block's END, an LPub line before a STEP);
## "head" and "end": a section's key -> the lines of its head (above its first
##   placing line or STEP, to its first blank line) and those after its last;
## "order": a section's key -> its placing lines, in the file's order;
## "covers": a block -> the placing lines inside it.
## A placing line is a part's or a copy's: a part's place in the file is its
## origin's last line (Placement.origin), a copy's its reference's.
var kept_lines: Dictionary = {}


## What [method parse] keeps as it reads ([member kept_lines]).
class _Keeper extends RefCounted:
	var out: Dictionary = {"before": {}, "after": {}, "head": {}, "end": {}, "order": {},
		"covers": {}}
	var key: String = "\n"
	var pending: Array = []
	## Whether no placing line or STEP has been read in the section yet, and
	## where in [member pending] its head ends (-1: all of it so far).
	var head_open: bool = true
	var head_cut: int = -1
	var last: int = -1
	var blocks: Array = []
	var next_block: int = 0

	func begin(section: String) -> void:
		finish()
		key = section
		head_open = true
		head_cut = -1
		last = -1
		blocks = []

	## The lines still waiting: the section's end.
	func finish() -> void:
		if pending.is_empty():
			return
		_join(out["end"], key, pending)
		pending = []

	func blank() -> void:
		if head_open and head_cut < 0:
			head_cut = pending.size()

	## A line kept: [param opens] or [param closes] a block (TEXMAP START /
	## END and the like), [param binds] says what the next line is.
	func carry(raw: String, opens: bool, closes: bool, binds: bool) -> void:
		var block: int = int(blocks[blocks.size() - 1]) if not blocks.is_empty() else -1
		if opens:
			block = next_block
			next_block += 1
			blocks.append(block)
		if head_open and head_cut < 0 and (binds or block >= 0):
			head_cut = pending.size()
		pending.append([raw.trim_suffix("\r"), block])
		if closes and block >= 0:
			blocks.pop_back()
			var inside: Array = (out["covers"] as Dictionary).get(block, [])
			# The block's END after the last line it covers, which it closes.
			if not inside.is_empty() and int(inside[inside.size() - 1]) == last:
				_join(out["after"], last, pending)
				pending = []

	## A placing line, line [param index] of the file.
	func anchor(index: int) -> void:
		if head_open:
			var cut: int = head_cut if head_cut >= 0 else pending.size()
			if cut > 0:
				_join(out["head"], key, pending.slice(0, cut))
			pending = pending.slice(cut)
			head_open = false
		if not pending.is_empty():
			_join(out["before"], index, pending)
			pending = []
		last = index
		(out["order"] as Dictionary).get_or_add(key, []).append(index)
		for block: int in blocks:
			(out["covers"] as Dictionary).get_or_add(block, []).append(index)

	## A STEP or ROTSTEP line: what waits ends the step, after its last line.
	func step() -> void:
		if head_open:
			if not pending.is_empty():
				_join(out["head"], key, pending)
				pending = []
			head_open = false
			return
		if last >= 0 and not pending.is_empty():
			_join(out["after"], last, pending)
			pending = []

	## Every line kept of section [param section], dropped: a part's, a
	## flexible part's skin, written as the file has them by other means.
	func drop(section: String) -> void:
		for line: int in (out["order"] as Dictionary).get(section, []):
			(out["before"] as Dictionary).erase(line)
			(out["after"] as Dictionary).erase(line)
		for table: String in ["head", "end", "order"]:
			(out[table] as Dictionary).erase(section)

	static func _join(table: Dictionary, at: Variant, lines: Array) -> void:
		(table.get_or_add(at, []) as Array).append_array(lines)


## Whether a "0" line of [param words] is one the model does not read and a
## whole write carries ([member kept_lines]): none of the app's own, nor a
## Name or Author line, which the writer writes.
static func _carried_word(keyword: String) -> bool:
	return keyword != "!BRICKWORKS" and keyword != "NAME:" and keyword != "AUTHOR:" \
		and keyword != "!DATA"


## Whether "0" [param words] open or close a block another program writes
## round lines: [opens, closes]. TEXMAP's START and END (its NEXT is a line
## about the next), LeoCAD's, LPub's and LSynth's BEGIN and END, MLCad's
## SKIP_BEGIN and SKIP_END.
static func _block_of(words: PackedStringArray) -> Array:
	if words.size() < 3:
		return [false, false]
	var first: String = words[1].to_upper().trim_prefix("!")
	if first == "TEXMAP":
		var said: String = words[2].to_upper()
		return [said == "START", said == "END"]
	if first == "MLCAD":
		var said: String = words[2].to_upper()
		return [said == "SKIP_BEGIN", said == "SKIP_END"]
	if first == "LEOCAD" or first == "LPUB" or first == "SYNTH":
		for n: int in range(2, mini(words.size(), 5)):
			var said: String = words[n].to_upper()
			if said == "BEGIN":
				return [true, false]
			if said == "END":
				return [false, true]
	return [false, false]


## Whether "0" [param words] say what the line after them is (SourceFile
## ._binds_next's kinds): BFC INVERTNEXT, LDCad's GROUP_NXT, MLCad's BTG,
## !TEXMAP NEXT, LeoCAD's PIECE, Studio's PE_TEX lines.
static func _binds_next(words: PackedStringArray) -> bool:
	if words.size() < 2:
		return false
	var first: String = words[1].to_upper()
	if first == "PE_TEX_PATH" or first == "PE_TEX_INFO":
		return true
	if words.size() < 3:
		return false
	var said: String = first + " " + words[2].to_upper()
	return said == "BFC INVERTNEXT" or said == "!LDCAD GROUP_NXT" or said == "MLCAD BTG" \
		or said == "!TEXMAP NEXT" or said == "!LEOCAD PIECE"


## Whether a line of the model's own head is one whose it is and on what
## terms, which a whole write of someone else's file writes from its header
## already (SourceFile.header): not carried again.
static func _header_kept(line: String) -> bool:
	var words: PackedStringArray = _fields(line.strip_edges())
	if words.size() < 2 or words[0] != "0":
		return false
	if words[1] == "!LDCAD" and words.size() > 2 and words[2] == "GROUP_DEF":
		return true
	for kept: String in ["!LICENSE", "!LDRAW_ORG", "!HISTORY", "!THEME", "!CATEGORY",
			"!KEYWORDS", "!HELP"]:
		if words[1].begins_with(kept):
			return true
	return false


## [param kept] ([member kept_lines]) for a write that writes the placing
## lines [param present] (line -> true) and the sections [param written]
## (key -> true): the lines of each line not written go to the next one of
## its section that is, or to the section's end, and those after it to the
## one before; a section not written gives its head to its first line still
## written and its end to its last; a block round only lines not written goes
## with them (a TEXMAP block round a part taken off textured nothing); a
## section none of whose lines is written takes its lines with it. Returns
## the same tables, "before", "after", "head" and "end", of the lines alone.
static func kept_for(kept: Dictionary, present: Dictionary, written: Dictionary,
		elsewhere: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"before": {}, "after": {}, "head": {}, "end": {}, "block_of": {},
		"at": kept.get("at", {})}
	if kept.is_empty():
		return out
	var before: Dictionary = kept["before"]
	var after: Dictionary = kept["after"]
	var heads: Dictionary = kept["head"]
	var ends: Dictionary = kept["end"]
	var gone: Dictionary = {}       ## a block round no line written -> true
	for block: int in kept["covers"]:
		var written_in: Array = (kept["covers"][block] as Array).filter(
			func(line: int) -> bool: return present.has(line))
		if written_in.is_empty():
			gone[block] = true
		# Round two or more written: they are written together, in the file's
		# order, so the block is round them and nothing else (_write_one).
		elif written_in.size() > 1:
			for line: int in written_in:
				(out["block_of"] as Dictionary)[line] = block
	var keys: Dictionary = {}
	for table: Dictionary in [kept["order"], heads, ends]:
		for key: String in table:
			keys[key] = true
	for key: String in keys:
		var waiting: Array = []
		var head: Array = _kept_texts(heads.get(key, []), gone)
		if not written.has(key):
			waiting = head.filter(func(line: String) -> bool: return not elsewhere.has(line))
			head = []
		var last: int = -1
		for line: int in (kept["order"] as Dictionary).get(key, []):
			var above: Array = _kept_texts(before.get(line, []), gone)
			var below: Array = _kept_texts(after.get(line, []), gone)
			if present.has(line):
				(out["before"] as Dictionary)[line] = waiting + above
				waiting = []
				if not below.is_empty():
					(out["after"] as Dictionary)[line] = below
				last = line
				continue
			waiting.append_array(above)
			if last >= 0:
				(out["after"] as Dictionary).get_or_add(last, []).append_array(below)
			else:
				waiting.append_array(below)
		var tail: Array = waiting + _kept_texts(ends.get(key, []), gone)
		if written.has(key):
			if not head.is_empty():
				(out["head"] as Dictionary)[key] = head
			if not tail.is_empty():
				(out["end"] as Dictionary)[key] = tail
		elif last >= 0:
			(out["after"] as Dictionary).get_or_add(last, []).append_array(tail)
	return out


## Of [param data] (a file's !DATA pictures, by lower-case file name), those
## a TEXMAP line of [param kept] ([member kept_lines]) names, by a word of it.
static func _pictures_named(kept: Dictionary, data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if data.is_empty():
		return out
	for table: String in ["before", "after", "head", "end"]:
		for at: Variant in kept[table]:
			for item: Array in kept[table][at]:
				var line: String = str(item[0])
				if not line.to_upper().contains("!TEXMAP"):
					continue
				for word: String in _fields(line.strip_edges()):
					var named: String = word.replace("\\", "/").get_file().to_lower()
					if data.has(named):
						out[named] = data[named]
	return out


static func _kept_texts(lines: Array, gone: Dictionary) -> Array:
	var out: Array = []
	for item: Array in lines:
		if int(item[1]) < 0 or not gone.has(int(item[1])):
			out.append(str(item[0]))
	return out


## The line of the file a written part stands for: its origin's last
## (Placement.origin), -1 for one the file never had.
static func kept_line(origin: String) -> int:
	var at: int = origin.rfind("/")
	var last: String = origin.substr(at + 1) if at >= 0 else origin
	return last.to_int() if last.is_valid_int() else -1


## The line placing the copy a part of it with [param origin] is directly
## in: the one before its own in the origin ("12/40" -> 12), -1 for none.
static func kept_copy_line(origin: String) -> int:
	var parts: PackedStringArray = origin.split("/", false)
	if parts.size() < 2:
		return -1
	var said: String = parts[parts.size() - 2]
	return said.to_int() if said.is_valid_int() else -1


## The line of the file each of [param placements] stands for ([method
## kept_line]), in their order: what [method _write_one] writes its kept
## lines beside.
static func _kept_anchors(placements: Array) -> Array:
	return placements.map(func(p: Placement) -> int: return kept_line(p.origin))


## The line placing each copy in [param placements], by its path: the one
## most of the parts directly in it say ([method kept_copy_line]); a part
## brought into it from another copy says that one's.
static func _copy_lines(placements: Array) -> Dictionary:
	var votes: Dictionary = {}       ## path -> {line: how many}
	for item: Variant in placements:
		var placement: Placement = item
		if placement.unit.is_empty():
			continue
		var line: int = kept_copy_line(placement.origin)
		if line >= 0:
			var said: Dictionary = votes.get_or_add(placement.unit, {})
			said[line] = int(said.get(line, 0)) + 1
	var out: Dictionary = {}
	for path: String in votes:
		var best: int = -1
		var most: int = 0
		for line: int in votes[path]:
			if int(votes[path][line]) > most:
				most = int(votes[path][line])
				best = line
		out[path] = best
	return out


## The lines a write writes ([method kept_for]'s present): each part's, and
## each copy's of [param placed] (path -> true) that [param copy_lines] has.
static func _kept_present(placements: Array, copy_lines: Dictionary,
		placed: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in placements:
		var line: int = kept_line((item as Placement).origin)
		if line >= 0:
			out[line] = true
	for path: String in placed:
		if copy_lines.has(path):
			out[int(copy_lines[path])] = true
	return out
