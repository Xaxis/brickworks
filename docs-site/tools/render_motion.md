---
tool: render_motion
example: {"name": "Open the doors", "size": "720p", "fps": 24}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Render one of the model's motions as an animation, a WebP and an MP4 (where ffmpeg is installed) where Render saves, framed on what it moves, without changing the model. reverse= and sequence= as play_motion; fps= 12 or 24; size= 480x300 or 720p; view= where the camera stands, hero (three-quarter from the front left, the default) or back for what moves at the back. Needs the app in a window, and is a job (job gives the result, with a picture of its frames).
```
