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
	_held_for = _who()


func _ensure_inventories() -> void:
	if inventories == null:
		inventories = SetInventories.new()
		add_child(inventories)


## From now on, fetched as each person signs in ([member account]'s).
func follow_account() -> void:
	if account != null:
		account.changed.connect(_on_account)
		_on_account()


## Fetched once per person signing in, not on every change the account
## reports (a renewal, going offline); forgotten on signing out, so the next
## person on this machine starts from their own.
func _on_account() -> void:
	var who: String = _who()
	if who == _loaded_for:
		return
	_loaded_for = who
	if who.is_empty():
		collection = Collection.new()
		_held_for = ""
		on_hand = {}
		records = {}
		changed.emit()
		return
	load_collection()


## Whose collection was last fetched: the account's id, empty for nobody.
var _loaded_for: String = ""


## Fetch the account's copy, or fall back to the one on this device.
## Returns what to say: empty when all went well. A reply that comes back
## after the account changed is the last person's, and is dropped.
func load_collection() -> String:
	var reply: Dictionary = await _ask(HTTPClient.METHOD_GET, null)
	if int(reply["code"]) == DROPPED:
		return ""
	if int(reply["code"]) == 200:
		_take(reply["body"])
		offline = false
	else:
		offline = true
		collection = Collection.from_json(_read_local(_who()))
		_held_for = _who()
	await refresh_pool()
	changed.emit()
	return "" if not offline else "working from the copy on this device — %s" % _why(reply)


## What a write came to: "kind" is "done", "refused" (the account said no:
## nothing changed), "conflict" (what was seen is no longer so: nothing
## changed, and the collection as it is now is taken and shown), or
## "unreached" (no answer came, sent again and still none, or it came for
## an account no longer signed in: it may have been made all the same);
## "said" says it in words, empty when done; "body" is the account's answer.
const DONE := "done"
const REFUSED := "refused"
const CONFLICT := "conflict"
const UNREACHED := "unreached"


## One change at the account, as one op (api/collection.js): never a copy
## of the collection. Sent with an id of its own; when no answer comes, or
## the account was busy, sent again as it was, which the account never
## makes twice and answers as it did the first time. A collection shown
## from the copy on this device is read afresh first, and nothing is sent
## while the account cannot be reached. Every write goes through here, one
## at a time (the dialog's, a session's edit_collection, a probe's), so
## each is made on what the last one left and is answered after it
## (mb2review finding 4).
func change(body: Dictionary) -> Dictionary:
	while _changing:
		await _change_made
	_changing = true
	var done: Dictionary = await _change_now(body)
	_changing = false
	_change_made.emit()
	return done


## A change is being made at the account, and the next waits its turn.
var _changing: bool = false
signal _change_made


func _change_now(body: Dictionary) -> Dictionary:
	if account == null or not account.signed_in():
		return {"kind": REFUSED, "said": _why({"code": -1, "body": null}), "body": {}}
	if offline:
		await load_collection()
		if offline:
			return {"kind": REFUSED, "said": "could not reach Brickworks, so nothing was changed: what is "
				+ "shown is the copy on this device", "body": {}}
	var sent: Dictionary = body.duplicate()
	sent["id"] = "%d-%s" % [int(Time.get_unix_time_from_system() * 1000.0),
		Crypto.new().generate_random_bytes(8).hex_encode()]
	var reply: Dictionary = {}
	for attempt: int in 3:
		if attempt > 0:
			await get_tree().create_timer(1.5 * attempt).timeout
		reply = await _ask(HTTPClient.METHOD_POST, sent)
		var code: int = int(reply["code"])
		if code != 0 and code != 503 and code != 502:
			break
	var code: int = int(reply["code"])
	# Sent, perhaps, and no answer for whoever is signed in now: it may have
	# been made (mb2review finding 6).
	if code == DROPPED:
		return {"kind": UNREACHED, "said": "the account changed while it was being sent, so it may have "
			+ "been made: reload My collection to see", "body": {}}
	if code == 200:
		_take(reply["body"])
		offline = false
		await refresh_pool()
		changed.emit()
		return {"kind": DONE, "said": "", "body": reply["body"]}
	if code == 409 and reply["body"] is Dictionary and (reply["body"] as Dictionary).has("parts"):
		_take(reply["body"])
		await refresh_pool()
		changed.emit()
		return {"kind": CONFLICT, "said": "%s. It changed since it was shown, so nothing was changed: it is "
			% _why(reply) + "shown as it is now", "body": reply["body"]}
	if code == 0 or code == 502:
		return {"kind": UNREACHED, "said": "%s, so it may have been made: reload My collection to see"
			% _why(reply), "body": {}}
	return {"kind": REFUSED, "said": _why(reply), "body": reply.get("body", {})}


