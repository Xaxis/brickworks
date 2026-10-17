# Connections: what the build check holds in real sets

Every set in the LDraw model repository holds together in reality, so every part
the build check calls floating in one is a gap in the connection data or the
joint types, and every pair it would refuse as overlapping is a collision cover
that is not the part. `tools/connection_audit.py run` checks every file as an
edit is checked for what it leaves hanging (only the ground holds), and `report`
writes this page. Rerun both after any change to `tools/ldraw/connectivity.py`,
`tools/ldraw/occupancy.py`, the catalogue or the checker's joints
(`src/assembly/joints.gd`).

**Coverage: 93.97% of part instances held, from 70.00%** — 637,318 of 678,214 in 1,572 files (1,262 sets), where 470,265 were.

- Floating: 40,896 part instances, from 201,505.
- Files whole (nothing floating): 794, from 474.
- Overlapping pairs (covers that are not the part): 958,272, from 1,012,593.
- Read off their place (the reading cannot put the part where the file has it, most often a part turned about two axes at once): 46,077 instances, of them 5,967 floating.
- Not in the catalogue, so not checked: 233 distinct parts summed over files.

Each cluster of floating parts (floating parts touching each other) is put down
to one joint: of the joints between it and the held parts it touches, the first
in this table's order, read off what the two parts are and which of their
connectors meet there. *Instances* is the floating parts so put down.

A row can rise. A part that touched another's cover counted as held while
covers were boxes; now that a cover is the part's shape, the joint it lacks
shows, and a cluster that was held is put down to it.

## By connection type

