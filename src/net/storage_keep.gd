## Whether the browser will keep the person's models.
##
## On the web every model is in the site's storage in the browser (user://
## is IndexedDB), and nowhere else: the account keeps none
## (supabase/schema.sql). A browser may clear a site's storage when it runs
## short of space, unless the site asked to keep it with
## navigator.storage.persist() and was let; Safari deletes what a site's
## scripts stored after seven days without a visit (MDN, "Storage quotas
## and eviction criteria"). Until 2026-10-14 the app never asked.
##
## So it asks at the right moment, which is when there is something to keep:
## the first save, or a visit by somebody who has saved models (Main). The
## page asks the browser and keeps the answer (src/boot/shell.html,
## window.brickworksPersist); this is the app's side of it: the line the
## Account panel shows, and whether to warn, once, where the models may go
## (StorageOffer).
##
## Signed in, the account keeps a copy of each too (CloudModels, from
## 2026-10-23): while it has them all, Account says so and nothing is
## warned, since a browser clearing them loses nothing.
##
## Always kept off the web, where the models are files on the computer, and
## signed in, kept with the account too (lib219, 2026-10-24).
##
## Each line is true in every way the models stand with the account
## (CloudModels.standing): signed out, kept with it, full, refused, offline,
## not reached, or a deployment that keeps none. Signed in with the account
## full, the warning said "Your account keeps no copy" of an account that
## had all but the two it had no room for (tidy232).
class_name StorageKeep
extends RefCounted

## What the page said, played for a probe ([method pretend]); empty when not.
static var _pretended: Dictionary = {}
static var _asked: bool = false
## The page's last answer and when it was read: the page is told the state
## twice a second (Main._tell_page), and once is enough for both.
static var _read: Dictionary = {}
static var _read_at: int = -1000000


## Ask the browser to keep this site's storage, once a page, on the web.
## Chromium answers from how the site has been used, without asking the
## person; Firefox asks them; Safari answers too, and deletes after seven
## days without a visit either way.
static func ask() -> void:
	if _asked:
		return
	_asked = true
	if not _pretended.is_empty():
		_pretended["asked"] = true
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.brickworksPersist && window.brickworksPersist()", true)


## What the browser has said: {web, asked, answered, kept, safari}. kept is
## whether it agreed to keep the storage; answered whether it has said.
static func state() -> Dictionary:
	if not _pretended.is_empty():
		return _pretended
	if not OS.has_feature("web"):
		return {"web": false, "asked": false, "answered": true, "kept": true, "safari": false}
	if Time.get_ticks_msec() - _read_at < 400:
		return _read
	_read_at = Time.get_ticks_msec()
	var said: Variant = JavaScriptBridge.eval(
		"window.brickworksStorage ? window.brickworksStorage() : ''", true)
	var parsed: Variant = JSON.parse_string(str(said)) if said != null and str(said) != "" else null
	var page: Dictionary = parsed if parsed is Dictionary else {}
	_read = {"web": true, "asked": bool(page.get("asked", false)),
		"answered": bool(page.get("answered", false)) or page.get("persisted") == true,
		"kept": page.get("persisted") == true, "safari": bool(page.get("safari", false))}
	return _read


## Whether this browser may clear models the account does not have: it was
## asked and would not agree, or it cannot be asked, or it is Safari, which
## deletes after seven days without a visit whatever it agreed to.
static func at_risk() -> bool:
	var now: Dictionary = state()
	if not bool(now["web"]) or _account() == "kept":
		return false
	if bool(now["safari"]):
		return true
	return bool(now["answered"]) and not bool(now["kept"])


