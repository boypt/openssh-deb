# Backport OpenSSH for Debian / Ubuntu distros.

A simple script to build backport openssh deb, using [Debian sid sources](https://packages.debian.org/sid/openssh-server).

Similar Project:　[Backport OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

### Current Version:

- OpenSSH 9.7p1
- OpenSSL 3.0.13 (static linked)

### Supported (tested) Distro:

- Ubuntu 22.04
- Ubuntu 20.04
- Ubuntu 18.04

## Direct Build

```bash
# Install Dependencies
sudo apt install pkgconf build-essential fakeroot \
    dpkg-dev debhelper debhelper-compat dh-exec dh-runit \
    libkrb5-dev libpam0g-dev libwrap0-dev \
    libaudit-dev libedit-dev libfido2-dev \
    libgtk-3-dev libselinux1-dev libsystemd-dev \
    libcbor-dev

# pull source
./pullsrc.sh

# direct build
./compile.sh
```

## Use Docker to Build

Build without installing a bunch of dev packages, also for a different distro by changing build-arg.

```bash
# pull source from debian sid
./pullsrc.sh

# build a docker image that fits your target system.
docker build \
    -t opensshbuild \
    --build-arg DISTRO=ubuntu \
    --build-arg DISTVER=22.04 \
    --build-arg APT_MIRROR=ftp.us.debian.org \
    ./docker

# run the build process
docker run --rm -v $PWD:/data opensshbuild

# clean up docker image
docker image rm opensshbuild
docker builder prune
```

## Install DEBs

All DEBs are generated right under `build` directory. (either direct build or docker build).

```bash
ls -l build/*.deb

# Ignore thoses files with dbgsym and tests
find build -maxdepth 1 ! -name '*dbgsym*' ! -name '*tests*' -name '*.deb' | xargs sudo apt install -y
```
