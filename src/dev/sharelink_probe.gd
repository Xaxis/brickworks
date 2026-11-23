## Does Share a build, from the home page's feed (/app?share), open the
## share panel for the model the app came back with, and only once somebody
## is signed in?
##
##   godot --headless --path . --script src/dev/sharelink_probe.gd
##
## The home page's "Share a build" (homefeed, 2026-11-23; web/index.html
## #share-build) is /app?share, which the page's shell passes on as --share
## (main._share_asked). This probe never passes it: it sets what reading it
## sets, so the probe takes no app argument names. Then:
##
##   - signed out, nothing opens and the ask is kept for the sign-in;
##   - signed in (_on_account_changed), the panel opens, for the model on
##     the baseplate (its name in the panel's box), and the ask is spent;
##   - asked again (another account change, the first open done again),
##     the panel stays open: the panel's open() toggles, and a second call
##     would close it;
##   - with no ask, an account change opens nothing.
extends SceneTree

const NAME := "Sharelink Probe House"

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = _main.get("_store")
	store.keeps = true
	store.open("res://models/house.ldr")
	# Named as a person names it, in the header's name field: the field is
	# what the panel reads (main: share.named = _bar.model_name), and its
	# typing is what keeps the store's title. A title set on the store alone
	# never reaches the field, so the panel said the file's own "House".
	var bar: ModelBar = _main.get("_bar")
	var field: LineEdit = bar.get("_name")
	field.text = NAME
	field.text_changed.emit(NAME)
	_check("named in the header (%s), the store's title too (%s)" % [bar.model_name(), store.title],
		bar.model_name() == NAME and store.title == NAME)
	var account: Account = _main.get("_account")
	_check("the app has come up (its first open done)", bool(_main.get("_first_open_done")))
	_check("nothing asked for the share panel without ?share", not bool(_main.get("_share_asked")))

	# Signed out: kept for the sign-in.
	_main.set("_share_asked", true)
	account.state = Account.State.SIGNED_OUT
	_main.call("_on_account_changed")
	await process_frame
	_check("signed out, the share panel stays shut", not _panel_open())
	_check("signed out, the ask is kept for the sign-in", bool(_main.get("_share_asked")))

	# Signed in: open, for this model.
	account.state = Account.State.NOT_NEEDED
	_main.call("_on_account_changed")
	await process_frame
	_check("signed in, the share panel opens", _panel_open())
	_check("and the ask is spent", not bool(_main.get("_share_asked")))
	var panel: Node = _main.get("_share_panel_made")
	var named: String = ""
	if panel != null and panel.get("_name") is LineEdit:
		named = (panel.get("_name") as LineEdit).text
	_check("the panel is for the model on the baseplate (its name: %s)" % named, named == NAME)

	# Asked of the app again: the panel is not toggled shut.
	_main.call("_on_account_changed")
	_main.call("_maybe_share")
	await process_frame
	_check("another account change leaves the panel open", _panel_open())

	# Shut, and no ask: an account change opens nothing.
	panel.call("open")
	await process_frame
	_check("the panel shuts as it is pressed again", not _panel_open())
	_main.call("_on_account_changed")
	await process_frame
	_check("with no ask, an account change opens nothing", not _panel_open())

	print("sharelink: %s" % ("all ok" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _panel_open() -> bool:
	var panel: Control = _main.get("_share_panel_made")
	return panel != null and panel.visible


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
