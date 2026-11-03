## Help, Check for updates… and Reinstall Brickworks…: asked, and answered in
## a few words. "You're up to date (0.16.0)", or what is new in the version
## that is out with Update and restart; and Reinstall, this same version
## downloaded again to repair a broken install, said as it goes.
class_name UpdateDialog
extends ConfirmationDialog

var updater: Updater

## "check" or "reinstall": what was asked.
var _asking: String = ""
## Whether the reinstall was confirmed and is under way.
var _going: bool = false


func _ready() -> void:
	min_size = Vector2i(460, 0)
	dialog_autowrap = true
	dialog_hide_on_ok = false
	confirmed.connect(_confirmed)
	updater.changed.connect(_show)


## Help, Check for updates….
func check() -> void:
	_asking = "check"
	_going = false
	title = "Check for updates"
	popup_centered()
	updater.check()
	_show()


## Help, Reinstall Brickworks….
func ask_reinstall() -> void:
	_asking = "reinstall"
	_going = false
	title = "Reinstall Brickworks"
	popup_centered()
	_show()


func _confirmed() -> void:
	if _asking == "reinstall":
		_going = true
		await updater.reinstall()
		if updater.state == Updater.READY and visible:
			updater.restart("install")
		return
	if not updater.can_install():
		Outside.open_link(updater.download_link())
		hide()
		return
	updater.update_and_restart()


## What the updater says now, in the dialog.
func _show() -> void:
	if not visible:
		return
	var ok: Button = get_ok_button()
	var mine: String = BuildInfo.version()
	ok.visible = true
	ok.disabled = false
	get_cancel_button().text = "Cancel"
	if _asking == "reinstall" and not _going:
		dialog_text = ("Download Brickworks %s again and put it in place of this copy? "
			+ "This repairs a damaged install. Your models and settings are kept.") % mine
		if not updater.can_install():
			dialog_text = str(updater.install.get("why_not", ""))
			ok.visible = false
		ok.text = "Reinstall and restart"
		return
	match updater.state:
		Updater.CHECKING, Updater.RESTARTING:
			dialog_text = updater.said
			ok.disabled = true
		Updater.DOWNLOADING:
			dialog_text = updater.said if updater.total <= 0 else "%s %d%%" % [updater.said,
				roundi(100.0 * updater.received / maxf(1.0, updater.total))]
			ok.disabled = true
		Updater.OUT, Updater.READY:
			if _asking == "reinstall":
				dialog_text = updater.said
				ok.disabled = true
				return
			var found: Dictionary = updater.manifest
			var notes: String = Updates.whats_new(found, 600)
			dialog_text = "Brickworks %s is out. You have %s." % [str(found["version"]), mine]
			if not notes.is_empty():
				dialog_text += "\n\n" + notes
			ok.text = "Update and restart" if updater.can_install() else "Download"
			if updater.install.has("moves_to"):
				ok.text = "Move to Applications and update"
			get_cancel_button().text = "Later"
		_:
			dialog_text = updater.said
			ok.visible = false
			get_cancel_button().text = "OK"


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"update_dialog_ok": get_ok_button(), "update_dialog_cancel": get_cancel_button()}
