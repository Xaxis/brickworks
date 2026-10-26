## Real sets' sub-assemblies, found by what they are.
##
## An expert asked for an owl's eye does not invent one; they remember
## how a set built it. LDraw's model repository has the real sets with
## every part placed, split by their modellers into named sub-models —
## Eye, Beak, Wing L, Bonnet, Grille — and tools/snippets.py indexes every
## one of them, and the unnamed clusters of craft round brackets, hinges
## and slopes, into assets/knowledge/snippets.json.gz: the set, its
## modeller and licence, size, parts, kinds, a description written by
## Claude from a picture of it, and the LDraw lines to place it as built.
##
## Search is the same as tools/snippets.py's: BM25 over the words each
## piece can be found by, weighted by field, the query's words stemmed
## alike, with pieces from sets about the query's subject first. Change
## one, change the other: src/dev/snippets_probe.gd checks they agree.
##
## The desktop reads the index from its own files. The web build does not
## carry it — 3.6 MB in the pack every visitor waits for, for the few who
## design — so ensure() fetches it from beside the build (knowledge/,
## which tools/export.sh web writes and deploy.sh serves under /b/<sha>/)
## the first time a design asks, and keeps it for the visit.
##
## A set under test is never in it. tools/bench/realset.py judges a design
## against the real set of the same brief, and starts the design with
## --held-out=<the set's number>: that set's pieces are dropped as the index
## is read, so the designer cannot lay the answer it is measured against.
class_name RealSnippets
extends RefCounted

const INDEX := "res://assets/knowledge/snippets.json.gz"
const K1 := 1.2
const B := 0.75
## A piece that lays as it stands counts this much more (src/dev/
## snippet_verdicts.gd checked each alone).
const LAYS := 1.25
## A word naming the subject ("bird" in "bird beak") counts this much in a
## piece's score: it has put the subject's sets first already, and within
## them the feature asked for should decide.
const SUBJECT_WEIGHT := 0.3

const FILLER := ["the", "a", "an", "of", "and", "with", "for", "in", "on", "to",
	"at", "by", "set", "model", "main", "mpd", "ldr", "dat", "sub", "submodel",
	"subpart", "subassembly", "assembly", "assy", "part", "parts", "step",
	"steps", "bag", "new", "build", "built", "complete", "final", "version",
	"alt", "alternate", "copy", "mod", "modified", "unnamed", "untitled", "nr",
	"no"]
const IRREGULAR := {"feet": "foot", "teeth": "tooth", "leaves": "leaf",
	"wolves": "wolf", "knives": "knife", "mice": "mouse", "geese": "goose",
	"men": "man", "calves": "calf", "halves": "half", "shelves": "shelf",
	"hooves": "hoof", "grey": "gray", "colour": "color", "tyre": "tire",
	"tyres": "tire", "aeroplane": "airplane", "storey": "story", "storeys": "story"}

static var _document: Dictionary = {}
static var _tried: bool = false
static var _fetching: bool = false
## Stemmed word -> the subjects it names, from the index's own table.
static var _subject_of: Dictionary = {}
static var _by_id: Dictionary = {}


## The index, read from this build's own files the first time anything
## asks. Empty when it has none — which on the web is until ensure() has
## fetched it.
static func document() -> Dictionary:
	if not _tried and (not OS.has_feature("web") or FileAccess.file_exists(INDEX)):
		_tried = true
		_take(read(INDEX))
	return _document


## The index, wherever this build keeps it: its own files, or on the web
## fetched from beside the build. True when there is one. Awaited.
static func ensure(host: Node) -> bool:
	if not _tried and OS.has_feature("web") and not FileAccess.file_exists(INDEX):
		while _fetching:
			await host.get_tree().process_frame
		if not _tried:
			_fetching = true
			_take(parse(await fetch(host, INDEX.get_file())))
			_tried = true
			_fetching = false
	return available()


## Lookups by subject word and by id, made once from a fresh index, with
## the pieces of any set held out (DesignMemory.held_out) left out.
static func _take(read_in: Dictionary) -> void:
	_document = read_in
	_subject_of.clear()
	_by_id.clear()
	var held: PackedStringArray = DesignMemory.held_out()
	if not held.is_empty() and _document.has("entries"):
		var kept: Array = []
		var hidden: Dictionary = {}
		for raw: Variant in _document["entries"]:
			var from: String = str((raw as Dictionary).get("set", ""))
			if held.has(from):
				hidden[from] = int(hidden.get(from, 0)) + 1
			else:
				kept.append(raw)
		_document["entries"] = kept
		for from: String in hidden:
			# In the run's log, so a batch shows the set under test was out.
			print("real sets: holding out %s (%d pieces)" % [from, int(hidden[from])])
	var subjects: Dictionary = _document.get("subjects", {})
	for subject: String in subjects:
		for word: Variant in [subject] + (subjects[subject] as Array):
			for said: String in words(str(word)):
				if not _subject_of.has(said):
					_subject_of[said] = []
				if not (_subject_of[said] as Array).has(subject):
					(_subject_of[said] as Array).append(subject)
	for raw: Variant in _document.get("entries", []):
		var entry: Dictionary = raw
		_by_id[str(entry["id"])] = entry


