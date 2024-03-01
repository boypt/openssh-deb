ARG DISTRO=ubuntu
ARG DISTVER=22.04
FROM $DISTRO:$DISTVER
LABEL BOYPT=""
WORKDIR /data

RUN sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|mirrors.bfsu.edu.cn|" /etc/apt/sources.list && \
    apt update && \
    apt upgrade -y && \
    apt install -y sudo pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit libaudit-dev libedit-dev libfido2-dev libgtk-3-dev libselinux1-dev libsystemd-dev libkrb5-dev libpam0g-dev libwrap0-dev

CMD ["bash", "/data/compile.sh"]
