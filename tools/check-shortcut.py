#!/usr/bin/env python3
"""List the macOS system-wide keyboard shortcuts currently in use.

Use it before binding a global hotkey to drake, so you do not pick something
already taken:

    tools/check-shortcut.py            # list everything in use
    tools/check-shortcut.py ctrl+opt+cmd+D

Caveat: this reads macOS's own symbolic hotkeys table. It cannot see hotkeys
registered privately by third-party apps (Raycast, Alfred, Karabiner and so on),
so a combo reported free may still be claimed by one of those.
"""

import plistlib
import subprocess
import sys

MODIFIERS = {
    131072: "shift",
    262144: "control",
    524288: "option",
    1048576: "command",
}

ALIASES = {
    "ctrl": "control",
    "control": "control",
    "opt": "option",
    "alt": "option",
    "option": "option",
    "cmd": "command",
    "command": "command",
    "shift": "shift",
}

# Virtual key codes for the keys worth naming.
KEY_NAMES = {
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
    9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
    31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
    46: "M", 43: ",", 47: ".", 33: "[", 30: "]", 41: ";", 39: "'", 42: "\\",
    27: "-", 24: "=", 50: "`", 48: "Tab", 49: "Space", 51: "Delete",
    53: "Escape", 36: "Return",
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
    100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    123: "Left", 124: "Right", 125: "Down", 126: "Up",
    115: "Home", 119: "End", 116: "PageUp", 121: "PageDown", 107: "F14",
    113: "F15", 105: "F13",
}


def key_name(code):
    return KEY_NAMES.get(code, f"key{code}")


def in_use():
    """(frozenset(modifiers), key name, hotkey id) for each enabled shortcut."""
    raw = subprocess.run(
        ["defaults", "export", "com.apple.symbolichotkeys", "-"],
        capture_output=True,
        check=True,
    ).stdout
    entries = plistlib.loads(raw).get("AppleSymbolicHotKeys") or {}

    found = []
    for identifier, entry in entries.items():
        if not isinstance(entry, dict) or not entry.get("enabled"):
            continue
        parameters = (entry.get("value") or {}).get("parameters")
        if not parameters or len(parameters) < 3:
            continue
        code, mask = parameters[1], parameters[2]
        modifiers = frozenset(name for bit, name in MODIFIERS.items() if mask & bit)
        if not modifiers:
            continue
        found.append((modifiers, key_name(code), identifier))
    return found


def parse(spec):
    parts = [p.strip().lower() for p in spec.replace("-", "+").split("+") if p.strip()]
    modifiers, keys = set(), []
    for part in parts:
        if part in ALIASES:
            modifiers.add(ALIASES[part])
        else:
            keys.append(part.upper())
    if len(keys) != 1:
        sys.exit(f"could not read a single key out of {spec!r}")
    return frozenset(modifiers), keys[0]


def main():
    shortcuts = in_use()

    if len(sys.argv) > 1:
        wanted_modifiers, wanted_key = parse(" ".join(sys.argv[1:]))
        pretty = "+".join(sorted(wanted_modifiers) + [wanted_key])
        clashes = [
            identifier
            for modifiers, key, identifier in shortcuts
            if modifiers == wanted_modifiers and key == wanted_key
        ]
        if clashes:
            print(f"{pretty} is TAKEN by macOS (symbolic hotkey id {', '.join(clashes)})")
            return 1
        print(f"{pretty} is free as far as macOS's own shortcuts go.")
        print("Third-party launchers register hotkeys privately and are not visible here.")
        return 0

    print(f"{len(shortcuts)} system shortcuts with modifiers are enabled:\n")
    for modifiers, key, identifier in sorted(shortcuts, key=lambda item: (item[1], item[2])):
        print(f"  {'+'.join(sorted(modifiers)):26} {key:8} (id {identifier})")
    print("\nCheck a specific combo:  tools/check-shortcut.py ctrl+opt+cmd+D")
    return 0


if __name__ == "__main__":
    sys.exit(main())
