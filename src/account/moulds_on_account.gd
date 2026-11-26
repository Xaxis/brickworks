## Your own moulds on your account (sitehair, 2026-11-25; owner ask #14).
##
## A mould saved in the minifig builder ([MouldEditor]) is kept on this
## device ([CustomParts]) and in each model that uses it. Signed in, a copy
## goes to the account the moment it is saved (POST /api/people?op=mould,
## api/_moulds.js, supabase/own_moulds.sql), so the site's own minifig maker
## (Edit profile, web/minifig-maker.js) lists it beside the catalogue's hair
## and the person's avatar can wear it, with no second step.
##
## Only the person's own, and only on their own account (hairfix, after
## hairreview H1: every mould file on the device went to whoever signed in,
## a mould carried in a model somebody else made and one saved signed out
## by somebody else on a shared computer too). "Mine" is not "a mould file
## on this device": the device keeps a ledger ([method ledger_path]) of the
## moulds made here with Save mould, each with the account signed in at that
## moment, or none. A mould a model brought is in no ledger, so it is never
## sent. One made under an account goes to that account alone: at once, or,
## when that failed, the next time the builder opens with that account
## signed in ([method sweep]). One made signed out belongs to nobody the
## studio knows: on a shared computer it may be anybody's. So it is never
## sent by itself; the builder, opened signed in, asks the person whether
## those are theirs ([method unclaimed]), and sends them only when they say
## so ([method claim]), or never asks that account again ([method decline]).
##
## The account's answer is said in the app's own words, in the person's
## language (each refusal's code, api/_moulds.js MouldRefusal). Refused for
## what the mould is (too big, a file the site will not keep), a mould is not
## sent again; refused for room, it goes again once the account has room for
## it (the list the sweep asks says how much); out of reach, it goes the next
## time the builder opens (hairreview L1, L3).
##
## A mould shaped further from one of the person's own is sent with the one
## it was shaped from (replaces), which the account then drops: reworking
## your hair keeps one mould on the account, not one a version (H2).
class_name MouldsOnAccount
extends RefCounted

## Said in the builder once the account has the mould.
const KEPT := "Kept on your account too: wear it in the site's minifig maker (Edit profile)."
## Said when the account would not keep it: why after.
const NOT_KEPT := "Kept in the studio only: %s"
const SIGNED_OUT := "sign in to keep it on your account"
const NOT_HERE := "it is not kept on this device"
const SIGN_IN_AGAIN := "sign in again to keep it on your account"
const UNREACHED := "Brickworks could not be reached"
const NOT_TAKEN := "Brickworks could not take it just now (%d)"
const NO_ROOM := "your account has room for 40 moulds and 24 MB of them: remove one in the site's minifig maker (Edit profile, Hair and hats), and this one goes the next time the builder opens"
const TOO_BIG := "it is bigger than the site keeps: 2 MB and 18,000 triangles at most"
const NOT_A_MOULD := "the site would not keep its file: save it again"
const TOO_MANY := "more moulds than the site takes in an hour: it goes the next time the builder opens"
const NOT_OPEN := "moulds on your account are not open on Brickworks yet"
## The builder's question, opened signed in, for moulds saved signed out.
const ASK_ONE := "1 mould made here while nobody was signed in is kept in the studio only. Is it yours?"
const ASK_MANY := "%d moulds made here while nobody was signed in are kept in the studio only. Are they yours?"
const PUT_ON := "Put on my account"
const NOT_MINE := "Not mine"
const CLAIMED := "Kept on your account too: %d of them."

## The account a sweep was made for this run, so one is made once; cleared
## when one of its sends did not get through, so the next opening tries.
static var swept_for: String = ""
## How many moulds this run sent, for a check to count.
static var sends: int = 0


## Where the ledger is kept: beside the folder of made parts it speaks of,
## so a check that keeps its parts apart keeps its ledger apart too.
static func ledger_path() -> String:
	return CustomParts.dir.trim_suffix("/").get_base_dir().path_join("own_moulds.json")


## The ledger's entries: {id, slot, by (the account's id, "" for nobody
## signed in), at, replaces, sent, refused ({status, code} once the account
## refused it), declined (accounts that said it was not theirs), superseded
## (shaped further before it was sent)}.
static func ledger() -> Array:
	var text: String = FileAccess.get_file_as_string(ledger_path())
	if text.is_empty():
		return []
	var read: Variant = JSON.parse_string(text)
	if not (read is Dictionary) or not ((read as Dictionary).get("moulds") is Array):
		return []
	var out: Array = []
	for one: Variant in (read as Dictionary)["moulds"]:
		if one is Dictionary and str((one as Dictionary).get("id", "")).begins_with("bw-"):
			out.append(one)
	return out


