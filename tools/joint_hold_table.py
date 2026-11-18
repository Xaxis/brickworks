#!/usr/bin/env python3
"""Write data/joint_hold.json: how much turning load each friction joint kind
holds, from what builders have published, with every step of the sum.

The LEGO Group publishes no holding torque for any joint. What has been
measured, by hanging bricks on a lever until the joint gave, is turned here
into N·mm with BrickLink's catalogue weights and the levers read off the
published photographs. A kind nobody has measured is written with no number
and the searches that found none (unit posehold, docs/APP_UX9.md):
PoseHold shows such a joint as "not known" and never guesses.

  python3 tools/joint_hold_table.py          # writes data/joint_hold.json
  python3 tools/joint_hold_table.py --check  # exits 1 if the file differs

Each measured kind has three figures:
  every_held  the turning load every joint measured held: the working load
  holds       the median joint's: where a joint of the kind lets go
  every_gave  the load every joint measured had given way under
"""
import json
import statistics
import sys
from pathlib import Path

G = 9.81e-3            # N per gram
STUD = 8.0             # mm
OUT = Path(__file__).resolve().parent.parent / "data" / "joint_hold.json"

# BrickLink catalogue weights, g, read 2026-11-17 from each part's page
# (https://www.bricklink.com/v2/catalog/catalogitem.page?P=<part>).
GRAMS = {
    "3001": 2.32,   # Brick 2 x 4
    "3002": 1.92,   # Brick 2 x 3
    "3004": 0.83,   # Brick 1 x 2
    "3020": 1.20,   # Plate 2 x 4
    "3021": 0.93,   # Plate 2 x 3
    "2465": 6.20,   # Brick 1 x 16
    "92013": 1.98,  # Technic Brick 2 x 2 with Ball Socket and Axle Hole
    "32525": 2.80,  # Technic Liftarm Thick 1 x 11
    "32073": 0.66,  # Technic Axle 5L
    "3713": 0.14,   # Technic Bush
    "3700": 0.82,   # Technic Brick 1 x 2 with Hole
}

RAMBLING_2017 = {
    "title": "Its new to me: stiffening the joints with Element 74261/6106472 (Element Exposition)",
    "author": "The Rambling Brick",
    "date": "2017-02-17",
    "url": "https://ramblingbrick.com/2017/02/17/its-new-to-me-stiffening-the-joints-with-element-742616106472/",
    "quote": ("2 1×16 bricks are attached to the brick with the ball, and a load is progressively "
              "added to the end of the lever. I used standardised 2×4 bricks as my load. [...] The "
              "'naked' ball joint was fairly steady up until the fifth brick was loaded on the lever. "
              "When six bricks were loaded onto the lever, the joint rapidly buckled under the load, "
              "with virtually no drag."),
}
RAMBLING_2021 = {
    "title": "What if they introduced a new Technic pin, and nobody noticed?",
    "author": "The Rambling Brick",
    "date": "2021-01-27",
    "url": "https://ramblingbrick.com/2021/01/27/what-if-they-introduced-a-new-technic-pin-and-nobody-noticed/",
    "quote": ("I inserted it at the proximal hole of an 11 module lift arm, and fashioned a freely "
              "rotating weight, consiting of a 5 module long bar, 2 stoppers and 1×2 bricks – 2 with "
              "technic hols. The bottom was stabilised using a 2×3 plate. The load was increased, by "
              "a 2×3 brick at a time until the arm was unable to resist gravity. [...] A total of 10 "
              "'older' and 8 of the newer pins were tested [...] the Older design – 4.5, the newer "
              "pin: 3."),
}
EUROBRICKS_BALLS = {
    "title": "Question about ball joints (LEGO Action Figures)",
    "author": "Eurobricks forum",
    "date": "2016-07",
    "url": "https://www.eurobricks.com/forum/forums/topic/138001-question-about-ball-joints/",
    "quote": ("The friction of a ball joint/ball socket piece usually varies from piece to piece and "
              "often depends on how much it was used."),
}
BRICKLINK_HINGES = {
    "title": "Re: Variants Thread - January 26",
    "author": "BrickLink forum",
    "date": "2024-01-28",
    "url": "https://www.bricklink.com/message.asp?ID=1451115",
    "quote": ("hanging some kitchen weights from the end of a Technic brick attached to another one "
              "attached to the hinge, so 32L long [...] Either there is huge variability between "
              "hinges or variability comes through the connections between all the parts."),
}


