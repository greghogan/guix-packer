#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

# install new packages
yum install -y \
  patch
