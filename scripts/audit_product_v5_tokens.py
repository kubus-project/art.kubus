#!/usr/bin/env python3
"""Reproducibly inventory legacy and PRODUCT v5 token call sites.

The baseline is read from Git so it remains stable after this migration. The
current snapshot scans Dart files under lib/, test/, and packages/ in the
working tree. Output omits file contents and includes paths only.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = "251130ec6296c24ad317c5231d8dd365ed513874"
PATTERNS = {
    "inter_helper": re.compile(r"\bKubusTypography\.inter\s*\("),
    "direct_google_fonts_inter": re.compile(r"\bGoogleFonts\.inter\s*\("),
    "outfit_helper": re.compile(r"\bKubusTypography\.outfit\s*\("),
    "direct_google_fonts_outfit": re.compile(r"\bGoogleFonts\.outfit\s*\("),
    "space_mono_family": re.compile(r"Space Mono"),
    "google_fonts_api": re.compile(r"\bGoogleFonts\.(\w+)"),
    "kubus_colors_api": re.compile(r"\bKubusColors\.(\w+)"),
    "kubus_typography_api": re.compile(r"\bKubusTypography\.(\w+)"),
    "kubus_radius_api": re.compile(r"\bKubusRadius\.(\w+)"),
    "primary_color": re.compile(r"\bKubusColors\.primary\b"),
    "gradient_api": re.compile(r"\bKubusGradients\.(\w+)"),
    "glass_effect_api": re.compile(r"\bKubusGlassEffects\.(\w+)"),
    "glass_surface_token_api": re.compile(
        r"\bKubusGlassSurfaceTokens\.(\w+)"
    ),
    "liquid_glass_panel": re.compile(r"\bLiquidGlassPanel\s*\("),
    "animated_gradient_background": re.compile(
        r"\bAnimatedGradientBackground\s*\("
    ),
    "kubus_card": re.compile(r"\bKubusCard\s*\("),
    "kubus_button": re.compile(r"\bKubusButton\s*\("),
    "kubus_chip": re.compile(r"\bKubusChip\s*\("),
    "kubus_borders_api": re.compile(r"\bKubusBorders\.(\w+)"),
    "glass_chip_api": re.compile(r"\bKubusGlassChip\s*\("),
    "glass_icon_button_api": re.compile(r"\bKubusGlassIconButton\s*\("),
    "explicit_glass_card": re.compile(r"\bKubusCard\s*\([^)]*\bisGlass\s*:\s*true", re.S),
    "raw_color_constructor": re.compile(r"\bColor\s*\("),
    "hex_color_literal": re.compile(r"\bColor\s*\(\s*0[xX][0-9A-Fa-f]+"),
    "theme_primary_chain": re.compile(
        r"\bTheme\.of\([^\n)]*\)\.colorScheme\.primary"
    ),
    "scheme_primary": re.compile(r"\bscheme\.primary\b"),
    "accent_color_property": re.compile(
        r"\b(?:themeProvider|ThemeProvider|provider)\.accentColor\b"
    ),
}


def _files_at(revision: str | None) -> dict[str, str]:
    result: dict[str, str] = {}
    if revision:
        tree = subprocess.check_output(
            ["git", "ls-tree", "-r", "-z", revision, "--", "lib", "test", "packages"],
            cwd=ROOT,
        )
        entries: list[tuple[str, str]] = []
        for record in tree.split(b"\0"):
            if not record:
                continue
            metadata, raw_path = record.split(b"\t", 1)
            _mode, kind, object_id = metadata.decode("ascii").split()
            path = raw_path.decode("utf-8")
            if not path.endswith(".dart") or not path.startswith(
                ("lib/", "test/", "packages/")
            ):
                continue
            if kind == "blob":
                entries.append((object_id, path))

        if entries:
            batch = subprocess.check_output(
                ["git", "cat-file", "--batch"],
                cwd=ROOT,
                input=("\n".join(object_id for object_id, _ in entries) + "\n").encode("ascii"),
            )
            offset = 0
            for object_id, path in entries:
                header_end = batch.index(b"\n", offset)
                returned_id, kind, raw_size = batch[offset:header_end].split()
                if returned_id.decode("ascii") != object_id or kind != b"blob":
                    raise RuntimeError(f"Unexpected git cat-file response for {path}")
                size = int(raw_size)
                content_start = header_end + 1
                content_end = content_start + size
                result[path] = batch[content_start:content_end].decode("utf-8")
                if batch[content_end:content_end + 1] != b"\n":
                    raise RuntimeError(f"Malformed git cat-file response for {path}")
                offset = content_end + 1
    else:
        for folder in ("lib", "test", "packages"):
            base = ROOT / folder
            if not base.exists():
                continue
            for path in sorted(base.rglob("*.dart")):
                if any(part in {"build", ".dart_tool"} for part in path.parts):
                    continue
                result[path.relative_to(ROOT).as_posix()] = path.read_text(
                    encoding="utf-8"
                )
    return result


def _metric_summary(
    files: dict[str, str], pattern: re.Pattern[str]
) -> dict[str, object]:
    matches: dict[str, int] = {}
    for path, source in files.items():
        count = len(pattern.findall(source))
        if count:
            matches[path] = count
    return {
        "occurrences": sum(matches.values()),
        "files": len(matches),
        "by_file": dict(sorted(matches.items())),
    }


def _family_inventory(files: dict[str, str]) -> dict[str, object]:
    inventory: dict[str, object] = {}
    for name, pattern in PATTERNS.items():
        inventory[name] = _metric_summary(files, pattern)

    for key in (
        "google_fonts_api",
        "kubus_colors_api",
        "kubus_typography_api",
        "kubus_radius_api",
        "kubus_borders_api",
        "gradient_api",
        "glass_effect_api",
        "glass_surface_token_api",
    ):
        member_pattern = PATTERNS[key]
        members: defaultdict[str, int] = defaultdict(int)
        for source in files.values():
            for member in member_pattern.findall(source):
                members[member] += 1
        inventory[key]["by_member"] = dict(sorted(members.items()))
    return inventory


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", default=DEFAULT_BASELINE)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    payload = {
        "schemaVersion": 1,
        "baselineRevision": args.baseline,
        "scope": ["lib/", "test/", "packages/"],
        "counting": "regex occurrence counts; files are distinct Dart paths",
        "baseline": _family_inventory(_files_at(args.baseline)),
        "currentWorkingTree": _family_inventory(_files_at(None)),
    }
    rendered = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        target = args.output if args.output.is_absolute() else ROOT / args.output
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
