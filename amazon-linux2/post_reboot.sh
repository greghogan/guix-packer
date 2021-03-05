#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

ARCH=$(uname -m)

# kernel-ng is installed in the pre-reboot script and loaded on the reboot,
# so remove old kernel (and headers) from the base Amazon Linux 2 repo;
# from `man yum`: 'Note that if the repo cannot be determined, "installed" is printed instead.'
OLD_KERNEL_VERSIONS=$(yum list installed kernel | awk '($3 == "@amzn2-core" || $3 == "installed") { split($1, p, "."); print p[1] "-" $2 }')
if [ -n "${OLD_KERNEL_VERSIONS}" ]; then
  # leave unquoted so that arguments are passed on one line
  yum remove -y ${OLD_KERNEL_VERSIONS}
fi

# alternatively, the following command dependent on 'yum-utils' removes old kernels:
# package-cleanup -y --oldkernels --count=1


# install new packages
yum install -y \
  amazon-efs-utils \
  ioping \
  libhugetlbfs-devel \
  libhugetlbfs-utils \
  patch \
  perf \
  xorg-x11-xauth

# needed by Intel C/C++ compiler, which does not properly locate dependent
# GCC directories when guix is loaded in the user environment; guix is
# disabled by commenting out the "source ${GUIX_PROFILE}/etc/profile"
# command in .bashrc
yum groupinstall -y \
  "Development Tools"

# needed by Intel C/C++ compiler??? 2020 update 1 fails without these packages
# graphical dependencies (may not be needed, but relatively small installations):
if [ "${ARCH}" = "x86_64" ]; then
  yum install -y \
    alsa-lib \
    gtk2 \
    gtk3 \
    libXScrnSaver \
    xorg-x11-server-Xorg
fi

# install Java JDK
yum install -y java-11-amazon-corretto-headless

# install Intel ICX (cpp) and ICC (cpp-classic) compilers
if [ "${ARCH}" = "x86_64" ]; then
  yum install -y intel-oneapi-compiler-dpcpp-cpp intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic
fi
