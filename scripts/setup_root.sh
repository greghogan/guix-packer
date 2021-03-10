#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# enable passwordless SSH for root
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin without-password/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes$/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd.service

# generate and authorize an SSH public key, shared by all nodes in the cluster
ssh-keygen -N "" -t rsa -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

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
