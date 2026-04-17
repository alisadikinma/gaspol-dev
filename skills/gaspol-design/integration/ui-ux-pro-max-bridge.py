"""
Optional delegation bridge to ui-ux-pro-max v2.0 (if installed).

Usage:
    from integration.ui_ux_pro_max_bridge import (
        is_v2_available,
        delegate_design_system_gen,
    )

    if is_v2_available():
        result = delegate_design_system_gen(request)
    else:
        # Use own scripts/design_system_gen.py
        ...
"""

import os
import subprocess
import sys
from pathlib import Path


def is_v2_available() -> bool:
    """
    Detect ui-ux-pro-max v2.0 installation in Claude Code plugins cache.

    Returns True if plugin cache directory exists and contains expected scripts.
    """
    cache_path = Path.home() / ".claude" / "plugins" / "cache" / "ui-ux-pro-max-skill"
    if not cache_path.exists():
        return False

    # Find any version directory
    versions = [p for p in cache_path.glob("ui-ux-pro-max/*") if p.is_dir()]
    if not versions:
        return False

    # Verify scripts exist
    for version_dir in versions:
        search_py = version_dir / "src" / "ui-ux-pro-max" / "scripts" / "search.py"
        if search_py.exists():
            return True

    return False


def get_v2_path() -> Path | None:
    """Return path to ui-ux-pro-max scripts directory, or None if not available."""
    if not is_v2_available():
        return None

    cache_path = Path.home() / ".claude" / "plugins" / "cache" / "ui-ux-pro-max-skill"
    versions = sorted(
        (p for p in cache_path.glob("ui-ux-pro-max/*") if p.is_dir()),
        reverse=True,  # latest version first
    )
    if not versions:
        return None

    return versions[0] / "src" / "ui-ux-pro-max" / "scripts"


def delegate_design_system_gen(request: str) -> dict:
    """
    Delegate full design-system generation to ui-ux-pro-max v2.0 if available.

    Args:
        request: natural language design request (e.g., "SaaS analytics dashboard")

    Returns:
        dict with keys: stdout, stderr, returncode, source ("v2" or "fallback")
    """
    v2_scripts = get_v2_path()
    if v2_scripts is None:
        return {
            "source": "unavailable",
            "returncode": 1,
            "stdout": "",
            "stderr": "ui-ux-pro-max v2.0 not installed. Falling back to own engine.",
        }

    search_py = v2_scripts / "search.py"
    try:
        result = subprocess.run(
            [sys.executable, str(search_py), request, "--design-system"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        return {
            "source": "v2",
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired:
        return {
            "source": "v2",
            "returncode": 124,
            "stdout": "",
            "stderr": "v2.0 design-system generation timed out (>120s). Consider fallback.",
        }
    except Exception as exc:
        return {
            "source": "v2",
            "returncode": 1,
            "stdout": "",
            "stderr": f"Bridge invocation failed: {exc}",
        }


def delegate_domain_search(query: str, domain: str) -> dict:
    """
    Delegate domain-specific search to ui-ux-pro-max v2.0.

    Args:
        query: search query
        domain: one of [style, color, typography, chart, ux, landing, product, icons]

    Returns:
        dict similar to delegate_design_system_gen
    """
    v2_scripts = get_v2_path()
    if v2_scripts is None:
        return {
            "source": "unavailable",
            "returncode": 1,
            "stdout": "",
            "stderr": "ui-ux-pro-max v2.0 not installed. Use own data/ CSV files.",
        }

    search_py = v2_scripts / "search.py"
    try:
        result = subprocess.run(
            [sys.executable, str(search_py), query, "--domain", domain],
            capture_output=True,
            text=True,
            timeout=30,
        )
        return {
            "source": "v2",
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except Exception as exc:
        return {
            "source": "v2",
            "returncode": 1,
            "stdout": "",
            "stderr": f"Bridge invocation failed: {exc}",
        }


if __name__ == "__main__":
    # Self-test
    print(f"v2.0 available: {is_v2_available()}")
    if is_v2_available():
        print(f"v2.0 path: {get_v2_path()}")
    else:
        print("Using own engine (fallback mode)")
