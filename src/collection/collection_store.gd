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
##
## With nobody signed in (localbricks, APP_UX6 #8, 2026-11-07), the
## collection is this device's own (CollectionHere, [method here_folder]):
## added to, counted and marked as an account's is, by the same ops, and
## never mixed with the copy of an account's kept here, which is shown only
## to its own account and never changed signed out. When somebody signs in
## and this device keeps anything, they are asked whether to put it into
## their account's collection ([signal join_offered], [method join]): every
## lot and set of both is kept, and nothing moves until they say so.
class_name CollectionStore
extends Node

## Where the copy of an account's collection on this device is kept. A
## probe points it somewhere of its own, and the device's own collection
## goes beside it ([method here_folder]).
static var where: String = "user://collection.json"

## What each set the person owns is marked as missing, by set number:
## {"copies": how many they own, "missing": key (Collection.key_of) ->
## pieces}, every entry of that number's together. Kept current by the
## window's store ([method refresh_pool]), so a bin built from a set
## (SetBin.make: Build from it, Build from them all, a model's bin opened
## again) leaves out what is not there (localbricks).
static var marks: Dictionary = {}

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
## Whether [member collection] is this device's own: nobody is signed in
## (localbricks).
var here: bool = false
## Which tab's or window's file this store writes the device's own
## collection to (CollectionHere): TabSession's id when empty. A probe
## playing two tabs gives each its own.
var writer: String = ""
## The folder this store keeps the device's own collection in: [method
## here_folder] when empty. A probe playing two devices gives each its own.
var here_at: String = ""
## The joins sent from this device that no answer came for yet, as last
## read: each {"id", "to", "sets", "parts"}.
var pending: Array = []
## Tabs' records of the device's own collection that could not be read:
## kept on disk as they are, and said ([method here_words]).
var unread: PackedStringArray = PackedStringArray()

signal changed
## Somebody signed in and this device keeps a collection of its own they
## have not answered for: they are asked whether to put it into their
## account's ([method join]). Only the window's store asks ([method
## follow_account]).
signal join_offered


func _ready() -> void:
	_ensure_inventories()
	if _who().is_empty():
		_take_here(CollectionHere.read(_folder()))
	else:
		collection = Collection.from_json(_read_local(_who()))
		_held_for = _who()


func _ensure_inventories() -> void:
	if inventories == null:
		inventories = SetInventories.new()
		add_child(inventories)


## From now on, fetched as each person signs in ([member account]'s); and,
## as the window's store, asking at each sign-in whether to put this
## device's own collection into the account's ([signal join_offered]).
func follow_account() -> void:
	_asks = true
	join_offered.connect(show_offer)
	if account != null:
		account.changed.connect(_on_account)
		_on_account()


## Fetched once per person signing in, not on every change the account
## reports (a renewal, going offline); on signing out, the device's own
## collection, so the account's is not shown to the next person on this
## machine, nor left to be changed here (localbricks). Then the pool again.
func _on_account() -> void:
	var who: String = _who()
	if _loaded_for != null and who == str(_loaded_for):
		return
	_loaded_for = who
	if who.is_empty():
		_take_here(CollectionHere.read(_folder()))
		offline = false
		on_hand = {}
		records = {}
		changed.emit()
		await refresh_pool()
		changed.emit()
		return
	await load_collection()
	if _who() == who:
		await _after_sign_in(who)


## Whose collection was last fetched: the account's id, empty for nobody,
## null before the first.
var _loaded_for: Variant = null
## Whether this is the window's store, which asks at sign-in.
var _asks: bool = false


## Fetch the account's copy, or fall back to the one on this device.
## Returns what to say: empty when all went well. A reply that comes back
## after the account changed is the last person's, and is dropped.
func load_collection() -> String:
	# Nobody signed in: the device's own, read afresh (another tab's or
	# window's changes in it too).
	if _who().is_empty():
		_take_here(CollectionHere.read(_folder()))
		offline = false
		await refresh_pool()
		changed.emit()
		return here_words()
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
		here = false
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
		return await _change_here(body)
	if offline:
		await load_collection()
		if offline:
			return {"kind": REFUSED, "said": "could not reach Brickworks, so nothing was changed: what is "
				+ "shown is the copy on this device", "body": {}}
	var sent: Dictionary = body.duplicate()
	# A join says its own id, kept with it on this device before it is sent
	# (localbricks): sent again with it, it is never made twice.
	if str(body.get("id", "")).is_empty():
		sent["id"] = _fresh_id()
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


