## Who is signed in, and the way out.
##
## Opened from Account on the toolbar. Says which address this is, whether
## Brickworks could confirm it just now (the desktop keeps working offline
## once signed in, and says so here rather than pretending), what the
## account holds — the address, not the models — and signs out. Signing
## out switches off this tab's Claude connector, because the connector
## belongs to the account. On the web it says whether the browser agreed to
## keep the models, which live only there (StorageKeep).
##
## And whether Claude is connected to the account (2026-10-11): which of
## its apps, since when and when last used, with Disconnect Claude, which
## ends every connection at once — Claude's tokens stop working that
## moment, on every device. Or, not connected, a way to connect it.
##
## The owner's account (MASTER_EMAIL) also gets a link to the admin page,
## on the web, where the page is.
##
## And what came into the account's feed since it was last opened
## (2026-10-18, api/people.js ?op=feed_count, supabase/follows.sql): new
## models and versions from people it follows, photos, comments and remixes
## of its models. Asked when somebody signs in, when the panel opens, when
## the window comes back to the front, and every five minutes; the count is
## on Account in the bar (feed_counted) and here, with Open your feed,
## which is the site's /feed. Opening the feed there clears it.
class_name AccountPanel
extends PanelContainer

## How big it would like to be, before the window has its say.
const WIDE := 420.0
const TALL := 480.0

var account: Account

var _who: Label
var _state: Label
var _kept: Label
var _admin: LinkButton
var _sign_out: Button
var _done: Button
var _claude_box: VBoxContainer
var _claude_state: Label
var _claude_connect: LinkButton
var _claude_disconnect: Button
var connector: ClaudeConnector

## The person asked to sign out; the app switches the connector off and
## the sign-in screen comes back.
signal sign_out_wanted()

## How many things came into the feed since it was last opened: 0 when
## none, or nobody is signed in.
signal feed_counted(count: int)

## How often the count is asked again while signed in.
const FEED_EVERY := 300.0

var feed_count: int = 0
var _feed_line: Label
var _feed_link: LinkButton
var _feed_asking := false
var _feed_asked_at := -INF


func setup(with_account: Account) -> void:
	account = with_account
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "Your account"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 14)
	_who.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(_who)

	_state = _line("", 12, 0.7)
	column.add_child(_state)

	column.add_child(_line("Your account is your email address.", 12, 0.7))
	# Where the models are, and on the web whether the browser agreed to
	# keep them (StorageKeep): read again while the panel is open (_process).
	_kept = _line(StorageKeep.words(), 12, 0.7)
	column.add_child(_kept)

	# Claude, connected to this account: shown once a connector is given.
	_claude_box = VBoxContainer.new()
	_claude_box.add_theme_constant_override("separation", 6)
	_claude_box.visible = false
	column.add_child(_claude_box)
	_claude_box.add_child(HSeparator.new())
	var claude_title := Label.new()
	claude_title.text = "Claude"
	claude_title.add_theme_font_size_override("font_size", 14)
	_claude_box.add_child(claude_title)
	_claude_state = _line("", 12, 0.8)
	_claude_box.add_child(_claude_state)
	_claude_connect = Look.link("Connect Claude", 12)
	_claude_connect.tooltip_text = "Opens claude.ai with Brickworks filled in"
	_claude_connect.pressed.connect(func() -> void:
		if connector.connected():
			connector.open_in_claude()
			return
		connector.connect_claude()
		_claude_state.text = connector.connect_words())
	# One row, side by side: stacked, the link's tooltip opened over
	# Disconnect Claude below it and took the click meant for it.
	var claude_row := HBoxContainer.new()
	claude_row.add_theme_constant_override("separation", 14)
	_claude_box.add_child(claude_row)
	_claude_connect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claude_row.add_child(_claude_connect)
	_claude_disconnect = Button.new()
	_claude_disconnect.text = "Disconnect Claude"
	_claude_disconnect.focus_mode = Control.FOCUS_NONE
	_claude_disconnect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_claude_disconnect.tooltip_text = ("Claude can no longer reach your "
		+ "Brickworks, from any of its apps, until you connect it again.")
	_claude_disconnect.pressed.connect(func() -> void:
		var ended: int = await connector.disconnect_claude()
		if ended < 0:
			_claude_state.text = "Could not reach Brickworks to disconnect. Try again.")
	claude_row.add_child(_claude_disconnect)

	# What came into the feed since it was last opened, and the way to it.
	_feed_line = _line("", 12, 0.85)
	_feed_line.visible = false
	column.add_child(_feed_line)
	_feed_link = Look.link("Open your feed", 12)
	_feed_link.tooltip_text = ("New models from people you follow, and photos, comments "
		+ "and remixes of yours, on brickworks.diy")
	_feed_link.visible = false
	column.add_child(_feed_link)
	var every := Timer.new()
	every.wait_time = FEED_EVERY
	every.autostart = true
	every.timeout.connect(ask_feed)
	add_child(every)

	_admin = Look.link("Accounts and connectors (admin)", 12)
	_admin.uri = "/admin"
	column.add_child(_admin)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_sign_out = Button.new()
	_sign_out.text = "Sign out"
	_sign_out.custom_minimum_size = Vector2(0, 34)
	_sign_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_out.focus_mode = Control.FOCUS_NONE
	_sign_out.tooltip_text = ("Sign out of Brickworks on this device. Your "
		+ "models stay here. Claude stops building in this tab, and stays "
		+ "connected to your account until you disconnect it.")
	_sign_out.pressed.connect(func() -> void:
		visible = false
		sign_out_wanted.emit())
	row.add_child(_sign_out)
	_done = Button.new()
	_done.text = "Done"
	_done.custom_minimum_size = Vector2(0, 34)
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(func() -> void: visible = false)
	row.add_child(_done)

	account.changed.connect(_follow)
	_follow()
	minimum_size_changed.connect(_keep_centred)


