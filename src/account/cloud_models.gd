## A signed-in person's saved models, kept with their account as well as in
## this browser or on this computer (api/models.js,
## supabase/account_models.sql; walk180's A4, 2026-10-23).
##
## On the web a saved model was in the site's storage in that browser and
## nowhere else: another device or browser had none of them, and a browser
## that cleared the site's storage took them. Mecabricks keeps every model
## with the account. Now, signed in, each save is sent to the account once
## it is made, and every browser and desktop app the person signs in to
## puts the account's models in File, Open, beside the ones it has. Its own
## copy is kept as it always was (ModelStore), so the app works as before
## offline and signed out; a save made then is sent at the next sign-in.
## The desktop app keeps its models in step the same way (lib219,
## 2026-10-24): a model saved in a browser is in its Open, and one saved in
## it is in every browser's.
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
##   one the account had and has no more,           deleted elsewhere:
##     unchanged here                                 deleted here too
##   one the account had and has no more,           kept: sent as new
##     changed here since
##   one deleted here                                deleted with the
##                                                    account, from the
##                                                    version it had
##
## Never a save lost to another. A save is sent with the version it was
## made from, and only a save of the version there replaces it; one made
## from an older version, in another browser or device, is kept beside it
## by the account under a name of its own ("Castle 2"). This browser's
## copy then takes that name too, the model on the baseplate with it, the
## account's model comes here under its own, and both are in Open.
## Nothing is fetched over a model changed here and not sent.
##
## Nor a save lost to a delete. A delete is sent with the version deleted,
## and the account deletes only that one: a newer save, from another
## browser, is kept and comes back here as a saved model. And a model
## changed here after another browser deleted it is sent again as new. A
## delete made offline or signed out is kept in the manifest of each
## account that had the model ("deleted") and sent at the next look, so a
## model deleted is never fetched back unasked. A rename is a delete of the
## old name and a save under the new; another browser with the old name
## open has it called the new one (its file, renamed, is the new one's).
##
## A model of another account signed in in this browser before is never
## sent to this one: what each account has had here is in its own manifest.
##
## Off for a run nobody is sitting at ([member keeps]). The one test
## account every browser flow signs in as is kept out by the deployment
## (api/models.js), which answers it as one without the table does: a list
## that says off.
class_name CloudModels
extends Node

const MANIFEST := "user://cloud/"
## How often to look again while signed in, and how soon after a return to
## the window: another device's save is here within this.
const EVERY := 300.0
const AGAIN_AFTER_MS := 20000
## Most a model fetched may come to, as api/models.js keeps them.
const MOST_RAW := 32 * 1024 * 1024
## How full the account is when Save says so: of its models, or of its bytes.
const NEAR := 0.9

var account: Account
var store: ModelStore
## Whether this run keeps the person's models with their account: off for a
## probe, a command-line run and a shared model's viewer, as Account.keeps.
var keeps: bool = true

## Something to tell the person, on the status bar.
signal said(text: String)
## The model called [param from] here is called [param to] now: a save of
## it made from an older version than the account's, kept beside that one;
## or a rename made elsewhere.
signal kept_as(from: String, to: String)
## The saved model called [param name] was deleted in another browser or on
## another device, and so here.
signal deleted_elsewhere(name: String)
## The account is full or nearly, said after a save: [param words] say
## how full, plainly, for an offer to delete old models (AccountFullOffer).
signal short_of_room(words: String)

## How the last look went: "" not yet, "off", "kept" (in step with the
## account), "away" (could not reach it), "not_here" (this deployment keeps
## no models: account_models.sql not applied).
var state: String = ""
## The models the account refused, by name, and why in words.
var refused: Dictionary = {}
## How much the account keeps, as its list last said: {models, bytes,
## most_models, most_bytes}, bytes left out by a deployment without
## account_models_delete.sql.
var room: Dictionary = {}
## Whether the models here are all kept with the account too, as the last
## look found: what StorageKeep says in Account and whether it warns.
static var keeping: bool = false

