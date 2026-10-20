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
## The gallery's front too (2026-10-19): this week's pick and the small
## builds' shelf, and, for a person signed in with a collection, what they
## can build now; and the sorts the gallery has, Top builds and Most built,
## and Parts I own for that person. Each model says what moves in it, as its
## app found from its joints ("moves: steering, boom"), which its link lets
## anybody take hold of and move, and its own motions by name ("motions:
## "Open the dome", "Extend the telescope"", docs/MOTIONS.md), which its link
## plays by a button each, and play_motion plays once it is opened.
##
## A tool of AppTools (gallery), served wherever the app's tools are: the
## desktop's MCP port, My Claude and the connector.
class_name GalleryTool
extends RefCounted

const SIZES: Array[String] = ["small", "medium", "large"]
const SORTS: Array[String] = ["newest", "views", "likes", "remixes", "builds", "top", "owned"]
## Each sort as a heading says it.
const SORT_WORDS: Dictionary = {"newest": "newest first", "views": "most viewed first",
	"likes": "most liked first", "remixes": "most remixed first", "builds": "most built first",
	"top": "Top builds first (a build finished counts 3, a remix 2, the Tested mark 5)",
	"owned": "the largest share of its parts you own first"}
## How much of a model is read: the server's own limit (api/share.js).
const MOST_MODEL := 3 * 1024 * 1024
const MOST_PICTURE := 128 * 1024
## What each licence lets a session do with what it learns, said to it.
const LICENCES: Dictionary = {
	"cc-by-4.0": ["CC BY 4.0", "anyone may share it, change it and build on it, crediting %s and linking %s"],
	"cc-by-sa-4.0": ["CC BY-SA 4.0", "anyone may build on it, crediting %s and linking %s, and must share what they make under CC BY-SA 4.0 too"],
	"all-rights-reserved": ["All rights reserved", "learn from how %s built it; do not copy it into a model you make or share without their leave (%s)"],
}

## A designer's handle, as api/people.js takes one.
const HANDLE := "^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$"
## What a session says of following, liking and commenting: the person's
## own, on the site, signed in. A session asked to follow somebody guessed
## where the button might be.
const FOLLOWING := ("Following, liking and commenting are the person's own: Follow is on the "
	+ "designer's page, %s, signed in to Brickworks. A session reads; it does not do these for them.")

var app: Node


static func definition() -> Dictionary:
	return {
		"name": "gallery",
		"description": ("Search brickworks.diy/gallery, the models people built in Brickworks and "
			+ "shared, and open one as a reference. With no open: a page of models matching q "
			+ "(words of a name, a builder, a tag or a description), kind, size, technic, "
			+ "instructions, sorted by sort (top: Top builds; owned: Parts I own, signed in with a "
			+ "collection); each with its link id, part count, credit, licence, how many built it and "
			+ "what moves in it (steering, a boom: anybody can move them on its link) and its own "
			+ "motions by name (open_model link= opens a copy, and play_motion plays them). shelves=true: "
			+ "the gallery's front, this week's pick and the small builds, and what the person can "
			+ "build now from their collection. "
			+ "open=<id>: one model compactly — what it is, its size, its sub-assemblies and steps, "
			+ "its parts by kind and the most used, its credit and its licence, how many built it, "
			+ "its comments and photos of real builds, and its picture — to learn how it is built. "
			+ "designer=<handle> (a list's \"by Name (@handle)\"): a designer's page, what their "
			+ "models earned and their models. Read-only: nothing on the baseplate changes, and "
			+ "liking, following and commenting are the person's own, on the site. Credit its "
			+ "builder and keep to its licence in anything made from it."),
		"input_schema": {"type": "object", "additionalProperties": false, "properties": {
			"q": {"type": "string", "description": "words to look for, up to 100 characters"},
			"kind": {"type": "string", "enum": Array(ModelKinds.ids())},
			"size": {"type": "string", "enum": SIZES},
			"technic": {"type": "boolean", "description": "only Technic models and mechanisms"},
			"instructions": {"type": "boolean", "description": "only models with their builder's own steps"},
			"sort": {"type": "string", "enum": SORTS, "description": "newest when omitted; owned only for "
				+ "a person signed in with a collection"},
			"shelves": {"type": "boolean", "description": "the gallery's front: this week's pick, the small "
				+ "builds, and what the person can build now"},
			"page": {"type": "integer", "description": "1 when omitted"},
			"open": {"type": "string", "description": "a model's link id, from a search, to read it"},
			"designer": {"type": "string", "description": "a designer's handle, from a list's \"by Name (@handle)\""},
			"picture": {"type": "boolean", "description": "with open: its picture too; true when omitted"},
		}},
	}


