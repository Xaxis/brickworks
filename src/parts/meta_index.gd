## The app's own lines in a model's file, "0 !BRICKWORKS WORD ...": found
## once, and written in one place (APP_UX7 #2, metalines).
##
## About a dozen features keep a line or a few in the model's file: what it
## stands on (ModelFloor), its views (SavedViews), lights (SceneLights), cut
## (CutShape), hidden colours (HiddenColours), motions (Motions), pins
## (PinnedComments), the set it is, its bin (SetBin), the picture to build
## over (ReferenceImage), the name a save gave it, the link it is shared at
## and who made it (ModelStore). Each found, read and wrote its own lines,
## and reviews found the same faults in several of them: a line one could
## not read went at the next save; a line went into a file whose lines end
## "\r\n" ending "\n" alone; a tab between the words, a CR at the end or a
## "0 FiLe" was not read as the clean form; a sub-model's line was read, or
## taken out, as the model's; a line the file had moved on a save with
## nothing changed; and each scanned the whole text, a big model's a dozen
## times over every save. Here they are found once ([method of_text]: every
## such line, by its section and word, each section's head and title, the
## file's own line end) and written once ([method written]); each feature
## keeps only its own reading of what its lines say.
##
## Writing, a feature gives the lines it has now (a [Family]), and each line
## the file has that says the same is the file's line, byte for byte, where
## the file has it: an unedited save is the file. A line changed is written
## where the one it replaces was, a line added after the one before it, and
## lines the file had none of under the model's title or at the end of its
## head. A line a feature cannot read stays where the file has it, as it is
## ([member Line.taken], [method lines_for]).
##
## Lines are found by the engine's search for a line beginning "0", so
## the cost is in the type 0 lines and not the parts: a line indented
## before its "0" is not one (no LDraw tool writes one).
class_name MetaIndex
extends RefCounted

## The word every line of the app's own begins with, after "0".
const WORD := "!BRICKWORKS"
## Where a family's lines go in the model when the file has none of them:
## under its title (the line after its 0 FILE), as LdrModel.into_main put
## them...
const TITLE := 0
## ...or at the end of its head, after its name and author lines, before its
## first part, step or blank line (where ModelFloor put its line).
const HEAD := 1


## One of the app's lines as the file has it.
class Line extends RefCounted:
	## Where it begins in the text, where it ends before its CR, and where
	## the next line begins (the text's length at its end).
	var start: int = 0
	var stop: int = 0
	var next: int = 0
	## The word after !BRICKWORKS, in capitals ("VIEW"), and what it says
	## after that, its ends trimmed: the JSON, or the words.
	var word: String = ""
	var said: String = ""
	## The line as the file has it, without its line end.
	var raw: String = ""
	## The section it is in: 0 the model's own, -1 none (after a NOFILE).
	var section: int = 0
	## A reader read it into what its feature holds: a line none took is
	## kept as the file has it ([method untaken]).
	var taken: bool = false

	## The line as a writer writes it: one space between its words.
	func clean() -> String:
		return MetaIndex.clean_of(word, said)


## A section of the file: the model's own, or a sub-model's 0 FILE.
class Section extends RefCounted:
	## As its 0 FILE line names it; "" for a file with none.
	var name: String = ""
	## Where its 0 FILE line begins (-1 for none), where the line after it
	## begins, and where the section ends: the next 0 FILE, or after its
	## NOFILE, or the text's end.
	var file: int = -1
	var body: int = 0
	var end: int = 0
	## Where a line under its title goes: after its first line when that is
	## a title, else its first line's place.
	var title_end: int = 0
	## Where its head ends: before its first part, step, section line or
	## blank line, and before the lines that say what the line after them is
	## for another program (SourceFile.before_run).
	var head_end: int = 0


## The lines one feature keeps in the model, as it is to have them.
class Family extends RefCounted:
	## The words its lines begin with; one ending "*" is any word beginning
	## so ("MOTION*").
	var words: PackedStringArray = PackedStringArray()
	## Every line of it, in order, without line ends: those the feature says
	## now, and those it keeps unread as the file had them ([method lines_for]).
	var lines: PackedStringArray = PackedStringArray()
	## Where its lines go when the file has none: [constant TITLE] or
	## [constant HEAD].
	var at: int = TITLE
	## Its lines anywhere in the file, not in the model's section alone: the
	## steps a shared link carries at the file's end (SharedPages).
	var anywhere: bool = false


