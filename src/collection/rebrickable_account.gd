## A person's sets and parts lists, read from their own Rebrickable account.
##
## With their own API key (rebrickable.com, Settings, API) and their user
## token — or, once, their Rebrickable username and password, which
## Rebrickable trades for a token (POST /users/_token/). Everything here
## goes from this app straight to rebrickable.com, whose API answers any
## page (Access-Control-Allow-Origin: *); none of it is sent to Brickworks
## and none of it is kept. What comes back is handed to api/collection.js
## as "rebrickable_api", in Rebrickable's own numbers, to be mapped there
## with every other import.
##
## Read: /users/{token}/sets/ (the sets in their set lists) and
## /users/{token}/parts/ (the loose parts in their part lists), a page of
## a thousand at a time. Not /allparts/, which Rebrickable asks callers not
## to overuse and which would count every set's parts a second time here,
## where sets are expanded from the downloaded inventories.
##
## Rebrickable allows about one request a second and bans a caller that
## keeps going after a 429, so pages are paced and a 429 stops the read.
class_name RebrickableAccount
extends Node

const API := "https://rebrickable.com/api/v3"
const PAGE := 1000
## Seconds between requests: under Rebrickable's one a second.
const PACE := 1.1
## Most pages of each list read: 50,000 rows, past any real collection.
const MOST_PAGES := 50

## Where the API is; a probe points it at a stand-in.
var api: String = API
var pace: float = PACE


## {"sets": [[set_num, qty, include_spares]], "parts": [[part_num, colour id,
## qty]], "error": ""}. Give [param token], or [param username] and
## [param password] to get one.
func read(key: String, token: String, username: String = "", password: String = "") -> Dictionary:
	var out: Dictionary = {"sets": [], "parts": [], "error": ""}
	key = key.strip_edges()
	token = token.strip_edges()
	if key.is_empty():
		out["error"] = "paste your Rebrickable API key first (rebrickable.com, Settings, API)"
		return out
	if token.is_empty():
		if username.strip_edges().is_empty() or password.is_empty():
			out["error"] = "give your user token, or your Rebrickable username and password"
			return out
		var got: Dictionary = await _call("/users/_token/", key, HTTPClient.METHOD_POST,
			"username=%s&password=%s" % [username.strip_edges().uri_encode(), password.uri_encode()])
		if not (int(got["code"]) in [200, 201]) or typeof(got["body"]) != TYPE_DICTIONARY:
			out["error"] = _why(got, "Rebrickable would not sign in with that username and password")
			return out
		token = str((got["body"] as Dictionary).get("user_token", ""))
		if token.is_empty():
			out["error"] = "Rebrickable gave no user token"
			return out
	var sets: Dictionary = await _pages("/users/%s/sets/" % token.uri_encode(), key)
	if not str(sets["error"]).is_empty():
		out["error"] = sets["error"]
		return out
	for row: Variant in sets["rows"]:
		var entry: Dictionary = row
		var set_of: Variant = entry.get("set", {})
		var number: String = str((set_of as Dictionary).get("set_num", "")) \
			if typeof(set_of) == TYPE_DICTIONARY else str(entry.get("set_num", ""))
		if not number.is_empty():
			(out["sets"] as Array).append([number, maxi(1, int(entry.get("quantity", 1))),
				bool(entry.get("include_spares", false))])
	var parts: Dictionary = await _pages("/users/%s/parts/" % token.uri_encode(), key)
	if not str(parts["error"]).is_empty():
		out["error"] = parts["error"]
		return out
	for row: Variant in parts["rows"]:
		var entry: Dictionary = row
		var part_of: Variant = entry.get("part", {})
		var colour_of: Variant = entry.get("color", {})
		var part: String = str((part_of as Dictionary).get("part_num", "")) \
			if typeof(part_of) == TYPE_DICTIONARY else str(entry.get("part_num", ""))
		var colour: int = int((colour_of as Dictionary).get("id", -1)) \
			if typeof(colour_of) == TYPE_DICTIONARY else int(entry.get("color_id", -1))
		if not part.is_empty():
			(out["parts"] as Array).append([part, colour, maxi(1, int(entry.get("quantity", 1)))])
	return out


func _pages(path: String, key: String) -> Dictionary:
	var rows: Array = []
	var url: String = "%s%s?page_size=%d" % [api, path, PAGE]
	for page: int in MOST_PAGES:
		if page > 0:
			await get_tree().create_timer(pace).timeout
		var got: Dictionary = await _call(url, key, HTTPClient.METHOD_GET, "")
		if int(got["code"]) != 200 or typeof(got["body"]) != TYPE_DICTIONARY:
			return {"rows": rows, "error": _why(got, "Rebrickable did not answer")}
		var body: Dictionary = got["body"]
		rows.append_array(body.get("results", []))
		var next: Variant = body.get("next")
		if next == null or str(next).is_empty():
			return {"rows": rows, "error": ""}
		url = str(next)
	return {"rows": rows, "error": ""}


static func _why(got: Dictionary, otherwise: String) -> String:
	match int(got["code"]):
		0:
			return "could not reach rebrickable.com"
		401, 403:
			return "Rebrickable refused that key or token"
		404:
			return "Rebrickable does not know that user token"
		429:
			return "Rebrickable asks us to slow down — try again in a minute"
	var body: Variant = got["body"]
	if typeof(body) == TYPE_DICTIONARY and (body as Dictionary).has("detail"):
		return "Rebrickable: %s" % str(body["detail"])
	return "%s (%d)" % [otherwise, int(got["code"])]


func _call(path_or_url: String, key: String, method: int, form: String) -> Dictionary:
	var url: String = path_or_url if path_or_url.begins_with("http") else api + path_or_url
	var headers := PackedStringArray(["Authorization: key " + key, "Accept: application/json"])
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/x-www-form-urlencoded")
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	if http.request(url, headers, method, form) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}
