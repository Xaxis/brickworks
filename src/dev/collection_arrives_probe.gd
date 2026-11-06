## A signed-in person's collection is fetched as they sign in, with the
## window, as it was when My collection's panel was made with the window.
## The panel came to be made on first use (leaves), and its store with it:
## nothing fetched the collection until something asked for it, and the
## first to ask read nothing. Bring in a 3D model said "none kept yet" to a
## person with a collection, and parts_list which=need said it was empty.
##
##   a collection kept on this device for a person, who signs in (no server
##   here, so it is the copy on this device that arrives, as offline);
##   it arrives with no panel made (Shell.collection_store);
##   Bring in a 3D model's box says what is on hand, compiling no panel;
##   it is told again as the collection changes, and as they sign out;
##   parts_list which=need reads it, making no panel;
##   My collection, opened, shows the same store.
##
##   godot --headless --path . --script src/dev/collection_arrives_probe.gd
##
## It names no class that names My collection's panel (AppTools does), so
## that "compiled" means the app compiled it.
extends SceneTree

const WHO := "probe-collection-user"

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	CollectionStore.where = OS.get_temp_dir().path_join("brickworks_collection_arrives_%d.json"
		% OS.get_process_id())
	CollectionStore._write_local({"owner": WHO, "sets": [], "parts": [
		{"part": "3001", "colour": 4, "qty": 5}, {"part": "3003", "colour": 1, "qty": 2}]})
	var scene: PackedScene = load("res://src/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and bool(_main.get("_built")):
			break
	var shell: Node = _main.get("_shell")
	if shell == null:
		print("  collection_arrives probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Object = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	await _frames(30)

	var store: CollectionStore = shell.get("collection_store")
	_check("the window has the collection's store, with no panel made",
		store != null and not Later.loaded(&"CollectionDialog"))
	# Signed in: the account's own sign-in, which has no server here, so the
	# copy kept on this device for them arrives (offline).
	var account: Account = _main.get("_account")
	account.keeps = false
	account.set("_refresh", "probe")
	account.set("_url", "")
	account.user_id = WHO
	account.state = Account.State.SIGNED_IN
	var arrived: Array = [false]
	if store != null:
		store.changed.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	account.changed.emit()
	var since: int = Time.get_ticks_msec()
	while not arrived[0] and Time.get_ticks_msec() - since < 10000:
		await process_frame
	_check("signed in, their collection arrives: %d pieces" % (
		store.pieces_on_hand() if store != null else -1),
		arrived[0] and store.pieces_on_hand() == 7)
	_check("and no panel was made for it: %s" % str(Later.took.keys()),
		not Later.loaded(&"CollectionDialog"))

	# Bring in a 3D model, first thing.
	var dialog: Control = _main.get("_brickify")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/brickify/bunny.obj")
	var mesh: Object = load("res://src/parts/mesh_file.gd").call("read", bytes, "bunny.obj")
	dialog.call("show_for", mesh)
	await _frames(3)
	var box: CheckBox = dialog.get("_from_owned")
	_check("Bring in a 3D model's box says what is on hand: \"%s\"" % box.text,
		box.text.contains("(7 pieces)") and not box.disabled)
	_check("and the panel showed with no My collection compiled: %s" % str(Later.took.keys()),
		not Later.loaded(&"CollectionDialog"))
	if store != null:
		store.on_hand[Collection.key_of("3001", 4, _main.get("_library"))] = 7
		store.changed.emit()
		await _frames(2)
		_check("told again as the collection changes: \"%s\"" % box.text, box.text.contains("(9 pieces)"))

	# parts_list which=need, as a session asks it. AppTools names My
	# collection's panel for its sums' words, so it is loaded here, after the
	# checks above: compiled, as it is in the app, but not made.
	var tools: RefCounted = load("res://src/net/app_tools.gd").new()
	tools.set("app", _main)
	var said: String = str(await tools.call("run", "parts_list", {"which": "need"}))
	_check("parts_list which=need reads it: %s" % said.replace("\n", " ").left(100),
		not said.contains("collection is empty") and said.contains("they own"))
	_check("and made no panel either", shell.get("_collection") == null)

	# My collection, opened, is the same store.
	var panel: Control = shell.get("collection")
	panel.call("open", "own")
	await _frames(3)
	_check("My collection opened reads the same store",
		panel.get("store") == store and store != null)
	panel.call("close")

	# Signed out: forgotten, and the box says so.
	var cleared: Array = [false]
	if store != null:
		store.changed.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
	account.user_id = ""
	account.state = Account.State.SIGNED_OUT
	account.changed.emit()
	await _frames(3)
	_check("signed out, it is forgotten and the box says none: \"%s\"" % box.text,
		cleared[0] and store.on_hand.is_empty() and box.disabled)

	# Brickify's compile on its worker ends before the app does.
	since = Time.get_ticks_msec()
	while bool(dialog.get("_making")) and Time.get_ticks_msec() - since < 120000:
		await process_frame
	DirAccess.remove_absolute(CollectionStore.where)
	print("collection_arrives probe: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
