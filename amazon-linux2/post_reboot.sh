#!/bin/sh -x

# exit immediately on failure, treat unset variables and parameters as an
# error, and disable filename expansion (globbing)
set -euf

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
  perf

# needed by Intel C/C++ compiler, which does not properly locate dependent
# GCC directories when guix is loaded in the user environment; guix is
# disabled by commenting out the "source ${GUIX_PROFILE}/etc/profile"
# command in .bashrc
yum groupinstall -y \
  "Development Tools"

# needed by Intel C/C++ compiler??? 2020 update 1 fails without these packages
# graphical dependencies (may not be needed, but relatively small installations):
yum install -y \
  alsa-lib \
  gtk2 \
  gtk3 \
  libXScrnSaver \
  xorg-x11-server-Xorg

# install Java JDK
cat <<'EOF' >/etc/yum.repos.d/adoptopenjdk.repo
[AdoptOpenJDK]
name=AdoptOpenJDK
baseurl=http://adoptopenjdk.jfrog.io/adoptopenjdk/rpm/amazonlinux/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
EOF

yum update -y
yum install -y adoptopenjdk-11-hotspot
