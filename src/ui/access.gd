## Every button within reach of the keys, and names a screen reader would
## otherwise be without, in the parts of the interface Godot builds itself.
##
## A button made with no focus (FOCUS_NONE, as most of the app's are, so a
## click did not leave the space bar on it) joins the keyboard's order as it
## is made (FocusGuard.by_keyboard): Tab and the arrows reach it, Return
## presses it, and a click still leaves the keys with the model. So every
## dialog's buttons and the sign-in screen's can be used without a mouse,
## whoever made them and whenever.
##
## Every control the app makes says its own name (accessibility_name, or its
## words), and one made without (a number, a slider, a choice, a field with
## no placeholder, a button drawn as a picture alone) is named here from the
## words beside it: the label that names it in its form, else its
## tooltip's first line, else the label before it in its row
## ([method name_from_words]). Godot says a name through the translation
## (get_accessibility_name is tr() of it), so one kept in English, as every
## control's words are, is said in German in German; a button's tooltip it
## would read as it is, in English whatever the language. My collection's
## How many came in with a tooltip alone (11-06), as a dozen numbers and
## sliders and some forty choices had.
##
## Godot's own file dialog, which the desktop shows to choose a picture, a
## model or a place to save, names all but a few of its parts: the two
## buttons that move a favourite folder up and down, which have only an
## arrow, the bars between its panes, and the choice of the kind of file
## beside the file's name. They are named here as each dialog is made,
## whoever makes it.
class_name Access
extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	# And those made before this was.
	_reach_all.call_deferred(get_tree().root)


static func _reach_all(node: Node) -> void:
	for child: Node in node.get_children(true):
		if child is BaseButton:
			_within_reach(child)
		if child is Control:
			name_from_words(child)
		_reach_all(child)


func _on_added(node: Node) -> void:
	if node is FileDialog:
		_name_dialog.call_deferred(node)
	elif node is BaseButton:
		_within_reach.call_deferred(node)
	if node is Control and _named_kind(node):
		# After whoever made it has set it up: its tooltip and its label are
		# set once it was added, in the same call.
		name_from_words.call_deferred(node)


