#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen"
  exit 1
fi
xcodegen generate
echo "Created VioletScan.xcodeproj — open it in Xcode."
echo "Signing: set your Team for com.violetscan.app"
echo "Device: LiDAR iPhone/iPad (12 Pro / 13 Pro / 14 Pro / 15 Pro / 16 Pro / Pro iPad)."
