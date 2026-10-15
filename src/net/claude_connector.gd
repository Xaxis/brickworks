## This tab, offered to Claude as a connector.
##
## Someone on a Claude plan who wants to design without an API key turns
## this on, and gets a private address to add to Claude: claude.ai or the
## Claude app as a custom connector, or Claude Code with `claude mcp add
## --transport http`. Claude, signed in their own way on their own plan,
## then calls this app's tools while they talk to it; this tab answers each
## call and the model is built here, where they can watch it.
##
## The address goes to api/mcp.js, which queues Claude's requests until
## this tab asks for them, and hands the answers back. The answers come
## from [method CommandSocket.answer_rpc] — the code that serves the
## desktop's MCP port — so a tool works the same over either.
##
## The token in the address is the only credential and is made here, at
## random. It is kept on this device, like a key, because the address is
## added to Claude once: a new one every visit made the connector someone
## had added dead by the next. Switching off keeps it; "New address" is
## what forgets it.
##
## A browser stops drawing a tab it is not showing, and the app runs on
## drawing — so while the person was over in claude.ai this tab answered
## nothing, and Claude told them Brickworks was not connected while it
## plainly was. Now, while the connector is on, the page keeps the app
## running out of view: the engine asks the page for each frame, and a tab
## out of view is given its frames by a worker's clock, which a browser
## does not pause, instead of by the screen ([method _watch_the_page]). The
## page also says it is alive every few seconds from that worker, so the
## relay judges an open tab by the page and not by whether the app happens
## to be asking for work — which it is not while it builds a large design.
## The handshake and the tool list are sent to the relay when it switches
## on, so Claude can add and list the connector before any of that; and a
## call taken just as a tab went to sleep is handed out again when it wakes
## (supabase/relay.sql).
##
## A connector belongs to an account (2026-10-11). Switching on sends the
## person's session with the hello, the relay records whose connector it
## is, and it refuses a tab that is not signed in, or an address another
## account switched on. So this switches on only while [member account] is
## signed in, and goes off — saying why — when the relay refuses it.
##
## And Claude connects to the account, not to this tab (2026-10-11). There
## is one address for everybody, [method shared_address]; Claude signs in
## to it with OAuth (api/oauth.js) and the relay sends its calls to
## whichever of the account's tabs is listening. [method connect_claude] is
## the one click: this tab starts listening, and claude.ai's "Add custom
## connector" opens with Brickworks filled in. The account's connections
## ([member connections]) are asked of the deployment; once there is one,
## any tab the person signs in to listens by itself, unless they switched
## Claude off in it. The private address above is still this tab's
## channel, and still answers anyone who added it by hand.
class_name ClaudeConnector
extends Node

## What Claude shows the connector as.
const NAME := "Brickworks"

## Where the address and whether it was on are kept: in this tab's own
## folder (TabSession), since 2026-10-13. It was one file for the browser,
## so every tab had the one address, the relay knew them as one tab, and a
## second tab switching on took it from the first ("another page switched
## this connector on"). Now each tab is its own connector, which Claude can
## list and choose between (api/mcp.js, the tabs tool). A probe points this
## elsewhere so it never touches the one this machine uses.
static var where: String = ""
## Which tab this is, as Claude is shown it: this tab's id (TabSession). A
## probe playing several tabs in one process gives each its own, and each
## a file of its own ([member kept_in]); both before it is added.
var tab_id: String = ""
var kept_in: String = ""
## The name of the model in this tab, as Claude is told it with every
## answer and in the list of tabs. Main's is its ModelStore title.
var model_name: Callable = func() -> String: return ""

## Where the relay is. The site the page came from on the web; on the
## desktop the deployment the account signs in to — the live site, or
## BRICKWORKS_API — so the session said with a hello is one it knows.
var base_url: String = "https://brickworks.diy"
## Answers the requests. Needs its assistant and app set.
var rpc: CommandSocket
## Who is switching it on: the relay will not let a tab that is not signed
## in switch a connector on.
var account: Account
## Whether [method connect_claude] opens claude.ai. A probe turns this off
## and reads [member last_opened] instead of opening a browser.
var open_links: bool = true
var last_opened: String = ""

