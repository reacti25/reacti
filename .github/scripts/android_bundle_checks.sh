#!/usr/bin/env bash
# Checks an Android App Bundle (.aab) for the two things that make Google Play
# refuse an upload outright (Android plan, Step 4b):
#
#   1. Signature: the bundle must be signed with Reacti's upload key, never the
#      debug key. Compared with the public fingerprint in
#      app/android/upload-key.sha256.
#   2. 16 KB pages: since 2025-11-01 every native library (.so) for 64-bit
#      devices must have its ELF LOAD segments aligned to at least 16 KB
#      (2**14). This is the check from Google's "Prepare your apps for 16 KB"
#      guide; a plugin built the old way fails it.
#
# Usage (from app/, after `flutter build appbundle` and a build that installed
# the NDK): android_bundle_checks.sh build/app/outputs/bundle/release/app-release.aab
# Set CHECK_SIGNATURE=0 where the upload-key secret is unavailable (Dependabot
# and fork PRs build with the debug key); the 16 KB check always runs.
set -uo pipefail

aab="$1"
failed=0

# --- 1. Signature --------------------------------------------------------
if [ "${CHECK_SIGNATURE:-1}" = "1" ]; then
  want=$(tr -d '\r\n' < android/upload-key.sha256)
  got=$(keytool -printcert -jarfile "$aab" 2>/dev/null | sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1)
  if [ "$got" = "$want" ]; then
    echo "Signature: signed with the upload key."
  else
    echo "::error::$aab is signed with ${got:-nothing readable}, not the upload key"
    failed=1
  fi
else
  echo "::notice::Signature check skipped (no upload key in this build)."
fi

# --- 2. 16 KB alignment ----------------------------------------------------
ndk=$(ls -d "$ANDROID_SDK_ROOT"/ndk/*/ 2> /dev/null | sort -V | tail -n 1)
objdump="${ndk}toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
if [ ! -x "$objdump" ]; then
  echo "::error::llvm-objdump not found under $ndk; cannot check 16 KB alignment"
  exit 1
fi

libs=$(mktemp -d)
unzip -q -o "$aab" 'base/lib/arm64-v8a/*' 'base/lib/x86_64/*' -d "$libs" 2> /dev/null || true
count=0
while IFS= read -r so; do
  count=$((count + 1))
  # Smallest LOAD alignment in the file, e.g. 2**14; anything under 14 fails.
  min=$("$objdump" -p "$so" | awk '/LOAD/ { split($NF, a, "\\*\\*"); print a[2] }' | sort -n | head -n 1)
  if [ -z "$min" ] || [ "$min" -lt 14 ]; then
    echo "::error::${so#"$libs"/} is aligned to 2**${min:-?}, not 16 KB (2**14)"
    failed=1
  fi
done < <(find "$libs" -name '*.so')
rm -rf "$libs"

if [ "$count" -eq 0 ]; then
  echo "::error::no 64-bit native libraries found in $aab; the check proved nothing"
  failed=1
elif [ "$failed" -eq 0 ]; then
  echo "16 KB: all $count 64-bit native libraries are aligned to 16 KB."
fi
exit "$failed"
