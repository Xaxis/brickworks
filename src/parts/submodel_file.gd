## A sub-model as a file of its own (APP_UX7 #19, subexport): the model
## tree's Export as its own file…, File › Export › Each sub-model, and
## export_model's submodel and submodels over MCP.
##
## Cut from the file File › Export writes for the whole model, never written
## again: a sub-model's file is its section of that file, with every section
## it places (its own sub-models at every depth, and the made parts and
## pictures they carry), each line as the whole model's file has it. So
## whatever the whole model's file keeps of a sub-model (its steps, its
## lights, an author's own lines in someone else's model) its own file keeps
## too, and the two never differ. Of the model's own lines it takes only the
## one saying whose its steps are (AUTHORED or WORKED): without it a
## sub-model of a model stepped by its author opened with its steps worked
## out again.
##
## A copy built in its parent's steps (AuthorSteps.IN_PARENT: the castle's
## towers, a course of each in turn) has no section of its own. Its file is
## its lines out of its parent's, in the steps they are built in, one step of
## its own for each, its own copies inside named from it.
##
## One section alone is written as a plain .ldr, without its FILE line; more
## than one as an .mpd, as the whole model's export names its file
## (ModelBar.ldraw_extension).
##
## Each file is named after its sub-model, by one rule for both kinds
## ([method file_name]), into a name Windows, macOS and Linux all take and
## no unzip puts outside its folder: a copy titled "..\..\evil" was a
## zip entry `..\..\evil.ldr`, which Python's unzip wrote two folders up
## (sereview F1, F6).
class_name SubmodelFile
extends RefCounted

