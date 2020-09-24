#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

# update all installed packages
apt-get update && apt-get upgrade