## Listening for Claude, or not; and the address to give it while it is.
signal listening(on: bool, address: String)
## Claude asked for something: a tool by name, with what it passed, or ""
## for the protocol's own requests; and it was answered — whether the tool
## did what was asked, and what it said.
signal called(tool: String, arguments: Dictionary)
signal answered(tool: String, ok: bool, text: String)
## The relay could not be reached, in words.
signal trouble(why: String)
## Another page switched this connector on, and this one has let go.
signal replaced()
## The relay answered again after [signal trouble].
signal relay_ok()
## The account's Claude connections changed: each {id, client, since,
## last_used}, newest first.
signal connections_changed(connections: Array)

## Claude (claude.ai, the Claude apps, Claude Code) signed in to this
## account, as the deployment last said; empty until it has been asked.
var connections: Array = []
## Whether the connections have been asked for since the account changed.
var connections_known: bool = false
## Whether this account has had Claude (claude.ai and its apps) connected,
## connected now or not: the deployment keeps it past a Disconnect
## (api/oauth.js). The person's Claude has a Brickworks connector then, and
## connecting again is Connect on that one. Adding it again from claude.ai's
## "Add custom connector" sets one up anew, its tool permissions to choose
## again: the owner disconnected and connected again four times in two days
## this way, and re-enabled the tools after every one (2026-10-14).
var had_claude: bool = false

## Claude's own list of the person's connectors (Customize › Connectors),
## where a Brickworks already there is connected again.
const CONNECTORS := "https://claude.ai/customize/connectors"

var _token: String = ""
var _on: bool = false
## Switched off in this tab by the person, so a connection to the account
## does not switch it back on by itself.
var _off_here: bool = false
## Until when, in ticks, the connections are asked for again every few
## seconds: after [method connect_claude], while the person is in claude.ai.
var _waiting_until: int = 0
var _next_ask: int = 0
var _asking_connections: bool = false
## Whether Claude has ever reached this address, so the steps for adding
## it can be folded away once it has.
var _used: bool = false
## This page load, so the relay can tell two of them apart. The newest one
## to switch on listens; an older one is told so and lets go.
var _instance: String = ""
## Bumped on every switch on and off. The address outlives both now, so it
## can no longer tell an old listening loop that it has been superseded:
## a cancelled request never completes, and the loop waiting on it would
## wake on the next one's answer and answer it twice.
var _generation: int = 0
var _troubled: bool = false
var _http: HTTPRequest
var _reply: HTTPRequest
## When the request for work now waiting went out, in ticks, or 0. The
## relay answers one within 25 s; one outstanding far longer died while the
## page slept, and the loop waiting on it is replaced rather than left to
## hang, which is how a tab brought back into view stayed deaf.
var _asking_since: int = 0
const STALLED_MS := 45_000


func _ready() -> void:
	if OS.has_feature("web"):
		var here: Variant = JavaScriptBridge.eval("location.origin", true)
		if typeof(here) == TYPE_STRING and str(here).begins_with("http"):
			base_url = str(here)
	else:
		base_url = Deployment.api_base()
	_http = HTTPRequest.new()
	# The relay holds a request for work for 25 s; wait a little longer.
	_http.timeout = 40.0
	add_child(_http)
	_reply = HTTPRequest.new()
	_reply.timeout = 30.0
	add_child(_reply)
	_instance = _new_token().substr(0, 16)
	_load()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	# A headless run has no window anybody uses, though it says it has focus.
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless" \
			and get_window().has_focus():
		_focused_at = now
	if _waiting_until > now and now >= _next_ask and not _asking_connections:
		_next_ask = now + 5000
		refresh_connections()
	if not _on or _asking_since == 0:
		return
	if now - _asking_since > STALLED_MS:
		_asking_since = 0
		_http.cancel_request()
		_generation += 1
		_listen()


func is_on() -> bool:
	return _on


## Off with the assistant (Settings, Assistant (AI)): nothing listens, and
## nothing switches it on, not a sign-in and not a connection to the
## account. What it was is kept, so the assistant on again puts it back.
var held: bool = false


func hold(off: bool) -> void:
	if held == off:
		return
	held = off
	if off:
		_waiting_until = 0
		if _on:
			_hang_up()


## True once Claude has reached this address.
func used() -> bool:
	return _used


## The address to add to Claude, or "" when there is none yet.
func address() -> String:
	return "" if _token.is_empty() else "%s/api/mcp?t=%s" % [base_url, _token]


## The address everybody adds to Claude. Claude signs in to it, and its
## calls come to whichever of the account's tabs is listening.
func shared_address() -> String:
	return base_url + "/api/mcp"


