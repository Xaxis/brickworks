---
tool: pattern_parts
example: {"bricks": [12], "columns": 4, "rows": 3, "levels": 2, "column_studs": 3, "row_studs": 3, "level_plates": 9}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Lay copies of parts in a grid, as the window's Edit, Pattern…, In a grid does: columns along x, rows along z and levels up, each count with the parts given as the first (columns=4 rows=3 levels=2 is 24 in all, 23 copies). column_studs= and row_studs= how far apart, in studs (a whole or half number), and level_plates= in plates (9 is 3 bricks); each, when not given, the parts' own size that way, so copies touch (a 2 x 2 brick: 2, 2 and 3). Negative goes the other way. A row is one row and one level. Every copy is checked for room against the model and the copies before it; all or nothing, one undo step, and a copy with no room is said by its column, row and level and what is in its way. bricks= the parts, by their numbers in look_at_model.
```
