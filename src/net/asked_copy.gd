## Open in Brickworks' link (/app?copy=<id>), kept only in the browser
## across the way in, so the model asked for is what the studio shows from
## its first frame to the copy made, and is copied once (firstminute,
## 2026-11-23; Main._open_asked and Main._maybe_copy).
##
## Two marks, neither of them sent anywhere:
##   - this tab's (sessionStorage "brickworks.asked"): the link whose model
##     it opened behind the sign-in screen and has not made the person's yet.
##     A reload in the middle of signing in brings that model back as the
##     tab's working model, known for it by this mark and the link it says
##     it came from (ModelStore.remixed_from), never kept as work of the
##     person's own and copied a second time.
##   - the device's (localStorage "brickworks.copied"): each link copied in
##     the last [constant FRESH_S] seconds, by whom, and the name the copy was
##     saved under. The same link opened again in this tab or a second one
##     (pressed twice, the page reloaded with the address as it was) opens
##     that copy rather than making another.
## The address itself carries the link through the site's sign-in
## (/profile?then=/app?copy=…, which web/profile.js follows only to the
## app's own address). Off the web (a probe, the desktop) both are kept in
## memory for the run.
class_name AskedCopy
extends RefCounted

const SHOWN_KEY := "brickworks.asked"
const MADE_KEY := "brickworks.copied"
## How long a copy made is the one the same link opens again: a second tab,
## or a press of the button again by somebody who meant the first. Past
## that, the link makes a fresh copy, as asked.
const FRESH_S := 1800
## The most links the device's mark keeps.
const KEPT := 30

static var _shown: String = ""
static var _made: Dictionary = {}


## This tab opened [param id]'s model behind the sign-in screen.
static func mark_shown(id: String) -> void:
	_shown = id
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{sessionStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(SHOWN_KEY), JSON.stringify(id)], true)


## Whether this tab opened [param id]'s model and has not made it theirs.
static func shown_here(id: String) -> bool:
	if OS.has_feature("web"):
		var kept: Variant = JavaScriptBridge.eval(
			"(function(){try{return sessionStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(SHOWN_KEY), true)
		return not id.is_empty() and str(kept) == id
	return not id.is_empty() and _shown == id


## The name [param person]'s copy of [param id] was saved under in the last
## FRESH_S seconds on this device, or "".
static func made(id: String, person: String) -> String:
	var copied: Dictionary = _read_made()
	var theirs: Variant = copied.get(person, {})
	if not theirs is Dictionary or not (theirs as Dictionary).has(id):
		return ""
	var one: Variant = (theirs as Dictionary)[id]
	if not one is Array or (one as Array).size() < 2:
		return ""
	if Time.get_unix_time_from_system() - float((one as Array)[1]) > FRESH_S:
		return ""
	return str((one as Array)[0])


## [param person]'s copy of [param id] is saved, as [param name]: this tab's
## mark goes, and the device's says so.
static func mark_made(id: String, person: String, name: String) -> void:
	_shown = ""
	var copied: Dictionary = _read_made()
	var theirs: Dictionary = copied.get(person, {}) if copied.get(person) is Dictionary else {}
	theirs[id] = [name, int(Time.get_unix_time_from_system())]
	# The newest KEPT, and none past FRESH_S.
	var now: float = Time.get_unix_time_from_system()
	var fresh: Dictionary = {}
	for key: Variant in theirs:
		var one: Variant = theirs[key]
		if one is Array and (one as Array).size() >= 2 and now - float((one as Array)[1]) <= FRESH_S:
			fresh[key] = one
	while fresh.size() > KEPT:
		fresh.erase(fresh.keys()[0])
	copied[person] = fresh
	if not OS.has_feature("web"):
		_made = copied
		return
	JavaScriptBridge.eval(("(function(){try{sessionStorage.removeItem(%s);"
		+ "localStorage.setItem(%s,%s)}catch(e){}})()") % [JSON.stringify(SHOWN_KEY),
		JSON.stringify(MADE_KEY), JSON.stringify(JSON.stringify(copied))], true)


static func _read_made() -> Dictionary:
	if not OS.has_feature("web"):
		return _made.duplicate(true)
	var text: Variant = JavaScriptBridge.eval(
		"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
		% JSON.stringify(MADE_KEY), true)
	var json := JSON.new()
	if text == null or str(text).is_empty() or json.parse(str(text)) != OK or not json.data is Dictionary:
		return {}
	return json.data


## Forgotten, for a probe that walks the way in more than once in a run.
static func forget() -> void:
	_shown = ""
	_made = {}
