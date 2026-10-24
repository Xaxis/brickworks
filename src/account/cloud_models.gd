## A signed-in person's saved models, kept with their account as well as in
## this browser (api/models.js, supabase/account_models.sql; walk180's A4,
## 2026-10-23).
##
## On the web a saved model was in the site's storage in that browser and
## nowhere else: another device or browser had none of them, and a browser
## that cleared the site's storage took them. Mecabricks keeps every model
## with the account. Now, signed in, each save is sent to the account once
## it is made, and every browser the person signs in to puts the account's
## models in File, Open, beside the ones it has. The browser's own copy is
## kept as it always was (ModelStore), so the app works as before offline
## and signed out; a save made then is sent at the next sign-in.
##
## In step ([method sync]): asked as somebody signs in, after each save,
## when the window is come back to, and every few minutes. The account's
## list says each model's version and the sum of its file, and what this
## browser last had of each from the account is kept beside its models
## (user://cloud/<account>.json, MANIFEST), so:
##
##   a model here that the account has as it is      nothing to do
##   one here changed since the account had it      sent, from that version
##   one the account has newer, unchanged here      fetched over it
##   one only the account has                       fetched
##   one here the account never had                 sent, as new
##
## Never a save lost to another. A save is sent with the version it was
## made from, and only a save of the version there replaces it; one made
## from an older version, in another browser or device, is kept beside it
## by the account under a name of its own ("Castle 2"). This browser's
## copy then takes that name too, the model on the baseplate with it, the
## account's model comes here under its own, and both are in Open.
## Nothing is fetched over a model changed here and not sent.
##
## A model of another account signed in in this browser before is never
## sent to this one: what each account has had here is in its own manifest.
##
## Web only: on the desktop the models are files on the computer, as
## Studio's are. Off for a run nobody is sitting at ([member keeps]). The
## one test account every browser flow signs in as is kept out by the
## deployment (api/models.js), which answers it as one without the table.
class_name CloudModels
extends Node

const MANIFEST := "user://cloud/"
## How often to look again while signed in, and how soon after a return to
## the window: another device's save is here within this.
const EVERY := 300.0
const AGAIN_AFTER_MS := 20000
## Most a model fetched may come to, as api/models.js keeps them.
const MOST_RAW := 32 * 1024 * 1024

var account: Account
var store: ModelStore
## Whether this run keeps the person's models with their account: off for a
## probe, a command-line run and a shared model's viewer, as Account.keeps.
var keeps: bool = true

## Something to tell the person, on the status bar.
signal said(text: String)
## The model called [param from] here is called [param to] now: a save of
## it made from an older version than the account's, kept beside that one.
signal kept_as(from: String, to: String)

## How the last look went: "" not yet, "off", "kept" (in step with the
## account), "away" (could not reach it), "not_here" (this deployment keeps
## no models: account_models.sql not applied).
var state: String = ""
## The models the account refused, by name, and why in words.
var refused: Dictionary = {}
## Whether the models here are all kept with the account too, as the last
## look found: what StorageKeep says in Account and whether it warns.
static var keeping: bool = false

var _syncing: bool = false
var _again: bool = false
var _looked_at: int = -1000000
var _clock: Timer
## What the last look did, for a browser check: {sent, fetched, names},
## names those of the account's models this browser has.
var last: Dictionary = {}
## Each saved model's sum as last read, by path: [modified, size, sum]. A
## look reads only the files changed since; a person with a hundred models
## hashed them all every few minutes.
var _sums: Dictionary = {}


func _ready() -> void:
	_clock = Timer.new()
	_clock.wait_time = EVERY
	_clock.autostart = true
	_clock.timeout.connect(sync)
	add_child(_clock)
	if account != null:
		account.changed.connect(_on_account)
	if store != null:
		store.kept_save.connect(func(path: String) -> void:
			_sums.erase(path)
			sync())
	_on_account()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN \
			and Time.get_ticks_msec() - _looked_at > AGAIN_AFTER_MS:
		sync()


func _on_account() -> void:
	if not _on():
		keeping = false
		if account != null and account.state != Account.State.CHECKING:
			state = "off"
		return
	if state != "kept" and state != "":
		state = ""
	sync()


## Whether models are kept with the account here and now.
func _on() -> bool:
	if not keeps or account == null or store == null or not OS.has_feature("web"):
		return false
	return account.signed_in() and not account.offline and not account.user_id.is_empty()


## Bring this browser's models and the account's into step. Safe to call at
## any time: a call while one is going makes it look again when it ends.
func sync() -> void:
	if not _on():
		return
	if _syncing:
		_again = true
		return
	_syncing = true
	while true:
		_again = false
		_looked_at = Time.get_ticks_msec()
		await _sync_once()
		if not _again or not _on():
			break
	_syncing = false


