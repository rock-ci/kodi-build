#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${SCRIPT_DIR}/lib/versions.sh"

echo ""
echo "Addon to build:   $ADDON_NAME (from Debian source)"
echo "Base version:     $BASE_VERSION"
echo "Upstream version: $UPSTREAM_VER"
echo "Debian revision:  $DEBIAN_REV"
echo "Our revision      $OUR_REV"
echo ""

apt source "${ADDON_NAME}=${BASE_VERSION}"

cd "${ADDON_NAME}-${UPSTREAM_VER}"

echo "************************"
echo "** Patching changelog **"
echo "************************"

cat << EOF | tee debian/changelog.new
${ADDON_NAME} (10:${UPSTREAM_VER}-${OUR_REV}) unstable; urgency=medium

* Use APP_RENDER_SYSTEM=gles instead of desktop OpenGL

-- Hugh Cole-Baker <sigmaris@gmail.com>  $(date '+%a, %d %b %Y %H:%M:%S %z')

EOF
cat debian/changelog >> debian/changelog.new
mv debian/changelog.new debian/changelog

echo "**********************"
echo "** Building package **"
echo "**********************"

dpkg-buildpackage -b -uc -us

echo "**************"
echo "** All done **"
echo "**************"
