## This week's quick build in the app (prompts, 2026-11-23): a weekly prompt's
## brief said above a copy of its template, and Share's box that enters the
## copy or keeps it out, laid out as a phone's browser has the app.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 390x844 \
##     --script src/dev/prompt_probe.gd
##
## No network: api/people.js ?op=prompt_of and api/share.js are played by
## FakeShared, which answers each request as the endpoint does, as text off
## the wire, so the app's own reading of the answer (SharedModels.prompt_in)
## is what is tested. Nothing is given on the command line: main.gd reads its
## own arguments.
##
## The edge: an answer of another status or shape, a closed prompt, one for
## another template, one with no day it ends, all no prompt; the day said as
## "29 November"; a long brief cut on a phone at a sentence, the day it ends
## still said.
##
## The studio (/app?copy=<id>, Main._maybe_copy): the template copied, its
## open done while prompt_of is still unanswered (it is never waited on),
## then the line above the model with the title, the brief and the day,
## the prompt kept with the copy (ModelStore.prompt_now); at 390 x 844 the
## line inside the window's width, over none of the phone's bars, and wholly
## above the model as it is drawn; Got it takes it away. A copy of a link
## that is no prompt's template says nothing, and nor does an answer that
## comes once New has replaced the copy.
##
## Share (SharePanel): for a copy of the template, the box directly under
## List it in the gallery, asked of the server as the panel opens; greyed
## and unticked with its tooltip while the model is not listed; ticked once
## it is; published ticked, no prompt_out sent and the status line saying it
## was entered and where every entry is; unticked by a tap, prompt_out: true
## sent and the server's words said; its choice kept across the gallery's
## box. A copy reopened later, with nothing in memory, asked again and
## shown; a model copied from no link has no box and asks nothing.
##
## The words in German, French and Spanish (locale/*.po): the line, the box,
## the status line's and Got it, through the app's own matching (Language).
##
## Pictures in shots/prompt/.
extends SceneTree

const SHOTS := "res://shots/prompt/"
## The template of this week's quick build, and a link that is no prompt's.
const TEMPLATE := "Pr0mptT3mp"
const PLAIN := "Pl41nL1nk0"
const BRIEF := "A home for one minifigure: a bed, a door, a light and somewhere to sit. " \
	+ "Under 150 parts, on a 16 x 16 plate."
const PAGE := "https://brickworks.diy/challenge?id=12"
const LINE := "This week's quick build, Habitat: “" + BRIEF + "” Publish it by 29 November to enter."
const ENTERED := "Entered in this week's quick build: Habitat. Every entry is at brickworks.diy/challenge?id=12."
const KEPT_OUT := "Kept out of this week's quick build, as you asked."
const BOX := "Enters this week's quick build: Habitat"
const TIP := "Shown in the gallery, it enters this week's quick build"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _bar: ModelBar
var _shell: Shell


