## A challenge's rules, ticked on the model open in the studio
## (challengestudio, 2026-11-23): the month's challenge open now, its rules
## from api/people.js ?op=challenge_rules (its set's parts as they were kept
## when it was set, supabase/challenge_studio.sql), and what each says of
## the model as it stands, said as the person can act on it.
##
## The site checks an entry on the stored file (supabase/challenges.sql
## challenge_check): its parts against most_parts, what it needs
## (model_needs) against the set's parts, and its Tested mark. What the
## file's parts and needs are is api/share.js checkModel's, as a publish
## counts them, spelled as api/_owned.js keyed spells them. Each is ported
## here exactly, step for step, so the studio's tick is the site's answer
## for the file a publish would send ([method facts_of], [method check]);
## tools/challenge_rules_check.mjs and src/dev/challenge_rules_probe.gd run
## both on 30 published models under three rules and compare every answer.
##
## Tested is the app's own finding, which the site keeps and never makes:
## the four tests a publish runs (SharedPages.attach_tested). It is not
## ticked live, for one run can take a minute on a big model: it is
## unknown until the person runs it (Test it), or until a publish does.
class_name ChallengeRules
extends RefCounted

## The most of the lots short said, as challenge_check says them.
const MOST_SHORT := 12
## The most parts a shared model may have (api/share.js).
const MOST_PARTS := 200000
## A mould's letter on a part's number: 3794a is 3794 (api/_owned.js MOULD).
const _MOULD := "^([ux]?\\d+)[a-z]$"
## The pieces a flexible part is laid from, by their kind (api/share.js
## FLEX_PIECES): a sub-model of one kind's pieces alone is one part.
const FLEX_PIECES: Dictionary = {
	"71944k01": "ribbed_hose", "71944k02": "ribbed_hose",
	"71533k02": "pneumatic_tube", "71533k03": "pneumatic_tube",
	"u9053": "flex_hose", "77": "flex_hose",
	"u9010": "flex_axle", "u9011": "flex_axle", "u9012": "flex_axle",
	"71149k01": "string", "71149k02": "string",
}


# -- the rules, read at the edge -----------------------------------------------

## The challenge an answer of ?op=challenge_rules names, read at the edge:
## {id, title, brief, starts_on, ends_on, entries_until, entering, page,
## test, rules: {most_parts: int (0 for none), set: {} or {number, name,
## lots: {"part/colour": qty}}, tested: bool}}; {} for none, or for any other
## status or shape. A rule of the wrong shape is no challenge at all: a
## half-read rule would tick what the site refuses.
static func rules_in(answer: Dictionary) -> Dictionary:
	if int(answer.get("code", 0)) != 200 or not answer.get("body") is Dictionary:
		return {}
	var said: Variant = (answer["body"] as Dictionary).get("challenge")
	if not said is Dictionary:
		return {}
	var c: Dictionary = said
	var id: Variant = c.get("id")
	var title: String = str(c["title"]).strip_edges() if c.get("title") is String else ""
	var ends: String = str(c["ends_on"]) if c.get("ends_on") is String else ""
	if not (id is int or id is float) or int(id) <= 0 or title.is_empty() \
			or SharedModels.day_words(ends).is_empty() or not c.get("rules") is Dictionary:
		return {}
	var given: Dictionary = c["rules"]
	var rules: Dictionary = {"most_parts": 0, "set": {}, "tested": given.get("tested") == true}
	var most: Variant = given.get("most_parts")
	if most != null:
		if not (most is int or most is float) or int(most) < 1:
			return {}
		rules["most_parts"] = int(most)
	if given.get("set") != null:
		if not given["set"] is Dictionary or not (given["set"] as Dictionary).get("lots") is Array:
			return {}
		var set_said: Dictionary = given["set"]
		var lots: Dictionary = {}
		for lot: Variant in set_said["lots"]:
			if not lot is Array or (lot as Array).size() != 3 or not lot[0] is String \
					or not (lot[1] is int or lot[1] is float) or not (lot[2] is int or lot[2] is float):
				return {}
			lots["%s/%d" % [lot[0], int(lot[1])]] = int(lot[2])
		var number: String = str(set_said.get("number", ""))
		if number.is_empty():
			return {}
		rules["set"] = {"number": number,
			"name": str(set_said["name"]) if set_said.get("name") is String else "", "lots": lots}
	var page: String = str(c["page"]) if c.get("page") is String else ""
	var until: String = str(c["entries_until"]) if c.get("entries_until") is String else ""
	return {"id": int(id), "title": title,
		"brief": str(c["brief"]).strip_edges() if c.get("brief") is String else "",
		"starts_on": str(c["starts_on"]) if c.get("starts_on") is String else "",
		"ends_on": ends, "entries_until": until if not SharedModels.day_words(until).is_empty() else "",
		"entering": c.get("entering") != false, "test": c.get("test") == true,
		"page": page if page.begins_with("https://") or page.begins_with("http://127.0.0.1") else "",
		"rules": rules}