## The tool's answer: text, or text and a picture.
func run(input: Dictionary) -> Variant:
	var opened: String = str(input.get("open", "")).strip_edges()
	if not opened.is_empty():
		return await _open(opened, bool(input.get("picture", true)))
	if not str(input.get("designer", "")).strip_edges().is_empty():
		return await _designer(str(input["designer"]).strip_edges().trim_prefix("@").to_lower())
	if bool(input.get("shelves", false)):
		return await _shelves()
	return await _search(input)


## The person's session for the gallery's own question about them (mine=1):
## their share of each model's parts. "" when nobody is signed in.
func _token() -> String:
	var account: Account = app.get("_account") as Account if app != null else null
	if account == null or not account.signed_in():
		return ""
	return await account.access_token()


## The gallery's front: this week's pick, the small builds, and with a
## collection what the person can build now (api/share.js ?op=shelves).
func _shelves() -> String:
	var token: String = await _token()
	var answer: Dictionary = await _ask("/api/share?op=shelves" + ("&mine=1" if not token.is_empty() else ""),
		256 * 1024, token)
	var body: Variant = _json(answer)
	if int(answer["code"]) != 200 or not body is Dictionary:
		return _trouble(answer, body)
	var front: Dictionary = body
	var lines := PackedStringArray(["The gallery's front at %s:" % Deployment.api_base()])
	var pick: Variant = front.get("pick")
	if pick is Dictionary and (pick as Dictionary).get("model") is Dictionary:
		var picked: Dictionary = pick
		var week: Dictionary = picked["week"] if picked.get("week") is Dictionary else {}
		var why := PackedStringArray()
		if bool(picked.get("chosen", false)):
			why.append("chosen by Brickworks")
		if int(week.get("builds", 0)) > 0:
			why.append("built %s this week" % _times(int(week["builds"])))
		if int(week.get("remixes", 0)) > 0:
			why.append("remixed %s this week" % _times(int(week["remixes"])))
		lines.append("This week's pick%s: %s" % [" (" + ", ".join(why) + ")" if not why.is_empty() else "",
			_line(picked["model"])])
	else:
		lines.append("This week's pick: none this week.")
	var small: Dictionary = front["small"] if front.get("small") is Dictionary else {}
	var shelf: Array = small["models"] if small.get("models") is Array else []
	lines.append("Small builds (%s), Top builds first:%s" % [str(small.get("label", "under 200 parts")),
		"" if not shelf.is_empty() else " none yet."])
	for one: Variant in shelf:
		if one is Dictionary:
			lines.append("- " + _line(one))
	if front.get("ready") is Dictionary:
		var ready: Array = (front["ready"] as Dictionary).get("models", [])
		lines.append("You can build now, every piece in your collection:%s" % ("" if not ready.is_empty()
			else " nothing yet."))
		for one: Variant in ready:
			if one is Dictionary:
				lines.append("- " + _line(one))
	elif token.is_empty():
		lines.append("Signed in with a collection, the person is told what they can build now.")
	lines.append("gallery open=<id> reads one as a reference; sort=top lists the gallery by Top builds.")
	return "\n".join(lines)


