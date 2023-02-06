#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# install newer kernel
amazon-linux-extras install -y \
  epel \
  kernel-ng

# update all installed packages
yum install -y deltarpm
yum update -y
