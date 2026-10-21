## A part whose fetch fails is asked again; a model short of one says so.
##
##   godot --headless --path . --script src/dev/fetch_retry_probe.gd
##
## Until 2026-10-20 a fetch that failed was never asked for again: a model
## opening with that part waited for it for ever, short of it, and nothing
## said so (m115's preview: the grab flow's 29-part crane opened without its
## 3709b on a loaded box). A phone's connection drops the same way.
##
## The library is pointed at nothing on disk, so every part is fetched, from
## a host this probe runs on 127.0.0.1:9191 (or the next port free; from
## another with `-- --port=N`) that
## answers from the checkout's assets/generated and fails on purpose: 3709b
## twice with a 503, 3673 once by cutting the connection (HTTP 0), 4519
## always 404, 3649 four times (one more than the library asks). Then the
## crane is opened, and:
##
## - each fault that may pass is asked again, after 2, 6 and 12 s, and a 404
##   once only; what arrives late is put down;
## - nothing is asked twice: a part asked for while it waits joins the wait;
## - once nothing else is on its way, the status bar says once how many parts
##   could not be loaded and that they are kept in the file;
## - Save writes the file whole, the parts that did not come too; one asked
##   for again later is put down, and the bar does not say it again;
## - the same for a file the app wrote itself, which is written whole rather
##   than back from the file;
## - an exact shape is asked again the same way, and a 404 for one once;
## - the working model short of 4519 is autosaved after a change nobody made
##   by hand, 4519 in it where the file had it, and reopened from it with the
##   change, 4519 awaited and put down when it comes (someone else's file and
##   the app's own); until 2026-10-20 nothing of a model short of a part was
##   autosaved;
## - a whole working model reopened while its parts are on their way is never
##   written back short of them, at once or after a change.
extends SceneTree

const PORT := 9191
const CRANE := [
	"0 Grab crane",
	"0 Name: grab_crane.ldr",
	"1 71 0 0 0 1 0 0 0 1 0 0 0 1 3031.dat",
	"1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat",
	"1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat",
	"1 15 0 -32 0 1 0 0 0 1 0 0 0 1 3937.dat",
	"1 4 0 -32 0 1 0 0 0 1 0 0 0 1 3938.dat",
	"1 4 0 -40 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
	"1 71 200 0 0 1 0 0 0 1 0 0 0 1 32278.dat",
	"1 14 240 -20 -60 0 0 1 0 1 0 -1 0 0 32316.dat",
	"1 14 240 -20 60 0 0 1 0 1 0 -1 0 0 32316.dat",
	"1 4 280 -40 0 1 0 0 0 1 0 0 0 1 32524.dat",
	"1 0 200 -10 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
	"1 0 200 -10 60 0 -1 0 1 0 0 0 0 1 3673.dat",
	"1 0 280 -30 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
	"1 0 280 -30 60 0 -1 0 1 0 0 0 0 1 3673.dat",
	"1 4 -120 -24 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -120 -48 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -120 -72 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -120 -96 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -120 -120 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -120 -144 10 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 7 -120 -168 0 1 0 0 0 1 0 0 0 1 3701.dat",
	"1 0 -120 -158 -10 0 0 -1 0 1 0 1 0 0 3673.dat",
	"1 14 -120 -98 -20 -1 0 0 0 0 1 0 1 0 32524.dat",
	"1 4 -300 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -300 -48 0 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 4 -300 -72 0 1 0 0 0 1 0 0 0 1 3001.dat",
	"1 7 -300 -80 0 1 0 0 0 1 0 0 0 1 3709b.dat",
	"1 0 -300 -102 0 0 -1 0 1 0 0 0 0 1 4519.dat",
	"1 7 -300 -112 0 1 0 0 0 0 1 0 -1 0 3649.dat",
]
const PARTS := 29

var _failures: int = 0
var _port: int = PORT
var _server := TCPServer.new()
var _peers: Array[Dictionary] = []
## File name -> [how, times]: answered so the first `times` asks (every ask
## when -1); how is an HTTP status, or 0 for a connection cut unanswered.
var _plan: Dictionary = {}
## File name -> when each ask came, msec.
var _asks: Dictionary = {}
var _library: PartLibrary
## What the status bar said, each time it was said.
var _said: PackedStringArray = PackedStringArray()
var _bar: ModelBar


