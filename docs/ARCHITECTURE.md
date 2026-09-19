# Architecture

A dimensionally exact brick construction system: every part that has been
modelled, at true size, assembled under real connection rules, with a
design assistant that produces buildable models rather than plausible
pictures of them.

This document records what is decided and *why*, especially where the
obvious choice turned out to be wrong. Numbers here were measured, not
looked up.

---

## 1. The unit system

**1 LDU = 0.4 mm exactly.** Verified against the library rather than
assumed: `parts/3001.dat` (Brick 2 × 4) spans x −40…40, z −20…20,
y 0…24. Four studs over 80 LDU gives a 20 LDU pitch; `p/stud.dat` is a
radius-6 cylinder. That fixes:

| Feature | LDU | mm |
|---|---|---|
| Stud pitch | 20 | 8.0 |
| Brick height | 24 | 9.6 |
| Plate height | 8 | 3.2 |
| Stud diameter | 12 | 4.8 |
| Half-stud offset (jumper) | 10 | 4.0 |

LDraw models *nominal* size, omitting the ~0.1 mm per side of mould
clearance a real brick has. That is correct for CAD: parts tile exactly.

**LDraw has −Y up.** The application uses +Y up, so the conversion is
`(x, −y, −z)` — negating *two* axes, which is a 180° rotation about X and
therefore preserves handedness and polygon winding. Negating only Y would
mirror everything.

**1 Godot unit = 1 LDU.** Not metres. Every pitch stays a round integer,
the assembly lattice is integer arithmetic, and no scale factor appears
anywhere between the engine and the model. Physical size is a display
concern: multiply by 0.4 for mm.

---

## 2. Where the data comes from

**Geometry: the LDraw Parts Library.** 24,735 files in `parts/` —
18,645 parts, 4,961 shortcuts, 490 aliases, 506 fixed-colour moulds, 128
flexible sections.

**Licensing is clean and was checked before any converter was written.**
Every file carries `CC BY 4.0` (23,244) or dual `CC BY 2.0 and 4.0`
(1,491). CC BY permits commercial use and derivative works — a converted
mesh is a derivative — with attribution. See `docs/ATTRIBUTION.md` for the
required notice and the LEGO trademark constraints, which bind naming and
UI copy.

**Colours: `LDConfig.ldr`.** 322 colours with the finishes that decide
which shader a surface needs: 57 transparent, 59 rubber, 24 pearlescent,
24 speckle, 15 glitter, 11 metal, 7 chrome, 3 glow, 20 fabric.

---

## 3. The offline pipeline (`tools/`)

```
vendor/ldraw/*.dat
        │
        ├─ parser.py       line types 0–5, subfile matrices, BFC meta
        ├─ library.py      name resolution, curve substitution, caching
        ├─ geometry.py     recursive flattening → triangles
        ├─ colors.py       LDConfig → palette with finishes
        ├─ connectivity.py connectors from the primitives used
        ├─ occupancy.py    solid volume, collision boxes, sockets
        └─ meshfile.py     the .lbm binary the app loads
                │
        assets/generated/  catalogue.json + parts/<hash>.lbm
```

### Winding composes by XOR

Three independent things reverse a polygon's winding: a file declaring
`BFC CW`, a `BFC INVERTNEXT` before a reference, and a transform with a
negative determinant. They compose, and a mirrored reference inside an
inverted one cancels. Getting this wrong is invisible with two-sided
materials and glaring the moment culling is switched on.

### Smoothing splits at the author's edge lines

Smoothing every shared vertex rounds off the corner of a brick; smoothing
none turns a stud into a faceted drum. LDraw authors already mark hard
creases with type-2 edge lines, so the faces around each vertex are
partitioned into groups connected through *uncreased* edges only, and each
group gets its own normal. Measured on Brick 2 × 4: 252 axis-aligned faces
with zero normal deviation, 1,344 curved corners smoothed.

### Connectivity is recovered, not stored

LDraw holds no connectivity — it is a format for drawing, and a renderer
never needs to know a stud fits a tube. But authors do not draw a stud as
an anonymous cylinder; they reference `stud.dat`. Walking the reference
tree and noting every transform landing on a known connector primitive
recovers the author's intent at full precision.

Across the library: **196,541 studs, 44,656 tubes, 8,679 Technic pin
holes, 1,319 axle holes, 496 ridges, 335 axles, 326 pins, 271 clips.**

Two traps. Connector axes must be rotated by the accumulated transform, or
every sideways-mounted stud claims to point at the sky. And a Technic hole
is drawn either as one `beamhole` or as two `peghole` halves recessed into
opposite faces — counting primitives counts the second kind twice, so
halves sharing an axis line are merged.

### A tube is not a socket

The underside tube sits *between* four studs and grips them from outside,
so its position is not a place a stud goes. Worse, the smallest parts have
no tube at all — a 1 × 1 tile's cavity walls do the gripping — so 447
tiles declared no connectivity whatsoever while plainly accepting studs.

