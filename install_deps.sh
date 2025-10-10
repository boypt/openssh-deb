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


# install the latest debhelper from debian sid by adding debian sources
_DEBIAN_DEBHELPER() {

    local __coreutils_ver="$(dpkg-query -f '${Version}' -W coreutils || true)"
    [[ -z $__coreutils_ver ]] && __coreutils_ver="0.0.0"
    echo "DEBUG: __coreutils_ver:$__coreutils_ver"

    # Note: latest debhelper calls `cp --update=none` which is unsupported with coreutils < 9.5
    # Install a fixed version of debhelper in our repo instead.
    if dpkg --compare-versions "$__coreutils_ver" le '9.5~'; then
        sudo apt install -y --allow-downgrades "$__dir"/builddep/*.deb
        return 0
    fi

    DEBIAN_SOURCE="http://deb.debian.org/debian/"
    [[ -n "${APT_MIRROR:-}" ]] && \
        DEBIAN_SOURCE="http://${APT_MIRROR}/debian/"

    # Download Debian sid GPG key
    wget -O /usr/share/keyrings/debian-sid.gpg https://deb.debian.org/debian/dists/sid/Release.gpg

    # Add Debian sid source with the GPG key
    echo "deb [signed-by=/usr/share/keyrings/debian-sid.gpg] $DEBIAN_SOURCE sid main" > /etc/apt/sources.list.d/debian-sid.list

    apt update
    apt install -y debhelper
    rm /etc/apt/sources.list.d/debian-sid.list
}

__debhelper_ver="$(dpkg-query -f '${Version}' -W debhelper || true)"
[[ -z $__debhelper_ver ]] && __debhelper_ver="0.0.0"
echo "DEBUG: __debhelper_ver:$__debhelper_ver"
if dpkg --compare-versions "$__debhelper_ver" le '13.1~'; then
   sudo apt install -y "$__dir"/builddep/*.deb
fi

#CODE_NAME=$(lsb_release -sc)
# if [ "${CODE_NAME}" != "focal" ]; then
#     apt install -y dh-virtualenv
# fi
# case ${CODE_NAME} in
#     # dists with coreutils >= 9.5 can use the latest debhelper from debian sid
#     trixie)
#         _DEBIAN_DEBHELPER
#         ;;
#     plucky|questing|resolute)
#         _DEBIAN_DEBHELPER
#         ;;
#     *)
#         echo "$CODE_NAME does NOT NEED to add Debian sources."
#         ;;
# esac

exit 0