func _initialize() -> void:
	_run()


## Each frame: the host answers, and what the bar said is read.
func _tick() -> void:
	_serve()
	if _bar != null:
		var label: Label = _bar._status
		if not label.text.is_empty():
			_said.append(label.text)
			# Taken down as soon as read, so saying it again is seen again.
			label.text = ""


func _run() -> void:
	await process_frame
	# The first port free from PORT, so two runs at once do not meet.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
	var first: int = _port
	while _server.listen(_port, "127.0.0.1") != OK:
		_port += 1
		if _port >= first + 9:
			print("  FAIL  could not listen on %d to %d" % [first, first + 8])
			quit(1)
			return
	process_frame.connect(_tick)
	_check("a fault that may pass is asked again, an answer is not",
		PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 0)
		and PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 503)
		and PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 408)
		and PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 429)
		and PartLibrary.may_pass(HTTPRequest.RESULT_TIMEOUT, 0)
		and PartLibrary.may_pass(HTTPRequest.RESULT_CANT_CONNECT, 0)
		and not PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 404)
		and not PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 400)
		and not PartLibrary.may_pass(HTTPRequest.RESULT_SUCCESS, 200))

	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	_library = main.get("_library")
	var world: BrickWorld = main.get("_world")
	var store: ModelStore = main.get("_store")
	_bar = main.get("_bar")
	# Once the deployment has said where parts live, or it would say so over
	# this host.
	var deployment: Deployment = main.get("_deployment")
	var asked_since: int = Time.get_ticks_msec()
	while not deployment.finished and Time.get_ticks_msec() - asked_since < 30_000:
		await process_frame
	# Nothing on disk: every part is fetched, as the web fetches what its
	# pack does not carry.
	_library._root = "user://no_parts/"
	_library.release_geometry()
	_library.remote_parts = "http://127.0.0.1:%d/" % _port

	var hash_of := func(part_id: String) -> String:
		return (_library.parts[part_id] as PartLibrary.PartInfo).mesh_hash + ".lbm"
	_plan[hash_of.call("3709b")] = [503, 2]
	_plan[hash_of.call("3673")] = [0, 1]
	_plan[hash_of.call("4519")] = [404, -1]
	_plan[hash_of.call("3649")] = [503, 4]

	var path: String = "user://grab_crane.ldr"
	_write(path, "\n".join(CRANE) + "\n")
	_said.clear()
	var opened_at: int = Time.get_ticks_msec()
	main._open(path)

	# Asked for again while it waits to be asked again: joins it.
	var gear: String = hash_of.call("3709b")
	while _asks.get(gear, []).size() < 1 and Time.get_ticks_msec() - opened_at < 10_000:
		await process_frame
	# Answered at once; asked again 2 s after.
	await _seconds(0.5)
	var waiting_on: bool = _library.is_on_its_way("3709b")
	for _n: int in 3:
		_library.request_mesh("3709b", true)
	_check("3709b, waiting to be asked again, is still on its way (%s), and asked for 3 more times "
		% waiting_on + "joins the wait: %d ask so far" % _asks.get(gear, []).size(),
		waiting_on and _asks.get(gear, []).size() == 1)

	# Until nothing is on its way.
	var deadline: int = Time.get_ticks_msec() + 60_000
	while Time.get_ticks_msec() < deadline and not store.awaited.all(
			func(p: LdrModel.Placement) -> bool: return not _library.is_on_its_way(p.part_id)):
		await process_frame
	await _seconds(0.5)
	var took: float = (Time.get_ticks_msec() - opened_at) / 1000.0
	print("  nothing on its way after %.1f s; asks: %s" % [took, _asks_said(hash_of)])

	_check("3709b asked 3 times (two 503s, then the part): %s" % _gaps(gear),
		_asks.get(gear, []).size() == 3 and _spaced(gear, [2.0, 6.0]))
	_check("3673 asked twice (the connection cut, then the part): %s" % _gaps(hash_of.call("3673")),
		_asks.get(hash_of.call("3673"), []).size() == 2 and _spaced(hash_of.call("3673"), [2.0]))
	_check("4519 asked once: a 404 is an answer (%d)" % _asks.get(hash_of.call("4519"), []).size(),
		_asks.get(hash_of.call("4519"), []).size() == 1)
	_check("3649 asked 4 times, over about 20 s, then given up: %s" % _gaps(hash_of.call("3649")),
		_asks.get(hash_of.call("3649"), []).size() == 4
		and _spaced(hash_of.call("3649"), [2.0, 6.0, 12.0]))
	_check("what came late is down: %d of %d bricks, 3709b and the 3673s among them"
		% [world.brick_count(), PARTS],
		world.brick_count() == PARTS - 2 and _has(world, "3709b") and _count(world, "3673") == 5)
	var told: PackedStringArray = _matching("could not be loaded")
	_check("the bar said it once: %s" % [told],
		told.size() == 1 and told[0] == "27 bricks — 2 parts could not be loaded, and are kept in the file")

	# Saved: the file whole.
	var saved: String = ModelStore.SAVE_DIR + "fetch_retry.ldr"
	_check("saved", store.save_file(saved, "Grab crane"))
	var written: Dictionary = _lines_in(FileAccess.get_file_as_string(saved))
	_check("the file is whole: %d parts, 4519 and 3649 among them, where they were" % _total(written),
		_total(written) == PARTS and written.get("4519", 0) == 1 and written.get("3649", 0) == 1
		and _where_it_was(FileAccess.get_file_as_string(saved), "4519")
		and _where_it_was(FileAccess.get_file_as_string(saved), "3649"))

	# Asked for again, later, the gear comes and goes down; nothing more said.
	_said.clear()
	_library.request_mesh("3649", true)
	deadline = Time.get_ticks_msec() + 10_000
	while not _has(world, "3649") and Time.get_ticks_msec() < deadline:
		await process_frame
	await _seconds(0.5)
	_check("3649 asked for again later is put down: %d bricks (%d asks); the bar said %s"
		% [world.brick_count(), _asks.get(hash_of.call("3649"), []).size(), _said],
		_has(world, "3649") and world.brick_count() == PARTS - 1
		and _matching("could not be loaded").is_empty())
	written = _lines_in(_saved_text(store, saved))
	_check("saved again, still whole: %d parts" % _total(written),
		_total(written) == PARTS and written.get("4519", 0) == 1)

	# A file the app wrote itself is written whole, not back from the file.
	var own: PackedStringArray = PackedStringArray(CRANE)
	own.insert(1, "0 Author: Brickworks")
	_write(path, "\n".join(own) + "\n")
	_said.clear()
	main._open(path)
	deadline = Time.get_ticks_msec() + 30_000
	while _matching("could not be loaded").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	await _seconds(0.5)
	told = _matching("could not be loaded")
	_check("the app's own file: %d bricks, and the bar said once %s" % [world.brick_count(), told],
		world.brick_count() == PARTS - 1 and told.size() == 1
		and told[0] == "28 bricks — 1 part could not be loaded, and is kept in the file")
	var own_saved: String = _saved_text(store, saved)
	written = _lines_in(own_saved)
	_check("the app's own file saved whole: %d parts, 4519 among them, where it was" % _total(written),
		_total(written) == PARTS and written.get("4519", 0) == 1 and _where_it_was(own_saved, "4519"))

	# Exact shapes: the same way.
	var shape_of := func(part_id: String) -> String:
		return (_library.parts[part_id] as PartLibrary.PartInfo).mesh_hash + ".bwx"
	_plan[shape_of.call("3001")] = [503, 2]
	_plan[shape_of.call("3020")] = [404, -1]
	var heard: Array[String] = []
	_library.exact_fetched.connect(func(part_id: String) -> void: heard.append(part_id))
	_library.request_exact("3001")
	_library.request_exact("3020")
	deadline = Time.get_ticks_msec() + 30_000
	while heard.size() < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("3001's exact shape asked 3 times and kept: %s; 3020's asked once, none (%d); heard %s"
		% [_gaps(shape_of.call("3001")), _asks.get(shape_of.call("3020"), []).size(), heard],
		_asks.get(shape_of.call("3001"), []).size() == 3 and _spaced(shape_of.call("3001"), [2.0, 6.0])
		and Exact.shape_for(_library, "3001") != null
		and _asks.get(shape_of.call("3020"), []).size() == 1 and Exact.known(_library, "3020")
		and Exact.shape_for(_library, "3020") == null and heard.size() == 2)
	# 3709b twice, 3673 once, 3649 three times, 3001's shape twice.
	deadline = Time.get_ticks_msec() + 10_000
	while int(_library._open.get("lbm", 0)) + int(_library._open.get("bwx", 0)) != 0 \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("asked again %d times in all, and nothing left open (%s)" % [_library.retries, _library._open],
		_library.retries == 2 + 1 + 3 + 2 and int(_library._open.get("lbm", 0)) == 0
		and int(_library._open.get("bwx", 0)) == 0)

	# The working model kept while a part of it never comes.
	store.keeps = true
	for its_own: bool in [false, true]:
		await _autosaved(main, store, world, path, hash_of, its_own)
	await _half_opened(main, store, world, hash_of)

	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "a failed fetch is asked again, and a part that never came is said and kept")
	_server.stop()
	quit(1 if _failures else 0)


