# Backport OpenSSH for Debian / Ubuntu distros.

A script to build openssh deb backport to older distros, using [Debian sid sources](https://packages.debian.org/sid/openssh-server)

Similar Project: [Backport OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

### Current Version:

Package version are defined in `version.env` file.

Current version: (follows `debian/sid` automatically)

- OpenSSH 10.0p1-2
- OpenSSL 3.0.16

### Supported (tested) Distro:

- Ubuntu 24.04/22.04/20.04/18.04
- Debian 13/trixie 12/bookworm 11/bullseye
- UnionTech OS Desktop 20 Home (Debian GLIBC 2.28.21-1+deepin-1) 
- Kylin V10 SP1 (Ubuntu GLIBC 2.31-0kylin9.2k0.1)

## Download and install DEBs

Github Action builds common distro DEBs.

If your server OS is in the supported list, you can download and install them in the server.

### Release supported OSs
- Debian `bullseye(11)` / `bookworm(12)` / `trixie(13)` - `amd64`/`arm64`
- Ubuntu `bionic(18.04)` / `focal(20.04)` / `jammy(22.04)` / `noble(24.04)` - `amd64`/`arm64`

```bash
# make sure you have the tools
apt install -y wget jq lsb-release

_CN=$(lsb_release -sc)
_AR=$(dpkg --print-architecture)
wget -O- https://api.github.com/repos/boypt/openssh-deb/releases/latest \
    | jq -r ".assets[] | select(.name | contains(\"${_CN}_${_AR}\")) or contains(\"${_CN}_all\")) | .browser_download_url" \
    | wget -i-

ls *${_CN}*.deb
sudo apt install -y ./*${_CN}*.deb
```

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

Build without installing a bunch of dev packages, and build for different versions of distros.

```bash
# pull source from debian sid
./pullsrc.sh

# run with a docker image that fits your target system.
docker run --rm -v "$(pwd):/work" -w /work ubuntu:20.04 bash -c "./install_deps.sh && ./compile.sh"

# clean up docker image
docker builder prune
```

<details>

<summary>Using a APT mirror or proxy inside docker</summary>

using `-e` to set environment variables inside docker.

```bash
    docker run --rm -v "$(pwd):/work" -w /work \
        -e APT_MIRROR=mirrors.ustc.edu.cn \
        -e http_proxy=http://x.x.x.x \
        -e https_proxy=http://x.x.x.x \
        ubuntu:20.04 bash -c "./install_deps.sh && ./compile.sh"
```

</details>


## Install DEBs

Generated DEBs are right under the `output` directory. (both direct build and docker build).

```bash
ls -l output/*.deb
sudo apt install -y output/*.deb
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
