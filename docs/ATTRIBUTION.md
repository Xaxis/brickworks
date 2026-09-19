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
  > licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
  > LDraw™ is a trademark owned and licensed by the Estate of James
  > Jessiman. This application is not affiliated with or endorsed by
  > LDraw.org.

- Source: https://library.ldraw.org/

## LEGO trademarks

Quoted from the LEGO Group's Fair Play guidelines
(https://www.lego.com/legal/notices-and-policies/fair-play/):

> If the LEGO trademark is used at all, it should always be used as an
> adjective, not as a noun.

> [the mark should appear] in the same typeface as the surrounding text
> and should not be isolated or set apart.

> The LEGO logo [should] NEVER be used on an unofficial web site.

and the mark "cannot be used in an Internet address". Note also:

> a disclaimer will not serve to undo an improper trademark use.

Required notice, which must appear in the about screen, the README and
the web footer:

> LEGO® is a trademark of the LEGO Group of companies which does not
> sponsor, authorize or endorse this site.

Binding consequences for naming and UI copy:

- **Never "LEGOs", never "a LEGO".** Adjective only: "models built of
  LEGO® bricks". Always carry the ®.
- **The mark may not appear in the domain, package name, application
  identifier or repository name.** The application is called Brickworks
  for this reason. *The `lego-emulator` repository name still violates
  this and should be renamed* — see docs/ARCHITECTURE.md.
- No LEGO logo, brand typography or product photography anywhere.
- No minifigure trade dress in branding — the app icon, store banner or
  marketing. Rendering minifigure *parts* inside the app from CC BY
  geometry is what every fan tool has done for thirty years and is a
  different question from putting one on the box.
- No stud-array pattern as a logo mark.
- Part names come from LDraw's descriptions, which are descriptive
  ("Brick 2 x 4"), not from LEGO's marketing names.

Precedent is otherwise reassuring: LDraw (1995), LeoCAD (1997),
Mecabricks and BrickStore have run for decades unchallenged, and the
LEGO Group bought BrickLink in 2019 and still ships Studio on the LDraw
library. Enforcement has gone at clone-brick manufacturers and retail
trade dress, not at CAD software.

## Catalogue metadata

**Rebrickable** — safe to redistribute, attribution required. Their
downloads page grants:

> You can use these files for any purpose, including commercial,
> provided you acknowledge Rebrickable as your source of data.

with the condition that automated downloading happens "at most once a
day". This is a custom informal grant rather than a named licence, so a
dated snapshot of the terms text is pinned beside any vendored data.
Required credit: "Catalog data: Rebrickable".

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
