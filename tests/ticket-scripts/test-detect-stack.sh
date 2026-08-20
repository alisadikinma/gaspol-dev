#!/usr/bin/env bash
# test-detect-stack.sh — TDD test for skills/gaspol-execute/scripts/detect-stack
#
# Covers: happy path (npm test key present), tsconfig.json absence (static
# line omitted, not UNKNOWN), missing backing key (UNKNOWN), empty dir
# (zero lines), a non-node stack (go.mod), a polyglot monorepo (prefixed
# lines), the usage error (missing directory arg), and (Phase E) the
# python/go/rust `command -v` backing gate — proven deterministic on ANY
# machine by controlling PATH directly (a stripped PATH for "tool absent",
# a temp dir with a fake shim script for "tool present") instead of relying
# on what happens to be installed on the machine running the suite.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT_STACK="$REPO_ROOT/skills/gaspol-execute/scripts/detect-stack"
BASH_BIN="$(command -v bash)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# fake_bin DIR NAME... — creates DIR (if absent) and drops an executable
# no-op shim named NAME (one per arg) inside it, so a test can put exactly
# the tools it wants "installed" on PATH, deterministically.
fake_bin() {
    local dir="$1"; shift
    mkdir -p "$dir"
    local name
    for name in "$@"; do
        cat >"$dir/$name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "$dir/$name"
    done
}

echo "test-detect-stack: running case 1 (npm test key present)..."

NODE_DIR="$TMP_DIR/node-full"
mkdir -p "$NODE_DIR"
cat >"$NODE_DIR/tsconfig.json" <<'EOF'
{}
EOF
cat >"$NODE_DIR/package.json" <<'EOF'
{
  "name": "x",
  "scripts": {
    "test": "jest",
    "lint": "eslint .",
    "build": "tsc -p ."
  }
}
EOF

OUTPUT="$("$DETECT_STACK" "$NODE_DIR")"

if ! grep -qx "unit: npm test" <<<"$OUTPUT"; then
    echo "FAIL: case 1 expected 'unit: npm test' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "static: npx tsc --noEmit" <<<"$OUTPUT"; then
    echo "FAIL: case 1 expected 'static: npx tsc --noEmit' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: npm run lint" <<<"$OUTPUT"; then
    echo "FAIL: case 1 expected 'lint: npm run lint' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "build: npm run build" <<<"$OUTPUT"; then
    echo "FAIL: case 1 expected 'build: npm run build' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 2 (tsconfig.json absent -> no static line)..."

NODE_NO_TS_DIR="$TMP_DIR/node-no-ts"
mkdir -p "$NODE_NO_TS_DIR"
cat >"$NODE_NO_TS_DIR/package.json" <<'EOF'
{
  "name": "x",
  "scripts": {
    "test": "jest"
  }
}
EOF

OUTPUT="$("$DETECT_STACK" "$NODE_NO_TS_DIR")"
if grep -q "^static:" <<<"$OUTPUT"; then
    echo "FAIL: case 2 expected NO static: line when tsconfig.json is absent, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 3 (package.json without build key -> UNKNOWN)..."

NODE_NO_BUILD_DIR="$TMP_DIR/node-no-build"
mkdir -p "$NODE_NO_BUILD_DIR"
cat >"$NODE_NO_BUILD_DIR/package.json" <<'EOF'
{
  "name": "x",
  "scripts": {
    "test": "jest"
  }
}
EOF

OUTPUT="$("$DETECT_STACK" "$NODE_NO_BUILD_DIR")"
if ! grep -qx "build: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 3 expected 'build: UNKNOWN' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 3 expected 'lint: UNKNOWN' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 4 (empty dir -> zero lines, exit 0)..."

EMPTY_DIR="$TMP_DIR/empty"
mkdir -p "$EMPTY_DIR"
OUTPUT="$("$DETECT_STACK" "$EMPTY_DIR")"
if [[ -n "$OUTPUT" ]]; then
    echo "FAIL: case 4 expected zero output, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 5 (go.mod fixture, fake go on PATH -> exactly 3 lines)..."

GO_DIR="$TMP_DIR/go-proj"
mkdir -p "$GO_DIR"
cat >"$GO_DIR/go.mod" <<'EOF'
module example.com/x

go 1.22
EOF

GO_FAKE_BIN="$TMP_DIR/bin-go-present"
fake_bin "$GO_FAKE_BIN" go

