# Connections: what the build check holds in real sets

Every set in the LDraw model repository holds together in reality, so every part
the build check calls floating in one is a gap in the connection data or the
joint types, and every pair it would refuse as overlapping is a collision cover
that is not the part. `tools/connection_audit.py run` checks every file as an
edit is checked for what it leaves hanging (only the ground holds), and `report`
writes this page. Rerun both after any change to `tools/ldraw/connectivity.py`,
`tools/ldraw/occupancy.py`, the catalogue or the checker's joints
(`src/assembly/joints.gd`).

**Coverage: 58.00% of part instances held** — 392,834 of 677,296 in 1,572 files (1,262 sets).

- Floating: 284,462 part instances.
- Files whole (nothing floating): 362 of 1,572.
- Overlapping pairs (covers that are not the part): 411,926.
- Read off their place (the reading cannot put the part where the file has it, most often a part turned about two axes at once): 101,711 instances, of them 72,846 floating.
- Not in the catalogue, so not checked: 1,365 distinct parts summed over files.

Each cluster of floating parts (floating parts touching each other) is put down
to one joint: of the joints between it and the held parts it touches, the first
in this table's order, read off what the two parts are and which of their
connectors meet there. *Instances* is the floating parts so put down.

## By connection type

| Connection | Instances | Clusters | Files | Commonest joint (floating part on held part) | What is done about it |
|---|---:|---:|---:|---|---|
| stands a little off the ground in the file | 159,654 | 960 | 472 | 32019 on  (20495), 55976 on  (16359), 3811 on  (6221) |  |
| stands on parts the catalogue does not have | 55,782 | 1,109 | 206 |  |  |
| read off its place | 29,773 | 1,583 | 370 | 71533k03 on 71533k03 (2965), 2780 on 2739a (1826), 77 on 4185a (1266) |  |
| touches nothing held | 10,578 | 628 | 204 |  |  |
| Technic pin or axle | 8,525 | 1,687 | 258 | 42066 - 24316 on 55982 (1233), 32140 on 3705 (512), 32348 on 6183 (375) |  |
| hose, string or chain | 3,722 | 74 | 34 | 77 on 77 (2505), 77 on 32039 (291), 71533k03 on 99021 (228) |  |
| click hinge | 3,587 | 266 | 160 | 30552 on 30553 (654), 44301a on 44302a (484), 30541 on 44302a (411) |  |
| no connector at the contact | 2,919 | 211 | 113 | 6003 on 4489b (2055), 3857 on 3857 (128), 44728 on 87079 (90) |  |
| Technic, no pin or axle at the contact | 2,622 | 242 | 104 | 3895 on 6636 (1779), 3068b on 32124 (145), 8868-1 - myrubbercyl on 4265a (82) |  |
| towball | 1,299 | 81 | 42 | 98263 on 2508 (368), 2508 on 63082 (297), 77 on 6628 (125) |  |
| ball and socket | 952 | 31 | 18 | 41681 on 8012 - 32578-f2 (359), 15459 on 15460 (167), 57908 on 87408 (109) |  |
| magnet | 945 | 35 | 17 | 64417c01 on 2878 (761), 2959c01 on 2959c01 (66), 4023c01 on 4023c01 (64) |  |
| clip on bar or handle | 788 | 219 | 122 | 63868 on 60478 (92), 60478 on 48729a (67), 4735 on 3023b (41) |  |
| studs that do not clutch | 710 | 292 | 125 | 4597 on 2431 (138), 4477 on 50950 (93), 42446 on 3034 (38) |  |
| hinge | 520 | 136 | 74 | 3068b on 2430 (133), 6636 on 2429 (118), 3938 on 2440 (47) |  |
| tyre on wheel | 509 | 27 | 19 | 3749 on 2815 (354), 6014bc02 on 4162 (61), 4482 on 3641 (45) |  |
| bar in a hole or tube | 508 | 197 | 99 | 4623 on 3176 (58), 30374 on 6538a (42), 3612 on 792 (30) |  |
| minifig on the model | 351 | 152 | 84 | 4210a on 3731 (87), 4032a on 64644 (39), 3849 on 3941 (14) |  |
| turntable | 264 | 7 | 4 | 3873 on 18938 (125), 24316 on 18938 (88), 3403 on 3069bp06 (34) |  |
| pane or door in its frame | 214 | 139 | 78 | 3856 on 3853 (38), 4346 on 4345b (23), 2653 on 4510 (23) |  |
| sticker | 181 | 178 | 46 | 191915i on 3008 (8), 190145a on 4215a (5), 191915d on 3008 (4) |  |
| electric | 29 | 18 | 9 | 593 on 3009 (11), 6141 on 4170c01 (10), 24849 on 11214 (2) |  |
| minifig part on minifig part | 17 | 17 | 10 | 53451 on 30162 (8), 3837 on 3836 (2), 24093 on 24324 (1) |  |
| rubber band | 12 | 12 | 7 | 4185a on 98585 (4), 4185a on 3706 (3), 4185a on 6558 (1) |  |
| minifig hand grip | 1 | 1 | 1 | 61482 on 2377 (1) |  |

