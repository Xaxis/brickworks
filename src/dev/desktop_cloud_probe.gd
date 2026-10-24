## The desktop app's saved models kept in step with the account, as a
## browser's are (CloudModels, lib219, 2026-10-24).
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8891 &
##   BRICKWORKS_API=http://127.0.0.1:8891 \
##     godot --headless --path . --script src/dev/desktop_cloud_probe.gd
##
## The desktop kept its models on the computer alone: one saved in a
## browser never reached it, nor one saved on it a browser. This is the
## desktop's side, through api/models.js as it ships and the real
## database: a throwaway account at a Resend test address, signed in by
## its password (no code to redeem), and deleted at the end with its
## models. "A browser" is this probe asking the same routes as the account,
## as a browser's app does.
##
##   1. a save on the desktop reaches the account
##   2. a model saved in a browser reaches the desktop
##   3. both change one model from the same version, the desktop offline:
##      both kept, the desktop's as "Name 2", which opens under that name
##   4. deleted on the desktop, online and offline: gone from the account,
##      and the one deleted offline is not fetched back
##   5. deleted in a browser: gone from the desktop
##   6. deleted in a browser while the desktop changed it: the change kept
##   7. renamed on the desktop, and in a browser: the new name everywhere,
##      the old one nowhere, the model open on the desktop called the new
##   8. a delete undone: back with the account
##
## On a build from before 2026-10-24 the desktop sends nothing (CloudModels
## was web only): 1 fails, and 2 finds nothing; and there is no delete or
## rename to call. Not in the suite: it needs the relay and the project's
## keys (tools/suite/out.txt).
extends SceneTree

