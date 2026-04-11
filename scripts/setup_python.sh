#!/bin/bash
#
# OpenRocky — Voice-first AI Agent
# https://github.com/openrocky/openrocky
#
# Developed by everettjf with the assistance of Claude Code and Codex.
# Date: 2026-03-25
# Copyright (c) 2026 everettjf. All rights reserved.
#
set -e

PYTHON_VERSION="3.13"
BUILD="b13"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/Packages/OpenRockyPython"
XCFRAMEWORK_DIR="$DEST_DIR/Python.xcframework"

if [ -d "$XCFRAMEWORK_DIR" ]; then
    echo "Python.xcframework already exists at $XCFRAMEWORK_DIR"
    echo "To re-download, remove it first: rm -rf $XCFRAMEWORK_DIR"
    exit 0
fi

URL="https://github.com/openrocky/python/releases/download/1.0.0/Python-${PYTHON_VERSION}-iOS-support.${BUILD}.tar.gz"
TARBALL="/tmp/Python-${PYTHON_VERSION}-iOS-support.${BUILD}.tar.gz"

echo "Downloading Python ${PYTHON_VERSION} iOS support (${BUILD})..."
curl -L -o "$TARBALL" "$URL"

echo "Extracting to $DEST_DIR..."
tar xzf "$TARBALL" -C "$DEST_DIR"

# Clean up files we don't need
rm -rf "$DEST_DIR/testbed" "$DEST_DIR/VERSIONS"
rm -f "$TARBALL"

# Fix modulemap for SPM compatibility:
# BeeWare ships a plain `module Python` but when used as an xcframework
# inside a .framework bundle, clang requires `framework module Python`.
# Also copy modulemap to Modules/ where SPM expects it.
echo "Patching modulemap for SPM..."
for slice in ios-arm64 ios-arm64_x86_64-simulator; do
    FW="$XCFRAMEWORK_DIR/$slice/Python.framework"
    mkdir -p "$FW/Modules"
    sed 's/^module Python {/framework module Python {/' \
        "$FW/Headers/module.modulemap" > "$FW/Modules/module.modulemap"
done

# Install pre-bundled Python packages
SITE_PACKAGES="$DEST_DIR/site-packages"
if [ ! -d "$SITE_PACKAGES" ]; then
    echo "Installing Python packages..."
    python3 -m pip install --target="$SITE_PACKAGES" \
        requests httpx aiohttp \
        ytmusicapi spotipy telethon google-genai \
        pyaes rsa websockets \
        --quiet 2>/dev/null || {
        echo "Warning: pip install failed. site-packages will be empty."
    }
    # Remove C extensions (won't work on iOS) and unnecessary files
    find "$SITE_PACKAGES" -name "*.so" -delete 2>/dev/null
    find "$SITE_PACKAGES" -name "*.dylib" -delete 2>/dev/null
    find "$SITE_PACKAGES" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null
    find "$SITE_PACKAGES" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    rm -rf "$SITE_PACKAGES/bin" "$SITE_PACKAGES/redis"
    rm -rf "$SITE_PACKAGES/cryptography" "$SITE_PACKAGES/cffi"
    rm -rf "$SITE_PACKAGES/pydantic_core" "$SITE_PACKAGES/pydantic"
    # Patch spotipy to make redis optional
    if [ -f "$SITE_PACKAGES/spotipy/cache_handler.py" ]; then
        sed -i '' 's/^from redis import RedisError$/try:\n    from redis import RedisError\nexcept ImportError:\n    class RedisError(Exception): pass/' \
            "$SITE_PACKAGES/spotipy/cache_handler.py" 2>/dev/null || true
    fi
    echo "Installed site-packages at $SITE_PACKAGES"
else
    echo "site-packages already exists at $SITE_PACKAGES"
fi

echo "Done! Python 3.13 ready at $XCFRAMEWORK_DIR"