## claude.ai's "Add custom connector", with the name and the address filled
## in: claude.com/docs/connectors/building/directory-vs-custom.
func claude_ai_link() -> String:
	return ("https://claude.ai/customize/connectors?modal=add-custom-connector"
		+ "&connectorName=%s&connectorUrl=%s") % [NAME.uri_encode(), shared_address().uri_encode()]


## The same for Claude Code, which has no link: the command to paste.
func claude_code_command() -> String:
	return "claude mcp add --transport http brickworks " + shared_address()


## True while Claude (any of its apps) is signed in to this account.
func connected() -> bool:
	return not connections.is_empty()


## Whether the person switched Claude off in this tab.
func off_here() -> bool:
	return _off_here


## On again if it was on when the page was last open, with the same
## address, so the connector added to Claude keeps working; and on, too,
## if Claude is connected to the account and the person has not switched it
## off here. Run when somebody signs in.
func resume() -> void:
	if held:
		return
	var saved: Dictionary = _read()
	if bool(saved.get("on", false)) and not _token.is_empty():
		start()
	# Which switches it on, if Claude is connected (_set_connections).
	refresh_connections()


## The one click: listen here, put the shared address on the clipboard
## (for wherever the link cannot fill it in), and open claude.ai with
## Brickworks filled in — or, for an account that has had Claude connected
## ([member had_claude]), Claude's list of connectors, where the Brickworks
## it has is connected again. Then ask every few seconds for ten minutes
## whether Claude has connected; the relay also says so the moment it has.
func connect_claude() -> void:
	if held:
		return
	# Waiting before switching on, which tells the panels at once: set after
	# it, Connect Claude from Account left the assistant panel saying
	# "Connected through this tab's private address" while Claude was not.
	_waiting_until = Time.get_ticks_msec() + 600_000
	_next_ask = Time.get_ticks_msec() + 5000
	start()
	DisplayServer.clipboard_set(shared_address())
	last_opened = CONNECTORS if had_claude else claude_ai_link()
	if open_links:
		OS.shell_open(last_opened)


## Connected: one click to the Brickworks connector in Claude, for its
## tools and their permissions. With Claude connected there was no way back
## to it from here but Disconnect, which sets up a new connector and its
## permissions anew (2026-10-15).
func open_in_claude() -> void:
	last_opened = CONNECTORS
	if open_links:
		OS.shell_open(CONNECTORS)


## Where Connect Claude has sent the person and what to do there, in a
## sentence: adding Brickworks the first time, connecting the one they have
## after that. Claude's own names for it (claude.com/docs/connectors/
## getting-started, read 2026-10-14): Customize › Connectors, Your
## connectors, Connect, Reconnect, Tool permissions.
func connect_words() -> String:
	if had_claude:
		return ("Claude's connectors have opened (Customize › Connectors): select "
			+ "Brickworks under Your connectors, press Connect (or Reconnect, if it "
			+ "says so), and Allow when Brickworks asks. Connect the one you have "
			+ "rather than adding it again, which sets up a new one with its tool "
			+ "permissions to choose again.")
	return ("claude.ai has opened with Brickworks filled in: press Add, then "
		+ "Connect, and Allow when Brickworks asks.")


## Whether the person has been sent to connect Claude and it has not yet.
func waiting_for_claude() -> bool:
	return _waiting_until > Time.get_ticks_msec() and not connected()


## Ask the deployment which Claude apps are signed in to this account.
func refresh_connections() -> void:
	if account == null or not account.signed_in():
		had_claude = false
		_set_connections([])
		return
	_asking_connections = true
	var session: String = await account.access_token()
	if session.is_empty():
		_asking_connections = false
		return
	var got: Array = await _fetch(HTTPClient.METHOD_GET, "/api/oauth?op=connections", session)
	_asking_connections = false
	if int(got[0]) == 200 and got[1] is Dictionary:
		_take_connections(got[1] as Dictionary)


## The deployment's answer (op=connections): the connections, and whether
## the account has had Claude connected before.
func _take_connections(body: Dictionary) -> void:
	var now: Array = body.get("connections", []) as Array
	had_claude = bool(body.get("before", false)) or now.any(func(one: Variant) -> bool:
		return one is Dictionary and str((one as Dictionary).get("client", "")) == "Claude")
	_set_connections(now)