Sockets are derived instead, from a projection with its holes filled: take
the lowest plate of the part, flatten it, fill the enclosed voids. A
brick's hollow underside is exactly such a void, so what comes back is the
footprint rather than the ring of walls bounding it.

The result matches the stud positions recovered from primitives *to the
micron* on every studded part tested — two derivations sharing no code,
agreeing. And an arch reports sockets under its two legs and none under
its span, because there the underside is open to the outside rather than
enclosed.

---

## 4. The lattice is 2 LDU

This looks needlessly fine until a part is turned over: a brick 24 LDU
tall becomes 24 LDU wide, and 24 is not a multiple of 20. Studs-not-on-top
building is half of how modern sets are designed, so the lattice must hold
under a quarter turn about any axis.

The cell therefore has to divide 20 (stud pitch), 10 (half-pitch), 24
(brick) and 8 (plate). Their greatest common divisor is 2. **4 LDU does
not work** — a 1 × 1 brick spans −10…10, straddles a cell at each end and
measures 1.4 studs across.

Consequences, all good: positions are integers, collision is integer
comparison with no tolerance, and a model saved today loads identically
tomorrow.

**Studs are not part of a part's volume.** A stud ends up inside the part
above it; counting it would make every brick four plates tall and nothing
could stack. Parts are voxelised whole — keeping the mesh watertight and
the fill honest — and stud cells removed afterwards.

**Cavities are filled, layer by layer.** A brick's interior is hollow, but
nothing can be placed inside it. Filling per horizontal layer rather than
in 3D is deliberate: the cavity is open at the bottom, so a 3D fill from
outside reaches straight in, whereas in any single layer it is a closed
ring of wall. The same choice keeps arches honest — under the span the gap
runs out to the part's edge in that layer, so it stays open.

Most parts then reduce to **one** collision box; a slope is a staircase of
about twelve, an arch about twenty-eight.

---

## 5. The runtime (`src/`)

### Why not glTF

Godot imports glTF well, but ~23,000 parts would mean ~23,000 trips
through the import pipeline, ~23,000 `.import` sidecars and re-encoded
copies in `.godot/imported`. It is slow to build, enormous in the
repository, and impossible to stream — and the web build should fetch a
part's geometry only when someone places one.

`.lbm` is a small binary that maps onto the arrays `ArrayMesh` wants.

### Vertices are quantised

At 24 bytes a vertex the library came to **1.5 GB**. A position is now a
16-bit count of 1/64 LDU steps and a normal an octahedral pair: **10
bytes**, 47% smaller. Measured error: **3 µm** of position, **0.0013°** of
normal, against a 0.1 mm mould tolerance.

The step is fixed across the library rather than fitted per part, so a
vertex at x = 20 LDU encodes identically everywhere and surfaces that meet
in the real brick still meet here. Only 75 parts (long hoses, flex axles,
out to 1060 LDU) exceed 16 bits at that step and fall back to a coarser
one.

### Connectivity rides with the geometry

It was in the catalogue first. With 196,541 studs that pushed the
catalogue past 25 MB — seconds of parsing before the first frame, to
answer questions about parts nobody had placed. It shares the geometry's
lifetime exactly, so it lives in the `.lbm` and arrives in the same fetch.
The catalogue keeps only what browsing and searching need.

### Batching, and what it costs

One `MultiMesh` per (surface geometry, material class), keyed by content
hash so the many part numbers sharing a shape share a batch. Colour is
carried per instance, which is why one copy of a mesh serves every colour
the part was ever moulded in. Rebuilds are deferred to end of frame, so
dropping in a large model is not quadratic.

Measured on an M3 Max, Forward+: **200,000 bricks, 14 draw calls, 65 M
primitives/frame, 307 MB VRAM, 131 fps.** Frame time is flat from 1,000 to
200,000 bricks — geometry is effectively free and the ~7.6 ms is the
post-processing stack. The largest set the LEGO Group has ever sold is
about 11,700 pieces.

*This is desktop Metal. WebGL2 is a separate budget.*

### Four shaders, not one with flags

A shader fixes its cull mode and whether it writes `ALPHA` at compile
time, and writing `ALPHA` at all forces a material onto the transparent
path. So opaque/transparent × culled/uncilled are four files sharing one
`.gdshaderinc`. Two-sided is used only where LDraw declines to certify a
part's winding.

### Picking marches the lattice

`MultiMesh` has no per-instance collision, and giving each brick a physics
body would undo the batching. The occupancy grid is already there, so a
ray is marched through it: exact, costs nothing extra, and returns the
face that was entered as well as the brick — which is exactly what placing
the next part needs.

---

## 6. Still open

- **Web delivery.** 863 MB of geometry cannot ship wholesale. Plan: a core
  set resident, the rest fetched on demand. Threads need COOP/COEP headers,
  which the deploy sets.
- **The catalogue is still ~10 MB of JSON.** Fine on desktop; a binary
  format if startup needs it.
- **Stability.** Connection counting and centre-of-mass are cheap and
  worth having before anything cleverer.
- **The design assistant.** The LLM emits a structured placement DSL that
  is validated against the real collision and connection engine — it is
  never trusted with geometry directly.
