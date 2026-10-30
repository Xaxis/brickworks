---
tool: animate_model
example: {"turntable": true}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Animate the model: poses at moments, played smoothly between (an arm raised over two seconds and lowered again, doors opening), the model turned round once as well if asked, and rendered as an animation (a WebP, and an MP4 where ffmpeg is installed) where Render saves. keys: [{"t": seconds, "angles": {joint: degrees}}], joints by number or name from pose_model's list, or a part on its joint as move_part names it ("#14": a steering, a wheel, an arm on its pin), each in degrees from where it was built. Rendering needs the app in a window and is a job (job gives the result). The keys are kept as the model's motion "Animation" (list_motions, play_motion), which the person plays in Build, Motions…; render=false only keeps them.
```
