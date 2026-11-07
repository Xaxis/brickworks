## A model's parts list in the forms the shops read: a BrickLink wanted
## list, a Rebrickable parts list, and a LEGO® Pick a Brick list.
##
## Building by hand ends at a table with the bricks on it. The app's own
## CSV carries element numbers and every colour name, which a person can
## read and a shop cannot: BrickLink's wanted lists take an XML of its own
## item and colour numbers, Rebrickable's import takes three columns, and
## LEGO's own Pick a Brick takes element numbers and quantities. Studio
## exports the first two; the third is the one shop that sells every part
## new, at its own price.
class_name ShopLists
extends RefCounted

## What a wanted list asks of each item beyond its number, colour and count,
## as BrickLink's upload help documents them
## (https://www.bricklink.com/help.asp?helpID=207, "Wanted List, Mass
## Upload", updated 16 October 2025). Chosen on the parts list's BrickLink
## button, and kept on the device for File, Export to use as well.
class Wants extends RefCounted:
	## CONDITION: "N" new or "U" used; "" for either, the tag left out.
	var condition: String = ""
	## WANTEDLISTID: an additional wanted list's ID, digits; "" for the main
	## wanted list, the tag left out.
	var wanted_list: String = ""
	## NOTIFY Y: BrickLink emails when a lot of the item is listed for sale.
	## Left out otherwise, as the help says it is needed only when wanted.
	var notify: bool = false

	## The choice kept on this device (ShellPrefs).
	static func kept() -> Wants:
		var wants := Wants.new()
		var condition: String = str(ShellPrefs.value("bricklink_condition"))
		wants.condition = condition if condition in ["N", "U"] else ""
		var list: String = str(ShellPrefs.value("bricklink_list"))
		wants.wanted_list = list if list.is_valid_int() and int(list) > 0 else ""
		wants.notify = bool(ShellPrefs.value("bricklink_notify"))
		return wants

	func keep() -> void:
		ShellPrefs.put("bricklink_condition", condition)
		ShellPrefs.put("bricklink_list", wanted_list)
		ShellPrefs.put("bricklink_notify", notify)

	## A session's choice (export_model): condition "new", "used" or "any",
	## wanted_list a wanted list's ID, notify true or false. What was not
	## given is what the person chose last. A [Wants], or why not as a
	## String.
	static func from(input: Dictionary) -> Variant:
		var wants: Wants = kept()
		if input.has("condition"):
			var said: String = str(input["condition"]).strip_edges().to_lower()
			var code: Variant = {"new": "N", "n": "N", "used": "U", "u": "U", "any": "",
				"either": "", "": ""}.get(said)
			if code == null:
				return "the condition is new, used or any, not \"%s\"" % said
			wants.condition = str(code)
		if input.has("wanted_list"):
			# JSON's numbers come as floats: 1234567.0.
			var given: Variant = input["wanted_list"]
			var list: String = str(int(given)) if given is float or given is int \
				else str(given).strip_edges().to_lower()
			if list in ["", "0", "main"]:
				wants.wanted_list = ""
			elif not list.is_valid_int() or int(list) <= 0:
				return ("the wanted_list is one of the person's BrickLink wanted lists by its ID, "
					+ "the number after wantedMoreID= in its address; 0 is the main list")
			else:
				wants.wanted_list = str(int(list))
		if input.has("notify"):
			var notify: Variant = input["notify"]
			wants.notify = bool(notify) if notify is bool or notify is int or notify is float \
				else str(notify).strip_edges().to_lower() in ["true", "yes", "y", "1"]
		return wants

	## What it asks, in words, or "" when it asks nothing beyond the parts.
	func words() -> String:
		var said := PackedStringArray()
		if condition == "N":
			said.append("new only")
		elif condition == "U":
			said.append("used only")
		if not wanted_list.is_empty():
			said.append("into wanted list %s" % wanted_list)
		if notify:
			said.append("BrickLink emails when one is listed")
		return "; ".join(said)

## LEGO's Pick a Brick takes up to 400 lines a file, and up to 999 of an
## element (its upload, New Elementary, 2024-10:
## https://www.newelementary.com/2024/10/pick-brick-new-upload-feature-now-live.html).
const PICK_A_BRICK_LINES := 400
const PICK_A_BRICK_MOST := 999

