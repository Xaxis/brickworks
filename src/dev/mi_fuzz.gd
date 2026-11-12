## A fuzz of the app's own lines in a model's file (MetaIndex): random files
## (CRLF or LF, a last line with or without an end, a sub-model, tabs and
## double spaces, words in any case, lines of a word no reader reads, lines
## no reader can read, and lines the same as another, or of one name or id
## with another value), each read by the app's own reader of its word as an
## open reads it, the family changed as a person changes it, and written as
## a save writes it: into the file (someone else's, a patch) and into a text
## without the family's lines (the app's own file, written whole).
##
## Grown from mlcheck's (2026-11-12) for mlfix: what a save says is what the
## next open reads (mlcheck F1: two FLOOR GRID lines, the floor changed, and
## the old one read again; F2: a second view named A came back once the
## views were taken out); every line no reader can read kept once, as the
## file has it; a line another beat kept only while the family is as it was
## read; a save with nothing changed is the file, byte for byte; saved again,
## the same file; every other line as it was, the file's line ends kept.
##   godot --headless --path . --script src/dev/mi_fuzz.gd -- --n=12000 --seed=1
extends SceneTree

const WORDS := ["FLOOR", "CUT_AWAY", "VIEW", "PIN", "LIGHT", "MOTION_KEY"]
const SPOT := "{\"aim\":[0,1,0],\"at\":[%d,-200,0],\"colour\":\"#ffffff\",\"cone\":30,\"kind\":\"spot\",\"shadows\":true,\"size\":4,\"strength\":1}"

var _rng := RandomNumberGenerator.new()
var _fails: int = 0
var _shown: int = 0
## How many cases had each kind of line, to say the fuzz reached them.
var _seen: Dictionary = {}


func _initialize() -> void:
	var n: int = 2000
	var seed_value: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			n = arg.substr(4).to_int()
		if arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
	_rng.seed = seed_value
	for i: int in n:
		_one(i)
	var reached := PackedStringArray()
	var keys: Array = _seen.keys()
	keys.sort()
	for key: String in keys:
		reached.append("%s %d" % [key, int(_seen[key])])
	print("mi_fuzz: reached " + ", ".join(reached))
	print("mi_fuzz: %d cases, %d failed" % [n, _fails])
	quit(1 if _fails > 0 else 0)


func _saw(what: String) -> void:
	_seen[what] = int(_seen.get(what, 0)) + 1


# -- the lines ---------------------------------------------------------------------


## What a line of [param word] says after its word: one a reader reads, of
## value [param k]; or with [param bad] one it cannot.
func _said(word: String, k: int, bad: bool) -> String:
	match word:
		"FLOOR":
			if bad:
				return "BANANA %d" % k
			return "GRID" if k % 3 == 0 else "BASEPLATE %d %d 2" % [8 + k % 40, 8 + k % 40]
		"CUT_AWAY":
			if bad:
				return "{\"shape\":\"blob%d\"}" % k
			return "{\"at\":%d.0,\"away\":1,\"axis\":\"x\",\"ghosts\":false,\"shape\":\"plane\"}" % k
		"VIEW":
			if bad:
				return "{\"name\":\"orbit%d\",\"path\":[[0,0,0],[40,0,0]],\"kind\":\"orbit\"}" % k
			return "{\"distance\":400,\"focus\":[0,0,0],\"name\":\"v%d\",\"pitch\":-25,\"yaw\":%d}" \
				% [k % 7, k]
		"PIN":
			if bad:
				return "{\"id\":\"BAD ID %d\"}" % k
			return ("{\"id\":\"p%d\",\"part\":\"3001\",\"colour\":4,\"at\":[%d,0,0],\"text\":\"t%d\","
				+ "\"when\":\"2026-11-12T00:00:%02dZ\"}") % [k % 7, k, k, k % 60]
		"LIGHT":
			if bad:
				return "{\"kind\":\"laser\",\"at\":[%d,0,0]}" % k
			return SPOT % k
	# MOTION_KEY: which are read is the motions' own call (Motions.unread).
	return "\"Lift\" 1 %d %d EASE" % [k, k * 10]


func _line(word: String, said: String) -> String:
	var line: String = "0 !BRICKWORKS %s %s" % [word, said]
	match _rng.randi_range(0, 9):
		0:
			return line.replace("0 !BRICKWORKS ", "0\t!BRICKWORKS\t")
		1:
			return line.replace("0 !BRICKWORKS ", "0  !BRICKWORKS  ")
		2:
			return line + "  "
		3:
			# Any case, as LDraw and the index read a keyword (mlcheck F4).
			return line.replace("!BRICKWORKS " + word, "!BrickWorks " + word.to_lower())
	return line


