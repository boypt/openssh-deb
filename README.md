# Backport OpenSSH for Debian / Ubuntu distros.

A simple script to build backport openssh deb, using [Debian sid sources](https://packages.debian.org/sid/openssh-server).

Similar Project:　[Backport OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

### Current Version:

Package version are defined in `version.env` file.

Current version: (will follow debian sid upstream automatically when `./pullsrc.sh` is called)

- OpenSSH 9.9p2
- OpenSSL 3.0.16

### Supported (tested) Distro:

- Ubuntu 24.04
- Ubuntu 22.04
- Ubuntu 20.04
- Debian 13/trixie
- Debian 12/bookworm
- Debian 11/bullseye
- UnionTech OS Desktop 20 Home (Debian GLIBC 2.28.21-1+deepin-1) 
- Kylin V10 SP1 (Ubuntu GLIBC 2.31-0kylin9.2k0.1)

## Direct Build

```bash
# Install Dependencies
./install_deps.sh

# pull source
./pullsrc.sh

# direct build
./compile.sh
```

## Docker Build

Build without installing a bunch of dev packages, also for a different distro by changing build-arg.

```bash
# pull source from debian sid
./pullsrc.sh

# build a docker image that fits your target system.
docker run --rm -v "$(pwd):/work" -w /work ubuntu:20.04 bash -c "./install_deps.sh && ./compile.sh"

# clean up docker image
docker builder prune
```

## Install DEBs

Generated DEBs are right under the `output` directory. (either direct build or docker build).

```bash
ls -l output/*.deb

# Ignore dbgsym and tests
find output -maxdepth 1 ! -name '*dbgsym*' ! -name '*tests*' -name '*.deb' | xargs sudo apt install -y
```

## NOTES

### Known issues 

#### sshd-session issue

If installing backported openssh 9.8+ on older distros, some other programs may face problems while interacting with the openssh service. Since openssh-9.8, the subprocess name have changed from `sshd` to `sshd-session`.

Known programs with issue:

- fail2ban
- sshguard

Make sure to upgrade or reconfigure them to meet the latest changes.

##### fail2ban

change in `filter.d/sshd.conf`:

```
_daemon = sshd
```

into

```
_daemon = sshd(?:-session)?
```


### Distro Issues

Extra steps are needed to install on some distros.

##### UnionTech OS Desktop 20 Home (Debian GLIBC 2.28.21-1+deepin-1) 

1. Exclude `libfido2-dev` from the build Dependencies intall command, it's not available.
2. Install following packages from `debian/bullseye`.
    - [bullseye/dwz](https://packages.debian.org/bullseye/dwz)
    - [bullseye/dh-runit](https://packages.debian.org/bullseye/dh-runit)

##### Kylin V10 SP1 (Ubuntu GLIBC 2.31-0kylin9.2k0.1)

Run `./compile.sh` from the desktop Terminal(`mate-terminal`). 

During install the `builddep/*.deb`, a `kysec_auth` dialog would pop up asking for installing permissions. Manual click on the permit button is needed. 

If running in a ssh session, the compile script would fail without permissions.
