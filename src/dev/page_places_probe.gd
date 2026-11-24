## The page is told where a control is only where it is drawn.
##
##   godot --headless --path . --script src/dev/page_places_probe.gd
##
## Browser checks press the app's controls where the app says they are
## (window.brickworksControls, Main._tell_page). The warning that the browser
## may clear the models is offered in the same frame the page is told, every
## second, and a control shown this frame is not laid out until the frame
## ends. So its Download my models was told at its place before layout, 440
## px from where it is drawn, for half a second, and keep_flow pressed
## nothing there: on 480b81a and on 9aba2b9 alike, about one run in two.
## Here the warning is shown, the page's places are worked out in that frame
## as Main works them out, and again once it is laid out.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var offer: StorageOffer = main.get("_storage_offer")
	var to_window: Transform2D = main.get_viewport().get_final_transform()
	# Told once before, with the warning not up.
	offer.visible = false
	await _frames(3)
	main.call("_page_places", main.call("_page_controls"), to_window, 1.0)

	print("\nthe warning shown, and the page told in the same frame")
	StorageKeep.pretend({"asked": true, "answered": true, "kept": false})
	ShellPrefs.put("storage_warned", false)
	_check("the warning is offered", offer.offer_if_due(true))
	var button: Button = offer.controls_by_name().get("storage_download_all")
	var unsorted: Vector2 = to_window * button.get_global_rect().get_center()
	var first: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	# Left out for having come, it is owed a telling soon, not two seconds
	# on (Main._tell_page): account and oauth read nothing there for two
	# seconds (nightly 2026-11-24).
	_check("...left out as it came, the next telling is owed now, not at rest's two seconds",
		bool(main.get("_places_unsettled")))
	await _frames(3)
	var drawn: Vector2 = to_window * button.get_global_rect().get_center()
	var drawn_at: Dictionary = {"x": roundi(drawn.x), "y": roundi(drawn.y)}
	_check("in that frame Download my models is not yet where it is drawn: at %s, drawn at %s"
		% [unsorted.round(), drawn.round()], unsorted.round() != drawn.round())
	var told: Variant = first.get("storage_download_all")
	_check("...and the page is told no place it is not drawn at: told %s" % str(told),
		told == null or _at(told) == drawn_at)
	var second: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	told = second.get("storage_download_all")
	_check("laid out, the page is told no other place: told %s" % str(told),
		told == null or _at(told) == drawn_at)
	var third: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	_check("...and once it has stayed there, it is told where it is drawn: %s"
		% str(third.get("storage_download_all")), third.get("storage_download_all") != null
		and _at(third["storage_download_all"]) == drawn_at)
	_check("...and with every control told where it stood, nothing more is owed",
		not bool(main.get("_places_unsettled")) and int(main.get("_places_settling")) == 0)

	print("\nput away, it is gone at once")
	offer.visible = false
	var fourth: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	_check("Got it, and the page is told no Download my models", not fourth.has("storage_download_all"))
	_check("...and the controls that stayed put are still told: Save at %s" % str(fourth.get("save")),
		fourth.has("save"))

	# A control a list cuts off is told so, with the part of the list that
	# shows: a check turns the wheel there (tools/web/browser.mjs intoSight),
	# where the Share form's foot covered every place beside List it in the
	# gallery (share_flow, nightreds 2026-11-24).
	print("\na control under a list's foot")
	var holder := Control.new()
	main.add_child(holder)
	holder.position = Vector2(40, 60)
	var scroller := ScrollContainer.new()
	scroller.position = Vector2(0, 0)
	scroller.size = Vector2(200, 100)
	holder.add_child(scroller)
	var rows := VBoxContainer.new()
	scroller.add_child(rows)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(180, 140)
	rows.add_child(spacer)
	var under := Button.new()
	under.text = "under the foot"
	rows.add_child(under)
	await _frames(3)
	var named: Dictionary = {"under_the_foot": under}
	main.call("_page_places", named, to_window, 1.0)
	var cut: Dictionary = main.call("_page_places", named, to_window, 1.0)
	var at_cut: Dictionary = cut.get("under_the_foot", {})
	var list_shown: Rect2 = to_window * scroller.get_global_rect()
	var list_told: Dictionary = at_cut.get("list", {})
	_check("told cut off, with the list's part that shows: %s" % str(at_cut),
		bool(at_cut.get("clipped", false)) and list_told.get("x") == roundi(list_shown.get_center().x)
		and list_told.get("y") == roundi(list_shown.get_center().y)
		and list_told.get("w") == roundi(list_shown.size.x) and list_told.get("h") == roundi(list_shown.size.y))
	scroller.scroll_vertical = 1000
	await _frames(3)
	main.call("_page_places", named, to_window, 1.0)
	var whole: Dictionary = main.call("_page_places", named, to_window, 1.0).get("under_the_foot", {})
	_check("...and scrolled to it, told whole, with no list: %s" % str(whole),
		not whole.is_empty() and not whole.has("clipped") and not whole.has("list"))
	holder.queue_free()

	StorageKeep.pretend({})
	print("")
	if _failures == 0:
		print("the page is told where a control is only where it is drawn")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


## Where a control is told to be, its middle: the page is told its size
## too (w, h), which the place does not depend on.
static func _at(told: Variant) -> Dictionary:
	var place: Dictionary = told
	return {"x": place.get("x"), "y": place.get("y")}
