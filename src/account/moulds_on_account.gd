## Your own moulds on your account (sitehair, 2026-11-25; owner ask #14).
##
## A mould saved in the minifig builder ([MouldEditor]) is kept on this
## device ([CustomParts]) and in each model that uses it. Signed in, a copy
## goes to the account the moment it is saved (POST /api/people?op=mould,
## api/_moulds.js, supabase/own_moulds.sql), so the site's own minifig maker
## (Edit profile, web/minifig-maker.js) lists it beside the catalogue's hair
## and the person's avatar can wear it, with no second step. A mould made
## while signed out or out of reach goes the next time the builder opens
## signed in ([method sweep]): the account's list is asked once, and what it
## lacks is sent.
##
## The text sent is the part's own file, as it is kept; the deployment holds
## it to what a mould is before anything is kept, and says why in words when
## it will not keep one, which the builder shows.
class_name MouldsOnAccount
extends RefCounted

## Said in the builder once the account has the mould.
const KEPT := "Kept on your account too: wear it in the site's minifig maker (Edit profile)."
## Said when the account would not keep it: the deployment's words after.
const NOT_KEPT := "Kept in the studio only: %s"

## The account a sweep was made for this run, so one is made once.
static var swept_for: String = ""


## The mould [param id], saved for [param slot], sent to [param account]:
## "" once it is kept there, or why not, in words. Nothing is sent for
## nobody signed in.
static func send(account: Account, id: String, slot: String) -> String:
	if account == null or not account.signed_in():
		return "sign in to keep it on your account"
	var text: String = FileAccess.get_file_as_string(CustomParts.dir + id + ".dat")
	if text.is_empty():
		return "it is not kept on this device"
	var token: String = await account.access_token()
	if token.is_empty():
		return "sign in again to keep it on your account"
	var reply: Dictionary = await account._fetch(Deployment.api_base() + "/api/people?op=mould",
		PackedStringArray(["content-type: application/json", "authorization: Bearer " + token]),
		HTTPClient.METHOD_POST, JSON.stringify({"id": id, "slot": slot, "text": text}))
	var code: int = int(reply.get("code", 0))
	var said: Variant = reply.get("body")
	if code == 200:
		return ""
	if said is Dictionary and (said as Dictionary).has("error"):
		return str((said as Dictionary)["error"])
	if code == 0:
		return "Brickworks could not be reached"
	return "Brickworks could not take it just now (%d)" % code


## Every mould kept on this device and not on the account, sent: once a
## run for each account. [param library] says what each mould was made
## for. The ids sent.
static func sweep(account: Account, library: PartLibrary) -> Array[String]:
	var sent: Array[String] = []
	if account == null or not account.signed_in() or account.user_id.is_empty() \
			or swept_for == account.user_id:
		return sent
	swept_for = account.user_id
	var token: String = await account.access_token()
	if token.is_empty():
		swept_for = ""
		return sent
	var reply: Dictionary = await account._fetch(Deployment.api_base() + "/api/people?op=moulds",
		PackedStringArray(["authorization: Bearer " + token]), HTTPClient.METHOD_GET, "")
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) != 200 or not body is Dictionary \
			or not bool((body as Dictionary).get("ready", false)):
		# Not open yet, or out of reach: asked again next run.
		swept_for = ""
		return sent
	var there: Dictionary = {}
	for one: Variant in (body as Dictionary).get("moulds", []):
		if one is Dictionary:
			there[str((one as Dictionary).get("id", ""))] = true
	for id: String in kept_moulds():
		if there.has(id):
			continue
		var slot: String = Minifig.slot_for(library.parts.get(id)) if library != null else ""
		if slot.is_empty():
			continue
		if (await send(account, id, slot)).is_empty():
			sent.append(id)
	return sent


## The moulds kept on this device: each made part whose file says it was
## moulded here.
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
