#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

arg1="${1:-}"

source $__dir/version.env

# debhelper .debs for old distros: downloaded here on the host (current CA and
# network), installed by install_deps.sh from builddep/ (gitignored). Old
# distros cannot build the sid OpenSSH source with their own debhelper
# (dh-sequence-movetousr needs >= 13.11.7), and adding sid apt sources inside
# old containers is fragile, so we just fetch the two arch-all .debs directly.
DEBHELPER_LINKS=(
	$DEBMIRROR/pool/main/d/debhelper/debhelper_${DEBHELPER_SIDPKG}_all.deb
	$DEBMIRROR/pool/main/d/debhelper/libdebhelper-perl_${DEBHELPER_SIDPKG}_all.deb
)

# `./pullsrc.sh debhelper` fetches only the .debs (used by the deps-image CI
# before docker build, where the openssh sources are not needed).
if [[ "$arg1" == "debhelper" ]]; then
	mkdir -p $__dir/builddep
	echo "> INFO: downloading debhelper ${DEBHELPER_SIDPKG} .debs into builddep/."
	wget --continue -P "$__dir/builddep" "${DEBHELPER_LINKS[@]}"
	exit 0
fi

DOWNLOADLINKS=(
	$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSH_SIDPKG}.{debian.tar.xz,dsc}
)
# Dynamic orig detection: parse .dsc for actual orig filename(s) to handle gz→xz switch (10.5p1+ uses .xz, no .asc)
DSC_URL=$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSH_SIDPKG}.dsc
ORIG_FILES=$(wget -qO- "$DSC_URL" 2>/dev/null | awk '/^ [0-9a-f]+ [0-9]+ openssh.*\.orig\./{print $3}' | sort -u || true)
if [[ -n "$ORIG_FILES" ]]; then
	for f in $ORIG_FILES; do DOWNLOADLINKS+=("$DEBMIRROR/pool/main/o/openssh/$f"); done
else
	# Fallback when .dsc parsing fails (network hiccup or format change):
	# probe xz→gz in order, only add the first URL that actually exists (200).
	# Reuse the wget→curl→python3 probe from install_deps.sh (timeout 5) so
	# minimal containers without wget/curl still work; keep it inside `if`
	# so `set -e` / `trap ERR` is not triggered on 404/offline.
	CANDIDATES=("openssh_${OPENSSHVER}.orig.tar.xz" "openssh_${OPENSSHVER}.orig.tar.gz")
	_probe_url() {
		local _pu_url="$1"
		if command -v wget >/dev/null 2>&1; then
			if wget -q --spider --timeout=5 "$_pu_url" 2>/dev/null; then
				return 0
			fi
		fi
		if command -v curl >/dev/null 2>&1; then
			if curl -fsI --max-time 5 -L "$_pu_url" >/dev/null 2>&1; then
				return 0
			fi
			if curl -fsI --max-time 5 "$_pu_url" >/dev/null 2>&1; then
				return 0
			fi
		fi
		if command -v python3 >/dev/null 2>&1; then
			if python3 -c 'import sys, urllib.request, ssl
url=sys.argv[1]
try:
    ctx=ssl._create_unverified_context()
except Exception:
    ctx=None
try:
    req=urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, timeout=5, context=ctx) as r:
        sys.exit(0 if r.status < 400 else 1)
except Exception:
    try:
        req=urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5, context=ctx) as r:
            sys.exit(0 if r.status < 400 else 1)
    except Exception:
        sys.exit(1)
' "$_pu_url" 2>/dev/null; then
				return 0
			fi
		fi
		return 1
	}
	_found=0
	for cand in "${CANDIDATES[@]}"; do
		if _probe_url "$DEBMIRROR/pool/main/o/openssh/$cand"; then
			DOWNLOADLINKS+=("$DEBMIRROR/pool/main/o/openssh/$cand")
			_found=1
			break
		fi
	done
	if [[ $_found -eq 0 ]]; then
		# offline or both 404: keep one attempt so wget error is explicit via trap ERR
		DOWNLOADLINKS+=("$DEBMIRROR/pool/main/o/openssh/openssh_${OPENSSHVER}.orig.tar.xz")
	fi
fi
DOWNLOADLINKS+=("${OPENSSLMIR}/${OPENSSLSRC}")

mkdir -p $__dir/downloads $__dir/builddep && cd $__dir/downloads
echo "> INFO: downloading the following sources."
echo "${DOWNLOADLINKS[@]}" | tr " " "\n"
wget --continue "${DOWNLOADLINKS[@]}"

echo "> INFO: downloading debhelper ${DEBHELPER_SIDPKG} .debs into builddep/."
wget --continue -P "$__dir/builddep" "${DEBHELPER_LINKS[@]}"

