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
	dpkg-dev debhelper debhelper-compat dh-exec dh-runit ca-certificates \
	libaudit-dev libedit-dev libgtk-3-dev libselinux1-dev libsystemd-dev \
	libkrb5-dev libpam0g-dev libwrap0-dev

# Only install libfido2-dev when it is available in the default archive
# (priority 500). If it only exists in backports (priority 100, e.g. Debian 10
# buster), building against it would produce a libfido2-1 runtime dependency
# that a stock target system cannot satisfy.
if [[ $(apt-cache policy libfido2-dev 2>/dev/null | grep -cE ' 500$') -gt 0 ]]; then
	apt install -y libfido2-dev libcbor-dev
fi

# libcrypt-dev only exists on distros where libxcrypt was split out of libc
if [[ $(apt-cache search --names-only 'libcrypt-dev' | wc -l) -gt 0 ]]; then
	apt install -y libcrypt-dev
fi


# install the latest debhelper from debian sid by adding debian sources
_DEBIAN_DEBHELPER() {

    local __coreutils_ver="$(dpkg-query -f '${Version}' -W coreutils || true)"
    [[ -z $__coreutils_ver ]] && __coreutils_ver="0.0.0"
    echo "DEBUG: __coreutils_ver:$__coreutils_ver"

    # Note: with coreutils < 9.5, `cp --update=none` is not supported.
    # But the latest debhelper generate such commands.
    # Using the latest debhelper would fail.
    if dpkg --compare-versions "$__coreutils_ver" lt '9.5~'; then
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
if dpkg --compare-versions "$__debhelper_ver" lt '13.12~'; then
   # dh-sequence-movetousr was added to debhelper in 13.11.7

   # debhelper 13.14 needs dwz >= 0.12.20190711, newer than some distros ship
   # (Ubuntu 18.04 has 0.12-2): pull it from the distro backports pocket.
   __dwz_ver="$(apt-cache policy dwz 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
   [[ -z $__dwz_ver || $__dwz_ver == "(none)" ]] && __dwz_ver=0
   if dpkg --compare-versions "$__dwz_ver" lt '0.12.20190711'; then
       apt install -y -t "$(lsb_release -sc)-backports" dwz
   fi

   sudo apt install -y "$__dir"/builddep/*.deb

   # debhelper 13.14 uses Perl >= 5.30 syntax (state vars in list context) and
   # dh_missing declares v5.28; downgrade both for older perls (Ubuntu 18.04: 5.26).
   __perl_ver="$(perl -MConfig -e 'print $Config{version}')"
   if dpkg --compare-versions "$__perl_ver" lt '5.28'; then
       sed -i -E 's/^(\s*)state\s+([%@][^=]+=)/\1my \2/; s/^(\s*)state\s+\(([^)]+)\)/\1my (\2)/' /usr/share/perl5/Debian/Debhelper/Dh_Lib.pm
       sed -i 's/^use v5\.28;/use v5.26;/' /usr/bin/dh_missing
   fi

   # debhelper hardcodes versioned deps on init-system-helpers that old distros
   # predate (Ubuntu 18.04: 1.51); the subcommands used are all supported there.
   __ish_ver="$(apt-cache policy init-system-helpers 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
   [[ -z $__ish_ver || $__ish_ver == "(none)" ]] && __ish_ver=0
   if dpkg --compare-versions "$__ish_ver" lt '1.52'; then
       sed -i "s/\">= 1\.52\"/\">= $__ish_ver\"/; s/\">= 1\.66~\"/\">= $__ish_ver\"/" /usr/bin/dh_installsystemduser
   fi
   # invoke-rc.d only learned --skip-systemd-native in init-system-helpers 1.54;
   # drop the option on older distros (dh_installinit then also omits its
   # Pre-Depends on init-system-helpers (>= 1.54~) automatically).
   if dpkg --compare-versions "$__ish_ver" lt '1.54~'; then
       sed -i "s/compat(11) ? '' : '--skip-systemd-native '/''/" /usr/bin/dh_installinit
   fi

   # On non-merged-usr distros (e.g. Ubuntu 18.04) deb-systemd-helper only
   # searches /lib/systemd/system, but debhelper 13.14 installs units to
   # /usr/lib: keep units in /lib so services actually get enabled.
   if [ ! -L /lib ]; then
       sed -i 's|\$tmpdir/usr/lib/systemd/system|$tmpdir/lib/systemd/system|g' /usr/bin/dh_installsystemd
   fi
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
