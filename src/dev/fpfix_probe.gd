## fpfix: Edit › Finish the surfaces… as its review (fpreview) attacked it,
## a case for each finding, each failing at b236ab7d9:
##   reopen    closed mid-read and opened again, no frame over 100 ms of its
##             own (H1: the second reading ran whole, 9,597 ms)
##   openwhile another model opened mid-read: the bar shows that model's own
##             findings, then and opened again twice (M1: 0 of the house's 22)
##   ghost     the ghost taken down or read again after an open, an Undo and
##             another's edit (M2)
##   subs      Lay keeps each sub-model's parts: a swap's parts stand in the
##             sub-model and step of the parts they replace, no line but
##             parts lost, a count per sub-model and step before and after
##             (M3: the castle's curtain walls 40 -> 38)
##   laytime   Lay on Orthanc and 10179, no frame over 100 ms of its own, the
##             status bar counting the parts, one undo, back byte for byte
##             (M5: 182-205 ms)
##   phone     (-- --phone) at 390 x 844 the bar is a sheet under the model,
##             the ghost in sight above it, Lay and the ticks a finger's
##             size (M4: the bar covered the screen)
##
##   godot --headless --path . --script src/dev/fpfix_probe.gd
##   ... -- --phone        the phone case only; FP_PHONE=430x932 at that size
##   FPF_CASES=reopen,ghost  only these
##   FP_SHOTS=DIR          windowed: the phone's sheet as a picture
extends "res://src/dev/finishpass_probe.gd"

