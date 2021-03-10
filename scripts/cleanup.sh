#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# delete temporary files and clear command history
rm -rf /tmp/*
> ~/.bash_history && history -c
