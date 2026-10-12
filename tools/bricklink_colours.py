"""LDraw colour code -> BrickLink colour number.

A BrickLink wanted list names its colours by BrickLink's own numbers,
which are on disk nowhere else: Rebrickable's downloads leave them out.
tools/refresh_catalogue.py write_colors puts each number on its colour in
assets/generated/colors.json as "bricklink", and the app (ShopLists, the
inspector, My collection) and tools/collection_data.py read it from there.

Built once, from four public sources, each read once:

- Rebrickable's colours page, rebrickable.com/colors/, which gives every
  Rebrickable colour its LEGO, LDraw and BrickLink numbers, each marked
  Import and Export. The live page answers a script with a Cloudflare
  challenge, so it was read on 2026-10-12 from the Internet Archive's copy
  of 2026-06-10 (web.archive.org/web/20260610225200/rebrickable.com/colors/).
- The SetDB colour guide, merlinsbricks.com/colors, read 2026-10-12, which
  sets BrickLink, LEGO, Rebrickable and LDraw numbers side by side. It
  copies Rebrickable's numbers, so it agrees with it on all 155 pairs both
  give, stale LDraw names included; it is a check on the reading, not a
  second witness.
- BrickLink's colour guide, bricklink.com/catalogColors.asp, read
  2026-10-12: 214 colours by number and name. Every number below is on it.
- LDraw's LDConfig.ldr (UPDATE 2026-05-29, vendor/ldraw): the codes, the
  names, and the LEGO number each colour was taken from.

Rebrickable numbered its colours by LDraw's codes, and LDraw has moved
some plastics to new codes since (see tools/rebrickable.py
colour_matches), so its LDraw column can name an old code: it gives
Flat Silver as LDraw 179, which LDraw now calls Pearl_Silver, LEGO's
Silver Flip-flop; Flat Silver is 315. So a pair is kept only on two of

  R  Rebrickable's page: the colour that reads the LDraw code in writes
     the BrickLink number out;
  J  this repo's own join puts the LDraw code on a Rebrickable colour
     (colors.json rebrickable_id) that writes the BrickLink number out;
  G  LDConfig's LEGO number for the code is one that Rebrickable or SetDB
     give the BrickLink colour;
  N  the names agree once spelled alike (Grey/Gray, Opal/Satin,
     Modulex/Mx);

and never where G clashes: both sides give a LEGO number and none is
shared. Every pair below has R or J and also G or N. A colour not here
has no BrickLink number: it is left off a wanted list and named, never
guessed, because a guessed colour orders the wrong plastic. Rubber and
canvas colours are not here either; a shop files a Rubber Black tyre
under Black, and the app asks for the plain colour (PartLibrary.plain_code).
"""

from __future__ import annotations

