## At a sign-in, the collection this device kept while nobody was signed in,
## offered to the account (localbricks, APP_UX6 #8, 2026-11-07).
##
## Asked first, never done unasked: what is on this device and what the
## account has, side by side, and what putting them together does (every lot
## and set of both kept; a part's counts in one colour added together; a set
## in both, two copies, each with what it is missing). Put them together
## sends it as one change (CollectionStore.join) and says what came of it
## here; Not now leaves it on this device, apart, and it is not asked again
## at a sign-in until it changes (My collection still offers it).
##
## Made by the window's store the first time it is wanted, so the web loads
## none of it until a person has something to put together.
class_name CollectionOffer
extends ConfirmationDialog

var store: CollectionStore
## "asking", "sending", or "told" (what came of it, with Done).
var state: String = "asking"
## What came of the last answer, in words: empty until one is given.
var told: String = ""


func _ready() -> void:
	title = "Your bricks on this device"
	dialog_autowrap = true
	dialog_hide_on_ok = false
	min_size = Vector2i(480, 0)
	confirmed.connect(_on_ok)
	canceled.connect(_on_not_now)


## Show what this device keeps beside what the account has, and ask.
func ask() -> void:
	var what: Dictionary = store.offer_now()
	if (what["sets"] as Array).is_empty() and (what["parts"] as Array).is_empty():
		hide()
		return
	state = "asking"
	told = ""
	dialog_text = ("While nobody was signed in, this device kept %s. Your account's collection has %s. Put them "
		+ "together?\n\nEvery lot and set of both is kept: a part's counts in the same colour are added together, "
		+ "and a set kept in both is two copies, each with what it is missing. Not now leaves them on this device, "
		+ "apart from your account.") % [amount(what), amount(store.collection.to_json())]
	ok_button_text = "Put them together"
	cancel_button_text = "Not now"
	get_cancel_button().visible = true
	get_ok_button().disabled = false
	popup_centered(Vector2i(maxi(480, min_size.x), 0))


## A collection's sets and loose lots, in words: "2 sets and 12 lots of loose
## parts (31 pieces)", its minifigures too when it has some, or "nothing
## yet". One pattern a shape, so each language says it whole.
static func amount(kept: Dictionary) -> String:
	var sets: int = 0
	var figs: int = 0
	for entry: Dictionary in kept.get("sets", []):
		if Collection.is_fig(entry):
			figs += int(entry.get("qty", 1))
		else:
			sets += int(entry.get("qty", 1))
	var pieces: int = 0
	for lot: Dictionary in kept.get("parts", []):
		pieces += int(lot.get("qty", 0))
	var lots: int = (kept.get("parts", []) as Array).size()
	if sets + figs + lots == 0:
		return "nothing yet"
	if figs > 0:
		return "%s, %s and %s of loose parts (%s)" % [Counted.of(sets, "set"), Counted.of(figs, "minifigure"),
			Counted.of(lots, "lot"), Counted.of(pieces, "piece")]
	return "%s and %s of loose parts (%s)" % [Counted.of(sets, "set"), Counted.of(lots, "lot"),
		Counted.of(pieces, "piece")]


func _on_ok() -> void:
	if state == "told":
		hide()
		return
	if state == "sending":
		return
	state = "sending"
	get_ok_button().disabled = true
	get_cancel_button().visible = false
	dialog_text = "Putting them together…"
	_fit()
	var done: Dictionary = await store.join()
	var joined: Dictionary = (done.get("body", {}) as Dictionary).get("done", {}).get("joined", {}) \
		if (done.get("body", {}) as Dictionary).get("done") is Dictionary else {}
	if done["kind"] == CollectionStore.DONE:
		told = "Put together: your account's collection has %s now, nothing of either left out." \
			% amount(store.collection.to_json())
		var held: String = CollectionStore.clamped_words(done["body"])
		if not held.is_empty():
			told += " " + held[0].to_upper() + held.substr(1) + "."
		state = "told"
		dialog_text = told
		ok_button_text = "Done"
		get_ok_button().disabled = false
		get_cancel_button().visible = false
		_fit()
		return
	if done["kind"] == CollectionStore.UNREACHED:
		told = ("No answer came, so they may be in your collection already. They stay on this device, and are "
			+ "sent again, never added twice, when you next sign in or open My collection.")
	else:
		told = "%s. Nothing was lost: they are on this device still." % str(done["said"]).rstrip(".")
	if joined.is_empty() and done["kind"] != CollectionStore.UNREACHED:
		state = "asking"
		dialog_text = told
		ok_button_text = "Try again"
		cancel_button_text = "Not now"
		get_ok_button().disabled = false
		get_cancel_button().visible = true
		_fit()
		return
	state = "told"
	dialog_text = told
	ok_button_text = "Done"
	get_ok_button().disabled = false
	_fit()


func _on_not_now() -> void:
	if state == "sending":
		return
	if state == "asking":
		store.decline()
		told = "They stay on this device, apart from your account: My collection offers them again."
	state = "asking"


## As tall as what it says now, in the middle of the window again: an answer
## shorter than the question leaves no empty space under it.
func _fit() -> void:
	reset_size()
	move_to_center()
