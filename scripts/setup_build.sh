#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

ARCH=$(uname -m)

# compiler and library packages
cp /tmp/manifest/build.scm manifest.scm
guix package --manifest=manifest.scm
source ~/.bashrc

# configure ccache
mkdir -p ~/.ccache
cat <<EOF >~/.ccache/ccache.conf
max_size = 1.0G
EOF

# Intel Compiler
if [ "${ARCH}" = "x86_64" ]; then
  cat <<-EOF >>~/.bashrc

	# setup Intel oneAPI environment
	. /opt/intel/oneapi/setvars.sh > /dev/null
	EOF
fi

# remove old generations but defer cleanup to the final script
guix gc --collect-garbage=0 --delete-generations

# clear command history
> ~/.bash_history && history -c