## The wanted list, how many lots had to be left off it, and the colours
## that left them off.
##
## Colours are BrickLink's numbers (PartLibrary.bricklink_colour, from
## colors.json). A colour with no BrickLink number known is left off and
## named, never guessed: a guessed colour orders the wrong plastic. Item
## numbers are BrickLink's where LDraw records them (Inventory.Lot.
## bricklink_id: a ribbed hose 9L is 78c09 there and 71917 here), and
## LDraw's otherwise, which are BrickLink's for nearly every plain part;
## BrickLink names the few it does not know when the list is uploaded, and
## they are on the app's own CSV to find by hand.
##
## [param wants]: the condition, the wanted list and notify, each written
## only where it asks something (the main list, either condition and no
## email are BrickLink's own when the tag is left out), after MINQTY in the
## order BrickLink's help lists its tags.
##
## A part in a direct colour is listed in the colour it stands in as
## (Inventory.Lot.stand_in), with a REMARKS saying so, which BrickLink keeps
## on the wanted list beside the item; "stand_ins" names each.
static func bricklink_xml(stock: Inventory, library: PartLibrary,
		wants: Wants = null) -> Dictionary:
	var lines := PackedStringArray(["<INVENTORY>"])
	var left: int = 0
	var made: int = 0
	var unnumbered := PackedStringArray()
	var stand_ins := PackedStringArray()
	for lot: Inventory.Lot in stock.lots:
		var colour: int = library.bricklink_colour(
			lot.stand_in if lot.stand_in >= 0 else lot.color_code)
		if lot.custom or colour < 0:
			left += 1
			if lot.custom:
				made += 1
			elif not unnumbered.has(lot.color_name):
				unnumbered.append(lot.color_name)
			continue
		lines.append("  <ITEM>")
		lines.append("    <ITEMTYPE>P</ITEMTYPE>")
		lines.append("    <ITEMID>%s</ITEMID>" % _xml(
			lot.bricklink_id if not lot.bricklink_id.is_empty() else lot.part_id))
		lines.append("    <COLOR>%d</COLOR>" % colour)
		lines.append("    <MINQTY>%d</MINQTY>" % lot.count)
		if wants != null and not wants.condition.is_empty():
			lines.append("    <CONDITION>%s</CONDITION>" % wants.condition)
		if lot.stand_in >= 0:
			lines.append("    <REMARKS>%s</REMARKS>" % _xml(_remark(lot)))
			_note(stand_ins, lot)
		if wants != null and wants.notify:
			lines.append("    <NOTIFY>Y</NOTIFY>")
		if wants != null and not wants.wanted_list.is_empty():
			lines.append("    <WANTEDLISTID>%s</WANTEDLISTID>" % wants.wanted_list)
		lines.append("  </ITEM>")
	lines.append("</INVENTORY>")
	return {"text": "\n".join(lines) + "\n", "left_out": left,
		"lots": stock.lots.size() - left, "colours_left": unnumbered, "made_parts": made,
		"stand_ins": stand_ins}


## What a list says of the parts it lists in a colour standing in for a
## direct colour ([param made]'s "stand_ins"), for the status line: ""
## when there are none.
static func stand_in_words(made: Dictionary) -> String:
	var stand_ins: PackedStringArray = made.get("stand_ins", PackedStringArray())
	if stand_ins.is_empty():
		return ""
	return "no shop sells a direct colour, so %s in the nearest colour LEGO makes: %s" % [
		"it is" if stand_ins.size() == 1 else "they are", ", ".join(stand_ins)]


## A lot in a direct colour as a list names it: "#FF0000 as Reddish Orange".
static func _note(stand_ins: PackedStringArray, lot: Inventory.Lot) -> void:
	var said: String = "%s as %s" % [lot.color_name, lot.stand_in_name]
	if not stand_ins.has(said):
		stand_ins.append(said)


## A wanted list item's REMARKS for a lot in a direct colour.
static func _remark(lot: Inventory.Lot) -> String:
	return "Brickworks: drawn in %s, an LDraw direct colour no shop sells; listed in the nearest, %s" % [
		lot.color_name, lot.stand_in_name]


