## Prove GDScript run on several worker threads at once has run once on one
## thread first (WorkerTasks.first_here), and that this is what keeps the
## engine up.
##
##   godot --headless --path . --script src/dev/worker_first_run_probe.gd \
##     [-- rounds=N] [-- cold]
##
## The engine writes into a function's bytecode the first time each of its
## operators on a value of no fixed type runs, the operand types before the
## function that does it (gdscript_vm.cpp:805-809), and a thread at the same
## operator in between calls address 0. Here: a script compiled fresh each
## round, every operator cold, run by every worker thread let go at the same
## instant. Through first_here, every round must come back right. With
## -- cold the rounds skip first_here: that is the engine as it is, and it
## crashes (SIGSEGV, rip 0x0, a worker's backtrace at the operator), 2 runs
## of 2 within 4,000 rounds on a 24-thread box (crashfind, 2026-10-17).
##
## Then the app's own: PartForge.warm builds its part and its skin all the
## way through (a warm-up that stopped early would leave the rest of the
## forge cold), and the first carried parts built at once in a run have
## the forge run here first.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var rounds: int = 1500
	var cold: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("rounds="):
			rounds = int(arg.substr(7))
		elif arg == "cold":
			cold = true
	_operators_at_once(rounds, cold)
	_forge_warmed()
	print("")
	print("worker first run: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _operators_at_once(rounds: int, cold: bool) -> void:
	print("operators run for the first time on every worker at once%s"
		% (", cold (the engine as it is)" if cold else ""))
	var sites: int = 16
	var threads: int = OS.get_processor_count()
	var obj := RefCounted.new()
	var other := RefCounted.new()
	var began: int = Time.get_ticks_msec()
	var wrong: int = 0
	for r: int in rounds:
		# Each round's text its own, so nothing of it is compiled already.
		var body := PackedStringArray(["extends RefCounted\n# round %d\n" % r,
			"static func run(o: Object, p: Object) -> int:\n\tvar n: int = 0\n"])
		for i: int in sites:
			body.append("\tif o == null:\n\t\tn += 1\n\tif o != p:\n\t\tn += 2\n")
		body.append("\treturn n\n")
		var script := GDScript.new()
		script.source_code = "".join(body)
		if script.reload() != OK:
			_check("round %d compiles" % r, false)
			return
		var run: Callable = func() -> void: script.call("run", obj, other)
		if not cold:
			WorkerTasks.first_here("probe round %d" % r, run)
		var go: Array = [0]
		var results: Array = []
		results.resize(threads)
		var task: int = WorkerThreadPool.add_group_task(func(n: int) -> void:
			var at: int = go[0]
			while at == 0:
				at = go[0]
			results[n] = script.call("run", obj, other), threads, -1, true, "probe operators")
		OS.delay_usec(1500)
		go[0] = 1
		WorkerThreadPool.wait_for_group_task_completion(task)
		for got: Variant in results:
			if got != sites * 2:
				wrong += 1
	_check("%d rounds of %d cold operators on %d threads let go at once: none came back wrong (%d), and the engine is still here (%d ms)"
		% [rounds, sites * 2, threads, wrong, Time.get_ticks_msec() - began], wrong == 0)


func _forge_warmed() -> void:
	print("the forge run once here before its workers")
	var began: int = Time.get_ticks_usec()
	var made: Array[PartForge.Result] = PartForge.warm()
	var ms: float = (Time.get_ticks_usec() - began) / 1000.0
	var part: PartForge.Result = made[0]
	var skin: PartForge.Result = made[1]
	_check("its part builds all the way: %s, %d triangles, connectors %s, %d boxes (%.1f ms for both)"
		% ["no problem" if part.problem.is_empty() else part.problem, part.triangles,
			part.connector_counts, part.boxes.size(), ms],
		part.problem.is_empty() and part.boxes.size() > 0
		and int(part.connector_counts.get("stud", 0)) == 2
		and int(part.connector_counts.get("pin_hole", 0)) >= 1
		and part.connector_counts.has("tube"))
	_check("its skin builds all the way: %s, %d triangles, %d boxes"
		% ["no problem" if skin.problem.is_empty() else skin.problem, skin.triangles,
			skin.boxes.size()],
		skin.problem.is_empty() and skin.boxes.size() > 1)
	# The app's first carried parts built at once in this run.
	var before: bool = WorkerTasks._run_here.has("the forge")
	var texts: Dictionary = {"probe-a.dat": PartForge.WARM_PART.replace("brickworks-warm", "probe-a"),
		"probe-b.dat": PartForge.WARM_PART.replace("brickworks-warm", "probe-b")}
	var others: Dictionary = {"s\\probe-a-s01.dat": PartForge.WARM_SUB,
		"s\\probe-b-s01.dat": PartForge.WARM_SUB}
	var built: Dictionary = CustomParts._built_at_once(texts, others)
	_check("carried parts built at once had the forge run here first (not before: %s, after: %s), and built (%d)"
		% [before, WorkerTasks._run_here.has("the forge"), built.size()],
		not before and WorkerTasks._run_here.has("the forge") and built.size() == 2)
