## Does a static table read for the first time on a worker and on the main
## thread at the same instant leave the app up?
##
##   godot --headless --path . --script src/dev/table_race_probe.gd \
##     [-- --tries=N] [-- --only=mechanism,...]
##
## As a model of 600 parts or more opens, Grab reads its joints on a worker
## (GrabDrag "read the model's joints"), which asks Mechanism for each part's
## gear. A session's look_at_model, on the main thread, asks it for the
## turntables (Assistant._joint_lines). The first to ask read the gear table
## from its file and put it in a static var; both asked at once, both read
## it, and the second to put its own in freed the first's while the other
## thread was copying it. The copy came out holding nothing, and its
## is_empty() read address 0x34: signal 11 on the main thread at
## mechanism.gd:78 (Dubai, 750 parts, 1 run of 8; racefix, 2026-10-20).
##
## Each try is a run of the engine of its own, as a static is read for the
## first time once a run: a worker and the main thread let go at the same
## instant, each asking as the app does for 30 ms. Pass: every try's run
## exits 0 and says it was still up. Then the same for the tables like it a
## worker reaches: Flex's pieces (Grab's reading and Balance's weigh on a
## worker, the counts line here) and Style's norms (a build's check).
extends SceneTree

## What each table's two threads ask, as the app asks it: [the worker's,
## the main thread's], each given an index and saying how much it found.
var _askers: Dictionary = {
	"mechanism": [
		func(i: int) -> int: return Mechanism.spec_of(GEARS[i % GEARS.size()]).size(),
		func(_i: int) -> int: return (Mechanism.table().get("turntables", {}) as Dictionary).size()],
	# Its siblings: Balance's weigh and Grab's reading on a worker, the
	# counts line here; a build's check on a worker, and another here.
	"flex": [
		func(i: int) -> int: return Flex.kind_of_piece(PIECES[i % PIECES.size()]).length(),
		func(i: int) -> int: return Flex.kind_of_piece(PIECES[(i + 1) % PIECES.size()]).length()],
	"style": [
		func(_i: int) -> int: return Style.norms().size(),
		func(_i: int) -> int: return Style.norms().size()],
}

## Parts the gear table has, and one it has not.
const GEARS := ["3647", "10928", "3001", "99010", "18938", "4019"]
## Pieces of flexible things, and a part that is none.
const PIECES := ["71944k02", "71533k03", "3711", "3873", "3001"]
const ASK_USEC := 30000

var _failures: int = 0


func _initialize() -> void:
	var tries: int = 40
	var only: Array = _askers.keys()
	var child: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tries="):
			tries = maxi(int(argument.trim_prefix("--tries=")), 1)
		elif argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
		elif argument.begins_with("--child="):
			child = argument.trim_prefix("--child=")
	if not child.is_empty():
		_try(child)
		return
	for table: String in only:
		_tries(table, tries)
	print("")
	print("table race: %s" % ("every try stayed up" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _tries(table: String, tries: int) -> void:
	print("%s: read first on a worker and here at once, %d runs" % [table, tries])
	var died: int = 0
	## Where each died: the top of its GDScript backtrace -> runs.
	var where: Dictionary = {}
	var began: int = Time.get_ticks_msec()
	for t: int in tries:
		var said: Array = []
		var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://src/dev/table_race_probe.gd", "--", "--child=" + table]),
			said, true)
		var output: String = "".join(said)
		if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
			print(output.right(2000))
			_check("%s: a try ran with no script error" % table, false)
			return
		if code != 0 or not output.contains("STILL UP"):
			died += 1
			var top: String = "exit %d, no backtrace" % code
			var at: int = output.find("most recent call first):\n")
			if at >= 0:
				var lines: PackedStringArray = output.substr(at).split("\n")
				top = "exit %d at %s" % [code, lines[1].strip_edges() if lines.size() > 1 else "?"]
			where[top] = int(where.get(top, 0)) + 1
	_check("%s: %d of %d runs died, %d s" % [table, died, tries,
		(Time.get_ticks_msec() - began) / 1000], died == 0)
	for top: String in where:
		print("        %d  %s" % [where[top], top])


## One try, in this run of its own: the worker and this thread let go at
## once, the worker waited for, and each asking for [constant ASK_USEC], so
## one asks all the while the other reads its table.
func _try(table: String) -> void:
	var askers: Array = _askers[table]
	var on_worker: Callable = askers[0]
	var here: Callable = askers[1]
	# The worker says it is ready and waits on a lock held here, let go of
	# as this thread starts. Flags in an Array, set on one thread while the
	# other reads them, can be read as null (worker_first_run_probe).
	var ready := Semaphore.new()
	var gate := Mutex.new()
	var got: Array = [0]
	gate.lock()
	var task: int = WorkerTasks.add(func() -> void:
		ready.post()
		gate.lock()
		gate.unlock()
		var n: int = 0
		var i: int = 0
		var until: int = Time.get_ticks_usec() + ASK_USEC
		while Time.get_ticks_usec() < until:
			n += int(on_worker.call(i))
			i += 1
		got[0] = n, true, "probe: the worker's asks")
	ready.wait()
	gate.unlock()
	var n: int = 0
	var i: int = 0
	var until: int = Time.get_ticks_usec() + ASK_USEC
	while Time.get_ticks_usec() < until:
		n += int(here.call(i))
		i += 1
	WorkerTasks.collect(task)
	print("STILL UP %d %d" % [n, got[0]])
	quit(0)
