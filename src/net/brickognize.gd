## What part a photo shows, asked of Brickognize.
##
## "What is this piece?" is the question a builder has most often, with a
## part in one hand and no name for it. Brickognize (brickognize.com) is an
## image search for LEGO® parts with a public API: a photo posted to
## /predict/parts/ comes back as its best guesses, each a BrickLink number
## and how sure it is. The parts bin maps those to its own parts
## (PartLibrary.by_shop) and shows them as its results.
##
## Brickognize is a third party, and a photo sent there is theirs to keep:
## their terms of service (brickognize.com/terms-of-service, read
## 2026-10-24) give them a perpetual licence to store, publish and train
## models on what is uploaded, and govern only their own site's use; the
## API asks for no key, and answers any origin (Access-Control-Allow-Origin
## *), so a browser asks it directly and no server of ours sees the photo.
## So the bin says so before the first photo, and nothing is sent but a
## photo the person chose (PartsBin._ask_photo).
##
## The endpoint is the one their API documents for parts (openapi.json,
## "search (legacy)"). Their own site has moved to another, internal one;
## should this one go, the failure is said plainly, as any other is.
class_name Brickognize
extends Node

const URL := "https://api.brickognize.com/predict/parts/"
## The longest side a photo is sent at. A phone's twelve megapixels are four
## megabytes to upload for an answer a thousand pixels gives as well.
const LONGEST := 1024
## How many guesses are asked for, and the least sure one kept.
const MOST := 10
const LEAST := 0.3
## How long an answer is waited for, in seconds.
const WAIT := 30.0

## Where photos go: a probe points it at a stub of its own.
var url: String = URL

## The guesses, best first: each {bricklink, name, score}, score 0 to 1.
## Empty when Brickognize saw no part it knows.
signal answered(guesses: Array)
## Why there is no answer, in words for the person.
signal failed(why: String)

var _http: HTTPRequest


## Ask what part [param photo] shows. Answered by [signal answered] or
## [signal failed], once; a second photo before the first is answered
## replaces it.
func identify(photo: Image) -> void:
	var sent: Image = photo.duplicate()
	var longest: int = maxi(sent.get_width(), sent.get_height())
	if longest > LONGEST:
		var scale: float = float(LONGEST) / longest
		sent.resize(maxi(1, roundi(sent.get_width() * scale)),
			maxi(1, roundi(sent.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	if sent.detect_alpha() != Image.ALPHA_NONE or sent.get_format() != Image.FORMAT_RGB8:
		sent.convert(Image.FORMAT_RGB8)
	var boundary: String = "brickworks%d" % Time.get_ticks_usec()
	var body := PackedByteArray()
	body.append_array(("--" + boundary + "\r\nContent-Disposition: form-data; "
		+ "name=\"query_image\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
		.to_utf8_buffer())
	body.append_array(sent.save_jpg_to_buffer(0.88))
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = WAIT
		_http.request_completed.connect(_on_answer)
		add_child(_http)
	else:
		_http.cancel_request()
	var asked: int = _http.request_raw("%s?top_k_items=%d&min_similarity_items=%s"
		% [url, MOST, LEAST], ["Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST, body)
	if asked != OK:
		failed.emit(OFFLINE)


const OFFLINE := "Could not reach Brickognize: is this device online?"


func _on_answer(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	var why: String = trouble(result, code)
	if not why.is_empty():
		failed.emit(why)
		return
	var guesses: Variant = guesses_in(body.get_string_from_utf8())
	if guesses == null:
		failed.emit("Brickognize answered with something that is not an answer: try again later")
		return
	answered.emit(guesses)


## What went wrong with a request, in words, or "" when nothing did.
static func trouble(result: int, code: int) -> String:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "Brickognize did not answer in %d seconds: try again later" % int(WAIT)
	# A browser's failed fetch comes back as no reply at all, code 0.
	if result != HTTPRequest.RESULT_SUCCESS or code == 0:
		return OFFLINE
	if code == 429:
		return "Brickognize has had too many photos from here: try again in a minute"
	if code >= 500:
		return "Brickognize is not answering just now (HTTP %d): try again later" % code
	if code != 200:
		return "Brickognize could not take that photo (HTTP %d)" % code
	return ""


## The guesses in an answer's text, best first, or null when it is not one.
## Each has the BrickLink number its BrickLink link names, which is
## Brickognize's own id where there is none.
static func guesses_in(text: String) -> Variant:
	# Read quietly: an answer that is not JSON (a gateway's error page) is
	# said to the person, not printed as an error of the app's.
	var reading := JSON.new()
	if reading.parse(text) != OK:
		return null
	var answer: Variant = reading.data
	if not answer is Dictionary or not (answer as Dictionary).get("items") is Array:
		return null
	var out: Array = []
	for raw: Variant in answer["items"]:
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		if str(item.get("type", "part")) != "part":
			continue
		var number: String = str(item.get("id", ""))
		for site: Variant in item.get("external_sites", []):
			if site is Dictionary and str((site as Dictionary).get("name", "")) == "bricklink":
				var link: String = str((site as Dictionary).get("url", ""))
				if link.contains("P="):
					number = link.get_slice("P=", 1).get_slice("&", 0).uri_decode()
		if number.is_empty():
			continue
		out.append({"bricklink": number, "name": str(item.get("name", "")),
			"score": clampf(float(item.get("score", 0.0)), 0.0, 1.0)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	return out