## The working model kept while a part of it never comes (4519, a 404 every
## time), someone else's file or one the app wrote itself ([param own]): a
## change nobody made by hand (one the store hears, as it hears a session's or
## the assistant's: ModelStore.listen) is written on the autosave's own clock,
## every part in it and 4519 where the file had it; and the model opened again
## from it, as start-up does, has the change, 4519 awaited again, and put down
## when it comes after all. Until 2026-10-20 a model short of a part was never
## autosaved (the store's flag whole, gone since): closing the tab lost all of it.
func _autosaved(main: Node, store: ModelStore, world: BrickWorld, path: String,
		hash_of: Callable, own: bool) -> void:
	print("\nthe autosave of %s short of 4519" % ("the app's own file" if own else "someone else's file"))
	var builder: Builder = main.get("_builder")
	# Every part fetched again, 4519 a 404 again.
	_library.release_geometry()
	_plan[hash_of.call("4519")] = [404, -1]
	var crane := PackedStringArray(CRANE)
	if own:
		crane.insert(1, "0 Author: Brickworks")
	_write(path, "\n".join(crane) + "\n")
	DirAccess.remove_absolute(ModelStore.autosave())
	_said.clear()
	main._open(path)
	var deadline: int = Time.get_ticks_msec() + 30_000
	while _matching("could not be loaded").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("opened short of 4519: %d bricks, %d awaited" % [world.brick_count(), store.awaited.size()],
		world.brick_count() == PARTS - 1 and store.awaited.size() == 1)
	# A brick put down past the builder's signals, as a session's figure goes
	# (Builder.put_figure): the store hears it, nobody tells it.
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 200.0) + store.lift())
	builder.register(world.add_brick("3001", 1, at), "3001", at)
	var waited: float = ModelStore.AUTOSAVE_DELAY_MS / 1000.0 + 1.5
	await _seconds(waited)
	var kept: String = FileAccess.get_file_as_string(ModelStore.autosave())
	var written: Dictionary = _lines_in(kept)
	_check("autosaved %.1f s after a change nobody made by hand: %d parts, 3001 ×%d, 4519 ×%d where it was"
		% [waited, _total(written), written.get("3001", 0), written.get("4519", 0)],
		_total(written) == PARTS + 1 and written.get("3001", 0) == 10
		and written.get("4519", 0) == 1 and _where_it_was(kept, "4519"))

	# Opened again from it, as start-up does after the tab was closed.
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	store.scenery.clear()
	_said.clear()
	var back: int = await store.restore_fetched()
	var awaited := PackedStringArray()
	for placement: LdrModel.Placement in store.awaited:
		awaited.append(placement.part_id)
	_check("reopened from it: %d parts back, %d down, 3001 ×%d, awaited %s"
		% [back, world.brick_count(), _count(world, "3001"), awaited],
		back == PARTS + 1 and world.brick_count() == PARTS and _count(world, "3001") == 10
		and awaited == PackedStringArray(["4519"]))
	deadline = Time.get_ticks_msec() + 10_000
	while _matching("could not be loaded").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	# And it comes after all.
	_plan.erase(hash_of.call("4519"))
	_library.request_mesh("4519", true)
	deadline = Time.get_ticks_msec() + 10_000
	while not _has(world, "4519") and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("4519, come after all, is put down: %d bricks, %d awaited"
		% [world.brick_count(), store.awaited.size()],
		_has(world, "4519") and world.brick_count() == PARTS + 1 and store.awaited.is_empty())


