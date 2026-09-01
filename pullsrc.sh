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

# debhelper .debs for old distros: downloaded here on the host (current CA and
# network), installed by install_deps.sh from builddep/ (gitignored). Old
# distros cannot build the sid OpenSSH source with their own debhelper
# (dh-sequence-movetousr needs >= 13.11.7), and adding sid apt sources inside
# old containers is fragile, so we just fetch the two arch-all .debs directly.
DEBHELPER_LINKS=(
	$DEBMIRROR/pool/main/d/debhelper/debhelper_${DEBHELPER_SIDPKG}_all.deb
	$DEBMIRROR/pool/main/d/debhelper/libdebhelper-perl_${DEBHELPER_SIDPKG}_all.deb
)

# `./pullsrc.sh debhelper` fetches only the .debs (used by the deps-image CI
# before docker build, where the openssh sources are not needed).
if [[ "$arg1" == "debhelper" ]]; then
	mkdir -p $__dir/builddep
	echo "> INFO: downloading debhelper ${DEBHELPER_SIDPKG} .debs into builddep/."
	wget --continue -P "$__dir/builddep" "${DEBHELPER_LINKS[@]}"
	exit 0
fi

DOWNLOADLINKS=(
	$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSH_SIDPKG}.{debian.tar.xz,dsc}
	$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSHVER}.orig.tar.gz{,.asc}
	${OPENSSLMIR}/${OPENSSLSRC}
)

mkdir -p $__dir/downloads $__dir/builddep && cd $__dir/downloads
echo "> INFO: downloading the following sources."
echo "${DOWNLOADLINKS[@]}" | tr " " "\n"
wget --continue "${DOWNLOADLINKS[@]}"

echo "> INFO: downloading debhelper ${DEBHELPER_SIDPKG} .debs into builddep/."
wget --continue -P "$__dir/builddep" "${DEBHELPER_LINKS[@]}"