## By part: the gaps that block the most

*Blocks* is the floating instances put down to a joint on this part's side;
*floating* is how many of this part itself float.

| Part | Name | Blocks | Floating | Files | Joint |
|---|---|---:|---:|---:|---|
| 77 | ~Technic Flex-System Hose Segment | 5,943 | 8,166 | 14 | read off its place 2991, hose, string or chain 2827 |
| 71533k03 | ~Technic Pneumatic Tube Segment | 5,410 | 17,943 | 17 | read off its place 5076, hose, string or chain 334 |
| u9218 | ~Electric Power Functions  2.0 6-Wire Ribbon Cable Segment | 2,947 | 8,421 | 12 | read off its place 2772, hose, string or chain 175 |
| 6003 | Plate  6 x  6 with  4 x  4 Round Corner | 2,055 | 12 | 5 | no connector at the contact 2055 |
| 3713 | Technic Bush with Two Flanges | 1,998 | 2,805 | 336 | read off its place 1276, Technic pin or axle 700 |
| 2780 | Technic Pin with Friction and Slots | 1,877 | 9,051 | 191 | read off its place 1844, Technic, no pin or axle at the contact 33 |
| 3895 | Technic Brick  1 x 12 with Holes | 1,779 | 245 | 60 | Technic, no pin or axle at the contact 1779 |
| 42066 - 24316 |  | 1,233 | 6 | 1 | Technic pin or axle 1233 |
| 756 | ~Hose Flexible Segment Center Section | 1,146 | 2,223 | 50 | read off its place 1138, hose, string or chain 8 |
| 32016 | Technic Angle Connector #3 (157.5 degree) | 1,077 | 182 | 50 | read off its place 1069, Technic pin or axle 8 |
| 44375b | Dish  6 x  6 Inverted with Solid Studs | 858 | 22 | 5 | read off its place 858 |
| 754 | ~Hose Flexible Segment Link Section | 833 | 1,929 | 28 | read off its place 783, hose, string or chain 50 |
| 64417c01 | Train Buffer Sealed Magnet | 761 | 5 | 2 | magnet 761 |
| 30552 | Hinge Arm Locking with Single Finger and Axlehole | 704 | 54 | 29 | click hinge 704 |
| 32140 | Technic Beam  2 x  4 Liftarm Bent 90 | 622 | 1,067 | 93 | Technic pin or axle 521, read off its place 101 |
| 7817 - ls60 |  | 601 | 576 | 1 | read off its place 601 |
| 44301a | Hinge Plate  1 x  2 Locking with Groove with Single Finger o | 601 | 173 | 40 | click hinge 561, read off its place 40 |
| 44302a | Hinge Plate  1 x  2 Locking with Dual Finger on End Vertical | 541 | 308 | 64 | read off its place 339, click hinge 202 |
| u9190 | ~Electric Power Functions 4-Wire Ribbon Cable Segment | 478 | 3,845 | 9 | read off its place 478 |
| 6572 | Technic Suspension Arm  2 x  4.8 with Towball | 477 | 19 | 6 | read off its place 477 |
| 71944k02 | ~Technic Ribbed Hose Mid Segment | 466 | 1,472 | 25 | read off its place 458, hose, string or chain 8 |
| 63869 | Technic Cross Block 3 x 2 (Axle/Triple Pin) | 461 | 346 | 54 | Technic pin or axle 344, read off its place 107 |
| 6536 | Technic Cross Block 1 x 2 (Axle/Pin) | 444 | 1,458 | 137 | Technic pin or axle 413, read off its place 28 |
| 3034 | Plate  2 x  8 | 437 | 884 | 224 | read off its place 437 |
| 6397 - ls60 |  | 431 | 430 | 1 | read off its place 431 |
| 6472 - ls60 |  | 431 | 430 | 1 | read off its place 431 |
| 364 - ls60 |  | 413 | 834 | 1 | read off its place 413 |
| 30541 | Hinge Brick  1 x  2 Locking with Single Finger On End Horizo | 411 | 11 | 3 | click hinge 411 |
| 3068b | Tile  2 x  2 with Groove | 383 | 1,449 | 218 | Technic, no pin or axle at the contact 145, hinge 133 |
| 32348 | Technic Beam  4 x  4 Liftarm Bent 53.13 | 382 | 186 | 39 | Technic pin or axle 376, read off its place 6 |
| 3649 | Technic Gear 40 Tooth | 375 | 19 | 6 | Technic pin or axle 375 |
| 98263 | Plate  1 x  4 with Socket Joint-8 Square | 368 | 4 | 3 | towball 368 |
| 3749 | Technic Axle Pin | 367 | 945 | 176 | tyre on wheel 354, read off its place 12 |
| 41681 | Technic Beam  3.8 x  1 Liftarm with Click Rotation Ring Sock | 359 | 3 | 1 | ball and socket 359 |
| 7750 - ls23 |  | 345 | 345 | 1 | read off its place 345 |
| 28326 | Car Mudguard  4 x  3 x  1 | 338 | 12 | 3 | Technic pin or axle 338 |
| 4730 | Brick  2 x  2 with Pin | 335 | 32 | 13 | Technic pin or axle 335 |
| 6141 | Plate  1 x  1 Round | 330 | 4,263 | 525 | read off its place 123, studs that do not clutch 63 |
| 11299 | Ladder  2.6 x 16 with Handrails | 312 | 1 | 1 | read off its place 312 |
| 32123b | Technic Bush 1/2 Smooth with Axle Hole Semi-Reduced | 297 | 884 | 120 | Technic pin or axle 252, read off its place 40 |
| 2508 | Plate  1 x  2 with 3L Extension and Towball | 297 | 13 | 13 | towball 297 |
| 32062 | Technic Axle  2 Notched | 278 | 1,825 | 175 | read off its place 270, Technic pin or axle 5 |
| 6339 - ls60 |  | 242 | 232 | 1 | read off its place 242 |
| 61510 | Technic Reel  2 x  1 | 241 | 18 | 14 | read off its place 236, Technic, no pin or axle at the contact 3 |
| 2825 | Technic Beam  4 x  0.5 Liftarm with Boss | 233 | 219 | 54 | Technic pin or axle 231, Technic, no pin or axle at the contact 2 |
| 4589 | Cone  1 x  1 | 230 | 777 | 169 | studs that do not clutch 65, clip on bar or handle 41 |
| 30383 | Hinge Plate  1 x  2 Locking with Single Finger On Top | 219 | 135 | 25 | click hinge 219 |
| 32123a | Technic Bush  1/2 Smooth with Axle Hole Reduced | 213 | 713 | 113 | Technic pin or axle 188, read off its place 11 |
| 98138 | Tile  1 x  1 Round with Groove | 206 | 787 | 97 | read off its place 174, no connector at the contact 23 |
| 920 - rocket launch pad - ls23 |  | 206 | 219 | 1 | read off its place 206 |
| 30364 | Hinge Brick  1 x  2 Locking with Single Finger On End | 206 | 63 | 11 | read off its place 140, click hinge 66 |
| 993 | ~Electric Cable 3LDU Twin | 200 | 316 | 4 | read off its place 200 |
| 21034 - ls41 |  | 196 | 192 | 1 | read off its place 196 |
| 94925 | Technic Gear 16 Tooth Reinforced | 190 | 267 | 61 | Technic pin or axle 174, read off its place 13 |
| 41497 - ls60 |  | 190 | 184 | 1 | read off its place 170, hose, string or chain 10 |
| 3873 | Technic Chain Tread 2.5 Wide | 189 | 555 | 10 | turntable 125, hose, string or chain 64 |
| 4276b | Hinge Plate  1 x  2 with 2 Fingers and Hollow Studs | 179 | 186 | 72 | click hinge 133, read off its place 46 |
| 9396 - ls60 |  | 175 | 174 | 1 | read off its place 175 |
| 30365 | Hinge Brick  1 x  2 Locking with Dual Finger On End | 168 | 99 | 16 | click hinge 168 |
| 15459 | Technic Suspension Arm  1 x  5 Type 1 | 167 | 33 | 6 | ball and socket 167 |
| 60471 | Hinge Plate  1 x  2 Locking 9-Position with Dual Finger on S | 165 | 30 | 13 | click hinge 165 |
| 3730 | Plate  2 x  2 with Towball Socket | 164 | 17 | 17 | towball 164 |
| 32034 | Technic Angle Connector #2 (180 degree) | 163 | 532 | 97 | Technic pin or axle 97, read off its place 61 |
| 4697b | Technic Pneumatic T-Piece - Type 2 | 161 | 63 | 22 | Technic pin or axle 160, click hinge 1 |
| 60478 | Plate  1 x  2 with Handle on End | 159 | 260 | 52 | clip on bar or handle 138, read off its place 19 |
| 30104k02 | Minifig Chain Link for Chain  6L and 17L | 156 | 522 | 20 | read off its place 156 |
| 3736 | Technic Pulley Wheel 5D | 153 | 18 | 15 | Technic pin or axle 153 |
| 10182 - ls51 |  | 150 | 148 | 1 | read off its place 150 |
| 30553 | Hinge Arm Locking with Dual Finger and Axlehole | 149 | 114 | 53 | click hinge 141, read off its place 8 |
| 4593 | Hinge Control Stick | 146 | 333 | 130 | read off its place 97, hinge 47 |
| 42003 | Technic Cross Block 1 x 3 (Axle/Pin/Pin) | 141 | 850 | 89 | Technic pin or axle 141 |
| 3673 | Technic Pin | 138 | 1,317 | 142 | Technic pin or axle 138 |
| 4597 | Cockpit  6 x  6 | 138 | 5 | 4 | studs that do not clutch 138 |
| 4274 | Technic Pin  1/2 | 137 | 2,086 | 207 | Technic pin or axle 82, read off its place 38 |
| 44728 | Bracket  1 x  2 -  2 x  2 Down | 137 | 493 | 94 | no connector at the contact 137 |
| 4019 | Technic Gear 16 Tooth | 131 | 114 | 44 | Technic pin or axle 127, read off its place 4 |
| 44567a | Hinge Plate  1 x  2 Locking with Groove with Single Finger O | 129 | 59 | 33 | click hinge 117, read off its place 12 |
| 3857 | Baseplate 16 x 32 with Square Corners | 128 | 14 | 9 | no connector at the contact 128 |
| 6636 | Tile  1 x  6 | 126 | 873 | 119 | hinge 118, read off its place 7 |
| 4005 - ls60 |  | 123 | 114 | 1 | read off its place 123 |

