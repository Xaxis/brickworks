## Does the parts bin's Fits list what goes on the selected part?
##
##   godot --headless --path . --script src/dev/fits_probe.gd
##
## Nothing in the bin answered "what goes on this?" (appux371 B5, 2026-10-30):
## a person who knew a beam takes a pin found one by its name. Fits lists the
## parts that fit the selected part, or the one in hand. Twelve pairs a
## builder knows, written before the change and not tuned on it: a beam and
## its pin, a pin and a beam, an axle and what it goes through, a gear and
## its axle, a clip and a bar, a bar and a clip, a jumper and the 1 x 1 round
## on it, a click hinge's two halves, a ball and its socket, a hinge's base
## and its top, a turntable's, and a Technic brick and its pin. Each must
## have a part that fits among the first five tiles, chosen as a person
## chooses it: a part selected in the model, then the Fits chip. And the
## part in hand when nothing is selected; a part taken from the list does
## not change it; what is typed narrows it; and with nothing to fit it says
## what to do.
extends SceneTree

## [the part selected, the parts any one of which fits it, what it is].
const PAIRS: Array = [
	["32316", ["2780", "6558", "43093", "4274", "3673"], "a beam takes a pin"],
	["2780", ["3700", "32316", "32524", "6536", "3701", "32523", "40490", "32526"],
		"a pin goes in a beam or a Technic brick"],
	["3705", ["3713", "32123b", "6536", "3648b", "59443", "32039", "32054"],
		"an axle goes through a bush or a cross block"],
	["3648b", ["3705", "3706", "4519", "32062", "3707", "3708", "44294", "6587"],
		"a gear goes on an axle"],
	["63868", ["87994", "30374", "63965a", "2540", "48336", "60478", "3839b"],
		"a clip holds a bar"],
	["87994", ["63868", "61252", "60470b", "4085c", "15712", "60897", "11476"],
		"a bar goes in a clip"],
	["15573", ["6141", "98138", "3062b"], "a 1 x 1 round on a jumper"],
	["44301b", ["44302a", "44302b"], "a click hinge's finger in its fork"],
	["14417", ["14704", "14418", "14419"], "a ball in its socket"],
	["3937", ["3938"], "a hinge's top on its base"],
	["3680", ["3679"], "a turntable's top on its base"],
	["3700", ["2780", "6558", "43093", "4274", "3673"], "a Technic brick takes a pin"],
]
## How long the first answer may take, over the whole catalogue.
const SLOW_MS := 1000.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var bin := PartsBin.new()
	bin.library = library
	get_root().add_child(bin)
	await process_frame
	bin.populate()
	var status: Label = bin.get("_status")

	bin.show_category(PartsBin.FITS)
	_check("with nothing selected or in hand, Fits says what to do: \"%s\"" % status.text,
		bin.first_found(1).is_empty() and status.text.begins_with("Select a part"))

	print("")
	print("  a part selected in the model, then Fits")
	var within: int = 0
	var slowest: float = 0.0
	for pair: Array in PAIRS:
		var part: String = pair[0]
		var wanted: Array = pair[1]
		var started: int = Time.get_ticks_usec()
		bin.show_selection(PackedStringArray([part]), PackedInt32Array([4]))
		var took: float = float(Time.get_ticks_usec() - started) / 1000.0
		slowest = maxf(slowest, took)
		var tiles: PackedStringArray = bin.first_found(5)
		var at: int = -1
		for n: int in tiles.size():
			if wanted.has(tiles[n]):
				at = n
				break
		if at >= 0:
			within += 1
		print("  %s  %-7s %-46s first five %s%s  (%.0f ms)" % ["ok  " if at >= 0 else "FAIL",
			part, pair[2], ", ".join(tiles), "" if at >= 0 else
			"  wanted one of %s" % ", ".join(PackedStringArray(wanted)), took])
		bin.show_selection(PackedStringArray(), PackedInt32Array())
	_failures += PAIRS.size() - within
	print("  %d of %d pairs with a part that fits in the first five; the slowest answer %.0f ms"
		% [within, PAIRS.size(), slowest])
	_check("each answer under %d ms over %d parts (%.0f)" % [roundi(SLOW_MS), library.parts.size(),
		slowest], slowest < SLOW_MS)

	print("")
	print("  the status line, and what is typed")
	bin.show_selection(PackedStringArray(["32316"]), PackedInt32Array([4]))
	_check("it names what it lists the fits of: \"%s\"" % status.text,
		status.text.contains("Technic Beam 5"))
	bin._run_search("axle")
	var typed: PackedStringArray = bin.first_found(3)
	_check("\"axle\" typed narrows it to the axles that fit the beam: %s" % ", ".join(typed),
		not typed.is_empty() and Array(typed).all(func(id: String) -> bool:
			return library.parts[id].name.to_lower().contains("axle")))
	bin._run_search("")
	bin.show_selection(PackedStringArray(), PackedInt32Array())

	print("")
	print("  the part in hand")
	bin.show_category("All")
	bin.show_held("3700", 4)
	bin.show_category(PartsBin.FITS)
	var held: PackedStringArray = bin.first_found(5)
	_check("with nothing selected, Fits is what fits the part in hand, 3700: %s" % ", ".join(held),
		held.has("2780"))
	# A part taken from the list is in hand, and the list stays the beam's.
	bin.show_held("2780", 4)
	bin._run_search("")
	_check("taking 2780 from it leaves the list on 3700: %s" % ", ".join(bin.first_found(5)),
		bin.first_found(5) == held)

	bin.queue_free()
	print("")
	print("fits lists what goes on a part" if _failures == 0 else "%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