## api/share.js and api/people.js as they answer, by the request's path.
class FakeShared extends SharedModels:
	## The model at every link.
	var text: String = ""
	## ?op=prompt_of's prompt by template; any other is answered null.
	var prompts: Dictionary = {}
	## While set, ?op=prompt_of has not answered yet.
	var hold: bool = false
	var prompt_asked: Array[String] = []
	var prompt_tokens: Array[String] = []
	var prompt_answered: int = 0
	## What each publish sent, and what its answer says of the quick build.
	var published: Array[Dictionary] = []
	var entry: Dictionary = {}

	func _fetch(path: String, method: int, token: String, body: String) -> Dictionary:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if path.begins_with("/api/people?op=prompt_of"):
			prompt_asked.append(path)
			prompt_tokens.append(token)
			while hold:
				await tree.process_frame
			await tree.process_frame
			prompt_answered += 1
			return _wire(200, {"prompt": prompts.get(path.get_slice("model=", 1).uri_decode())})
		await tree.process_frame
		if path.begins_with("/api/share?id="):
			var id: String = path.trim_prefix("/api/share?id=").get_slice("&", 0)
			return _wire(200, {"id": id, "name": "Probe Starter House", "author": "Brickworks",
				"licence": "cc-by-4.0", "url": "https://brickworks.diy/m/" + id, "parts": 7,
				"version": 1, "model": text})
		if path == "/api/share?op=mine":
			return _wire(200, {"shared": [], "credit": null})
		if path == "/api/share" and method == HTTPClient.METHOD_POST:
			var sent: Variant = JSON.parse_string(body)
			if not sent is Dictionary:
				return _wire(400, {"error": "not JSON"})
			published.append(sent)
			var given: String = str((sent as Dictionary).get("id", "Pr0mptC0py"))
			var reply: Dictionary = {"id": given, "url": "https://brickworks.diy/m/" + given,
				"embed": SharedModels.embed_for(given), "parts": 7,
				"updated": (sent as Dictionary).has("id"),
				"listed": (sent as Dictionary).get("listed") == true, "version": 1, "said": ""}
			if not entry.is_empty():
				reply["prompt"] = entry
			return _wire(200 if (sent as Dictionary).has("id") else 201, reply)
		return _wire(404, {"error": "not here"})

	## An answer as it comes off the wire: JSON text read back, numbers floats.
	static func _wire(code: int, body: Dictionary) -> Dictionary:
		return {"code": code, "body": JSON.parse_string(JSON.stringify(body))}


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  prompt probe: needs a window, laid out as a phone's")
		quit(1)
		return
	# Nothing reaches the network: the deployment and the account's own
	# requests find nothing at this port, and the two endpoints are FakeShared.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	# Laid out for a finger, as a phone's browser gets the app.
	Phone._on = 1
	Phone._wide = false
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_edges()

	var fake := FakeShared.new()
	fake.text = FileAccess.get_file_as_string("res://models/house.ldr")
	fake.prompts[TEMPLATE] = {"id": 12, "title": "Habitat", "brief": BRIEF,
		"starts_on": "2026-11-23", "ends_on": "2026-11-29", "open": true, "template": TEMPLATE,
		"page": PAGE}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_world") != null and _main.get("_shell") != null:
			break
	if _main.get("_shell") == null:
		print("  prompt probe: SKIPPED — the window did not come up")
		quit(3)
		return
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	var window: Rect2 = root.get_visible_rect()
	print("\n  a %d x %d window, %.0f units across" % [DisplayServer.window_get_size().x,
		DisplayServer.window_get_size().y, window.size.x])
	_check("the window is laid out for a phone", _main.get("_phone") != null and not Phone.wide())
	# Signed in once start-up has said who is here, as a person only can be.
	var account: Account = _main.get("_account")
	await account.deployment.wait()
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(10)
	# The parts drawer put away, as the studio opens on a phone: the strip over
	# the model waits while it is out (Main._show_notices).
	var drawer: SideDock = _main.get("_bin_dock")
	if drawer != null and drawer.is_open():
		drawer.set_open(false)
		await _frames(20)

	await _studio(fake)
	await _panel(fake)
	_languages()
	_finish()


# -- the edge -----------------------------------------------------------------


func _edges() -> void:
	print("\nwhat ?op=prompt_of may answer")
	var good: Dictionary = {"id": 12.0, "title": "Habitat", "brief": "A home.", "starts_on": "2026-11-23",
		"ends_on": "2026-11-29", "open": true, "template": TEMPLATE, "page": PAGE}
	var read: Dictionary = SharedModels.prompt_in({"code": 200, "body": {"prompt": good}}, TEMPLATE)
	_check("an open prompt is read: id %s, %s, ends %s, page %s" % [read.get("id"), read.get("title"),
		read.get("ends_on"), read.get("page")], read.get("id") is int and int(read["id"]) == 12
		and read["title"] == "Habitat" and read["template"] == TEMPLATE and read["page"] == PAGE)
	var none: Array = [
		["null", {"code": 200, "body": {"prompt": null}}],
		["a 500", {"code": 500, "body": {"prompt": good}}],
		["nothing at all", {"code": 0, "body": null}],
		["a prompt that is words", {"code": 200, "body": {"prompt": "Habitat"}}],
		["no body", {"code": 200, "body": "Habitat"}],
		["one said closed", {"code": 200, "body": {"prompt": good.merged({"open": false}, true)}}],
		["another template's", {"code": 200, "body": {"prompt": good.merged({"template": PLAIN}, true)}}],
		["no day it ends", {"code": 200, "body": {"prompt": good.merged({"ends_on": "soon"}, true)}}],
		["no title", {"code": 200, "body": {"prompt": good.merged({"title": ""}, true)}}],
		["no id", {"code": 200, "body": {"prompt": good.merged({"id": "twelve"}, true)}}],
	]
	for one: Array in none:
		_check("%s is no prompt" % one[0], SharedModels.prompt_in(one[1], TEMPLATE).is_empty())
	_check("a link that is not a link's id is not asked about", SharedModels.is_id(TEMPLATE)
		and not SharedModels.is_id("../../etc"))
	_check("the day it ends said as a day (%s, %s)" % [SharedModels.day_words("2026-11-29"),
		SharedModels.day_words("2027-01-03")], SharedModels.day_words("2026-11-29") == "29 November"
		and SharedModels.day_words("2027-01-03") == "3 January" and SharedModels.day_words("2026-13-01").is_empty())
	var long: Dictionary = read.merged({"brief": BRIEF + " Give it a roof that lifts off, so the "
		+ "minifigure can be seen at home, and a garden at the back with a tree in it."}, true)
	var cut: String = SharedModels.prompt_line(long, SharedModels.BRIEF_ON_A_PHONE)
	var whole: String = SharedModels.prompt_line(long)
	_check("a long brief is cut on a phone at a sentence, the day still said (%d of %d characters: %s)"
		% [cut.length(), whole.length(), cut], cut.length() < whole.length()
		and cut.ends_with("” Publish it by 29 November to enter.") and cut.contains("somewhere to sit.")
		and not cut.contains("garden") and whole.contains("garden"))


