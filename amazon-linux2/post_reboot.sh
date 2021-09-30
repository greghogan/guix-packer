#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

ARCH=$(uname -m)

# install new packages
yum install -y \
  amazon-efs-utils \
  ioping \
  libhugetlbfs-devel \
  libhugetlbfs-utils \
  patch \
  perf \
  xorg-x11-xauth \
  yum-utils

# kernel-ng is installed in the pre-reboot script and loaded on the reboot,
# so remove old kernel (and headers) from the base Amazon Linux 2 repo
package-cleanup -y --oldkernels --count=1

# needed by Intel C/C++ compiler, which does not properly locate dependent
# GCC directories when guix is loaded in the user environment; guix is
# disabled by commenting out the "source ${GUIX_PROFILE}/etc/profile"
# command in .bashrc
yum groupinstall -y "Development Tools"

# install Java JDK
yum install -y java-11-amazon-corretto-headless

# install Intel ICX (cpp) and ICC (cpp-classic) compilers
if [ "${ARCH}" = "x86_64" ]; then
  yum install -y intel-oneapi-compiler-dpcpp-cpp intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic

  # install Packer
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  yum -y install packer
fi
