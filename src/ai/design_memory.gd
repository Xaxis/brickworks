## Our own scored designs, found by what they are: the designer's memory.
##
## The design bench (tools/bench, docs/DESIGN_SCORES.md) has a calibrated
## judge score each design it makes, with a line of reason a dimension.
## tools/design_memory.py keeps every scored design in
## assets/knowledge/designs.json.gz: its subject and brief, its scores, the
## judge's reasons, how it was built and a small picture of it. A designer
## starting a subject is handed what the best design of the nearest one
## did and what the judge faulted in it, so it starts past those faults
## rather than at them.
##
## Search is the real-set index's (src/ai/real_snippets.gd): BM25 over
## the weighted words tools/design_memory.py wrote, stemmed by the same
## words(), and a word naming a subject also asks for its kinds (an eagle
## for birds and animals, a store for houses). A design is near only if
## the query shares a word of its title or a kind of subject with it, so
## a revision ("make it two studs taller") is handed nothing; designs
## whose subject the query names come first, then designs of its kind.
##
## The bench's subjects are its test set. A batch designing one passes
## --held-out=<its id>, and that subject's designs are never found while
## it runs: memory may teach the designer about other subjects, never hand
## it the answer for the one being scored. A person's subject is new, and
## for them nothing is held out.
##
## Like the real-set index, the web build does not carry it in the pack;
## ensure() fetches it from beside the build (knowledge/).
class_name DesignMemory
extends RefCounted

const INDEX := "res://assets/knowledge/designs.json.gz"
const K1 := 1.2
const B := 0.75
## A word naming a subject asks for its kinds at this weight.
const KIND_WEIGHT := 0.5
## The judge's dimensions a picture is scored on, weakest across the suite
## first, which is the order a tie between faults is told in.
const VISUAL := ["technique", "surface", "creativity", "colour", "likeness"]
## Subjects told below the nearest.
const ALSO := 2
## A reason said in at most this many characters.
const SAID := 240

static var _document: Dictionary = {}
static var _tried: bool = false
static var _fetching: bool = false
## Stemmed word -> the kinds of subject it names.
static var _kinds_of: Dictionary = {}
static var _held_out: PackedStringArray = PackedStringArray()
static var _held_read: bool = false


static func document() -> Dictionary:
	if not _tried and (not OS.has_feature("web") or FileAccess.file_exists(INDEX)):
		_tried = true
		_take(RealSnippets.read(INDEX))
	return _document


## The index, wherever this build keeps it. True when there is one. Awaited.
static func ensure(host: Node) -> bool:
	if not _tried and OS.has_feature("web") and not FileAccess.file_exists(INDEX):
		while _fetching:
			await host.get_tree().process_frame
		if not _tried:
			_fetching = true
			_take(RealSnippets.parse(await RealSnippets.fetch(host, INDEX.get_file())))
			_tried = true
			_fetching = false
	return not document().get("entries", []).is_empty()


static func _take(read_in: Dictionary) -> void:
	_document = read_in
	_kinds_of.clear()
	var subjects: Dictionary = _document.get("subjects", {})
	for kind: String in subjects:
		for word: Variant in [kind] + (subjects[kind] as Array):
			for said: String in RealSnippets.words(str(word)):
				if not _kinds_of.has(said):
					_kinds_of[said] = []
				if not (_kinds_of[said] as Array).has(kind):
					(_kinds_of[said] as Array).append(kind)
	var held: PackedStringArray = held_out()
	if not held.is_empty():
		var hidden: int = 0
		for raw: Variant in _document.get("entries", []):
			if held.has(str((raw as Dictionary)["subject"])):
				hidden += 1
		# In the run's log, so a batch shows the flag took.
		print("design memory: holding out %s (%d designs)" % [", ".join(held), hidden])


## The subjects under test, from --held-out=a,b on the command line.
static func held_out() -> PackedStringArray:
	if not _held_read:
		_held_read = true
		_held_out = held_out_of(OS.get_cmdline_user_args())
	return _held_out