## A whole working model opened again while its parts are on their way (every
## one fetched again: 3001 asked four times over 20 s, 4519 a 404) is never
## written back short of them: not written now, as a reload writes it
## (ModelStore.write_now), nor on the autosave's own clock after a change. It
## did not write then because it wrote nothing for a model short of a part.
func _half_opened(main: Node, store: ModelStore, world: BrickWorld, hash_of: Callable) -> void:
	print("\na whole working model reopened while its parts are on their way")
	var builder: Builder = main.get("_builder")
	_write(ModelStore.autosave(), "\n".join(CRANE) + "\n")
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	store.scenery.clear()
	_library.release_geometry()
	# Counted from here: the crane's opens above asked for it already.
	_asks.erase(hash_of.call("3001"))
	_plan[hash_of.call("3001")] = [503, 3]
	_plan[hash_of.call("4519")] = [404, -1]
	var back: int = await store.restore_fetched()
	var down: int = world.brick_count()
	store.touch()
	store.write_now()
	var kept: String = FileAccess.get_file_as_string(ModelStore.autosave())
	var written: Dictionary = _lines_in(kept)
	_check("written at once, %d of %d down: %d parts, 3001 ×%d, 4519 ×%d where it was"
		% [down, back, _total(written), written.get("3001", 0), written.get("4519", 0)],
		back == PARTS and down < PARTS and _total(written) == PARTS
		and written.get("3001", 0) == 9 and _where_it_was(kept, "4519"))
	# A change heard while 3001 is still on its way: a part that has come.
	var deadline: int = Time.get_ticks_msec() + 10_000
	while not _library.is_resident("3701") and Time.get_ticks_msec() < deadline:
		await process_frame
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 200.0) + store.lift())
	builder.register(world.add_brick("3701", 1, at), "3701", at)
	var waited: float = ModelStore.AUTOSAVE_DELAY_MS / 1000.0 + 1.5
	await _seconds(waited)
	var on_its_way: bool = _library.is_on_its_way("3001")
	kept = FileAccess.get_file_as_string(ModelStore.autosave())
	written = _lines_in(kept)
	_check("autosaved %.1f s after a change, 3001 still on its way (%s): %d parts, 3001 ×%d, 3701 ×%d"
		% [waited, on_its_way, _total(written), written.get("3001", 0), written.get("3701", 0)],
		on_its_way and _total(written) == PARTS + 1 and written.get("3001", 0) == 9
		and written.get("3701", 0) == 2 and _where_it_was(kept, "4519"))


