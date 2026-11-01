---
tools: read_guide, review_model, settle_feature, settle_surface, job
ai: A design session works in passes, as a set designer does: the scale and references, the silhouette submitted first, a review against real sets, each feature and each assembly, the surface pass, the creative pass, then save. The said blocks on this page are the exact words every session is given first; read_guide gives any section of the rest.
rules:
  - Nothing overlaps; nothing floats; the model is one connected thing, and parts side by side are not joined, only stacking joins.
  - Only the start of the instructions reaches every client (Claude Code shows about 3,800 characters); read_guide gives the rest.
  - A call answered with a job number is still working in the app; call job until it gives the answer.
  - Each change is one undo step.
title: How a design session works
nav: A design session
description: What an assistant does when it designs in Brickworks, the words it is given, each call, the limits, and what to do when something goes wrong.
---

Whichever assistant designs, Claude through the connector, ChatGPT, Claude Code, or an AI on your own key in the assistant panel, it works the same way, with the same tools, and the app holds every change to the same checks. This page is the method in plain words, then the words the assistant itself is given, which are made from this page, so the two cannot differ.

## The method {#method}

1. **Scale and references.** `plan_scale` with the real thing's length, `find_reference` for a picture of anything real, and `how_real_sets_build_this` for what real sets of the kind are built from, and the faults found in earlier designs of it.
2. **The silhouette first.** `submit_design` with the main masses, the model's assemblies (what a person would name: the gatehouse, each tower) and its features (what the subject is known by: an owl's eyes, a car's grille), each with where it goes. The app builds it, checks it, and refuses what does not hold together, part by part.
3. **Review.** `review_model` sets the silhouette and proportions beside real sets; the masses are fixed before any detail.
4. **Each feature.** The app lays a real set's piece where the feature goes, and `settle_feature` accepts it, asks for the next, rejects it, or says the assistant built it itself.
5. **Each assembly**, looked at with `review_model` and detailed with `edit_model`.
6. **The surface pass.** `review_model` with `surface`: the app tiles open studs, steps slopes and rounds hard edges, and `settle_surface` settles each finding.
7. **The creative pass**, a few touches of character, then `save_model`. A new design's first save brings [fresh eyes](/docs/fresh-eyes).