## The most a file's name holds, in UTF-8 bytes: inside every file system's
## 255, with room for the folder an unzip puts it in.
const MOST_BYTES := 200
## Names Windows keeps for its devices, whatever follows a dot ("CON.ldr"
## opens the console; CONIN$ and CONOUT$ its two ends, as Python's
## ntpath.isreserved has them): one is given a "_" ("CON_.ldr").
const RESERVED: Array[String] = ["CON", "CONIN$", "CONOUT$", "PRN", "AUX", "NUL",
	"COM0", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "COM¹", "COM²", "COM³",
	"LPT0", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9", "LPT¹", "LPT²", "LPT³"]
## What Windows refuses in a name. A "/" or "\" in a title is a "_": a
## title's, never a folder's.
const REFUSED := "<>:\"|?*"
## The marks that turn the way text runs, which a name shows and no one
## sees: "x\u202Eexe.ldr" reads "xrdl.exe" (se3check). Left-to-right and
## right-to-left marks, the embeddings, overrides and isolates and their
## ends, Arabic's letter mark, and the byte-order mark.
const TURNS: Array[int] = [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
	0x2066, 0x2067, 0x2068, 0x2069, 0x061C, 0xFEFF]
## The characters Unicode says draw nothing (Default_Ignorable_Code_Point,
## Unicode 15), first and last of each run: the soft hyphen, the combining
## grapheme joiner, Hangul's fillers, Mongolian's vowel separator and
## variation selectors, the zero-width space, joiners and word joiner, the
## variation selectors, the tags. A title of only these, spaces and marks
## was a name of nothing to see before its ".ldr" (se4check).
const UNSEEN: Array[int] = [0x00AD, 0x00AD, 0x034F, 0x034F, 0x061C, 0x061C, 0x115F, 0x1160,
	0x17B4, 0x17B5, 0x180B, 0x180F, 0x200B, 0x200F, 0x202A, 0x202E, 0x2060, 0x206F,
	0x3164, 0x3164, 0xFE00, 0xFE0F, 0xFEFF, 0xFEFF, 0xFFA0, 0xFFA0, 0xFFF0, 0xFFF8,
	0x1BCA0, 0x1BCA3, 0x1D173, 0x1D17A, 0xE0000, 0xE0FFF]
## Spaces of every width (Unicode's White_Space, controls aside).
const SPACES: Array[int] = [0x0020, 0x00A0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004,
	0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000]
## Of [constant UNSEEN], those that format what is around them and so mean
## nothing at a name's end: there a joiner joins nothing (a family of faces
## cut off its last). A variation selector or a tag ends an emoji (a red
## heart, a flag), and stays.
const LOOSE_ENDS: Array[int] = [0x00AD, 0x034F, 0x180E, 0x200B, 0x200C, 0x200D, 0x2060,
	0x2061, 0x2062, 0x2063, 0x2064, 0xE0001]
## The table of each character Unicode also writes as a letter and its marks
## (tools/canonical_forms.py), loaded by [method _one_key] alone.
const CANONICAL := "res://src/parts/canonical_forms.gd"


## One sub-model's file.
class Made extends RefCounted:
	## Its file name: "tower.ldr", "castle_wall.mpd".
	var name: String = ""
	var text: String = ""
	## The sub-model as the tree names it: "Tower".
	var title: String = ""
	## The parts its file places, its sub-models' too, each copy counted.
	var parts: int = 0
	## The sub-models inside it, each definition once.
	var inside: int = 0
	## The steps of its own section.
	var steps: int = 0


## The whole model's file read once, for as many cuts as are asked of it.
class Whole extends RefCounted:
	var lines: PackedStringArray
	var model: LdrModel
	## Every placement, its copy's path and the line it is read from.
	var placed: Array[LdrModel.Placement] = []
	## Each FILE section as LdrModel.parse read it, by its whole name
	## (LdrModel._key) -> [its FILE line, the line after its last] (its
	## NOFILE line in it where it has one); a file of no FILE line, "".
	var sections: Dictionary = {}
	## Its names in the order the file has them.
	var order: Array[String] = []
	var main_key: String = ""
	## !DATA name (lower case) -> [its line, the line after its last].
	var data: Dictionary = {}
	## The model's own line saying whose its steps are, or "".
	var marker: String = ""


## [param text] as File › Export writes it (ModelStore.text_for_file), read
## for cutting; [param known] the library's parts, so a sub-model named as a
## part is read as the model was opened (LdrModel.flatten).
static func read(text: String, known: Dictionary = {}) -> Whole:
	var whole := Whole.new()
	whole.lines = text.split("\n")
	whole.model = LdrModel.parse(text, "model")
	whole.placed = whole.model.flatten(known)
	# Each section where the model's own reading found it, so of two of one
	# key the one the model is built of: read again here, the first was cut
	# while the model was built of the last, and 345-1's House reopened 115
	# of its 116 parts (sereview F3).
	for name: String in whole.model.files:
		var span: Vector2i = (whole.model.files[name] as LdrModel.SubModel).span
		whole.sections[name] = [span.x, span.y]
		whole.order.append(name)
	if whole.order.is_empty():
		whole.sections[""] = [0, whole.lines.size()]
		whole.order.append("")
	else:
		whole.main_key = whole.model.main_key
		whole.sections[whole.main_key] = [whole.model.main.span.x, whole.model.main.span.y]
		whole.order.sort_custom(func(a: String, b: String) -> bool:
			return int(whole.sections[a][0]) < int(whole.sections[b][0]))
	# The pictures the file carries (!DATA), each to the next section's line.
	var data_name: String = ""
	for n: int in whole.lines.size():
		var word: String = LdrModel.section_word(whole.lines[n])
		if word.is_empty():
			continue
		if not data_name.is_empty():
			(whole.data[data_name] as Array)[1] = n
			data_name = ""
		var fields: PackedStringArray = LdrModel._fields(whole.lines[n].strip_edges())
		if word == "!DATA" and fields.size() > 2:
			data_name = " ".join(fields.slice(2)).get_file().to_lower()
			whole.data[data_name] = [n, whole.lines.size()]
	var main: Array = whole.sections[whole.main_key]
	for n: int in range(int(main[0]), int(main[1])):
		var line: String = whole.lines[n].strip_edges()
		if line == LdrModel.AUTHORED_META or line == LdrModel.WORKED_META:
			whole.marker = line
			break
	return whole


## The paths of the copies the model places, as its tree has them.
static func paths(whole: Whole) -> PackedStringArray:
	var out := PackedStringArray(whole.model.unit_steps.keys())
	out.sort()
	return out


## The file of the sub-model at [param path] (a copy's path in the model
## tree: "Castle#1/Wing#2"); null when the whole model's file places no such
## copy.
static func cut(whole: Whole, path: String) -> Made:
	if not whole.model.unit_steps.has(path):
		return null
	if int(whole.model.unit_steps[path]) == LdrModel.IN_PARENT:
		return _cut_built_within(whole, path)
	var key: String = _section_of_copy(whole, path)
	if not whole.sections.has(key) or key == whole.main_key:
		return null
	var keys: Array[String] = _placed_from([key], whole)
	var made := Made.new()
	made.title = Assemblies.definition(Assemblies.leaf(path))
	var first: Array = whole.sections[key]
	var named: String = whole.lines[int(first[0])].strip_edges()
	made.name = file_name(" ".join(LdrModel._fields(named).slice(2)), keys.size() > 1)
	var out := PackedStringArray()
	for each: String in keys:
		var span: Array = whole.sections[each]
		var from: int = int(span[0])
		var to: int = int(span[1])
		if keys.size() == 1:
			# One section: a plain .ldr, its FILE and NOFILE lines left out.
			from += 1
			if to > from and LdrModel.section_word(whole.lines[to - 1]) == "NOFILE":
				to -= 1
		var lines: PackedStringArray = whole.lines.slice(from, to)
		if each == key:
			lines = _marked(lines, whole.marker, keys.size() == 1)
		out.append_array(lines)
	out.append_array(_data_for(out, whole))
	made.text = _ended("\n".join(out))
	_count(made, whole, path)
	made.steps = _steps_in(whole, key) + 1
	return made


## Each sub-model of the model, each definition once (a copy of one is the
## same file), in the order the tree lists them; a copy built in its
## parent's steps once by its name.
static func each(whole: Whole) -> Array[Made]:
	var out: Array[Made] = []
	var done: Dictionary = {}
	var names: Dictionary = {}
	for path: String in paths(whole):
		var built_within: bool = int(whole.model.unit_steps[path]) == LdrModel.IN_PARENT
		var which: String = ("in " + Assemblies.definition(Assemblies.leaf(path))) if built_within \
			else "section " + str(whole.model.unit_sections.get(path, ""))
		if done.has(which):
			continue
		done[which] = true
		var made: Made = cut(whole, path)
		if made == null:
			continue
		# Two of one name (a copy built in its parent's steps named as a
		# section is, or two that one rule made one): the second "_2",
		# whatever the case, and written either way Unicode writes a letter
		# with an accent, as Windows and macOS see one name. "Café" written
		# as one letter and as "e" and its accent were two members that
		# every libarchive unzip (bsdtar, Windows' and macOS's tar) made one
		# file, the second over the first, unsaid (se3check); a macOS disk
		# takes them as one too. "Cafe" and "Café" are two names to all of
		# them, and stay so ([method _one_key]).
		var base: String = made.name.get_basename()
		var name: String = made.name
		var n: int = 1
		while names.has(_one_key(name)):
			n += 1
			var suffix: String = "_%d.%s" % [n, made.name.get_extension()]
			name = _capped(base, MOST_BYTES - suffix.to_utf8_buffer().size()) + suffix
		names[_one_key(name)] = true
		made.name = name
		out.append(made)
	return out


## What two names that a file system or an unzip takes as one have alike:
## each character as Unicode writes it as a letter and its marks (its
## canonical decomposition, [constant CANONICAL]; a Hangul syllable its
## letters), the marks on one letter in one order, in lower case. So "Café"
## as one letter and as "e" and U+0301 are one; "Cafe" and "Café", "Ma",
## "Má" and "Mạ", かっこう and がっこう are two, as they are to every disk
## and unzip: the key stripped every accent, and the second of each pair
## was named "_2" (se4check). Two names alike but for the order of two
## marks of one kind ("a" with an acute then a grave, and a grave then an
## acute), which Unicode keeps apart, are taken as one: the second is named
## "_2", and nothing is lost.
static func _one_key(name: String) -> String:
	var plain: bool = true
	for n: int in name.length():
		if name.unicode_at(n) >= 0x80:
			plain = false
			break
	if plain:
		return name.to_lower()
	var table: Dictionary = (load(CANONICAL) as GDScript).get_script_constant_map()["DECOMPOSED"]
	var spelled: String = ""
	for n: int in name.length():
		var code: int = name.unicode_at(n)
		if code >= 0xAC00 and code <= 0xD7A3:
			# A Hangul syllable: its leading consonant, vowel and final one.
			var at: int = code - 0xAC00
			spelled += String.chr(0x1100 + at / 588) + String.chr(0x1161 + (at % 588) / 28)
			if at % 28 != 0:
				spelled += String.chr(0x11A7 + at % 28)
		else:
			spelled += str(table.get(code, name[n]))
	var server: TextServer = TextServerManager.get_primary_interface()
	var out: String = ""
	var marks: Array[int] = []
	for n: int in spelled.length():
		# A mark that sits on a letter (one Unicode orders): strip_diacritics
		# takes it away whole.
		if server.strip_diacritics(spelled[n]).is_empty():
			marks.append(spelled.unicode_at(n))
			continue
		out += _in_order(marks) + spelled[n]
		marks.clear()
	return (out + _in_order(marks)).to_lower()


static func _in_order(marks: Array[int]) -> String:
	marks.sort()
	var out: String = ""
	for code: int in marks:
		out += String.chr(code)
	return out


## [param keys] and every section their lines place, at every depth, in the
## order the file has them, [param keys] first.
static func _placed_from(keys: Array[String], whole: Whole) -> Array[String]:
	var found: Dictionary = {}
	for key: String in keys:
		found[key] = true
	var waiting: Array[String] = keys.duplicate()
	while not waiting.is_empty():
		var key: String = waiting.pop_back()
		var span: Array = whole.sections[key]
		for n: int in range(int(span[0]) + 1, int(span[1])):
			for placed: String in _sections_of(whole, _placed_by(whole.lines[n])):
				if found.has(placed) or placed == whole.main_key:
					continue
				found[placed] = true
				waiting.append(placed)
	var out: Array[String] = keys.duplicate()
	for key: String in whole.order:
		if found.has(key) and not out.has(key):
			out.append(key)
	return out


## What a line places, as it names it ("1 16 0 0 0 1 0 0 0 1 0 0 0 1
## wing.ldr" -> "wing.ldr"), a line hidden by MLCad, LPub's ghost or a
## picture's fallback geometry too; "" for any other line. Its name as
## written (LdrModel.reference_of), so "wing  part.ldr" is not "wing part.ldr".
static func _placed_by(raw: String) -> String:
	var line: String = raw.lstrip(LdrModel.SPACE).rstrip(LdrModel.SPACE)
	for before: String in ["0 !:", "0 MLCAD HIDE", "0 GHOST"]:
		if line.to_upper().begins_with(before):
			line = line.substr(before.length()).lstrip(LdrModel.SPACE)
			break
	if not line.begins_with("1"):
		return ""
	var fields: PackedStringArray = LdrModel._fields(line)
	if fields.size() < 15 or fields[0] != "1":
		return ""
	return LdrModel.reference_of(line)


## The sections of the whole file a reference to [param reference] is read
## as: the section of its name (LdrModel._key: as written, in any case, "\"
## as "/"), the first block of a name, as the app's open, LDView and LDCad
## all read it now. Else a part's own file the file carries under another
## folder, the last of its file name, as the app finds one (CustomParts.needs),
## or of its number. [] for none.
static func _sections_of(whole: Whole, reference: String) -> Array[String]:
	var out: Array[String] = []
	if reference.is_empty():
		return out
	var named: String = LdrModel._key(reference)
	if whole.sections.has(named):
		out.append(named)
		return out
	var found: String = ""
	for each: String in whole.order:
		if each.get_file() == named.get_file():
			found = each
	if found.is_empty():
		var number: String = LdrModel.stem(reference)
		for each: String in whole.order:
			if LdrModel.stem(each) == number:
				found = each
	if not found.is_empty():
		out.append(found)
	return out


## The section the copy at [param path] is built of: its sub-model's, as
## the model was built of it (LdrModel.unit_sections, the key it was found
## by).
static func _section_of_copy(whole: Whole, path: String) -> String:
	var sub: LdrModel.SubModel = whole.model.submodels.get(
		str(whole.model.unit_sections.get(path, "")))
	return LdrModel._key(sub.name) if sub != null else ""


## Each !DATA block a line of [param lines] names (a picture a print is
## drawn with), as the whole file has it.
static func _data_for(lines: PackedStringArray, whole: Whole) -> PackedStringArray:
	var out := PackedStringArray()
	if whole.data.is_empty():
		return out
	var text: String = "\n".join(lines).to_lower()
	var names: Array = whole.data.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(whole.data[a][0]) < int(whole.data[b][0]))
	for name: String in names:
		if text.contains(name):
			var span: Array = whole.data[name]
			out.append_array(whole.lines.slice(int(span[0]), int(span[1])))
	return out