static func available() -> bool:
	return not document().get("entries", []).is_empty()


## An index file, gzipped or not.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_bytes(path))


## A file's bytes as the index, gzipped or not: told by its first two
## bytes, because a server may unzip a .gz on the way (Content-Encoding)
## or may not.
static func parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > 2 and bytes[0] == 0x1f and bytes[1] == 0x8b:
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


## A file from beside the web build, or nothing.
static func fetch(host: Node, file_name: String) -> PackedByteArray:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	host.add_child(http)
	if http.request(Origin.build() + "knowledge/" + file_name) != OK:
		http.queue_free()
		return PackedByteArray()
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		push_warning("real-set index: knowledge/%s did not arrive (%d, %d)"
			% [file_name, int(result[0]), int(result[1])])
		return PackedByteArray()
	return result[3]


static func stem(word: String) -> String:
	word = word.to_lower()
	if IRREGULAR.has(word):
		return IRREGULAR[word]
	if word.length() > 4 and word.ends_with("ies"):
		return word.left(-3) + "y"
	if word.length() > 4:
		for ending: String in ["ches", "shes", "sses", "xes", "zes"]:
			if word.ends_with(ending):
				return word.left(-2)
	if word.length() > 3 and word.ends_with("s") and not (word.ends_with("ss")
			or word.ends_with("us") or word.ends_with("is")):
		return word.left(-1)
	return word


## A phrase as stemmed words, as tools/snippets.py words() has them.
static func words(text: String) -> PackedStringArray:
	var spaced := RegEx.create_from_string("([a-z])([A-Z])").sub(text, "$1 $2", true)
	# One letter and a word are one name: a Y-wing is not a wing. Not L or
	# R, which are left and right.
	spaced = RegEx.create_from_string("\\b([A-KM-QS-Za-km-qs-z])-([A-Za-z]{2,})").sub(spaced, "$1$2", true)
	spaced = RegEx.create_from_string("([A-Za-z])(\\d)").sub(spaced, "$1 $2", true)
	var out := PackedStringArray()
	for found: RegExMatch in RegEx.create_from_string("[a-z0-9]+").search_all(spaced.to_lower()):
		var word: String = found.get_string()
		if word in FILLER or word.is_valid_int() or word.length() < 3:
			continue
		out.append(stem(word))
	return out


## The query's words and their weights, with two run together where the
## index knows them that way: "wheel arch" also asks for "wheelarch",
## which counts double, being both words at once.
static func query_words(query: String) -> Dictionary:
	var idf: Dictionary = document().get("idf", {})
	var found: PackedStringArray = words(query)
	var out: Dictionary = {}
	for word: String in found:
		out[word] = float(out.get(word, 0.0)) + (SUBJECT_WEIGHT if _subject_of.has(word) else 1.0)
	for n: int in range(found.size() - 1):
		if idf.has(found[n] + found[n + 1]):
			out[found[n] + found[n + 1]] = float(out.get(found[n] + found[n + 1], 0.0)) + 2.0
	return out