## A designer's page as anyone sees it (api/people.js ?op=profile): who they
## are, what their models earned, and their models by Top builds. Asked who
## made a model and what else they made, a session could only search the
## builder's name, and could say nothing of their page or how to follow
## them (bench/results/mcpwalk2-2026-10-19, t5).
func _designer(handle: String) -> String:
	if RegEx.create_from_string(HANDLE).search(handle) == null:
		return ("designer is a designer's handle, as a list gives it after their name: "
			+ "\"by Name (@handle)\". A model with no handle has no designer's page.")
	var answer: Dictionary = await _ask("/api/people?op=profile&handle=" + handle, 256 * 1024)
	var body: Variant = _json(answer)
	if int(answer["code"]) == 404:
		return "Nobody has the handle @%s." % handle
	if int(answer["code"]) != 200 or not body is Dictionary:
		return _trouble(answer, body)
	var person: Dictionary = body
	var url: String = str(person.get("url", "%s/u/%s" % [Deployment.api_base(), handle]))
	var lines := PackedStringArray(["%s (@%s, %s)%s" % [person.get("name", handle), handle, url,
		": " + str(person["bio"]).replace("\n", " ").left(300) if person.get("bio") is String
			and not str(person["bio"]).is_empty() else ""]])
	if person.get("designer") is Dictionary:
		var earned: Dictionary = person["designer"]
		lines.append("What their models earned: %s models, %s, %s remixes, %s Tested, %s comments, "
			% [_count(int(earned.get("models", 0))), _built(int(earned.get("builds", 0))),
			_count(int(earned.get("remixes", 0))), _count(int(earned.get("tested", 0))),
			_count(int(earned.get("comments", 0)))]
			+ "%s likes, %s followers." % [_count(int(earned.get("likes", 0))),
			_count(int(earned.get("followers", 0)))])
	else:
		lines.append("%s models in the gallery, %s likes, %s followers, following %s." % [
			_count(int(person.get("models_count", 0))), _count(int(person.get("likes", 0))),
			_count(int(person.get("followers", 0))), _count(int(person.get("following", 0)))])
	var models: Array = person["models"] if person.get("models") is Array else []
	lines.append("Their models, Top builds first:%s" % ("" if not models.is_empty() else " none listed."))
	for one: Variant in models.slice(0, 12):
		if one is Dictionary:
			lines.append("- " + _line(one) + (" · %s comments" % _count(int((one as Dictionary)["comments"]))
				if (one as Dictionary).get("comments") != null else ""))
	if models.size() > 12 or bool(person.get("more", false)):
		lines.append("And more on their page.")
	lines.append(FOLLOWING % url)
	return "\n".join(lines)


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
		return "sort is %s." % ", ".join(SORTS)
	# Parts I own is the person's own question: with their session, and
	# only once they are signed in.
	var token: String = await _token() if sort == "owned" else ""
	if sort == "owned" and token.is_empty():
		return ("sort=owned is Parts I own: the person signs in to Brickworks, with their parts kept in "
			+ "Collection, and asks again.")
	if not token.is_empty():
		asked.append("mine=1")
	asked.append("sort=" + sort)
	var page: int = maxi(1, int(input.get("page", 1)))
	asked.append("page=%d" % page)
	var answer: Dictionary = await _ask("/api/share?" + "&".join(asked), 256 * 1024, token)
	var body: Variant = _json(answer)
	if int(answer["code"]) != 200 or not body is Dictionary:
		return _trouble(answer, body)
	var models: Array = (body as Dictionary).get("models", [])
	var heading: String = "The gallery at %s%s, %s, page %d" % [Deployment.api_base(),
		"" if said.is_empty() else " (" + ", ".join(said) + ")", SORT_WORDS[sort], page]
	if models.is_empty():
		return "%s: nothing%s." % [heading, " matches" if not said.is_empty() else " is listed"]
	var lines := PackedStringArray(["%s:" % heading])
	var number: int = (page - 1) * 24
	for one: Variant in models:
		if not one is Dictionary:
			continue
		number += 1
		lines.append("%d. %s" % [number, _line(one)])
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
	# What people did with it, as its page says it and the list says it of
	# each model: how many built it, and the Tested mark.
	if shared.has("builds"):
		lines.append("Built to its last step %s." % _times(int(shared["builds"])) if int(shared["builds"]) > 0
			else "Nobody has built it to its last step yet.")
	if shared.get("tested") is Dictionary:
		lines.append("Tested: %s." % str((shared["tested"] as Dictionary).get("line", "the app checked it")))
	lines.append_array(await _said_of(id))
	if shared.get("remixed_from") is Dictionary:
		lines.append("Remixed from %s (%s)." % [(shared["remixed_from"] as Dictionary).get("name", "?"),
			(shared["remixed_from"] as Dictionary).get("url", "")])
	lines.append_array(_reading(str(shared.get("model", ""))))
	var motions: String = motions_words(Motions.read(str(shared.get("model", ""))))
	if not motions.is_empty():
		lines.append("%s Its link plays each by a button; open_model link=%s opens a copy, and play_motion "
			% [motions, id] + "name= plays one there.")
	lines.append(("Read-only: nothing on the baseplate changed. Build your own; to start from this "
		+ "one instead, open_model link=%s opens a copy in the person's models, as Open in "
		+ "Brickworks on its page does. Liking it, commenting and following its designer are the "
		+ "person's own, on its page, signed in.") % id)
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


## Its comments and the photos of real builds of it, as its page shows them
## to anybody (api/people.js ?op=comments and ?op=photos). What people
## wrote is quoted as theirs. Asked whether anybody had commented, a
## session could only send the person to the page (mcpwalk2, t5).
func _said_of(id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var answer: Dictionary = await _ask("/api/people?op=comments&id=" + id, 256 * 1024)
	var body: Variant = _json(answer)
	if int(answer["code"]) == 200 and body is Dictionary:
		var shown: Array = ((body as Dictionary).get("comments", []) as Array).filter(func(one: Variant) -> bool:
			return one is Dictionary and not bool((one as Dictionary).get("hidden", false)))
		shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("at", "")) > str(b.get("at", "")))
		var count: int = int((body as Dictionary).get("count", shown.size()))
		lines.append("Comments: %s%s%s" % ["none yet" if count == 0 else _count(count),
			"" if bool((body as Dictionary).get("open", true)) else " (closed by its designer)",
			"; the newest, as people wrote them:" if not shown.is_empty() else "."])
		for one: Dictionary in shown.slice(0, 3):
			lines.append("  %s%s%s: \"%s\"" % [str(one["by"]) if one.get("by") is String else "somebody",
				" (@%s)" % one["handle"] if one.get("handle") is String else "",
				" (its designer)" if bool(one.get("by_owner", false)) else "",
				str(one.get("body", "")).replace("\n", " ").left(240)])
	answer = await _ask("/api/people?op=photos&id=" + id, 64 * 1024)
	body = _json(answer)
	if int(answer["code"]) == 200 and body is Dictionary and (body as Dictionary).get("photos") is Array:
		var photos: int = ((body as Dictionary)["photos"] as Array).size()
		lines.append("Photos of real builds: %s." % ("none yet" if photos == 0 else "%d, on its page" % photos))
	return lines


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