## The models with sub-models of finishpass' 10 and fpreview's 14.
const SUBS: Array = ["res://src/dev/fixtures/metalines/apps.mpd",
	"res://src/dev/fixtures/metalines/sub_pic.mpd", "res://src/dev/fixtures/metalines/drive.ldr",
	"res://src/dev/fixtures/house/robot.ldr", "res://src/dev/fixtures/copyfaults_wing.ldr",
	"res://src/dev/fixtures/copyfaults_nest.mpd", "res://src/dev/fixtures/telescope.mpd",
	"res://src/dev/fixtures/keep_text_notes.mpd", "res://src/dev/fixtures/stepnames/row.ldr",
	"res://src/dev/fixtures/cfc_wing2.ldr", "res://src/dev/fixtures/kt3r_whole.mpd",
	"res://models/castle.ldr", "res://models/station.ldr", "res://models/orrery.ldr",
	"res://models/house.ldr", "res://models/car.ldr", "res://models/corner_shop.ldr",
	"res://models/kart.ldr", "res://models/lighthouse.ldr"]


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_finger = args.has("--phone")
	if _finger:
		Phone._on = 1
		Phone._wide = false
	_shots = OS.get_environment("FP_SHOTS") if DisplayServer.get_name() != "headless" else ""
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	if _finger:
		await _as_finger()
		await _case_phone_sheet()
	else:
		var cases: String = OS.get_environment("FPF_CASES")
		if cases.is_empty():
			cases = "reopen,openwhile,ghost,held,subs,laytime"
		for name: String in cases.split(","):
			print("\n== %s" % name)
			match name:
				"held": await _case_held()
				"reopen": await _case_reopen()
				"openwhile": await _case_open_while()
				"ghost": await _case_ghost()
				"subs":
					for path: String in SUBS:
						await _case_subs(path)
				"laytime":
					for path: String in BIG:
						await _case_lay_time(path)
	print("\n".join(_summary))
	print("fpfix: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _open_model(path: String, name: String) -> void:
	await _open(FileAccess.get_file_as_string(path))
	_set_name(name)
	await _frames(10)


## The frames' longest own work since [param frames] was added, and how
## many were over 100 ms, each printed.
func _longest(frames: ProbeTime.Frames, what: String) -> Array:
	var longest: float = 0.0
	var over: int = 0
	for frame: Array in frames.work:
		var own: float = float(frame[1]) - float(frame[2])
		longest = maxf(longest, own)
		if own > 100.0:
			over += 1
			print("    %s: over 100 ms, %.1f ms own, at %s" % [what, own, str(frame[3])])
	return [longest, over]


func _labelled() -> ProbeTime.Frames:
	var frames := ProbeTime.Frames.new()
	frames.label = func() -> String:
		var job: Working.Job = Working.current()
		var made: Node = _main.get("_finish_made") if _main != null else null
		return (job.words if job != null else "") + " | " + (str(made.get("phase")) if made != null else "")
	root.add_child(frames)
	return frames


# -- H1 ---------------------------------------------------------------------------------


## Closed while it reads, then opened again: the second reading waits for
## the first to stop, and neither runs whole on the main thread.
func _case_reopen() -> void:
	await _open_model("res://models/orthanc.ldr", "orthanc")
	var frames: ProbeTime.Frames = _labelled()
	Fiber.long_stretches = []
	_shell.run("finish_surfaces")
	await _frames(30)
	var bar: FinishBar = _main.get("_finish_made")
	print("  reading: busy %s phase %s fiber busy %s" % [bar.busy, bar.phase, Fiber.busy()])
	bar.close()
	var closed_at: int = Time.get_ticks_msec()
	await _frames(2)
	_shell.run("finish_surfaces")
	await _frames(2)
	await _until(func() -> bool: return not bar.busy and bar.visible, 600000)
	await _frames(4)
	var took: int = Time.get_ticks_msec() - closed_at
	var timed: Array = _longest(frames, "reopen")
	frames.queue_free()
	for stretch: Array in Fiber.long_stretches:
		print("    a stretch of %.1f ms with no pause, from %s to %s" % stretch)
	_check("reopen: closed while reading and opened again, read in %d ms, the longest frame %.1f ms of its own"
		% [took, float(timed[0])], int(timed[1]) == 0 and bar.read_at == _world.revision)
	_check("reopen: shows the model's findings (%d placements)" % _signatures(bar).size(),
		_signatures(bar).size() == _plain_signatures("orthanc").size())
	# And closed mid-read again: the reading stops within a few turns.
	bar.refresh()
	await _frames(40)
	var stop_frames: ProbeTime.Frames = _labelled()
	var stopped_at: int = Time.get_ticks_msec()
	bar.close()
	await _until(func() -> bool: return not Fiber.busy(), 600000)
	var stop_ms: int = Time.get_ticks_msec() - stopped_at
	var stop_timed: Array = _longest(stop_frames, "stopping")
	print("  KNOWN reopen: a reading stopped mid-way ended in %d ms over %d frames, the longest %.1f ms own"
		% [stop_ms, stop_frames.work.size(), float(stop_timed[0])])
	stop_frames.queue_free()
	_check("reopen: closed mid-read, the reading stops, no frame over 100 ms (%d ms)" % stop_ms,
		not Fiber.busy() and int(stop_timed[1]) == 0)


## What the AI's own reading (find() on the main thread) would lay on the
## model as it stands.
func _plain_signatures(name: String) -> Dictionary:
	var reader: Assistant = Assistant.new()
	reader.library = _library
	reader.world = _world
	reader.builder = _builder
	reader.scenery = _store.scenery
	reader._named_as = name
	var plain: Dictionary = {}
	for one: SurfacePass.Finding in SurfacePass.new(reader).find():
		for raw: Variant in one.add:
			plain[_signature(raw)] = true
	reader.free()
	return plain


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.size() == b.size() and a.keys().all(func(key: Variant) -> bool: return b.has(key))


# -- M1 ---------------------------------------------------------------------------------


func _case_open_while() -> void:
	await _open_model("res://models/orthanc.ldr", "orthanc")
	var frames: ProbeTime.Frames = _labelled()
	_shell.run("finish_surfaces")
	await _frames(40)
	var bar: FinishBar = _main.get("_finish_made")
	print("  reading orthanc: busy %s fiber %s" % [bar.busy, Fiber.busy()])
	await _open_model("res://models/house.ldr", "house")
	await _until(func() -> bool: return not bar.busy and not Fiber.busy(), 600000)
	await _frames(10)
	var timed: Array = _longest(frames, "openwhile")
	frames.queue_free()
	var plain: Dictionary = _plain_signatures("house")
	var shown: Dictionary = _signatures(bar)
	_check("openwhile: after another model opened mid-read, the bar shows (visible %s) %d placements, the house's own %d, the longest frame %.1f ms own"
		% [bar.visible, shown.size(), plain.size(), float(timed[0])],
		bar.visible and _same(plain, shown) and bar.read_at == _world.revision and int(timed[1]) == 0)
	bar.close()
	await _frames(4)
	for n: int in 2:
		var again: FinishBar = await _open_bar()
		var count: int = _signatures(again).size() if again != null else -1
		_check("openwhile, opened again (%d): the house shows %d placements (%d its own)" % [n + 1,
			count, plain.size()], again != null and _same(plain, _signatures(again)))
		if again != null:
			again.close()
		await _frames(4)


# -- M2 ---------------------------------------------------------------------------------


func _visible_ghosts(bar: FinishBar) -> int:
	var n: int = 0
	for kind: Variant in bar._ghosts:
		var holder: Node3D = bar._ghosts[kind]
		if is_instance_valid(holder) and holder.is_inside_tree() and holder.is_visible_in_tree():
			n += holder.get_child_count()
	return n


## What's held when Lay is pressed: parts carried are never laid round or
## lost; Lay says to put them down first and changes nothing, and once they
## are put back Lay lays as one undo.
func _case_held() -> void:
	await _open_model("res://models/house.ldr", "house")
	var bar: FinishBar = await _open_bar()
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var two: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if two.size() < 2 and not _store.scenery.has(brick.id):
			two.append(brick.id)
	_builder.selection.clear()
	for id: int in two:
		_builder.selection[id] = true
	_builder.lift_selection()
	# Lifted, the model changed: the bar reads it again before Lay is offered.
	await _frames(4)
	await _until(func() -> bool: return not bar.busy, 300000)
	var carrying: bool = _builder.is_carrying()
	var said: Array = []
	var was_say: Callable = bar.say
	bar.say = func(line: String) -> void:
		said.append(line)
		was_say.call(line)
	var laid: Dictionary = await bar.lay_now()
	var still: bool = _builder.is_carrying()
	_builder.cancel_carry()
	await _frames(4)
	_check("held: Lay with %d parts in hand lays nothing and says so (%s), the parts still in hand (%s), back where they were after"
		% [two.size(), "; ".join(said), still],
		carrying and laid.is_empty() and still and not said.is_empty()
		and _store.saved_text() == before)
	bar = await _open_bar()
	await bar.lay_now()
	await _frames(4)
	var one: bool = _builder.history_depth() == depth + 1
	await _undo()
	_check("held: put back, Lay lays as one undo step (%s) and Undo puts the file back byte for byte" % one,
		one and _store.saved_text() == before)
	bar.say = was_say
	bar.close()


## The ghost's pieces as they are now.
func _ghost_pieces(bar: FinishBar) -> Array:
	var out: Array = []
	for kind: Variant in bar._ghosts:
		var holder: Node3D = bar._ghosts[kind]
		if is_instance_valid(holder):
			out.append_array(holder.get_children())
	return out


## How many of [param pieces] are still drawn.
static func _shown_of(pieces: Array) -> int:
	var n: int = 0
	for piece: Variant in pieces:
		if is_instance_valid(piece) and (piece as Node3D).is_inside_tree() \
				and (piece as Node3D).is_visible_in_tree():
			n += 1
	return n


## Down, or drawn for the model as it now stands: the findings shown read
## at the world's revision, and what they lay the AI's own reading's.
func _ghost_true(bar: FinishBar, name: String) -> bool:
	if _visible_ghosts(bar) == 0:
		return true
	return bar.read_at == _world.revision and not bar.busy \
		and _same(_signatures(bar), _plain_signatures(name))


func _case_ghost() -> void:
	await _open_model("res://models/house.ldr", "house")
	var bar: FinishBar = await _open_bar()
	print("  shown: %d ghost pieces, bar visible %s" % [_visible_ghosts(bar), bar.visible])
	# Another model opened, as File › Open does: the house's ghost is
	# watched frame by frame, as the car's own may be up again soon after.
	var old: Array = _ghost_pieces(bar)
	var watch: Dictionary = {"generation": _world.generation(), "late": 0, "changed_at": -1, "frame": 0}
	var watcher := func() -> void:
		watch["frame"] = int(watch["frame"]) + 1
		if int(watch["changed_at"]) < 0 and _world.generation() != int(watch["generation"]):
			watch["changed_at"] = int(watch["frame"])
		# The frame after the one the world changed in: none of it drawn.
		if int(watch["changed_at"]) >= 0 and int(watch["frame"]) > int(watch["changed_at"]) \
				and _shown_of(old) > 0:
			watch["late"] = int(watch["late"]) + 1
	process_frame.connect(watcher)
	await _open_model("res://models/car.ldr", "car")
	await _until(func() -> bool: return not bar.busy, 300000)
	await _frames(4)
	process_frame.disconnect(watcher)
	_check("ghost: down the frame another model opens (%d of %d pieces drawn after, over %d frames), then the car's own (read_at %d, revision %d)"
		% [_shown_of(old), old.size(), int(watch["late"]), bar.read_at, _world.revision],
		old.size() > 0 and int(watch["changed_at"]) >= 0 and int(watch["late"]) == 0
		and _ghost_true(bar, "car"))
	bar.close()
	# An edit, then Undo, while the ghost is shown.
	await _open_model("res://models/house.ldr", "house")
	var some: int = int(_world.bricks()[0].id)
	_builder.remove_brick_id(some)
	_main.call("_on_model_edited")
	await _frames(4)
	bar = await _open_bar()
	var shown: int = _visible_ghosts(bar)
	await _undo()
	var after_undo: int = _visible_ghosts(bar)
	await _until(func() -> bool: return not bar.busy, 300000)
	await _frames(4)
	_check("ghost: down after an Undo (%d pieces before, %d after), then read again (read_at %d, revision %d)"
		% [shown, after_undo, bar.read_at, _world.revision], after_undo == 0 and _ghost_true(bar, "house"))
	# A part put down by another (a Together peer's edit is a world change).
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(400, 0, 400))
	_builder.swap_bricks(PackedInt64Array(), [{"part": "3001", "color": 4, "at": at}])
	await _frames(2)
	var after_peer: int = _visible_ghosts(bar)
	await _until(func() -> bool: return not bar.busy, 300000)
	await _frames(4)
	_check("ghost: down after another's edit (%d), then read again (read_at %d, revision %d)"
		% [after_peer, bar.read_at, _world.revision], after_peer == 0 and _ghost_true(bar, "house"))
	bar.close()