## [param lines] (a section's, its FILE line first unless [param bare]) with
## the model's [param marker] after its header's Author line (or its Name
## line, or its title), unless it has one; each line ending as theirs do.
static func _marked(lines: PackedStringArray, marker: String, bare: bool) -> PackedStringArray:
	if marker.is_empty():
		return lines
	var at: int = -1
	var start: int = 0 if bare else 1
	for n: int in range(start, lines.size()):
		var line: String = lines[n].strip_edges()
		if line == LdrModel.AUTHORED_META or line == LdrModel.WORKED_META:
			return lines
		if line.begins_with("1") or line.begins_with("0 STEP") or line.begins_with("0 ROTSTEP"):
			break
		if line.begins_with("0 Author:") or line.begins_with("0 AUTHOR:"):
			at = n
			break
		if line.begins_with("0 Name:") or n == start:
			at = n
	var out: PackedStringArray = lines.duplicate()
	var eol: String = "\r" if at >= 0 and lines[at].ends_with("\r") else ""
	out.insert(at + 1 if at >= 0 else start, marker + eol)
	return out


## The file a sub-model [param named] is written as (a FILE line's name,
## "sub\Wing.ldr", or a title, "north_east_tower"): .mpd when [param many]
## sections go in it, else .ldr; what follows the last "/" or "\" of a
## FILE line's name, a folder there, by [method _safe_name].
static func file_name(named: String, many: bool) -> String:
	var bare: String = named.replace("\\", "/").get_file()
	if bare.get_extension().to_lower() in ["ldr", "dat", "mpd"]:
		bare = bare.get_basename()
	return _safe_name(bare, ".mpd" if many else ".ldr", "submodel")


