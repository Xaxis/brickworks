## LDraw's models of real sets, as a library to open any of them from (File,
## Open, Library…: LibraryDialog; open_model library= over MCP).
##
## Kept where the part geometry the build does not carry is kept
## (PartLibrary.remote_parts, which the deployment names), under library/:
##
##   library/index.json            every model: its id ("omr-10179-1"), set,
##                                 name, theme, year, parts, file, cover,
##                                 author, licence, LDraw page, and which
##                                 model it is an alternate of
##   library/covers/<id>.webp      its picture
##   library/omr/<file>.mpd        the model, as LDraw's Official Model
##                                 Repository has it
##
## The web asks for them as it asks for a part. The desktop asks the same
## store and keeps what it fetched under user://library/, so the index and
## a model opened once are there with no connection; a dev checkout reads
## vendor/omr/files when the store cannot be reached.
class_name ModelLibrary
extends Node

const ROOT := "library/"
const KEPT := "user://library/"
const VENDOR := "res://vendor/omr/files/"
## An id as the index makes them: "omr-10179-1", "omr-10001-1_B-Model-from-Instruction".
const ID := "^[a-z]{2,8}-[A-Za-z0-9._-]{1,120}$"
const PER_PAGE := 24
## How the shelf is sorted, and each in words.
const SORTS: Array[String] = ["newest", "oldest", "largest", "smallest", "name"]
const SORT_WORDS: Dictionary = {"newest": "Newest sets", "oldest": "Oldest sets",
	"largest": "Most parts", "smallest": "Fewest parts", "name": "By name"}
## The gallery's sizes (api/_directory.js SIZES), so the two shelves agree.
const SIZES: Dictionary = {"small": [0, 199], "medium": [200, 999], "large": [1000, 1 << 30]}
const SIZE_WORDS: Dictionary = {"small": "Small, under 200 parts",
	"medium": "Medium, 200 to 999 parts", "large": "Large, 1,000 parts or more"}
## What the library is, said where a model from it is credited.
const FROM := "LDraw's Official Model Repository"
## Most the index and a model may be: the largest repository model is ~4 MB.
const MOST_INDEX := 16 * 1024 * 1024
const MOST_MODEL := 24 * 1024 * 1024
const MOST_COVER := 512 * 1024

var parts: PartLibrary
var deployment: Deployment

## Every model, as the index has them, each checked (_entry).
var _models: Array = []
var _by_id: Dictionary = {}
var _reading: bool = false
## Why the index could not be read, for a person; "" when it was.
var trouble: String = ""
signal _read


static func is_id(text: String) -> bool:
	return RegEx.create_from_string(ID).search(text) != null


## Where the store is, once the deployment has said; "" when it cannot be
## known (offline on the desktop, before it answered).
func root() -> String:
	if deployment != null:
		await deployment.wait()
	var given: String = parts.remote_parts if parts != null else ""
	if given.is_empty():
		return ""
	return given if given.ends_with("/") else given + "/"


## Every model, read once: [] when the index could not be read, and
## [member trouble] says why.
func models() -> Array:
	if not _models.is_empty():
		return _models
	if _reading:
		await _read
		return _models
	_reading = true
	var got: Dictionary = await _kept_or_fetched(ROOT + "index.json", MOST_INDEX, true)
	var json := JSON.new()
	if int(got["code"]) != 200 or json.parse((got["bytes"] as PackedByteArray).get_string_from_utf8()) != OK \
			or not json.data is Dictionary or not (json.data as Dictionary).get("models") is Array:
		trouble = _unreached(got, "the library's index")
	else:
		trouble = ""
		var kept: Array = []
		for raw: Variant in (json.data as Dictionary)["models"]:
			var entry: Dictionary = _entry(raw)
			if not entry.is_empty() and not _by_id.has(entry["id"]):
				_by_id[entry["id"]] = entry
				kept.append(entry)
		_models = kept
	_reading = false
	_read.emit()
	return _models


## One model by its id, or {} with [member trouble] saying why.
func find(id: String) -> Dictionary:
	if not is_id(id):
		trouble = "A library id is a kind and a name, like omr-10179-1."
		return {}
	await models()
	if _models.is_empty():
		return {}
	if not _by_id.has(id):
		trouble = "The library has no model %s." % id
		return {}
	return _by_id[id]