static func _keep(entries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ledger_path().get_base_dir())
	var file := FileAccess.open(ledger_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "moulds": entries}, "\t"))
	file.close()


static func _at(entries: Array, id: String, by: String) -> int:
	for n: int in entries.size():
		var one: Dictionary = entries[n]
		if str(one.get("id", "")) == id and str(one.get("by", "")) == by:
			return n
	return -1


## Who is signed in on [param account], as the ledger names them: "" for
## nobody.
static func _who(account: Account) -> String:
	return account.user_id if account != null and account.signed_in() else ""


## The mould [param id], saved for [param slot] with Save mould, written in
## the ledger as made by whoever is signed in on [param account] now.
## [param replaces] is the mould of theirs it was shaped from, or "".
static func made(id: String, slot: String, account: Account, replaces: String = "") -> void:
	var entries: Array = ledger()
	var by: String = _who(account)
	var n: int = _at(entries, id, by)
	if n < 0:
		entries.append({"id": id, "slot": slot, "by": by, "at": Time.get_datetime_string_from_system(true),
			"replaces": replaces, "sent": false})
	else:
		(entries[n] as Dictionary)["slot"] = slot
	# The one it was shaped from, not sent yet, is not sent now: this one is
	# what the person kept of it.
	if not replaces.is_empty():
		var was: int = _at(entries, replaces, by)
		if was >= 0 and not bool((entries[was] as Dictionary).get("sent", false)):
			(entries[was] as Dictionary)["superseded"] = true
	_keep(entries)


## The mould [param id], saved for [param slot], sent to [param account]:
## "" once it is kept there, or why not, in the app's words. Its ledger
## entry for that account says what came of it.
static func send(account: Account, id: String, slot: String, replaces: String = "") -> String:
	if account == null or not account.signed_in():
		return SIGNED_OUT
	var text: String = FileAccess.get_file_as_string(CustomParts.dir + id + ".dat")
	if text.is_empty():
		return NOT_HERE
	var token: String = await account.access_token()
	if token.is_empty():
		return SIGN_IN_AGAIN
	var asked: Dictionary = {"id": id, "slot": slot, "text": text}
	if not replaces.is_empty():
		asked["replaces"] = replaces
	sends += 1
	var reply: Dictionary = await account._fetch(Deployment.api_base() + "/api/people?op=mould",
		PackedStringArray(["content-type: application/json", "authorization: Bearer " + token]),
		HTTPClient.METHOD_POST, JSON.stringify(asked))
	var code: int = int(reply.get("code", 0))
	var said: Dictionary = reply.get("body") if reply.get("body") is Dictionary else {}
	var kind: String = str(said.get("code", ""))
	_answered(id, account.user_id, code, kind)
	if code == 200:
		return ""
	if code == 409 or kind == "room":
		return NO_ROOM
	if code == 413 or kind == "big":
		return TOO_BIG
	if code == 400:
		return NOT_A_MOULD
	if code == 429:
		return TOO_MANY
	if code == 503 and kind == "not_yet":
		return NOT_OPEN
	if code == 401 or code == 403:
		return SIGN_IN_AGAIN
	if code == 0:
		return UNREACHED
	return NOT_TAKEN % code


## What the account said of [param id], in its ledger entry for [param by]:
## kept, refused for good (what it is), refused for room, or nothing to
## keep (out of reach, signed out, too many at once: it goes again).
static func _answered(id: String, by: String, code: int, kind: String) -> void:
	var entries: Array = ledger()
	var n: int = _at(entries, id, by)
	if n < 0:
		return
	var one: Dictionary = entries[n]
	if code == 200:
		one["sent"] = true
		one.erase("refused")
	elif code in [400, 409, 413]:
		one["refused"] = {"status": code, "code": kind if not kind.is_empty() else ("room" if code == 409 else "shape")}
	else:
		return
	_keep(entries)