## A model's own motions in a line, as its file has them: "Its motions (2):
## "Open the gates" (2 s, 2 joints), "Turn the crank" (4 s, a driver)."; ""
## for none. What a session names to play_motion.
static func motions_words(motions: Motions) -> String:
	if motions == null or motions.is_empty():
		return ""
	var said := PackedStringArray()
	for motion: Motions.Motion in motions.list:
		var joints: int = motion.tracks.size()
		said.append("%s (%s s, %s)" % [Motions.quoted(motion.name), Motions.num(motion.length(), 1),
			"a driver" if motion.driver != null else "%d joint%s" % [joints, "" if joints == 1 else "s"]])
	return "Its motions (%d): %s." % [said.size(), ", ".join(said)]


## One model of a list: "name (id) — 93 parts, by X · licence · counts ·
## built 3 times · moves: steering · Tested".
static func _line(model: Dictionary) -> String:
	var facts := PackedStringArray(["%s parts" % _count(int(model.get("parts", 0)))])
	if model.get("author") is String:
		facts[0] += ", by %s" % model["author"]
	# The designer whose page designer= reads, when the model is credited to one.
	if model.get("by") is Dictionary and (model["by"] as Dictionary).get("handle") is String:
		facts[0] += " (@%s)" % (model["by"] as Dictionary)["handle"]
	if model.get("kind") is String:
		facts.append(str(model["kind"]))
	facts.append(_licence_name(model.get("licence")))
	facts.append("%d views, %d likes, %d remixes" % [int(model.get("views", 0)),
		int(model.get("likes", 0)), int(model.get("remixes", 0))])
	# Said at nought too: a session sorting by Most built read a missing
	# count as one the list did not give.
	if model.has("builds"):
		facts.append(_built(int(model["builds"])))
	if bool(model.get("own_steps", false)):
		facts.append("its builder's own steps")
	if bool(model.get("technic", false)):
		facts.append("Technic")
	var moves: Array = model["moves"] if model.get("moves") is Array else []
	if not moves.is_empty():
		facts.append("moves: %s" % ", ".join(PackedStringArray(moves.map(func(one: Variant) -> String:
			return str(one)))))
	var motions: Array = model["motions"] if model.get("motions") is Array else []
	if not motions.is_empty():
		facts.append("motions: %s" % ", ".join(PackedStringArray(motions.map(func(one: Variant) -> String:
			return Motions.quoted(str(one))))))
	if bool(model.get("tested", false)):
		facts.append("Tested")
	if model.get("owned") is Dictionary and (model["owned"] as Dictionary).get("pieces") != null:
		var owned: Dictionary = model["owned"]
		facts.append("you own %s of its %s pieces" % [_count(int(owned.get("have", 0))),
			_count(int(owned.get("pieces", 0)))])
	return "%s (%s) — %s" % [model.get("name", "?"), model.get("id", "?"), " · ".join(facts)]


## "built 3 times", or "not built yet": finished to its last step by people
## following its steps (supabase/builds.sql).
static func _built(n: int) -> String:
	return "built %s" % _times(n) if n > 0 else "not built yet"


## "once", "twice", "3 times".
static func _times(n: int) -> String:
	return "once" if n == 1 else ("twice" if n == 2 else "%s times" % _count(n))


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
## anywhere a session names: {code, bytes}. With [param token], as the
## person signed in: their own share of each model's parts (mine=1).
func _ask(path: String, most: int, token: String = "") -> Dictionary:
	var request := HTTPRequest.new()
	request.body_size_limit = most
	request.timeout = 60.0
	app.add_child(request)
	var headers := PackedStringArray(["Accept: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	if request.request(Deployment.api_base() + path, headers) != OK:
		request.queue_free()
		return {"code": 0, "bytes": PackedByteArray()}
	var got: Array = await request.request_completed
	request.queue_free()
	if int(got[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "bytes": PackedByteArray()}
	return {"code": int(got[1]), "bytes": got[3] as PackedByteArray}
