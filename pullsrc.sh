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

DOWNLOADLINKS=( \
		$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSH_SIDPKG}.debian.tar.xz \
		$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSH_SIDPKG}.dsc \
		$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSHVER}.orig.tar.gz \
		$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSHVER}.orig.tar.gz.asc \
		${OPENSSLMIR}/${OPENSSLSRC}
	      )

mkdir -p $__dir/downloads && cd $__dir/downloads
echo "> INFO: downloading the following sources."
echo "${DOWNLOADLINKS[@]}" | tr " " "\n"
wget --continue "${DOWNLOADLINKS[@]}"

