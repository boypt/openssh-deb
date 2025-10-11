#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace
trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR
# make sure you have the tools
sudo apt install -y wget jq lsb-release

#GH_PROXY=https://tvv.tw/
#GH_PROXY=https://gh-proxy.com/

_REPO=boypt/openssh-deb
_LATEST_API=${GH_PROXY:-}https://api.github.com/repos/${_REPO}/releases/latest

_WORKDIR=$(mktemp -d)
_CN=$(lsb_release -sc)
_AR=$(dpkg --print-architecture)

pushd $_WORKDIR
mapfile -t DEB_URLS < <(wget -O- "$_LATEST_API" \
    | jq -r ".assets[] | select(.name | contains(\"${_CN}_${_AR}\") or contains(\"${_CN}_all\")) | .browser_download_url" )

if [[ -n ${GH_PROXY:-} ]] && ! printf '%s\n' "${DEB_URLS[@]}" | grep ${GH_PROXY}; then
    printf '%s\n' "${DEB_URLS[@]}" | sed "s|https://github.com|${GH_PROXY:-}https://github.com|g" | wget -i -
else
    printf '%s\n' "${DEB_URLS[@]}" | wget -i -
fi

if [[ $(find . -type f -name "*${_CN}*.deb" | wc -l) -gt 0 ]]; then
    echo "> These DEBs is going to be installed... Ctrl+C to interrupt"
    find . -type f -name "*${_CN}*.deb" -print
    sleep 3
    sudo apt install -y *${_CN}*.deb
fi
popd

[[ -d $_WORKDIR ]] && rm -rfv $_WORKDIR
ssh -V
