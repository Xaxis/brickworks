## One header in every mode of the app (appchrome, 2026-11-23, AppHeader).
##
##   godot --path . --resolution 1280x800 --script src/dev/appchrome_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh appchrome_probe     a phone's window
##
## The owner: "when a user clicks Build it it opens the view of the app that
## doesnt have the brickworks logo in the header ... Same for when user closes
## the instruction manual view." Build it's step player drew a bar of its own
## over the whole window, and the viewer's had the word Brickworks and no mark.
##
## Laid out as the desktop has it and as a browser does (AppHeader.web_layout),
## each mode opened as a person opens it, and its header read:
##
##   the studio            the menu bar (ModelBar), or a phone's top bar
##   the page laid out     Booklet › Lay out page…, over the studio
##   ...and Done           the studio again
##   a shared model        /app?view=<id>, played by a stand-in server
##   Build it              pressed on the viewer's bar: the step player
##   ...and Close          the viewer again
##
## In each: the header from the window's top, the site's 60 points and its
## line, on the site's ground; the mark where every other mode has it, its
## cube 26 points, a fingertip square or more; the right-most control the
## gutter from the window's edge; on the menu bar's modes the same controls at
## the same places (in a browser Menu and Account, on the desktop Account),
## the mark's own way: in a browser home, in this tab, on the desktop the
## app's menu; and nothing of the mode over it (the step player's bar, the
## page's tools, the viewer's bar all start at its foot or below).
##
## Pictures in shots/appchrome/, named by the window's size and the layout.
extends SceneTree

const AppHeader := preload("res://src/ui/app_header.gd")
const SHOTS := "res://shots/appchrome/"
const ID := "Chr0meV1ew"
const MODEL := "res://models/house.ldr"

var _failures: int = 0
var _size: String = ""


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	var text: String = FileAccess.get_file_as_string(MODEL)
	if text.is_empty():
		print("appchrome_probe: SKIPPED, no %s" % MODEL)
		quit(3)
		return
	print("appchrome_probe: a %s window" % _size)
	BuildSteps._kept.clear()
	for web: bool in [false, true]:
		AppHeader.web_layout = web
		var layout: String = "web" if web else "desktop"
		print("\n== laid out as %s ==" % ("a browser has it" if web else "the desktop has it"))
		var told: Dictionary = {}
		await _studio(layout, told)
		await _viewer(layout, text, told)
		_same(layout, told)
	print("\nappchrome_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)


## The studio, the page laid out over it, and Done.
func _studio(layout: String, told: Dictionary) -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await _frames(90)
	var playback: Node = main.get("_playback")
	if playback != null:
		playback.call("stop")
	await _settle()
	told["studio"] = await _header(main, layout, "studio")
	var shell: Shell = main.get("_shell")
	var steps: StepsBar = main.get("_steps")
	if steps.current_step() == null:
		shell.run("timeline")
		for _n: int in 900:
			if steps.current_step() != null:
				break
			await process_frame
	shell.run("booklet_lay_out")
	var editor: Control = null
	for _n: int in 600:
		editor = main.get("_page_editor_made")
		if editor != null and editor.is_visible_in_tree():
			break
		await process_frame
	_ok(editor != null and editor.is_visible_in_tree(), "%s: Booklet, Lay out page opens the page" % layout)
	if editor != null and editor.is_visible_in_tree():
		await _frames(30)
		await _settle()
		var head: Dictionary = await _header(main, layout, "pages")
		told["pages"] = head
		_ok(editor.get_global_rect().position.y >= float(head["rect"].end.y) - 0.5,
			"%s: the page's own tools start under the header (at %.0f, the header's foot %.0f)" % [
			layout, editor.get_global_rect().position.y, head["rect"].end.y])
		var done: Control = editor.call("controls_by_name").get("page_done")
		await _click(done)
		await _frames(10)
		_ok(not editor.is_visible_in_tree(), "%s: Done puts the page away" % layout)
		var back: Dictionary = await _header(main, layout, "pages_closed")
		told["pages_closed"] = back
		var bar: ModelBar = main.get("_bar")
		if main.get("_phone") == null:
			_ok(bar.menus.is_visible_in_tree(), "%s: ...and the menus are back in the header" % layout)
	main.queue_free()
	await _frames(4)


## A shared model's viewer, Build it pressed, and Close.
func _viewer(layout: String, text: String, told: Dictionary) -> void:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe House", "author": "Probe Builder",
		"parts": 40, "url": "https://brickworks.diy/m/" + ID, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", ID)
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 2400:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "%s: the shared model opens in the viewer (%s)" % [
		layout, view.state if view != null else "no viewer"])
	if view == null or view.state != "ready":
		main.queue_free()
		await _frames(4)
		return
	var steps: StepsBar = main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	await _settle()
	var head: Dictionary = await _header(main, layout, "viewer")
	told["viewer"] = head
	var view_bar: Control = view.get("_bar")
	_ok(view_bar.is_visible_in_tree() and view_bar.get_global_rect().position.y >= float(head["rect"].end.y) - 0.5,
		"%s: the viewer's own bar is under the header (at %.0f, the header's foot %.0f)" % [layout,
		view_bar.get_global_rect().position.y, head["rect"].end.y])
	var build: Control = view.controls_by_name()["view_build"]
	await _click(build)
	var mode: BuildMode = main.get("_build_mode")
	since = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _frames(20)
	await _settle()
	_ok(mode.is_open(), "%s: Build it opens the step player" % layout)
	head = await _header(main, layout, "build")
	told["build"] = head
	var top: Control = mode.controls_by_name()["build_top"]
	_ok(top.get_global_rect().position.y >= float(head["rect"].end.y) - 0.5,
		"%s: the step player's bar starts under the header (at %.0f, the header's foot %.0f)" % [layout,
		top.get_global_rect().position.y, head["rect"].end.y])
	_ok(mode.free_rect().position.y >= float(head["rect"].end.y),
		"%s: ...and the step is framed below both" % layout)
	await _click(mode.controls_by_name()["build_close"])
	await _frames(20)
	await _settle()
	_ok(not mode.is_open(), "%s: Close puts the step player away" % layout)
	head = await _header(main, layout, "closed")
	told["closed"] = head
	_ok(view_bar.is_visible_in_tree() and absf(view_bar.get_global_rect().position.y - float(head["rect"].end.y)) < 1.0,
		"%s: ...and the viewer is as it came, its bar right under the header" % layout)
	var bar: ModelBar = main.get("_bar")
	Outside.opened.clear()
	await _click(bar.brand)
	await _frames(6)
	var popup: PopupMenu = bar.mark.get_popup()
	if AppHeader.web_layout:
		_ok(Outside.opened.has("/") and not popup.visible,
			"%s: the mark is the way home, in this tab, as the site's is (%s)" % [layout, Outside.opened])
	else:
		_ok(popup.visible and popup.item_count > 5, "%s: the mark opens the app's menu (%d rows)" % [layout,
			popup.item_count])
		popup.hide()
	if AppHeader.web_layout:
		await _click(bar.mark)
		await _frames(6)
		_ok(popup.visible and popup.item_count > 5, "%s: Menu opens the app's menu (%d rows)" % [layout,
			popup.item_count])
		popup.hide()
		await _frames(4)
	Outside.opened.clear()
	await _click(bar.controls_by_name()["account"])
	await _frames(6)
	_ok(Outside.opened.size() == 1 and Outside.opened[0].ends_with("/settings"),
		"%s: Account on somebody else's model is the site's settings, nobody's account read here (%s)" % [
		layout, Outside.opened])
	main.queue_free()
	await _frames(4)


