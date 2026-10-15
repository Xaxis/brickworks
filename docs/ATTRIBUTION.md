# Attribution and licensing of source data

This project renders geometry it did not author. The terms below are
obligations, not courtesies: they must appear in the application's about
screen and in any distributed build.

## LDraw Parts Library

All part geometry derives from the LDraw Parts Library.

- Every file in the library carries `0 !LICENSE Licensed under CC BY 4.0`
  or `CC BY 2.0 and CC BY 4.0`. Verified across all 24,735 files in
  `parts/` as of the 2025-05 release: 23,244 CC BY 4.0, 1,491 dual.
- CC BY permits commercial use and derivative works — which is what a
  converted mesh is — provided attribution is given.
- Required notice:

  > This application uses the LDraw™ Parts Library, © the LDraw community,
  > licensed under CC BY 2.0 (https://creativecommons.org/licenses/by/2.0/)
  > and CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
  > LDraw™ is a trademark owned and licensed by the Estate of James
  > Jessiman. This application is not affiliated with or endorsed by
  > LDraw.org.

- Source: https://library.ldraw.org/
- Eleven of the library's primitives are copied unchanged into
  `assets/ldraw/` and ship in every build — `stud`, `stud3`, `stud4`,
  `box4`, `box5`, `4-4cyli`, `4-4disc`, `4-4edge`, `4-4ndis`, `4-4ring3` and
  `peghole`, authored by
  James Jessiman (each file names him), CC BY 4.0 — because the element
  maker (`src/parts/element_maker.gd`) draws every part it makes from them
  and the app has to build those parts where the library is not to hand.
  A part the maker writes is an unofficial part, not a library one: its
  header names the maker as its author, and LDraw's own `u` and `t`
  numbers are assigned by the Parts Library admin, so it uses none.

## BrickNet's connector labels and colliders

The build check reads each part's exact shape and connectors from
`assets/generated/exact/<hash>.bwx` (`src/assembly/exact.gd`), which
`tools/build_exact.py` converts from two things BrickNet publishes:

- its connector labels (`labels.json.xz`, `part_names.json`,
  `part_aliases.json.xz`), part of the `bricknet` Python package, MIT:
  "Copyright (c) 2026 Peter Kulits", whose notice and permission must go
  with any copy (https://github.com/kulits/BrickNet);
- its convex colliders, the per-part `.cvx.obj` files `python -m bricknet
  fetch-meshes` downloads, which are decompositions of LDraw parts and so
  derive from the LDraw Parts Library (CC BY, above) as our meshes do.

Neither is committed: like the meshes, the converted files are built into
`assets/generated/` and shipped in builds. Required notice, beside the
LDraw one:

  > Part colliders and connector labels from BrickNet (Kulits and Schmid,
  > 2026), MIT License, Copyright (c) 2026 Peter Kulits.

## LDraw Official Model Repository

Some of the worked constructions the assistant can look up
(`src/ai/techniques.gd`) are sub-models of real sets as modelled in
LDraw's Official Model Repository (https://library.ldraw.org/omr), read
into this app's coordinates, or groups of parts cut from inside them.
Those files carry `0 !LICENSE Redistributable under CCAL version 2.0`,
which is CC BY 2.0, or `Licenced under CC BY 4.0` (10359 Fountain
Garden); files marked "free for non-commercial use" were left out. Each
technique names its set and modeller in its own text, and here:

- `lamp post`: 4886 Building Bonanza, modelled by Robert Paciorek, CC BY 2.0.
- `tree`: 4956 House, modelled by Marc Giraudet, CC BY 2.0.
- `bed`: 10297 Boutique Hotel, modelled by Philippe Hurbain, CC BY 2.0.
- `bench`: 2150 Train Station, modelled by Robert Paciorek, CC BY 2.0.
- `armchair`: 10246 Detective’s Office, modelled by Willy Tschager, CC BY 2.0.
- `table`: 31025 Mountain Hut, modelled by Stefan Frenz, CC BY 2.0.
- `planter`: 4956 House, modelled by Marc Giraudet, CC BY 2.0.
- `chimney`: 10182 Cafe Corner, modelled by Max Martin Richter, CC BY 2.0.
- `fence`: 3189 Heartlake Stables, modelled by Takeshi Takahashi, CC BY 2.0.
- `rough stone wall`, `cobbled path`, `log pile`: 21325 Medieval Blacksmith, modelled by Vincent Messenet, CC BY 2.0.
- `weathered stone wall`: 9471 Uruk-hai Army, modelled by Philippe Hurbain, CC BY 2.0.
- `corbelled wall walk`, `postern arch`: 6080 King's Castle, modelled by Stefan Frenz, CC BY 2.0.
- `oversail on inverted slopes`: 10176 Royal King's Castle, modelled by Marc Giraudet, CC BY 2.0.
- `stone corbel`: 7327 Scorpion Pyramid, modelled by Christian Neumann, CC BY 2.0.
- `balustrade`, `clipped hedge`: 10359 Fountain Garden, modelled by Orion Pobursky, CC BY 4.0.
- `embossed brick wall`: 75980 Attack on The Burrow, modelled by Stefan Frenz, CC BY 2.0.
- `columns with capitals`, `striped awning`, `staircase`: 10278 Police Station, modelled by Philippe Hurbain, CC BY 2.0.
- `stone column`: 4954 Model Town House, modelled by Marc Giraudet, CC BY 2.0.
- `turned wooden pillar`: 10182 Cafe Corner, modelled by Max Martin Richter, CC BY 2.0.
- `corner on a turntable`: 10182 Cafe Corner (the corner entrance's steps, turned 45 degrees on its turntable), modelled by Max Martin Richter, CC BY 2.0.
- `turret spire`: 75969 Hogwarts Astronomy Tower, modelled by Stefan Frenz, CC BY 2.0.
- `roof ridge`: 75954 Hogwarts Great Hall, modelled by Stefan Frenz, CC BY 2.0.
- `arched window`, `bookcase`: 10270 Bookshop, modelled by Ulrich Röder, CC BY 2.0.
- `window with shutters`, `dresser`: 10243 Parisian Restaurant, modelled by Willy Tschager, CC BY 2.0.
- `rock outcrop`, `anvil`: 9476 The Orc Forge, modelled by Philippe Hurbain, CC BY 2.0.
- `rocky ground with plants`: 6066 Camouflaged Outpost, modelled by Takeshi Takahashi, CC BY 2.0.
- `stone with ivy`: 6071 Forestmen's Crossing, modelled by Takeshi Takahashi, CC BY 2.0.
- `hedge with flowers`, `sofa`: 10297 Boutique Hotel, modelled by Philippe Hurbain, CC BY 2.0.
- `leafy plant`, `fireplace`, `wall lantern`, `campfire`: 5766 Log Cabin, modelled by Marc Giraudet, CC BY 2.0.
- `flower bed`: 5891 Apple Tree House, modelled by Marc Giraudet, CC BY 2.0.
- `curved skin panel`, `studs-out core`, `grille band`, `cone bell on round plates`, `round tip`, `fin root on a Technic pin`: 21309 NASA Apollo Saturn V, modelled by Jaco van der Molen, CC BY 2.0.
- `hearth`: 30210 Frodo with Cooking Corner, modelled by Stan Isachenko, CC BY 2.0.
- `chest`: 10267 Gingerbread House, modelled by Orion Pobursky, CC BY 2.0.
- `potion shelf`: 75953 Hogwarts Whomping Willow, modelled by Stefan Frenz, CC BY 2.0.
- `four-poster bed`: 21318 Tree House, modelled by Orion Pobursky, CC BY 2.0.
- `hanging lamp`: 10246 Detective’s Office, modelled by Willy Tschager, CC BY 2.0.
- `bedside lamp`: 75948 Hogwarts Clock Tower, modelled by Stefan Frenz, CC BY 2.0.

### The real-set index

`find_techniques` and `place_technique` search and lay pieces from
`assets/knowledge/snippets.json.gz` (`tools/snippets.py`): named
sub-models and clusters of parts from the same repository, read as LDraw
lines. Every piece carries its set, its modeller and its licence, and both
tools say them wherever a piece is shown or laid. Only files under CC BY
2.0 (`Redistributable under CCAL version 2.0`) or CC BY 4.0 are in it;
files free for non-commercial use only, and share-alike ones, are left out.
Each piece's one-line description was written for this project by Claude
from a picture of it. 12967 pieces from 1185 sets by 76 modellers; 12880 CC BY 2.0, 87 CC BY 4.0. By modeller, with the sets
(`tools/snippets.py credits` prints this list from the index):

- Adrien Pennamen: 75892, 76897
- Allard van Efferen (rabbitdesign.nl): 851, 852, 8844, 8848, 8859
- Antony Lodge: 6010
- Bert Van Raemdonck: 10183
- Bruno Altmann: 1572
- Casey Puyleart: 6825
- Charles Farmer: 8022, 8032, 8062
- Charles the Farmer: 8032
- Chris Böhnke: 6043, 6056, 6516
- Christian Maglekær: 40141, 40142, 40143, 40144, 40180, 40181, 40182, 40183
- Christian Neumann: 30091, 7306, 7325, 7326, 7327, 9470
- Christophe Mitillo: 21303, 70816
- Damien Roux: 1478, 1479, 1620, 1621, 1704, 1787, 1789, 1793, 1875, 1887, 1969, 1974-4, 21003, 21006, 21007, 21012, 21014, 21017, 21018, 21019, 21020, 21021, 21022, 21023, 21024, 21026, 21027, 21028, 21029, 21030, 21031, 21032, 21033, 21034, 41485, 41486, 41490, 41491, 41492, 41493, 41496, 41497, 41498, 41585, 41586, 41587, 41588, 41589, 41590, 41591, 41592, 41593, 41594, 41595, 41596, 6770, 6781, 6810, 6828, 6830, 6831, 6832, 6833, 6834, 6835, 6848, 6850, 6851, 6852, 6861-2, 6862, 6875, 6876, 6877, 6878, 6879, 6884, 6885, 6886, 6887, 6889, 6893, 6894, 6895, 6896, 6897, 6898, 6923, 6925, 6932, 6939, 6941, 6949, 6953, 6954, 6955, 6956, 6957, 6959, 6973, 6981, 6983, 6984, 6986, 6987, 6988, 6989, 6990
- Daniel Goerner: 7101, 7110, 7111, 7121, 7128, 7130, 7131, 7140, 7141, 7150
- Darats: 6933
- EdmanZA: 10213
- Eisner Johann: 42073, 4347
- Evert Jan Boer: 75053, 7657
- Evert-Jan Boer: 4487, 4489, 4492, 4494, 4495, 6965, 6966, 71200
- Faramond Florent: 10018, 42020, 42021, 42022, 42023
- Florian Schüller: 8832
- folkoluck: 75075
- Greg Teft: 21013
- Ignacio Fernandez Galvan: 6780, 6827, 6891, 6951, 8841, 8855
- Iván Sánchez Ortega: 6361, 6594, 6644
- Jaco van der Molen: 10264, 21309, 75276, 8204, 8209, 8217, 8218
- Javier Orquera: 6991
- Jens Brühl: 10294, 42115
- Johann Eisner: 42084, 4488, 4490, 4491, 4493, 5864, 6054, 6741, 6742, 6911, 6967, 7601, 7602, 7603, 7803, 7808
- Jude Parrill: 10143, 20019, 20021, 30050, 30051, 30052, 30053, 30054, 30055, 8028, 8029, 8031, 8033
- juraj3579: 4439, 4641, 4888
- Ken Drew: 20006, 20009, 20011, 20014, 20015, 4347, 4348, 4349, 4837, 4838, 4915, 4918, 5762, 7223, 7875
- Lasse Deleuran: 30542, 30571, 40396
- LDCad: 41999
- Magnus Forsberg: 10242, 10248, 10271, 41630, 75870, 75878, 75893, 75895, 8143, 8156, 8169
- Makou: 42024
- Marc Belanger: 30572, 31049, 31072, 31088, 31092, 42088
- Marc Giraudet: 10124, 10176, 10184, 10224, 10233, 10265, 30472, 31031, 31038, 3178, 3179, 3181, 3221, 345, 346-2, 40335, 40386, 40391, 40428, 40431, 40456, 40457, 4096, 4200, 42029, 42032, 4206-2, 4404, 4433, 4434, 4436, 4643, 4883, 4886, 4896, 4911, 4914, 4917, 4937, 4939, 4953, 4954, 4955, 4956, 4991, 4993, 4996, 5533, 5766, 5865, 5866, 5891, 5893, 60017, 60018, 60059, 6522, 6743, 6745, 6747, 6753, 689, 7242, 7248, 7347, 76042, 7630, 7631, 7632, 7634, 7635, 7636, 7637, 7638, 7639, 7641, 7685, 7732, 7733, 7736, 7737, 7741, 7743, 7746, 7747, 7784, 7903, 7936, 7942, 7990, 7991, 7992, 7997, 8081, 8270, 8281, 8283, 8289, 8416, 8418, 8419
- Massimo Maso: 30033, 30034, 30035, 30161, 30190, 30191, 30192, 30194, 30195, 30300, 5969, 5970, 5971, 5972, 5973, 5974, 5979, 5980, 5981, 5982, 5983, 5984, 5985, 7452, 7611, 7612, 7613, 7801, 8119, 8120, 8121, 8122, 8123, 8124, 8125, 8126, 8130, 8131, 8132, 8133, 8134, 8135, 8147, 8148, 8149, 8150, 8151, 8152, 8154, 8158, 8159, 8160, 8161, 8182, 8186, 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8211, 8301, 8302, 8303, 8304, 8495, 8641, 8642, 8643, 8644, 8655, 8656, 8657, 8658, 8661, 8662, 8663, 8664, 8665, 8666, 8681
- Max Martin Richter: 10182, 10185, 10190, 10197, 42071, 42079, 42101, 42102, 8024, 8074, 8258, 8272, 8273, 8274, 8275, 8810, 8815, 8820, 8826, 8828, 8830, 8836, 8838, 8856
- Merlijn Wissink: 10251, 21001, 21010, 21016, 21107, 21113, 30029, 30181, 30284, 30311, 30312, 30313, 310-3, 31027, 31028, 31037, 31039, 311, 312-3, 314, 3223, 40148, 41040, 41071, 41072, 41073, 41500, 41501, 41502, 41503, 41504, 41505, 42031, 4484, 4485, 4486, 4525, 4536, 4778, 4903, 4904, 4905, 60065, 60066, 60067, 60083, 6208, 7180, 7210, 7219, 7268, 7269, 75010, 7796, 7911, 850, 950
- Michael Heidemann: 106, 107-2, 30201, 60001, 610
- Michal Oravec: 8020
- MMR1988: 4002020, 42101, 42108
- N. W. Perry: 5510, 5540, 6919, 7246, 956
- Nathan Perry: 952
- Oh-Seong KWON: 42000, 42006, 9390, 9391, 9392, 9394, 9395, 9396, 9397
- Oliver Dammann: 358
- Orion Pobursky: 10019, 10214, 10226, 10241, 10253, 10256, 10262, 10267, 10269, 10272, 10276, 10280, 10281, 10283, 10315, 10359, 21002, 21004, 21005, 21008, 21009, 21011, 21036, 21037, 21039, 21041, 21042, 21043, 21045, 21046, 21047, 21051, 21052, 21307, 21311, 21318, 21321, 21323, 30056, 30277, 40199, 40270, 40354, 40433, 40448, 42026, 42111, 5521, 6931, 7181, 7191, 75033, 75060, 75181, 75277, 76139, 76161, 77904, 8099, 8448, 8466, 8880
- Peter Bartfai: 8464
- Philippe Hurbain: 10230, 10258, 10261, 10278, 10297, 30285, 3061, 3063, 31040, 31063, 31084, 3184, 3930, 3931, 4010, 40138, 40274, 41075, 41181, 41512, 42031, 42032, 42033, 42034, 42035, 42036, 42037, 42038, 42039, 42040, 42041, 42042, 42043, 42044, 42045, 42046, 42047, 42048, 42049, 42050, 42052, 42053, 42056, 42057, 42058, 42060, 42064, 42071, 42092, 42093, 42094, 42095, 42096, 42099, 42105, 42106, 42107, 42109, 42112, 42113, 42116, 42122, 71006, 7410, 8001, 8002, 8012, 8257, 8285, 9469, 9471, 9476
- Rene Frijhoff: 5540
- Rene Rechthaler: 40782, 40783
- Rijk van Voorst: 1484, 6355, 6515, 6661, 6679, 7815, 7834, 7839
- Robert Paciorek: 10001, 10036, 10037, 10128, 10156, 1029, 1472, 1489, 1490, 1496, 1656, 1682, 1702, 1772, 1773, 1775, 1792, 1808, 1831, 1854, 1896, 1952, 2140, 2148, 2149, 2150, 2531, 316, 3180, 3442, 376-2, 390-2, 392, 395, 4002, 4005, 4015, 4205, 4208, 4431, 4532, 4537, 4554, 4555, 4563, 4565, 4886, 60054, 625, 6331, 6334, 6339, 6346, 6348, 6349, 6350, 6351, 6352, 6353, 6354, 6356, 6357, 6362, 6363, 6364, 6368, 6369, 6370, 6372, 6373, 6374, 6375, 6376, 6378, 6380, 6382, 6384, 6386, 6388, 6389, 6392, 6397, 6398, 6399, 6402, 6414, 6416, 6430, 6431, 6440, 6442, 6450, 6462, 6473, 6480, 6482, 6484, 6490, 6501, 6506, 6507, 6511, 6512, 6514, 6521, 6523, 6524, 6525, 6526, 6527, 6529, 6530, 6533, 6534, 6537, 6540, 6541, 6542, 6544, 6545, 6550, 6553, 6556, 6562, 6571, 6581, 6597, 6598, 6599, 6601, 6614, 6622, 6623, 6624, 6625, 6627, 6628, 6629, 6630, 6631, 6632, 6633, 6642, 6643, 6645, 6648, 6648-2, 6649, 6651, 6652, 6653, 6656, 6660, 6663, 6666, 6667, 6668, 6669, 6670, 6673, 6674, 6676, 6677, 6678, 6680, 6681, 6682, 6683, 6684, 6685, 6687, 6692, 6693, 6694, 6695, 6696, 6697, 6698, 6699, 7722, 7731, 7735, 7813, 7816, 7819, 7821, 7822, 7823, 7824, 7866, 7902
- Roland Dahl: 10030, 10174, 10175, 10179, 10212, 10240, 10252, 70814, 75050, 75054, 75055, 75144
- Sean Burke: 7667
- Stan Isachenko: 10220, 30210, 5920, 5934, 5935, 6232, 6279, 7161
- Stefan Frenz: 1972, 31009, 31025, 31048, 31070, 40190, 40191, 40192, 40193, 40194, 40195, 4025, 6022, 6034, 6040, 6041, 6049, 6059, 6061, 6062, 6067, 6073, 6074, 6080, 6085, 6379, 6592, 75948, 75953, 75954, 75966, 75968, 75969, 75980, 854, 8845, 8849, 8854, 8865, 8868
- Stefan Frenz (smf): 10218
- Steffen: 7725, 7740, 7745, 7750, 7755
- Steffen Altenburg: 4432
- Strikeman: 6381, 6552, 7715, 7730, 7835
- Takeshi: 166, 167
- Takeshi Takahashi: 148, 165, 1680, 1974-3, 30024, 30025, 30026, 30027, 30028, 30103, 30105, 3183, 3185, 3187, 3188, 3189, 3316, 374, 377, 3932, 3933, 3934, 3935, 3936, 3937, 3938, 3939, 3942, 40011, 561412, 5761, 5763, 5764, 5765, 5767, 5770, 5771, 5867, 5892, 6021, 6030, 6035, 6066, 6071, 620, 621, 622, 623, 8835, 8862
- technicbasics: 42072
- Tim Singer: 5571
- Tomas Kralicek: 1477, 31045, 42004, 6344, 6508, 6509, 6532, 6535, 6596, 8049, 8063, 8110, 8202, 8256, 8259, 8260, 8261, 9393
- TotalyWicked: 10002, 10013, 10014, 10015, 10016, 10020, 10022, 10025, 10133, 10158, 10170, 10194, 10205, 1517, 1991, 20004, 2962, 3740, 3741, 3742, 4533, 4539, 4541, 4543, 4544, 4546, 4547, 4549, 4551, 4557, 6445, 6451, 6479, 6503, 6536, 6615, 7810, 7817
- Ulrich Röder: 10265, 10270
- Ulrich Röder {UR}: 10277, 10295, 5542
- Victor Di Rienzo: 1591, 6626, 6641, 6647, 6650, 6657, 6658, 6675, 6679-2, 6688, 6690, 7236, 7245, 8054, 8825, 8840, 8850
- Vincent Messenet: 21302, 21319, 21325, 40271, 40272, 40273, 40348, 40349, 40350, 40351, 40352, 40353, 40367, 40377, 40378, 40379, 40380, 40412, 40425, 40436, 40440, 40441, 40466, 41487, 41488, 41598, 41599, 41600, 41601, 41602, 41603, 41604, 41605, 41606, 41607, 41608, 41609, 41611, 41612, 41613, 41614, 41615, 41616, 41617, 41618, 41620, 41621, 41624, 41625, 41627, 41632, 41634, 41637, 75272, 75317
- Willy Tschager: 10243, 10246, 1499, 364, 365, 367, 396, 40290, 6716, 6718, 6755, 6761, 6765, 6769, 6799, 6822, 6841, 6842, 6844, 6861, 6870, 6880, 6890, 6927, 6929, 6950, 6970, 6980, 891, 894, 897, 918, 920-2, 924, 926, 928
- Willy Tschager {Holly Wood}: 6901
- Zoltán Kéri: 10001, 10159, 4558, 6396, 6472, 6481, 6634, 6689

## Test models for Brickify

The sphere, the chamfered cube and the bunny that `src/dev/brickify_probe.gd`
and `tools/web/brickify_flow.mjs` brickify are made in code here
(`src/dev/brickify_samples.gd`), not downloaded, so nothing of anyone
else's is in them. `tests/fixtures/brickify/bunny.obj` is that bunny written
out, and is dedicated to the public domain (CC0 1.0).

## LEGO Digital Designer's numbers (ldraw.xml)

Opening an LDD model (`.lxf`, `src/parts/ldd_lxf.gd`) needs LDD's part and
colour numbers in LDraw's terms, and where each part's origin is in each.
That table is `ldraw.xml`: first shipped with LDD itself for its LDraw
export, then kept up by the LDraw community. `assets/ldraw/ldd.json` is
derived from it by `tools/ldd_map.py` (colours, renamed parts, origins;
nothing else of it is kept) and ships in every build.

- Source: the version of 2025-08-11 (`LDD 4.3.11 Brick ver 2670`),
  https://gitlab.com/sylvainls/lxf2ldr/-/raw/master/common/ldraw.xml,
  byte for byte the copy at http://slswww.free.fr/ldraw.xml that the LDraw
  wiki names as current (https://wiki.ldraw.org/wiki/LDraw.xml_File).
- Kept by Sylvain Sauvage, from Mike Gallagher's v4.40 beta, with
  additions and corrections from shutterfreak, djm, Mattia Zamboni,
  TotiGonzales and Jarema, as its header says.
- Licence: none is stated. lxf2ldr's README says the file "never had any
  explicit license and has been treated as 'free to use and modify'", and
  LeoCAD and LPub3D ship it whole; we ship a derived table, credited here.
  `tools/fetch_data.sh` fetches the source into `vendor/`.

The `.lxf` the importer is proven with, `src/dev/fixtures/49311_test.lxf`, is
from https://github.com/sttng/LDD (`assets/49311_test.lxf`), saved by LDD
4.3, under the MIT licence:

> MIT License
>
> Copyright (c) 2019 sttng
>
> Permission is hereby granted, free of charge, to any person obtaining a
> copy of this software and associated documentation files (the
> "Software"), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish,
> distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to
> the following conditions:
>
> The above copyright notice and this permission notice shall be included
> in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
> OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
> MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
> IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
> CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
> TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
> SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The AES-locked zip the `.io` reader is proven with,
`tests/fixtures/studio/libarchive_aes256.zip`, is libarchive's own test file
(https://github.com/libarchive/libarchive,
`libarchive/test/test_read_format_zip_winzip_aes256.zip.uu`, decoded), under
libarchive's BSD 2-clause licence:

> Copyright (c) 2003-2018 Tim Kientzle and the libarchive authors.
> All rights reserved.
>
> Redistribution and use in source and binary forms, with or without
> modification, are permitted provided that the following conditions are
> met:
> 1. Redistributions of source code must retain the above copyright notice,
>    this list of conditions and the following disclaimer in this position
>    and unchanged.
> 2. Redistributions in binary form must reproduce the above copyright
>    notice, this list of conditions and the following disclaimer in the
>    documentation and/or other materials provided with the distribution.
>
> THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
> IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
> OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
> IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
> INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
> NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
> DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
> THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
> (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
> THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
## HDR panoramas for File, Render…

The three photographed places a render can be lit by (`assets/hdri/`,
`src/render/studio_render.gd`, `StudioRender.HDRIS`) are Poly Haven's,
downloaded at 1K on 2026-10-12 and imported at 512 x 256. Poly Haven
publishes every asset under **CC0 1.0** (public domain dedication,
https://creativecommons.org/publicdomain/zero/1.0/): no attribution is
required, and it is given anyway.

- `studio_small_09.hdr`, "Studio Small 09", by Sergej Majboroda —
  https://polyhaven.com/a/studio_small_09 ("Softbox studio").
- `photo_studio_loft_hall.hdr`, "Photo Studio Loft Hall", by Sergej
  Majboroda — https://polyhaven.com/a/photo_studio_loft_hall
  ("Window light").
- `kloofendal_48d_partly_cloudy_puresky.hdr`, "Kloofendal 48d Partly Cloudy
  (Pure Sky)", by Greg Zaal (original) and Jarod Guest (sky edits) —
  https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky ("Daylight").

## LEGO trademarks

LEGO® is a trademark of the LEGO Group of companies which does not
sponsor, authorize or endorse this app. LEGO® Art, Technic, the Minifigure
and the Brick and Knob configurations are also trademarks of the LEGO Group.

How the app, the site and the designer follow the LEGO Group's Fair Play
policy — the rules, quoted from the policy with links, where the
disclaimer is, the test that holds it, and the questions left for counsel —
is in `docs/TRADEMARKS.md`. Part names come from LDraw's descriptions,
which are descriptive ("Brick 2 x 4"), not from the LEGO Group's marketing
names.

## Catalogue metadata

**Rebrickable** — safe to redistribute, attribution required. Their
downloads page grants:

> You can use these files for any purpose, including commercial,
> provided you acknowledge Rebrickable as your source of data.

with the condition that automated downloading happens "at most once a
day". This is a custom informal grant rather than a named licence, so
the quotation above is the pinned snapshot, read 2026-10-05.

In use since 2026-10-05, and the reason: LDraw models geometry and has
no idea what LEGO ever moulded, so it will render a wedge plate in a
colour that never existed. `tools/fetch_data.sh` fetches six of their
tables into `vendor/rebrickable/`, and `tools/rebrickable.py` joins them
to the LDraw library to give each part the colours it was really made in
and the years it appeared in a set. Nothing of theirs is redistributed:
the index is derived at build time and the tables are gitignored. The
once-a-day condition is enforced in the fetch itself, where `--force`
will not re-download a table less than a day old.

Required credit: "Catalog data: Rebrickable" — in `web/index.html`'s
footer and on every instruction booklet (`src/assembly/booklet.gd`).

**BrickLink** — do not redistribute. The API is OAuth-gated and catalog
downloads are login-gated; the LEGO Group has owned BrickLink since
2019, so its terms are effectively LEGO's. Using BrickLink *identifiers*
is fine — LDraw embeds them in its own CC BY `!KEYWORDS` lines — but
mirroring the catalogue is not. Nothing is lost by declining: BrickLink
Studio's part library is the LDraw library.

**LDCad shadow library** — CC BY-SA 4.0, which is *not* the parts
library's CC BY 4.0. ShareAlike is viral: connectivity data derived from
it must itself be released under CC BY-SA 4.0. If it is ever used, it
ships as a separately licensed data file rather than compiled in. The
connectivity this project uses is derived from the parts library's own
primitives instead, and carries no such obligation.

**Rendered images are not derivative works** of the LDraw library, so
part thumbnails rendered here are unencumbered — which is the reason to
render our own rather than hotlink anyone's CDN.
