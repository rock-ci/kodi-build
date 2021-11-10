#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${SCRIPT_DIR}/lib/versions.sh"

echo "***************************"
echo "** Downloading artifacts **"
echo "***************************"

FILE_VER="${UPSTREAM_VER}-${OUR_REV}"
for file_to_get in kodi-config_${FILE_VER}_${DEB_ARCH}.tar.bz2 kodi-addons-dev_${FILE_VER}_${DEB_ARCH}.deb kodi-addons-dev-common_${FILE_VER}_all.deb
do
    echo "* $file_to_get"
    curl \
        --location \
        --silent \
        --netrc-file <(cat <<<"machine $FILEBUCKET_SERVER login $FILEBUCKET_USER password $FILEBUCKET_PASSWORD") \
        --output "$file_to_get" \
        "https://${FILEBUCKET_SERVER}/${ARTIFACT_PREFIX}${file_to_get}"
done

echo "*************************"
echo "** Unpacking artifacts **"
echo "*************************"

tar xjf kodi-config_${FILE_VER}_${DEB_ARCH}.tar.bz2