## The model saved as Save saves it, read back.
func _saved_text(store: ModelStore, path: String) -> String:
	if not store.save_file(path, "Grab crane"):
		return ""
	return FileAccess.get_file_as_string(path)


# -- the host ----------------------------------------------------------------

func _serve() -> void:
	while _server.is_connection_available():
		_peers.append({"peer": _server.take_connection(), "got": PackedByteArray()})
	for client: Dictionary in _peers.duplicate():
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(client)
			continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			# A copy each time: a PackedByteArray is a value.
			client["got"] = (client["got"] as PackedByteArray) + (peer.get_data(available)[1] as PackedByteArray)
		var text: String = (client["got"] as PackedByteArray).get_string_from_ascii()
		if not text.contains("\r\n\r\n"):
			continue
		_peers.erase(client)
		_answer(peer, text.get_slice(" ", 1).get_file())


func _answer(peer: StreamPeerTCP, file: String) -> void:
	if not _asks.has(file):
		_asks[file] = []
	(_asks[file] as Array).append(Time.get_ticks_msec())
	var plan: Array = _plan.get(file, [200, 0])
	var asked: int = (_asks[file] as Array).size()
	var how: int = int(plan[0]) if int(plan[1]) < 0 or asked <= int(plan[1]) else 200
	if how == 0:
		peer.disconnect_from_host()
		return
	var body := PackedByteArray()
	if how == 200:
		var folder: String = "parts/" if file.ends_with(".lbm") else "exact/"
		body = FileAccess.get_file_as_bytes("res://assets/generated/" + folder + file)
		if body.is_empty():
			how = 404
	var head: String = "HTTP/1.1 %d %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [how, {200: "OK", 404: "Not Found", 503: "Service Unavailable"}.get(how, "?"), body.size()]
	peer.put_data(head.to_ascii_buffer())
	if not body.is_empty():
		peer.put_data(body)
	peer.disconnect_from_host()


