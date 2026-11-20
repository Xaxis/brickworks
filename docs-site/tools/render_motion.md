---
tool: render_motion
example: {"name": "Open the doors", "size": "720p", "fps": 24}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Render one of the model's motions as an animation, a WebP and an MP4 (where ffmpeg is installed) where Render saves, framed on what it moves, without changing the model; through its camera keys where it has them. camera= keys the camera first, kept in the motion (one undo step), a motion of that name made for it when the model has none: {"turntable": true} films the model turned once round in this one call. reverse= and sequence= as play_motion; fps= 12 or 24; size= 480x300 or 720p; view= where the camera stands, hero (three-quarter from the front left, the default) or back for what moves at the back. Needs the app in a window, and is a job (job gives the result, with six of its frames in one picture, the first and the last among them).
```
