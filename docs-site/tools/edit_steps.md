---
tool: edit_steps
example: {"op": "list"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The model's build steps, the order the booklet and the timeline follow, as Edit, Build steps changes them. op "list" (the default) gives them with the part numbers in each; "to" puts bricks= in step=, however far, as the person drags them onto a step; "next" or "prev" moves bricks= a step later or earlier; "new" makes a new step of bricks=; "earlier", "later", "merge" (with the next) and "delete" act on step=, a number from the list. A model with no steps of its own is given the worked-out ones first, in the same undo step.
```
