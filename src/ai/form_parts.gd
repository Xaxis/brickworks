## What real sets build a form with: a curve in profile or in plan, an arch,
## a taper, a flare, a lean, a turn off the grid, a twist, an open frame, a
## slender rod, at each size and in each theme.
##
## design24 asked each feature's form before the first build and won head to
## head twice, then lost the proof on its surface: the forms were laid in
## plates stepped in, where the sets turn them with curved slopes, wedges,
## SNOT and hinges (docs/DESIGN_SCORES.md). tools/form_parts.py reads the
## snippets index by each piece's own geometry and parts, not its name, and
## writes assets/knowledge/form_parts.json.gz: for each form x size x theme,
## how many pieces of which sets, the parts that make the form there (ranked
## by how many of its pieces use them, lifted over how common they are
## anywhere) and the share of its pieces using each technique.
##
## The feature pass's close look (Assistant._form_brief) reads a feature's
## form in the design's own words (forms_in), finds its cell (cell) and lays
## the form's parts where the feature's plates step (SurfacePass.form_finish).
##
## Every set of the bench's two halves is held out when the table is made,
## and said() names no set DesignMemory holds (src/dev/form_parts_probe.gd).
##
## The desktop reads the table from its own files; the web build fetches it
## from beside the build (knowledge/, tools/export.sh) the first time a form
## is looked at, as RealSnippets does.
class_name FormParts
extends RefCounted

const TABLE := "res://assets/knowledge/form_parts.json.gz"
## A cell's theme row is used when it has this many pieces; else "any".
const LEAST := 4
## Sizes by longest side in studs, as the table has them.
const SMALL := 4.0
const MEDIUM := 10.0
## The roles whose parts round a profile, and taper or straighten one, as the
## close look lays them on a feature's treads and edges.
const CURVING: Array = ["curved_slope", "dome"]
const STRAIGHT: Array = ["slope", "wedge"]
const SIDEWAYS: Array = ["snot"]

static var _table: Dictionary = {}
static var _tried: bool = false
static var _fetching: bool = false


## The table, read from this build's own files the first time anything asks.
static func table() -> Dictionary:
	if not _tried and (not OS.has_feature("web") or FileAccess.file_exists(TABLE)):
		_tried = true
		_table = RealSnippets.read(TABLE)
	return _table


## The table, wherever this build keeps it. True when there is one. Awaited.
static func ensure(host: Node) -> bool:
	if not _tried and OS.has_feature("web") and not FileAccess.file_exists(TABLE):
		while _fetching:
			await host.get_tree().process_frame
		if not _tried:
			_fetching = true
			_table = RealSnippets.parse(await RealSnippets.fetch(host, TABLE.get_file()))
			_tried = true
			_fetching = false
	return available()


static func available() -> bool:
	return not table().get("forms", {}).is_empty()


## The forms a feature's own words name, the first named first: "curved: a
## dome of curved slopes over a round drum" is curved, then round. The words
## are the table's own (tools/form_parts.py FORMS). A form said before a
## colon, as submit_design asks it ("open: a ring of 1x1 round columns round
## the drum"), is the form, and the parts after it are not: read whole, that
## peristyle was round and arched as well, and an attic "set back above the
## overhanging cornice" flared (design24's first builds, replayed).
static func forms_in(text: String) -> PackedStringArray:
	var head: String = text.get_slice(":", 0) if text.contains(":") else ""
	if not head.is_empty():
		var said: PackedStringArray = _forms_named(head)
		if not said.is_empty():
			return said
	return _forms_named(text)


static func _forms_named(text: String) -> PackedStringArray:
	var low: String = " "
	for ch: String in text.to_lower():
		low += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-" else " "
	low += " "
	var found: Array = []
	var forms: Dictionary = table().get("forms", {})
	for form: String in forms:
		var at: int = -1
		for word: Variant in (forms[form] as Dictionary).get("words", []):
			var where: int = low.find(" %s " % str(word))
			if where >= 0 and (at < 0 or where < at):
				at = where
		if at >= 0:
			found.append([at, form])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := PackedStringArray()
	for row: Array in found:
		out.append(str(row[1]))
	return out


