## Does a tab running an older build than the live one say so, keep to its
## own session, and reload with nothing lost?
##
##   godot --headless --path . --script src/dev/update_probe.gd
##
## The app's half of "Brickworks has been updated" (NewerBuild): the page
## asks the site which build is live and holds back every write outside the
## tab's own session from then on (src/boot/shell.html), which a browser
## proves (tools/web/reload_flow.mjs). Here the page's word is played
## (NewerBuild.pretend) on the real scene: the banner shows above the model
## with Reload; a save to the models every tab shares is refused, saying
## why, while the working model still goes to the tab's own session;
## Reload writes the working model at once, before it would have settled,
## and only then reloads; and Claude, over the connector, is told once.
##
## Before 2026-10-13 there was no banner, nothing to tell the app a newer
## build was live, and Save went to the shared models as ever.
extends SceneTree

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
	var offer: Variant = main.get("_update_offer")
	store.open("res://models/house.ldr")
	store.title = "Update Probe House"
	store.adopt()
	await _frames(70)
	_check("no banner while this build is the live one",
		offer != null and not (offer as UpdateOffer).showing())

	NewerBuild.pretend("probe-newer")
	await _frames(90)
	_check("a newer build live: \"Brickworks has been updated\", with Reload, above the model",
		offer != null and (offer as UpdateOffer).showing()
			and (offer as UpdateOffer).controls_by_name().has("update_reload"))

	var shared: String = ModelStore.saved_path("Update Probe House")
	DirAccess.remove_absolute(shared)
	var saved: bool = store.save_as("Update Probe House")
	_check("Save to the shared models is refused, saying why: %s" % store.refused,
		not saved and store.refused == NewerBuild.REFUSAL and not FileAccess.file_exists(shared))

	# A probe keeps no working model unless it turns that on (Main).
	store.keeps = true
	var own: String = ModelStore.autosave()
	DirAccess.remove_absolute(own)
	store.touch()
	var written: String = store.write_now()
	_check("the working model goes to this tab's own session at once: %s" % written,
		written == own and own.begins_with(TabSession.ROOT + TabSession.id() + "/")
			and FileAccess.get_file_as_string(own).begins_with("0 Update Probe House"))

	# Reload: the working model written first, then the page reloaded.
	DirAccess.remove_absolute(own)
	store.touch()
	var reloaded: Array = [false]
	var had_file: Array = [false]
	(offer as UpdateOffer).reload_page = func() -> void:
		had_file[0] = FileAccess.file_exists(own)
		reloaded[0] = true
	(offer as UpdateOffer).reload()
	await _frames(20)
	_check("Reload writes the working model before it would have settled, then reloads",
		reloaded[0] and had_file[0])

	# Claude, over the connector, told once.
	var socket := CommandSocket.new()
	socket.assistant = main.get("_assistant")
	socket.app = main
	main.add_child(socket)
	var first: Dictionary = await socket.answer_rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
		"params": {"name": "search_parts", "arguments": {"query": "2 x 4"}}})
	var second: Dictionary = await socket.answer_rpc({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
		"params": {"name": "search_parts", "arguments": {"query": "2 x 2"}}})
	_check("Claude's next call is told the tab runs an older build, and to ask for Reload",
		_text(first).contains("Brickworks has been updated since this tab opened"))
	_check("...once", not _text(second).contains("has been updated"))

	NewerBuild.pretend("")
	_done()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _text(answer: Dictionary) -> String:
	var said: String = ""
	for block: Variant in ((answer.get("result", {}) as Dictionary).get("content", []) as Array):
		said += str((block as Dictionary).get("text", "")) + "\n"
	return said


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("a tab on an older build says so, keeps to its own session, and reloads with nothing lost")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
