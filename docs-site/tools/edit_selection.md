---
tool: edit_selection
example: {"recolor": [{"bricks": [2], "color": 14}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Change the selected parts as edit_model does — take off, paint, move, put down — keeping to the selection's room: a change that reaches outside it is refused whole, and everything else in the model stays where it is. It is checked as any design is, so a change that would not hold together or leaves a part loose changes nothing, and the refusal says, part by part, what each ran into or why nothing holds it, and the nearest place it fits and holds. check_only=true tries a change without making it. Other copies of the sub-assembly follow the change. One undo takes the request back. For more room, give room= and why=: the person is asked first.
```
