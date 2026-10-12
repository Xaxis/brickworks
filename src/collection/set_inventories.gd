## What is in a set, looked up by its number.
##
## tools/collection_data.py writes Rebrickable's set inventories, in
## LDraw's numbers, as 256 shards under assets/generated/sets/, with the
## official models' parts lists (src/dev/collection_models.gd) beside them.
## The desktop reads them from its own files. The web build does not carry
## them — together they are 26 MB and a person types one set at a time — so
## it fetches the one shard a set is in from the deployment's /sets/, which
## deploy.sh fills, and keeps what it fetched for the visit.
class_name SetInventories
extends Node

const ROOT := "res://assets/generated/sets/"
const SHARDS := 256

## Where the shards are fetched from on the web; the deployment's own
## /sets/ unless a probe points it elsewhere.
var remote: String = ""

## shard number -> {set number -> record}
var _shards: Dictionary = {}
var _models: Array = []
var _models_read: bool = false
## Why the last lookup could not be made, for the panel to say; empty when
## it could.
var trouble: String = ""


## Which shard a set is in. tools/collection_data.py shard_of is the same
## sum and the two must agree, or a typed set is looked for in the wrong
## file and reported unknown.
static func shard_of(set_number: String) -> int:
	var h: int = 0
	for byte: int in set_number.strip_edges().to_lower().to_utf8_buffer():
		h = (h * 31 + byte) % 1000003
	return h % SHARDS


## "10237" is "10237-1", as Rebrickable and BrickLink number a first
## version. The same rule as api/collection.js setNumber.
static func normal(set_number: String) -> String:
	var text: String = set_number.strip_edges().to_lower()
	if text.is_empty():
		return ""
	var dash: int = text.rfind("-")
	if dash < 0 or not text.substr(dash + 1).is_valid_int():
		text += "-1"
	return text


## The records of the sets asked for: set number -> {"n", "y", "p", "s"}.
## A set that is in no inventory is simply absent.
func lookup(numbers: PackedStringArray) -> Dictionary:
	trouble = ""
	var wanted: Dictionary = {}
	for number: String in numbers:
		wanted[shard_of(number)] = true
	for shard: int in wanted:
		if not _shards.has(shard):
			var read: Variant = await _read("%03d.json" % shard)
			if typeof(read) == TYPE_DICTIONARY:
				_shards[shard] = (read as Dictionary).get("sets", {})
	var found: Dictionary = {}
	for number: String in numbers:
		var held: Dictionary = _shards.get(shard_of(number), {})
		if held.has(number):
			found[number] = held[number]
	return found


## The official LDraw set models (vendor/omr), each with its parts:
## [{"name", "set", "file", "year", "theme", "page", "needs": {key -> count}}].
func official_models() -> Array:
	if _models_read:
		return _models
	var read: Variant = await _read("models.json")
	_models_read = typeof(read) == TYPE_DICTIONARY
	if _models_read:
		_models = []
		for entry: Variant in (read as Dictionary).get("models", []):
			var model: Dictionary = entry
			var needs: Dictionary = {}
			for row: Variant in model.get("p", []):
				var lot: Array = row
				needs[Collection.key_of(str(lot[0]), int(lot[1]))] = int(lot[2])
			_models.append({"name": str(model.get("n", "")), "set": str(model.get("set", "")),
				"file": str(model.get("file", "")), "year": int(model.get("y", 0)),
				"theme": str(model.get("t", "")), "page": str(model.get("g", "")), "needs": needs})
	return _models


func _read(file_name: String) -> Variant:
	if not OS.has_feature("web") or FileAccess.file_exists(ROOT + file_name):
		var text: String = FileAccess.get_file_as_string(ROOT + file_name)
		if text.is_empty():
			trouble = "the set inventories are not in this build (tools/collection_data.py)"
			return null
		return JSON.parse_string(text)
	var base: String = remote if not remote.is_empty() else Deployment.api_base() + "/sets/"
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	if http.request(base + file_name) != OK:
		http.queue_free()
		trouble = "could not ask for the set inventories"
		return null
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		trouble = "the set inventories did not arrive (%d)" % int(result[1])
		return null
	var json := JSON.new()
	if json.parse((result[3] as PackedByteArray).get_string_from_utf8()) != OK:
		trouble = "the set inventories did not read"
		return null
	return json.data