# -- M3 ---------------------------------------------------------------------------------


## Each part line of [param text] counted by the FILE it is in and its step
## there: "file#step" -> count.
static func _per_step(text: String) -> Dictionary:
	var out: Dictionary = {}
	var file: String = "(main)"
	var step: int = 0
	for line: String in text.split("\n"):
		var plain: String = line.strip_edges()
		if plain.begins_with("0 FILE "):
			file = plain.substr(7)
			step = 0
		elif plain == "0 STEP" or plain.begins_with("0 ROTSTEP"):
			step += 1
		elif plain.begins_with("1 "):
			var key: String = "%s#%d" % [file, step]
			out[key] = int(out.get(key, 0)) + 1
	return out


## Each part line of [param text] counted by the copy an IN line names it
## in (LdrModel.IN_META, to the next IN line or the step's end), "" for a
## FILE's own: "file|copy" -> count.
static func _per_copy(text: String) -> Dictionary:
	var out: Dictionary = {}
	var file: String = "(main)"
	var copy: String = ""
	for line: String in text.split("\n"):
		var plain: String = line.strip_edges()
		if plain.begins_with("0 FILE "):
			file = plain.substr(7)
			copy = ""
		elif plain == "0 STEP" or plain.begins_with("0 ROTSTEP"):
			copy = ""
		elif plain.begins_with(LdrModel.IN_META):
			copy = plain.substr(LdrModel.IN_META.length()).strip_edges()
		elif plain.begins_with("1 "):
			var key: String = "%s|%s" % [file, copy]
			out[key] = int(out.get(key, 0)) + 1
	return out


