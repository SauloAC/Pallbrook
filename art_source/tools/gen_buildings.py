"""Builds Pallbrook's 2D-on-volume buildings from art_source/tools/specs/*.py.

    python3 art_source/tools/gen_buildings.py

Run from the repo root. Writes assets/buildings2d/<name>/ and scripts/npc/HouseLayouts.gd.
After running: reimport in Godot, rebake the navigation mesh, save Cidade.tscn."""
import glob, json, os, runpy, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from b2d import build_house, layout

ROOT = os.environ.get("PALLBROOK_ROOT", ".")
SPECS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "specs")
OUT = os.path.join(ROOT, "assets", "buildings2d")
LAYOUTS = os.path.join(ROOT, "scripts", "npc", "HouseLayouts.gd")


def prop_sizes():
    from PIL import Image
    sizes = {}
    for f in glob.glob(os.path.join(OUT, "props", "prop_*.png")):
        sizes[os.path.basename(f)[5:-4]] = Image.open(f).size
    return sizes


def main():
    sizes = prop_sizes()
    layouts = {}
    for path in sorted(glob.glob(os.path.join(SPECS, "*.py"))):
        spec = runpy.run_path(path)["SPEC"]
        spec["facade"] = os.path.join(ROOT, spec["facade"])
        h = build_house(spec, os.path.join(OUT, spec["name"].lower()), sizes)
        print(spec["name"], json.dumps(h.info))
        if h.layout:
            layouts[spec["name"]] = h.layout
    layout.write_gd(layouts, LAYOUTS)
    print("NPC layouts:", ", ".join(layouts))


if __name__ == "__main__":
    main()
