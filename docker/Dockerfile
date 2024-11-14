ARG DISTRO=ubuntu
ARG DISTVER=22.04
FROM $DISTRO:$DISTVER
WORKDIR /data
# Copy all files
COPY . /data
ARG APT_MIRROR=""
ENV DEBIAN_FRONTEND=noninteractive
# The following parameters are used for installing Debian distribution packages on Ubuntu systems.
# *ONLY* used at Jammy version.
ARG DEBIAN_SOURCE="http://ftp.debian.org/debian/"
ARG OPENPGP_SERVER="keyserver.ubuntu.com"

RUN if [ ! -z "$APT_MIRROR" ]; then \
        if [ -f /etc/apt/sources.list ]; then \
            sed -i "s|$(awk '/^deb/{print $2}' /etc/apt/sources.list | head -n1 | cut -d/ -f3)|${APT_MIRROR}|" /etc/apt/sources.list; \
        fi; \
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
            sed -i "s|deb.debian.org|${APT_MIRROR}|" /etc/apt/sources.list.d/debian.sources;  \
        fi; \
    fi && \
    apt update && apt upgrade -y && \
    apt install -y lsb-release && \
    CODE_NAME=$(lsb_release -sc) && \
    if [ ${CODE_NAME} != "focal" ]; then \
        apt install -y dh-virtualenv; \
    fi && \
    apt install -y \
        build-essential curl debhelper debhelper-compat dh-exec dh-runit dpkg-dev \
        fakeroot libaudit-dev libedit-dev libgtk-3-dev libkrb5-dev libpam0g-dev \
        libselinux1-dev libsystemd-dev libwrap0-dev pkgconf sudo wget && \
    if [ $(apt-cache search --names-only 'libfido2-dev' | wc -l) -gt 0 ]; then \
        apt install -y libfido2-dev libcbor-dev; \
    fi && \
    case ${CODE_NAME} in \
        jammy|bookworm|bullseye) \
            echo "deb $DEBIAN_SOURCE sid main" >> /etc/apt/sources.list; \
            KEYS=$(apt update 2>&1 | grep -o 'NO_PUBKEY [A-F0-9]\+' | sed 's/NO_PUBKEY //' | sort | uniq); \
            for KEY in ${KEYS}; \
            do \
                apt-key adv --keyserver ${OPENPGP_SERVER} --recv-keys ${KEY}; \
            done; \
            apt update; \
            apt install -y dh-sequence-movetousr; \
            ;; \
        *) \
            echo "$CODENAME is NOT NEED to add Debian sources."; \
            ;; \
    esac && \
    apt clean all && \
    bash /data/pullsrc.sh

CMD ["bash", "/data/compile.sh"]