## The world's parts by sub-model (Assemblies.path_of) and step.
func _per_path() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
		out[key] = int(out.get(key, 0)) + 1
	return out


static func _lines(text: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in text.split("\n"):
		out[line.strip_edges()] = int(out.get(line.strip_edges(), 0)) + 1
	return out


func _case_subs(path: String) -> void:
	var name: String = path.get_file().get_basename()
	if not FileAccess.file_exists(path):
		print("  (no %s)" % path)
		return
	await _open_model(path, name.replace("_", " "))
	var s0: String = _store.saved_text()
	var paths0: Dictionary = _per_path()
	var bar: FinishBar = await _open_bar()
	if bar == null:
		_check("subs %s: the bar read the model" % name, false)
		return
	if bar.counts().is_empty():
		print("  %s: nothing to finish" % name)
		bar.close()
		return
	for kind: String in FinishBar.KINDS:
		bar.set_kind(kind, true)
	# Each swap's parts, and the sub-model and step of the parts it takes off.
	var swaps: Array = []     ## [the parts it lays, {"path#step": true} of those it takes off]
	var removed_at: Dictionary = {}
	for kind: String in bar.found:
		for one: SurfacePass.Finding in bar.found[kind]:
			var places: Dictionary = {}
			for id: int in one.remove:
				var brick: BrickWorld.Brick = _world.get_brick(id)
				if brick != null:
					var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
					places[key] = true
					removed_at[key] = int(removed_at.get(key, 0)) + 1
			if not places.is_empty():
				var parts: Array = []
				for raw: Variant in one.add:
					parts.append([str(raw["part"]), bar._at(raw)])
				swaps.append([parts, places])
	var ids0: Dictionary = _ids()
	var laid: Dictionary = await bar.lay_now()
	await _frames(6)
	var s1: String = _store.saved_text()
	if int(laid.get("laid", 0)) == 0:
		print("  %s: nothing laid (%s)" % [name, str(laid.get("left", []))])
		bar.close()
		return
	var paths1: Dictionary = _per_path()
	var whole1: String = str(_store.last_whole)
	# Where each new part stands, by its place.
	var astray := PackedStringArray()
	var checked: int = 0
	for swap: Array in swaps:
		for pair: Array in swap[0]:
			var brick: BrickWorld.Brick = _new_brick_at(str(pair[0]), pair[1], ids0)
			if brick == null:
				continue
			checked += 1
			var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
			if not (swap[1] as Dictionary).has(key):
				astray.append("%s in %s, not %s" % [pair[0], key, ", ".join((swap[1] as Dictionary).keys())])
	_check("subs %s: a swap's %d parts each in the sub-model and step of a part it replaced (%s)"
		% [name, checked, "; ".join(astray.slice(0, 4)) if not astray.is_empty() else "all"],
		astray.is_empty())
	# No sub-model or step lost more than was taken off it.
	var short := PackedStringArray()
	for key: String in paths0:
		var lost: int = int(paths0[key]) - int(paths1.get(key, 0))
		if lost > int(removed_at.get(key, 0)):
			short.append("%s %d -> %d (%d taken off)" % [key, paths0[key], paths1.get(key, 0),
				removed_at.get(key, 0)])
	_check("subs %s: no sub-model or step lost a part not taken off (%s)" % [name,
		"; ".join(short.slice(0, 4)) if not short.is_empty() else "none"], short.is_empty())
	# A step left with none of its parts: each place that took from it, how
	# many parts it laid and from how many steps it took.
	var emptied := PackedStringArray()
	for key: String in paths0:
		if int(paths1.get(key, 0)) > 0:
			continue
		var by := PackedStringArray()
		for swap: Array in swaps:
			if (swap[1] as Dictionary).has(key):
				by.append("%d laid for %d steps" % [(swap[0] as Array).size(), (swap[1] as Dictionary).size()])
		emptied.append("%s (%s)" % [key, ", ".join(by)])
	if not emptied.is_empty():
		print("  KNOWN subs %s: steps all of whose parts were taken off: %s" % [name, "; ".join(emptied)])
	# In the file: every copy built in its parent's steps keeps its parts,
	# but those taken off it (an IN line's copy is its path).
	var taken_by_path: Dictionary = {}
	for key: String in removed_at:
		var at: String = key.left(key.rfind("#"))
		taken_by_path[at] = int(taken_by_path.get(at, 0)) + int(removed_at[key])
	var copies0: Dictionary = _per_copy(s0)
	var copies1: Dictionary = _per_copy(s1)
	var fewer := PackedStringArray()
	for key: String in copies0:
		var copy: String = key.get_slice("|", 1)
		var lost: int = int(copies0[key]) - int(copies1.get(key, 0))
		if not copy.is_empty() and lost > int(taken_by_path.get(copy, 0)):
			fewer.append("%s %d -> %d (%d taken off)" % [copy, copies0[key], copies1.get(key, 0),
				taken_by_path.get(copy, 0)])
	_check("subs %s: saved, every copy built in steps keeps its parts but those taken off (%s)"
		% [name, "; ".join(fewer.slice(0, 4)) if not fewer.is_empty() else "all"], fewer.is_empty())
	var before: Dictionary = _lines(s0)
	var after: Dictionary = _lines(s1)
	var lost_lines := PackedStringArray()
	var lost_in := PackedStringArray()
	for line: String in before:
		if not line.begins_with("1 ") and int(after.get(line, 0)) < int(before[line]):
			if line.begins_with(LdrModel.IN_META):
				lost_in.append("%s %d -> %d" % [line.substr(LdrModel.IN_META.length() + 1),
					before[line], after.get(line, 0)])
			else:
				lost_lines.append(line.left(90))
	_check("subs %s: no line but parts and steps' IN lines lost by Lay (%s)"
		% [name, " || ".join(lost_lines.slice(0, 4))], lost_lines.is_empty())
	if not lost_in.is_empty() or not whole1.is_empty():
		# Written whole, the file's steps are numbered afresh (AuthorSteps):
		# a copy's parts come in fewer runs, each named by its IN line.
		print("  KNOWN subs %s: written whole because %s; IN lines fewer: %s" % [name,
			whole1 if not whole1.is_empty() else "(a patch)", ", ".join(lost_in)])
	# The count per sub-model and step, saved, before and after.
	var steps0: Dictionary = _per_step(s0)
	var steps1: Dictionary = _per_step(s1)
	var changed := PackedStringArray()
	var keys: Array = steps0.keys()
	for key: Variant in steps1:
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	for key: Variant in keys:
		if int(steps0.get(key, 0)) != int(steps1.get(key, 0)):
			changed.append("%s %d->%d" % [key, steps0.get(key, 0), steps1.get(key, 0)])
	print("  KNOWN subs %s: laid %d parts in %d places (%d taken off); saved per sub-model and step: %s"
		% [name, int(laid.get("parts", 0)), int(laid.get("laid", 0)), int(laid.get("taken", 0)),
		", ".join(changed)])
	await _undo()
	_check("subs %s: Undo back byte for byte" % name, _store.saved_text() == s0)
	# Saved after Lay and opened again: the same file, and why each save
	# was written whole (fpreview's reopen fails on the castle and the
	# station with a part taken off by hand too).
	await _open(s1)
	await _frames(6)
	var reopened: String = _store.saved_text()
	if reopened != s1:
		print("  KNOWN subs %s: saved after Lay (whole: %s), opened again, saved (whole: %s): not the same file"
			% [name, whole1, str(_store.last_whole)])
		_first_diff(s1, reopened)


func _new_brick_at(part: String, at: Transform3D, before: Dictionary) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id) and brick.part_id == part \
				and brick.transform.origin.distance_to(at.origin) < 0.5:
			return brick
	return null


