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
## for the protocol's own requests, and which chat asked (the relay's short
## name for it, or "" when it named none); and it was answered — whether
## the tool did what was asked, and what it said.
signal called(tool: String, arguments: Dictionary, chat: String)
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
## The Claude chats working in this tab changed (see [member chats]).
signal chats_changed(chats: Array)

## The Claude chats working in this tab, as the relay says and as their
## calls come (2026-10-17): each {chat, since, last, did, words}: a short
## name for the chat, when it chose this tab and when it last called (ISO,
## UTC), which tool that was, and what it did in words. Two at once is two
## chats editing one model, which the tab says plainly ([method keep_chat]).
var chats: Array = []
## How long a chat that has said nothing still counts as working here: the
## relay's HELD_MS (api/mcp.js).
const HELD_S := 30 * 60

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


## A Claude chat for this tab (2026-10-17): Claude opened on a new chat
## whose first message names this tab, so the chat's first call chooses it
## (select_tab, api/mcp.js) and it never lands in a tab another chat is
## building in. Claude's own links, each filling the message in for the
## person to read and send, never sending it:
##   claude.ai        https://claude.ai/new?q=…   (not in Anthropic's docs;
##                    the desktop's documented link below is the same path)
##   the Claude app   claude://claude.ai/new?q=…  support.claude.com/en/
##                    articles/14729294-open-claude-desktop-with-a-link
##   Claude Code      claude-cli://open?q=…, code.claude.com/docs/en/
##                    deep-links; or the command line to paste
## The message is copied too, for wherever a link cannot fill it in.
const NEW_CHAT := "https://claude.ai/new?q="
const NEW_CHAT_APP := "claude://claude.ai/new?q="
const NEW_CHAT_CODE := "claude-cli://open?q="


## What this tab is called to Claude and to the person: its id, and its
## model's name when it has one: "k7qd (“Castle”)".
func tab_words() -> String:
	var model: String = _model().strip_edges()
	return tab() + (" (“%s”)" % model if not model.is_empty() and model != ModelStore.UNTITLED else "")


## The first message of a chat for this tab, for the person to send as it
## is or to go on typing after.
func first_message() -> String:
	return "Use my Brickworks tab %s for this chat." % tab_words()


## The link that opens [param where] ("claude.ai", "app", "code") on a new
## chat with [method first_message] filled in.
func new_chat_link(where: String = "claude.ai") -> String:
	var start: String = {"app": NEW_CHAT_APP, "code": NEW_CHAT_CODE}.get(where, NEW_CHAT)
	return start + first_message().uri_encode()


## The same for Claude Code from a shell: a command line to paste. Double
## quotes, which every shell takes, round a message with none in it.
func new_chat_command() -> String:
	var said: String = first_message()
	for awkward: String in ["\"", "$", "`", "\\", "!", "%"]:
		said = said.replace(awkward, "")
	return "claude \"%s\"" % said


## Opens [param where] on a new chat for this tab, and copies its first
## message (for Claude Code, the command line) for wherever it is not filled in.
func start_chat(where: String = "claude.ai") -> void:
	DisplayServer.clipboard_set(new_chat_command() if where == "code" else first_message())
	last_opened = new_chat_link(where)
	if not open_links:
		return
	if OS.has_feature("web") and where != "claude.ai":
		# An app's own link, followed in place: a new browser tab for it
		# would be left behind empty. Nothing happens where the app is not
		# installed, and the page stays as it was.
		JavaScriptBridge.eval("(function (u) { var a = document.createElement('a'); "
			+ "a.href = u; a.rel = 'noopener'; document.body.appendChild(a); a.click(); a.remove(); })(%s)"
			% JSON.stringify(last_opened), true)
		return
	OS.shell_open(last_opened)


## The chats working in this tab now: the ones heard from within
## [constant HELD_S], oldest first.
func working() -> Array:
	var now: int = int(Time.get_unix_time_from_system())
	return chats.filter(func(one: Variant) -> bool:
		return one is Dictionary and now - _unix(str((one as Dictionary).get("last", ""))) < HELD_S)


## Keep [param chat] working in this tab and move every other chat off it:
## the other's next call is told so and does nothing. Returns how many were
## moved, or -1 if the relay could not be asked.
func keep_chat(chat: String) -> int:
	if _token.is_empty():
		return -1
	var got: Array = await _ask_aside("%s/api/mcp?t=%s&i=%s&op=keep&chat=%s"
		% [base_url, _token, _instance, chat.uri_encode()])
	var body: Variant = JSON.parse_string((got[2] as PackedByteArray).get_string_from_utf8()) \
		if got[0] == HTTPRequest.RESULT_SUCCESS else null
	if body is Dictionary and (body as Dictionary).get("chats") is Array:
		_set_chats((body as Dictionary)["chats"], true)
	return int((body as Dictionary).get("moved", -1)) if body is Dictionary and int(got[1]) == 200 else -1


