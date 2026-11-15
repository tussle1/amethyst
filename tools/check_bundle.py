#!/usr/bin/env python3
"""Fail if the checked-in single-file script is stale or unexpectedly references Studio."""
from build_private import ROOT, render

output = ROOT / "executor/AmethystPrivate.lua"
actual = output.read_text(encoding="utf-8")
expected = render()
if actual != expected:
    raise SystemExit("executor/AmethystPrivate.lua is stale; run python3 tools/build_private.py")

for forbidden in ("require(script.", "game:HttpGet(", "loadstring(", "amethyst studio hub"):
    if forbidden in actual:
        raise SystemExit(f"single-file script has an unexpected dependency: {forbidden}")

print(f"bundle is up to date: {len(actual.splitlines())} Luau lines")
