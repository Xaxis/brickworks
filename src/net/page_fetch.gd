## A request as the page itself makes it, in a browser.
class_name PageFetch
extends RefCounted

## The most asks [method asked] keeps for the page.
const KEPT_ASKS := 200


## When a send was asked (unix ms), kept for the page in
## window.brickworksAsked: tools/web/framefetch_flow.mjs reads it beside the
## server's own time of arrival, and the difference is how long a send
## waited before it left.
static func asked(url: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(("(() => { const a = window.brickworksAsked = window.brickworksAsked || [];"
		+ " a.push(%s); if (a.length > %d) a.shift(); })()") % [JSON.stringify({"url": url,
		"at": int(Time.get_unix_time_from_system() * 1000.0)}), KEPT_ASKS], true)
