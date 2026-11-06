---
tool: compare_with_photo
example: {"photo": "a red and white lighthouse on a cliff, from the side", "is_it": true, "whole": {"length": 0.2, "width": 0.2, "height": 1}, "features": [{"name": "the lantern", "where": {"y_from": 60, "y_to": 72}, "length": 0.8, "width": 0.8, "height": 0.2}, {"name": "the gallery", "where": {"y_from": 57, "y_to": 60}, "length": 1, "width": 1, "height": 0.04}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Answer each step of the look a design's first whole review asks for, measuring the model against a photograph of the real thing: real_thing (its own name, to search for the photograph), then photo, is_it and the shares read off the photograph (whole, and features each with where), then settled (each share over the line rebuild or keep, and why), then again (each rebuilt feature's box now). Only when a review asks.
```