## The one quiet line the Account panel shows about where the models are:
## where this browser or computer keeps them, then what the account has.
static func words() -> String:
	var now: Dictionary = state()
	var web: bool = bool(now["web"])
	var standing: String = _account()
	if standing == "kept":
		return ("Your models are kept with your account, and %s: they are in " % ("in this browser"
			if web else "on this computer") + "File › Open in any browser or desktop app you "
			+ "sign in to.")
	var here: String = "Your models are kept on this computer."
	if web and bool(now["safari"]):
		here = ("Your models are kept on this device, in this browser, and may be cleared by the "
			+ "browser: Safari deletes a site's data after seven days without a visit.")
	elif web and bool(now["kept"]):
		here = "Your models are kept on this device: this browser has agreed not to clear them."
	elif web and bool(now["answered"]):
		here = ("Your models are kept on this device, and may be cleared by the browser when it "
			+ "runs short of space: it would not agree to keep them.")
	elif web:
		here = "Your models are kept on this device, in this browser."
	var mine: String = "download yours (File, Export, All my models)" if web \
		else "export one as LDraw to take it elsewhere"
	var account: String
	match standing:
		"none":
			account = "Your account keeps no copy, so %s." % mine
		"full":
			account = ("Your account is full: %s kept only here, the rest with your account too. "
				% _left_out() + "Delete models you no longer need to make room, or %s." % mine)
		"refused":
			account = ("Your account would not take %s: those are kept only here, the rest with "
				% _left_out(false) + "your account too.")
		"offline":
			account = "You are offline: a model saved now goes to your account when you are back online."
		"looking", "away":
			account = ("Your account has not been reached yet: a model it does not have goes to it "
				+ "when it is.")
		_:
			account = ("Your account keeps no copy of a model saved while you are signed out: sign "
				+ "in and it is kept there too, or %s." % mine)
	return "%s %s" % [here, account]


## The warning, once (StorageOffer): what to say, or "" when there is
## nothing to warn of.
static func warning() -> String:
	if not at_risk():
		return ""
	var why: String = ("Safari deletes a site's data after seven days without a visit"
		if bool(state()["safari"])
		else "it would not agree to keep them, so it may clear them when it runs short of space")
	var mine: String = "Download your models to keep a copy of your own"
	match _account():
		"none":
			return ("Your models are kept only in this browser, and %s. " % why
				+ "Your account keeps no copy. %s." % mine)
		"full":
			return ("Your account is full, so %s kept only in this browser, and %s. " % [_left_out(),
				why] + "%s, or delete those you no longer need to make room." % mine)
		"refused":
			return ("Your account would not take %s, so those are kept only in this browser, and "
				% _left_out(false) + "%s. %s." % [why, mine])
		"offline":
			return ("You are offline, so a model saved now is kept only in this browser until you "
				+ "are back online, and %s. %s." % [why, mine])
		"looking", "away":
			return ("Your account has not been reached yet, so a model it does not have is kept "
				+ "only in this browser until it is, and %s. %s." % [why, mine])
	return ("Your models are kept in this browser, and %s. Your account keeps no copy of a "
		% why + "model saved while you are signed out. %s, or sign in and they are kept with "
		% mine + "your account too.")


## How the models stand with the account (CloudModels.standing), or what a
## probe pretends ("account", signed out when it says none).
static func _account() -> String:
	return str(_pretended.get("account", "out")) if not _pretended.is_empty() \
		else CloudModels.standing


## The models the account would not take, counted: "2 of your models are",
## or without [param verb] "2 of your models".
static func _left_out(verb: bool = true) -> String:
	var many: int = int(_pretended.get("left_out", 0)) if not _pretended.is_empty() \
		else CloudModels.left_out
	return ("%d of your models%s" % [many, (" is" if many == 1 else " are") if verb else ""]) \
		if many > 0 else ("some of your models%s" % (" are" if verb else ""))


## Be told what the page would say, for a probe: {asked, answered, kept,
## safari}, web assumed unless "web": false; and how the models stand with
## the account ({account, left_out}, CloudModels.standing), signed out
## unless said. Empty is the real page again.
static func pretend(said: Dictionary) -> void:
	_pretended = {}
	_asked = false
	if said.is_empty():
		return
	_pretended = {"web": true, "asked": false, "answered": false, "kept": false, "safari": false}
	_pretended.merge(said, true)
