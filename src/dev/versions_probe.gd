## Are a model's last 20 saves kept, can one be opened again, and does the
## browser get asked to keep them, with one warning where it will not?
##
##   godot --headless --path . --script src/dev/versions_probe.gd
##
## On the web a person's models are only in the browser (supabase/schema.sql
## keeps none), and until 2026-10-14 a save wrote over the last with no copy
## kept, and the browser was never asked to keep its storage. Here, on the
## real scene:
##
##   - 21 saves of a model, each a part more: 20 are kept, the 21st drops the
##     oldest, and a save that changes nothing keeps no second copy.
##   - File, Versions… lists them, newest first, and Open on one puts that
##     save on the baseplate under the model's name, part for part; with
##     changes not saved it says so and offers Save, and Open asks first.
##   - All of them together stay under the cap, oldest first, never a
##     model's newest.
##   - A save asks the browser to keep the storage (StorageKeep; the page's
##     answer is played with StorageKeep.pretend, and the page itself is
##     proved by tools/web/keep_flow.mjs). Account says whether it agreed.
##     Refused, or Safari, the warning shows once, above the model, with
##     Download my models; agreed, never.
##   - Over MCP, open_model lists a model's versions and opens one, and
##     export_model all_models downloads every saved model in one .zip.
##
## On main there was no ModelVersions, StorageKeep or Versions…, and this
## does not parse there.
extends SceneTree