## False overlaps: covers that are not the part

A real set's parts do not overlap either, so every pair the check would refuse
as overlapping is a collision cover wrong (`tools/ldraw/occupancy.py` builds them),
or the reading's: a part read a little off where the file has it. The check
excuses overlaps between parts already standing, and keeps them for this count
(`Assistant._standing_overlaps`).

- Overlapping pairs: 411,926, of them 229,208 with a part read off its place.
- Files with none: 60 of 1,572.

| Part | Name | Pairs | Files | Commonest partner |
|---|---|---:|---:|---|
| 77 | ~Technic Flex-System Hose Segment | 35,711 | 15 | 77 (34550), 32013 (182), 59443 (175) |
| u9218 | ~Electric Power Functions  2.0 6-Wire Ribbon Cable Segment | 6,904 | 12 | u9218 (6339), 22169 (111), u9390 (51) |
| 71533k03 | ~Technic Pneumatic Tube Segment | 6,447 | 17 | 71533k03 (5641), 71533k01 (180), 32291 (73) |
| 3023b | Plate  1 x  2 | 3,500 | 604 | 50745 (98), 3023b (85), 62361 (74) |
| 6632 | Technic Beam  3 x  0.5 Liftarm | 2,873 | 187 | 6632 (402), 32123a (99), 32056 (92) |
| 3710 | Plate  1 x  4 | 2,759 | 478 | 3665a (106), 50745 (98), 2672 (64) |
| 3665a | Slope Brick 45  2 x  1 Inverted without Inner Stopper Ring | 2,656 | 377 | 4180c02 (128), 3027 (124), 3665a (109) |
| 41677 | Technic Beam  2 x  0.5 Liftarm | 2,440 | 140 | 41677 (460), 32123b (108), 32073 (80) |
| 32123b | Technic Bush 1/2 Smooth with Axle Hole Semi-Reduced | 2,407 | 156 | 32123b (170), 41677 (108), 56145 (98) |
| 6989 - ls60 |  | 2,364 | 1 | 6989 - ls60 (2026), 4209a (175), 2582p68 (144) |
| 3020 | Plate  2 x  4 | 2,270 | 475 | 50745 (80), 2878c01 (63), 3665a (59) |
| 6141 | Plate  1 x  1 Round | 2,068 | 406 | 22885 (176), 6141 (57), 3623 (48) |
| 32123a | Technic Bush  1/2 Smooth with Axle Hole Reduced | 2,027 | 152 | 6632 (99), 32123a (86), 56145 (72) |
| 50745 | Car Mudguard  4 x  2.5 x  2 | 1,900 | 45 | 6014a (144), 4488 (126), 3023b (98) |
| 2780 | Technic Pin with Friction and Slots | 1,771 | 216 | 2851 (126), 18939 (58), 32278 (44) |
| 3713 | Technic Bush with Two Flanges | 1,741 | 293 | 56145 (208), 55976 (70), 44309 (60) |
| 3795 | Plate  2 x  6 | 1,648 | 322 | 4180c02 (86), 4022 (79), 3665a (76) |
| 6015 | Tyre 12/ 40 x 11 Wide | 1,618 | 109 | 6014a (478), 4600 (232), 6157 (132) |
| 32449 | Technic Beam  4 x  0.5 Liftarm | 1,577 | 104 | 32449 (280), 71533k03 (54), 41677 (51) |
| 32056 | Technic Beam  3 x  3 x  0.5 Liftarm Bent 90 | 1,559 | 110 | 32056 (277), 6632 (92), 41677 (66) |
| 3022 | Plate  2 x  2 | 1,546 | 417 | 3665a (46), 4022 (37), 4180c02 (31) |
| 3024 | Plate  1 x  1 | 1,506 | 301 | 3665a (68), 3659 (66), 3024 (52) |
| 3666 | Plate  1 x  6 | 1,499 | 316 | 3665a (102), 50745 (49), 3710 (38) |
| 3004 | Brick  1 x  2 | 1,482 | 294 | 3004 (52), 2345 (47), 14716 (42) |
| u9190 | ~Electric Power Functions 4-Wire Ribbon Cable Segment | 1,462 | 9 | u9190 (1432), 99499 (18), 58124c01 (8) |
| 6014a | Wheel Rim 12 x 11 with Round Hole | 1,375 | 147 | 6015 (478), 6157 (161), 4488 (148) |
| 3641 | Tyre  6/ 50 x  8 Offset Tread | 1,354 | 160 | 4600 (313), 3788 (235), 2441 (96) |
| 3623 | Plate  1 x  3 | 1,339 | 270 | 3665a (52), 6141 (48), 3710 (30) |
| 3021 | Plate  2 x  3 | 1,320 | 318 | 3665a (27), 3021 (27), 4477 (25) |
| 50951 | Tyre  6/ 30 x 11 | 1,314 | 88 | 51719 (468), 6157 (442), 44674 (92) |
| 754 | ~Hose Flexible Segment Link Section | 1,227 | 28 | 754 (1043), 755 (96), 756 (51) |
| 56145 | Wheel Rim 20 x 30 with  6 Dual Spokes and External Ribs | 1,214 | 73 | 3713 (208), 44309 (107), 32123b (98) |
| 6157 | Plate  2 x  2 with 2 Wheel Pins Extended without Wishbones | 1,191 | 158 | 50951 (442), 6014a (161), 6015 (132) |
| 3460 | Plate  1 x  8 | 1,174 | 231 | 3665a (71), 4215a (40), 3710 (39) |
| 6589 | Technic Gear 12 Tooth Bevel | 1,162 | 135 | 6589 (176), 62821 (128), 64179 (95) |
| 98138 | Tile  1 x  1 Round with Groove | 1,138 | 86 | 98138 (584), 30414 (54), 2445 (43) |
| 3069b | Tile  1 x  2 with Groove | 1,125 | 282 | 2877 (34), 3795 (27), 3069b (23) |
| 4477 | Plate  1 x 10 | 1,118 | 147 | 2555 (78), 4274 (54), 3665a (51) |
| 3005 | Brick  1 x  1 | 1,117 | 195 | 3005 (58), 3665a (46), 3062b (40) |
| 11478 | Technic Beam  5 x  0.5 Liftarm with Axle Holes at Both Ends | 1,104 | 68 | 11478 (154), 41677 (55), 32123b (39) |
| 6536 | Technic Cross Block 1 x 2 (Axle/Pin) | 1,054 | 168 | 6632 (89), 41677 (63), 32123a (63) |
| 3010 | Brick  1 x  4 | 1,038 | 237 | 3665a (37), 50745 (36), 4180c02 (34) |
| 3034 | Plate  2 x  8 | 1,036 | 239 | 2878c02 (50), 2878c01 (46), 4022 (36) |
| 32140 | Technic Beam  2 x  4 Liftarm Bent 90 | 1,014 | 148 | 6632 (79), 71533k03 (65), 41677 (61) |
| 2431 | Tile  1 x  4 with Groove | 999 | 224 | 3024 (42), 2431 (41), 4162 (33) |
| 4600 | Plate  2 x  2 with 2 Wheel Pins | 975 | 162 | 3641 (313), 6015 (232), 6014a (124) |
| 4162 | Tile  1 x  8 | 968 | 140 | 74746 (40), 2431 (33), 3710 (32) |
| 57518 | Technic Chain Tread 5 Wide | 952 | 14 | 57519 (266), 57520 (185), 42610 (140) |
| 32063 | Technic Beam  6 x  0.5 | 909 | 70 | 32063 (167), 6632 (52), 41239 (47) |
| 2420 | Plate  2 x  2 Corner | 892 | 190 | 3023b (50), 2420 (43), 3665a (41) |
| 2412b | Tile  1 x  2 Grille with Groove | 881 | 203 | 44674 (33), 4477 (28), 2412b (25) |
| 64179 | Technic Beam  7 x  5 with Open Center  5 x  3 | 881 | 46 | 6589 (95), 32316 (36), 62821 (33) |
| 3062b | Brick  1 x  1 Round with Hollow Stud | 861 | 170 | 3062b (53), 22885 (48), 3005 (40) |
| 3832 | Plate  2 x 10 | 858 | 151 | 3665a (72), 4180c02 (36), 2593 (22) |
| 4265a | Technic Bush  1/2 Type 1 | 830 | 74 | 4273a (80), 3707 (35), 2905 (33) |
| 3705 | Technic Axle  4 | 826 | 243 | 32123b (44), 6632 (42), 4265a (31) |
| 30562 | Panel  4 x  4 x  6 Corner Round | 817 | 11 | 3941 (88), 4032a (88), 3001 (76) |
| 32316 | Technic Beam  5 | 792 | 124 | 41677 (53), 64179 (36), 32140 (30) |
| 4022 | Train Buffer Beam | 775 | 54 | 2920 (120), 3795 (79), 3023b (53) |
| 30028b | Tyre  8/ 40 x  8 Slick Smooth | 766 | 54 | 30027a (142), 6157 (126), 3795 (62) |

