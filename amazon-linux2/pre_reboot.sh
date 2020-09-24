#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

# install newer kernel
amazon-linux-extras install -y \
  BCC \
  epel \
  kernel-ng

# update all installed packages
yum install -y deltarpm
yum update -y
