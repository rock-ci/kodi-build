#!/bin/bash -e

: "${FILEBUCKET_USER:=drone.io}"

echo "*********************************"
echo "*** Uploading built artifacts ***"
echo "*********************************"

for pkgfile in "$@"
do
	if [[ -f "$pkgfile" ]]
	then
		echo " ${pkgfile}..."
		curl --silent --upload-file "$pkgfile" --netrc-file <(cat <<<"machine $FILEBUCKET_SERVER login $FILEBUCKET_USER password $FILEBUCKET_PASSWORD") "https://${FILEBUCKET_SERVER}/filebucket/"
	else
		echo "Warning: No matches for: $pkgfile"
	fi
done

echo "*************"
echo "*** Done! ***"
echo "*************"