## Whether [param challenge] ([method rules_in]) has a rule to tick.
static func has_rules(challenge: Dictionary) -> bool:
	if challenge.is_empty():
		return false
	var rules: Dictionary = challenge["rules"]
	return int(rules["most_parts"]) > 0 or not (rules["set"] as Dictionary).is_empty() \
		or bool(rules["tested"])


## The day entries close: entries_until in rounds, else the last day.
static func last_day(challenge: Dictionary) -> String:
	var until: String = str(challenge.get("entries_until", ""))
	return until if not until.is_empty() else str(challenge.get("ends_on", ""))


## Whole days left to enter, today one of them, on [param today] ("2026-11-23",
## UTC as a challenge's days are); -1 for a day that is no day.
static func days_left(day: String, today: String) -> int:
	if SharedModels.day_words(day).is_empty() or SharedModels.day_words(today).is_empty():
		return -1
	var last: int = Time.get_unix_time_from_datetime_string(day + "T00:00:00")
	var now: int = Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	return maxi(0, int((last - now) / 86400) + 1)


## Today as a challenge's days are, in UTC.
static func today() -> String:
	return Time.get_date_string_from_system(true)


# -- what the file says, as a publish counts it ------------------------------

## What [param text] holds for the rules, as api/share.js checkModel counts
## the file a publish sends: {"parts": int, "needs": {"part/colour": qty}},
## the needs spelled as model_needs keeps them ([method spelled_needs]);
## {"error": words} for a file a publish refuses. [method read] then
## [method spelled_needs]: the first touches nothing but the text, so a big
## model's is read on a worker.
static func facts_of(text: String, library: PartLibrary) -> Dictionary:
	var read_out: Dictionary = read(text)
	if read_out.has("error"):
		return read_out
	return {"parts": read_out["parts"], "needs": spelled_needs(read_out["needs"], library)}