## What the check said, summed over files

floating 284,462, off its studs 2,661, section adrift 269

## The files with the most floating

| File | Parts | Floating | Misread | Seconds |
|---|---:|---:|---:|---:|
| 10294-1.mpd | 9,112 | 9,112 | 96 | 45 |
| 42043-1_Flatbed-Trailer.mpd | 7,887 | 7,887 | 3,423 | 119 |
| 42043-1.mpd | 7,311 | 7,311 | 2,721 | 96 |
| 42131-1.mpd | 5,155 | 5,155 | 2,413 | 132 |
| 8273-1_Utility-Cargo-Truck.mpd | 4,115 | 4,115 | 3,458 | 52 |
| 8273-1.mpd | 4,018 | 4,018 | 3,224 | 58 |
| 42055-1.mpd | 3,889 | 3,889 | 122 | 449 |
| 42115-1.mpd | 3,669 | 3,669 | 387 | 90 |
| 76139-1.mpd | 3,281 | 3,281 | 76 | 28 |
| 42100-1.mpd | 7,221 | 3,244 | 2,878 | 175 |
| 10297-1.mpd | 3,148 | 3,108 | 193 | 31 |
| 76042-1.mpd | 3,080 | 3,080 | 161 | 39 |
| 10030-1.mpd | 3,037 | 3,037 | 1,395 | 590 |
| 8275-1.mpd | 3,028 | 3,028 | 1,695 | 27 |
| 10224-1.mpd | 2,797 | 2,797 | 50 | 8 |
| 42053-1.mpd | 2,703 | 2,703 | 1,287 | 21 |
| 8841-1_Combination-with-8700.mpd | 2,667 | 2,667 | 2,485 | 9 |
| 71006-1.mpd | 2,571 | 2,571 | 106 | 84 |
| 10243-1.mpd | 2,475 | 2,474 | 104 | 87 |
| 42070-1.mpd | 2,383 | 2,378 | 532 | 21 |