func _sync_once() -> void:
	var listed: Dictionary = await _ask("GET", "/api/models")
	if int(listed["code"]) != 200 or not listed["body"] is Dictionary \
			or not (listed["body"] as Dictionary).get("models") is Array:
		state = "not_here" if int(listed["code"]) == 503 else "away"
		keeping = false
		return
	var there: Dictionary = {}
	for one: Variant in (listed["body"] as Dictionary)["models"]:
		if one is Dictionary and fits(str((one as Dictionary).get("name", ""))):
			there[str(one["name"])] = one
	var sent: int = 0
	var fetched: int = 0
	var trouble: bool = false
	var known: Dictionary = _known()
	# What is here first: sent where it changed, fetched over where only the
	# account's changed.
	for name: String in _local_names():
		var path: String = _path(name)
		var sum: String = _sum_of(path)
		var had: Dictionary = known.get(name, {})
		var theirs: Dictionary = there.get(name, {})
		if not theirs.is_empty() and str(theirs.get("sum", "")) == sum:
			_record(name, int(theirs["version"]), sum)
			continue
		if not had.is_empty() and str(had.get("sum", "")) == sum and not theirs.is_empty():
			if int(theirs["version"]) > int(had.get("v", 0)):
				var got: int = await _fetch_model(name, sum)
				fetched += maxi(got, 0)
				trouble = trouble or got < 0
			continue
		if had.is_empty() and _claimed_elsewhere(name):
			continue
		var went: String = await _send(name, FileAccess.get_file_as_string(path),
			int(had.get("v", 0)) if not had.is_empty() else 0)
		sent += 1 if went == "kept" else 0
		trouble = trouble or went == "away"
	# Then what only the account has.
	for name: String in there:
		if FileAccess.file_exists(_path(name)):
			continue
		var got: int = await _fetch_model(name, "")
		fetched += maxi(got, 0)
		trouble = trouble or got < 0
	state = "away" if trouble else "kept"
	keeping = not trouble and refused.is_empty()
	last = {"sent": sent, "fetched": fetched, "names": _known().keys()}
	if fetched > 0:
		said.emit(("%d model from your account is in File › Open" if fetched == 1
			else "%d models from your account are in File › Open") % fetched)


## The sum of the file at [param path], read again only when it changed.
func _sum_of(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var stamp: Array = [FileAccess.get_modified_time(path), file.get_length()]
	var had: Array = _sums.get(path, [])
	if had.size() == 3 and had[0] == stamp[0] and had[1] == stamp[1]:
		return str(had[2])
	var sum: String = file.get_as_text().sha256_text()
	_sums[path] = [stamp[0], stamp[1], sum]
	return sum


## A saved model's file, by its name: as the file is called, and not
## ModelStore.saved_path, which a name a session gave (save_model's
## "tug.v2.ldr") does not come back from.
static func _path(name: String) -> String:
	return ModelStore.SAVE_DIR + name + ".ldr"


## Whether [param name] can be a saved model's file here, as api/models.js
## takes one: one line of 1 to 60 characters, none a file name may not have.
static func fits(name: String) -> bool:
	if name.is_empty() or name.length() > 60 or name != name.strip_edges() or name in [".", ".."]:
		return false
	for character: String in name:
		if character in "/\\:*?\"<>|" or character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	return true


## This browser's saved models, by name.
func _local_names() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(ModelStore.SAVE_DIR):
		return out
	for file: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		if file.ends_with(".ldr") and fits(file.get_basename()):
			out.append(file.get_basename())
	return out


## Send the model called [param name], made from [param base]: "kept" when
## the account keeps it, "refused" when it will not (too big, or the
## account full: said, and in [member refused]), "away" when it could not be
## asked.
func _send(name: String, text: String, base: int) -> String:
	var zipped: PackedByteArray = text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var reply: Dictionary = await _ask("POST", "/api/models", JSON.stringify({
		"name": name, "base": base, "model": Marshalls.raw_to_base64(zipped)}))
	var body: Variant = reply["body"]
	if int(reply["code"]) == 413 or int(reply["code"]) == 422:
		var why: String = str((body as Dictionary).get("error", "")) if body is Dictionary else ""
		if str(refused.get(name, "")) != why:
			said.emit("“%s” is not kept with your account: %s" % [name, why])
		refused[name] = why
		return "refused"
	if int(reply["code"]) != 200 or not body is Dictionary:
		return "away"
	refused.erase(name)
	var kept: String = str((body as Dictionary).get("name", name))
	var version: int = int((body as Dictionary).get("version", 1))
	var sum: String = text.sha256_text()
	if kept == name or not fits(kept):
		_record(name, version, sum)
		return "kept"
	# Made from an older version than the account's, and kept beside it: this
	# copy takes the name it is kept under, and the account's comes here as
	# it is there.
	var path: String = _path(kept)
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).sha256_text() != sum:
		return "kept"
	if not _write(path, text):
		return "away"
	_record(kept, version, sum)
	kept_as.emit(name, kept)
	var mine: String = _path(name)
	if FileAccess.get_file_as_string(mine).sha256_text() == sum:
		_forget(name)
		await _fetch_model(name, sum)
	said.emit("“%s” was saved in another browser or on another device too, so this one is kept "
		% name + "as “%s”: both are in File › Open." % kept)
	return "kept"


