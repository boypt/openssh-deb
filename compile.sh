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
__debhelper_ver="$(dpkg-query -f '${Version}' -W debhelper || true)"
[[ -z $__debhelper_ver ]] && __debhelper_ver="0.0.0"

source $__dir/version.env

STATIC_OPENSSL=0
if dpkg --compare-versions $__libssl lt '3.0.0' || [[ -n ${FORCESSL+x} ]]; then
	STATIC_OPENSSL=1
fi

echo "-- Build OpenSSH : ${OPENSSH_SIDPKG}"
echo "-- Linked OpenSSL: ${OPENSSLSRC/.tar.gz/}"
SOURCES=(
	openssh_${OPENSSH_SIDPKG}.debian.tar.xz \
	openssh_${OPENSSH_SIDPKG}.dsc \
	openssh_${OPENSSHVER}.orig.tar.gz \
	openssh_${OPENSSHVER}.orig.tar.gz.asc \
)
[[ $STATIC_OPENSSL -eq 1 ]] && SOURCES+=("$OPENSSLSRC")

CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "-- Error: $1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}

for fn in ${SOURCES[@]}; do
  CHECKEXISTS $fn 
done

dpkg --compare-versions $__debhelper_ver le '13.1~' && \
   sudo apt install -y $__dir/builddep/*.deb

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

dpkg-source -x $__dir/downloads/openssh_${OPENSSH_SIDPKG}.dsc
pushd openssh-${OPENSSHVER}

if dpkg --compare-versions $__libfido2_ver lt '1.5.0'; then
	sed -i '/libfido2-dev/d' debian/control
	sed -i "s|with-security-key-builtin|disable-security-key|" debian/rules
fi

if [[ $STATIC_OPENSSL -eq 1 ]]; then
	sed -i "s|-lcrypto|${OPENSSLDIR}/libcrypto.a -lz -ldl -pthread|g" configure configure.ac
	sed -i '/libssl-dev/d' debian/control
	sed -i "/^confflags += --with-ssl-engine/aconfflags += --with-ssl-dir=${OPENSSLDIR}\nconfflags_udeb += --with-ssl-dir=${OPENSSLDIR}" debian/rules
	sed -i "/^override_dh_auto_configure-arch:/iDEB_CONFIGURE_SCRIPT_ENV += LD_LIBRARY_PATH=${OPENSSLDIR}" debian/rules
fi

### Build OpenSSH Package
env \
	DEB_BUILD_OPTIONS=nocheck \
	DEB_BUILD_PROFILES=pkg.openssh.nognome \
	dpkg-buildpackage --no-sign -rfakeroot -b
popd

# Move all files into output dir
cd $__dir
mkdir -p output
mv -f build/*.deb output/ 2> /dev/null || echo "No deb packages created!"
mv -f build/*.udeb output/ 2> /dev/null || echo "No udeb packages created!"