var _syncing: bool = false
var _again: bool = false
var _looked_at: int = -1000000
var _clock: Timer
## A save was made since the last look: that look says whether the account
## is near full ([signal short_of_room]).
var _saved: bool = false
## What the last look did, for a browser check: {sent, fetched, names,
## deleted}, names those of the account's models this browser has.
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
			_saved = true
			sync())
		store.removed_save.connect(func(name: String) -> void:
			_deleted_here(name)
			sync())
		# A rename is the old name deleted and the new one saved, as new.
		store.renamed_save.connect(func(from: String, _to: String) -> void:
			_deleted_here(from)
			sync())
		store.put_back_save.connect(func(name: String) -> void:
			_put_back_here(name)
			sync())
	_on_account()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) \
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
	if not keeps or account == null or store == null:
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
	# This deployment keeps no models for this account (api/models.js off).
	if (listed["body"] as Dictionary).get("off") is String:
		state = "not_here"
		keeping = false
		return
	var there: Dictionary = {}
	for one: Variant in (listed["body"] as Dictionary)["models"]:
		if one is Dictionary and fits(str((one as Dictionary).get("name", ""))):
			there[str(one["name"])] = one
	var kept: Variant = (listed["body"] as Dictionary).get("kept")
	room = kept if kept is Dictionary else {}
	var sent: int = 0
	var fetched: int = 0
	var gone: int = 0
	var trouble: bool = false
	var away: bool = false
	# Deleted here first: the account deletes each as it was, unless it was
	# saved since elsewhere, and then it comes back here below.
	var deleted: Dictionary = _manifest(_manifest_path()).get("deleted", {})
	for name: String in deleted:
		if not there.has(name):
			_undelete(_manifest_path(), name, false)
			continue
		var reply: Dictionary = await _ask("DELETE", "/api/models?name=%s&version=%d"
			% [name.uri_encode(), int((deleted[name] as Dictionary).get("v", 0))])
		var body: Variant = reply["body"]
		if int(reply["code"]) != 200 or not body is Dictionary:
			# Asked again at the next look; until then not fetched back.
			trouble = trouble or int(reply["code"]) != 503
			continue
		_undelete(_manifest_path(), name, false)
		if (body as Dictionary).has("kept"):
			said.emit(("“%s” was saved in another browser or on another device after it was "
				+ "deleted here, so that save is kept: it is in File › Open.") % name)
		else:
			there.erase(name)
	deleted = _manifest(_manifest_path()).get("deleted", {})
	var known: Dictionary = _known()
	# What is here: sent where it changed, fetched over where only the
	# account's changed, deleted where the account deleted it.
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
				away = got == AWAY
				if away:
					break
			continue
		if not had.is_empty() and theirs.is_empty():
			if str(had.get("sum", "")) == sum:
				gone += 1 if await _gone_elsewhere(name, there, known) else 0
				continue
			# Changed here since: kept, and sent as a model of its own.
			_forget(name)
			had = {}
			said.emit(("“%s” was deleted in another browser or on another device after it was "
				+ "changed here, so this one is kept, with your account too.") % name)
		if had.is_empty() and _claimed_elsewhere(name):
			continue
		var went: String = await _send(name, FileAccess.get_file_as_string(path),
			int(had.get("v", 0)) if not had.is_empty() else 0)
		sent += 1 if went == "kept" else 0
		trouble = trouble or went == "away"
		# Out of reach: the rest waits for the next look, not a request each.
		away = went == "away"
		if away:
			break
	# Then what only the account has, but for what was deleted here and has
	# not reached it yet.
	for name: String in there:
		if away:
			break
		if FileAccess.file_exists(_path(name)) or deleted.has(name):
			continue
		var got: int = await _fetch_model(name, "")
		fetched += maxi(got, 0)
		trouble = trouble or got < 0
		away = got == AWAY
	state = "away" if trouble else "kept"
	keeping = not trouble and refused.is_empty()
	last = {"sent": sent, "fetched": fetched, "deleted": gone, "names": _known().keys()}
	if fetched > 0:
		said.emit(("%d model from your account is in File › Open" if fetched == 1
			else "%d models from your account are in File › Open") % fetched)
	if _saved:
		_saved = false
		# How full the account is now, with what was just sent.
		if sent > 0:
			var now: Dictionary = await _ask("GET", "/api/models")
			if int(now["code"]) == 200 and now["body"] is Dictionary \
					and (now["body"] as Dictionary).get("kept") is Dictionary:
				room = (now["body"] as Dictionary)["kept"]
		var words: String = short_words()
		if not words.is_empty():
			short_of_room.emit(words)


