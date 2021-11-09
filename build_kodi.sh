#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${SCRIPT_DIR}/lib/versions.sh"

echo ""
echo "Upstream version: $UPSTREAM_VER"
echo "Debian revision:  $DEBIAN_REV"
echo "Our revision      $OUR_REV"
echo "Debian arch:      $DEB_ARCH"
echo ""

cd "kodi-${UPSTREAM_VER}"

echo "**********************"
echo "** Building package **"
echo "**********************"

dpkg-buildpackage -b -uc -us

echo "**************"
echo "** All done **"
echo "**************"
