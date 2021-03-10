#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

# the following packages must be installed on the offload host
guix install \
  guix \
  guile \
  guile-ssh

# cleanup
guix gc --delete-generations
# 'optimize' does create free space despite no intentional disabling of the daemon's automatic deduplication
# from the guix gc man page:
#   "this option is primarily useful when the daemon was running with --disable-deduplication"
guix gc --optimize --delete-generations

# clear command history
> ~/.bash_history && history -c
