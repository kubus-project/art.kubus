#!/usr/bin/env python3
"""Wave 4 PRODUCT v5 app-wide legacy-style inventory.

Scans Dart sources under lib/ (excluding generated localization) and writes a
per-file, per-area occurrence table. Counts are textual source matches, not
runtime widget counts. Output contains paths and counts only, never source.

    py -3 scripts/audit_product_v5_app.py --output docs/design/product_v5_app_audit.json
    py -3 scripts/audit_product_v5_app.py --baseline <sha> --output ...
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Legacy cyan/blue values that predate the PRODUCT v5 neutral + family-active
# palette. Matched case-insensitively inside Color(0x..) literals.
LEGACY_BLUE_CYAN = (
    "00D4FF", "00E5FF", "00BCD4", "06B6D4", "0EA5E9", "22D3EE", "38BDF8",
    "3B82F6", "2563EB", "1D4ED8", "60A5FA", "4F46E5", "6366F1", "0099CC",
    "00B8D9", "4FC3F7", "29B6F6", "03A9F4", "2196F3", "1E88E5", "00ACC1",
)

PATTERNS = {
    # Typography
    "inter_helper": r"\bKubusTypography\.inter\s*\(",
    "outfit_helper": r"\bKubusTypography\.outfit\s*\(",
    "mono_compat_helper": r"\bKubusTypography\.mono\s*\(",
    "structural_helper": r"\bKubusTypography\.(?:structural|machine)\s*\(|\bKubusTextStyles\.(?:structuralLabel|metadataRegister|ordinal|machineValue|coordinate|version)\b",
    "google_fonts_direct": r"\bGoogleFonts\.\w+\s*\(",
    # Surfaces
    "liquid_glass_panel": r"\bLiquidGlass(?:Panel|Card)\s*\(",
    "frosted_container": r"\bFrostedContainer\s*\(",
    "backdrop_glass_sheet": r"\bBackdropGlassSheet\s*\(",
    "backdrop_filter": r"\bBackdropFilter\s*\(",
    "image_filter_blur": r"\bImageFilter\.blur\s*\(",
    "glass_effects_api": r"\bKubusGlassEffects\.\w+",
    "animated_gradient_background": r"\bAnimatedGradientBackground\s*\(",
    "linear_gradient": r"\bLinearGradient\s*\(",
    "radial_gradient": r"\bRadialGradient\s*\(",
    "kubus_gradients_api": r"\bKubusGradients\.\w+",
    "accent_gradients_api": r"\bKubusAccentGradients\.\w+",
    "box_shadow": r"\bBoxShadow\s*\(",
    # Colour
    "hex_color_literal": r"\bColor\s*\(\s*0[xX][0-9A-Fa-f]+",
    "legacy_primary_variant": r"\bKubusColors\.primaryVariant(?:Light|Dark)\b",
    "kubus_colors_primary": r"\bKubusColors\.primary\b",
    "accent_color_property": r"\b(?:themeProvider|ThemeProvider|provider|theme)\.accentColor\b",
    "material_colors_named": r"\bColors\.(?:blue|cyan|lightBlue|indigo|purple|deepPurple|teal)\b",
    "color_roles": r"\bKubusColorRoles\.of\s*\(",
    # Components
    "kubus_button": r"\bKubusButton\s*\(",
    "kubus_outline_button": r"\bKubusOutlineButton\s*\(",
    "material_elevated_button": r"\bElevatedButton(?:\.icon)?\s*\(",
    "material_filled_button": r"\bFilledButton(?:\.icon|\.tonal)?\s*\(",
    "material_outlined_button": r"\bOutlinedButton(?:\.icon)?\s*\(",
    "material_text_button": r"\bTextButton(?:\.icon)?\s*\(",
    "kubus_card": r"\bKubusCard\s*\(",
    "material_card": r"(?<![A-Za-z_])Card\s*\(",
    "kubus_chip": r"\bKubusChip\s*\(",
    "material_chip": r"\b(?:Filter|Choice|Action|Input)?Chip\s*\(",
    "empty_state_card": r"\bEmptyStateCard\s*\(",
    "inline_loading": r"\bInline(?:Loading|Progress)\s*\(",
    "raw_progress_indicator": r"\b(?:Circular|Linear)ProgressIndicator\s*\(",
    "kubus_snackbar": r"\bKubusSnackbar\.|\bshowKubusSnackBar\s*\(",
    "raw_snackbar": r"(?<!Kubus)\bSnackBar\s*\(",
    "show_dialog": r"\bshowDialog\s*<?|\bshowKubusDialog\s*<?",
    "show_bottom_sheet": r"\bshowModalBottomSheet\s*<?",
    "semantics": r"\bSemantics\s*\(",
    "grandfathered_lint_ignore": r"ignore_for_file:.*kubus_",
    # Economic language (display review only)
    "kub8_text": r"KUB8",
}
COMPILED = {k: re.compile(v) for k, v in PATTERNS.items()}
HEX_RE = re.compile(r"\bColor\s*\(\s*0[xX]([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})")

# Screen / feature areas in Wave 4 priority order. First match wins.
AREAS = [
    ("01_shell_navigation", r"lib/(?:screens/desktop/desktop_shell|screens/desktop/components/desktop_navigation|widgets/navigation/|main_app|widgets/mobile_shell|screens/desktop/desktop_shell_scope|widgets/drawer/|core/)"),
    ("02_home_discovery", r"lib/(?:screens/(?:desktop/)?(?:desktop_)?home_screen|widgets/home/)"),
    ("03_map_surrounding_ui", r"lib/(?:screens/(?:desktop/)?(?:desktop_)?map_screen|screens/map|widgets/map/|features/map/)"),
    ("03b_search", r"lib/widgets/search/|lib/.*search"),
    ("04_subject_detail_reference", r"lib/(?:screens/(?:desktop/)?art/|screens/events/(?:event|exhibition)_detail|widgets/detail/|screens/art/collection_detail)"),
    ("05_profiles", r"lib/(?:screens/(?:desktop/)?community/(?:desktop_)?(?:user_)?profile|widgets/profile|screens/community/profile_screen_methods|screens/web3/institution/institution_detail)"),
    ("06_community_social", r"lib/(?:screens/(?:desktop/)?community/|widgets/community/|screens/collab/|screens/activity/|widgets/notifications/|screens/desktop/components/desktop_notifications|widgets/notification_tile)"),
    ("07_auth_onboarding", r"lib/(?:screens/(?:desktop/)?auth/|screens/(?:desktop/)?onboarding/|widgets/auth|widgets/onboarding|widgets/.*sign_in|widgets/email_registration|widgets/user_persona|widgets/secure_account|widgets/security)"),
    ("08_create_contribute", r"lib/(?:screens/map_markers/|widgets/creator/|screens/spatial/|widgets/spatial/|screens/web3/artist/artwork_creator|screens/web3/artist/collection_creator|screens/events/exhibition_creator|screens/web3/institution/event_creator)"),
    ("09_settings", r"lib/screens/(?:desktop/)?(?:desktop_)?settings|lib/screens/security/"),
    ("10_artist_institution_management", r"lib/screens/(?:desktop/web3/desktop_(?:artist_studio|institution_hub)|web3/artist/|web3/institution/|events/exhibition_list)"),
    ("11_web3_wallet_marketplace_dao", r"lib/(?:screens/(?:desktop/)?web3/|widgets/wallet|widgets/promotion/|screens/web3/|widgets/wallet_)"),
    ("12_ar_spatial", r"lib/screens/art/ar_|lib/widgets/ar_"),
    ("13_node_infrastructure", r"lib/(?:screens/node/|widgets/node/|screens/settings/availability_node)"),
    ("14_shared_components", r"lib/(?:widgets/|utils/design_tokens|utils/kubus_)"),
]
AREAS_RE = [(name, re.compile(rx)) for name, rx in AREAS]


def _area(path: str) -> str:
    for name, rx in AREAS_RE:
        if rx.search(path):
            return name
    return "99_other"


def _sources(revision: str | None) -> dict[str, str]:
    files: dict[str, str] = {}
    if revision:
        listing = subprocess.check_output(
            ["git", "ls-tree", "-r", "--name-only", revision, "--", "lib"],
            cwd=ROOT,
        ).decode("utf-8").splitlines()
        for path in listing:
            if not path.endswith(".dart") or "/l10n/" in path:
                continue
            files[path] = subprocess.check_output(
                ["git", "show", f"{revision}:{path}"], cwd=ROOT
            ).decode("utf-8", "replace")
    else:
        for file in sorted((ROOT / "lib").rglob("*.dart")):
            rel = file.relative_to(ROOT).as_posix()
            if "/l10n/" in rel:
                continue
            files[rel] = file.read_text(encoding="utf-8", errors="replace")
    return files


def _scan(files: dict[str, str]) -> dict:
    per_file: dict[str, dict[str, int]] = {}
    totals: dict[str, int] = defaultdict(int)
    file_counts: dict[str, int] = defaultdict(int)
    per_area: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for path, text in files.items():
        counts: dict[str, int] = {}
        for key, rx in COMPILED.items():
            n = len(rx.findall(text))
            if n:
                counts[key] = n
        legacy = 0
        for _alpha, rgb in HEX_RE.findall(text):
            if rgb.upper() in LEGACY_BLUE_CYAN:
                legacy += 1
        if legacy:
            counts["legacy_blue_cyan_hex"] = legacy
        counts["lines"] = text.count("\n") + 1
        per_file[path] = counts
        area = _area(path)
        for key, n in counts.items():
            totals[key] += n
            per_area[area][key] += n
            if key != "lines":
                file_counts[key] += 1
    return {
        "totals": dict(sorted(totals.items())),
        "files_with_occurrence": dict(sorted(file_counts.items())),
        "areas": {a: dict(sorted(c.items())) for a, c in sorted(per_area.items())},
        "files": {
            p: {"area": _area(p), **c}
            for p, c in sorted(per_file.items())
            if len(c) > 1
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", default=None)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result: dict = {
        "schema": "kubus.product_v5_app_audit/1",
        "notes": "Textual Dart source matches under lib/ excluding lib/l10n. "
        "Not runtime widget counts. See docs/design/PRODUCT_V5_APP_AUDIT.md.",
        "patterns": PATTERNS,
        "legacy_blue_cyan_rgb": list(LEGACY_BLUE_CYAN),
    }
    if args.baseline:
        base = _scan(_sources(args.baseline))
        result["baseline"] = {"revision": args.baseline, **base}
    result["current"] = _scan(_sources(None))
    out = ROOT / args.output
    out.write_text(json.dumps(result, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    cur = result["current"]["totals"]
    for key in sorted(cur):
        print(f"{key:34s} {cur[key]:7d}  files={result['current']['files_with_occurrence'].get(key, 0)}")


if __name__ == "__main__":
    main()