## The header of [param main] as it stands, checked on its own, its picture
## kept as <size>_<layout>_<mode>.png.
func _header(main: Node, layout: String, mode: String) -> Dictionary:
	var bar: ModelBar = main.get("_bar")
	# A phone's studio has its own top bar (PhoneShell); every other mode the
	# menu bar.
	var phone: Node = main.get("_phone") if str(main.get("_viewing")).is_empty() else null
	var named: Dictionary = phone.call("controls_by_name") if phone != null else bar.controls_by_name()
	var panel: Control = named.get("app_header")
	var at: Dictionary = {"mode": mode, "phone": phone != null}
	_ok(panel != null and panel.is_visible_in_tree(), "%s %s: the header is up" % [layout, mode])
	if panel == null or not panel.is_visible_in_tree():
		at["rect"] = Rect2()
		return at
	var pt: float = AppHeader.points(panel)
	var width: float = root.get_visible_rect().size.x
	var rect: Rect2 = panel.get_global_rect()
	at["rect"] = rect
	at["pt"] = pt
	var tall: float = (AppHeader.TALL + AppHeader.LINE) * pt
	_ok(absf(rect.position.y) < 0.5 and absf(rect.position.x) < 0.5 and absf(rect.size.x - width) < 1.0
		and absf(rect.size.y - tall) < 1.5,
		"%s %s: the header across the window's top, %.0f points tall (want %.0f): %s" % [layout, mode,
		rect.size.y / pt, AppHeader.TALL + AppHeader.LINE, rect])
	var ground: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	_ok(ground != null and ground.bg_color.is_equal_approx(AppHeader.GROUND) and ground.border_width_bottom >= 1,
		"%s %s: on the site's ground, its line along the foot" % [layout, mode])
	# The mark: the control at the left with the cube on it.
	var mark: Button = named.get("app_home") if named.has("app_home") else named.get("app_menu")
	if phone == null:
		mark = bar.brand
	at["mark"] = mark.get_global_rect() if mark != null else Rect2()
	var icon_tall: float = float(mark.icon.get_height()) / Icons.density(mark) if mark != null and mark.icon != null else 0.0
	at["icon"] = icon_tall
	_ok(mark != null and mark.is_visible_in_tree() and absf(icon_tall - AppHeader.MARK * pt) < 1.5
		and mark.get_global_rect().size.y >= AppHeader.TARGET * pt - 0.5,
		"%s %s: the mark at the left, its cube %.0f points (want %.0f), %.0f points tall" % [layout, mode,
		icon_tall / pt, AppHeader.MARK, mark.get_global_rect().size.y / pt if mark != null else 0.0])
	var gutter: float = (AppHeader.GUTTER_NARROW if width / pt < 600.0 else AppHeader.GUTTER) * pt
	_ok(mark != null and absf(mark.get_global_rect().position.x - gutter) < 1.5,
		"%s %s: ...the gutter from the window's left (%.0f, want %.0f)" % [layout, mode,
		mark.get_global_rect().position.x if mark != null else -1.0, gutter])
	at["named"] = mark.text if mark != null else ""
	# What is at the right: Menu and Account on the menu bar's modes in a
	# browser, Account on the desktop's; Menu on a phone's top bar.
	var right: Array[String] = []
	for name: String in ["app_menu", "account"]:
		var control: Control = named.get(name)
		if control == null or not control.is_visible_in_tree() or control == mark:
			continue
		right.append(name)
		at[name] = control.get_global_rect()
		_ok(control.get_global_rect().size.y >= AppHeader.TARGET * pt - 0.5,
			"%s %s: %s a fingertip tall (%.0f points)" % [layout, mode, name, control.get_global_rect().size.y / pt])
	at["right"] = right
	# The right-most thing in the header's row, the gutter from the edge.
	var last: float = 0.0
	var last_name: String = ""
	for child: Node in _controls_in(panel):
		var button: Button = child as Button
		if button != null and button.is_visible_in_tree() and button.get_global_rect().end.x > last:
			last = button.get_global_rect().end.x
			last_name = button.name
	_ok(absf(last - (width - gutter)) < 1.5,
		"%s %s: %s right-most, the gutter from the edge (ends %.0f, want %.0f)" % [layout, mode,
		last_name, last, width - gutter])
	await _settle()
	_save("%s_%s_%s.png" % [_size, layout, mode])
	return at


