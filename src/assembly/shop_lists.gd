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

## LDraw colour code -> BrickLink colour number, for the colours LEGO makes
## now and most of the ones it made. From the SetDB colour guide
## (merlinsbricks.com/colors, read 2026-10-11), which sets BrickLink,
## LEGO, Rebrickable and LDraw numbers side by side; every pair agrees
## with BrickLink's own colour guide where both have it. A colour not
## here is left off the list and said so, never guessed: a guessed colour
## orders the wrong plastic.
const BRICKLINK_COLOUR: Dictionary = {
	0: 11, 1: 7, 2: 6, 4: 5, 5: 47, 6: 8, 10: 36, 14: 3, 15: 1, 19: 2,
	25: 4, 26: 71, 27: 34, 28: 69, 29: 104, 30: 157, 31: 154, 33: 14,
	34: 20, 36: 17, 37: 50, 40: 13, 41: 15, 42: 16, 46: 19, 47: 12,
	52: 51, 57: 98, 70: 88, 71: 86, 72: 85, 73: 42, 78: 90, 84: 150,
	85: 89, 92: 28, 117: 101, 179: 95, 191: 110, 212: 105, 226: 103,
	272: 63, 288: 80, 297: 115, 308: 120, 320: 59, 321: 153, 322: 156,
	323: 152, 326: 158, 330: 155, 353: 220, 378: 48, 379: 55, 484: 68,
}


## The wanted list, and how many lots had to be left off it.
##
## Item numbers are LDraw's, which are BrickLink's for nearly every plain
## part; BrickLink names the few it does not know when the list is
## uploaded, and they are on the app's own CSV to find by hand.
static func bricklink_xml(stock: Inventory, library: PartLibrary) -> Dictionary:
	var lines := PackedStringArray(["<INVENTORY>"])
	var left: int = 0
	for lot: Inventory.Lot in stock.lots:
		var plain: int = library.plain_code(lot.color_code)
		if lot.custom or not BRICKLINK_COLOUR.has(plain):
			left += 1
			continue
		lines.append("  <ITEM>")
		lines.append("    <ITEMTYPE>P</ITEMTYPE>")
		lines.append("    <ITEMID>%s</ITEMID>" % _xml(lot.part_id))
		lines.append("    <COLOR>%d</COLOR>" % int(BRICKLINK_COLOUR[plain]))
		lines.append("    <MINQTY>%d</MINQTY>" % lot.count)
		lines.append("  </ITEM>")
	lines.append("</INVENTORY>")
	return {"text": "\n".join(lines) + "\n", "left_out": left,
		"lots": stock.lots.size() - left}


## Rebrickable's parts-list import: part, Rebrickable colour, quantity.
static func rebrickable_csv(stock: Inventory) -> Dictionary:
	var rows := PackedStringArray(["Part,Color,Quantity"])
	var left: int = 0
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or lot.rebrickable_colour < 0:
			left += 1
			continue
		rows.append("%s,%d,%d" % [lot.part_id, lot.rebrickable_colour, lot.count])
	return {"text": "\n".join(rows) + "\n", "left_out": left,
		"lots": stock.lots.size() - left}


static func _xml(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
