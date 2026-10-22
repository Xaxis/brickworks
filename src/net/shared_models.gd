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


## Who made a shared model and on what terms, as a copy of it carries them
## (ModelStore.credit): its designer, its licence by name, and its link.
const GALLERY := "the Brickworks gallery"


static func credit_of(body: Dictionary, id: String) -> Dictionary:
	var licence: Variant = body.get("licence")
	var url: String = str(body.get("url", link_for(id)))
	return {"by": str(body["author"]) if body.get("author") is String else "",
		"licence": str(GalleryTool.LICENCES[licence][0]) if licence is String
			and GalleryTool.LICENCES.has(licence) else "no licence chosen",
		"page": url if url.begins_with("https://") else "", "from": GALLERY}


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


## The model at [param id] built to its last step on this device ([param
## device], device_key()), on [param version] of it: {code, body: {counted,
## builds}}. No account and nothing about the builder: the server keeps a
## key made from the link and the device's own random number, so the same
## device is counted once (api/share.js ?op=built). Off the web the app says
## it is the app, which is how the server tells it from a robot; in a
## browser the page's own request says it.
func built(id: String, device: String, version: int = 1) -> Dictionary:
	return await _fetch("/api/share?op=built&id=" + id.uri_encode(), HTTPClient.METHOD_POST, "",
		JSON.stringify({"device": device, "v": maxi(version, 1)}))


# -- builds finished, once per device ---------------------------------------
#
# A model built to its last step is counted once per device (api/share.js
# ?op=built): the device is a random number it made for itself, never tied
# to an account, and which links it has been counted for. In the browser
# both are in localStorage, beside the place kept per link (BuildSteps);
# off the web in one small file under user://, the one thing a desktop
# viewer keeps: without it, every run of the app would be a new device.

const DEVICE_KEY := "brickworks.device"
const BUILT_AS := "brickworks.built."
const DEVICE := "^[0-9a-f]{32}$"
## Where the desktop keeps them; a probe points it at a file of its own.
static var kept_at: String = "user://built_once.cfg"


## This device's own random number, 32 lowercase hex: made the first time
## it is asked for and kept. A value of the wrong shape is no value, and a
## new one is made.
static func device_key() -> String:
	var kept: String = ""
	if OS.has_feature("web"):
		var text: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(DEVICE_KEY), true)
		kept = str(text) if text is String else ""
	else:
		var file := ConfigFile.new()
		if file.load(kept_at) == OK:
			var value: Variant = file.get_value("device", "key", "")
			kept = value if value is String else ""
	if RegEx.create_from_string(DEVICE).search(kept) != null:
		return kept
	var made: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(DEVICE_KEY), JSON.stringify(made)], true)
	else:
		var file := ConfigFile.new()
		file.load(kept_at)
		file.set_value("device", "key", made)
		file.save(kept_at)
	return made


## Whether this device's finish of [param link] has been counted: then it
## is not sent again.
static func built_counted(link: String) -> bool:
	if OS.has_feature("web"):
		var text: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(BUILT_AS + link), true)
		return text is String and text == "1"
	var file := ConfigFile.new()
	if file.load(kept_at) != OK:
		return false
	var value: Variant = file.get_value("built", link, false)
	return value is bool and value


## Keep that this device's finish of [param link] was counted.
static func mark_built(link: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,'1')}catch(e){}})()"
			% JSON.stringify(BUILT_AS + link), true)
		return
	var file := ConfigFile.new()
	file.load(kept_at)
	file.set_value("built", link, true)
	file.save(kept_at)


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
	# Off the web the app says what it is, so a build finished on a desktop
	# is told from a robot's request (api/share.js ?op=built). In a browser
	# the browser's own goes, and cannot be changed.
	if not OS.has_feature("web"):
		headers.append("User-Agent: Brickworks/%s (desktop)" % BuildInfo.version())
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
