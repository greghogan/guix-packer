#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html
AWS_EFA_INSTALLER_VERSION=1.21.0

function WGET() { until wget --tries=1 --timeout=10 --progress=dot:mega "$1" -O "$2"; do rm -f "$2"; done }

ARCH=$(uname -m)

# install new packages
yum install -y \
  amazon-efs-utils \
  bcc \
  bpftrace \
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
yum install -y java-17-amazon-corretto-headless

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
  yum update -y

  if [ "${INSTALL_INTEL_COMPILERS}" = "true" ]; then
    yum install -y intel-oneapi-compiler-dpcpp-cpp intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic
  fi

  # install Packer
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  yum -y install packer

  # install AWS EFA (Elastic Fabric Adaptor); for supported instance types and AMIs see
  #   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types
  #   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-amis
  WGET https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-${AWS_EFA_INSTALLER_VERSION}.tar.gz aws-efa-installer.tar.gz
  tar xf aws-efa-installer.tar.gz && rm -f aws-efa-installer.tar.gz
  cd aws-efa-installer || exit
  ./efa_installer.sh -y || exit
  cd .. || exit
  rm -rf aws-efa-installer
fi
