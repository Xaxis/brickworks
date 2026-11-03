## Every AI app Brickworks connects to, from one table:
## res://assets/assistants.json.
##
## The owner (2026-11-02): connecting ChatGPT, Gemini or any provider should
## be as easy as Claude, and the workflows as alike as each allows. The
## relay already serves any app that speaks MCP (docs/ANY_ASSISTANT.md, A.3);
## what differs is how each adds Brickworks, so that is all this holds, as
## data: one row an assistant, Claude first, with its way in the fewest
## steps it allows, those steps in its own screens' words, who may, what it
## cannot do yet, and how a new chat for a tab starts in it. Connect your
## AI (ConnectorForm), New chat for this tab (ClaudeTabView) and, from U4,
## the site's pages read the same rows, so they cannot disagree.
##
## A row's way:
##   link     its own link opens it with Brickworks filled in (Claude,
##            Cursor, VS Code)
##   command  a command, copied, to run in a terminal (Claude Code, Codex,
##            Gemini CLI)
##   open     the address copied and its own page opened, to paste it in
##            (ChatGPT, Gemini, Le Chat, Perplexity, Grok)
##   copy     the address copied, for any other app
## A link's or a command's words take {address}, {address_uri}, {name},
## {name_uri}, {key}, {config_base64} (Cursor's: the server as JSON, then
## base64, then percent-encoded) and {config_json_uri} (VS Code's: the
## server as JSON, percent-encoded); a new chat's, {message} and
## {message_uri}.
class_name Assistants
extends RefCounted

const TABLE := "res://assets/assistants.json"
## The one that is chosen until another is.
const CLAUDE := "claude"

## What the server is called in each app, and the rows, read at the class's
## load (the server first: _read sets it).
static var _server: Dictionary = {"name": "Brickworks", "key": "brickworks"}
static var _rows: Array[Dictionary] = _read()


static func _read() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	if not parsed is Dictionary:
		push_error("Assistants: %s is missing or not JSON" % TABLE)
		return rows
	if (parsed as Dictionary).get("server") is Dictionary:
		_server = (parsed as Dictionary)["server"]
	for one: Variant in (parsed as Dictionary).get("assistants", []):
		if one is Dictionary and not str((one as Dictionary).get("id", "")).is_empty():
			rows.append(one)
	return rows


## Every assistant, in the table's order.
static func all() -> Array[Dictionary]:
	return _rows


## The row of [param id], or Claude's when there is none.
static func find(id: String) -> Dictionary:
	for one: Dictionary in _rows:
		if str(one["id"]) == id:
			return one
	return _rows[0] if not _rows.is_empty() else {"id": CLAUDE, "name": "Claude", "way": "link"}


static func known(id: String) -> bool:
	return _rows.any(func(one: Dictionary) -> bool: return str(one["id"]) == id)


## What a row is named in the chooser: "ChatGPT", "Another app".
static func name_of(id: String) -> String:
	return str(find(id).get("name", "Claude"))


## What a sentence calls it: its name, or a row's own words for a sentence
## where its name would not read ("Connect your AI app", not "Connect
## Another app").
static func called(id: String) -> String:
	var row: Dictionary = find(id)
	return str(row.get("called", row.get("name", "Claude")))


## How [param id] adds Brickworks at [param address]: {way, open, copy}:
## what to hand the system ("" for nothing) and what to put on the
## clipboard: the command for a command, else the address.
static func adding(id: String, address: String) -> Dictionary:
	var row: Dictionary = find(id)
	var way: String = str(row.get("way", "copy"))
	var words: String = fill(str(row.get("add", "")), address)
	return {"way": way, "open": words if way in ["link", "open"] else "",
		"copy": words if way == "command" else address}


## How [param id] starts a new chat whose first message is [param message]:
## {way, open, copy}. A link fills the message in and copies it too, for
## wherever it does not; a page is opened with the message copied, to
## paste; a command is copied; otherwise the message alone is copied.
static func new_chat(id: String, message: String) -> Dictionary:
	var chat: Dictionary = find(id).get("new_chat", {}) if find(id).get("new_chat") is Dictionary else {}
	var way: String = str(chat.get("way", "copy"))
	var to: String = fill(str(chat.get("to", "")), "", message)
	return {"way": way, "open": to if way in ["link", "open"] else "",
		"copy": to if way == "command" else message}


## [param words] with the server's and [param address]'s places filled in.
static func fill(words: String, address: String, message: String = "") -> String:
	var name: String = str(_server.get("name", "Brickworks"))
	var key: String = str(_server.get("key", "brickworks"))
	# A message in a command goes between double quotes, which every shell
	# takes: nothing in it a shell would read.
	var plain: String = message
	for awkward: String in ["\"", "$", "`", "\\", "!", "%"]:
		plain = plain.replace(awkward, "")
	return words.format({
		"address": address, "address_uri": address.uri_encode(),
		"name": name, "name_uri": name.uri_encode(), "key": key,
		"config_base64": Marshalls.utf8_to_base64(JSON.stringify({"url": address})).uri_encode(),
		"config_json_uri": JSON.stringify({"name": key, "type": "http", "url": address}).uri_encode(),
		"message": plain, "message_uri": message.uri_encode(),
	})