OUTPUT="$(PATH="$GO_FAKE_BIN" "$BASH_BIN" "$DETECT_STACK" "$GO_DIR")"
LINE_COUNT="$(grep -c . <<<"$OUTPUT" || true)"
if [[ "$LINE_COUNT" -ne 3 ]]; then
    echo "FAIL: case 5 expected exactly 3 lines, got $LINE_COUNT:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "static: go vet ./..." <<<"$OUTPUT"; then
    echo "FAIL: case 5 expected 'static: go vet ./...' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "unit: go test ./..." <<<"$OUTPUT"; then
    echo "FAIL: case 5 expected 'unit: go test ./...' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "build: go build ./..." <<<"$OUTPUT"; then
    echo "FAIL: case 5 expected 'build: go build ./...' line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 6 (monorepo -> prefixed lines)..."

MONO_DIR="$TMP_DIR/mono"
mkdir -p "$MONO_DIR"
cat >"$MONO_DIR/package.json" <<'EOF'
{
  "name": "x",
  "scripts": {
    "test": "jest"
  }
}
EOF
cat >"$MONO_DIR/composer.json" <<'EOF'
{
  "name": "x/x"
}
EOF

OUTPUT="$("$DETECT_STACK" "$MONO_DIR")"
if ! grep -qx "node/unit: npm test" <<<"$OUTPUT"; then
    echo "FAIL: case 6 expected 'node/unit: npm test' prefixed line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
# This fixture has composer.json and NO artisan file, so PHP's unit level is
# correctly UNKNOWN. (Until the case-13 fix this asserted 'php artisan test' —
# the test had codified the bug, which is worse than no test: it made the lie
# look verified.) What case 6 actually proves is the monorepo PREFIXING.
if ! grep -qx "php/unit: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 6 expected 'php/unit: UNKNOWN' prefixed line, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if grep -qx "unit: npm test" <<<"$OUTPUT"; then
    echo "FAIL: case 6 found unprefixed 'unit: npm test' line in a monorepo scan:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 7 (missing directory arg -> exit 1)..."

if "$DETECT_STACK" "$TMP_DIR/does-not-exist" >/dev/null 2>"$TMP_DIR/err7"; then
    echo "FAIL: case 7 expected non-zero exit for a missing directory" >&2
    exit 1
fi
if ! grep -q "not found" "$TMP_DIR/err7"; then
    echo "FAIL: case 7 stderr message unexpected: $(cat "$TMP_DIR/err7")" >&2
    exit 1
fi

echo "test-detect-stack: running case 8 (pyproject.toml, PATH stripped -> unit: UNKNOWN, python backing checked)..."

PY_DIR="$TMP_DIR/py-proj"
mkdir -p "$PY_DIR"
cat >"$PY_DIR/pyproject.toml" <<'EOF'
[project]
name = "x"
EOF

OUTPUT="$(PATH=/nonexistent "$BASH_BIN" "$DETECT_STACK" "$PY_DIR")"
if ! grep -qx "unit: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: python backing not checked — expected 'unit: UNKNOWN' with pytest absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "static: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: python backing not checked — expected 'static: UNKNOWN' with mypy absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: python backing not checked — expected 'lint: UNKNOWN' with ruff absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 9 (pyproject.toml, fake pytest only on PATH -> unit: pytest)..."

PY_FAKE_BIN="$TMP_DIR/bin-pytest-present"
fake_bin "$PY_FAKE_BIN" pytest

OUTPUT="$(PATH="$PY_FAKE_BIN" "$BASH_BIN" "$DETECT_STACK" "$PY_DIR")"
if ! grep -qx "unit: pytest" <<<"$OUTPUT"; then
    echo "FAIL: case 9 expected 'unit: pytest' with fake pytest on PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "static: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 9 expected 'static: UNKNOWN' (mypy still absent), got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 9 expected 'lint: UNKNOWN' (ruff still absent), got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 10 (go.mod fixture, PATH stripped -> all UNKNOWN)..."

OUTPUT="$(PATH=/nonexistent "$BASH_BIN" "$DETECT_STACK" "$GO_DIR")"
if ! grep -qx "static: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: go backing not checked — expected 'static: UNKNOWN' with go absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "unit: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: go backing not checked — expected 'unit: UNKNOWN' with go absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "build: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: go backing not checked — expected 'build: UNKNOWN' with go absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 11 (Cargo.toml, PATH stripped -> all UNKNOWN)..."

RUST_DIR="$TMP_DIR/rust-proj"
mkdir -p "$RUST_DIR"
cat >"$RUST_DIR/Cargo.toml" <<'EOF'
[package]
name = "x"
EOF