## End Claude's connection to this account: one ([param id]) or all of
## them. Claude's tokens stop working at once; to use it again, connect
## again. Returns how many were ended, or -1 if the deployment could not
## be asked.
func disconnect_claude(id: String = "") -> int:
	if account == null or not account.signed_in():
		return -1
	var session: String = await account.access_token()
	var path: String = "/api/oauth?op=disconnect" + ("&id=" + id if not id.is_empty() else "")
	var got: Array = await _fetch(HTTPClient.METHOD_POST, path, session)
	await refresh_connections()
	if int(got[0]) != 200 or not got[1] is Dictionary:
		return -1
	# Claude is not wanted here any more: this tab stops listening too, so
	# nothing reaches it until the person connects again.
	if not connected() and _on:
		stop()
	return int((got[1] as Dictionary).get("disconnected", 0))


func _set_connections(now: Array) -> void:
	var was: bool = connected()
	connections = now
	connections_known = true
	if connected():
		_waiting_until = 0
	connections_changed.emit(connections)
	# Connected while this tab was waiting for it: it is on already. On
	# another tab, or a page opened afterwards: on now, unless switched off.
	if connected() and not was and not _on and not _off_here \
			and account != null and account.signed_in():
		start()


## One request to the deployment with the session: [status, parsed body].
func _fetch(method: int, path: String, session: String) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(base_url + path, PackedStringArray([
			"authorization: Bearer " + session, "content-type: application/json"]),
			method, "" if method == HTTPClient.METHOD_GET else "{}") != OK:
		http.queue_free()
		return [0, null]
	var done: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	var text: String = (done[3] as PackedByteArray).get_string_from_utf8()
	return [int(done[1]), json.data if json.parse(text) == OK else null]


## Start listening, on the address this device keeps, or a new one.
func start() -> void:
	if _on or held:
		return
	if account == null or not account.signed_in():
		listening.emit(false, address())
		trouble.emit("Sign in to Brickworks to connect Claude.")
		return
	if _token.is_empty():
		_token = _new_token()
		_used = false
	_on = true
	_off_here = false
	_generation += 1
	_save()
	_watch_the_page()
	listening.emit(true, address())
	_listen()


## Stop listening. The address is kept, so switching on again needs no
## change in Claude; until then a call is told the tab is not listening.
## [param by_hand]: the person switched it off here, so a connection to the
## account does not switch it back on by itself.
func stop(by_hand: bool = false) -> void:
	if by_hand:
		_off_here = true
	var was_on: bool = _on
	_on = false
	_save()
	if was_on:
		_hang_up()


## Stop listening and say so, leaving what is kept as it was.
func _hang_up() -> void:
	_on = false
	_generation += 1
	_http.cancel_request()
	listening.emit(false, address())
	_watch_the_page()
	# Told so the relay can say "not open" at once, rather than after the
	# tab has been silent long enough to count as gone.
	_tell("close")


## Use an address already added to Claude — from another browser, or
## before this one's storage was cleared — so nothing changes in Claude.
## Takes the whole address or just its token. Returns "" or why not.
func adopt(given: String) -> String:
	var token: String = given.strip_edges()
	if token.contains("t="):
		token = token.get_slice("t=", 1).get_slice("&", 0)
	var shape := RegEx.create_from_string("^[A-Za-z0-9_-]{40,96}$")
	if shape.search(token) == null:
		return "That is not a Brickworks connector address."
	stop()
	_token = token
	# Claude has it already; that is the point.
	_used = true
	_save()
	start()
	return ""


## Forget the address altogether: anyone who had it can no longer reach
## this tab, and the next one is new. For an address that got out.
func forget() -> void:
	var was_on: bool = _on
	stop()
	_token = ""
	_used = false
	_save()
	if was_on:
		start()
	else:
		listening.emit(false, "")


func _tell(op: String) -> void:
	if _token.is_empty():
		return
	var note := HTTPRequest.new()
	add_child(note)
	note.request_completed.connect(func(_a: int, _b: int,
			_c: PackedStringArray, _d: PackedByteArray) -> void:
		note.queue_free())
	note.request("%s/api/mcp?t=%s&i=%s&op=%s" % [base_url, _token, _instance, op],
		PackedStringArray(), HTTPClient.METHOD_POST, "")


