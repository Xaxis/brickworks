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
class_name SubmodelFile
extends RefCounted


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
	## FILE section key -> [its FILE line, the line after its last] (its
	## NOFILE line in it where it has one).
	var sections: Dictionary = {}
	## Its keys in the order the file has them.
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
	var current: String = ""
	var data_name: String = ""
	var any_file: bool = false
	for n: int in whole.lines.size():
		var word: String = LdrModel.section_word(whole.lines[n])
		if word.is_empty():
			continue
		var fields: PackedStringArray = LdrModel._fields(whole.lines[n].strip_edges())
		if not current.is_empty():
			(whole.sections[current] as Array)[1] = n + 1 if word == "NOFILE" else n
			current = ""
		if not data_name.is_empty():
			(whole.data[data_name] as Array)[1] = n
			data_name = ""
		if word == "FILE":
			var key: String = LdrModel._key(" ".join(fields.slice(2)))
			if whole.sections.has(key):
				continue
			current = key
			whole.sections[key] = [n, whole.lines.size()]
			whole.order.append(key)
			if not any_file:
				whole.main_key = key
			any_file = true
		elif word == "!DATA" and fields.size() > 2:
			data_name = " ".join(fields.slice(2)).get_file().to_lower()
			whole.data[data_name] = [n, whole.lines.size()]
	if not any_file:
		whole.sections[""] = [0, whole.lines.size()]
		whole.order.append("")
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
	var key: String = str(whole.model.unit_sections.get(path, ""))
	if not whole.sections.has(key) or key == whole.main_key:
		return null
	var keys: Array[String] = _placed_from([key], whole)
	var made := Made.new()
	made.title = Assemblies.definition(Assemblies.leaf(path))
	var first: Array = whole.sections[key]
	var named: String = whole.lines[int(first[0])].strip_edges()
	named = " ".join(LdrModel._fields(named).slice(2)).replace("\\", "/").get_file()
	made.name = _file_name(named, keys.size() > 1)
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
		# section is): the second "_2".
		var base: String = made.name.get_basename()
		var name: String = made.name
		var n: int = 1
		while names.has(name.to_lower()):
			n += 1
			name = "%s_%d.%s" % [base, n, made.name.get_extension()]
		names[name.to_lower()] = true
		made.name = name
		out.append(made)
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
			var placed: String = _placed_by(whole.lines[n])
			if placed.is_empty() or found.has(placed) or not whole.sections.has(placed) \
					or placed == whole.main_key:
				continue
			found[placed] = true
			waiting.append(placed)
	var out: Array[String] = keys.duplicate()
	for key: String in whole.order:
		if found.has(key) and not out.has(key):
			out.append(key)
	return out


## The key of what a line places ("1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr" ->
## "wing"), a line hidden by MLCad, LPub's ghost or a picture's fallback
## geometry too; "" for any other line.
static func _placed_by(raw: String) -> String:
	var line: String = raw.strip_edges()
	for before: String in ["0 !:", "0 MLCAD HIDE", "0 GHOST"]:
		if line.to_upper().begins_with(before):
			line = line.substr(before.length()).strip_edges()
			break
	if not line.begins_with("1"):
		return ""
	var fields: PackedStringArray = LdrModel._fields(line)
	if fields.size() < 15 or fields[0] != "1":
		return ""
	return LdrModel._key(" ".join(fields.slice(14)))


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


static func _file_name(named: String, many: bool) -> String:
	var base: String = named.get_basename() if named.get_extension().to_lower() in ["ldr", "dat",
		"mpd"] else named
	base = base.replace(":", "_").strip_edges()
	if base.is_empty():
		base = "submodel"
	return base + (".mpd" if many else ".ldr")


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
	var key: String = whole.main_key if home.is_empty() \
		else str(whole.model.unit_sections.get(home, ""))
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
		var placed: String = _placed_by(whole.lines[n])
		if whole.sections.has(placed) and not references.has(placed):
			references.append(placed)
	var keys: Array[String] = _placed_from(references, whole) if not references.is_empty() \
		else ([] as Array[String])
	var own_name: String = made.title.to_snake_case()
	made.name = _file_name(own_name, not keys.is_empty())
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