# -- the studio -----------------------------------------------------------------


func _studio(fake: FakeShared) -> void:
	print("\na copy of this week's template (/app?copy=)")
	fake.hold = true
	var asked: int = fake.prompt_asked.size()
	var answered: int = fake.prompt_answered
	var opened: bool = await _copy(TEMPLATE)
	_check("the template's copy opened, a copy of it (%s, %d parts)" % [_store.remixed_from,
		_parts_on()], opened and _parts_on() > 0)
	_check("its open was done with prompt_of asked and not yet answered: never waited on (%d asked, %d answered)"
		% [fake.prompt_asked.size() - asked, fake.prompt_answered - answered],
		fake.prompt_asked.size() == asked + 1 and fake.prompt_answered == answered)
	_check("asked for the template, with no session (%s)" % (fake.prompt_asked[-1] if
		fake.prompt_asked.size() > asked else "nothing asked"), fake.prompt_asked.size() > asked
		and fake.prompt_asked[-1] == "/api/people?op=prompt_of&model=" + TEMPLATE
		and fake.prompt_tokens[-1].is_empty())
	var notice: RestoreNotice = _main.get("_prompt_notice")
	_check("nothing said before it answers", notice == null or not notice.visible)
	fake.hold = false
	for _n: int in 600:
		await process_frame
		notice = _main.get("_prompt_notice")
		if notice != null and notice.visible:
			break
	await _frames(120)
	_check("the line above the model says the title, the brief and the day (%s)"
		% (notice.words() if notice != null else "no line"), notice != null and notice.words() == LINE)
	var kept: Dictionary = _store.prompt_now()
	_check("the prompt is kept with the copy, in memory (%s)" % [kept], int(kept.get("id", 0)) == 12
		and kept.get("title") == "Habitat" and kept.get("template") == TEMPLATE and kept.get("page") == PAGE)
	var saved: String = FileAccess.get_file_as_string(ModelStore.saved_path(_store.title))
	_check("...and in none of what it saves (%s, %d bytes)" % [_store.title, saved.length()],
		not saved.is_empty() and not saved.contains("Habitat") and not saved.contains("challenge"))
	var named: Dictionary = _main.call("_page_controls")
	_check("its Got it is a control the page can find", named.has("prompt_got_it"))
	if notice == null or not notice.visible:
		return
	_layout(notice)
	await _shot("1_line.png")
	await _tap((named["prompt_got_it"] as Control).get_global_rect().get_center())
	await _frames(20)
	var others: PackedStringArray = _other_notices(notice)
	_check("Got it takes it away, and the strip with it unless another notice is up (%s)"
		% (", ".join(others) if not others.is_empty() else "none"), not notice.visible
		and (_main.get("_notices") as Control).visible == not others.is_empty())

	print("\na copy of a link that is no prompt's template")
	answered = fake.prompt_answered
	await _copy(PLAIN)
	for _n: int in 300:
		await process_frame
		if fake.prompt_answered > answered:
			break
	await _frames(30)
	_check("asked, answered null, and nothing said (%d answered)" % (fake.prompt_answered - answered),
		fake.prompt_answered == answered + 1 and not notice.visible and _store.prompt_now().is_empty())

	print("\nNew before the answer comes")
	fake.hold = true
	answered = fake.prompt_answered
	await _copy(TEMPLATE)
	await _bar._start_new()
	await _frames(10)
	fake.hold = false
	for _n: int in 300:
		await process_frame
		if fake.prompt_answered > answered:
			break
	await _frames(30)
	_check("the answer for the copy that went says nothing over the new model",
		fake.prompt_answered == answered + 1 and not notice.visible and _store.prompt_now().is_empty()
		and _store.remixed_from.is_empty())