var _failures: int = 0
var _account: Account
var _cloud: CloudModels
var _store: ModelStore
var _api: String = ""
var _renamed: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Account.where = "user://probe_session.json"
	Account._clear()
	_api = Deployment.api_base()
	if OS.has_feature("web") or not _api.begins_with("http://127.0.0.1"):
		print("desktop_cloud probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % _api)
		quit(1)
		return
	var deployment := Deployment.new()
	get_root().add_child(deployment)
	_account = Account.new()
	_account.deployment = deployment
	get_root().add_child(_account)
	while _account.state == Account.State.CHECKING:
		await _account.changed
	var email: String = SignInHelper.throwaway("desk")
	var problem: String = await _sign_in(email)
	_check("signed in on the desktop as a throwaway account: %s" % (problem if not problem.is_empty() else email),
		problem.is_empty() and _account.signed_in())
	if not _account.signed_in():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	_store = ModelStore.new()
	_cloud = CloudModels.new()
	_cloud.account = _account
	_cloud.store = _store
	# As Main takes a new name for the model on the baseplate (_called_now).
	_cloud.kept_as.connect(func(from: String, to: String) -> void:
		_renamed.append([from, to])
		if _store.title == from:
			_store.title = to
			_store.know(_path(to)))
	get_root().add_child(_cloud)
	await _settled()
	_check("CloudModels is on, off the web: %s" % _cloud.state, _cloud.state == "kept")
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(email, get_root())
	_check("the throwaway account deleted, its models with it: %d" % gone, gone == 1)
	print("\ndesktop_cloud probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	var house: String = FileAccess.get_file_as_string("res://models/house.ldr")
	var desk: String = _titled(house, "Desk House")

	print("\n1. a save on the desktop")
	_save("Desk House", desk)
	await _settled()
	var had: Dictionary = _listed(await _list(), "Desk House")
	_check("the account lists “Desk House”, version %d, its sum the file’s" % int(had.get("version", 0)),
		int(had.get("version", 0)) == 1 and str(had.get("sum", "")) == desk.sha256_text())

	print("\n2. a model saved in a browser")
	var barn: String = _titled(house.replace("1 2 60 -8 -60", "1 4 60 -8 -60"), "Web Barn")
	var browser: Dictionary = await _browser_save("Web Barn", barn, 0)
	_check("a browser saves “Web Barn”: version %d" % int(browser.get("version", 0)),
		int(browser.get("version", 0)) == 1)
	await _look()
	_check("...and it is on the desktop, whole, in Open",
		FileAccess.get_file_as_string(_path("Web Barn")) == barn
		and _store.list_saved().any(func(e: ModelStore.Entry) -> bool: return e.name == "Web Barn"))

	print("\n3. both change “Desk House” from version 1, the desktop offline")
	var theirs: String = desk.replace("1 2 180 -8 -60", "1 1 180 -8 -60")
	browser = await _browser_save("Desk House", theirs, 1)
	_check("the browser’s save is version %d" % int(browser.get("version", 0)), int(browser.get("version", 0)) == 2)
	_offline(true)
	var mine: String = desk.replace("1 2 60 -8 -180", "1 14 60 -8 -180")
	_save("Desk House", mine)
	await _settled()
	_check("saved offline: on the desktop all the same, the app knowing the account has not got it (%s)"
		% _cloud.state, FileAccess.get_file_as_string(_path("Desk House")) == mine and _cloud.state == "away")
	_offline(false)
	await _look()
	var models: Array = await _list()
	_check("back online, both kept: “Desk House” the browser's, “Desk House 2” the desktop's",
		str(_listed(models, "Desk House").get("sum", "")) == theirs.sha256_text()
		and not _listed(models, "Desk House 2").is_empty())
	_check("...the desktop has the browser's under “Desk House”",
		FileAccess.get_file_as_string(_path("Desk House")) == theirs)
	var second: String = FileAccess.get_file_as_string(_path("Desk House 2"))
	_check("...and its own under “Desk House 2”, which opens under that name (“%s”)"
		% ModelStore.title_in(second, "Desk House 2"),
		ModelStore._brick_lines(second) == ModelStore._brick_lines(mine)
		and ModelStore.title_in(second, "") == "Desk House 2")
	await _look()
	_check("...and the account has it so too, sent again under its name",
		str(_listed(await _list(), "Desk House 2").get("sum", "")) == second.sha256_text())

	print("\n4. deleted on the desktop")
	_check("“Web Barn” deleted, kept for Undo", not _do("delete_saved", ["Web Barn"]).is_empty()
		and not FileAccess.file_exists(_path("Web Barn")))
	await _settled()
	_check("...and gone from the account", _listed(await _list(), "Web Barn").is_empty())
	_offline(true)
	var undo: String = _do("delete_saved", ["Desk House 2"])
	await _settled()
	_check("“Desk House 2” deleted offline: still with the account until the desktop is back",
		not undo.is_empty() and not _listed(await _list(), "Desk House 2").is_empty())
	_offline(false)
	await _look()
	_check("...then gone from it, and not fetched back here",
		_listed(await _list(), "Desk House 2").is_empty() and not FileAccess.file_exists(_path("Desk House 2")))

	print("\n5. deleted in a browser")
	var version: int = int(_listed(await _list(), "Desk House").get("version", 0))
	var deleted: Dictionary = await _browser_delete("Desk House", version)
	_check("a browser deletes “Desk House” (version %d): %s" % [version, JSON.stringify(deleted)],
		bool(deleted.get("deleted", false)))
	await _look()
	_check("...and it is gone from the desktop: %s" % JSON.stringify(_cloud.last),
		not FileAccess.file_exists(_path("Desk House")) and int(_cloud.last.get("deleted", 0)) == 1)

	print("\n6. deleted in a browser while the desktop changed it")
	var edit: String = _titled(house, "Edit Me")
	_save("Edit Me", edit)
	await _settled()
	_offline(true)
	var edited: String = edit.replace("1 2 60 -8 -60", "1 15 60 -8 -60")
	_save("Edit Me", edited)
	await _settled()
	deleted = await _browser_delete("Edit Me", 1)
	_check("the desktop changes “Edit Me” offline, and a browser deletes it: %s" % JSON.stringify(deleted),
		bool(deleted.get("deleted", false)))
	_offline(false)
	await _look()
	_check("...the desktop's change is kept: with the account again, and here",
		str(_listed(await _list(), "Edit Me").get("sum", "")) == edited.sha256_text()
		and FileAccess.get_file_as_string(_path("Edit Me")) == edited)

	print("\n7. renamed")
	var why: String = _do("rename_saved", ["Edit Me", "Edited"])
	await _settled()
	models = await _list()
	_check("“Edit Me” renamed “Edited” on the desktop%s: the account has “Edited”, not “Edit Me”"
		% ("" if why.is_empty() else " (%s)" % why),
		why.is_empty() and not _listed(models, "Edited").is_empty() and _listed(models, "Edit Me").is_empty())
	_check("...the name in its file too (“%s”)" % ModelStore.title_in(FileAccess.get_file_as_string(_path("Edited")), ""),
		ModelStore.title_in(FileAccess.get_file_as_string(_path("Edited")), "") == "Edited")
	# A browser renames it again, as the app does: the old name deleted and
	# the model saved under the new, called that in its file.
	var text: String = FileAccess.get_file_as_string(_path("Edited"))
	browser = await _browser_save("Final", _titled(text, "Final"), 0)
	deleted = await _browser_delete("Edited", int(_listed(models, "Edited").get("version", 1)))
	_renamed.clear()
	_store.title = "Edited"
	_store.know(_path("Edited"))
	await _look()
	_check("a browser renames it “Final”: here “Final”, no “Edited”",
		FileAccess.file_exists(_path("Final")) and not FileAccess.file_exists(_path("Edited")))
	_check("...known for a rename, so the model open here takes the name: %s" % str(_renamed),
		_renamed.has(["Edited", "Final"]) and _store.title == "Final")
	_check("...and knows its file as fetched, not as a save made elsewhere to reload",
		not _store.saved_elsewhere())

	print("\n8. a delete undone")
	var kept: String = _do("delete_saved", ["Final"])
	await _settled()
	_check("“Final” deleted: gone from the account", _listed(await _list(), "Final").is_empty())
	var back: String = _do("put_back", [kept])
	await _settled()
	_check("...Undo puts it back as “%s”, and with the account again" % back,
		back == "Final" and not _listed(await _list(), "Final").is_empty())


func _sign_in(email: String) -> String:
	var password: String = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(get_root(), HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": password, "email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await _account._fetch(_account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + _account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	_account._keep(reply["body"])
	_account.state = Account.State.SIGNED_IN
	_account.changed.emit()
	return ""


## Saved on the desktop as Save saves: the file written, and the account
## told (ModelStore._store, which every save ends in).
func _save(name: String, text: String) -> void:
	_store._store(_path(name), text)


static func _path(name: String) -> String:
	return ModelStore.SAVE_DIR + name + ".ldr"


## What the store's [param method] answers, in words: "" where it has none
## (a build from before delete and rename).
func _do(method: String, args: Array) -> String:
	return str(_store.callv(method, args)) if _store.has_method(method) else ""


## [param text], a model of the app's own, called [param name]: its first
## line, which names it.
static func _titled(text: String, name: String) -> String:
	return "0 " + name + text.substr(text.find("\n"))


## The account's models as it lists them.
func _list() -> Array:
	var got: Dictionary = await _browser("GET", "/api/models", "")
	return (got["body"] as Dictionary).get("models", []) if got["body"] is Dictionary else []


static func _listed(models: Array, name: String) -> Dictionary:
	for one: Variant in models:
		if one is Dictionary and str((one as Dictionary).get("name", "")) == name:
			return one
	return {}


func _browser_save(name: String, text: String, base: int) -> Dictionary:
	var zipped: PackedByteArray = text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var got: Dictionary = await _browser("POST", "/api/models", JSON.stringify(
		{"name": name, "base": base, "model": Marshalls.raw_to_base64(zipped)}))
	return got["body"] if got["body"] is Dictionary else {}


func _browser_delete(name: String, version: int) -> Dictionary:
	var got: Dictionary = await _browser("DELETE", "/api/models?name=%s&version=%d"
		% [name.uri_encode(), version], "")
	return got["body"] if got["body"] is Dictionary else {}


## A request as the account, as another browser's app makes it.
func _browser(method: String, route: String, body: String) -> Dictionary:
	var token: String = await _account.access_token()
	var http := HTTPRequest.new()
	get_root().add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + token, "content-type: application/json"])
	var how: int = {"POST": HTTPClient.METHOD_POST, "DELETE": HTTPClient.METHOD_DELETE}.get(method, HTTPClient.METHOD_GET)
	http.request(_api + route, headers, how, body)
	var done: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse((done[3] as PackedByteArray).get_string_from_utf8()) == OK else null
	return {"code": int(done[1]), "body": parsed}


## The desktop's requests out of reach, or back: the account's route
## pointed nowhere, as a computer offline finds it.
func _offline(away: bool) -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9" if away else _api)


## The desktop coming back to its window: CloudModels looks again.
func _look() -> void:
	await _settled()
	_cloud._looked_at = -1000000
	_cloud.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settled()


## Until the look going, and any it asked for, are done.
func _settled() -> void:
	for _n: int in 600:
		await create_timer(0.1).timeout
		if not _cloud._syncing:
			return


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
