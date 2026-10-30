## How the window was laid out last time: which panels were open, how
## tall the model tree and the properties were in their column, which
## column a narrow window showed, whether the key strip and the grid were
## showing, the snap and the turn step — and the floor a new model starts
## on, which is a preference of the person's rather than of any model.
##
## Kept on this machine, like ViewPrefs, and for the same reason: a layout
## is a fact about the screen in front of you. A probe neither reads nor
## writes it, so every check starts from the layout a first visit gets and
## nobody's own layout is touched by one.
class_name ShellPrefs
extends RefCounted

const WHERE := "user://shell.cfg"

## Every setting and what a first visit gets.
const DEFAULTS: Dictionary = {
	"parts_open": true,
	# Folded to its rail until asked for: a first visit opens on the CAD
	# itself, the parts bin and the model.
	"assistant_open": false,
	"inspector_open": true,
	# Folded to its header under the parts bin: a model with no
	# sub-assemblies has one row in it, and the properties use the room.
	"outliner_open": false,
	# The model tree's and the properties' heights in the left-hand
	# column (PanelStack); the parts bin has what is left.
	"tree_height": 210.0,
	"properties_height": 230.0,
	# In a window with room for one column beside the model, the one
	# showing: "parts" (the bin, the tree and the properties), "assistant",
	# or "" for neither (Main._fit_panels). A first visit gets the parts:
	# Brickworks is a CAD first, and the assistant one choice in it.
	"narrow_side": "parts",
	# Settings, Assistant (AI): "on", "off", or "" until somebody chooses
	# ([method assistant_shown]).
	"assistant": "",
	# Whether the first visit's one line offering the assistant has been
	# shown (Main._offer_assistant): once, and never again.
	"assistant_offered": false,
	# Whether the warning that this browser may clear the person's models
	# has been shown (StorageOffer): once on a device, and never again.
	"storage_warned": false,
	# Whether finding a part from a photo has said, once, that the photo goes
	# to Brickognize, a third party (PartsBin._ask_photo).
	"photo_told": false,
	"key_strip": true,
	"grid": false,
	"snap": "stud",
	"turn_step": 90.0,
	# What a new model stands on (ModelFloor, Settings): the words after
	# FLOOR in its meta line. The dark green 32 x 32 every model had
	# before there was a choice.
	"new_floor": "BASEPLATE 32 32 288",
	# The folder the last export or Save as went to on the desktop, where
	# the next one's dialog opens (SaveTo): "" for Documents.
	"save_folder": "",
	# The folder the last file of each kind ("picture", "model", "mesh",
	# "list") was chosen from on the desktop, where the next chooser of
	# that kind opens (OpenFrom).
	"open_folders": {},
	# Settings, Interface size: how much bigger or smaller than the window
	# would draw it the interface is, 0.85 to 1.5 (Main._match_screen_density).
	"interface_size": 1.0,
	# Settings, Reduce motion: no model going up brick by brick, no light
	# crossing a waiting picture, and the view goes where it is sent at once.
	"reduce_motion": false,
	# The commands last run from Find a command (CommandPalette), the latest
	# first: they come first there.
	"palette_recent": [],
}

## Settings, Interface size: the choices, as shares of the size the window
## would draw it at.
const INTERFACE_SIZES: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5]

static var _values: Dictionary = {}
static var _loaded: bool = false


## Set for a model shared by link and opened to look at: the viewer's
## layout is its own, and the visitor's is neither read nor written.
static var frozen: bool = false


## False under --script, so a probe changes nothing on disk.
static func keeps() -> bool:
	return not frozen and not OS.get_cmdline_args().has("--script")


## Whether the assistant is in the window at all (Settings, Assistant
## (AI)). Off, nothing of AI is anywhere in it: no column, no Ask Claude,
## no Design with Claude, no connector, no word of it in the tour or the
## help (a builder on Reddit, 2026-10-13: "a LOT of us… building freely and
## building things that are not AI designed").
##
## Until somebody chooses, a first visit builds by hand, and a device that
## has used Claude here keeps it as it had it: its key, its connector or
## its choice of model are kept on it. A probe is a first visit.
static func assistant_shown() -> bool:
	var chosen: String = str(value("assistant"))
	if chosen.is_empty():
		return keeps() and used_claude_here()
	return chosen == "on"


## Settings, Interface size, as a factor: one of [constant INTERFACE_SIZES].
static func interface_size() -> float:
	return clampf(float(value("interface_size")), INTERFACE_SIZES[0], INTERFACE_SIZES[-1])


## Settings, Reduce motion: whatever moves by itself keeps still.
static func reduce_motion() -> bool:
	return bool(value("reduce_motion"))


static func used_claude_here() -> bool:
	for kept: String in [OwnKey.WHERE, ClaudeConnector.where, Brain.where]:
		if FileAccess.file_exists(kept):
			return true
	return false


static func value(name: String) -> Variant:
	_load()
	return _values.get(name, DEFAULTS.get(name))


## Set one, and write the lot.
static func put(name: String, to: Variant) -> void:
	_load()
	if _values.get(name) == to:
		return
	_values[name] = to
	if not keeps():
		return
	var file := ConfigFile.new()
	for key: String in _values:
		file.set_value("shell", key, _values[key])
	file.save(WHERE)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	if not keeps():
		return
	var file := ConfigFile.new()
	if file.load(WHERE) != OK:
		return
	for key: String in DEFAULTS:
		var kept: Variant = file.get_value("shell", key, DEFAULTS[key])
		# Only a value of the kind expected: a file edited by hand, or
		# written by a later version, must not break the layout.
		if typeof(kept) == typeof(DEFAULTS[key]) \
				or (DEFAULTS[key] is float and kept is int):
			_values[key] = kept
