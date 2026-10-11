## What the deployment says about itself, asked once at start-up.
##
## Two things: where the part geometry this build did not ship is served
## from — the library is larger than a deployment can hold as files, so
## most of it lives somewhere else, and only the deployment knows where —
## and whether it has accounts, with where to sign in if it does. Since
## 2026-10-11 everyone who uses Brickworks signs in; [Account] reads that
## half of the answer.
##
## The question goes to /api/account, which is where builds already out
## ask it, accounts or not.
class_name Deployment
extends Node

## Where the endpoint lives when the app is not itself being served from
## there. The web build asks its own origin.
const HOSTED := "https://brickworks.diy"

## Where the geometry this build did not ship is served from, as the
## deployment reports it. Empty means beside the app.
var parts_url: String = ""
## Whether the deployment actually replied. False while the question is
## still out and false if it failed, which are not the same thing as a
## reply that named nothing.
var answered: bool = false
## True once the question is over, answered or not. [signal settled] is
## emitted once; anyone arriving later reads this instead of waiting.
var finished: bool = false
## Whether this deployment has accounts, so everyone signs in. A
## deployment without them (a local server, somebody's own copy) has
## nothing to sign in to.
var accounts: bool = false
## Where sign-in is: the Supabase project and its publishable key, which
## is meant to be in a client. Served rather than compiled in, so a
## rotated key reaches a desktop build without anyone reinstalling.
var accounts_url: String = ""
var accounts_key: String = ""

## Emitted once, when the question is over, whether or not anything
## answered. Anyone waiting on it needs to hear that it failed, too.
signal settled


func _ready() -> void:
	_ask()


## The base the endpoint hangs off. The deployment itself on the web, so
## a preview asks itself rather than production; on desktop the hosted
## one, unless pointed somewhere else — which is how a local `vercel dev`
## gets exercised by the real client rather than by curl.
static func api_base() -> String:
	if OS.has_feature("web"):
		# Absolute, not "/api/…". HTTPRequest refuses a relative URL.
		return Origin.here()
	var override: String = OS.get_environment("BRICKWORKS_API")
	return override.rstrip("/") if not override.is_empty() else HOSTED


## Wait for the answer if it is still out; at once if it is in.
func wait() -> void:
	if not finished:
		await settled


func _ask() -> void:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(api_base() + "/api/account") != OK:
		http.queue_free()
		_finish()
		return
	var result: Array = await http.request_completed
	http.queue_free()

	# Parsed through an instance rather than JSON.parse_string, which
	# pushes an engine error when the body is not JSON. It often is not:
	# a deployment with no functions behind it answers every path with
	# the page. Offline is not worth a red line either.
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	if int(result[1]) == 200 and json.parse(text) == OK \
			and typeof(json.data) == TYPE_DICTIONARY:
		var body: Dictionary = json.data
		answered = true
		var named: Variant = body.get("parts_url")
		parts_url = str(named) if named != null else ""
		accounts = bool(body.get("enabled", false))
		if accounts:
			accounts_url = str(body.get("url", "")).rstrip("/")
			accounts_key = str(body.get("key", ""))
			# Enabled with nowhere to sign in is no accounts at all.
			accounts = not accounts_url.is_empty() and not accounts_key.is_empty()
	_finish()


func _finish() -> void:
	finished = true
	settled.emit()