## The page, not the app, says when it goes out of view or away, and that
## it is still there; and while the connector is on it keeps the app
## running out of view.
##
## The engine asks the page for every frame (requestAnimationFrame), and a
## browser stops answering that for a tab it is not showing. So the page
## answers it instead while the tab is out of view and the connector is
## on: from a worker's clock, which a browser does not hold back the way it
## holds back the page's own timers — one frame at a time, 33 ms after the
## last has run, so the page keeps time for everything else it does. A
## frame asked for just before the tab went out of view is handed on too,
## once — the screen would otherwise sit on it until the tab came back.
## The same worker tells the relay the page is alive every ten seconds.
## sendBeacon carries out-of-view and closed, and is let through at the
## moment a page is being closed.
func _watch_the_page() -> void:
	if not OS.has_feature("web"):
		return
	var url: String = ("%s/api/mcp?t=%s&i=%s" % [base_url, _token, _instance]
		if _on else "")
	JavaScriptBridge.eval("""
		window.brickworksConnector = %s;
		if (!window.brickworksConnectorWatched) {
			window.brickworksConnectorWatched = true;
			var paint = window.requestAnimationFrame.bind(window);
			var waiting = [];
			var pending = null;
			var clock = null;
			var ticking = false;
			function once(callback) {
				var done = false;
				return function (time) {
					if (done) return;
					done = true;
					callback(time);
				};
			}
			function frame() {
				ticking = false;
				var now = performance.now();
				var run = waiting;
				waiting = [];
				for (var i = 0; i < run.length; i++) run[i](now);
			}
			// One frame asked for at a time, and only once the last has run.
			// A clock that ticked regardless queued its ticks faster than a
			// frame could be drawn, the frames ran back to back, and nothing
			// else in the page got a turn — the replies carrying the app's
			// answers among them, so a call was taken and never answered.
			function tick() {
				if (ticking || !waiting.length) return;
				ticking = true;
				clock.postMessage({frame: 33});
			}
			function tell(op) {
				var url = window.brickworksConnector;
				if (url) navigator.sendBeacon(url + op);
			}
			// That the page is alive, whether it is in view, when the person
			// last used it and what its model is called: the relay lists the
			// tabs by these and sends a session's calls to the tab used last.
			function alive() {
				return "&op=state&visible=" + (document.hidden ? "0" : "1")
					+ "&used=" + (window.brickworksUsedAgo ? window.brickworksUsedAgo() : "")
					+ "&model=" + encodeURIComponent(String(window.brickworksModelName || "").slice(0, 120));
			}
			var focusedAt = 0;
			function steer() {
				var away = document.hidden && !!window.brickworksConnector;
				if (!clock) {
					var code = "var b=null;onmessage=function(e){" +
						"if(e.data.frame>0){setTimeout(function(){postMessage('frame')},e.data.frame);return}" +
						"clearInterval(b);b=null;" +
						"if(e.data.beat>0)b=setInterval(function(){postMessage('beat')},e.data.beat)};";
					clock = new Worker(URL.createObjectURL(new Blob([code], {type: "text/javascript"})));
					clock.onmessage = function (e) {
						if (e.data === "frame") frame();
						else tell(alive());
					};
				}
				clock.postMessage({beat: window.brickworksConnector ? 10000 : 0});
				if (away && pending) {
					waiting.push(pending);
					tick();
				}
				if (!document.hidden) frame();
			}
			window.brickworksSteer = steer;
			window.requestAnimationFrame = function (callback) {
				var wrapped = once(callback);
				if (document.hidden && window.brickworksConnector) {
					waiting.push(wrapped);
					tick();
					return 0;
				}
				pending = wrapped;
				return paint(wrapped);
			};
			document.addEventListener("visibilitychange", function () {
				tell(alive());
				steer();
			});
			// Used now: said at once, so a call made the moment the person
			// comes back from another tab goes to this one.
			window.addEventListener("focus", function () {
				if (Date.now() - focusedAt < 2000) return;
				focusedAt = Date.now();
				tell(alive());
			});
			window.addEventListener("pagehide", function () {
				tell("&op=close");
			});
		}
		window.brickworksSteer();
	""" % JSON.stringify(url), true)


## Which tab this is, as the relay and Claude know it.
func tab() -> String:
	return tab_id if not tab_id.is_empty() else TabSession.id()


func _file() -> String:
	if not kept_in.is_empty():
		return kept_in
	if not where.is_empty():
		return where
	return TabSession.ROOT + tab() + "/claude_connector.json"


func _read() -> Dictionary:
	if not FileAccess.file_exists(_file()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_file()))
	return parsed if parsed is Dictionary else {}