## The text's length when it was read.
var size: int = 0
## The text's own line end, its first line's (LdrModel.eol_of): every line
## written into it ends so.
var eol: String = "\n"
## Its sections, the model's own first.
var sections: Array[Section] = []
## Every line of the app's own, in the file's order.
var lines: Array[Line] = []
## How many ROTSTEP lines it has, and each page's picture it embeds
## (LDraw's !DATA named brickworks-page-...), by its name, lower case: what
## the booklet's looks look for (BookletLooks._written_in).
var rotsteps: int = 0
var pictures: PackedStringArray = PackedStringArray()


static func family(words: Array, lines: PackedStringArray, at: int = TITLE,
		anywhere: bool = false) -> Family:
	var out := Family.new()
	out.words = PackedStringArray(words)
	out.lines = lines
	out.at = at
	out.anywhere = anywhere
	return out


# -- reading ----------------------------------------------------------------------


## [param text] read: its sections and the app's lines in them.
static func of_text(text: String) -> MetaIndex:
	var out := MetaIndex.new()
	var size: int = text.length()
	out.size = size
	out.eol = LdrModel.eol_of(text)
	var model := Section.new()
	model.end = size
	out.sections.append(model)
	var within: int = 0
	var files: int = 0
	var at: int = 1 if text.begins_with("﻿") else 0
	if at >= size or text.unicode_at(at) != 48:
		at = _next_zero(text, at)
	while at >= 0:
		var stop: int = text.find("\n", at)
		var next: int = size if stop < 0 else stop + 1
		if stop < 0:
			stop = size
		var end: int = stop
		if end > at and text.unicode_at(end - 1) == 13:
			end -= 1
		var k: int = _past_blanks(text, at + 1, end)
		if k > at + 1 and k < end:
			var w: int = _to_blank(text, k, end)
			# Read as LdrModel.parse reads a keyword: any case, so "0 FiLe".
			var keyword: String = text.substr(k, w - k).to_upper()
			if keyword == WORD:
				var m: int = _past_blanks(text, w, end)
				var e: int = _to_blank(text, m, end)
				var line := Line.new()
				line.start = at
				line.stop = end
				line.next = next
				line.word = text.substr(m, e - m).to_upper()
				line.said = text.substr(e, end - e).strip_edges()
				line.raw = text.substr(at, end - at)
				line.section = within
				out.lines.append(line)
			elif keyword == "FILE":
				files += 1
				if files == 1:
					model.name = text.substr(w, end - w).strip_edges()
					model.file = at
					model.body = next
					within = 0
				else:
					if within >= 0:
						out.sections[within].end = at
					var section := Section.new()
					section.name = text.substr(w, end - w).strip_edges()
					section.file = at
					section.body = next
					section.end = size
					out.sections.append(section)
					within = out.sections.size() - 1
			elif keyword == "NOFILE":
				if within >= 0:
					out.sections[within].end = next
				within = -1
			elif keyword == "!DATA":
				if within >= 0:
					out.sections[within].end = at
				within = -1
				var named: String = text.substr(w, end - w).strip_edges().get_file().to_lower()
				if named.begins_with("brickworks-page-"):
					out.pictures.append(named)
			elif keyword == "ROTSTEP":
				out.rotsteps += 1
		at = _next_zero(text, stop)
	_head_of(text, model)
	return out


## The lines of the model's own section whose word is one of [param words]
## (a word ending "*" any word beginning so), in the file's order.
func own(words: Array) -> Array[Line]:
	var out: Array[Line] = []
	var wanted := PackedStringArray(words)
	for line: Line in lines:
		if line.section == 0 and matches(line.word, wanted):
			out.append(line)
	return out


## [method own], every section's.
func anywhere(words: Array) -> Array[Line]:
	var out: Array[Line] = []
	var wanted := PackedStringArray(words)
	for line: Line in lines:
		if matches(line.word, wanted):
			out.append(line)
	return out


## Whether the model's own section has a line of any of [param words].
func has(words: Array) -> bool:
	var wanted := PackedStringArray(words)
	for line: Line in lines:
		if line.section == 0 and matches(line.word, wanted):
			return true
	return false


## Whether any section has a line of any of [param words].
func has_anywhere(words: Array) -> bool:
	var wanted := PackedStringArray(words)
	for line: Line in lines:
		if matches(line.word, wanted):
			return true
	return false