# -- M5 ---------------------------------------------------------------------------------


func _case_lay_time(path: String) -> void:
	var name: String = path.get_file().get_basename()
	await _open_model(path, name)
	var bar: FinishBar = await _open_bar()
	if not _check("laytime %s: the bar read the model" % name, bar != null):
		return
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var frames: ProbeTime.Frames = _labelled()
	var began: int = Time.get_ticks_msec()
	var laid: Dictionary = await bar.lay_now()
	var took: int = Time.get_ticks_msec() - began
	await _frames(8)
	var timed: Array = _longest(frames, "lay " + name)
	var said: bool = false
	for frame: Array in frames.work:
		said = said or str(frame[3]).begins_with("Laying the finish")
	frames.queue_free()
	_check("laytime %s: laid %d parts in %d places in %d ms over %d frames, the longest %.1f ms of its own, the status bar saying so"
		% [name, int(laid.get("parts", 0)), int(laid.get("laid", 0)), took, frames.work.size(),
		float(timed[0])], int(laid.get("parts", 0)) > 0 and int(timed[1]) == 0 and said)
	_summary.append("SUMMARY laytime %s: %d parts, %d ms, longest %.1f ms own" % [name,
		int(laid.get("parts", 0)), took, float(timed[0])])
	_check("laytime %s: one undo step" % name, _builder.history_depth() == depth + 1)
	await _undo()
	_check("laytime %s: Undo puts it back byte for byte" % name,
		_store.saved_text() == before and _builder.history_depth() == depth)