## The file the app writes named after [param title], a model's or a list's
## (File › Export's of every kind, a picture, a render, the instructions, a
## parts list), [param tail] its suffix and extension ("_submodels.zip",
## ".ldr"): the title's words joined by "_" as every export has named them,
## by [method _safe_name]; [param none] when nothing is left. One rule for
## every file the app names, a sub-model's too: "My: Castle?" was
## my:_castle?_submodels.zip, which Windows refuses or keeps in a stream
## after the ":", and a title 300 letters long a name of 314 bytes, which
## no file system takes and over MCP failed to write (se3check).
static func titled(title: String, tail: String, none: String = "model") -> String:
	return _safe_name(_trimmed(title).to_snake_case(), tail, none)


## The file named after [param title] as it is written, its case and its
## spaces kept, where a person names it: Save as's suggestion, the sticker
## sheet ("My Castle stickers.pdf"). [param tail] and [param none] as
## [method titled]'s. They kept only what followed a title's last "/":
## "AC/DC" was offered as DC.mpd, "1/2 Scale Tower" as "2 Scale Tower.mpd"
## (se4check).
static func named(title: String, tail: String, none: String = "model") -> String:
	return _safe_name(title, tail, none)


## [param words] then [param tail] as a name every system takes as a file's,
## of at most [constant MOST_BYTES] UTF-8 bytes: without control
## characters, [constant TURNS] or [constant REFUSED], a "/" or "\" a "_"
## (a title's, never a folder's: one function kept what followed the last,
## and named AC/DC's file DC.mpd), its ends trimmed ([method _trimmed]),
## cut on a whole character as a reader sees one ([method _capped]);
## [param none] when nothing is left to see ([method _shows]); a
## [constant RESERVED] name given a "_", looked for in the whole name with
## its tail, as Windows does: "CON" is con_.mpd and con_instructions.html,
## which is no device's.
static func _safe_name(words: String, tail: String, none: String) -> String:
	var room: int = MOST_BYTES - tail.to_utf8_buffer().size()
	var kept: String = ""
	for n: int in words.length():
		var code: int = words.unicode_at(n)
		if code < 32 or (code >= 127 and code < 160) or code in TURNS or REFUSED.contains(words[n]):
			continue
		kept += "_" if code == 0x2F or code == 0x5C else words[n]
	kept = _trimmed(_capped(_trimmed(kept), room))
	if not _shows(kept):
		kept = none
	# A device's name looked for after the cut, which may leave one ("CON",
	# 300 spaces, "x"), and cut again once given its "_", which may take it
	# past the room ("aux." and 100 城); a cut only takes from the end.
	var device: String = (kept + tail).get_slice(".", 0).rstrip(" ")
	if device.to_upper() in RESERVED and device.length() <= kept.length():
		kept = _trimmed(_capped(device + "_" + kept.substr(device.length()), room))
	return kept + tail


