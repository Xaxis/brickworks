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
## ([member Line.taken], [method lines_for]); so does a line of a word no
## feature reads ([method unclaimed]).
##
## Each line is in one of three states once the open has read it: taken (a
## reader read it into what its feature holds), beaten (a reader could read
## it, and another line won: a second FLOOR, a second view of one name) or
## unread (no reader could). Which is decided where it is read, by its place
## among its word's lines, and a save goes by those marks alone: up to
## mlfix it worked out again from the text which line had been read, and of
## two lines the same it kept the first and changed the second, so the next
## open read the old one again (mlcheck F1).
##
## Lines are found by the engine's search for a line beginning "0", so
## the cost is in the type 0 lines and not the parts: a line indented
## before its "0" is not one (no LDraw tool writes one).
class_name MetaIndex
extends RefCounted

## The word every line of the app's own begins with, after "0".
const WORD := "!BRICKWORKS"
## How nearly every one of them begins, as the app writes them: read past
## without a walk over its letters ([method of_text]).
const LEAD := "0 !BRICKWORKS "
## Where a family's lines go in the model when the file has none of them:
## under its title, after the model's first line whatever it is
## (LdrModel.title_end, into_main's rule too)...
const TITLE := 0
## ...or at the end of its head, after its name and author lines, before its
## first part, step or blank line (where ModelFloor put its line).
const HEAD := 1
## The words a reader of the app's reads in a model's file, besides the
## booklet's (BookletLooks.WORDS) and the motions' ("MOTION..."): a line of
## any other word is a later build's, kept as the file has it
## ([method unclaimed]). Each feature's reader is named beside its word.
const READ_WORDS: Array[String] = [
	"TITLE", "FROM_SET", "SHARE", "REMIX", "REMIX_VERSION", "CREDIT", "MADE", # ModelStore
	"FLOOR", "VIEW", "LIGHT", "CUT_AWAY", "HIDDEN_COLOURS", "PIN", "BIN", # each its own class
	"REFERENCE", "REFERENCE_PICTURE", # ReferenceImage
	"AUTHORED_STEPS", "WORKED_STEPS", "COPY", "IN", # LdrModel
	"PAGES", "PAGE", # SharedPages
]


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
	## A reader could read it, and took another line of its word in its
	## place: a second FLOOR, a second view of a name another has, a second
	## pin of one id. Kept while its feature says what the open read, and let
	## go once that changes ([method lines_for]).
	var beaten: bool = false

	## The line as a writer writes it: one space between its words.
	func clean() -> String:
		return raw if MetaIndex._plain(raw) else MetaIndex.clean_of(word, said)


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
	## Where a line under its title goes: after its first line, whatever it
	## is (LdrModel.title_end).
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
## Every line of the app's own, in the file's order, kept as columns: where
## it begins, ends before its CR and the next begins; the section it is in;
## its word; where in it what it says begins; the line. Its [Line] is made
## when a reader or writer asks for its word's lines ([method own]), once,
## so its [member Line.taken] stays: 200,000 light lines no reader can read
## cost each save of them a [Line] apiece, 2 s of a save of 3.7 (lights'
## _r_junk).
var _start := PackedInt32Array()
var _stop := PackedInt32Array()
var _next := PackedInt32Array()
var _section := PackedInt32Array()
var _said_at := PackedInt32Array()
var _word := PackedStringArray()
var _raw := PackedStringArray()
## Each one's [Line] once asked for, else null.
var _made: Array = []
## Their places in those columns by their word, each word's in the file's
## order: what a feature asks for is found without a look at the rest.
var _by_word: Dictionary = {}
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
		var raw: String = text.substr(at, end - at)
		if raw.begins_with(LEAD):
			# As the app writes one: its word up to the next space.
			var e: int = raw.find(" ", LEAD.length())
			if e < 0:
				e = raw.length()
			var word: String = raw.substr(LEAD.length(), e - LEAD.length())
			if not word.is_empty() and not word.contains("\t"):
				out._add(at, end, next, within, word.to_upper(), e, raw)
				at = _next_zero(text, stop)
				continue
		var k: int = _past_blanks(text, at + 1, end)
		if k > at + 1 and k < end:
			var w: int = _to_blank(text, k, end)
			# Read as LdrModel.parse reads a keyword: any case, so "0 FiLe".
			var keyword: String = text.substr(k, w - k).to_upper()
			if keyword == WORD:
				var m: int = _past_blanks(text, w, end)
				var e: int = _to_blank(text, m, end)
				out._add(at, end, next, within, text.substr(m, e - m).to_upper(), e - at, raw)
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


