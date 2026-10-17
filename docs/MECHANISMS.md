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
| **P3 Forward dynamics** | Gravity moves things, friction, motor torque curves, collisions between moving parts. Jolt with the gear constraints bound through a GDExtension and the world scaled, or our own solver. | Pendulum periods. A gear train coasting down. Determinism per platform where it is promised. | 3–6 weeks; the riskiest |

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
- **Dynamics (S2, P3) is qualitative.**
  - Friction and damping in the joints of LEGO® parts are unmeasured.
  - Jolt is tuned for metres, and is deterministic only per binary.
  
  "This arm will swing past the edge if driven at full speed" is a fair claim.
  "It will fall at 1.7 s" is not.

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
fixture here; linkages (P2); the frames of a recording are tinted only in the
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
| one stud under a wider part | rigid: clutch holds it |
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
keyed to them. What hangs on a driven gear by a clip or a hinge does not yet
follow it. A **closed loop** (a four-bar, a crank and its rod, a steering rack
on its arms) is held at both ends: the drag says so and moves nothing. That
is P2.

**Physics on release, honestly.** A joint holds by friction or it does not.
A pin's name says which: "with Friction Ridges" (2780, 43093, 6558) holds; a
pin without (3673, 3749, 4274) turns freely, as builders use them
(Eurobricks, "Technic pins: to friction or not to friction"). An axle in a
round hole and a turntable turn freely; hinges, clips, click hinges, balls
and a stud hold. Let go, a free joint swings down to where the centre of mass
of what it carries is lowest, or to what stops it: quasi-static, no swing
back. Then Balance: stands, or tips and over which edge, and the most loaded
stud joint against its working load. "About", because a stud's clutch is not
published (above): honest to a factor of two.

**Ready before the press.** The bodies, the graph Balance weighs
(`Balance.prepare`) and the gear trains (`Mechanism.build`, anchors as the
ground) are read once a model revision, a quarter of a second after it last
changed, on a worker from 300 parts (`GrabDrag._ready_ahead`), so a press finds
them read. Each frame a moving part's box is asked of the lattice first, and
its turned cover is worked out only when something it may hit is near it.

**Live structure.** The graph read ahead is weighed for each pose alone
(`Balance.weigh_pose`) every 50 ms: the support polygon and the centre of
mass on the floor, stud joints past half their working load tinted amber to
red, the model drawn leaning 4° over the edge it would tip over, and a line
in the status bar. The model, its lattice, its history and its revision are
untouched until the button comes up (`BrickWorld.set_drawn`); then the pose
is one undo step. Escape puts it back.

**Over MCP**, `move_part`: part= a part's number or a sub-assembly's name.
Alone it changes nothing and says what would move, on what joint, whether it
holds or swings, and how the model stands. degrees= or along= move it as a
drag does and answer with what moved and the balance after.

**Left for later.** Inverse kinematics along a chain of joints (an arm's
shoulder, elbow and wrist dragged by the hand). Every modifier on a left drag
is the view's already (Alt turns, Shift slides, Ctrl draws a box or copies),
so the proposal is a press held still on the end part for 0.4 s before it is
dragged, or a Chain toggle on the hint strip; each joint's range is the
lattice's, so an IK step costs a room test per joint, which the box-first test
now makes cheap. Closed loops (P2); what hangs
on a driven gear following it; a free joint inside what moves settling too
(only the grabbed joint settles); dynamics (S2, P3); the click step measured
on real parts rather than read from retailers; settling a model that tips
(it is said and drawn leaning, not laid over).
