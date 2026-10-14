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
## Always kept off the web, where the models are files on the computer.
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


## Whether this browser may clear the models: it was asked and would not
## agree, or it cannot be asked, or it is Safari, which deletes after seven
## days without a visit whatever it agreed to.
static func at_risk() -> bool:
	var now: Dictionary = state()
	if not bool(now["web"]):
		return false
	if bool(now["safari"]):
		return true
	return bool(now["answered"]) and not bool(now["kept"])


## The one quiet line the Account panel shows about where the models are.
static func words() -> String:
	var now: Dictionary = state()
	if not bool(now["web"]):
		return ("Your models are kept on this computer, not with your account — export one as "
			+ "LDraw to take it elsewhere.")
	if bool(now["safari"]):
		return ("Your models are kept on this device, in this browser, and may be cleared by the "
			+ "browser: Safari deletes a site's data after seven days without a visit. Your "
			+ "account keeps no copy, so download yours (File, Export, All my models).")
	if bool(now["kept"]):
		return ("Your models are kept on this device: this browser has agreed not to clear them. "
			+ "Your account keeps no copy — File, Export, All my models downloads them.")
	if bool(now["answered"]):
		return ("Your models are kept on this device, and may be cleared by the browser when it "
			+ "runs short of space: it would not agree to keep them. Your account keeps no copy, "
			+ "so download yours (File, Export, All my models).")
	return ("Your models are kept on this device, in this browser, not with your account — "
		+ "File, Export, All my models downloads them.")


## The warning, once (StorageOffer): what to say, or "" when there is
## nothing to warn of.
static func warning() -> String:
	if not at_risk():
		return ""
	var why: String = ("Safari deletes a site's data after seven days without a visit"
		if bool(state()["safari"])
		else "it would not agree to keep them, so it may clear them when it runs short of space")
	return ("Your models are kept only in this browser, and %s. " % why
		+ "Your account keeps no copy. Download your models to keep a copy of your own.")


## Be told what the page would say, for a probe: {asked, answered, kept,
## safari}, web assumed. Empty is the real page again.
static func pretend(said: Dictionary) -> void:
	_pretended = {}
	_asked = false
	if said.is_empty():
		return
	_pretended = {"web": true, "asked": false, "answered": false, "kept": false, "safari": false}
	_pretended.merge(said, true)