func _load() -> void:
	var saved: Dictionary = _read()
	var token: String = str(saved.get("token", ""))
	_token = token if token.length() >= 40 else ""
	_used = bool(saved.get("used", false)) and not _token.is_empty()
	_off_here = bool(saved.get("off_here", false))


func _save() -> void:
	if _token.is_empty() and not _off_here:
		if FileAccess.file_exists(_file()):
			DirAccess.remove_absolute(_file())
		return
	DirAccess.make_dir_recursive_absolute(_file().get_base_dir())
	var file: FileAccess = FileAccess.open(_file(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"token": _token, "on": _on, "used": _used,
		"off_here": _off_here}))
	file.close()


## Said to Claude first, ahead of the app's guidance. Short: Claude Code
## reads only the first 3,800 characters of a server's instructions, and
## the app's own head (Assistant.GUIDE_HEAD) is most of that, so what a
## session must act on goes in the answers instead — a paused tab says to
## ask for it to be shown, and every answer names its tab and model, and
## says when others are open (api/mcp.js). mcp_sync_probe holds the two
## together under the limit.
const CONNECTED_NOTE := ("These tools build in Brickworks, in a tab of the "
	+ "person's browser that keeps working while they are here. Each answer "
	+ "begins with the tab and model it acted on; tabs lists them all.\n\n")


func _model() -> String:
	var said: Variant = model_name.call()
	return str(said).left(120) if said != null else ""


## Seconds since the person last used this tab or window: the relay sends
## a session's calls to the one used most recently. On the web the page
## counts presses and focus; on the desktop, the window having focus
## ([method _process]). -1 for a window nobody has used — one run headless
## — which the relay leaves as it was rather than call it used just now.
func _used_ago() -> int:
	if OS.has_feature("web"):
		var ago: Variant = JavaScriptBridge.eval(
			"window.brickworksUsedAgo ? window.brickworksUsedAgo() : 0", true)
		return int(ago) if ago != null else 0
	if _focused_at == 0:
		return -1
	return (Time.get_ticks_msec() - _focused_at) / 1000


var _focused_at: int = 0


## What this tab would answer to the handshake and the tool list, for the
## relay to answer with while the tab cannot; sent with the person's
## session, which makes the connector theirs. The relay's status: 204 when
## it took it, 401 when it would not take this tab as signed in, 403 when
## another account owns the address, 0 when nothing answered.
func _hello() -> int:
	if rpc == null:
		return 0
	var session: String = await account.access_token() if account != null else ""
	if session.is_empty():
		return 401
	var greeted: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "initialize", "params": {}})
	var listed: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 2,
		"method": "tools/list", "params": {}})
	var body: Dictionary = {
		"instructions": CONNECTED_NOTE + str(((greeted as Dictionary)
			.get("result", {}) as Dictionary).get("instructions", "")),
		"tools": ((listed as Dictionary).get("result", {}) as Dictionary).get("tools", []),
	}
	body["model"] = _model()
	var got: Array = await _ask(_http, "%s/api/mcp?t=%s&i=%s&tab=%s&used=%d&op=hello" % [
		base_url, _token, _instance, tab(), _used_ago()], JSON.stringify(body),
		PackedStringArray(["authorization: Bearer " + session]))
	return int(got[1]) if got[0] == HTTPRequest.RESULT_SUCCESS else 0


## 32 random bytes, URL-safe. Crypto rather than randi(): this is a
## credential, and a guessable one would let anyone build in someone
## else's tab.
static func _new_token() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(32)
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace(
		"/", "_").replace("=", "")