## Whether [param text] has a character to see: not only [constant UNSEEN]
## ones, spaces and marks with nothing under them. A title of zero-width
## spaces and joiners, or of a soft hyphen, the combining grapheme joiner
## and Mongolian's vowel separator, was a name of nothing before its ".ldr"
## (se4check).
static func _shows(text: String) -> bool:
	# Never strip_diacritics(""): ICU says the empty string is not ended, and
	# Godot prints that as an error.
	if text.is_empty():
		return false
	var letters: String = TextServerManager.get_primary_interface().strip_diacritics(text)
	for n: int in letters.length():
		var code: int = letters.unicode_at(n)
		if not _in_runs(code, UNSEEN) and not code in SPACES:
			return true
	return false


## [param text] with what its ends may not have taken off: dots and spaces
## (".." is the folder above; a name ending so Windows cannot open, one
## starting with a dot macOS and Linux hide); first, a [constant UNSEEN]
## character or a mark, with nothing before it to join or sit on; last, a
## [constant LOOSE_ENDS] one.
static func _trimmed(text: String) -> String:
	var from: int = 0
	var to: int = text.length()
	var server: TextServer = TextServerManager.get_primary_interface()
	while from < to:
		var code: int = text.unicode_at(from)
		if code != 0x2E and not code in SPACES and not _in_runs(code, UNSEEN) \
				and not server.strip_diacritics(text[from]).is_empty() and code > 32:
			break
		from += 1
	while to > from:
		var code: int = text.unicode_at(to - 1)
		if code != 0x2E and not code in SPACES and not code in LOOSE_ENDS and code > 32:
			break
		to -= 1
	return text.substr(from, to - from)


