#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# install newer kernel
amazon-linux-extras install -y \
  BCC \
  epel \
  kernel-ng

# install Intel oneAPI repository
# the GPG keys are installed below during "yum update -y"
cat <<EOF > /etc/yum.repos.d/intel.repo
[oneAPI]
name=Intel(R) oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

# update all installed packages
yum install -y deltarpm
yum update -y
