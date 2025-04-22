ARG DISTRO=ubuntu
ARG DISTVER=22.04
FROM $DISTRO:$DISTVER
WORKDIR /data
# Copy all files
COPY . /data
ARG APT_MIRROR=
ENV APT_MIRROR=${APT_MIRROR}
RUN bash /data/install_deps.sh
CMD ["bash", "/data/compile.sh"]
