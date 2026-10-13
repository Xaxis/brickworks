## The gallery, for a session: what people built and shared at
## brickworks.diy/gallery, searched, and one of them opened as a reference.
##
## Read-only. Nothing on the baseplate changes and nothing is published:
## a session asks what is there (api/share.js ?op=list, the gallery's own
## question) and reads one model (?id=, the viewer's own request), and is
## told about it compactly — what it is, its size, its parts by kind, its
## credit and its licence, and its small picture — so it can learn how
## somebody built a thing before it builds its own. Whose it is and what
## they allow is in every answer, because whatever a session makes from it
## is its builder's work too.
##
## A tool of AppTools (gallery), served wherever the app's tools are: the
## desktop's MCP port, My Claude and the connector.
class_name GalleryTool
extends RefCounted

const SIZES: Array[String] = ["small", "medium", "large"]
const SORTS: Array[String] = ["newest", "views", "likes", "remixes"]
## How much of a model is read: the server's own limit (api/share.js).
const MOST_MODEL := 3 * 1024 * 1024
const MOST_PICTURE := 128 * 1024
## What each licence lets a session do with what it learns, said to it.
const LICENCES: Dictionary = {
	"cc-by-4.0": ["CC BY 4.0", "anyone may share it, change it and build on it, crediting %s and linking %s"],
	"cc-by-sa-4.0": ["CC BY-SA 4.0", "anyone may build on it, crediting %s and linking %s, and must share what they make under CC BY-SA 4.0 too"],
	"all-rights-reserved": ["All rights reserved", "learn from how %s built it; do not copy it into a model you make or share without their leave (%s)"],
}

var app: Node


static func definition() -> Dictionary:
	return {
		"name": "gallery",
		"description": ("Search brickworks.diy/gallery, the models people built in Brickworks and "
			+ "shared, and open one as a reference. With no open: a page of models matching q "
			+ "(words of a name, a builder, a tag or a description), kind, size, technic, "
			+ "instructions, sorted by sort; each with its link id, part count, credit and licence. "
			+ "open=<id>: one model compactly — what it is, its size, its sub-assemblies and steps, "
			+ "its parts by kind and the most used, its credit and its licence, and its picture — "
			+ "to learn how it is built. Read-only: nothing on the baseplate changes. Credit its "
			+ "builder and keep to its licence in anything made from it."),
		"input_schema": {"type": "object", "additionalProperties": false, "properties": {
			"q": {"type": "string", "description": "words to look for, up to 100 characters"},
			"kind": {"type": "string", "enum": Array(ModelKinds.ids())},
			"size": {"type": "string", "enum": SIZES},
			"technic": {"type": "boolean", "description": "only Technic models and mechanisms"},
			"instructions": {"type": "boolean", "description": "only models with their builder's own steps"},
			"sort": {"type": "string", "enum": SORTS},
			"page": {"type": "integer", "description": "1 when omitted"},
			"open": {"type": "string", "description": "a model's link id, from a search, to read it"},
			"picture": {"type": "boolean", "description": "with open: its picture too; true when omitted"},
		}},
	}


## The tool's answer: text, or text and a picture.
func run(input: Dictionary) -> Variant:
	var opened: String = str(input.get("open", "")).strip_edges()
	if not opened.is_empty():
		return await _open(opened, bool(input.get("picture", true)))
	return await _search(input)


