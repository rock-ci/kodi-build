#!/bin/bash
set -euo pipefail
BASE_VERSION="$1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"


if [[ -z "$BASE_VERSION" ]]
then
    echo "Usage: $0 <base version> [our revision override]"
    exit 1
fi
after_epoch=${BASE_VERSION#*:}
upstream_ver=${after_epoch%-*}
debian_rev=${after_epoch##*-}
our_rev="${2:-$debian_rev}"

echo ""
echo "Upstream version: $upstream_ver"
echo "Debian revision:  $debian_rev"
echo "Our revision      $our_rev"
echo ""


echo "***********************"
echo "** Retrieving source **"
echo "***********************"

apt-get -y source "kodi=${BASE_VERSION}"

cd "kodi-${upstream_ver}"


echo "************************"
echo "** Patching changelog **"
echo "************************"

cat << EOF | tee debian/changelog.new
kodi (10:${upstream_ver}-${our_rev}) unstable; urgency=medium

  * Use APP_RENDER_SYSTEM=gles instead of desktop OpenGL

 -- Hugh Cole-Baker <sigmaris@gmail.com>  $(date '+%a, %d %b %Y %H:%M:%S %z')

EOF
cat debian/changelog >> debian/changelog.new
mv debian/changelog.new debian/changelog


echo "********************************"
echo "** Patching APP_RENDER_SYSTEM **"
echo "********************************"

sed -i -e "s/-DAPP_RENDER_SYSTEM=gl /-DAPP_RENDER_SYSTEM=gles /g" debian/rules
grep APP_RENDER_SYSTEM=gles debian/rules


echo "***************************"
echo "** Applying kodi patches **"
echo "***************************"

for patchfile in "${SCRIPT_DIR}"/patches/*.patch
do
    echo "* Applying $patchfile ..."
    patch -p1 < "$patchfile"
done

echo "**********************"
echo "** Building package **"
echo "**********************"

dpkg-buildpackage -b -uc -us

echo "**************"
echo "** All done **"
echo "**************"
