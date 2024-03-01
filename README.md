# Latest OpenSSH for Debian / Ubuntu release.


A simple script to build latest deb package, using Debian sid packaging sources.


## Install Dependencies

```bash
sudo apt install pkgconf build-essential fakeroot dpkg-dev debhelper debhelper-compat dh-exec dh-runit libaudit-dev libedit-dev libfido2-dev libgtk-3-dev libselinux1-dev libsystemd-dev
```

## Build

```bash
./pullsrc.sh
./compile.sh
```

## Use Docker to Build

Build the DEBs without installing a bunch of developing package in your host system.

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