## The table's size word for a longest side in studs.
static func size_of(studs: float) -> String:
	if studs <= SMALL + 0.01:
		return "small"
	if studs <= MEDIUM + 0.01:
		return "medium"
	return "large"


## The theme a request names, as the table has its themes (a set's top
## theme: "Architecture", "Technic", "Creator"), longest first; "" for none.
static func theme_in(text: String) -> String:
	var low: String = text.to_lower()
	var themes: Dictionary = {}
	for form: Variant in table().get("forms", {}).values():
		for size: Variant in (form as Dictionary).get("sizes", {}).values():
			for theme: String in (size as Dictionary):
				if theme != "any":
					themes[theme] = true
	var names: Array = themes.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for theme: String in names:
		if low.contains(theme.to_lower()):
			return theme
	return ""


## One form's cell for a feature [param studs] long in [param theme]: the
## theme's own row when it has LEAST pieces, else every theme's; at its own
## size, else the nearest size the form has. With "form", "size" and
## "theme" said in it; {} when the table has no such form.
static func cell(form: String, studs: float, theme: String = "") -> Dictionary:
	var body: Dictionary = table().get("forms", {}).get(form, {})
	var sizes: Dictionary = body.get("sizes", {})
	if sizes.is_empty():
		return {}
	var want: String = size_of(studs)
	var order: Array = {"small": ["small", "medium", "large"],
		"medium": ["medium", "small", "large"], "large": ["large", "medium", "small"]}[want]
	for size: String in order:
		var themed: Dictionary = sizes.get(size, {})
		var row: Dictionary = {}
		var from: String = ""
		if not theme.is_empty() and themed.has(theme) \
				and int((themed[theme] as Dictionary).get("entries", 0)) >= LEAST:
			row = themed[theme]
			from = theme
		elif themed.has("any"):
			row = themed["any"]
			from = "any"
		if row.is_empty():
			continue
		var out: Dictionary = row.duplicate(true)
		out["form"] = form
		out["size"] = size
		out["theme"] = from
		out["said"] = str(body.get("said", form))
		return out
	return {}


## The part ids of a cell whose role is one of [param roles], in the cell's
## order: what the sets used most for the form, first.
static func parts_of(one: Dictionary, roles: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for row: Variant in one.get("parts", []):
		var listed: Array = row
		if roles.has(str(listed[2])):
			out.append(str(listed[0]))
	return out


## A part's name as the table has it.
static func name_of(part: String) -> String:
	return str(table().get("names", {}).get(part, part))


## A cell in words, for the close look: what real sets build the form with at
## this size, the parts with how many of the pieces used each, the technique,
## and the sets it is read from (none the bench holds out).
static func said(one: Dictionary, most: int = 6) -> String:
	if one.is_empty():
		return ""
	var parts := PackedStringArray()
	for row: Variant in (one.get("parts", []) as Array).slice(0, most):
		var listed: Array = row
		parts.append("%s %s (%d%%)" % [str(listed[0]), name_of(str(listed[0])),
			roundi(100.0 * float(listed[1]))])
	var ways := PackedStringArray()
	var names: Dictionary = table().get("techniques", {})
	var technique: Dictionary = one.get("technique", {})
	for key: String in technique:
		if ways.size() >= 3:
			break
		if key == "tiles":
			continue
		ways.append("%s in %d%%" % [str(names.get(key, key)), roundi(100.0 * float(technique[key]))])
	var sets := PackedStringArray()
	for row: Variant in one.get("sets", []):
		var listed: Array = row
		if DesignMemory.holds(str(listed[0]), str(listed[1])):
			continue
		if sets.size() < 3:
			sets.append("%s %s" % [str(listed[0]), str(listed[1])])
	var theme: String = str(one.get("theme", "any"))
	return ("Real %ssets build %s at this size (%s) with %s; their technique: %s. Read from %d "
		% ["" if theme == "any" else theme + " ", str(one.get("said", one.get("form", ""))),
			str(one.get("size", "")), ", ".join(parts) if not parts.is_empty() else "no part "
			+ "above the rest", ", ".join(ways) if not ways.is_empty() else "plain bricks",
			int(one.get("entries", 0))]
		+ "pieces of %d sets, %s among them." % [int(one.get("set_count", 0)), ", ".join(sets)])