## checkModel's reading of [param text], the parts and what it needs as the
## file names them: {"parts": int, "needs": [[part, colour, qty]]} or
## {"error": words}. Nothing but the text is read, so any thread may run it.
static func read(text: String) -> Dictionary:
	var files: Dictionary = {}
	var order: Array[String] = []
	var blocks: Dictionary = {}
	var current: Dictionary = _file("", false)
	var in_data: bool = false
	var colour_re: RegEx = RegEx.create_from_string("^(\\d+|0x[0-9A-Fa-f]{7})$")
	var number_re: RegEx = RegEx.create_from_string("^[-+]?(\\d+\\.?\\d*|\\.\\d+)([eE][-+]?\\d+)?$")
	var part_re: RegEx = RegEx.create_from_string("(?i)part|shortcut|primitive|subpart")
	var coords: Dictionary = {"2": 6, "3": 9, "4": 12, "5": 12}
	var body: String = text.trim_prefix(String.chr(0xFEFF))
	var line_no: int = 0
	for raw: String in body.split("\n"):
		line_no += 1
		# JS's split(/\r?\n/), then trim(): the \r goes with the space.
		var line: String = _js_trim(raw.trim_suffix("\r"))
		if line.is_empty():
			continue
		var tokens: PackedStringArray = _js_tokens(line)
		var kind: String = tokens[0]
		if not kind in ["0", "1", "2", "3", "4", "5"]:
			return {"error": "line %d does not start with an LDraw line type" % line_no}
		if kind == "0":
			var meta: String = tokens[1].to_upper() if tokens.size() > 1 else ""
			if meta == "FILE":
				var name: String = LdrModel.file_name_of(raw.trim_suffix("\r"))
				current = _file(LdrModel.section_key(raw.trim_suffix("\r"), blocks),
					name.to_lower().ends_with(".dat"))
				if not files.has(current["name"]):
					files[current["name"]] = current
					order.append(current["name"])
				in_data = false
			elif meta == "!DATA":
				in_data = true
				current = _file("", true)
			elif meta == "NOFILE":
				in_data = false
			elif meta == "!LDRAW_ORG" and part_re.search(tokens[2] if tokens.size() > 2 else "") != null:
				current["is_part"] = true
			continue
		if in_data:
			return {"error": "line %d is inside a 0 !DATA block" % line_no}
		if kind == "1":
			if tokens.size() < 15 or colour_re.search(tokens[1]) == null:
				return {"error": "line %d is not a well-formed part line" % line_no}
			for at: int in range(2, 14):
				if number_re.search(tokens[at]) == null:
					return {"error": "line %d is not a well-formed part line" % line_no}
			if not files.has(current["name"]):
				files[current["name"]] = current
				order.append(current["name"])
			(current["placed"] as Array).append(LdrModel._key(LdrModel.reference_of(raw.trim_suffix("\r"))))
			(current["colours"] as Array).append(tokens[1])
		else:
			var need: int = int(coords[kind])
			if tokens.size() != need + 2 or colour_re.search(tokens[1]) == null:
				return {"error": "line %d is not a well-formed type %s line" % [line_no, kind]}
			for at: int in range(2, tokens.size()):
				if number_re.search(tokens[at]) == null:
					return {"error": "line %d is not a well-formed type %s line" % [line_no, kind]}
	# The model is the first file that is no part; the rest are what it places.
	var main: String = ""
	var found: bool = false
	for name: String in order:
		if not bool((files[name] as Dictionary)["is_part"]):
			main = name
			found = true
			break
	var parts: int = 0
	if found:
		var tallied: Variant = _tally(main, files, {}, {})
		if tallied == null:
			return {"error": "that model places itself inside itself"}
		parts = int(tallied)
	if parts < 1:
		return {"error": "that model has no parts in it"}
	if parts > MOST_PARTS:
		return {"error": "that model has more parts than a shared model can have"}
	var needs: Array = []
	var made: Dictionary = _needs_of(main, "16", files, {})
	for lot: String in made:
		var at: int = lot.find("\n")
		needs.append([lot.substr(0, at), _colour_number(lot.substr(at + 1)), int(made[lot])])
	return {"parts": parts, "needs": needs}


static func _file(name: String, is_part: bool) -> Dictionary:
	return {"name": name, "placed": [], "colours": [], "is_part": is_part}


## JS's String.trim: the white space and line ends Unicode names, both ends.
static func _js_trim(text: String) -> String:
	var from: int = 0
	var to: int = text.length()
	while from < to and _js_space(text.unicode_at(from)):
		from += 1
	while to > from and _js_space(text.unicode_at(to - 1)):
		to -= 1
	return text.substr(from, to - from)


