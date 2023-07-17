#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

ARCH=$(uname -m)

# install new packages
dnf install -y \
  amazon-efs-utils \
  bcc \
  bpftrace \
  dnf-utils \
  patch \
  perf \
  xorg-x11-xauth

# needed by Intel C/C++ compiler, which does not properly locate dependent
# GCC directories when guix is loaded in the user environment; guix is
# disabled by commenting out the "source ${GUIX_PROFILE}/etc/profile"
# command in .bashrc
dnf groupinstall -y "Development Tools"

# install Java JDK
dnf install -y java-17-amazon-corretto-headless

# install Intel ICX (cpp) and ICC (cpp-classic) compilers
if [ "${ARCH}" = "x86_64" ]; then
  cat <<EOF > /etc/yum.repos.d/intel.repo
[oneAPI]
name=Intel(R) oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

  # install the repository GPG keys
  yum upgrade -y

  if [ "${INSTALL_INTEL_COMPILERS}" = "true" ]; then
    dnf install -y intel-oneapi-compiler-dpcpp-cpp intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic
  fi

  # install Packer
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  dnf -y install packer
fi
