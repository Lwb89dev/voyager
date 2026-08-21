#!/usr/bin/env bash
# Builds Voyager's working copy of Roadstr: a mirror of the upstream checkout
# with Voyager's own UI patches applied on top.
#
# THE PROBLEM THIS SOLVES
#
# Voyager needs two things that pull in opposite directions. It has to track
# Roadstr — every fix to routing, speed cameras or ZTL warnings should arrive
# on the next build, because that is the part nobody wants to maintain twice.
# And it has to change Roadstr's map chrome, because a UI laid out for a phone
# held in the hand wastes most of a landscape dashboard.
#
# A fork gives the second and loses the first. Editing the upstream checkout in
# place gives both and destroys someone's working tree. So: mirror upstream into
# .roadstr/ (gitignored, never edited by hand), apply the patches in
# patches/roadstr/, and point the pubspec path dependency at the mirror. The
# original checkout is only ever read.
#
# When upstream moves under a patch, `patch` fails and so does this script. That
# is the point: a patch that no longer applies is a UI change that needs looking
# at, not something to discover as a rendering bug three builds later.
set -euo pipefail

SOURCE="${ROADSTR_SOURCE:-../roadstr}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="$HERE/.roadstr"
PATCHES="$HERE/patches/roadstr"

if [[ ! -f "$SOURCE/pubspec.yaml" ]]; then
  echo "Roadstr checkout not found at $SOURCE" >&2
  echo "Set ROADSTR_SOURCE, or pass the path as the first argument." >&2
  exit 1
fi
[[ $# -ge 1 ]] && SOURCE="$1"

echo "==> Mirroring $SOURCE into .roadstr"
# --delete so a file removed upstream disappears here too; excluding .git keeps
# the mirror from looking like a repository anyone might commit into, and
# excluding the build outputs keeps the copy quick.
rsync -a --delete \
  --exclude '.git/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude '.flutter-plugins-dependencies' \
  "$SOURCE/" "$MIRROR/"

upstream_version="$(grep -m1 '^version:' "$MIRROR/pubspec.yaml" | awk '{print $2}')"
echo "    upstream version $upstream_version"

echo "==> Applying Voyager patches"
shopt -s nullglob
patches=("$PATCHES"/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "    none"
else
  for p in "${patches[@]}"; do
    name="$(basename "$p")"
    if patch -p1 -d "$MIRROR" --forward --silent < "$p"; then
      echo "    applied $name"
    else
      echo >&2
      echo "FAILED to apply $name" >&2
      echo >&2
      echo "Roadstr has changed underneath this patch. Rebase it against the" >&2
      echo "current upstream file and commit the result — do not skip it, and" >&2
      echo "do not edit .roadstr/ by hand: the next run overwrites it." >&2
      echo "See patches/roadstr/README.md." >&2
      exit 1
    fi
  done
fi

# ── Runtime assets ─────────────────────────────────────────────────────────
# Roadstr is an application, so its code loads assets by their app-root key —
# rootBundle.load('assets/espeak-ng-data.tar.gz'). Consumed as a package its
# assets land under packages/roadstr/…, and every one of those lookups fails.
# Flutter's asset list cannot reference a path outside the project, so the files
# have to be here. libespeak-ng.so is the same story: dart:ffi loads it from the
# app's own native library directory, which means Voyager's APK.
echo "==> Copying runtime assets"
mkdir -p "$HERE/assets"
for item in espeak-ng-data.tar.gz kokoro_phrases cursors icons; do
  src="$MIRROR/assets/$item"
  if [[ -e "$src" ]]; then
    rm -rf "$HERE/assets/$item"
    cp -r "$src" "$HERE/assets/$item"
    echo "    assets/$item"
  fi
done

for abi in arm64-v8a armeabi-v7a x86_64; do
  src="$MIRROR/android/app/src/main/jniLibs/$abi/libespeak-ng.so"
  if [[ -f "$src" ]]; then
    mkdir -p "$HERE/android/app/src/main/jniLibs/$abi"
    cp "$src" "$HERE/android/app/src/main/jniLibs/$abi/"
    echo "    jniLibs/$abi/libespeak-ng.so"
  fi
done

echo "==> Done. Run 'flutter pub get' if the Roadstr version changed."
