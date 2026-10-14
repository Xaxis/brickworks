# Research: the state of the art, and where Brickworks stands

Read on **2026-10-14**, against `main` at `47a905b`. It covers AI design for
LEGO® bricks in research and in products (2024–2026), the CAD tools builders
use today, and what those builders ask for. It ends with the ten units that
would do most for Brickworks, ranked.

**How it was made.**
- Four research passes read every source below on 2026-10-14: AI generation
  papers, benchmarks and products, CAD tools, and builders' forums. They
  kept a short quote for every claim.
- The claims the ranking rests on were then re-read by hand: BrickBench's
  numbers, `verify.py`, the OMR's rule on steps, the Rebrickable AI rule,
  four forum quotes, LDraw Nova, BrickSim, Mecabricks' render farm, the iPad
  thread, MDN's eviction rules and the overlap of BrickNet's parts with our
  catalogue. All matched.
- *Unverified* marks a claim seen only in a search summary, or on a page
  that refused us. reddit.com refuses automated readers, so Reddit threads
  were read through the Arctic Shift archive [arctic]; the links go to
  reddit.com. The BrickLink forum asks for a sign-in and was not read.
- Brickworks' own claims link into this repository. `docs/COMPETITIVE.md`
  (2026-10-12) is the feature-by-feature matrix. This file does not repeat
  it; it adds what changed and what the field measures.

## Where Brickworks stands, from its own records

- **Leads.** It is the only CAD found with an AI designer
  ([COMPETITIVE.md](COMPETITIVE.md)). It checks clutch and levers per
  joint ([stability.gd](../src/assembly/stability.gd)). It runs in a
  browser and on three desktops. Its gear trains turn in Simulate, and its
  orrery keeps eight planets' years within 0.35% of NASA's figures
  ([MECHANISMS.md](MECHANISMS.md)).
- **Since 2026-10-12** it has added: the author's steps kept and edited, Ask
  Claude about this, Build mode on a phone, 3D export, a public gallery,
  Sketch first, and the assistant made optional ([CHANGELOG.md](../CHANGELOG.md)).
- **Design quality, by its own judge.** The latest round's mean is 5.1 of 10.
  Technique is 4.2 and surface 4.5, the weakest two. The run-to-run spread
  is about as large as the changes ([DESIGN_SCORES.md](DESIGN_SCORES.md)).
- **The build check against real sets.** It holds 65.5% of part instances
  in 1,572 files of LDraw's model repository ([CONNECTIONS.md](CONNECTIONS.md)).
- **Never measured outside.** No external benchmark has been run on it.

## 1. AI design for LEGO® bricks, 2024–2026

