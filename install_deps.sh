#!/bin/bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app
#

export DEBIAN_FRONTEND=noninteractive

if [[ -n "${APT_MIRROR:-}" ]]; then
	if [[ -f /etc/apt/sources.list ]]; then
		# Extract the hostname from the first 'deb' line and replace it
		original_mirror=$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)
		sed -i "s|${original_mirror}|${APT_MIRROR}|" /etc/apt/sources.list
		# Comment out the security update source to avoid potential issues from mixed mirror sources
		sed -i "/security.ubuntu.com/s|^|#|" /etc/apt/sources.list
	fi

	if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
		sed -i "s|deb.debian.org|${APT_MIRROR}|" /etc/apt/sources.list.d/debian.sources
	fi
fi

apt update
apt upgrade -y
apt install -y --no-install-recommends lsb-release wget sudo pkgconf build-essential fakeroot \
	dpkg-dev debhelper debhelper-compat dh-exec dh-runit \
	libaudit-dev libedit-dev libgtk-3-dev libselinux1-dev libsystemd-dev \
	libkrb5-dev libpam0g-dev libwrap0-dev

if [[ $(apt-cache search --names-only 'libfido2-dev' | wc -l) -gt 0 ]]; then
	apt install -y libfido2-dev libcbor-dev
fi

# The following parameters are used for installing Debian distribution packages
# on Ubuntu systems or old Debian systems.
# *ONLY* used at:
# Ubuntu series: jammy & bionic
# Debian series: bullseye & bookworm
DEBIAN_SOURCE="http://deb.debian.org/debian/"
OPENPGP_SERVER="keyserver.ubuntu.com"

if [[ -n "${APT_MIRROR:-}" ]]; then
    DEBIAN_SOURCE="http://${APT_MIRROR}/debian/"
fi
if [[ -n "${PGP_SERVER:-}" ]]; then
    OPENPGP_SERVER="${PGP_SERVER}"
fi

_DEBIAN_SID_DEBHELPER() {
    # install the latest debhelper from debian sid by adding debian sources
    apt install -y gnupg
    echo "deb $DEBIAN_SOURCE sid main" >> /etc/apt/sources.list
    # Allow apt update to fail in order to capture missing keys
    KEYS=$(apt update 2>&1 | grep -o 'NO_PUBKEY [A-F0-9]\+' | sed 's/NO_PUBKEY //' | sort | uniq || true)
    for KEY in ${KEYS}; do
        apt-key adv --keyserver "${OPENPGP_SERVER}" --recv-keys "${KEY}"
    done
    apt update
    apt install -y debhelper
}

CODE_NAME=$(lsb_release -sc)

if [ "${CODE_NAME}" != "focal" ]; then
    apt install -y dh-virtualenv
fi

__coreutils_ver="$(dpkg-query -f '${Version}' -W coreutils || true)"
[[ -z $__coreutils_ver ]] && __coreutils_ver="0.0.0"
echo "DEBUG: __coreutils_ver:$__coreutils_ver"

# Note: latest debhelper calls `cp --update=none` which is unsupported in coreutils < 9.5
# Install a fixed version of debhelp in our repo instead
if dpkg --compare-versions "$__coreutils_ver" le '9.5~'; then
   sudo apt install -y "$__dir"/builddep/*.deb
fi

case ${CODE_NAME} in
    # dists with coreutils >= 9.5 can use the latest debhelper from debian sid
    trixie)
        _DEBIAN_SID_DEBHELPER
        ;;
    plucky|questing|resolute)
        _DEBIAN_SID_DEBHELPER
        ;;
    *)
        echo "$CODE_NAME does NOT NEED to add Debian sources."
        ;;
esac

__debhelper_ver="$(dpkg-query -f '${Version}' -W debhelper || true)"
[[ -z $__debhelper_ver ]] && __debhelper_ver="0.0.0"
echo "DEBUG: __debhelper_ver:$__debhelper_ver"

if dpkg --compare-versions "$__debhelper_ver" le '13.1~'; then
   sudo apt install -y --allow-downgrades "$__dir"/builddep/*.deb
fi

exit 0
