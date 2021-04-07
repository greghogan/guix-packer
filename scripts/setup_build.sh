#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

ARCH=$(uname -m)

# compiler and library packages
guix install \
  abseil-cpp \
  boost \
  ccache \
  clang \
  cmake \
  cxxopts \
  fmt \
  folly \
  gcc-toolchain \
  gdb \
  gflags \
  git \
  gmp \
  json-modern-cxx \
  make \
  valgrind
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