# -- M4 ---------------------------------------------------------------------------------


## At a phone's size the bar is a sheet under the model: on the screen, the
## ghost's pieces seen above it in the model's room, Lay and each tick a
## finger's size; Lay pressed lays it as one undo.
func _case_phone_sheet() -> void:
	await _make("g3 house")
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var bar: FinishBar = await _open_bar()
	if not _check("phone: the bar read the model", bar != null):
		return
	await _frames(30)
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var shown: Rect2 = bar.get_global_rect()
	_check("phone: the bar on the screen (%s in %s)" % [shown, screen], screen.grow(0.5).encloses(shown))
	var camera: Camera3D = _main.get("_camera")
	var room: Rect2 = _main.call("_model_rect")
	var seen: int = 0
	var pieces: int = 0
	for kind: Variant in bar._ghosts:
		var holder: Node3D = bar._ghosts[kind]
		if not holder.is_visible_in_tree():
			continue
		for piece: Node in holder.get_children():
			var mesh: MeshInstance3D = piece
			pieces += 1
			var middle: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
			if camera.is_position_behind(middle):
				print("    a piece behind the eye: %s" % middle)
				continue
			var at: Vector2 = camera.unproject_position(middle)
			print("    a piece at %s on the screen (%s in the world)" % [at, middle])
			if screen.has_point(at) and room.has_point(at) and not shown.has_point(at):
				seen += 1
	_check("phone: the ghost in sight above the bar (%d of %d pieces in the model's room %s, none under the bar %s)"
		% [seen, pieces, room, shown], pieces > 0 and seen == pieces and not shown.intersects(room.grow(-1.0)))
	var small: PackedStringArray = PackedStringArray()
	var targets: Array = [bar._lay, bar._close]
	for kind: String in bar._ticks:
		if (bar._ticks[kind] as CheckBox).visible:
			targets.append(bar._ticks[kind])
	for target: Control in targets:
		if target.size.y < FinishBar.FINGER - 0.5 or target.size.x < FinishBar.FINGER - 0.5:
			small.append("%s %s" % [target.name, target.size])
		elif not screen.grow(0.5).encloses(target.get_global_rect()):
			small.append("%s off the screen at %s" % [target.name, target.get_global_rect()])
	_check("phone: Lay, Close and %d ticks a finger's size, on the screen (%s)" % [targets.size() - 2,
		", ".join(small) if not small.is_empty() else "all 44 points or more"], small.is_empty())
	await _shot("phone_sheet")
	bar._lay.pressed.emit()
	await _until(func() -> bool: return not bar.busy and not bar.visible, 60000)
	_check("phone: Lay pressed lays it as one undo step", _builder.history_depth() == depth + 1)
	await _undo()
	_check("phone: Undo puts the file back byte for byte",
		_store.saved_text() == before and _builder.history_depth() == depth)
