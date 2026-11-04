"""Pack the mod for a release: dist/menu-pages-<version>.zip, with the menu-pages folder at its top (the
way wcmods adds a mod from a .zip, and the name Get set up looks for in a release).

    python tools/pack.py

In a git checkout it refuses while menu-pages/ has changes that aren't committed, or files git doesn't keep
(a settings.json a test run changed, an editor's backup, __pycache__), and when git can't say, so the zip is
what's in git. A copy that isn't a checkout (a downloaded one) is packed as it is.
"""
import json
import os
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(HERE, "menu-pages")


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
    changed = git("status", "--porcelain", "--ignored", "--untracked-files=normal", "--", "menu-pages").splitlines()
    # Files git has been told not to look at (skip-worktree "S", assume-unchanged lower case): whether they
    # changed can't be told from git status.
    changed += [f"(git was told not to look at it) {line[2:]}"
                for line in git("ls-files", "-v", "--", "menu-pages").splitlines()
                if line[:1] == "S" or line[:1].islower()]
    return "\n".join(changed).rstrip()


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