func _search(input: Dictionary) -> String:
	var asked := PackedStringArray(["op=list"])
	var said := PackedStringArray()
	var words: String = str(input.get("q", "")).strip_edges().left(100)
	if not words.is_empty():
		asked.append("q=" + words.uri_encode())
		said.append("\"%s\"" % words)
	var kind: String = str(input.get("kind", ""))
	if not kind.is_empty():
		if not ModelKinds.ids().has(kind):
			return "kind is one of %s." % ", ".join(ModelKinds.ids())
		asked.append("kind=" + kind)
		said.append(ModelKinds.label(kind).to_lower())
	var size: String = str(input.get("size", ""))
	if not size.is_empty():
		if not SIZES.has(size):
			return "size is small, medium or large."
		asked.append("size=" + size)
		said.append(size)
	if bool(input.get("technic", false)):
		asked.append("technic=1")
		said.append("Technic or a mechanism")
	if bool(input.get("instructions", false)):
		asked.append("instructions=1")
		said.append("with their builder's own steps")
	var sort: String = str(input.get("sort", "newest"))
	if not SORTS.has(sort):
		return "sort is newest, views, likes or remixes."
	asked.append("sort=" + sort)
	var page: int = maxi(1, int(input.get("page", 1)))
	asked.append("page=%d" % page)
	var answer: Dictionary = await _ask("/api/share?" + "&".join(asked), 256 * 1024)
	var body: Variant = _json(answer)
	if int(answer["code"]) != 200 or not body is Dictionary:
		return _trouble(answer, body)
	var models: Array = (body as Dictionary).get("models", [])
	var heading: String = "The gallery at %s%s, %s, page %d" % [Deployment.api_base(),
		"" if said.is_empty() else " (" + ", ".join(said) + ")",
		{"newest": "newest first", "views": "most viewed first", "likes": "most liked first",
			"remixes": "most remixed first"}[sort], page]
	if models.is_empty():
		return "%s: nothing%s." % [heading, " matches" if not said.is_empty() else " is listed"]
	var lines := PackedStringArray(["%s:" % heading])
	var number: int = (page - 1) * 24
	for one: Variant in models:
		if not one is Dictionary:
			continue
		var model: Dictionary = one
		number += 1
		var facts := PackedStringArray(["%s parts" % _count(int(model.get("parts", 0)))])
		if model.get("author") is String:
			facts[0] += ", by %s" % model["author"]
		if model.get("kind") is String:
			facts.append(str(model["kind"]))
		facts.append(_licence_name(model.get("licence")))
		facts.append("%d views, %d likes, %d remixes" % [int(model.get("views", 0)),
			int(model.get("likes", 0)), int(model.get("remixes", 0))])
		if bool(model.get("own_steps", false)):
			facts.append("its builder's own steps")
		if bool(model.get("technic", false)):
			facts.append("Technic")
		lines.append("%d. %s (%s) — %s" % [number, model.get("name", "?"), model.get("id", "?"),
			" · ".join(facts)])
	if bool((body as Dictionary).get("more", false)):
		lines.append("More: page=%d." % (page + 1))
	lines.append("gallery open=<id> reads one as a reference. What you make from it is its builder's "
		+ "work too: credit them, and keep to its licence.")
	return "\n".join(lines)


func _open(id: String, with_picture: bool) -> Variant:
	if not SharedModels.is_id(id):
		return "open is a model's link id: ten letters and digits, from a search."
	var answer: Dictionary = await _ask("/api/share?id=" + id, MOST_MODEL)
	var body: Variant = _json(answer)
	if int(answer["code"]) == 410 or int(answer["code"]) == 404:
		return "%s is not shared any more, or never was." % id
	if int(answer["code"]) != 200 or not body is Dictionary:
		return _trouble(answer, body)
	var shared: Dictionary = body
	var url: String = str(shared.get("url", "%s/m/%s" % [Deployment.api_base(), id]))
	var author: String = str(shared["author"]) if shared.get("author") is String else ""
	var credit: String = author if not author.is_empty() else "its builder"
	var lines := PackedStringArray()
	lines.append("%s (%s)%s — %s parts." % [shared.get("name", "?"), url,
		", by %s" % author if not author.is_empty() else "", _count(int(shared.get("parts", 0)))])
	if shared.get("description") is String:
		lines.append("About it: %s" % str(shared["description"]).replace("\n", " ").left(500))
	var tags: Array = shared.get("tags", []) if shared.get("tags") is Array else []
	if not tags.is_empty() or shared.get("kind") is String:
		lines.append("Kind: %s%s" % [ModelKinds.label(str(shared.get("kind", ""))) if shared.get("kind") is String
			else "not said", "; tags: %s" % ", ".join(PackedStringArray(tags)) if not tags.is_empty() else ""])
	var licence: Variant = shared.get("licence")
	if licence is String and LICENCES.has(licence):
		lines.append("Licence: %s — %s." % [LICENCES[licence][0], LICENCES[licence][1] % [credit, url]])
	else:
		lines.append("Licence: none chosen — learn from it; do not copy it into what you make or share.")
	if shared.get("remixed_from") is Dictionary:
		lines.append("Remixed from %s (%s)." % [(shared["remixed_from"] as Dictionary).get("name", "?"),
			(shared["remixed_from"] as Dictionary).get("url", "")])
	lines.append_array(_reading(str(shared.get("model", ""))))
	lines.append("Read-only: nothing on the baseplate changed. Build your own; to start from this "
		+ "one instead, the person presses Open in Brickworks on its page.")
	var text: String = "\n".join(lines)
	if not with_picture:
		return text
	var picture: Dictionary = await _ask("/m/%s.webp" % id, MOST_PICTURE)
	var kind: String = "image/webp"
	if int(picture["code"]) != 200:
		picture = await _ask("/m/%s.png" % id, 700 * 1024)
		kind = "image/png"
	if int(picture["code"]) != 200 or (picture["bytes"] as PackedByteArray).is_empty():
		return text + "\nIt has no picture."
	return [{"type": "text", "text": text}, {"type": "image", "source": {"type": "base64",
		"media_type": kind, "data": Marshalls.raw_to_base64(picture["bytes"])}}]


