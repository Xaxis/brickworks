# Connections: what the build check holds in real sets

Every set in the LDraw model repository holds together in reality, so every part
the build check calls floating in one is a gap in the connection data or the
joint types, and every pair it would refuse as overlapping is a collision cover
that is not the part. `tools/connection_audit.py run` checks every file as an
edit is checked for what it leaves hanging (only the ground holds), and `report`
writes this page. Rerun both after any change to `tools/ldraw/connectivity.py`,
`tools/ldraw/occupancy.py`, the catalogue or the checker's joints
(`src/assembly/joints.gd`).

**Coverage: 65.51% of part instances held, from 58.00%** — 443,693 of 677,296 in 1,572 files (1,262 sets), where 392,834 were.

- Floating: 233,603 part instances, from 284,462.
- Files whole (nothing floating): 450, from 362.
- Overlapping pairs (covers that are not the part): 351,842, from 411,926.
- Read off their place (the reading cannot put the part where the file has it, most often a part turned about two axes at once): 101,710 instances, of them 67,044 floating.
- Not in the catalogue, so not checked: 1,365 distinct parts summed over files.

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
| stands a little off the ground in the file | 98,017 | 159,654 | 668 | 333 | 92912 on  (8651), 55976 on  (4345), 76139 - 43045 on  (3246) | Within a cell (2 LDU) of the ground a square part now stands on it (`Assistant._on_the_ground`): opening a file rounds its lift up to a whole cell, and a wheel's cover stops a cell above its tread. Left: 3 to 8 LDU up, a model drawn with something under the table (a figure's feet under a car's tyres); allowing that much would let a design's part hover. |
| stands on parts the catalogue does not have | 56,748 | 55,782 | 1,260 | 226 |  | Left: the file uses parts the catalogue has not got (unofficial treads, tyres, panels), and what stood on them has nothing under it. The catalogue's gap, not a joint's. |
| read off its place | 44,632 | 29,773 | 1,604 | 389 | 87407 on 88323 (7001), 71533k03 on 71533k03 (4810), 71533k03 on 32526 (3519) | Left: a part turned about two axes at once, which no section of one axis can say, so the reading puts it at the nearest square turn and its joints miss. Agent angles' sections at any angle are the fix. |
| touches nothing held | 11,239 | 10,578 | 675 | 215 |  | Left: nothing held within a cell of the cluster: parts hung on strings and chains drawn as paths, held by a missing part, or placed apart in the file. |
| Technic pin or axle | 3,149 | 8,525 | 324 | 150 | 2920 on 4022 (664), 28326 on 4519 (338), 4730 on 6118 (335) | Fixed in part by agent axles: an axle holds every hole along it (`Joints.through`). Left: holes drawn without a hole primitive, and pins in parts read off their place. |
| hose, string or chain | 3,115 | 3,722 | 65 | 41 | 77 on 77 (1484), 77 on 32039 (291), 752 on 4081b (276) | Left: flexible parts (chain links, treads, strings) drawn segment by segment are held by what they wrap round, which no connector says. |
| click hinge | 2,068 | 3,587 | 119 | 78 | 44301a on 3068b (1480), 4276b on 4275b (82), 4275b on 4276b (57) | Fixed: LDraw's clh* primitives read as a finger and a fork on the line they turn on (`connectivity._HINGES`), paired by `Joints.rounds`. |
| Technic, no pin or axle at the contact | 3,549 | 2,622 | 327 | 141 | 3895 on 6636 (1779), 32007 on 71372k02 (277), 3749 on 18977 (238) |  |
| no connector at the contact | 1,424 | 2,919 | 259 | 140 | 4180c02 on 3228b (186), 3030 on 74747 (136), 3857 on 3857 (128) |  |
| studs that do not clutch | 2,906 | 710 | 366 | 166 | 2878 on 70720c01 (1511), 2878 on 57878 (540), 4597 on 2431 (138) | Left, and more than before: 2878, a train bogie, held its wheelset 70720c01 only while both covers were boxes. Its bearings are not read as bores, so the axle in them is no joint, and the cars on 7 files' bogies float. |
| towball | 613 | 1,299 | 81 | 42 | 77 on 6628 (125), 3183a on 2508 (119), 3730 on 2508 (100) | Fixed for a towball in a Joint-8 socket: a whole sphere 16 LDU across reads as a ball and `Joints.balls` holds it in a socket at its middle at any turn. Left: the older towball sockets (3491) are drawn from chords and have no socket connector. |
| magnet | 1,083 | 945 | 57 | 31 | 64417c01 on 2878 (743), 2959c01 on 2920 (143), 735 on 7722 - x941 (82) |  |
| ball and socket | 454 | 952 | 30 | 20 | 15459 on 15460 (167), 57908 on 87408 (109), 62712 on 57909 (104) | Fixed where the ball is turned in its socket (`Joints.balls`). Left: Technic ball joints whose socket is drawn as plain cylinders. |
| bar in a hole or tube | 893 | 508 | 195 | 109 | 6157 on 6014a (189), 4488 on 6014a (174), 112-2 - x579 on 245c01 (68) |  |
| clip on bar or handle | 815 | 788 | 237 | 122 | 63868 on 60478 (92), 60478 on 48729a (67), 4735 on 3023b (41) | Fixed where the clip's eye is up to 1.5 LDU off the bar (`ROUND_OFF_AXIS`, was 1), as LDraw draws a clip turned to an odd angle. `attachment_points` lists bars and clips and a part goes on one by axis and joint. |
| minifig on the model | 712 | 351 | 239 | 125 | 3034 on 973p1c (125), 3711 on 3626b (90), 4210a on 3731 (87) |  |
| hinge | 623 | 520 | 167 | 97 | 6636 on 2429 (317), 4593 on 4592 (61), 2873 on 4315 (33) | Left: hinge panels (2440) and plates whose pin is a half cylinder under 2 LDU, and old finger hinges (4275/4276) drawn without clh primitives. |
| tyre on wheel | 441 | 509 | 40 | 23 | 18892 on 11209 (192), 4488 on 6014bc01 (85), 6014bc02 on 4162 (61) |  |
| pane or door in its frame | 437 | 214 | 171 | 89 | 3030 on 4865b (126), 3665a on 4510 (77), 3856 on 3853 (37) |  |
| turntable | 419 | 264 | 7 | 7 | 18938 on 32525 (366), 3403 on 3069bp06 (34), 4504 on 4508 (8) | Left: Technic chain tread round a turntable (3873 on 18938), which is a chain. |
| sticker | 229 | 181 | 226 | 62 | 191915i on 3008 (8), 4159998b on 4215b (6), 4188571b on 6111 (4) |  |
| electric | 21 | 29 | 19 | 9 | 6141 on 4170c01 (12), 70160 on 990 (2), 59494 on 919 (2) |  |
| minifig part on minifig part | 12 | 17 | 11 | 11 | 3837 on 3836 (2), 92257 on 3626c (2), 24093 on 24324 (1) |  |
| rubber band | 2 | 12 | 2 | 2 | 4274 on 4185a (1), 4185a on 3794a (1) |  |
| minifig hand grip | 2 | 1 | 2 | 2 | 61482 on 2377 (1), 2495c01 on 30383 (1) |  |