## Asks the relay which chats work in this tab: as it switches on, when a
## page comes back.
func refresh_chats() -> void:
	if _token.is_empty() or not _on:
		return
	var got: Array = await _ask_aside("%s/api/mcp?t=%s&i=%s&op=chats" % [base_url, _token, _instance])
	if got[0] != HTTPRequest.RESULT_SUCCESS or int(got[1]) != 200:
		return
	var body: Variant = JSON.parse_string((got[2] as PackedByteArray).get_string_from_utf8())
	if body is Dictionary and (body as Dictionary).get("chats") is Array:
		_set_chats((body as Dictionary)["chats"])


## The relay's list, keeping the words this tab heard for a chat's last call.
## The relay lists the chats that chose this tab; one that named it on its
## calls instead (target) and called in the last two minutes stays shown,
## unless [param whole]: the list after Keep this one is the whole of it.
func _set_chats(given: Array, whole: bool = false) -> void:
	var heard: Dictionary = {}
	for one: Variant in chats:
		if one is Dictionary:
			heard[str((one as Dictionary).get("chat", ""))] = one
	var listed: Dictionary = {}
	for one: Variant in given:
		if one is Dictionary:
			listed[str((one as Dictionary).get("chat", ""))] = true
	var now: Array = []
	if not whole:
		var at: int = int(Time.get_unix_time_from_system())
		for chat: String in heard:
			if not listed.has(chat) and at - _unix(str((heard[chat] as Dictionary).get("last", ""))) < 120:
				now.append(heard[chat])
	for one: Variant in given:
		if not one is Dictionary:
			continue
		var it: Dictionary = (one as Dictionary).duplicate()
		var was: Dictionary = heard.get(str(it.get("chat", "")), {})
		if str(was.get("did", "")) == str(it.get("did", "")) and not str(was.get("words", "")).is_empty():
			it["words"] = was["words"]
		elif not str(it.get("did", "")).is_empty():
			it["words"] = ConnectorForm.said(str(it["did"]))
		now.append(it)
	chats = now
	chats_changed.emit(chats)


## A call from a chat working in this tab (the relay names it on the call's
## _meta): when, and what it did.
func _chat_called(request: Dictionary, tool: String, arguments: Dictionary) -> void:
	var said: Dictionary = _chat_said(request)
	var chat: String = str(said.get("chat", ""))
	if chat.is_empty():
		return
	var at: String = Time.get_datetime_string_from_system(true) + "Z"
	var found: Dictionary = {}
	for one: Variant in chats:
		if one is Dictionary and str((one as Dictionary).get("chat", "")) == chat:
			found = one
	if found.is_empty():
		found = {"chat": chat, "since": str(said.get("since", at))}
		chats.append(found)
	found["last"] = at
	found["did"] = tool
	found["words"] = ConnectorForm.said(tool, arguments)
	chats_changed.emit(chats)


## Which chat the relay says made [param request]: {chat, since}, or empty.
static func _chat_said(request: Dictionary) -> Dictionary:
	var params: Dictionary = request.get("params", {}) if request.get("params") is Dictionary else {}
	var meta: Dictionary = params.get("_meta", {}) if params.get("_meta") is Dictionary else {}
	return meta.get("brickworks/chat", {}) if meta.get("brickworks/chat") is Dictionary else {}


## Each chat working in this tab, by the relay's short name ("" for calls that
## name none: a tab's own address), as one sitting: when it last called, and
## whether it has been told how to work here (Assistant.METHOD) and has begun
## its subject; the assistant keeps which sizes it was told (_sizes_once), and
## a new sitting is told them again. A chat quiet for longer than
## [constant QUIET_MS] begins a new sitting, as the relay stops counting it in
## the tab then (api/mcp.js HELD_MS): claude.ai is reported to share one
## session between two of its conversations (claudeissues.com/issue/41836),
## and the second would otherwise never be told.
var _sittings: Dictionary = {}
const QUIET_MS := 30 * 60 * 1000
## The calls that say what is being designed, with the words that say it.
const SUBJECT_CALLS := ["how_real_sets_build_this", "plan_scale", "find_reference",
	"submit_design"]


