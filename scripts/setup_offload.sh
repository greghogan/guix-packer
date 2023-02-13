#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# packages which must be installed on the offload host
cp /transfer/offload.scm manifest.scm

# remove emulation binaries from manifest if not requested
if ! "$INSTALL_EMULATION_BINARIES" ; then
  sed -i 's/"qemu:static"//' manifest.scm
fi

# install packages
guix package --manifest=manifest.scm


# clear command history
> ~/.bash_history && history -c
