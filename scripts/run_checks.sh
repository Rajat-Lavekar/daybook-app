#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/swift.sh build --product daybook
bash scripts/swift.sh build --product DaybookChecks
exec .build/debug/DaybookChecks
