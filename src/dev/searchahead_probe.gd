## The search's index is made ahead of need once the start's model is laid,
## not as the bin first fills (webstart13).
##
##   godot --headless --path . --script src/dev/searchahead_probe.gd
##
## On WebKit as an iPhone 13 on live, a worker grew the Wasm memory from 360
## to 432 MB about 5 s after the window was built, while the start's model
## was still being drawn; every growth the page's own thread asked for had
## stopped at 360 (tools/web/start_phases.mjs). The index, made on a worker
## from the bin's first fill (PartsBin.populate), is the start's worker task
## over the whole catalogue. Now:
## - a library held (PartLibrary.search_ahead_held) asked for the index ahead
##   of need makes none, and remembers the asking;
## - a search typed while it is held has the index made at once (wanted);
## - let go of, the index asked for meanwhile is made;
## - the app's start: no index is made, nor begun, until the start's model is
##   laid and every part of it is here (Main._search_ahead_after_start); then
##   it is let go of within a few frames and the index is made, so the bin's
##   first search finds it as before.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	print("\n  a library held")
	await _held()
	print("\n  the app's start")
	await _start()
	print("")
	if _failures == 0:
		print("searchahead probe: all checks passed")
	else:
		print("searchahead probe: %d check(s) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Whether [param library]'s index is made or being made, asked without
## waiting for it.
static func _begun(library: PartLibrary) -> bool:
	return library._preparing >= 0 or library._index_making != null or library.search_ready()


func _held() -> void:
	# Two of each kind, in a library of their own: the index made from them
	# is a few words, so whatever is begun is done in a frame or two.
	var library := PartLibrary.new()
	for id: String in ["3001", "3003"]:
		var info := PartLibrary.PartInfo.new()
		info.id = id
		info.name = "Brick 2 x %s" % ("4" if id == "3001" else "2")
		info.category = "Brick"
		info.reachable = true
		library.parts[id] = info
		library._ordered_ids.append(id)
	library.search_ahead_held = true
	library.prepare_search()
	_check("held, the index asked for ahead of need is not begun", not _begun(library))
	library.let_search_ahead()
	_check("let go of, the index asked for meanwhile is begun", _begun(library))
	await _made(library)
	_check("…and made", library.search_ready())
	_check("…and finds what it is asked", not library.search("brick 2 x 4", 5).is_empty())
	# Held again: a typed search has it made at once.
	library.forget_search()
	await _let_go(library)
	library.search_ahead_held = true
	library.prepare_search(true)
	_check("held, a search typed has the index begun at once", _begun(library))
	await _made(library)
	_check("…and made", library.search_ready())
	library.let_search_ahead()
	_check("let go of with nothing asked meanwhile, no second index is begun",
		library.search_ready() and library._preparing < 0 and library._index_making == null)
	library.forget_search()
	await _let_go(library)


## Frames until [param library]'s index is made, at most 600.
func _made(library: PartLibrary) -> void:
	for _n: int in 600:
		if library.search_ready():
			return
		await process_frame


## Frames until what [param library] let go of is gone, at most 600.
func _let_go(library: PartLibrary) -> void:
	for _n: int in 600:
		if library._letting_go.is_empty() and library._preparing < 0:
			return
		library._collect_preparing()
		await process_frame


func _start() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var library: PartLibrary = null
	var begun_early: bool = false
	var laid_at: int = -1
	var let_go_at: int = -1
	var made_at: int = -1
	var frames: int = 0
	var since: int = Time.get_ticks_msec()
	# Up to 60 s: the start, its model laid, the index let go of and made.
	while Time.get_ticks_msec() - since < 60000:
		await process_frame
		frames += 1
		if library == null:
			library = main.get("_library")
			if library == null:
				continue
		var store: ModelStore = main.get("_store")
		var laid: bool = bool(main.get("_first_open_done")) and store != null \
			and store.awaited.is_empty() and not store.laying
		if laid and laid_at < 0:
			laid_at = frames
		if not laid and _begun(library):
			begun_early = true
		if not library.search_ahead_held and let_go_at < 0:
			let_go_at = frames
		if library.search_ready() and made_at < 0:
			made_at = frames
			break
	print("    model laid at frame %d, the index let go of at %d, made at %d" % [laid_at, let_go_at, made_at])
	_check("the start lays its model", laid_at > 0)
	_check("no index is begun before the start's model is laid and its parts are here", not begun_early)
	_check("held from the catalogue on: let go of only once the model is laid",
		let_go_at < 0 or laid_at > 0 and let_go_at >= laid_at)
	_check("let go of within 5 frames of the model being laid", let_go_at > 0 and let_go_at - laid_at <= 5)
	_check("the index is made once let go of, ahead of any search", made_at > 0)
	main.queue_free()
	await process_frame