## Whether [param code] is in one of [param runs], first and last of each.
static func _in_runs(code: int, runs: Array[int]) -> bool:
	for n: int in range(0, runs.size(), 2):
		if code >= runs[n] and code <= runs[n + 1]:
			return true
	return false


## [param text] cut to at most [param room] UTF-8 bytes, between two
## characters as a reader sees them (TextServer's grapheme breaks): a が
## written as か and its mark, an é as e and its accent, a family of faces
## joined by zero-width joiners, each kept whole or left out. Cut on a code
## point, the first lost its mark and the last ended in a bare joiner
## (se4check).
static func _capped(text: String, room: int) -> String:
	if text.to_utf8_buffer().size() <= room:
		return text
	var used: int = 0
	var kept: int = 0
	for end: int in TextServerManager.get_primary_interface().string_get_character_breaks(text):
		used += text.substr(kept, end - kept).to_utf8_buffer().size()
		if used > room:
			break
		kept = end
	return text.left(kept)


static func _ended(text: String) -> String:
	return text if text.ends_with("\n") else text + "\n"


## How many 0 STEP or ROTSTEP lines [param key]'s section has.
static func _steps_in(whole: Whole, key: String) -> int:
	var span: Array = whole.sections[key]
	var count: int = 0
	for n: int in range(int(span[0]) + 1, int(span[1])):
		if _is_step(whole.lines[n]):
			count += 1
	return count


static func _is_step(raw: String) -> bool:
	var fields: PackedStringArray = LdrModel._fields(raw.strip_edges())
	return fields.size() >= 2 and fields[0] == "0" \
		and (fields[1].to_upper() == "STEP" or fields[1].to_upper() == "ROTSTEP")


## The parts in the copy at [param path] and the sub-models inside it.
static func _count(made: Made, whole: Whole, path: String) -> void:
	for placement: LdrModel.Placement in whole.placed:
		if Assemblies.within(placement.unit, path):
			made.parts += 1
	var kinds: Dictionary = {}
	for unit: String in whole.model.unit_steps:
		if unit != path and Assemblies.within(unit, path):
			kinds[Assemblies.definition(Assemblies.leaf(unit))] = true
	made.inside = kinds.size()


