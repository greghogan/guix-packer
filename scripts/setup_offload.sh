#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

# the following packages must be installed on the offload host
cp /tmp/manifest/offload.scm manifest.scm
guix package --manifest=manifest.scm && source ~/.bashrc

# clear command history
> ~/.bash_history && history -c