## The best few pieces for a query, as [score, entry] pairs: at most
## per_set from one set, none wider or deeper than max_studs (0 for any
## size), and of every kind asked for.
static func search(query: String, max_studs: float = 0.0, kinds: Array = [],
		limit: int = 5, per_set: int = 2) -> Array:
	var doc: Dictionary = document()
	var idf: Dictionary = doc.get("idf", {})
	var average: float = maxf(float(doc.get("average", 1.0)), 0.001)
	var asked: Dictionary = query_words(query)
	# The subject named, and the kinds it is of: an owl, and a bird and an
	# animal.
	var named_subjects: Dictionary = {}
	var subjects: Dictionary = {}
	for word: String in asked:
		if _subject_of.has(word):
			named_subjects[word] = true
			for subject: Variant in _subject_of[word]:
				subjects[str(subject)] = true
	var scored: Array = []
	for raw: Variant in doc.get("entries", []):
		var entry: Dictionary = raw
		var size: Array = entry["size"]
		if max_studs > 0.0 and maxf(float(size[0]), float(size[2])) > max_studs:
			continue
		var has_kinds: bool = true
		for kind: Variant in kinds:
			if not (entry["kinds"] as Array).has(kind):
				has_kinds = false
		if not has_kinds:
			continue
		var terms: Dictionary = entry["t"]
		var score: float = 0.0
		var named: bool = false
		for word: String in asked:
			var tf: float = float(terms.get(word, 0.0))
			if tf <= 0.0:
				continue
			score += float(asked[word]) * float(idf.get(word, 0.0)) * tf * (K1 + 1.0) / (
				tf + K1 * (1.0 - B + B * float(entry["n"]) / average))
			if not _subject_of.has(word):
				named = true
		if score <= 0.0:
			continue
		if bool(entry.get("lays", false)):
			score *= LAYS
		# Sets about the subject first, then sets about its kind, where
		# what was asked for is in them too: otherwise every piece of an
		# owl set would come before every other set's eye.
		var tier: int = 0
		if named:
			for subject: Variant in entry["subject"]:
				if named_subjects.has(str(subject)):
					tier = 2
					break
				if subjects.has(str(subject)):
					tier = 1
		scored.append([tier, score, entry])
	# Ties by id, as tools/snippets.py breaks them.
	scored.sort_custom(func(one: Array, other: Array) -> bool:
		if one[0] != other[0]:
			return one[0] > other[0]
		var mine: float = snappedf(float(one[1]), 0.000001)
		var theirs: float = snappedf(float(other[1]), 0.000001)
		if mine != theirs:
			return mine > theirs
		return str(one[2]["id"]) < str(other[2]["id"]))
	var out: Array = []
	var taken: Dictionary = {}
	for row: Array in scored:
		var entry: Dictionary = row[2]
		var from: String = str(entry["set"])
		if int(taken.get(from, 0)) >= per_set:
			continue
		taken[from] = int(taken.get(from, 0)) + 1
		out.append([row[1], entry])
		if out.size() >= limit:
			break
	return out


## Whether the index knows [param word] (stemmed) as a subject: owl, car.
static func is_subject(word: String) -> bool:
	document()
	return _subject_of.has(word)


## The subjects [param word] names, by the index's own table: "cottage" is
## a house, "tug" a boat. Empty for a word it does not know as one.
static func subjects_of(word: String) -> Array:
	document()
	return _subject_of.get(stem(word), [])


## [param word] (stemmed) and the words the index takes as the same thing
## (its synonyms table): a hand is a claw or a gripper, a window a pane.
static func kin(word: String) -> PackedStringArray:
	var out := PackedStringArray([stem(word)])
	for row: Variant in document().get("synonyms", []):
		var group: PackedStringArray = words(str(row))
		if group.has(out[0]):
			for one: String in group:
				if not out.has(one):
					out.append(one)
	return out


## What a piece is, as stemmed words: its description up to the colon
## ("tugboat funnel or smokestack: a column of ...", the how after it), and
## of that what comes before a "with" or an "on": a word anywhere else in it
## is how it was built, what it carries or where it came from. A column of
## round bricks that is a tugboat's funnel is not its fenders, nor its
## windows, and "a robot on a base with control panel" is not a chest panel.
## Not its name, which is its modeller's: "4wd-locker" is a differential lock.
static func what_it_is(entry: Dictionary) -> PackedStringArray:
	var head: String = str(entry.get("text", "")).get_slice(":", 0)
	var cut: RegExMatch = _CARRIES.search(head)
	return words(head.left(cut.get_start()) if cut != null and cut.get_start() > 0 else head)


static var _CARRIES := RegEx.create_from_string(
	"(?i)\\b(with|on|for|holding|carrying|over|under|beside|behind|inside|atop)\\b")


## Words that say how much of a thing a piece is, never what: "tower roof
## ridge section" is a ridge, "jet engine exhaust nozzle block" a nozzle.
## A word for where on a thing it is stays its head: a bus's front end is a
## front, not a bus, as a lion's belly is not a lion.
const FILLER_HEADS := ["section", "segment", "detail", "piece", "part", "assembly",
	"subassembly", "unit", "element", "module", "cluster", "structure", "block",
	"portion", "component", "frame", "housing", "mount", "mounting", "build",
	"construction", "mechanism", "arrangement", "combination", "group"]