## How full the account is, plainly, when it is full or nearly: "" when it
## has room. From its list, as the last look had it, and what it refused.
func short_words() -> String:
	if room.is_empty():
		return ""
	var models: int = int(room.get("models", 0))
	var most: int = int(room.get("most_models", 500))
	var bytes: float = float(room.get("bytes", 0))
	var most_bytes: float = float(room.get("most_bytes", 64 * 1024 * 1024))
	var refusal: String = ""
	for name: String in refused:
		if str(refused[name]).begins_with(FULL):
			refusal = str(refused[name]).trim_prefix(FULL)
	var full: bool = not refusal.is_empty() or models >= most or bytes >= most_bytes
	if not full and models < int(most * NEAR) and bytes < most_bytes * NEAR:
		return ""
	var by_bytes: bool = refusal == "too big" \
		or (refusal.is_empty() and models < int(most * NEAR))
	var which: String = ("%.1f MB of the %d MB of models it keeps" % [bytes / 1048576.0,
		int(most_bytes / 1048576.0)]) if by_bytes and room.has("bytes") \
		else ("the %d MB of models it keeps" % int(most_bytes / 1048576.0)) if by_bytes \
		else ("%d of the %d models it keeps" % [models, most])
	if full:
		return ("Your account is full: it has %s, so new saves are kept only %s. "
			+ "Delete models you no longer need to make room.") % [which, here()]
	return ("Your account is nearly full: it has %s. Delete models you no longer need, "
		+ "or new saves will be kept only %s.") % [which, here()]


## Where a model is kept when not with the account, in words.
static func here() -> String:
	return "in this browser" if OS.has_feature("web") else "on this computer"


## The model called [param name], unchanged here, was deleted with the
## account elsewhere: deleted here too, the model on the baseplate kept. A
## rename when the account has a model it had not that is this one called
## something else ([method ModelStore.retitled]): that one is fetched first,
## then the model on the baseplate takes its name, so it knows the file
## under it as fetched (ModelStore.know) and does not take it for a save
## made elsewhere. Whether it was deleted.
func _gone_elsewhere(name: String, there: Dictionary, known: Dictionary) -> bool:
	var path: String = _path(name)
	if not NewerBuild.may_write(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	var renamed: String = ""
	for other: String in there:
		if known.has(other) or FileAccess.file_exists(_path(other)):
			continue
		if ModelStore.retitled(text, other).sha256_text() == str((there[other] as Dictionary).get("sum", "")):
			renamed = other
			break
	if not renamed.is_empty() and await _fetch_model(renamed, "") != 1:
		return false
	if DirAccess.remove_absolute(path) != OK:
		return false
	_sums.erase(path)
	# Written: on the web, what makes the browser store the delete too.
	_forget(name)
	if not renamed.is_empty():
		var versions: String = ModelVersions.folder(name)
		if DirAccess.dir_exists_absolute(versions) and not DirAccess.dir_exists_absolute(ModelVersions.folder(renamed)):
			DirAccess.rename_absolute(versions, ModelVersions.folder(renamed))
		kept_as.emit(name, renamed)
		return true
	deleted_elsewhere.emit(name)
	return true


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


## What the account says when it is full (api/models.js), the start of
## what [member refused] holds for a model it would not keep for that.
const FULL := "full: "


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
		var full: String = str((body as Dictionary).get("full", "")) if body is Dictionary else ""
		if not full.is_empty():
			why = FULL + full
			if str(refused.get(name, "")) != why:
				_saved = true
		elif str(refused.get(name, "")) != why:
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
	# copy takes the name it is kept under, in its file too, so it opens and
	# saves under that one (sent again so at the next look), and the
	# account's comes here as it is there.
	var path: String = _path(kept)
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).sha256_text() != sum:
		return "kept"
	if not _write(path, ModelStore.retitled(text, kept)):
		return "away"
	_record(kept, version, sum)
	_again = true
	kept_as.emit(name, kept)
	var mine: String = _path(name)
	if FileAccess.get_file_as_string(mine).sha256_text() == sum:
		_forget(name)
		await _fetch_model(name, sum)
	said.emit("“%s” was saved in another browser or on another device too, so this one is kept "
		% name + "as “%s”: both are in File › Open." % kept)
	return "kept"


## What [method _fetch_model] answers when the account could not be reached.
const AWAY := -2


