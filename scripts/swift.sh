#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"

# Some CLT installations contain a Swift 5.10 private manifest interface next to
# a Swift 6 runtime. Use its matching public interface locally, without modifying
# the toolchain. SwiftPM documents SWIFTPM_CUSTOM_LIBS_DIR in CONTRIBUTING.md.
daybook_swift_bin="$(dirname "$(xcrun --find swiftc)")"
daybook_pm="$daybook_swift_bin/../lib/swift/pm"
daybook_public="$daybook_pm/ManifestAPI/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"
daybook_private="$daybook_pm/ManifestAPI/PackageDescription.swiftmodule/arm64-apple-macos.private.swiftinterface"
if [[ -f "$daybook_private" ]] && grep -q 'Swift version 5.10' "$daybook_private" && grep -q 'Swift version 6.' "$daybook_public"; then
    daybook_local="$PWD/.build/manifest-runtime/ManifestAPI"
    mkdir -p "$daybook_local/PackageDescription.swiftmodule"
    cp "$daybook_public" "$daybook_local/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"
    ln -sf "$daybook_pm/ManifestAPI/libPackageDescription.dylib" "$daybook_local/libPackageDescription.dylib"
    export SWIFTPM_CUSTOM_LIBS_DIR="$PWD/.build/manifest-runtime"
fi

daybook_action="${1:-build}"
if [[ $# -gt 0 ]]; then shift; fi
daybook_extra=(-j 4)
daybook_old_map="$daybook_swift_bin/../include/swift/module.modulemap"
daybook_new_map="$daybook_swift_bin/../include/swift/bridging.modulemap"
if [[ -f "$daybook_old_map" && -f "$daybook_new_map" ]] && grep -q 'module SwiftBridging' "$daybook_old_map" && grep -q 'module SwiftBridging' "$daybook_new_map"; then
    mkdir -p .build/toolchain-overlay
    : > .build/toolchain-overlay/empty.modulemap
    python3 - "$daybook_old_map" "$PWD/.build/toolchain-overlay" <<'PY'
import json, pathlib, sys
old, folder = pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2])
(folder / 'overlay.json').write_text(json.dumps({'version': 0, 'roots': [
    {'type': 'file', 'name': str(old), 'external-contents': str(folder / 'empty.modulemap')}
]}))
PY
    daybook_extra+=(-Xswiftc -vfsoverlay -Xswiftc "$PWD/.build/toolchain-overlay/overlay.json")
fi
exec xcrun swift "$daybook_action" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security --scratch-path .build "${daybook_extra[@]}" "$@"
