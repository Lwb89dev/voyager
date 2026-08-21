#!/usr/bin/env bash
# Fails if a built APK contains Google proprietary libraries.
#
# Voyager inherits Roadstr's position: location goes through Android's own
# LocationManager, nothing calls Play Services, and the classes should not be in
# the APK at all. They arrive as transitive dependencies of Flutter plugins if
# nobody stops them, and once packaged they are dead weight that also makes the
# app look dependent on something it deliberately avoids — F-Droid's scanner
# reports them, and it is right to.
#
# The Gradle build excludes the groups at the root (android/build.gradle.kts),
# but an exclusion is a claim. This checks the artifact.
set -euo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  echo "Usage: tools/check_no_google.sh [path-to-apk]" >&2
  exit 1
fi

echo "Scanning $(basename "$APK") ($(du -h "$APK" | cut -f1))"

# Searched as raw bytes across the whole archive: class names survive in the dex
# string pool whether or not the code is reachable, which is exactly what needs
# to be absent.
patterns=(
  "com/google/android/gms"
  "com/google/android/play/core"
  "com/google/firebase"
)

failed=0
for pattern in "${patterns[@]}"; do
  count="$(grep -a -c "$pattern" "$APK" || true)"
  if [[ "$count" -gt 0 ]]; then
    echo "  FOUND $pattern ($count matches)"
    failed=1
  else
    echo "  clean: $pattern"
  fi
done

if (( failed )); then
  echo >&2
  echo "Google proprietary classes are in the APK." >&2
  echo "Check the exclusions in android/build.gradle.kts and whether a newly" >&2
  echo "added plugin pulls them in." >&2
  exit 1
fi

echo "No Google proprietary libraries in the APK."
