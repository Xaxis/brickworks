---
tool: render_queue
example: {"action": "add", "quality": "best", "size": "1080p", "samples": 512}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Pictures lined up and drawn one after another while the person goes on working, as File, Render queue… does. action add queues the model and the view as they are now (view current, the window's, unless another is given), with Render's settings changed by quality, size, samples (Best's, 1 to 4096), view, look, backdrop and depth_of_field as render_model takes them; drawing begins at once unless paused, and each is saved where Render saves under a name of its own. list (the default) says what is waiting, being drawn and done, with where each was saved, and changes nothing; number=N with it shows that finished picture. pause holds the rest after the one being drawn, go_on carries on, finish_now keeps the one being drawn as clean as it is (a path-traced picture), cancel number=N takes one out or stops it, clear forgets the finished. Best is path traced where the graphics card traces rays, and frames averaged where it does not, and the answer says which. Needs the app in a window.
```
