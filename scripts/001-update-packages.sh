#!/bin/bash
# exit on errors
set -e
# update
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
# install dependencies
apt-get -y install jq git
# cleanup
apt-get -y autoremove