## Every mould [param account]'s person made here, signed in to it, that
## the account has not had yet, sent: once a run for each account, again
## when one did not get through. [param library] says what each mould was
## made for. The ids sent.
static func sweep(account: Account, library: PartLibrary) -> Array[String]:
	var sent: Array[String] = []
	if account == null or not account.signed_in() or account.user_id.is_empty() \
			or swept_for == account.user_id:
		return sent
	var who: String = account.user_id
	swept_for = who
	var waiting: Array = []
	for one: Dictionary in ledger():
		if str(one.get("by", "")) == who and not bool(one.get("sent", false)) \
				and not bool(one.get("superseded", false)) \
				and FileAccess.file_exists(CustomParts.dir + str(one.get("id", "")) + ".dat"):
			waiting.append(one)
	if waiting.is_empty():
		return sent
	var token: String = await account.access_token()
	if token.is_empty():
		swept_for = ""
		return sent
	var reply: Dictionary = await account._fetch(Deployment.api_base() + "/api/people?op=moulds",
		PackedStringArray(["authorization: Bearer " + token]), HTTPClient.METHOD_GET, "")
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) != 200 or not body is Dictionary \
			or not bool((body as Dictionary).get("ready", false)):
		# Not open yet, or out of reach: asked again next time.
		swept_for = ""
		return sent
	var there: Dictionary = {}
	var weight: int = 0
	for one: Variant in (body as Dictionary).get("moulds", []):
		if one is Dictionary:
			there[str((one as Dictionary).get("id", ""))] = true
			weight += int((one as Dictionary).get("bytes", 0))
	var most: Dictionary = (body as Dictionary).get("most", {}) if (body as Dictionary).get("most") is Dictionary else {}
	var room: int = int(most.get("moulds", 40)) - there.size()
	var room_bytes: int = int(most.get("bytes", 24 * 1024 * 1024)) - weight
	for one: Dictionary in waiting:
		var id: String = str(one.get("id", ""))
		if there.has(id):
			# Kept there already (sent from another tab, or its answer lost).
			_answered(id, who, 200, "")
			continue
		var refused: Dictionary = one.get("refused", {}) if one.get("refused") is Dictionary else {}
		var size: int = FileAccess.get_file_as_bytes(CustomParts.dir + id + ".dat").size()
		if not refused.is_empty():
			# Refused for what it is: never again. For room: once there is.
			if str(refused.get("code", "")) != "room" or room < 1 or size > room_bytes:
				continue
		var slot: String = str(one.get("slot", ""))
		if slot.is_empty() and library != null:
			slot = Minifig.slot_for(library.parts.get(id))
		if slot.is_empty():
			continue
		var why: String = await send(account, id, slot, str(one.get("replaces", "")))
		if why.is_empty():
			sent.append(id)
			room -= 1
			room_bytes -= size
		elif why in [UNREACHED, TOO_MANY, SIGN_IN_AGAIN] or why.begins_with("Brickworks could not take"):
			swept_for = ""
	return sent


## The moulds made here while nobody was signed in, still on this device
## and never sent, that [param account]'s person has not said are not
## theirs: what the builder asks them about.
static func unclaimed(account: Account) -> Array[String]:
	var found: Array[String] = []
	var who: String = _who(account)
	if who.is_empty():
		return found
	for one: Dictionary in ledger():
		var id: String = str(one.get("id", ""))
		if str(one.get("by", "")) == "" and not bool(one.get("sent", false)) \
				and not bool(one.get("superseded", false)) and not who in (one.get("declined", []) as Array) \
				and FileAccess.file_exists(CustomParts.dir + id + ".dat") and not found.has(id):
			found.append(id)
	return found


## [param ids], made signed out, said by [param account]'s person to be
## theirs: theirs in the ledger from now on, and sent. How many the
## account kept, and the first refusal's words ("" for none).
static func claim(account: Account, ids: Array[String]) -> Array:
	var who: String = _who(account)
	if who.is_empty():
		return [0, SIGNED_OUT]
	var entries: Array = ledger()
	var wanted: Array = []
	for one: Dictionary in entries:
		if str(one.get("by", "")) == "" and ids.has(str(one.get("id", ""))):
			one["by"] = who
			wanted.append(one)
	_keep(entries)
	var kept: int = 0
	var why: String = ""
	for one: Dictionary in wanted:
		var said: String = await send(account, str(one.get("id", "")), str(one.get("slot", "")),
			str(one.get("replaces", "")))
		if said.is_empty():
			kept += 1
		elif why.is_empty():
			why = said
	if not why.is_empty():
		swept_for = ""
	return [kept, why]


## [param ids], made signed out, said by [param account]'s person not to
## be theirs: never asked of that account again.
static func decline(account: Account, ids: Array[String]) -> void:
	var who: String = _who(account)
	if who.is_empty():
		return
	var entries: Array = ledger()
	for one: Dictionary in entries:
		if str(one.get("by", "")) == "" and ids.has(str(one.get("id", ""))):
			var declined: Array = one.get("declined", []) if one.get("declined") is Array else []
			if not who in declined:
				declined.append(who)
			one["declined"] = declined
	_keep(entries)


## The moulds kept on this device: each made part whose file says it was
## moulded here (or in somebody else's studio, for one a model brought).
## Not what is sent: that is the ledger's.
static func kept_moulds() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(CustomParts.dir):
		if not file_name.ends_with(".dat") or not file_name.begins_with("bw-") \
				or not file_name.contains("-m-"):
			continue
		var text: String = FileAccess.get_file_as_string(CustomParts.dir + file_name)
		if text.contains(PartPrints.MOULDED_BY):
			found.append(file_name.get_basename())
	return found
