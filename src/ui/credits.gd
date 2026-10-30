## Whose work is in Brickworks, on what terms, and the words each asks for.
##
## Help, About lists every one (Shell._show_about), with a way to read each
## licence; every desktop package carries the same in THIRD-PARTY-NOTICES.txt
## (tools/release_notices.gd writes notices()). One list, so what the app
## says and what the packages say cannot drift apart. docs/ATTRIBUTION.md
## keeps why each term is what it is; this is what a person is shown.
##
## Godot's licence asks for its text "somewhere in your game", with the
## notices of the components the engine is made from; they are read from
## the running engine, so they are those of the version in use. BrickNet's
## MIT asks for its notice and its permission with every copy, and the
## labels and colliders converted from it ship in every build.
##
## Nothing here may depend on another script: the release's notices are
## written from it by a bare SceneTree script.
class_name Credits
extends RefCounted

## BrickNet's licence word for word, as its package carries it
## (bricknet 0.1.1, bricknet-0.1.1.dist-info/licenses/LICENSE).
const BRICKNET_MIT := """MIT License

Copyright (c) 2026 Peter Kulits

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

## The type the booklet's PDF and pages are set in (assets/fonts): its
## notices and the SIL Open Font License 1.1, which asks to go with every
## copy, word for word as the fonts' own package carries it.
const LIBERATION_OFL := """Liberation Sans 2.1.5
Digitized data copyright (c) 2010 Google Corporation with Reserved Font Arimo, Tinos and Cousine.
Copyright (c) 2012 Red Hat, Inc. with Reserved Font Name Liberation.

This Font Software is licensed under the SIL Open Font License, Version 1.1.

SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

PREAMBLE The goals of the Open Font License (OFL) are to stimulate
worldwide development of collaborative font projects, to support the font
creation efforts of academic and linguistic communities, and to provide
a free and open framework in which fonts may be shared and improved in
partnership with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves.
The fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works.  The fonts and derivatives,
however, cannot be released under any other type of license.  The
requirement for fonts to remain under this license does not apply to
any document created using the fonts or their derivatives.



DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such.
This may include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components
as distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole --
any of the components of the Original Version, by changing formats or
by porting the Font Software to a new environment.

"Author" refers to any designer, engineer, programmer, technical writer
or other person who contributed to the Font Software.


PERMISSION & CONDITIONS

Permission is hereby granted, free of charge, to any person obtaining a
copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,in
   Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
   redistributed and/or sold with any software, provided that each copy
   contains the above copyright notice and this license. These can be
   included either as stand-alone text files, human-readable headers or
   in the appropriate machine-readable metadata fields within text or
   binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
   Name(s) unless explicit written permission is granted by the
   corresponding Copyright Holder. This restriction only applies to the
   primary font name as presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
   Software shall not be used to promote, endorse or advertise any
   Modified Version, except to acknowledge the contribution(s) of the
   Copyright Holder(s) and the Author(s) or with their explicit written
   permission.

5) The Font Software, modified or unmodified, in part or in whole, must
   be distributed entirely under this license, and must not be distributed
   under any other license. The requirement for fonts to remain under
   this license does not apply to any document created using the Font
   Software.



TERMINATION
This license becomes null and void if any of the above conditions are not met.



DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT.  IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER
DEALINGS IN THE FONT SOFTWARE.
"""

## Each one: its id, its name, what of it is here, its terms, the licence
## to read in full ("" where a link says it), and its links as [words,
## address]. The order is About's.
const LIST: Array = [
	{"id": "godot", "name": "Godot Engine",
		"what": "The engine Brickworks runs on, the libraries it is made from, and the type"
			+ " its words are set in (Open Sans, SIL Open Font License 1.1).",
		"terms": "MIT License. Copyright (c) 2014-present Godot Engine contributors;"
			+ " Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.",
		"full": "Godot's licence and notices",
		"links": [["godotengine.org/license", "https://godotengine.org/license"]]},
	{"id": "ldraw", "name": "LDraw™ Parts Library",
		"what": "Every part's shape.",
		"terms": "© the LDraw community, licensed under CC BY 2.0 and CC BY 4.0. LDraw™ is a"
			+ " trademark owned and licensed by the Estate of James Jessiman. This application"
			+ " is not affiliated with or endorsed by LDraw.org.",
		"full": "",
		"links": [["CC BY 2.0", "https://creativecommons.org/licenses/by/2.0/"],
			["CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"],
			["library.ldraw.org", "https://library.ldraw.org/"]]},
	{"id": "bricknet", "name": "BrickNet",
		"what": "Part colliders and connector labels (Kulits and Schmid, 2026).",
		"terms": "MIT License. Copyright (c) 2026 Peter Kulits.",
		"full": "BrickNet's licence",
		"links": [["github.com/kulits/BrickNet", "https://github.com/kulits/BrickNet"]]},
	{"id": "rebrickable", "name": "Rebrickable",
		"what": "Catalog data: Rebrickable. The colours each part was made in and the years"
			+ " it was in sets.",
		"terms": "Used with the acknowledgement Rebrickable's terms ask for.",
		"full": "",
		"links": [["rebrickable.com", "https://rebrickable.com/"]]},
	{"id": "omr", "name": "LDraw Official Model Repository",
		"what": "Worked constructions from real sets, each credited to its set and its"
			+ " modeller where it is shown.",
		"terms": "CC BY 2.0 and CC BY 4.0.",
		"full": "",
		"links": [["library.ldraw.org/omr", "https://library.ldraw.org/omr"]]},
	{"id": "polyhaven", "name": "Poly Haven",
		"what": "The light a render can be lit by: Studio Small 09 and Photo Studio Loft Hall"
			+ " by Sergej Majboroda, Kloofendal 48d Partly Cloudy (Pure Sky) by Greg Zaal and"
			+ " Jarod Guest.",
		"terms": "CC0 1.0, given to the public domain.",
		"full": "",
		"links": [["polyhaven.com", "https://polyhaven.com/"]]},
	{"id": "liberation", "name": "Liberation Sans",
		"what": "The type a booklet's PDF and its pages' pictures are set in, carried in the PDF.",
		"terms": "SIL Open Font License 1.1. Copyright (c) 2010 Google Corporation; Copyright"
			+ " (c) 2012 Red Hat, Inc., with Reserved Font Name Liberation.",
		"full": "The type's licence",
		"links": [["github.com/liberationfonts", "https://github.com/liberationfonts"]]},
	{"id": "ldd", "name": "ldraw.xml",
		"what": "LEGO® Digital Designer's part and colour numbers in LDraw's terms, for opening"
			+ " .lxf models. Kept by Sylvain Sauvage from Mike Gallagher's version, with"
			+ " additions from the LDraw community.",
		"terms": "Its keepers state no licence; it has long been treated as free to use"
			+ " and modify.",
		"full": "",
		"links": []},
]


## The one with [param id], or empty.
static func find(id: String) -> Dictionary:
	for one: Dictionary in LIST:
		if one["id"] == id:
			return one
	return {}


## The licence of [param id] in full, as About opens it: Godot's with its
## components' notices, BrickNet's MIT, or the type's Open Font License;
## empty for the others.
static func full_text(id: String) -> String:
	match id:
		"godot":
			return godot_text()
		"bricknet":
			return BRICKNET_MIT
		"liberation":
			return LIBERATION_OFL
	return ""


## Godot's licence, then each component the engine is made from with its
## holders and terms, then those licences' texts: what Godot's "Complying
## with licenses" asks for, from the engine running.
static func godot_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Godot Engine %s" % str(Engine.get_version_info().get("string", "")))
	lines.append("")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("== Components ==")
	lines.append("")
	lines.append("The engine is made from these, each under its own terms.")
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "")))
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", PackedStringArray()):
				lines.append("  Copyright %s" % holder)
			lines.append("  License: %s" % str(part.get("license", "")))
	lines.append("")
	lines.append("== Licence texts ==")
	var texts: Dictionary = Engine.get_license_info()
	var names: Array = texts.keys()
	names.sort()
	for license_name: Variant in names:
		lines.append("")
		lines.append("--- %s ---" % str(license_name))
		lines.append("")
		lines.append(str(texts[license_name]))
	return "\n".join(lines)


## THIRD-PARTY-NOTICES.txt: every one in the list with its terms, then
## BrickNet's licence, the type's and Godot's in full.
static func notices() -> String:
	var lines: PackedStringArray = []
	lines.append("Brickworks is made with the work of others. Each is named here with")
	lines.append("its terms; the licences they ask to be carried follow in full.")
	lines.append("ATTRIBUTION.md, beside this file, says where each is used and why")
	lines.append("its terms are what they are.")
	for one: Dictionary in LIST:
		lines.append("")
		lines.append("== %s ==" % one["name"])
		lines.append("")
		lines.append(one["what"])
		lines.append(one["terms"])
		for link: Array in one["links"]:
			lines.append("%s: %s" % [link[0], link[1]])
	lines.append("")
	lines.append("== BrickNet's licence ==")
	lines.append("")
	lines.append(BRICKNET_MIT)
	lines.append("== Liberation Sans's licence ==")
	lines.append("")
	lines.append(LIBERATION_OFL)
	lines.append("== Godot Engine's licence and its components' notices ==")
	lines.append("")
	lines.append(godot_text())
	return "\n".join(lines) + "\n"
