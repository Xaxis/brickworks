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
## The unit step of such a copy (AuthorSteps reads it from here): kept here,
## where the file is read, so reading one names no class of the app's and
## compiles alone, which is what a file browser's picture of a model waits
## for (ModelThumbnail).
const IN_PARENT := -2
## Every FILE section's text but the model's own, by its FILE name in lower
## case: what a part drawn from the file's sections is built from
## (CustomParts.begin_skins), LDCad's donor sections among them.
var section_texts: Dictionary = {}
## The sub-models LDCad generated a flexible part's skin into: sub-model key
## -> [the line of its first `0 !LDCAD GENERATED`, the step it is in].
var generated: Dictionary = {}
## What each of those sub-models' skin is as a part (CustomParts._skin_text),
## by its body: made once an open, where the web looks for what a skin is
## drawn from before it opens (CustomParts.unreached_by) and builds it after.
var skin_texts: Dictionary = {}


## Whether the steps in the file are an author's, to keep: there are steps,
## and they are not ones Brickworks worked out and wrote itself. Every file
## it saved wrote its worked-out order as 0 STEP lines, so other tools see
## a build, and those are no one's steps: kept, a model saved yesterday
## would have a new tower's hundred parts in its last step tomorrow.
func steps_are_authored() -> bool:
	return stepped and not marked_worked \
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

	# A plain .ldr has no FILE lines and is one implicit sub-model.
	var current: SubModel = SubModel.new()
	current.name = source_name
	model.submodels[source_name.to_lower()] = current
	model.main = current

	var step: int = 0
	## The copy the next reference is, from a COPY_META line before it.
	var copy_next: int = 0
	## The copy built in this one's steps the lines now read are of, from an
	## IN_META line: to the next, or the end of the step.
	var within: String = ""
	var first_file: bool = true
	## The FILE section being read, and its lines as written.
	var section: String = ""
	var sections: Dictionary = {}
	## The !DATA section being read, and its base64 so far.
	var data_name: String = ""
	var data := PackedStringArray()

	var index: int = -1
	for raw: String in text.split("\n"):
		index += 1
		var line: String = raw.strip_edges()
		if not data_name.is_empty():
			if line.begins_with("0 !:"):
				data.append(line.substr(4).strip_edges())
				continue
			model.embedded_data[data_name] = Marshalls.base64_to_raw("".join(data))
			data_name = ""
		if line.begins_with("0 !DATA ") or line.begins_with("0 !DATA\t"):
			section = ""
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
			if keyword == "FILE":
				var sub_name: String = " ".join(tokens.slice(2)).strip_edges()
				section = sub_name.to_lower()
				sections[section] = []
				current = SubModel.new()
				current.name = sub_name
				# Keyed the way a reference to it will be looked up.
				# FILE names carry directories and extensions as written
				# and references are reduced to a bare lowercase stem,
				# so a sub-model called "sub/roof.ldr" was stored under
				# that and looked for under "roof" — never found, and
				# the whole sub-assembly silently dropped.
				model.submodels[_key(sub_name)] = current
				step = 0
				within = ""
				if first_file:
					# The first FILE in an .mpd is the model itself; the
					# rest are parts of it.
					model.main = current
					model.submodels.erase(_key(source_name))
					first_file = false
			elif keyword == "STEP" or keyword == "ROTSTEP":
				# A ROTSTEP ends a step as a STEP does, turning the view
				# for the next (MLCad, LPub).
				step += 1
				current.step_count = step + 1
				model.stepped = true
				within = ""
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == AUTHORED_META.get_slice(" ", 2):
				model.marked_authored = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == WORKED_META.get_slice(" ", 2):
				model.marked_worked = true
			elif keyword == "!BRICKWORKS" and tokens.size() > 3 \
					and tokens[2] == COPY_META.get_slice(" ", 2):
				copy_next = maxi(tokens[3].to_int(), 0)
			elif keyword == "!BRICKWORKS" and tokens.size() > 2 \
					and tokens[2] == IN_META.get_slice(" ", 2):
				# A path's names may hold spaces: the rest of the line.
				within = line.substr(line.to_upper().find(keyword) + keyword.length()).strip_edges() \
					.substr(tokens[2].length()).strip_edges()
			elif keyword == "!LDCAD" and tokens.size() > 2 and tokens[2] == "GENERATED" \
					and not model.generated.has(_key(current.name)):
				model.generated[_key(current.name)] = [index, step]
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

		var reference: String = " ".join(tokens.slice(14)).strip_edges()
		reference = reference.replace("\\", "/").to_lower()
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
		copy_next = 0
		current.placements.append(read)

	if not data_name.is_empty():
		model.embedded_data[data_name] = Marshalls.base64_to_raw("".join(data))
	for file_name: String in sections:
		var lines := PackedStringArray(sections[file_name])
		# The first section is the model itself, whatever it is called.
		if file_name == model.main.name.to_lower():
			continue
		var body: String = "\n".join(lines).strip_edges() + "\n"
		model.section_texts[file_name] = body
		var key: String = file_name if file_name.ends_with(".dat") else file_name + ".dat"
		if declares_library_file(lines):
			var named: String = key.replace("\\", "/")
			model.embedded_sources[named] = body
			model.embedded_sources[named.get_file()] = body
		if not _is_part(file_name, lines):
			continue
		model.embedded_parts[key.get_file()] = body
		model.submodels.erase(_key(file_name))
	return model


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
	var tokens: PackedStringArray = line.split(" ", false)
	return tokens.size() >= 2 and tokens[0] == "0" \
		and (tokens[1].to_upper() == "FILE" or tokens[1].to_upper() == "NOFILE"
			or tokens[1].to_upper() == "!DATA")


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


