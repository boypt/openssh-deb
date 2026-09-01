#!/bin/bash
# Switch Debian package sources to archive.debian.org for EOL releases.
# Called from docker/Dockerfile.deps and CI workflows before apt operations.
# Non-Debian and non-EOL distros are not affected.
set -e
. /etc/os-release
[ "${ID:-}" = "debian" ] || exit 0

case "${VERSION_CODENAME:-}" in
    buster|bullseye)
        # Which Debian releases are EOL and need archive.debian.org
        # (stretch and earlier are also EOL but not in the CI matrix)
        sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list
        sed -i 's|security.debian.org|archive.debian.org/debian-security|g' /etc/apt/sources.list
        # The backports source is not in the base image; add it so that
        # install_deps.sh can pull packages like dwz from backports.
        echo "deb http://archive.debian.org/debian ${VERSION_CODENAME}-backports main" >> /etc/apt/sources.list
        ;;
esac