| Work | What it does | Measured how | Result (the authors' own unless marked) | Open, licence | For Brickworks |
|---|---|---|---|---|---|
| **BrickBench + BrickAgent** (Stanford, MPI-IS, Inria; 8 Oct 2026) [bb] | A frontier model as a coding agent with a Python API over LDraw: part search, placement by connector, sub-assemblies, renders, a checker. 300 prompts: Model (≤400 parts), Set (400–4,000), Alt-Build (the 783 parts of set 10698) [bb] | Valid (part limits, no collisions, PyBullet rigid-body stability). VQA: Gemma 4 31B answers a question graph on 8 renders. ELO: pairwise Bradley–Terry, judged by the same Gemma [bb] [bb-vlm] | Claude Opus 5.5, Model setting: valid 1.00, VQA 0.952, Design ELO 1252, $5.90 a build; overall VQA 0.923 [bb]. Without the checker, GPT-6 Astra is valid on 40% [bb]. People picked the human model in 323 of 360 ratings [bb]. Judge and 102 raters agreed on 34 of 36 pairs (Kendall τ 0.89) [bb] | MIT code, prompts in the repo [bb-repo]. Human reference models are in BrickNet's gated data [bricknet-repo]. Agents' 3,456 builds are downloadable from the gallery, no licence stated [bb-gallery] | **Run it** (unit 1). Their stability test leaves "the holding force of stud connections" unmodelled [bb]; ours checks it. Adopt pairwise judging (unit 4) |
| **BrickGPT** (CMU; ICCV 2025) [bgpt] | Text to bricks from a fine-tuned 1B Llama: 8 rectangular bricks, one unit tall, a 20³ grid [bgpt] | Valid, stable (StableLego force balance), CLIP, DINOv2 on 250 prompts [bgpt] | 100% valid, 98.8% stable, median 40.8 s [bgpt]. BrickBench measured it at VQA 0.024 [bb] | MIT code, weights and the StableText2Brick data (42,604 train, 4,785 test) [bgpt-repo] [s2b]. Stability needs a Gurobi licence [bgpt-repo] | Beat on parts. Its metrics are cheap to compute on our designs |
| **STABLE** (Buffalo, UMD; May 2026) [stable] | Point cloud to BrickGPT's bricks, trained with rewards for collisions, connectivity and interlocking; no rollback [stable] | Collision-free, voxel IoU, interlocking, seam coverage, time [stable] | 0.99 collision-free, IoU 0.907, 57.6 s a sample [stable]. ResemBrick's exact solver found it 14% stable on held-out objects [resem] | MIT code and data [stable-repo] | Adopt its interlocking and seam metrics. Its headline stability excluded invalid outputs: report ours over everything |
| **BrickAnything** (XJTU; v2 Aug 2026) [banything] | Mesh or point cloud to a tree of attached bricks; rollback to the parent brick only [banything] | Chamfer, IoU, rollbacks, % stable on 500 easy and 500 hard shapes [banything] | 83.4% stable on the hard set, where Legolization got 0% [banything]. Fails on "slender components, smooth curved surfaces" [banything] | MIT code and weights; the 168K training pairs not found [banything-repo] | Repair from the failing parent, not the whole design |
| **ResemBrick** (CUHK-Shenzhen; Aug 2026) [resem] | A few photos to a textured mesh, then a brick model with every floating part grounded; 91 solid colours [resem] | MS-SSIM, LPIPS, Stab% (StableLego MILP) on 198 held-out objects [resem] | 0.955 / 0.075 / 100% stable, against **BrickLink Studio's converter at 0.733 / 0.204 / 75.0** [resem] | No code, weights or data found | A published table our brickify can be put against |
| **BrickNet** (Inria, MPI-IS; CVPR 2026) [bricknet] | Real LDraw parts with typed connectors (stud, hinge, axle, ball, fixed); models written as a tree of connections; Qwen3 0.6B–14B [bricknet] | Valid steps; VQAScore, PE, SigLIP 2 on 512 captions [bricknet] | 9,743 parts, builds capped at 100 parts [bricknet]. BrickBench found it collision-free on 26% of prompts [bb] | MIT code and connector labels [bricknet-repo]. Data "for academic and research use only" [bricknet-repo] | Its MIT connector labels are a second opinion on our connection data. Its data is closed to us |
| **LegoACE** (ZJU, VAST; SIGGRAPH Asia 2025) [legoace] | Text or normal maps to (position, rotation, type) tokens; 9,314 part types [legoace] | CLIP, a user study, connectivity counted by hand [legoace] | CLIP 23.25 against BrickGPT's 21.92; "some generated instances contain disconnected components" [legoace] | MIT; the released weights cover 28 part types; its 55,000-model data was not found [legoace-hf] | Beat: no physics or connection model |
| **StableLego** (CMU; RA-L 2024) [stablelego] | Force-balance stability per brick, solved with Gurobi [stablelego] | 225 objects built for real [stablelego] | 99.56% correct, one wrong of 225 [stablelego] | MIT code [stablelego-repo] | A ground truth for our check (unit 3) |
| **BrickSim** (CMU; Mar 2026) [bricksim] | Snap-fit physics per stud as a convex QP [bricksim] | 150 real builds of up to 30 bricks [bricksim] | 100% correct in 5 ms; StableLego 98%, "conservative" [bricksim] | MIT; needs Isaac Sim on Linux with NVIDIA; the 150 labels are not in the repo [bricksim-repo] | The strongest stability model found; bricks, plates and slopes only, no Technic or hinges [bricksim] |
| **PVPO** (May 2026) [pvpo] | Post-training on BrickGPT's grid | Validity, VLM likeness [pvpo] | Names "PhysHack": assemblies valid but "geometrically misaligned, semantically inconsistent" [pvpo] | Code not released [pvpo] | Score likeness and stability apart, always |
| **LDraw Nova** (one developer; Sept 2026) [nova] | An agent writes a plan and a Python generator that emits LDraw; part search, collision and gap checks, headless renders [nova] | None published | 351 stars in three weeks [nova]. Its example cathedral, B-wing and street were the most set-like renders seen in this survey (our judgement, three images) | AGPL-3.0 [nova]. No stability check in its README [nova] | The closest open rival. Beat on stability, a CAD to edit in and MCP |
| **Products** | BrickForgerAI: a 55-part library, 70+ in a beta mode with no load check, from £1.50 a month [bforger] [bforger-help]. BrickBuilder.ai: shapes on a stud grid, parts shipped, free to generate [bbuilder]. MCP servers: lego-mcp (43 parts) [legomcp], BrickBuilderMCP (stud-only, "No physics", an inline viewer in Claude Desktop) [bbmcp] | Galleries only | — | Mostly MIT on GitHub | Beat on parts and physics. Adopt the inline viewer (unit 9) |

**What the field shows.**
- **Agents with tools have overtaken trained generators.** BrickGPT reaches
  VQA 0.024 where a frontier agent reaches 0.95 [bb]. That is Brickworks'
  approach.
- **The checker is what makes them buildable.** Valid falls from 100% to
  40% without it [bb].
- **No agent is yet taken for a designer.** Five raters chose the human
  model in 323 of 360 ratings [bb]. They found agent builds lack "the part
  usage, proportion, and surface detail that mark human design" [bb]. Our
  judge names the same gaps: technique and surface
  ([DESIGN_SCORES.md](DESIGN_SCORES.md)).
- **Physics is the weak spot everywhere.** The systems use a rigid-body
  drop [bb], force balance on rectangular bricks [stablelego], or none
  [legoace]. Only StableLego and BrickSim were tested on real builds, and
  neither covers Technic or hinges [stablelego] [bricksim].
- **None of this runs inside a CAD.** The CAD tools ship no generative AI.
  Studio's release notes since 2.0, 193 versions, hold none [st-dl], and its
  help centre has no article on it [st-help-api].
- **Also read, and smaller for us.** LEGO®-Maker turns an image into a
  model with over 100 part types (ACM TOG, Dec 2025); no code was found
  [legomaker]. TreeSBA builds from images, self-supervised (ECCV 2024, MIT)
  [treesba]. Brick-Composer lifts a multimodal model's step-level assembly
  success "from less than 1% to around 15%" [bcomposer]. CAD-Assistant
  drives FreeCAD with a vision model and found that answering from renders
  beats answering from text (ICCV 2025, CC BY-NC) [cadassist].

### Instructions and assembly order

| Work | What it found | Open | For our booklet |
|---|---|---|---|
| Agrawala et al., SIGGRAPH 2003 [agrawala]; the user study [heiser] | "the strongest design principle is that all the new parts added in each step ... must be visible" [agrawala]. Generated instructions cut furniture assembly time 35% and errors 50% [heiser] | Papers only | A visibility gate per step (unit 2) |
| MEPNet, ECCV 2022 [mepnet] | Real manuals' steps form a tree of sub-models. Its synthetic manuals take parts that are removable and visible, at most 10 parts and 5 kinds a step [mepnet] | MIT code [mepnet] | A step-size cap; callouts from the tree |
| APEX-MR, RSS 2025 [apexmr] | Plans by taking a model apart and pruning every order whose intermediate structure is unstable [apexmr] | MIT code [apexmr] | Check every intermediate state (unit 2) |
| AssemblyBench, CVPR 2026 [asmbench] | Scores a camera by each part's visible pixels, on a log scale, zero if a new part is hidden [asmbench] | None found | Choose each section's view by it |
| Graph Transformer sequence planning [gt-asp] | Predicted LEGO® build orders reach Kendall τ 0.44 against human ones [gt-asp] | Repo gone (404) | The measure for unit 2 |

### Benchmarks Brickworks could run

| Benchmark | What it would prove | What running it takes |
|---|---|---|
| **BrickBench** [bb-repo] | Where our designer stands against 13 systems, like for like against Opus 5.5 in BrickAgent | Parts limited to BrickNet's 14,441, which are all in our catalogue but are 48.8% of it: no stickers or unofficial parts (measured today against `catalogue.json`). A `build.py` per design, since `verify.py` requires it [bb-verify]. `verify.py` runs on a CPU. VQA and ELO need BrickNet-Render (Blender 5.1, Python 3.13) and Gemma 4 31B in about 62 GB of GPU memory [bb-repo]. This machine has a 12.9 GB GPU. Or submit a zip of at most 10 MB through their form [bb-repo] |
| **StableText2Brick** [s2b] | Text to model against BrickGPT's CLIP 0.324 | 250 test captions, CLIP and DINOv2 on one GPU. A low ceiling: simple shapes and captions without colour [bgpt] |
| **StableLego, BrickSim** [stablelego-repo] [bricksim] | How often our stability check is right | StableLego's probes and constants (MIT). BrickSim's 150 real-build labels on request. CPU only (unit 3) |
| **ResemBrick's protocol** [resem] | Brickify against Studio's converter (75% stable) | Its 198 OmniObject3D objects at R=24, MS-SSIM, LPIPS, and Gurobi for the stability score. OmniObject3D's licence not checked |
| **The OMR's own steps** [omr-spec] | Whether our booklet orders a build as the official one does | The repository's rule: its step metas "should enable any instructions generated to be as close to the official instructions as possible" [omr-spec]. We already hold 1,572 of its files (unit 2) |
| LEGO®-Puzzles [legopuzzles] | How well a model's eyes read assembly pictures (GPT-5 72.0%, people 93.6%) | Apache-2.0 code. It tests the judge, not the designer: low priority |

## 2. CAD tools for LEGO® bricks, as builders use them

| Tool | Latest | What 2025–2026 added | What it has that Brickworks lacks |
|---|---|---|---|
| **BrickLink Studio** | 2.26.9_1, 30 Sep 2026; Early Access 2.26.9_1, 6 Oct [st-dl] | Flex control points that lock [st-flex]; a Sub-Assembly palette (2.26.6_1, Jun 2026); search by element ID (Early Access, Oct 2026); a view cube; 43 to 319 new parts in each release from Nov 2025 to Apr 2026; a LEGO® account for sign-in (2.25.9) [st-dl] [st-signin]. A Unity flaw pulled every older version from download [st-unity] | Prices and availability inline, with parts not sold in a colour hidden [st-price] [st-palette]. Live co-editing with chat [st-bt]. A Cycles path tracer, NVIDIA CUDA only [st-eyesight]. Instruction page design. Counted set palettes [st-palette]. The only door to the BrickLink Designer Program: "Submissions must be built in Studio" [bdp] |
| **Mecabricks** | No versions. The Blender add-on is at 2.1.17, Sep 2025, $25 [mb-shop] | Little. Version 2.0, expected "more likely for early 2024" [mb-2a], is unreleased, and users still ask in Sep 2026 [mb-2]. A forum regular says the render farm stays offline "until Mecabricks 2.0" [mb-farm] | A node animation editor; a Blender route with wear materials [mb-shop] |
| **LeoCAD** | 26.09, 20 Sep 2026 [lc-2609] | Undo across far more actions, a rotation gizmo, merging files, Chinese [lc-2609]. In 25.09: a train track layout editor and Blender rendering [lc-2509] | Track layouts, a Blender hand-off, translations |
| **LDCad** | 1.7 Beta 2b, 15 Mar 2026; last stable 1.6d2, 2022 [ld-dl] | Beta 2 after "over 2.5 years" [ld-b2] | Springs and rubber bands, and a scripting API for macros and animation [ld-features] |
| **Bricksmith** | 3.1, Feb 2022 [bs-vh] | None | "Insert Related" adds the matching tyre or glass [bs-vh] |
| **LPub3D, LDView** | v2.4.9, Jan 2025 [lpub]; 4.7, Feb 2026 [ldview] | LDView: STL options, headless rendering [ldview] | LPub3D: full instruction page layout [lpub] |
| **Blender importers** | ImportLDraw 1.3.0, 5 Oct 2026 [importldraw] | Prints and stickers drawn; a 58,000-brick model in about 20 s; reads Studio `.io` [importldraw] | Nothing: it reads the `.mpd` Brickworks writes, so our models reach Cycles this way too |
| **Newcomers** | Sim Studio, Sep 2026 [simstudio]; Gr8Brik, Oct 2026 [gr8brik] | Sim Studio: Technic mechanisms in a browser with gravity, friction and motors, "experimental" [simstudio]. Gr8Brik: a three.js editor in beta [gr8brik] | Sim Studio's rigid-body physics with motors |
| **LEGO® Builder app** | 4.3.9, 29 Sep, by the App Store [legobuilder] | Build Together: builders split a set's steps on their phones [legobuilder] | Instructions only; no design of your own |

### What builders ask for, and complain about

Counted over every post in r/bricklinkstudio (826) and r/DigitalLego (2,292)
since 2024 [arctic], 30 Eurobricks threads, about 20 on Rebrickable's forum,
and the LDraw and Mecabricks forums. Counts are lower bounds.

| # | Complaint or request | Seen | Examples |
|---|---|---|---|
| 1 | Studio updates break files and features; "never upgrade" mid-project | ~20 Reddit threads, 4 Eurobricks | "consider Studio as almost a perpetual beta" [r-break]; an update turned every 16 x 16 plate black [r-update] |
| 2 | Making instructions: lag, steps scrambled after an edit, weak automatic steps | 20+ people, 12 threads | Page Design "is the single biggest killer of my enthusiasm" [rb-io-pdf]; "An instruction maker that doesn't lag" [rb-dream]. BrickStep, an automatic generator, drew 82 posts in two months [rb-brickstep] |
| 3 | Lost, corrupt or unsaved files | ~13 Reddit threads, 2 Eurobricks | "nothing was saved and all the work lost" [eb-backup]; "unable to save my creations" [r-save]. Studio's own help: backups "can cause users to think that their model has disappeared" [st-backup] |
| 4 | Connecting, hinges, angles, collision | 10+ explicit complaints | "Pieces in studio jump and twist and won't connect" [eb-dream]; four hours on one step [eb-falcon] |
| 5 | A tablet, iPad, phone or Chromebook version | 25+ people | A home-made iPad Studio drew 35 comments and about 17 testers in a day [r-ipad]; "I don't have a computer, only a mobile phone" [eb-mobile] |
| 6 | Slow renders; the GPU unused on AMD and new NVIDIA cards | 12+ | "I've left it up for 3 days and it never finished" [r-render] |
| 7 | Technic mechanism simulation | ~10 | "every Technic builder in the world will beat a path to your door" [eb-dream]; a teacher wrote a gear simulator to fill the gap [r-gear] |
| 8 | Flexible parts | ~10 | "Trying to build something with flexible parts is a nightmare" [rb-flex] |
| 9 | Mac breakage, blurry on HiDPI screens, Linux | ~25 together | macOS 14.2 stopped mouse clicks for two months [eb-mac]; "Studio looks awful and blurry" [r-hidpi]; no working Studio on Linux [r-linux] |
| 10 | Sign-in broke when BrickLink accounts became LEGO® accounts | 3 Reddit threads | cannot sign in to Studio since the merge, in Oct 2025 [r-signin] |
| 11 | Buying the parts | 2 threads, 5 tools builders wrote themselves | "overwhelmed by the seller options" [r-buy]; Pick a Brick availability palettes [r-pab] |
| 12 | Live co-editing | ~6, nearly all on the Mecabricks forum before 2024 | Few asks in 2024–2026 |

**The painful workflows**, in builders' order:
1. Making instructions [rb-io-pdf].
2. Getting a design onto Rebrickable, where a premium design needs a PDF
   [rb-io-pdf].
3. Buying the parts [r-buy].
4. Moving between tools. A Mecabricks model opened in Studio had "half the
   pieces ... upside down" [mb-export]. LDCad loses a custom part's
   connections from Studio [ld-roundtrip]. Many still render through
   Mecabricks and Blender [eb-dream].
5. Renders [r-render].
6. Angled and sideways building [eb-falcon].

**What makes a builder switch.**
- LDD's retirement moved people to Studio. One "made the switch to Stud.io
  and have never looked back" [eb-noob].
- Studio failing for weeks sends them looking for another [r-alt].
- Flexible parts and speed send some to LDCad [rb-flex] [r-ldcad].
- What stops some trying the others: LDCad "seems difficult to use", and
  Mecabricks "seems to get stuck loading pieces" [eb-which].

**What holds them.** Studio's ecosystem holds most: "I don't know anyone
that is not using Studio" [rb-tools]. One Eurobricks member: "definitely
make an instructions tab, I don't think I'd switch without it" [eb-dream].
A post about a new brick CAD on r/lego on 2026-10-13 got "Studio exists,
LDD exists" [r-newcad].

**What builders say about AI.**
- **Mostly hostile.** Rebrickable's rule: "AI generated models are not
  permitted" [rb-ai]. It no longer lists auto-generated designs either,
  mosaics included (an admin, Dec 2025) [rb-mosaic].
- **On r/lego**, an AI picture scored −44 [r-ai1], and "AI adds nothing to
  the experience" [r-ai2].
- **LEGO® Ideas** refuses work "assisted using any artificial intelligence"
  tools, quoted by a fan site [hoth]. *Unverified*: the terms page refused
  us.
- **The common doubt** is physics: "they need to understand physics" [rb-aitrain].
- **The welcome use** is an AI checked by exact tools. One builder: "It
  could even get a tool, like BrickLink Studio's Stability Tool to check"
  [rb-aitrain].
- **So** Brickworks' assistant being off until asked for
  ([CHANGELOG.md](../CHANGELOG.md)) is right. Its exact checks are what to
  lead with.

## 3. Ten units, ranked

Ranked by how far each moves the owner's two goals, the best CAD and the
best AI designer, by evidence. Each is one agent's bounded unit with a proof
an agent can run. **Catch up** means another tool or paper has it. **Leap**
means none was found, and it is within reach.

| Rank | Unit | Kind |
|---|---|---|
| 1 | Put the designer on BrickBench | catch up: 13 systems measured, Brickworks not |
| 2 | Score the booklet against real sets' own steps, then gate it | leap |
| 3 | Give the stability check a measured accuracy | leap |
| 4 | Judge design rounds in pairs | catch up: BrickBench's method |
| 5 | Models that cannot vanish from a browser | catch up: Studio keeps backups |
| 6 | Racks and steering in Simulate | leap among current tools |
| 7 | Build on a tablet, measured | catch up: Mecabricks |
| 8 | A Brickworks `.io` seen opening in Studio | catch up |
| 9 | The model inline in Claude, through MCP Apps | catch up: two small servers |
| 10 | Check the brief's questions before a design is handed over | leap |

### Catch up

**1. Put the designer on BrickBench.**
- *What.* Ten Model-setting prompts through the real loop on the
  subscription, parts limited to BrickNet's 14,441. Write `model.mpd` and
  a `build.py` that places the same parts, with rotations made orthonormal
  for its check [bb-repo].
- *Then.* Run `verify.py`. Run `check_submission.py` and send the zip
  through their form. Until the authors score it, also judge our builds
  against BrickAgent's Opus 5.5 builds of the same prompts from the gallery
  [bb-gallery], marked as our judge and not theirs.
- *Proof.* `verify.py`'s report for the ten, and the table beside their
  Table 1, committed.
- *Why first.* It is the only external ruler, and 13 systems are on it.
  The same model has a published score there: VQA 0.952, Design ELO 1252,
  $5.90 a build [bb]. Every claim about our designer rests on our own judge
  until this runs.

**4. Judge design rounds in pairs.**
- *What.* `tools/bench` gets a pairwise mode: two designs of one subject,
  four views each, both orders, judged on the subscription. Fit
  Bradley–Terry with the existing rounds as anchors, as BrickBench does
  [bb].
- *Proof.* Re-judge the rounds already in `bench/results`, and publish ELO
  with intervals in `DESIGN_SCORES.md`. Show whether rounds that were "a
  null" on the 1–10 scale separate.
- *Why fourth.* The 1–10 means move less than the run-to-run spread
  ([DESIGN_SCORES.md](DESIGN_SCORES.md)), so a design change cannot show it
  worked. BrickBench's pairwise judge agreed with 102 people on 34 of 36
  pairs [bb]. Every later design unit is judged by this.

**5. Models that cannot vanish from a browser.**
- *What.* On the web, a person's models live only in the browser
  ([schema.sql](../supabase/schema.sql): "There is deliberately no table of
  models").
  - Browsers may evict such storage unless the page calls
    `navigator.storage.persist()` [mdn-storage].
  - Safari deletes a site's script-made data after seven days without a
    visit [mdn-storage]. The app makes no such call (`grep` finds none).
- *The unit.*
  - Call `persist()` at the first save, and show its state in Settings.
  - Keep each model's last 20 saves, with File, Earlier versions to bring
    one back as one undo.
  - On Safari, show a line saying the browser can delete models, with
    Download all.
- *Proof.* A browser flow saves three versions and restores the second,
  and Settings shows what `navigator.storage.persisted()` answered.
- *Why fifth.* Lost and broken files are two of builders' top three
  complaints. A lost model is the worst thing a CAD can do. The fix is
  small.

**7. Build on a tablet, measured.**
- *What.* A browser flow at iPad sizes (1024 x 1366 and 1180 x 820), with
  touch only: place 30 parts, turn, recolour, undo, save. Fix what fails.
- *Proof.* The flow passes under `heavy`.
- *Why seventh.* More than 25 people asked for a tablet version, and an
  unofficial iPad Studio found testers in a day [r-ipad]. Studio is
  desktop-only [st-dl]. Brickworks has a phone layout and Build mode, but
  tablets were never measured ([COMPETITIVE.md](COMPETITIVE.md)).

**8. A Brickworks `.io` seen opening in Studio.**
- *What.* Run Studio under Wine on this machine. One builder reports it
  works on kubuntu [eb-linux], another that it locks up [r-linux]; Studio
  itself says NVIDIA only [st-dl]. Open our car's `.io` and fix what it
  shows.
- *If Studio will not start.* Record that in the recipe, and keep "not yet
  seen opening in Studio" in the changelog.
- *Proof.* A screenshot of the model in Studio, and the recipe.
- *Why eighth.* Builders stay because of Studio's ecosystem [rb-tools], and
  the BrickLink Designer Program takes only Studio files [bdp]. So a file
  that goes back to Studio is how a Studio builder can try Brickworks at
  no risk.

**9. The model inline in Claude, through MCP Apps.**
- *What.* Since 2026-01-26, any MCP server can show interactive UI in
  Claude on the web, desktop and mobile [mcpapps]. It is served as a
  `ui://` resource named in a tool's `_meta` [mcpapps-spec].
- *The unit.* The connector serves one: the session's model as a turntable
  and its steps, from pictures the app already renders, so a person
  designing in claude.ai sees the model without another tab.
- *Proof.* The resource reads back over MCP, and a recipe opens it in
  claude.ai.
- *Why ninth.* Two small servers already do this [bbmcp] [brickmcpapp].
  The owner builds this way. But only Claude users gain.

### Leap

**2. Score the booklet against real sets' own steps, then gate it.**
- *What.* A probe takes held-out files from LDraw's model repository, whose
  steps are meant to follow the official instructions [omr-spec]. It plans each with
  `Instructions.plan` and reports four measures:
  - Kendall τ between our order and the author's, the measure used for
    LEGO® assembly sequences in [gt-asp];
  - the share of steps with a new part hidden from the step's view, the
    "strongest design principle" in Agrawala et al. [agrawala];
  - steps over 10 parts or 5 kinds, the rule MEPNet built its synthetic
    manuals with [mepnet];
  - and every intermediate state that fails `Stability.check`, as APEX-MR
    prunes [apexmr].
- *Then.* Fix the worst of the four with one gate.
- *Proof.* The four numbers over the same sets, before and after,
  committed.
- *Why second.* Instructions are builders' most painful workflow
  [rb-io-pdf] [rb-brickstep], and the lack of them keeps people from
  switching [eb-dream]. No tool found measures its automatic steps against
  official ones, and we hold the files.
- *Caution.* A patent of the LEGO Group describes instructions generated by
  taking a model apart. Google Patents shows it active until 2030-03-17, a
  status it calls "an assumption" [patent]. Our planner builds forward;
  keep it that way, and ask counsel before changing it.

**3. Give the stability check a measured accuracy.**
- *What.* Turn StableLego's test structures into LDraw and run
  `Stability.check` on them [stablelego-repo]: the 19-step stairs that
  stand and the 20 that fall, the stick with two loads and with three. Add
  a sample of StableText2Brick's structures, which its authors call
  "physically stable" and score brick by brick [bgpt] [s2b]. Those scores
  are computed, not built, so they test agreement, not truth.
- *Then.* Report agreement and false alarms, and compare our clutch with
  their 0.98 N a stud [stablelego]. Ask BrickSim's authors for their 150
  labelled real builds [bricksim].
- *Proof.* A probe and an agreement table, committed.
- *Why third.* No CAD publishes how often its stability check is right.
  Studio calls its own "very conservative" [st-stab], and BrickBench's
  check leaves the holding force of studs unmodelled [bb]. This turns Brickworks' central claim
  into a number, on a CPU, in one unit.

**6. Racks and steering in Simulate.**
- *What.* A prismatic joint for a rack driven by a pinion, which
  [MECHANISMS.md](MECHANISMS.md) lists as left. Prove it on a Technic
  steering rack from the model repository: a turn of the wheel moves the
  rack by the pitch the closed form gives.
- *Proof.* A probe against the closed form, and the rack moving in
  Simulate's recording.
- *Why sixth.* Builders ask for this in so many words [eb-dream] [r-gear].
  Studio's animation builds the model or turns the camera [st-anim]. No
  mechanism simulation was found in LeoCAD's notes [lc-2609] [lc-2509].
  Sim Studio, a browser simulator with motors, calls itself "experimental"
  [simstudio]. SR 3D Builder, whose last version dates from 2014 [sr3d], is
  recorded in [MECHANISMS.md](MECHANISMS.md) as having animated racks (that
  record was not re-read today). It builds on a lead we already have.

**10. Check the brief's questions before a design is handed over.**
- *What.* BrickBench breaks each prompt into a graph of yes or no questions
  and scores what renders show [bb]. Its agents meet texture questions only
  49–83% of the time [bb]. CADCodeVerify uses the same kind of questions
  to check a CAD model [cadverify].
- *The unit.* The designer writes those questions from the brief at the
  start. Before `submit_design` ends the loop, a check answers each on the
  model's own renders, and sends back the failures once.
- *Proof.* Five held-out subjects with and without the check, judged in
  pairs (unit 4), and the share of questions met.
- *Why tenth.* It aims at likeness and at BrickBench's VQA. PVPO shows that
  a loop which only checks stability can drift from the subject [pvpo].
  But its proof waits on unit 4.

### Considered, not in the ten

- **BrickLink prices.** Studio shows them [st-price], and one MCP server
  reads price guides with the user's own BrickLink API keys
  [bricklink-mcp]. Whether any member can get those keys was not checked.
- **Rubber bands and springs** (LDCad [ld-features]). Builders ask for
  flexible parts in general more than for these [rb-flex].
- **A part from a photo.** Brickognize's API declares no key [brickognize],
  but its terms were not readable, so whether it may be used from an app
  is open.
- **Listing the connector** in the official MCP registry. No server that
  builds models is listed, and "brickworks" returns nothing
  [registry]. A small task; do it anyway.
- **A path tracer.** ImportLDraw and our glTF export already reach Blender
  [importldraw].
- **Live co-editing.** Studio has it [st-bt], but few asked in 2024–2026.
- **BrickNet's data.** It is closed to anything but academic use
  [bricknet-repo].

## Sources

All read on 2026-10-14.

**Benchmarks and research**

[bb]: https://arxiv.org/html/2610.12452v1
[bb-repo]: https://github.com/kulits/BrickAgent
[bb-verify]: https://github.com/kulits/BrickAgent/blob/master/scripts/verify.py
[bb-vlm]: https://github.com/kulits/BrickAgent/blob/master/scripts/vlm.py
[bb-gallery]: https://gallery.brickben.ch/
[bgpt]: https://arxiv.org/html/2505.05469v3
[bgpt-repo]: https://github.com/AvaLovelace1/BrickGPT
[s2b]: https://huggingface.co/datasets/AvaLovelace/StableText2Brick
[stable]: https://arxiv.org/html/2605.06947v1
[stable-repo]: https://github.com/miniHuiHui/STABLE
[banything]: https://arxiv.org/html/2605.26182v2
[banything-repo]: https://github.com/xjtunzy/BrickAnything
[resem]: https://arxiv.org/html/2608.09597v1
[bricknet]: https://arxiv.org/html/2604.22984v1
[bricknet-repo]: https://github.com/kulits/BrickNet
[legoace]: https://xjtang.com/assets/files/publications/2025Lego/main.pdf
[legoace-hf]: https://huggingface.co/VAST-AI/LegoACE
[stablelego]: https://arxiv.org/html/2402.10711v2
[stablelego-repo]: https://github.com/intelligent-control-lab/StableLego
[bricksim]: https://arxiv.org/html/2603.16853v1
[bricksim-repo]: https://github.com/intelligent-control-lab/BrickSim
[pvpo]: https://arxiv.org/html/2606.07602v2
[legopuzzles]: https://arxiv.org/html/2503.19990
[cadverify]: https://arxiv.org/abs/2410.05340
[agrawala]: https://graphics.stanford.edu/papers/assembly_instructions/assembly.pdf
[heiser]: https://graphics.stanford.edu/papers/assembly_instructions_study/assemblyuserstudy.pdf
[asmbench]: https://arxiv.org/html/2605.12845
[legomaker]: https://api.crossref.org/works/10.1145/3763285
[treesba]: https://arxiv.org/abs/2407.15648
[bcomposer]: https://arxiv.org/abs/2606.05445
[cadassist]: https://arxiv.org/html/2412.13810
[mepnet]: https://arxiv.org/html/2207.12572
[apexmr]: https://arxiv.org/html/2503.15836
[gt-asp]: https://arxiv.org/abs/2210.05236
[patent]: https://patents.google.com/patent/US7979251B2/en
[omr-spec]: https://www.ldraw.org/article/593.html

**Products and services**

[nova]: https://github.com/anteloc/ldraw-nova
[bforger]: https://brickforgerai.com/
[bforger-help]: https://brickforgerai.com/help
[bbuilder]: https://brickbuilder.ai/
[legomcp]: https://github.com/Axel-Jalonen/lego-mcp
[bbmcp]: https://github.com/jonx/BrickBuilderMCP
[brickmcpapp]: https://github.com/dend/brick-mcp-app
[bricklink-mcp]: https://github.com/Irongenie/bricklink-mcp
[brickognize]: https://api.brickognize.com/openapi.json
[registry]: https://registry.modelcontextprotocol.io/v0/servers?search=brickworks
[mcpapps]: https://claude.com/resources/articles/interactive-tools-in-claude
[mcpapps-spec]: https://blog.modelcontextprotocol.io/posts/2025-11-21-mcp-apps/
[mdn-storage]: https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria

**CAD tools**

[st-dl]: https://www.bricklink.com/v3/studio/download.page
[st-help-api]: https://studiohelp.bricklink.com/api/v2/help_center/en-us/articles.json
[st-flex]: https://studiohelp.bricklink.com/hc/en-us/articles/6481921905303-Flexible-parts
[st-bt]: https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767-Build-Together
[st-eyesight]: https://studiohelp.bricklink.com/hc/en-us/articles/6505772624023-Photoreal-Eyesight-options
[st-price]: https://studiohelp.bricklink.com/hc/en-us/articles/5705572363159-Parts-prices-and-availability
[st-palette]: https://studiohelp.bricklink.com/hc/en-us/articles/5428782263447-Building-palette
[st-stab]: https://studiohelp.bricklink.com/hc/en-us/articles/6501498505111-Stability-check
[st-backup]: https://studiohelp.bricklink.com/hc/en-us/articles/38269468384151-Studio-Backup-Files
[st-signin]: https://studiohelp.bricklink.com/hc/en-us/articles/35041828645143-Studio-v-2-25-9-Critical-Update-released
[st-unity]: https://studiohelp.bricklink.com/hc/en-us/articles/35810236794135-Studio-Critical-Update-v-2-25-10-1-EA-2-25-10-2
[bdp]: https://blocksmag.com/submissions-open-for-lego-bricklink-designer-program-series-10/
[mb-shop]: https://www.mecabricks.com/en/shop/product/4
[mb-2a]: https://www.mecabricks.com/en/forum/topic/69160
[mb-2]: https://www.mecabricks.com/en/forum/topic/69160/21
[mb-export]: https://www.mecabricks.com/en/forum/topic/61390
[ld-roundtrip]: https://forums.ldraw.org/thread-28625.html
[st-anim]: https://studiohelp.bricklink.com/hc/en-us/articles/6507015818263-Animation
[mb-farm]: https://www.mecabricks.com/en/forum/topic/76310
[lc-2609]: https://github.com/leozide/leocad/releases/tag/v26.09
[lc-2509]: https://github.com/leozide/leocad/releases/tag/v25.09
[ld-dl]: http://www.melkert.net/LDCad/download
[ld-features]: http://www.melkert.net/LDCad/features
[ld-b2]: https://forums.ldraw.org/post-59566.html
[bs-vh]: https://bricksmith.sourceforge.io/VersionHistory.html
[lpub]: https://github.com/trevorsandy/lpub3d/releases
[ldview]: https://github.com/tcobbs/ldview/releases/tag/v4.7
[importldraw]: https://github.com/TobyLobster/ImportLDraw/releases/tag/v1.3.0
[simstudio]: https://github.com/WorketeWorks/SimStudio-LEGO-Technic-Physics-Simulator
[gr8brik]: https://github.com/susstevedev/gr8brik
[sr3d]: https://wiki.ldraw.org/wiki/Sr3d
[legobuilder]: https://apps.apple.com/us/app/lego-builder-3d-instructions/id1486159728

**Builders**

[arctic]: https://arctic-shift.photon-reddit.com/
[r-break]: https://www.reddit.com/r/bricklinkstudio/comments/1wvcemm/
[r-update]: https://www.reddit.com/r/bricklinkstudio/comments/1ue9ed0/latest_update/
[r-save]: https://www.reddit.com/r/bricklinkstudio/comments/1p6wtwr/
[r-ipad]: https://www.reddit.com/r/DigitalLego/comments/1tm9kaz/
[r-render]: https://www.reddit.com/r/bricklinkstudio/comments/1oxyrkd/time_to_render/
[r-gear]: https://www.reddit.com/r/DigitalLego/comments/1p1rbfd/
[r-hidpi]: https://www.reddit.com/r/DigitalLego/comments/1kl0x2m/
[r-linux]: https://www.reddit.com/r/DigitalLego/comments/1shtl7q/
[r-alt]: https://www.reddit.com/r/bricklinkstudio/comments/1r3kmjy/
[r-ldcad]: https://www.reddit.com/r/DigitalLego/comments/1b4rpkg/
[r-signin]: https://www.reddit.com/r/bricklinkstudio/comments/1ohoy4d/
[r-buy]: https://www.reddit.com/r/Bricklink/comments/1weghph/
[r-pab]: https://www.reddit.com/r/bricklinkstudio/comments/1vwk15g/
[r-newcad]: https://www.reddit.com/r/lego/comments/1x4sj2s/
[r-ai1]: https://www.reddit.com/r/lego/comments/1wrxth9/
[r-ai2]: https://www.reddit.com/r/lego/comments/1vvlpfk/
[eb-dream]: https://www.eurobricks.com/forum/forums/topic/213692-what-features-would-you-have-in-your-dream-lego-cad/
[eb-which]: https://www.eurobricks.com/forum/forums/topic/212517-which-lego-cad-software-in-2026/
[eb-backup]: https://www.eurobricks.com/forum/forums/topic/207709-recovering-studio-backup-file/
[eb-falcon]: https://www.eurobricks.com/forum/forums/topic/212088-ucs-millennium-falcon-75192-part-collision-issues-in-studio/
[eb-mobile]: https://www.eurobricks.com/forum/forums/topic/197304-lddstudio-for-mobile/
[eb-noob]: https://www.eurobricks.com/forum/forums/topic/213436-couple-of-question-from-a-noob-considering-digital-design-at-some-point-in-the-future/
[eb-linux]: https://www.eurobricks.com/forum/forums/topic/210429-studio-linux/
[eb-mac]: https://www.eurobricks.com/forum/forums/topic/197047-studio-and-mac-big-issue-with-mouse-input/
[rb-io-pdf]: https://forum.rebrickable.com/t/drawbacks-of-releasing-the-io-file-versus-pdf/169084
[rb-dream]: https://forum.rebrickable.com/t/what-features-would-your-dream-lego-cad-have/173928
[rb-brickstep]: https://forum.rebrickable.com/t/brickstep-automatic-instruction-generator-for-lego-models/174227
[rb-flex]: https://forum.rebrickable.com/t/preferred-digital-building-platform/167455
[rb-tools]: https://forum.rebrickable.com/t/what-software-should-i-use-to-create-good-instructions/169284
[rb-ai]: https://forum.rebrickable.com/t/drawing-the-line-on-ai-generated-content/174669
[rb-mosaic]: https://forum.rebrickable.com/t/free-open-source-lego-mosaic-generator/170395/6
[rb-aitrain]: https://forum.rebrickable.com/t/exclude-ai-training/172438
[hoth]: https://en.hothbricks.com/lego-et-lutilisation-de-lintelligence-artificielle-ce-qui-est-vrai-et-confirme-et-ce-que-les-fans-croient-savoir/