## By part: the gaps that block the most

*Blocks* is the floating instances put down to a joint on this part's side;
*floating* is how many of this part itself float.

| Part | Name | Blocks | Floating | Files | Joint |
|---|---|---:|---:|---:|---|
| 71533k03 | ~Technic Pneumatic Tube Segment | 10,769 | 17,759 | 17 | read off its place 10594, hose, string or chain 175 |
| 87407 | Technic Gear 20 Tooth Bevel with Peghole | 7,001 | 86 | 9 | read off its place 7001 |
| 57518 | Technic Chain Tread 5 Wide | 3,394 | 508 | 6 | read off its place 3394 |
| 77 | ~Technic Flex-System Hose Segment | 2,608 | 6,846 | 14 | hose, string or chain 1862, read off its place 621 |
| 8273 - ls60 |  | 2,235 | 2,226 | 2 | read off its place 2235 |
| 2878 | Train Wheel Bogie Single Axle without Wheelset | 2,051 | 52 | 7 | studs that do not clutch 2051 |
| u9190 | ~Electric Power Functions 4-Wire Ribbon Cable Segment | 1,885 | 3,514 | 9 | read off its place 1883, hose, string or chain 2 |
| 3895 | Technic Brick  1 x 12 with Holes | 1,779 | 122 | 29 | Technic, no pin or axle at the contact 1779 |
| 32140 | Technic Beam  2 x  4 Liftarm Bent 90 | 1,676 | 1,064 | 82 | read off its place 1672, Technic pin or axle 4 |
| 44301a | Hinge Plate  1 x  2 Locking with Groove with Single Finger o | 1,480 | 84 | 22 | click hinge 1480 |
| 756 | ~Hose Flexible Segment Center Section | 1,069 | 2,227 | 50 | read off its place 1065, hose, string or chain 4 |
| u9218 | ~Electric Power Functions  2.0 6-Wire Ribbon Cable Segment | 1,021 | 9,117 | 12 | read off its place 1015, hose, string or chain 6 |
| 754 | ~Hose Flexible Segment Link Section | 986 | 1,938 | 28 | read off its place 984, hose, string or chain 2 |
| 64417c01 | Train Buffer Sealed Magnet | 747 | 5 | 2 | magnet 747 |
| 71944k02 | ~Technic Ribbed Hose Mid Segment | 725 | 1,709 | 23 | read off its place 639, hose, string or chain 86 |
| 8841 - ls50 |  | 712 | 11 | 3 | read off its place 712 |
| 3034 | Plate  2 x  8 | 670 | 564 | 152 | read off its place 545, minifig on the model 125 |
| 2920 | Train Coupling Type 2 | 666 | 32 | 10 | Technic pin or axle 664, Technic, no pin or axle at the contact 2 |
| 7817 - ls60 |  | 608 | 583 | 1 | read off its place 608 |
| 6339 - ls60 |  | 558 | 548 | 1 | read off its place 558 |
| 9395 - ls60 |  | 503 | 502 | 1 | read off its place 503 |
| 752 | Hose Flexible End  1 x  1 x  0.667 without Tabs | 499 | 105 | 34 | hose, string or chain 446, read off its place 53 |
| 3820 | Minifig Hand | 495 | 854 | 211 | read off its place 495 |
| 6397 - ls60 |  | 431 | 430 | 1 | read off its place 431 |
| 6472 - ls60 |  | 431 | 430 | 1 | read off its place 431 |
| 30377 | Minifig Mechanical Arm with Clips Parallel | 424 | 54 | 17 | read off its place 424 |
| 6141 | Plate  1 x  1 Round | 416 | 3,283 | 452 | Technic, no pin or axle at the contact 144, read off its place 129 |
| 364 - ls60 |  | 413 | 834 | 1 | read off its place 413 |
| 18938 | Technic Turntable 60 Tooth Top | 366 | 9 | 7 | turntable 366 |
| 7750 - ls23 |  | 344 | 344 | 1 | read off its place 344 |
| 28326 | Car Mudguard  4 x  3 x  1 | 338 | 14 | 4 | Technic pin or axle 338 |
| 4730 | Brick  2 x  2 with Pin | 335 | 25 | 10 | Technic pin or axle 335 |
| 9391 - ls60 |  | 326 | 319 | 1 | read off its place 326 |
| 6636 | Tile  1 x  6 | 324 | 538 | 80 | hinge 317, read off its place 7 |
| 30104k02 | Minifig Chain Link for Chain  6L and 17L | 324 | 511 | 20 | read off its place 324 |
| 8841 - ls51 |  | 291 | 995 | 3 | read off its place 291 |
| 3068b | Tile  2 x  2 with Groove | 289 | 1,011 | 165 | Technic, no pin or axle at the contact 145, no connector at the contact 90 |
| 9390 - ls60 |  | 285 | 283 | 1 | read off its place 285 |
| 44302a | Hinge Plate  1 x  2 Locking with Dual Finger on End Vertical | 284 | 184 | 27 | read off its place 284 |
| 32007 | Technic Tread Sprocket Wheel | 277 | 16 | 3 | Technic, no pin or axle at the contact 277 |
| 4589 | Cone  1 x  1 | 270 | 733 | 157 | studs that do not clutch 99, read off its place 42 |
| 3030 | Plate  4 x 10 | 262 | 104 | 43 | no connector at the contact 136, pane or door in its frame 126 |
| 4488 | Plate  2 x  2 with 1 Wheel Pin | 259 | 78 | 20 | bar in a hole or tube 174, tyre on wheel 85 |
| 71533k01 | ~Technic Pneumatic Tube End (Bulged) | 255 | 318 | 14 | read off its place 255 |
| 10182 - ls51 |  | 252 | 248 | 1 | read off its place 252 |
| 3749 | Technic Axle Pin | 243 | 814 | 126 | Technic, no pin or axle at the contact 243 |
| 32062 | Technic Axle  2 Notched | 240 | 1,892 | 148 | read off its place 235, Technic pin or axle 5 |
| 3711 | Technic Chain Link | 233 | 440 | 12 | hose, string or chain 143, minifig on the model 90 |
| 32523 | Technic Beam  3 | 232 | 799 | 81 | hose, string or chain 222, Technic, no pin or axle at the contact 7 |
| 15459 | Technic Suspension Arm  1 x  5 Type 1 | 222 | 13 | 4 | ball and socket 167, read off its place 55 |
| 98138 | Tile  1 x  1 Round with Groove | 214 | 693 | 89 | read off its place 188, no connector at the contact 16 |
| 32034 | Technic Angle Connector #2 (180 degree) | 210 | 459 | 93 | Technic pin or axle 101, read off its place 101 |
| 2959c01 | ~Magnet Cylindrical in Casing (Complete) (Obsolete) | 209 | 44 | 18 | magnet 209 |
| 21034 - ls41 |  | 196 | 192 | 1 | read off its place 196 |
| 41497 - ls60 |  | 193 | 187 | 1 | read off its place 182, hose, string or chain 11 |
| 18892 | Brick  2 x  4 with  2 x  2 x  0.667 Cutout and 2 Wheel Pins | 192 | 2 | 1 | tyre on wheel 192 |
| 6157 | Plate  2 x  2 with 2 Wheel Pins Extended without Wishbones | 189 | 114 | 38 | bar in a hole or tube 189 |
| 4180c02 | Brick  2 x  4 Black with Train Wheels Small (Complete) | 186 | 13 | 4 | no connector at the contact 186 |
| 6989 - ls60 |  | 177 | 244 | 1 | read off its place 177 |
| 2458 | Brick  1 x  2 with Pin | 176 | 85 | 29 | Technic pin or axle 176 |
| 8868-1 - myrubbercyl |  | 174 | 174 | 1 | Technic, no pin or axle at the contact 95, read off its place 79 |
| 4005 - ls60 |  | 174 | 164 | 1 | read off its place 174 |
| 6538b | Technic Axle Joiner Offset | 168 | 109 | 19 | Technic pin or axle 164, bar in a hole or tube 4 |
| 3730 | Plate  2 x  2 with Towball Socket | 167 | 14 | 14 | towball 167 |
| 4593 | Hinge Control Stick | 161 | 306 | 115 | read off its place 95, hinge 64 |
| 4697b | Technic Pneumatic T-Piece - Type 2 | 161 | 45 | 18 | Technic pin or axle 160, Technic, no pin or axle at the contact 1 |
| 4032a | Plate  2 x  2 Round with Axlehole | 160 | 565 | 140 | Technic pin or axle 110, minifig on the model 39 |
| 32556a | Technic Pin Long without Friction with Single Slot | 159 | 666 | 74 | Technic pin or axle 118, Technic, no pin or axle at the contact 41 |
| 48729b | Bar  1.5L with Clip with Truncated Sides and Hole in Shaft | 153 | 143 | 43 | clip on bar or handle 103, read off its place 30 |
| 3673 | Technic Pin | 138 | 1,165 | 116 | Technic pin or axle 138 |
| 4597 | Cockpit  6 x  6 | 138 | 6 | 5 | studs that do not clutch 138 |
| 44728 | Bracket  1 x  2 -  2 x  2 Down | 137 | 391 | 70 | no connector at the contact 137 |
| 4276b | Hinge Plate  1 x  2 with 2 Fingers and Hollow Studs | 137 | 180 | 68 | click hinge 125, read off its place 12 |
| 4275b | Hinge Plate  1 x  2 with 3 Fingers and Hollow Studs | 136 | 109 | 46 | click hinge 130, read off its place 6 |
| 3062b | Brick  1 x  1 Round with Hollow Stud | 135 | 1,119 | 177 | read off its place 88, Technic, no pin or axle at the contact 21 |
| 98100 | Cone  2 x  2 Truncated | 132 | 19 | 4 | read off its place 130, minifig on the model 2 |
| 3710 | Plate  1 x  4 | 130 | 2,342 | 301 | Technic, no pin or axle at the contact 79, read off its place 38 |
| 4151a | Plate  8 x  8 with Grille without Hole | 130 | 6 | 2 | read off its place 130 |
| 3857 | Baseplate 16 x 32 with Square Corners | 128 | 12 | 8 | no connector at the contact 128 |
| 4477 | Plate  1 x 10 | 125 | 550 | 95 | studs that do not clutch 93, read off its place 13 |

