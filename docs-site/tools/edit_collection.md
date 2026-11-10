---
tool: edit_collection
example: {"add": [{"part": "3001", "color": 4, "count": 6}, {"part": "3023", "color": 71, "count": 12}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The person's own bricks, as Build, My collection's What I own keeps them with their account: sets, and loose parts by part, colour and count. add=[{part, color, count}] adds loose lots, all in one call: given a photo of their pile, look at it closely, name each part (its LDraw number, as search_parts gives it; a BrickLink number is read too) and its LDraw colour code, count each, and add them together. Every lot added is marked as this chat's and listed for the person apart from their own, to keep or take back with one button. remove=[{part, color, count}] takes pieces off lots this chat added (count omitted: the whole lot). With neither, it reads the collection back, this chat's lots apart. Their sets and their own lots are theirs: this never changes them. parts_list which="need" then measures the model against it, and which="buildable" ranks what they can build. missing={set, lots: [{part, color, count}]} puts how many of each named part a set they own is missing to count, all its copies together (0 unmarks it), as its Missing parts… page does; the reply says each change as was N, now M, to put back. none=true says a set has nothing missing, and is refused while anything is marked: name those lots, count 0. Send missing= alone, not with add= or remove=. What do I need?, the pool and a bin built from the set then count only what is there.
```
