#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

__libssl="$(dpkg-query -f '${Version}' -W libssl-dev || true)"
[[ -z $__libssl ]] && __libssl="0.0.0"
__libfido2_ver="$(dpkg-query -f '${Version}' -W libfido2-dev || true)"
[[ -z $__libfido2_ver ]] && __libfido2_ver="0.0.0"
__initsystemhelpers_ver="$(dpkg-query -f '${Version}' -W init-system-helpers || true)"
[[ -z $__initsystemhelpers_ver ]] && __initsystemhelpers_ver="0.0.0"

STATIC_OPENSSL=0

echo "Getting version from version.env ..."
source $__dir/version.env

RETRY_COUNT=0
MAX_RETRIES=10
while [[ -z ${OPENSSH_SIDPKG:-} ]]; do
	RETRY_COUNT=$((RETRY_COUNT+1))
	if [[ $RETRY_COUNT -gt $MAX_RETRIES ]]; then
		echo "Error: Failed to get OPENSSH_SIDPKG from version.env after $MAX_RETRIES retries." >&2
		exit 1
	fi
	echo "Warning: OPENSSH_SIDPKG is not set. Retrying in 3 seconds... (Attempt ${RETRY_COUNT}/${MAX_RETRIES})"
	source $__dir/version.env
	sleep 3
done

if dpkg --compare-versions $__libssl lt '3.0.0' || [[ -n ${FORCESSL+x} ]]; then
	STATIC_OPENSSL=1
fi

BUILD_CODENAME=$(lsb_release -sc)

SOURCES=(
	openssh_${OPENSSH_SIDPKG}.debian.tar.xz \
	openssh_${OPENSSH_SIDPKG}.dsc \
	openssh_${OPENSSHVER}.orig.tar.gz \
	openssh_${OPENSSHVER}.orig.tar.gz.asc \
)

echo "-- Build OpenSSH : ${OPENSSH_SIDPKG}"
if [[ $STATIC_OPENSSL -eq 1 ]]; then 
	echo "-- Linked OpenSSL: ${OPENSSLSRC/.tar.gz/}"
	SOURCES+=("$OPENSSLSRC")
else
	echo "-- Linked OpenSSL: libssl-dev ${__libssl}"
fi

CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "-- Error: $1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}

for fn in ${SOURCES[@]}; do
  CHECKEXISTS $fn 
done

cd $__dir
[[ -d build ]] && rm -rf build
mkdir -p build && pushd build

#### Build OPENSSL
if [[ $STATIC_OPENSSL -eq 1 ]]; then
	mkdir -p openssl
	tar xfz $__dir/downloads/$OPENSSLSRC --strip-components=1 -C openssl
	pushd openssl
	./config shared zlib -fPIC
	make -j$(nproc)
	OPENSSLDIR=$PWD
	popd
fi
#################

## Extract dpkg source
dpkg-source -x $__dir/downloads/openssh_${OPENSSH_SIDPKG}.dsc
pushd openssh-${OPENSSHVER}

## disable fido support on older distro
if dpkg --compare-versions $__libfido2_ver lt '1.5.0'; then
	sed -i '/libfido2-dev/d' debian/control
	sed -i "s|with-security-key-builtin|disable-security-key|" debian/rules
fi

## link openssl staticlly on older distro / or forced with `FORCESSL=1`
if [[ $STATIC_OPENSSL -eq 1 ]]; then
	sed -i "s|-lcrypto|${OPENSSLDIR}/libcrypto.a -lz -ldl -pthread|g" configure configure.ac
	sed -i '/libssl-dev/d' debian/control
	sed -i "/^confflags += --with-ssl-engine/aconfflags += --with-ssl-dir=${OPENSSLDIR}\nconfflags_udeb += --with-ssl-dir=${OPENSSLDIR}" debian/rules
	sed -i "/^override_dh_auto_configure-arch:/iDEB_CONFIGURE_SCRIPT_ENV += LD_LIBRARY_PATH=${OPENSSLDIR}" debian/rules
fi

## wtmpdb not available in older distros
if ! dpkg -l libwtmpdb-dev; then
	sed -i '/libwtmpdb-dev/d' debian/control
	sed -i '/with-wtmpdb/d' debian/rules
fi

## fix init-system-helpers version require
if dpkg --compare-versions $__initsystemhelpers_ver lt '1.66'; then
	sed -i '/init-system-helpers/s|1.66|1.50|' debian/control
fi

## Check build deps
if ! dpkg-checkbuilddeps; then
	echo "The build dependencies are not met, run ./install_deps.sh first."
	exit 1
fi

## Adding distro codename to package names
sed -i "1s|)|~${BUILD_CODENAME})|" debian/changelog

## SKIP openssh-tests pkg
sed -i "/^%:/iBUILD_PACKAGES += -Nopenssh-tests\n" debian/rules

echo "INFO: Building Package: $(head -n1 debian/changelog)"

### Build OpenSSH Package
env \
	DEB_BUILD_OPTIONS="noddebs nocheck" \
	DEB_BUILD_PROFILES="noudeb pkg.openssh.nognome" \
	dpkg-buildpackage --no-sign -rfakeroot -b
popd

# Move all files into output dir
cd $__dir
mkdir -p output
mv -f build/*.deb output/ 2> /dev/null || echo "No deb packages created!"
#mv -f build/*.udeb output/ 2> /dev/null || echo "No udeb packages created!"