NUMBERS: dict[int, int] = {
    0: 11,        # Black
    1: 7,         # Blue
    2: 6,         # Green
    3: 39,        # Dark Turquoise
    4: 5,         # Red
    5: 47,        # Dark Pink
    6: 8,         # Brown
    7: 9,         # Light Grey: Light Gray
    8: 10,        # Dark Grey: Dark Gray
    9: 62,        # Light Blue
    10: 36,       # Bright Green
    11: 40,       # Light Turquoise
    12: 25,       # Salmon
    13: 23,       # Pink
    14: 3,        # Yellow
    15: 1,        # White
    17: 38,       # Light Green
    18: 33,       # Light Yellow
    19: 2,        # Tan
    20: 44,       # Light Violet
    21: 46,       # Glow In Dark Opaque
    22: 24,       # Purple
    23: 109,      # Dark Blue Violet: Dark Royal Blue
    25: 4,        # Orange
    26: 71,       # Magenta
    27: 34,       # Lime
    28: 69,       # Dark Tan
    29: 104,      # Bright Pink
    30: 157,      # Medium Lavender
    31: 154,      # Lavender
    33: 14,       # Trans Dark Blue: Trans-Dark Blue
    34: 20,       # Trans Green: Trans-Green
    35: 108,      # Trans Bright Green: Trans-Bright Green
    36: 17,       # Trans Red: Trans-Red
    37: 50,       # Trans Dark Pink: Trans-Dark Pink
    38: 18,       # Trans Neon Orange: Trans-Neon Orange
    39: 113,      # Trans Very Light Blue: Trans-Aqua
    40: 13,       # Trans Brown: Trans-Brown
    41: 15,       # Trans Medium Blue: Trans-Light Blue (disputed)
    42: 16,       # Trans Neon Green: Trans-Neon Green
    43: 15,       # Trans Light Blue: Trans-Light Blue
    45: 107,      # Trans Pink: Trans-Pink
    46: 19,       # Trans Yellow: Trans-Yellow
    47: 12,       # Trans Clear: Trans-Clear
    52: 51,       # Trans Purple: Trans-Purple
    54: 121,      # Trans Neon Yellow: Trans-Neon Yellow
    57: 98,       # Trans Orange: Trans-Orange
    60: 57,       # Chrome Antique Brass
    61: 52,       # Chrome Blue
    62: 64,       # Chrome Green
    63: 82,       # Chrome Pink
    64: 122,      # Chrome Black
    68: 96,       # Very Light Orange
    69: 93,       # Bright Reddish Lilac: Light Purple
    70: 88,       # Reddish Brown
    71: 86,       # Light Bluish Grey: Light Bluish Gray
    72: 85,       # Dark Bluish Grey: Dark Bluish Gray
    73: 42,       # Medium Blue
    74: 37,       # Medium Green
    75: 116,      # Speckle Black Copper: Speckle Copper
    77: 56,       # Light Pink: Rose Pink
    78: 90,       # Light Nougat
    79: 60,       # Milky White
    80: 67,       # Metallic Silver
    81: 70,       # Metallic Green
    82: 65,       # Metallic Gold
    83: 244,      # Pearl Black
    84: 150,      # Medium Nougat
    85: 89,       # Medium Lilac: Dark Purple
    86: 91,       # Light Brown
    89: 97,       # Blue Violet: Royal Blue
    92: 28,       # Nougat
    100: 26,      # Light Salmon
    110: 43,      # Violet
    112: 73,      # Medium Violet
    114: 100,     # Glitter Trans Dark Pink: Glitter Trans-Dark Pink
    115: 76,      # Medium Lime
    117: 101,     # Glitter Trans Clear: Glitter Trans-Clear
    118: 41,      # Aqua
    120: 35,      # Light Lime
    123: 231,     # Dark Salmon
    128: 225,     # Dark Nougat
    129: 102,     # Glitter Trans Purple: Glitter Trans-Purple
    132: 111,     # Speckle Black Silver: Speckle Silver
    133: 151,     # Speckle Black Gold: Speckle Gold
    134: 84,      # Copper
    135: 66,      # Pearl Light Grey: Pearl Light Gray
    137: 78,      # Metallic Blue: Pearl Sand Blue
    142: 61,      # Pearl Light Gold
    148: 77,      # Pearl Dark Grey: Pearl Dark Gray
    150: 119,     # Pearl Very Light Grey: Pearl Very Light Gray
    151: 99,      # Very Light Bluish Grey: Very Light Bluish Gray
    179: 95,      # Pearl Silver: Flat Silver (disputed)
    180: 161,     # Dark Yellow
    183: 83,      # Pearl White
    184: 252,     # Metallic Bright Red: Pearl Red
    185: 254,     # Metallic Bright Blue: Pearl Blue
    186: 253,     # Metallic Dark Green: Pearl Green
    187: 255,     # Pearl Brown
    189: 235,     # Reddish Gold
    191: 110,     # Bright Light Orange
    212: 105,     # Bright Light Blue
    216: 27,      # Rust
    218: 227,     # Reddish Lilac: Clikits Lavender
    219: 245,     # Lilac
    220: 246,     # Light Lilac
    225: 172,     # Warm Yellowish Orange
    226: 103,     # Bright Light Yellow
    227: 226,     # Trans Bright Light Green: Trans-Light Bright Green
    231: 164,     # Trans Bright Light Orange: Trans-Light Orange
    232: 87,      # Sky Blue
    272: 63,      # Dark Blue
    284: 114,     # Trans Reddish Lilac: Trans-Light Purple
    285: 221,     # Trans Light Green: Trans-Light Green
    288: 80,      # Dark Green
    294: 118,     # Glow In Dark Trans
    297: 115,     # Pearl Gold
    300: 250,     # Metallic Copper
    302: 162,     # Glitter Trans Light Blue: Glitter Trans-Light Blue
    308: 120,     # Dark Brown
    313: 72,      # Maersk Blue
    315: 95,      # Flat Silver
    316: 77,      # Titanium Metallic: Pearl Dark Gray
    320: 59,      # Dark Red
    321: 153,     # Dark Azure
    322: 156,     # Medium Azure
    323: 152,     # Light Aqua
    326: 158,     # Yellowish Green
    329: 159,     # Glow In Dark White
    330: 155,     # Olive Green
    334: 21,      # Chrome Gold
    335: 58,      # Sand Red
    339: 163,     # Glitter Trans Neon Green: Glitter Trans-Neon Green
    341: 222,     # Glitter Trans Orange: Glitter Trans-Orange
    353: 220,     # Coral
    360: 228,     # Opal Trans Clear: Satin Trans-Clear
    362: 223,     # Opal Trans Light Blue: Satin Trans-Light Blue
    363: 229,     # Opal Trans Black: Satin Trans-Brown
    364: 224,     # Opal Trans Dark Pink: Satin Trans-Dark Pink
    365: 230,     # Opal Trans Purple: Satin Trans-Purple
    366: 29,      # Earth Orange
    367: 233,     # Opal Trans Bright Green: Satin Trans-Bright Green
    368: 236,     # Neon Yellow
    370: 240,     # Medium Brown
    371: 241,     # Medium Tan
    373: 54,      # Sand Purple
    376: 170,     # Opal Trans Yellow: Satin Trans-Yellow
    378: 48,      # Sand Green
    379: 55,      # Sand Blue
    383: 22,      # Chrome Silver
    402: 167,     # Reddish Orange
    422: 169,     # Sienna Brown: Sienna
    423: 168,     # Umber Brown: Umber
    424: 173,     # Ochre Yellow
    430: 175,     # Warm Pink
    431: 174,     # Bright Blue Violet: Blue Violet
    450: 106,     # Fabuland Brown
    462: 31,      # Medium Orange
    484: 68,      # Dark Orange
    503: 49,      # Very Light Grey: Very Light Gray
    509: 160,     # Fabuland Orange
    510: 248,     # Fabuland Lime
    10015: 171,   # Lemon
    10366: 232,   # Opal Trans Dark Blue: Satin Trans-Dark Blue
    10375: 251,   # Trans Black: Trans-Black
    30000: 149,   # Modulex Clear: Mx Clear
    30001: 123,   # Modulex White: Mx White
    30002: 125,   # Modulex Light Grey: Mx Light Gray
    30003: 128,   # Modulex Black: Mx Black
    30004: 134,   # Modulex Terracotta: Mx Terracotta
    30005: 133,   # Modulex Buff: Mx Buff
    30006: 138,   # Modulex Ochre Yellow: Mx Ochre Yellow
    30007: 140,   # Modulex Olive Green: Mx Olive Green
    30008: 146,   # Modulex Teal Blue: Mx Teal Blue
    30009: 132,   # Modulex Brown: Mx Brown
    30011: 145,   # Modulex Pastel Blue: Mx Pastel Blue
    30012: 135,   # Modulex Orange: Mx Orange
    30013: 129,   # Modulex Red: Mx Red
    30014: 141,   # Modulex Pastel Green: Mx Pastel Green
    30015: 139,   # Modulex Lemon: Mx Lemon
    30016: 148,   # Modulex Pink: Mx Pink
    30032: 124,   # Modulex Light Bluish Grey: Mx Light Bluish Gray
    30033: 130,   # Modulex Pink Red: Mx Pink Red
    30034: 142,   # Modulex Aqua Green: Mx Aqua Green
    30035: 137,   # Modulex Light Yellow: Mx Light Yellow
    30037: 147,   # Modulex Violet: Mx Violet
    30038: 144,   # Modulex Medium Blue: Mx Medium Blue
    30039: 136,   # Modulex Light Orange: Mx Light Orange
    30040: 126,   # Modulex Charcoal Grey: Mx Charcoal Gray
    30082: 210,   # Modulex Foil Dark Grey: Mx Foil Dark Gray
    30083: 211,   # Modulex Foil Light Grey: Mx Foil Light Gray
    30084: 212,   # Modulex Foil Dark Green: Mx Foil Dark Green
    30085: 213,   # Modulex Foil Light Green: Mx Foil Light Green
    30086: 214,   # Modulex Foil Dark Blue: Mx Foil Dark Blue
    30087: 215,   # Modulex Foil Light Blue: Mx Foil Light Blue
    30088: 216,   # Modulex Foil Violet: Mx Foil Violet
    30090: 218,   # Modulex Foil Yellow: Mx Foil Yellow
    30091: 219,   # Modulex Foil Orange: Mx Foil Orange
}