## The name a reference and a FILE line have in common: no directory, no
## extension, lowercase.
static func _key(name: String) -> String:
	var text: String = name.replace("\\", "/").strip_edges().to_lower()
	text = text.get_file()
	for suffix: String in [".ldr", ".dat", ".mpd"]:
		if text.ends_with(suffix):
			return text.substr(0, text.length() - suffix.length())
	return text


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


## Every placement of the main model, with sub-models inlined.
##
## A sub-model reference carries its own transform, so inlining composes
## the two. Recursion is bounded because a model that contains itself is
## malformed and would otherwise hang the loader.
func flatten(known_parts: Dictionary = {}) -> Array[Placement]:
	var out: Array[Placement] = []
	_names = _assembly_names()
	unit_steps.clear()
	unit_frames.clear()
	unit_sections.clear()
	unit_colours.clear()
	unit_lines.clear()
	if main != null:
		_inline(main, Transform3D.IDENTITY, 0, out, known_parts, {}, 0, "", "",
			{})
	return out


## Reflection across x, which with a turn and a shift is every mirrored
## reference.
const REFLECT_X := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
	Vector3.ZERO)

## Sub-model key -> the name its assembly goes by.
var _names: Dictionary = {}


## What each sub-model's assembly is called: its title, or its file name
## where it has none — and the file name too where two share a title, so
## two different sub-models are never taken for copies of one. Never with
## a "/" or a "#", which the path uses.
func _assembly_names() -> Dictionary:
	var by_title: Dictionary = {}
	for key: String in submodels:
		var sub: SubModel = submodels[key]
		var title: String = (sub.title if not sub.title.is_empty() else key) \
			.replace("/", "-").replace("#", "").strip_edges()
		if not by_title.has(title):
			by_title[title] = []
		(by_title[title] as Array).append(key)
	var out: Dictionary = {}
	for title: String in by_title:
		var keys: Array = by_title[title]
		for key: String in keys:
			out[key] = title if keys.size() == 1 else "%s (%s)" % [title, key]
	return out


