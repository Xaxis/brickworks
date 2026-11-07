---
tool: save_view
example: {"name": "Three quarter"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Keep where the person's window looks from now with the model, by a name, as View › Viewpoint › Save this view… does: the camera's turn, tilt and distance, the point it looks at, and whether it is square on. Each of the first nine gets a key of its own and a row in View › Viewpoint, Render's Camera lists them all, and view_model, render_model and render_queue draw from one by its name as view=; in_view lists them. A view of the same name is replaced where it is. Kept in the model's file at its next save (save_model). remove=true takes the view of that name out instead. Answered with the model drawn from the view, as view_model view= draws it (picture=false: words alone).
```
