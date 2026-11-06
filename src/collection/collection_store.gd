## The person's collection, kept with their account and on this device.
##
## The account's copy (api/collection.js, supabase/collection.sql) is the
## one that counts: it follows the person to another device and every
## import goes through it, because the server is where an import is parsed
## and put into LDraw's numbers. A copy is kept here as well, written
## whenever the account's arrives, so the desktop app still knows what is
## owned with no network — "What do I need?" and "What can I build?" work
## from it, and say they are working from the copy on this device.
##
## Also the one place the sets are expanded (SetInventories) into the pool
## every sum is done against, so the panels and the assistant agree on
## what is owned.
class_name CollectionStore
extends Node

## Where the copy on this device is kept. A probe points it somewhere of
## its own.
static var where: String = "user://collection.json"

var account: Account
var inventories: SetInventories
var library: PartLibrary

var collection: Collection = Collection.new()
## Part and colour -> how many are on hand, sets expanded. Kept current
## by [method refresh_pool].
var on_hand: Dictionary = {}
## Working from the copy on this device, because the account could not be
## reached or nobody is signed in.
var offline: bool = false
## The records of the sets in the collection, as last looked up.
var records: Dictionary = {}

signal changed


func _ready() -> void:
	_ensure_inventories()
	collection = Collection.from_json(_read_local(_who()))


func _ensure_inventories() -> void:
	if inventories == null:
		inventories = SetInventories.new()
		add_child(inventories)


## Fetch the account's copy, or fall back to the one on this device.
## Returns what to say: empty when all went well.
func load_collection() -> String:
	var reply: Dictionary = await _ask(HTTPClient.METHOD_GET, null)
	if int(reply["code"]) == 200:
		_take(reply["body"])
		offline = false
	else:
		offline = true
		collection = Collection.from_json(_read_local(_who()))
	await refresh_pool()
	changed.emit()
	return "" if not offline else "working from the copy on this device — %s" % _why(reply)


## An import: {"from": ..., "text" or "sets"/"parts", "mode"}. Returns
## {"error", "imported", "left_out"}.
func add(payload: Dictionary) -> Dictionary:
	var reply: Dictionary = await _ask(HTTPClient.METHOD_POST, payload)
	if int(reply["code"]) != 200:
		return {"error": _why(reply), "imported": {}, "left_out": []}
	_take(reply["body"])
	offline = false
	await refresh_pool()
	changed.emit()
	var body: Dictionary = reply["body"]
	return {"error": "", "imported": body.get("imported", {}), "left_out": body.get("left_out", [])}


## Keep exactly this collection (after taking a set out, say).
func put(next: Collection) -> String:
	var reply: Dictionary = await _ask(HTTPClient.METHOD_PUT,
		{"sets": next.sets, "parts": next.parts})
	if int(reply["code"]) != 200:
		return _why(reply)
	_take(reply["body"])
	await refresh_pool()
	changed.emit()
	return ""


## Forget all of it, at the account and here.
func clear() -> String:
	var reply: Dictionary = await _ask(HTTPClient.METHOD_DELETE, null)
	if int(reply["code"]) != 200:
		return _why(reply)
	_take(reply["body"])
	await refresh_pool()
	changed.emit()
	return ""


## Expand the sets afresh into [member on_hand].
func refresh_pool() -> void:
	_ensure_inventories()
	records = {}
	if not collection.sets.is_empty():
		records = await inventories.lookup(collection.set_numbers())
	on_hand = collection.pool(records, library)


func pieces_on_hand() -> int:
	var total: int = 0
	for key: String in on_hand:
		total += int(on_hand[key])
	return total


func _take(body: Variant) -> void:
	collection = Collection.from_json(body)
	var kept: Dictionary = collection.to_json()
	kept["owner"] = _who()
	_write_local(kept)


## Whose collection this is: the signed-in account's id, empty when none.
func _who() -> String:
	return account.user_id if account != null and account.signed_in() else ""


func _ask(method: int, body: Variant) -> Dictionary:
	if account == null or not account.signed_in():
		return {"code": -1, "body": null}
	var token: String = await account.access_token()
	if token.is_empty():
		return {"code": -1, "body": null}
	var headers := PackedStringArray(["authorization: Bearer " + token,
		"content-type: application/json"])
	var http := HTTPRequest.new()
	http.timeout = 60.0
	add_child(http)
	var sent: String = JSON.stringify(body) if body != null else ""
	if http.request(Deployment.api_base() + "/api/collection", headers, method, sent) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


static func _why(reply: Dictionary) -> String:
	var code: int = int(reply["code"])
	if code == -1:
		return "sign in to keep a collection with your account"
	if code == 0:
		return "could not reach Brickworks"
	var body: Variant = reply["body"]
	if typeof(body) == TYPE_DICTIONARY and (body as Dictionary).has("error"):
		return str(body["error"])
	return "Brickworks said %d" % code


## The copy on this device, if it is [param owner]'s. Somebody else signing
## in on the same machine is not shown the last person's collection while
## their own is on its way, nor instead of it when it cannot be fetched.
static func _read_local(owner: String = "") -> Dictionary:
	if not FileAccess.file_exists(where):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(where))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var kept_for: String = str((parsed as Dictionary).get("owner", ""))
	if not owner.is_empty() and not kept_for.is_empty() and kept_for != owner:
		return {}
	return parsed


static func _write_local(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(where, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
