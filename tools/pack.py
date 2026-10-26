"""Pack the mod for a release: dist/menu-pages-<version>.zip, with the menu-pages folder at its top (the
way wcmods adds a mod from a .zip, and the name Get set up looks for in a release).

    python tools/pack.py
"""
import json
import os
import zipfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(HERE, "menu-pages")


def main():
    with open(os.path.join(MOD, "mod.json"), encoding="utf-8") as f:
        version = json.load(f)["version"]
    out = os.path.join(HERE, "dist", f"menu-pages-{version}.zip")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, dirs, files in os.walk(MOD):
            dirs.sort()
            for name in sorted(files):
                path = os.path.join(folder, name)
                z.write(path, "menu-pages/" + os.path.relpath(path, MOD).replace(os.sep, "/"))
    print(out)


if __name__ == "__main__":
    main()