## Why a list made here left lots off, in words for the status line:
## the colours by name where [method bricklink_xml] named them.
static func why_left_off(made: Dictionary, shop: String) -> String:
	var colours: PackedStringArray = made.get("colours_left", PackedStringArray())
	if shop != "bricklink":
		return "a colour Rebrickable has no number for, or a made part"
	var why := PackedStringArray()
	if not colours.is_empty():
		why.append("BrickLink has no number for %s" % ", ".join(colours))
	if int(made.get("made_parts", 0)) > 0:
		why.append("%d made part%s" % [int(made["made_parts"]),
			"" if int(made["made_parts"]) == 1 else "s"])
	return "; ".join(why)


## Rebrickable's parts-list import: part, Rebrickable colour, quantity. The
## part by Rebrickable's number where LDraw records it (a 9L pneumatic tube
## is 5102c09.375 there and 21826-f1 here).
##
## A part in a direct colour is listed in the colour it stands in as
## (Inventory.Lot.stand_in): the import has no column to say so in, so
## "stand_ins" names each for the status line.
static func rebrickable_csv(stock: Inventory) -> Dictionary:
	var rows := PackedStringArray(["Part,Color,Quantity"])
	var left: int = 0
	var stand_ins := PackedStringArray()
	for lot: Inventory.Lot in stock.lots:
		var colour: int = lot.stand_in_rebrickable if lot.stand_in >= 0 else lot.rebrickable_colour
		if lot.custom or colour < 0:
			left += 1
			continue
		if lot.stand_in >= 0:
			_note(stand_ins, lot)
		rows.append("%s,%d,%d" % [lot.rebrickable_id if not lot.rebrickable_id.is_empty()
			else lot.part_id, colour, lot.count])
	return {"text": "\n".join(rows) + "\n", "left_out": left,
		"lots": stock.lots.size() - left, "stand_ins": stand_ins}


## LEGO's Pick a Brick list: `elementId,quantity`, as LEGO's own template
## writes it (line ends and all), a line an element, in files of
## [constant PICK_A_BRICK_LINES] lines. A lot with no element number known
## (Inventory.Lot.element), or a made part, is not on it and is named in
## "missing", the lots themselves, for the person to find elsewhere. Two lots
## of one element (a tyre in Rubber Black and one in Black) are one line.
## An element wanted more than [constant PICK_A_BRICK_MOST] times is asked
## for that many, and the rest named in "over": element -> how many more.
## A part in a direct colour is the element of the part in the colour it
## stands in as (Inventory.Lot.stand_in), named in "stand_ins", as LEGO's
## two columns have nowhere to say so.
static func pick_a_brick(stock: Inventory) -> Dictionary:
	var wanted: Dictionary = {}
	var missing: Array[Inventory.Lot] = []
	var stand_ins := PackedStringArray()
	var pieces: int = 0
	for lot: Inventory.Lot in stock.lots:
		var element: String = lot.stand_in_element if lot.stand_in >= 0 else lot.element
		if lot.custom or element.is_empty():
			missing.append(lot)
			continue
		if lot.stand_in >= 0:
			_note(stand_ins, lot)
		wanted[element] = int(wanted.get(element, 0)) + lot.count
		pieces += lot.count
	var files := PackedStringArray()
	var over: Dictionary = {}
	var elements: Array = wanted.keys()
	for start: int in range(0, elements.size(), PICK_A_BRICK_LINES):
		var rows := PackedStringArray(["elementId,quantity"])
		for element: String in elements.slice(start, start + PICK_A_BRICK_LINES):
			var count: int = int(wanted[element])
			if count > PICK_A_BRICK_MOST:
				over[element] = count - PICK_A_BRICK_MOST
			rows.append("%s,%d" % [element, mini(count, PICK_A_BRICK_MOST)])
		files.append("\r\n".join(rows))
	return {"files": files, "lines": elements.size(), "pieces": pieces,
		"lots": stock.lots.size() - missing.size(), "missing": missing, "over": over,
		"stand_ins": stand_ins}


## The lots [method pick_a_brick] could not list, by name: "2 × Tile 1 x 2
## Grille in Black (2412b)", each.
static func named_lots(lots: Array[Inventory.Lot]) -> PackedStringArray:
	var out := PackedStringArray()
	for lot: Inventory.Lot in lots:
		out.append("%d × %s in %s (%s)" % [lot.count, lot.name, lot.color_name, lot.part_id])
	return out


static func _xml(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
