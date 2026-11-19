---
tool: compare_with_set
example: {"set": "7140-1"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
What differs between the model and a real set, and where, as File, Compare, Compare with the set… lists it: the model checked against the set's own model from the library (LDraw's model repository, stepped by its author as the booklet is). Every part taken away, added, swapped for another mould or part, recoloured, moved (a stud is enough) or put in another sub-model, under the set's own step it is in (step 12; step 3 of the Wing, which goes on in step 12), each with where it is in the model (its sub-model and the line of its file), its #N as look_at_model numbers it, and the edit_model call that puts it back as the set has it. A model that is the set says it matches. set= the set's number as on its box (7140 or 7140-1); without it, the set the model was opened from (open_model library=). most= how many changes are listed (60). show=true opens it in the person's window too, drawn on the model. Changes nothing.
```

One call answers "what did I change from the set, and where": each change under the set's own step, with the part's #N and the edit_model call that puts it back. Without `set`, it checks against the set the model was opened from. It changes nothing, so it is safe to call after every round of edits.

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
What differs between the model and a real set, and where, as File, Compare, Compare with the set… lists it: the model checked against the set's own model from the library (LDraw's model repository, stepped by its author as the booklet is). Every part taken away, added, swapped for another mould or part, recoloured, moved (a stud is enough) or put in another sub-model, under the set's own step it is in (step 12; step 3 of the Wing, which goes on in step 12), each with where it is in the model (its sub-model and the line of its file), its #N as look_at_model numbers it, and the edit_model call that puts it back as the set has it. A model that is the set says it matches. set= the set's number as on its box (7140 or 7140-1); without it, the set the model was opened from (open_model library=). most= how many changes are listed (60). show=true opens it in the person's window too, drawn on the model. Changes nothing.
```