## The line at 390 points across: in the window, clear of the phone's bars,
## and the model drawn wholly under the strip it is in.
func _layout(notice: RestoreNotice) -> void:
	var window: Rect2 = root.get_visible_rect()
	var strip: Control = _main.get("_notices")
	var rect: Rect2 = strip.get_global_rect()
	print("  the strip: %d..%d across, %d..%d down, of %d x %d; other notices in it: %s" % [
		roundi(rect.position.x), roundi(rect.end.x), roundi(rect.position.y), roundi(rect.end.y),
		roundi(window.size.x), roundi(window.size.y), ", ".join(_other_notices(notice))])
	var off := PackedStringArray()
	for found: Node in notice.find_children("*", "Control", true, false):
		var control: Control = found
		if control.is_visible_in_tree() and (control.get_global_rect().position.x < window.position.x - 0.5
				or control.get_global_rect().end.x > window.end.x + 0.5):
			off.append("%s %s" % [control.get_class(), control.get_global_rect()])
	var own: Rect2 = notice.get_global_rect()
	_check("the line and its Got it inside the window's width%s" % ("" if off.is_empty()
		else ": " + "; ".join(off)), off.is_empty() and own.position.x >= window.position.x - 0.5
		and own.end.x <= window.end.x + 0.5)
	var phone: PhoneShell = _main.get("_phone")
	var bars: Array = [["the phone's top bar", phone.get("_top")], ["its row of tools", phone.get("_row")],
		["its Fit", phone.get("_fit")], ["the toolbar", _shell.toolbar], ["the menus", _bar]]
	for pair: Array in bars:
		var bar: Control = pair[1]
		if bar == null or not bar.is_visible_in_tree():
			continue
		# Within a pixel is the phone's scale rounding a bar's edge (its top
		# bar is 61.7 px tall at 1.087), not the line over it.
		_check("the line is over none of %s (%s, %s)" % [pair[0], notice.get_global_rect(),
			bar.get_global_rect()], not notice.get_global_rect().grow(-1.0).intersects(bar.get_global_rect()))
	var camera: Camera3D = _main.get("_camera")
	var box: AABB = _main.call("_built_bounds")
	var drawn := Rect2(camera.unproject_position(box.get_endpoint(0)), Vector2.ZERO)
	for n: int in range(1, 8):
		drawn = drawn.expand(camera.unproject_position(box.get_endpoint(n)))
	_check("the model is drawn wholly under the strip, its box from %d down (the strip ends at %d)"
		% [roundi(drawn.position.y), roundi(rect.end.y)], drawn.position.y >= rect.end.y
		and drawn.end.y > drawn.position.y)


# -- Share -------------------------------------------------------------------------


