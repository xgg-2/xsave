#!/usr/bin/env python3
"""Join the files listed in manifest.txt into saveinstance.luau.

    python build.py            build
    python build.py --check    fail if saveinstance.luau is out of date
"""
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(ROOT, "saveinstance.luau")


def build():
    with open(os.path.join(ROOT, "manifest.txt"), encoding="utf-8") as manifest:
        paths = [line.strip() for line in manifest if line.strip()]

    parts = []
    for path in paths:
        full = os.path.join(ROOT, path)
        if not os.path.isfile(full):
            sys.exit(f"missing source file: {path}")
        with open(full, encoding="utf-8", newline="") as handle:
            parts.append(handle.read().strip("\n"))
    return ("\n\n".join(parts) + "\n").encode("utf-8")


def main():
    built = build()
    if "--check" in sys.argv:
        current = open(OUTPUT, "rb").read() if os.path.isfile(OUTPUT) else b""
        if current != built:
            sys.exit("saveinstance.luau is out of date, run python build.py")
        return
    with open(OUTPUT, "wb") as handle:
        handle.write(built)
    lines = built.count(b"\n")
    print(f"built saveinstance.luau ({lines} lines)")


if __name__ == "__main__":
    main()
