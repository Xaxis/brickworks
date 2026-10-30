---
tool: make_sections
example: {"sections": [{"name": "roof", "from": [21, 22, 23, 24]}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Make the suggested sections (suggest_sections) sub-assemblies, as one undo step, as the model tree's Accept all does. With no sections= every suggestion as suggested; with sections= one sub-assembly for each entry: its name and the numbers of the suggestions it is made of (two or more merge them). Parts already in a sub-assembly go inside the new one.
```
