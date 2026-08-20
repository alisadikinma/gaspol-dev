#!/usr/bin/env bash
# test-detect-stack.sh — TDD test for skills/gaspol-execute/scripts/detect-stack
#
# Covers: happy path (npm test key present), tsconfig.json absence (static
# line omitted, not UNKNOWN), missing backing key (UNKNOWN), empty dir
# (zero lines), a non-node stack (go.mod), a polyglot monorepo (prefixed
# lines), and the usage error (missing directory arg).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT_STACK="$REPO_ROOT/skills/gaspol-execute/scripts/detect-stack"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

echo "test-detect-stack: running case 5 (go.mod fixture -> exactly 3 lines)..."

GO_DIR="$TMP_DIR/go-proj"
mkdir -p "$GO_DIR"
cat >"$GO_DIR/go.mod" <<'EOF'
module example.com/x

go 1.22
EOF

OUTPUT="$("$DETECT_STACK" "$GO_DIR")"
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
if ! grep -qx "php/unit: php artisan test" <<<"$OUTPUT"; then
    echo "FAIL: case 6 expected 'php/unit: php artisan test' prefixed line, got:" >&2
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

echo "PASS: test-detect-stack"
