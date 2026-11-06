## The search's index let go of a frame's share at a time, never while a
## search still reads it, and never the parts it was made from.
##
##   godot --headless --path . --script src/dev/index_letgo_probe.gd
##
## A made index let go of at once held its frame for 60 to 80 ms, each of
## 34,000 words' parts an array of its own: the first search of
## bin_first_probe's browser without threads, and the frame a part made in
## the app lets the index go (bintiles, 2026-11-05). PartLibrary.forget_search
## now hands it to _index_frame, which lets go of it a share a frame
## (PartSearch.let_go_for) once nothing else holds it: a search on a worker
## may still be reading it.
extends SceneTree

## A step's share, as PartLibrary.INDEX_BUDGET_MS gives it.
const STEP_USEC := 4000

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var host := Node.new()
	root.add_child(host)
	library.set_fetch_host(host)
	var parts: int = library.parts.size()
	var offered: PackedStringArray = library._offered_ids()

	# One let go of at once, as it was, and one a step at a time.
	var whole := PartSearch.new(library.parts, offered)
	var t0: int = Time.get_ticks_usec()
	whole = null
	var at_once: float = (Time.get_ticks_usec() - t0) / 1000.0
	var index := PartSearch.new(library.parts, offered)
	var found: Array = index.find("brick 2 x 4", 10)
	var steps: Array = []
	var gone: bool = false
	while not gone and steps.size() < 100000:
		var s0: int = Time.get_ticks_usec()
		gone = index.let_go_for(STEP_USEC)
		steps.append((Time.get_ticks_usec() - s0) / 1000.0)
	var longest: float = steps.max()
	_check("a made index (it found %d) let go of in %d steps, the longest %.1f ms, where at once it was %.1f"
		% [found.size(), steps.size(), longest, at_once],
		gone and steps.size() > 5 and longest < at_once / 3.0)
	_check("all of it let go of", index._named.is_empty() and index._keyed.is_empty()
		and index._infos.is_empty() and index._at.is_empty() and index._named_words.is_empty()
		and index._going.is_empty())
	index = null
	_check("the library's parts kept (%d of %d)" % [library.parts.size(), parts],
		library.parts.size() == parts)

	# One being made, the library's parts in it.
	var partly := PartSearch.new(library.parts, offered, false)
	partly.made_for(30000)
	while not partly.let_go_for(STEP_USEC):
		pass
	partly = null
	_check("a part-made index let go of, the library's parts kept (%d of %d)"
		% [library.parts.size(), parts], library.parts.size() == parts)

	# Through the library: made, let go of, made again.
	library.prepare_search()
	while not library.search_ready():
		await process_frame
	var before: Array = _ids(library.search("plate 1 x 2", 8))
	library.forget_search()
	var held: Array[PartSearch] = library._letting_go
	_check("forget_search lets go of nothing on its frame (%d held, whole)" % held.size(),
		held.size() == 1 and not held[0]._named.is_empty())
	held = []
	var frames: int = 0
	while not library._letting_go.is_empty() and frames < 2000:
		await process_frame
		frames += 1
	await process_frame
	_check("then let go of in %d frames, and no frame's step after" % frames,
		library._letting_go.is_empty() and frames > 3
		and not process_frame.is_connected(library._index_frame))
	library.prepare_search()
	while not library.search_ready():
		await process_frame
	var after: Array = _ids(library.search("plate 1 x 2", 8))
	_check("the index made again finds the same (%s)" % ", ".join(after), after == before
		and not after.is_empty())

	# Let go of while a worker makes the next one, which holds the index's
	# lock all the while: no frame waits for it.
	library.forget_search()
	library.prepare_search()
	var slowest: float = 0.0
	var began: int = Time.get_ticks_usec()
	var last: int = began
	frames = 0
	while (not library.search_ready() or not library._letting_go.is_empty()) and frames < 20000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		slowest = maxf(slowest, (now - last) / 1000.0)
		last = now
		frames += 1
	var took: float = (Time.get_ticks_usec() - began) / 1000.0
	_check("let go of as a worker makes the next, its lock held: the longest frame %.1f ms of the %.0f it took (%d frames)"
		% [slowest, took, frames], library.search_ready() and library._letting_go.is_empty()
		and frames > 5 and slowest < took / 4.0)

	# Held by a search meanwhile.
	var searching: PartSearch = library._finder()
	library.forget_search()
	for n: int in 30:
		await process_frame
	var kept: bool = library._letting_go.size() == 1 and not searching._named.is_empty()
	var still: Array = _ids(searching.find("plate 1 x 2", 8))
	_check("held by a search, kept whole 30 frames on, and it still finds the same (%s)"
		% ", ".join(still), kept and still == before)
	searching = null
	frames = 0
	while not library._letting_go.is_empty() and frames < 2000:
		await process_frame
		frames += 1
	_check("let go of once the search lets go (%d frames)" % frames, library._letting_go.is_empty())

	print("")
	if _failures == 0:
		print("index_letgo: every check passed")
	else:
		print("index_letgo: %d FAILED" % _failures)
	quit(1 if _failures else 0)


func _ids(infos: Array) -> Array:
	return infos.map(func(info: PartLibrary.PartInfo) -> String: return info.id)


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
