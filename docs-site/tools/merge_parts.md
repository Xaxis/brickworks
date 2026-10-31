---
tool: merge_parts
example: {"bricks": [30, 31, 32, 33, 34, 35]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Merge parts into the fewest bigger ones, as the window's Merge does: the plates, bricks and tiles of each colour and sub-assembly covered by the fewest real parts made in that colour, biggest first, three plates high a brick, each where the old ones stood. Six 1 x 1 plates in a 2 x 3 become a 2 x 3 plate; three stacked 1 x 4 plates a 1 x 4 brick. bricks= the parts. One undo step; where no real part would be fewer, they are left as they were.
```
