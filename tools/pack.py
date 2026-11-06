"""Pack the mod for a release: dist/menu-pages-<version>.zip, with the menu-pages folder at its top (the
way wcmods adds a mod from a .zip, and the name Get set up looks for in a release).

    python tools/pack.py

In a git checkout it refuses while menu-pages/ has changes that aren't committed, or files git doesn't keep
(a settings.json a test run changed, an editor's backup, __pycache__), and when git can't say, so the zip is
what's in git. A copy that isn't a checkout (a downloaded one) is packed as it is.

The C++ part goes in built: menu-pages/dlls/ (main.dll and build.json, which `python wcmods.py cpp build
<this checkout>/menu-pages` writes and git doesn't keep), without its source, cpp/ (an install would only say the DLL is
older than the source it was unpacked after). It refuses without a DLL, or with one older than its source
(cpp/CMakeLists.txt and cpp/src/), unless --lua-only leaves the C++ part out (its pages then say they need it).
"""
import json
import os
import subprocess
import sys
import zipfile

LUA_ONLY = "--lua-only" in sys.argv[1:]
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(HERE, "menu-pages")
DLLS = os.path.join(MOD, "dlls")      # the C++ part, built (not in git)
SOURCE = os.path.join(MOD, "cpp")     # its source (not in the zip)


def git(*args):
    """git's output, run in this checkout; exits saying why when git can't run or fails."""
    try:
        done = subprocess.run(["git", *args], cwd=HERE, capture_output=True, encoding="utf-8", errors="replace")
    except OSError as e:
        sys.exit(f"git couldn't run ({e}), so menu-pages/ can't be checked against the last commit. "
                 "Put git on PATH, then pack again.")
    if done.returncode != 0:
        sys.exit(f"git {args[0]} failed, so menu-pages/ can't be checked against the last commit:\n"
                 + (done.stderr or done.stdout).strip())
    return done.stdout


def uncommitted():
    """What differs from the last commit in menu-pages/, ignored and untracked files too ("" when nothing does).
    None when this isn't a git checkout of its own (a downloaded copy), where there's nothing to compare with."""
    if not os.path.exists(os.path.join(HERE, ".git")):
        return None
    if git("rev-parse", "--show-cdup").strip():
        sys.exit(f"git says {HERE} isn't the top of its checkout: can't tell what's committed here.")
    changed = [line for line in git("status", "--porcelain", "--ignored", "--untracked-files=normal", "--",
                                    "menu-pages").splitlines()
               if line[3:].rstrip("/") != "menu-pages/dlls"]   # (the build, checked by itself below)
    # Files git has been told not to look at (skip-worktree "S", assume-unchanged lower case): whether they
    # changed can't be told from git status.
    changed += [f"(git was told not to look at it) {line[2:]}"
                for line in git("ls-files", "-v", "--", "menu-pages").splitlines()
                if line[:1] == "S" or line[:1].islower()]
    return "\n".join(changed).rstrip()


def cpp_problem():
    """Why the built C++ part can't go in the zip, or None: no DLL or build.json, or a DLL older than its source."""
    dll, info = os.path.join(DLLS, "main.dll"), os.path.join(DLLS, "build.json")
    if not os.path.isfile(dll) or not os.path.isfile(info):
        return "menu-pages/dlls/ has no main.dll and build.json: the C++ part isn't built."
    # (Its source: CMakeLists.txt and src/. cpp/README.md, the calls' list, isn't built.)
    source = [os.path.join(SOURCE, "CMakeLists.txt")]
    source += [os.path.join(d, n) for d, _, names in os.walk(os.path.join(SOURCE, "src")) for n in names]
    newest = max((os.path.getmtime(f) for f in source if os.path.isfile(f)), default=0)
    if newest > os.path.getmtime(dll):
        return "menu-pages/dlls/main.dll is older than its source in menu-pages/cpp/: build it again."
    return None


def main():
    sys.stdout.reconfigure(errors="backslashreplace")   # (a path with letters the console's code page hasn't)
    changed = uncommitted()
    if changed:
        hidden = "(git was told not to look at it)" in changed
        sys.exit("menu-pages/ may not be as it was committed, so the zip might not be what's in git:\n" + changed +
                 "\nCommit, undo or delete these (git status --ignored menu-pages), then pack again." +
                 ("\nFor a file git was told not to look at: git update-index --no-skip-worktree --no-assume-unchanged "
                  "<file>, then look at it again." if hidden else ""))
    if changed is None:
        print("(not a git checkout: packing menu-pages/ as it is)", file=sys.stderr)
    if not LUA_ONLY:
        problem = cpp_problem()
        if problem:
            sys.exit(problem + "\nBuild it in a wcmods checkout: python wcmods.py cpp build " + MOD +
                     "\n(or pack with --lua-only to leave the C++ part out).")
    with open(os.path.join(MOD, "mod.json"), encoding="utf-8") as f:
        version = json.load(f)["version"]
    out = os.path.join(HERE, "dist", f"menu-pages-{version}.zip")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, dirs, files in os.walk(MOD):
            if folder == MOD:
                dirs[:] = [d for d in dirs if d != "cpp" and not (LUA_ONLY and d == "dlls")]
            dirs.sort()
            for name in sorted(files):
                path = os.path.join(folder, name)
                z.write(path, "menu-pages/" + os.path.relpath(path, MOD).replace(os.sep, "/"))
    print(out)


if __name__ == "__main__":
    main()