## Expand the sets afresh into [member on_hand]. A collection taken while
## its sets were looked up (signed out meanwhile) is that one's to expand.
func refresh_pool() -> void:
	_ensure_inventories()
	var held: Collection = collection
	var found: Dictionary = {}
	if not held.sets.is_empty():
		found = await inventories.lookup(held.set_numbers())
	if held != collection:
		return
	records = found
	on_hand = collection.pool(records, library)
	if _asks:
		marks = _marks_of(collection)


## What [param mine]'s sets are marked as missing, by set number ([member
## marks]).
func _marks_of(mine: Collection) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in mine.sets:
		if Collection.is_fig(entry):
			continue
		var number: String = str(entry["set"])
		if not out.has(number):
			out[number] = {"copies": 0, "missing": {}}
		out[number]["copies"] = int(out[number]["copies"]) + int(entry.get("qty", 1))
		var gone: Dictionary = Collection.missing_keys(entry, library)
		for key: String in gone:
			out[number]["missing"][key] = int(out[number]["missing"].get(key, 0)) + int(gone[key])
	for number: String in out.keys():
		if (out[number]["missing"] as Dictionary).is_empty():
			out.erase(number)
	return out


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
	here = false
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


# --- the collection this device keeps (localbricks, APP_UX6 #8) -------------
#
# With nobody signed in, every change goes to this device's own collection
# (CollectionHere), checked as the account checks it and answered the same
# way, so My collection, edit_collection and every probe of them work alike
# signed in or out. At a sign-in, what it keeps is offered to the account,
# the person asked first (CollectionOffer); "Put them together" joins it,
# every lot and set of both kept; "Not now" leaves it here, apart, offered
# again in My collection and at the next sign-in once it has changed.

## The folder the device's own collection is kept in, beside [member where]:
## a file a tab or window (CollectionHere).
static func here_folder() -> String:
	return where.get_basename() + ".here"


func _folder() -> String:
	return here_at if not here_at.is_empty() else here_folder()


func _writer() -> String:
	return writer if not writer.is_empty() else TabSession.id()


static func _fresh_id() -> String:
	return "%d-%s" % [int(Time.get_unix_time_from_system() * 1000.0), Crypto.new().generate_random_bytes(8).hex_encode()]


## [param read] (CollectionHere.read) taken as the collection shown.
func _take_here(read: Dictionary) -> void:
	collection = Collection.from_json(read["shown"])
	here = true
	_held_for = ""
	pending = read["pending"]
	unread = read["unread"]


## What is said of the device's own collection beyond its lots: a tab's
## record that could not be read (kept as it is), and lots on their way to
## an account. Empty when there is nothing to say.
func here_words() -> String:
	var said := PackedStringArray()
	if not unread.is_empty():
		said.append("%s of this collection on this device could not be read, and is kept as it is"
			% Counted.of(unread.size(), "window's record", "windows' records"))
	var going: int = 0
	for join: Dictionary in pending:
		going += (join.get("parts", []) as Array).size() + (join.get("sets", []) as Array).size()
	if going > 0:
		said.append("%s sent to an account had no answer yet: kept here, and sent again (never twice) when "
			% Counted.of(going, "lot or set", "lots and sets") + "that account signs in")
	return "; ".join(said)


## One change to the device's own collection, as [method _change_now] makes
## one at the account: checked against every tab's record put together, and
## kept as how far it moves each count, so a change another tab made at the
## same moment stays too. Answered as the account answers.
func _change_here(body: Dictionary) -> Dictionary:
	var folder: String = _folder()
	var read: Dictionary = CollectionHere.read(folder)
	var made: Dictionary = CollectionHere.apply(read["shown"], body, library)
	if made.has("error"):
		if made.get("conflict") == true:
			_take_here(read)
			await refresh_pool()
			changed.emit()
			var now: Dictionary = (read["shown"] as Dictionary).duplicate()
			now["error"] = made["error"]
			return {"kind": CONFLICT, "said": "%s. It changed since it was shown, so nothing was changed: it is "
				% made["error"] + "shown as it is now", "body": now}
		return {"kind": REFUSED, "said": str(made["error"]), "body": {"error": made["error"]}}
	if made.get("next") != null:
		var trouble: String = CollectionHere.write(folder, _writer(), read["raw"], made["next"])
		if not trouble.is_empty():
			return {"kind": REFUSED, "said": trouble, "body": {"error": trouble}}
		read = CollectionHere.read(folder)
	_take_here(read)
	await refresh_pool()
	changed.emit()
	var reply: Dictionary = (read["shown"] as Dictionary).duplicate()
	reply["done"] = made["done"]
	if (made["done"] as Dictionary).has("imported"):
		reply["imported"] = made["done"]["imported"]
		reply["left_out"] = made["done"].get("left_out", [])
	return {"kind": DONE, "said": "", "body": reply}


## What this device keeps of its own that could go to the account: all of
## it, less what is on its way to an account already. {"sets", "parts"}.
func offer_now() -> Dictionary:
	return CollectionHere.offerable(CollectionHere.read(_folder()))


