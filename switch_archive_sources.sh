#!/bin/bash
# Switch Debian package sources to archive.debian.org for EOL releases.
# Called from docker/Dockerfile.deps and CI workflows before apt operations.
# Non-Debian and non-EOL distros are not affected.
set -e
. /etc/os-release
[ "${ID:-}" = "debian" ] || exit 0

case "${VERSION_CODENAME:-}" in
    buster)
        # EOL Debian releases served from archive.debian.org.
        # NOTE: do NOT add bullseye until deb.debian.org/security.debian.org
        # stop serving it (its repos were still live as of 2026-09).
        sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list
        # buster bundles security under deb.debian.org (path /debian-security)
        sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list
        # The backports source is not in the base image; add it so that
        # install_deps.sh can pull packages like dwz from backports.
        echo "deb http://archive.debian.org/debian ${VERSION_CODENAME}-backports main" >> /etc/apt/sources.list
        ;;
esac