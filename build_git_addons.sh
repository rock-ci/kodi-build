#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "${SCRIPT_DIR}/lib/versions.sh"

: "${DISTRO_CODENAME:=$(lsb_release -cs)}"

WORK_DIR="$(pwd)"
ADDONS_LOG_DIR="${WORK_DIR}/addons_logs"
mkdir -p "$ADDONS_LOG_DIR"

KODI_SOURCE_DIR="${WORK_DIR}/kodi-${UPSTREAM_VER}"
cd "${KODI_SOURCE_DIR}/obj-${ARCH_TRIPLET}"
ADDON_DEPENDS_PATH="$(pwd)/build"

mkdir -p build/addons_build
cd build/addons_build

echo "*****************************"
echo "*** Configuring addons... ***"
echo "*****************************"

cmake \
  -DBUILD_DIR="$(pwd)" \
  -DCORE_SOURCE_DIR="$KODI_SOURCE_DIR" \
  -DADDONS_TO_BUILD="$ADDONS_REGEX" \
  -DADDON_DEPENDS_PATH="$ADDON_DEPENDS_PATH" \
  "${KODI_SOURCE_DIR}/cmake/addons/"

echo "**************************"
echo "*** Building addons... ***"
echo "**************************"

declare -a ADDONS_BUILD_OK
declare -a ADDONS_BUILD_FAILED
set +e

for D in $(ls . --ignore="*prefix")
do
	if [ -d "${D}/debian" ]
	then

		# Build libretro core libraries
		if [[ "${D}" == game.libretro.* ]]
		then
			for DEP in ${D}/depends/common/*
			do
				BASE_DEP="$(basename "$DEP")"
				echo "**********************************************"
				echo "*** Building libretro dependency $BASE_DEP ***"
				echo "**********************************************"
				BUILD_LOG="${ADDONS_LOG_DIR}/${D}-${BASE_DEP}.log"
				cmake --build . --target "$BASE_DEP" -- -j$(getconf _NPROCESSORS_ONLN) > "$BUILD_LOG" 2>&1

				if [ $? -ne 0 ]
				then
					ADDONS_BUILD_FAILED+=("${D}(${BASE_DEP})")
					cat "$BUILD_LOG"
					echo "********************************************"
					echo "*** Failed building dependency $BASE_DEP ***"
					echo "********************************************"
					continue 2
				fi

				# Remove build dependency on this libretro core
				sed -i -e 's/kodi-addon-dev,/kodi-addon-dev/' -e "/libretro-${BASE_DEP} \(.*\) \| ${BASE_DEP} \(.*\)/d" "${D}/debian/control"
			done
			# Set env variable during build so this built lib is found & used
			EXTRA_ENV="CMAKE_LIBRARY_PATH=${ADDON_DEPENDS_PATH}/lib"
		else
			EXTRA_ENV=""
		fi

		cd "${D}"

		echo "********************************"
		echo "*** Building binary addon $D ***"
		echo "********************************"

		# Debian renamed this package to make it plural:
		sed -i -e "s/kodi-addon-dev/kodi-addons-dev/g" debian/control

		VERSION_FILE="addon.xml.in"
		[[ ! -f "${D}/addon.xml.in" ]] && VERSION_FILE="addon.xml"
		ADDONS_PACK_VER=$(grep -oP "(  |\\t)version=\"(.*)\"" ./${D}/${VERSION_FILE} | awk -F'\"' '{print $2}')
		sed -e "s/#PACKAGEVERSION#/${ADDONS_PACK_VER}/g" -e "s/#TAGREV#/${OUR_REV}/g" -e "s/#DIST#/${DISTRO_CODENAME}/g" debian/changelog.in > debian/changelog

		env $EXTRA_ENV dpkg-buildpackage -us -uc -b --jobs=auto

		if [ $? -ne 0 ]
		then
			ADDONS_BUILD_FAILED+=("${D}")
		else
			ADDONS_BUILD_OK+=("${D}")
		fi
		cd ..
	fi
done

echo "********************************"
echo "*** Finished building addons ***"
echo "********************************"
echo ""
echo "Addons built OK: ${ADDONS_BUILD_OK[@]}"
echo ""
echo "Addons which failed to build: ${ADDONS_BUILD_FAILED[@]}"

# Move build products to original working dir
mv *.deb *.buildinfo *.changes "${WORK_DIR}"