## What a model's file says about how it is built: its size, its
## sub-assemblies and steps, its parts by kind and the most used.
func _reading(text: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var library: PartLibrary = app.get("_library") if app != null else null
	var parsed: LdrModel = LdrModel.parse(text, "shared")
	if parsed == null or parsed.main == null:
		return lines
	var known: Dictionary = library.parts if library != null else {}
	var placed: Array[LdrModel.Placement] = parsed.flatten(known)
	var assemblies: int = maxi(0, parsed.submodels.size() - 1)
	lines.append("%d sub-assemblies, %d steps." % [assemblies, parsed.main.step_count])
	var box := AABB()
	var first: bool = true
	var by_kind: Dictionary = {}
	var by_part: Dictionary = {}
	for one: LdrModel.Placement in placed:
		var info: PartLibrary.PartInfo = known.get(one.part_id) as PartLibrary.PartInfo
		var local: AABB = info.bounds if info != null else AABB(Vector3(-10, -24, -10), Vector3(20, 24, 20))
		var moved: AABB = one.transform * local
		box = moved if first else box.merge(moved)
		first = false
		var kind: String = info.category if info != null and not info.category.is_empty() else "made in the app"
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var key: String = "%s|%d" % [one.part_id, one.color_code]
		by_part[key] = int(by_part.get(key, 0)) + 1
	if not first:
		lines.append("Size: %d x %d studs, %s bricks tall." % [roundi(box.size.x / 20.0),
			roundi(box.size.z / 20.0), String.num(box.size.y / 24.0, 1)])
	var kinds: Array = by_kind.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(by_kind[a]) > int(by_kind[b]))
	var said := PackedStringArray()
	for kind: String in kinds.slice(0, 8):
		said.append("%s %s" % [kind, _count(int(by_kind[kind]))])
	if not said.is_empty():
		lines.append("Its parts by kind: %s." % ", ".join(said))
	var parts: Array = by_part.keys()
	parts.sort_custom(func(a: String, b: String) -> bool: return int(by_part[a]) > int(by_part[b]))
	said = PackedStringArray()
	for key: String in parts.slice(0, 10):
		var id: String = key.get_slice("|", 0)
		var code: int = int(key.get_slice("|", 1))
		var info: PartLibrary.PartInfo = known.get(id) as PartLibrary.PartInfo
		var colour: Variant = library.colors.get(code) if library != null else null
		said.append("%d x %s %s, %s" % [int(by_part[key]), id,
			Inventory._tidy(info.name) if info != null else "(made in the app)",
			(colour as PartLibrary.BrickColor).name if colour is PartLibrary.BrickColor else "colour %d" % code])
	if not said.is_empty():
		lines.append("The most used: %s." % "; ".join(said))
	return lines


static func _licence_name(licence: Variant) -> String:
	return str(LICENCES[licence][0]) if licence is String and LICENCES.has(licence) else "no licence chosen"


static func _count(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out


static func _json(answer: Dictionary) -> Variant:
	var json := JSON.new()
	var bytes: PackedByteArray = answer["bytes"]
	return json.data if json.parse(bytes.get_string_from_utf8()) == OK else null


static func _trouble(answer: Dictionary, body: Variant) -> String:
	if body is Dictionary and str((body as Dictionary).get("error", "")) != "":
		return "The gallery said: %s." % str((body as Dictionary)["error"])
	if int(answer["code"]) == 0:
		return "Could not reach the gallery at %s just now." % Deployment.api_base()
	return "The gallery answered %d." % int(answer["code"])


## One request to this app's own deployment (Deployment.api_base), never
## anywhere a session names: {code, bytes}.
func _ask(path: String, most: int) -> Dictionary:
	var request := HTTPRequest.new()
	request.body_size_limit = most
	request.timeout = 60.0
	app.add_child(request)
	if request.request(Deployment.api_base() + path, ["Accept: application/json"]) != OK:
		request.queue_free()
		return {"code": 0, "bytes": PackedByteArray()}
	var got: Array = await request.request_completed
	request.queue_free()
	if int(got[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "bytes": PackedByteArray()}
	return {"code": int(got[1]), "bytes": got[3] as PackedByteArray}
