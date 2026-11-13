## A model's parts not to hand are asked for before it is laid, and what does
## not come is named and kept (askfirst, 2026-11-12).
##
##   godot --headless --path . --script src/dev/askfirst_probe.gd
##
## On the web most parts' geometry is fetched as a model opens. An open with
## the status bar's job asked for it as the file was read (ask_geometry), but
## every other one (a shared link's viewer, the working model put back at
## start-up, a session's open_model link=, Together) asked only as each part
## was laid: after the file's carried parts' LDraw files and their copies'
## geometry had been fetched (CustomParts.fetch_sources), one wait after
## another. And a part whose fetch failed before it was laid was asked for
## again by the lay, and one that failed while a big model was being laid was
## said by nothing (ModelStore.not_coming waits for the laying).
##
## Here the library's geometry is served by a local server on 127.0.0.1:9947
## under names the build has not got, as the parts store serves the web's,
## and the LDraw library is withheld as a build has it, its files served
## beside, slowed so an open waits on its carried part as a phone does. Each
## request the server hears is logged. Then:
##   1. an open with no job (the viewer's, start-up's): every part not to
##      hand is on its way while its carried part's LDraw file is fetched,
##      the model before still down; then laid whole;
##   2. a part whose geometry is not there (HTTP 404), heard before the lay:
##      asked for once, held (awaited), named in the open's answer and words
##      ("could not be loaded, kept in the file") and written by a save; one
##      that fails after the lay is said by not_coming, as before;
##   3. a big model opened with the bar's job, laid a slice at a time: its
##      parts on their way before its first slice, laid in the file's order,
##      and one that is not there asked for once and named;
##   4. a save while parts are on their way: every part of the model written,
##      and once they come, all down and the same parts saved.
extends SceneTree

