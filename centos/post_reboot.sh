#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

# install new packages
yum install -y \
  patch \
  yum-utils

# install Packer
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
yum -y install packer
