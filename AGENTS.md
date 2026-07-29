# AGENTS.md

Shell scripts that backport OpenSSH from Debian sid to older Debian/Ubuntu distros.

## Build order (must be sequential)

1. `./install_deps.sh` — install build dependencies via apt
2. `./pullsrc.sh` — download OpenSSH sources from Debian sid pool into `downloads/`
3. `./compile.sh` — build .deb packages into `output/`

## Version source of truth

`version.env` defines `OPENSSLVER` and auto-detects `OPENSSH_SIDPKG` by scraping `http://deb.debian.org/debian/pool/main/o/openssh/`. It is sourced (not executed) by `compile.sh` and `pullsrc.sh`. Do not run it directly.

## Key env vars

- `FORCESSL=1` — force static OpenSSL linking even on distros with libssl >= 3.0
- `APT_MIRROR` — substitute apt sources mirror (e.g. `mirrors.ustc.edu.cn`)
- `DEB_BUILD_OPTIONS` and `DEB_BUILD_PROFILES` are set inside `compile.sh` to skip tests and udebs

## Package versioning

The distro codename is appended to the package version (`~${BUILD_CODENAME}`) during compile. The version is pinned via `OPENSSH_SIDPKG` in `version.env`; if that variable is empty, it falls back to auto-detecting the latest from Debian sid.

## Docker build

```bash
docker build --build-arg BASE_IMAGE=ubuntu:noble -f docker/Dockerfile.deps -t <tag> .
```

## Directories

| Directory    | Purpose                                  |
|-------------|------------------------------------------|
| `downloads/` | Downloaded source tarballs (gitignored)  |
| `build/`     | Temporary build tree (gitignored)        |
| `output/`    | Final .deb packages                      |
| `builddep/`  | Pre-built debhelper .debs for old distros |

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