## A request that leaves the moment it is asked for and is answered the
## moment its answer is in: every request the app makes of a server, other
## than Together's own and a part's (Together._ask_page,
## PartLibrary._ask_page), and those made from a thread.
##
## In a browser an HTTPRequest is the engine's, polled once a frame, and
## each of its states took a frame: asked in one frame, it asked the page
## for the request in the third (resolving, connecting, then the request),
## and its answer, in, was read over two or three more. A frame drawn in
## software or on a phone is 100 to 600 ms, so the relay's answer to a
## Claude call left a second after the tab had it (framefetch, 2026-11-14:
## tools/web/framefetch_flow.mjs). Here, in a browser, the page's own fetch
## is asked at once and its answer handed back from the page's callback,
## between frames, and a tab whose frames have stopped (out of view) is
## answered all the same. Off the web it is the HTTPRequest it always was.
class_name PageFetch
extends RefCounted

## The most asks [method asked] keeps for the page.
const KEPT_ASKS := 200

const _METHODS := ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"]

## The one that holds the page's callback, made the first time it is asked.
static var _the: PageFetch = null
## The requests [method cancel] can stop, by their tag: an HTTPRequest off
## the web, the page's id in a browser.
static var _tagged: Dictionary = {}

var _callback: JavaScriptObject = null
var _window: JavaScriptObject = null
var _asked: int = 0
var _answers: Dictionary = {}
signal _answered(id: int)


## [result, code, headers, body], as [signal HTTPRequest.request_completed]
## gives them: an [enum HTTPRequest.Result], the status, the answer's
## headers ("name: value") and its bytes. [param timeout] in seconds, none
## at 0; [param most] the most bytes taken, any at -1. [param tag] names it
## for [method cancel], which stops it: its answer is then
## [constant HTTPRequest.RESULT_REQUEST_FAILED].
static func ask(host: Node, url: String, headers: PackedStringArray = PackedStringArray(),
		method: int = HTTPClient.METHOD_GET, body: String = "", timeout: float = 0.0, most: int = -1,
		tag: String = "") -> Array:
	asked(url)
	if OS.has_feature("web"):
		return await _page()._ask_page(url, headers, method, body, timeout, most, tag)
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.body_size_limit = most
	host.add_child(http)
	if not tag.is_empty():
		_tagged[tag] = http
	if http.request(url, headers, method, body) != OK:
		_untag(tag, http)
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var done: Array = await http.request_completed
	Wake.all("fetch")
	_untag(tag, http)
	http.queue_free()
	return done


