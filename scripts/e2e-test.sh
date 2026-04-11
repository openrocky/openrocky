#!/bin/bash
#
# Run Rocky E2E tests on a real device.
#
# Usage:
#   ./scripts/e2e-test.sh                          # prompts for API key
#   ./scripts/e2e-test.sh sk-xxx                   # pass key as argument
#   ROCKY_TEST_OPENAI_API_KEY=sk-xxx ./scripts/e2e-test.sh  # env var
#
# Options:
#   --list-devices   List available iOS devices and exit
#   --device "Name"  Specify device name (default: auto-detect first iPhone)
#

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="OpenRocky/OpenRocky.xcodeproj"
SCHEME="OpenRocky"
TEST_TARGET="OpenRockyTests/OpenRockyE2ETests"

# ── Parse arguments ──

DEVICE_NAME=""
LIST_DEVICES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list-devices)
            LIST_DEVICES=true
            shift
            ;;
        --device)
            DEVICE_NAME="$2"
            shift 2
            ;;
        sk-*)
            ROCKY_TEST_OPENAI_API_KEY="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--list-devices] [--device \"iPhone Name\"] [sk-xxx]"
            exit 1
            ;;
    esac
done

# ── List devices ──

if $LIST_DEVICES; then
    echo "Available iOS devices:"
    xcrun xctrace list devices 2>/dev/null | grep -i iphone || echo "  (none found)"
    exit 0
fi

# ── Resolve device ──

if [[ -z "$DEVICE_NAME" ]]; then
    DEVICE_NAME=$(xcrun xctrace list devices 2>/dev/null | grep -i iphone | head -1 | sed 's/ (.*//')
    if [[ -z "$DEVICE_NAME" ]]; then
        echo "Error: No iPhone found. Connect a device or use --device \"Name\"."
        exit 1
    fi
    echo "Auto-detected device: $DEVICE_NAME"
fi

# ── Resolve API key ──

if [[ -z "${ROCKY_TEST_OPENAI_API_KEY:-}" ]]; then
    echo -n "Enter OpenAI API key (sk-...): "
    read -r ROCKY_TEST_OPENAI_API_KEY
fi

if [[ -z "$ROCKY_TEST_OPENAI_API_KEY" ]]; then
    echo "Error: No API key provided. E2E tests will be skipped."
    exit 1
fi

export ROCKY_TEST_OPENAI_API_KEY

# ── Run tests ──

echo ""
echo "═══════════════════════════════════════════"
echo "  OpenRocky E2E Tests"
echo "  Device: $DEVICE_NAME"
echo "  Key:    ${ROCKY_TEST_OPENAI_API_KEY:0:8}..."
echo "═══════════════════════════════════════════"
echo ""

xcodebuild test \
    -scheme "$SCHEME" \
    -project "$PROJECT" \
    -destination "platform=iOS,name=$DEVICE_NAME" \
    -only-testing:"$TEST_TARGET" \
    ROCKY_TEST_OPENAI_API_KEY="$ROCKY_TEST_OPENAI_API_KEY" \
    2>&1 | tee /tmp/rocky-e2e-test.log | \
    grep -E '(Test Case|passed|failed|error:|SUCCEEDED|FAILED|Executed)'

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ All E2E tests passed"
else
    echo "✗ Some tests failed (full log: /tmp/rocky-e2e-test.log)"
fi

exit $EXIT_CODE
