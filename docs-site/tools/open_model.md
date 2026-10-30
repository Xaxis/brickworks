---
tool: open_model
example: {"name": "Castle"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The person's saved models and the examples that come with the app, with their part counts; name= opens one in place of what is on the baseplate, as File, Open does. Each save is kept as a version, the last 20, as File, Versions… shows: versions=true lists name='s, newest first, and version=N opens the Nth. link= a gallery model's link id (gallery) opens a copy of it saved in the person's models, as Open in Brickworks on its page does. library= an id from gallery library=true ("omr-10179-1") opens LDraw's model of that real set, credited to whoever made it, as File, Library… does. The person's work is never lost: while the model on the baseplate has changes not saved, opening is refused unless discard_changes=true, and an open is undone like any change (undo brings back the model it replaced).
```
