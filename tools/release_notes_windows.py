"""Add the Windows install steps to a release's notes (used by .github/workflows/release-windows.yml).

    python tools/release_notes_windows.py NOTES.md VERSION

Rewrites NOTES.md in place and prints "changed" or "unchanged". Notes that already have a
"### Install on Windows" section are left alone, so running it again is harmless. A plain
"### Install" heading (the Mac steps) becomes "### Install on Mac", and the Windows section goes
right after that section's numbered steps; without one, it's added at the end.
"""
import re
import sys

WINDOWS_SECTION = """### Install on Windows
1. Download **MHGU-Charms-RNG-{version}-Windows.zip** below. It runs on 64-bit Windows 10 and 11 (Windows on Arm runs it through emulation).
2. Right-click the zip, choose **Extract All…**, and keep the extracted **MHGU Charms RNG** folder together: the `.dll` files next to the app are the runtime it needs. There's no installer and nothing else to install.
3. Open **MHGU Charms RNG.exe**. The first time, Windows SmartScreen may say it "protected your PC", because the app isn't code-signed. Click **More info**, then **Run anyway**.

Settings are kept in the registry under `HKEY_CURRENT_USER\\Software\\MHGU Charms RNG`.
"""


def add_windows_steps(notes: str, version: str) -> str:
    if re.search(r"^#+\s*Install on Windows\s*$", notes, re.M):
        return notes
    section = WINDOWS_SECTION.format(version=version).splitlines()
    lines = notes.replace("\r\n", "\n").rstrip("\n").split("\n")

    heading = next((i for i, l in enumerate(lines) if re.fullmatch(r"###\s*Install(\s+on\s+Mac)?\s*", l.strip())), None)
    if heading is None:
        return "\n".join(lines + [""] + section) + "\n"

    lines[heading] = "### Install on Mac"
    # The end of the section's steps: past the numbered items and their indented continuations.
    i = heading + 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    while i < len(lines) and (re.match(r"\s*\d+\.\s", lines[i]) or (lines[i].startswith((" ", "\t")) and lines[i].strip())):
        i += 1
    return "\n".join(lines[:i] + [""] + section + lines[i:]) + "\n"


if __name__ == "__main__":
    path, version = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as f:
        old = f.read()
    new = add_windows_steps(old, version)
    if new.replace("\r\n", "\n").rstrip("\n") != old.replace("\r\n", "\n").rstrip("\n"):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
        print("changed")
    else:
        print("unchanged")