func _inline(
	sub: SubModel,
	at: Transform3D,
	color: int,
	out: Array[Placement],
	known_parts: Dictionary,
	visiting: Dictionary,
	depth: int,
	group: String,
	unit: String,
	copies: Dictionary
) -> void:
	if depth > 32 or visiting.has(_key(sub.name)):
		push_warning("ldr: %s contains itself; not expanding further" % sub.name)
		return
	visiting[_key(sub.name)] = true
	## Each copy built in this one's steps (Placement.within) -> its path.
	var made: Dictionary = {}

	for placement: Placement in sub.placements:
		var nested: SubModel = submodels.get(_key(placement.part_id))
		# In a copy built in this one's steps: that copy's, as a reference
		# makes one, numbered as the file says where that number is free.
		var own_group: String = group
		var own_unit: String = unit
		if not placement.within.is_empty():
			own_unit = _built_within(placement.within, unit, copies, made)
			if depth == 0:
				own_group = own_unit.get_slice("/", 0).get_slice("#", 0)

		# A name is a sub-model only if it is not a real part: published
		# models occasionally name a sub-assembly after a part number.
		if nested != null and not known_parts.has(placement.part_id):
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
			_inline(
				nested,
				at * placement.transform,
				placement.color_code if placement.color_code != 16 else color,
				out, known_parts, visiting.duplicate(), depth + 1, named,
				inside, copies)
			continue

		var resolved: int = placement.color_code
		if resolved == 16:
			resolved = color
		var placed := Placement.new(
			placement.part_id, resolved, at * placement.transform, placement.step)
		placed.group = own_group
		placed.unit = own_unit
		placed.line = placement.line
		if at.basis.determinant() < 0.0:
			placed.mirrored = true
			placed.local = placement.transform
			placed.frame = at * REFLECT_X
		out.append(placed)

	visiting.erase(sub.name.to_lower())


## The path of the copy [param within] names (IN_META), built in the steps
## of the copy at [param unit]: each of its copies numbered as the file says
## where that number is still free in [param copies], else the next after
## the highest, as a reference's is ([method _inline]); the same path for
## every line of one copy in one reading of [param unit] ([param made]).
## Each is a copy built in its parent's steps (AuthorSteps.IN_PARENT).
func _built_within(within: String, unit: String, copies: Dictionary, made: Dictionary) -> String:
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
	return path


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
## the model 20 LDU higher.
static func write_ldr(
	placements: Array, title: String = "Model", author_name: String = "",
	frames: Dictionary = {}, embedded: Dictionary = {}, parts: Dictionary = {}
) -> String:
	var groups: Array[String] = []
	for item: Variant in placements:
		var group: String = (item as Placement).group
		if not group.is_empty() and not groups.has(group):
			groups.append(group)
	if groups.is_empty() and embedded.is_empty():
		return _write_one(placements, title, author_name, [])

	var main_file: String = title.to_snake_case() + ".ldr"
	var file_of: Dictionary = {}
	for group: String in groups:
		var file: String = group.to_snake_case() + ".ldr"
		while file == main_file or file_of.values().has(file) \
				or parts.has(file.get_basename()):
			file = file.get_basename() + "_.ldr"
		file_of[group] = file
	var loose: Array = placements.filter(func(p: Placement) -> bool:
		return p.group.is_empty())
	var refs: Array[String] = []
	for group: String in groups:
		var frame: Transform3D = frames.get(group, Transform3D.IDENTITY)
		refs.append("1 16 %s %s" % [_line_numbers(frame), str(file_of[group])])
	var text: String = "0 FILE " + main_file + "\n" \
		+ _write_one(loose, title, author_name, refs) + "0 NOFILE\n"
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
## "def": its definition's name, and "first" where it is known: the id of
## its first part, which orders the references of a section}, from
## Assemblies.file_frames and ModelStore. A
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
## naming it (IN_META).
static func write_tree(
	placements: Array, title: String, author_name: String,
	instances: Dictionary, embedded: Dictionary = {}, unit_steps: Dictionary = {},
	parts: Dictionary = {}
) -> String:
	var in_parent := func(path: String) -> bool:
		return int(unit_steps.get(path, -1)) == IN_PARENT
	# The section a path's own parts are written in, and the path within it.
	var home_of := func(path: String) -> String:
		while not path.is_empty() and in_parent.call(path):
			path = "" if path.rfind("/") < 0 else path.substr(0, path.rfind("/"))
		return path
	var within_of := func(path: String, home: String) -> String:
		if path == home:
			return ""
		return path if home.is_empty() else path.substr(home.length() + 1)
	var ordered: Array = instances.keys().filter(func(path: String) -> bool:
		return not in_parent.call(path))
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
	var main_file: String = title.to_snake_case() + ".ldr"
	var file_of: Dictionary = {}
	for def: String in defs:
		var file: String = def.to_snake_case() + ".ldr"
		while file == main_file or file_of.values().has(file) \
				or parts.has(file.get_basename()):
			file = file.get_basename() + "_.ldr"
		file_of[def] = file
	var children: Dictionary = {}    ## the section placing it -> Array of paths
	var placed_within: Dictionary = {}     ## path -> the copy it is placed in there, IN_META
	for path: String in ordered:
		var at: int = path.rfind("/")
		var parent: String = "" if at < 0 else path.substr(0, at)
		var section: String = home_of.call(parent)
		placed_within[path] = within_of.call(parent, section)
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
	var refs := func(parent: String, inverse: Transform3D) -> Array[String]:
		var out: Array[String] = []
		for child: String in children.get(parent, []):
			var entry: Dictionary = instances[child]
			var line: String = "1 16 %s %s" % [_line_numbers(inverse
				* (entry["frame"] as Transform3D)), str(file_of[str(entry["def"])])]
			# Which copy it is, where it is a copy of the definition it
			# places: one that went its own way (Assemblies.file_frames) is
			# the first of a definition of its own.
			var leaf: String = child.get_slice("/", child.count("/"))
			if leaf.get_slice("#", 0) == str(entry["def"]) and leaf.contains("#"):
				line = "%s %d\n%s" % [COPY_META, maxi(leaf.get_slice("#", 1).to_int(), 1), line]
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
		return home_of.call(p.unit) == "")
	var text: String = "0 FILE " + main_file + "\n" \
		+ _write_one(loose, title, author_name, refs.call("", Transform3D.IDENTITY), "",
			ref_steps.call(""), loose.map(func(p: Placement) -> String:
				return within_of.call(p.unit, "")), ref_within.call("")) \
		+ "0 NOFILE\n"
	for def: String in defs:
		var master: String = masters[def]
		var inverse: Transform3D = ((instances[master] as Dictionary)["frame"] as Transform3D) \
			.affine_inverse()
		var own: Array = placements.filter(func(p: Placement) -> bool:
			return home_of.call(p.unit) == master).map(func(p: Placement) -> Placement:
				var local := Placement.new(p.part_id, p.color_code, inverse * p.transform, p.step)
				local.group = p.group
				local.unit = p.unit
				local.within = within_of.call(p.unit, master)
				return local)
		text += "0 FILE " + str(file_of[def]) + "\n" \
			+ _write_one(own, def, author_name, refs.call(master, inverse), str(file_of[def]),
				ref_steps.call(master), own.map(func(p: Placement) -> String: return p.within),
				ref_within.call(master)) \
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


