## A long job says when it is done (APP_UX7 #11, donenote).
##
## A design, a Best render, the render queue and a build video each take
## from a minute to many, and a person who looks away while one works kept
## coming back to see whether it had finished: Brickium says when its builds
## are done, and Brickworks said nothing. So when a job the person started
## ends while they are not looking:
## - on the desktop, the window asks for attention (the taskbar's flash, the
##   dock's bounce) and its title starts with "Done · " until it is looked
##   at again;
## - on the web, one notification with the model's name and what finished,
##   and the tab's title starts the same way (Main._tell_page): all a
##   browser that may not notify shows.
## Nothing happens while the window has the focus. Settings, "Say when a long
## job is done", turns it off, kept on this device (ShellPrefs "done_note").
##
## The browser asks whether the page may notify only when the person first
## starts a long job here, while the press that started it is fresh (a
## browser refuses or hides an ask no press made), and never on load.
##
## A job a session drives from outside (Claude over MCP or the connector) is
## told to that session, which says it in the chat: nothing here, and no ask.
## The render queue is the exception: a session adding to it is answered at
## once, and nobody would say when its pictures are drawn.
##
## Each job tells this its start and its end where the app already hears
## them (Main: the assistant's panel, Render's dialog, the render queue).
## Render's dialog has no signal for a render's end, and is round six's
## video2's to change, so whether it is drawing is asked each frame here
## ([method follow_render]).
class_name DoneNote
extends Node

## The setting, in ShellPrefs: on until somebody turns it off.
const SETTING := "done_note"
## How often, while a note waits to be seen, whether the person is back is
## asked, in ms.
const LOOK_MS := 500

## What finished, as the note says it, by the job: a design or a change
## asked for in the assistant's panel, its three sketches, and Render's
## picture at Best, turntable, animation and build video, and the queue.
const DONE: Dictionary = {
	"design": "Design done",
	"sketches": "Sketches ready to choose from",
	"picture": "Best render done",
	"turntable": "Turntable done",
	"animation": "Animation done",
	"building": "Build video done",
	"queue": "Render queue done",
}
## And what ended with nothing made: a design that failed, a render that
## could not be drawn.
const NOT_DONE: Dictionary = {
	"design": "The design did not finish",
	"sketches": "The design did not finish",
}
const RENDER_NOT_DONE := "The render did not finish"

## Stand-ins a check puts in place of the window and the browser before the
## app is made (donenote_probe), with looking(), attention(), permission(),
## ask() and notify(title, body); null for the real ones.
static var stand_in: Object = null
## Whether the browser's Notification is used, rather than the window's
## attention: on the web, or for a check of the web's way.
static var on_web: bool = OS.has_feature("web")

## The model's name, for the note (Main's ModelBar.model_name).
var named: Callable = func() -> String: return "Model"
## Whether what is starting now is a session's call from outside
## (Main: CommandSocket.at_work).
var driven: Callable = func() -> bool: return false
## A note is up and not yet seen: the title starts "Done · " until it is.
var waiting: bool = false
## Notes given since the app started, for a check and the log.
var given: int = 0

## The browser was asked whether the page may notify, this visit.
var _asked: bool = false
var _looked_ms: int = 0
## Render's dialog while it is followed, and what it is drawing: "" when
## nothing, "-" for what says nothing (a Quick or Good picture, a session's).
var _render: Node = null
var _render_kind: String = ""
var _render_made: Variant = null


## Whether long jobs say when they are done (Settings).
static func wanted() -> bool:
	return bool(ShellPrefs.value(SETTING))


static func want(on: bool) -> void:
	ShellPrefs.put(SETTING, on)


## A long job [param kind] the person started: on the web, the first asks
## the browser whether the page may notify, while the press is fresh.
func started(_kind: String) -> void:
	if not on_web or _asked or not wanted() or bool(driven.call()):
		return
	if _permission() != "default":
		return
	_asked = true
	_ask()


## [param kind] has ended, with something made or ([param ok] false) not:
## said, unless the person is looking or turned it off.
func finished(kind: String, ok: bool = true) -> void:
	if not wanted() or _looking():
		return
	var words: String = str(DONE.get(kind, "Done")) if ok \
		else str(NOT_DONE.get(kind, RENDER_NOT_DONE))
	given += 1
	print("done note: %s (%s)" % [words, str(named.call())])
	if on_web:
		_notify(str(named.call()), tr(words))
	else:
		_attention()
	waiting = true
	_looked_ms = Time.get_ticks_msec()
	_show_waiting()