func _sitting(request: Dictionary) -> Dictionary:
	var chat: String = str(_chat_said(request).get("chat", ""))
	var now: int = Time.get_ticks_msec()
	var sitting: Dictionary = _sittings.get(chat, {})
	if sitting.is_empty() or now - int(sitting["last"]) > QUIET_MS:
		sitting = {"told": false, "begun": false}
		_sittings[chat] = sitting
		if rpc != null and rpc.assistant != null:
			rpc.assistant.sitting_begun(chat)
	sitting["last"] = now
	return sitting


## A chat's first design call begins its subject, as the bench's brief begins
## one (Main.design_with_claude_code, Assistant.heard(brief, true)): what an
## earlier chat in this tab designed, its part count and what it was told,
## is not this one's. The tab never hears the person's words, so the subject
## is the call's own.
func _begin(sitting: Dictionary, tool: String, arguments: Dictionary) -> void:
	if not tool in SUBJECT_CALLS or bool(sitting["begun"]) or rpc == null or rpc.assistant == null:
		return
	sitting["begun"] = true
	var subject: String = str(arguments.get("subject", "")) if tool != "submit_design" \
		else "%s. %s" % [arguments.get("name", ""), arguments.get("description", "")]
	rpc.assistant.heard(subject.strip_edges().trim_suffix(".").strip_edges(), true)


## [param answer] as the chat is sent it: its first answer in this tab with
## the working method ahead of the tool's own words, which a client that
## shows no instructions never had. Once a sitting, never in every answer: a
## word said in every answer is heard twenty times and misleads (pose174,
## 2026-10-23). The panel's copy of the answer is the tool's alone.
func _taught(sitting: Dictionary, tool: String, answer: Variant) -> Variant:
	if tool.is_empty() or bool(sitting["told"]) or not answer is Dictionary \
			or not (answer as Dictionary).get("result") is Dictionary \
			or not ((answer as Dictionary)["result"] as Dictionary).get("content") is Array:
		return answer
	sitting["told"] = true
	var sent: Dictionary = (answer as Dictionary).duplicate()
	var result: Dictionary = (sent["result"] as Dictionary).duplicate()
	result["content"] = [{"type": "text", "text": Assistant.METHOD}] + (result["content"] as Array)
	sent["result"] = result
	return sent


## An ISO time from the relay, in seconds since 1970 (UTC).
static func _unix(iso: String) -> int:
	if iso.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)))


## A POST of its own, beside the request waiting for work: [result, code, body].
func _ask_aside(url: String) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var got: Array = await _ask(http, url, "{}")
	http.queue_free()
	return got


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
	# No chat reaches a tab that is not listening.
	if not chats.is_empty():
		chats = []
		chats_changed.emit(chats)
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
			// Going away: the page's every word to the relay from pagehide on
			// says so. Two beacons sent in the same moment as a tab closed, one
			// was sometimes lost on the way, and when it was the goodbye, the
			// relay took the closed tab for one paused out of view and a
			// chat's next call waited on it (tabs_flow on m99, 2026-10-19:
			// close sent, never received, the visibility beacon after it
			// received). So the visibility change that follows pagehide says
			// goodbye too. A page kept to go back to (pageshow) is here again.
			var leaving = false;
			document.addEventListener("visibilitychange", function () {
				tell(leaving ? "&op=close" : alive());
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
				leaving = true;
				tell("&op=close");
			});
			window.addEventListener("pageshow", function () {
				leaving = false;
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
const CONNECTED_NOTE := ("These tools build in the person's Brickworks tab, "
	+ "which works on while they are here. Each answer names its tab and model. "
	+ "When the person names a tab or model, call select_tab first.\n\n")


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
			# A page reloaded or switched on again: which chats work here.
			refresh_chats()
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
	# Which chats work in this tab now: one chose it, or left it.
	if str(request.get("method", "")) == "brickworks/chats":
		var listed: Variant = (request.get("params", {}) as Dictionary).get("chats", []) \
			if request.get("params") is Dictionary else []
		if listed is Array:
			_set_chats(listed)
		return
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
		if not tool.is_empty():
			_chat_called(request, tool, arguments)
		called.emit(tool, arguments, str(_chat_said(request).get("chat", "")))
	# A notification — the relay saying Claude reached it, or one of the
	# protocol's own — wants no answer, and the relay has already let it go.
	if request.get("id") == null:
		return
	var sitting: Dictionary = {}
	if not looking and not tool.is_empty():
		sitting = _sitting(request)
		_begin(sitting, tool, arguments)
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
		int(work.get("id", 0))], JSON.stringify(answer if sitting.is_empty() else _taught(sitting, tool, answer)))
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
