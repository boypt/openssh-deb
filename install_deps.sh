#!/bin/bash

if [[ ! -z "${APT_MIRROR+x}" ]]; then \
	[[ -f /etc/apt/sources.list ]] && \
		sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|${APT_MIRROR}|" /etc/apt/sources.list

	[[ -f /etc/apt/sources.list.d/debian.sources ]] && \
		sed -i "s|deb.debian.org|${APT_MIRROR}|" /etc/apt/sources.list.d/debian.sources
fi

apt update && apt upgrade -y
apt install -y sudo pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit \
	libaudit-dev libedit-dev libgtk-3-dev libselinux1-dev libsystemd-dev libkrb5-dev libpam0g-dev libwrap0-dev

if [[ $(apt-cache search --names-only 'libfido2-dev' | wc -l) -gt 0 ]]; then
	apt install -y libfido2-dev libcbor-dev
fi

