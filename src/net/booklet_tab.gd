## The browser tab a booklet is drawn into (BookletOut), opened as
## Instructions is pressed.
##
## Apart from BookletMaker, which the first screen reaches through Later:
## the tab is opened inside the press, and asking BookletMaker to open it
## compiled the maker there first: 180 ms of a browser's own work before
## the press's bar was drawn (a preview at load 6, bookletbar, 2026-11-02).
class_name BookletTab
extends RefCounted


## In a browser: open the tab the booklet will be shown in, now, while
## the click that asked for it still counts as a click. A page may only
## open a window in answer to one, and the pictures take seconds.
static func open() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.brickworksBooklet = window.open('', '_blank');
		if (window.brickworksBooklet) {
			window.brickworksBooklet.document.write(
				'<title>Building instructions</title>' +
				'<p style="font:16px system-ui,sans-serif;margin:40px">' +
				'Drawing your building instructions&hellip;</p>' +
				'<p id="working" style="font:14px system-ui,sans-serif;margin:0 40px;color:#555"></p>');
		}
	""", true)


## Say in the tab opened for the booklet how it is going: that tab is in
## front while the booklet is drawn, and it said only "Drawing your
## building instructions…" for as long as that took.
static func tell(line: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(() => {
			const tab = window.brickworksBooklet;
			const said = tab && !tab.closed && tab.document.getElementById('working');
			if (said) said.textContent = %s;
		})();
	""" % JSON.stringify(line), true)


## Whether the tab opened for the booklet is there, in a browser.
static func is_open() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
		"!!(window.brickworksBooklet && !window.brickworksBooklet.closed)", true))


## Close the tab opened for a booklet that was stopped or came to nothing.
static func close() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		if (window.brickworksBooklet && !window.brickworksBooklet.closed) window.brickworksBooklet.close();
		window.brickworksBooklet = null;
	""", true)
