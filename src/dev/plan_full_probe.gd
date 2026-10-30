## The plan keeps no more models with the account: Save says so in the
## plan's words, with Pro beside the way to delete one (savecap360,
## 2026-10-29).
##
##   godot --headless --path . --script src/dev/plan_full_probe.gd
##
## Free keeps 25 models with the account, and a 26th is refused by the
## deployment (api/models.js 413 {full: "plan", error, pro: "/plans"}). Here
## the account is a stand-in answering as api/models.js does, with
## account_models_plan.sql's rule: only a model new to the account counts.
## Twenty-six saved models are looked at (CloudModels): 25 kept, the 26th
## refused; the offer above the model (AccountFullOffer) says the plan's
## words, every time, with Delete old models and See Pro; the saved models
## dialog's note says them too. One is deleted here: at the next look the
## account deletes it, takes the 26th, and nothing is refused. A full
## account (500) still says its own words, with no See Pro.
##
## A build from before 2026-10-29 has no CloudModels.PLAN, and this does
## not load.
extends SceneTree

const WORDS := "Free keeps 25 models in your account. Delete one, or get Pro for unlimited."
const MOST := 25

var _failures: int = 0


## api/models.js and account_models.sql, in memory: the account's models by
## name, {version, sum}, at most MOST new ones.
class PlanAccount extends CloudModels:
	var kept: Dictionary = {}
	var most: int = MOST

	func _ask(method: String, route: String, body: String = "") -> Dictionary:
		if method == "GET" and route == "/api/models":
			var models: Array = []
			for name: String in kept:
				models.append({"name": name, "version": kept[name]["version"], "sum": kept[name]["sum"]})
			return {"code": 200, "body": {"models": models, "kept": {"models": kept.size(), "bytes": 0,
				"most_models": 500, "most_bytes": 64 * 1024 * 1024}}}
		if method == "DELETE":
			var name: String = route.get_slice("name=", 1).get_slice("&", 0).uri_decode()
			kept.erase(name)
			return {"code": 200, "body": {"name": name, "deleted": true}}
		var sent: Dictionary = JSON.parse_string(body)
		var name: String = str(sent["name"])
		var text: String = Marshalls.base64_to_raw(str(sent["model"])).decompress_dynamic(
			1 << 24, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
		var sum: String = text.sha256_text()
		if kept.has(name):
			kept[name] = {"version": int(kept[name]["version"]) + 1, "sum": sum}
			return {"code": 200, "body": {"name": name, "version": kept[name]["version"]}}
		if kept.size() >= most:
			return {"code": 413, "body": {"full": "plan", "pro": "/plans", "error": WORDS}}
		kept[name] = {"version": 1, "sum": sum}
		return {"code": 200, "body": {"name": name, "version": 1}}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _ldr(name: String) -> String:
	return "0 %s\n0 Name: %s.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" % [name, name]


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	for n: int in range(1, 27):
		var file := FileAccess.open(ModelStore.SAVE_DIR + "Model %02d.ldr" % n, FileAccess.WRITE)
		file.store_string(_ldr("Model %02d" % n))
		file.close()
	var account := Account.new()
	account.user_id = "plan-probe"
	var cloud := PlanAccount.new()
	cloud.account = account
	var offer := AccountFullOffer.new()
	get_root().add_child(offer)
	var told: Array = []
	cloud.short_of_room.connect(func(words: String, pro: String) -> void: told.append([words, pro]))
	cloud.short_of_room.connect(offer.tell)

	# A save made: the look sends all 26, the account keeps 25.
	cloud._saved = true
	await cloud._sync_once()
	_check("the account keeps %d of the 26 (%d)" % [MOST, cloud.kept.size()], cloud.kept.size() == MOST)
	_check("the 26th refused for the plan: %s" % JSON.stringify(cloud.refused),
		cloud.refused == {"Model 26": CloudModels.FULL + CloudModels.PLAN})
	_check("its standing is full, 1 left out (%s, %d)" % [CloudModels.standing, CloudModels.left_out],
		CloudModels.standing == "full" and CloudModels.left_out == 1)
	_check("Save says the plan's words, with Pro's page: %s" % JSON.stringify(told),
		told == [[WORDS, "/plans"]])
	_check("the offer above the model says them: \"%s\"" % offer.words(), offer.words() == WORDS)
	var named: Dictionary = offer.controls_by_name()
	_check("...with Delete old models, See Pro and Not now: %s" % ", ".join(named.keys()),
		named.has("room_delete_old") and named.has("room_see_pro") and named.has("room_not_now")
		and (named["room_see_pro"] as Button).text == "See Pro")
	_check("the saved models dialog's note has them too", cloud.short_words() == WORDS)

	# Not now, then another save while still full: said again, every time.
	(named["room_not_now"] as Button).pressed.emit()
	_check("Not now hides it", not offer.showing())
	cloud._saved = true
	await cloud._sync_once()
	_check("the next save says it again: \"%s\"" % offer.words(), offer.words() == WORDS and told.size() == 2)

	# One deleted here: the account deletes it and takes the 26th at once.
	DirAccess.remove_absolute(ModelStore.SAVE_DIR + "Model 03.ldr")
	cloud._deleted_here("Model 03")
	cloud._saved = true
	await cloud._sync_once()
	_check("a delete makes room: the 26th is kept (%s)" % ", ".join(cloud.kept.keys().slice(-2)),
		cloud.kept.has("Model 26") and not cloud.kept.has("Model 03") and cloud.kept.size() == MOST)
	_check("nothing refused now, nothing to say (%s, \"%s\")" % [JSON.stringify(cloud.refused),
		cloud.short_words()], cloud.refused.is_empty() and cloud.short_words() == ""
		and CloudModels.standing == "kept" and told.size() == 2)

	# The account's own limit (500) is not the plan's: its words, no See Pro.
	offer.tell("Your account is full: it has 500 of the 500 models it keeps, so new saves are kept "
		+ "only on this computer. Delete models you no longer need to make room.")
	_check("a full account says its own words with no See Pro",
		offer.showing() and not offer.controls_by_name().has("room_see_pro"))

	offer.queue_free()
	cloud.free()
	account.free()
	print("plan_full probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures else 0)