## False overlaps: covers that are not the part

A real set's parts do not overlap either, so every pair the check would refuse
as overlapping is a collision cover wrong (`tools/ldraw/occupancy.py` builds them),
or the reading's: a part read a little off where the file has it. The check
excuses overlaps between parts already standing, and keeps them for this count
(`Assistant._standing_overlaps`).

- Overlapping pairs: 351,842, of them 216,160 with a part read off its place.
- Files with none: 118 of 1,572.

| Part | Name | Pairs | Before | Files | Commonest partner |
|---|---|---:|---:|---:|---|
| 77 | ~Technic Flex-System Hose Segment | 35,703 | 35,711 | 15 | 77 (34550), 32013 (182), 59443 (175) |
| u9218 | ~Electric Power Functions  2.0 6-Wire Ribbon Cable Segment | 6,713 | 6,904 | 12 | u9218 (6339), 22169 (53), u9390 (51) |
| 71533k03 | ~Technic Pneumatic Tube Segment | 6,342 | 6,447 | 17 | 71533k03 (5641), 71533k01 (180), 32291 (73) |
| 6632 | Technic Beam  3 x  0.5 Liftarm | 2,470 | 2,873 | 187 | 6632 (402), 32123a (99), 32056 (92) |
| 6989 - ls60 |  | 2,252 | 2,364 | 1 | 6989 - ls60 (2026), 4209a (207), 4208 (14) |
| 3023b | Plate  1 x  2 | 2,248 | 3,500 | 414 | 3023b (85), 3659 (72), 41682 (50) |
| 41677 | Technic Beam  2 x  0.5 Liftarm | 2,121 | 2,440 | 140 | 41677 (465), 32123b (108), 6632 (78) |
| 32123b | Technic Bush 1/2 Smooth with Axle Hole Semi-Reduced | 1,853 | 2,407 | 154 | 32123b (170), 41677 (108), 56145 (98) |
| 3710 | Plate  1 x  4 | 1,780 | 2,759 | 325 | 3710 (54), 3703 (44), 3460 (39) |
| 6141 | Plate  1 x  1 Round | 1,551 | 2,068 | 335 | 22885 (176), 6141 (57), 3623 (48) |
| 3020 | Plate  2 x  4 | 1,540 | 2,270 | 332 | 3020 (42), 3023b (38), 30028b (38) |
| 32123a | Technic Bush  1/2 Smooth with Axle Hole Reduced | 1,513 | 2,027 | 149 | 6632 (99), 32123a (86), 56145 (72) |
| u9190 | ~Electric Power Functions 4-Wire Ribbon Cable Segment | 1,450 | 1,462 | 9 | u9190 (1432), 58124c01 (8), 99499 (7) |
| 32056 | Technic Beam  3 x  3 x  0.5 Liftarm Bent 90 | 1,399 | 1,559 | 110 | 32056 (277), 6632 (92), 41677 (66) |
| 32449 | Technic Beam  4 x  0.5 Liftarm | 1,383 | 1,577 | 102 | 32449 (280), 41677 (51), 6536 (50) |
| 754 | ~Hose Flexible Segment Link Section | 1,224 | 1,227 | 28 | 754 (1043), 755 (96), 756 (51) |
| 3713 | Technic Bush with Two Flanges | 1,192 | 1,741 | 263 | 56145 (208), 44309 (47), 32056 (46) |
| 2780 | Technic Pin with Friction and Slots | 1,155 | 1,771 | 186 | 2851 (126), 32278 (40), 2780 (39) |
| 56145 | Wheel Rim 20 x 30 with  6 Dual Spokes and External Ribs | 1,103 | 1,214 | 73 | 3713 (208), 44309 (107), 32123b (98) |
| 3024 | Plate  1 x  1 | 1,092 | 1,506 | 226 | 3659 (66), 3024 (52), 2877 (45) |
| 3666 | Plate  1 x  6 | 1,076 | 1,499 | 234 | 3710 (38), 3666 (35), 3460 (27) |
| 98138 | Tile  1 x  1 Round with Groove | 1,064 | 1,138 | 82 | 98138 (584), 30414 (54), 2445 (43) |
| 3623 | Plate  1 x  3 | 1,042 | 1,339 | 218 | 6141 (48), 3710 (30), 3623 (27) |
| 3022 | Plate  2 x  2 | 1,021 | 1,546 | 284 | 3020 (30), 3641 (28), 3665a (27) |
| 3004 | Brick  1 x  2 | 1,015 | 1,482 | 198 | 3004 (52), 14716 (42), 35464 (40) |
| 3795 | Plate  2 x  6 | 1,010 | 1,648 | 227 | 30028b (62), 3020 (31), 3023b (29) |
| 11478 | Technic Beam  5 x  0.5 Liftarm with Axle Holes at Both Ends | 977 | 1,104 | 68 | 11478 (154), 41677 (53), 32123b (39) |
| 4477 | Plate  1 x 10 | 937 | 1,118 | 115 | 2555 (78), 4274 (54), 3703 (42) |
| 3460 | Plate  1 x  8 | 919 | 1,174 | 173 | 4215a (40), 3710 (39), 3023b (30) |
| 3021 | Plate  2 x  3 | 903 | 1,320 | 215 | 3021 (27), 4477 (25), 33909 (22) |
| 32063 | Technic Beam  6 x  0.5 | 866 | 909 | 70 | 32063 (167), 6632 (52), 41239 (47) |
| 3005 | Brick  1 x  1 | 865 | 1,117 | 139 | 3005 (58), 3062b (40), 60596 (28) |
| 6536 | Technic Cross Block 1 x 2 (Axle/Pin) | 863 | 1,054 | 163 | 6632 (89), 41677 (63), 32123a (57) |
| 3069b | Tile  1 x  2 with Groove | 859 | 1,125 | 222 | 3795 (27), 3069b (23), 6141 (20) |
| 32140 | Technic Beam  2 x  4 Liftarm Bent 90 | 833 | 1,014 | 145 | 6632 (79), 71533k03 (67), 41677 (61) |
| 2431 | Tile  1 x  4 with Groove | 824 | 999 | 182 | 3024 (42), 2431 (41), 4162 (33) |
| 6157 | Plate  2 x  2 with 2 Wheel Pins Extended without Wishbones | 808 | 1,191 | 132 | 50951 (442), 6014a (159), 30028b (126) |
| 4162 | Tile  1 x  8 | 796 | 968 | 118 | 2431 (33), 3710 (32), 3666 (24) |
| 30028b | Tyre  8/ 40 x  8 Slick Smooth | 743 | 766 | 54 | 30027a (142), 6157 (126), 3795 (62) |
| 2905 | Technic Beam  5 x  3 x  0.5 Liftarm Triangle | 718 | 735 | 50 | 2905 (62), 6632 (40), 57518 (36) |
| 32250 | Technic Beam  3 x  5 x  0.5 Liftarm Bent 90 Quarter Ellipse | 712 | 755 | 63 | 32250 (69), 6632 (49), 32123a (40) |
| 3010 | Brick  1 x  4 | 691 | 1,038 | 157 | 3009 (26), 3023b (19), 3010 (19) |
| 41497 - ls60 |  | 672 | 682 | 1 | 41497 - ls60 (522), 572c (150) |
| 32017 | Technic Beam  5 x  0.5 | 667 | 734 | 55 | 32017 (76), 32065 (40), 6629 (36) |
| 32278 | Technic Beam 15 | 663 | 738 | 94 | 2780 (40), 41677 (38), 32056 (31) |
| 3062b | Brick  1 x  1 Round with Hollow Stud | 660 | 861 | 130 | 3062b (53), 22885 (48), 3005 (40) |
| 32524 | Technic Beam  7 | 656 | 764 | 110 | 6632 (46), 2780 (32), 32056 (28) |
| 3034 | Plate  2 x  8 | 652 | 1,036 | 161 | 2420 (22), 30028b (19), 6081 (19) |
| 57518 | Technic Chain Tread 5 Wide | 652 | 952 | 14 | 57519 (180), 57520 (135), 42610 (59) |
| 50951 | Tyre  6/ 30 x 11 | 645 | 1,314 | 88 | 6157 (442), 86501 (40), 32073 (24) |
| 32525 | Technic Beam 11 | 628 | 686 | 103 | 57518 (56), 6632 (30), 32449 (25) |
| 32316 | Technic Beam  5 | 620 | 792 | 117 | 41677 (53), 32140 (31), 6632 (27) |
| 2420 | Plate  2 x  2 Corner | 616 | 892 | 137 | 3023b (50), 2420 (43), 3034 (22) |
| 2412b | Tile  1 x  2 Grille with Groove | 614 | 881 | 145 | 4477 (28), 2412b (25), 99781 (24) |
| 32065 | Technic Beam  7 x  0.5 | 612 | 647 | 42 | 32065 (135), 32002 (112), 32123b (47) |
| 3817 | ~Minifig Leg Left (Obsolete) | 602 | 683 | 359 | 3815 (170), 4079 (35), 3795 (24) |
| 3832 | Plate  2 x 10 | 601 | 858 | 102 | 3665a (26), 3024 (18), 3023b (16) |
| 4265a | Technic Bush  1/2 Type 1 | 586 | 830 | 73 | 4273a (80), 2905 (29), 2711 (25) |
| 3816 | ~Minifig Leg Right (Obsolete) | 585 | 660 | 253 | 3815 (171), 4079 (35), 3795 (24) |
| 40490 | Technic Beam  9 | 582 | 670 | 112 | 32056 (42), 6632 (31), 32449 (31) |