## The model's own lines of [param words] as the file has them.
func raws(words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for line: Line in own(words):
		out.append(line.raw)
	return out


## The model's own lines of [param words] no reader took, as the file has
## them: written back as they are, where they are ([method lines_for]).
func untaken(words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for line: Line in own(words):
		if not line.taken:
			out.append(line.raw)
	return out


## The first of the model's own lines of [param word] that [param read]
## (what it says -> a value, or null for none it reads) reads, taken, and
## its value; null when none is read. The others stay untaken.
func first_read(word: String, read: Callable) -> Variant:
	for line: Line in own([word]):
		var value: Variant = read.call(line.said)
		if value != null:
			line.taken = true
			return value
	return null


## [param now], a feature's lines of [param words] as it says them, each
## that says what a line the file has said when it was read ([param read]:
## what a line says -> its value, empty or null for none) given as the file
## has it: a view read as {"yaw":30} and said again as {"yaw":30.0,
## "square":false} is the file's line, and an unedited save is the file
## (metalines).
func as_written(words: Array, now: PackedStringArray, read: Callable) -> PackedStringArray:
	var had: Array = []         ## [value, raw] of each line of the file's that was read
	for line: Line in own(words):
		if not line.taken:
			continue
		var value: Variant = read.call(line.said)
		if value != null and not (value is Dictionary and (value as Dictionary).is_empty()):
			had.append([value, line.raw])
	if had.is_empty():
		return now
	var out := PackedStringArray()
	for said: String in now:
		var line: String = said
		var k: int = _past_blanks(said, 1, said.length())
		var w: int = _to_blank(said, k, said.length())
		var m: int = _past_blanks(said, w, said.length())
		var e: int = _to_blank(said, m, said.length())
		var value: Variant = read.call(said.substr(e).strip_edges())
		for n: int in had.size():
			if had[n][0] == value:
				line = had[n][1]
				had.remove_at(n)
				break
		out.append(line)
	return out


## Whether [param word] is one of [param words] (a word ending "*" any word
## beginning so).
static func matches(word: String, words: PackedStringArray) -> bool:
	for one: String in words:
		if one == word or (one.ends_with("*") and word.begins_with(one.left(-1))):
			return true
	return false


## A line of the app's own as a writer writes it: "0 !BRICKWORKS", the word
## and what it says, one space between; [param line] as it is for any
## other.
static func clean(line: String) -> String:
	var end: int = line.length()
	if end > 0 and line.unicode_at(end - 1) == 13:
		end -= 1
	var at: int = 0
	if end == 0 or line.unicode_at(0) != 48:
		return line.left(end)
	var k: int = _past_blanks(line, 1, end)
	var w: int = _to_blank(line, k, end)
	if k == 1 or line.substr(k, w - k).to_upper() != WORD:
		return line.left(end)
	var m: int = _past_blanks(line, w, end)
	var e: int = _to_blank(line, m, end)
	return clean_of(line.substr(m, e - m).to_upper(), line.substr(e, end - e).strip_edges())


## The line of [param word] that says [param said] as two lines are told
## the same by: its words one space apart, as LDraw reads any run of spaces
## and tabs; and JSON as what it says, its keys in order and its numbers as
## numbers, so a file's "at":[0,0,0] says what the app's [0.0,0.0,0.0] does
## and an unedited save keeps the file's line (metalines).
static func clean_of(word: String, said: String) -> String:
	if said.begins_with("{") or said.begins_with("["):
		var parsed: Variant = JSON.parse_string(said)
		if parsed != null:
			said = JSON.stringify(parsed, "", true)
	elif said.contains("\t") or said.contains("  "):
		said = " ".join(LdrModel._fields(said))
	return "0 " + WORD + " " + word + ("" if said.is_empty() else " " + said)


# -- writing ----------------------------------------------------------------------


## [param now], the lines a feature says, with [param unread] (lines it
## keeps without reading them, as the file had them) each where it was among
## [param had] (the family's lines as the file was opened, [method raws]):
## after the line read before it, so a refused motion key stays between the
## keys either side of it (kt5check F1). A line read that is gone gives its
## place to the next line said that is new. An unread line the file did not
## have goes after the rest.
static func lines_for(had: PackedStringArray, now: PackedStringArray,
		unread: PackedStringArray) -> PackedStringArray:
	if unread.is_empty():
		return now
	var left: Dictionary = {}       ## clean -> how many of it are unread
	for line: String in unread:
		var key: String = clean(line)
		left[key] = int(left.get(key, 0)) + 1
	var kept := PackedStringArray()     ## each line of had, unread as it is, else ""
	var reads := PackedStringArray()    ## the clean lines of had that were read
	for line: String in had:
		var key: String = clean(line)
		if int(left.get(key, 0)) > 0:
			left[key] = int(left[key]) - 1
			kept.append(line)
		else:
			kept.append("")
			reads.append(key)
	var said := PackedStringArray()
	for line: String in now:
		said.append(clean(line))
	var keep: PackedInt32Array = aligned(reads, said)
	var stays := PackedByteArray()
	stays.resize(now.size())
	stays.fill(0)
	for k: int in keep:
		if k >= 0:
			stays[k] = 1
	var out := PackedStringArray()
	var j: int = 0
	var r: int = 0
	for n: int in had.size():
		if not kept[n].is_empty():
			out.append(kept[n])
			continue
		var k: int = keep[r]
		r += 1
		if k >= 0:
			while j <= k:
				out.append(now[j])
				j += 1
		elif j < now.size() and stays[j] == 0:
			out.append(now[j])
			j += 1
	while j < now.size():
		out.append(now[j])
		j += 1
	# Unread lines the file did not have (a motion renamed): after the rest.
	for line: String in unread:
		var key: String = clean(line)
		if int(left.get(key, 0)) > 0:
			left[key] = int(left[key]) - 1
			out.append(line)
	return out


## For each of [param had] the line of [param now] it is, the same words in
## the same order, -1 for none: each matched to the first unmatched one
## after the last matched, as a line diff matches lines.
static func aligned(had: PackedStringArray, now: PackedStringArray) -> PackedInt32Array:
	var keep := PackedInt32Array()
	keep.resize(had.size())
	keep.fill(-1)
	if had.is_empty() or now.is_empty():
		return keep
	var where: Dictionary = {}     ## a line -> its places in now, in order
	for j: int in now.size():
		if not where.has(now[j]):
			where[now[j]] = PackedInt32Array()
		var at: PackedInt32Array = where[now[j]]
		at.append(j)
		where[now[j]] = at
	var next_of: Dictionary = {}   ## a line -> the first of its places not passed
	var from: int = 0
	for i: int in had.size():
		if not where.has(had[i]):
			continue
		var at: PackedInt32Array = where[had[i]]
		var n: int = int(next_of.get(had[i], 0))
		while n < at.size() and at[n] < from:
			n += 1
		next_of[had[i]] = n + 1
		if n < at.size():
			keep[i] = at[n]
			from = at[n] + 1
	return keep


## [param text] with each of [param families] written into it
## ([method write]); the text as it is when none has a line or a word in it.
static func written(text: String, families: Array) -> String:
	var any: bool = false
	for family: Family in families:
		if not family.lines.is_empty():
			any = true
			break
	if not any and not text.contains(WORD):
		return text
	return of_text(text).write(text, families)


## [param text], the one this read, with each of [param families] written in
## the model's own section (or anywhere, for one that says so): each line it
## has that says what one of the family's says is kept as the text has it,
## where it has it; one the family has not got goes; one new goes in the
## place of one gone between its neighbours, else after the line before it,
## else before the line after it, else where the family's lines go
## ([member Family.at]). Each line put in ends as the text's lines do, and a
## text that ended without a line end still does.
func write(text: String, families: Array) -> String:
	var cut: Dictionary = {}       ## where a line taken out begins -> where the next does
	var put: Array = []            ## [where, order, line]
	var order: int = 0
	for family: Family in families:
		var had: Array[Line] = anywhere(family.words) if family.anywhere else own(family.words)
		var had_clean := PackedStringArray()
		for line: Line in had:
			had_clean.append(line.clean())
		var said := PackedStringArray()
		for line: String in family.lines:
			said.append(clean(line))
		var keep: PackedInt32Array = aligned(had_clean, said)
		var stays_as := PackedInt32Array()
		stays_as.resize(family.lines.size())
		stays_as.fill(-1)
		for i: int in had.size():
			if keep[i] >= 0:
				stays_as[keep[i]] = i
			else:
				cut[had[i].start] = had[i].next
		var used: Dictionary = {}
		var last: int = -1      ## the line of had the last one went at or after
		var after: int = -1     ## where a line goes to follow the last one
		for j: int in family.lines.size():
			if stays_as[j] >= 0:
				last = stays_as[j]
				after = had[last].next
				continue
			var upto: int = had.size()
			for k: int in range(j + 1, family.lines.size()):
				if stays_as[k] >= 0:
					upto = stays_as[k]
					break
			var slot: int = -1
			for i: int in range(last + 1, upto):
				if keep[i] < 0 and not used.has(i):
					slot = i
					break
			var where: int
			if slot >= 0:
				used[slot] = true
				last = slot
				where = had[slot].start
			elif after >= 0:
				where = after
			elif upto < had.size():
				where = had[upto].start
			else:
				where = sections[0].head_end if family.at == HEAD else sections[0].title_end
			put.append([where, order, family.lines[j]])
			order += 1
			after = where
	if cut.is_empty() and put.is_empty():
		return text
	put.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var starts: Array = cut.keys()
	starts.sort()
	var open_end: bool = size > 0 and not text.ends_with("\n")
	var pieces := PackedStringArray()
	var from: int = 0
	var p: int = 0
	var c: int = 0
	while p < put.size() or c < starts.size():
		var next_put: int = int(put[p][0]) if p < put.size() else size + 1
		var next_cut: int = int(starts[c]) if c < starts.size() else size + 1
		if next_put <= next_cut:
			if next_put > from:
				pieces.append(text.substr(from, next_put - from))
				from = next_put
			if next_put >= size and open_end:
				# After a last line with no line end: its line end first.
				pieces.append(eol)
				open_end = false
			pieces.append(str(put[p][2]).trim_suffix("\r") + eol)
			p += 1
		else:
			if next_cut > from:
				pieces.append(text.substr(from, next_cut - from))
			from = maxi(from, int(cut[next_cut]))
			c += 1
	if from < size:
		pieces.append(text.substr(from))
	var out: String = "".join(pieces)
	if size > 0 and not text.ends_with("\n") and out.ends_with("\n"):
		# Its last line taken out, or one put after it: it ends as it did.
		out = out.trim_suffix("\n").trim_suffix("\r")
	return out


# -- the head ---------------------------------------------------------------------


## [param section]'s title and head ends, read from its first lines.
static func _head_of(text: String, section: Section) -> void:
	var at: int = section.body
	section.title_end = at
	section.head_end = at
	if at >= section.end:
		return
	var next: int = _next_line(text, at)
	if _is_title(LdrModel._fields(text.substr(at, next - at))):
		section.title_end = next
		at = next
	var run: int = -1
	var count: int = 0
	while at < section.end and count < 400:
		next = _next_line(text, at)
		var line: String = text.substr(at, next - at)
		var words: PackedStringArray = LdrModel._fields(line)
		if words.is_empty() or words[0] != "0":
			break
		var keyword: String = words[1].to_upper() if words.size() > 1 else ""
		if keyword in ["FILE", "NOFILE", "!DATA", "STEP", "ROTSTEP"]:
			break
		if SourceFile._binds_next(line):
			run = at if run < 0 else run
		else:
			run = -1
		at = next
		count += 1
	section.head_end = run if run >= 0 else at


## Whether a line of [param words] is a model's title, as LdrModel.parse
## takes one: a comment that is no meta command.
static func _is_title(words: PackedStringArray) -> bool:
	if words.size() < 2 or words[0] != "0":
		return false
	var keyword: String = words[1].to_upper()
	return not keyword.begins_with("!") and not words[1].begins_with("//") \
		and not keyword in ["BFC", "NAME:", "AUTHOR:", "FILE", "NOFILE", "STEP", "ROTSTEP"]


static func _next_line(text: String, at: int) -> int:
	var stop: int = text.find("\n", at)
	return text.length() if stop < 0 else stop + 1


## Where the next line beginning "0" after [param from] begins, -1 for none.
static func _next_zero(text: String, from: int) -> int:
	var hit: int = text.find("\n0", from)
	return -1 if hit < 0 else hit + 1


static func _past_blanks(text: String, at: int, end: int) -> int:
	while at < end:
		var c: int = text.unicode_at(at)
		if c != 32 and c != 9:
			break
		at += 1
	return at


static func _to_blank(text: String, at: int, end: int) -> int:
	while at < end:
		var c: int = text.unicode_at(at)
		if c == 32 or c == 9:
			break
		at += 1
	return at
