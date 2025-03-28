#!/bin/bash
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
#

__debhelper_ver="$(dpkg-query -f '${Version}' -W debhelper || true)"
[[ -z $__debhelper_ver ]] && __debhelper_ver="0.0.0"

export DEBIAN_FRONTEND=noninteractive

if [[ ! -z "${APT_MIRROR+x}" ]]; then \
	[[ -f /etc/apt/sources.list ]] && \
		sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|${APT_MIRROR}|" /etc/apt/sources.list

	[[ -f /etc/apt/sources.list.d/debian.sources ]] && \
		sed -i "s|deb.debian.org|${APT_MIRROR}|" /etc/apt/sources.list.d/debian.sources
fi

apt update && apt upgrade -y
apt install -y --no-install-recommends wget sudo pkgconf build-essential fakeroot \
	dpkg-dev debhelper debhelper-compat dh-exec dh-runit \
	libaudit-dev libedit-dev libgtk-3-dev libselinux1-dev libsystemd-dev \
	libkrb5-dev libpam0g-dev libwrap0-dev

if [[ $(apt-cache search --names-only 'libfido2-dev' | wc -l) -gt 0 ]]; then
	apt install -y libfido2-dev libcbor-dev
fi

dpkg --compare-versions $__debhelper_ver le '13.1~' && \
   sudo apt install -y $__dir/builddep/*.deb

