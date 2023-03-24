#!/bin/bash
set -e
GROUP_NAME="brandon"
USERNAME="brandon"
PASSWORD="........"
# create group
groupadd "$GROUP_NAME"
# create user
useradd --create-home --shell /bin/bash -g "$GROUP_NAME" "$USERNAME"
# change user password
echo "$USERNAME:$PASSWORD" | chpasswd
# add user to sudo
usermod -aG sudo "$USERNAME"
# copy authorized_keys to user
cp -r /root/.ssh /home/$USERNAME/.ssh
# change privileges
chown -R $USERNAME:$GROUP_NAME /home/$USERNAME/.ssh
