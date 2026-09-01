# AGENTS.md

Shell scripts that backport OpenSSH from Debian sid to older Debian/Ubuntu distros.

## Build order (must be sequential)

1. `./pullsrc.sh` — download OpenSSH sources from Debian sid pool into `downloads/`, plus the sid debhelper .debs into `builddep/` (needed by `install_deps.sh` on old distros; `./pullsrc.sh debhelper` fetches only the .debs)
2. `./install_deps.sh` — fix EOL/mirror sources then install build dependencies via apt; on distros with debhelper < 13.12 it installs `builddep/*.deb` and applies old-distro compat sed hacks
3. `./compile.sh` — build .deb packages into `output/`

## Version source of truth

`version.env` defines `OPENSSLVER`, pins `DEBHELPER_SIDPKG` (sid debhelper .debs; empty = auto-detect latest from the pool), and auto-detects `OPENSSH_SIDPKG` by scraping `http://deb.debian.org/debian/pool/main/o/openssh/`. It is sourced (not executed) by `compile.sh` and `pullsrc.sh`. Do not run it directly.

## Key env vars

- `FORCESSL=1` — force static OpenSSL linking even on distros with libssl >= 3.0
- `APT_MIRROR` — substitute apt sources mirror (e.g. `mirrors.ustc.edu.cn`); also applied when switching EOL Debian sources to archive handling (archive.debian.org)
- `DEB_BUILD_OPTIONS` and `DEB_BUILD_PROFILES` are set inside `compile.sh` to skip tests and udebs

## Package versioning

The distro codename is appended to the package version (`~${BUILD_CODENAME}`) during compile. The version is pinned via `OPENSSH_SIDPKG` in `version.env`; if that variable is empty, it falls back to auto-detecting the latest from Debian sid.

## Docker build

```bash
./pullsrc.sh debhelper   # host: populate builddep/ (required for old-distro dep images)
docker build --build-arg BASE_IMAGE=ubuntu:noble -f docker/Dockerfile.deps -t <tag> .
```

`docker/Dockerfile.deps` uses BuildKit `--mount=type=bind` for `install_deps.sh` and `builddep/`, so neither lands in an image layer (BuildKit is required; it is the default in modern docker).

> **EOL distro sources**: For EOL Debian releases (e.g. buster) the default
> `deb.debian.org` no longer serves the repository. `install_deps.sh` now automatically switches EOL Debian sources to `archive.debian.org` (adding the `-backports` pocket) before apt operations; `switch_archive_sources.sh` has been removed; EOL handling (buster unconditional, bullseye probed via deb.debian.org Release check with fallback to archive.debian.org) is now fully inside `install_deps.sh`. `docker/Dockerfile.deps` and CI both invoke `install_deps.sh` directly.

## pullsrc on the host

Old distros often ship old `ca-certificates` (or none in minimal images),
which can no longer verify GitHub's TLS chain. The release CI avoids this
by running `./pullsrc.sh` on the host runner (current CA store), then
mounting the repository into the build container with `-v`. `pullsrc.sh`
also downloads the sid debhelper .debs into `builddep/` (gitignored), which
`install_deps.sh` installs on distros whose own debhelper is < 13.12 — so
`pullsrc.sh` must run before `install_deps.sh`. When building manually for
an old distro, apply the same pattern:

```bash
./pullsrc.sh
docker run --rm -v "$(pwd):/work" -w /work debian:buster bash -c "./install_deps.sh && ./compile.sh"
```

## Directories

| Directory    | Purpose                                  |
|-------------|------------------------------------------|
| `downloads/` | Downloaded source tarballs (gitignored)  |
| `build/`     | Temporary build tree (gitignored)        |
| `output/`    | Final .deb packages                      |
| `builddep/`  | Sid debhelper .debs downloaded by `pullsrc.sh` (gitignored) |

## Release workflow

When a new upstream version is built and released:

1. Scrape the latest sid version to get the new value for `OPENSSH_SIDPKG`:
   ```bash
   wget -qO- http://deb.debian.org/debian/pool/main/o/openssh/ | grep -oP 'openssh_\K[0-9]+\.[0-9]+p[0-9]+-[0-9]+(?:~bpo[0-9]+(?:\+[0-9]+)?)?' | sort -V | tail -n 1
   ```
2. Update `OPENSSH_SIDPKG` in `version.env` and the `- OpenSSH ...` line in `README.md` with the new version.
3. Commit the change: `git add README.md version.env && git commit -m "bump version to <new-version>"`
4. Tag the release: `git tag v<new-version>_b1` (prefix `v`, suffix `_b1` = build 1; increment for rebuilds)
5. Push: `git push && git push --tags`

## Known distro-specific quirks

- Kylin V10 SP1: must run `./compile.sh` from a desktop terminal (not SSH), `kysec_auth` dialog requires manual approval
- UnionTech OS Desktop 20: exclude `libfido2-dev`, install `dwz` and `dh-runit` from bullseye
- `fail2ban`/`sshguard` need config changes for OpenSSH >= 9.8 (sshd → sshd-session)