# The two of the 61 pairs the app's own table held (ShopLists, from SetDB,
# read 2026-10-11) that the sources above do not bear out. Kept as they
# were until the owner decides, and passed over when a BrickLink number is
# read back if another code has it (tools/collection_data.py).
DISPUTED: dict[int, str] = {
    41: "Trans Medium Blue is LEGO 143 Transparent Fluorescent Blue (LDConfig), "
        "which Rebrickable and SetDB both give BrickLink as 74 Trans-Medium Blue. "
        "15 Trans-Light Blue is LEGO 42, LDraw 43. SetDB's row for 15 says LDraw "
        "43 but names it Trans_Medium_Blue, which is 41.",
    179: "Pearl Silver is LEGO 179 Silver Flip-flop (LDConfig). Rebrickable and SetDB "
         "give 95 Flat Silver as LDraw 179, Rebrickable's old numbering; Flat Silver "
         "is LEGO 315, LDraw 315, which has 95 here as well.",
}

# What some source pairs with a BrickLink number and the rule above does
# not keep, and why.
HELD_BACK: dict[int, str] = {
    44: "Trans Bright Reddish Lilac, LEGO 236; Rebrickable's 114 Trans-Light Purple is LEGO 284",
    76: "Speckle Dark Bluish Grey Silver; Rebrickable's 117 is not on BrickLink's guide",
    87: "Metallic Dark Grey, LEGO 337; Rebrickable's 77 Pearl Dark Gray is LEGO 148 and 316",
    125: "Spud Orange, LEGO 125; Rebrickable's 32 Light Orange is LEGO 121",
    176: "Pearl Red, LEGO 176; Rebrickable's 252 Pearl Red is LEGO 184",
    178: "Pearl Yellow, LEGO 178; Rebrickable's 81 Flat Dark Gold is LEGO 147",
    351: "Medium Dark Pink, LEGO 16; Rebrickable's 94 Medium Dark Pink is LEGO 22",
    30054: "Modulex Dark Brown; only the join says 131 Mx Tile Brown, and the names differ",
    30089: "Modulex Foil Dark Red; only the join says 217 Mx Foil Red, and the names differ",
    31000: "Modulex Dark Grey; only the join says 127 Mx Tile Gray, and the names differ",
    31001: "Modulex Blue; only the join says 143 Mx Tile Blue, and the names differ",
}