## Taller than it was placed for (this tab's Claude chats, ClaudeTabView,
## with two chats listed), it grew downwards from where it was put, and its
## foot, Sign out and Done, ran off an 800-pixel window: centred on what it
## holds now, and no shorter than it was placed (main's _inset).
func _keep_centred() -> void:
	if not is_inside_tree():
		return
	var room: float = get_viewport().get_visible_rect().size.y - 48.0
	var tall: float = maxf(minf(TALL, room), get_combined_minimum_size().y)
	offset_top = -tall * 0.5
	offset_bottom = tall * 0.5


func open() -> void:
	_follow()
	_kept.text = StorageKeep.words()
	visible = not visible
	if visible and connector != null and account.signed_in():
		connector.refresh_connections()
	if visible:
		ask_feed(true)


## Ask how many things came into the feed since it was last opened, and
## say it. Not more than once in 20 seconds unless [now]; never as nobody.
func ask_feed(now: bool = false) -> void:
	if not account.signed_in():
		_show_feed(0)
		return
	var at: float = Time.get_ticks_msec() / 1000.0
	if _feed_asking or (not now and at - _feed_asked_at < 20.0):
		return
	_feed_asking = true
	_feed_asked_at = at
	var token: String = await account.access_token()
	if token.is_empty():
		_feed_asking = false
		_show_feed(0)
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + token])
	if http.request(Deployment.api_base() + "/api/people?op=feed_count", headers) != OK:
		http.queue_free()
		_feed_asking = false
		return
	var result: Array = await http.request_completed
	http.queue_free()
	_feed_asking = false
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return
	var said: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if said is Dictionary:
		_show_feed(int((said as Dictionary).get("count", 0)))


func _show_feed(count: int) -> void:
	feed_count = maxi(count, 0)
	var shown: String = "99+" if feed_count > 98 else str(feed_count)
	_feed_line.text = ("Nothing new in your feed." if feed_count == 0
		else "%s new in your feed since you last opened it." % shown)
	_feed_line.visible = account.signed_in()
	_feed_link.visible = account.signed_in()
	_feed_link.uri = (Origin.here() if OS.has_feature("web") else Deployment.api_base()) + "/feed"
	feed_counted.emit(feed_count)


## What it says of the feed, for probes and the browser flows.
func feed_words() -> String:
	return _feed_line.text if _feed_line != null and _feed_line.visible else ""


## Back to the front (another tab had the feed open, say): asked again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and account != null:
		ask_feed()


## Where the models are kept, as the browser says it now, for as long as the
## panel is open. It was read once as the panel opened, and the browser can
## answer after that: Firefox asks the person, and the read is up to 400 ms
## old (StorageKeep.state). Opened just as Chromium agreed, the panel said
## the browser had not answered, and went on saying it (keep_flow, 2026-10-14).
func _process(_delta: float) -> void:
	if not visible or _kept == null:
		return
	var now: String = StorageKeep.words()
	if _kept.text != now:
		_kept.text = now


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"sign_out": _sign_out, "account_done": _done}
	if _feed_link.is_visible_in_tree():
		named["account_feed"] = _feed_link
	if _claude_disconnect.is_visible_in_tree():
		named["account_disconnect_claude"] = _claude_disconnect
	if _claude_connect.is_visible_in_tree():
		named["account_connect_claude"] = _claude_connect
	if _tab_view != null:
		named.merge(_tab_view.controls_by_name())
	return named


