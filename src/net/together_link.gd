## A Build together link, read without the session itself (Together, which
## Later loads the first time a session is joined or Build together… is
## opened): the secret in a page's address or a pasted link, and the session
## this tab was in before a reload, which every start asks after
## (Main._maybe_join_together).
class_name TogetherLink
extends RefCounted

## Where the session this tab is in is kept with the tab (TabSession.path),
## so a reload or a restart goes back into it by itself.
const KEPT_FILE := "together.txt"


## The secret from a Build together link (…/app?together=SECRET), or the
## secret itself; "" when it is neither.
static func secret_in(address: String) -> String:
	var said: String = address.strip_edges()
	var at: int = said.find("together=")
	if at >= 0:
		said = said.substr(at + 9)
		for stop: String in ["&", "#", " "]:
			if said.find(stop) >= 0:
				said = said.substr(0, said.find(stop))
	return said if RegEx.create_from_string("^[A-Za-z0-9_-]{32}$").search(said) != null else ""


## Where a browser keeps this tab's changes on their way: by its session's
## id, which the next page to take the session up reads.
static func page_key() -> String:
	return "brickworks.together_pending." + TabSession.id()


## What a browser kept of this tab's changes on their way, or "".
static func page_kept() -> String:
	var got: Variant = JavaScriptBridge.eval(("(() => { const key = %s; try { return localStorage.getItem(key)"
		+ " || sessionStorage.getItem(key) || ''; } catch (e) { return ''; } })()") % JSON.stringify(page_key()),
		true)
	return str(got) if got != null else ""


## The session this tab was in when it was reloaded or closed, or "".
static func kept_secret() -> String:
	var path: String = TabSession.path(KEPT_FILE)
	if FileAccess.file_exists(path):
		return secret_in(FileAccess.get_file_as_string(path))
	# A browser stores user:// on its own schedule, half a minute and more
	# on a loaded machine (ModelStore._tell_page_wrote): a tab closed sooner
	# has not this file, but its changes on their way, kept at once, name
	# the session too.
	if OS.has_feature("web"):
		var words: String = page_kept()
		var kept: Variant = JSON.parse_string(words) if not words.is_empty() else null
		if kept is Dictionary:
			return secret_in(str((kept as Dictionary).get("s", "")))
	return ""