func _panel(fake: FakeShared) -> void:
	print("\nShare, for a copy of this week's template")
	fake.entry = {}
	await _copy(TEMPLATE)
	for _n: int in 300:
		await process_frame
		if not _store.prompt_now().is_empty():
			break
	var asked: int = fake.prompt_asked.size()
	var panel: SharePanel = _open_share()
	_check("File › Share… opens the panel", panel != null and panel.visible)
	if panel == null or not panel.visible:
		return
	await _until_shown(panel, fake, asked)
	var box: CheckBox = panel.get("_prompt_box")
	var listing: CheckBox = panel.get("_list")
	_check("it asked again for the model the copy was made from (%s)" % (fake.prompt_asked[-1]
		if fake.prompt_asked.size() > asked else "nothing asked"), fake.prompt_asked.size() == asked + 1
		and fake.prompt_asked[-1].ends_with("model=" + TEMPLATE))
	_check("the quick build's box is there: \"%s\"" % box.text, box.is_visible_in_tree() and box.text == BOX
		and panel.controls_by_name().has("share_prompt"))
	_check("...directly under List it in the gallery", box.get_parent() == listing.get_parent()
		and box.get_index() == listing.get_index() + 1 and listing.text == "List it in the gallery")
	_check("not listed, it is greyed and unticked, and says why (%s)" % box.tooltip_text,
		not listing.button_pressed and box.disabled and not box.button_pressed and box.tooltip_text == TIP)
	await _tap_box(listing, true, "List it in the gallery")
	_check("listed, it is ticked, and can be unticked", listing.button_pressed and not box.disabled
		and box.button_pressed and panel.page_state()["prompt_in"] == true)
	await _shot("2_panel.png")

	fake.entry = {"id": 12, "title": "Habitat", "entered": true, "page": PAGE}
	await panel.publish()
	var sent: Dictionary = _last_sent(fake)
	_check("published ticked: listed, a copy of the template, and no prompt_out (%s)" % [
		sent.keys().filter(func(key: String) -> bool: return key in ["listed", "remixed_from", "prompt_out"])],
		panel.state == "published" and sent.get("listed") == true
		and sent.get("remixed_from") == TEMPLATE and not sent.has("prompt_out"))
	_check("the status line says it was entered, and where every entry is (%s)" % panel._status.text,
		panel._status.text.ends_with(" " + ENTERED) and panel.page_state()["prompt_said"] == ENTERED)
	await _shot("3_entered.png")

	await _tap_box(box, false, "the quick build's box")
	_check("a tap unticks it, still enabled", not box.button_pressed and not box.disabled)
	fake.entry = {"id": 12, "title": "Habitat", "entered": false, "said": KEPT_OUT}
	await panel.publish()
	sent = _last_sent(fake)
	_check("published unticked: prompt_out: true goes with it, still listed", sent.get("prompt_out") == true
		and sent.get("listed") == true)
	_check("...and the server's words are said (%s)" % panel._status.text,
		panel._status.text.ends_with(" " + KEPT_OUT))
	await _tap_box(listing, false, "List it in the gallery")
	_check("out of the gallery, the box is greyed and unticked", box.disabled and not box.button_pressed)
	await _tap_box(listing, true, "List it in the gallery")
	_check("listed again, it is as it was left: unticked", not box.disabled and not box.button_pressed)
	fake.entry = {}
	await panel.publish()
	_check("...and so it goes: prompt_out: true", _last_sent(fake).get("prompt_out") == true)

	print("\nthe copy reopened later, nothing of the week in memory")
	panel.visible = false
	_store.prompt = {}
	asked = fake.prompt_asked.size()
	_check("Share opens again", _open_share().visible)
	await _until_shown(panel, fake, asked)
	_check("asked of the server, and the box is there again (%d asked)" % (fake.prompt_asked.size() - asked),
		fake.prompt_asked.size() == asked + 1 and box.is_visible_in_tree() and box.text == BOX)
	panel.visible = false

	print("\na model copied from no link")
	await _bar._start_new()
	await _frames(10)
	asked = fake.prompt_asked.size()
	_check("Share opens on it", _open_share().visible)
	await _frames(40)
	_check("no box, and nothing asked (%d asked)" % (fake.prompt_asked.size() - asked),
		not box.visible and not panel.controls_by_name().has("share_prompt")
		and panel.page_state()["prompt_shown"] == false and fake.prompt_asked.size() == asked)
	panel.visible = false


## File › Share…, by its command, or as Main runs it where the layout has no
## such command.
func _open_share() -> SharePanel:
	if not _shell.run("share"):
		print("  (share is not a command here: opened as Main opens it)")
		_main.call("_share_wanted")
	return _main.get("_share_panel")


## The strip's other notices shown just now, by their class.
func _other_notices(notice: Control) -> PackedStringArray:
	var out := PackedStringArray()
	for note: Node in (_main.get("_notices") as Control).get_child(0).get_children():
		if note != notice and (note as Control).visible:
			out.append(note.get_class() if note.get_script() == null
				else str((note.get_script() as Script).get_global_name()))
	return out


## What the last publish sent, or {} when none was.
func _last_sent(fake: FakeShared) -> Dictionary:
	return fake.published[-1] if not fake.published.is_empty() else {}


