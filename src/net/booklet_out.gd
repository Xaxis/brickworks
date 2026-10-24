## Where a booklet goes while it is drawn: each piece BookletMaker sends
## out (wrote) into its file as it comes, and to the reader at once, who
## reads page 1 while page 300 is drawn.
##
## A castle's booklet was handed over whole: its first page showed after a
## minute and a half on the desktop, and after more than 25 minutes in a
## browser drawing in software (steps206, 2026-10-23).
##
##   desktop  the file, as NAME.part beside where it was asked for until it
##            is whole; and, to be read, the same pieces over HTTP from
##            127.0.0.1, the browser opened on them with the first. A page
##            opened from a file is read once, as far as the file then goes;
##            one over HTTP is drawn as it comes. The pieces are kept, so the
##            page can be opened again while the app runs.
##   web      into the tab opened as the button was pressed
##            (BookletMaker.open_tab), by document.write, which draws as it
##            comes too; with no tab (the browser blocked it), downloaded
##            whole at the end.
class_name BookletOut
extends Node

## Whether the reader has it: the browser was opened on it (desktop), or it
## went into the tab (web).
var shown: bool = false

var _path: String = ""
var _file: FileAccess
var _tab: JavaScriptObject = null
var _kept := PackedStringArray()
var _server: TCPServer
var _url: String = ""
var _name: String = ""
var _pieces: Array[PackedByteArray] = []
var _readers: Array[Reader] = []
var _done: bool = false
var _asked: bool = false
## The file could not be opened to be written.
var _unwritable: bool = false


## A browser reading the booklet over HTTP: its request, then how far
## through the pieces it has been sent.
class Reader extends RefCounted:
	var peer: StreamPeerTCP
	var asked := PackedByteArray()
	var answered: bool = false
	var piece: int = 0
	var at: int = 0


## Start a booklet that goes to the file [param to] ("" for none) and, with
## [param show], to a browser on the desktop, named [param name] there.
func begin(to: String, show: bool, name: String) -> void:
	_path = ProjectSettings.globalize_path(to) if not to.is_empty() else ""
	_name = name
	set_process(false)
	if OS.has_feature("web"):
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		var tab: Variant = window.brickworksBooklet if window != null else null
		_tab = tab if tab is JavaScriptObject else null
		return
	if not _path.is_empty():
		_file = FileAccess.open(_part(), FileAccess.WRITE)
		_unwritable = _file == null
	if show:
		_server = TCPServer.new()
		if _server.listen(0, "127.0.0.1") == OK:
			_url = "http://127.0.0.1:%d/%s" % [_server.get_local_port(), _name.uri_encode()]
		else:
			_server = null
	# Each frame only while there is a browser to serve.
	set_process(_server != null)


## Where a browser reads it as it comes, "" when it cannot.
func url() -> String:
	return _url


## The next piece of the booklet (BookletMaker.wrote).
func take(piece: String) -> void:
	if OS.has_feature("web"):
		if _tab == null:
			_kept.append(piece)
			return
		var document: JavaScriptObject = _tab.document
		if not shown:
			shown = true
			document.open()
		# The tab was opened from the app, so it is under the app's security
		# policy, which runs no inline handler: Print did nothing in a browser
		# (share_flow, 2026-10-12). The app gives the button its click at the
		# end instead; the file the desktop writes keeps its own.
		document.write(piece.replace(BookletMaker.PRINT_INLINE, ""))
		return
	if _file != null:
		_file.store_string(piece)
	if _server != null:
		_pieces.append(piece.to_utf8_buffer())
		# Asked once: with no browser to open it, the file is said at the end.
		if not _asked and not _url.is_empty():
			_asked = true
			shown = SaveTo.open_with.call(_url) == OK


## The booklet is whole ([param whole]) or was stopped. Returns whether its
## file was written; on the web, [method kept] is the file when there was
## no tab to show it in.
func finish(whole: bool) -> bool:
	_done = true
	if OS.has_feature("web"):
		if _tab != null and shown and whole:
			(_tab.document as JavaScriptObject).close()
			JavaScriptBridge.eval("""
				(() => {
					const tab = window.brickworksBooklet;
					const button = tab && tab.document.querySelector('.bar button');
					if (button) button.addEventListener('click', () => tab.print());
					window.brickworksBooklet = null;
				})();
			""", true)
		elif not whole:
			BookletMaker.close_tab()
		return true
	var written: bool = not _unwritable
	if _file != null:
		written = _file.get_error() == OK
		_file.close()
		_file = null
		if whole and written:
			if FileAccess.file_exists(_path):
				DirAccess.remove_absolute(_path)
			written = DirAccess.rename_absolute(_part(), _path) == OK
		else:
			DirAccess.remove_absolute(_part())
	if not whole or not shown:
		_stop()
	return written


## The whole file, on the web with no tab to write it into.
func kept() -> String:
	return "".join(_kept)


func _part() -> String:
	return _path + ".part"


func _stop() -> void:
	set_process(false)
	if _server != null:
		_server.stop()
		_server = null
	for reader: Reader in _readers:
		reader.peer.disconnect_from_host()
	_readers.clear()
	_pieces.clear()


func _exit_tree() -> void:
	_stop()


## Each frame: a browser come to read it let in, asked what it wants, and
## sent what has been drawn since, a few megabytes at a time.
func _process(_delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var reader := Reader.new()
		reader.peer = _server.take_connection()
		_readers.append(reader)
	for reader: Reader in _readers.duplicate():
		reader.peer.poll()
		if reader.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_readers.erase(reader)
			continue
		if not reader.answered:
			_answer(reader)
			continue
		var budget: int = 4 << 20
		while budget > 0 and reader.piece < _pieces.size():
			var bytes: PackedByteArray = _pieces[reader.piece]
			var sent: Array = reader.peer.put_partial_data(
				bytes.slice(reader.at, mini(bytes.size(), reader.at + budget)))
			if int(sent[0]) != OK or int(sent[1]) == 0:
				break
			reader.at += int(sent[1])
			budget -= int(sent[1])
			if reader.at >= bytes.size():
				reader.piece += 1
				reader.at = 0
		if _done and reader.piece >= _pieces.size():
			reader.peer.disconnect_from_host()
			_readers.erase(reader)


## Read [param reader]'s request, once it has all come, and answer it: the
## booklet as it goes for its own name, nothing for anything else (the
## browser asks for an icon).
func _answer(reader: Reader) -> void:
	var waiting: int = reader.peer.get_available_bytes()
	if waiting > 0:
		var got: Array = reader.peer.get_partial_data(waiting)
		if int(got[0]) == OK:
			reader.asked.append_array(got[1])
	var request: String = reader.asked.get_string_from_utf8()
	if not request.contains("\r\n\r\n"):
		if reader.asked.size() > 16384:
			reader.peer.disconnect_from_host()
			_readers.erase(reader)
		return
	var wanted: String = request.get_slice("\r\n", 0).get_slice(" ", 1)
	if wanted.get_slice("?", 0) != "/" + _name.uri_encode():
		reader.peer.put_data(("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n"
			+ "Connection: close\r\n\r\n").to_utf8_buffer())
		reader.peer.disconnect_from_host()
		_readers.erase(reader)
		return
	reader.peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n"
		+ "Cache-Control: no-store\r\nConnection: close\r\n\r\n").to_utf8_buffer())
	reader.answered = true