## Every control under [param node], at any depth.
static func _controls_in(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children():
		out.append(child)
		out.append_array(_controls_in(child))
	return out


## Every mode against the viewer's: the mark at its place, and on the menu
## bar's modes the same controls at the same places.
func _same(layout: String, told: Dictionary) -> void:
	if not told.has("viewer"):
		return
	var base: Dictionary = told["viewer"]
	for mode: String in told:
		var one: Dictionary = told[mode]
		if not one.has("mark"):
			continue
		_ok(_near(one["rect"], base["rect"]) and absf(float(one["icon"]) - float(base["icon"])) < 1.0
			and absf((one["mark"] as Rect2).position.x - (base["mark"] as Rect2).position.x) < 1.5
			and absf((one["mark"] as Rect2).get_center().y - (base["mark"] as Rect2).get_center().y) < 1.5,
			"%s: %s's header and mark where the viewer's are" % [layout, mode])
		if bool(one["phone"]):
			# A phone's studio: its own top bar, its tools in it and Menu at the
			# right in a browser (the site's phone header keeps the account in
			# Menu); on the desktop the mark is the menu.
			_ok(one["right"] == (["app_menu"] if AppHeader.web_layout else []),
				"%s: %s has %s at the right, as a phone's header has" % [layout, mode,
				"Menu" if AppHeader.web_layout else "no menu but the mark"])
			continue
		_ok(one["right"] == base["right"], "%s: %s has %s at the right, as the viewer does" % [layout, mode,
			" and ".join(one["right"])])
		for name: String in base["right"]:
			if one.has(name):
				_ok(_near(one[name], base[name]), "%s: ...%s where the viewer's is (%s, %s)" % [layout, name,
					one[name], base[name]])


static func _near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 1.5 and a.size.distance_to(b.size) < 1.5


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw


## A mouse's click on [param control], or a finger's tap on a phone.
func _click(control: Control) -> void:
	if control == null:
		return
	var at: Vector2 = control.get_global_rect().get_center()
	var shown: Vector2 = root.get_final_transform() * at
	if Phone.on():
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = down
			touch.position = shown
			Input.parse_input_event(touch)
			await process_frame
	else:
		var move := InputEventMouseMotion.new()
		move.position = shown
		Input.parse_input_event(move)
		await process_frame
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = shown
			Input.parse_input_event(click)
			await process_frame
	await _settle()


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SHOTS + name))
		print("  wrote shots/appchrome/%s" % name)