## After whoever made it has set it up: a focus set once it was added counts.
static func _within_reach(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.has_meta(FocusGuard.BY_KEYBOARD) \
			and button.focus_mode in [Control.FOCUS_NONE, Control.FOCUS_ACCESSIBILITY]:
		FocusGuard.by_keyboard(button)


static func _name_dialog(dialog: FileDialog) -> void:
	if not is_instance_valid(dialog):
		return
	var arrows: Array[String] = ["Move the favourite up", "Move the favourite down"]
	for part: Node in _all_under(dialog):
		var control: Control = part as Control
		if control == null or not control.accessibility_name.is_empty():
			continue
		if control.get_class() == "SplitContainerDragger":
			control.accessibility_name = "Drag to share the room between the panes"
		elif control is OptionButton:
			control.accessibility_name = "Kind of file"
		elif control is Button and (control as Button).text.is_empty() \
				and control.tooltip_text.is_empty() and not arrows.is_empty():
			control.accessibility_name = arrows.pop_front()


static func _all_under(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children(true):
		out.append(child)
		out.append_array(_all_under(child))
	return out


## Marks a name given here, from the words beside the control: [the words,
## where they came from ("tooltip" or "label")]. Given again when the keys
## come to it, as those words may have changed since (a button's tooltip
## that says what a press does now), unless whoever made it has named it
## since. What's This? reads a name from the tooltip as no name of its own,
## as before it was given ([method from_tooltip]).
const NAMED_BESIDE := &"named_beside"
## Marks a control whose focus is heard here.
const WATCHED := &"access_watched"
## The longest label that is a field's name: longer is a sentence about it.
const LABEL_LONGEST := 48
## A word: two letters or more.
static var _word := RegEx.create_from_string(r"\p{L}{2,}")


## [param control], where it is one a person sets or presses and has no
## name of its own, named from the words beside it ([method words_beside]).
## A name given since, by whoever made it, is theirs and stays.
static func name_from_words(control: Control) -> void:
	if not is_instance_valid(control) or not _wants_name(control):
		return
	_watch(control)
	var found: Array = _words_and_where(control)
	if str(found[0]).is_empty():
		return
	control.accessibility_name = found[0]
	control.set_meta(NAMED_BESIDE, found)


## Whether [param control]'s name is one given here from its tooltip, and
## still is.
static func from_tooltip(control: Control) -> bool:
	return _still_ours(control) and str((control.get_meta(NAMED_BESIDE) as Array)[1]) == "tooltip"


## Whether the name given here is still the control's: the property says it
## through tr(), as the words kept are said.
static func _still_ours(control: Control) -> bool:
	if not control.has_meta(NAMED_BESIDE):
		return false
	var given: Array = control.get_meta(NAMED_BESIDE)
	return control.accessibility_name == control.tr(str(given[0]))


## When the keys come to it, named again if the name was given here (the
## setter keeps the same words as they are), or for the first time if
## what it needed was set after it was made.
static func _watch(control: Control) -> void:
	if control.has_meta(WATCHED):
		return
	control.set_meta(WATCHED, true)
	control.focus_entered.connect(_on_focus.bind(control))


static func _on_focus(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if _still_ours(control):
		var found: Array = _words_and_where(control)
		if not str(found[0]).is_empty():
			control.accessibility_name = found[0]
			control.set_meta(NAMED_BESIDE, found)
		return
	control.remove_meta(NAMED_BESIDE)
	name_from_words(control)


## The kinds named here: a number, a slider, a choice, words typed, a list
## or a tree, and a button with no words of its own (a picture, a box to
## tick with its words beside it, a menu's button drawn as a picture).
static func _named_kind(control: Control) -> bool:
	if control is LineEdit and control.get_parent() is SpinBox:
		return false
	return control is SpinBox or control is Slider or control is BaseButton \
		or control is LineEdit or control is TextEdit or control is ItemList \
		or control is Tree


## Whether [param control] is a kind named here and says nothing yet: no
## name given, none from a label (accessibility_labeled_by_nodes), and for
## a button no words, for a field no placeholder (which Godot says). A
## choice's words are what is chosen, not what it chooses, so it is named
## whatever it shows.
static func _wants_name(control: Control) -> bool:
	if not _named_kind(control):
		return false
	if not control.accessibility_name.is_empty() \
			or not control.accessibility_labeled_by_nodes.is_empty():
		return false
	if control is OptionButton:
		return true
	if control is Button:
		return (control as Button).text.strip_edges().is_empty()
	if control is LinkButton:
		return (control as LinkButton).text.strip_edges().is_empty()
	if control is LineEdit:
		return (control as LineEdit).placeholder_text.strip_edges().is_empty()
	if control is TextEdit:
		return (control as TextEdit).placeholder_text.strip_edges().is_empty()
	return true


## What [param control] is called, from the words beside it, in English.
## A button's is its tooltip's first line (the rest is help): what a press
## does. The others' is the label that names it in its form, as a person
## reads the form (the label before it in a grid or a column, or first in
## its row, or ending in a colon: "Samples", "Studs across:"); else its
## tooltip's first line; else the label just before it in its row. "" when
## there are none.
static func words_beside(control: Control) -> String:
	return _words_and_where(control)[0]


static func _words_and_where(control: Control) -> Array:
	var tip: String = control.tooltip_text.strip_edges().get_slice("\n", 0).strip_edges()
	if control is BaseButton and not control is OptionButton:
		return [tip, "tooltip"]
	var before: Label = _label_before(control)
	if before == null and control.get_parent() is BoxContainer \
			and control.get_parent().get_child_count() <= 2:
		# A slider and the number beside it, in a row of their own under the
		# form's label.
		before = _label_before(control.get_parent() as Control)
	if before != null and _names_a_field(before):
		return [before.text.strip_edges(), "label"]
	if not tip.is_empty():
		return [tip, "tooltip"]
	return [before.text.strip_edges(), "label"] if before != null else ["", ""]


## The label just before [param control] among its parent's children, with
## words, short and on one line; null when the one before is not that.
static func _label_before(control: Control) -> Label:
	var parent: Node = control.get_parent()
	if parent == null or control.get_index() == 0:
		return null
	var before: Label = parent.get_child(control.get_index() - 1) as Label
	if before == null:
		return null
	var words: String = before.text.strip_edges()
	if words.is_empty() or "\n" in words or words.length() > LABEL_LONGEST \
			or _word.search(words) == null:
		return null
	return before


## Whether [param label], the one before a control, is its field's name
## rather than a word of a row (a part's name, its colour): it is a grid's
## or a column's cell before it, first in its row, or ends in a colon.
static func _names_a_field(label: Label) -> bool:
	var parent: Node = label.get_parent()
	return parent is GridContainer or parent is VBoxContainer or label.get_index() == 0 \
		or label.text.strip_edges().ends_with(":")
