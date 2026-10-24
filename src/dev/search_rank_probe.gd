## Does a search put first the part an expert would reach for?
##
##   godot --headless --path . --script src/dev/search_rank_probe.gd
##
## An expert's walk found the parts bin ranking by how a name reads and not by
## how much a part is used (walk239 A13, 2026-10-24): "door frame" gave 80400a,
## 28327, 33227, 2662 and 3417 first, not 60596, the 1 x 4 x 6 frame in hundreds
## of sets; "window 1 x 2 x 3" put the bare pane 3854 first; "3008" and "slope
## 45 2 x 4" gave the plain part and then dozens of its stickered versions.
##
## The queries below were written before the ranking was changed, and nothing
## was tuned on them (the five of the kind "category" after the rest, before
## the change they test): everyday names, sizes, part numbers and misspellings, each
## with the parts any one of which an expert expects among the first three
## tiles. Each answer was read off the catalogue by hand, the part in the most
## sets of the ones that are what was asked. Both the bin's tiles (what a
## person reads off the top of the list, PartsBin.first_found) and the
## assistant's search_parts are measured; each must have one of them in its
## first three for nine queries in ten.
##
## And how long the bin takes to answer a first keystroke: one letter or digit,
## over the whole catalogue, the results and the tiles that show them; the
## 50 ms meant is said, and the probe fails past 150 (KEYSTROKE_GUARD_MS).
##
## `-- quality` or `-- time` runs one half.
extends SceneTree

## [what is typed, the parts any one of which is right, what kind of query].
const QUERIES: Array = [
	# Everyday names.
	["door frame", ["60596"], "name"],
	["door", ["60596", "60616b", "60623", "3821", "3822"], "name"],
	["window 1x2x3", ["60593", "60593c01"], "name"],
	["window 1x2x2", ["60592", "60592c01"], "name"],
	["window", ["60592", "60594", "60593", "3853"], "name"],
	["slope 45 2x4", ["3037"], "name"],
	["slope 45 2x2", ["3039"], "name"],
	["slope 2x1", ["3040b"], "name"],
	["cheese slope", ["54200"], "name"],
	["tile 1x2", ["3069b"], "name"],
	["tile 2x2", ["3068b"], "name"],
	["tile 1x1", ["3070b"], "name"],
	["plate 1x2", ["3023b"], "name"],
	["jumper", ["15573", "3794b", "87580"], "name"],
	["hinge", ["3937", "6134", "3938", "73983"], "name"],
	["technic pin", ["2780", "3673", "61332", "6558", "4274"], "name"],
	["axle 4", ["3705"], "name"],
	["axle 3", ["4519"], "name"],
	["wheel", ["6014b", "4624", "42610", "55981", "56145"], "name"],
	["minifig head", ["3626c", "28621", "3626b"], "name"],
	["round plate 1x1", ["6141"], "name"],
	["round tile 1x1", ["98138"], "name"],
	["round brick 1x1", ["3062b"], "name"],
	["headlight brick", ["4070"], "name"],
	["grille tile", ["2412b"], "name"],
	["bracket 1x2 2x2", ["44728", "99207"], "name"],
	["technic brick 1x2", ["3700"], "name"],
	["technic beam 5", ["32316"], "name"],
	["liftarm 5", ["32316"], "name"],
	["gear 24", ["3648b"], "name"],
	["steering wheel", ["3829c01", "16091", "30663"], "name"],
	["windscreen", ["3823", "2437"], "name"],
	["fence", ["3633", "3185"], "name"],
	["baseplate 32x32", ["3811"], "name"],
	["arch 1x4", ["3659"], "name"],
	["technic bush", ["3713", "32123b"], "name"],
	["plate with clip", ["60897", "61252", "4081b", "63868", "11476", "60470b"], "name"],
	["window with glass", ["60593c01", "60592c01"], "name"],
	# Part numbers.
	["3008", ["3008"], "number"],
	["3001", ["3001"], "number"],
	["3039", ["3039"], "number"],
	["3069", ["3069b"], "number"],
	["60596", ["60596"], "number"],
	["2780", ["2780"], "number"],
	["4073", ["6141"], "number"],
	["3794", ["3794b", "3794a", "15573"], "number"],
	# Sizes alone.
	["2x4", ["3001", "3020", "87079"], "size"],
	["1x2", ["3004", "3023b", "3069b"], "size"],
	["1 x 6 plate", ["3666"], "size"],
	["6x6", ["3958"], "size"],
	["1x1x3", ["14716"], "size"],
	# Misspelt, run together, spelt the other way.
	["tyle 1x2", ["3069b"], "misspelt"],
	["brik 2x4", ["3001"], "misspelt"],
	["plat 2x2", ["3022"], "misspelt"],
	["slop 45 2x2", ["3039"], "misspelt"],
	["techic pin", ["2780", "3673", "61332", "6558", "4274"], "misspelt"],
	["windw 1x2x3", ["60593", "60593c01"], "misspelt"],
	["hindge", ["3937", "6134", "3938", "73983"], "misspelt"],
	["axel 4", ["3705"], "misspelt"],
	["cheeze slope", ["54200"], "misspelt"],
	["minifig hed", ["3626c", "28621", "3626b"], "misspelt"],
	["doorframe", ["60596"], "misspelt"],
	["tile 1x2 grill", ["2412b"], "misspelt"],
	# A family word and what kind of it, as BrickLink files them: written
	# after the first 63 and before the change they test (search242, the
	# lead's "wedge brick"). A modified plate or brick is one with
	# something on it, not a round one.
	["round brick", ["3062b", "3941"], "category"],
	["curved slope", ["11477", "15068", "93273", "50950"], "category"],
	["tile round", ["98138", "14769", "4150"], "category"],
	["plate modified", ["15573", "87580", "2540", "48336", "60478", "32028", "4081b",
		"60897", "61252", "63868", "11476"], "category"],
	["brick modified", ["4070", "87087", "11211", "30414", "2877", "6091"], "category"],
]

