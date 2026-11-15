## The figures' index made and read on two threads at once comes out whole,
## and nothing reading it fails.
##
##   godot --headless --path . --script src/dev/figure_index_probe.gd
##
## cffix2's mcp_agree (2026-11-12): "Invalid access to property or key
## '3816cpde' on a base object of type 'Dictionary'" in Minifig._index, from
## index_paced on the main thread. The warm-up's sort went through the
## index's tables (static Dictionaries) while a figure asked about on a worker
## (Assistant._checked's check, a file being written) sorted the library and
## cleared them under it. Here, as then: the index let go of (as a print made
## since lets it go), and made again on the main thread and on a worker at
## the same moment, while a second worker asks a part's role, its partner and
## a slot's choices all the while; each round, the tables are the size a
## whole index has, and partner and choices answer as before. Twelve rounds.
## A table cleared under a reader fails its read (a SCRIPT ERROR, the
## tables left short) or crashes the run. Exits non-zero on a failure.
extends SceneTree

var _failures: int = 0
var _reading: bool = false
var _read_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	library.load_catalogue()
	var started: int = Time.get_ticks_msec()
	Minifig._index(library)
	print("    the index, made once: %d ms" % (Time.get_ticks_msec() - started))
	var whole: Dictionary = _sizes()
	var pair: String = Minifig.partner(library, "3816c")
	var legs: int = Minifig.choices(library, "legs").size()
	print("    a whole index: %s; 3816c's partner %s; %d legs" % [JSON.stringify(whole), pair, legs])
	_check("a whole index has its figure parts, pairs and moulds", int(whole["slots"]) > 1000
		and int(whole["paired"]) > 100 and int(whole["moulds"]) > 10 and not pair.is_empty())
	var short := PackedStringArray()
	for round: int in 12:
		Minifig._index_of = 0
		_reading = true
		var reader: int = WorkerThreadPool.add_task(_read.bind(library), false, "figure_index reader")
		var maker: int = WorkerThreadPool.add_task(func() -> void: Minifig._index(library), false,
			"figure_index maker")
		Minifig._index(library)
		while not WorkerThreadPool.is_task_completed(maker):
			await process_frame
		WorkerThreadPool.wait_for_task_completion(maker)
		_reading = false
		WorkerThreadPool.wait_for_task_completion(reader)
		var sizes: Dictionary = _sizes()
		var answered: bool = Minifig.partner(library, "3816c") == pair \
			and Minifig.choices(library, "legs").size() == legs
		if sizes != whole or not answered:
			short.append("round %d: %s%s" % [round + 1, JSON.stringify(sizes),
				"" if answered else ", partner or choices changed"])
	print("    %d reads beside the makers" % _read_count)
	_check("made on two threads at once and read meanwhile, every round's index is whole (%s)"
		% ("; ".join(short) if not short.is_empty() else "12 rounds"), short.is_empty())
	print("\nfigure_index: %s" % ("%d FAILED" % _failures if _failures > 0 else "all passed"))
	quit(1 if _failures > 0 else 0)


## A worker asking about figures while the index is made.
func _read(library: PartLibrary) -> void:
	while _reading:
		Minifig.role_of("3816c")
		Minifig.partner(library, "3818")
		Minifig.choices(library, "hands")
		Minifig.offered(library)
		_read_count += 1


## The index's tables' sizes, read with no other thread about.
func _sizes() -> Dictionary:
	return {"slots": Minifig._slot_of.size(), "paired": Minifig._paired.size(),
		"moulds": Minifig._family_pairs.size(), "names": Minifig._by_name.size()}