const NAME := "Versions Probe House"
const OTHER := "Versions Probe Shed"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = main.get("_store")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var shell: Shell = main.get("_shell")
	var offer: StorageOffer = main.get("_storage_offer")
	var account: AccountPanel = main.get("_account_panel")
	for name: String in [NAME, OTHER]:
		_forget(name)
	# Kept, as a person's window keeps it: a probe keeps nothing unless it
	# says so (Main), and the warning is for a window that keeps models.
	store.keeps = true

	# The page has not been asked; a save asks it.
	StorageKeep.pretend({"asked": false})
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	var first: int = world.brick_count() - store.scenery.size()
	var stamps: Array[int] = []
	for n: int in 21:
		_add_brick(world, builder, n)
		if not store.save_as(NAME):
			_check("save %d: %s" % [n + 1, store.refused], false)
		var newest: Array[ModelVersions.Version] = store.versions()
		stamps.append(newest[0].at if not newest.is_empty() else -1)
		if n == 0:
			_check("the first save asks the browser to keep the storage",
				bool(StorageKeep.state()["asked"]))
		if n == 19:
			_check("20 saves: 20 versions kept", newest.size() == 20)
	var kept: Array[ModelVersions.Version] = store.versions()
	_check("the 21st save: still 20 versions, %d" % kept.size(), kept.size() == ModelVersions.KEPT)
	_check("...and the oldest is the one dropped",
		kept[kept.size() - 1].at == stamps[1] and not kept.any(
			func(v: ModelVersions.Version) -> bool: return v.at == stamps[0]))
	_check("the newest is the last save, %d parts" % kept[0].parts,
		kept[0].at == stamps[20] and kept[0].parts == first + 21)
	_check("newest first, each a part fewer than the one after it",
		range(kept.size() - 1).all(func(n: int) -> bool:
			return kept[n].at > kept[n + 1].at and kept[n].parts == kept[n + 1].parts + 1))
	store.save_as(NAME)
	_check("a save that changes nothing keeps no second copy",
		store.versions().size() == 20 and store.versions()[0].at == stamps[20])

	# File, Versions…: opened, and the fifth newest opened from it.
	_add_brick(world, builder, 40)
	shell.versions.open()
	await process_frame
	var listed: Dictionary = shell.versions.page_state()
	var controls: Dictionary = shell.versions.controls_by_name()
	_check("Versions… lists the 20, newest first: %s" % str(listed["note"]).left(60),
		bool(listed["open"]) and (listed["rows"] as Array).size() == 20
			and controls.has("version_open_1") and controls.has("version_open_20"))
	_check("...and says the baseplate has changes not saved, with Save beside it",
		str(listed["note"]).contains("not saved") and controls.has("versions_save"))
	var fifth: ModelVersions.Version = kept[4]
	(controls["version_open_5"] as Button).pressed.emit()
	await process_frame
	# Asked first, as every open over changes not saved is
	# (ModelBar.ask_to_replace); Don't save, here.
	var asked: Dictionary = shell.bar.controls_by_name()
	_check("...asked first: Save, Don't save or Cancel",
		asked.has("replace_save") and asked.has("replace_discard") and asked.has("replace_cancel"))
	if asked.has("replace_discard"):
		(asked["replace_discard"] as Button).pressed.emit()
	for _n: int in 30:
		await process_frame
	_check("Open on the fifth puts that save on the baseplate: %d parts, %d wanted"
		% [world.brick_count() - store.scenery.size(), fifth.parts],
		world.brick_count() - store.scenery.size() == fifth.parts)
	_check("...under the model's name, %s" % store.title, store.title == NAME)
	_check("...not yet saved as it is", store.has_unsaved_work())
	_check("...and the dialog has gone", not shell.versions.visible)

	# The cap on all of them: oldest first, never a model's newest.
	store.open("res://models/tower.ldr")
	store.title = OTHER
	store.adopt()
	store.save_as(OTHER)
	var other_newest: int = ModelVersions.of(OTHER)[0].at
	var before: int = ModelVersions.total_bytes()
	var limit: int = ModelVersions.most_bytes
	ModelVersions.most_bytes = before / 2
	store.open(ModelStore.saved_path(NAME))
	_add_brick(world, builder, 41)
	store.save_as(NAME)
	var after: int = ModelVersions.total_bytes()
	_check("over the cap, the oldest go: %d bytes, cap %d, from %d" % [after, before / 2, before],
		after <= before / 2 and store.versions().size() < 20)
	_check("...never a model's newest",
		ModelVersions.of(OTHER).size() == 1 and ModelVersions.of(OTHER)[0].at == other_newest
			and store.versions()[0].parts == world.brick_count() - store.scenery.size())
	ModelVersions.most_bytes = limit

	# Where the models are kept, and the one warning.
	StorageKeep.pretend({"asked": true, "answered": true, "kept": true})
	account.open()
	_check("agreed: Account says the models are kept on this device: %s" % account.storage_words(),
		account.storage_words().begins_with("Your models are kept on this device: this browser has agreed"))
	account.visible = false
	_check("...and nothing is warned", not offer.offer_if_due(true) and not offer.showing())
	# The browser answers while Account is open: Firefox asks the person, and
	# Chromium's answer can land just after the panel read the last one.
	StorageKeep.pretend({"asked": true})
	account.open()
	var asking: String = account.storage_words()
	StorageKeep.pretend({"asked": true, "answered": true, "kept": true})
	await _until(func() -> bool: return account.storage_words().begins_with(
		"Your models are kept on this device: this browser has agreed"), 2.0)
	_check("the browser agrees while Account is open, and Account says so: %s"
		% account.storage_words().left(70), asking.contains("Your account keeps no copy of a model "
			+ "saved while you are signed out")
		and account.storage_words().begins_with(
			"Your models are kept on this device: this browser has agreed"))
	account.visible = false
	StorageKeep.pretend({"asked": true, "answered": true, "kept": false})
	account.open()
	_check("refused: Account says they may be cleared by the browser",
		account.storage_words().contains("may be cleared by the browser"))
	account.visible = false
	_check("...says the account keeps no copy, and invents none",
		account.storage_words().contains("Your account keeps no copy"))
	await _until(func() -> bool: return offer.showing(), 4.0)
	_check("the warning shows above the model, with Download my models: %s" % offer.words(),
		offer.showing() and offer.controls_by_name().has("storage_download_all")
			and offer.words().contains("Your account keeps no copy"))
	(offer.controls_by_name()["storage_got_it"] as Button).pressed.emit()
	await _until(func() -> bool: return offer.showing(), 2.5)
	_check("...once: dismissed, it does not come back", not offer.showing()
		and not offer.offer_if_due(true) and bool(ShellPrefs.value("storage_warned")))
	ShellPrefs.put("storage_warned", false)
	StorageKeep.pretend({"asked": true, "answered": true, "kept": true, "safari": true})
	_check("Safari warns even when it agreed: it deletes after seven days without a visit",
		offer.offer_if_due(true) and offer.words().contains("seven days"))
	offer.visible = false
	ShellPrefs.put("storage_warned", false)
	StorageKeep.pretend({"asked": true, "answered": true, "kept": false})
	_check("...and with no saved models there is nothing to warn of", not offer.offer_if_due(false))

	# Every line about where the models are, true in each way they can stand
	# with the account. Signed in with the account full, the warning said
	# "Your account keeps no copy", which was false: it had all but those it
	# had no room for. Each said with the browser refusing to keep them (so
	# the warning shows), agreeing, and on the desktop.
	var told: Dictionary = {
		"out": ["Your account keeps no copy of a model saved while you are signed out",
			"sign in"],
		"full": ["Your account is full", "2 of your models are kept only"],
		"offline": ["You are offline", "back online"],
		"none": ["Your account keeps no copy"],
		"kept": ["kept with your account"],
	}
	for standing: String in told:
		for browser: Dictionary in [{"answered": true, "kept": false}, {"answered": true,
				"kept": true}, {"web": false}]:
			var as_if: Dictionary = {"asked": true, "account": standing, "left_out": 2}
			as_if.merge(browser, true)
			StorageKeep.pretend(as_if)
			var lines: PackedStringArray = [StorageKeep.words()]
			if not StorageKeep.warning().is_empty():
				lines.append(StorageKeep.warning())
			var where: String = "on the desktop" if browser.has("web") else (
				"agreed" if browser["kept"] else "refused")
			for line: String in lines:
				var says: bool = (told[standing] as Array).all(func(w: String) -> bool:
					return line.contains(w))
				# "keeps no copy" said bare is true only where it keeps none.
				var false_copy: bool = standing != "none" and line.contains("Your account keeps no copy") \
					and not line.contains("while you are signed out")
				_check("%s, %s: %s" % [standing, where, line.left(110)], says and not false_copy)
			_check("...%s, %s: warned only where the browser may clear them and the account "
				% [standing, where] + "lacks some", (lines.size() == 2) == (standing != "kept"
				and not browser.has("web") and not browser["kept"]))
	StorageKeep.pretend({"asked": true, "answered": true, "kept": false})

	# Over MCP: the same versions, and every saved model in one .zip.
	var tools := AppTools.new()
	tools.app = main
	tools.assistant = main.get("_assistant")
	var listing: String = str(await tools.run("open_model", {}))
	_check("open_model's list says how many versions each has, and where the models stand",
		listing.contains("%s (" % NAME) and listing.contains("versions)")
			and listing.contains("may be cleared by the browser"))
	var said: String = str(await tools.run("open_model", {"name": NAME, "versions": true}))
	_check("open_model versions=true lists them, newest first", said.contains("1. Today at"))
	var third: ModelVersions.Version = store.versions()[2]
	said = str(await tools.run("open_model", {"name": NAME, "version": 3, "discard_changes": true}))
	_check("open_model version=3 opens that save: %s" % said.left(70),
		said.begins_with("Opened %s as saved" % NAME)
			and world.brick_count() - store.scenery.size() == third.parts and store.title == NAME)
	var exports: Exports = main.get("_exports")
	var folder: String = ProjectSettings.globalize_path("user://versions_probe_downloads")
	DirAccess.make_dir_recursive_absolute(folder)
	exports.folder = folder
	said = str(await tools.run("export_model", {"format": "all_models"}))
	var zip_path: String = folder.path_join("brickworks_models_%s.zip" % Time.get_date_string_from_system())
	var reader := ZIPReader.new()
	var opened: bool = reader.open(zip_path) == OK
	var inside: PackedStringArray = reader.get_files() if opened else PackedStringArray()
	_check("export_model all_models: every saved model in one .zip (%s)" % ", ".join(inside),
		opened and inside.has(NAME + ".ldr") and inside.has(OTHER + ".ldr")
			and ModelStore.count_in(reader.read_file(NAME + ".ldr").get_string_from_utf8())
				== _parts(ModelStore.saved_path(NAME)))
	if opened:
		reader.close()
	exports.folder = ""
	DirAccess.remove_absolute(zip_path)

	StorageKeep.pretend({})
	for name: String in [NAME, OTHER]:
		_forget(name)
	_done()


## Frames until [param test] holds or [param seconds] have gone.
func _until(test: Callable, seconds: float) -> void:
	var ends: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(test.call()) and Time.get_ticks_msec() < ends:
		await process_frame


## A 1 x 1 brick somewhere on the baseplate no other probe brick is.
func _add_brick(world: BrickWorld, builder: Builder, n: int) -> void:
	var at := Transform3D(Basis.IDENTITY, Vector3(-300.0 + 20.0 * (n % 10), -24.0 * (1 + n / 10),
		-300.0))
	var id: int = world.add_brick("3005", 4, at)
	if id != 0:
		builder.register(id, "3005", at)


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


func _parts(path: String) -> int:
	return ModelStore.count_in(FileAccess.get_file_as_string(path))


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("a model's last 20 saves are kept and open again, and the browser is asked to keep them")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
