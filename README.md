# OpenSSH Backport for Debian & Ubuntu

**Stay on the latest OpenSSH without upgrading your entire distro.**

This project rebuilds the official [Debian Sid OpenSSH source package](https://packages.debian.org/sid/openssh-server) for older Debian and Ubuntu releases. You get the newest security fixes and features as native `.deb` packages — with Debian's patches, systemd integration, and packaging intact — so you can keep long-term-stable systems secure without a full OS upgrade.

> **Similar project:** [openssh-rpms — Backport OpenSSH RPM for CentOS](https://github.com/boypt/openssh-rpms)

---

## Supported Distributions

Prebuilt packages are tested and published via GitHub Actions. Other architectures can be built from source.

| Distribution | Codename | Architectures | Notes |
| :--- | :--- | :---: | :--- |
| **Ubuntu 24.04 LTS** | `noble` | `amd64` / `arm64` | ✅ Fully supported |
| **Ubuntu 22.04 LTS** | `jammy` | `amd64` / `arm64` | ✅ Fully supported |
| **Ubuntu 20.04 LTS** | `focal` | `amd64` / `arm64` | ✅ Fully supported |
| **Ubuntu 18.04 LTS** | `bionic` | `amd64` / `arm64` | ✅ Fully supported |
| **Debian 13** | `trixie` | `amd64` / `arm64` | ✅ Fully supported |
| **Debian 12** | `bookworm` | `amd64` / `arm64` | ✅ Fully supported |
| **Debian 11** | `bullseye` | `amd64` / `arm64` | ✅ Fully supported |
| **Debian 10** | `buster` | `amd64` / `arm64` | ✅ Fully supported |
| UnionTech OS Desktop 20 Home | *based on buster / glibc 2.28* | — | ⚠️ See [extra steps](#uniontech-os-desktop-20-home) |
| Kylin V10 SP1 | *based on focal / glibc 2.31* | — | ⚠️ See [extra steps](#kylin-v10-sp1) |

> **Need another architecture?** Any Debian/Ubuntu derivative with a compatible glibc can build from source — see [Build from Source](#build-from-source).

---

## Current Versions

Versions are pinned in [`version.env`](version.env). When `OPENSSH_SIDPKG` is empty, the build automatically picks the latest version from Debian Sid.

| Component | Version | Source |
| :--- | :--- | :--- |
| **OpenSSH** | `10.5p1-1` | Debian Sid — auto-tracked |
| **OpenSSL** | `3.5.8` | Static link on older distros, dynamic link on newer ones |

The built package version is suffixed with the target codename (e.g. `10.5p1-1~noble`) so it is clearly distinguishable from the distro's official package and won't be silently overwritten.

---

## Quick Start — Install Prebuilt Packages

If your OS is in the table above, the fastest way is to install the CI-built `.debs`:

```bash
sudo bash -c "$(curl -L https://github.com/boypt/openssh-deb/raw/master/lazy_install.sh)"
```

Behind a firewall or need a GitHub proxy?

```bash
sudo bash -c "$(curl -L https://gh-proxy.com/github.com/boypt/openssh-deb/raw/master/lazy_install.sh)" @ gh-proxy.com
```

The script detects your codename and architecture, downloads the matching release tarball from the [latest GitHub Release](https://github.com/boypt/openssh-deb/releases/latest), and installs it with `apt`.

---

## Build from Source

### Prerequisites

The build must run in three steps **in order**:

```bash
# 1. Fetch OpenSSH sources from Debian Sid + sid debhelper debs for old distros
./pullsrc.sh

# 2. Fix apt sources for EOL releases and install build dependencies
./install_deps.sh

# 3. Compile — output goes to output/
./compile.sh
```

Useful environment variables:

| Variable | Effect |
| :--- | :--- |
| `FORCESSL=1` | Force static OpenSSL even when `libssl-dev >= 3.0` is available |
| `APT_MIRROR=mirrors.ustc.edu.cn` | Use a custom apt mirror (also applied when switching EOL Debian sources to `archive.debian.org`) |

Build artefacts:

| Directory | Contents |
| :--- | :--- |
| `downloads/` | Fetched source tarballs (gitignored) |
| `build/` | Ephemeral build tree (gitignored) |
| `builddep/` | Sid `debhelper` `.deb`s downloaded by `pullsrc.sh` (gitignored) |
| `output/` | Final `.deb` packages |

Install the result:

```bash
ls -l output/*.deb
sudo apt install -y output/*.deb
```

### Docker Build

Build without polluting your host, or target a different distro than your host:

```bash
# Fetch sources on the host first (host has a current CA store; old containers may not)
./pullsrc.sh

# Build for e.g. Ubuntu 20.04
docker run --rm -v "$(pwd):/work" -w /work ubuntu:20.04 bash -c "./install_deps.sh && ./compile.sh"

docker builder prune
```

With a mirror or proxy inside the container:

```bash
docker run --rm -v "$(pwd):/work" -w /work \
  -e APT_MIRROR=mirrors.ustc.edu.cn \
  -e http_proxy=http://proxy.example.com:8080 \
  -e https_proxy=http://proxy.example.com:8080 \
  ubuntu:20.04 bash -c "./install_deps.sh && ./compile.sh"
```

> **Why fetch sources on the host?** Minimal or EOL images often ship outdated `ca-certificates` and cannot verify GitHub's TLS chain. The release CI uses the same pattern: run `./pullsrc.sh` on the host runner, then mount the repo into the container. `pullsrc.sh` also populates `builddep/` with the Sid `debhelper` debs that `install_deps.sh` needs on distros with `debhelper < 13.12`.

<details>
<summary>Dockerfile.deps for CI</summary>

For reproducible CI images:

```bash
./pullsrc.sh debhelper   # populate builddep/ only
docker build --build-arg BASE_IMAGE=ubuntu:noble -f docker/Dockerfile.deps -t <tag> .
```

`docker/Dockerfile.deps` uses BuildKit `--mount=type=bind` for `install_deps.sh` and `builddep/`, so they don't end up in image layers. BuildKit is required (default on modern Docker).

</details>

---

## Notes

### Rolling Back to the Distro Default

```bash
sudo apt update
V=$(apt-cache madison ssh | awk 'NR==1 {print $3}')
sudo apt install --allow-downgrades -y \
    ssh=$V openssh-client=$V openssh-server=$V openssh-sftp-server=$V
```

### OpenSSH 9.8+ — `sshd` → `sshd-session`

Since OpenSSH 9.8, the per-connection daemon was renamed from `sshd` to `sshd-session`. Tools that match on the process name will miss new sessions unless updated.

**Affected software:** `fail2ban`, `sshguard`, and similar log monitors.

#### fail2ban

In `filter.d/sshd.conf`, change:

```ini
_daemon = sshd
```

to:

```ini
_daemon = sshd(?:-session)?
```

Then restart `fail2ban`. `sshguard` and other tools need analogous updates — check their docs for OpenSSH 9.8+ compatibility.

### Distribution-Specific Quirks

#### UnionTech OS Desktop 20 Home

*Debian glibc 2.28-21-1+deepin-1*

1. Exclude `libfido2-dev` from the build-dependency install — it is not available.
2. Manually install from `bullseye`:
   - [dwz](https://packages.debian.org/bullseye/dwz)
   - [dh-runit](https://packages.debian.org/bullseye/dh-runit)

#### Kylin V10 SP1

*Ubuntu glibc 2.31-0kylin9.2k0.1*

Run `./compile.sh` from a desktop terminal (`mate-terminal`), **not** over SSH. Installing `builddep/*.deb` triggers a `kysec_auth` authorization dialog that requires a manual click — it will fail silently in a headless SSH session.

---

## How It Works

The build starts from the unmodified Debian Sid source package and applies only the minimal compatibility shims needed for older toolchains:

- **No test or udeb packages** — `openssh-tests` is excluded (`BUILD_PACKAGES += -Nopenssh-tests`), `DEB_BUILD_PROFILES="noudeb pkg.openssh.nognome"` and `DEB_BUILD_OPTIONS="noddebs nocheck"` skip udebs, GNOME askpass, and the build-time test suite.
- **Codename suffix** — `~${BUILD_CODENAME}` is appended to the version in `debian/changelog`.
- **OpenSSL linkage** (decided at build time from the installed `libssl-dev`):
  - *Dynamic* — if `libssl-dev >= 3.0.0` and `FORCESSL` is unset: links against the system OpenSSL, no extra compilation.
  - *Static* — if `libssl-dev < 3.0.0` or `FORCESSL=1`: builds OpenSSL `${OPENSSLVER}` from source, removes `libssl-dev` from `debian/control`, and injects `--with-ssl-dir` plus `LD_LIBRARY_PATH` into `debian/rules`.
- **Security-key / FIDO2** — if `libfido2-dev < 1.5.0`, removes it from build deps and flips `with-security-key-builtin` to `disable-security-key`.
- **wtmpdb** — if `libwtmpdb-dev` is unavailable, strips it and `--with-wtmpdb`.
- **init-system-helpers** — relaxes the versioned dependency from `1.66` to `1.50` when the installed version is older.
- **EOL apt sources** — `install_deps.sh` automatically rewrites EOL Debian sources to `archive.debian.org` (including `-backports`), unconditionally for both `buster` and `bullseye`; bullseye-security is commented out as archive.debian.org does not carry it yet. The retired `switch_archive_sources.sh` is no longer needed.
- **Additional portability shims in `compile.sh`** — handles `libcrypt-dev`, `dh-runit`/`runit-helper`, `systemd` sysusers, and non-merged-`/usr` layouts as needed.

---

## Releasing a New Version

1. Find the latest Sid version:
   ```bash
   wget -qO- http://deb.debian.org/debian/pool/main/o/openssh/ \
     | grep -oP 'openssh_\K[0-9]+\.[0-9]+p[0-9]+-[0-9]+(?:~bpo[0-9]+(?:\+[0-9]+)?)?' \
     | sort -V | tail -n 1
   ```
2. Update `OPENSSH_SIDPKG` in `version.env` and the version table in `README.md`.
3. Commit: `git add README.md version.env && git commit -m "bump version to <new-version>"`
4. Tag: `git tag v<new-version>_b1` (`_b1` = build 1; increment on rebuilds)
5. Push: `git push && git push --tags`
