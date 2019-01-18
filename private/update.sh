#!/bin/bash

scriptroot=$(readlink -f $(dirname $0))

BUNDLE=$1

if [[ -z $BUNDLE ]]; then
  cd $scriptroot/..
  meteor npm install
  meteor build /tmp
  BUNDLE=/tmp/codex-blackboard.tar.gz
  cd -
fi

sudo mkdir /opt/codex2
sudo tar -C /opt/codex2 -xz < $BUNDLE
cd /opt/codex2/bundle/programs/server
sudo npm install
cd -
if [[ -d /opt/codex-old ]]; then
  sudo rm -rf /opt/codex-old
fi
sudo systemctl stop codex.target
sudo mv /opt/codex /opt/codex-old
sudo mv /opt/codex2 /opt/codex
sudo systemctl start codex.target

