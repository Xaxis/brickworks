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
changed, on a worker from 300 parts (`GrabDrag._ready_ahead`), so a press finds
them read. On 7191 (1,312 parts) that takes 4 to 7 s on a loaded box; a press
on a big model before it is done says so and waits, rather than hold the
window. Each frame a moving part's box is asked of the lattice first, and its
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