## The device's own collection as [method offer_now] has it, as a
## Collection: what My collection lists as on this device only.
func here_collection() -> Collection:
	return Collection.from_json(offer_now())


## Signed in: joins sent before with no answer, sent again with their ids;
## then, when this device keeps anything the person has not answered for
## as it is now, they are asked.
func _after_sign_in(who: String) -> void:
	await resume_joins()
	if not _asks or _who() != who:
		return
	var read: Dictionary = CollectionHere.read(_folder())
	var what: Dictionary = CollectionHere.offerable(read)
	if (what["sets"] as Array).is_empty() and (what["parts"] as Array).is_empty():
		return
	var turned: Dictionary = (read["declined"] as Dictionary).get(who, {})
	if str(turned.get("what", "")) == CollectionHere.signature(what):
		return
	join_offered.emit()


## The offer, shown: made the first time it is wanted (the web loads none of
## it until then).
func show_offer() -> void:
	if not is_inside_tree() or _who().is_empty():
		return
	if _offer == null:
		_offer = Later.make(&"CollectionOffer") as Window
		_offer.set("store", self)
		add_child(_offer)
	_offer.call("ask")


## The offer's window, once made: for a probe to press as a person does.
func offer_window() -> Window:
	return _offer


var _offer: Window = null


## Not now: what this device keeps stays here, apart, and is not asked
## about again at a sign-in until it changes (My collection still offers it).
func decline() -> void:
	var who: String = _who()
	if who.is_empty():
		return
	var read: Dictionary = CollectionHere.read(_folder())
	CollectionHere.write(_folder(), _writer(), read["raw"], null, {"declined": {who: {
		"at": int(Time.get_unix_time_from_system() * 1000.0),
		"what": CollectionHere.signature(CollectionHere.offerable(read))}}})


## Put what this device keeps into the signed-in account's collection: kept
## here with its id before it is sent, then sent as one change (api
## /collection.js op "join"), every lot and set of both kept. Asked for by
## the person (CollectionOffer). Answered as [method change] is; "body"'s
## "joined" says how many lots and sets went.
func join() -> Dictionary:
	var who: String = _who()
	if who.is_empty():
		return {"kind": REFUSED, "said": "sign in first: what this device keeps goes into your account's collection",
			"body": {}}
	await resume_joins()
	var folder: String = _folder()
	var read: Dictionary = CollectionHere.read(folder)
	var what: Dictionary = CollectionHere.offerable(read)
	if (what["sets"] as Array).is_empty() and (what["parts"] as Array).is_empty():
		return {"kind": DONE, "said": "", "body": {"joined": {"sets": 0, "lots": 0}}}
	# Its id is what it sends, to whom, after which joins: two tabs that press
	# Put them together at once, each before it saw the other's, send one
	# join the account makes once; the same lots added again after a join
	# are a join of their own.
	var id: String = "join-" + JSON.stringify([who, what, read["joins"]]).md5_text()
	var sent: Dictionary = {"id": id, "to": who, "at": int(Time.get_unix_time_from_system() * 1000.0),
		"sets": what["sets"], "parts": what["parts"]}
	var trouble: String = CollectionHere.write(folder, _writer(), read["raw"], null, {"joins": [sent]})
	if not trouble.is_empty():
		return {"kind": REFUSED, "said": trouble, "body": {}}
	return await _send_join(sent)


## Every join sent from this device to the signed-in account with no answer
## yet, sent again as it was; each settled by the answer.
func resume_joins() -> void:
	var who: String = _who()
	if who.is_empty():
		return
	for sent: Dictionary in CollectionHere.read(_folder())["pending"]:
		if str(sent.get("to", "")) == who and _who() == who:
			await _send_join(sent)


func _send_join(sent: Dictionary) -> Dictionary:
	var done: Dictionary = await change({"op": "join", "id": sent["id"], "sets": sent.get("sets", []),
		"parts": sent.get("parts", [])})
	var settled: String = ""
	if done["kind"] == DONE:
		settled = "applied"
	elif done["kind"] == REFUSED or done["kind"] == CONFLICT:
		# Refused, so never made: it stays on this device.
		settled = "returned"
	if not settled.is_empty():
		var read: Dictionary = CollectionHere.read(_folder())
		CollectionHere.write(_folder(), _writer(), read["raw"], null, {"settled": {str(sent["id"]): settled}})
	if done["kind"] == UNREACHED:
		done["said"] = ("no answer came, so they may be in your collection already: they stay on this device, and "
			+ "are sent again (never added twice) when you next sign in or open My collection")
	pending = CollectionHere.read(_folder())["pending"]
	changed.emit()
	return done
