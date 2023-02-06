#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

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
fi


# install qemu targets for user mode emulation
yum install -y qemu-user-static

# register emulation binaries using the command from the qemu-binfmt-conf script as called by register.sh
#   https://github.com/qemu/qemu/blob/master/scripts/qemu-binfmt-conf.sh
#   https://github.com/multiarch/qemu-user-static/blob/master/containers/latest/register.sh
case "${ARCH}" in
  aarch64)
    cpu=x86_64
    magic='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'
    mask='\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
    echo ":qemu-${cpu}:M::${magic}:${mask}:/usr/bin/qemu-${cpu}-static:" > /proc/sys/fs/binfmt_misc/register
    ;;
  x86_64)
    cpu=aarch64
    magic='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
    mask='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
    echo ":qemu-${cpu}:M::${magic}:${mask}:/usr/bin/qemu-${cpu}-static:" > /proc/sys/fs/binfmt_misc/register
    ;;
  *)
    echo "unsupported ARCH=${ARCH}"
    exit 1
esac
