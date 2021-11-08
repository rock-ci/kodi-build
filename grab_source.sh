#!/bin/bash
set -euo pipefail
BASE_VERSION="$1"
DEV_URL="$2"
DEB_ARCH="$3"

AFTER_EPOCH=${BASE_VERSION#*:}
UPSTREAM_VER=${AFTER_EPOCH%-*}
DEBIAN_REV=${AFTER_EPOCH##*-}
OUR_REV="${4:-$DEBIAN_REV}"

echo "***************************"
echo "** Downloading artifacts **"
echo "***************************"

FILE_VER="${UPSTREAM_VER}-${OUR_REV}"
for file_to_get in kodi-${FILE_VER}-config.tar.bz2 kodi-addons-dev_${FILE_VER}_${DEB_ARCH}.deb kodi-addons-dev-common_${FILE_VER}_${DEB_ARCH}.deb
do
    echo "* $file_to_get"
    curl \
        --location \
        --silent \
        --netrc-file <(cat <<<"machine $FILEBUCKET_SERVER login $FILEBUCKET_USER password $FILEBUCKET_PASSWORD") \
        --output "$file_to_get" \
        "${DEV_URL}/$file_to_get"
done

echo "*************************"
echo "** Unpacking artifacts **"
echo "*************************"

tar xjf kodi-${FILE_VER}-config.tar.bz2
sudo apt-get -y -u -V install ./kodi-addons-dev_${FILE_VER}_${DEB_ARCH}.deb ./kodi-addons-dev-common_${FILE_VER}_${DEB_ARCH}.deb
