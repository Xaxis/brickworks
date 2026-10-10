## What the deployment says about itself, asked once at start-up.
##
## One thing, now: where the part geometry this build did not ship is
## served from. The library is larger than a deployment can hold as
## files, so most of it lives somewhere else, and only the deployment
## knows where.
##
## This was the account probe until 2026-10-09, when accounts were
## removed. Nobody signs in: the assistant runs on a key of the person's
## own, sent only to Anthropic, or on their own Claude plan. The question
## still goes to /api/account, because that is where builds already out
## ask it.
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


func _ask() -> void:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(api_base() + "/api/account") != OK:
		http.queue_free()
		settled.emit()
		return
	var result: Array = await http.request_completed
	http.queue_free()

	# Parsed through an instance rather than JSON.parse_string, which
	# pushes an engine error when the body is not JSON. It often is not:
	# a deployment with no functions behind it answers every path with
	# the page. Offline is not worth a red line either — everything but
	# the parts this build did not ship still works.
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	if int(result[1]) == 200 and json.parse(text) == OK \
			and typeof(json.data) == TYPE_DICTIONARY:
		answered = true
		var named: Variant = (json.data as Dictionary).get("parts_url")
		parts_url = str(named) if named != null else ""
	settled.emit()