# -- reading -----------------------------------------------------------------

func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## The waits between a file's asks, said.
func _gaps(file: String) -> String:
	var times: Array = _asks.get(file, [])
	var gaps := PackedStringArray()
	for n: int in range(1, times.size()):
		gaps.append("%.1f s" % ((int(times[n]) - int(times[n - 1])) / 1000.0))
	return "%d asks, waits %s" % [times.size(), ", ".join(gaps) if not gaps.is_empty() else "none"]


## Whether a file's asks were [param waits] apart, give or take a second
## (an ask's own answer is in the wait).
func _spaced(file: String, waits: Array) -> bool:
	var times: Array = _asks.get(file, [])
	if times.size() != waits.size() + 1:
		return false
	for n: int in waits.size():
		var gap: float = (int(times[n + 1]) - int(times[n])) / 1000.0
		if gap < float(waits[n]) - 0.1 or gap > float(waits[n]) + 1.0:
			return false
	return true


func _asks_said(hash_of: Callable) -> String:
	var out := PackedStringArray()
	for part_id: String in ["3709b", "3673", "4519", "3649"]:
		out.append("%s %d" % [part_id, _asks.get(hash_of.call(part_id), []).size()])
	return ", ".join(out)


func _matching(words: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in _said:
		if line.contains(words):
			out.append(line)
	return out


func _has(world: BrickWorld, part_id: String) -> bool:
	return _count(world, part_id) > 0


func _count(world: BrickWorld, part_id: String) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == part_id:
			n += 1
	return n


## Whether [param text] places [param part_id] where the crane does, to a
## hundredth of an LDU.
static func _where_it_was(text: String, part_id: String) -> bool:
	var want := PackedFloat64Array()
	for line: String in CRANE:
		if line.ends_with(" %s.dat" % part_id):
			for value: String in line.split(" ", false).slice(2, 14):
				want.append(value.to_float())
	for line: String in text.split("\n"):
		var cut: PackedStringArray = line.strip_edges().split(" ", false)
		if cut.size() != 15 or cut[0] != "1" or cut[14].get_basename() != part_id:
			continue
		for n: int in 12:
			if absf(cut[n + 2].to_float() - want[n]) > 0.01:
				print("      %s written as %s" % [part_id, line.strip_edges()])
				return false
		return true
	return false


## Part id -> how many type-1 lines place it.
static func _lines_in(text: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in text.split("\n"):
		var cut: PackedStringArray = line.strip_edges().split(" ", false)
		if cut.size() == 15 and cut[0] == "1":
			var part_id: String = cut[14].get_basename()
			out[part_id] = int(out.get(part_id, 0)) + 1
	return out


static func _total(lines: Dictionary) -> int:
	var n: int = 0
	for part_id: String in lines:
		n += int(lines[part_id])
	return n


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
