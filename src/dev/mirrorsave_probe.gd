## mirrorsave's probe: a sub-model keeps its own text in its own frame
## whatever placement of it comes first (wingfix2 N1). A wing placed twice,
## its FIRST placement mirrored, was written again from the other hand on
## the save after an edit's: Main's `1 16 0 0 0 -1 ... wing.ldr` became
## `1 16 -200 0 0 1 ...`, and the wing's own lines were mirrored about x 100
## (its 3003 at 40 became 160). The parts stayed where they were; only the
## person's text changed, which other LDraw programs and their instructions
## read.
##
## Each case opens a file (the app's own, "Author: Brickworks", which a save
## writes whole, and someone else's, which it patches), makes one edit, and
## saves three times: in the session twice, opened again and saved, opened
## again and saved. Every save is the one before byte for byte; every
## placement of a sub-model is its line as the file had it; each
## sub-model's parts are its lines as the file had them (where the edit put
## a part in a copy, those lines and the moved one); and the model opened
## again has every part where it was after the edit, in place, colour and
## hand.
##
##   godot --headless --path . --script src/dev/mirrorsave_probe.gd
##
##   MIRRORSAVE_ONLY=words   only the cases whose names have them
extends "res://src/dev/copyfaults_probe.gd"

const WING := """0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: %s

1 1 100 -8 0 1 0 0 0 1 0 0 0 1 3034.dat
1 4 40 -32 0 1 0 0 0 1 0 0 0 1 3003.dat
1 14 100 -32 -10 1 0 0 0 1 0 0 0 1 3004.dat
0
0 NOFILE
"""

## A wing with a part made in two hands (41770, the library's 41770a since
## its number moved: its reflection is the other hand, 41769), and none at
## its middle.
const HANDED := """0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: %s

1 1 100 -8 0 1 0 0 0 1 0 0 0 1 3034.dat
1 4 60 -16 0 1 0 0 0 1 0 0 0 1 41770.dat
1 14 140 -32 0 1 0 0 0 1 0 0 0 1 3003.dat
0
0 NOFILE
"""

## A car of two wings, the first mirrored, and a brick of its own.
const CAR := """0 FILE car.ldr
0 Car
0 Name: car.ldr
0 Author: %s

1 16 0 0 0 -1 0 0 0 1 0 0 0 1 wing.ldr
1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 14 0 -24 60 1 0 0 0 1 0 0 0 1 3001.dat
0
0 NOFILE
"""

const STRAIGHT := "1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr"
const MIRRORED := "1 16 0 0 0 -1 0 0 0 1 0 0 0 1 wing.ldr"
const MIRRORED_BEHIND := "1 16 0 0 -200 -1 0 0 0 1 0 0 0 1 wing.ldr"
const TURNED := "1 16 0 0 300 0 0 1 0 1 0 -1 0 0 wing.ldr"
const CAR_STRAIGHT := "1 16 0 0 0 1 0 0 0 1 0 0 0 1 car.ldr"
const CAR_MIRRORED := "1 16 0 0 -300 1 0 0 0 1 0 0 0 -1 car.ldr"

## [name, Main's placements, the sub-models' sections (WING, CAR)].
const MS_CASES: Array = [
	["mirrored first", [MIRRORED, STRAIGHT], [WING]],
	["straight first", [STRAIGHT, MIRRORED], [WING]],
	["three copies, two mirrored, a mirrored one first", [MIRRORED, STRAIGHT, MIRRORED_BEHIND], [WING]],
	["nested: a car mirrored first, its wings mirrored first", [CAR_MIRRORED, CAR_STRAIGHT], [CAR, WING]],
	["a turned copy first", [TURNED, STRAIGHT], [WING]],
	["one copy, mirrored", [MIRRORED], [WING]],
	["a handed wing mirrored first", [MIRRORED, STRAIGHT], [HANDED]],
	["a handed wing, one copy, mirrored", [MIRRORED], [HANDED]],
]

