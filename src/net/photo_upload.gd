## A real build's photo sent as its bytes to the storage address
## api/people.js ?op=photo_start signed for it (makes, 2026-11-23), as the
## model's page sends one (web/model-page.js). PageFetch carries text bodies
## alone, so this is the one request of SharedModels' that is not PageFetch's,
## kept to a file of its own so tests/test_page_fetch.py still holds every
## other request of SharedModels to it (its KEPT list is by file).
extends RefCounted


## [param bytes], of [param type], PUT to [param url] with the storage
## gateway's [param key] beside it, from [param host]: {code}, 0 when it
## never reached the server.
static func send(host: Node, url: String, key: String, type: String, bytes: PackedByteArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 120.0
	host.add_child(http)
	var headers := PackedStringArray(["content-type: " + type, "x-upsert: false"])
	if not key.is_empty():
		headers.append("apikey: " + key)
	if http.request_raw(url, headers, HTTPClient.METHOD_PUT, bytes) != OK:
		http.queue_free()
		return {"code": 0}
	var done: Array = await http.request_completed
	http.queue_free()
	return {"code": int(done[1]) if int(done[0]) == HTTPRequest.RESULT_SUCCESS else 0}
