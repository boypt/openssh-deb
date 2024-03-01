# Latest OpenSSH for Debian / Ubuntu distros.

A simple script to build latest deb package, using Debian sid packaging sources.

Similar Project:　[Latest OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

## Direct Build

### Install Dependencies

```bash
sudo apt install pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit libaudit-dev libedit-dev libfido2-dev libgtk-3-dev libselinux1-dev libsystemd-dev
```

### Build
```bash
# pull source from debian sid
./pullsrc.sh

# direct build
./compile.sh
```

## Use Docker to Build

Build DEBs without installing a bunch of dev packages in your system.

```bash
./pullsrc.sh
docker build \
    -t opensshbuild \
    --build-arg DISTRO=ubuntu \
    --build-arg DISTVER=22.04 \
    --build-arg APT_MIRROR=ftp.us.debian.org \
    ./docker
docker run --rm -v $PWD:/data opensshbuild
docker image rm opensshbuild
```

## Install DEBs

All DEBs are generated right under `build` directory. (Either direct build or with docker).

```bash
ls -l build/*.deb

# Ignore thoses files with dbgsym and tests
# Normally all you need is these 3 debs.
# openssh-client openssh-server openssh-sftp-server
```