static func held_out_of(arguments: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for argument: String in arguments:
		if argument.begins_with("--held-out="):
			for id: String in argument.trim_prefix("--held-out=").split(",", false):
				out.append(id.strip_edges())
	return out


## Hold out these subjects instead, as the flag would. For probes.
static func hold_out(subjects: PackedStringArray) -> void:
	_held_read = true
	_held_out = subjects


## The query's words and their weights: each word, and the kinds of
## subject a word names at KIND_WEIGHT.
static func query_words(query: String) -> Dictionary:
	document()
	var out: Dictionary = {}
	for word: String in RealSnippets.words(query):
		out[word] = maxf(float(out.get(word, 0.0)), 1.0)
		for kind: Variant in _kinds_of.get(word, []):
			out[str(kind)] = maxf(float(out.get(str(kind), 0.0)), KIND_WEIGHT)
	return out


## The designs near a query, as [score, entry] pairs, best first, none of
## a held-out subject's.
static func search(query: String, limit: int = 8) -> Array:
	var doc: Dictionary = document()
	var idf: Dictionary = doc.get("idf", {})
	var average: float = maxf(float(doc.get("average", 1.0)), 0.001)
	var asked: Dictionary = query_words(query)
	var named: Dictionary = {}
	var kinds: Dictionary = {}
	for word: String in RealSnippets.words(query):
		named[word] = true
		for kind: Variant in _kinds_of.get(word, []):
			kinds[str(kind)] = true
	var held: PackedStringArray = held_out()
	var scored: Array = []
	for raw: Variant in doc.get("entries", []):
		var entry: Dictionary = raw
		if held.has(str(entry["subject"])):
			continue
		var direct: bool = (entry["named"] as Array).any(
			func(word: Variant) -> bool: return named.has(str(word)))
		var of_kind: bool = (entry["kinds"] as Array).any(
			func(kind: Variant) -> bool: return kinds.has(str(kind)))
		if not direct and not of_kind:
			continue
		# Named and of the kind asked for first; then of the kind; then a
		# word of its title alone ("speed" in a speed boat is no Porsche).
		var tier: int = 2 if direct and (of_kind or kinds.is_empty()) else 1 if of_kind else 0
		var terms: Dictionary = entry["t"]
		var score: float = 0.0
		for word: String in asked:
			var tf: float = float(terms.get(word, 0.0))
			if tf > 0.0:
				score += float(asked[word]) * float(idf.get(word, 0.0)) * tf * (K1 + 1.0) / (
					tf + K1 * (1.0 - B + B * float(entry["n"]) / average))
		scored.append([tier, snappedf(score, 0.000001), entry])
	scored.sort_custom(func(one: Array, other: Array) -> bool:
		if one[0] != other[0]:
			return one[0] > other[0]
		if one[1] != other[1]:
			return one[1] > other[1]
		return str(one[2]["id"]) < str(other[2]["id"]))
	var out: Array = []
	for row: Array in scored.slice(0, limit):
		out.append([row[1], row[2]])
	return out


## The subjects near a query, nearest first, each as its designs best
## first by the judge's visual mean.
static func near(query: String) -> Array:
	var order: PackedStringArray = PackedStringArray()
	for pair: Variant in search(query, 64):
		var subject: String = str((pair as Array)[1]["subject"])
		if not order.has(subject):
			order.append(subject)
	var out: Array = []
	for subject: String in order:
		var designs: Array = (document().get("entries", []) as Array).filter(
			func(entry: Variant) -> bool: return str((entry as Dictionary)["subject"]) == subject)
		designs.sort_custom(func(one: Dictionary, other: Dictionary) -> bool:
			if float(one["visual"]) != float(other["visual"]):
				return float(one["visual"]) > float(other["visual"])
			return str(one["id"]) > str(other["id"]))
		out.append(designs)
	return out


## What a designer starting [param query] is handed: the best design of the
## nearest subject — its scores, how it was built, the judge's faults to
## avoid and what it did best — a line for the next ALSO subjects, and,
## with [param picture], a picture of that best design. Content blocks; none
## when nothing is near. The app's own loop takes the words only: its first
## message's pictures are the reference, which a picture of our design must
## not be read as (src/dev/reference_probe.gd).
static func recall(query: String, picture: bool = true) -> Array:
	var subjects: Array = near(query)
	if subjects.is_empty():
		return []
	var designs: Array = subjects[0]
	var best: Dictionary = designs[0]
	var scores: Dictionary = best["scores"]
	var lines := PackedStringArray()
	lines.append("FROM OUR OWN SCORED DESIGNS. The design bench's judge scored "
		+ "designs made here 1-10 (%s). " % str(document().get("anchors", ""))
		+ "Start past them: keep what worked, and design out every fault "
		+ "below before you build.")
	lines.append("")
	var said_scores := PackedStringArray()
	for dimension: String in ["likeness", "surface", "colour", "technique", "creativity"]:
		said_scores.append("%s %d" % [dimension, int(scores[dimension])])
	lines.append("Nearest: %s. The best of %d design%s: %s (%d parts)." % [
		best["title"], designs.size(), "" if designs.size() == 1 else "s",
		", ".join(said_scores), int(best["parts"])])
	if not str(best.get("built", "")).is_empty():
		var shaped := PackedStringArray()
		for pair: Variant in best.get("shaped", []):
			shaped.append("%s x%d" % [(pair as Array)[0], int((pair as Array)[1])])
		lines.append("  Built with: %s (real sets since 2010: about a third plain)%s." % [
			best["built"], "" if shaped.is_empty() else "; most-used shaped parts " + ", ".join(shaped)])
	var process: Dictionary = best.get("process", {})
	var did := PackedStringArray()
	for pair: Array in [["features", "features worked"], ["laid", "real-set pieces laid"],
			["techniques", "worked techniques read"]]:
		var listed: Array = process.get(pair[0], [])
		if not listed.is_empty():
			did.append("%s: %s" % [pair[1], ", ".join(PackedStringArray(listed.slice(0, 6)))])
	if not did.is_empty():
		lines.append("  " + "; ".join(did) + ".")
	lines.append("  What the judge faulted, to design out:")
	for dimension: String in _faults(best):
		lines.append("  - %s %d: %s" % [dimension, int(scores[dimension]),
			_cut(str(best["reasons"][dimension]))])
	var strongest: String = _strongest(best)
	lines.append("  Its best, %s %d: %s" % [strongest, int(scores[strongest]),
		_cut(str(best["reasons"][strongest]))])
	for designs_of: Variant in subjects.slice(1, 1 + ALSO):
		var other: Dictionary = (designs_of as Array)[0]
		var weakest: String = _faults(other)[0]
		lines.append("Also near: %s, %s %d: %s" % [other["title"], weakest,
			int(other["scores"][weakest]), _cut(str(other["reasons"][weakest]), 160)])
	var blocks: Array = [{"type": "text", "text": "\n".join(lines)}]
	var thumb: String = str(best.get("thumb", ""))
	if picture and not thumb.is_empty():
		blocks.append({"type": "text", "text": "The picture is that best %s, scored %.1f "
			% [str(best["title"]).trim_prefix("a ").trim_prefix("an "), float(best["visual"])]
			+ "on the five: build better than it."})
		blocks.append({"type": "image", "source": {"type": "base64",
			"media_type": "image/jpeg", "data": thumb}})
	return blocks


## The text of recall(), for a caller that takes words only.
static func recall_text(query: String) -> String:
	var said := PackedStringArray()
	for block: Variant in recall(query, false):
		said.append(str((block as Dictionary)["text"]))
	return "\n".join(said)


## Its three weakest visual dimensions, and buildability when the build
## check faulted it (6 or less) and was the fixed check, weakest first.
static func _faults(entry: Dictionary) -> Array:
	var scores: Dictionary = entry["scores"]
	var order: Array = VISUAL.duplicate()
	order.sort_custom(func(one: String, other: String) -> bool:
		if int(scores[one]) != int(scores[other]):
			return int(scores[one]) < int(scores[other])
		return VISUAL.find(one) < VISUAL.find(other))
	var out: Array = order.slice(0, 3)
	if int(scores.get("buildability", 10)) <= 6 and bool(entry.get("build_told", true)):
		out.append("buildability")
	return out


static func _strongest(entry: Dictionary) -> String:
	var scores: Dictionary = entry["scores"]
	var best: String = VISUAL[0]
	for dimension: String in VISUAL:
		if int(scores[dimension]) > int(scores[best]):
			best = dimension
	return best


static func _cut(text: String, most: int = SAID) -> String:
	text = text.strip_edges()
	if text.length() <= most:
		return text
	var at: int = text.rfind(" ", most - 1)
	return text.left(at if at > most / 2 else most - 1).rstrip(",;:") + "…"
