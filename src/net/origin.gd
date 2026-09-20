## Where "here" is, as an absolute URL.
##
## Godot's [HTTPRequest] will not take a relative URL — it reports
## "Error parsing URL: '/api/account'" and refuses to send. That is easy
## to miss, because on the desktop every URL is absolute anyway and on
## the web the failure is silent in the only place it happens: a part
## that will not load looks exactly like a part this build does not
## carry.
##
## It bit twice. The account probe never left the browser, so the web
## build reported that it had no accounts; and the on-demand part fetch
## never left either, so the web build could only ever place the few
## hundred parts it shipped with while the catalogue listed thousands
## more as available.
##
## The base also has to be the deployment root rather than the page's
## own directory. The build is served from /b/<sha>/ so that it can be
## cached forever, but the parts are served from /parts/ so they survive
## a deploy — a URL resolved against the page would look for them inside
## the build and find nothing.
class_name Origin
extends RefCounted


## "https://brickworks.diy" in the browser, empty on the desktop, where
## the caller supplies a host of its own.
static func here() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval("location.origin", true)
	if value == null:
		return ""
	return str(value).rstrip("/")
