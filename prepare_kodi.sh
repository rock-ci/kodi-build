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


echo "***********************"
echo "** Retrieving source **"
echo "***********************"

apt-get -y source "kodi=${BASE_VERSION}"

cd "kodi-${UPSTREAM_VER}"


echo "************************"
echo "** Patching changelog **"
echo "************************"

cat << EOF | tee debian/changelog.new
kodi (10:${UPSTREAM_VER}-${OUR_REV}) unstable; urgency=medium

  * Support Video4Linux2 hardware deinterlacing
  * Support Video4Linux2 stateless video decode acceleration

 -- Hugh Cole-Baker <sigmaris@gmail.com>  $(date '+%a, %d %b %Y %H:%M:%S %z')

EOF
cat debian/changelog >> debian/changelog.new
mv debian/changelog.new debian/changelog

echo "***************************"
echo "** Applying kodi patches **"
echo "***************************"

for patchfile in "${SCRIPT_DIR}"/patches/*.patch
do
    echo "* Applying $patchfile ..."
    patch -p1 < "$patchfile"
done

echo "*************************"
echo "** Configuring package **"
echo "*************************"

debian/rules override_dh_auto_configure

echo "*************************"
echo "** Creating tarball... **"
echo "*************************"

cd ..
tar cjf kodi-config_${UPSTREAM_VER}-${OUR_REV}_${DEB_ARCH}.tar.bz2 "kodi-${UPSTREAM_VER}"

echo "******************"
echo "** Prepare done **"
echo "******************"
