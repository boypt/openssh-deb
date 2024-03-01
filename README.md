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