OUTPUT="$(PATH=/nonexistent "$BASH_BIN" "$DETECT_STACK" "$RUST_DIR")"
if ! grep -qx "static: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: rust backing not checked — expected 'static: UNKNOWN' with cargo absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: rust backing not checked — expected 'lint: UNKNOWN' with cargo absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "unit: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: rust backing not checked — expected 'unit: UNKNOWN' with cargo absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "build: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: rust backing not checked — expected 'build: UNKNOWN' with cargo absent from PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "test-detect-stack: running case 12 (Cargo.toml, fake cargo on PATH -> all resolved)..."

RUST_FAKE_BIN="$TMP_DIR/bin-cargo-present"
fake_bin "$RUST_FAKE_BIN" cargo

OUTPUT="$(PATH="$RUST_FAKE_BIN" "$BASH_BIN" "$DETECT_STACK" "$RUST_DIR")"
if ! grep -qx "static: cargo check" <<<"$OUTPUT"; then
    echo "FAIL: case 12 expected 'static: cargo check' with fake cargo on PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "lint: cargo clippy" <<<"$OUTPUT"; then
    echo "FAIL: case 12 expected 'lint: cargo clippy' with fake cargo on PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "unit: cargo test" <<<"$OUTPUT"; then
    echo "FAIL: case 12 expected 'unit: cargo test' with fake cargo on PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if ! grep -qx "build: cargo build" <<<"$OUTPUT"; then
    echo "FAIL: case 12 expected 'build: cargo build' with fake cargo on PATH, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

# --- case 13: plain PHP project, no artisan, no php on PATH -> unit: UNKNOWN --
# composer.json proves PHP, not Laravel. A plain library must never be told to
# run `php artisan test`. PATH is stripped to a fake bin dir so the result does
# not depend on whether php happens to be installed on this machine.
echo "test-detect-stack: running case 13 (plain PHP, no artisan, no php -> unit: UNKNOWN)..."
PHP_PLAIN_DIR="$TMP_DIR/php-plain"
mkdir -p "$PHP_PLAIN_DIR"
echo '{}' >"$PHP_PLAIN_DIR/composer.json"
OUTPUT="$(PATH=/nonexistent "$BASH_BIN" "$DETECT_STACK" "$PHP_PLAIN_DIR")"
if ! grep -qx "unit: UNKNOWN" <<<"$OUTPUT"; then
    echo "FAIL: case 13 expected 'unit: UNKNOWN' for a plain PHP project, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi
if grep -q "php artisan" <<<"$OUTPUT"; then
    echo "FAIL: case 13 emitted 'php artisan' for a project with no artisan file:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

# --- case 14: PHP project with vendor/bin/phpunit -> unit: ./vendor/bin/phpunit
echo "test-detect-stack: running case 14 (PHP with phpunit binary -> phpunit)..."
PHP_UNIT_DIR="$TMP_DIR/php-phpunit"
mkdir -p "$PHP_UNIT_DIR/vendor/bin"
echo '{}' >"$PHP_UNIT_DIR/composer.json"
printf '#!/bin/sh\nexit 0\n' >"$PHP_UNIT_DIR/vendor/bin/phpunit"
chmod +x "$PHP_UNIT_DIR/vendor/bin/phpunit"
OUTPUT="$(PATH=/nonexistent "$BASH_BIN" "$DETECT_STACK" "$PHP_UNIT_DIR")"
if ! grep -qx "unit: ./vendor/bin/phpunit" <<<"$OUTPUT"; then
    echo "FAIL: case 14 expected 'unit: ./vendor/bin/phpunit', got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

# --- case 15: real Laravel (artisan present) + php on PATH -> artisan runner --
echo "test-detect-stack: running case 15 (Laravel artisan + php on PATH -> artisan)..."
PHP_LARAVEL_DIR="$TMP_DIR/php-laravel"
PHP_FAKE_BIN="$TMP_DIR/php-fake-bin"
mkdir -p "$PHP_LARAVEL_DIR"
echo '{}' >"$PHP_LARAVEL_DIR/composer.json"
touch "$PHP_LARAVEL_DIR/artisan"
fake_bin "$PHP_FAKE_BIN" php
OUTPUT="$(PATH="$PHP_FAKE_BIN" "$BASH_BIN" "$DETECT_STACK" "$PHP_LARAVEL_DIR")"
if ! grep -qx "unit: php artisan test" <<<"$OUTPUT"; then
    echo "FAIL: case 15 expected 'unit: php artisan test' for a Laravel project, got:" >&2
    printf '%s\n' "$OUTPUT" >&2
    exit 1
fi

echo "PASS: test-detect-stack"
