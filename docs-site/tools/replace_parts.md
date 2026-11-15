---
tool: replace_parts
example: {"find": {"part": "3023", "color": 0}, "replace": {"color": 72}, "where": "all"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Find and replace parts across the whole model in one call, as the person's Edit › Find and replace… does: find= a part, a colour or a part in a colour; replace= another part, another colour or both, each part keeping what it is not given. where= "all" (the default) is every part of the model, inside every sub-model and every copy of one; "submodel" the sub-model the person is editing and every copy of it; "selection" the parts selected. A sub-model's copies are one definition, so a part replaced in one is replaced in every copy, and a copy placed by a mirror is given the new part's other hand. One call is one undo step, and the model saves as the window's own replace saves it. The answer lists where the part is (the model and each sub-model, with counts and copies) and every colour it is used in, flags a part used in more than one colour, and says where a new part will not sit as the old one did (another footprint, other connection points) or would hold onto nothing, and where it has no room and is left. With no replace= or with preview=true it changes nothing and lists only.
```