def technic_ball() -> dict:
    """The 10.2 mm ball of 17114 in 92013's socket, both from 31058-1 (whose
    inventory has them, in the photo's dark bluish grey and dark green), a
    lever of two 1 x 16 bricks, 2 x 4 bricks stacked on its last four studs.

    Levers, in studs from the ball's middle, read off the photo 'weak.png'
    (its middle panel, scaled by the stacked 2 x 4s' four studs): the ball
    0.95 stud before the socket brick's face, the brick 2 studs long, the
    1 x 16s after it, the two 2 x 4 plates joining them centred on the seam,
    and the stack centred 2 studs from the lever's end. Read to half a stud
    either way, which the figures carry."""
    ball_to_face = 0.95
    arms = {"92013": ball_to_face + 1.0, "3020": ball_to_face + 2.0,
            "2465": ball_to_face + 2.0 + 8.0, "load": ball_to_face + 2.0 + 16.0 - 2.0}
    lever = {"92013": 1, "3020": 2, "2465": 2}

    def moment(bricks: float, slack: float) -> float:
        own = sum(GRAMS[p] * n * (arms[p] + slack) * STUD for p, n in lever.items())
        return G * (own + bricks * GRAMS["3001"] * (arms["load"] + slack) * STUD)

    return {
        "said": "Technic ball joint",
        "parts": "a 10.2 mm Technic ball in its socket",
        "measured_on": "17114's ball in 92013's socket, the pair 31058-1 uses",
        "joints_measured": 1,
        "every_held_n_mm": round(moment(5, -0.5), 1),
        "holds_n_mm": round(moment(5.5, 0.0), 1),
        "every_gave_n_mm": round(moment(6, 0.5), 1),
        "how": ("held 5 2 x 4 bricks on a lever of two 1 x 16 bricks and buckled at 6: the joint "
                "lets go between those two loads, levered from the ball's middle, the lever's own "
                "weight with them"),
        "sum": {"grams": {p: GRAMS[p] for p in ["3001", "2465", "92013", "3020"]},
                "levers_studs": arms, "lever_slack_studs": 0.5, "held": 5, "gave": 6},
        "spread": ("one joint; friction varies from piece to piece and with wear, new joints "
                   "holding more [eurobricks-balls]"),
        "sources": ["rambling-2017", "eurobricks-balls", "bricklink-weights"],
    }


def friction_pin() -> dict:
    """A friction pin turning in a Technic hole: a thick 1 x 11 liftarm on a
    pin in a wall of Technic bricks, a carrier hung freely at its far hole,
    2 x 3 bricks added to the carrier until the arm fell.

    The pin is in hole 1 and the carrier on a 5L axle through hole 11, 80 mm
    out (photos img_1683-1685); the liftarm's middle 40 mm out. The carrier
    is the axle, its 2 bushes, 2 1 x 2 Technic bricks, the plate and 1 to 3
    plain 1 x 2 bricks (the photo shows a layer of them; how many is not
    said), which the figures carry. Each count in the histogram is the
    number of bricks that made it fall, so the pin held one fewer."""
    falls = {"old (2780, 4121715)": {3: 2, 4: 3, 5: 3, 6: 1, 7: 1},
             "new (61332, 6279875)": {2: 1, 3: 4, 4: 2, 5: 1}}
    carrier = {k: GRAMS["32073"] + 2 * GRAMS["3713"] + 2 * GRAMS["3700"] + k * GRAMS["3004"]
               + GRAMS["3021"] for k in (1, 2, 3)}
    out_mm = 10 * STUD

    def moment(bricks: float, carried: float) -> float:
        return G * ((bricks * GRAMS["3002"] + carried) * out_mm + GRAMS["32525"] * out_mm / 2)

    every: list = []
    for counts in falls.values():
        for n, times in counts.items():
            every += [n] * times
    median = statistics.median(every)
    per_design = {}
    for design, counts in falls.items():
        mine = [n for n, times in counts.items() for _ in range(times)]
        per_design[design] = {"pins": len(mine), "median_falls_at": statistics.median(mine),
                              "holds_n_mm": round(moment(statistics.median(mine) - 0.5, carrier[2]), 1)}
    return {
        "said": "friction pin",
        "parts": ("a pin with friction ridges turning in a round Technic hole (2780, 61332, 4459; "
                  "the same ridges on 6558, 43093 and their kin)"),
        "measured_on": "2780 (10 pins of various ages) and 61332 (8 new pins), one thick liftarm each",
        "joints_measured": len(every),
        "every_held_n_mm": round(moment(min(every) - 1, carrier[1]), 1),
        "holds_n_mm": round(moment(median - 0.5, carrier[2]), 1),
        "every_gave_n_mm": round(moment(max(every), carrier[3]), 1),
        "how": ("fell at the count of 2 x 3 bricks in the article's histogram, each pin holding "
                "one fewer; both designs together, since a file's 2780 does not say which a "
                "builder has"),
        "sum": {"grams": {p: GRAMS[p] for p in ["3002", "32525", "32073", "3713", "3700", "3004",
                                                  "3021"]},
                "carrier_grams": {str(k): round(v, 2) for k, v in carrier.items()},
                "lever_mm": out_mm, "falls_at": falls, "median_falls_at": median,
                "by_design": per_design},
        "spread": "18 pins; the old design held about a brick more than the new (p = 0.03)",
        "sources": ["rambling-2021", "bricklink-weights"],
    }