## Until the panel has asked of the server and its answer has come.
func _until_shown(panel: SharePanel, fake: FakeShared, asked: int) -> void:
	for _n: int in 300:
		await process_frame
		if fake.prompt_asked.size() > asked and fake.prompt_answered >= fake.prompt_asked.size() \
				and panel.page_state()["prompt_shown"] == true:
			break
	await _frames(10)


## Tap [param box] where it is drawn, scrolled into sight, to make it [param
## on]. Said when a tap could not, and then made so, so that one control out
## of a finger's reach is one failure and not every check after it.
func _tap_box(box: CheckBox, on: bool, what: String) -> void:
	var holder: Node = box.get_parent()
	while holder != null and not holder is ScrollContainer:
		holder = holder.get_parent()
	if holder is ScrollContainer:
		(holder as ScrollContainer).ensure_control_visible(box)
	await _frames(10)
	var at: Vector2 = box.get_global_rect().get_center()
	var phone: PhoneShell = _main.get("_phone")
	_check("%s is where a finger can tap it (%s)" % [what, at], root.get_visible_rect().has_point(at)
		and not phone.covers(at))
	await _tap(at)
	await _frames(10)
	if not _check("a tap on %s makes it %s" % [what, "ticked" if on else "unticked"],
			box.button_pressed == on):
		box.button_pressed = on
		await _frames(5)


# -- the words ---------------------------------------------------------------------


func _languages() -> void:
	print("\nthe words in German, French and Spanish")
	Language.keep_name("Habitat")
	var wanted: Dictionary = {
		"de": ["Schnellbau der Woche, Habitat: „", "“ Veröffentliche es bis zum 29. November, um teilzunehmen.",
			"Nimmt am Schnellbau der Woche teil: Habitat",
			"Beim Schnellbau der Woche eingereicht: Habitat. Alle Beiträge findest du unter brickworks.diy/challenge?id=12.",
			"Verstanden", "In der Galerie gezeigt, nimmt es am Schnellbau der Woche teil"],
		"fr": ["Construction express de la semaine, Habitat : « ",
			" » Publiez-le au plus tard le 29 novembre pour participer.",
			"Participe à la construction express de la semaine : Habitat",
			"Inscrit à la construction express de la semaine : Habitat. Toutes les participations sont sur brickworks.diy/challenge?id=12.",
			"Compris", "Publié dans la galerie, il participe à la construction express de la semaine"],
		"es": ["Construcción rápida de la semana, Habitat: «", "» Publícalo hasta el 29 de noviembre para participar.",
			"Participa en la construcción rápida de la semana: Habitat",
			"Inscrito en la construcción rápida de la semana: Habitat. Todas las participaciones están en brickworks.diy/challenge?id=12.",
			"Entendido", "Mostrado en la galería, participa en la construcción rápida de la semana"],
	}
	for code: String in wanted:
		Language.apply(code)
		var said: Array = wanted[code]
		var line: String = Language.says(LINE)
		_check("%s: the line says the title and the day, the brief as written (%s)" % [code, line],
			line.begins_with(str(said[0])) and line.contains(BRIEF) and line.ends_with(str(said[1])))
		var others: Array = [[BOX, said[2]], [ENTERED, said[3]], ["Got it", said[4]], [TIP, said[5]]]
		for pair: Array in others:
			var got: String = Language.says(str(pair[0]))
			_check("%s: \"%s\" is \"%s\"" % [code, pair[0], got], got == str(pair[1]))
	Language.apply("en")


# -- helpers --------------------------------------------------------------------------


## Copy the link [param id] as /app?copy= does once signed in: true when the
## copy is open.
func _copy(id: String) -> bool:
	_main.set("_copying", id)
	_main.set("_copy_started", false)
	_main.set("_first_open_done", true)
	await _main.call("_maybe_copy")
	await _frames(10)
	return _store.remixed_from == id


func _parts_on() -> int:
	var world: BrickWorld = _main.get("_world")
	return world.brick_count() - _store.scenery.size()


## A finger's tap at [param at], in the window's units: down, then up a
## moment later, as the screen gives it (the mouse's from it).
func _tap(at: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at * scale
		touch.pressed = down
		Input.parse_input_event(touch)
		await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SHOTS + name))
		print("  wrote shots/prompt/%s" % name)


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("")
	if _failures == 0:
		print("this week's quick build is said over its copy, entered from Share, and kept out by one tap")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
