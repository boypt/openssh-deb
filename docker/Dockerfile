ARG DISTRO=ubuntu
ARG DISTVER=22.04
FROM $DISTRO:$DISTVER
WORKDIR /data
ARG APT_MIRROR=
ENV DEBIAN_FRONTEND=noninteractive

RUN if [ ! -z "$APT_MIRROR" ]; then \
      sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|${APT_MIRROR}|" /etc/apt/sources.list \
    ;fi && \
    apt update && \
    apt upgrade -y && \
    apt install -y sudo pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit libaudit-dev libedit-dev libfido2-dev libgtk-3-dev libselinux1-dev libsystemd-dev libkrb5-dev libpam0g-dev libwrap0-dev

CMD ["bash", "/data/compile.sh"]