# -- reading and writing as the app does -------------------------------------------


## What the app's reader of [param word] reads of [param metas], each line
## it reads marked taken and each it could read and another beat marked
## beaten: a list of what it holds, each a value in words to compare.
func _read(word: String, metas: MetaIndex) -> Array:
	match word:
		"FLOOR":
			var floor: ModelFloor = ModelFloor.read_from(metas)
			return [floor.to_meta()] if floor != null else []
		"CUT_AWAY":
			var cut: Dictionary = CutShape.read_from(metas)
			return [JSON.stringify(cut, "", true)] if not cut.is_empty() else []
		"VIEW":
			var out: Array = []
			for view: Dictionary in SavedViews.read_from(metas):
				out.append(JSON.stringify(view, "", true))
			return out
		"PIN":
			var out: Array = []
			for pin: PinnedComments.Pin in PinnedComments.read_from(metas).list:
				out.append(JSON.stringify(pin.fields(), "", true))
			return out
		"LIGHT":
			var lit: Dictionary = SceneLights.read_from(metas)
			metas.set_meta("lights_read", lit)
			var out: Array = []
			for light: Dictionary in lit["lights"]:
				out.append(JSON.stringify(light, "", true))
			return out
	return []


## The lines a feature of [param word] says for [param values] ([method _read]'s).
func _lines_of(word: String, values: Array, metas: MetaIndex) -> PackedStringArray:
	var out := PackedStringArray()
	match word:
		"FLOOR":
			for value: String in values:
				out.append(value)
		"CUT_AWAY":
			for value: String in values:
				out.append(CutShape.META + JSON.stringify(JSON.parse_string(value)))
		"VIEW":
			var views: Array = []
			for value: String in values:
				views.append(JSON.parse_string(value))
			out = SavedViews.lines_of(views)
		"PIN":
			for value: String in values:
				out.append(PinnedComments.META + JSON.stringify(JSON.parse_string(value), "", false))
		"LIGHT":
			var lights: Array = []
			for value: String in values:
				lights.append(JSON.parse_string(value))
			# Each light read and not changed is its line (SceneLights.lines_now),
			# as the open's reading says.
			out = SceneLights.lines_now(lights, metas.get_meta("lights_read", {}) if metas != null
				else {})
	return out


func _reader(word: String) -> Callable:
	match word:
		"FLOOR":
			return ModelFloor.said_in
		"CUT_AWAY":
			return CutShape._parsed
		"VIEW":
			return SavedViews._parsed
		"PIN":
			return PinnedComments.said_in
	return Callable()


## The family a save writes for [param word] (ModelStore._family).
func _family(word: String, metas: MetaIndex, now: PackedStringArray,
		unread: Variant = null) -> MetaIndex.Family:
	var at: int = MetaIndex.HEAD if word in ["FLOOR", "PIN", "MOTION_KEY"] else MetaIndex.TITLE
	return ModelStore._family(metas, [word], now, at, _reader(word), unread, word == "PIN")


## [param value] (JSON) as [param word]'s reader reads it back, in words to
## compare: a number the reader keeps whole stays whole.
func _canon(word: String, value: Variant) -> String:
	var line: String = "0 !BRICKWORKS %s %s\n" % [word, JSON.stringify(value)]
	var read: Array = _read(word, MetaIndex.of_text(line))
	return str(read[0]) if not read.is_empty() else ""


## A value of [param word] another than [param value], as an edit makes one.
func _changed(word: String, value: String, k: int) -> String:
	match word:
		"FLOOR":
			return ModelFloor.parse("BASEPLATE %d %d 2" % [50 + k % 40, 50 + k % 40]).to_meta()
		"CUT_AWAY":
			var cut: Dictionary = JSON.parse_string(value)
			cut["at"] = float(500 + k)
			return _canon(word, cut)
		"VIEW":
			var view: Dictionary = JSON.parse_string(value)
			view["yaw"] = float(300 + k)
			return _canon(word, view)
		"PIN":
			var pin: Dictionary = JSON.parse_string(value)
			pin["text"] = "changed %d" % k
			return _canon(word, pin)
	var light: Dictionary = JSON.parse_string(value)
	light["at"] = [float(900 + k), -200.0, 0.0]
	return JSON.stringify(SceneLights.checked(JSON.stringify(light))[0], "", true)