## What a piece is, by the head noun of each thing its description says it
## is, stemmed: [[first reading's heads], [the next reading's], ...]. A
## piece is named by its head, not by a word that only describes it: a
## "pool cue rack" is a rack, not a pool, a "yellow lion belly" a belly, a
## "bus bonnet" a bonnet. main's and main2's sessions rejected 63 of 72
## pieces handed for features, matched on any word: a Technic gearbox for
## a skyscraper's crown ("a 24-tooth crown gear"), a cue rack for a
## reflecting pool. "traffic cone or warning beacon" is a cone first, a
## beacon only as its second reading; "car windscreen and roof" both.
static func heads_of(entry: Dictionary) -> Array:
	var head: String = str(entry.get("text", "")).get_slice(":", 0)
	var cut: RegExMatch = _CARRIES.search(head)
	if cut != null and cut.get_start() > 0:
		head = head.left(cut.get_start())
	# "top-left of Boba Fett's helmet dome" is a top-left, not a dome; "row of
	# windows" windows.
	var of: RegExMatch = _OF.search(head)
	if of != null:
		var before: PackedStringArray = words(of.get_string(1))
		head = of.get_string(2) if not before.is_empty() and COUNTED.has(before[-1]) \
			else of.get_string(1)
	var out: Array = []
	for reading: String in _READINGS.sub(head, "|", true).split("|", false):
		var heads := PackedStringArray()
		for thing: String in _AND.sub(reading, "|", true).split("|", false):
			for one: String in head_words(thing):
				if not heads.has(one):
					heads.append(one)
		if not heads.is_empty():
			out.append(heads)
	return out


## The head of a noun phrase, stemmed: its last word that is not
## [constant FILLER_HEADS]. "tower roof ridge section" is [ridge]. Empty for
## no word.
static func head_words(phrase: String) -> PackedStringArray:
	var said: PackedStringArray = words(phrase)
	for n: int in range(said.size() - 1, -1, -1):
		if not FILLER_HEADS.has(said[n]):
			return PackedStringArray([said[n]])
	return PackedStringArray([said[-1]]) if not said.is_empty() else PackedStringArray()


## Whether a piece can be laid whole into a model: square to the grid, and
## whole as it stands or wanting only a hold from the model (alone, its
## verdict is floating, not held, or in pieces: PieceHold finds the hold).
## Not one the check refuses as it was built, an overlap or a collision of
## its own parts, which no hold mends.
static func holdable(entry: Dictionary) -> bool:
	if not bool(entry.get("square", true)) or not entry.has("lays"):
		return false
	if bool(entry["lays"]):
		return true
	var why: String = str(entry.get("why", ""))
	for said: String in why.split(",", false):
		var one: String = said.strip_edges()
		if not (one == "floating" or one == "not held" or one.ends_with(" pieces")):
			return false
	return not why.is_empty()


## The same build at the other sizes real sets use it: pieces that are the
## same thing by their first reading (an arch, a shell, a fender), made of
## much the same parts, as small and as big as sets made them, smallest
## first, each laid whole by place_technique. An arch of two 1 x 4 arches
## for a gateway, of 1 x 12 x 3 ones for a bridge.
static func sizes_of(entry: Dictionary, limit: int = 3) -> Array:
	var mine: PackedStringArray = first_heads(entry)
	if mine.is_empty():
		return []
	var parts: Dictionary = _parts_of(entry)
	var scored: Array = []
	for raw: Variant in document().get("entries", []):
		var other: Dictionary = raw
		if other["id"] == entry["id"] or not first_heads(other).has(mine[0]) \
				or not holdable(other):
			continue
		var alike: float = _alike(parts, _parts_of(other)) + 0.5 * _alike(
			_set_of(entry.get("kinds", [])), _set_of(other.get("kinds", [])))
		if alike >= 0.25:
			scored.append([alike, other])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] if a[0] != b[0] else str(a[1]["id"]) < str(b[1]["id"]))
	var kept: Array = []
	var sizes: Array = [footprint(entry)]
	for row: Array in scored:
		var size: float = footprint(row[1])
		var apart: bool = true
		for other_size: float in sizes:
			if maxf(size, other_size) < 1.4 * minf(size, other_size):
				apart = false
		if apart:
			kept.append(row[1])
			sizes.append(size)
		if kept.size() >= limit:
			break
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return footprint(a) < footprint(b))
	return kept


## How much ground a piece covers, in studs: its width by its depth, the
## height counted for one that stands taller than it is wide.
static func footprint(entry: Dictionary) -> float:
	var size: Array = entry["size"]
	return maxf(1.0, float(size[0])) * maxf(1.0, float(size[2])) \
		* maxf(1.0, float(size[1]) / 3.0 / maxf(1.0, maxf(float(size[0]), float(size[2]))))


static var _first_heads: Dictionary = {}


