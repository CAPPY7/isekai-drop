#!/usr/bin/env bash
# Publishes one platform's files to the pre-release "latest-build".
#
#   latest_build.sh <platform> <stale-regex> <notes-line> <file>...
#
# - Uploads <file>... with --clobber (stable names, so each build REPLACES
#   the last one instead of piling up numbered files).
# - Deletes this platform's old assets: names matching <stale-regex> that are
#   not one of the files just uploaded. Other platforms' files are never
#   touched, so Android / iOS / Windows workflows can publish at the same time.
# - Puts <notes-line> (version / build number) into the release text on this
#   platform's own line, keeping the other platforms' lines.
# Never deletes or publishes the release itself.
set -euo pipefail
platform=$1
stale=$2
line=$3
shift 3
R="$GITHUB_REPOSITORY"
TAG=latest-build
TITLE="Latest test build (DEV-signed, not a real release)"

base_notes() {
  cat <<'TXT'
Automatic TEST build of Isekai Drop. Signed with the throwaway DEV key (Android). Not for public distribution.
Each new build replaces the files below (no build number in the file names; the build numbers are listed here).

- isekai-drop-android-arm64.apk: smaller file for most phones from about 2017 on.
- isekai-drop-android-universal.apk: works on all Android phones.
- isekai-drop-windows-setup.exe: Windows 10/11 installer (one file, no admin needed). NOT code-signed: SmartScreen warns and Windows 11 Smart App Control blocks it. See README "Windows".
- isekai-drop-ios-unsigned.ipa: UNSIGNED. Needs sideloading (AltStore/Sideloadly with your own free Apple ID) and expires after 7 days. See README.

Builds:
<!--builds-->
TXT
}

if ! gh release view "$TAG" -R "$R" >/dev/null 2>&1; then
  # Another platform may create it at the same moment; that is fine.
  gh release create "$TAG" -R "$R" --prerelease --latest=false \
    --title "$TITLE" --notes "$(base_notes)" || true
fi

gh release upload "$TAG" "$@" --clobber -R "$R"

keep=" "
for f in "$@"; do keep="$keep$(basename "$f") "; done
gh release view "$TAG" -R "$R" --json assets -q '.assets[].name' |
  while read -r name; do
    if [[ "$name" =~ $stale ]] && [[ "$keep" != *" $name "* ]]; then
      echo "Deleting old asset $name"
      gh release delete-asset "$TAG" "$name" -y -R "$R"
    fi
  done

# Release text: replace only this platform's line. Re-checked because two
# platforms can edit at the same time.
for attempt in 1 2 3 4 5; do
  gh release view "$TAG" -R "$R" --json body -q .body > "$RUNNER_TEMP/body.txt"
  base_notes > "$RUNNER_TEMP/base.txt"
  PLATFORM="$platform" LINE="$line" python3 - <<'PY'
import os
tmp = os.environ["RUNNER_TEMP"]
body = open(f"{tmp}/body.txt").read()
base = open(f"{tmp}/base.txt").read().rstrip("\n")
tag = f"<!--{os.environ['PLATFORM']}-->"
lines = []
if "<!--builds-->" in body:
    lines = [l for l in body.split("<!--builds-->", 1)[1].splitlines()
             if l.strip() and tag not in l]
lines.append(f"- {os.environ['LINE']} {tag}")
lines.sort()
open(f"{tmp}/new.txt", "w").write(base + "\n" + "\n".join(lines) + "\n")
PY
  gh release edit "$TAG" -R "$R" --notes-file "$RUNNER_TEMP/new.txt" >/dev/null
  sleep $((RANDOM % 5 + 3))
  if gh release view "$TAG" -R "$R" --json body -q .body | grep -qF "$line"; then
    break
  fi
  echo "Release text changed by another platform, retrying ($attempt)"
done

gh release view "$TAG" -R "$R" --json assets -q '.assets[].name'