## A value of [param word] none of [param values] is, as an edit adds one.
func _added(word: String, values: Array, k: int) -> String:
	var line: String = "0 !BRICKWORKS %s %s" % [word, _said(word, 700 + k, false)]
	var metas: MetaIndex = MetaIndex.of_text(line + "\n")
	var read: Array = _read(word, metas)
	if word == "VIEW":
		var view: Dictionary = JSON.parse_string(str(read[0]))
		view["name"] = "new%d" % k
		return _canon(word, view)
	if word == "PIN":
		var pin: Dictionary = JSON.parse_string(str(read[0]))
		pin["id"] = "n%d" % k
		pin["when"] = "2026-11-13T00:00:00Z"
		return _canon(word, pin)
	return str(read[0]) if not values.has(read[0]) else _changed(word, str(read[0]), k)


## The open's reading of [param text] for [param word]: its index, with the
## lines its reader took and beat marked, and what it read.
func _open(word: String, text: String) -> Array:
	var metas: MetaIndex = MetaIndex.of_text(text)
	return [metas, _read(word, metas)]


# -- one case ----------------------------------------------------------------------


func _one(i: int) -> void:
	var crlf: bool = _rng.randf() < 0.5
	var word: String = WORDS[_rng.randi_range(0, WORDS.size() - 1)]
	var lines := PackedStringArray(["0 FILE main.ldr", "0 Main", "0 Name: main.ldr",
		"0 Author: Someone"])
	var mine := PackedStringArray()     ## the app's lines of the word put in, as written
	var count: int = _rng.randi_range(0, 7)
	for n: int in count:
		var roll: float = _rng.randf()
		var line: String
		if not mine.is_empty() and roll < 0.25:
			# The same line again, byte for byte or spaced another way.
			var again: String = mine[_rng.randi_range(0, mine.size() - 1)]
			line = again
			if _rng.randf() < 0.4:
				# The same words, spaced or cased another way.
				line = _line(word, MetaIndex.of_text(again + "\n").own([word])[0].said)
			_saw("twin")
		elif roll < 0.45:
			line = _line(word, _said(word, n, true))
			_saw("unread")
		else:
			# A value read before (of one name or id, another value) or new.
			line = _line(word, _said(word, n if _rng.randf() < 0.6 else n + 7 * _rng.randi_range(1, 3),
				false))
		mine.append(line)
		lines.append(line)
		if _rng.randf() < 0.3:
			lines.append("1 4 %d 0 0 1 0 0 0 1 0 0 0 1 3001.dat" % n)
		if _rng.randf() < 0.2:
			lines.append("0 !BRICKWORKS FUTURE_KIND %d" % n)
		if _rng.randf() < 0.1:
			lines.append(_line(WORDS[_rng.randi_range(0, WORDS.size() - 1)], _said("FLOOR", n, false)))
	lines.append("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")
	if _rng.randf() < 0.5:
		lines.append_array(["0 STEP", "0 NOFILE", "0 FILE sub.ldr", "0 Sub",
			"0 !BRICKWORKS %s %s" % [word, _said(word, 90, false)],
			"1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "0 NOFILE"])
	var eol: String = "\r\n" if crlf else "\n"
	var text: String = eol.join(lines) + (eol if _rng.randf() < 0.8 else "")
	var why := PackedStringArray()
	if word == "MOTION_KEY":
		_motion_case(text, why)
	else:
		_family_case(word, text, why)
	if not why.is_empty():
		_fails += 1
		if _shown < 12:
			_shown += 1
			print("FAIL %d %s: %s\n--- in\n%s\n" % [i, word, "; ".join(why),
				text.c_escape().replace("\\n", "\n")])


func _family_case(word: String, text: String, why: PackedStringArray) -> void:
	var opened: Array = _open(word, text)
	var metas: MetaIndex = opened[0]
	var had: Array = opened[1]
	var single: bool = word in ["FLOOR", "CUT_AWAY"]
	var unread: PackedStringArray = metas.untaken([word])
	var beaten: PackedStringArray = metas.beaten([word])
	if not beaten.is_empty():
		_saw("beaten")
	# The edit: none, or as a person makes one.
	var now: Array = had.duplicate()
	var roll: float = _rng.randf()
	if roll < 0.3:
		_saw("unedited")
	elif single:
		if roll < 0.55 or had.is_empty():
			now = [] if not had.is_empty() else [_added(word, had, 1)]
		else:
			now = [_changed(word, str(had[0]), 1)]
		_saw("changed")
	else:
		now = []
		for n: int in had.size():
			var r: float = _rng.randf()
			if r < 0.15:
				continue
			now.append(_changed(word, str(had[n]), n) if r < 0.35 else had[n])
		if _rng.randf() < 0.3 or now == had:
			now.append(_added(word, now, 1))
		if _rng.randf() < 0.1:
			now = []
		_saw("changed")
	var same: bool = now == had
	var said: PackedStringArray = _lines_of(word, now, metas)
	var family: MetaIndex.Family = _family(word, metas, said)
	# Into the file, as someone else's is patched.
	var out: String = MetaIndex.of_text(text).write(text, [family])
	_check_written(word, text, out, now, unread, beaten, same, "patch", why)
	if same and out != text:
		why.append("patch: an unedited save is not the file (%s)" % _first_unlike(text, out))
	if _others(text, word) != _others(out, word):
		why.append("patch: a line not of %s changed" % word)
	# Into a text without the family's lines, as the app's own is written whole.
	var bare: String = _without(text, word)
	var whole: String = MetaIndex.of_text(bare).write(bare, [family])
	_check_written(word, text, whole, now, unread, beaten, same, "whole", why)
	var again_bare: String = _without(whole, word)
	var reopened: Array = _open(word, whole)
	var whole2: String = MetaIndex.of_text(again_bare).write(again_bare,
		[_family(word, reopened[0], _lines_of(word, reopened[1], reopened[0]))])
	if whole2 != whole:
		why.append("whole: written whole again unedited, not the same (%s)" % _first_unlike(whole, whole2))


## The invariants of [param out], [param text] saved with the family saying
## [param now], read again as the next open reads it.
func _check_written(word: String, text: String, out: String, now: Array,
		unread: PackedStringArray, beaten: PackedStringArray, same: bool, how: String,
		why: PackedStringArray) -> void:
	var reopened: Array = _open(word, out)
	var again: MetaIndex = reopened[0]
	var read: Array = reopened[1]
	var want: Array = now.duplicate()
	var got: Array = read.duplicate()
	if word == "PIN":
		want.sort()
		got.sort()
	if got != want:
		why.append("%s: the next open reads %s, the save said %s" % [how, str(got).left(300),
			str(want).left(300)])
	var raws: PackedStringArray = again.raws([word])
	var counted: Dictionary = {}
	for line: String in unread:
		counted[line] = int(counted.get(line, 0)) + 1
	for line: String in counted:
		if raws.count(line) < int(counted[line]):
			why.append("%s: a line no reader reads lost: %s (%d of %d)" % [how, line.c_escape(),
				raws.count(line), int(counted[line])])
	# What the save said, each line that says what one taken said as the file
	# has it (ModelStore._family).
	var opened: MetaIndex = MetaIndex.of_text(text)
	_read(word, opened)
	var said: PackedStringArray = _lines_of(word, now, opened)
	if _reader(word).is_valid():
		said = opened.as_written([word], said, _reader(word))
	# Lines that say what one beaten says, counted by what they say.
	var clean_of: Callable = func(lines: PackedStringArray, one: String) -> int:
		var count: int = 0
		for each: String in lines:
			if MetaIndex.clean(each) == MetaIndex.clean(one):
				count += 1
		return count
	for line: String in beaten:
		if same and raws.count(line) == 0:
			why.append("%s: unedited, a line another beat went: %s" % [how, line.c_escape()])
		var kept: int = clean_of.call(raws, line)
		if not same and kept > clean_of.call(said, line) + clean_of.call(unread, line):
			why.append("%s: changed, a line another beat kept: %s\n--- said %s\n--- out\n%s" % [how,
				line.c_escape(), str(said), out.c_escape().replace("\\n", "\n")])
	# The line ends as the file's.
	var crlf: bool = text.contains("\r\n")
	if crlf and out.count("\n") != out.count("\r\n"):
		why.append("%s: LF alone in a CRLF file" % how)
	if not crlf and out.contains("\r"):
		why.append("%s: CR in an LF file" % how)
	if how == "patch" and text.ends_with("\n") != out.ends_with("\n"):
		why.append("patch: the end changed")
	# Saved again unedited: the same file.
	var twice: String = again.write(out, [_family(word, again, _lines_of(word, read, again))])
	if twice != out:
		why.append("%s: saved again unedited, not the same (%s)" % [how, _first_unlike(out, twice)])


## The motions' family: which lines are read is theirs, and they say which
## they keep unread (Motions.unread), by text; of two the same, one read and
## one not, the one kept is the one not read, where it was (mlcheck F1).
func _motion_case(text: String, why: PackedStringArray) -> void:
	var metas: MetaIndex = MetaIndex.of_text(text)
	var own: Array[MetaIndex.Line] = metas.own(["MOTION_KEY"])
	var keep := PackedStringArray()
	var read_at := PackedInt32Array()
	for n: int in own.size():
		own[n].taken = _rng.randf() < 0.6
		if own[n].taken:
			read_at.append(n)
		else:
			keep.append(own[n].raw)
	if keep.is_empty():
		return
	_saw("motion unread")
	# The read keys said again, some changed; or a refused one renamed (not
	# the file's), the rest as they were.
	var renamed: String = ""
	if _rng.randf() < 0.2:
		renamed = keep[0].replace("Lift", "Raise")
		keep[0] = renamed
		_saw("motion renamed")
	var now := PackedStringArray()
	for n: int in read_at:
		now.append(own[n].clean() if not renamed.is_empty() or _rng.randf() < 0.7 else
			"0 !BRICKWORKS MOTION_KEY \"Lift\" 1 %d 77 EASE" % (500 + n))
	var lines: PackedStringArray = metas.lines_for(["MOTION_KEY"], now, keep)
	# What it is to be: each read line its line said now, in its place; each
	# kept unread line where it was, the first of its text not taken given
	# to the first of it kept; a renamed one after the rest.
	var free: Dictionary = {}
	for n: int in own.size():
		if not own[n].taken:
			if not free.has(own[n].raw):
				free[own[n].raw] = []
			(free[own[n].raw] as Array).append(n)
	var kept: Dictionary = {}
	for line: String in keep:
		var at: Array = free.get(line, [])
		if not at.is_empty():
			kept[int(at.pop_front())] = true
	var want := PackedStringArray()
	var r: int = 0
	for n: int in own.size():
		if own[n].taken:
			want.append(now[r])
			r += 1
		elif kept.has(n):
			want.append(own[n].raw)
	if not renamed.is_empty():
		want.append(renamed)
	if lines != want:
		why.append("motion: lines %s, wanted %s; read %s, keep %s, now %s" % [str(lines), str(want),
			str(read_at), str(keep), str(now)])
	var out: String = metas.write(text, [MetaIndex.family(["MOTION_KEY"], lines, MetaIndex.HEAD)])
	var got := PackedStringArray()
	for line: String in MetaIndex.of_text(out).raws(["MOTION_KEY"]):
		got.append(MetaIndex.clean(line))
	var said := PackedStringArray()
	for line: String in lines:
		said.append(MetaIndex.clean(line))
	if got != said:
		why.append("motion: written %s, wanted %s" % [str(got).left(200), str(said).left(200)])


# -- helpers -----------------------------------------------------------------------


## [param text] without the model's own lines of [param word]: a text the
## app wrote whole, which has none of them.
static func _without(text: String, word: String) -> String:
	var metas: MetaIndex = MetaIndex.of_text(text)
	var out: String = text
	var lines: Array[MetaIndex.Line] = metas.own([word])
	for n: int in range(lines.size() - 1, -1, -1):
		out = out.left(lines[n].start) + out.substr(lines[n].next)
	return out


## The text's lines but the model's own lines of [param word], trimmed of CR.
static func _others(text: String, word: String) -> PackedStringArray:
	var index: MetaIndex = MetaIndex.of_text(text)
	var skip: Dictionary = {}
	for line: MetaIndex.Line in index.own([word]):
		skip[line.start] = true
	var out := PackedStringArray()
	var at: int = 0
	while at < text.length():
		var stop: int = text.find("\n", at)
		var next: int = text.length() if stop < 0 else stop + 1
		if not skip.has(at):
			out.append(text.substr(at, next - at).trim_suffix("\n").trim_suffix("\r"))
		at = next
	return out


static func _first_unlike(a: String, b: String) -> String:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "<none>"
		var y: String = lb[n] if n < lb.size() else "<none>"
		if x != y:
			return "line %d: %s | %s" % [n + 1, x.c_escape().left(90), y.c_escape().left(90)]
	return "the same lines"
