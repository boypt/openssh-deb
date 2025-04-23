#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

_REPO=boypt/openssh-deb
USER_REPO="${1:-}"
[[ -n $USER_REPO ]] && _REPO=$USER_REPO

# make sure you have the tools
sudo apt install -y wget jq lsb-release

_WORKDIR=$(mktemp -d)
_CN=$(lsb_release -sc)
_AR=$(dpkg --print-architecture)

pushd $_WORKDIR
wget -O- https://api.github.com/repos/${_REPO}/releases/latest \
    | jq -r ".assets[] | select(.name | contains(\"${_CN}_${_AR}\") or contains(\"${_CN}_all\")) | .browser_download_url" \
    | wget -i-

echo "> These DEBs is going to install... Ctrl+c to interrupt"
ls -l *${_CN}*.deb
sleep 3
sudo apt install -y ./*${_CN}*.deb
popd

[[ -d $_WORKDIR ]] && rm -rfv $_WORKDIR
ssh -V
