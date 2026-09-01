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

# ---------------------------------------------------------------------------
# fix_apt_sources: unified APT source fixing
# Order: fix EOL archives first, then apply APT_MIRROR.
# If both are triggered, APT_MIRROR takes precedence but a warning is emitted.
# ---------------------------------------------------------------------------
# Global flag set by _fix_eol when EOL handling actually rewrote sources.
_fix_apt_eol_fixed=0

fix_apt_sources() {
    # --- EOL archive fixing (Debian only) ---
    _fix_eol() {
        # Only Debian needs archive switching; Ubuntu and others are unaffected.
        if [[ ! -f /etc/os-release ]]; then
            return 0
        fi
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "debian" ]]; then
            return 0
        fi

        # EOL codenames that have been moved to archive.debian.org.
        # buster is definitively EOL, bullseye just passed EOL (2026-09) and
        # is in transitional state where archive may not yet be ready, so
        # probing is required.
        local EOL_CODENAMES=("buster" "bullseye")

        local codename="${VERSION_CODENAME:-}"
        local is_eol=0
        local c
        for c in "${EOL_CODENAMES[@]}"; do
            if [[ "$c" == "$codename" ]]; then
                is_eol=1
                break
            fi
        done
        if [[ "$is_eol" -ne 1 ]]; then
            return 0
        fi

        echo "[fix-apt] EOL codename detected: ${codename} (ID=debian), switching to archive.debian.org..."

        case "${codename}" in
            buster)
                # Legacy sources.list (buster default)
                for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
                    [[ -f "$f" ]] || continue
                    if grep -q "deb.debian.org" "$f" 2>/dev/null; then
                        echo "[fix-apt]   $f: deb.debian.org -> archive.debian.org"
                        sed -i 's|deb.debian.org|archive.debian.org|g' "$f"
                    fi
                    if grep -q "security.debian.org" "$f" 2>/dev/null; then
                        echo "[fix-apt]   $f: security.debian.org -> archive.debian.org"
                        sed -i 's|security.debian.org|archive.debian.org|g' "$f"
                    fi
                done
                # DEB822 .sources (e.g. /etc/apt/sources.list.d/debian.sources)
                for f in /etc/apt/sources.list.d/*.sources; do
                    [[ -f "$f" ]] || continue
                    if grep -q "deb.debian.org" "$f" 2>/dev/null; then
                        echo "[fix-apt]   $f: deb.debian.org -> archive.debian.org (DEB822)"
                        sed -i 's|deb.debian.org|archive.debian.org|g' "$f"
                    fi
                    if grep -q "security.debian.org" "$f" 2>/dev/null; then
                        echo "[fix-apt]   $f: security.debian.org -> archive.debian.org (DEB822)"
                        sed -i 's|security.debian.org|archive.debian.org|g' "$f"
                    fi
                done
                # Append buster-backports if not already present (needed for dwz etc.)
                if ! grep -q "${codename}-backports" /etc/apt/sources.list 2>/dev/null; then
                    echo "[fix-apt]   adding ${codename}-backports to /etc/apt/sources.list"
                    echo "deb http://archive.debian.org/debian ${codename}-backports main" >> /etc/apt/sources.list
                else
                    echo "[fix-apt]   ${codename}-backports already present, skipping"
                fi
                _fix_apt_eol_fixed=1
                ;;
            bullseye)
                # Bullseye EOL transitional: probe official source first.
                # If still reachable, keep official; if not reachable, switch to archive.
                local _probe_ok=0
                # Try both Release and InRelease with timeout 5, spider mode; suppress errexit
                if wget -q --spider --timeout=5 "http://deb.debian.org/debian/dists/bullseye/Release" 2>/dev/null; then
                    _probe_ok=1
                elif wget -q --spider --timeout=5 "http://deb.debian.org/debian/dists/bullseye/InRelease" 2>/dev/null; then
                    _probe_ok=1
                fi
                if [[ $_probe_ok -eq 1 ]]; then
                    echo "[fix-apt] bullseye still served from deb.debian.org (probe succeeded), keeping official sources"
                    # do NOT set _fix_apt_eol_fixed, remain on official
                else
                    echo "[fix-apt] bullseye official source not reachable (probe failed), switching to archive.debian.org..."
                    # copy same sed logic as buster but for bullseye (legacy + DEB822 + backports)
                    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
                        [[ -f "$f" ]] || continue
                        if grep -q "deb.debian.org" "$f" 2>/dev/null; then
                            echo "[fix-apt]   $f: deb.debian.org -> archive.debian.org"
                            sed -i 's|deb.debian.org|archive.debian.org|g' "$f"
                        fi
                        if grep -q "security.debian.org" "$f" 2>/dev/null; then
                            echo "[fix-apt]   $f: security.debian.org -> archive.debian.org"
                            sed -i 's|security.debian.org|archive.debian.org|g' "$f"
                        fi
                    done
                    for f in /etc/apt/sources.list.d/*.sources; do
                        [[ -f "$f" ]] || continue
                        if grep -q "deb.debian.org" "$f" 2>/dev/null; then
                            echo "[fix-apt]   $f: deb.debian.org -> archive.debian.org (DEB822)"
                            sed -i 's|deb.debian.org|archive.debian.org|g' "$f"
                        fi
                        if grep -q "security.debian.org" "$f" 2>/dev/null; then
                            echo "[fix-apt]   $f: security.debian.org -> archive.debian.org (DEB822)"
                            sed -i 's|security.debian.org|archive.debian.org|g' "$f"
                        fi
                    done
                    if ! grep -q "${codename}-backports" /etc/apt/sources.list 2>/dev/null; then
                        echo "[fix-apt]   adding ${codename}-backports to /etc/apt/sources.list"
                        echo "deb http://archive.debian.org/debian ${codename}-backports main" >> /etc/apt/sources.list
                    else
                        echo "[fix-apt]   ${codename}-backports already present, skipping"
                    fi
                    _fix_apt_eol_fixed=1
                fi
                ;;
            *)
                echo "[fix-apt] WARNING: EOL codename ${codename} matched but no handler defined"
                ;;
        esac
    }

    # --- APT_MIRROR handling ---
    _apply_mirror() {
        if [[ -z "${APT_MIRROR:-}" ]]; then
            return 0
        fi
        echo "[fix-apt] applying APT_MIRROR=${APT_MIRROR} ..."

        # Legacy list files: /etc/apt/sources.list and /etc/apt/sources.list.d/*.list
        for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
            [[ -f "$f" ]] || continue
            # Extract hostname from first deb line and replace it
            local original_mirror
            original_mirror=$(awk '/^deb /{print $2}' "$f" | head -n1 | cut -d/ -f3)
            if [[ -n "${original_mirror:-}" ]]; then
                echo "[fix-apt]   $f: replacing host ${original_mirror} -> ${APT_MIRROR}"
                sed -i "s|${original_mirror}|${APT_MIRROR}|g" "$f"
            fi
            # Comment out security.ubuntu.com to avoid mixed-mirror issues (Ubuntu only)
            if grep -q "security.ubuntu.com" "$f" 2>/dev/null; then
                echo "[fix-apt]   $f: commenting security.ubuntu.com"
                sed -i "/security.ubuntu.com/s|^|#|" "$f"
            fi
        done

        # DEB822 .sources files: replace deb.debian.org hostname with mirror
        for f in /etc/apt/sources.list.d/*.sources; do
            [[ -f "$f" ]] || continue
            if grep -q "deb.debian.org" "$f" 2>/dev/null; then
                echo "[fix-apt]   $f: deb.debian.org -> ${APT_MIRROR} (DEB822)"
                sed -i "s|deb.debian.org|${APT_MIRROR}|g" "$f"
            fi
        done
    }

    _fix_eol
    _apply_mirror

    if [[ "${_fix_apt_eol_fixed}" -eq 1 && -n "${APT_MIRROR:-}" ]]; then
        echo "[fix-apt] WARNING: EOL archive fix was applied but APT_MIRROR=${APT_MIRROR} overrides archive.debian.org; you are responsible for ensuring the mirror provides the archive path."
    fi
}

# Parse --fix-apt-only before any heavy work.
# When set, only fix apt sources and exit 0 (lightweight CI install-test).
FIX_APT_ONLY=0
if [[ "${1:-}" == "--fix-apt-only" ]]; then
    FIX_APT_ONLY=1
fi

if [[ "$FIX_APT_ONLY" -eq 1 ]]; then
    fix_apt_sources
    echo "[fix-apt] --fix-apt-only: done, exiting 0"
    exit 0
fi

# Normal flow: fix sources then continue with dependency installation
fix_apt_sources

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


# Old distros ship a debhelper too old to build the sid OpenSSH source
# (dh-sequence-movetousr needs >= 13.11.7). The sid .debs are downloaded on
# the host by pullsrc.sh into builddep/ (gitignored) and installed here.
# No sid apt source is configured inside the container: expired GPG/CA and
# dependency churn make that fragile on old distros.
__debhelper_ver="$(dpkg-query -f '${Version}' -W debhelper || true)"
[[ -z $__debhelper_ver ]] && __debhelper_ver="0.0.0"
echo "DEBUG: __debhelper_ver:$__debhelper_ver"
if dpkg --compare-versions "$__debhelper_ver" lt '13.12~'; then
   if ! ls "$__dir"/builddep/debhelper_*_all.deb >/dev/null 2>&1; then
       echo "ERROR: builddep/debhelper_*.deb missing. Run ./pullsrc.sh on the host first (it downloads them into builddep/)." >&2
       exit 1
   fi

   # debhelper needs dwz >= 0.12.20190711, newer than some distros ship
   # (Ubuntu 18.04 has 0.12-2): pull it from the distro backports pocket.
   __dwz_ver="$(apt-cache policy dwz 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
   [[ -z $__dwz_ver || $__dwz_ver == "(none)" ]] && __dwz_ver=0
   if dpkg --compare-versions "$__dwz_ver" lt '0.12.20190711'; then
       apt install -y -t "$(lsb_release -sc)-backports" dwz
   fi

   apt install -y --allow-downgrades "$__dir"/builddep/*.deb

   # debhelper >= 13.27 restores its bucket files with `cp --update=none`,
   # which coreutils only learned in 9.3. On the older coreutils shipped by
   # these distros `-n` has identical semantics (upstream itself used
   # `cp -an` at these two Dh_Lib.pm call sites until 13.26), so rewrite it.
   __coreutils_ver="$(dpkg-query -f '${Version}' -W coreutils || true)"
   [[ -z $__coreutils_ver ]] && __coreutils_ver="0.0.0"
   echo "DEBUG: __coreutils_ver:$__coreutils_ver"
   if dpkg --compare-versions "$__coreutils_ver" lt '9.3~'; then
       sed -i "s/'--update=none'/'-n'/g" /usr/share/perl5/Debian/Debhelper/Dh_Lib.pm
   fi

   # debhelper >= 14 declares `use v5.28` (Dh_Lib.pm, dh_assistant) and uses
   # `state` with initializers (perl >= 5.28); downgrade both for older perls
   # (Ubuntu 18.04: 5.26). Bare `state $x;` / `state %h;` work on 5.26.
   __perl_ver="$(perl -MConfig -e 'print $Config{version}')"
   if dpkg --compare-versions "$__perl_ver" lt '5.28'; then
       sed -i -E 's/^(\s*)state\s+([%@][^=]+=)/\1my \2/; s/^(\s*)state\s+\(([^)]+)\)/\1my (\2)/' /usr/share/perl5/Debian/Debhelper/Dh_Lib.pm
       sed -i 's/^use v5\.28;/use v5.26;/' /usr/share/perl5/Debian/Debhelper/Dh_Lib.pm /usr/bin/dh_assistant /usr/bin/dh_missing
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
   # searches /lib/systemd/system, but debhelper installs units to
   # /usr/lib: keep units in /lib so services actually get enabled.
   # (debhelper >= 14 also uses the ${tmpdir} brace form; rewrite both.)
   if [ ! -L /lib ]; then
       sed -i 's|$tmpdir/usr/lib/systemd/system|$tmpdir/lib/systemd/system|g; s|${tmpdir}/usr/lib/systemd/system|${tmpdir}/lib/systemd/system|g' /usr/bin/dh_installsystemd
   fi
 fi

exit 0
