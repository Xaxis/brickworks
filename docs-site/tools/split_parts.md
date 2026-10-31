---
tool: split_parts
example: {"bricks": [21]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Split parts into smaller ones of their kind on the same studs, as the window's Split does, by Studio's rules: a plate, a brick or a tile into 1 x 1s of its kind, a 1 x 1 brick into three 1 x 1 plates, a slope into the 1-wide slope of its angle, length and height, a curved slope into the 1-wide curved slope of its length. What was joined to them is joined to the pieces. bricks= the parts. One undo step; a part that does not split, or has no room for its pieces, is said and left as it was.
```
