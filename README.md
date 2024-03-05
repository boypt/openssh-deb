# Latest OpenSSH for Debian / Ubuntu distros.

A simple script to build latest deb package, using Debian sid packaging sources.

Similar Project:　[Latest OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

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
    libgtk-3-dev libselinux1-dev libsystemd-dev

# pull source from debian sid
./pullsrc.sh

# direct build
./compile.sh
```

## Use Docker to Build

With docker, build without installing a bunch of dev packages, also for different distro versions by changing build-arg.

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

```

## Install DEBs

All DEBs are generated right under `build` directory. (Either direct build or with docker).

```bash
ls -l build/*.deb

# Ignore thoses files with dbgsym and tests
# Normally all you need is these 3 debs.
# openssh-client openssh-server openssh-sftp-server
find build -maxdepth 1 ! -name '*dbgsym*' ! -name '*tests*' -name '*.deb'
```