## A copy built in its parent's steps: its lines out of the section they are
## written in, its own copies' references with them, a step for each step of
## that section they are in; its own copies built within it named from it.
static func _cut_built_within(whole: Whole, path: String) -> Made:
	var home: String = path
	while not home.is_empty() and int(whole.model.unit_steps.get(home, 0)) == LdrModel.IN_PARENT:
		home = Assemblies.parent_of(home)
	var key: String = whole.main_key if home.is_empty() else _section_of_copy(whole, home)
	if not whole.sections.has(key):
		return null
	var span: Array = whole.sections[key]
	# Line -> the copy it is of: each of its parts, and each reference to a
	# copy inside it with a section of its own.
	var taken: Dictionary = {}
	for placement: LdrModel.Placement in whole.placed:
		if placement.line >= int(span[0]) and placement.line < int(span[1]) \
				and Assemblies.within(placement.unit, path):
			taken[placement.line] = placement.unit
	for unit: String in whole.model.unit_lines:
		var line: int = int(whole.model.unit_lines[unit])
		if unit != path and Assemblies.within(unit, path) and line >= int(span[0]) \
				and line < int(span[1]) and int(whole.model.unit_steps.get(unit, 0)) != LdrModel.IN_PARENT:
			taken[line] = Assemblies.parent_of(unit)
	var made := Made.new()
	made.title = Assemblies.definition(Assemblies.leaf(path))
	var eol: String = "\r" if whole.lines[int(span[0])].ends_with("\r") else ""
	var author: String = "0 Author: Brickworks"
	for n: int in range(int(span[0]), int(span[1])):
		var line: String = whole.lines[n].strip_edges()
		if line.begins_with("1") or _is_step(line):
			break
		if line.begins_with("0 Author:"):
			author = line
			break
	var body := PackedStringArray()
	var references: Array[String] = []
	var steps: int = 0
	var in_step: bool = false
	var inside: String = ""
	for n: int in range(int(span[0]) + 1, int(span[1])):
		if _is_step(whole.lines[n]):
			inside = ""
			if in_step:
				in_step = false
				steps += 1
			continue
		if not taken.has(n):
			continue
		if not in_step and steps > 0:
			body.append("0 STEP" + eol)
		in_step = true
		# Its own copies built in its steps, named from it as the file named
		# them from the section ("IN north-east tower#1/turret#1" -> "IN turret#1").
		var unit: String = str(taken[n])
		var own: String = "" if unit == path else unit.substr(path.length() + 1)
		if own != inside:
			body.append(LdrModel.IN_META + (" " + own if not own.is_empty() else "") + eol)
			inside = own
		var before: String = whole.lines[n - 1].strip_edges() if n > 0 else ""
		if before.begins_with(LdrModel.COPY_META):
			body.append(whole.lines[n - 1])
		body.append(whole.lines[n])
		for placed: String in _sections_of(whole, _placed_by(whole.lines[n])):
			if placed != whole.main_key and not references.has(placed):
				references.append(placed)
	var keys: Array[String] = _placed_from(references, whole) if not references.is_empty() \
		else ([] as Array[String])
	# Named as a section's file is, and its FILE and Name lines so: titled
	# "..\..\evil", it was all three (sereview F1).
	made.name = file_name(made.title.to_snake_case(), not keys.is_empty())
	var own_name: String = made.name.get_basename()
	var head := PackedStringArray(["0 " + made.title + eol,
		"0 Name: " + own_name + ".ldr" + eol, author + eol])
	if not whole.marker.is_empty():
		head.append(whole.marker + eol)
	head.append(eol)
	var out := PackedStringArray()
	if not keys.is_empty():
		out.append("0 FILE " + own_name + ".ldr" + eol)
	out.append_array(head)
	out.append_array(body)
	if not keys.is_empty():
		out.append("0 NOFILE" + eol)
		for each: String in keys:
			var at: Array = whole.sections[each]
			out.append_array(whole.lines.slice(int(at[0]), int(at[1])))
	out.append_array(_data_for(out, whole))
	made.text = _ended("\n".join(out))
	_count(made, whole, path)
	made.steps = steps + (1 if in_step else 0)
	return made
