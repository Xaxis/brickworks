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
func fetch(id: String) -> Dictionary:
	return await _fetch("/api/share?id=" + id.uri_encode(), HTTPClient.METHOD_GET, "", "")


## Publish {name, author?, model, image?, id?} as the session's account.
func publish(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/share", HTTPClient.METHOD_POST, token, JSON.stringify(body))


func unpublish(token: String, id: String) -> Dictionary:
	return await _fetch("/api/share?op=unpublish&id=" + id.uri_encode(),
		HTTPClient.METHOD_POST, token, "{}")


## The account's own links: {code, body: {shared: [...]}}.
func mine(token: String) -> Dictionary:
	return await _fetch("/api/share?op=mine", HTTPClient.METHOD_GET, token, "")


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
