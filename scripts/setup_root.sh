#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# prevent SSH key refresh on instance creation
cat <<EOF > /etc/cloud/cloud.cfg.d/99_custom.cfg
ssh_deletekeys: false
EOF


# generate and authorize an SSH public key, shared by all nodes in the cluster
ssh-keygen -N "" -t rsa -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys


# remove key prefix preventing SSH public key login to root; looks to be too
# late to prevent by adding 'disable_root: false' to cloud-init's cloud.cfg
sed -i -E 's/.* (ssh-rsa .*)/\1/' ~/.ssh/authorized_keys


# enable the sharing of multiple sessions over a single network connection
# with ControlMaster and ControlPath
mkdir .ssh/sockets

cat <<EOF > ~/.ssh/config
Host *
    LogLevel ERROR
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
EOF
chmod 600 ~/.ssh/config
