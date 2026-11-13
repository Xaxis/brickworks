## smalls1 review: Minifig's compiled patterns (_patterns) are made and read
## under Minifig._lock, flat_of's too: it read and wrote the table with no
## lock, and failed here 3 of 3 with a double free (10f375551) until it asked
## Minifig._regex as the rest do. Here a worker compiles patterns under the lock, as
## a figure asked about on a worker does the first time it meets one
## (_regex: role_of's "^973...", _hand_moulded_on's), while the main thread
## asks for a worn cape's flat drawing the first time each round (its entry
## taken out under the lock first). First through _regex, as the rest of the
## file asks (the control), then through flat_of. A table
## changed on two threads at once is read wrong or crashes: a wrong answer, a
## script error, or the run dies. Exits non-zero on a failure.
##
##   godot --headless --path . --script src/dev/s1r_flat_race_probe.gd -- [--phases=locked,flat_of]
extends SceneTree

const FORMED := "^(.+)c\\d\\d$"

var _going: bool = true
var _made: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	library.load_catalogue()
	var cape: PartLibrary.PartInfo = null
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.name.contains("(Formed") and RegEx.create_from_string(FORMED).search(id) != null:
			cape = info
			break
	if cape == null:
		print("no formed cape in the catalogue")
		quit(2)
		return
	var want: String = Minifig.flat_of(cape)
	print("    %s (%s): flat_of says %s" % [cape.id, cape.name, want])
	var failures: int = 0
	var phases: Array = ["locked", "flat_of"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phases="):
			phases = Array(arg.substr(9).split(","))
	for how: String in phases:
		_going = true
		_made = 0
		var maker: int = WorkerThreadPool.add_task(_make, false, "s1r pattern maker")
		var wrong: int = 0
		var asked: int = 0
		var began: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - began < 15000:
			Minifig._lock.lock()
			Minifig._patterns.erase("formed")
			Minifig._patterns.erase(FORMED)
			Minifig._lock.unlock()
			var got: String
			if how == "locked":
				var found: RegExMatch = Minifig._regex(FORMED).search(cape.id)
				got = found.get_string(1) if found != null else ""
			else:
				got = Minifig.flat_of(cape)
			if got != want:
				wrong += 1
			asked += 1
		_going = false
		WorkerThreadPool.wait_for_task_completion(maker)
		var ok: bool = wrong == 0
		print("  %s  %s: %d asks beside %d patterns made on a worker, %d wrong" % [
			"ok  " if ok else "FAIL", how, asked, _made, wrong])
		if not ok:
			failures += 1
	print("\ns1r_flat_race: %s" % ("%d FAILED" % failures if failures > 0 else "all passed"))
	quit(1 if failures > 0 else 0)


func _make() -> void:
	var n: int = 0
	while _going:
		Minifig._matches("3816c", "^s1r_%d$" % n)
		n += 1
		if n % 4096 == 0:
			# Kept small, so the table grows and is made again over and over.
			Minifig._lock.lock()
			for key: Variant in Minifig._patterns.keys():
				if str(key).begins_with("^s1r_"):
					Minifig._patterns.erase(key)
			Minifig._lock.unlock()
	_made = n
