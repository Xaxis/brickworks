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
	var first_file: bool = true
	## The FILE section being read, and its lines as written.
	var section: String = ""
	var sections: Dictionary = {}

	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
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
				if first_file:
					# The first FILE in an .mpd is the model itself; the
					# rest are parts of it.
					model.main = current
					model.submodels.erase(_key(source_name))
					first_file = false
			elif keyword == "STEP":
				step += 1
				current.step_count = step + 1
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

		current.placements.append(
			Placement.new(part_id, color, to_transform(numbers), step))

	for file_name: String in sections:
		var lines := PackedStringArray(sections[file_name])
		# The first section is the model itself, whatever it is called.
		if file_name == model.main.name.to_lower() or not _is_part(file_name, lines):
			continue
		var key: String = file_name if file_name.ends_with(".dat") else file_name + ".dat"
		model.embedded_parts[key.get_file()] = "\n".join(lines).strip_edges() + "\n"
		model.submodels.erase(_key(file_name))
	return model


static func _is_file_line(line: String) -> bool:
	var tokens: PackedStringArray = line.split(" ", false)
	return tokens.size() >= 2 and tokens[0] == "0" \
		and (tokens[1].to_upper() == "FILE" or tokens[1].to_upper() == "NOFILE")


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
		# again. The palette has no entry for it and whatever draws it
		# will fall back, which is a visible approximation rather than a
		# silent one.
		return text.hex_to_int()
	return UNREADABLE_COLOUR


## Whether a colour code is an RGB value written into the file rather
## than an index into the palette.
static func is_direct_colour(code: int) -> bool:
	return code >= 0x2000000


## The name a reference and a FILE line have in common: no directory, no
## extension, lowercase.
static func _key(name: String) -> String:
	var text: String = name.replace("\\", "/").strip_edges().to_lower()
	text = text.get_file()
	for suffix: String in [".ldr", ".dat", ".mpd"]:
		if text.ends_with(suffix):
			return text.substr(0, text.length() - suffix.length())
	return text


## The fields of a line, split on any run of whitespace.
static func _fields(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var token: String = ""
	for n: int in line.length():
		var c: String = line[n]
		if c == " " or c == "\t" or c == "\r":
			if not token.is_empty():
				out.append(token)
				token = ""
		else:
			token += c
	if not token.is_empty():
		out.append(token)
	return out


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
	if main != null:
		_inline(main, Transform3D.IDENTITY, 0, out, known_parts, {}, 0, "")
	return out


func _inline(
	sub: SubModel,
	at: Transform3D,
	color: int,
	out: Array[Placement],
	known_parts: Dictionary,
	visiting: Dictionary,
	depth: int,
	group: String
) -> void:
	if depth > 32 or visiting.has(_key(sub.name)):
		push_warning("ldr: %s contains itself; not expanding further" % sub.name)
		return
	visiting[_key(sub.name)] = true

	for placement: Placement in sub.placements:
		var nested: SubModel = submodels.get(_key(placement.part_id))

		# A name is a sub-model only if it is not a real part: published
		# models occasionally name a sub-assembly after a part number.
		if nested != null and not known_parts.has(placement.part_id):
			# A sub-model referenced by the model itself is one of its
			# assemblies; what that sub-model nests stays part of it.
			var named: String = group
			if depth == 0:
				named = (nested.title if not nested.title.is_empty()
					else _key(nested.name))
			_inline(
				nested,
				at * placement.transform,
				placement.color_code if placement.color_code != 16 else color,
				out, known_parts, visiting.duplicate(), depth + 1, named)
			continue

		var resolved: int = placement.color_code
		if resolved == 16:
			resolved = color
		var placed := Placement.new(
			placement.part_id, resolved, at * placement.transform, placement.step)
		placed.group = group
		out.append(placed)

	visiting.erase(sub.name.to_lower())


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
static func write_ldr(
	placements: Array, title: String = "Model", author_name: String = "",
	frames: Dictionary = {}, embedded: Dictionary = {}
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
		while file == main_file or file_of.values().has(file):
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
		text += "0 FILE " + str(part_name) + "\n" \
			+ str(embedded[part_name]).strip_edges() + "\n0 NOFILE\n"
	return text


static func _write_one(placements: Array, title: String, author_name: String,
		refs: Array[String], file_name: String = "") -> String:
	var lines := PackedStringArray()
	lines.append("0 " + title)
	lines.append("0 Name: " + (file_name if not file_name.is_empty()
		else title.to_snake_case() + ".ldr"))
	if not author_name.is_empty():
		lines.append("0 Author: " + author_name)
	lines.append("")
	lines.append_array(PackedStringArray(refs))

	var step: int = -1
	for item: Variant in placements:
		var placement: Placement = item
		if placement.step != step:
			if step >= 0:
				lines.append("0 STEP")
			step = placement.step
		# A direct colour goes back out in the form it came in, or it
		# reads as an enormous palette index that nothing has.
		var colour: String = ("0x%07X" % placement.color_code
			if is_direct_colour(placement.color_code)
			else str(placement.color_code))
		lines.append("1 %s %s %s.dat" % [
			colour, _line_numbers(placement.transform), placement.part_id])

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
		var places: int = 4 if n < 3 else 8
		var shown: String = String.num(value, places) \
			.rstrip("0").rstrip(".")
		numbers.append("0" if shown == "-0" or shown.is_empty() else shown)
	return " ".join(numbers)
