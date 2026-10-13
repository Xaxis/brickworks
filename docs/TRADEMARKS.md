# Trademarks

How Brickworks writes about LEGO® bricks, and why. **This is compliance
with the LEGO Group's published Fair Play policy. It is not legal advice.**
Nobody here is a lawyer. The questions the policy does not answer are at
the end, under "For counsel".

LEGO® is a trademark of the LEGO Group of companies which does not
sponsor, authorize or endorse this app. LEGO® Art, Technic, the Minifigure
and the Brick and Knob configurations are also trademarks of the LEGO Group.

## Sources

Fetched on 2026-10-13. lego.com refuses scripts, so the policy's full text
was read from the Wayback Machine's copy of 2026-10-07 and its key sentences
checked against the live page.

- **[FP]** The Fair Play policy:
  https://www.lego.com/en-us/legal/notices-and-policies/fair-play
  (copy: https://web.archive.org/web/20261007061707/https://www.lego.com/en-us/legal/notices-and-policies/fair-play)
- **[BR]** The Fair Play brochure the policy links to, dated 01.11.18:
  https://www.lego.com/cdn/cs/legal/assets/blt1a4c9a959ce8e1cb/LEGO_Fairplay_Nov2018.pdf
- **[TOU]** lego.com terms of use, last modified 2026-02-27:
  https://www.lego.com/en-us/legal/terms-of-use. On trademarks it says only
  "see the LEGO Group Fair Play Policy".

## The rules we follow

**1. LEGO is an adjective, in capitals, with its ®.**

> If the LEGO trademark is used at all, it should always be used as an
> adjective, not as a noun. For example, say "MODELS BUILT OF LEGO BRICKS".
> Never say "MODELS BUILT OF LEGOs". [...] the trademark should appear in
> the same typeface as the surrounding text and should not be isolated or
> set apart [...] Finally, the LEGO trademark should always appear with a
> ® symbol each time it is used. [FP]

> ALWAYS write our trademarks in capital letters. ALWAYS use a noun after
> the trademark, e.g. LEGO® toys, LEGO values. NEVER add a possessive "s",
> plural "s" or hyphen, e.g. LEGO's design, more LEGOs to play with,
> LEGO-bricks. [BR p.7]

> the ® symbol is NOT used under any circumstances in company names such
> as e.g. the LEGO Group [BR p.7]

So: "LEGO® bricks", "a LEGO® set", "LEGO® Digital Designer". Never "Legos",
"LEGO's", "LEGO-compatible", or LEGO alone as a noun. When we mean the
company — "as LEGO made it" — we write "the LEGO Group", with no ®. In
plain-text files that may not be UTF-8 (the release README) the ® is "(R)".

**2. The disclaimer, word for word, wherever the mark is used.**

> A disclaimer should be used when the LEGO trademark appears on a Web
> page. An appropriate disclaimer would be "LEGO® is a trademark of the
> LEGO Group of companies which does not sponsor, authorize or endorse this
> site". However, a disclaimer will not serve to undo an improper trademark
> use. [FP]

> The disclaimer should include a reference to all LEGO trademarks that
> are included on the site. [BR p.10]

We use the [FP] sentence exactly. Only its last word changes, to say what
it is on: "site" on the web, "app" in the app and the README, "booklet" on
an instruction booklet. Where a page or the app names other LEGO marks, a
second sentence names them: "LEGO® Art, Technic, the Minifigure and the
Brick and Knob configurations are also trademarks of the LEGO Group."

**3. No LEGO logo, and none of the LEGO Group's own pictures.**

> We must, therefore, insist that the LEGO logo NEVER be used on an
> unofficial web site. [FP]

> The LEGO Group owns the copyrights to its building instructions,
> publications and to the photographs used in our catalogs and on our
> packages. [FP]

Every picture on the site and in the app is our own: screenshots of the app
and renders of LDraw models, made by the runs listed in
`web/img/manifest.json`. No box art, catalogue photos or official
instructions. LDraw's own legal page lists "Rendered images generated from
the LDraw library" as not derivative of the parts
(https://www.ldraw.org/legal-info). The parts are credited, CC BY 4.0, in
the site's footers, the app's About, the booklet and the README.

**4. The mark is not in our names.** Not in the app's name, the domain, the
repository, a package, or a feature.

> The LEGO trademark should not be incorporated into an Internet
> address. [FP]

> This restriction applies to all registered LEGO trademarks, such as but
> not limited to; LEGO, MINDSTORMS®, DUPLO®, NINJAGO® and LEGOLAND®.
> [BR p.9]

The policy says nothing directly about feature names. We apply its reason —
nothing may suggest the LEGO Group made or endorses this — to them too.
The mosaic mode that lays a picture like a LEGO® Art set was called "LEGO
Art". It is now **Brick Art**, described as "in the style of LEGO® Art
sets". Sub-brands appear only as facts about the LEGO Group's sets ("the
rockets of LEGO® City sets"), never as the name of something of ours.

**5. Part names are descriptions.** "Technic brick", "Minifig torso" and the
like are the LDraw library's descriptions of the parts, and are how
BrickLink and Rebrickable name them too. We use them to say what a part
is, never as a brand of ours. That Technic is a LEGO Group mark ([BR p.3]
writes "Technic™") is why it is named in the second sentence of the
disclaimer.

**6. Licensed names are someone else's.** Set names in the catalogue data
include licensed marks ("LEGO Star Wars™ ... Harry Potter™, Disney™, DC
Comics™ Super Heroes and Jurassic World™", [BR p.4]). We use a set's name
only to say which set something comes from.

**7. Non-commercial use only.**

> The LEGO trademarks (but not the logo) may be used in a non-commercial
> manner to refer to LEGO products or elements which are shown or
> discussed on a web site, as long as the trademark is not unduly
> emphasized [...] [FP]

> The LEGO Group's trademarks and copyrighted material may NEVER be used by
> unrelated third parties for their own commercial or marketing purposes,
> unless formal permission or a written licence has been granted by the
> LEGO Group. [BR p.9]

Brickworks is free. If that changes, see "For counsel".

## Where the disclaimer is

| Where a person reads it | File |
|---|---|
| every page's footer: home, download, changelog, 404 (with the second sentence) | `web/*.html` |
| the connector's sign-in page | `web/authorize.html` |
| the home page's FAQ, and its structured data | `web/index.html` |
| the web app's loading page | `src/boot/shell.html` |
| a share page, and the page for a link that is gone | `api/share.js` (`NOTICE`) |
| Help, About Brickworks (with the second sentence) | `src/ui/shell.gd` (`_show_about`) |
| the foot of every instruction booklet page | `src/render/booklet_maker.gd` |
| the README (with the second sentence), and the README in each download | `README.md`, `tools/release.py` (`readme`) |

The embed card (`/m/<id>/embed`) is a small picture and a title inside
somebody else's page. It does not name the mark, and it links to the share
page, which carries the disclaimer.

## How it is held

`tests/test_trademarks.py` reads every file a person reads — the website,
the share page, the app's strings (not its comments or probes), the
connector's tool list, the README, the changelog and the release README —
and fails on:

- LEGO without its ®, or with a ® in "the LEGO Group";
- "Lego" or "Legos", any plural, any possessive;
- LEGO used as a noun for the company ("as LEGO made it");
- "laid in LEGO" with no noun after it;
- "LEGO CAD", which reads as a LEGO product;
- "LEGO Art" not followed by "set" or "sets": the line's name used as ours;
- and any place in the table above that has lost the disclaimer, word for
  word, or the second sentence where it belongs.

Each pattern is also run on a sentence it must catch, and a list of right
uses must get through all of them, so a pattern that never fires cannot
pass quietly. `tools/check.sh` runs it.

The designer is told the rule as well. Claude writes to the person in the
app's chat and in their own Claude, so the rules it designs by
(`Assistant._rules`) say: LEGO® in capitals, with its ®, as an adjective,
never plural or possessive, and the company is the LEGO Group.

Code comments, probes, internal names (`lego_name`, `print_lego`, the
feature map's ids) and the developer documents in `docs/` are not held to
this. The policy is about what the public reads.

## What comparable tools do

All fetched on 2026-10-13. None of them has LEGO in its name or domain.

| Tool | Its notice |
|---|---|
| LeoCAD, https://www.leocad.org/ | "LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this software." |
| Mecabricks, https://www.mecabricks.com/en/ | "LEGO®, the LEGO logo, the Minifigure, and the Brick and Knob configurations are trademarks of the LEGO Group of Companies which does not sponsor, authorize, or endorse this site." |
| LDraw.org, https://www.ldraw.org/legal-info | "LEGO® is a registered trademark of the LEGO Group, which does not sponsor, endorse, or authorize this site." |
| LDCad, https://www.melkert.net/LDCad (Bricksmith the same) | "LEGO® is a registered trademark of the LEGO Group, which does not sponsor, endorse, or authorize this site." |
| Brickset, https://brickset.com/ | "LEGO, the LEGO logo, the Minifigure, and the Brick and Knob configurations are trademarks of the LEGO Group of Companies. ©2026 The LEGO Group." |
| Rebrickable, https://rebrickable.com/ | "LEGO® is a trademark of the LEGO Group of companies." |
| Brick Owl, https://www.brickowl.com/ | "LEGO, the LEGO logo are trademarks of The LEGO Group of companies which is not associated with Brick Owl" |
| BrickLink (the LEGO Group's own), https://www.bricklink.com/ | "LEGO, the LEGO logo, BrickLink, the Minifigure, DUPLO, [...] NINJAGO, VIDIYO and MINDSTORMS are trademarks of the LEGO Group. © 2026 The LEGO Group." |

Rebrickable's terms go further than the policy: "you must not use
trademarked terms in the MOC's name. For example, submitting a MOC named
"Tie Fighter" which is a term trademarked by Disney is not allowed"
(https://tostracker.app/document/rebrickablecom-tos, a copy of 2026-07-09;
rebrickable.com refused the fetch).

## For counsel

Questions the policy does not settle, and a person qualified to answer them
should. Listed most pressing first.

1. **Our logo is a red brick with two knobs.** `web/icon.svg`, the
   favicons, the app icon (`assets/icon.png`) and the share card all draw
   it. The brochure names among the LEGO Group's trademarks "the LEGO logo,
   the minifigure, the basic brick and the knobs", adds that "even though
   they are not registered for construction toys, they are still
   registered for other toys and various other goods", and says of the
   marks it pictures: "They are not to be copied, depicted or used in any
   way without the prior consent of the LEGO Group" [BR p.8]. The policy:
   "In some countries, the LEGO Basic Brick is protected by a trademark
   registration" [FP]. In
   2019 the LEGO Group told the YouTuber behind Held der Steine "that he
   should stop using his logo, which features a stylised version of a LEGO
   brick" (https://www.brickfanatics.com/dispute-between-the-lego-group-and-vlogger-draws-media-attention/,
   2019-01-23). LEGO's own 2016 guidelines for user groups allowed bricks
   and knobs in a logo only to non-commercial groups, and told incorporated
   ones to drop them (https://www.eurobricks.com/forum/forums/topic/139417-mini-figs-on-lug-websites).
   This project's own earlier rule, in `docs/ATTRIBUTION.md` before this
   file replaced it, was "No stud-array pattern as a logo mark", and the
   icon has two. Is our mark safe, or should it be redrawn without knobs?
2. **The name Brickworks.** No clearance search has been done. There is a
   Mac App Store app called Brickworks, an LDraw model viewer by Matusalem
   Marques, last updated 2017 (https://apps.apple.com/us/app/id1176177802).
   Brickworks Limited is a large Australian maker of building materials. A
   quick search found no BRICKWORKS mark for software or toys (classes 9
   and 28), but that is not a search of the USPTO, EUIPO and WIPO records.
3. **Minifigure likeness.** The Minifigure is a LEGO Group trademark
   [BR p.14]. The app has a minifigure builder and draws minifigures from
   LDraw parts, and the site's pictures show them (the Orthanc's two
   wizards, the car's driver). Fan tools have done this for thirty years;
   none of it is in our branding. Is that enough?
4. **Real set numbers, set names and licensed names.** The designer's
   worked examples name the sets they come from ("As the LEGO Group built it
   in 10182 Cafe Corner"), including licensed sets ("75969 Hogwarts
   Astronomy Tower", "21309 NASA Apollo Saturn V"). The site's best picture
   is a Tower of Orthanc Claude designed, and the app ships it
   (`models/orthanc.ldr`): Orthanc is a name from The Lord of the Rings.
   Rebrickable bans trademarked names in fan models' names. Should the
   gallery model be renamed, and should the designer avoid licensed names
   in what it calls a model?
5. **The LEGO Group's own designs, rebuilt.** The worked constructions are
   sub-models of official sets from LDraw's model repository (CC BY 2.0,
   credited); the print editor starts from LDraw's copies of the LEGO
   Group's printed parts, licensed ones among them; colour names and element
   numbers are the LEGO Group's. LDraw's position covers renders of its
   library; it does not speak for the artwork on a printed part.
6. **Commercial use.** Fair Play covers non-commercial use only [FP]
   [BR p.9]. Brickworks is free today. Anything paid — a subscription,
   ads, selling parts lists or kits — would need permission or advice.
7. **"Compatible with".** We never claim compatibility; we say the app is
   for LEGO® bricks. In New Zealand, ZURU's "LEGO Brick Compatible" packaging
   was held to infringe in 2023 because "ZURU was using the word to
   distinguish itself from competitors, rather than in a purely descriptive
   sense"
   (https://www.shortlandchambers.co.nz/news-articles/member-kevin-glover-wins-high-profile-trade-mark-case);
   reports say it was reversed on appeal in 2025, which was not confirmed.
   Is "a CAD app for LEGO® bricks" descriptive enough?
8. **The ® on every use.** [FP] asks for it "each time", which we do in
   everything a person reads. Whether the designer's replies in a person's
   own Claude must carry it too is beyond what we control; it is told to.