## An import: {"from": ..., "text" or "sets"/"parts", "mode"}. Returns
## {"error", "imported", "left_out", "clamped"} ([method clamped_words]).
## Sent again with no answer, it is told what the first try did.
func add(payload: Dictionary) -> Dictionary:
	var done: Dictionary = await change(payload)
	if done["kind"] != DONE:
		return {"error": done["said"], "imported": {}, "left_out": [], "clamped": ""}
	var body: Dictionary = done["body"]
	return {"error": "", "imported": body.get("imported", {}), "left_out": body.get("left_out", []),
		"clamped": clamped_words(body)}


## Loose lots added, each {"part", "colour", "qty"}, and "by" and "chat" for
## a session's; and a session's own lots taken down by "qty" (all of it
## when 0). Nothing else in the collection is touched, here or at the
## account. Returns [method change]'s answer.
func change_lots(adding: Array, taking_down: Array = []) -> Dictionary:
	var body: Dictionary = {"op": "lots"}
	if not adding.is_empty():
		body["add"] = adding
	if not taking_down.is_empty():
		body["remove"] = taking_down
	return await change(body)


## Lots' counts put from what was shown to what was asked: each of
## [param asked] is a lot as shown (its "qty" what the person saw) and
## "to", the count asked for (0 takes it out). Refused, changing nothing,
## when any is not as shown.
func set_counts(asked: Array) -> Dictionary:
	var lots: Array = []
	for one: Dictionary in asked:
		var lot: Dictionary = Collection.named(one)
		lot["was"] = int(one["qty"])
		lot["qty"] = int(one["to"])
		lots.append(lot)
	return await change({"op": "set", "lots": lots})


## Lots a session added, at the counts shown ([param shown]), made the
## person's own ("keep") or taken out ("take_back"): exactly those.
func settle_added(op: String, shown: Array) -> Dictionary:
	var lots: Array = []
	for one: Dictionary in shown:
		var lot: Dictionary = Collection.named(one)
		lot["was"] = int(one["qty"])
		lots.append(lot)
	if lots.is_empty():
		return {"kind": DONE, "said": "", "body": {}}
	return await change({"op": op, "lots": lots})


## Every lot a session added, as this copy shows them, taken back.
func take_back() -> Dictionary:
	return await settle_added("take_back", collection.added_lots())


## Every lot a session added, as this copy shows them, kept as the
## person's own.
func keep_added() -> Dictionary:
	return await settle_added("keep", collection.added_lots())


## A set taken out, at the count shown.
func remove_set(entry: Dictionary) -> Dictionary:
	var body: Dictionary = Collection.named(entry)
	body["op"] = "remove_set"
	body["was"] = int(entry["qty"])
	return await change(body)


## Forget all of it, at the account and here: what was shown, if it is
## still so.
func clear() -> Dictionary:
	return await change({"op": "start_over", "rev": collection.rev})


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


## [param body] taken as the collection, unless it is older than the one
## held for the same person: replies come in any order (a read sent before
## an Add can be answered after it), and the account's rev says which is
## newer; a reply with none is from before the account kept any (mb2review
## finding 4). Returns whether it was taken.
func _take(body: Variant) -> bool:
	var next: Collection = Collection.from_json(body)
	var who: String = _who()
	if who == _held_for and collection.rev != null and (next.rev == null or int(next.rev) < int(collection.rev)):
		return false
	collection = next
	_held_for = who
	var kept: Dictionary = collection.to_json()
	kept["owner"] = who
	_write_local(kept)
	return true


## Whose [member collection] is: the account it was taken for.
var _held_for: String = ""


## What the account held back, in words: a lot stops at 100,000 pieces,
## and what went over is said, never dropped quietly. Empty when nothing
## was. [param body] is the account's answer to a change.
static func clamped_words(body: Variant) -> String:
	if not body is Dictionary or not (body as Dictionary).get("done") is Dictionary:
		return ""
	var done: Dictionary = body["done"]
	var held: Array = done["clamped"] if done.get("clamped") is Array else []
	if held.is_empty():
		return ""
	var named := PackedStringArray()
	for one: Variant in held.slice(0, 3):
		if one is Dictionary:
			named.append("%s in colour %d (%d over)" % [str(one.get("part", "")), int(one.get("colour", 0)),
				int(one.get("over", 0))])
	var lots: int = int(done.get("clamped_lots", held.size()))
	return "%s stopped at 100,000, the most one lot holds, and the rest was not kept: %s%s" % [
		Counted.of(lots, "lot"), ", ".join(named), "" if lots <= named.size() else ", …"]


## Whose collection this is: the signed-in account's id, empty when none.
func _who() -> String:
	return account.user_id if account != null and account.signed_in() else ""


## A reply dropped: it came for an account no longer the signed-in one.
const DROPPED := -2


func _ask(method: int, body: Variant) -> Dictionary:
	if account == null or not account.signed_in():
		return {"code": -1, "body": null}
	var asked_for: String = _who()
	var token: String = await account.access_token()
	if _who() != asked_for:
		return {"code": DROPPED, "body": null}
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
	if _who() != asked_for:
		return {"code": DROPPED, "body": null}
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
	if code == DROPPED:
		return "the account changed while it was being asked"
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
