## A saved model put into the one open, read as a file of its own whose
## every name is free here (File, Import, Into this model…; the library's
## Put in this model; open_model into=true). Its model becomes a sub-model
## of this one, named as it was saved ("Shed"), and each name it defines
## that this model has taken (Assemblies.names_taken: a sub-model, a part
## file it carries, a file that part is drawn from, a picture) is given a
## free one (Names.free_name: "Window 2", "oddpart_2.dat"), renamed through its
## FILE and Name lines, its title, every reference to it, its pictures'
## TEXMAP and booklet lines, and the paths and joints that name a
## sub-model. A part file the model holds as it is, word for word, is the
## same part and keeps its name. What comes out is opened as any file is
## (ModelStore.held_from), so the model put in is held as an open holds a
## model, and saved as one is: two of one name was how a model put in took
## the host's own sub-model, part file or picture, or a second model's of
## the first (imreview 1, im2review hostodd, twoodd, windowdat).
class_name IntoModel
extends RefCounted


class Block extends RefCounted:
	## "file" (a FILE section), "data" (a !DATA picture) or "" (lines before
	## any, or after a NOFILE).
	var kind: String = ""
	var name: String = ""
	## Its lines' range in the text: [start, end).
	var start: int = 0
	var end: int = 0
	## A part, subpart or primitive by its header, not a sub-model.
	var part: bool = false


## [param text] (a model's file, called [param file_name]) with every name
## it defines free of [param taken] (Names keys, which it takes in turn),
## its model's own named [param called] where given, else as its title says.
## A file of no FILE sections is put in one. [param shares] (name, its text
## or bytes) says whether this model holds a part file, a file a part is
## drawn from or a picture of that name word for word, which keeps its name.
## {"text" ("\n" line ends), "def" (its model's name as a sub-model here),
## "file" (its section's file name), "defs" (each sub-model's name in the
## file -> its name here, its own model's by ""), "files" (each section's
## and picture's key, LdrModel._key, -> its name here, those renamed),
## "error"}.
static func renamed(text: String, file_name: String, taken: Dictionary, called: String = "",
		shares: Callable = Callable()) -> Dictionary:
	var out: Dictionary = {"text": "", "def": "", "file": "", "defs": {}, "files": {}, "error": ""}
	text = text.trim_prefix(LdrModel.bom()).replace("\r\n", "\n")
	var model: LdrModel = LdrModel.parse(text, file_name)
	if model == null or model.main == null:
		out["error"] = "that is not an LDraw file"
		return out
	var lines: PackedStringArray = text.split("\n")
	var own_title: String = called.strip_edges() if not called.strip_edges().is_empty() \
		else ModelStore._title_of(model, file_name)
	if own_title == ModelStore.UNTITLED:
		own_title = "Model"
	# A file of no FILE sections is its model's section of its own.
	if not model.has_file_lines:
		var end: int = lines.size()
		for n: int in lines.size():
			if LdrModel.section_word(lines[n]) == "!DATA":
				end = n
				break
		while end > 0 and lines[end - 1].strip_edges().is_empty():
			end -= 1
		var head := PackedStringArray(["0 FILE " + LdrModel.new_file_name(own_title)])
		lines = head + lines.slice(0, end) + PackedStringArray(["0 NOFILE"]) + lines.slice(end)
	var blocks: Array[Block] = _blocks(lines)
	var names: Dictionary = model._assembly_names()
	var main_block: Block = null
	for block: Block in blocks:
		if block.kind == "file":
			main_block = block
			break
	if main_block == null:
		out["error"] = "that is not an LDraw file"
		return out
	# Who is who: each sub-model by its definition and file name, each part
	# file and picture by its name.
	var wanted: Array = []      ## [block, the name it goes by, its file name]
	for block: Block in blocks:
		if block.kind == "data":
			wanted.append([block, "", block.name])
		elif block.kind == "file":
			block.part = block != main_block and LdrModel.declares_library_file(
				lines.slice(block.start + 1, mini(block.end, block.start + 17)))
			if block == main_block:
				wanted.append([block, own_title, block.name])
			elif block.part:
				wanted.append([block, "", block.name])
			else:
				var key: String = LdrModel._key(block.name)
				wanted.append([block, str(names.get(key, LdrModel.stem(block.name))), block.name])
	# Taken first, each name this model has not got: a name given to one
	# renamed is never one the file uses itself.
	var clash: Dictionary = {}
	var host: Dictionary = taken.duplicate()
	for entry: Array in wanted:
		var block: Block = entry[0]
		var def: String = entry[1]
		var name: String = entry[2]
		var shared: bool = (block.kind == "data" or block.part) and Names.is_taken(name, host) \
			and shares.is_valid() and bool(shares.call(name, _content(lines, block)))
		if not shared and (Names.is_taken(name, host) or not def.is_empty() and Names.is_taken(def, host)):
			clash[block] = true
	for entry: Array in wanted:
		var block: Block = entry[0]
		if not clash.has(block):
			Names.take(str(entry[1]), taken)
			Names.take(str(entry[2]), taken)
	var defs: Dictionary = {}       ## old definition -> new
	var files: Dictionary = {}      ## old key -> new name
	var titled: Dictionary = {}     ## block -> its new title
	for entry: Array in wanted:
		var block: Block = entry[0]
		var def: String = entry[1]
		var name: String = entry[2]
		if not clash.has(block):
			if block == main_block:
				# Its model's title is the sub-model's name here, whatever the
				# file called it ("Shed", as it was saved).
				defs[""] = def
				titled[block] = def
			elif not def.is_empty():
				defs[def] = def
			continue
		if def.is_empty():
			files[LdrModel._key(name)] = Names.free_name(name, taken, true)
			continue
		var pair: Array = _free_pair(def, name, taken)
		defs["" if block == main_block else def] = pair[0]
		titled[block] = pair[0]
		if LdrModel._key(pair[1]) != LdrModel._key(name):
			files[LdrModel._key(name)] = pair[1]
	out["defs"] = defs
	out["files"] = files
	out["def"] = defs.get("", own_title)
	out["file"] = files.get(LdrModel._key(main_block.name), main_block.name)
	var pictures: Dictionary = {}   ## old picture key -> new name
	for block: Block in blocks:
		if block.kind == "data" and files.has(LdrModel._key(block.name)):
			pictures[LdrModel._key(block.name)] = files[LdrModel._key(block.name)]
	out["text"] = "\n".join(_written(lines, blocks, files, defs, titled, pictures, main_block))
	return out