## What the check said, summed over files

floating 233,603, off its studs 3,373, section adrift 296

## The files with the most floating

| File | Parts | Floating | Misread | Seconds |
|---|---:|---:|---:|---:|
| 10294-1.mpd | 9,112 | 9,112 | 96 | 57 |
| 42100-1.mpd | 7,221 | 7,047 | 2,878 | 267 |
| 42043-1_Flatbed-Trailer.mpd | 7,887 | 5,180 | 3,423 | 81 |
| 42131-1.mpd | 5,155 | 5,155 | 2,413 | 75 |
| 42114-1.mpd | 4,631 | 4,628 | 806 | 188 |
| 42043-1.mpd | 7,311 | 4,038 | 2,721 | 61 |
| 8110-1.mpd | 4,026 | 4,026 | 1,812 | 115 |
| 42055-1.mpd | 3,889 | 3,881 | 122 | 441 |
| 42115-1.mpd | 3,669 | 3,669 | 387 | 127 |
| 76139-1.mpd | 3,281 | 3,256 | 76 | 56 |
| 10030-1.mpd | 3,037 | 3,037 | 1,395 | 786 |
| 8275-1.mpd | 3,028 | 3,028 | 1,695 | 34 |
| 42125-1.mpd | 2,944 | 2,942 | 1,244 | 147 |
| 10224-1.mpd | 2,797 | 2,797 | 50 | 9 |
| 71006-1.mpd | 2,571 | 2,571 | 106 | 103 |
| 8841-1_Combination-with-8700.mpd | 2,667 | 2,498 | 2,485 | 9 |
| 42070-1.mpd | 2,383 | 2,378 | 532 | 27 |
| 42053-1.mpd | 2,703 | 2,346 | 1,287 | 18 |
| 42069-1.mpd | 2,249 | 2,243 | 11 | 33 |
| 10283-1.mpd | 2,290 | 2,214 | 437 | 501 |
