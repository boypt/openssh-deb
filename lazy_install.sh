#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace
trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

sudo apt install -y wget jq lsb-release tar

#GH_PROXY=https://tvv.tw/
#GH_PROXY=https://gh-proxy.com/
[[ -n ${1:-} ]] && GH_PROXY=${1:-} && \
    if ! [[ "$GH_PROXY" =~ ^https://.*/$ ]]; then
        GH_PROXY=https://${GH_PROXY}/
    fi

_REPO=boypt/openssh-deb
_LATEST_API=https://api.github.com/repos/${_REPO}/releases/latest

if [[ -n ${GH_PROXY:-} ]] && ! [[ $_LATEST_API =~ ^${GH_PROXY}.* ]]; then
    _LATEST_API="${GH_PROXY}${_LATEST_API}"
fi

_WORKDIR=$(mktemp -d)
_CN=$(lsb_release -sc)
_AR=$(dpkg --print-architecture)
_TARGET_ARCH="${_AR}"

pushd $_WORKDIR
TAR_URL=$(wget -O- "$_LATEST_API" \
    | jq -r ".assets[] | select(.name | contains(\"${_CN}\") and contains(\"${_TARGET_ARCH}\") and (endswith(\".tar.gz\"))) | .browser_download_url" | head -n 1)

if [[ -z "$TAR_URL" ]]; then
    echo "Error: No matching release package found for ${_CN}-${_TARGET_ARCH}."
    exit 1
fi

if [[ -n ${GH_PROXY:-} ]] && ! [[ "$TAR_URL" =~ ^${GH_PROXY}.* ]]; then
    TAR_URL=$(echo "$TAR_URL" | sed "s|https://github.com|${GH_PROXY:-}https://github.com|g")
fi

wget -O- "$TAR_URL" | tar -xzf -

if [[ $(find . -type f -name "*.deb" | wc -l) -gt 0 ]]; then
    echo "> These DEBs are going to be installed... Ctrl+C to interrupt"
    find . -type f -name "*.deb" -print
    sleep 3
    find . -type f -name "*.deb" -print | xargs sudo apt install -y
else
    echo "Error: No .deb packages found inside the archive."
    exit 1
fi
popd

[[ -d $_WORKDIR ]] && rm -rfv $_WORKDIR
ssh -V