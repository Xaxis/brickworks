---
tool: search_parts
example: {"query": "slope 45 2 x 2", "limit": 5}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Find real parts by description. Returns part numbers with their footprint, height and the colours they were really made in. Use this instead of guessing a part number. Printed parts are found by what is on them with the word print: "porsche print", "control panel print", "3623 print" (3623's prints); a part with a sticker on, with sticker. like= a part number lists the parts like it, to swap it for: its footprint and kind first.
```

To swap a part for one like it, give `like` a part number, `{"query": "", "like": "3001"}`: five of its footprint and kind come first, then the rest of its footprint by use, nearby kinds among them (a 2 × 4 brick's plate and tile), then its kind in other sizes, as the parts bin's [Like this](/docs/parts-bin#like-this) lists them. Words in `query` narrow the list: `{"query": "plate", "like": "3001"}` is the 2 × 4 plates.
