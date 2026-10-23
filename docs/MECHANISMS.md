# Mechanisms: gears that turn, and models that stand while they do

The owner asked for "the ability to build and record accurate physics
simulations of gear/Technic mechanics". Two more things were added on
2026-10-13:

- **The acceptance demo is a working orrery of LEGO® bricks.** It is a gear train whose
  ratios give each planet its real orbital period relative to the others. A
  crank or a motor drives it, and it is simulated and recorded. It should be
  the first thing that works end to end.
- **Balance and strength.** Claude flagged this itself on the owner's orrery:
  "Brickworks checks that the parts connect, not physical balance… Neptune's arm
  still reaches about 18 studs past the base edge, so swing that arm hard at
  your own risk."

This file is the research and the plan. Phase P1a's core is
`src/assembly/mechanism.gd`, with its gear table `assets/ldraw/gears.json`.
It is proven by `src/dev/mechanism_probe.gd` and, on real sets,
`src/dev/mechanism_sets.gd`. Phase P1b put it in the app: Tools, Simulate
mechanism (`src/ui/simulate_panel.gd`, over `src/assembly/simulation.gd`), and
`simulate_mechanism` over MCP, with P1c's period readout; proven by
`src/dev/simulate_probe.gd` and `tools/mcp_check.py` (recipes in
`.claude/skills/verify/features/geometry.md`; section 8 below). P1c's ratio
search is `src/assembly/gear_ratios.gd` (`search_gear_ratio` over MCP), proven
by `src/dev/gear_ratio_probe.gd`, and the eight-planet orrery a Claude session
built with it is `models/orrery.ldr` (section 9).

## In short

- **Kinematics comes first and is mostly solved already.** The parts already
  record their axles, pins, holes and studs. A gear's pitch radius is 1.25 LDU
  per tooth. That number was measured on real sets: 764 of 809 candidate gear
  pairs in the OMR's Technic sets agree to 0.3 LDU or better.
- **The core works on real sets.** It is one linear equation per coupling
  and one unknown per joint. It turns the windmill of LEGO® set 8020 9:1 from
  crank to sails, read straight off the set's file, with every frame of the
  drawing checked against the tooth counts. It turns a two-planet orrery, a
  12 inside a 140 tooth ring, a chain, a gearbox with a driving ring and a
  differential, whose sides' rates sum to twice its casing's. It reports a
  locked train and names the meshes that lock it. It reads 42055 and 42082,
  the OMR's two sets with the most gears, in two seconds each, and every gear
  in them turns on something or the file says why not (section 7).
- **The orrery needs only that core** (phase 1) plus a Simulate mode, a ratio
  readout in planet years, and turntables and ring gears. Linkages (phase 2)
  and dynamics (phase 3) are not on its path.
- **Balance is a check across the whole motion, not at rest.** Phase S1
  computes the centre of mass and the tipping margin at every frame of the
  cycle. This catches Neptune's arm at the angle where it hangs furthest out.
  It also computes the moment every stud joint carries against its capacity,
  with the capacities cited below. Dynamic loads are small for an orrery: a
  planet's centripetal force is under a fifth of its weight. They matter for
  fast arms and come later (S2).
- **"Accurate" means different things in each phase.** Kinematics can be
  exact. Statics can be honest to about a factor of two, because nobody has
  published a measured clutch force for LEGO® bricks. Dynamics would be qualitative. The
  section [What "accurate" can honestly mean](#what-accurate-can-honestly-mean)
  says why.

## 1. What exists elsewhere

**No tool for LEGO® models simulates dynamics.** The ones that move mechanisms all do
driven kinematics: a driver moves, and everything else is solved from
constraints.

| tool | what it does | how | source |
|---|---|---|---|
| SR 3D Builder (Reano, last release 2014, abandoned) | Detects connections and rotation axles. Animates gear trains, differentials, racks, worms, linear actuators, pneumatics, Jansen linkages and flexible parts. | Kinematic solver with a pre-pass that finds "triangled undeformable structures" (rigid groups). Large models solve slowly. Meshing was never documented. No gravity or collisions. | [ldraw wiki](https://wiki.ldraw.org/wiki/Sr3d), [0.6.0.8 notes](https://forums.ldraw.org/thread-1212.html), [0.8.9.16 notes](https://forums.ldraw.org/printthread.php?tid=9215) |
| LDCad (Melkert) | Animation by Lua script. Flexible parts (hoses, chains, springs) are generated along paths. | Nothing is inferred: the script sets every part's pose each frame. The author said gear trains "need extra information on many parts (tooth count, radius, gear type, etc)". | [script API](https://www.melkert.net/LDCad/docs/scriptAPI), [forum 2021](https://forums.ldraw.org/post-42067.html), [meta](https://www.melkert.net/LDCad/tech/meta) |
| BrickLink Studio | Hinge tool (turns everything connected about one pivot, with collision on mouse drags). Flex tool. Animation renders only building steps and camera turns. | No mechanism simulation. | [hinge](https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351-Hinge-and-Rotation-tool), [render](https://studiohelp.bricklink.com/hc/en-us/articles/6507015818263) |
| Mecabricks | Keyframe and node animation with parenting. | Hand-made math. Gear-train inference was requested in 2020 and never answered. | [Brickset](https://brickset.com/article/53762/mecabricks-let-s-animate-our-bricks!), [Eurobricks](https://www.eurobricks.com/forum/forums/topic/177590-mecabricks-animation-tools) |
| LeoMCAD (CEIG 2018) | Mechanical CAD for LEGO® models with typed gear connectors (regular, crown, rack, worm, bevel). | Propagates motion depth-first. Constraints are enforced while assembling, not while simulating, so it moves mechanisms that Inventor locks. | [paper](https://diglib.eg.org/handle/10.2312/ceig20181163) |
| TechnicBrickPower calculator (2021) | Upload an .ldr, click a gear, read the ratios. | Shows underconstrained differentials. With several motors it gives weighted sums. No chains, and it is sensitive to part orientation. | [Eurobricks](https://www.eurobricks.com/forum/forums/topic/186656-new-technic-gear-ratio-calculator-tool) |

**Research we can build on:**

- **Coros et al. 2013, *Computational Design of Mechanical Characters*.** This
  is the template for phases 1 and 2.
  - Each part has a pose. A pin adds 6 equations and removes 5 freedoms. A gear
    pair is a phase relation, α_i = −r·α_j.
  - Each step advances the driver and minimises ½CᵀC by Newton–Raphson.
  - An over-constrained mechanism shows as a non-zero minimum. An
    under-constrained one shows as a singular Hessian.
  - Unlike a tree walk, it closes loops.
  
  [pdf](https://studios.disneyresearch.com/wp-content/uploads/2019/03/Computational-Design-of-Mechanical-Characters-1.pdf)
- **Mitra et al. 2010, *Illustrating How Mechanical Assemblies Work*.** It
  infers axes and tooth counts from shape and classifies pairs as spur, bevel
  or rack. Motion spreads breadth-first from a driver as ω₂ = ω₁·r₁/r₂.
  [pdf](https://www.cs.princeton.edu/courses/archive/spring11/cos598A/pdfs/Mitra10b.pdf)
- **Xu et al. 2019, *Computational LEGO® Technic Design*.** It builds models
  from sketches with motion annotations and analyses balance and stress.
  [arXiv](https://arxiv.org/abs/2007.02245)
- **Luo et al. 2015, *Legolization*, and StableLego (Liu et al., CMU, 2024).**
  Both model brick stability with forces at the studs. StableLego is below
  under clutch. [Legolization](https://history.siggraph.org/?p=210389),
  [StableLego](https://arxiv.org/html/2402.10711v2)
- **Counting freedoms needs care.** Grübler's formula fails when constraints
  are redundant: it calls a parallelogram linkage rigid when it has one degree
  of freedom. Technic is full of parallelograms, so the rank has to be
  computed numerically.
  [Modern Robotics §2.2](https://hades.mech.northwestern.edu/images/2/25/MR-v2.pdf)
  The pebble game finds rigid clusters combinatorially.
  [(k,l) frameworks](https://web3.arxiv.org/pdf/math/0702129)

**How mechanical CAD separates kinematics from dynamics:**

- **Onshape.** Mates are solved together, so their order doesn't matter. Gear,
  rack-and-pinion and screw "relations" couple two mates by a ratio, and are
  not physics. There is exactly one mate between any two instances. Animate
  drives one mate and enforces the rest.
  [relations](https://cad.onshape.com/help/Content/relations.htm),
  [mates](https://cad.onshape.com/help/Content/Assembly/mates.htm)
- **SolidWorks** has three tiers:
  - *Animation* interpolates keys and motors.
  - *Basic Motion* approximates gravity, springs and contact.
  - *Motion Analysis* computes forces, friction and inertia.
  
  It removes redundant mates automatically, which can give wrong forces. Its
  advice is that redundancy "matters less for purely kinematic results".
  [Javelin 2018](https://www.javelin-tech.com/blog/2018/02/solidworks-motion-simulation/),
  [Javelin 2025](https://www.javelin-tech.com/blog/2025/02/mate-redundancies-in-solidworks-motion-simulation/)
- **Fusion.** Motion links tie joints by a ratio. A motion study drives them.
  Contact sets are costly, and support staff advise against them (search
  snippets only; Autodesk's pages refused the fetch).
  [Autodesk](https://www.autodesk.com/learn/ondemand/tutorial/create-realistic-motion-in-assemblies)

All three put kinematics first, as relations between joints, and make physics
an opt-in layer that reuses the same joints. This plan does the same.

**Godot 4.7 and Jolt:**

- **Availability.** Jolt has been built in since Godot 4.4 and is the default
  for new 3D projects since 4.6. [4.6 release](https://godotengine.org/releases/4.6/)
- **Joints.** `HingeJoint3D` maps to Jolt's `HingeConstraint`, with a velocity
  motor whose torque limit is `max_impulse / step`. `SliderJoint3D` maps to a
  `SliderConstraint`. Some properties (softness, bias, relaxation) are ignored.
  [docs](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html),
  [hinge source](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp)
- **No gear or rack joint in Godot.** `PhysicsServer3D` has pin, hinge, slider,
  cone-twist and 6DOF only. Jolt itself has `GearConstraint` and
  `RackAndPinionConstraint` (each using its two hinges to correct drift), but
  Godot does not expose them; that would take a GDExtension.
  [Godot](https://docs.godotengine.org/en/latest/classes/class_physicsserver3d.html),
  [GearConstraint](https://jrouwe.github.io/JoltPhysics/class_gear_constraint.html),
  [RackAndPinion](https://jrouwe.github.io/JoltPhysics/class_rack_and_pinion_constraint_settings.html)
- **Defaults are metric and capped.** The penetration slop and speculative
  distance are 2 cm, the convex radius is 5 cm, and the maximum angular
  velocity is **2700°/s (450 rpm)**. A Power Functions L motor at 390 rpm
  geared up 40:8 would be clamped. The scale of LEGO® bricks needs the world scaled or the
  settings changed.
  [settings](https://raw.githubusercontent.com/godotengine/godot/master/modules/jolt_physics/jolt_project_settings.cpp)
- **Determinism and the web.** Jolt is deterministic only with the same binary
  and the same order of calls; across platforms it needs a build flag. Godot
  promises nothing. The web build is single-threaded, so Jolt runs serially
  there. [Jolt](https://jrouwe.github.io/JoltPhysics/)

## 2. What our data already gives, measured

The pipeline records every part's connectors (`tools/ldraw/connectivity.py`,
`Lbm.Connector`). They map onto a mechanism like this:

| connector meeting | what it is | read by |
|---|---|---|
| axle (male) through an `axle_hole` | rigid: the hole's part turns with the axle | `Mechanism`: holes on an axle's line, within its length |
| axle or pin through a `pin_hole`, or a whole bore of radius 6 (an axle's size) | revolute about the line | the same |
| stud in a socket (`PartMesh.sockets`, at the part's underside) | rigid | `Mechanism` |
| two revolutes between the same two bodies on different lines | rigid: two pins through two beams | `Mechanism`, repeated until nothing changes |
| a pin that carries nothing keyed | not a body: what it joins turn against each other on its line | `Mechanism` |
| a turntable's top on its base | revolute about the base's axis | `Mechanism` (the table's `turntables`); `Joints.rounds` already pairs them for the checker |
| a differential's planet on the stub inside its casing | revolute about the stub | `Mechanism` (the table's `stubs`: no connector records the stub) |
| a driving ring on its ridged joiner, and in a clutch gear it reaches 4 LDU into | rigid | `Mechanism` (the table's `driving_rings`, `ring_carriers`, `clutch_gears`) |
| a ring gear nothing it is fixed to turns on, meshing a gear on something that does | revolute about its own centre, on what carries that gear: it rides on rollers round its rim | `Mechanism` (a "rim" joint) |
| a shaft in a coaxial bore of its size (clip on bar, hinge, turntable) | revolute | `Joints.rounds`, which the Poser already turns |

**Gears: the tooth count is only in the name.** "Technic Gear 24 Tooth" is the
only place the catalogue says 24. The table `assets/ldraw/gears.json` keeps
each gear's kind, tooth count, hole (axle or round), the offset of its pitch
plane for right-angle meshes and where its teeth are along its axis. It sits
beside `ldd.json` rather than in `assets/knowledge`, which the web build
leaves out of its pack. A pitch radius of 1.25 LDU per tooth is module 1 mm. That
matches [BrickNerd's](https://bricknerd.com/home/everything-you-want-to-know-about-lego-gears-5-10-24)
"teeth/16 studs", and it was measured on every gear in the 354 Technic sets in
`vendor/omr` (the 42xxx and 8xxx files). The method:

1. Flatten each set with `tools/omr.py`'s `_flatten`.
2. Take each gear's axis as its local z through its origin (a turntable's as
   its local y).
3. For every pair, measure:
   - parallel axes: the centre distance across the axis, and how far apart
     along it;
   - axes at right angles that cross: each origin's distance from the
     crossing;
   - a worm: the distance between the two axis lines.

`tools/gears.py measure` is that measurement, kept: over the 363 Technic sets
the OMR has now, 855 parallel pairs in one plane stand within 8 LDU of
meshing, 750 of them to 0.1 LDU and 67 more to 0.3. `tools/gears.py check`
and `tests/test_gears.py` hold the table to the catalogue's names (every
Technic part named with a tooth count is in it, or set aside with a reason),
to the parts' own connectors (each gear has the hole the table says, on its
axis), to module 1 mm (a spur gear is 2.5 (N + 2) LDU across) and, on 42055,
42082 and 8020, to the spacing above.

- **Parallel gears in one plane within 8 LDU of meshing: 809 pairs.**
  - 722 stand at 1.25·(N₁+N₂) LDU apart to 0.1 LDU.
  - 42 more stand within 0.3 LDU. Most are 16 and 20, or 12 and 24, on a
    stud's diagonal: 44.7 for 45.
  - 5 are within 1 LDU.
  - The other 40 are 1.2 to 6.6 LDU out: neighbours, not meshes.
  
  The commonest are 16+16 at 40 (426 pairs), 12+20 double bevels at 40 (107),
  8+24 at 40 (93), 8+8 at 20 (40) and 24+24 at 60 (19).
- **At right angles, where the axes cross:** each gear's origin stands at the
  other's pitch radius plus its own face offset from the crossing.

  | pair | each gear's distance from the crossing (LDU) | sets |
  |---|---|---|
  | 12t bevel 6589 + 6589 | 17 and 17 (offset 2) | 155 pairs |
  | 12t double bevel 32270 + 32270 | 20 and 20 (offset 5) | 28 |
  | 12t double bevel + 20t double bevel | 30 and 20 | 2 |
  | 12t bevel 6589 + 20t bevel 32198 | 27 and 20 | 47 |
  | crown 3650 + 8t, 16t, 24t | spur at 30; crown at 12, 22, 32 (offset 2) | 9, 6, 5 |

- **Worms.**
  - 4716 drives a 24 from 40 LDU in 51 of the 53 pairs near one, and an 8
    from 20 in all 37. Its pitch radius is 10 LDU, the same as an 8.
  - 27938 drives a 20 from 40, so its pitch radius is 15.
- **Turntables.** The top and base share an origin and an axis in all 71 the
  sets contain. The tops are gears:
  - 99010: 28 teeth on its origin plane (a 20 at 60, a 12 at 50, an 8 at 44.7).
  - 48168: 56 teeth, 20 LDU along its axis.
- **The differential 62821.** Its planet 6589 stands 17 LDU along its local y,
  and its side gears 17 along z. That is the 6589 + 6589 rule again (43, 42
  and 41 times). Its 28t ring drives a 20t double bevel standing 40 LDU off its
  axis (r 35 + 5).
- **Racks.**
  - The pitch line is not where a single number puts it. Rack 3743 sits 4 LDU
    from its origin for an 8 (36 pairs) but 6 for a 16 (6 pairs).
  - 87761 and 64781 are at 5 LDU for a 12; 32185 is at 0 for an 8.
  
  Racks need a measured offset per part, and the 3743 disagreement needs a look
  at the mesh before it is trusted.

**Gaps, and how to fill each:**

1. **A gear table as data. Done (P1a).** `assets/ldraw/gears.json`, checked as
   above. Its spur gears' outside diameters are 2.5·(N+2) LDU: 24t 64.78
   against 65, 8t 24.86 against 25, 40t 104.7 against 105, 12t 35.39, 20t
   55.2. The 16t is 43.28 against 45; its teeth are short. The 8 with a
   clutch is excused: its hub is wider than its teeth.
2. **Missing or wrong connectors. Done (P1a), in `connectivity.py`.** A
   sub-build of the 179 parts it changes, with 200 unchanged parts as
   controls, merges with `tools/merge_subbuild.py`; a full rebuild gives the
   same. Until a checkout's catalogue has it, the probe's first check fails
   and says so.
   - The 24 tooth gear 3648a/3648b/24505 had no `axle_hole` at its centre: its
     subpart `s/3648s02` draws an eighth of the hole, eight times mirrored,
     from rectangles. `connectivity.py` now names the holes a file draws
     without a primitive (`_UNDRAWN`), and the eight merge into one.
   - 3709b reads its three holes as `pin_hole`s now, and so do its siblings
     3738 and 32001, the Technic plates 2 x 8 and 2 x 6 with holes; 6542a, the
     16 with clutch, has its centre `pin_hole`, and the old differentials
     (6573, its casing 4141, and 73071) a `pin_hole` in each hub. All seven
     draw their holes as plain cylinders. A rule for every such bore would not do: 4,970 parts
     have a whole bore of that size with no hole on it, most of them
     minifigure hands, hair and slopes' undersides. So they are named
     (`_PLAIN_HOLES`). The 1 x N Technic plates (2719, 4262, 4263, 4442) are
     drawn another way and are left.
   - 32062's notch no longer reads as an `axle_hole`, nor do 153 more: an
     axle-hole edge piece (axlehol2, axlehol3 and their kind) lying on the
     part's own axle is that axle meeting its stop, its stud or its notch.
     Axles with a stop (15462, 24316, 32209 ...), axle pins, towballs, CV
     joints, shock absorbers and pneumatic cylinders all had one.
   - Still open: 32187, the driving ring extension, has no hole at its centre
     either.
3. **Right-angle offsets, measured (P1a)** from the sets the same way:
   - 4143, the 14t bevel: 96 pairs stand 17 and 17 from the crossing, so its
     face offset is -0.5 (17 = 17.5 - 0.5).
   - 32498, the 36t double bevel: 20 and 50 with a 12t double bevel, face 5.
   - 87407, the 20t bevel with a peg hole: 20 and 27 with a 6589, face 5.
   - 18938, the 60t turntable: its teeth are on its origin plane, measured
     against a 36 at 120, a 20 at 100 and a 12 at 89.4.
   - 48168, the 56t turntable: 20 LDU along its axis, which is +20 in the
     app's axes (the probe had -20, and no case met it).
   - 24121, the quarter ring: its teeth are inside, 140 to the circle, centred
     on its origin; 48 pairs in the sets stand a 12t double bevel 160.1 from
     the centre (175 - 15).
   - 62821's 28t bevel ring is 25 along its axis from its origin, toward its
     teeth: it meets a 20t double bevel whose axis passes through the casing's
     middle (33 pairs at 0 and 40).
   - Still unmeasured: 46372's right angle, 69761, 69762, 78442 (a quarter
     ring of 60, taken to be inside like 24121) and 6573's planets.
4. **Racks.** One offset per part (above).
5. **Which way a worm's thread runs.** The probe assumes right-handed. The
   ratio does not depend on it, but the direction does. Read it from the
   helix in the LDraw mesh, then test the simplest assembly by hand.
6. **Masses.** `Stability.grams` estimates mass from volume. StableLego
   weighed parts: 1×1 brick 0.43 g, 2×4 brick 2.16 g, 1×8 3.03 g. Calibrate
   against those.

## 3. Architecture

```
parts + transforms ──► Mechanism.build()                 (pure, like Flex)
                         bodies     union-find over rigid joins
                         joints     revolute / prismatic, one per pair of bodies
                         couplings  gear mesh, worm, rack, chain, screw
                         loops      joints that close a cycle
                     ──► solve(drivers)  ──► rates, free joints, locked meshes
                     ──► pose(t)         ──► every part's transform
                                           │
               ┌───────────────────────────┼──────────────────────────┐
               ▼                           ▼                          ▼
     Simulate mode (UI)           StudioRender.animate        check_design / MCP
     driver, play, scrub,         + AnimatedWebP + MP4        ratios, locked, free,
     record                       (as Pose does today)        balance numbers
```

**P1, kinematics (the PoC's core).**

- **Joints.** One unknown per joint in a tree grown out from the ground: a
  turn relative to the body it hangs from.
- **Couplings.**
  - Each gear mesh is one linear equation: the two pitch circles' surfaces move
    together where they touch. This one form covers spur, crown, bevel and
    internal meshes.
  - **The ratio is the teeth's; the spacing only says whether they mesh.** The
    2 LDU lattice cannot stand every pair at its pitch: a worm on the 28
    tooth turntable is 46 LDU off its axis for 45, a 16 and a 20 on a stud's
    diagonal 44.72 for 45. Read where one gear's pitch circle reaches, as P1a
    first did, the other's lever took up the difference, and the worm turned
    the turntable once in 28.8. Now the teeth meet where the line between the
    centres is split as the radii are (a worm's advance scaled the same), so
    each lever is its radius times one factor and the ratio is exactly the
    tooth counts' however far within `MESH_SLACK` they stand. In an
    epicyclic train the point is shared by both sides, so a carrier's own
    turn still cancels as it should.
  - **A mesh further off than real sets stand theirs is said to be.** Past
    `SPACING_SLACK` (0.3 LDU: 750 of 855 pairs in the sets are within 0.1)
    Simulate and `simulate_mechanism` say "Off their spacing … 46 LDU apart
    for 45, 1 LDU loose", and `check_design`'s mesh line carries the same
    words. It still meshes and still turns at its teeth's ratio; a real one
    that far out runs loose or binds.
  - A worm's equation adds the thread's advance (lead / 2π per radian).
  - A rack's is the same with its prismatic joint.
  - A chain's is the same as a mesh with the direction kept.
- **Loops.** A joint that closes a loop adds five equations: the two bodies
  may turn only about its line.
- **Drivers.** Each driver sets its joint's rate to 1. Gaussian elimination
  then gives one of three answers:
  - every rate;
  - joints left free;
  - a contradiction. The train is **locked**, and the solver names each mesh
    whose removal frees it.
- **Free joints follow what carries them.** A round-holed gear with nothing to
  drive it, or sails threaded on an axle, turns with its carrier, as friction
  would have it.
- **Why it stays linear.** As long as every axis stays fixed relative to the
  body that carries it, the angles are exactly the rates times the driver's
  angle. That covers gear trains, epicyclic trains (orreries, differentials)
  and turntables.

**P2, linkages.** Cranks, connecting rods, 4-bar linkages, pistons, cardan
joints and steering all have axes that move. The equations become nonlinear in
the angles. Solve them per frame by Newton–Raphson on the loop-closure
residuals, Coros-style, starting from the last frame. Report:

- jams (the residual won't go to zero);
- toggle points (the Jacobian loses rank);
- free motion (the null space).

Use numerical rank, not Grübler. Linear actuators and pneumatic cylinders are
prismatic joints. A linear actuator is a screw coupling with its lead. A
pneumatic cylinder is driven by its own input until P3.

**P3, dynamics.** Two routes:

1. **Inverse dynamics on the P1/P2 motion (cheap; useful first).** The motion
   is known, so recursive Newton–Euler
   ([Modern Robotics §8.3](https://hades.mech.northwestern.edu/images/2/25/MR-v2.pdf))
   gives every joint's force and torque at every frame: gravity, inertia and
   centripetal loads. That is enough for strength, for tipping while moving,
   and for motor torque budgets. This is S2 below.
2. **Forward dynamics (gravity moves things, motors stall, parts collide).**
   Either:
   - Jolt bodies with hinge motors, plus `GearConstraint` and
     `RackAndPinionConstraint` bound through a GDExtension, with the world
     scaled; or
   - our own sequential-impulse or XPBD solver
     ([Müller et al. 2020](https://diglib.eg.org/handle/10.1111/cgf14105))
     over the same bodies and couplings.
   
   Jolt is the less work. Our own solver is the only way to get determinism on
   every platform the app runs on.

**Recording.** `PoseAnimation` is driven by time and `StudioRender.animate`
by a pose for each frame, and the probe already uses `animate` with the
mechanism's poses. A recording is the driver's angle against time (constant
speed, or eased in the same monotone cubic as Pose's keys). It is written as
frames, an animated WebP and an MP4 through `RenderOutput`, as Pose's "Render
animation" does now.

**UI: a Simulate mode.** It sits beside Pose and animate. The person:

1. clicks a driver (an axle, a crank, a motor part);
2. sees every turning body tinted by its speed, and the ratio of each named
   body (an arm, a wheel);
3. plays or scrubs;
4. records.

A locked train highlights the meshes that fight. A free body shows as free.

**AI: an MCP tool, `simulate_mechanism`.** It is a thin wrapper over the same
`Mechanism` code. It takes a driver and how far to turn it. It returns compact
results:

```json
{"bodies": [{"name": "Mars arm", "turns_per_driver_turn": -0.714286, "period_driver_turns": 1.4}],
 "locked": [], "free": ["sail plates (follow the axle)"],
 "balance": {"worst_tipping_margin_studs": -18.2, "at_driver_deg": 270,
             "edge": "front", "counterweight_g_at_4_studs_inside": 41}}
```

It records on request, as a job (below). That is what lets the designer build a mechanism and
then prove it turns, the same loop it already uses for `check_design`.

## 4. Balance and strength

**Phase S1 at rest is built** (2026-10-13): `src/assembly/balance.gd`, over
the Pose panel's animation or every joint swept through its reach
(`Poser.sweep`), in Tools, Check stability and in check_design's result. The
gear-driven sweep is P1b's: Simulate mechanism hands the frames of a whole
cycle to `Balance.measure` as poses (section 8). What follows is the research
it was built from.

**What the app checked before it** (`src/assembly/stability.gd`):

- every stud joint's load against **80 g per stud**;
- whether the load's centre of mass falls past the joint's footprint
  ("levered");
- a slenderness limit.

Its comment calls ~1 N per stud "the LEGO Group's own figure". That number is
not published: the LEGO Group's own book says "the ideal strength's value must remain
secret" (Konstanski, *The Secret Life of LEGO® Bricks*, p. 22,
[via Brick Architect](https://brickarchitect.com/cite/S4)). The check is also
taken at rest only.

**Measured and published numbers to use:**

| quantity | value | source |
|---|---|---|
| Stud friction capacity | **0.98 N per contact point**. A stud has 3 contact points under a 2×N part and 4 under a 1×N part, so about 3–4 N per stud to pull off. The method is not described; the code's `"T": 100` is grams-force. | [StableLego paper](https://arxiv.org/html/2402.10711v2), [config](https://github.com/intelligent-control-lab/StableLego/blob/main/config.json) |
| Stud pull-off, simulated | 53.1 N for a 2×4 on a 2×4 (6.6 N per stud). FEM, not a bench test. Stud shear yield ~311 N, so shear never governs. | [Faria 2018, Porto MSc](https://repositorio-aberto.up.pt/bitstream/10216/116072/2/291826.pdf) |
| Moment a stud joint holds | Not measured anywhere found. Rigid-plastic bound: M = Σ F·dᵢ about the compressed edge. A 2×2 joint at 1 N per stud holds about 3.2 N·cm. | derived from StableLego's force model |
| Friction pin 2780 | No torque published. Arm-hanging test: 4.5 vs 3 bricks before slipping (old vs new pin), lever unreported. Placeholder 0.5–1 N·cm, to measure. | [Rambling Brick](https://ramblingbrick.com/2021/01/27/what-if-they-introduced-a-new-technic-pin-and-nobody-noticed/) |
| Axle in torsion | twists from 30 N·cm, permanent at 50, breaks at 70 | [Brick Experiment Channel](https://brickexperimentchannel.wordpress.com/2023/11/15/characteristics-of-lego-parts/) |
| Gear teeth | 8t fails at 40–60 N·cm, 40t at ~200 N·cm. 24t clutch gear slips at 3.9–4.7 N·cm (stamped 2.5–5). | same; [TechnicBricks](http://www.technicbricks.com/2008/02/tbs-technugets-01-inside-technic-clutch.html) |
| ABS | E 2.1–2.8 GPa, yield 35–50 MPa, 1.03–1.06 g/cm³ | [Faria 2018](https://repositorio-aberto.up.pt/bitstream/10216/116072/2/291826.pdf) |
| Motors at 9 V (no-load rpm, stall N·cm) | PF M 405/11, PF L 390/18, PF XL 220/40, Control+ L 315/26, EV3 L 175/43, SPIKE M 228/13.5, SPIKE L 213/33.5. Philo calls stall values "VERY imprecise". Run at most half stall continuously; peak power is at half stall and half speed. | [Philo](https://web.archive.org/web/2024/https://www.philohome.com/motors/motorcomp.htm), [SPIKE sheet](https://assets.education.lego.com/v3/assets/blt293eea581807678a/bltb9abb42596a7f1b3/5f8801b5f4c5ce0e93db1587/le_spike-prime_tech-fact-sheet_45602_1hy19.pdf) |

The current 80 g allowable is defensible as a working load, about a quarter of
StableLego's ultimate. It should carry a margin, not a verdict, and cite the
source.

**Static tipping (S1).**

- **The support polygon.** It is the convex hull of where the model touches the
  floor or its plate. The model stands if its centre of mass projects inside
  it. The **tipping margin** is the distance from that projection to the
  nearest edge. [Support polygon](https://en.wikipedia.org/wiki/Support_polygon)
- **Prefer the force-angle measure**
  ([Papadopoulos & Rey 1996](https://dspace.lib.ntua.gr/xmlui/handle/123456789/13824?show=full)).
  It is the same edges, weighted by the centre of mass's height, so a tall
  model on a narrow base reads as nearer tipping.
- **A mechanism changes its centre of mass as it moves.** S1 evaluates the
  margin at every frame of the P1 cycle and reports the worst, with its
  angle. That is the owner's orrery: Neptune's arm, 18 studs past the base
  edge at one angle, is the worst frame, and the scrubber goes straight to it.
- **The fix, as a number.** Total mass m whose centre is a distance d past
  the edge needs a counter-moment m·d. A counterweight w placed a distance L
  inside the edge must satisfy w·L ≥ m·d.

  For example, in round numbers that are not the owner's: an arm and planet of
  30 g with their centre 18 studs (144 mm) out, and a base whose own mass sits
  6 studs inside, needs 30·144/48 = 90 g more at that point. Or the base must be
  that much heavier, or that much wider.

**Joint strength (S1).**

- **Stud joints.** Every stud joint in the model (Stability already finds them)
  gets the moment and pull it carries from everything beyond it, at every
  frame. That is compared with M = Σ F·dᵢ for its studs, at 1 N per stud for
  the allowable and 3 N for the ultimate.
- **Pin and axle joints.** Pins carry moments by bearing, which is not the
  weak point. What fails in practice is a friction pin slipping under an arm's
  weight, so those are compared with the pin's friction torque once it is
  measured.
- **The drivetrain.** Gears and axles are checked only once there is a motor
  (S2).

**Dynamic loads (S2, inverse dynamics on the P1/P2 motion).**

- **The loads.** Centripetal force is m·ω²·r
  ([HyperPhysics](http://hyperphysics.phy-astr.gsu.edu/hbase/cf.html)), and
  the torque to accelerate is I·α. Newton–Euler adds them along the chain.
- **Dynamic tipping uses the zero-moment point** instead of the centre of mass
  ([Vukobratović & Borovac 2004](https://en.wikipedia.org/wiki/Zero_moment_point)).
- **For an orrery they are small.** A 20 g planet 150 mm out at half a turn a
  second feels 0.03 N, against 0.196 N of weight. Gravity governs, and the
  "Clockwork Solar System" builders saw the same: the outer arms sagged
  ([Eurobricks](https://www.eurobricks.com/forum/forums/topic/187509-clockwork-solar-system)).
- **Where dynamics matters:** fast swinging arms, flywheels, and motors near
  stall. S2 also budgets motor torque against the stall table: every motor
  under half stall at every frame.

**Showing it.**

- **To the person:**
  - A heat map: each joint's part tinted by load over capacity, green through
    red, at the frame being shown.
  - A tipping margin readout ("2.1 studs to the front edge; worst 18 studs
    past it at 270°"), with the support polygon drawn on the floor and the
    centre of mass dropped onto it as a marker.
  - A sweep strip under the scrubber, marking the frames where something is
    over.
- **To the AI designer:** numbers in `check_design`'s result and in
  `simulate_mechanism`'s:
  - the worst margin in studs, at which driver angle, and over which edge;
  - the counterweight needed at a named distance;
  - the three most loaded joints, with part ids, load and capacity.
  
  Then it can add counterweight or bracing and run the check again. The
  guidance a session must act on goes in the result itself ("add ≥ 90 g within
  4 studs of the back edge, or widen the base 6 studs"), not in the
  instructions head.

## 5. Phases

The **orrery is the acceptance demo**. It needs P1a, P1b and P1c, then S1
across its cycle. Nothing on its path waits for linkages or dynamics.

| phase | what ships | how it is proven | estimate |
|---|---|---|---|
| **P1a Gear trains** | **Shipped:** `src/assembly/mechanism.gd` lifted from the probe, with sparse elimination. The gear table as data (`assets/ldraw/gears.json`) with its pipeline check (`tools/gears.py`, `tests/test_gears.py`). Connector fixes in `connectivity.py` (3648a/b/24505, 3709b with 3738 and 32001, 6542a, the old differentials 6573/4141/73071, 32062 with 153 more), committed on their own first (293bea2) so a session can seat gears on axles. Ring gears (inner mesh: centres r_ring − r apart, same sense, within a quarter's arc; a ring on rollers turns about its own centre), chains on `Flex.SPROCKETS` (same sense, the links' ratio), clutch gears and driving rings, the differential (two freedoms: two drivers, or one and a held output). Locked, free and floating reports; drivers absolute. **Left:** racks (no prismatic joint yet, and the pitch lines in section 2 are unchecked); 42179's year train (not in the OMR); 6573's and 65414c01's planets (the shortcut is one part, so nothing in it can turn); 32187's centre hole; worm handedness; posing a chain's links along their loop. | The probe's cases plus: 42055 (140 gears) and 42082 (135), the OMR's sets with the most gears, read with every gear on what it turns on or a reason the file gives (`src/dev/mechanism_sets.gd`); a differential's Willis relation to 1e-6 under five pairs of drivers. Every check fails on a solver broken on purpose (section 7). | 4–5 agent days |
| **P1b Simulate mode** | **Shipped (section 8):** Tools, Simulate mechanism (`src/ui/simulate_panel.gd` over `src/assembly/simulation.gd`): pick a driver (the one a sub-assembly named Crank marks, or a click), play, pause, scrub, speed, record to WebP and MP4; bodies tinted by speed; locked meshes red and named; free and floating parts named; the model never moved (`BrickWorld.set_drawn`); the balance over the whole cycle. `simulate_mechanism` over MCP with its compact result and a picture, and `tools/mcp_tools.json` regenerated. | `src/dev/simulate_probe.gd`, windowed, clicking the driver, playing, scrubbing and recording, every frame read back off the renderer, failing on a solver broken on purpose. `tools/mcp_check.py` driving it the way a Claude session does. | 3–4 days |
| **P1c The orrery** | **Shipped (section 9):** the ratio search (`src/assembly/gear_ratios.gd`, `search_gear_ratio`), the quarter ring's cover opened inside (`MOSTLY_AIR`), gears read round by the checker, and the eight-planet orrery built by a Claude session over MCP (`models/orrery.ldr`). Periods read out as planet years ("Mars: 1.96 Earth years; NASA 1.8808, +4.2%"): **shipped with P1b**, in the panel and in simulate_mechanism, against NASA's sidereal periods or `targets=`. Turntables (56, 60) and the 140 tooth ring. A ratio search for the designer: the gear trains on the stud grid within n stages that come nearest a target. Every LEGO tooth count factors into primes ≤ 7 (bar the 22), so 365.25 = 3·487/4 can only be approximated; Brocot's method finds the nearest ([AMS](https://www.ams.org/featurecolumn/archive/stern-brocot.html)). | **Acceptance:** an orrery of at least the eight planets, built in the app by the owner or by Claude over MCP. Every arm's period within the error its gear train claims, checked frame by frame off the renderer as the probe does. Recorded to MP4 and WebP. | 2–3 days, plus the build |
| **S1 Balance at rest and across the cycle** | The support polygon, centre of mass and force-angle tipping margin at every frame. Stud joint moments against the cited capacities. Counterweight advice. The heat map and margin readout. Numbers in `check_design` and `simulate_mechanism`. `Stability` rewritten on margins with sources. | Arrangements with known answers (a T on one stud, a cantilever of n plates). The owner's orrery reproduces "18 studs past the edge" at its worst angle, and a counterweight added by the advice brings it inside. | 3–4 days |
| **P2 Linkages and closed loops** | Newton–Raphson on loop closure. Cranks, connecting rods, 4-bars, pistons, cardan joints, steering. Linear actuators as screws. Pneumatic cylinders as driven prismatics. Jam, toggle and free-motion reports. | A 4-bar's coupler curve against the closed form. A crank-slider's stroke. 42xxx steering racks from the OMR. | 1.5–2 weeks |
| **S2 Dynamic loads** | Inverse dynamics over the P1/P2 motion: joint forces and torques, the zero-moment point, a motor torque budget against Philo's table. | A swinging arm against m·ω²·r and I·α by hand. A motor geared to stall reported as stalling. | 1 week |
| **P3 Forward dynamics** | **Begun (§14):** a free joint swings, a chain of them together, with Coulomb friction, stopped by the room test; a model that tips falls in time about its edge. **Left:** gravity moves everything else, friction measured, motor torque curves, collisions between moving parts. Jolt with the gear constraints bound through a GDExtension and the world scaled, or our own solver. | Pendulum periods. A gear train coasting down. Determinism per platform where it is promised. | 3–6 weeks; the riskiest |

## What "accurate" can honestly mean

- **Kinematics (P1, P2) can be exact.** Gear teeth don't slip. A simulated
  orrery's period error is exactly its ratio's error against NASA's period,
  and the tool can say so to six figures. Real ones show that is the whole
  story:
  - 42179 is 364.5 Earth turns per year, 0.2% off ([BrickNerd](https://bricknerd.com/home/falling-down-the-gravity-well-orbits-of-the-lego-orrery-6-24-24));
  - JK Brickworks' is 375 days, +2.7% ([JK Brickworks](http://jkbrickworks.com/earth-moon-and-sun-orrery/));
  - Clockwork Solar System is under 0.15% for every planet with 153 gears.
  
  Two things are out of reach:
  - **Phase.** Backlash leaves a few degrees; the LEGO Group's own spec for the SPIKE motor is
    ±3° including gearbox slack. It does not accumulate unless something slips.
  - **Scale.** Distances and sizes are not to scale.
  
  42179's 364.5 against 365.5 argument is about which frame a carrier's turns
  are counted in ([Eurobricks](https://www.eurobricks.com/forum/forums/topic/196903-42179-planet-earth-and-moon-in-orbit/page/4/)).
  The simulator has to say plainly which frame each period is in.
- **Statics (S1) is honest to about a factor of two to four.** Per-stud
  clutch is unpublished, and the best numbers range from 0.78 N (ours) to
  3–4 N (StableLego's ultimate per stud). So the check shows margins, names its
  numbers and says when a margin is within that band. Friction pins are
  unmeasured. A small bench rig (a known arm, a known mass, a protractor) would
  pin them down, and is worth more than any model.
- **Dynamics (S2, P3) is as good as what it is made of.**
  - Friction and damping in the joints of LEGO® parts are unmeasured.
  - Jolt is tuned for metres, and is deterministic only per binary.
  
  "This arm will swing past the edge if driven at full speed" is a fair claim.
  Since G5 (§14), so is "it falls in a fifth of a second" and "it swings
  with a period of 0.38 s", to a few per cent: they come from the masses and
  the moments of inertia, and the probe holds them to the hand formulas. "It
  swings 15 times before it hangs still" is not: that comes from a pin's
  friction, which nobody has measured, and is good to a factor of 1.5 either
  way.

## 6. Risks

- **Rigid groups the connectors don't see.**
  - A frame held by friction alone.
  - A part placed off its connectors in a file.
  - The gaps in §2.
  
  Each gives a floating body or a free joint. The probe reports both, and on
  8020 it found none once the frame's pins and studs were read. On large sets
  (122 gears) this is untested.
- **Tolerance.** A real set's gear 0.3 LDU off pitch on a diagonal must mesh
  (MESH_SLACK is 1 LDU). Two gears 1.2 LDU off must not, and the data says
  those are neighbours. Files built by hand in other tools will be worse.
  Report near misses rather than silently meshing them.
- **Redundancy.** Real models are over-constrained everywhere: an axle through
  three holes, a beam on four pins. The probe collapses those first and
  checks the rank of the rest, as Coros and Onshape do. P2's nonlinear loops
  need the same care, or every Technic chassis will read as jammed (LeoMCAD's
  complaint about Inventor).
- **Free means follows.** Friction, not a rule of the parts, decides what a
  free joint does. Sails on round holes turn with their axle, and an idle gear
  on a round hole stands still. The probe's rule (a free joint keeps its
  relative angle) gets both right. A clutch gear that should slip will need its
  slip torque, which is S2.
- **Single precision.** Transforms are 32-bit floats, so ratios read back to
  1e-6, not 1e-9. That is fine for pictures, but use the rates, not
  re-measured transforms, for period readouts.
- **The web build.** Phase 1 is a few hundred equations solved once per
  driver, so it is cheap anywhere. P3 with Jolt on the single-threaded web
  build is the performance risk.

## 7. The proof

The proof of concept became `src/assembly/mechanism.gd` in P1a, and
`src/dev/mechanism_probe.gd` runs every case through it. Real sets are
`src/dev/mechanism_sets.gd`. Run them with:

```sh
godot --headless --path . --script src/dev/mechanism_probe.gd
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/mechanism_probe.gd
godot --headless --path . --script src/dev/mechanism_sets.gd
```

Run 2026-10-13, headless (the windowed run adds the drawn frames, below). The
ratios in brackets are what the solver gave:

```
the gear table and the parts it names
ok    the table reads, 56 gears
ok    every gear with a hole has it on its axis in the catalogue's connectors (all do)
a real set: 8020's windmill (OMR)
ok    the crown's axle turns 24/8 = 3 times the crank's, the other way (-3.000000)
ok    the sails' axle turns 3 x 3 = 9 times the crank's (9.000000)
ok    the sail plates go round with their axle (free on it, followed)
ok    nothing with a gear in it floats (0)
the same two axles, also joined 16 to 16
ok    ...naming both meshes as the ones that fight (["parallel 8-24", "parallel 16-16"])
a worm driving a 24
ok    the 24 turns once for 24 turns of the worm (1/24.0000)
a two-planet orrery: Earth on the central axle, Mars on a turntable, one crank
ok    a Mars year is 1.9600 Earth years here, against 1.8808: +4.2%
a 12 carried round inside four quarter rings of 35 (140 in all)
ok    on its arm the 12 turns 140/12 = 11.6667 times the arm, the other way (-11.666667)
ok    the central axle, which nothing turns, stays still under its arm (0.000000)
ok    one quarter on the far side: no mesh (none), and the 12 is left free
ok    a quarter held by nothing turns on its rim about its centre, 12/140 = 0.085714 of the 12 and the same way (0.085714)
a chain from a 24 to an 8
ok    the 8 turns 12/4 = 3 times the 24, the same way (3.000000)
a gearbox: a driving ring between a 24 and a 16 with clutches
ok    in the middle the ring drives neither gear, and the output is free
ok    pushed into the 16, the output turns 16/16 = 1 the other way (-1.000000)
ok    pushed into the 24, the output turns 24/8 = 3 the other way (-3.000000)
a differential (62821), its two freedoms and Willis's relation
ok    one driver leaves one freedom, the sides and the planet undecided
ok    the pinion turns the casing 20/28 of a turn (-0.714286)
ok    two drivers decide it, and the sides sum to twice the casing every time, to 0.00000017881393
        (0.000 + -1.429 = 2 x -0.714; 1.000 + 1.000 = 2 x 1.000; 1.000 + -1.000 = 2 x 0.000;
         0.300 + 2.000 = 2 x 1.150; -1.929 + 0.500 = 2 x -0.714)
exact ratios where the 2 LDU lattice stands gears off their pitch
ok    the turntable's base, resting on the plate's studs, is held with it (3033, 99009, 32523 x2)
ok    a worm 46 LDU off a 28 tooth turntable turns it once in 28 turns, exactly (1/27.999999)
ok    ...and says it stands off its spacing (46 LDU apart for 45, 1 LDU loose)
ok    ...in what Simulate and simulate_mechanism say: Off their spacing (they mesh, and turn at
      their teeth's ratio, but real ones that far out run loose or bind): #7 4716 with #3 99010,
      46 LDU apart for 45, 1 LDU loose.
ok    8 to 40 three studs apart: -0.200000, -0.2
ok    12 to 36 three studs apart: -0.333333, -0.3333
ok    a 20 to a 16 idler to a 20 on two stud diagonals: the idler -1.250000 (-20/16), the output
      1.000000, as the input
ok    ...and a stud's diagonal, 0.28 LDU short, is not said to be off its spacing
mechanism: gear trains read off the parts, every ratio its tooth counts', a locked train named, a ring, a chain, a gearbox and a differential turned
```

That is 51 checks, abridged here; the windowed run adds the drawn frames, and the sets 3.
The exact-ratio cases were run (2026-10-13) against a copy of the code with
the mesh point put back at one gear's pitch circle and parts standing on
studs not joined, as P1a had it. Four fail: the turntable's base
floats, so its top floats with it and the worm turns nothing ("1/inf"), and the
readout names the top floating; and the idler train's output turns 1.025559 for
1, the idler -1.267661. The 8 to a 40 and the 12 to a 36 stand at their pitch
and pass on both, as they should. (Held by its name instead, the old code read
the worm at 46 LDU as 1/28.8: `axle_probe`'s tolerance of 0.03 was there for it.)
Willis holds to 2e-7, not to 1e-12: the
parts stand where 32-bit transforms put them, so a lever of 17 LDU is
17.000001. Periods for P1c should come from the rates, which are exact to
the tooth, not from re-measured transforms.

Windowed, every frame of the windmill and the orrery is read back off the
renderer's copy: the sails step 9.0000 times the crank to 0.0000°, Earth's arm
1.4000 times, Mars's 0.7143 times. The pictures are in `shots/mechanism/` (16
windmill frames and 24 orrery frames, each as PNGs and a WebP).

**Real sets.** 42055 and 42082, the OMR's two sets with the most gears, read in
two seconds each:

```
42055-1.mpd
  3928 parts, 783 bodies (the ground 807 parts), 377 joints in the tree, 124 closing loops, 405 floating (3 with a gear); 140 gears, 70 couplings
ok      apart: 302 parts with 3 gears touch no connector of the rest; read on their own [...] 0 gears floating
ok    42055-1.mpd: of 3 floating, 0 near misses the file draws and 3 apart, none unexplained (0)
42082-1.mpd
  5025 parts, 1716 bodies (the ground 950 parts), 581 joints in the tree, 190 closing loops, 1134 floating (2 with a gear); 135 gears, 67 couplings
  near miss: 24505 stands 2.0 LDU off the axle it is on, 15462, in the file
  near miss: 24505 stands 2.0 LDU off the axle it is on, 59426, in the file
ok    42082-1.mpd: of 2 floating, 2 near misses the file draws and 0 apart, none unexplained (0)
mechanism sets: 2 read, every gear on what it turns on or said why not
```

What floats, and why:

- **42055's mine truck.** The file's main model places two: the truck and the
  excavator. The truck touches nothing of the excavator, so its three gears
  float against the excavator's ground. Read on its own, its chassis is its
  ground and nothing in it floats.
- **42055's bucket wheel** floated until the "rim" joint. Its eight quarter
  rings ride on rollers round their rim and turn on no axle, so no connector
  says what they turn about. A ring meshing a gear on something that turns now
  turns about its own centre on what carries that gear.
- **42082's two 24s** stand 2 LDU off their axles in the file (z -78 for -80;
  y -2 for 0). The reading allows 1.5 and reports these rather than mending
  them.

Many other bodies float (405 and 1134): panels held by pins in holes the
connectors don't record, flexible hoses, tyres on rims (a shaft in a bore, which
`Joints.rounds` reads for the checker and the mechanism does not need), and
42082's two unofficial flexible sections that the catalogue does not have. None
has a gear in it. The drivetrains do not yet read whole: from twelve inputs
each, at most 10 joints of 42055's 377 turn and 15 of 42082's 581. Why is
P1b's to find, with the sets' drivetrains drawn turning.

**Every check fails on a solver broken on purpose.** Each mutation below was
made to `mechanism.gd` (or the table) alone, the probe and the sets run, and
the file put back. Each check failed under at least one:

| broken | checks it failed |
|---|---|
| the two sides of a mesh pull the same way | every ratio's sense, Willis, the held side |
| one side's lever counted twice | every ratio, the Mars year, Willis |
| a contradiction never seen | the locked train, its culprits |
| the culprits not named | the culprits |
| no parallel meshes / no bevel pairs at right angles / no worm | each mesh count, and what turns through them |
| a worm's lead doubled | 1/24 |
| a ring's inside taken for an outside; a quarter's arc ignored; no rim joint | the ring's mesh, 140/12 and 128/12; the far quarter; the rim |
| a chain against its sense; no link on a sprocket | 3:1 the same way; the chain found |
| a driving ring in every clutch it touches; not keyed to its joiner | neutral; each gear pushed into |
| no stub for the planet | the stub, the one freedom, the held side |
| studs hold nothing; axles not keyed; two pins hold nothing; the held parts not held | the frame, nothing floating, the sets; Earth rides its arm; the base stays |
| a free rate turns at 1, not 0 | the sails follow their axle |
| a pose turned a tenth too far / at every joint's driver's angle / not at all | nothing moved at 0; every frame's step; the pictures change |
| the largest pivot, not the one furthest from the ground | the central axle stays still |
| drivers relative to their carrier | 128/12 |
| the table missing; no hole on any axis; a gear the catalogue lacks; a part dropped | the table reads; the holes; the catalogue; 57 parts |

The one check no solver can break is "every frame drawn": it is the
renderer's.

**What it found:**

- The connector data is enough for bodies and joints once the parts' own
  misreads are fixed (section 2's gaps, in `connectivity.py`). A gear table is
  the one thing that has to be added.
- A part can be a shaft and a holder at once: 87082, the long pin with a hole
  across its middle, and the axle connectors with an axle of their own. Read as
  holders only, their pins went into nothing, and 89 more of 42055's parts
  hung loose from its frame.
- Two rules made the windmill's frame one body: studs in sockets, and two
  revolutes between the same two bodies on different lines. Without them, 8
  floating pins and 6 pieces of frame hung off the axles.
- The locked train needs no special case. The equations contradict, and
  dropping each mesh in turn names the ones that fight.
- A driver is how fast its body turns against the ground. As a rate relative to
  what carries it, an arm on an idle axle could stand still while the axle
  turned back under it, and the ring case read 0 for 128/12.
- Loops of fixed axes stay linear. A joint closing a loop adds five equations
  and no new kind of solver. A differential is one: its casing turns on both
  half axles.
- A worm is one more term in the same equation (the thread's lead). Its
  direction depends on a handedness not yet read from the part.

**The windmill is the windmill of LEGO® set 8020**, from the OMR
(`8020-1_Windmill.mpd`, 57 parts, as published), and the file was not touched:
the frame is 40 parts held by studs and by 8 friction pins, two pins to each
joint; three axles turn; the sails are six plates threaded on their axle by
round holes, free on it and following it; the crank is a steering arm keyed
to the first axle. **The orrery** is hand-placed: Earth's arm on the central
axle, Mars's arm pinned across a 28 tooth turntable round that axle, both from
one crank three studs away. Its Mars year is (28/20)² = 1.96 Earth years,
against NASA's 686.98 / 365.256 = 1.8808: +4.2%. A second stage, (24/16)·(20/16)
= 1.875, would be −0.3%. That is P1c's ratio search.

## 8. Simulate mode (P1b), with the period readout (P1c)

**Where it is.** Tools, Simulate mechanism…, beside Check stability. Both
read the model as built and change none of it; Pose and animate is under
Build because every pose a slider sets is a step to undo. The panel is
docked in a column of its own beside the model's, as the parts column is,
and the parts column folds while it is open (and comes back when it
closes): the view is centred on what is left (CadCamera's lens), so no
part of the train is under the panel. It first stood over the model's left
edge, where at 1600 x 900 it covered half a gear train and a click meant
for the 8's axle selected the 24. Opening Pose closes it. `src/ui/simulate_panel.gd` is the panel; `src/assembly/simulation.gd`
reads the model into a `Mechanism`, names its bodies and says what it found.

**What it does.**

- **The driver.** A sub-assembly named Crank, Motor, Handle or Driver, else
  the part selected, else the body with a gear that turns most of the train
  and leaves least undecided. The Select tool is put in hand, so a click on
  an axle or a crank drives that body instead.
- **The base.** The baseplate and what stands on its studs, plus any
  sub-assembly named Frame, Base, Stand or Chassis. A part standing on
  studs is held by them whether or not the part records a socket there
  (`Mechanism._rest_on_studs`: its underside at the studs' foot, the studs
  under it): a turntable's base resting on a plate, a frame or the
  baseplate stands still with it, where it used to float unless pinned or
  named. The name is still how a person or a session holds still a frame
  nothing the parts record holds (section 7's orrery's turntable base sits
  on a studless beam). Without a baseplate it is the largest rigid part.
- **Tinted by speed**, blue slow to orange fast on a log scale, the driver
  white; the meshes that lock a train red, free bodies amber, floating gears
  violet, each also named with its part numbers in the panel.
- **Play, pause, scrub and speed.** Play turns the driver at 0.1 to 2 turns a
  second; the slider covers the cycle, a turn of the slowest turning body;
  Worst balance goes to the frame where it comes nearest tipping.
- **The model never moves.** The turning parts are drawn where the
  simulation puts them (`BrickWorld.set_drawn`): their transforms, the
  lattice, the history and the model's revision stay as they were, so a save
  or an undo while it plays sees the model as built.
- **Periods.** Every turning body's turns per driver turn, against the base
  (the sidereal frame), the same or the other way when its line is parallel
  to the driver's. With a reference (Earth when a body is named so), each
  other's period in its turns, and for a body named after a planet against
  NASA's sidereal period: "Mars arm: 1.96 Earth years; real 1.8808, +4.2%".
  The planets and the bodies `targets=` names come first, then those a
  sub-assembly names, then the rest, each fastest first (`Simulation.listed`):
  the orrery's gear axles turn faster than its outer planets.
- **Balance over the motion.** 72 frames of the cycle go to `Balance.measure`
  through Shell's `weigh_balance` (polygon and centre of mass drawn on the
  floor), and the turning body reaching furthest past the base's edge is
  named, with the frame it does it at.
- **Record.** One turn of the reference, or of the driver, in 24, 48 or 96
  frames, through `StudioRender.animate` into `RenderOutput`, as Pose's
  Render animation keeps one: an animated WebP, and on the desktop the frames
  and, with ffmpeg, an MP4.
- **Working** is up for every slow step: reading the mechanism (on a worker
  from 600 parts), turning it, weighing it, recording.

**Over MCP, `simulate_mechanism`** (`AppTools`, `SimulatePanel.for_session`)
runs the same reading, driving and weighing and answers compactly: the
driver and why, the base, each turning part's rate or period against the
real one (or `targets=`), a locked train's meshes and the free and floating
parts by number with what to do about each, the balance at the worst frame
of the cycle with Balance's counterweight advice, and a picture of that
frame from the hero view. `record=true` renders `turns=` turns of the
reference in `frames=` frames, and is a job as `render_model`'s turntable is
(`ToolJobs.long_call`): the call answers at once with the job's number, the
frames are counted on the job (and on the Working bar the person sees), the
session polls `job` until it gives the whole answer, and `job` with
`cancel=true` (or the window's Cancel) stops the renderer. It never changes
the model, and leaves the panel as the person left it.

**The proof** is `src/dev/simulate_probe.gd`, windowed, in the real scene
with the mouse: an 8 driving a 24 (a 16 free on the 8's axle, an 8 lying
loose, then two 16s meshed as well to lock it) and section 7's orrery on two
pillars. Run 2026-10-13, abridged:

```
ok    a click on the 24 makes its axle the driver, the 8 then turning 3 the other way
ok    a click on the 8's axle makes it the driver
ok    the 24 turns a third of the 8's turn, the other way (-0.333333)
ok    the 16 on a round hole is named free, by its number
ok    the 8 lying loose is named floating, by its number
ok    in every frame played the 24 turns a third of the 8's step back (39 frames, to 0.0000°)
ok    while it played the model stood still: every part where it was built
ok    in every frame drawn the 24 turns a third of the 8's 15° step back, to 0.0000°
ok    ...naming the 16s and the 8 and 24 as the meshes that fight
ok    the crank is the driver, as its sub-assembly's name marks it
ok    Mars's year is 1.9600 Earth years against 1.8808, said with the error:
      "Mars arm: 1.96 Earth years; real 1.8808, +4.2%"
    balance: Balance over 72 frames of the cycle (1.4 turns of Crank): Stands, 0.8 studs
    inside the right edge (a 9° tilt tips it) with Crank at 329°, its worst of 73 poses.
    Furthest out: Mars arm, 3 studs past the left edge with Crank at 42°.
ok    a recording of one Earth year: in every frame drawn Earth turns 1.4 of the crank's
      step and Mars 20/28 (to 0.0000° and 0.0000°)
ok    simulate_mechanism says the driver, the periods against NASA's and the balance,
      with a picture
simulate: a driver clicked, played, scrubbed and recorded, every frame's turn the tooth
counts', a locked train named, Mars's year in Earth years against NASA's, the balance
over the cycle, and the model never moved
```

With the solver broken on purpose (the two sides of a mesh pulling the same
way) eight of those fail; put back, all pass. Over MCP `tools/mcp_check.py`
opens the same two models, as a session can, and drives `simulate_mechanism`
against a windowed app and a headless one. A 24-frame Quick recording took
79-88 s on this box under a load of 50, longer than a call should wait, so a
recording is a job; mcp_check asks for one and polls `job` to its end.

**Left for later.** Turntables of 56 and 60 are read by P1a but not yet in a
fixture here; linkages (P2: since section 27, a loop the driver closes is
turned as Grab turns it); the frames of a recording are tinted only in the
window, not in the WebP.

## 9. The ratio search and the orrery (P1c)

### The ratio search

Every LEGO® tooth count factors into primes of 7 or less (bar the 22 tooth
bevel), so most ratios a person wants can only be come near. The Stern–Brocot
tree gives the nearest fraction with a bounded denominator
([AMS](https://www.ams.org/featurecolumn/archive/stern-brocot.html)), and that
is the right tool for the question "how near could anything get": a Mars year
is 686.98 / 365.256 = 1.880813 Earth years, and its best small fractions are
15/8 (-0.31%), 32/17 (+0.08%), 47/25 (-0.04%), 79/42 (+0.007%) and 363/193.
Only the first has no prime a gear lacks. So the search does not walk the tree;
it searches the trains themselves, which are the fractions gears can make:

- **A mesh** is two spur gears of 8, 12, 16, 20, 24, 28, 36 or 40 teeth (the
  axle-holed ones in `assets/ldraw/gears.json`; a double bevel's teeth mesh a
  spur's) whose pitch circles meet at a distance the stud grid gives, to
  `Mechanism.SPACING_SLACK`: 1 stud (8+8), 2 (8+24, 12+20, 16+16), 3 (8+40,
  12+36, 20+28, 24+24), 4 (24+40, 28+36), 5 (40+40), a stud's diagonal, 44.72
  LDU for 45 (8+28, 12+24, 16+20) and three studs' diagonal, 84.85 for 85
  (28+40). One stud's diagonal, 28.28, has none.
- **A train** is a product of meshes; each reverses the turn, so an even count
  keeps the way round, and the search keeps to the count that turns the way
  asked. The halves are met in the middle: every multiset of up to half the
  meshes, listed by value, each met by the other half's nearest. Six meshes
  take a quarter of a second.
- **Between two axles** (`to=`): the output's axle stands where it is asked,
  and every axle between on a grid point of its own within `within=` studs of
  the line between them. The grid points reached in so many meshes from each
  end are met at the points both reach. That is what a gearbox needs, its
  input and its output already in holes.

`src/assembly/gear_ratios.gd` (`GearRatios`) is the search; over MCP it is the
assistant's `search_gear_ratio` (so the in-app designer has it too):
`ratio=` or `period=`, `stages=`, `to=`, `within=`, `gears=`, `first=` (the
input axle's own gear, for two trains off one shaft at one height). It answers
with the three nearest trains, each with its fraction, its error, its gears by
part and, with `to=`, where every axle stands. A Mars year: 15/8 in four
meshes (-0.31%, the nearest four can do), 2304/1225 in six (-0.0001%).

The proof is `src/dev/gear_ratio_probe.gd` (recipe in
`.claude/skills/verify/features/geometry.md`, `gear ratio search`). Every train
any of its searches answers with is laid out axle by axle in beams, each mesh
three plates above the last, and turned by `Mechanism`: the output must turn
the train's own ratio, through exactly its meshes, to 1e-5 of itself (the
32-bit transforms; a mesh read at one gear's pitch circle was 1e-2 out on a
diagonal). Laying them out found what a session would trip on too: a 40 has
four more axle holes a stud out from its middle, so an axle reaching
up into a 40 a stud from its own keys the two axles together and locks the
train. Each axle reaches its own two gears and no further.

### Why rings, not a stack of hubs

An orrery's arms all turn about one line, at different rates. Brass orreries
nest tubes; LEGO® parts have none. Every other layout was worked through:

- **Hubs stacked on a central axle, each driven from a gear on a layshaft
  outside.** An arm reaches out past its layshaft, so every layshaft that
  goes up past an arm to a hub above it sweeps through that arm once a turn.
  Driving from below and above, at most two arms clear.
- **Nested carriers** (each arm's turntable riding on the one below, its
  layshafts reacting against a fixed sun on the central axle, as
  [Rob Ayres' orrery](https://mrob.com/pub/lego/orrery.html) and the LEGO
  Ideas Clockwork Solar System do). Each stage sets the *difference* between
  neighbouring planets' rates, so its error is multiplied by up to 6.3
  (Jupiter to Mars); with a 28 tooth turntable as the only hub that carries
  an arm, the best three-mesh stages left Saturn 2.2% out and Mercury 1.6%,
  and the central axle runs through the turntables' bores.
- **A ring per planet, turned from inside.** A ring of 140 teeth (four
  24121 quarter rings) is hollow: its pinion stands inside it, and so does
  every other ring's pinion axle passing by, so nothing that turns crosses an
  arm. Each ring's train is its own, from a fixed central shaft, so each
  planet's error is only its own train's.

The pinion stands 8 studs out for a 12 (175 - 15 = 160 LDU) or 7 for a 28 (175
- 35 = 140): the only two the grid gives on an axis. Four axes, a gearbox under
the rings for the lower four and one over them for the upper four, so each
axis carries one pinion axle up from below and one down from above, which
never meet.

**The covers.** A quarter of a ring of 140 is 472 boxes exact, past the
`to_boxes` limit, and its cover was its bounding box: solid inside its teeth.
Every pinion, and every quarter beside it, overlapped it, so `check_design`
refused the ring that LEGO® set 42055 builds. `tools/ldraw/occupancy.py` now
keeps a part's own cells, however many boxes that takes up to `CARVED_LIMIT`,
when its bounding box is more than `MOSTLY_AIR` (3) times its own cells
(`tests/test_ldraw.py`, `test_a_quarter_ring_keeps_its_inside_open`). 24121
and its three printed variants and 78442 were rebuilt with `--only` and merged
with 200 controls (`tools/merge_subbuild.py`): all 200 agreed. Other parts
the rule changes come in with the next full mesh build.

### The trains

The scale: Earth's ring turns 0.57698 for each turn of the central shaft
(1.7332 turns of the shaft to an Earth year). It was chosen by scanning the
scale for the one whose worst planet comes nearest, each planet's ring
taking the nearer of a 12 at 8 studs and a 28 at 7, four meshes within a stud
of the axis: 0.18% at worst, where three turns to the year left Neptune 0.9%
out.

### The build

A Claude Code session on the subscription built it over MCP
(`--ask-claude-code`, `env -u ANTHROPIC_API_KEY`, the app in a window under
Xvfb), with `search_gear_ratio` for every train, `attachment_points` for every
hole it put an axle in, and `simulate_mechanism` to read what the parts gave.
It took two runs. The first (55 minutes) found every train and built the frame,
both gearboxes and the four lower rings, and ran into three things the check
got wrong, each fixed in the app then:

- the quarter rings' covers, solid inside (above);
- **a gear read as the square round its teeth.** A 20 is 8 boxes, a 28 and a
  36 26: past the box limit their covers are their boxes, and on a stud's
  diagonal a square's corner meets the next axle. The checker
  (`Assistant._joints_out`) and `Builder.room_for` now ask
  `Joints.past_the_teeth`: where two covers meet only outside a gear's round,
  they do not meet;
- **an 8 meshing a 28 on a stud's diagonal**, whose teeth clear the 8's axle
  by 1.4 LDU, a cell of the lattice: `Joints.meshing` forgives a gear against
  the axle its partner is keyed on (`axle_probe`'s by-hand case).

It was stopped as it began carrying a ring on spokes from a hub on the central
shaft, which would have swept them through the pinion axles inside the rings.
The second run was given its saved work and told to rest each ring on smooth
beams under its band instead (resting holds a part for the check, and adds no
joint to the mechanism, so the ring stays free to turn on its pinion), and to
search Neptune again. It rebuilt the whole of it in 87 minutes (101 replies,
44 M tokens in, 98% of them cached): 494 parts, holding together, nothing
locked, free or floating (42 of 43 joints turn, none left undecided). Each
ring is joined to nothing that turns on the central shaft: Mechanism reads
every one as a ring carried round its own centre by its pinion (a "rim"
joint), as 42055's bucket wheel is. It found
two more things: a frame named Frame holds everything in it still, so a shaft
put in it locks the train (it moved the shaft out); and the readout listed
the sixteen fastest bodies, so an orrery's gear axles hid its outer planets
behind "and 25 more" (`Simulation.listed` now says the planets first).

Read back by `mechanism_probe` (headless, off the file) and by
`simulate_mechanism` over MCP in a window (the same numbers), against NASA's
sidereal periods, Earth the reference:

| planet | its train, from the central shaft (driver > driven) | pinion > ring | turns a crank turn | period, Earth years | NASA | error |
|---|---|---|---|---|---|---|
| Mercury | 40>8, 16>20, 28>8, 24>12 | 12 > 140 | 2.4 | 0.2400 | 0.2408 | -0.35% |
| Venus | 20>16, 40>8, 12>20, 20>16 | 28 > 140 | 0.9375 | 0.6144 | 0.6152 | -0.13% |
| Earth | 16>20, 36>12, 12>20, 24>12 | 28 > 140 | 0.576 | 1 | 1 | the reference |
| Mars | 16>20, 16>20, 16>20, 24>8 | 28 > 140 | 0.3072 | 1.875 | 1.8808 | -0.31% |
| Jupiter | 28>36, 20>16, 8>40, 20>16 | 28 > 140 | 0.0486 | 11.85 | 11.86 | -0.11% |
| Saturn | 8>28, 12>36, 16>20, 36>28 | 28 > 140 | 0.0196 | 29.40 | 29.46 | -0.19% |
| Uranus | 12>20, 8>8, 8>40, 8>28 | 28 > 140 | 0.0069 | 84.00 | 84.01 | -0.01% |
| Neptune | 8>40, 20>28, 8>28, 8>8 | 12 > 140 | 0.0035 | 164.64 | 164.79 | -0.09% |

The crank turns the central shaft through a pair of 12 tooth bevels, 1:1, so a
crank turn is a shaft turn and an Earth year is 1.736 of them. Every planet is
within 0.35% of NASA's year; Mercury and Mars are the two furthest, where the
session took trains that kept their first axles clear of the central shaft's
other gears over the scale's best (0.18% at worst, section above), and Mars at
15/8 is the nearest four meshes give at all.

The balance over the whole cycle (72 frames of 285.8 crank turns, a turn of
Neptune): it stands, its centre of mass 15.4 studs inside the base's edge at
the worst pose (force angle 39°), 1,588 g. Neptune's arm reaches 18 studs past
the base's edge, the same overhang the owner's orrery has; this one's base is
heavy enough that no counterweight is needed, and simulate_mechanism says so.

The recording: two Earth years (3.47 crank turns) in 96 frames, rendered as a
job in 481 s on this box in software, a WebP (726 KB) and an MP4 (120 KB). Its
frames show every arm going round the Sun at its own pace, Mercury eight times,
the outer planets a few degrees.

Left: the rings rest on beams, which is a sliding bearing, and LEGO® parts
would want rollers there to turn freely; and the app does not yet check that
moving parts clear each other through the cycle (P2), so the layout's rule,
nothing joined to a ring inside its teeth, was the session's to keep.


## 10. Grab and move (G1)

The owner asked (2026-10-17) that a person "should be able to manipulate and
move any hinging, moving, otherwise interactive part with perfect
physics/support/structure simulation", and then that a grab take hold of
sections of the build, not one part. G1 is the first slice: the part itself,
taken in the view and moved as the real one moves.

**What moves.** `src/assembly/bodies.gd` reads the model as rigid bodies and
the joints between them, from `Joints`' rules, so the build check, Balance and
Sections read the same graph:

| between two parts | what it is |
|---|---|
| two studs or more in another part (`Joints.studs_in`) | rigid |
| one stud, when either part is a single stud across | turns on the stud: a 1x1 round plate, a minifigure's head |
| one stud into a part turned to it off the square, in a socket or hole of it | turns on the stud: it came to its angle so |
| studs into a part turned to them, in no socket or hole of it | nothing: the part leans on them (6753-1's fifth wheel) |
| one stud under a wider part square to it | rigid: clutch holds it |
| an axle in an axle hole (`Joints.through`, "grips") | rigid |
| an axle in a round hole ("turns") | turns on its line; slides as far as the axle reaches |
| a pin in a round hole | turns on its line; a pin is held by its collar and does not slide. A pin keyed to nothing is part of the first thing it is in (Mechanism's rule) |
| a clip on a bar, a hinge's pin, a turntable (`Joints.rounds`) | turns on the shared line; a clip or a minifigure's hand slides along its bar |
| a tyre on its wheel | rigid: it does not turn on the rim |
| a click hinge's fingers | turns in clicks of 22.5° |
| a ball in its socket (`Joints.balls`) | turns every way about its middle |
| glue, a magnet, one thing in pieces | rigid |
| resting on a part with the lower part's studs under its foot (`Stability.contacts`) | as studs: the lattice's cover of a hinge brick is hollow where its turntable's studs reach |
| resting on a part with no stud in it | nothing: a flap folded down lifts off |

A joint between two parts overrides every stud and cell they share: a
turntable's top and base, a hinge brick's halves, a click hinge's two parts
are held by their joint alone. A stud the lattice finds in either of two such
parts is given to the one whose face it meets (a turntable's base, not its
top), so what stands on the top turns with it and what the base stands on
stays. Two joints between the same two bodies on different lines hold them as
one, as Mechanism's two pins through two beams do. Each piece of the model
has an **anchor**, the side that stays: a part the person locked; else what
stands on the baseplate's studs, a stud in one of its sockets (a tyre resting
on the plate is not); else the heaviest body. A car's chassis stays and
its wheels turn; a crane's base stays and its boom swings. Grabbing a part
moves its body and everything beyond it, on the one joint between it and the
anchor. Grabbing the anchored half of a joint (a hinge plate's lower half)
moves the half across it. A selection moves whole bodies only, about what
joins them to the rest; a selection held on by studs is carried as before.

**How it moves** (`src/assembly/grab.gd`, `src/ui/grab_drag.gd`). With Select,
a press on such a part and a drag past 5 pixels takes hold of it. A turn
follows the angle of the pointer about the joint's line, in the plane of the
point held, so the point stays under the pointer. A drag along a slider's
line, as the eye sees it, slides instead (the first move decides). A ball
turns so the point held goes towards the pointer. Every frame asks the
lattice whether anything but what it is joined to is in the way; if so, the
angle is bisected back to the last one with room, 10 rounds, under 0.2°.
Nothing else limits it: a hinge with room to go all the way round does.

**Couplings.** A grabbed gear drives its train through `Mechanism`, the
Simulate solver: the gears it meshes turn by their teeth, with the parts
keyed to them. What hangs on a driven gear by a clip or a hinge did not yet
follow it, and a **closed loop** (a four-bar, a crank and its rod, a steering
rack on its arms) was held at both ends and moved nothing: section 11 does
both.

**Physics on release, honestly.** A joint holds by friction or it does not.
A pin's name says which: "with Friction Ridges" (2780, 43093, 6558) holds; a
pin without (3673, 3749, 4274) turns freely, as builders use them
(Eurobricks, "Technic pins: to friction or not to friction"). An axle in a
round hole and a turntable turn freely; hinges, clips, click hinges, balls
and a stud hold. Let go, a free joint swings down to where the centre of mass
of what it carries is lowest, or to what stops it: quasi-static, no swing
back (since G5 it swings, §14). Then Balance: stands, or tips and over which edge, and the most loaded
stud joint against its working load. "About", because a stud's clutch is not
published (above): honest to a factor of two.

**Ready before the press.** The bodies, the graph Balance weighs
(`Balance.prepare`) and the gear trains (`Mechanism.build`, anchors as the
ground) are read once a model revision, a quarter of a second after it last
changed, on a worker wherever there are threads (`GrabDrag._ready_ahead`), so
a press finds them read. On 7191 (1,312 parts) that takes 4 to 7 s on a loaded
box; a press on a model of 300 parts or more before it is done says so, rather
than hold the window, and one on a smaller model waits for the rest of the
reading (`GrabDrag._ready_now`) rather than read it again beside the worker.
Until 2026-10-21 a model under 300 parts was read on the main thread, and
its Main._weigh for the status bar under 600: after every move, undo and part
placed the 126-part Ducati a session designed held the window 0.4 s and then
0.2 s, 42004-1's 248 parts 1.8 s and then up to 2.2 s. On a worker the
longest frame after each is 9 to 18 ms (`ahead_probe`, headless). Each frame a moving part's box is asked of the lattice first, and its
turned cover is worked out only when something it may hit is near it; a part
whose whole sweep round the line meets nothing is never tested.

**A big section.** Past 40 moving parts a frame's room test stops after
10 ms. The section is drawn where the pointer says, the status bar says it is
"too big to test every frame: checked when you pause", and the test carries
on, a share a frame, while the pointer rests and after it is let go
(`Grab.verify_step`); what it meets is bisected back a round a frame. On
7191's 131-part wing: the grab begins in 79 to 91 ms, a drag frame's own work
is 1.9 to 2.8 ms on average and 24 to 32 ms at worst, whole frames 20 to 27 ms
on average. Let go, the wing (on a free axle) is swung down under its weight
and checked in 17 to 20 s, a frame at a time, the worst frame 160 ms: one
part's turned cover is one test, and the budget is asked between parts.

**Live structure.** The graph read ahead is weighed for each pose alone
(`Balance.weigh_pose`) every 50 ms: the support polygon and the centre of
mass on the floor, stud joints past half their working load tinted amber to
red, the model drawn leaning 4° over the edge it would tip over, and a line
in the status bar. The model, its lattice, its history and its revision are
untouched until the button comes up (`BrickWorld.set_drawn`); then the pose
is one undo step. Escape puts it back.

**Copies.** A sub-assembly with other copies follows an edit of any one of
them (Assemblies.after_edit), so posing one of two alike minifigures' arm
moved both. Before a pose is kept, each sub-assembly round what moves that
has other copies and does not move whole is made a copy of its own
(Assemblies.make_unique), innermost first, in the same undo step; the status
bar says "this copy of Figure is now its own; the other one stays as it
was", and so does move_part. One undo puts back the pose and the copy.

**By the chain.** A press held still 0.4 s on a part, then dragged, takes it
by its chain of joints back to the anchor (`src/assembly/grab_chain.gd`):
the status bar says "chain". Each joint's range is read once, turning it
alone through the lattice in 10° steps and bisecting the last (a minifigure's
two joints in 0.4 s, the crane's four in 0.25 s); each frame the end is drawn
to the pointer's ray within those ranges by cyclic coordinate descent, a dozen
rounds from the end inwards, started again from eight other turns when it
sticks where the reach curves away (a hand on its wrist and shoulder did).
Let go, every part that moved is tested against the rest of the model; if
anything is in the way the turns are eased back together to the furthest
that has room. On a minifigure the hand reached its point to 1.9 px on two
joints; on 4096 the crane's end to 1.4 px on four. Balls and slides in a
chain stay as they are.

**Over MCP**, `move_part`: part= a part's number or a sub-assembly's name.
Alone it changes nothing and says what would move, on what joint, whether it
holds or swings, and how the model stands. degrees= or along= move it as a
drag does and answer with what moved and the balance after.

**Left for later** (a chain over MCP, closed loops, what hangs on a driven
gear, free joints inside what moves, and a model that tips are section 11's).
A chain over MCP; a chain's ranges read with the other
joints turned (each is read alone, from where the model stands); closed
loops (P2); what hangs
on a driven gear following it; a free joint inside what moves settling too
(only the grabbed joint settles); dynamics (S2, P3); the click step measured
on real parts rather than read from retailers; settling a model that tips
(it is said and drawn leaning, not laid over).

## 11. Loops, what hangs on a train, and falling over (G2)

G1 left four things for later that a person meets at once: a part held at
both ends said so and moved nothing; what hung on a driven gear stayed where
it was; only the grabbed joint settled; and a model past its edge was drawn
leaning, not laid over. G2 does each, and no more precisely than the parts
allow.

**Closed loops (P2).** `src/assembly/linkage.gd`. Bodies grows its tree from
the anchor, and each link the tree did not grow along closes a loop. A grab
whose moving side is held by one of those (`Bodies.loops_out`) takes every
closing link whose loop runs through a joint that moves, and every joint of
those loops, until nothing more joins. Each joint is one unknown, its turn;
one more when it slides (an axle in a round hole, a piston); three for a
ball. A loop is closed when each closing joint still holds its halves
together: its point where it is in one is where it is in the other, and
their lines are one line (a ball keeps only its middle; a sliding joint
keeps only its line). The grabbed joint is driven; the rest are found by
damped Gauss-Newton (Levenberg-Marquardt) on those residuals, with exact
derivatives (a turn moves a point at x by its way crossed with x less its
point), from the pose last kept, the driver followed in steps of 5° so a
four-bar stays open or crossed as it was built. Real models hold a loop by
more joints than it needs; least squares takes the extra equations as they
come, so a redundant chassis does not read as jammed (§6, Redundancy). It is
P2's Newton-Raphson, numbered as §3 has it.

Honest about what it cannot do: where the loop does not close at the angle
the pointer asks, it stops at the nearest angle that does (bisected to a
fiftieth of a step) and says "its loop closes no further that way"; a loop
that closes neither a degree one way nor the other has no freedom and is
"Locked: this loop has no freedom". A slide inside a loop goes as far as the
loop takes it: its connectors' lengths are drawn approximately (8218's
piston needs 20 LDU of its cylinder and the connectors give 19). A loop
holds where it is put if any joint in it holds by friction; if none does, it
turns down under its own weight when let go, its driver stepped downhill
while the centre of mass of what it moves comes lower and it has room.

Measured on real sets, each against its closed form, by the pointer, 60
frames each (`grab_probe -- --only=loops`):

| set | loop | checked against | worst |
|---|---|---|---|
| 8020-1 Jeep | the steering: two arms on their kingpins and the track rod (a four-bar, 4 hinges) | the rocker's turn where two circles meet: the far pin on a circle about its kingpin, at the track rod's length from the near pin | 0.012° |
| 8218-1 | the engine: crank, connecting rod, piston in its cylinder (2 axles, a sliding hinge, a ball) | the crank-slider's quadratic: the wrist pin on the cylinder's line at the rod's length from the crank pin | under 0.001 LDU; stroke 20.00 LDU, twice the 10.00 LDU throw |

The engine needed two readings the connectors did not give: an engine's
piston slides in its cylinder, freely (`Bodies._slide_within`: a short shaft
inside a longer bore of the same round), and its rod's ball end sits between
the piston's two small bores, a socket no connector names
(`Bodies._bores_across`). Without them the rod hung loose from its crank and
the piston turned in its cylinder.

The room test had to learn three things the loops showed. A steering arm
built flush against the brick beside it met it by one turned 2 LDU cell at
3° and not at all at 10°: two parts whose turned boxes are into each other by
no more than 1 LDU only touch (`Grab._touching`, the separating axis test on
their boxes). A part turning on a line square to the face it rests on slides
over that face: its reach along the line is unchanged, so it meets the part
under it no more than it did (`Grab._slides_over`). A tyre resting on the
floor, turned with its axle, met the floor by its turned cover: a part round
about the line it turns on and centred on it (a wheel, a tyre, a gear) sweeps
only where it is, and is not tested (`Grab._round_on`).

**What hangs on a driven gear.** The gears a grab drives are Mechanism's
bodies; what hangs on them by a clip, a hinge, a tyre on its rim or an arm
pinned on is Bodies'. Every part of a driven part's rigid body in Bodies, and
everything beyond it there, now goes round with the driven part that carries
it (`Grab._follow_driven`), and is tested for room as the section is
(`grab_probe -- --only=follow`). A made train, an 8 tooth crank driving a 24
on a Technic brick with an arm on a hinge on the 24's axle: the crank turned
30°, the arm turns 10.000°, a third, to 0.0000° of the gear reading's rate.
On 8418's B model an excavator bucket (30394) hung on a driven body turns
3.750° for the crank's 30°, an eighth.

**Every free joint settles.** Let go, the grabbed joint swings down as
before, and then every joint inside what moved (and inside what follows a
driven gear) that does not hold by friction swings what it carries down
under its line too, innermost first and over again three times (a pendulum
on a pendulum), each as far as it has room against the model that stands
(`Grab._settle_inside`); the status bar names them. It is not tested against
the rest of what moved, which is not yet in the lattice.

**Falling over.** `src/assembly/topple.gd`. Let go past its edge (Balance's
margin below zero), a model turns about the support's edge the centre of
mass is past, until another corner of its cover reaches the floor: a corner
u out past the edge and h above the floor touches when the model has turned
atan2(h, u), and the least of those over every corner is where it rests on
that edge and the new point. While it still does not stand, it falls again
about the next edge, at most four times. Quasi-static, as the settling is:
where it comes to rest, not how fast or whether it bounces (§ What
"accurate" can honestly mean: "it will fall at 1.7 s" is not a fair claim).
It was drawn falling over half a second, faster as it goes (since G5 it
falls as a body falls about its edge, §14), and kept in the
same undo step as the grab, in words: "tipped over to the left and lies on
its side". A model standing on a baseplate's studs does not fall: they hold
it, and on a baseplate the plate is the floor; it says so ("It does not fall:
it stands on the baseplate's studs"). `GrabDrag.topple_on_baseplate` turns
that off. A model Balance reads as past its edge where it stood does not fall
either: Balance's support is the lowest cells, and 8218's smaller front tyres
stand clear of them, so it reads as tipping at rest; a grab of its engine
does not throw it on its nose.

Real sets rarely tip from one turn: the six biggest sections of 64 sets
turned ±90° and ±150° on no floor left none past its edge. So the probe
builds one that does (`grab_probe -- --only=falling`): a tall arm of five
1x2 bricks on a hinge (3937 and 3938) on a tower of four 2x2 bricks, on no
floor, the arm dragged out to 90°. Its centre of mass is then 6.7 LDU past
the tower's front edge. Let go, it falls 42.79° about that edge; worked by
hand over every vertex of every part as posed, the first point down is a
corner of the 1x2 plate on the arm's end, 108.0 LDU out past the edge and
100.0 up, atan2(100.0, 108.0) = 42.79°; that corner then stands 0.00 LDU off
the floor, nothing is below it, and the model rests with its centre of mass
a stud inside what it lies on: "tipped over to the front and rests leaning
43°, its far end on the floor". The drag and the fall are one undo step. On a
16x16 baseplate's studs the same drag leaves it standing: "would tip over to
the front, 0.3 studs past its edge. It does not fall: it stands on the
baseplate's studs".

**A loop's drag frame.** The steering's worst drag frame was 162 ms: every
round of bisecting where it stops worked out its arms' and wheels' turned
covers afresh, 11 to 16 ms each. A part whose turned box is apart from every
part near it, or into one only by touching, or sliding over a face square to
its line, skips its cover (`Grab._boxes_meet`); the driver turns on a
quarter-degree grid, so covers already worked out are found again; and a
stop is bisected a round at a time, finished on a pause. Over six runs on a
loaded box the drag's own worst frame was 26 to 41 ms (the wheel's cover
alone 11 to 16 ms as the box was loaded), whole frames 25 to 45 ms; not
reliably under 33. Covers worked out side by side on workers did not help:
Builder's worker cache holds its lock while it works one out.

The first move of a drag decides between turning and sliding a joint that
does both. It slid when the pointer went along the line more than across
it; seen from above its axle, a wheel's rim turns along that line on the
screen, and the engine's crank slid. It now slides only when the pointer
goes along the line clearly more than the point held goes when it turns.

**The release frame and a chain over MCP.** A big section let go is checked
and swung down on a worker (`GrabDrag._verify_off_thread`), the window
drawing it where it was let go meanwhile; the frame-at-a-time path stays for
the browser without threads. `move_part` takes `to=` [x, y, z] in studs, as
it says where a joint is: the part drawn there by its whole chain back to
the anchor (GrabChain, as a person's hold-then-drag), tested, eased back to
the furthest that has room, one undo step. On 4096 the crane's end reached
its point to 0.32 LDU along 4 joints. On 7191 the 131-part wing let go is
now checked and kept in 8 s, its worst frame 69 ms (the commit 49 and what an
edit sets going 17; the checking itself is off the window); it was 17 to
20 s with a worst frame of 160 ms.

**Left for later.** Racks: a rack driven by its pinion, a steering rack
and its arms, a scissor lift (Mechanism has no prismatic joint yet, §5), done in section 12;
a loop's drag frame reliably under 33 ms; a loop through a joint the tree grew
as a ball is solved, but the ball itself cannot be grabbed to drive it; the
settling of free joints inside a loop; the fall of a model whose support
Balance cannot see; dynamics (S2, P3).

## 12. Racks and scissor lifts (G3)

G2 left racks and scissor lifts for the next unit. Both are loops, so both go
through `Linkage`; a rack needed one more kind of equation, and a scissor lift
needed a loop that is driven by a slide.

**A pinion in its rack.** `src/assembly/racks.gd`. Every rack the library
draws from a tooth primitive has its teeth 8 LDU apart: ten to the four studs
of a 1 x 4 (3743), and the same in the 1 x 8, 1 x 10 and 1 x 14 with holes
and the 1 x 7 and 1 x 13 steering racks (two authors). A pinion's pitch
circle is 1.25 LDU a tooth (section 2), 7.854 LDU of arc a tooth. Teeth do not
slip, so a turn of an 8 tooth pinion moves its rack 8 teeth, 64 LDU; its pitch
circle would say 62.83. The 1.9% between them is taken up in the teeth's
play, and the rack moves 8 LDU a tooth, as the parts are drawn. Whether a
real rack is cut 3.2 mm or π mm a tooth, the parts do not say, and nothing
we found does.

Where a pinion stands against a rack was measured on the OMR's sets, in the
rack's own frame (the gear table's `racks`): a 3743's 8 tooth pinions stand
14 LDU above its origin in 50 pairs and 12 or 16 in 26 more, a 16 at 26, so
its pitch line is 4 LDU up and a mesh is read within 3 LDU of it (8849-1
stands its at 11); the 1 x 8 and 1 x 10 with holes have theirs at 2, the
1 x 14 at 0, the 1 x 7 and 1 x 13 steering racks at 5 (55 pairs of a 12 at
20). 2790a's teeth are drawn without
the tooth primitive and were not counted; 18942's pinion was not met in a set.

`Racks.find` reads each pinion in a rack, and `Linkage` takes each as one
more equation of a loop: where the pinion's centre now is, seen from the
rack, along the rack's teeth, from where it was, plus the teeth's share of
the pinion's turn against the rack, is nought. Its derivatives are exact, as
the loops' are: a joint on the pinion's side moves the centre the rack sees,
one on the rack's side moves the rack under it the other way. The 1980s
Technic steering is this loop: the rack rides on the track rod, which is the
coupler of a four-bar with the two steering arms, and the pinion on the
steering column pushes it. Read from the column, the pinion is a closing
link like any other, so turning the steering wheel turns the wheels, and
dragging a wheel turns the column.

Measured with the pointer on the steering, 45 frames each, against the
geometry by hand (`grab_probe -- --only=racks`): the rack's place along its
teeth against 8 LDU a tooth of the pinion's turn in the rack; the near arm's
turn found by bisection where the track rod's near pin, carried round its
kingpin, puts the rack at that place, the far pin where two circles meet;
the far arm's turn from the far pin.

| set | steering | rack against its teeth | near arm | far arm |
|---|---|---|---|---|
| 8841-1 Chassis | the steering wheel, by a universal joint to the pinion's column | 0.010 LDU | 0.014° | 0.016° |
| 8808-1 | the steering wheel on the pinion's column | 0.010 LDU | 0.016° | 0.018° |
| 8054-1 Model C | the column, turning the pinion's axle through two 14 tooth bevels | 0.001 LDU | 0.001° | 0.001° |
| 8828-1 Grader | the column, through two 14 tooth bevels | 0.010 LDU | 0.015° | 0.017° |

**Through gears.** A steering column often turns its pinion through a pair
of bevels. A grab whose gear train (Mechanism's, read ahead) reaches a
pinion in a rack that does not move with it offers the train's meshes to
the loop (`Grab._train_to_racks`), and `Linkage` takes each as one more
equation, linear, as Mechanism writes it: the two gears' teeth move together
where they meet. On 8054 and 8828 the pinion turned one to one with the
column, as the 14 and 14 teeth say, to 0.001° and 0.024°. That row is exact
only while each gear turns on its own axle in what stands; where a gear
rides on a joint the loop moves (8062-1's column, in a cab of hinges), the
grab turns the column as before, its gears by their teeth, and leaves the
rack (`Linkage.gears_carried`). Offered so, 8062's pinion had turned 4.6°
off its bevels.

5533-1's tractor does not pass: its steering wheel turns the pinion by
gears, which this does not read, so the column is turned instead; it stops
at 24° against the model, and its arms stand 5.7° and 9.2° off the planar
hand form, whose kingpins it takes to be parallel (5533's lean 3° and stand
6 LDU apart in height). It is left out of the run and can be asked for with
`--rack-set=`.

On 8841 the steering wheel turned 30° turns the pinion 30° in the rack,
two thirds of a tooth: the rack goes 5.33 LDU and both arms 7.66°; at 90°,
two teeth, 16.00 LDU and 23.58°, by hand and as drawn. The 8020 Jeep's
four-bar of section 11 now carries its pinion's column round with it, and
its far arm still stands where the circles put it, to 0.004°.

**A scissor lift.** A loop that cannot turn the joint grabbed but can slide
it is driven by the slide (`Linkage.can_move`): a scissor lift's foot on its
rail cannot turn about the rail, and slides along it. No set in the OMR has
a scissor lift whose sliding foot the joints read (42078's tipper has a
scissor driven by a rack in its housing, which `Bodies` does not read as a
slide), so `grab_probe -- --only=scissor` makes one: two stages of beams 9
crossed and pinned at their middles and ends with friction pins, one foot
pinned to a beam 15 on the floor, the other on a cross block that slides
along an axle 8 held at its ends by two more cross blocks. Each link is
160 LDU between its end pins, so with its foot x from the fixed one the top
stands 2·sqrt(160² − x²) above it. Dragged by its foot from 113.14 LDU
(45°) to 33.14 LDU (78.05°, 313.06 high) and back, in 41 frames the top
stood where that puts it to 0.015 LDU. A lift held only by its foot's slide
is not a real one: on an axle in round holes, a part slides as far as the
axle reaches, and nothing here stops it sooner but the parts it meets.

**The loop's drag frame.** The steering's worst drag frames worked out one
part's turned cover, 11 to 18 ms, and it was most often the first frame
finding what a part already overlapped where it stood (a wheel's box into
its neighbour's), which is forgiven for good once found. A loop's grab of
no more than 80 parts now finds those at the press (`Grab._chosen`), as the
first frame would. Builder's worker cache held its lock while it worked a
cover out, so covers asked of workers side by side took turns; it now holds
it only to look up and to keep (`Builder.boxes_for`), and a grab works out
the turned covers a frame's test will want side by side on the engine's
workers before testing (`Grab._covers_ahead`), kept as `boxes_for` keeps its
own. Not in a browser: its workers start when first asked, and the first
drag there waited 1.3 s for them.

Over four runs of 8020's four-bar on a loaded box (`grab_probe --
--only=fourbar`), the drag's own worst frame was 13.7 to 15.5 ms (26 to
41 ms before), one steering arm's cover where it rests on the brick under it
(12 to 14 ms); whole frames, with drawing and the balance weighed every
50 ms, 29.7 to 37.9 ms. 8808's steering's own worst frame went from 25 to
31 ms to 2.2 ms. In a browser, the flat four-bar's frames cost 1.4 ms on
average and 5.6 ms at worst, and the page's longest wait during the drag
was 69 ms.

**A round part beside the line.** From G2's loop work on, a drag on 4096's
turret stopped at 3.7° either way, where the build before it turned. The
two cones under the boom turn with it, and their turned covers, 2 LDU cells
worked out turned from a square, reached past the round cones into the
2 x 2 plate beside their feet by up to 1.2 LDU from 3.7° to 8.8° either way,
though the cones swing away from it. The room test had seen that span
before too: the build before only jumped past it, its first frame reading
-8.8°. A part round about its own middle's line along the joint's (a cone,
a round brick, a wheel lying flat) is now tested as its shape where it
stood, moved round (`Grab._shape_at`), which is what it is; pushed 4 LDU
into the parts beside them, the cones still meet them (`grab_probe --
--only=turntable`). The turret now follows the pointer all the way round.

**Tried and left.** 42035-1's 1 x 7 steering rack is read as one body with
the connector its pinion's axle turns in, so the pinion cannot push it;
8849-1's whole steering is read as hanging from the pinion's axle. Both are
`Bodies` readings of a sliding fit the connectors do not name.

**Left for later.** Gears riding on joints the loop moves (8062's column);
5533's steering wheel, which reaches its pinion by neither. A rack held in
a guide the joints do not read (a 1 x 13 steering rack between beams,
42078's rack in its housing, 42035's in its connector): `Bodies` gives it no
slide. Worms and linear actuators driving a rack (the library has both; a
linear actuator's travel per turn is not published); 2790a's teeth; whole
frames, drawing included, under 33 ms; dynamics (S2, P3).

## 13. Worms, linear actuators, gears that ride, and the frame (G4)

G3 left worms, linear actuators, gears riding on joints a loop moves, racks
in guides the joints do not read, and whole frames under 33 ms. G4 does the
first three and the frame; the racks in guides are left, and why is below.

**A worm turns its gear, and holds it.** Mechanism already read a worm as a
mesh whose thread advances a tooth a turn (section 3), so a worm's axle
grabbed turns its gear by its teeth. Turned the other way, from the gear's
side, it turned the worm backwards, which a worm never does: its thread
climbs a tooth, π mm, round a 4 mm pitch radius, a lead angle of 7° (5° for
27938's 6 mm), too shallow for the gear's teeth to push it round. A grab
whose train reaches a worm from its gear's side, going out from the grabbed
joint mesh by mesh (`Mechanism.worms_back_driven`), or whose loop moves a
gear whose worm stands still (`Grab._worm_holding`), is refused in words:
"Held by a worm: … a gear cannot turn its worm back (a worm is
self-locking: its thread climbs at 7°, too shallow for the gear's teeth to
push it round). Turn the worm's axle instead." The friction that makes it
so is not measured (section 4); that it holds is what builders build
cranes and winches on. Which way a worm's thread runs is still not read
from the part (section 2): the ratio is the teeth's, the direction assumed.

Measured with the pointer, two whole turns of the worm in 10° frames, the
gear against the teeth its name gives (`grab_probe -- --only=worms`):

| set | worm drives | gear's turn for the worm's 720°, by hand | worst | the gear's side grabbed |
|---|---|---|---|---|
| 42042-1 Tower Crane | the winch's spool, through an 8 | 720/8 = 90° | 0.0000° | held, said |
| 8063-1 Sower | a 24 tooth crown gear | 720/24 = 30° | 0.0000° | held, said (a loop) |
| 8049-1 | the log grabber, through an 8 | 90° | 0.0000° | held, said |

8062-1's crane winch stops at once: its gear's axle carries a universal
joint, and what hangs on a driven gear goes round with it rigidly (section
11), so the joint's centre met its far end; a universal joint passing a
turn on is not read. 8258-1's worm stops at 10°, a beam on its axle meeting
the beam beside it.

**Linear actuators and cylinders.** The library draws each actuator as a
body and a rod, and its own contracted and extended files place the rod
for each end: the small 4 x 1 x 1 (92693c01) 60 LDU apart, three studs; the
8 x 2 x 2 (62271c01, and u9559c01 of 43097) 100; the 12 x 2 x 2 (u9487c01)
160; the 2 x 11 pneumatic cylinder (19466c01) 120. The gear table's
`actuators` keeps those (`tools/gears.py check` holds them to the files),
and `Bodies` reads a rod standing on its body's axis between them as a
joint that slides and does not turn (`actuator`, `cylinder`), from where it
stands to either end; nothing else the two share joins them. A screw holds
where it is left and so, with its valve shut, does a cylinder's air. In a
loop the actuator is a joint of the tree, not the one that closes it, so a
drag on its rod drives the loop by its slide (`Linkage`, which keeps every
slide of an actuator within its stroke and never turns one).

Turning the input: the small actuator's input is a part of its own (92695),
and a turn of it drives the rod by the screw, read as a pinion in a rack
(`Racks.screws`): the rod goes the stroke over the input's turns. How many
turns is not published, nor drawn: the screw is inside. Builders counted
them on the Eurobricks forum (topic 196207, 2023-24): the small one 7,112°
to 7,226° from in to out over six runs, 19.9 turns, so 60/19.9 = 3.02 LDU
(1.21 mm) a turn, to about 1%; the 8 x 2 x 2 9,665° to 9,709°, 26.9 turns,
3.72 LDU a turn; the 12 x 2 x 2 43.75 turns, counted once. Which way round
draws it out is not read. The 8 x 2 x 2's input is drawn in its body's part,
so it cannot be turned on its own; its rod is dragged. A screw cannot be
pushed round from its rod: a grab of anything else in an actuator's loop is
refused, "Held by its linear actuator: … whose screw holds it where it is
(a screw is self-locking). Drag the actuator's rod, or turn its input."

Measured with the pointer on the rod, 4 LDU a frame out past one end, in
past the other and back, the arm it raises against the law of cosines by
hand: the rod's pin drawn along the actuator from where it stood, the pins
|r + a e − p| apart square to the arm's pivot, the angle at the pivot from
the two pins' distances to it (`grab_probe -- --only=actuators`):

| set | actuator | travel drawn | ends | arm against the law of cosines |
|---|---|---|---|---|
| 42081-1 | 8 x 2 x 2 raising the digging arm | −56.00 to +40.00 LDU, 55 frames | out to the end exactly and no further; in, 4 LDU short of its end, the room test stops it (a 15265 meeting a 3811) | 73 poses, worst 0.0021°: the arm turned 29.67° at the outer end, 36.44° the other way at −56 |
| 42024-1 | the small one, in a loop of 36 joints | −44.00 to +4.00 LDU, 14 to 16 frames | the room test stops it both ways first (a pin 6558 meeting a cross block 6536) | 49 poses, worst 0.0002° |

On 42024-1 the input turned a whole turn over MCP (`move_part degrees=360`)
moved the rod 3.014 LDU against the 3.015 the count gives, and one undo put
input and rod back. The arm grabbed on either set is held, said. 42006-1's
boom closes its triangle to 0.006° but stops 3.4 LDU out and 13.3 in, a beam
of the boom meeting an axle of the turret by the room test. 42080-1's
pneumatic cylinders are not read sliding: their rod and body are in one
body of 458 parts, held to the turret by more than the cylinder.

These loops are big, and their drag is slow: 42081-1's 25 joints and 262
parts cost 174 ms a frame on average, 42024-1's 36 joints 137 ms, solving
and testing for room together; a person sees the arm follow in steps. A
section this big moved by its slide was bisected where it stopped by
whole room tests: 42081-1's arm, 262 parts, held one frame 31 s at the end
of its stroke (164 tests). A slide is now tested within the frame's share
and its stop found on pauses and at the release, as a turn's is
(`Grab.slide_to`, `Grab.verify_step`).

**Gears that ride on joints a loop moves.** G3 read each gear mesh offered
to a loop as Mechanism's linear row: right while each gear turns on its own
axle in what stands, and 4.6° off on 8062-1, whose steering column turns in
a cab of hinges, so the column route was refused there. A mesh is now held
by each gear's turn read against the line from it to the other gear's axis
(`Linkage._gear_turns`), its lever as Mechanism has it: a pair carried round
together turns neither against the other, so the equation is as exact on a
moving carrier as on a fixed one (unwrapped against the turn last kept, so a
worm turned many times over in a drag stays on its count; its derivatives
by central differences, being read off angles). Then the cab's hinges took
up a share of the column's turn, 10.7° of 30: least squares over every joint
moves the free ones too. What carries the driver is now held where it is
first (`Linkage._carrying`), and freed only when the loop closes no other
way, for the rest of that grab (a wheel turned on its steering arm moves the
arm's kingpin). A bevel turned on its joint in a moving cab was tested by its
turned cover and met the plate beside it at 4.25°; a round part on a joint
the loop carries is tested where its carrier puts it (`Grab._tested_at`).

8062-1's column dragged ±90° by the pointer, 45 frames: the pinion turns
1.000 of the column's turn to 0.001°, both measured against the column's
carrier (Willis: in the carrier's frame two gears turn as their teeth say);
the rack a tooth for a tooth of the pinion to 0.000 LDU; both arms by hand to
0.000°. 8054-1 and 8828-1, through bevels that stand still, 0.001° and 0.024°
as before; 8841-1 and 8808-1 unchanged.

**The four-bar's whole frame.** G3 measured 8020-1's four-bar at 29.7 to
37.9 ms a whole frame, drawing included, and its own work at 14 to 16; what
else a frame did was not known. Each frame is now taken apart
(`grab_probe -- --only=fourbar`): the window's own frame with nothing moving,
timed for 30 frames before the press; the renderer's CPU and GPU time
(`RenderingServer.viewport_get_measured_render_time_*`); the drag's own work
(`GrabDrag.last_motion_ms`: following the pointer, set_drawn, weighing,
saying); and rewriting the batches the moved parts are drawn in
(`BrickWorld.rebuilt_ms`). On a quiet box, the windowed probe under xvfb:

| per frame | mean | 95% | worst |
|---|---|---|---|
| whole drag frame | 15.0 ms | 19.4 | 25.9 |
| the window alone, nothing moving | 13.5 | 16.5 | 21.2 |
| the renderer, CPU / GPU | 1.0 / 6.1 | 1.3 / 6.8 | 1.5 / 7.2 |
| the drag's own work | 1.7 | 9.8 | 11.1 |
| rewriting the moved parts' 16 batches | 0.3 | 0.5 | 0.8 |

A drag frame is the window's idle frame plus the drag's work: drawing what
moved adds nothing measurable (−0.2 ms on average). The idle frame is most
of it, and it is the harness's: xvfb shows the picture through a software
copy (`MESA_VK_WSI_DEBUG=sw`), which no display with a GPU swapchain has.
The drag's worst is one steering arm's turned cover, 9.3 ms, where it stands
in its brick. With the web export running beside it on the same box, the
same drag measured 20.7 mean and 35.5 worst, the idle frame 16.0 and 30.8
(in the full run, a browser test beside it: 20.5 and 42.8, idle 18.3 and 33.1):
the box's load moves the whole frame more than the drag does, so "under
33 ms" holds on a quiet box and is not a promise under load. The probe now
checks what the app controls: the drawing's share of a drag frame (under
4 ms on average). The status line during a drag is said ten times a second
rather than each frame (`GrabDrag.TELL_EVERY_MS`): every new line was laid
out afresh and set a timer of its own to clear it; its share was not
measured apart.

**The first drag in a browser.** grab_flow held release m54: on its
preview the page waited over 250 ms during a drag. Five alternating runs
each on local exports of the held build (d24d4d6) and live's (047bb4a), on a
box loaded 12 to 43 on 24 cores, waited over 250 ms in two runs of five on
both, nearly always in the session's first drag: the held build 470 and
335 ms, live's 387, 671 and 805. The app's own drag frames stayed under
13 ms in every run. So it was not the racks' code. A build that says the
app's longest frame gap and what the grab spent in it, traced in Chromium,
put the wait in the renderer: a 670 ms gap in which the grab spent 1 ms (its
press). Two causes, one the app's:

- In the first frame of the first drag Godot built the balance mark's
  shaders: 10 compiled, 3,208 queries of their uniforms, 203 ms. Proven the
  mark's by a build that draws no mark during the drag: the build moved to
  the frame after the release, where the mark is first drawn. The mark is now
  drawn once, unseen, as soon as the model has been read (`BalanceMark.warm`,
  a transparent triangle in front of the eye for two frames, as Render warms
  its renderer before it is opened); in six traced runs no first drag built
  a shader.
- After each pointer move of a drag the renderer checks a framebuffer and
  asks the GPU a question (`checkFramebufferStatus`, `getParameter`), and a
  question waits for every command the GPU process has queued. In a browser
  drawing in software that process is SwiftShader on the same loaded CPU: one
  to one and a half seconds into the first drag, on both builds, with and
  without the mark, it was 334 to 950 ms behind, and the page waited that
  long. Later drags in a session mostly waited under 100 ms, but the four-bar
  waited 219 to 805 ms in three runs of ten, the same way. Which call of the
  renderer checks the framebuffer was not found; in two of three runs of the
  warmed build the first drag waited 16 to 28 ms. It is SwiftShader's time,
  and left.

**Racks in guides, tried and left.** 42035-1's 1 x 7 steering rack (87761)
is pinned through its middle hole by a long pin (87082) into a beam 7, so
read as the parts stand it can only turn on that pin, and its 12 tooth
double bevel's axle turns in a cross block (32184) pinned to the same beam:
the pinion cannot push it, and whether it slides on that pin in the real
model the parts do not say. 42078-1's racks with a beam under them (18942)
slide in their housings (18940), two pairs on the main model with no gear
within 70 LDU of either, and one alone on the dump truck with none within
50: there is no pinion in either file to read 18942's pitch line from
(section 12), so a guide read as a slider would move only by dragging the
rack itself. Both want the guide read from the parts' shapes (a slot the
rack's beam runs in), which the connectors do not give.

**Left for later.** Racks in guides (above); a universal joint passing a turn
on (8062-1's crane winch); a worm's hand, read from its thread; 42080-1's
pneumatic cylinders, held to their turret by more than the cylinder; the
8 x 2 x 2 actuator's input, drawn inside its body's part; a big loop's drag
(an actuator's arm in a loop of 25 to 36 joints, 137 to 174 ms a frame;
42081-1's held one frame 1.9 to 3.1 s, one room test of one large part, and
let go it was checked and kept in 22 s on a box loaded 41, not yet taken
apart; section 15 takes it apart and does it); whether the
meetings that stop 42006-1's boom and 42024-1's small actuator short of
their ends are the real sets' or the room test's 2 LDU cells (not checked
against the built models); dynamics (S2, P3).

## 14. Swinging and falling in time (S2's first slice)

G1 to G4 settled a free joint and a falling model quasi-statically: where it
comes to rest, not how it gets there. A pin without friction ridges let go
jumped to where its arm hangs, and a model past its edge was drawn falling
over a fixed half second. The owner asked that a person move any part "with
perfect physics", and a free joint that does not swing is the first thing a
person sees is wrong. G5 is the motion: a section let go swings, and a model
that tips falls as a body falls.

**A pendulum, or a chain of them.** `src/assembly/swing.gd`. Let go, a section
on a free joint (a pin without friction, an axle in a round hole, a turntable
on its side: §10's `holds` false) is a rigid body turning about that joint's
line, and every free joint inside it another (`Grab.swing_begin`), on Bodies'
tree: an arm on two free pins is a double pendulum. The equations are
Newton-Euler's written in the joints' turns, M(q) q'' = Q(q, q'): the mass
matrix and the forces from each segment's mass, centre and moment of inertia,
gravity, and the velocity terms (a swinging outer arm pulls on the inner one).
They are stepped at 1 ms by semi-implicit Euler, which keeps a pendulum's
energy from growing as an explicit step's does; at this step its period is
off by under a part in ten thousand for anything that can be built. A click
hinge, a ball, a loop, a gear train and a section of more than 40 parts settle
as before (§10, §11).

What it is made of, and how sure each is:

| quantity | taken as | how sure |
|---|---|---|
| mass | `Stability.grams`: a part's walls, studs and tubes | within 6% of BrickLink's weighings for common bricks (§4); a mean figure, not this part's |
| moment of inertia | each part's mass spread evenly through its box, about the line by parallel axes | a brick's mass is mostly in its walls, so its own share is low by up to a third; for a section a few studs out from its joint that share is a few per cent of the whole |
| friction in a free joint | a journal bearing: μ r N against the turn. r 2.4 mm, a Technic hole's radius and a stud's; N the weight carried; μ 0.3 | μ for ABS on ABS is not published. ABS against steel and printed ABS on a pin-on-disc read 0.2 to 0.4 ([Ramadan et al. 2023](https://tribology.rs/journals/2023/2023-1/2023-1-13.html)), so the number of swings is good to about a factor of 1.5 either way. The rub of a beam's face on the beam beside it is not counted (nothing says how hard a pin's collar presses them), so a real arm may stop sooner |
| what it meets | the room test (Grab's), each time the furthest moving point has gone 4 LDU, bisected where it meets something | as the drag's: 2 LDU cells. It stops dead there: how much a section of bricks bounces off another is not measured, so it does not bounce |
| at rest | no joint's furthest point moving faster than 0.2 mm/s for 0.12 s | held by its friction within asin(μ r / d) of hanging straight (d its centre of mass's distance from the line), or pressed against what stopped it |

Coulomb friction takes a fixed share of each swing: a pendulum loses
2 μ r / d radians of its swing each half, and stops inside asin(μ r / d) of
the bottom. Both are checked by hand below. Several free joints' friction is
solved together at the velocity (projected Gauss-Seidel), each joint sticking
or slipping as its torque allows.

Measured with the pointer, windowed (`grab_probe -- --only=swing`), on made
pendulums: a Technic beam 7 (32524) on a pin without friction (3673) in a
Technic brick 1 x 4 on a tower of twelve 2 x 4 bricks, the beam in front of
it. By hand from its parts as the probe reads them (the beam 1.81 g, its pin
0.46 g): m 2.27 g, d 47.9 LDU, I 9,455 g·LDU², so 2π√(I/(m g d)) = 0.3744 s.

| case | checked against | result |
|---|---|---|
| let go 30° out | each half swing against T0 lengthened for its amplitude by the elliptic integral, 2K(sin(θ/2))/π | five half swings: 0.3768 s a swing against 0.3762, 0.17% off; the worst half 0.36% |
| the same | the swing lost each half, 2μr/d = 4.30° | 4.38°: 29.9, 25.4, 21.0, 16.6, 12.3, 7.9, 3.6° from hanging |
| the same | where statics hangs it, within asin(μr/d) = 2.15° | 0.68° from straight down; the settle before it, 0.00° |
| the same | its energy never above where it was let go | never above it |
| let go 75° out | the first half swing against 2√(I/(m g d)) K(sin(θ/2)) at its mean amplitude, 0.2076 s | 0.2050 s, 1.3% off (Coulomb's loss within the swing is not in the hand form); 15 swings in 3.1 s, at rest 0.67° from hanging |
| a column of 1 x 2 bricks in its swing, let go 60° out the other way | where a turn towards the column stops, 36.75° | its first swing ends at 36.85°, stopped dead; then it swings back and comes to rest hanging |
| two beams 7 on two free pins, the inner let go 60° out | where the settle before it hangs the outer beam; its energy | they swing together, the outer folding against the inner and back, 28 times in 7.1 s; the outer beam comes to rest 2.0 LDU from where the settle hangs it (each pin's band, 0.9° and 1.7°, allows 4.5), the inner 0.97° from hanging; the energy never above where it was let go |
| move_part degrees=40 | the reply | "then swung down under its own weight and back and forth 8 times in 1.7 s, and came to rest at 0°, hanging within its friction of straight down" |

**Falling in time.** `Topple.timed`. Where a model that tips comes to rest is
still `Topple.fall`'s (§11); how it gets there is now a rigid body turning
about its edge from rest under gravity, θ'' = τ(θ)/I, its moment of inertia
about the edge from the parts as above, stepped at 1 ms, stopping dead where
it lands. A second fall about a further edge starts from rest. The edge is
taken not to slip. Checked against the time by hand: energy gives
θ'² = 2 m g r (cos φ0 − cos(φ0 + θ)) / I for a centre of mass r from the edge
and φ0 past upright, and the time is the integral of dθ/θ' to the angle it
falls, by Simpson's rule with θ = s² to take out the start's 1/√θ
(`grab_probe -- --only=falling`):

| model | by hand | Topple.timed |
|---|---|---|
| §11's made crane, its arm out 90°: 11.43 g, r 81.7 LDU, φ0 4.68°, I 111,472 g·LDU², falls 42.79° | 0.2109 s | 0.2110 s |
| the made crane with a beam 3 on a free pin at its tower's side, its arm two bricks longer: 15.81 g, r 97.8 LDU, φ0 7.28°, falls 39.97° | 0.1974 s | 0.1970 s |

A model barely past its edge falls slowly at first: the made crane is a
fifth of a second, against the half second drawn before. It is drawn by the
clock, and no frame of either fall drew a corner below the floor.

**What hangs on a free joint as it lands.** A model past its edge as it is let
go begins to fall at once, and what hangs on a free joint inside it is held
while it falls (a fifth of a second) and let go as it lands
(`Grab.land_begin`): the model stops dead, and the free parts keep their
momentum about their joints (`Swing.carry`: M q' = Σ Jᵀ (m v, I ω) of the
motion they had), so they swing on in the new lie until they hang. The two
together, a joint swinging while the model falls, are not worked out. A
grabbed joint that is itself free swings first, as before: it drops at
once, and its swing may bring the weight back over the base. The made
crane's beam 3, carried 40° off hanging by the fall, swung back and forth 5
times in 0.58 s and came to rest 0.01° from straight down below its pin
(its band 5.2°). The drag, the fall and the swing are one undo step, and
over MCP: "Then it tipped over to the front and rests leaning 40°, its far
end on the floor: … falling for 0.20 s. As it landed, the Technic Beam 3, 1
part swung down under its own weight and back and forth 5 times in 0.58 s,
and came to rest hanging within its friction of straight down."

**In the app.** A swing is drawn by the clock, its time stepped each frame
(`GrabDrag._swing_frame`) within 8 ms of the frame's work: past that it goes
slower than the clock rather than hold the frame. It is kept as one undo step
with the drag when it comes to rest; a click catches it where it is ("caught
by a press 0.18 s into its swing"), kept the same way; Escape puts it back.
Over MCP, move_part runs it to rest at once and says how it swung and where
it came to rest. On the windowed probe under xvfb the swing's own work
(stepping, its room tests, setting what is drawn) was 0.32 ms a frame on
average and 0.72 at worst for the beam let go 30° out (94 frames, 104 room
tests, none over 0.03 ms), 0.70 and 8.33 from 75°, 1.26 and 8.11 for the
double pendulum (319 frames; the worst are frames catching up after the
probe took a picture, stopped at the 8 ms budget), and 1.15 and 3.64 for the
beam swinging as the crane landed. Each frame steps the time the clock has
moved since the last, carrying what a whole 1 ms step ran over: the beam's
1.44 s swing took 1.45 s on the clock, the double pendulum's 7.19 s 7.21,
and the fall 0.199 s for its 0.197.

In a browser (grab_flow: a beam 7 on a free pin beside the crane, the
threaded web export drawn by SwiftShader on a loaded box) it swung as on the
desktop, back and forth 14 times in 2.9 s, and came to rest at −1°; its own
work was 5.4 ms a frame on average and 8.1 at worst. The page drew it
slowly: from the release to rest its frames came 0.58 s apart (median),
where turning the view with a right-drag drew them 33 ms apart in the same
run, so the 2.98 s swing took 10.7 s on the clock in 14 frames. A frame
steps the swing at most a quarter of a second
(`GrabDrag.SWING_MOST_FRAME_S`); at the first cap, a twentieth, the same
swing was drawn fifteen times slower than it is.

Traced in Chromium (`grab_flow --trace=FILE`, with `--trace-drag=` and
`--trace-view=` for the arm's drag and the view turning): each long frame of
the swing is the page waiting on the GPU process in
`CheckFramebufferStatus` or `GetBooleanv` (1.5 s of a 1.6 s frame), and the
GPU process's WebGL flushes add up to 13 to 16 s over the swing's 16 to 18
frames, about a second of SwiftShader's work a frame. The arm's drag costs
770 ms of flushes over its 24 drawn frames (32 ms a frame), the view turning
2.2 s over 17 (130 ms). Tried and ruled out, each in a build of its own,
none bringing a frame under 0.6 s: the swing worked out ahead at the
release and drawn back with no room test in a drawn frame (the app's frame
0.05 to 0.23 ms); its moving part drawn apart from its batch, a one-instance
MultiMesh moved by its node's transform, so no batch's buffer is written a
frame (`_fresh_slots` is not it) and no `rebuilt` listener runs; and that
part casting no shadow. What a frame in which a part has moved costs
SwiftShader that one in which the view has turned does not is not found.

**Found (swingtrace, 2026-10-17): nothing; a swing frame costs what any
drawn frame costs.** Each of the app's WebGL calls recorded in the page
(a wrapper round the context, `bench/results/swingtrace-2026-10-17/`): a
drawn frame of the crane is 20,842 calls, the same call for call, objects
renumbered, in a drag before any swing and in one after it, but for where
one draw's blend is set. The GPU process traced with
`--enable-gpu-service-tracing` says the same of a drag frame and a swing
frame: 514 and 535 instanced draws, every other call within a few per cent.
`CheckFramebufferStatus` is Godot checking the multisample resolve's
framebuffer in every 3D frame, a drag's as well, and `GetBooleanv` a
`getParameter` before the last blit to the page: neither makes anything,
both are where the page waits for SwiftShader to finish the frame before.
What a frame is, for SwiftShader: the sun's 4096² shadow atlas (four 2048²
splits cleared, two drawn), the model's depth and colour into a 1400 × 900
target four samples deep, three full-window blits resolving depth, stencil
and colour, glow's seven passes, the tone map, the interface and the blit
to the page, 550 draw calls and 265,000 primitives.

Counted in frames the app drew (`Engine.get_frames_drawn`, which the page
now has as `window.brickworksGrab.drawn`), in one page on this box at load
36 to 40: the arm dragged as a person drags it, a move every 60 ms, 108 ms a
drawn frame; the same drag moved without a pause, 437; the swing, 746;
after it the paced drag 895 and the unpaused one 609, and a second swing
347. A view turning drew its first frames in 119 and 258 ms and the rest in
627 to 713. The drag's "17 ms" was the page's median gap, and a drag draws
only when the pointer moves: most of the page's frames had nothing drawn.
A swing and a turning view draw every frame. SwiftShader's sixteen workers
had a fifth to a third of a core each (load 45 to 58, the browser at the
pool's nice 10), 3 to 5 cores in all, 2.5 to 3.5 CPU-seconds a frame.
Taken away one at a time while it swung, none of them made a frame cheap:
the hover outline (1.1 frames a second), the parts bin's pictures (1.8),
the sun's shadow, multisampling, glow (670 to 980 ms a frame; all three
together 548), the same pose drawn again every frame (2.2 frames a second),
a frame drawn only once the card had finished the last (by a fence: the
page never waited past 33 ms, and the swing drew 1.1 a second), every
fourth frame drawn (1.5). Why one drawn frame costs 110 ms in one minute
and 900 in the next with the same calls is not found: it follows the box's
load and how long SwiftShader has been drawing without rest, and switching
the 3D off for two seconds brought a drag back to 107 to 118 ms three times
at load 42 or under, and not at 54.

grab_flow judged the swing against the page's median gap while the view
turned. It now says both in frames the app drew a second and gates neither:
the rate is SwiftShader's on a loaded CPU (a turn drew 1.0 a second one run
and 2.4 the next), and three quarters of the turn's rate failed the swing in
one run of two with nothing changed. What it gates is what the app controls,
as for a drag: its own work in a swing frame (under 33 ms; 0.30 ms on
average on the desktop), no page wait past 5 s, and the swing coming to
rest. Fifteen a second for this model drawn in software would take
SwiftShader a tenth of the work it does a frame now; a browser drawing on a
graphics card is not held by it.

**The let-go and the keep, timed (letgo, 2026-10-18).** m79 was held on
the swing's page wait in grab_flow on its preview: 7.8, 15.0 and 15.7 s,
where live m78 had waited 2.4 s minutes before. Nothing in m79 costs it.
Local exports of both, each browser held to cores of its own (`taskset`),
waited alike: 3.5 s for m79 and 3.7 s for m78 on four cores one after the
other, 7.6 and 8.0 s on three side by side, 12.1 and 11.4 s on two, both
failing the 5 s hang gate from three cores down. Unpinned, m79 waited 1.6
to 2.0 s at load 5 to 21, its preview 1.6 s, and m78 1.6 s at load 23. The
runs that held m79 were at load 22 to 30; m78 at load 45 had waited 4.0 s.

The wait starts at the release, and it is drawing. A heartbeat in the page
marked the press, the release and the rest: the long gaps begin at the
release. Traced from the press, the swing's first five frames each cost
SwiftShader two WebGL flushes the size of a whole drag frame (3.3 to 4.8 s
a frame on three cores), and the later ones one. Between them the page's
timers starve, so a 50 ms heartbeat's longest gap spans two or three
frames. In each of those frames the app's own work, the trace's script time
less its waits on the GPU process, was 11 to 15 ms, the keep's frame 39 to
57 ms and the reading after it 55, the same in both builds. Why the first
swing frames cost twice a drag frame is not found.

So the app's part is now on the page and gated by itself. `let_go_ms` is
all of `GrabDrag.release`: the swing set going and the topple check, or the
pose kept at once. `kept_ms` is all of `_end_swing`: the swing's words,
the step kept, the model weighed as it stands, and what an edit sets going.
Each must stay under 100 ms, about when a person sees a click wait
(`grab_flow --keep=MS`). `ready_ms`, the joints read again once the model
has stood still a quarter second, must stay under that quarter second
(`--read=MS`). The crane's, in a browser drawing in software at load 11 to
21: let go in 0.2 to 0.3 ms, kept in 15 ms (the flywheel's coast in 66),
read again in 51 to 82 ms. A build whose keep was made 300 ms slower failed
it (kept in 315 and 367 ms) while the hang gate passed it at 1.7 s. The hang
gate stays, but it fails m78 as readily as m79 once the browser has three
cores or fewer; the new gate says whether the app is to blame. The runs and
their traces are in `bench/results/letgo-2026-10-18/`.

**The handles a browser test takes hold of.** The grab tool told a browser
page where each joint's part was on the screen (for grab_flow to press on)
twice a second, raycasting every part of each body, for every model in every
browser. On a 4,000-part model that held frames 180 to 460 ms (sharesteps,
2026-10-17). It now finds them only when the page asks
(`window.brickworksGrabAsk`), again only when the model, the view or the
window has changed, and from the four parts of a body furthest from its
joint. On 42082-1 (2,184 parts) in a browser drawing in software, once its
parts were in, the page not asking: before, 20 frames in 20 s, each 1.18 to
1.28 s, and the page never went quiet in three minutes of waiting; after,
1,201 frames, none longer than 17 ms. Asked, they are found once, in 973 ms
on that model, and not again while nothing changes (`grab_flow --big=…
--only-big`).

**Left for later.** Spinning and coasting (S2's next; done in §16): a wheel or a gear train
spun by a drag and let go, coasting down against its bearings' friction,
needs the train's inertia reflected through its ratios and a fling's speed
read from the pointer (a release now starts from rest). A joint swinging
while the model falls. A big section's swing (over 40 parts its room tests
cost more than a frame; it settles as before). Loops, balls and click hinges
swinging. Friction in a free pin measured on the bench (§ What "accurate"
can honestly mean), and how much a section bounces. A frame of the model
drawn in software (above): every motion drawn frame by frame, a swing, a
turning view or a drag moved without pausing, draws one to two frames a
second on this box; what in SwiftShader's 2.5 to 3.5 CPU-seconds a frame is
worth cutting (the 4096² shadow atlas, the multisampled blits, the
interface) is measured nowhere yet, and only on a box not shared with forty
other jobs would the measure mean much.

## 15. Big loops at frame rate, and universal joints (G6)

G4 left an actuator's arm in a loop of 25 to 36 joints dragging at 137 to
174 ms a frame, one frame of 42081-1's held 1.9 to 3.1 s, and the arm let go
checked and kept in 22 s. A person feels that: the arm follows the pointer
in steps. G6 measured where each frame's time went and took out what was
spent, and then let a universal joint pass a turn on.

**Where the time went.** Each part of a drag frame timed apart, on the code
before (`grab_probe -- --only=actuators`, windowed, a box loaded 35 to 45):

- 42081-1's arm, 262 parts in a loop of 25 joints: solving the loop was 1 to
  3 ms a frame. The room test was the rest, 10 to 60 ms a frame, and 2.8 s
  each time it came to the arm's Technic panel 15265 at a new turn. A turned
  part's cover is worked out cell by cell (`BrickLattice.cells_for_turned`,
  then `compress`) and kept for that part at that turn; in a loop every body
  turns its own way and to a new turn every frame, so none was ever found
  kept. 37 covers were worked out in 73 frames, 18.1 s of the drag's 19.3.
  Let go, the check bisected where it stopped the same way: 15 s of covers.
- 42024-1's small actuator, 82 parts in a loop of 36 joints: the room test
  was 0.4 s over the whole drag, and solving the loop 8.2 s of its 8.6:
  6,096 rounds of Levenberg-Marquardt for 547 closes. Its loop holds the
  actuator's screw, and the screw's input turns 2.08 radians for each LDU
  the rod goes, and through a universal joint (62520 and 62519) an axle that
  turns 1.9. Each 4 LDU step of the rod began 8 radians from where those last
  closed, more than a turn to cover by derivatives worked out at the start;
  one close in five took all 24 rounds and did not close, and was then
  bisected as a stop. 7 of the 49 frames stopped short with nothing in the
  way and went on the next frame.

**What changed.**

- A turned part whose cover is not kept is asked where something is,
  rather than worked out whole (`BrickLattice.TurnedCover`). Whether one of
  its cover's boxes, turned, touches a box of a part near it is the
  separating axis test of the two boxes: a cell touches a turned box exactly
  when that test says so of the cell, and a lattice box is its cells. Within
  0.01 of a cell of touching, the cells there are asked line by line as
  `cells_for_turned` asks them, so a cell that only just touches is decided
  the way it always was. `turned_probe` holds it to the whole cover over 1,800
  random parts and boxes, beside them, into them and laid against their faces:
  the same answer every time, 37 to 45 times quicker. Asked on real sets with
  `grab_probe -- --check-covers`, every turned part's test also works out its
  whole cover and the two are compared: 71 of 71 the same on 42081-1 and
  42024-1.
- A section bigger than 40 parts is tested within a frame's share and its
  stop found on pauses (§10). A slide drawn on past a stop it met is not
  tested again, as a turn's is not. And a stop met and not yet found is let go
  once the section stands where its whole test finds room: it was found at
  the release instead, and 42081-1's arm let go 20 LDU out was kept 60 LDU in,
  at the stop it had met at the start of the drag; 42024-1's, let go 4 LDU
  out, 48 in. A test cut short for one pose is not carried on for the next.
- The loop is solved in steps sized by how fast its joints turn: each step
  starts where the last one's slope says, as many steps as keep the
  fastest turning joint within 0.5 radians, the steps on the way closed to
  0.5 LDU and only the last to the 0.05 every close is held to. A part of the
  loops that spins on its own, joints whose constraints no other joint moves
  (the screw's input, the universal joint and the axle it turns: 4 joints, 19
  rows), is solved after the rest with the rest held, in its own steps: the
  rest in one or two, the part in sixteen to thirty, each small (`Linkage._reach_parted`;
  where either does not close, the whole is solved together as before). The
  normal equations are made from each row's few columns that are not nought,
  and solved by Cholesky's factoring. A frame asked the loop twice for the
  same pose (how far it goes, then the parts there) and solved it twice; the
  second is answered from the first. The derivative of a closing joint that
  slides now has its line's turning in it.
- Before testing a turned part's box against each box of a neighbour's
  cover by the fifteen lines, their boxes square to the grid are compared:
  apart along one of the grid's three lines, which are three of the fifteen,
  they are apart.

The drag's own work a frame (`GrabDrag.last_motion_ms`: following the
pointer, the room test, the loop, drawing, weighing), and the release:

| set | loop | before: mean, worst | after: mean, 95%, worst | let go, checked and kept |
|---|---|---|---|---|
| 42081-1 | the digging arm, 262 parts, 25 joints | 252.7 ms, 2,936 ms | 10.4 to 11.1, 14.7 to 18.2, 15.2 to 19.7 ms | 19.0 s, now 3.8 to 6.1 s |
| 42024-1 | the small actuator's arm, 82 parts, 36 joints | 148.3 ms, 346 ms | 9.0 to 10.7, 17.4 to 22.7, 25.5 to 35.9 ms | 3.0 s, now 0.4 to 0.5 s |

The after figures are three runs of the code as committed, on a box loaded 40
to 50 (two of the actuators alone, one in the whole run); before is one run of
the code before, at the same load.

Every frame's pose was written out before and after and set side by side.
On 42081-1 every part of every one of the 73 frames stands within 0.07 LDU
of where it stood before (each joint closes to 0.05 LDU, and a part far out
on the arm moves more for it); the arm against the law of cosines went from
0.0021° to 0.0073°. On 42024-1, within 0.03 LDU in every frame where both
followed the pointer; the frames that stopped short with nothing in the way
now follow it, and the arm stands where the law of cosines puts it to
0.0166° (0.0002° before; the part solved apart lets the rest settle on a
slightly different least-squares pose, inside the same 0.05 LDU). The other
loops of the run (8020-1's four-bar, 8218-1's engine, the five racks, the
three worms, the scissor lift) pass as before, with 269 checks in all. The
probe checks the mean and the 95th percentile under 33 ms, the release under
10 s and the rod kept where it was let go; each fails with its fix taken out.

**A universal joint passes a turn on.** `Bodies` already read a universal
joint as what it is, a cross pinned into two ends: on 8062-1's crane each
3326a sits in two 3712s by two hinges, one along y and one along z, their
lines crossing on the shafts' line. The gear reading did not read hinges, so
the shaft past the joint was a train of its own. Turning the winch's crank
turned the near shaft through the worm and its gears; what hung on it went
round with it rigidly, the cross with it, and the cross met the far end at
once (§13). Now `Bodies.universals` finds each cross (a body of a part or
two joined to two others by a turning joint each, the two lines square and
crossing within 1.5 LDU), and `Mechanism.join_universals` takes it as a
coupling between the shafts its ends are keyed to, when each shaft turns
about a line through the crossing square to the line it is pinned on: the
two shafts turn alike about their lines, the way the turn goes through. A
shaft held by nothing but the crosses at its two ends (8062-1's axles 6 and
8, joined by a connector, between its two joints) floats in the gear reading; it is given the line
between the two crossings, in what the near shaft turns in. The cross is
drawn from both ends, each of its lines turning with the end it is pinned
in (`Grab._pose_crosses`). One for one is exact for shafts in line, as
8062-1's are; for shafts at an angle it is the mean of Cardano's ratio, which
runs the far shaft ahead and behind within each half turn, and the cross is
drawn square between its two lines.

The crank turned two turns by the pointer, 72 frames (`grab_probe --
--only=worms`, 8062-1_Crane now in the run): its 8 tooth gear turns 90° to
0.0000°, and at each universal joint the shaft before it and the one past it
turned 90.0° and 90.0°, at most 0.0000° apart in any frame. Pictures of the
driveline drawn alone, before and after, show both ends and the cross a
quarter turn round. Without the joining the crank does not move at all, the
cross meeting its far end in the first frame.

**Left for later.** The arm laid in the lattice at the release still works
the panel's whole cover out, 3.5 to 4.5 s of the 3.8 to 5.8 on a worker
while the window draws (a cover worked out by runs along each line of cells
rather than cell by cell was only 1.3 times quicker, and cut into more boxes,
so it was left). A loop's worst frame is near 33 ms on a loaded box (42024-1's
25.5 to 35.9 over three runs, at the end of its rod's stroke, where the rest of
the loop is bisected; the 95th percentile stays under 23); a person's drag of
more than 4 LDU a frame takes more steps. A universal joint at an angle turns its far shaft by
Cardano's ratio, not its mean, and none in the probe's sets stands at one
(§16 does it, on a made one).

42080-1's pneumatic cylinders still do not move; taken apart, three things
hold them, and a trial of the first two is kept beside the results
(`bench/results/grab6-2026-10-17/cylinders-trial.patch`):

- `Bodies` joins a pin keyed to nothing to the first part it is in, and
  asks which pins are alone as it joins them. Joining changes a piece's
  root, the root is then not among the sizes counted before, and a pin in
  that piece is taken for one alone: the axle pin at the rod's eye, keyed
  into the arm, joined the rod to the arm, and the cylinder and the arm's
  two lines then made the rod and the cylinder one body of 458 parts. Read
  before joining, each cylinder is read as sliding (250 bodies and 59 loops,
  from 232 and 40).
- The cylinders' tubes are rigid pieces joined to their ports and valves,
  and held at both ends they lock the loop ("closes neither a degree one way
  nor the other"). Read as bending (closing no loop, carrying nothing on,
  tested for room by nothing), the rod is drawn out to the end of its stroke
  and in 12 LDU, the arm against the law of cosines to 0.0031°, 9.5 ms a frame.
- But a 24 tooth gear and a part beside it on the arm's head stay where they
  stood as the arm rises: they hang from the frame through the saw's
  drivetrain, not from the arm. A section this big is tested within 10 ms a
  frame, so the drag shows the arm through them, and let go, the release's
  whole test finds them and puts the arm back near where it began. Until the
  drivetrain on the arm goes with the arm, the trial is left out. (§16: they
  hung from nothing; the joints joined them to nothing at all.)

## 16. Pneumatic cylinders, a flick that coasts, and a universal joint at an angle (G7)

G6 left 42080-1's pneumatic cylinders still: taken apart, three things held
them (§15), and a trial of the first two moved the rod but left a gear on
the arm in the air. G7 finds the third and moves them, and then lets a part
let go while it turns carry on turning (S2's next, §14).

**What held the cylinders.** The first two are the trial's, kept: which
pins are keyed to nothing is read before any is joined, and a hose, a tube
or a chain (`Flex.strung`, every part of its body) bends: it closes no loop,
carries nothing on from where it hangs, and is tested for room by nothing
(`Bodies.flexible`). The third was not the saw's drivetrain. The parts left
standing were joined to nothing at all, each a piece of the model of its
own, anchored where it stood (found by listing each part that stayed while
a part it was lodged in moved, and the connectors round it):

- an axle 3 and an axle 5 in pins with stop bushes (32054): the bush's axle
  hole is on the pin's own line, and Mechanism takes a hole on a part's own
  shaft line for the notch an older catalogue read as a hole
  (`Mechanism._holes_of`), so no axle is ever read in it;
- an axle joiner 3L (26287), whose connectors name an axle hole in its
  middle and a bore too narrow for an axle, so the axles in its ends are not
  read in it;
- the saw's drive gear, a 20 tooth double bevel the file carries as a part
  of its own ("42080 - 18575", unofficial when it was drawn), whose
  connectors are read off its drawing without its axle hole;
- the log the gripper holds up, a piece of 15 parts standing on nothing.

A part no joint names cannot float in a real model: what it is pushed into
holds it. `Bodies._lodge`: a piece of the model that nothing holds where it
is (no part of it on the baseplate's studs, none locked), not the biggest
piece and of no more than 300 parts, whose part shares lattice cells with a
part of another piece, is joined to the part whose box its own is most into
(counting their shared cells instead cost 42081-1's reading 5 s). On
42080-1 41 pieces are held so; the gear turns with its axle, the log goes up
with the gripper. Not a piece with a hose, a string or a chain in it, nor into
one (`Bodies.bends`): it hangs on what bends. The first run of the whole
probe found 42042-1's hook block, on its winch's rope, joined to the drum the
rope's end was lodged in: it went round with the drum, met the model at
once, and the winch's worm would not turn. Not the connectors themselves:
the stop bush's hole and the joiner's ends are the catalogue's to name
(tools/ldraw/connectivity.py and a mesh rebuild), and `_holes_of`'s rule
guards against the old notch.

Measured with the pointer (`grab_probe -- --only=actuators`, windowed), the
rod drawn 4 LDU a frame past both ends and back. Its rod is pinned to the
cab, so the cylinder hangs from the rod in the tree and a drag on the rod
draws the cylinder along it, the arm with it:

| | 42080-1's crane, two cylinders in a loop of 11 joints |
|---|---|
| what moves | 606 parts: the arm, its saw, the gripper and the log (587 in the trial, the gear and the log left standing) |
| travel | out to the end of its stroke, 49.56 LDU, and in to −68.00, 2.44 short of its other end, where the foot of the log in the gripper meets the baseplate |
| the arm against the law of cosines | 85 poses, worst 0.0024° to 0.0036° over three runs |
| left behind | none: no part that stays is lodged in one that moved while in a piece of its own (9 with `_lodge` taken out: the axles, the joiner, the gear and the log) |
| the drag's own work a frame | mean 9.5 to 12.7 ms, 95% 13.5 to 19.8, worst 15.0 to 22.0 |
| let go | checked and kept in 1.5 to 2.8 s, where it was let go (with `_lodge` out the log met the gripper and it was kept 0.6 LDU off) |
| what it raises, taken hold of | the arm turned 4.00° on its pin draws the rod 9.98 LDU along its cylinder, the triangle turning 4.00° for that by hand |

A cylinder has no screw: what its rod raises, taken hold of and turned,
draws the rod along its cylinder, the loop with it. With its valve shut the
air would hold it, springing a little; which way a valve stands is not
read, and a cylinder moves as one open to the air does.

**Left for later.** A hose is not laid again as what it joins moves: one
between the cab and the arm stays where it lay, its end parting from the
fitting on the arm. The stop bush's and the joiner's axle holes named in
the catalogue. The valve's position.

**Flick to spin, and coast.** A grab notes the turn at each of the
pointer's moves, with the clock (`Grab._note_turn`). Let go, its speed is
the slope of the turn against the clock over the last moves, by least
squares (`Grab.fling_rate`): those within a tenth of a second, or the last
three where they come further apart (a browser drawing in software moves it
a few times a second), back to where it paused (a gap over 40 ms in which it
went slower than 11° a second). The first rule cut the moves at any gap one
and a half times another's, and on a loaded box, frames 10 to 50 ms apart,
it read a 1,080° a second flick as 619 and 639. Still for 60 ms, or for twice
its last gap, before the button came up, it is let go from rest; slower
than 11° a second the hand only drifted; faster than ten turns a second is
taken as ten, a frame held up making one move look like a flick. It is the
turn as the parts went, not as the pointer asked: a stop the model met is
not a fling.

The swing (§14) then starts at that speed (`Swing.fling`) and coasts:
gravity, its bearing's friction, the room test, at rest as before. A gear
train the grabbed joint drives turns with it (`Swing.add_geared`): each body
of the gear reading the grab drives is a segment turning about its own line
at the train's ratio, so the equations count its inertia times the ratio
squared and its bearing's friction, μ r m g, times the ratio, which is what
a train's inertia and losses reflected to its driver are. A gear on a
carrier the train turns is read about the line it turns about as it is let
go. A train coasts when the grabbed joint and every bearing of the train
turn freely; one gear pinned on with a friction pin holds it all
(`Grab._train_holds`). A section of more than 40 parts settles as before.

What it is made of, besides §14's mass, inertia and μ:

| quantity | taken as | how sure |
|---|---|---|
| the speed let go at | the pointer's, as above | as the pointer's moves are timed: a frame's time (17 ms) |
| a gear's bearing | its own axle's, μ r m g with r a pin's 2.4 mm and m the grams it turns with | the push of the teeth on its axle adds to it and is not counted, nor the teeth's own sliding (a few per cent a mesh for spur gears), so a real train coasts somewhat less far |
| a turntable's bearing | its top on its base, a flat disc under even pressure, at two thirds of its round's radius | a ring at the rim would be half as much again: its coast is good to about that |
| the air | not counted | a gear 40 at three turns a second, taken as a disc, loses to the air about half a per cent of what its bearing takes; its teeth stir more, still a few per cent |
| mass and inertia | §14's: Stability's grams, spread through each part's box | read as a brick's walls and top, a gear's grams are not checked against a weighing. A gear alone coasts as far whatever it weighs (its friction and its inertia both go as its mass); a train's share of each gear goes as their masses' ratio |
| μ | 0.3 (0.2 to 0.4) | a coast's turns and time go as 1/μ: good to about a factor of 1.5 either way |

Measured with the pointer (`grab_probe -- --only=coast`, windowed): a made
gear 40 (3649) on an axle 4 in a Technic brick 1 x 6, taken by its rim and
turned at 1,080° a second by the clock for 0.3 s, let go turning; then the
same with a gear 8 on a second axle that it turns five times as fast. By
hand from the parts (each part's mass spread through its box, about its own
axle), the ratio from the teeth (40/8): the train's inertia I = I₄₀ + 25 I₈,
its friction μ r g (m₄₀ + 5 m₈), α = friction / I; from ω it coasts ω²/2α
radians in ω/α seconds.

| | flywheel | 40 driving 8 |
|---|---|---|
| let go at, against the pointer's 1,080° a second | 1,082° and 1,069° in two runs | 1,072° and 1,087° |
| inertia about the 40's axle; friction | 12,371 g·LDU²; 324,323 g·LDU²/s² | 14,077; 569,278 |
| coasted, by hand | 1.080 turns, 1.082 | 0.688 turns, 0.689 |
| for, by hand | 0.719 s, 0.720 | 0.462 s, 0.463 |
| the 8 at rest against five times the 40's turn | | to 0.0000° |
| move_part spin=720, by hand | 0.478 turns, 0.479 | 0.310 turns, 0.311 |
| its own work a coasting frame, mean and worst | 0.29 ms, 1.91 | 0.39 ms, 3.02 |

Through its teeth the 8 brings 1.76 times the 40's friction and 14% more
inertia: the train coasts two thirds as far as the gear alone. The hand
form is worked from the same masses and boxes as the app's, so it checks
the integration and the reflection through the ratio, not the masses.
With the pointer's speed taken out (let go from rest) the gear does not
coast and three checks fail; with the 8 left out of the motion, move_part's
coast is 0.478 turns against the train's 0.311 and fails. 4096's hinge
flicked the same way stays where it was let go, and move_part spin= says it
does not coast.

**In the app.** The status bar says it while it coasts, "coasting at 1.8
turns a second, 2.3 turns so far", ten times a second; let go, "let go
turning at 3.0 turns a second, it coasted 1.1 turns in 0.81 s against its
bearing's friction, and came to rest at 512° (1.4 turns round from where it
was taken hold of)". A click catches it, Escape puts it back, and the drag and
the coast are one undo step, as a swing's. Over MCP, `move_part spin=`
(degrees a second, after degrees= if given) lets it go turning and says how
it spun and where it came to rest. In a browser (grab_flow, the local web
export drawn by SwiftShader), a gear 40 lying flat on a free axle, turned
round its axle's point on the page at half a turn a second by the clock and
let go, coasted and said so, its own work in a coasting frame 1.2 to 4.4 ms
on average and 1.8 to 8.6 at worst over three runs; the page drew one to
three frames a second there, so the pointer was read that often and the
speed let go at was read as 50°, −38° and 207° a second against 180 (a turn
of more than half a circle between two reads is taken the short way round;
the first two runs also circled the axle's end, below the gear). Said, not gated, as
§14 says of that page's rate; on a page drawn at frame rate the probe's
reading holds. The handles the page asks for now say where their joint's
line is on the page (`pivot_x`, `pivot_y`), for a test to drag round it.

**Left for later.** A slide flicked along its line does not coast, nor a
ball, a loop or a click hinge. A section of more than 40 parts. A joint
that swings while the model falls (§14). μ and a gear mesh's losses
measured on the bench. In a browser drawing in software the pointer is read
a few times a second, and a pointer held still for less than two of those
before letting go reads as a flick.

**A universal joint at an angle.** The gear reading turns the shaft past a
universal joint one for one (§15), exact for shafts in line and, for shafts
at an angle β, the mean of what they do: the far end's pin stays square to
the near end's pin and to the far shaft, so the far shaft runs ahead of the
near one and behind it within each half turn, tan ψ2 = tan ψ1 cos β, ψ1 the
near pin's turn from square to the plane of the two shafts and ψ2 the far
pin's from that plane (Cardano's relation). Each frame a grab now turns the
far shaft where its pin then lies (`Grab._cardan`, `Grab.cardan_turn`, worked
from the pins' lines, so no reference is assumed), and every gear it drives
by its ratio to it, about its own axle. Where the far side is more than
shafts and gears on axles that stand (a gear on a carrier the train turns),
or reaches back to the near side, the mean is kept; so do two joints at an
angle one after the other (a cardan shaft's two ends, whose unevenness
cancels when they are phased), not worked out. How far round a real joint goes before its forks meet
its cross is the room test's to say, as for any part.

None of the probe's sets has a joint at an angle in a gear train, so the
probe makes one (`grab_probe -- --only=cardan`): 8062-1's winch joint (two
3712 ends and a 3326a cross), a crank driving its near shaft through two
gears 8, and the far shaft with a gear 8 on it in a Technic brick on a tower
of its own, the far half turned 30° about the near end's pin, both towers
locked. The crank turned two turns in 20° steps: in 36 poses the far shaft
stood where Cardano's relation puts it, worked by hand from where the
joint's parts stand, to 0.0001°; the mean, one for one, is off it by up to
4.095° (sampled every 20°; the most the relation allows at 30° is
arctan((1 − cos β) / (2 √cos β)) = 4.12°), and with `_cardan` taken out the
check fails by that. Reading the made joint found a shaft of two parts (the
far end on its axle, turning in a hole on a line through the crossing) read
as a second cross; a cross is now one pinned into both its ends, by hinges
or pins (`Bodies.universals`).

**The whole probe** (`grab_probe`, windowed) passes 320 checks, 279 before
G7. Its four-bar's drawing share of a frame (§13) failed twice with other
runs beside it on the box (8.2 and 8.3 ms, the idle frame itself 20 ms) and
passed with none (−0.3 ms): the box's load, as §13 says. The reading of the
model's bodies on 42081-1 is 7.0 s against 6.6 s without lodging, on a
worker, on a loaded box.

## 17. Steering that turns both ways, and what holds a part that will not (G8)

A real Claude session building a small Technic kart over MCP, the way the
owner builds (bench/results/mcpwalk-2026-10-17), met three things worst
first: its steering turned once and the turn back swung the chassis; made a
sub-assembly, its front axle locked the steering's gears; and a bush on the
deck locked the steering column, with an answer no one could act on, "held
rigidly to what stays (26 bodies, 30 joints ...): nothing it is built on
turns". G8 takes each to its cause.

**A tyre on the baseplate's studs.** What stays when a part is moved is a
locked part's body, else what stands on the baseplate's studs (a stud in one
of its sockets), else the heaviest body (§10). A tyre was meant to be no
socket's, but 58090's part file leaves four gaps in its tread that read as
sockets. The kart (its column turning a centre-pivot front axle through
three 16 tooth gears) turned 30 degrees, a front tyre's gap came over a
baseplate stud, the front axle became what stays, and the turn back swung
the chassis round it. The sub-assembly was the same tyre: the session took
the axle's eight parts off and put them back in a section of their own, the
tyres laid a hair differently, and the next turn found the front axle
standing on a stud, the pivot's gear held with it, and the column's train
locked against it ("its gears lock (parallel 16-16, parallel 16-16)"). A
sub-assembly is only a grouping in the file: grouped as one with Make
sub-assembly, the same eight parts steer as before. A tyre now stands on no
stud, whatever its file says (`Bodies._read`). The fix tried and reverted in
the walk-through kept tyres off the floor in a second place too, and asked
a turned part for two studs to stand: that cut the half pin's stud in
42081-1's turned arm, and is not needed.

**Studs pressed on a face.** A stud holds where it goes into something: a
socket underneath, or a hole. The kart had a bush (3713) on its column and
half bushes on the idler and the pivot, sitting on the deck's studs; the
lattice found the studs' tips in the bushes' cells, two studs or more joined
them, and the bush, gripping its axle, joined the column to the chassis. A
part with no socket (a bush, a gear, a beam) now takes a stud only in one of
its holes (`Bodies._no_sockets`, `_takes_stud`); studs that only press on
its face join nothing, between any two parts and where a part rests on a
joint's half. On 42042-1 two pairs are read so (a 1 x 3 plate's studs
against a long pin's stop bush) and its winch turns as before; if a stud
there goes into the pin's hollow end, which a stud does, a pin's end is not
yet read as a hole.

**What holds it, in words.** Bodies now keeps why each two parts became one
body (`joined_by`: an axle gripped in an axle hole, studs, a tyre on its
rim, glue, a lodged piece, a lone pin, two joints on different lines) and
each joint it read between two parts that ended in one body (`overruled`).
A part that will not move is told by the joint nearest it that its body
holds still and each join that holds the two halves as one, part by part,
each named with its number (`Bodies.held_words`): "the Technic Axle 4 (#15)
would turn on its axle in the Technic Plate 2 x 8 with Holes (#11), but the
Brick 2 x 2 Round (#25) grips the Technic Axle 4 (#15) and the studs of the
Technic Plate 2 x 8 with Holes (#11) grip the Brick 2 x 2 Round (#25)". With
no such joint, why its body is what stays: it is locked, it stands on the
baseplate's studs, or it is the heaviest. move_part answers so; the status
bar says it as the part is carried instead (a press on a part held rigidly
picks it up, as before); and a train whose gears lock names what it is held
between ("It is held between what stays: the Technic Plate 2 x 8 with Holes
(#11) is locked and the Tyre 14/ 50 x 17 VR (#23) is locked"). Locking or
unlocking a part changes no revision, so the joints read ahead were kept:
after unlocking, the kart's steering stayed locked. They are read again
when the locked parts differ from those they were read with
(`GrabDrag.is_ready`).

**Measured** (`grab_probe -- --only=kart`, windowed): each kart turned +30,
−60 and +30 by move_part, the front axle against the column (column, idler
and pivot gear are all 16s, so one for one, the same way round), the deck
where it was built.

| kart | +30 | −30 | back | chassis |
|---|---|---|---|---|
| as built (`steering_kart.json`) | 29.7° | −29.5° | 0.4° | still |
| its front axle put back as a section, as the session did | 30.0° | −30.0° | 0.0° | still |
| its front axle a sub-assembly (Make sub-assembly) | 29.7° | −29.5° | 0.4° | still |
| with its bushes (`steering_kart_bushes.json`, as the session first built it) | 29.7° | −29.5° | 0.4° | still |

The front axle falls 0.3° short of the column one way and 0.5° the other,
and comes back 0.4° past where it was built; why was not found (the
section's re-laid parts follow exactly), and it is within the check's
degree. Each check fails with its fix taken out: with
tyres standing on studs, the kart's turn back moves the chassis and the
section's turn locks its gears, word for word as the session was told;
with studs pressed on a face holding, the bushed kart "will not move"; with
the locked parts not compared, the unlocked steering stays locked.

**Every steering in the probe's sets, both ways and back** (`grab_probe --
--only=steering`, in the full run): 8020-1's Jeep, 8841-1, 8808-1, 8054-1,
8828-1 and 8062-1, each turned over MCP at its steering wheel where turning
it reaches the rack (8808-1), else its pinion's column, +30, −60 and +30
from where it stands. Each turn moved; the rack went 5.34 LDU one way and
5.34 to 5.35 the other side of where it stood (by hand 5.33: 30 degrees of
an 8 tooth pinion is two thirds of a tooth, 8 LDU a tooth); the last put
every part back within 0.001 to 0.015 LDU; what stays never moved.
`--steer-set=FILE` asks it of another set.

Eight more of the OMR's 64 sets with a steering rack, asked so
(`steering_extra.log`), do not pass, and none for the reasons above.
8815-1's racer, 8832-1 and 8272-1 have no pinion read in a rack (their
racks are parts the gear table does not list); 8448-1's pinion and 42035-1's
turn without moving their racks (42035-1's rack is read as one body with the
connector it rides in, §12); 42029-1's column is held at both ends; 42037-1's
rack goes 0.29 LDU for 30 degrees, and the turn back leaves a part 23 LDU
from where it stood. 42039-1 is the kart's kind: turned +30 its rack goes
11.19 LDU, and read again its pinion is in no rack, so the turn back turns
the column alone. Its pinion stood 7.9 LDU across the rack's middle, within
the 7 + 1 the reading allows, and 8.6 once the rack had tipped 3.5 degrees
on its track rod. Allowed half a gear's face (4 LDU) the pinion is read in
its rack again, and the loop it closes then reads 58 joints where it read 75
and "has no freedom": read again after the turn, the tow ball pin 6628 in
its cross block (42003) is no longer a joint (226 bodies for 227) and an
axle joint the build did not read appears. Choosing a lone pin's part by
number rather than by the order the joints are read changed the whole
reading (235 bodies, the steering's loops too big to solve), so it is left.
That is the next unit's.

**The session again.** The walk-through's kart task was run again on this
build, the way mcpwalk ran it (`claude -p` with only the app's MCP, on the
subscription; `t1_kart` in bench/results/grab8-2026-10-18). The session
built its own kart (no floor, an 8 tooth gear on the column driving a 24 on
a pivoting front axle) and turned it +60, −120 and +60: each turn drove the
front axle, and it reported both directions working. Asked then to put a
round brick 2 x 2 over the column and turn it both ways (`t1b_held`), it was
told "#32 will not move: the Technic Axle 4 (#31) would turn on its axle in
the Technic Plate 2 x 4 with Holes (#14), but the Brick 2 x 2 Round without
Reinforcement (#51) grips the Technic Axle 4 (#31) and the studs of the
Technic Plate 2 x 4 with Holes (#14) grip the Brick 2 x 2 Round without
Reinforcement (#51)", and swapped the brick for a round tile with a hole
under it. It then met one more: the
column turned +60 drove the front axle, and turned back drove nothing. The
model it was in is kept (`tests/fixtures/mcpwalk/steering_kart2.ldr`, from
the session's own app by undo) and is `grab_probe -- --only=kart2`.

**A gear's face on studs.** The gear reading (Mechanism) joins a part to the
studs it stands on where it records no socket for them (a turntable's base,
a beam's holes over a plate's studs). Turned 60 degrees, the round brick
on the session's column brought one of its studs under the 24 tooth gear on
the pivot beside it, at the gear's face: read as the gear standing on it, the
pivot was one body with the column, both were held to the chassis, and the
turn back turned the column alone. A gear now stands on a stud only where
the stud is on the line of one of its holes (`Mechanism._in_a_hole`). The
session's kart turned +60, −120 and +60: the 24 turns −20.0°, +20.0° and
back to 0.0°, a third of the wheel's turn the other way, by its teeth; with
the change taken out the second and third turns fail. A fresh session given
that saved car (`t1c_turn_back`) turned it +60, −120 and +60, each turn
driving the same 12 parts, and reported the front wheels steered each way
and back to straight.

**The whole probe** (`grab_probe`, windowed) passes 368 checks, 320 before
G8; mechanism_probe (54), mechanism_sets and simulate_probe pass as before.

**Tried and left.** What stays chosen through the wheels: a vehicle on its
wheels stays with what they turn in, rather than with its heaviest body. It
was tried for 42081-1, whose tyre the file carries as "42081 - 23798",
described only "23798", so it is not read as a tyre and its tread's gaps
stand on a baseplate stud: the loader is anchored on a wheel, by chance, as
the kart was. Named from the catalogue (Tyre 44/ 58 x 56 R Tractor), the
tyre stood on nothing, and the heaviest body was the arm's curved panel
(15265, 535 g weighed by its box), so the loader swung round the arm when
its rod was drawn. Anchored on what its wheels turn in, the arm moved
again, but 42042-1's crawler crane stood on its tracks' rollers, the gear
reading's ground went with them, and the winch's worm turned its gear no
longer; and 7191-1, on three legs, would have swung its whole hull about
the canopy's hinge. Both are left out: 42081-1's tyre still stands on its
stud, and the heaviest body by boxes is not yet a measure of what stays
that a curved panel cannot fool.

**Left for later.** A model file's parts described by a bare number named
from the catalogue, with what stays chosen so a panel's box does not decide
it (above). A pin's hollow end read as a hole a stud goes into. The eight
sets above, 42039-1 first, and the rest of the 64 with steering racks.
Two things the sessions stumbled on: move_part's "now −120°" is the turn of
that call, not where the part stands from where it was built, and one
session had to check with a picture; and look_at_model lists a wheel turned
and turned back by a few ten-millionths as standing a stud off (its axis at
z 9 for 10), which sent a session to look again.

## 18. Every real set's steering, swept (G9)

G8 turned the six steerings in grab_probe's sets both ways and back, and
tried eight more of the OMR's: all eight failed. G9 asks it of every set
the OMR has with a steering, and takes the failures to their causes, most
sets first.

**The sweep** (`tools/steer_sweep.py`, over `grab_probe -- --only=sweep`).
A set has a steering when its file has a steering arm (a part named
Steering Arm, Steering Wheel Bearing, Wheel Spindle Steering Arm or
Steering Wheel Hub), a steering rack (any Technic gear rack but the plain
1 x 4), or a 1 x 4 rack and a gear that may stand in it: 181 of the OMR's
1,576 files. Each is opened headless and its steering turned over MCP as a
session turns one: the steering wheel where turning it reaches the rack,
else the pinion's column, else a steering arm on its kingpin; +30, −60 and
+30 degrees from where it stands. It steers when each turn moves it, the
rack (or the far arm) goes one way and then the other, what stays never
moves, and the last turn puts every part back within 0.02 LDU. Twelve
files have only a 1 x 4 rack that no pinion stands in (a lift, a slide) and
are not counted. Four jobs under `heavy`, about 15 minutes on a loaded box;
a set that takes longer than the timeout is stopped and said so (none
did). The rows (what was turned, what each turn said, how far the rack
went, what stays and why, and for a pinion what its rack is one body with)
and the table are in bench/results/grab9-2026-10-18 (`sweep_before.md`,
`sweep_after.md`; `--shots` takes pictures from above, windowed).

| | sets that steer, of those with a steering |
|---|---|
| before (m78; `sweep_before`) | 25 of 168 |
| the biggest body stays, the tyre named (`sweep_anchor`) | 25 of 169 |
| and a block with pins on two lines not a pin (`sweep_fix1`) | 33 of 169 |
| and a heavier body standing on the floor stays (`sweep_after`) | 33 of 169 |

No set that steered stopped steering at any step. One set more is counted
once parts are named by their number: 42110-1 carries its steering arms as
parts of its own described only "23801"; named from the catalogue
(Technic Steering Wheel Bearing with 2 Pegholes and 2 Slotted Axlehole
Arms), they are found and turned, and the far arm does not follow.

The failures before, by cause, as the table groups them: the pinion turned
and its rack did not, the rack one body with what the pinion turns in (37);
the rack or the far arm did not move (30); not back where it stood (17);
the loop has no freedom (15); something in the way at once (15); a steering
arm hanging on a ball in a loop (8); loops too big to solve as it moves
(7); a rack the gear table does not list (7: 18940 and 18942); held
rigidly (4); held by a worm or a screw (2); what stays moved (1).

**A block with pins on two lines is not a pin.** The biggest group was the
rack held still with the pinion's bearing. What made them one, followed
join by join from the rack to the part the pinion turns in (`grab_probe --
--only=steerdebug --steer-set=FILE`), went again and again through the
lone pin rule: a pin keyed to nothing is part of the first thing it is in
(§10, Mechanism's rule). The cross block with four pins (48989) is named a
pin and keyed to nothing, so it was joined to whatever it was first read
in: on 42050-1 two of them, each pinned into the rack's hole and into the
two beams 7 the pinion's long pin goes through, made the rack, the beams
and the pinion's bearing one body. A part whose pins stand on more than one
line is not a pin: held on two lines it is held by that rule, and on one it
turns (`Bodies._pins_on_lines`). Eight sets steer that did not, none that
did stopped, and four more move where they did not: 42050-1, 8258-1,
8273-1 and its Utility Cargo Truck, 8289-1 and its Tow Truck, 9395-1 and
9397-1's Snowplow steer; 8274-1 (back to 0.022 LDU), 8285-1, 9393-1 and
42075-1 now move and fall short on the way back. grab_probe's steering run
has 42050-1 and 8273-1 in it; both fail without the change, as the sweep
before says (the pinion turned, its rack did not).

**What stays.** When a person grabs one part of a model, the rest stays
where it is. What stays is, in order (`Bodies._anchor_and_grow`):

1. a part the person locked, its body;
2. what stands on the baseplate's studs (a stud in one of its sockets;
   never a tyre);
3. the biggest body: the one with the most parts, between two of a size the
   heavier. This is how the gear reading takes its ground
   (`Mechanism._largest`), so the two agree;
4. unless a body standing on the floor is heavier than it: one that
   reaches down to within 2 LDU of where its piece is lowest, not by a
   tyre, which rolls. It holds the model where it stands by its weight. A
   crane of a few bricks stands on its tower, though its arm has more
   parts.

Not the heaviest outright, as it was: a part is weighed by its box
(`Stability.grams`), right for a brick and far out for a shell, whose box
is mostly air. 42081-1's bucket (15265, a curved shell) weighs 535 g by its
box, more than the loader's frame of 145 parts (205 g). Its tyre, which the
file carries as its own part described only "23798", now takes the name
the catalogue gives that number (Tyre 44/ 58 x 56 R Tractor;
`CustomParts.add`), so it is read as a tyre: it stands on no stud, and it
is held on its rim. Before, it stood on a baseplate stud by its tread's
gaps and anchored the loader by chance; named, with the heaviest body
anchoring, the bucket stayed and drawing the arm's rod swung the loader
round it (§17). Now the frame stays and the arm moves as before
(`grab_probe -- --only=actuators`, 38 checks). `-- --only=stays` checks the
tyre's name and that what stays is the biggest body, not the bucket's; with
the heaviest rule back it fails: what stays is then the bucket's body, of 9
parts. The floor is there for the made crane of the falling case (a tall
arm of seven parts on a tower of five 2 x 2 bricks, on no floor): by parts
alone the arm stayed and the tower swung, and the case's six checks
failed. Taking the biggest body that stands on the floor first, whatever
it weighs, failed three others in the full run: 42042-1's tower crane's
worm turned no gear, dragging the made scissor lift's foot moved its base
(the beam 15, 26 parts) instead, and the made gear 40 coasted at 1,326° a
second for the pointer's 1,080. So the floor wins only by weight.

**Tried and left.** Two things looked like the steering arms that hang on
a ball (10295-1, 42021-1, 42124-1, 4404-1, 9392-1, 8880-1's F1 racer):
growing the tree of joints along balls last, so an arm hangs on its kingpin
and its track rod's ball closes the loop; and reading two balls between
the same two bodies, their middles on one line, as a hinge on that line
(15460's kingpin is a ball above and a ball below). Neither moved any of
the seven, and both were taken out again.

**Left for later**, by the after table's groups, with sets to start from:
a rack on a plate's studs, held with the frame (8448-1's five models, 32185
on a 2 x 10 plate; 8081-1, 6574 on a 2 x 2; 854-1, 3743 on a stack of
plates); 1980s steering racks (2790a in its holder 2791a, eleven files of
8022, 8024, 8815, 8820 and 8832) and 42043-1's 18942 in its housing 18940,
which the gear table does not list and which slide in a housing of their
own; steering arms on balls (above); loops too big to solve (42024-1,
42029-1, 42070-1); and the 21 that turn and do not come back within 0.02
LDU. The other moving things (turntables, doors and ramps, booms) were not
swept.

**Proved** (bench/results/grab9-2026-10-18), on a box at load 30 to 50:
`grab_probe` windowed, twice: 371 of 373 checks and 374 of 376. The two
that failed each time were different and each is a timing check (a loader
arm let go at the end of its stroke kept 0.35 LDU short, the big model's
section read before its parts had loaded, the four-bar's drawing 7.7 ms
over its 4, the gear 40's start against the pointer's rate); each passes
run alone (`--only=actuators` 38, `--only=big` 5) or in the other full
run. mechanism_probe 54, mechanism_sets, simulate_probe 41, element_probe
and app_tools_probe pass; the MCP is in step with the app. Pictures of
42050-1, 8273-1 and 9395-1 from above, cut over the rack, before and
turned each way (`steer_*.png`). Not run: tools/web/grab_flow.mjs (the
local export was made, and the flow waited on the box past the time box).
8283-1 is the one set the sweep could not read to the end: turning it made
a copy of a shared sub-assembly its own, which gives its parts new
numbers, and the row is empty.
## 18. Hoses that follow what they join (G10)

G7 let a hose bend rather than hold what it joins (`Bodies.flexible`), and
left it where it was drawn: raise 42080-1's crane arm and the tubes from the
cab stayed put, their ends out of the fittings on the arm (§16). G10 lays
each such hose again as the section moves.

**The cases.** `grab_probe -- --flex-survey` over 22 sets with pneumatic
parts, hoses, strings or chains lists every flexible thing held at both ends
and the joints between the two bodies holding them
(`bench/results/grab10-2026-10-18/flex_survey.txt`). 96 hoses in 9 sets are
held at both ends; 51 of them have a joint between their ends, so a grab
moves one end and not the other. The other 45 run between parts that are
pieces of their own (a T-piece or a valve no joint holds), each with its own
anchor: a grab of either moves one end too.

| set | what bends | its two ends | what moves one end |
|---|---|---|---|
| 42080-1 | 15 pneumatic tubes LDCad laid (165 and 166, read as 71533k01 and k03) | the cab's valve u9417 and the hose connectors on the arm (LQ-11, LQ-12); the arm head's cylinder 2947b and its connectors (LQ-9, LQ-10); a connector and a cross block across the turret (LQ-1) | the arm on its pin (493 to 606 parts, raised by its two cylinders); the arm head on its turntable (132); the head's cylinder on its axle; the turret on its turntable (1,346) |
| 42043-1 | 14 pneumatic tubes | connectors on the arm and the 2 x 11 and 1 x 11 cylinders (19, 20, 22, 23); a pin and a cross block (1) | each cylinder on its axle or pin (3 or 4 parts) |
| 42053-1 | 15 pneumatic tubes | the valves 47223 and the cylinders 19466 (LQ-07 to 10); the valves and the grabber's cylinder (LQ-11 to 14) | the cylinders on their axles; the boom (266 parts); the grabber |
| 8110-1 | 9 pneumatic tubes | the valves on the crane arm and the curved cylinders 47224 (LQ-5 to 8) | the cylinders on their pins; the crane arm on its axle (501 parts) |
| 8868-1 | 13 pneumatic tubes | the gripper's flex-system hoses and its 1 x 5 cylinder | the gripper's hinges |
| 8851-1 | 8 pneumatic tubes | the T-pieces on hinges and a brick 1 x 16, a valve | the T-pieces on their hinges |
| 8854-1 | 6 pneumatic tubes | the valve, T-pieces and cylinders 2793, all pieces of their own | either piece |
| 42050-1 | 9 ribbed hoses LDCad laid (79 and 80, read as 71944k01 and k02) | pins and cross blocks on the engine and the frame | the engine's cone on its axle (23 parts) |
| 42029-1 | 2 ribbed hoses | pins on the pickup's panel and its frame | the panel (44 parts), in a loop of 44 joints too big to solve: the grab is refused |

Strings: no set surveyed has a string with end studs (71149) held at both
ends; 42042-1's winch rope and 42082-1's rope are skins LDCad drew, one mesh
each, which no layout here lays (CADTASK). Chains: every chain in the sets
(8838-1, 8835-1, 42035-1, 8844-1, 42050-1, 10124-1) is held by no joint, link
or sprocket, so no grab parts it, and none has its sprockets on two bodies a
grab moves apart. A chain already couples its sprockets in the gear reading
(`Mechanism._find_chains`, §2): turning one turns the others. Laying a chain
again as its sprockets move is left. LSynth hoses (8273-1, 8275-1) and
8049-1's tubes, whose middles are skins, are not Flex's kinds and are carried
whole as before.

**How it follows** (`src/assembly/flex_follow.gd`). At the press
(`Grab._chosen`) every flexible body whose one end is held by a part that
moves and the other by one that does not is read as an item: its kind
(`Flex.strung`, so LDCad's 165 is the tube's end), its two ends off its own
end pieces (`Flex.ends_of_item`), the part across the hose's joint nearest
each tip, how far each end runs straight in that part's connector (matched
as Reshape matches one, `FlexFollow._in_its_connector`: a pin hole's, to 2
LDU past its mouth; read off the pieces alone every end ran 2 LDU), its length along its pieces as they lie, end to end, and its bend
(`Flex.fit_bend`, as Reshape reads one, now from one to seven bend points).
The bends of every hose in the model are read ahead with the bodies, on the
worker (`GrabDrag._read_all`, `FlexFollow.fit_all`): read at a drag's first
frame, 42080-1's six tubes held it half a second. Each drawn frame of a
drag, a swing, a coast or a settle (`Grab.drawn`, wherever the window draws
a grab) each item is laid again by its kind's own layout (`Flex.lay_swept`)
between where its ends' holders put its tips, the way each leaves turned
with them, its bend points carried by both ends, each by as much as it is
near that end. One whose ends move alike is carried whole. Its pieces are
drawn slot for slot onto its own; kept (`Grab.commit`), it is moved piece by
piece where the layout lays as many, and otherwise laid afresh in its place,
its own end parts and colours kept (`FlexFollow.swap`), in the move's one
undo step.

Three things the reading found. LDCad puts a pneumatic tube's bulged end
(71533k01) on the other way round from the end Flex lays (71533k02): read as
Flex's, each end left its fitting backwards, into the valve, and the tube was
read back 15 to 21 LDU off where it lay. Which way an end points is now read
from the piece next to it (`Flex._faces_away`), and an own end the other way
round is laid turned half round (`FlexFollow._own_end`). LDCad lays a ribbed
hose's rings closer than their pitch (42050-1's 4.8 LDU apart, not 6.25):
its length by its rings was a quarter too long, so a hose's length is
measured along its pieces, its rings' count used only where the two agree.
And the layout's end tangents were never shorter than a fifth of the whole
gap between the ends, which with bend points near the ends overshot each
one: the least is now a fifth of the way to the next point the curve goes
through, which changes nothing for a hose without bend points or one that
fitted before.

**A hose has a length.** A pose that would put a hose's ends further apart
than it reaches is no pose (`Grab._test`, `FlexFollow.stretched`): how far it
must reach is its tips' straight runs and the line between them, and near
its length (within 15%) the shortest curve its layout lays there, which
cannot cut straight across ends that leave their holes side by side; a hose
drawn taut in a file may reach as far as it does where it stands. Not
through its bend points: they lie on the hose as it was read, and a curve
through them is as long as the hose already (42080-1's arm lowered by 4 LDU
of rod read a tube as pulled to its length). Where the curve through them
would come out longer than the hose, it straightens, laid between its ends
alone. A hose to a small piece no joint holds (Bodies reaches it from no
anchor: 42080-1's T-pieces, joined to the model by tubes alone) is laid to
it and holds nothing by its length (`FlexFollow._hangs`): the T-piece would
come with it, and stood where it was drawn, its tube held the arm 3° down.
The turn is
bisected back as a collision is, a swing or a coast stops dead there, and the
status bar says "stopped: the pneumatic tube from the Technic Brick 1 x 2 with
Hole (#7) holds it"; move_part, "it stopped where the pneumatic tube from …
holds it, pulled to its full length".

**Saved.** A hose LDCad laid keeps its path: when a sub-model of the file
was an LDCad path of parts and its end caps no longer stand where the file
had them, its `PATH_POINT`s are written along its pieces as they lie, a point
about every 20 LDU pointing along the hose (LDCad's point runs along its own
-y), its control points a third of the way to its neighbours, and its
`PATH_CAP`s on its end pieces (`src/parts/ldcad_path.gd`), in a file
written whole (a copy of a sub-model made its own, which posing 42080-1's arm
does), where the path lines were lost before, and in one written back over
its source, where they are replaced in place (no probe case writes that one
yet). A path untouched is left byte for byte.

**It stays fast.** A hose kept is laid by at most 100 points
(`FlexFollow.POINTS`; three quarters of an LDU apart on a short hose, as
Flex draws one, 7 on 42080-1's 700 LDU tubes), its length search started
from the last laying's (`Flex._rising_root`: two or three tries where
bisecting from nothing takes fifty, each length worked out without making
the curve, `Flex._curve_length`), and how tight it bends left out. Laid
every one every frame that way, 42080-1's six tubes cost its cylinder's drag
8 ms a frame on a quiet box and 77 on a loaded one (13 a tube), and its drag
frames 20.5 ms on average where G7's were 9.5 to 12.7: on the web build,
which has one thread, a stall every frame. So a drag's frame lays hoses for
2 ms at most (`FlexFollow.BUDGET_MS`), at least one, the longest waiting
first, each by 50 points (`DRAG_POINTS`); a hose not laid that frame is
carried from where it was last laid, each piece by its two ends' moves since,
blended by how far along it is (`FlexFollow._carry`), so its ends stay in
their fittings exactly and only its middle lags a frame or two. While the
pointer rests the window lays the rest, a budget a frame (`GrabDrag._process`).
Kept, every hose is laid in full as before (`Grab.commit`, `Grab.drawn(true)`
for the copies made their own), so what is kept, saved and undone is the
same. Of the ways to make it fit, this one keeps the layout the kept hose
has and the cost of a frame bounded whatever the number of hoses; laying
only those whose ends moved against each other was already so, and a
cheaper layout alone (fewer points) still grows with the hoses.

**Measured** (`grab_probe -- --only=hoses`, windowed, on a box at load 30 to
40; `bench/results/grab10-2026-10-18`):

| case | what moved | its ends against their fittings | its length | laid again, a frame |
|---|---|---|---|---|
| a tube the app laid from the floor to an arm on a hinge | the arm, 20° | 0.000 LDU | 179.92 of 179.97 | 1.0 to 1.2 ms |
| 42080-1, the cab's tube LQ-12 (709 LDU) | the arm lowered 6° on its pin, in its loop of 11 joints; 6 tubes bent | 0.000 | 708.93 of 709.10 | 8.0 ms for six (1.3 a tube) |
| 42043-1, the arm's tube 19 (493 LDU) | its cylinder −6° on its axle; 2 tubes | 0.000 | 492.80 of 492.92 | 2.7 ms for two |
| 42050-1, ribbed hose 1 (149 LDU) | the engine's cone 19.9° on its axle; 8 hoses | 0.007 | 147.86 of 149.03 | 9.0 ms for eight (1.1 a hose) |

Each kept is one undo step, and the undo puts every part back exactly; the
made tube and 42080-1's saved and opened again lie where they were kept, to
0.000 LDU. 42080-1 was written whole (the arm's copy of a sub-model made its
own), and the tube's sub-model has 37 `PATH_POINT`s, its first and last on
its caps to 0.000 LDU. A tube laid 3% longer than its straight runs
through the made model's two holes and the line between stops the arm at
7.8°, where it would have to reach 155.28 LDU and is 154.78; move_part says "it stopped where
the pneumatic tube from the Technic Brick 1 x 2 with Hole (#7) holds it,
pulled to its full length". That check failed at the first G10 head: with
every end read as running 2 LDU straight, the tube could bend 10 LDU sooner
in each hole than it does, so it reached 12 LDU further than its holes let
it, and the arm met the tower first; and the made model's floor brick stood
off the baseplate's stud grid, held by nothing, so the tube to it read as
hanging. Each end's run is now its connector's, and the brick stands on the
studs. Every hose's bend is read ahead in 0.08 s (42050-1) to 0.7 s
(42080-1, 42043-1) on the worker. Read back by the layout where they lay, the
tubes are 2.5 LDU (42050-1), 11.5 (42080-1, seven bend points) and 49 LDU
(42043-1, one) off where LDCad drew them: at the first frame of a drag a
hose moves into the layout's curve by that much.

In a browser (`tools/web/grab_flow.mjs` on a local web export, SwiftShader),
the made tube's arm dragged 16°: the page says one tube was laid again, at
most 7.7 ms a frame, and the drag frames' own work was 4.8 ms on average and
9.6 at worst over 19 frames, under the 33 ms gate. The app drew a frame
for 19 of the drag's 20 moves, 60 ms apart on the clock, so it kept up with
the pointer there; said, not gated. The flow's other cases passed but one:
the pendulum's swing, with no hose in it, kept the page waiting 36.6 s on the
loaded box (its gate is 5 s).

With FlexFollow taken out (once, by a switch since removed), the made case
fails at once: the arm's grab bends no tube (0 read), and every check after
it stands on that. And 42080-1's cylinder case, with it out, drew the rod in
to the end of its stroke (−70.44 LDU); with it in, before T-pieces held by
nothing were let hang, a tube from one held the arm at −4.00.

**Left for later.** 42043-1's tube 19 is read back by the layout only to
49 LDU: LDCad routed it tighter than a pneumatic tube bends, and the kink
penalty of the fit (as Reshape scores it) keeps one bend point, so the tube
jumps into the layout's curve at the first frame. A T-piece or a valve held
by nothing stays where it was drawn while its tubes are laid to it; carried
by its tubes, it would come along. A chain is not laid again as its
sprockets move apart (no set's chain has its sprockets on two bodies a grab
parts). Skins (a rope, a band) and LSynth hoses are not Flex's kinds and are
carried whole. A grab by its chain of joints (`GrabChain`) and Pose's
sliders bend no hose. A hose hanging from what moves still reads its far end
as a loop (`Bodies.loops_out`), so a hinge with a tube on it says "in a loop
of 1 joints, closed by 0", as it has since G7. In a browser a tube's own
piece is offered as a handle to take hold of ("71533k03 on its hinge").

**The whole probe** (`grab_probe`, windowed) ran 402 checks, 368 before G10:
400 passed. The two that failed were the actuators' "kept where it was let
go": 42024-1's, which has no hose, passed in both runs since; 42080-1's was
a tube from a T-piece held by nothing holding the arm (above), and with that
fixed the actuators' run passes all 38. The whole probe was not run again
after the last two fixes (the T-pieces, and a hose straightening where its
bend points would overstretch it); the hoses' and the actuators' runs were.
42080-1's cylinder drag now lays six tubes a frame: its own work a frame was
20.5 ms on average, 32.4 at the 95th per cent and 43.1 at worst on a box at
load 30 to 40 (G7 measured 9.5 to 12.7, 13.5 to 19.8 and 15 to 22), within
the case's gate on the mean and the 95th per cent. flex_probe, flex_ui_probe
(its reshape check reads `Flex.along_of` now), mechanism_probe and
simulate_probe (41) pass.

## 19. What steering still could not do, and the other moving things (G11)

G9 swept every OMR set with a steering and left 136 of 169 that did not
steer both ways and back. G11 takes the biggest groups left to their causes,
then sweeps the other things a real set moves: a turntable's top, a door or
a ramp, a boom or an arm on its hinge, pin or axle.

**The base.** The staged release (17bc0382: m78 with G9, G10 and the
whole-set placing fixes), swept again (`sweep_before`): 33 of 169, the same
33 sets as G9's after table. The tables are in
bench/results/grab11-2026-10-18.

**A round steering rack.** The 1980s steering rack (2790a) is a rod ringed
with teeth 8 LDU apart that runs through its holder (2791a), pushed by an 8
tooth gear standing beside it at whatever angle the holder is turned round
the rod. It was not in the gear table, so no pinion was read in it, and its
rod in the holder's bore was read as a hinge that turns and does not slide:
each of the eleven files that have it (8022, 8024, 8815, 8820, 8832) was
"locked: this loop has no freedom". Measured on the eleven, the gear stands
16 to 18.9 LDU from the rod's line (an 8's pitch radius is 10), at the rod's
middle. The table now has it as a round rack (`round`, its pitch line 8 from
the line); `Racks.find` reads a pinion in it on whatever side it stands,
square to the rod and to the way out to it. Held to its holder's line as
well, the loop closed to 0.007 LDU at 5 degrees, 0.028 at 10 and not at all
(0.064) at 20: as the arms at the rod's ends swing, their pins go a little
aside, and so does the rod, which the holder lets it (a rod 20 across in a
bore 22 across). The rod is now loose in its holder (`Bodies._rides_loose`):
its pinion and its arms hold it.

**A rack in a housing.** 18942 (a 1 x 14 rack with a beam under it) slides
in its housing (18940) on 42043-1's outriggers and 42078-1's tipper. It is in
the table now (32 teeth, pitch line 25: a 12 stands at 40 on 42043-1 and
42078-1's dump truck), with its housing: the rack's origin on the housing's
line where the table puts it is a slide along that line that does not turn
(`Bodies._rack_housings`, kind "housing"), and what else joins the two (an
axle through the housing's slot) does not hold them as one. 42078-1,
42079-1, 42061-1 and 42062-1 drive theirs with a worm, which is not read in
a rack, and no longer count as having a steering (164 sets, from 169).

**A steering rack's groove.** The 1 x 7 and 1 x 13 steering racks (87761,
64781) are channels open underneath, as their files draw them, and the half
pins standing up into them guide them as they slide (42069-1, 42076-1,
42083-1, 42111-1). The half pins' studs were read as gripping the rack, and
the rack was one with the frame. Studs standing up into a grooved rack from
below now ride in its groove: a slide along its line as far as they stay
under it (`Bodies._in_a_groove`, kind "groove"; the table's `groove`). Only
those two racks are marked: 3743 has sockets underneath and clicks onto
studs, and with every rack read so 8273-1, which steers on jumper plates,
stopped coming back.

**A rack its pinion holds, lying on a tile.** 6753-1's tow truck has its 1 x 4
rack under a Technic brick that lies on a tile 1 x 6; nothing joins the two,
so the brick was lodged in the tile (§16) and the rack was held with the
frame. A piece with a rack in it that a pinion of another piece stands in is
held by the pinion's teeth: it is not lodged where it rests, but slides
there along the rack's line (`Bodies._driven_rack`, kind "rests"). The tow
truck's rack now goes 10.67 LDU each way; read again after the two turns,
its piece shares no cell with the tile, is held by nothing and stays, and
the turn back turns nothing. Sliding it against what its pinion turns in
then did not bring it back either, and was taken out; it is left.

**A shaft on a loop's line.** An axle or a pin on a joint's own line turns
inside the holes it is in; a grab left such parts untested where nothing
but the joint moved, and tested them in a loop. 42111-1's steering column
turned in its loop met the joiner it turns in at once ("the Technic Axle 4
with Middle Cylindrical Stop meets the Technic Axle Joiner 3L"); 8862-1's
too. In a loop, a part all within 6.5 LDU of a turning joint's line that
the loop does not carry is not tested either (`Grab._thin_on`).

**A socket drawn as plain rounds.** A steering link's ends (2739a) are ball
sockets drawn from cylinders, not the socket primitive, so a towball in them
(6628) was in nothing: the track rods were not in the steering's loop, and
the rack slid without them. A bore a ball's size (8 LDU across the middle,
no longer than the ball) is now a socket at its middle (`Joints.balls`).

**A tyre on the floor.** 8063-1's and 42075-1's steering stopped where a front
tyre met the baseplate at the first degree. Rubber on the floor scrubs round
as its wheel is steered: the baseplate is not in a tyre's way
(`Grab._scrubs`); that it goes no lower is the floor's own test.

**What bends is not in the way.** A hose's piece was never tested; a cable or
a rubber band a file draws whole (a skin) was, and 8074-1's crane stopped
where its frame met its cable, 10252-1's arm where it met a rubber band. A
part that bends (`Bodies.bends`) is no longer in a move's way
(`Grab._bends_aside`).

**What touched as built.** A grab forgives for good what its moving side
touched where it began: the covers are 2 LDU cells and a part built flush
against another meets it at the first degree. Turned out and back in three
moves, the third began away from what the part was built against and met it
short of where it was built: 10220-1's door stopped at 18 degrees, 8855-1's
steering at 6. Pairs found touching before a grab moved either are now kept
from one grab to the next (`Grab._built_touching`), so moves in turn forgive
what one drag through the same angles forgives.

**What is in the way, named.** A move stopped by the model said "something is
in the way at once" or "it stopped where it meets the model". move_part and
the status bar now say which two parts met ("the Technic Axle Towball (#1095)
meets the Technic Steering Wheel Bearing ... (#1045)"), or which part would
go through the floor (`GrabDrag._met_words`). The sweep's tables give them.

**The sweep's own fixes.** A turn stopped short against the model says how
far it went; the sweep turned back by the 30 it asked, and 12 of G9's 21 "not
back" were that. It now turns back by the turn measured from where the part
stood (the calls say whole degrees). A shared sub-assembly's copy made its
own by a turn gave its parts new numbers and lost the sweep the parts it
watched (8283-1, 8855-1): the sweep makes every copy its own before it turns
anything. Each row says how far the steering arms turned (`arms_deg`).

**Steering, swept** (`tools/steer_sweep.py`, bench/results/grab11-2026-10-18:
`sweep_before`, `sweep_after3`; `sweep_after2` is the same without the last
four fixes and is 38 of 164).

| | sets that steer, of those with a steering |
|---|---|
| before (17bc0382) | 33 of 169 |
| all of G11, and a stud rule since taken out (`sweep_after3`) | 53 of 167 |
| as committed: `sweep_after3`'s 53 swept again (`sweep_final`) | 51 of 167 |

No set that steered stopped. The 18 that steer now: the eleven round-rack
files (8022-1's racecar, robot and tow truck, 8024-1's racer, 8815-1 and its
racer and road roller, 8820-1 and its racer and dune buggy, 8832-1), 42043-1
and its flatbed trailer (the housing), 42076-1 (the groove), 42075-1 (a tyre
on the floor), 8416-1, 8845-1 and 8862-1 (a shaft on the line, and the parts
met named). The two of `sweep_after3` that do not: 8074-1's grader, which
needed the stud rule (below), and 6753-1's tow truck (above). In every one that steers at a pinion and has steering arms, the
arms turn with the rack (34 of 34). 167 count as having a steering, from
169: 42061-1, 42062-1, 42078-1 and 42079-1 drive 18942 with a worm, which is
not read in a rack (no steering read, not counted), and 8836-1 took longer
than the sweep's 300 s twice (it failed before, "what stays moved"); 8283-1
is read to the end now, and 850-1's and 950-1's lifts have their pinion read
in their rack once the rack is no longer one body with it.

| what stopped it | before | after |
|---|---|---|
| the rack (or far arm) did not move | 33 | 34 |
| the pinion turned, its rack did not (one body with what it turns in) | 23 | 13 |
| not back where it stood | 21 | 21 |
| something is in the way at once | 15 | 18 |
| its loop has no freedom | 13 | 4 |
| held rigidly | 9 | 7 |
| its arm hangs on a ball in a loop | 7 | 8 |
| its rack is not in the gear table | 7 | 0 |
| its loops are too big to solve | 6 | 8 |
| what stays moved | 1 | 0 |
| held by a worm or a screw | 1 | 1 |

"Not back" is 21 again but not the same 21: twelve of G9's were the sweep
turning back by 30 after a turn stopped short, and are gone; of those left,
seven come back to within 0.02 to 0.07 LDU (8256-1, 5571-1, 5510-1, 8274-1,
8840-1's B model, 8854-1, 8850-1's B model): a loop is closed to 0.05 LDU,
and the turns there and back leave its idle freedoms (an axle free to slide
in its hole, a link free to spin on its line) a few hundredths from where
they stood. The rest stop on the way back where two parts meet, now named
in each row (9393-1's "Technic Axle 3 with Stud meets the Technic Gear 12
Tooth Bevel", 42077-1's steering link and wheel bearing, 42110-1's rack and
frame).

**The other moving things, swept** (`tools/move_sweep.py`,
`movesweep_now`). 749 OMR files have a turntable, a door, ramp, hatch, gate,
flap or lid, or say crane, excavator or boom; 407 have something of those
kinds on a joint, and 574 things were moved +30, -60 and back over MCP: the
top of a turntable, a door, and the biggest boom or arm (6 parts or more) on
a hinge, a pin or an axle, which in a car is often a bonnet or a gearbox
shaft. With every fix above but the last three:

| kind | things | both ways and back |
|---|---|---|
| turntable | 130 | 72 |
| door | 97 | 52 |
| boom or arm | 347 | 123 |

| what stopped it | things |
|---|---|
| two parts meet at once | 108 |
| moves, not back where it stood | 104 |
| its loop has no freedom | 57 |
| held rigidly | 21 |
| its loops are too big to solve | 11 |
| held by a worm or a screw | 11 |
| it did not move | 10 |
| what stays moved | 4 |

Every one moved at all; the refusals name what holds each. Of the 104 not
back, 50 stop on the way back where two parts meet, 30 swing down under
their weight on the way (a boom on a pin without friction falls when let
go, as it should), and 22 drift. Two parts meeting, at once or on the way
back, is the biggest cause (158 of 327), and the last three fixes are for
it: what bends is not in the way, a tyre scrubs on the floor, and what
touched as built is forgiven in each later grab.
Swept again with them (`movesweep_after`): the 138 sets with a thing that
two parts stopped, and every fourth of the rest with one that moved, 184
sets and 285 things (run with a stud rule since taken out, below).

| | both ways and back | two parts meet at once | not back |
|---|---|---|---|
| before the three (`movesweep_now`) | 87 of 285 | 108 | 60 |
| after (`movesweep_after`) | 102 of 285 | 104 | 49 |

Sixteen move both ways and back that did not (ten booms or arms, four
turntables, two doors: 8074-1's crane on its turntable past its cable,
10220-1's door back past what it was built against), and one that did no
longer comes back (8110-1's arm, 2.3 LDU short). Most of what meets at once
is not changed by them: covers 2 LDU a cell meeting a neighbour built flush
(a plate meeting the tile beside it, two slopes, a door its frame's corner),
which each row names.

**A stud's tip, tried and taken out.** 8074-1's grader is drawn tipped 4.6
degrees, and the studs of a brick under a row of tiles were read as reaching
the plate on the tiles, which holds the rack: the lattice covers a part
turned off the grid with every cell its boxes touch. A stud into a part
turned off the grid held only where its tip is inside that part's box
(`Bodies._tip_in`), and the grader steered; but 42080-1's crane then left
five round bricks behind on its flexible joiners, and its cylinder's checks
failed (with the rule, and with it narrowed to parts square to each other,
when the grader stopped steering again). It is taken out, and the grader is
left for later.

**Proved** (bench/results/grab11-2026-10-18, `probes/`), on a box at load
25 to 38: `grab_probe` windowed (`grab_probe_full2.log`) ran 439 checks and
434 passed. Of the five that failed, 6753-1's turn back is no longer a
check (above); "pulled too far, the tube is named" fails on 17bc0382 too
(G10's, `--only=hoses --hose=made` on the base); two hose-laying costs (6.1
and 27.3 ms a frame) and the big model's let-go frame (111 ms) are timing
checks and pass run alone (`--only=hoses`: 31 of 32, the one G10's;
`--only=big`: 5 of 5, 45 ms). The check added for the round rack's socket
count was corrected after that run and passes alone (`--only=sockets`, 6
ball joints for 4 links). mechanism_probe (54), mechanism_sets (2 sets) and
simulate_probe (41) pass; `tools/gears.py check`: 0 problems. Each new
check fails with its fix taken out, tried once in a copy with the fixes
out: 42076-1 without the groove, 8022-1's racecar (the round rack's;
8832-1's is the same rule) and 42043-1 without the table's entries, 8862-1
without the shaft on the line, 42111-1's sockets without the bore rule
(0 ball joints), 42083-1's meeting words without the names, 8074-1's crane
and 10220-1's door without what bends and what touched as built. Pictures
from above, cut over the rack, before and turned each way
(`steer_SET_*.png`): 8022-1's racecar and 8832-1's roadster, whose front
wheels the round rack turns one way and the other, and 8074-1's grader,
taken with the stud rule (its wheels turned each way; without the rule it
does not steer).

**Tried and left.** A pinion read in its rack kept in it at the next reading
with twice the slacks (teeth in mesh stay in mesh), for 8466-1 and
42077-1, whose turn back found the pinion in no rack: neither came back,
and it was taken out again.

**Left for later**, with sets to start from: racks clicked onto a plate's
studs in the file (8448-1's five models: 32185's peg holes take the 2 x 10
plate's studs and the plate stands on the frame's studs; 8081-1, 854-1,
5533-1); steering arms on balls (10295-1, 4404-1, 9392-1, 42021-1); loops
too big to solve (42029-1, 42039-1, 42125-1, 42131-1, now with the track
rods' balls in them); the far arm that does not follow (34, many bikes and
single wheels, where the sweep's far arm is not a steering's); the 21 not
back (above: a loop's idle freedoms, and parts meeting on the way back);
8836-1, which takes longer than the sweep allows. In the moving things:
loops with no freedom (57: a boom in a frame of pins), and what swings down
under its weight on the way back, which is right, and which the sweep counts
as not back.
**Fitting a frame, measured** (`grab_probe -- --only=hoses` at load 20 to 23
of 24 cores; `bench/results/grab10-2026-10-18`). Laying every hose every
frame, 42080-1's six tubes took 8.2 ms of a frame here and 77 at worst on a
loaded box, its cylinder's drag 20.5 ms a frame on average and 43.1 at worst,
and a browser's frame with the made tube 7.7 ms for the tube. Within the
budget: 42080-1's six 3.2 ms at worst (0.5 a tube), 42043-1's two 1.9,
42050-1's eight 2.7, the made tube 0.4; every one laid within one or two
frames of the pointer resting. 42080-1's cylinder drag (the whole probe):
12.5 ms a frame on average, 16.9 at the 95th per cent, 17.2 at worst, back
with G7's 9.5 to 12.7. In a browser (grab_flow on a local export) the tube
costs at most 2.7 ms a frame and the drag frame 2.1 ms on average, 3.9 at
worst; every check passed. The probe now fails a frame whose hoses take
more than 3.5 ms: laid every one every frame, 42080-1's took 10.3 and failed
it. The whole probe ran 406 checks at load 30 to 37 and failed five, all
timing: the four-bar's drawing share and the hose frames; each passes run
alone at low load.

## 20. Real stops and false ones (G12)

G11's moving sweep left "two parts meet" as the biggest cause, 158 of 327
failures, and could not tell a real stop from a false one. A door turned
against its frame should stop there, and the sweep should count that as
moving to its stop. A plate that met the tile built flush beside it at the
first degree should not stop at all. G12 makes the sweep tell the two
apart, fixes the false ones in general, and then takes on the steering
left over, most sets first.

**The base.** m81 (ec9133ea, every grab unit), swept again with this
unit's judge (below), from a copy of it: the steering sweep
(`sweep_before`) and the moving sweep over all 749 files
(`movesweep_before`). The tables are in bench/results/grab12-2026-10-18.

| | before (m81) |
|---|---|
| sets that steer, of those with a steering | 51 of 168 |
| things that turn both ways and back, of the 749 files' 576 | 240 |
| and that turn as far as their real parts let them | 10 |

**Telling a real stop from a false one.** Where a move stops where two
parts meet, the sweep now works out a grab of its own on the same part and
turns the moving part a degree further, the way the move was going. A
click hinge is turned to its next click instead. It then asks whether the
two parts' exact shapes overlap there (`grab_probe._judge_meeting`). The
shapes are BrickNet's convex pieces, the same ones the build check uses,
and they meet when they overlap by more than 1 LDU. A stop is "real" when
they overlap, "false" when only the parts' 2 LDU covers met, and "not
judged" when one of the two parts has no exact shape. A file's own printed
or fan-made part is one case. So is a part that swung on under its own
weight after it stopped, or a driver that is held rigidly once it has
turned (`meeting` in each row). A thing counts as **moving to its stop**
when a turn that did not move at all met real parts, the other turn moved,
what stays stayed, and the turn back put it where it stood
(`move_sweep.to_its_stop`). In the base, the 565 steps stopped where two
parts meet were 195 real, 198 covers only and 172 not judged.

The false ones were parts built flush: 10220-1's plate with rounded pins
beside a tile 2 x 4, 10295-1's two slopes 75 side by side, a hinge plate on
10185-1's plate with studs on one edge, 10256-1's plate 1 x 8 beside a
plate 1 x 6, two plates on 10184-1's brick 2 x 3, 8285-1's angle connector
on an axle pin. Each part's cover reaches past the part, and at the first
degree the cells of a turned cover cross the cells of the neighbour. The
real ones were mostly a door or a lid closed against what it rests on
(6693-1's car roof, its hinge top against its base), and a train's plate
against its buffer beam. By the 1 LDU rule, a bogie on a pin built flush
under its buffer beam overlaps it by 1.3 to 1.7 LDU a degree on, both ways
(10015-1, 10183-1, 10205-1). It counts as real, which a person looking at
the train may doubt; it is left as the build check would judge it.

**Two parts meet where their shapes do** (`Grab._clear_exactly`). A grab
still finds room with its covers, which is fast. Where a cover meets
another part, it now asks the two parts' exact shapes at that pose, and
the part is stopped only where they overlap by more than the 1 LDU the
build check allows. A part with no exact shape is still judged by its
cover. On the web the shapes come as the geometry does, and until they
arrive the cover decides. The cost is a test of the two parts' convex
pieces, and only where a cover has met something.

**Racks with holes ride in their groove.** The racks with holes (6630,
6592, 32185) are drawn as channels underneath, 12 LDU across between their
end holes, which is a stud's width. 8448-1's rack (32185) lies on a plate
2 x 10, and the plate's studs stand up in the channel. The rack was read
as gripped by those studs, so it was one body with the frame, and in all
five of 8448-1's models the pinion turned against nothing. The gear table
now marks the three as grooved, as G11 marked 87761 and 64781. Turned
once, 8448-1's rack slid 1.96 LDU, and the next reading found none of the
studs. Their tips are in the groove, which the rack's cover leaves empty,
and the rack was then lodged in the steering arm it touched and carried by
it. The studs standing in a grooved rack's groove are now found from the
rack's shape, wherever it has slid to (`Bodies._grooves_by_shape`). 5533-1's
rack (6630) goes 5.33 LDU and back. 8448-1's goes 1.96 LDU and comes back
0.75 LDU on the second turn, which then stops where a steering link meets
a wheel rim (left, below).

**A steering arm on two balls turns on its kingpin.** The steering arms
with ball joints (15460, 32186, 6571) hang on an upper and a lower ball,
which work as their kingpin, plus a third ball for the track rod. A grab
of one was refused "on a ball in a closed loop", because a ball has no
line to turn about. A part on a ball in a loop that also hangs on a second
ball now turns on the line through the two balls' middles (`Grab._kingpin`;
`Linkage.read`'s `driver_line`). The second ball must be on a body held on
a line of its own or on what stays, so a track rod hung only on balls is
not taken for a kingpin. Both balls stay where they are as the arm turns,
and the loop moves the rest. 9392-1's arm turns on it with its kingpin
0.000 LDU from where it stood. Its turn then stops where the track rod
meets a beam, and 4404-1's loop closes neither way (left, below).

**The joints' cache under a lock.** A sweep job and a probe run each died
on a broken key in `Joints._lines`, the cache of each part's axles and
holes. The model's joints are read on a worker once it has stood still,
and on the main thread when move_part asks before that reading is done.
The two filled the cache at once. It is now filled under a lock.

**Steering, swept** (`sweep_before`, `sweep_after`).

| | sets that steer, of those with a steering |
|---|---|
| before (m81) | 51 of 168 |
| after (all of G12) | 54 of 168 |

No set that steered stopped. 8285-1 steers because its angle connector
no longer meets the axle pin beside it by their covers at once. 42035-1 and
5510-1 steer because their turn back no longer stops short, where they
came back 0.53 and 0.07 LDU off before. In all 33 sets that steer at a
pinion and have steering arms, the arms turn with the rack.

| what stopped it | before | after |
|---|---|---|
| the rack (or far arm) did not move | 33 | 44 |
| not back where it stood | 21 | 23 |
| something is in the way at once | 18 | 7 |
| the pinion turned, its rack did not (one body with what it turns in) | 15 | 10 |
| held rigidly | 9 | 9 |
| its arm hangs on a ball in a loop | 8 | 5 |
| its loops are too big to solve | 7 | 8 |
| its loop has no freedom | 4 | 6 |
| what stays moved | 1 | 1 |
| held by a worm or a screw | 1 | 1 |

"The rack did not move" grew, because sets that were refused at once now
turn and stop further on. Among them are 8448-1's five models, which stop
on the second turn, and 9392-1's two, which stop where a track rod meets a
beam. Five that met something at once are also here: 42055-1, 42056-1,
42078-1's dump truck, 42108-1 and 8880-1. 5533-1's rack goes 5.33 LDU and
back the other way, but does not come back where it stood.

**The other moving things, swept** (`movesweep_before` over all 749 files;
`movesweep_after` and `movesweep_beforesub` over the same 260). The after
sweep moved, as G11's did, every set whose things two parts stopped, that
hang on a ball in a loop, or that have a rack with holes, plus every fourth
set of the rest: 260 sets and 382 things. A turn now counts only when the
thing itself turns a whole degree. A turn stopped at once used to say
"Moved" when free joints inside the thing swung down, and four things
(42068-1's turntable, 4432-1's door, 4993-1's and 5974-1's booms) passed
as moving in m81 without turning (`move_sweep.moves`).

| the same 260 sets | both ways and back | to its stop | turn at all | two parts meet | steps stopped by covers only |
|---|---|---|---|---|---|
| before (m81) | 103 of 382 | 5 | 245 | 139 | 162 |
| after (all of G12) | 145 of 382 | 15 | 300 | 59 | 15 |

By kind, both ways and back: turntables 34 to 46, doors 25 to 34, booms and
arms 44 to 65. No thing that turned both ways and back before stops now.

| what stopped it | before | after |
|---|---|---|
| moves, not back where it stood | 54 | 71 |
| two parts meet at once: their covers only | 54 | 6 |
| its loop has no freedom | 38 | 44 |
| two parts meet at once: the real parts | 33 | 16 |
| held rigidly | 18 | 19 |
| not back, two parts meet on the way back: not judged | 16 | 17 |
| two parts meet at once: not judged | 16 | 11 |
| not back, two parts meet on the way back: their covers only | 13 | 0 |
| held by a worm or a screw | 10 | 10 |
| not back, two parts meet on the way back: the real parts | 7 | 9 |
| its loops are too big to solve | 7 | 7 |
| moves to its stop (the real parts meet) | 5 | 15 |
| it did not move | 4 | 4 |
| what stays moved | 3 | 7 |
| other (a head on a ball in a loop) | 1 | 1 |

"Not back" grew because more things turn now. Of the 71, most hang on a
pin or an axle without friction and swing down under their weight once
let go, which is right, and the sweep counts it as not back. "Two parts
meet at once: the real parts" fell from 33 to 16, and not every one of
those fell for a good reason (left, below).

**Proved** (bench/results/grab12-2026-10-18/`probes/`), on a box shared
with other sessions: `grab_probe` windowed on the GPU lease, in full
(`grab_probe_full.log`), ran 451 checks and all passed. That is the 442 it
had and nine new ones. 10295-1's right door opens one way and stops at
once the other, where its real parts meet. Three moving cases have no turn
stopped where only covers met. Two grooved racks pass two checks each, and
there is one kingpin check. No timing check failed, so
none had to be run alone. mechanism_probe (54 checks), mechanism_sets (2
sets), simulate_probe (41) and placing_probe (36) pass, `tools/gears.py
check` finds no problems, and tests/test_gears.py passes 6. Each new check
fails with its fix taken out. This was tried once in a copy: 10295-1's two
checks without `Grab._clear_exactly`, all four grooved checks without the
table's grooves, 8448-1's second check without the reading by shape, and
the kingpin check without `Grab._kingpin`, where the arm is refused again.
Pictures (`steer_SET_*.png`, `move_SET_KIND_*.png`, before and after each
turn). 5510-1's front wheels turn one way and then the other. 3741-1's B
model's locomotive turns on its coupling against its tender, which its
covers held at once both ways in m81. 10185-1's first floor swings open on
its hinge, where its hinge plates met the plate beside them at once. Also
10295-1's right door, and 8285-1's front wheels, from above.

**Left for later.**
- A session's move tests where it ends, not the way there. With covers,
  a flush neighbour also blocked the end, so a move stayed put. With exact
  shapes the end is often clear. Eight things that now turn both ways pass
  a stop the judge calls real at the first degree. Six are trains: 10015-1,
  10183-1 and its caboose, 10205-1, 3741-1's B model and 4543-1, each a bogie
  or a coupling under a buffer beam. The others are 21019-1's turntable and
  3180-1's boom. The bogies turn in the real trains, and a buffer beam's
  convex pieces may fill the space under it. A move_part that tests its way
  a few degrees at a time comes next, with both sweeps run again.
- What the joints are read as after a move, from where the parts stand.
  8448-1's steering link loses the ball on its arm, and the second turn
  stops where it meets a wheel rim (five models). 4432-1's door is read on
  another joint. 10185-1's first floor, 4404-1's kingpin loop and 9393-1
  lock. 10295-1's door and 75969-1's roof are held rigidly on the way back.
  G11's studs off the grid belong here too.
- Ball-jointed steering arms still refused: 10265-1, 10295-1 and its 911
  Turbo, 42021-1 and 41999-1. The ball they are taken by is on a rod hung
  only on balls, so no kingpin is found.
- The judge's own limits. A part on a free pin that swings after its move
  is judged where it came to rest. 21311-1 and 8147-1 read as covers only.
  A click hinge is judged at its next click, and one that meets something
  between two clicks, and is clear at the click, reads as covers only
  (10179-1, 21318-1).
- From G11: 8074-1's grader, 6753-1's tow truck, steering loops too big to
  solve, and 23 steering sets and 71 moving things not back.

## 21. Play from a shared link (P1)

Grab 1 to 12 let a person drag what moves in their own model. P1 lets
anybody do it on a model somebody shared: open its link and steer the
wheels by the steering wheel, swing the boom, open the doors, turn the
gearbox by its input. Nobody can play with a model on Rebrickable.

**The same grab.** The viewer takes a press on a part the way the
builder's Select does (`GrabDrag.press`), on the same joints, stops,
couplings, loops, swings and falls; held still 0.4 s first it takes the
end of a chain (`PressHold`, timed by what the frames saw). A press that
takes hold of nothing that moves (a rigid part, a loop with no freedom)
says why in the viewer's pill and turns the view instead, as a drag on
the model always did there (`main._play_press`). A finger plays too
(`main._play_touch`): one finger down on a part that moves and drawn past
a tap (`CadCamera.TAP_SLOP`, 14 px) takes hold of it before the camera
sees the drag; anywhere else, or with a second finger, the camera turns
and pinches as before, and every finger's coming down and lifting still
reaches it (`CadCamera.fingers`).

**Nothing kept.** The store is read-only in the viewer, so a move is kept
only in this visit's model (one step of its history, as in the builder).
Reset undoes every play's step back to the model as it opened
(`main._play_reset`; a swing is stopped where it is first, and a section
still being checked or falling comes to rest first). Build it and the
booklet put it back before they start: they are the model as built.

**When.** The joints are read once the model is up, its steps worked out
and its lattice told of every part (`_ready_play`, after
`ModelStore.register_later`): a worker's work from 300 parts where there
are threads. Read as the model opened it slowed a phone's first step
(the reason the viewer had the grab switched off). Until then a drag
turns the view; so does a drag while the timeline shows a step short of
the whole model, whose parts ahead of it are in a move's way unseen.

**What moves, said** (`src/assembly/playable.gd`). From the bodies and
gear trains a drag uses: steering (a steering arm on its kingpin, a
steering rack, or whatever carries a wheel and turns on an upright line:
a knuckle of beams and blocks on its pin, a toy's front axle on a
turntable; taken by its steering wheel where it has one, else its arm or
its biggest part), turntable,
boom (6 parts or more on a hinge, a click hinge, a pin or an axle,
reaching 3 studs or more from its line, no tyre in it, and lifting: its
line is not upright), doors (a door,
ramp, hatch, gate, tailgate, flap or lid), gears (two in mesh, one
turning on its joint), pneumatics, actuator, rack. A minifigure, a hose
and a wheel on its axle are not said: every town and car has them, and
they can still be dragged. The viewer's pill says "Moves: steering, boom"
and "Drag a part that moves" ("Touch a part that moves and drag it" on a
touch screen); the same words go with the model when it is published,
for its gallery card (docs/COMMUNITY.md, Play).

**A fingertip, and a browser's fingers.** Two things the desktop probe
did not show and play_flow did. Chrome numbers a finger as the page's
touches go (index 1 there), and a finger taken only at index 0 never
played: the first finger is the one that comes down with no other down.
And a steering wheel on a phone is a few points across, its rim thinner
than a fingertip: the finger on the wheel's handle came down on the plate
behind it and turned the view. A finger on a part that does not move now
means a part that moves within a fingertip of it, about 10 points
(`main._play_brick_near`).

**What a frame costs.** Without the balance marks a viewer's drag does not
weigh the model each frame either (once, as it is let go, for a fall):
on a phone slowed four times the weighing took the worst drag frame from
19 to 47 ms. The joints are read on a worker in the viewer whatever the
model's size (`GrabDrag._ready_ahead`, in the builder too since
2026-10-21): the 93-part racer read on the page's thread was 147 to 159 ms
of one frame in SwiftShader.

**Proved** (2026-10-19). `tools/probe.sh share_play_probe` (windowed, on
the GPU), 40 checks: 8808-1 opened by its link, "Moves: steering" said
2.3 s after its steps; its steering wheel turned 30° by the mouse takes the
loop and the rack and both steering arms turn 7.7° on their kingpins, the
pill saying "The steering, 34°", no balance marks; the drag's own work 1.1
to 1.3 ms a frame on average, 1.5 to 1.9 at worst; nothing published,
written or changed at the link; Reset puts every part back exactly; a
fingertip beside the wheel's rim means the wheel, and a finger (index 1)
turns it with the camera still; a drag on the chassis turns the view;
Build it opens on the model as built; and the Share panel sends `moves:
["steering"]`. With the press taken out (`_play_press` false) it fails at
the first drag, and with the finger taken only at index 0 it fails three
checks. `share_view_probe` passes as before (173 checks), `grab_probe --
--only=racks` too (43). In a browser, `tools/web/play_flow.mjs` on a local
export, Chromium in SwiftShader, 34 checks: at 1280 x 800 the mouse turns
the steering 85°, the app's own work 3.5 ms a frame on average and 9.2 at
worst, the page's frames 17 ms (33 at worst); at 390 x 844, three device
pixels to the point, a finger turns it 107° to its stop with the CPU slowed
four times, the app's own work 6.9 ms on average and 23 at worst, the
page's frames 17 ms median and 1.1 s at worst (SwiftShader drawing 1170 x
2532 pixels on a slowed CPU, as grab_flow found); the joints read on a
worker in 136 to 194 ms; the pill clear of the view cube; Reset; the link's
text unchanged; and the gallery's cards saying what moves. Against the
release before it (rel-m84's export) the flow fails: nothing is said to
move. Pictures in the run's `--out` (`laptop_*.png`, `phone_*.png`).

**Left for later.** A drag on the timeline short of the whole model turns
the view: playing a step's parts with the parts ahead hidden but in the
way would surprise. The part under a lifted finger stays named, as before
in the viewer. Bigger models in the viewer (a few thousand parts) are not
measured here: the reading is on a worker, but each move's room tests are
the builder's, and a big section is checked on pauses as it is there.

## 22. A move tested along its way (G13, G13b)

G12 made two parts block a move only where their exact shapes overlap. A
session's move_part, and a big section's check when the pointer pauses,
still tested only where the move ended. With covers, a flush neighbour also
blocked the end, so a move that would have gone through something stayed
put anyway. With exact shapes the end is often clear when the way is not:
G12's sweep found eight things turning both ways through a stop its judge
calls real at the first degree. G13 tests the way, then decides the eight.

**The base.** rel-m83 (b1108e94: G12 and covers2), swept with G12's judge
from a copy of it: the steering sweep over its 181 files (`sweep_before`)
and the moving sweep over G12's 260 sets (`movesweep_before`). The tables
are in bench/results/grab13-2026-10-19.

**Along the way** (`Grab._walk`). A turn, a slide or a ball's turn is
tested in steps from where it stands (a big section shown on trust, from
the last pose checked) towards where it was asked. It stops at the first
step with no room, bisected back to STOP_TO from there. A step moves no
point of what moves more than 2 LDU (`PATH_LDU`): the corners of each
tested part's box, placed as the move places it a degree on (a slide's LDU
on), measured once a grab (`Grab._path_rate`), so gears the move drives,
what hangs on them and a loop's other bodies count as they move. A turn's
step is between 0.1° and 3°. A loop is solved at each step, so its way is
tested in at most six steps a move and two a drag's frame, on its
quarter-degree grid, and its
pose is kept at each step, so the next is solved from it: solved from where
the move began, 42024-1's loop of 36 joints took 172 ms a frame and four
steering four-bars came back 2 to 5 LDU off. Each part is tested only
as often as it goes 2 LDU: a hinge's own pieces, which stand next to
something all the way round, are tested a few times in a turn that tests a
boom's tip at every step. A part not tested at a step may be up to 2 LDU of
its own way from where it was last tested, so a stop can leave such a part
into another by that much. A step asks each turned cover where something
is (BrickLattice.TurnedCover) rather than working it out whole. The end is
tested whole, as before. A drag does the same each frame within its
budget, and a big section shown on trust is checked on a pause from the
last pose checked, a step at a time, each part as often as it goes 2 LDU
(`Grab.verify_step`): every part at every step kept 42081-1's arm, 653
parts, 10 s after it was let go. A swing under its own weight already
tested its way (Swing, every TEST_LDU).

**What a move may go through** (`Grab._pair_forgiven`). A grab forgave for
good every part whose cover overlapped the moving side's where it began,
for every moving part. A cover reaches past its part, so a move stopped
where two parts just meet begins the next with their covers into each
other. Tested along its way, 10220-1's door stopped at 5° where its plate 1
x 1 round meets the tile it was built against, then turned -60 from there
with its plate 2 x 8 through that tile, and met it coming back at -17°. Now
only the pair that overlapped is forgiven: the plate 1 x 1 round may go on
through the tile, the plate 2 x 8 may not. Where one of the two has no exact
shape, its cover judges it, and what overlapped any moving part is forgiven
for all of them, as before: 42042-1's winch drum, a file's own part, met an
axle by their covers 66° round. What touched as built is kept
for later grabs as a pair too, and only where the two exact shapes overlap
as built (a file's parts built into each other) or one has none
(`Grab._forgiven_at_rest`): flush parts are for the exact shapes to judge.
A section of up to 80 parts has what it touches read at the press, as a
loop's was, so what touched as built is kept whatever the first move met.

**The eight stops, decided** (`grab_probe -- --only=gapjudge`, then
`tools/shape_gap.py`; `gapjudge.jsonl` and `shape_gap.json`). Each pair was
also set side by side as the parts' own solids: each part voxelised from its
LDraw geometry at 0.5 LDU, as the covers are at 2, with its studs put back
(voxelise leaves a stud's open barrel out, and a stud is what meets a
buffer beam), the moved one turned half a degree at a time to 30° each way.
In the six trains the exact shapes and the solids first overlap by more
than 1 LDU at the same half degree both ways, and in 21019-1 within half a
degree. In 3180-1, one way, the solids stay clear where the shapes overlap
by 1.02 LDU. So a buffer beam's convex pieces do not fill the space under
it, and the judge is right about the shapes. What was wrong is what was
read as moving.

- **The six trains: false, the reading's error.** In each, the buffer
  beam (4022) sits on four studs of a plate that turns: BrickNet joins its
  four holes to them. The app read it as a body of its own, hung by a hinge
  on its coupling (2920), and it stayed where it stood while its plate, or
  the bogie built against it, turned into it. The holes are in the beam's
  cap, 32 LDU above its bottom face, where the catalogue's sockets are read
  from. The lattice found the studs in the beam, but the beam and its
  coupling turn against each other, and by their faces the studs were put
  in the coupling, which has no socket: studs pressed on a face, holding
  nothing. Where the part chosen by faces has no socket, a stud the lattice
  found in a part with one of BrickNet's holes for it is in that part
  (`Bodies._sits_on`), and one of BrickNet's holes or tubes takes a stud as
  a socket does (`Bodies._in_a_hole_exactly`). The beam is one body with its
  plate and turns with it. In 10015-1 and 4543-1 the coupling then met its
  magnet (73092, an obsolete part with no exact shape), held by nothing. A
  part held by nothing that shares no cell with anything, where it or what
  it is in has no exact shape, is now held by what goes through its middle,
  else by what its box is most into (`Bodies._lodge`): the magnet by its
  coupling, 8074-1's belt wheel by its axle and the half pin by the wheel.
  Two parts with exact shapes are not: lodged so, 42042-1's winch was read
  into a loop of 63 joints. The shapes are read on the main thread before
  the model's joints are read on a worker (`GrabDrag._ready_ahead`). Since
  the file's copies of the belt wheel are read as 4185a (2026-10-20), it has
  an exact shape, and its half pin was held by nothing and stayed as the
  crane turned, stopping it at once: neither the wheel's connectors nor
  BrickNet's shape name the holes in its rim. A part whose shaft or stud
  runs in a round hole of the other that names no joint (a bore) is lodged
  in it, exact shapes or not (`Bodies._in_a_bore`).
- **21019-1's turntable: real.** A bracket (99781) stands on two studs of
  the plate 8 x 8 on the turntable, and its own studs are in tiles of the
  side that stays: the build holds the turntable, which in the real tower
  sets a leg's angle. Its solids overlap from 1.5° one way.
- **3180-1's boom: false one way.** The tanker turns its container
  cupboard (4532) into the cupboard's own door (4533), which the app reads
  as held by nothing: the door's hinge in the cupboard is not read, and
  both have exact shapes, so it is not lodged either (left, below).

**The other moving things, swept** (`movesweep_before`, `movesweep_after`,
G12's 260 sets; the after sweep's last 31 sets ran as `movesweep_afterrest`
and are merged into it).

| the same 260 sets | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|
| before (rel-m83) | 144 of 380 | 15 | 297 | 209 / 16 / 180 |
| after (G13) | 161 of 377 | 15 | 294 | 224 / 15 / 179 |

By kind, both ways and back: turntables 46 to 51, doors 34 to 39, booms
and arms 64 to 71. 23 things now move both ways and back that did not, 8
no longer do. Among them, 3180-1's and 6357-1's booms now move to their
stop, and 42094-1's turntable, 5571-1's and 6950-1's booms meet real parts
on the way back. The six trains moved both
ways in rel-m83 too, through their beams; now their beams go with them.

**Steering, swept** (`sweep_before`, `sweep_after`; its last 45 sets as
`sweep_afterrest`).

| | sets that steer, of those with a steering |
|---|---|
| before (rel-m83) | 55 of 168 |
| after (G13) | 42 of 167 |

This is worse, and not by what is in the way: all 14 sets that stopped
steering turn both ways and come back 0.027 to 0.19 LDU off, past the 0.02
the sweep allows, the part furthest off an axle of the steering loop.
The loop's pose is kept at each step of the way, and a way solved in steps
does not come back to exactly where it began. Stepped finely (no limit of
six steps) it came back no closer, on 12 of the 14 (`sweep_fix`). Left for
later, first.

**Proved** (bench/results/grab13-2026-10-19/`probes/`): `grab_probe`
windowed through `tools/probe.sh`, in full (`grab_probe_full.log`), ran 463
checks: 461 passed. The two that failed are 42080-1's hoses laid within a
drag's frame (16.8 ms against 2.0), a timing check: run alone side by side
under the same load, rel-m83 fails it too (5.8 ms; G13 3.7 ms). New checks:
`-- --only=path` (2: the made arm stops at the plate over its way, and goes
all 90° the other way) and `-- --only=beams` (6: 10205-1's and 10183-1's
beam is one body with its plate and turns 30° with it). Both fail in
rel-m83 (`--only=path`: the arm went 90° through the plate; `--only=beams`
4 of 6). The moving checks' 8074-1 turntable is checked both ways, not
back. The Python suite (numpy and scipy) passes 748; pyright finds no
errors. Frame costs, the drag's own work (this run, at load 15 to 28; G12's
at load 4): the turntable, hinge, click hinge, gear train and slider drags
mean 0.2 to 1.3 ms a frame (G12 0.15 to 0.5), worst 0.8 to 5.6 ms (G12 0.5
to 7.4); the ball joint 1.2 ms mean, 8.3 worst (0.4, 0.7); steering loops
1.5 to 3.4 ms at worst (1.2 to 2.8); 42024-1's actuator 13.4 ms mean, 27.9
at 95% (6.6, 12.1); 42081-1's arm 11.8 and 24.3 (11.2, 14.0), kept 3.6 s
after it is let go (3.6); 7191-1's big section 7.5 mean, 18.8 worst (2.7,
21.4). Pictures: `move_10205-1_door_*`, `move_4543-1_boom_*`,
`move_10220-1_*`.

### G13b: the steering comes back, a free joint pressed swings aside

G13 was held on its steering sweep: 42 of 167 sets steered, against
rel-m83's 55. G13b, on the same branch, mends that and does three more
things.

**A loop's end does not depend on the steps** (`Linkage.kept_state`,
`Linkage.restore_kept`). A loop is solved from the pose it last kept, and
the walk kept each step's pose to solve the next from it. Putting that pose
back after the walk was not enough. The solver also keeps its last solve,
the slope the next solve starts from, and the part of the loops that spins
on its own. Left as the steps had them, the steering came back 0.5 LDU off.
Now all of it is put back after the walk, and after a pause's walk, so
where a move ends is solved as if there were no steps. The 14 sets that
stopped steering in G13 all steer again, back within 0.0011 to 0.0183 LDU
(`sweep_fix3`). A loop's drag now leaves its way to a pause or the
release, as a big section's does, and each frame tests only where the
pointer is. Solved a step at a time in the frame, 42024-1's actuator (a
loop of 36 joints) took 62 ms a frame on average and 181 at 95%.

**A free joint inside what moves swings aside when pressed**
(`Grab._push_aside`). A step may have no room where the part that met
something hangs on a joint inside the moving section that does not hold by
friction. That joint is then turned aside 1°, then 2, 4 and so on to 64
each way, until the step has room, and the move goes on. It settles under
its weight afterwards, as before. Loops and balls are left out. 8074-1's
crane swings 18 free joints inside it down on its first turn, most of them
180°, and on the way back it met the brick 1 x 16 that swung. Now it turns
+30, -60 and back to 0.000 LDU, and its moving check is strict again.

**A small section's drag tests its way for 2 ms a frame**
(`Grab.walk_budget_ms`, `GrabDrag.WALK_BUDGET_MS`). Past that, the turn is
shown where the pointer is, and the rest of the way is tested from the last
step with room, on the next frame or on a pause. The status bar keeps its
words for that ("too big to test every frame: checked when you pause").
The drag's own work at its worst frame, in the full run below (load about
28 there) and in the one the spin-down cut short: a turntable 2.1 and 2.1
ms (G13 5.5, G12 0.3), a hinge 4.9 and 4.2 (G13 5.2, G12 7.0), a click
hinge 4.4 and 2.9 (G13 3.4, G12 3.3). The ball joint's is not walked within
a budget, and is no better: 9.3 and 7.8 ms (G13 8.0, G12 0.5).

**The hoses' cost checks judge the laying's own work**
(`FlexFollow.lay_cost`, `grab_probe._lay_checks`). The two checks timed a
drag's worst frame by the wall clock, so a busy box failed them: 42080-1's
tubes took 16.8 ms at load 28, and 3.7 ms on the same code minutes later.
Now each hose is laid again where it stands seven times, and the fastest
is taken, which other jobs cannot make slower. A hose's mean must be at
most 2 ms, and the budget plus the costliest laying within 3.5 ms. The
drag's worst frame is said, not judged. With every laying slowed 3 ms
(`-- --slow-lay=3000`) all eight cost checks fail. Run seven times beside
other work (`-- --only=hoses`), and once in the full run, all eight passed
every time. In the run at load 43 to 46 (the 1-minute average while each
case ran), 42080-1's six tubes cost 0.79 ms a hose and 3.04 of 3.5 ms with
the budget, 42043-1's two 0.50 and 2.64, and 42050-1's eight 0.47 and
2.54. The fastest of seven still varies: the costliest laying was 0.55 to
1.15 ms from run to run, not in step with the load. The closest to the
limit was 42043-1's 3.15 of 3.5, in the full run at load 42. The drag's
worst frame by the clock was 2.1 to 4.3 ms, once 10.5 (42050-1, at load
30).

**Steering, swept again** (`sweep_after2`, the same 181 files): 56 of 168
sets steer both ways and back, against rel-m83's 55 and G13's 42. None
that steered in rel-m83 is lost, and 8840-1's B model now steers.

**The other moving things, swept again** (`movesweep_after2`; its last 45
sets, cut short by a spin-down, as `movesweep_after2rest`; both merged in
`movesweep_g13b`).

| the same 260 sets | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|
| before (rel-m83) | 144 of 380 | 15 | 297 | 209 / 16 / 180 |
| G13 | 161 of 377 | 15 | 294 | 224 / 15 / 179 |
| G13b | 163 of 381 | 15 | 300 | 221 / 19 / 170 |

By kind, both ways and back: turntables 51, doors 39, booms and arms 73.
Against G13, four things now move both ways and back that did not
(42064-1's and 42108-1's turntables, 42112-1's and 6953-1's booms), and two
no longer do. Both are worse:

- 21019-1's turntable. G13b's first turn stops 10° round, not 9°. From
  there, the second turn begins with a plate with a handle (#86) whose
  cover is into a plate with a clip (#124). A pair whose covers overlap
  where a grab begins is forgiven for that grab (G13), so the second turn
  goes all of -60° through the clip. The turn back is not forgiven, meets
  the clip at -29° and stops, 15.7 LDU from where it stood. The push aside
  is not the cause: switched off, the same. rel-m83 turned it +1° and -10°
  and back.
- 6987-1's turntable, in a loop of 8 joints, comes back 0.29 LDU off
  (G13: 0.0001). rel-m83 did not read the loop, and came back 12.3 LDU
  off.

Against rel-m83, nine things no longer move both ways and back: G13's eight
and 21019-1's turntable. Of G13's eight, 4002020-1's turntable (a loop of
15 joints) now comes back 0.025 LDU off, against G13's 0.057 and the 0.02
allowed. Steps judged to stop on covers only went from 15 to 19: five new
(4002020-1, 6983-1, 952-1, and 76139-1 twice), one of G13's gone.

**Proved** (bench/results/grab13-2026-10-19/`probes/`, on rel-m87 merged):
`grab_probe` windowed through `tools/probe.sh`, in full
(`grab_probe_full_g13b_final.log`, at load 17 to 48), ran 463 checks: 462
passed. The one that failed is a timing check: 7191-1's big section let go,
its keeping frame 119 ms against 100, 94 of it the commit (`Grab.commit`,
which this branch does not touch). It ran at load 47; G13's run kept it in
67 ms, 53 the commit, at load 15 to 28. Run alone (`-- --only=big`) beside
rel-m87 at the same time, at load about 28, both pass: G13b 64 ms (52 the
commit), rel-m87 75 (55). Alone at load 46, G13b took 249 (`big_ab`).
8074-1's turntable is
checked back again: +30, -60, +30 and back to 0.000 LDU, and no turn
stopped on covers only. `-- --only=path` and `-- --only=beams` pass, and
10220-1's door turns +4°, -9°, +5° and back to 0.000 LDU. Beside it,
`placing_probe` passes (38 checks) and `share_play_probe` passes (40: a
shared model's steering turned by its wheel, the grab's own work 2.9 ms at
worst). Frame costs, the drag's own work: 42024-1's actuator 14.1 ms mean,
29.9 at 95%, at load about 22 (G13 13.4 and 27.9; G12 6.6 and 12.1 at load
4); 42081-1's arm 12.7 and 17.5 (G13 11.8 and 24.3); the four-bar's worst
frame 18.1 ms, almost all one room test where the pointer is, at load
about 28 (G13 12.7); 7191-1's big section 9.7 ms mean and 28.4 worst, at
load 47 (G13 7.5 and 18.8).

**Left for later.**
- A pair forgiven by its covers (21019-1, above). Where both parts have
  exact shapes, forgive the pair only where those shapes overlap where the
  grab begins, and judge the rest by their shapes. That costs an exact
  test on every flush neighbour, so both sweeps and the frame costs need
  running again with it.
- Loops that come back a little off over three moves: 6987-1 (0.29 LDU)
  and 4002020-1 (0.025).
- A loop's drag is tested along its way only on a pause or the release;
  between, it is shown where the pointer is.
- The ball joint's drag is not walked within a budget.
- A part a step does not test may stand up to 2 LDU of its own way into
  another where a move stops.
- 3180-1's cupboard door: its hinge in the cupboard is not read.
- 6627-1's minifigure drag has one frame of about 400 ms, as in G12
  (403 ms).
- From G12, not begun: joints read again after a move (8448-1's steering
  link and its wheel rim, 4432-1's door, 10185-1's first floor, 4404-1's
  kingpin loop, 9393-1, and 6980-1's hatch, whose second turn takes the
  whole back), ball-jointed steering arms still refused, the judge's own
  limits, and G11's leftovers.

## 23. Grab 14a: room tests

G13b left two things worse: 21019-1's turntable went through a clip, and a
room test where a move meets the model cost 25 to 37 ms on a phone at 4x
CPU throttle (play_flow, 8808-1's steering dragged into its stop), against
the 33 ms a frame may take. G14a measured both. The second is mended. The
first was not what G13b took it for, and is left for later. On the way,
loops that came back a little off from a session's moves now come back.

**What 21019-1's turntable goes through.** Its first turn takes 267 parts, a
loop of 11 joints. One of those joints is a plate with a clip (#124) on a
plate with a handle (#86). A joint's own two parts are never tested against
each other, and the loop's turn of 10° leaves the handle's plate 2.42 LDU
into the clip's plate, by their exact shapes (0 where it began). The next
turn takes 16 parts and no loop. It begins with the two into each other, so
forgives them for the grab, and goes all of -60° through the clip. Their
covers were not the cause, as G13b thought: forgiving only a pair whose
exact shapes overlap where the grab begins changed nothing (10°, -60°, back
15.7 LDU off, `movesweep_fix21019`). Two more were tried and not kept:

- A loop's bodies tested against each other, the parts of their joints
  too (`movesweep_joints21019`). The clip's plate meets the handle's plate
  under a degree each way: the turntable turns 0.3° and -1°, judged real a
  degree on (1.77 LDU), and comes back 0.051 LDU off. That is what the
  model is: G13 found the build holds the turntable, so G13's 9° went
  through this clip too. But a steering's joints are pressed together, so
  their parts' shapes were asked at every frame: 8808-1's steering drag
  went from 0.9 ms to 3 ms of room tests a frame natively, ten times that on
  a phone.
- A pair already into each other where a grab begins may go no further in
  than it began, and half an LDU (`movesweep_depth21019`). After the first
  turn the turntable is then stuck both ways, 2.45 LDU from where it was
  built.

**A session's turn of a loop goes where it asks** (`Grab.turn_to`). A
loop's turn was put on a quarter-degree grid, so a drag back over the same
ground finds its turned covers kept. A stop is found off that grid, and the
turn back by as far as two turns went was rounded past where it began: 6987-1's
turntable came back 0.29 LDU off, its boom 0.29, 4002020-1's turntable
0.025. Only a drag's turn is put on the grid now. All three move both ways
and back, within 0.0005 LDU (`movesweep_grid2`).

**The room test where a move meets the model.** A probe of the drag
(`room_cost_probe.gd`, kept with the results: 8808-1's steering taken by
its tyre and turned 3° a frame to its stop) timed each part's test. Natively
the frame that met the stop took 3.6 ms, 1.6 of it one part: the steering
arm (4261, 176 convex pieces) judged against the Technic brick it meets
(3894, 316 pieces) by their exact shapes. `Exact._overlapping` compared every
piece of one with every piece of the other near it, 1,020 pairs of boxes, to
find 16 to test. Each shape now keeps its pieces' boxes in a tree, built as
it is read (`Exact._tree_of`), and the pairs are found through the two trees
and tested in the order they were before, so a clash says the same piece
pair. On 5,500 poses of real parts set side by side (`tree_check.gd`) the
two answer the same, the trees four times faster (1,113 ms against 275).
The arm's judge went from 1.6 ms to 0.4.

That left the room test's filters, the most of every frame: each moving part
asked the lattice twice what stands near it, and each box's shadow was
measured from its sixteen corners. A part's neighbours are now asked for its
cells and four more all round, once, at the press, and sifted from that
until it leaves them (`Grab._near`); a shadow is its middle and half edges
(`Grab.box_depth`, within 0.00003 LDU of the corners' on 20,000 pairs of
boxes, `box_check.gd`). Natively: a drag frame's room test
0.87 ms to 0.33 on average, the frame that meets the stop 3.6 to 1.1, the
first frame 1.3 to 0.9; the press asks the lattice for 21 parts' neighbours,
about 1 ms of a 6 ms press.

The local server handed out no exact shapes, so a local play_flow judged
the steering by covers: it stopped at 95°, not 108°, and its stop cost half
what it does on a deployment. `serve.py --parts` now serves `exact/` beside
`parts/`, as the bucket does. Then play_flow, the two builds served side by
side and run in turn, 8808-1's steering turned by a finger into its stop
at 390 x 844, the CPU slowed four times (the app's own work in a drag
frame):

| | worst frame | its room tests | mean frame |
|---|---|---|---|
| before (rel-m89), 6 runs | 24.8 to 46.7 ms, 29.5 the median | 20.4 to 32.7 ms | 9.5 to 13.6 ms |
| G14a, 4 runs | 17.1 to 21.8 ms, 20.5 the median | 11.4 to 15.2 ms | 7.1 to 8.8 ms |

By the mouse at 1280 x 800 the worst frame went from 4.2 ms to 3.4, its
room tests from 3.2 to 2.2. The trees alone, three runs: 21.3 to 38.2 ms.

The drag's worst frame also names its slowest part now ("the slowest part
#54 4261 7.1 ms").

A shape's tree costs its reading about a fifth more, and a browser reads a
shape in the frame it arrives; reading into arrays of its own pays for it
(`Exact.parse`, `parse_check.gd`: 600 shapes the same, 7.55 s with their
trees against 7.58 without). Natively a shape is still read when first
asked, so the first meeting with a part not met before reads it in that
frame (8808-1's brick: 12 ms).

**The other moving things, swept** (`movesweep_g14a260`: G13b's 260 sets,
run as `movesweep_g14a` and, for the 92 that run did not reach,
`movesweep_g14arest`, merged).

| the same 260 sets | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|
| G13b | 163 of 381 | 15 | 300 | 221 / 19 / 170 |
| G14a | 169 of 381 | 17 | 300 | 221 / 19 / 170 |

None lost. Six now move both ways and back that did not, each a loop that
came back off and now comes back within 0.0005 LDU: 4002020-1's and
42043-1's (the flatbed trailer) turntables, 6987-1's turntable and boom,
42080-1's and 8448-1's booms. 7991-1's boom and 952-1's turntable now move to
their stops. 21019-1's turntable is as it was in G13b. The list of sets has
grown to 709 since G12; 157 of the new ones were swept on the way
(`movesweep_g14aextra`: 60 of their 100 things move both ways and back), with
no row of G13b's to set them against.

**Steering, swept** (`sweep_g14a`, the same 181 files): 59 of 168 sets
steer both ways and back, against G13b's 56. None lost. 8256-1, its lawn
mower and 8854-1 came back 0.06 to 0.19 LDU off and now come back, by the
same mend.

**Proved** (bench/results/grab14a-2026-10-19/`probes/`): `grab_probe`
windowed through `tools/probe.sh`, in full (`grab_probe_full_g14a.log`, at
load about 27), ran 463 checks: 458 passed. Four of the five that failed
fail the same on rel-m89's own code, run beside it: `-- --only=path` and
`-- --only=beams` read a move's words as "now 30°", and MCP walk 2 made them
"turned 30°" (the moving sweep already read "turned"). The probe reads them
so now: `--only=path` passes (2: the arm stops at -20° where it meets the
plate, and goes all 90° the other way) and `--only=beams` passes (6). The
fifth is the timing check G13b's run failed too: 7191-1's big section let
go, its keeping frame 106 ms against 100. The frames
gate (`tools/web/cad_frames.mjs --gate`, 75969-1, the local server) passed
on this build twice and on rel-m89's once, at load 14 to 27: an orbit's
frames at the 95th percentile 43.6 and 61.3 ms against 27.7, select all
64.4 and 86.9 against 52.1, the timeline's Next 8.6 to 23 against 10.5 to
31.9, every bar 200 or 400. Neither an orbit nor select all runs a room
test or reads an exact shape. play_flow passed (34 checks) on this build.
`exact_probe` (29) and `joint_check_probe` (19), the build check by real
shapes, pass. `GRAB_PROBE_OUT` gives `grab_probe` a folder of its own, so a
run does not write over another's pictures.

**Left for later.**
- A joint's own two parts are not tested against each other, so a loop can
  turn a joint past where its parts meet: 21019-1's clip, above. Testing
  them every frame costs a steering's drag three times its room tests; a
  joint's parts turn about one line against each other, so where they meet
  could be found once a grab.
- A part not met before is read in the frame that meets it, natively.
- A loop that closes by sliding a clip along its bar where turning it on
  the bar would serve (4002020-1): the solver takes the slide. And the
  sweep's judge turns the moving side a degree on; such a stop wants the
  joint's own slide judged.
- A loop's room test may take 24 ms of a frame (`LOOP_BUDGET_MS`), which on a
  phone at 4x leaves too little for the rest of it in a big loop.
- G13b's other leftovers stand.

## 24. Steering still refused, a door's hinge, and the part taken (G14b)

G12 left five sets whose ball-jointed steering arms were refused at the
arm: 10265-1, 10295-1 and its 911 Turbo, 42021-1 and 41999-1. G11 left
6753-1's tow truck and 8074-1's grader, and G13b left 3180-1's cupboard
door. G14b traced each to how its joints are read. 41999-1 is mended, and
seventeen doors held by nothing now swing; 3180-1's is not one of them, as
its cupboard is on a part that moves. For the four ball-jointed sets the
cause is found and its fix was written, but it broke 8448-1's racer, and it
is taken out (below), as are three stud rules that freed the tow truck and
the grader.

**The base.** rel-m89 (71a32f72: live m88 and G13b), against G13b's own
sweeps: `sweep_after2` (56 of 168 steer) and `movesweep_g13b` (163 of 381
move both ways and back), copied as `sweep_g13b` and `movesweep_g13b`. The
tables are in bench/results/grab14b-2026-10-19. Each sweep ran from a copy
of the worktree, so edits made while it ran could not reach it.

**A pinion lodged where no hole names its axle** (`Bodies._driving_pinion`).
41999-1's steering pinion is on an axle through the big ball joint's socket
(92911), which names no hole there. Held by nothing, the pinion was lodged
in the socket. It was one body with the whole front axle (93 parts), which
hangs on a ball, and the steering was refused on that ball. A pinion
standing in another piece's rack now turns on its own axis where it is
lodged, as G11's rack slides where it rests.

**A door's hinge only BrickNet names** (`Bodies._labelled_hinge`). 3180-1's
cupboard door (4533) hangs on the cupboard (4532) by a pin at each end. The
file draws the door's pin and the cupboard's as rounds of one size, end to
end. No round reads that as one in a bore, and the door was held by
nothing: both have exact shapes, so it was not lodged either (G13). Their
labels in BrickNet name a hinge on each part, at one point and on one line.
A door, a hatch or a lid (Playable.door_named) held by nothing, where it
would be lodged in a part of its piece's biggest body (what stays) that
names that hinge with it, now hangs on the hinge (`Exact.meets`) instead
(`Bodies._stays`). 3180-1's cupboard is on the tanker's boom, a part that
moves, so its door is left as G13b left it. It was read wider first, and
each widening lost something: for every pair, 9397-1's universal joint gained its second
hinge and its steering loop grew to 44 joints, too many to solve; for any
part held by nothing, 6765-1's carriage tongue was hinged to its
turntable's base, and the turntable's turn moved the carriage; for a door
on any part, 10264-1's roller door, once its spool had turned, hung on the
spool; read before the studs, 6285-1's door, on one stud of its boom, also
hung on the ship and locked the boom; on any part it is lodged in, 21319-1's
door hung on a clip of the camera boom and swung with it into its frame.

**The part taken, named.** In a loop, move_part named everything the loop
moves by its biggest part ("the Technic Beam 13, 34 parts"). It now names
the body taken. So does the refusal of a part on a ball in a closed loop.

**The joints' ends under a lock** (`JointSnap.ends_of`). Bodies asks
whether a hole takes a stud on the worker that reads a big model's joints,
and on the main thread. With a stud rule tried below, it asked often enough
that the two filled JointSnap's cache at once and the app stopped (10265-1),
as Joints' did in G12. It is filled under a lock.

**Steering, swept** (`sweep_f8`, the final code merged with main, over the
79 files that steer or whose cause changed in a sweep of all 181 with the
rules taken out below, `sweep_f2`; merged over G13b's rows as
`sweep_g14b`).

| | sets that steer, of those with a steering |
|---|---|
| G13b (`sweep_g13b`) | 56 of 168 |
| G14b (`sweep_g14b`) | 57 of 168 |

Gained: 41999-1. Its rack goes 8.01 LDU each way, its arms 5.1°, and it
comes back to 0.0006 LDU; from above, both front wheels turn one way and
then the other (`pictures/steer_41999-1_*`). None lost. One other set's
cause changed: 8020-1's van, not back where it stood in G13b, is now
locked (its pinion's axle, read by the new pinion rule, and its rack close
neither way). In 34 of the 35 that steer at a pinion and have steering
arms, the arms turn with the rack (not 42125-1, as before). Four sets are
still refused on a ball, as G13b left them: 10265-1, 10295-1 and its 911
Turbo, and 42021-1.

**The other moving things, swept** (`movesweep_f5` over G13b's 260 sets;
`movesweep_f8`, the final code merged with main, over the 40 whose things
changed; merged as `movesweep_final`). The other 220 sets' rows are
`movesweep_f5`'s, run while the ball rules (taken out, below) were in, and
each is as it was in G13b.

| the same 260 sets | things | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|---|
| G13b | 381 | 163 | 15 | 300 | 221 / 19 / 170 |
| G14b | 405 | 183 | 15 | 324 | 227 / 19 / 172 |

By kind, both ways and back: turntables 53 (51), doors 56 (39), booms and
arms 74 (73). None that moved both ways and back in G13b is lost.
Twenty-four doors are on a joint now that were held by nothing (89, from
65), and seventeen of them move both ways and back: 6765-1's safe door and
10184-1, 10197-1, 10218-1, 10267-1, 3942-1, 41015-1, 60216-1, 6355-1,
6388-1, 6597-1, 6861-2, 6862-1, 6889-1, 6980-1, 6987-1 and 7741-1. Three
more things move both ways and back with main's Grab 14a merged in:
42043-1's flatbed trailer's turntable, and 6987-1's turntable and boom.

**The ball joints' reading, found and taken out.** §20 said the arm's ball
was on a rod hung only on balls. It was not: all three of a steering arm's
ball joints were read at one point. A joint's middle is the ball nearest
the other part's socket, and only socket connectors counted. 15459's and
32005's sockets are drawn as plain rounds, which Joints.balls has read
since G11 but the middle did not, so each joint fell back to the arm's
first ball, and the line through two of them had no length. Three rules
mended it: a ball paired with a socket of the other part, drawn either way
(`Bodies._ball_middle`); two balls between the same two bodies turning
them on the line through both, a kingpin, not a lock (10265-1's arms hang
on an upper and a lower ball of the chassis); and a ball in a socket drawn
as a bore anywhere along its line (42021-1's track rod and towball stand
2.0 LDU apart along it as built, and once turned, 2.001, and the track rod
lost its towball). With them no arm was refused on a ball, but none of the
four came to steer: 42021-1 turned 30° each way and came back 2.92 LDU off
(its lever hangs on one pin off its column's line, a freedom the loop
leaves idle); 10295-1 and its 911 Turbo turned 13° and 17° and stopped 11°
short on the way back (its loop of 46 joints takes in the front
suspension); 10265-1 and its B model were locked by their steering lever
(below). And `grab_probe`'s grooved check failed on 8448-1's racer: its
steering turned all 30° and its rack 5.33 LDU (rel-m89: 11° and 1.94),
then, read again where it stopped, its loop had two hinges more and was
locked, so the rack did not come back. Switched off one at a time, the
first rule turns the racer so; all three off, it moves as in rel-m89. All
three are taken out.

**Studs that hold nothing, tried and taken out.** Three rules about where a
stud holds freed 10265-1's steering lever, 6753-1's tow truck and 8074-1's
grader, and cost three moving things. A stud into a part on its side held
only in one of its holes: 10265-1's lever is a beam 3 on its edge with two
of a brick's studs against its side, and the beam's holes, read from below,
are sockets to the catalogue, so the studs held the lever to the chassis.
A stud into a part turned off the grid held only in one of its sockets or
holes: 8074-1's grader is drawn tipped 4.6°, and a brick's studs under a row
of tiles reached the cover of the plate on the tiles, which holds the rack.
And what rests on a joint's half held only by a stud in one of its sockets
or holes: turned, 10265-1's lever brought a towball pin's round side down on
the brick's studs. With them, and a rack slid off its tile's cells resting
on what its box touches, the steering sweep had 59 of 168 (`sweep_final`),
the grader and the tow truck among them. The moving sweep, a third of the
way through (`movesweep_f3`), had lost 75144-1's boom (back 0.088 LDU off,
a tile the first rule freed), 42080-1's turntable (0.325 off) and 10265-1's
B model's boom (locked). Switched off a rule or two at a time
(`movesweep_ab1` to `ab4`), the boom of 75144-1 came from the side rule,
10265-1's from the grid or resting rule, and 42080-1's from more than one.
All four were taken out. The tow truck's rack, once slid, is held from its
side by a stud; without the side rule the rest rule did not help.

**A loop's leftover freedom, tried and taken out.** Two ways of keeping it
where it was, for 42021-1 and 10295-1. A settle at the end of each move,
drawing every coordinate back towards where the move began (1e-3 against
JᵀJ), left 42021-1 4.3 LDU off, worse than without. Holding the joints that
friction holds first, freeing them only where the loop cannot close
without them, left 10295-1 as it was and stopped 10265-1 at once one way.

**Proved** (bench/results/grab14b-2026-10-19). Every sweep ran from a copy
of the worktree, or from the worktree untouched while it ran, two shards
under heavy. `grab_probe` in full through `tools/probe.sh` on the final
code merged with main (`probes/grab_probe_merged.log`) ran 466 checks, and
all passed. New: `-- --only=swept` steers 41999-1 the sweep's way, +8.01
LDU, -8.01 and back to 0.0006; `-- --only=moving` swings 6765-1's safe door
both ways and back. Each fails on rel-m89's code, as its sweep row there
shows (41999-1 refused on a ball, 6765-1 with no door on a joint). The
path checks and the two beams checks looked for "now 30°" in move_part's
words, which say "turned 30°" since MCP walk 2, and failed on rel-m89 too
(`--only=path` run alone on its code); Grab 14a mended them, and G14b the
same way. Before the merge (`probes/grab_probe_final.log`) all 466 passed
too; a run with the ball rules in (`probes/grab_probe_full.log`) passed 462
of 467: those four, and 8448-1's racer (above).

**Left for later.**
- The ball joints' reading (above): the cause of the five refusals, its
  three rules written and taken out. 8448-1's racer, which they turn
  further and then lock, is the case to start from; then a loop's leftover
  freedom (42021-1's lever, 10295-1's suspension).
- Where a stud holds, with the three cases that broke the rules tried:
  75144-1's boom (a tile held only by a stud against its side), 42080-1's
  turntable and 10265-1's B model's boom. 6753-1's tow truck: once slid,
  its rack's brick is held from its side by a stud. 8074-1's grader: a
  stud reaching the cover of a part off the grid holds it. 6753-1 itself:
  a brick's studs hold its steering's axle 6, an axle read with sockets
  from below.
- 3180-1's cupboard door, and any door held by nothing on a part that
  moves: hung on it, 21319-1's door went with the camera boom into its
  frame. A door belongs on the part that carries its hinge's other half;
  which part that is wants more than BrickNet's label where both move.
- A 2 x 2 turntable under a wheel plate, held by the plate's studs (not
  begun).
- 42110-1 and the loops too big to solve.

## 25. A loop's own joints, and keeping a move (Grab 15)

G14a left two things. 21019-1's turntable went through a clip: its first
turn moves 267 parts as a loop of 11 joints, nothing tests a joint's own
two parts against each other, and the turn left a plate with a handle
(#86) 2.42 LDU into the plate with a clip on that handle (#124); the next
grab began with them into each other, forgave them, and went 60° through.
Testing a loop's joint pairs every frame mended it and tripled 8808-1's
room test a frame. And keeping a move cost most of the 100 ms a keep may
take: grab_flow's flywheel 89.8 to 92 ms on quiet previews, 119 at load 20,
and 7191-1's big section's keeping frame, which G13b and G14a traced to
`Grab.commit`.

**The base.** f6db180c (live m98: G14a and G14b in), against G14b's own
sweeps: `movesweep_final` (183 of 405 things move both ways and back) and
`sweep_g14b` (57 of 168 sets steer), copied with the lists of their sets
into bench/results/grab15-2026-10-19 as `movesweep_g14b` and `sweep_g14b`.
Each sweep ran from a copy of the worktree, one shard under heavy.

### Where a keep's time went

Timed part by part inside `Grab.commit` (natively, `grab_probe -- --only=coast`
and `--only=big`):

- **The coasted flywheel** (a gear 40 and its axle, kept where they came to
  rest): 59.9 ms, of which 57.4 the gear's turned cover. A part kept at a
  new turn has no cover kept for it, and `BrickLattice.boxes_for_turned`
  worked one out cell by cell: `cells_for_turned` found each line's cells,
  put each in a dictionary and a list, and `compress` sorted them back into
  runs along x. The gear's cover is 300 boxes, its turned cells 12,935.
- **7191-1's big section** (132 parts on an axle, 60,514 boxes of cover):
  the keeping frame 107 ms, the commit 87. Its cells were worked out on a
  worker before the keep, but putting them in still worked out each
  cover's bound (24 ms) and its rows (34 ms), and taking the old ones out
  spent 20 ms on nothing: `_bounds.get(brick_id, _bound_of(packed))` works
  the default out whether it is wanted or not, so every part's old cover was
  gone over box by box. Its buckets, in and out, were 5 ms.

**A turned cover a line at a time** (`BrickLattice.boxes_for_turned`,
`_runs_of_box`, `_slabs_of`). For each box, each line of cells along x
within its reach gets its run from the fifteen slabs of the separating axis
test, each axis once a turn (a turn about one line gives several twice), and
a slab with no x says which lines of a row are touched at all. A cell within
0.01 of touching is asked exactly, as `cells_for_turned` asks it, and where
an axis was taken for a twin that leans from it by a rounding or a hair's
turn, the band grows by how far that lean can move a slab over the box. The
runs of a line from several boxes are joined where they meet, and the lines
are taken in the order `compress` met them, so the boxes come out the same
and in the same order. `turned_probe` holds it to `compress(cells_for_turned)`
over 486 turns of real parts (90 from the catalogue at random with the
flywheel's and a few joints' parts; about the vertical, about x, at random,
by a hundredth to a third of a degree, and off the origin): the same boxes
in the same order on all 486, 29.2 s cell by cell against 6.9 s.

**A big section's covers ready to put in** (`BrickLattice.cover_for`,
`occupy_moved`). The worker that works out a big section's cells now works
out each cover's bound and rows too, as `occupy_boxes` would, and the keep
puts them in as they are. And `release` asks for the bound it keeps before
working one out.

| the keep | before (f6db180c) | Grab 15 |
|---|---|---|
| grab_flow's flywheel, in a browser (SwiftShader, local server, the two builds in turn) | 151.8, 94.5, 91.1 ms (load 18, 11, 15) | 29.6, 31.3, 34.2 ms (load 19, 14, 15) |
| grab_flow's pendulum | 26.7, 14.8, 21.6 ms | 11.9, 16.0, 18.3 ms |
| the coasted flywheel, natively (`grab_probe -- --only=coast`, the flywheel, the train, the flywheel across a slow frame) | 59.9 and 53.5 ms (57.4 and 51.4 their covers) | 14.8, 17.7, 14.8 ms |
| 7191-1's big section's keeping frame, natively | 100 to 107 ms (commit 81 to 87) | 18, 18, 19 ms (commit 5 to 7) |

### A loop's joints test their own parts

`Grab._meeting_pairs`, at the press: each pair of parts that makes one of the
loop's joints (`Bodies.Link.pairs`, of `Linkage.links` and its closing
joints), where the two can meet as the joint turns. Not where either is a
pin, an axle or a round part on the joint's line (`_thin_on`, `_round_on`),
which turns in place; not where a plane square to the line keeps them apart
further than the joint slides (a beam on a beam, by their boxes' reach along
the line). And only a hinge's, a click hinge's or a turntable's (`PAIR_KINDS`).

`Grab._pair_clear_at`, in every room test of a loop after its moving parts:
the joint's turn about its line and slide along it, read from where the two
stand, and the pair asked by their exact shapes only where those are past
what was already found clear, which then grows to take them in. Where the
two were into each other as the grab began, or one has no exact shape, the
pair is forgiven, as the rest of the room test forgives such a pair; that is
asked when the pair is first tested, not at the press. A test cut short by
its budget goes on from the pair it reached, and a pair whose last test
would take the frame past its budget waits for the next.

**21019-1.** The loop does not turn the clip on its handle so much as slide
it: the joint is a clip on a bar, which `_slide_on` lets slide half a stud
each way, and the loop closed by sliding the clip 4.3 LDU along the handle's
bar into the plate the handle is on, turned 0.03°. Now the turntable turns
+0.3° and -1° before the clip's plate meets the handle's plate (judged real
a degree on, 1.77 LDU, the sweep's judge) and comes back to 0.0004 LDU. The
moving sweep's row, and `grab_probe -- --only=moving`, which now moves it too.
G13 found the build holds this turntable, so a turn of a degree is what the
model allows.

**Only hinges, clips and turntables.** Tested at every joint, an axle's or a
pin's too, the steering sweep (`old_code/sweep_g15allkinds`) lost no set
that steered, but 16 steered less far before they stopped: 8448-1's racer
and its four other models 1° where they steered 11°, 5533-1 2° where 10°,
8049-1 7° where 30°, 4896-1, 7347-1 and 9394-1 alike. In the two taken
apart, a towball slid along its axle into its rack (8448-1) and a steering
arm along its axle into the brick it is in (5533-1), 1 to 2 LDU: an axle's
slide is read as far as the axle reaches, not as far as a flange lets it,
and a loop whose other joints are read loosely closes by those slides.
Those pairs are left out (below, the sets again).

**A loop's drag leaves the pairs to its pause.** Asked in every frame of a
drag, the six pairs of 8808-1's steering (its two arms each through two
plates' holes, `4261` in `4262`) took the room test from 0.5 ms a frame to
5 to 10 natively. A loop's drag already tests only where the pointer is, a
frame, and its way on a pause or the release (G13b); its joints' pairs go
with the way (`_test`'s `pairs`, from `turn_to` and `slide_to`).

| 8808-1's steering dragged 3° a frame to its stop and back (`room_cost_probe.gd`, natively) | before | Grab 15 |
|---|---|---|
| room tests a frame, mean | 0.54 ms | 0.40 ms |
| at worst (the frame that meets the stop and reads the brick's shape) | 10.8 ms | 5.9 ms |
| a pause's check of the way | 0.3 to 0.5 ms | 5.3 to 10.4 ms |
| the press | 6 to 10 ms | 6 to 10 ms |
| where it stops | ±108° | ±108° |

play_flow, the two builds served side by side and run in turn, 8808-1's
steering turned by a finger into its stop at 390 x 844, the CPU slowed four
times (the app's own work in a drag frame):

| | worst frame | its room tests | mean frame |
|---|---|---|---|
| before (m98), 4 runs, load 15 to 28 | 13.6, 22.2, 18.9, 12.1 ms | 11.0, 12.8, 14.2, 8.4 ms | 5.9 to 9.8 ms |
| Grab 15, 4 runs, load 12 to 24 | 19.0, 29.2, 16.2, 22.8 ms | 13.6, 14.0, 10.2, 15.9 ms | 7.6 to 9.9 ms |

The room tests are the same work frame for frame (natively, above); in the
browser the two overlap, and Grab 15's sit a little higher, which more runs
than four a side would be needed to call. Every run passed. By the mouse at
1280 x 800, the worst frame 2.1 to 3.0 ms against 1.9 to 5.2.

What a pause checks is said now (`GrabDrag.worst_pause_ms`, play_flow): on
Grab 15, 27.4 to 28.1 ms by the mouse; slowed four times, 36.6 and 46.5 ms
before a pair's test waited for a frame with the budget for it, 39.8 and
38.6 after. The build before has no such number to set beside it; natively
its pause took 0.3 to 0.5 ms (above).

**Steering, swept** (`sweep_g15final`: `old_code/sweep_g15allkinds`, every
joint's pairs tested, over the 181 files, with the 23 whose turns differed
from G14b's run again on the final code, `sweep_g15rerun`).

| | sets that steer, of those with a steering |
|---|---|
| G14b (`sweep_g14b`) | 57 of 168 |
| Grab 15 (`sweep_g15final`) | 60 of 168 |

None lost. Gained: 8256-1, its lawn mower and 8854-1, which G14a's turn on a
loop that goes where it asks brought back within 0.005 LDU (G14b's rows
were run before main's G14a was merged). Of the 23 run again, 20 turn as in
G14b's row to the degree and the hundredth of an LDU of rack; 42000-1's
last turn, back, stops where it did not, and it did not steer either way.

**The other moving things, swept** (`movesweep_g15`: G14b's 260 sets, one
shard for the 89 biggest, `movesweep_g15_0`, on 8aebef66, before a pair's
test waited for a frame's budget, which a session's turn does not have, and
two shards for the rest on the final code, `movesweep_g15rest`; the first
run, every joint's pairs tested, was stopped a third of the way, kept as
`old_code/movesweep_g15allkinds_0`; 42043-1's flatbed trailer timed out
there, at 300 s, and its row is its run alone, `movesweep_g15flatbed`, 244
s at load 10, where G14b's took 264).

| the same 260 sets | things | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|---|
| G14b | 405 | 183 | 15 | 324 | 227 / 19 / 172 |
| Grab 15 | 405 | 186 | 18 | 325 | 228 / 20 / 170 |

None that moved both ways and back in G14b is lost. 21019-1's turntable
moves to its stop: +0.3° and -1°, the clip's plate meeting the handle's
(judged real), and back to 0.0004 LDU, where G14b's was back 15.7 LDU off.
42080-1's boom and 8448-1's boom move both ways and back now, and 952-1's
turntable and 7991-1's boom to their stops, each having come back 0.06 to
0.78 LDU off in G14b's rows, which were run before main's G14a (a loop's
turn goes where it asks) was merged: G14a's own sweep found all four so.
10283-1's boom is another part (#429, not #475) and moves both ways and
back; G14b's was locked.

**One thing lost against main.** 4002020-1's turntable turns +5° as
before, and then, on the way back, stops at once where a clip (#849) meets
the bar with a ball end it holds (#863), a pair of the loop's hinges. G14a's
sweep, with main's loop turn, had it turn -10° to where a steering link
meets a brick and come back, both ways and back; G14b's row, run before
that was merged, came back 0.025 LDU off, so against G14b's count it is not
lost, but against main it is. The loop slides the clip along its bar into
the ball end to close, as 21019-1's slid its clip into the handle's plate;
the shapes say both meet, and the loop takes the slide where a turn of the
clip on its bar may have served. The judge calls the stop covers only: it
turns the moving side a degree on, and a turn does not slide the clip.

**Proved** (bench/results/grab15-2026-10-19/`probes/`). `grab_probe`
windowed through `tools/probe.sh`, in full, on the final code
(`grab_probe_final.log`, and before a pair's test waited for a frame's
budget, `grab_probe_full.log`): 468 checks, all passed both times; it now
says the coast's keep (14.8 ms natively); new, `-- --only=moving`
moves 21019-1's turntable +0°, -1° and back to 0.000 LDU, no turn stopped
on covers only (on f6db180c it is back 15.7 LDU off, its sweep row). Its
big case kept 7191-1's section in an 18 and a 19 ms frame (5 the commit,
10 and 11 what an edit sets going). `turned_probe` (486 real turns the same boxes in the same
order). grab_flow, both builds three times each in turn (above): every check
passed on Grab 15, and m98's first run failed the keep (151.8 ms against
100). play_flow, four runs a side, all passed. The frames gate
(`tools/web/cad_frames.mjs --gate`, 75969-1, the local server, load 14):
an orbit's frames at the 95th percentile 28.9 ms against 200, select all
45.5 against 400, the timeline's Next 9.1 to 12.8 against 200; passed.
`snap_probe` and `snot_probe`, the lattice's own (`featuremap affected`),
pass.

**What got worse.**
- A pause in a loop's drag, and a session's turn of a loop, now test its
  joints' pairs: natively 8808-1's pause 0.3 to 0.5 ms became 5 to 10, and
  on a phone at a quarter speed 37 to 46 ms (play_flow, said), the budget
  of 24 ms plus a pair's test begun inside it. A pair is not begun now where
  its last test would pass the budget, unless it is the first a frame asks.
- In the browser the drag frames of 8808-1 on a slowed phone sat a little
  higher (above); natively they are the same.
- 4002020-1's turntable no longer moves both ways and back (G14a's sweep
  had it): on the way back it stops at once, where the loop slid a clip
  along its bar into the bar's ball end (above).

**Left for later.**
- An axle's or a pin's own parts in a loop: a loop closes by sliding them
  along their holes as far as the reading lets, into flanges and faces
  (8448-1's towball into its rack, 5533-1's steering arm into its brick).
  The slide wants reading as far as the parts let it, not the axle's
  length, before those pairs can be tested.
- A pair that cannot meet by its parts' shapes is still tested where its
  parts' boxes reach past each other along the line: 8808-1's steering arms,
  whose kingpins go through two plates each. Their pieces read about the
  joint's line (how far out each reaches, at what height) would leave them.
- A loop that closes by sliding a clip along its bar where turning it on
  the bar would serve (4002020-1): the solver takes the slide. And the
  sweep's judge turns the moving side a degree on; such a stop wants the
  joint's own slide judged.
- A loop's room test may take 24 ms of a frame (`LOOP_BUDGET_MS`), which on
  a phone at a quarter speed is more than a frame (G14a); its pauses now
  fill it.
- The ball joint's drag, and G14b's and G13b's other leftovers, stand.


## 26. Slides in loops, and the pause (Grab 16)

Grab 15 left a loop sliding a clip along its bar where the real part cannot:
21019-1's slid its clip 4.3 LDU into the plate its handle is on, and
4002020-1's slid its clip into its bar's ball end, so since Grab 15 that
turntable stopped at once on its way back (G14a had it moving both ways).
It left the axle and pin pairs out of the joint-pair test, since a loop
closed by sliding axles into flanges, and a pause in a loop's drag took a
phone 37 to 46 ms, its joints' pairs asked there.

**The base.** 2189419d (live main, m101: Grab 15 in), against Grab 15's own
sweeps: `movesweep_g15` (186 of 405 things move both ways and back) and
`sweep_g15final` (60 of 168 sets steer), in bench/results/grab15-2026-10-19.
Each sweep ran from a copy of the worktree, two shards under heavy. Every
experiment is kept in bench/results/grab16-2026-10-19/`exp/`.

### A slide as far as its parts let it

A loop's solve had no end to a slide on a joint that turns as well: a clip
on its bar, an axle in a round hole. Only an actuator's stroke was checked.
And the reading the slide came from let a clip's bore go until its middle
reached the end of every round on the bar's line, and a hole until its
middle reached the end of the axle's part, a towball's ball and all.

**By the parts' rounds** (`Bodies._rounds_room`). Each of the two parts is
read along the joint's line from its connectors: its rounds (shafts, with
their radius) and its bores. At each place along the line a part is solid
from its widest bore out to its widest round (all the way out round a bore
with no round over it); past the shaft part's last round, where the part
goes on further than an axle's chamfer (2.5 LDU), it is solid all through:
a towball's ball, a bar's ball end, the plate a handle is on. Two parts may
not slide into a place where both are solid at one radius, a pin's end
ridge (6.5 across) in its hole (6) spared, and what is so where they stand
is forgiven. Read so:

| joint | the reading before | by its rounds |
|---|---|---|
| 4002020-1's clip (4081b, a bore 16 long) on its bar with a ball end (22484) | 10 LDU each way | 2 towards the ball, 10 towards the free end |
| 21019-1's clip (61252, a bore 8 long) on its handle (60478: 8 LDU of bar between two supports 6 across) | 10 each way | none: the clip fills the bar, so it does not slide |
| 8448-1's rack (32185) on its towball (2736) | 14 down, 23 up through the flange and the ball | 14 down, none up: the flange sits in the rack's counterbore |
| 5533-1's steering arm (32069), its pin in a brick (2743) | 50 in, 10 out | none in (the pin's collar), 10 out |

**Held there as the loop is solved** (`Linkage._bounded`, `_close_with`). A
clip's slide is kept inside its range: a step that would take
it past an end stops at the end, and one standing at an end that the step
would take further out is held there for that step while the rest is
solved again without it. Where the two parts' exact shapes are at hand the
range is theirs (`Bodies.exact_room`: bisected to where they first meet,
within the bore's middle on its bar); else the rounds'. 4002020-1's clip
goes 6.37 LDU towards the ball by its shapes, where its rounds said 2: the
bar narrows to a neck before its ball (`exp/exact_room.gd`; Grab 15's loop
had slid it 6.27 LDU on the way out, and on the way back on into the
ball). Read with its shapes from disk, its first grab takes 31 ms more
natively; a browser that has not fetched them yet holds the clip by its
rounds.

**4002020-1**, its turntable moved +30, -60 and back as the sweep moves it
(the loop: 15 joints, 1 turntable, 8 axle, 4 hinge and 2 ball, closed by
4):

| the clip's slide held | +30 | -60 | back |
|---|---|---|---|
| not at all (Grab 15; `exp/movesweep_t2none`) | +5, its covers meet | 0: the clip at once into its bar's ball end | |
| by its rounds, and every axle's too (`exp/movesweep_t1`) | +17 | -46 | 2° short: the steering link meets a slope brick on the way |
| by its rounds, axles free (`exp/movesweep_t2clips`) | +16 | -5 | 2° short: the bar meets the slope brick |
| by its exact shapes (`movesweep_g16`) | +13, its covers meet | -44, the real parts meet | back to 0.0001 LDU |

Held at 2 LDU, the loop took its turn elsewhere and did not come back the
same way: a loop with freedom left over (G14b) goes out by one path and back
by another. Held where the clip truly meets the ball, it does. G14a had it
turning +5° and -10° with the clip sliding into the ball.

**21019-1** is locked: its clip fills its handle's bar, so nothing in its
loop of 11 joints (4 turntable, 7 hinge) slides, and the loop closes
neither a degree one way nor the other ("Locked: this loop has no
freedom"). Grab 15 turned it +0.3° and -1° by sliding the clip, before the
clip's plate met the handle's (judged real); G13 found the build holds this
turntable. The sweep counts it to its stop no longer; `--only=clipped`
holds that it is locked and that the clip never ends into the handle's
plate.

**An axle's slide is read so too, and not held in a loop.** Held to its
flanges (`exp/sweep_t3bound`, 21 files: the sets Grab 15 named and others),
8448-1 and its four other models turned 0.1° each way where Grab 15 turned
7.2°, the loop closing no further without its towballs sliding up through
the rack; 8256-1 and its lawn mower turned as before and came back 0.057
and 0.053 LDU off, and no longer steered. With the axle and pin pairs tested
as well (`exp/sweep_t3pairs`) 8256-1 steered, but 2.4° where it steered
11.5°. So the axle and pin pairs stay out of the test, and the slide an
axle's rounds allow is what a single joint's slide goes by (`Grab._range`).
Nor is an engine's piston held: kept to its cylinder's rounds, 8218-1's
stroke was 19.35 LDU where its crank's throw makes it 20 (`grab_probe`'s
crank and piston), and its crank holds it.

### The pause

A pause in a loop's drag checks its way (`Grab.verify_step`) a frame's share
at a time. It had the loop's 24 ms, and the loop's joints' pairs are asked
there (Grab 15); the part or pair begun last could take as long again.

- **4 ms a frame** (`GrabDrag.PAUSE_BUDGET_MS`, `Grab.pause_budget_ms`), the
  rest in the frames after, from the part and the pair it reached. The
  first part and the first pair a call asks are always tested, so a pause
  whose solve took its share still goes on (`Grab._test`).
- **Pairs that cannot meet are not asked** (`Grab._about_line`,
  `_pieces_apart`). A turn about a joint's line keeps each point's place
  along it and its distance from it. Each piece of each part is read so:
  how far along the line it reaches and how near and far from it (the
  nearest edge of its outline seen along the line). Two parts none of whose
  pieces share a place, slid as far as the joint slides, cannot meet as it
  turns: a quarter LDU each way is spared, a quarter of what a build
  allows. 8808-1's six pairs are all so: where each plate is along a
  kingpin's line, only the kingpin is, narrower than the hole. Each part is
  read only where the other reaches along the line (the arm's 176 pieces
  to 73 and 56), and the verdict is kept for the next grab.

8808-1's steering dragged 3° a frame to its stop, pausing every 8 frames
(`native/room_cost_probe.gd`, natively):

| | Grab 15 | Grab 16 |
|---|---|---|
| a pause's check of the way | 5.3 to 10.4 ms | 0.25 to 0.94 ms; the first of a grab 3 frames, at worst 5.3 ms (3.5 of it reading the two shapes from disk) |
| where it stops | ±108° | ±108° |

play_flow, the two builds served side by side and run in turn, 8808-1's
steering turned into its stop by the mouse at 1280 x 800, and by a finger
at 390 x 844 with the CPU slowed four times (`web/play_flow_*.log`; the
first two Grab 16 runs, at 8 ms and before the pairs' reading was made
cheaper, gave 11 to 12 and 24 to 34 ms):

| the pause's worst frame | by the mouse | slowed four times |
|---|---|---|
| m101 (2189419d), 4 runs, load 3 to 15 | 24.1, 24.6, 24.3, 24.6 ms | 34.7, 42.3, 35.6, 39.3 ms |
| Grab 16, 2 runs, load 3 and 11 | 7.2, 5.6 ms | 18.8, 22.9 ms |

The drag's own frames are as they were: slowed four times, 6.7 and 7.1 ms
a frame on average and 15.4 and 15.6 at worst (m101: 7.2 and 6.9, 15.6 and
16.8). Every run passed its 34 checks.

### Swept

**The other moving things** (`movesweep_g16final`: `movesweep_g16`, Grab
16's 260 sets on d9e7f718, two shards, merged with `movesweep_g16p`, the 37
of them with an engine's piston run again once a piston's slide was let go
free, on 6a79564f; each of the 37 as in Grab 15's row both times).

| the same 260 sets | things | both ways and back | to its stop | turn at all | steps met: real / covers only / not judged |
|---|---|---|---|---|---|
| Grab 15 (`movesweep_g15`) | 405 | 186 | 18 | 325 | 228 / 20 / 170 |
| Grab 16 (`movesweep_g16final`) | 405 | 187 | 17 | 324 | 227 / 19 / 170 |

Gained: 4002020-1's turntable, +13°, -44° and back to 0.0001 LDU. Changed:
21019-1's turntable, to its stop in Grab 15 (+0°, -1°, judged real), is
locked, and its boom, which did not move, is locked too. Every other thing
of the 405 has Grab 15's cause.

**Steering** (`sweep_g16final`: `sweep_g16`, the 181 files on d9e7f718, two
shards, merged with `sweep_g16p`, the 80 with an engine's piston run again
on 6a79564f).

| | sets that steer, of those with a steering |
|---|---|
| Grab 15 (`sweep_g15final`) | 60 of 168 |
| Grab 16 (`sweep_g16final`) | 60 of 168 |

Every one of the 181 turns its arms and its rack as in Grab 15's row, to the
hundredth. In the first run, with a piston's slide held, 8868-1 (which steers
in neither) moved its rack 0.03 LDU where it had not; let go, as before.

**Proved** (bench/results/grab16-2026-10-19). `grab_probe` windowed through
`tools/probe.sh`, in full, on the final code (`probes/grab_probe_final.log`):
470 checks, all passed. New, `-- --only=clipped`: 4002020-1's turntable
turns +13°, -44° and is back to 0.0001 LDU, and 21019-1's is locked; in
neither does the clip end into its bar's part by their exact shapes. On
Grab 15's code the first would fail (+5° and 0°, its sweep row) and so would
the second (+0° and -1°, neither locked nor turning a degree each way). The
run before a piston's slide was let go (`probes/grab_probe_g16.log`) passed
468 of 470: the crank and piston's two (above); `-- --only=loops` then
passed all 13 (`probes/grab_probe_loops.log`). The keeps are as Grab 15
left them: the coasted flywheel's 16.0, 18.0 and 16.5 ms, 7191-1's big
section's keeping frame 20 ms (6 the commit). play_flow,
two runs a side on the final builds served side by side (above): 34 checks
passed in every run. The frames gate (`tools/web/cad_frames.mjs --gate`,
75969-1, the local server, load 11): an orbit's frames at the 95th
percentile 17.9 ms against 200, select all 32.2 against 400, the timeline's
Next 9.4 to 18.3 against 200; passed (`web/frames_g16.log`). Neither an
orbit nor select all runs a room test. The experiments are kept in `exp/`
with the scratch probes that read the joints (`native/inspect_links.gd`),
time the pieces' reading (`native/foot_cost.gd`) and a clip's room
(`exp/exact_room.gd`).

**What got worse.**
- 21019-1's turntable moved +0.3° and -1° to where its clip's plate met
  the handle's; it is locked now. Its clip fills its handle's bar, so its
  loop has nothing to close by; the turn it had came from the clip sliding.
- The first grab of a loop with a clip reads both parts' exact shapes at the
  press (31 ms natively for 4002020-1's, most of it reading them from disk);
  a later grab finds them kept.
- A pause's check of a loop takes more frames: 4 ms of each, where it had
  24.

**Left for later.**
- An axle's slide in a loop: held to its flanges, 8448-1's steering closes
  0.1° and 8256-1's comes back 0.05 LDU off. 8448-1's loop closes only by
  sliding a towball up through its rack; how its ball joints are read
  (G14b's left for later) is where to look. Until then the axle and pin
  pairs stay out of the joint-pair test.
- A clip slides no further than what is drawn on its own bar; another part
  on the same bar (a second clip) is left to the room test.
- A loop with freedom left over goes out by one path and back by another
  (4002020-1 with its clip held at 2 LDU); held where the parts truly meet,
  it came back.
- In a browser, a loop grabbed before its clip's and bar's shapes have come
  holds the clip by its rounds (4002020-1's: 2 LDU, not 6.37).
- A part or a pair begun last in a pause's frame still runs to its end: on
  the slowed phone the pause's frame was 18.8 and 22.9 ms against its 4.
- G15's other leftovers stand.

## 27. A session's telescope, and Simulate turned as Grab turns (mechverify)

A Claude session building the owner a telescope that tilts and extends
told them, over MCP:

> The extension wheel won't move the telescope in Brickworks. The simulator
> doesn't model gears on racks, so turning that wheel only spins the small
> gear. To try the extension in the app, drag the telescope tube itself; it
> slides along its rod. I first built a crank-and-rod version that the app
> could in theory drive, but it seized up in the simulation, so I switched to
> the rack... On real bricks, tilting forward also nudges the tube out about
> 0.4 stud, because the small gear is held still while the tilt rolls the
> rack along it... Friction pins in the gear chains should stop the
> telescope drooping when you let go.

Each claim was tried on small rigs of real parts, opened as a session opens
a saved model, in Simulate (`Simulation`, Tools, Simulate mechanism, and
`simulate_mechanism`), in Grab (a drag, `GrabDrag.Turning`, as a person's
drag and `animate_model` turn a part) and over MCP (`move_part`). The probe
is `src/dev/telescope_probe.gd`; its rigs are in `src/dev/fixtures/`. Its
runs before (cde834b2) and after, and the pictures, are in
`bench/results/mechverify-2026-10-20/`.

| rig | what it is |
|---|---|
| `rack_wheel.ldr` | a wheel (4185a) on an axle with an 8, meshing a 24 whose axle carries an 8 tooth pinion in a 1 x 4 rack (3743) on a tube (3700 and a 2 x 6 plate) that slides on a 12L axle fixed in two bricks with axle holes |
| `crank_slider.ldr` | the same tube on its rod, pinned (3673) to a 5L beam whose other end is on a crank (41677, an axle pin 3749) a stud from its axle, turned by a wheel |
| `tilt_cradle.ldr` | a cradle (a 4 x 12 plate, the rod's two bricks, a hanger with a round hole) hung on the pinion's own axle, carrying the tube; the pinion's chain to the wheel is 16-16-16 through a clutch gear (6542b) on a friction pin (2780) |
| `telescope.mpd` | the owner's shape as their Claude described it: the same, the cradle also keyed to a tilt axle on the same line, which a tilt wheel turns through its own 16-16-16 chain with a friction pin; sub-assemblies Stand, Extension wheel, Tilt wheel, Cradle, Tube |
| `friction_arms.ldr` | two 13L beams, one on a friction pin (2780), one on a plain pin (3673), each in a brick 4 bricks up |

An 8 tooth pinion moves its rack 8 teeth a turn, 8 LDU each (section 12):
64 LDU, 3.2 studs.

### The claims

| the claim | Simulate before | Simulate now | Grab and `move_part` |
|---|---|---|---|
| 1. The extension wheel cannot move the tube; turning it only spins the small gear | **True.** `rack_wheel`: a turn of the wheel moves the tube 0.000 LDU, and it is called "Free (nothing decides how fast it turns...). Mesh it with a gear that turns" though it is meshed. The telescope's tube likewise. | False. 21.328 LDU a turn ("slides 1.1 studs along its line for each turn"); the teeth say 64/3 = 21.333. The telescope's 3.2 studs a turn, 16.002 LDU a quarter. | **False.** 21.333 a turn, exactly, on a fixed rod; `move_part degrees=360` the same. On the telescope a quarter turn tilted the cradle 45° and slid the tube 8 LDU of 16 before; now the cradle stays (0.00°) and the tube slides 15.997. |
| 2. Drag the tube itself; it slides along its rod | (Simulate turns only) | | **True.** It slides; drawn 10 LDU, its rack turned the pinion but not the train beyond it, the wheel 0.00° where the teeth say 168.75°. Now 168.69°. |
| 3. A crank-and-rod version seized up in the simulation | **True.** At dead centre the rod spins round, 0.25 turns for each turn of the crank, and the slider stays; off dead centre: "LOCKED: it cannot turn — the meshes ask for two different speeds at once. The ones that fight: none alone; several together. Take one of those gears off". There are no gears. | False. "a loop of 4 joints (2 axle, 2 pin), closed by 1": the slider "goes 2 studs back and forth" (40.000 LDU, twice the 20 LDU throw), the rod "rocks 14° either way" (asin 20/80 = 14.48°). | **False.** It strokes 40.000 LDU. Let go, it swings under its weight: no joint in it holds by friction. |
| 4. Tilting nudges the tube about 0.4 stud: the pinion held still, the tilt rolls the rack along it | **False.** 0.000: the tube goes round with the cradle. | True. 7.999 LDU for a 45° tilt. | **True.** 64 LDU x 45/360 = 8 LDU, 0.4 stud, for a 45° tilt with an 8 (0.2 stud at 22.5°). `tilt_cradle`: 7.992. The telescope was 3.998 from its cradle (the extension chain turned half) and 0.000 from its tilt wheel (the tube carried as if fixed); now 7.999 and 7.995. |
| 5. Friction pins in the gear chains stop the droop when let go | (no weight in Simulate) | (no weight) | **True, and for the telescope only now.** The beam on a friction pin holds at 30.0°; on a plain pin it swings to -18.5°, where it meets the model. The telescope tilted by its cradle and let go drooped before: "the loop turned 62° under its own weight: no joint in it holds by friction", its chains read out of its loop; now it holds at 45°, as from its tilt wheel. |

![rack_wheel in Simulate before and now, 1.5 turns of the wheel in](mechanisms/rack_wheel_simulate_before_after.webp)

![crank_slider in Simulate before and now, the crank at 120°](mechanisms/crank_slider_simulate_before_after.webp)

On real bricks claim 4 is the geometry above, and claim 5 is likely but
unmeasured: the cradle and tube (24.1 g, their centre 16.1 mm across the
tilt line at 45°) pull 0.38 N·cm about it, through a 1:1 chain onto a
friction pin, whose hold is unpublished (section 4: 0.5 to 1 N·cm, a
placeholder). A gear reduction in the tilt chain (a worm) would make it
certain.

### What was fixed

None changes the interface. Each is a check of `telescope_probe` that
fails on cde834b2: 15 fail there, none here.

1. **Simulate turns a loop as a drag turns it** (`Simulation._take_hold`,
   `hold_with`; the panel and `simulate_mechanism` through
   `SimulatePanel._held`). The driver is taken hold of as Grab takes it,
   through Simulate's own gear reading (`Grab.shared_mechanism`, its ground
   Simulate's base), on the driver's own line. Where that closes a loop
   (a pinion's rack, a crank's rod and slider) and the loop moves what the
   gear reading cannot, or the gear reading is locked, every pose drawn,
   weighed and recorded is Grab's (`_grab_pose`, the loop followed in
   steps of half a radian, `_walk_loop`), and every rate is read off them
   over a turn (`_read_loop`): a gear turns as many times as it goes round
   in one, a rack slides on, a slider goes back and forth, a rod rocks
   (`travels`, said in the readout: "slides 1.1 studs along its line for
   each turn of", "goes 2 studs back and forth", "rocks 14° either way").
   A gear train keeps the gear reading's poses, which a drag turns by the
   same rates: the orrery's eight periods are as section 9 has them, and
   every part of it stands where it did in every frame (to 0.00000 LDU);
   `simulate_probe` passes as before.
2. **A gear chain held by friction stays while a free joint can move**
   (`Linkage._friction`, `FRICTION_WEIGHT`). Where a loop has more freedom
   than its driver takes up, least squares shared the motion between every
   joint alike: the telescope's cradle, tilted 45°, turned its extension
   chain half way (its idler on a friction pin) and slid the tube 3.998 LDU
   of 8. Each step now damps a bearing of the loop's gear chains that holds
   by friction a thousand times as hard, so it moves least: 7.999. Only a
   gear chain's: with every hinge held so, 8808-1's and 8054-1's steerings
   slid their columns along their axles off their racks, and came back 12
   and 13.6 LDU off. A loop with no freedom to spare closes where it did.
3. **A drawn rack turns its pinion's train** (`Grab._train_of_pinions`).
   A loop held by a pinion in a rack was offered no meshes from the rack's
   side, so the pinion turned and its train stood. Where the rack is drawn
   and the pinion is not taken, the pinion's train, as the gear reading has
   it, holds the loop too: the tube drawn 10 LDU turns the wheel 168.69°.
   Not a pinion taken by hand: 8062-1's, in a cab of hinges, then shared
   its turn with the cab (the rack 4.45 LDU of 5.34 for 30°). Too big to
   solve with the train, the loop is as it was.
4. **A rack carried past a still pinion rolls along it, and a gear the loop
   turns on its own axle turns what it meshes** (`Grab._train_to_racks`,
   `_meshes_moved`, `_only_bearings`). Turned from the tilt wheel, the
   telescope's cradle carried its tube round as if fixed to it: only a
   turning pinion's rack made a loop. A rack whose body hangs from what the
   train turns, against a pinion that does not turn, makes one now. And a
   loop's meshes were only those of the train it was driven through: the
   extension wheel's loop tilted the cradle 45°, its tilt chain not in it.
   A mesh of a gear the loop turns on the gear's own axle, against one it
   leaves standing, joins it, out to six meshes on, when what that adds is
   the gears' own bearings: the cradle now stays (0.00°) and the tube
   slides 15.997 LDU. A gear swung about another line (a hub's on a steered
   wheel) is left out, and so is a mesh that would bring in what carries a
   gear: 8062-1's steering took in its cab of hinges, 13 joints for 5, and
   the cab took a sixth of the rack's travel. So is a worm standing still
   against the gear the loop turns: it holds the gear (section 13), and a
   tractor's sower dragged from its gear's side turned 720° with the worm's
   mesh in its loop. And so is a gear held with what stays, with no joint
   of its own to turn on: 8020-1's truck, steered and steered back, took
   such a mesh into its loop and locked ("It did not move").
5. **A frame named so is held still body by body** (`Simulation._frame_held`).
   Simulate held every part of a sub-assembly named Stand, Frame, Base or
   Chassis. The telescope's Stand lists the friction pin its tilt chain's
   idler is read fixed to, the two turning together in the stand's hole, so
   the frame held the idler and the chain read locked ("#24 6542b with #26
   4019"). The parts are read first with only the baseplate held; a body is
   held when a part of the frame in it is not a pin or an axle, or when all
   of it is the frame's. The tilt wheel now slides the tube 8.003 LDU in
   Simulate, 7.995 in Grab. The orrery's frame and its periods are as they
   were. Where a frame is named the gear reading is built twice.
6. **A session can lay a pinion in its rack** (`Joints.meshing`). The check
   every edit_model, submit_design and placed part goes through forgives a
   gear's teeth in its partner's, but did not know racks: laid again part
   by part through edit_model, `rack_wheel` came back "Not applied — the
   model would not hold together. brick 14 (3647 at -1,8.25,0.40) overlaps
   brick 7, which fills y=7 up to y=8.75 — so the course above it starts at
   y=8.75". Half a plate up is 4 LDU off the rack's pitch line, past the 3
   Racks reads as a mesh: a pinion moved where the check says meshes
   nothing, and its wheel turns only its gears. Whether the owner's Claude
   met this is not known; it is what a session building a rack meets, and
   it would make claim 1 true of Grab as well. A pinion in a rack is now
   said and forgiven as a mesh ("an 8 in rack 3743"), and the rig laid so
   slides its tube 21.333 LDU a turn in Grab and in Simulate.

Also checked, after: `simulate_probe` (41 ok, windowed), `grab_probe`'s
racks (43), loops (13), steer (27), steering (36), worms (34), actuators
(38), follow (5), cardan (3), swing (28), scissor (5), kart2 (3), moving
(18) and big (5) in a window, all passing, and headless the
same 164 passed as on cde834b2 (its 35 that fail headless need a pointer,
there as here); `mechanism_probe` (54), `axle_probe` (48), `joints_probe`
(57), `app_tools_probe` (103), `mcp_walk_probe` (33), `mcp_sync_probe`,
`animation_probe` (23) and `placing_probe` (38). The steering sweep
(`tools/steer_sweep.py`, 181 sets, `sweeps/sweep_mechverify2.md` in the
results): 60 of 168 steer both ways and back, as Grab 16's `g16final`, and
not one set's verdict changed (the first run, before the guard of fix 4,
lost 8020-1's truck). The move sweep against `g16final`, stopped at the
time box: the first 43 sets (68 things, before fix 4's last guards) and 35
of the 87 sets whose things turn gears or close a loop (64 things): not
one thing's verdict changed (`sweeps/movesweep_mechverify_part1.jsonl`,
`movesweep_mechgear_0.jsonl`); the other 52 are not run. `simulate_mechanism`'s
description says it turns a rack and a crank's rod and slider
(`tools/mcp_tools.json` written again).

### What is left

The probe prints these as `GAP`, not failures.

- **A body on a free bearing on the shaft that drives it is carried round
  with it.** `tilt_cradle`'s wheel at 90° turns its cradle 90° and slides
  the tube 0.000 (16 by the teeth), in Grab and in Simulate. The cradle's
  joint is a turn relative to the pinion's axle (Bodies' tree), and the
  loop keeps the joints it does not need where they were relative to their
  parents. Weight and friction decide which goes, the cradle or the tube;
  the parts would leave a heavy cradle where it stands. What it takes:
  `Linkage` choosing among a loop's spare freedoms by how far each body
  moves in the world, weighted by its mass (least kinetic energy, Gauss's
  principle), not by its joints' own turns; then the free bearing's
  joint joins the loop as a column, as the rack's mesh asks.
- **Simulate's base and Grab's anchors are two readings of what stays.**
  Simulate holds the baseplate, what stands on its studs and a frame named
  so (section 8, fix 5); Grab holds a locked part, what stands on the
  baseplate's studs, else the biggest body (section 10). Grab's anchors
  lock the 494-part orrery's crank ("its gears lock (right angle 12-12)")
  and hold the two-planet orrery's crank rigidly ("joined on two lines at
  once"), where Simulate's base turns both; which is why a gear train keeps
  the gear reading's poses (fix 1). What it takes: one rule for what stays,
  read once and given to both `Mechanism.build` and `Bodies.read`, with the
  orrery's periods and section 22's sweeps run again on it.
- **Simulate drives only a turn.** A tube drawn along its rod (claim 2), an
  actuator's rod, a slide, are Grab's alone.
- **Nothing in Simulate has weight.** Claims 3 and 5 (a crank-slider let
  go swings; a friction pin holds) are Grab's; Simulate says where things
  go, not whether they stay there.
- **What reads a clutch gear on a friction pin.** The telescope's two
  idlers, the same parts on the same pins mirrored, are read one turning on
  its pin, the other fixed to its pin and turning with it in the stand
  (move_part's list: "#20 ... on its pin", "#16 Technic Pin with Friction
  and Slots and 1 more part, on its pin"). Either turns the chain, now in
  Simulate too (fix 5). Not looked into further.

## 28. A bearing, a part stopped against another, and a loop's big step (Grab 17)

Three things real sessions met on 2026-10-20 (MCP walk 3, motions1). Each
was measured on the base, 21b2f95b, and after, by a scratch probe calling
move_part as a session does; `grab_probe -- --only=bearing`, `--only=path`
(with `shapeless`) and `--only=bigstep` hold them.

### A part slid into the bearing its axle turns in

The observatory (`tests/fixtures/mcpwalk3/observatory.ldr`), its dome
opened, the telescope's carriage drawn along its axle: move_part #149
along=6 slid it all 6 studs, and the carriage's Technic brick (#150) ended
at (20.5, 4.8, 15) studs, where the axle's bearing (#151) stands, 4.00 LDU
into it by their exact shapes. Read again, the two were one body. Two
causes, each enough:

- **Every joint's halves were skipped for every moving part.**
  `Grab._chosen` put both parts of each joint between what moves and what
  stays into `skip`, which no moving part is tested against. Now the part
  that stays is forgiven only for its partner across the joint
  (`Grab._across`, `_join_across`, `_pair_forgiven`): the axle in its
  bearing, not the carriage on the axle. Nor does the axle's cover in its
  bearing count towards what a cover forgives every moving part. The same
  for a free joint let go to swing (`land_begin`).
- **A slide was not tested where its turn had swept clear.** A grab of a
  part that turns and slides on an axle is read as a turn first, and the
  turn's sweeps leave out what can never meet anything turning about the
  line (`_never_meet`), and what is on the line itself. move_part along=
  then slides it (`use_slide`), and the carriage, its sweep round the axle
  clear, was never tested at all. What was left out for the turn alone
  (`_turn_only`) is tested again when it slides.

After: "slid 5.1 studs along (asked 6 studs); it stopped where the Technic
Brick 1 x 2 with Hole (#150) meets the Technic Brick 1 x 2 with Hole
(#151)", the carriage at x = 19.6 studs, 1.99 LDU into the bearing by their
exact shapes: within a cover's cell (2 LDU), which is where the room test
finds two parts meet (the shapes only forgive what the covers met; G13's
left for later). Nothing else that moved is into either bearing. With a
cover reaching the cell it fell short by (below), 5.05 studs, and no
deeper than the 1 LDU their shapes allow.

### A part stopped against another, moved on into it

The made arm on its hinge and the plate over its way (`MADE_PATH`), turned
-90° towards the plate: it stops at -20°, where its Brick 1 x 2 (#11)
meets the plate. Turned -90° again from there:

| the plate | 21b2f95b | now |
|---|---|---|
| with none (a browser before the shape is fetched) | all 90°, through the plate; turned back +90° it stops at 66° on the plate | 0°, stopped where it is; +90° back, all of it |
| with its exact shape | 6° more, a box 12 LDU into the plate's, until the arm's Plate 1 x 2 meets it; then the arm is read as part of the plate and will not move | the same (left, below) |

Where a move stops, the two covers (2 LDU cells that reach past their
parts) overlap, and a pair whose covers overlap where a grab begins was
forgiven for the whole grab (G13). Now, where one of the two has no exact
shape, the covers judge, and cannot tell parts built flush from parts into
each other: the pair is forgiven only as far as the boxes were into each
other where the grab began, or as built, and `TOUCHING` (1 LDU) more
(`_no_deeper`). Away and back is forgiven, on into it is not. The same for
what a cover forgives every moving part (42042-1's winch drum: `--only=worms`
passes, 34 checks).

**Left: two exact shapes stopped against each other.** Forgiven only where
the shapes are into each other where the grab began, and judged by them
otherwise (`_clear_exactly`, their clash at rest already asked at the press
by `_forgiven_at_rest`), the made arm stopped at once. But three steerings
stopped short: 42050-1's at 10° of 30, where an axle joiner (#45) meets the
axle pin in it (#46), back 0.295 LDU off (it was 0.006); 5533-1's at 2°,
its steering arm on its plate; 4002020-1's turntable +1°, -32° (+13°, -44°).
Their parts were forgiven as they stood since G13, and judged by their
shapes the loops close through them. Each stop needs reading (a joint
Bodies does not see, or a loop's reading) before the rule can go in.

### A turned part's cover a cell short (m131's hold)

`grab_probe --only=hinge` failed on every run with Grab 17: 4096-1's boom,
the Plate 2 x 8 on its 3937/3938 hinge, stopped at 95.7° where the plate
(#32) meets the hinge's base (#30), and the probe's room test found room a
degree on. Before, the base was skipped for every moving part as half of
the hinge, and the boom went on to 112.8°, to the turntable (#24): there,
by their exact shapes, 2.6 LDU into the base. Now only the hinge's top (#31)
is forgiven it. At 90° the plate's underside lies flush on the base's side,
and past it the plate's overhang turns into the base: by their shapes 1.0
LDU at 95.5°, 1.24 at 96.7°, 3.4 at 117°. The stop is right and 112.8° was
not (bisected: 1d27522c, "a bearing is forgiven only for the axle in it").

The room test disagreed with itself. A cover is counted from the cell its
part's origin is in (`Builder.boxes_for` and `turned_cover`, from
`BrickLattice.to_cell`, a floor), and a turned part's is not cut back or
rounded out about where the part is, so it stands up to a cell short of it
towards +x, +y and +z. Turned an eighth of a degree at a time from 94.7° to
97.7°, the plate's cover met the base's at 14 of 25 turns and missed it at
11, in two runs as its origin crossed its cell along z (95.0° to 95.7°,
96.7° to 97.1°). The shapes only judge what the covers meet
(`_clear_exactly`), so room came and went with the cell: none at 96.0°, room
at 96.7°, none at 97.7°. Placed where the part is, its cover met the base
at all 25.

Now a part off the lattice asks its cover a cell further on, towards +x, +y
and +z (`Grab._reach_cell`, in `_blocked` and `_blocked_turned`), for a pair
whose exact shapes then judge it. A pair with no exact shape is judged by
the cover as it was, so nothing judged by covers alone changes. The boom
stops at 95.4°, its base met at 95.53° (1.01 LDU by their shapes), and the
room test agrees at every turn asked between 94.4° and 115.4°. Left: covers
kept in the lattice, of what stands and of a part placed turned, are counted
the same way; only the room test reaches the cell.

Checked, in a window: `grab_probe --only=hinge` (18, the click hinge's stop
unchanged at 90° on its 22° clicks), `--only=minifigure` (9), `--only=loops`
(15), `--only=racks` (43) and `--only=worms` (34), each as on ec690d35,
`--only=bearing` (2), `--only=path` (6, its two GAPs) and `--only=steering`
(36). The steering sweep on nine sets (42125-1, 8820-1, 8808-1, 8448-1's
racer, 42043-1, 6753-1 and three of 8074-1's) steers where the standing
sweep (play127) does, five of the nine, each back as far; `own_copies_probe`
(33) and `mechanism_probe` pass.

**What it found that was hidden: 5533-1's steering arm in its brick.**
`--only=grooved` (not run above) fails with the cover reaching its cell:
turned +30 at its pinion, 5533-1 stops at 2° where its steering arm (#33,
32069) meets a Plate 2 x 4 (#19), the rack 0.35 LDU along where it went
1.76. Their shapes do not overlap as built; at the stop the arm is 1.75 LDU
into the plate. The arm has not turned there: it has slid 1.75 LDU along
its own shaft (+x), the axle by which it sits in its Technic brick (#29,
2743), read with 0 LDU to go that way and 10 the other. The loop closes by
that slide because an axle's slide in a loop is not held to its range (§26,
left for later: held, 8448-1 steered 1° where it steers 11°). Without the
reach, the same +30 kept the arm 1.47 LDU into the plate, 1.47
into its own brick and 1.47 into the plate under it (#31), none of it as
built, and the room test passed it: its floored cover was short of all
three. So the stop is the room test right about the pose the loop chose,
and what is wrong is the loop's. Damping the axle's slide as a friction
pin's is damped (`Linkage._friction`, 1000 times) still slid it, the rack
0.42 LDU, so the loop as read has no other way to close. 8448-1's racer
passes either way. With Grab 18 and 19's loop solve merged (4d1c9b5f; in
it, a free axle's slide moves less than a turn, af58aa09), the check passes
with the cover reaching its cell: the rack goes 2.67 LDU and comes back to
-0.40, and nothing stops it. Which of their commits does it is not
bisected.

### What the joints' halves cost a wheel loader's arm

The same commit (1d27522c) held m131 a second way: 42081-1's arm drawn by
its linear actuator (`grab_probe --only=actuators`) took its drag's own
work a frame from 12.1 and 12.3 ms on average, 95% 23.1 and 25.9 (main,
two runs alternated), to 15.5 and 15.5, 95% 51.2 and 46.2 (1d27522c), and
the bar is 33. Weighing was 1 to 2 ms of it. The room test, timed part by
part, met three things main never did, each from a half of a joint now
tested against what moves:

- The turned fairing (#974, 64683) had its cover asked against everything
  its cover's reach met, among them a frame (#196, 11954) of 2,573 boxes
  that its box was not into: 42 to 45 ms a frame, five frames running.
- `_pair_forgiven` asked whether the two were exact before it needed to,
  and a shape not yet read is read from disk: 16 of them, 49 ms in a frame.
- `_rest_with`, a part's overlaps where the grab began asked the first time
  it is met, asked the clash at rest of its partner across the joint as
  well: 37 to 48 ms once.

Now a turned cover is asked only against what the part's box is into by
more than `TOUCHING` (`Grab._into_cover`, as `_boxes_meet` asks it), the
shapes are read only where they decide, and the partner across a joint is
not asked its clash at rest (it is forgiven whatever it is). Alternated
again, two rounds: main 12.1 and 12.3 ms, 95% 23.1 and 25.9; this 12.5 and
12.2, 95% 22.8 and 20.4; baac8987 (the cover reaching a cell) 15.3 and
17.2, 95% 46.2 and 52.7; 1d27522c 15.5 and 15.5, 95% 51.2 and 46.2. One
frame in a run still costs 58 to 70 ms, the first `_rest_with` of a part
met: the 95% is unchanged by it. 8820-1's steering, which Grab 17 had
stopped at 6° where a tyre's turned cover reached its steering top, turns
all 30° again and comes back 0.0042 LDU off, as before Grab 17: the tyre
has no exact shape, and its box is not into the steering top's cover.
Left: a whole cover (`_blocked`, a test asked at once) does not ask the box
first, so for a pair with no exact shape it may still find a cell's reach
the asked cover lets by. Checked on this, in a window: `grab_probe
--only=hinge` (18), `minifigure` (9), `loops` (15), `racks` (43) and `worms`
(34) as on ec690d35, `bearing` (2), `path` (6, its two GAPs), `steering`
(36); the nine sets' sweep as play127 but 8820-1, above; `own_copies_probe`
(33) and `mechanism_probe` pass.

### A loop turned in one big step drifts (not fixed)

8808-1's steering wheel (#80) turned by move_part, a step each, measured
where every part stands back (LDU):

| | 90, -90 | 90, -180, 90 | 30, -60, 30 | 11, -11 |
|---|---|---|---|---|
| 21b2f95b | 0.0270 | 1.7814 | 0.0008 | 0.0000 |
| every step of a solve closed to `CLOSE_TO` | 0.0037 | 0.0082 | 0.0146 | 0.0005 |
| the same, in 3° steps | 0.0019 | 0.0031 | 0.0096 | 0.0001 |
| Grab moving the loop 3° at a time, each kept, as a motion plays it | 0.2084 | 6.5690 | 0.0117 | 0.0017 |

Every way tried took the big step's drift down only by taking the
sweeps' own turn (+30, -60, +30) from 0.0008 to about 0.01, half the 0.02
both sweeps allow, and Grab stepping as a motion steps was worse. None
was kept. The drift is the loop's freedom to spare (the column's slide
along its axle): `Linkage._follow_slope` reads each step's slope off the
step before, freedom to spare and all, and the next step starts from
there, so whatever one step's solve slid it, the next slides it again. What
it takes: the slope with its part along that freedom taken out (the least
change that keeps the loop closed: the free columns' Jacobian's least-norm
answer for the driver's turn, weighted as `FRICTION_WEIGHT` weights it), and
both sweeps run again on it. `grab_probe -- --only=bigstep` prints where it
stands as a GAP. Done in Grab 19 (section 30), and the GAP is a check.

### Checked

On the final code: `grab_probe` headless whole, 172 passed (the base's 164,
loops, racks, worms, steering and all, and this unit's 8), and the same 35
that need a pointer failing, as on the base; in a window `--only=bearing`
(2) and `--only=path` (6, and the exact shape's two GAPs); headless
`--only=steering` (36), `--only=clipped` (4) and `--only=grooved` (4), the
three that stopped short with the exact-shape rule. `motions_probe` (70),
`telescope_probe` (32, its three gaps), `simulate_probe` (41),
`placing_probe` and `mcp_walk3_probe` (20) pass. The walk's "Extend the
telescope" now stops at 574° of the 612°, where the carriage meets its
bearing: it slid on into it before, "clear all the way", and that check now
asks that it does not stop on the dome. The steering sweep (181 sets) is
not run here: the bearings' test touches every loop's room test.

## 29. A loop of what moves, a rack on its rests, and a tyre's round (Grab 18)

With a file's own copies of parts read as those parts (9dbfc354) on Grab 17
(e8d58876), the steering sweep (`tools/steer_sweep.py`, 181 sets) found
42125-1's steering refused as too big, 8820-1's rack sliding a fifth of what
it did, and 8845-1 lost with Grab 17's bearing rule alone. Each was measured
on the base, cbfb2506, and after, by the sweep set by set and by a scratch
probe calling `move_part` as a session does.

### 42125-1: the joints a drive moves

The rack hangs on its track rods by their balls now that the rods are read,
so its way from what stays runs out through the suspension, and the
pinion's runs through the housing it turns in, a beam hung on four pins in
the frame, each pin a body turning in both. `Linkage` took in every loop
through any joint on those ways, and every loop through theirs: 106 joints
in the first round (the limit is 40), 257 in all, the frame's pins, the
doors, the roof. Refused. The sweep's mechverify2 row said it steered: the
rods were not read then, the rack slid 0.76 LDU and no arm turned.

1. **A loop is solved between groups of bodies held as one**
   (`Bodies.held_together`). Two groups are one when every way between
   them together lets no motion of the one against the other: each joint
   straight between them, and each way through a third body that touches no
   more than six groups (a pin, a connector), which lets what its two sides
   let. Motions are twists about the joints' middle in radians and studs; a
   way counts where it stands 0.03 from the rest (two pins' lines 0.6 LDU or
   more apart hold). Every anchor is one group. 42125-1: 547 bodies in 353
   groups, 129 ms, once per reading and only when a loop is read. `Linkage`
   places each group where its lead (its body nearest an anchor) stands; a
   lead hangs on the tree's joint, and every other joint between two groups
   closes a loop. A driver turning within a group is read as before. The
   steering: 18 joints.
2. **A rack hung on balls alone rests on what it lies on**
   (`Bodies._rest_racks`). With nothing guiding it, the rack rolled about
   its line and swung on the rods: 10° of the pinion slid it 2.67 LDU and
   turned the knuckles 1.18°. A rack a pinion of another body drives, whose
   own joints are all balls, rests on the part its box is most into of
   those sharing its cells (not what its balls join it to, nor its
   pinion's body), as `_lodge` lays one for a rack nothing holds.
3. **An axle's free slide moves less than a turn.** Least squares over
   every coordinate alike slid the suspension arms along their axles as
   the knuckles turned, 0.5 LDU for 10°, until a bush met a shock absorber
   at 25°. Each step damps an axle's unbounded slide `SLIDE_WEIGHT` (30)
   times as hard as a turn, and a friction bearing `FRICTION_WEIGHT` times
   as hard as that, so a telescope's tube still slides 7.99 LDU of 8 on its
   rod against its chain's friction pin (damped alike, 7.08). Damped a
   thousand times, the arms stayed to 0.000 LDU, but 4002020-1's turntable,
   whose clip slides on its bar, came back 0.138 LDU off.
4. **A universal joint's centre in an end's fork is pinned there**
   (`Bodies._cross_in_forks`, the 3L joint's parts only: pinned so, 8448-1's
   older 4L joint locked its steering's loop), and a loop takes in the
   shafts its gears turn through one (`Grab._only_bearings`). The file draws both centres of the
   steering column a quarter turn off their ends' forks (the fork's pins
   along x, the centre's at 45° to it), each pinned in one end only. The
   cardan shaft between was held by nothing and lodged where its box was
   most into something: a liftarm beside it, and once the column had turned
   30°, read again, the column's end. Turned back, the shaft swung round
   with the column into the frame ("the Technic Universal Joint 3L End
   (#672) meets the Technic Angle Connector #2 (#649) at once"). A centre
   within `SAME_LINE` of an end's fork's middle is pinned in it on the
   fork's line.

After: "a loop of 35 joints (18 axle, 1 rests, 8 ball, 8 hinge), closed by
13 of them and 2 gear meshes and a 12 tooth pinion in rack 87761". +30°:
the rack 8.00 LDU (12 teeth of 8 LDU, a twelfth of a turn), the knuckles
11.54°; -60°: -8.00 LDU, 11.54° the other way; back 0.0069 LDU. The sweep's
row takes 59 s (it was refused in 25).

### 8820-1's rack

Under Grab 17 it slid +1.12 and -1.45 LDU where it slid 5.34: stopped at 6°
of 30 where a tyre (#132, 2346, no exact shape) meets the Technic Steering
Top (#17). The two boxes touch as built, so `_no_deeper` lets them no more
than 1 LDU into each other, and each 3° of the steering swung the tyre's box
0.47 LDU further in (0.94 at 6°). Judged as the round its box makes (35 LDU
across the tread, 30 wide) against the top's exact shape, the tyre is clear
all the way to 30°, the top's nearest corner 0.09 LDU outside it. The stop
was false.

5. **A tyre with no exact shape is judged by its round**
   (`Grab._depth_between`, `Exact.round_of`): the 16-sided prism inside its
   box's round, against the other part's exact shape. After: +24° (the rack
   4.21 LDU), where the same tyre meets the Technic Plate 1 x 8 with Holes
   (#2) under it, by its round and the plate's shape; -59° of -60 (-6.38
   LDU), where a rim (#133) meets the steering top; back 0.0065 LDU.

Not a wheel's rim. 8845-1's rim (#171), judged by its round, let its
steering on from -24° to -52°; read again there, its axle pin (#50) is in
its track rod's (#59) hole on a second line ("lines:50:59"), the arm and the
rod one body, and the turn back moved only a wheel: 35 LDU off. Its exact
shapes and the tyres' rounds are clear at -39° (a scan of every moving part
against everything its box meets). A rim stays judged by its box until that
reading is fixed.

### 8845-1, the bearing rule and Grab 17 whole

It steers here as with Grab 17 whole: 8.13° (+30 stops where the Wheel Rim
#177 meets the Technic Plate 1 x 4 with Holes #36), -24° (the rim #171 meets
plate #63), back 0.0004 LDU. The bearing rule (`_across`) no longer forgives
the plate its arm's hinge is on for every moving part, so the first turn
stops at 8° where it went 30°. The second begins there with rim #171 and
plate #63 in each other's covers, a pair G13 forgives for the grab. With the
bearing rule alone it was forgiven whole: the rim went through the plate to
-52°, where the reading above makes the arm one body with its track rod and
the turn back moves only a wheel (#51 35 LDU off). `_no_deeper`, Grab 17's
other rule, forgives the pair only as deep as it began: it stops at -24°.

### 8416-1 is held by its worm

Not a steering: a forklift whose lift the sweep turns by the 16 tooth gear
(#43) on its pinion's axle. That axle carries a 24 tooth crown gear (#28)
that a worm (#27, 4716, on a vertical axle) meshes, 41 LDU from its middle.
The loop had taken in the mast's pins and the worm's own axle as joints, and
a worm the loop carries may turn its gear (`Grab._worm_holding`): the lift
went 10.67 LDU. Grouped, the mast is one body and the worm's axle is not in
the loop, so the worm holds the gear: "Held by a worm ... Turn the worm's
axle instead." So it is with the parts: a worm is self-locking (section 13).

### The big step's drift (not done)

8808-1's wheel turned 90, -180, 90 comes back 1.7814 LDU off and 90, -90
0.0270, as on the base: the slide's damping does not reach it. Section 28's
least-norm slope was not tried (Grab 19 did it: section 30).

### Left

- **8448-1_Racer's grooved rack no longer moves** (`grab_probe --only=grooved`,
  base 1.94 LDU): "the Wheel Rim 30 x 61 with 3 Spokes Swirled (#478) meets
  the Technic Suspension Arm 2 x 6.5 Type 2 (#376) at once". Its two
  suspension arms (32195a, #367 and #376) are pinned to the chassis at (6,
  4.1) and (6, 6.1) studs and joined at (8, 4.1) and (8, 6.1) by a cross
  block (#374): a parallelogram, free to move. `held_together` grouped them
  with the chassis because `Bodies._ball_middle` put both arms' ball joints
  on the steering arm's (32186) first ball, at (11.5, 4.1): it counts only a
  socket named so, and 32195a's socket is drawn as rounds (a bore 8 across,
  10 long), which `Joints.balls` reads and `_ball_middle` did not. Two arms
  on one ball close the parallelogram. Counting such a bore as a socket
  (`grab18_ball_socket_bores.patch` in the results) puts the upper arm's
  ball at (11.5, 6.1); then the first turn goes all of 30° (the rack 5.33
  LDU, its arms 7.65°, where the base went 1.94), and the second is refused,
  "Locked", by what the joints read after that turn: the pinion read one
  body with an axle on a hinge. Not kept: not proven on the other sets in
  the hour, and the second turn not looked into (Grab 19 kept it and found
  why: section 30). The old loop counted the
  arms as moving (everything beyond a loop joint), so the rim beside them
  was never tested against them.
- 8845-1 at -52°: an axle pin read in its track rod's hole on a second line,
  at a pose its rims' boxes keep it from. Why the exact shapes let it get
  there, and which joint reading should not see it, is not known.
- `held_together` costs 129 to 156 ms on 42125-1's 3,184 parts, at the
  press of a loop's grab, once a reading.
- A universal joint's centre is pinned only in a fork whose middle it is
  within 1.5 LDU of; one drawn elsewhere is as before.

### Checked

On the final code: `grab_probe -- --only=groups` (4: 42125-1's loop of 22
joints, +30° the rack 8.00 LDU and the knuckles 11.53° and 11.52°, the
suspension arm 0.102 LDU, the column's two 16s 30.00° each, back 0.0170
LDU; 8820-1 24°), which fails 3 of 4 on cbfb2506; `telescope_probe` (32,
its three gaps; a turn slides the tube 21.333 LDU, tilted 45° 7.993 and
7.999); `--only=clipped` (4: 4002020-1 +10°, -2°, -7°, back 0.0001 LDU).
Earlier in the unit, with the slide damped as hard as friction:
`grab_probe` headless whole 164 passed and 41 failed, which run on
cbfb2506 section by section are the 35 that need a pointer, 42050-1's
ribbed hose and 8074-1_Crane's turntable (failing there too: the own
copies'), 4002020-1 (passes now) and 8448-1_Racer's two (Left, above); in a
window `--only=bearing` (2) and `--only=path` (6, two gaps);
`motions_probe` (92), `simulate_probe` (41), `mcp_walk3_probe` (20) and
`own_copies_probe` (20) passed. The steering sweep, the 60 sets that steer
in mechverify2: 59 steer both ways and back, 8416-1 held by its worm (above);
nothing else changed but 42125-1 and 8820-1. The 181 are the lead's.

## 30. A column through two old universal joints, and a loop's least change (Grab 19)

8448-1_Racer, with Grab 18 and its ball socket patch (a socket drawn as a
bore is a socket): the steering turned at its pinion went +30°, and the
second turn was refused, "Locked". Each was measured on that base, 5f2ecc9a,
and after, by a scratch probe calling `move_part` as a session does and by
the steering sweep.

### Why the second turn locked

The set steers from a large steering wheel (2741) on a column, an axle 8
with a 4L universal joint (3712 ends, a 3326b centre) at each end, down to
the pinion. The file places the column as a sub-model of its own ("// Needs
work", the author wrote), turned 28.4° round its own line from where the
joints' other ends stand. So each centre is drawn in the column's fork and
28.4° off the other end's, and the chassis draws a second centre at the same
point, in the pinion end's fork only. As read:

- **Neither joint joined anything.** The pinion's shaft turned alone, and the
  steering wheel turned nothing: the sweep turned the set at its pinion.
- **The column was one with the chassis**, by the studs of a wing brick
  (2744, #574) 13 LDU below the tilted axle: the lattice covers a part turned
  off the grid with every cell its boxes' turned corners span, and the stud's
  tip was in one. A lone stud between parts askew to each other, in no socket
  or hole, is kept as a joint (42081-1's half pin), and with neither part one
  stud across it joined them.
- **Turned 30°, the pinion end's fork met the column's centre**, whose other
  pin stands 28.4° round: read again, the centre was pinned in both ends, and
  the pinion's shaft was held through it by a column that was part of the
  chassis.

Grab 18 had pinned a 3L joint's centre in both forks
(`Bodies._cross_in_forks`) and left the 4L out because pinned so it locked
this steering at once: the column held by that stud was why.

1. **A stud reaches into a part turned askew to it only within that part's
   own box** (`Bodies._reaches_into`, a cell's slack round it). The column is
   then held by nothing it is drawn in (its axle passes through no hole as
   placed) and lodged in the wing brick, so the second turn still swung it,
   hung on the pinion, into a liftarm at -5°.
2. **Every universal joint's centre is pinned in both its ends' forks as
   built**, the 4L's as the 3L's (any part named Universal Joint, Centre or
   End, but a complete assembly). The column is in the loop from the start:
   the pinion, both joints, the column and the wheel's shaft. The sweep finds
   that the wheel turns the rack and turns it there: +30° slides the rack 6.36
   LDU and turns the pinion 35.7° (crosses that stand 68.8° and a column at an
   angle turn it more than one for one) and the steering arms 9.1°; -60° takes
   it to -6.15 LDU.

### The loop's freedom to spare (section 28)

Turned back +30°, the wheel came back 1.58 LDU off: the column, between two
axles that each slide in their holes, slid along itself with them.
`Linkage._follow_slope` read each step's slope off the step before, and the
next step started there, so whatever one step's solve slid in the loop's
freedom to spare, every step after slid again.

3. **A step starts along the loop's least change** (`Linkage._tangent`): the
   slope where the last step closed, the change of least weight that keeps
   every row closed for a unit of the driver, weighted as a step's solve
   weighs it (a slide `SLIDE_WEIGHT`, friction `FRICTION_WEIGHT`), from the
   normal equations with their weight times 1e-6 on the diagonal. A slide at
   its end that the change would take further out is held there, as a
   step's solve holds it: free to go on past it, 4002020-1's clip on its bar
   let the turntable turn +15° and -5°, and it came back 2.09 LDU off. A part
   solved apart (`_reach_parted`) keeps its step's own.

| back where it began, LDU | before | after |
|---|---|---|
| 8808-1's wheel 90, -90 (`--only=bigstep`) | 0.0270 | 0.0013 |
| 8808-1's wheel 90, -180, 90 (`--only=bigstep`) | 1.7814 | 0.0030 |
| 8808-1's wheel 30, -60, 30 (the sweep) | 0.0008 | 0.0010 |
| 42125-1's pinion 30, -60, 30 (`--only=groups`) | 0.0170 | 0.0057 |
| 8448-1_Racer's wheel 30, -60, 30 (the sweep) | 1.5761 | 0.2042 |
| 4002020-1's turntable 30, -60, back (`--only=clipped`) | +10°, -2°, -7°: 0.0001 | +15°, -39°, +24°: 0.0001 |

### Swept

86 sets from a snapshot of the final code (`sweep_grab19t` in the results):
the 59 that steer in `play127` and every set with a 4L joint. 62 steer both
ways and back. Of `play127`'s 59, 58 still do; 8416-1 is held by its worm
(section 29). Four more steer: 8880-1_F1-Racer, at its steering wheel
through its 4L joints (its rack did not come back), 8841-1_Buggy (back 1.99
LDU, now 0.007), 8274-1 (0.022, now 0.002) and 42070-1 (back 0.0198 of the
0.02 allowed). Of the 58 that steer in both, 16 come back nearer than they
did (8273-1 0.018 to 0.002, 42075-1 0.018 to 0.004), 39 the same to 0.001
LDU, and 3 further, by at most 0.0012 (9395-1, 0.0012 to 0.0024). The 86
took 1,249 s where `play127` took 1,845 s for them.

### Left

- **8448-1_Racer comes back 0.20 LDU off** (the sweep asks 0.02), the column
  slid along the pinion's axle. Each turn reads the joints afresh, and the
  slide's least change is not the same either way: +30° slid it 0.125 LDU
  one way, and the 30° back from there 0.229 the other. Every step's solve
  closed to `CLOSE_TO` changed nothing.
- 8466-1's steering now moves both ways at its pinion (it was "Locked"), and
  a centre (#1165, 3326b) comes back 37 LDU off.

### Kept where it was let go (Grab 19b)

rel-m131 kept 42024-1's small actuator 1.75 LDU out once in three whole runs,
where the drag had shown it at 4.00, its stop on the model (#688 meets #670):
`--only=actuators`, "kept where it was let go". A loop's drag tests only the
pose where the pointer is; its way is checked when the pointer pauses or lets
go (`Grab.verify_step`), and where that walk meets something it is bisected
and the section kept at the stop. The walk was solved from the pose shown: its
first step jumped from there back to the value checked last, and each step on
from the one before. Its poses were not the ones the drag had shown. Measured
at the end of the walk against the pose shown, at the let-go value: 42024-1's
actuator 0.0004 to 0.022 LDU from run to run, 42081-1's arm 0.018 to 0.021,
and 42080-1's crane 127.6 LDU (a part that spins free, on another turn of
it). With the old slope (section 28) it was the same: 0.0049, 0.0181 and
127.6, so the step's least change was not the cause. At a stop where parts
touch, a few hundredths decide whether the walk meets something before it.

4. **The walk starts from the pose kept where it was checked last**
   (`Grab._checked_kept`), as the drag got there, and at the let-go value tests
   the pose shown, which is what is kept. A bisection goes on from the last
   step with room. Measured again: 0.0064, 0.0078 and 127.6 LDU; the crane's
   free part is still on another turn, so the walk's own poses still differ
   from the drag's where a loop has freedom to spare.
5. **A stop found after the release is said.** Where the walk meets something
   short of where the pointer let go, the keep says "it stopped where the A
   (#a) meets the B (#b), short of where it was let go" (`Grab.let_go_at`,
   `GrabDrag._keep`); before, it said only where it stood.

Forced (`repro/grab19_keep_repro.gd` in the results): the rod
shown on trust at 6 LDU, past its stop, as a frame whose test is cut short
shows it, and let go through `GrabDrag.release`. Kept at 1.75 LDU, the
failing run's value: "it stopped where the Technic Pin Joiner Round with
Slot (#686) meets the Technic Beam 4 x 6 Liftarm Bent 53.13 (#670), short of
where it was let go". The same, with the poses at 1.5 to 4 LDU solved first
(each clear by the two parts' exact shapes, each with room): kept at 4.31,
where the long pin (#688) meets the model, the stop the drag found. So the
walk met #686 only on a pose its own solve's history made: a false stop, and
it is now said, not hidden.

Checked on 86e4534b, in a window: `--only=actuators` five times, 38 each, the
small actuator kept at 4.00 every time and the wheel loader's arm 95% 12.5 to
15.1 ms a frame; `bigstep` (4), `grooved` (4), `groups` (4), `loops` (21) and
`hinge` (18, 95.4°) pass.

**Left:** the false stop itself. A loop with freedom to spare has no one pose
for a value of its driver, and the walk cannot replay the drag's. Keeping
each pose the drag showed (its kept state, a frame at a time) and walking
between them, or a pose fixed by the driver's value alone, would end it.

### Checked

On the final code: `grab_probe` headless whole, 178 passed and 35 failed,
the 34 that need a pointer and the big model's section, as on Grab 18
(165 and 39: those 35, 8074-1_Crane's turntable, 42050-1's ribbed hose and
8448-1_Racer's two, which all pass now, and `--only=bigstep`'s two gaps are
checks). In a window (`tools/probe.sh grab_probe`), 483 passed and one
failed: 4096-1's hinge stopped at 95.7° with room a degree on, the room
test's own (it fails on 95ffb570, and the hinge131 unit mends it). There
8062-1's winch turns through its two 4L joints as before, and the wheel
loader's arm (42081-1) drags at 12.0 ms of its own a frame on average, 95%
28.8 (the bar is 33). `--only=groups` passes as Grab 18 left it, 42125-1
back 0.0057 LDU. `mechanism_probe` (54), `own_copies_probe` (33),
`telescope_probe` (32, its three gaps; tilted 45° the tube slides 8.000
LDU), `simulate_probe` (41) and `motions_probe` (92) pass.

Merged with the hinge fix (39be9037), in a window: `--only=groups` (4,
8820-1 30° of 30), `grooved` (4), `hinge` (18, the boom stopping at 95.4°),
`loops` (21), `racks` (43), `worms` (34), `bigstep` (4) and `clipped` (4)
pass. `--only=actuators` five times: the wheel loader's arm drags at 95%
14.3 to 16.3 ms of its own a frame, where 39be9037 took 19.4, 20.6 and 35.9
in three runs. Once in the five, 42024-1's small actuator, drawn out until it
met the model at 4.00 LDU and let go, was kept at 1.75 ("kept where it was
let go" failed); 39be9037 kept it at 4.00 all three times. Left: whether
the step's new slope stops the keep's walk short of a stop where parts touch.

## 31. An axle's slide in a loop (Grab 20)

Grab 16 left an axle's slide in a loop free (section 26): held to its
flanges, 8448-1 then turned 0.1° where it turned 7°, its towballs needing
to slide up through the rack. Grab 19 left 8448-1's steering coming back
0.20 LDU off, the column slid along the pinion's axle. Each was measured on
m131 (3b02e21e) by a scratch probe calling `move_part` as a session does,
and by the steering sweep on 17 sets (the five 8448-1 files, 8466-1, both
5533-1 files, 8808-1, 8820-1, 42125-1, 8880-1_F1-Racer, 8841-1_Buggy,
42043-1, 9393-1 and both 8256-1 files).

### Why 8448-1 came back off

8448-1_Racer's wheel turned +30, -60 and +30:

| | back, LDU |
|---|---|
| as `move_part` turns it, each turn its joints read afresh | 0.2042 |
| in one grab, turned to +30, -30 and 0 | 0.2012 |
| the same, in steps of 1° (`STEP_TURN`) where they are 5° | 0.0353 |
| every axle's slide in the loop held at nought | 0.0087 |

So not the fresh reads: the steps. The pinion's axle (#417) and the wheel's
(#440) each slide in their holes, and the column between their joints can
go along itself with both: freedom the loop does not need. A step starts
along the loop's least change (section 30) and closes from there, and the
close moves nothing along that freedom, but the least change bends over a
step, and what it moved there along the slide was not undone on the way
back. Held at nought, the loop closes as well (the rack +6.35, -6.15) and
comes back. So does every slide of 8448-1's: since Grab 18 read the
towballs' sockets, none of them needs to slide.

Tried and not kept: a step started along the slope halfway along it (the
last step's change of slope taken as its bend). In one grab 8448-1 came back
0.022 LDU off; but 8880-1_F1-Racer, turned at its wheel through two 4L
joints, came back 13.65 LDU off, a cross gone round onto another branch.

### What is on an axle's line

`Link.slide` read an axle against each part it goes through. Each part on
the axle's side that it goes through or grips is now read too, against each
part on the other side it goes through (`Bodies.line_room`, from the parts
`Joints.through` finds on each axle, `Bodies.on_shaft`): by their exact
shapes where both are at hand, to where they first touch (`Exact.clash`
forgives `Exact.TAU`, 1 LDU, into each other, taken off), else by their
rounds. 8448-1's pinion axle read 9.5 and 29.5 LDU against its two bricks;
its pinion stands against one face of the nearer brick and the column's
joint end against the other, and by their shapes it goes 2 LDU either way
(their counterbores). A loop holds an axle's slide inside that, as it holds
a clip's (`Linkage._bounded`), and still damps it.

Held so, with the slide damped 30 times a turn as before, 42125-1 came back
0.1155 LDU off where it came back 0.006: its suspension arms slid 0.10 to
0.26 LDU each way as it steered (as at 30 they always had), and with two of
them flush against a part one way, held there on the way out, they came
back by another path.

### A slide moves only where the loop needs it

`SLIDE_WEIGHT` 30 to 1000: a slide the loop needs still moves (the least
change takes it), and one it does not, does not. On the 17 sets
(`sweep_grab20y`), against the standing sweep (`sweep_m131f`):

| set | m131f | Grab 20 |
|---|---|---|
| 8448-1 and its four other models | rack +6.35, -6.15, back 0.202 to 0.204 | the same rack, back 0.0074 to 0.0078: steers |
| 42125-1 | back 0.006 | 0.0073 |
| 8880-1_F1-Racer | back 0.017 | 0.0166 |
| 8841-1_Buggy | 0.007 | 0.0145 |
| 8808-1, 8820-1, 9393-1, 42043-1 | 0.001, 0.004, 0.004, 0.000 | 0.001, 0.0039, 0.0035, 0.000 |
| 8256-1, its lawn mower | steer, 0.000, 0.001 | steer, 0.0004, 0.0005 |
| 5533-1 | rack +2.67, -0.40: stops on the way back | rack +4.43, -5.31, back 6.43 LDU off (#368) |
| 5533-1_Tractor-Pulling | back 0.088 | 0.0905 |
| 8466-1 | rack +1.92, -2.08, back 36.83 (#1165) | the same, 36.92 |

Nothing that steered is lost, and 8448-1's five steer. With the line room
and the slope's bend, before the weight (`sweep_grab20x`): 42125-1 lost
(0.1155), 8880-1_F1-Racer lost (1.456).

### Left

- **5533-1** steers both ways now (`--only=grooved`: +4.43, then back to
  -5.31) and comes back 6.43 LDU off at #368 (2994). Not read yet.
- **8466-1**: the third turn reads the pinion as a body of two parts on a
  pin in no loop ("1 body move together"), and a joint's centre (#1165,
  3326b) turns with it, 37 LDU off. Why the loop is not read there after
  the second turn is not found.
- A closing joint's slide is not a coordinate (its along-line gap is left
  out of the residual), so it is not held to its line's room.
- A browser that has not fetched the shapes reads the line by the parts'
  rounds; how 8448-1 steers there is not measured.
- The loop with freedom to spare (#65) is where it was: a weight keeps a
  spare slide still, not a spare turn.

### Checked

On d854fab2, in a window (`tools/probe.sh grab_probe`): `--only=grooved`
(4: 8448-1_Racer's rack +6.35 then back to -6.15, 5533-1's +4.43 then
-5.31), `groups` (4), `bigstep` (4), `loops` (21), `racks` (43), `worms`
(34) and `hinge` (18) pass. `--only=actuators` five times: 38 checks in
four, and once the small actuator, let go at its stop 4.00 LDU out, was
kept at 1.75 (the false stop of section 30's Grab 19b, which passed it five
times in five); the wheel loader's arm 95% 15.1 to 16.7 ms a frame.
`mechanism_probe` (54) and `own_copies_probe` (33) pass. The whole steering
sweep is not run here.

## 32. The same shapes on a worker (Grab 21)

Grab 19b left 42024-1's small actuator, let go at its stop 4.00 LDU out,
kept at 1.75 about one run in four (`--only=actuators`, "kept where it was
let go"), and read it as the loop's freedom to spare (#65): the walk after
the release solves its own poses, not the drag's, and met something in one
the drag never showed. Its forced repro (`repro/grab19_keep_repro.gd`: the
rod shown on trust at 2, 4 and 6 LDU, then let go through
`GrabDrag.release`) was kept at 1.75, where the pin joiner #686 meets the
bent liftarm #670; with the poses at 1.5 to 4 LDU solved first, at 4.31.
Each was measured on m134 (38f44636) by variants of that repro
(`repro/grab21_keep_variants.gd`), which do one thing more before the
release, on the main thread:

| before the release | kept at |
|---|---|
| nothing | 1.75: #686 meets #670 |
| the poses at 1.5 to 4 LDU solved | 1.75: #686 meets #670 |
| solved, and #686 and #670 set against each other by their exact shapes | 4.31: #688 meets #670 |
| #686's and #670's exact shapes read, nothing solved | 4.31: #688 meets #670 |
| nothing, and the same walk run on the main thread, not on a worker | 5.75: #430 meets #61 |

So not the solves: the shapes. The check after the release runs on a
worker (`GrabDrag._verify_off_thread`), and there `Exact.shape_for`
answered null for any shape the main thread had not read yet. A pair with
a part of no shape is judged by covers, 2 LDU cells that reach past their
parts (`Grab._clear_exactly`, `_verdict`): #686's cover met #670's at
1.75, where their shapes are clear. The repro's "solved first" read the two
shapes as it measured them, and that, not the solving, moved the stop. In
the probe the drag reads shapes on the main thread as its frames' tests
reach them, a budget at a time, so whether it had read #686's before the
release changed from run to run.

1. **A worker reads a shape from disk as the main thread does**
   (`Exact.shape_for`). In a browser the shapes are fetched on the main
   thread, and a worker there still answers null for one not fetched, as
   the main thread does until it comes. Two workers reading one part keep
   one shape, and an id is given under the lock: shapes' ids key the
   verdicts between them.

The forced repro is now kept at 5.75 LDU, where the beam 3 (#430) meets
the cross block (#61), short of where it was shown on trust (6.00) and
said so, on a worker as on the main thread.
`exact_probe` asks four workers at once for two shapes not read yet: on
m134 each answered null; now each reads its shape, the one the main thread
then has.

### The loop's freedom to spare

The walk's poses were still not the drag's. Solved back from the pose shown
at 6 LDU, the forced repro's rod at 5.5 has the beam 3 (#430) 1.11 LDU into
the cross block (#61) by their exact shapes, no room; walked out from 0, it
has room to 5.75. A loop with freedom to spare has no one pose for a value
of its driver, and a stop the walk finds in its own poses need not be one
the drag met.

2. **The walk goes through the poses the drag showed** (`Grab._shown`,
   `_frames_on_the_way`). Each frame of a loop's drag shown on trust keeps
   its pose (`Linkage.kept_state`); the walk after a pause or the release
   lands on the value of each between the value checked last and the one it
   checks to, the last shown at each value, in order, puts that pose back
   and tests it as shown, and solves each step on from it. Traced on the
   forced repro, whose frames were 2, 4 and 6 LDU: the steps of 0.25 LDU
   land on 2 and 4 with the frames' own poses, and it is kept at 5.75 as
   before, the stop between the frame at 4 and the pose shown at 6.

### Checked

In a window (`tools/probe.sh grab_probe`), on the final code:
`--only=actuators` six times, 38 checks each, the small actuator kept at
4.00 LDU every time and 42080-1's crane at -28.00; with the shapes alone
(1. without 2.) six times more, the same. `grooved` (4), `groups` (4),
`bigstep` (4), `loops` (21), `racks` (43), `worms` (34), `hinge` (18, the
boom stopping at 95.4°) and `swing` (28) pass, as they do with 1. alone;
`mechanism_probe` (54), `own_copies_probe` (33) and `exact_probe` (30)
pass.

The wheel loader's arm, 95% of a drag frame's own work, ms, a run of m134
and then one of the change, in turn:

| round | m134 | then |
|---|---|---|
| 1 | 15.3 | 14.0, the shapes alone |
| 2 | 16.9 | 14.2, the shapes alone |
| 3 | 13.4 | 14.9, the final code |
| 4 | 14.2 | 16.3, the final code |
| 5 | 14.3 | 16.6, the final code |
| 6 | 19.7 | 18.2, the final code |

The box's load moved them more than the code: m134 itself went from 13.4
to 19.7, four more runs of the shapes alone one after another from 13.7 to
17.2, and four more of the final code from 12.9 to 16.1. A frame's share of the change is one
`Linkage.kept_state` a frame, 0.7 µs on 42024-1's loop of 29 joints.

The steering sweep on 19 sets (the five 8448-1 files, 42125-1, 8808-1,
8820-1, 8880-1_F1-Racer, 8841-1_Buggy, 9393-1, 42043-1, 5533-1, 42024-1,
42029-1, 42070-1, 8274-1, 6753-1 and 8054-1_Model-C), with the shapes alone
(`sweep_grab21x`) and on the final code (`sweep_grab21y`), is the same as
`sweep_grab20` set by set, to the step: 17 steer, 5533-1 comes back 6.43
LDU off and 6753-1 does not move, as there. A session's move is not a drag:
it walks its own way and keeps no frames. The whole sweep is not run here.

### Left

- The walk's poses between the drag's frames are still its own, solved
  from the frame behind. A drag whose frames are far apart (a big section's,
  a slow device's) leaves the walk more of its own way to solve.
- `Bodies._unknown_shape` and `_labelled_hinge` still read only shapes
  already read when off the main thread; the only reader there (GrabDrag's
  read ahead) reads every part's shape first, so nothing differs today.

## 33. An axle a part slides along, in what carries it (m135)

m134 left the observatory of the third MCP walk (`motions_probe`, section 7)
with its axle #148 (3708) 19.5 LDU off where it was built, once "Show it
all" had played and then played backwards. Bisected: 8903033e passes, the
Grab 20 merge (38f44636) fails.

The telescope's tube rides on the axle and the gear's rack pushes the tube.
The axle slides in two of the frame's bricks (#147, #151) and the tube's
bricks (#149, #150) slide along it: two slides on one line, one after the
other, so where the axle stands on its line is freedom the loop does not
need. Damped alike (`SLIDE_WEIGHT`), each step's least change split the
tube's run between them:

| | out, the axle | back, the axle | off |
|---|---|---|---|
| m131 (8903033e), nothing holding the axle's slide | +60.0, out of #147 | -60.0 | 0 |
| m134, the slide held to its line's room (±19.5, `Bodies.line_room`) | +19.5, at its end | -39.0, from a fresh read's room of (-39, 0) | 19.5 |
| the axle's slide in what carries it damped as a friction bearing | +0.12 | -0.12 | 0 |

So Grab 20's room was right, and showed the wrong: m131 came back only
because its unbounded split was the same both ways, having slid the axle out
of one of the bricks it is in.

1. **An axle a part of the loop slides along stays in what carries it**
   (`Linkage._carried`, damped as `_friction` is, through one
   `Linkage._weight` that a step's solve and its least change both read).
   Only where all the axle carries of what holds the loop (a closing
   joint's end, a rack, a gear mesh) rides on a part sliding along it: a
   pinion on the axle itself may need the axle to slide.

### Checked

On the final code, in a window: `motions_probe` 92 of 92 twice (the Grab 20
merge failed the observatory's backwards, render and undo checks);
`telescope_probe` (32), `simulate_probe` (41), `mechanism_probe` (54) and
`grab_probe` `--only=loops` (21), `groups` (4) and `grooved` (4) pass.
`--only=actuators` three times: 38 checks twice, the small actuator kept at
4.00 LDU; once 42024-1's rod was not found under the pointer from any of
three views, a pick before anything is solved, and the rest of it was not
run. The steering sweep on 13 sets (the five 8448-1 files,
42125-1, 8808-1, 8820-1, 8880-1_F1-Racer, 8841-1_Buggy, 9393-1, 42043-1,
5533-1; `sweep_motions135x`), against `sweep_m134`: 12 steer as there, the
same to the step but 8841-1_Buggy, back 0.0070 LDU where it was 0.0145.
5533-1 comes back 6.43 LDU off (#368) as there: not this.

## 34. A hinge built backwards stops its arm at its own base (m135's suite)

The full suite on main (684673c7) failed `pose_probe`: a click on the
crane's arm slider at -45° kept the key at -22.1°, and the panel said why:
"Arm stops at -22° of the -45° asked, where the Plate 2 x 6 (#6) meets the
Hinge 1 x 2 Base (#4). The key is there." Bisected: 21b2f95b passes and
1d27522c ("a bearing is forgiven only for the axle in it", §28) fails. Since
that commit, only the hinge's top is forgiven its base, and what the top
carries is tested against the base too.

The stop is right. 3937's top edge is square on one side (LDraw y 2, z 4.5
to 10, flush under the top) and rounded about the pin on the other, so the
top tips one way only. The probe's crane had the hinge facing so that its
arm rose the blocked way: the arm's short end turns down onto the square
shoulder. Measured about the pin (y 22, z 0), raised by the angle shown:

| up | arm into base, exact shapes | arm into base, real surface | top into base, exact |
|---|---|---|---|
| 12° | 0 | 0 | 1.90 |
| 14° | 0.18 | 0.18 | 2.18 |
| 21° | 0.81 | 1.05 | 3.05 |
| 22° | 0.98 | 1.16 | 3.16 |
| 23° | 1.14 | 1.27 | 3.27 |
| 45° | 2.73 | 2.00 (the wall's half) | 4.73 |

"Real surface" is 3937's LDraw triangles sampled every 0.5 LDU against
3795's solid (its box less its hollow underside). The top itself is 1 LDU
into its base by 6°, so a real hinge built this way barely moves; the top
is forgiven its base as the joint's other half. With the hinge turned 180°
about up, nothing of the arm meets the base by either measure from 0° to
90°, and the top's deepest is 0.09.

So the probe's crane now has its hinge facing the way the arm rises. Its
check of each frame drawn read the arm's turn (`hinge⁻¹ · top`, in the
hinge's frame) against the pin's axis in the world, which agree only for a
hinge standing unturned; it now reads the pin's axis in the hinge's frame.

### Checked

In a window on 5be39c85 with this: `pose_probe` (the arm keyed at 44°, 49°
and 20°, and stopped at -17° where it meets the baseplate, as at 17°
before), `motions_probe` (92), `animation_probe` (24) and `grab_probe`
`--only=hinge` (18), `cases` (72) and `loops` (21) pass. Nothing outside
the probe changed.

## 35. A hinge turns only as far as its parts let it (hinge77)

Since Grab 17 (§28) the part that stays is forgiven only its partner
across the joint (`Grab._across`), but that partner whatever their shapes
say. So a bare hinge turned either way as far as it was asked. On
3978c6f7, each made hinge below (its base locked, its top turned over
MCP, `grab_probe --only=hingerange`) went all 170° both ways and ended 4.0
to 4.5 LDU into its base by their exact shapes. pose136 had measured
3937's top 1 LDU into its base 6° the wrong way (§34).

1. **The joint turned alone is judged as a loop's joints are**
   (`_meeting_pairs`, `_pair_clear_at`): its two parts by their exact
   shapes, at every pose the room test asks. The covers still forgive the
   partner; the pair test judges it.
2. **Forgiven only what turns in place and what was built into each
   other** (`_pair_forgives`): each piece the joint's line goes through
   (`Exact.through`, within 0.25 LDU: a pin in its hole, a knuckle on its
   pin, a clip on its bar), and each pair of pieces more than `Exact.TAU`
   into each other where the grab began or where the two were built
   (`Exact.overlaps`). The rest is judged (`Exact.clash_but`). For 3937 and
   3938 that is 5 pieces (the top's fingers and bar, the base's boss); for
   44301 and 44302 5 pieces and 20 pairs built into each other.
3. **Worked out at the press** (`_pair_judge`): asked in the drag's first
   frame it took 1.1 ms for 3937/3938 and 6.3 ms for the click hinge (its
   134 pieces read about the line), past the walk's 2 ms share, and the made
   crane's drag was shown on trust and checked at the release, too late for
   it to fall when let go. In a frame now: 0.4 to 0.7 ms the first ask.
4. **Asked along the way where it is due** (`_pairs_due` in
   `_walk_steps`). The top's sweep round the line met nothing but its base,
   which the covers forgive, so `_never_meet` set it with `_on_the_line`,
   the walk tested no step of it, and the top went 168° the wrong way
   before a stop was looked for. Its moving part is rated now
   (`_pair_parts`), and the pair is asked where that part has gone
   `PATH_LDU`, as a part is tested: asked at every step the arm's other
   parts were, the made crane's drag ran past its share and was shown on
   trust. A click hinge's just past each click it crosses, where it stands:
   a drag's frame steps it 22.5° at once, and 4903-1's, asked at each of the
   walk's ten steps, ran past the share, shown at 67.5° on trust, past where
   its plate meets its base (1.09 LDU at 55°, 3.44 at 90°); asked only where
   a move ends, the made one went 157.5° through its base. It stops at 45°
   now; on 3978c6f7 it went on to 90°, where its covers met the model.

Measured, judged as Grab judges them (`--only=hingerange`):

| hinge | the wrong way | there, LDU | a step on | the open way | there | a step on |
|---|---|---|---|---|---|---|
| 3937/3938 | 5.9° | 0.99 | 1.14 | 95.4° | 0.98 | 1.17 |
| 2429/2430 (1 x 4 swivel) | 2.8° | 0.98 | 1.33 | all 170° | 0.31 | 0.31 |
| 44301a/44302a (click, 22.5° clicks) | 90° | 0.04 | 1.93 | 90° | 0.04 | 1.93 |

3937/3938's top by angle: 0.51 LDU into its base at -3°, 1.00 at -6°, 1.90
at -12° (pose136's 1.90), 3.93 at -30°; the open way no more than 0.09 to
90°. The click hinge's two ways are alike (its plates end to end).

**Left as it was: a loop's pair into each other where the grab began** is
still forgiven whole. Judged but for its pin, 8448-1's racer steered 22° of
30 and stopped where a universal joint's end (#446, 3712) met its centre
(#316, 3326b) by 1.10 LDU, a piece of the end's fork tip against the
centre's other arm, which a pure turn about their pin keeps apart: the
loop's solve closes to a tolerance and the centre is posed by its own
reading. A loop's pair clear of each other where the grab began is judged
whole, as before.

The probes' made models with 3937/3938 had their hinges facing the way
their tests need: `MADE_PATH`'s arm turned towards the plate the wrong way
and now faces it (the other way its own base stops it at 6°), and
`pose_probe`'s turret stop, -17° on the baseplate since §34, is now -6° on
the hinge's own base.

### Checked

On the final code: `grab_probe` whole in a window, 489 passed and one
failed, the big model's section held by a worm (7191-1, `--only=big`),
which fails the same on 3978c6f7. `--only=hingerange` (9), `--only=path`
(6), `--only=falling` (26, its drag checked every frame, as on 3978c6f7),
`--only=click` (9, the stop at 45°). `pose_probe` (25), `motions_probe`
(92), `animation_probe` (24) and `mechanism_probe` (54) pass.

The steering sweep on 20 sets (`sweep_hinge77x`, all but 42024-1 with
hinges in the loop they steer: 8880-1_F1-Racer, 8448-1_Racer, 8830-1, 8062-1_Crane, 8820-1,
8022-1_Racecar, 8832-1, 8841-1_Buggy, 8815-1, 8022-1_Robot, 8854-1,
8835-1_Farm-Tractor, 8020-1_Jeep, 8845-1, 5510-1, 8828-1, 8808-1, 8848-1,
950-1, 42024-1) against `sweep_joins72`: all 20 steer, each turn and its
way back the same to the hundredth, but 8841-1_Buggy back 0.007 LDU where
it was 0.015.

The drag's cost, each alternated with 3978c6f7, two rounds:

| | 3978c6f7 | this |
|---|---|---|
| 42081-1's arm (`--only=actuators`), the drag's own work a frame | mean 9.3 and 7.3 ms, 95% 14.4 and 13.1 | mean 8.6 and 7.6, 95% 15.0 and 14.1 |
| 8808-1's steering on a phone, the CPU slowed 4 times (`play_flow --sizes=phone`) | mean 9.28 and 9.29 ms, worst 20.86 and 20.79 | mean 10.10 and 9.08, worst 22.57 and 19.65 |

Turned alone, a turntable's two halves are now judged every frame: its
drag 1.88 ms a frame on average (4096-1), 1.58 (30181-1), worst 3.9.

The full sweep is the lead's: from a locked snapshot of this,
`SWEEP_OUT=bench/results/grab17-2026-10-20 tools/steer_sweep.py run hinge77
--jobs=3`, then `table hinge77 --against=joins72`; the bar is every set
that steers in joins72 (77) steering, nothing lost.

### The browser checks' cranes (pose148)

Two browser checks built the crane with its hinge the blocked way too.
`flex_pose_flow.mjs`, run by no release from m124 to m145, failed in m146:
its arm, asked -45° and then 45°, stopped at -22° on the base's shoulder
from 1d27522c (21b2f95b reached -45°), at -6° on the top's own base from
8d1aa81d, and at 17° on the baseplate the other way throughout. The
`grab_flow.mjs` arm's drag up stopped at -5.9° and passed its 5° by 0.9.
Both now have the hinge turned about up: the slider keys the arm at 44°,
and the drag turns it 37.1°.

## 36. A pinion at its rack's end, and a loop kept open (Grab 22)

Grab 20 left two sets of the steering sweep coming back wrong (section 31):
8466-1 37 LDU off at a universal joint's centre (#1165), 5533-1 6.43 LDU
off at a wheel (#368). Each was measured on main (4ac4fc83) by a scratch
probe calling `move_part` as the sweep does (+30, -60, then back by the
turn measured), reading the loop's coordinates at every step.

### 8466-1: a pinion carried off its rack

8466-1's track rod is a rack 1 x 10 (6592, #723) sliding on an axle, with
four 8 tooth pinions under it: two on the steering's columns (#735, #736),
and one free on an axle pin at each end (#734, #739), each 70 LDU from the
rack's middle, where its last tooth's middle is 68. A pinion is read in a
rack while it stands within `Racks.ALONG_SLACK` (4 LDU) past the last
tooth, and the loop is held by all four. The sweep turns the first pinion
it finds: #734, at the end.

| turn | rack, LDU | #734 past the last tooth | read after it |
|---|---|---|---|
| as built | 0 | 2.00 | 4 pinions in the rack |
| +30, stopped at 11° | +1.92 | 0.08 | 4 |
| -60, stopped at -23° | -2.09 | 4.09 | 3: #734 is out |
| back, +11.7° | -2.09 | 4.09 | 3 |

So the turn back found #734 a gear free on its pin, "1 body move
together", and turned it and its pin alone: the rack and the 64 parts the
loop had moved stayed where the second turn left them. #1165 had not turned
with the pinion, as section 31 read it: it went round with the loop, 33.96
LDU off after the first turn and 36.92 after the second, and the third did
not move it.

1. **A loop carries no pinion past where it is read in its rack**
   (`Linkage._within`, `Racks.room_along`): each pinion the loop is held by
   stays within its rack's teeth and `ALONG_SLACK`, as read where the move
   began, and a move that would carry it further stops there, as at a
   stop. 8466-1's second turn stops at -22° with the rack at -1.98 (the
   pinion 3.98 LDU past the last tooth), and the turn back turns the loop:
   the rack comes back to -0.01 LDU. Held to its own rack, the
   observatory's telescope (`motions_probe`) stopped at 225° of 675°: its
   tube carries 1 x 4 racks end to end, and the pinion runs on from one
   into the next. So the room is every rack of the rack's body whose teeth
   the pinion would stand in, met end to end along its line (`Racks._fit`,
   what `Racks.find` asks of a pinion but where along the rack).

8466-1 still does not come back: the worst part is now #651, a universal
joint drawn as one part (9244, "Complete Assembly Shortcut"), 10.74 LDU
off. As built it is one body with the axle in its near end (#653); after
the first turn the steered wheel's half-shaft (#658) lines up with its far
end, and it is read one body with that hub (#644), which the second turn
turns 5.6°; after the second it is read one body with the frame, and the
turn back leaves it there. A universal joint read as one rigid part is
joined to whichever shaft lines up with it where the model stands.

### 5533-1: a loop kept open

5533-1's track rod is the rack (6630, #38) in its groove, pinned at each end
(3749 in its hole) to an arm (32068) on a kingpin; each kingpin is on a
steering arm (32069) read on one pin in a round hole, free to turn about it
and to slide out along it 10 LDU, and not in. Turned, an arm's pin goes
round a circle 40 LDU about its kingpin while the rack's hole goes along a
line: they part by 40(1 − cos θ), 0.05 LDU at 2.9°, 0.24 at 6.3°. The loop
closes exactly only by sliding a steering arm out along its pin, which
each side can do one way of the two.

| turn | rack, LDU | left arm | its steering arm slid, LDU | left pin out of its hole, LDU | right arm | its steering arm slid | right pin out |
|---|---|---|---|---|---|---|---|
| +30, to 25° | +4.43 | 3.4° | 2.05 | 0.07 | 6.3° | 0 | 0.24 |
| -60, to -30° | -5.31 | 7.6° the other way | 0.01 | 0.35 | 3.1° | 7.44 | 0.06 |
| back | +0.03 | 7.6° | 5.33 | 0.35 | 3.1° | 2.16 | 0.06 |

"Out of its hole" is the pin against the hole as built, each carried as its
own part moved. Two things together:

- **A move keeps a loop open.** The first turn's steps closed on the way
  (`Linkage.ON_THE_WAY`, 0.5 LDU) with the right pin 0.01, 0.04, 0.09, 0.15
  and 0.24 LDU out; the last did not close to `CLOSE_TO` (0.05), nothing
  between closed to it either, and `Linkage._reach` kept the step before,
  0.24 LDU open.
- **The next move reads it closed.** A closing joint's two halves are read
  at one point, where the parts stand, so a gap a move left is forgotten.
  Turned back, the left arm closes its real gap but reads as opening one;
  its steering arm slides out instead, and the arm stays turned 7.6°.

Tried and not kept: the last step kept only where it closes to `CLOSE_TO`,
else back to the furthest step that did. Each move then leaves 0.05 LDU at
most; the steering turns 11° and -13° (the rack +2.02 and -2.53) and comes
back 3.05 LDU off (#368): a steering arm slid out on one turn has nothing
to bring it back on the next, which turns the arm instead. Less steering,
and still not back.

### Left

- **5533-1**: read a closing joint where each half has it (the pin's line in
  one part, the hole's in the other), so a gap one move leaves is closed by
  the next, not taken as closed. The way back then closes the real gaps; but
  a model built with a pin off its hole's middle (as Joints allows, within
  `Mechanism.LINE_SLACK`) would begin every move with a gap to close, so it
  wants the whole sweep first. The steering arms' one way slides would still
  be freedom the loop takes.
- **8466-1**: read a 9244 as a universal joint, its two ends turning against
  each other, as `Bodies.universals` reads a cross in two ends. It is in
  three OMR files.
- The sweep turns 8466-1 at an end pinion free on its pin, not at either
  column.

### Checked

On the final code, in a window (`tools/probe.sh grab_probe`): `--only=grooved`
6 (on 4ac4fc83 the two new checks fail: the turn back "2 parts on a pin
without friction", the rack back to -2.09 LDU), `groups` (4), `loops` (21),
`bigstep` (4), `hinge` (27), and the whole probe, 496 passed and none
failed (`actuators` and `cases` within it: the wheel loader's arm 95% 13.0
ms of the drag's own work a frame, the small actuator 13.8). `motions_probe` 92 of 92 (with the pinion held to its own rack
alone, 10 failed: the telescope stopped at 225°), `telescope_probe` (32),
`mechanism_probe` (54) and `own_copies_probe` (33) pass.

The steering sweep on 19 sets (the five 8448-1 files, 5533-1, 8466-1,
42125-1, 8808-1, 8820-1, 8880-1_F1-Racer, 8841-1_Buggy, 9393-1, 42043-1,
42024-1, 42070-1, 6753-1, 6753-1_Tow-Truck, 8054-1_Model-C;
`sweep_grab22y`) against `sweep_hinge77`: 18 the same to the step, 16
steering as there; 8466-1's rack back to -0.01 LDU where it stayed at
-2.09, and its worst part 10.74 LDU off (#651) where it was 36.92 (#1165).
The whole sweep is the lead's: from a locked snapshot of this,
`SWEEP_OUT=bench/results/grab17-2026-10-20 tools/steer_sweep.py run grab22
--jobs=3`, then `table grab22 --against=hinge77`; the bar is every set that
steers in hinge77 (77) steering, nothing lost.

## 37. A universal joint drawn whole, and a loop measured from how it was built (Grab 23)

Grab 22 left 8466-1 coming back 10.74 LDU off at a universal joint drawn as
one part (#651, 9244), and 5533-1 6.43 LDU off at a wheel (#368), its loop
kept open by one move and read closed by the next (section 36). Each was
measured on m140 (4c747508) by a scratch probe calling `move_part` as the
sweep does (+30, -60, then back by the turn measured).

### 8466-1: a universal joint drawn whole

9244 is a shortcut for 3712c01, which LDraw draws as two 4L ends and a
centre in one part (3712c01-c03, 575c01-c02, 4240416 and the 3L 61903 the
same). Its connectors make one axle hole along its whole length, its middle
at the centre, so an axle reaching within 2 LDU of the centre was keyed to
it (`Joints.through`): as built the drive shaft (#653) was, and the
half-shaft in its far end (#658), 20 LDU short, was not. After the first
turn the half-shaft lined up with it and it was keyed to the wheel's hub;
after the second, to the frame; the turn back left it 10.74 LDU off.

1. **A universal joint drawn whole is its cross** (`Bodies._whole_crosses`,
   `Bodies.whole_cross`): a body of its own, joined by nothing but a hinge
   to the shaft in each end, at its middle, on that end's fork line, as
   `_cross_in_forks` pins a two-part joint's centre. LDraw draws each with
   its first end towards -z (Godot's frame), its fork across x, and the
   second turned a quarter round towards +z, its fork across y. An end's
   shaft is an axle square to its fork's line, through the middle, reaching
   into the end from its side: where the joint has bent, the shaft no longer
   lies along the part. Read from the connectors (an axle hole along z and
   two pairs of fork bores across x and y at the middle), as a browser has
   them. `Bodies.universals` then reads it as it reads a two-part joint, and
   the gear reading keys no shaft to it (`Mechanism._build`), so a turn
   passes through it as through the two-part kind. Posed as its cross, its
   drawn ends stand off its shafts as it bends: the pair is not tested by
   their shapes (`Grab._meeting_pairs`).

8466-1's front half-shafts run from the joint (x=±100) to a wheel spindle's
axle driver (32494) at the steering's kingpin (x=±210): the steering turns
about the axle driver's ball, and the half-shaft does not steer. Lodged in
the wheel as one piece with it, it had steered, and carried the joint off.
As its cross, the joint stays where its shafts are.

8466-1 then came back 0.199 LDU off at its steering column's top centre
(#1165, 3326b), which hangs 220 LDU from the pinion column it turns with
(#736): the rack came back 0.011 LDU off its driver, and the column turned
0.069° with it.

### 5533-1: a loop measured from how it was built

5533-1's steering arms swing on circles while its rack's holes go in a line,
so its loop closes exactly only by sliding a steering knuckle (32069) out
along its axle (section 36). The first turn kept a step that closed only on
the way (0.24 LDU open), and the next read it closed.

2. **A closing joint and a rack are measured from how their two parts were
   built** (`Linkage._from_built`): the far half's point and line are where
   the near half's stood against it as built (`Grab._built_at`, where a grab
   first moved each part), and a rack's teeth from where its pinion stood in
   them, turn and all. A gap a move left is closed by the next; a gap built
   into the model is nought, so a pin built a little off its hole starts no
   move with one to close. Two parts further than 1 LDU from how they were
   built (`FROM_BUILT_MOST`) were rebuilt, not left open, and are read as
   they stand.
3. **A move keeps only a closed pose** (`Linkage._reach`): where the last
   step does not close and nothing short of it does, the step before is
   closed all the way there, else the move goes back to the furthest step
   that closed all the way. Grab 22 tried this alone: 11° and -13°, back
   3.05 LDU off. With 2. alone, the second turn found the loop open by 0.24
   LDU where no turn closed it, and did not move.
4. **A loop turned back to where it was built goes back as it was built**
   (`Linkage._closes_built`): where the driver stands within 0.001 of its
   turn as built, the last step is tried first with every slide the loop has
   to spare where it was built, and closed on past a fifth of `CLOSE_TO`, as
   long as each round takes a tenth off what is left, to `CLOSE_FINE`
   (0.0005 LDU). Least change kept a slide the way out took: 5533-1's
   knuckle slid 2.9 LDU out on the second turn, and on the way back its arm
   turned to make up for it, the wheel 0.28 LDU off. And closed only to a
   fifth of `CLOSE_TO`, 8466-1's rack came back 0.011 LDU off its driver, and
   its steering column, turning with a pinion in that rack, 0.199 LDU off at
   its top centre.
5. **A session's move closes its last step on too** (`Linkage.fine`, set
   where `Grab.budget_ms` has no end: a session's move and the check after a
   release, not a drag's frame). Closed on only back where built, 42024-1 and
   8880-1_F1-Racer came back 0.012 and 0.019 LDU off, near the sweep's 0.02.
   Closed on at every drag frame's end, the wheel loader's arm took 1 ms more
   of its 95th frame (14.4 and 15.1 ms, m140's 13.0 and 13.9).

On the scratch probe and the sweep, turned +30, -60 and back:

| | 5533-1, rack | back, LDU | 8466-1, rack | back, LDU |
|---|---|---|---|---|
| m140 | +4.43, -5.31 | 6.43 (#368) | +1.92, -1.98 | 10.74 (#651) |
| 1. | | | +1.92, -1.98 | 0.199 (#1165) |
| 1., 2. and 3., every last step closed on while each round halved what is left | +2.03, -2.07 | 1.106 (#370) | +1.92, -1.99 | 0.068 (#1165) |
| the same, while each round takes a tenth | | 0.278 (#370) | | 0.002 |
| 1. to 4. | +2.02, -2.07 | 0.003 | +1.92, -1.99 | 0.005 |
| 1. to 5. | +2.02, -2.07 | 0.0034 | +1.93, -1.99 | 0.0053 |

5533-1 steers less far: its loop closes to `CLOSE_TO` only that far, and
the 4.43 LDU it went before was with a pin 0.24 LDU out of its hole.

### Checked

On the final code, in a window (`tools/probe.sh grab_probe`): the whole
probe, 499 passed and none failed, three of them new in `--only=grooved`
(9): 5533-1 and 8466-1, turned as the sweep turns them, come back within
0.003 and 0.005 LDU, and 8466-1's four 9244s are each a cross on two hinges
square to each other. `groups` (4), `loops` (21), `bigstep` (4), `hinge`
(27) and `cases` (72) pass alone too. `mechanism_probe` (54),
`own_copies_probe` (33), `motions_probe` (92) and `telescope_probe` (32)
pass.

A drag's frame, `--only=actuators` alternated with m140 (4c747508), the
drag's own work a frame, 95th:

| | m140 | this |
|---|---|---|
| the wheel loader's arm | 14.6, 14.9 ms | 14.0, 14.1 |
| the small actuator | 15.6, 15.1 | 14.0, 13.9 |
| the forest machine's crane | 16.7, 17.8 | 18.0, 17.3 |

38 checks each; in two earlier rounds, one of each side, 42024-1's rod was
not found under the pointer from any of three views (section 30's pick).

The steering sweep on 20 sets (`sweep_g23u`: 5533-1, 8466-1,
5533-1_Tractor-Pulling, the five 8448-1 files, 41999-1, 42070-1, 8848-1,
8854-1, 8862-1, 8880-1_F1-Racer, 42125-1, 8808-1, 8820-1, 8841-1_Buggy,
42024-1, 9393-1; twelve with a universal joint drawn whole), against
`sweep_grab22`: all 20 steer, where 17 did. 5533-1 comes back 0.0034 LDU
off, 8466-1 0.0053 and 5533-1_Tractor-Pulling 0.0157 (0.090 before); every
other set comes back as near as before or nearer, 42070-1 0.0002 where it
was 0.0199 (its rack +8.02 and -8.02, where it was +1.98 and -14.12).

### Left

- **5533-1 steers less far**: +2.02 and -2.07 LDU where it went +4.43 and
  -5.31 with a pin 0.24 LDU out of its hole. Its loop closes to `CLOSE_TO`
  only that far; a real set's pins have play this does not.
- **How each part was built is kept for the session** (`Grab._built_at`,
  started again when parts are added or taken away): a model saved with a
  gap a move left and opened again reads the gap as built.
- **Back where it was built** is the driver within 0.001 radian of its
  turn as built: a drag passes it only by chance, and a slide its loop has
  to spare stays where least change left it.
- **A universal joint drawn whole is posed as its cross**: its drawn ends
  stand off its shafts by the bend, and its shape is not tested against
  theirs.
- **8466-1's steering column** hangs on its lower universal joint only: the
  top joint's far end (#999, 3712) stands 4.7 LDU off the centre in the
  file, past `SAME_LINE`, so the column swings with its pinion's column,
  34 LDU at its top for an 11° turn.
- The whole sweep is the lead's: from a locked snapshot of this,
  `SWEEP_OUT=bench/results/grab17-2026-10-20 tools/steer_sweep.py run grab23
  --jobs=3`, then `table grab23 --against=grab22`; the bar is every set that
  steers in grab22 (77) steering, and 5533-1 and 8466-1 with them.

## 38. Gears put in mesh by hand (gears186)

walk180 (2026-10-23, item 3) built two 24s on axles three studs apart in the
web app. Each went on its axle wherever the pointer was along it, and they
stood a stud apart in depth. Sliding one towards the other moved the whole
axle through its brick until the axle's end reached the hole ("2 parts on
its axle: not moved"). Turning one did not turn the other, and nothing said
why. Studio and LDCad put a gear on the Technic hole grid, so a pair lines
up.

### Why

- **Where a gear goes on an axle** was the pointer's alone
  (`JointSnap.ways`: a hole on an axle anywhere along it, in whole LDU). The
  gear beside it was never asked.
- **The slide** moved the grabbed part's whole body. A gear keyed on its
  axle is one body with it, so the axle slid in its round hole, as far as
  it stays in the hole, and then no further.
- **Meshing** was right all along: `Mechanism` meshes two gears whose
  planes are within 6 LDU. These were 20.75 apart.

### What was done

- **A gear in hand on an axle seats in mesh** (`Builder._into_mesh`, from
  `GearMesh.shifts`). For each gear beside the axle, it finds where along
  the axle the gear in hand meshes it: parallel, at right angles (bevels,
  double bevels, a crown and a spur) and with a worm. Each place is checked
  by `Mechanism.couple`, the coupling test `_find_couplings` now shares, so
  a seat here is a mesh there. Within `GearMesh.CAPTURE` (30 LDU) of the
  pointer, and with room, the gear goes there. The status line says "in
  mesh with the 24 beside it (24 teeth to 24)", or why not.
- **A bevel's teeth face where the axles cross.** Which face is read from
  the part's box: 6589's crossing is on its -z (app axes) in all 319 pairs
  of two in the OMR's sets, 4143's and 87407's on +z, a crown's on -z.
- **Where only the other gear stands wrong** (a bevel's partner too far
  from where the axles cross, a worm's gear out of its plane), the gear in
  hand seats for its own half and says what the other needs: "meshing the
  12 bevel beside it, once it is slid along its axle: it stands 22 LDU
  from where the axles cross, and meshes this one at 17".
- **A gear goes on by the hole in its middle** (`Builder._on_its_middle`).
  The 36 went on by a hole a stud from its middle. The 16's hole is drawn
  0.28 LDU off its middle, so two 16s turned each other 1:1.02. Real sets
  stand a gear's middle on its axle.
- **A gear dragged along its axle slides on it** (`Grab._slide_on_axle`).
  The gear and what is fixed to it move, and the axle stays. It goes as far
  as its hole stays on the axle and the parts on the axle let it. It stops
  in mesh within `GearMesh.SNAP` (4 LDU), and a gear it slides into mesh
  with is not in its way.
- **Why two gears beside each other do not mesh is said** as one goes
  down and as the other is turned (`Grab.mesh_words`): "their axles are 80
  LDU apart where a 24 and a 24 mesh at 60, 20 LDU too far"; "its axle is
  square to this one's, and gears like these mesh only on parallel axles";
  "...meshes it where the Technic Bush with Two Flanges is in the way".

### Checked

`tools/probe.sh gear_mesh_probe` builds each pair by pointing and turns the
first 30° with Grab. Spurs 8/24, 24/24, 16/16, 12/20, a 36 and a 12 double
bevel, and 40/8 turn by their teeth to 0.001°, the other way. Bevels 12/12,
20/12 and double 12/20 at right angles mesh once the first is dragged into
mesh. A worm turns a 24 1/24 as far. A 24 on an axle in a crossblock's pin
hole turns its partner 1:1. All 40 checks pass; on 8c0cc501 34 of 42 fail.

### Left

- **The first gear of a pair at right angles** has nothing to mesh when it
  goes down, so it goes where the pointer is. The second seats for its own
  half and says how far to slide the first.
- **A gear on an axle held rigidly** (in an axle hole of the frame) cannot
  be grabbed at all, so it cannot be slid either.