| Connection | Instances | Before | Clusters | Files | Commonest joint (floating part on held part) | What is done about it |
|---|---:|---:|---:|---:|---|---|
| stands a little off the ground in the file | 13,108 | 98,881 | 161 | 78 | 90498 on  (3257), 3021 on  (1746), 6015 on  (1072) | Fixed for most (joints4): opening a file stood the model on each part's box, and a turned part's box hangs below it, so a car on wheels drawn spun on their axles stood up to 12 LDU in the air on them; a turned part is now measured by its cover (`Lbm.PartMesh.lowest_at`), and a file another tool drew up in the air comes down onto the ground (`ModelStore.lift_for`). Within a cell of the ground a part stands on it by its shape (`Assistant._on_the_ground`). Left: 3 to 8 LDU up, a model drawn with something under the table (a figure's feet under a car's tyres); allowing that much would let a design's part hover. |
| stands on parts the catalogue does not have | 5,877 | 56,771 | 143 | 63 |  | Fixed in part (joints4): a part a file carries is built from the subparts and primitives the file carries for it (`LdrModel.embedded_sources`); only parts were read, by bare name, and 1,401 carried parts could not be built. Left: parts neither LDraw nor the file has (unofficial treads, tyres, panels). |
| read off its place | 0 | 12,970 | 0 | 0 |  | Fixed (joints4): a part turned two ways is read in a section turned so (agent angles), and what the reading still cannot say — a figure's parts, which it reads at the nearest square turn, and pieces LSynth draws sheared and stretched — is checked where it stands when nothing has moved it (`Assistant._joined_at`). And a retired number is the new part where its stub puts it (`PartLibrary.moved_by`): 68 stubs turn or shift it, and 3139's tyres stood turned across their own axles. A cluster is put down here only where the check puts a part off its place; the reading's own misses are counted above. |
| touches nothing held | 8,945 | 8,243 | 690 | 207 |  | Left: nothing held within a cell of the cluster: parts hung on strings and chains drawn as paths, held by a missing part, or placed apart in the file. And 75272's TIE fighter, whose stand's columns (95347, which the file carries and is built now) the file draws hanging down through the plate they stand on, leaving the fighter on nothing. |
| Technic pin or axle | 1,074 | 3,473 | 235 | 123 | 6538b on 32072 (164), 63965a on 32064a (94), 4032a on 30360 (86) | Fixed in part by agent axles: an axle holds every hole along it (`Joints.through`). Left: holes drawn without a hole primitive, and pins in parts read off their place. |
| Technic, no pin or axle at the contact | 1,515 | 3,433 | 369 | 155 | 3749 on 5540 - formula i racer - 4185a (354), 3004 on 3673 (102), 42078 - 209b on 32523 (86) | 3895 on 6636 was 10283's stand: the shuttle's pins are parts the file carries, drawn from a friction rib it carries as a primitive, and are built now (joints4). Left: 42069's body on its treads, links the file carries and are built now, held by the sprockets they wrap round, which no connector says. |
| click hinge | 1,891 | 3,308 | 44 | 29 | 44301a on 3068b (1482), 44302a on 21318 - 44301b (170), 21318 - 44301b on 44302a (56) | Fixed: LDraw's clh* primitives read as a finger and a fork on the line they turn on (`connectivity._HINGES`), paired by `Joints.rounds`. And the older finger hinges (4275b's three fingers, 4276b's two), whose fingers' ends are rounds on one line, a finger of one between two of the other (`Joints._knuckles`, joints4). Left: where LDraw draws the halves off one line (6682's, opened 30 degrees, 2.4 LDU apart), and 10240's X-wing, which rests on its stand: the stand's top tile meets the hinge plates under the body with no connector at the contact. |
| studs that do not clutch | 1,341 | 3,002 | 228 | 112 | 2878 on 57878 (540), 4597 on 2431 (138), 98138 on 30414 (124) | Fixed in part (joints4): a wheelset's axle ends are pushed into 2878's cups, which its cover fills, and what is pushed into what holds (`Joints.pushed_in`), so 4558's and 10001's cars stand on their bogies, drawn 2.25 LDU off the cups. Left: 2878 on 10183's wheels 57878 and on 4533's wheelsets, whose ends the cover does not reach: the cups are pointed half cones (2-4con0), which nothing reads as a bore. |
| hose, string or chain | 872 | 2,691 | 53 | 29 | 752 on 4081b (278), 32523 on 15379 (222), 752 on 2419 (116) | A flexible thing is one thing (`Flex.one_thing`), and so are a hose LSynth drew, whose pieces a file carries named LS and a number, and every piece LDraw draws one element in (a pneumatic tube's ends with its segments; joints4). Left: flexible parts (chain links, treads, strings) drawn segment by segment are held by what they wrap round, which no connector says. |
| no connector at the contact | 1,565 | 1,531 | 283 | 144 | 4180c02 on 3228b (186), 40379 on 3003 (137), 3030 on 74747 (136) |  |
| bar in a hole or tube | 452 | 1,260 | 133 | 82 | 63965a on 26287 (67), 30504 on 6190 (38), 3612 on 792 (37) |  |
| magnet | 1,169 | 1,089 | 46 | 30 | 2959 on 2920 (906), 2959c01 on 2959c01 (134), 4022c01 on 4022c01 (80) | Left: the magnet 2959 in its holder 2920, whose ring nothing reads as a bore (4558's and 10001's trains, coupled by them). |
| clip on bar or handle | 218 | 1,056 | 67 | 45 | 3941 on 30237 (36), 4735 on 3023b (27), 2655 on 4477 (20) | Fixed where the clip's eye is up to 1.5 LDU off the bar (`ROUND_OFF_AXIS`, was 1), as LDraw draws a clip turned to an odd angle. `attachment_points` lists bars and clips and a part goes on one by axis and joint. |
| ball and socket | 898 | 496 | 36 | 23 | 21311 - 92013 on 53585 (388), 57909 on 21321 - international space station - 92013 (296), 21311 - 92013 on 90630 (98) | Fixed where the ball is turned in its socket (`Joints.balls`). Left: Technic ball joints whose socket is drawn as plain cylinders. |
| minifig on the model | 449 | 720 | 157 | 90 | 3034 on 973p1c (125), 30104k01 on 32278 (46), 30104k01 on 32013 (42) |  |
| towball | 689 | 514 | 125 | 58 | 6628 on u9053 (416), 3183a on 2508 (119), 2739a on 6628 (27) | Fixed for a towball in a Joint-8 socket: a whole sphere 16 LDU across reads as a ball and `Joints.balls` holds it in a socket at its middle at any turn. Left: the older towball sockets (3491) are drawn from chords and have no socket connector. |
| hinge | 110 | 646 | 69 | 50 | 3479 on 3937 (32), 2348b on 2349a (25), 3475b on 4315 (12) | Left: hinge panels (2440) and plates whose pin is a half cylinder under 2 LDU. Old finger hinges (4275/4276) hold by their knuckles where they lie on one line (`Joints._knuckles`). |
| turntable | 36 | 492 | 2 | 2 | 3403 on 3069bp06 (34), 4032a on 3680c01 (2) | Left: Technic chain tread round a turntable (3873 on 18938), which is a chain. |
| tyre on wheel | 68 | 450 | 8 | 4 | 6014bc02 on 4162 (61), 54086 on 44309 (4), 55976 on 56145 (2) |  |
| pane or door in its frame | 447 | 435 | 165 | 91 | 3030 on 4865b (130), 3665a on 4510 (77), 4346 on 4345b (26) |  |
| minifig part on minifig part | 119 | 17 | 25 | 21 | 30104k02 on 30104k01 (85), 4714 on 3819 (11), 30104k01 on 30104k02 (5) |  |
| minifig hand grip | 28 | 2 | 13 | 11 | 3070a on 3820 (14), 2447 on 3820 (3), 4593 on 3820 (2) | Fixed (joints4): what is pushed into what holds (`Joints.pushed_in`), as it made a figure one piece. A file swings an arm about the torso's line and not its own, so the arm's peg is off its socket's line and no round pairs them; read square it rested on the torso, and checked where it stands the arm, its hand and what the hand held hung in the air. |
| electric | 22 | 21 | 8 | 7 | 593 on 3009 (11), 8868 - 2839a on 2838 (3), 24849 on 42113 - 24851 (2) |  |
| sticker | 2 | 2 | 2 | 2 | 148 - 004589b on 004589e (1), 197875a on 3008 (1) |  |
| rubber band | 1 | 2 | 1 | 1 | 4185a on 3794a (1) |  |

## By part: the gaps that block the most

*Blocks* is the floating instances put down to a joint on this part's side;
*floating* is how many of this part itself float.

| Part | Name | Blocks | Floating | Files | Joint |
|---|---|---:|---:|---:|---|
| 44301a | Hinge Plate  1 x  2 Locking with Groove with Single Finger o | 1,482 | 43 | 8 | click hinge 1482 |
| 2959 | ~Magnet Cylindrical Casing (Obsolete) | 906 | 8 | 4 | magnet 906 |
| 2878 | Train Wheel Bogie Single Axle without Wheelset | 605 | 26 | 6 | studs that do not clutch 605 |
| 21311 - 92013 |  | 486 | 18 | 2 | ball and socket 486 |
| 752 | Hose Flexible End  1 x  1 x  0.667 without Tabs | 448 | 43 | 13 | hose, string or chain 448 |
| 6628 | Technic Pin Towball with Friction | 416 | 23 | 8 | towball 416 |
| 3749 | Technic Axle Pin | 360 | 64 | 22 | Technic, no pin or axle at the contact 360 |
| 6141 | Plate  1 x  1 Round | 317 | 1,236 | 240 | Technic, no pin or axle at the contact 168, Technic pin or axle 61 |
| 57909 | Brick  2 x  2 with Ball Joint and Axlehole | 296 | 2 | 1 | ball and socket 296 |
| 3030 | Plate  4 x 10 | 266 | 26 | 13 | no connector at the contact 136, pane or door in its frame 130 |
| 98138 | Tile  1 x  1 Round with Groove | 234 | 306 | 20 | studs that do not clutch 172, no connector at the contact 62 |
| 32523 | Technic Beam  3 | 229 | 38 | 10 | hose, string or chain 222, Technic, no pin or axle at the contact 7 |
| 63965a | Bar  6L with Thick Stop | 221 | 12 | 6 | Technic pin or axle 153, bar in a hole or tube 68 |
| 4180c02 | Brick  2 x  4 Black with Train Wheels Small (Complete) | 186 | 12 | 4 | no connector at the contact 186 |
| 44302a | Hinge Plate  1 x  2 Locking with Dual Finger on End Vertical | 170 | 86 | 10 | click hinge 170 |
| 6538b | Technic Axle Joiner Offset | 169 | 29 | 7 | Technic pin or axle 165, bar in a hole or tube 4 |
| 8868-1 - myrubbercyl |  | 161 | 161 | 1 | Technic, no pin or axle at the contact 161 |
| 4032a | Plate  2 x  2 Round with Axlehole | 159 | 176 | 57 | Technic pin or axle 109, minifig on the model 39 |
| 21034 - ls41 |  | 156 | 152 | 1 | no connector at the contact 156 |
| 2959c01 | ~Magnet Cylindrical in Casing (Complete) (Obsolete) | 146 | 21 | 14 | magnet 146 |
| 4597 | Cockpit  6 x  6 | 138 | 2 | 2 | studs that do not clutch 138 |
| 40379 | Animal Tail Section End | 137 | 8 | 1 | no connector at the contact 137 |
| 3004 | Brick  1 x  2 | 126 | 518 | 72 | Technic, no pin or axle at the contact 114, Technic pin or axle 12 |
| 3034 | Plate  2 x  8 | 125 | 142 | 53 | minifig on the model 125 |
| 3183a | Plate  1 x  4 with Towball Socket Long with  2 Slots | 119 | 1 | 1 | towball 119 |
| 4477 | Plate  1 x 10 | 108 | 134 | 33 | no connector at the contact 96, bar in a hole or tube 12 |
| 50254 | Train Wheel Small with Notched Hole | 104 | 8 | 2 | no connector at the contact 104 |
| 30104k01 | Minifig Chain End for Chain  6L and 17L | 93 | 12 | 5 | minifig on the model 88, minifig part on minifig part 5 |
| 3665a | Slope Brick 45  2 x  1 Inverted without Inner Stopper Ring | 89 | 171 | 36 | pane or door in its frame 77, no connector at the contact 10 |
| 42078 - 209b |  | 86 | 82 | 1 | Technic, no pin or axle at the contact 86 |
| 30104k02 | Minifig Chain Link for Chain  6L and 17L | 85 | 156 | 7 | minifig part on minifig part 85 |
| 4595 | Brick  1 x  2 x  0.667 with Studs on Sides | 81 | 46 | 23 | studs that do not clutch 77, hinge 4 |
| 754 | ~Hose Flexible Segment Link Section | 80 | 531 | 7 | hose, string or chain 80 |
| 4022c01 | Train Buffer Beam with Black Coupling Type 1 with Magnet in  | 80 | 12 | 3 | magnet 80 |
| 3062b | Brick  1 x  1 Round with Hollow Stud | 76 | 226 | 60 | Technic, no pin or axle at the contact 40, no connector at the contact 16 |
| 42120 - 42135 |  | 74 | 2 | 1 | Technic pin or axle 74 |
| 32278 | Technic Beam 15 | 72 | 11 | 4 | Technic pin or axle 72 |
| 3943b | Cone  4 x  4 x  2 with Axlehole | 72 | 10 | 6 | studs that do not clutch 72 |
| 364 - ls60 |  | 69 | 68 | 1 | no connector at the contact 69 |
| 6014bc02 | Wheel Rim 12 x 11 with Notched Hole with Tyre 12/ 40 x 11 Wi | 61 | 4 | 1 | tyre on wheel 61 |
| 2739a | Technic Steering Link  6L Type 1 | 59 | 62 | 27 | towball 52, ball and socket 6 |
| 21318 - 44301b |  | 56 | 10 | 2 | click hinge 56 |
| 3612 | Arm Piece with 2 and 3 Fingers Aligned | 54 | 33 | 6 | bar in a hole or tube 37, no connector at the contact 17 |
| 4070 | Brick  1 x  1 with Headlight | 50 | 248 | 57 | no connector at the contact 42, Technic, no pin or axle at the contact 8 |
| 4346 | Container Box  2 x  2 x  2 Door with Slot | 49 | 63 | 38 | pane or door in its frame 38, minifig on the model 4 |
| 4589 | Cone  1 x  1 | 48 | 228 | 76 | no connector at the contact 14, studs that do not clutch 13 |
| 4740 | Dish  2 x  2 Inverted | 48 | 159 | 70 | Technic, no pin or axle at the contact 18, studs that do not clutch 16 |
| 993 | ~Electric Cable 3LDU Twin | 48 | 122 | 3 | hose, string or chain 48 |
| 2447 | ~Minifig Helmet Visor Standard (Obsolete) | 48 | 65 | 56 | no connector at the contact 40, minifig on the model 5 |
| 3703 | Technic Brick  1 x 16 with Holes | 48 | 19 | 7 | Technic, no pin or axle at the contact 48 |
| 8258 - ls70 |  | 45 | 376 | 1 | no connector at the contact 33, Technic, no pin or axle at the contact 12 |
| 3666 | Plate  1 x  6 | 45 | 369 | 73 | no connector at the contact 44, studs that do not clutch 1 |
| 3941 | Brick  2 x  2 Round without Reinforcement | 45 | 136 | 26 | clip on bar or handle 36, bar in a hole or tube 8 |
| 14704 | Plate  1 x  2 with Socket Joint-8 with Friction Centre | 45 | 21 | 6 | ball and socket 45 |
| 30553 | Hinge Arm Locking with Dual Finger and Axlehole | 44 | 15 | 11 | click hinge 44 |
| 3024 | Plate  1 x  1 | 41 | 624 | 96 | Technic, no pin or axle at the contact 34, no connector at the contact 5 |
| 32556a | Technic Pin Long without Friction with Single Slot | 41 | 54 | 12 | Technic, no pin or axle at the contact 41 |
| 30162 | Minifig Binoculars with Round Eyepiece | 40 | 46 | 24 | minifig on the model 39, minifig part on minifig part 1 |
| 32062 | Technic Axle  2 Notched | 39 | 131 | 28 | Technic pin or axle 39 |
| 32293 | Technic Steering Link 9L | 39 | 37 | 13 | towball 35, bar in a hole or tube 2 |
| 3136 | Crane Hook with  4 Studs | 39 | 1 | 1 | no connector at the contact 39 |
| 30504 | Plate  8 x  8 without Corner | 38 | 2 | 1 | bar in a hole or tube 38 |
| 73092 | ~_Magnet Cylindrical in Casing Black (Obsolete) | 37 | 33 | 21 | magnet 37 |
| 70814 - 43903a |  | 36 | 36 | 1 | no connector at the contact 36 |
| 32449 | Technic Beam  4 x  0.5 Liftarm | 36 | 22 | 5 | Technic pin or axle 36 |
| 26287 | Technic Axle Joiner  3L | 35 | 40 | 16 | Technic pin or axle 33, Technic, no pin or axle at the contact 2 |
| 3479 | Tail  4 x  2 x  2 | 34 | 14 | 5 | hinge 32, studs that do not clutch 2 |
| 3403 | Turntable  4 x  4 Base | 34 | 1 | 1 | turntable 34 |
| 2780 | Technic Pin with Friction and Slots | 32 | 580 | 36 | Technic, no pin or axle at the contact 32 |
| 4733 | Brick  1 x  1 with Studs on Four Sides | 32 | 31 | 11 | no connector at the contact 21, Technic, no pin or axle at the contact 11 |
| 3641 | Tyre  6/ 50 x  8 Offset Tread | 30 | 131 | 30 | studs that do not clutch 18, bar in a hole or tube 8 |
| 3700 | Technic Brick  1 x  2 with Hole | 30 | 129 | 32 | Technic, no pin or axle at the contact 30 |
| 6539 | Technic Transmission Driving Ring | 30 | 29 | 14 | Technic pin or axle 30 |
| 2348b | Glass for Hinge Car Roof  4 x  4 Sunroof with Ridges | 29 | 35 | 31 | hinge 29 |
| 42131 - 42135 |  | 29 | 5 | 1 | Technic pin or axle 29 |
| 6558 | Technic Pin Long with Friction and Slot | 28 | 242 | 17 | Technic, no pin or axle at the contact 28 |
| 61678 | Slope Brick Curved  4 x  1 | 28 | 100 | 14 | no connector at the contact 28 |
| 3960 | Dish  4 x  4 Inverted | 28 | 41 | 22 | studs that do not clutch 10, no connector at the contact 9 |
| 4735 | Brick  1 x  1 x  0.667 Round with Bar and Clip Vertical | 28 | 7 | 3 | clip on bar or handle 28 |
| 59443 | Technic Axle Joiner Inline Smooth | 26 | 92 | 20 | hose, string or chain 18, Technic, no pin or axle at the contact 7 |

## False overlaps: covers that are not the part

A real set's parts do not overlap either, so every pair the check would refuse
as overlapping is a collision cover wrong (`tools/ldraw/occupancy.py` builds them),
or the reading's: a part read a little off where the file has it. The check
excuses overlaps between parts already standing, and keeps them for this count
(`Assistant._standing_overlaps`).

Two parts a joint joins (a ball in its socket, a bar in its clip, a pin in its
hole, a hinge's knuckles) meet inside the joint by their real shapes, and the
check holds that to be the joint, not an overlap (`ExactCheck.at_joint`):
`src/dev/joint_collisions.gd` counts those of real sets, and docs/DESIGN_SCORES.md
("Technique: joints held by their real shapes") says what they were and are.

- Overlapping pairs: 958,272, of them 645,108 with a part read off its place.
- Files with none: 150 of 1,572.

| Part | Name | Pairs | Before | Files | Commonest partner |
|---|---|---:|---:|---:|---|
| 77 | ~Technic Flex-System Hose Segment | 54,604 | 76,357 | 15 | 77 (51885), 8012 - 41663 (415), 32013 (320) |
| 71533k03 | ~Technic Pneumatic Tube Segment | 52,804 | 39,089 | 17 | 71533k03 (49096), 71533k01 (930), u9190 (497) |
| u9218 | ~Electric Power Functions  2.0 6-Wire Ribbon Cable Segment | 44,526 | 41,250 | 12 | u9218 (41362), 64178 (332), 42131 - 25560 (308) |
| u9190 | ~Electric Power Functions 4-Wire Ribbon Cable Segment | 30,324 | 28,848 | 9 | u9190 (29409), 71533k03 (497), 42043 - 2850b (79) |
| 6989 - ls60 |  | 11,671 | 39,154 | 1 | 6989 - ls60 (10974), 4209a (665), 4208 (31) |
| 754 | ~Hose Flexible Segment Link Section | 6,057 | 6,040 | 28 | 754 (5309), 756 (262), 755 (207) |
| 3023b | Plate  1 x  2 | 3,764 | 3,492 | 392 | 3023b (134), 3020 (75), 3623 (74) |
| 3710 | Plate  1 x  4 | 2,560 | 2,432 | 305 | 3710 (76), 44568 (70), 3023b (61) |
| 3020 | Plate  2 x  4 | 2,369 | 2,347 | 305 | 3023b (75), 3710 (49), 3020 (46) |
| 98138 | Tile  1 x  1 Round with Groove | 2,257 | 2,176 | 84 | 98138 (1311), 30414 (92), 87079 (88) |
| 2780 | Technic Pin with Friction and Slots | 2,115 | 1,777 | 189 | 2851 (242), 32532a (123), 71533k03 (62) |
| 6141 | Plate  1 x  1 Round | 1,992 | 1,931 | 328 | 22885 (176), 6141 (71), 3623 (54) |
| 3623 | Plate  1 x  3 | 1,824 | 1,783 | 210 | 3023b (74), 6141 (54), 3710 (50) |
| 3460 | Plate  1 x  8 | 1,690 | 1,610 | 163 | 3710 (51), 3023b (50), 3460 (44) |
| 6632 | Technic Beam  3 x  0.5 Liftarm | 1,681 | 2,767 | 131 | 6632 (202), 6536 (67), 32123b (58) |
| 3024 | Plate  1 x  1 | 1,673 | 1,615 | 222 | 3024 (73), 3659 (68), 3023b (60) |
| 3021 | Plate  2 x  3 | 1,656 | 1,642 | 202 | 3023b (46), 3666 (40), 3623 (35) |
| 3666 | Plate  1 x  6 | 1,648 | 1,612 | 221 | 3710 (57), 3023b (44), 3021 (40) |
| 3022 | Plate  2 x  2 | 1,548 | 1,453 | 275 | 3020 (45), 3023b (42), 3641 (31) |
| 756 | ~Hose Flexible Segment Center Section | 1,535 | 1,526 | 53 | 756 (1246), 754 (262), 755 (13) |
| 3795 | Plate  2 x  6 | 1,498 | 1,508 | 197 | 3023b (49), 3623 (46), 3069b (35) |
| 41677 | Technic Beam  2 x  0.5 Liftarm | 1,435 | 2,312 | 103 | 41677 (201), 32123b (49), 32316 (48) |
| 32123b | Technic Bush 1/2 Smooth with Axle Hole Semi-Reduced | 1,278 | 2,012 | 122 | 56145 (102), 32123b (75), 6632 (58) |
| 71944k02 | ~Technic Ribbed Hose Mid Segment | 1,278 | 1,244 | 24 | 71944k02 (950), 43093 (43), 2780 (34) |
| 3069b | Tile  1 x  2 with Groove | 1,267 | 1,245 | 211 | 3023b (52), 3795 (35), 3710 (29) |
| 3004 | Brick  1 x  2 | 1,257 | 1,212 | 194 | 3023b (45), 14716 (42), 3004 (41) |
| 3713 | Technic Bush with Two Flanges | 1,220 | 1,347 | 237 | 56145 (212), 44309 (49), 15413 (39) |
| 2431 | Tile  1 x  4 with Groove | 1,198 | 1,185 | 174 | 3024 (47), 2431 (43), 3023b (42) |
| 56145 | Wheel Rim 20 x 30 with  6 Dual Spokes and External Ribs | 1,143 | 1,138 | 73 | 3713 (212), 44309 (109), 32123b (102) |
| 32123a | Technic Bush  1/2 Smooth with Axle Hole Reduced | 1,122 | 1,633 | 110 | 56145 (69), 6632 (49), 32056 (47) |
| 3005 | Brick  1 x  1 | 1,077 | 1,027 | 144 | 3005 (59), 3062b (40), 3023b (34) |
| 71533k01 | ~Technic Pneumatic Tube End (Bulged) | 1,055 | 984 | 18 | 71533k03 (930), 71533k01 (68), 42043 - 47222-v2 (6) |
| 6536 | Technic Cross Block 1 x 2 (Axle/Pin) | 1,037 | 1,279 | 126 | 77 (107), 6632 (67), 32123a (36) |
| 4162 | Tile  1 x  8 | 1,023 | 965 | 117 | 3029 (62), 2431 (39), 3023b (25) |
| 32140 | Technic Beam  2 x  4 Liftarm Bent 90 | 1,022 | 1,098 | 129 | 71533k03 (86), 32316 (48), 41677 (44) |
| 32524 | Technic Beam  7 | 1,020 | 1,041 | 96 | 71533k03 (80), 32278 (34), 2780 (32) |
| 3034 | Plate  2 x  8 | 1,008 | 984 | 146 | 3666 (33), 3023b (31), 3460 (27) |
| 4477 | Plate  1 x 10 | 927 | 860 | 102 | 3020 (26), 3004 (25), 3024 (25) |
| 32316 | Technic Beam  5 | 911 | 881 | 114 | 32140 (48), 41677 (48), 32523 (27) |
| 3068b | Tile  2 x  2 with Groove | 890 | 730 | 139 | 10261 - 25061 (24), 3020 (22), 3795 (21) |
| 6636 | Tile  1 x  6 | 873 | 866 | 102 | 24309 (58), 2412b (27), 3023b (26) |
| 2420 | Plate  2 x  2 Corner | 860 | 841 | 124 | 3023b (54), 2420 (52), 3623 (27) |
| 41497 - ls60 |  | 844 | 1,648 | 1 | 41497 - ls60 (559), 572c (282), 572a (3) |
| 3010 | Brick  1 x  4 | 841 | 768 | 159 | 3023b (24), 3009 (21), 4162 (20) |
| 6558 | Technic Pin Long with Friction and Slot | 834 | 683 | 117 | 2780 (39), 56145 (36), 32532a (24) |
| 3062b | Brick  1 x  1 Round with Hollow Stud | 832 | 775 | 125 | 3062b (98), 22885 (48), 18649 (44) |
| 2412b | Tile  1 x  2 Grille with Groove | 829 | 781 | 141 | 2412b (39), 6636 (27), 3795 (27) |
| 32449 | Technic Beam  4 x  0.5 Liftarm | 827 | 1,452 | 76 | 32449 (103), 71533k03 (49), 41677 (37) |
| 32013 | Technic Angle Connector #1 | 813 | 867 | 113 | 77 (320), 32123a (21), u9190 (21) |
| 32063 | Technic Beam  6 x  0.5 | 813 | 1,161 | 61 | 32063 (129), 45982 (30), 6632 (28) |
| 32278 | Technic Beam 15 | 801 | 904 | 81 | 71533k03 (103), 2780 (44), u9218 (39) |
| 32523 | Technic Beam  3 | 794 | 787 | 108 | u9218 (55), 56145 (48), u9190 (39) |
| 3032 | Plate  4 x  6 | 760 | 724 | 90 | 3032 (32), 3795 (21), 3023b (20) |
| 43093 | Technic Axle Pin with Friction | 759 | 505 | 115 | 71944k02 (43), 2654a (23), 10179 - 33299a (19) |
| 59443 | Technic Axle Joiner Inline Smooth | 749 | 818 | 95 | 77 (278), 32123b (32), 2780 (14) |
| 2852 | Technic Engine Connecting Rod | 749 | 652 | 70 | 2851 (344), 2852 (132), 2850a (95) |
| 4274 | Technic Pin  1/2 | 736 | 588 | 147 | 98138 (44), 6141 (39), 15413 (24) |
| 85984 | Slope Brick 31  1 x  2 x  0.667 | 724 | 691 | 83 | 85984 (38), 6134 (31), 3622 (28) |
| 57518 | Technic Chain Tread 5 Wide | 723 | 669 | 14 | 57519 (178), 57520 (142), 57518 (74) |
| 54200 | Slope Brick 31  1 x  1 x  0.667 | 720 | 692 | 118 | 86501 (30), 54200 (27), 3024 (23) |

## What the check said, summed over files

floating 40,896, off its studs 2,560, section adrift 318

## The files with the most floating

| File | Parts | Floating | Misread | Seconds |
|---|---:|---:|---:|---:|
| 76139-1.mpd | 3,292 | 3,257 | 12 | 84 |
| 8841-1_Combination-with-8700.mpd | 2,667 | 2,225 | 2,485 | 34 |
| 21311-1_Lions.mpd | 2,204 | 1,840 | 0 | 16 |
| 10240-1.mpd | 1,559 | 1,504 | 7 | 341 |
| 42052-1.mpd | 1,245 | 1,231 | 0 | 100 |
| 6597-1.mpd | 931 | 761 | 69 | 29 |
| 8147-1.mpd | 783 | 729 | 0 | 4 |
| 6542-1.mpd | 1,188 | 651 | 39 | 13 |
| 7637-1.mpd | 632 | 622 | 16 | 7 |
| 75953-1.mpd | 719 | 588 | 14 | 28 |
| 10183-1.mpd | 566 | 542 | 12 | 2 |
| 8161-1.mpd | 558 | 524 | 0 | 7 |
| 10283-1.mpd | 2,348 | 481 | 11 | 814 |
| 5770-1.mpd | 517 | 479 | 4 | 1 |
| 75272-1.mpd | 452 | 443 | 0 | 3 |
| 8258-1.mpd | 2,196 | 424 | 537 | 48 |
| 42106-1.mpd | 2,257 | 417 | 0 | 145 |
| 21311-1.mpd | 2,317 | 404 | 10 | 227 |
| 5985-1.mpd | 551 | 403 | 11 | 10 |
| 6346-1.mpd | 460 | 394 | 31 | 25 |
