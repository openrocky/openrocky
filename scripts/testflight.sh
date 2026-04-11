#!/usr/bin/env bash
#
# OpenRocky — Voice-first AI Agent
# https://github.com/openrocky/openrocky
#
# Developed by everettjf with the assistance of Claude Code and Codex.
# Date: 2026-03-25
# Copyright (c) 2026 everettjf. All rights reserved.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/OpenRocky/OpenRocky.xcodeproj}"
SCHEME="${SCHEME:-OpenRocky}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/build/testflight}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARTIFACTS_DIR/$SCHEME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ARTIFACTS_DIR/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ARTIFACTS_DIR/ExportOptions.plist}"
MODE="${1:-all}"

ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"
TESTFLIGHT_INTERNAL_ONLY="${TESTFLIGHT_INTERNAL_ONLY:-0}"

log() {
  printf '[testflight] %s\n' "$*"
}

fail() {
  printf '[testflight] error: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

build_setting() {
  local key="$1"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' -v key="$key" '$1 ~ key {print $2; exit}'
}

prepare_dirs() {
  mkdir -p "$ARTIFACTS_DIR" "$EXPORT_PATH"
}

write_export_options() {
  local team_id="$1"
  local bundle_id="$2"
  local internal_only_flag="false"
  if [[ "$TESTFLIGHT_INTERNAL_ONLY" == "1" ]]; then
    internal_only_flag="true"
  fi

  cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${team_id}</string>
  <key>testFlightInternalTestingOnly</key>
  <${internal_only_flag}/>
  <key>uploadSymbols</key>
  <true/>
  <key>distributionBundleIdentifier</key>
  <string>${bundle_id}</string>
</dict>
</plist>
EOF
}

archive_app() {
  local extra_flags=()
  if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    extra_flags+=(-allowProvisioningUpdates)
  fi

  log "archiving $SCHEME ($CONFIGURATION)"
  rm -rf "$ARCHIVE_PATH"
  xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    "${extra_flags[@]}"
}

export_ipa() {
  local team_id="$1"
  local bundle_id="$2"

  log "exporting ipa"
  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"
  write_export_options "$team_id" "$bundle_id"

  local extra_flags=()
  if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    extra_flags+=(-allowProvisioningUpdates)
  fi

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    "${extra_flags[@]}"
}

ipa_path() {
  find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit
}

upload_ipa() {
  local ipa="$1"
  local auth_args=()

  if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
    auth_args+=(--api-key "$ASC_API_KEY_ID" --api-issuer "$ASC_API_ISSUER_ID")
    if [[ -n "${ASC_API_KEY_P8_PATH:-}" ]]; then
      auth_args+=(--p8-file-path "$ASC_API_KEY_P8_PATH")
    fi
  elif [[ -n "${ALTOOL_USERNAME:-}" && -n "${ALTOOL_PASSWORD:-}" ]]; then
    auth_args+=(--username "$ALTOOL_USERNAME" --password "$ALTOOL_PASSWORD")
  else
    fail "set ASC_API_KEY_ID + ASC_API_ISSUER_ID (+ optional ASC_API_KEY_P8_PATH), or ALTOOL_USERNAME + ALTOOL_PASSWORD"
  fi

  log "uploading $(basename "$ipa") to TestFlight"
  xcrun altool \
    --upload-app \
    --file "$ipa" \
    --type ios \
    --output-format json \
    "${auth_args[@]}"
}

print_summary() {
  local ipa="$1"
  local version="$2"
  local build="$3"
  local bundle_id="$4"

  log "bundle id: $bundle_id"
  log "version: $version ($build)"
  log "archive: $ARCHIVE_PATH"
  log "ipa: $ipa"
}

main() {
  require_tool xcodebuild
  require_tool xcrun

  prepare_dirs

  local bundle_id
  local team_id
  local version
  local build

  bundle_id="$(build_setting "PRODUCT_BUNDLE_IDENTIFIER")"
  team_id="$(build_setting "DEVELOPMENT_TEAM")"
  version="$(build_setting "MARKETING_VERSION")"
  build="$(build_setting "CURRENT_PROJECT_VERSION")"

  [[ -n "$bundle_id" ]] || fail "could not resolve PRODUCT_BUNDLE_IDENTIFIER"
  [[ -n "$team_id" ]] || fail "could not resolve DEVELOPMENT_TEAM"
  [[ -n "$version" ]] || fail "could not resolve MARKETING_VERSION"
  [[ -n "$build" ]] || fail "could not resolve CURRENT_PROJECT_VERSION"

  case "$MODE" in
    archive)
      archive_app
      ;;
    export)
      [[ -d "$ARCHIVE_PATH" ]] || fail "archive not found at $ARCHIVE_PATH"
      export_ipa "$team_id" "$bundle_id"
      ;;
    upload)
      local ipa_only
      ipa_only="$(ipa_path)"
      [[ -n "$ipa_only" ]] || fail "ipa not found under $EXPORT_PATH"
      upload_ipa "$ipa_only"
      print_summary "$ipa_only" "$version" "$build" "$bundle_id"
      ;;
    all)
      archive_app
      export_ipa "$team_id" "$bundle_id"
      local ipa
      ipa="$(ipa_path)"
      [[ -n "$ipa" ]] || fail "ipa export failed under $EXPORT_PATH"
      upload_ipa "$ipa"
      print_summary "$ipa" "$version" "$build" "$bundle_id"
      ;;
    *)
      fail "usage: scripts/testflight.sh [archive|export|upload|all]"
      ;;
  esac
}

main "$@"