const PORT := 9947
## How long the server takes over the LDraw library's files, and over a
## geometry file whose name begins "slow-": an open waits on its carried
## part as a phone does, and a part is still on its way when it is saved.
const SOURCE_DELAY_S := 0.8
const SLOW_DELAY_S := 3.0
const WATCHDOG := 300.0
const SERVER := """import functools, http.server, sys, time
port, root, log, source, slow = int(sys.argv[1]), sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5])
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        with open(log, "a") as out:
            out.write(self.path + "\\n")
        if self.path.startswith("/ldraw/"):
            time.sleep(source)
        elif self.path.startswith("/geo/slow-"):
            time.sleep(slow)
        super().do_GET()
    def log_message(self, *_):
        pass
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=root)).serve_forever()
"""
## A carried part drawn from a library subpart: with the library withheld,
## its LDraw file is fetched before the model is laid.
const WALL := """0 FILE probe-askwall.dat
0 A wall drawn from a library subpart
0 Name: probe-askwall.dat
0 Author: Somebody Else
0 !LDRAW_ORG Unofficial_Part
0 BFC CERTIFY CCW
1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/3001s01.dat
0 NOFILE
"""

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _server: int = -1
var _dir: String = ""
## Each part withheld, id -> its real geometry's name, put back at the end.
var _withheld: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("askfirst: FAIL, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_dir = OS.get_user_data_dir().path_join("askfirst_probe")
	DirAccess.make_dir_recursive_absolute(_dir.path_join("root/geo"))
	CustomParts.dir = _dir.path_join("parts/")
	CustomParts.keeps = false
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("askfirst: FAIL the catalogue does not load")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = _builder
	_store.library = _library
	_store.keeps = false
	_library.set_fetch_host(_world)
	_library.remote_parts = "http://127.0.0.1:%d/geo/" % PORT
	# Put down as each arrives, as Main does (_on_part_fetched).
	_library.fetched.connect(func(part_id: String) -> void: _store.place_awaited(part_id))
	await process_frame
	if not await _serve():
		print("askfirst: FAIL could not serve on port %d" % PORT)
		quit(1)
		return
	await _no_job()
	await _lost()
	await _paced()
	await _saved_mid_fetch()
	for part_id: String in _withheld:
		(_library.parts[part_id] as PartLibrary.PartInfo).mesh_hash = str(_withheld[part_id])
	OS.kill(_server)
	print("askfirst: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## The server: the LDraw library at /ldraw/ (vendor's), withheld geometry at
## /geo/, each request logged to asked.log. True once it answers.
func _serve() -> bool:
	var script: String = _dir.path_join("serve.py")
	var file: FileAccess = FileAccess.open(script, FileAccess.WRITE)
	file.store_string(SERVER)
	file.close()
	var root: String = _dir.path_join("root")
	var ldraw: String = root.path_join("ldraw")
	if not DirAccess.dir_exists_absolute(ldraw):
		DirAccess.open(root).create_link(ProjectSettings.globalize_path("res://vendor/ldraw"), ldraw)
	file = FileAccess.open(root.path_join("geo/up.txt"), FileAccess.WRITE)
	file.store_string("up")
	file.close()
	_server = OS.create_process("python3", [script, str(PORT), root, _log(),
		str(SOURCE_DELAY_S), str(SLOW_DELAY_S)])
	if _server <= 0:
		return false
	for _n: int in 50:
		var request := HTTPRequest.new()
		get_root().add_child(request)
		request.request("http://127.0.0.1:%d/geo/up.txt" % PORT)
		var result: Array = await request.request_completed
		request.queue_free()
		if int(result[1]) == 200:
			return true
		await create_timer(0.2).timeout
	return false


func _log() -> String:
	return _dir.path_join("asked.log")


## How many times the server was asked for [param part_id]'s geometry.
func _asked(part_id: String) -> int:
	var named: String = (_library.parts[part_id] as PartLibrary.PartInfo).mesh_hash
	var count: int = 0
	for line: String in FileAccess.get_file_as_string(_log()).split("\n", false):
		if line.ends_with("/" + named + ".lbm"):
			count += 1
	return count


## [param part_id]'s geometry withheld from the build under a name of
## [param tag]'s: served (unless [param served] is false: not there, HTTP
## 404), its name beginning "slow-" with [param slow].
func _withhold(part_id: String, tag: String, served: bool = true, slow: bool = false) -> void:
	# A number laid as itself: 3023 is laid as 3023b, which the build has.
	if _library.resolve(part_id) != part_id:
		_check("%s is laid as itself, not as %s" % [part_id, _library.resolve(part_id)], false)
	var info: PartLibrary.PartInfo = _library.parts[part_id]
	if not _withheld.has(part_id):
		_withheld[part_id] = info.mesh_hash
	var real: String = str(_withheld[part_id])
	var named: String = "%s%s-%s" % ["slow-" if slow else "", tag, real]
	if served:
		DirAccess.copy_absolute(_library._on_disk(real),
			_dir.path_join("root/geo/" + named + ".lbm"))
	info.mesh_hash = named


## The web's state at the start of a session: the library's own LDraw files
## not to hand, nothing of them fetched, no carried part built yet.
func _fresh() -> void:
	PartForge.withheld = true
	CustomParts.sources_from = "http://127.0.0.1:%d/" % PORT
	PartForge._fetched_lock.lock()
	PartForge._fetched.clear()
	PartForge._fetched_lock.unlock()
	CustomParts._unfetched.clear()
	for id: String in _library.custom.keys():
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		if info != null:
			_library._custom_meshes.erase(info.mesh_hash)
		_library.parts.erase(id)
		_library.custom.erase(id)


## A model's text: [param lines] (part id, x, z) in its main model, by
## [param author], with the carried wall when [param carried].
static func _text(title: String, author: String, parts: Array, carried: bool) -> String:
	var lines := PackedStringArray(["0 FILE %s.ldr" % title, "0 " + title,
		"0 Name: %s.ldr" % title, "0 Author: " + author])
	if carried:
		lines.append("1 4 0 0 -200 1 0 0 0 1 0 0 0 1 probe-askwall.dat")
	for part: Array in parts:
		lines.append("1 %d %d 0 %d 1 0 0 0 1 0 0 0 1 %s.dat" % [4 + lines.size() % 10,
			int(part[1]), int(part[2]), str(part[0])])
	lines.append("0 NOFILE")
	return "\n".join(lines) + "\n" + (WALL if carried else "")


## [param ids] each placed [param each] times, in a row of their own.
static func _rows(ids: Array, each: int, from_z: int = 0) -> Array:
	var out: Array = []
	for n: int in ids.size():
		for m: int in each:
			out.append([ids[n], m * 100, from_z + n * 100])
	return out


## The open [param go] (a coroutine, its answer put in done[1]) started, and
## awaited to its end: done[0] once it has.
func _until_done(done: Array) -> void:
	var began: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - began < 60000:
		await process_frame


## Until the model is laid and nothing of it is on its way: each part down
## or not coming.
func _until_landed() -> void:
	var began: int = Time.get_ticks_msec()
	while (_store.laying or _store.awaited.any(func(p: LdrModel.Placement) -> bool:
			return _library.is_on_its_way(p.part_id))) and Time.get_ticks_msec() - began < 30000:
		await process_frame
	for _n: int in 3:
		await process_frame


func _bricks_of(part_id: String) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			count += 1
	return count


## 1: an open with no job, as the viewer of a shared link and start-up open.
func _no_job() -> void:
	print("askfirst: an open with no job")
	_fresh()
	# The model before: two parts the build has.
	_store.open_text(_text("before", "Brickworks", [["3068b", 0, 0], ["3069b", 100, 0]], false),
		"before")
	var before: int = _world.brick_count()
	var generation: int = _world.generation()
	var fetched: Array = ["3001", "3002", "3003", "3004"]
	for id: String in fetched:
		_withhold(id, "a")
	var text: String = _text("asked", "Somebody Else", _rows(fetched, 3), true)
	var done: Array = [false, {}]
	var go: Callable = func() -> void:
		done[1] = await _store.open_text_fetched(text, "asked")
		done[0] = true
	go.call()
	# Back here at the open's first wait: its carried part's LDraw file.
	var coming: Array = fetched.filter(func(id: String) -> bool: return _library.is_on_its_way(id))
	_check("asked before it is laid: %d of %d parts on their way while its carried part's file is fetched, the model before still down (%d parts, the same world: %s)"
		% [coming.size(), fetched.size(), _world.brick_count(), _world.generation() == generation],
		not done[0] and coming.size() == fetched.size() and _world.generation() == generation
		and _world.brick_count() == before)
	await _until_done(done)
	await _until_landed()
	var whole: bool = fetched.all(func(id: String) -> bool: return _bricks_of(id) == 3)
	_check("then laid whole: %d parts down, none awaited, its carried part built (%s), each asked once (%s)"
		% [_world.brick_count(), _library.parts.has("probe-askwall"),
			fetched.map(func(id: String) -> int: return _asked(id))],
		whole and _store.awaited.is_empty() and _library.parts.has("probe-askwall")
		and fetched.all(func(id: String) -> bool: return _asked(id) == 1))


## 2: a part whose geometry is not there.
func _lost() -> void:
	print("askfirst: a part that does not come")
	_fresh()
	var fetched: Array = ["3009", "3010"]
	for id: String in fetched:
		_withhold(id, "b")
	_withhold("3008", "b", false)
	_withhold("3007", "b", false, true)
	var text: String = _text("lost", "Brickworks", _rows(["3009", "3010", "3008", "3007"], 2), true)
	var result: Dictionary = await _store.open_text_fetched(text, "lost")
	var lost: Dictionary = result.get("lost", {})
	var words: String = ModelBar.left_out_words(result)
	_check("heard before the lay: asked for once (%d), held (%d of the awaited), named in the answer %s and its words%s"
		% [_asked("3008"), _store.awaited.filter(func(p: LdrModel.Placement) -> bool:
			return p.part_id == "3008").size(), lost, words],
		_asked("3008") == 1 and int(lost.get("3008", 0)) == 2
		and words.contains("2 could not be loaded, kept in the file (3008 ×2)"))
	var saved: String = _store.to_text("lost")
	_check("and written by a save: %d of its 2 lines" % saved.count(" 3008.dat"),
		saved.count(" 3008.dat") == 2)
	# The one that fails once the model is laid: said as before.
	var said: Array = [0]
	var heard: Callable = func(part_id: String, _why: String) -> void:
		if part_id == "3007":
			said[0] = _store.not_coming(part_id)
	_library.fetch_failed.connect(heard)
	await _until_landed()
	_library.fetch_failed.disconnect(heard)
	_check("one that fails after the lay: said by not_coming (%d parts could not be loaded), asked once (%d)"
		% [said[0], _asked("3007")], int(said[0]) == 4 and _asked("3007") == 1)
	_check("the rest down: %s" % [fetched.map(func(id: String) -> int: return _bricks_of(id))],
		fetched.all(func(id: String) -> bool: return _bricks_of(id) == 2))


## 3: a big model opened with the bar's job, laid a slice at a time.
func _paced() -> void:
	print("askfirst: a big model opened with the bar")
	_fresh()
	var fetched: Array = ["3020", "3021", "3022"]
	for id: String in fetched:
		_withhold(id, "c")
	_withhold("3710", "c", false)
	var parts: Array = _rows(fetched + ["3710"], 3)
	# The rest the build has: enough to be laid a slice at a time.
	for n: int in ModelStore.LAID_IN_SLICES_FROM:
		parts.append(["3005", (n % 20) * 20, 600 + (n / 20) * 20])
	var text: String = _text("big", "Somebody Else", parts, true)
	var job := Working.Job.new()
	var done: Array = [false, {}]
	var go: Callable = func() -> void:
		done[1] = await _store.open_text_fetched(text, "big", null, job)
		done[0] = true
	go.call()
	var coming: Array = fetched.filter(func(id: String) -> bool: return _library.is_on_its_way(id))
	_check("its parts on their way before its first slice: %d of %d, nothing laid yet"
		% [coming.size(), fetched.size()],
		not done[0] and not _store.laying and coming.size() == fetched.size())
	await _until_done(done)
	await _until_landed()
	var result: Dictionary = done[1]
	var lost: Dictionary = result.get("lost", {})
	_check("the part not there asked for once (%d) and named: %s"
		% [_asked("3710"), lost], _asked("3710") == 1 and int(lost.get("3710", 0)) == 3)
	# Down in the file's order: the parts it places, the one not there aside.
	var wanted := PackedStringArray()
	for part: Array in parts:
		if str(part[0]) != "3710":
			wanted.append(str(part[0]))
	var down := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id != "probe-askwall":
			down.append(brick.part_id)
	_check("laid in the file's order: %d parts, the same order as its %d lines"
		% [down.size(), wanted.size()], down == wanted)


## 4: a save while parts are on their way.
func _saved_mid_fetch() -> void:
	print("askfirst: a save while parts are on their way")
	_fresh()
	var slow: Array = ["3031", "3032", "3034"]
	for id: String in slow:
		_withhold(id, "d", true, true)
	var parts: Array = _rows(slow, 2) + _rows(["3005"], 4, 400)
	var text: String = _text("mid", "Brickworks", parts, false)
	await _store.open_text_fetched(text, "mid")
	var path: String = _dir.path_join("mid.ldr")
	var waiting: int = _store.awaited.size()
	_store.save_file(path, "mid")
	var saved: String = FileAccess.get_file_as_string(path)
	var counts: Array = (slow + ["3005"]).map(func(id: String) -> int:
		return saved.count(" %s.dat" % id))
	_check("saved with %d parts on their way: every part written %s"
		% [waiting, counts], waiting == 6 and counts == [2, 2, 2, 4])
	await _until_landed()
	_store.save_file(path, "mid")
	saved = FileAccess.get_file_as_string(path)
	var again: Array = (slow + ["3005"]).map(func(id: String) -> int:
		return saved.count(" %s.dat" % id))
	_check("once they came: all %d down, the same parts saved %s"
		% [_world.brick_count(), again],
		_store.awaited.is_empty() and again == [2, 2, 2, 4]
		and slow.all(func(id: String) -> bool: return _bricks_of(id) == 2))
