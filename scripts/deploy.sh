#!/usr/bin/env bash
#
# OpenRocky — Voice-first AI Agent
# https://github.com/openrocky/openrocky
#
# Developed by everettjf with the assistance of Claude Code and Codex.
# Date: 2026-03-25
# Copyright (c) 2026 everettjf. All rights reserved.
#
#
# Rocky Deploy — one-command build & upload to TestFlight
#
# Usage:
#   ./scripts/deploy.sh              # full: setup → build → archive → upload
#   ./scripts/deploy.sh --skip-setup # skip Python setup
#   ./scripts/deploy.sh --archive    # archive only, no upload
#
# Auth (set in shell profile or before running):
#   export APPLE_ID="you@example.com"
#   export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/OpenRocky/OpenRocky.xcodeproj"
SCHEME="OpenRocky"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/OpenRocky.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"

SKIP_SETUP=0
ARCHIVE_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --skip-setup) SKIP_SETUP=1 ;;
        --archive)    ARCHIVE_ONLY=1 ;;
    esac
done

log() { printf "\033[1;36m[deploy]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[deploy]\033[0m %s\n" "$*" >&2; exit 1; }

# ── Step 0: Setup dependencies ───────────────────────────────────────────────
if [[ "$SKIP_SETUP" -eq 0 ]]; then
    log "Setting up Python framework..."
    bash "$ROOT/scripts/setup_python.sh"
fi

# ── Step 1: Auto-increment build number ──────────────────────────────────────
log "Incrementing build number..."
CURRENT_BUILD=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/CURRENT_PROJECT_VERSION/ {print $2; exit}')
NEW_BUILD=$((CURRENT_BUILD + 1))
# Skip build numbers containing digit 4
while [[ "$NEW_BUILD" == *4* ]]; do
    NEW_BUILD=$((NEW_BUILD + 1))
done

sed -i '' "s/CURRENT_PROJECT_VERSION = ${CURRENT_BUILD}/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/g" \
    "$PROJECT/project.pbxproj"

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}')
TEAM_ID=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/DEVELOPMENT_TEAM/ {print $2; exit}')

log "Version: $VERSION ($NEW_BUILD) | Team: $TEAM_ID"

# ── Step 1.5: Commit version bump ───────────────────────────────────────────
log "Committing version bump..."
git -C "$ROOT" add "$PROJECT/project.pbxproj"
git -C "$ROOT" commit -m "chore: bump build number to $NEW_BUILD"

# ── Step 2: Archive ──────────────────────────────────────────────────────────
log "Archiving (Release)..."
mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet

[[ -d "$ARCHIVE" ]] || err "Archive failed"
log "Archive OK"

if [[ "$ARCHIVE_ONLY" -eq 1 ]]; then
    log "Done! Archive at $ARCHIVE"
    exit 0
fi

# ── Step 3: Export IPA ───────────────────────────────────────────────────────
# Always export locally first (destination=export), then upload separately.
# "destination=upload" requires Xcode GUI account session which fails in CLI.

log "Exporting IPA..."
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates

IPA=$(find "$EXPORT_DIR" -name "*.ipa" -print -quit)
[[ -n "$IPA" ]] || err "IPA not found after export"
log "IPA exported: $IPA"

# ── Step 4: Upload to TestFlight ─────────────────────────────────────────────

if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
    log "Uploading via ASC API Key..."
    API_KEY_ARGS=(--apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID")
    xcrun altool --upload-app --file "$IPA" --type ios "${API_KEY_ARGS[@]}"
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    log "Uploading via Apple ID ($APPLE_ID)..."
    xcrun altool --upload-app --file "$IPA" --type ios \
        --username "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD"
else
    log "No upload credentials configured."
    log "Set APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD, or ASC_API_KEY_ID + ASC_API_ISSUER_ID."
    log "Upload manually: open Transporter.app and drag $IPA"
    exit 0
fi

# ── Done ─────────────────────────────────────────────────────────────────────
log ""
log "=========================================="
log "  Uploaded to TestFlight!"
log "  OpenRocky $VERSION ($NEW_BUILD)"
log "=========================================="
log ""
log "Check status: https://appstoreconnect.apple.com"
