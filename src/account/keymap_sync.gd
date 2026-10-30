## The keys (Keymap) with the account: a person who sets their keys on one
## computer has them in a new browser once they sign in there (APP_UX A11).
##
## The account keeps the preset, the keys set over it and when they were
## set (GET and POST /api/account?op=keys, supabase/keymap.sql). Signed in,
## the newer of the account's and this device's wins: the account's taken
## here, or this device's sent there. Each change made here is sent. Not
## signed in, or the account out of reach, the keys are this device's
## alone, as they always are (ShellPrefs).
class_name KeymapSync
extends Node

var account: Account
## Told when the account's keys were taken here: the strip, the toolbar
## and the sheet say them (Main).
signal taken

## Whose keys were last compared, so a sign-in compares once.
var _compared_for: String = ""


## The account signed in, or another: compare once for each.
func account_changed() -> void:
	if account == null or not account.signed_in() or account.user_id.is_empty():
		_compared_for = ""
		return
	if _compared_for == account.user_id:
		return
	_compared_for = account.user_id
	await compare()


## The newer keys win: the account's taken here, or this device's sent.
func compare() -> void:
	var token: String = await account.access_token()
	if token.is_empty():
		return
	var reply: Dictionary = await account._fetch(Deployment.api_base() + "/api/account?op=keys",
		PackedStringArray(["authorization: Bearer " + token]), HTTPClient.METHOD_GET, "")
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) != 200 or not body is Dictionary \
			or not bool((body as Dictionary).get("ready", false)):
		return
	var theirs: Variant = (body as Dictionary).get("keys")
	var here: float = float(ShellPrefs.value("keys_at"))
	if theirs is Dictionary and float((theirs as Dictionary).get("at", 0.0)) > here:
		if Keymap.take(theirs):
			taken.emit()
	elif here > 0.0:
		await send()


## This device's keys, to the account: after each change made here.
func send() -> void:
	if account == null or not account.signed_in():
		return
	var token: String = await account.access_token()
	if token.is_empty():
		return
	await account._fetch(Deployment.api_base() + "/api/account?op=keys",
		PackedStringArray(["content-type: application/json", "authorization: Bearer " + token]),
		HTTPClient.METHOD_POST, JSON.stringify(Keymap.kept()))
