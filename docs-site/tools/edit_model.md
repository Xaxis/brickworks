---
tool: edit_model
example: {"recolor": [{"bricks": [3, 4], "color": 1}], "move": [{"bricks": [7], "dx": 1}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Change what is already built without describing it again. Takes the numbers look_at_model prints beside each brick. Use this for any change to an existing model — moving a wall, recolouring a roof, taking a chimney off, adding a door — and only use submit_design when starting something new. Everything is checked together before any of it is applied, so a change that would not hold together changes nothing.
```