## Fetch the account's model called [param name] here, over the file of that
## name only while it is still [param was] (its sum, "" for none): how many
## were fetched, 0 or 1, and -1 when it could not be.
func _fetch_model(name: String, was: String) -> int:
	var reply: Dictionary = await _ask("GET", "/api/models?name=" + name.uri_encode())
	var body: Variant = reply["body"]
	if int(reply["code"]) != 200 or not body is Dictionary:
		return -1
	var zipped: PackedByteArray = Marshalls.base64_to_raw(str((body as Dictionary).get("model", "")))
	var text: String = zipped.decompress_dynamic(MOST_RAW, FileAccess.COMPRESSION_GZIP) \
		.get_string_from_utf8()
	var sum: String = str((body as Dictionary).get("sum", ""))
	if text.is_empty() or text.sha256_text() != sum:
		return -1
	var path: String = _path(name)
	# Changed here while it was on its way: kept, and sent at the next look.
	var now: String = FileAccess.get_file_as_string(path).sha256_text() \
		if FileAccess.file_exists(path) else ""
	if now != was:
		_again = true
		return 0
	if not _write(path, text):
		return -1
	# Kept as a version too, as a save is (File, Versions…).
	var version: String = ModelVersions.keep(name, text)
	if not version.is_empty():
		ModelStore._tell_page_wrote(version, FileAccess.get_file_as_bytes(version).size())
	_record(name, int((body as Dictionary).get("version", 1)), sum)
	return 1


func _write(path: String, text: String) -> bool:
	# A newer build is live: this tab writes nothing the tabs share (NewerBuild).
	if not NewerBuild.may_write(path):
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	ModelStore._tell_page_wrote(path, text.to_utf8_buffer().size())
	return true


## What this browser last had of each of the account's models: name ->
## {v, sum}. Read from the file each time, since every tab keeps it.
func _known() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(_manifest_path()) \
		if FileAccess.file_exists(_manifest_path()) else ""
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var models: Variant = (parsed as Dictionary).get("models") if parsed is Dictionary else null
	return models if models is Dictionary else {}


func _record(name: String, version: int, sum: String) -> void:
	var known: Dictionary = _known()
	var had: Dictionary = known.get(name, {})
	if int(had.get("v", -1)) == version and str(had.get("sum", "")) == sum:
		return
	known[name] = {"v": version, "sum": sum}
	_keep_known(known)


func _forget(name: String) -> void:
	var known: Dictionary = _known()
	if known.erase(name):
		_keep_known(known)


func _keep_known(known: Dictionary) -> void:
	_write(_manifest_path(), JSON.stringify({"models": known}))


func _manifest_path() -> String:
	return MANIFEST + account.user_id + ".json"


## Whether another account signed in here has had [param name] from its own
## models: then it is that account's, and never sent to this one.
func _claimed_elsewhere(name: String) -> bool:
	if not DirAccess.dir_exists_absolute(MANIFEST):
		return false
	for file: String in DirAccess.get_files_at(MANIFEST):
		if not file.ends_with(".json") or file == account.user_id + ".json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST + file))
		if parsed is Dictionary and (parsed as Dictionary).get("models") is Dictionary \
				and ((parsed as Dictionary)["models"] as Dictionary).has(name):
			return true
	return false


## What a browser check reads (Main's page state).
func page_state() -> Dictionary:
	return {"state": state, "keeping": keeping, "refused": refused, "last": last,
		"syncing": _syncing}


## One request as the person: {code, body}, code 0 when nothing came back.
func _ask(method: String, route: String, body: String = "") -> Dictionary:
	var token: String = await account.access_token()
	if token.is_empty():
		return {"code": 401, "body": null}
	var http := HTTPRequest.new()
	http.timeout = 60.0
	http.body_size_limit = 8 * 1024 * 1024
	add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + token])
	if method == "POST":
		headers.append("content-type: application/json")
	if http.request(Deployment.api_base() + route, headers,
			HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, body) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}
