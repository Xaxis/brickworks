---
tool: make_art
example: {"name": "The Great Wave", "panels": [3, 2], "palette": [15, 1, 272, 71]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Lay a picture as a LEGO® Art set is laid — 31212 The Milky Way, 31208 The Great Wave, 31213 Mona Lisa — on 16 x 16 panels joined underneath into one piece: square tiles merged where it is flat, 1 x 1 round tiles for texture, quarter circles along curved contours, stars in trans-clear, glow-in-the-dark, pearl and metallic set a plate proud, and the subject raised on stacked plates with cheese slopes. Use this, not submit_design, whenever a mosaic, a picture in bricks, wall art or something like a LEGO® Art set is asked for. It replaces what is on the baseplate.
The picture is the one the person chose (look_at_picture shows it). With none, draw it yourself as svg: one stud is one pixel, so big simple shapes in flat colours, like a poster.
You decide what a designer of LEGO® Art sets decides, and the app reads everything you leave out off the picture: the panels and the crop; regions over the picture, each with its texture, its relief (the subject raised, the background flat), whether contours run in it and whether its points of light are stars and in what finish; single stars put exactly where you want them; a palette to keep to. Coordinates are fractions of the picture, 0 to 1 from its top left. Later regions lie over earlier ones and change only what they say, so start with the whole picture and work inward. A plan that cannot be laid is refused with every fault named.
The answer is the picture as laid, face on, and what it is made of. Look at it as a person would from across a room, and call make_art again with the plan changed if it does not read as the subject.
```