## [param title] as the window or the tab should say it now: "Done · "
## before it while a note waits to be seen.
func titled(title: String) -> String:
	return prefix() + title if waiting and not title.begins_with(prefix()) else title


## What a title starts with while a note waits, in the language in use.
func prefix() -> String:
	return tr("Done") + " · "


## Render's dialog (RenderDialog), whose renders are followed from here on.
func follow_render(dialog: Node) -> void:
	_render = dialog


func _process(_delta: float) -> void:
	if _render != null and is_instance_valid(_render):
		_watch_render()
	if not waiting:
		return
	var now: int = Time.get_ticks_msec()
	if now - _looked_ms < LOOK_MS:
		return
	_looked_ms = now
	if _looking():
		_seen()
	else:
		# The model renamed meanwhile writes the title afresh (Main._show_name).
		_show_waiting()


## A render's start and end, as Render's dialog draws: a picture at Best, a
## turntable, an animation or a build video the person started.
func _watch_render() -> void:
	var drawing: bool = bool(_render.call("is_rendering"))
	if drawing == not _render_kind.is_empty():
		return
	if drawing:
		var kind: String = str(_render.get("_working"))
		var chosen: RenderSettings = _render.get("settings") as RenderSettings
		if not DONE.has(kind) or bool(driven.call()) or (kind == "picture"
				and (chosen == null or chosen.quality != RenderSettings.Quality.BEST)):
			kind = "-"
		_render_kind = kind
		# What it last made, to tell a new one from it as it ends.
		_render_made = _render.get("_last")
		if kind != "-":
			started(kind)
		return
	var ended: String = _render_kind
	_render_kind = ""
	if ended == "-":
		return
	var made: Variant = _render.get("_last")
	finished(ended, made is Dictionary and not (made as Dictionary).is_empty()
		and not is_same(made, _render_made))


func _show_waiting() -> void:
	if on_web or not waiting or DisplayServer.get_name() == "headless":
		return
	var window: Window = get_window()
	if window != null and window.title != titled(window.title):
		window.title = titled(window.title)


## The person is back: the title as it was, and a note still up in the
## system's list taken down.
func _seen() -> void:
	waiting = false
	if on_web:
		if stand_in == null and OS.has_feature("web"):
			JavaScriptBridge.eval("(window.brickworksDoneNotes || []).forEach(function (n) { "
				+ "try { n.close(); } catch (e) {} }); window.brickworksDoneNotes = [];", true)
		return
	var window: Window = get_window()
	if window != null and DisplayServer.get_name() != "headless":
		window.title = window.title.trim_prefix(prefix())


# -- the window and the browser, or a check's stand-ins for them --------------


## Whether the person is looking: the window has the focus, or the tab is
## in view and its page has the focus.
func _looking() -> bool:
	if stand_in != null:
		return bool(stand_in.call("looking"))
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval(
			"document.visibilityState === 'visible' && document.hasFocus()", true))
	if DisplayServer.get_name() == "headless":
		return false
	return DisplayServer.window_is_focused() \
		and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED


func _attention() -> void:
	if stand_in != null:
		stand_in.call("attention")
	elif DisplayServer.get_name() != "headless":
		DisplayServer.window_request_attention()


## The browser's Notification permission: "default" until the person
## answers, "granted", "denied", or "" where there is none.
func _permission() -> String:
	if stand_in != null:
		return str(stand_in.call("permission"))
	if not OS.has_feature("web"):
		return ""
	var said: Variant = JavaScriptBridge.eval(
		"('Notification' in window) ? String(Notification.permission) : ''", true)
	return str(said) if said != null else ""


func _ask() -> void:
	if stand_in != null:
		stand_in.call("ask")
	elif OS.has_feature("web"):
		JavaScriptBridge.eval("try { Notification.requestPermission(); } catch (e) {}", true)


## One notification: [param title] the model's name, [param body] what
## finished. A click on it brings the tab forward. A browser that may not
## notify, or a phone's, which notifies only through a service worker, shows
## none, and the tab's title says it.
func _notify(title: String, body: String) -> void:
	if stand_in != null:
		stand_in.call("notify", title, body)
		return
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(("""(function () {
		try {
			if (!('Notification' in window) || Notification.permission !== 'granted') return;
			var note = new Notification(%s, {body: %s, icon: '/favicon-192.png'});
			note.onclick = function () { window.focus(); note.close(); };
			(window.brickworksDoneNotes = window.brickworksDoneNotes || []).push(note);
		} catch (e) {}
	})()""") % [JSON.stringify(title), JSON.stringify(body)], true)