## What it says about where the models are kept, as it says it now.
func storage_words() -> String:
	return _kept.text if _kept != null else ""


## Claude's half: the connector whose connections this shows, and this tab
## as Claude knows it, with the chats working in it (ClaudeTabView).
func use_connector(with: ClaudeConnector) -> void:
	connector = with
	_claude_box.visible = claude_shown
	_tab_view = ClaudeTabView.new()
	_tab_view.prefix = "account_"
	_claude_box.add_child(_tab_view)
	_claude_box.move_child(_tab_view, _claude_state.get_index() + 1)
	_tab_view.setup(connector)
	connector.connections_changed.connect(func(_now: Array) -> void: _show_claude())
	_show_claude()


var _tab_view: ClaudeTabView = null


## What this tab's Claude part says, for probes.
func tab_words() -> String:
	return _tab_view.words() if _tab_view != null and _tab_view.is_visible_in_tree() else ""


## Settings, Assistant (AI): off, nothing here speaks of Claude.
var claude_shown: bool = true


func show_claude(on: bool) -> void:
	claude_shown = on
	_claude_box.visible = on and connector != null
	_sign_out.tooltip_text = "Sign out of Brickworks on this device. Your models stay here." \
		+ (" Claude stops building in this tab, and stays connected to your account "
			+ "until you disconnect it." if on else "")


## Which of Claude's apps are connected to this account, since when and
## when last used; or that none is.
func _show_claude() -> void:
	if connector == null:
		return
	var lines := PackedStringArray()
	for one: Variant in connector.connections:
		var it: Dictionary = one
		var line: String = "%s, connected %s" % [str(it.get("client", "Claude")),
			when(str(it.get("since", "")))]
		if it.get("last_used") != null:
			line += ", last used %s" % when(str(it.get("last_used", "")))
		lines.append(line)
	if lines.is_empty() and connector.had_claude:
		_claude_state.text = ("Not connected now. Connect Claude takes you to the "
			+ "Brickworks you already have in Claude, to connect it again.")
	elif lines.is_empty():
		_claude_state.text = ("Not connected. Connect Claude once and it can "
			+ "build in any Brickworks tab you have open, on your Claude plan."
			if connector.connections_known else "Checking…")
	else:
		_claude_state.text = "Connected — Claude can build in your open Brickworks tabs.\n" \
			+ "\n".join(lines)
	# Always one click to Claude: Connect while it is not connected, and
	# while it is, Open in Claude for the connector's tools and permissions.
	_claude_connect.text = "Connect Claude" if lines.is_empty() else "Open in Claude"
	_claude_connect.tooltip_text = ("Opens your connectors in Claude, where Brickworks is"
		if connector.had_claude or not lines.is_empty()
		else "Opens claude.ai with Brickworks filled in")
	_claude_disconnect.visible = not lines.is_empty()


## An ISO time from the deployment, in words: "today at 14:05", or "11 Oct".
static func when(iso: String) -> String:
	if iso.length() < 19:
		return "just now"
	var utc: int = Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	var local: int = utc + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var then: Dictionary = Time.get_datetime_dict_from_unix_time(local)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	if then.year == now.year and then.month == now.month and then.day == now.day:
		return "today at %02d:%02d" % [then.hour, then.minute]
	var months: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s" % [then.day, months[int(then.month) - 1]]


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func _follow() -> void:
	if not account.signed_in():
		visible = false
	if _feed_line != null:
		if account.signed_in():
			ask_feed()
		elif feed_count != 0 or _feed_line.visible:
			_show_feed(0)
	_who.text = "Signed in as %s" % account.email if not account.email.is_empty() \
		else "Signed in"
	# Let in from what this device kept while it is renewed: what waits on
	# it says so (Account.renewing).
	_state.text = (Account.waiting_words("Saving to your account, sharing and Claude go on")
		if account.renewing
		else "Brickworks could not be reached just now, so this is "
		+ "the account kept on this device. It is checked again when "
		+ "Brickworks can be reached." if account.offline
		else "Signed in on this device until you sign out.")
	# The admin page is a page of the site, so only where the site is.
	_admin.visible = account.master and OS.has_feature("web")
	if _admin.visible:
		_admin.uri = Origin.here() + "/admin"


## Escape closes it, like the other panels.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