## One file section: its header, then its references to sub-models and its
## parts, step by step, a "0 STEP" between steps. [param ref_steps] gives
## each reference the step it goes on in, as [param placements] carry
## theirs; without them every reference goes first, in the first step. A
## reference was always written first, so a window an author put on in
## step 9 came back put on in step 1. [param within] and [param ref_within]
## name the copy built in this one's steps each part and each reference is
## of, "" for its own: each run of a step's lines of one such copy is
## written after a line naming it (IN_META).
static func _write_one(placements: Array, title: String, author_name: String,
		refs: Array[String], file_name: String = "", ref_steps: Array = [],
		within: Array = [], ref_within: Array = []) -> String:
	var lines := PackedStringArray()
	lines.append("0 " + title)
	lines.append("0 Name: " + (file_name if not file_name.is_empty()
		else title.to_snake_case() + ".ldr"))
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
		# A direct colour goes back out in the form it came in, or it
		# reads as an enormous palette index that nothing has.
		var colour: String = ("0x%07X" % placement.color_code
			if is_direct_colour(placement.color_code)
			else str(placement.color_code))
		items.append([placement.step, 1, n, "1 %s %s %s.dat" % [
			colour, _line_numbers(placement.transform), placement.part_id],
			str(within[n]) if n < within.size() else ""])
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
		if str(item[4]) != inside:
			inside = str(item[4])
			lines.append(IN_META + ("" if inside.is_empty() else " " + inside))
		lines.append(str(item[3]))

	lines.append("0")
	return "\n".join(lines) + "\n"


## The twelve numbers of a type-1 line for a placement.
static func _line_numbers(at: Transform3D) -> String:
	var v: PackedFloat64Array = from_transform(at)
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
		var places: int = 4 if n < 3 else 8
		var shown: String = String.num(value, places) \
			.rstrip("0").rstrip(".")
		numbers.append("0" if shown == "-0" or shown.is_empty() else shown)
	return " ".join(numbers)
