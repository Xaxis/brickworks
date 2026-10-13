# Mechanisms: gears that turn, and models that stand while they do

The owner asked for "the ability to build and record accurate physics
simulations of gear/Technic mechanics". Two more things were added on
2026-10-13:

- **The acceptance demo is a working LEGO orrery.** It is a gear train whose
  ratios give each planet its real orbital period relative to the others. A
  crank or a motor drives it, and it is simulated and recorded. It should be
  the first thing that works end to end.
- **Balance and strength.** Claude flagged this itself on the owner's orrery:
  "Brickworks checks that the parts connect, not physical balance… Neptune's arm
  still reaches about 18 studs past the base edge, so swing that arm hard at
  your own risk."

This file is the research, the plan and the proof of concept. Nothing here is a
feature yet. The proof of concept is `src/dev/mechanism_probe.gd` (recipe in
`.claude/skills/verify/features/geometry.md`).

## In short

- **Kinematics comes first and is mostly solved already.** The parts already
  record their axles, pins, holes and studs. A gear's pitch radius is 1.25 LDU
  per tooth. That number was measured on real sets: 764 of 809 candidate gear
  pairs in the OMR's Technic sets agree to 0.3 LDU or better.
- **The core works on a real set.** It is one linear equation per gear mesh
  and one unknown per joint. It turns LEGO 8020's windmill 9:1 from crank to
  sails, read straight off the set's file, with every frame of the drawing
  checked against the tooth counts. It also turns a two-planet orrery. It
  reports a locked train and names the meshes that lock it.
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
  published a measured LEGO clutch force. Dynamics would be qualitative. The
  section [What "accurate" can honestly mean](#what-accurate-can-honestly-mean)
  says why.

## 1. What exists elsewhere

**No LEGO tool simulates dynamics.** The ones that move mechanisms all do
driven kinematics: a driver moves, and everything else is solved from
constraints.

| tool | what it does | how | source |
|---|---|---|---|
| SR 3D Builder (Reano, last release 2014, abandoned) | Detects connections and rotation axles. Animates gear trains, differentials, racks, worms, linear actuators, pneumatics, Jansen linkages and flexible parts. | Kinematic solver with a pre-pass that finds "triangled undeformable structures" (rigid groups). Large models solve slowly. Meshing was never documented. No gravity or collisions. | [ldraw wiki](https://wiki.ldraw.org/wiki/Sr3d), [0.6.0.8 notes](https://forums.ldraw.org/thread-1212.html), [0.8.9.16 notes](https://forums.ldraw.org/printthread.php?tid=9215) |
| LDCad (Melkert) | Animation by Lua script. Flexible parts (hoses, chains, springs) are generated along paths. | Nothing is inferred: the script sets every part's pose each frame. The author said gear trains "need extra information on many parts (tooth count, radius, gear type, etc)". | [script API](https://www.melkert.net/LDCad/docs/scriptAPI), [forum 2021](https://forums.ldraw.org/post-42067.html), [meta](https://www.melkert.net/LDCad/tech/meta) |
| BrickLink Studio | Hinge tool (turns everything connected about one pivot, with collision on mouse drags). Flex tool. Animation renders only building steps and camera turns. | No mechanism simulation. | [hinge](https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351-Hinge-and-Rotation-tool), [render](https://studiohelp.bricklink.com/hc/en-us/articles/6507015818263) |
| Mecabricks | Keyframe and node animation with parenting. | Hand-made math. Gear-train inference was requested in 2020 and never answered. | [Brickset](https://brickset.com/article/53762/mecabricks-let-s-animate-our-bricks!), [Eurobricks](https://www.eurobricks.com/forum/forums/topic/177590-mecabricks-animation-tools) |
| LeoMCAD (CEIG 2018) | LEGO mechanical CAD with typed gear connectors (regular, crown, rack, worm, bevel). | Propagates motion depth-first. Constraints are enforced while assembling, not while simulating, so it moves mechanisms that Inventor locks. | [paper](https://diglib.eg.org/handle/10.2312/ceig20181163) |
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
- **Xu et al. 2019, *Computational LEGO Technic Design*.** It builds models
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
  geared up 40:8 would be clamped. LEGO scale needs the world scaled or the
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
| axle (male) through an `axle_hole` | rigid: the hole's part turns with the axle | the probe: holes on an axle's line, within its length |
| axle or pin through a `pin_hole`, or a round bore 6 LDU across | revolute about the line | the same |
| stud in a socket (`PartMesh.sockets`, at the part's underside) | rigid | the probe |
| two revolutes between the same two bodies on different lines | rigid: two pins through two beams | the probe, repeated until nothing changes |
| a pin that carries nothing keyed | not a body: what it joins turn against each other on its line | the probe |
| a turntable's top on its base | revolute about the base's axis | the probe (`TURNTABLES`); `Joints.rounds` already pairs them for the checker |
| a shaft in a coaxial bore of its size (clip on bar, hinge, turntable) | revolute | `Joints.rounds`, which the Poser already turns |

**Gears: the tooth count is only in the name.** "Technic Gear 24 Tooth" is the
only place the catalogue says 24. The probe keeps a table (`GEARS`) of kind,
tooth count, hole (axle or round), and the offset of the pitch plane for
right-angle meshes. A pitch radius of 1.25 LDU per tooth is module 1 mm. That
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

The scripts were scratch work and were not kept. P1a's pipeline check is where
they belong.

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

1. **A gear table as data.** Move tooth count, kind, hole, face offset, axis
   and plane into `assets/knowledge/gears.json`. Generate it from the names and
   check it in the pipeline in two ways:
   - Measured spacing in the OMR, as above.
   - Each part's outside diameter. A spur gear's is 2.5·(N+2) LDU: 24t 64.78
     against 65, 8t 24.86 against 25, 40t 104.7 against 105, 12t 35.39, 20t
     55.2. The 16t is 43.28 against 45; its teeth are short.
2. **Missing or wrong connectors.**
   - The 24 tooth gear 3648a/3648b/24505 has no `axle_hole` at its centre (its
     hole is drawn without the primitive). The table supplies it for now.
   - 3709b, a Technic plate with holes, reads its three holes as bores but not
     as `pin_hole`s. The probe accepts a 6 LDU bore as a round hole.
   - 6542a, the 16 with clutch, has no hole at all.
   - 32062, the notched axle 2, reads its notch as an `axle_hole`. Fix these in
     `connectivity.py`; the probe works round them.
3. **Unmeasured right-angle offsets:**
   - the 28t and 36t double bevels (46372, 32498);
   - the 14t and 22t bevels (4143, 69761);
   - the bevels with a round hole;
   - the 60t turntable's plane;
   - the quarter ring 24121, four of which make the 140 tooth inner ring that
     the best LEGO orreries use.
   
   Measure them from the sets the same way.
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

It records on request. That is what lets the designer build a mechanism and
then prove it turns, the same loop it already uses for `check_design`.

## 4. Balance and strength

**Phase S1 at rest is built** (2026-10-13): `src/assembly/balance.gd`, over
the Pose panel's animation or every joint swept through its reach
(`Poser.sweep`), in Tools, Check stability and in check_design's result. The
gear-driven sweep waits for the mechanism module: it hands its frames to
`Balance.measure` as poses. What follows is the research it was built from.

**What the app checked before it** (`src/assembly/stability.gd`):

- every stud joint's load against **80 g per stud**;
- whether the load's centre of mass falls past the joint's footprint
  ("levered");
- a slenderness limit.

Its comment calls ~1 N per stud "the LEGO Group's own figure". That number is
not published: LEGO's book says "the ideal strength's value must remain
secret" (Konstanski, *The Secret Life of LEGO Bricks*, p. 22,
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
| **P1a Gear trains** | `src/assembly/mechanism.gd` lifted from the probe. The gear table as data with its pipeline check. Connector fixes (3648, 3709b, 6542a, 32062). Ring gears (inner mesh: centres r_ring − r apart, same sense), chains on `Flex.SPROCKETS` (same sense, tooth ratio), racks with measured pitch lines, clutch gears and driving rings, the differential (two freedoms: two drivers, or one and a held output). Locked, free and floating reports. | The probe's cases plus: the OMR's sets with the most gears (42055: 122 gears, 42082: 102) read without a floating drivetrain body; 42179's year train read as 121.5:1 from its file if it can be got; a differential's Willis relation. | 4–5 agent days |
| **P1b Simulate mode** | The panel (pick a driver, play, scrub, record), bodies tinted by speed, locked meshes highlighted. `simulate_mechanism` over MCP with its compact result, and `tools/mcp_tools.json` regenerated. | A windowed probe that clicks an axle and records. `tools/mcp_check.py` driving it the way a Claude session does. | 3–4 days |
| **P1c The orrery** | Periods read out as planet years ("Mars: 1.96 Earth years; NASA 1.8808, +4.2%"). Turntables (56, 60) and the 140 tooth ring. A ratio search for the designer: the gear trains on the stud grid within n stages that come nearest a target. Every LEGO tooth count factors into primes ≤ 7 (bar the 22), so 365.25 = 3·487/4 can only be approximated; Brocot's method finds the nearest ([AMS](https://www.ams.org/featurecolumn/archive/stern-brocot.html)). | **Acceptance:** an orrery of at least the eight planets, built in the app by the owner or by Claude over MCP. Every arm's period within the error its gear train claims, checked frame by frame off the renderer as the probe does. Recorded to MP4 and WebP. | 2–3 days, plus the build |
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
  - **Phase.** Backlash leaves a few degrees; LEGO's own SPIKE motor spec is
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
  - Friction and damping in LEGO joints are unmeasured.
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

## 7. The proof of concept

`src/dev/mechanism_probe.gd`, phase 1's core and nothing else: no UI, nothing
kept in the app. Run it with:

```sh
godot --headless --path . --script src/dev/mechanism_probe.gd
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/mechanism_probe.gd
```

Run 2026-10-13, windowed (the headless run gives the same ratios and skips the
pictures):

```
a real set: 8020's windmill (OMR)
  57 parts, 5 bodies (the ground 40 parts), 4 joints in the tree, 0 closing loops, 0 floating; 4 gears, 2 meshes
ok    two meshes: the 24 with an 8, and the crown at right angles with the other 8 (parallel 8-24, right angle 24-8)
ok    the crown's axle turns 24/8 = 3 times the crank's, the other way (-3.000000)
ok    the sails' axle turns 3 x 3 = 9 times the crank's (9.000000)
ok    the sail plates go round with their axle (free on it, followed)
ok    windmill: in every frame drawn the sails turns 9.0000 times the driver's step, to 0.0000°
the same two axles, also joined 16 to 16
ok    it is locked, and says so (locked: the meshes ask for two different turns at once)
ok    ...naming both meshes as the ones that fight (["parallel 8-24", "parallel 16-16"])
a worm driving a 24
ok    the 24 turns once for 24 turns of the worm (1/24.0000)
a two-planet orrery: Earth on the central axle, Mars on a turntable, one crank
ok    Earth's arm turns 28/20 = 1.4 times the crank, the other way (-1.400000)
ok    Mars's arm turns 20/28 of the crank, the other way (-0.714286)
ok    a Mars year is 1.9600 Earth years here, against 1.8808: +4.2%, (28/20)^2 the nearest two meshes of these gears give
ok    orrery: in every frame drawn Mars's arm turns 0.7143 times the driver's step, to 0.0000°
mechanism: gear trains read off the parts, every ratio its tooth counts', a locked train named, and the windmill and the orrery turned
```

The pictures are in `shots/mechanism/` (16 windmill frames and 24 orrery
frames, each as PNGs and a WebP).

**The windmill is LEGO 8020's windmill**, from the OMR
(`8020-1_Windmill.mpd`, 57 parts, as published). The file was not touched. The
probe found:

- the frame: 40 parts held by studs and by 8 friction pins, two pins to each
  joint;
- three turning axles;
- the sails: six plates threaded on their axle by round holes, free on it and
  following it;
- the crank: a steering arm keyed to the first axle.

The 24 drives an 8 (3:1). That axle's crown gear drives an 8 at right angles
(3:1 again). The sails turn 9 times for every turn of the crank. Every frame of
the drawing was read back off the renderer's copy, and the sails' step was 9
times the crank's to 0.0000°.

**The orrery** is hand-placed: Earth's arm on the central axle, Mars's arm
pinned across a 28 tooth turntable round that axle, and both driven from one
crank three studs away. Its Mars year is (28/20)² = 1.96 Earth years, against
NASA's 686.98 / 365.256 = 1.8808: +4.2%. Two meshes of these spacings can't do
better. A second stage, (24/16)·(20/16) = 1.875, would be −0.3%. That is P1c's
ratio search.

**What it found:**

- The connector data is enough for bodies and joints once a few parts are
  patched (§2's gaps). A gear table is the one thing that has to be added.
- Two rules made the frame one body: studs in sockets, and two revolutes
  between the same two bodies on different lines. Without them, 8 floating
  pins and 6 pieces of frame hung off the axles.
- The locked train needs no special case. The equations contradict, and
  dropping each mesh in turn names the ones that fight.
- Loops of fixed axes stay linear. A joint closing a loop adds five equations
  and no new kind of solver.
- A worm is one more term in the same equation (the thread's lead). Its
  direction depends on a handedness not yet read from the part.