## The lines of [param lines] that begin and end each FILE and !DATA section.
static func _blocks(lines: PackedStringArray) -> Array[Block]:
	var out: Array[Block] = []
	var open: Block = null
	for n: int in lines.size():
		var word: String = LdrModel.section_word(lines[n])
		if word.is_empty():
			continue
		if open != null:
			open.end = n if word != "NOFILE" else n + 1
			out.append(open)
			open = null
		if word == "FILE" or word == "!DATA":
			open = Block.new()
			open.kind = "file" if word == "FILE" else "data"
			open.name = LdrModel.file_name_of(lines[n].strip_edges()) if word == "FILE" \
				else lines[n].strip_edges().substr(lines[n].strip_edges().to_upper().find("!DATA") + 5) \
					.strip_edges()
			open.start = n
	if open != null:
		open.end = lines.size()
		out.append(open)
	return out


## What [param block] holds: a section's lines, or a picture's base64.
static func _content(lines: PackedStringArray, block: Block) -> String:
	if block.kind == "data":
		var data := PackedStringArray()
		for n: int in range(block.start + 1, block.end):
			var line: String = lines[n].strip_edges()
			if line.begins_with("0 !:"):
				data.append(line.substr(4).strip_edges())
		return "".join(data)
	return "\n".join(lines.slice(block.start + 1, block.end)).strip_edges()


## A sub-model's name and file name, free of [param taken] together and taken:
## [param def] and [param file] where both are, else "Def 2" and "def_2.ldr",
## "Def 3" and "def_3.ldr".
static func _free_pair(def: String, file: String, taken: Dictionary) -> Array:
	var base: String = def.strip_edges().replace("/", "-").replace("#", "").strip_edges()
	if base.is_empty():
		base = "Sub-assembly"
	var n: int = 1
	while true:
		var name: String = base if n == 1 else "%s %d" % [base, n]
		var named: String = file if n == 1 else LdrModel.new_file_name(name)
		if not Names.is_taken(name, taken) and not Names.is_taken(named, taken):
			Names.take(name, taken)
			Names.take(named, taken)
			return [name, named]
		n += 1
	return [base, file]


