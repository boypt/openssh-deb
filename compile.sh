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

arg1="${1:-}"


source $__dir/version.env
SOURCES=(
	openssh_${OPENSSHVER}-${OPENSSHPKGVER}.debian.tar.xz \
	openssh_${OPENSSHVER}-${OPENSSHPKGVER}.dsc \
	openssh_${OPENSSHVER}.orig.tar.gz \
	openssh_${OPENSSHVER}.orig.tar.gz.asc \
)

CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "$1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}

for fn in ${SOURCES[@]}; do
  CHECKEXISTS $fn 
done
sudo apt install -y $__dir/builddep/*.deb


cd $__dir
[[ -d build ]] && rm -rf build
mkdir -p build && pushd build
dpkg-source -x $__dir/downloads/openssh_${OPENSSHVER}-${OPENSSHPKGVER}.dsc


cd openssh-${OPENSSHVER}
dpkg-buildpackage --no-sign -rfakeroot -b

