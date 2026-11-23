"""tools/photoreal/stage_measure.py [TREEDIR] [--only a,b] [--frame-fix] : the stage each photograph
shows, beside the same measures of a tree's renders (TREEDIR/<shot>.png, a folder photoreal_probe drew):
what the model stands on and how it is lit, outside the model's outline (photoreal.silhouette, at 256
wide). photoreal9's measure9, which photoreal10 matched the stage to (docs/RENDERING.md 5n).

  back   the backdrop's L* (median), and its spread (p90 - p10 of the lit part, L* above median - 6)
  fall   how its light falls across the frame: the lit backdrop's median L* in the frame's top third
         minus its bottom third, and right third minus left third
  shadow the share of the backdrop in shade (L* 4 or more under the lit median), the share in deep
         shade (12 or more), and the deep share over the shade's (a hard shadow's core is most of it)
  core   the darkest 2 percent of the backdrop: L* and its a*, b* less the lit backdrop's (the
         shadow's colour)
  grain  the backdrop's fine texture, mean |L* - its 3x3 blur| over the lit backdrop, in the frame's
         top third (far, on a floor) and bottom third (near): a surface's grain, and how depth of field
         softens it with distance
  edge   the model's outline sharpness: the mean |L* step| across the outline (pixels on the mask's
         border), against the backdrop's own
"""
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from bench import photoreal  # noqa: E402

args = sys.argv[1:]
only = None
if "--only" in args:
    i = args.index("--only"); only = args[i + 1].split(","); del args[i:i + 2]
fix = "--frame-fix" in args
if fix:
    args.remove("--frame-fix")
tree = Path(args[0]) if args else None


def outline(small, **kw):
    """photoreal.silhouette, and with --frame-fix (photoreal10) the frame's own edge pixels that are not the
    backdrop's colour given back to the model: silhouette seeds the whole frame edge as backdrop, so a model
    cut by the frame (set_6532's render) had its cut edge counted in the shade's core (40 yellow pixels,
    b* +64, moving the core's b* by +3)."""
    mask = photoreal.silhouette(small, **kw)
    if not fix:
        return mask
    far = kw.get("far", 80)
    w, h = small.size
    px = small.load()
    border = sorted(px[x, y] for x in range(w) for y in (0, h - 1))
    ref = border[len(border) // 2]
    m = mask.load()
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1) or y in (0, h - 1)) and max(abs(px[x, y][k] - ref[k]) for k in range(3)) > far:
                m[x, y] = 255
    return mask


def lab_of(image):
    w, h = image.size
    px = image.load()
    out = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            out[y][x] = photoreal._lab(px[x, y])
    return out


def pct(values, share):
    if not values:
        return float("nan")
    values = sorted(values)
    return values[min(len(values) - 1, int(share * len(values)))]


def measure(image, shot):
    W = 256
    small = image.resize((W, round(W * image.height / image.width)), Image.LANCZOS)
    mask = outline(small, **shot.get("mask", {}))
    w, h = small.size
    m = mask.load()
    lab = lab_of(small)
    blur = lab_of(small.filter(ImageFilter.BoxBlur(1)))
    back = [(x, y) for y in range(h) for x in range(w) if not m[x, y]]
    if len(back) < 50:
        return None
    L = [lab[y][x][0] for x, y in back]
    med = pct(L, 0.5)
    lit = [(x, y) for x, y in back if lab[y][x][0] >= med - 6]
    Llit = [lab[y][x][0] for x, y in lit]
    lit_med = pct(Llit, 0.5)
    a_lit = pct([lab[y][x][1] for x, y in lit], 0.5)
    b_lit = pct([lab[y][x][2] for x, y in lit], 0.5)

    def band(sel):
        v = [lab[y][x][0] for x, y in lit if sel(x, y)]
        return pct(v, 0.5) if len(v) > 20 else float("nan")
    fall_v = band(lambda x, y: y < h / 3) - band(lambda x, y: y > 2 * h / 3)
    fall_h = band(lambda x, y: x > 2 * w / 3) - band(lambda x, y: x < w / 3)
    shade = sum(1 for v in L if v <= lit_med - 4) / len(L)
    deep = sum(1 for v in L if v <= lit_med - 12) / len(L)
    darkest = sorted(back, key=lambda p: lab[p[1]][p[0]][0])[: max(5, len(back) // 50)]
    core = (sum(lab[y][x][0] for x, y in darkest) / len(darkest),
            sum(lab[y][x][1] for x, y in darkest) / len(darkest) - a_lit,
            sum(lab[y][x][2] for x, y in darkest) / len(darkest) - b_lit)

    def grain(sel):
        v = [abs(lab[y][x][0] - blur[y][x][0]) for x, y in lit if sel(x, y) and 1 <= x < w - 1 and 1 <= y < h - 1]
        return sum(v) / len(v) if len(v) > 20 else float("nan")
    g_far = grain(lambda x, y: y < h / 3)
    g_near = grain(lambda x, y: y > 2 * h / 3)
    border = [(x, y) for y in range(1, h - 1) for x in range(1, w - 1)
              if m[x, y] and (not m[x + 1, y] or not m[x - 1, y] or not m[x, y + 1] or not m[x, y - 1])]
    steps = []
    for x, y in border:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not m[nx, ny]:
                steps.append(abs(lab[y][x][0] - lab[ny][nx][0]))
    edge = sum(steps) / len(steps) if steps else float("nan")
    return {"back": med, "spread": pct(Llit, 0.9) - pct(Llit, 0.1), "fall_v": fall_v, "fall_h": fall_h,
            "shade": shade, "deep": deep, "hard": deep / shade if shade else 0.0, "core": core,
            "grain_far": g_far, "grain_near": g_near, "edge": edge, "model": 1 - len(back) / (w * h)}


def line(who, r):
    if r is None:
        return f"  {who:6s} (no backdrop found)"
    return (f"  {who:6s} back {r['back']:5.1f} spread {r['spread']:4.1f} | fall top-bot {r['fall_v']:+5.1f} "
            f"right-left {r['fall_h']:+5.1f} | shade {r['shade']:.2f} deep {r['deep']:.2f} hard {r['hard']:.2f} "
            f"| core L {r['core'][0]:5.1f} da {r['core'][1]:+5.1f} db {r['core'][2]:+5.1f} | grain far "
            f"{r['grain_far']:.2f} near {r['grain_near']:.2f} | edge {r['edge']:4.1f} | model {r['model']:.2f}")


for shot in photoreal.shots(only):
    print(shot["name"])
    try:
        print(line("photo", measure(photoreal.photo_of(shot), shot)))
    except Exception as e:  # noqa: BLE001
        print("  photo", e)
    if tree and (tree / f"{shot['name']}.png").exists():
        image = Image.open(tree / f"{shot['name']}.png").convert("RGB").resize(tuple(shot["size"]))
        print(line("render", measure(image, shot)))
