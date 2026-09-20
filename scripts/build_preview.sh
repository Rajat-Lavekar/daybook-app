#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/swift.sh build --product DaybookPreview
mkdir -p .build/Daybook.app/Contents/MacOS
cp .build/debug/DaybookPreview .build/Daybook.app/Contents/MacOS/DaybookPreview
python3 - <<'PY'
import pathlib, plistlib
root = pathlib.Path.cwd()
info = {
    'CFBundleName': 'Daybook', 'CFBundleDisplayName': 'Daybook',
    'CFBundleIdentifier': 'local.daybook.preview', 'CFBundleExecutable': 'DaybookPreview',
    'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '0.3.0',
    'CFBundleVersion': '5', 'LSMinimumSystemVersion': '14.0',
    'NSHighResolutionCapable': True,
    'DaybookPreviewDataDirectory': str(root / 'private-data' / 'preview'),
}
with (root / '.build/Daybook.app/Contents/Info.plist').open('wb') as f:
    plistlib.dump(info, f)
PY
codesign --force --sign - .build/Daybook.app
printf 'Built %s/.build/Daybook.app\n' "$PWD"
