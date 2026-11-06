---
tool: view_board
example: {"views": ["front", "left", "top", "corner"], "highlight": [12, 13]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Look at the model from up to six sides in one picture: each view labelled, and each the picture view_model gives from that side (views= any of front, back, left, right, top, corner; all six when not given). Also takes, with one view or several: where= to look closely at one box, as view_model's; highlight= parts edged in magenta in their own colours with every other part drawn see-through, to find them in a big model or inside it; xray= parts drawn see-through, so what they hide shows (a roof, a shell, a hull); step=N the model as built to step N, that step's new parts edged in magenta (edit_steps lists the steps). Changes nothing.
```
