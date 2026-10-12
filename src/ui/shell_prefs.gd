## How the window was laid out last time: which panels were open, how
## tall the model tree and the properties were in their column, which
## column a narrow window showed, whether the key strip and the grid were
## showing, the snap and the turn step.
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
	"assistant_open": true,
	"inspector_open": true,
	# Folded to its header under the parts bin: a model with no
	# sub-assemblies has one row in it, and the properties use the room.
	"outliner_open": false,
	# The model tree's and the properties' heights in the left-hand
	# column (PanelStack); the parts bin has what is left.
	"tree_height": 170.0,
	"properties_height": 230.0,
	# In a window with room for one column beside the model, the one
	# showing: "parts" (the bin, the tree and the properties), "assistant",
	# or "" for neither (Main._fit_panels). A first visit gets the
	# assistant: designing with Claude is what the landing page sends
	# people in to do, and folded to a rail a newcomer may never find it.
	"narrow_side": "assistant",
	"key_strip": true,
	"grid": false,
	"snap": "stud",
	"turn_step": 90.0,
}

static var _values: Dictionary = {}
static var _loaded: bool = false


## Set for a model shared by link and opened to look at: the viewer's
## layout is its own, and the visitor's is neither read nor written.
static var frozen: bool = false


## False under --script, so a probe changes nothing on disk.
static func keeps() -> bool:
	return not frozen and not OS.get_cmdline_args().has("--script")


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
