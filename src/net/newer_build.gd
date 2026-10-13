## Whether a newer build of Brickworks is live than the one this tab runs.
##
## People keep a tab open for hours, and after a deploy an open tab goes on
## running the build it loaded. The page asks the site which build is live
## now and then (src/boot/shell.html, /version.json), and from the moment
## it is not this tab's the page stores nothing outside this tab's own
## session: the newer build owns what the tabs share. This is the app's
## side of that: the banner that offers to reload (UpdateOffer), a save
## that would go to the shared models refused with why rather than made in
## memory and never stored ([method may_write]), and Claude told once over
## the connector (CommandSocket).
##
## Always nothing off the web, where a window runs the build it was
## installed as.
class_name NewerBuild
extends RefCounted

## What a save the tab may not make says.
const REFUSAL := ("Brickworks has been updated: reload this tab (Reload, above the model) "
	+ "and save then. The model comes back as it is.")

static var _live: String = ""


## The build live now when it is not this tab's, or "" (asked of the page
## until there is one; from then on it stays).
static func live() -> String:
	if _live.is_empty() and OS.has_feature("web"):
		var said: Variant = JavaScriptBridge.eval(
			"window.brickworksNewer ? window.brickworksNewer() : ''", true)
		_live = str(said) if said != null else ""
	return _live


## Be told [param commit] is live, as the page would say it: for a probe.
static func pretend(commit: String) -> void:
	_live = commit


## Whether [param path] may be written now: anything until a newer build is
## live, and from then on only this tab's own files (TabSession), which the
## reload brings back. The page holds the rest back anyway; refused here,
## the person is told rather than shown "saved" for a file never stored.
static func may_write(path: String) -> bool:
	return live().is_empty() or path.begins_with(TabSession.ROOT + TabSession.id() + "/")
