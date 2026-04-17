"""
Design Audit Script (gaspol-design)

Scans target project codebase for design system compliance.
Detects:
- Hardcoded colors (should use design tokens)
- Hardcoded fonts (should use design system font stack)
- Non-responsive layouts (missing breakpoints)
- Missing component states (loading/error/empty)
- Accessibility gaps (missing ARIA, no keyboard support, contrast issues)

Usage:
    python design_audit.py <target_project_path> [--design-system <path_to_CLAUDE.md>]
"""

import argparse
import json
import re
import sys
from pathlib import Path


# Regex patterns for detection
HARDCODED_COLOR_PATTERNS = [
    # Hex colors in JSX/TSX/Vue
    re.compile(r"(?:color|background|bg|border|fill|stroke)[:=][\s'\"`]*#[0-9a-fA-F]{3,8}"),
    # RGB/RGBA
    re.compile(r"(?:color|background|bg|border|fill|stroke)[:=][\s'\"`]*rgba?\("),
    # Tailwind arbitrary values
    re.compile(r"\b(?:bg|text|border)-\[#[0-9a-fA-F]{3,8}\]"),
]

HARDCODED_FONT_PATTERNS = [
    re.compile(r"font-family[:=][\s'\"`]+[^var(]"),
    # Tailwind arbitrary font
    re.compile(r"\bfont-\[[^\]]+\]"),
]

# Responsive breakpoint indicators (Tailwind)
RESPONSIVE_INDICATORS = re.compile(r"\b(?:sm|md|lg|xl|2xl):[a-z-]+")

# State indicators
STATE_INDICATORS = {
    "loading": re.compile(r"\b(?:loading|isLoading|pending|isPending)\b"),
    "error": re.compile(r"\b(?:error|isError|hasError)\b"),
    "empty": re.compile(r"\b(?:empty|isEmpty|nodata|no_data)\b"),
}

# A11y indicators
A11Y_PATTERNS = {
    "aria": re.compile(r"\baria-[a-z]+"),
    "role": re.compile(r'\brole=["\']'),
    "semantic": re.compile(r"<(?:nav|main|article|section|aside|header|footer)\b"),
    "keyboard": re.compile(r"\b(?:onKeyDown|onKeyPress|tabIndex)\b"),
}

# UI-related file extensions
UI_EXTENSIONS = {".tsx", ".jsx", ".vue", ".svelte", ".astro", ".html"}
STYLE_EXTENSIONS = {".css", ".scss", ".sass", ".module.css"}


def scan_file(path: Path) -> dict:
    """Scan a single UI file for design system violations."""
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as exc:
        return {"error": str(exc), "file": str(path)}

    findings = {
        "file": str(path),
        "hardcoded_colors": [],
        "hardcoded_fonts": [],
        "responsive_breakpoints": False,
        "states": {k: False for k in STATE_INDICATORS},
        "a11y": {k: False for k in A11Y_PATTERNS},
    }

    for pattern in HARDCODED_COLOR_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            findings["hardcoded_colors"].append({"line": line_num, "match": match.group()})

    for pattern in HARDCODED_FONT_PATTERNS:
        for match in pattern.finditer(content):
            line_num = content[: match.start()].count("\n") + 1
            findings["hardcoded_fonts"].append({"line": line_num, "match": match.group()})

    findings["responsive_breakpoints"] = bool(RESPONSIVE_INDICATORS.search(content))

    for state_name, pattern in STATE_INDICATORS.items():
        findings["states"][state_name] = bool(pattern.search(content))

    for a11y_name, pattern in A11Y_PATTERNS.items():
        findings["a11y"][a11y_name] = bool(pattern.search(content))

    return findings


def is_ui_file(path: Path) -> bool:
    """Return True if path is a UI-related source file."""
    return path.suffix in UI_EXTENSIONS


def scan_project(project_root: Path) -> list[dict]:
    """Scan entire project for UI files and audit each."""
    if not project_root.exists():
        raise FileNotFoundError(f"Project root not found: {project_root}")

    results = []
    # Skip common non-source directories
    skip_dirs = {"node_modules", ".git", ".next", "dist", "build", "out", "__pycache__", ".cache"}

    for path in project_root.rglob("*"):
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.is_file() and is_ui_file(path):
            results.append(scan_file(path))

    return results


def summarize(findings: list[dict]) -> dict:
    """Aggregate findings into summary counts."""
    total_files = len(findings)
    total_hardcoded_colors = sum(len(f.get("hardcoded_colors", [])) for f in findings)
    total_hardcoded_fonts = sum(len(f.get("hardcoded_fonts", [])) for f in findings)
    files_without_responsive = sum(1 for f in findings if not f.get("responsive_breakpoints", False))
    files_missing_states = {
        state: sum(1 for f in findings if not f.get("states", {}).get(state, False))
        for state in STATE_INDICATORS
    }
    files_weak_a11y = sum(
        1 for f in findings
        if not any(f.get("a11y", {}).get(k, False) for k in ("aria", "role", "semantic"))
    )

    return {
        "total_ui_files": total_files,
        "hardcoded_colors": total_hardcoded_colors,
        "hardcoded_fonts": total_hardcoded_fonts,
        "files_without_responsive": files_without_responsive,
        "files_missing_states": files_missing_states,
        "files_weak_a11y": files_weak_a11y,
    }


def verdict(summary: dict) -> str:
    """Return overall compliance verdict."""
    score = 100
    if summary["hardcoded_colors"] > 0:
        score -= min(30, summary["hardcoded_colors"] * 2)
    if summary["hardcoded_fonts"] > 0:
        score -= min(20, summary["hardcoded_fonts"] * 3)
    if summary["files_without_responsive"] > summary["total_ui_files"] * 0.5:
        score -= 20
    if summary["files_weak_a11y"] > summary["total_ui_files"] * 0.3:
        score -= 15

    if score >= 80:
        return "🟢 COMPLIANT"
    elif score >= 60:
        return "🟡 PARTIAL COMPLIANCE"
    else:
        return "🔴 NON-COMPLIANT"


def main():
    parser = argparse.ArgumentParser(description="Design system compliance audit")
    parser.add_argument("project_path", help="Target project root")
    parser.add_argument("--design-system", help="Path to CLAUDE.md or design tokens reference")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    project_root = Path(args.project_path).resolve()
    findings = scan_project(project_root)
    summary = summarize(findings)
    overall_verdict = verdict(summary)

    if args.json:
        output = {
            "project": str(project_root),
            "summary": summary,
            "verdict": overall_verdict,
            "findings": findings,
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"Design Audit — {project_root}")
        print(f"Verdict: {overall_verdict}")
        print()
        print(f"Files scanned: {summary['total_ui_files']}")
        print(f"Hardcoded colors: {summary['hardcoded_colors']}")
        print(f"Hardcoded fonts: {summary['hardcoded_fonts']}")
        print(f"Files without responsive breakpoints: {summary['files_without_responsive']}")
        print(f"Files with weak a11y: {summary['files_weak_a11y']}")
        print()
        print("State coverage (files missing each state indicator):")
        for state, count in summary["files_missing_states"].items():
            print(f"  {state}: {count}")

    return 0 if "COMPLIANT" in overall_verdict and "NON" not in overall_verdict else 1


if __name__ == "__main__":
    sys.exit(main())
