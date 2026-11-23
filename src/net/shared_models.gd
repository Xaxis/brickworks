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
const PhotoUpload := preload("res://src/net/photo_upload.gd")


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
## Each licence by id: its name, and what it lets a session do with what it
## learns, said to it (GalleryTool). Here, so that a copy's credit does not
## load the gallery's tool (Later).
const LICENCES: Dictionary = {
	"cc-by-4.0": ["CC BY 4.0", "anyone may share it, change it and build on it, crediting %s and linking %s"],
	"cc-by-sa-4.0": ["CC BY-SA 4.0", "anyone may build on it, crediting %s and linking %s, and must share what they make under CC BY-SA 4.0 too"],
	"all-rights-reserved": ["All rights reserved", "learn from how %s built it; do not copy it into a model you make or share without their leave (%s)"],
	"cc-by-2.0": ["CC BY 2.0", "anyone may share it, change it and build on it, crediting %s and linking %s"],
}


static func credit_of(body: Dictionary, id: String) -> Dictionary:
	var licence: Variant = body.get("licence")
	var url: String = str(body.get("url", link_for(id)))
	return {"by": str(body["author"]) if body.get("author") is String else "",
		"licence": str(LICENCES[licence][0]) if licence is String
			and LICENCES.has(licence) else "no licence chosen",
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


## A change a remixer sent back to its designer (suggestedit, 2026-11-23;
## api/_suggestions.js): {code, body: {id, status, you, model: {id, name, n},
## remix, by, note, changes, counts, theirs, mine (its designer alone)}}.
func suggestion(token: String, id: int) -> Dictionary:
	return await _fetch("/api/share?op=suggestion&id=%d" % id, HTTPClient.METHOD_GET, token, "")


## Its designer's newest version [param n] with the changes [param take]
## ("all", or the ids ticked) taken in: {code, body: {text, taken, whole, n,
## model}}. Nothing is kept until that text is published.
func take_suggestion(token: String, id: int, n: int, take: Variant) -> Dictionary:
	return await _fetch("/api/share?op=suggestion_merge", HTTPClient.METHOD_POST, token,
		JSON.stringify({"id": id, "n": n, "take": take}))


## The kinds a sent change lists, as api/_suggest.js KINDS says them.
const SUGGEST_KINDS: Array[String] = ["added", "removed", "moved", "recoloured", "swapped",
	"restepped"]


## Who sent a change, by their profile's name, else their handle.
static func sender_of(got: Dictionary) -> String:
	var by: Dictionary = got.get("by") if got.get("by") is Dictionary else {}
	var who: String = str(by.get("name", "")).strip_edges()
	if who.is_empty() and not str(by.get("handle", "")).is_empty():
		who = "@" + str(by["handle"])
	return who if not who.is_empty() else "A remixer"


## "Ann's change from their remix “Red car, wider”".
static func suggestion_heading(got: Dictionary) -> String:
	var remix: Dictionary = got.get("remix") if got.get("remix") is Dictionary else {}
	return "%s's change from their remix “%s”" % [sender_of(got), str(remix.get("name", ""))]


## "3 added, 1 taken away, 2 moved", as the bell says it.
static func suggestion_counts(counts: Variant) -> String:
	var said := PackedStringArray()
	if counts is Dictionary:
		for kind: String in SUGGEST_KINDS:
			var n: int = int((counts as Dictionary).get(kind, 0))
			if n > 0:
				said.append(kind_count(kind, n))
	return ", ".join(said) if not said.is_empty() else "no change"


static func kind_count(kind: String, n: int) -> String:
	match kind:
		"added":
			return "%d added" % n
		"removed":
			return "%d taken away" % n
		"moved":
			return "%d moved" % n
		"recoloured":
			return "%d recoloured" % n
		"swapped":
			return "%d swapped" % n
	return "%d to another step" % n


## What a version taking [param taken] (ModelStore.suggestion) says it took:
## "Ann's change" whole, "part of Ann's change" else.
static func taken_words(taken: Dictionary) -> String:
	return ("%s's change" if bool(taken.get("whole", false)) else "Part of %s's change") % sender_of(taken)


## The note its version is published with: "With Ann's change from their
## remix “Red car, wider”: 3 added, 1 moved."
static func taken_note(taken: Dictionary) -> String:
	var remix: Dictionary = taken.get("remix") if taken.get("remix") is Dictionary else {}
	return ("With %s's change from their remix “%s”: %s." if bool(taken.get("whole", false))
		else "With part of %s's change from their remix “%s”: %s.") % [sender_of(taken),
		str(remix.get("name", "")), suggestion_counts(taken.get("taken", {}))]


## Declined by its designer: {code, body: {closed, status}}.
func decline_suggestion(token: String, id: int) -> Dictionary:
	return await _fetch("/api/share?op=suggestion_close", HTTPClient.METHOD_POST, token,
		JSON.stringify({"id": id, "status": "declined"}))


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


## Add a comment on a part (partpins, 2026-11-23), as the session's account:
## {model, version, step (or null), body, part: {part, colour, at}}, the part
## as the viewer picked it, at in LDraw's coordinates; the server finds it in
## that version's file and keeps its line. 201 with {comment} and its pin; a
## refusal says why in {error}.
func pin(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/people?op=pin", HTTPClient.METHOD_POST, token, JSON.stringify(body))


## The model's owner done with a comment on a part ([param resolved] true),
## or not: 200 with {comment}, its resolved_at said; a refusal says why in
## {error}.
func resolve_pin(token: String, id: int, resolved: bool) -> Dictionary:
	return await _fetch("/api/people?op=pin_resolve", HTTPClient.METHOD_POST, token,
		JSON.stringify({"id": id, "resolved": resolved}))


## A real build's photos (api/people.js, api/_builds.js), as the step
## player's last step posts one (MakeCard). The photos of [param id] as the
## account asking may act on them: {code, body: {owner, left, photos, mine}}
## ("owner": the model is the account's own; "left": how many more it may
## add, of three).
func photos(id: String, token: String) -> Dictionary:
	return await _fetch("/api/people?op=photos&id=" + id.uri_encode(), HTTPClient.METHOD_GET, token, "")


## Where to send one: {model, type, size} to {code, body: {upload, ticket,
## key}}, or a refusal in {error} (the age rule, may_act's limit, three on a
## model) before anything of the photo is sent.
func photo_start(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/people?op=photo_start", HTTPClient.METHOD_POST, token, JSON.stringify(body))


## The photo's [param bytes], of [param type], to the [param url] photo_start
## signed for them, with the storage gateway's [param key] beside it, as the
## model's page sends one (web/model-page.js): {code}. Bytes, which
## PageFetch's text bodies cannot carry, so src/net/photo_upload.gd sends them.
func photo_send(url: String, key: String, type: String, bytes: PackedByteArray) -> Dictionary:
	return await PhotoUpload.send(self, url, key, type, bytes)


## The photo sent, kept: {model, ticket, words?} to 201 {id, page, card, ...}
## (api/people.js photoSaid), or a refusal in {error}.
func photo_keep(token: String, body: Dictionary) -> Dictionary:
	return await _fetch("/api/people?op=photo", HTTPClient.METHOD_POST, token, JSON.stringify(body))


# -- this week's quick build -------------------------------------------------
#
# A weekly prompt (api/people.js ?op=prompt_of, 2026-11-23): a challenge with
# a model to start from, its template. Start on its page opens the studio on
# a copy of the template (/app?copy=<id>, Main._maybe_copy), and that copy,
# published during the week, enters it. The studio says the brief above the
# model (Main._ask_prompt), and Share asks whether to enter (SharePanel).

const MONTHS: Array[String] = ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]
## The most of a brief said above the model on a touch screen, where every
## line of it is a line less of the model's room.
const BRIEF_ON_A_PHONE := 120


# -- the month's challenge, in the studio ------------------------------------
#
# The challenge open now and its rules (api/people.js ?op=challenge_rules,
# 2026-11-23), ticked on the model as it is built (ChallengeLine), and a
# model entered from Share (?op=enter) or asked whether it is in
# (?op=challenge_entry). Read at the edge by ChallengeRules.rules_in and
# SharePanel, which this core never names.

## The month's challenge open now, as the server answers: {code, body}.
## With [param token], a test account's is the checks' own.
func challenge_rules(token: String) -> Dictionary:
	return await _fetch("/api/people?op=challenge_rules", HTTPClient.METHOD_GET, token, "")


## [param model] entered in the challenge open now, built [param way] (hand
## or assistant): {code, body}, body {entered, title, label} or {error,
## refused}.
func enter(token: String, model: String, way: String) -> Dictionary:
	return await _fetch("/api/people?op=enter", HTTPClient.METHOD_POST, token,
		JSON.stringify({"model": model, "way": way}))


## Whether [param model], the caller's, is in the challenge open now:
## {code, body}, body {mine, challenge, entry, keeps, broken}.
func challenge_entry(token: String, model: String) -> Dictionary:
	if not is_id(model):
		return {"code": 0, "body": null}
	return await _fetch("/api/people?op=challenge_entry&id=" + model.uri_encode(), HTTPClient.METHOD_GET, token, "")


## This week's quick build when [param template] is the model it starts
## from: {id, title, brief, starts_on, ends_on, template, page}, or {} when
## it is not the template of one open now. Anything else that comes back,
## another status, another shape or nothing at all, is no prompt either, and
## never said as a trouble: the copy is the person's model all the same.
## Anybody may ask, signed in or not.
func prompt_of(template: String) -> Dictionary:
	if not is_id(template):
		return {}
	var answer: Dictionary = await _fetch("/api/people?op=prompt_of&model=" + template.uri_encode(),
		HTTPClient.METHOD_GET, "", "")
	return prompt_in(answer, template)


## The prompt an answer of ?op=prompt_of names, read at the edge: a whole
## number id, a title, a day it ends that is a day, and the template asked
## about; {} for anything short of that, or one said to be closed.
static func prompt_in(answer: Dictionary, template: String) -> Dictionary:
	if int(answer.get("code", 0)) != 200 or not answer.get("body") is Dictionary:
		return {}
	var said: Variant = (answer["body"] as Dictionary).get("prompt")
	if not said is Dictionary:
		return {}
	var prompt: Dictionary = said
	var id: Variant = prompt.get("id")
	var title: String = str(prompt["title"]).strip_edges() if prompt.get("title") is String else ""
	var ends: String = str(prompt["ends_on"]) if prompt.get("ends_on") is String else ""
	if not (id is int or id is float) or int(id) <= 0 or title.is_empty() \
			or day_words(ends).is_empty() or prompt.get("open") == false \
			or prompt.get("template") is String and str(prompt["template"]) != template:
		return {}
	var page: String = str(prompt["page"]) if prompt.get("page") is String else ""
	return {"id": int(id), "title": title,
		"brief": str(prompt["brief"]).strip_edges() if prompt.get("brief") is String else "",
		"starts_on": str(prompt["starts_on"]) if prompt.get("starts_on") is String else "",
		"ends_on": ends, "template": template,
		"page": page if page.begins_with("https://") else ""}


## "2026-11-29" as "29 November", or "" for what is not a day.
static func day_words(iso: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("^\\d{4}-(\\d{2})-(\\d{2})$").search(iso)
	if found == null:
		return ""
	var month: int = found.get_string(1).to_int()
	var day: int = found.get_string(2).to_int()
	if month < 1 or month > 12 or day < 1 or day > 31:
		return ""
	return "%d %s" % [day, MONTHS[month - 1]]


## What the studio says of [param prompt] ([method prompt_in]): its title,
## its brief in quotes and the day to publish by. A brief longer than [param most]
## characters is cut, so the day it ends is always said: after its last
## whole sentence that fits, which keeps each sentence one a language finds
## (Language's ". "), else at a word, with an ellipsis.
static func prompt_line(prompt: Dictionary, most: int = -1) -> String:
	var title: String = str(prompt["title"])
	var brief: String = str(prompt.get("brief", "")).strip_edges()
	if most > 0 and brief.length() > most:
		var cut: String = brief.left(most + 1)
		var sentence: int = maxi(maxi(cut.rfind(". "), cut.rfind("! ")), cut.rfind("? "))
		var space: int = cut.rfind(" ")
		if sentence > most / 2:
			brief = cut.left(sentence + 1)
		else:
			brief = (cut.left(space) if space > most / 2 else cut.left(most)).rstrip(" ,;:.—-") + "…"
	var day: String = day_words(str(prompt["ends_on"]))
	if brief.is_empty():
		return "This week's quick build: %s. Publish it by %s to enter." % [title, day]
	if not brief.right(1) in [".", "!", "?", "…"]:
		brief += "."
	# The brief in quotes: the owner's words, drawn as written in every
	# language (Language keeps what an entry quotes), never half translated.
	return "This week's quick build, %s: “%s” Publish it by %s to enter." % [title, brief, day]


## The studio's first screen (api/people.js ?op=studio_start): what came
## back on the person's models and this week's quick build, nothing marked
## read: {code, body: {ready, came: [...], prompt}} (StudioStart).
## Its lines in [param lang], the interface's language (Language.current).
func studio_start(token: String, lang: String = "en") -> Dictionary:
	return await _fetch("/api/people?op=studio_start&lang=" + lang.uri_encode(), HTTPClient.METHOD_GET, token, "")


## A page of the gallery (api/share.js ?op=list), as the library's Community
## shelf asks it: [param words] searched for, or the gallery's own first
## page for none; with [param token], nobody they blocked in it. {code,
## body: {models: [...], more}}.
func gallery(words: String, token: String = "") -> Dictionary:
	var asked: String = "/api/share?op=list&page=1"
	if not words.strip_edges().is_empty():
		asked += "&q=" + words.strip_edges().left(100).uri_encode()
	if not token.is_empty():
		asked += "&mine=1"
	return await _fetch(asked, HTTPClient.METHOD_GET, token, "")


## One request, as Account._fetch makes it (PageFetch).
func _fetch(path: String, method: int, token: String, body: String) -> Dictionary:
	var headers := PackedStringArray(["content-type: application/json"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	# Off the web the app says what it is, so a build finished on a desktop
	# is told from a robot's request (api/share.js ?op=built). In a browser
	# the browser's own goes, and cannot be changed.
	if not OS.has_feature("web"):
		headers.append("User-Agent: Brickworks/%s (desktop)" % BuildInfo.version())
	# A model and its picture, up to about 3 MB, on a slow line.
	var result: Array = await PageFetch.ask(self, Deployment.api_base() + path, headers, method, body, 90.0)
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