## Fetch the account's model called [param name] here, over the file of that
## name only while it is still [param was] (its sum, "" for none): how many
## were fetched, 0 or 1; -1 when it could not be, and [constant AWAY] when
## nothing answered.
func _fetch_model(name: String, was: String) -> int:
	var reply: Dictionary = await _ask("GET", "/api/models?name=" + name.uri_encode())
	var body: Variant = reply["body"]
	if int(reply["code"]) == 0:
		return AWAY
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
	# Or deleted here meanwhile, in another tab: not brought back.
	var now: String = FileAccess.get_file_as_string(path).sha256_text() \
		if FileAccess.file_exists(path) else ""
	if now != was:
		_again = true
		return 0
	if (_manifest(_manifest_path())["deleted"] as Dictionary).has(name):
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


## A manifest as kept: {models: name -> {v, sum}, what this browser last
## had of each of the account's models; deleted: name -> {v, sum}, those
## deleted here and not yet with the account}. Read from the file each
## time, since every tab keeps it.
static func _manifest(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var out: Dictionary = {"models": {}, "deleted": {}}
	if parsed is Dictionary:
		for part: String in out:
			if (parsed as Dictionary).get(part) is Dictionary:
				out[part] = (parsed as Dictionary)[part]
	return out


func _known() -> Dictionary:
	return _manifest(_manifest_path())["models"]


func _record(name: String, version: int, sum: String) -> void:
	var manifest: Dictionary = _manifest(_manifest_path())
	var had: Dictionary = (manifest["models"] as Dictionary).get(name, {})
	if int(had.get("v", -1)) == version and str(had.get("sum", "")) == sum:
		return
	manifest["models"][name] = {"v": version, "sum": sum}
	_keep_manifest(_manifest_path(), manifest)


func _forget(name: String) -> void:
	var manifest: Dictionary = _manifest(_manifest_path())
	if (manifest["models"] as Dictionary).erase(name):
		_keep_manifest(_manifest_path(), manifest)


func _keep_manifest(path: String, manifest: Dictionary) -> void:
	_write(path, JSON.stringify(manifest))


func _manifest_path() -> String:
	return MANIFEST + account.user_id + ".json"


## Every account's manifest kept here: a model deleted signed out is
## deleted from whichever account had it, at its next sign-in.
static func _manifests() -> PackedStringArray:
	var out := PackedStringArray()
	if DirAccess.dir_exists_absolute(MANIFEST):
		for file: String in DirAccess.get_files_at(MANIFEST):
			if file.ends_with(".json"):
				out.append(MANIFEST + file)
	return out


## The person deleted the model called [param name] here: each account that
## had it is to delete it too, from the version it had.
func _deleted_here(name: String) -> void:
	_sums.erase(_path(name))
	for path: String in _manifests():
		var manifest: Dictionary = _manifest(path)
		if (manifest["models"] as Dictionary).has(name):
			manifest["deleted"][name] = manifest["models"][name]
			(manifest["models"] as Dictionary).erase(name)
			_keep_manifest(path, manifest)


## The model called [param name] is back (Undo): not to be deleted with an
## account it has not reached yet, and had from it as before.
func _put_back_here(name: String) -> void:
	for path: String in _manifests():
		_undelete(path, name, true)


## No longer to be deleted with the account of the manifest at [param path]:
## [param had] puts it back among the models had from it.
func _undelete(path: String, name: String, had: bool) -> void:
	var manifest: Dictionary = _manifest(path)
	if not (manifest["deleted"] as Dictionary).has(name):
		return
	if had:
		manifest["models"][name] = manifest["deleted"][name]
	(manifest["deleted"] as Dictionary).erase(name)
	_keep_manifest(path, manifest)


## Whether another account signed in here has had [param name] from its own
## models: then it is that account's, and never sent to this one.
func _claimed_elsewhere(name: String) -> bool:
	for path: String in _manifests():
		if path != _manifest_path() and (_manifest(path)["models"] as Dictionary).has(name):
			return true
	return false


## What a browser check reads (Main's page state).
func page_state() -> Dictionary:
	return {"state": state, "keeping": keeping, "refused": refused, "last": last,
		"syncing": _syncing, "room": room, "short": short_words()}


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
	var how: int = {"POST": HTTPClient.METHOD_POST, "DELETE": HTTPClient.METHOD_DELETE}.get(
		method, HTTPClient.METHOD_GET)
	if http.request(Deployment.api_base() + route, headers, how, body) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}
