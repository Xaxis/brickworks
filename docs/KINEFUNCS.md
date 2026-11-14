<!-- Written by tools/kinefuncs.py table LABEL --write; do not edit by hand. -->
<!-- Kinebrick f46de815366d47de1231b92af63831ce7bb9a9aa: github.com/erik-larsen/kinebrick (MIT; its data CC BY-SA 4.0). -->

# Simulate on real sets' functions, beside Kinebrick (r8g)

Brickworks' Simulate works 391 of the 1224 functions of Kinebrick's 186 sets (32%); Kinebrick's main (f46de81) works 522 by its sets' own results (its README: 517). Both work 291. Every function of 18 sets works in Simulate.

| result | Brickworks | Kinebrick |
|---|---|---|
| works | 391 | 522 |
| partly | 459 | 356 |
| no | 199 | 171 |
| skipped | 117 | 117 |
| not checked | 58 | 58 |

| why a function does not work in Simulate | functions |
|---|---|
| turned, but parts that should move did not | 493 |
| the train locks | 93 |
| the control turns on nothing the reading found | 22 |
| partly | 16 |
| parts that should stay moved | 8 |
| no | 3 |
| no: p79 64178 is part of the frame p177 64178 is part of the fr… | 1 |
| no: p170 92907 is part of the frame p179 92907 is part of the f… | 1 |
| no: p156 32556 is part of the frame (#157 32556a, a pin in the … | 1 |
| partly: p233 88517 is part of the frame (#235 88517, keyed in its a… | 1 |
| no: p646 41239 is part of the frame p671 41239 is part of the f… | 1 |
| no: p251 32140 is part of the frame | 1 |
| no: p415 2819 is part of the frame (#416 2819, keyed in its axl… | 1 |
| no: p3369 58119 is part of the frame (#3367 58119, a stud in it… | 1 |
| no: p1059 15458 is part of the frame | 1 |
| partly: p401 55982 is part of the frame p412 55982 is part of the f… | 1 |
| no: p1083 64782 is part of the frame | 1 |
| no: p2631 64782 is part of the frame (#2626 64782, two joints o… | 1 |
| partly: p3522 42083 - 37383p01 is part of the frame | 1 |
| partly: p2924 62531 is part of the frame | 1 |
| no: p380 24119 is part of the frame (#381 24119, two joints on … | 1 |
| no: p769 22169 is part of the frame (#777 22169, keyed in its a… | 1 |
| no: p1927 2819 is part of the frame (#1936 2819, keyed in its a… | 1 |
| partly: p2363 41681 is part of the frame (#2364 41681, two joints o… | 1 |
| partly: p205 56145 is part of the frame (#206 56145, keyed in its a… | 1 |
| no: p826 47223a-f1 is part of the frame (#829 47223a-f1, two jo… | 1 |
| partly: p317 6595 is part of the frame (#322 6595, keyed in its axl… | 1 |
| no: p757 6536 is part of the frame (#762 6536, keyed in its axl… | 1 |
| partly: p284 3482 is part of the frame (#285 3482, keyed in its axl… | 1 |

| mechanism | functions | Brickworks works | Kinebrick works |
|---|---|---|---|
| free-wheels | 154 | 137 | 138 |
| hinge | 129 | 58 | 48 |
| function-selector | 97 | 6 | 15 |
| electric-motor | 89 | 7 | 13 |
| worm-drive | 85 | 30 | 25 |
| differential | 78 | 3 | 35 |
| crank-and-link | 78 | 28 | 22 |
| rack-steering | 76 | 26 | 55 |
| piston-engine | 71 | 8 | 38 |
| spring | 63 | 3 | 3 |
| linear-actuator | 50 | 1 | 5 |
| turntable | 40 | 4 | 10 |
| for-show | 33 | 26 | 26 |
| rack-and-pinion | 30 | 10 | 12 |
| winch | 29 | 3 | 13 |
| crawler-tracks | 29 | 13 | 19 |
| linkage-steering | 29 | 2 | 11 |
| pneumatic-cylinder | 29 | 4 | 4 |
| double-wishbone | 26 | 5 | 8 |
| driven-rotor | 25 | 6 | 11 |
| pull-back-motor | 22 | 2 | 11 |
| remote-control | 21 | 1 | 4 |
| rigid | 20 | 0 | 0 |
| catch | 19 | 4 | 6 |
| hangs-free | 18 | 4 | 5 |
| swing-arm | 16 | 1 | 3 |
| slip-clutch | 15 | 2 | 0 |
| multi-axle-steering | 14 | 3 | 10 |
| power-take-off | 14 | 1 | 8 |
| pneumatic-pump | 13 | 0 | 1 |
| driving-ring-gearbox | 13 | 0 | 8 |
| accessory | 12 | 2 | 1 |
| belt-drive | 12 | 1 | 6 |
| posable-joint | 11 | 4 | 5 |
| chain-drive | 11 | 2 | 5 |
| sequential-gearbox | 11 | 1 | 0 |
| slide | 10 | 3 | 1 |
| pendular-axle | 9 | 4 | 1 |
| fork-steering | 8 | 4 | 0 |
| control-surfaces | 8 | 1 | 1 |
| three-point-hitch | 8 | 0 | 3 |
| sprung-axle | 7 | 2 | 0 |
| articulated-steering | 7 | 0 | 2 |
| portal-axle | 6 | 1 | 1 |
| ratchet | 6 | 0 | 0 |
| friction-brake | 6 | 2 | 0 |
| skid-steering | 5 | 0 | 1 |
| bogie | 5 | 3 | 3 |
| planetary-hub | 5 | 0 | 0 |
| pushrod-suspension | 4 | 1 | 1 |
| swivel-axle-steering | 4 | 2 | 0 |
| driven-detail | 4 | 1 | 3 |
| retractable-landing-gear | 4 | 2 | 0 |
| sliding-gear-gearbox | 4 | 0 | 2 |
| telescopic-fork | 3 | 0 | 0 |
| rotary-tool | 3 | 0 | 0 |
| rudder | 3 | 0 | 0 |
| launcher | 3 | 0 | 0 |
| scissor-linkage | 3 | 3 | 1 |
| rotor-pitch | 3 | 0 | 0 |
| valve-train | 3 | 1 | 3 |
| lights | 2 | 0 | 0 |
| telescopic-mast | 2 | 0 | 0 |
| oscillating-chassis | 2 | 1 | 1 |
| removable | 2 | 0 | 0 |
| push-pull-cable | 2 | 0 | 0 |
| pop-up-headlights | 2 | 1 | 1 |
| steering-mode-selector | 1 | 1 | 1 |
| conveyor | 1 | 0 | 0 |
| telelever | 1 | 0 | 0 |
| hook-lift | 1 | 0 | 1 |
| track-suspension | 1 | 0 | 0 |
| differential-lock | 1 | 0 | 0 |
| track-tensioner | 1 | 0 | 0 |
| swinging-idler-clutch | 1 | 0 | 0 |
| trailing-arm | 1 | 0 | 0 |
| swing-wing | 1 | 0 | 1 |

| set | # | what it does | Kinebrick | Brickworks | how Simulate drove it, or why not |
|---|---|---|---|---|---|
| 1972-1 | 1 | The steering wheel steers the front wheels: a 16-tooth gear on the slanted steering colum… | works | works | a drag's loop |
| 1972-1 | 2 | The four wheels roll freely, the rear two each on its own short axle; there's no engine d… | works | works | the gear reading |
| 41999-1 | 1 | Driving (remote, one stick): two Power Functions XL motors, one on each axle, each turn t… | works | partly | the gear reading and 1 loop it turns; still: p94 62821, p192 62821, p1539 44772 |
| 41999-1 | 2 | Steering (remote, other stick): the Power Functions servo turns a shaft running front and… | partly | partly | the gear reading; still: p299 87761, p316 87761, p151 92909 |
| 41999-1 | 3 | Each axle is a live axle hung on the chassis with shock absorbers and links, so it can ti… | no | no | p79 64178 is part of the frame p177 64178 is part of the frame |
| 41999-1 | 4 | The shock absorbers' springs hold the chassis up on its axles. | skipped | skipped |  |
| 41999-1 | 5 | The front winch: a Power Functions M motor, switched by hand with the pole-reverser switc… | partly | works | the gear reading |
| 41999-1 | 6 | The two front doors open. | partly | no | the gear reading; p1190 43093: locked: the couplings ask for two different turns at once p1235 43093: locked: the couplings ask…; still: p1171 11954, p1216 11954 |
| 41999-1 | 7 | The whole body shell tilts up on a hinge at the back, for getting at the battery box and … | partly | works | a drag's loop |
| 41999-1 | 8 | The headlights (two Power Functions LEDs) light up when the battery box is switched on. | not checked | not checked |  |
| 42000-1 | 1 | The steering wheel in the cockpit steers the front wheels: its column runs forward under … | works | works | a drag's loop |
| 42000-1 | 2 | Rolling the car turns the V8 engine: the rear wheels drive a differential through two hal… | partly | partly | the gear reading; still: p274 62821, p395 2853, p396 2852 |
| 42000-1 | 3 | The black knob on the side behind the cockpit, with the yellow selector lever above it, w… | partly | partly | the gear reading; still: p105 92693c01, p252 3706, p1089 92693c01 |
| 42000-1 | 4 | Each front wheel rides on double wishbones with a pushrod to a rocker inside the nose, wh… | partly | partly | a drag's loop; still: p559 32056, p566 4255 |
| 42000-1 | 5 | Each rear wheel rides on double wishbones with a pushrod to a rocker above the gearbox, w… | partly | partly | a drag's loop; still: p298 87083, p464 4254 |
| 42000-1 | 6 | The shock absorbers' springs hold the car up on its suspension. | skipped | skipped |  |
| 42000-1 | 7 | The front wheels roll freely. | works | works | the gear reading |
| 42004-1 | 1 | The knob on the cab roof steers: its vertical shaft drives a 20-tooth gear that turns the… | works | partly | the gear reading and 1 loop it turns |
| 42004-1 | 2 | Turning the exhaust stack raises and lowers the loader arm: the stack is the top of a ver… | works | works | the gear reading |
| 42004-1 | 3 | The black gear on the side of the loader arm's front tilts the loader bucket: it turns a … | works | works | a drag's loop |
| 42004-1 | 4 | The knob on top of the backhoe's upright shaft raises and lowers the backhoe boom: a worm… | no | works | the gear reading |
| 42004-1 | 5 | The black gear at the top of the boom swings the backhoe's stick (dipper) in and out; it … | no | works | a drag's loop |
| 42004-1 | 6 | The backhoe bucket hangs on a click hinge at the end of the stick and is set by hand. | no | works | the gear reading |
| 42004-1 | 7 | The four wheels roll freely. | works | works | the gear reading |
| 42004-1 | 8 | The steering wheel in the cab turns on its pin; it isn't connected to anything. | works | works | the gear reading |
| 42006-1 | 1 | The black knob at the back of the superstructure drives a gearbox; two red change-over le… | works | works | the gear reading |
| 42006-1 | 2 | With the rear lever's ring on its back gear, the knob raises and lowers the boom: a shaft… | partly | partly | the gear reading; p240 87083, worked first, went 0.09 of 0.4; still: p206 60485, p361 62274c01, p389 32278 |
| 42006-1 | 3 | With the rear lever's ring on its front gear, the knob moves the stick (arm) in and out: … | partly | partly | the gear reading; p240 87083, worked first, went -0.09 of -0.4; still: p250 55013, p458 62274c01, p486 32209 |
| 42006-1 | 4 | With the front lever's ring engaged, the knob opens and closes the four-claw grab: the ot… | partly | partly | the gear reading; p239 87083, worked first, went 0.09 of 0.4; still: p253 99008, p425 3737, p648 92695 |
| 42006-1 | 5 | The superstructure slews all the way round (360 degrees) on the big turntable over the tr… | not checked | not checked |  |
| 42006-1 | 6 | The tracks run freely round their sprockets; nothing drives them. | works | works | the gear reading |
| 42020-1 | 1 | Turning either rotor turns the other: a long shaft under the roof joins the two rotor hea… | works | partly | the gear reading; a drag on its joint; still: p137 57585, p100 57585, p89 32270 |
| 42020-1 | 2 | The four wheels roll freely. | works | works | the gear reading |
| 42020-1 | 3 | The nose wheels' strut turns on a vertical axle, so the front wheels castor. | works | works | the gear reading |
| 42020-1 | 4 | The small bent liftarm with two half-beams under the tail hangs on a pin and swings. | works | no | p60 32140: Simulate has no joint it turns on (floating) |
| 42021-1 | 1 | Turning the handlebars steers both front skis: the steering column turns a short arm unde… | works | partly | the gear reading; still: p12 15460, p169 92907 |
| 42021-1 | 2 | Each ski rides on its own pair of wishbones (independent front suspension): pushing a ski… | partly | no | the gear reading; p8 15459: locked: the couplings ask for two different turns at once p9 15459: locked: the couplings ask for t…; still: p11 15459, p12 15460 |
| 42021-1 | 3 | The two shock absorbers' springs hold the front up. | skipped | skipped |  |
| 42021-1 | 4 | Each ski pivots on its mount, so its tip can tilt up and down over bumps. | works | no | p170 92907 is part of the frame p179 92907 is part of the frame |
| 42021-1 | 5 | The track's four 20-tooth wheels turn freely, and the rubber-linked track runs round them. | works | works | the gear reading |
| 42021-1 | 6 | The track unit is pinned to the body at two places and doesn't pivot. | not checked | not checked |  |
| 42022-1 | 1 | The knob on the upright post behind the cab steers the front wheels: a bevel gear at its … | works | partly | the gear reading; still: p61 32293, p205 48989, p206 48989 |
| 42022-1 | 2 | Rolling the car turns the V6 engine: one rear wheel's axle drives, through bevel gears an… | partly | partly | the gear reading and 1 loop it turns; moved: p314 2851 |
| 42022-1 | 3 | The other rear wheel and the two front wheels roll freely. | works | works | the gear reading |
| 42022-1 | 4 | The black gear knob on the cab's side opens the body: turning it swings the blue side pan… | works | works | a drag's loop |
| 42023-1 | 1 | The black knob on the cab roof steers the front wheels: its upright axle turns a short cr… | no | partly | a drag's loop |
| 42023-1 | 2 | Turning the cross axle under the front of the dump body (by either end) tips the body: a … | partly | partly | the gear reading; still: p244 92695, p213 64782 |
| 42023-1 | 3 | The dump body's tailgate hangs from pins at its top and swings open as the body tips, let… | works | works | the gear reading |
| 42023-1 | 4 | The two front wheels and the four wheels on the two rear axles roll freely. | works | works | the gear reading |
| 42024-1 | 1 | The black gear on top of the upright axle behind the cab steers the front wheels: knob ge… | works | partly | the gear reading; still: p462 32072, p439 32072, p436 32270 |
| 42024-1 | 2 | The yellow handle low on the left side, behind the front wheel, works a gearbox in the mi… | no | partly | a drag's loop; still: p561 6539 |
| 42024-1 | 3 | With the arms chosen, turning the black gear on the right side behind the front wheel swi… | partly | partly | the gear reading; p50 32039, worked first, went 0.01 of 0.5; still: p562 32270, p547 6542b, p570 3648b |
| 42024-1 | 4 | With the stabilisers chosen, turning the same black gear lowers or raises the two stabili… | partly | partly | the gear reading; p50 32039, worked first, went -0.02 of -0.5; still: p546 6542b, p584 94925, p656 92695 |
| 42024-1 | 5 | The front wheels and the four wheels on the two rear axles roll freely; nothing is driven… | works | works | a drag on its joint |
| 42024-1 | 6 | The optional Power Functions motor and battery box (not in the set) can be fitted under t… | not checked | not checked |  |
| 42026-1 | 1 | The two big rear wheels turn together on their axle, which runs through the pull-back mot… | works | no | p120 56145 is part of the frame (#125 56145, keyed in its axle hole, #26 3708; #26 3708, keyed in its axle ho…; still: p120 56145, p121 56145 |
| 42026-1 | 2 | Pull the racer back along the floor and let go: the pull-back motor's spring drives the r… | skipped | skipped |  |
| 42026-1 | 3 | The two front wheels roll freely on their axle; there's no steering. | works | works | the gear reading |
| 42026-1 | 4 | The steering wheel in the cockpit turns, but steers nothing. | works | works | the gear reading |
| 42029-1 | 1 | The black gear on top of the upright axle behind the cab steers the front wheels: a bevel… | works | no | the gear reading; p656 32270: locked: the couplings ask for two different turns at once; still: p437 6589, p415 32270, p405 87761 |
| 42029-1 | 2 | The steering wheel in the cab turns, but isn't linked to the front wheels. | works | works | a drag on its joint |
| 42029-1 | 3 | As the truck rolls, the rear wheels drive the V6 engine: the rear differential's ring gea… | partly | partly | a drag on its joint; still: p457 62821, p356 94925, p367 6542b |
| 42029-1 | 4 | The rear differential lets the two rear wheels turn at different speeds on corners. | works | works | a drag on its joint |
| 42029-1 | 5 | The yellow lever inside the cab, on the right behind the seat, works a gearbox under the … | works | partly | the gear reading; still: p48 6539 |
| 42029-1 | 6 | With the winch chosen, turning the black gear low on the right side, under the door, wind… | partly | partly | the gear reading; still: p64 6542b, p55 94925, p832 4716 |
| 42029-1 | 7 | With the bed chosen, turning the same black gear tips the pick-up bed: the gearbox's othe… | partly | partly | the gear reading; still: p49 6542b, p62 94925, p597 92695 |
| 42029-1 | 8 | The bonnet hinges up at its back edge to show the engine. | works | works | the gear reading and 1 loop it turns |
| 42029-1 | 9 | The front and rear axles are each sprung on two shock absorbers, so they can tilt and ris… | skipped | skipped |  |
| 42029-1 | 10 | The optional Power Functions motor and battery box (not in the set) can be fitted to driv… | not checked | not checked |  |
| 42031-1 | 1 | The black knob at the back of the boom's yellow mount turns a worm, which turns the 24-to… | works | works | the gear reading |
| 42031-1 | 2 | The whole boom, with its yellow mount, turns round on a single upright pin on top of the … | works | no | p101 6632 is part of the frame; still: p101 6632, p122 11478 |
| 42031-1 | 3 | The work basket hangs from the boom tip on pins and a pin joiner, so it swings and swivel… | works | works | the gear reading |
| 42031-1 | 4 | The four wheels roll freely, each on its own pin; there's no steering. | works | works | the gear reading |
| 42032-1 | 1 | The gear-wheel knob at the back turns a worm, which turns a 24-tooth gear behind the cab;… | works | works | the gear reading |
| 42032-1 | 2 | The upright lever on the left loader arm tilts the bucket: rocking it pushes a long white… | no | partly | a drag's loop; still: p114 42032 - 33299b; moved: p139 59443 |
| 42032-1 | 3 | The upright lever on the right loader arm tilts the fork above the bucket up and down, th… | no | works | a drag's loop |
| 42032-1 | 4 | The two tracks run round their wheels, so the loader rolls along. | works | no | p156 32556 is part of the frame (#157 32556a, a pin in the first thing it is in, #154 40490; #154 40490, two … |
| 42033-1 | 1 | The two big rear wheels turn together on their axle, which runs through the pull-back mot… | works | no | p118 56145 is part of the frame (#119 56145, keyed in its axle hole, #14 60485; #14 60485, keyed in its axle …; still: p118 56145, p120 56145 |
| 42033-1 | 2 | Pull the car back along the floor and let go: the pull-back motor's spring drives the rea… | skipped | skipped |  |
| 42033-1 | 3 | The two small front wheels roll freely on their axle. | partly | works | a drag on its joint |
| 42033-1 | 4 | The clear canopy over the cockpit swings up to open. | works | works | the gear reading |
| 42033-1 | 5 | The steering wheel in the cockpit turns, but steers nothing: the front wheels are on a fi… | works | works | the gear reading |
| 42034-1 | 1 | The two rear wheels turn together on their axle, which runs through the pull-back motor a… | works | no | p137 56145 is part of the frame (#138 56145, keyed in its axle hole, #83 3708; #83 3708, keyed in its axle ho…; still: p137 56145, p139 56145 |
| 42034-1 | 2 | Pull the quad back along the floor and let go: the pull-back motor's spring drives the re… | skipped | skipped |  |
| 42034-1 | 3 | The two front wheels roll freely on their axle; there's no steering, the handlebars are f… | works | works | the gear reading |
| 42035-1 | 1 | The black gear on top of the tall yellow column behind the cab steers the front wheels: t… | works | works | a drag's loop |
| 42035-1 | 2 | As the truck rolls, the right rear wheel drives the engine: its 20-tooth bevel gear turns… | works | partly | the gear reading; still: p49 6589, p96 10928, p122 94925 |
| 42035-1 | 3 | The left rear wheel rolls freely on its own axle. | partly | works | the gear reading |
| 42035-1 | 4 | The two front wheels roll freely on their steering hubs. | works | works | the gear reading |
| 42035-1 | 5 | The black gear on the axle sticking out of the left side behind the cab tips the dump bod… | works | works | a drag's loop |
| 42036-1 | 1 | Pushed along, the rear wheel runs the four-cylinder engine: a 24 tooth sprocket on the re… | partly | partly | the gear reading; still: p129 94925, p117 6542b, p107 3648b |
| 42036-1 | 2 | The rear wheel rides on a swing arm pivoted under the seat, with a yellow shock absorber … | partly | no | the gear reading; p79 64290: locked: the couplings ask for two different turns at once; still: p118 88517, p455 4254 |
| 42036-1 | 3 | The front wheel rides between two long shock absorbers, a telescopic front fork, so it mo… | partly | partly | the gear reading; still: p233 88517 |
| 42036-1 | 4 | The shock absorbers' springs hold the bike up and spring back. | skipped | skipped |  |
| 42036-1 | 5 | The handlebars steer the front fork and wheel. | no | partly | a drag's loop; still: p233 88517 |
| 42036-1 | 6 | The kickstand under the right side swings down to hold the bike up, and folds back up. | no | works | the gear reading |
| 42036-1 | 7 | Both wheels roll freely. | partly | partly | the gear reading; p233 88517 is part of the frame (#235 88517, keyed in its axle hole, #232 44294; #232 44294, keyed in its axl… |
| 42037-1 | 1 | Pushed along, the rear wheels run the inline four-cylinder engine in front of the seat: t… | partly | partly | a drag on its joint; still: p225 62821, p214 32269, p136 94925 |
| 42037-1 | 2 | The rear differential lets the two rear wheels turn at different speeds; with the car lif… | works | partly | a drag on its joint; still: p493 45982, p225 62821 |
| 42037-1 | 3 | The black gear on top of the roll cage behind the seat steers the front wheels (hand of g… | partly | no | the gear reading; p349 32270: locked: the couplings ask for two different turns at once; still: p34 3737, p54 87761, p66 11949 |
| 42037-1 | 4 | The front wheels each have independent suspension: each steering hub rides between an upp… | partly | no | the gear reading; p58 57515: locked: the couplings ask for two different turns at once p72 57515: locked: the couplings ask for…; still: p66 11949, p76 11949, p96 76537 |
| 42037-1 | 5 | The rear wheels each have independent suspension: each hub rides on two pairs of arms wit… | works | no | the gear reading; p229 32063: locked: the couplings ask for two different turns at once p241 32063: locked: the couplings ask f…; still: p235 11950, p236 11950, p290 4254 |
| 42037-1 | 6 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 42037-1 | 7 | The steering wheel in front of the seat turns freely; it isn't linked to the steering. | works | works | the gear reading |
| 42038-1 | 1 | The black gear on top of the frame behind the cab steers (hand of god steering): its vert… | no | no | the gear reading; p170 32270: locked: the couplings ask for two different turns at once; still: p290 32270, p288 64781, p284 92909 |
| 42038-1 | 2 | With the red selector lever in position 1, the knob on top of the frame (a black axle joi… | partly | partly | the gear reading; p69 18947, worked first, went 0.0 of -10.0; still: p69 18947, p67 18946, p6 94925 |
| 42038-1 | 3 | With the lever in position 2, the same knob raises and lowers the crane's boom: the other… | partly | partly | the gear reading; p69 18947, worked first, went 0.0 of 10.0; still: p69 18947, p71 18946, p33 94925 |
| 42038-1 | 4 | The red selector lever beside the knob slides the driving ring between the two clutch gea… | works | no | p84 2736: Simulate has no joint it turns on (floating); still: p69 18947 |
| 42038-1 | 5 | The crane slews round on its turntable behind the cab, turned by hand; a 20 tooth gear be… | works | works | a drag's loop |
| 42038-1 | 6 | The black gear at the crane's base winds the winch, raising and lowering the hook and its… | works | works | the gear reading |
| 42038-1 | 7 | The front and rear axles each swing side to side on a central pivot, with a shock absorbe… | partly | partly | the gear reading; p280 41239: locked: the couplings ask for two different turns at once; still: p284 92909, p237 92909 |
| 42038-1 | 8 | The shock absorbers' springs hold the axles level and spring back. | skipped | skipped |  |
| 42038-1 | 9 | Each of the four track units rocks on its hub, and its track runs freely round its sprock… | works | no | p646 41239 is part of the frame p671 41239 is part of the frame p696 41239 is part of the frame p721 41239 is… |
| 42038-1 | 10 | The cab's top tips forward on a hinge, to reach inside (where the Power Functions battery… | not checked | not checked |  |
| 42038-1 | 11 | The steering wheel in the cab turns freely; it isn't linked to the steering. | works | works | the gear reading |
| 42038-1 | 12 | With the Power Functions motor fitted (sold separately, 8293), the motor turns the knob's… | not checked | not checked |  |
| 42039-1 | 1 | Pushed along, the rear wheels run the V8 engine behind the seats: the rear differential's… | works | partly | the gear reading; still: p6 62821, p5 32269, p178 2854 |
| 42039-1 | 2 | The rear differential lets the two rear wheels turn at different speeds; with the car lif… | works | partly | the gear reading; still: p1295 15038, p6 62821 |
| 42039-1 | 3 | The black gear on top of the roof steers the front wheels (hand of god steering): its ver… | works | partly | the gear reading; still: p560 3737, p558 32270, p548 87761 |
| 42039-1 | 4 | The steering wheel in the cockpit turns. | works | works | the gear reading |
| 42039-1 | 5 | The front wheels each have independent pushrod suspension: each hub rides between an uppe… | partly | no | the gear reading; p482 57515: locked: the couplings ask for two different turns at once p486 57515: locked: the couplings ask f…; still: p515 11949, p520 11949, p506 4254 |
| 42039-1 | 6 | The rear axle is sprung on two shock absorbers. | no | partly | a drag on its joint; still: p80 4254, p82 4254 |
| 42039-1 | 7 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 42039-1 | 8 | With the red selector lever on the side in position 1, the black gear on the car's left s… | partly | partly | the gear reading; p636 18947, worked first, went 0.0 of 10.0; still: p636 18947, p670 18946, p653 4716 |
| 42039-1 | 9 | With the lever in position 2, the same gear lifts the rear engine cover, which tips back … | works | partly | the gear reading; p636 18947, worked first, went 0.0 of -10.0; still: p636 18947, p633 18946, p637 94925 |
| 42039-1 | 10 | The red selector lever slides the driving ring between the two clutch gears: position 1 f… | works | partly | the gear reading; still: p636 18947 |
| 42039-1 | 11 | With the Power Functions motor fitted (sold separately), the motor in the nose turns the … | not checked | not checked |  |
| 42040-1 | 1 | Pushed along on the little wheels under its floats, the plane turns its propeller and eng… | partly | partly | the gear reading; still: p557 99012, p75 2853 |
| 42040-1 | 2 | The propeller turns the engine's crankshaft, and the pistons pump up and down in their cy… | works | works | a drag's loop |
| 42040-1 | 3 | The hatch on top of the fuselage, behind the engine, flips forward to fill the tank with … | works | no | p251 32140 is part of the frame |
| 42040-1 | 4 | Pressing the knob on top of the fuselage drops the water: it pushes down a shaft that rel… | partly | partly | a drag on its joint; still: p226 60483, p234 2736 |
| 42040-1 | 5 | The trapdoor under the tank swings down by its own weight once released, and is pushed sh… | skipped | skipped |  |
| 42040-1 | 6 | The red joystick on top behind the wing, tilted side to side, works the ailerons: its col… | partly | partly | a drag's loop; still: p381 32072, p384 32072, p405 32072 |
| 42040-1 | 7 | Tilted forward and back, the joystick works the elevator: a steering link under it pulls … | partly | partly | a drag's loop; still: p338 18945 |
| 42040-1 | 8 | The rudder on the fin swings side to side. | no | no | the gear reading; p314 92907: locked: the couplings ask for two different turns at once; still: p311 40490 |
| 42040-1 | 9 | The wheels under the floats roll. | works | works | the gear reading |
| 42041-1 | 1 | Pushed along, the rear wheels run the V8 engine behind the cab: the rear differential's 2… | works | no | p647 56908 is part of the frame (#648 56908, keyed in its axle hole, #161 59426) p649 56908 is part of the fr…; still: p153 62821, p155 6589, p198 32269 |
| 42041-1 | 2 | The rear differential lets the two rear wheels turn at different speeds; with the truck l… | works | no | p647 56908 is part of the frame (#648 56908, keyed in its axle hole, #161 59426); still: p649 56908, p153 62821 |
| 42041-1 | 3 | The gear on top of the cab's roof steers the front wheels (hand of god steering): a long … | works | no | p319 32270 is part of the frame (#320 32270, keyed in its axle hole, #319 4519; #319 4519, keyed in its axle …; still: p283 32072, p69 32072, p71 32270 |
| 42041-1 | 4 | The front wheels roll freely, and the four wheels together let the truck be pushed along. | works | works | the gear reading |
| 42041-1 | 5 | The steering wheel in the cab turns freely; it isn't linked to the steering. | no | no | p415 2819 is part of the frame (#416 2819, keyed in its axle hole, #414 4519; #414 4519, keyed in its axle ho… |
| 42042-1 | 1 | The Power Functions L motor at the back of the superstructure runs the gearbox: a 24 toot… | works | works | the gear reading |
| 42042-1 | 2 | Lever B: with its driving ring pushed one way or the other, the motor drives both tracks … | works | partly | the gear reading; p576 18947, worked first, went 0.0 of 10.0; still: p576 18947, p710 62520, p45 6589 |
| 42042-1 | 3 | Lever C: the motor slews the superstructure round on the crawler: the driving ring's shaf… | partly | partly | the gear reading; p577 18947, worked first, went 0.0 of 10.0; still: p577 18947, p581 10928, p588 76019 |
| 42042-1 | 4 | Lever A: the motor raises and lowers the boom: the driving ring's shaft turns a 20 tooth … | no | partly | the gear reading; p575 18947, worked first, went 0.0 of 10.0; still: p575 18947, p525 32269, p796 32270 |
| 42042-1 | 5 | Lever D: the motor raises and lowers the grab: the driving ring's shaft turns a 20 tooth … | works | partly | the gear reading; p578 18947, worked first, went 0.0 of 10.0; still: p578 18947, p530 32269, p797 32270 |
| 42042-1 | 6 | The four levers on the superstructure (two pairs) each slide one driving ring forward or … | partly | partly | the gear reading; still: p575 18947, p576 18947, p577 18947 |
| 42042-1 | 7 | The black knob gear on top of the grab opens and closes its four claws: it turns a 20 too… | works | partly | the gear reading and 1 loop it turns; still: p1337 11953, p1339 11953, p1340 11953 |
| 42042-1 | 8 | The cab's door swings open. | no | partly | a drag's loop |
| 42042-1 | 9 | The tracks run round their sprockets and rollers when driven. | works | works | the gear reading |
| 42042-1 | 10 | The spare boom section can be fitted into the boom to make it 12 cm longer. | not checked | not checked |  |
| 42043-1 | 1 | One Power Functions L-motor in the chassis behind the cab, switched on and reversed at th… | partly | partly | the gear reading; still: p1703 3707, p1704 94925, p1692 18946 |
| 42043-1 | 2 | Function A: with the red lever on the right of the chassis pushed forward, to A, the moto… | partly | partly | the gear reading; p2200 6536, worked first, went 0.0 of 0.4; still: p1898 62274c01, p7053 64782 |
| 42043-1 | 3 | Function D: with the same right lever pulled back, to PUMP, the motor works the pneumatic… | partly | partly | the gear reading; p2200 6536, worked first, went 0.0 of -0.4; still: p1723 18946, p1663 32269, p1670 32062 |
| 42043-1 | 4 | Function C: with the red lever on the left of the chassis pushed forward, to C, the motor… | partly | partly | the gear reading; p2181 6536, worked first, went 0.0 of 0.4; still: p1722 18947, p1706 18946, p1709 18946 |
| 42043-1 | 5 | Function B: with the left lever pulled back, to B, the motor slides the two outriggers ou… | partly | partly | the gear reading; p2181 6536, worked first, went 0.0 of -0.4; still: p1722 18947, p1724 18946, p1616 32269 |
| 42043-1 | 6 | Function L: each outrigger's foot is lowered or raised by hand: turning the black 12-toot… | partly | partly | the gear reading; still: p1538 4519, p1536 4716, p1530 10928 |
| 42043-1 | 7 | Functions E, F, G and H: the four pneumatic switches on the red crane base work the crane… | skipped | skipped |  |
| 42043-1 | 8 | Function K: the orange beacons on the two back corners of the cab's roof are knobs that s… | works | partly | the gear reading; still: p1123 32005, p2217 86652, p2211 86652 |
| 42043-1 | 9 | The steering wheel in the cab turns freely; it doesn't steer. | works | works | the gear reading |
| 42043-1 | 10 | Pushing the truck along runs the six-cylinder engine under the cab: both rear axles are d… | partly | partly | the gear reading; still: p2036 62821, p2104 62821, p2029 62520 |
| 42043-1 | 11 | The two rear axles each have a differential, so their wheels can turn at different speeds… | works | partly | the gear reading; still: p2036 62821 |
| 42043-1 | 12 | All four axles have suspension: each axle swings on its shock absorbers, hard springs on … | skipped | skipped |  |
| 42043-1 | 13 | Function i: the tipper's tailgate is locked by a lever at the back on the right; with it … | partly | partly | the gear reading; still: p7226 32073, p7228 32524 |
| 42043-1 | 14 | Function J: the two cab doors open. | works | works | the gear reading |
| 42043-1 | 15 | Function M: the whole cab tilts forward. | partly | no | the gear reading; p6963 64782: locked: the couplings ask for two different turns at once; still: p6909 2741, p6740 32316 |
| 42044-1 | 1 | The 12-tooth bevel gear on the fuselage's right side is a knob that raises and lowers the… | works | partly | the gear reading; still: p106 42610, p34 32293, p25 32073 |
| 42044-1 | 2 | The canopy, made of two flexible axles over the cockpit, hinges up at its front to open t… | works | works | the gear reading |
| 42044-1 | 3 | The three landing gear wheels roll freely. | works | works | the gear reading |
| 42045-1 | 1 | Pushing the hydroplane along on the two small wheels under its nose runs the inline four-… | works | works | the gear reading and 1 loop it turns |
| 42045-1 | 2 | The engine spins the propeller at the back: an axle in the crankshaft's rear end carries … | partly | works | the gear reading and 1 loop it turns |
| 42046-1 | 1 | The rear wheels' 12-long axle runs through the pull-back motor under the back of the car,… | works | no | p157 56145 is part of the frame (#158 56145, keyed in its axle hole, #94 3708; #94 3708, keyed in its axle ho…; still: p93 3708, p158 55978, p164 55978 |
| 42046-1 | 2 | The front wheels roll freely on their own 12-long axle; there's no steering. | works | works | the gear reading |
| 42046-1 | 3 | The pull-back motor: pull the car backwards along the ground and let go, and its spring d… | skipped | skipped |  |
| 42047-1 | 1 | The rear wheels' 12-long axle runs through the pull-back motor at the back of the chassis… | works | works | the gear reading |
| 42047-1 | 2 | The front wheels roll freely on their own 12-long axle; there's no steering. | works | works | the gear reading |
| 42047-1 | 3 | The pull-back motor: pull the car backwards along the ground and let go, and its spring d… | skipped | skipped |  |
| 42048-1 | 1 | The steering wheel steers the front wheels: the column's foot carries a short liftarm wit… | partly | partly | the gear reading; still: p132 40490, p118 48989, p119 48989 |
| 42048-1 | 2 | The red gear lever on the seat's left has three positions, 1, N and 2: it turns a cross s… | works | partly | the gear reading; still: p278 32293, p215 6641, p67 18947 |
| 42048-1 | 3 | With a gear engaged, pushing the kart along runs its one-cylinder engine: the rear axle t… | works | partly | the gear reading; still: p63 44294, p222 44294, p246 3648b |
| 42048-1 | 4 | The four wheels roll; the rear wheels share one axle (made of two 7-long axles joined by … | works | works | the gear reading |
| 42049-1 | 1 | The knob on top behind the cab (the hand-of-god gear) steers the loader by bending it in … | partly | no | p96 32270: Simulate has no joint it turns on (floating); still: p94 60485, p180 32270, p210 42049 - 18938 |
| 42049-1 | 2 | The 12-tooth gear knob at the back of the top, on the left, opens and closes the claw: it… | no | no | the gear reading; p101 32270: locked: the couplings ask for two different turns at once; still: p66 32269, p57 32269, p61 94925 |
| 42049-1 | 3 | The tall yellow lever standing on the front half raises and lowers the arm: pulling it ba… | partly | partly | a drag's loop |
| 42049-1 | 4 | Pushing the loader along runs its two-cylinder engine: both rear wheels' half axles carry… | works | partly | the gear reading; p468 86652: locked: the couplings ask for two different turns at once; still: p5 55013, p6 32269, p128 32270 |
| 42049-1 | 5 | The two rear wheels turn together, geared to the same shaft; the two front wheels roll fr… | works | partly | the gear reading; p468 86652: locked: the couplings ask for two different turns at once |
| 42050-1 | 1 | Pushing the dragster along runs its V8 engine: the rear axle's 20-tooth bevel gear turns … | works | works | the gear reading and 2 loops it turns |
| 42050-1 | 2 | The 12-tooth gear knob on top of the car, behind the cockpit, steers the front wheels: it… | works | partly | the gear reading; still: p57 94925, p46 94925, p32 32270 |
| 42050-1 | 3 | Function A: the black lever just in front of the right rear wheel, swung back, tilts the … | no | works | a drag's loop |
| 42050-1 | 4 | Function B: turning the knob just in front of the right rear wheel works the linear actua… | partly | partly | the gear reading; still: p242 92696 |
| 42050-1 | 5 | The four wheels roll; the front wheels turn on their steering hubs and the wheelie bars' … | works | works | the gear reading |
| 42052-1 | 1 | One Power Functions M-motor, switched on and reversed at the battery box under the nose, … | partly | partly | the gear reading; still: p239 15462, p241 94925, p261 18946 |
| 42052-1 | 2 | Function A: with the lever on the right side behind the cockpit pushed to A, the motor tu… | partly | partly | the gear reading; p131 6553, worked first, went 0.1 of 0.4; still: p272 18947, p276 18946, p278 18946 |
| 42052-1 | 3 | Function B: with the right lever pushed to B, the motor lowers or raises the rear loading… | partly | partly | the gear reading; p131 6553, worked first, went -0.1 of -0.4; still: p272 18947, p248 18946, p262 94925 |
| 42052-1 | 4 | Function C: with the lever on the left side pushed to C, the motor swings the two orange … | partly | partly | the gear reading; p132 6553, worked first, went 0.0 of 0.4; still: p271 18947, p275 18946, p168 94925 |
| 42052-1 | 5 | Function D: with the left lever pushed to D, the motor winds the winch, raising or loweri… | partly | partly | the gear reading; p132 6553, worked first, went 0.0 of -0.4; still: p271 18947, p249 18946, p253 94925 |
| 42052-1 | 6 | With a lever in the middle, between its two positions, its driving ring locks neither clu… | not checked | not checked |  |
| 42052-1 | 7 | The landing gear's wheels roll freely: two small nose wheels and two larger main wheels. | works | works | a drag on its joint; the gear reading |
| 42053-1 | 1 | Pumping the hand pump on the upper body's right side, pushing its black top down, fills t… | skipped | skipped |  |
| 42053-1 | 2 | Valve A, the left one of the three valve levers along the back of the upper body (seen fr… | skipped | skipped |  |
| 42053-1 | 3 | Valve B, the middle lever, sends air to the cylinder on top of the boom, which swings the… | skipped | skipped |  |
| 42053-1 | 4 | Valve C, the right lever, sends air to a small cylinder inside the grab at the stick's en… | skipped | skipped |  |
| 42053-1 | 5 | The knob on top of the upper body, behind the cab, raises and lowers the cab: its upright… | no | partly | the gear reading; still: p2222 42053 - 33299b, p2407 32073 |
| 42053-1 | 6 | The 20 tooth gear at the back of the chassis steers the front wheels: a long shaft down t… | works | partly | the gear reading; still: p78 32270, p66 87761, p55 59426 |
| 42053-1 | 7 | The upper body, with the boom and cab, slews round by hand on the turntable on top of the… | partly | partly | a drag's loop; still: p0 92907; moved: p66 87761, p55 59426 |
| 42053-1 | 8 | The two rear outriggers swing down from the chassis' back corners onto their feet, and a … | works | works | the gear reading |
| 42053-1 | 9 | The four wheels roll freely; there is no drive. | works | works | the gear reading |
| 42054-1 | 1 | The Power Functions M motor at the front, under the bonnet, runs all the time it is switc… | partly | partly | the gear reading; still: p457 3648b, p513 3648b, p366 94925 |
| 42054-1 | 2 | The upper of the two grey levers on the fuel tank on the right side, turned up, switches … | no | no | the gear reading; p824 41669: locked: the couplings ask for two different turns at once |
| 42054-1 | 3 | Lever A, the lower grey lever on the fuel tank, turned up or down, rotates the whole cab … | partly | partly | the gear reading; still: p303 18947, p692 42054 - 18938, p1176 64782 |
| 42054-1 | 4 | Lever B, the left of the two red levers at the back of the crane's base, pushed up or dow… | partly | partly | the gear reading; still: p1627 18947, p1820 92696, p1841 40490 |
| 42054-1 | 5 | Lever C, the right red lever, pushed up or down, slews the crane round one way or the oth… | partly | partly | the gear reading; still: p1620 18947, p1659 42054 - 18938 |
| 42054-1 | 6 | The small gear on top of the boom's end slides the jib in and out: it runs on the rack al… | works | works | a drag's loop |
| 42054-1 | 7 | Turning the gear at the back of the grab opens and closes it: a worm turns a 24 tooth gea… | works | works | the gear reading |
| 42054-1 | 8 | The grab hangs from the jib's tip on a small turntable, so it can be turned round by hand. | works | partly | the gear reading; still: p1924 3648b |
| 42054-1 | 9 | The whole crane rises and falls on the back of the tractor: the 12 tooth gears at both si… | no | partly | the gear reading; still: p1660 18939 |
| 42054-1 | 10 | The crane's two legs fold down from its base to stand on the ground, and lock there. | no | partly | a drag's loop; still: p1779 6558, p1768 6558 |
| 42054-1 | 11 | The knob at the top of the cab's back steers the tractor: a pair of bevel gears turns a s… | partly | no | the gear reading and 1 loop it turns; still: p12 87083, p200 3648b, p480 42054 - 23801 |
| 42054-1 | 12 | The red knob at the back, between the rear mudguards, picks one of three steering modes: … | works | works | the gear reading |
| 42054-1 | 13 | The four wheels roll freely; there is no drive to them. | works | works | a drag on its joint |
| 42054-1 | 14 | The bonnet tips up, giving access to the battery box. | works | works | the gear reading |
| 42055-1 | 1 | The orange switch on the battery box, at the back end of the counterweight boom, switches… | no | no | p3369 58119 is part of the frame (#3367 58119, a stud in its socket, #3151 58124c01; #3151 58124c01, held, #4… |
| 42055-1 | 2 | The XL motor, beside the gearbox on the counterweight boom, drives a gearbox whose three … | partly | partly | a drag on its joint; still: p2426 42055 - 24120, p2339 57520, p1869 57520 |
| 42055-1 | 3 | With the middle knob back, the right knob, pushed forward or back, slews the whole upper … | partly | partly | a drag on its joint; still: p418 64178 |
| 42055-1 | 4 | With the middle knob pushed forward, the left knob, pushed forward or back, drives the ex… | partly | partly | a drag on its joint; p3250 6641, worked first, went -0.57 of -1.0; still: p911 57520, p1018 57520, p910 57520 |
| 42055-1 | 5 | With the red lever at the back of the upper works in the middle (N), the black gear behin… | partly | partly | the gear reading; still: p1616 32270, p1599 42055 - 18938, p1869 57520 |
| 42055-1 | 6 | The red lever at the back, pushed down (lock), slides a driving ring that ties the discha… | works | no | p1678 6641: Simulate has no joint it turns on (floating); still: p1710 18947 |
| 42055-1 | 7 | The black gear at the foot of the tower, used as a crank, raises and lowers the bucket wh… | partly | no | the gear reading; p1809 32269: locked: the couplings ask for two different turns at once; still: p1510 62274c01, p1513 62274c01, p2535 42055 - 55615 |
| 42055-1 | 8 | The mine truck's white knob on top of its cab, a 12 tooth gear on an upright axle, steers… | works | works | a drag's loop |
| 42055-1 | 9 | The 12 tooth gear on the mine truck's side, used as a knob, tips the dump body up and low… | works | partly | the gear reading; still: p263 18945, p264 18945 |
| 42055-1 | 10 | The mine truck's four wheels roll freely. | works | works | the gear reading |
| 42056-1 | 1 | The steering wheel steers the front wheels: its column turns a cross shaft and a shaft wi… | works | partly | the gear reading; still: p450 32270, p626 32270, p585 32269 |
| 42056-1 | 2 | Pushed along in gear, the rear wheels run the flat six engine: half shafts with constant … | partly | partly | the gear reading; still: p689 62821, p910 2853, p917 2851 |
| 42056-1 | 3 | The paddle shifters behind the steering wheel shift the sequential gearbox up and down: e… | partly | partly | the gear reading; still: p340 32072, p155 32072, p234 18947 |
| 42056-1 | 4 | The gear lever on the centre console between the seats selects reverse, neutral or drive:… | partly | partly | a drag on its joint; still: p317 6641, p39 18947 |
| 42056-1 | 5 | Each front wheel has independent suspension: a double wishbone with a shock absorber lets… | partly | no | the gear reading; p535 57515: locked: the couplings ask for two different turns at once p543 57515: locked: the couplings ask f…; still: p2731 23800, p2734 23800 |
| 42056-1 | 6 | Each rear wheel has the same independent suspension, the half shafts reaching the wheels … | works | no | the gear reading; p757 32063: locked: the couplings ask for two different turns at once p784 32063: locked: the couplings ask f…; still: p2725 23800, p2728 23800 |
| 42056-1 | 7 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 42056-1 | 8 | The two doors swing open on hinges at their front edges. | partly | works | a drag's loop; the gear reading |
| 42056-1 | 9 | The front hood opens, hinged at its back edge by the windscreen, showing the luggage comp… | works | works | the gear reading and 1 loop it turns |
| 42056-1 | 10 | The suitcase in the luggage compartment opens. | no | works | the gear reading |
| 42056-1 | 11 | The rear wing's angle can be adjusted: the wing tilts on its two supports. | works | partly | a drag's loop |
| 42056-1 | 12 | The seats sit on their own pins and can be tipped or slid by hand. | works | works | the gear reading |
| 42057-1 | 1 | Turning the main rotor runs the three-cylinder engine behind the pilot: the rotor's mast … | works | partly | the gear reading and 1 loop it turns; still: p68 87083 |
| 42057-1 | 2 | The rear propeller turns with the engine and the main rotor. | partly | partly | a drag on its joint; still: p113 32209, p73 2854 |
| 42057-1 | 3 | The red lever on the helicopter's right side, under the engine, swings the tail rudder: a… | partly | works | a drag's loop |
| 42057-1 | 4 | The joystick in front of the pilot's seat tilts. | works | works | the gear reading |
| 42057-1 | 5 | The nose wheel and the two wheels on the red landing legs roll freely. | works | works | a drag on its joint; the gear reading |
| 42058-1 | 1 | Pull the bike back and let go: the pull-back motor drives the rear wheel through three 16… | works | no | the gear reading; p41 56145: locked: the couplings ask for two different turns at once; still: p18 94925, p21 18946, p17 94925 |
| 42058-1 | 2 | The pull-back motor's spring winds up as the bike is pulled back and drives it forward wh… | skipped | skipped |  |
| 42058-1 | 3 | The front wheel rolls freely. | works | works | the gear reading |
| 42058-1 | 4 | The stunt ramp, a printed cardboard sheet folded over two 9 long beams, stands on the gro… | not checked | not checked |  |
| 42059-1 | 1 | Pull the truck back and let go: the pull-back motor at the back turns the rear axle, a 12… | works | no | p126 56145 is part of the frame (#127 56145, keyed in its axle hole, #31 3708; #31 3708, keyed in its axle ho…; still: p30 3708 |
| 42059-1 | 2 | The pull-back motor's spring winds up as the truck is pulled back and drives it forward w… | skipped | skipped |  |
| 42059-1 | 3 | The front wheels roll freely, both on one 12 long axle; there's no steering. | works | works | the gear reading |
| 42059-1 | 4 | The stunt ramp, a printed cardboard sheet folded over two 9 long beams, stands on the gro… | not checked | not checked |  |
| 42060-1 | 1 | The black gear on the cab roof steers the truck's front wheels: its shaft runs down throu… | no | partly | the gear reading; still: p69 48989, p70 48989, p76 42060 - 18575 |
| 42060-1 | 2 | Turning the axle end on the side of the truck under the tipper tips the tipper up: a cran… | no | partly | the gear reading; still: p159 32525, p173 32525, p172 15458 |
| 42060-1 | 3 | The truck's four wheels roll freely. | works | works | the gear reading |
| 42060-1 | 4 | The trailer hangs on a hitch behind the truck and swings from side to side as it is towed… | works | works | the gear reading |
| 42060-1 | 5 | The round knob on top of the excavator's engine cover raises and lowers the boom: its upr… | partly | partly | the gear reading; still: p277 32316 |
| 42060-1 | 6 | Turning the axle at the boom's elbow swings the excavator's arm and bucket in and out: a … | no | partly | the gear reading; still: p288 42060 - 33299b, p295 32524 |
| 42060-1 | 7 | The excavator rides on two tracks of chain links, each over two 16 tooth gears, and rolls… | works | works | the gear reading |
| 42060-1 | 8 | The excavator's bucket sits on a hinge arm at the end of the arm and can be set at an ang… | works | works | the gear reading |
| 42061-1 | 1 | The gear on the cab roof steers all four wheels: its upright shaft runs down through the … | works | partly | the gear reading; still: p28 48989, p31 48989, p40 48989 |
| 42061-1 | 2 | The gear on the side of the chassis, between the wheels, raises and lowers the boom: its … | works | partly | a drag on its joint; still: p85 32348, p90 18940, p178 42061 - 28216 |
| 42061-1 | 3 | Turning the axle end at the back of the boom extends and retracts the boom's inner sectio… | partly | no | p199 59443 is part of the frame (#200 59443, keyed in its axle hole, #199 4519; #199 4519, keyed in its axle …; still: p170 18942, p178 42061 - 28216 |
| 42061-1 | 4 | The axle end on top of the boom's head tilts the bucket: it turns a worm, which turns an … | partly | partly | the gear reading; still: p178 42061 - 28216 |
| 42061-1 | 5 | The four wheels roll freely. | works | works | the gear reading |
| 42061-1 | 6 | The steering wheel in the cab turns on its own; it isn't linked to the steering. | works | works | the gear reading |
| 42062-1 | 1 | The black knob on the truck's cab roof steers the front wheels: its shaft runs down throu… | partly | partly | a drag's loop; still: p87 48989, p88 48989, p183 55981 |
| 42062-1 | 2 | The semi-trailer turns on its coupling behind the cab as the truck steers. | partly | partly | the gear reading; still: p188 32525 |
| 42062-1 | 3 | The truck's and the trailer's wheels roll freely. | works | works | the gear reading |
| 42062-1 | 4 | Twist locks at the trailer's corners turn to hold a container down on the trailer. | no | no | the gear reading; p213 3749: locked: the couplings ask for two different turns at once p214 3749: locked: the couplings ask for… |
| 42062-1 | 5 | The gear at the reach stacker's back end, the lower of two, steers its rear wheels: an ax… | partly | partly | the gear reading; still: p406 48989, p407 48989, p597 55981; moved: p510 18940 |
| 42062-1 | 6 | The upper gear at the reach stacker's back end raises and lowers the boom: a worm on its … | partly | works | the gear reading |
| 42062-1 | 7 | The knob beside the boom's base extends and retracts the boom: axles linked by angle conn… | works | works | a drag's loop |
| 42062-1 | 8 | The spreader turns on the boom's tip to line up with a container. | works | no | the gear reading; p547 32524: locked: the couplings ask for two different turns at once |
| 42062-1 | 9 | Turning the axle at the spreader's end swings its claws in to grip a container's top or o… | no | partly | the gear reading; still: p581 6553, p568 32526 |
| 42062-1 | 10 | The reach stacker's four wheels roll freely. | works | works | the gear reading |
| 42063-1 | 1 | The handlebars steer the front wheel: the whole front fork turns with them. | no | no | the gear reading; p418 32016: locked: the couplings ask for two different turns at once p419 32016: locked: the couplings ask f…; still: p386 88517, p345 32278 |
| 42063-1 | 2 | Pushing the bike along turns the boxer engine: the rear wheel's 20 tooth bevel gear turns… | works | partly | the gear reading; still: p23 32269, p64 2853, p67 2851 |
| 42063-1 | 3 | The front wheel rolls freely. | works | works | the gear reading |
| 42063-1 | 4 | The front wheel has suspension: the fork is held by a suspension arm under the tank (BMW'… | partly | no | a drag's loop; still: p386 88517, p164 4254 |
| 42063-1 | 5 | The rear wheel has suspension: it rides on a swing arm pivoted under the seat, with a sho… | partly | no | the gear reading; p72 14720: locked: the couplings ask for two different turns at once; still: p334 88517, p198 4254 |
| 42063-1 | 6 | The shock absorbers' springs hold the bike up and spring back. | skipped | skipped |  |
| 42063-1 | 7 | The side stand holds the bike upright when parked. | skipped | skipped |  |
| 42064-1 | 1 | Knob A, the left of the two black gears on the bridge roof, raises and lowers the crane's… | partly | partly | the gear reading; still: p255 32270, p214 4716, p218 3648b |
| 42064-1 | 2 | Knob B, the right of the two black gears on the bridge roof, slews the crane round on its… | no | partly | the gear reading; still: p350 94925, p248 32270, p224 99010 |
| 42064-1 | 3 | Knob C, the gear behind the bridge, steers the ship: its upright shaft turns a long shaft… | partly | partly | the gear reading; still: p330 6589, p17 11946, p18 11947 |
| 42064-1 | 4 | The ship rolls on hidden wheels under its hull: a single wheel under the bow, a pair in t… | works | works | the gear reading |
| 42064-1 | 5 | The helicopter's black gear under the rotor mast turns the main rotor, and through a pair… | partly | partly | the gear reading; still: p1327 6041 |
| 42064-1 | 6 | The submarine's rear knob on top turns its two propellers: a bevel gear pair takes the kn… | works | works | the gear reading |
| 42064-1 | 7 | The submarine's front knob on top swings its two arms with their grabbers out and in: the… | works | works | the gear reading |
| 42064-1 | 8 | The hook block hangs from the crane's boom tip, for lifting the submarine. | works | works | the gear reading |
| 42064-1 | 9 | The hatch on the foredeck, in front of the bridge, lifts open. | works | no | p1059 15458 is part of the frame |
| 42065-1 | 1 | The M motor at the back right drives the right track: its shaft's axle runs straight into… | partly | partly | the gear reading; still: p651 57518 |
| 42065-1 | 2 | The M motor at the front left drives the left track: its shaft's axle runs straight into … | partly | partly | the gear reading; still: p688 57518 |
| 42065-1 | 3 | With both tracks driven the same way the racer drives straight forwards or back; with one… | works | partly | the gear reading; still: p524 57519, p521 57519 |
| 42065-1 | 4 | The idler sprockets and the eight white road wheels turn freely as the tracks run round t… | works | works | the gear reading; a drag on its joint |
| 42065-1 | 5 | The whole green body tilts up on pins at its front, so the battery box can be reached, an… | partly | partly | a drag's loop; still: p529 6558 |
| 42065-1 | 6 | The battery box's switch turns the power on and off. | skipped | skipped |  |
| 42066-1 | 1 | The M motor, switched on at the battery box, runs a gearbox with two outputs; the two red… | partly | partly | the gear reading; still: p804 10928, p800 94925 |
| 42066-1 | 2 | With the right lever set, the motor raises and lowers the landing gear: a worm on the rig… | partly | partly | a drag's loop; still: p158 3648b, p244 3706, p400 40490 |
| 42066-1 | 3 | With the left lever set, the motor opens and closes the canopy, lowers the air brake unde… | partly | no | the gear reading; p1117 4716: locked: the couplings ask for two different turns at once; still: p159 3648b, p669 60483, p720 32524 |
| 42066-1 | 4 | The black knob on top of the fuselage between the tail fins turns both red rudders togeth… | partly | partly | the gear reading; still: p1193 40490, p1227 40490 |
| 42066-1 | 5 | The black knob on top of the fuselage behind the cockpit steers the nose wheel, through a… | no | works | a drag's loop |
| 42066-1 | 6 | The two main wheels and the twin nose wheels roll freely. | works | partly | the gear reading; p401 55982 is part of the frame p412 55982 is part of the frame |
| 42068-1 | 1 | The tan gear on top of the body, behind the boom, steers the front and rear axles togethe… | works | partly | a drag's loop; still: p1065 56145, p1071 56145 |
| 42068-1 | 2 | Pushing the truck along turns the V4 engine's pistons in the back: the middle axle's diff… | works | partly | the gear reading; still: p4 94925, p493 2853, p496 2851 |
| 42068-1 | 3 | The black knob at the back of the truck works the boom, through a gearbox chosen by the y… | partly | partly | the gear reading; still: p471 3648b, p425 99010 |
| 42068-1 | 4 | The black knob at the foot of the boom unfolds and folds the boom's upper section: throug… | works | partly | the gear reading; still: p983 32270, p1000 4716, p1002 10928 |
| 42068-1 | 5 | A shock absorber at the foot of the boom helps hold it up. | skipped | skipped |  |
| 42068-1 | 6 | The grey hatch on the side of the body, just behind the cab, swings open. | not checked | not checked |  |
| 42068-1 | 7 | The tool tray, with its axe, extinguisher and other tools, slides into the body from the … | no | no | p1083 64782 is part of the frame |
| 42068-1 | 8 | The six wheels roll freely. | works | works | the gear reading |
| 42069-1 | 1 | The knob on the roof, behind the windscreen, steers the front track units: an upright sha… | works | partly | the gear reading; still: p4 32270, p1894 32270, p1879 64781 |
| 42069-1 | 2 | The knob on the right side of the body (the side with the right door) winds the winch in … | works | partly | the gear reading; still: p299 32270, p316 32012 |
| 42069-1 | 3 | A ratchet on the winch stops it unwinding under load. | skipped | skipped |  |
| 42069-1 | 4 | The knob on the left side of the body raises the back of the roof, with its rack and jerr… | partly | partly | the gear reading; still: p566 92696, p1214 18945, p1215 18945 |
| 42069-1 | 5 | Pushing the vehicle along turns the V8 engine's pistons: the rear differential drives a s… | works | partly | a drag's loop; the gear reading; still: p1333 62821, p146 2853, p162 2851 |
| 42069-1 | 6 | The four track units roll; each pivots on its axle to follow the ground. | works | works | a drag's loop; the gear reading |
| 42069-1 | 7 | Each front door swings open, and a steering link from the door lowers the side step under… | partly | partly | the gear reading; p1172 32525 is part of the frame; still: p1150 62531, p1033 62531 |
| 42069-1 | 8 | The rear door, with the spare wheel on it, swings open, and the white tray inside slides … | partly | no | the gear reading; p1300 64782 is part of the frame (#1302 64782, two joints on two lines, #1298 40490) p722 64782: locked: the … |
| 42069-1 | 9 | The side panel at the back on each side flips up, showing the first aid kit and fire exti… | no | works | the gear reading |
| 42069-1 | 10 | Shock absorbers on each axle let the track units rise and fall. | skipped | skipped |  |
| 42070-1 | 1 | The XL motor drives all six wheels: through a 16 tooth gear it turns a centre differentia… | partly | partly | the gear reading; still: p405 18946, p448 94925, p381 6573 |
| 42070-1 | 2 | As the truck drives, the V8 engine under the bonnet pumps its pistons, turned from the dr… | partly | partly | the gear reading; still: p592 18946, p1057 94925, p1137 2853 |
| 42070-1 | 3 | The M motor steers the front wheels: through a 16 and 20 tooth gear, a 16 tooth clutch ge… | partly | partly | the gear reading; still: p406 18946, p390 76244, p430 18575 |
| 42070-1 | 4 | The drive/crane lever on the side of the cab switches both motors at once, from driving a… | works | partly | the gear reading; still: p1055 6641, p1056 6641, p403 18947 |
| 42070-1 | 5 | The crane-function lever behind the cab chooses which two crane functions the motors work… | works | no | p994 42070 - 33299a: Simulate has no joint it turns on (floating); still: p1067 6641, p1068 6641, p135 18947 |
| 42070-1 | 6 | In crane mode, the XL motor slews the crane round: its crane shaft drives through a 24 to… | partly | partly | the gear reading; still: p174 18946, p378 94925, p124 18946 |
| 42070-1 | 7 | In crane mode, the XL motor lowers and raises the outriggers: its crane shaft drives a ro… | partly | partly | the gear reading; still: p139 18946, p1005 18575, p1377 94925 |
| 42070-1 | 8 | In crane mode, the M motor winds the winch: its crane shaft drives up through the turntab… | partly | partly | the gear reading; still: p107 18946, p1003 10928, p1304 6573 |
| 42070-1 | 9 | In crane mode, the M motor raises and lowers the boom: its crane shaft drives an upright … | partly | partly | the gear reading; still: p138 18946, p130 94925, p100 42070 - 32198 |
| 42070-1 | 10 | The two rear axles each rock side to side on a turntable, so all six wheels stay on rough… | no | works | the gear reading |
| 42070-1 | 11 | The 24 tooth clutch gears in the steering and crane drives slip at the end of travel, so … | skipped | skipped |  |
| 42071-1 | 1 | The upright axle behind the cab steers the compactor by bending it in the middle: its 12 … | works | no | p92 26287: Simulate has no joint it turns on (floating); still: p20 18575, p22 99010, p145 64782 |
| 42071-1 | 2 | The upright axle in front of the cab raises and lowers the blade: a worm at its foot turn… | partly | works | the gear reading |
| 42071-1 | 3 | The four spiked compactor wheels roll freely; there is no drive. | works | works | the gear reading |
| 42072-1 | 1 | The rear wheels turn together on the axle through the pull-back motor: pulled back along … | works | no | p113 54087 is part of the frame (#114 54087, keyed in its axle hole, #71 3708; #71 3708, keyed in its axle ho…; still: p70 3708, p113 54087, p114 54087 |
| 42072-1 | 2 | The front wheels roll freely on their axle. | works | works | the gear reading |
| 42072-1 | 3 | When the car runs into a wall, the lever sticking out low at the front is knocked back, a… | works | works | the gear reading |
| 42072-1 | 4 | The pull-back motor's spring drives the car once it is wound and let go. | skipped | skipped |  |
| 42073-1 | 1 | The rear wheels turn together on the axle through the pull-back motor: pulled back along … | works | no | p117 54087 is part of the frame (#118 54087, keyed in its axle hole, #62 3708; #62 3708, keyed in its axle ho…; still: p61 3708, p117 54087, p120 54087 |
| 42073-1 | 2 | The front wheels roll freely on their axle. | works | works | the gear reading |
| 42073-1 | 3 | When the car runs into a wall, the red lever sticking out low at the front is knocked bac… | works | works | the gear reading |
| 42073-1 | 4 | The pull-back motor's spring drives the car once it is wound and let go. | skipped | skipped |  |
| 42074-1 | 1 | The helm, a small steering wheel on the deck, turns the rudder at the stern: its 16 tooth… | partly | partly | the gear reading; still: p90 6589, p93 42074 - 32198, p95 32316; moved: p34 32316 |
| 42074-1 | 2 | Either of the two winch cranks on the deck swings the boom and mainsail from side to side… | no | partly | the gear reading; still: p123 61510, p124 10928, p150 3648b |
| 42074-1 | 3 | The yacht stands on four small wheels under its hull, which roll freely so it can be push… | works | works | the gear reading; a drag on its joint |
| 42074-1 | 4 | The rubber bands slip if the boom is held, so the winches can't jam it. | skipped | skipped |  |
| 42075-1 | 1 | The black gear on the cab roof steers the front wheels: its upright shaft turns a long sh… | works | works | a drag's loop |
| 42075-1 | 2 | Pushed along, the rear wheels drive the two cylinder engine under the bonnet: a different… | partly | partly | the gear reading; still: p116 62821, p349 2853, p352 2851 |
| 42075-1 | 3 | The front wheels roll freely; only the rear ones are driven. | works | works | the gear reading |
| 42075-1 | 4 | The gear on the front bumper winds the winch, reeling the hook's string in or out. | works | works | the gear reading |
| 42075-1 | 5 | The rear axle is a swinging, sprung unit: it pivots at its front end and a single shock a… | partly | partly | a drag's loop; still: p163 4254 |
| 42075-1 | 6 | The light mast, lying along the roof, swings up at the back of the truck to stand upright… | works | works | the gear reading |
| 42075-1 | 7 | The bonnet, with the grille and headlights, tips up and forward to show the engine. | no | works | the gear reading and 1 loop it turns |
| 42075-1 | 8 | The two seats tip forward. | works | works | the gear reading |
| 42076-1 | 1 | Pushed along, the hovercraft's hidden wheels underneath spin both propellers at the stern… | works | partly | the gear reading and 1 loop it turns; still: p615 15790, p647 15790 |
| 42076-1 | 2 | The black gear on top at the stern steers: it swings both propeller pods together, and th… | partly | partly | the gear reading; still: p596 87080, p628 87080, p194 42610 |
| 42076-1 | 3 | Either gear on a yellow upright shaft on the deck beside the bow lowers and raises the ra… | partly | no | the gear reading; p348 32270: locked: the couplings ask for two different turns at once p363 32270: locked: the couplings ask f…; still: p544 64782, p568 92696, p577 92696 |
| 42076-1 | 4 | The black gear on the carriage at the top of the red gantry raises and lowers the white b… | no | partly | a drag's loop; still: p726 60485 |
| 42076-1 | 5 | The bridge, on its carriage, slides from side to side along the gantry's black top beam. | no | no | p676 14720 is part of the frame; still: p697 64781, p726 60485 |
| 42076-1 | 6 | The truck: the black gear on its cab roof steers its front wheels. | no | partly | the gear reading; still: p982 55982, p989 55982 |
| 42076-1 | 7 | The truck's rear axle swings up and down, sprung by a shock absorber. | partly | partly | the gear reading; still: p883 73129 |
| 42076-1 | 8 | The truck's four wheels roll; it can drive up the ramp onto the deck. | works | works | the gear reading |
| 42076-1 | 9 | The rotors in the two red fans on deck spin freely. | works | no | the gear reading; p661 46667: locked: the couplings ask for two different turns at once p675 46667: locked: the couplings ask f… |
| 42077-1 | 1 | The black gear on the roof steers the front wheels: its upright shaft and a pair of bevel… | works | partly | the gear reading; still: p561 87761, p1077 15038, p1081 15038 |
| 42077-1 | 2 | Pushed along, the rear wheels drive the V6 engine behind the seats: the rear differential… | partly | partly | the gear reading; still: p59 62821, p139 2853, p142 2851 |
| 42077-1 | 3 | The front wheels roll freely; only the rear ones are driven. | works | works | the gear reading |
| 42077-1 | 4 | All four wheels have independent suspension: each hub rides on a pair of arms with a stif… | works | works | the gear reading |
| 42077-1 | 5 | The bonnet lifts up at its back edge, hinged at the front. | partly | no | the gear reading; p813 18944: locked: the couplings ask for two different turns at once; still: p808 18944 |
| 42077-1 | 6 | The two doors swing open. | no | works | the gear reading |
| 42077-1 | 7 | The rear of the body, with the rear roof, rear wings and spoiler, tilts up from the back … | partly | works | a drag's loop |
| 42078-1 | 1 | The gear on top at the back of the cab roof steers the front wheels: a shaft runs down th… | no | partly | the gear reading; still: p537 3648b, p502 56145, p512 56145 |
| 42078-1 | 2 | Pushed along, the tractor's two rear axles drive the six cylinder engine under the bonnet… | partly | partly | the gear reading; still: p324 3708, p405 4519, p414 4519 |
| 42078-1 | 3 | The front wheels roll freely; they aren't driven. | works | works | the gear reading |
| 42078-1 | 4 | The bonnet, with the grille, headlights and front wings, tips forward to show the engine. | works | partly | the gear reading; still: p1423 40490 |
| 42078-1 | 5 | The cab doors swing open. | no | works | the gear reading |
| 42078-1 | 6 | The fifth wheel at the back of the tractor slides forward and back. | no | no | the gear reading; p17 32278: locked: the couplings ask for two different turns at once |
| 42078-1 | 7 | The trailer swings on its king pin behind the tractor. | partly | no | p1634 32278 is part of the frame (#1637 32278, two joints on two lines, #1635 43093; #1635 43093, keyed in it…; still: p1890 56145 |
| 42078-1 | 8 | The black gear low on the side of the trailer's front winds the landing gear's two legs, … | partly | works | a drag's loop |
| 42078-1 | 9 | One of the two black gears at the trailer's rear works both cranes' large linear actuator… | no | partly | a drag's loop; still: p1960 62274c01, p2188 62274c01, p2048 18940 |
| 42078-1 | 10 | The other black gear at the trailer's rear works both cranes' small linear actuators toge… | no | partly | the gear reading; still: p1640 94925, p1980 92696, p2144 92696 |
| 42078-1 | 11 | Each crane leg is a rack in a housing that telescopes, so the leg can reach the ground as… | no | works | the gear reading |
| 42078-1 | 12 | The container's two end doors swing open. | no | no | p2631 64782 is part of the frame (#2626 64782, two joints on two lines, #2629 32524; #2629 32524, two joints … |
| 42078-1 | 13 | The trailer's four wheels roll freely. | works | works | the gear reading |
| 42079-1 | 1 | Turning the orange beacon on the cab roof raises and lowers the forks: its upright shaft … | partly | partly | the gear reading; still: p471 18942, p524 32524, p531 32524 |
| 42079-1 | 2 | The lever on the side of the body tilts the mast forward and back. | works | works | a drag's loop |
| 42079-1 | 3 | The grey exhaust stack on top at the back steers the rear wheels. | works | partly | the gear reading; still: p454 86652, p456 86652 |
| 42079-1 | 4 | Pushed along, the front wheels drive the two cylinder engine through a differential: a sh… | works | partly | the gear reading and 1 loop it turns |
| 42079-1 | 5 | The rear wheels roll freely; they aren't driven. | partly | works | the gear reading |
| 42079-1 | 6 | The two front wheel arches, with the mirrors, swing out. | no | works | the gear reading |
| 42080-1 | 1 | The Power Functions L motor on the rear unit, run from the battery box behind it, works t… | works | no | p820 44294 is part of the frame (#831 44294, keyed in its axle hole, #827 42003; #827 42003, two joints on tw…; still: p821 6632, p653 42080 - 26674-f1 |
| 42080-1 | 2 | The black gear on the right of the cab turns a pneumatic valve that sends air to the two … | no | partly | the gear reading; still: p1946 19466c01, p1949 19466c01, p1317 3703 |
| 42080-1 | 3 | The black gear on the left of the cab turns the second pneumatic valve, which works the s… | no | partly | the gear reading; still: p1421 2947b, p1522 42080 - 27266, p1529 42080 - 27266 |
| 42080-1 | 4 | The cab and boom slew round on a turntable on the front unit, about 270 degrees. | works | no | the gear reading; p282 18938: locked: the couplings ask for two different turns at once; still: p385 42080 - 19474-f1 |
| 42080-1 | 5 | The black gear on top of the rear unit, just behind the cab, steers the machine: through … | partly | partly | the gear reading; still: p586 18938, p1073 56145, p1081 56145 |
| 42080-1 | 6 | The black gear on the boom's tip turns the harvester head round on its 28 tooth turntable. | no | partly | the gear reading; still: p1485 99010, p1509 61403 |
| 42080-1 | 7 | The circular saw blade under the harvester head spins freely. | works | works | the gear reading |
| 42080-1 | 8 | All eight wheels roll freely; none is driven. | works | works | the gear reading |
| 42081-1 | 1 | The knob on top, between the lift arm and the rear body, steers all four wheels: a shaft … | no | partly | a drag's loop; still: p35 64781, p27 42081 - 23801, p31 42081 - 23801 |
| 42081-1 | 2 | Either of the middle pair of knobs low on the chassis sides, just behind the front wheels… | partly | partly | a drag on its joint; still: p464 32271, p442 62274c01, p1136 15265 |
| 42081-1 | 3 | Either of the upper pair of knobs, high on the sides by the arm's pivot, tilts the bucket… | partly | partly | the gear reading; still: p1136 15265, p506 62274c01; moved: p464 32271 |
| 42081-1 | 4 | Either of the lowest pair of knobs, under the chassis sides just behind the front wheels,… | partly | partly | the gear reading; still: p315 64179 |
| 42081-1 | 5 | The knob at the very back slides the whole rear body (the battery pack with the drone pad… | partly | no | p943 32270 is part of the frame (#944 32270, keyed in its axle hole, #942 87083); still: p621 18940 |
| 42081-1 | 6 | The four wheels roll freely; there's no drive to them. | works | works | the gear reading |
| 42081-1 | 7 | The drone's four three-bladed propellers spin, and the drone lifts off its pad on top of … | works | works | the gear reading |
| 42081-1 | 8 | The two seven-bladed fans set into the top of the rear body spin. | works | works | the gear reading |
| 42081-1 | 9 | The work light on its flexible arm above the rear body can be posed on its ball joints. | skipped | skipped |  |
| 42082-1 | 1 | The small handwheel at the very back of the chassis steers all four wheels: a shaft along… | no | no | the gear reading and 1 loop it turns; still: p743 87761, p569 87761, p679 92908 |
| 42082-1 | 2 | Pushing the crane along runs the V8 engine at the back of the chassis: the axles' differe… | works | partly | a drag on its joint; still: p1223 2854, p1235 2851, p1236 2851 |
| 42082-1 | 3 | Each axle has a differential: with the engine held, turning one wheel turns the other whe… | partly | partly | a drag on its joint; still: p2284 92912 |
| 42082-1 | 4 | The motor lowers and raises the four outriggers: with the red lever on the superstructure… | partly | partly | the gear reading; p3557 16646, worked first, went -0.09 of -0.6; still: p827 32140, p858 32140, p992 32140 |
| 42082-1 | 5 | The motor slews the superstructure round, all the way round: with the red lever on the su… | works | partly | the gear reading; p3557 16646, worked first, went -0.09 of -0.6; still: p2649 64179, p2941 41239 |
| 42082-1 | 6 | The motor raises and lowers the boom: with the red lever on the superstructure set to the… | partly | partly | the gear reading; p3557 16646, worked first, went 0.09 of 0.6 p2738 11214, worked first, went 0.09 of 0.3; still: p2941 41239, p2383 62274c01, p2386 62274c01 |
| 42082-1 | 7 | The motor extends and retracts the boom: with the red lever on the boom side and the gate… | partly | partly | the gear reading; p3557 16646, worked first, went 0.09 of 0.6 p2738 11214, worked first, went 0.09 of 0.3; still: p3076 3703, p3268 32270 |
| 42082-1 | 8 | The motor winds the winch, raising or lowering the hook: with the red lever on the boom s… | partly | partly | the gear reading; p3557 16646, worked first, went 0.09 of 0.6 p2738 11214, worked first, went 0.09 of 0.3; still: p2870 3737, p3371 2736 |
| 42082-1 | 9 | The cab door on the superstructure swings open on its hinge. | partly | partly | a drag's loop |
| 42082-1 | 10 | The hook carries the load: a grey wall frame hangs from the hook on four chains, and two … | not checked | not checked |  |
| 42083-1 | 1 | The steering wheel steers the front wheels: its column runs forward along the cockpit's l… | works | partly | the gear reading; still: p1039 42083 - 23801, p1046 42083 - 23801, p1119 64781 |
| 42083-1 | 2 | The two paddle shifters behind the steering wheel shift the 8-speed sequential gearbox on… | partly | partly | the gear reading; still: p1345 24505, p406 42083 - 35188, p410 42083 - 35188 |
| 42083-1 | 3 | Two rubber bands in the paddle mechanism bring the rocker and its pawls back after each s… | skipped | skipped |  |
| 42083-1 | 4 | Rolling the car runs the W16 engine: all four wheels are driven, each axle through its ow… | partly | partly | the gear reading; p3522 42083 - 37383p01 is part of the frame p3525 42083 - 37383p01 is part of the frame; still: p597 2854, p609 2851, p671 2854 |
| 42083-1 | 5 | Each axle's differential lets its two wheels turn at different speeds, as in a corner. | works | partly | the gear reading; p3522 42083 - 37383p01 is part of the frame |
| 42083-1 | 6 | The speed key raises and lowers the rear wing: its long axle goes into a hole behind the … | works | works | the gear reading |
| 42083-1 | 7 | The two doors swing open on hinges at their front edges. | works | partly | the gear reading; p2924 62531 is part of the frame |
| 42083-1 | 8 | Each front wheel has independent suspension: its steering knuckle rides between a lower a… | no | no | the gear reading; p1051 15459: locked: the couplings ask for two different turns at once p1044 15459: locked: the couplings ask…; still: p1046 42083 - 23801 |
| 42083-1 | 9 | Each rear wheel has independent suspension in the same way: its upright rides between two… | partly | no | the gear reading; p137 32316: locked: the couplings ask for two different turns at once p187 32316: locked: the couplings ask f…; still: p3525 42083 - 37383p01 |
| 42083-1 | 10 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 42083-1 | 11 | The Bugatti overnight bag sits in the storage space at the front, behind the grille. | not checked | not checked |  |
| 42084-1 | 1 | The gear on top of the cab, behind the roof, steers the front wheels: its upright axle ru… | no | partly | a drag's loop |
| 42084-1 | 2 | The gear low on the side of the bed, behind the cab, swings the hook arm back over the re… | works | no | p102 32270: Simulate has no joint it turns on (floating); still: p81 32014, p96 10928, p99 10928 |
| 42084-1 | 3 | The four wheels roll freely; there's no drive. | works | works | the gear reading |
| 42084-1 | 4 | The container comes off: it rests on the bed held only by the hook through the loop at it… | not checked | not checked |  |
| 42088-1 | 1 | The 12 tooth gear on the end of the long axle at the back of the boom's mount raises and … | partly | works | the gear reading |
| 42088-1 | 2 | The boom's mount turns round on a single upright pin on the chassis, swinging the boom an… | works | no | p111 32138 is part of the frame (#112 32138, a pin in the first thing it is in, #114 32291; #114 32291, keyed…; still: p124 11478, p139 32270, p140 32249 |
| 42088-1 | 3 | The bucket turns round on the upright pins it hangs from at the boom's tip. | works | works | the gear reading |
| 42088-1 | 4 | The bucket's hanger swings on a pin across the boom's tip, so the bucket hangs upright wh… | skipped | skipped |  |
| 42088-1 | 5 | The four wheels roll freely; there's no steering. | works | works | the gear reading |
| 42092-1 | 1 | The 12 tooth gear under the belly spins the main rotor on its upright shaft, and a 20 too… | partly | partly | the gear reading; still: p314 62743, p225 3708, p275 6589 |
| 42092-1 | 2 | The tan gear beside the winch drum, high on the left side behind the cockpit, winds the w… | works | partly | a drag on its joint; still: p309 61510 |
| 42092-1 | 3 | The 12 tooth gear high on the right side turns the winch too: it is on a cross axle whose… | works | partly | the gear reading; still: p309 61510 |
| 42092-1 | 4 | The winch's arm swings out from the side on a pin, carrying the pulley the string runs ov… | partly | no | the gear reading; p302 74695: locked: the couplings ask for two different turns at once; still: p307 74695 |
| 42092-1 | 5 | The two rear doors swing open sideways. | works | works | the gear reading |
| 42092-1 | 6 | The stretcher hangs level from the hook on its string. | skipped | skipped |  |
| 42093-1 | 1 | Pushed along, the rear wheels drive the V8 through a differential: a 20 tooth gear on the… | partly | partly | the gear reading; still: p114 55013, p320 24316, p323 24316 |
| 42093-1 | 2 | The black 12 tooth gear at the back, just above the exhausts, steers the front wheels: it… | partly | partly | the gear reading; still: p80 24316, p128 60485, p194 22961 |
| 42093-1 | 3 | The front wheels roll freely and turn with the steering. | works | works | the gear reading |
| 42093-1 | 4 | The steering wheel in the cockpit turns on its pin; it isn't linked to the steering. | works | works | the gear reading |
| 42094-1 | 1 | The rear one of the two black gear knobs on top of the engine cover raises and lowers the… | works | partly | the gear reading and 1 loop it turns; still: p30 55013 |
| 42094-1 | 2 | The front one of the two knobs on top turns the cab right round on its turntable: a 12 to… | partly | partly | the gear reading; still: p42 18938, p926 26603 |
| 42094-1 | 3 | The black gear knob on the left side at the back winds the winch drum in the rear, reelin… | partly | partly | the gear reading; still: p104 32012, p113 32073 |
| 42094-1 | 4 | The red lever on top at the back shifts a driving ring between two gears on the winch kno… | works | partly | the gear reading; still: p133 18947 |
| 42094-1 | 5 | The grab on the end of the arm closes on the log: the black gear on its side turns the up… | no | works | the gear reading |
| 42094-1 | 6 | The armrest consoles beside the seat, carrying the control levers, tip up on hinges at th… | partly | partly | the gear reading; still: p979 11947, p948 11946 |
| 42094-1 | 7 | The two tracks roll freely round their sprockets as the loader is pushed along. | works | works | the gear reading |
| 42094-1 | 8 | Each track's raised front idler sits on a sprung arm, held out by a small shock absorber. | skipped | skipped |  |
| 42095-1 | 1 | The left track: a Power Functions L motor, worked by one lever on the remote through the … | works | partly | the gear reading; still: p306 57519 |
| 42095-1 | 2 | The right track: the other L motor, worked by the remote's other lever, drives the right … | works | partly | the gear reading; still: p287 57519 |
| 42095-1 | 3 | Steering is by the two tracks: both levers the same way drive the racer forward or back, … | not checked | not checked |  |
| 42095-1 | 4 | The blue top hinges forward on pins at its front to reach the battery box: unplug the two… | partly | no | p250 32524 is part of the frame (#251 32524, two joints on two lines, #252 32140; #252 32140, keyed in its ax…; still: p541 98138p0e |
| 42095-1 | 5 | The two small yellow wheels on the tail, behind and above the tracks, roll freely, so the… | works | works | the gear reading |
| 42096-1 | 1 | Pushed along, the rear wheels drive the flat six through a differential: half shafts with… | partly | partly | the gear reading; still: p6 62821, p47 32494, p404 32270 |
| 42096-1 | 2 | The steering wheel steers the front wheels: its column runs forward through two universal… | works | partly | a drag's loop; still: p264 18575, p192 32270, p182 87761 |
| 42096-1 | 3 | The two doors swing open on hinges at their front edges. | works | works | the gear reading |
| 42096-1 | 4 | The front wheels each have independent suspension: the hub rides between a lower and an u… | works | no | a drag's loop |
| 42096-1 | 5 | The rear wheels have independent suspension too, on pairs of arms with a shock absorber e… | works | no | the gear reading; p22 32063: locked: the couplings ask for two different turns at once p26 32063: locked: the couplings ask for… |
| 42099-1 | 1 | The front XL motor drives the front wheels: the 20 tooth gear on its shaft drives a 12 to… | partly | partly | the gear reading; still: p510 42099 - 18575, p465 32270, p486 62821 |
| 42099-1 | 2 | The rear XL motor drives the rear wheels the same way: the 20 tooth gear on its shaft dri… | no | no | p359 42099 - 18575 is part of the frame (#369 42099 - 18575, keyed in its axle hole, #368 4519; #368 4519, ke…; still: p83 32270, p59 42099 - 18575, p20 32270 |
| 42099-1 | 3 | With both XL motors driven together the off-roader has four-wheel drive, forwards or back. | partly | partly | the gear reading; p359 42099 - 18575 is part of the frame (#369 42099 - 18575, keyed in its axle hole, #368 4519; #368 4519, ke…; still: p1854 23798, p1858 23798, p1856 23798 |
| 42099-1 | 4 | The L motor steers the front wheels: a 12 tooth gear on its shaft drives a toothed rack a… | works | partly | a drag's loop; still: p559 42099 - 46490c01, p569 42099 - 46490c01 |
| 42099-1 | 5 | The front axle has an open differential: with the front motor still, turning one front wh… | no | no | p1858 23798: Simulate has no joint it turns on (floating); still: p1854 23798, p486 62821 |
| 42099-1 | 6 | The rear axle has an open differential too: with the rear motor still, turning one rear w… | partly | no | p1860 23798: Simulate has no joint it turns on (floating); still: p1856 23798, p43 62821 |
| 42099-1 | 7 | The front half of the chassis (front axle, both front motors) twists against the rear hal… | not checked | not checked |  |
| 42099-1 | 8 | Four red shock absorbers, two on each axle, spring the axles against the chassis. | skipped | skipped |  |
| 42099-1 | 9 | The small steering wheel on the dashboard turns freely; it isn't joined to the steering. | works | works | the gear reading |
| 42100-1 | 1 | The XL motor on the right drives the right track: a 20 tooth gear by the motor drives, th… | partly | partly | the gear reading; still: p313 42100 - 42529, p110 42100 - 42529 |
| 42100-1 | 2 | The XL motor on the left drives the left track the same way. | partly | partly | the gear reading; still: p1099 42100 - 42529, p896 42100 - 42529 |
| 42100-1 | 3 | With both tracks driven the same way the excavator drives forwards or back; driven opposi… | partly | partly | the gear reading; still: p313 42100 - 42529, p1099 42100 - 42529 |
| 42100-1 | 4 | The L motor in the undercarriage slews the whole superstructure on the big turntable: a 1… | partly | partly | the gear reading; still: p1927 42003, p516 18938 |
| 42100-1 | 5 | The XL motor in the superstructure raises and lowers the boom: a 12 tooth gear on its axl… | partly | partly | the gear reading; still: p2971 42003, p1481 42100 - 62274c02, p1502 42100 - 62274c02 |
| 42100-1 | 6 | Two L motors on the boom swing the stick in and out together: each turns a 16 tooth gear … | partly | partly | a drag's loop; still: p3322 42003 |
| 42100-1 | 7 | An L motor on top of the boom tilts the bucket: a 12 tooth gear on its axle drives a 20 t… | no | partly | a drag's loop; still: p3600 15458, p3784 42100 - 62274c02, p3801 42100 - 62274c02 |
| 42100-1 | 8 | A shaft runs down the stick from bevel gears at the boom's tip to two small linear actuat… | no | partly | the gear reading; still: p3322 42003 |
| 42100-1 | 9 | The access ladder at the back left of the superstructure swings up out of the way and dow… | no | works | the gear reading |
| 42101-1 | 1 | The 12 tooth gear on top of the upright axle behind the seat steers the front wheels: tur… | no | partly | a drag's loop |
| 42101-1 | 2 | The rear wheels ride on a swinging arm: the arm pivots under the seat and carries the 9-l… | works | no | the gear reading; p22 32140: locked: the couplings ask for two different turns at once; still: p34 32140, p25 32316, p37 32316 |
| 42101-1 | 3 | The shock absorber's spring pushes the rear wheels back down. | skipped | skipped |  |
| 42101-1 | 4 | The four wheels roll freely; there's no drive and no engine. The two rear wheels turn tog… | works | works | the gear reading |
| 42101-1 | 5 | The steering wheel in front of the seat spins on its half pin; it isn't joined to the ste… | works | works | the gear reading |
| 42102-1 | 1 | The black 12 tooth gear on top of the cab steers the front wheels: its shaft runs down to… | works | partly | the gear reading; still: p0 48989, p5 48989, p121 55982 |
| 42102-1 | 2 | Pushing the tractor along spins the two rake wheels behind it: the tan 20 tooth bevel gea… | partly | partly | a drag's loop; moved: p103 32524 |
| 42102-1 | 3 | The rotary rake lifts up behind the tractor: the lime arm it hangs from swings up, and th… | no | partly | a drag's loop; moved: p125 55982, p127 55982 |
| 42102-1 | 4 | The four wheels roll freely: each front wheel on its own short axle in its steering knuck… | works | works | the gear reading; a drag's loop |
| 42105-1 | 1 | The black 12 tooth gear at the back of the deck, between the hulls, steers: turning it sw… | partly | partly | the gear reading; still: p60 40490, p293 99012, p316 99012 |
| 42105-1 | 2 | The handle on top of the right hull's tower raises and lowers its daggerboard: the handle… | partly | no | p186 42105 - 33299b: Simulate has no joint it turns on (floating); still: p184 27938, p155 42105 - 18575, p161 32278 |
| 42105-1 | 3 | The handle on top of the left hull's tower raises and lowers its daggerboard the same way… | partly | no | p261 42105 - 33299b: Simulate has no joint it turns on (floating); still: p259 27938, p230 42105 - 18575, p236 32278 |
| 42105-1 | 4 | The sails swing from side to side: a crank on the deck turns, and black link rods from it… | no | partly | a drag on its joint; still: p393 44294 |
| 42105-1 | 5 | The boat floats on its two hollow hull shells. | skipped | skipped |  |
| 42106-1 | 1 | The black 12 tooth gear on the truck's cab roof steers the front wheels: its upright shaf… | works | partly | the gear reading; still: p84 6589, p98 32270, p95 87761 |
| 42106-1 | 2 | The truck's four wheels roll freely; there's no drive. The two rear wheels turn together … | works | works | the gear reading |
| 42106-1 | 3 | The trailer hitches on a pin at the truck's back and swings behind it as the truck turns. | works | works | the gear reading |
| 42106-1 | 4 | The 12 tooth gear on the trailer's side swings the blue legs at its front down, so the un… | no | works | a drag's loop |
| 42106-1 | 5 | The trailer's two wheels roll freely together on one axle line. | works | works | the gear reading |
| 42106-1 | 6 | The bike's rear wheel winds its pull-back motor: a 16 tooth gear on the rear wheel's axle… | works | no | the gear reading; p2196 56145: locked: the couplings ask for two different turns at once; still: p2190 94925, p2193 18946, p2189 94925 |
| 42106-1 | 7 | The pull-back motor's spring drives the bike forward when it's pulled back and let go, fa… | skipped | skipped |  |
| 42106-1 | 8 | The bike's front wheel rolls freely on its axle in the fork. | works | works | the gear reading |
| 42106-1 | 9 | The bike stands on a removable stand on the trailer; it lifts off for its run. | not checked | not checked |  |
| 42106-1 | 10 | The truck's doors swing open on their pins. | works | no | p380 24119 is part of the frame (#381 24119, two joints on two lines, #378 32524) p402 24119 is part of the f… |
| 42107-1 | 1 | The grey gear lever on the gearbox's right side picks neutral, first or second gear: it t… | partly | works | the gear reading |
| 42107-1 | 2 | In first or second gear, turning the rear wheel runs the V4 engine: the chain from the re… | partly | no | p247 35189 is part of the frame; still: p288 23948, p289 94925, p185 2854 |
| 42107-1 | 3 | The rear wheel rides on the swing arm, which pivots on the gearbox's output shaft; the sh… | partly | no | a drag's loop; still: p247 35189, p284 76537 |
| 42107-1 | 4 | The rear shock absorber's spring pushes the rear wheel back down. | skipped | skipped |  |
| 42107-1 | 5 | The handlebars steer: they turn the front fork with the front wheel on the steering head. | no | works | the gear reading |
| 42107-1 | 6 | The front fork's two gold legs are shock absorbers: they shorten so the front wheel can r… | no | no | p408 32039 is part of the frame (#411 32039, keyed in its axle hole, #412 44294; #412 44294, keyed in its axl…; still: p372 44294, p379 88516 |
| 42107-1 | 7 | The front wheel rolls freely on its axle between the fork legs. | works | works | a drag on its joint |
| 42107-1 | 8 | The red paddock stand lifts the rear: pushing its handle down rocks it on its small wheel… | no | no | p27 25214 is part of the frame (#28 25214, keyed in its axle hole, #24 4519; #24 4519, keyed in its axle hole…; still: p36 32524, p247 35189 |
| 42107-1 | 9 | The side fairings come off to show the engine and gearbox. | not checked | not checked |  |
| 42108-1 | 1 | Either of the two orange knobs on top of the chassis behind the cab steers: their shafts … | works | partly | the gear reading; still: p3 44294, p105 48989, p111 48989 |
| 42108-1 | 2 | The eight wheels roll freely; there's no drive. | works | works | the gear reading |
| 42108-1 | 3 | Each of the four outriggers swings out and down onto its foot: turning its black 12 tooth… | partly | partly | a drag on its joint; the gear reading; still: p355 32062, p248 32062, p256 32062 |
| 42108-1 | 4 | The superstructure slews all the way round on its turntable, carrying the cab, boom and h… | partly | works | the gear reading |
| 42108-1 | 5 | The black knob nearer the cab on the superstructure's left side raises and lowers the boo… | no | partly | the gear reading; still: p808 11954 |
| 42108-1 | 6 | The black knob at the back of the superstructure's left side winds the winch, raising or … | partly | partly | the gear reading; still: p1045 30395 |
| 42108-1 | 7 | The black knob on the superstructure's right side extends the boom: it turns a red 16 too… | partly | partly | the gear reading; still: p923 23948, p1017 42108 - 35185, p957 2730 |
| 42108-1 | 8 | A red lever with a white ball on each side of the superstructure locks a drive: one locks… | skipped | skipped |  |
| 42109-1 | 1 | The XL motor drives the rear wheels: a 36 tooth gear on its shaft drives the differential… | partly | no | p16 42109 - 65414c01 is not where Kinebrick reads it p40 22172 is part of the frame (#47 22172, two joints on…; still: p351 32498, p16 42109 - 65414c01, p969 56145 |
| 42109-1 | 2 | With the XL motor still, turning one rear wheel turns the other the opposite way through … | no | partly | the gear reading; still: p27 3707, p969 56145 |
| 42109-1 | 3 | The L motor at the front steers: a 12 tooth gear on its shaft slides the steering rack, w… | partly | no | p390 22169 is part of the frame (#397 22169, two joints on two lines, #393 32526; #393 32526, two joints on t…; still: p692 32270, p686 87761, p670 48989 |
| 42109-1 | 4 | The front wheels roll freely, each on its own axle in its steering knuckle. | partly | works | the gear reading |
| 42109-1 | 5 | The Control+ hub runs both motors from the app, with drive and steering controls, gyro st… | not checked | not checked |  |
| 42110-1 | 1 | The gear knob on the roof (hand of God) steers the front wheels: a vertical shaft down th… | works | partly | the gear reading; still: p171 87761, p81 42110 - 23801, p86 42110 - 23801 |
| 42110-1 | 2 | The steering wheel turns with the steering, through universal joints from the steering ge… | works | partly | the gear reading; still: p849 2741 |
| 42110-1 | 3 | All four wheels are driven: pushing the car along turns the wheels, which through the fro… | partly | no | p2606 42110 - 49294 is part of the frame (#2610 42110 - 49294, a pin in the first thing it is in, #90 42110 -…; still: p242 3708, p211 4519, p223 4519 |
| 42110-1 | 4 | Open differentials in the front and rear axles and a centre differential between them let… | works | no | p2606 42110 - 49294 is part of the frame (#2610 42110 - 49294, a pin in the first thing it is in, #90 42110 -…; still: p2613 42110 - 49294, p38 62821 |
| 42110-1 | 5 | The four-speed sequential gearbox at the back: tipping the + / - lever between the front … | partly | no | the gear reading; p385 3706: locked: the couplings ask for two different turns at once; still: p723 32072, p715 32072, p578 42110 - 35188 |
| 42110-1 | 6 | The D-N-R lever in the console slides a driving ring in the gearbox in front of the conso… | works | partly | the gear reading; still: p330 18947 |
| 42110-1 | 7 | The HI-LO lever beside it slides the other driving ring in the same gearbox, choosing the… | works | partly | the gear reading; still: p331 18947 |
| 42110-1 | 8 | The winch in the front bumper: the hook pulls the string out, and turning the 12 tooth kn… | works | no | p896 32270 is part of the frame (#898 32270, held, #1 40490); still: p958 32012 |
| 42110-1 | 9 | Four independent suspension arms with shock absorbers let each wheel move up and down on … | skipped | skipped |  |
| 42110-1 | 10 | The two front doors open on their hinges. | no | works | a drag's loop |
| 42110-1 | 11 | The bonnet lifts, hinged at its back edge, showing the engine. | works | works | the gear reading |
| 42110-1 | 12 | Turning the spare wheel on the tailgate works the tailgate's latch, and the tailgate then… | works | no | p2614 42110 - 49294 is part of the frame (#2618 42110 - 49294, keyed in its axle hole, #1515 55013; #1515 550…; still: p1504 32065 |
| 42110-1 | 13 | The lid of the box on the roof rack lifts open. | no | works | the gear reading |
| 42110-1 | 14 | The lid of the case on the right side of the roof swings open. | no | works | the gear reading |
| 42110-1 | 15 | The roof, with its rack, lifts off. | skipped | skipped |  |
| 42111-1 | 1 | The black gear on the rear shelf behind the roof steers the front wheels (hand of God ste… | works | partly | the gear reading; still: p199 99008, p288 87761, p297 15460 |
| 42111-1 | 2 | Rolling the car turns the V8 engine: the rear wheels drive the differential, whose ring g… | works | partly | the gear reading; still: p8 62821, p56 59426, p210 94925 |
| 42111-1 | 3 | The rear differential lets the rear wheels turn at different speeds in a bend. | works | partly | the gear reading; still: p473 56908 |
| 42111-1 | 4 | The front wheels have independent suspension: each rides on a pair of suspension arms, sp… | partly | no | the gear reading; p276 15459: locked: the couplings ask for two different turns at once p279 15459: locked: the couplings ask f…; still: p297 15460, p318 15461 |
| 42111-1 | 5 | The front shock absorbers' springs push the front wheels back down. | skipped | skipped |  |
| 42111-1 | 6 | The rear axle is sprung: the whole rear axle with its differential swings on a ball joint… | no | works | the gear reading |
| 42111-1 | 7 | The rear shock absorbers' springs push the rear axle back down. | skipped | skipped |  |
| 42111-1 | 8 | The bonnet opens: it lifts on hinges at the windscreen end to show the engine and superch… | works | partly | the gear reading; still: p725 32054 |
| 42111-1 | 9 | The boot lid opens on its hinges at the back of the car. | works | no | p959 64782 is part of the frame; still: p964 26287, p978 32524, p979 32524 |
| 42111-1 | 10 | The red lever between the seats works the wheelie bar: pushing it swings a bar down under… | no | works | a drag's loop |
| 42112-1 | 1 | The black 12 tooth gear on top of the cab steers the front two axles (hand of God steerin… | works | partly | the gear reading; still: p61 48989, p65 48989, p69 48989 |
| 42112-1 | 2 | The eight wheels roll. The four rear wheels drive through a differential on each rear axl… | works | works | the gear reading |
| 42112-1 | 3 | Rolling the truck turns the small engine under the cab: the rear differentials drive a sh… | partly | partly | the gear reading; still: p249 62821, p245 18575, p17 60485 |
| 42112-1 | 4 | The white selector lever under the chassis picks how the drum is turned: in one position … | partly | no | the gear reading; p374 32523: locked: the couplings ask for two different turns at once; still: p354 18947 |
| 42112-1 | 5 | With the selector set for driving, rolling the truck turns the drum to mix: the drive sha… | partly | partly | the gear reading; still: p231 94925, p356 42112 - 35185, p361 32270 |
| 42112-1 | 6 | With the selector set for the crank, the crank on the side of the chassis turns the drum … | partly | partly | the gear reading; still: p361 32270, p1128 42112 - 65421p01 |
| 42112-1 | 7 | The drum's back end rides on four small wheels on a rocking frame. | works | works | a drag's loop |
| 42112-1 | 8 | The chute at the back swings down from its stowed position for pouring. | works | no | the gear reading; still: p559 57585 |
| 42113-1 | 1 | The motor in the fuselage, run from the hub, drives whichever function is selected by fou… | works | no | p769 22169 is part of the frame (#777 22169, keyed in its axle hole, #876 32062; #876 32062, keyed in its axl… |
| 42113-1 | 2 | With the rotor button pushed in, the motor spins both three-bladed rotors together, in op… | partly | no | p769 22169 is part of the frame (#777 22169, keyed in its axle hole, #876 32062; #876 32062, keyed in its axl…; still: p1739 57585, p1773 57585 |
| 42113-1 | 3 | With the nacelle button pushed in, the motor tilts both engine nacelles together between … | partly | no | p769 22169 is part of the frame (#777 22169, keyed in its axle hole, #876 32062; #876 32062, keyed in its axl…; still: p1345 99010, p1479 99010, p1739 57585 |
| 42113-1 | 4 | With the landing gear button pushed in, the motor retracts and lowers the three landing g… | partly | no | p769 22169 is part of the frame (#777 22169, keyed in its axle hole, #876 32062; #876 32062, keyed in its axl…; still: p882 92693c01, p105 42610, p130 42610 |
| 42113-1 | 5 | With the ramp button pushed in, the motor opens and closes the rear cargo ramp: a linear … | partly | no | p769 22169 is part of the frame (#777 22169, keyed in its axle hole, #876 32062; #876 32062, keyed in its axl…; still: p974 92693c01, p223 64782, p244 32524 |
| 42113-1 | 6 | The wheels on the three landing gear legs roll freely. | works | works | the gear reading |
| 42113-1 | 7 | The rotor blades are hinged at their roots and can be folded by hand. | no | partly | the gear reading and 1 loop it turns |
| 42113-1 | 8 | The flaps on the wings' trailing edges move with the nacelles. | works | partly | a drag's loop |
| 42114-1 | 1 | The XL motor in the rear frame, just behind the articulation, drives all six wheels throu… | partly | no | the gear reading; p602 22169, worked first, went 0.0 of 1.5 p427 22172: locked: the couplings ask for two different turns at on…; still: p275 6573, p84 65414c01, p318 65414c01 |
| 42114-1 | 2 | The L motor beside the XL motor shifts the gearbox: it turns a changeover rotary catch, w… | partly | no | the gear reading; p602 22169: locked: the couplings ask for two different turns at once; still: p129 35188, p120 18947, p121 18947 |
| 42114-1 | 3 | With the gearbox in its tipping position, the XL motor raises and lowers the dump body: a… | partly | no | the gear reading; p602 22169, worked first, went 0.0 of 1.5 p427 22172: locked: the couplings ask for two different turns at on…; still: p779 32198, p808 4519, p839 4519 |
| 42114-1 | 4 | The large angular motor at the front steers by bending the truck at its articulation: its… | no | no | p1031 42114 - 69730 is not where Kinebrick reads it; still: p2038 32140, p2043 32140, p994 99010 |
| 42114-1 | 5 | The rear half can roll against the front half on a turntable lying on its side in the hit… | works | works | the gear reading |
| 42114-1 | 6 | The orange beacon on the cab roof switches the hub on and off: turning it turns an uprigh… | works | no | p2535 3941 is part of the frame (#2537 3941, keyed in its axle hole, #2466 3706; #2466 3706, keyed in its axl…; still: p2471 41677 |
| 42114-1 | 7 | The black hood over the hub tilts forward once the long axle pin at the front bumper is p… | partly | no | a drag's loop; still: p2766 32525 |
| 42115-1 | 1 | Pushed along, all four wheels drive together through a differential on each axle, and in … | partly | partly | the gear reading; still: p38 62821, p797 62821, p681 2854 |
| 42115-1 | 2 | The paddle shifters behind the steering wheel change gear in the eight-speed sequential g… | partly | partly | the gear reading; still: p579 32072, p439 32072, p441 32072 |
| 42115-1 | 3 | The lever on the centre console between the seats switches the gearbox between drive and … | works | partly | the gear reading; still: p549 18947 |
| 42115-1 | 4 | The steering wheel steers the front wheels: its column turns through universal joints and… | works | partly | the gear reading; still: p1017 87761, p886 35189, p894 35189 |
| 42115-1 | 5 | All four wheels have independent pushrod suspension: each wheel's wishbones push a rocker… | works | works | the gear reading |
| 42115-1 | 6 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 42115-1 | 7 | The rear spoiler rises and tilts: a lever in the interior pushes a flexible axle, used as… | partly | partly | the gear reading; still: p2703 11946, p2708 11947 |
| 42115-1 | 8 | The two scissor doors swing up and forward on hinges at their front edges. | no | no | the gear reading; p3495 55615: locked: the couplings ask for two different turns at once p3589 55615: locked: the couplings ask…; still: p3498 64394, p3592 64680 |
| 42115-1 | 9 | The front hood lifts, showing the luggage space and the set's bag. | no | works | the gear reading |
| 42115-1 | 10 | The engine cover behind the cabin lifts to show the V12. | partly | no | the gear reading; p2809 32278: locked: the couplings ask for two different turns at once; still: p2806 32140 |
| 42115-1 | 11 | The seats' backs tilt. | no | works | the gear reading |
| 42116-1 | 1 | The black 12 tooth gear on top of the cage, at its back, raises and lowers the loader arm… | partly | partly | the gear reading; still: p139 18943 |
| 42116-1 | 2 | The black 12 tooth gear on the right side at the back tilts the bucket: its shaft carries… | works | partly | the gear reading; still: p73 41239 |
| 42116-1 | 3 | The four wheels roll freely; there's no steering and no drive to them. | works | works | the gear reading |
| 42116-1 | 4 | The worm holds the arm where it's left, so the arm doesn't drop under the bucket's weight. | skipped | skipped |  |
| 42120-1 | 1 | Pushing the hovercraft along spins the two big fans at the back: two hidden rubber-tyred … | partly | partly | the gear reading; still: p580 42120 - 92842, p581 42120 - 92842 |
| 42120-1 | 2 | Pushing it along also spins the beacon on the tall post in the middle of the deck, the tw… | partly | partly | the gear reading; still: p549 27940, p550 59900, p551 59900 |
| 42120-1 | 3 | The black knob on top of the cabin steers: turning it swings a crossbar underneath, whose… | partly | partly | the gear reading; still: p585 30031; moved: p51 4185a |
| 42120-1 | 4 | The two small front wheels under the bow roll freely. | works | works | the gear reading |
| 42120-1 | 5 | The small fan on the front deck spins freely on its pin. | works | no | the gear reading; p583 46667: locked: the couplings ask for two different turns at once |
| 42121-1 | 1 | The black gear knob at the back of the superstructure raises and lowers the boom: through… | partly | partly | the gear reading; still: p84 32271, p46 92696, p147 24120 |
| 42121-1 | 2 | The black gear knob on the side of the superstructure opposite the cab moves the stick in… | no | partly | the gear reading; still: p131 32525, p110 92693c01, p147 24120 |
| 42121-1 | 3 | The whole superstructure, with cab, boom and stick, slews all the way round on the turnta… | works | works | the gear reading |
| 42121-1 | 4 | The two tracks roll freely round their sprockets and rollers; nothing drives them. | works | works | the gear reading |
| 42121-1 | 5 | The bucket is fixed to the end of the stick; the grey cylinder on the stick is only for s… | not checked | not checked |  |
| 42122-1 | 1 | The 12 tooth gear on top at the back, between the roll bars, steers the front wheels: a l… | no | partly | the gear reading; still: p145 40490, p130 42122 - 65489, p131 42122 - 65489 |
| 42122-1 | 2 | The front axle swings side to side on a turntable under the chassis, so the front wheels … | no | works | a drag's loop |
| 42122-1 | 3 | The rear axle swings side to side on its own turntable under the back of the chassis (pen… | no | partly | a drag's loop; still: p193 4254, p200 4254 |
| 42122-1 | 4 | The two shock absorbers' springs push the rear axle back level. | skipped | skipped |  |
| 42122-1 | 5 | The 16 tooth gear on the front bumper winds the winch drum, reeling the string in or out … | works | partly | the gear reading; still: p235 61510 |
| 42122-1 | 6 | The bonnet lifts open, hinged at its back edge by the windscreen, showing the engine. | no | works | the gear reading |
| 42122-1 | 7 | The two doors swing open. | no | works | the gear reading |
| 42122-1 | 8 | The rear seat's backrest folds forward. | works | works | a drag on its joint |
| 42122-1 | 9 | The four wheels roll freely; there's no drivetrain. | works | works | a drag on its joint |
| 42123-1 | 1 | The 12 tooth gear on top of the roof steers the front wheels: its upright shaft drives a … | works | partly | the gear reading; still: p110 87761, p94 42123 - 65489, p97 42123 - 65489 |
| 42123-1 | 2 | Rolling the car turns the V8 engine behind the seats: the right rear wheel's axle turns t… | partly | no | the gear reading; p1109 42123 - 56145: locked: the couplings ask for two different turns at once; still: p162 55013, p253 32123b, p264 32123b |
| 42123-1 | 3 | The two doors swing up and forward on hinges at their front corners (dihedral doors). | no | works | the gear reading |
| 42123-1 | 4 | The front wheels and the left rear wheel roll freely. | works | works | a drag on its joint; the gear reading |
| 42124-1 | 1 | The front motor steers the front wheels: it turns a crank across the front of the chassis… | partly | no | the gear reading; p0 22169: locked: the couplings ask for two different turns at once; still: p318 32524, p343 15460, p345 15460 |
| 42124-1 | 2 | The rear motor drives the rear wheels: a 36 tooth gear on its shaft drives the differenti… | partly | no | the gear reading; p501 22169: locked: the couplings ask for two different turns at once; still: p889 32498, p464 65414c01, p972 56908 |
| 42124-1 | 3 | The differential lets one rear wheel turn while the other is held, or turn backwards agai… | partly | partly | the gear reading; still: p974 56908 |
| 42124-1 | 4 | Each front wheel moves up and down on its own pair of suspension arms (independent suspen… | no | no | the gear reading; p325 42124 - 31794: locked: the couplings ask for two different turns at once p326 42124 - 31794: locked: the…; still: p343 15460, p345 15460 |
| 42124-1 | 5 | The front shock absorbers' springs hold the front of the buggy up. | skipped | skipped |  |
| 42124-1 | 6 | The rear unit (motor, gears, differential and rear wheels) swings up and down on a pivot … | no | no | the gear reading; p470 40490: locked: the couplings ask for two different turns at once; still: p464 65414c01, p501 22169 |
| 42124-1 | 7 | The rear shock absorbers' springs hold the back of the buggy up. | skipped | skipped |  |
| 42124-1 | 8 | The front wheels roll freely. | works | no | p971 42124 - 69909: Simulate has no joint it turns on (floating) p977 42124 - 69909: Simulate has no joint it… |
| 42125-1 | 1 | The steering wheel steers the front wheels: its column runs forward through two universal… | partly | partly | a drag's loop; still: p441 87761, p339 42125 - 23801, p343 42125 - 23801 |
| 42125-1 | 2 | Rolling the car turns the V8 engine: the rear wheels drive the differential, which turns … | works | partly | a drag on its joint; still: p15 62821, p165 2853, p181 2851 |
| 42125-1 | 3 | The rear differential lets the rear wheels turn at different speeds in a corner: holding … | works | partly | a drag on its joint; still: p3145 44771 |
| 42125-1 | 4 | Each front wheel rides on its own pair of wishbones (independent suspension), sprung by a… | no | no | the gear reading; p318 57515: locked: the couplings ask for two different turns at once p326 57515: locked: the couplings ask f…; still: p339 42125 - 23801, p413 4254 |
| 42125-1 | 5 | The front shock absorbers' springs hold the front of the car up. | skipped | skipped |  |
| 42125-1 | 6 | The rear wheels ride on their own suspension arms with shock absorbers. | works | works | the gear reading |
| 42125-1 | 7 | The two doors swing up and forward on hinges at their front edges (butterfly doors). | works | no | the gear reading; p2982 64682: locked: the couplings ask for two different turns at once p3032 64392: locked: the couplings ask… |
| 42125-1 | 8 | The front wheels roll freely. | works | works | a drag on its joint |
| 42129-1 | 1 | The two L drive motors drive all four wheels: their 24 tooth gears both turn the centre d… | partly | partly | the gear reading; still: p2922 42129 - 69912 |
| 42129-1 | 2 | The centre differential lets the front and rear axles turn at different speeds while it's… | works | partly | the gear reading; still: p471 4519 |
| 42129-1 | 3 | The front and rear axle differentials let each axle's wheels turn at different speeds in … | no | no | p2922 42129 - 69912: Simulate has no joint it turns on (floating) p2924 42129 - 69912: Simulate has no joint …; still: p2928 42129 - 69912, p2926 42129 - 69912 |
| 42129-1 | 4 | The medium motor locks the differentials: through gears and two slip clutches it turns tw… | partly | no | the gear reading; p550 21980: locked: the couplings ask for two different turns at once; still: p517 35188, p1060 35188, p513 18947 |
| 42129-1 | 5 | The L motor on the front axle steers the front wheels: its 12 tooth gear slides the steer… | works | no | the gear reading; p1470 22169: locked: the couplings ask for two different turns at once; still: p1394 87761, p1342 46490c01, p1343 46490c01 |
| 42129-1 | 6 | Each axle is held under the chassis on swinging suspension arms and sways and rises over … | partly | partly | the gear reading; still: p1305 65414c01, p1030 65414c01, p1371 4254 |
| 42129-1 | 7 | The four shock absorbers' springs hold the truck up on its axles. | skipped | skipped |  |
| 42129-1 | 8 | The steering wheel in the cab turns freely; it isn't connected to the steering. | works | no | p1927 2819 is part of the frame (#1936 2819, keyed in its axle hole, #1935 32062) |
| 42131-1 | 1 | The angular motor at the back on the right drives the right track: its shaft turns, throu… | partly | partly | the gear reading; still: p3606 42529, p6159 42131 - 69910 |
| 42131-1 | 2 | The angular motor at the back on the left drives the left track the same way, through its… | partly | partly | the gear reading; still: p3609 42529, p6101 42131 - 69910 |
| 42131-1 | 3 | With both tracks driven the same way the bulldozer drives straight; driven at different s… | partly | partly | the gear reading; still: p3606 42529, p3609 42529 |
| 42131-1 | 4 | The V12 engine's pistons pump as the bulldozer drives: the two drive motors' inner shafts… | partly | partly | the gear reading; still: p5 62821, p3657 2853, p3665 2851 |
| 42131-1 | 5 | One of the two L motors in the gearbox only shifts it: it turns the selector, with its or… | partly | no | the gear reading; p3163 3706: locked: the couplings ask for two different turns at once; still: p3293 18947, p3322 18947 |
| 42131-1 | 6 | With the gearbox set to the ripper, the function L motor raises and lowers the ripper at … | partly | no | the gear reading; p3164 32073: locked: the couplings ask for two different turns at once; still: p3395 62274c01, p3404 62274c01, p5913 32524 |
| 42131-1 | 7 | With the gearbox set to blade lift, the function L motor raises and lowers the blade: a s… | partly | no | the gear reading; p3164 32073: locked: the couplings ask for two different turns at once; still: p4118 62274c01, p4193 62274c01, p6204 32525 |
| 42131-1 | 8 | With the gearbox set to blade tilt, the function L motor tilts the blade forward and back… | partly | no | the gear reading; p3164 32073: locked: the couplings ask for two different turns at once; still: p6006 62274c01, p6074 62274c01, p6204 32525 |
| 42131-1 | 9 | With the gearbox set to the ladder, the function L motor lowers and raises the boarding l… | partly | no | the gear reading; p3164 32073: locked: the couplings ask for two different turns at once; still: p5713 42131 - 71710, p5742 6536 |
| 42131-1 | 10 | The red lever in the engine compartment switches the Control+ hub on: pressing it pushes … | works | works | a drag's loop |
| 42131-1 | 11 | The two drive motors and two gearbox motors are worked from the LEGO Technic Control+ app… | not checked | not checked |  |
| 42131-1 | 12 | A worm on each track frame, turned by a gear on the side, slides the front idler to tensi… | skipped | skipped |  |
| 42131-1 | 13 | The roller bogies under each track frame rock to follow the ground. | skipped | skipped |  |
| 8001-1 | 1 | The droid folds up for transport: the legs swing up against the body at the hips, turning… | works | partly | the gear reading; still: p42 32165, p71 32165 |
| 8001-1 | 2 | Pressing the round button on the back of the hips tips the lever it sits on, lifting the … | works | partly | the gear reading; still: p9 32034 |
| 8001-1 | 3 | Once the catch is lifted, rubber bands round the two pulleys in the hips spring the droid… | skipped | skipped |  |
| 8001-1 | 4 | The head folds down onto the back for transport and swings back up, pivoting on an axle a… | works | works | a drag's loop |
| 8001-1 | 5 | Turning the grey gear on the backpack raises the right arm, which holds the blaster, to a… | no | partly | a drag on its joint; still: p848 32177, p846 32177; moved: p95 32184, p830 32177 |
| 8001-1 | 6 | The left arm swings at the shoulder and bends at the elbow, so it can be posed. | works | partly | the gear reading; still: p825 32177, p815 6536 |
| 8001-1 | 7 | Each leg bends at the knee, and a rubber band across the knee pulls it straight again. | partly | no | p42 32165 is part of the frame (#46 32165, keyed in its axle hole, #45 32062) p71 32165 is part of the frame …; still: p42 32165, p71 32165 |
| 8001-1 | 8 | The blaster is held in the right hand by a magnet, so it can be taken out and put back. | skipped | skipped |  |
| 8002-1 | 1 | The droid changes from its standing attack shape into a wheel: the curved brown shell, hi… | works | works | the gear reading |
| 8002-1 | 2 | The head on the front end of the shell, with its red-tipped sensors, folds down against t… | works | works | the gear reading |
| 8002-1 | 3 | Each arm swings in at the shoulder, folding its twin blasters against the body for rollin… | partly | partly | the gear reading; still: p856 6536, p619 6536 |
| 8002-1 | 4 | Each twin blaster bends at the elbow of its arm. | partly | partly | the gear reading; still: p856 6536, p619 6536 |
| 8002-1 | 5 | The two front legs fold back under the body for rolling and swing down to stand on. | works | works | the gear reading |
| 8002-1 | 6 | The single back leg swings up over the back to close the wheel, and down again to stand o… | works | works | a drag's loop |
| 8002-1 | 7 | Pressing the red pin on top of the shell pushes a rod down the middle that frees a catch,… | skipped | skipped |  |
| 8002-1 | 8 | Catches click to hold the arms and the shell folded in the wheel shape, and rubber bands … | skipped | skipped |  |
| 8002-1 | 9 | In the wheel shape the droid rolls along the floor on the rim of its shell. | skipped | skipped |  |
| 8012-1 | 1 | The black lever at the top of the back swings the right arm up and down: the lever carrie… | works | works | the gear reading |
| 8012-1 | 2 | The left arm swings at the shoulder on a long pin. | works | works | the gear reading |
| 8012-1 | 3 | Each arm bends at the elbow on a click hinge, which holds where it's set. | partly | no | p3833 3705 is part of the frame (#3834 3705, keyed in its axle hole, #3842 32291; #3842 32291, two joints on …; still: p3851 32291, p3083 6538b |
| 8012-1 | 4 | A long grey rod runs from each arm's blaster frame up the arm to beside the shoulder. | not checked | not checked |  |
| 8012-1 | 5 | A rubber band at the right arm's blasters holds the blaster frame. | skipped | skipped |  |
| 8012-1 | 6 | Each leg poses at the hip, knee and ankle on click hinges, each holding where it's set. | partly | partly | a drag on its joint; the gear reading; p2363 41681 is part of the frame (#2364 41681, two joints on two lines, #2362 32062; #2362 32062, keyed in it… |
| 8012-1 | 7 | A grey rod hangs from each hip's round plate down the front of the thigh, sliding through… | not checked | not checked |  |
| 8020-1 | 1 | The wheel on the cab roof steers the front wheels: an 8-tooth gear at the foot of its axl… | works | works | a drag's loop |
| 8020-1 | 2 | The four road wheels roll freely, the front ones on pins in the steering arms, the rear o… | works | works | the gear reading |
| 8022-1 | 1 | Rolling the plane on its wheels spins the propeller: an 8 tooth gear on the wheels' axle … | works | works | the gear reading |
| 8024-1 | 1 | The knob on the rear deck steers the front wheels: its upright shaft has a crown gear at … | works | works | a drag's loop |
| 8024-1 | 2 | Rolling the racer works its engine: the right rear half-axle carries a crankshaft, and th… | works | works | a drag's loop |
| 8024-1 | 3 | The four wheels roll freely, the rear two each on its own half-axle. | works | works | the gear reading; a drag's loop |
| 8032-1 | 1 | The handwheel works the saw: a pin in the 24 tooth gear on the handwheel's axle is a cran… | works | works | a drag's loop |
| 8032-1 | 2 | The crown gear on top of the tilted frame turns freely on its axle, like a saw blade. | works | works | the gear reading |
| 8049-1 | 1 | The round yellow knob on the cab roof steers the front wheels: its upright axle comes dow… | partly | works | a drag's loop |
| 8049-1 | 2 | The trailer hangs on the tractor's hitch by a single pin, so the tractor swings on it to … | no | works | the gear reading |
| 8049-1 | 3 | The black gear at the back of the trailer slews the crane: a long axle under the trailer … | partly | partly | the gear reading; still: p404 48452 |
| 8049-1 | 4 | The hand pump on the trailer, with the left valve set, works the cylinder in the crane's … | partly | no | the gear reading; p422 2796: locked: the couplings ask for two different turns at once; still: p424 32278, p455 32278 |
| 8049-1 | 5 | The hand pump, with the right valve set one way or the other, works the cylinder on top o… | partly | no | the gear reading; p452 2796: locked: the couplings ask for two different turns at once; still: p455 32278, p461 6536 |
| 8049-1 | 6 | The black gear on the grab opens and closes its two jaws: it turns a worm, which turns an… | works | works | the gear reading |
| 8049-1 | 7 | The grab hangs from the end of the outer arm on two pivots, so it swings and stays hangin… | skipped | skipped |  |
| 8049-1 | 8 | The tractor's four wheels and the trailer's four wheels roll freely. | works | partly | the gear reading; p205 56145 is part of the frame (#206 56145, keyed in its axle hole, #27 87083) |
| 8054-1 | 1 | The motor at the back drives the four rear wheels through two rubber-band stages: a band … | works | no | p72 4265a is part of the frame (#73 4265a, keyed in its axle hole, #28 6216m; #28 6216m, a stud in its socket…; still: p50 4185, p55 4185, p53 3708 |
| 8054-1 | 2 | The two front wheels roll freely on their axle; there's no steering. | works | works | the gear reading |
| 8054-1 | 3 | The rubber bands slip when the wheels are held, so the motor can't stall. | skipped | skipped |  |
| 8062-1 | 1 | Swinging the player's upper body sweeps the hockey stick across the ice at the puck (a cr… | partly | partly | the gear reading; still: p55 3705 |
| 8062-1 | 2 | The stick is held on two axles between the hand's two yellow liftarms, so it stays fixed … | not checked | not checked |  |
| 8063-1 | 1 | The black 20 tooth gear on the cab roof steers the front wheels: its shaft runs down to a… | works | works | a drag's loop |
| 8063-1 | 2 | The steering wheel in the cab turns on an axle pin but isn't joined to the steering. | works | works | the gear reading |
| 8063-1 | 3 | The rear wheels drive through a differential, and the four pistons of the engine under th… | works | partly | the gear reading; still: p199 6573, p29 32270, p37 4019 |
| 8063-1 | 4 | The front wheels roll freely. | works | works | the gear reading |
| 8063-1 | 5 | The red lever on the tractor's left side slides a driving ring along the drive shaft, loc… | works | partly | the gear reading; still: p33 6539 |
| 8063-1 | 6 | With the lever engaged, the rear power take-off turns as the tractor rolls: the clutch ge… | works | partly | the gear reading; p112 32039, worked first, went 0.03 of 0.4; still: p31 6542a, p61 4019, p65 3706 |
| 8063-1 | 7 | The black knob behind the cab raises and lowers the rear three-point linkage: it turns a … | partly | partly | the gear reading; still: p13 32009, p184 32009 |
| 8063-1 | 8 | Either of the two gears at the front of the trailer, one on each side, tips the trailer's… | works | partly | the gear reading; still: p764 62274c01, p959 40490, p1004 64782; moved: p763 62271c01 |
| 8063-1 | 9 | The trailer's drawbar is hitched behind the tractor and swivels on its pin, so the traile… | not checked | not checked |  |
| 8063-1 | 10 | The trailer's four wheels roll freely. | works | works | the gear reading |
| 8063-1 | 11 | Each side's two trailer wheels sit at the ends of a beam that rocks on its middle, so all… | works | no | the gear reading; p708 32525: locked: the couplings ask for two different turns at once p842 32525: locked: the couplings ask f… |
| 8063-1 | 12 | A short chain hangs from the trailer's drawbar. | skipped | skipped |  |
| 8074-1 | 1 | The handwheel with the half-pin handle, low on the tower's side, winds the winch: its 12-… | partly | partly | the gear reading; still: p231 8074 - 4185a, p233 70496 |
| 8074-1 | 2 | A pawl on the tower, a 4-long axle hanging from a pin, rests on the 16-tooth gear on the … | skipped | skipped |  |
| 8074-1 | 3 | The round yellow knob high on the tower's side slews the crane: its 6-long axle turns a 1… | partly | partly | the gear reading; still: p40 2856, p96 3738, p201 3703 |
| 8074-1 | 4 | One handwheel at the back of the counter-jib luffs the jib: its 10-long axle's worm turns… | partly | partly | the gear reading; still: p177 3708, p201 3703, p202 3703 |
| 8074-1 | 5 | The other handwheel at the back of the counter-jib swings the arm that hangs from the jib… | partly | partly | the gear reading; still: p170 3704, p223 3705, p216 2730 |
| 8081-1 | 1 | The black gear on the roof steers the front wheels: its upright axle comes down behind th… | partly | partly | the gear reading; still: p48 32072, p52 32072, p219 3647 |
| 8081-1 | 2 | Rolling the car turns the V4 engine: the rear wheels drive the differential, a shaft with… | works | partly | the gear reading; still: p94 62821, p81 32269, p8 94925 |
| 8081-1 | 3 | The rear differential lets the two rear wheels turn at different speeds round corners. | works | partly | the gear reading; still: p95 6589 |
| 8081-1 | 4 | The bonnet tilts up on a hinge at the windscreen, showing the engine. | no | works | the gear reading |
| 8081-1 | 5 | The two front doors open, each swinging out on a hinge at its front edge. | works | no | the gear reading; p472 41239: locked: the couplings ask for two different turns at once p504 41239: locked: the couplings ask f… |
| 8081-1 | 6 | The tailgate at the back swings up on a hinge at the roof. | no | no | p415 32278 is part of the frame (#417 32278, held, #1 64179); still: p455 41239, p411 87086, p412 87080 |
| 8081-1 | 7 | The front wheels have independent suspension: each hub rides between an upper and a lower… | no | works | a drag's loop |
| 8081-1 | 8 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 8081-1 | 9 | The small steering wheel in the cab turns on its own; it doesn't steer. | works | works | the gear reading |
| 8094-1 | 1 | The base motor slews the robot round on its turntable: a rubber band from the motor turns… | partly | partly | the gear reading; still: p161 2855, p259 3703, p281 3709b |
| 8094-1 | 2 | The arm motor, at the back of the arm as a counterweight, opens and closes the gripper: t… | partly | partly | the gear reading; still: p297 2825, p305 2825, p316 3708 |
| 8094-1 | 3 | The same arm motor raises and lowers the arm: once the claws have closed on something, th… | works | partly | the gear reading; still: p259 3703, p281 3709b |
| 8094-1 | 4 | As the arm rises and falls, the grey links and support rod on its far side keep the forea… | not checked | not checked |  |
| 8094-1 | 5 | Pieces set on the sloping chute slide down to the stop at its foot, where the gripper pic… | skipped | skipped |  |
| 8094-1 | 6 | The chute stands fixed beside the baseplate: its two grey pillars and the sloping ramp on… | not checked | not checked |  |
| 8110-1 | 1 | The gear on the cab roof steers the front wheels: its long upright axle comes down throug… | partly | partly | the gear reading; still: p1498 32072, p1088 32270, p1080 87761 |
| 8110-1 | 2 | The steering wheel in the cab turns with the steering. | works | works | the gear reading |
| 8110-1 | 3 | Rolling the truck turns the four-cylinder engine: both axles' differentials are linked by… | works | partly | the gear reading; still: p969 62821, p590 62821, p1145 94925 |
| 8110-1 | 4 | Each axle's differential lets its two wheels turn at different speeds round corners. | works | partly | the gear reading; still: p971 6589, p593 6589 |
| 8110-1 | 5 | Both portal axles swing about the frame (pendulum suspension), each sprung by two shock a… | partly | works | the gear reading |
| 8110-1 | 6 | The Power Functions motor under the bed drives a gearbox with two driving rings; the yell… | no | works | the gear reading |
| 8110-1 | 7 | With the yellow lever up and the red lever down, the motor winds the winch at the front: … | no | partly | the gear reading; p512 6641, worked first, went 0.09 of 0.4 p516 6641, worked first, went -0.09 of -0.4; still: p4019 94925, p4001 4716, p4029 76019 |
| 8110-1 | 8 | With both levers up, the motor slews the crane: a shaft runs back to the crane base, wher… | no | partly | the gear reading; p512 6641, worked first, went 0.09 of 0.4 p516 6641, worked first, went 0.09 of 0.4; still: p767 94925, p2199 94925, p2172 4716 |
| 8110-1 | 9 | With the yellow lever down and the red knob on the side pushed out, the motor runs the co… | no | partly | the gear reading; p512 6641, worked first, went -0.09 of -0.4; still: p422 94925, p730 6587 |
| 8110-1 | 10 | With the yellow lever down and the red knob pushed in, the motor works a fourth output. | no | works | the gear reading |
| 8110-1 | 11 | The first valve on the crane base works the cylinder that raises and lowers the crane's m… | partly | partly | the gear reading; still: p2628 47224 |
| 8110-1 | 12 | The second valve works the cylinder that swings the crane's outer arm with the grab up an… | no | partly | the gear reading; still: p3164 2947a |
| 8110-1 | 13 | The third valve works the small cylinder that opens and closes the grab's jaws. | works | works | the gear reading |
| 8110-1 | 14 | The black gears at the two sides of the crane's subframe swing the striped stabiliser leg… | works | works | a drag's loop |
| 8110-1 | 15 | The cab tilts forward on hinges at its front, showing the engine. | partly | no | p1563 32278 is part of the frame (#1568 32278, two joints on two lines, #1538 32526; #1538 32526, two joints …; still: p1761 32278, p1843 2741 |
| 8110-1 | 16 | A fourth valve on the truck, by the gearbox, is part of the air system. | no | no | p826 47223a-f1 is part of the frame (#829 47223a-f1, two joints on two lines, #831 32140; #831 32140, a pin i… |
| 8202-1 | 1 | Pulling the chopper backwards along the ground winds it up: the rear axle's gear drives t… | partly | partly | the gear reading; still: p34 4019, p24 32012; moved: p45 32013 |
| 8202-1 | 2 | Let go, the stretched bungee pulls the string back off the reel, which drives the rear wh… | skipped | skipped |  |
| 8202-1 | 3 | The idler gear rides on a swinging arm hung from a pin at the front of the frame, resting… | skipped | skipped |  |
| 8202-1 | 4 | The twin front wheels roll freely together on their short axle at the end of the long for… | partly | works | the gear reading |
| 8203-1 | 1 | The four wheels roll freely, each on its own pin in the yellow chassis; there's no steeri… | works | partly | a drag on its joint; p10 6118: Simulate has no joint it turns on (floating) p11 6118: Simulate has no joint it turns on (floating) |
| 8203-1 | 2 | The black arm carrying the hose roll cage tilts on the 4-long axle through the middle of … | works | works | the gear reading |
| 8203-1 | 3 | The rubber band, looped round the two 3/4 pins on the chassis sides and under the black a… | skipped | skipped |  |
| 8204-1 | 1 | Rolling the plane on its two wheels spins the propeller: a rubber band runs as a belt fro… | partly | partly | a drag on its joint; still: p10 6589, p25 6589, p35 32125 |
| 8204-1 | 2 | The propeller spins by hand, turning the two bevel gears and, through the band, the wheel… | works | works | the gear reading |
| 8208-1 | 1 | The handlebars steer the front wheel: the long front fork hangs from the head of the fram… | no | works | the gear reading |
| 8208-1 | 2 | Both wheels roll freely: the front one on an axle between the fork's two toggle joints, t… | works | works | the gear reading |
| 8209-1 | 1 | The rear end is sprung: the rear wheels, the dark 5-hole side beams they hang on and the … | no | no | the gear reading; p6 32056: locked: the couplings ask for two different turns at once; still: p46 32193, p45 32193, p25 32073 |
| 8209-1 | 2 | The shock absorber's spring holds the rear end up, so the car stands on its rear wheels a… | skipped | skipped |  |
| 8209-1 | 3 | Pushed along, all four wheels roll freely: each rear wheel on its own axle pin in the dar… | works | works | the gear reading |
| 8209-1 | 4 | The grey 12-tooth gear in front of the cockpit stands for the steering wheel. Its column … | not checked | not checked |  |
| 8217-1 | 1 | Pushed along, the two wheels turn together on one long axle, and a 12-tooth bevel gear on… | works | works | the gear reading |
| 8217-1 | 2 | The tail rotor, a dark 5-hole beam with yellow round plates at its ends, spins freely on … | works | works | the gear reading |
| 8218-1 | 1 | Rolling the trike turns the right rear wheel, whose axle turns the crank under the engine… | works | works | a drag's loop |
| 8218-1 | 2 | The left rear wheel turns freely on its own axle pin and doesn't drive the engine. | works | works | the gear reading |
| 8218-1 | 3 | The front wheel rolls freely on its axle between the fork's tips. | works | works | the gear reading |
| 8218-1 | 4 | The handlebars steer the front fork, which swivels on a single friction pin at the front … | no | works | the gear reading |
| 8245-1 | 1 | The buggy's punch: turning the small black knob low on the buggy's right side swings a le… | partly | works | the gear reading |
| 8245-1 | 2 | The buggy rolls on three wheels with yellow hubs: two on one axle at the back and one at … | works | works | the gear reading |
| 8245-1 | 3 | The robot's rubber-band motor: rolling the robot on its two big wheels turns the purple r… | works | works | the gear reading |
| 8245-1 | 4 | The long white rubber band runs from the reel along the purple tail, round the pulleys at… | skipped | skipped |  |
| 8245-1 | 5 | The two small black wheels at the end of the purple tail roll freely. | works | works | the gear reading |
| 8245-1 | 6 | The robot's head (the eyes, the black hoses and the purple target disc on top) is set fol… | works | no | p188 6629 is part of the frame; still: p285 2723, p189 99773 |
| 8245-1 | 7 | Two black rubber bands from the head down to the body pull the head back once it's let go. | skipped | skipped |  |
| 8245-1 | 8 | The two purple arms with yellow claws swing round on upright pins at the front corners of… | partly | works | the gear reading |
| 8245-1 | 9 | Black rubber bands across the front of the body, round the arms' pins, spring the arms. | skipped | skipped |  |
| 8245-1 | 10 | A black T-shaped foot hangs on a cross axle under the front of the body and swings. | works | works | the gear reading |
| 8256-1 | 1 | The steering wheel steers the front wheels: the foot of its slanted column pushes the 9-l… | partly | partly | the gear reading; still: p83 32068, p84 32068, p89 40490 |
| 8256-1 | 2 | Pushing the kart along turns the engine: the rear axle's 16 tooth gear turns the 16 tooth… | works | partly | a drag's loop; still: p16 4019, p12 2853, p14 2852 |
| 8256-1 | 3 | The wheels roll freely: the two rear wheels together on their 7-long axle, the two front … | works | works | a drag's loop; the gear reading |
| 8257-1 | 1 | The purple striker runs on two rubber tracks, each round three yellow sprocket wheels tha… | works | works | the gear reading |
| 8257-1 | 2 | Pulling the purple striker's trigger, the yellow towball arm under the top of its handle,… | works | works | a drag's loop |
| 8257-1 | 3 | The purple striker's seat sits on a lever pivoted at the top of its handle: a black cage … | partly | partly | the gear reading; still: p620 2698 |
| 8257-1 | 4 | Hitting the purple striker's target swings the target lever back on its pivot under the s… | no | works | the gear reading |
| 8257-1 | 5 | The teal striker runs on three wheels that roll freely: one at the front, under the targe… | partly | works | a drag on its joint |
| 8257-1 | 6 | Pulling the teal striker's trigger, the yellow towball arm under the top of its handle, s… | partly | works | a drag's loop |
| 8257-1 | 7 | The teal striker's seat is a cage of grey angle connectors and axles round the driver, wi… | no | partly | the gear reading; still: p184 2698 |
| 8257-1 | 8 | Hitting the teal striker's target swings the target lever back on its pivot under the sea… | works | works | the gear reading |
| 8257-1 | 9 | On each striker, a spring shock absorber between the seat's lever and the handle flips th… | skipped | skipped |  |
| 8257-1 | 10 | On each striker, two rubber bands pull the trigger back, which folds the scissor arm away… | skipped | skipped |  |
| 8258-1 | 1 | The Power Functions XL motor drives the crane's four functions one at a time: the battery… | not checked | not checked |  |
| 8258-1 | 2 | The four outriggers slide out sideways and back in, driven by the motor through gear rack… | partly | partly | the gear reading and 1 loop it turns; still: p531 64781, p557 64781, p524 32524 |
| 8258-1 | 3 | The lower boom rises and lowers, pushed by the linear actuator under it, driven by the mo… | partly | partly | the gear reading and 1 loop it turns; still: p2097 62274c01, p2123 32526, p2180 32524 |
| 8258-1 | 4 | The crane slews round on its turntable behind the cab, carrying both booms, driven by the… | partly | partly | the gear reading and 1 loop it turns; still: p2027 48168, p2046 40490, p2123 32526 |
| 8258-1 | 5 | The upper boom folds up and down at the lower boom's tip, pushed by the second linear act… | partly | partly | the gear reading and 1 loop it turns; still: p2167 62274c01, p2180 32524 |
| 8258-1 | 6 | The round knob on top behind the cab steers the front two axles: a long vertical shaft ta… | works | works | a drag's loop |
| 8258-1 | 7 | The V8 engine turns as the truck rolls: the two rear axles drive the long shaft along the… | works | partly | the gear reading and 1 loop it turns |
| 8258-1 | 8 | The eight wheels roll; the front four steer. | not checked | not checked |  |
| 8258-1 | 9 | The hook hangs on its string from the upper boom's tip. | not checked | not checked |  |
| 8259-1 | 1 | Turning the knob at the back (a bush on the long axle through the body) turns the worm un… | partly | partly | the gear reading and 1 loop it turns; still: p56 4716 |
| 8259-1 | 2 | The two tracks roll as the bulldozer is pushed along; nothing drives them. Each track run… | works | works | the gear reading |
| 8259-1 | 3 | The two yellow rams standing on the blade are only for show: each is an axle in an axle j… | skipped | skipped |  |
| 8260-1 | 1 | Turning the red knob at the back turns the worm under the tractor, which turns the 8 toot… | works | works | the gear reading |
| 8260-1 | 2 | The bucket tips forward and back by hand on its click hinge at the arms' ends, holding wh… | no | works | the gear reading |
| 8260-1 | 3 | The wheels roll freely: the two big rear wheels together on their 8-long axle, the two sm… | works | works | the gear reading |
| 8260-1 | 4 | The steering wheel turns on its axle in the cab, but steers nothing: the front wheels sit… | works | works | the gear reading |
| 8261-1 | 1 | The 12 tooth gear on the roof steers the front wheels: it turns a vertical shaft down thr… | works | works | the gear reading |
| 8261-1 | 2 | The front axle swings side to side about the steering shaft it hangs from, so the front w… | no | no | the gear reading; p63 32524: locked: the couplings ask for two different turns at once; still: p63 32524, p66 48989, p67 48989 |
| 8261-1 | 3 | The rear wheels ride on a trailing arm: two bent beams pivot on a 7-long axle under the m… | no | no | the gear reading; p45 32271: locked: the couplings ask for two different turns at once; still: p45 32271, p51 32271, p43 59426 |
| 8261-1 | 4 | The shock absorber's spring pushes the rear wheels back down. | skipped | skipped |  |
| 8261-1 | 5 | The four wheels roll freely; there's no drive. | works | works | the gear reading |
| 8270-1 | 1 | The crane's upper works turn round on the chassis, carrying the boom with them: they sit … | no | no | p0 2905 is part of the frame; still: p30 57779, p60 32498 |
| 8270-1 | 2 | The gear knob at the back raises and lowers the boom: its long axle turns a worm, which t… | partly | partly | a drag on its joint; still: p30 57779 |
| 8270-1 | 3 | The gear knob on the end of the winch drum's axle, high on the upper works' side, winds t… | partly | partly | the gear reading; still: p57 30395 |
| 8270-1 | 4 | The black inner boom slides in and out of the yellow outer boom by hand, carrying the pul… | partly | partly | a drag on its joint; still: p55 32278, p50 6632; moved: p30 57779 |
| 8270-1 | 5 | The two pairs of black outrigger legs, one at each end of the chassis, fold down to stand… | no | partly | a drag's loop; still: p76 32140, p77 32140; moved: p64 32523, p65 32523 |
| 8270-1 | 6 | The four wheels roll freely on their pins; there's no steering. | works | works | the gear reading |
| 8270-1 | 7 | An 8-tooth gear on a friction pin meshes with the 8-tooth gear on the winch drum's axle, … | skipped | skipped |  |
| 8270-1 | 8 | The hook hangs straight down beneath the boom tip, with the red beam hooked on it, as the… | not checked | not checked |  |
| 8272-1 | 1 | The handlebars steer the two skis: the steering column turns the red steering arm at its … | works | partly | the gear reading; still: p76 32526, p80 32005, p81 32005 |
| 8272-1 | 2 | The left ski has independent suspension: it rides on two wishbones of thin grey beams, up… | no | no | the gear reading; p12 32063: locked: the couplings ask for two different turns at once; still: p43 32063, p17 32063, p36 32063 |
| 8272-1 | 3 | The right ski has independent suspension, as the left. | no | no | the gear reading; p9 32063: locked: the couplings ask for two different turns at once; still: p42 32063, p21 32063, p35 32063 |
| 8272-1 | 4 | The front shock absorbers' springs hold the front up and spring back. | skipped | skipped |  |
| 8272-1 | 5 | The track runs round its three black sprockets and the grey wheels beside them as the sno… | works | partly | the gear reading; still: p142 57520, p150 57520, p166 57518 |
| 8272-1 | 6 | Each ski rocks nose up and nose down on the pin that holds it under its spindle, followin… | works | works | the gear reading |
| 8273-1 | 1 | The gear on the cab roof steers the front wheels: its shaft runs down through the cab to … | works | works | a drag's loop |
| 8273-1 | 2 | The cab tilts forward on its pivot at the front of the chassis, taking the roof gear's sh… | no | no | p556 41239 is part of the frame (#557 41239, two joints on two lines, #516 32525; #516 32525, two joints on t…; still: p556 41239, p644 32269 |
| 8273-1 | 3 | The gear knob at the front bumper winds the winch, pulling in or paying out the hook on i… | works | partly | the gear reading; still: p3954 30395 |
| 8273-1 | 4 | The rear of the two gear knobs on the chassis's left side slews the crane round on its tu… | partly | no | p187 32270: Simulate has no joint it turns on (floating); still: p136 32270, p212 48168, p455 32525 |
| 8273-1 | 5 | The front of the two gear knobs on the chassis's left side raises and lowers the crane's … | partly | works | a drag on its joint |
| 8273-1 | 6 | The gear knob at the top of the red arm folds the black jib up and down: it turns a worm … | works | works | the gear reading |
| 8273-1 | 7 | The fork hangs from the jib's end and stays level as the crane moves, carrying the tan lo… | not checked | not checked |  |
| 8273-1 | 8 | The gear knob low on the right side, behind the cab, tips the grey bed: its shaft's crank… | works | works | a drag's loop |
| 8273-1 | 9 | The tailgate at the back of the bed swings open. | works | partly | the gear reading; still: p357 32316 |
| 8273-1 | 10 | The four rear wheels are on a bogie that rocks on one cross axle through the frame, so bo… | no | works | the gear reading |
| 8273-1 | 11 | The six wheels roll freely; nothing drives them. | works | works | the gear reading |
| 8273-1 | 12 | A second 8-tooth gear meshes with the 8-tooth gear on the winch drum's other end, a brake… | skipped | skipped |  |
| 8274-1 | 1 | The 20-tooth gear on top behind the cab steers the rear wheels: its shaft runs down to a … | works | works | a drag's loop |
| 8274-1 | 2 | The 20-tooth gear on top at the front raises and lowers the header: its shaft runs down t… | no | works | the gear reading |
| 8274-1 | 3 | Pushing the combine along turns the header's reel: the front axle's differential turns a … | partly | partly | the gear reading; still: p18 6573, p123 3648b, p122 32072 |
| 8274-1 | 4 | The front wheels drive through a differential, so they can turn at different speeds in a … | partly | partly | the gear reading; still: p968 41896, p18 6573 |
| 8274-1 | 5 | The white unloading auger swings out from the grain tank to the side and back in along th… | partly | no | the gear reading; p919 32278: locked: the couplings ask for two different turns at once; still: p938 43857 |
| 8274-1 | 6 | The four wheels roll freely; only the front pair drives anything. | works | works | the gear reading |
| 8274-1 | 7 | For road travel the header comes off the front and is hitched behind the combine, where i… | not checked | not checked |  |
| 8275-1 | 1 | The left XL motor drives the left track: a 16 tooth gear on its shaft drives, through a 1… | partly | partly | the gear reading and 1 loop it turns; still: p2626 57518, p34 4019 |
| 8275-1 | 2 | The right XL motor drives the right track the same way, from the back: a 16 tooth gear on… | partly | partly | the gear reading and 1 loop it turns; still: p2670 57518, p663 4019 |
| 8275-1 | 3 | With both tracks driven the same way the bulldozer drives straight forwards or back; with… | partly | partly | the gear reading and 1 loop it turns; still: p2614 57519, p2612 57519 |
| 8275-1 | 4 | The six pistons of the V6 engine in the middle of the bulldozer pump in their cylinders a… | works | partly | the gear reading and 1 loop it turns; still: p1397 2853, p1409 2851, p1410 2851 |
| 8275-1 | 5 | One M motor raises and lowers the blade: an 8 tooth gear on its shaft drives a 24 tooth c… | partly | works | the gear reading |
| 8275-1 | 6 | The other M motor raises and lowers the ripper at the back: an 8 tooth gear on its shaft … | partly | partly | the gear reading; still: p2944 4716, p2954 3648b, p2971 6629; moved: p2902 6178 |
| 8275-1 | 7 | The two 24 tooth clutch gears slip when the blade or the ripper reaches the end of its tr… | skipped | skipped |  |
| 8281-1 | 1 | The red knob low at the front, under the bonnet, raises and lowers the tedder: it's the f… | partly | partly | a drag's loop |
| 8281-1 | 2 | Pushing the tractor along spins the tedder's three toothed rotors: the rear axle's 20-too… | partly | partly | a drag's loop; the gear reading; still: p95 4019, p120 3650c, p118 3650c; moved: p96 32524 |
| 8281-1 | 3 | The front wheels roll freely on their axle; nothing steers them. | works | works | the gear reading |
| 8281-1 | 4 | The steering wheel in the cab is for show: it sits on a half pin and turns, but isn't lin… | no | works | the gear reading |
| 8283-1 | 1 | The yellow knob on the cab roof steers the front wheels: its column runs down through the… | partly | partly | the gear reading; still: p50 3647, p54 3648b, p83 32069 |
| 8283-1 | 2 | The left of the two knobs at the back (a 12-tooth double bevel gear) raises and lowers th… | no | partly | the gear reading; still: p223 41239, p310 2951; moved: p223 41239 |
| 8283-1 | 3 | The right of the two knobs at the back (a 12-tooth double bevel gear) extends and retract… | works | works | the gear reading |
| 8283-1 | 4 | Turning the axle end at the boom's head tilts the bucket: a worm on that axle turns an 8-… | works | works | the gear reading |
| 8283-1 | 5 | The four wheels roll freely; nothing drives them. | works | partly | the gear reading; p317 6595 is part of the frame (#322 6595, keyed in its axle hole, #81 6587) |
| 8283-1 | 6 | The steering wheel in the cab is for show: it sits on a half pin and turns, but isn't lin… | works | works | the gear reading |
| 8285-1 | 1 | Pushing the truck along turns the V6 engine: the first pair of rear wheels drives a diffe… | no | partly | the gear reading; still: p60 6573, p385 50450, p720 3705 |
| 8285-1 | 2 | The second pair of rear wheels and the front wheels roll freely. | no | works | the gear reading |
| 8285-1 | 3 | The knob on the cab roof steers the front wheels: its shaft runs down behind the seats, t… | partly | partly | the gear reading; still: p490 3743, p472 59426, p478 59426 |
| 8285-1 | 4 | The small steering wheel in the cab turns on its own; it isn't linked to the steering. | works | works | the gear reading |
| 8285-1 | 5 | The bonnet, with the grille and front wings, tilts forward to show the engine. | works | partly | the gear reading; still: p1074 3707 |
| 8285-1 | 6 | The knob on top of the sleeper box lowers and raises the two outriggers at the back: a wo… | partly | partly | the gear reading; still: p611 3648b, p367 50450, p1586 40490 |
| 8285-1 | 7 | The front knob on the crane base's left side winds the winch: a 12-tooth gear on its shaf… | partly | partly | the gear reading; still: p1877 70496 |
| 8285-1 | 8 | A ratchet holds the hook up: the yellow lever over the winch drum carries a pawl, held do… | skipped | skipped |  |
| 8285-1 | 9 | The rear knob on the crane base's left side raises and lowers the boom: a worm turns a 24… | no | works | a drag's loop |
| 8285-1 | 10 | The knob on the crane base's right side extends and retracts the boom's inner section: be… | works | works | the gear reading and 1 loop it turns |
| 8285-1 | 11 | Pumping the yellow hand pump on the deck fills the pneumatic system with air. | skipped | skipped |  |
| 8285-1 | 12 | The valve lever on the crane base's right side sends air to the yellow cylinder under the… | skipped | skipped |  |
| 8285-1 | 13 | The wheel-lift arm hinges at the back of the deck, so it swings up and down as the cylind… | no | partly | the gear reading; still: p51 47224c01-f1 |
| 8285-1 | 14 | The wheel forks hang from the end of the wheel-lift arm on a hinge, sprung by a shock abs… | partly | works | the gear reading |
| 8285-1 | 15 | The two side lockers behind the cab open: each door, with a handle, hinges up at its top … | works | no | the gear reading; p2158 32278: locked: the couplings ask for two different turns at once p2241 32278: locked: the couplings ask… |
| 8289-1 | 1 | The gear at the back of the truck, under the rear bumper, steers the front wheels: a long… | works | partly | the gear reading; still: p24 3743, p26 59426, p30 59426 |
| 8289-1 | 2 | The small steering wheel in the cab turns on its own; it isn't linked to the steering. | works | works | the gear reading |
| 8289-1 | 3 | The four wheels roll freely; there's no drivetrain. | works | works | the gear reading |
| 8289-1 | 4 | The two gears on top of the cab's back wall lower and raise the two outriggers, one on ea… | no | partly | the gear reading and 1 loop it turns; still: p281 32072, p282 32072, p232 40490 |
| 8289-1 | 5 | The 12-tooth gears low on the truck's sides beside the turntable slew the ladder round, a… | partly | works | the gear reading |
| 8289-1 | 6 | The other pair of 12-tooth gears on the truck's sides raises and lowers the ladder: their… | partly | partly | the gear reading; still: p955 32271 |
| 8289-1 | 7 | The hose reels at the back, three wheel hubs on a cross axle, turn. | works | works | the gear reading |
| 8416-1 | 1 | The crank at the back raises and lowers the forks: through a 20- and a 12-tooth double be… | no | no | the gear reading; p401 33299: locked: the couplings ask for two different turns at once; still: p406 32269, p324 4019, p529 6589 |
| 8416-1 | 2 | The levers at the front edge of the cab roof tilt the mast: they turn a crank on the roof… | partly | works | a drag's loop |
| 8416-1 | 3 | The beacon on the cab roof is a knob that steers the rear wheels: its axle runs down thro… | works | partly | the gear reading; still: p414 32198, p399 6589, p396 3647 |
| 8416-1 | 4 | The four wheels roll freely; nothing drives them. | works | works | the gear reading |
| 8416-1 | 5 | The steering wheel in the cab is for show: it sits on an axle pin and turns, but isn't li… | works | works | the gear reading |
| 8416-1 | 6 | The pallet is loose: it rests on the forks and is carried by them. | not checked | not checked |  |
| 8418-1 | 1 | The grey knob at the back (a 12-tooth double bevel gear) raises and lowers the loader arm… | works | works | the gear reading |
| 8418-1 | 2 | The bucket tilts by hand on its click hinge under the arms' crossbar, holding at each cli… | no | works | the gear reading |
| 8418-1 | 3 | The four wheels roll freely on pins; there's no steering (a skid loader). | no | works | the gear reading |
| 8419-1 | 1 | The upper body slews round on the turntable by hand, carrying the boom with it. | no | no | p212 32009 is part of the frame (#213 32009, keyed in its axle hole, #165 4519; #165 4519, two joints on two …; still: p212 32009, p284 2950 |
| 8419-1 | 2 | The knob at the back on the right (a 20-tooth double bevel gear) raises and lowers the bo… | works | partly | the gear reading; still: p144 32449, p148 32063, p115 32140 |
| 8419-1 | 3 | The knob at the back on the left (a 20-tooth double bevel gear) swings the stick in and o… | no | partly | the gear reading; still: p102 3326b, p129 4716, p135 3647 |
| 8419-1 | 4 | The two tracks run freely round their sprockets; nothing drives them. | partly | partly | the gear reading; still: p69 71372c01, p70 71372c01 |
| 8419-1 | 5 | The bucket is held at a fixed angle on the end of the stick by a grey link; it isn't work… | not checked | not checked |  |
| 8448-1 | 1 | The steering wheel steers the front wheels: its column, through universal joints, turns a… | partly | works | a drag's loop |
| 8448-1 | 2 | Pushing the car along runs the V8: the rear wheels drive the differential, whose output, … | partly | no | p478 32196 is part of the frame (#483 32196, held, #1 3703) p481 32196 is part of the frame (#486 32196, held…; still: p236 6573, p31 3706, p100 3737 |
| 8448-1 | 3 | The gear lever between the seats changes gear: moving it across picks one of the gearbox'… | works | partly | the gear reading; still: p497 6539 |
| 8448-1 | 4 | The differential lets the rear wheels turn at different speeds in a bend: with the drive … | partly | no | p478 32196 is part of the frame (#483 32196, held, #1 3703); still: p481 32196, p237 6589 |
| 8448-1 | 5 | The front wheels have independent suspension: each hub rides between two suspension arms … | partly | no | the gear reading; p364 32195a: locked: the couplings ask for two different turns at once p380 32195a: locked: the couplings ask…; still: p370 32184, p384 32184, p475 32196 |
| 8448-1 | 6 | The rear wheels have independent suspension: each upright rides between two arms with a s… | no | no | p231 6629 is part of the frame (#232 6629, a pin in the first thing it is in, #231 2780; #231 2780, held, #1 …; still: p259 32184, p270 32184, p481 32196 |
| 8448-1 | 7 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 8448-1 | 8 | The two pop-up headlights at the front swing up and down together, joined by a cross bar. | partly | partly | the gear reading; p1078 32000: locked: the couplings ask for two different turns at once; still: p1016 32015, p1017 32015, p1078 32000 |
| 8448-1 | 9 | The rear deck behind the seats, with its roll bars, tips up on its hinge, a white damped … | partly | partly | the gear reading; still: p1147 32181c01 |
| 8448-1 | 10 | A hinged catch at the very back holds the rear deck down. | skipped | skipped |  |
| 8448-1 | 11 | Each seat's backrest folds forward. | no | no | p757 6536 is part of the frame (#762 6536, keyed in its axle hole, #754 3705; #754 3705, keyed in its axle ho… |
| 8464-1 | 1 | The steering wheel in the cab steers the loader by bending it in the middle: an 8-tooth p… | partly | partly | the gear reading; still: p268 3647, p569 2995, p558 32030 |
| 8464-1 | 2 | The round yellow knob on top of the tall shaft behind the cab steers too: the shaft's 8-t… | no | partly | the gear reading; still: p303 4019, p291 2819, p569 2995 |
| 8464-1 | 3 | Pushing the loader along turns all four wheels together and runs the V6 engine: each axle… | partly | partly | a drag on its joint; still: p569 2995, p8 4019, p31 3650a |
| 8464-1 | 4 | The rear differential lets the rear wheels turn at different speeds in a bend: with the d… | works | partly | a drag on its joint; still: p567 2995, p17 6589 |
| 8464-1 | 5 | The front differential does the same for the front wheels. | works | partly | a drag on its joint; still: p571 2995, p99 6589 |
| 8464-1 | 6 | Pushing the pump's black knob in and out 30-35 times fills the blue air tank. | skipped | skipped |  |
| 8464-1 | 7 | One valve raises and lowers the boom: it feeds the two cylinders low down between the fro… | no | partly | the gear reading; still: p234 3702, p250 3702, p201 2793c01-f1 |
| 8464-1 | 8 | The other valve tips the bucket: it feeds the cylinder on top of the boom, which turns th… | no | partly | the gear reading; still: p558 32030, p203 2793c01-f1 |
| 8466-1 | 1 | The steering wheel steers the front wheels: its column, through two universal joints, tur… | partly | partly | the gear reading; still: p732 3647, p719 6592, p802 2739a |
| 8466-1 | 2 | The black knob on top of the roof also steers the front wheels: its long upright shaft ha… | partly | partly | the gear reading; still: p296 6589, p1103 32198, p731 3647 |
| 8466-1 | 3 | Pushing the off-roader along turns all four wheels together and runs the V8 engine: the f… | partly | no | p1063 22969 is part of the frame (#1067 22969, a pin in the first thing it is in, #1065 32496); still: p1081 22969, p669 22969, p690 22969 |
| 8466-1 | 4 | The gear lever between the seats picks one of five speeds or reverse, in the H-shaped gat… | not checked | not checked |  |
| 8466-1 | 5 | The front differential lets the front wheels turn at different speeds in a bend: with the… | no | no | p669 22969 is part of the frame; still: p690 22969, p651 6589, p652 6589 |
| 8466-1 | 6 | The rear differential does the same for the rear wheels. | partly | no | p1063 22969 is part of the frame (#1067 22969, a pin in the first thing it is in, #1065 32496); still: p1081 22969, p1033 6589, p1034 6589 |
| 8466-1 | 7 | The central differential lets the front and rear axles turn at different speeds: with the… | partly | no | p1063 22969 is part of the frame (#1067 22969, a pin in the first thing it is in, #1065 32496); still: p1031 6573, p818 6589 |
| 8466-1 | 8 | Each wheel has independent suspension: its hub rides on an upper and a lower suspension a… | partly | partly | a drag's loop; the gear reading |
| 8466-1 | 9 | The four shock absorbers' springs hold the off-roader up and spring back. | skipped | skipped |  |
| 8466-1 | 10 | The two doors swing up and out like gull wings: each is a black frame running from the ro… | partly | partly | a drag's loop; still: p276 32189, p257 32188 |
| 8466-1 | 11 | A white damped shock absorber at each side of the roof frame works like a gas strut for i… | skipped | skipped |  |
| 8466-1 | 12 | Two upright axles with grey bushes on top, either side of the knob at the back of the roo… | no | no | the gear reading; p183 3737: locked: the couplings ask for two different turns at once p210 3737: locked: the couplings ask for… |
| 850-1 | 1 | The handwheel on the mast's left side raises and lowers the forks: the axle across the to… | works | works | the gear reading |
| 850-1 | 2 | The steering wheel steers the back wheels: its upright axle turns a crown gear, which dri… | works | works | a drag's loop |
| 850-1 | 3 | The four wheels roll freely; the front pair are on short axles of their own. | works | works | the gear reading |
| 850-1 | 4 | The two levers beside the seat tip fore and aft on their pins, as the driver's controls; … | works | works | the gear reading |
| 851-1 | 1 | The 24-tooth gear on top of the steering column, used as the steering wheel, steers the f… | no | partly | the gear reading; still: p55 3706, p159 3743, p150 3706 |
| 851-1 | 2 | The two big rear wheels roll and drive the rotary harrow: the crown gear on the rear half… | works | partly | a drag's loop; still: p281 3649, p303 3649, p309 3649; moved: p39 3702, p226 3702 |
| 851-1 | 3 | The two small front wheels roll freely. | works | works | the gear reading |
| 851-1 | 4 | The tall lever beside the seat, linked by a short rod at its foot to the hitch, raises an… | no | partly | a drag's loop; still: p102 3702; moved: p239 3739 |
| 852-1 | 1 | The handwheel on the cabin's right side turns both rotors: through a crown gear and an 8-… | works | no | the gear reading; p143 3736: locked: the couplings ask for two different turns at once; still: p253 3708, p282 3034, p229 3650a |
| 852-1 | 2 | The two control sticks in front of the seats, on one cross shaft, raise and lower the col… | no | no | the gear reading; p37 3707: locked: the couplings ask for two different turns at once p41 3707: locked: the couplings ask for t…; still: p9 3706, p23 3701, p60 3707 |
| 852-1 | 3 | The landing skids stand fixed under the cabin on four struts, braced by two cross axles a… | not checked | not checked |  |
| 854-1 | 1 | The steering wheel steers the front wheels: its column, held at an angle on a frame of ro… | works | partly | the gear reading; still: p142 3706, p125 3743, p21 3679 |
| 854-1 | 2 | The rear wheels work the engine as the kart rolls: the 24-tooth gear on the right rear ax… | works | partly | the gear reading and 1 loop it turns; the gear reading; still: p46 3647, p47 3705, p100 3652 |
| 854-1 | 3 | The front wheels roll freely. | works | works | the gear reading |
| 854-1 | 4 | The nose with the number board hangs on the axle across the very front. | not checked | not checked |  |
| 855-1 | 1 | The cab slews round on its turntable, carrying the boom with it. | works | no | p162 3404 is part of the frame (#162 3403c01, a stud in its socket, #142 3033; #142 3033, a stud in its socke…; still: p315 3029 |
| 855-1 | 2 | The crank at the front of the cab's left side raises and lowers the boom: two racks slide… | works | works | a drag's loop |
| 855-1 | 3 | The crank at the back of the cab's left side winds the winch, raising or lowering the hoo… | works | partly | the gear reading; still: p497 3651 |
| 855-1 | 4 | The crank high on the cab's right side, on the boom's pivot axle, extends the boom's blue… | works | partly | a drag's loop; still: p402 3703; moved: p315 3029, p272 3736 |
| 855-1 | 5 | The four outriggers slide out on tiles and stand on their feet. | no | works | a drag on its joint |
| 855-1 | 6 | The four road wheels roll freely; there's no steering. | works | works | the gear reading |
| 855-1 | 7 | The four black window shutters on the chassis sides swing open. | no | works | the gear reading |
| 855-1 | 8 | The hook hangs straight down beneath the boom tip as the cab slews and the boom luffs. | not checked | not checked |  |
| 855-1 | 9 | A ratchet holds the boom up: the yellow lever's pawl rests on the luffing gears, so the b… | skipped | skipped |  |
| 855-1 | 10 | The rubber band pulls the ratchet's lever down onto the gears. | skipped | skipped |  |
| 856-1 | 1 | The handwheel at the back on the left raises and lowers the loader arms, slowly: its 8-to… | partly | partly | a drag's loop; moved: p140 3460 |
| 856-1 | 2 | The handwheel at the back on the right tips the bucket: its 8-tooth gear turns a crown ge… | works | partly | a drag's loop; still: p206 3894, p202 3700; moved: p60 3034 |
| 856-1 | 3 | The two tracks run freely, each on a 40-tooth gear at the front and back of its side, so … | works | works | the gear reading |
| 856-1 | 4 | The angled front guard below the cab front stays put. | not checked | not checked |  |
| 858-1 | 1 | 2-cycle engine: turning the hand wheel, the 24 tooth gear beside the engine with a pin fo… | works | partly | the gear reading; still: p7 3705, p15 3652 |
| 858-1 | 2 | Boxer engine: turning the crank, the 40 tooth gear on the end of the crankshaft, with a p… | works | partly | the gear reading; still: p67 3652, p71 3652, p75 3652 |
| 858-1 | 3 | Inline engine: pins on the camshaft's gears lift the three push rods in turn, and each ro… | works | partly | the gear reading; still: p138 3706, p157 3706 |
| 858-1 | 4 | Inline engine: turning the crank, the 40 tooth gear on the end of the crankshaft, with a … | works | partly | the gear reading; still: p23 3652, p27 3652, p31 3652 |
| 858-1 | 5 | Inline engine: as the crankshaft turns, rubber bands from its belt wheels turn the fan an… | works | partly | the gear reading; still: p110 3749, p52 3706 |
| 858-1 | 6 | Inline engine: the crankshaft's four 24 tooth gears turn the camshaft's four beside them,… | works | works | the gear reading |
| 858-1 | 7 | Inline engine: pins on the camshaft's gears lift the three push rods in turn, and each ro… | works | partly | the gear reading; still: p157 3706, p160 3706, p163 3706 |
| 858-1 | 8 | V-6 engine: turning the crank, the 40 tooth gear on the end of the crankshaft, with a pin… | works | partly | the gear reading; still: p16 3652, p20 3652, p24 3652 |
| 858-1 | 9 | V-6 engine: as the crankshaft turns, rubber bands from its belt wheels turn the fan and t… | works | partly | the gear reading; still: p158 3749, p114 3708 |
| 8808-1 | 1 | The steering wheel steers the front wheels: an 8 tooth gear on its column runs in a rack … | works | works | a drag's loop |
| 8808-1 | 2 | Pushed along, the four rear wheels, doubled up on one long axle, roll together. | works | works | the gear reading |
| 8808-1 | 3 | The front wheels, doubled up on a short axle in each steering arm, roll freely. | works | works | the gear reading |
| 8810-1 | 1 | The handlebars steer the front wheel: the whole front fork, with its two long fork legs, … | partly | works | the gear reading |
| 8810-1 | 2 | The rear wheel rides on a swinging arm: two 1x6 technic plates pivot on the axle under th… | partly | partly | a drag's loop; still: p33 4262, p16 4254, p18 4254 |
| 8810-1 | 3 | The two shock absorbers' springs push the rear wheel back down. | skipped | skipped |  |
| 8810-1 | 4 | The two wheels roll freely; there's no drive. The front wheel turns on its 4-long axle be… | works | works | the gear reading |
| 8810-1 | 5 | The parking stand under the middle of the bike folds: its two legs are hinge plates joine… | no | no | p28 4276b is part of the frame; still: p30 4276b, p34 3710 |
| 8815-1 | 1 | The steering wheel steers the front wheels: an 8-tooth gear at the foot of the steering c… | works | no | p59 8815 - 4185a is part of the frame (#60 8815 - 4185a, keyed in its axle hole, #54 3705; #54 3705, keyed in…; still: p53 3705, p48 2790a, p18 4261 |
| 8815-1 | 2 | Pushing the kart along works its engine: the crank on the rear axle on the engine's side … | works | partly | a drag's loop; moved: p22 2850a, p38 3706 |
| 8815-1 | 3 | The four wheels roll freely: each rear wheel on its own 4-long axle, each front wheel on … | works | works | a drag's loop; the gear reading |
| 8815-1 | 4 | The number board at the front tilts on its hinge. | no | works | the gear reading |
| 8820-1 | 1 | The steering wheel steers the front wheels: its column runs down at a slant to an 8-tooth… | no | works | a drag's loop |
| 8820-1 | 2 | The rear wheels ride on a swinging arm: two 1x6 bricks, one each side, pivot on a 10-long… | partly | no | a drag's loop; still: p105 3894, p32 3707, p30 4254 |
| 8820-1 | 3 | The shock absorber's spring pushes the rear wheels back down. | skipped | skipped |  |
| 8820-1 | 4 | The four wheels roll freely, each on its own axle pin; there's no drive. | partly | works | the gear reading |
| 8824-1 | 1 | The black wheel on top of the cabin steers: an 8 tooth gear at the foot of its shaft turn… | partly | works | the gear reading |
| 8824-1 | 2 | Rolling the hovercraft on its front wheels spins the propeller: a bevel gear on the front… | works | works | the gear reading |
| 8824-1 | 3 | The two rear wheels roll freely under the steering column. | works | works | the gear reading |
| 8825-1 | 1 | The handwheel on the right side turns the main rotor: the crown gear on its cross axle dr… | partly | partly | the gear reading; still: p57 3706, p82 4477, p83 4477 |
| 8825-1 | 2 | The same handwheel turns the tail rotor: the crown gear drives a 14 tooth bevel gear on t… | partly | partly | the gear reading; still: p45 3708, p95 2711 |
| 8825-1 | 3 | The round white light on the nose turns freely on its pin. | works | works | a drag on its joint |
| 8825-1 | 4 | The airframe holds its shape: the two skids, their four grey struts and the grey canopy f… | not checked | not checked |  |
| 8826-1 | 1 | The handlebars steer: the whole front end, with its two fork legs, both front wheels, the… | partly | partly | the gear reading; still: p53 3705 |
| 8826-1 | 2 | The four wheels roll freely, each on its own axle pin; there's no drive. | works | works | the gear reading |
| 8828-1 | 1 | The crank on the right side raises and lowers the loader arms with the bucket: it turns a… | works | works | the gear reading |
| 8828-1 | 2 | The crank on the left side tips the bucket: a crank arm on its axle pushes and pulls a pa… | partly | no | the gear reading; p126 3704: locked: the couplings ask for two different turns at once; still: p163 2951, p120 3706, p129 2711 |
| 8828-1 | 3 | The round knob on the cab roof steers the rear wheels: its long vertical axle turns a pai… | works | works | a drag's loop |
| 8828-1 | 4 | The four wheels roll freely; nothing drives them. The front wheels are on fixed pins, the… | works | works | the gear reading |
| 8830-1 | 1 | The handwheel on the roof steers the front and rear wheels together, the middle pair stay… | works | works | a drag's loop |
| 8830-1 | 2 | Pushed along, the six wheels roll freely on their axle pins. | works | works | the gear reading |
| 8830-1 | 3 | The small grey steering wheel the driver holds in front of the seat is for show: it isn't… | works | works | the gear reading |
| 8830-1 | 4 | The roll cage holds its shape: the front frame of toggle joints and the two roll bars ove… | not checked | not checked |  |
| 8832-1 | 1 | The steering wheel steers the front wheels: an 8-tooth gear at the foot of the slanted st… | works | no | p51 4185 is part of the frame (#52 4185a, keyed in its axle hole, #41 3705); still: p39 2790a, p12 4261, p13 4261 |
| 8832-1 | 2 | The rear wheels ride on a swinging arm: two 1x6 bricks pivot on the long axle under the s… | partly | partly | a drag's loop; moved: p9 2738, p32 3707 |
| 8832-1 | 3 | The shock absorber's spring pushes the rear wheels back down. | skipped | skipped |  |
| 8832-1 | 4 | The four wheels roll freely, each on its own axle pin; there's no drive. | works | works | the gear reading |
| 8835-1 | 1 | The crank handle on the big grey wheel on the cab's right side raises and lowers the fork… | works | partly | the gear reading; still: p63 2823, p71 3706; moved: p231 2695c01, p232 2695c01 |
| 8835-1 | 2 | The wedge-belt wheel on the cab's left side tilts the mast: it swings a short liftarm who… | no | partly | the gear reading; still: p63 2823 |
| 8835-1 | 3 | The yellow round knob on the cab roof steers the rear wheels: its vertical axle runs down… | works | works | a drag's loop |
| 8835-1 | 4 | The four wheels roll freely; there's no drive to them. | works | works | the gear reading |
| 8836-1 | 1 | The propeller turns the flat-twin engine in the nose: its shaft is the crankshaft, and tw… | works | works | a drag's loop |
| 8836-1 | 2 | Tilting the control stick side to side works the ailerons, the outer flaps behind each wi… | partly | partly | the gear reading; still: p9 3707, p122 4185b, p187 3737 |
| 8836-1 | 3 | The main landing gear is sprung: the two legs swing together on their pivots, joined by a… | works | partly | a drag's loop; still: p22 4254 |
| 8836-1 | 4 | The shock absorber's spring holds the main landing gear down and springs it back. | skipped | skipped |  |
| 8836-1 | 5 | The wheels roll freely: two nose wheels on one short axle, and a main wheel on each leg. … | works | works | the gear reading |
| 8837-1 | 1 | Pump with the black hand pump and push the lever of the inner valve (the two valves stand… | partly | partly | the gear reading; still: p174 3895, p213 3895, p183 3895 |
| 8837-1 | 2 | The outer valve, on the same side as the grey tower, works the small yellow cylinder on t… | partly | partly | the gear reading; still: p212 2950, p185 2825, p188 4263 |
| 8837-1 | 3 | The stick is held at a fixed angle to the boom: it pivots on the boom-tip axle, and a pai… | not checked | not checked |  |
| 8837-1 | 4 | The yellow round knob on top of the turntable, pushed down and turned, steers the wheels … | works | partly | a drag's loop; still: p19 2790a, p16 4261, p23 4261; moved: p54 3703 |
| 8837-1 | 5 | The same knob, pulled up and turned, slews the whole upper body with the boom round on th… | partly | partly | a drag's loop; still: p51 3647 |
| 8837-1 | 6 | The four wheels roll freely; nothing drives them. The two under the boom end steer, the t… | works | works | the gear reading |
| 8837-1 | 7 | The hand pump: pushing the black knob down blows air through the valves, and its spring p… | skipped | skipped |  |
| 8838-1 | 1 | The handlebars steer the front wheel: the whole front fork, with its two triangular clamp… | partly | partly | the gear reading; still: p73 3705, p77 2905, p84 2905 |
| 8838-1 | 2 | The front wheel has telescopic suspension: it hangs from the piston rods of two long shoc… | partly | partly | the gear reading; still: p227 2910, p219 3706, p220 8838 - 2903 |
| 8838-1 | 3 | The rear wheel rides on a swinging arm: a 1x10 brick and a triangular liftarm on each sid… | works | works | a drag's loop |
| 8838-1 | 4 | The shock absorbers' springs, two front and two rear, hold the bike up and push the wheel… | skipped | skipped |  |
| 8838-1 | 5 | Turning the rear wheel works the two-cylinder engine: a 24-tooth gear on the rear wheel d… | partly | partly | a drag on its joint; still: p25 4143, p1 2853, p5 2851 |
| 8838-1 | 6 | The front wheel rolls freely on its 6-long axle. | works | no | p220 8838 - 2903: Simulate has no joint it turns on (floating) |
| 8838-1 | 7 | The centre stand under the engine swings down onto its two legs to hold the bike up, and … | no | works | the gear reading |
| 8838-1 | 8 | Two rubber bands between the stand's levers and two dark levers on the frame hold the sta… | skipped | skipped |  |
| 8840-1 | 1 | The steering wheel in front of the seat steers the front wheels: the 16 tooth gear on the… | partly | works | a drag's loop |
| 8840-1 | 2 | The left rear wheel runs the V2 engine: on the left rear half-shaft a 14 tooth bevel gear… | partly | partly | a drag on its joint; still: p120 2851, p121 2851 |
| 8840-1 | 3 | The rear suspension: the whole rear frame, carrying the rear wheels and the engine, swing… | partly | no | a drag's loop; still: p210 4266, p213 4266, p200 4255 |
| 8840-1 | 4 | The shock absorbers' springs hold the rear frame down and let it bounce back. | skipped | skipped |  |
| 8840-1 | 5 | Pushed along, the four wheels roll freely; the right rear wheel turns on its own half-sha… | works | partly | the gear reading; a drag on its joint; p208 4266: Simulate has no joint it turns on (floating) |
| 8840-1 | 6 | The roll cage of toggle joints and axles over the driver, and the big rear wing on its fr… | not checked | not checked |  |
| 8841-1 | 1 | The steering wheel steers the front wheels: its column runs down through a universal join… | works | works | a drag's loop |
| 8841-1 | 2 | Rolling the buggy works the engine's piston: a pin in the 24-tooth gear on the left rear … | works | works | the gear reading |
| 8841-1 | 3 | The front wheels turn freely on pins in the steering arms. | works | works | the gear reading |
| 8841-1 | 4 | The rear wheels are on two separate axles; only the left one turns the engine. | works | works | the gear reading |
| 8841-1 | 5 | The roll cage, the seat and the steering column's mounting stay rigid: the toothed toggle… | not checked | not checked |  |
| 8844-1 | 1 | The crank low on the left side beside the seats retracts and lowers the landing gear: its… | partly | works | the gear reading |
| 8844-1 | 2 | The handwheel high on the left side turns the main rotor: a crown gear on its axle drives… | partly | partly | the gear reading; still: p172 3648a, p206 4262, p207 4262 |
| 8844-1 | 3 | The same handwheel turns the tail rotor: a second crown gear on its axle drives an 8 toot… | partly | partly | the gear reading; still: p134 3650b, p131 3706, p156 3666 |
| 8844-1 | 4 | Pushed along, the three wheels roll freely on their axle pins. | works | partly | the gear reading; p284 3482 is part of the frame (#285 3482, keyed in its axle hole, #284 3749) |
| 8844-1 | 5 | The two yellow engines either side of the rotor housing turn freely on their axles. | works | works | the gear reading |
| 8844-1 | 6 | The airframe holds its shape: the tail boom and rotor housing, the upright beams behind t… | not checked | not checked |  |
| 8845-1 | 1 | The steering wheel steers the front wheels: its column bends through a universal joint to… | no | partly | a drag's loop; still: p59 3743, p168 3482, p174 3482 |
| 8845-1 | 2 | Each rear wheel rides on its own trailing arm, which pivots on the cross axle ahead of it… | partly | no | the gear reading; p0 3702: locked: the couplings ask for two different turns at once p1 3702: locked: the couplings ask for two…; still: p172 3482, p170 3482, p105 4255 |
| 8845-1 | 3 | The shock absorbers' springs hold the rear arms down, so the buggy stands on its rear whe… | skipped | skipped |  |
| 8845-1 | 4 | Pushed along, all four wheels roll freely: the front ones on axle pins in the steering ar… | works | works | the gear reading |
| 8845-1 | 5 | The roll cage holds its shape: its toothed toggle joints grip at the angles they're set t… | not checked | not checked |  |
| 8848-1 | 1 | The steering wheel on top of the cab turns the front wheels: its column's bevel gear turn… | works | works | a drag's loop |
| 8848-1 | 2 | The rear axle has a differential, so as it rolls round a bend each rear wheel can turn at… | works | partly | the gear reading; still: p0 73071 |
| 8848-1 | 3 | As it rolls, the differential's big gear also turns two bevel gears: one on a drive shaft… | works | partly | the gear reading; still: p40 3708, p86 3705 |
| 8848-1 | 4 | The yellow lever on the right of the steering wheel tips the body: a link from it turns a… | no | partly | the gear reading; still: p328 3028, p114 3743, p121 3743 |
| 8848-1 | 5 | The yellow lever on the left of the steering wheel raises and lowers the front bucket's a… | partly | partly | a drag's loop; still: p191 3705, p190 3705, p359 3034 |
| 8848-1 | 6 | The 24 tooth gear at the front of the cab, behind the bucket, tips the bucket: turned as … | partly | partly | the gear reading; still: p245 3705, p359 3034 |
| 8848-1 | 7 | Pushed along, the front wheels roll freely on their stub axles in the steering arms. | works | works | the gear reading |
| 8849-1 | 1 | The steering wheel steers the front wheels: the column drives a shaft under the bonnet th… | works | partly | the gear reading; still: p118 3707, p114 3743, p100 4261 |
| 8849-1 | 2 | The exhaust stack on the bonnet turns as the steering wheel turns: a bevel gear on the st… | works | partly | the gear reading; still: p150 3708, p152 6143 |
| 8849-1 | 3 | The front axle rocks side to side on the steering shaft, so the front wheels can follow u… | works | works | a drag's loop |
| 8849-1 | 4 | Rolling the tractor turns the power take-off shaft sticking out at the back: a 24-tooth g… | works | partly | a drag's loop; still: p52 3707, p44 3705 |
| 8849-1 | 5 | The handwheel on the cab's right side raises and lowers the three-point hitch and the spr… | works | partly | the gear reading; still: p269 3894 |
| 8849-1 | 6 | The sprayer hangs on the hitch's two lower links and its top link, so it stays upright as… | not checked | not checked |  |
| 8849-1 | 7 | The four wheels roll; the front wheels turn freely on their own axles. | works | works | a drag's loop; the gear reading |
| 8850-1 | 1 | The yellow beacon on the roof steers the front wheels: its tall upright shaft carries a 2… | works | works | a drag's loop |
| 8850-1 | 2 | Pushed along, the rear wheels drive the differential between them, so they can turn at di… | works | partly | the gear reading; still: p76 73071 |
| 8850-1 | 3 | As the truck rolls, the V6 engine runs: a 14 tooth bevel gear on the long prop shaft mesh… | partly | partly | the gear reading; still: p21 3708, p264 4019, p240 2853 |
| 8850-1 | 4 | The axle sticking out of the back of the chassis turns as the truck rolls: its 8 tooth ge… | partly | partly | the gear reading; still: p94 3737 |
| 8850-1 | 5 | The front wheels roll freely on their stub axles. | works | no | p342 4266: Simulate has no joint it turns on (floating) p348 4266: Simulate has no joint it turns on (floatin… |
| 8850-1 | 6 | The front bar, an axle held in two toggle joints on short yellow liftarms at the ends of … | partly | partly | a drag's loop; the gear reading; still: p139 2825, p189 3708 |
| 8850-1 | 7 | The grey pulley wheel on the side of the engine turns freely on its pin. | works | works | the gear reading |
| 8850-1 | 8 | The cab and roll cage hold their shape: the two sloping beams on the cab sides, running f… | not checked | not checked |  |
| 8851-1 | 1 | Pump with the red hand pump and push the valve at the left of the cab's back to the side,… | no | no | p17 8851-4694c01-f1 is part of the frame (#18 4694, a stud in its socket, #16 3701; #16 3701, two joints on t…; still: p1038 3703, p261 337, p1034 3703 |
| 8851-1 | 2 | The middle valve works the cylinder on top of the boom, which swings the stick in and out… | no | no | p256 8851-4694c01-f1 is part of the frame (#259 4694, a stud in its socket, #258 3701; #258 3701, two joints …; still: p1034 3703, p1047 337, p1070 4700 |
| 8851-1 | 3 | The valve at the right of the cab's back works the cylinder on the stick, which curls the… | no | no | p542 8851-4694c01-f1 is part of the frame (#547 4694, a stud in its socket, #550 3701; #550 3701, two joints …; still: p1070 4700, p1058 337, p1062 4263 |
| 8851-1 | 4 | The hand pump: pushing the red plunger down blows air through the valves, and its spring … | skipped | skipped |  |
| 8851-1 | 5 | The cab and arm slew round on the turntable above the tracks. | partly | no | p852 3738 is part of the frame (#859 3738, a stud in its socket, #863 3894; #863 3894, a stud in its socket, …; still: p906 3403 |
| 8851-1 | 6 | The tracks roll freely round the 40-tooth sprockets and the 16-tooth idlers; nothing driv… | works | works | the gear reading |
| 8854-1 | 1 | The yellow beacon on the cab roof steers the front wheels: it caps a shaft that runs down… | works | partly | the gear reading; still: p59 3743, p28 4261, p29 4261 |
| 8854-1 | 2 | The handwheel low on the chassis's left side slews the superstructure round on its turnta… | partly | partly | the gear reading; still: p533 3709b |
| 8854-1 | 3 | The handwheel low on the chassis's right side lowers and raises both rear stabiliser legs… | works | works | the gear reading |
| 8854-1 | 4 | Each stabiliser leg's foot, two pulley wheels on toothed toggle joints, tilts to sit flat… | works | no | the gear reading; p169 4185: locked: the couplings ask for two different turns at once p178 4185: locked: the couplings ask for… |
| 8854-1 | 5 | Either handwheel at the back of the superstructure winds the winch, raising or lowering t… | partly | partly | the gear reading; still: p951 70644 |
| 8854-1 | 6 | A ratchet holds the hook up: a pawl on a toothed toggle joint rests on the 24-tooth gear … | skipped | skipped |  |
| 8854-1 | 7 | The handwheel at the boom's pivot, on the right, extends and retracts the boom's grey inn… | partly | works | the gear reading |
| 8854-1 | 8 | The two pneumatic cylinders behind the cab raise and lower the boom: their piston rods sl… | partly | no | the gear reading; p811 3709b: locked: the couplings ask for two different turns at once; still: p694 2796c01, p697 2796c01, p692 2793 |
| 8854-1 | 9 | Pumping the spring-loaded pump on the chassis, with the valve lever on the superstructure… | skipped | skipped |  |
| 8854-1 | 10 | The four wheels roll freely; nothing drives them. | works | works | the gear reading |
| 8854-1 | 11 | The hook hangs straight down beneath the boom tip as the superstructure slews, the boom l… | not checked | not checked |  |
| 8855-1 | 1 | The propeller turns the engine's piston: the propeller's 24-tooth gear and the engine's 2… | no | no | p428 8855-2742c01 is part of the frame (#429 3701, a stud in its socket, #88 3666; #88 3666, a stud in its so…; still: p90 3648a, p91 3705, p95 3652 |
| 8855-1 | 2 | Tipping the control stick forward and back tilts the tail's elevators: under the cockpit … | partly | partly | the gear reading; still: p347 3707, p369 3708, p371 3705 |
| 8855-1 | 3 | Tipping the control stick side to side works the ailerons near the wing tips, one up as t… | partly | partly | the gear reading; still: p154 3706, p336 2712, p530 3706 |
| 8855-1 | 4 | The four small wheels set into the pontoons roll freely, so the seaplane can roll on land. | works | works | the gear reading |
| 8856-1 | 1 | The big white handwheel on the right side spins the main rotor through a bevel gear at th… | works | partly | the gear reading; still: p460 2906, p372 3707, p490 2711 |
| 8856-1 | 2 | The small crank low on the right side retracts and lowers the landing gear: a worm turns … | partly | works | the gear reading |
| 8856-1 | 3 | The small crank low on the left side winds the winch: a 16-tooth gear and a bevel pair tu… | partly | partly | the gear reading; still: p468 70278 |
| 8856-1 | 4 | The small crank high on the left side swings the black hoist arm, with the hook hanging f… | partly | partly | the gear reading; still: p242 3705, p256 3705, p408 2738 |
| 8856-1 | 5 | Pushing the control stick in the cockpit forward or back tilts the main rotor forward or … | partly | partly | the gear reading; still: p38 2736, p375 2825, p373 2738 |
| 8856-1 | 6 | Pushing the control stick left or right tilts the main rotor sideways: the stick turns th… | partly | partly | the gear reading; still: p11 3705, p27 2736, p462 2908 |
| 8856-1 | 7 | A pawl rests on the winch crank's 16-tooth gear, so the hook stays where it is wound to. | skipped | skipped |  |
| 8856-1 | 8 | The three landing gear wheels roll freely. | works | works | the gear reading |
| 8859-1 | 1 | The steering wheel steers the front wheels: its column runs forward through two universal… | partly | partly | the gear reading; still: p250 3648a, p95 3743, p37 4261 |
| 8859-1 | 2 | Rolling the tractor runs the engine: the rear wheels turn the differential, a 14-tooth be… | partly | partly | a drag on its joint; still: p7 4143, p411 3648a, p416 3648a |
| 8859-1 | 3 | The differential lets the two rear wheels turn at different speeds in a corner. | partly | works | a drag on its joint |
| 8859-1 | 4 | The lever by the seat raises and lowers the three-point hitch and the cultivator on it: i… | partly | partly | the gear reading; still: p488 3648a, p109 3647, p283 3743 |
| 8859-1 | 5 | The front wheels turn freely on short axles in the steering arms. | partly | works | a drag on its joint |
| 8859-1 | 6 | The cultivator's four tines are held down by rubber bands and spring back when they hit s… | skipped | skipped |  |
| 8859-1 | 7 | The cab frame, its sloping front legs, the bonnet and the exhaust stack stay rigid on the… | not checked | not checked |  |
| 8862-1 | 1 | The round yellow knob on the cab roof steers the front wheels: its shaft runs down throug… | works | partly | a drag's loop; still: p368 3743, p360 4261, p370 4261 |
| 8862-1 | 2 | The handwheel low on the right, in front of the cab, raises and lowers the loader arms: a… | partly | works | the gear reading |
| 8862-1 | 3 | The handwheel low on the left, in front of the cab, tips the loader bucket: a bevel pair … | partly | works | the gear reading |
| 8862-1 | 4 | The handwheel high in the cab on the right swings both outriggers out and down together: … | works | works | the gear reading |
| 8862-1 | 5 | Each outrigger's foot tilts on toothed toggle joints to sit flat on the ground. | works | no | the gear reading; p159 3701: locked: the couplings ask for two different turns at once p178 3701: locked: the couplings ask for… |
| 8862-1 | 6 | The handwheel high in the cab on the left slews the backhoe: its shaft runs down to a bev… | works | no | the gear reading; p572 3736: locked: the couplings ask for two different turns at once; still: p224 3404, p264 3702 |
| 8862-1 | 7 | The cylinder on the turntable raises and lowers the backhoe's boom. | works | works | a drag's loop |
| 8862-1 | 8 | The cylinder along the top of the boom swings the dipper arm in and out. | works | works | a drag's loop |
| 8862-1 | 9 | The cylinder on the dipper arm curls and opens the backhoe bucket through a short linkage. | works | works | the gear reading and 1 loop it turns |
| 8862-1 | 10 | Pumping the pump, whose knob stands up through the bonnet, with one of the three valves a… | skipped | skipped |  |
| 8862-1 | 11 | The bonnet over the pump lifts on the axle along its back edge. | works | works | the gear reading |
| 8862-1 | 12 | The four wheels roll freely; nothing drives them. | works | works | the gear reading |
| 8865-1 | 1 | The steering wheel on the left steers the front wheels: its column, through two universal… | works | partly | the gear reading; still: p287 3743, p423 2737, p424 2737 |
| 8865-1 | 2 | Pushing the car along turns the V4 engine: the rear wheels drive the differential, whose … | works | no | the gear reading; p900 3739: locked: the couplings ask for two different turns at once; still: p904 3739, p149 73071, p175 3706 |
| 8865-1 | 3 | The blue-knobbed gear lever between the seats picks one of three speeds: moving it fore a… | partly | partly | the gear reading; still: p400 3707, p406 3708, p408 4019 |
| 8865-1 | 4 | The differential lets the rear wheels turn at different speeds in a bend: with the engine… | partly | no | the gear reading; p900 3739: locked: the couplings ask for two different turns at once; still: p904 3739, p150 4143 |
| 8865-1 | 5 | The front wheels have independent suspension: each rides on two grey suspension arms, upp… | works | no | a drag's loop |
| 8865-1 | 6 | The rear wheels have independent suspension: each rides on an upright held between two wi… | works | no | a drag's loop |
| 8865-1 | 7 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 8865-1 | 8 | The 16-tooth gear outside the left seat slides that seat fore and aft: its axle's 8-tooth… | no | works | a drag's loop |
| 8865-1 | 9 | The 16-tooth gear outside the right seat slides that seat fore and aft, as on the left. | no | works | a drag's loop |
| 8865-1 | 10 | Each seat's backrest reclines on its hinge plates, and the headrest tilts on its own hing… | works | no | p840 3036: Simulate has no joint it turns on (floating) p863 3036: Simulate has no joint it turns on (floatin… |
| 8865-1 | 11 | The red-knobbed lever left of the gear lever raises the pop-up headlights: it turns a lon… | partly | partly | a drag on its joint; still: p114 3708, p471 3737, p472 3737 |
| 8868-1 | 1 | The 9V motor, switched at the battery box on the cab roof, runs the compressor: a rubber … | no | partly | a drag's loop; still: p2721 74982-f1 |
| 8868-1 | 2 | The knob on the cab roof steers the front wheels: its upright shaft, through a universal … | works | partly | the gear reading; still: p75 4261, p80 4261, p132 3743 |
| 8868-1 | 3 | The two front wheels roll freely on the steering arms. | works | works | the gear reading |
| 8868-1 | 4 | Rolling the truck runs the six-piston engine in the nose: both rear axles have differenti… | works | partly | the gear reading; still: p27 3707, p1975 4185a, p2898 2853 |
| 8868-1 | 5 | The rear valve on the cab's left side slews the crane: two cylinders lying lengthwise in … | no | no | p1952 4694c01-f1 is part of the frame (#1953 4694c01-f1, a stud in its socket, #1961 3700; #1961 3700, a stud…; still: p2045 2855, p2420 2717, p1409 2796c01 |
| 8868-1 | 6 | The front valve on the cab's left side raises and lowers the big arm: a cylinder from the… | no | no | p1951 4694c01-f1 is part of the frame (#1952 4694c01-f1, a stud in its socket, #1960 3700; #1960 3700, two jo…; still: p2459 4519, p2185 2796c01 |
| 8868-1 | 7 | The rear valve on the cab's right side raises and lowers the front arm: a cylinder along … | no | no | p1950 4694c01-f1 is part of the frame (#1951 4694c01-f1, a stud in its socket, #1962 3700; #1962 3700, a stud…; still: p2831 4519, p2744 2796c01 |
| 8868-1 | 8 | The front valve on the cab's right side opens and closes the claw: a small cylinder in th… | no | no | p1949 4694c01-f1 is part of the frame (#1950 4694c01-f1, a stud in its socket, #1958 3700; #1958 3700, two jo…; still: p3240 2825, p3264 2825, p3206 2944c01 |
| 8868-1 | 9 | The claw head hangs on an axle at the tip of the front arm, so it swings to hang straight… | skipped | skipped |  |
| 8868-1 | 10 | The fuel tanks, exhaust stacks and roof horns stay fixed to the truck whatever is turned. | not checked | not checked |  |
| 8880-1 | 1 | Pushed along, all four wheels drive together through three differentials (one between the… | works | partly | the gear reading; still: p14 6573, p302 6573, p320 6573 |
| 8880-1 | 2 | In gear, the car rolling runs the V8: the gearbox's output shaft drives the crankshaft by… | works | partly | the gear reading; still: p750 2853, p753 2852, p767 2851 |
| 8880-1 | 3 | The gear lever moves in an H gate with four slots: tilted into each, its foot slides one … | no | no | p595 6549: Simulate has no joint it turns on (floating); still: p240 6539 |
| 8880-1 | 4 | The steering wheel steers all four wheels: its column turns through crown gears and unive… | works | no | the gear reading; p894 2741: locked: the couplings ask for two different turns at once; still: p429 6540b, p438 6540b, p432 6540b |
| 8880-1 | 5 | The knob on top behind the cockpit, a small tyre on an upright axle, steers the car as th… | works | no | the gear reading; p925 3482: locked: the couplings ask for two different turns at once; still: p429 6540b, p438 6540b, p894 2741 |
| 8880-1 | 6 | The headlights pop up: the small knob on the centre console, just in front of the gear le… | works | works | a drag's loop |
| 8880-1 | 7 | The front wheels each have independent suspension: the steering arm rides between a lower… | no | works | a drag's loop |
| 8880-1 | 8 | The rear wheels have the same independent suspension as the front ones. | no | works | a drag's loop |
| 8880-1 | 9 | The shock absorbers' springs hold the car up and spring back. | skipped | skipped |  |
| 8880-1 | 10 | The whole rear body, from the roof back to the tail, lifts as one hatch on two axles behi… | no | partly | the gear reading and 1 loop it turns |
| 8880-1 | 11 | A prop rod with a toggle joint, pinned to the chassis on the right of the engine, folds u… | skipped | skipped |  |
| 8880-1 | 12 | The two seat backs tilt on their finger hinges. | no | no | p1092 3031: Simulate has no joint it turns on (floating) p1126 3031: Simulate has no joint it turns on (float… |
| 8880-1 | 13 | Turned by hand at its fan, with the gear lever in neutral, the V8 runs on its own and the… | works | works | a drag's loop |
| 9390-1 | 1 | The black gear on top behind the cab is a steering knob: it turns an upright axle whose a… | works | works | a drag's loop |
| 9390-1 | 2 | The black gear on the left of the red boom winds the winch: its axle carries the reel, wh… | works | partly | the gear reading; still: p92 61510 |
| 9390-1 | 3 | A small gear on a friction axle pin on the boom's right meshes with the gear on the winch… | skipped | skipped |  |
| 9390-1 | 4 | The red boom is fixed to the back of the frame; it doesn't luff or slew. | not checked | not checked |  |
| 9390-1 | 5 | The rear wheels roll freely on their axle. | works | works | the gear reading |
| 9391-1 | 1 | The black gear at the back end of the undercarriage slews the crane: its long axle runs u… | works | no | p31 32270: Simulate has no joint it turns on (floating); still: p4 99010, p78 32140, p116 32062 |
| 9391-1 | 2 | The black gear at the top back of the upper works raises and lowers the boom: it turns a … | works | works | the gear reading |
| 9391-1 | 3 | The black gear on the left side at the back of the upper works winds the winch, raising o… | works | partly | the gear reading; still: p121 30395 |
| 9391-1 | 4 | A small gear on a friction axle pin meshes with the gear on the winch axle, so the winch … | skipped | skipped |  |
| 9391-1 | 5 | The two tracks run round their sprockets and idlers, so the crane rolls along; nothing dr… | works | works | the gear reading |
| 9392-1 | 1 | Turning the handlebars steers the front wheels: the steering column turns an arm at its f… | no | no | the gear reading; p194 32016: locked: the couplings ask for two different turns at once; still: p121 32209, p114 2739a, p107 6571 |
| 9392-1 | 2 | Rolling the quad works the engine: the rear axle's sprocket drives a chain forward to a c… | partly | partly | the gear reading; still: p146 94925, p137 2853, p140 2851 |
| 9392-1 | 3 | The engine can also be turned from its crankshaft, turning the rear wheels through the ge… | partly | partly | a drag's loop; still: p17 94925, p182 56145 |
| 9392-1 | 4 | The rear wheels ride on a swinging arm with a single shock absorber: pushing the rear axl… | no | no | the gear reading; p22 32140: locked: the couplings ask for two different turns at once; still: p13 3737, p182 56145 |
| 9392-1 | 5 | The front wheels have independent suspension: each hub rides between an upper and a lower… | no | no | the gear reading; p95 6572: locked: the couplings ask for two different turns at once p99 6572: locked: the couplings ask for t…; still: p106 6572, p104 6572, p107 6571 |
| 9392-1 | 6 | The three shock absorbers' springs hold the quad up and spring back. | skipped | skipped |  |
| 9393-1 | 1 | The black gear on the cab roof steers the front wheels: its upright axle comes down throu… | works | no | the gear reading; p72 32270: locked: the couplings ask for two different turns at once; still: p8 3705, p31 87761, p25 48989 |
| 9393-1 | 2 | The grey smooth axle joiner standing up behind the cab lifts the three-point linkage: it … | works | no | the gear reading; p132 59443: locked: the couplings ask for two different turns at once; still: p130 4716, p149 3647, p145 2736 |
| 9393-1 | 3 | Rolling the tractor spins the hay tedder's two rotors: the right rear wheel's axle turns … | works | partly | the gear reading; still: p328 6589, p337 3648b, p305 3648b |
| 9393-1 | 4 | The left rear wheel turns on its own short axle, so only the right one drives the tedder. | partly | works | the gear reading |
| 9393-1 | 5 | The tedder's two arms fold up over it for transport, each swinging its rotor up on a pivo… | partly | no | the gear reading; p299 48989: locked: the couplings ask for two different turns at once p309 48989: locked: the couplings ask f…; still: p301 6587, p311 6587 |
| 9393-1 | 6 | The small steering wheel in the cab turns freely on its pin; it doesn't steer. | works | works | the gear reading |
| 9394-1 | 1 | Turning the round exhaust nozzle at the tail sweeps both wings back and forward together:… | works | partly | a drag's loop; still: p85 4716, p281 3648b, p157 64781 |
| 9394-1 | 2 | The smooth grey axle joiner low on the fuselage's left side raises and lowers the landing… | partly | partly | the gear reading; still: p55 2825, p57 42610 |
| 9394-1 | 3 | The black gear on the spine behind the cockpit opens the canopy: it turns a worm, which t… | partly | works | the gear reading |
| 9394-1 | 4 | Moving the control stick in the cockpit forward and back tilts the two tailplanes: rods a… | works | partly | a drag's loop; still: p308 32278, p244 60485, p541 64392 |
| 9394-1 | 5 | The three landing gear wheels roll freely. | works | works | the gear reading |
| 9395-1 | 1 | The black gear on the cab roof steers the front wheels: its upright axle comes down to a … | works | works | a drag's loop |
| 9395-1 | 2 | Rolling the truck turns the engine at the front: the rear wheels drive the differential, … | works | partly | a drag's loop; still: p7 32269, p187 94925, p306 94925 |
| 9395-1 | 3 | The red lever beside the seats is a gear selector: it slides a driving ring on the gearbo… | no | partly | a drag's loop; still: p60 6539 |
| 9395-1 | 4 | With the selector set for the winch, the black gear on the side behind the cab winds the … | partly | partly | a drag's loop; p612 2825, worked first, went 0.04 of 0.3; still: p55 32072, p58 6542b, p374 94925 |
| 9395-1 | 5 | With the selector set for the boom, the same side gear raises or lowers the boom with its… | partly | partly | a drag's loop; p612 2825, worked first, went -0.05 of -0.3; still: p62 6542b, p438 94925, p441 4716 |
| 9395-1 | 6 | The small grey steering wheel in the cab is fixed; it doesn't steer. | not checked | not checked |  |
| 9395-1 | 7 | The four wheels roll freely, the rear ones turning the engine as they go; the front ones … | works | works | the gear reading; a drag's loop |
| 9396-1 | 1 | One knob on the fuselage's side works everything through a gearbox; two selector levers, … | partly | partly | the gear reading and 1 loop it turns; p1425 6553, worked first, went 0.09 of 0.3; still: p1510 99013p01, p1088 32270, p1337 55013 |
| 9396-1 | 2 | With the same lever the other way (toward the landing-gear symbol), the knob retracts and… | partly | partly | the gear reading and 1 loop it turns; p1425 6553, worked first, went -0.09 of -0.3; still: p449 92695, p437 92695, p1198 42610 |
| 9396-1 | 3 | With the other lever toward the hoist symbol, the knob winds the rescue winch above the s… | partly | partly | the gear reading and 1 loop it turns; p1428 6553, worked first, went 0.09 of 0.3; still: p570 32073, p575 30395 |
| 9396-1 | 4 | With the other lever toward the helicopter symbol, the knob opens and closes the rear loa… | partly | partly | the gear reading and 1 loop it turns; p1428 6553, worked first, went -0.09 of -0.3; still: p1278 41239, p1399 41239 |
| 9396-1 | 5 | The main rotor's four blades fold back on their hinges for parking, released by a blue le… | no | works | the gear reading |
| 9396-1 | 6 | The wheels roll freely when the landing gear is down. | works | works | the gear reading |
| 9397-1 | 1 | A Power Functions M motor in the chassis, switched on and reversed with the orange switch… | works | works | the gear reading and 1 loop it turns |
| 9397-1 | 2 | With one lever to one side, the motor lowers and raises the outrigger legs behind the cab… | partly | partly | the gear reading and 1 loop it turns; p217 3749, worked first, went 0.0 of 20.0; still: p464 92695 |
| 9397-1 | 3 | With the same lever the other way, the motor slews the crane round on its mast through a … | partly | partly | the gear reading and 1 loop it turns; p217 3749, worked first, went -1.0 of -20.0; still: p534 4716, p528 32140 |
| 9397-1 | 4 | With the other lever to one side, the motor raises and lowers the crane's main boom by sp… | partly | partly | the gear reading and 1 loop it turns; p221 3749, worked first, went -1.0 of -20.0; still: p624 62274c01 |
| 9397-1 | 5 | With the other lever the other way, the motor folds the crane's outer arm (the yellow jib… | works | works | the gear reading and 1 loop it turns |
| 9397-1 | 6 | The log grab at the jib tip opens and closes by hand, by turning a gear on top of it, and… | not checked | not checked |  |
| 9397-1 | 7 | The front wheels steer from a knob on top of the cab (hand of god): its upright shaft tur… | partly | works | a drag's loop |
| 9397-1 | 8 | Rolling the truck turns the engine: the two rear axles' differential drives a shaft forwa… | partly | partly | the gear reading; still: p778 2853, p779 2852 |
| 9397-1 | 9 | All six wheels roll; the front pair steer. | works | works | the gear reading |
| 950-1 | 1 | The handwheel on the mast's left side raises and lowers the forks: the axle across the to… | works | works | the gear reading |
| 950-1 | 2 | The steering wheel steers the back wheels: its upright axle turns a crown gear, which dri… | works | works | a drag's loop |
| 950-1 | 3 | The four wheels roll freely; the front pair are on short axles of their own. | works | works | the gear reading |
| 950-1 | 4 | The two levers beside the seat tip fore and aft on their pins, as the driver's controls; … | works | works | the gear reading |
| 952-1 | 1 | The steering wheel turns the front wheels: its column bends through a universal joint dow… | works | partly | a drag's loop; still: p247 3482, p248 3482, p163 3743 |
| 952-1 | 2 | The big rear wheels drive the power take-off: a crown gear on the right half axle turns a… | works | partly | a drag on its joint; moved: p235 3702, p37 3702 |
| 952-1 | 3 | Pushed along, the front wheels roll freely, and the hitch and its lever stay where they w… | partly | works | the gear reading |
| 952-1 | 4 | The lever on the right beside the seat raises and lowers the hitch: a short link from it … | works | partly | a drag's loop; moved: p251 952-3739c01 |
| 952-1 | 5 | Lowered by the lever until it rests on its two small wheels, the harrow's top 40 tooth ge… | partly | partly | a drag on its joint; p235 3702, worked first, went -0.23 of -1.39 p305 3649 is not where Kinebrick reads it p300 3649 is not where…; still: p305 3649, p300 3649, p310 3649 |
| 952-1 | 6 | Inside the harrow, the top 40 tooth gear drives the middle rotor's 8 tooth gear five time… | works | works | the gear reading |
| 952-1 | 7 | The harrow's two small wheels roll freely. | works | partly | a drag on its joint |
| 956-1 | 1 | The steering wheel turns the front wheels: its column bends through a double universal jo… | works | partly | the gear reading; still: p342 3739, p340 3739, p295 3743 |
| 956-1 | 2 | As it rolls, the rear axle runs the four-cylinder engine: the rear axle's 24 tooth gear t… | works | partly | a drag's loop; still: p571 3652, p577 3652, p583 3652; moved: p559 3705 |
| 956-1 | 3 | Pushed along, the front wheels roll freely on their own axles. | works | works | the gear reading |
| 956-1 | 4 | The gear lever standing up behind the engine slides the engine's input shaft back and for… | partly | partly | the gear reading; still: p555 3737 |
| 956-1 | 5 | The 24 tooth gear on the right side of the chassis slides the right front seat forward an… | works | partly | the gear reading; still: p143 3031 |
| 956-1 | 6 | The 24 tooth gear on the left side of the chassis slides the left (driver's) front seat f… | works | partly | the gear reading; still: p148 3031 |
| 956-1 | 7 | The rear seat's centre armrest, two Technic bricks pinned between its backs, folds up int… | works | works | the gear reading |
