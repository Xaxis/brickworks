---
tool: measure
example: {"from": "#4.hinge[0]", "to": "#5.hinge[0]"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Measure between two connectors, or two points, as the window's Measure does: the distance in mm, studs across (x), deep (z) and plates up (y), and the angle between the two connectors' axes to a tenth of a degree (with a hole, a bar or a hinge, which go both ways, the angle between the lines, 0 to 90°; between two pins or axles, 0 to 180°). from= and to= each a connector as attach names it, "#12.hole[1]" or "#7.hinge[0]" (attachment_points lists a part's), or a point "x y z" in studs and plates. The two halves of one joint (a hinge, a pin in its hole, a clip on a bar) are said with the turn between them as attach's yaw gives it, so a hinge left at an angle reads back as that angle. Changes nothing.
```