## The edits: a part put down in Main, beside the copies (only Main's text
## changes, by the part's line); the 3003 of the first copy nudged a cell,
## the other copies following (one line of the sub-model changes).
## And the first copy mirrored in place, every part of it across x through
## its middle (the Mirror tool, Shift+M): the line placing it changes hands,
## its section's lines none (Builder.mirror_bricks carries where each part's
## line is).
const MS_EDITS: Array = ["put in main", "nudge in the first copy", "mirror the first copy"]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("mirrorsave probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	var only: String = OS.get_environment("MIRRORSAVE_ONLY")
	var table := PackedStringArray()
	for author: String in ["Brickworks", "Someone Else"]:
		for one: Array in MS_CASES:
			for edit: String in ["unedited"] + MS_EDITS:
				var name: String = "%s, %s, %s" % [one[0], edit,
					"the app's own" if author == "Brickworks" else "someone else's"]
				if not only.is_empty() and not name.contains(only):
					continue
				var before: int = _failures
				await _case(name, _file(one[1], one[2], author), edit)
				table.append("%-90s %s" % [name, "ok" if _failures == before else "FAIL"])
	print("\nthe table:")
	for line: String in table:
		print("  " + line)
	print("\nmirrorsave probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _file(placements: Array, sections: Array, author: String) -> String:
	var out := PackedStringArray(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr",
		"0 Author: %s" % author, ""])
	out.append_array(placements)
	out.append_array(["0", "0 NOFILE"])
	var text: String = "\n".join(out) + "\n"
	for section: String in sections:
		text += section % author
	return text


func _case(name: String, text: String, edit: String) -> void:
	print("\n== %s" % name)
	await _open(text)
	if edit == "unedited":
		_frames_say_hands(name, text)
	var said: String = "nothing"
	## The sub-model and the part whose line the edit changes ("" for none).
	var changed_in: String = ""
	var changed_part: String = ""
	if edit == "put in main":
		var plate: BrickWorld.Brick = _first_plate()
		var put: int = await _hand_put_in("3001", 15, plate.transform.translated(Vector3(0, 0, 900)), "")
		said = "a 3001 put in Main (#%d)" % put
		changed_in = "main.ldr"
		changed_part = "3001.dat"
		if not _check("%s: the part put down" % name, put != 0):
			return
	elif edit == "nudge in the first copy":
		var plate: BrickWorld.Brick = _first_plate()
		var path: String = Assemblies.path_of(plate)
		var brick: BrickWorld.Brick = _in_copy(path, "3003")
		_pick([brick.id])
		var moved: int = _builder.move_selection(Vector3i(0, 0, 1))
		await _edited()
		await _frames(2)
		said = "%s's 3003 nudged a cell along z, %d moved" % [path, moved]
		changed_in = "wing.ldr"
		changed_part = "3003.dat"
		if not _check("%s: the part moved" % name, moved > 0):
			return
	elif edit == "mirror the first copy":
		var plate: BrickWorld.Brick = _first_plate()
		var path: String = Assemblies.path_of(plate)
		var ids := PackedInt64Array()
		for brick: BrickWorld.Brick in _world.bricks():
			if Assemblies.path_of(brick) == path:
				ids.append(brick.id)
		var made: PackedInt64Array = _builder.mirror_bricks(ids, 0)
		await _edited()
		await _frames(2)
		said = "%s mirrored in place across x, %d of %d parts" % [path, made.size(), ids.size()]
		# Its reference changes hands; its section, not at all.
		changed_in = "car.ldr" if path.contains("/") else "main.ldr"
		changed_part = "wing.ldr"
		if not _check("%s: the copy mirrored" % name, not made.is_empty() and made.size() == ids.size()):
			return
	print("  %s" % said)
	var parts: Array = _parts_placed()
	var first: String = _save()
	var again: String = _save()
	_check("%s: saved twice in the session, the same" % name, again == first)
	_compare(name, "saved", text, first, changed_in, changed_part, edit == "mirror the first copy")
	_dump(name, 0, text)
	_dump(name, 1, first)
	var last: String = first
	var saves: int = 1
	for round: String in ["opened again and saved", "opened a third time and saved"]:
		await _open(last)
		var reopened: Array = _parts_placed()
		var lost: PackedStringArray = _not_in(parts, reopened)
		var extra: PackedStringArray = _not_in(reopened, parts)
		_check("%s: %s, every part where it was (%d parts; %d not, %d new%s)" % [name, round,
			reopened.size(), lost.size(), extra.size(),
			"" if lost.is_empty() else ": " + ", ".join(lost.slice(0, 3)) + " | " + ", ".join(extra.slice(0, 3))],
			lost.is_empty() and extra.is_empty())
		var saved: String = _save()
		if not _check("%s: %s, the file before byte for byte" % [name, round], saved == last):
			_wr_diff(round, last, saved)
		saves += 1
		_dump(name, saves, saved)
		last = saved


## Each copy's frame as the open read it (Assemblies.file_frames: what the
## writer writes a section and its references in, and what Find and Replace
## reads to say which copy shows the other hand) reflects where the file's
## lines placing it, from Main's down, reflect an odd number of times. Voted
## from where the parts stand, a mirrored-first wing read as the plain one
## and the plain one as the mirror. Copies are numbered by definition in the
## order the file places them, depth first ("1/2": the second copy inside
## the first).
func _frames_say_hands(name: String, text: String) -> void:
	var sections: Dictionary = _sections(text)
	var want: Dictionary = {}
	_hands_in(sections, "main.ldr", "", false, {}, want)
	var frames: Dictionary = _shell.assemblies.file_frames()
	var said := PackedStringArray()
	var wrong := PackedStringArray()
	for path: String in frames:
		var numbers := PackedStringArray()
		for segment: String in Assemblies.segments(path):
			numbers.append(str(Assemblies.copy_of(segment)))
		var key: String = "/".join(numbers)
		var mirror: bool = ((frames[path] as Dictionary)["frame"] as Transform3D).basis.determinant() < 0.0
		said.append("%s %s" % [key, "mirrored" if mirror else "plain"])
		if not want.has(key) or bool(want[key]) != mirror:
			wrong.append(path)
	said.sort()
	_check("%s: each copy read in the hand its lines place it in (%s; %d copies, %d in the file%s)" % [
		name, ", ".join(said), frames.size(), want.size(),
		"" if wrong.is_empty() else "; wrong: " + ", ".join(wrong)],
		wrong.is_empty() and frames.size() == want.size())


## Into [param want]: each copy [param section] places, by its numbers
## ([method _frames_say_hands]), -> whether the lines down to it reflect.
static func _hands_in(sections: Dictionary, section: String, above: String, odd: bool,
		counts: Dictionary, want: Dictionary) -> void:
	for line: String in _refs(sections.get(section, PackedStringArray()), true):
		var w: PackedStringArray = line.split(" ", false)
		var file: String = w[14].to_lower()
		var b := Basis(Vector3(w[5].to_float(), w[8].to_float(), w[11].to_float()),
			Vector3(w[6].to_float(), w[9].to_float(), w[12].to_float()),
			Vector3(w[7].to_float(), w[10].to_float(), w[13].to_float()))
		counts[file] = int(counts.get(file, 0)) + 1
		var key: String = str(counts[file]) if above.is_empty() else "%s/%d" % [above, int(counts[file])]
		var here: bool = odd != (b.determinant() < 0.0)
		want[key] = here
		_hands_in(sections, file, key, here, counts, want)


## The file opened (0) and each save (1 to 3), into MIRRORSAVE_DUMP's
## folder where it is given.
static func _dump(name: String, n: int, text: String) -> void:
	var dir: String = OS.get_environment("MIRRORSAVE_DUMP")
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open("%s/%s_%d.ldr" % [dir, name.to_snake_case().validate_filename()
		.replace(" ", "_").replace(",", ""), n], FileAccess.WRITE)
	if file != null:
		file.store_string(text)


## Each placement of a sub-model in [param saved] is its line in
## [param text]; each sub-model's part lines are its lines there but the one
## the edit changed, which differs only in [param changed_part]'s line. With
## [param mirrored] (a copy mirrored in place), only the line placing that
## copy in [param changed_in] differs.
func _compare(name: String, what: String, text: String, saved: String,
		changed_in: String, changed_part: String, mirrored: bool = false) -> void:
	var was: Dictionary = _sections(text)
	var now: Dictionary = _sections(saved)
	for section: String in was:
		if not now.has(section):
			_check("%s: %s, %s written (sections %s)" % [name, what, section, str(now.keys())], false)
			continue
		var a: PackedStringArray = was[section]
		var b: PackedStringArray = now[section]
		var refs_a: PackedStringArray = _refs(a, true)
		var refs_b: PackedStringArray = _refs(b, true)
		if mirrored:
			# A copy mirrored whole changes no section's own parts: each line as
			# it was, in the order the app's steps, worked out again, build them
			# (pre261 orders three copies' wing so too), a retired number as the
			# number it moved to where a plain copy writes it, as a whole write
			# always has (ModelStore.as_moved).
			var own_was: PackedStringArray = _as_now(_refs(a, false))
			var own_now: PackedStringArray = _as_now(_refs(b, false))
			_check("%s: %s, %s's parts by its own lines, in any order (%s; were %s)" % [name, what,
				section, " / ".join(_refs(b, false)), " / ".join(_refs(a, false))],
				_missing(own_was, own_now).is_empty() and _missing(own_now, own_was).is_empty())
			# The line placing the copy mirrored changes hands, and no other;
			# inside a car, the other car's twin follows it, and the line
			# placing that car says how (main's and car's lines are the
			# writer's to choose there; the wing's own lines are not).
			var went: PackedStringArray = _missing(refs_a, refs_b)
			var new: PackedStringArray = _missing(refs_b, refs_a)
			if section == changed_in and not changed_in.begins_with("car"):
				_check("%s: %s, %s's lines as they were but the mirrored copy's (gone %s; new %s)" % [name,
					what, section, " / ".join(went), " / ".join(new)], went.size() == 1 and new.size() == 1)
			elif not was.has("car.ldr"):
				_check("%s: %s, %s places its sub-models by its own lines (%s; were %s)" % [name, what,
					section, " / ".join(refs_b), " / ".join(refs_a)], went.is_empty() and new.is_empty())
			continue
		# The app's own steps are worked out again after an edit, and the
		# section the edit changed lists its copies in the order they are
		# built: each line as it was, in any order (pre261 orders three
		# copies so too).
		var any_order: bool = section == changed_in and name.contains("the app's own")
		_check("%s: %s, %s places its sub-models by its own lines%s (%s; were %s)" % [name, what, section,
			", in any order" if any_order else "", " / ".join(refs_b), " / ".join(refs_a)],
			refs_a == refs_b if not any_order
			else _missing(refs_a, refs_b).is_empty() and _missing(refs_b, refs_a).is_empty())
		var own_a: PackedStringArray = _refs(a, false)
		var own_b: PackedStringArray = _refs(b, false)
		if section != changed_in:
			_check("%s: %s, %s's parts by its own lines (%s; were %s)" % [name, what, section,
				" / ".join(own_b), " / ".join(own_a)], own_a == own_b)
			continue
		var gone: PackedStringArray = _missing(own_a, own_b)
		var came: PackedStringArray = _missing(own_b, own_a)
		# A part put down is one line more; one moved, its line for another.
		var put: bool = section == "main.ldr"
		_check("%s: %s, %s's lines as they were but the %s %s's (gone %s; new %s)" % [name, what,
			section, "new" if put else "moved", changed_part, " / ".join(gone), " / ".join(came)],
			gone.size() == (0 if put else 1) and came.size() == 1
			and (put or gone[0].ends_with(changed_part)) and came[0].ends_with(changed_part))


## "0 FILE name" -> its lines, with the text's lines put to one space.
static func _sections(text: String) -> Dictionary:
	var out: Dictionary = {}
	var at: String = ""
	for raw: String in text.split("\n"):
		var line: String = " ".join(raw.strip_edges().split(" ", false))
		if line.begins_with("0 FILE "):
			at = line.substr(7).to_lower()
			out[at] = PackedStringArray()
		elif not at.is_empty():
			# A packed array is a value: appended to as itself, not a copy.
			var lines: PackedStringArray = out[at]
			lines.append(line)
			out[at] = lines
	return out


## The type 1 lines of a section: those placing a sub-model
## ([param models]) or those placing a part, in order.
static func _refs(lines: PackedStringArray, models: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in lines:
		if line.begins_with("1 ") and line.to_lower().ends_with(".ldr") == models:
			out.append(line)
	return out


## Part lines with each part named as the library has it now (a retired
## number as the number it moved to, PartLibrary.resolve).
func _as_now(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in lines:
		var w: PackedStringArray = line.split(" ", false)
		var part: String = w[w.size() - 1].get_basename()
		w[w.size() - 1] = _library.resolve(part) + ".dat"
		out.append(" ".join(w))
	return out


## What of [param a] [param b] has not, counted.
static func _missing(a: PackedStringArray, b: PackedStringArray) -> PackedStringArray:
	var left: Dictionary = {}
	for x: String in b:
		left[x] = int(left.get(x, 0)) + 1
	var out := PackedStringArray()
	for x: String in a:
		if int(left.get(x, 0)) > 0:
			left[x] = int(left[x]) - 1
		else:
			out.append(x)
	return out


## Every part, in the file's coordinates: {"key": part, colour, place and
## turn, so a part written in the other hand reads differently; "where":
## part, colour and place; "part"; "at"}.
func _parts_placed() -> Array:
	var back := Transform3D(Basis.IDENTITY, -(_store.call("_lift_now") as Vector3))
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		# The baseplate laid under the model is the app's, laid again at each
		# open to the model's size.
		if _store.scenery.has(brick.id):
			continue
		var at: Transform3D = back * brick.transform
		var b: Basis = at.basis
		var where: String = "%s c%d at %s" % [brick.part_id, brick.color_code,
			str(at.origin.snappedf(0.01))]
		out.append({"key": "%s turn %s %s %s" % [where, str(b.x.snappedf(0.001)),
			str(b.y.snappedf(0.001)), str(b.z.snappedf(0.001))], "where": where,
			"part": brick.part_id, "at": at})
	return out


## The keys of [param a] ([method _parts_placed]) with no part of [param b] where
## it is: the same part in its colour at its place, turned as it is or, for
## a part the same turned on itself, filling the same cells
## (Assemblies._same_place). A plain brick in a turned copy mirrored in
## place is turned a half on itself by the Mirror tool and back by the open
## (each the reflection), and is where it was.
func _not_in(a: Array, b: Array) -> PackedStringArray:
	var used: Dictionary = {}
	var out := PackedStringArray()
	for one: Dictionary in a:
		var hit: int = -1
		for n: int in b.size():
			if not used.has(n) and (b[n] as Dictionary)["key"] == one["key"]:
				hit = n
				break
		if hit < 0:
			for n: int in b.size():
				var other: Dictionary = b[n]
				if not used.has(n) and other["where"] == one["where"] \
						and _shell.assemblies._same_place(str(one["part"]), one["at"], other["at"]):
					hit = n
					break
		if hit < 0:
			out.append(one["key"])
		else:
			used[hit] = true
	return out


## The plate of the copy Main places first (the one at the lowest line).
func _first_plate() -> BrickWorld.Brick:
	var found: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3034") and (found == null
				or Assemblies.path_of(brick) < Assemblies.path_of(found)):
			found = brick
	return found


func _in_copy(path: String, part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id.begins_with(part):
			return brick
	return null


func _wr_diff(what: String, a: String, b: String) -> void:
	var x: PackedStringArray = a.split("\n")
	var y: PackedStringArray = b.split("\n")
	var shown: int = 0
	for n: int in maxi(x.size(), y.size()):
		var l: String = x[n] if n < x.size() else "<none>"
		var r: String = y[n] if n < y.size() else "<none>"
		if l != r:
			print("    %s line %d: %s  |  %s" % [what, n + 1, l, r])
			shown += 1
			if shown > 8:
				break