## The share of queries with a right part in the first three, at least.
const TOP3_BAR := 0.9
## The bin's answer to a first keystroke, in milliseconds: what it is meant to
## take on a quiet desktop, and what fails the probe. About 30 ms the median and
## 54 ms the slowest letter at a load of 13, every time twice that at 38
## (2026-10-24); the scan it replaced took a second, and the guard is for that.
const KEYSTROKE_MS := 50.0
const KEYSTROKE_GUARD_MS := 150.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		only = arg
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var bin := PartsBin.new()
	bin.library = library
	get_root().add_child(bin)
	await process_frame
	bin.populate()
	if only != "time":
		_quality(library, bin)
	if only != "quality":
		await _time(library, bin)
	bin.queue_free()
	print("")
	print("search ranks as an expert would" if _failures == 0
		else "%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _quality(library: PartLibrary, bin: PartsBin) -> void:
	var tally: Dictionary = {}     ## kind -> [queries, bin top 1, bin top 3, search top 1, search top 3]
	var all: Array = [0, 0, 0, 0, 0]
	for row: Array in QUERIES:
		var asked: String = row[0]
		var wanted: Array = row[1]
		var kind: String = row[2]
		bin._run_search(asked)
		var tiles: PackedStringArray = bin.first_found(3)
		var searched := PackedStringArray()
		for info: PartLibrary.PartInfo in library.search(asked, 3):
			searched.append(info.id)
		var hits: Array = [1,
			1 if not tiles.is_empty() and wanted.has(tiles[0]) else 0,
			1 if _any(wanted, tiles) else 0,
			1 if not searched.is_empty() and wanted.has(searched[0]) else 0,
			1 if _any(wanted, searched) else 0]
		if not tally.has(kind):
			tally[kind] = [0, 0, 0, 0, 0]
		for n: int in 5:
			tally[kind][n] += hits[n]
			all[n] += hits[n]
		print("  %s %s  %-20s bin %-26s search %-26s wanted %s" % [
			"ok  " if hits[2] else "MISS", "ok  " if hits[4] else "MISS", asked,
			", ".join(tiles), ", ".join(searched), ", ".join(PackedStringArray(wanted))])
	print("")
	print("  %-9s %7s  %-14s %-14s" % ["", "queries", "bin top 1/3", "search top 1/3"])
	for kind: String in tally:
		var t: Array = tally[kind]
		print("  %-9s %7d  %3d%% %3d%%      %3d%% %3d%%" % [kind, t[0],
			_share(t[1], t[0]), _share(t[2], t[0]), _share(t[3], t[0]), _share(t[4], t[0])])
	print("  %-9s %7d  %3d%% %3d%%      %3d%% %3d%%" % ["all", all[0],
		_share(all[1], all[0]), _share(all[2], all[0]), _share(all[3], all[0]),
		_share(all[4], all[0])])
	for at: int in [2, 4]:
		var share: float = float(all[at]) / float(all[0])
		if share < TOP3_BAR:
			_failures += 1
			print("  FAIL  the %s has a right part in its first three for %d%% of the queries, under %d%%"
				% ["bin" if at == 2 else "search", _share(all[at], all[0]), roundi(TOP3_BAR * 100)])


## The bin's answer to one keystroke, from the text changing to its tiles in
## the grid: the median and the slowest of each letter and digit a search
## starts with, every one after the first search of the session, which is
## timed apart.
func _time(library: PartLibrary, bin: PartsBin) -> void:
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var cold_bin := PartsBin.new()
	cold_bin.library = fresh
	get_root().add_child(cold_bin)
	await process_frame
	var shown: int = Time.get_ticks_usec()
	cold_bin.populate()
	# The index is made off the main thread once the bin is filled, where
	# there are threads (PartLibrary.prepare_search); a person types after.
	var frames: int = 0
	if fresh.has_method("search_ready"):
		while not fresh.call("search_ready") and frames < 600:
			await process_frame
			frames += 1
	var ready: float = float(Time.get_ticks_usec() - shown) / 1000.0
	var started: int = Time.get_ticks_usec()
	cold_bin._run_search("d")
	var cold: float = float(Time.get_ticks_usec() - started) / 1000.0
	cold_bin.queue_free()

	var times: Array[float] = []
	var slowest: String = ""
	var worst: float = 0.0
	for key: String in ["a", "b", "c", "d", "g", "h", "p", "r", "s", "t", "w", "1", "2", "3", "6"]:
		bin._run_search("")
		var at: int = Time.get_ticks_usec()
		bin._run_search(key)
		var took: float = float(Time.get_ticks_usec() - at) / 1000.0
		times.append(took)
		if took > worst:
			worst = took
			slowest = key
	times.sort()
	var median: float = times[times.size() / 2]
	var whole: Array[float] = []
	for query: String in ["door frame", "slope 45 2x4", "3008", "brick 2 x 4", "technic pin"]:
		var at: int = Time.get_ticks_usec()
		bin._run_search(query)
		whole.append(float(Time.get_ticks_usec() - at) / 1000.0)
	print("")
	print("  a first keystroke over %d parts: median %.1f ms, slowest %.1f ms (\"%s\"); the session's first search %.1f ms, %.0f ms after the bin was filled"
		% [library.parts.size(), median, worst, slowest, cold, ready])
	print("  whole queries: %s ms" % ", ".join(whole.map(func(ms: float) -> String:
		return "%.1f" % ms)))
	var slowest_ms: float = maxf(worst, cold)
	if slowest_ms > KEYSTROKE_GUARD_MS:
		_failures += 1
		print("  FAIL  a first keystroke takes %.1f ms, over %d" % [slowest_ms,
			roundi(KEYSTROKE_GUARD_MS)])
	elif slowest_ms > KEYSTROKE_MS:
		print("  --    the slowest first keystroke, %.1f ms, is over the %d ms meant on a quiet desktop (load %s)"
			% [slowest_ms, roundi(KEYSTROKE_MS), _load()])


## The box's load over the last minute, which every timing here moves with.
static func _load() -> String:
	# /proc says its files are empty, so read a line rather than the length.
	var file: FileAccess = FileAccess.open("/proc/loadavg", FileAccess.READ)
	var text: String = file.get_line() if file != null else ""
	return text.get_slice(" ", 0) if not text.is_empty() else "unknown"


static func _any(wanted: Array, found: PackedStringArray) -> bool:
	for id: String in found:
		if wanted.has(id):
			return true
	return false


static func _share(part: int, whole: int) -> int:
	return roundi(100.0 * float(part) / float(maxi(whole, 1)))
