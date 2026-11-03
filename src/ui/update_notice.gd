## "Brickworks 0.17.0 is ready", above the model, with What's new, Update
## and restart, and Later: the desktop app's word that a newer version is
## out (Updater), in the look of the web app's "Brickworks has been
## updated" (UpdateOffer).
##
## Quiet: nothing moves and nothing is asked until a person presses. In
## Settings, Updates, Automatic the version is already downloaded by the
## time this shows, and goes in as the app quits if Later is pressed; in
## Ask first it is downloaded on the press. Where this copy cannot update
## itself, the press is Download: the new .deb for a copy installed from
## one, the download page for one installed where it may not write. On a
## Mac run from Downloads, it moves the app to Applications as it updates it.
class_name UpdateNotice
extends PanelContainer

var updater: Updater

var _words: Label
var _new: LinkButton
var _go: Button
var _later: Button
var _notes: Label
var _notes_link: LinkButton
var _notes_row: HBoxContainer
## The version Later was pressed for: not shown again this run.
var _put_off: String = ""
## Whether Update and restart was pressed here: its download is shown.
var _going: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 6
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_words = Label.new()
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)
	_new = Look.link("What's new", 13)
	_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_new.tooltip_text = "What this version changes, from its release notes"
	_new.pressed.connect(func() -> void: _notes_row.visible = not _notes_row.visible)
	row.add_child(_new)
	_go = ReloadOffer.button("Update and restart", true)
	_go.pressed.connect(_pressed)
	row.add_child(_go)
	_later = ReloadOffer.button("Later", false)
	_later.tooltip_text = "Not now. In Automatic, it goes in as Brickworks quits."
	_later.pressed.connect(later)
	row.add_child(_later)

	_notes_row = HBoxContainer.new()
	_notes_row.add_theme_constant_override("separation", 10)
	_notes_row.visible = false
	column.add_child(_notes_row)
	_notes = Label.new()
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.custom_minimum_size = Vector2(360, 0)
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.add_theme_font_size_override("font_size", 12)
	_notes.add_theme_color_override("font_color", Color(0.78, 0.81, 0.88))
	# The release's own words, as they were written.
	_notes.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_notes_row.add_child(_notes)
	_notes_link = Look.link("Release notes", 12)
	_notes_link.size_flags_vertical = Control.SIZE_SHRINK_END
	_notes_link.pressed.connect(func() -> void:
		Outside.open_link(str(updater.manifest.get("page", Updates.DOWNLOAD))))
	_notes_row.add_child(_notes_link)
	if updater != null:
		updater.changed.connect(_show)
		_show()


## What the updater found, shown or put away.
func _show() -> void:
	var found: Dictionary = updater.manifest
	var version: String = str(found.get("version", ""))
	var shown: bool = not version.is_empty() and version != _put_off and not updater.reinstalling \
		and updater.state in [Updater.OUT, Updater.DOWNLOADING, Updater.READY, Updater.FAILED] \
		and Updates.compare(version, BuildInfo.version()) > 0
	# Ask first says a version is out; Automatic downloads it unseen and says
	# it once it is ready; Off only once asked (Help).
	if updater.state in [Updater.OUT, Updater.DOWNLOADING] and Updater.mode() == "auto" \
			and updater.can_install() and not _going:
		shown = false
	if not shown:
		visible = false
		return
	_notes.text = Updates.whats_new(found)
	_new.visible = not _notes.text.is_empty()
	_go.disabled = false
	match updater.state:
		Updater.DOWNLOADING:
			_words.text = updater.said if updater.total <= 0 else "%s %d%%" % [
				updater.said, roundi(100.0 * updater.received / maxf(1.0, updater.total))]
			_go.disabled = true
		Updater.READY:
			_words.text = "Brickworks %s is ready" % version
		Updater.FAILED:
			_words.text = updater.said
		_:
			_words.text = "Brickworks %s is out" % version
	if not updater.can_install():
		_go.text = "Download"
		_go.tooltip_text = str(updater.install.get("why_not", ""))
	elif updater.install.has("moves_to"):
		_go.text = "Move to Applications and update"
		_go.tooltip_text = "Brickworks is running from Downloads or a disk image, where it can't update itself: it goes to %s" % str(updater.install["moves_to"]).get_base_dir()
	else:
		_go.text = "Update and restart"
		_go.tooltip_text = "Restart into Brickworks %s now. The model on the baseplate comes back as it is." % version
	visible = true


func _pressed() -> void:
	if not updater.can_install():
		Outside.open_link(updater.download_link())
		return
	_going = true
	await updater.update_and_restart()
	_going = false


## Later: put away until the app starts again.
func later() -> void:
	_put_off = str(updater.manifest.get("version", ""))
	visible = false


func showing() -> bool:
	return visible


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"update_restart": _go, "update_later": _later, "update_whats_new": _new}