func _add(start: int, stop: int, next: int, section: int, word: String, said_at: int,
		raw: String) -> void:
	var n: int = _raw.size()
	_start.append(start)
	_stop.append(stop)
	_next.append(next)
	_section.append(section)
	_said_at.append(said_at)
	_word.append(word)
	_raw.append(raw)
	_made.append(null)
	var same: Variant = _by_word.get(word)
	if same == null:
		_by_word[word] = [n]
	else:
		(same as Array).append(n)


## The [Line] of the app's line [param n], made once.
func _line(n: int) -> Line:
	var made: Variant = _made[n]
	if made != null:
		return made
	var line := Line.new()
	line.start = _start[n]
	line.stop = _stop[n]
	line.next = _next[n]
	line.section = _section[n]
	line.word = _word[n]
	line.raw = _raw[n]
	line.said = line.raw.substr(_said_at[n]).strip_edges()
	_made[n] = line
	return line


## Where the lines of any of [param words] are (a word ending "*" any word
## beginning so), every section's, in the file's order.
func _of_words(words: Array) -> Array:
	var lists: Array = []
	var seen: Dictionary = {}
	for one: String in words:
		if one.ends_with("*"):
			var stem: String = one.left(-1)
			for word: String in _by_word:
				if word.begins_with(stem) and not seen.has(word):
					seen[word] = true
					lists.append(_by_word[word])
		elif _by_word.has(one) and not seen.has(one):
			seen[one] = true
			lists.append(_by_word[one])
	if lists.size() == 1:
		return lists[0]
	var all: Array = []
	for list: Array in lists:
		all.append_array(list)
	if lists.size() > 1:
		all.sort()
	return all


