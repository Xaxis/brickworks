## Models shared by link (api/share.js): publishing the one that is open,
## taking it down, and fetching somebody's for the viewer.
##
## A link is https://brickworks.diy/m/<id>. Publishing needs the session;
## reading needs nothing, which is the point of a link. What the server
## checks and keeps is in api/share.js and supabase/shared_models.sql.
class_name SharedModels
extends Node

## A link's id, as the server makes them. Anything else in a page's
## address is refused before it reaches a request.
const ID := "^[A-Za-z0-9]{10}$"


static func is_id(text: String) -> bool:
	return RegEx.create_from_string(ID).search(text) != null


## Where a link points, on this deployment.
static func link_for(id: String) -> String:
	return Deployment.api_base() + "/m/" + id


## The snippet a blog or a forum puts in a page: the link's card, framed.
static func embed_for(id: String) -> String:
	return ('<iframe src="%s/embed" width="560" height="420" style="border:0;max-width:100%%" '
		+ 'title="A Brickworks model" loading="lazy"></iframe>') % link_for(id)


## The model at a link: {code, body}. 200 with {name, author, parts,
## model, url…}; 410 taken down; 404 never there; 0 unreachable.
##
## Asked up to three times when nothing came back at all. A visitor's first
## request goes out while the engine is still starting, and a browser drawing
## in software can stall a frame long enough for it to come back as nothing:
## a viewer on a preview said "Could not reach Brickworks" once in four runs,
## and the same link opened at the next try. Reading is safe to repeat.
##
## [param version] asks for that version of it (/m/<id>/v/<n>); 0 is the
## newest. Either way the answer says which it is ("version", "newest") and
## what each version changed ("versions"), newest first.
func fetch(id: String, version: int = 0) -> Dictionary:
	var answer: Dictionary = await _asked_early(id, version)
	if not answer.is_empty():
		return answer
	var path: String = "/api/share?id=" + id.uri_encode() + ("&v=%d" % version if version > 0 else "")
	for attempt: int in 3:
		answer = await _fetch(path, HTTPClient.METHOD_GET, "", "")
		if int(answer["code"]) != 0:
			break
		await get_tree().create_timer(1.5 * (attempt + 1)).timeout
	return answer


## Publish {name, author?, model, image?, id?} as the session's account.
## The link's answer as the page asked for it before the engine started
## (src/boot/shell.html, window.brickworksSharePrefetch), taken once; empty
## when the page did not ask, asked for another link, or got nothing, and
## the link is then asked for here.
func _asked_early(id: String, version: int = 0) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var asked: String = "(function(){var p=window.brickworksSharePrefetch;" \
		+ "return p && p.id===%s && (p.version||0)===%d ? (p.done ? 2 : 1) : 0})()" % [
			JSON.stringify(id), version]
	var state: Variant = JavaScriptBridge.eval(asked, true)
	while state != null and int(state) == 1:
		await get_tree().process_frame
		state = JavaScriptBridge.eval(asked, true)
	if state == null or int(state) != 2:
		return {}
	var status: int = int(JavaScriptBridge.eval("window.brickworksSharePrefetch.status", true))
	var text: Variant = JavaScriptBridge.eval("window.brickworksSharePrefetch.text", true)
	JavaScriptBridge.eval("window.brickworksSharePrefetch = null", true)
	if status == 0 or not (text is String):
		return {}
	var json := JSON.new()
	return {"code": status, "body": json.data if json.parse(text) == OK else null}


func publish(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/share", HTTPClient.METHOD_POST, token, JSON.stringify(body))


func unpublish(token: String, id: String) -> Dictionary:
	return await _fetch("/api/share?op=unpublish&id=" + id.uri_encode(),
		HTTPClient.METHOD_POST, token, "{}")


## The account's own links: {code, body: {shared: [...]}}.
func mine(token: String) -> Dictionary:
	return await _fetch("/api/share?op=mine", HTTPClient.METHOD_GET, token, "")


## The comments on a link (api/people.js ?op=comments, 2026-10-18), as the
## step player and the viewer show them on each step: {code, body: {model,
## version, newest, open, comments: [...], you}}. [param version] is the
## version open (0, the newest), which says which step each comment shows
## on; [param token] says who is asking, so the answer says whether they
## may write, and if not, why. Anybody may read them.
func comments(id: String, version: int = 0, token: String = "") -> Dictionary:
	return await _fetch("/api/people?op=comments&id=" + id.uri_encode()
		+ ("&v=%d" % version if version > 0 else ""), HTTPClient.METHOD_GET, token, "")


## Add a comment, as the session's account: {model, version, step (null for
## the whole model), body}. 201 with {comment}; a refusal says why in
## {error}.
func comment(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/people?op=comment", HTTPClient.METHOD_POST, token, JSON.stringify(body))


## One request on a throwaway node, as Account._fetch does: an
## HTTPRequest takes one call at a time.
func _fetch(path: String, method: int, token: String, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	# A model and its picture, up to about 3 MB, on a slow line.
	http.timeout = 90.0
	add_child(http)
	var headers := PackedStringArray(["content-type: application/json"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	if http.request(Deployment.api_base() + path, headers, method, body) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


## What a failed answer says, in words for a person.
static func trouble(answer: Dictionary, fallback: String) -> String:
	var body: Variant = answer.get("body")
	if body is Dictionary and str((body as Dictionary).get("error", "")) != "":
		return str((body as Dictionary)["error"])
	if int(answer.get("code", 0)) == 0:
		return "Could not reach Brickworks. Check the connection and try again."
	return fallback