## Stop the request [method ask] was given [param tag] for, if it is out.
## Its asker wakes after this returns, as it does in a browser: woken
## within, the connector's loop that a stalled request was cancelled for
## read the cancel as the relay gone (ffreview, 2026-11-14).
static func cancel(tag: String) -> void:
	var going: Variant = _tagged.get(tag)
	_tagged.erase(tag)
	if going is HTTPRequest and is_instance_valid(going):
		(going as HTTPRequest).cancel_request()
		(going as HTTPRequest).call_deferred(&"emit_signal", &"request_completed",
			HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
	elif going is int:
		JavaScriptBridge.eval("window.brickworksFetchStop(%d)" % int(going), true)


static func _untag(tag: String, going: Variant) -> void:
	if not tag.is_empty() and _tagged.get(tag) == going:
		_tagged.erase(tag)


## When a send was asked (unix ms), kept for the page in
## window.brickworksSends: tools/web/framefetch_flow.mjs reads it beside the
## server's own time of arrival, and the difference is how long a send
## waited before it left. A name of its own: dialogs_flow keeps booleans in
## window.brickworksAsked (ffreview, 2026-11-14).
static func asked(url: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(("(() => { const a = window.brickworksSends = window.brickworksSends || [];"
		+ " a.push(%s); if (a.length > %d) a.shift(); })()") % [JSON.stringify({"url": url,
		"at": int(Time.get_unix_time_from_system() * 1000.0)}), KEPT_ASKS], true)


static func _page() -> PageFetch:
	if _the == null:
		_the = PageFetch.new()
		_the._callback = JavaScriptBridge.create_callback(_the._on_answer)
		_the._window = JavaScriptBridge.get_interface("window")
		_the._window.brickworksFetched = _the._callback
		JavaScriptBridge.eval(_PAGE % [HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_SUCCESS,
			HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_REQUEST_FAILED, HTTPRequest.RESULT_CONNECTION_ERROR], true)
	return _the


## The page's end: brickworksFetch(id, url, method, headers, body, wait ms,
## most bytes) fetches and keeps the answer's bytes and headers by its id,
## then says (id, result, status, size) to brickworksFetched. The headers
## are [name, value] pairs, as JSON, so one given twice goes twice; the body
## is text, sent as its UTF-8 bytes, or null for none: as the engine's
## fetch sent them, with no Content-Type the app did not give. A fetch that
## fails (refused, offline, or a site that does not let a browser read it)
## is RESULT_CONNECTION_ERROR, as the engine's was, and FetchWords says so;
## brickworksFetchTake(id) hands the headers over, then the bytes, once, as a
## Uint8Array, which JavaScriptBridge.eval gives the app as a
## PackedByteArray in one copy; brickworksFetchStop(id) stops one.
const _PAGE := """(function () {
	const kept = new Map(), stops = new Map();
	window.brickworksFetch = function (id, url, method, headers, body, wait, most) {
		const stop = new AbortController();
		let late = false;
		const timer = wait > 0 ? setTimeout(function () { late = true; stop.abort(); }, wait) : 0;
		stops.set(id, stop);
		const told = function (result, status, bytes, heads) {
			clearTimeout(timer);
			stops.delete(id);
			kept.set(id, [heads || '', bytes || new Uint8Array()]);
			window.brickworksFetched(id, result, status, bytes ? bytes.byteLength : 0);
		};
		fetch(url, {method: method, headers: JSON.parse(headers), signal: stop.signal,
			body: body === null || body === undefined ? undefined : new TextEncoder().encode(body)})
			.then(function (answer) {
				return answer.arrayBuffer().then(function (buffer) {
					const heads = [];
					answer.headers.forEach(function (value, name) { heads.push(name + ': ' + value); });
					if (most >= 0 && buffer.byteLength > most) told(%d, answer.status, null, heads.join('\\n'));
					else told(%d, answer.status, new Uint8Array(buffer), heads.join('\\n'));
				});
			})
			.catch(function () { told(late ? %d : stop.signal.aborted ? %d : %d, 0, null, ''); });
	};
	window.brickworksFetchTake = function (id, part) {
		const got = kept.get(id) || ['', new Uint8Array()];
		if (part === 1) kept.delete(id);
		return got[part];
	};
	window.brickworksFetchStop = function (id) {
		const stop = stops.get(id);
		if (stop) stop.abort();
	};
})();"""


func _ask_page(url: String, headers: PackedStringArray, method: int, body: String, timeout: float,
		most: int, tag: String) -> Array:
	_asked += 1
	var id: int = _asked
	if not tag.is_empty():
		_tagged[tag] = id
	var pairs: Array = []
	for line: String in headers:
		var colon: int = line.find(":")
		if colon > 0:
			pairs.append([line.substr(0, colon).strip_edges(), line.substr(colon + 1).strip_edges()])
	var verb: String = _METHODS[method] if method >= 0 and method < _METHODS.size() else "GET"
	# Handed over as an argument, not written into a script to eval: a 6 MB
	# body escaped and parsed so held the frame that asked 370 ms, and 198
	# handed over, on one loaded box (ffreview's rig, 2026-11-14). The rest
	# is the bridge's own copy of a String and fetch()'s of its bytes.
	var sent: Variant = null if verb in ["GET", "HEAD"] or body.is_empty() else body
	_window.call(&"brickworksFetch", id, url, verb, JSON.stringify(pairs), sent, int(timeout * 1000.0), most)
	while not _answers.has(id):
		await _answered
	var got: Array = _answers[id]
	_answers.erase(id)
	_untag(tag, id)
	return got


## The page's word that request [param args][0] is answered: its result,
## its status and how many bytes came, taken from the page here.
func _on_answer(args: Array) -> void:
	var id: int = int(args[0])
	var heads: Variant = JavaScriptBridge.eval("window.brickworksFetchTake(%d, 0)" % id, true)
	var bytes: Variant = JavaScriptBridge.eval("window.brickworksFetchTake(%d, 1)" % id, true)
	_answers[id] = [int(args[1]), int(args[2]),
		PackedStringArray(str(heads).split("\n", false)) if heads is String else PackedStringArray(),
		bytes if bytes is PackedByteArray else PackedByteArray()]
	# An answer can change what any panel shows (Wake), with no input.
	Wake.all("fetch")
	_answered.emit(id)
