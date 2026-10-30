## Is a big model's booklet read while it is drawn, as a person reads it?
##
##   godot --path . --resolution 1280x800 --script src/dev/booklet_stream_probe.gd -- [--model=FILE]
##
## Needs a window: every picture is drawn. FILE is res://models/castle.ldr
## unless named (2,497 parts, 400 steps).
##
## steps206 (2026-10-23) found the castle's booklet still drawing after 25
## minutes on a preview; on the desktop's card it took a minute and a half,
## and nothing of it showed until all of it had been drawn. So this presses
## Instructions as a person does, answers where to save it, and reads what
## the browser is given (BookletOut: over HTTP from 127.0.0.1, the browser
## opened on it with the first page), here by a reader of its own standing
## in for the browser:
##
##   is the browser asked to open the booklet once, and does it get the
##   cover within 5 s and the first page of steps long before the last?
##   is what it read, whole, the file written, and does the page opened
##   again give the whole booklet again (a reload, after it is drawn)?
##   does the window go on drawing meanwhile: no frame of the app's longer
##   than half a second?
##   does the status bar say it is open in the browser?
##
## Times are said from the press of Save: the cover, the first page of
## steps, the whole booklet, the longest frame.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _opened: Array = []
## The stand-in browser: [StreamPeerTCP, bytes read, done].
var _reader: StreamPeerTCP = null
var _read := PackedByteArray()
var _seen: Dictionary = {}
var _pressed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	var model: String = "res://models/castle.ldr"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
	SaveTo.native = false
	SaveTo.open_with = func(uri: String) -> Error:
		_opened.append(uri)
		if uri.begins_with("http://"):
			_reader = _read_from(uri)
		return OK
	var out: String = OS.get_user_data_dir().path_join("booklet_stream_probe")
	DirAccess.make_dir_recursive_absolute(out)

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		_bar = _main.get("_bar")
		if _shell != null and _bar != null:
			break
	await _frames(30)
	_main.call("_open", model)
	_main.call("_lay_baseplate")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(60)
	var world: BrickWorld = _main.get("_world")
	print("  %s: %d parts" % [model.get_file(), world.brick_count()])

	_check("Instructions can be pressed", _shell.run("instructions"))
	var dialog: FileDialog = null
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until and dialog == null:
		await process_frame
		if SaveTo.showing != null and SaveTo.showing.visible:
			dialog = SaveTo.showing
	if not _check("Instructions asks where to save the booklet", dialog != null):
		_quit()
		return
	var path: String = out.path_join(model.get_file().get_basename() + "_booklet.html")
	dialog.current_dir = path.get_base_dir()
	dialog.current_file = path.get_file()
	await _frames(2)
	_bar.say("")
	# Each frame from the press on, the longest of them the app's own stall.
	var longest: Array = [0, Time.get_ticks_usec(), 0.0]
	var watch := func() -> void:
		var now: int = Time.get_ticks_usec()
		if now - int(longest[1]) > int(longest[0]):
			longest[0] = now - int(longest[1])
			longest[2] = (Time.get_ticks_msec() - _pressed) / 1000.0
		longest[1] = now
		_poll()
	process_frame.connect(watch)
	_pressed = Time.get_ticks_msec()
	dialog.get_ok_button().pressed.emit()
	var said: String = ""
	until = Time.get_ticks_msec() + 600000
	while Time.get_ticks_msec() < until:
		await process_frame
		said = _bar.status_text()
		if said.begins_with("the booklet is open") or said.begins_with("no browser") \
				or said.begins_with("could not") or said.begins_with("stopped") \
				or said.begins_with("nothing"):
			break
	var whole_at: float = (Time.get_ticks_msec() - _pressed) / 1000.0
	var stall: float = int(longest[0]) / 1000000.0
	# The rest of what was sent, read.
	until = Time.get_ticks_msec() + 30000
	while _reader != null and Time.get_ticks_msec() < until:
		await process_frame
	process_frame.disconnect(watch)

	var cover: float = float(_seen.get("page-1", -1.0))
	var steps: float = float(_seen.get("page-2", -1.0))
	print("  from Save: the cover at %.1f s, the first page of steps at %.1f s, " % [cover, steps]
		+ "the whole booklet at %.1f s; the longest frame %.0f ms, at %.1f s"
		% [whole_at, stall * 1000.0, float(longest[2])])
	_check("the status bar says the booklet is open in the browser (%s)" % said,
		said.begins_with("the booklet is open in your browser") and said.ends_with(path))
	_check("the browser was asked to open it once, as it is drawn (%s)" % str(_opened),
		_opened.size() == 1 and str(_opened[0]).begins_with("http://127.0.0.1:"))
	_check("the cover was in front of the reader within 5 s (%.1f s)" % cover,
		cover >= 0.0 and cover <= 5.0)
	_check("...and the first page of steps long before the last (%.1f s of %.1f s)"
		% [steps, whole_at], steps >= 0.0 and steps < whole_at * 0.5)
	var file: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("what the browser read is the file written (%d bytes, %d)" % [_read.size(), file.size()],
		file.size() > 100000 and _read == file)
	_check("...whose pages are all there (%d)" % _count(file, "<section class=\"page"),
		_count(file, "<section class=\"page") > 10 and _count(file, "</html>") == 1)
	_check("no .part is left beside it", not FileAccess.file_exists(path + ".part"))
	_check("the window went on drawing: no frame longer than 500 ms (%.0f ms)" % (stall * 1000.0),
		stall < 0.5)
	if not _opened.is_empty():
		# Opened again, once it is whole: the whole booklet again.
		_read = PackedByteArray()
		_reader = _read_from(str(_opened[0]))
		until = Time.get_ticks_msec() + 30000
		while _reader != null and Time.get_ticks_msec() < until:
			await process_frame
			_poll()
		_check("opened again, it is the whole booklet again (%d bytes)" % _read.size(),
			_read == file)
	_quit()