Through it all, three rules hold: nothing overlaps, nothing floats, and the model is one connected thing. Asked about a selection, the assistant changes only that ([Ask about the selection](/docs/ai#ask)).

## What the assistant is told {#told}

The connector and the desktop's port give every session the same instructions. A client may show an assistant only their start (Claude Code shows about the first 3,800 characters), so the start says how to work and names every section of the rest, which `read_guide` gives in full. These are the words, exactly as Brickworks sends them.

```said connected
These tools build in the person's Brickworks tab, which works on while they are here. Each answer names its tab and model. When the person names a tab or model, call select_tab first.
```

```said head
You design LEGO® models with this app's tools: it builds what you submit, checks that it holds together, and refuses what does not. Only the start of these instructions may reach you: read_guide gives any section of the rest in full.

HOW TO WORK — the way a set is designed:
 1. plan_scale with the real thing's length; find_reference for anything that exists; how_real_sets_build_this with the subject: real sets' parts, and the faults the judge found in our own designs of it, to design out.
 2. The silhouette: the main masses, sized in studs off the picture and the brief. A hull, a car body, a fuselage or a building is a shape pattern (read_guide "shapes"); a figure, a creature, a character or anything small is shaped parts on joints (the figure pattern, attach; read_guide "figures"). submit_design that first, with its assemblies and features — what the subject is known by (an owl's eyes; a car's wheel arches, grille), each with where it goes (x, y, z, facing).
 3. review_model: the silhouette and proportions against real sets. Fix the masses before any detail.
 4. Each feature in turn: the app lays the best real set's piece where it goes; settle_feature accepts it, asks for the next, rejects it, says you built it or skips it. A feature is parts with depth, never a painted tile.
 5. Each assembly in turn: review_model {"assembly": name}, detailed with edit_model.
 6. The surface pass: review_model {"surface": true} — the app tiles open studs, slopes staircases, rounds hard edges; settle each with settle_surface.
 7. Last, the creative pass: review_model {"creative": true} — three touches, the best one or two added; where the brief lists the scene, on what it names. Then save_model.

THE RULES: nothing overlaps; nothing floats (every part on the ground or on a part under it); the model is one connected thing — parts side by side are not joined, only stacking joins, so stagger the joints.

A MECHANISM (gears, axles, a crank, a turntable): read_guide "pins" first. Put a pin, an axle, a gear or a bush by its line, axis "z" and the x, y, z attachment_points gives the hole, never by its corner. Gears mesh 1.25 LDU a tooth apart: an 8 and a 24, 2 studs. A ratio no two gears give: search_gear_ratio.

A ROUNDED BODY (an animal, a fruit, a figure's belly, a curved car): read_guide "outline" first, and search_parts its outline parts before you lay it. A dome or a sphere: read_guide "round". Never plates stepped in.

ASKED ABOUT A SELECTION (parts the person selected): selection, then where_to_attach (with part=, placements that fit as they are), then edit_selection; never submit_design.

SKETCH FIRST, when asked: submit_design with "sketch": true three times (each a different idea, under 150 parts), then choose_sketch one and design from it.

read_guide sections: "work", "rules", "outline", "shapes" (repeat, mirror, fill, rock, studs_out, prism, round, and shape with its face), "figures", "subject" (what each kind of subject needs), "real", "colour", "angle", "round", "coordinates", "sideways", "pins", "big", "look", "good", "beautiful", "creative", "changing", "kind", "art", and "app" (everything else the person can do from the menus, as tools).

A call answered with a job number is still working in the app: call job about every 10 s until it gives the answer.
```

```said method
How to work here, said once as this chat begins (read_guide "work" has it whole, and read_guide any section a step names):
 1. Before building: plan_scale with the real thing's size, find_reference for anything that exists, how_real_sets_build_this with the subject: real sets' parts, and the faults found in our own designs of it, to design out.
 2. submit_design the silhouette first: the main masses, with its assemblies and its features (what the subject is known by, each with where it goes). A hull, a car body or a building is a shape pattern (read_guide "shapes"); a figure or a creature is shaped parts on joints (read_guide "figures"). Pass the person's request, word for word, as brief, and a part count they named as parts.
 3. review_model: fix the silhouette and proportions before any detail.
 4. Each feature: the app lays a real set's piece; settle_feature it.
 5. Each assembly: review_model {"assembly": name}, detailed with edit_model.
 6. review_model {"surface": true}, settle_surface each; 7. review_model {"creative": true}; then save_model.
Nothing overlaps, nothing floats, and the model is one connected thing.
```

## Each call {#calls}

- **One undo step a change.** Whatever a call changes, Undo takes back in one step; your own Undo takes back any step, and the assistant's `undo` stops at a step another chat made.
- **Parts by number.** `look_at_model` lists the parts with a number each, and later calls name parts by those numbers (`brick`, `bricks`).
- **Pictures.** A change is answered with a close look at what changed, and `view_model` looks from any side.
- **Long work is a job.** A client waits about three minutes for an answer, so a render, a turntable, a booklet, a Studio file, a picture, a brickify or a recording answers at once with a job number and goes on in the window. `job` waits up to 45 seconds a call and gives the answer, picture and all, once it is done.
- **Its tab.** Through the connector, each chat's calls go to its own tab: see [Several tabs, several chats](/docs/connector#tabs).

## Limits {#limits}

| What | The limit |
|---|---|
| One call | A client waits about three minutes; longer work is a job, followed with `job` |
| The instructions | A client may show only their start, about 3,800 characters; `read_guide` has the rest |
| Undo | 1 to 25 steps a call |
| A sketch | Under 150 parts, three to an idea, then `choose_sketch` |
| A selection | `edit_selection` changes the selection and the room just round it, and more only when the person allows it |
| Brickify | 6 to 64 studs along the longest side; a file by link of at most 96 MB |
| A mosaic | 1 to 6 panels of 16 x 16 studs each way |
| The tools | Every one, with its arguments and an example, is in [the tool reference](/docs/mcp-tools) |

## When something goes wrong {#troubleshooting}

- **"No Brickworks tab is open"**: open [brickworks.diy/app](/app), signed in with the account the assistant connected with, and turn the assistant on (**Tools › Settings…**, *Assistant (AI)*). Then ask again.
- **"The browser has paused it"**: a browser pauses a tab out of view. Bring the Brickworks tab into view for a moment; the connector waits 20 seconds for it before it says so.
- **A design refused**: the answer says what failed, part by part, and the assistant fixes it and submits again. Nothing that fails reaches the baseplate.
- **A tool is missing**, or **it built in the wrong tab**: see [Troubleshooting](/docs/troubleshooting#new-tools) and [the wrong tab](/docs/troubleshooting#wrong-tab).