## The lines of [param words] as the file has them, the model's own or with
## [param everywhere] every section's, made into no [Line].
func _raws_of(words: Array, everywhere: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in _of_words(words):
		if everywhere or _section[n] == 0:
			out.append(_raw[n])
	return out


## The lines of the model's own section whose word is one of [param words]
## (a word ending "*" any word beginning so), in the file's order.
func own(words: Array) -> Array[Line]:
	var out: Array[Line] = []
	for n: int in _of_words(words):
		if _section[n] == 0:
			out.append(_line(n))
	return out


## [method own], every section's.
func anywhere(words: Array) -> Array[Line]:
	var out: Array[Line] = []
	for n: int in _of_words(words):
		out.append(_line(n))
	return out


## Whether the model's own section has a line of any of [param words].
func has(words: Array) -> bool:
	for n: int in _of_words(words):
		if _section[n] == 0:
			return true
	return false


## Whether any section has a line of any of [param words].
func has_anywhere(words: Array) -> bool:
	return not _of_words(words).is_empty()


## The model's own lines of [param words] as the file has them.
func raws(words: Array) -> PackedStringArray:
	return _raws_of(words, false)


## The model's own lines of [param words] no reader could read, as the file
## has them: written back as they are, where they are ([method lines_for]).
func untaken(words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in _of_words(words):
		if _section[n] == 0 and (_made[n] == null
				or not ((_made[n] as Line).taken or (_made[n] as Line).beaten)):
			out.append(_raw[n])
	return out


## The model's own lines of [param words] a reader could read and another
## line beat ([member Line.beaten]), as the file has them.
func beaten(words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in _of_words(words):
		if _section[n] == 0 and _made[n] != null and (_made[n] as Line).beaten:
			out.append(_raw[n])
	return out


## The first of the model's own lines of [param word] that [param read]
## (what it says -> a value, or null for none it reads) reads, taken, and
## its value; null when none is read. Each later one it reads is beaten
## ([member Line.beaten]), and one it cannot read is left unread.
func first_read(word: String, read: Callable) -> Variant:
	var found: Variant = null
	for line: Line in own([word]):
		var value: Variant = read.call(line.said)
		if value == null:
			continue
		if found == null:
			line.taken = true
			found = value
		else:
			line.beaten = true
	return found


## The model's own lines of [param words] at [param which] (their places
## among them, as [method raws] gives them) marked taken, each made into a
## [Line] and no other: for a reader that reads from the lines as the file
## has them (SceneLights.read_from), so 200,000 light lines past the most it
## tries cost no [Line] apiece.
func take(words: Array, which: PackedInt32Array) -> void:
	if which.is_empty():
		return
	var places := PackedInt32Array()
	for n: int in _of_words(words):
		if _section[n] == 0:
			places.append(n)
	for k: int in which:
		_line(places[k]).taken = true


## The model's own lines of a word no reader of the app's reads (a later
## build's, "0 !BRICKWORKS FUTURE_KIND ..."): one family of them all, as
## the file has them, in its order. Written back where the file had them,
## and, in a model written whole, at the end of its head. Up to mlfix such a
## line was lost at every save of the app's own file, and at a Make or a
## sub-model renamed in someone else's (mlcheck).
func unclaimed() -> Family:
	var words := PackedStringArray()
	for word: String in _by_word:
		if not (word in READ_WORDS or word in BookletLooks.WORDS or word.begins_with("MOTION")):
			words.append(word)
	var lines := PackedStringArray()
	if not words.is_empty():
		lines = _raws_of(Array(words), false)
	return family(Array(words), lines, HEAD)


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
	if _plain(line):
		return line
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


## Whether [param line] is one of the app's as [method clean] gives it:
## "0 !BRICKWORKS", a word in capitals and what it says, each one space
## apart, no JSON, its ends bare. Most are, and are told apart as they are.
static func _plain(line: String) -> bool:
	if not line.begins_with(LEAD) or line.contains("\t") or line.contains("  ") \
			or line.contains("{") or line.contains("[") or line.ends_with(" ") \
			or line.ends_with("\r"):
		return false
	var e: int = line.find(" ", LEAD.length())
	var word: String = line.substr(LEAD.length(), (line.length() if e < 0 else e) - LEAD.length())
	return not word.is_empty() and word == word.to_upper()


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


## The lines a save writes of [param words] in the model: [param now], what
## its feature says, with each of the model's own lines of them the open did
## not take kept as the file has it, where it was among them: after the line
## before it, so a refused motion key stays between the keys either side of
## it (kt5check F1). A line read that is gone gives its place to the next
## line said that is new.
##
## Which stay is told by each line's place and its reader's mark, never by
## its text: of two lines the same, the first taken and the second not, the
## second is the one kept and the change goes where the first was (mlcheck
## F1: two FLOOR GRID lines, the floor changed, and the next open read the
## one kept). A line no reader could read stays always. One a reader could
## read and another beat ([member Line.beaten]) stays only while [param now]
## says what the open read, so a save with nothing changed is the file; once
## the family changes it goes, or the next open would read it in place of
## what was saved (F2: every view taken out, and a second view named A came
## back).
##
## [param unread], when given, is the feature's own list of the lines it
## keeps unread (Motions.unread, which lets one go when the next open would
## read it): each is the first line not taken of its text, and one the file
## has none of (a motion renamed) goes after the rest. [param any_order]: the
## feature reads its lines in any order and says them in its own (pins, by
## when each was made), so [param now] saying the lines taken in another
## order says the same, and they stay in the file's.
func lines_for(words: Array, now: PackedStringArray, unread: Variant = null,
		any_order: bool = false) -> PackedStringArray:
	var places := PackedInt32Array()
	for n: int in _of_words(words):
		if _section[n] == 0:
			places.append(n)
	var keeps := PackedByteArray()      ## 1 for each of places kept as the file has it
	keeps.resize(places.size())
	keeps.fill(0)
	var after := PackedStringArray()    ## the feature's unread lines the file has not
	var any: bool = false
	if unread == null:
		var read := PackedStringArray()
		for n: int in places:
			var line: Line = _made[n]
			if line != null and line.taken:
				read.append(_raw[n])
		var same: bool = _same(read, now, any_order)
		if same and any_order:
			now = read
		for k: int in places.size():
			var line: Line = _made[places[k]]
			if line == null or not (line.taken or (line.beaten and not same)):
				keeps[k] = 1
				any = true
	else:
		var free: Dictionary = {}       ## a line as the file has it -> its places, none taken
		for k: int in places.size():
			var line: Line = _made[places[k]]
			if line == null or not line.taken:
				var raw: String = _raw[places[k]]
				if not free.has(raw):
					free[raw] = []
				(free[raw] as Array).append(k)
		for line: String in unread as PackedStringArray:
			var at: Array = free.get(line, [])
			if at.is_empty():
				after.append(line)
			else:
				keeps[int(at.pop_front())] = 1
				any = true
	if not any:
		if after.is_empty():
			return now
		var all: PackedStringArray = now.duplicate()
		all.append_array(after)
		return all
	# Paired by what they say and where they are, and only with a line taken:
	# one not taken and not kept (beaten, or a motion renamed) goes, and its
	# place is the next new line's, never a line of now that says the same,
	# which is the one taken (mi_fuzz: a refused key renamed, and the key it
	# had the words of, read further on, moved up into its place). A line of
	# now the same byte for byte as a twin of the one it was read from (a
	# motion written again as the app writes it) is not that twin's.
	var reads := PackedStringArray()    ## the clean lines of those not kept
	for k: int in places.size():
		if keeps[k] == 0:
			var line: Line = _made[places[k]]
			# A line end is in no clean line, so this pairs with nothing.
			reads.append(clean(_raw[places[k]]) if line != null and line.taken
				else "\n%d" % k)
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
	for k: int in places.size():
		if keeps[k] == 1:
			out.append(_raw[places[k]])
			continue
		var m: int = keep[r]
		r += 1
		if m >= 0:
			while j <= m:
				out.append(now[j])
				j += 1
		elif j < now.size() and stays[j] == 0:
			out.append(now[j])
			j += 1
	while j < now.size():
		out.append(now[j])
		j += 1
	# The feature's unread lines the file did not have (a motion renamed):
	# after the rest.
	out.append_array(after)
	return out


## Whether [param now] says what [param read] (the lines taken) does, each
## the same words, in its order or with [param any_order] in any.
static func _same(read: PackedStringArray, now: PackedStringArray, any_order: bool) -> bool:
	if read.size() != now.size():
		return false
	if not any_order:
		for n: int in read.size():
			if read[n] != now[n] and clean(read[n]) != clean(now[n]):
				return false
		return true
	var count: Dictionary = {}
	for line: String in read:
		var key: String = clean(line)
		count[key] = int(count.get(key, 0)) + 1
	for line: String in now:
		var key: String = clean(line)
		if int(count.get(key, 0)) == 0:
			return false
		count[key] = int(count[key]) - 1
	return true


## For each of [param had] the line of [param now] it is, the same words in
## the same order, -1 for none: each matched to the first unmatched one
## after the last matched, as a line diff matches lines. Where a line is
## there twice, the most lines matched, and of those the pairs the same
## byte for byte as [param had_raw] and [param now_raw] have them (when
## given), and then the nearest each other in place ([method _aligned_twins]).
static func aligned(had: PackedStringArray, now: PackedStringArray,
		had_raw := PackedStringArray(), now_raw := PackedStringArray()) -> PackedInt32Array:
	var keep := PackedInt32Array()
	keep.resize(had.size())
	keep.fill(-1)
	if had.is_empty() or now.is_empty():
		return keep
	if had.size() * now.size() <= TWINS_MOST and (_twice(had) or _twice(now)):
		return _aligned_twins(had, now, had_raw if had_raw.size() == had.size() else had,
			now_raw if now_raw.size() == now.size() else now)
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


## What pairing had's line [param i] with now's [param j] (from 1, the same
## words) is worth in [method _aligned_twins].
static func _pair(i: int, j: int, had_raw: PackedStringArray, now_raw: PackedStringArray) -> int:
	return (1 << 40) + ((1 << 20) if had_raw[i - 1] == now_raw[j - 1] else 0) - absi(i - j)


## The most pairs of lines [method aligned] works out with a table, past
## which it matches the first after the last, as for lines said once each.
const TWINS_MOST := 65536


## Whether [param lines] has a line twice.
static func _twice(lines: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for line: String in lines:
		if seen.has(line):
			return true
		seen[line] = true
	return false


## [method aligned] where a line is there twice: the longest run of lines
## both have in one order; of those the one with the most pairs the same
## byte for byte ([param had_raw], [param now_raw]); and of those the one
## whose pairs are nearest each other in place. Matched first after last,
## two lines the same, the first read and changed and the second not, the
## second was paired with the first's new line and everything between moved
## past it (mi_fuzz, mlfix).
static func _aligned_twins(had: PackedStringArray, now: PackedStringArray,
		had_raw: PackedStringArray, now_raw: PackedStringArray) -> PackedInt32Array:
	var rows: int = had.size() + 1
	var cols: int = now.size() + 1
	# Each cell: the lines matched in had[..i] and now[..j], how many of them
	# byte for byte, and how far apart their pairs are in all, as
	# matched * BIG + exact * MID - apart, the more the better.
	const BIG := 1 << 40
	const MID := 1 << 20
	var best := PackedInt64Array()
	best.resize(rows * cols)
	best.fill(0)
	for i: int in range(1, rows):
		for j: int in range(1, cols):
			var value: int = maxi(best[(i - 1) * cols + j], best[i * cols + j - 1])
			if had[i - 1] == now[j - 1]:
				value = maxi(value, best[(i - 1) * cols + j - 1] + _pair(i, j, had_raw, now_raw))
			best[i * cols + j] = value
	var keep := PackedInt32Array()
	keep.resize(had.size())
	keep.fill(-1)
	var i: int = had.size()
	var j: int = now.size()
	while i > 0 and j > 0:
		var here: int = best[i * cols + j]
		if had[i - 1] == now[j - 1] \
				and here == best[(i - 1) * cols + j - 1] + _pair(i, j, had_raw, now_raw):
			keep[i - 1] = j - 1
			i -= 1
			j -= 1
		elif here == best[(i - 1) * cols + j]:
			i -= 1
		else:
			j -= 1
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
		# Each line as the file has it, in its order: nothing to do.
		if _raws_of(family.words, family.anywhere) == family.lines:
			continue
		var had: Array[Line] = anywhere(family.words) if family.anywhere else own(family.words)
		var had_clean := PackedStringArray()
		var had_raw := PackedStringArray()
		for line: Line in had:
			had_clean.append(line.clean())
			had_raw.append(line.raw)
		var said := PackedStringArray()
		for line: String in family.lines:
			said.append(clean(line))
		var keep: PackedInt32Array = aligned(had_clean, said, had_raw, family.lines)
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
	section.title_end = LdrModel.title_end(text, section.body, section.end)
	section.head_end = section.title_end
	var at: int = section.title_end
	var run: int = -1
	var count: int = 0
	while at < section.end and count < 400:
		var next: int = _next_line(text, at)
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
