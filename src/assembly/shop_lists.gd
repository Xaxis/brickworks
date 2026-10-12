## A model's parts list in the forms the two big shops read: a BrickLink
## wanted list and a Rebrickable parts list.
##
## Building by hand ends at a table with the bricks on it. The app's own
## CSV carries element numbers and every colour name, which a person can
## read and a shop cannot: BrickLink's wanted lists take an XML of its own
## item and colour numbers, and Rebrickable's import takes three columns.
## Studio exports both.
class_name ShopLists
extends RefCounted

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
static func bricklink_xml(stock: Inventory, library: PartLibrary) -> Dictionary:
	var lines := PackedStringArray(["<INVENTORY>"])
	var left: int = 0
	var made: int = 0
	var unnumbered := PackedStringArray()
	for lot: Inventory.Lot in stock.lots:
		var colour: int = library.bricklink_colour(lot.color_code)
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
		lines.append("  </ITEM>")
	lines.append("</INVENTORY>")
	return {"text": "\n".join(lines) + "\n", "left_out": left,
		"lots": stock.lots.size() - left, "colours_left": unnumbered, "made_parts": made}


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
static func rebrickable_csv(stock: Inventory) -> Dictionary:
	var rows := PackedStringArray(["Part,Color,Quantity"])
	var left: int = 0
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or lot.rebrickable_colour < 0:
			left += 1
			continue
		rows.append("%s,%d,%d" % [lot.rebrickable_id if not lot.rebrickable_id.is_empty()
			else lot.part_id, lot.rebrickable_colour, lot.count])
	return {"text": "\n".join(rows) + "\n", "left_out": left,
		"lots": stock.lots.size() - left}


static func _xml(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