## A reader of [param uri], as a browser asks for a page.
func _read_from(uri: String) -> StreamPeerTCP:
	var rest: String = uri.trim_prefix("http://")
	var host: String = rest.get_slice("/", 0)
	var peer := StreamPeerTCP.new()
	peer.connect_to_host(host.get_slice(":", 0), host.get_slice(":", 1).to_int())
	peer.set_meta("request", ("GET /%s HTTP/1.1\r\nHost: %s\r\n\r\n"
		% [rest.get_slice("/", 1), host]).to_utf8_buffer())
	_read = PackedByteArray()
	_seen.clear()
	return peer


## What has come since the last frame, and when each page first showed.
func _poll() -> void:
	if _reader == null:
		return
	_reader.poll()
	var status: StreamPeerTCP.Status = _reader.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED and _reader.has_meta("request"):
		_reader.put_data(_reader.get_meta("request"))
		_reader.remove_meta("request")
	var waiting: int = _reader.get_available_bytes() if status == StreamPeerTCP.STATUS_CONNECTED else 0
	if waiting > 0:
		var got: Array = _reader.get_partial_data(waiting)
		var from: int = maxi(0, _read.size() - 64)
		_read.append_array(got[1])
		var text: String = _read.slice(from).get_string_from_ascii()
		for page: String in ["page-1", "page-2"]:
			if not _seen.has(page) and text.contains("id=\"%s\"" % page):
				_seen[page] = (Time.get_ticks_msec() - _pressed) / 1000.0
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		# The headers off the front: the body is the file.
		var at: int = _header_end(_read)
		_read = _read.slice(at) if at > 0 else _read
		_reader = null


static func _header_end(bytes: PackedByteArray) -> int:
	var head: String = bytes.slice(0, mini(bytes.size(), 1024)).get_string_from_ascii()
	var at: int = head.find("\r\n\r\n")
	return at + 4 if at >= 0 else 0


static func _count(bytes: PackedByteArray, what: String) -> int:
	return bytes.get_string_from_utf8().count(what)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


## The system's own back before the engine shuts down: a class's static
## Callable holding this script's lambda corrupts the heap at exit (4.7.2,
## save_dialog_probe).
func _quit() -> void:
	SaveTo.open_with = Callable(Outside, "open_link")
	print("")
	print("booklet stream probe: %s" % ("all checks passed" if _failures == 0
		else "%d check(s) FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