func _listen() -> void:
	var token: String = _token
	var mine: int = _generation
	while true:
		var greeted: int = await _hello()
		if mine != _generation:
			return
		if greeted == 204:
			relay_ok.emit()
			break
		if greeted == 401 or greeted == 403:
			# Not something trying again fixes: off, and why.
			_on = false
			_generation += 1
			_save()
			_watch_the_page()
			listening.emit(false, address())
			trouble.emit("Sign in to Brickworks again to connect Claude."
				if greeted == 401 else
				"This address was switched on by another Brickworks account. "
				+ "Make a new address to connect Claude with yours.")
			return
		trouble.emit("Could not reach Brickworks' relay; trying again.")
		await get_tree().create_timer(3.0).timeout
	while mine == _generation:
		_asking_since = Time.get_ticks_msec()
		var got: Array = await _ask(_http, "%s/api/mcp?t=%s&i=%s&used=%d&model=%s&op=next" % [
			base_url, token, _instance, _used_ago(), _model().uri_encode()], "")
		if mine != _generation:
			return
		_asking_since = 0
		var result: int = got[0]
		var code: int = got[1]
		if code == 409:
			# Another page switched it on since; that one has it now.
			_on = false
			_generation += 1
			_watch_the_page()
			listening.emit(false, address())
			replaced.emit()
			return
		if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 0:
			trouble.emit("Could not reach Brickworks' relay; trying again.")
			_troubled = true
			await get_tree().create_timer(3.0).timeout
			continue
		if _troubled:
			_troubled = false
			relay_ok.emit()
		if code == 204:
			continue
		if code == 401:
			# The relay has no signed-in hello for this address any more
			# (the account went, or the row was swept): say it again,
			# which signs it in or switches it off saying why.
			await get_tree().create_timer(2.0).timeout
			if mine != _generation:
				return
			_generation += 1
			_listen()
			return
		if code != 200:
			trouble.emit("The relay refused this tab (%d)." % code)
			await get_tree().create_timer(5.0).timeout
			continue
		var work: Variant = JSON.parse_string((got[2] as PackedByteArray)
			.get_string_from_utf8())
		if typeof(work) != TYPE_DICTIONARY:
			continue
		await _answer(token, work as Dictionary)


func _answer(token: String, work: Dictionary) -> void:
	var request: Dictionary = work.get("request", {}) as Dictionary
	# Claude has just been signed in to the account (api/oauth.js tells the
	# account's tabs): the panel says so now, before Claude has called.
	if str(request.get("method", "")) == "brickworks/connected":
		refresh_connections()
		return
	if str(request.get("method", "")) == "brickworks/claude_here" and not connected() \
			and not _asking_connections:
		refresh_connections()
	var tool: String = ""
	var arguments: Dictionary = {}
	if str(request.get("method", "")) == "tools/call":
		var params: Dictionary = request.get("params", {}) as Dictionary
		tool = str(params.get("name", ""))
		var given: Variant = params.get("arguments", {})
		arguments = given if given is Dictionary else {}
	if not _used:
		_used = true
		_save()
	# The card in Claude asking for the model, the check or the steps
	# (ViewerTools) is the person looking, not Claude building: the panel
	# does not say Claude is at work for it.
	var looking: bool = ViewerTools.handles(tool)
	if not looking:
		called.emit(tool, arguments)
	# A notification — the relay saying Claude reached it, or one of the
	# protocol's own — wants no answer, and the relay has already let it go.
	if request.get("id") == null:
		return
	var answer: Variant = null
	if rpc != null:
		answer = await rpc.answer_rpc(request)
	if answer == null:
		answer = {"jsonrpc": "2.0", "id": request.get("id"),
			"error": {"code": -32603, "message": "this tab cannot answer"}}
	# Which tab answered, and what its model is called now: the relay
	# starts every answer by naming them, so a session working with several
	# tabs open knows where each call landed (api/mcp.js).
	# Added to what the answer carries already (the viewer's, ModelViews).
	if (answer as Dictionary).get("result") is Dictionary:
		var carried: Dictionary = (answer as Dictionary)["result"]
		var meta: Dictionary = carried.get("_meta") if carried.get("_meta") is Dictionary else {}
		meta["brickworks/tab"] = tab()
		meta["brickworks/model"] = _model()
		carried["_meta"] = meta
	await _ask(_reply, "%s/api/mcp?t=%s&op=answer&id=%d" % [base_url, token,
		int(work.get("id", 0))], JSON.stringify(answer))
	if looking:
		return
	var result: Dictionary = (answer as Dictionary).get("result", {}) as Dictionary
	var said := PackedStringArray()
	for block: Variant in result.get("content", []) as Array:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			said.append(str((block as Dictionary).get("text", "")))
	answered.emit(tool, not bool(result.get("isError", false))
		and not (answer as Dictionary).has("error"), "\n".join(said))


## A POST, awaited: [result, code, body].
func _ask(http: HTTPRequest, url: String, body: String,
		more: PackedStringArray = PackedStringArray()) -> Array:
	var headers := PackedStringArray(["content-type: application/json"])
	headers.append_array(more)
	if http.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	var done: Array = await http.request_completed
	return [done[0], done[1], done[3]]