## An entry of the index, checked at the edge: {} for one that is not
## whole. Paths stay under library/, a page is an https address.
static func _entry(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var given: Dictionary = raw
	var id: String = str(given.get("id", ""))
	var file: String = str(given.get("file", ""))
	var cover: String = str(given.get("cover", "")) if given.get("cover") is String else ""
	var page: String = str(given.get("page", "")) if given.get("page") is String else ""
	if not is_id(id) or not _inside(file) or (not cover.is_empty() and not _inside(cover)):
		return {}
	return {"id": id, "set": str(given.get("set", "")) if given.get("set") is String else "",
		"name": str(given.get("name", id)).left(200), "theme": str(given.get("theme", "")).left(200)
			if given.get("theme") is String else "",
		"year": int(given.get("year", 0)) if given.get("year") is float or given.get("year") is int else 0,
		"parts": int(given.get("parts", 0)) if given.get("parts") is float or given.get("parts") is int else 0,
		"file": file, "cover": cover,
		"author": str(given.get("author", "")).left(200) if given.get("author") is String else "",
		"licence": str(given.get("licence", "")).left(60) if given.get("licence") is String else "",
		"page": page if page.begins_with("https://") else "",
		"alternate_of": str(given["alternate_of"]) if given.get("alternate_of") is String else ""}


static func _inside(path: String) -> bool:
	return path.begins_with(ROOT) and not path.contains("..") and not path.contains("\\") \
		and not path.contains("//")


## A model's top theme, as the shelf filters by it: "Town" of "Town > Classic Town".
static func theme_of(entry: Dictionary) -> String:
	return tidy(str(entry.get("theme", "")).get_slice(" > ", 0).get_slice(" / ", 0).strip_edges())


## Every top theme, by name.
static func themes(of: Array) -> PackedStringArray:
	var seen: Dictionary = {}
	for entry: Dictionary in of:
		var theme: String = theme_of(entry)
		if not theme.is_empty():
			seen[theme] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out


## The decades the shelf filters by, newest first: "2020s" … "1970s".
static func decades(of: Array) -> PackedStringArray:
	var seen: Dictionary = {}
	for entry: Dictionary in of:
		if int(entry["year"]) > 0:
			seen[int(entry["year"]) / 10 * 10] = true
	var years: Array = seen.keys()
	years.sort()
	years.reverse()
	var out := PackedStringArray()
	for year: int in years:
		out.append("%ds" % year)
	return out


## The LEGO Group's own words as the index has them, written as docs/TRADEMARKS.md
## asks where a person reads them: "LEGO Ideas" is "LEGO® Ideas".
static func tidy(text: String) -> String:
	return RegEx.create_from_string("\\bLEGO(?!®)\\b").sub(text, "LEGO®", true)


## The models [param ask] asks for, a page of them: {"models", "total",
## "page", "pages"}. [param ask]: q (words of a name or a set number),
## theme, decade ("1990s"), size (SIZES), sort (SORTS), page (from 1).
static func search(of: Array, ask: Dictionary) -> Dictionary:
	var words := PackedStringArray()
	for word: String in str(ask.get("q", "")).to_lower().split(" ", false):
		words.append(word)
	var theme: String = str(ask.get("theme", ""))
	var decade: int = str(ask.get("decade", "")).trim_suffix("s").to_int() \
		if not str(ask.get("decade", "")).is_empty() else -1
	var size: Array = SIZES.get(str(ask.get("size", "")), [])
	var found: Array = []
	for entry: Dictionary in of:
		if not theme.is_empty() and theme_of(entry) != theme:
			continue
		if decade >= 0 and int(entry["year"]) / 10 * 10 != decade:
			continue
		if not size.is_empty() and (int(entry["parts"]) < int(size[0]) or int(entry["parts"]) > int(size[1])):
			continue
		var said: String = ("%s %s %s %s" % [entry["name"], entry["set"], entry["theme"],
			entry["author"]]).to_lower()
		var all: bool = true
		for word: String in words:
			if not said.contains(word):
				all = false
				break
		if all:
			found.append(entry)
	var sort: String = str(ask.get("sort", "newest"))
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort:
			"oldest":
				if int(a["year"]) != int(b["year"]):
					return int(a["year"]) < int(b["year"])
			"largest":
				if int(a["parts"]) != int(b["parts"]):
					return int(a["parts"]) > int(b["parts"])
			"smallest":
				if int(a["parts"]) != int(b["parts"]):
					return int(a["parts"]) < int(b["parts"])
			"name":
				pass
			_:
				if int(a["year"]) != int(b["year"]):
					return int(a["year"]) > int(b["year"])
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	var pages: int = maxi(1, ceili(found.size() / float(PER_PAGE)))
	var page: int = clampi(int(ask.get("page", 1)), 1, pages)
	return {"models": found.slice((page - 1) * PER_PAGE, page * PER_PAGE), "total": found.size(),
		"page": page, "pages": pages}


## Who made [param entry] and on what terms, as the model carries it once
## opened (ModelStore.credit): {by, licence, page, from}.
static func credit_of(entry: Dictionary) -> Dictionary:
	return {"by": str(entry.get("author", "")), "licence": str(entry.get("licence", "")),
		"page": str(entry.get("page", "")), "from": FROM}


## "106-1 UNICEF Van": the set it is and what the LEGO Group called it.
static func title_of(entry: Dictionary) -> String:
	var number: String = str(entry.get("set", ""))
	return ("%s %s" % [number, entry["name"]]) if not number.is_empty() else str(entry["name"])


## The model's file: {"text", "error"}, the error in words for a person.
func model_text(entry: Dictionary) -> Dictionary:
	var file: String = str(entry["file"])
	var got: Dictionary = await _kept_or_fetched(file, MOST_MODEL, false)
	if int(got["code"]) == 200 and not (got["bytes"] as PackedByteArray).is_empty():
		return {"text": (got["bytes"] as PackedByteArray).get_string_from_utf8(), "error": ""}
	# A dev checkout has the repository's files themselves.
	if not OS.has_feature("web") and FileAccess.file_exists(VENDOR + file.get_file()):
		return {"text": FileAccess.get_file_as_string(VENDOR + file.get_file()), "error": ""}
	return {"text": "", "error": _unreached(got, title_of(entry))}


## A model's cover, or null.
func cover(entry: Dictionary) -> Texture2D:
	var path: String = str(entry.get("cover", ""))
	if path.is_empty():
		return null
	var got: Dictionary = await _kept_or_fetched(path, MOST_COVER, false)
	return picture(got["bytes"]) if int(got["code"]) == 200 else null


## A WebP, PNG or JPEG as a texture, or null.
static func picture(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 12:
		return null
	var image := Image.new()
	var read: int = ERR_FILE_UNRECOGNIZED
	if bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
		read = image.load_webp_from_buffer(bytes)
	elif bytes[0] == 0x89 and bytes[1] == 0x50:
		read = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		read = image.load_jpg_from_buffer(bytes)
	return ImageTexture.create_from_image(image) if read == OK else null


## Why [param what] did not come, in words for a person.
static func _unreached(got: Dictionary, what: String) -> String:
	if int(got["code"]) == 0:
		return "Could not reach the library for %s. Check the connection and try again." % what
	return "The library did not have %s (it answered %d)." % [what, int(got["code"])]


## [param path] under the store: {code, bytes}. The desktop keeps what came
## and reads it back first, or, with [param fresh], only when the store
## cannot be reached.
func _kept_or_fetched(path: String, most: int, fresh: bool) -> Dictionary:
	var kept: String = KEPT + path.trim_prefix(ROOT)
	var desk: bool = not OS.has_feature("web")
	if desk and not fresh and FileAccess.file_exists(kept):
		return {"code": 200, "bytes": FileAccess.get_file_as_bytes(kept)}
	var base: String = await root()
	var got: Dictionary = {"code": 0, "bytes": PackedByteArray()}
	if not base.is_empty():
		got = await fetch(base + path, most)
	if int(got["code"]) == 200:
		if desk:
			DirAccess.make_dir_recursive_absolute(kept.get_base_dir())
			var file: FileAccess = FileAccess.open(kept, FileAccess.WRITE)
			if file != null:
				file.store_buffer(got["bytes"])
				file.close()
		return got
	if desk and FileAccess.file_exists(kept):
		return {"code": 200, "bytes": FileAccess.get_file_as_bytes(kept)}
	return got


## One request: {code, bytes}, code 0 when nothing came back. Asked again
## twice when nothing did, as SharedModels.fetch does.
func fetch(url: String, most: int) -> Dictionary:
	for attempt: int in 3:
		var request := HTTPRequest.new()
		request.body_size_limit = most
		request.timeout = 60.0
		add_child(request)
		if request.request(url) != OK:
			request.queue_free()
			return {"code": 0, "bytes": PackedByteArray()}
		var got: Array = await request.request_completed
		request.queue_free()
		if int(got[0]) == HTTPRequest.RESULT_SUCCESS and int(got[1]) != 0:
			return {"code": int(got[1]), "bytes": got[3] as PackedByteArray}
		if attempt < 2:
			await get_tree().create_timer(1.0 + attempt * 2.0).timeout
	return {"code": 0, "bytes": PackedByteArray()}