NOT_KNOWN = {
    "small_ball": {
        "said": "small ball joint",
        "parts": "a 5.9 mm towball or Mixel ball in its socket (14417, 14418, 14419, 14704, 3184 ...)",
        "why": "no measurement published",
    },
    "click_hinge": {
        "said": "click hinge",
        "parts": ("a locking hinge's teeth (44301, 44302, 30383, 30364, 30365, 54657 ...), "
                  "a click rotation joint's (47455 in 48170 or 48171 ...)"),
        "why": ("no measurement published: one builder hung weights on a 32L lever and found the "
                "tipping point varied too much to report [bricklink-hinges]"),
    },
    "hinge": {
        "said": "hinge",
        "parts": "a friction hinge's pin in its eye (2429 with 2430, 3937 with 3938 ...)",
        "why": "no measurement published",
    },
    "turntable": {
        "said": "turntable",
        "parts": "a turntable's top on its base (3679 with 3680, 61485, 99009 with 99010 ...)",
        "why": "no measurement published",
    },
    "clip": {
        "said": "clip on a bar",
        "parts": "a clip round a bar or a handle",
        "why": "no measurement published",
    },
}

SEARCHED = ("Philohome, BrickNerd, New Elementary, Brickset, Brick Architect, Hackaday, Eurobricks "
            "(about 12 threads on pins, hinges, ball joints and turntables), BZPower, LUGNET, "
            "BrickLink's forum, Brick Experiment Channel, Crossref and web searches for theses and "
            "robotics or posable-figure papers, LEGO and Interlego patents (US10065128, US6447358: "
            "holding force named, never measured), toy-safety testing; 2026-11-17")


def table() -> dict:
    kinds = {"technic_ball": technic_ball(), "friction_pin": friction_pin()}
    for key, one in NOT_KNOWN.items():
        kinds[key] = dict(one, holds_n_mm=None, sources=["searched"])
    return {
        "about": ("How much turning load each friction joint holds, N·mm, as builders measured it "
                  "by hanging bricks on a lever until the joint gave; written by "
                  "tools/joint_hold_table.py, read by PoseHold. A kind with no number is not known: "
                  "it is left unweighed, never guessed."),
        "kinds": kinds,
        "sources": {
            "rambling-2017": RAMBLING_2017,
            "rambling-2021": RAMBLING_2021,
            "eurobricks-balls": EUROBRICKS_BALLS,
            "bricklink-hinges": BRICKLINK_HINGES,
            "bricklink-weights": {"title": "BrickLink catalogue weights", "date": "2026-11-17",
                                  "url": "https://www.bricklink.com/v2/catalog/catalogitem.page?P=3001",
                                  "quote": "Weight: 2.32g (and each part's own page)"},
            "searched": {"title": "Searched, nothing measured", "date": "2026-11-17",
                         "quote": SEARCHED},
        },
    }


def main() -> int:
    text = json.dumps(table(), indent=1, ensure_ascii=False) + "\n"
    if "--check" in sys.argv[1:]:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("joint_hold: %s" % ("current" if same else "differs from tools/joint_hold_table.py"))
        return 0 if same else 1
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    kinds = table()["kinds"]
    for key, one in kinds.items():
        if one.get("holds_n_mm") is None:
            print("%-13s not known" % key)
        else:
            print("%-13s holds %5.1f N·mm (every one held %4.1f, every one gave by %4.1f; %d measured)" % (
                key, one["holds_n_mm"], one["every_held_n_mm"], one["every_gave_n_mm"],
                one["joints_measured"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