## A trimmed line split at runs of JS's \s.
static func _js_tokens(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var start: int = -1
	for at: int in line.length():
		if _js_space(line.unicode_at(at)):
			if start >= 0:
				out.append(line.substr(start, at - start))
				start = -1
		elif start < 0:
			start = at
	if start >= 0:
		out.append(line.substr(start))
	return out


## JS's \s: ECMAScript's white space and line terminators.
static func _js_space(c: int) -> bool:
	return c == 0x20 or (c >= 0x09 and c <= 0x0D) or c == 0xA0 or c == 0x1680 \
		or (c >= 0x2000 and c <= 0x200A) or c == 0x2028 or c == 0x2029 or c == 0x202F \
		or c == 0x205F or c == 0x3000 or c == 0xFEFF


## Whether a file's parts are all one flexible part's pieces.
static func _laid_flexible(placed: Array) -> bool:
	if placed.is_empty():
		return false
	var kinds: Dictionary = {}
	for ref: String in placed:
		var id: String = ref.trim_suffix(".dat")
		if not FLEX_PIECES.has(id):
			return false
		kinds[FLEX_PIECES[id]] = true
	return kinds.size() == 1


## checkModel's tally of [param name]'s parts through its sub-models; null
## for a model that places itself.
static func _tally(name: String, files: Dictionary, counted: Dictionary, visiting: Dictionary) -> Variant:
	if not files.has(name):
		return 1
	var file: Dictionary = files[name]
	if bool(file["is_part"]) or _laid_flexible(file["placed"]):
		return 1
	if counted.has(name):
		return counted[name]
	if visiting.has(name):
		return null
	visiting[name] = true
	var total: int = 0
	for ref: String in file["placed"]:
		var one: Variant = _tally(ref, files, counted, visiting) if files.has(ref) else 1
		if one == null:
			return null
		total += int(one)
	visiting.erase(name)
	counted[name] = total
	return total


## checkModel's needsOf: every part line the tally counts, through its
## sub-models in the colour each is placed in (16 is that colour), by
## "part\ncolour" as the file names them; a flexible part laid as segments
## is left out.
static func _needs_of(name: String, colour: String, files: Dictionary, memo: Dictionary) -> Dictionary:
	var key: String = name + "\n" + colour
	if memo.has(key):
		return memo[key]
	var file: Dictionary = files[name]
	var out: Dictionary = {}
	var placed: Array = file["placed"]
	var colours: Array = file["colours"]
	for at: int in placed.size():
		var ref: String = placed[at]
		var own: String = colours[at]
		var placed_in: String = colour if own == "16" else own
		var sub: Variant = files.get(ref)
		if sub != null and not bool((sub as Dictionary)["is_part"]):
			if _laid_flexible((sub as Dictionary)["placed"]):
				continue
			var inner: Dictionary = _needs_of(ref, placed_in, files, memo)
			for lot: String in inner:
				out[lot] = int(out.get(lot, 0)) + int(inner[lot])
		else:
			var lot: String = ref.trim_suffix(".dat") + "\n" + placed_in
			out[lot] = int(out.get(lot, 0)) + 1
	memo[key] = out
	return out


## Number(colour) of a colour as a file writes it: 4, or 0x2RRGGBB's value.
static func _colour_number(token: String) -> int:
	if token.begins_with("0x"):
		return token.substr(2).hex_to_int()
	return token.to_int()


# -- spelled as model_needs keeps it ------------------------------------------

## [param needs] ([[part, colour, qty]] as the file names them) in the one
## spelling api/_owned.js keyed gives them before they are kept: a part by
## the number it means today, a mould's letter left off, a colour by the one
## a shop files it under, a part nobody owns on its own left out, the same
## lot counted once. {"part/colour": qty}.
static func spelled_needs(needs: Array, library: PartLibrary) -> Dictionary:
	var out: Dictionary = {}
	for lot: Array in needs:
		var key: String = spelled(str(lot[0]), int(lot[1]), library)
		if key.is_empty() or int(lot[2]) < 1:
			continue
		out[key] = int(out.get(key, 0)) + int(lot[2])
	return out


## api/_owned.js spelled: "part/colour", or "" for a colour that is none or a
## part the catalogue does not know as one anybody owns.
static func spelled(raw_part: String, colour: int, library: PartLibrary) -> String:
	if colour < 0:
		return ""
	var id: String = raw_part.to_lower().trim_suffix(".dat")
	if id.is_empty() or (library != null and not _known(id, library)):
		return ""
	var part: String = _family(_resolve(id, library))
	var code: int = library.plain_code(colour) if library != null else colour
	return "%s/%d" % [part, code]


## Whether a catalogue part is one anybody owns (deriveOwnedFacts' known):
## judged by the part it means today, through at most eight moves to parts
## the catalogue has (ownable).
static func _known(id: String, library: PartLibrary) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(id)
	# A part made here or carried in by a file (PartLibrary.custom) is in the
	# app's library only, never in the catalogue the site counts by.
	if info == null or library.custom.has(id):
		return false
	var today: PartLibrary.PartInfo = info
	for _hop: int in 8:
		if today.moved_to.is_empty() or not library.parts.has(today.moved_to):
			break
		today = library.parts[today.moved_to]
	if today.category == "Sticker" or today.kind.contains("Flexible_Section"):
		return false
	return not today.name.begins_with("~") or not today.moved_to.is_empty() \
		or today.name.contains("(Obsolete)")


## resolvePart: through LDraw's moves, at most eight, and only to a part
## anybody owns.
static func _resolve(id: String, library: PartLibrary) -> String:
	var at: String = id.to_lower()
	if library == null:
		return at
	for _hop: int in 8:
		var info: PartLibrary.PartInfo = library.parts.get(at)
		var to: String = info.moved_to if info != null else ""
		if to.is_empty() or not _known(to, library):
			return at
		at = to
	return at


static var _mould: RegEx = RegEx.create_from_string(_MOULD)


static func _family(part: String) -> String:
	var found: RegExMatch = _mould.search(part)
	return found.get_string(1) if found != null else part


# -- the check, as challenge_check answers ----------------------------------

## What [param rules] ([method rules_in]'s) say of a model of [param facts]
## ([method facts_of]), and of its Tested finding [param tested] (true
## passed, false failed, null not known): challenge_check's answer, key for
## key, a rule the challenge does not have left out. {"ok", "parts": {most,
## has, ok}, "set": {number, name, counted, ok, short_lots, short: [{part,
## colour, need, have}], the most missing first, at most twelve}, "tested":
## {ok}}. A Tested not known is not ok, as the site's would not be.
static func check(rules: Dictionary, facts: Dictionary, tested: Variant) -> Dictionary:
	var out: Dictionary = {}
	var ok: bool = true
	var most: int = int(rules.get("most_parts", 0))
	if most > 0:
		var has: int = int(facts.get("parts", 0))
		out["parts"] = {"most": most, "has": has, "ok": has <= most}
		ok = ok and has <= most
	var set_rule: Dictionary = rules.get("set", {})
	if not set_rule.is_empty():
		var lots: Dictionary = set_rule["lots"]
		var needs: Dictionary = facts.get("needs", {})
		var short: Array = []
		for key: String in needs:
			var have: int = int(lots.get(key, 0))
			if have < int(needs[key]):
				var at: int = key.rfind("/")
				short.append({"part": key.substr(0, at), "colour": key.substr(at + 1).to_int(),
					"need": int(needs[key]), "have": have})
		short.sort_custom(_more_short)
		out["set"] = {"number": set_rule["number"], "name": set_rule.get("name", ""), "counted": true,
			"ok": short.is_empty(), "short_lots": short.size(), "short": short.slice(0, MOST_SHORT)}
		ok = ok and short.is_empty()
	if bool(rules.get("tested", false)):
		out["tested"] = {"ok": tested == true}
		ok = ok and tested == true
	out["ok"] = ok
	return out


## The most missing first, then by part and colour, as challenge_check orders.
static func _more_short(a: Dictionary, b: Dictionary) -> bool:
	var gap_a: int = int(a["need"]) - int(a["have"])
	var gap_b: int = int(b["need"]) - int(b["have"])
	if gap_a != gap_b:
		return gap_a > gap_b
	if a["part"] != b["part"]:
		return str(a["part"]) < str(b["part"])
	return int(a["colour"]) < int(b["colour"])


# -- said, as the person can act on it ----------------------------------------

## Each rule of [param challenge] as the studio's line lists it, for the
## model's [param checked] ([method check], {} before the first) and its
## Tested [param tested] (null not known; or the finding's tests,
## {name: {ok, why}}): [{rule, state ("ok", "no", "unknown"), words, fix}],
## [param library] naming a short lot's part and colour.
static func rows(challenge: Dictionary, checked: Dictionary, tested: Variant,
		library: PartLibrary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if challenge.is_empty():
		return out
	var rules: Dictionary = challenge["rules"]
	var most: int = int(rules["most_parts"])
	if most > 0:
		var said: Dictionary = checked.get("parts", {})
		if said.is_empty():
			out.append({"rule": "parts", "state": "unknown", "fix": "",
				"words": "At most %s parts" % Working.comma(most)})
		else:
			var has: int = int(said["has"])
			out.append({"rule": "parts", "state": "ok" if bool(said["ok"]) else "no",
				"words": "%s of %s parts" % [Working.comma(has), Working.comma(most)],
				"fix": "" if bool(said["ok"]) else ("Take %s away: it has %s, and the most is %s."
					% [_parts_words(has - most), Working.comma(has), Working.comma(most)])})
	var set_rule: Dictionary = rules["set"]
	if not set_rule.is_empty():
		var name: String = str(set_rule.get("name", ""))
		var number: String = str(set_rule["number"]).trim_suffix("-1")
		var words: String = ("Only parts from set %s, %s" % [number, name]) if not name.is_empty() \
			else ("Only parts from set %s" % number)
		var said: Dictionary = checked.get("set", {})
		if said.is_empty():
			out.append({"rule": "set", "state": "unknown", "words": words, "fix": ""})
		elif bool(said["ok"]):
			out.append({"rule": "set", "state": "ok", "words": words, "fix": ""})
		else:
			out.append({"rule": "set", "state": "no", "words": words,
				"fix": short_words(said["short"], int(said["short_lots"]), library)})
	if bool(rules["tested"]):
		if tested is Dictionary:
			var failed: PackedStringArray = PackedStringArray()
			for test: String in ["stands", "steps", "parts", "whole"]:
				var one: Variant = (tested as Dictionary).get(test)
				if not one is Dictionary or not bool((one as Dictionary).get("ok", false)):
					var why: String = str((one as Dictionary).get("why", "")) if one is Dictionary else ""
					failed.append("%s: %s" % [TESTED_FAILED[test], why] if not why.is_empty() else TESTED_FAILED[test])
			out.append({"rule": "tested", "state": "ok" if failed.is_empty() else "no",
				"words": "Tested: stands at every step, nothing loose" if failed.is_empty() else "Tested",
				"fix": ". ".join(failed).strip_edges() + ("." if not failed.is_empty() else "")})
		else:
			out.append({"rule": "tested", "state": "unknown", "words": "Tested",
				"fix": "Not tested yet: a publish tests it, or test it now."})
	return out


## What each of the four tests is called when it fails (api/_tested.js FAILED).
const TESTED_FAILED: Dictionary = {
	"stands": "Not shown to stand at every step",
	"steps": "Not every step shown reachable",
	"parts": "A part is not made in its colour",
	"whole": "It does not go together",
}


## "1 part", "12 parts".
static func _parts_words(count: int) -> String:
	return "1 part" if count == 1 else "%s parts" % Working.comma(count)


## What the set rule's short lots say to change: the first three named, as
## "2 more Red Brick 1 x 2 (3004) than the set has", and how many more.
static func short_words(short: Array, lots: int, library: PartLibrary) -> String:
	var named := PackedStringArray()
	for one: Variant in short.slice(0, 3):
		var lot: Dictionary = one
		var over: int = int(lot["need"]) - int(lot["have"])
		var what: String = lot_name(str(lot["part"]), int(lot["colour"]), library)
		named.append(("%d %s, which the set has none of" % [over, what]) if int(lot["have"]) == 0
			else ("%d more %s than the set has" % [over, what]))
	var more: int = lots - named.size()
	# Each said whole, so each language words it its own way (locale/*.po).
	if more <= 0:
		return "Swap or take away %s." % "; ".join(named)
	if more == 1:
		return "Swap or take away %s, and 1 lot more." % "; ".join(named)
	return "Swap or take away %s, and %d lots more." % ["; ".join(named), more]


## A lot as a person reads it: "Red Brick 1 x 2 (3004)".
static func lot_name(part: String, colour: int, library: PartLibrary) -> String:
	var name: String = part
	var colour_name: String = "colour %d" % colour
	if library != null:
		var info: PartLibrary.PartInfo = library.parts.get(part)
		if info != null:
			name = " ".join(info.name.lstrip("~=_ ").split(" ", false))
		var found: Variant = library.colors.get(colour)
		if found != null:
			colour_name = str(found.name).replace("_", " ")
	return "%s %s (%s)" % [colour_name, name, part]