## The heads of a piece's first reading, kept once worked out.
static func first_heads(entry: Dictionary) -> PackedStringArray:
	var id: String = str(entry["id"])
	if not _first_heads.has(id):
		var readings: Array = heads_of(entry)
		_first_heads[id] = readings[0] if not readings.is_empty() else PackedStringArray()
	return _first_heads[id]


static func _parts_of(entry: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for line: Variant in entry.get("bom", []):
		out[str((line as Array)[0])] = true
	return out


static func _set_of(items: Variant) -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in items as Array:
		out[str(item)] = true
	return out


## Jaccard: what two sets share, of all either has.
static func _alike(one: Dictionary, other: Dictionary) -> float:
	if one.is_empty() and other.is_empty():
		return 0.0
	var shared: int = 0
	for key: Variant in one:
		if other.has(key):
			shared += 1
	return float(shared) / float(one.size() + other.size() - shared)


## Words a thing is counted in: a row of windows is windows.
const COUNTED := ["row", "pair", "set", "line", "column", "ring", "stack", "bank",
	"band", "string", "array", "series", "couple", "number", "run", "tier", "cluster",
	"group", "collection", "bunch"]
static var _OF := RegEx.create_from_string("(?i)^(.*?)\\s+\\bof\\b\\s+(.*)$")
static var _READINGS := RegEx.create_from_string("(?i)\\s*(?:\\bor\\b|,|;|/)\\s*")
static var _AND := RegEx.create_from_string("(?i)\\s*(?:\\band\\b|&|\\+)\\s*")


static func entry(id: String) -> Dictionary:
	document()
	return _by_id.get(id.strip_edges(), {})


## Who made it and under what terms, said wherever it is shown or placed.
static func credit(entry: Dictionary) -> String:
	var year: int = int(entry.get("year", 0))
	return "from %s %s%s, model by %s, %s, LDraw Official Model Repository" % [
		str(entry["set"]).trim_suffix("-1"), entry["set_name"],
		" (%d)" % year if year > 0 else "", entry["by"], entry["licence"]]


## The piece as a standalone LDraw file, credited on its second line.
static func ldr_text(entry: Dictionary) -> String:
	var lines := PackedStringArray(["0 %s" % entry["name"], "0 // " + credit(entry)])
	for line: Variant in entry["ldr"]:
		lines.append("1 " + str(line))
	return "\n".join(lines) + "\n"


## What families of parts read as in a model (tools/part_looks.py): a
## feather, a claw, an exhaust, by the words a designer would use, where
## the catalogue says "Plate 1 x 2 with Tooth".
const LOOKS := "res://assets/knowledge/part_looks.json"
static var _looks: Dictionary = {}
static var _looks_tried: bool = false


static func looks() -> Dictionary:
	if not _looks_tried and (not OS.has_feature("web") or FileAccess.file_exists(LOOKS)):
		_looks_tried = true
		_looks = read(LOOKS)
	return _looks


## The same, fetched from beside the web build the first time. Awaited.
static func ensure_looks(host: Node) -> bool:
	if not _looks_tried and OS.has_feature("web") and not FileAccess.file_exists(LOOKS):
		_looks_tried = true
		_looks = parse(await fetch(host, LOOKS.get_file()))
	return not looks().get("families", []).is_empty()


## The families whose look matches the query best, best first.
static func search_looks(query: String, limit: int = 6) -> Array:
	var doc: Dictionary = looks()
	var idf: Dictionary = doc.get("idf", {})
	var average: float = maxf(float(doc.get("average", 1.0)), 0.001)
	var asked: PackedStringArray = words(query)
	var scored: Array = []
	for raw: Variant in doc.get("families", []):
		var row: Dictionary = raw
		var terms: Dictionary = row["t"]
		var score: float = 0.0
		for word: String in asked:
			var tf: float = float(terms.get(word, 0.0))
			if tf > 0.0:
				score += float(idf.get(word, 0.0)) * tf * (K1 + 1.0) / (
					tf + K1 * (1.0 - B + B * float(row["n"]) / average))
		if score > 0.0:
			scored.append([snappedf(score, 0.000001), row])
	scored.sort_custom(func(one: Array, other: Array) -> bool:
		if one[0] != other[0]:
			return one[0] > other[0]
		return str(one[1]["family"]) < str(other[1]["family"]))
	var out: Array = []
	for row: Array in scored.slice(0, limit):
		out.append(row[1])
	return out


## A name for its picture: the id with nothing a file system minds.
static func file_name(entry: Dictionary) -> String:
	return str(entry["id"]).replace("/", "__").replace("'", "").replace(" ", "_")
