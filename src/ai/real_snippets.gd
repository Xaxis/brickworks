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
class_name RealSnippets
extends RefCounted

const INDEX := "res://assets/knowledge/snippets.json.gz"
const K1 := 1.2
const B := 0.75
## A piece that lays as it stands counts this much more (src/dev/
## snippet_verdicts.gd checked each alone).
const LAYS := 1.25

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
## Stemmed word -> the subjects it names, from the index's own table.
static var _subject_of: Dictionary = {}
static var _by_id: Dictionary = {}


## The index, read the first time anything asks. Empty when this build
## has none.
static func document() -> Dictionary:
	if not _tried:
		_tried = true
		_document = read(INDEX)
		_subject_of.clear()
		_by_id.clear()
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
	return _document


static func available() -> bool:
	return not document().get("entries", []).is_empty()


## An index file, gzipped or not.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if path.ends_with(".gz"):
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


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
		out[word] = float(out.get(word, 0.0)) + 1.0
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
	if not _looks_tried:
		_looks_tried = true
		_looks = read(LOOKS)
	return _looks


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
