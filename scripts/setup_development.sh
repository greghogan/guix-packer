#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

GUIX_COMMIT=964bc9e5

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html
AWS_EFA_INSTALLER_VERSION=1.11.2

# https://software.seek.intel.com/ps-l
#   Intel Compiler serial number must be kept up-to-date in intel/silent.cfg
# https://software.intel.com/en-us/articles/intel-cpp-compiler-release-notes
#   to check compatible GCC release versions (after installation run `icc -v`)
INTEL_PARALLEL_STUDIO_XE_URL='https://registrationcenter-download.intel.com/akdlm/irc_nas/tec/17113/parallel_studio_xe_2020_update4_cluster_edition.tgz'

ARCH=$(uname -m)

GUIX_PROFILE='/var/guix/profiles/per-user/${USER}/guix-profile'

function WGET() { until wget --tries=1 --timeout=10 --progress=dot:mega "$1" -O "$2"; do rm -f "$2"; done }

# Ephemeral disks are setup in setup_system.sh to mount on boot;
# builds are just as fast on EBS but perhaps the snapshot is better with fewer fragments
mkdir -p "/volumes/nvme1n1/tmp" >/dev/null 2>&1 && cd "$_" || echo "No ephemeral disk mounted, building in home directory"

# Force creation of a profile by updating to the current Guix version, to the (optional) commit
/var/guix/profiles/per-user/root/current-guix/bin/guix pull ${GUIX_COMMIT:+--commit=${GUIX_COMMIT}}

# Import environment variables from Guix package installations
readonly SET_GUIX_PROFILE="export GUIX_PROFILE=${GUIX_PROFILE}"
eval "${SET_GUIX_PROFILE}" && echo "${SET_GUIX_PROFILE}" >>~/.bashrc

# Prepend PATH to second search for Guix binaries
readonly SET_GUIX_BINARY_PATH="export PATH=\$HOME/.config/guix/current/bin\${PATH:+:}\$PATH"
eval "${SET_GUIX_BINARY_PATH}" && echo "${SET_GUIX_BINARY_PATH}" >>~/.bashrc

# Prepend PATH to first search for user binaries
readonly SET_HOME_BINARY_PATH="export PATH=\$HOME/bin:\$HOME/sbin\${PATH:+:}\$PATH"
eval "${SET_HOME_BINARY_PATH}" && echo "${SET_HOME_BINARY_PATH}" >>~/.bashrc

# Install UTF-8 locale and force initial build of Guix
guix install glibc-utf8-locales

readonly SET_GUIX_LOCPATH="export GUIX_LOCPATH=\${GUIX_PROFILE}/lib/locale"
eval "${SET_GUIX_LOCPATH}" && echo "${SET_GUIX_LOCPATH}" >>~/.bashrc

# The profile does not look to be available until after the installation of
# glibc-utf8-locales, the first installed package, and the 'eval' will result
# in an error if the source file is not present.
readonly SOURCE_GUIX_PROFILE="source \${GUIX_PROFILE}/etc/profile"
eval "${SOURCE_GUIX_PROFILE}" && echo "${SOURCE_GUIX_PROFILE}" >>~/.bashrc

# System utility packages
if [ "${ARCH}" = "x86_64" ]; then
guix install \
  cpuid \
  fio
fi

guix install \
  binutils \
  coreutils \
  curl \
  diffutils \
  dos2unix \
  htop \
  iftop \
  iotop \
  iperf \
  jq \
  less \
  man-db \
  man-pages \
  netcat \
  numactl \
  parallel \
  pdsh \
  socat \
  tar \
  time \
  zstd
source ~/.bashrc

# Configure ccache (without installing)
mkdir -p ~/.ccache
cat <<EOF >~/.ccache/ccache.conf
max_size = 1.0G
EOF

# Install AWS EFA (Elastic Fabric Adaptor)
# this also installs Amazon's OpenMPI build among other installed packages
# note: no current support for aarch64 instances:
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types
if [ "${ARCH}" = "x86_64" ]; then
  WGET https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-${AWS_EFA_INSTALLER_VERSION}.tar.gz aws-efa-installer.tar.gz
  tar xf aws-efa-installer.tar.gz && rm -f aws-efa-installer.tar.gz
  cd aws-efa-installer || exit
  sudo ./efa_installer.sh -y || exit
  cd .. || exit
  rm -rf aws-efa-installer
fi

# Intel Compiler
if [ "${ARCH}" = "x86_64" ]; then
  WGET ${INTEL_PARALLEL_STUDIO_XE_URL} parallel_studio_xe.tbz
  tar xf parallel_studio_xe.tbz --transform "s|[^/]*|parallel_studio_xe|rSH" && rm -f parallel_studio_xe.tbz
  cd parallel_studio_xe || exit
  sudo ./install.sh --silent /tmp/silent.cfg || exit
  cd .. || exit
  rm -rf parallel_studio_xe

  echo -e "\n# Intel Compiler" >>~/.bashrc
  readonly SET_INTEL_BINARY_PATH="export PATH=\$PATH\${PATH:+:}/opt/intel/bin"
  eval "${SET_INTEL_BINARY_PATH}" && echo "${SET_INTEL_BINARY_PATH}" >>~/.bashrc
fi
rm -f /tmp/silent.cfg

# Cleanup
guix gc --delete-generations
# 'optimize' does create free space despite no intentional disabling of the daemon's automatic deduplication
# from the guix gc man page:
#   "this option is primarily useful when the daemon was running with --disable-deduplication"
guix gc --optimize --delete-generations