## [param lines] with the names changed: each section's FILE and Name lines,
## a sub-model's title, every reference, a picture's !DATA line and each line
## naming it (TEXMAP, the booklet's IMAGE), and every path or joint naming a
## sub-model (!BRICKWORKS IN, a motion's ASSEMBLY).
static func _written(lines: PackedStringArray, blocks: Array[Block], files: Dictionary,
		defs: Dictionary, titled: Dictionary, pictures: Dictionary, main_block: Block) -> PackedStringArray:
	var out := PackedStringArray()
	var title_at: Dictionary = {}   ## line -> its block, a renamed section's title
	var untitled: Dictionary = {}   ## FILE line -> its block, a renamed section with none
	for block: Block in titled:
		var at: int = _title_line(lines, block)
		if at >= 0:
			title_at[at] = block
		else:
			untitled[block.start] = block
	var renamed_defs: Dictionary = {}
	for def: String in defs:
		if not def.is_empty() and str(defs[def]) != def:
			renamed_defs[def] = defs[def]
	var in_block: Block = null
	var next: int = 0
	for n: int in lines.size():
		while next < blocks.size() and blocks[next].start <= n:
			in_block = blocks[next]
			next += 1
		if in_block != null and n >= in_block.end:
			in_block = null
		var raw: String = lines[n]
		var line: String = raw.strip_edges()
		var words: PackedStringArray = LdrModel._fields(line)
		if title_at.has(n):
			out.append("0 " + str(titled[title_at[n]]))
			continue
		if words.size() >= 2 and words[0] == "0":
			var word: String = words[1].to_upper()
			if word == "FILE" and in_block != null and files.has(LdrModel._key(in_block.name)):
				out.append("0 FILE " + str(files[LdrModel._key(in_block.name)]))
				if untitled.has(n):
					out.append("0 " + str(titled[untitled[n]]))
				continue
			if word == "FILE" and untitled.has(n):
				out.append(raw)
				out.append("0 " + str(titled[untitled[n]]))
				continue
			if word == "NAME:" and in_block != null and in_block.kind == "file" \
					and files.has(LdrModel._key(in_block.name)):
				out.append("0 Name: " + str(files[LdrModel._key(in_block.name)]))
				continue
			if word == "!DATA" and in_block != null and pictures.has(LdrModel._key(in_block.name)):
				out.append("0 !DATA " + str(pictures[LdrModel._key(in_block.name)]))
				continue
			if not pictures.is_empty() and (word == "!TEXMAP" or word == "!BRICKWORKS"
					and words.size() > 2 and words[2].to_upper() == "IMAGE"):
				out.append(_pictures_renamed(raw, pictures))
				continue
			if not renamed_defs.is_empty() and word == "!BRICKWORKS" and words.size() > 3 \
					and words[2] == "IN":
				var path: String = line.substr(line.find(" IN ") + 4).strip_edges()
				out.append("0 !BRICKWORKS IN " + _path_renamed(path, renamed_defs))
				continue
			if not renamed_defs.is_empty() and word == "!BRICKWORKS" and words.size() > 2 \
					and words[2].begins_with("MOTION") and line.contains("ASSEMBLY \""):
				out.append(_joints_renamed(raw, renamed_defs))
				continue
			out.append(raw)
			continue
		if LdrModel.is_placing(line) and not files.is_empty():
			var ref: String = LdrModel.reference_of(line)
			var key: String = LdrModel._key(ref)
			if files.has(key):
				var kept: String = raw.rstrip(" \t\r")
				out.append(kept.substr(0, kept.length() - ref.length()) + str(files[key]))
				continue
		out.append(raw)
	return out


## The line of [param block] its title is on, as LdrModel.parse reads one:
## its first comment before any part that is not a meta line, a BFC, its
## Name or an author; -1 for none.
static func _title_line(lines: PackedStringArray, block: Block) -> int:
	for n: int in range(block.start + 1, block.end):
		var words: PackedStringArray = LdrModel._fields(lines[n].strip_edges())
		if words.is_empty():
			continue
		if words[0] != "0":
			return -1
		if words.size() < 2:
			continue
		var word: String = words[1].to_upper()
		if word.begins_with("!") or word == "BFC" or word == "NAME:" or word == "NOFILE" \
				or word == "AUTHOR:" or word == "STEP" or word == "ROTSTEP" \
				or words[1].begins_with("//"):
			continue
		return n
	return -1


## [param raw] with each word naming a picture of [param pictures] (by its
## key) given its new name.
static func _pictures_renamed(raw: String, pictures: Dictionary) -> String:
	var words: PackedStringArray = raw.strip_edges().split(" ", false)
	var changed: bool = false
	for n: int in words.size():
		var key: String = LdrModel._key(words[n])
		if pictures.has(key):
			words[n] = str(pictures[key])
			changed = true
	return " ".join(words) if changed else raw


## A path of sub-model copies ("Wing#1/Flap#2") with each definition renamed.
static func _path_renamed(path: String, defs: Dictionary) -> String:
	var segments := PackedStringArray()
	for segment: String in path.split("/", false):
		var def: String = Assemblies.definition(segment)
		segments.append(segment if not defs.has(def)
			else "%s#%d" % [defs[def], Assemblies.copy_of(segment)] if segment.contains("#")
			else str(defs[def]))
	return "/".join(segments)


## A motion's line with each joint it takes hold of by a sub-model's name
## (ASSEMBLY "Door Right") named anew.
static func _joints_renamed(raw: String, defs: Dictionary) -> String:
	var out: String = raw
	for def: String in defs:
		out = out.replace("ASSEMBLY \"%s\"" % def, "ASSEMBLY \"%s\"" % defs[def])
	return out
