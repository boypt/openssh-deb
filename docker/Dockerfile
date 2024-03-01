FROM $DISTRO:$DISTVER
LABEL BOYPT=""
WORKDIR /data

COPY .. /data

RUN sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|mirrors.bfsu.edu.cn|" /etc/apt/sources.list && \
    apt update && \
    apt upgrade -y && \
    apt install pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit libaudit-dev libedit-dev libfido2-dev libgtk-3-dev libselinux1-dev libsystemd-dev

RUN ./pullsrc.sh
CMD ["bash", "/data/compile.sh"]
